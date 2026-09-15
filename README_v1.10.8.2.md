# FIXIS PRO v1.10.8.2 — Job Intake + Arrival Guard

## Included
- Address reference for hard-to-find homes/passages.
- Optional preferred visit date/time (explicitly not a confirmed appointment).
- Up to 3 initial problem photos, private bucket `job-evidence`.
- `job_attachments` auditable metadata table.
- Backend-authoritative arrival guard using FIXIS Live / PostGIS.
- Arrival audit fields on `jobs`: time, coordinates, accuracy and measured distance.
- Flutter refreshes current GPS immediately before requesting `mark_arrived`.
- Existing commission/snapshot/ledger logic is not modified.

## QA thresholds
- Arrival radius: 200 meters.
- Maximum GPS accuracy value: 100 meters.
- Maximum age of last live location: 120 seconds.

These are QA parameters and may be tuned after physical testing.

## Apply order
1. Backup / staging first.
2. Run `migrations/018_job_intake_arrival_guard_v1_10_8_2.sql`.
3. Run `migrations/VALIDATION_018_v1_10_8_2.sql`.
4. `flutter pub get`
5. `flutter analyze`
6. Physical test: create job, attach photos, start route, attempt arrival far away, attempt arrival near service point.

## Not included yet
- Confirmed appointment negotiation.
- Revised quote / change order.
- No-contact SLA/reassignment.
- Legal onboarding.
