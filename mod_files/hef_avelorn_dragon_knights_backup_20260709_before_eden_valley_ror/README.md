# hef_avelorn_dragon_knights

新增高等精灵单位：阿瓦隆龙骑士。

## 核心 key

- 新单位：`hefadk_hef_cav_avelorn_dragon_knights`
- 新小型耀星龙 battle mount：`hefadk_hef_mnt_star_dragon_025`
- 新耀星龙 mount variant：`hefadk_hef_star_dragon_mount_025`
- 新小型耀星龙 battle entity：`hefadk_hef_mon_star_dragon_025`
- 新 360 度骑手 battle entity：`hefadk_hef_rider_360_avelorn_dragon_knights`
- 新骑手 battle personality：`hefadk_avelorn_sister_dragon_rider`
- 新近战武器：`hefadk_hef_star_dragon_quarter`
- 新远程武器/弹体：`hefadk_hef_longbow_arrow_avelorn_dragon_knights`
- 新一次性耀星龙吐息：`hefadk_unit_abilities_star_dragons_breath_once`
- 新列阵 spacing：`hefadk_avelorn_dragon_knights_flying`
- 新长描述 key：`hefadk_unit_long_text_hef_cav_avelorn_dragon_knights`
- 新短描述 key：`hefadk_unit_short_text_hef_cav_avelorn_dragon_knights`

## 设计说明

本 MOD 不修改原版阿瓦隆姐妹、精灵公主、耀星龙单位、原版耀星龙坐骑或原版武器。

单位组合方式：

