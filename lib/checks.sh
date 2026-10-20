# shellcheck shell=bash
# Verify output: one line per check, a hint on failures, a count the caller turns into the exit status.
# Checks only read; anything that needs root to read says so instead of failing silently.

CHECK_FAILED=0
CHECK_PASSED=0

pass() { CHECK_PASSED=$((CHECK_PASSED + 1)); printf '  %s[ OK ]%s %s\n' "$C_GREEN" "$C_OFF" "$1"; }
# fail MESSAGE [HINT]
fail() {
    CHECK_FAILED=$((CHECK_FAILED + 1))
    printf '  %s[FAIL]%s %s\n' "$C_RED" "$C_OFF" "$1"
    [[ -n ${2:-} ]] && printf '         %s-> %s%s\n' "$C_DIM" "$2" "$C_OFF"
    return 0
}
info() { printf '  %s[INFO]%s %s\n' "$C_BLUE" "$C_OFF" "$1"; }
skip() { printf '  %s[SKIP]%s %s\n' "$C_YELLOW" "$C_OFF" "$1"; }

# same_file SRC DEST LABEL HINT: DEST is byte-identical to the kit's SRC.
same_file() {
    if cmp -s "$1" "$2"; then pass "$3"; else fail "$3: $2 missing or different from the kit" "$4"; fi
}

# Extension state over D-Bus (numeric: the text of `gnome-extensions info` is translated).
extension_state() {
    local n
    n=$(gdbus call --session -d org.gnome.Shell.Extensions -o /org/gnome/Shell/Extensions \
        -m org.gnome.Shell.Extensions.GetExtensionInfo "$1" 2>/dev/null |
        sed -n "s/.*'state': <\([0-9]*\)\(\.0\)\{0,1\}>.*/\1/p")
    case "$n" in
        '') echo unknown ;; 1) echo ACTIVE ;; 2) echo INACTIVE ;; 3) echo ERROR ;; 4) echo OUT_OF_DATE ;;
        6) echo INITIALIZED ;; 7) echo DEACTIVATING ;; 8) echo ACTIVATING ;; 99) echo UNINSTALLED ;; *) echo "state $n" ;;
    esac
}

# check_extension UUID SRC_DIR: files installed as shipped, extension enabled and running.
check_extension() {
    local uuid=$1 src=$2 dest="$HOME/.local/share/gnome-shell/extensions/$1" f stale='' state
    for f in "$src"/*.js "$src"/metadata.json; do
        cmp -s "$f" "$dest/${f##*/}" || stale+=" ${f##*/}"
    done
    if [[ -z $stale ]]; then pass "extension files up to date: $uuid"
    else fail "extension $uuid: missing or different:$stale" "reinstall the component"; fi
    state=$(extension_state "$uuid")
    if [[ $state == ACTIVE ]]; then pass "extension running: $uuid"
    else fail "extension $uuid is $state" "log out and back in once after installing; then: gnome-extensions enable $uuid"; fi
}

checks_summary() {
    local label=$1
    if [[ $CHECK_FAILED == 0 ]]; then
        printf '  %s%s: all %d checks passed%s\n' "$C_GREEN" "$label" "$CHECK_PASSED" "$C_OFF"
    else
        printf '  %s%s: %d of %d checks failed%s\n' "$C_RED" "$label" "$CHECK_FAILED" "$((CHECK_FAILED + CHECK_PASSED))" "$C_OFF"
    fi
}

# checks_done: closing line of a component_verify; returns 1 when a check failed.
checks_done() { checks_summary "$TITLE"; ((CHECK_FAILED == 0)); }
