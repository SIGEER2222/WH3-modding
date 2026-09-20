# -*- coding: utf-8 -*-
"""Unity YAML (Pokemon HOME dump) -> skinned GLB.

Per pokemon folder:
  fbx/model/<name>Avatar.asset        skeleton (parent ids)
  fbx/model/<name>_<part>Skin.asset   Mesh yaml (verts/tris/uv/weights/bindpose)
  fbx/textures/*.png                  textures
  production/models/<pm>/<pm>.prefab  bone names/hierarchy + skin bone order

Usage: home_pkm_to_glb.py <unzip_root> <mitake>/<ver>/<pmID> <out.glb>
  e.g. home_pkm_to_glb.py E:\\pkm 01rg/pm0006_00_00 out.glb
"""
import io, json, re, struct, sys
from pathlib import Path

import numpy as np
import yaml

FMT_SIZE = {0:4,1:2,2:1,3:1,4:2,5:2,6:1,7:1,8:2,9:2,10:4,11:4}


def load_docs(text):
    """Split unity yaml into {fileID: (classId, dict)}."""
    docs = {}
    for m in re.finditer(r"--- !u!(\d+) &(\d+)\n(.*?)(?=\n--- !u!|\Z)", text, re.S):
        cid, fid, body = int(m.group(1)), int(m.group(2)), m.group(3)
        try:
            d = yaml.safe_load(body)
        except Exception:
            # unity emits odd scalars occasionally; fall back to line regex for needed keys
            d = None
        docs[fid] = (cid, d, body)
    return docs


def parse_prefab(path):
    docs = load_docs(Path(path).read_text(encoding="utf-8", errors="ignore"))
    go_name, tr = {}, {}
    smr = []
    for fid, (cid, d, body) in docs.items():
        if cid == 1 and d:  # GameObject
            go = d.get("GameObject", d)
            go_name[fid] = go.get("m_Name")
        elif cid == 4 and d:  # Transform
            t = d.get("Transform", d)
            tr[fid] = dict(
                go=t.get("m_GameObject", {}).get("fileID"),
                father=(t.get("m_Father") or {}).get("fileID", 0),
                pos=[t.get("m_LocalPosition", {}).get(k, 0.0) for k in "xyz"],
                rot=[t.get("m_LocalRotation", {}).get(k, 0.0) for k in "xyzw"],
                scl=[t.get("m_LocalScale", {}).get(k, 1.0) for k in "xyz"],
            )
        elif cid == 137 and d:  # SkinnedMeshRenderer
            r = d.get("SkinnedMeshRenderer", d)
            bones = [b.get("fileID") for b in r.get("m_Bones", [])]
            mesh = r.get("m_Mesh", {})
            smr.append(dict(bones=bones, mesh=mesh, go=r.get("m_GameObject", {}).get("fileID")))
    return go_name, tr, smr


