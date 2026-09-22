def events: ["launched", "adopted", "unreaped", "needs_input", "answered", "stalled", "near_full", "conflict", "lane_done", "parked", "finished", "reaped", "superseded"];
def lifecycle: ["launched", "adopted", "unreaped", "finished", "reaped", "superseded"];
def terminal: ["finished", "reaped", "superseded"];
def valid_id: type == "string" and test("\\A[A-Za-z0-9][A-Za-z0-9._:-]{0,127}\\z");
def valid_ts:
  type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$") and
  (. as $s | try ((fromdateiso8601 | strftime("%Y-%m-%dT%H:%M:%SZ")) == $s) catch false);
def valid_row:
  type == "object" and
  (.event as $e | events | index($e) != null) and
  (.session_id | valid_id) and (.ts | valid_ts) and
  (.seq | type == "number" and . > 0 and floor == .) and
  (.machine | type == "string" and length > 0) and
  ((has("by") | not) or (.by | valid_id)) and
  ((has("superseded_by") | not) or (.superseded_by | valid_id));
def ordered: sort_by([.ts, .seq]);
def last_lifecycle: map(select(.event as $e | lifecycle | index($e))) | last;
def live_session:
  (last_lifecycle) as $last |
  $last != null and ($last.event as $e | terminal | index($e) == null);
# Input is raw file text, not a JSON stream: every physical line must be one row.
def read_rows:
  if . == "" then []
  elif endswith("\n") | not then error("ledger has an incomplete final line")
  else split("\n")[:-1] | map(fromjson) |
    if all(.[]; valid_row) and (to_entries | all(.[]; .value.seq == .key + 1)) then .
    else error("invalid record or non-contiguous sequence") end
  end;
