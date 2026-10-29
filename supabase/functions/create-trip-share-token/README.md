# create-trip-share-token

Creates a 24-hour bearer token for the public trip tracking page.

Body: `{ "job_id": "<uuid>" }`

The RPC `public.create_trip_share_token` verifies that the caller is the job's
customer or driver. The response contains `token`, `expires_at`, and
`share_url` (`PUBLIC_TRACKING_BASE_URL` + token).
