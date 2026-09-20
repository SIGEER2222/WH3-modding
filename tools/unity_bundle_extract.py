"""Extract assets from a Unity AssetBundle (e.g. Sands of Salzaar workshop mod).

Usage:
    python unity_bundle_extract.py <bundle_path> <out_dir> [--inventory-only]

Outputs:
    <out_dir>/inventory.json        object type counts + per-object index
    <out_dir>/textures/*.png        Texture2D / Sprite exports
    <out_dir>/meshes/*.obj          Mesh exports (OBJ, no skeleton)
    <out_dir>/meshes/*.skin.json    bone weights + bindposes for skinned meshes
    <out_dir>/anims/*.json          AnimationClip typetree dumps
    <out_dir>/typetree/<type>/*.json other objects dumped via typetree (materials etc.)
"""
import json
import sys
import traceback
from collections import Counter
from pathlib import Path

import UnityPy


def safe_name(s: str) -> str:
    return "".join(c if c.isalnum() or c in "._- " else "_" for c in s).strip() or "unnamed"


def main() -> None:
    bundle_path = sys.argv[1]
    out_dir = Path(sys.argv[2])
    inventory_only = "--inventory-only" in sys.argv
    out_dir.mkdir(parents=True, exist_ok=True)

    env = UnityPy.load(bundle_path)

    inventory = []
    counts = Counter()
    for obj in env.objects:
        tname = obj.type.name
        counts[tname] += 1
        entry = {
            "path_id": obj.path_id,
            "type": tname,
            "name": getattr(obj, "path", None) or "",
        }
        try:
            if tname in ("GameObject", "Mesh", "Texture2D", "AnimationClip",
                         "Material", "SkinnedMeshRenderer", "AnimatorController"):
                entry["name"] = obj.read().m_Name or entry["name"]
        except Exception:
            pass
        inventory.append(entry)

    print("object counts:", dict(counts.most_common()))
    (out_dir / "inventory.json").write_text(
        json.dumps({"counts": dict(counts.most_common()), "objects": inventory},
                   ensure_ascii=False, indent=1),
        encoding="utf-8",
    )
    if inventory_only:
        return

    for obj in env.objects:
        tname = obj.type.name
        try:
            if tname == "Texture2D":
                tex = obj.read()
                p = out_dir / "textures" / (safe_name(tex.m_Name) + ".png")
                p.parent.mkdir(parents=True, exist_ok=True)
                tex.image.save(str(p))
            elif tname == "Mesh":
                mesh = obj.read()
                p = out_dir / "meshes" / (safe_name(mesh.m_Name) + ".obj")
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text(mesh.export(), encoding="utf-8")
                skin = getattr(mesh, "m_Skin", None)
                if skin:
                    side = {
                        "bindposes": [list(map(list, bp.get_e().tolist() if hasattr(bp, "get_e") else [])) for bp in mesh.m_BindPoses] if getattr(mesh, "m_BindPoses", None) else None,
                        "skin_count": len(skin),
                    }
                    try:
                        side["bindposes"] = [list(map(float, bp)) for bp in mesh.m_BindPoses]
                    except Exception:
                        pass
                    (out_dir / "meshes" / (safe_name(mesh.m_Name) + ".skin.json")).write_text(
                        json.dumps(side, ensure_ascii=False), encoding="utf-8")
            elif tname == "AnimationClip":
                clip = obj.read_typetree() if hasattr(obj, "read_typetree") else obj.read()
                p = out_dir / "anims" / (safe_name(getattr(clip, "m_Name", f"clip_{obj.path_id}")) + ".json")
                p.parent.mkdir(parents=True, exist_ok=True)
                if isinstance(clip, dict):
                    p.write_text(json.dumps(clip, ensure_ascii=False, default=str), encoding="utf-8")
                else:
                    p.write_text(json.dumps(clip.__dict__, ensure_ascii=False, default=str), encoding="utf-8")
        except Exception:
            print("FAILED", tname, obj.path_id, file=sys.stderr)
            traceback.print_exc()

    print("done ->", out_dir)


if __name__ == "__main__":
    main()
