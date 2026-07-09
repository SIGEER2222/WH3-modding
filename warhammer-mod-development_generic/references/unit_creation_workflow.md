# 新增/派生兵种工作流

本文件整理从原版单位、领主坐骑、武器和 UI 资源派生新兵种时的可复用经验。目标是做最小、可诊断、低冲突的 WH3 新单位 MOD。

## 适用场景

- 新增一个继承原版单位数据的新兵牌。
- 从多个 donor 组合模型、坐骑、武器、弹药、招募建筑、科技加成。
- 新建或缩放坐骑，但不影响原版同坐骑角色/兵种。
- 修正单位卡、低画质/高画质 porthole、动态头像镜头。
- 根据 RPFM diagnostics 修 invalid reference、missing loc、banned table。

## 总原则

- 不直接改 donor 原版行；复制实际被读取的行到新 key，再改最小字段。
- 不新建孤立 key 期待游戏自动继承；每条读取链都要被现有表引用。
- TSV 列名、列数、列顺序、版本必须与目标表一致。
- 同名主键行可覆盖原版数据；新单位则必须用新 `main_units`/`land_units` key 并补齐引用链。
- 共用资源需要改数值时，新建专用 key：weapon、projectile、mount、entity、spacing、unit card、porthole。
- 先让功能跑通，再逐步加资源与平衡改动；每步跑 RPFM diagnostics。

## 新单位基础链

新增一个普通变体单位时，先复制这些核心链路：

1. `main_units_tables`：战役单位、人数、招募成本、tier、UI 分组、porthole。
2. `land_units_tables`：战斗实体、坐骑、武器、弹药、属性组、AI 分类、编组。
3. `unit_attributes_groups_tables` 与 `unit_attributes_to_groups_junctions_tables`：复制原属性组，加入新增属性。
4. `variants_tables` 与 `unit_variants_tables`：战斗模型、variant、unit card。
5. `land_units_to_unit_abilites_junctions_tables`：只复制适合普通多实体单位的能力。
6. 招募/可用性：常见为 `building_units_allowed_tables`、`units_to_groupings_military_permissions_tables`、`units_custom_battle_permissions_tables`。
7. 费用/质量/AI：按 donor 实际行复制 `battle_currency_units_cost_values_tables`、`cdir_military_generator_unit_qualities_tables` 等。
8. 科技/技能加成：把新单位加入 donor 实际使用的 `unit_set_to_unit_junctions_tables` unit set，区分科技用、MP cap、单实体、领主集合。
9. Loc：至少提供 `land_units_onscreen_name_<land_unit>`；如替换描述 key，还要补 description DB 表与 Loc。

不要机械复制剧情、任务或编成表，例如 `battle_set_piece_*`、`armed_citizenry_*`、`mercenary_unit_groups`，除非用户明确要求。

## 多源拼装单位

当一个新单位同时借用 A 的外观、B 的坐骑、C 的武器、D 的招募建筑时，把来源链分开确认：

- 兵牌/模型来源不决定战斗类别。
- 坐骑来源不自动带来骑乘动画、battle personality 或 rider weapon。
- 武器来源不自动改 autonomous rider 或 battle entity stats。
- 招募来源不自动继承科技加成。
- unit set 加成不等于招募许可。

推荐为每个 donor 建一个小清单：复制哪些表、沿用哪些 key、哪些字段必须改成新 key。

## 骑乘/多实体飞行单位

多模型骑乘单位不是“单实体领主复制 20 次”这么简单：

