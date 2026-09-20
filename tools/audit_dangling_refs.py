"""WH3 MOD 悬空引用静态审计。

目的：抓住 "czx_dgm_agumon 类" 崩溃源——mod TSV 里引用了不存在的 key
（改名/删 key 后残留引用），以及缺变体网格文件、缺兵牌、缺中文 loc 等问题。

数据源：
- vanilla 键集：gamedata/db/<table>/data__.tsv（2026-09-06 导出）
- mod 行：mod_files/*/db/<table>/*.tsv + mod_files/*/text/db/*.loc.tsv

FK 推断：对每张源表的每列，在 vanilla 各表的唯一列里找覆盖率 >= COVER_MIN
的最小目标集作为外键目标；找不到则退回"同列 vanilla 值集"闭枚举检查。
mod 行值若在目标集 ∪ 全 mod 定义键池 ∪ 空前缀白名单 内则通过。

用法：
    python tools/audit_dangling_refs.py [--mods name1,name2] [--report out.tsv]
    可用 WSL python3 或 Windows Python313（纯读仓库文件）。
"""
from __future__ import annotations

import argparse
import csv
import os
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAMEDATA_DB = ROOT / "gamedata" / "db"
MOD_FILES = ROOT / "mod_files"
BILINGUAL_CN = ROOT / "bilingual" / "localisation__.loc_CN.tsv"

COVER_MIN = 0.95          # 源列 vanilla 值被目标键集覆盖的比例下限
ENUM_FALLBACK_MIN = 0.80  # 同列闭枚举检查的覆盖率下限（低于此则该列不查）

# 本工作区自定义前缀——这些 key 是"我们自己的"，悬空必须报 ERROR
OWN_PREFIXES = (
    "czx_", "cthd", "hef_", "dgm_", "pm", "zz_", "cust_",
)
# 上游被补丁 mod 的前缀——其 key 可能定义在工坊包里，悬空只报 WARN
UPSTREAM_PREFIXES = ("psw_", "xyz_", "nanu_", "sm0_", "aig3_", "lalolalo", "cth_")

SEVERITY_ERR = tuple(OWN_PREFIXES)
SEVERITY_WARN = tuple(OWN_PREFIXES + UPSTREAM_PREFIXES)

# 目标表候选：列名 -> 默认主键列（用于键集构建；唯一性会再验证）
PK_HINTS = {
    "main_units_tables": "unit",
    "land_units_tables": "key",
    "melee_weapons_tables": "key",
    "missile_weapons_tables": "key",
    "projectiles_tables": "key",
    "projectiles_explosions_tables": "key",
    "unit_abilities_tables": "key",
    "special_ability_phases_tables": "id",
    "battle_entities_tables": "key",
    "battle_entity_stats_tables": "key",
    "battle_skeletons_tables": "name",
    "ui_unit_groupings_tables": "key",
    "battle_animations_table_tables": "key",
    "variants_tables": "variant_name",
    "unit_sets_tables": "key",
    "factions_tables": "key",
    "building_levels_tables": "level_name",
    "building_chains_tables": "key",
    "unit_attributes_tables": "key",
    "unit_attributes_groups_tables": "group_name",
    "agent_subtypes_tables": "key",
    "agent_uniforms_tables": "uniform_name",
    "ancillaries_tables": "key",
    "character_skills_tables": "key",
    "character_skill_nodes_tables": "key",
    "character_skill_node_sets_tables": "key",
    "effects_tables": "effect",
    "effect_bundles_tables": "key",
    "dilemmas_tables": "key",
    "cultures_tables": "key",
    "subcultures_tables": "subculture",
    "battle_personalities_tables": "key",
    "unit_spacings_tables": "key",
    "loading_screen_quotes_tables": "key",
    "mounts_tables": "key",
    "mercenary_unit_groups_tables": "key",
    "advice_threads_tables": "thread",
    "advice_levels_tables": "key",
    "slot_templates_tables": "key",
    "battlefield_engines_tables": "key",
    "land_unit_articulated_vehicles_tables": "key",
    "first_person_engines_tables": "key",
    "names_tables": "key",
    "names_groups_tables": "key",
    "technologies_tables": "key",
    "unit_shield_types_tables": "key",
    "missile_weapons_to_projectiles_tables": "missile_weapon",
    "cdir_events_dilemma_choice_details_tables": "choice_key",
    "campaign_group_unique_agents_tables": "agent",
    "unique_agents_tables": "agent_key",
    "military_force_type_horde_details_tables": "type",
}


