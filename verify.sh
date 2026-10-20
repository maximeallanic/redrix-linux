#!/usr/bin/env bash
# Checks components without changing anything: one line per check, a hint under each failure.
#
#   ./verify.sh                 the components installed by this user
#   ./verify.sh camera speakers only these (installed or not: useful to see the state before installing)
#   ./verify.sh --all           every component
# Exit status: the number of components with a failed check (0: all good).
set -uo pipefail
REDRIX_ROOT=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
for f in common board components checks gnome; do
    # shellcheck source=/dev/null
    source "$REDRIX_ROOT/lib/$f.sh"
done

ids=()
for arg in "$@"; do
    case "$arg" in
        --all) ids=("${REDRIX_COMPONENTS[@]}") ;;
        -h|--help) sed -n '2,/^set -uo/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
        *) is_component "$arg" || { echo "unknown component \"$arg\"" >&2; exit 64; }; ids+=("$arg") ;;
    esac
done
if ((${#ids[@]} == 0)); then
    mapfile -t ids < <(state_list)
    ((${#ids[@]})) || { say "Nothing installed by redrix-linux for this user. Try: ./verify.sh --all"; exit 0; }
fi
is_redrix || warn "this is a $(board_description), not a Redrix: most checks will fail"

bad=0
for id in "${ids[@]}"; do
    printf '\n%s%s%s (%s)\n' "$C_BOLD" "$(component_field "$id" TITLE)" "$C_OFF" "$id"
    if ! why=$(component_call "$id" component_supported 2>&1); then skip "not applicable here: $why"; continue; fi
    component_call "$id" component_verify || bad=$((bad + 1))
done
printf '\n'
if ((bad == 0)); then say "${C_GREEN}Everything checked is in order.${C_OFF}"; else say "${C_RED}$bad component(s) with failed checks.${C_OFF}"; fi
exit "$bad"
