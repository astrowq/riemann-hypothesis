#!/usr/bin/env bash
# Run from the original build directory. The sole argument names a private evidence directory.
set -euo pipefail
root=$(pwd -P)
out=$(realpath -e -- "$1")
results="$root/results"
judgebin="$root/tools/lean-4.36.0-linux/bin"
exec >> "$out/run.log" 2>&1
date -Is
exec 9>"$results/audit.lock"
flock -n 9
export PATH="$judgebin:$PATH" LEAN_ABORT_ON_PANIC=1 COMPARATOR_BWRAP="$out/tuned-bwrap"
unset MIMALLOC_GENERIC_COLLECT
ulimit -n 65536
check_inputs() {
    sha256sum --check "$out/inputs.sha256"
}
check_inputs
sha256sum --check "$out/tools.sha256"
stat -c '%d %i %s %y %z %n' results/rebuilt.ndjson results/challenge.ndjson > "$out/before.stat"
date -Is
cd "$results"
status=0
{ time -p "$judgebin/lake" comparator --config ../comparator.json --challenge-from-export challenge.ndjson --solution-from-export rebuilt.ndjson; } > "$out/comparator.log" 2>&1 || status=$?
printf 'Exit status: %d\n' "$status" >> "$out/comparator.log"
date -Is
if (( status != 0 )); then
    exit "$status"
fi
python3 - "$out/comparator.log" <<'PY'
from pathlib import Path
import sys
lines = Path(sys.argv[1]).read_text().splitlines()
expected = []
for name in ('Lean paranoid', 'nanoda', 'Lean default'):
    expected.extend((f'Running {name} kernel on solution', f'{name} kernel accepts the solution'))
expected.extend(('Your solution is okay!', 'Exit status: 0'))
if [s for s in lines if s in expected] != expected or lines[-1] != expected[-1]:
    sys.exit('The complete ordered sequence of kernel verdicts is missing')
PY
cd "$root"
check_inputs
sha256sum --check "$out/tools.sha256"
stat -c '%d %i %s %y %z %n' results/rebuilt.ndjson results/challenge.ndjson > "$out/after.stat"
cmp "$out/before.stat" "$out/after.stat"
date -Is
touch "$out/accepted"
