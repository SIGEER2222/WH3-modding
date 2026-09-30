# -*- coding: utf-8 -*-
"""RMV2 v8 multi-part writer — G4 slot 化 M0/M1 POC.

不动 rmv2_convert.py：import 其低层原语（read_glb/read_accessor/
_node_world_mats/parse_rmv2/write_weighted_material 等），本文件只新增：
  glb_mesh_parts()    — glb_mesh 的多 part 版：按 prim['material'] 分组，
                        返回 [(mat_idx, mat_name, mesh_tuple)]，顶点序保持文件序
  write_rmv2_v8_mp()  — write_rmv2_v8 的多 part 版：每 LOD 写 N 个 model_block
                        （LOD header mesh_count=N），每 part 克隆 donor 材质块
                        并写各自的贴图槽路径 <texbase>_p<i>_<slot>.dds
  extract_glb_textures_per_material() — 按材质拆图（M2-lite，POC 用 PNG 直出）

约定（与 convert_new_units.convert_unit 对齐）：
- mesh 源=bound.glb（donor 骨架），调用方负责 pos/nrm/tan 的 X 翻转（本文件不做）
- 材质块克隆 donor_model['material']：attachments(逐骨挂载表)/strings/floats/
  ints/vec4s/transform 原样复制；model_name=<texbase>_p<i>
- part 顺序 = GLB materials[] 索引序（决定 part_index↔材质映射，wsmodel 依赖）
- 索引缓冲 u16：单 part 顶点数须 <65536（写时断言）
"""
import io
import json
import struct
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from rmv2_convert import (  # noqa: E402
    read_glb, read_accessor, parse_rmv2, _node_world_mats,
    write_weighted_material, fix_str, normal_to_byte, COMMON_HEADER_SIZE)

TEX_SUFFIX = {27: 'base_colour', 1: 'normal', 29: 'material_map',
              11: 'specular', 3: 'mask'}


def glb_mesh_parts(glb_path, skeleton_json):
    """Multi-part version of rmv2_convert.glb_mesh.

    Returns list of (mat_idx, mat_name, (pos,nrm,uv,tan,idx,bone_idx,w))
    ordered by GLB material index. 顶点序=文件序，idx 已按 part 内局部重基。
    """
    js, binbuf = read_glb(glb_path)
    skel = json.load(open(skeleton_json, encoding='utf-8'))
    name2idx = {b['name']: i for i, b in enumerate(skel['bones'])}
    world = _node_world_mats(js)
    mats = js.get('materials', [])

    groups = {}   # mat_idx -> lists
    for ni, n in enumerate(js['nodes']):
        if 'mesh' not in n:
            continue
        skin_i = n.get('skin')
        M = world.get(ni, np.eye(4))
        R = M[:3, :3]
        jmap = None
        if skin_i is not None:
            jnames = [js['nodes'][j].get('name', '') for j in
                      js['skins'][skin_i]['joints']]
            jmap = np.array([name2idx.get(nm, 0) for nm in jnames],
                            dtype=np.uint8)
        for prim in js['meshes'][n['mesh']].get('primitives', []):
            at = prim['attributes']
            if 'JOINTS_0' not in at or 'POSITION' not in at:
                continue
            mi = prim.get('material')
            mi_key = mi if mi is not None else -1
            pos = read_accessor(js, binbuf, at['POSITION']).astype(np.float64)
            pos = pos @ R.T + M[:3, 3]
            nrm = read_accessor(js, binbuf, at['NORMAL']).astype(np.float64) \
                if 'NORMAL' in at else np.tile([0, 0, 1], (len(pos), 1))
            nrm = nrm @ R.T
            uv = read_accessor(js, binbuf, at['TEXCOORD_0']).astype(np.float64) \
                if 'TEXCOORD_0' in at else np.zeros((len(pos), 2))
            if 'TANGENT' in at:
                tan = read_accessor(js, binbuf, at['TANGENT']).astype(
                    np.float64)
                tan[:, :3] = tan[:, :3] @ R.T
            else:
                tan = None
            joints = read_accessor(js, binbuf, at['JOINTS_0'])
            w = read_accessor(js, binbuf, at['WEIGHTS_0']).astype(np.float64)
            idx = read_accessor(js, binbuf, prim['indices']).reshape(-1) \
                if 'indices' in prim else np.arange(len(pos))
            g = groups.setdefault(mi_key, dict(P=[], N=[], U=[], T=[], I=[],
                                               B=[], W=[], voff=0))
            g['P'].append(pos); g['N'].append(nrm); g['U'].append(uv)
            g['T'].append(tan); g['I'].append(idx + g['voff'])
            g['B'].append(jmap[joints] if jmap is not None else joints)
            g['W'].append(w)
            g['voff'] += len(pos)

    parts = []
    for mi in sorted(groups):
        g = groups[mi]
        pos = np.vstack(g['P']); nrm = np.vstack(g['N']); uv = np.vstack(g['U'])
        idx = np.concatenate(g['I']); weights = np.vstack(g['W'])
        bone_idx = np.vstack(g['B'])
        tan = np.vstack(g['T']) if all(t is not None for t in g['T']) else None
        name = mats[mi].get('name', '') if 0 <= mi < len(mats) else ''
        parts.append((mi, name, (pos, nrm, uv, tan, idx, bone_idx, weights)))
    return parts