def parse_mesh_asset(path):
    docs = load_docs(Path(path).read_text(encoding="utf-8", errors="ignore"))
    for fid, (cid, d, body) in docs.items():
        if cid != 43 or not d:
            continue
        mesh = d.get("Mesh", d)
        vd = mesh["m_VertexData"]
        raw = bytes.fromhex(re.sub(r"\s", "", vd["_typelessdata"]))
        n = vd["m_VertexCount"]
        chans = vd["m_Channels"]
        # stream strides = max(offset+dim*size) per stream
        strides = {}
        for c in chans:
            if c["dimension"] == 0:
                continue
            s, end = c["stream"], c["offset"] + c["dimension"] * FMT_SIZE[c["format"]]
            strides[s] = max(strides.get(s, 0), end)
        # stream data packed sequentially, aligned to 16
        offs, pos = {}, 0
        for s in sorted(strides):
            offs[s] = pos
            pos += strides[s] * n
            pos = (pos + 15) & ~15
        def get(cidx, count, dtype):
            c = chans[cidx]
            st = np.frombuffer(raw, dtype=dtype, count=count * c["dimension"],
                               offset=offs[c["stream"]])
            # strided read
            itemsize = np.dtype(dtype).itemsize * c["dimension"]
            idx = np.arange(count) * strides[c["stream"]]
            buf = np.empty((count, c["dimension"]), dtype=dtype)
            for i, o in enumerate(idx):
                buf[i] = np.frombuffer(raw, dtype=dtype, count=c["dimension"],
                                       offset=offs[c["stream"]] + o + c["offset"])
            return buf
        out = dict(
            pos=get(0, n, np.float32),
            nrm=get(1, n, np.float32) if chans[1]["dimension"] else None,
            uv=get(4, n, np.float32) if chans[4]["dimension"] else None,
            weights=get(12, n, np.float32) if chans[12]["dimension"] else None,
            joints=(get(13, n, np.uint8) if chans[13]["format"] in (2, 6)
                    else get(13, n, np.uint32) if chans[13]["dimension"] else None),
            idx=np.frombuffer(bytes.fromhex(re.sub(r"\s", "", mesh["m_IndexBuffer"])),
                              dtype=np.uint16),
            subs=[(s["firstByte"] // 2, s["indexCount"], s.get("baseVertex", 0),
                   s.get("firstVertex", 0), s.get("vertexCount", 0))
                  for s in mesh["m_SubMeshes"]],
            bindpose=[np.array(b["e00":"e33".replace("e33", "e33")], dtype=np.float64)
                      if False else None for b in []],
        )
        # bindpose
        bp = mesh.get("m_BindPose") or []
        mats = []
        for b in bp:
            vals = [b[f"e{r}{c}"] for r in range(4) for c in range(4)]
            mats.append(np.array(vals, dtype=np.float64).reshape(4, 4))
        out["bindpose"] = mats
        out["name"] = mesh.get("m_Name")
        return out
    raise ValueError(f"no Mesh in {path}")


def parse_anim(path):
    """Unity .anim YAML -> {bone_name: {'pos':[(t,xyz)], 'rot':[(t,xyzw)], 'scl':[(t,xyz)]}}, rate."""
    docs = load_docs(Path(path).read_text(encoding="utf-8", errors="ignore"))
    clip = None
    for fid, (cid, d, body) in docs.items():
        if cid == 74 and d:
            clip = d.get("AnimationClip", d); break
    if clip is None:
        return None
    rate = clip.get("m_SampleRate", 30) or 30
    out = {}
    def curves(key, dims, conv=None):
        for c in clip.get(key, []) or []:
            p = c.get("path", "")
            name = p.rsplit("/", 1)[-1]
            ks = []
            for k in c["curve"]["m_Curve"]:
                t = k["time"]
                v = k["value"]
                vec = [v.get(a, 0.0) for a in "xyzw"[:dims]]
                def slope(keyname):
                    s = k.get(keyname)
                    if not isinstance(s, dict):
                        return [0.0] * dims
                    vals = [s.get(a, 0.0) for a in "xyzw"[:dims]]
                    return [v if isinstance(v, (int, float)) and abs(v) != float("inf")
                            else 0.0 for v in vals]
                ks.append((t, vec, slope("inSlope"), slope("outSlope")))
            out.setdefault(name, {}).setdefault(key, []).extend(ks)
    curves("m_PositionCurves", 3)
    curves("m_RotationCurves", 4)
    curves("m_EulerCurves", 3)
    curves("m_ScaleCurves", 3)
    return out, rate


def euler2q(e):
    x, y, z = [np.radians(v) for v in e]
    cx, sx = np.cos(x / 2), np.sin(x / 2)
    cy, sy = np.cos(y / 2), np.sin(y / 2)
    cz, sz = np.cos(z / 2), np.sin(z / 2)
    qz = np.array([0, 0, sz, cz]); qx = np.array([sx, 0, 0, cx]); qy = np.array([0, sy, 0, cy])
    def mul(a, b):
        ax, ay, az, aw = a; bx, by, bz, bw = b
        return np.array([aw*bx+ax*bw+ay*bz-az*by, aw*by-ax*bz+ay*bw+az*bx,
                         aw*bz+ax*by-ay*bx+az*bw, aw*bw-ax*bx-ay*by-az*bz])
    return mul(qy, mul(qx, qz)).tolist()


