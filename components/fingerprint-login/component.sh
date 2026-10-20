# shellcheck shell=bash disable=SC2034  # the metadata variables are read by lib/components.sh
# Fingerprint login: Debian's pam_fprintd profile (common-auth: login screen, lock screen, sudo, polkit) and the
# fingerprint option of the GDM login screen. The password always keeps working.
TITLE="Log in with a fingerprint"
SUMMARY="Unlock, log in and approve sudo/admin prompts with a finger; the password still works everywhere."
RISK=high
DEFAULT=0
ROOT=1
DEBIAN_PACKAGES="libpam-fprintd"
REQUIRES="fingerprint"
CHANGES="Backs up /etc/pam.d to /var/backups/redrix-linux/pam.d-<date>
pam-auth-update --enable fprintd: Debian's own profile puts pam_fprintd (one try, 10 s) before the password in common-auth
/etc/gdm3/greeter.dconf-defaults: enable-fingerprint-authentication=true, and the same key for your session
Logging in at the login screen with a finger does not unlock the GNOME keyring (it asks for the password later)"
ROLLBACK="sudo pam-auth-update --package --disable fprintd
or restore the backup: sudo cp -a /var/backups/redrix-linux/pam.d-<date>/. /etc/pam.d/
From a text console (Ctrl+Alt+F3) if the graphical login fails: the password works there too"

GREETER=/etc/gdm3/greeter.dconf-defaults
# Debian's gdm3 compiles the greeter's dconf database with this generator (dconf update does not cover it).
GDM_GENERATOR=/usr/share/gdm/generate-config
BACKUPS=/var/backups/redrix-linux

component_supported() {
    [[ -e /etc/pam.d/common-auth ]] || { echo "Debian-style PAM (pam-auth-update) not found"; return 1; }
    [[ -f $GREETER ]] || { echo "GDM (gdm3) not found"; return 1; }
    return 0
}

enrolled() { local l; l=$(fprintd-list "$USER" 2>/dev/null) || l=''; grep -q ' - #' <<<"$l"; }

# greeter true|false: whether GDM and the lock screen offer the fingerprint.
greeter() {
    as_root sed -i "s/^#\? *enable-fingerprint-authentication=.*/enable-fingerprint-authentication=$1/" "$GREETER"
    if [[ $REDRIX_DRY_RUN != 1 ]] && ! grep -q "^enable-fingerprint-authentication=$1\$" "$GREETER"; then
        die "could not set enable-fingerprint-authentication=$1 in $GREETER"
    fi
    if [[ -x $GDM_GENERATOR ]]; then as_root "$GDM_GENERATOR"; fi
}

component_install() {
    local backup
    enrolled || die "no finger enrolled for $USER: run fprintd-enroll, test it with fprintd-verify, then install this again"
    backup=$BACKUPS/pam.d-$(date +%Y%m%d-%H%M%S)
    as_root mkdir -p "$BACKUPS"
    as_root cp -a /etc/pam.d "$backup"
    note "backup of /etc/pam.d: $backup"
    as_root pam-auth-update --package --enable fprintd
    if [[ $REDRIX_DRY_RUN != 1 ]]; then
        if ! grep -q pam_unix.so /etc/pam.d/common-auth; then
            as_root pam-auth-update --package --disable fprintd
            local f
            for f in common-auth common-account common-password common-session common-session-noninteractive; do
                if [[ -e $backup/$f ]]; then as_root cp -a "$backup/$f" "/etc/pam.d/$f"; fi
            done
            die "pam_unix vanished from common-auth: the fingerprint profile was disabled and the common-* files were put back from $backup"
        fi
        grep -q pam_fprintd.so /etc/pam.d/common-auth || die "pam-auth-update did not add pam_fprintd (local edits to common-auth?)"
    fi
    greeter true
    gsettings_set_saved org.gnome.login-screen enable-fingerprint-authentication true
    note "test it now in a second terminal, before closing this one: sudo -k; sudo true  (touch the sensor)"
}

component_uninstall() {
    as_root pam-auth-update --package --disable fprintd
    greeter false
    gsettings_restore org.gnome.login-screen enable-fingerprint-authentication
    note "libpam-fprintd stays installed (inactive); backups of /etc/pam.d are in $BACKUPS"
}

component_verify() {
    if grep -q pam_fprintd.so /etc/pam.d/common-auth; then pass "fingerprint enabled in common-auth"
    else fail "pam_fprintd is not in /etc/pam.d/common-auth" "./install.sh fingerprint-login"; fi
    if grep -q pam_unix.so /etc/pam.d/common-auth; then pass "password fallback (pam_unix) present"
    else fail "pam_unix is missing from common-auth: password login is broken" "restore a backup from $BACKUPS now"; fi
    if grep -q '^enable-fingerprint-authentication=true' "$GREETER"; then pass "login screen offers the fingerprint"
    else fail "login screen does not offer the fingerprint" "./install.sh fingerprint-login"; fi
    if enrolled; then pass "finger(s) enrolled for $USER"
    else fail "no finger enrolled for $USER" "fprintd-enroll"; fi
    checks_done
}
