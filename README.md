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
