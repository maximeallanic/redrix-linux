// Run: gjs -m components/haptics/haptic-events@maximeallanic.github.io/tests/test_events.js
import {sizeChangeEvent, osdEvent, buttonAction, pointerKind, toggleEvent} from '../events.js';

let failures = 0;
function equal(got, expected, name) {
    if (got !== expected) {
        failures++;
        print(`FAIL ${name}: got ${got}, expected ${expected}`);
    }
}

equal(sizeChangeEvent('maximize', true, true), 'maximize', 'maximized both ways');
equal(sizeChangeEvent('maximize', false, true), 'edge', 'vertical tiling is an edge');
equal(sizeChangeEvent('maximize', true, false), 'edge', 'horizontal tiling is an edge');
equal(sizeChangeEvent('unmaximize', false, false), 'unmaximize', 'restore');
equal(sizeChangeEvent('fullscreen', false, false), 'maximize', 'fullscreen counts as maximize');
equal(sizeChangeEvent('unfullscreen', false, false), 'unmaximize', 'leaving fullscreen');
equal(sizeChangeEvent('monitor-move', true, true), null, 'monitor move ignored');
equal(sizeChangeEvent('other', true, true), null, 'unknown change ignored');

equal(osdEvent('audio-volume-medium-symbolic', 0.5, -1), 'volume', 'volume step');
equal(osdEvent('audio-volume-muted-symbolic', 0, -1), 'volume-stop', 'volume at zero');
equal(osdEvent('audio-volume-high-symbolic', 1, -1), 'volume-stop', 'volume at maximum');
equal(osdEvent('audio-volume-overamplified-symbolic', 1.2, 1.5), 'volume', 'over-amplification below its ceiling');
equal(osdEvent('audio-volume-overamplified-symbolic', 1.5, 1.5), 'volume-stop', 'over-amplification ceiling');
equal(osdEvent('display-brightness-symbolic', 0.5, -1), null, 'brightness ignored');
equal(osdEvent('', undefined, undefined), null, 'OSD without icon');

equal(buttonAction(1, true), null, 'primary button ignored');
equal(buttonAction(8, true).action, 'workspace-prev', 'back in the overview');
equal(buttonAction(9, true).action, 'workspace-next', 'forward in the overview');
equal(buttonAction(8, true).consumed, true, 'back consumed in the overview');
equal(buttonAction(8, false).consumed, false, 'back passed on outside the overview');
equal(buttonAction(8, false).action, null, 'back has no action outside the overview');
equal(buttonAction(10, false).consumed, false, 'button 10 passed on');

// Same names as Clutter.InputDeviceType and Clutter.EventType, values made up: pointerKind only compares them.
const C = {
    InputDeviceType: {POINTER_DEVICE: 0, KEYBOARD_DEVICE: 1, TOUCHPAD_DEVICE: 4, TOUCHSCREEN_DEVICE: 5, TABLET_DEVICE: 6},
    EventType: {MOTION: 3, ENTER: 4, LEAVE: 5, BUTTON_PRESS: 6, BUTTON_RELEASE: 7, SCROLL: 8,
        TOUCHPAD_PINCH: 13, TOUCHPAD_SWIPE: 14, TOUCHPAD_HOLD: 15},
};
const T = C.InputDeviceType, E = C.EventType;
const NODE = '/dev/input/event3';
const ev = (deviceType, eventType = E.MOTION, synthetic = false, deviceNode = NODE) =>
    ({deviceType, eventType, synthetic, deviceNode});
equal(pointerKind(ev(T.POINTER_DEVICE), C), 'mouse', 'pointer device is the mouse');
equal(pointerKind(ev(T.TOUCHPAD_DEVICE), C), 'touchpad', 'touchpad device');
equal(pointerKind(ev(T.KEYBOARD_DEVICE), C), null, 'keyboard ignored');
equal(pointerKind(ev(T.TOUCHSCREEN_DEVICE), C), null, 'touchscreen ignored');
equal(pointerKind(ev(T.TABLET_DEVICE), C), null, 'stylus ignored');
equal(pointerKind(ev(undefined), C), null, 'event without source device');
equal(pointerKind(ev(T.TOUCHPAD_DEVICE, E.TOUCHPAD_SWIPE), C), 'touchpad', 'touchpad swipe gesture');
equal(pointerKind(ev(T.TOUCHPAD_DEVICE, E.BUTTON_PRESS), C), 'touchpad', 'touchpad click');
equal(pointerKind(ev(T.POINTER_DEVICE, E.SCROLL), C), 'mouse', 'mouse wheel');
// The Shell re-picks the actor under a still cursor after every animation and reports the resulting crossing
// events on the logical pointer, a POINTER_DEVICE: they must not take the vibration away from the touchpad.
equal(pointerKind(ev(T.POINTER_DEVICE, E.ENTER), C), null, 'crossing enter ignored');
equal(pointerKind(ev(T.POINTER_DEVICE, E.LEAVE), C), null, 'crossing leave ignored');
equal(pointerKind(ev(T.POINTER_DEVICE, E.MOTION, true), C), null, 'synthetic motion ignored');
// During a window drag Mutter emits plain motion and button events on the logical pointer, which has no
// device node: with the mouse away they must not steal the vibration from the touchpad doing the drag.
equal(pointerKind(ev(T.POINTER_DEVICE, E.MOTION, false, null), C), null, 'logical pointer motion ignored');
equal(pointerKind(ev(T.POINTER_DEVICE, E.BUTTON_PRESS, false, null), C), null, 'logical pointer button ignored');
equal(pointerKind(ev(T.POINTER_DEVICE, E.MOTION, false, '/dev/input/event28'), C), 'mouse', 'any pointer with a node is a mouse');

equal(toggleEvent(false), 'toggle-on', 'a tile that was off is switched on');
equal(toggleEvent(true), 'toggle-off', 'a tile that was on is switched off');

if (failures === 0)
    print('OK');
else
    imports.system.exit(1);
