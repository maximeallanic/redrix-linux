import struct, zlib, numpy as np
W, H, BL = 2592, 1944, 64.0
def load_rgb(path):
    """SGRBG10 -> half-resolution linear RGB (black level removed), float, 0..1 of 10-bit range."""
    a = np.fromfile(path, dtype='<u2').reshape(H, W).astype(np.float64)
    gr, r, b, gb = a[0::2, 0::2], a[0::2, 1::2], a[1::2, 0::2], a[1::2, 1::2]
    return np.clip(np.dstack([r, (gr + gb) / 2, b]) - BL, 0, None) / (1023 - BL)
def write_png(path, img8):
    h, w, _ = img8.shape
    raw = b''.join(b'\x00' + img8[y].tobytes() for y in range(h))
    def chunk(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d))
    open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
                           + chunk(b'IDAT', zlib.compress(raw, 6)) + chunk(b'IEND', b''))
