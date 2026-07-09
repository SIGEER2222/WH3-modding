# 项目结构

本文件说明 `D:\modding\wh3modding` 的目录职责，以及制作具体 WH3 MOD 时推荐使用的源文件、打包输出和 Workshop 发布结构。

## 当前结构

```text
wh3modding/
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
├── gamedata/
├── bilingual/
├── rpfm-v5.0.5-x86_64-pc-windows-msvc/
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
| `gamedata/` | 提取的游戏原版脚本、UI、DB 等数据；只读参考 | 忽略 |
| `bilingual/` | 游戏内中英对照和本地化参考文件；只读参考 | 忽略 |
| `rpfm-v5.0.5-x86_64-pc-windows-msvc/` | RPFM 工具本体 | 忽略 |
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
    ├── preview.png
    └── release_notes.bbcode.txt
```

Steam Workshop 文本描述使用 Steam BBCode。Markdown 可以作为草稿，但最终发布文本应转换为 BBCode。

## 文件归属规则

- 工具文件归属 RPFM 目录，不参与 MOD 逻辑维护。
- 通用经验归属 `warhammer-mod-development_generic/`。
- 项目级说明归属 `docs/` 与 `AGENTS.md`。
- 原版数据与中英本地化参考归属 `gamedata/`、`bilingual/`，只读使用。
- 具体 MOD 源文件归属 `mod_files/<MOD名>/`。
- 具体 MOD 设计、测试、故障记录归属 `mod_files/<MOD名>/notes/` 或该 MOD 自己的文档。
- 可复用且已验证的经验，再按 `docs/DEVELOPMENT_GUIDE_UPDATE_RULES.md` 提升到 development 指南。
