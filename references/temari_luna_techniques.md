# temari_luna.pack 技术提取（工坊 3807340793，疑似 AI 产出，103MB）

> 提取目的：复用其「整单位替换 + 自定义骨骼/动作 + 技能播歌」的实现手法。
> 源：steamapps/workshop/content/1142710/3807340793/temari_luna.pack（PFH5，99 文件，无依赖声明）。
> 单一命名空间 `codex_temari_luna_v001`，纯数据驱动（零 lua），vanilla 复用率极高——结构干净，适合当模板读。

## 1. 整单位替换（不动 vanilla 结构，同主键覆盖）

替换目标是 RoR 精英玉鼓 `wh3_dlc24_cth_veh_zhangu_war_drum_ror`：

- `main_units` 写**同主键行** `unit=wh3_dlc24_cth_veh_zhangu_war_drum_ror`（row-level 冲突 later-wins），
  只把 `land_unit` 字段改指 `codex_temari_luna_v001_unit`——招募/费用/tier/vo/UI 分组全部保留原版值，
  只有战场实体被换。
- `unit_variants`：`name=wh3_dlc24_cth_veh_zhangu_war_drum_ror` → `unit=codex_temari_luna_v001_unit`、
  `variant`/`unit_card=codex_temari_luna_v001`。
- `land_units`（新 key `codex_temari_luna_v001_unit`）抄原版战鼓数值（6192 血、38/27、wh2_main_plate_95），
  改 `man_animation=codex_temari_luna_v001`、`man_entity=codex_temari_luna_v001_entity`；
  `attribute_group=wh3_dlc24_cth_veh_zhangu_war_drum_ror` **直接复用 vanilla 属性组**。
- 附加技能：`land_units_to_unit_abilites` 9 行 = 原版三鼓技能（bastion/disdain/icon）+ harmony 阴阳 +
  single_entity + 自定义 `ror_fury`/`play`/`stop`。

**手法**：替换不是改 vanilla 行，而是「vanilla 主键 → 自定义 land_unit/variant」的指针重定向。

## 2. 技能播歌（纯 DB + wwise，零脚本）

调用链：

```
unit_special_abilities.codex_temari_luna_v001_play   (active_time=155.6s≈曲长, use_loop_stance=false)
  → special_ability_to_special_ability_phase_junctions (order=1, target_self)
  → special_ability_phases.codex_temari_luna_v001_play (phase_audio=codex_temari_luna_v001_audio, cant_move=true)
  → audio_ability_phases.codex_temari_luna_v001_audio (unit_removal_event=Stop_codex_temari_luna_v001, max_distance=10000)
  → audio_metadata_tags: Play_codex_temari_luna_v001 / Stop_codex_temari_luna_v001
      (is_persistent_loop=true, play_at_base=true, culling_distance_override=10000)
  → audio/wwise/global_music_codex_temari_luna_v001.bnk + 3156169727.wem(2.24MB 曲子)
     + event_data__codex_temari_luna_v001.dat
```

- 「停止表演」是第二个 ability `codex_temari_luna_v001_stop`，其 phase_audio 指向 `_stop_audio` 行，
  该行的 `stop_event=Stop_codex_temari_luna_v001`——即停止按钮本体就是"播 Stop 事件"。
- **歌舞卡点**：`animations/audio/battle/<id>/luna_sync_v012.snd.meta` 是二进制 SOUND_TRIGGER 记录，
  把 `Play_/Stop_codex_temari_luna_v001` 打在动画时间轴（含 float 时间戳）——音乐节拍与动画帧同步靠这个，
  不是靠脚本计时。
- bnk 命名 `global_music_<id>`；wem 文件名是 wwise 数字 hash。

## 3. 双按钮互斥（play/stop/原版三鼓全互斥）

```
special_ability_exclusive_toggle_groups:  wh3_dlc24_zhangu_war_drum_exclusive_toggle   (复用 vanilla 组 key)
unit_special_ability_to_special_ability_toggle_groups_junctions:
    该组 ← ror_fury / play / stop   (3 行)
```

自定义技能塞进 vanilla 互斥组 → 与原版三个鼓 buff 天然互斥，无需自建组。

