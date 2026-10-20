#!/usr/bin/env bash
# install.sh / uninstall.sh / verify.sh end to end, on a copy of the kit whose components are fakes that only touch
# files in a scratch directory. sudo is a stub that runs the command as the current user.
set -uo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
# shellcheck source=tests/shell/assert.sh
source "$HERE/assert.sh"
SCRATCH=$(mktemp -d "${TEST_TMPDIR:?}/flow.XXXXXX")

# shellcheck disable=SC2016  # the stub and the fake components' bodies keep their $ unexpanded on purpose
setup_kit() {
    KIT=$SCRATCH/kit-$RANDOM
    MARK=$KIT/marks
    mkdir -p "$KIT/components" "$KIT/bin" "$MARK" "$KIT/sys/class/dmi/id" "$KIT/sys/power"
    cp -r "$ROOT/lib" "$ROOT/install.sh" "$ROOT/uninstall.sh" "$ROOT/verify.sh" "$KIT/"
    sed -i '/^REDRIX_COMPONENTS=(/,/^)/c REDRIX_COMPONENTS=(alpha beta absent broken gamma chain)' "$KIT/lib/components.sh"
    printf 'Google\n' >"$KIT/sys/class/dmi/id/sys_vendor"
    printf 'Redrix\n' >"$KIT/sys/class/dmi/id/product_name"
    printf 'MrChromebox-2609.1\n' >"$KIT/sys/class/dmi/id/bios_version"
    printf 's2idle [deep]\n' >"$KIT/sys/power/mem_sleep"
    printf '#!/bin/sh\n[ "$1" = -v ] && exit 0\n[ "$1" = -- ] && shift\nexec "$@"\n' >"$KIT/bin/sudo"
    chmod +x "$KIT/bin/sudo"
    fake alpha low 1 '' 'run touch "$MARK/alpha"; as_root touch "$MARK/alpha-root"'
    fake beta medium 1 '' 'run touch "$MARK/beta"'
    fake absent low 1 '' 'run touch "$MARK/absent"' 'component_supported() { echo "not on this machine"; return 1; }'
    fake broken low 0 '' 'run touch "$MARK/broken-start"; false; run touch "$MARK/broken-after-false"'
    fake gamma high 0 alpha 'run touch "$MARK/gamma"'
    fake chain low 0 gamma 'run touch "$MARK/chain"'
    export REDRIX_SYSFS=$KIT/sys REDRIX_STATE_DIR=$KIT/state/installed REDRIX_SKIP_SESSION_CHECK=1 MARK NO_COLOR=1
    export PATH=$KIT/bin:$PATH
}

# fake ID RISK DEFAULT REQUIRES INSTALL_BODY [EXTRA]
fake() {
    mkdir -p "$KIT/components/$1"
    cat >"$KIT/components/$1/component.sh" <<EOT
# shellcheck shell=bash
TITLE="Fake $1"
SUMMARY="Fake component $1."
RISK=$2
DEFAULT=$3
ROOT=1
DEBIAN_PACKAGES=""
REQUIRES="$4"
CHANGES="touches \$MARK/$1"
ROLLBACK="rm \$MARK/$1"
component_install() { $5; }
component_uninstall() { run rm -f "\$MARK/$1" "\$MARK/$1-root"; }
component_verify() { if [[ -e \$MARK/$1 ]]; then pass "$1 present"; else fail "$1 missing"; fi; checks_done; }
${6:-}
EOT
}

test_yes_installs_only_the_preselected_low_risk() {
    setup_kit
    local out
    out=$("$KIT/install.sh" --yes 2>&1)
    [[ -e $MARK/alpha && -e $MARK/alpha-root ]] || t_fail "alpha not installed: $out"
    [[ ! -e $MARK/beta ]] || t_fail "medium-risk beta was installed without being named"
    [[ ! -e $MARK/absent ]] || t_fail "unsupported component installed"
    [[ -f $REDRIX_STATE_DIR/alpha ]] || t_fail "alpha not recorded"
    t_contains "$out" "alpha present"
}

test_list_shows_risk_and_availability() {
    setup_kit
    local out
    out=$("$KIT/install.sh" --list)
    t_contains "$out" "beta"
    t_contains "$out" "medium risk"
    t_contains "$out" "HIGH RISK"
    t_contains "$out" "not on this machine"
}

test_a_failing_command_stops_the_component_and_the_run() {
    setup_kit
    local out rc=0
    out=$("$KIT/install.sh" --yes broken alpha 2>&1) || rc=$?
    t_eq "$rc" 1 "exit status"
    [[ -e $MARK/broken-start ]] || t_fail "broken did not start"
    [[ ! -e $MARK/broken-after-false ]] || t_fail "install went on after a failed command"
    [[ ! -f $REDRIX_STATE_DIR/broken ]] || t_fail "failed component recorded as installed"
    t_contains "$out" "broken failed"
}

