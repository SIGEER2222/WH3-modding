STATUS: DONE（104/104 结论清零：100 只 chr 原生激活 + 4 只 serpent 维持 vanilla 通过；鸟系 3 只 bind-fit 已重修部署✅；L4 全行⏭环境阻塞待复核；❌/🔧 清零）

# 数码宝贝 v2 模型检验台账（leader: digimon）

范围：`mod_files/zzz_czx_digimon_v2/` → 部署包 `zzz_czx_digimon_v2.pack`（playset pos100，mod_id `local:data:6d429f74a958fd64f5`）

## 全局状态（2026-09-25 iter1 基线）

- **文件链 104/104 齐**：vmd→wsmodel→rmv2→material→dds 全链存在；RMV2 内嵌骨架名 == battle_skeletons.name == 骨架目录名（czx_*）。见 `scratch/model_check/digimon/l0_report.tsv`。
- **DB 行 104/104 齐**：main/land/unit_variants/variants/battle_animations_table/battle_skeletons/custom_battle_permissions/loc（name+short+hist）全在；audit_dangling_refs 0 ERROR（104 WARN 全部是 `wh3_main_cth_the_northern_provinces` 已知误报）。
- ⚠ **animset 注册层整体缺失**：源码 `animations/database/battle/bin/` 为空，pack 内无 `animations/database/` 子树（无 bin 无 animpack）。当前 `land_units.man_animation` 全部指向 vanilla 族套件（hu1_empire_sword_and_shield×83 / wf1_dire_wolf×9 / sn1_sepulchral_stalker_halberd×5 / sp1_giant_spider×4 / bi1_eagle×3，2026-09-24 13:07 改动），czx_dgm_*_suffix 动画 key 仅被 battle_animations_table/culture 表引用——自定义套件资产（9021 clips + 104 骨架 + bins）目前是休眠层。
- iter2 animpack 解剖结论（`scratch/model_check/digimon/animpack_audit.py`）：`scratch/zzz_czx_digimon_v2_animsets.animpack.broken` **格式完好**（104 条、无尾字节）、**内部套件名==stem==DB key**（czx_dgm_*_suffix，已是正确命名约定，非 vanilla donor 名）、bin 内引用 `animations/skeletons/czx_*.anim`+`reference_poses/` 正确；且与 `scratch/dgm_plus_pkm_src/animations/database/battle/bin/` 备份 **104/104 逐字节相同**。"broken" 名不符实——格式/命名都对，被弃的真实原因是**剪辑内容畸形**（L3 实测），9-24 拔除+改 vanilla man_animation 属止损。修好剪辑后直接把这 104 bin 回源/重打 animpack 即可，无需改名手术。
- ⚠ **unit_set_to_unit_junctions 全空**（仅表头）：104 只无 unit_set 归属——自定义战斗选人界面分类页签可能不显示它们（units_custom_battle_permissions 已在，全派系行齐）。待确认影响。
- ✅ **be_prop 轨道修复（2026-09-26 iter13）**：grafted 剪辑 `be_prop_*` 原全静态钉原点，已按 CA 惯例补写（`scratch/fix_beprop_tracks.py` 全动态 + `fix_beprop_tracks_dyn.py` 压缩剪辑重建）。映射 0/1→hand_right、2→hand_left、3→spine_2、4→root、5→hand_left；`L_prop=inv(W_animroot)⊗W_driver`（animroot 有 X180° 常量翻转）。全量 9496 剪辑 ok=8765/no-prop=731/other=0；799 个压缩剪辑（czx_meg/met/ple/sea/dorugo/omega0/shine0/veemo0/wargr0）重建为全动态。抽样 140 剪辑归一化 FK 逐帧零偏差、四元数半球连续、非 prop 通道保真（0 pos/0.003° rot）。**坑**：压缩编码解出非单位 quat（|q|=1.0011）会在 q·v·conj(q) 上按 |q|² 缩放——FK 前必须归一化。包已重建（533MB，+42MB 因 799 剪辑全动态化），部署挂 `scratch/deploy_digimon_when_free.sh` 等 WH3 退出。注意：轨道≠挂载，武器要显示仍需 VMD SLOT attach_point。
- Warhammer3.exe 运行中 → L4 全跳过（「待游戏窗口」）。

## 单位台账

