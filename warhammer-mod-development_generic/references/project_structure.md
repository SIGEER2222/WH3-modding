# 项目结构说明

## 顶层目录

| 目录 | 用途 |
|---|---|
| `/mod_files` | 战锤3 MOD 打包前源文件目录，包含自己的 MOD 项目 |
| `/mod_output` | `.pack`、管理器缩略图等打包输出产物 |
| `/workshop_release` | Steam Workshop 发布材料；文本描述使用 Steam BBCode |
| `/assets/image` | 用户维护的图片、美术源素材和参考图 |
| `/bilingual` | 战锤3原版本地化/中英对照文件；`localisation__.loc_CN.tsv` 为中文，`/EN` 为英文原文；只读参考 |
| `/gamedata` | 战锤3原版脚本、UI、DB 文件；用于查表结构、API、原版用法；只读参考 |
| `/rpfm-v5.0.5-x86_64-pc-windows-msvc` | 本地 RPFM 工具目录；只调用，不修改 |

`assets/`、`bilingual/`、`gamedata/`、RPFM 工具目录、`mod_output/` 与 `workshop_release/` 默认不纳入版本管理。

`gamedata/` 是从游戏 pack 导出的本地原版数据快照，不会因 RPFM 刷新 dependencies/cache 自动更新。WH3 游戏更新后，如果后续仍要依赖本地搜索、表结构比对、脚本 API 或 UI 路径查证，应重新从当前游戏 pack 导出相关范围，或明确标记该目录仍是旧版本快照 `[需随版本复查]`。

## MOD 源文件目录结构

```text
mod_files/<MOD名称>/
├── db/
│   ├── <table_name>/
│   │   ├── !!!custom_xxx.tsv
│   │   ├── !!custom_xxx.tsv
│   │   ├── custom_xxx.tsv
│   │   └── ...
│   └── ...
├── script/
│   └── campaign/
│       ├── mod/
│       │   └── custom_xxx.lua
│       └── <原版脚本名>.lua        # 直接覆盖原版脚本，少用，高风险
├── text/
│   └── db/
│       ├── custom_xxx_CN.loc.tsv
│       └── en/
│           └── custom_xxx_EN.loc.tsv
├── ui/
├── notes/
└── TESTING.md
```

## 关键路径约定

| 类型 | 路径 |
|---|---|
| 自定义 Lua | `script/campaign/mod/custom_<feature>.lua` |
| DB 表 | `db/<table_name>/!!custom_<feature>.tsv` |
| 中文本地化 | `text/db/custom_<feature>_CN.loc.tsv` |
| 英文本地化 | `text/db/en/custom_<feature>_EN.loc.tsv` |
| 用户维护图片 | `assets/image/` |
| 打包输出 | `mod_output/<mod_name>.pack` |
| Workshop BBCode 文案 | `workshop_release/<MOD名>/description.bbcode.txt` |
| 原版 DB | `gamedata/db/<table_name>/` |
| 原版脚本 | `gamedata/script/` |
| 原版脚本文档 | `gamedata/documentation/script` |
| 英文原文 | `bilingual/EN` |
| 中文本地化 | `bilingual/localisation__.loc_CN.tsv` |
| 术语库 | `bilingual/术语库.md` |

## 打包与发布约定

需要打包 MOD 时，先询问用户选择：

1. 用户手动用 RPFM 打包：Codex 准备 `mod_files/<MOD名>/` 源文件和说明。
2. Codex 自动打包：Codex 调用 RPFM/脚本生成 `.pack`，并承担 diagnostics 与回归核对。

打包输出放 `mod_output/`。Workshop 发布文件放 `workshop_release/`，其中最终说明文本使用 Steam BBCode；Markdown 只可作为中间草稿。

## 前端派系选择显示

主菜单/领主选择界面的说明不一定读取战役 Lua 的结果。常见可查路径：