def _pack_verts_v8(pos, nrm, uv, tan, bone_idx, weights):
    """36B/vertex V8 interleave — same layout as write_rmv2_v8."""
    n = len(pos)
    ws = 1.0 + np.arange(1024) / 1024.0
    best_err = np.full(n, np.inf)
    best_w = np.ones((n, 1), dtype=np.float16)
    best = np.zeros((n, 3), dtype=np.float16)
    for i in range(1024):
        w = ws[i]
        h = (pos / w).astype(np.float16)
        err = np.abs(pos - h.astype(np.float64) * w).sum(1)
        m = err < best_err
        best_err[m] = err[m]
        best_w[m] = w
        best[m] = h[m]
    pos4 = np.empty((n, 4), dtype=np.float16)
    pos4[:, :3] = best
    pos4[:, 3] = best_w[:, 0]

    bw = np.round(weights * 255).astype(np.int64)
    for i in range(n):
        s = bw[i].sum()
        if s != 255:
            k = int(np.argmax(bw[i]))
            bw[i, k] += 255 - s
    bw = np.clip(bw, 0, 255).astype(np.uint8)

    def byte4(arr3, w=-1.0):
        o = np.empty((n, 4), dtype=np.uint8)
        o[:, :3] = np.round(
            (np.clip(arr3, -1, 1) + 1.0) / 2.0 * 255.0).astype(np.uint8)
        o[:, 3] = normal_to_byte(w)
        return o

    if tan is None:
        tan = np.zeros((n, 4))
        tan[:, 0] = 1.0
    binorm = np.cross(nrm, tan[:, :3]) * tan[:, 3:4]
    uvh = np.empty((n, 2), dtype=np.float16)
    uvh[:, 0] = uv[:, 0]
    uvh[:, 1] = uv[:, 1]
    col = np.full((n, 4), 255, dtype=np.uint8)

    verts = np.empty((n, 36), dtype=np.uint8)
    verts[:, 0:8] = pos4.view(np.uint8).reshape(n, 8)
    verts[:, 8:12] = bone_idx.astype(np.uint8)
    verts[:, 12:16] = bw
    verts[:, 16:20] = byte4(nrm)
    verts[:, 20:24] = uvh.view(np.uint8).reshape(n, 4)
    verts[:, 24:28] = byte4(binorm)
    verts[:, 28:32] = byte4(tan[:, :3])
    verts[:, 32:36] = col
    return verts.tobytes()


def _clone_mat_for_part(donor_mat, texbase, part_idx):
    """Deep-copy donor material dict; rewrite texture paths + model_name."""
    mat = dict(donor_mat)
    mat['attachments'] = [tuple(a) for a in donor_mat['attachments']]
    mat['strings'] = list(donor_mat['strings'])
    mat['floats'] = list(donor_mat['floats'])
    mat['ints'] = list(donor_mat['ints'])
    mat['vec4s'] = list(donor_mat['vec4s'])
    mat['transform'] = bytes(donor_mat['transform'])
    pbase = f"{texbase}_p{part_idx}"
    mat['model_name'] = pbase
    new_tex = []
    for ttype, _ in donor_mat['textures']:
        suffix = TEX_SUFFIX.get(ttype, 'base_colour')
        new_tex.append((ttype, f"{mat['tex_dir']}/{pbase}_{suffix}.dds"))
    mat['textures'] = new_tex
    return mat


