import sys, numpy as np
sys.path.insert(0, __import__('os').path.dirname(__file__)); from raw import load_rgb, write_png
rgb = load_rgb(sys.argv[1])
print('clipped fraction per channel:', [(rgb[..., c] >= 0.999).mean().round(4) for c in range(3)], 'max', rgb.max().round(3))
g = rgb / rgb.reshape(-1, 3).mean(0) * rgb.mean()          # grey world
g = np.clip(g / np.percentile(g, 99.5), 0, 1) ** (1 / 2.2)
write_png(sys.argv[2], (g * 255).astype(np.uint8))
