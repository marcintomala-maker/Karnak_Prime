#!/usr/bin/env python3
"""Convert Inter-Quake Export (.iqe) models (Unvanquished) into binary glTF (.glb)
with skeleton, skin and all named animations. Textures are embedded as PNG.
Usage: iqe2glb.py in.iqe out.glb [--maxtex 1024] [--search dir ...]
"""
import sys, os, json, struct, argparse, io
import numpy as np
from PIL import Image

def qnorm(q):
    q = np.asarray(q, dtype=np.float64); n = np.linalg.norm(q)
    return q / n if n > 0 else np.array([0, 0, 0, 1.0])

def qmat(q):
    x, y, z, w = q
    return np.array([[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)],
                     [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)],
                     [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]])

def trs(t, q, s):
    m = np.eye(4); m[:3, :3] = qmat(q) * np.asarray(s)[None, :]; m[:3, 3] = t; return m

def parse_pq(parts):
    v = [float(x) for x in parts]
    t = v[0:3]; q = v[3:7] if len(v) >= 7 else [0, 0, 0, 1]
    s = v[7:10] if len(v) >= 10 else [1, 1, 1]
    return np.array(t), qnorm(q), np.array(s)

def parse(path):
    joints, base, meshes, anims = [], [], [], []
    cur_mesh = None; cur_anim = None; cur_frame = None; mode = 'base'
    with open(path, 'r', errors='replace') as f:
        for line in f:
            p = line.strip().split()
            if not p or p[0].startswith('#'): continue
            k = p[0]
            if k == 'joint':
                name = line.split('"')[1] if '"' in line else p[1]
                parent = int(line.split('"')[-1].split()[0]) if '"' in line else int(p[2])
                joints.append((name, parent))
            elif k == 'pq':
                pose = parse_pq(p[1:])
                if mode == 'base': base.append(pose)
                else: cur_frame.append(pose)
            elif k == 'mesh':
                name = line.split('"')[1] if '"' in line else p[1]
                cur_mesh = dict(name=name, material=name, vp=[], vt=[], vn=[], vb=[], fm=[])
                meshes.append(cur_mesh); mode = 'mesh'
            elif k == 'material' and cur_mesh is not None:
                cur_mesh['material'] = line.split('"')[1] if '"' in line else p[1]
            elif k == 'vp': cur_mesh['vp'].append([float(x) for x in p[1:4]])
            elif k == 'vt': cur_mesh['vt'].append([float(x) for x in p[1:3]])
            elif k == 'vn': cur_mesh['vn'].append([float(x) for x in p[1:4]])
            elif k == 'vb':
                vals = p[1:]; pairs = [(int(vals[i]), float(vals[i+1])) for i in range(0, len(vals) - 1, 2)]
                cur_mesh['vb'].append(pairs)
            elif k == 'fm': cur_mesh['fm'].append([int(x) for x in p[1:4]])
            elif k == 'fa':
                raise SystemExit('fa faces unsupported')
            elif k == 'animation':
                name = line.split('"')[1] if '"' in line else (p[1] if len(p) > 1 else 'anim')
                cur_anim = dict(name=name, fps=30.0, loop=False, frames=[]); anims.append(cur_anim); mode = 'anim'
            elif k == 'framerate' and cur_anim is not None: cur_anim['fps'] = float(p[1])
            elif k == 'loop' and cur_anim is not None: cur_anim['loop'] = True
            elif k == 'frame':
                cur_frame = []; cur_anim['frames'].append(cur_frame)
    return joints, base, meshes, anims

SKIP_MESH = set(['Arms'])
TEX_EXT = ['.png', '.webp', '.jpg', '.jpeg', '.tga']

ALIAS={'models/players/builder/skin':'models/players/builder/granger','models/weapons/chaingun/backmetal':'models/weapons/chaingun/blackmetal'}
def find_tex(material, search, src_dir):
    material = ALIAS.get(material, material)
    rel = material.replace('\\', '/')
    cands = []
    for root in search:
        for suf in ['', '_d']:
            for e in TEX_EXT:
                cands.append(os.path.join(root, rel + suf + e))
    base = os.path.basename(rel)
    for suf in ['', '_d']:
        for e in TEX_EXT:
            cands.append(os.path.join(src_dir, base + suf + e))
    for c in cands:
        if os.path.isfile(c): return c
    return None

