// Run: gjs -m post-install/peripheriques/pen-dot/tests/test_devices.js
// Device classification of pen-dot. Touches no session bus and no Shell: Clutter.InputDeviceType is replaced by a
// table of distinct values (the logic never depends on the numbers).
import System from 'system';
import {classify, LastPointing, STYLUS, OTHER} from '../devices.js';

const T = {
    POINTER_DEVICE: 0, KEYBOARD_DEVICE: 1, EXTENSION_DEVICE: 2, JOYSTICK_DEVICE: 3, TABLET_DEVICE: 4,
    TOUCHPAD_DEVICE: 5, TOUCHSCREEN_DEVICE: 6, PEN_DEVICE: 7, ERASER_DEVICE: 8, CURSOR_DEVICE: 9, PAD_DEVICE: 10,
};

let failures = 0;
function equal(got, expected, name) {
    if (got !== expected) {
        failures++;
        print(`FAIL ${name}: got ${got}, expected ${expected}`);
    }
}

// The machine's pen: libinput tablet capability, every event carries a tool.
equal(classify(T.TABLET_DEVICE, true, T), STYLUS, 'tablet device with a tool');
equal(classify(T.TABLET_DEVICE, false, T), STYLUS, 'tablet device, event without tool (proximity out)');
equal(classify(T.PEN_DEVICE, false, T), STYLUS, 'pen device');
equal(classify(T.ERASER_DEVICE, false, T), STYLUS, 'eraser device');
equal(classify(undefined, true, T), STYLUS, 'tool without source device');
equal(classify(T.CURSOR_DEVICE, true, T), OTHER, 'tablet puck keeps its cursor');
equal(classify(T.POINTER_DEVICE, false, T), OTHER, 'mouse');
equal(classify(T.TOUCHPAD_DEVICE, false, T), OTHER, 'touchpad');
equal(classify(T.TOUCHSCREEN_DEVICE, false, T), OTHER, 'finger');
equal(classify(T.KEYBOARD_DEVICE, false, T), null, 'keyboard says nothing');
equal(classify(T.PAD_DEVICE, false, T), null, 'tablet pad says nothing');
equal(classify(undefined, false, T), null, 'no device');
equal(classify(null, false, T), null, 'null device type');

const last = new LastPointing();
equal(last.isStylus, false, 'nothing seen yet');
equal(last.update(STYLUS), true, 'stylus seen');
equal(last.update(null), true, 'a key press while the pen hovers changes nothing');
equal(last.update(undefined), true, 'missing kind changes nothing');
equal(last.update(OTHER), false, 'mouse takes over');
equal(last.update(null), false, 'still the mouse');
equal(last.update(STYLUS), true, 'pen again');

print(failures ? `${failures} failure(s)` : 'test_devices: ok');
System.exit(failures ? 1 : 0);
