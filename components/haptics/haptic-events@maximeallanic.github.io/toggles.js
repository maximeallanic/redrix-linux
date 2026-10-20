// User-driven toggles -> 'toggle-on' / 'toggle-off'. Quick-settings tiles: the
// direction is read when the button is pressed (pointer, touch or keyboard all set St.Button:pressed), the event is
// played on `clicked`; a state that changes on its own (Wi-Fi reconnecting) plays nothing. Menu switches:
// PopupSwitchMenuItem.toggle() is only called by an activation of the item.
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import * as QuickSettings from 'resource:///org/gnome/shell/ui/quickSettings.js';

import {toggleEvent} from './events.js';

let play = null;
let grid = null;
let addedId = 0;
let originalToggle = null;
const tracked = new Map(); // grid element -> [[object, handler id]…]

const isTile = el => el instanceof QuickSettings.QuickToggle || el instanceof QuickSettings.QuickMenuToggle;

function track(tile) {
    if (tracked.has(tile) || !isTile(tile))
        return;
    // The button the user clicks: the tile itself, or the toggle half of a tile with a menu.
    const button = tile instanceof QuickSettings.QuickMenuToggle ? tile._box.get_first_child() : tile;
    let before = null;
    tracked.set(tile, [
        [button, button.connect('notify::pressed', () => {
            if (button.pressed)
                before = tile.checked;
        })],
        [button, button.connect('clicked', () => {
            if (before === null)
                return;
            play?.(toggleEvent(before));
            before = null;
        })],
        [tile, tile.connect('destroy', () => tracked.delete(tile))],
    ]);
}

export function enable(playEvent) {
    play = playEvent;
    grid = Main.panel.statusArea.quickSettings.menu._grid;
    for (const el of grid.get_children())
        track(el);
    addedId = grid.connect('child-added', (_g, el) => track(el));
    const proto = PopupMenu.PopupSwitchMenuItem.prototype;
    originalToggle = proto.toggle;
    proto.toggle = function () {
        const before = this.state;
        originalToggle.call(this);
        if (this.state !== before)
            play?.(toggleEvent(before));
    };
}

export function disable() {
    if (originalToggle)
        PopupMenu.PopupSwitchMenuItem.prototype.toggle = originalToggle;
    originalToggle = null;
    if (grid && addedId)
        grid.disconnect(addedId);
    addedId = 0;
    grid = null;
    for (const ids of tracked.values()) {
        for (const [object, id] of ids)
            object.disconnect(id);
    }
    tracked.clear();
    play = null;
}
