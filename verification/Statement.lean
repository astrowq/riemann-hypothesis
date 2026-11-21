import Mathlib.NumberTheory.LSeries.RiemannZeta

namespace Verification

/-- Away from the pole, every zeta zero is a negative even integer or lies on the critical line. -/
theorem riemannHypothesis_iff_zero_classification :
    RiemannHypothesis ↔
      ∀ s : ℂ, s ≠ 1 → riemannZeta s = 0 →
        (∃ n : ℕ, s = -2 * (n + 1)) ∨ s.re = (1 : ℝ) / 2 := by
  constructor
  · intro h s hp hz
    by_cases htriv : ∃ n : ℕ, s = -2 * (n + 1)
    · exact Or.inl htriv
    · exact Or.inr (h s hz htriv hp)
  · intro h s hz htriv hp
    exact (h s hp hz).resolve_left htriv

#print axioms riemannHypothesis_iff_zero_classification

end Verification
