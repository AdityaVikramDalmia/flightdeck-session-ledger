# Storage, concurrency, and recovery

The chosen directory contains `ledger.jsonl` and a transient `.ledger.lock/` directory. The tool sets umask `077`. Use trusted local storage controlled by one OS account. Network filesystems and multiple machines sharing storage are unsupported. The directory and ledger themselves cannot be symlinks; ancestor paths and external mutations remain the operator's responsibility. The protocol is advisory, not a security boundary against processes that bypass it.

Every append assembles and validates a compact JSON object before acquiring the lock. Under the lock it parses and validates the existing ledger, checks contiguous sequence numbers, allocates the next number, validates the final record, appends one newline-terminated row, and verifies that exact row exists. Only then does it print the JSON receipt. All reads acquire the same lock, load and validate a consistent snapshot into memory, release the lock, and render the result. Empty storage reads as an empty ledger.

No unlocked fallback exists. `SESSION_LEDGER_LOCK_WAIT_S` (default 10; accepted range 0–86400) bounds lock wait; contention returns 4. Whole-ledger validation on every append and read is O(number of stored records), and reads hold a complete snapshot in memory. This small local control-state tool is not intended as a high-throughput event store. Long rows are limited by shell/OS argument size and available memory.

Writes are append-only during ordinary operation. There is no cross-file transaction, fsync, power-loss durability guarantee, or exactly-once retry guarantee. A process can die after appending but before printing its receipt. A write error can leave part of a line. On a nonzero result, inspect the ledger before retrying: absence of a receipt does not prove absence of a row. A duplicate retry becomes a second event with another sequence number.

An incomplete final line, malformed JSON, invalid record, or sequence discontinuity blocks reads and later appends. The tool never silently drops or repairs data. Recovery requires stopping all users, preserving a backup, inspecting the bytes, and deliberately restoring a valid ledger. Preserve the backup as evidence. If you remove an incomplete final row, retry only after determining that the desired event is absent. Corrections to valid historical reports should normally be new events, not edits.

EXIT, INT, HUP, and TERM handlers release the owned lock when Bash can execute traps. SIGKILL, machine failure, or interruption during acquisition can leave a lock. Automatic stale recovery is deliberately absent: a timeout or process-id reuse must never let a contender remove a live holder's lock.

For a stale lock, stop **all** processes using the directory first. Inspect `.ledger.lock/pid`, confirm the prior holder has stopped, remove the `pid` file, then remove the empty directory with `rmdir`. Validate the ledger before restarting writers. Never delete locks while any caller is still running. A blocked child or output stream can delay when Bash executes its signal trap.

Back up the complete directory with users stopped. Do not append using another tool, rotate/truncate an active ledger, or rely on a `tail` reader to participate in the locking contract.
