# hef_princess_scaled_star_dragon

新增一个高等精灵领主：精灵公主（改）。

## 修改范围

- 原版 agent subtype：`wh2_main_hef_princess`
- 新 agent subtype：`hefps_hef_princess_mod`
- 新基础单位：`hefps_hef_cha_princess_mod_0`
- 新耀星龙骑乘单位：`hefps_hef_cha_princess_mod_5`
- 新耀星龙 battle mount：`hefps_hef_mnt_star_dragon_040`
- 新耀星龙 campaign mount：`hefps_cam_mnt_hef_star_dragon_040`
- 新耀星龙 mount variant：`hefps_hef_star_dragon_mount_040`

## 设计说明

本 MOD 不修改原版精灵公主、原版耀星龙坐骑、原版耀星龙兵种或原版 battle entity。它复制精灵公主的领主 subtype、可招募派系、技能树引用、坐骑技能、坐骑 ancillary 与 bodyguard 单位链路。

仅新建的 `精灵公主（改）` 在装备耀星龙坐骑时使用独立 mount/variant：

- 原版 battle mount：`wh2_main_hef_mnt_star_dragon` -> 新 battle mount：`hefps_hef_mnt_star_dragon_040`
- 原版 campaign mount：`wh2_main_cam_mnt_hef_star_dragon` -> 新 campaign mount：`hefps_cam_mnt_hef_star_dragon_040`
- 原版 mount variant：`wh2_main_hef_star_dragon_mount` -> 新 variant：`hefps_hef_star_dragon_mount_040`
- `variants_tables.mount_scale`：`1.0450 -> 0.4180`
- `variants_tables.scale`：保留原版 `1.1500`，避免同步缩小骑手模型

其他坐骑单位复制原数据并保持原模型。新耀星龙坐骑的碰撞、实体、血量和战斗数值保持原版公主骑耀星龙数据，只通过 `mount_scale` 缩小坐骑模型，避免影响骑手、普通领主骑耀星龙或耀星龙作为兵种单位时的大小。

`units_custom_battle_permissions_tables.set_piece_character` 保留原版 `wh2_main_hef_cha_princess_0`。该字段引用 `battle_set_piece_armies_characters_tables.character_name`，不是普通单位 key；替换为新单位 key 会触发 RPFM invalid reference。

未放入 RPFM 已知 banned 的 `main_unit_ownership_content_pack_junctions_tables`。
