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
--   [{ "name": ..., "gradual_weight": ..., "attenuated": ... }, ...]
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

-- | Process a parsed request: build WArg, run fixed-point, apply attenuation.
--
-- TODO (Year 1): integrate explanation subgraph into the wire output.
-- Doing so requires: (a) adding an `explanation` field to 'WireResult' in
-- Types.hs; (b) extending the Python `WargResult` dataclass in sybyn/warg_ffi.py;
-- (c) updating the smoke tests. Until then the 'explain' function in
-- Explanation.hs is not called from this path — keeping a dead call here
-- would create the false impression that explanations are being computed and
-- silently discarded.
processRequest :: WireRequest -> [WireResult]
processRequest req =
  let warg      = buildWArg req
      threshold = wrCorpusMaxPerplexity req
      attMap    = runFixedPointWithAttenuation warg threshold
  in [ WireResult
         { wrName          = name
         , wrGradualWeight = unDUnit gw
         , wrAttenuated    = att
         }
     | (name, (gw, att)) <- Map.toList attMap
     ]
