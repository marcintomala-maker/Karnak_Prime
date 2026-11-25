#!/usr/bin/env python3
"""Karnak Prime world generator (run once; output is shipped with the game).
Produces heightfield, nav data, street/terrain masks and the city layout."""
import json, math, os, sys
import numpy as np
from scipy import ndimage
from PIL import Image, ImageDraw
import trimesh

OUT = sys.argv[1] if len(sys.argv) > 1 else '/home/claude/karnak_prime/assets/world'
BLD = '/home/claude/karnak_prime/assets/models/buildings'
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(621)
N = 512; CELL = 2.0; HALF = N * CELL / 2
xs = -HALF + (np.arange(N) + 0.5) * CELL
X, Z = np.meshgrid(xs, xs)  # X[j,i] = x of column i ; Z[j,i] = z of row j

def noise(scale, seed, octaves=1, persistence=0.5):
    """fBm value noise: random lattice every `scale` meters, bicubic upsampled."""
    r = np.random.default_rng(seed); out = np.zeros((N, N)); amp = 1.0; tot = 0
    s = scale
    for o in range(octaves):
        n = max(2, int(N * CELL / s) + 3)
        lat = r.standard_normal((n, n))
        z = ndimage.zoom(lat, (N + 2 * N / n) / n, order=3)[:N, :N]
        out += amp * z / (z.std() + 1e-9); tot += amp; amp *= persistence; s /= 2
    return out / tot

def sample(grid, x, z):
    i = np.clip(((np.asarray(x) + HALF) / CELL - 0.5), 0, N - 1.001)
    j = np.clip(((np.asarray(z) + HALF) / CELL - 0.5), 0, N - 1.001)
    i0 = np.floor(i).astype(int); j0 = np.floor(j).astype(int); fi = i - i0; fj = j - j0
    return (grid[j0, i0] * (1 - fi) * (1 - fj) + grid[j0, i0 + 1] * fi * (1 - fj) +
            grid[j0 + 1, i0] * (1 - fi) * fj + grid[j0 + 1, i0 + 1] * fi * fj)

def to_ij(x, z):
    return int((x + HALF) / CELL), int((z + HALF) / CELL)

# ---------------------------------------------------------------- island & mountains
ang = np.arctan2(Z, X); dist = np.hypot(X, Z)
rim = 430 + 38 * noise(160, 1, 3) + 22 * np.sin(3 * ang + 1.3)
shore = rim - dist                       # >0 on land
hills = 2.5 + 3.5 * noise(90, 2, 4)
base = np.where(shore > 0, np.minimum(shore * 0.07, 1.0) * hills + np.clip(shore, 0, 60) * 0.05, shore * 0.05)
base = base - 2.2 * (shore < 25)         # gentle beach drop
# mountain ranges (N / NE / E arc and a western spine), ridged noise
ridged = np.clip(1 - np.abs(noise(120, 3, 4)), 0, 1)
ridged = ridged ** 2.2
sector = np.clip(np.cos(ang - (-1.0)) * 1.2, 0, 1) + 0.9 * np.clip(np.cos(ang - 2.6) * 1.4 - 0.4, 0, 1)
ring = np.clip((dist - 300) / 40, 0, 1) * np.clip((rim - 45 - dist) / 50, 0, 1)
mount = ridged * sector * ring * 95
h_nat = base + mount

# ---------------------------------------------------------------- city terraces
CX, CZ = 10.0, 15.0
wr = 16 * noise(140, 4, 2) + 7 * noise(50, 5, 1)
rc = np.hypot(X - CX, Z - CZ) + wr
dist_c = np.hypot(X - CX, Z - CZ)
rc = rc - 64.0 * np.clip(1.0 - dist_c / 150.0, 0, 1)
CITY_R = 300.0
LEVELS = [(300, 4.0), (238, 10.0), (178, 16.0), (122, 22.0), (66, 28.0)]
def terrace(r):
    h = np.full_like(r, np.nan, dtype=float)
    for rad, lv in LEVELS:
        h = np.where(r < rad, lv, h)
    return h
