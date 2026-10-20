#!/usr/bin/env bash
# Extracts the DSM parameter files of the four MAX98390 smart amplifiers (woofers L/R, tweeters tt_L/tt_R) from
# Google's official Redrix recovery image and installs them into /lib/firmware. Run as root by the speakers component.
#
# The files are Google's and are not redistributed by this kit: they are read from ROOT-A of the recovery image
# (loop device, read-only, through debugfs; nothing is mounted). They are pinned by SHA-256 in the manifest given as
# argument; files that do not match are never installed, so a newer image that changes them needs a deliberate
# review and a manifest update. Nothing is downloaded when the installed files already match.
#
#   fetch-dsm-params.sh MANIFEST [WORKDIR_PARENT]
# WORKDIR_PARENT (default /var/tmp) needs about 7 GB free: the image is ~1.5 GB zipped and ~5 GB unpacked.
set -euo pipefail
export LC_ALL=C

MANIFEST=$1
PARENT=${2:-/var/tmp}
DEST=/lib/firmware
RECOVERY_INDEX=https://dl.google.com/dl/edgedl/chromeos/recovery/recovery2.json
FILES=(dsm_param_L_Google_Redrix.bin dsm_param_R_Google_Redrix.bin
       dsm_param_tt_L_Google_Redrix.bin dsm_param_tt_R_Google_Redrix.bin)
NEEDED_KB=$((7 * 1024 * 1024))

[[ $EUID == 0 ]] || { echo "run as root" >&2; exit 1; }
[[ -r $MANIFEST ]] || { echo "missing hash manifest $MANIFEST" >&2; exit 1; }
# The manifest must pin exactly the four files, so a partial manifest cannot pass for a full check.
for f in "${FILES[@]}"; do
    grep -Eq "^[0-9a-f]{64}  $f\$" "$MANIFEST" || { echo "$MANIFEST does not pin $f" >&2; exit 1; }
done
[[ $(grep -c . "$MANIFEST") == "${#FILES[@]}" ]] || { echo "$MANIFEST pins unexpected entries" >&2; exit 1; }

# matches DIR: the four files in DIR against the pinned hashes; prints the mismatches.
matches() { (cd "$1" && sha256sum -c --quiet --strict "$MANIFEST" 2>&1); }

if matches "$DEST" >/dev/null; then
    echo "DSM files already installed and matching the pinned hashes: nothing to download."
    exit 0
fi

free_kb=$(df -Pk "$PARENT" | awk 'NR == 2 {print $4}')
((free_kb >= NEEDED_KB)) || { echo "not enough space in $PARENT: $((free_kb / 1024 / 1024)) GB free, 7 GB needed" >&2; exit 1; }

WORK=$(mktemp -d "$PARENT/redrix-recovery.XXXXXX")
LOOP=''
cleanup() {
    if [[ -n $LOOP ]]; then losetup -d "$LOOP"; fi
    rm -rf -- "$WORK"
}
trap cleanup EXIT

echo "== Finding the latest stable Redrix recovery image"
ENTRY=$(curl -fsSL --proto '=https' "$RECOVERY_INDEX" | python3 -I -c '
import json, sys
for e in json.load(sys.stdin):
    if e.get("hwidmatch", "").startswith("^REDRIX") and "stable-channel" in e.get("url", ""):
        print(e["url"], e["sha1"])
        break
')
[[ -n $ENTRY ]] || { echo "no stable Redrix entry in $RECOVERY_INDEX" >&2; exit 1; }
read -r URL SHA1 <<<"$ENTRY"
echo "$URL"
echo "== Downloading (about 1.5 GB)"
curl -fL --proto '=https' --progress-bar -o "$WORK/image.zip" "$URL"
echo "$SHA1  $WORK/image.zip" | sha1sum -c --quiet

echo "== Extracting the DSM files from ROOT-A"
unzip -q -d "$WORK" "$WORK/image.zip"
rm -- "$WORK/image.zip"
images=("$WORK"/*.bin)
[[ ${#images[@]} == 1 && -f ${images[0]} ]] || { echo "unexpected recovery archive content" >&2; exit 1; }
read -r START END < <(sfdisk -d "${images[0]}" | awk -F'[=,]' '/name="ROOT-A"/ {print $2 + 0, $2 + $4 - 1}')
[[ -n ${START:-} ]] || { echo "no ROOT-A partition in the image" >&2; exit 1; }
LOOP=$(losetup -r -f --show -o $((START * 512)) --sizelimit $(((END - START + 1) * 512)) "${images[0]}")
mkdir "$WORK/dsm"
for f in "${FILES[@]}"; do
    debugfs -R "dump /lib/firmware/$f $WORK/dsm/$f" "$LOOP" 2>/dev/null
    [[ -s $WORK/dsm/$f ]] || { echo "$f missing from the image" >&2; exit 1; }
done
if ! diff=$(matches "$WORK/dsm"); then
    echo "The DSM files in $URL differ from the pinned ones:" >&2
    echo "$diff" >&2
    echo "Nothing installed. Please open an issue: the manifest needs a reviewed update." >&2
    exit 1
fi

echo "== Installing into $DEST"
for f in "${FILES[@]}"; do install -m 644 "$WORK/dsm/$f" "$DEST/$f"; done
echo "Done: reboot so the amplifiers load their DSM parameters."
