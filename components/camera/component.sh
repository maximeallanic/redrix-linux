# shellcheck shell=bash disable=SC2034  # the metadata variables are read by lib/components.sh
# Internal camera: libcamera tuning for the hi556 sensor (black level, colour matrix) and a WirePlumber policy that
# hides the 32 raw IPU6 nodes and lets a USB webcam outrank the internal camera.
TITLE="Camera colours"
SUMMARY="Calibrated colours and black level for the internal camera; hides 32 unusable raw camera entries from apps."
RISK=low
DEFAULT=1
ROOT=1
DEBIAN_PACKAGES="libcamera-ipa gstreamer1.0-libcamera libspa-0.2-libcamera gstreamer1.0-tools wireplumber"
REQUIRES=""
CHANGES="/etc/libcamera/ipa/simple/hi556.yaml: tuning file for the internal sensor
~/.config/wireplumber/wireplumber.conf.d/50-cameras.conf: hides the raw IPU6 nodes, USB webcams first
WirePlumber is restarted when the policy changes (audio and video streams reconnect, about a second)"
ROLLBACK="sudo rm /etc/libcamera/ipa/simple/hi556.yaml
rm ~/.config/wireplumber/wireplumber.conf.d/50-cameras.conf && systemctl --user restart wireplumber"

TUNING=/etc/libcamera/ipa/simple/hi556.yaml
WP_CONF=${XDG_CONFIG_HOME:-$HOME/.config}/wireplumber/wireplumber.conf.d/50-cameras.conf
# ACPI path of the sensor: the name libcamera gives the internal camera on this board.
CAMERA_NAME='\_SB_.PCI0.I2C2.CAM0'

component_supported() {
    [[ -d /sys/bus/i2c/drivers/hi556 ]] && return 0
    echo "the hi556 camera sensor driver is not loaded"
    return 1
}

component_install() {
    install_if_changed "$COMPONENT_DIR/hi556.yaml" "$TUNING" 644
    # Restarting WirePlumber re-routes every audio and video stream (calls included): only when the policy changed.
    if cmp -s "$COMPONENT_DIR/50-cameras.conf" "$WP_CONF"; then
        note "up to date: $WP_CONF"
    else
        run install -D -m 644 "$COMPONENT_DIR/50-cameras.conf" "$WP_CONF"
        run systemctl --user restart wireplumber.service
        note "installed: $WP_CONF (WirePlumber restarted)"
    fi
    note "applications use the new tuning the next time they open the camera"
}

component_uninstall() {
    remove_root_file "$TUNING"
    if [[ -e $WP_CONF ]]; then
        run rm -f -- "$WP_CONF"
        run systemctl --user restart wireplumber.service
        note "removed: $WP_CONF (WirePlumber restarted)"
    fi
}

component_verify() {
    local log status
    same_file "$COMPONENT_DIR/hi556.yaml" "$TUNING" "hi556 tuning installed" "reinstall: ./install.sh camera"
    same_file "$COMPONENT_DIR/50-cameras.conf" "$WP_CONF" "WirePlumber camera policy installed" "reinstall: ./install.sh camera"
    if command -v gst-launch-1.0 >/dev/null; then
        log=$(LIBCAMERA_LOG_LEVELS=IPAProxy:INFO timeout 15 gst-launch-1.0 -q libcamerasrc camera-name="$CAMERA_NAME" \
            ! fakesink num-buffers=3 2>&1)
        if grep -qF "Using tuning file $TUNING" <<<"$log"; then pass "libcamera loads the hi556 tuning (3 frames captured)"
        else fail "libcamera did not load $TUNING" "is another application using the camera? Output: $(tail -1 <<<"$log")"; fi
    else
        skip "gst-launch-1.0 not installed: capture test skipped (sudo apt install gstreamer1.0-tools)"
    fi
    status=$(wpctl status 2>/dev/null | sed -n '/^Video/,/^Settings/p')
    if grep -q 'ipu6' <<<"$status"; then fail "raw IPU6 nodes still listed by PipeWire" "systemctl --user restart wireplumber"
    else pass "raw IPU6 nodes hidden"; fi
    if grep -q 'hi556' <<<"$status"; then pass "internal camera available to applications"
    else fail "internal camera missing from PipeWire" "check that libspa-0.2-libcamera is installed, then restart wireplumber"; fi
    checks_done
}