def terrace_smooth(r, ramp=26.0):
    h = np.full_like(r, LEVELS[0][1] - 4.0, dtype=float)
    for k, (rad, lv) in enumerate(LEVELS):
        prev = LEVELS[0][1] - 1.5 if k == 0 else LEVELS[k - 1][1]
        t = np.clip((rad + ramp / 2 - r) / ramp, 0, 1)
        h = np.where(r < rad + ramp / 2, prev + (lv - prev) * t, h)
    return h
city_h = terrace(rc)
dist_c = np.hypot(X - CX, Z - CZ)
in_city = rc < CITY_R
# avenues (curving spokes) = ramps between terraces
cang = np.arctan2(Z - CZ, X - CX)
NSPOKE = 6
spoke_off = rng.uniform(0, 2 * np.pi)
av = np.zeros((N, N))
for k in range(NSPOKE):
    a0 = spoke_off + k * 2 * np.pi / NSPOKE
    wig = 0.22 * noise(110, 10 + k, 2)
    da = np.angle(np.exp(1j * (cang - a0 - wig)))
    lateral = np.abs(da) * np.hypot(X - CX, Z - CZ)
    av = np.maximum(av, np.clip((9.0 - lateral) / 3.0, 0, 1) * (rc > 40))
avenue = av > 0.5
smooth_h = terrace_smooth(rc)
ch = np.where(np.isnan(city_h), smooth_h, city_h)
ch = ch * (1 - av) + smooth_h * av
# blend city into nature at outer rim
edge = np.clip((CITY_R + 25 - rc) / 25, 0, 1)
h = np.where(rc < CITY_R + 25, ch * edge + h_nat * (1 - edge), h_nat)
h = np.where(in_city, ch, h)
h_city_flat = h.copy()

# ---------------------------------------------------------------- building catalogue
man = json.load(open(f'{BLD}/manifest.json'))
SKIP = {'pers_lamassu', 'ptol_lighthouse'}
cat = {}
for name, m in man.items():
    if name.startswith('ptol_statue') or name in SKIP: continue
    mn, mx = np.array(m['min']), np.array(m['max'])
    vis_h = mx[1]
    if vis_h < 6: continue
    sx, sz = mx[0] - mn[0], mx[2] - mn[2]
    if min(sx, sz) < 4: continue
    tgt = rng.uniform(26, 44)
    scale = float(np.clip(tgt / vis_h, 1.7, 3.2))
    cat[name] = dict(min=mn.tolist(), max=mx.tolist(), scale=scale)
print('catalogue', len(cat))

# footprint rasters (1 m, local, unscaled) from mesh triangles above ground
foot = {}
for name in cat:
    tm = trimesh.load(f'{BLD}/{name}.glb', force='mesh')
    v = np.asarray(tm.vertices); f = np.asarray(tm.faces)
    keep = v[f].max(axis=1)[:, 1] > 0.6
    tris = v[f[keep]][:, :, [0, 2]]
    mn = np.floor(v[:, [0, 2]].min(0)) - 1
    size = (np.ceil(v[:, [0, 2]].max(0) - mn) + 2).astype(int)
    im = Image.new('L', tuple(size), 0); d = ImageDraw.Draw(im)
    for t in tris:
        d.polygon([tuple(p - mn) for p in t], fill=255)
    arr = ndimage.binary_closing(np.asarray(im) > 0, iterations=2)
    arr = ndimage.binary_fill_holes(arr)
    foot[name] = (arr, mn)

# ---------------------------------------------------------------- city layout (uv space)
WA = 20.0
wnx = noise(230, 20, 2); wnz = noise(230, 21, 2)
def world_to_uv(x, z):
    u, v = x, z
    for _ in range(4):
        u = x - WA * sample(wnx, u, v); v = z - WA * sample(wnz, u, v)
    return u, v
