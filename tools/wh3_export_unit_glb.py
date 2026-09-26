# -*- coding: utf-8 -*-
"""WH3 单位反向导出：VMD/WSMODEL/RMV2 + 骨架 + 动画 + 贴图 -> 自包含蒙皮 GLB。

用法:
  python wh3_export_unit_glb.py <目标> --out <目录> [选项]

  <目标> 可以是:
    - pack 内 VMD 路径:  variantmeshes/.../xxx.variantmeshdefinition
    - pack 内 wsmodel 路径 / rigid_model_v2 路径
    - VMD 名（自动在 pack 索引里找 <名>.variantmeshdefinition）
    - 本地磁盘文件路径（同上三种后缀）

  --clips a,b,c   内嵌动画 clip 名（stem 或内部路径），'auto' 自动挑常用集
  --lod N         LOD 等级（默认 0 最高细节）
  --no-tex        不嵌贴图（跳过 texconv DDS->PNG）
  --no-anim       不嵌动画
  --name X        输出文件名前缀

产物: <out>/<name>.glb + <out>/files/ 提取的中间文件
"""
import json
import os
import struct
import subprocess
import sys
import tempfile
from pathlib import Path
import xml.etree.ElementTree as ET

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from rmv2_convert import parse_rmv2
from parse_anim_skeleton import parse_anim, world_transforms
from parse_anim_clip import parse_anim_clip, resolve_locals

WORKSPACE = Path(__file__).resolve().parents[1]
TEXCONV = WORKSPACE / 'tools' / 'texconv.exe'

try:
    from export_gamedata import iter_pack_index, read_pack_payload, GAME_DATA
except Exception:
    GAME_DATA = None


# ------------------------------------------------------------------ pack resolve

_IDX = None


def pack_index():
    global _IDX
    if _IDX is None:
        _IDX = {}
        for p in sorted(GAME_DATA.glob('*.pack')):
            try:
                for e in iter_pack_index(p):
                    _IDX.setdefault(e.name.casefold(), []).append((p, e))
            except Exception as exc:
                print('index fail', p.name, exc)
    return _IDX


def resolve_payload(ref, out_files):
    """ref = 磁盘路径 | pack 内路径 | 文件名 stem。返回 (内部名, bytes)。"""
    ref = str(ref)
    if Path(ref).is_file():
        return Path(ref).name, Path(ref).read_bytes()
    key = ref.replace('\\', '/').casefold().lstrip('/')
    idx = pack_index()
    hits = idx.get(key)
    if not hits:
        # stem / suffix 模糊命中
        hits = [(p, e) for n, lst in idx.items() if n.endswith(key)
                for p, e in lst]
    if not hits and not key.endswith(('.anim', '.dds', '.xml', '.wsmodel')):
        # 裸名：按文件名匹配
        hits = [(p, e) for n, lst in idx.items()
                if Path(n).name == key or Path(n).stem == key
                for p, e in lst]
    if not hits:
        raise FileNotFoundError(ref)
    p, e = hits[0]
    payload = read_pack_payload(p, e)
    if out_files is not None:
        dest = out_files / e.name.replace('/', '__')
        dest.write_bytes(payload)
    return e.name, payload


def grep_pack(pat):
    idx = pack_index()
    return sorted(n for n in idx if pat.casefold() in n)


# ------------------------------------------------------------------ format parse

def parse_vmd(payload):
    """VMD xml -> [(slot_name, wsmodel_path), ...] 每槽位取第一个 variant。"""
    root = ET.fromstring(payload.decode('utf-8', 'replace'))
    out = []
    for slot in root.iter('SLOT'):
        for vm in slot.iter('VARIANT_MESH'):
            model = vm.get('model')
            if model:
                out.append((slot.get('name', '?'), model.replace('\\', '/')))
                break
    return out


def parse_wsmodel(payload):
    """wsmodel xml -> (rmv2_path, [material paths])."""
    root = ET.fromstring(payload.decode('utf-8', 'replace'))
    geo = root.find('geometry')
    mats = [m.text.strip() for m in root.iter('material') if m.text]
    return geo.text.strip().replace('\\', '/'), mats


