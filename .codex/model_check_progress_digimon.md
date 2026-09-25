STATUS: IN_PROGRESS

# 数码宝贝 v2 模型检验台账（leader: digimon）

范围：`mod_files/zzz_czx_digimon_v2/` → 部署包 `zzz_czx_digimon_v2.pack`（playset pos100，mod_id `local:data:6d429f74a958fd64f5`）

## 全局状态（2026-09-25 iter1 基线）

- **文件链 104/104 齐**：vmd→wsmodel→rmv2→material→dds 全链存在；RMV2 内嵌骨架名 == battle_skeletons.name == 骨架目录名（czx_*）。见 `scratch/model_check/digimon/l0_report.tsv`。
- **DB 行 104/104 齐**：main/land/unit_variants/variants/battle_animations_table/battle_skeletons/custom_battle_permissions/loc（name+short+hist）全在；audit_dangling_refs 0 ERROR（104 WARN 全部是 `wh3_main_cth_the_northern_provinces` 已知误报）。
- ⚠ **animset 注册层整体缺失**：源码 `animations/database/battle/bin/` 为空，pack 内无 `animations/database/` 子树（无 bin 无 animpack）。当前 `land_units.man_animation` 全部指向 vanilla 族套件（hu1_empire_sword_and_shield×83 / wf1_dire_wolf×9 / sn1_sepulchral_stalker_halberd×5 / sp1_giant_spider×4 / bi1_eagle×3，2026-09-24 13:07 改动），czx_dgm_*_suffix 动画 key 仅被 battle_animations_table/culture 表引用——自定义套件资产（9021 clips + 104 骨架 + bins）目前是休眠层。唯一 animpack 副本在 `scratch/zzz_czx_digimon_v2_animsets.animpack.broken`（Sep 24 12:55，104 条，内部名=stem=czx 名=**matched-combat 修复前**布局）。**另一会话正在 crash_20260925 排查，animpack 去留由主会话裁决，本轮不重建。**
- ⚠ **unit_set_to_unit_junctions 全空**（仅表头）：104 只无 unit_set 归属——自定义战斗选人界面分类页签可能不显示它们（units_custom_battle_permissions 已在，全派系行齐）。待确认影响。
- Warhammer3.exe 运行中 → L4 全跳过（「待游戏窗口」）。

## 单位台账