| unit | cn | stage | form | animset(man_animation) | skel | L0 | L1 | L2 | L3 | L4 | 问题/修复 | 状态 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| czx_dgm_agumon | 亚古兽 | rookie | biped | **czx_dgm_agumon_emp_sws1** | czx_agumon | ⚠缺bin层 | ✅ | ✅内收 | ✅chr原生GIF | ⏭环境阻塞 |**iter4 灰度已部署**：95 槽 chr050 重定向 .anim + `zzz_dgm_agumon_only.animpack`（inner==stem==DB key）入源，land_units 单行 man_animation 切 `czx_dgm_agumon_emp_sws1`，重打包 sha 一致、包内 DB 行已验证；其余 103 只仍 vanilla。L3=chr 8 剪辑 GIF 全合身。L4：三连拉起全部 `+0x538a0a` crash-report（环境级，全日 7 次同址含 swarm/满 playset/本包，非 graft 归因；crash 对话框保活 pid 导致 autotest 误报 alive）；iter5：bin 原样并入 12-bin zzz_dgm_chr_native.animpack（payload 仍是 proto graft 版），batch_chr 自动 bonemap 62/72骨复跑 GIF 亦合身；L4环境阻塞待复核 | 🔧已部署待L4 |
| czx_dgm_gabumon | 加布兽 | rookie | biped | **czx_dgm_gabumon_emp_sws1** | czx_gabumo | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 |iter4 批量管线：chr151（双臂 donor）自动 bonemap 62/72 骨，7/7 剪辑 GIF 合身；idle/move/down/win 验收帧正常；iter5批1已部署：chr151 bonemap 62/72骨 7剪辑全OK→graft 槽位满填，GIF合身 | 🔧已部署待L4 |
| czx_dgm_biyomon | 比丘兽 | rookie | flyer | **czx_dgm_biyomon_bi1_eagl** | czx_bi | ⚠缺bin层 | ✅ | ✅翼骨已重配 | ✅chr原生GIF | ⏭环境阻塞 |bird01 骨架 bind 展翼 vs mesh 收翼，翼骨伸出网格 3-4x；fly_walk 翅膀被拉成平板帆、attack 成扇形——骨架 fit 需按收翼重配翼链；iter4 chr307 原生管线 95/95 骨全映射（wing→J_hane、tail→J_sippo 折叠到单骨），11/11 剪辑 GIF 合身；iter5批1已部署：chr307 bonemap 95/95骨 11剪辑全OK→graft 槽位满填，GIF合身 【iter11 已修】skin-权重质心 landmarks（wing/feather/tail 14 骨）→ fit_skeleton 重配 bind（拓扑/骨名/权重不变）→ batch_chr chr307 重跑 95/95 骨 11/11 剪辑→graft 68/68→deploy sha 60ad37ab。蒙皮顶点 LBS 采样 idle/move/attack01 max_r≤1.05（≈1×体型）无 NaN；overlay 三视图+top 已渲（iter11_overlay_*.png）。远距 feather 骨为未蒙皮装饰骨不驱动顶点| ✅fit已修(部署) |
| czx_dgm_patamon | 巴达兽 | rookie | flyer | **czx_dgm_patamon_wf1_wolf** | czx_pa | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter9 flyer试跑：chr307(bird) bonemap 42/42骨 11剪辑GIF合身；iter10批6已部署（95-bin animpack） | 🔧已部署待L4 |
| czx_dgm_gomamon | 哥玛兽 | rookie | biped | **czx_dgm_gomamon_emp_sws1** | czx_gomamo | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批1已部署：chr343 bonemap 45/72骨 12剪辑全OK→graft 槽位满填，GIF合身 | 🔧已部署待L4 |  |
| czx_dgm_palmon | 巴鲁兽 | rookie | biped | **czx_dgm_palmon_emp_sws1** | czx_palmon | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter7 biped试跑：chr050 bonemap 62/72骨 8剪辑GIF合身；iter8批4已部署（53-bin animpack） | 🔧已部署待L4 |
| czx_dgm_tentomon | 甲虫兽 | rookie | insect | **czx_dgm_tentomon_sp1_spid** | czx_tent | ⚠缺bin层 |  |  |  | ⏭环境阻塞 | ；iter10批7已部署（100-bin animpack） | 🔧已部署待L4 |
| czx_dgm_guilmon | 基尔兽 | rookie | biped | **czx_dgm_guilmon_emp_sws1** | czx_guilmo | ⚠缺bin层 | ✅ | ✅内收 | ✅chr原生GIF(族donor) | ⏭环境阻塞 | L3 walk 前俯驼背、attack 双臂拉成红条、death 整体拉伸；同 agumon 的 hu1 retarget 失真；iter8 biped放量：chr050 bonemap 62/72骨 8剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |
| czx_dgm_renamon | 妖狐兽 | rookie | biped | **czx_dgm_renamon_emp_sws1** | czx_renamo | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter7 biped试跑：chr151 bonemap 62/72骨 7剪辑GIF合身；iter8批4已部署（53-bin animpack） | 🔧已部署待L4 |
| czx_dgm_dorumon | 多路兽 | rookie | quadruped | **czx_dgm_dorumon_emp_sws1** | czx_dorumo | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批1已部署：chr112 bonemap 47/72骨 5剪辑全OK→graft 槽位满填，GIF合身 | 🔧已部署待L4 |  |
| czx_dgm_plotmon | 小狗兽 | rookie | quadruped | **czx_dgm_plotmon_wf1_wolf** | czx_pl | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批1已部署：chr361 bonemap 37/42骨 5剪辑全OK→graft 槽位满填，GIF合身 | 🔧已部署待L4 |  |
| czx_dgm_veemon | v仔兽 | rookie | biped | **czx_dgm_veemon_emp_sws1** | czx_veemon | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter7 biped试跑：chr050 bonemap 62/72骨 8剪辑GIF合身；iter8批4已部署（53-bin animpack） | 🔧已部署待L4 |
| czx_dgm_lalamon | 拉拉兽 | rookie | biped | **czx_dgm_lalamon_emp_sws1** | czx_lalamo | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter8 biped放量：chr050 bonemap 62/72骨 8剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |
| czx_dgm_sunflowmon | 向日葵兽 | rookie | biped | **czx_dgm_sunflowmon_emp_sws1** | czx_sunflo | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter8 biped放量：chr050 bonemap 62/72骨 8剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |
| czx_dgm_tinkermon | 叮克兽 | rookie | flyer | **czx_dgm_tinkermon_emp_sws1** | czx_tinker | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter6 族donor试跑：g133(Bip001) bonemap 49/72骨 4剪辑GIF合身；iter7批3已部署（38-bin animpack） | 🔧已部署待L4 |
| czx_dgm_zubamon | 兹巴兽 | rookie | biped | **czx_dgm_zubamon_emp_sws1** | czx_zubamo | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter8 biped放量：chr050 bonemap 62/72骨 8剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |
| czx_dgm_greymon | 暴龙兽 | champion | biped | **czx_dgm_greymon_emp_sws1** | czx_greymo | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 |iter4 批量管线：chr326 自动 bonemap 62/72 骨，9/9 剪辑 GIF 合身；idle/move/win/down 验收正常；iter5批1已部署：chr326 bonemap 62/72骨 9剪辑全OK→graft 槽位满填，GIF合身 | 🔧已部署待L4 |
| czx_dgm_garurumon | 加鲁鲁兽 | champion | quadruped | **czx_dgm_garurumon_wf1_wolf** | czx_ga | ⚠缺bin层 | ✅ | ✅内收 | ✅chr原生GIF | ⏭环境阻塞 |L3 walk/attack/death 全部蜷缩变形（头折进胸腔、腿互绞、鬃毛件漂浮）；quad 族 retarget 失真；iter4 chr012 原生管线 34/42 骨（clav/finger 无映射=跟随父骨），8/8 剪辑 GIF 合身（idle/move/down/win 验收正常）；iter5批1已部署：chr012 bonemap 34/42骨 8剪辑全OK→graft 槽位满填，GIF合身（❌为旧 vanilla retarget 结论，chr 原生已验收部署）| 🔧已部署待L4 |
| czx_dgm_birdramon | 巴多拉兽 | champion | flyer | **czx_dgm_birdramon_bi1_eagl** | czx_b0 | ⚠缺bin层 | ✅ | ✅翼骨已重配 | ✅chr原生GIF | ⏭环境阻塞 |已有 RETARGET_DAMP 仍压不住：fly_walk 翼面拖拽、attack 蜷缩、death_fall 塌扁；根因是翼骨 bind 尺寸远超 mesh（几何失配，非摆幅问题）；iter5批1已部署：chr308 bonemap 82/95骨 11剪辑全OK→graft 槽位满填，GIF合身 【iter11 已修】skin-权重质心 landmarks（wing/feather/tail 26 骨）→ fit_skeleton 重配 bind（拓扑/骨名/权重不变）→ batch_chr chr308 重跑 82/95 骨 11/11 剪辑→graft 68/68→deploy sha 60ad37ab。蒙皮顶点 LBS 采样 idle/move/attack01 max_r≤3.22（≈0.9×体型）无 NaN；overlay 三视图+top 已渲| ✅fit已修(部署) |
| czx_dgm_angemon | 天使兽 | champion | flyer | **czx_dgm_angemon_emp_sws1** | czx_angemo | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter9 flyer试跑：chr039(angel) bonemap 42/72骨 11剪辑GIF合身；iter10批6已部署（95-bin animpack） | 🔧已部署待L4 |
| czx_dgm_ikkakumon | 海狮兽 | champion | quadruped | **czx_dgm_ikkakumon_wf1_wolf** | czx_ik | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr344 bonemap 35/42骨 11剪辑GIF合身；iter6批2已部署（33-bin animpack） | 🔧已部署待L4 |
| czx_dgm_togemon | 仙人掌兽 | champion | biped | **czx_dgm_togemon_emp_sws1** | czx_togemo | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr349 bonemap 47/72骨 10剪辑GIF合身；iter6批2已部署（33-bin animpack） | 🔧已部署待L4 |
| czx_dgm_kabuterimon | 比多兽 | champion | insect | **czx_dgm_kabuterimon_sp1_spid** | czx_kabu | ⚠缺bin层 | ✅ | ✅内收 | ✅chr原生GIF(族donor) | ⏭环境阻塞 | L3 walk/attack 蜷缩成球、death 位移出画面变小；spider 族 retarget 失真（或需 pos_damp）；iter10批7已部署（100-bin animpack） | 🔧已部署待L4 |
| czx_dgm_gatomon | 迪路兽 | champion | biped | **czx_dgm_gatomon_emp_sws1** | czx_gatomo | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter7 biped试跑：chr050 bonemap 62/72骨 8剪辑GIF合身；iter8批4已部署（53-bin animpack） | 🔧已部署待L4 |
| czx_dgm_growlmon | 古拉兽 | champion | biped | **czx_dgm_growlmon_emp_sws1** | czx_growlm | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter7 biped试跑：chr326 bonemap 62/72骨 9剪辑GIF合身；iter8批4已部署（53-bin animpack） | 🔧已部署待L4 |
| czx_dgm_dorugamon | 多路加兽 | champion | quadruped | **czx_dgm_dorugamon_emp_sws1** | czx_doruga | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr396 bonemap 42/72骨 5剪辑GIF合身；iter6批2已部署（33-bin animpack） | 🔧已部署待L4 |
| czx_dgm_geogreymon | 大地暴龙兽 | champion | biped | **czx_dgm_geogreymon_emp_sws1** | czx_geogre | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter7 biped试跑：chr326 bonemap 62/72骨 9剪辑GIF合身；iter8批4已部署（53-bin animpack） | 🔧已部署待L4 |
| czx_dgm_kyubimon | 九尾狐兽 | champion | quadruped | **czx_dgm_kyubimon_wf1_wolf** | czx_ky | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter6 族donor试跑：chr012(族quad) bonemap 34/42骨 8剪辑GIF合身；iter7批3已部署（38-bin animpack） | 🔧已部署待L4 |
| czx_dgm_tyranomon | 巨龙兽 | champion | biped | **czx_dgm_tyranomon_emp_sws1** | czx_tyrano | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter7 biped试跑：chr364(同种metaltyranomon) bonemap 53/72骨 5剪辑GIF合身；iter8批4已部署（53-bin animpack） | 🔧已部署待L4 |
| czx_dgm_seadramon | 海龙兽 | champion | serpent | sn1_sepulchral_stalker_halberd | czx_sea | ⚠缺bin层 | ✅ | ⚠供体骨出网格 | ✅连贯 | ⏭环境阻塞 | L2 供体腿/翼骨落于网格外但 L3 三剪辑（walk/attack_03/death）运动连贯无异常——疑似未蒙皮无害 无蛇形 donor，维持 vanilla sn1_sepulchral_stalker_halberd——iter1/2 L3 已实证该套件连贯合身（蛇形原生套件本就匹配）| ✅通过 |
| czx_dgm_veedramon | v龙兽 | champion | biped | **czx_dgm_veedramon_emp_sws1** | czx_veedra | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr397 bonemap 42/72骨 5剪辑GIF合身；iter6批2已部署（33-bin animpack） | 🔧已部署待L4 |
| czx_dgm_zubaeagermon | 兹巴伊戈兽 | champion | flyer | **czx_dgm_zubaeagermon_wf1_wolf** | czx_zu | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter9 flyer试跑：chr308(bird) bonemap 37/42骨 11剪辑GIF合身；iter10批6已部署（95-bin animpack） | 🔧已部署待L4 |
| czx_dgm_veemonex | v仔兽ex | champion | biped | **czx_dgm_veemonex_emp_sws1** | czx_veemo1 | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter7 biped试跑：chr397(同种veedramon) bonemap 42/72骨 5剪辑GIF合身；iter8批4已部署（53-bin animpack） | 🔧已部署待L4 |
| czx_dgm_fairymon | 仙女兽 | champion | flyer | **czx_dgm_fairymon_emp_sws1** | czx_fairym | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter9 flyer试跑：chr039(angel) bonemap 42/72骨 11剪辑GIF合身；iter10批6已部署（95-bin animpack） | 🔧已部署待L4 |
| czx_dgm_vritramon | 火神兽 | champion | biped | **czx_dgm_vritramon_emp_sws1** | czx_vritra | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter8 biped放量：chr326 bonemap 62/72骨 9剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |
| czx_dgm_duramon | 杜兰兽 | ultimate | biped | **czx_dgm_duramon_emp_sws1** | czx_duramo | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter8 biped放量：chr326 bonemap 62/72骨 9剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |
| czx_dgm_metalgreymon | 机械暴龙兽 | ultimate | biped | **czx_dgm_metalgreymon_emp_sws1** | czx_metalg | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批1已部署：chr302 bonemap 64/72骨 8剪辑全OK→graft 槽位满填，GIF合身 | 🔧已部署待L4 |  |
| czx_dgm_weregarurumon | 兽人加鲁鲁兽 | ultimate | biped | **czx_dgm_weregarurumon_emp_sws1** | czx_werega | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr140 bonemap 62/72骨 8剪辑GIF合身；iter6批2已部署（33-bin animpack） | 🔧已部署待L4 |
| czx_dgm_garudamon | 伽偻达兽 | ultimate | flyer | **czx_dgm_garudamon_emp_sws1** | czx_garuda | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter9 flyer试跑：chr308(bird) bonemap 43/72骨 11剪辑GIF合身；iter10批6已部署（95-bin animpack） | 🔧已部署待L4 |
| czx_dgm_angewomon | 天女兽 | ultimate | flyer | **czx_dgm_angewomon_emp_sws1** | czx_angewo | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter9 flyer试跑：chr039(angel) bonemap 42/72骨 11剪辑GIF合身；iter10批6已部署（95-bin animpack） | 🔧已部署待L4 |
| czx_dgm_zudomon | 祖顿兽 | ultimate | biped | **czx_dgm_zudomon_emp_sws1** | czx_zudomo | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter7 biped试跑：chr344(同种ikkakumon) bonemap 45/72骨 11剪辑GIF合身；iter8批4已部署（53-bin animpack） | 🔧已部署待L4 |
| czx_dgm_megakabuterimon | 超比多兽 | ultimate | insect | **czx_dgm_megakabuterimon_sp1_spid** | czx_mega | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter6 族donor试跑：chr359(insectoid) bonemap 46/74骨 11剪辑GIF合身；iter7批3已部署（38-bin animpack） | 🔧已部署待L4 |
| czx_dgm_lilimon | 花仙兽 | ultimate | flyer | **czx_dgm_lilimon_emp_sws1** | czx_lilimo | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter9 flyer试跑：chr039(angel) bonemap 42/72骨 11剪辑GIF合身；iter10批6已部署（95-bin animpack） | 🔧已部署待L4 |
| czx_dgm_magnaangemon | 神圣天使兽 | ultimate | flyer | **czx_dgm_magnaangemon_emp_sws1** | czx_magnaa | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr101 bonemap 40/72骨 5剪辑GIF合身；iter6批2已部署（33-bin animpack） | 🔧已部署待L4 |
| czx_dgm_wargrowlmon | 大古拉兽 | ultimate | biped | **czx_dgm_wargrowlmon_emp_sws1** | czx_wargro | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter8 biped放量：chr364 bonemap 53/72骨 5剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |
| czx_dgm_rizegreymon | 跃升暴龙兽 | ultimate | biped | **czx_dgm_rizegreymon_emp_sws1** | czx_rizegr | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter8 biped放量：chr364(机龙) bonemap 53/72骨 5剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |
| czx_dgm_paildramon | 机甲龙兽 | ultimate | biped | **czx_dgm_paildramon_emp_sws1** | czx_paildr | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter8 biped放量：chr326 bonemap 62/72骨 9剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |
| czx_dgm_megaseadramon | 超海龙兽 | ultimate | serpent | sn1_sepulchral_stalker_halberd | czx_meg | ⚠缺bin层 |  |  | ✅连贯(vanilla) | ⏭环境阻塞 | 无蛇形 donor，维持 vanilla sn1_sepulchral_stalker_halberd——iter1/2 L3 已实证该套件连贯合身（蛇形原生套件本就匹配）| ✅通过 |
| czx_dgm_skullgreymon | 丧尸暴龙兽 | ultimate | biped | **czx_dgm_skullgreymon_emp_sws1** | czx_skullg | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter7 biped试跑：chr326(同种greymon系) bonemap 62/72骨 9剪辑GIF合身；iter8批4已部署（53-bin animpack） | 🔧已部署待L4 |
| czx_dgm_metaltyranomon | 金属巨龙兽 | ultimate | biped | **czx_dgm_metaltyranomon_emp_sws1** | czx_metalt | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr364 bonemap 53/72骨 5剪辑GIF合身；iter6批2已部署（33-bin animpack） | 🔧已部署待L4 |
| czx_dgm_lilamon | 丁香兽 | ultimate | biped | **czx_dgm_lilamon_emp_sws1** | czx_lilamo | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter8 biped放量：chr349(植物系togemon) bonemap 47/72骨 10剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |
| czx_dgm_taomon | 祭师兽 | ultimate | biped | **czx_dgm_taomon_emp_sws1** | czx_taomon | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter8 biped放量：chr151(狐系同族) bonemap 62/72骨 7剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |
| czx_dgm_jetsilphymon | 喷射西尔芙兽 | ultimate | flyer | **czx_dgm_jetsilphymon_emp_sws1** | czx_jetsil | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter9 flyer试跑：u133(Bip001) bonemap 37/72骨 8剪辑GIF合身；iter10批6已部署（95-bin animpack） | 🔧已部署待L4 |
| czx_dgm_aerovdramon | 天翔V龙兽 | ultimate | flyer | **czx_dgm_aerovdramon_emp_sws1** | czx_aerovd | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr400 bonemap 60/72骨 5剪辑GIF合身；iter6批2已部署（33-bin animpack） | 🔧已部署待L4 |
| czx_dgm_blitzgreymon | 电光暴龙兽 | mega | biped | **czx_dgm_blitzgreymon_emp_sws1** | czx_blitzg | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter8 biped放量：chr364 bonemap 53/72骨 5剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |
| czx_dgm_cresgarurumon | 偃月加鲁鲁兽 | mega | quadruped | **czx_dgm_cresgarurumon_emp_sws1** | czx_cresga | ⚠缺bin层 |  |  |  | ⏭环境阻塞 | ；iter10批7已部署（100-bin animpack） | 🔧已部署待L4 |
| czx_dgm_durandamon | 杜兰达兽 | mega | biped | **czx_dgm_durandamon_emp_sws1** | czx_durand | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter8 biped放量：chr027 bonemap 45/72骨 8剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |
| czx_dgm_metalseadramon | 钢铁海龙兽 | mega | serpent | sn1_sepulchral_stalker_halberd | czx_met | ⚠缺bin层 |  |  | ✅连贯(vanilla) | ⏭环境阻塞 | 无蛇形 donor，维持 vanilla sn1_sepulchral_stalker_halberd——iter1/2 L3 已实证该套件连贯合身（蛇形原生套件本就匹配）| ✅通过 |
| czx_dgm_plesiomon | 蛇颈龙兽 | mega | serpent | sn1_sepulchral_stalker_halberd | czx_ple | ⚠缺bin层 | ✅ | ⚠供体骨出网格 | ✅连贯 | ⏭环境阻塞 | damp(tail 0.25/neck-spine 0.4)有效：walk 滑行、attack_03 前扑、death 瘫伏均连贯；L2 供体腿骨落网格外同 seadramon 无害 无蛇形 donor，维持 vanilla sn1_sepulchral_stalker_halberd——iter1/2 L3 已实证该套件连贯合身（蛇形原生套件本就匹配）| ✅通过 |
| czx_dgm_machinedramon | 机械邪龙兽 | mega | biped | **czx_dgm_machinedramon_emp_sws1** | czx_machin | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter7 biped试跑：chr364(同族机龙) bonemap 53/72骨 5剪辑GIF合身；iter8批4已部署（53-bin animpack） | 🔧已部署待L4 |
| czx_dgm_chaosdramon | 混沌龙兽 | mega | biped | **czx_dgm_chaosdramon_emp_sws1** | czx_chaosd | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter8 biped放量：chr364 bonemap 53/72骨 5剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |
| czx_dgm_sakuyamon | 沙古牙兽 | mega | biped | **czx_dgm_sakuyamon_emp_sws1** | czx_sakuya | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter8 biped放量：chr151(狐系同族) bonemap 62/72骨 7剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |
| czx_dgm_rosemon | 蔷薇兽 | mega | biped | **czx_dgm_rosemon_emp_sws1** | czx_rosemo | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter8 biped放量：chr446(纤细天使) bonemap 49/72骨 5剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |
| czx_dgm_rosemonbm | 蔷薇兽爆裂形态 | mega | biped | **czx_dgm_rosemonbm_emp_sws1** | czx_rosem0 | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter8 biped放量：chr446 bonemap 49/72骨 5剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |
| czx_dgm_vikemon | 维京兽 | mega | biped | **czx_dgm_vikemon_emp_sws1** | czx_vikemo | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter8 biped放量：chr344(海狮系) bonemap 45/72骨 11剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |
| czx_dgm_heraklekabuterimon | 力神比多兽 | mega | insect | **czx_dgm_heraklekabuterimon_sp1_spid** | czx_hera | ⚠缺bin层 |  |  |  | ⏭环境阻塞 | ；iter10批7已部署（100-bin animpack） | 🔧已部署待L4 |
| czx_dgm_magnadramon | 圣龙兽 | mega | quadruped | **czx_dgm_magnadramon_wf1_wolf** | czx_ma | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter6 族donor试跑：chr548(翼quad) bonemap 34/42骨 12剪辑GIF合身；iter7批3已部署（38-bin animpack） | 🔧已部署待L4 |
| czx_dgm_hououmon | 凤凰兽 | mega | flyer | **czx_dgm_hououmon_bi1_eagl** | czx_ho | ⚠缺bin层 | ✅ | ✅翼骨已重配 | ✅chr原生GIF(族donor) | ⏭环境阻塞 | 同 birdramon：damp 已加仍 fly 全段翼面塌陷成倒 V/死坠压扁；翼骨 bind 远超 mesh 须 fit 重修；iter9 flyer试跑：chr308(bird) bonemap 82/95骨 11剪辑GIF合身（hououmon翼骨13尾羽未映射跟父骨，fit失配项单列）；iter10批6已部署（95-bin animpack）【iter11 已修】skin-权重质心 landmarks（wing/feather/tail 32 骨）→ fit_skeleton 重配 bind 收翼裹体（拓扑/骨名/权重不变）→ batch_chr chr308 重跑 82/95 骨 11/11 剪辑→graft 68/68→deploy sha 60ad37ab。蒙皮顶点 LBS 采样 idle/move/attack01 max_r≤3.23（≈0.9×体型）无 NaN；overlay 三视图+top 已渲| ✅fit已修(部署) |
| czx_dgm_dorugoramon | 多路龙兽 | mega | quadruped | **czx_dgm_dorugoramon_emp_sws1** | czx_dorug0 | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr019 bonemap 64/72骨 12剪辑GIF合身；iter6批2已部署（33-bin animpack） | 🔧已部署待L4 |
| czx_dgm_fujinmon | 风神兽 | mega | biped | **czx_dgm_fujinmon_emp_sws1** | czx_fujinm | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter8 biped放量：chr027 bonemap 45/72骨 8剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |
| czx_dgm_wargreymon | 战斗暴龙兽 | mega | biped | **czx_dgm_wargreymon_emp_sws1** | czx_wgm001 | ⚠缺bin层 | ✅ | ✅内收 | ✅chr原生GIF | ⏭环境阻塞 |L3 attack_05 站姿正常、run/death 前倾可辨——体形接近 humanoid01 失真较轻，边缘通过；iter5批1已部署：chr027 bonemap 45/72骨 8剪辑全OK→graft 槽位满填，GIF合身 | ✅通过 |
| czx_dgm_wargreymonx | 战斗暴龙兽X | mega | biped | **czx_dgm_wargreymonx_emp_sws1** | czx_wargre | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter7 biped试跑：chr027(同种wargreymon) bonemap 45/72骨 8剪辑GIF合身；iter8批4已部署（53-bin animpack） | 🔧已部署待L4 |
| czx_dgm_metalgarurumon | 钢铁加鲁鲁 | mega | quadruped | **czx_dgm_metalgarurumon_wf1_wolf** | czx_me | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批1已部署：chr135 bonemap 37/42骨 8剪辑全OK→graft 槽位满填，GIF合身 | 🔧已部署待L4 |  |
| czx_dgm_metalgarurumonx | 钢铁加鲁鲁X | mega | quadruped | **czx_dgm_metalgarurumonx_wf1_wolf** | czx_m0 | ⚠缺bin层 |  |  |  | ⏭环境阻塞 | ；iter10批7已部署（100-bin animpack） | 🔧已部署待L4 |
| czx_dgm_shinegreymon | 闪光暴龙兽 | mega | biped | **czx_dgm_shinegreymon_emp_sws1** | czx_shineg | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr094 bonemap 62/72骨 5剪辑GIF合身；iter6批2已部署（33-bin animpack） | 🔧已部署待L4 |
| czx_dgm_shinegreymonbm | 闪光暴龙兽爆裂形态 | mega | biped | **czx_dgm_shinegreymonbm_emp_sws1** | czx_shine1 | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter8 biped放量：chr094(同种shinegreymon) bonemap 62/72骨 5剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |
| czx_dgm_omegamon | 奥米加兽 | mega | biped | **czx_dgm_omegamon_emp_sws1** | czx_omegam | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr088 bonemap 47/72骨 7剪辑GIF合身；iter6批2已部署（33-bin animpack） | 🔧已部署待L4 |
| czx_dgm_omegamonx | 奥米加兽X | mega | biped | **czx_dgm_omegamonx_emp_sws1** | czx_omega5 | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter8 biped放量：chr357(v1原生指派) bonemap 47/72骨 7剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |
| czx_dgm_omegamonab | 奥米加兽Alter-B | mega | biped | **czx_dgm_omegamonab_emp_sws1** | czx_omega1 | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter8 biped放量：chr448(omegamonm翼版) bonemap 49/72骨 5剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |
| czx_dgm_omegamonas | 奥米加兽Alter-S | mega | biped | **czx_dgm_omegamonas_emp_sws1** | czx_omega2 | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter8 biped放量：chr691(v1原生指派) bonemap 45/72骨 5剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |
| czx_dgm_omegamond | 奥米加兽兹瓦特战损 | mega | biped | **czx_dgm_omegamond_emp_sws1** | czx_omega3 | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter8 biped放量：chr088(同种omegamon) bonemap 47/72骨 7剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |
| czx_dgm_omegamonm | 奥米加兽慈悲形态 | mega | biped | **czx_dgm_omegamonm_emp_sws1** | czx_omega4 | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr448 bonemap 49/72骨 5剪辑GIF合身；iter6批2已部署（33-bin animpack） | 🔧已部署待L4 |
| czx_dgm_gallantmon | 红莲骑士兽 | mega | biped | **czx_dgm_gallantmon_emp_sws1** | czx_gallan | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr013 bonemap 62/72骨 5剪辑GIF合身；iter6批2已部署（33-bin animpack） | 🔧已部署待L4 |
| czx_dgm_gallantmoncm | 红莲骑士兽真红莲形态 | mega | biped | **czx_dgm_gallantmoncm_emp_sws1** | czx_galla0 | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr105 bonemap 62/72骨 11剪辑GIF合身；iter6批2已部署（33-bin animpack） | 🔧已部署待L4 |
| czx_dgm_gallantmonx | 红莲骑士兽X | mega | biped | **czx_dgm_gallantmonx_emp_sws1** | czx_galla1 | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter7 biped试跑：chr013(同种gallantmon) bonemap 62/72骨 5剪辑GIF合身；iter8批4已部署（53-bin animpack） | 🔧已部署待L4 |
| czx_dgm_alphamon | 阿尔法兽 | mega | biped | **czx_dgm_alphamon_emp_sws1** | czx_alpham | ⚠缺bin层 | ✅ | ✅内收 | ✅chr原生GIF | ⏭环境阻塞 | hu1 walk 整体前倾 ~45°、attack 拧转披风乱飞、death 倾覆——大体积 biped 仍失真（无 damp）；iter5批量管线完毕：chr416 bonemap 21/72骨 4剪辑GIF合身；iter6批2已部署（33-bin animpack）（❌为旧 vanilla retarget 结论，chr 原生已验收部署）| 🔧已部署待L4 |
| czx_dgm_jesmon | 杰斯兽 | mega | biped | **czx_dgm_jesmon_emp_sws1** | czx_jesmon | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr749 bonemap 64/72骨 5剪辑GIF合身；iter6批2已部署（33-bin animpack） | 🔧已部署待L4 |
| czx_dgm_jesmonx | 杰斯兽X | mega | biped | **czx_dgm_jesmonx_emp_sws1** | czx_jesmo0 | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter7 biped试跑：chr749(同种jesmon) bonemap 64/72骨 5剪辑GIF合身；iter8批4已部署（53-bin animpack） | 🔧已部署待L4 |
| czx_dgm_magnamon | 金甲龙兽 | mega | biped | **czx_dgm_magnamon_emp_sws1** | czx_magnam | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter8 biped放量：chr416 bonemap 21/72骨 4剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |
| czx_dgm_magnamonx | 金甲龙兽X | mega | biped | **czx_dgm_magnamonx_emp_sws1** | czx_magna0 | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter7 biped试跑：chr416(alphamon骑士) bonemap 21/72骨 4剪辑GIF合身；iter8批4已部署（53-bin animpack） | 🔧已部署待L4 |
| czx_dgm_imperialdm | 帝皇龙甲兽龙形态 | mega | flyer | **czx_dgm_imperialdm_emp_sws1** | czx_imper1 | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter6 族donor试跑：u133(Bip001) bonemap 37/72骨 8剪辑GIF合身；iter7批3已部署（38-bin animpack） | 🔧已部署待L4 |
| czx_dgm_imperialfm | 帝皇龙甲兽战士形态 | mega | biped | **czx_dgm_imperialfm_emp_sws1** | czx_imperi | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter8 biped放量：chr027 bonemap 45/72骨 8剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |
| czx_dgm_imperialpm | 帝皇龙甲兽圣骑士形态 | mega | biped | **czx_dgm_imperialpm_emp_sws1** | czx_imper0 | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter8 biped放量：chr027 bonemap 45/72骨 8剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |
| czx_dgm_ulforcev | 究极V龙兽 | mega | biped | **czx_dgm_ulforcev_emp_sws1** | czx_ulforc | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr397 bonemap 42/72骨 5剪辑GIF合身；iter6批2已部署（33-bin animpack） | 🔧已部署待L4 |
| czx_dgm_ulforcevx | 究极V龙兽X | mega | biped | **czx_dgm_ulforcevx_emp_sws1** | czx_ulfor0 | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr418 bonemap 49/72骨 5剪辑GIF合身；iter6批2已部署（33-bin animpack） | 🔧已部署待L4 |
| czx_dgm_seraphimon | 炽天使兽 | mega | flyer | **czx_dgm_seraphimon_emp_sws1** | czx_seraph | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr315 bonemap 47/72骨 4剪辑GIF合身；iter6批2已部署（33-bin animpack） | 🔧已部署待L4 |
| czx_dgm_ophanimon | 座天使兽 | mega | flyer | **czx_dgm_ophanimon_emp_sws1** | czx_ophani | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter9 flyer试跑：chr446(同族ophanimonfm) bonemap 49/72骨 5剪辑GIF合身；iter10批6已部署（95-bin animpack） | 🔧已部署待L4 |
| czx_dgm_ophanimonfm | 座天使兽堕落形态 | mega | flyer | **czx_dgm_ophanimonfm_emp_sws1** | czx_ophan0 | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr446 bonemap 49/72骨 5剪辑GIF合身；iter6批2已部署（33-bin animpack） | 🔧已部署待L4 |
| czx_dgm_mastemon | 莫斯提兽 | mega | biped | **czx_dgm_mastemon_emp_sws1** | czx_mastem | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter8 biped放量：chr446(天使) bonemap 49/72骨 5剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |
| czx_dgm_zeedmillennium | 最终千年兽 | boss | biped | **czx_dgm_zeedmillennium_emp_sws1** | czx_zeedmi | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter8 biped放量：chr364 bonemap 53/72骨 5剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |
| czx_dgm_apocalymon | 启示录兽 | boss | biped | **czx_dgm_apocalymon_sn1_serp** | czx_apo | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter8 biped放量：chr027 bonemap 48/90骨 8剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |
| czx_dgm_lucemon | 光明兽 | boss | flyer | **czx_dgm_lucemon_emp_sws1** | czx_lucem0 | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter9 flyer试跑：chr039(同种lucemonfm) bonemap 42/72骨 11剪辑GIF合身；iter10批6已部署（95-bin animpack） | 🔧已部署待L4 |
| czx_dgm_lucemonfm | 光明兽堕落形态 | boss | biped | **czx_dgm_lucemonfm_emp_sws1** | czx_lucemo | ⚠缺bin层 |  |  | ✅chr原生GIF | ⏭环境阻塞 | iter5批量管线完毕：chr039 bonemap 42/72骨 11剪辑GIF合身；iter6批2已部署（33-bin animpack） | 🔧已部署待L4 |
| czx_dgm_susanoomon | 金刚武神兽 | boss | biped | **czx_dgm_susanoomon_emp_sws1** | czx_susano | ⚠缺bin层 |  |  | ✅chr原生GIF(族donor) | ⏭环境阻塞 | ；iter8 biped放量：chr105(gallantmoncm) bonemap 62/72骨 11剪辑GIF合身；iter9批5已部署（84-bin animpack） | 🔧已部署待L4 |

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


