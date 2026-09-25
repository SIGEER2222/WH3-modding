STATUS: IN_PROGRESS

# 数码宝贝 v2 模型检验台账（leader: digimon）

范围：`mod_files/zzz_czx_digimon_v2/` → 部署包 `zzz_czx_digimon_v2.pack`（playset pos100，mod_id `local:data:6d429f74a958fd64f5`）

## 全局状态（2026-09-25 iter1 基线）

- **文件链 104/104 齐**：vmd→wsmodel→rmv2→material→dds 全链存在；RMV2 内嵌骨架名 == battle_skeletons.name == 骨架目录名（czx_*）。见 `scratch/model_check/digimon/l0_report.tsv`。
- **DB 行 104/104 齐**：main/land/unit_variants/variants/battle_animations_table/battle_skeletons/custom_battle_permissions/loc（name+short+hist）全在；audit_dangling_refs 0 ERROR（104 WARN 全部是 `wh3_main_cth_the_northern_provinces` 已知误报）。
- ⚠ **animset 注册层整体缺失**：源码 `animations/database/battle/bin/` 为空，pack 内无 `animations/database/` 子树（无 bin 无 animpack）。当前 `land_units.man_animation` 全部指向 vanilla 族套件（hu1_empire_sword_and_shield×83 / wf1_dire_wolf×9 / sn1_sepulchral_stalker_halberd×5 / sp1_giant_spider×4 / bi1_eagle×3，2026-09-24 13:07 改动），czx_dgm_*_suffix 动画 key 仅被 battle_animations_table/culture 表引用——自定义套件资产（9021 clips + 104 骨架 + bins）目前是休眠层。
- iter2 animpack 解剖结论（`scratch/model_check/digimon/animpack_audit.py`）：`scratch/zzz_czx_digimon_v2_animsets.animpack.broken` **格式完好**（104 条、无尾字节）、**内部套件名==stem==DB key**（czx_dgm_*_suffix，已是正确命名约定，非 vanilla donor 名）、bin 内引用 `animations/skeletons/czx_*.anim`+`reference_poses/` 正确；且与 `scratch/dgm_plus_pkm_src/animations/database/battle/bin/` 备份 **104/104 逐字节相同**。"broken" 名不符实——格式/命名都对，被弃的真实原因是**剪辑内容畸形**（L3 实测），9-24 拔除+改 vanilla man_animation 属止损。修好剪辑后直接把这 104 bin 回源/重打 animpack 即可，无需改名手术。
- ⚠ **unit_set_to_unit_junctions 全空**（仅表头）：104 只无 unit_set 归属——自定义战斗选人界面分类页签可能不显示它们（units_custom_battle_permissions 已在，全派系行齐）。待确认影响。
- Warhammer3.exe 运行中 → L4 全跳过（「待游戏窗口」）。

## 单位台账

