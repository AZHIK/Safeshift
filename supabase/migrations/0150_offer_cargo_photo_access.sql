-- A driver must be able to review the customer's parcel photos before
-- accepting the offer. At that point jobs.driver_id is still unset: the only
-- link between the driver and the job is the pending job_offers row. Allow
-- reading objects under <job_id>/ for the driver who holds a live offer.

drop policy if exists job_evidence_storage_select on storage.objects;

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
           or exists (
             select 1
               from public.job_offers o
              where o.job_id = j.id
                and o.driver_id = auth.uid()
                and o.response = 'pending'
                and o.expires_at > now()
           )
           or (select public.has_permission('view_all_jobs'))
         )
    )
  );
