# shellcheck shell=bash disable=SC2034  # the metadata variables are read by lib/components.sh
# Fingerprint reader: libfprint with the crfpmoc driver for the fingerprint MCU, used by fprintd. Login is a separate
# component (fingerprint-login): this one never touches PAM.
TITLE="Fingerprint reader"
SUMMARY="Builds the driver for the fingerprint sensor so you can enroll fingers (fprintd-enroll). Does not change how you log in."
RISK=medium
DEFAULT=0
ROOT=1
DEBIAN_PACKAGES="fprintd git meson ninja-build pkg-config gcc libglib2.0-dev libgusb-dev libgudev-1.0-dev libnss3-dev libpixman-1-dev libudev-dev libcairo2-dev libssl-dev"
REQUIRES=""
CHANGES="Downloads two pinned third-party source trees (libfprint crfpmoc branch, c640 driver files) to /usr/local/src
Builds and installs libfprint into /usr/local (Debian's libfprint is not replaced)
/etc/systemd/system/fprintd.service.d/redrix-crfpmoc.conf: fprintd loads that libfprint
PAM is not changed: logging in with a finger is the fingerprint-login component"
ROLLBACK="sudo rm /etc/systemd/system/fprintd.service.d/redrix-crfpmoc.conf && sudo systemctl daemon-reload
sudo xargs -a /usr/local/src/redrix-linux-fingerprint/installed-files.txt rm -f && sudo ldconfig"

DROPIN=/etc/systemd/system/fprintd.service.d/redrix-crfpmoc.conf
LIB=/usr/local/lib/x86_64-linux-gnu/libfprint-2.so.2

component_supported() {
    [[ -e /dev/cros_fp ]] && return 0
    echo "no fingerprint MCU (/dev/cros_fp) found"
    return 1
}

component_install() {
    as_root bash "$COMPONENT_DIR/build-libfprint.sh" install
    install_if_changed "$COMPONENT_DIR/fprintd-crfpmoc.conf" "$DROPIN" 644
    as_root systemctl daemon-reload
    as_root systemctl try-restart fprintd.service
    note "next: enroll a finger with  fprintd-enroll  (then fprintd-verify to test it)"
    note "logging in with it is a separate step: ./install.sh fingerprint-login"
}

component_uninstall() {
    remove_root_file "$DROPIN"
    as_root systemctl daemon-reload
    as_root bash "$COMPONENT_DIR/build-libfprint.sh" uninstall
    as_root systemctl try-restart fprintd.service
    note "enrolled fingers stay in /var/lib/fprint (delete them first with fprintd-delete \"\$USER\" if you want)"
}

component_verify() {
    local listing pid maps
    if [[ -e /dev/cros_fp ]]; then pass "fingerprint MCU present (/dev/cros_fp)"; else fail "/dev/cros_fp missing" "see docs/components/fingerprint.md"; fi
    if [[ -e $LIB ]]; then pass "libfprint with crfpmoc installed in /usr/local"; else fail "$LIB missing" "./install.sh fingerprint"; fi
    same_file "$COMPONENT_DIR/fprintd-crfpmoc.conf" "$DROPIN" "fprintd uses that libfprint" "./install.sh fingerprint"
    # fprintd-list activates fprintd over D-Bus.
    listing=$(fprintd-list "$USER" 2>&1)
    if grep -q 'found 1 device' <<<"$listing"; then pass "fprintd sees the sensor"
    else fail "fprintd sees no sensor: $(head -n1 <<<"$listing")" "sudo systemctl restart fprintd; journalctl -u fprintd -b"; fi
    if grep -q ' - #' <<<"$listing"; then pass "$(grep -c ' - #' <<<"$listing") finger(s) enrolled for $USER"
    else info "no finger enrolled yet: fprintd-enroll"; fi
    # The library fprintd loaded: its memory map is readable by root only.
    if pid=$(pidof fprintd) && maps=$(cat "/proc/$pid/maps" 2>/dev/null) && [[ -n $maps ]]; then
        if grep -qF "$LIB" <<<"$maps"; then pass "fprintd runs with the crfpmoc libfprint"
        else fail "fprintd runs with Debian's libfprint" "sudo systemctl restart fprintd"; fi
    else
        info "library loaded by fprintd not checked (needs root): sudo grep libfprint /proc/\$(pidof fprintd)/maps"
    fi
    checks_done
}
