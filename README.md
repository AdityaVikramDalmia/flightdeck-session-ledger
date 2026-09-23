# session-ledger

An append-only JSONL ledger of process and session lifecycle events for shell
programs: record launches, observations, and completion, then query exact session
history or a current live-session projection. It tracks what sessions did, not what
was decided; for decisions and answers kept in their original wording, see the
separate [Decision Ledger](https://github.com/AdityaVikramDalmia/flightdeck-decision-ledger).

> **Status:** public Apache-2.0 reference implementation, deprecated for new Claude Code
> integrations as of 2026-09-22. Not a claim that Claude Code replaces every capability; no
> ongoing feature work or support is promised.

## What it does

- `append EVENT ID [key=value ...]` adds one event for a session. Lifecycle events
  (`launched`, `adopted`, `unreaped`, `finished`, `reaped`, `superseded`) decide
  whether a session is live; others, such as `needs_input`, are observations.
- `history`, `latest`, `live`, `read`, and `validate` query the ledger.
- It makes no network or model calls and discovers no global sessions.

## Why it exists

A lifecycle ledger is only useful if every row is there and belongs to the right
session. All reads and appends serialize through a storage-local lock, and lock
contention fails closed. Appends print a JSON receipt only after a checked write and
exact readback. Identifiers remain exact, including full UUIDs; shared prefixes
never merge two sessions.

## Install

Requires Bash 3.2+, jq 1.6+, and standard macOS/Linux command-line utilities. `make`
runs the tests; Git is not a runtime dependency. Keep `bin/` and `lib/` together.
From a checkout:

```bash
git clone https://github.com/AdityaVikramDalmia/flightdeck-session-ledger.git
cd flightdeck-session-ledger
export PATH="$PWD/bin:$PATH"
export SESSION_LEDGER_DIR="$PWD/.session-ledger-data"
```

Or pass `session-ledger --dir '/path with spaces/state' ...` on each call.

## Quick use

```bash
session-ledger append launched worker-1 --by supervisor project=example
session-ledger append needs_input worker-1 'note=Waiting for review'
session-ledger live
session-ledger append finished worker-1 result=passed
session-ledger history worker-1
session-ledger validate
```

`bash examples/lifecycle.sh` runs a complete isolated example.

See [documentation](docs/README.md) for the event model, storage contract, and
recovery. [Provenance](PROVENANCE.md) records the extraction and deliberate changes.

## Limits

- A record describes a caller's report, not proof that an OS process exists or has
  stopped.
- Lock contention fails closed (exit 4) instead of writing without the lock.
- Network filesystems and multiple machines sharing storage are unsupported. This
  small local control-state tool is not intended as a high-throughput event store;
  see [storage, concurrency, and recovery](docs/storage.md).

## Test

```bash
make test
```

`make test` checks script syntax with `bash -n`, then runs the synthetic suite in
`tests/test.sh`.

## License and maintenance

Copyright 2026 Aditya Dalmia. Licensed under [Apache-2.0](LICENSE), with
[attribution](NOTICE) and [source provenance](PROVENANCE.md). This is a public
reference implementation, deprecated for new Claude Code integrations as of 2026-09-22. See the [release preparation index](docs/release/README.md),
[contributing guide](CONTRIBUTING.md), and [security contact](SECURITY.md).