def write_rmv2_v8_mp(out_path, skeleton_name, parts, donor_model,
                     lod_levels=None):
    """parts: list of mesh tuples (pos,nrm,uv,tan,idx,bone_idx,w) in rmv2 space,
    one per GLB material group (part order = caller's list order).
    donor_model: parse_rmv2(...)['models'][0][0] — material/template source.
    Every LOD writes len(parts) model_blocks; LOD header mesh_count=N."""
    n_parts = len(parts)
    texbase = donor_model['material']['model_name']  # caller preset
    blocks = []
    for pi, mesh in enumerate(parts):
        pos, nrm, uv, tan, idx, bone_idx, weights = mesh
        n = len(pos)
        assert n < 65536, f'part{pi} verts={n} exceeds u16 index range'
        verts = _pack_verts_v8(pos, nrm, uv, tan, bone_idx, weights)
        idxb = np.asarray(idx, dtype='<u2').tobytes()
        mat = _clone_mat_for_part(donor_model['material'], texbase, pi)
        mat_bytes = write_weighted_material(mat, 4, mat['tex_dir'],
                                            mat['textures'],
                                            mat['model_name'])
        header_size = COMMON_HEADER_SIZE + len(mat_bytes)
        voff = header_size
        ioff = voff + len(verts)
        mesh_size = ioff + len(idxb)
        mins = pos.min(0); maxs = pos.max(0)
        common = struct.pack('<HH5I', donor_model['model_type'], 0, mesh_size,
                             voff, n, ioff, len(idx))
        common += struct.pack('<6f', mins[0], mins[1], mins[2],
                              maxs[0], maxs[1], maxs[2])
        common += donor_model.get('shader_params',
                                  fix_str('default_dry ', 12) + b'\x00' * 20)
        blocks.append(common + mat_bytes + verts + idxb)

    lod_block_bytes = sum(len(b) for b in blocks)
    donor_lods = donor_model.get('lod_headers') or []
    lods = max(1, len(donor_lods))
    if lod_levels:
        lods = min(lods, lod_levels)
    fh = b'RMV2' + struct.pack('<II', 8, lods) + fix_str(skeleton_name, 128)
    lod_header_size = 28
    out = bytearray(fh)
    first_mesh_off = len(fh) + lods * lod_header_size
    for li in range(lods):
        dist = donor_lods[li][4] if li < len(donor_lods) else 10000.0
        lvl = donor_lods[li][5] if li < len(donor_lods) else li
        q = donor_lods[li][6] if li < len(donor_lods) else 0
        off = first_mesh_off + li * lod_block_bytes
        out += struct.pack('<4IfI4B', n_parts,
                           sum(len(p[0]) * 36 for p in parts),
                           sum(len(p[4]) * 2 for p in parts),
                           off, dist, lvl, q, 0, 0, 0)
    for li in range(lods):
        for b in blocks:
            out += b
    Path(out_path).write_bytes(bytes(out))
    return n_parts, lods, len(out)


def extract_glb_textures_per_material(glb_path, cap=2048):
    """M2-lite: {mat_idx: {base,mr,normal: PNG bytes or None}} per material."""
    js, binbuf = read_glb(glb_path)
    texs = js.get('textures', [])
    out = {}
    for mi, mat in enumerate(js.get('materials', [])):
        pbr = mat.get('pbrMetallicRoughness', {})
        rec = {}
        for kind, tref in (('base', pbr.get('baseColorTexture')),
                           ('mr', pbr.get('metallicRoughnessTexture')),
                           ('normal', mat.get('normalTexture'))):
            if not tref:
                continue
            src = texs[tref['index']].get('source')
            if src is None:
                continue
            img = js['images'][src]
            bv = js['bufferViews'][img['bufferView']]
            rec[kind] = binbuf[bv.get('byteOffset', 0):
                               bv.get('byteOffset', 0) + bv['byteLength']]
        out[mi] = rec
    return out


# ---------------- M2: per-part textures PNG -> DDS ----------------

TEXCONV = Path(__file__).resolve().parent / 'texconv.exe'
# 槽位名映射：GLB 贴图 kind -> 成品槽位后缀（5 槽布局同 convert_unit）
KIND2SLOT = {'base': 'base_colour', 'normal': 'normal', 'mr': 'material_map'}
ALL_SLOTS = ['base_colour', 'normal', 'material_map', 'mask', 'specular']
# 缺槽 16x16 占位（与 convert_new_units.py L214-219 同值）
PLACEHOLDER = {'base_colour': (255, 0, 255, 255),
               'normal': (128, 128, 255, 255),
               'material_map': (128, 128, 128, 255),
               'mask': (0, 0, 0, 255),
               'specular': (64, 64, 64, 255)}


