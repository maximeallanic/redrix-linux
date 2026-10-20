// Pure functions, no Shell dependency: testable with plain gjs (tests/test_events.js).

/** Window size change (Mutter's size-change signal) -> haptic event name, or null. */
export function sizeChangeEvent(change, maximizedH, maximizedV) {
    switch (change) {
    case 'maximize':
        return maximizedH && maximizedV ? 'maximize' : 'edge';
    case 'fullscreen':
        return 'maximize';
    case 'unmaximize':
    case 'unfullscreen':
        return 'unmaximize';
    default:
        return null;
    }
}

/** Shell OSD -> 'volume', 'volume-stop' (at an end stop), or null when it is not the volume. */
export function osdEvent(iconName, level, maxLevel) {
    if (typeof iconName !== 'string' || !iconName.startsWith('audio-volume'))
        return null;
    if (typeof level !== 'number')
        return 'volume';
    const ceiling = typeof maxLevel === 'number' && maxLevel > 0 ? maxLevel : 1;
    return level <= 0 || level >= ceiling ? 'volume-stop' : 'volume';
}

/**
 * Extra mouse buttons (Clutter numbers: 8 back, 9 forward, 10+ others). Returns {action, consumed}, or null when
 * the button is not an extra one. In the overview, back/forward switch workspaces (event consumed); elsewhere the
 * click stays with the application (browser: previous/next page) and the mouse only vibrates.
 */
export function buttonAction(button, overviewVisible) {
    if (!Number.isInteger(button) || button < 8)
        return null;
    if (overviewVisible && button === 8)
        return {action: 'workspace-prev', consumed: true};
    if (overviewVisible && button === 9)
        return {action: 'workspace-next', consumed: true};
    return {action: null, consumed: false};
}

/**
 * Input event -> the haptic target that should answer ('mouse' or 'touchpad'), or null when the event says
 * nothing about which device the hand is on: devices that cannot vibrate (keyboard, touchscreen, stylus), and
 * events the compositor makes up itself. Those come in two shapes. After every animation the Shell re-picks
 * the actor under the still cursor and emits synthetic crossing events. During a window drag, a lock or a new
 * window, Mutter also emits plain motion and button events on the logical pointer, a POINTER_DEVICE with no
 * device node, which is what used to hand the vibration to an absent mouse while the touchpad was dragging.
 * Only devices backed by a node under /dev/input are real hardware.
 * `event` is {deviceType, eventType, synthetic, deviceNode}; `C` provides Clutter.InputDeviceType and
 * Clutter.EventType, passed in so the function stays testable without the Shell.
 */
export function pointerKind({deviceType, eventType, synthetic, deviceNode}, C) {
    const E = C.EventType;
    const fromHardware = [E.MOTION, E.BUTTON_PRESS, E.BUTTON_RELEASE, E.SCROLL,
        E.TOUCHPAD_PINCH, E.TOUCHPAD_SWIPE, E.TOUCHPAD_HOLD].includes(eventType);
    if (!fromHardware || synthetic || !deviceNode)
        return null;
    if (deviceType === C.InputDeviceType.TOUCHPAD_DEVICE)
        return 'touchpad';
    if (deviceType === C.InputDeviceType.POINTER_DEVICE)
        return 'mouse';
    return null;
}

/**
 * A quick-settings tile or a menu switch flipped by the user -> haptic event. `before` is the state before the
 * click: the real state may arrive later (network), so the direction is the one the user asked for.
 */
export function toggleEvent(before) {
    return before ? 'toggle-off' : 'toggle-on';
}
