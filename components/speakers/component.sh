# shellcheck shell=bash disable=SC2034  # the metadata variables are read by lib/components.sh
# Speakers: DSM parameter files of the four MAX98390 smart amplifiers, extracted from Google's recovery image.
TITLE="Speaker protection files"
SUMMARY="Downloads Google's recovery image (~1.5 GB) once to extract the speaker amplifiers' tuning files: fuller, protected sound."
RISK=medium
DEFAULT=0
ROOT=1
DEBIAN_PACKAGES="curl unzip fdisk e2fsprogs python3"
REQUIRES=""
CHANGES="Downloads the latest stable ChromeOS recovery image for Redrix from dl.google.com (~1.5 GB; 7 GB free in /var/tmp needed, deleted afterwards)
Installs dsm_param_{L,R,tt_L,tt_R}_Google_Redrix.bin into /lib/firmware, only if they match the hashes pinned in the kit
Takes effect at the next boot"
ROLLBACK="sudo rm /lib/firmware/dsm_param_L_Google_Redrix.bin /lib/firmware/dsm_param_R_Google_Redrix.bin \\
  /lib/firmware/dsm_param_tt_L_Google_Redrix.bin /lib/firmware/dsm_param_tt_R_Google_Redrix.bin, then reboot"

MANIFEST=$COMPONENT_DIR/dsm-param-redrix.sha256
FILES=(dsm_param_L_Google_Redrix.bin dsm_param_R_Google_Redrix.bin
       dsm_param_tt_L_Google_Redrix.bin dsm_param_tt_R_Google_Redrix.bin)

component_supported() {
    compgen -G '/sys/bus/i2c/devices/i2c-MX98390:*' >/dev/null && return 0
    echo "no MAX98390 amplifier found"
    return 1
}

component_install() {
    as_root bash "$COMPONENT_DIR/fetch-dsm-params.sh" "$MANIFEST"
}

component_uninstall() {
    local f
    for f in "${FILES[@]}"; do remove_root_file "/lib/firmware/$f"; done
    note "the amplifiers run without DSM parameters from the next boot"
}

component_verify() {
    local f expected bound journal log probes calib
    for f in "${FILES[@]}"; do
        expected=$(awk -v f="$f" '$2 == f {print $1}' "$MANIFEST")
        if [[ ! -s /lib/firmware/$f ]]; then fail "/lib/firmware/$f missing" "./install.sh speakers"
        elif [[ $(sha256sum <"/lib/firmware/$f" | cut -d' ' -f1) == "$expected" ]]; then pass "$f installed, matches its pinned hash"
        else fail "/lib/firmware/$f differs from its pinned hash" "./install.sh speakers"; fi
    done
    bound=$(compgen -G '/sys/bus/i2c/drivers/max98390/i2c-MX98390:*' | wc -l)
    if [[ $bound == 4 ]]; then pass "the 4 MAX98390 amplifiers are bound to their driver"
    else fail "$bound of 4 MAX98390 amplifiers bound to their driver" "sudo journalctl -k -b | grep -i max98390"; fi
    # This boot's kernel log: readable as a member of adm or systemd-journal, else through sudo without a prompt.
    if journal=$(journalctl -k -b --no-pager -q 2>/dev/null) && [[ -n $journal ]] ||
        journal=$(sudo -n journalctl -k -b --no-pager -q 2>/dev/null); then
        log=$(grep 'max98390' <<<"$journal")
        probes=$(grep -c 'MAX98390 revisionID' <<<"$log")
        if [[ $probes != 4 ]]; then
            skip "kernel log holds $probes of 4 amplifier probe lines for this boot (rotated?): DSM load not checked"
        else
            if grep -q 'Direct firmware load for dsm' <<<"$log"; then fail "an amplifier could not load its DSM file this boot" "reboot after installing"
            else pass "all amplifiers loaded their DSM file this boot"; fi
            calib=$(grep -c 'r0_calib: 0x[1-9a-f]' <<<"$log")
            if [[ $calib == 4 ]]; then pass "factory calibration read for the 4 amplifiers"
            else fail "factory calibration found for $calib of 4 amplifiers" "see docs/components/speakers.md"; fi
        fi
    else
        skip "kernel log not readable without root; check by hand: sudo journalctl -k -b | grep max98390"
    fi
    if grep -q 'HiFi__Speaker__sink' <<<"$(wpctl status -n 2>/dev/null)"; then pass "speaker output available"
    else fail "no speaker output in PipeWire" "install the Chromebook audio configuration (docs/components/speakers.md)"; fi
    checks_done
}
