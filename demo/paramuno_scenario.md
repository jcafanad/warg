# Paramuno-Inspired Demonstration Scenario
## warg prototype — paraconsistent weighted argumentation

**Context:** Agricultural cooperative discourse on market participation vs. solidarity economics. Inspired by fieldwork themes from GLR Páramo region (2019-2020), but constructed for demonstration purposes.

---

## The dialectical situation

**Central claim (C):** "Market participation strengthens the cooperative"

**Dialectical complexity:**
- Multiple speakers with different epistemic positions
- Contradictory evidence from lived experience
- Value tensions (autonomy vs. market dependency)
- Colonial epistemic traces (market language imposed by development agencies)

**Why this demonstrates paraconsistent logic:**
Standard argumentation frameworks (Dung 1995) assign binary labels: IN/OUT/UNDEC. A claim cannot be both accepted and rejected. But in actual cooperative discourse:
- Market participation **does** bring income (experiential evidence)
- Market participation **does** undermine solidarity (experiential evidence)
- Both are true simultaneously

The Belnap four-valued logic admits `B` (Both true and false) as a legitimate epistemic state. In this scenario, the dialetheia does not reside in a single atom's σ* value — it resides in the structural conflict between a₃ and a₄, both accepted, with a₆ as the atom that makes that conflict explicit. The h-categoriser preserves this irresolution rather than forcing a binary outcome.

---

## Argument structure

```
Arguments (6 total):

a₁: "Market prices have increased our income"
    - Speaker: GR (market-experienced)
    - Initial weight: 0.85 (low perplexity, high engagement)
    - Attacks: a₅ (contradicts autonomy claim)

a₂: "But we depend on intermediaries now"
    - Speaker: AC (critical)
    - Initial weight: 0.72
    - Attacks: a₁ (qualifies the income claim)

a₃: "The cooperative decides collectively"
    - Speaker: GR (market-experienced, same speaker as a₁)
    - Initial weight: 0.65
    - Attacks: a₂ (defends collective agency), a₆ (contests the epistemic critique
      by enacting the condition it diagnoses — asserting autonomy in market language)

a₄: "Market forces us to grow what they want"
    - Speaker: LO (land manager)
    - Initial weight: 0.68
    - Attacks: a₃ (challenges collective autonomy)

a₅: "We maintain autonomy over production"
    - Speaker: NR (cooperative founder)
    - Initial weight: 0.58 (higher perplexity — abstract claim)
    - Attacks: a₄

a₆: "Development agencies teach us market language"
    - Speaker: AC (analytical)
    - Initial weight: 0.45 (HIGH perplexity — meta-epistemic claim)
    - Attacks: a₁, a₅ (epistemic critique of both market-positive claims)
    - **This is the automatic subject atom** (λ_⊥ ≈ 21.0)
    - Attacked by a₃: the cooperative's collective decision claim contests the
      critique, not by refuting it, but by demonstrating that collective agency
      operates inside market language — the very condition a₆ names
```

**Attack topology:**
```
    a₁ ←─── a₂ ←─── a₃ ←─── a₄ ←─── a₅
    ↑          ↗             ↑
    └──── a₆ ──┘             │
         └───────────────────┘
         (a₃ also attacks a₆)
```

**Key features:**
1. **Cycle structure:** a₁ → a₅ → a₄ → a₃ → a₂ → a₁ (via attacks)
2. **Meta-level critique:** a₆ attacks both endpoints (a₁ and a₅); a₃ attacks a₆
3. **Perplexity gradient:** Concrete claims (income) → lower λ_⊥; abstract claims (autonomy, meta-critique) → higher λ_⊥
4. **Automatic subject:** a₆ has perplexity near threshold (survives attenuation gate)

---

## What warg computes (h-categoriser fixed-point)

Verified σ* values (warg 0.1.0.0 binary):

| Arg | σ*    | Interpretation |
|-----|-------|----------------|
| a₄  | 0.637 | Most accepted — structural coercion is the dominant outcome |
| a₂  | 0.588 | Dependency critique holds — qualifies a₁ and is not decisively answered |
| a₃  | 0.505 | Barely above threshold — asserts collective agency but only in market language |
| a₆  | 0.471 | Present, recognized, below 0.5 — necessary but insubstantial for autonomy |
| a₁  | 0.445 | Market income claim weakened — attacked by a₂ and a₆ |
| a₅  | 0.388 | Most weakened — attacked by both a₁ and a₆ |

**The dialetheia is structural, not scalar.** a₆ is a Belnap B atom:
- *Truth side:* a₄=0.637 (accepted) — the cooperative IS structurally coerced. a₆ is correct.
- *False side:* a₃=0.505 (accepted) — collective agency persists. The cooperative's use of market language is a decision, not pure imposition. a₆ is contested.
- *a₆ at 0.471:* names the tension between a₃ and a₄, cannot resolve it.

Adorno's non-identity preserved computationally: the critique cannot be synthesised away, but also cannot escape the condition it diagnoses.

**Note on the Belnap B value:** V(a₆)=B is formally expressible only at the cubun/PVAF layer (Year 1 coupling between warg and contra-value). The h-categoriser alone produces σ*∈[0,1]. The dialetheia is in the topology, not the scalar.

---

## Where a standard LLM fails

### LLM summarization

**Prompt:** "Summarize this discussion: Does market participation strengthen or weaken the cooperative?"