### iter 8 — 批4（15只biped）落源部署 + biped 放量 31/31 全过，biped 组清零

- **批4 部署 ✅（累计 53/104 激活）**：veemon/gatomon/palmon/renamon/growlmon/geogreymon/skullgreymon/tyranomon/machinedramon/veemonex/zudomon/wargreymonx/gallantmonx/jesmonx/magnamonx——graft 全 95/95 满填（全员 emp_sws1 套件，other-skel 槽保留），骨架名三处一致性预检 15/15 OK。`pack_animsets.py` 重打 **53-bin** `zzz_dgm_chr_native.animpack`（4.83MB）；land_units 15 行切 `czx_dgm_*_emp_sws1`（`_lu_switch.py` 脚本化）。deploy 于并发会话空窗完成：398MB/10851 文件，mod_output==data sha256 `fede8f69`，playset pos 91。**激活 53/104（land_units 源表复核 53 行），剩余 51 只 vanilla。**
- **biped 组放量 31/31 全合格 → biped 类别清零（批5 名单）**：剩余 21 只 mesh-chr biped + 10 只 no-src biped 一次跑完，14 种 donor 全覆盖。亮点：(a) **v1 原生指派复活**——omegamonx 的 v1 land_units 指向 chr357、omegamonas→chr691（GLB 无 chr 号但 v1 已指 animset，实为作者亲选同种 donor），直接采用；(b) 族系细化——taomon/sakuyamon←chr151（狐系同族）、lilamon/rosemon/rosemonbm←chr349/chr446（植物/纤细天使）、vikemon←chr344（海狮系，appendix 原定 chr027 改投同族）、chr364 系 5 只机龙/大古拉/兹德全合身；(c) 无系别失真：chr050/151/326/344/349/364/446/027/094/357/448/691/416/105/088 全通。特例：apocalymon（多面体+锁链臂，90骨系）idle/move 锁链垂摆合身；fujinmon 平飞造型非失真（c150 GLB 本身就是卧飞姿态）；susanoomon 的 Orochi 小龙绑在 be_prop_* 未映射骨上静卧脚边（单元件，非炸顶点）。montage 验收图 `scratch/model_check/digimon/montage/czx_dgm_*.png`。
- **L4 继续环境阻塞**：`+0x4e5b30` 最近 dump 16:06 仍同址；但 16:22/16:39 有另一会话的 WH3 存活拉起（环境修复组在试），本迭代不抢并发。前端二分判据待其退场后执行。
- **下一步**：iter9 = 批5 落源 31 只 biped → flyer 组（bird chr307/308 + angel chr039/446/101/094 + winged-dragon chr019/400/229/209/208 三池，~14 只）→ quad 剩余 + insect 补位（tentomon/kabuterimon/heraklekabuterimon←chr359 已证）→ serpent 4 只 vanilla 收场。


