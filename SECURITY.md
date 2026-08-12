# Crop Saathi security and privacy notes

This is a hackathon prototype, not a production security assessment.

## Assets

- Farmer observation metadata, symptoms, consent, and approximate location.
- Crop images, including possible faces or unrelated private material.
- Reviewer credentials and verified labels.
- Model and agronomy content packages.

## Trust boundaries

1. The farmer device and its local SQLite database.
2. The public/untrusted network used for synchronization.
3. The FastAPI service and its database/object storage.
4. Verified reviewer/admin accounts.
5. External price and model sources.

## Abuse paths and current mitigations

| Abuse path | Impact | Current mitigation | Production requirement |
| --- | --- | --- | --- |
| Replaying an observation upload | Duplicate labels or review work | Client-generated observation ID and idempotent insert | Authenticated farmer/device identity and signed event sequence |
| Guessing a reviewer endpoint | Unauthorized training labels | Reviewer token dependency; no configured token disables access | OIDC/RBAC, rotation, audit logging, rate limits |
| Uploading private images | Privacy harm | Training consent is explicit; approximate location is optional | Malware scanning, face/PII detection, retention/deletion controls, encryption at rest |
| Tampering with a model package | Wrong diagnosis | Manifest and checksum are specified in the product design | Signed releases, pinned revision, rollback, secure update verification |
| Stale or manipulated prices | Financial loss | Price source/date/unit are retained; stale data forces uncertainty | Server-side source validation, anomaly detection, market/quality adjustment |
| Malicious or malformed JSON | Service failure | Pydantic bounds on key fields | Request-size limits, WAF/rate limiting, dependency scanning |
| Overconfident model result | Crop loss or unsafe chemical use | Mock result abstains; `Invalid` label abstains; UI warns | Field calibration, action-specific cost thresholds, expert escalation |

## Data rules

- Do not collect exact GPS by default.
- Do not use farmer submissions as training truth without reviewer confidence and consent.
- Preserve original model prediction separately from the verified label.
- Give the farmer a deletion/contact path in a production release.
- Do not place API keys, reviewer tokens, or cloud credentials in the Flutter binary.

## Known prototype gaps

- SQLite is used instead of PostgreSQL/object storage.
- Reviewer authentication is a shared development token, not identity management.
- Images are not uploaded by the current API.
- No production TLS termination, rate limiting, malware scanning, or retention job is included.
- The disease model has not been field-validated or calibrated.