def uv_to_world(u, v):
    return u + WA * sample(wnx, u, v), v + WA * sample(wnz, u, v)

S_COL = 48.0
streets = []   # (u0,u1,v0,v1) rectangles of street in uv
lots = []
ucols = np.arange(-CITY_R - S_COL, CITY_R + S_COL, S_COL) + rng.uniform(-6, 6)
for ci in range(len(ucols) - 1):
    cw = 11.0 if ci % 2 == 0 else rng.uniform(4.5, 6.5)      # street west of column
    u0 = ucols[ci] + cw / 2; u1 = ucols[ci + 1] - (11.0 if (ci + 1) % 2 == 0 else 5.5) / 2
    streets.append((ucols[ci] - cw / 2, ucols[ci] + cw / 2, -CITY_R - 80, CITY_R + 80))
    off = rng.uniform(0, 50)
    v = -CITY_R - 80 + off
    while v < CITY_R + 60:
        bh = rng.uniform(30, 56)
        rw = rng.choice([4.0, 5.0, 9.0, 10.0], p=[0.3, 0.3, 0.2, 0.2])
        streets.append((u0 - 1, u1 + 1, v + bh, v + bh + rw))
        # subdivide block into lots with narrow passages
        bw = u1 - u0
        if bw > 40 and rng.random() < 0.7:
            cut = rng.uniform(0.35, 0.65) * bw; pw = rng.uniform(3.2, 4.5)
            parts_u = [(u0, u0 + cut - pw / 2), (u0 + cut + pw / 2, u1)]
            streets.append((u0 + cut - pw / 2, u0 + cut + pw / 2, v, v + bh))
        else:
            parts_u = [(u0, u1)]
        for (a, b) in parts_u:
            if bh > 44 and rng.random() < 0.6:
                cut = rng.uniform(0.4, 0.6) * bh; pw = rng.uniform(3.2, 4.5)
                lots.append((a, b, v, v + cut - pw / 2)); lots.append((a, b, v + cut + pw / 2, v + bh))
                streets.append((a, b, v + cut - pw / 2, v + cut + pw / 2))
            else:
                lots.append((a, b, v, v + bh))
        v += bh + rw
print('lots', len(lots))

# ---------------------------------------------------------------- ponds & canals (plazas)
ponds = []
pond_mask = np.zeros((N, N), bool)
water_y = np.full((N, N), -1000.0)
cand = []
for lv_i in range(0, len(LEVELS) - 1):
    r_in = LEVELS[lv_i + 1][0] + 18
    r_out = LEVELS[lv_i][0] - 18
    for _ in range(60):
        a = rng.uniform(0, 2 * np.pi); r = rng.uniform(r_in + 10, r_out - 10)
        x, z = CX + r * np.cos(a), CZ + r * np.sin(a)
        i, j = to_ij(x, z)
        if 0 <= i < N and 0 <= j < N and not avenue[j, i] and abs(rc[j, i] - r) < 15:
            cand.append((lv_i, x, z))
rng.shuffle(cand)
chosen = []
for lv_i, x, z in cand:
    if all(math.hypot(x - c[1], z - c[2]) > 120 for c in chosen):
        chosen.append((lv_i, x, z))
    if len(chosen) >= 6: break
for lv_i, x, z in chosen:
    lv = LEVELS[lv_i][1]
    rx, rz = rng.uniform(16, 24), rng.uniform(13, 20)
    rot = rng.uniform(0, np.pi)
    dx, dz = X - x, Z - z
    lx = dx * np.cos(rot) + dz * np.sin(rot); lz = -dx * np.sin(rot) + dz * np.cos(rot)
    e = np.sqrt((lx / rx) ** 2 + (lz / rz) ** 2) + 0.08 * noise(30, 40 + len(ponds))
    ok = (city_h == lv) & ~avenue
    inside = (e < 1.0) & ok
    depth = np.clip((1.0 - e) * 10.0, 0, 2.2)
    h = np.where(inside, lv - depth, h)
    shore_m = (e < 1.6) & (e >= 1.0) & ok
    wl = lv - 0.35
    water_y = np.where(inside, wl, water_y)
    pond_mask |= inside
    ponds.append(dict(x=float(x), z=float(z), rx=float(rx * 1.05), rz=float(rz * 1.05), rot=float(rot), y=float(wl), level=lv))
