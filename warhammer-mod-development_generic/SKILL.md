---
name: warhammer-mod-development
description: "全面战争：战锤3（Total War: WARHAMMER III）MOD 开发辅助。用于 WH3/战锤3 MOD、RPFM、Pack、DB/TSV、Loc、本地化、Lua 战役脚本、日志排查、新增/派生兵种、坐骑、武器、unit card、porthole、资源链路和 diagnostics 修复。"
---

# 战锤3 MOD 开发指南

## 入口规则

- 处理本项目任务时，先读 `.codex/project_context.md`；本工作区的可维护源副本以 `warhammer-mod-development_generic/` 为准。
- `gamedata/`、`bilingual/` 与 RPFM 工具目录只读使用；不修改、不格式化、不清理、不移动。
- 具体 MOD 源文件默认维护在 `mod_files/<MOD名>/`；图片素材在 `assets/image/`，由用户维护；`.pack` 输出在 `mod_output/`；Workshop 发布文件在 `workshop_release/`。
- 需要打包时默认由 Codex 用  自动完成打包、部署 data 目录、写入 playset（备份 state.db），不询问；仅当用户明确说要自己用 RPFM 打包时才停在源文件。
- Workshop 文本描述使用 Steam BBCode 作为最终发布格式；发布包应写清依赖、加载顺序、改动内容和兼容性，缩略图优先复用 MOD 源目录中已确认的 `thumbnail.png` 或用户提供图片。

## Reference 路由

只加载当前任务需要的 reference：

| 任务 | 读取 |
|---|---|
| 新增/派生兵种、坐骑、武器、弹药、兵牌、porthole | `references/unit_creation_workflow.md` |
| 新建可玩派系、独立文化、startpos、前端派系选择 | `references/project_structure.md`、`references/rpfm_and_verification_workflow.md` |
| DB/TSV、Loc TSV、表版本、列数检查 | `references/tsv_format.md` |
| 命名前缀、`data__`、加载排序、文件名 | `references/naming_conventions.md` |
| Lua、监听器、First Tick、日志点 | `references/lua_api.md` |
| effect/effect bundle/scope | `references/common_effect_keys.md` |
| 工作区路径、原版 DB/脚本/本地化查证 | `references/project_structure.md` |
| RPFM、打包、diagnostics、日志、Workshop 发布 | `references/rpfm_and_verification_workflow.md` |
| 启动崩溃、Bad Mods 对话框、加载顺序/同名片段遮蔽、data pack 启用、排错二分 | `references/crash_and_load_order_diagnostics.md` |
| 战役内 "Placeholder Body" 卡死弹窗、`show_advice`/`trigger_dilemma` 缺记录 | `references/ui_popup_and_event_diagnostics.md` |
| 模型/动画预览、RMV2 骨骼绑定诊断、Skin Wrap 重绑定、AssetEditor 自动化 | `references/asseteditor_animation_workflow.md` |
| 外部 GLB 模型 → 自造兵种端到端管线（绑骨/RMV2/DB/数值对标/验收） | `references/custom_model_unit_pipeline.md` |
| 单位/领主/英雄语音（VO）接入、自定义 `.bnk`/`.wem`、Dialogue_Event、`vo_actor`/`vo_culture`/`vo_sel` | `references/audio_and_vo.md` |

## 默认流程

