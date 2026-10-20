#!/usr/bin/env bash
# Rebuilds MrChromebox's UEFI Full ROM for Redrix with two optional changes: your own boot logo (also the ACPI BGRT
# image that Plymouth redraws) and no "Press ESC for Boot Options/Settings" text (edk2-hide-boot-prompt.patch; Esc
# still works). Everything else comes from the release's own .config, read back from an image of YOUR machine.
# Builds in the pinned coreboot SDK container (Docker, rootless works). It never flashes anything: flashing is a
# manual step described in docs/firmware.md, with the backup it requires.
#
#   REF_ROM=/path/to/bios-backup.rom [LOGO=/path/to/logo.bmp] [HIDE_PROMPT=1] tools/firmware/build-firmware.sh
#
# REF_ROM  required: a BIOS-region image of this machine running MrChromebox $RELEASE (flashrom -r --ifd -i bios).
#          Its CBFS holds the release .config and this machine's HWID, which is written back into the new image.
# LOGO     optional: a 24-bit BMP. Without it, MrChromebox's default logo is kept.
# Output: $TREE/build/coreboot.rom
set -euo pipefail
export LC_ALL=C

RELEASE=${RELEASE:-MrChromebox-2609.1}
TREE=${TREE:-${XDG_CACHE_HOME:-$HOME/.cache}/redrix-linux/coreboot-$RELEASE}
SDK=${SDK:-coreboot/coreboot-sdk:2026-07-06_c165edb4ce}
REF_ROM=${REF_ROM:?set REF_ROM to a BIOS-region image of this machine (see the header of this script)}
LOGO=${LOGO:-}
HIDE_PROMPT=${HIDE_PROMPT:-1}
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d /var/tmp/fw-build.XXXXXX)
trap 'rm -rf -- "$WORK"' EXIT
EDK2=$TREE/payloads/external/edk2/workspace/mrchromebox
CBFSTOOL=$TREE/util/cbfstool/cbfstool
command -v docker >/dev/null || { echo "docker is required (sudo apt install docker.io)" >&2; exit 1; }
if [[ -n $LOGO ]]; then
    [[ $(head -c 2 "$LOGO") == BM ]] || { echo "$LOGO is not a BMP file" >&2; exit 1; }
fi

echo "== 1. coreboot tree at $RELEASE"
if [ ! -d "$TREE" ]; then
    git clone --depth 1 -b "$RELEASE" https://github.com/MrChromebox/coreboot "$TREE"
    for s in 3rdparty/vboot 3rdparty/blobs 3rdparty/fsp 3rdparty/intel-microcode; do
        git -C "$TREE" -c "submodule.$s.update=checkout" submodule update --init --depth 1 "$s"
    done
fi
[ "$(git -C "$TREE" describe --tags --exact-match 2>/dev/null)" = "$RELEASE" ] || {
    echo "$TREE is not at $RELEASE" >&2; exit 1; }

echo "== 2. .config and HWID of the reference image ($REF_ROM)"
[ -s "$REF_ROM" ] || { echo "$REF_ROM missing or empty" >&2; exit 1; }
# cbfstool built from the pinned tree in the pinned SDK (only links libc, so it runs on the host); never a download.
docker run --rm -u 0 -e HOME=/tmp -v "$TREE:/cb" -w /cb "$SDK" make -C util/cbfstool cbfstool >/dev/null
"$CBFSTOOL" "$REF_ROM" extract -r COREBOOT -n config -f "$TREE/.config" -m x86 >/dev/null
"$CBFSTOOL" "$REF_ROM" extract -r COREBOOT -n hwid -f "$WORK/hwid" >/dev/null
if [[ -n $LOGO ]]; then
    mkdir -p "$TREE/site-local"
    cp "$LOGO" "$TREE/site-local/boot-logo.bmp"
    # The release .config may be a minimal one that leaves the default logo implicit: replace the line or add it.
    LOGO_LINE='CONFIG_EDK2_BOOTSPLASH_FILE="site-local/boot-logo.bmp"'
    if grep -q '^CONFIG_EDK2_BOOTSPLASH_FILE=' "$TREE/.config"; then
        sed -i "s|^CONFIG_EDK2_BOOTSPLASH_FILE=.*|$LOGO_LINE|" "$TREE/.config"
    else
        echo "$LOGO_LINE" >>"$TREE/.config"
    fi