test_high_risk_needs_naming_and_accept_risk() {
    setup_kit
    local out
    out=$("$KIT/install.sh" --yes gamma 2>&1)
    [[ ! -e $MARK/gamma ]] || t_fail "high risk installed without --accept-risk"
    t_contains "$out" "needs --accept-risk"
    out=$("$KIT/install.sh" --yes --accept-risk gamma 2>&1)
    [[ -e $MARK/gamma ]] || t_fail "gamma not installed: $out"
    [[ -e $MARK/alpha ]] || t_fail "its requirement alpha was not added"
    t_contains "$out" "gamma needs alpha: added"
}

test_medium_risk_needs_naming_with_yes() {
    setup_kit
    "$KIT/install.sh" --yes beta >/dev/null 2>&1
    [[ -e $MARK/beta ]] || t_fail "named medium-risk component not installed"
}

test_dry_run_changes_nothing() {
    setup_kit
    local out
    out=$("$KIT/install.sh" --dry-run --yes --accept-risk alpha gamma 2>&1)
    [[ -z $(ls -A "$MARK") ]] || t_fail "dry run touched: $(ls "$MARK")"
    [[ ! -d $REDRIX_STATE_DIR ]] || t_fail "dry run recorded state"
    t_contains "$out" "[dry-run] touch"
    t_contains "$out" "[dry-run, root] touch"
    t_contains "$out" "Dry run finished: nothing was changed"
}

test_uninstall_removes_dependents_first() {
    setup_kit
    "$KIT/install.sh" --yes --accept-risk gamma >/dev/null 2>&1
    local out
    out=$("$KIT/uninstall.sh" --yes alpha 2>&1)
    t_contains "$out" "gamma depends on alpha"
    t_contains "$out" "To remove: gamma alpha"
    [[ ! -e $MARK/alpha && ! -e $MARK/gamma ]] || t_fail "not removed: $(ls "$MARK")"
    [[ -z $(ls -A "$REDRIX_STATE_DIR") ]] || t_fail "state left: $(ls "$REDRIX_STATE_DIR")"
}

test_uninstall_follows_dependency_chains() {
    setup_kit
    "$KIT/install.sh" --yes --accept-risk gamma chain >/dev/null 2>&1
    [[ -e $MARK/chain ]] || t_fail "chain not installed"
    local out
    out=$("$KIT/uninstall.sh" --yes alpha 2>&1)
    t_contains "$out" "To remove: chain gamma alpha"
    [[ -z $(ls -A "$MARK") ]] || t_fail "left: $(ls "$MARK")"
}

test_uninstall_without_arguments_removes_what_is_installed() {
    setup_kit
    "$KIT/install.sh" --yes alpha beta >/dev/null 2>&1
    "$KIT/uninstall.sh" --yes >/dev/null 2>&1
    [[ -z $(ls -A "$MARK") ]] || t_fail "left: $(ls "$MARK")"
}

test_verify_counts_failing_components() {
    setup_kit
    "$KIT/install.sh" --yes alpha >/dev/null 2>&1
    rm "$MARK/alpha"
    local rc=0
    "$KIT/verify.sh" >/dev/null 2>&1 || rc=$?
    t_eq "$rc" 1 "verify exit status"
    local out
    out=$("$KIT/verify.sh" absent 2>&1)
    t_contains "$out" "not applicable here: not on this machine"
}

test_unknown_component_and_option_are_refused() {
    setup_kit
    local out
    out=$("$KIT/install.sh" --yes nosuch 2>&1) && t_fail "accepted an unknown component"
    t_contains "$out" 'unknown component "nosuch"'
    out=$("$KIT/install.sh" --frobnicate 2>&1) && t_fail "accepted an unknown option"
    t_contains "$out" "unknown option"
}

test_other_hardware_is_refused() {
    setup_kit
    printf 'LENOVO\n' >"$KIT/sys/class/dmi/id/sys_vendor"
    local out
    out=$("$KIT/install.sh" --yes alpha 2>&1) && t_fail "installed on another machine"
    [[ ! -e $MARK/alpha ]] || t_fail "alpha installed on another machine"
    t_contains "$out" "only for the HP Elite Dragonfly Chromebook"
}

test_piped_bootstrap_refuses_without_a_pinned_release() {
    local out
    # The pin is emptied here, as scripts/release.sh does when it builds the tarball: the test does not depend on
    # whether the checkout is a release commit. --force gets past the board check on any host, so the pin check is
    # what stops it, before any download.
    out=$(sed "s/^RELEASE_SHA256=.*/RELEASE_SHA256=''/" "$ROOT/install.sh" | bash -s -- --force 2>&1) &&
        t_fail "bootstrap succeeded"
    t_contains "$out" "no release of redrix-linux is pinned"
    [[ $out != *Downloading* ]] || t_fail "downloaded without a pin: $out"
}

"${@:-run_tests}"
