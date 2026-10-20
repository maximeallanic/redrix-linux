// Fade to black on shutdown/reboot. logind emits PrepareForShutdown(true) before it stops gdm; the Shell is killed
// shortly after, then plymouth-{poweroff,reboot}.service draws the redrix-shutdown theme, which starts from black.
import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import St from 'gi://St';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

const FADE_MS = 300;

export default class FadeToBlack extends Extension {
    enable() {
        this._veil = null;
        this._subscription = Gio.DBus.system.signal_subscribe(
            'org.freedesktop.login1', 'org.freedesktop.login1.Manager', 'PrepareForShutdown',
            '/org/freedesktop/login1', null, Gio.DBusSignalFlags.NONE,
            (_c, _s, _p, _i, _n, params) => {
                const [shuttingDown] = params.deep_unpack();
                if (shuttingDown)
                    this._fadeOut();
                else
                    this._cancel();
            });
    }

    disable() {
        Gio.DBus.system.signal_unsubscribe(this._subscription);
        this._subscription = null;
        this._cancel();
    }

    _fadeOut() {
        if (this._veil)
            return;
        // Top chrome sits above the panel, the overview and modal dialogs.
        this._veil = new St.Widget({
            style: 'background-color: black;',
            reactive: true, // swallows input while the system goes down
            opacity: 0,
        });
        this._veil.set_size(global.stage.width, global.stage.height);
        Main.layoutManager.addTopChrome(this._veil);
        const animate = St.Settings.get().enable_animations;
        this._veil.ease({
            opacity: 255,
            duration: animate ? FADE_MS : 0,
            mode: Clutter.AnimationMode.EASE_OUT_QUAD,
        });
    }

    // PrepareForShutdown(false): shutdown cancelled (e.g. an inhibitor said no).
    _cancel() {
        if (!this._veil)
            return;
        Main.layoutManager.removeChrome(this._veil);
        this._veil.destroy();
        this._veil = null;
    }
}
