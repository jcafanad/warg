-- |
-- Module      : DPosetTensor
-- Description : Tensor product (⊗) and monoidal unit (j) on the D-Poset [0,1]
--
-- = Theoretical context
--
-- Jacobs & Mandemaker [13] establish that the category D-Posets is coreflective
-- in the category of orthomodular posets (OMP) via the adjunction K ⊣ J, where
-- J : OMP → D-Posets is the forgetful functor and K assigns to each D-Poset its
-- free OMP. The tensor product ⊗ on D-Posets is inherited from this adjunction:
-- it makes (D-Posets, ⊗, j) a symmetric monoidal category such that K ⊣ J is a
-- symmetric monoidal adjunction.
--
-- This module implements the restriction of that tensor to the concrete D-Poset
-- [0,1] — the carrier for the h-categoriser gradual semantics (Stratum A, Year 0).
--
-- = Concrete realisation on [0,1]
--
-- For the unit interval D-Poset ([0,1], ≤, 0, b \ a = b − a):
--
--   * The tensor product ⊗ = · (ordinary multiplication).
--   * The monoidal unit j = 1 (the top element, DUnit 1).
--
-- The justification is threefold:
--
-- 1. [0,1] is a commutative D-Poset (b \ a = b − a is real subtraction, and
--    the sequential product from quantum logic coincides with multiplication for
--    commutative D-Posets embedded in ℝ).
--
-- 2. Closure: a · b ∈ [0,1] whenever a, b ∈ [0,1] (no clamping needed; the
--    mkDUnit clamp is present for safety but is a no-op for valid inputs).
--
-- 3. The five monoidal laws (left unit, right unit, associativity, symmetry,
--    zero absorption) all hold as exact equalities under 'Rational' arithmetic —
--    not as approximations. This is why 'DUnit' is backed by 'Rational' rather
--    than 'Double': associativity of 'Double' multiplication is NOT exact under
--    IEEE 754, so 'prop_tensor_assoc' would have been a probabilistic claim
--    rather than a verified law.
--
-- = What this enables
--
-- With (D-Posets, ⊗, j) concretely typed, the next Year 1 module ('ArgDouble.hs')
-- can state the D-actegory coherence laws for Proposition 1 of [0]:
--
--   * Unitor: j ⊙ w ≅ w
--   * Associativity: (p ⊗ q) ⊙ w ≅ p ⊙ (q ⊙ w)
--
-- These cohere precisely because ⊗ has a verified monoidal structure here.
--
-- = Proof obligations deferred to Year 2 Agda
--
-- This module does NOT construct:
--   * The free OMP functor K or the forgetful J.
--   * The universal property: DPoset(P ⊗ Q, R) ≅ BiMor(P, Q; R).
--   * The associator and unitor as natural isomorphisms (only pointwise equalities).
--   * The fact that the monoidal unit in the full categorical sense is the
--     two-element chain {0,1} and that [0,1] with j=1 is a particular object.
--
-- These are Year 2 Agda proof obligations (roadmap §6.2, §8.3).
--
-- See: Jacobs & Mandemaker (2012), "Coreflections in algebraic quantum logic",
-- Foundations of Physics 42, 932–958. [13]
-- See: Afanador (2025), ACT 2025 abstract, Proposition 1. [0]
module DPosetTensor
  ( dTensor
  , dUnit
  , prop_tensor_left_unit
  , prop_tensor_right_unit
  , prop_tensor_assoc
  , prop_tensor_comm
  , prop_tensor_zero
  ) where

import DUnit (DUnit(..), mkDUnit)

-- | The tensor product ⊗ on the D-Poset [0,1].
--
-- Concretely: @dTensor a b = a · b@ (exact Rational multiplication).
--
-- Closure: if a, b ∈ [0,1] (enforced by the 'DUnit' invariant), then
-- a · b ∈ [0,1] (since a · b ≤ a ≤ 1 and a · b ≥ 0). The 'mkDUnit' clamp
-- is applied for safety but is a no-op for well-formed inputs.
--
-- This is the concrete instance of the tensor product from the K ⊣ J adjunction
-- of Jacobs & Mandemaker [13], restricted to the commutative D-Poset [0,1].
dTensor :: DUnit -> DUnit -> DUnit
dTensor (DUnit a) (DUnit b) = mkDUnit (a * b)

-- | The monoidal unit j for the tensor product on [0,1].
--
-- Concretely: @dUnit = DUnit 1@ (the top element of the unit interval).
--
-- This satisfies @dUnit \`dTensor\` d = d@ and @d \`dTensor\` dUnit = d@
-- for all d ∈ [0,1], by the multiplicative identity law in ℚ (exact).
--
-- In the full categorical sense (Year 2 Agda), the monoidal unit of
-- (D-Posets, ⊗, j) is the two-element chain {0,1}; the value @DUnit 1@ is
-- the image of the unit in the concrete D-Poset [0,1].
dUnit :: DUnit
dUnit = DUnit 1

-- ---------------------------------------------------------------------------
-- QuickCheck monoidal laws
--
-- All five properties are stated as exact equalities (==) on DUnit, which
-- compares the underlying Rational values by exact equality. No ε-tolerance
-- is needed or appropriate: Rational arithmetic is a ring, and ring laws
-- hold definitionally.
-- ---------------------------------------------------------------------------

-- | Left unit law: j ⊗ d = d.
--
-- Formally: for all d ∈ [0,1], dUnit \`dTensor\` d = d.
-- Proof obligation (discharged by QuickCheck): 1 · d = d in ℚ.
prop_tensor_left_unit :: DUnit -> Bool
prop_tensor_left_unit d = dUnit `dTensor` d == d

-- | Right unit law: d ⊗ j = d.
--
-- Formally: for all d ∈ [0,1], d \`dTensor\` dUnit = d.
-- Proof obligation (discharged by QuickCheck): d · 1 = d in ℚ.
prop_tensor_right_unit :: DUnit -> Bool
prop_tensor_right_unit d = d `dTensor` dUnit == d

-- | Associativity: (a ⊗ b) ⊗ c = a ⊗ (b ⊗ c).
--
-- Formally: for all a, b, c ∈ [0,1], (a · b) · c = a · (b · c) in ℚ.
-- This is a ring identity, holding exactly under 'Rational' arithmetic.
-- It would NOT hold exactly under 'Double' (IEEE 754 multiplication is
-- not associative). This property is a key reason for the Rational migration.
prop_tensor_assoc :: DUnit -> DUnit -> DUnit -> Bool
prop_tensor_assoc a b c =
  (a `dTensor` b) `dTensor` c == a `dTensor` (b `dTensor` c)

-- | Symmetry (commutativity): a ⊗ b = b ⊗ a.
--
-- Formally: for all a, b ∈ [0,1], a · b = b · a in ℚ.
-- This reflects that [0,1] is a symmetric monoidal structure; the tensor
-- product is commutative because [0,1] is a commutative D-Poset.
prop_tensor_comm :: DUnit -> DUnit -> Bool
prop_tensor_comm a b = a `dTensor` b == b `dTensor` a

-- | Zero absorption: 0 ⊗ d = 0.
--
-- Formally: for all d ∈ [0,1], DUnit 0 \`dTensor\` d = DUnit 0.
-- Proof obligation: 0 · d = 0 in ℚ. The bottom element 0 is absorbing
-- for the tensor product, which reflects its role as the zero-weight
-- argument in the gradual semantics (an argument with zero initial weight
-- cannot gain acceptability by composing with any D-Poset element).
prop_tensor_zero :: DUnit -> Bool
prop_tensor_zero d = DUnit 0 `dTensor` d == DUnit 0
