#!/usr/bin/env bash
# Use the dedicated audit directory created by prepare-linux.sh.
set -euo pipefail
work=$(pwd -P)
ulimit -n 65536
exec 8>results/source-build.lock
flock 8

# Give the submitted project a separate writable copy of the verified dependencies.
mkdir -p lean/.lake
if [[ ! -f results/build-dependencies-ready ]]; then
    cp -a --reflink=auto reference/.lake/packages lean/.lake/
    touch results/build-dependencies-ready
fi
inside=/home/ubuntu/grh/src/lean
isolate=(bwrap --unshare-all --die-with-parent --new-session --clearenv
    --ro-bind /usr /usr --symlink usr/bin /bin --symlink usr/lib /lib --symlink usr/lib64 /lib64
    --proc /proc --dev /dev --tmpfs /tmp --dir /home/builder
    --ro-bind "$work/tools/lean-4.33.1-linux" /opt/lean
    --ro-bind "$work/tools/exporter/.lake/build/bin/lean4export" /opt/lean4export
    --bind "$work/lean" "$inside" --chdir "$inside"
    --setenv HOME /home/builder --setenv PATH /opt/lean/bin:/usr/bin --setenv LANG C.UTF-8
    --setenv LEAN_ABORT_ON_PANIC 1 --setenv LAKE_ARTIFACT_CACHE false
    --setenv LEAN_NUM_THREADS "${LEAN_NUM_THREADS:-20}")
if [[ ! -f results/source-built ]]; then
    { time -p "${isolate[@]}" lake build Main; } >> results/source-build.log 2>&1
    test -s lean/.lake/build/lib/lean/Main.olean
    touch results/source-built
fi
if [[ "${1:-}" == --build-only ]]; then exit 0; fi

printf 'import Main\n#print riemannHypothesis\n#print axioms riemannHypothesis\n' > lean/AuditRH.lean
"${isolate[@]}" lake env lean AuditRH.lean > results/axioms.log 2>&1
python3 -c 'import re; from pathlib import Path; s=Path("results/axioms.log").read_text(); m=re.search(r"\x27riemannHypothesis\x27 depends on axioms: \[([^\]]*)\]",s); assert m and set(m[1].split(", ")) == {"propext","Classical.choice","Quot.sound"}, s'
mapfile -t targets < <(tr '[:space:]' '\n' < export-targets.txt | sed '/^$/d')
if [[ ! -f results/rebuilt.ndjson ]]; then
    { time -p "${isolate[@]}" lake env /opt/lean4export Main -- "${targets[@]}"; } > results/rebuilt.ndjson.partial 2> results/rebuilt-export.log
    mv results/rebuilt.ndjson.partial results/rebuilt.ndjson
fi
sha256sum results/rebuilt.ndjson > results/rebuilt.sha256