| unit | cn | stage | form | animset(man_animation) | skel | L0 | L1 | L2 | L3 | L4 | 问题/修复 | 状态 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| czx_dgm_agumon | 亚古兽 | rookie | biped | **czx_dgm_agumon_emp_sws1** | czx_agumon | ⚠缺bin层 | ✅ | ✅内收 | ✅chr原生GIF | ⏭环境阻塞 |**iter4 灰度已部署**：95 槽 chr050 重定向 .anim + `zzz_dgm_agumon_only.animpack`（inner==stem==DB key）入源，land_units 单行 man_animation 切 `czx_dgm_agumon_emp_sws1`，重打包 sha 一致、包内 DB 行已验证；其余 103 只仍 vanilla。L3=chr 8 剪辑 GIF 全合身。L4：三连拉起全部 `+0x538a0a` crash-report（环境级，全日 7 次同址含 swarm/满 playset/本包，非 graft 归因；crash 对话框保活 pid 导致 autotest 误报 alive）；iter5：bin 原样并入 12-bin zzz_dgm_chr_native.animpack（payload 仍是 proto graft 版），batch_chr 自动 bonemap 62/72骨复跑 GIF 亦合身；L4环境阻塞待复核 | 🔧已部署待L4 |
| czx_dgm_gabumon | 加布兽 | rookie | biped | **czx_dgm_gabumon_emp_sws1** | czx_gabumo | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 |iter4 批量管线：chr151（双臂 donor）自动 bonemap 62/72 骨，7/7 剪辑 GIF 合身；idle/move/down/win 验收帧正常；iter5批1已部署：chr151 bonemap 62/72骨 7剪辑全OK→graft 槽位满填，GIF合身 |  |
| czx_dgm_biyomon | 比丘兽 | rookie | flyer | **czx_dgm_biyomon_bi1_eagl** | czx_bi | ⚠缺bin层 | ✅ | ⚠翼骨出网格 | ✅chr原生GIF | ⏭环境阻塞 |bird01 骨架 bind 展翼 vs mesh 收翼，翼骨伸出网格 3-4x；fly_walk 翅膀被拉成平板帆、attack 成扇形——骨架 fit 需按收翼重配翼链；iter4 chr307 原生管线 95/95 骨全映射（wing→J_hane、tail→J_sippo 折叠到单骨），11/11 剪辑 GIF 合身；iter5批1已部署：chr307 bonemap 95/95骨 11剪辑全OK→graft 槽位满填，GIF合身 | ❌未修阻塞(fit) |
| czx_dgm_patamon | 巴达兽 | rookie | flyer | wf1_dire_wolf | czx_pa | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_gomamon | 哥玛兽 | rookie | biped | **czx_dgm_gomamon_emp_sws1** | czx_gomamo | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | | iter5批1已部署：chr343 bonemap 45/72骨 12剪辑全OK→graft 槽位满填，GIF合身 |  |
| czx_dgm_palmon | 巴鲁兽 | rookie | biped | hu1_empire_sword_and_shield | czx_palmon | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter7 biped试跑：chr050 bonemap 62/72骨 8剪辑GIF合身→批4名单 |  |
| czx_dgm_tentomon | 甲虫兽 | rookie | insect | sp1_giant_spider | czx_tent | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_guilmon | 基尔兽 | rookie | biped | hu1_empire_sword_and_shield | czx_guilmo | ⚠缺bin层 | ✅ | ✅内收 | ❌扭曲 | ⏭游戏运行中 | L3 walk 前俯驼背、attack 双臂拉成红条、death 整体拉伸；同 agumon 的 hu1 retarget 失真 | ❌未修阻塞 |
| czx_dgm_renamon | 妖狐兽 | rookie | biped | hu1_empire_sword_and_shield | czx_renamo | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter7 biped试跑：chr151 bonemap 62/72骨 7剪辑GIF合身→批4名单 |  |
| czx_dgm_dorumon | 多路兽 | rookie | quadruped | **czx_dgm_dorumon_emp_sws1** | czx_dorumo | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | | iter5批1已部署：chr112 bonemap 47/72骨 5剪辑全OK→graft 槽位满填，GIF合身 |  |
| czx_dgm_plotmon | 小狗兽 | rookie | quadruped | **czx_dgm_plotmon_wf1_wolf** | czx_pl | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | | iter5批1已部署：chr361 bonemap 37/42骨 5剪辑全OK→graft 槽位满填，GIF合身 |  |
| czx_dgm_veemon | v仔兽 | rookie | biped | hu1_empire_sword_and_shield | czx_veemon | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter7 biped试跑：chr050 bonemap 62/72骨 8剪辑GIF合身→批4名单 |  |
| czx_dgm_lalamon | 拉拉兽 | rookie | biped | hu1_empire_sword_and_shield | czx_lalamo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_sunflowmon | 向日葵兽 | rookie | biped | hu1_empire_sword_and_shield | czx_sunflo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_tinkermon | 叮克兽 | rookie | flyer | **czx_dgm_tinkermon_emp_sws1** | czx_tinker | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter6 族donor试跑：g133(Bip001) bonemap 49/72骨 4剪辑GIF合身；iter7批3已部署（38-bin animpack） |  |
| czx_dgm_zubamon | 兹巴兽 | rookie | biped | hu1_empire_sword_and_shield | czx_zubamo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_greymon | 暴龙兽 | champion | biped | **czx_dgm_greymon_emp_sws1** | czx_greymo | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 |iter4 批量管线：chr326 自动 bonemap 62/72 骨，9/9 剪辑 GIF 合身；idle/move/win/down 验收正常；iter5批1已部署：chr326 bonemap 62/72骨 9剪辑全OK→graft 槽位满填，GIF合身 |  |
| czx_dgm_garurumon | 加鲁鲁兽 | champion | quadruped | **czx_dgm_garurumon_wf1_wolf** | czx_ga | ⚠缺bin层 | ✅ | ✅内收 | ✅chr原生GIF | ⏭环境阻塞 |L3 walk/attack/death 全部蜷缩变形（头折进胸腔、腿互绞、鬃毛件漂浮）；quad 族 retarget 失真；iter4 chr012 原生管线 34/42 骨（clav/finger 无映射=跟随父骨），8/8 剪辑 GIF 合身（idle/move/down/win 验收正常）；iter5批1已部署：chr012 bonemap 34/42骨 8剪辑全OK→graft 槽位满填，GIF合身 | ❌未修阻塞(旧路) |
| czx_dgm_birdramon | 巴多拉兽 | champion | flyer | **czx_dgm_birdramon_bi1_eagl** | czx_b0 | ⚠缺bin层 | ✅ | ⚠翼骨出网格 | ✅chr原生GIF | ⏭环境阻塞 |已有 RETARGET_DAMP 仍压不住：fly_walk 翼面拖拽、attack 蜷缩、death_fall 塌扁；根因是翼骨 bind 尺寸远超 mesh（几何失配，非摆幅问题）；iter5批1已部署：chr308 bonemap 82/95骨 11剪辑全OK→graft 槽位满填，GIF合身 | ❌未修阻塞 |
| czx_dgm_angemon | 天使兽 | champion | flyer | hu1_empire_sword_and_shield | czx_angemo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_ikkakumon | 海狮兽 | champion | quadruped | **czx_dgm_ikkakumon_wf1_wolf** | czx_ik | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr344 bonemap 35/42骨 11剪辑GIF合身；iter6批2已部署（33-bin animpack） |  |
| czx_dgm_togemon | 仙人掌兽 | champion | biped | **czx_dgm_togemon_emp_sws1** | czx_togemo | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr349 bonemap 47/72骨 10剪辑GIF合身；iter6批2已部署（33-bin animpack） |  |
| czx_dgm_kabuterimon | 比多兽 | champion | insect | sp1_giant_spider | czx_kabu | ⚠缺bin层 | ✅ | ✅内收 | ❌扭曲 | ⏭游戏运行中 | L3 walk/attack 蜷缩成球、death 位移出画面变小；spider 族 retarget 失真（或需 pos_damp） | ❌未修阻塞 |
| czx_dgm_gatomon | 迪路兽 | champion | biped | hu1_empire_sword_and_shield | czx_gatomo | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter7 biped试跑：chr050 bonemap 62/72骨 8剪辑GIF合身→批4名单 |  |
| czx_dgm_growlmon | 古拉兽 | champion | biped | hu1_empire_sword_and_shield | czx_growlm | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter7 biped试跑：chr326 bonemap 62/72骨 9剪辑GIF合身→批4名单 |  |
| czx_dgm_dorugamon | 多路加兽 | champion | quadruped | **czx_dgm_dorugamon_emp_sws1** | czx_doruga | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr396 bonemap 42/72骨 5剪辑GIF合身；iter6批2已部署（33-bin animpack） |  |
| czx_dgm_geogreymon | 大地暴龙兽 | champion | biped | hu1_empire_sword_and_shield | czx_geogre | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter7 biped试跑：chr326 bonemap 62/72骨 9剪辑GIF合身→批4名单 |  |
| czx_dgm_kyubimon | 九尾狐兽 | champion | quadruped | **czx_dgm_kyubimon_wf1_wolf** | czx_ky | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter6 族donor试跑：chr012(族quad) bonemap 34/42骨 8剪辑GIF合身；iter7批3已部署（38-bin animpack） |  |
| czx_dgm_tyranomon | 巨龙兽 | champion | biped | hu1_empire_sword_and_shield | czx_tyrano | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter7 biped试跑：chr364(同种metaltyranomon) bonemap 53/72骨 5剪辑GIF合身→批4名单 |  |
| czx_dgm_seadramon | 海龙兽 | champion | serpent | sn1_sepulchral_stalker_halberd | czx_sea | ⚠缺bin层 | ✅ | ⚠供体骨出网格 | ✅连贯 | ⏭游戏运行中 | L2 供体腿/翼骨落于网格外但 L3 三剪辑（walk/attack_03/death）运动连贯无异常——疑似未蒙皮无害 | ✅通过 |
| czx_dgm_veedramon | v龙兽 | champion | biped | **czx_dgm_veedramon_emp_sws1** | czx_veedra | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr397 bonemap 42/72骨 5剪辑GIF合身；iter6批2已部署（33-bin animpack） |  |
| czx_dgm_zubaeagermon | 兹巴伊戈兽 | champion | flyer | wf1_dire_wolf | czx_zu | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_veemonex | v仔兽ex | champion | biped | hu1_empire_sword_and_shield | czx_veemo1 | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter7 biped试跑：chr397(同种veedramon) bonemap 42/72骨 5剪辑GIF合身→批4名单 |  |
| czx_dgm_fairymon | 仙女兽 | champion | flyer | hu1_empire_sword_and_shield | czx_fairym | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_vritramon | 火神兽 | champion | biped | hu1_empire_sword_and_shield | czx_vritra | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_duramon | 杜兰兽 | ultimate | biped | hu1_empire_sword_and_shield | czx_duramo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_metalgreymon | 机械暴龙兽 | ultimate | biped | **czx_dgm_metalgreymon_emp_sws1** | czx_metalg | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | | iter5批1已部署：chr302 bonemap 64/72骨 8剪辑全OK→graft 槽位满填，GIF合身 |  |
| czx_dgm_weregarurumon | 兽人加鲁鲁兽 | ultimate | biped | **czx_dgm_weregarurumon_emp_sws1** | czx_werega | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr140 bonemap 62/72骨 8剪辑GIF合身；iter6批2已部署（33-bin animpack） |  |
| czx_dgm_garudamon | 伽偻达兽 | ultimate | flyer | hu1_empire_sword_and_shield | czx_garuda | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_angewomon | 天女兽 | ultimate | flyer | hu1_empire_sword_and_shield | czx_angewo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_zudomon | 祖顿兽 | ultimate | biped | hu1_empire_sword_and_shield | czx_zudomo | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter7 biped试跑：chr344(同种ikkakumon) bonemap 45/72骨 11剪辑GIF合身→批4名单 |  |
| czx_dgm_megakabuterimon | 超比多兽 | ultimate | insect | **czx_dgm_megakabuterimon_sp1_spid** | czx_mega | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter6 族donor试跑：chr359(insectoid) bonemap 46/74骨 11剪辑GIF合身；iter7批3已部署（38-bin animpack） |  |
| czx_dgm_lilimon | 花仙兽 | ultimate | flyer | hu1_empire_sword_and_shield | czx_lilimo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_magnaangemon | 神圣天使兽 | ultimate | flyer | **czx_dgm_magnaangemon_emp_sws1** | czx_magnaa | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr101 bonemap 40/72骨 5剪辑GIF合身；iter6批2已部署（33-bin animpack） |  |
| czx_dgm_wargrowlmon | 大古拉兽 | ultimate | biped | hu1_empire_sword_and_shield | czx_wargro | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_rizegreymon | 跃升暴龙兽 | ultimate | biped | hu1_empire_sword_and_shield | czx_rizegr | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_paildramon | 机甲龙兽 | ultimate | biped | hu1_empire_sword_and_shield | czx_paildr | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_megaseadramon | 超海龙兽 | ultimate | serpent | sn1_sepulchral_stalker_halberd | czx_meg | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_skullgreymon | 丧尸暴龙兽 | ultimate | biped | hu1_empire_sword_and_shield | czx_skullg | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter7 biped试跑：chr326(同种greymon系) bonemap 62/72骨 9剪辑GIF合身→批4名单 |  |
| czx_dgm_metaltyranomon | 金属巨龙兽 | ultimate | biped | **czx_dgm_metaltyranomon_emp_sws1** | czx_metalt | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr364 bonemap 53/72骨 5剪辑GIF合身；iter6批2已部署（33-bin animpack） |  |
| czx_dgm_lilamon | 丁香兽 | ultimate | biped | hu1_empire_sword_and_shield | czx_lilamo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_taomon | 祭师兽 | ultimate | biped | hu1_empire_sword_and_shield | czx_taomon | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_jetsilphymon | 喷射西尔芙兽 | ultimate | flyer | hu1_empire_sword_and_shield | czx_jetsil | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_aerovdramon | 天翔V龙兽 | ultimate | flyer | **czx_dgm_aerovdramon_emp_sws1** | czx_aerovd | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr400 bonemap 60/72骨 5剪辑GIF合身；iter6批2已部署（33-bin animpack） |  |
| czx_dgm_blitzgreymon | 电光暴龙兽 | mega | biped | hu1_empire_sword_and_shield | czx_blitzg | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_cresgarurumon | 偃月加鲁鲁兽 | mega | quadruped | hu1_empire_sword_and_shield | czx_cresga | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_durandamon | 杜兰达兽 | mega | biped | hu1_empire_sword_and_shield | czx_durand | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_metalseadramon | 钢铁海龙兽 | mega | serpent | sn1_sepulchral_stalker_halberd | czx_met | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_plesiomon | 蛇颈龙兽 | mega | serpent | sn1_sepulchral_stalker_halberd | czx_ple | ⚠缺bin层 | ✅ | ⚠供体骨出网格 | ✅连贯 | ⏭游戏运行中 | damp(tail 0.25/neck-spine 0.4)有效：walk 滑行、attack_03 前扑、death 瘫伏均连贯；L2 供体腿骨落网格外同 seadramon 无害 | ✅通过 |
| czx_dgm_machinedramon | 机械邪龙兽 | mega | biped | hu1_empire_sword_and_shield | czx_machin | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter7 biped试跑：chr364(同族机龙) bonemap 53/72骨 5剪辑GIF合身→批4名单 |  |
| czx_dgm_chaosdramon | 混沌龙兽 | mega | biped | hu1_empire_sword_and_shield | czx_chaosd | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_sakuyamon | 沙古牙兽 | mega | biped | hu1_empire_sword_and_shield | czx_sakuya | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_rosemon | 蔷薇兽 | mega | biped | hu1_empire_sword_and_shield | czx_rosemo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_rosemonbm | 蔷薇兽爆裂形态 | mega | biped | hu1_empire_sword_and_shield | czx_rosem0 | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_vikemon | 维京兽 | mega | biped | hu1_empire_sword_and_shield | czx_vikemo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_heraklekabuterimon | 力神比多兽 | mega | insect | sp1_giant_spider | czx_hera | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_magnadramon | 圣龙兽 | mega | quadruped | **czx_dgm_magnadramon_wf1_wolf** | czx_ma | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter6 族donor试跑：chr548(翼quad) bonemap 34/42骨 12剪辑GIF合身；iter7批3已部署（38-bin animpack） |  |
| czx_dgm_hououmon | 凤凰兽 | mega | flyer | bi1_eagle | czx_ho | ⚠缺bin层 | ✅ | ⚠翼骨出网格 | ❌扭曲 | ⏭游戏运行中 | 同 birdramon：damp 已加仍 fly 全段翼面塌陷成倒 V/死坠压扁；翼骨 bind 远超 mesh 须 fit 重修 | ❌未修阻塞 |
| czx_dgm_dorugoramon | 多路龙兽 | mega | quadruped | **czx_dgm_dorugoramon_emp_sws1** | czx_dorug0 | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr019 bonemap 64/72骨 12剪辑GIF合身；iter6批2已部署（33-bin animpack） |  |
| czx_dgm_fujinmon | 风神兽 | mega | biped | hu1_empire_sword_and_shield | czx_fujinm | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_wargreymon | 战斗暴龙兽 | mega | biped | **czx_dgm_wargreymon_emp_sws1** | czx_wgm001 | ⚠缺bin层 | ✅ | ✅内收 | ✅chr原生GIF | ⏭环境阻塞 |L3 attack_05 站姿正常、run/death 前倾可辨——体形接近 humanoid01 失真较轻，边缘通过；iter5批1已部署：chr027 bonemap 45/72骨 8剪辑全OK→graft 槽位满填，GIF合身 | ✅通过 |
| czx_dgm_wargreymonx | 战斗暴龙兽X | mega | biped | hu1_empire_sword_and_shield | czx_wargre | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter7 biped试跑：chr027(同种wargreymon) bonemap 45/72骨 8剪辑GIF合身→批4名单 |  |
| czx_dgm_metalgarurumon | 钢铁加鲁鲁 | mega | quadruped | **czx_dgm_metalgarurumon_wf1_wolf** | czx_me | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | | iter5批1已部署：chr135 bonemap 37/42骨 8剪辑全OK→graft 槽位满填，GIF合身 |  |
| czx_dgm_metalgarurumonx | 钢铁加鲁鲁X | mega | quadruped | wf1_dire_wolf | czx_m0 | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_shinegreymon | 闪光暴龙兽 | mega | biped | **czx_dgm_shinegreymon_emp_sws1** | czx_shineg | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr094 bonemap 62/72骨 5剪辑GIF合身；iter6批2已部署（33-bin animpack） |  |
| czx_dgm_shinegreymonbm | 闪光暴龙兽爆裂形态 | mega | biped | hu1_empire_sword_and_shield | czx_shine1 | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_omegamon | 奥米加兽 | mega | biped | **czx_dgm_omegamon_emp_sws1** | czx_omegam | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr088 bonemap 47/72骨 7剪辑GIF合身；iter6批2已部署（33-bin animpack） |  |
| czx_dgm_omegamonx | 奥米加兽X | mega | biped | hu1_empire_sword_and_shield | czx_omega5 | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_omegamonab | 奥米加兽Alter-B | mega | biped | hu1_empire_sword_and_shield | czx_omega1 | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_omegamonas | 奥米加兽Alter-S | mega | biped | hu1_empire_sword_and_shield | czx_omega2 | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_omegamond | 奥米加兽兹瓦特战损 | mega | biped | hu1_empire_sword_and_shield | czx_omega3 | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_omegamonm | 奥米加兽慈悲形态 | mega | biped | **czx_dgm_omegamonm_emp_sws1** | czx_omega4 | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr448 bonemap 49/72骨 5剪辑GIF合身；iter6批2已部署（33-bin animpack） |  |
| czx_dgm_gallantmon | 红莲骑士兽 | mega | biped | **czx_dgm_gallantmon_emp_sws1** | czx_gallan | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr013 bonemap 62/72骨 5剪辑GIF合身；iter6批2已部署（33-bin animpack） |  |
| czx_dgm_gallantmoncm | 红莲骑士兽真红莲形态 | mega | biped | **czx_dgm_gallantmoncm_emp_sws1** | czx_galla0 | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr105 bonemap 62/72骨 11剪辑GIF合身；iter6批2已部署（33-bin animpack） |  |
| czx_dgm_gallantmonx | 红莲骑士兽X | mega | biped | hu1_empire_sword_and_shield | czx_galla1 | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter7 biped试跑：chr013(同种gallantmon) bonemap 62/72骨 5剪辑GIF合身→批4名单 |  |
| czx_dgm_alphamon | 阿尔法兽 | mega | biped | **czx_dgm_alphamon_emp_sws1** | czx_alpham | ⚠缺bin层 | ✅ | ✅内收 | ✅chr原生GIF | ⏭环境阻塞 | hu1 walk 整体前倾 ~45°、attack 拧转披风乱飞、death 倾覆——大体积 biped 仍失真（无 damp）；iter5批量管线完毕：chr416 bonemap 21/72骨 4剪辑GIF合身；iter6批2已部署（33-bin animpack） | ❌未修阻塞 |
| czx_dgm_jesmon | 杰斯兽 | mega | biped | **czx_dgm_jesmon_emp_sws1** | czx_jesmon | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr749 bonemap 64/72骨 5剪辑GIF合身；iter6批2已部署（33-bin animpack） |  |
| czx_dgm_jesmonx | 杰斯兽X | mega | biped | hu1_empire_sword_and_shield | czx_jesmo0 | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter7 biped试跑：chr749(同种jesmon) bonemap 64/72骨 5剪辑GIF合身→批4名单 |  |
| czx_dgm_magnamon | 金甲龙兽 | mega | biped | hu1_empire_sword_and_shield | czx_magnam | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_magnamonx | 金甲龙兽X | mega | biped | hu1_empire_sword_and_shield | czx_magna0 | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter7 biped试跑：chr416(alphamon骑士) bonemap 21/72骨 4剪辑GIF合身→批4名单 |  |
| czx_dgm_imperialdm | 帝皇龙甲兽龙形态 | mega | flyer | **czx_dgm_imperialdm_emp_sws1** | czx_imper1 | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter6 族donor试跑：u133(Bip001) bonemap 37/72骨 8剪辑GIF合身；iter7批3已部署（38-bin animpack） |  |
| czx_dgm_imperialfm | 帝皇龙甲兽战士形态 | mega | biped | hu1_empire_sword_and_shield | czx_imperi | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_imperialpm | 帝皇龙甲兽圣骑士形态 | mega | biped | hu1_empire_sword_and_shield | czx_imper0 | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_ulforcev | 究极V龙兽 | mega | biped | **czx_dgm_ulforcev_emp_sws1** | czx_ulforc | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr397 bonemap 42/72骨 5剪辑GIF合身；iter6批2已部署（33-bin animpack） |  |
| czx_dgm_ulforcevx | 究极V龙兽X | mega | biped | **czx_dgm_ulforcevx_emp_sws1** | czx_ulfor0 | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr418 bonemap 49/72骨 5剪辑GIF合身；iter6批2已部署（33-bin animpack） |  |
| czx_dgm_seraphimon | 炽天使兽 | mega | flyer | **czx_dgm_seraphimon_emp_sws1** | czx_seraph | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr315 bonemap 47/72骨 4剪辑GIF合身；iter6批2已部署（33-bin animpack） |  |
| czx_dgm_ophanimon | 座天使兽 | mega | flyer | hu1_empire_sword_and_shield | czx_ophani | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_ophanimonfm | 座天使兽堕落形态 | mega | flyer | **czx_dgm_ophanimonfm_emp_sws1** | czx_ophan0 | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr446 bonemap 49/72骨 5剪辑GIF合身；iter6批2已部署（33-bin animpack） |  |
| czx_dgm_mastemon | 莫斯提兽 | mega | biped | hu1_empire_sword_and_shield | czx_mastem | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_zeedmillennium | 最终千年兽 | boss | biped | hu1_empire_sword_and_shield | czx_zeedmi | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_apocalymon | 启示录兽 | boss | biped | sn1_sepulchral_stalker_halberd | czx_apo | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_lucemon | 光明兽 | boss | flyer | hu1_empire_sword_and_shield | czx_lucem0 | ⚠缺bin层 |  |  |  | ⏭游戏运行中 |  |  |
| czx_dgm_lucemonfm | 光明兽堕落形态 | boss | biped | **czx_dgm_lucemonfm_emp_sws1** | czx_lucemo | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr039 bonemap 42/72骨 11剪辑GIF合身；iter6批2已部署（33-bin animpack） |  |
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

