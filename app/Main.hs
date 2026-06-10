{-# LANGUAGE OverloadedStrings #-}
-- |
-- warg — categorical gradual argumentation engine (Year 0 skeleton)
--
-- IO layer: reads JSON from stdin, runs the h-categoriser fixed-point,
-- applies the corpus_max_perplexity attenuation gate, and writes a flat
-- JSON array to stdout.
--
-- Wire format (stdin):
--   { "corpus_max_perplexity": <float>,
--     "atoms": [{ "name": ..., "initial_weight": ..., "weight": ...,
--                 "perplexity": ..., "attacks": [...] }] }
--
-- Wire format (stdout — flat JSON array, authoritative):
--   [{ "name": ..., "gradual_weight": ..., "attenuated": ...,
--      "attackers": [{"attacker_id": ..., "attacker_sigma": ...}, ...] }, ...]
--
-- "attackers" contains all attackers with σ* > DUnit 0 (natural bottom of the
-- D-Poset). Any ε > 0 truncation is the orchestrator's responsibility.
--
-- The flat array format (not a wrapper object) matches sybyn/warg_ffi.py:
--   return [WargResult.from_dict(item) for item in data]
-- where data = json.loads(proc.stdout) — direct iteration, no "results" key.
module Main (main) where

import qualified Data.ByteString.Lazy as BS
import Data.Aeson (eitherDecode, encode)
import qualified Data.Map.Strict as Map
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

import Data.Text (unpack)
import DUnit (DUnit(..))
import Types (WireRequest(..), WireResult(..), buildWArg, validateWArg)
import FixedPoint (runFixedPointWithAttenuation)
import Explanation (explain, explAtomId, explAttackers)

main :: IO ()
main = do
  input <- BS.getContents
  case eitherDecode input of
    Left  err -> do
      hPutStrLn stderr ("warg: parse error: " ++ err)
      exitFailure
    Right req ->
      case validateWArg (buildWArg req) of
        Left  msg -> do
          hPutStrLn stderr ("warg: invalid argument framework: " ++ unpack msg)
          exitFailure
        Right _ ->
          BS.putStr (encode (processRequest req))

-- | Process a parsed request: build WArg, run fixed-point, apply attenuation,
-- attach attacker subgraph for XAI.
--
-- The ε threshold for attacker inclusion is the categorical natural bottom
-- (σ* > 0), fixed inside 'explain' — see Explanation.hs for the full
-- rationale. The orchestrator owns any ε > 0 it wishes to apply.
processRequest :: WireRequest -> [WireResult]
processRequest req =
  let warg      = buildWArg req
      threshold = wrCorpusMaxPerplexity req
      attMap    = runFixedPointWithAttenuation warg threshold
      sigma     = fmap fst attMap
      explMap   = Map.fromList
                    [ (explAtomId e, explAttackers e)
                    | e <- explain warg sigma
                    ]
  in [ WireResult
         { wrName          = name
         -- fromRational converts the exact Rational back to Double for the
         -- wire output (JSON). The wire format specifies gradual_weight as a
         -- float; this is the only place Rational re-crosses the Double boundary.
         , wrGradualWeight = fromRational (unDUnit gw)
         , wrAttenuated    = att
         , wrAttackers     = [ (aid, fromRational (unDUnit s))
                              | (aid, s) <- Map.findWithDefault [] name explMap
                              ]
         }
     | (name, (gw, att)) <- Map.toList attMap
     ]
