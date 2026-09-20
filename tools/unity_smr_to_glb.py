"""Export SkinnedMeshRenderer hierarchies from a Unity AssetBundle to GLB.

Usage:
    python unity_smr_to_glb.py <bundle_path> <out_dir> [--filter substr]

Each root Transform hierarchy that contains at least one SkinnedMeshRenderer
becomes one .glb (skeleton + skinned mesh + embedded base-color texture).
Coordinates are converted Unity(LH, Y-up) -> glTF(RH, Y-up) by flipping X.

Produces <out_dir>/<root_name>.glb plus <out_dir>/index.json mapping
glb -> digimon asset dir (when resolvable via bundle container paths).
"""
import json
import math
import re
import struct
import sys
from collections import deque
from pathlib import Path

import UnityPy
from UnityPy.helpers.MeshHelper import MeshHandler

FLIP = (-1.0, 1.0, 1.0)  # D = diag(-1,1,1,1)


def v3(v):
    if hasattr(v, "x"):
        return (float(v.x), float(v.y), float(v.z))
    return (float(v[0]), float(v[1]), float(v[2]))


def v4(v):
    if hasattr(v, "x"):
        return (float(v.x), float(v.y), float(v.z), float(v.w))
    t = tuple(float(x) for x in v)
    return t + (0.0,) * (4 - len(t))


def mat_elems(m):
    return [[float(getattr(m, f"e{r}{c}")) for c in range(4)] for r in range(4)]


def conj_flip(mat):
    """D * M * D for D=diag(-1,1,1,1): negate elements where exactly one index is 0."""
    out = [row[:] for row in mat]
    for j in (1, 2, 3):
        out[0][j] = -out[0][j]
        out[j][0] = -out[j][0]
    return out


def mat_col_major(mat):
    return [mat[r][c] for c in range(4) for r in range(4)]


class Glb:
    def __init__(self):
        self.buf = bytearray()
        self.views = []
        self.accessors = []
        self.nodes = []
        self.meshes = []
        self.skins = []
        self.materials = []
        self.textures = []
        self.images = []
        self.samplers = [{"magFilter": 9729, "minFilter": 9987}]
        self.mat_cache = {}   # path_id -> material index
        self.tex_cache = {}   # path_id -> texture index

    def add_accessor(self, data: bytes, comp_type: int, count: int,
                     acc_type: str, minmax=None):
        while len(self.buf) % 4:
            self.buf.append(0)
        self.views.append({
            "buffer": 0, "byteOffset": len(self.buf), "byteLength": len(data),
        })
        self.buf += data
        acc = {"bufferView": len(self.views) - 1, "componentType": comp_type,
               "count": count, "type": acc_type}
        if minmax is not None:
            acc["min"], acc["max"] = minmax
        self.accessors.append(acc)
        return len(self.accessors) - 1

    def build(self, root_node: int) -> bytes:
        scene_nodes = [n for n in (root_node,) if n is not None]
        gltf = {
            "asset": {"version": "2.0", "generator": "unity_smr_to_glb"},
            "scene": 0,
            "scenes": [{"nodes": scene_nodes}],
            "nodes": self.nodes,
            "meshes": self.meshes,
            "skins": self.skins,
            "accessors": self.accessors,
            "bufferViews": self.views,
            "buffers": [{"byteLength": len(self.buf)}],
        }
        if self.materials:
            gltf["materials"] = self.materials
        if self.textures:
            gltf["textures"] = self.textures
            gltf["images"] = self.images
            gltf["samplers"] = self.samplers
        js = json.dumps(gltf, separators=(",", ":")).encode()
        while len(js) % 4:
            js += b" "
        bin_pad = (4 - len(self.buf) % 4) % 4
        self.buf += b"\0" * bin_pad
        total = 12 + 8 + len(js) + 8 + len(self.buf)
        out = bytearray()
        out += struct.pack("<III", 0x46546C67, 2, total)
        out += struct.pack("<II", len(js), 0x4E4F534A) + js
        out += struct.pack("<II", len(self.buf), 0x004E4942) + bytes(self.buf)
        return bytes(out)