**Typical LLM output:**
> "The speakers have mixed views. Some argue market participation increases income (Speaker GR), while others worry it creates dependency (Speaker AC) and undermines autonomy (Speaker LO). Overall, the cooperative faces a trade-off between economic benefits and maintaining independence."

**What this misses:**

1. **Resolving the irresolution:** The LLM produces a "trade-off" narrative that synthesises the contradiction. The Paramuno speakers are not describing a trade-off — they are holding irresolvable positions simultaneously. a₃=0.505 and a₄=0.637 are both accepted; the framework does not resolve this into a recommendation.

2. **Erasing epistemic standing:** The LLM gives equal weight to all speakers. But a₆ has perplexity λ_⊥ ≈ 21.0 (near attenuation threshold) because BETO's training corpus does not engage well with meta-epistemic critique of colonial development language. The LLM does not surface this — the claim barely survives the gate (21.0 < 21.769), but the system marks it.

3. **Ignoring attack topology:** The LLM does not show that a₂ specifically qualifies a₁, or that a₆ targets both market-positive and autonomy claims, or that a₃ answers a₆ by enacting the condition a₆ critiques. The dialectical structure is lost.

4. **Missing the structural finding:** The most accepted claim in the framework is a₄ (market coercion, σ*=0.637) — not a market-positive claim. The LLM summary implies the cooperative benefits from market participation. The warg fixed-point shows the dominant outcome is structural coercion.

### warg preserves what LLM erases

**warg output shows:**
- σ*(a₄)=0.637 > σ*(a₁)=0.445 → coercion more accepted than income claim
- σ*(a₆)=0.471 (below 0.5, not attenuated) → critique present but insubstantial
- σ*(a₃)=0.505, σ*(a₄)=0.637 → both accepted in structural conflict (dialetheia preserved in topology)
- Attack graph → a₃ answers a₆ in the only available language; the answer enacts the condition the critique names

**This is why warg ≠ LLM summarization.** The LLM resolves contradictions into a coherent narrative. The warg fixed-point preserves the irresolution as the result.

---

## Pedagogical point: What counts as "explanation"?

**Standard XAI (SHAP, LIME, attention):**
> "Why did the model predict X?" → Surface feature attributions

**warg XAI:**
> "What is the dialectical structure of the discourse?" → Attack graph + gradual semantics

The explanation is not "why BETO classified this span as entailment." The explanation is: **here are the contradictions the speakers hold, with their epistemic standing preserved, without colonial flattening.** The irresolution is the finding.

This is Adorno's negative dialectics in computational form: preserve non-identity, refuse synthesis.

---

## Automatic subject atom (a₆)

**Why a₆ is theoretically significant:**

The claim "development agencies teach us market language" has perplexity λ_⊥ ≈ 21.0 (just below the 21.769 threshold). This is because:

1. **BETO's training corpus:** Spanish Wikipedia, news, formal texts. No representation of decolonial critique or indigenous epistemologies.

2. **Lexical mismatch:** The phrase "agencias de desarrollo nos enseñan lenguaje de mercado" does not appear in BETO's training data in this form.

3. **Epistemic violence measure:** High perplexity = model uncertainty = colonial epistemic exclusion made computationally detectable.

If `corpus_max_perplexity` were set to 20.0 instead of 21.769, a₆ would be attenuated (σ*=0.0, attenuated=true). The automatic subject atom would be silenced before the argument could begin. **The choice of threshold is a political decision disguised as a technical parameter.**

By setting the threshold at exactly 21.769 (the empirical maximum from Speaker GR's transcripts), we ensure the most epistemically marginal claim in the corpus survives into the argumentation space. This is a decolonial design choice.

---

## JSON payload for warg binary

```json
{
  "corpus_max_perplexity": 21.769,
  "atoms": [
    {"name": "a1_market_income",           "initial_weight": 0.85, "weight": 0.85, "perplexity": 3.2,  "attacks": ["a5_autonomy"]},
    {"name": "a2_intermediary_dependency", "initial_weight": 0.72, "weight": 0.72, "perplexity": 6.1,  "attacks": ["a1_market_income"]},
    {"name": "a3_collective_decision",     "initial_weight": 0.65, "weight": 0.65, "perplexity": 7.8,  "attacks": ["a2_intermediary_dependency", "a6_epistemic_critique"]},
    {"name": "a4_market_coercion",         "initial_weight": 0.68, "weight": 0.68, "perplexity": 7.2,  "attacks": ["a3_collective_decision"]},
    {"name": "a5_autonomy",                "initial_weight": 0.58, "weight": 0.58, "perplexity": 12.5, "attacks": ["a4_market_coercion"]},
    {"name": "a6_epistemic_critique",      "initial_weight": 0.45, "weight": 0.45, "perplexity": 21.0, "attacks": ["a1_market_income", "a5_autonomy"]}
  ]
}
```

---

## Limitations of this scenario

This scenario is a pedagogical compression of actual Paramuno dialectical structure, not a direct corpus run. Specifically:

- **Speaker provenance is illustrative.** Speaker initials (GR, AC, LO, NR) correspond to fieldwork participants but the argument content and weights are constructed for demonstration.
- **Perplexity values are constructed** except for λ_⊥=21.769 (empirical, from Speaker GR's automatic subject atom in the actual corpus).
- **The Belnap B value V(a₆)=B is a forward reference.** The h-categoriser alone produces σ*∈[0,1]. The formal dialetheia requires the Year 1 cubun/PVAF coupling.
- **No cycles in the demo topology** that are not resolved by the fixed-point iteration — real corpus discourse has deeper mutual attack structures.