- 若单位本质是骑龙/骑怪兽单位，`land_units_tables.category`、`class`、`ai_usage_group` 优先参考骑乘领主/怪兽，而不是因为有骑手就设成普通骑兵。
- `main_units_tables.num_men` 与 `land_units_tables.num_mounts` 要同步确认。
- `rank_depth` 与 `spacing` 共同影响队列排数；20+ 模型飞行骑兵不要直接套 4 模型巨兽 spacing。
- 原版 spacing 方向正确但间距不合适时，复制 `unit_spacings_tables` 到新 key 后微调，不改原版共用 spacing `[实测/需随版本复查]`。
- 多实体单位不应保留领主/英雄专用属性或能力，如 `encourages` 激励光环，除非设计明确需要 `[实测/需随版本复查]`。
- rider entity 与 mount entity 都要复查 `can_dismember` 等死亡/减员字段；20 模型单位需要正常减员时，专用 entity 通常应启用相关字段并实测 `[实测/需随版本复查]`。

## 坐骑缩放

只想让新单位或新角色的坐骑改变大小时：

1. 复制 `mounts_tables` 行为新 mount key。
2. 复制该 mount 引用的 `variants_tables` 行为新 variant key。
3. 让新 `land_units_tables.mount` 指向新 mount。
4. 只缩放坐骑时优先改新 variant 的 `mount_scale`，保留 `scale`；同步改 `scale` 会让骑手也缩放 `[实测/需随版本复查]`。
5. 若碰撞/受击/质量也需要跟着变，复制 mount `battle_entities_tables` 为新 entity，并让新 mount 指向它；调整 `radius`、`mass`、`height`、`size`、`combat_reaction_radius` 等后进战斗复查。

不要改原版 mount、variant 或 entity，否则所有共用该坐骑的单位/角色都可能受影响。

## 骑手动画与 battle personality

如果骑手需要用另一个角色的骑乘攻击动画：

- 查目标角色是否通过 `land_units_to_battle_personalities_junctions_tables` 绑定 `battle_personalities_tables`。
- 有 autonomous rider 链路时，通常新建 battle personality。
- 动画字段可参考目标角色；variant 可使用新骑手模型来源。
- `battle_entity_stats` 可独立指定 rider 使用的远程武器。
- `riders_attachment_point` 要参考目标坐骑/角色的挂点，进战斗确认骑手位置。
- `land_units_to_battle_personalities_junctions_tables` 不要只填 `battle_personality` 与 `land_unit` 两列；骑乘 autonomous rider 行通常还要复制 donor 的 `attach`、`riders_attachment_point`、`engine_articulation_index` 与 `jettison_rider`。这些列留空可能导致 RPFM 无法正常读取/导入该行，或导致骑手挂点失效 `[实测/需随版本复查]`。

## 单位能力与使用次数

`[已查原版 DB / 需游戏内复查]`

如果只想让新单位使用 donor 的主动技能，但要改使用次数、冷却、投射物或 UI，不要直接改 donor ability key：

1. 复制 `unit_abilities_tables` 为新 ability key；如果不制作新图标，`icon_name` 可继续指向 donor 原图标 key。
2. 复制 `unit_special_abilities_tables` 同 key 行，修改 `num_uses`、`recharge_time`、`activated_projectile` 等目标字段，并给 `unique_id` 新值。
3. 复制该 ability 实际存在的辅助链路，如 `unit_abilities_to_additional_ui_effects_juncs_tables`、`special_ability_to_invalid_usage_flags_tables`。
4. 将 `land_units_to_unit_abilites_junctions_tables.ability` 改为新 ability key。
5. 为新 ability key 补 `unit_abilities_onscreen_name_*` 与 `unit_abilities_tooltip_text_*` Loc，避免 UI 缺字。
6. 不要机械复制 `effect_bonus_value_unit_ability_junctions_tables`。例如原版龙息有 `uses_mod` 加成链路；若目标是固定每队只用 1 次，复制该 junction 可能让科技/效果重新提高次数。只有明确希望新能力继承这些加成时才复制。

## 360 度骑射

360 度射击通常不是单靠一个属性完成：

