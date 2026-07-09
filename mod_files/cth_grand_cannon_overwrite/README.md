# cth_grand_cannon_overwrite

覆盖原版震旦巨炮：

- 目标单位：`wh3_main_cth_art_grand_cannon_0`
- 炮弹弹道：`high` 高角分支测试版，弹速 1000，45 度计算最远约 750m；反推 `gravity=1333.3333`，88 度计算最近约 52.32m（表内取 `minimum_range=53`），`effective_range=750`，`max_elevation=88`。
- 巨炮门数：`land_units_tables.num_engines` 4 -> 8；炮组人数 `main_units_tables.num_men` 44 -> 88。
- 生命值翻倍：炮组实体与火炮实体都使用专用 key 并把 `hit_points` 翻倍；`bonus_hit_points` 同步 48 -> 96。
- 护甲使用当前原版最高护甲 key：`wh2_main_heavy_metal_160`。
- 移动速度翻倍：炮组和火炮实体的 `walk_speed`、`run_speed`、`charge_speed` 翻倍；`acceleration` 保持原值。
- 近战攻防按原版巨炮 +50，冲锋加成 25。
- 新近战武器 `cthgco_cth_grand_cannon_melee_ap60`：破甲杀伤 +60。
- 新远程武器 `cthgco_cth_grand_cannon_high_1000_750`：保留原版巨炮弹药表现，远程伤害 x2，炮弹飞行速度固定为 1000，装填时间固定为 6，弹药 x5；弹道为非 fixed 的 `high` 分支，`minimum_range=53`、`effective_range=750`。
- 追加可切换爆破弹药 `cthgco_cth_grand_cannon_high_1000_750_explosive`：参考亚雷鸣炮的 `unit_missile_weapon_junctions_tables` + `missile_weapons_to_projectiles_tables` 链路，直伤按亚雷鸣炮爆破弹比例降为普通弹 50%（`88/352`），并添加半径 7 的范围爆炸（`detonation_damage=50.0000`、`detonation_damage_ap=76.0000`）。
- 巨炮炮组与炮身专用实体 `fire_arc_close` 改为 180 度。
- 添加抵御冲锋、先锋部署、永不战败、再生，`damage_mod_all=50`，`healing_power=4.0000`。
- 近战/远程自动分为 1000/2000，招募回合 1。
- 追加役农长柄矛手的全部招募建筑许可给原版巨炮。

生成源文件：

- `db/land_units_tables/!!cthgco_grand_cannon_overwrite.tsv`
- `db/main_units_tables/!!cthgco_grand_cannon_overwrite.tsv`
- `db/melee_weapons_tables/!!cthgco_grand_cannon_overwrite.tsv`
- `db/missile_weapons_tables/!!cthgco_grand_cannon_overwrite.tsv`
- `db/projectiles_tables/!!cthgco_grand_cannon_overwrite.tsv`
- `db/projectiles_explosions_tables/!!cthgco_grand_cannon_overwrite.tsv`
- `db/missile_weapons_to_projectiles_tables/!!cthgco_grand_cannon_overwrite.tsv`
- `db/unit_missile_weapon_junctions_tables/!!cthgco_grand_cannon_overwrite.tsv`
- `db/effects_tables/!!cthgco_grand_cannon_overwrite.tsv`
- `db/effect_bonus_value_missile_weapon_junctions_tables/!!cthgco_grand_cannon_overwrite.tsv`
- `db/effect_bundles_tables/!!cthgco_grand_cannon_overwrite.tsv`
- `db/effect_bundles_to_effects_junctions_tables/!!cthgco_grand_cannon_overwrite.tsv`
- `db/mounts_tables/!!cthgco_grand_cannon_overwrite.tsv`
- `db/battle_entities_tables/!!cthgco_grand_cannon_overwrite.tsv`
- `db/battlefield_engines_tables/!!cthgco_grand_cannon_overwrite.tsv`
- `db/land_unit_articulated_vehicles_tables/!!cthgco_grand_cannon_overwrite.tsv`
- `db/articulation_nodes_in_land_articulated_vehicles_tables/!!cthgco_grand_cannon_overwrite.tsv`
- `db/first_person_engines_tables/!!cthgco_grand_cannon_overwrite.tsv`
- `db/unit_attributes_to_groups_junctions_tables/!!cthgco_grand_cannon_overwrite.tsv`
- `db/land_units_to_unit_abilites_junctions_tables/!!cthgco_grand_cannon_overwrite.tsv`
- `db/building_units_allowed_tables/!!cthgco_grand_cannon_overwrite.tsv`
- `db/ui_unit_bullet_point_unit_overrides_tables/!!cthgco_grand_cannon_overwrite.tsv`
- `script/campaign/mod/cthgco_grand_cannon_ammo.lua`

输出 pack：

- `mod_output/cth_grand_cannon_overwrite.pack`

说明：普通 DB 追加不会删除原版已有的巨炮招募许可；本 MOD 让它额外获得役农长柄矛手同款建筑许可，因此在常规震旦建筑链中与役农长柄矛手一致，同时原版已有许可若仍被游戏读取也会保留。
