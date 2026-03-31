# warg

A Haskell implementation of the h-categoriser fixed-point from Libman, Oren & Yun (2024) [7], typed toward the D-actegory structure of weighted argumentation frameworks established in:

> Afanador, J. (2025). Gradual Semantics of Abstract Argumentation, Categorically through Prisms. ACT 2025 (extended abstract). [0]

The Year 0 implementation provides a working binary: given a weighted argument graph as JSON, it returns a gradual acceptability score σ*(aᵢ) ∈ [0,1] per argument, with an ε-filtered attacker subgraph for explanation. The categorical superstructure — D-actegory over H(**Arg**), Para•(WArg) as cocartesian monoidal bicategory — is the developmental horizon.

---

## Theoretical strata

**Stratum A — concrete scoring layer (Year 0, implemented)**

The h-categoriser of Definition 2.7 in [7]:

```
σ(aᵢ) = w(aᵢ) / (w(aᵢ) + Σ_{aⱼ attacks aᵢ} σ(aⱼ))
```

with initial weights w(aᵢ) ∈ [0,1] and identity scoring function f(x) = x. Unique fixed point via contraction mapping on ([0,1]ⁿ, ‖·‖∞); computed by synchronous iteration to tolerance 1e-10. The unit interval carries the canonical D-Poset structure (partial subtraction b \ a = b − a when a ≤ b) verified by QuickCheck.

**Stratum B — categorical typing (Year 1, prospective)**

**Proposition 1.** WArg is a D-actegory over H(**Arg**), whose base monoidal category is (D-Posets, ⊗, j) under the tensor product of [13], derived from the adjunction K ⊣ J between D-Posets and orthomodular posets.

**Proposition 2.** Para•(WArg) is the cocartesian monoidal bicategory of (weighted) gradual semantics with (+, 0_**Arg**). Its 2-morphisms encode abstract (weighted) gradual semantics. The h-categoriser fixed-point is the concrete 2-morphism.

**Stratum C — profunctorial characterisation (Year 2, prospective)**

The fixed-point property is conjectured to be characterisable as a natural transformation in a profunctor category whose morphisms are prisms (mixed optics [14]), hinging on the link between Para [10, 11] and Cospan [12].

---

## XAI

Large language models produce outputs without accessible reasoning chains. They can be prompted to argue, to weigh evidence, to reach conclusions — but the structure of that reasoning is opaque: weights distributed across billions of parameters, not propositions that attack or support each other. The canonical critique of this opacity is not merely technical. An LLM trained on a dominant corpus has absorbed that corpus's epistemic defaults — its ways of collapsing contradictions, silencing marginal claims, and treating contested matters as settled. The output looks like reasoning; the onto-epistemic flattening is inapparent.

Argumentation frameworks offer a different register. If LLM outputs can be parsed into argumentative discourse units — claims, attacks, support relations — then the h-categoriser provides a gradual acceptability score σ*(aᵢ) ∈ [0,1] for each claim, derived from the attack structure rather than from the model's internal geometry. The explanation triple (V(aᵢ), σ*(aᵢ), ε-filtered attacker subgraph) then makes the reasoning legible: V(aᵢ) is the discrete truth value from the paraconsistent layer; σ*(aᵢ) is the gradual acceptability under attack pressure; the attacker subgraph shows which claims were doing the undermining.

This is an independent symbolic layer that the LLM output must answer to. Where the LLM's training geometry distorts the weight of a claim (high pseudo-perplexity λ_⊥ under the NLI model), the `attenuated` flag marks the output as epistemically imposed rather than structurally warranted. The distinction matters: a claim silenced by attack topology has been defeated by the argument; a claim silenced by the model's training distribution has been suppressed before the argument could begin. Making that difference visible is what the explanation triple is for.

The profunctorial characterisation at Stratum C (Year 2) is the theoretical account of why this triple is canonical — why σ* is the correct acceptability degree and why the attacker subgraph, rather than any other substructure of the framework, is the correct explanation object.

---

## What is in the repository now

