import argparse
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT = ROOT / "scratch" / "dgm_templates"

TEMPLATES = {
    "biped_tail": {
        "label": "双足带尾",
        "unit": "czx_dgm_greymon",
        "status": "review_required",
        "source": ROOT / "scratch" / "greymon_trial",
        "files": {
            "model": "czx_dgm_greymon_trial_bound.glb",
            "skeleton": "skel_czx_greymo_trial.json",
            "pose": "../greymon_chr050_trial/chr050_move.pose.json",
            "mapping": "jmap.json",
            "preview": "../dgm_template_env/biped_tail/run_flat/frame000.png",
            "probe": "../dgm_template_env/biped_tail/run_flat/probe.json",
        },
        "notes": "尾链已从 cape 分支重建；原生 chr050 动作已渲染，但跑步仍需通过接地门。",
    },
    "quadruped_longtail": {
        "label": "四足长尾",
        "unit": "czx_dgm_garurumon",
        "status": "ready_for_template_review",
        "source": ROOT / "scratch" / "dgm_pub_batch" / "czx_dgm_garurumon",
        "files": {
            "model": "czx_dgm_garurumon_bound.glb",
            "skeleton": "skel_czx_ga.json",
            "pose": "pose_wf1_walk_01.json",
            "mapping": "jmap.json",
            "preview": "../dgm_template_env/quadruped_longtail/slope_up_12deg/frame000.png",
            "probe": "../dgm_template_env/quadruped_longtail/slope_up_12deg/probe.json",
        },
        "notes": "当前五类中唯一已通过实例映射拓扑审计的代表模板。",
    },
    "winged_biped": {
        "label": "飞翼双足",
        "unit": "czx_dgm_birdramon",
        "status": "evidence_missing",
        "source": ROOT / "scratch" / "dgm_pub_batch" / "czx_dgm_birdramon",
        "files": {
            "model": "czx_dgm_birdramon_bound.glb",
            "skeleton": "skel_czx_b0.json",
            "pose": "pose_bi1_fly_walk_01.json",
            "preview": "../dgm_template_env/winged_biped/obstacle_025h/frame000.png",
            "probe": "../dgm_template_env/winged_biped/obstacle_025h/probe.json",
        },
        "notes": "绑定和飞行动作样例已存在，但代表实例缺少独立 jmap 证据。",
    },
    "serpentine": {
        "label": "蛇形长身",
        "unit": "czx_dgm_seadramon",
        "status": "evidence_missing",
        "source": ROOT / "scratch" / "dgm_pub_batch" / "czx_dgm_seadramon",
        "files": {
            "model": "czx_dgm_seadramon_bound.glb",
            "skeleton": "skel_czx_sea.json",
            "pose": "pose_sn01_run_01.json",
            "preview": "../dgm_template_env/serpentine/slope_up_12deg/frame000.png",
            "probe": "../dgm_template_env/serpentine/slope_up_12deg/probe.json",
        },
        "notes": "蛇形骨架和跑步姿态样例已存在，但代表实例缺少独立 jmap 证据。",
    },
    "arthropod": {
        "label": "多足甲壳",
        "unit": "czx_dgm_kabuterimon",
        "status": "evidence_missing",
        "source": ROOT / "scratch" / "dgm_pub_batch" / "czx_dgm_kabuterimon",
        "files": {
            "model": "czx_dgm_kabuterimon_bound.glb",
            "skeleton": "skel_czx_kabu.json",
            "pose": "pose_sp1_run_01.json",
            "preview": "../dgm_template_env/arthropod/obstacle_025h/frame000.png",
            "probe": "../dgm_template_env/arthropod/obstacle_025h/probe.json",
        },
        "notes": "多足绑定和跑步姿态样例已存在，但代表实例缺少独立 jmap 证据。",
    },
}


def copy_asset(src, dst):
    if not src.exists():
        raise FileNotFoundError(src)
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def export(out):
    manifest = {"schema_version": 1, "output": str(out), "templates": []}
    for template_id, spec in TEMPLATES.items():
        target_dir = out / template_id
        target_dir.mkdir(parents=True, exist_ok=True)
        copied = {}
        for kind, relative in spec["files"].items():
            if relative.startswith("../"):
                src = ROOT / "scratch" / relative[3:]
            else:
                src = spec["source"] / relative
            target_name = {
                "model": f"template_{template_id}.glb",
                "skeleton": f"template_{template_id}_skeleton.json",
                "pose": f"template_{template_id}_pose.json",
                "mapping": "jmap.json",
                "preview": "preview.png",
                "probe": "probe.json",
            }[kind]
            dst = target_dir / target_name
            copy_asset(src, dst)
            copied[kind] = str(dst)
        entry = {
            "template_id": template_id,
            "label": spec["label"],
            "unit": spec["unit"],
            "status": spec["status"],
            "files": copied,
            "notes": spec["notes"],
        }
        (target_dir / "template.json").write_text(
            json.dumps(entry, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        manifest["templates"].append(entry)
    (out / "template_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    return manifest


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(DEFAULT_OUT))
    args = ap.parse_args()
    manifest = export(Path(args.out))
    print("DIGIMON_TEMPLATE_ASSETS", args.out, "templates", len(manifest["templates"]))
    for entry in manifest["templates"]:
        print(entry["template_id"], entry["status"], entry["files"]["model"])


if __name__ == "__main__":
    main()
