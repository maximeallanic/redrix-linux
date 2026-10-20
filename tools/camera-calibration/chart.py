import struct, zlib, sys
# X-Rite ColorChecker Classic, sRGB 8-bit (row-major, 6x4)
P = [(115,82,68),(194,150,130),(98,122,157),(87,108,67),(133,128,177),(103,189,170),
     (214,126,44),(80,91,166),(193,90,99),(94,60,108),(157,188,64),(224,163,46),
     (56,61,150),(70,148,73),(175,54,60),(231,199,31),(187,86,149),(8,133,161),
     (243,243,242),(200,200,200),(160,160,160),(122,122,121),(85,85,85),(52,52,52)]
W, H, CELL, GAP = 2400, 1080, 230, 30
x0 = (W - (6*CELL + 5*GAP)) // 2; y0 = (H - (4*CELL + 3*GAP)) // 2
rows = []
for y in range(H):
    row = bytearray(b'\x00')
    r = (y - y0) // (CELL + GAP); inr = 0 <= y - y0 and (y - y0) % (CELL + GAP) < CELL and r < 4
    for x in range(W):
        c = (x - x0) // (CELL + GAP); inc = 0 <= x - x0 and (x - x0) % (CELL + GAP) < CELL and c < 6
        row += bytes(P[r*6 + c]) if inr and inc else b'\x00\x00\x00'
    rows.append(bytes(row))
def chunk(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d))
png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 2, 0, 0, 0))
# sRGB chunk: rendering intent perceptual, tells viewers the values are sRGB
png += chunk(b'sRGB', b'\x00') + chunk(b'IDAT', zlib.compress(b''.join(rows), 9)) + chunk(b'IEND', b'')
open(sys.argv[1], 'wb').write(png)