### iter 2 — animpack 解剖 + chr 原型 + damp 三件套复验

- **animpack 解剖**：`scratch/zzz_czx_digimon_v2_animsets.animpack.broken` 格式完好、命名约定正确（inner==stem==DB key）、与 `scratch/dgm_plus_pkm_src/bin/` 备份逐字节相同——弃置原因是剪辑内容畸形而非格式。修复路线=修剪辑数据→bin 回源→重打 animpack→man_animation 指回 czx key。
- **chr 原生路线原型（agumon）**：v1 `mod_files/zzz_czx_digimon/animations/database/battle/bin/chr###.animpack` 共 **50 只**有 chr 源（chr050=亚古兽等，`digimon_batch.py` CHR_MAP 段有 unit→chr 对应）。`scratch/chr_clips/` 已有完整管线遗产：chr050 clips + `bonemap_czx2chr050.json`（24 骨映射）+ `retarget_bonemap.py` 产物 `agu_*_pose.json`。本轮把 agu_move/idle/damage 直接渲到 czx_dgm_agumon_bound.glb：**姿态完全正常**（自然走姿/直立 idle/受击后仰）——同骨架同渲染器下 chr 源✅ vs vanilla retarget 源❌，定性证据拿到。
- **对比图**：`Temp\modelcheck\digimon\l3\` 并存 `czx_dgm_agumon_hu1_sws_*`（畸形）/ `czx_dgm_agumon_VANILLA_*`（正常但拉长）/ `czx_dgm_agumon_CHR_*`（正常且合身）。
- **damp 三件套复验**：plesiomon（tail/neck damp）三剪辑连贯 ✅——damp 对「链过长摆幅过大」有效；birdramon/hououmon 仍 ❌——其根因是**翼骨 bind 尺寸与 mesh 收翼不匹配**（L2 翼骨出网格 3-4x），属 fit_skeleton 几何问题，damp 旋钮压不住。biyomon 同型。
- **alphamon**：L1✅ L2✅ 但 L3 hu1 系前倾 ~45°/拧转 ❌——大体型 biped 无 damp 一样失真。
- **推荐修复路线（综合）**：主线走 **chr 原生剪辑**（50/104 有源，语义正确、原型已验证），每 chr 单位需要 skel_chr###.json（dump_chr_skel.py 已有）+ czx→chr bonemap（chr_clips 有样例可半自动生成）+ 剪辑槽位映射（chr ~8-15 剪 vs WH3 ~40 槽，可复用）；无 chr 源的 54 只回退「修 retarget_delta/补 damp」或继续 vanilla man_animation。骨架 fit 失配（翼骨>mesh）是独立缺陷，无论走哪条路线都要修 3 只鸟的 fit。
- L4 仍跳过：Warhammer3.exe 运行中。

### iter 3 — agumon chr 端到端原型 + 灰度方案 + L4 初探

- **结构对比**：chr050.bin（947B）极简——8 剪辑 12 槽位引用（idle/move/damage/down/getup/guard/win/eat）；czx_dgm_agumon_emp_sws1.bin（107KB）= hu1 完整套件克隆，95 条 `animations/battle/czx_agumon/**.anim` 槽位路径横跨 14 类（attacks13/deaths15/knockdown14/reactions8/locomotion8/movement6/defends6/jumps_falls7/stand4/knockback4/combat_idles3/celebrate3/shield_up2/porthole2）。
- **原型产出**（`scratch/model_check/digimon/proto_agumon/`）：chr050 8 剪辑经 `retarget_bonemap.py`+`bonemap_czx2chr050.json`（czx→chr 24 骨映射）→ `anims/chr_*.anim`（skeleton_name=czx_agumon，v8）→ blender 渲 GIF **8/8 全合身正常**（idle 站姿呼吸 / move 自然步态 / damage 受击后仰 / down 倒地 / getup 爬起 / guard 抱臂格挡 / win 跳举庆祝 / eat 前扑咬=attack 语义）。
- **graft 资产**：`build_graft.py` 生成 95 槽位 .anim 全覆盖映射（attacks→eat、locomotion/movement/shield_up→move、stand/idles/porthole→idle、defends→guard、knockback/reactions→damage、knockdown/deaths/falls→down、getup→getup、celebrate→win）+ `zzz_dgm_agumon_only.animpack`（单 bin，inner==stem==DB key）+ `ACTIVATION.txt`（步骤+回滚）。
- **灰度可行性 ✅**：`land_units.man_animation` 按单位选套件——只改 agumon 一行（hu1_empire_sword_and_shield→czx_dgm_agumon_emp_sws1）即可单单位启用；`battle_animations_table` key→skeleton 行已存在；`culture_to_battle_animation` 是 animset↔culture 白名单（2912 行 = 104 key × 28 culture pack + cathay 行），不驱选择、不波及其他单位；animpack 只含 agumon bin，其余 103 套件不注册。**激活三件套未进源**（等主会话放行再落 mod_files）。
- **L4 初探**（游戏已退）：digimon-only 场景（6 只：agumon/wargreymon/guilmon/garurumon/seadramon/biyomon，`--mods packs:zzz_czx_digimon_v2.pack`）**init 通过**、120s 存活无 dump——vanilla-man_animation 现役包游戏内可初始化（stretched-sane 假设的 init 侧实证）。二跑出现 crash-report 窗口（flaky init，进程活着但窗口名 Crash report）。**满 playset（215 mod）两连崩于 Warhammer3.exe+0x538a0a（0xc0000005 exec-fault），与会话前 13:18 崩溃同址——跨 mod 环境性崩溃，digimon 包单独无责**。截图取证失败（战斗窗口离屏/最小化，只抓到桌面）。
- 遗留：graft 未入源；attack 槽暂用 eat（咬合前扑）——chr050 无专用 attack 剪辑；鸟系三只 fit 失配（翼骨>mesh）待修 fit_skeleton。

### iter 4 — agumon 灰度激活已部署 + 批量 chr 管线开工（L4 环境阻塞）

- **graft 落源+部署 ✅**：proto_agumon/graft/ 的 95 槽 .anim 落到 `mod_files/zzz_czx_digimon_v2/animations/battle/czx_agumon/`（覆盖同路径），`zzz_dgm_agumon_only.animpack` 落 `animations/database/battle/bin/`；land_units 仅 agumon 行 man_animation→`czx_dgm_agumon_emp_sws1`（包内二进制行已验证，邻近单位仍 hu1_empire_sword_and_shield）。`build_pack.py --deploy` 完成：mod_output 与 data\ 包 sha256 一致（296MB/10798 文件），battle_animations_table 行已在包内。首次 deploy 撞上 swarm leader 的 L4 测试进程占包锁（zz_psw_only.txt/zz_r2_a.txt 脚本参数拉起、Crash report 残留的僵尸窗），等其自然释放后二次 deploy 成功。
- **L4 三连拉起全部崩溃（环境阻塞，非 graft 归因）**：3 次 digimon-only battle 拉起均在极早期（script log 尚未写）弹 "Crash report" 窗口；已有 dump 全部同址 `Warhammer3.exe+0x538a0a`（0xc0000005），今日 7 连崩横跨 digimon-only/swarm-only/满 playset/部署前旧包——游戏更新后任意拉起即崩，**判定游戏环境损坏/更新后不稳**，与 graft 无因果。工具坑：battle_autotest 的存活判定被 crash-report 窗口骗过（pid 未退→误报 alive），另发 `_fgshot2.ps1` 前台强制+截图证实窗口真身是 Crash report。留 data\ 的 battle xml 已清理。
- **批量管线 `scratch/model_check/digimon/batch_chr.py` 建成 ✅**：`chr_map_full.json`（v1 land_units 48 条为权威 assignment + GLB 名 chr### 补齐 + EN/JP 别名表 12 条；direct donor 33 只 / chr 源但无 animset 53 只 / 无 chr 源 18 只）。逐单位自动：`skeletons/chr###.anim`(v7) → donor skel json → J 骨名语义分类（EN+罗马字+错拼词表，四足 B_/F_ 前后肢链、双臂、翼、尾链）→ 我方模板槽位按链位置对齐生成 bonemap → `retarget_bonemap.py` 逐剪辑重定向 → blender 渲 6 帧/关键剪辑 + gif + report.json。
- **试跑 4 只全过（视觉合身）**：garurumon←chr012（quad↔quad：后肢 B 链/前肢 F 链/脊/尾 1:1，34/42 骨）8/8 剪辑；greymon←chr326（biped，62/72）9/9；gabumon←chr151（双臂 donor，62/72，右臂 hand→J_hand2_r 因 donor 缺 J_hand1_r）7/7；biyomon←chr307（bird 95/95 全映射：wing→J_hane1/2、12 尾骨折叠到单 J_sippo1_L、toes→tumasaki）11/11 含 attack01/attack02（chr307 自带动攻击剪辑——**部分 donor 有真 attack 剪辑，非全靠 eat 顶替**）。GIF 在 `Temp\modelcheck\digimon\iter4\{garurumon,biyomon,greymon,gabumon}\`。
- **chr 剪辑目录差异**：donor 剪辑集不均（chr012=8 基础、chr326=9 含 glad、chr307=11 含 attack01/02/special01、chr004=含 attack01/02/anim_n/field）——graft 槽位映射需按 donor 实际清单生成（attacks 槽优先 attack\*/special，缺则 eat）。
- 遗留：agumon L4 待环境恢复后复核（graft 是否被引擎正常吃）；53 只 chr-in-GLB-无-animset + 18 只无 chr → 族内 donor 分配待做；鸟系 fit 失配仍是独立几何缺陷；graft 自动化（按 bin 槽位映射）未写。
- 下一步计划：迭代 5 = 先复核 agumon L4（环境恢复后）→ batch_chr 全量 33 只 direct-donor → 族 donor 表（53+18）→ graft 自动化 + 分批灰度。
### iter 5 — batch_chr 全量 33 只 direct-donor 跑通 + 批1（12只）落源部署；L4 仍环境阻塞

