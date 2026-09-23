# session-ledger

> **Deprecated for new Claude Code integrations — 2026-09-22.** Retained as an
> Apache-2.0 public reference implementation. This is a maintainer status
> decision, not a claim that Claude
> Code replaces every capability. No ongoing feature work or support is promised.

An append-only JSONL lifecycle ledger for shell programs. Record launches, observations, and completion; query exact session history or a current live-session projection. It makes no network or model calls and discovers no global sessions.

Requires Bash 3.2+, jq 1.6+, and standard macOS/Linux command-line utilities. `make` runs the tests; Git is not a runtime dependency. Keep `bin/` and `lib/` together. From a checkout:

```bash
export PATH="$PWD/bin:$PATH"
export SESSION_LEDGER_DIR="$PWD/.session-ledger-data"
session-ledger append launched worker-1 --by supervisor project=example
session-ledger append needs_input worker-1 'note=Waiting for review'
session-ledger live
session-ledger append finished worker-1 result=passed
session-ledger history worker-1
session-ledger validate
make test
```

Or pass `session-ledger --dir '/path with spaces/state' ...` on each call. `bash examples/lifecycle.sh` runs a complete isolated example.

All reads and appends serialize through a storage-local lock. Appends print a JSON receipt only after a checked write and exact readback. Lock contention fails closed. Identifiers remain exact, including full UUIDs; shared prefixes never merge two sessions. A record describes a caller's report, not proof that an OS process exists or has stopped.

See [documentation](docs/README.md) for the event model, storage contract, and recovery. [Provenance](PROVENANCE.md) records the extraction and deliberate changes. Licensed under Apache-2.0; see [LICENSE](LICENSE) and [NOTICE](NOTICE). The repository is public.

## License and maintenance

Copyright 2026 Aditya Dalmia. Licensed under [Apache-2.0](LICENSE), with
[attribution](NOTICE) and [source provenance](PROVENANCE.md). This is a public
reference implementation, deprecated for new Claude Code integrations as of 2026-09-22. See the [release preparation index](docs/release/README.md),
[contributing guide](CONTRIBUTING.md), and [security contact](SECURITY.md).
