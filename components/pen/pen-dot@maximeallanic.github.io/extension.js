// Pen Dot: under the stylus, a small dot instead of the mouse arrow.
//
// Mutter gives every tablet tool its own sprite and draws for it the cursor of the actor under it, like for the
// mouse: the theme's arrow over the Shell and the desktop, the shape or the image the application asks for over a
// window. No setting hides it and Meta.CursorTracker.inhibit_cursor_visibility() only applies to the mouse pointer.
// The one hook is Meta.Backend::override-cursor, consulted for every cursor taken from the theme: while the stylus is
// the pointing device in use it is answered NONE, and a dot is drawn at the tip instead. cursorOverride.js explains
// why that signal needs more than a connect().
//
// Not covered, because Mutter has no hook there: an application that gives the tablet tool a cursor IMAGE of its own
// (zwp_tablet_tool_v2.set_cursor with a surface: GTK 3, XWayland) keeps it, next to the dot. Applications that ask
// for a cursor SHAPE (cursor-shape-v1: GTK 4) get the dot alone.
//
// Diagnostic, at most three lines per session in the journal (journalctl --user -b -o cat | grep 'pen-dot:'):
//   enabled ...                     the hook is installed ("pen-dot: error: ..." when Mutter does not consult it)
//   first stylus event ...          stylus events reach the stage and are recognised
//   first cursor hidden ...         Mutter consulted the hook for the stylus
import Clutter from 'gi://Clutter';
import St from 'gi://St';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import {CursorOverride} from './cursorOverride.js';
import {classify, LastPointing, STYLUS} from './devices.js';

const DIAMETER = 6; // logical pixels
const MOVES_DOT = [
    Clutter.EventType.MOTION, Clutter.EventType.PROXIMITY_IN,
    Clutter.EventType.BUTTON_PRESS, Clutter.EventType.BUTTON_RELEASE,
];

function deviceKind(device, hasTool) {
    return classify(device?.get_device_type(), hasTool, Clutter.InputDeviceType);
}

function eventKind(event) {
    return deviceKind(event.get_source_device(), event.get_device_tool() !== null);
}

export default class PenDot extends Extension {
    enable() {
        this._pointing = new LastPointing();
        this._loggedEvent = false;
        this._loggedHidden = false;
        this._dot = new St.Widget({
            style: 'background-color: rgba(0, 0, 0, 0.8); border: 1px solid rgba(255, 255, 255, 0.9);' +
                `border-radius: ${DIAMETER}px;`,
            reactive: false,
            visible: false,
        });
        global.stage.add_child(this._dot);

        this._override = new CursorOverride(global.backend, Clutter.CursorType, () => this._hidesCursor());
        if (this._override.enable()) {
            console.log(`pen-dot: enabled (${this.metadata.uuid}), override-cursor hook consulted ` +
                `(shadowing Mutter's handler: ${this._override.shadowsAnotherHandler ? 'yes' : 'no'})`);
        } else {
            console.error('pen-dot: error: enabled, but Meta.Backend::override-cursor does not consult this extension: ' +
                'the cursor under the stylus cannot be hidden on this Mutter (the dot is still drawn)');
        }
        this._capturedId = global.stage.connect('captured-event', (_stage, event) => this._onEvent(event));
    }

    disable() {
        global.stage.disconnect(this._capturedId);
        this._capturedId = 0;
        this._override.disable();
        this._override = null;
        this._dot.destroy();
        this._dot = null;
        this._pointing = null;
    }

    // Asked by Mutter each time it takes a cursor from the theme, for any sprite. The device that decides is, in
    // order: the one of the event being processed (a pen entering proximity is picked, and its cursor chosen, before
    // the stage sees the event); else the last device Mutter has seen (it re-evaluates the mouse cursor when the mouse
    // comes back, before that event is processed); else the last pointing device this extension has seen (a key
    // pressed while the pen hovers is the last device, and says nothing).
    // Meta.Backend.get_last_input_device() is new in Mutter 51; without it the first and last rules remain.
    _hidesCursor() {
        const event = Clutter.get_current_event();
        const kind = (event ? eventKind(event) : null) ?? deviceKind(global.backend.get_last_input_device?.(), false);
        const hidden = this._pointing.update(kind);
        if (hidden && !this._loggedHidden) {
            this._loggedHidden = true;
            console.log('pen-dot: first cursor hidden for the stylus (Mutter consulted the hook)');
        }
        return hidden;
    }

    _onEvent(event) {
        const kind = eventKind(event);
        if (kind === null)
            return Clutter.EVENT_PROPAGATE;
        this._pointing.update(kind);

        const type = event.type();
        if (kind !== STYLUS || type === Clutter.EventType.PROXIMITY_OUT) {
            this._dot.hide();
        } else if (MOVES_DOT.includes(type)) {
            this._logFirstStylusEvent(event);
            const size = DIAMETER * St.ThemeContext.get_for_stage(global.stage).scale_factor;
            const [x, y] = event.get_coords();
            this._dot.set_size(size, size);
            this._dot.set_position(Math.round(x - size / 2), Math.round(y - size / 2));
            global.stage.set_child_above_sibling(this._dot, null);
            this._dot.show();
        }
        return Clutter.EVENT_PROPAGATE;
    }

    _logFirstStylusEvent(event) {
        if (this._loggedEvent)
            return;
        this._loggedEvent = true;
        const device = event.get_source_device();
        console.log(`pen-dot: first stylus event (event type ${event.type()}, ` +
            `device type ${device?.get_device_type() ?? 'none'}, tool: ${event.get_device_tool() ? 'yes' : 'no'}), ` +
            'dot shown');
    }
}
