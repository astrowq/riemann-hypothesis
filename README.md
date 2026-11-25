# Independent verification of Alpöge’s Lean proof of the Riemann hypothesis

On 25 November 2026, I completed an independent rebuild and replay of Levent Alpöge’s published Lean proof. The theorem checked was Mathlib’s `RiemannHypothesis`: every nontrivial zero of the Riemann zeta function has real part ½. Credit for the proof belongs to Alpöge, who describes his work with Claude in the [original announcement](https://alpo.ge/remark.pdf).

- **Source.** All 175,187 Lean modules compiled from the original release. All 175,187 compiled module hashes matched Andrew Sutherland’s separate sandbox build. [Build record](verification/evidence/source-build.log)
- **Proof.** The rebuilt export matched Sutherland’s published export byte for byte across all 61,570,595,788 bytes. Its SHA-256 is `5ea74b912147c5c93cc2b6d70cc727cf908df2f62ac6a20480a3fa02f6be244e`. [Comparison record](verification/evidence/rebuilt-export.log) · [Sutherland’s reference files](https://math.mit.edu/~drew/grh/)
- **Independent replay.** Against a separately compiled, Mathlib-only challenge, con-leche justified all five theorems in 7 min 9 s. Lean Comparator v4.36.0 accepted the same proof with paranoid Lean, nanoda and default Lean in 18 h 30 min. Both commands exited with status zero. [Con-leche transcript](verification/evidence/rebuilt-compare.log) · [Comparator transcript](verification/evidence/rebuilt-comparator.log)

The [verification report](VERIFICATION.md) gives the axiom audit, negative controls, input digests, and Linux reproduction commands. To check a downloaded copy, run `shasum -a 256 -c SHA256SUMS` from the repository root.