- rider/infantry `battle_entities_tables.fire_arc_close=360.0000` 是常见关键字段。
- `battle_personalities_tables.battle_entity` 要指向新 360 rider entity。
- `land_units_tables.man_entity` 也要确认没有仍指向旧 entity。
- 若单位有 `land_units_tables.mount`，专用 mount entity 的 `fire_arc_close` 也可能影响游戏内射界显示；用户实测中 rider 为 360 但 mount 仍为 120 时，UI 仍显示 120，将专用 mount entity 同步为 360 后显示变为 360 `[实测/需随版本复查]`。
- 仍不生效时，对比原版已生效骑射单位的 `turn_speed`、tracking、locomotion、`autonomous_rider_hero` 等字段。

修改只作用在新建专用 rider/mount entity，不改原版共用 entity。

## 武器、弹药与 projectile

需要调整武器数值时，不改 donor 共用 weapon/projectile：

1. 复制 `missile_weapons_tables` 为新 missile weapon key。
2. 复制 `projectiles_tables` 为新 projectile key。
3. 让新 missile weapon 的 `default_projectile` 指向新 projectile。
4. 让新单位 `land_units_tables.primary_missile_weapon` 或 rider 链路指向新 missile weapon。
5. 如果存在 `battle_entity_stats_tables.primary_missile_weapon`、`unit_missile_weapon_junctions_tables` 或 autonomous rider 链路，也要同步检查。
6. 复制 `melee_weapons_tables` 为新近战武器 key 后再改伤害，避免影响领主、怪兽或其他单位共用武器。

常见字段提醒：

- 单位弹药量通常在 `land_units_tables.primary_ammo` / `secondary_ammo`。
- `projectiles_tables.projectile_number`、`shots_per_volley`、`burst_size`、`burst_shot_delay` 属于不同层级，需按动画实测。
- 普通弓箭/骑射动画可能不明显表现 `shots_per_volley` 散布；可测试 `shots_per_volley=1` 配合提高 `projectile_number` `[实测/需随版本复查]`。
- `base_reload_time` 过低可能被 UI、战斗引擎或动画周期限制；本项目曾出现设为 2 秒但游戏显示仍接近 4 秒的情况 `[实测/需随版本复查]`。
- 制作可切换弹药时，可参考亚雷鸣炮链路：`unit_missile_weapon_junctions_tables` 给单位追加可切换 missile weapon，`missile_weapons_to_projectiles_tables` 把该 missile weapon 指向替换 projectile；若再用 `effect_bonus_value_missile_weapon_junctions_tables` 的 `enable` bonus 绑定 effect，则该切换弹药会变成科技/效果解锁。若希望自用 MOD 默认可切换，可先测试只追加 ungated junction `[已查原版 DB / 需游戏内复查]`。
- 调 projectile 弹道时先区分 `trajectory_sight`：本地 schema 说明 `muzzle_velocity` 与 `max_elevation` 在 fixed trajectory 下不使用；`fixed` 可强制高抛但弹速可能不按设定生效，`dual_low_fixed` 可能在无遮挡目标上优先走低平分支，不等于强制曲射。`gravity=-1` 是使用默认/正常重力的特殊值，不应按 `-2=两倍重力` 理解；需要额外下坠时使用正数并按游戏内轨迹复查。在同一弹速、重力和距离存在两组抛物线解时，可把 `low` / `high` 理解为取低角解/高角解；`high` 在高速重炮测试中会强制或倾向最大角/高角分支，近距离目标可能几乎垂直向上发射，但能保留更远的理论射程；需要“曲射且弹速参与”时优先测试非 fixed 的分支，并进战斗实测 `[实测/需随版本复查]`。
- 若要指定某个距离的发射角度，可用 `gravity = velocity^2 * sin(2 * angle) / range` 反推；`low` 与 `high` 都使用同一公式，只是取低角解或高角解。随后可用 `range = velocity^2 * sin(2 * angle) / gravity` 估算某个仰角对应的可解距离，用 45 度估算理论最远射程。例：1000 弹速、45 度最远 750m 时 `gravity≈1333.33`；同一重力下 88 度约对应最近 52.32m `[实测/需随版本复查]`。
- 调射程时同时检查 `effective_range`、`calibration_distance`、`expiry_range`，并保持各列原版格式。当前原版 `projectiles_tables` 中 `effective_range` 与 `expiry_range` 使用整数格式，`calibration_distance` 使用小数格式；若把整数列写成 `333.3333` 这类小数，RPFM 可能无法正常识别/导入该行 `[已查原版 DB / 需随版本复查]`。
- 建筑伤害、友军伤害、建筑倍率通常在 projectile 对应字段里，先查原版同列含义。