| unit | cn | stage | form | animset(man_animation) | skel | L0 | L1 | L2 | L3 | L4 | 问题/修复 | 状态 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| czx_dgm_agumon | 亚古兽 | rookie | biped | hu1_empire_sword_and_shield | czx_agumon | ⚠缺bin层 | ✅ | ✅内收 | ❌扭曲 | ⏭游戏运行中 | L3 定制剪辑扭曲（walk 头折贴地/attack 四肢拉条/death 团状）；idle 尚可；vanilla hu1 回退路径渲染正常偏拉长；retarget 大摆幅失真待专项返工 | ❌未修阻塞 |
| czx_dgm_gabumon | 加布兽 | rookie | biped | hu1_empire_sword_and_shield | czx_gabumo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_biyomon | 比丘兽 | rookie | flyer | bi1_eagle | czx_bi | ⚠缺bin层 | ✅ | ⚠翼骨出网格 | ⚠翅膀摊平 | ⏭游戏运行中 | bird01 骨架 bind 展翼 vs mesh 收翼，翼骨伸出网格 3-4x；fly_walk 翅膀被拉成平板帆、attack 成扇形——骨架 fit 需按收翼重配翼链 | ❌未修阻塞 |
| czx_dgm_patamon | 巴达兽 | rookie | flyer | wf1_dire_wolf | czx_pa | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_gomamon | 哥玛兽 | rookie | biped | hu1_empire_sword_and_shield | czx_gomamo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_palmon | 巴鲁兽 | rookie | biped | hu1_empire_sword_and_shield | czx_palmon | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_tentomon | 甲虫兽 | rookie | insect | sp1_giant_spider | czx_tent | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_guilmon | 基尔兽 | rookie | biped | hu1_empire_sword_and_shield | czx_guilmo | ⚠缺bin层 | ✅ | ✅内收 | ❌扭曲 | ⏭游戏运行中 | L3 walk 前俯驼背、attack 双臂拉成红条、death 整体拉伸；同 agumon 的 hu1 retarget 失真 | ❌未修阻塞 |
| czx_dgm_renamon | 妖狐兽 | rookie | biped | hu1_empire_sword_and_shield | czx_renamo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_dorumon | 多路兽 | rookie | quadruped | hu1_empire_sword_and_shield | czx_dorumo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_plotmon | 小狗兽 | rookie | quadruped | wf1_dire_wolf | czx_pl | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_veemon | v仔兽 | rookie | biped | hu1_empire_sword_and_shield | czx_veemon | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_lalamon | 拉拉兽 | rookie | biped | hu1_empire_sword_and_shield | czx_lalamo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_sunflowmon | 向日葵兽 | rookie | biped | hu1_empire_sword_and_shield | czx_sunflo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_tinkermon | 叮克兽 | rookie | flyer | hu1_empire_sword_and_shield | czx_tinker | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_zubamon | 兹巴兽 | rookie | biped | hu1_empire_sword_and_shield | czx_zubamo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_greymon | 暴龙兽 | champion | biped | hu1_empire_sword_and_shield | czx_greymo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_garurumon | 加鲁鲁兽 | champion | quadruped | wf1_dire_wolf | czx_ga | ⚠缺bin层 | ✅ | ✅内收 | ❌扭曲 | ⏭游戏运行中 | L3 walk/attack/death 全部蜷缩变形（头折进胸腔、腿互绞、鬃毛件漂浮）；quad 族 retarget 失真 | ❌未修阻塞 |
| czx_dgm_birdramon | 巴多拉兽 | champion | flyer | bi1_eagle | czx_b0 | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_angemon | 天使兽 | champion | flyer | hu1_empire_sword_and_shield | czx_angemo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_ikkakumon | 海狮兽 | champion | quadruped | wf1_dire_wolf | czx_ik | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_togemon | 仙人掌兽 | champion | biped | hu1_empire_sword_and_shield | czx_togemo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_kabuterimon | 比多兽 | champion | insect | sp1_giant_spider | czx_kabu | ⚠缺bin层 | ✅ | ✅内收 | ❌扭曲 | ⏭游戏运行中 | L3 walk/attack 蜷缩成球、death 位移出画面变小；spider 族 retarget 失真（或需 pos_damp） | ❌未修阻塞 |
| czx_dgm_gatomon | 迪路兽 | champion | biped | hu1_empire_sword_and_shield | czx_gatomo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_growlmon | 古拉兽 | champion | biped | hu1_empire_sword_and_shield | czx_growlm | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_dorugamon | 多路加兽 | champion | quadruped | hu1_empire_sword_and_shield | czx_doruga | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_geogreymon | 大地暴龙兽 | champion | biped | hu1_empire_sword_and_shield | czx_geogre | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_kyubimon | 九尾狐兽 | champion | quadruped | wf1_dire_wolf | czx_ky | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_tyranomon | 巨龙兽 | champion | biped | hu1_empire_sword_and_shield | czx_tyrano | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_seadramon | 海龙兽 | champion | serpent | sn1_sepulchral_stalker_halberd | czx_sea | ⚠缺bin层 | ✅ | ⚠供体骨出网格 | ✅连贯 | ⏭游戏运行中 | L2 供体腿/翼骨落于网格外但 L3 三剪辑（walk/attack_03/death）运动连贯无异常——疑似未蒙皮无害 | ✅通过 |
| czx_dgm_veedramon | v龙兽 | champion | biped | hu1_empire_sword_and_shield | czx_veedra | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_zubaeagermon | 兹巴伊戈兽 | champion | flyer | wf1_dire_wolf | czx_zu | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_veemonex | v仔兽ex | champion | biped | hu1_empire_sword_and_shield | czx_veemo1 | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_fairymon | 仙女兽 | champion | flyer | hu1_empire_sword_and_shield | czx_fairym | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_vritramon | 火神兽 | champion | biped | hu1_empire_sword_and_shield | czx_vritra | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_duramon | 杜兰兽 | ultimate | biped | hu1_empire_sword_and_shield | czx_duramo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_metalgreymon | 机械暴龙兽 | ultimate | biped | hu1_empire_sword_and_shield | czx_metalg | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_weregarurumon | 兽人加鲁鲁兽 | ultimate | biped | hu1_empire_sword_and_shield | czx_werega | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_garudamon | 伽偻达兽 | ultimate | flyer | hu1_empire_sword_and_shield | czx_garuda | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_angewomon | 天女兽 | ultimate | flyer | hu1_empire_sword_and_shield | czx_angewo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_zudomon | 祖顿兽 | ultimate | biped | hu1_empire_sword_and_shield | czx_zudomo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_megakabuterimon | 超比多兽 | ultimate | insect | sp1_giant_spider | czx_mega | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_lilimon | 花仙兽 | ultimate | flyer | hu1_empire_sword_and_shield | czx_lilimo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_magnaangemon | 神圣天使兽 | ultimate | flyer | hu1_empire_sword_and_shield | czx_magnaa | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_wargrowlmon | 大古拉兽 | ultimate | biped | hu1_empire_sword_and_shield | czx_wargro | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_rizegreymon | 跃升暴龙兽 | ultimate | biped | hu1_empire_sword_and_shield | czx_rizegr | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_paildramon | 机甲龙兽 | ultimate | biped | hu1_empire_sword_and_shield | czx_paildr | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_megaseadramon | 超海龙兽 | ultimate | serpent | sn1_sepulchral_stalker_halberd | czx_meg | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_skullgreymon | 丧尸暴龙兽 | ultimate | biped | hu1_empire_sword_and_shield | czx_skullg | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_metaltyranomon | 金属巨龙兽 | ultimate | biped | hu1_empire_sword_and_shield | czx_metalt | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_lilamon | 丁香兽 | ultimate | biped | hu1_empire_sword_and_shield | czx_lilamo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_taomon | 祭师兽 | ultimate | biped | hu1_empire_sword_and_shield | czx_taomon | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_jetsilphymon | 喷射西尔芙兽 | ultimate | flyer | hu1_empire_sword_and_shield | czx_jetsil | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_aerovdramon | 天翔V龙兽 | ultimate | flyer | hu1_empire_sword_and_shield | czx_aerovd | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_blitzgreymon | 电光暴龙兽 | mega | biped | hu1_empire_sword_and_shield | czx_blitzg | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_cresgarurumon | 偃月加鲁鲁兽 | mega | quadruped | hu1_empire_sword_and_shield | czx_cresga | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_durandamon | 杜兰达兽 | mega | biped | hu1_empire_sword_and_shield | czx_durand | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_metalseadramon | 钢铁海龙兽 | mega | serpent | sn1_sepulchral_stalker_halberd | czx_met | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_plesiomon | 蛇颈龙兽 | mega | serpent | sn1_sepulchral_stalker_halberd | czx_ple | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_machinedramon | 机械邪龙兽 | mega | biped | hu1_empire_sword_and_shield | czx_machin | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_chaosdramon | 混沌龙兽 | mega | biped | hu1_empire_sword_and_shield | czx_chaosd | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_sakuyamon | 沙古牙兽 | mega | biped | hu1_empire_sword_and_shield | czx_sakuya | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_rosemon | 蔷薇兽 | mega | biped | hu1_empire_sword_and_shield | czx_rosemo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_rosemonbm | 蔷薇兽爆裂形态 | mega | biped | hu1_empire_sword_and_shield | czx_rosem0 | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_vikemon | 维京兽 | mega | biped | hu1_empire_sword_and_shield | czx_vikemo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_heraklekabuterimon | 力神比多兽 | mega | insect | sp1_giant_spider | czx_hera | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_magnadramon | 圣龙兽 | mega | quadruped | wf1_dire_wolf | czx_ma | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_hououmon | 凤凰兽 | mega | flyer | bi1_eagle | czx_ho | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_dorugoramon | 多路龙兽 | mega | quadruped | hu1_empire_sword_and_shield | czx_dorug0 | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_fujinmon | 风神兽 | mega | biped | hu1_empire_sword_and_shield | czx_fujinm | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_wargreymon | 战斗暴龙兽 | mega | biped | hu1_empire_sword_and_shield | czx_wgm001 | ⚠缺bin层 | ✅ | ✅内收 | ⚠可辨 | ⏭游戏运行中 | L3 attack_05 站姿正常、run/death 前倾可辨——体形接近 humanoid01 失真较轻，边缘通过 | ✅通过 |
| czx_dgm_wargreymonx | 战斗暴龙兽X | mega | biped | hu1_empire_sword_and_shield | czx_wargre | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_metalgarurumon | 钢铁加鲁鲁 | mega | quadruped | wf1_dire_wolf | czx_me | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_metalgarurumonx | 钢铁加鲁鲁X | mega | quadruped | wf1_dire_wolf | czx_m0 | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_shinegreymon | 闪光暴龙兽 | mega | biped | hu1_empire_sword_and_shield | czx_shineg | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_shinegreymonbm | 闪光暴龙兽爆裂形态 | mega | biped | hu1_empire_sword_and_shield | czx_shine1 | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_omegamon | 奥米加兽 | mega | biped | hu1_empire_sword_and_shield | czx_omegam | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_omegamonx | 奥米加兽X | mega | biped | hu1_empire_sword_and_shield | czx_omega5 | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_omegamonab | 奥米加兽Alter-B | mega | biped | hu1_empire_sword_and_shield | czx_omega1 | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_omegamonas | 奥米加兽Alter-S | mega | biped | hu1_empire_sword_and_shield | czx_omega2 | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_omegamond | 奥米加兽兹瓦特战损 | mega | biped | hu1_empire_sword_and_shield | czx_omega3 | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_omegamonm | 奥米加兽慈悲形态 | mega | biped | hu1_empire_sword_and_shield | czx_omega4 | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_gallantmon | 红莲骑士兽 | mega | biped | hu1_empire_sword_and_shield | czx_gallan | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_gallantmoncm | 红莲骑士兽真红莲形态 | mega | biped | hu1_empire_sword_and_shield | czx_galla0 | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_gallantmonx | 红莲骑士兽X | mega | biped | hu1_empire_sword_and_shield | czx_galla1 | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_alphamon | 阿尔法兽 | mega | biped | hu1_empire_sword_and_shield | czx_alpham | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_jesmon | 杰斯兽 | mega | biped | hu1_empire_sword_and_shield | czx_jesmon | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_jesmonx | 杰斯兽X | mega | biped | hu1_empire_sword_and_shield | czx_jesmo0 | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_magnamon | 金甲龙兽 | mega | biped | hu1_empire_sword_and_shield | czx_magnam | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_magnamonx | 金甲龙兽X | mega | biped | hu1_empire_sword_and_shield | czx_magna0 | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_imperialdm | 帝皇龙甲兽龙形态 | mega | flyer | hu1_empire_sword_and_shield | czx_imper1 | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_imperialfm | 帝皇龙甲兽战士形态 | mega | biped | hu1_empire_sword_and_shield | czx_imperi | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_imperialpm | 帝皇龙甲兽圣骑士形态 | mega | biped | hu1_empire_sword_and_shield | czx_imper0 | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_ulforcev | 究极V龙兽 | mega | biped | hu1_empire_sword_and_shield | czx_ulforc | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_ulforcevx | 究极V龙兽X | mega | biped | hu1_empire_sword_and_shield | czx_ulfor0 | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_seraphimon | 炽天使兽 | mega | flyer | hu1_empire_sword_and_shield | czx_seraph | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_ophanimon | 座天使兽 | mega | flyer | hu1_empire_sword_and_shield | czx_ophani | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_ophanimonfm | 座天使兽堕落形态 | mega | flyer | hu1_empire_sword_and_shield | czx_ophan0 | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_mastemon | 莫斯提兽 | mega | biped | hu1_empire_sword_and_shield | czx_mastem | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_zeedmillennium | 最终千年兽 | boss | biped | hu1_empire_sword_and_shield | czx_zeedmi | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_apocalymon | 启示录兽 | boss | biped | sn1_sepulchral_stalker_halberd | czx_apo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_lucemon | 光明兽 | boss | flyer | hu1_empire_sword_and_shield | czx_lucem0 | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_lucemonfm | 光明兽堕落形态 | boss | biped | hu1_empire_sword_and_shield | czx_lucemo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_susanoomon | 金刚武神兽 | boss | biped | hu1_empire_sword_and_shield | czx_susano | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |

