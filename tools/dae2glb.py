#!/usr/bin/env python3
"""0 A.D. structural .dae -> merged static glb (geometry + uv0 only, Y-up, meters as-is)
and a JSON manifest with footprint/height. Materials are replaced in-game by a
world-projected sci-fi shader, so no textures are embedded."""
import sys, os, json, glob, argparse
import numpy as np
import collada
sys.path.insert(0, os.path.dirname(__file__))
from iqe2glb import GLB

def load(path):
    c = collada.Collada(path, ignore=[collada.common.DaeUnsupportedError, collada.common.DaeBrokenRefError])
    up = c.assetInfo.upaxis if c.assetInfo else 'Y_UP'
    unit = (c.assetInfo.unitmeter or 1.0) if c.assetInfo else 1.0
    P, N, U, I = [], [], [], []; base = 0
    if c.scene is None: return None
    for geom in c.scene.objects('geometry'):
        for prim in geom.primitives():
            if not isinstance(prim, (collada.triangleset.BoundTriangleSet, collada.polylist.BoundPolylist, collada.polygons.BoundPolygons)):
                continue
            tris = prim.triangleset() if not isinstance(prim, collada.triangleset.BoundTriangleSet) else prim
            if tris.vertex is None or len(tris.vertex_index) == 0: continue
            vi = tris.vertex_index.reshape(-1)
            p = tris.vertex[vi]
            if tris.normal is not None and tris.normal_index is not None:
                n = tris.normal[tris.normal_index.reshape(-1)]
            else:
                a, b, cc = p[0::3], p[1::3], p[2::3]
                fn = np.cross(b - a, cc - a); fn /= np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-9)
                n = np.repeat(fn, 3, axis=0)
            if tris.texcoordset and tris.texcoord_indexset and len(tris.texcoord_indexset) > 0:
                u = tris.texcoordset[0][tris.texcoord_indexset[0].reshape(-1)]
            else:
                u = np.zeros((len(p), 2))
            P.append(p); N.append(n); U.append(u)
            I.append(np.arange(len(p)) + base); base += len(p)
    if not P: return None
    P = np.concatenate(P); N = np.concatenate(N); U = np.concatenate(U)
    if up == 'Z_UP':
        P = P[:, [0, 2, 1]] * np.array([1, 1, -1]); N = N[:, [0, 2, 1]] * np.array([1, 1, -1])
    elif up == 'X_UP':
        P = P[:, [1, 0, 2]] * np.array([-1, 1, 1]); N = N[:, [1, 0, 2]] * np.array([-1, 1, 1])
    I = np.arange(len(P), dtype=np.uint32).reshape(-1, 3)
    # fix winding vs normals
    a, b, cc = P[I[:, 0]], P[I[:, 1]], P[I[:, 2]]
    fn = np.cross(b - a, cc - a); avg = N[I[:, 0]] + N[I[:, 1]] + N[I[:, 2]]
    if (np.einsum('ij,ij->i', fn, avg) < 0).mean() > 0.5: I = I[:, [0, 2, 1]]
    # weld duplicate vertices for smaller files
    key = np.round(np.concatenate([P, N * 100, U * 1000], axis=1), 4)
    uniq, inv = np.unique(key, axis=0, return_inverse=True)
    inv = inv.reshape(-1)
    P2 = np.zeros((len(uniq), 3)); N2 = np.zeros((len(uniq), 3)); U2 = np.zeros((len(uniq), 2))
    P2[inv] = P; N2[inv] = N; U2[inv] = U
    I2 = inv[I.reshape(-1)].reshape(-1, 3).astype(np.uint32)
    return P2.astype(np.float32), N2.astype(np.float32), U2.astype(np.float32), I2

