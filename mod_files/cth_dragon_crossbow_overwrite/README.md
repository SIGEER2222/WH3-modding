# cth_dragon_crossbow_overwrite

覆盖原版震旦天廷龙弩手：

- 目标单位：`wh3_main_cth_inf_dragon_guard_crossbowmen_0`
- 武器母本：桂阴御赐军 `wh3_dlc24_cth_inf_dragon_guard_crossbowmen_ror`
- 新近战武器：`cthdco_cth_dragon_crossbow_ror_melee_x2`，普通伤害为桂阴御赐军近战武器的 2 倍，破甲伤害在 2 倍后再 +35。
- 新远程武器：`cthdco_cth_dragon_crossbow_ror_bolt_x3`，弹药为桂阴御赐军弩矢的 3 倍伤害、2 倍射程，破甲伤害在 3 倍后再 +35。
- 兵模 120，招募费 400，维持费 100，招募回合 1，近战/远程自动分 1500/1500。
- 近战攻防按原版天廷龙弩手 +45，冲锋 45，护甲 `wh2_main_chainmail_110`，保留盾牌。
- 生命值按原版 1.5 倍处理：`land_units_tables.bonus_hit_points` 与专用实体 `hit_points` 都同步提高。
- 新专用实体 `cthdco_cth_dragon_guard_crossbow_fast_180`：行走/奔跑/冲锋速度翻倍，加速度不变，射击角 180。
- 添加先锋部署、永不战败、重生、抵御冲锋，`damage_mod_all=30`，`healing_power=4.0000`。
- 追加役农长柄矛手的全部招募建筑许可给原版天廷龙弩手。

生成源文件：

- `db/land_units_tables/!!cthdco_dragon_crossbow_overwrite.tsv`
- `db/main_units_tables/!!cthdco_dragon_crossbow_overwrite.tsv`
- `db/melee_weapons_tables/!!cthdco_dragon_crossbow_overwrite.tsv`
- `db/missile_weapons_tables/!!cthdco_dragon_crossbow_overwrite.tsv`
- `db/projectiles_tables/!!cthdco_dragon_crossbow_overwrite.tsv`
- `db/battle_entities_tables/!!cthdco_dragon_crossbow_overwrite.tsv`
- `db/unit_attributes_to_groups_junctions_tables/!!cthdco_dragon_crossbow_overwrite.tsv`
- `db/land_units_to_unit_abilites_junctions_tables/!!cthdco_dragon_crossbow_overwrite.tsv`
- `db/building_units_allowed_tables/!!cthdco_dragon_crossbow_overwrite.tsv`
- `db/ui_unit_bullet_point_unit_overrides_tables/!!cthdco_dragon_crossbow_overwrite.tsv`

输出 pack：

- `mod_output/cth_dragon_crossbow_overwrite.pack`

说明：普通 DB 追加不会删除原版已有的天廷龙弩手招募许可；本 MOD 让它获得役农长柄矛手同款建筑许可，因此在常规震旦建筑链中与役农长柄矛手一致，同时原版已有许可若仍被游戏读取也会保留。
