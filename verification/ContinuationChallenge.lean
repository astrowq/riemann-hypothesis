import ZetaContinuation

/-- Con-leche must discharge this one external premise from the supplied solution. -/
axiom riemannHypothesis : RiemannHypothesis

namespace Verification

/-- The classical zero statement, using the Dirichlet series to specify the function. -/
theorem continuation_zeros (f : ℂ → ℂ) (ha : AnalyticOnNhd ℂ f {1}ᶜ)
    (hs : ∀ s : ℂ, 1 < s.re → f s = ∑' n : ℕ, 1 / (n + 1 : ℂ) ^ s)
    (s : ℂ) (hp : s ≠ 1) (hz : f s = 0) :
    (∃ n : ℕ, s = -2 * (n + 1)) ∨ s.re = 1 / 2 :=
  riemannHypothesis_iff_continuation_zeros.mp riemannHypothesis f ha hs s hp hz

#print axioms continuation_zeros

end Verification
