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
        write(P, N, U, I, os.path.join(a.outdir, name + '.glb'))
        man[name] = dict(min=mn.tolist(), max=mx.tolist(), tris=int(len(I)))
        print(f'{name}: tris={len(I)} size={np.round(mx - mn, 1).tolist()} miny={mn[1]:.2f}')
    json.dump(man, open(os.path.join(a.outdir, 'manifest.json'), 'w'), indent=1)
