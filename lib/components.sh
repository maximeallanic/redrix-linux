# shellcheck shell=bash disable=SC2034  # variables shared with the scripts that source this file
# Component registry. Each component lives in components/<id>/component.sh and defines:
#   TITLE      short name shown in the checklist
#   SUMMARY    one plain-language sentence: what you get
#   RISK       low | medium | high  (high: PAM, boot chain; never preselected, typed confirmation)
#   DEFAULT    1 when preselected in the checklist (only ever for low-risk components)
#   ROOT       1 when it changes system files (sudo)
#   DEBIAN_PACKAGES  space-separated Debian/Ubuntu package names it needs (may be empty)
#   REQUIRES   other component ids that must be installed first (may be empty)
#   CHANGES    what it changes, one item per line (shown before medium/high-risk installs)
#   ROLLBACK   how to undo it by hand if the kit itself is gone
#   component_supported   optional: returns 1 and prints why when it cannot apply to this machine
#   component_install, component_uninstall, component_verify
# A component is sourced in a subshell, so its variables and functions never leak into another one.

# Display order of the checklist: the safe, everyday ones first.
REDRIX_COMPONENTS=(
    haptics pen top-row camera microphone speakers suspend battery-guard keychron
    fingerprint fingerprint-login lockscreen-fingerprint boot-splash shutdown-splash
)

component_dir() { printf '%s/components/%s' "$REDRIX_ROOT" "$1"; }

is_component() {
    local c
    for c in "${REDRIX_COMPONENTS[@]}"; do [[ $c == "$1" ]] && return 0; done
    return 1
}

# component_field ID FIELD: one metadata value.
component_field() {
    (
        COMPONENT_DIR=$(component_dir "$1")
        COMPONENT_ID=$1
        # shellcheck source=/dev/null
        source "$COMPONENT_DIR/component.sh"
        printf '%s' "${!2:-}"
    )
}

# component_call ID FUNCTION [ARGS...]: runs one of the component's functions in its own subshell, with
# COMPONENT_DIR pointing at its files.
component_call() {
    local id=$1 fn=$2
    shift 2
    (
        COMPONENT_DIR=$(component_dir "$id")
        COMPONENT_ID=$id
        # Install and uninstall stop at the first failing command (see component_run).
        if [[ ${REDRIX_STRICT:-0} == 1 ]]; then set -euo pipefail; fi
        # shellcheck source=/dev/null
        source "$COMPONENT_DIR/component.sh"
        if [[ $(type -t "$fn") != function ]]; then
            [[ $fn == component_supported ]] && exit 0
            die "component $id has no $fn"
        fi
        "$fn" "$@"
    )
}

# component_run ID FUNCTION [ARGS...]: component_call with errexit on, status in COMPONENT_RC, always returns 0.
# Bash ignores `set -e` in anything run as the condition of an if, && or ||, subshells included, so an install
# called as `if ! component_call ...` would carry on after a failed command. Callers test COMPONENT_RC instead.
component_run() {
    local had_errexit=0
    [[ $- == *e* ]] && had_errexit=1
    set +e
    REDRIX_STRICT=1 component_call "$@"
    COMPONENT_RC=$?
    if ((had_errexit)); then set -e; fi
    return 0
}

# Order IDS so that every component comes after the ones it requires (registry order otherwise).
order_components() {
    local wanted=" $* " c out=()
    for c in "${REDRIX_COMPONENTS[@]}"; do [[ $wanted == *" $c "* ]] && out+=("$c"); done
    printf '%s\n' "${out[@]}"
}