| File | Content |
|---|---|
| `src/DUnit.hs` | D-Poset on [0,1]: `DUnit`, `dDiff`, QuickCheck laws |
| `src/Types.hs` | `Arg`, `WArg`, `GradualSemantics`; JSON wire format |
| `src/FixedPoint.hs` | `hCategoriser`, `runFixedPoint`, attenuation gate |
| `src/Monoidal.hs` | `wargZero`, `wargPlus`, monoidal law QuickCheck properties |
| `src/Explanation.hs` | ε-filtered attacker subgraph |
| `app/Main.hs` | JSON stdin → stdout binary |

---

## Build

```bash
cabal build
cabal install   # installs to ~/.cabal/bin/warg
```

Tested under GHC 9.6.7.

---

## Demo

Three minimal scenarios exercising the Year 0 binary. Run them with:

```bash
cat demo/paramo_defended.json         | warg
cat demo/paramo_attenuation.json      | warg
cat demo/paramo_gate_interaction.json | warg
```

or via `bash demo/run_demo.sh` (includes verification checks).

Each JSON file contains comprehensive documentation comments explaining field semantics, expected outputs, and theoretical grounding. The perplexity values are constructed for pedagogical demonstration (not empirical corpus spans), chosen to exercise the full range from concrete claims (λ_⊥ ≈ 4.5) to meta-epistemic critique (λ_⊥ ≈ 28.4).

---

### Scenario 1 — Reinstatement (`paramo_defended.json`)

A three-argument chain from the Páramo domain:

```
evidencia_hidrica  -->  estado_concesion  -->  paramo_territorio
```

`evidencia_hidrica` (hydrological field evidence) is unattacked. It attacks `estado_concesion` (the State concession claim). `estado_concesion` attacks `paramo_territorio` (the Paramuno territorial claim).

**Output:**

```json
[
  {"name": "evidencia_hidrica",  "gradual_weight": 1.0,   "attenuated": false},
  {"name": "estado_concesion",   "gradual_weight": 0.408, "attenuated": false},
  {"name": "paramo_territorio",  "gradual_weight": 0.641, "attenuated": false}
]
```

**Interpretation:**

The unattacked `evidencia_hidrica` converges to σ\* = 1.0 (h-categoriser identity for unattacked positive-weight arguments, Definition 2.7 of [7]). It defeats `estado_concesion` (σ\* = 0.408 < 0.5). The weakened `estado_concesion` exerts reduced attack pressure on `paramo_territorio`, which recovers to σ\* = 0.641 — above the 0.5 threshold.

This is **reinstatement**: a defeated attacker cannot sustain its attack. The h-categoriser propagates attack strength through the topology. Weak attackers produce weak attacks.

---

### Scenario 2 — Attenuation gate (`paramo_attenuation.json`)

Three unattacked atoms with differing perplexity values under the `corpus_max_perplexity = 21.769` threshold (the empirical λ_⊥ of "poner a valer a través del trabajo," the highest perplexity for natural Spanish in the Paramuno corpus):

| Atom                   | λ_⊥    | Relation to threshold |
|------------------------|--------|-----------------------|
| recurso_hidrico_estado | 6.1    | well below            |
| poner_a_valer_trabajo  | 21.769 | exactly at threshold  |
| ontologia_paramuna     | 28.4   | above threshold       |

**Output:**

```json
[
  {"name": "recurso_hidrico_estado", "gradual_weight": 1.0, "attenuated": false},
  {"name": "poner_a_valer_trabajo",  "gradual_weight": 1.0, "attenuated": false},
  {"name": "ontologia_paramuna",     "gradual_weight": 0.0, "attenuated": true}
]
```

**Interpretation:**

Because all atoms are unattacked, the h-categoriser plays no role — all non-attenuated atoms converge to 1.0. Only the attenuation gate differentiates outcomes. The gate condition is strict (`λ_⊥ > threshold`, not `≥`), so `poner_a_valer_trabajo` is not attenuated despite its perplexity being exactly equal to the threshold.

`ontologia_paramuna` (Paramuno lifeworld ontological claims, λ_⊥ = 28.4) exceeds the threshold. The gate fires: σ\* is forced to 0.0 and `attenuated = true`.

**The flag marks epistemic imposition** — the claim has been suppressed by the corpus geometry of BETO's Iberian training data, not by any argument that defeats it in the framework. A claim silenced by topology has been argued against; a claim marked `attenuated = true` has been suppressed before the argument could begin.