def export_root(env, objs, root_pid, out_dir, pid2path):
    """Return (glb_bytes, label) or None if hierarchy has no SMR."""
    # ---- collect hierarchy ----
    order = []          # transform path_ids, BFS
    seen = set()
    dq = deque([root_pid])
    while dq:
        pid = dq.popleft()
        if pid in seen or pid not in objs:
            continue
        seen.add(pid)
        order.append(pid)
        t = objs[pid].read()
        for ch in t.m_Children:
            dq.append(ch.m_PathID)

    smrs = []           # (node transform pid, smr data)
    for pid in order:
        t = objs[pid].read()
        go = objs[t.m_GameObject.m_PathID].read()
        for c in go.m_Component:
            co = objs[c.component.m_PathID]
            if co.type.name == "SkinnedMeshRenderer":
                smrs.append((pid, co.read()))
    if not smrs:
        return None

    g = Glb()
    node_idx = {}
    for pid in order:
        t = objs[pid].read()
        go = objs[t.m_GameObject.m_PathID].read()
        p = v3(t.m_LocalPosition)
        q = v4(t.m_LocalRotation)
        s = v3(t.m_LocalScale)
        node = {
            "name": go.m_Name,
            "translation": [p[0] * FLIP[0], p[1], p[2]],
            "rotation": [q[0], -q[1], -q[2], q[3]],
            "scale": [s[0], s[1], s[2]],
            "children": [],
        }
        node_idx[pid] = len(g.nodes)
        g.nodes.append(node)
    for pid in order:
        t = objs[pid].read()
        parent = t.m_Father.m_PathID
        if parent in node_idx:
            g.nodes[node_idx[parent]]["children"].append(node_idx[pid])
    for n in g.nodes:
        if not n["children"]:
            n.pop("children")

    # ---- meshes / skins ----
    for smr_pid, smr in smrs:
        mesh_obj = objs.get(smr.m_Mesh.m_PathID)
        if mesh_obj is None:
            continue
        mesh = mesh_obj.read()
        mh = MeshHandler(mesh)
        mh.process()
        verts = [v3(v) for v in mh.m_Vertices]
        nverts = len(verts)
        if not nverts:
            continue
        norms = [v3(v) for v in mh.m_Normals] if mh.m_Normals else None
        uvs = [(float(u[0]), float(u[1])) if not hasattr(u, "x")
               else (float(u.x), float(u.y)) for u in (mh.m_UV0 or [])]
        joints_raw = [tuple(int(x) for x in (b if not hasattr(b, "x") else (b.x, b.y, b.z, b.w)))
                      for b in (mh.m_BoneIndices or [])]
        weights_raw = [v4(w) for w in (mh.m_BoneWeights or [])]
        idx_buf = list(mh.m_IndexBuffer)
        idx32 = getattr(mh, "m_Use16BitIndices", True) is False

        has_skin = bool(mesh.m_BindPose) and joints_raw and weights_raw \
            and len(smr.m_Bones) == len(mesh.m_BindPose)

        # positions
        pv = [(v[0] * FLIP[0], v[1], v[2]) for v in verts]
        flat = [c for v in pv for c in v]
        mn = [min(v[i] for v in pv) for i in range(3)]
        mx = [max(v[i] for v in pv) for i in range(3)]
        pos_acc = g.add_accessor(struct.pack(f"<{len(flat)}f", *flat),
                                 5126, nverts, "VEC3", (mn, mx))

        def attr_acc(vals, comp, acc_type):
            flatv = [c for v in vals for c in v]
            fmt = {5126: "f", 5123: "H", 5121: "B"}[comp]
            return g.add_accessor(struct.pack(f"<{len(flatv)}{fmt}", *flatv),
                                  comp, len(vals), acc_type)

        nrm_acc = uv_acc = jnt_acc = wgt_acc = None
        if norms:
            nrm_acc = attr_acc([(n[0] * FLIP[0], n[1], n[2]) for n in norms],
                               5126, "VEC3")
        if uvs:
            uv_acc = attr_acc(uvs, 5126, "VEC2")
        if has_skin:
            jnt_acc = attr_acc(joints_raw, 5121 if len(smr.m_Bones) <= 255 else 5123, "VEC4")
            wgt_acc = attr_acc(weights_raw, 5126, "VEC4")

        # submeshes -> primitives
        subs = mesh.m_SubMeshes
        prims = []
        for si, sub in enumerate(subs):
            ibw = 2 if not idx32 else 4
            start = sub.firstByte // ibw
            idx = idx_buf[start:start + sub.indexCount]
            # flip winding for X mirror
            rev = []
            for i in range(0, len(idx) - 2, 3):
                rev += [idx[i], idx[i + 2], idx[i + 1]]
            comp = 5125 if (idx32 or max(idx, default=0) > 65535) else 5123
            fmt = "I" if comp == 5125 else "H"
            iacc = g.add_accessor(struct.pack(f"<{len(rev)}{fmt}", *rev),
                                  comp, len(rev), "SCALAR")
            attrs = {"POSITION": pos_acc}
            if nrm_acc is not None:
                attrs["NORMAL"] = nrm_acc
            if uv_acc is not None:
                attrs["TEXCOORD_0"] = uv_acc
            if has_skin:
                attrs["JOINTS_0"] = jnt_acc
                attrs["WEIGHTS_0"] = wgt_acc
            prim = {"attributes": attrs, "indices": iacc}
            mat_i = material_index(g, objs, smr, si)
            if mat_i is not None:
                prim["material"] = mat_i
            prims.append(prim)
        if not prims:
            continue
        g.meshes.append({"name": mesh.m_Name, "primitives": prims})
        node = g.nodes[node_idx[smr_pid]]
        node["mesh"] = len(g.meshes) - 1
        if has_skin:
            jnodes = []
            for b in smr.m_Bones:
                if b.m_PathID not in node_idx:
                    has_skin = False
                    break
                jnodes.append(node_idx[b.m_PathID])
            if has_skin:
                ibms = [mat_col_major(conj_flip(mat_elems(bp)))
                        for bp in mesh.m_BindPose]
                flat = [c for m in ibms for c in m]
                iacc = g.add_accessor(struct.pack(f"<{len(flat)}f", *flat),
                                      5126, len(ibms), "MAT4")
                g.skins.append({"joints": jnodes, "inverseBindMatrices": iacc,
                                "skeleton": node_idx[root_pid]})
                node["skin"] = len(g.skins) - 1

    # ---- label ----
    root_t = objs[root_pid].read()
    root_name = objs[root_t.m_GameObject.m_PathID].read().m_Name
    label = pid2path.get(root_pid) or root_name
    return g.build(node_idx[root_pid]), label, root_name


