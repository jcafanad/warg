-- |
-- Module      : DActegory
-- Description : WArg as a D-actegory over H(AArg)
--
-- = Theoretical stakes
--
-- Proposition 1 of Afanador (2025) states:
--
--   WArg is a D-actegory over H(AArg), whose base monoidal category is
--   (D, tensor, j) — the category of D-Posets under the tensor product of
--   Jacobs & Mandemaker (2012).
--
-- An M-actegory (Capucci et al., ACT 2021, Definition 2.1; paper §2) is a
-- category C equipped with a functor
--
--     bullet : M x C -> C
--
-- and two natural isomorphisms:
--
--     unitor       eta_{c}   : c -> c `bullet` I      (or I `bullet` c -> c)
--     multiplicator mu_{c,m,n}: c `bullet` (m `tensor` n) -> (c `bullet` m) `bullet` n
--
-- satisfying three coherence diagrams (pentagon + two triangles).
--
-- = The concrete action for WArg
--
-- The action functor is (paper §2, lines around eq. at l.374):
--
--     bullet : D x Arg -> Arg
--
-- For a D-Poset element d : [0,1] and an argumentation framework A : Arg,
-- d `bullet` A is the framework A with every argument weight w(a) replaced
-- by d `tensor` w(a) = d * w(a)  (exact Rational multiplication, as in
-- DPosetTensor.dTensor).
--
-- The two functorial aspects of the action (paper l.374-385):
--   1. (- `bullet` A) : Arg -> Arg  acts as the identity on the argument-set
--      structure; it only rescales weights.  This is why the action does not
--      change the attack relation.
--   2. (D `bullet` -) : (D, oplus) -> (Arg, +)  is the right adjoint to the
--      Von Neumann-Morgenstern functor V.  In the concrete setting this is
--      just pointwise multiplication of weights.
--
-- = Unitor and multiplicator
--
-- The paper (l.309, l.387) writes:
--
--   eta_a   : a -> j `bullet` a      (unitor)
--   mu_{m,n,a}: m `bullet` (n `bullet` a) -> (m `tensor` n) `bullet` a
--              (multiplicator — note direction vs. Capucci et al.)
--
-- Concretely:
--   * j `bullet` warg = warg  (because j = DUnit 1 and 1 * w = w for any w)
--   * m `bullet` (n `bullet` warg) = (m `tensor` n) `bullet` warg
--     because m * (n * w) = (m * n) * w in Q (associativity of multiplication)
--
-- Both laws hold as exact equalities over Rational — no epsilon tolerance
-- needed.  This is precisely what prop_tensor_assoc in DPosetTensor already
-- establishes at the scalar level; here we lift it to the WArg level.
--
-- = Direction convention
--
-- The paper writes bullet : D x Arg -> Arg, so D is the LEFT argument.
-- The old src-cat/WArg.hs had bullet :: c a -> m -> c a (C then M), which
-- was backwards.  This module uses:
--
--   bullet :: DUnit -> WArg -> WArg    (M first, C second)
--
-- = What is deferred
--
-- * The natural isomorphism aspect (eta and mu as natural transformations
--   between functors, not just pointwise equations) is a Year 2 Agda
--   obligation — it requires the functor laws to be stated formally.
--
-- * The coherence diagrams (pentagon, two triangles) are stated as
--   QuickCheck properties here but not as type-level proofs.  GHC2021
--   cannot express coherence as a type constraint without Agda-style
--   dependent types.
--
-- * The full double-category action (bullet operating on horizontal 1-cells
--   / cospans, not just on objects) is Todo 4 (Para) territory.  At Year 1
--   we only implement the object-level action.
--
-- * Para_bullet(WArg) — the bicategory of gradual semantics — is Todo 4.
--   The stop-before-Para boundary is here because Para requires:
--     (a) The full actegory with coherent natural isomorphisms (this module).
--     (b) A 1-cell type: pairs (P : D, f : A `bullet` P -> B) in Arg.
--   (b) requires representing morphisms in Arg (cospan morphisms = 2-cells
--   in AArg), which requires the full double category structure.
--
-- See: Afanador (2025), ACT 2025 paper, Proposition 1 (prop: argisact).
-- See: Capucci et al. (2021), "Towards Foundations of Categorical Cybernetics",
--      ACT 2021, Definition of M-actegory (para.tex, lines 1-8).
-- See: Jacobs & Mandemaker (2012), tensor product of D-Posets (for dTensor).
module DActegory
  ( -- * Actegory typeclass
    Actegory(..)
    -- * WArg action
  , scaleArg
  , scaleWArg
    -- * QuickCheck properties
  , prop_unitor_law
  , prop_multiplicator_law
  , prop_unitor_left_triangle
  , prop_unitor_right_triangle
  ) where

import qualified Data.Map.Strict as Map
import Test.QuickCheck ()

import DUnit (DUnit(..))
import DPosetTensor (dTensor, dUnit)
import Types (Arg(..), WArg(..))

-- ---------------------------------------------------------------------------
-- Actegory typeclass
-- ---------------------------------------------------------------------------

