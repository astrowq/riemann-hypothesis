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
if [[ -n ${RH_READ_SMALL_IMPORTS:-} ]]; then
    scripts=$(cd "$(dirname "$0")" && pwd -P)
    isolate+=(--ro-bind "$scripts/read_small_imports.py" /opt/read-small-imports.py
        --setenv GLIBC_TUNABLES glibc.malloc.mmap_max=0:glibc.malloc.arena_max=1
        --setenv MIMALLOC_RESERVE_OS_MEMORY 4GiB
        /usr/bin/python3 /opt/read-small-imports.py)
    export_read_bytes=$RH_READ_SMALL_IMPORTS
    if [[ $RH_READ_SMALL_IMPORTS == 1048576 ]]; then
        export_read_bytes=589824
    fi
    export_isolate=("${isolate[@]}" "$export_read_bytes")
    isolate+=("$RH_READ_SMALL_IMPORTS")
else
    export_isolate=("${isolate[@]}")
fi
if [[ ! -f results/source-built ]]; then
    lake_build=(lake build Main)
    if [[ ${RH_READ_SMALL_IMPORTS:-} == 1048576 ]]; then
        lake_build=(/usr/bin/env LEAN_NUM_THREADS=1 "${lake_build[@]}")
        echo 'Compiling large imports with one Lake worker in the 1 MiB pass.' >&2
    fi
    { time -p "${isolate[@]}" "${lake_build[@]}"; } >> results/source-build.log 2>&1
    test -s lean/.lake/build/lib/lean/Main.olean
    touch results/source-built
fi
if [[ "${1:-}" == --build-only ]]; then exit 0; fi

printf 'import Main\n#print riemannHypothesis\n#print axioms riemannHypothesis\n' > lean/AuditRH.lean
"${isolate[@]}" lake env lean AuditRH.lean > results/axioms.log 2>&1
python3 -c 'import re; from pathlib import Path; s=Path("results/axioms.log").read_text(); m=re.search(r"\x27riemannHypothesis\x27 depends on axioms: \[([^\]]*)\]",s); assert m and set(m[1].split(", ")) == {"propext","Classical.choice","Quot.sound"}, s'
mapfile -t targets < <(tr '[:space:]' '\n' < export-targets.txt | sed '/^$/d')
if [[ ! -f results/rebuilt.ndjson ]]; then
    emit_proof() {
        time -p "$@" lake env /opt/lean4export Main -- "${targets[@]}"
    }
    status=0
    echo "Exporting Main with file-read threshold ${export_read_bytes:-default}." >&2
    emit_proof "${export_isolate[@]}" > results/rebuilt.ndjson.partial 2> results/rebuilt-export.log || status=$?
    if ((status)); then
        if [[ ${export_read_bytes:-} != 589824 || ${RH_READ_SMALL_IMPORTS:-} != 1048576 || -s results/rebuilt.ndjson.partial ]] ||
           ! grep -Eq 'failed to read (file )?.*\.olean' results/rebuilt-export.log; then
            exit "$status"
        fi
        failure_log=$(mktemp results/rebuilt-export-576k-import-XXXXXXXX.log)
        cp results/rebuilt-export.log "$failure_log"
        echo "The 576 KiB export stopped during import before emitting data. Retrying at 1 MiB. Evidence in $failure_log." >&2
        emit_proof "${isolate[@]}" > results/rebuilt.ndjson.partial 2> results/rebuilt-export.log
    fi
    mv results/rebuilt.ndjson.partial results/rebuilt.ndjson
fi
sha256sum results/rebuilt.ndjson > results/rebuilt.sha256
