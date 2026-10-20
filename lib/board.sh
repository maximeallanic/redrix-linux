# shellcheck shell=bash
# Which machine and firmware this is. Read-only. REDRIX_SYSFS overrides /sys for the tests.

: "${REDRIX_SYSFS:=/sys}"

dmi() { local v; v=$(cat "$REDRIX_SYSFS/class/dmi/id/$1" 2>/dev/null) || v=''; printf '%s' "${v//$'\n'/}"; }

# 0 when this is an HP Elite Dragonfly Chromebook. coreboot reports the Google board name in SMBIOS on both the
# stock ChromeOS firmware and MrChromebox's; variants carry a suffix (the same hwdb match "pnRedrix*" is used).
is_redrix() {
    [[ $(dmi sys_vendor) == Google && $(dmi product_name) == Redrix* ]]
}

board_description() {
    local vendor product
    vendor=$(dmi sys_vendor) product=$(dmi product_name)
    printf '%s %s' "${vendor:-unknown vendor}" "${product:-unknown product}"
}

# mrchromebox | chromeos | unknown. MrChromebox's UEFI Full ROM puts its release in the BIOS version
# ("MrChromebox-2609.1"); the stock firmware reports a "Google_Redrix.*" version.
firmware_kind() {
    local version
    version=$(dmi bios_version)
    case "$version" in
        MrChromebox-*) echo mrchromebox ;;
        Google_*) echo chromeos ;;
        *) echo unknown ;;
    esac
}

firmware_version() { dmi bios_version; }

# 0 when the kernel offers S3 ("deep"), which MrChromebox's UEFI firmware does on this board.
offers_deep_sleep() { grep -qw deep "$REDRIX_SYSFS/power/mem_sleep" 2>/dev/null; }

# require_board FORCE: stops on other hardware unless FORCE is 1.
require_board() {
    if is_redrix; then return 0; fi
    if [[ ${1:-0} == 1 ]]; then
        warn "this is a $(board_description), not an HP Elite Dragonfly Chromebook (Google Redrix): continuing because of --force"
        return 0
    fi
    die "this kit is only for the HP Elite Dragonfly Chromebook (board \"redrix\"); this machine reports \"$(board_description)\".
       Nothing was changed. --force skips this check, at your own risk: most components address this board's exact hardware."
}

# os_release_field KEY: one value of /etc/os-release, read without sourcing the file.
os_release_field() {
    sed -n "s/^$1=//p" "${REDRIX_OS_RELEASE:-/etc/os-release}" 2>/dev/null | head -1 | tr -d "\"'"
}

# distro_family: debian | fedora | arch | other (from /etc/os-release ID and ID_LIKE).
distro_family() {
    case " $(os_release_field ID) $(os_release_field ID_LIKE) " in
        *" debian "*|*" ubuntu "*) echo debian ;;
        *" fedora "*|*" rhel "*) echo fedora ;;
        *" arch "*) echo arch ;;
        *) echo other ;;
    esac
}
