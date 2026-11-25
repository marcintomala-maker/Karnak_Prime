import plistlib, json, re, sys
def rect(s): return [int(float(x)) for x in re.findall(r'-?[\d.]+', s)]
def conv(src, out, scale=1.0):
    d = plistlib.load(open(src, 'rb')); fr = {}
    for k, v in d['frames'].items():
        r = rect(v.get('frame') or v.get('textureRect')); off = rect(v.get('offset', '{0,0}')) if 'offset' in v else [0, 0]
        src_size = rect(v.get('sourceSize', '{0,0}')); scr = rect(v.get('sourceColorRect', '{{0,0},{0,0}}'))
        fr[k] = dict(x=r[0]*scale, y=r[1]*scale, w=r[2]*scale, h=r[3]*scale, rotated=bool(v.get('rotated', False)), src_w=src_size[0]*scale, src_h=src_size[1]*scale, src_x=scr[0]*scale, src_y=scr[1]*scale)
    json.dump(fr, open(out, 'w'), indent=0); print(out, len(fr))
conv(*sys.argv[1:3], float(sys.argv[3]) if len(sys.argv) > 3 else 1.0)