### iter 9 — 批5（31只biped）落源部署，biped 类别全激活；flyer 组 11/11 全过

- **批5 部署 ✅（累计 84/104 激活）**：guilmon/lalamon/sunflowmon/zubamon/duramon/taomon/sakuyamon/paildramon/vritramon/lilamon/rosemon/rosemonbm/mastemon/rizegreymon/blitzgreymon/chaosdramon/zeedmillennium/wargrowlmon/vikemon/durandamon/imperialfm/imperialpm/apocalymon/fujinmon/shinegreymonbm/omegamonx/omegamonab/omegamonas/magnamon/susanoomon/omegamond。graft 全满填（30×emp_sws1 95/95 + apocalymon sn1_serp 81/81——其 v1 模板本就是 serpent 套件，锁链臂走蛇链），骨架名三检 31/31 OK。`pack_animsets.py` → **84-bin** animpack（8.09MB）；land_units 31 行切换（复核激活=84）。`build_pack --deploy` 于 WH3 空窗完成：**461MB/10882 文件，sha `e220c808` 双侧一致**，playset pos 91。**剩 20 只 vanilla**。
- **flyer 组放量 11/11 全合格 → 批6 名单**：bird 池 patamon←chr307（42/42 满映射）、zubaeagermon/garudamon/hououmon←chr308；angel 池 angemon/angewomon/fairymon/lilimon/lucemon←chr039、ophanimon←chr446；jetsilphymon←u133（Bip001 37/72）。逐张 montage 合身：patamon 滑翔悬停、鸟系收翼站姿一致、天使翼随父骨收放自然；lilimon 百合炮/fujinmon 平飞均为 mesh 设计非失真。**翼骨 fit 失配复核**：本批未见 biyomon 式翼骨超网格新案例（hououmon 13 尾羽骨未映射跟父骨，收翼裹体合身——其 bind-fit 缺陷与 biyomon/birdramon 同型，台账已单列不阻塞）。
- **L4 继续环境阻塞（有恢复信号）**：`+0x4e5b30` 末次 dump 仍 16:06；环境组 16:22/16:39 两次拉起均存活退出（无新 dump）——崩溃签名可能已消退，待环境组确认后跑前端二分（批1-5 抽验清单备好）。
- **下一步**：iter10 = 批6 落源 11 只 flyer → 剩余 5 只一次跑完（quad：cresgarurumon/metalgarurumonx←chr135；insect：tentomon/kabuterimon/heraklekabuterimon←chr359）→ serpent 4 只（seadramon/megaseadramon/metalseadramon/plesiomon）维持 vanilla 记 ✅通过 → 全表清零待 L4。