## 迭代记录

### iter 1 — 台账建立 + L0 全量 + 首批渲染

- 建台账：104 只 = ROSTER.tsv 权威清单 == vmd 文件名集（diff 0 差异）。
- L0：`scratch/model_check/digimon/l0_audit.py` 全量跑通，结论见上「全局状态」。
- 复用素材：`scratch/digimon_batch/<unit>/<unit>_bound.glb` + `skel_czx_*.json`（104/104 全在）。
- 批次 1（跨形态）：agumon guilmon biyomon garurumon wargreymon seadramon kabuterimon。
- 产物：`scratch/model_check/digimon/{l1,l2,l3,pose}/`（L1=rmv2+dds 直渲；L2=骨架叠加 front/persp；L3=parse_anim_clip→blender_pose_anim→gif；agumon 另渲 VANILLA hu1_sws_walk/attack 对照，图集副本在 `%TEMP%\modelcheck\digimon`）。
- **L1 静态：7/7 ✅**——网格完整、贴图正常（无缺贴图紫/黑块）、朝向比例合理。
- **L2 骨架：5/7 内收 ✅**；biyomon 翼骨 3-4x 超出收翼 mesh（骨架 bind=展翼 vs mesh=收翼，L3 里翅膀被拉成平板帆——需 fit 阶段按收翼重配翼链）；seadramon 供体腿/翼骨落于网格外但运动无异常（疑似未蒙皮，无害观察项）。
- **L3 定制 .anim 离线渲染（数据可信：parse 结果与 digimon_batch 自产 pose.json 逐骨比对一致，且 digimon_batch 自带 qa_*.png 同样扭曲）**：7 只中 5 只扭曲——agumon/guilmon（hu1：四肢拉条、头折贴地）、garurumon（wf1：蜷缩互绞）、kabuterimon（sp1：团状+death 出画）、biyomon（bi1：翼面摊平）；seadramon（sn1）三剪辑连贯 ✅，wargreymon（hu1，体形接近供体）大体可辨 ⚠️。低摆幅 combat_idle 姿态正常 → retarget_delta 世界差值在大摆幅/比例悬殊时失真，属数据问题非渲染管线问题。
- **对照实验**：agumon 渲 vanilla hu1_sws_walk/attack（=当前游戏实际路径，man_animation 指向原版套件）姿态正常仅拉长 → 游戏内现状不是团状扭曲；定制剪辑层休眠且失真。
- **修复决策**：retarget 质量返工（调 RETARGET_DAMP/POS_DAMP 或改用 chr 原生剪辑——chr050→czx_agumon 实测渲染正常）+ animset 注册层去留都属专项，本轮不修，相关 5 只记 ❌未修阻塞。
- L4 全跳过：Warhammer3.exe 运行中（禁动用户游戏窗口/不写 data\）。
