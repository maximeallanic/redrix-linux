# shellcheck shell=bash disable=SC2034  # the metadata variables are read by lib/components.sh
# Shutdown splash: GNOME fades to black, then Plymouth's shutdown screen fades the firmware logo in where it sits at
# power-on. The boot theme is not touched.
TITLE="Shutdown logo"
SUMMARY="Shutting down or restarting fades to black, then shows the firmware logo, instead of a jump to text."
RISK=medium
DEFAULT=0
ROOT=1
DEBIAN_PACKAGES="plymouth plymouth-themes python3"
REQUIRES=""
CHANGES="/usr/share/plymouth/themes/redrix-shutdown/: theme script, the firmware logo as PNG, the spinner frames
/etc/plymouth/plymouthd-redrix-shutdown.conf, bind-mounted over plymouthd.conf in the Plymouth shutdown units only
Drop-ins for plymouth-{poweroff,reboot,halt,kexec}.service
GNOME Shell extension fade-to-black@maximeallanic.github.io"
ROLLBACK="sudo rm -r /usr/share/plymouth/themes/redrix-shutdown /etc/plymouth/plymouthd-redrix-shutdown.conf
sudo rm /etc/systemd/system/plymouth-{poweroff,reboot,halt,kexec}.service.d/redrix-shutdown-theme.conf
sudo systemctl daemon-reload
gnome-extensions disable fade-to-black@maximeallanic.github.io"

THEME_DIR=/usr/share/plymouth/themes/redrix-shutdown
SPINNER_DIR=/usr/share/plymouth/themes/spinner
CONF=/etc/plymouth/plymouthd-redrix-shutdown.conf
UNITS=(plymouth-poweroff plymouth-reboot plymouth-halt plymouth-kexec)
DROPIN_NAME=redrix-shutdown-theme.conf
EXT_SRC=$COMPONENT_DIR/fade-to-black@maximeallanic.github.io
UUID=fade-to-black@maximeallanic.github.io
FRAMES=30

component_supported() {
    [[ -r /sys/firmware/acpi/bgrt/image ]] && return 0
    echo "the firmware publishes no boot logo (no ACPI BGRT image)"
    return 1
}

theme_files() {
    local i
    printf '%s\n' redrix-shutdown.plymouth redrix-shutdown.script logo.png
    for ((i = 1; i <= FRAMES; i++)); do printf 'throbber-%04d.png\n' "$i"; done
}

component_install() {
    local tmp u i f
    [[ -e /etc/plymouth/plymouthd.conf || $REDRIX_DRY_RUN == 1 ]] || die "/etc/plymouth/plymouthd.conf missing (package plymouth)"
    install_if_changed "$COMPONENT_DIR/theme/redrix-shutdown.plymouth" "$THEME_DIR/redrix-shutdown.plymouth" 644
    install_if_changed "$COMPONENT_DIR/theme/redrix-shutdown.script" "$THEME_DIR/redrix-shutdown.script" 644
    tmp=$(mktemp -d)
    python3 -I "$COMPONENT_DIR/bgrt_to_png.py" "$tmp/logo.png" >/dev/null
    install_if_changed "$tmp/logo.png" "$THEME_DIR/logo.png" 644
    rm -rf -- "$tmp"
    for ((i = 1; i <= FRAMES; i++)); do
        f=$(printf 'throbber-%04d.png' "$i")
        if [[ -e $SPINNER_DIR/$f || $REDRIX_DRY_RUN == 1 ]]; then
            install_if_changed "$SPINNER_DIR/$f" "$THEME_DIR/$f" 644
        else
            die "$SPINNER_DIR/$f missing (package plymouth-themes)"
        fi
    done
    install_if_changed "$COMPONENT_DIR/plymouthd-redrix-shutdown.conf" "$CONF" 644
    for u in "${UNITS[@]}"; do
        install_if_changed "$COMPONENT_DIR/shutdown-theme.conf" "/etc/systemd/system/$u.service.d/$DROPIN_NAME" 644
    done
    as_root systemctl daemon-reload
    install_extension "$EXT_SRC"
    grep -qw splash /proc/cmdline || warn "the kernel command line has no \"splash\": Plymouth shows text at shutdown (docs/components/shutdown-splash.md)"
}

component_uninstall() {
    local u f
    remove_extension "$UUID"
    for u in "${UNITS[@]}"; do
        remove_root_file "/etc/systemd/system/$u.service.d/$DROPIN_NAME"
        if [[ -d /etc/systemd/system/$u.service.d ]]; then as_root rmdir --ignore-fail-on-non-empty -- "/etc/systemd/system/$u.service.d"; fi
    done
    as_root systemctl daemon-reload
    remove_root_file "$CONF"
    while IFS= read -r f; do remove_root_file "$THEME_DIR/$f"; done < <(theme_files)
    if [[ -d $THEME_DIR ]]; then as_root rmdir -- "$THEME_DIR"; fi
}

component_verify() {
    local u missing='' f
    while IFS= read -r f; do [[ -s $THEME_DIR/$f ]] || missing+=" $f"; done < <(theme_files)
    if [[ -z $missing ]]; then pass "shutdown theme complete in $THEME_DIR"
    else fail "shutdown theme incomplete, missing:$missing" "./install.sh shutdown-splash"; fi
    same_file "$COMPONENT_DIR/theme/redrix-shutdown.script" "$THEME_DIR/redrix-shutdown.script" "theme script up to date" "./install.sh shutdown-splash"
    same_file "$COMPONENT_DIR/plymouthd-redrix-shutdown.conf" "$CONF" "shutdown-only Plymouth configuration installed" "./install.sh shutdown-splash"
    for u in "${UNITS[@]}"; do
        if grep -qF "BindReadOnlyPaths=$CONF:/etc/plymouth/plymouthd.conf" <<<"$(systemctl cat "$u.service" 2>/dev/null)"; then
            pass "$u.service uses the shutdown theme"
        else
            fail "$u.service does not use the shutdown theme" "./install.sh shutdown-splash; sudo systemctl daemon-reload"
        fi
    done
    if grep -qw splash /proc/cmdline; then pass "kernel command line has \"splash\""
    else fail "kernel command line lacks \"splash\": Plymouth shows text" "see docs/components/shutdown-splash.md"; fi
    check_extension "$UUID" "$EXT_SRC"
    checks_done
}
