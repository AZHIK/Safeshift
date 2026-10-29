# sos_alert

Escalates a `trip_alerts` row created by the customer or driver app.

- Requires a user JWT (`Authorization: Bearer ...`).
- Verifies the alert belongs to the caller.
- SMSes every emergency contact with `notify_on_sos = true`.
- Pushes on-call admins (`super_admin`, `operations_admin`, `support_agent`).
- Writes every attempt to `notification_log`; provider outages never roll back
  the safety alert itself.

Body: `{ "alert_id": "<uuid>", "job_id": "<uuid optional>", "note": "optional" }`