class GLB:
    def __init__(self):
        self.bin = bytearray(); self.j = dict(asset=dict(version='2.0', generator='karnak iqe2glb'),
            buffers=[], bufferViews=[], accessors=[], nodes=[], meshes=[], materials=[],
            textures=[], images=[], samplers=[dict(magFilter=9729, minFilter=9987, wrapS=10497, wrapT=10497)],
            scenes=[dict(nodes=[])], scene=0)
    def view(self, data, target=None):
        while len(self.bin) % 4: self.bin.append(0)
        off = len(self.bin); self.bin += data
        bv = dict(buffer=0, byteOffset=off, byteLength=len(data))
        if target: bv['target'] = target
        self.j['bufferViews'].append(bv); return len(self.j['bufferViews']) - 1
    def acc(self, arr, ctype, typ, target=None, minmax=False, normalized=False):
        arr = np.ascontiguousarray(arr)
        bv = self.view(arr.tobytes(), target)
        count = arr.shape[0]
        a = dict(bufferView=bv, componentType=ctype, count=count, type=typ)
        if normalized: a['normalized'] = True
        if minmax:
            a['min'] = arr.reshape(count, -1).min(axis=0).tolist(); a['max'] = arr.reshape(count, -1).max(axis=0).tolist()
        self.j['accessors'].append(a); return len(self.j['accessors']) - 1
    def image(self, path, maxtex):
        im = Image.open(path); im.load()
        if im.mode not in ('RGB', 'RGBA'): im = im.convert('RGBA')
        w, h = im.size; s = max(w, h)
        if s > maxtex:
            r = maxtex / s; im = im.resize((max(1, int(w*r)), max(1, int(h*r))), Image.LANCZOS)
        bio = io.BytesIO(); im.save(bio, 'PNG', optimize=True)
        bv = self.view(bio.getvalue())
        self.j['images'].append(dict(bufferView=bv, mimeType='image/png'))
        self.j['textures'].append(dict(sampler=0, source=len(self.j['images']) - 1))
        return len(self.j['textures']) - 1, im.mode == 'RGBA'
    def write(self, path):
        while len(self.bin) % 4: self.bin.append(0)
        self.j['buffers'] = [dict(byteLength=len(self.bin))]
        for k in list(self.j.keys()):
            if isinstance(self.j[k], list) and not self.j[k] and k not in ('scenes',): del self.j[k]
        js = json.dumps(self.j, separators=(',', ':')).encode()
        while len(js) % 4: js += b' '
        total = 12 + 8 + len(js) + 8 + len(self.bin)
        with open(path, 'wb') as f:
            f.write(struct.pack('<III', 0x46546C67, 2, total))
            f.write(struct.pack('<II', len(js), 0x4E4F534A)); f.write(js)
            f.write(struct.pack('<II', len(self.bin), 0x004E4942)); f.write(self.bin)

