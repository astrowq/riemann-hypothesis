import Mathlib.NumberTheory.LSeries.RiemannZeta
import Mathlib.Analysis.Normed.Module.Connected

open Complex Filter Set
open scoped Topology

namespace Verification

/-- On the punctured plane, analyticity and the usual Dirichlet series determine zeta. -/
theorem continuation_eq_riemannZeta (f : ℂ → ℂ) (ha : AnalyticOnNhd ℂ f {1}ᶜ)
    (hs : ∀ s : ℂ, 1 < s.re → f s = ∑' n : ℕ, 1 / (n + 1 : ℂ) ^ s) :
    EqOn f riemannZeta {1}ᶜ := by
  have connected : IsPreconnected ({1}ᶜ : Set ℂ) :=
    (isConnected_compl_singleton_of_one_lt_rank (by simp) (1 : ℂ)).isPreconnected
  have halfPlane : {s : ℂ | 1 < s.re} ∈ 𝓝 (2 : ℂ) :=
    (continuous_re.isOpen_preimage _ isOpen_Ioi).mem_nhds (by simp)
  apply ha.eqOn_of_preconnected_of_eventuallyEq analyticOn_riemannZeta connected
    (z₀ := (2 : ℂ)) (by simp)
  filter_upwards [halfPlane] with s h
  exact (hs s h).trans (zeta_eq_tsum_one_div_nat_add_one_cpow h).symm

/-- Classical RH expressed solely through analytic continuation and the Dirichlet series. -/
theorem riemannHypothesis_iff_continuation_zeros :
    RiemannHypothesis ↔
      ∀ f : ℂ → ℂ, AnalyticOnNhd ℂ f {1}ᶜ →
        (∀ s : ℂ, 1 < s.re → f s = ∑' n : ℕ, 1 / (n + 1 : ℂ) ^ s) →
        ∀ s : ℂ, s ≠ 1 → f s = 0 →
          (∃ n : ℕ, s = -2 * (n + 1)) ∨ s.re = 1 / 2 := by
  constructor
  · intro rh f ha hs s hp hz
    by_cases trivialZero : ∃ n : ℕ, s = -2 * (n + 1)
    · exact Or.inl trivialZero
    · have same := continuation_eq_riemannZeta f ha hs (show s ∈ ({1}ᶜ : Set ℂ) by simpa using hp)
      exact Or.inr (rh s (same.symm.trans hz) trivialZero hp)
  · intro h s hz nontrivial hp
    have zeros := h riemannZeta analyticOn_riemannZeta
      (fun _ hs => zeta_eq_tsum_one_div_nat_add_one_cpow hs) s hp hz
    exact zeros.resolve_left nontrivial

#print axioms continuation_eq_riemannZeta
#print axioms riemannHypothesis_iff_continuation_zeros

end Verification
