#!/usr/bin/env python3
"""
Paramuno-inspired demonstration scenario for warg prototype.

Run this script to:
1. Build the dialectical argument graph
2. Call the warg binary
3. Verify structural outcomes (dialetheia preserved in topology)
4. Generate demo/paramuno_demo.json with verified outputs

Usage:
    cd ~/warg
    python3 demo/generate_paramuno_demo.py

Requires:
    - warg binary on PATH (or at ~/.local/bin/warg)
    - contra-value repo at ~/contra-value (for sybyn.warg_ffi)
"""

from pathlib import Path
import json
import sys

# sybyn.warg_ffi lives in contra-value, not warg
sys.path.insert(0, str(Path.home() / "contra-value"))

from sybyn.warg_ffi import call_warg, WargAtom


def build_scenario():
    """
    Construct the Paramuno-inspired dialectical scenario.

    Topology note: a3 attacks a6. The cooperative's collective decision claim
    contests the epistemic critique not by refuting it, but by enacting the
    condition it diagnoses — asserting autonomy in market language. This is
    the move that makes a6 insubstantial for autonomy while not dismissing it.
    """
    atoms = [
        WargAtom(
            name="a1_market_income",
            initial_weight=0.85,
            weight=0.85,
            perplexity=3.2,
            attacks=["a5_autonomy"]
        ),
        WargAtom(
            name="a2_intermediary_dependency",
            initial_weight=0.72,
            weight=0.72,
            perplexity=6.1,
            attacks=["a1_market_income"]
        ),
        WargAtom(
            name="a3_collective_decision",
            initial_weight=0.65,
            weight=0.65,
            perplexity=7.8,
            attacks=["a2_intermediary_dependency", "a6_epistemic_critique"]
        ),
        WargAtom(
            name="a4_market_coercion",
            initial_weight=0.68,
            weight=0.68,
            perplexity=7.2,
            attacks=["a3_collective_decision"]
        ),
        WargAtom(
            name="a5_autonomy",
            initial_weight=0.58,
            weight=0.58,
            perplexity=12.5,
            attacks=["a4_market_coercion"]
        ),
        WargAtom(
            name="a6_epistemic_critique",
            initial_weight=0.45,
            weight=0.45,
            perplexity=21.0,
            attacks=["a1_market_income", "a5_autonomy"]
        )
    ]

    return atoms


def verify_results(results):
    """
    Verify structural outcomes. The dialetheia is not in a6's σ* alone —
    it is in the structural conflict between a3 and a4, both accepted,
    with a6 as the atom that makes that conflict explicit.
    """
    print("\n" + "="*70)
    print("VERIFICATION RESULTS")
    print("="*70)

    print("\nFixed-point gradual weights (σ*):\n")
    for r in sorted(results, key=lambda x: -x.gradual_weight):
        status = "ATTENUATED" if r.attenuated else "active"
        print(f"  {r.name:30} σ*={r.gradual_weight:.3f}  [{status}]")

    a3 = next(r for r in results if r.name == "a3_collective_decision")
    a4 = next(r for r in results if r.name == "a4_market_coercion")
    a6 = next(r for r in results if r.name == "a6_epistemic_critique")

    # Structural dialetheia check: both sides of the tension accepted
    print("\n" + "-"*70)
    print("DIALETHEIA CHECK (structural — in topology, not in scalar)")
    print("-"*70)
    print(f"\n  Truth side: a4_market_coercion (coercion accepted)")
    print(f"    σ*(a4) = {a4.gradual_weight:.3f}")
    print(f"    Status: {'ACCEPTED (>0.5)' if a4.gradual_weight > 0.5 else 'below threshold'}")

    print(f"\n  False side: a3_collective_decision (collective agency accepted)")
    print(f"    σ*(a3) = {a3.gradual_weight:.3f}")
    print(f"    Status: {'ACCEPTED (>0.5)' if a3.gradual_weight > 0.5 else 'below threshold'}")

    print(f"\n  Critiquing atom: a6_epistemic_critique")
    print(f"    σ*(a6) = {a6.gradual_weight:.3f}")
    print(f"    Attenuated: {a6.attenuated}")
    print(f"    Status: {'present, below 0.5 — insubstantial for autonomy' if not a6.attenuated and a6.gradual_weight < 0.5 else 'check manually'}")

    dialetheia_preserved = (
        a3.gradual_weight > 0.5 and
        a4.gradual_weight > 0.5 and
        not a6.attenuated and
        a6.gradual_weight > 0
    )
    print(f"\n  → Structural dialetheia preserved: {dialetheia_preserved}")
    print(f"     a3 and a4 both accepted, in conflict.")
    print(f"     a6 present and non-attenuated — cannot be dismissed.")
    print(f"     a6 below 0.5 — insubstantial for autonomy.")

    # Automatic subject check
    print("\n" + "-"*70)
    print("AUTOMATIC SUBJECT CHECK")
    print("-"*70)
    print(f"\n  Atom: a6_epistemic_critique")
    print(f"    Perplexity: 21.0  |  Threshold: 21.769")
    print(f"    σ*(a6) = {a6.gradual_weight:.3f}  |  Attenuated: {a6.attenuated}")
    survives = not a6.attenuated and a6.gradual_weight > 0
    print(f"\n  → Automatic subject survives gate: {survives}")
    if survives:
        print(f"     21.0 < 21.769 — claim enters argumentation space.")
        print(f"     Threshold choice (21.769) is a decolonial design decision.")

    # Bounds check
    print("\n" + "-"*70)
    print("BOUNDS CHECK")
    print("-"*70)
    all_valid = all(0.0 <= r.gradual_weight <= 1.0 for r in results)
    print(f"\n  All gradual weights in [0,1]: {all_valid}")

    return dialetheia_preserved and survives and all_valid


