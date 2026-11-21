#!/usr/bin/env bash
# Verify the final implication from Dirichlet nonvanishing to classical RH.
# Run in the audit work directory after prepare-linux.sh.
set -euo pipefail
work=$(pwd -P)
export PATH="$work/tools/lean-4.33.1-linux/bin:$PATH"
export LEAN_ABORT_ON_PANIC=1 LAKE_ARTIFACT_CACHE=false
out=$(mktemp -d "$work/results/reduction-XXXXXXXX")
mkdir "$out/reference" "$out/solution"
printf '%s\n' "$out"

python3 - "$out" <<'PY'
from pathlib import Path
import sys

out = Path(sys.argv[1])
src = Path("lean/src")
chars = src / "Development/AutomorphicArithmetic/CharacterBoxes/EveryCharacter.lean"
last = src / "Formalism/GammaFactorNonvanishing"

def declaration(path, start):
    source = path.read_text()
    sections = [s for s in source.split("\n\n") if s.startswith(start)]
    if len(sections) != 1:
        raise ValueError(f"Expected exactly one declaration starting {start!r} in {path}")
    return sections[0].strip()

claim = """theorem Verification.rh_from_dirichlet_nonvanishing
    (h : ∀ (N : ℕ) [NeZero N] (χ : DirichletCharacter ℂ N) (s : ℂ),
      1 / 2 < s.re → (χ ≠ 1 ∨ s ≠ 1) → DirichletCharacter.LFunction χ s ≠ 0) :
    RiemannHypothesis"""
(out / "reference/Reduction.lean").write_text("import Mathlib\n\n" + claim + " := by sorry\n")
solution = [
    (last / "RhOfRight.lean").read_text().rstrip(),
    "open Complex DirichletCharacter",
    declaration(chars, "def UpperTheory.EveryCharacter "),
    declaration(last / "CritLine.lean", "theorem Formalism.VW.rh_of_every "),
    claim + " := Formalism.VW.rh_of_every h",
    "#print axioms Verification.rh_from_dirichlet_nonvanishing",
]
(out / "solution/Reduction.lean").write_text("\n\n".join(solution) + "\n")
PY

mapfile -t targets < <(awk 'NR==2 { print "Verification.rh_from_dirichlet_nonvanishing"; next } {print}' export-targets.txt |
    tr '[:space:]' '\n' | sed '/^$/d')
cd reference
for kind in reference solution; do
    dir="$out/$kind"
    lake env lean --root="$dir" -o "$dir/Reduction.olean" "$dir/Reduction.lean" > "$dir/build.log" 2>&1
    lake env bash -c 'export LEAN_PATH="$1:$LEAN_PATH"; shift; exec "$@"' _ "$dir" \
        "$work/tools/exporter/.lake/build/bin/lean4export" Reduction -- "${targets[@]}" > "$dir/export.ndjson"
done
"$work/tools/con-leche/.lake/build/bin/con-leche" --jobs=8 --compare \
    "$out/reference/export.ndjson" "$out/solution/export.ndjson" > "$out/compare.log" 2>&1
grep -F 'theorem Verification.rh_from_dirichlet_nonvanishing justified by the solution' "$out/compare.log"
cat "$out/solution/build.log"
sha256sum "$out"/{reference,solution}/export.ndjson

mkdir "$out/judge"
python3 - "$work/comparator.json" "$out/judge/comparator.json" <<'PY'
import json
import sys
from pathlib import Path

config = json.loads(Path(sys.argv[1]).read_text())
config.update(challenge_module="Reduction", solution_module="Reduction",
              theorem_names=["Verification.rh_from_dirichlet_nonvanishing"])
Path(sys.argv[2]).write_text(json.dumps(config))
PY
cd "$out/judge"
judgebin="$work/tools/lean-4.36.0-linux/bin"
PATH="$judgebin:$PATH" "$judgebin/lake" comparator --config comparator.json \
    --challenge-from-export "$out/reference/export.ndjson" \
    --solution-from-export "$out/solution/export.ndjson" > "$out/comparator.log" 2>&1
tail -12 "$out/comparator.log"