# canals between ponds on the same terrace + bridges
bridges = []
canal_mask = np.zeros((N, N), bool)
for a in range(len(chosen)):
    for b in range(a + 1, len(chosen)):
        if chosen[a][0] != chosen[b][0]: continue
        (lv_i, x0, z0), (_, x1, z1) = chosen[a], chosen[b]
        if math.hypot(x1 - x0, z1 - z0) > 220: continue
        lv = LEVELS[lv_i][1]
        L = math.hypot(x1 - x0, z1 - z0); nseg = int(L / 2)
        pts = []
        for s in range(nseg + 1):
            t = s / nseg
            px, pz = x0 + (x1 - x0) * t, z0 + (z1 - z0) * t
            # bow the canal so it is not straight
            nx, nz = -(z1 - z0) / L, (x1 - x0) / L
            bow = math.sin(t * math.pi) * 18
            pts.append((px + nx * bow, pz + nz * bow))
        cm = Image.new('L', (N, N), 0); dd = ImageDraw.Draw(cm)
        dd.line([((p[0] + HALF) / CELL, (p[1] + HALF) / CELL) for p in pts], fill=255, width=4)
        cmask = (np.asarray(cm) > 0) & (city_h == lv)
        if cmask.sum() == 0: continue
        if (avenue & cmask).sum() > 0 and False: pass
        h = np.where(cmask, np.minimum(h, lv - 1.8), h)
        water_y = np.where(cmask, lv - 0.35, water_y)
        canal_mask |= cmask
        # bridges every ~45 m
        for s in range(10, len(pts) - 10, 22):
            (bx, bz), (bx2, bz2) = pts[s], pts[min(s + 1, len(pts) - 1)]
            bi, bj = to_ij(bx, bz)
            if not cmask[bj, bi]: continue
            dirx, dirz = bx2 - bx, bz2 - bz
            ang_b = math.atan2(dirz, dirx) + math.pi / 2
            bridges.append(dict(x=bx, z=bz, rot=ang_b, y=lv + 0.25, length=16.0, width=6.0))
water_body = pond_mask | canal_mask
print('ponds', len(ponds), 'bridges', len(bridges))

# ---------------------------------------------------------------- place buildings
occupied = np.zeros((N, N), bool)
street_mask = np.zeros((N, N), bool)
U, V = world_to_uv(X, Z)
for (u0, u1, v0, v1) in streets:
    street_mask |= (U >= u0) & (U <= u1) & (V >= v0) & (V <= v1)
street_mask &= in_city
street_mask |= avenue & in_city
# keep a plaza around the ziggurat
zig_r = 46.0
plaza = np.hypot(X - CX, Z - CZ) < zig_r * 1.42 + 12
names = sorted(cat.keys())
big = [n for n in names if (np.array(cat[n]['max']) - np.array(cat[n]['min']))[[0, 2]].max() * cat[n]['scale'] > 50]
buildings = []
def footprint_cells(name, x, z, rot, scale):
    arr, mn = foot[name]
    jj, ii = np.nonzero(arr)
    lx = (ii + mn[0] + 0.5) * scale; lz = (jj + mn[1] + 0.5) * scale
    # Godot rotation about Y by rot: x' = x cos + z sin ; z' = -x sin + z cos
    wx = x + lx * np.cos(rot) + lz * np.sin(rot); wz = z - lx * np.sin(rot) + lz * np.cos(rot)
    ci = ((wx + HALF) / CELL).astype(int); cj = ((wz + HALF) / CELL).astype(int)
    ok = (ci >= 0) & (ci < N) & (cj >= 0) & (cj < N)
    return np.unique(cj[ok] * N + ci[ok])
