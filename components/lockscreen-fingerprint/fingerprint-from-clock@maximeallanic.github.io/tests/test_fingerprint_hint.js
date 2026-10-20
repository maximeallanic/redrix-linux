// gjs -m tests/test_fingerprint_hint.js: the silenced reader hint (fingerprint-hint.js) with stubs for the
// AuthServicesLegacy instance, then the Shell sources it relies on, read from the gresource of the installed libshell.
// Without GNOME Shell installed (CI), that second half is skipped and says so.
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import System from 'system';
import {silenceReaderHint} from '../fingerprint-hint.js';

let n = 0, failures = 0;
function ok(cond, name, detail = '') {
    n++;
    print(`${cond ? 'ok' : 'not ok'} ${n} - ${name}${cond || !detail ? '' : ` (${detail})`}`);
    if (!cond)
        failures++;
}

const FP = 'gdm-fingerprint', PASSWORD = 'gdm-password', NONE = 0;
const mechanisms = [{serviceName: PASSWORD}, {serviceName: FP}];

function run({selected, enabled = mechanisms, service, info = 'Place your finger on the fingerprint reader'}) {
    const emitted = [], forwarded = [];
    const services = {
        _selectedMechanism: selected,
        _enabledMechanisms: enabled,
        emit: (name, args) => emitted.push([name, args]),
    };
    const original = function (...args) {
        forwarded.push({self: this, args});
    };
    silenceReaderHint(original, FP, NONE).call(services, service, info);
    return {services, emitted, forwarded};
}

{
    const r = run({selected: mechanisms[0], service: FP});
    ok(r.forwarded.length === 0, 'fingerprint info while password is selected: not forwarded to the stock handler');
    ok(r.emitted.length === 1 && r.emitted[0][0] === 'queue-message', 'one queue-message', JSON.stringify(r.emitted));
    const args = r.emitted[0]?.[1] ?? {};
    ok(args.serviceName === FP && args.message === null && args.messageType === NONE,
        'queued without text, type NONE, under the fingerprint service', JSON.stringify(args));
}
{
    const r = run({selected: mechanisms[1], service: FP});
    ok(r.emitted.length === 0 && r.forwarded.length === 1, 'fingerprint selected: its own info goes to the stock handler');
}
{
    const r = run({selected: mechanisms[0], service: PASSWORD, info: 'You have 2 attempts left'});
    ok(r.emitted.length === 0 && r.forwarded.length === 1 && r.forwarded[0].args[1] === 'You have 2 attempts left',
        'password info: stock handler, message untouched');
    ok(r.forwarded[0]?.self === r.services, 'stock handler called on the same instance');
}
{
    const r = run({selected: mechanisms[0], enabled: [mechanisms[0]], service: FP});
    ok(r.emitted.length === 0 && r.forwarded.length === 1, 'fingerprint not enabled: stock handler (which ignores it)');
}
{
    const r = run({selected: null, service: FP});
    ok(r.forwarded.length === 0 && r.emitted.length === 1, 'no mechanism selected yet: still silenced');
}

// The Shell sources this relies on, from the installed libshell (its name carries the Shell's major version).
function findLibshell() {
    const dir = Gio.File.new_for_path('/usr/lib/gnome-shell');
    let children;
    try {
        children = dir.enumerate_children('standard::name', Gio.FileQueryInfoFlags.NONE, null);
    } catch {
        return null;
    }
    for (let info; (info = children.next_file(null)) !== null;) {
        if (/^libshell-\d+\.so$/.test(info.get_name()))
            return dir.get_child(info.get_name()).get_path();
    }
    return null;
}
function shellSource(lib, path) {
    const [, out, err, status] = GLib.spawn_sync(null,
        ['gresource', 'extract', lib, path], null, GLib.SpawnFlags.SEARCH_PATH, null);
    if (status !== 0)
        throw new Error(`gresource extract ${path}: ${new TextDecoder().decode(err)}`);
    return new TextDecoder().decode(out);
}
const libshell = findLibshell();
if (libshell === null) {
    print('# skip: GNOME Shell is not installed, its sources are not checked');
} else {
    const legacy = shellSource(libshell, '/org/gnome/shell/gdm/authServicesLegacy.js');
    const onInfo = legacy.slice(legacy.indexOf('    _handleOnInfo('), legacy.indexOf('    _handleOnProblem('));
    ok(legacy.includes(`const FINGERPRINT_SERVICE_NAME = '${FP}';`), `fingerprint service is ${FP}`);
    ok(/\[Role\.FINGERPRINT\]: FINGERPRINT_SERVICE_NAME/.test(legacy), 'RoleToService maps the fingerprint role to it');
    ok(onInfo.includes('FINGERPRINT_SERVICE_NAME') && onInfo.includes('messageType: MessageType.HINT'),
        '_handleOnInfo is where the reader hint is made');
    const verifier = shellSource(libshell, '/org/gnome/shell/gdm/userVerifier.js');
    ok(/NONE: 0,/.test(verifier), 'MessageType.NONE is 0');
}

print(`1..${n}`);
System.exit(failures ? 1 : 0);