## 4. 自定义骨骼 + 动作包（§10.34 同名约束实测合规）

- `battle_animations_table`：`key=codex_temari_luna_v001, skeleton=codex_temari_luna_v001`
- `animations/database/battle/bin/codex_temari_luna_v001.animpack` + `.bin`
  - animpack 首串 = bin 路径 `animations/database/battle/bin/codex_temari_luna_v001.bin`
  - bin 内串：`codex_temari_luna_v001`（内部名=stem=DB key ✓）、
    `animations/locomotion_graphs/entity_locomotion_graph.xml`（vanilla 运动图复用）
- `battle_skeletons` 行 `codex_temari_luna_v001`：节点全为 `tm_*`（tm_002 spine、tm_010/005 up-leg、
  tm_018/028 foot、tm_039/051 lower-leg、tm_040/038 upper-arm、tm_042 neck、tm_064/076 forearm、
  tm_073/072 footstep、tm_106/112 fingers）+ `hand_left/hand_right/head/root/animroot`。
  `locomotion=biped`，`footstep_nodes=tm_073;tm_072`。
- `animations/skeletons/codex_temari_luna_v001.anim` + `.bone_inv_trans_mats`（骨架定义+逆绑定矩阵）。
- `animations/battle/codex_temari_luna_v001/`：真实动作只有 idle/walk/run/charge/attack/`luna.anim`(19.8MB 舞)，
  **animpack 槽位表把大量槽全部回填 idle.anim**——缺动作就用 idle 兜底，不用做全套。
  文件名带 `_v006/_v008` 迭代后缀，bin 内按完整路径引用。
- phase `requested_stance=music_looped_ability_2`（ror_fury/stop 行）——用 vanilla 舞蹈 stance 驱动循环动作。

## 5. 模型/材质/兵牌

- `variantmeshes/wh_variantmodels/hu1/hef/codex_temari_luna_v001/`：放 hef(高精女) 骨架目录位。
  `temari.rigid_model_v2`(8.7MB) + `temari.wsmodel` + m00–m07 材质 + `tex/mNN_{base_colour,mask,material_map,normal}.dds`。
- `variantmeshdefinitions/codex_temari_luna_v001.variantmeshdefinition`：
  SLOT `body`→wsmodel；`META_DATA audio_entity_type:wh_human_female` + `audio_armour_type:cloth`（模型层挂音频类型）。
- 材质 XML 8 贴图槽：自定义 4 图 + vanilla `commontextures/{bloodmap,dither,winds_of_magic_noise,winds_of_magic_specular}.dds`。
- **自带编译 shader**：`shaders/codex_temari_luna_v001_weighted4_character{,_blood}.xml.shader` +
  `fxc/*.hlsl_compiled`（多数 mod 只引 vanilla shader；这里带了编译产物，可能改过 skinning）。
- 兵牌 `ui/units/icons/codex_temari_luna_v001.png` + `infopics/`（unit_card key=variant 名）。

## 6. 可复用清单 / 注意点

可直接抄的模式：
1. 替换单位 = 同主键 main_units 行改 land_unit + unit_variants 重定向，vanilla 数值一行不碰。
2. 播歌 = phase_audio → audio_ability_phases(unit_removal_event) → metadata_tags Play/Stop → bnk+wem；
   停止按钮 = 第二个 ability 播 stop_event；卡点 = snd.meta SOUND_TRIGGER 打进动画。
3. 技能互斥 = 塞进既有 vanilla exclusive_toggle 组。
4. animpack 三件套同名约束 + idle 兜底全槽位 + vanilla locomotion graph。
5. 单 SLOT variantmeshdefinition + META_DATA 挂音频类型。

注意：pack 内 `variants`/`unit_description_*` 只有 key 无本地化文本（loc 键靠别处或缺）；表版本号新旧混杂
（main_units v7、special_ability_phases v44 等为高版本 schema——对应 9.x 期版本）。整包被工坊标记
"不兼容 WH3"（下架项），具体 9.0 适配性未经游戏内验证——**手法可学，行值别照抄**。
