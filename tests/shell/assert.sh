# shellcheck shell=bash
# Minimal assertions for the shell tests. Each test is a function named test_*; run_tests runs each in a subshell
# with errexit, so the first failing command or assertion ends that test.
T_FAILED=0
T_RUN=0

t_fail() { printf '    not ok: %s\n' "$*"; return 1; }
t_eq() { [[ $1 == "$2" ]] || t_fail "${3:-values differ}: expected [$2], got [$1]"; }
t_contains() { [[ $1 == *"$2"* ]] || t_fail "${3:-missing text}: [$2] not in [$1]"; }
# t_false CMD...: CMD must fail. (`! cmd` never stops a test: errexit ignores negated commands.)
t_false() { if "$@"; then t_fail "expected to fail: $*"; fi; }
t_not_contains() { [[ $1 != *"$2"* ]] || t_fail "${3:-unexpected text}: [$2] in [$1]"; }

run_tests() {
    local t rc
    for t in $(declare -F | awk '{print $3}' | grep '^test_'); do
        T_RUN=$((T_RUN + 1))
        # Neither in an if nor before || or &&: bash then ignores errexit in the whole subshell, and a failed check
        # would pass. The test scripts themselves run without errexit, so a failing subshell does not stop them.
        ( set -e; "$t" )
        rc=$?
        if ((rc == 0)); then
            printf 'ok %s\n' "$t"
        else
            printf 'FAIL %s\n' "$t"
            T_FAILED=$((T_FAILED + 1))
        fi
    done
    printf '%d tests, %d failed\n' "$T_RUN" "$T_FAILED"
    ((T_FAILED == 0))
}
