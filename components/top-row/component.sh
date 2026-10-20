# shellcheck shell=bash disable=SC2034  # the metadata variables are read by lib/components.sh
# Keyboard top row: the lock key locks the screen (it sends KEY_SLEEP by default) and the fullscreen key toggles
# fullscreen.
TITLE="Lock and fullscreen keys"
SUMMARY="The lock key at the end of the top row locks the screen instead of suspending; the fullscreen key works."
RISK=low
DEFAULT=1
ROOT=1
DEBIAN_PACKAGES=""
REQUIRES=""
CHANGES="/etc/udev/hwdb.d/61-redrix-lock-key.hwdb: scancode 0x5d becomes KEY_SCREENLOCK on this board only
The built-in keyboard is re-bound once so GNOME sees the new key (a second without keyboard)
GNOME settings: lock-screen shortcut also bound by keycode (0xa0), fullscreen key bound to toggle fullscreen"
ROLLBACK="sudo rm /etc/udev/hwdb.d/61-redrix-lock-key.hwdb && sudo systemd-hwdb update
sudo sh -c 'echo serio0 > /sys/bus/serio/drivers/atkbd/unbind; echo serio0 > /sys/bus/serio/drivers/atkbd/bind'   (one line; or reboot)
gsettings reset org.gnome.settings-daemon.plugins.media-keys screensaver
gsettings reset org.gnome.desktop.wm.keybindings toggle-fullscreen"

HWDB=/etc/udev/hwdb.d/61-redrix-lock-key.hwdb
KEYBOARD=/dev/input/by-path/platform-i8042-serio-0-event-kbd
MEDIA_KEYS=org.gnome.settings-daemon.plugins.media-keys
WM_KEYS=org.gnome.desktop.wm.keybindings

component_supported() {
    [[ -e /sys/bus/serio/drivers/atkbd/serio0 ]] && return 0
    echo "built-in keyboard (atkbd serio0) not found"
    return 1
}

# The hwdb is applied by a "change" uevent, but Mutter keeps the key list it read when it opened the device and
# drops codes missing from it: re-binding the keyboard makes the compositor reopen it.
reload_keyboard() {
    as_root systemd-hwdb update
    write_sysfs serio0 /sys/bus/serio/drivers/atkbd/unbind
    write_sysfs serio0 /sys/bus/serio/drivers/atkbd/bind
}

component_install() {
    install_if_changed "$COMPONENT_DIR/61-redrix-lock-key.hwdb" "$HWDB" 644
    if ((INSTALLED_CHANGED)); then reload_keyboard; fi
    # Mutter resolves keysym names case-insensitively and, since xkbcommon gained XF86Screensaver, the default
    # "XF86ScreenSaver" binding lands on that other keysym and never fires (mutter#3990). Binding the keycode as
    # well works around it and stays harmless once upstream fixes the lookup.
    gsettings_set_saved "$MEDIA_KEYS" screensaver "['<Super>l', '0xa0']"
    gsettings_set_saved "$WM_KEYS" toggle-fullscreen "['XF86FullScreen']"
}

component_uninstall() {
    if [[ -e $HWDB ]]; then
        remove_root_file "$HWDB"
        reload_keyboard
    fi
    gsettings_restore "$MEDIA_KEYS" screensaver
    gsettings_restore "$WM_KEYS" toggle-fullscreen
}

component_verify() {
    local code
    same_file "$COMPONENT_DIR/61-redrix-lock-key.hwdb" "$HWDB" "lock key mapping installed" "reinstall: ./install.sh top-row"
    if [[ ! -e $KEYBOARD ]]; then
        fail "built-in keyboard not found at $KEYBOARD"
    else
        if grep -qx 'KEYBOARD_KEY_5d=screenlock' <<<"$(udevadm info --query=property "$KEYBOARD")"; then
            pass "udev applies KEYBOARD_KEY_5d=screenlock to the built-in keyboard"
        else
            fail "udev does not apply the lock key mapping" "sudo systemd-hwdb update, then reboot"
        fi
        if [[ -r $KEYBOARD ]]; then
            code=$(python3 -I "$COMPONENT_DIR/keycode.py" "$KEYBOARD" 0x5d)
            if [[ $code == 152 ]]; then pass "kernel keymap: scancode 0x5d -> KEY_SCREENLOCK"
            else fail "kernel keymap: scancode 0x5d -> keycode $code (152 expected)" "reboot, or reinstall"; fi
        else
            info "kernel keymap not read ($KEYBOARD is readable by root only); the udev check above covers the mapping"
        fi
    fi
    if [[ $(gsettings get "$MEDIA_KEYS" screensaver) == *"'0xa0'"* ]]; then pass "lock shortcut also bound by keycode (mutter#3990)"
    else fail "lock shortcut lacks the keycode entry '0xa0'" "reinstall: ./install.sh top-row"; fi
    if [[ $(gsettings get "$WM_KEYS" toggle-fullscreen) == *XF86FullScreen* ]]; then pass "fullscreen key bound"
    else fail "fullscreen key not bound" "reinstall: ./install.sh top-row"; fi
    checks_done
}