**The threshold is political:** Setting `corpus_max_perplexity` to 21.769 preserves the automatic subject atom (`poner_a_valer_trabajo`) at its own ceiling. A lower threshold would silence it. The parameter value is a design commitment about whose discourse survives.

---

### Scenario 3 — Gate + h-categoriser interaction (`paramo_gate_interaction.json`)

Two-argument scenario showing the attenuation gate and h-categoriser operating at different layers:

```
evidencia_institucional  -->  ontologia_paramuna
```

`evidencia_institucional` (institutional scientific evidence) attacks `ontologia_paramuna` (Paramuno lifeworld ontology). But `ontologia_paramuna` has λ_⊥ = 25.2 > 21.769, so it is attenuated BEFORE entering the argumentation space.

**Output:**

```json
[
  {"name": "evidencia_institucional", "gradual_weight": 1.0, "attenuated": false},
  {"name": "ontologia_paramuna",      "gradual_weight": 0.0, "attenuated": true}
]
```

**Interpretation:**

The attack from `evidencia_institucional` is formally present in the topology, but it never fires. `ontologia_paramuna` is silenced by epistemic imposition (attenuation gate), not by being defeated in argumentation. The h-categoriser never evaluates the attack because the target is excluded ab initio.

**This demonstrates the two-layer architecture:**

1. **Attenuation gate** (pre-argumentation filter): Excludes claims with λ_⊥ > threshold. Marks them `attenuated = true`. This is **epistemic imposition** — colonial geometry made computationally detectable.

2. **h-categoriser** (gradual semantics): Computes fixed-point acceptability degrees for non-attenuated atoms based on attack topology. Low σ\* due to attacks is **structural silencing** — defeat by argumentation.

**Contrast:** If `ontologia_paramuna` had λ_⊥ = 10.0 (below threshold), it would survive the gate and be DEFEATED by `evidencia_institucional` (σ\* ≈ 0.42, `attenuated = false`). Same outcome (low acceptability) but different mechanism. The flag makes the distinction visible.

---

### Limitations of these demos

These scenarios demonstrate core Year 0 functionality but are minimal for pedagogical clarity. Real Paramuno discourse includes:

- **Cycles**: The demos are DAGs (directed acyclic graphs) or trivial topologies. Real discourse has cycles (mutual attack, self-contradiction). The h-categoriser handles these via fixed-point iteration; the demos don't exercise this.

- **Multiple attackers**: Real arguments are attacked by several others simultaneously. Scenario 1 uses at most one attacker per target; Scenarios 2 and 3 have no attacks or single attacks.

- **Deep chains**: The demos have depth ≤ 2. Real corpus chains reach depth 5+.

- **Speaker provenance**: The demos don't encode speaker identity (Speaker GR, AC, etc.), which affects epistemic standing in the full VALUE_NET pipeline.

- **Empirical perplexity distribution**: The demos use constructed perplexity values for pedagogical range. Real corpus perplexity follows a right-skewed distribution with mode ≈ 5.0 and long tail to 28.4.

For a six-argument scenario with cycle structure, speaker provenance, and the structural dialetheia from the Paramuno fieldwork, see `demo/paramuno_scenario.md`.

---

## References

- [0] Afanador, J. (2025). Gradual Semantics of Abstract Argumentation, Categorically through Prisms. Extended abstract, ACT 2025.
- [7] Libman, A., Oren, N., Yun, B. (2024). Abstract weighted based gradual semantics in argumentation theory. arXiv:2401.11472.
- [10] Capucci, M., Gavranović, B. (2022). Actegories for the working mathematician. arXiv:2203.16351.
- [11] Gavranović, B. (2024). Fundamental components of deep learning. arXiv:2403.13001.
- [12] Baez, J.C., Courser, K., Vasilakopoulou, C. (2022). Structured versus decorated cospans. *Compositionality*, 4.
- [13] Jacobs, B., Mandemaker, J. (2012). Coreflections in algebraic quantum logic. *Foundations of Physics*, 42:932–958.
- [14] Clarke, B., Elkins, D., Gibbons, J., Loregian, F., Milewski, B., Pillmore, E., Román, M. (2024). Profunctor optics, a categorical update. *Compositionality*, 6.

---

## Licence

GNU General Public Licence v3 or later.
