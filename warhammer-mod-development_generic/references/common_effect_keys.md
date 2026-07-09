# 常用 Effect Key 参考（通用版）

## 使用原则

本文件只是常用 effect key 的起点，不是绝对真理。

生成 DB 或 Lua 前必须：

1. 在原版 `effect_bundles_to_effects_junctions_tables` 搜索该 effect key。
2. 查看原版使用过哪些 `effect_scope`、`value` 正负和 `advancement_stage`。
3. 查看 `effects_tables` 中 `is_positive_value_good`。
4. 若要显示在 UI，查原版 Loc key 前缀。
5. 用 RPFM diagnostics 检查引用。

## 经济/发展类

| Effect Key | 用途 | is_positive_value_good | 常见 scope（需查原版确认） | 备注 |
|---|---|---:|---|---|
| `wh_main_effect_economy_gdp_mod_all` | 所有收入修正 | true | `faction_to_faction_own_unseen` | 收入 +30% 通常 value = `30` |
| `wh_main_effect_technology_research_points` | 科研速率 | true | `faction_to_faction_own_unseen` | 科研 +10% value = `10` |
| `wh3_main_effect_province_growth_faction` | 行省发展度/增长 | true | `faction_to_province_own_unseen` | 查原版同类 bundle |

## 费用/时间类

| Effect Key | 用途 | is_positive_value_good | 常见 scope（需查原版确认） | 备注 |
|---|---|---:|---|---|
| `wh_main_effect_force_all_campaign_upkeep` | 部队维持费 | false | `faction_to_force_own_unseen` | 减少 30% 通常 value = `-30` |
| `wh_main_effect_force_all_campaign_recruitment_cost_all` | 招募费用 | false | `faction_to_faction_own_unseen` | 减少费用用负值 |
| `wh3_main_effect_building_construction_time_add_mod_all` | 建筑时间修正 | false | `faction_to_region_own_unseen` | 减少时间用负值；查原版 scope |

### 限定具体单位的维持费

`wh_main_effect_force_all_campaign_upkeep` 在原版 `effect_bonus_value_ids_unit_sets_tables` 中绑定 `all_units`；直接复用通常会影响全体部队。若目标是“只让某几个新单位维护费 -20%”，应新建专用 effect 并绑定专用 unit set `[已查原版 DB / 需游戏内复查]`：

1. `unit_sets_tables` 新建一个只服务此效果的 unit set。
2. `unit_set_to_unit_junctions_tables` 把目标 `main_units.unit` 加入该 unit set。
3. `effects_tables` 新建专用 effect key，复制同类 upkeep effect 的 icon/category/is_positive_value_good。
4. `effect_bonus_value_ids_unit_sets_tables` 使用 `bonus_value_id=upkeep_mod`，把新 effect 绑定到专用 unit set。
5. `effect_bundles_tables` + `effect_bundles_to_effects_junctions_tables` 把新 effect 放进 bundle；减少维护费用通常写负值，例如 `-20.0000`。
6. 需要 UI 显示时补 `effects_description_<effect_key>` 与 `effect_bundles_localised_title/description_<bundle_key>` Loc。

常见 `effect_scope` 可先参考原版农民经济等单位集合维护费效果使用的 `faction_to_force_own`，但仍需按目标 bundle 类型查原版同类用法。

## 前端/派系效果显示

战役 Lua `cm:apply_effect_bundle` 能让效果生效，但不会让主菜单选领主界面的派系效果说明提前出现；如果还需要前端和战役派系效果文本显示，应把可见 effect 放进该传奇领主或派系实际使用的 DB bundle，例如 `faction_starting_general_effects_tables.agent_subtype -> effect_bundle` 指向的 `lord_trait_*` bundle `[实测/需随版本复查]`。

注意：

- 不要同时让 Lua 独立 bundle 和起始 trait bundle 都包含同一条实际数值效果，否则可能叠加生效。
- 需要显示的效果不要使用 `_unseen` scope；参考同类原版 lord trait 中可见效果的 `faction_to_force_own` 等 scope。
- 如果只是补前端文本而实际效果仍由 Lua 处理，可考虑 dummy effect，但要明确它只是 UI 文本，不承担数值逻辑。

## 建筑/招募类

