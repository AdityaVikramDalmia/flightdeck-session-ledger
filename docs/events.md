# Events, identity, and projections

The lifecycle subset is `launched`, `adopted`, `unreaped`, `finished`, `reaped`, and `superseded`.

| Event | Intended report | Lifecycle effect |
| --- | --- | --- |
| `launched` | Caller started a session | Live |
| `adopted` | Caller registers an already-existing session | Live |
| `unreaped` | Caller corrects a prior retirement | Live |
| `finished` | Work completed | Terminal |
| `reaped` | Caller retired or stopped a session | Terminal |
| `superseded` | Another session replaced this one | Terminal |

Other events (`needs_input`, `answered`, `stalled`, `near_full`, `conflict`, `lane_done`, `parked`) are observations and do not change lifecycle status. For example, `finished` followed by `answered` remains terminal. A session with only observation events is not live because no lifecycle event establishes it.

`live` groups by exact session id, sorts each history by UTC timestamp then sequence number, and examines its latest lifecycle event. It emits one merged object per live session. Fields from later rows replace earlier fields with the same name. `last_event` names the latest observation or lifecycle event; `lifecycle_event` names the event establishing current liveness. The ordinary `event`, `ts`, and `seq` belong to the latest chronological row. Missing metadata does not clear earlier metadata. This projection is a convenience view, not an OS process scan.

`latest` returns the latest individual chronological row, without merging metadata. `history` returns individual rows in timestamp/sequence order. `read` returns physical append order. A historical timestamp can place a newly appended row earlier in a projection. Same-second events are ordered by their serialized sequence, not incidental sort stability.

Identifiers contain 1–128 ASCII characters, start with a letter or digit, and then use letters, digits, `.`, `_`, `:`, or `-`. The whole identifier must match this grammar; a trailing newline is invalid.
They are case-sensitive and preserved exactly. A short identifier is a separate identity from a UUID beginning with that prefix. The ledger has no automatic prefix resolution, transcript lookup, external registry, or roster conventions.

Timestamps use `YYYY-MM-DDTHH:MM:SSZ` and must round-trip through jq's UTC date conversion; invalid calendar dates are rejected. Caller-provided backfills change chronological projections, so use them intentionally. Events are reports accepted from callers; the ledger does not enforce a state machine or require a previous launch before a terminal row.
