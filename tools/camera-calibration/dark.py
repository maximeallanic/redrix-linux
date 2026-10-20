import sys, numpy as np
W, H = 2592, 1944
names = {(0,0):'Gr',(0,1):'R',(1,0):'B',(1,1):'Gb'}   # SGRBG
for f in sys.argv[1:]:
    a = np.fromfile(f, dtype='<u2').reshape(H, W)
    s = ' '.join(f"{names[(y,x)]}={a[y::2, x::2].mean():6.2f}" for y in (0,1) for x in (0,1))
    print(f.split('-')[-1], s, f"p50={np.median(a):.0f} p99.9={np.percentile(a,99.9):.0f} max={a.max()}")
