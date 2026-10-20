#!/usr/bin/env bash
# Prints the redrix-bgrt Plymouth theme, derived from the bgrt theme of the installed plymouth-themes package (its
# ACPI BGRT background and spinner) with the dialog, title and spinner moved below the firmware logo, and the logo
# kept on screen while a password or PIN prompt shows; a short fade into the login screen. Generated on the machine: the kit ships no copy of Debian's
# theme, and follows its updates.
#   render-theme.sh [SOURCE]   (SOURCE defaults to /usr/share/plymouth/themes/bgrt/bgrt.plymouth)
set -euo pipefail
export LC_ALL=C
SOURCE=${1:-/usr/share/plymouth/themes/bgrt/bgrt.plymouth}
[[ -r $SOURCE ]] || { echo "$SOURCE not found (package plymouth-themes)" >&2; exit 1; }

# The firmware draws the logo centred at 38.2 % of the height (edk2 EDK2_FOLLOW_BGRT_SPEC); everything else goes below.
awk '
    BEGIN {
        want["DialogClearsFirmwareBackground"] = "false"
        want["DialogVerticalAlignment"] = ".72"
        want["TitleVerticalAlignment"] = ".72"
        want["VerticalAlignment"] = ".82"
        want["Transition"] = "fade-over"
        want["TransitionDuration"] = "0.5"
    }
    function emit(line) { out = out line "\n" }
    /^\[/ { section = $0 }
    /^Name\[/ { next }
    /^Name=/ && section == "[Plymouth Theme]" { emit("Name=redrix-linux firmware logo"); next }
    /^Description=/ && section == "[Plymouth Theme]" {
        emit("Description=The firmware boot logo (ACPI BGRT) stays on screen from power-on to the login screen; prompts and spinner below it. Derived from the bgrt theme by redrix-linux.")
        next
    }
    section == "[two-step]" {
        split($0, kv, "=")
        if (kv[1] in want) { emit(kv[1] "=" want[kv[1]]); seen[kv[1]] = 1; next }
    }
    { emit($0) }
    # Printed only when complete: a partial theme must never reach the caller.
    END {
        for (k in want) if (!(k in seen)) { print "missing key " k " in [two-step] of the source theme" > "/dev/stderr"; exit 1 }
        printf "%s", out
    }
' "$SOURCE"
