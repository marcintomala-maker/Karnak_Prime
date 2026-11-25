#!/usr/bin/env python3
"""Quake3-style 6-face skybox -> equirectangular panorama for Godot PanoramaSkyMaterial."""
import sys, numpy as np
from PIL import Image

def load(prefix, f, rot):
    im = Image.open(f'{prefix}_{f}.png').convert('RGB')
    if rot: im = im.rotate(rot, expand=True)
    return np.asarray(im).astype(np.float32)

def convert(prefix, out, W=2048, rots=None, order=None):
    rots = rots or {}
    # Godot/Y-up direction d; map to quake (Z-up) q = (x_q, y_q, z_q)
    faces = {k: load(prefix, k, rots.get(k, 0)) for k in ['rt', 'lf', 'bk', 'ft', 'up', 'dn']}
    H = W // 2
    u = (np.arange(W) + 0.5) / W; v = (np.arange(H) + 0.5) / H
    lon = (u - 0.5) * 2 * np.pi; lat = (0.5 - v) * np.pi
    lon, lat = np.meshgrid(lon, lat)
    # quake coords: x forward, y left, z up
    x = np.cos(lat) * np.cos(lon); y = np.cos(lat) * np.sin(lon); z = np.sin(lat)
    out_img = np.zeros((H, W, 3), np.float32)
    ax, ay, az = np.abs(x), np.abs(y), np.abs(z)
    order = order or dict(px='rt', nx='lf', py='bk', ny='ft')
    def sample(face, s, t, mask):
        img = faces[face]; h, w = img.shape[:2]
        ix = np.clip(((s + 1) / 2 * (w - 1)).round().astype(int), 0, w - 1)
        iy = np.clip(((t + 1) / 2 * (h - 1)).round().astype(int), 0, h - 1)
        out_img[mask] = img[iy[mask], ix[mask]]
    m = (ax >= ay) & (ax >= az) & (x > 0); sample(order['px'], -y / ax, -z / ax, m)
    m = (ax >= ay) & (ax >= az) & (x <= 0); sample(order['nx'], y / ax, -z / ax, m)
    m = (ay > ax) & (ay >= az) & (y > 0); sample(order['py'], x / ay, -z / ay, m)
    m = (ay > ax) & (ay >= az) & (y <= 0); sample(order['ny'], -x / ay, -z / ay, m)
    m = (az > ax) & (az > ay) & (z > 0); sample('up', -y / az, x / az, m)
    m = (az > ax) & (az > ay) & (z <= 0); sample('dn', -y / az, -x / az, m)
    Image.fromarray(out_img.clip(0, 255).astype(np.uint8)).save(out)

if __name__ == '__main__':
    convert(sys.argv[1], sys.argv[2])
