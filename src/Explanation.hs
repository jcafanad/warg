{-# LANGUAGE OverloadedStrings #-}
-- |
-- Module      : Explanation
-- Description : ε-filtered attacker subgraph for XAI output
--
-- The explanation triple (V(aᵢ), σ_i*, weighted attacker subgraph) is the
-- canonical XAI artefact (roadmap §6.4). At Year 0 the Belnap value V(aᵢ)
-- is computed by the chuaque layer — it is absent from the warg wire output
-- by design (roadmap §4.2). σ_i* modulates V(aᵢ); it does not replace it.
-- The coupling is in the pipeline orchestrator, not in this module.
--
-- The 'Explanation' type is NOT used in the wire output directly. The wire
-- output is a flat array of 'WireResult' (see Types). 'Explanation' is
-- used internally for attacker subgraph construction, and its fields are
-- inlined into 'WireResult' by Main. This design keeps the wire format
-- minimal and the internal type expressive.
--
-- Note on the wire format for 'attenuated': the Python side (warg_ffi.py)
-- checks result.attenuated but does not check per-attacker scores in the
-- main wire format. The explanation attacker scores are included in the
-- wire output but are currently only used by the pipeline orchestrator for
-- fine-grained XAI, not by the basic call_warg path.
module Explanation
  ( Explanation(..)
  , explain
  ) where

import qualified Data.Map.Strict as Map
import Data.Text (Text)
import GHC.Generics (Generic)
import Data.Aeson

import DUnit (DUnit(..))
import Types (WArg(..), GradualSemantics)

-- | Explanation for argument aᵢ: its σ* plus the ε-filtered attacker subgraph.
--
-- explAttackers lists only those attackers whose σ* exceeds the epsilon
-- threshold — negligible attackers are filtered to keep the explanation
-- focused on the structurally significant attack pressure.
data Explanation = Explanation
  { explAtomId    :: Text
  , explSigmaStar :: DUnit
  , explAttackers :: [(Text, DUnit)]   -- (attacker_id, σ*(attacker))
  } deriving (Show, Generic)

instance ToJSON Explanation where
  toJSON e = object
    [ "atom_id"    .= explAtomId e
    , "sigma_star" .= unDUnit (explSigmaStar e)
    , "attackers"  .=
        [ object ["attacker_id" .= aid, "attacker_sigma" .= unDUnit s]
        | (aid, s) <- explAttackers e
        ]
    ]

-- | Build ε-filtered explanations from the fixed-point result.
--
-- For each argument in the framework:
--   1. Look up its σ* in the GradualSemantics map.
--   2. Collect its attackers (from wArgAttacks, per-target encoding).
--   3. Filter attackers whose σ* ≤ ε (negligible attack pressure).
--
-- Arguments not in the semantics map are skipped (should not occur in
-- well-formed input, but defensive).
explain :: WArg -> GradualSemantics -> Double -> [Explanation]
explain warg sigma epsilon =
  [ Explanation atomId score significantAttackers
  | (atomId, score) <- Map.toList sigma
  , let attackerIds = Map.findWithDefault [] atomId (wArgAttacks warg)
        significantAttackers =
          [ (aid, s)
          | aid <- attackerIds
          , let s = Map.findWithDefault (DUnit 0) aid sigma
          , unDUnit s > epsilon
          ]
  ]
