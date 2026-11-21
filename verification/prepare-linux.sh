#!/usr/bin/env bash
# Run from a dedicated working directory with this script and Statement.lean together.
set -euo pipefail
work=$(pwd -P)
scripts=$(cd "$(dirname "$0")" && pwd -P)
export LEAN_ABORT_ON_PANIC=1 LAKE_ARTIFACT_CACHE=false
export MATHLIB_CACHE_DIR="$work/downloads/mathlib-cache"
export MATHLIB_CACHE_GET_URL=https://cache.mathlib.org/mathlib4
ulimit -n 65536
mkdir -p downloads tools reference/src results

checked() {
    printf '%s  %s\n' "$1" "$2" | sha256sum -c -
}

download() {
    curl --fail --location --silent --show-error --connect-timeout 30 --retry 4 "$1" -o "$2.partial"
    mv "$2.partial" "$2"
}

checkout() {
    local dest=$1 url=$2 revision=$3
    if [[ ! -d "$dest/.git" ]]; then
        git init -q "$dest"
        git -C "$dest" remote add origin "$url"
    fi
    if ! git -C "$dest" cat-file -e "$revision^{commit}" 2>/dev/null; then
        git -C "$dest" -c protocol.version=2 fetch -q --depth 1 origin "$revision"
    fi
    git -C "$dest" checkout -q --detach "$revision"
    test "$(git -C "$dest" rev-parse HEAD)" = "$revision"
}

for version in 4.33.1 4.36.0; do
    archive="lean-$version-linux.tar.zst"
    if [[ ! -s "downloads/$archive" ]]; then
        download "https://github.com/leanprover/lean4/releases/download/v$version/$archive" "downloads/$archive"
    fi
    case "$version" in
        4.33.1) digest=890afd185370f85666025b883914ab4f4b339136f8c96167b69cfb62aecaf235 ;;
        4.36.0) digest=2b7ab1ed8b92d2e6abfaf41344823b510064dbc9c0260cac73eb496ab2dea6eb ;;
    esac
    checked "$digest" "downloads/$archive"
    if [[ ! -f "tools/$version.extracted" ]]; then
        tar --zstd -xf "downloads/$archive" -C tools
        touch "tools/$version.extracted"
    fi
done
buildbin="$work/tools/lean-4.33.1-linux/bin"
judgebin="$work/tools/lean-4.36.0-linux/bin"
export PATH="$buildbin:$PATH"
"$buildbin/lean" --version
"$judgebin/lean" --version

for n in $(seq -w 1 14); do
    part="lean.tar.gz.part$n"
    [[ -s "downloads/$part" ]] || download "https://alpo.ge/$part" "downloads/$part"
done
cat downloads/lean.tar.gz.part{01..14} > downloads/lean.tar.gz
checked 9631b4f020199e580ba86178cb56c6e9b09f690c2369a80dc4334aa93f49c7fc downloads/lean.tar.gz
if [[ ! -f results/source-extracted ]]; then
    tar -xzf downloads/lean.tar.gz
    touch results/source-extracted
fi
mirror=https://raw.githubusercontent.com/leanprover-community/riemann-hypothesis/f28a764e76a18f68680446bf09682c24d1a8b5c4
for file in src/Challenge.lean export-targets.txt comparator.json; do
    name=${file##*/}
    [[ -s "$name" ]] || download "$mirror/$file" "$name"
done
checked a3cebbf30be6b9268a0ed413c9bbc256dfa9f4bfa04f1a75f144d135da5e21a5 Challenge.lean
checked 9eeb2e5e55be4a78f6e4983fc950dba915b45ad8aeb7a02a32341927a89e05e8 export-targets.txt
checked 8ea890e6ccda9cf3983ada343af18a41d12542036875a3936e7925ed5b1582ff comparator.json
cp Challenge.lean reference/src/
cp lean/lake-manifest.json lean/lean-toolchain reference/
cp lean/lakefile.toml reference/lakefile.toml
printf '\n[[lean_lib]]\nname = "Challenge"\n' >> reference/lakefile.toml
mkdir -p reference/.lake/packages
python3 -c 'import json; print("\n".join(" ".join([p["name"],p["url"],p["rev"]]) for p in json.load(open("reference/lake-manifest.json"))["packages"]))' > results/dependencies.txt
while read -r name url revision; do
    checkout "reference/.lake/packages/$name" "$url" "$revision"
done < results/dependencies.txt
checkout tools/exporter https://github.com/leanprover/lean4export 15f6055e299ad5b89345e533cc2192f4cc00f659
checkout tools/con-leche https://github.com/leanprover/con-leche 5dc36dc15b7bee891a02406b78a8ac816a47baad
(cd tools/exporter && lake build) > results/exporter-build.log 2>&1
(cd tools/con-leche && PATH="$judgebin:$PATH" "$judgebin/lake" build con-leche) > results/checker-build.log 2>&1
(cd reference && lake exe mathlib/cache get) > results/mathlib-cache.log 2>&1
(cd reference && lake env lean "$scripts/Statement.lean" && lake build Challenge) > results/challenge-build.log 2>&1
mapfile -t targets < <(tr '[:space:]' '\n' < export-targets.txt | sed '/^$/d')
(cd reference && lake env "$work/tools/exporter/.lake/build/bin/lean4export" Challenge -- "${targets[@]}") > results/challenge.ndjson
checked bd484ac9886a96f26b1d9a7a59ebd45b7a70d102c015d4f31f9302bbdd6ab2b9 results/challenge.ndjson
touch results/challenge-matched
