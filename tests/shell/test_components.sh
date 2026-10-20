#!/usr/bin/env bash
# Pure functions of real components: generated files and manifests, without touching the system.
set -uo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
# shellcheck source=tests/shell/assert.sh
source "$HERE/assert.sh"
SCRATCH=$(mktemp -d "${TEST_TMPDIR:?}/components.XXXXXX")
# shellcheck source=lib/common.sh
source "$REPO/lib/common.sh"

# shellcheck disable=SC2034  # COMPONENT_ID is read by the sourced component
in_component() {  # ID: sources it like lib/components.sh does
    COMPONENT_DIR=$REPO/components/$1
    COMPONENT_ID=$1
    # shellcheck source=/dev/null
    source "$COMPONENT_DIR/component.sh"
}

test_boot_theme_moves_prompts_below_the_logo_in_two_step_only() {
    local out
    out=$(bash "$REPO/components/boot-splash/render-theme.sh" "$HERE/../fixtures/bgrt.plymouth")
    t_contains "$out" $'[two-step]\nImageDir=/usr/share/plymouth/themes//spinner\nDialogVerticalAlignment=.72\nTitleVerticalAlignment=.72\nVerticalAlignment=.82\nTransition=fade-over\nTransitionDuration=0.5\nDialogClearsFirmwareBackground=false'
    t_contains "$out" $'[updates]\nTitle=Installing Updates...\nVerticalAlignment=.5' "other sections untouched"
    t_contains "$out" "Name=redrix-linux firmware logo"
    t_not_contains "$out" "Name[fr]"
}

test_boot_theme_refuses_a_source_without_the_keys() {
    printf '[Plymouth Theme]\nName=x\n[two-step]\nVerticalAlignment=.7\n' >"$SCRATCH/partial.plymouth"
    t_false bash "$REPO/components/boot-splash/render-theme.sh" "$SCRATCH/partial.plymouth" 2>/dev/null
}

test_microphone_conf_targets_the_detected_node() {
    in_component microphone
    local out
    out=$(render alsa_input.pci-0000_00_1f.3-platform-adl_rt5682_def.HiFi__Mic1__source)
    t_contains "$out" 'target.object = "alsa_input.pci-0000_00_1f.3-platform-adl_rt5682_def.HiFi__Mic1__source"'
    t_not_contains "$out" "@"
}

test_microphone_finds_mic1_in_wpctl_output() {
    in_component microphone
    # shellcheck disable=SC2329  # called by mic1_node and node_id
    wpctl() {
        printf ' │      63. alsa_input.pci-0000_00_1f.3-platform-adl_rt5682_def.HiFi__Mic2__source [Audio/Source]\n'
        printf ' │      66. alsa_input.pci-0000_00_1f.3-platform-adl_rt5682_def.HiFi__Mic1__source [Audio/Source]\n'
        printf ' │  *   42. mic_noise_suppression                                        [Audio/Source]\n'
    }
    t_eq "$(mic1_node)" alsa_input.pci-0000_00_1f.3-platform-adl_rt5682_def.HiFi__Mic1__source
    t_eq "$(node_id)" 42
}

test_speaker_manifest_pins_exactly_the_four_files() {
    local m=$REPO/components/speakers/dsm-param-redrix.sha256
    t_eq "$(grep -c . "$m")" 4
    t_eq "$(grep -cE '^[0-9a-f]{64}  dsm_param_(L|R|tt_L|tt_R)_Google_Redrix\.bin$' "$m")" 4
}

test_shutdown_theme_lists_every_file_the_script_loads() {
    in_component shutdown-splash
    local files script
    files=$(theme_files)
    script=$(cat "$REPO/components/shutdown-splash/theme/redrix-shutdown.script")
    t_contains "$files" logo.png
    t_contains "$script" 'Image("logo.png")'
    t_eq "$(grep -c '^throbber-' <<<"$files")" "$(sed -n 's/^SPINNER_FRAMES = \([0-9]*\);.*/\1/p' <<<"$script")"
}

test_only_hidden_solaar_entries_are_removed() {
    in_component haptics
    t_eq "$SOLAAR_HIDDEN" $'[Desktop Entry]\nType=Application\nName=Solaar\nHidden=true'
}

"${@:-run_tests}"