### iter 10 — 收尾轮：批6 flyer 11 只 + 批7 quad/insect 5 只落源，**100/104 激活 + serpent 4 只 vanilla 通过 = 全表清零**

- **批6 部署 ✅（95/104）**：patamon←chr307(42/42)/zubaeagermon+garudamon←chr308(wf1_wolf 43/43)/hououmon←chr308(bi1_eagl 68/68)/fairymon+angewomon+lilimon+angemon+lucemon←chr039/ophanimon←chr446/jetsilphymon←u133（均 emp_sws1 95/95）。骨架名三检 11/11 OK。95-bin animpack（8.99MB）→ deploy 485MB/10893 文件 sha `cd52603c`。
- **批7 部署 ✅（100/104，收尾 5 只全过）**：cresgarurumon←chr135（quad 39/72）、metalgarurumonx←chr135（同种 37/42 wf1_wolf 43/43）、tentomon/kabuterimon/heraklekabuterimon←chr359（insectoid 46/74，sp1_spid 35/35）——独角仙爬/突进/展翅全合身。100-bin animpack（9.14MB）→ deploy **492MB/10898 文件 sha `3b0661bf`** 双侧一致。graft/skel/land_units 全部满填。
- **serpent 4 只维持 vanilla 定案**：seadramon/megaseadramon/metalseadramon/plesiomon 留 `sn1_sepulchral_stalker_halberd`——无蛇形 chr donor 可借，且 vanilla 蛇套件 iter1/2 L3 已实证连贯合身（蛇形原生套件本就匹配），标 ✅通过。
- **L4 终态=环境阻塞（实锤）**：本会话亲自拉起全 playset（95 mod 含本包 pos 91）到主菜单——17:06 秒级崩 `Crash report` 窗口、modified.log 未生成（挂载阶段前即死）；环境组 17:02/17:09 两次拉起同样 Crash report。+0x4e5b30 仍在（dump 待 crash-report 关闭后落盘）。**非本包归因**：vanilla 空 modlist 同址复现已证。**前端二分判据未能执行存活样本**——包挂载验证与单位抽验全部待环境恢复。已杀本会话测试实例释放包锁。
- **遗留清单**：(a) 鸟系 bind-fit 3 只（biyomon/birdramon/hououmon）❌遗留专项——`fit_skeleton.py` 按收翼 mesh 重配翼链 landmarks→重跑 batch_chr+graft；(b) L4 全量复核挂起；(c) susanoomon Orochi 小龙绑定件静卧脚边（be_prop 未映射，可选增强非缺陷）。
- **STATUS=DONE（动画侧）**：104 行全有结论——100 只 chr 原生套件激活（graft 满填+GIF 验收+skel 三检）、4 只 serpent vanilla 通过、L4 全行 ⏭环境阻塞、❌ 仅余 3 条 fit 专项几何项（动画侧已验收）。

### iter 11 — 鸟系 bind-fit 专项重修：3/3 修复并部署，动画侧 ❌/🔧 清零

- **根因复核**：真正出网格的并非 wing_* 主翼链（本轮先按 8 骨质心 landmark 将其收进 mesh），而是 feather_* 羽骨层——每骨架 38 根羽骨绝大多数**未蒙皮**（biyomon 仅 2、birdramon 8、hououmon 12 根驱动顶点）；蒙皮羽骨 bind 位伸出网格达 ~8x（如 biyomon feather_primary_middle_left_2 x=-4.42 vs mesh ±0.54）。未蒙皮羽骨纯装饰不驱动顶点，故数字「超框」不等于网格失真——蒙皮顶点 LBS 才是判据。
- **landmarks 升级（_wing_landmarks.py）**：对 skin 中 weight>0.35 的顶点取加权质心作为该骨 landmark，prefix 扩到 wing_/feather_/tail_——biyomon 14 / birdramon 26 / hououmon 32 条 landmark；拓扑、骨名、蒙皮权重一律不动（chr 剪辑与权重兼容要求）。
- **fit_skeleton 重配**：fit() 重定位 landmark 骨+链插值+最短弧 re-aim；skel_*.json、czx_{bi,b0,ho}.anim、.bone_inv_trans_mats（各 4568B）重写。静态复核：**所有蒙皮骨均落入 mesh bbox（5% 余量）内**，质心残差 ≤0.36 仅为 pivot 骨（root/spine/leg/neck）正常偏移。
- **overlay 验证**：blender_skel_overlay_json.py 补 --top；每单位 4 视图（v3/front/side/top）共 12 张渲染 OK → scratch/digimon_batch/<u>/iter11_overlay_*.png。
- **batch_chr 重跑+GIF 验收**：biyomon←chr307 **95/95**、birdramon/hououmon←chr308 **82/95**（tail_* 多级尾链 chr308 无对应链，跟父骨，与上轮同）→ **11/11 剪辑全 OK**，idle/move/attack01/attack02 GIF+montage 重出（scratch/model_check/digimon/batch_chr/<u>/、montage/）。
- **蒙皮顶点 LBS 定量验收**：新 bind+新剪辑下 idle/move/attack01 采样 8 帧，蒙皮顶点 max_r = 0.96(biyomon) / 3.22(birdramon) / 3.23(hououmon)，均 ≈1x 体型半径、无 NaN——biyomon 剪辑中远距关节（r≈5）均为未蒙皮羽骨，顶点不跟随。
- **graft+部署**：3 只 bi1_eagl 槽位 68/68 满填，骨架名三检（skel json == battle_animations_table == 剪辑内嵌）3/3 OK；animpack 重打（bin 只引槽路径，载荷不变）。WH3 进程 17:32 拉起、17:38 退出后 build_pack --deploy：**492,314,053B / 10,898 文件，sha256 60ad37ab mod_output==data 双侧一致**，playset pos 85。
- **L4 全行 ⏭环境阻塞维持**：+0x4e5b30 环境级签名未复核（vanilla 控制组同址复现已证非本包）；待环境恢复后跑前端二分+单位抽验。
- **STATUS 终态**：**104/104 全清零**——100 只 chr 原生套件激活、4 只 serpent vanilla 通过、3 只鸟系 fit 修复部署 ✅；❌/🔧 归零，仅 L4 环境级阻塞遗留。