fi
docker run --rm -u 0 -e HOME=/tmp -v "$TREE:/cb" -w /cb "$SDK" make olddefconfig >/dev/null
if [[ -n $LOGO ]]; then
    grep -qxF "$LOGO_LINE" "$TREE/.config" || { echo "$TREE/.config does not keep $LOGO_LINE after olddefconfig" >&2; exit 1; }
fi

echo "== 3. edk2 patch (the coreboot Makefile keeps a dirty edk2 tree as is)"
if [ ! -d "$EDK2" ]; then
    # Fetch only the payload source at the release's revision (the edk2 Makefile's own clone target), so the
    # patch is in place before the one and only build.
    REPO=$(sed -n 's/^CONFIG_EDK2_REPOSITORY="\(.*\)"$/\1/p' "$TREE/.config")
    REV=$(sed -n 's/^CONFIG_EDK2_TAG_OR_REV="\(.*\)"$/\1/p' "$TREE/.config")
    [ -n "$REPO" ] && [ -n "$REV" ] || { echo "edk2 repository or revision missing from $TREE/.config" >&2; exit 1; }
    docker run --rm -u 0 -e HOME=/tmp -v "$TREE:/cb" -w /cb "$SDK" sh -c \
        'git config --global --add safe.directory "*" && make -C payloads/external/edk2 "$0" \
            CONFIG_EDK2_REPOSITORY="$1" CONFIG_EDK2_TAG_OR_REV="$2"' \
        /cb/payloads/external/edk2/workspace/mrchromebox "$REPO" "$REV"
    [ -d "$EDK2" ] || { echo "edk2 fetch did not create $EDK2 (check CONFIG_EDK2_REPOSITORY)" >&2; exit 1; }
fi
if [[ $HIDE_PROMPT == 1 ]]; then
    if git -C "$EDK2" apply --check "$HERE/edk2-hide-boot-prompt.patch" 2>/dev/null; then
        git -C "$EDK2" apply "$HERE/edk2-hide-boot-prompt.patch"
    else
        git -C "$EDK2" apply --reverse --check "$HERE/edk2-hide-boot-prompt.patch" || {
            echo "edk2 tree neither clean nor patched" >&2; exit 1; }
    fi
elif git -C "$EDK2" apply --reverse --check "$HERE/edk2-hide-boot-prompt.patch" 2>/dev/null; then
    git -C "$EDK2" apply --reverse "$HERE/edk2-hide-boot-prompt.patch"
fi

echo "== 4. Build in $SDK"
docker run --rm -u 0 -e HOME=/tmp -v "$TREE:/cb" -w /cb "$SDK" sh -c \
    'git config --global --add safe.directory "*" && make -j"$(nproc)"'
if [[ $HIDE_PROMPT == 1 ]]; then
    git -C "$EDK2" apply --reverse --check "$HERE/edk2-hide-boot-prompt.patch" || {
        echo "edk2 patch missing from the build" >&2; exit 1; }
fi

echo "== 5. HWID of this machine"
# Replace a hwid entry the build may already carry, so the image holds this machine's.
if "$CBFSTOOL" "$TREE/build/coreboot.rom" print -r COREBOOT | awk '{print $1}' | grep -qx hwid; then
    "$CBFSTOOL" "$TREE/build/coreboot.rom" remove -r COREBOOT -n hwid
fi
"$CBFSTOOL" "$TREE/build/coreboot.rom" add -r COREBOOT -n hwid -f "$WORK/hwid" -t raw
echo "Done: $TREE/build/coreboot.rom (not flashed: see docs/firmware.md)"
