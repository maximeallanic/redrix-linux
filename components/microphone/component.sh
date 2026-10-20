# shellcheck shell=bash disable=SC2034  # the metadata variables are read by lib/components.sh
# Noise-suppressed internal microphone: PipeWire's echo-cancel module with WebRTC noise suppression on Mic1, made
# the default source.
TITLE="Microphone noise suppression"
SUMMARY="Adds a noise-suppressed internal microphone (fans, keyboard, room noise) and makes it the default input."
RISK=low
DEFAULT=1
ROOT=0
DEBIAN_PACKAGES="libspa-0.2-modules pipewire-bin wireplumber"
REQUIRES=""
# shellcheck disable=SC2088  # text shown to the user, not a path to expand
CHANGES="~/.config/pipewire/pipewire.conf.d/60-mic-noise-suppression.conf: a filtered source, mic_noise_suppression
The default audio input becomes that source (once PipeWire has restarted, at your next login)"
ROLLBACK="rm ~/.config/pipewire/pipewire.conf.d/60-mic-noise-suppression.conf
systemctl --user restart pipewire pipewire-pulse wireplumber   (cuts audio for a second)
then pick the internal microphone again in Settings > Sound"

CONF=${XDG_CONFIG_HOME:-$HOME/.config}/pipewire/pipewire.conf.d/60-mic-noise-suppression.conf
NODE=mic_noise_suppression

# The Mic1 capture node created by the SOF/rt5682 UCM profile (it carries the PCI path, so it is read, not assumed).
mic1_node() {
    wpctl status -n 2>/dev/null | sed -n 's/^.* \(alsa_input\.[^ ]*HiFi__Mic1__source\) .*$/\1/p' | head -1
}
node_id() {
    wpctl status -n 2>/dev/null | sed -n "s/^[^0-9]*\([0-9][0-9]*\)\. *$NODE  *\[Audio\/Source\].*/\1/p" | head -1
}
render() { sed "s|@MIC1_NODE@|$1|" "$COMPONENT_DIR/60-mic-noise-suppression.conf.in"; }

component_supported() {
    command -v wpctl >/dev/null || { echo "PipeWire/WirePlumber (wpctl) not found"; return 1; }
    [[ -n $(mic1_node) ]] && return 0
    echo "internal microphone (Mic1) not found: install the Chromebook audio configuration first (docs/components/microphone.md)"
    return 1
}

component_install() {
    local mic1 id
    mic1=$(mic1_node)
    [[ -n $mic1 ]] || die "internal microphone (Mic1) not found"
    if [[ $(render "$mic1") == "$(cat "$CONF" 2>/dev/null)" ]]; then
        note "up to date: $CONF"
    else
        run mkdir -p "${CONF%/*}"
        if [[ $REDRIX_DRY_RUN == 1 ]]; then note "[dry-run] write $CONF (capture target $mic1)"
        else render "$mic1" >"$CONF"; note "installed: $CONF (capture target $mic1)"; fi
    fi
    # PipeWire reads its configuration at start. Restarting it now would cut every stream, calls included, so the
    # filtered source appears at the next login, and the default is set then by `./install.sh microphone` or here
    # if it already runs.
    id=$(node_id)
    if [[ -n $id ]]; then
        run wpctl set-default "$id"
        note "default input: $NODE"
    else
        note "the filtered source starts with PipeWire: log out and back in, then run ./install.sh microphone again"
        note "to make it the default input (or pick \"Internal Microphone (noise suppressed)\" in Settings > Sound)"
    fi
}

component_uninstall() {
    if [[ -e $CONF ]]; then run rm -f -- "$CONF"; note "removed: $CONF"; fi
    note "the filtered source disappears when PipeWire restarts (next login); the default input then falls back"
    note "to the internal microphone by itself"
}

component_verify() {
    local mic1 status links sources others default
    mic1=$(mic1_node)
    status=$(wpctl status -n 2>/dev/null)
    links=$(pw-link -l 2>/dev/null)
    if [[ -n $mic1 && $(render "$mic1") == "$(cat "$CONF" 2>/dev/null)" ]]; then pass "configuration installed for $mic1"
    else fail "$CONF missing or out of date" "reinstall: ./install.sh microphone"; fi
    if [[ -e /usr/lib/$(uname -m)-linux-gnu/spa-0.2/aec/libspa-aec-webrtc.so ]]; then pass "WebRTC audio processing plugin present"
    else fail "libspa-aec-webrtc.so missing" "sudo apt install libspa-0.2-modules"; fi
    if grep -qE "[0-9]+\. +$NODE +\[Audio/Source\]" <<<"$status"; then pass "$NODE is running"
    else fail "$NODE is not running" "PipeWire reads the file at start: log out and back in"; fi
    # The capture stream's actual links: target.object only asks WirePlumber for Mic1.
    sources=$(awk -v want="$NODE.capture:" '
        /^[^ ]/ { port = $0; next }
        /^ +\|<- / && index(port, want) == 1 { sub(/^ +\|<- /, ""); print }' <<<"$links")
    if [[ -z $sources ]]; then
        fail "$NODE.capture is linked to nothing (expected Mic1)" "log out and back in"
    elif others=$(grep -v -F "${mic1:-Mic1}:" <<<"$sources"); then
        fail "$NODE.capture is also fed by: ${others//$'\n'/ }" "systemctl --user restart wireplumber"
    else
        pass "$NODE captures from Mic1"
    fi
    default=$(wpctl inspect @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | sed -n 's/.*node.name = "\(.*\)"/\1/p')
    if [[ $default == "$NODE" ]]; then pass "default input: $NODE"
    else fail "default input is ${default:-none}, not $NODE" "run ./install.sh microphone again, or choose it in Settings > Sound"; fi
    checks_done
}
