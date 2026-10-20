"""Shared loader and fakes for the haptic-bridge tests (the script has no .py extension)."""
import importlib.machinery
import importlib.util
import os
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent


def load_bridge():
    loader = importlib.machinery.SourceFileLoader('haptic_bridge', str(HERE / 'haptic-bridge'))
    mod = importlib.util.module_from_spec(importlib.util.spec_from_loader('haptic_bridge', loader))
    loader.exec_module(mod)
    return mod


HB = load_bridge()
ALL_WAVEFORMS = (1 << 16) - 1  # mask: all 16 waveforms
WITHOUT_WHISPER = 0x7FFF  # 15 waveforms, ids 0..14: what the real MX Master 4 advertises


class FakeReceiver:
    """Like a Solaar Receiver: a hidraw path and an integer descriptor; close() closes it."""
    def __init__(self):
        self.path = '/dev/null'
        self.handle = os.open('/dev/null', os.O_RDONLY)
        self.closed = 0

    def close(self):
        self.closed += 1
        if self.handle is not None:
            os.close(self.handle)
            self.handle = None

    def kill(self):  # the receiver went away: Solaar closed the descriptor without notice
        os.close(self.handle)


class FakeDevice:
    def __init__(self, mask=ALL_WAVEFORMS, failures=0, caps_none=False, dies_after_send=False):
        self.mask = mask
        self.failures = failures  # number of 0x40 sends that raise before succeeding (NoReceiver on write)
        self.caps_none = caps_none  # Solaar returns None when the mouse does not answer
        self.dies_after_send = dies_after_send  # Solaar swallows the failure on read: returns None, dead descriptor
        self.receiver = FakeReceiver()
        self.calls = []

    def feature_request(self, feature, function=0x00, *params, no_reply=False):
        self.calls.append((feature, function, params, no_reply))
        if function == 0x00:
            if self.caps_none:
                return None
            return b'\x00\x00\x00\x00' + self.mask.to_bytes(4, 'big') + b'\x00' * 8
        if function == 0x40 and self.failures > 0:
            self.failures -= 1
            raise OSError('hidraw closed')
        if function == 0x40 and self.dies_after_send:
            self.receiver.kill()
            return None
        return b''