rng2 = np.random.default_rng(77)
from collections import Counter
FAIL = Counter()
def try_place(u0, u1, v0, v1, depth=0):
    lw, lh = u1 - u0, v1 - v0
    if lw < 12 or lh < 12 or depth > 3: return
    cu, cv = (u0 + u1) / 2, (v0 + v1) / 2
    x, z = uv_to_world(np.array(cu), np.array(cv)); x, z = float(x), float(z)
    i, j = to_ij(x, z)
    if not (0 <= i < N and 0 <= j < N) or not in_city[j, i] or plaza[j, i] or water_body[j, i]: FAIL['lotpos'] += 1; return
    ex, ez = uv_to_world(np.array(cu + 5.0), np.array(cv))
    wang = math.atan2(float(ez) - z, float(ex) - x)
    opts = []
    for name in names:
        c = cat[name]; s_ = c['scale']
        sx = (c['max'][0] - c['min'][0]) * s_; sz = (c['max'][2] - c['min'][2]) * s_
        for k in range(4):
            fx, fz = (sx, sz) if k % 2 == 0 else (sz, sx)
            if fx <= lw - 1.0 and fz <= lh - 1.0:
                opts.append((fx * fz * rng2.uniform(0.6, 1.0), name, k, fx, fz))
    if not opts: FAIL['nofit'] += 1; return
    opts.sort(reverse=True)
    tries = [(o, sd) for o in opts[:70] for sd in (rng2.random() < 0.5, None)]
    for (_, name, k, fx, fz), side in tries:
        c = cat[name]; s_ = c['scale']
        # anchor the building to one end of the lot along the longer axis, remainder recursed
        along_u = lw - fx > lh - fz
        if side is None:
            bu, bv = cu, cv
        elif along_u:
            bu = (u0 + fx / 2 + 0.5) if side else (u1 - fx / 2 - 0.5); bv = cv
        else:
            bu = cu; bv = (v0 + fz / 2 + 0.5) if side else (v1 - fz / 2 - 0.5)
        bx, bz = uv_to_world(np.array(bu), np.array(bv)); bx, bz = float(bx), float(bz)
        rot = -wang + k * math.pi / 2
        lcx = (c['max'][0] + c['min'][0]) / 2 * s_; lcz = (c['max'][2] + c['min'][2]) / 2 * s_
        ox = bx - (lcx * math.cos(rot) + lcz * math.sin(rot)); oz = bz - (-lcx * math.sin(rot) + lcz * math.cos(rot))
        cells = footprint_cells(name, ox, oz, rot, s_)
        cj, ci = cells // N, cells % N
        lvls = city_h[cj, ci]
        if np.any(np.isnan(lvls)): FAIL['level'] += 1; continue
        ldiff = np.nanmax(lvls) - np.nanmin(lvls)
        if ldiff > 0 and (ldiff > 6.5 or -c['min'][1] * s_ < ldiff + 1.0): FAIL['level'] += 1; continue
        if np.any(avenue[cj, ci]): FAIL['avenue'] += 1; continue
        if np.any(occupied[cj, ci]): FAIL['occ'] += 1; continue
        if np.any(water_body[cj, ci]) or np.any(plaza[cj, ci]): FAIL['water'] += 1; continue
        occupied[cj, ci] = True
        buildings.append(dict(name=name, x=ox, z=oz, y=float(np.nanmax(lvls)), rot=rot, scale=s_))
        gap = rng2.uniform(3.2, 5.0)
        if side is None:
            pass
        elif along_u:
            if side: try_place(u0 + fx + 1 + gap, u1, v0, v1, depth + 1)
            else: try_place(u0, u1 - fx - 1 - gap, v0, v1, depth + 1)
        else:
            if side: try_place(u0, u1, v0 + fz + 1 + gap, v1, depth + 1)
            else: try_place(u0, u1, v0, v1 - fz - 1 - gap, depth + 1)
        return
