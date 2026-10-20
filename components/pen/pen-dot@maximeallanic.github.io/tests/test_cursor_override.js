// Run: gjs -m post-install/peripheriques/pen-dot/tests/test_cursor_override.js
// The override-cursor takeover of pen-dot against a stand-in for Meta.Backend: a GObject with the same signal
// declaration (no parameter, a return value, g_signal_accumulator_first_wins) and, connected first, a handler playing
// MetaCompositor's. Touches no session bus and no Shell.
import GObject from 'gi://GObject';
import System from 'system';
import {CursorOverride, SIGNAL} from '../cursorOverride.js';

const CURSORS = {INHERIT: 0, NONE: 1};
const WAIT = 7;   // any other cursor type: what the compositor answers during an application startup

const Backend = GObject.registerClass({
    Signals: {[SIGNAL]: {return_type: GObject.TYPE_INT, accumulator: GObject.AccumulatorType.FIRST_WINS}},
}, class Backend extends GObject.Object {});

let failures = 0;
function equal(got, expected, name) {
    if (got !== expected) {
        failures++;
        print(`FAIL ${name}: got ${got}, expected ${expected}`);
    }
}

// A backend with the compositor's handler connected first, as in a running Shell.
function shell() {
    const backend = new Backend();
    const compositor = {cursor: CURSORS.INHERIT, calls: 0};
    compositor.id = backend.connect(SIGNAL, () => {
        compositor.calls++;
        return compositor.cursor;
    });
    return {backend, compositor};
}

// 1. What pen-dot did until 2026-10-12: a plain connect(). Never consulted: this is why the arrow stayed.
{
    const {backend, compositor} = shell();
    let calls = 0;
    backend.connect(SIGNAL, () => {
        calls++;
        return CURSORS.NONE;
    });
    equal(backend.emit(SIGNAL), CURSORS.INHERIT, 'plain connect: the compositor answers');
    equal(calls, 0, 'plain connect: the second handler is never run');
    equal(compositor.calls, 1, 'plain connect: the compositor handler ran');
}

// 2. The takeover: consulted, hides on demand, otherwise gives the compositor's answer.
{
    const {backend, compositor} = shell();
    let hidden = false;
    let asked = 0;
    const override = new CursorOverride(backend, CURSORS, () => {
        asked++;
        return hidden;
    });
    equal(override.enable(), true, 'takeover: enable() reports it is consulted');
    equal(override.shadowsAnotherHandler, true, 'takeover: the compositor handler is shadowed');
    equal(asked, 0, 'takeover: the probe emission does not ask wantsHidden');
    equal(compositor.calls, 0, 'takeover: the probe emission does not reach the compositor');

    equal(backend.emit(SIGNAL), CURSORS.INHERIT, 'takeover: nothing to hide, compositor has nothing: inherit');
    equal(compositor.calls, 1, 'takeover: the compositor was consulted');
    compositor.cursor = WAIT;
    equal(backend.emit(SIGNAL), WAIT, 'takeover: the compositor busy cursor goes through');

    hidden = true;
    const before = compositor.calls;
    equal(backend.emit(SIGNAL), CURSORS.NONE, 'takeover: hidden wins over the compositor cursor');
    equal(compositor.calls, before, 'takeover: the compositor is not consulted when hidden');

    hidden = false;
    equal(backend.emit(SIGNAL), WAIT, 'takeover: back to the compositor answer');
    equal(asked, 4, 'takeover: wantsHidden asked once per emission');

    override.disable();
    asked = 0;
    equal(backend.emit(SIGNAL), WAIT, 'disabled: the compositor answers again');
    equal(asked, 0, 'disabled: wantsHidden is no longer asked');
    equal(Number(GObject.signal_handler_find(backend, {signalId: SIGNAL})), compositor.id,
        'disabled: the compositor handler is first and connected');

    // Enabled, disabled and enabled again (lock, unlock): no block is left behind.
    equal(override.enable(), true, 're-enabled: consulted');
    hidden = true;
    equal(backend.emit(SIGNAL), CURSORS.NONE, 're-enabled: hides');
    override.disable();
    equal(backend.emit(SIGNAL), WAIT, 're-disabled: the compositor answers');
}

// 3. No handler before ours (a Mutter that would stop connecting one): still works, inherits when not hidden.
{
    const backend = new Backend();
    let hidden = false;
    const override = new CursorOverride(backend, CURSORS, () => hidden);
    equal(override.enable(), true, 'alone: consulted');
    equal(override.shadowsAnotherHandler, false, 'alone: nothing shadowed');
    equal(backend.emit(SIGNAL), CURSORS.INHERIT, 'alone: inherit');
    hidden = true;
    equal(backend.emit(SIGNAL), CURSORS.NONE, 'alone: hides');
    override.disable();
}

// 4. The shadowed handler goes away while we are enabled (compositor disposed at shutdown): no warning, inherit.
{
    const {backend, compositor} = shell();
    const override = new CursorOverride(backend, CURSORS, () => false);
    override.enable();
    backend.disconnect(compositor.id);
    equal(backend.emit(SIGNAL), CURSORS.INHERIT, 'shadowed handler gone: inherit');
    override.disable();
}

print(failures ? `${failures} failure(s)` : 'test_cursor_override: ok');
System.exit(failures ? 1 : 0);