def read_tsv(path: Path):
    """返回 (header, data_rows)。跳过 BOM 与空行。"""
    try:
        with open(path, encoding="utf-8-sig", errors="replace", newline="") as fh:
            rows = [r for r in csv.reader(fh, delimiter="\t") if any(c.strip() for c in r)]
    except Exception as e:  # noqa: BLE001
        return None, [], str(e)
    if not rows:
        return None, [], "empty"
    # RPFM 导出格式：行1=列名，行2=#table;ver;path 元数据，行3+=数据
    data = [r for r in rows[1:] if not (r and r[0].lstrip().startswith("#"))]
    return rows[0], data, None


def col_idx(header, name):
    try:
        return header.index(name)
    except ValueError:
        return -1


def load_vanilla():
    """vanilla[table] = {col: set(values)}，只保留 data__.tsv。"""
    vanilla: dict[str, dict[str, set[str]]] = {}
    for tdir in sorted(GAMEDATA_DB.iterdir()):
        if not tdir.is_dir():
            continue
        t = tdir.name
        f = tdir / "data__.tsv"
        if not f.exists():
            cands = list(tdir.glob("*.tsv"))
            if not cands:
                continue
            f = cands[0]
        hdr, data, err = read_tsv(f)
        if hdr is None:
            continue
        cols: dict[str, set[str]] = {c: set() for c in hdr}
        for r in data:
            for i, c in enumerate(hdr):
                if i < len(r) and r[i] != "":
                    cols[c].add(r[i])
        vanilla[t] = cols
    return vanilla


def unique_cols(vanilla):
    """uniq[table] = set(列名)，该列在 vanilla 全表唯一且非空。"""
    uniq = {}
    for t, cols in vanilla.items():
        f = GAMEDATA_DB / t / "data__.tsv"
        if not f.exists():
            continue
        hdr, data, _ = read_tsv(f)
        if not hdr:
            continue
        u = set()
        for i, c in enumerate(hdr):
            vals = [r[i] for r in data if i < len(r) and r[i].strip()]
            if vals and len(vals) == len(set(vals)) and len(vals) > 3:
                u.add(c)
        uniq[t] = u
    return uniq


def collect_mod_tsvs(mod_filter=None):
    """mods[modname][table] = [(file, header, data_rows)]"""
    mods: dict[str, dict[str, list]] = defaultdict(lambda: defaultdict(list))
    for mdir in sorted(MOD_FILES.iterdir()):
        if not mdir.is_dir() or (mod_filter and mdir.name not in mod_filter):
            continue
        db = mdir / "db"
        if not db.is_dir():
            continue
        for tdir in sorted(db.iterdir()):
            if not tdir.is_dir():
                continue
            for f in sorted(tdir.glob("*.tsv")):
                hdr, data, err = read_tsv(f)
                if hdr is None:
                    mods[mdir.name][tdir.name].append((f, None, err or "empty"))
                    continue
                mods[mdir.name][tdir.name].append((f, hdr, data))
    return mods


def build_mod_key_pool(mods):
    """所有 mod 定义的主键值池：表名 -> set(key)。"""
    pool: dict[str, set[str]] = defaultdict(set)
    for mdir_name, tables in mods.items():
        for t, files in tables.items():
            pk = PK_HINTS.get(t)
            for f, hdr, data in files:
                if hdr is None:
                    continue
                idx = col_idx(hdr, pk) if pk else -1
                if idx < 0:
                    # 自动选唯一列：先按常见主键名，再退首个唯一列（单行表也收）
                    KEYISH = ("key", "name", "unit", "unit_record", "id", "thread",
                              "effect", "level_name", "group_name", "subculture",
                              "variant_name", "model", "uniform_name", "land_unit",
                              "agent_subtype", "agent", "building", "chain",
                              "missile_weapon", "melee_weapon", "projectile",
                              "phase", "faction", "culture_pack", "attribute",
                              "attribute_group", "ancillary", "skill",
                              "character_skill_key", "effect_bundle_key", "quote",
                              "unit_set", "pool", "type", "skeleton",
                              "man_animations_table", "battle_animations_table",
                              "valid_group", "mounted_unit")
                    uniq_cols = []
                    for i, c in enumerate(hdr):
                        vals = [r[i] for r in data if i < len(r) and r[i].strip()]
                        if vals and len(vals) == len(set(vals)) and len(vals) >= 1:
                            uniq_cols.append(i)
                    for kn in KEYISH:
                        j = col_idx(hdr, kn)
                        if j in uniq_cols:
                            idx = j
                            break
                    if idx < 0 and uniq_cols:
                        idx = uniq_cols[0]
                if idx < 0:
                    continue
                for r in data:
                    if idx < len(r) and r[idx].strip():
                        pool[t].add(r[idx])
    return pool