- 兵牌：使用 `ui/units/icons/hefadk_hef_cav_avelorn_dragon_knights.png`，由 `mod/generated.png` 缩放为原版兵牌尺寸 `60x130`
- 骑手外观：阿瓦隆姐妹 `wh2_dlc10_hef_inf_sisters_of_avelorn_0`
- 单位类型：`main_units_tables.caste=monster`，`land_units_tables.category=war_beast`，`class=com`，对齐精灵公主骑耀星龙的战斗类型
- 骑乘动画：`land_units_tables.man_animation` 与 `battle_personalities_tables.man_animations_table` 都使用精灵公主骑耀星龙的 `hu1b_elf_dr1_dragon_wb_sword_and_bow`
- 骑手挂点：复制精灵公主骑耀星龙的 autonomous rider 链路，`riders_attachment_point=ap_riderpos_0`
- 360 度射击：新建 `hefadk_hef_rider_360_avelorn_dragon_knights`，`land_units_tables.man_entity` 与 `battle_personalities_tables.battle_entity` 都指向该新 entity；该 entity 保留 `fire_arc_close=360.0000`，并参考永恒女王侍女/精灵公主的有效 360 射手 entity 调整 `turn_speed=160.0000`、tracking、`small_entity` 等字段；`battle_personalities_tables.autonomous_rider_hero=true`，对齐原版骑龙/骑飞行坐骑角色链路
- 坐骑射界：`hefadk_hef_mon_star_dragon_025.fire_arc_close=360.0000`；实测显示游戏内单位射界显示会读取/受限于 mount entity 的 `fire_arc_close`，只改 rider entity 仍会显示原星龙的 120 度
- 坐骑：复制耀星龙 battle mount，新 variant 只改 `mount_scale=0.2613`，保留 `scale=1.1500`，避免缩小骑手
- 坐骑 entity：新建 `hefadk_hef_mon_star_dragon_025`，以耀星龙 entity 为母本，但按小型多实体飞行怪兽收敛碰撞半径、质量、高度、抗硬直和 locomotion，避免视觉缩小后仍使用原版大龙碰撞
- 多实体减员：新 rider entity 与新 mount entity 均设为 `can_dismember=true`
- 实体数量：`main_units.num_men=12`，`land_units.num_mounts=12`
- 部队列阵：`rank_depth=2`，`spacing=hefadk_avelorn_dragon_knights_flying`；该 spacing 复制飞马骑兵模板后略增间距，`close_formation_spacing_horizontal=6.0000`、`close_formation_spacing_vertical=5.8000`，避免飞马间距偏紧，同时不再使用 4 模型狮鹫骑士的超大 spacing
- 兵种头像：低画质 porthole 复制阿瓦隆姐妹 `ui/units/minspec_portholes/wh2_dlc10_hef_inf_sisters_of_avelorn_0*.png`，并改名为 `hefadk_hef_cav_avelorn_dragon_knights*.png`，已确认可显示静态阿瓦隆姐妹头像。高画质动态 porthole 通过 `main_units_tables.porthole_composite_scene=composite_scene\porthole\hefadk_avelorn_dragon_knights_porthole.csc` 指向专用单人场景；该场景以阿拉瑞丽单实体 porthole 模板为底，主模型改为阿瓦隆姐妹，额外发丝节点改为原版 `dummy_mesh`，并保留固定 `[Camera]` 模板，避免实时捕捉本单位的龙模型，也避免使用带 `camera_focal_*` 轨道的模板导致镜头疑似锁头
- 血量平衡：`bonus_hit_points=942`，约为耀星龙本体血量 9416 的 0.1 倍；12 模型总血量约为耀星龙的 1.2 倍
- 近战攻防冲：以耀星龙为基准后继续削弱，`melee_attack=56`、`melee_defence=42`、`charge_bonus=45`；领导力 `morale=75`
- 近战武器：复制精灵公主骑耀星龙/耀星龙使用的 `wh2_main_hef_star_dragon` 为 `hefadk_hef_star_dragon_quarter`，先由 `145/435` 调整为 `36/109`，当前再乘 `0.75` 后取整为 `27/82`
- 远程武器：复制阿瓦隆姐妹弓箭为 `hefadk_hef_longbow_arrow_avelorn_dragon_knights`；当前弹体伤害为阿瓦隆姐妹的 1.5 倍，即 `4/18 -> 6/27`；装填为原版 0.75 倍，即 `10 -> 7.5000`；射程改为 `200`，并同步调整 `calibration_distance=133.3333`、`expiry_range=333`；弹药从 `33` 翻倍为 `66`；`shots_per_volley=1`，`projectile_number=4`，改回 burst fire，`burst_size=2`、`burst_shot_delay=0.2000`，弹速回到阿瓦隆姐妹原值 `muzzle_velocity=55.0000`，`spread=1.8000`，`collision_radius=0.1000`，不可伤害建筑，且建筑伤害倍率还原为阿瓦隆姐妹原弹体的 `0.2500`，不会伤害友军
- 属性：阿瓦隆姐妹 + 精灵公主骑耀星龙属性并集；平衡后移除 `hide_forest`、`guerrilla_deploy` 与 `unbreakable`，恢复耀星龙的 `damage_mod_missile=25`，并继续移除 `encourages`，避免获得领主激励光环
- 能力：保留阿瓦隆姐妹武艺高强；耀星龙吐息改为专用新 key `hefadk_unit_abilities_star_dragons_breath_once`，复制原版吐息链路但将 `num_uses=1`，未复制原版 `uses_mod` effect bonus junction，避免次数被全局龙息加成改回
- 招募建筑：复制耀星龙招募建筑
- 等级定位：V 级，AI 质量复制耀星龙 `tier_5_units`
- 科技/加成继承：加入阿瓦隆姐妹和耀星龙相关 unit set，以接收两边已有科技和效果
- 文本：新增独立 short/historical description DB 行与中文 Loc；描述结合阿瓦隆姐妹的永恒女王圣卫设定、卡勒多耀星龙盟约，以及该部队的空中骑射定位

## 打包说明

用 RPFM 新建 Pack 后，将本目录下 `db/` 与 `text/db/` 的 TSV 按对应表导入即可。导入后运行 diagnostics；如果需要进一步调整平衡，优先改新单位自己的 `main_units_tables` 和 `land_units_tables` 行，不要修改原版耀星龙或阿瓦隆姐妹行。