### iter 12 — 挂载件焊腿骨修复（susanoomon 平台 + imperialpm 巨剑）已部署

- **缺陷定位**（用户截图指出 susanoomon「模型站在飞行器上」两部分应独立）：bound GLB 探查发现 `part0` 下两 prim——本体走全身骨架，平台 prim1 全部顶点被管线最近骨配重焊到 foot/toe/lowerleg（源模型里平台本来就是独立 `J_wep/J_wep1` 武器骨挂载件）。
- **susanoomon**：平台 5237v 权重全改 `animroot`（刚性挂载）。RMV2 验证：verts>=9247 全部 bone0/weight255，本体 0 误伤。工作室实拍：idle/walk 平台刚性不动，death 尸体平躺落地、平台悬停原位 =「人从车上摔下」正确分离。
- **imperialpm**：同法扫描全 104 bound GLB（无躯干骨 prim 探测）又抓出 `_001_chr420` 401v 巨剑（Omega Blade，源绑 J_weapon）焊在脚骨拖地 4.47m。修法：顶点绕柄部（源点）前俯 -12° 平移到 `hand_right` bind 位、全权重绑 hand_right —— Blener 渲染确认持剑前伸、剑尖自然垂地。
- **同类扫描结果**：ikkakumon 164v 腹甲片贴身穿戴正常（不动）；gallantmonx/shinegreymonbm/metalgarurumon 的无躯干骨 prim 均为手部武器合法绑定。
- **坑**：GLB 补丁切片写入必须用 `nbytes`（元素数×4 会错位截断文件——第一版补丁给 three.js 报 RangeError: Invalid typed array length 1152，Python 解析器容忍所以难发现）。JSON chunk 改写必须保持原长度（空格补齐）。
- **部署**：两单位 convert_unit 重生 RMV2 → build_pack --deploy：491,621,358B / 11,392 文件，playset pos 86，sha 双侧一致。
- **产物**：`scratch/_sweep/fix_imperialpm_sword.py`、`scratch/_sweep/regen_susano.py`；GLB 备份 `.preprop.bak`/`.presword.bak`。

## iter13（2026-09-26）原版惯例导出学习

- 用户指示「先从游戏导一批模型学人家怎么做骨骼和动画」。用 `tools/wh3_export_unit_glb.py`（本轮修复：stump 槽跳过、VMD 直链 rmv2、无骨架 prop 跳过）导出 7 只代表到 `scratch/ref_export/`：stegadon/hurricanum/giant_spider/greatswords/eagle/medusa/dragon。
- **惯例归纳**（详 `references/vanilla_bone_conventions.md`）：
  1. 平台/载具件=专用骨链（platform_back/front、pole、bow / spider 的 platform+section_0..7）挂 root 或 rear_0 下，剪辑逐骨写轨道——susanoomon 改 animroot 属同一思路的最刚性版。
  2. 武器=无骨架 prop + `<SLOT name="weapon_1" attach_point="be_prop_0">` 运行时挂骨；hu1 原版剪辑 be_prop_0..5 全有武器弧线轨道。
  3. **graft 管线缺陷实锤**：重定向剪辑里 be_prop_*/root 轨道全恒等（czx_imper0 attack 55 帧 be_prop_0 钉原点）→ 现阶段 prop 槽挂法不可用；imperialpm 的「顶点搬手位+焊 hand_right」是当前正确解。若启用 CA 式挂载需 graft 阶段生成 be_prop 轨道（每帧=持械手世界变换）。
  4. 羽骨全链带动画轨道（czx_bi/czx_ho 实测外层羽活动 2-3.4m），graft 保 feather 数据，bind fit 必须准。
  5. snake02 蛇系 tail_0..19 主链+侧链+发蛇 jaw，供 seadramon 族后续 graft 参考。
- **遗留 TODO**：graft 补 be_prop 轨道生成 → 之后可把 imperialpm 剑改成 CA 式 weapon_1 attach_point（可换 variant、跟武器弧线）。

## iter14（2026-09-26 上午续）注入 GLB 剪辑解体修复 + 全库批量落地

- **病灶**：inject_rt 把重定向后 .anim 的局部 TRS 直接写进 GLB 节点轨道——.anim 局部值是 wh3 拟合骨架（czx_*）局部约定，GLB 节点是 Blender 导出骨轴系约定，直接套用到工作室预览即解体。
- **修法**：scratch/fix_injected_anims.py 世界空间 delta 重定向——W_glb=ΔW_skel⊗W_glb_bind，再按 GLB 父子链分解回节点局部 TRS 重写轨道；每动画写 extras.wsFixed 幂等标记防二次换算；每骨补齐 rotation+translation 双 channel（wh3 原 clip 位移轨道稀疏，世界重定向后每骨都需位移）。
- **批量**：无参跑=全部有 skel_*.json 的单位。**104/104 dgm GLB 全修完**（4-7 clip/只，joints 42-95）；ref_* 导出件（wh3_export_unit_glb 自带烘焙剪辑，本就正确）与无动画件（pkm_*/jibian）不受影响。
- **tabbit 抽验**（127.0.0.1:57202 studio）：tentomon sp1_walk/attack 中帧网格连贯无解体、wargreymon hu1_sws_attack 站姿出招正常、stegadon hq01_attack（ref 对照组）原生剪辑正常。
- **游戏侧**：zzz_czx_digimon_v3.pack（11:13 部署 491,581,042B）随 WMM 清单加载；11:32/11:40 两次启动撞 §10.40 loading-dismiss 竞态崩（+0x132c34c/+0x22c0f80 已知签名），11:43 第三次拉起存活。
- **文档**：坑表已补 wsFixed 修法行（custom_model_unit_pipeline.md §9）。
- **待办**：游戏内 tentomon 战斗动画目视验收（甲虫兽 czx_tent 骨架 + sp1 蛛系剪辑）。

## iter15（2026-09-26 晚）与官方模型硬性差距清单（定量对比）

基准：官方 `lzd_carnosaur_feral`（variants.pack 解出 RMV2 直读）+ ref_export GLB 集；我方 `czx_dgm_greymon`（v2 当前部署版）。渲染对照图 `scratch/_cmp_{greymon,kroxigor,bls}_front.png`。

| 维度 | 我们 | 官方 | 判定 |
|---|---|---|---|
| LOD | **1 级** | **5 级**（10/30/120/180/10000m：19462/13635/8237/867/297 v） | ❌差距 |
| lod0 网格 | 3,448v / 4,812tri | 19,462v / 30,472tri | ❌素材上限（Cyber Sleuth 拆包低模，非转换丢） |
| 贴图 | base_colour 512² 真 + normal/specular/mask/material_map **全 16²占位**（104/104 全占位） | 2048² 全六件真图 + commontextures bloodmap/dither | ❌差距最大项 |
| 蒙皮 | greymon 78% 单骨、22% 双骨；wargreymon 87% 单骨；biyomon 22% 单骨（接近官方） | 33% 四骨、47% 多骨 | ⚠bonemap 转移质量不齐，硬朗系偏刚性 |
| 材质 | weighted4_character_alpha；faction tint 通道 0,0,0,0 全关 | weighted4_character；faction3_mask_channel 0,0,1,0 + 血渍参数 | ⚠小差距（alpha shader 选型+无 mask 阵营染色） |
| wsmodel | 仅 lod0 一条 material | 每 LOD 独立材质，lod2+ 降 weighted2 | 派生差距（LOD 补齐自然带上） |
| 挂点 | ~72 个 per-bone 占位 attach | 4 个语义挂点（animRoot/root/spine…） | ⚠冗余非缺陷，语义挂点体系未建 |
| 骨架 | czx_greymo 72 骨 | raptor03b 83 骨 | ✅同量级 |
| 动画量 | ~95 剪辑/只（9709 总） | 恐爪龙自身 ~79 + matched/subset/骑乘库 | ✅量持平；质=移植 vs 手工（L4 待验收） |
| 顶点格式 | RMV2 v8 36B（带顶点色通道） | v7 32B weighted | ✅不亏 |
| VMD | 单 body 槽 | 恐爪龙同样单 body 槽 | ✅怪物单位本就单槽 |
| specular 回退 | v1 有 24 只真 `*s.dds`（如 chr326a01s 22KB），v2 全占位 | — | ⚠v2 相对 v1 小回退 |

**结论**：差距 = 素材源上限（512²/低模）+ 表面工艺（无法线/高光/mask/LOD）+ 蒙皮偏硬 + prop 未分离。修得了的：占位图→真图（源有 ~24 张 s 图，其余可生成法线）、LOD 生成、prop attach_point 化。修不了的：要超官方观感只能换 manual_edit 式高模源（Sketchfab 34K v/4K PBR 线，密度已超官方但需逐只人工修权）。


## iter16（2026-09-26 深夜）greymon 试点推进到"基本完善"

对象：czx_dgm_greymon（chr326 供体骨架 czx_greymo）。产物落在源包内，原件备份在 scratch/greymon_hq/bak/。

