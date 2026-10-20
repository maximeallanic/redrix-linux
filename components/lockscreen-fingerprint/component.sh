# shellcheck shell=bash disable=SC2034  # the metadata variables are read by lib/components.sh
# Lock screen: the fingerprint reader is armed as soon as the clock shows, so a finger unlocks without pressing a
# key first (upstream gnome-shell#3048).
TITLE="Fingerprint from the lock clock"
SUMMARY="Touch the sensor on the lock screen clock to unlock, without pressing a key first."
RISK=medium
DEFAULT=0
ROOT=0
DEBIAN_PACKAGES=""
REQUIRES="fingerprint-login"
CHANGES="GNOME Shell extension fingerprint-from-clock@maximeallanic.github.io (changes the lock screen's unlock dialog)"
ROLLBACK="gnome-extensions disable fingerprint-from-clock@maximeallanic.github.io
rm -r ~/.local/share/gnome-shell/extensions/fingerprint-from-clock@maximeallanic.github.io"

EXT_SRC=$COMPONENT_DIR/fingerprint-from-clock@maximeallanic.github.io
UUID=fingerprint-from-clock@maximeallanic.github.io

component_install() { install_extension "$EXT_SRC"; }
component_uninstall() { remove_extension "$UUID"; }
component_verify() {
    check_extension "$UUID" "$EXT_SRC"
    checks_done
}