def convert(inp, out, maxtex=1024, search=(), static=False, skip_anims=(), alpha_cut=None):
    joints, base, meshes, anims = parse(inp)
    src_dir = os.path.dirname(inp)
    g = GLB(); J = g.j
    nj = len(joints)
    # root node converts Quake (Z up, +X forward) to glTF/Godot (Y up, -Z forward)
    # Quake (x,y,z) -> Godot (-y?..) : x_fwd -> -Z ; y_left -> -X ; z_up -> +Y
    # matrix rows map: X_g = -y_q, Y_g = z_q, Z_g = -x_q
    R = np.array([[0, -1, 0], [0, 0, 1], [-1, 0, 0]], dtype=np.float64)
    # quaternion of R
    from scipy.spatial.transform import Rotation
    rq = Rotation.from_matrix(R).as_quat()  # x y z w
    J['nodes'].append(dict(name='QuakeRoot', rotation=rq.tolist(), children=[]))
    root = 0; J['scenes'][0]['nodes'] = [root]
    joint_nodes = []
    have_skel = nj > 0 and not static
    if have_skel:
        for i, (name, parent) in enumerate(joints):
            t, q, s = base[i] if i < len(base) else (np.zeros(3), np.array([0, 0, 0, 1.0]), np.ones(3))
            n = dict(name=name, translation=t.tolist(), rotation=q.tolist())
            if not np.allclose(s, 1): n['scale'] = s.tolist()
            J['nodes'].append(n); joint_nodes.append(len(J['nodes']) - 1)
        for i, (name, parent) in enumerate(joints):
            if parent >= 0: J['nodes'][joint_nodes[parent]].setdefault('children', []).append(joint_nodes[i])
            else: J['nodes'][root]['children'].append(joint_nodes[i])
        glob = [None] * nj
        for i, (name, parent) in enumerate(joints):
            t, q, s = base[i]; m = trs(t, q, s)
            glob[i] = m if parent < 0 else glob[parent] @ m
        ibm = np.array([np.linalg.inv(m).T.reshape(-1) for m in glob], dtype=np.float32)
        ibm_acc = g.acc(ibm, 5126, 'MAT4')
        J['skins'] = [dict(joints=joint_nodes, inverseBindMatrices=ibm_acc, skeleton=joint_nodes[0])]
    # materials
    mat_cache = {}
    def material(name):
        if name in mat_cache: return mat_cache[name]
        tex = find_tex(name, search, src_dir)
        m = dict(name=os.path.basename(name), pbrMetallicRoughness=dict(metallicFactor=0.0, roughnessFactor=1.0))
        if tex:
            ti, has_a = g.image(tex, maxtex)
            m['pbrMetallicRoughness']['baseColorTexture'] = dict(index=ti)
            if has_a and alpha_cut is not None:
                m['alphaMode'] = 'MASK'; m['alphaCutoff'] = alpha_cut
            nt = None
            for e in TEX_EXT:
                for cand in [tex.rsplit('.', 1)[0].removesuffix('_d') + '_n' + e]:
                    if os.path.isfile(cand): nt = cand
            if nt:
                ni, _ = g.image(nt, maxtex); m['normalTexture'] = dict(index=ni)
        else:
            print('  ! no texture for', name, file=sys.stderr)
        J['materials'].append(m); mat_cache[name] = len(J['materials']) - 1
        return mat_cache[name]
    prims = []
    for me in meshes:
        if me['name'] in SKIP_MESH: continue
        if not me['fm'] or not me['vp']: continue
        vp = np.array(me['vp'], dtype=np.float32); nv = len(vp)
        vn = np.array(me['vn'], dtype=np.float32) if len(me['vn']) == nv else None
        vt = np.array(me['vt'], dtype=np.float32) if len(me['vt']) == nv else None
        fm = np.array(me['fm'], dtype=np.uint32)
        # winding: make faces agree with vertex normals (glTF = CCW front)
        if vn is not None:
            a, b, c = vp[fm[:, 0]], vp[fm[:, 1]], vp[fm[:, 2]]
            fn = np.cross(b - a, c - a); avg = vn[fm[:, 0]] + vn[fm[:, 1]] + vn[fm[:, 2]]
            if (np.einsum('ij,ij->i', fn, avg) < 0).mean() > 0.5: fm = fm[:, [0, 2, 1]]
        attrs = dict(POSITION=g.acc(vp, 5126, 'VEC3', 34962, minmax=True))
        if vn is not None: attrs['NORMAL'] = g.acc(vn, 5126, 'VEC3', 34962)
        if vt is not None: attrs['TEXCOORD_0'] = g.acc(vt, 5126, 'VEC2', 34962)
        if have_skel:
            ji = np.zeros((nv, 4), dtype=np.uint16); jw = np.zeros((nv, 4), dtype=np.float32)
            for i in range(nv):
                pairs = me['vb'][i] if i < len(me['vb']) else [(0, 1.0)]
                pairs = sorted(pairs, key=lambda x: -x[1])[:4]
                for k, (jj, ww) in enumerate(pairs): ji[i, k] = min(jj, nj - 1); jw[i, k] = ww
                s = jw[i].sum(); jw[i] = jw[i] / s if s > 0 else [1, 0, 0, 0]
            attrs['JOINTS_0'] = g.acc(ji, 5123, 'VEC4', 34962)
            attrs['WEIGHTS_0'] = g.acc(jw, 5126, 'VEC4', 34962)
        idx = g.acc(fm.reshape(-1), 5125, 'SCALAR', 34963)
        prims.append(dict(attributes=attrs, indices=idx, material=material(me['material'])))
    J['meshes'].append(dict(name=os.path.splitext(os.path.basename(inp))[0], primitives=prims))
    mesh_node = dict(name='Mesh', mesh=0)
    if have_skel: mesh_node['skin'] = 0
    J['nodes'].append(mesh_node); J['nodes'][root]['children'].append(len(J['nodes']) - 1)
    # animations
    if have_skel and anims:
        J['animations'] = []
        for an in anims:
            if an['name'] in skip_anims or not an['frames']: continue
            nf = len(an['frames']); fps = an['fps'] or 30.0
            times = (np.arange(nf, dtype=np.float32) / fps).astype(np.float32)
            tacc = g.acc(times, 5126, 'SCALAR', minmax=True)
            samplers, channels = [], []
            for jn in range(nj):
                T = np.zeros((nf, 3), dtype=np.float32); Q = np.zeros((nf, 4), dtype=np.float32); S = np.ones((nf, 3), dtype=np.float32)
                for fi, fr in enumerate(an['frames']):
                    t, q, s = fr[jn] if jn < len(fr) else base[jn]
                    T[fi] = t; S[fi] = s
                    if fi > 0 and np.dot(Q[fi - 1], q) < 0: q = -q
                    Q[fi] = q
                for path, data, typ in (('translation', T, 'VEC3'), ('rotation', Q, 'VEC4'), ('scale', S, 'VEC3')):
                    if path == 'scale' and np.allclose(S, 1): continue
                    oacc = g.acc(data, 5126, typ)
                    samplers.append(dict(input=tacc, output=oacc, interpolation='LINEAR'))
                    channels.append(dict(sampler=len(samplers) - 1, target=dict(node=joint_nodes[jn], path=path)))
            J['animations'].append(dict(name=an['name'] + ('_loop' if an['loop'] else ''), samplers=samplers, channels=channels))
    g.write(out)
    print(f'{os.path.basename(inp)} -> {os.path.basename(out)}: joints={nj} meshes={len(prims)} anims={len(anims)}')

if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('inp'); ap.add_argument('out')
    ap.add_argument('--maxtex', type=int, default=1024)
    ap.add_argument('--search', nargs='*', default=[])
    ap.add_argument('--static', action='store_true')
    ap.add_argument('--alpha', type=float, default=None)
    a = ap.parse_args()
    convert(a.inp, a.out, a.maxtex, a.search, a.static, alpha_cut=a.alpha)
