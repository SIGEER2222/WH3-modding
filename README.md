# WH3 Modding Workspace

这个工作区用于《全面战争：战锤3》（Total War: WARHAMMER III）的 MOD 制作、RPFM 辅助编辑，以及 Codex 开发指南维护。

它不是常规软件代码仓库。当前核心内容是：

| 路径 | 用途 |
|---|---|
| `rpfm-v5.0.5-x86_64-pc-windows-msvc/` | 本地 RPFM 工具目录，用于打开、编辑、诊断 `.pack` 文件 |
| `warhammer-mod-development_generic/` | 战锤3 MOD 开发指南 skill 的项目内源文件 |
| `mod_files/` | MOD 打包前的源文件目录 |
| `mod_output/` | 打包生成的 `.pack` 等产物 |
| `workshop_release/` | Steam Workshop 发布材料；文本描述使用 BBCode |
| `assets/image/` | 用户维护的图片、美术源素材和参考图 |
| `gamedata/` | 原版脚本、UI、DB 等查证资料；只读 |
| `bilingual/` | 中英本地化和术语参考；只读 |
| `.codex/project_context.md` | 给 Codex 的项目上下文入口 |
| `.agents/README.md` | 给其他代理/自动化的说明入口 |
| `docs/PROJECT_STRUCTURE.md` | 本工作区和未来 MOD 目录结构说明 |
| `docs/RPFM_USAGE.md` | RPFM 在本项目中的使用约定 |
| `docs/DEVELOPMENT_GUIDE_UPDATE_RULES.md` | 根据需求和错误反馈更新 development 指南的规则 |

## Codex 读取顺序

处理本项目任务时，优先按以下顺序读取：

1. `AGENTS.md`
2. `.codex/project_context.md`
3. `warhammer-mod-development_generic/SKILL.md`
4. 与任务相关的 `warhammer-mod-development_generic/references/*.md`
5. `docs/PROJECT_STRUCTURE.md`
6. `docs/DEVELOPMENT_GUIDE_UPDATE_RULES.md`

## 工作原则

- RPFM 目录是外部工具，不把它当作项目源码来重构。
- `assets/`、`bilingual/`、`gamedata/`、RPFM 工具目录、`mod_output/` 和 `workshop_release/` 默认不纳入版本管理。
- development 指南是可维护资产；当用户反馈可复用的需求、RPFM 诊断、游戏日志错误或实测结论时，应按规则更新指南。
- 真实 MOD 源文件建议放在 `mod_files/<MOD名>/` 下，内部结构遵循 `db/`、`script/campaign/mod/`、`text/db/`。
- 生成 DB/Loc/Lua 前先查原版、目标 Pack 或目标 MOD；不确定的规则标注 `[需验证]`。
- 需要打包时，先确认用户是手动用 RPFM 打包，还是由 Codex 自动打包。
- Workshop 文案最终使用 Steam BBCode，不直接把 Markdown 当作发布文本。
- 完成可测试变更前，优先使用 RPFM diagnostics 和游戏 `script_log_*.txt` 做验证。

## MOD 源文件目录

当开始制作具体 MOD 时，建议新增：

```text
mod_files/
└── <MOD名>/
    ├── db/
    ├── script/campaign/mod/
    ├── text/db/
    ├── notes/
    └── TESTING.md
```

原版数据和本地化资料使用：

```text
gamedata/
bilingual/
```

这些目录通常很大，只读参考，默认不纳入版本管理。
