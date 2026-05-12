-- |
-- Module:      Para
-- Description: Para_bullet(WArg) bicategory over the D-actegory (Proposition 2)
--
-- Convention A (in force):
--   * 'paraAction' represents φ : M•X → Y, taking a pre-scaled input.
--     'evalPara m a = paraAction m (scaleWArg (paraParam m) a)' provides
--     the single pre-scaling by 'paraParam'.
--   * 'paraCompose m1 m2' tensors parameters and bare-composes actions.
--     Scaling is applied once, at evaluation time. This fixes the d² bug
--     (paraAction was scaleWArg d) and the p³q³ bug (paraCompose was
--     double-scaling internally).
--
-- D-equivariance:
--   The scaleMorphism family is D-equivariant by construction
--   (prop_scalemorphism_equivariant). Horizontal composition requires
--   D-equivariance of the intermediate action f: f((Q⊗P)•x) = Q•(f(P•x)).
--
-- Note on the h-categoriser (liftFixedPoint / runFixedPoint):
--   liftFixedPoint is D-invariant, not D-equivariant: σ*(d•w) = σ*(w) for
--   all d ∈ D (the fixed point is determined by graph topology, independent
--   of input weight scale). Para•(Act_D(C)) requires D-equivariance of its
--   1-cells; D-invariance is the dual failure. liftFixedPoint therefore lives
--   in C (plain WArg morphisms), not in Para•(WArg). Its principled home is
--   Para(Prism(WArg, Smooth_{[0,1]})) — Year-2 work (see project_year2_obligations).
--   Fixed-point properties are tested in Spec.hs under the FixedPoint stanza.
--
-- Cospan ↔ Para: H(AArg) cospan composition (Cospan.hs) and Para_bullet(WArg)
--   parametric composition run on parallel tracks. Corollary 3.5 is a
--   year-2 Agda obligation.
--
-- Deferred to year-2 Agda:
--   * Phantom types a, b in ParaMorphism a b (Π-type obligations)
--   * Full Cap–Gav 2-cell coherence with contravariant r : M' → M
--   * Para ↔ Cospan fusion (Corollary 3.5)
--   * Parameter lift to [0,1]^n (Remark 4.3)
--   * Para(Prism(WArg, Smooth_{[0,1]})) construction for scoring dynamics
--
-- See: Afanador (2025), Proposition 2.
-- See: Capucci & Gavranović (2022), arXiv:2203.16351, Definition 3.1.
-- See: DActegory.hs (Proposition 1, the actegory this Para builds on).
{-# LANGUAGE OverloadedStrings #-}
module Para
  ( -- * 1-cells
    ParaMorphism(..)
    -- * 2-cells
  , ParaTransformation(..)
    -- * Bicategory operations
  , paraId
  , paraCompose
  , paraVComp
    -- * Full semantic evaluation
  , evalPara
    -- * Concrete generator (for QuickCheck; not an Arbitrary instance)
  , scaleMorphism
  , genParaMorphism
    -- * Cocartesian injections
  , paraIota1
  , paraIota2
    -- * QuickCheck properties
  , prop_para_left_unit
  , prop_para_right_unit
  , prop_para_compose_associative
  , prop_para_vcomp_identity
  , prop_para_horizontal_param_tensor
  , prop_scalemorphism_equivariant
  , prop_para_decomposition_equivalence
  ) where

import qualified Data.Map.Strict as Map
import Test.QuickCheck (Gen, arbitrary)

import DUnit (DUnit(..))
import DPosetTensor (dTensor, dUnit)
import DActegory (scaleWArg)
import Monoidal (wargZero, wargPlus)
import Types (WArg(..))

-- ---------------------------------------------------------------------------
-- 1-cells: ParaMorphism
-- ---------------------------------------------------------------------------

data ParaMorphism a b = ParaMorphism
  { paraParam  :: DUnit
  , paraAction :: WArg -> WArg
  }

-- ---------------------------------------------------------------------------
-- 2-cells: ParaTransformation
-- ---------------------------------------------------------------------------

data ParaTransformation a b = ParaTransformation
  { reparam    :: DUnit -> DUnit
  , paraSource :: ParaMorphism a b
  , paraTarget :: ParaMorphism a b
  }

-- ---------------------------------------------------------------------------
-- Bicategory operations
-- ---------------------------------------------------------------------------

paraId :: ParaMorphism a a
paraId = ParaMorphism
  { paraParam  = dUnit
  , paraAction = id
  }

-- Convention A: bare-compose actions; evalPara supplies the single pre-scaling
-- by dTensor (paraParam m1) (paraParam m2). Requires D-equivariance of
-- paraAction m1 at non-unit parameters (year-2 Agda obligation).
-- In the unit fibre (all paraParam = dUnit), equivariance is trivial.
paraCompose :: ParaMorphism a b -> ParaMorphism b c -> ParaMorphism a c
paraCompose m1 m2 = ParaMorphism
  { paraParam  = dTensor (paraParam m1) (paraParam m2)
  , paraAction = paraAction m2 . paraAction m1
  }

paraVComp :: ParaTransformation a b -> ParaTransformation a b -> ParaTransformation a b
paraVComp r s = ParaTransformation
  { reparam    = reparam s . reparam r
  , paraSource = paraSource r
  , paraTarget = paraTarget s
  }

-- ---------------------------------------------------------------------------
-- Cocartesian injections
-- ---------------------------------------------------------------------------

paraIota1 :: ParaMorphism a (Either () ())
paraIota1 = ParaMorphism
  { paraParam  = dUnit
  , paraAction = \a -> wargPlus a wargZero
  }

paraIota2 :: ParaMorphism b (Either () ())
paraIota2 = ParaMorphism
  { paraParam  = dUnit
  , paraAction = \b -> wargPlus wargZero b
  }

-- ---------------------------------------------------------------------------
-- Full Para evaluation
-- ---------------------------------------------------------------------------

evalPara :: ParaMorphism a b -> WArg -> WArg
evalPara m a = paraAction m (scaleWArg (paraParam m) a)

-- Convention A: the parameter d carries the scaling in paraParam; paraAction
-- is identity. evalPara applies scaleWArg (paraParam m) once at the boundary.
-- Fixes the d² bug (was: paraAction = scaleWArg d).
scaleMorphism :: DUnit -> ParaMorphism () ()
scaleMorphism d = ParaMorphism
  { paraParam  = d
  , paraAction = id
  }

genParaMorphism :: Gen (ParaMorphism () ())
genParaMorphism = scaleMorphism <$> arbitrary

-- ---------------------------------------------------------------------------
-- QuickCheck properties
-- ---------------------------------------------------------------------------

-- | Left unit law: paraCompose paraId m evaluates identically to m.
-- Uses evalPara — the categorically meaningful equality under Convention A.
prop_para_left_unit :: DUnit -> WArg -> Bool
prop_para_left_unit d warg =
  let m        = scaleMorphism d
      composed = paraCompose paraId m
  in wArgArgs (evalPara composed warg) == wArgArgs (evalPara m warg)

-- | Right unit law: paraCompose m paraId evaluates identically to m.
prop_para_right_unit :: DUnit -> WArg -> Bool
prop_para_right_unit d warg =
  let m        = scaleMorphism d
      composed = paraCompose m paraId
  in wArgArgs (evalPara composed warg) == wArgArgs (evalPara m warg)

-- | Action-level associativity. Tests the full evalPara pipeline, not just
-- paraParam equality (a corollary of prop_tensor_assoc; not duplicated here).
prop_para_compose_associative :: DUnit -> DUnit -> DUnit -> WArg -> Bool
prop_para_compose_associative p q r warg =
  let m1  = scaleMorphism p
      m2  = scaleMorphism q
      m3  = scaleMorphism r
      lhs = evalPara (paraCompose (paraCompose m1 m2) m3) warg
      rhs = evalPara (paraCompose m1 (paraCompose m2 m3)) warg
  in wArgArgs lhs == wArgArgs rhs

-- | Identity vertical composition.
prop_para_vcomp_identity :: DUnit -> Bool
prop_para_vcomp_identity p =
  let idCell   = ParaTransformation { reparam = id, paraSource = paraId, paraTarget = paraId }
      composed = paraVComp idCell idCell
  in reparam composed p == p

-- | Horizontal composition parameter law. Definitional content of paraCompose's
-- paraParam field; guards against accidental refactoring.
prop_para_horizontal_param_tensor :: DUnit -> DUnit -> Bool
prop_para_horizontal_param_tensor p q =
  let m1 = scaleMorphism p
      m2 = scaleMorphism q
  in paraParam (paraCompose m1 m2) == dTensor (paraParam m1) (paraParam m2)

-- | D-equivariance of the scaleMorphism family: φ((n⊗d)•a) = n•(φ(d•a)).
-- paraAction = id makes both sides (n*d)·warg. Documents scaleMorphism as a
-- member of the D-equivariant class required by Convention A composition.
prop_scalemorphism_equivariant :: DUnit -> DUnit -> WArg -> Bool
prop_scalemorphism_equivariant d n warg =
  let m   = scaleMorphism d
      lhs = paraAction m (scaleWArg (dTensor n d) warg)
      rhs = scaleWArg n (paraAction m (scaleWArg d warg))
  in wArgArgs lhs == wArgArgs rhs

-- | Decomposition equivalence: the same evalPara image admits two decompositions —
-- scaling in paraAction (m_src, Convention B style) or absorbed into paraParam
-- (m_tgt, Convention A style). Not Cap–Gav 2-cell coherence (which requires
-- contravariant r : M' → M and the full coherence square).
prop_para_decomposition_equivalence :: DUnit -> DUnit -> WArg -> Bool
prop_para_decomposition_equivalence p k warg =
  let m_src = ParaMorphism { paraParam = p,           paraAction = scaleWArg k }
      m_tgt = ParaMorphism { paraParam = dTensor k p, paraAction = id          }
  in wArgArgs (evalPara m_src warg) == wArgArgs (evalPara m_tgt warg)

