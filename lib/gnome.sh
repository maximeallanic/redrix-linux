# shellcheck shell=bash
# GNOME session helpers: Shell extensions and user services. All run as the session user.

EXTENSIONS_DIR="$HOME/.local/share/gnome-shell/extensions"

# enabled_extensions add|remove UUID...: edits org.gnome.shell enabled-extensions, leaving every other entry alone.
enabled_extensions() {
    local action=$1
    shift
    if [[ $REDRIX_DRY_RUN == 1 ]]; then note "[dry-run] enabled-extensions: $action $*"; return 0; fi
    python3 -I "$REDRIX_ROOT/lib/enabled_extensions.py" "$action" "$@"
}

# install_extension SRC_DIR: copies the runtime files (top-level *.js and metadata.json; tests stay behind) to the
# user's extension folder under the UUID of its metadata, then enables it.
install_extension() {
    local src=$1 uuid dest f
    uuid=$(python3 -I -c 'import json, sys; print(json.load(open(sys.argv[1]))["uuid"])' "$src/metadata.json")
    dest="$EXTENSIONS_DIR/$uuid"
    run mkdir -p "$dest"
    for f in "$src"/*.js "$src"/metadata.json; do run install -m 644 "$f" "$dest/${f##*/}"; done
    enabled_extensions add "$uuid"
    # The running Shell only knows extensions present at login; enabling a new one takes a new login on Wayland.
    if [[ $REDRIX_DRY_RUN != 1 ]] && ! gnome-extensions enable "$uuid" 2>/dev/null; then
        note "extension $uuid will start at your next login"
    fi
}

# remove_extension UUID: disables it and deletes exactly its folder.
remove_extension() {
    local uuid=$1
    [[ $uuid == *@* && $uuid != */* ]] || die "refusing to remove a suspicious extension uuid: $uuid"
    enabled_extensions remove "$uuid"
    if grep -qxF "$uuid" <<<"$(gnome-extensions list --enabled 2>/dev/null)"; then run gnome-extensions disable "$uuid"; fi
    if [[ -d "$EXTENSIONS_DIR/$uuid" ]]; then run rm -rf -- "${EXTENSIONS_DIR:?}/$uuid"; note "removed extension $uuid"; fi
}

extension_uuid() { python3 -I -c 'import json, sys; print(json.load(open(sys.argv[1]))["uuid"])' "$1/metadata.json"; }

# gsettings_set_saved SCHEMA KEY VALUE: sets a key, first keeping its current value (only the first time, so a
# reinstall does not replace the user's original with the kit's own value).
gsettings_set_saved() {
    local schema=$1 key=$2 value=$3 dir
    dir=$(saved_dir "$COMPONENT_ID")
    if [[ ! -e "$dir/$schema.$key" && $REDRIX_DRY_RUN != 1 ]]; then
        mkdir -p "$dir"
        gsettings get "$schema" "$key" >"$dir/$schema.$key"
    fi
    run gsettings set "$schema" "$key" "$value"
}

# gsettings_restore SCHEMA KEY: puts back the value kept by gsettings_set_saved; the default when none was kept.
gsettings_restore() {
    local schema=$1 key=$2 file
    file="$(saved_dir "$COMPONENT_ID")/$schema.$key"
    if [[ -s $file ]]; then
        run gsettings set "$schema" "$key" "$(cat "$file")"
        run rm -f -- "$file"
    else
        run gsettings reset "$schema" "$key"
    fi
}
