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

- **Empirical perplexity distribution**: The demos use constructed perplexity values for pedagogical range. Real corpus perplexity follows a right-skewed distribution with mode ≈ 5.0 and long tail to 28.4. See `internal/CONFIG_ANALYSIS.md` for empirical statistics.

For corpus-scale complexity, see `examples/paramuno_corpus_run.json` (when available, pending ethics review).

---

### References

The theoretical grounding for these scenarios:

- **[7]** Libman, Oren, and Yun. "Gradual Semantics of Abstract Argumentation" (working paper). The h-categoriser (Definition 2.7) and fixed-point convergence (Theorem 3.3).

- **[0]** Afanador. "Gradual Semantics of Abstract Argumentation: Categorically through Prisms" (ACT 2025). The attenuation gate, epistemic imposition distinction, and categorical structure.

- **THEORY_CODE_ALIGNMENT.md** (in repo): Maps theoretical claims to implementation decisions, including the initial_weight/weight distinction and the strict inequality gate condition.

The automatic subject atom ("poner a valer a través del trabajo," λ_⊥ = 21.769) is documented in `internal/project_automatic_subject_finding.md` (empirical identification from Speaker GR transcripts, 2019-2020 fieldwork).
