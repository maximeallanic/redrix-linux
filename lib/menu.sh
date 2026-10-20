# shellcheck shell=bash
# The component checklist. whiptail when it is installed, a plain numbered list otherwise; both read /dev/tty so
# they work under `curl ... | bash`.

risk_label() {
    case "$1" in
        low) printf 'low risk' ;;
        medium) printf 'medium risk' ;;
        high) printf 'HIGH RISK' ;;
        *) printf 'unknown risk' ;;
    esac
}

# menu_rows: "id<TAB>risk<TAB>default<TAB>available<TAB>title<TAB>summary<TAB>reason" for every component.
menu_rows() {
    local id reason available default risk title summary
    for id in "${REDRIX_COMPONENTS[@]}"; do
        if reason=$(component_call "$id" component_supported 2>&1); then available=1; reason=''; else available=0; fi
        risk=$(component_field "$id" RISK)
        default=$(component_field "$id" DEFAULT)
        title=$(component_field "$id" TITLE)
        summary=$(component_field "$id" SUMMARY)
        # Only low-risk components may ever be preselected, whatever a component file says.
        if [[ $risk != low || $default != 1 || $available != 1 ]]; then default=0; fi
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$risk" "$default" "$available" "$title" "$summary" "${reason//$'\n'/ }"
    done
}

# default_selection: the preselected ids, one per line (what --yes installs when no component is named).
default_selection() {
    local id risk default available _rest rows
    rows=$(menu_rows)
    while IFS=$'\t' read -r id risk default available _rest; do
        if [[ $default == 1 ]]; then printf '%s\n' "$id"; fi
    done <<<"$rows"
}

# choose_components: prints the chosen ids, one per line. Empty output: nothing chosen.
choose_components() {
    tty_available || die "no terminal for the checklist: name the components (./install.sh camera pen ...) or pass --yes"
    if command -v whiptail >/dev/null; then choose_whiptail; else choose_text; fi
}

choose_whiptail() {
    local id risk default available title summary reason args=() unavailable='' state mark rows
    rows=$(menu_rows)
    while IFS=$'\t' read -r id risk default available title summary reason; do
        if [[ $available != 1 ]]; then unavailable+="  - $title: $reason"$'\n'; continue; fi
        state=OFF; [[ $default == 1 ]] && state=ON
        mark=''; state_installed "$id" && mark=' (installed)'
        args+=("$id" "$title$mark - $(risk_label "$risk"). $summary" "$state")
    done <<<"$rows"
    local text="Space toggles, Enter confirms. Low-risk items are preselected; medium and high-risk items ask again before anything is changed. Full descriptions: ./install.sh --list"
    [[ -n $unavailable ]] && text+=$'\n\nNot available on this machine:\n'"$unavailable"
    # Fit the terminal: whiptail draws past the edges instead of shrinking, and scrolls a list that is too long.
    local size lines cols height width list_height text_lines
    size=$(stty size </dev/tty)
    lines=${size% *} cols=${size#* }
    width=$((cols < 120 ? cols - 2 : 118))
    text_lines=$(fold -s -w $((width - 4)) <<<"$text" | wc -l)
    height=$((lines - 2))
    list_height=$((height - text_lines - 7))
    if ((list_height < 3 || width < 50)); then
        warn "terminal too small for the checklist (${cols}x${lines}): using the plain list"
        choose_text
        return 0
    fi
    ((list_height > ${#args[@]} / 3)) && list_height=$((${#args[@]} / 3)) && height=$((list_height + text_lines + 7))
    local out
    out=$(whiptail --title "redrix-linux $REDRIX_VERSION - components" --separate-output --checklist "$text" \
        "$height" "$width" "$list_height" "${args[@]}" 3>&1 1>/dev/tty 2>&3 </dev/tty) || return 0   # Cancel: nothing chosen
    printf '%s\n' "$out"
}

choose_text() {
    local rows=() id risk default available title summary reason i n answer tok all
    local -A on=()
    all=$(menu_rows)
    while IFS=$'\t' read -r id risk default available title summary reason; do
        rows+=("$id"$'\t'"$risk"$'\t'"$available"$'\t'"$title"$'\t'"$summary"$'\t'"$reason")
        if [[ $default == 1 ]]; then on[$id]=1; fi
    done <<<"$all"
    while true; do
        {
            printf '\n%sComponents%s (x = selected)\n' "$C_BOLD" "$C_OFF"
            for i in "${!rows[@]}"; do
                IFS=$'\t' read -r id risk available title summary reason <<<"${rows[$i]}"
                n=$((i + 1))
                if [[ $available != 1 ]]; then
                    printf '  %2d. [-] %s (not available: %s)\n' "$n" "$title" "$reason"
                    continue
                fi
                printf '  %2d. [%s] %s%s%s - %s%s\n' "$n" "$([[ -n ${on[$id]:-} ]] && echo x || echo ' ')" \
                    "$C_BOLD" "$title" "$C_OFF" "$(risk_label "$risk")" "$(state_installed "$id" && echo ', installed')"
                printf '          %s\n' "$summary"
            done
            printf '\nNumbers to toggle (e.g. "3 7"), Enter to continue, q to quit: '
        } >/dev/tty
        read -r answer </dev/tty || answer=q
        [[ $answer == q ]] && return 0
        [[ -z $answer ]] && break
        for tok in $answer; do
            if ! [[ $tok =~ ^[0-9]+$ ]] || ((tok < 1 || tok > ${#rows[@]})); then
                printf 'ignored: %s\n' "$tok" >/dev/tty
                continue
            fi
            IFS=$'\t' read -r id risk available _ <<<"${rows[$((tok - 1))]}"
            [[ $available == 1 ]] || { printf 'not available here: %s\n' "$id" >/dev/tty; continue; }
            if [[ -n ${on[$id]:-} ]]; then unset "on[$id]"; else on[$id]=1; fi
        done
    done
    for i in "${!rows[@]}"; do
        id=${rows[$i]%%$'\t'*}
        [[ -n ${on[$id]:-} ]] && printf '%s\n' "$id"
    done
    return 0
}