## 单位卡与 porthole

单位卡和 porthole 是两套东西：

- `unit_variants_tables.unit_card` 指向 `ui/units/icons/<unit_card>.png`，字段值不带 `.png`。
- Mod 管理器/启动器 thumbnail 不是单位卡资源；本地/Workshop 发布时通常使用与 `.pack` 同名、放在 pack 同目录的 `.png`，并保持小于 1MB。发布缩略图优先做成正方形，常见尺寸为 `256x256`。源目录可额外保留 `thumbnail.png` 作为可维护副本，但不需要作为 DB/UI 资源导入 pack `[已查外部资料 / 需随版本复查]`。
- 本项目核对的阿瓦隆姐妹与耀星龙原版单位卡是 `60x130` PNG；新单位独立兵牌应按该尺寸生成并放入 `ui/units/icons/` `[已查原版文件/需随版本复查]`。
- 低画质静态 porthole 通常读取 `ui/units/minspec_portholes/<main_units.unit>.png` 及 mask；缺失时可能显示上一个选择单位的残留头像 `[实测/需随版本复查]`。
- 高画质动态 porthole 会实时捕捉单位/实体。多实体骑乘单位若只想显示骑手/步兵，通常需要 `main_units_tables.porthole_composite_scene` 指向专用 `.csc`。
- 制作专用 `.csc` 时，优先找原版单实体 humanoid porthole 模板；避免直接复用带坐骑、多人或多余发丝/道具节点的场景。
- 二进制替换 `.csc` 内嵌路径时必须同步字符串长度字段，并抽取字符串核对引用。
- 未修改的原版动画、模型、材质可直接引用，不必重复打包。
- 若动态 porthole 排除坐骑后出现“头不动身子晃”，优先怀疑模板内置 camera/target 轨道锁在头部；本项目实测改用带固定 `[Camera]` 的模板，并把多余可见模型节点替换成 `dummy_mesh`，可解决该问题 `[实测/需随版本复查]`。

## 精英部队 / RoR 招募池

制作“精英部队”“RoR”“限 1 队招募”的派生单位时，不要只在 `main_units_tables.campaign_cap` 写 1。应参考同派系原版 RoR 与普通单位的差异，补齐精英招募池链路：