for (u0, u1, v0, v1) in lots:
    try_place(u0, u1, v0, v1)
print('buildings', len(buildings), FAIL)

# ---------------------------------------------------------------- ziggurat (stamped into nav height only)
zig = dict(x=CX, z=CZ, y=LEVELS[-1][1], tiers=[], stair_angle=float(spoke_off))
nav_h = h.copy()
zig_block = np.zeros((N, N), bool)
half = zig_r
ty = zig['y']
for t in range(5):
    tier_h = 7.0
    zig['tiers'].append(dict(half=half, y0=ty, y1=ty + tier_h))
    # rotated square relative to stair direction
    ca, sa = math.cos(spoke_off), math.sin(spoke_off)
    lx = (X - CX) * ca + (Z - CZ) * sa; lz = -(X - CX) * sa + (Z - CZ) * ca
    inside = (np.abs(lx) <= half) & (np.abs(lz) <= half)
    nav_h = np.where(inside, ty + tier_h, nav_h)
    ty += tier_h; half -= 8.0
zig['top_y'] = ty
# stair along +local x from the base edge to top (width 10 m)
ca, sa = math.cos(spoke_off), math.sin(spoke_off)
lx = (X - CX) * ca + (Z - CZ) * sa; lz = -(X - CX) * sa + (Z - CZ) * ca
st_out = zig_r + 24.0; st_in = half + 8.0 - 3.0
stair = (np.abs(lz) <= 5.0) & (lx <= st_out) & (lx >= st_in)
stair_h = zig['y'] + (zig['top_y'] - zig['y']) * np.clip((st_out - lx) / (st_out - st_in), 0, 1)
nav_h = np.where(stair, np.maximum(stair_h, zig['y']), nav_h)
zig['stair'] = dict(out=st_out, inn=st_in, width=10.0)
zig_foot = np.hypot(X - CX, Z - CZ) < zig_r * 1.42
# bridges into nav
bridge_mask = np.zeros((N, N), bool)
for b in bridges:
    ca, sa = math.cos(b['rot']), math.sin(b['rot'])
    lx = (X - b['x']) * ca + (Z - b['z']) * sa; lz = -(X - b['x']) * sa + (Z - b['z']) * ca
    m = (np.abs(lx) <= b['length'] / 2) & (np.abs(lz) <= b['width'] / 2)
    nav_h = np.where(m, b['y'], nav_h); bridge_mask |= m

# ---------------------------------------------------------------- walkability
gx = np.zeros((N, N)); gz = np.zeros((N, N))
gx[:, 1:] = np.abs(np.diff(nav_h, axis=1)); gz[1:, :] = np.abs(np.diff(nav_h, axis=0))
slope = np.maximum(np.maximum(gx, np.roll(gx, -1, 1)), np.maximum(gz, np.roll(gz, -1, 0)))
walk = (slope < 1.25) & ~occupied & (shore > 4)
deep = (water_y > nav_h + 0.25) & ~bridge_mask
walk &= ~deep
walk &= ~((nav_h < 0.4) & (shore < 20))
# ziggurat interior blocked except tiers tops reachable via stair (slope test handles walls)
walk[:1, :] = walk[-1:, :] = False; walk[:, :1] = walk[:, -1:] = False

# ---------------------------------------------------------------- spawn point on the beach (SW)
best = None
for a in np.linspace(2.0, 3.2, 40):
    for r in np.arange(330, 440, 2):
        x, z = r * np.cos(a), r * np.sin(a)
        i, j = to_ij(x, z)
        if 0 < i < N - 1 and 0 < j < N - 1 and walk[j, i] and shore[j, i] > 22 and shore[j, i] < 40 and h[j, i] > 1.0:
            best = (x, z, a); break
    if best: break
