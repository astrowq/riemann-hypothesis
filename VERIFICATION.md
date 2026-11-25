# Independent verification report

**Completed 25 November 2026.** I rebuilt Levent Alpöge’s original Lean release and checked its five named theorems against a challenge compiled separately from Mathlib. The headline theorem is `riemannHypothesis : RiemannHypothesis`, with proof term `rhOfAll`. It states that every nontrivial zero of the Riemann zeta function has real part ½. This report records an independent replication of the released proof. [Announcement](https://alpo.ge/remark.pdf) · [Lean axiom output](verification/evidence/rebuilt-axioms.log) · [Classical zero classification](verification/Statement.lean)

## What passed

| Check | Observed result | Evidence |
| --- | --- | --- |
| Original source | The joined 14-part archive and extracted source matched the original mirror tree, including all 175,190 paths and executable bits. | [Source tree](verification/evidence/source-tree.log) · [Original mirror](https://github.com/leanprover-community/riemann-hypothesis/tree/40e56bab026552e089d7afcfeff08d2defb9c005) |
| Compilation | Lean v4.33.1 compiled all 175,187 project modules through `Main`. Every compiled module matched Sutherland’s sandbox manifest. | [Final build](verification/evidence/source-build.log) · [Per-module hashes, gzip](verification/evidence/project-oleans.sha256.gz) · [Sandbox reference](https://math.mit.edu/~drew/grh/sandbox-project-oleans.sha256) |
| Dependencies and statement | All nine dependency revisions and 43,460 compiled dependency files matched across the source and challenge trees. The five target statements came from a separate file importing only Mathlib. | [Dependency audit](verification/evidence/dependencies.log) · [Pinned challenge](https://github.com/leanprover-community/riemann-hypothesis/blob/f28a764e76a18f68680446bf09682c24d1a8b5c4/src/Challenge.lean) |
| Axioms | Lean reported exactly `propext`, `Classical.choice` and `Quot.sound` for classical RH. Comparator checked the five targets against the same allowlist. | [Native axiom output](verification/evidence/rebuilt-axioms.log) · [Comparator configuration and checks](verification/evidence/rebuilt-comparator-final.log) |
| Rebuilt proof export | A full comparison of two separately closed files found every byte equal. Both measured 61,570,595,788 bytes. A separate closing audit rehashed the proof, challenge, compiler output and native verdicts. | [Comparison and closing audit](verification/evidence/rebuilt-export.log) · [Published proof export](https://math.mit.edu/~drew/grh/#downloads) |
| Con-leche | In verified mode it accepted 1,468,418 solution declarations and 51,692 challenge declarations. It justified all five named theorems and exited 0 after 429.47 seconds on 32 workers. | [Native checker transcript](verification/evidence/rebuilt-compare.log) |
| Lean Comparator v4.36.0 | The paranoid Lean kernel, nanoda and default Lean kernel each accepted the rebuilt export. Comparator exited 0 after 66,600.74 seconds. Both input digests matched before and after the run. | [Native Comparator transcript](verification/evidence/rebuilt-comparator.log) · [Pre- and post-run checks](verification/evidence/rebuilt-comparator-final.log) |

The two published compiled-module manifests differ at one module, `RankPointCounts.LocModel`. We reproduced both variants and traced the difference to a compiler-generated binder name. Their declaration bodies agreed. Our complete build matched the sandbox variant, and the entire five-target proof export matched the published proof. [Module comparison](verification/evidence/locmodel-comparison.log)

## What the challenge tests

The original proof derives classical RH from nonvanishing for Dirichlet L-functions. The headline theorem specializes to the trivial character modulo 1, whose L-function is zeta. The other four targets cover the equivalent zero statement, right-half-plane nonvanishing, critical-strip zeros for Dirichlet characters, and the primitive-character case. Their scope is Dirichlet L-functions. [Main theorems](https://github.com/leanprover-community/riemann-hypothesis/blob/40e56bab026552e089d7afcfeff08d2defb9c005/src/Supplements/Kernels/MainTheorems.lean) · [Five named verdicts](verification/evidence/rebuilt-compare.log)

As a separate check of meaning, I specified zeta by its Dirichlet series for Re(s) > 1 and analytic continuation away from 1. Lean proved the equivalence to the usual zero classification. Con-leche then checked the published proof against this challenge and discharged its RH premise. Removing the unconditional RH proof made the control fail. [Equivalence](verification/ZetaContinuation.lean) · [Independent challenge](verification/ContinuationChallenge.lean) · [Control and result](verification/evidence/continuation-challenge.log)

Two further controls tested the verification setup. Passing the unproved five-statement challenge as the solution failed on `sorryAx` in both checkers. A small end-to-end Comparator run accepted the original test theorem and rejected the same proof when the challenge statement changed. [Unproved-solution control](verification/evidence/unproved-challenge.log) · [Changed-statement control](verification/evidence/tuned-controls.log)

## Inputs and replay conditions

| Artifact | SHA-256 |
| --- | --- |
| Joined original source archive | `9631b4f020199e580ba86178cb56c6e9b09f690c2369a80dc4334aa93f49c7fc` |
| Compiled original `Main.olean` | `9146dfb4148e24d2252e04c50742f3e49dd126dfcc5006d10bf5f873ddf796ad` |
| Uncompressed per-module manifest | `51319e37e06fd80dc16cdbe3380e13967603cc36d529389f835ca48076c24859` |
| Independent challenge export (350,862,311 bytes) | `bd484ac9886a96f26b1d9a7a59ebd45b7a70d102c015d4f31f9302bbdd6ab2b9` |
| Rebuilt solution export (61,570,595,788 bytes) | `5ea74b912147c5c93cc2b6d70cc727cf908df2f62ac6a20480a3fa02f6be244e` |
| Five-theorem Comparator configuration | `8ea890e6ccda9cf3983ada343af18a41d12542036875a3936e7925ed5b1582ff` |

The source build used Lean v4.33.1 and Mathlib commit `0df444a360eaa60ab8c11dca51a86af692955474`. Mathlib dependencies came from the pinned release and its build cache. The exporter was lean4export at `15f6055e299ad5b89345e533cc2192f4cc00f659`, and con-leche was at `5dc36dc15b7bee891a02406b78a8ac816a47baad`. [Preparation script and pins](verification/prepare-linux.sh) · [Reference artifacts](https://math.mit.edu/~drew/grh/)

The original build finished incrementally after retries for file-mapping limits. An early export stopped during memory pressure. The successful export used the stock exporter, with the host mapping limit temporarily raised and then restored. The untuned Comparator run was stopped before a verdict. The accepted run started from the beginning with `MIMALLOC_GENERIC_COLLECT=1000000` passed through Bubblewrap to the two Lean kernels. Nanoda used its stock environment. The 18 h 30 min is elapsed time for Comparator alone. [Exact sandbox launcher](verification/evidence/rebuilt-tuned-launcher.py) · [Run driver](verification/evidence/rebuilt-tuned-driver.sh) · [Tuning reference](https://math.mit.edu/~drew/grh/)

## Reproduce or inspect the result

**Check the evidence bundle.** From the top of this repository, run the following commands. The first verifies the distributed files. The second checks the uncompressed per-module manifest against the digest above.

```sh
shasum -a 256 -c SHA256SUMS
gzip -dc verification/evidence/project-oleans.sha256.gz | shasum -a 256
```

**Replay from source on x86-64 Linux.** Start in a fresh clone with Bash, Git, curl, zstd, Python 3.11+, Bubblewrap, standard Linux build tools, and the system libraries required by Lean. Use a separate empty directory for downloads and compilation. The release has 175,187 modules. Allow terabyte-scale working space for a full rebuild. The source script uses a fixed path inside the sandbox to reproduce path-sensitive compiler output.

```bash
scripts="$(pwd -P)/verification"
work="$(mktemp -d)"
cd "$work"
bash "$scripts/prepare-linux.sh"
python3 "$scripts/check_source.py" downloads/lean.tar.gz --checkout lean
export COMPARATOR_BWRAP="$scripts/evidence/rebuilt-tuned-launcher.py"
bash "$scripts/run-proof.sh"
python3 "$scripts/check_dependencies.py" --include-companions .
```

Choose a working filesystem with sufficient space, for example by setting `TMPDIR` before creating the directory. On systems with a low mapping limit, `RH_READ_SMALL_IMPORTS=1048576` enables the source-build read fallback. The recorded stock export used a mapping limit of 1,048,576. Source compilation and full-export replay are separate resource-intensive stages. To replay existing exports instead, use Comparator v4.36.0, the pinned configuration and the two uncompressed inputs with the digests above. [Pinned Comparator configuration](https://github.com/leanprover-community/riemann-hypothesis/blob/f28a764e76a18f68680446bf09682c24d1a8b5c4/comparator.json) · [Reference download and replay instructions](https://math.mit.edu/~drew/grh/)

The final [Comparator transcript](verification/evidence/rebuilt-comparator.log), [con-leche transcript](verification/evidence/rebuilt-compare.log), and [Lean axiom output](verification/evidence/rebuilt-axioms.log) retain their original bytes. Supporting records include selected output with local paths and machine identifiers removed. The closing audit lists the original digests of all three native transcripts. [Closing audit](verification/evidence/rebuilt-export.log) · [Distributed-file checksums](SHA256SUMS)
