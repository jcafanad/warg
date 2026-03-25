{-# LANGUAGE OverloadedStrings #-}
-- |
-- warg test suite: QuickCheck D-Poset laws and cocartesian unit laws.
module Main (main) where

import Test.QuickCheck
import qualified Data.Map.Strict as Map

import DUnit (prop_diff_antitone, prop_diff_involution, DUnit(..))
import Monoidal (prop_leftUnit, prop_rightUnit, prop_assoc)
import FixedPoint (hCategoriser, runFixedPoint)
import Types (Arg(..), WArg(..))

main :: IO ()
main = do
  putStrLn "=== DUnit D-Poset laws ==="
  quickCheck prop_diff_antitone
  quickCheck prop_diff_involution

  putStrLn "=== Monoidal unit laws ==="
  quickCheck prop_leftUnit
  quickCheck prop_rightUnit

  putStrLn "=== Monoidal associativity law ==="
  quickCheck prop_assoc

  putStrLn "=== hCategoriser unit tests ==="
  -- Unattacked argument: h(w, []) = w / (w + 0) = 1.0 (full credence, no attack pressure).
  -- This follows from Definition 2.7 of [7]. The fixed-point initialises at w, not at 1.0;
  -- it is the *convergence* that produces 1.0 for unattacked positive-weight arguments.
  let w = DUnit 0.7
  let result = hCategoriser w []
  if abs (unDUnit result - 1.0) < 1e-10
    then putStrLn "hCategoriser []: PASS"
    else putStrLn ("hCategoriser []: FAIL (got " ++ show (unDUnit result) ++ ")")

  -- Zero-weight argument stays at 0
  let z = hCategoriser (DUnit 0) [DUnit 0.5]
  if unDUnit z == 0
    then putStrLn "hCategoriser zero-weight: PASS"
    else putStrLn ("hCategoriser zero-weight: FAIL (got " ++ show (unDUnit z) ++ ")")

  -- Two equal-weight atoms attacking each other converge to 0.5
  let twoAtom = WArg
        { wArgArgs = Map.fromList
            [ ("a", Arg "a" (DUnit 0.5) 0)
            , ("b", Arg "b" (DUnit 0.5) 0)
            ]
        , wArgAttacks = Map.fromList
            [ ("a", ["b"])   -- b attacks a
            , ("b", ["a"])   -- a attacks b
            ]
        }
  let sigma = runFixedPoint twoAtom
  let sa = unDUnit (sigma Map.! "a")
  let sb = unDUnit (sigma Map.! "b")
  if abs (sa - 0.5) < 1e-6 && abs (sb - 0.5) < 1e-6
    then putStrLn "runFixedPoint symmetric: PASS"
    else putStrLn ("runFixedPoint symmetric: FAIL (a=" ++ show sa ++ " b=" ++ show sb ++ ")")

  putStrLn "=== All tests done ==="
