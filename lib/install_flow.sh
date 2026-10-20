# shellcheck shell=bash
# install.sh once the kit is on disk: arguments, checklist, confirmations, packages, install, checks.

install_usage() { sed -n '2,/^# Docs:/p' "$REDRIX_ROOT/install.sh" | sed 's/^# \{0,1\}//'; }

list_components() {
    local id risk _default available title summary reason status rows
    rows=$(menu_rows)
    printf '%-24s %-12s %-11s %s\n' COMPONENT RISK STATUS DESCRIPTION
    while IFS=$'\t' read -r id risk _default available title summary reason; do
        status=available
        state_installed "$id" && status=installed
        [[ $available == 1 ]] || status=n/a
        printf '%-24s %-12s %-11s %s%s\n' "$id" "$(risk_label "$risk")" "$status" "$summary" \
            "$([[ $available == 1 ]] || printf ' [%s]' "$reason")"
    done <<<"$rows"
}

# confirm_component ID NAMED: 0 to go ahead. Low risk: chosen is enough. Medium: yes/no after the list of changes.
# High: the id typed back. With --yes, medium and high need the component named on the command line, and high
# also needs --accept-risk.
confirm_component() {
    local id=$1 named=$2 risk title
    risk=$(component_field "$id" RISK)
    title=$(component_field "$id" TITLE)
    [[ $risk == low ]] && return 0
    printf '\n%s%s%s - %s\n' "$C_BOLD" "$title" "$C_OFF" "$(risk_label "$risk")"
    say "What changes:"
    printf '%s\n' "$(component_field "$id" CHANGES)" | sed 's/^/  - /'
    say "How to undo it: ./uninstall.sh $id, or by hand:"
    printf '%s\n' "$(component_field "$id" ROLLBACK)" | sed 's/^/    /'
    say "Details: docs/components/$id.md"
    if [[ $REDRIX_ASSUME_YES == 1 ]]; then
        [[ $named == 1 ]] || { warn "skipping $id: with --yes, $(risk_label "$risk") components must be named"; return 1; }
        [[ $risk != high || $ACCEPT_RISK == 1 ]] || { warn "skipping $id: high risk, needs --accept-risk"; return 1; }
        return 0
    fi
    if [[ $risk == high ]]; then
        ask_typed "$id" "This changes how you log in or how the machine boots."
    else
        ask_yes_no "Install $title?" n
    fi
}

install_main() {
    local named=() selected=() chosen=() id req force=0 verify=1 remove=0
    ACCEPT_RISK=0
    while (($#)); do
        case "$1" in
            --list) LIST_ONLY=1 ;;
            --dry-run) REDRIX_DRY_RUN=1 ;;
            -y|--yes) REDRIX_ASSUME_YES=1 ;;
            --accept-risk) ACCEPT_RISK=1 ;;
            --no-verify) verify=0 ;;
            --force) force=1 ;;
            --remove|--uninstall) remove=1 ;;
            --version) echo "redrix-linux $REDRIX_VERSION"; return 0 ;;
            -h|--help) install_usage; return 0 ;;
            -*) die "unknown option $1 (see --help)" ;;
            *) is_component "$1" || die "unknown component \"$1\" (see --list)"; named+=("$1") ;;
        esac
        shift
    done
    if [[ $remove == 1 ]]; then
        exec "$REDRIX_ROOT/uninstall.sh" "${named[@]}"
    fi
    [[ ${REDRIX_SKIP_SESSION_CHECK:-0} == 1 ]] || require_user_session
    require_board "$force"
    if [[ ${LIST_ONLY:-0} == 1 ]]; then list_components; return 0; fi

    step "redrix-linux $REDRIX_VERSION"
    note "machine:  $(board_description), firmware $(firmware_version) ($(firmware_kind))"
    note "system:   $(os_release_field PRETTY_NAME), $(gnome-shell --version 2>/dev/null || echo 'GNOME Shell not found')"
    [[ $REDRIX_DRY_RUN == 1 ]] && note "dry run: nothing will be changed"

    local picked=''
    if ((${#named[@]})); then
        selected=("${named[@]}")
    elif [[ $REDRIX_ASSUME_YES == 1 ]]; then
        picked=$(default_selection)
    else
        picked=$(choose_components)
    fi
    if [[ -n $picked ]]; then mapfile -t selected <<<"$picked"; fi
    ((${#selected[@]})) || { say "Nothing selected, nothing changed."; return 0; }

    # Prerequisites come in with their own confirmation, and only stay if what needs them is confirmed too.
    local -A added_for=()
    for id in "${selected[@]}"; do
        for req in $(component_field "$id" REQUIRES); do
            if ! state_installed "$req" && [[ " ${selected[*]} " != *" $req "* ]]; then
                note "$id needs $req: added"
                selected+=("$req")
                added_for[$req]+=" $id"
            fi
        done
    done
    picked=$(order_components "${selected[@]}")
    mapfile -t selected <<<"$picked"

    for id in "${selected[@]}"; do
        local why
        if ! why=$(component_call "$id" component_supported 2>&1); then warn "skipping $id: $why"; continue; fi
        if confirm_component "$id" "$([[ " ${named[*]} " == *" $id "* ]] && echo 1 || echo 0)"; then
            chosen+=("$id")
        else
            note "skipped: $id"
        fi
    done
    local kept=() dependent wanted
    for id in "${chosen[@]}"; do
        wanted=1
        if [[ -n ${added_for[$id]:-} ]]; then
            wanted=0
            for dependent in ${added_for[$id]}; do [[ " ${chosen[*]} " == *" $dependent "* ]] && wanted=1; done
        fi
        if ((wanted)); then kept+=("$id"); else note "not installing $id: nothing chosen needs it"; fi
    done
    chosen=("${kept[@]}")
    ((${#chosen[@]})) || { say "Nothing to install."; return 0; }
    for id in "${chosen[@]}"; do
        for req in $(component_field "$id" REQUIRES); do
            state_installed "$req" || [[ " ${chosen[*]} " == *" $req "* ]] ||
                die "$id needs $req, which was skipped; nothing was installed"
        done
    done

    step "Plan: ${chosen[*]}"
    local root_needed=()
    for id in "${chosen[@]}"; do [[ $(component_field "$id" ROOT) == 1 ]] && root_needed+=("$id"); done
    ((${#root_needed[@]})) && sudo_prime "${root_needed[*]}"
    ensure_packages "${chosen[@]}"

    local done_ids=()
    for id in "${chosen[@]}"; do
        step "Installing $(component_field "$id" TITLE) ($id)"
        component_run "$id" component_install
        if ((COMPONENT_RC)); then
            warn "$id failed. Installed so far: ${done_ids[*]:-nothing}."
            warn "Undo a component with ./uninstall.sh <component>; details in docs/components/$id.md."
            return 1
        fi
        state_mark "$id"
        done_ids+=("$id")
    done

    if [[ $verify == 1 && $REDRIX_DRY_RUN != 1 ]]; then
        step "Checking what was installed"
        "$REDRIX_ROOT/verify.sh" "${done_ids[@]}" || note "some checks failed: several only pass after a new login or a reboot (see each hint)"
    fi
    say ""
    if [[ $REDRIX_DRY_RUN == 1 ]]; then
        say "Dry run finished: nothing was changed. Without --dry-run this would install: ${done_ids[*]}."
        return 0
    fi
    say "Done: ${done_ids[*]}."
    say "Log out and back in to load the GNOME Shell extensions; reboot for speakers, boot and suspend changes."
    say "Check again at any time: $REDRIX_ROOT/verify.sh    Undo: $REDRIX_ROOT/uninstall.sh <component>"
}
