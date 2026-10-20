"""Prints the keycode the kernel maps a scancode to on an evdev node (EVIOCGKEYCODE_V2).
Usage: keycode.py /dev/input/eventN 0x5d"""
import fcntl
import os
import struct
import sys

FORMAT = 'BBHI32s'  # struct input_keymap_entry: flags, len, index, keycode, scancode[32]
SIZE = struct.calcsize(FORMAT)
EVIOCGKEYCODE_V2 = (2 << 30) | (SIZE << 16) | (ord('E') << 8) | 0x04


def keycode(path, scancode):
    fd = os.open(path, os.O_RDONLY)
    try:
        request = struct.pack(FORMAT, 0, 4, 0, 0, struct.pack('I', scancode) + b'\0' * 28)
        return struct.unpack(FORMAT, fcntl.ioctl(fd, EVIOCGKEYCODE_V2, request))[3]
    finally:
        os.close(fd)


if __name__ == '__main__':
    print(keycode(sys.argv[1], int(sys.argv[2], 0)))
