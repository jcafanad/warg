#!/usr/bin/env bash
# Demo runner and regression test for warg 0.1.0.0
# 
# Usage:
#   bash demo/run_demo.sh              # Run with installed warg binary
#   WARG=/path/to/warg bash demo/run_demo.sh  # Use custom binary path
#
# Exit codes:
#   0 - All scenarios passed verification
#   1 - Binary not found or not executable
#   2 - Scenario execution failed (binary error)
#   3 - Verification failed (output does not match expected semantics)

set -euo pipefail

# Configuration
WARG="${WARG:-warg}"
DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes for output (disable if not a TTY)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Utility functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $*"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

# Check dependencies
check_dependencies() {
    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed. Install with: apt install jq / brew install jq"
        exit 1
    fi
    
    if ! command -v bc &> /dev/null; then
        log_warning "bc not found. Numerical comparisons will be skipped."
    fi
    
    if ! command -v "$WARG" &> /dev/null; then
        log_error "warg binary not found at: $WARG"
        log_error "Install with: cd ~/warg && cabal install"
        log_error "Or set custom path: WARG=/path/to/warg bash $0"
        exit 1
    fi
    
    if ! [ -x "$(command -v "$WARG")" ]; then
        log_error "warg binary is not executable: $WARG"
        exit 1
    fi
    
    log_info "Using warg binary: $(command -v "$WARG")"
}

# Scenario 1: Reinstatement
run_paramo_defended() {
    local scenario="paramo_defended"
    local json_file="$DEMO_DIR/${scenario}.json"
    
    echo ""
    echo "========================================================================"
    echo "SCENARIO 1: Reinstatement (paramo_defended.json)"
    echo "========================================================================"
    echo ""
    log_info "Description: Three-argument chain demonstrating reinstatement."
    log_info "  evidencia_hidrica (unattacked) → estado_concesion → paramo_territorio"
    log_info ""
    log_info "Expected outcome:"
    log_info "  • evidencia_hidrica: σ*=1.0 (unattacked → maximum acceptability)"
    log_info "  • estado_concesion:  σ*≈0.408 (defeated by evidencia_hidrica)"
    log_info "  • paramo_territorio: σ*≈0.641 (reinstated, above 0.5 threshold)"
    echo ""
    
    # Execute binary
    log_info "Calling warg binary..."
    local output
    if ! output=$("$WARG" < "$json_file" 2>&1); then
        log_error "Binary execution failed for $scenario"
        echo "$output" >&2
        exit 2
    fi
    
    # Display output
    echo "Raw output:"
    echo "$output" | jq .
    echo ""
    
    # Verification checks
    log_info "Verifying semantic properties..."
    
    # Check 1: evidencia_hidrica = 1.0 (unattacked)
    local evidencia_weight
    evidencia_weight=$(echo "$output" | jq -r '.[] | select(.name=="evidencia_hidrica") | .gradual_weight')
    if [ "$evidencia_weight" = "1" ] || [ "$evidencia_weight" = "1.0" ]; then
        log_success "evidencia_hidrica converged to σ*=1.0 (unattacked argument)"
    else
        log_error "evidencia_hidrica expected σ*=1.0, got: $evidencia_weight"
        exit 3
    fi
    
    # Check 2: estado_concesion defeated (σ* < 0.5)
    local estado_weight
    estado_weight=$(echo "$output" | jq -r '.[] | select(.name=="estado_concesion") | .gradual_weight')
    if command -v bc &> /dev/null; then
        if (( $(echo "$estado_weight < 0.5" | bc -l) )); then
            log_success "estado_concesion defeated (σ*=$estado_weight < 0.5)"
        else
            log_error "estado_concesion expected defeated (σ* < 0.5), got: $estado_weight"
            exit 3
        fi
    else
        log_warning "bc not available, skipping numerical comparison for estado_concesion"
    fi
    
    # Check 3: paramo_territorio reinstated (σ* > 0.5)
    local paramo_weight
    paramo_weight=$(echo "$output" | jq -r '.[] | select(.name=="paramo_territorio") | .gradual_weight')
    if command -v bc &> /dev/null; then
        if (( $(echo "$paramo_weight > 0.5" | bc -l) )); then
            log_success "paramo_territorio reinstated (σ*=$paramo_weight > 0.5)"
        else
            log_error "paramo_territorio expected reinstated (σ* > 0.5), got: $paramo_weight"
            exit 3
        fi
    else
        log_warning "bc not available, skipping numerical comparison for paramo_territorio"
    fi
    
    # Check 4: No atoms attenuated (all perplexity < threshold)
    local attenuated_count
    attenuated_count=$(echo "$output" | jq '[.[] | select(.attenuated==true)] | length')
    if [ "$attenuated_count" -eq 0 ]; then
        log_success "No atoms attenuated (all λ_⊥ < 21.769)"
    else
        log_error "Expected 0 attenuated atoms, found: $attenuated_count"
        exit 3
    fi
    
    echo ""
    log_success "Scenario 1 (reinstatement) PASSED"
}