- **全量批跑 ✅**：33/33 direct-donor 单位完成 bonemap→retarget→GIF 验收帧（`scratch/model_check/digimon/batch_chr/<unit>/`，montage 验收图在 `montage/` + `Temp\modelcheck\digimon\iter5\`）。逐目检视全部合身：无炸顶点、无穿地、姿态语义正确（idle 站/move 走/win 抬头/down 倒地）。映射覆盖率 21/72（alphamon←chr416 极简骨架）~95/95（biyomon←chr307），未映射骨均为道具/细节骨（be_prop_*、手指细分、尾甲），跟随父骨安全。
- **分类器三次升级**（已入 batch_chr.py）：前缀侧位 `J_L_leg`/`J_Lude`（chr140/343/344/359）、小写 quad `J_b_leg_l`（chr548 翼四足）、3dsMax `Bip001 L Thigh` 命名（g133/u133 池）。修后 gomamon 11→45 骨、weregarurumon 26→62、ikkakumon 13→35 并全部 GIF 复验通过。
- **graft 通用化 `graft_batch.py` ✅**：v1 模板 bin（`scratch/dgm_plus_pkm_src/.../bin/czx_dgm_<unit>_<fam>.bin`，104 个全在）→ 扫描 `animations/battle/<该单位skel>/` 槽位 → 语义 MAP 填重定向剪辑（attacks 优先 attack*/special 轮换，缺则 eat→damage→idle 降级；refuses/faces/transitions/docking/subset/resurrect/rebirth/missile_actions/rider 等异族槽位全覆盖）；**异骨架路径（humanoid01 rider 槽 166 条）原样保留指 vanilla**。批1 十一只全部槽位满填：emp_sws1 系 95/95、wf1_wolf 43/43、bi1_eagl 68/68。
- **批1 部署 ✅（12 只）**：agumon + gabumon/gomamon/greymon/metalgreymon/wargreymon（emp_sws1）+ garurumon/metalgarurumon/plotmon（wf1_wolf）+ biyomon/birdramon（bi1_eagl）+ dorumon（emp_sws1）。`pack_animsets.py` 合并 12 bin → `zzz_dgm_chr_native.animpack`（813KB，stem==inner 全 OK，替换掉 zzz_dgm_agumon_only）；land_units 11 行 man_animation 切 `czx_dgm_*` key；`build_pack --deploy` 成功（312MB/10810 文件，mod_output==data sha256 `321f5b35…`，playset pos 92，包内抽查 key 各 35 处）。其余 92 只仍 vanilla。
- **L4 本轮跳过（环境阻塞）**：Basic Render Driver + `Warhammer3.exe+0x538a0a` 环境级连崩未恢复；agumon L4 复核同步挂起。台账 L4 列统一记 ⏭环境阻塞。
- **53 只 mesh-only + 18 只无 chr 处置方案**：见文末附录表。要点——(a) 族内 donor 借用为主：biped 池 19 个 extracted animset 按体型分 rookie/champion/mega 档；翼系分 bird（chr307/308）/winged-angel（chr039/446/101/094）/winged-dragon（chr019/400/229/209/208）三池；quad 池 chr012/135/361 + 翼龙 quad chr548；(b) **4 只 serpent 无蛇形 donor → 维持 vanilla sn1_serpent**（原生蛇形套件本来就合身）；(c) insect 4 只试 chr359（winged-biped 带 canon/hane，11 剪辑含 attack/special）；(d) tinkermon 源 GLB g133 的 animset 其实已抽取（Bip001 骨架本轮已支持）→ 准 direct；imperialdm/jetsilphymon 试 u133。全部族 donor 借用仍需逐只 GIF 验收后才许落源。
- **下一步计划**：迭代 6 = 环境恢复后补批1 L4 → 批2 落源剩余 21 只 direct-donor（已全验过，纯 graft+部署）→ 族 donor 试跑先行样本（tinkermon←g133、kyubimon←chr012、magnadramon←chr548、megakabuterimon←chr359、imperialdm←u133）→ 视验收推 53+18。鸟系 fit 失配（翼骨 bind 展翼 vs mesh）仍是独立几何缺陷，挂 fit_skeleton。

#### 附录A：53 只 mesh-only-chr + 18 只无源 处置方案（iter5 规划，未动手）

| unit | stage/form | 源 | 类别 | 建议donor | 方案说明 |
|---|---|---|---|---|---|
| czx_dgm_palmon | biped | chr348 | mesh-chr | chr050 | rookie biped→agumon donor |
| czx_dgm_guilmon | biped | chr090 | mesh-chr | chr050 | rookie biped→agumon donor |
| czx_dgm_renamon | biped | chr391 | mesh-chr | chr050 | rookie biped→agumon donor |
| czx_dgm_veemon | biped | chr114 | mesh-chr | chr050 | rookie biped→agumon donor |
| czx_dgm_lalamon | biped | chr056 | mesh-chr | chr050 | rookie biped→agumon donor |
| czx_dgm_sunflowmon | biped | chr058 | mesh-chr | chr050 | rookie biped→agumon donor |
| czx_dgm_zubamon | biped | chr697 | mesh-chr | chr050 | rookie biped→agumon donor |
| czx_dgm_gatomon | biped | chr092 | mesh-chr | chr326 | champion biped→greymon donor |
| czx_dgm_growlmon | biped | chr078 | mesh-chr | chr326 | champion biped→greymon donor |
| czx_dgm_geogreymon | biped | chr054 | mesh-chr | chr326 | champion biped→greymon donor |
| czx_dgm_tyranomon | biped | chr363 | mesh-chr | chr326 | champion biped→greymon donor |
| czx_dgm_veemonex | biped | chr365 | mesh-chr | chr326 | champion biped→greymon donor |
| czx_dgm_vritramon | biped | - | no-src | chr326 | 人形斗士→greymon biped |
| czx_dgm_duramon | biped | chr699 | mesh-chr | chr326 | champion biped→greymon donor |
| czx_dgm_zudomon | biped | chr345 | mesh-chr | chr326 | champion biped→greymon donor |
| czx_dgm_wargrowlmon | biped | - | no-src | chr019 | 大古拉→翼龙 biped donor |
| czx_dgm_rizegreymon | biped | chr071 | mesh-chr | chr326 | champion biped→greymon donor |
| czx_dgm_paildramon | biped | chr408 | mesh-chr | chr326 | champion biped→greymon donor |
| czx_dgm_skullgreymon | biped | chr404 | mesh-chr | chr326 | champion biped→greymon donor |
| czx_dgm_lilamon | biped | chr073 | mesh-chr | chr326 | champion biped→greymon donor |
| czx_dgm_taomon | biped | chr405 | mesh-chr | chr326 | champion biped→greymon donor |
| czx_dgm_blitzgreymon | biped | chr689 | mesh-chr | chr027 | mega/boss biped→wargreymon donor |
| czx_dgm_durandamon | biped | chr700 | mesh-chr | chr027 | mega/boss biped→wargreymon donor |
| czx_dgm_machinedramon | biped | chr385 | mesh-chr | chr027 | mega/boss biped→wargreymon donor |
| czx_dgm_chaosdramon | biped | chr422 | mesh-chr | chr027 | mega/boss biped→wargreymon donor |
| czx_dgm_sakuyamon | biped | chr425 | mesh-chr | chr027 | mega/boss biped→wargreymon donor |
| czx_dgm_rosemon | biped | chr057 | mesh-chr | chr027 | mega/boss biped→wargreymon donor |
| czx_dgm_rosemonbm | biped | chr779 | mesh-chr | chr027 | mega/boss biped→wargreymon donor |
| czx_dgm_vikemon | biped | chr346 | mesh-chr | chr027 | mega/boss biped→wargreymon donor |
| czx_dgm_fujinmon | biped | - | no-src | chr027 | 人形 mega→wargreymon |
| czx_dgm_wargreymonx | biped | chr110 | mesh-chr | chr027 | mega/boss biped→wargreymon donor |
| czx_dgm_shinegreymonbm | biped | - | no-src | chr094 | →shinegreymon 同种 |
| czx_dgm_omegamonx | biped | - | no-src | chr088 | →omegamon 同种 |
| czx_dgm_omegamonab | biped | - | no-src | chr448 | alter→omegamonm 翼版 |
| czx_dgm_omegamonas | biped | - | no-src | chr448 | alter-s→omegamonm |
| czx_dgm_gallantmonx | biped | chr358 | mesh-chr | chr027 | mega/boss biped→wargreymon donor |
| czx_dgm_jesmonx | biped | chr468 | mesh-chr | chr027 | mega/boss biped→wargreymon donor |
| czx_dgm_magnamon | biped | - | no-src | chr416 | 金甲→alphamon knight |
| czx_dgm_magnamonx | biped | chr432 | mesh-chr | chr027 | mega/boss biped→wargreymon donor |
| czx_dgm_imperialfm | biped | chr419 | mesh-chr | chr027 | mega/boss biped→wargreymon donor |
| czx_dgm_imperialpm | biped | chr420 | mesh-chr | chr027 | mega/boss biped→wargreymon donor |
| czx_dgm_mastemon | biped | chr748 | mesh-chr | chr027 | mega/boss biped→wargreymon donor |
| czx_dgm_zeedmillennium | biped | chr230 | mesh-chr | chr027 | mega/boss biped→wargreymon donor |
| czx_dgm_apocalymon | biped | chr328 | mesh-chr | chr027 | mega/boss biped→wargreymon donor |
| czx_dgm_susanoomon | biped | - | no-src | chr105 | 武神→gallantmoncm knight |
| czx_dgm_patamon | flyer | chr096 | mesh-chr | chr307 | 小飞兽→鸟 donor |
| czx_dgm_tentomon | insect | - | no-src | chr359 | insectoid donor 试 |
| czx_dgm_tinkermon | flyer | - | no-src | g133 | GLB 源 g133 animset 已抽取(Bip001) |
| czx_dgm_angemon | flyer | chr087 | mesh-chr | chr039 | 天使人形→lucemonfm |
| czx_dgm_kabuterimon | insect | - | no-src | chr359 | insectoid donor 试 |
| czx_dgm_kyubimon | quadruped | chr395 | mesh-chr | chr012 | 九尾狐→garurumon quad |
| czx_dgm_seadramon | serpent | chr347 | mesh-chr | - | serpent 无 donor→vanilla |
| czx_dgm_zubaeagermon | flyer | chr698 | mesh-chr | chr308 | 刃鸟→birdramon |
| czx_dgm_fairymon | flyer | - | no-src | chr039 | 妖精人形→winged-angel |
| czx_dgm_garudamon | flyer | chr309 | mesh-chr | chr308 | 大鸟→birdramon |
| czx_dgm_angewomon | flyer | chr148 | mesh-chr | chr039 | 天使→lucemonfm |
| czx_dgm_megakabuterimon | insect | chr305 | mesh-chr | chr359 | insectoid donor 试 |
| czx_dgm_lilimon | flyer | - | no-src | chr039 | 妖精人形→winged-angel |
| czx_dgm_megaseadramon | serpent | chr132 | mesh-chr | - | serpent→vanilla |
| czx_dgm_jetsilphymon | flyer | - | no-src | u133 | u147→最近 u133(Bip001) |
| czx_dgm_cresgarurumon | quadruped | - | no-src | chr135 | quad→metalgarurumon donor |
| czx_dgm_metalseadramon | serpent | chr434 | mesh-chr | - | serpent→vanilla |
| czx_dgm_plesiomon | serpent | chr450 | mesh-chr | - | serpent→vanilla |
| czx_dgm_heraklekabuterimon | insect | chr306 | mesh-chr | chr359 | insectoid donor 试 |
| czx_dgm_magnadramon | quadruped | chr453 | mesh-chr | chr548 | 圣龙 quad+翼→winged-quad |
| czx_dgm_hououmon | flyer | chr310 | mesh-chr | chr308 | 凤凰→bird |
| czx_dgm_metalgarurumonx | quadruped | chr108 | mesh-chr | chr135 | 同种→metalgarurumon donor |
| czx_dgm_imperialdm | flyer | - | no-src | u133 | u152→u133；或 chr019 翼龙 |
| czx_dgm_ophanimon | flyer | chr421 | mesh-chr | chr446 | →ophanimonfm donor |
| czx_dgm_lucemon | flyer | chr390 | mesh-chr | chr039 | →lucemonfm 同种 |
| czx_dgm_omegamond | biped | - | no-src | chr088 | 兹瓦特→omegamon |
### iter 6 — 批2（21只）落源部署完成，33 只 direct-donor 全部灰度激活；族 donor 试跑 5/5 过；L4 前端二分亦环境阻塞

- **批2 部署 ✅（21 只，累计 33/33 direct-donor）**：togemon/veedramon/metaltyranomon/shinegreymon/omegamon/omegamonm/gallantmon/gallantmoncm/alphamon/jesmon/ulforcev/ulforcevx/lucemonfm/ikkakumon/dorugamon/magnaangemon/aerovdramon/dorugoramon/seraphimon/ophanimonfm/weregarurumon。graft_batch 修两坑后全满填：(a) 单 attack 剪辑时 `attacks/` 轮换分支不触发（`len>1` 才轮换的笔误）→ 任意长度轮换；(b) donor 缺 idle/win 槽级联空转 → 全槽位语义降级链（idle→anim_n/field/guard→move→win，win→glad→idle，down→damage，move→field→idle 等）。**emp_sws1 95/95、wf1_wolf 43/43、bi1_eagl 68/68，全 21 只零 unmapped**。
- **合并 animpack 33 bin**：`pack_animsets.py` 重打 `zzz_dgm_chr_native.animpack`（2.97MB，33 bin 全 stem==inner OK）；land_units 再切 21 行（脚本按 bin stem 自动配 key，共 33 行 czx_dgm_* 激活）。`build_pack --deploy`：357MB/10831 文件，mod_output==data sha256 `2095a1bb…`，playset pos 101，包内 key 抽查命中。**剩余 71 只仍 vanilla**（53 mesh-chr + 18 no-src，见附录A处置表）。
- **族 donor 试跑 5/5 合格（批3 名单锁定）**：tinkermon←**g133**（Bip001 骨架 49/72 骨，4/4 剪辑——GLB 源 animset 直用）；kyubimon←**chr012**（族 quad 34/42，8/8：idle 站姿/move 迈步/win 仰首/down 侧倒全合身）；magnadramon←**chr548**（翼四足 34/42，12/12：圣龙四足+翼同构——appendix 验证最硬的一条）；megakabuterimon←**chr359**（insectoid 46/74，11/11：独角仙甲虫姿态正）；imperialdm←**u133**（Bip001 半 biped 37/72，8/8：龙形态前臂无 donor 链跟父骨仍自然）。验收图 `Temp\modelcheck\digimon\iter5\czx_dgm_{tinkermon,kyubimon,magnadramon,megakabuterimon,imperialdm}.png`。
- **L4 环境阻塞（证据链更新）**：今日另一会话已定位 `+0x538a0a` 真凶=zz_diag_junction.pack（移出 playset）；GPU 侧 `gfx.log` 已恢复 RTX 2070（Basic Render Driver 消失）。但新签名 `+0x4e5b30` 出现：本会话探针 digimon-only（15:39）与**纯 vanilla 空 modlist（15:44）同址复现**，且其他会话的前端 modlist 拉起（zz_e1，含本包）同址——**两条拉起路径都被 +0x4e5b30 打死，vanilla 控制组复现=与本包无关**。判定 L4 继续挂起；`game_startup_mode battle` autotest 在 9.0 上 vanilla 也死（+0x1a957e7），前端二分法（挂载完停在 press-any-key + modified.log/mp_log.txt 判据）为下轮正解，本轮因并发会话残留 crash 进程（zz_e1）+连崩未拉。
- **骨架名对齐修正**：全量比对 `skel_*.json.skeleton_name` vs `battle_animations_table` 注册骨架发现唯一不一致 = dorugoramon（skel json `czx_dorug` / 注册 `czx_dorug0`）——剪辑内嵌骨架名与注册名不符。已给 skel json 加 `custom_name=czx_dorug0` 重跑 batch+graft，剪辑内嵌名已对齐；最终部署包 sha `1943f896`（含修正，357MB/10831 文件）。
- **下一步**：iter7 = 批3 落源 5 只族 donor 合格品（tinkermon/kyubimon/magnadramon/megakabuterimon/imperialdm 已备好 bin+剪辑，graft+deploy 即可）→ 前端二分 L4（zz_diag_junction 已除，待 +0x4e5b30 消退或定位）→ 53 只 mesh-chr 按附录A池化分批跑 batch_chr --donor → 视情况给 serpent/insect 补位。
### iter 7 — 批3（5只族 donor）落源部署 + mesh-chr biped 组试跑 15/15 全过

- **批3 部署 ✅（累计 38 只激活）**：tinkermon←g133(Bip001)/kyubimon←chr012/magnadramon←chr548/megakabuterimon←chr359/imperialdm←u133，graft 全满填（emp_sws1 95/95、wf1_wolf 43/43、sp1_spid 35/35）。骨架名一致性预检通过（skel json == battle_animations_table == 剪辑内嵌名，5/5 OK——iter6 dorugoramon 教训已制度化）。`pack_animsets.py` 重打 38-bin animpack（3.2MB）；land_units 再切 5 行；`build_pack --deploy` 成功：370MB/10836 文件，sha `b13ece55`，mod_output==data 一致。**激活数 38/104，剩余 66 只 vanilla。**
- **mesh-chr biped 组试跑 15/15 合格（批4 名单）**：veemon/gatomon/palmon←chr050、renamon←chr151、growlmon/geogreymon/skullgreymon←chr326、tyranomon/machinedramon←chr364、veemonex←chr397、zudomon←chr344、wargreymonx←chr027、gallantmonx←chr013、jesmonx←chr749、magnamonx←chr416——优先同种/同族 donor。逐张 montage 验收全合身，无炸顶点/穿地/塌身。映射 21/72（magnamonx←chr416 极简）~64/72（jesmonx）。验收图 `Temp\modelcheck\digimon\iter7\`。**无系统性失真模式，池化方案放量安全。**
- **L4 继续环境阻塞**：`+0x4e5b30` 全路径连崩未消退（截至 16:06 已 10 连同址，含 vanilla 空 modlist 控制组）。前端二分判据备好（拉起 modlist→press-any-key 存活+modified.log/mp_log.txt 条数），待环境恢复执行。
- **下一步**：iter8 = 批4 落源 15 只 biped 合格品 → mesh-chr 继续放量：biped 剩余 ~22 只（按池化表 chr050/151/326/349/364/140/027/088/105/416/749/213 分档）→ flyer 组（bird/angel/dragon 三池）→ quad 剩余（kyubimon 外的 quad 已验 chr012 可行）→ insect 补位（chr359 已证）→ serpent 4 只维持 vanilla 收场。无 chr 源 18 只按附录A借用方案同流。
