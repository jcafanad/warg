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
-- output is a 'WireResponse' whose "results" carry 'WireResult' (see Types).
-- 'Explanation' is used internally for attacker subgraph construction, and its
-- fields are inlined into 'WireResult' by Main. This design keeps the wire
-- format minimal and the internal type expressive.
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

-- | Build explanations from the fixed-point result.
--
-- For each argument in the framework:
--   1. Look up its σ* in the GradualSemantics map.
--   2. Collect its attackers (from wArgAttacks, per-target encoding).
--   3. Retain only attackers with σ* > 0 (the natural bottom of the D-Poset).
--
-- The ε threshold is fixed at DUnit 0 — the categorical natural bottom — and
-- is not a parameter. Filtering at any ε > 0 is cosmetic structural truncation
-- (discarding structurally present but weak attack pressure) and is
-- non-commensurable with attenuation (corpus_max_perplexity), which marks
-- distributional epistemic imposition. Collapsing both into a single threshold
-- here would erase that non-identity. Any ε > 0 filtering belongs to the
-- orchestration layer, which owns the readability/precision trade-off.
--
-- Arguments not in the semantics map are skipped (defensive; should not occur
-- in well-formed input validated by validateWArg).
explain :: WArg -> GradualSemantics -> [Explanation]
explain warg sigma =
  [ Explanation atomId score significantAttackers
  | (atomId, score) <- Map.toList sigma
  , let attackerIds = Map.findWithDefault [] atomId (wArgAttacks warg)
        significantAttackers =
          [ (aid, s)
          | aid <- attackerIds
          , let s = Map.findWithDefault (DUnit 0) aid sigma
          , s > DUnit 0
          ]
  ]