def fill_holes(P, N, U, I, max_dev=0.6):
    """Close open boundary loops (missing ceilings / bottoms the RTS camera never sees).
    Only near-planar loops are capped (fan from the loop centroid)."""
    key = np.round(P, 3)
    uniq, inv = np.unique(key, axis=0, return_inverse=True)
    inv = inv.reshape(-1)
    F = inv[I]
    from collections import defaultdict
    cnt = defaultdict(int); directed = {}
    for f in F:
        for a, b in ((f[0], f[1]), (f[1], f[2]), (f[2], f[0])):
            k = (min(a, b), max(a, b)); cnt[k] += 1; directed[(a, b)] = True
    nxt = defaultdict(list)
    for (a, b) in directed:
        if cnt[(min(a, b), max(a, b))] == 1:
            nxt[b].append(a)        # reversed so the cap winds opposite to its neighbour faces
    used = set(); loops = []
    for start in list(nxt.keys()):
        if start in used: continue
        loop = [start]; used.add(start); cur = start
        for _ in range(4000):
            cand = [v for v in nxt[cur] if v not in used or (v == start and len(loop) > 2)]
            if not cand: break
            v = cand[0]
            if v == start: loops.append(loop); break
            loop.append(v); used.add(v); cur = v
    newP, newN, newU, newI = [], [], [], []
    base = len(P); added = 0
    for loop in loops:
        if len(loop) < 3 or len(loop) > 400: continue
        pts = uniq[loop]
        c = pts.mean(0)
        u_, s_, vt = np.linalg.svd(pts - c)
        n = vt[2]
        dev = np.abs((pts - c) @ n).max()
        ext = np.linalg.norm(pts.max(0) - pts.min(0))
        if dev > max_dev or ext < 0.05: continue
        # orient cap normal consistently with the loop winding
        acc = np.zeros(3)
        for k in range(len(pts)):
            acc += np.cross(pts[k] - c, pts[(k + 1) % len(pts)] - c)
        if np.linalg.norm(acc) < 1e-9: continue
        n = acc / np.linalg.norm(acc)
        # ear-clip in the loop's plane (handles concave outlines without spikes)
        import mapbox_earcut as earcut
        ax = np.cross(n, [1, 0, 0] if abs(n[0]) < 0.9 else [0, 1, 0]); ax /= np.linalg.norm(ax)
        ay = np.cross(n, ax)
        pts2 = np.stack([(pts - c) @ ax, (pts - c) @ ay], axis=1).astype(np.float64)
        try:
            tri = np.asarray(earcut.triangulate_float64(pts2, np.array([len(pts2)], dtype=np.uint32))).reshape(-1, 3)
        except Exception:
            continue
        if len(tri) == 0:
            continue
        ci = base + sum(len(x) for x in newP)
        newP.append(pts); newN.append(np.repeat(n[None], len(pts), 0)); newU.append(np.zeros((len(pts), 2)))
        for t in tri:
            a, b, cc = int(t[0]), int(t[1]), int(t[2])
            # keep cap winding consistent with the loop normal
            if np.dot(np.cross(pts[b] - pts[a], pts[cc] - pts[a]), n) < 0:
                b, cc = cc, b
            newI.append([ci + a, ci + b, ci + cc])
        added += 1
    if not newP:
        return P, N, U, I, 0
    P2 = np.vstack([P] + newP).astype(np.float32); N2 = np.vstack([N] + newN).astype(np.float32)
    U2 = np.vstack([U] + newU).astype(np.float32); I2 = np.vstack([I, np.array(newI, dtype=np.uint32)]).astype(np.uint32)
    return P2, N2, U2, I2, added

def write(P, N, U, I, out):
    g = GLB(); J = g.j
    J['nodes'].append(dict(name='Building', mesh=0)); J['scenes'][0]['nodes'] = [0]
    J['materials'].append(dict(name='structure', pbrMetallicRoughness=dict(metallicFactor=0, roughnessFactor=1)))
    attrs = dict(POSITION=g.acc(P, 5126, 'VEC3', 34962, minmax=True), NORMAL=g.acc(N, 5126, 'VEC3', 34962),
                 TEXCOORD_0=g.acc(U, 5126, 'VEC2', 34962))
    J['meshes'].append(dict(name='b', primitives=[dict(attributes=attrs, indices=g.acc(I.reshape(-1), 5125, 'SCALAR', 34963), material=0)]))
    g.write(out)

if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('outdir'); ap.add_argument('files', nargs='+')
    a = ap.parse_args(); os.makedirs(a.outdir, exist_ok=True)
    man = {}
    for f in a.files:
        name = os.path.splitext(os.path.basename(f))[0]
        try:
            r = load(f)
        except Exception as e:
            print('ERR', name, e); continue
        if r is None: print('empty', name); continue
        P, N, U, I = r
        mn, mx = P.min(0), P.max(0)
        P, N, U, I, nfill = fill_holes(P, N, U, I)
        print(name, 'capped holes:', nfill)
        write(P, N, U, I, os.path.join(a.outdir, name + '.glb'))
        man[name] = dict(min=mn.tolist(), max=mx.tolist(), tris=int(len(I)))
        print(f'{name}: tris={len(I)} size={np.round(mx - mn, 1).tolist()} miny={mn[1]:.2f}')
    json.dump(man, open(os.path.join(a.outdir, 'manifest.json'), 'w'), indent=1)
