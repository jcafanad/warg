{-# LANGUAGE OverloadedStrings #-}
-- |
-- warg test suite: QuickCheck D-Poset laws, cocartesian unit laws, and
-- FixedPoint / attenuation properties.
module Main (main) where

import Data.Ratio ((%))
import Test.QuickCheck
import qualified Data.Map.Strict as Map
import qualified Data.Text as T

import DUnit
  ( prop_diff_exists
  , prop_diff_upper_bound
  , prop_diff_antitone
  , prop_diff_involution
  , DUnit(..)
  )
import Monoidal (prop_leftUnit, prop_rightUnit, wargPlus, checkDisjoint)
import FixedPoint (hCategoriser, runFixedPoint, runFixedPointWithAttenuation)
import Types (Arg(..), WArg(..))
import Data.Either (isRight)

-- ---------------------------------------------------------------------------
-- Disjoint-triple generator (roadmap §8.4)
--
-- The standard Arbitrary WArg instance draws ids from the fixed namespace
-- "arg_0" … "arg_4", so two independent WArg values frequently share ids,
-- causing prop_assoc to discard most test cases.
--
-- This generator namespaces the three frameworks independently:
--   w1 uses prefix "a_", w2 uses "b_", w3 uses "c_".
-- Frameworks with disjoint prefixes are always disjoint regardless of the
-- number of atoms generated. The disjointness precondition for wargPlus is
-- therefore satisfied structurally rather than by rejection sampling.
-- ---------------------------------------------------------------------------

genDisjointTriple :: Gen (WArg, WArg, WArg)
genDisjointTriple = do
  w1 <- genPrefixed "a_"
  w2 <- genPrefixed "b_"
  w3 <- genPrefixed "c_"
  return (w1, w2, w3)

genPrefixed :: String -> Gen WArg
genPrefixed prefix = do
  n <- chooseInt (0, 5)
  let ids = [ T.pack (prefix <> show (i :: Int)) | i <- [0 .. n - 1] ]
  weights <- mapM (\_ -> arbitrary :: Gen DUnit) ids
  perps   <- mapM (\_ -> abs <$> (arbitrary :: Gen Double)) ids
  let args = Map.fromList
        [ (iid, Arg { argId = iid, argWeight = w, argPerplexity = p })
        | (iid, w, p) <- zip3 ids weights perps
        ]
  attacks <- fmap (Map.fromListWith (<>) . concat) $ mapM
    (\src -> do
        attack <- arbitrary :: Gen Bool
        if attack && length ids > 1
          then do
            targets <- sublistOf (filter (/= src) ids)
            return [(tgt, [src]) | tgt <- targets]
          else return []
    ) ids
  return (WArg args attacks)

-- | Associativity law using the disjoint-triple generator.
--
-- Replaces the guarded prop_assoc from Monoidal.hs for testing purposes.
-- The prefix-namespaced generator guarantees disjointness structurally,
-- eliminating the 1000-discard problem observed with the standard Arbitrary
-- WArg instance (which draws all ids from "arg_0"…"arg_5").
prop_assoc_disjoint :: Property
prop_assoc_disjoint = forAll genDisjointTriple $ \(w1, w2, w3) ->
  isRight (checkDisjoint w1 w2) &&
  isRight (checkDisjoint w2 w3) &&
  isRight (checkDisjoint w1 w3) ==>
    wargPlus w1 (wargPlus w2 w3) == wargPlus (wargPlus w1 w2) w3

-- ---------------------------------------------------------------------------
-- Attenuation gate property
--
-- THEORY_CODE_ALIGNMENT §2.4 identifies the `attenuated` flag as load-bearing
-- for the pipeline orchestrator's ability to distinguish structural silencing
-- from epistemic imposition. This property tests the gate directly:
-- if an argument's perplexity exceeds the threshold, the result must be
-- attenuated=True and gradual_weight=0.0.
--
-- The property is stated as a unit-test-style check on a single constructed
-- argument rather than as a QuickCheck property over WArg, because the
-- attenuation gate is a deterministic post-fixed-point filter and the
-- interesting case (perplexity > threshold) is not likely to arise in the
-- standard Arbitrary WArg generator.
-- ---------------------------------------------------------------------------

-- | Attenuation gate zeroes weight and sets attenuated=True above threshold.
--
-- Constructs a single unattacked argument with a perplexity value chosen to
-- exceed the threshold. After runFixedPointWithAttenuation, the output for
-- that argument must have gradual_weight=0.0 and attenuated=True.
--
-- The chosen perplexity (30.0) exceeds the canonical threshold (21.769)
-- used in the Paramuno corpus (the λ_⊥ of "poner a valer a través del
-- trabajo"). The threshold passed to runFixedPointWithAttenuation (21.769)
-- is the same default used in sybyn/warg_ffi.py and in the wire format
-- smoke tests, so this test exercises the same code path as the real binary.
prop_attenuation_gate_above_threshold :: Bool
prop_attenuation_gate_above_threshold =
  case Map.lookup "high_perplexity_atom" attMap of
    Nothing           -> False   -- atom missing from result: fail
    Just (gw, attenu) -> unDUnit gw == 0.0 && attenu
  where
    threshold = 21.769
    warg = WArg
      { wArgArgs = Map.fromList
          [ ("high_perplexity_atom"
            , Arg "high_perplexity_atom" (DUnit 0.7) 30.0)  -- λ_⊥ = 30 > 21.769
          ]
      , wArgAttacks = Map.empty
      }
    attMap = runFixedPointWithAttenuation warg threshold

-- | Attenuation gate leaves weight intact and sets attenuated=False below threshold.
prop_attenuation_gate_below_threshold :: Bool
prop_attenuation_gate_below_threshold =
  case Map.lookup "low_perplexity_atom" attMap of
    Nothing           -> False
    Just (gw, attenu) ->
      -- Unattacked argument with positive initial weight converges to exactly 1.
      -- Under Rational arithmetic the fixed point is reached exactly; no
      -- tolerance is needed.
      unDUnit gw == 1 && not attenu
  where
    threshold = 21.769
    warg = WArg
      { wArgArgs = Map.fromList
          [ ("low_perplexity_atom"
            , Arg "low_perplexity_atom" (DUnit 0.7) 5.0)  -- λ_⊥ = 5 < 21.769
          ]
      , wArgAttacks = Map.empty
      }
    attMap = runFixedPointWithAttenuation warg threshold

-- | Attenuation gate smoke test: atom exactly AT the threshold is NOT attenuated.
--
-- The gate is strict (>), not (>=). An atom at exactly the threshold value
-- (21.769) is not attenuated — the threshold is an exclusive upper bound.
-- This matches the docstring in FixedPoint.hs: "argPerplexity arg > threshold".
prop_attenuation_gate_at_threshold :: Bool
prop_attenuation_gate_at_threshold =
  case Map.lookup "at_threshold_atom" attMap of
    Nothing           -> False
    Just (_gw, attenu) -> not attenu   -- at threshold = not attenuated
  where
    threshold = 21.769
    warg = WArg
      { wArgArgs = Map.fromList
          [ ("at_threshold_atom"
            , Arg "at_threshold_atom" (DUnit 0.7) 21.769)
          ]
      , wArgAttacks = Map.empty
      }
    attMap = runFixedPointWithAttenuation warg threshold

-- ---------------------------------------------------------------------------
-- Main
-- ---------------------------------------------------------------------------

main :: IO ()
main = do
  putStrLn "=== DUnit D-Poset laws ==="
  putStr "prop_diff_exists:       " >> quickCheck prop_diff_exists
  putStr "prop_diff_upper_bound:  " >> quickCheck prop_diff_upper_bound
  putStr "prop_diff_antitone:     " >> quickCheck prop_diff_antitone
  putStr "prop_diff_involution:   " >> quickCheck prop_diff_involution

  putStrLn "=== Monoidal unit laws ==="
  putStr "prop_leftUnit:          " >> quickCheck prop_leftUnit
  putStr "prop_rightUnit:         " >> quickCheck prop_rightUnit

  putStrLn "=== Monoidal associativity law ==="
  putStr "prop_assoc (disjoint):  " >> quickCheck prop_assoc_disjoint

  putStrLn "=== hCategoriser unit tests ==="
  -- Unattacked argument: h(w, []) = w / (w + 0) = 1.
  -- With Rational arithmetic this is exact: 7/10 / (7/10 + 0) = 1 % 1.
  let w = DUnit (7 % 10)
  let result = hCategoriser w []
  if unDUnit result == 1
    then putStrLn "hCategoriser []:              PASS"
    else putStrLn ("hCategoriser []: FAIL (got " ++ show (unDUnit result) ++ ")")

  -- Zero-weight argument stays at 0
  let z = hCategoriser (DUnit 0) [DUnit (1 % 2)]
  if unDUnit z == 0
    then putStrLn "hCategoriser zero-weight:     PASS"
    else putStrLn ("hCategoriser zero-weight: FAIL (got " ++ show (unDUnit z) ++ ")")

  -- Two equal-weight atoms mutually attacking converge to exactly 1/2.
  -- Rational fixed-point: σ = 1/2 is the unique solution to
  --   σ = w / (w + σ)  with w = 1/2, which gives σ(1 + σ/w) = 1,
  --   i.e. σ + σ²/w = w => σ = w / (w + σ). At σ = 1/2: 1/2 / (1/2 + 1/2) = 1/2. ✓
  let twoAtom = WArg
        { wArgArgs = Map.fromList
            [ ("a", Arg "a" (DUnit (1 % 2)) 0)
            , ("b", Arg "b" (DUnit (1 % 2)) 0)
            ]
        , wArgAttacks = Map.fromList
            [ ("a", ["b"])
            , ("b", ["a"])
            ]
        }
  let sigma = runFixedPoint twoAtom
  let sa = unDUnit (sigma Map.! "a")
  let sb = unDUnit (sigma Map.! "b")
  if sa == 1 % 2 && sb == 1 % 2
    then putStrLn "runFixedPoint symmetric:      PASS"
    else putStrLn ("runFixedPoint symmetric: FAIL (a=" ++ show sa ++ " b=" ++ show sb ++ ")")

  putStrLn "=== Attenuation gate ==="
  putStrLn $ "attenuation above threshold:  " ++
    if prop_attenuation_gate_above_threshold then "PASS" else "FAIL"
  putStrLn $ "attenuation below threshold:  " ++
    if prop_attenuation_gate_below_threshold then "PASS" else "FAIL"
  putStrLn $ "attenuation at threshold:     " ++
    if prop_attenuation_gate_at_threshold    then "PASS" else "FAIL"

  putStrLn "=== All tests done ==="
