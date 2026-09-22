# Command reference

Set `SESSION_LEDGER_DIR` or pass global `--dir PATH` before the command.

| Command | Output |
| --- | --- |
| `append EVENT ID [key=value ...]` | Exact appended JSON row after readback |
| `read` (alias `list`) | All individual rows in append order, JSONL |
| `history ID` | Exact identity's chronological rows, JSONL |
| `latest ID` | Latest chronological row, or an empty stream |
| `live` | Merged projection for each live session, JSONL |
| `validate` | Record count after full validation |
| `path` | Selected ledger filename without creating it |

Append accepts `--ts YYYY-MM-DDTHH:MM:SSZ` for backfill and `--by ID` for authorship. `SESSION_LEDGER_BY` supplies optional default authorship; no other session environment variables are consulted. `machine` comes from the current hostname.

Additional metadata uses identifier-shaped keys. Boolean words become JSON booleans; unsigned decimal integers without leading zeros become numbers; everything else stays a string, including numeric-looking values ending in a newline. Empty values are omitted. jq's numeric precision limits apply. `superseded_by` is an exact identifier. Computed envelope/projection fields are reserved so metadata cannot change event, identity, timestamp, sequence, or author.

No history match is a successful empty result. Invalid arguments generally exit 2. Ledger validation, write, or readback failure returns 3. Contention returns 4. Other utility/I/O errors can propagate nonzero status. If stdout fails after mutation, the mutation is not rolled back; inspect storage before retrying.