def decode_verts(raw, count, vsize):
    """-> pos f32[n,3], uv f32[n,2], nrm f32[n,3], boneidx u8[n,4], bonew f32[n,4]"""
    a = np.frombuffer(raw, dtype=np.uint8).reshape(count, vsize)
    if vsize == 36:          # v8 cinematic
        pos4 = a[:, 0:8].copy().view('<f2').reshape(count, 4).astype(np.float32)
        pos = pos4[:, :3] * pos4[:, 3:4]
        bi = a[:, 8:12].copy(); bw = a[:, 12:16].copy()
        nrm_b = a[:, 16:20].astype(np.float32)
        uv = a[:, 20:24].copy().view('<f2').reshape(count, 2).astype(np.float32)
    elif vsize == 32:        # v7 weighted: 两种布局
        pos = a[:, 0:12].copy().view('<f4').reshape(count, 3)
        if np.isfinite(pos).all() and np.abs(pos).max() < 1000:
            bi = a[:, 12:16].copy(); bw = a[:, 16:20].copy()
            nrm_b = a[:, 20:24].astype(np.float32)
            uv = a[:, 24:28].copy().view('<f2').reshape(count, 2).astype(np.float32)
        else:
            pos = a[:, 0:6].copy().view('<f2').reshape(count, 3).astype(np.float32)
            bi = a[:, 8:12].copy(); bw = a[:, 12:16].copy()
            nrm_b = a[:, 16:20].astype(np.float32)
            uv = a[:, 20:24].copy().view('<f2').reshape(count, 2).astype(np.float32)
    else:
        raise ValueError('unknown vsize %d' % vsize)
    nrm = (nrm_b[:, :3] / 255.0) * 2.0 - 1.0
    bw = bw.astype(np.float32) / 255.0
    s = bw.sum(1, keepdims=True)
    s[s == 0] = 1.0
    return pos.astype(np.float32), uv, nrm.astype(np.float32), bi, bw / s


# ------------------------------------------------------------------ quat math

def qmul(a, b):
    ax, ay, az, aw = a; bx, by, bz, bw = b
    return [aw*bx + ax*bw + ay*bz - az*by,
            aw*by - ax*bz + ay*bw + az*bx,
            aw*bz + ax*by - ay*bx + az*bw,
            aw*bw - ax*bx - ay*by - az*bz]


def qconj(q):
    return [-q[0], -q[1], -q[2], q[3]]


def qrot(q, v):
    qc = qconj(q)
    return qmul(qmul(q, [v[0], v[1], v[2], 0]), qc)[:3]


def qnorm(q):
    n = float(np.sqrt(sum(x * x for x in q))) or 1.0
    return [x / n for x in q]


def quat_to_mat4(q, t):
    x, y, z, w = q
    R = np.array([
        [1 - 2*(y*y + z*z), 2*(x*y - z*w), 2*(x*z + y*w)],
        [2*(x*y + z*w), 1 - 2*(x*x + z*z), 2*(y*z - x*w)],
        [2*(x*z - y*w), 2*(y*z + x*w), 1 - 2*(x*x + y*y)]], dtype=np.float64)
    M = np.eye(4)
    M[:3, :3] = R
    M[:3, 3] = t
    return M


# ------------------------------------------------------------------ GLB writer

COMP_F32, COMP_U8, COMP_U16, COMP_U32 = 5126, 5121, 5123, 5125


