import sys, json, numpy as np
sys.path.insert(0, __import__('os').path.dirname(__file__)); from raw import load_rgb
REF8 = np.array([(115,82,68),(194,150,130),(98,122,157),(87,108,67),(133,128,177),(103,189,170),
     (214,126,44),(80,91,166),(193,90,99),(94,60,108),(157,188,64),(224,163,46),
     (56,61,150),(70,148,73),(175,54,60),(231,199,31),(187,86,149),(8,133,161),
     (243,243,242),(200,200,200),(160,160,160),(122,122,121),(85,85,85),(52,52,52)], float) / 255
def lin(v): return np.where(v <= 0.04045, v / 12.92, ((v + 0.055) / 1.055) ** 2.4)
REF = lin(REF8)
M_XYZ = np.array([[0.4124,0.3576,0.1805],[0.2126,0.7152,0.0722],[0.0193,0.1192,0.9505]])
WP = M_XYZ @ np.ones(3)
def lab(rgb):
    xyz = (M_XYZ @ np.clip(rgb, 0, None).T).T / WP
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16/116)
    return np.dstack([116*f[:,1]-16, 500*(f[:,0]-f[:,1]), 200*(f[:,1]-f[:,2])])[0]
def de(a, b): return np.linalg.norm(lab(a) - lab(b), axis=1)

def measure(frames, corners, rad=20, keep=0.4):
    TL, TR, BL, BR = map(np.array, corners)
    img = np.mean([load_rgb(f) for f in frames], axis=0)
    out, clip = [], []
    for r in range(4):
        for c in range(6):
            u, v = c / 5, r / 3
            x, y = np.round((1-u)*(1-v)*TL + u*(1-v)*TR + (1-u)*v*BL + u*v*BR).astype(int)
            box = img[y-rad:y+rad, x-rad:x+rad].reshape(-1, 3)
            lum = box @ [0.25, 0.5, 0.25]
            sel = box[lum <= np.quantile(lum, keep)]       # glare is additive: keep the darkest pixels
            out.append(sel.mean(0)); clip.append(box.max() >= 0.98)
    return np.array(out), np.array(clip)

cfg = json.loads(sys.argv[1])
cam, clip = measure(cfg['frames'], cfg['corners'])
neutral = [19, 20, 21, 22]                     # patches 20-23 (0-based 19-22)
ok = ~clip
wb = cam[neutral].mean(0); wb = wb[1] / wb        # gains so that neutrals have R=G=B
c = cam * wb
s = REF[neutral, 1].mean() / c[neutral, 1].mean()
c = c * s
use = ok.copy(); use[23] = False               # black patch: too noisy for the fit
M = np.zeros((3, 3))
for i in range(3):                             # rows sum to 1: white stays white
    A = np.stack([c[use, 0] - c[use, 2], c[use, 1] - c[use, 2]], 1)
    b = REF[use, i] - c[use, 2]
    (m0, m1), *_ = np.linalg.lstsq(A, b, rcond=None)
    M[i] = [m0, m1, 1 - m0 - m1]
before, after = de(c, REF), de((M @ c.T).T, REF)
print('clipped patches:', [i+1 for i in np.where(clip)[0]])
print('WB gains (R,G,B):', np.round(wb, 3))
print('CCM:\n', np.round(M, 3))
for i in range(24):
    print(f"{i+1:2d} dE before {before[i]:5.1f} after {after[i]:5.1f}{'' if use[i] else '  (not fitted)'}")
print(f"mean dE fitted patches: before {before[use].mean():.1f} after {after[use].mean():.1f}; rows 3-4 only after {after[12:23].mean():.1f}")
json.dump({'ccm': M.round(4).tolist()}, open('ccm.json', 'w'))