sx, sz, sa = best
# reachability from spawn (4-connected flood)
lab, nl = ndimage.label(walk)
si, sj = to_ij(sx, sz)
reach = lab == lab[sj, si]
print('spawn', sx, sz, 'reachable cells', reach.sum(), 'of walk', walk.sum())
# remove buildings' interior nav; city reach stats
city_reach = (reach & in_city).sum() / max(1, (walk & in_city).sum())
print('city reach fraction', round(city_reach, 3))

# ---------------------------------------------------------------- enviro lights on buildings
lights = []
for b in buildings:
    if rng.random() < 0.55:
        arr, mn = foot[b['name']]; s = b['scale']
        jj, ii = np.nonzero(arr)
        k = rng.integers(0, len(ii))
        lx = (ii[k] + mn[0] + 0.5) * s; lz = (jj[k] + mn[1] + 0.5) * s
        rot = b['rot']
        wx = b['x'] + lx * math.cos(rot) + lz * math.sin(rot); wz = b['z'] - lx * math.sin(rot) + lz * math.cos(rot)
        lights.append(dict(x=wx, z=wz, y=b['y'] + float(rng.uniform(5, 14))))
print('lights', len(lights))

# ---------------------------------------------------------------- export
mask = np.zeros((N, N, 4), np.uint8)
mask[..., 0] = (street_mask & ~water_body) * 255                     # street
mask[..., 1] = ((plaza | zig_foot) & in_city) * 255                    # plaza stone
sand = np.clip((32 - shore) / 18, 0, 1) * (shore > -10) * (~in_city)
pond_shore = ndimage.binary_dilation(water_body, iterations=3) & ~water_body
mask[..., 2] = np.clip(sand * 255 + pond_shore * 200, 0, 255).astype(np.uint8)  # sand/mud
mask[..., 3] = (in_city * 255).astype(np.uint8)
Image.fromarray(mask, 'RGBA').save(f'{OUT}/mask.png')
h.astype(np.float32).tofile(f'{OUT}/height.f32')
nav_h.astype(np.float32).tofile(f'{OUT}/navheight.f32')
water_y.astype(np.float32).tofile(f'{OUT}/water.f32')
Image.fromarray(((walk & reach) * 255).astype(np.uint8)).save(f'{OUT}/walk.png')
meta = dict(N=N, cell=CELL, half=HALF, city=dict(x=CX, z=CZ, r=CITY_R, levels=LEVELS), spawn=dict(x=sx, z=sz, y=float(sample(h, sx, sz)), face=float(sa + math.pi)),
            ziggurat=zig, ponds=ponds, bridges=bridges, buildings=buildings, lights=lights,
            avenue_angles=[float(spoke_off + k * 2 * math.pi / NSPOKE) for k in range(NSPOKE)])
json.dump(meta, open(f'{OUT}/world.json', 'w'))
# preview
pv = np.zeros((N, N, 3))
hn = (h - h.min()) / (h.max() - h.min())
pv[...] = hn[..., None] * 0.8
pv[street_mask] = [0.6, 0.6, 0.2]
pv[occupied] = [0.8, 0.3, 0.2]
pv[water_body] = [0.2, 0.3, 0.9]
pv[shore < 0] = [0.05, 0.05, 0.3]
pv[(~(walk & reach)) & in_city & ~occupied & ~water_body] *= 0.4
pv[bridge_mask] = [1, 1, 1]
im = Image.fromarray((pv * 255).astype(np.uint8)).resize((1024, 1024), Image.NEAREST)
d = ImageDraw.Draw(im)
px, pz = (sx + HALF) / CELL * 2, (sz + HALF) / CELL * 2
d.ellipse((px - 6, pz - 6, px + 6, pz + 6), fill=(0, 255, 0))
im.save('/tmp/world_preview.png')
print('done')