- 领主说明：`frontend_faction_leaders_tables` 与 `frontend_faction_leaders__.loc.tsv`。
- 派系机制文本：`frontend_factions_tables` 与 `frontend_factions__.loc.tsv`。
- 前端展示的代表单位：`frontend_faction_top_units_tables`。该表不等同于 startpos 的完整实际开局军队；在 WH3 `campaign_select_new.twui.xml` 的“领主详情 -> 初始军队”卡位中，实测该表不控制目标面板 `[实测/需随版本复查]`。
- 领主详情“初始军队”卡位：优先查 `gamedata/ui/frontend ui/campaign_select_new.twui.xml` 中的 `start_units`、`CcoFrontendFactionLeader.UnitList`、`CcoCampaignStartInfo` 与 `CcoUnitDetails.UnitRecordContext.IconPath` 链路；该面板通常由前端 CCO/startpos 类数据动态填充，Lua 进战役后调整开局军队不会提前改变主菜单卡牌。若必须改显示，通常需要 startpos/前端 CCO 相关资源，属于高冲突修改，先标注 `[需验证]`。
- 若目标是“主菜单 -> 战役 -> 新建 -> 选择传奇领主详情页”的初始军队兵牌，而不是进战役后的实际部队，脚本替换方案会保留 startpos 兼容性但通常不会改变该前端卡位；真正改卡位一般要改并重建 `campaigns/<campaign>/startpos.esf`，重点核对 Assembly Kit 的 `start_pos_land_units`、`start_pos_starting_general_options` 与可能存在的 additional units 类表 `[已查本地 UI / 已查外部 startpos 资料 / 实测需随版本复查]`。
- 派系/领主效果列表：优先查 `faction_starting_general_effects_tables` 指向的 `effect_bundle`，再查 `effect_bundles_to_effects_junctions_tables` 和对应 Loc。

## 第三方目标 MOD 使用规则

本通用版不内置任何固定 MOD 清单。

只有在用户明确提供或指定某个目标 MOD / 目标 Pack 时，才把它作为格式、命名、表版本和目录布局的参考。不要主动假设用户正在开发他人的某个 MOD，也不要将他人项目名写入生成文件。

## 新建功能推荐结构

例如功能名：`example_feature`

```text
mod_files/<MOD名>/
├── db/
│   ├── effects_tables/
│   │   └── !!custom_example_feature.tsv
│   ├── effect_bundles_tables/
│   │   └── !!custom_example_feature.tsv
│   └── effect_bundles_to_effects_junctions_tables/
│       └── !!custom_example_feature.tsv
├── script/campaign/mod/
│   └── custom_example_feature.lua
└── text/db/
    ├── custom_example_feature_CN.loc.tsv
    └── en/
        └── custom_example_feature_EN.loc.tsv
```

## 查原版文件流程

### 查 DB 表

1. 打开 `gamedata/db/<table_name>/`。
2. 查原版 `data__` 或其他内部表的列名、版本、数据类型。
3. 用 RPFM schema/diagnostics 验证。
4. 如果用户提供了目标 MOD 或目标 Pack，再查其中同表文件并保持同目标 MOD/目标 Pack 风格。

### 查 Lua API

1. 搜 `gamedata/documentation/script`。
2. 搜 `gamedata/script/campaign/`。
3. 若网页文档与本地文件冲突，以 `gamedata` 中的当前游戏版本文件为准。
4. 不确定时标注 `[需验证]`。

### 查本地化术语

1. 查 `bilingual/术语库.md`。
2. 未命中则在 `bilingual/EN` 单独搜英文术语。
3. 用英文条目的 key 查 `bilingual/localisation__.loc_CN.tsv`。
4. 新术语回填术语库。

## 覆盖原版脚本的风险

默认不要直接放：

```text
script/campaign/<原版脚本名>.lua
```

除非用户明确要求覆盖原版脚本。原因：

- 与其他 MOD 高冲突。
- 游戏更新后容易失效。
- 小改动也需要维护完整原版脚本上下文。

优先使用：

```text
script/campaign/mod/custom_<feature>.lua
```

配合事件监听器和 DB 表实现功能。

## 输出与测试文件

可以在 MOD 目录下保留：

```text
notes/
TESTING.md
```

但打包 Pack 前应确认这些文件不会被误导入游戏路径，或按项目习惯保留在工作目录而非 Pack 内。