def hermite(t0, v0, m0, t1, v1, m1, t):
    h = t1 - t0
    if h <= 0:
        return v1
    s = (t - t0) / h
    s2, s3 = s * s, s * s * s
    a = 2 * s3 - 3 * s2 + 1
    b = s3 - 2 * s2 + s
    c = -2 * s3 + 3 * s2
    d = s3 - s2
    return [a * v0[i] + b * m0[i] * h + c * v1[i] + d * m1[i] * h for i in range(len(v0))]


def sample_curve(ks, rate):
    """resample hermite keys at 1/rate; ks sorted by time."""
    if not ks:
        return [], []
    ks = sorted(ks)
    t0, t1 = ks[0][0], ks[-1][0]
    n = max(1, int(round((t1 - t0) * rate)) + 1)
    times = [t0 + i / rate for i in range(n)]
    if times[-1] < t1 - 1e-6:
        times.append(t1)
    vals, seg = [], 0
    for t in times:
        while seg < len(ks) - 1 and t > ks[seg + 1][0] + 1e-9:
            seg += 1
        k0 = ks[seg]
        if seg + 1 >= len(ks) or t <= k0[0] + 1e-9:
            vals.append(list(k0[1]))
        else:
            k1 = ks[seg + 1]
            vals.append(hermite(k0[0], k0[1], k0[3], k1[0], k1[1], k1[2], t))
    return times, vals


def unity_to_gltf_pos(p):
    return np.array([-p[0], p[1], p[2]], dtype=np.float64)

def unity_to_gltf_quat(q):
    x, y, z, w = q
    return [x, -y, -z, w]

def unity_to_gltf_mat(m):
    S = np.diag([-1.0, 1.0, 1.0, 1.0])
    return S @ m @ S


