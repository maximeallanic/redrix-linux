#!/usr/bin/env bash
# Builds libfprint with the crfpmoc driver (the fingerprint MCU of Chromebooks, /dev/cros_fp) and installs it into
# /usr/local, next to Debian's own libfprint which stays untouched. Run as root by the fingerprint component.
#
# Sources are third-party and pinned by full commit hash:
#   libfprint, branch feature/crfpmoc of Marco Trevisan's fork (LGPL-2.1+)
#   the crfpmoc driver files of the HP Pro c640 Chromebook project, a newer revision of the same driver
# The list of installed files is kept (INSTALL_LOG) so the component's uninstall removes exactly those.
#
#   build-libfprint.sh install | uninstall
set -euo pipefail
export LC_ALL=C

LIBFPRINT_URL=https://gitlab.freedesktop.org/3v1n0/libfprint.git
LIBFPRINT_REF=56442591a5c302a906289f30988fb50fc3d82ed6
C640_URL=https://github.com/samson1357924/hp-pro-c640-chromebook-linux.git
C640_REF=b58b5ac1c6c0526fe49c362da78512009324c1cd
SRC=/usr/local/src/redrix-linux-fingerprint
INSTALL_LOG=$SRC/installed-files.txt
# This board is x86-64 only (Alder Lake).
LIBDIR=lib/x86_64-linux-gnu

[[ $EUID == 0 ]] || { echo "run as root" >&2; exit 1; }

# fetch URL REF DIR: a clean checkout of exactly REF.
fetch() {
    if [[ ! -d $3/.git ]]; then git clone --quiet "$1" "$3"; fi
    git -C "$3" fetch --quiet origin
    # The driver graft below edits the tree in place: start from a clean checkout every time.
    git -C "$3" reset --quiet --hard
    git -C "$3" clean -fdq
    git -C "$3" checkout --quiet --detach "$2"
    [[ $(git -C "$3" rev-parse HEAD) == "$2" ]] || { echo "unexpected commit in $3 (expected $2)" >&2; exit 1; }
}

install_libfprint() {
    mkdir -p "$SRC"
    echo "== Fetching the pinned sources"
    fetch "$LIBFPRINT_URL" "$LIBFPRINT_REF" "$SRC/libfprint"
    fetch "$C640_URL" "$C640_REF" "$SRC/c640"

    echo "== Grafting the newer crfpmoc driver files"
    cp -f "$SRC"/c640/fingerprint/driver/crfpmoc* "$SRC/libfprint/libfprint/drivers/crfpmoc/"
    if ! grep -q crfpmoc-proto.c "$SRC/libfprint/libfprint/meson.build"; then
        sed -i "s|'drivers/crfpmoc/crfpmoc-ec-transfer.c',|'drivers/crfpmoc/crfpmoc-ec-transfer.c',\n        'drivers/crfpmoc/crfpmoc-proto.c',|" \
            "$SRC/libfprint/libfprint/meson.build"
    fi
    grep -q crfpmoc-proto.c "$SRC/libfprint/libfprint/meson.build" || { echo "could not add crfpmoc-proto.c to meson.build" >&2; exit 1; }
    # Bug of the branch with meson >= 1.12: tests/meson.build iterates a dict with a single loop variable.
    sed -i 's|^\(\s*\)foreach driver_test: drivers_tests|\1foreach driver_test, _args : drivers_tests|' "$SRC/libfprint/tests/meson.build"

    echo "== Building"
    # -Ddrivers=crfpmoc,elanspi: with crfpmoc alone the branch never defines HAVE_UDEV.
    # Explicit udev_rules_dir and no hwdb: recent systemd no longer ships udev.pc, which meson would look for.
    rm -rf -- "$SRC/build"
    meson setup "$SRC/build" "$SRC/libfprint" --prefix=/usr/local --libdir="$LIBDIR" \
        -Ddrivers=crfpmoc,elanspi -Dintrospection=false -Ddoc=false -Dgtk-examples=false -Dinstalled-tests=false \
        -Dudev_rules_dir=/usr/local/lib/udev/rules.d -Dudev_hwdb=disabled
    ninja -C "$SRC/build"
    ninja -C "$SRC/build" install
    cp "$SRC/build/meson-logs/install-log.txt" "$INSTALL_LOG"
    ldconfig
}

uninstall_libfprint() {
    local f
    if [[ ! -f $INSTALL_LOG ]]; then echo "no install log at $INSTALL_LOG: nothing to remove"; return 0; fi
    # Exact paths written by meson, under /usr/local only.
    while IFS= read -r f; do
        [[ $f == /usr/local/* ]] || continue
        if [[ -e $f || -L $f ]]; then rm -f -- "$f"; fi
    done < <(grep -v '^#' "$INSTALL_LOG")
    ldconfig
    rm -rf -- "$SRC"
    echo "removed the /usr/local libfprint and its sources ($SRC)"
}

case "${1:-}" in
    install) install_libfprint ;;
    uninstall) uninstall_libfprint ;;
    *) echo "usage: $0 install|uninstall" >&2; exit 2 ;;
esac
