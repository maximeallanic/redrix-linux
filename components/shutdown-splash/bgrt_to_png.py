"""Converts the firmware boot logo (ACPI BGRT image, an uncompressed BMP) to PNG for the Plymouth shutdown theme.

The shutdown screen redraws the logo the firmware showed at power-on, so it is taken from the machine itself rather
than shipped. Standard library only: 24- and 32-bit uncompressed BMPs (BI_RGB, and BI_BITFIELDS with the usual
BGRA masks), bottom-up or top-down, which is what edk2 publishes.

Usage: bgrt_to_png.py [SOURCE.bmp] DEST.png   (SOURCE defaults to /sys/firmware/acpi/bgrt/image)
"""
import struct
import sys
import zlib

BGRT_IMAGE = '/sys/firmware/acpi/bgrt/image'
BI_RGB, BI_BITFIELDS = 0, 3


class NotSupported(ValueError):
    pass


def decode_bmp(data):
    """Returns (width, height, rows) with rows top to bottom, each a bytes object of RGB triplets."""
    if data[:2] != b'BM' or len(data) < 54:
        raise NotSupported('not a BMP file')
    offset, = struct.unpack_from('<I', data, 10)
    header_size, width, height, planes, bpp, compression = struct.unpack_from('<IiiHHI', data, 14)
    if header_size < 40 or planes != 1:
        raise NotSupported(f'unsupported BMP header (size {header_size}, planes {planes})')
    if bpp not in (24, 32) or compression not in (BI_RGB, BI_BITFIELDS):
        raise NotSupported(f'unsupported BMP format ({bpp} bits, compression {compression})')
    if compression == BI_BITFIELDS:
        masks = struct.unpack_from('<III', data, 14 + 40) if header_size == 40 else struct.unpack_from('<III', data, 54)
        if bpp != 32 or masks != (0x00FF0000, 0x0000FF00, 0x000000FF):
            raise NotSupported(f'unsupported BMP bit fields {masks!r}')
    top_down = height < 0
    height = abs(height)
    if width <= 0 or height == 0:
        raise NotSupported('empty image')
    step = bpp // 8
    stride = (width * step + 3) & ~3
    if offset + stride * height > len(data):
        raise NotSupported('truncated BMP')
    rows = []
    for y in range(height):
        start = offset + stride * (y if top_down else height - 1 - y)
        line = data[start:start + width * step]
        rgb = bytearray(width * 3)
        rgb[0::3] = line[2::step]
        rgb[1::3] = line[1::step]
        rgb[2::3] = line[0::step]
        rows.append(bytes(rgb))
    return width, height, rows


def encode_png(width, height, rows):
    def chunk(kind, body):
        return struct.pack('>I', len(body)) + kind + body + struct.pack('>I', zlib.crc32(kind + body) & 0xFFFFFFFF)
    raw = b''.join(b'\0' + row for row in rows)  # filter type 0 on every row
    header = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)  # 8-bit RGB
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')


def main(argv):
    if len(argv) not in (1, 2):
        print(__doc__, file=sys.stderr)
        return 2
    source, dest = (BGRT_IMAGE, argv[0]) if len(argv) == 1 else argv
    with open(source, 'rb') as f:
        data = f.read()
    try:
        width, height, rows = decode_bmp(data)
    except NotSupported as e:
        print(f'{source}: {e}', file=sys.stderr)
        return 1
    with open(dest, 'wb') as f:
        f.write(encode_png(width, height, rows))
    print(f'{dest}: {width}x{height}')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
