# shellcheck shell=bash disable=SC2034  # the metadata variables are read by lib/components.sh
# Haptic feedback: the ELAN2703 haptic touchpad and, when one is connected, a Logitech mouse with a haptic motor
# (MX Master 4), vibrate on GNOME events (window maximised, workspace switched, screen locked...).
TITLE="Haptic feedback"
SUMMARY="The touchpad (and an MX Master 4 mouse, if you have one) gives a short vibration on window, workspace and lock events."
RISK=low
DEFAULT=1
ROOT=1
DEBIAN_PACKAGES="solaar python3-gi python3-tomlkit"
REQUIRES=""
CHANGES="/etc/udev/rules.d/70-haptic-touchpad.rules: lets your session write to the touchpad's hidraw node
~/.local/bin/haptic-bridge, ~/.local/lib/haptic-bridge/ and the user service haptic-bridge.service
~/.config/haptic-bridge/events.toml: your settings (kept on uninstall)
~/.config/autostart/solaar.desktop: hides the Solaar tray app (it would talk to the mouse at the same time)
GNOME Shell extension haptic-events@maximeallanic.github.io"
ROLLBACK="sudo rm /etc/udev/rules.d/70-haptic-touchpad.rules && sudo udevadm control --reload-rules
systemctl --user disable --now haptic-bridge.service
rm ~/.local/bin/haptic-bridge ~/.config/systemd/user/haptic-bridge.service; rm -r ~/.local/lib/haptic-bridge
gnome-extensions disable haptic-events@maximeallanic.github.io; rm -r ~/.local/share/gnome-shell/extensions/haptic-events@maximeallanic.github.io"

UDEV_RULE=/etc/udev/rules.d/70-haptic-touchpad.rules
BIN=$HOME/.local/bin/haptic-bridge
LIBDIR=$HOME/.local/lib/haptic-bridge
UNIT=$HOME/.config/systemd/user/haptic-bridge.service
EVENTS=$HOME/.config/haptic-bridge/events.toml
SOLAAR_AUTOSTART=$HOME/.config/autostart/solaar.desktop
SOLAAR_HIDDEN=$'[Desktop Entry]\nType=Application\nName=Solaar\nHidden=true'
EXT_SRC=$COMPONENT_DIR/haptic-events@maximeallanic.github.io
UUID=haptic-events@maximeallanic.github.io

component_install() {
    install_if_changed "$COMPONENT_DIR/70-haptic-touchpad.rules" "$UDEV_RULE" 644
    as_root udevadm control --reload-rules
    as_root udevadm trigger --action=change --subsystem-match=hidraw
    as_root udevadm settle

    run install -D -m 755 "$COMPONENT_DIR/haptic-bridge" "$BIN"
    run install -D -m 644 "$COMPONENT_DIR/haptic_touchpad.py" "$LIBDIR/haptic_touchpad.py"
    run install -D -m 644 "$COMPONENT_DIR/haptic-bridge.service" "$UNIT"
    # events.toml holds the user's settings: copied when absent, otherwise only the events it lacks are added
    # (merge_events.py keeps every key, comment and muted event, and leaves a dated copy before rewriting).
    if [[ ! -f $EVENTS ]]; then
        run install -D -m 644 "$COMPONENT_DIR/events.toml" "$EVENTS"
    elif [[ $REDRIX_DRY_RUN != 1 ]]; then
        local added
        added=$(python3 -I "$COMPONENT_DIR/merge_events.py" "$EVENTS" "$COMPONENT_DIR/events.toml")
        note "events.toml kept; events added: ${added//$'\n'/ }"
    fi
    # Solaar is used as a library; its tray app would be a second HID++ client of the mouse. Hidden only when the
    # user has no autostart entry of their own for it.
    if [[ ! -e $SOLAAR_AUTOSTART ]]; then
        run mkdir -p "${SOLAAR_AUTOSTART%/*}"
        [[ $REDRIX_DRY_RUN == 1 ]] || printf '%s\n' "$SOLAAR_HIDDEN" >"$SOLAAR_AUTOSTART"
    fi
    run systemctl --user daemon-reload
    run systemctl --user enable haptic-bridge.service
    run systemctl --user restart haptic-bridge.service
    install_extension "$EXT_SRC"
}

component_uninstall() {
    remove_extension "$UUID"
    if [[ -f $UNIT ]]; then run systemctl --user disable --now haptic-bridge.service; fi
    run rm -f -- "$UNIT" "$BIN" "$LIBDIR/haptic_touchpad.py"
    if [[ -d $LIBDIR ]]; then run rmdir --ignore-fail-on-non-empty -- "$LIBDIR"; fi
    run systemctl --user daemon-reload
    if [[ $(cat "$SOLAAR_AUTOSTART" 2>/dev/null) == "$SOLAAR_HIDDEN" ]]; then run rm -f -- "$SOLAAR_AUTOSTART"; fi
    remove_root_file "$UDEV_RULE"
    as_root udevadm control --reload-rules
    note "kept: $EVENTS (your settings) and the solaar package (remove it with apt if you do not use it)"
}

component_verify() {
    local tp
    if systemctl --user is-active --quiet haptic-bridge.service; then pass "haptic-bridge.service is running"
    else fail "haptic-bridge.service is not running" "journalctl --user -u haptic-bridge -b"; fi
    same_file "$COMPONENT_DIR/70-haptic-touchpad.rules" "$UDEV_RULE" "udev rule for the touchpad" "reinstall: ./install.sh haptics"
    if tp=$("$BIN" --touchpad 2>/dev/null | sed -n '1s/^# //p') && [[ -n $tp ]]; then
        pass "haptic touchpad found: $tp"
        if [[ -w $tp ]]; then pass "your session can write to $tp"
        else fail "no write access to $tp" "log out and back in; the uaccess ACL is granted to the active session"; fi
    else
        fail "haptic touchpad not found" "is this the ELAN2703 touchpad (HID 04F3:323B)? journalctl --user -u haptic-bridge -b"
    fi
    if [[ -f $EVENTS ]]; then
        local missing
        if missing=$(python3 -I -c 'import sys, tomllib
user, kit = (tomllib.load(open(p, "rb")).get("events", {}) for p in sys.argv[1:3])
print(" ".join(sorted(set(kit) - set(user))))' "$EVENTS" "$COMPONENT_DIR/events.toml" 2>/dev/null); then
            if [[ -z $missing ]]; then pass "events.toml has every event of the kit"
            else fail "events.toml lacks: $missing" "reinstall: ./install.sh haptics (adds them, keeps your settings)"; fi
        else
            fail "$EVENTS is not valid TOML" "fix it or move it away and reinstall"
        fi
    else
        fail "$EVENTS is missing" "reinstall: ./install.sh haptics"
    fi
    if "$BIN" --ping >/dev/null 2>&1; then pass "Logitech haptic mouse connected"
    else info "no Logitech haptic mouse connected (optional: only the touchpad will vibrate)"; fi
    check_extension "$UUID" "$EXT_SRC"
    if [[ -n ${tp:-} ]] && "$BIN" play lock touchpad 2>/dev/null; then pass "test vibration played on the touchpad (rest a finger on it to feel it)"
    elif [[ -n ${tp:-} ]]; then fail "test vibration not played on the touchpad" "journalctl --user -u haptic-bridge -b"; fi
    checks_done
}