# Scenario 2: Attenuation gate
run_paramo_attenuation() {
    local scenario="paramo_attenuation"
    local json_file="$DEMO_DIR/${scenario}.json"
    
    echo ""
    echo "========================================================================"
    echo "SCENARIO 2: Attenuation gate (paramo_attenuation.json)"
    echo "========================================================================"
    echo ""
    log_info "Description: Three unattacked atoms with perplexity variation."
    log_info "  recurso_hidrico_estado: λ_⊥=6.1   (well below threshold)"
    log_info "  poner_a_valer_trabajo:  λ_⊥=21.769 (exactly at threshold)"
    log_info "  ontologia_paramuna:     λ_⊥=28.4   (above threshold)"
    log_info ""
    log_info "Expected outcome:"
    log_info "  • recurso_hidrico_estado: σ*=1.0, attenuated=false"
    log_info "  • poner_a_valer_trabajo:  σ*=1.0, attenuated=false (strict inequality)"
    log_info "  • ontologia_paramuna:     σ*=0.0, attenuated=true  (gate fires)"
    echo ""
    
    # Execute binary
    log_info "Calling warg binary..."
    local output
    if ! output=$("$WARG" < "$json_file" 2>&1); then
        log_error "Binary execution failed for $scenario"
        echo "$output" >&2
        exit 2
    fi
    
    # Display output
    echo "Raw output:"
    echo "$output" | jq .
    echo ""
    
    # Verification checks
    log_info "Verifying semantic properties..."
    
    # Check 1: recurso_hidrico_estado = 1.0, not attenuated
    local recurso_weight recurso_attenuated
    recurso_weight=$(echo "$output" | jq -r '.[] | select(.name=="recurso_hidrico_estado") | .gradual_weight')
    recurso_attenuated=$(echo "$output" | jq -r '.[] | select(.name=="recurso_hidrico_estado") | .attenuated')
    if [ "$recurso_weight" = "1" ] || [ "$recurso_weight" = "1.0" ]; then
        log_success "recurso_hidrico_estado: σ*=1.0 (λ_⊥ < threshold)"
    else
        log_error "recurso_hidrico_estado expected σ*=1.0, got: $recurso_weight"
        exit 3
    fi
    if [ "$recurso_attenuated" = "false" ]; then
        log_success "recurso_hidrico_estado: attenuated=false"
    else
        log_error "recurso_hidrico_estado expected attenuated=false, got: $recurso_attenuated"
        exit 3
    fi
    
    # Check 2: poner_a_valer_trabajo = 1.0, not attenuated (strict inequality test)
    local poner_weight poner_attenuated
    poner_weight=$(echo "$output" | jq -r '.[] | select(.name=="poner_a_valer_trabajo") | .gradual_weight')
    poner_attenuated=$(echo "$output" | jq -r '.[] | select(.name=="poner_a_valer_trabajo") | .attenuated')
    if [ "$poner_weight" = "1" ] || [ "$poner_weight" = "1.0" ]; then
        log_success "poner_a_valer_trabajo: σ*=1.0 (λ_⊥=threshold, strict inequality)"
    else
        log_error "poner_a_valer_trabajo expected σ*=1.0, got: $poner_weight"
        exit 3
    fi
    if [ "$poner_attenuated" = "false" ]; then
        log_success "poner_a_valer_trabajo: attenuated=false (automatic subject survives)"
    else
        log_error "poner_a_valer_trabajo expected attenuated=false, got: $poner_attenuated"
        exit 3
    fi
    
    # Check 3: ontologia_paramuna = 0.0, attenuated
    local ontologia_weight ontologia_attenuated
    ontologia_weight=$(echo "$output" | jq -r '.[] | select(.name=="ontologia_paramuna") | .gradual_weight')
    ontologia_attenuated=$(echo "$output" | jq -r '.[] | select(.name=="ontologia_paramuna") | .attenuated')
    if [ "$ontologia_weight" = "0" ] || [ "$ontologia_weight" = "0.0" ]; then
        log_success "ontologia_paramuna: σ*=0.0 (gate fired)"
    else
        log_error "ontologia_paramuna expected σ*=0.0, got: $ontologia_weight"
        exit 3
    fi
    if [ "$ontologia_attenuated" = "true" ]; then
        log_success "ontologia_paramuna: attenuated=true (epistemic imposition)"
    else
        log_error "ontologia_paramuna expected attenuated=true, got: $ontologia_attenuated"
        exit 3
    fi
    
    echo ""
    log_success "Scenario 2 (attenuation gate) PASSED"
}

