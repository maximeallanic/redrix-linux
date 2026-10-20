"""bgrt_to_png: BMP decoding (row order, padding, channel order) and a PNG that decodes back to the same pixels."""
import importlib.util
import struct
import unittest
import zlib
from pathlib import Path

spec = importlib.util.spec_from_file_location('bgrt_to_png', Path(__file__).resolve().parent.parent / 'bgrt_to_png.py')
bgrt = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bgrt)

# 3x2 image, top row red green blue, bottom row white black grey (RGB).
PIXELS = [[(255, 0, 0), (0, 255, 0), (0, 0, 255)], [(255, 255, 255), (0, 0, 0), (128, 128, 128)]]


def bmp(bpp=24, top_down=False, compression=0):
    width, height = 3, 2
    step = bpp // 8
    stride = (width * step + 3) & ~3
    order = PIXELS if top_down else PIXELS[::-1]
    body = b''
    for row in order:
        line = b''.join(bytes((b, g, r)) + (b'\xff' if step == 4 else b'') for r, g, b in row)
        body += line + b'\0' * (stride - len(line))
    extra = struct.pack('<III', 0x00FF0000, 0x0000FF00, 0x000000FF) if compression == 3 else b''
    offset = 14 + 40 + len(extra)
    info = struct.pack('<IiiHHIIiiII', 40, width, -height if top_down else height, 1, bpp, compression,
                       len(body), 2835, 2835, 0, 0)
    return b'BM' + struct.pack('<IHHI', offset + len(body), 0, 0, offset) + info + extra + body


def png_pixels(png):
    assert png[:8] == b'\x89PNG\r\n\x1a\n'
    pos, idat, size = 8, b'', None
    while pos < len(png):
        length, = struct.unpack_from('>I', png, pos)
        kind, body = png[pos + 4:pos + 8], png[pos + 8:pos + 8 + length]
        crc, = struct.unpack_from('>I', png, pos + 8 + length)
        assert crc == zlib.crc32(kind + body) & 0xFFFFFFFF
        if kind == b'IHDR':
            size = struct.unpack_from('>II', body)
        elif kind == b'IDAT':
            idat += body
        pos += 12 + length
    width, height = size
    raw = zlib.decompress(idat)
    rows = [raw[y * (width * 3 + 1) + 1:(y + 1) * (width * 3 + 1)] for y in range(height)]
    return [[tuple(row[x * 3:x * 3 + 3]) for x in range(width)] for row in rows]


class Bmp(unittest.TestCase):
    def check(self, data):
        width, height, rows = bgrt.decode_bmp(data)
        self.assertEqual((width, height), (3, 2))
        self.assertEqual(png_pixels(bgrt.encode_png(width, height, rows)), PIXELS)

    def test_bottom_up_24_bit(self):
        self.check(bmp())

    def test_top_down_24_bit(self):
        self.check(bmp(top_down=True))

    def test_32_bit(self):
        self.check(bmp(bpp=32))

    def test_32_bit_bitfields(self):
        self.check(bmp(bpp=32, compression=3))

    def test_refuses_what_it_cannot_read(self):
        for data in (b'not a bmp at all, long enough to hold a header' * 2, bmp(bpp=24, compression=1), bmp()[:70]):
            with self.assertRaises(bgrt.NotSupported):
                bgrt.decode_bmp(data)


if __name__ == '__main__':
    unittest.main()
