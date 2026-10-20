#!/usr/bin/env bash
# Removes components installed by redrix-linux, newest dependents first. Each component puts back what it changed
# and deletes only the exact files it installed; your own settings files (haptics events.toml) are kept.
#
#   ./uninstall.sh                 every installed component (asks first)
#   ./uninstall.sh camera pen      only these (and, after asking, what depends on them)
#   ./uninstall.sh --dry-run ...   show the commands, change nothing
#   ./uninstall.sh --yes ...       do not ask
# shellcheck disable=SC2034  # REDRIX_* flags are read by lib/common.sh
set -euo pipefail
REDRIX_ROOT=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
for f in common board components checks gnome; do
    # shellcheck source=/dev/null
    source "$REDRIX_ROOT/lib/$f.sh"
done

ids=()
while (($#)); do
    case "$1" in
        --dry-run) REDRIX_DRY_RUN=1 ;;
        -y|--yes) REDRIX_ASSUME_YES=1 ;;
        -h|--help) sed -n '2,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
        -*) die "unknown option $1" ;;
        *) is_component "$1" || die "unknown component \"$1\""; ids+=("$1") ;;
    esac
    shift
done
[[ ${REDRIX_SKIP_SESSION_CHECK:-0} == 1 ]] || require_user_session

if ((${#ids[@]} == 0)); then
    mapfile -t ids < <(state_list)
    ((${#ids[@]})) || { say "No component of redrix-linux is installed for this user."; exit 0; }
fi
# Installed components that depend, directly or not, on one being removed go too, and first.
installed=$(state_list)
grew=1
while ((grew)); do
    grew=0
    for id in $installed; do
        for req in $(component_field "$id" REQUIRES); do
            if [[ " ${ids[*]} " == *" $req "* && " ${ids[*]} " != *" $id "* ]]; then
                say "$id depends on $req and will be removed too."
                ids+=("$id")
                grew=1
            fi
        done
    done
done
mapfile -t ordered < <(order_components "${ids[@]}")
removal=()
for ((i = ${#ordered[@]} - 1; i >= 0; i--)); do removal+=("${ordered[$i]}"); done

say "To remove: ${removal[*]}"
ask_yes_no "Continue?" y || { say "Nothing changed."; exit 0; }
needs_root=()
for id in "${removal[@]}"; do [[ $(component_field "$id" ROOT) == 1 ]] && needs_root+=("$id"); done
((${#needs_root[@]})) && sudo_prime "removing ${needs_root[*]}"

failed=()
for id in "${removal[@]}"; do
    step "Removing $(component_field "$id" TITLE) ($id)"
    component_run "$id" component_uninstall
    if ((COMPONENT_RC == 0)); then state_clear "$id"; else failed+=("$id"); warn "$id: removal failed, see above"; fi
done
((${#failed[@]} == 0)) || die "not fully removed: ${failed[*]} (see docs/components/<id>.md, section Rollback)"
packages=''
for id in "${removal[@]}"; do packages+=" $(component_field "$id" DEBIAN_PACKAGES)"; done
packages=$(tr ' ' '\n' <<<"$packages" | sed '/^$/d' | sort -u | tr '\n' ' ')
[[ -z $packages ]] || note "packages are kept (other software may use them): $packages"
say "Removed: ${removal[*]}. Log out and back in (extensions) or reboot (speakers, boot, suspend) to finish."