- `main_units_tables`：通常设置 `campaign_cap=1`、`is_renown=true`、`restrict_xp_gain_in_campaign=true`、`multiplayer_cap=1`、`multiplayer_qb_cap=1`，并按 RoR 习惯调整 `create_time`、费用、CP 和 UI 分组 `[已查原版 DB / 需游戏内复查]`。
- 不给精英版新增 `building_units_allowed_tables` 行，除非设计目标就是建筑招募；否则会同时出现在建筑和精英招募界面。
- `mercenary_unit_groups_tables` 与 `mercenary_pool_to_groups_junctions_tables` 是常见 RoR 招募入口；高等精灵 RoR 示例使用 `wh2_main_hef_units_of_renown_pool`，并通过 `subculture_requirement=wh2_main_sc_hef_high_elves` 接入高精子文化 `[已查原版 DB / 需随版本复查]`。
- 如果 DB 三件套都存在但战役精英招募界面仍不显示，尤其是已有存档或 MOD 追加自建 RoR group 时，可用战役 Lua 在 first tick 调用 `cm:add_unit_to_faction_mercenary_pool(faction, unit_key, "renown", count, replenishment_chance, max_units, max_per_turn, faction_restriction, subculture_restriction, tech_restriction, partial_replenishment, mercenary_unit_group)` 主动注入 faction mercenary pool。官方脚本文档说明 `add_unit_to_faction_mercenary_pool` 可把指定 unit 加入 faction pool，而 `add_units_to_faction_mercenary_pool` 要求该 unit 类型已在池中存在 `[已查本地官方脚本文档 / 需游戏内复查]`。
- `campaign_mercenary_unit_character_level_restrictions_tables` 控制战役招募等级门槛；不要凭空猜等级，优先复制目标参照 RoR 的实际行再按设计改动。
- 如果 RoR 能在部队浏览器看到但战役精英招募界面找不到，优先检查 `campaign_mercenary_unit_character_level_restrictions_tables.character_level` 是否高于当前领主等级；测试用或设计为开局可见时可设为 `0` `[实测/需随版本复查]`。
- `unit_sets_tables` 可为该 RoR 自身建立同名 unit set；`unit_set_to_unit_junctions_tables` 应保留普通版的科技/单位组归属，并把普通 rank set 替换或补充为 RoR 版本，例如 `*_rank7_ror`、`wh2_main_ror_units_all`、`wh3_dlc27_*_ror`。
- `units_to_exclusive_faction_permissions_tables`、`units_to_groupings_military_permissions_tables`、`units_custom_battle_permissions_tables` 是否需要复制，应按同派系 RoR donor 的实际权限链路确认；若原 RoR 池后续版本新增了可玩派系，如高精 `wh3_dlc27_hef_aislinn`，自建 RoR 的 exclusive faction 白名单也要同步补齐，否则该派系可能看不到单位。
- 精英版如果要改变外观或 rider 远程武器，仍需独立 `unit_variants_tables`、`battle_personalities_tables`、`battle_entity_stats_tables`、`missile_weapons_tables`、`projectiles_tables` key；不要让普通版和精英版共用会被改数值的 weapon/projectile/ability。
- 新建 RoR ability 时，Loc 也要按新 ability key 补齐 `unit_abilities_onscreen_name_*` 与 `unit_abilities_tooltip_text_*`，否则战斗中技能名和简介会显示问号。

## Loc 与描述

Loc key 不要套单一模板：

- `land_units_onscreen_name_<land_unit>` 是单位名称常见 key，但仍应查同类原版。
- `land_units_tables.historical_description_text` 与 `short_description_text` 不是单纯 Loc 占位；还要在 `unit_description_historical_texts_tables` / `unit_description_short_texts_tables` 中存在对应 key。
- 新描述必须同时新增 description DB 行和 Loc 文本。
- 同一个 Pack 内 Loc key 必须唯一；不要同时放中英两套相同 key 的 Loc TSV。
- 面向多语言发布时，优先把英文或目标默认语言做成完整主 MOD，再把中文等其他语言做成只含 `text/db` Loc 的轻量补丁；汉化补丁需要在 Total War 启动器/Mod 管理器中排在主 MOD 前面加载，才能覆盖主 MOD 中相同 key 的文本 `[已查 CA 社区 Mod Manager 手动排序说明 / 实测需随版本复查]`。
- Loc TSV 也需要元数据行：`#Loc;1;text/db/<file>.loc`，并保持 `key	text	tooltip` 三列。
- 写入中文或其他非 ASCII Loc 后必须回读文件，确认目标文本没有被替换为字面量 `?`、`????` 或乱码。若游戏内名称/简介显示问号，但 RPFM 没报 missing loc，优先直接检查 MOD Loc TSV 中对应 key 的文本内容是否已经损坏 `[实测/需随版本复查]`。

## RPFM diagnostics 常见修正

