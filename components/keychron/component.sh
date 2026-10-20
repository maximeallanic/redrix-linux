# shellcheck shell=bash disable=SC2034  # the metadata variables are read by lib/components.sh
# Keychron keyboards: hidraw/USB access for Keychron Launcher in Chrome. Not specific to this laptop; off by default.
TITLE="Keychron Launcher access"
SUMMARY="Only if you own a Keychron keyboard: lets launcher.keychron.com in Chrome configure and update it."
RISK=low
DEFAULT=0
ROOT=1
DEBIAN_PACKAGES=""
REQUIRES=""
CHANGES="/etc/udev/rules.d/70-keychron.rules: raw HID access to Keychron devices for the session user"
ROLLBACK="sudo rm /etc/udev/rules.d/70-keychron.rules && sudo udevadm control --reload-rules"

RULE=/etc/udev/rules.d/70-keychron.rules

reload_rules() {
    as_root udevadm control --reload-rules
    as_root udevadm trigger --action=change --subsystem-match=hidraw --subsystem-match=usb
    as_root udevadm settle
}

component_install() {
    install_if_changed "$COMPONENT_DIR/70-keychron.rules" "$RULE" 644
    if ((INSTALLED_CHANGED)); then reload_rules; fi
}

component_uninstall() {
    if [[ -e $RULE ]]; then remove_root_file "$RULE"; reload_rules; fi
}

component_verify() {
    local d node found=0
    same_file "$COMPONENT_DIR/70-keychron.rules" "$RULE" "udev rule installed" "reinstall: ./install.sh keychron"
    for d in /sys/class/hidraw/hidraw*; do
        [[ -e $d ]] || continue
        if grep -qi 'keychron' "$d/device/uevent" 2>/dev/null; then
            found=1
            node=/dev/${d##*/}
            if [[ -r $node && -w $node ]]; then pass "Keychron device reachable: $node"
            else fail "no access to $node" "unplug and replug the keyboard or its dongle"; fi
        fi
    done
    ((found)) || info "no Keychron keyboard connected right now"
    checks_done
}
