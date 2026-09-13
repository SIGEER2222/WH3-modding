# 项目结构

本文件说明 `E:\Code\WH3-modding` 的目录职责，以及制作具体 WH3 MOD 时推荐使用的源文件、打包输出和 Workshop 发布结构。

## 当前结构

```text
WH3-modding/
├── AGENTS.md
├── README.md
├── .codex/
│   └── project_context.md
├── .agents/
│   └── README.md
├── assets/
│   └── image/
├── docs/
│   ├── PROJECT_STRUCTURE.md
│   ├── RPFM_USAGE.md
│   └── DEVELOPMENT_GUIDE_UPDATE_RULES.md
├── mod_files/
├── mod_output/
├── workshop_release/
├── manual_edit/
├── gamedata/
├── bilingual/
├── tools/
├── rpfm-v5.0.6-x86_64-pc-windows-msvc/
├── wyccc-warhammer-mod-manager/   # 本地 junction 到 wyccc-warhammer-mod-manager 工具仓库
└── warhammer-mod-development_generic/
    ├── SKILL.md
    ├── README.md
    ├── MANIFEST.md
    ├── CHANGELOG.md
    └── references/
```

## 顶层目录职责

| 路径 | 职责 | 版本管理 |
|---|---|---|
| `AGENTS.md` | Codex 和代理的项目规则入口 | 纳入 |
| `.codex/project_context.md` | Codex 专用上下文摘要 | 本地隐藏配置，默认忽略 |
| `.agents/README.md` | 其他代理入口说明 | 本地隐藏配置，默认忽略 |
| `docs/` | 项目级说明文档 | 纳入 |
| `assets/image/` | 用户维护的图片、美术源素材、参考图 | 忽略 |
| `mod_files/` | MOD 打包前的可维护源文件 | 纳入 |
| `mod_output/` | RPFM 或脚本打包生成的 `.pack` 等产物 | 忽略 |
| `workshop_release/` | Steam Workshop 发布材料、预览图、BBCode 文案 | 忽略 |
| `manual_edit/` | 用户手工 Blender 修权工作目录（`.blend` 大文件）；只引用/追加，不整理 | 忽略 |
| `gamedata/` | 提取的游戏原版脚本、UI、DB 等数据；只读参考 | 忽略 |
| `bilingual/` | 游戏内中英对照和本地化参考文件；只读参考 | 忽略 |
| `references/` | 本地 MOD/英雄/美术参考样例，仅引用 | 纳入 |
| `tools/` | 工作区级脚本（如 `export_gamedata.py` 导出 gamedata/bilingual） | 纳入 |
| `rpfm-v5.0.6-x86_64-pc-windows-msvc/` | RPFM 工具本体 | 忽略 |
| `wyccc-warhammer-mod-manager/` | 本地 junction 到 `wyccc-warhammer-mod-manager` 工具仓库；MOD 管理器参考/开发入口 | 忽略 |
| `scratch/` | 临时/实验性文件；一次性脚本、调试输出、中间导出、截图等 | 忽略 |
| `tools/_*/` | `tools/` 下脚本自身的输出、下载物、中间体（`_out`、`_dl`、`_donor`、`_skel` 等） | 忽略 |
| `warhammer-mod-development_generic/` | WH3 MOD development 指南源副本 | 纳入 |

## MOD 源文件结构

具体 MOD 默认放在：

```text
mod_files/
└── <MOD名>/
    ├── db/
    ├── script/
    │   └── campaign/
    │       └── mod/
    ├── text/
    │   └── db/
    ├── ui/
    ├── notes/
    └── TESTING.md
```

常见 Pack 内部路径：

| 类型 | Pack 内部路径 |
|---|---|
| DB 表 | `db/<table_name>/<internal_table_name>` |
| 战役 Lua | `script/campaign/mod/<prefix>_<feature>.lua` |
| 中文 Loc | `text/db/<prefix>_<feature>_CN.loc` |
| 英文 Loc | `text/db/en/<prefix>_<feature>_EN.loc` |
| UI 覆盖 | `ui/...` |
| 资源文件 | 按原版同路径放置 |

