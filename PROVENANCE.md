# Provenance

Extracted from source revision `494799eea3b9e7ce8686506a288c297ccf96be8d`.

- `bin/registry.sh`: lifecycle vocabulary, typed metadata, reserved envelope fields, serialized sequence allocation, checked append, exact readback, and chronological projections.
- `bin/registry-roundtrip-test.sh`: regression scenarios informed the synthetic standalone suite.
- `bin/lib/registry.sh`: latest-lifecycle and terminal-event classification informed `lib/schema.jq`.
- `bin/lib/lock.sh`: advisory-lock integration informed local locking; automatic stale recovery and unlocked fallback were deliberately removed.

The standalone version uses one explicitly selected ledger, exact case-sensitive identifiers (full identifiers are not shortened), stricter record and calendar-date validation, consistent read locking, and no transcript, task-tracker, global roster, or private naming integration. Observation-only sessions do not become live without a lifecycle event. The test fixtures are synthetic; no historical ledger or private metadata was copied. This records provenance, not a license grant.
