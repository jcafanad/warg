{-# LANGUAGE OverloadedStrings #-}
-- |
-- Module      : Types
-- Description : Core argumentation types and JSON wire format
--
-- Field names in 'WireAtom', 'WireRequest', and 'WireResult' are
-- authoritative and must match the Python wire format in sybyn/warg_ffi.py
-- exactly. The roadmap §4 JSON sketch diverges from the actual FFI — the
-- Python FFI is the ground truth.
--
-- Wire format (stdin):
--   { "corpus_max_perplexity": <float>,
--     "atoms": [{ "name": ..., "initial_weight": ..., "weight": ...,
--                 "perplexity": ..., "attacks": [...] }] }
--
-- Wire format (stdout, an object carrying the run's status):
--   { "status": ..., "steps": ..., "results": [{ "name": ...,
--     "gradual_weight": ..., "attenuated": ..., "attackers": [...] }] }
--
-- Internal types ('Arg', 'WArg', 'GradualSemantics') follow the roadmap §3.2
-- type sketches and are not directly serialised.
module Types
  ( -- * Internal types
    Arg(..)
  , WArg(..)
  , GradualSemantics
    -- * Wire types (JSON contract)
  , WireAtom(..)
  , WireRequest(..)
  , WireResult(..)
    -- * Conversion
  , buildWArg
    -- * Validation
  , validateWArg
  , FixedPointStatus(..)
  , WireResponse(..)
  ) where

import Data.Aeson
import Data.List (find)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import GHC.Generics (Generic)

import DUnit (DUnit(..))

-- ---------------------------------------------------------------------------
-- Internal types (roadmap §3.2)
-- ---------------------------------------------------------------------------

-- | An argument with its initial weight w(aᵢ) ∈ [0,1] (Definition 2.1 of [7]).
--
-- argWeight is the BETO-derived NLI weight — the perplexity-attenuated
-- engagement score. This is distinct from the VALUE_NET weight in the
-- paraconsistent AF (cubun layer). The distinction matters for the pipeline
-- orchestrator: VALUE_NET weight drives the Belnap fixed-point; argWeight
-- drives the h-categoriser fixed-point here.
data Arg = Arg
  { argId         :: Text
  , argWeight     :: DUnit    -- w(aᵢ): initial weight, perplexity-attenuated
  , argPerplexity :: Double   -- λ_⊥ epistemic imposition measure
  } deriving (Eq, Ord, Show, Generic)

-- | A weighted argumentation framework.
--
-- wArgAttacks: target_id → [attacker_ids]  (directed: attacker attacks target)
--
-- This encoding (inverted from the wire format, where attacks are stored
-- per-attacker) is chosen for efficiency in the h-categoriser fixed-point:
-- the step function needs "who attacks this argument?", not "what does
-- this argument attack?".
data WArg = WArg
  { wArgArgs    :: Map Text Arg
  , wArgAttacks :: Map Text [Text]   -- target → [attackers]
  } deriving (Eq, Show, Generic)

-- | Gradual semantics: a scoring assignment σ: ArgId → [0,1].
--
-- In Para•(WArg) (Prop. 2, Year 1), gradual semantics are encoded as
-- 2-morphisms. At Year 0, this is a plain Map.
type GradualSemantics = Map Text DUnit

-- ---------------------------------------------------------------------------
-- Wire types (JSON contract — authoritative)
-- ---------------------------------------------------------------------------

-- | A single atom in the JSON wire format (Python → Haskell).
--
-- The 'attacks' field lists atom names that THIS atom attacks (per-attacker
-- encoding). The 'buildWArg' function inverts this to per-target encoding
-- internally.
data WireAtom = WireAtom
  { waName          :: Text
  , waInitialWeight :: Double
  , waWeight        :: Double
  , waPerplexity    :: Double
  , waAttacks       :: [Text]
  } deriving (Show, Generic)

instance FromJSON WireAtom where
  parseJSON = withObject "WireAtom" $ \o ->
    WireAtom
      <$> o .:  "name"
      <*> o .:  "initial_weight"
      <*> o .:  "weight"
      <*> o .:  "perplexity"
      <*> o .:? "attacks" .!= []

-- | The full stdin request payload.
data WireRequest = WireRequest
  { wrCorpusMaxPerplexity :: Double
  , wrAtoms               :: [WireAtom]
  } deriving (Show, Generic)

instance FromJSON WireRequest where
  parseJSON = withObject "WireRequest" $ \o ->
    WireRequest
      <$> o .:  "corpus_max_perplexity"
      <*> o .:  "atoms"

-- | Why the fixed-point iteration stopped.
--
-- The names match 'Equilibrium.Bracket.Status' in equilibrium-optics where the
-- concept is the same, so the two implementations can be read against each
-- other. What they do not share is a constructor for a rejected framework, and
-- that absence is deliberate: see 'validateWArg'. A framework whose membership
-- is not settled never reaches the iteration, so refusing it is not a status
-- the computation can report. It is exit 1 and a message on stderr, before any
-- response object exists.
--
-- For the same reason there is no frontier in this wire format. warg's
-- argumentation frameworks are closed, so there is nothing at the horizon to
-- report; an open-frame variant would need a field here that this one has no
-- use for.
data FixedPointStatus
  = Converged       -- ^ σ' == σ was reached; the values are the fixed point
  | StepCapReached  -- ^ the cap was exhausted; the values are iterates, not the fixed point
  deriving (Eq, Show, Generic)

instance ToJSON FixedPointStatus where
  toJSON Converged      = "converged"
  toJSON StepCapReached = "step_cap_reached"

-- | The whole response: the status of the run, and the per-atom results.
--
-- This replaces the flat array the wire format used to emit. Convergence is a
-- property of the run and not of any one argument, so a per-atom field would
-- have recorded a global fact at the wrong level of the structure. The array
-- is now under "results"; roadmap §4 specified this shape and the flat array
-- was the deviation.
data WireResponse = WireResponse
  { wsStatus  :: FixedPointStatus
  , wsSteps   :: Int
  , wsResults :: [WireResult]
  } deriving (Show, Generic)

instance ToJSON WireResponse where
  toJSON r = object
    [ "status"  .= wsStatus r
    , "steps"   .= wsSteps r
    , "results" .= wsResults r
    ]

-- | A single result in the JSON wire format (Haskell → Python).
--
-- These are carried in the "results" field of a 'WireResponse'. The output
-- was a flat array of these until the run's status was added; a status has no
-- place to live in an array, and no per-atom field is the right home for a
-- property of the whole iteration.
--
-- wrAttackers: attacker subgraph for XAI. Inclusion threshold is σ* > DUnit 0
-- (the categorical natural bottom of the D-Poset), enforced inside
-- Explanation.explain — see that module for the full rationale. In brief:
-- attenuation (corpus_max_perplexity) and ε-filtering are non-commensurable
-- silencings; collapsing both into a single threshold here would erase that
-- non-identity. The orchestrator owns any ε > 0 it wishes to apply.
data WireResult = WireResult
  { wrName          :: Text
  , wrGradualWeight :: Double
  , wrAttenuated    :: Bool
  , wrAttackers     :: [(Text, Double)]  -- (attacker_id, σ*); σ* > 0, see Explanation.hs
  } deriving (Show, Generic)

instance ToJSON WireResult where
  toJSON r = object
    [ "name"           .= wrName r
    , "gradual_weight" .= wrGradualWeight r
    , "attenuated"     .= wrAttenuated r
    , "attackers"      .=
        [ object ["attacker_id" .= aid, "attacker_sigma" .= s]
        | (aid, s) <- wrAttackers r
        ]
    ]

-- ---------------------------------------------------------------------------
-- Conversion: WireRequest → WArg
-- ---------------------------------------------------------------------------

-- | Build the internal 'WArg' from the wire request.
--
-- Weight selection: we use 'waInitialWeight' (the NLI-derived, perplexity-
-- attenuated weight per Definition 2.1 of [7]) as the h-categoriser seed.
-- The 'waWeight' (VALUE_NET engagement, direction-neutral) is ignored here —
-- it is the paraconsistent AF weight in the cubun layer.
--
-- Attack inversion: wire format is per-attacker (each atom lists what it
-- attacks); internal format is per-target (each target lists its attackers).
buildWArg :: WireRequest -> WArg
buildWArg req = WArg
  { wArgArgs    = Map.fromList [(waName a, mkArg a) | a <- wrAtoms req]
  , wArgAttacks = Map.fromListWith (<>) attacks
  }
  where
    mkArg a = Arg
      { argId         = waName a
      -- toRational converts the IEEE-754 Double from the wire payload to the
      -- exact Rational it represents (all finite Doubles are rational).
      -- This is the only boundary where Double crosses into the DUnit world.
      , argWeight     = DUnit (max 0 (min 1 (toRational (waInitialWeight a))))
      , argPerplexity = waPerplexity a
      }
    attacks =
      [ (target, [waName a])
      | a      <- wrAtoms req
      , target <- waAttacks a
      ]

-- | Validate referential integrity of a 'WArg'.
--
-- Every atom id appearing as a source or target in the attack relation must
-- be present in 'wArgArgs'.  An attack edge whose source or target has no
-- corresponding argument would make the h-categoriser fixed-point operate
-- on a malformed graph — dangling references are silently absorbed by
-- 'Map.findWithDefault' in 'runFixedPoint', but that silence is misleading
-- rather than safe.
--
-- Returns 'Left msg' naming the first dangling id, or 'Right warg' if the
-- graph is well-formed.  This is a pure function: it does not modify the
-- framework, only checks it.
validateWArg :: WArg -> Either Text WArg
validateWArg warg =
  case find isDangling allIds of
    Just bad -> Left ("validateWArg: dangling atom id not in wArgArgs: " <> bad)
    Nothing  -> Right warg
  where
    -- Collect every id that appears as a target or attacker in the relation.
    allIds :: [Text]
    allIds =
      [ i
      | (target, attackers) <- Map.toList (wArgAttacks warg)
      , i <- target : attackers
      ]
    isDangling :: Text -> Bool
    isDangling i = not (i `Map.member` wArgArgs warg)
