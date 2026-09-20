# -*- coding: utf-8 -*-
"""Flatten a (possibly skinned) GLB into bind-space static geometry.

glTF skinned POSITION data is already authored in bind space (the space
inverse(IBM) maps joints into), so skinned prims are passed through raw and
only non-skinned parts get their node world transform applied. The output has
no skin/armature — feeding it to blender_rig2 avoids all rest-vs-bind pose
ambiguity (e.g. sources whose rest pose differs from bind pose).

Usage: glb_bindspace.py <in.glb> <out.glb>
"""
import json
import struct
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
from rmv2_convert import read_glb, read_accessor, _node_world_mats  # noqa

CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16,
      5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def bake(path):
    js, buf = read_glb(path)
    return _bake(js, buf)


def _bake(js, buf):
    world = _node_world_mats(js)
    out_prims = []          # dicts of merged per-material prim data
    for ni, n in enumerate(js.get("nodes", [])):
        if "mesh" not in n:
            continue
        skin = js["skins"][n["skin"]] if "skin" in n else None
        if skin is not None:
            jw = np.array([world[j] for j in skin["joints"]])
            ibm = read_accessor(js, buf, skin["inverseBindMatrices"])
            ibm = ibm.reshape(-1, 4, 4).transpose(0, 2, 1)  # glTF col-major
            JI = jw @ ibm                                   # (J,4,4)
        else:
            JI = None
        for prim in js["meshes"][n["mesh"]].get("primitives", []):
            at = prim["attributes"]
            pos = read_accessor(js, buf, at["POSITION"]).astype(np.float64)
            nrm = (read_accessor(js, buf, at["NORMAL"]).astype(np.float64)
                   if "NORMAL" in at else None)
            uv = (read_accessor(js, buf, at["TEXCOORD_0"]).astype(np.float64)
                  if "TEXCOORD_0" in at else None)
            idx = (read_accessor(js, buf, prim["indices"]).reshape(-1)
                   if "indices" in prim
                   else np.arange(len(pos), dtype=np.uint32))
            if JI is not None:
                pass        # skinned: POSITION is already bind space
            else:
                M = world.get(ni, np.eye(4))
                pos = pos @ M[:3, :3].T + M[:3, 3]
                if nrm is not None:
                    nrm = nrm @ M[:3, :3].T
                    nrm /= np.maximum(
                        np.linalg.norm(nrm, axis=1, keepdims=True), 1e-12)
            mat_i = prim.get("material")
            out_prims.append({"pos": pos.astype(np.float32),
                              "nrm": (nrm.astype(np.float32)
                                      if nrm is not None else None),
                              "uv": (uv.astype(np.float32)
                                     if uv is not None else None),
                              "idx": idx.astype(np.uint32),
                              "mat": mat_i})
    return js, out_prims