def infer_fk_map(vanilla, uniq):
    """fk_map[(src_table, src_col)] = (tgt_table, tgt_col, coverage)。"""
    fk = {}
    tgt_list = []
    for t, cols in vanilla.items():
        for c in uniq.get(t, ()):
            tgt_list.append((t, c, cols[c]))
    for st, cols in vanilla.items():
        for sc, svals in cols.items():
            if not svals:
                continue
            best = None
            for tt, tc, tset in tgt_list:
                if tt == st and tc == sc:
                    continue
                if len(tset) < len(svals) * COVER_MIN * 0.5:
                    continue
                cov = len(svals & tset) / len(svals)
                if cov >= COVER_MIN:
                    if best is None or len(tset) < len(best[2]):
                        best = (tt, tc, tset, cov)
            if best:
                fk[(st, sc)] = (best[0], best[1], best[3])
    return fk


def audit(mod_filter=None, report_path=None):
    vanilla = load_vanilla()
    uniq = unique_cols(vanilla)
    mods = collect_mod_tsvs(mod_filter)
    mod_pool = build_mod_key_pool(mods)
    fk_map = infer_fk_map(vanilla, uniq)

    # 全部 mod 键的扁平池（跨表），用于放行自定义 key
    flat_pool = set()
    for s in mod_pool.values():
        flat_pool |= s

    problems = []   # (level, mod, table, file, rowinfo, msg)
    stats = defaultdict(int)

    def add(level, mod, table, fname, where, msg):
        problems.append((level, mod, table, fname, where, msg))
        stats[level] += 1

    for mod, tables in mods.items():
        for t, files in tables.items():
            for f, hdr, data in files:
                if hdr is None:
                    add("ERROR", mod, t, f.name, "-", f"TSV 解析失败: {data}")
                    continue
                # 列数一致性
                ncol = len(hdr)
                for ri, r in enumerate(data):
                    if len(r) != ncol:
                        add("WARN", mod, t, f.name, f"row{ri+3}",
                            f"列数 {len(r)} != 表头 {ncol}")
                # FK 检查
                for ci, cname in enumerate(hdr):
                    tgt = fk_map.get((t, cname))
                    enum_vals = vanilla.get(t, {}).get(cname)
                    for ri, r in enumerate(data):
                        if ci >= len(r):
                            continue
                        v = r[ci].strip()
                        if not v or v.lower() in ("true", "false") or re.fullmatch(r"-?\d+(\.\d+)?", v):
                            continue
                        if v in flat_pool:
                            continue
                        if tgt:
                            tt, tc, cov = tgt
                            if v not in vanilla.get(tt, {}).get(tc, ()):
                                lvl = "ERROR" if v.startswith(SEVERITY_ERR) else "WARN"
                                add(lvl, mod, t, f.name, f"row{ri+3}.{cname}",
                                    f"{v!r} 不在 {tt}.{tc} (cov={cov:.0%})")

        # ---- 文件级检查：variantmesh / unit_card / loc ----
        mdir = MOD_FILES / mod
        vmd_dir = mdir / "variantmeshes" / "variantmeshdefinitions"
        icons_dir = mdir / "ui" / "units" / "icons"
        # 收集 mod 的 vmd 文件（跨 mod 也要能命中：先收集全局）
        global_vmds = set()
        for md2 in MOD_FILES.iterdir():
            vd = md2 / "variantmeshes" / "variantmeshdefinitions"
            if vd.is_dir():
                for x in vd.iterdir():
                    if x.suffix == ".variantmeshdefinition":
                        global_vmds.add(x.stem)
        global_icons = set()
        for md2 in MOD_FILES.iterdir():
            ic = md2 / "ui" / "units" / "icons"
            if ic.is_dir():
                for x in ic.iterdir():
                    global_icons.add(x.stem)

        # loc 键集：mod loc + 全局 mod loc + bilingual CN
        loc_keys = set()
        for md2 in MOD_FILES.iterdir():
            td = md2 / "text" / "db"
            if td.is_dir():
                for lf in td.glob("*.loc.tsv"):
                    h, d, _ = read_tsv(lf)
                    if h:
                        ki = col_idx(h, "key")
                        if ki >= 0:
                            for r in d:
                                if ki < len(r) and r[ki].strip():
                                    loc_keys.add(r[ki])
        if BILINGUAL_CN.exists():
            h, d, _ = read_tsv(BILINGUAL_CN)
            if h:
                ki = col_idx(h, "key")
                for r in d:
                    if ki < len(r) and r[ki].strip():
                        loc_keys.add(r[ki])

        vanilla_variants = vanilla.get("variants_tables", {}).get("variant_name", set())
        # vanilla variant_filename 全集（ vanilla 网格文件名，mod_files 没有实体文件）
        vanilla_vmd_files = vanilla.get("variants_tables", {}).get("variant_filename", set()) | \
            vanilla.get("variants_tables", {}).get("low_poly_filename", set()) | \
            vanilla.get("variants_tables", {}).get("super_low_poly_filename", set())
        # variant_name -> variant_filename 映射（mod+vanilla），供 unit_variants 查文件
        variant_file_of = {}
        for t2 in ("variants_tables",):
            vf = GAMEDATA_DB / t2 / "data__.tsv"
            h, d, _ = read_tsv(vf) if vf.exists() else (None, [], None)
            if h:
                ni, fi2 = col_idx(h, "variant_name"), col_idx(h, "variant_filename")
                for r in d:
                    if ni < len(r):
                        variant_file_of[r[ni]] = r[fi2] if fi2 < len(r) and r[fi2] else r[ni]
        for md2 in MOD_FILES.iterdir():
            vd2 = md2 / "db" / "variants_tables"
            if vd2.is_dir():
                for vf2 in vd2.glob("*.tsv"):
                    h, d, _ = read_tsv(vf2)
                    if not h:
                        continue
                    ni, fi2 = col_idx(h, "variant_name"), col_idx(h, "variant_filename")
                    for r in d:
                        if ni < len(r):
                            variant_file_of[r[ni]] = r[fi2] if fi2 < len(r) and r[fi2] else r[ni]

        for t, files in tables.items():
            for f, hdr, data in files:
                if hdr is None:
                    continue
                if t == "variants_tables":
                    vi = col_idx(hdr, "variant_name")
                    fi = col_idx(hdr, "variant_filename")
                    for ri, r in enumerate(data):
                        if vi < len(r) and r[vi].strip():
                            v = r[vi].strip()
                            vfile = r[fi].strip() if 0 <= fi < len(r) and r[fi].strip() else v
                            if (v.startswith(SEVERITY_ERR) and vfile not in global_vmds
                                    and vfile not in vanilla_vmd_files):
                                add("ERROR", mod, t, f.name, f"row{ri+3}",
                                    f"variant {v!r} (file {vfile!r}) 无 variantmeshdefinition 文件")
                if t == "unit_variants_tables":
                    vi = col_idx(hdr, "variant")
                    ci = col_idx(hdr, "unit_card")
                    for ri, r in enumerate(data):
                        if 0 <= vi < len(r) and r[vi].strip():
                            v = r[vi].strip()
                            vfile = variant_file_of.get(v, v)
                            if (v.startswith(SEVERITY_ERR) and vfile not in global_vmds
                                    and vfile not in vanilla_vmd_files and v not in vanilla_variants):
                                add("ERROR", mod, t, f.name, f"row{ri+3}.variant",
                                    f"variant {v!r} (file {vfile!r}) 无 vmd 文件")
                        if ci >= 0 and ci < len(r) and r[ci].strip():
                            c = r[ci].strip()
                            if c.startswith(SEVERITY_ERR) and c not in global_icons:
                                add("WARN", mod, t, f.name, f"row{ri+3}.unit_card",
                                    f"兵牌 {c!r} 无 ui/units/icons/{c}.png")
                # loc 约定：<描述表名去_tables>_text_<key>、onscreen_name 为 <表>_onscreen_name_<key>
                LOC_TEXT_TABLE_PREFIX = {
                    "unit_description_short_texts_tables": "unit_description_short_texts_text_",
                    "unit_description_historical_texts_tables": "unit_description_historical_texts_text_",
                }
                LAND_TEXT_COL_PREFIX = {
                    "short_description_text": "unit_description_short_texts_text_",
                    "historical_description_text": "unit_description_historical_texts_text_",
                }
                if t in LOC_TEXT_TABLE_PREFIX:
                    ki = col_idx(hdr, "key")
                    for ri, r in enumerate(data):
                        if ki >= 0 and ki < len(r) and r[ki].strip():
                            k = r[ki].strip()
                            lk = LOC_TEXT_TABLE_PREFIX[t] + k
                            if k.startswith(SEVERITY_ERR) and lk not in loc_keys and k not in loc_keys:
                                add("WARN", mod, t, f.name, f"row{ri+3}",
                                    f"loc key {lk!r} 无 CN loc 条目")
                if t == "land_units_tables":
                    ki2 = col_idx(hdr, "key")
                    for cn, pre in LAND_TEXT_COL_PREFIX.items():
                        ci = col_idx(hdr, cn)
                        if ci < 0:
                            continue
                        for ri, r in enumerate(data):
                            if ci < len(r) and r[ci].strip():
                                k = r[ci].strip()
                                if k.startswith(SEVERITY_ERR) and (pre + k) not in loc_keys and k not in loc_keys:
                                    add("WARN", mod, t, f.name, f"row{ri+3}.{cn}",
                                        f"loc key {pre + k!r} 无 CN loc")
                    # 单位 onscreen name loc
                    for ri, r in enumerate(data):
                        if ki2 >= 0 and ki2 < len(r) and r[ki2].strip():
                            k = r[ki2].strip()
                            if k.startswith(SEVERITY_ERR):
                                if f"land_units_onscreen_name_{k}" not in loc_keys:
                                    add("WARN", mod, t, f.name, f"row{ri+3}.key",
                                        f"land_units_onscreen_name_{k} 无 CN loc")
                if t == "main_units_tables":
                    ui = col_idx(hdr, "unit")
                    for ri, r in enumerate(data):
                        if ui >= 0 and ui < len(r) and r[ui].strip():
                            k = r[ui].strip()
                            if k.startswith(SEVERITY_ERR):
                                if f"units_onscreen_name_{k}" not in loc_keys:
                                    add("WARN", mod, t, f.name, f"row{ri+3}.unit",
                                        f"units_onscreen_name_{k} 无 CN loc")
                if t == "unit_abilities_tables":
                    ki = col_idx(hdr, "key")
                    for ri, r in enumerate(data):
                        if ki >= 0 and ki < len(r) and r[ki].strip():
                            k = r[ki].strip()
                            if k.startswith(SEVERITY_ERR):
                                if f"unit_abilities_onscreen_name_{k}" not in loc_keys:
                                    add("WARN", mod, t, f.name, f"row{ri+3}.key",
                                        f"unit_abilities_onscreen_name_{k} 无 CN loc")

        # ---- Lua: show_advice / add_listener 静态检查 ----
        for lf in (mdir / "script").rglob("*.lua") if (mdir / "script").is_dir() else []:
            try:
                src = lf.read_text(encoding="utf-8", errors="replace")
            except Exception:
                continue
            for m in re.finditer(r'show_advice\s*\(\s*"([^"]+)"', src):
                key = m.group(1)
                tgt = (vanilla.get("advice_threads_tables", {}).get("thread", set())
                       | mod_pool.get("advice_threads_tables", set()))
                if key not in tgt:
                    # 上游被补丁工坊包可能已定义该 key（如 psw 上游 1191 条），降级 WARN
                    add("WARN", mod, "lua", lf.name, "show_advice",
                        f"advice key {key!r} 无 advice_threads 记录（若上游包未加载会卡死弹窗）")
            for m in re.finditer(r"core:add_listener\s*\(([^)]*)\)", src, re.S):
                args = m.group(1)
                if "function" in args or "\n" in args:
                    continue  # 跨行/含匿名函数时无法可靠计数
                nargs = args.count(",") + 1 if args.strip() else 0
                if nargs == 4:
                    add("WARN", mod, "lua", lf.name, "add_listener",
                        f"疑似 4 参数 add_listener（要求 5 参数）: {args[:60]!r}")

    # 汇总输出
    by_level = defaultdict(list)
    for p in problems:
        by_level[p[0]].append(p)
    print(f"== audit: {len(problems)} findings "
          f"(ERROR={stats['ERROR']} WARN={stats['WARN']} INFO={stats['INFO']}) ==")
    for lvl in ("ERROR", "WARN", "INFO"):
        for mod, table, fname, where, msg in [(p[1], p[2], p[3], p[4], p[5]) for p in by_level[lvl]]:
            print(f"[{lvl}] {mod} | {table} | {fname} | {where} | {msg}")

    if report_path:
        with open(report_path, "w", encoding="utf-8", newline="") as fh:
            w = csv.writer(fh, delimiter="\t")
            w.writerow(["level", "mod", "table", "file", "where", "msg"])
            w.writerows(problems)
        print(f"report -> {report_path}")
    return stats


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mods", default="", help="逗号分隔 mod 目录名过滤")
    ap.add_argument("--report", default="", help="TSV 报告输出路径")
    args = ap.parse_args()
    mf = set(args.mods.split(",")) if args.mods else None
    rp = args.report or str(ROOT / "scratch" / "audit_dangling_refs_report.tsv")
    Path(rp).parent.mkdir(parents=True, exist_ok=True)
    stats = audit(mf, rp)
    return 1 if stats["ERROR"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
