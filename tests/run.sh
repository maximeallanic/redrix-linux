#!/usr/bin/env bash
# Runs every test of the kit: shell tests of the installer and components, Python and GJS unit tests.
# Nothing touches the system: the installer is exercised on a copy whose components are fakes.
#   tests/run.sh            all
#   tests/run.sh shell      only the shell tests (also: python, gjs)
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WHAT=${1:-all}
# Scratch space on disk, not in /tmp (it can be RAM-backed); removed at exit.
TEST_TMPDIR=$(mktemp -d "${XDG_CACHE_HOME:-$HOME/.cache}/redrix-linux-tests.XXXXXX")
export TEST_TMPDIR TMPDIR=$TEST_TMPDIR
# No __pycache__ left in the source tree.
export PYTHONDONTWRITEBYTECODE=1
trap 'rm -rf -- "$TEST_TMPDIR"' EXIT
failed=()

section() { printf '\n== %s\n' "$1"; }
record() { if (($1 != 0)); then failed+=("$2"); fi; }

if [[ $WHAT == all || $WHAT == shell ]]; then
    for t in "$ROOT"/tests/shell/test_*.sh; do
        section "${t#"$ROOT"/}"
        bash "$t"
        record $? "${t#"$ROOT"/}"
    done
fi

if [[ $WHAT == all || $WHAT == python ]]; then
    for d in "$ROOT"/components/*/tests; do
        compgen -G "$d/test_*.py" >/dev/null || continue
        section "python: ${d#"$ROOT"/}"
        (cd "${d%/tests}" && python3 -m unittest discover -s tests -p 'test_*.py')
        record $? "python ${d#"$ROOT"/}"
    done
fi

if [[ $WHAT == all || $WHAT == gjs ]]; then
    if command -v gjs >/dev/null; then
        for t in "$ROOT"/components/*/*@*/tests/test_*.js; do
            section "gjs: ${t#"$ROOT"/}"
            (cd "$(dirname "$t")/.." && gjs -m "tests/${t##*/}")
            record $? "gjs ${t#"$ROOT"/}"
        done
    else
        section "gjs"
        echo "gjs not installed: GNOME Shell extension tests skipped (sudo apt install gjs)"
        [[ ${CI:-} == true ]] && failed+=("gjs missing in CI")
    fi
fi

printf '\n'
if ((${#failed[@]})); then
    printf 'FAILED: %s\n' "${failed[@]}"
    exit 1
fi
echo "All tests passed."
