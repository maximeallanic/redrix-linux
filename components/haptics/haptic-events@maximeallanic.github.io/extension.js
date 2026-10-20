import Meta from 'gi://Meta';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import {HapticClient} from './hapticClient.js';
import Clutter from 'gi://Clutter';
import {sizeChangeEvent, osdEvent, buttonAction, pointerKind} from './events.js';
import * as Toggles from './toggles.js';

const CHANGES = {
    [Meta.SizeChange.MAXIMIZE]: 'maximize',
    [Meta.SizeChange.UNMAXIMIZE]: 'unmaximize',
    [Meta.SizeChange.FULLSCREEN]: 'fullscreen',
    [Meta.SizeChange.UNFULLSCREEN]: 'unfullscreen',
    [Meta.SizeChange.MONITOR_MOVE]: 'monitor-move',
};

export default class HapticEvents extends Extension {
    enable() {
        this._client = new HapticClient();
        this._signals = [];
        this._connect(global.workspace_manager, 'active-workspace-changed', () => this._play('workspace'));
        this._connect(Main.overview, 'showing', () => this._play('overview'));
        this._connect(Main.overview, 'hiding', () => this._play('overview'));
        this._connect(global.window_manager, 'size-change', (_wm, actor, change) => {
            const w = actor.meta_window;
            const ev = sizeChangeEvent(CHANGES[change], w.maximized_horizontally, w.maximized_vertically);
            if (ev)
                this._play(ev);
        });
        this._connect(global.stage, 'captured-event', (_s, event) => this._onCapturedEvent(event));
        this._connect(Main.screenShield, 'locked-changed', () => {
            if (Main.screenShield.locked)
                this._play('lock');
        });
        this._connect(Main.screenshotUI, 'screenshot-taken', () => this._play('screenshot'));
        // The OSD emits no signal: show() and showAll() are wrapped (the volume goes through showAll) and restored
        // in disable().
        const self = this;
        this._osdShow = Main.osdWindowManager.show;
        this._osdShowAll = Main.osdWindowManager.showAll;
        Main.osdWindowManager.show = function (icon, label, levels) {
            self._osd(icon, levels ? Object.values(levels).find(l => l) : null);
            return self._osdShow.call(this, icon, label, levels);
        };
        Main.osdWindowManager.showAll = function (icon, label, level, maxLevel) {
            self._osd(icon, {level, maxLevel});
            return self._osdShowAll.call(this, icon, label, level, maxLevel);
        };
        Toggles.enable(event => this._play(event));
    }

    disable() {
        Toggles.disable();
        for (const [obj, id] of this._signals)
            obj.disconnect(id);
        this._signals = [];
        if (this._osdShow) {
            Main.osdWindowManager.show = this._osdShow;
            Main.osdWindowManager.showAll = this._osdShowAll;
            this._osdShow = null;
            this._osdShowAll = null;
        }
        this._client?.destroy();
        this._client = null;
    }

    _connect(obj, signal, cb) {
        this._signals.push([obj, obj.connect(signal, cb)]);
    }

    _onCapturedEvent(event) {
        const source = event.get_source_device();
        const kind = pointerKind({
            deviceType: source?.get_device_type(),
            eventType: event.type(),
            synthetic: (event.get_flags() & Clutter.EventFlags.FLAG_SYNTHETIC) !== 0,
            deviceNode: source?.get_device_node() ?? null,
        }, Clutter);
        if (kind)
            this._client?.setActive(kind);
        if (event.type() !== Clutter.EventType.BUTTON_PRESS)
            return Clutter.EVENT_PROPAGATE;
        const r = buttonAction(event.get_button(), Main.overview.visible);
        if (!r)
            return Clutter.EVENT_PROPAGATE;
        if (r.action) {
            const dir = r.action === 'workspace-prev' ? Meta.MotionDirection.LEFT : Meta.MotionDirection.RIGHT;
            const ws = global.workspace_manager.get_active_workspace().get_neighbor(dir);
            ws.activate(global.get_current_time());   // the 'workspace' event does the vibration
        } else {
            this._play('button');
        }
        return r.consumed ? Clutter.EVENT_STOP : Clutter.EVENT_PROPAGATE;
    }

    _osd(icon, level) {
        const name = icon?.get_names?.()?.[0] ?? '';
        const ev = osdEvent(name, level?.level, level?.maxLevel);
        if (ev)
            this._play(ev);
    }

    _play(event) {
        this._client?.play(event);
    }
}