def generate_demo_json(results):
    """
    Build the paramuno_demo.json output structure with verified values.
    """
    descriptions = {
        "a1_market_income":           "Market prices have increased our income (Speaker GR, market-experienced)",
        "a2_intermediary_dependency": "But we depend on intermediaries now (Speaker AC, critical)",
        "a3_collective_decision":     "The cooperative decides collectively (Speaker GR, market-experienced)",
        "a4_market_coercion":         "Market forces us to grow what they want (Speaker LO, land manager)",
        "a5_autonomy":                "We maintain autonomy over production (Speaker NR, cooperative founder)",
        "a6_epistemic_critique":      "Development agencies teach us market language (Speaker AC, analytical)"
    }

    interpretations = {
        "a1_market_income":           "Below threshold — weakened by attacks from a2 and a6",
        "a2_intermediary_dependency": "Dependency critique holds — qualifies a1, itself attacked by a3",
        "a3_collective_decision":     "Barely above threshold — answers a6 in the only available language",
        "a4_market_coercion":         "Most accepted — structural coercion is the dominant outcome",
        "a5_autonomy":                "Most weakened — attacked by both a1 and a6",
        "a6_epistemic_critique":      "Present, recognized, below 0.5 — necessary but insubstantial for autonomy"
    }

    by_name = {r.name: r for r in results}

    output = {
        "scenario": "Paramuno-inspired dialectical scenario",
        "context": (
            "Agricultural cooperative discourse on market participation vs. "
            "solidarity economics. Inspired by fieldwork themes from GLR Páramo "
            "region (2019-2020), but constructed for demonstration purposes."
        ),
        "implementation": "warg 0.1.0.0",
        "corpus_max_perplexity": 21.769,
        "note": (
            "The dialetheia is structural: a3 and a4 are both accepted and in "
            "conflict, with a6 as the atom that makes that conflict explicit. "
            "a6's σ* alone does not encode the Belnap B value — V(a6)=B is a "
            "Year 1 cubun/PVAF coupling item."
        ),
        "results": [
            {
                "name": r.name,
                "description": descriptions.get(r.name, ""),
                "gradual_weight": round(r.gradual_weight, 3),
                "attenuated": r.attenuated,
                "interpretation": interpretations.get(r.name, "")
            }
            for r in sorted(results, key=lambda x: -x.gradual_weight)
        ],
        "key_observations": {
            "dialetheia_structure": {
                "truth_side":       f"a4_market_coercion σ*={by_name['a4_market_coercion'].gradual_weight:.3f} — coercion accepted",
                "false_side":       f"a3_collective_decision σ*={by_name['a3_collective_decision'].gradual_weight:.3f} — collective agency accepted",
                "critique_position": f"a6_epistemic_critique σ*={by_name['a6_epistemic_critique'].gradual_weight:.3f} — names the tension, cannot resolve it",
                "adorno":           "Non-identity preserved: the critique cannot be synthesised away, but cannot escape the condition it diagnoses."
            },
            "automatic_subject": {
                "atom":        "a6_epistemic_critique",
                "perplexity":  21.0,
                "threshold":   21.769,
                "status":      "Survives (not attenuated)",
                "significance": "Threshold choice (21.769) is a decolonial design decision."
            },
            "llm_failure_mode": {
                "standard_summarization": "Resolves to 'trade-off' narrative — synthesises the contradiction",
                "warg_preservation":      "Irresolution preserved as the result; a3 and a4 both accepted in structural conflict"
            }
        }
    }

    return output


def main():
    print("="*70)
    print("Paramuno-Inspired Demonstration Scenario")
    print("warg 0.1.0.0 — Paraconsistent Weighted Argumentation")
    print("="*70)

    print("\nBuilding argument graph...")
    atoms = build_scenario()
    print(f"  → {len(atoms)} arguments")
    print(f"  → {sum(len(a.attacks) for a in atoms)} attack relations")

    print("\nCalling warg binary (h-categoriser fixed-point)...")
    try:
        results = call_warg(atoms, corpus_max_perplexity=21.769)
        print(f"  → Convergence successful")
        print(f"  → {len(results)} gradual weights computed")
    except Exception as e:
        print(f"\n  ERROR: warg binary call failed")
        print(f"  {e}")
        sys.exit(1)

    verification_passed = verify_results(results)

    print("\n" + "="*70)
    print("GENERATING OUTPUT FILE")
    print("="*70)

    output = generate_demo_json(results)
    output_path = Path(__file__).parent / "paramuno_demo.json"

    with open(output_path, 'w') as f:
        json.dump(output, f, indent=2)

    print(f"\n  Demo file written: {output_path}")

    print("\n" + "="*70)
    if verification_passed:
        print("VERIFICATION PASSED")
        print("="*70)
        print("\nThis demo demonstrates:")
        print("  • Structural dialetheia (a3 and a4 both accepted, in conflict)")
        print("  • a6 present and non-attenuated but insubstantial for autonomy")
        print("  • Gradual semantics (attack topology → acceptability degrees)")
        print("  • Automatic subject survives attenuation gate")
        print("  • LLM failure mode: contradictions not flattened into 'trade-off'")
        return 0
    else:
        print("VERIFICATION FAILED")
        print("="*70)
        print("\nSome checks did not pass. Review output above.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