-- | An M-actegory: a category 'c' equipped with a monoidal action of 'm'.
--
-- Laws (to be QuickCheck-verified via the WArg instance below):
--
-- (1) Unitor:       bullet dUnit a == a
--     The monoidal unit j = DUnit 1 acts as identity.
--
-- (2) Multiplicator: bullet (dTensor m n) a == bullet m (bullet n a)
--     Scaling by (m * n) equals scaling first by n then by m.
--     Note the ORDER: the paper writes m `bullet` (n `bullet` a) on the right,
--     meaning n is applied first (innermost), then m.  This matches:
--
--       bullet m (bullet n a) = scale m (scale n a)
--                             = m * (n * w(arg))
--                             = (m * n) * w(arg)
--                             = bullet (m `tensor` n) a
--
-- The typeclass is stated without 'Functor c' or similar constraints because
-- at Year 1 'c' is a concrete type (WArg), not a type constructor.
-- Year 2 Agda will state this as a functor law.
class Actegory c m where
  -- | The actegorical action: m acts on c from the left.
  --
  -- Satisfies unitor and multiplicator laws (see module header).
  bullet :: m -> c -> c

-- ---------------------------------------------------------------------------
-- WArg instance
-- ---------------------------------------------------------------------------

-- | Scale a single argument's weight by a D-Poset element.
--
-- scaleArg d arg = arg { argWeight = dTensor d (argWeight arg) }
--
-- This is the pointwise action of d on the weighting function w: A -> [0,1].
-- The attack relation is unchanged: scaling weights does not alter who attacks
-- whom.
--
-- The argPerplexity field is also unchanged: perplexity is a measure of
-- epistemic imposition on the original text, not a semantic weight subject
-- to the D-Poset action.
scaleArg :: DUnit -> Arg -> Arg
scaleArg d arg = arg { argWeight = dTensor d (argWeight arg) }

-- | The D-Poset action on WArg: scale all argument weights by d.
--
-- d `bullet` warg applies scaleArg d to every argument in wArgArgs.
-- The attack relation wArgAttacks is left unchanged.
--
-- This realises the action functor:
--     bullet : D x Arg -> Arg,   d `bullet` A  (paper l.374)
--
-- For d = j = DUnit 1:   dTensor 1 w = w  (unitor law, exact over Rational)
-- For d = dTensor m n:   dTensor (m*n) w = dTensor m (dTensor n w)
--                        (multiplicator law, exact over Rational)
scaleWArg :: DUnit -> WArg -> WArg
scaleWArg d warg = warg { wArgArgs = Map.map (scaleArg d) (wArgArgs warg) }

instance Actegory WArg DUnit where
  bullet = scaleWArg

-- ---------------------------------------------------------------------------
-- QuickCheck properties for actegory laws
-- ---------------------------------------------------------------------------

-- | Unitor law: j `bullet` warg == warg.
--
-- Formally: for all A : WArg,  bullet dUnit A = A.
-- Concretely: for all a : Arg in A,  dTensor (DUnit 1) (argWeight a) = argWeight a.
--
-- This holds by prop_tensor_right_unit in DPosetTensor: 1 * w = w in Q.
-- Here we lift that scalar law to the WArg level: every argument weight
-- in the result equals the original weight.
--
-- We compare wArgArgs maps directly because wArgAttacks is unchanged by
-- bullet (attack relation is independent of weight scaling).
prop_unitor_law :: WArg -> Bool
prop_unitor_law warg =
  wArgArgs (bullet dUnit warg) == wArgArgs warg

-- | Multiplicator law: bullet (dTensor m n) a == bullet m (bullet n a).
--
-- Formally: for all d : D, e : D, A : WArg,
--   bullet (dTensor d e) A = bullet d (bullet e A).
--
-- Concretely: (d * e) * w = d * (e * w) for all w : [0,1].
-- This is the associativity of Rational multiplication, already established
-- by prop_tensor_assoc in DPosetTensor.  Here we lift it to WArg.
prop_multiplicator_law :: DUnit -> DUnit -> WArg -> Bool
prop_multiplicator_law d e warg =
  wArgArgs (bullet (dTensor d e) warg)
    == wArgArgs (bullet d (bullet e warg))

-- | Left triangle coherence (paper l.390-396):
--
--     j `bullet` (m `bullet` a)  should equal  m `bullet` a.
--
-- This says the unitor is compatible with the action on the left:
-- applying j after m is the same as just m.
--
-- Formally: bullet dUnit (bullet m a) = bullet m a.
-- This follows from the unitor law (prop_unitor_law) applied to (bullet m a).
prop_unitor_left_triangle :: DUnit -> WArg -> Bool
prop_unitor_left_triangle m warg =
  wArgArgs (bullet dUnit (bullet m warg))
    == wArgArgs (bullet m warg)

-- | Right triangle coherence (paper l.400-407):
--
--     m `bullet` (j `bullet` a)  should equal  m `bullet` a.
--
-- This says the unitor is compatible with the action on the right:
-- applying j before m is the same as just m.
--
-- Formally: bullet m (bullet dUnit a) = bullet m a.
-- This also follows from the unitor law applied inside: bullet dUnit a = a,
-- so bullet m (bullet dUnit a) = bullet m a.
prop_unitor_right_triangle :: DUnit -> WArg -> Bool
prop_unitor_right_triangle m warg =
  wArgArgs (bullet m (bullet dUnit warg))
    == wArgArgs (bullet m warg)
