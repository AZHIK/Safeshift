-- ============================================================================
-- 0110 — Phase 6: notification send pipeline
-- ============================================================================
-- Phase 6 intentionally stops at the notification_log boundary. FCM, Beem, and
-- Resend delivery are Phase 7 Edge Functions. This function resolves a template,
-- applies preferences/quiet hours, renders variables, and writes a pending log
-- row. It returns the API-facing notification_log.public_id.
-- ============================================================================

create or replace function public.send_notification(
  p_profile_id uuid,
  p_template_code text,
  p_channel text,
  p_variables jsonb,
  p_reference_type text default null,
  p_reference_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_country_id uuid;
  v_language_id uuid;
  v_country_language_id uuid;
  v_fallback_language_id uuid;
  v_tpl public.notification_templates%rowtype;
  v_category text;
  v_critical boolean;
  v_pref public.notification_preferences%rowtype;
  v_pref_found boolean := false;
  v_timezone text;
  v_local_time time;
  v_in_quiet_hours boolean := false;
  v_recipient text;
  v_title text;
  v_body text;
  v_subject text;
  v_provider text;
  v_public_id uuid;
  v_var record;
begin
  if not (private.is_service_context() or public.has_permission('manage_notifications')) then
    raise exception 'insufficient privileges to send notifications'
      using errcode = '42501';
  end if;

  if p_channel not in ('push', 'sms', 'email') then
    raise exception 'unsupported notification channel: %', p_channel
      using errcode = '22023';
  end if;

  if p_reference_type is null then
    p_reference_id := null;
  elsif p_reference_id is null then
    raise exception 'reference_id is required when reference_type is supplied'
      using errcode = '22023';
  end if;

  select p.default_country_id,
         p.preferred_language_id,
         c.default_language_id
    into v_country_id, v_language_id, v_country_language_id
    from public.profiles p
    left join public.countries c on c.id = p.default_country_id
   where p.id = p_profile_id;

  if not found then
    raise exception 'profile % does not exist', p_profile_id
      using errcode = '23503';
  end if;

  v_language_id := coalesce(v_language_id, v_country_language_id);

  select l.id into v_fallback_language_id
    from public.languages l
   where l.code = 'en'
   limit 1;

  -- Prefer an exact country + language template, then a global country fallback,
  -- then the same country in English, then the global English fallback.
  select *
    into v_tpl
    from public.notification_templates t
   where t.code = p_template_code
     and t.channel = p_channel
     and t.is_active
     and (t.country_id = v_country_id or t.country_id is null)
     and (t.language_id = v_language_id or t.language_id = v_fallback_language_id)
   order by (t.country_id is not null) desc,
            (t.language_id = v_language_id) desc,
            t.created_at asc
   limit 1;

  if not found then
    raise exception 'no active notification template for code %, channel %, country %, language %',
      p_template_code, p_channel, v_country_id, v_language_id
      using errcode = 'P0002';
  end if;

  v_category := case
    when p_template_code like 'job_%' then 'job_updates'
    when p_template_code like 'payment_%' then 'payment'
    when p_template_code like 'promo%' then 'promotions'
    when p_template_code in ('emergency_alert', 'safety_alert') then 'safety_alerts'
    when p_template_code like 'chat%' then 'chat'
    else 'system'
  end;

  v_critical := p_template_code in ('emergency_alert', 'safety_alert');

  select * into v_pref
    from public.notification_preferences np
   where np.profile_id = p_profile_id
     and np.category = v_category
     and np.channel = p_channel;
  v_pref_found := found;

  if v_pref_found and not v_pref.is_enabled and not v_critical then
    return null;
  end if;

  if v_pref_found
     and not v_critical
     and v_pref.quiet_hours_start is not null
     and v_pref.quiet_hours_end is not null
  then
    v_timezone := coalesce(
      v_pref.timezone,
      (select c.timezone from public.countries c where c.id = v_country_id),
      'Africa/Dar_es_Salaam'
    );
    v_local_time := (now() at time zone v_timezone)::time;

    if v_pref.quiet_hours_start < v_pref.quiet_hours_end then
      v_in_quiet_hours := v_local_time >= v_pref.quiet_hours_start
                          and v_local_time < v_pref.quiet_hours_end;
    else
      v_in_quiet_hours := v_local_time >= v_pref.quiet_hours_start
                          or v_local_time < v_pref.quiet_hours_end;
    end if;

    if v_in_quiet_hours then
      return null;
    end if;
  end if;

  if p_channel = 'push' then
    select pt.token into v_recipient
      from public.push_tokens pt
     where pt.profile_id = p_profile_id
       and pt.is_active
     order by pt.last_used_at desc nulls last, pt.created_at desc
     limit 1;
    v_provider := 'fcm';
  elsif p_channel = 'sms' then
    select p.phone into v_recipient
      from public.profiles p
     where p.id = p_profile_id;
    v_provider := 'beem';
  else
    select p.email into v_recipient
      from public.profiles p
     where p.id = p_profile_id;
    v_provider := 'resend';
  end if;

  if v_recipient is null or length(btrim(v_recipient)) = 0 then
    return null;
  end if;

  v_title := v_tpl.title_template;
  v_body := v_tpl.body_template;

  for v_var in
    select key, value from jsonb_each_text(coalesce(p_variables, '{}'::jsonb))
  loop
    v_body := replace(v_body, '{{' || v_var.key || '}}', coalesce(v_var.value, ''));
    v_body := replace(v_body, '{' || v_var.key || '}', coalesce(v_var.value, ''));
    if v_title is not null then
      v_title := replace(v_title, '{{' || v_var.key || '}}', coalesce(v_var.value, ''));
      v_title := replace(v_title, '{' || v_var.key || '}', coalesce(v_var.value, ''));
    end if;
  end loop;

  v_subject := case when p_channel = 'email' then coalesce(v_title, p_template_code) else null end;

  insert into public.notification_log (
    profile_id, channel, template_code, recipient, subject, body,
    status, provider, reference_type, reference_id
  ) values (
    p_profile_id, p_channel, p_template_code, v_recipient, v_subject, v_body,
    'pending', v_provider, p_reference_type, p_reference_id
  )
  returning public_id into v_public_id;

  return v_public_id;
end;
$$;

comment on function public.send_notification(uuid, text, text, jsonb, text, uuid) is
  'Resolves a template, applies notification preferences/quiet hours, renders variables, and writes a pending notification_log row. Actual provider delivery is Phase 7.';

revoke all on function public.send_notification(uuid, text, text, jsonb, text, uuid) from public;
grant execute on function public.send_notification(uuid, text, text, jsonb, text, uuid) to authenticated, service_role;
