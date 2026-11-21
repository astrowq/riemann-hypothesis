#!/usr/bin/env bash
# Run after prepare-linux.sh from the same working directory.
set -euo pipefail
work=$(pwd -P)
scripts=$(cd "$(dirname "$0")" && pwd -P)
judgebin="$work/tools/lean-4.36.0-linux/bin"
checker="$work/tools/con-leche/.lake/build/bin/con-leche"
export LEAN_ABORT_ON_PANIC=1 LAKE_ARTIFACT_CACHE=false
ulimit -n 65536
mkdir -p results downloads
exec 9>results/audit.lock
flock -n 9

checked() {
    printf '%s  %s\n' "$1" "$2" | sha256sum -c -
}

timed() {
    local status=0
    { time -p "$@"; } || status=$?
    printf 'Exit status: %d\n' "$status" >&2
    return "$status"
}
solution_hash=5ea74b912147c5c93cc2b6d70cc727cf908df2f62ac6a20480a3fa02f6be244e
if [[ ! -s downloads/solution.ndjson.zst ]]; then
    curl --fail --location --silent --show-error --connect-timeout 30 --retry 4 -C - \
        https://math.mit.edu/~drew/grh/solution.ndjson.zst -o downloads/solution.ndjson.zst.partial
    mv downloads/solution.ndjson.zst.partial downloads/solution.ndjson.zst
fi
checked 61a8938ad5f5e57397c1c0e3b954916af546d9004ade01c3555744a681b05381 downloads/solution.ndjson.zst
if [[ ! -s results/published.ndjson ]]; then
    zstd -dc --long=30 downloads/solution.ndjson.zst > results/published.ndjson.partial
    mv results/published.ndjson.partial results/published.ndjson
fi
checked "$solution_hash" results/published.ndjson
if [[ -n "${1:-}" ]]; then
    while tmux has-session -t "$1" 2>/dev/null; do sleep 20; done
fi
checked bd484ac9886a96f26b1d9a7a59ebd45b7a70d102c015d4f31f9302bbdd6ab2b9 results/challenge.ndjson
if [[ ! -f results/published-accepted ]]; then
    timed "$checker" --jobs=24 --progress=5% --compare results/challenge.ndjson results/published.ndjson > results/published-compare.log 2>&1
    grep -F 'theorem riemannHypothesis justified by the solution' results/published-compare.log
    touch results/published-accepted
fi

bash "$scripts/build-source.sh"
timed "$checker" --jobs=24 --progress=5% --compare results/challenge.ndjson results/rebuilt.ndjson > results/rebuilt-compare.log 2>&1
grep -F 'theorem riemannHypothesis justified by the solution' results/rebuilt-compare.log
(cd results && PATH="$judgebin:$PATH" timed "$judgebin/lake" comparator --config ../comparator.json \
    --challenge-from-export challenge.ndjson --solution-from-export rebuilt.ndjson) > results/comparator.log 2>&1
checked "$solution_hash" results/rebuilt.ndjson
touch results/rebuild-and-replay-complete