### 官方贴图通道布局解码（carnosaur 2048² 实测）
- mask.dds (BC3)：仅 B 通道有数据 = faction3 tint 选区；无阵营用 commontextures/default_black.dds
- material_map (BC7)：R=高光强度，G=光泽度，B=0，A=255
- normal.dds (BC3)：DXT5nm 布局 A=X, G=Y（R=255,B=0）
- 关键坑：官方 *_weighted4_alpha_off.xml.material 实际 shader 是 weighted4_character.xml.shader（非 alpha）——v2 全库错配成 weighted4_character_alpha
- xml.material 无 specular 槽；RMV2 内嵌贴图表仍带 type11 specular 路径（legacy）

### 已落地改动
1. 真贴图组（scratch/gen_greymon_tex.py → scratch/_dgm_greymon_tex/ → texconv）：
   - normal 512² 由 albedo 亮度微浮雕生成（strength 1.6，DXT5nm 编码，BC3）
   - material_map 512² BC7：R=v1 chr326a01s.dds（128² 真高光图）亮度×200，G=0.55
   - specular 512² BC7：v1 s 图升采样（v2 占位回退已补回）
   - mask 512² BC3 全零；material XML mask 槽改 commontextures/default_black.dds（同官方）
   - shader 从 weighted4_character_alpha 改 weighted4_character（base alpha 恒≈1.0 已验证）
2. 真 5 级 LOD（scratch/gen_lods_blender.py，Blender Decimate collapse + delimit NORMAL/UV/SEAM）：
   - ratio [0.7,0.42,0.18,0.09] → 2629/1801/967/613v（lod0=3448v 不动）
   - 蒙皮权重随抽减自动保留（vgroups=72 全保留，权重和=1，maxbone=54<72 合法）
   - lod 距离照搬恐爪龙 [10,30,120,180,10000]m
3. 多 LOD RMV2 写入器（scratch/build_greymon_hq.py 内 write_rmv2_v8_lods）：
   - 每 LOD 独立 model block + 独立 v/i buffer + 独立 bbox；lod header 字段照官方（q=2 仅 lod0）
   - 全部 vtype4/36B（没仿官方 lod2+ 降 vtype3/weighted2——vtype3 打包格式未实现，安全起见全 weighted4）
   - 新文件 444,726B（旧 161,464B）；parse_rmv2 回读 5 级计数正确
4. wsmodel：5 条 material 全指向 weighted4_alpha_off（顶点格式匹配优先）
5. 验收渲染（scratch/greymon_hq/）：
   - prev_lod{1..4}_front/side/top：剪影逐级平滑退化但角/尾/爪俱在
   - pose_lod2_f15.png / pose_lod4_f15.png（hu1_sws_attack_01 攻击帧）：蒙皮变形正常，无爆点/脱件
   - rt_lod3：新 RMV2 二进制转回 GLB 渲染正常 = 写盘格式经 decode 验证

### 部署状态
- pack 已重打包（818,185,218B）；游戏运行中锁文件 → scratch/deploy_digimon_when_free.sh watcher 挂起（退出后自动 --deploy + sha256 校验，日志 scratch/deploy_digimon.log）
- data\ 下并存 v2/v3/v4/v5 pack，playset 以 state.db 为准（部署后需复核）

### 待办/后续
- 游戏内实测：LOD 切换距离观感 + 攻击/行走/死亡剪辑 + 蒙皮
- weighted2/vtype3 32B 编码器（远级降档，官方做法）
- 蒙皮平滑化未动（78% 单骨刚性是 bonemap 移植上限）
- 推广：把 gen_lods_blender + write_rmv2_v8_lods + tex 生成并进 convert_new_units.py 主管线后批量跑全库
- 其余 103 只仍 16² 占位 + 单 LOD

## iter16（2026-09-26 深夜）greymon 试点推进到"基本完善"

对象：（chr326 供体骨架 czx_greymo）。产物全部落在源包内（bak 在 ）。

### 官方贴图通道布局解码（carnosaur 2048² 实测）
-  (BC3)：仅 **B 通道** 有数据 = faction3 tint 选区；无阵营用 
-  (BC7)：**R=高光强度，G=光泽度**，B=0，A=255
-  (BC3)：DXT5nm 布局 **A=X, G=Y**（R=255,B=0）
- 关键坑：官方  实际 shader 是 （**非 alpha**）——v2 全库错配成 
- xml.material 无 specular 槽；RMV2 内嵌贴图表仍带 type11 specular 路径（legacy）

### 已落地改动
1. **真贴图组**（ →  → texconv BC7/BC3）：
   - normal 512² 由 albedo 亮度微浮雕生成（strength 1.6，DXT5nm 编码）
   - material_map 512²：R=v1 （128² 真高光图）亮度×200，G=0.55
   - specular 512²：v1 s 图升采样（v2 占位回退已补回）
   - mask 512² 全零；material XML mask 槽改 （同官方）
   - shader 从  → （base alpha 恒≈1.0 验证过）
2. **真 5 级 LOD**（，Blender Decimate collapse + delimit{NORMAL,UV,SEAM}）：
   - ratio [0.7,0.42,0.18,0.09] → 2629/1801/967/613v（lod0=3448v 不动）
   - **蒙皮权重随抽减自动保留**（各 lod vgroups=72 全保留，权重和=1，maxbone=54<72 合法）
   - lod 距离照搬恐爪龙 [10,30,120,180,10000]m
3. **多 LOD RMV2 写入器**（ 内 ）：
   - 每 LOD 独立 model block + 独立 v/i buffer + 独立 bbox；lod header 字段照官方（q=2 仅 lod0）
   - 全部 vtype4/36B（**没有仿官方 lod2+ 降 vtype3/weighted2**——vtype3 打包格式未实现，先用安全全 weighted4；远级才几百顶点无损大局）
   - 新文件 444,726B（旧 161,464B）；parse_rmv2 回读 5 级计数正确
4. **wsmodel**：5 条 material 全部指向 （顶点格式匹配优先于官方 weighted2 降档）
5. **验收渲染**（）：
   - prev_lod{1..4}_front/side/top：剪影逐级平滑退化但角/尾/爪俱在（lod4 最低 613v 仍辨认得出暴龙兽）
   - /（hu1_sws_attack_01 攻击帧）：蒙皮变形正常，无爆点/脱件/折角
   - ：新 RMV2 二进制转回 GLB 渲染正常 = 写盘格式经 decode 验证

### 部署状态
- pack 已重打包（818MB，含新资产）；游戏运行中锁文件 → [2026-09-26 20:54:25] watcher start, waiting for Warhammer3.exe to exit... watcher 挂起（游戏退出后自动 --deploy + sha256 校验，日志 ）
- 注意 data\ 下并存 v2/v3/v4/v5 pack，playset 以 state.db 为准（部署后需复核）

### 待办/后续
- 游戏内实测：LOD 切换距离观感 + 攻击/行走/死亡剪辑 + 阵营染色（mask 全零=无染色，符合设定）
- **weighted2/vtype3 32B 编码器**（远级降档，官方做法）
- 蒙皮平滑化未动（78% 单骨刚性是 bonemap 移植上限；要改需 Blender smooth weights + 逐关节验收）
- 推广条件：把 gen_lods_blender + write_rmv2_v8_lods + tex 生成并进 `convert_new_units.py` 主管线，按"有 s 图/无 s 图"分两档跑全库
- 其余 103 只依旧 16² 占位 + 单 LOD——本试点跑通后批量套模板

### iter16 续：建模工作室自检通过（tabbit 8787）

- 五级 GLB 已放入 `model-studio/models/`：`greymon_hq_lod0..4.glb`（lod0=bound.glb 副本，lod1-4=decimate 产物）
- lod1：72 骨 / 17 自动映射 / rebind.steal=0 / jaw audit ok；idle、roar(t=0.6)、run(t=0.35) 截图均正常——吼叫张嘴、奔跑抬腿，无解体
- lod4：516v 吼叫帧剪影完整、jaw graft 正常，steal=0
- 证据图：tabbit artifacts `task-b5a60467…/studio_lod1_{idle,roar,run}.png`、`task-03626596…/lod4_roar.png`
- 部署 watcher 已按用户要求撤掉（游戏内验证等用户目检后再走）

### iter17：加鲁鲁兽原生剪辑 → .anim 入包路径（glb_src_to_anim 空间桥）

- **转换器** tools/glb_src_to_anim.py：GLB 原生 src_* 剪辑 → WH3 .anim v8 直转（同骨架无重定向）。核心空间桥：GLB 动画节点空间≠绑定空间（model-studio iter121 同病灶），设 D_i = IBM_i·M(worldFrame0_i)，则 animLocal_i = inv(D_par)·L_node_i·D_i 精确成立；skel 中 parent<0 根骨取 animLocal = nodeWorld·D。
- **验证**：写读回环组合世界矩阵 vs nodeWorld·D 期望，5 条剪辑 × 42 骨 × 3 帧 maxWorldErr ≤0.0008（i16 四元数量化噪声级）。全 43 槽文件 parse OK、骨架名 czx_ga、42 骨。
- **槽位映射**（39/43 换原生；清单 scratch/garu_qa/native_slotmap.json）：
  - attacks×7 ← atck_fa0/fb0/fc0/fd0 + shot_fa0 + jump_fa0/fa2
  - combat_idles×6 ← prov/gurd×3/feel_fg0/fh0
  - death×4 ← dmgx_fa1(仰面)/dmgl_fa0(击飞)/dmgx_fa0/fa2
  - defends×2 ← dmgs_fa0/feel_fh0；locomotion×7 ← run/walk_fa0×2/walk_ba0/base_fb0/feel×3
  - movement step_fwd/bwd ← walk_fa0/ba0（ba0 后退步归位正确）；porthole×2/refuses×2/stand×7 ← base/feel/eat/rest/getu
  - 保留 vanilla 重定向：turn_left/right_90、step_left/right（无原生对应）
