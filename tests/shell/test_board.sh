#!/usr/bin/env bash
# Board and distribution detection, with a fake /sys and /etc/os-release.
set -uo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
# shellcheck source=tests/shell/assert.sh
source "$HERE/assert.sh"
SCRATCH=$(mktemp -d "${TEST_TMPDIR:?}/board.XXXXXX")

fake_sys() {  # vendor product bios mem_sleep -> path
    local d=$SCRATCH/sys-$RANDOM
    mkdir -p "$d/class/dmi/id" "$d/power"
    printf '%s\n' "$1" >"$d/class/dmi/id/sys_vendor"
    printf '%s\n' "$2" >"$d/class/dmi/id/product_name"
    printf '%s\n' "$3" >"$d/class/dmi/id/bios_version"
    printf '%s\n' "$4" >"$d/power/mem_sleep"
    printf '%s' "$d"
}
load() {
    # shellcheck source=lib/common.sh
    source "$ROOT/lib/common.sh"
    # shellcheck source=lib/board.sh
    source "$ROOT/lib/board.sh"
}

test_redrix_on_mrchromebox() {
    REDRIX_SYSFS=$(fake_sys Google Redrix MrChromebox-2609.1 's2idle [deep]')
    load
    is_redrix
    t_eq "$(firmware_kind)" mrchromebox
    offers_deep_sleep
    t_eq "$(board_description)" "Google Redrix"
}

test_redrix_variant_on_stock_firmware() {
    REDRIX_SYSFS=$(fake_sys Google Redrix4ES Google_Redrix.14505.0.0 '[s2idle]')
    load
    is_redrix
    t_eq "$(firmware_kind)" chromeos
    t_false offers_deep_sleep
}

test_other_machine_is_refused_unless_forced() {
    REDRIX_SYSFS=$(fake_sys LENOVO 21AB 'N3AET70W' '[s2idle] deep')
    load
    t_false is_redrix
    local out
    out=$( (require_board 0) 2>&1) && t_fail "require_board accepted another machine"
    t_contains "$out" "only for the HP Elite Dragonfly Chromebook"
    t_contains "$out" "Nothing was changed"
    ( require_board 1 ) 2>/dev/null
}

test_missing_dmi_is_not_redrix() {
    REDRIX_SYSFS=$SCRATCH/empty
    load
    t_false is_redrix
    t_eq "$(firmware_kind)" unknown
}

test_distro_family() {
    load
    local f=$SCRATCH/os-release
    REDRIX_OS_RELEASE=$f
    printf 'ID=debian\nPRETTY_NAME="Debian GNU/Linux forky/sid"\n' >"$f"; t_eq "$(distro_family)" debian
    t_eq "$(os_release_field PRETTY_NAME)" "Debian GNU/Linux forky/sid"
    printf 'ID=ubuntu\nID_LIKE=debian\n' >"$f"; t_eq "$(distro_family)" debian
    printf 'ID=linuxmint\nID_LIKE="ubuntu debian"\n' >"$f"; t_eq "$(distro_family)" debian
    printf 'ID=fedora\n' >"$f"; t_eq "$(distro_family)" fedora
    printf 'ID=arch\n' >"$f"; t_eq "$(distro_family)" arch
    printf 'ID="opensuse-tumbleweed"\nID_LIKE="opensuse suse"\n' >"$f"; t_eq "$(distro_family)" other
}

run_tests
