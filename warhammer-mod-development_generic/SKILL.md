---
name: warhammer-mod-development
description: "全面战争：战锤3（Total War: WARHAMMER III）MOD 开发辅助。用于 WH3/战锤3 MOD、RPFM、Pack、DB/TSV、Loc、本地化、Lua 战役脚本、日志排查、新增/派生兵种、坐骑、武器、unit card、porthole、资源链路和 diagnostics 修复。"
---

# 战锤3 MOD 开发指南

## 入口

- 先读 `.codex/project_context.md`；涉及本机 playset、路径、Workshop、具体 MOD 或硬件时再读 `.codex/runtime_state.md`。
- 本项目可维护指南以 `warhammer-mod-development_generic/` 为准，只读取当前任务需要的 reference。
- `gamedata/`、`bilingual/` 与 RPFM 工具目录只读；源文件放 `mod_files/<MOD名>/`，产物放 `mod_output/`，发布材料放 `workshop_release/`。
- 默认用 Windows Python313 执行 `tools/build_pack.py <mod名> --deploy` 自动打包部署；仅用户明确要求时停在手工 RPFM 步骤。
- Workshop 最终文案使用 Steam BBCode；预览图源文件统一为 `preview.png`。

## Reference 路由

| 任务 | 读取 |
|---|---|
| 新增/派生兵种、坐骑、武器、弹药、兵牌、porthole | `references/unit_creation_workflow.md` |
| 新建可玩派系、独立文化、startpos、前端派系选择 | `references/project_structure.md`、`references/rpfm_and_verification_workflow.md` |
| DB/TSV、Loc TSV、表版本、列数检查 | `references/tsv_format.md` |
| 命名前缀、`data__`、文件名 | `references/naming_conventions.md` |
| Lua、监听器、First Tick、日志点 | `references/lua_api.md` |
| effect/effect bundle/scope | `references/common_effect_keys.md` |
| 工作区路径、原版 DB/脚本/本地化查证 | `references/project_structure.md` |
| key/内部路径/loc 反查（"X 定义在哪、被谁遮蔽/引用"）、行值/数值对比（"这补丁改了哪几个数"）、招募链路与派系扩充接线（unit→group→pool→faction）、表列/主键/外键查询 | `tools/wh3index.py`（find/key/path/loc/show/links/cols；索引过期先 `build`；细见 `tools/README.md`） |
| RPFM、打包、部署、依赖、diagnostics、Workshop 发布 | `references/rpfm_and_verification_workflow.md` |
| 启动崩溃、OOM、加载顺序、文件遮蔽、DB 行冲突、data pack、二分 | `references/crash_and_load_order_diagnostics.md` |
| Placeholder Body、`show_advice`/`trigger_dilemma` | `references/ui_popup_and_event_diagnostics.md` |
| RMV2、骨骼、动画预览、Skin Wrap、AssetEditor | `references/asseteditor_animation_workflow.md` |
| 外部 GLB → 自造兵种端到端管线 | `references/custom_model_unit_pipeline.md` |
| 单位/领主/英雄语音与 Wwise | `references/audio_and_vo.md` |

## 默认流程

1. 确定变更类型：DB、Loc、Lua、UI、模型、贴图、动画或音频。
2. 查原版与目标 MOD 的真实实现：`gamedata/db/`、`gamedata/script/`、`bilingual/` 及目标 pack。`gamedata/documentation/script/` 若不存在，不得假定已恢复；改用本地原版脚本与经核验的在线文档。
3. 沿用目标的表版本、列顺序、命名和资源链；新增最小必要行/文件，不复制整张原版表。
4. DB TSV 保持“列名行 → 元数据行 → 数据行”，并验证版本、列名、列数、主键和外键。
5. 打包前补齐 `notes/pack_notes.txt`、`notes/alias.txt`、`preview.png`；补丁型 MOD 还须有 `notes/dependencies.txt`，填写实际依赖 pack 文件名。
6. 运行构建、静态 diagnostics 和目标场景 MVP 验证；游戏/RPFM 更新后复查 schema、dependencies/cache 与原版结构。
7. 发布时生成同名 pack/PNG 和 BBCode 说明，明确依赖、排序、改动与兼容性。
8. 用户反馈形成可复用结论时，更新最小合适的 reference 与 `CHANGELOG.md`；单个 MOD 状态不要提升为通用规则。

## 高风险原则

- `custom_` 只用于模板；真实 MOD 使用稳定唯一短前缀。默认禁止 `data__` 整表替代。
- 本地化 key 按原版同表同字段确认；不确定的 API、scope、表版本、Loc key、UI 路径或资源链标注 `[需验证]`。
- `core:add_listener` 使用 5 参数签名；读档仍需存在的监听器必须用 `cm:add_first_tick_callback` 注册，不要只放在 `cm:add_first_tick_callback_new`。
- 修改原版对象时复制实际被读取的 key/group/junction，只改必要字段；不要直接改 donor 共用的武器、弹药、坐骑、entity、spacing、porthole 或 unit card。
- 新增单位必须补全 main/land unit、variant、entity、动画/骨架、武器/弹药、unit set、招募、Loc 与 UI 资源链；细节以 unit workflow 为准。
- 新英雄/领主复用技能树时新建 `character_skill_node_sets_tables.key`，不得复用原版 set 主键覆盖原角色。
- 加载顺序分两层：同内部路径文件级遮蔽最近实测为靠前 pack 胜出；不同片段同主键的 DB 行级冲突最近实测为靠后 pack 胜出。一个补丁同时需要两种方向时可能必须拆包，具体以诊断 reference 为准。
- 新 key 优先放唯一 DB 片段名，避免同路径片段被整文件遮蔽后产生悬空引用。
- 游戏 UI 自动化只作用于游戏窗口自身：被遮挡用 `PrintWindow`/屏幕 DC 截图、`PostMessageW` 发点击，只有游戏窗口可以 `SetForegroundWindow`；禁止 `ShowWindow(SW_HIDE)`/最小化/移走其他程序窗口或 `taskkill` 无关进程来清场（细则见 crash reference §10.41）。

## 指南维护

高层流程写本文件，详细规则写对应 `references/*.md`；规则变化更新 `CHANGELOG.md`，新增文件更新 `MANIFEST.md`。实测经验保留触发条件并标注 `[实测/需随版本复查]`。
