# Codex Project Context

这是一个《全面战争：战锤3》MOD 制作工作区。当前主要资产是本地 RPFM 工具和一份可维护的 `warhammer-mod-development` 指南源文件。

## 当前目录

```text
D:\modding\wh3modding\
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
```

## 关键判断

- `rpfm-v5.0.5-x86_64-pc-windows-msvc/` 是工具目录，不是待开发源码。
- `warhammer-mod-development_generic/` 是本项目维护的 development 指南源副本。
- 以后具体 MOD 打包前源文件放在 `mod_files/<MOD名>/`。
- 图片、美术源素材放在 `assets/image/`，由用户维护；Codex 默认只引用，不整理、不清理。
- 打包后的 `.pack` 输出放在 `mod_output/`，不作为源码维护。
- Steam Workshop 发布包、预览图、说明文本等放在 `workshop_release/`，其中说明文本默认使用 Steam BBCode。
- 原版导出、脚本、DB 和 UI 参考资料放在 `gamedata/`。
- 游戏内中英对照和本地化参考文件放在 `bilingual/`。
- `gamedata/`、`bilingual/` 与 RPFM 工具目录仅供读取或调用，不要修改、格式化、清理或移动其中的文件。
- 制作 MOD 时，打包前先询问用户：由用户手动用 RPFM 打包，还是由 Codex 自动调用 RPFM/脚本打包。默认不直接自动打包。

## Codex 工作方式

需要生成或修改 WH3 MOD 内容时，先阅读 `warhammer-mod-development_generic/SKILL.md`，再按任务类型读取对应 reference：

- 新增/派生兵种、坐骑、武器、兵牌、porthole：`references/unit_creation_workflow.md`
- TSV/DB：`references/tsv_format.md`、`references/naming_conventions.md`
- Lua：`references/lua_api.md`
- effect/effect bundle：`references/common_effect_keys.md`
- 目录与原版查证：`references/project_structure.md`
- RPFM、日志、网页核验：`references/rpfm_and_verification_workflow.md`

当用户反馈“这样不对”“RPFM 报错”“游戏日志报错”“以后按这个规则来”时，判断是否需要更新 development 指南。更新流程见 `docs/DEVELOPMENT_GUIDE_UPDATE_RULES.md`。
