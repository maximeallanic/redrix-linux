# shellcheck shell=bash
# System packages. Debian and Ubuntu: installed with apt after asking. Other distributions: the kit lists what is
# needed under its Debian name and stops, because the package names and some paths differ (see docs/installation.md).

# missing_debian_packages PKG...: the ones dpkg does not report as installed.
missing_debian_packages() {
    local p
    for p in "$@"; do
        [[ $(dpkg-query -W -f='${Status}' "$p" 2>/dev/null) == "install ok installed" ]] || printf '%s\n' "$p"
    done
    return 0
}

# ensure_packages COMPONENT-IDS...: installs what the chosen components need.
ensure_packages() {
    local id wanted=() missing=()
    for id in "$@"; do
        # shellcheck disable=SC2207  # package names have no spaces
        wanted+=($(component_field "$id" DEBIAN_PACKAGES))
    done
    ((${#wanted[@]})) || return 0
    # shellcheck disable=SC2207
    wanted=($(printf '%s\n' "${wanted[@]}" | sort -u))
    case "$(distro_family)" in
        debian)
            # shellcheck disable=SC2207
            missing=($(missing_debian_packages "${wanted[@]}"))
            ((${#missing[@]})) || { note "all needed packages are installed"; return 0; }
            say "These packages are needed: ${missing[*]}"
            ask_yes_no "Install them with apt now?" y || die "packages missing: ${missing[*]}"
            as_root apt-get update -qq
            # --no-install-recommends: libpam-fprintd, for one, would otherwise arrive with fprintd and change PAM.
            as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}"
            ;;
        *)
            warn "automatic package installation is only implemented for Debian and Ubuntu."
            say "Install the equivalents of these Debian packages, then run the installer again:"
            say "    ${wanted[*]}"
            say "See docs/installation.md (Other distributions) for the known differences."
            ask_yes_no "Are they installed already?" n || die "stopped before changing anything"
            ;;
    esac
}
