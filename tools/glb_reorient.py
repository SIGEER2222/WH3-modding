# -*- coding: utf-8 -*-
"""Rotate a GLB's world by +90/-90 deg about X, keeping skinning intact.

Blender's glTF export leaves skin bind space in the armature's Z-up frame
(the +Y-up conversion only lands on node transforms, which skinned vertices
ignore). This tool left-multiplies a global rotation R into:

  - a new root wrapper node (rotates every node transform / joint world)
  - skin.inverseBindMatrices  (R @ IBM  -> bind joints land rotated too)
  - POSITION / NORMAL / TANGENT accessors of SKINNED primitives
    (bind-space verts rotate with the skeleton)

Unskinned meshes are covered by the root wrapper alone.

Usage: python glb_reorient.py <in.glb> <out.glb> <rx+90|rx-90|rx180|rz+90|rz-90|none> [scale]

The optional uniform scale factor is applied to bind-space POSITION data and
inverse-bind translations (IBM @ inv(s)); normals/tangents keep their length
and the wrapper node carries the same scale so joint worlds stay consistent.
"""
import json
import struct
import sys
from pathlib import Path

import numpy as np

CTYPES = {5120: np.int8, 5121: np.uint8, 5122: np.int16,
          5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def read_glb(path):
    d = Path(path).read_bytes()
    jl = struct.unpack("<I", d[12:16])[0]
    return json.loads(d[20:20 + jl]), bytearray(d[20 + jl + 8:])


def write_glb(path, js, binbuf):
    jb = json.dumps(js, separators=(",", ":")).encode()
    jb += b" " * (-len(jb) % 4)
    binbuf += b"\0" * (-len(binbuf) % 4)
    total = 12 + 8 + len(jb) + 8 + len(binbuf)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(jb), 0x4E4F534A))
        f.write(jb)
        f.write(struct.pack("<II", len(binbuf), 0x004E4942))
        f.write(binbuf)


def acc_span(js, ai):
    a = js["accessors"][ai]
    bv = js["bufferViews"][a["bufferView"]]
    n = a["count"] * NCOMP[a["type"]]
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride")
    return a, bv, n, off, stride


def rot_acc_vecs(js, binbuf, ai, R, s=1.0):
    """In-place rotate VEC3/VEC4 float accessor by R and scale xyz by s
    (w kept)."""
    a, bv, n, off, stride = acc_span(js, ai)
    comp = NCOMP[a["type"]]
    assert a["componentType"] == 5126 and comp in (3, 4)
    cnt = a["count"]
    M = R * s
    if stride and stride != comp * 4:
        for i in range(cnt):
            o = off + i * stride
            v = np.frombuffer(binbuf, "<f4", comp, o).copy()
            v[:3] = M @ v[:3]
            binbuf[o:o + comp * 4] = v.astype("<f4").tobytes()
    else:
        v = np.frombuffer(binbuf, "<f4", cnt * comp, off).reshape(cnt, comp).copy()
        v[:, :3] = v[:, :3] @ M.T
        binbuf[off:off + cnt * comp * 4] = v.astype("<f4").tobytes()
    if "min" in a and "max" in a and comp == 3:
        lo, hi = np.array(a["min"]), np.array(a["max"])
        corners = np.array([[x, y, z] for x in (lo[0], hi[0])
                            for y in (lo[1], hi[1]) for z in (lo[2], hi[2])])
        rc = corners @ M.T
        a["min"], a["max"] = rc.min(0).tolist(), rc.max(0).tolist()


def main():
    src, dst, mode = sys.argv[1], sys.argv[2], sys.argv[3]
    scale = float(sys.argv[4]) if len(sys.argv) > 4 else 1.0
    if mode == "none":
        R = np.eye(3)
        q = [0.0, 0.0, 0.0, 1.0]
    else:
        ang = {"rx+90": np.pi / 2, "rx-90": -np.pi / 2, "rx180": np.pi,
               "rz+90": np.pi / 2, "rz-90": -np.pi / 2}[mode]
        c, s = round(np.cos(ang)), round(np.sin(ang))
        if mode.startswith("rx"):
            R = np.array([[1, 0, 0], [0, c, -s], [0, s, c]], dtype=np.float64)
            q = [round(float(np.sin(ang / 2)), 6), 0.0, 0.0,
                 round(float(np.cos(ang / 2)), 6)]
        else:
            R = np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]], dtype=np.float64)
            q = [0.0, 0.0, round(float(np.sin(ang / 2)), 6),
                 round(float(np.cos(ang / 2)), 6)]

    js, binbuf = read_glb(src)

    # 1) skinned bind-space verts + IBMs
    skinned_meshes = {n["mesh"] for n in js.get("nodes", []) if "skin" in n}
    done_acc = set()
    for mi in skinned_meshes:
        for pr in js["meshes"][mi].get("primitives", []):
            for attr in ("POSITION", "NORMAL", "TANGENT"):
                ai = pr["attributes"].get(attr)
                if ai is not None and ai not in done_acc:
                    # directions (normal/tangent) rotate but keep unit length
                    sc = scale if attr == "POSITION" else 1.0
                    rot_acc_vecs(js, binbuf, ai, R, sc)
                    done_acc.add(ai)
    for sk in js.get("skins", []):
        ai = sk.get("inverseBindMatrices")
        if ai is None:
            continue
        a, bv, n, off, stride = acc_span(js, ai)
        assert a["componentType"] == 5126 and a["type"] == "MAT4"
        m = np.frombuffer(binbuf, "<f4", a["count"] * 16, off) \
            .reshape(-1, 4, 4).transpose(0, 2, 1).copy()  # row-major mats
        Ri = np.eye(4)
        Ri[:3, :3] = R.T / scale
        # world stays consistent: (sW)(IBM')(sRv) == (W)(IBM)(v)
        m = m @ Ri
        binbuf[off:off + a["count"] * 64] = \
            m.transpose(0, 2, 1).astype("<f4").tobytes()

    # 2) root wrapper node carrying R (quaternion) + uniform scale
    wrapper = {"name": "reorient_root", "rotation": q,
               "children": list(js["scenes"][js.get("scene", 0)]["nodes"])}
    if scale != 1.0:
        wrapper["scale"] = [scale, scale, scale]
    js["nodes"].append(wrapper)
    js["scenes"][js.get("scene", 0)]["nodes"] = [len(js["nodes"]) - 1]

    write_glb(dst, js, binbuf)
    print("reoriented", mode, f"scale={scale}", "->", dst)


if __name__ == "__main__":
    main()