1. 明确修改类型：DB、Loc、Lua、UI、模型/贴图/动画资源。
2. 先查原版：`gamedata/db/`、`gamedata/script/`、`gamedata/documentation/script/`、`bilingual/EN`、`bilingual/localisation__.loc_CN.tsv`。
3. 若用户给出目标 Pack/MOD，沿用它的目录、命名、表版本、列顺序和 Loc 格式。
4. 做最小变更：新增或覆盖必要行和资源，不复制整张原版表。
5. TSV 保持“列名行 -> 元数据行 -> 数据行”，并匹配目标表版本、列名、列数和列顺序。
6. 用 RPFM diagnostics 排查 invalid reference、missing loc、schema、banned table、datacore 等问题。
7. 进游戏验证 UI、数值、动画、模型、射界、porthole、日志。
8. 游戏或 RPFM 更新后，先复查 RPFM schema、WH3 dependencies/cache 与原版表结构，再判断 MOD 是否需要兼容性更新。
9. 生成 Workshop 发布材料时，在 `workshop_release/` 准备 `.pack`、同名 `.png`、`description.bbcode.txt`、必要的发布说明和上传清单；生成物默认不纳入 git。
10. 用户反馈可复用错误、diagnostics、发布流程或实测结果时，同步更新本指南和 `CHANGELOG.md`。

## 高风险禁区

- `custom_` 只是模板前缀；真实 MOD 使用稳定、唯一的短前缀。
- 默认不要用 `data__` 作为 MOD 表文件名；只有明确整表替代时才标注 `[高风险整表替代]`。
- 修改原版对象时，复制原版实际被读取的 key/group/junction 行，只改必要字段；不要新建孤立 key 期待游戏自动读取。
- 新增单位不会自动继承整条数据链；`main_units`、`land_units`、variant、entity、mount、weapon、projectile、unit set、招募、Loc 等链路要逐项处理。
- 不直接改 donor 单位共用的武器、弹药、坐骑、entity、spacing、porthole 或 unit card；需要改数值时新建专用 key。
- 本地化 key 必须按原版同表同字段确认；不要套单一模板。
- Lua 监听器必须使用 `core:add_listener` 5 参数签名；读档也需要的监听器放 `cm:add_first_tick_callback`。
- 不确定的 API、scope、表版本、Loc key、UI 路径或资源链路标注 `[需验证]`。
- 新建英雄/领主复用他人技能树时，`character_skill_node_sets_tables` 的 `key` 是主键；**不要**直接复用原版 set key，否则会在 DB 合并时覆盖原版角色的技能树。应新建 set key，并复制对应 `character_skill_node_set_items_tables` 行。
- 同名 `db/<表>/<内部名>` 片段跨 pack 只做文件级去重、不逐行合并；实测加载顺序靠前 pack 胜出。给主 MOD 做补丁时，新增 key 优先放唯一片段名，避免被基础包同名片段遮蔽产生悬空引用（详见 `references/crash_and_load_order_diagnostics.md`）。

## 新增兵种提醒

新增兵种先读 `references/unit_creation_workflow.md`。尤其注意：

- `unit_variants_tables.unit_card` 指向 `ui/units/icons/<unit_card>.png`，字段值不带扩展名。
- 低画质 porthole 通常需要 `ui/units/minspec_portholes/<main_units.unit>.png` 和 mask。
- 高画质 porthole 若要排除坐骑或多实体，通常要专用 `.csc`。
- 360 度骑射同时核对 rider entity、battle personality、`land_units_tables.man_entity`；有坐骑时还要核对专用 mount entity 的 `fire_arc_close`。
- 多模型骑乘单位要复查 `num_men`、`num_mounts`、`rank_depth`、`spacing`、`can_dismember`、碰撞和质量。
- 可切换弹药若原版 donor 由科技/效果解锁，不要只加 `unit_missile_weapon_junctions`；还要查 `effect_bonus_value_missile_weapon_junctions_tables.enable`，并保证 enable effect 在战役或目标上下文中生效。
- 轮式火炮/车体单位的速度和射界不一定只读炮身 entity；同时核对 `articulated_record`、`land_unit_articulated_vehicles_tables`、articulated entity、牵引 `mount`/mount entity，以及必要时的 `first_person_engines_tables`。

## 指南维护

可复用规则写入最小合适位置：高层流程写 `SKILL.md`，详细规则写对应 `references/*.md`。每次规则变化都更新 `CHANGELOG.md`；新增文件时更新 `MANIFEST.md`。实测经验保留触发条件并标注 `[实测/需随版本复查]`。
