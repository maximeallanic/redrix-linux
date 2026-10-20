// D-Bus client of the haptic-bridge. Never blocking: asynchronous proxy, calls with a short timeout and
// without auto-start; if the bridge is absent, play() does nothing.
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';

const BUS_NAME = 'io.github.maximeallanic.Haptic';
const OBJ_PATH = '/io/github/maximeallanic/Haptic';
const IFACE = 'io.github.maximeallanic.Haptic';

export class HapticClient {
    constructor() {
        this._proxy = null;
        this._active = null;
        this._ownerId = 0;
        this._cancel = new Gio.Cancellable();
        Gio.DBusProxy.new_for_bus(
            Gio.BusType.SESSION,
            Gio.DBusProxyFlags.DO_NOT_AUTO_START | Gio.DBusProxyFlags.DO_NOT_LOAD_PROPERTIES |
                Gio.DBusProxyFlags.DO_NOT_CONNECT_SIGNALS,
            null, BUS_NAME, OBJ_PATH, IFACE, this._cancel,
            (_o, res) => {
                try {
                    this._proxy = Gio.DBusProxy.new_for_bus_finish(res);
                    // A restarted bridge starts on the mouse: tell it again which device is in use.
                    this._ownerId = this._proxy.connect('notify::g-name-owner', () => this._sendActive());
                    this._sendActive();
                } catch (e) {
                    if (!e.matches(Gio.IOErrorEnum, Gio.IOErrorEnum.CANCELLED))
                        console.warn(`haptic-events: bridge unreachable (${e.message})`);
                }
            });
    }

    play(event) {
        if (!this._proxy)
            return;
        this._proxy.call('Play', new GLib.Variant('(s)', [event]),
            Gio.DBusCallFlags.NO_AUTO_START, 200, null, () => {});
    }

    /** 'mouse' or 'touchpad': the device that should vibrate. Sent only when it changes. */
    setActive(kind) {
        if (kind === this._active)
            return;
        this._active = kind;
        this._sendActive();
    }

    _sendActive() {
        if (!this._proxy || !this._active || !this._proxy.g_name_owner)
            return;
        this._proxy.call('SetActive', new GLib.Variant('(s)', [this._active]),
            Gio.DBusCallFlags.NO_AUTO_START, 200, null, () => {});
    }

    destroy() {
        this._cancel.cancel();
        if (this._ownerId)
            this._proxy?.disconnect(this._ownerId);
        this._ownerId = 0;
        this._proxy = null;
    }
}