- `banned table`：优先删除对应 MOD 表文件，不要尝试改列或改 key。新增单位变体时已知 `allied_recruitment_core_units_tables` 与 `main_unit_ownership_content_pack_junctions_tables` 会被 RPFM 标为 banned table `[实测/需随版本复查]`。
- `units_custom_battle_permissions_tables.set_piece_character` 不是普通 `main_units.unit` 外键，而是引用 `battle_set_piece_armies_characters_tables.character_name`；复制自定义战斗权限时不要机械替换该列为新单位 key。
- invalid reference：查该列真实外键来源，补对应表行或恢复 donor 有效 key。
- missing loc：先确认 DB localised 字段实际引用的 key，再按同表同字段原版前缀补 Loc。
- duplicated loc key：同 Pack 只保留目标语言的一套 Loc，或拆分语言变体 Pack。

## 最小验证清单

- [ ] 每个 TSV 都是列名行、元数据行、数据行。
- [ ] 每行列数一致，表版本来自原版/RPFM/目标 MOD。
- [ ] 新 key 有稳定前缀，无无命名空间主键。
- [ ] 没有默认使用 `data__`。
- [ ] donor 共用 weapon/projectile/mount/entity/spacing 未被直接修改。
- [ ] 新单位 `main_units`、`land_units`、variant、attribute、ability、recruitment、unit set、Loc 链路完整。
- [ ] RPFM diagnostics 无 banned table、invalid reference、missing loc。
- [ ] 游戏内验证招募、单位卡、porthole、模型、骑手位置、动画、射界、移动射击、减员、阵型、武器数值。

## 2026-07-10 弹药切换解锁实测补充

- `[实测/需随版本复查]` 可切换弹药不一定只靠 `unit_missile_weapon_junctions_tables` + `missile_weapons_to_projectiles_tables` 就显示按钮；如果 donor 的切换弹药由科技/效果解锁，未激活 enable 效果时战役战斗 UI 可能没有切换键。
- 参考亚雷鸣炮、震旦巨炮霰弹等链路时，若存在 `effect_bonus_value_missile_weapon_junctions_tables` 的 `bonus_value_id=enable` 行，应同步给新 `unit_missile_weapon_junctions` 建立专用 enable effect，并保证该 effect 在目标上下文生效。
- 自用战役 MOD 想让单位开局自带切换弹药时，可创建隐藏 `effect_bundles_tables` bundle，将自定义 enable effect 以 donor 相同 force scope 挂入 `effect_bundles_to_effects_junctions_tables`，再用 `script/campaign/mod/*.lua` 在 first tick 给相关 faction 永久施加。自定义战斗是否显示仍需游戏内单独复查。

## 2026-07-10 火炮 articulated entity 实测补充

- `[实测/需随版本复查]` 轮式火炮/车体类单位若 `land_units_tables.articulated_record` 指向 `land_unit_articulated_vehicles_tables`，移动速度和射界可能还会读取该 articulated record 引用的 `battle_entities_tables.articulated_entity`，不只读取 `land_units.man_entity` 或 `battlefield_engines.battle_entity`。
- 覆盖或派生火炮时，如果修改 `battle_entities_tables.walk_speed/run_speed/charge_speed/fire_arc_close` 没有生效，应检查并复制：`land_unit_articulated_vehicles_tables`、`articulation_nodes_in_land_articulated_vehicles_tables`，并让 `land_units_tables.articulated_record` 指向新的 articulated record。
- 若火炮 `land_units_tables.mount` 仍指向原版 draught mount，移动速度还可能被 `mounts_tables.entity` 对应的牵引实体限制；需要同步复制 `mounts_tables` 与该 mount entity 的 `battle_entities_tables` 行，再让 `land_units_tables.mount` 指向新 mount。
- 火炮直控/特殊瞄准还可同步检查 `first_person_engines_tables`；若派生了新的 `battlefield_engines_tables.key`，可复制原火炮同 key 的 first-person row 到新 engine key，并按设计调整 `half_horizontal_fire_arc`。
