// Which kind of pointing device an input event comes from. Pure logic: no GObject import, so that it can be unit-tested
// with plain gjs (tests/test_devices.js); the caller passes Clutter.InputDeviceType.

// A stylus: the cursor is replaced by the dot.
export const STYLUS = 'stylus';
// Another pointing device (mouse, touchpad, finger, tablet puck): the cursor is left to Mutter.
export const OTHER = 'other';

// classify(deviceType, hasTool, types) -> STYLUS, OTHER, or null when the device says nothing about pointing
// (keyboard, tablet pad, unknown or missing device).
//   deviceType: Clutter.InputDeviceType of the event's source device (undefined or null: no device)
//   hasTool:    the event carries a tablet tool (Clutter.Event.get_device_tool() is not null)
//   types:      Clutter.InputDeviceType
// libinput reports a pen as a tool on a TABLET_DEVICE; PEN_DEVICE and ERASER_DEVICE are what other backends call the
// same thing. A tablet puck (CURSOR_DEVICE) is used like a mouse and keeps its cursor.
export function classify(deviceType, hasTool, types) {
    if (deviceType === types.CURSOR_DEVICE)
        return OTHER;
    if (hasTool)
        return STYLUS;
    switch (deviceType) {
    case types.TABLET_DEVICE:
    case types.PEN_DEVICE:
    case types.ERASER_DEVICE:
        return STYLUS;
    case types.POINTER_DEVICE:
    case types.TOUCHPAD_DEVICE:
    case types.TOUCHSCREEN_DEVICE:
        return OTHER;
    default:
        return null;
    }
}

// Remembers the last pointing device kind seen: update(kind) ignores null (a key press while the pen hovers does not
// make the pen stop being the pointing device in use). Returns true when the stylus is the one in use.
export class LastPointing {
    constructor() {
        this._kind = null;
    }

    update(kind) {
        if (kind !== null && kind !== undefined)
            this._kind = kind;
        return this.isStylus;
    }

    get isStylus() {
        return this._kind === STYLUS;
    }
}
