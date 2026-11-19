

-- ----------------------------------------------------------------------------
-- Driver documents: <driver_id>/<filename>
-- ----------------------------------------------------------------------------
create policy driver_documents_storage_select
  on storage.objects for select to authenticated
  using (
    bucket_id = 'driver-documents'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or (select public.has_permission('view_all_drivers'))
    )
  );

create policy driver_documents_storage_insert
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'driver-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy driver_documents_storage_update
  on storage.objects for update to authenticated
  using (
    bucket_id = 'driver-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'driver-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy driver_documents_storage_delete
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'driver-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ----------------------------------------------------------------------------
-- Vehicle documents: <vehicle_id>/<filename>
-- ----------------------------------------------------------------------------
create policy vehicle_documents_storage_select
  on storage.objects for select to authenticated
  using (
    bucket_id = 'vehicle-documents'
    and exists (
      select 1
      from public.vehicles v
      where v.id::text = (storage.foldername(name))[1]
        and (
          v.owner_profile_id = auth.uid()
          or v.primary_driver_id = auth.uid()
          or exists (
            select 1 from public.vehicle_assignments va
            where va.vehicle_id = v.id
              and va.driver_id = auth.uid()
              and va.is_active
              and va.unassigned_at is null
          )
          or (select public.has_permission('view_all_vehicles'))
        )
    )
  );

create policy vehicle_documents_storage_insert
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'vehicle-documents'
    and exists (
      select 1
      from public.vehicles v
      where v.id::text = (storage.foldername(name))[1]
        and (
          v.owner_profile_id = auth.uid()
          or v.primary_driver_id = auth.uid()
          or exists (
            select 1 from public.vehicle_assignments va
            where va.vehicle_id = v.id
              and va.driver_id = auth.uid()
              and va.is_active
              and va.unassigned_at is null
          )
        )
    )
  );

create policy vehicle_documents_storage_update
  on storage.objects for update to authenticated
  using (
    bucket_id = 'vehicle-documents'
    and exists (
      select 1
      from public.vehicles v
      where v.id::text = (storage.foldername(name))[1]
        and (
          v.owner_profile_id = auth.uid()
          or v.primary_driver_id = auth.uid()
        )
    )
  )
  with check (
    bucket_id = 'vehicle-documents'
    and exists (
      select 1
      from public.vehicles v
      where v.id::text = (storage.foldername(name))[1]
        and (
          v.owner_profile_id = auth.uid()
          or v.primary_driver_id = auth.uid()
        )
    )
  );

create policy vehicle_documents_storage_delete
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'vehicle-documents'
    and exists (
      select 1
      from public.vehicles v
      where v.id::text = (storage.foldername(name))[1]
        and (
          v.owner_profile_id = auth.uid()
          or v.primary_driver_id = auth.uid()
        )
    )
  );

-- ----------------------------------------------------------------------------
-- Job evidence: <job_id>/<filename>. Append-only from the app.
-- ----------------------------------------------------------------------------
create policy job_evidence_storage_select
  on storage.objects for select to authenticated
  using (
    bucket_id = 'job-evidence'
    and exists (
      select 1
      from public.jobs j
      where j.id::text = (storage.foldername(name))[1]
        and (
          j.customer_id = auth.uid()
          or j.driver_id = auth.uid()
          or (select public.has_permission('view_all_jobs'))
        )
    )
  );

create policy job_evidence_storage_insert
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'job-evidence'
    and exists (
      select 1
      from public.jobs j
      where j.id::text = (storage.foldername(name))[1]
        and (j.customer_id = auth.uid() or j.driver_id = auth.uid())
    )
  );

-- ----------------------------------------------------------------------------
-- Chat attachments: <job_id>/<filename>
-- ----------------------------------------------------------------------------
create policy chat_attachments_storage_select
  on storage.objects for select to authenticated
  using (
    bucket_id = 'chat-attachments'
    and exists (
      select 1
      from public.jobs j
      where j.id::text = (storage.foldername(name))[1]
        and (
          j.customer_id = auth.uid()
          or j.driver_id = auth.uid()
          or (select public.has_permission('view_all_jobs'))
        )
    )
  );

create policy chat_attachments_storage_insert
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'chat-attachments'
    and exists (
      select 1
      from public.jobs j
      where j.id::text = (storage.foldername(name))[1]
        and (j.customer_id = auth.uid() or j.driver_id = auth.uid())
    )
  );