def material_index(g, objs, smr, si):
    mats = smr.m_Materials
    if not mats:
        return None
    pid = mats[min(si, len(mats) - 1)].m_PathID
    if pid in g.mat_cache:
        return g.mat_cache[pid]
    mo = objs.get(pid)
    if mo is None:
        return None
    md = mo.read_typetree()
    mat = {"name": md.get("m_Name", f"mat_{si}"), "pbrMetallicRoughness": {}}
    tex_idx = None
    for name, env_ in md.get("m_SavedProperties", {}).get("m_TexEnvs", []):
        if "main" in name.lower() or tex_idx is None:
            tpid = env_.get("m_Texture", {}).get("m_PathID", 0)
            if tpid and tpid in objs:
                tex_idx = texture_index(g, objs, tpid)
            if "main" in name.lower():
                break
    if tex_idx is not None:
        mat["pbrMetallicRoughness"]["baseColorTexture"] = {"index": tex_idx}
        mat["pbrMetallicRoughness"]["metallicFactor"] = 0.0
        mat["pbrMetallicRoughness"]["roughnessFactor"] = 0.9
    mat["doubleSided"] = True
    g.materials.append(mat)
    g.mat_cache[pid] = len(g.materials) - 1
    return len(g.materials) - 1


def texture_index(g, objs, tpid):
    if tpid in g.tex_cache:
        return g.tex_cache[tpid]
    tex = objs[tpid].read()
    import io
    bio = io.BytesIO()
    tex.image.save(bio, format="PNG")
    data = bio.getvalue()
    while len(g.buf) % 4:
        g.buf.append(0)
    g.views.append({"buffer": 0, "byteOffset": len(g.buf),
                    "byteLength": len(data)})
    g.buf += data
    g.images.append({"name": tex.m_Name, "mimeType": "image/png",
                     "bufferView": len(g.views) - 1})
    g.textures.append({"source": len(g.images) - 1, "sampler": 0})
    g.tex_cache[tpid] = len(g.textures) - 1
    return len(g.textures) - 1


def main():
    bundle = sys.argv[1]
    out_dir = Path(sys.argv[2])
    out_dir.mkdir(parents=True, exist_ok=True)
    filt = sys.argv[sys.argv.index("--filter") + 1] if "--filter" in sys.argv else None

    env = UnityPy.load(bundle)
    objs = {}
    sf = None
    for o in env.objects:
        sf = o.assets_file
        objs[o.path_id] = o
    pid2path = {pp.m_PathID: p for p, pp in sf.container.items()}

    # stem -> digimon dir lookup from container paths
    stem2dir = {}
    for p in pid2path.values():
        m = re.search(r"role_models/model/([^/]+)/.*?([^/]+)\.(fbx|dae)$", p, re.I)
        if m:
            stem2dir[m.group(2).lower()] = m.group(1)

    roots = []
    for o in env.objects:
        if o.type.name == "Transform":
            t = o.read()
            if not t.m_Father.m_PathID:
                roots.append(o.path_id)
    print(f"{len(roots)} root hierarchies")

    index = []
    n_ok = 0
    for rpid in roots:
        t = objs[rpid].read()
        rname = objs[t.m_GameObject.m_PathID].read().m_Name
        if filt and filt.lower() not in rname.lower():
            continue
        try:
            res = export_root(env, objs, rpid, out_dir, pid2path)
        except Exception as e:
            print("FAILED", rname, repr(e))
            continue
        if res is None:
            continue
        glb, label, _ = res
        mon = stem2dir.get(rname.lower())
        safe = re.sub(r'[\\/:*?"<>|]', "_", rname)
        fn = f"{mon}_{safe}.glb" if mon else f"{safe}.glb"
        n = 2
        while (out_dir / fn).exists():
            fn = fn[:-4] + f"_{n}.glb"
            n += 1
        (out_dir / fn).write_bytes(glb)
        index.append({"file": fn, "root": rname, "digimon": mon,
                      "asset": label, "bytes": len(glb)})
        n_ok += 1
        print("wrote", fn, len(glb), "bytes")
    (out_dir / "index.json").write_text(
        json.dumps(index, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{n_ok} glb files -> {out_dir}")


if __name__ == "__main__":
    main()
