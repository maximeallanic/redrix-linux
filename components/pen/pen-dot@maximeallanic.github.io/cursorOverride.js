// Takes precedence on Meta.Backend::override-cursor, the only hook Mutter 50/51 offers on the cursor it draws for a
// sprite (pointer or tablet tool) when that cursor comes from the theme.
//
// Why a plain connect() is not enough: the signal is declared with g_signal_accumulator_first_wins (mutter
// src/backends/meta-backend.c), so only the FIRST connected handler is ever run, and MetaCompositor connects its own
// when it is constructed (src/compositor/compositor.c, on_override_cursor: the "busy" cursor of application startup),
// long before any extension. A handler connected afterwards is never called.
//
// There is no other API (no parameterless priority, no per-sprite cursor setter, Clutter.Sprite.invalidate_cursor is
// private). So, with public GObject calls only: the handler that was first is blocked for as long as this one is
// connected, and consulted by a nested emission whenever this one has nothing to say. Its answers are unchanged.
//
// Only GObject is imported: `backend` is any object with that signal, `cursors` gives the two values of
// Clutter.CursorType used here ({NONE, INHERIT}), so that tests/test_cursor_override.js runs under plain gjs.
import GObject from 'gi://GObject';

export const SIGNAL = 'override-cursor';

export class CursorOverride {
    // wantsHidden(): true when the cursor must not be drawn for the emission in progress.
    constructor(backend, cursors, wantsHidden) {
        this._backend = backend;
        this._cursors = cursors;
        this._wantsHidden = wantsHidden;
        this._id = 0;
        this._shadowed = 0;
        this._probing = false;
        this._probed = false;
    }

    // Returns true when this handler is the one Mutter consults. False: another handler still wins (the signal no
    // longer behaves as described above) and the cursor cannot be hidden; the caller must report it.
    enable() {
        // The first handler connected, the only one that runs: 0 when there is none.
        this._shadowed = Number(GObject.signal_handler_find(this._backend, {signalId: SIGNAL}));
        if (this._shadowed)
            GObject.signal_handler_block(this._backend, this._shadowed);
        this._id = this._backend.connect(SIGNAL, () => this._answer());
        return this._probe();
    }

    disable() {
        if (this._id)
            this._backend.disconnect(this._id);
        this._id = 0;
        if (this._shadowedIsConnected())
            GObject.signal_handler_unblock(this._backend, this._shadowed);
        this._shadowed = 0;
    }

    get shadowsAnotherHandler() {
        return this._shadowed !== 0;
    }

    _shadowedIsConnected() {
        return this._shadowed !== 0 && GObject.signal_handler_is_connected(this._backend, this._shadowed);
    }

    // An emission of our own, to check that it reaches this handler.
    _probe() {
        this._probing = true;
        this._probed = false;
        try {
            this._backend.emit(SIGNAL);
        } finally {
            this._probing = false;
        }
        return this._probed;
    }

    _answer() {
        if (this._probing) {
            this._probed = true;
            return this._cursors.INHERIT;
        }
        if (this._wantsHidden())
            return this._cursors.NONE;
        return this._chain();
    }

    // What the shadowed handler answers: unblocked, it is first again and wins the nested emission.
    _chain() {
        if (!this._shadowedIsConnected())
            return this._cursors.INHERIT;
        GObject.signal_handler_unblock(this._backend, this._shadowed);
        try {
            return this._backend.emit(SIGNAL);
        } finally {
            GObject.signal_handler_block(this._backend, this._shadowed);
        }
    }
}