- **钻地修复同步生效**：iter123 ground_clamp 已写入 bound.glb（atck_fc0/jump_fa1 逐帧地面吸附），本次转换用的是修复后数据——attack_03(=atck_fc0) 落盘即贴地版；jump_fa1 修复后暂未入槽（jump_attack_02 用的是 jump_fa2 落地段）。
- **待办**：游戏内实测原生动作观感（跑/咬/倒）；其余 103 只同法批量（需各自 GLB 原生剪辑先注入）；_un 单次剪辑与 _ul 循环剪辑的引擎行为待实测。
- **工作室复核**（用户明令验收在 model-studio 不进游戏）：12 槽代表帧 montage 目检全过——run 蹬地/walk/step_bwd/attack_01 扑咬/attack_03 贴地俯冲/shot/×2 combat_idle/death 仰倒+击飞/eat/rest，无解体穿地；证据 E:\Code\model-studio\scratch\_viz\garu_slotmap_sheet.png（tabbit task-0977c839 shot-872d92b6，__errs 空）。

### iter18：51 只数码兽 CS 原生剪辑批量注入（dgm_srcanim 流水线）

- **范围**：104 只 bound.glb 中筛出「有 jmap.json + 有 CS With Animations.fbx + 有 models/ glb」= **51 只**；其余缺口：31 只有 fbx 无 jmap（绑定未走权重迁移）、16 只有 jmap 无对应 fbx、4 只皆无。
- **工具链**（tools/ 新增）：
  - tools/dgm_dump_anims.py：Blender 批量——manifest 循环逐个 FBX 导入、滤非骨架 action、去 _N LOD 重名、>600f 跳过；导出 rest 世界矩阵 + 逐帧 pose 世界矩阵 + scene fps。
  - tools/dgm_srcanim_manifest.py：按 report.json 的 chrNNN 反查 dgm_pub_src FBX，产出 51 项 manifest。
  - tools/dgm_srcanim_inject.py：jmap + _root_src/_root_tgt（首选 J_center→root，omegamonas 落到 J_grey_head）拼注入 map，调 garu_qa/inject_src_anim.py，原地回写 models/<u>_bound.glb（先存 .bak_srcanim）。
- **关键坑——CS 源骨架是 Z-up 且 ~1/15 微缩**（与 NxO d043 不同）：FBX dump 的 rest span z>>y。注入前先做坐标变换：每帧世界矩阵 C4·m·C4ᵀ（C=标准 zup→yup：(x,z,-y)），否则旋转 delta 全绕错轴。每单元按 rest span 自动判向（span.z > 2·span.y）。亚古兽修正前注入的废案已回滚重灌。
- **产出**：51 只 × 各 11~13 条 src_* 剪辑（attack01/02、damage、down、eat、getup、glad、guard、idle、move、special01、win）共 554 条动作入库 models/，donor hu1_sws 剪辑原样保留。导出 JSON 存 scratch/dgm_srcanim/<u>/（gitignore 内，~524MB 可再生成）。
- **验证**：先导亚古兽 6 帧 montage（idle/move/attack01/attack02/down/win）姿态全正；抽 3 科复核——偃月加鲁鲁（四足扑咬）、伽偻达（鸟翼随动）、战斗暴龙（双足回旋爪+倒地持盾）均 upright/贴地/变形正常，__errs 空。证据 tabbit task-71ece22c：agu_src_sheet / srcinj_{cresgarurumon,garudamon,wargreymon}。
- **矩阵**：5 只试点 59P/33W/0F/92clip（scratch/matrix_srcinj5.json）；51 只全量矩阵见 matrix_srcinj51.json。
- **待办**：31 只「有 fbx 无 jmap」需自动建映射（位置匹配源骨→目标骨）；16 只 jmap 无 fbx 需另找源；src_* → .anim 槽位批量（glb_src_to_anim 按族骨架）；钻地类逐帧吸附按需（garu ground_clamp 可复用）；.bak_srcanim 回滚点保留在 models/。

### iter19：无 jmap 31 只自动建映射注入（dgm_automap 权重相关法）

- **需求**：33 只「有 CS 动画 fbx、无 jmap.json」单位（早前盘点 31+2 边界）。绑定批次时 jmap 只给走 keep 模式的 67 只写过；其余靠 rig2 几何重建权重，没有源→目标骨表。
- **方法**（tools/dgm_automap.py）：不猜骨名/位置，直接**蒙皮权重相关**——源 GLB 与 bound.glb 是同一块肉，把目标顶点 NN 匹配到源顶点（归一化空间），对每个源骨 s 求 argmax_t Σ_v w_s·w_t。姿态/骨原点差异免疫（flesh-to-flesh）。
- **自检**：对账有真值 jmap 的 4 只——agumon 23/23、dorugamon 37/37、garudamon 41/42、mastemon 94/103、omegamon 31/34。定向自验证：源 GLB 朝向各异（实测 zup+/zup-/raw 三种并存），4 候选朝向取 NN 中位距最小者，nn_med 全 0.0（顶点同序同位）。
- **结果**：33 只全建图（src 关节映射率 80~95%，tgt_used 11~30/72~95）；31 只注入成功各 10~13 条 src_*；2 只 FBX v6100 Blender 拒收（apocalymon chr328、omegamonm chr448）只建图未注入。
- **注入链复用**：dgm_srcanim_inject.py 改读 dgm_srcanim/<u>/map.json（无则回退 jmap.json），Z-up 微缩 FBX 世界矩阵 C4·m·C4ᵀ 共轭照旧。
- **抽验**：gatomon/metalgarurumon/seadramon/hououmon 各 4 帧 montage——钢狼站姿/蛇身盘地/凤凰飞扑成立；**gatomon 紫色巨刺**=目标侧权重债显影（J_tail03-05→upperleg_right 尾肉挂腿骨 + J_head→eye_left 头挂眼骨，与 rosemon B9 槽塌缩同族，自动图只是如实镜像）。metalgarurumon 红翼为原生导弹舱件随动正常。
- **目标侧权重债清单**（自动图如实镜像出的绑定重建缺口，归 B8/B9 同类工单）：gatomon(head/jaw→eye, tail→upperleg, ear/whisker→shoulder_pad)、gabumon、taomon、growlmon(tail→upperleg, head→eyebrow)、shinegreymon(tail→upperleg)、zeedmillennium(g_head→eye)、aerovdramon、weregarurumon 部分； wing→feather/fin、armor→leg 等语义对匹配为误报不误修。
- **矩阵**：全库 2544 clips 1747P/797W/0F（scratch/matrix_srcauto31.json），含新增 31 只零失败。
- **累计**：82/104 只已带原生 src_*（51 jmap + 31 automap）；剩余 22 只：4 无 fbx/jmap、2 fbx v6100、16 有 jmap 无 fbx（多为 NxO/其他源单位）。

### iter20：评分卡 v3.2 回归底座（skitter 双批六件销账后全量重排）

- **输入**：fix_b8_residual（jesmonx 踝簇 t-split 334v/apocalymon 幻影尾链 1380v/kabuterimon 回植 1509v）+ fix_v31_batch 高承皮族零权回植（omegamonab 641v/chaosdramon 1551v/jibian 200v）+A8 garurumon TANGENT +A9 fujinmon 装饰骨归位。
- **聚合升级**（scratch/pipeline/dgm_audit/score_card.py）：post 修复 headless 档三层覆盖（hl_tinkermon_corr/b8r/v31 post > fix_wave > 全库档）；SKIN_OVR 修复后实测承皮率×8；MTX_OVR lost_share 实测（omegamonab 91.3→8.7%）；B8 残域判序修正（部署级销项/LOST 足额回收先于残域字判定）；worst20 表加 E1/E2 池标注列。
- **结果**：均值 v3.1 72.1→v3.2 72.5；worst5=jibian(56，B13+B4 扣 24 在账）/mastemon(56)/chaosdramon(58)/seadramon(59)/blitzgreymon(59)；六修件全出榜（kabu 53→71、apoc 49→66、omegab 52→69、jesmonx 46→62）。
- **产物**：scratch/pipeline/dgm_audit/score_report_v3_2.md + score_card.json v3.2；LATEST/LEDGER 已同步。

## iter123 复合骨架手术·gatomon 全链路打通（权重债修复首个成功案例）

### 病灶定性
hu1 人形骨架（72 骨）缺尾/耳/须等解剖骨，automap 只能照抄坏权重（尾肉挂 upperleg、头挂 eye）——判定为**目标侧骨架债**，非映射错。

### 方案（tools/dgm_featbone.py，新增通用工具）
1. 特征族审计（FAM_PATS）→ 无 tgt 对应骨的 src 解剖骨新建 feature bone（gatomon：tail_0..4、ear_l/r_0..1、whisker_l/r_0 共 11 根，命名按链序基→梢）
2. 绑定姿态 （src IBM 逆变换直达 tgt 空间）；**静态 node.scale 承载 src 关节尺度约定（0.01）——丢了会让 IBM×100 放大顶点**
3. 全量权重重建：NN 肉对肉（nn_med=0）取 src 权重经语义修正 map 翻译进 tgt
4. 注入驱动：**逐骨桥 K_i = C_glb·B_i·rest_i⁻¹**（map /），注入器 （Ĝ 按 det(rest)/det(G) 归一化线性部分——dump 帧与 rest 尺度约定可差 100 倍）
5. glTF 局部矩阵分解：轨道写 T·R，node.scale 静态吸收尺度；父级全矩阵逆（不再 Wq.T）

### 关键数据事实（复用价值）
- 同一模型多份源 GLB 的 IBM 尺度约定可不同（salzaar det=1e-6 vs pub_src det=1）→ **按 det(B)≈det(rest) 挑源文件**，选错则 G·λ 把顶点压塌
- dump rest（1e-6）与 anim 帧（1e-12）尺度约定不一致 → 逐帧 det 比归一化
- rest_i = T(+29.46y)·B_i（近似纯平移）——“姿态差”实为骨架原点偏移

### 验证
- 绑定帧恒等检验 err=0.0/3265 顶点
- 工作室实拍：src_attack01 正面完整迪路兽（猫脸/大耳/紫爪红纹/张嘴 jaw 生效）；move 四肢+高卷尾（源动画尾尖位移 1.6 正确）；idle 直立
- selfCheck：32 clips **0 FAIL**（whisker 映射规则补进 importer.js:700）
- 证据：tabbit task-6d2e2a74 shots（attack01 正面、move×2、win、down、idle 侧/后、eat）

### 遗留
- whisker 细刺方向与尾附着视觉待微调； 投票在此案为 true（L/R 视觉正确）
- 推广：64 只特征骨债清单按族推进（gabumon/growlmon/taomon/翼族/蛇形鳍族）