def build_glb(root, ver, pmid, outpath, animfiles=None):
    base = Path(root) / ver / "Assets" / "sandbox" / "models" / ver / pmid
    prod = Path(root) / ver / "Assets" / "production" / "models" / pmid.split("_")[0]
    prefab = prod / f"{pmid}.prefab"
    go_name, tr, smr = parse_prefab(prefab)

    # bone order from first SMR (same for all parts usually)
    bone_fids = smr[0]["bones"]
    bone_names = [go_name.get(tr[b]["go"], f"bone{i}") for i, b in enumerate(bone_fids)]
    # build node list = all transforms in hierarchy order (parents first)
    order, seen = [], set()
    def add(fid):
        if fid in seen or fid not in tr:
            return
        f = tr[fid]["father"]
        if f:
            add(f)
        seen.add(fid); order.append(fid)
    for s in smr:
        for b in s["bones"]:
            add(b)
    idx_of = {f: i for i, f in enumerate(order)}
    children = {}
    parents = {}
    for f in order:
        fa = tr[f]["father"]
        parents[f] = idx_of.get(fa)
        children.setdefault(idx_of.get(fa), []).append(idx_of[f])

    skins_parts = sorted(base.glob("fbx/model/*Skin.asset"))
    # SMR by GameObject name == Skin asset stem; renderers on
    # "CusAnimVis_<part>" GameObjects hold that part's bones too
    smr_by_name = {}
    for s in smr:
        nm = go_name.get(s["go"])
        if nm:
            smr_by_name[nm] = s
            if nm.startswith("CusAnimVis_"):
                smr_by_name[nm[len("CusAnimVis_"):]] = s
    meshes = []
    for p in skins_parts:
        m = parse_mesh_asset(p)
        s = smr_by_name.get(p.stem)
        if s is None:
            # alt-form part (e.g. pm0025_01_00_SippoSkin) absent from this
            # prefab: no SMR -> bone order unknown -> drop rather than emit
            # a skin whose IBM count mismatches its joints [Blender import
            # pick_bind_pose crash; wrong bind matrices in WH3].
            print(f"   skip part {p.stem}: no SMR in prefab")
            continue
        if len(s["bones"]) != len(m["bindpose"]):
            print(f"   skip part {p.stem}: bones({len(s['bones'])}) "
                  f"!= bindpose({len(m['bindpose'])})")
            continue
        m["bone_fids"] = s["bones"]
        meshes.append(m)

    # GLB assemble
    buf = bytearray()
    accessors, bufviews = [], []
    def push(data: bytes, target=None):
        off = len(buf)
        buf.extend(data)
        while len(buf) % 4:
            buf.append(0)
        bufviews.append({"buffer": 0, "byteOffset": off, "byteLength": len(data)})
        return len(bufviews) - 1
    def acc(bv, ctype, count, atype, mn=None, mx=None):
        a = {"bufferView": bv, "componentType": ctype, "count": count, "type": atype}
        if mn is not None: a["min"], a["max"] = mn, mx
        accessors.append(a); return len(accessors) - 1

    # nodes
    nodes = []
    for f in order:
        t = tr[f]
        p = unity_to_gltf_pos(t["pos"])
        q = unity_to_gltf_quat(t["rot"])
        nodes.append({"name": go_name.get(t["go"], f"n{f}"),
                      "translation": p.tolist(), "rotation": q,
                      "scale": t["scl"]})
    for f in order:
        kids = children.get(idx_of[f])
        if kids:
            nodes[idx_of[f]]["children"] = kids

    # per-part skins (each Skin part has its own SMR bone order)
    part_skin = []
    for part in meshes:
        joints = [idx_of[b] for b in part["bone_fids"]]
        ibm_g = np.stack([unity_to_gltf_mat(m) for m in part["bindpose"]]).astype(np.float32)
        ia = acc(push(ibm_g.tobytes()), 5126, len(ibm_g), "MAT4")
        part_skin.append({"joints": joints, "inverseBindMatrices": ia})

    materials, meshes_out, textures, images, samplers = [], [], [], [], []
    texdir = base / "fbx" / "textures"
    img_files = {p.stem: p for p in texdir.glob("*.png")}
    def mat_for(part):
        nm = part["name"] or ""
        key = nm.replace("_Skin", "")
        img = None
        for s, p in img_files.items():
            if key.split("_")[-1] in s and s.endswith("_col") and "rare" not in s:
                img = p; break
        if img is None:
            for s, p in img_files.items():
                if s.endswith("_col") and "rare" not in s:
                    img = p; break
        if img is None:
            return None
        data = img.read_bytes()
        bv = push(data)
        images.append({"bufferView": bv, "mimeType": "image/png", "name": img.stem})
        if not samplers:
            samplers.append({"magFilter": 9729, "minFilter": 9987,
                             "wrapS": 10497, "wrapT": 10497})
        textures.append({"source": len(images) - 1, "sampler": 0})
        materials.append({"name": img.stem, "pbrMetallicRoughness": {
            "baseColorTexture": {"index": len(textures) - 1},
            "metallicFactor": 0.0, "roughnessFactor": 1.0}})
        return len(materials) - 1

    for pi, part in enumerate(meshes):
        mi = mat_for(part)
        for (first, icount, base_v, first_v, vcount) in part["subs"]:
            sl = slice(first_v, first_v + vcount)
            pos = part["pos"][sl].astype(np.float32) * np.array([-1, 1, 1], np.float32)
            nrm = part["nrm"][sl].astype(np.float32) * np.array([-1, 1, 1], np.float32) \
                if part["nrm"] is not None else None
            uv = part["uv"][sl].astype(np.float32) if part["uv"] is not None else None
            if uv is not None:
                uv = uv * np.array([1, -1], np.float32) + np.array([0, 1], np.float32)
            w = part["weights"][sl].astype(np.float32)
            j = part["joints"][sl].astype(np.uint16)
            idx = part["idx"][first:first + icount].astype(np.uint32) - first_v
            idx = idx.reshape(-1, 3)[:, ::-1].reshape(-1)  # flip winding
            pa = acc(push(pos.tobytes()), 5126, len(pos), "VEC3",
                     pos.min(0).tolist(), pos.max(0).tolist())
            attrs = {"POSITION": pa}
            if nrm is not None:
                attrs["NORMAL"] = acc(push(nrm.tobytes()), 5126, len(nrm), "VEC3")
            if uv is not None:
                attrs["TEXCOORD_0"] = acc(push(uv.tobytes()), 5126, len(uv), "VEC2")
            attrs["JOINTS_0"] = acc(push(j.tobytes()), 5123, len(j), "VEC4")
            attrs["WEIGHTS_0"] = acc(push(w.tobytes()), 5126, len(w), "VEC4")
            ia = acc(push(idx.tobytes()), 5125, len(idx), "SCALAR")
            prim = {"attributes": attrs, "indices": ia, "mode": 4}
            if mi is not None:
                prim["material"] = mi
            meshes_out.append({"name": part["name"], "primitives": [prim],
                               "skin_idx": pi})

    gltf = {
        "asset": {"version": "2.0", "generator": "home_pkm_to_glb"},
        "scene": 0,
        "scenes": [{"nodes": [i for i in range(len(order)) if parents[order[i]] is None]}],
        "nodes": nodes,
        "meshes": meshes_out,
        "skins": part_skin,
        "materials": materials, "textures": textures, "images": images,
        "samplers": samplers,
        "accessors": accessors, "bufferViews": bufviews,
        "buffers": [{"byteLength": len(buf)}],
    }
    # ---- animations ----
    if animfiles:
        name2node = {nodes[i]["name"]: i for i in range(len(order))}
        anims = []
        for af in animfiles:
            parsed = parse_anim(af)
            if not parsed:
                continue
            curves_d, rate = parsed
            channels, samplers_a = [], []
            for bone, cc in curves_d.items():
                ni = name2node.get(bone)
                if ni is None:
                    continue
                for key, prop, conv in [("m_PositionCurves", "translation",
                                         lambda v: [-v[0], v[1], v[2]]),
                                        ("m_RotationCurves", "rotation",
                                         lambda v: [v[0], -v[1], -v[2], v[3]]),
                                        ("m_EulerCurves", "rotation",
                                         lambda v: (lambda q: [q[0], -q[1], -q[2], q[3]])(euler2q(v))),
                                        ("m_ScaleCurves", "scale", lambda v: v)]:
                    ks = cc.get(key)
                    if not ks:
                        continue
                    times, vals = sample_curve(ks, rate)
                    vals = [conv(v) for v in vals]
                    if prop == "rotation":
                        vals = [np.array(v) / (np.linalg.norm(v) or 1) for v in vals]
                    ta = acc(push(np.array(times, np.float32).tobytes()), 5126,
                             len(times), "SCALAR", [min(times)], [max(times)])
                    va = acc(push(np.array(vals, np.float32).tobytes()), 5126,
                             len(vals), "VEC4" if prop == "rotation" else "VEC3")
                    samplers_a.append({"input": ta, "output": va,
                                       "interpolation": "LINEAR"})
                    channels.append({"sampler": len(samplers_a) - 1,
                                     "target": {"node": ni, "path": prop}})
            if channels:
                anims.append({"name": Path(af).stem, "channels": channels,
                              "samplers": samplers_a})
        if anims:
            gltf["animations"] = anims
    # attach meshes as child nodes under root
    mesh_nodes = []
    for mi, m in enumerate(meshes_out):
        # mesh index -> which part skin (meshes_out built in same order as meshes)
        nodes.append({"name": m["name"], "mesh": mi, "skin": m["skin_idx"]})
        mesh_nodes.append(len(nodes) - 1)
    roots = gltf["scenes"][0]["nodes"]
    for r in roots:
        nodes[r].setdefault("children", []).extend(mesh_nodes)

    js = json.dumps(gltf, separators=(",", ":")).encode()
    while len(js) % 4:
        js += b" "
    glb = b"glTF" + struct.pack("<II", 2, 12 + 8 + len(js) + 8 + len(buf)) + \
        struct.pack("<I", len(js)) + b"JSON" + js + \
        struct.pack("<I", len(buf)) + b"BIN\x00" + bytes(buf)
    Path(outpath).write_bytes(glb)
    print(f"{outpath}: {len(glb)}B nodes={len(nodes)} meshes={len(meshes_out)} bones={len(joints)}")


if __name__ == "__main__":
    build_glb(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4],
              animfiles=sys.argv[5:] or None)
