# -*- coding: utf-8 -*-
"""Force every skin joint's node transform to the bind pose.

Some sources (DAE exports, FBX "With Animations") store node TRS that do
NOT equal the skin's bind matrices (rest != bind). Baking world verts via
joint_world @ IBM then produces the wrong (posed/lying) shape.

Fix: for each skin, set joint world_transform := mesh_world @ inv(IBM_j)
and rewrite that node's local TRS accordingly. After this, rest == bind.

Usage: python glb_rest_bind.py <in.glb> <out.glb>
"""
import json
import struct
import sys
from pathlib import Path

import numpy as np


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


def node_local(n):
    if "matrix" in n:
        return np.array(n["matrix"], dtype=float).reshape(4, 4).T.copy()
    t = np.array(n.get("translation", [0, 0, 0]), dtype=float)
    r = np.array(n.get("rotation", [0, 0, 0, 1]), dtype=float)
    s = np.array(n.get("scale", [1, 1, 1]), dtype=float)
    x, y, z, w = r
    R = np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
    M = np.eye(4)
    M[:3, :3] = R @ np.diag(s)
    M[:3, 3] = t
    return M


def set_node_local(n, M):
    n.pop("matrix", None)
    n.pop("translation", None)
    n.pop("rotation", None)
    n.pop("scale", None)
    n["matrix"] = [float(v) for v in M.T.flatten()]  # column-major


def acc_mat4(js, binbuf, ai):
    a = js["accessors"][ai]
    bv = js["bufferViews"][a["bufferView"]]
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    return np.frombuffer(binbuf, "<f4", a["count"] * 16, off) \
        .reshape(-1, 4, 4).transpose(0, 2, 1).copy()


def main():
    src, dst = sys.argv[1], sys.argv[2]
    js, binbuf = read_glb(src)
    nodes = js["nodes"]

    par = {}
    for i, n in enumerate(nodes):
        for c in n.get("children", []):
            par[c] = i

    def world(i):
        M = node_local(nodes[i])
        p = par.get(i)
        return (world(p) @ M) if p is not None else M

    world_cache = {}

    def W(i):
        if i not in world_cache:
            M = node_local(nodes[i])
            p = par.get(i)
            world_cache[i] = (W(p) @ M) if p is not None else M
        return world_cache[i]

    changed = 0
    for sk in js.get("skins", []):
        ai = sk.get("inverseBindMatrices")
        if ai is None:
            continue
        ibm = acc_mat4(js, binbuf, ai)
        # world transform of the skinned mesh node (identity if absent)
        mn = next((i for i, n in enumerate(nodes)
                   if n.get("skin") is not None and "mesh" in n), None)
        W_mesh = W(mn) if mn is not None else np.eye(4)
        jset = set(sk.get("joints", []))
        W_target = {j: W_mesh @ np.linalg.inv(ibm[k])
                    for k, j in enumerate(sk.get("joints", []))}

        def depth(i):
            d, p = 0, par.get(i)
            while p is not None:
                d += 1
                p = par.get(p)
            return d

        for j in sorted(jset, key=depth):
            p = par.get(j)
            Wp = W_target.get(p, W(p) if p is not None else np.eye(4))
            L = np.linalg.inv(Wp) @ W_target[j]
            set_node_local(nodes[j], L)
            world_cache[j] = W_target[j]
            changed += 1
    write_glb(dst, js, binbuf)
    print(f"rest->bind: {changed} joints -> {dst}")


if __name__ == "__main__":
    main()
