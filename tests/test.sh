#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
L="$ROOT/bin/session-ledger"
T="$(mktemp -d "${TMPDIR:-/tmp}/ledger-tests.XXXXXXXX")"
trap 'rm -rf "$T"' EXIT
export SESSION_LEDGER_DIR="$T/store with spaces"
unset SESSION_LEDGER_BY SESSION_LEDGER_LOCK_WAIT_S 2>/dev/null || :
N=0
ok() { N=$((N+1)); printf 'ok %s - %s\n' "$N" "$1"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
reject() { if "$@" >"$T/rejected.out" 2>"$T/rejected.err"; then fail "unexpected success: $*"; fi; }
"$L" --help >/dev/null
reject env -u SESSION_LEDGER_DIR "$L" read
"$L" read >"$T/empty"; [ ! -s "$T/empty" ]
"$L" live >"$T/empty"; [ ! -s "$T/empty" ]
ok 'explicit storage required; empty reads are empty streams'
"$L" append launched run-1 --by supervisor --ts 2025-01-01T00:00:00Z project=demo active=true count=2 leading=007 'note=line one
line two' >"$T/receipt"
jq -e '.event=="launched" and .session_id=="run-1" and .by=="supervisor" and .active==true and .count==2 and .leading=="007" and .note=="line one\nline two" and .seq==1' "$T/receipt" >/dev/null
"$L" read >"$T/read"; cmp "$T/read" "$T/receipt"
ok 'typed metadata and multiline strings round trip in one physical JSONL row'
for arg in 'event=finished' 'session_id=other' 'seq=9' 'ts=bad' 'machine=bad' 'by=bad' '=bad' 'bad'; do reject "$L" append launched valid "$arg"; done
for sid in '../escape' 'run space' '' '.hidden'; do reject "$L" append launched "$sid"; done
for stamp in 2025-02-30T00:00:00Z 2025-01-01T25:00:00Z 2025-01-01T00:00:00+00:00 nonsense; do reject "$L" append launched valid --ts "$stamp"; done
reject "$L" append invented valid
reject "$L" append launched valid --by '../bad'
reject "$L" append superseded valid superseded_by=../bad
"$L" read >"$T/read"; cmp "$T/read" "$T/receipt"
ok 'reserved fields, identifier traversal, invalid timestamps and events rejected before write'
# Full IDs that share a prefix remain independent and lookups are exact.
a=12345678-aaaa-aaaa-aaaa-aaaaaaaaaaaa
b=12345678-bbbb-bbbb-bbbb-bbbbbbbbbbbb
"$L" append launched "$a" >/dev/null
"$L" append launched "$b" >/dev/null
"$L" history 12345678 >"$T/prefix"; [ ! -s "$T/prefix" ]
"$L" history "$a" | jq -se --arg id "$a" 'length==1 and .[0].session_id==$id' >/dev/null
ok 'full identifiers with a shared prefix do not alias'
"$L" append finished run-1 --ts 2025-01-01T00:00:01Z >/dev/null
"$L" append answered run-1 --ts 2025-01-01T00:00:02Z >/dev/null
"$L" live | jq -se 'all(.[]; .session_id != "run-1")' >/dev/null
"$L" append unreaped run-1 --ts 2025-01-01T00:00:03Z >/dev/null
"$L" live | jq -se 'any(.[]; .session_id=="run-1" and .lifecycle_event=="unreaped" and .project=="demo")' >/dev/null
"$L" append needs_input orphan >/dev/null
"$L" live | jq -se 'all(.[]; .session_id != "orphan")' >/dev/null
ok 'terminal lifecycle persists through annotations; explicit unreaped restores liveness'
"$L" append parked run-1 --ts 2025-01-01T00:00:03Z >/dev/null
"$L" latest run-1 | jq -e '.event=="parked"' >/dev/null
"$L" append reaped run-1 --ts 2024-12-31T23:59:59Z >/dev/null
"$L" latest run-1 | jq -e '.event=="parked"' >/dev/null
"$L" history run-1 | jq -se '.[0].event=="reaped" and .[-1].event=="parked"' >/dev/null
"$L" live | jq -se 'any(.[]; .session_id=="run-1" and .last_event=="parked" and .lifecycle_event=="unreaped")' >/dev/null
ok 'timestamp order supports backfill; sequence deterministically breaks same-second ties'
export SESSION_LEDGER_DIR="$T/concurrent"
pids=()
for i in $(seq 1 24); do "$L" append launched "worker-$i" --ts 2025-01-01T00:00:00Z >"$T/append.$i" & pids+=("$!"); done
for pid in "${pids[@]}"; do wait "$pid"; done
"$L" read | jq -se 'length==24 and (map(.seq)|unique|length)==24 and (map(.session_id)|unique|length)==24' >/dev/null
"$L" validate >"$T/validated"
grep 'valid: 24 records' "$T/validated" >/dev/null
ok '24 concurrent appends produce complete rows and unique contiguous sequence numbers'
mkdir "$SESSION_LEDGER_DIR/.ledger.lock"
printf '%s\n' "$$" >"$SESSION_LEDGER_DIR/.ledger.lock/pid"
cp -f "$SESSION_LEDGER_DIR/ledger.jsonl" "$T/before"
set +e
SESSION_LEDGER_LOCK_WAIT_S=0 "$L" append finished worker-1 >"$T/locked" 2>/dev/null; rc=$?
set -e
[ "$rc" = 4 ] && [ ! -s "$T/locked" ]
cmp "$SESSION_LEDGER_DIR/ledger.jsonl" "$T/before"
set +e; SESSION_LEDGER_LOCK_WAIT_S=0 "$L" read >/dev/null 2>&1; rc=$?; set -e
[ "$rc" = 4 ]
rm -f "$SESSION_LEDGER_DIR/.ledger.lock/pid"; rmdir "$SESSION_LEDGER_DIR/.ledger.lock"
ok 'contention blocks writers and readers without unlocked fallback'
printf '{partial' >>"$SESSION_LEDGER_DIR/ledger.jsonl"
cp -f "$SESSION_LEDGER_DIR/ledger.jsonl" "$T/corrupt"
reject "$L" append finished worker-1
[ ! -s "$T/rejected.out" ]; cmp "$SESSION_LEDGER_DIR/ledger.jsonl" "$T/corrupt"
reject "$L" read
[ ! -d "$SESSION_LEDGER_DIR/.ledger.lock" ]
ok 'incomplete tail refuses append/read and preserves forensic bytes'
export SESSION_LEDGER_DIR="$T/bad-schema"
mkdir -p "$SESSION_LEDGER_DIR"
printf '%s\n' '{"event":"launched","session_id":"valid","seq":1}' >"$SESSION_LEDGER_DIR/ledger.jsonl"
reject "$L" validate
reject "$L" append finished valid
ok 'well-formed JSON with invalid schema cannot enter a projection or accept appends'
# Pause jq after lock acquisition, before any append. Signals are coordinated by PID.
mkdir "$T/shims"
export REAL_JQ="$(command -v jq)" INTERRUPT_MARKER="$T/paused"
cat >"$T/shims/jq" <<'SHIM'
#!/usr/bin/env bash
if [ "${1:-}" = 'length + 1' ]; then
  printf '%s\n' "$$" >"$INTERRUPT_MARKER"
  kill -STOP "$$"
fi
exec "$REAL_JQ" "$@"
SHIM
chmod +x "$T/shims/jq"
export SESSION_LEDGER_DIR="$T/interrupted"
PATH="$T/shims:$PATH" "$L" append launched interrupted >"$T/interrupted.out" 2>"$T/interrupted.err" & writer=$!
for i in $(seq 1 200); do [ -s "$INTERRUPT_MARKER" ] && break; sleep .02; done
[ -s "$INTERRUPT_MARKER" ]
read -r shim <"$INTERRUPT_MARKER"
kill -TERM "$writer"
kill -CONT "$shim"
set +e; wait "$writer"; rc=$?; set -e
[ "$rc" = 143 ] && [ ! -s "$T/interrupted.out" ] && [ ! -e "$SESSION_LEDGER_DIR/ledger.jsonl" ] && [ ! -d "$SESSION_LEDGER_DIR/.ledger.lock" ]
"$L" append launched recovered >/dev/null
ok 'TERM before append leaves no row or receipt and releases lock'
# Readback failures must never produce a success receipt, although the row exists.
mkdir "$T/readback-shim"
printf '#!/usr/bin/env bash\nexit 2\n' >"$T/readback-shim/grep"
chmod +x "$T/readback-shim/grep"
export SESSION_LEDGER_DIR="$T/readback"
set +e
PATH="$T/readback-shim:$PATH" "$L" append launched unverified >"$T/unverified.out" 2>/dev/null; rc=$?
set -e
[ "$rc" = 3 ] && [ ! -s "$T/unverified.out" ] && [ ! -d "$SESSION_LEDGER_DIR/.ledger.lock" ]
"$L" read | jq -e '.session_id=="unverified"' >/dev/null
ok 'readback error returns failure without receipt and leaves inspectable appended row'
export SESSION_LEDGER_DIR="$T/symlink"
mkdir "$SESSION_LEDGER_DIR"
ln -s "$T/readback/ledger.jsonl" "$SESSION_LEDGER_DIR/ledger.jsonl"
reject "$L" append launched unsafe
ok 'symlink ledger refused'
export SESSION_LEDGER_DIR="$T/numeric-identity"
"$L" append superseded 123 superseded_by=456 >/dev/null
"$L" history 123 | jq -e '.session_id=="123" and .superseded_by=="456"' >/dev/null
ok 'numeric-looking identifiers remain strings in identity metadata'
export SESSION_LEDGER_DIR="$T/sequence"
"$L" append launched valid >/dev/null
jq -c '.seq=2' "$SESSION_LEDGER_DIR/ledger.jsonl" >"$T/wrong-sequence"
cp -f "$T/wrong-sequence" "$SESSION_LEDGER_DIR/ledger.jsonl"
reject "$L" validate
reject "$L" append finished valid
cmp "$T/wrong-sequence" "$SESSION_LEDGER_DIR/ledger.jsonl"
ok 'sequence discontinuity blocks appends without silently renumbering data'
export SESSION_LEDGER_DIR="$T/newline-identities"
reject "$L" append launched $'identity\n'
reject "$L" append launched good --by $'author\n'
reject "$L" append superseded good superseded_by=$'replacement\n'
[ ! -e "$SESSION_LEDGER_DIR/ledger.jsonl" ]
"$L" append launched valid >/dev/null
jq -c '.session_id="valid\n"' "$SESSION_LEDGER_DIR/ledger.jsonl" >"$T/newline-row"
cp -f "$T/newline-row" "$SESSION_LEDGER_DIR/ledger.jsonl"
reject "$L" read
reject "$L" append finished valid
cmp "$T/newline-row" "$SESSION_LEDGER_DIR/ledger.jsonl"
ok 'trailing-newline identities are rejected in arguments and stored records'
export SESSION_LEDGER_DIR="$T/broken-pipe"
big="$(printf '%100000s' x)"
set +e
"$L" append launched pipe-receipt "note=$big" 2>"$T/pipe.err" | head -c 1 >/dev/null
rc=${PIPESTATUS[0]}
set -e
[ "$rc" -ne 0 ] && [ ! -d "$SESSION_LEDGER_DIR/.ledger.lock" ]
"$L" read | jq -e '.session_id=="pipe-receipt" and (.note|length)==100000' >/dev/null
"$L" validate >/dev/null
ok 'broken receipt pipe reports failure while retaining the complete appended row'
mkdir "$T/readback-pause"
export REAL_GREP="$(command -v grep)" READBACK_MARKER="$T/readback-paused"
cat >"$T/readback-pause/grep" <<'SHIM'
#!/usr/bin/env bash
printf '%s\n' "$$" >"$READBACK_MARKER"
kill -STOP "$$"
exec "$REAL_GREP" "$@"
SHIM
chmod +x "$T/readback-pause/grep"
export SESSION_LEDGER_DIR="$T/readback-interrupted"
PATH="$T/readback-pause:$PATH" "$L" append launched written-before-signal >"$T/readback-interrupted.out" 2>"$T/readback-interrupted.err" & writer=$!
for i in $(seq 1 200); do [ -s "$READBACK_MARKER" ] && break; sleep .02; done
[ -s "$READBACK_MARKER" ]; read -r shim <"$READBACK_MARKER"
kill -TERM "$writer"; kill -CONT "$shim"
set +e; wait "$writer"; rc=$?; set -e
[ "$rc" = 143 ] && [ ! -s "$T/readback-interrupted.out" ] && [ ! -d "$SESSION_LEDGER_DIR/.ledger.lock" ]
"$L" read | jq -e '.session_id=="written-before-signal" and .seq==1' >/dev/null
ok 'TERM after append but before readback receipt retains the complete row and releases lock'
export SESSION_LEDGER_DIR="$T/literal-metadata"
"$L" append launched literal note=$'123\n' >"$T/literal-metadata.out"
jq -e '.note=="123\n"' "$T/literal-metadata.out" >/dev/null
ok 'newline-bearing numeric-looking metadata remains an exact string'
printf '1..%s\n' "$N"