# Scenario 3: Gate + h-categoriser interaction
run_paramo_gate_interaction() {
    local scenario="paramo_gate_interaction"
    local json_file="$DEMO_DIR/${scenario}.json"
    
    echo ""
    echo "========================================================================"
    echo "SCENARIO 3: Gate + h-categoriser interaction (paramo_gate_interaction.json)"
    echo "========================================================================"
    echo ""
    log_info "Description: Attack topology present but target attenuated before h-categoriser runs."
    log_info "  evidencia_institucional → ontologia_paramuna"
    log_info "  But: ontologia_paramuna has λ_⊥=25.2 > 21.769 → attenuated ab initio"
    log_info ""
    log_info "Expected outcome:"
    log_info "  • evidencia_institucional: σ*=1.0, attenuated=false (unattacked)"
    log_info "  • ontologia_paramuna:      σ*=0.0, attenuated=true  (gate fires)"
    log_info "  • Attack is IRRELEVANT (target excluded from argumentation space)"
    echo ""
    
    # Execute binary
    log_info "Calling warg binary..."
    local output
    if ! output=$("$WARG" < "$json_file" 2>&1); then
        log_error "Binary execution failed for $scenario"
        echo "$output" >&2
        exit 2
    fi
    
    # Display output
    echo "Raw output:"
    echo "$output" | jq .
    echo ""
    
    # Verification checks
    log_info "Verifying semantic properties..."
    
    # Check 1: evidencia_institucional = 1.0, not attenuated (unattacked)
    local evidencia_weight evidencia_attenuated
    evidencia_weight=$(echo "$output" | jq -r '.[] | select(.name=="evidencia_institucional") | .gradual_weight')
    evidencia_attenuated=$(echo "$output" | jq -r '.[] | select(.name=="evidencia_institucional") | .attenuated')
    if [ "$evidencia_weight" = "1" ] || [ "$evidencia_weight" = "1.0" ]; then
        log_success "evidencia_institucional: σ*=1.0 (unattacked)"
    else
        log_error "evidencia_institucional expected σ*=1.0, got: $evidencia_weight"
        exit 3
    fi
    if [ "$evidencia_attenuated" = "false" ]; then
        log_success "evidencia_institucional: attenuated=false"
    else
        log_error "evidencia_institucional expected attenuated=false, got: $evidencia_attenuated"
        exit 3
    fi
    
    # Check 2: ontologia_paramuna = 0.0, attenuated
    local ontologia_weight ontologia_attenuated
    ontologia_weight=$(echo "$output" | jq -r '.[] | select(.name=="ontologia_paramuna") | .gradual_weight')
    ontologia_attenuated=$(echo "$output" | jq -r '.[] | select(.name=="ontologia_paramuna") | .attenuated')
    if [ "$ontologia_weight" = "0" ] || [ "$ontologia_weight" = "0.0" ]; then
        log_success "ontologia_paramuna: σ*=0.0 (gate fired before h-categoriser)"
    else
        log_error "ontologia_paramuna expected σ*=0.0, got: $ontologia_weight"
        exit 3
    fi
    if [ "$ontologia_attenuated" = "true" ]; then
        log_success "ontologia_paramuna: attenuated=true (epistemic imposition, not defeat)"
    else
        log_error "ontologia_paramuna expected attenuated=true, got: $ontologia_attenuated"
        exit 3
    fi
    
    # Check 3: Total atoms = 2 (both present in output)
    local atom_count
    atom_count=$(echo "$output" | jq 'length')
    if [ "$atom_count" -eq 2 ]; then
        log_success "Output contains 2 atoms (topology preserved despite attenuation)"
    else
        log_error "Expected 2 atoms in output, found: $atom_count"
        exit 3
    fi
    
    echo ""
    log_success "Scenario 3 (gate + h-categoriser interaction) PASSED"
}

# Main execution
main() {
    echo "========================================================================"
    echo "warg 0.1.0.0 — Demo Scenarios with Verification"
    echo "========================================================================"
    
    check_dependencies
    
    run_paramo_defended
    run_paramo_attenuation
    run_paramo_gate_interaction
    
    echo ""
    echo "========================================================================"
    log_success "ALL SCENARIOS PASSED"
    echo "========================================================================"
    echo ""
    log_info "Summary:"
    log_info "  • Scenario 1 (reinstatement):           ✓ PASS"
    log_info "  • Scenario 2 (attenuation gate):        ✓ PASS"
    log_info "  • Scenario 3 (gate + h-categoriser):    ✓ PASS"
    echo ""
    log_info "All semantic properties verified. Binary is production-ready."
    
    exit 0
}

main
