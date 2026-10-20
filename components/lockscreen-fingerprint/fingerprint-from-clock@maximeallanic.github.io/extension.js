// Starts unlock verification while the lock screen still shows the clock, so a finger on the reader unlocks
// without pressing a key first (upstream gnome-shell#3048). Stock UnlockDialog only creates its AuthPrompt, and
// thus starts fprintd, when the prompt page is shown, and destroys it again when the clock comes back.
// Here the prompt is kept alive, hidden, under the clock; key focus stays on the dialog so the first key typed
// still raises the prompt and lands in the entry, exactly as before.
// Since the reader is already armed from the clock, the prompt's "(or place finger on reader)" hint is redundant:
// it is silenced at its source (fingerprint-hint.js).
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import {AuthServicesLegacy} from 'resource:///org/gnome/shell/gdm/authServicesLegacy.js';
import {Role} from 'resource:///org/gnome/shell/gdm/authServices.js';
import {MessageType} from 'resource:///org/gnome/shell/gdm/userVerifier.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {UnlockDialog} from 'resource:///org/gnome/shell/ui/unlockDialog.js';

import {silenceReaderHint} from './fingerprint-hint.js';

const FINGERPRINT_SERVICE = AuthServicesLegacy.RoleToService[Role.FINGERPRINT];

function keepFocusOffHiddenPrompt(dialog) {
    const focus = global.stage.key_focus;
    if (focus === null || dialog._authPrompt?.contains(focus) || focus === dialog._otherUserButton)
        dialog.grab_key_focus();
}

function startOnClock(dialog) {
    if (dialog._activePage !== dialog._clock)
        return;

    // Creates the prompt, or restarts verification after a failure or a cancel, and begins it.
    dialog._ensureAuthPrompt();

    const prompt = dialog._authPrompt;
    if (!prompt._fingerprintFromClockId) {
        // The password service asks its question asynchronously and AuthPrompt then focuses its entry.
        prompt._fingerprintFromClockId = prompt.connect('prompted', () => {
            if (dialog._activePage === dialog._clock)
                keepFocusOffHiddenPrompt(dialog);
        });
    }
    keepFocusOffHiddenPrompt(dialog);
}

// Undoes startOnClock on a dialog that is still open, once the stock prototype is back: the 'prompted' handler
// goes, and a prompt kept hidden under the clock is destroyed as stock Shell would have, disarming the reader.
function restoreStockDialog(dialog) {
    const prompt = dialog._authPrompt;
    if (prompt?._fingerprintFromClockId) {
        prompt.disconnect(prompt._fingerprintFromClockId);
        delete prompt._fingerprintFromClockId;
    }
    if (dialog._activePage === dialog._clock)
        dialog._maybeDestroyAuthPrompt();
}

export default class FingerprintFromClockExtension extends Extension {
    enable() {
        const proto = UnlockDialog.prototype;
        this._originals = {open: proto.open, _maybeDestroyAuthPrompt: proto._maybeDestroyAuthPrompt};
        const {open, _maybeDestroyAuthPrompt: maybeDestroy} = this._originals;
        this._originalOnInfo = AuthServicesLegacy.prototype._handleOnInfo;

        proto.open = function (...args) {
            const result = open.apply(this, args);
            startOnClock(this);
            return result;
        };
        // Called when the clock page comes back (crossfade done, swipe cancelled): keep the prompt instead.
        proto._maybeDestroyAuthPrompt = function () {
            if (this._activePage === this._clock)
                startOnClock(this);
            else
                maybeDestroy.call(this);
        };
        AuthServicesLegacy.prototype._handleOnInfo =
            silenceReaderHint(this._originalOnInfo, FINGERPRINT_SERVICE, MessageType.NONE);
    }

    disable() {
        Object.assign(UnlockDialog.prototype, this._originals);
        this._originals = null;
        const dialog = Main.screenShield?._dialog;
        if (dialog instanceof UnlockDialog)
            restoreStockDialog(dialog);
        AuthServicesLegacy.prototype._handleOnInfo = this._originalOnInfo;
        this._originalOnInfo = null;
    }
}
