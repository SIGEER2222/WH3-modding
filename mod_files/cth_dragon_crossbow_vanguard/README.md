# cth_dragon_crossbow_vanguard

新增一个震旦单位：天廷龙弩手（先锋部署）。

## 修改范围

- 原版单位：`wh3_main_cth_inf_dragon_guard_crossbowmen_0`
- 新单位：`cthdcv_cth_inf_dragon_guard_crossbowmen_vanguard`
- 中文显示名：`天廷龙弩手（先锋部署）`
- 英文显示名：`Celestial Dragon Crossbows (Vanguard Deployment)`
- 新增属性：`guerrilla_deploy`

## 设计说明

本 MOD 不直接修改原版天廷龙弩手。它复制原单位必要的 DB 行并替换为新单位 key：

- `main_units_tables` 与 `land_units_tables`：复制核心单位数据。
- `unit_attributes_groups_tables` 与 `unit_attributes_to_groups_junctions_tables`：复制原属性并新增先锋部署。
- `land_units_to_unit_abilites_junctions_tables`：保留阴系协同被动。
- `variants_tables` 与 `unit_variants_tables`：复用原模型、单位卡。
- `building_units_allowed_tables`：复制原招募建筑。
- `unit_set_to_unit_junctions_tables`：加入原单位所在的通用单位集合和原单位专属集合，以继承相关科技/技能效果。
- `text/db`：新增中文名称与 loading screen 文本。单位短/长描述沿用原版描述 key，避免新增未在 description DB 表登记的引用。

未复制 `battle_set_piece_*`、`armed_citizenry_*`、`mercenary_unit_groups` 等原版剧情战斗、驻军或特殊军队编成表，避免把新单位额外塞进原版任务战斗和驻军。RPFM diagnostics 标记为 banned 的 `allied_recruitment_core_units_tables` 与 `main_unit_ownership_content_pack_junctions_tables` 也不放入本 MOD。

用 RPFM 新建 Pack 后，将 `db/` 和 `text/db/` 下 TSV 按对应表导入即可。不要在同一个 pack 里同时放中英两套同 key Loc，否则 RPFM 会报 duplicated combined keys。导入后运行 diagnostics，并在自定义战斗或战役中确认新单位可招募且部署阶段拥有先锋部署。
