# zzz_czx_swarm_units 实现笔记

## 第二批：被感染/原始虫群单位（2026-09-13）

新增 5 个单位，全部来自用户提供的静态 GLB，经 blender_rig.py 自动蒙皮到 WH3 骨架。

| key | 中文名 | 骨架/动画集 | 供体 | 定位 |
|---|---|---|---|---|
| czx_baolongshou | 暴龙兽 | heavyquadruped01 / hq1_feral_stegadon | lzd_stegadon_02.rmv2 | 单体巨兽，46攻/70冲锋/9600血/2000金/T4 |
| czx_inf_tank | 被感染的坦克 | steamtank01 / wm_steam_tank01 | emp_steam_tank_01.rmv2 | 战车引擎单位，主炮40弹+冲撞，2200金/T4 |
| czx_dehaka | 德哈卡 | humanoid11b / hu11b_dlc17_ghorgon | bst_ghorgon_01.rmv2 | 单体巨兽英雄级，62攻/11800血/2400金/T5 |
| czx_inf_diamondback | 被感染的响尾蛇 | spider01 / sp1_giant_spider | grn_giant_spider_body_01.rmv2 | 16模型怪步，游走侧翼，1200金/T3 |
| czx_inf_marine | 被感染的枪兵 | humanoid01 / hu1_empire_sword_rifle | emp_volkmar_body_01.rmv2 | 90模型步枪步，650金/T2 |

### 坦克链路（与生物单位不同）

- 网格走引擎链：`land_units.engine=czx_inf_tank_engine` →
  `db/battlefield_engines_tables/!!czx_swarm_units.tsv` 里 model=`czx_inf_tank`（VMD 名）。
- `articulated_record=wh3_dlc25_emp_veh_steam_tank`（车轮关节，复用原版）。
- `mount=emp_hidden_mount_steam_tank`，乘员 variant 用 `czx_inf_marine`
  （感染枪兵站在车体上；原版用 wh_emp_state_troops）。
- destroyed_model 复用原版蒸汽坦克残骸 wsmodel。

### 新技能（全被动，unique_id 789900116-120）

- czx_ability_baolongshou_primal_fury 原始狂怒：+8攻 ×1.15冲锋 ×1.1速
- czx_ability_inf_tank_infested_hull 感染装甲：+15甲 +15远抗
- czx_ability_dehaka_essence_leech 精华汲取：再生型回血，-20火弱
- czx_ability_diamondback_blitz 闪电突袭：×1.15速 ×1.2冲锋 ×2加速
- czx_ability_marine_infested_rounds 感染弹丸：弹药附加中毒（wh_main_unit_contact_poison）

三个单体单位另挂 wh3_main_unit_passive_single_entity。

### 管线脚本

- `tools/convert_new_units.py`：UNITS 表新增 5 条配置（骨架 JSON、donor rmv2、包内目录）。
- `tools/add_inf_units_db.py`：DB 增量行生成器（克隆原版供体行；建筑 305 座/单位，key 段 2147198940-2147200464；25 派系自定义战权限；104 军事组）。
- `tools/gen_new_unit_cards.py`：由 Blender 前视渲染图裁 60x130 兵牌 + 120x260 infopic。
- `tools/parse_anim_skeleton.py`：已支持 `animations/skeletons/*.anim` 的 zstd 封装格式（28 b5 2f fd magic + 4B 原始大小前缀）。

### 已知限制

- 蒙皮用 `blender_rig2.py`（拓扑感知：最近骨初绑→邻域表决平滑→扩散渐变）；
  装饰骨黑名单 = 内置通用表 + 每骨架追加正则（hq1: skulls_/pole_/gut_/belly_/eyelid/tongue/jaw_/bow_；
  hu11b: eyelid/eyebrow；hu1: eyebrow/eye_/jaw；sp1/st1 无追加）。
- 暴龙兽 fit 轴必须用 `x`（hq1 骨架被鞍座骨拉高，auto 会选 y 把模型放大 3 倍——踩过）。
- 坦克长颈主要绑到 barrel_/exhaust_ 系骨，开火时随炮管后座摆动。
- 人工微调入口：`manual_edit/<unit>.blend`（Blender Weight Paint 改权重 → 导出 skinned GLB → 重转）。
  详见 `manual_edit/README.md`。
