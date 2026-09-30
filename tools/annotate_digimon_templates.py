import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from digimon_model_templates import template_for_record, template_id_for_record

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REPORT = ROOT / "scratch" / "dgm_pub_batch" / "report.json"


def annotate(path):
    report = json.loads(path.read_text(encoding="utf-8"))
    for record in report.values():
        template = template_for_record(record)
        record["template_id"] = template_id_for_record(record)
        record["template_motion_policy"] = template.get("motion_policy", {})
        record["template_environment"] = template.get("environment", {})
    path.write_text(json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8")
    return report


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--report", default=str(DEFAULT_REPORT))
    args = ap.parse_args()
    report = annotate(Path(args.report))
    print("TEMPLATE_METADATA_ANNOTATED", args.report, "records", len(report))


if __name__ == "__main__":
    main()
