# shellcheck shell=bash disable=SC2034  # the metadata variables are read by lib/components.sh
# Worn battery: UPower warns earlier and powers off cleanly at 6 % instead of letting the machine cut out.
TITLE="Worn battery guard"
SUMMARY="Only if your battery dies suddenly at a few percent: warn at 20 %, clean power-off at 6 %."
RISK=low
DEFAULT=0
ROOT=1
DEBIAN_PACKAGES="upower"
REQUIRES=""
CHANGES="/etc/UPower/UPower.conf.d/50-worn-battery.conf: low 20 %, critical 10 %, power off at 6 %; UPower restarted"
ROLLBACK="sudo rm /etc/UPower/UPower.conf.d/50-worn-battery.conf && sudo systemctl restart upower"

DEST=/etc/UPower/UPower.conf.d/50-worn-battery.conf

component_install() {
    install_if_changed "$COMPONENT_DIR/50-worn-battery.conf" "$DEST" 644
    # UPower reads its configuration at start only.
    if ((INSTALLED_CHANGED)); then as_root systemctl restart upower.service; note "UPower restarted"; fi
}

component_uninstall() {
    if [[ -e $DEST ]]; then
        remove_root_file "$DEST"
        as_root systemctl restart upower.service
    fi
}

component_verify() {
    local started
    same_file "$COMPONENT_DIR/50-worn-battery.conf" "$DEST" "UPower thresholds installed" "./install.sh battery-guard"
    if systemctl is-active --quiet upower.service; then pass "UPower is running"
    else fail "UPower is not running" "sudo systemctl start upower"; fi
    started=$(systemctl show upower.service --timestamp=unix -p ActiveEnterTimestamp --value)
    started=${started#@}
    if [[ -e $DEST && -n $started && $(stat -c %Y "$DEST") -le $started ]]; then pass "UPower started after the thresholds were written"
    else fail "UPower has not read the thresholds yet" "sudo systemctl restart upower"; fi
    checks_done
}
