# data-export

Builds a ZIP archive of a profile's SafeShift data and returns a short-lived signed download URL.

- **Auth:** bearer JWT. A caller may export their own data by `profile_id` or by their own
  `request_id`; exporting another profile or fulfilling another profile's request requires
  `manage_data_requests`.
- **Method:** `POST`.
- **Body:** `{ request_id }` or `{ profile_id }`.
- **Response:** `{ request_id, download_url, expires_at }`.

The archive contains profile, addresses, business memberships, driver documents, jobs, payments,
ratings, disputes, support tickets, chat messages, consent records, wallet transactions, payouts,
notification log, push tokens, and the request history. Files are written to the `data-exports`
Storage bucket and linked for seven days. The data subject request is marked `completed` with
`delivered_file_path`; `scheduled-retention` removes expired archives.

`PUBLIC_SUPABASE_URL` rewrites the signed URL host for local development. The local runtime reaches
Storage through `http://kong:8000`, which is not reachable from a developer machine; the placeholder
env sets it to `http://127.0.0.1:54321`. In production the value is unset and the Storage URL is
returned unchanged.