class Glb:
    def __init__(self):
        self.bin = bytearray()
        self.views = []
        self.accessors = []

    def view(self, data, target=None):
        off = len(self.bin)
        self.bin += data
        while len(self.bin) % 4:
            self.bin.append(0)
        v = {'buffer': 0, 'byteOffset': off, 'byteLength': len(data)}
        if target:
            v['target'] = target
        self.views.append(v)
        return len(self.views) - 1

    def acc(self, arr, ctype, atype, target=None, minmax=False):
        arr = np.ascontiguousarray(arr)
        vi = self.view(arr.tobytes(), target)
        a = {'bufferView': vi, 'componentType': ctype,
             'count': int(arr.shape[0] if arr.ndim > 1 else arr.size),
             'type': atype}
        if minmax:
            a['min'] = [float(x) for x in arr.reshape(arr.shape[0], -1).min(0)]
            a['max'] = [float(x) for x in arr.reshape(arr.shape[0], -1).max(0)]
        self.accessors.append(a)
        return len(self.accessors) - 1

    def write(self, gltf, path):
        gltf = dict(gltf)
        gltf.setdefault('asset', {'version': '2.0', 'generator': 'wh3_export_unit_glb'})
        gltf['accessors'] = self.accessors
        gltf['bufferViews'] = self.views
        gltf['buffers'] = [{'byteLength': len(self.bin)}]
        js = json.dumps(gltf, separators=(',', ':')).encode()
        while len(js) % 4:
            js += b' '
        out = bytearray()
        out += struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(self.bin))
        out += struct.pack('<II', len(js), 0x4E4F534A) + js
        out += struct.pack('<II', len(self.bin), 0x004E4942) + self.bin
        Path(path).write_bytes(bytes(out))


# ------------------------------------------------------------------ textures

def dds_to_png(dds_bytes, stem, workdir):
    """texconv.exe -> PNG bytes；失败返回 None。"""
    workdir = Path(workdir)
    workdir.mkdir(parents=True, exist_ok=True)
    src = workdir / (stem + '.dds')
    src.write_bytes(dds_bytes)
    try:
        r = subprocess.run(
            [str(TEXCONV), '-ft', 'PNG', '-y', '-o', str(workdir), str(src)],
            capture_output=True, timeout=120)
        png = workdir / (stem + '.png')
        if png.exists() and png.stat().st_size > 100:
            return png.read_bytes()
        print('texconv rc=%d %s' % (r.returncode, r.stdout[-200:]))
    except Exception as exc:
        print('texconv fail:', exc)
    return None


BASE_TEX_KEYS = ('base_colour', 'basecolor', 'diffuse')


def pick_base_colour(texs):
    """texs: [(ttype, path)] -> 最适合做 baseColor 的路径。"""
    for _t, p in texs:
        if any(k in p.casefold() for k in BASE_TEX_KEYS):
            return p
    return texs[0][1] if texs else None


# ------------------------------------------------------------------ auto clips

AUTO_CLIP_PATTERNS = [
    'stand_idle_01', 'attack_01', 'fly_stand_01', 'fly_charge_01',
    'move_01', 'run_01', 'death_01', 'walk_01',
]


def auto_clips(skel_name, limit=4, subdir=''):
    hits = [n for n in grep_pack('animations/battle/%s/%s' % (skel_name.casefold(), subdir))
            if n.endswith('.anim')]
    picked = []
    for pat in AUTO_CLIP_PATTERNS:
        for n in hits:
            stem = Path(n).stem
            if stem.endswith(pat) and n not in picked:
                picked.append(n)
                break
    if not picked:
        picked = hits[:limit]
    return picked[:limit]


# ------------------------------------------------------------------ main export

def collect_rmv2_refs(target, out_files):
    """target -> [rmv2 内部路径]（VMD/WSMODEL 链解开）。"""
    if target.endswith('.variantmeshdefinition') or (
            not Path(target).suffix and not Path(target).is_file()):
        if not target.endswith('.variantmeshdefinition'):
            # 裸名 -> 找 VMD
            hits = grep_pack('/' + target + '.variantmeshdefinition')
            if not hits:
                hits = grep_pack(target + '.variantmeshdefinition')
            if not hits:
                raise FileNotFoundError('VMD not found: ' + target)
            print('vmd hits:', hits)
            target = hits[0]
        _n, vmd = resolve_payload(target, out_files)
        refs = []
        for slot, wsm in parse_vmd(vmd):
            if slot.startswith('stump'):      # 断肢替换件不进主模型
                continue
            if wsm.lower().endswith('.rigid_model_v2'):
                refs.append((slot, wsm))
                continue
            try:
                _n2, ws = resolve_payload(wsm, out_files)
                rmv2_path, _mats = parse_wsmodel(ws)
            except Exception as exc:
                print('slot %s skip %s: %s' % (slot, wsm, exc))
                continue
            refs.append((slot, rmv2_path))
        return refs
    if target.endswith('.wsmodel'):
        _n, ws = resolve_payload(target, out_files)
        rmv2_path, _ = parse_wsmodel(ws)
        return [('body', rmv2_path)]
    return [('body', target)]


