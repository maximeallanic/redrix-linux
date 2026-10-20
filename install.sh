#!/usr/bin/env bash
# redrix-linux: hardware enablement for the HP Elite Dragonfly Chromebook (board "redrix") on Debian/Ubuntu + GNOME.
#
#   curl -fsSL https://raw.githubusercontent.com/maximeallanic/redrix-linux/main/install.sh | bash
#   ./install.sh [options] [component...]
#
# With no component named, a checklist opens (low-risk components preselected). Run as your normal user inside your
# GNOME session; the installer asks for sudo itself, once, when a component needs it.
#
# Options:
#   --list            list the components with their risk level and status, then exit
#   --dry-run         show every command that would run, change nothing
#   -y, --yes         no questions: install the named components, or the preselected ones when none is named
#   --accept-risk     with --yes, allow high-risk components (PAM, boot) that are named explicitly
#   --no-verify       skip the checks that run after installing
#   --force           run on hardware that is not a Redrix (most components will not make sense there)
#   --remove ID...    uninstall components (same as ./uninstall.sh ID...)
#   --version, -h, --help
#
# Docs: README.md and docs/. Uninstall: ./uninstall.sh [component...]. Checks: ./verify.sh [component...].
set -euo pipefail

# Pinned release fetched by the one-line install. scripts/release.sh fills both values after a release is published.
RELEASE_VERSION=0.1.0
RELEASE_SHA256='f24e9e50234bfff5e952bdaddc5849f2c0f10d10777ab8d9c96026be21fdb1ad'
RELEASE_URL="https://github.com/maximeallanic/redrix-linux/releases/download/v${RELEASE_VERSION}/redrix-linux-${RELEASE_VERSION}.tar.gz"

# Runs when the script arrives through a pipe: download the pinned release, check it, hand over to its installer.
bootstrap() {
    local arg force=0 data dest
    for arg in "$@"; do [[ $arg == --force ]] && force=1; done
    if [[ $(cat /sys/class/dmi/id/sys_vendor 2>/dev/null) != Google || $(cat /sys/class/dmi/id/product_name 2>/dev/null) != Redrix* ]] && [[ $force != 1 ]]; then
        echo "error: this kit is only for the HP Elite Dragonfly Chromebook (board \"redrix\"). Nothing was downloaded." >&2
        return 1
    fi
    if [[ -z $RELEASE_SHA256 ]]; then
        echo "error: no release of redrix-linux is pinned in this installer yet." >&2
        echo "       Use a checkout instead: git clone https://github.com/maximeallanic/redrix-linux && redrix-linux/install.sh" >&2
        return 1
    fi
    for arg in curl tar sha256sum; do
        command -v "$arg" >/dev/null || { echo "error: $arg is required (sudo apt install $arg)" >&2; return 1; }
    done
    data=${XDG_DATA_HOME:-$HOME/.local/share}/redrix-linux
    dest=$data/releases/$RELEASE_VERSION
    mkdir -p "$data/releases"
    # Global, not local: the EXIT trap runs after this function has returned.
    BOOTSTRAP_TMP=$(mktemp -d "$data/releases/.download.XXXXXX")
    trap 'rm -rf -- "$BOOTSTRAP_TMP"' EXIT
    local tmp=$BOOTSTRAP_TMP
    echo "Downloading redrix-linux $RELEASE_VERSION ..."
    curl -fsSL --proto '=https' --tlsv1.2 -o "$tmp/kit.tar.gz" "$RELEASE_URL"
    echo "$RELEASE_SHA256  $tmp/kit.tar.gz" | sha256sum -c --quiet - ||
        { echo "error: the download does not match the pinned checksum; nothing was installed." >&2; return 1; }
    mkdir "$tmp/kit"
    tar -xzf "$tmp/kit.tar.gz" -C "$tmp/kit" --strip-components=1 --no-same-owner
    rm -rf -- "$dest"
    mv "$tmp/kit" "$dest"
    echo "Kit unpacked in $dest (kept: its uninstall.sh and verify.sh are there)."
    bash "$dest/install.sh" "$@"
}

main() {
    REDRIX_ROOT=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
    local f
    for f in common board components checks gnome menu deps; do
        # shellcheck source=/dev/null
        source "$REDRIX_ROOT/lib/$f.sh"
    done
    # shellcheck source=lib/install_flow.sh
    source "$REDRIX_ROOT/lib/install_flow.sh"
    install_main "$@"
}

# The whole file is read before anything runs: a truncated download cannot execute half a script.
if [[ -n ${BASH_SOURCE[0]:-} && -f "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh" ]]; then
    main "$@"
else
    bootstrap "$@"
fi