def write_glb(path, src_js, prims, src_buf=None, weights=None,
              bone_names=None):
    """weights (optional): per-prim (JOINTS_0 u16 (nv,4), WEIGHTS_0 f32 (nv,4))
    already remapped into bone_names index space. Emits a synthetic skin with
    identity IBMs so Blender imports vertex groups named after target bones
    (identity IBMs + untransformed joints = no deformation on import)."""
    binbuf = bytearray()
    accs, bvs, meshes, nodes, mats, skins = [], [], [], [], [], []

    def add_acc(arr, ctype, target=None):
        arr = np.ascontiguousarray(arr)
        off = len(binbuf)
        binbuf.extend(arr.tobytes())
        while len(binbuf) % 4:
            binbuf.append(0)
        bv = {"buffer": 0, "byteOffset": off, "byteLength": arr.nbytes}
        if target:
            bv["target"] = target
        bvs.append(bv)
        acc = {"bufferView": len(bvs) - 1, "componentType":
               {np.dtype(np.float32): 5126, np.dtype(np.uint32): 5125,
                np.dtype(np.uint16): 5123}[arr.dtype],
               "count": len(arr),
               "type": ctype}
        if ctype == "VEC3" and arr.dtype == np.float32:
            acc["min"] = [float(x) for x in arr.min(0)]
            acc["max"] = [float(x) for x in arr.max(0)]
        accs.append(acc)
        return len(accs) - 1

    jbase = 0
    if weights is not None:
        jbase = len(prims)                       # joint nodes after prims
        for bn in bone_names:
            nodes.append({"name": bn})
        ibm = np.repeat(np.eye(4, dtype=np.float32).reshape(1, 4, 4),
                        len(bone_names), 0)
        ibm_acc = add_acc(ibm, "MAT4")
    for i, p in enumerate(prims):
        attrs = {"POSITION": add_acc(p["pos"], "VEC3", 34962)}
        if p["nrm"] is not None:
            attrs["NORMAL"] = add_acc(p["nrm"], "VEC3")
        if p["uv"] is not None:
            attrs["TEXCOORD_0"] = add_acc(p["uv"], "VEC2")
        skin_i = None
        if weights is not None and weights[i] is not None:
            jj, ww = weights[i]
            attrs["JOINTS_0"] = add_acc(jj.astype(np.uint16), "VEC4")
            attrs["WEIGHTS_0"] = add_acc(ww.astype(np.float32), "VEC4")
            skin_i = len(skins)
            skins.append({"joints": [jbase + k for k in
                                     range(len(bone_names))],
                          "inverseBindMatrices": ibm_acc})
        pr = {"attributes": attrs,
              "indices": add_acc(p["idx"].reshape(-1, 1), "SCALAR", 34963),
              "mode": 4}
        if p["mat"] is not None:
            pr["material"] = p["mat"]
        meshes.append({"primitives": [pr]})
        nd = {"mesh": len(meshes) - 1, "name": f"part{i}"}
        if skin_i is not None:
            nd["skin"] = skin_i
        # prim nodes were appended first; insert at index i (joints appended
        # after all prims so node indices stay stable)
        nodes.insert(i, nd)
    for i, m in enumerate(src_js.get("materials", [])):
        mats.append(m)
    # copy bufferView-embedded images into the new bin so previews keep
    # textures (texture maps for rmv2 still come from the SOURCE glb)
    images = []
    if src_buf is not None:
        for im in src_js.get("images", []):
            im = dict(im)
            if "bufferView" in im:
                sv = src_js["bufferViews"][im["bufferView"]]
                off = sv.get("byteOffset", 0)
                data = src_buf[off:off + sv["byteLength"]]
                noff = len(binbuf)
                binbuf.extend(data)
                while len(binbuf) % 4:
                    binbuf.append(0)
                bvs.append({"buffer": 0, "byteOffset": noff,
                            "byteLength": len(data)})
                im["bufferView"] = len(bvs) - 1
            images.append(im)

    gltf = {
        "asset": {"version": "2.0", "generator": "glb_bindspace"},
        "scene": 0, "scenes": [{"nodes": list(range(len(nodes)))}],
        "nodes": nodes, "meshes": meshes,
        "materials": mats,
        "accessors": accs, "bufferViews": bvs,
        "buffers": [{"byteLength": len(binbuf)}],
    }
    if skins:
        gltf["skins"] = skins
    for k in ("textures", "samplers"):
        if k in src_js:
            gltf[k] = src_js[k]
    if images:
        gltf["images"] = images
    jsb = json.dumps(gltf, separators=(",", ":")).encode()
    while len(jsb) % 4:
        jsb += b" "
    total = 12 + 8 + len(jsb) + 8 + len(binbuf)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<II", len(jsb), 0x4E4F534A) + jsb)
        f.write(struct.pack("<II", len(binbuf), 0x004E4942) + bytes(binbuf))


if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    _js, _buf = read_glb(src)
    sjs, prims = _bake(_js, _buf)
    write_glb(dst, sjs, prims, src_buf=_buf)
    tot = sum(len(p["pos"]) for p in prims)
    ys = np.concatenate([p["pos"][:, 1] for p in prims])
    print(f"{dst}: {len(prims)} prims, {tot} verts, "
          f"y {ys.min():.2f}..{ys.max():.2f}")
