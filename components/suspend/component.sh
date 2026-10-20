# shellcheck shell=bash disable=SC2034  # the metadata variables are read by lib/components.sh
# Suspend: S3 ("deep") instead of s2idle, and the touchpad no longer wakes the machine right after it suspends.
TITLE="Working suspend (S3)"
SUMMARY="Closing the lid really suspends: deep sleep that lasts days instead of a shallow sleep that drains the battery."
RISK=medium
DEFAULT=0
ROOT=1
DEBIAN_PACKAGES=""
REQUIRES=""
CHANGES="/etc/systemd/sleep.conf.d/90-redrix-deep.conf: MemorySleepMode=deep
/etc/udev/rules.d/90-redrix-touchpad-no-wakeup.rules: the touchpad cannot wake the machine (lid, keyboard, power button still do)"
ROLLBACK="sudo rm /etc/systemd/sleep.conf.d/90-redrix-deep.conf /etc/udev/rules.d/90-redrix-touchpad-no-wakeup.rules
echo enabled | sudo tee /sys/bus/i2c/devices/i2c-ELAN2703:00/power/wakeup"

SLEEP_CONF=/etc/systemd/sleep.conf.d/90-redrix-deep.conf
UDEV_RULE=/etc/udev/rules.d/90-redrix-touchpad-no-wakeup.rules
TOUCHPAD=/sys/bus/i2c/devices/i2c-ELAN2703:00

component_supported() {
    if [[ $(firmware_kind) != mrchromebox ]]; then
        echo "needs MrChromebox's UEFI firmware (this machine runs $(firmware_version)); on the stock firmware suspend crashes the EC"
        return 1
    fi
    offers_deep_sleep && return 0
    echo "the kernel does not offer S3 (no \"deep\" in /sys/power/mem_sleep)"
    return 1
}

set_touchpad_wakeup() {
    if [[ -e $TOUCHPAD/power/wakeup ]]; then write_sysfs "$1" "$TOUCHPAD/power/wakeup"; fi
}

component_install() {
    install_if_changed "$COMPONENT_DIR/90-redrix-deep.conf" "$SLEEP_CONF" 644
    install_if_changed "$COMPONENT_DIR/90-redrix-touchpad-no-wakeup.rules" "$UDEV_RULE" 644
    as_root udevadm control --reload-rules
    set_touchpad_wakeup disabled
    note "systemd reads sleep.conf.d at each suspend: nothing to restart"
}

component_uninstall() {
    remove_root_file "$SLEEP_CONF" "$UDEV_RULE"
    as_root udevadm control --reload-rules
    set_touchpad_wakeup enabled
}

component_verify() {
    local wakeup journal entries
    same_file "$COMPONENT_DIR/90-redrix-deep.conf" "$SLEEP_CONF" "deep sleep configured" "./install.sh suspend"
    same_file "$COMPONENT_DIR/90-redrix-touchpad-no-wakeup.rules" "$UDEV_RULE" "touchpad wake-up rule installed" "./install.sh suspend"
    if grep -qw deep /sys/power/mem_sleep; then pass "the kernel offers S3 (deep)"
    else fail "no S3 in /sys/power/mem_sleep" "see docs/components/suspend.md"; fi
    wakeup=$(cat "$TOUCHPAD/power/wakeup" 2>/dev/null)
    if [[ $wakeup == disabled ]]; then pass "the touchpad cannot wake the machine"
    else fail "touchpad wake-up is '${wakeup:-unknown}'" "./install.sh suspend, or reboot"; fi
    # Evidence from this boot, when the kernel log is readable: the last suspends used S3.
    if journal=$(journalctl -k -b --no-pager -q -g 'PM: suspend entry' 2>/dev/null) && [[ -n $journal ]]; then
        entries=$(grep -c 'suspend entry (deep)' <<<"$journal")
        if [[ $entries -gt 0 && $(tail -1 <<<"$journal") == *'(deep)'* ]]; then pass "last suspend of this boot used S3 ($entries deep suspend(s) so far)"
        else fail "the last suspend of this boot was not S3: $(tail -1 <<<"$journal")" "see docs/components/suspend.md"; fi
    else
        info "no suspend in this boot's readable kernel log yet (close the lid once, then check again)"
    fi
    checks_done
}
