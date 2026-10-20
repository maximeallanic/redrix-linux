// The prompt's "(or place finger on reader)" hint, silenced at its source. Stock Shell 51
// (gdm/authServicesLegacy.js, _handleOnInfo) never shows pam_fprintd's info messages: while fingerprint is not the
// selected mechanism, it turns each one into that hint. With the reader armed from the clock the hint is redundant.
// The queue entry is kept, without text, so a fingerprint error is still cleared on the next scan exactly when stock
// clears it. Matched by service name, never by text, so it holds in every language. Messages of the selected service
// and every error are left to the original handler.

// Returns a replacement for AuthServicesLegacy.prototype._handleOnInfo wrapping `onInfo`, the original.
export function silenceReaderHint(onInfo, fingerprintService, noneType) {
    return function (serviceName, info) {
        if (serviceName === fingerprintService &&
            serviceName !== this._selectedMechanism?.serviceName &&
            this._enabledMechanisms.some(m => m.serviceName === serviceName)) {
            this.emit('queue-message', {serviceName, message: null, messageType: noneType});
            return;
        }
        onInfo.call(this, serviceName, info);
    };
}
