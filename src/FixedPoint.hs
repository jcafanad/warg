-- |
-- Module      : FixedPoint
-- Description : h-categoriser fixed-point iteration (Stratum A, Year 0)
--
-- The h-categoriser from Libman-Oren-Yun [7] is the concrete instantiation
-- of a 2-morphism in Para•(WArg). At Year 0 it is implemented directly;
-- in Year 1 it will be retyped as a 2-morphism once Para•(WArg) is
-- established as a bicategory.
--
-- The h-categoriser satisfies Definition 2.7 of [7]: it is bounded,
-- homogeneous, non-negative, and increasing. The specific formula
--   σ(aᵢ) = w(aᵢ) / (w(aᵢ) + Σ σ(attacker))
-- is the instance from equation (3) of [7] with f(x) = x (identity scoring).
--
-- Convergence is guaranteed by [7] via monotone iteration on the complete
-- lattice ([0,1]^n, ≤). With Rational arithmetic, exact equality (==) is a
-- safe and correct termination guard; no ε-tolerance is needed.
module FixedPoint
  ( hCategoriser
  , runFixedPoint
  , runFixedPointWithAttenuation
  ) where

import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Text (Text)

import DUnit (DUnit(..))
import Types (Arg(..), WArg(..), GradualSemantics)

-- | One application of the h-categoriser scoring function.
--
-- hCategoriser w as = w / (w + sum as)   when w > 0
-- hCategoriser 0 _  = 0                  (zero-weight arguments stay at 0)
--
-- This is the concrete instance of the scoring function from Definition 2.7
-- of [7], with the simplest choice f(x) = x.
hCategoriser :: DUnit -> [DUnit] -> DUnit
hCategoriser (DUnit w) attackerScores
  | w <= 0    = DUnit 0
  | otherwise = DUnit (w / (w + total))
  where
    total = sum (map unDUnit attackerScores)

-- | Fixed-point iteration over the full argument framework.
--
-- Initialise σ⁰(aᵢ) = argWeight aᵢ (the BETO-derived initial weight).
-- Each iteration applies 'hCategoriser' synchronously to all arguments.
-- Terminates when σ' == σ (exact equality on Rational values).
--
-- Exact equality is correct here: Rational arithmetic is deterministic and
-- rounding-free, so two maps that are genuinely equal will compare equal
-- without any ε smearing.  The old tolerance (1e-10) was a workaround for
-- IEEE-754 drift; it is not needed and not appropriate under Rational.
-- (Flaw 3 of architecture_flaws.md resolved.)
--
-- For an argument with no attackers, hCategoriser w [] = w / (w + 0) = 1:
-- unattacked positive-weight arguments converge to full credence (1),
-- regardless of their initial weight. This is the correct semantics of
-- Definition 2.7 of [7]: no attack pressure = maximum acceptability degree.
runFixedPoint :: WArg -> GradualSemantics
runFixedPoint warg = converge 10000 initialSigma
  where
    initialSigma :: GradualSemantics
    initialSigma = Map.map argWeight (wArgArgs warg)

    converge :: Int -> GradualSemantics -> GradualSemantics
    converge 0 sigma = sigma
    converge n sigma
      | sigma' == sigma = sigma'
      | otherwise       = converge (n - 1) sigma'
      where
        sigma' = Map.mapWithKey (step sigma) sigma

    step :: GradualSemantics -> Text -> DUnit -> DUnit
    step sigma atomId _ =
      -- Invariant: sigma is initialised from Map.map argWeight (wArgArgs warg),
      -- so every key in sigma is also a key in wArgArgs.  The Nothing branch is
      -- unreachable in normal use; the DUnit 0 fallback means an unknown atom
      -- is treated as zero-weight (absorbing, non-contributory) rather than
      -- throwing a runtime exception.
      let w = maybe (DUnit 0) argWeight (Map.lookup atomId (wArgArgs warg))
          attackerIds =
            Map.findWithDefault [] atomId (wArgAttacks warg)
          attackerScores =
            map (\aid -> Map.findWithDefault (DUnit 0) aid sigma) attackerIds
      in hCategoriser w attackerScores

-- ---------------------------------------------------------------------------
-- Perplexity attenuation gate
-- ---------------------------------------------------------------------------

-- | Apply the corpus_max_perplexity attenuation gate to a GradualSemantics.
--
-- An atom whose λ_⊥ (argPerplexity) exceeds the threshold has its gradual
-- weight zeroed after the fixed-point completes. The atom is flagged
-- attenuated=True in the wire output.
--
-- Theoretical justification: atoms where BETO's colonial training corpus
-- creates extreme pseudo-perplexity (e.g. Muisca cosmological claims rendered
-- unintelligible by Iberian BETO) should not have their formal weight silently
-- erased — they are marked as epistemically imposed. The 21.769 default is
-- the empirical λ_⊥ of "poner a valer a través del trabajo" (the automatic
-- subject atom), the highest perplexity still within natural Spanish in the
-- Paramuno corpus (internal/CONFIG_ANALYSIS.md, 2026-03-18).
--
-- This is a post-fixed-point correction. The dynamics are not modified; only
-- the output is filtered. This preserves the fixed-point's mathematical
-- properties while surfacing epistemic imposition.
applyAttenuationGate
  :: WArg
  -> Double                     -- ^ corpus_max_perplexity threshold
  -> GradualSemantics
  -> Map Text (DUnit, Bool)     -- ^ (σ*, attenuated)
applyAttenuationGate warg threshold sigma =
  Map.mapWithKey gate sigma
  where
    gate atomId score =
      case Map.lookup atomId (wArgArgs warg) of
        Nothing  -> (score, False)
        Just arg ->
          if argPerplexity arg > threshold
            then (DUnit 0, True)
            else (score, False)

-- | Run fixed-point and apply attenuation gate in one pass.
--
-- This is the entry point called by Main.
runFixedPointWithAttenuation
  :: WArg
  -> Double                     -- ^ corpus_max_perplexity
  -> Map Text (DUnit, Bool)     -- ^ (σ*, attenuated) per atom
runFixedPointWithAttenuation warg threshold =
  applyAttenuationGate warg threshold (runFixedPoint warg)
