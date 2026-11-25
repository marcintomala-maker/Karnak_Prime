#!/usr/bin/env python3
"""md5mesh (bind pose) -> static glb. Skips meshes whose shader matches --skip substrings."""
import sys, re, os, argparse
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from iqe2glb import GLB, find_tex, qmat
from scipy.spatial.transform import Rotation

def q_from_xyz(x, y, z):
    t = 1.0 - x*x - y*y - z*z
    w = 0.0 if t < 0 else -np.sqrt(t)
    return np.array([x, y, z, w])

def main():
    ap = argparse.ArgumentParser(); ap.add_argument('inp'); ap.add_argument('out')
    ap.add_argument('--search', nargs='*', default=[]); ap.add_argument('--skip', nargs='*', default=[])
    a = ap.parse_args()
    txt = open(a.inp).read()
    jt = re.search(r'joints\s*\{(.*?)\}', txt, re.S).group(1)
    joints = []
    for m in re.finditer(r'"([^"]*)"\s+(-?\d+)\s*\(\s*([-\d.e]+)\s+([-\d.e]+)\s+([-\d.e]+)\s*\)\s*\(\s*([-\d.e]+)\s+([-\d.e]+)\s+([-\d.e]+)\s*\)', jt):
        p = np.array([float(m.group(i)) for i in (3, 4, 5)])
        q = q_from_xyz(*[float(m.group(i)) for i in (6, 7, 8)])
        joints.append((p, q))
    g = GLB(); J = g.j
    R = np.array([[0, -1, 0], [0, 0, 1], [-1, 0, 0]], dtype=np.float64)
    J['nodes'].append(dict(name='QuakeRoot', rotation=Rotation.from_matrix(R).as_quat().tolist(), children=[]))
    J['scenes'][0]['nodes'] = [0]
    prims = []; mats = {}
    for mb in re.finditer(r'mesh\s*\{(.*?)\n\}', txt, re.S):
        body = mb.group(1)
        shader = re.search(r'shader\s+"([^"]*)"', body).group(1)
        if any(s in shader for s in a.skip): continue
        verts = [(float(m.group(2)), float(m.group(3)), int(m.group(4)), int(m.group(5))) for m in
                 re.finditer(r'vert\s+(\d+)\s*\(\s*([-\d.e]+)\s+([-\d.e]+)\s*\)\s*(\d+)\s+(\d+)', body)]
        tris = [(int(m.group(2)), int(m.group(3)), int(m.group(4))) for m in re.finditer(r'tri\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)', body)]
        wts = [(int(m.group(2)), float(m.group(3)), np.array([float(m.group(i)) for i in (4, 5, 6)])) for m in
               re.finditer(r'weight\s+(\d+)\s+(\d+)\s+([-\d.e]+)\s*\(\s*([-\d.e]+)\s+([-\d.e]+)\s+([-\d.e]+)\s*\)', body)]
        vp = np.zeros((len(verts), 3)); vt = np.zeros((len(verts), 2))
        for i, (u, v, ws, wc) in enumerate(verts):
            pos = np.zeros(3)
            for k in range(wc):
                jn, bias, wp = wts[ws + k]; jp, jq = joints[jn]
                pos += (jp + qmat(jq) @ wp) * bias
            vp[i] = pos; vt[i] = (u, v)
        fm = np.array(tris, dtype=np.uint32)[:, [0, 2, 1]]
        # normals
        vn = np.zeros_like(vp)
        fn = np.cross(vp[fm[:, 1]] - vp[fm[:, 0]], vp[fm[:, 2]] - vp[fm[:, 0]])
        for c in range(3): np.add.at(vn, fm[:, c], fn)
        vn /= np.maximum(np.linalg.norm(vn, axis=1, keepdims=True), 1e-9)
        if shader not in mats:
            tex = find_tex(shader, a.search, os.path.dirname(a.inp))
            m = dict(name=os.path.basename(shader), pbrMetallicRoughness=dict(metallicFactor=0.0, roughnessFactor=1.0))
            if tex:
                ti, _ = g.image(tex, 1024); m['pbrMetallicRoughness']['baseColorTexture'] = dict(index=ti)
            else: print('  ! no tex', shader)
            J['materials'].append(m); mats[shader] = len(J['materials']) - 1
        attrs = dict(POSITION=g.acc(vp.astype(np.float32), 5126, 'VEC3', 34962, minmax=True),
                     NORMAL=g.acc(vn.astype(np.float32), 5126, 'VEC3', 34962),
                     TEXCOORD_0=g.acc(vt.astype(np.float32), 5126, 'VEC2', 34962))
        prims.append(dict(attributes=attrs, indices=g.acc(fm.reshape(-1), 5125, 'SCALAR', 34963), material=mats[shader]))
        print(' mesh', shader, len(verts))
    J['meshes'].append(dict(name='md5', primitives=prims))
    J['nodes'].append(dict(name='Mesh', mesh=0)); J['nodes'][0]['children'].append(1)
    g.write(a.out)

if __name__ == '__main__': main()
