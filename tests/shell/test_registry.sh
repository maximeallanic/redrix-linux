#!/usr/bin/env bash
# Every real component is complete and consistent: metadata, functions, docs page, risk rules, dependencies.
set -uo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
# shellcheck source=tests/shell/assert.sh
source "$HERE/assert.sh"
REDRIX_ROOT=$ROOT
# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"
# shellcheck source=lib/components.sh
source "$ROOT/lib/components.sh"

test_every_directory_is_registered_and_back() {
    local d listed
    listed=" ${REDRIX_COMPONENTS[*]} "
    for d in "$ROOT"/components/*/; do
        d=${d%/}; d=${d##*/}
        t_contains "$listed" " $d " "components/$d is not in REDRIX_COMPONENTS"
    done
    for d in "${REDRIX_COMPONENTS[@]}"; do [[ -f $ROOT/components/$d/component.sh ]] || t_fail "no components/$d/component.sh"; done
}

test_metadata_is_complete() {
    local id f v
    for id in "${REDRIX_COMPONENTS[@]}"; do
        for f in TITLE SUMMARY RISK DEFAULT ROOT CHANGES ROLLBACK; do
            v=$(component_field "$id" "$f")
            [[ -n $v ]] || t_fail "$id: $f is empty"
        done
        [[ $(component_field "$id" RISK) =~ ^(low|medium|high)$ ]] || t_fail "$id: bad RISK"
        [[ $(component_field "$id" DEFAULT) =~ ^[01]$ ]] || t_fail "$id: bad DEFAULT"
        [[ $(component_field "$id" ROOT) =~ ^[01]$ ]] || t_fail "$id: bad ROOT"
    done
}

test_only_low_risk_can_be_preselected() {
    local id
    for id in "${REDRIX_COMPONENTS[@]}"; do
        if [[ $(component_field "$id" DEFAULT) == 1 ]]; then t_eq "$(component_field "$id" RISK)" low "$id is preselected"; fi
    done
}

test_pam_boot_and_firmware_are_never_low_risk() {
    local id
    for id in fingerprint-login boot-splash; do t_eq "$(component_field "$id" RISK)" high "$id"; done
    for id in fingerprint speakers suspend shutdown-splash lockscreen-fingerprint; do
        [[ $(component_field "$id" RISK) != low ]] || t_fail "$id must not be low risk"
    done
}

test_functions_are_defined() {
    local id fn
    for id in "${REDRIX_COMPONENTS[@]}"; do
        for fn in component_install component_uninstall component_verify; do
            ( COMPONENT_DIR=$ROOT/components/$id
              # shellcheck source=/dev/null
              source "$COMPONENT_DIR/component.sh"; [[ $(type -t "$fn") == function ]] ) || t_fail "$id: no $fn"
        done
    done
}

test_requirements_exist_and_come_first() {
    local id req ids=" ${REDRIX_COMPONENTS[*]} " before
    for id in "${REDRIX_COMPONENTS[@]}"; do
        for req in $(component_field "$id" REQUIRES); do
            t_contains "$ids" " $req " "$id requires unknown $req"
            before=${ids%% "$id" *}
            t_contains "$before " " $req " "$req must be listed before $id"
        done
    done
}

test_every_component_has_a_docs_page() {
    local id
    for id in "${REDRIX_COMPONENTS[@]}"; do [[ -s $ROOT/docs/components/$id.md ]] || t_fail "docs/components/$id.md missing"; done
}

test_root_components_say_so() {
    local id src
    for id in "${REDRIX_COMPONENTS[@]}"; do
        src=$(sed -n '/^component_install()/,$p' "$ROOT/components/$id/component.sh")
        if grep -qE 'as_root|install_if_changed|remove_root_file|write_sysfs' <<<"$src"; then
            t_eq "$(component_field "$id" ROOT)" 1 "$id changes system files"
        fi
    done
}

run_tests
