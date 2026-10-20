# shellcheck shell=bash disable=SC2034  # the metadata variables are read by lib/components.sh
# Boot splash: one logo from power-on to the login screen. The firmware draws its logo and publishes it as the ACPI
# BGRT image; this Plymouth theme redraws it at the same place, and puts disk-unlock prompts and the spinner below it.
TITLE="Seamless boot logo"
SUMMARY="The firmware logo stays put from power-on to the login screen; password prompts appear under it."
RISK=high
DEFAULT=0
ROOT=1
DEBIAN_PACKAGES="plymouth plymouth-themes initramfs-tools"
REQUIRES=""
CHANGES="/usr/share/plymouth/themes/redrix-bgrt/redrix-bgrt.plymouth: generated from the bgrt theme of plymouth-themes
Default Plymouth theme set to redrix-bgrt (the previous one is recorded for uninstall)
Every initramfs is rebuilt (update-initramfs -u -k all): a failed rebuild can leave a kernel unbootable"
ROLLBACK="sudo plymouth-set-default-theme <previous theme, e.g. bgrt> && sudo update-initramfs -u -k all
sudo rm -r /usr/share/plymouth/themes/redrix-bgrt
If the machine does not boot: pick an older kernel in the boot menu (hold Space with systemd-boot, Esc/Shift with
GRUB) or boot a live USB, chroot and run the two commands above"

THEME=redrix-bgrt
THEME_FILE=/usr/share/plymouth/themes/$THEME/$THEME.plymouth

component_supported() {
    [[ -r /sys/firmware/acpi/bgrt/image ]] || { echo "the firmware publishes no boot logo (no ACPI BGRT image)"; return 1; }
    command -v update-initramfs >/dev/null && return 0
    echo "needs initramfs-tools (update-initramfs); dracut systems: see docs/components/boot-splash.md"
    return 1
}

previous_theme_file() { printf '%s/previous-theme' "$(saved_dir "$COMPONENT_ID")"; }

component_install() {
    local current theme
    if [[ ! -e /usr/share/plymouth/themes/bgrt/bgrt.plymouth ]] && [[ $REDRIX_DRY_RUN == 1 ]]; then
        note "[dry-run] plymouth-themes not installed yet: the theme is generated after the packages"
    else
        theme=$(bash "$COMPONENT_DIR/render-theme.sh")
        printf '%s\n' "$theme" | as_root_write "$THEME_FILE" 644
    fi
    current=$(plymouth-set-default-theme 2>/dev/null) || current=''
    if [[ -n $current && $current != "$THEME" && ! -e $(previous_theme_file) && $REDRIX_DRY_RUN != 1 ]]; then
        mkdir -p "$(saved_dir "$COMPONENT_ID")"
        printf '%s\n' "$current" >"$(previous_theme_file)"
    fi
    as_root plymouth-set-default-theme "$THEME"
    step "Rebuilding the initramfs of every installed kernel (the theme is copied into them)"
    as_root update-initramfs -u -k all
    if ! grep -qw splash /proc/cmdline; then
        warn "the kernel command line has no \"splash\": Plymouth shows text instead of the logo."
        warn "Add splash (and quiet) to it: see docs/components/boot-splash.md."
    fi
}

component_uninstall() {
    local previous=bgrt
    if [[ -s $(previous_theme_file) ]]; then previous=$(cat "$(previous_theme_file)"); fi
    if [[ $(plymouth-set-default-theme 2>/dev/null) == "$THEME" ]]; then
        as_root plymouth-set-default-theme "$previous"
        note "default theme back to $previous"
        step "Rebuilding the initramfs of every installed kernel"
        as_root update-initramfs -u -k all
    fi
    remove_root_file "$THEME_FILE"
    if [[ -d ${THEME_FILE%/*} ]]; then as_root rmdir -- "${THEME_FILE%/*}"; fi
    if [[ -e $(previous_theme_file) ]]; then run rm -f -- "$(previous_theme_file)"; fi
}

component_verify() {
    if [[ $(bash "$COMPONENT_DIR/render-theme.sh" 2>/dev/null) == "$(cat "$THEME_FILE" 2>/dev/null)" ]]; then
        pass "theme $THEME installed and up to date"
    else
        fail "$THEME_FILE missing or out of date" "./install.sh boot-splash"
    fi
    if [[ $(plymouth-set-default-theme 2>/dev/null) == "$THEME" ]]; then pass "Plymouth's default theme is $THEME"
    else fail "Plymouth's default theme is $(plymouth-set-default-theme 2>/dev/null || echo unknown)" "./install.sh boot-splash"; fi
    if grep -qw splash /proc/cmdline; then pass "kernel command line has \"splash\""
    else fail "kernel command line lacks \"splash\": the logo is not shown" "see docs/components/boot-splash.md"; fi
    if [[ -r /sys/firmware/acpi/bgrt/image ]]; then pass "the firmware publishes its logo (ACPI BGRT, $(cat /sys/firmware/acpi/bgrt/xoffset),$(cat /sys/firmware/acpi/bgrt/yoffset))"
    else fail "no ACPI BGRT image"; fi
    info "the initramfs copy is root-only; to check it: sudo lsinitramfs /boot/initrd.img-\$(uname -r) | grep $THEME"
    checks_done
}