本地导入导出时，DB 和 Loc 常以 `.tsv` 或 `.loc.tsv` 形式保存；Pack 内部最终路径以 RPFM 显示为准。

## 打包与发布结构

打包前先确认用户偏好：

1. 用户手动用 RPFM 打包：Codex 只准备 `mod_files/<MOD名>/` 源文件和必要说明。
2. Codex 自动打包：Codex 可调用 RPFM/脚本生成 `.pack`，但需要额外执行导入、diagnostics 和回归核对。

打包输出默认放：

```text
mod_output/
├── <mod_name>.pack
└── <mod_name>.png
```

Workshop 发布材料默认放：

```text
workshop_release/
└── <MOD名>/
    ├── description.bbcode.txt
    ├── <pack_name>.png
    └── release_notes.bbcode.txt
```

Steam Workshop 文本描述使用 Steam BBCode。Markdown 可以作为草稿，但最终发布文本应转换为 BBCode。若按发布批次整理，可使用 `workshop_release/<release_version>/<workshop_item_name>/`；其中 `.pack`、同名 `.png`、上传清单和 `.zip` 仍视为发布产物，默认不纳入版本管理。

## 文件归属规则

- 工具文件归属 RPFM 目录，不参与 MOD 逻辑维护。
- 通用经验归属 `warhammer-mod-development_generic/`。
- 项目级说明归属 `docs/` 与 `AGENTS.md`。
- 原版数据与中英本地化参考归属 `gamedata/`、`bilingual/`，只读使用。
- 具体 MOD 源目录中不要保留 `_bak`、`db_binary`、中间导出等生成/备份目录；这些属于临时产物，归属 `scratch/`。
- 仓库根目录禁止新增任何临时文件/目录；`_tmp_*`、`_preview/`、`_work_*/` 等临时命名只允许出现在 `scratch/` 内。新增顶级目录必须先在本文件与 `AGENTS.md` 登记职责，详见 `AGENTS.md` "工作区卫生" 一节。

## gamedata / bilingual 重建说明（2026-09-06）

旧工作区（D 盘）丢失后，这两个目录由 `tools/export_gamedata.py` 从当前游戏
`data/*.pack` 重新导出，schema 使用 rpfm-schemas 仓库最新 `schema_wh3.ron`
（比本地 RPFM 缓存 2025-09 的版本新，可用环境变量 `RPFM_SCHEMA_WH3` 覆盖）。

- `gamedata/db/<table>/<internal>.tsv`：解码为 RPFM TSV 布局（列名行→元数据行→数据行）。
  无法解码的表保留原始二进制为 `<internal>.raw`（本次仅
  `autoresolver_unit_group_categories_enums_tables` 一张）。
- `gamedata/script/`、`gamedata/ui/`：原版脚本与 UI 文本资源（xml/csv/txt 等）。
- `gamedata/documentation/` 未恢复（原目录来自网络脚本文档导出，不在游戏 pack 内）；
  查 Lua API 时改用 `gamedata/script/` 与 Chadvandy 在线文档 `[需验证]`。
- `bilingual/EN/`、`bilingual/CN/`：按 loc 文件拆分的 TSV（key/text/tooltip 三列）；
  `bilingual/localisation__.loc_CN.tsv` 为合并后的中文 key→text 速查表。
- 重新导出命令：`python tools/export_gamedata.py`（需 lz4、zstandard）。
- 一次性脚本、调试输出、中间导出、截图等无关改动归属 `scratch/`，不纳入版本管理。
- 具体 MOD 源文件归属 `mod_files/<MOD名>/`。
- 具体 MOD 设计、测试、故障记录归属 `mod_files/<MOD名>/notes/` 或该 MOD 自己的文档。
- 可复用且已验证的经验，再按 `docs/DEVELOPMENT_GUIDE_UPDATE_RULES.md` 提升到 development 指南。