def export_unit(target, out_dir, clips=None, lod=0, no_tex=False,
                no_anim=False, name=None, anim_dir=''):
    out_dir = Path(out_dir)
    files_dir = out_dir / 'files'
    files_dir.mkdir(parents=True, exist_ok=True)

    refs = collect_rmv2_refs(target, files_dir)
    print('rmv2 refs:', refs)

    # ---- rmv2 网格收集 ----
    meshes = []          # (slot, mesh dict)
    skel_name = None
    for slot, rmv2_path in refs:
        iname, payload = resolve_payload(rmv2_path, files_dir)
        # parse_rmv2 吃文件路径：物化到 files/ 再解析
        lp = files_dir / iname.replace('/', '__')
        if not lp.exists():
            lp.write_bytes(payload)
        d = parse_rmv2(lp)
        if not d['skeleton']:
            print('skip skeleton-less prop', rmv2_path)
            continue
        skel_name = skel_name or d['skeleton']
        assert d['skeleton'] == skel_name, (d['skeleton'], skel_name)
        lod_models = d['models'][lod] if lod < len(d['models']) else d['models'][0]
        for mi, m in enumerate(lod_models):
            vsize = (m['index_off'] - m['vertex_off']) // m['vertex_count']
            if vsize not in (32, 36):
                print('skip non-weighted mesh vsize', vsize)
                continue
            raw_v = d['bytes'][m['vertex_off']:m['index_off']]
            raw_i = d['bytes'][m['index_off']:m['index_off'] + m['index_count'] * 2]
            pos, uv, nrm, bi, bw = decode_verts(raw_v, m['vertex_count'], vsize)
            idx = np.frombuffer(raw_i, dtype='<u2').copy().astype(np.uint32)
            texs = m['material']['textures']
            meshes.append({
                'slot': slot, 'name': '%s_%s_%d' % (Path(rmv2_path).stem, slot, mi),
                'pos': pos, 'uv': uv, 'nrm': nrm, 'bi': bi, 'bw': bw,
                'idx': idx, 'texs': texs,
            })
    print('meshes:', [(m['name'], len(m['pos'])) for m in meshes])
    if not meshes:
        raise RuntimeError('no weighted meshes found')
    nb = int(max(int(m['bi'].max()) for m in meshes)) + 1
    print('skeleton:', skel_name, 'max bone idx:', nb)

    # ---- 骨架 ----
    sk_iname, sk_payload = resolve_payload(
        'animations/skeletons/%s.anim' % skel_name, files_dir)
    sk_file = files_dir / sk_iname.replace('/', '__')
    if not sk_file.exists():
        sk_file.write_bytes(sk_payload)
    skel = parse_anim(sk_file)
    bones = skel['bones']
    wp, wq = world_transforms(skel, 0)      # frame0 = bind pose

    # 局部 TRS + IBM
    node_trs = []
    ibms = np.zeros((len(bones), 16), dtype=np.float32)
    for i, b in enumerate(bones):
        par = b['parent']
        if par < 0:
            lp_, lq_ = wp[i], qnorm(wq[i])
        else:
            lp_ = qrot(qconj(wq[par]), [wp[i][0] - wp[par][0],
                                        wp[i][1] - wp[par][1],
                                        wp[i][2] - wp[par][2]])
            lq_ = qnorm(qmul(qconj(wq[par]), wq[i]))
        node_trs.append((lp_, lq_))
        M = quat_to_mat4(qnorm(wq[i]), wp[i])
        ibms[i] = np.linalg.inv(M).T.reshape(16)   # glTF 列主序

    # ---- 贴图 ----
    images = []         # {name, bufferView, mimeType}
    textures = []       # {source}
    img_cache = {}
    mesh_tex = []
    if not no_tex:
        for m in meshes:
            base = pick_base_colour(m['texs'])
            png_key = None
            if base:
                if base in img_cache:
                    png_key = img_cache[base]
                else:
                    try:
                        _tn, dds = resolve_payload(base, files_dir)
                        png = dds_to_png(dds, Path(base).stem,
                                         out_dir / 'tex')
                        if png:
                            png_key = png
                    except Exception as exc:
                        print('tex miss', base, exc)
            img_cache[base] = png_key
            mesh_tex.append(png_key)
    else:
        mesh_tex = [None] * len(meshes)

    # ---- glTF 组装 ----
    g = Glb()
    # 贴图去重：bytes 可哈希，相同 PNG 只嵌一份
    uniq_png = {}
    for t in mesh_tex:
        if t:
            uniq_png.setdefault(t, len(uniq_png))
    tex_of_mesh = {mi: uniq_png[t] for mi, t in enumerate(mesh_tex) if t}
    for png in uniq_png:
        vi = g.view(png)
        images.append({'name': 'tex%d' % len(images),
                       'bufferView': vi, 'mimeType': 'image/png'})
    for i in range(len(images)):
        textures.append({'source': i})

    materials = []
    primitives_per_mesh = []
    for mi, m in enumerate(meshes):
        mat = {'name': m['name'],
               'pbrMetallicRoughness': {'metallicFactor': 0.0,
                                        'roughnessFactor': 1.0},
               'doubleSided': True}
        if mi in tex_of_mesh:
            mat['pbrMetallicRoughness']['baseColorTexture'] = {
                'index': tex_of_mesh[mi]}
        materials.append(mat)

        a_pos = g.acc(m['pos'], COMP_F32, 'VEC3', 34962, minmax=True)
        a_nrm = g.acc(m['nrm'], COMP_F32, 'VEC3', 34962)
        a_uv = g.acc(m['uv'], COMP_F32, 'VEC2', 34962)
        a_j = g.acc(m['bi'], COMP_U8, 'VEC4', 34962)
        a_w = g.acc(m['bw'], COMP_F32, 'VEC4', 34962)
        a_i = g.acc(m['idx'].reshape(-1, 1), COMP_U32, 'SCALAR', 34963)
        primitives_per_mesh.append({
            'attributes': {'POSITION': a_pos, 'NORMAL': a_nrm,
                           'TEXCOORD_0': a_uv, 'JOINTS_0': a_j,
                           'WEIGHTS_0': a_w},
            'indices': a_i, 'material': mi})

    gltf_meshes = [{'name': m['name'], 'primitives': [p]}
                   for m, p in zip(meshes, primitives_per_mesh)]

    # 节点：骨架层级 + mesh 节点（场景根下并列）
    nodes = []
    bone_node = {}
    children_of = {}
    roots = []
    for i, b in enumerate(bones):
        lp_, lq_ = node_trs[i]
        ni = len(nodes)
        bone_node[i] = ni
        nodes.append({'name': b['name'],
                      'translation': [float(x) for x in lp_],
                      'rotation': [float(x) for x in lq_]})
        if b['parent'] < 0:
            roots.append(ni)
        else:
            children_of.setdefault(b['parent'], []).append(ni)
    for pi, kids in children_of.items():
        nodes[bone_node[pi]]['children'] = kids
    for k, m in enumerate(meshes):
        nodes.append({'name': m['name'], 'mesh': k, 'skin': 0})

    a_ibm = g.acc(ibms, COMP_F32, 'MAT4')
    skins = [{'joints': [bone_node[i] for i in range(len(bones))],
              'inverseBindMatrices': a_ibm,
              'skeleton': bone_node[0]}]

    scene_nodes = roots + [len(bones) + k for k in range(len(meshes))]
    gltf = {
        'scene': 0,
        'scenes': [{'nodes': scene_nodes}],
        'nodes': nodes,
        'meshes': gltf_meshes,
        'materials': materials,
        'skins': skins,
    }
    if images:
        gltf['images'] = images
        gltf['textures'] = textures
        gltf['samplers'] = [{'magFilter': 9729, 'minFilter': 9987,
                             'wrapS': 10497, 'wrapT': 10497}]

    # ---- 动画 ----
    animations = []
    if not no_anim:
        clip_list = list(clips or [])
        if clips == 'auto':
            clip_list = auto_clips(skel_name, subdir=anim_dir)
        skel_frame = skel['frames'][0]
        name2bone = {b['name']: i for i, b in enumerate(bones)}
        for cref in clip_list:
            try:
                cin, cpl = resolve_payload(cref, files_dir)
                cfile = files_dir / cin.replace('/', '__')
                if not cfile.exists():
                    cfile.write_bytes(cpl)
                clip = parse_anim_clip(cfile)
            except Exception as exc:
                print('clip miss', cref, exc)
                continue
            if clip['skeleton_name'] != skel_name:
                print('clip skeleton mismatch', cin, clip['skeleton_name'])
                continue
            part_idx = max(range(len(clip['parts'])),
                           key=lambda i: len(clip['parts'][i]['frames']))
            nf = len(clip['parts'][part_idx]['frames'])
            if nf == 0:
                continue
            rate = clip['frame_rate'] or 20.0
            times = np.arange(nf, dtype=np.float32) / rate
            # clip 骨序 -> 骨架骨序
            order = [name2bone.get(b['name'], -1) for b in clip['bones']]
            a_t = g.acc(times, COMP_F32, 'SCALAR', minmax=True)
            samplers = []
            channels = []
            for cb, si in enumerate(order):
                if si < 0:
                    continue
                poss = np.zeros((nf, 3), dtype=np.float32)
                quats = np.zeros((nf, 4), dtype=np.float32)
                prev = None
                for f in range(nf):
                    pos, quat = resolve_locals(clip, part_idx, f, skel_frame)
                    p, q = pos[cb], qnorm(quat[cb])
                    if prev is not None and sum(a * b for a, b in zip(q, prev)) < 0:
                        q = [-x for x in q]
                    prev = q
                    poss[f] = p
                    quats[f] = q
                a_p = g.acc(poss, COMP_F32, 'VEC3')
                samplers.append({'input': a_t, 'interpolation': 'LINEAR',
                                 'output': a_p})
                channels.append({'sampler': len(samplers) - 1,
                                 'target': {'node': bone_node[si],
                                            'path': 'translation'}})
                a_q = g.acc(quats, COMP_F32, 'VEC4')
                samplers.append({'input': a_t, 'interpolation': 'LINEAR',
                                 'output': a_q})
                channels.append({'sampler': len(samplers) - 1,
                                 'target': {'node': bone_node[si],
                                            'path': 'rotation'}})
            animations.append({'name': Path(str(cref)).stem,
                               'samplers': samplers, 'channels': channels})
            print('anim %s: %d frames @%g' % (cin, nf, rate))
    if animations:
        gltf['animations'] = animations

    out_name = name or Path(str(target)).stem.replace('.', '_')
    out_path = out_dir / (out_name + '.glb')
    g.write(gltf, out_path)
    print('wrote', out_path, out_path.stat().st_size, 'bytes')


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return
    target = args[0]
    out = 'scratch/wh3_export/out'
    clips, lod, no_tex, no_anim, name, anim_dir = None, 0, False, False, None, ''
    i = 1
    while i < len(args):
        a = args[i]
        if a == '--out':
            out = args[i + 1]; i += 2
        elif a == '--clips':
            v = args[i + 1]
            clips = 'auto' if v == 'auto' else v.split(',')
            i += 2
        elif a == '--lod':
            lod = int(args[i + 1]); i += 2
        elif a == '--name':
            name = args[i + 1]; i += 2
        elif a == '--no-tex':
            no_tex = True; i += 1
        elif a == '--no-anim':
            no_anim = True; i += 1
        elif a == '--anim-dir':
            anim_dir = args[i + 1]; i += 2
        else:
            print('unknown arg', a); i += 1
    export_unit(target, out, clips, lod, no_tex, no_anim, name, anim_dir)


if __name__ == '__main__':
    main()
