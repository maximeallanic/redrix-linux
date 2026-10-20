# shellcheck shell=bash disable=SC2034  # the metadata variables are read by lib/components.sh
# Built-in pen: declares the ELAN 04f3:2f75 pen digitiser to libwacom (so GNOME knows it is part of the display and
# maps it to it) with a one-tip pen profile, and replaces the mouse arrow under the pen tip by a small dot.
TITLE="Pen support"
SUMMARY="The pen stays on the laptop screen when a monitor is plugged in, appears in Settings > Wacom, draws a dot under the tip."
RISK=low
DEFAULT=1
ROOT=1
DEBIAN_PACKAGES="libwacom-bin"
REQUIRES=""
CHANGES="/etc/libwacom/elan-2f75.tablet and /etc/libwacom/redrix-pen.stylus, then libwacom-update-db
GNOME Shell extension pen-dot@maximeallanic.github.io"
ROLLBACK="sudo rm /etc/libwacom/elan-2f75.tablet /etc/libwacom/redrix-pen.stylus && sudo libwacom-update-db
gnome-extensions disable pen-dot@maximeallanic.github.io; rm -r ~/.local/share/gnome-shell/extensions/pen-dot@maximeallanic.github.io"

TABLET=/etc/libwacom/elan-2f75.tablet
STYLUS=/etc/libwacom/redrix-pen.stylus
EXT_SRC=$COMPONENT_DIR/pen-dot@maximeallanic.github.io
UUID=pen-dot@maximeallanic.github.io

update_libwacom() {
    # libwacom-update-db regenerates libwacom's udev rules and hwdb from /usr/share and /etc/libwacom.
    as_root libwacom-update-db
    as_root udevadm control --reload-rules
    as_root udevadm trigger --action=change --subsystem-match=input
    as_root udevadm settle
}

component_install() {
    local changed=0
    install_if_changed "$COMPONENT_DIR/elan-2f75.tablet" "$TABLET" 644
    changed=$INSTALLED_CHANGED
    install_if_changed "$COMPONENT_DIR/redrix-pen.stylus" "$STYLUS" 644
    if ((changed || INSTALLED_CHANGED)); then update_libwacom; fi
    install_extension "$EXT_SRC"
}

component_uninstall() {
    remove_extension "$UUID"
    if [[ -e $TABLET || -e $STYLUS ]]; then
        remove_root_file "$TABLET" "$STYLUS"
        update_libwacom
    fi
}

component_verify() {
    local devices
    same_file "$COMPONENT_DIR/elan-2f75.tablet" "$TABLET" "pen digitiser described to libwacom" "reinstall: ./install.sh pen"
    same_file "$COMPONENT_DIR/redrix-pen.stylus" "$STYLUS" "pen profile installed" "reinstall: ./install.sh pen"
    devices=$(libwacom-list-local-devices 2>/dev/null)
    if grep -q 'pid: 0x2f75' <<<"$devices"; then pass "libwacom recognises the built-in pen digitiser (04f3:2f75)"
    else fail "libwacom does not list the 04f3:2f75 digitiser" "sudo libwacom-update-db, then log out and back in"; fi
    if grep -q "name: 'Redrix Pen'" <<<"$devices"; then pass "pen described without button nor eraser (Redrix Pen)"
    else fail "pen profile 'Redrix Pen' not loaded" "sudo libwacom-update-db"; fi
    check_extension "$UUID" "$EXT_SRC"
    # pen-dot logs once per session whether Mutter consults its cursor hook. No grep -q: it would stop reading early
    # and journalctl would die of SIGPIPE.
    if journalctl --user -b --no-pager -o cat 2>/dev/null | grep -F "pen-dot: enabled ($UUID), override-cursor hook consulted" >/dev/null; then
        pass "pen-dot: Mutter consults its cursor hook"
    else
        fail "pen-dot has not reported its cursor hook this session" "log out and back in; journalctl --user -b -o cat | grep pen-dot:"
    fi
    checks_done
}
