{-# LANGUAGE OverloadedStrings #-}
-- |
-- warg test suite: QuickCheck D-Poset laws, cocartesian unit laws,
-- FixedPoint / attenuation properties, and Year 1 actegory laws.
--
-- __The suite can fail.__ Every property goes through 'quickCheckResult' and
-- every hand-checked assertion through 'unit'; both fold their verdict into an
-- 'IORef' that 'main' reads before deciding between 'exitSuccess' and
-- 'exitFailure'. Until 2026-09-06 the properties ran under 'quickCheck', which
-- prints a verdict and then discards it, and the unit checks printed the string
-- @FAIL@ and carried on; 'main' had no exit path at all, so the suite exited 0
-- whatever happened. A green result was a printout rather than evidence, and a
-- CI badge over it would have been permanently green by construction.
module Main (main) where

import Data.IORef (IORef, newIORef, modifyIORef', readIORef)
import Data.Ratio ((%))
import System.Exit (exitFailure, exitSuccess)
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
import DPosetTensor
  ( prop_tensor_left_unit
  , prop_tensor_right_unit
  , prop_tensor_assoc
  , prop_tensor_comm
  , prop_tensor_zero
  )
import Monoidal (prop_leftUnit, prop_rightUnit, wargPlus, checkDisjoint)
import FixedPoint (hCategoriser, runFixedPoint, runFixedPointWithAttenuation)
import Types (Arg(..), WArg(..))
import Data.Either (isRight)

-- Year 1: Cospan (H(AArg) horizontal 1-cells) and DActegory (Proposition 1)
import Cospan
  ( prop_cospan_leftleg_total
  , prop_cospan_rightleg_total
  , prop_pushout_left_commutes
  , prop_pushout_right_commutes
  )
import DActegory
  ( prop_unitor_law
  , prop_multiplicator_law
  , prop_unitor_left_triangle
  , prop_unitor_right_triangle
  )

-- Year 1: Para_bullet(WArg) — Proposition 2
import Para
  ( prop_para_left_unit
  , prop_para_right_unit
  , prop_para_compose_associative
  , prop_para_vcomp_identity
  , prop_para_horizontal_param_tensor
  , prop_scalemorphism_equivariant
  , prop_para_decomposition_equivalence
  )

-- ---------------------------------------------------------------------------
-- Orphan: Arbitrary Data.Text.Text
--
-- QuickCheck has no built-in Arbitrary instance for Data.Text.Text.
-- We derive one from the Arbitrary String instance via T.pack.
-- The -Wno-orphans flag on the test-suite stanza in warg.cabal suppresses
-- the orphan warning; this is standard practice for test-only instances.
-- ---------------------------------------------------------------------------

instance Arbitrary T.Text where
  arbitrary = T.pack <$> arbitrary
  shrink t  = T.pack <$> shrink (T.unpack t)

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

-- | Generates WArg with an acyclic attack graph.
-- Attacks only go from higher-indexed args to lower-indexed args,
-- so the L-O-Y fixed point converges in at most n iterations.
genAcyclicWArg :: Gen WArg
genAcyclicWArg = do
  n <- chooseInt (0, 6)
  let ids = [ T.pack ("a" <> show (i :: Int)) | i <- [0 .. n - 1] ]
  weights <- mapM (\_ -> arbitrary :: Gen DUnit) ids
  perps   <- mapM (\_ -> abs <$> (arbitrary :: Gen Double)) ids
  let args = Map.fromList
        [ (iid, Arg { argId = iid, argWeight = w, argPerplexity = p })
        | (iid, w, p) <- zip3 ids weights perps
        ]
  attacks <- fmap (Map.fromListWith (<>) . concat) $
    mapM (\(i, src) -> do
        let predecessors = take i ids
        if null predecessors
          then return []
          else do
            targets <- sublistOf predecessors
            return [(tgt, [src]) | tgt <- targets]
    ) (zip [0 :: Int ..] ids)
  return (WArg args attacks)

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
    (attMap, _, _) = runFixedPointWithAttenuation warg threshold

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
    (attMap, _, _) = runFixedPointWithAttenuation warg threshold

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
    (attMap, _, _) = runFixedPointWithAttenuation warg threshold

-- ---------------------------------------------------------------------------
-- Fixed-point structural invariant (formerly in Para.hs)
--
-- Relocated here because liftFixedPoint / runFixedPoint is D-invariant
-- (0-homogeneous), not D-equivariant (1-homogeneous): σ*(d•w) = σ*(w).
-- D-equivariance is the membership condition for Para•(WArg) 1-cells;
-- D-invariance is its dual failure. liftFixedPoint lives in C (plain WArg
-- morphisms), not Para•(WArg). Its principled home is
-- Para(Prism(WArg, Smooth_{[0,1]})) — Year-2 work.
--
-- This property tests the genuine structural invariant directly via
-- runFixedPoint, with no Para dependency.
-- ---------------------------------------------------------------------------

-- | σ* satisfies the h-categoriser fixed-point equation against the original
-- input weights. Passes under exact Rational arithmetic on acyclic graphs.
prop_hcat_satisfies_fixedpoint :: WArg -> Bool
prop_hcat_satisfies_fixedpoint warg =
  let (sigma, _, _) = runFixedPoint warg
      check atomId =
        case Map.lookup atomId (wArgArgs warg) of
          Nothing  -> True
          Just arg ->
            let w              = argWeight arg
                attackerIds    = Map.findWithDefault [] atomId (wArgAttacks warg)
                attackerScores = map (\aid -> Map.findWithDefault (DUnit 0) aid sigma)
                                     attackerIds
                expected       = hCategoriser w attackerScores
                actual         = Map.findWithDefault (DUnit 0) atomId sigma
            in actual == expected
  in all check (Map.keys (wArgArgs warg))

-- ---------------------------------------------------------------------------
-- Reporting: a verdict that reaches the exit code
-- ---------------------------------------------------------------------------

-- | Run a property and fold its verdict into the suite's outcome.
--
-- 'quickCheck' prints a verdict and discards it, which is why the suite could
-- not fail; 'quickCheckResult' returns one. Threading it through the ref is the
-- whole of the fix.
prop :: Testable a => IORef Bool -> a -> IO ()
prop ref p = do
  res <- quickCheckResult p
  modifyIORef' ref (&& isSuccess res)

-- | Fold a hand-checked assertion into the suite's outcome.
--
-- The printed PASS\/FAIL string used to be the only record of the verdict, so a
-- FAIL was invisible to the runner. @detail@ is appended on failure only, which
-- preserves the diagnostics the previous @if@\/@else@ arms printed.
unit :: IORef Bool -> String -> Bool -> String -> IO ()
unit ref caption ok detail = do
  putStrLn (caption ++ (if ok then "PASS" else "FAIL" ++ detail))
  modifyIORef' ref (&& ok)

-- ---------------------------------------------------------------------------
-- Main
-- ---------------------------------------------------------------------------

main :: IO ()
main = do
  ref <- newIORef True
  putStrLn "=== DUnit D-Poset laws ==="
  putStr "prop_diff_exists:       " >> prop ref prop_diff_exists
  putStr "prop_diff_upper_bound:  " >> prop ref prop_diff_upper_bound
  putStr "prop_diff_antitone:     " >> prop ref prop_diff_antitone
  putStr "prop_diff_involution:   " >> prop ref prop_diff_involution

  putStrLn "=== D-Poset tensor product (monoidal laws) ==="
  putStr "prop_tensor_left_unit:  " >> prop ref prop_tensor_left_unit
  putStr "prop_tensor_right_unit: " >> prop ref prop_tensor_right_unit
  putStr "prop_tensor_assoc:      " >> prop ref prop_tensor_assoc
  putStr "prop_tensor_comm:       " >> prop ref prop_tensor_comm
  putStr "prop_tensor_zero:       " >> prop ref prop_tensor_zero

  putStrLn "=== Monoidal unit laws ==="
  putStr "prop_leftUnit:          " >> prop ref prop_leftUnit
  putStr "prop_rightUnit:         " >> prop ref prop_rightUnit

  putStrLn "=== Monoidal associativity law ==="
  putStr "prop_assoc (disjoint):  " >> prop ref prop_assoc_disjoint

  putStrLn "=== hCategoriser unit tests ==="
  -- Unattacked argument: h(w, []) = w / (w + 0) = 1.
  -- With Rational arithmetic this is exact: 7/10 / (7/10 + 0) = 1 % 1.
  let w = DUnit (7 % 10)
  let result = hCategoriser w []
  unit ref "hCategoriser []:              " (unDUnit result == 1)
       (" (got " ++ show (unDUnit result) ++ ")")

  -- Zero-weight argument stays at 0
  let z = hCategoriser (DUnit 0) [DUnit (1 % 2)]
  unit ref "hCategoriser zero-weight:     " (unDUnit z == 0)
       (" (got " ++ show (unDUnit z) ++ ")")

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
  let (sigma, _, _) = runFixedPoint twoAtom
  let sa = unDUnit (sigma Map.! "a")
  let sb = unDUnit (sigma Map.! "b")
  unit ref "runFixedPoint symmetric:      " (sa == 1 % 2 && sb == 1 % 2)
       (" (a=" ++ show sa ++ " b=" ++ show sb ++ ")")

  -- σ* satisfies the fixed-point equation (D-invariant morphism; not Para)
  putStr "prop_hcat_satisfies_fixedpoint: " >> prop ref (forAll genAcyclicWArg prop_hcat_satisfies_fixedpoint)

  putStrLn "=== Attenuation gate ==="
  unit ref "attenuation above threshold:  " prop_attenuation_gate_above_threshold ""
  unit ref "attenuation below threshold:  " prop_attenuation_gate_below_threshold ""
  unit ref "attenuation at threshold:     " prop_attenuation_gate_at_threshold    ""

  putStrLn "=== Year 1: Cospan laws (H(AArg) horizontal 1-cells) ==="
  putStr "prop_cospan_leftleg_total:    " >> prop ref prop_cospan_leftleg_total
  putStr "prop_cospan_rightleg_total:   " >> prop ref prop_cospan_rightleg_total
  putStr "prop_pushout_left_commutes:   " >> prop ref prop_pushout_left_commutes
  putStr "prop_pushout_right_commutes:  " >> prop ref prop_pushout_right_commutes

  putStrLn "=== Year 1: D-actegory laws (Proposition 1) ==="
  putStr "prop_unitor_law:              " >> prop ref prop_unitor_law
  putStr "prop_multiplicator_law:       " >> prop ref prop_multiplicator_law
  putStr "prop_unitor_left_triangle:    " >> prop ref prop_unitor_left_triangle
  putStr "prop_unitor_right_triangle:   " >> prop ref prop_unitor_right_triangle

  putStrLn "=== Year 1: Para_bullet(WArg) laws (Proposition 2) ==="
  putStr "prop_para_left_unit:                 " >> prop ref prop_para_left_unit
  putStr "prop_para_right_unit:                " >> prop ref prop_para_right_unit
  putStr "prop_para_compose_associative:       " >> prop ref prop_para_compose_associative
  putStr "prop_para_horizontal_param_tensor:   " >> prop ref prop_para_horizontal_param_tensor
  putStr "prop_para_vcomp_identity:            " >> prop ref prop_para_vcomp_identity
  putStr "prop_scalemorphism_equivariant:      " >> prop ref prop_scalemorphism_equivariant
  putStr "prop_para_decomposition_equivalence: " >> prop ref prop_para_decomposition_equivalence

  putStrLn "=== All tests done ==="
  ok <- readIORef ref
  if ok
    then putStrLn "all checks as expected" >> exitSuccess
    else putStrLn "SUITE FAILED: at least one check did not behave as expected"
           >> exitFailure