| Effect Key | 用途 | is_positive_value_good | 常见 scope（需查原版确认） | 备注 |
|---|---|---:|---|---|
| `wh_main_effect_unit_recruitment_points` | 本地招募容量 | true | `faction_to_province_own_unseen` | 查本地/行省作用域 |
| `wh_main_effect_force_all_recruitment_points` | 部队招募点数/全局或游牧相关 | true | `faction_to_faction_own_unseen` | 查具体用法 |

## 军事/战斗类

| Effect Key | 用途 | is_positive_value_good | 常见 scope（需查原版确认） | 备注 |
|---|---|---:|---|---|
| `wh_main_effect_force_army_campaign_attrition_all_resistance` | 损耗抗性 | false | `faction_to_force_own_unseen` | 注意 false：更好可能是负值 |
| `wh_main_effect_force_army_campaign_attrition_all_immunity` | 损耗免疫 | true | `faction_to_force_own_unseen` | 通常是布尔/百分比类效果，查原版 |
| `wh_main_effect_force_all_campaign_replenishment_rate` | 补员速率 | true | `faction_to_force_own_unseen` | 正值有益 |
| `wh_main_effect_force_all_campaign_movement_range` | 移动范围 | true | `faction_to_force_own_unseen` | 正值有益 |

## 外交类

| Effect Key | 用途 | 常用 type/scope | 备注 |
|---|---|---|---|
| `wh_main_faction_political_diplomacy_mod` | 外交态度修正 | `diplomatic_mod` / `faction_to_faction_own_unseen` | 常需 `effect_bonus_value_faction_junctions_tables` 绑定目标派系 |

外交类效果常见链路：

1. `effects_tables` 注册/引用 effect key。
2. `effect_bonus_value_faction_junctions_tables` 绑定目标派系或 bonus value。
3. bundle/junction 或 Lua 动态 bundle 中传入数值。
4. 进游戏外交界面验证实际显示和生效。

## 自定义 Effect Key

自定义 key 不等于自定义逻辑。只有满足以下至少一项才更可能有效：

- 原版脚本/DB 已有相同逻辑读取该 effect。
- 该 effect 属于引擎内置 bonus value 系统，且在 `effects_tables`/bonus value 表里正确配置。
- 已经通过游戏实测验证。

否则标注：`[需验证：纯自定义 effect key 可能无效]`。

## 数值正负规则

`is_positive_value_good` 表示 UI/逻辑方向，不代表所有效果都能机械套用。

| is_positive_value_good | 常见含义 | 示例 |
|---|---|---|
| `true` | 正值通常有益 | 收入 +30% → `30` |
| `false` | 负值通常有益 | 维持费 -30% → `-30` |

常见例子：

```text
减少维持费 30% → value = -30.0000
增加收入 30%   → value = 30.0000
减少建筑时间 1 回合 → value = -1.0000 或 -1，按原版同列格式
```

## advancement_stage

`effect_bundles_to_effects_junctions_tables` 常见列：

```tsv
effect_bundle_key	effect_key	effect_scope	value	advancement_stage
```

`advancement_stage` 不要随意留空。查原版同类 bundle，常见值如：

```text
start_turn_completed
```

是否可以为空、应填什么，以原版同类效果为准。

## Scope 验证流程

示例：要使用 `wh_main_effect_economy_gdp_mod_all`：

1. 在原版 `db/effect_bundles_to_effects_junctions_tables/` 搜该 key。
2. 记录所有出现过的 `effect_scope`。
3. 找与你目标最接近的原版 bundle：派系全局、建筑、角色、部队、行省、地区。
4. 复制同类 scope，而不是凭名字猜。
5. 用 RPFM diagnostics 检查。
6. 游戏中检查 UI 和实际数值。

## 生成 Effect Bundle 的最小示例

```tsv
# effect_bundles_tables
key	localised_description	localised_title	bundle_target	priority	ui_icon	is_global_effect	show_in_3d_space	owner_only
#effect_bundles_tables;4;db/effect_bundles_tables/!!custom_example_bundle
custom_example_income_bundle	[hidden]	[hidden]	faction	1		false	false	true
```

```tsv
# effect_bundles_to_effects_junctions_tables
effect_bundle_key	effect_key	effect_scope	value	advancement_stage
#effect_bundles_to_effects_junctions_tables;3;db/effect_bundles_to_effects_junctions_tables/!!custom_example_bundle
custom_example_income_bundle	wh_main_effect_economy_gdp_mod_all	faction_to_faction_own_unseen	10.0000	start_turn_completed
```

使用前仍必须查原版确认 scope 和版本。