def emit_part_texture_pngs(glb_path, parts, texbase, stage_dir):
    """M2 第一步：每 part 5 槽 PNG 到 stage_dir（命名=<texbase>_p<i>_<slot>.png）。

    parts: glb_mesh_parts 返回的 [(mat_idx, mat_name, mesh)]；
    有源图用源图（>2048 等比缩），缺槽走 16x16 占位——与 convert_unit 对齐。
    返回 [(part_index, pbase, {slot: png_name})] 供 manifest/校验。"""
    from PIL import Image
    stage_dir = Path(stage_dir)
    stage_dir.mkdir(parents=True, exist_ok=True)
    tex_sets = extract_glb_textures_per_material(glb_path)
    manifest = []
    for pi, (mi, _name, _mesh) in enumerate(parts):
        pbase = f'{texbase}_p{pi}'
        ts = tex_sets.get(mi, {})
        imgs = {}
        for kind, data in ts.items():
            slot = KIND2SLOT.get(kind)
            if not slot:
                continue
            im = Image.open(io.BytesIO(data)).convert('RGBA')
            if im.size[0] > 2048:
                im = im.resize((2048, 2048), Image.LANCZOS)
            imgs[slot] = im
        png_names = {}
        for slot in ALL_SLOTS:
            im = imgs.get(slot)
            if im is None:
                im = Image.new('RGBA', (16, 16), PLACEHOLDER[slot])
            fn = f'{pbase}_{slot}.png'
            im.save(stage_dir / fn)
            png_names[slot] = fn
        manifest.append((pi, pbase, png_names))
    return manifest


def texconv_dir(stage_dir, tex_dir, texconv=TEXCONV):
    """M2 第二步：stage_dir 全部 PNG -> BC7 DDS 进 tex_dir，返回 dds 文件名表。"""
    import subprocess
    tex_dir = Path(tex_dir)
    tex_dir.mkdir(parents=True, exist_ok=True)
    for png in sorted(Path(stage_dir).glob('*.png')):
        subprocess.run([str(texconv), '-f', 'BC7_UNORM', '-y',
                        '-o', str(tex_dir), str(png)],
                       check=True, capture_output=True)
    return sorted(p.name for p in tex_dir.glob('*.dds'))


# ---------------- M3: wsmodel + per-part xml.material ----------------

def write_part_materials(mat_dir, pack_dir_bs, texbase, n_parts,
                         alpha_on_parts=()):
    """每 part 一份 xml.material（MAT_TEMPLATE，贴图源=<pbase>_<slot>.dds）。

    pack_dir_bs 用反斜杠 pack 相对路径（与 convert_unit 同口径）。
    返回 [(part_index, mat_file_name)]。alpha_on_parts 暂仅改文件名后缀
    （模板内容差异 [需验证]，M4 占位）。"""
    from convert_zerg_assets import MAT_TEMPLATE
    mat_dir = Path(mat_dir)
    mat_dir.mkdir(parents=True, exist_ok=True)
    texdir = pack_dir_bs + r'\tex'
    out = []
    for pi in range(n_parts):
        pbase = f'{texbase}_p{pi}'
        tag = 'alpha_on' if pi in alpha_on_parts else 'alpha_off'
        mat_name = f'{pbase}_weighted4_{tag}.xml.material'
        (mat_dir / mat_name).write_text(
            MAT_TEMPLATE.format(
                name=mat_name[:-len('.material')], texdir=texdir,
                base=pbase), encoding='utf-8')
        out.append((pi, mat_name))
    return out


def write_wsmodel_mp(out_path, geom_rel, mat_entries):
    """wsmodel：geometry + 逐 (part,lod) material 条目。

    geom_rel: rmv2 相对 pack 路径；mat_entries: [(part_index, lod_index,
    material_rel_path)]——稀疏枚举同 ref 惯例（本 POC lods=1 即每 part 一条）。
    返回写入的 wsmodel 文本。"""
    lines = ['<model version="1">',
             f'\t<geometry>{geom_rel}</geometry>',
             '\t<materials>']
    for p, l, m in mat_entries:
        lines.append(f'\t\t<material part_index="{p}" lod_index="{l}">'
                     f'{m}</material>')
    lines += ['\t</materials>', '</model>']
    xml = '\n'.join(lines) + '\n'
    Path(out_path).write_text(xml, encoding='utf-8')
    return xml


if __name__ == '__main__':
    print('rmv2_convert_mp — library only; see poc driver in '
          'scratch/pipeline/game_compare/mp_convert_driver.py')
