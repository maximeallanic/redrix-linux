# shellcheck shell=bash disable=SC2034  # variables shared with the scripts that source this file
# Shared helpers: output, prompts, privilege boundary, dry run, state. Sourced by install.sh, uninstall.sh, verify.sh
# and the tests; never executed on its own.

REDRIX_VERSION=0.1.1
REDRIX_NAME=redrix-linux

# Machine-parsed tool output must not depend on the desktop language.
export LC_ALL=C
# A failure inside $(...) fails the assignment that uses it, instead of passing an empty value along.
shopt -s inherit_errexit
# Administration tools the kit looks for (update-initramfs, libwacom-update-db, ...) live in sbin, which a normal
# user's PATH lacks on several Debian and Ubuntu releases; sudo then runs them with its own secure_path.
for _d in /usr/local/sbin /usr/sbin /sbin; do
    [[ :$PATH: == *":$_d:"* ]] || PATH=$PATH:$_d
done
unset _d

: "${REDRIX_DRY_RUN:=0}"
: "${REDRIX_ASSUME_YES:=0}"
# Where the kit records what it installed. Overridable for the tests.
: "${REDRIX_STATE_DIR:=${XDG_DATA_HOME:-$HOME/.local/share}/$REDRIX_NAME/installed}"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_BOLD=$'\e[1m' C_DIM=$'\e[2m' C_RED=$'\e[31m' C_GREEN=$'\e[32m' C_YELLOW=$'\e[33m' C_BLUE=$'\e[34m' C_OFF=$'\e[0m'
else
    C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_OFF=''
fi

say()  { printf '%s\n' "$*"; }
step() { printf '%s==>%s %s%s%s\n' "$C_BLUE" "$C_OFF" "$C_BOLD" "$*" "$C_OFF"; }
note() { printf '    %s\n' "$*"; }
warn() { printf '%swarning:%s %s\n' "$C_YELLOW" "$C_OFF" "$*" >&2; }
die()  { printf '%serror:%s %s\n' "$C_RED" "$C_OFF" "$*" >&2; exit 1; }

# The terminal to talk to. Under `curl ... | bash` stdin is the script itself, so prompts read /dev/tty.
tty_available() { [[ -r /dev/tty && -w /dev/tty ]] && { : </dev/tty; } 2>/dev/null; }

# ask_yes_no QUESTION [default y|n] -> 0 for yes. --yes answers the default without asking.
ask_yes_no() {
    local question=$1 default=${2:-n} answer hint='[y/N]'
    [[ $default == y ]] && hint='[Y/n]'
    if [[ $REDRIX_ASSUME_YES == 1 ]]; then [[ $default == y ]]; return; fi
    tty_available || die "no terminal to ask \"$question\": run interactively, or pass --yes"
    printf '%s %s ' "$question" "$hint" >/dev/tty
    read -r answer </dev/tty || answer=''
    answer=${answer,,}
    [[ -z $answer ]] && answer=$default
    [[ $answer == y || $answer == yes ]]
}

# ask_typed WORD PROMPT -> 0 only when the user types WORD exactly. For changes that can lock someone out.
ask_typed() {
    local word=$1 prompt=$2 answer
    tty_available || return 1
    printf '%s\nType %s%s%s to continue, anything else to skip: ' "$prompt" "$C_BOLD" "$word" "$C_OFF" >/dev/tty
    read -r answer </dev/tty || answer=''
    [[ $answer == "$word" ]]
}

# Every change goes through run (user) or as_root (system), so --dry-run can show the whole plan.
run() {
    if [[ $REDRIX_DRY_RUN == 1 ]]; then printf '    %s[dry-run]%s %s\n' "$C_DIM" "$C_OFF" "$*"; return 0; fi
    "$@"
}
as_root() {
    if [[ $REDRIX_DRY_RUN == 1 ]]; then printf '    %s[dry-run, root]%s %s\n' "$C_DIM" "$C_OFF" "$*"; return 0; fi
    if [[ $EUID == 0 ]]; then "$@"; else sudo -- "$@"; fi
}
# as_root_write DEST MODE: stdin -> DEST, written by root. For generated files.
as_root_write() {
    local dest=$1 mode=$2 tmp
    if [[ $REDRIX_DRY_RUN == 1 ]]; then
        printf '    %s[dry-run, root]%s write %s (mode %s):\n' "$C_DIM" "$C_OFF" "$dest" "$mode"
        sed 's/^/        | /'
        return 0
    fi
    tmp=$(mktemp)
    cat >"$tmp"
    as_root install -D -m "$mode" -o root -g root "$tmp" "$dest"
    rm -f "$tmp"
}
# write_sysfs VALUE PATH: writes a kernel attribute as root (a redirection cannot go through sudo).
write_sysfs() {
    if [[ $REDRIX_DRY_RUN == 1 ]]; then printf '    %s[dry-run, root]%s echo %s > %s\n' "$C_DIM" "$C_OFF" "$1" "$2"; return 0; fi
    printf '%s' "$1" | as_root tee "$2" >/dev/null
}
# Asks for the sudo password once, up front, with the reason.
sudo_prime() {
    [[ $REDRIX_DRY_RUN == 1 || $EUID == 0 ]] && return 0
    command -v sudo >/dev/null || die "sudo is required for: $*"
    note "Administrator rights are needed for: $*"
    sudo -v || die "sudo refused"
}

require_user_session() {
    [[ $EUID != 0 ]] || die "run this as your normal user (not root, not with sudo): it asks for sudo itself when needed"
    [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" || -S "${XDG_RUNTIME_DIR:-/run/user/$EUID}/bus" ]] ||
        die "no session bus: run this from a terminal inside your GNOME session"
}

# State: one file per installed component, holding the kit version and the date.
state_mark()      { [[ $REDRIX_DRY_RUN == 1 ]] && return 0; mkdir -p "$REDRIX_STATE_DIR"; printf '%s %s\n' "$REDRIX_VERSION" "$(date -Iseconds)" >"$REDRIX_STATE_DIR/$1"; }
state_clear()     { [[ $REDRIX_DRY_RUN == 1 ]] && return 0; rm -f -- "$REDRIX_STATE_DIR/$1"; }
state_installed() { [[ -f "$REDRIX_STATE_DIR/$1" ]]; }
state_list()      { [[ -d $REDRIX_STATE_DIR ]] && find "$REDRIX_STATE_DIR" -maxdepth 1 -type f -printf '%f\n' | sort; return 0; }

# install_if_changed SRC DEST MODE: root-owned copy when DEST differs. Sets INSTALLED_CHANGED to 1 when it wrote,
# 0 when DEST was already identical, so callers can skip a reload that is not needed.
install_if_changed() {
    local src=$1 dest=$2 mode=$3
    INSTALLED_CHANGED=0
    if cmp -s "$src" "$dest" 2>/dev/null; then note "up to date: $dest"; return 0; fi
    as_root install -D -m "$mode" -o root -g root "$src" "$dest"
    INSTALLED_CHANGED=1
    if [[ $REDRIX_DRY_RUN != 1 ]]; then note "installed: $dest"; fi
}
# remove_root_file PATH...: deletes files the kit installed, exact paths only.
remove_root_file() {
    local f
    for f in "$@"; do
        if [[ -e $f || -L $f ]]; then
            as_root rm -f -- "$f"
            if [[ $REDRIX_DRY_RUN != 1 ]]; then note "removed: $f"; fi
        fi
    done
}

# saved_dir ID: where a component keeps what it replaced (previous settings), for its uninstall.
saved_dir() { printf '%s/saved/%s' "${REDRIX_STATE_DIR%/installed}" "$1"; }
