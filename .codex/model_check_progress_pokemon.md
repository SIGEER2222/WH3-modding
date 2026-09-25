STATUS: DONE（L4 跳过：Warhammer3.exe 运行中；mod_output 已重打，data\ 待游戏关闭后部署）

# 模型检验台账 — zzz_czx_pokemon（7 只）

包：`zzz_czx_pokemon.pack`（部署名同名；**注意：data\ 当前是修复前旧包**，修复版在 mod_output/zzz_czx_pokemon.pack，游戏运行中不能写 data\）
单位清单权威：ROSTER.tsv（mod_files/zzz_czx_pokemon/ 根下）+ 7 个 vmd。
骨架族：czx_bu(wf1,妙蛙种子) czx_ve(wf1,妙蛙花) czx_charma(hu1,小火龙) czx_chari(dr1b,喷火龙) czx_squirt(hu1,杰尼龟) czx_blasto(hu1,水箭龟) czx_pikach(hu1,皮卡丘)

## 单位台账
| unit | L0 | L1 | L2 | L3 | L4 | 问题/修复 | 状态 |
|---|---|---|---|---|---|---|---|
| pkm_001_bulbasaur 妙蛙种子 | ✅ | ✅ | ✅ | ✅🔧 | ⏭无游戏窗口 | 权重 L/R 镜像已修 | ✅ |
| pkm_003_venusaur 妙蛙花 | ✅ | ✅ | ✅ | ✅🔧 | ⏭无游戏窗口 | 权重 L/R 镜像已修 | ✅ |
| pkm_004_charmander 小火龙 | ✅ | ✅ | ✅⚠ | ✅🔧 | ⏭无游戏窗口 | 权重 L/R 镜像已修 | ✅ |
| pkm_006_charizard 喷火龙 | ✅ | ✅ | ✅⚠ | ❌→✅ | ⏭无游戏窗口 | 权重 L/R 镜像已修（修复前 attack/death/guard/idle 顶点撕裂） | ✅ |
| pkm_007_squirtle 杰尼龟 | ✅ | ✅ | ✅⚠ | ✅🔧 | ⏭无游戏窗口 | 权重 L/R 镜像已修 | ✅ |
| pkm_009_blastoise 水箭龟 | ✅ | ✅ | ✅⚠ | ✅🔧 | ⏭无游戏窗口 | 权重 L/R 镜像已修 | ✅ |
| pkm_025_pikachu 皮卡丘 | ✅ | ✅ | ✅⚠ | ✅🔧 | ⏭无游戏窗口 | 权重 L/R 镜像已修 | ✅ |

（状态：✅通过 / 🔧已修待复验 / ❌未修阻塞 / ⏭跳过(原因) / 空=未检）

## iter 1 备注
- L0 结果（scratch/model_check/pokemon/l0_result.txt）：
  - vmd→wsmodel→rmv2→material→dds 全链 7/7 OK；skeleton .anim + .bone_inv_trans_mats 7/7 OK
  - animpack `zzz_czx_pokemon_animsets.animpack`：7 bin、内名正确、bin 内 .anim 引用 0 缺失（43/43/261/51/261/261/261）
  - pack↔source 差异均属预期（tsv 编译去扩展名、rpfm_reserved、ROSTER.tsv/notes/preview 不进包）；源码目录有游离文件 `db/units_custom_battle_permissions_tables/!!pkm_pokemon.tsv.bak_western`（不进包，暂不动）
  - 已知设计：hu1 系 4 个 bin 内部套件名均为 `hu1_empire_sword_and_shield`（9-23 matched-combat 修复——同名套件多 bin 是否致剪辑错绑仍需 L4 验证）
  - `building_units_allowed` 空表属正常——招募在 `zzz_czx_vmp_pokemon_unlock` 包
- L4：Warhammer3.exe PID 33560 运行中，本轮跳过

## iter 1 L1–L3 结果 + 权重镜像修复（2026-09-23）

- **L1 静态渲染 7/7 ✅**：全部带贴图、形态正确可辨认（Bulbasaur 蒜头+叶片尖、Venusaur 背树、Charizard 翼尾、Squirtle/Blastoise 龟壳、Pikachu 耳尾）。证据图在 `%TEMP%\modelcheck\pokemon\pkm_*_persp/front/side.png`。
- **L2 骨架叠加 7/7 ✅⚠**：骨架均在体内、头尾方向正确；两个已知松动：
  - hu1 系（charma/squirt/blasto/pikach）腿骨绑姿比网格腿长，脚骨端伸出脚底到地面下约 0.3-0.45（czx_pikach 骨 Y 范围 -0.46..0.37 vs 网格 0..0.51）——刚性蒙皮下网格脚仍在地面，但激进帧脚下陷最深约 -0.17，RTS 距离下可接受。
  - czx_chari 翼骨链超出翼膜缘、腿长杠杆偏大（翼尖骨 ~±1.04 vs 网格翼缘 ~±1.2 内侧），属先天绑骨比例。
- **L3 动画 40 条 GIF**：walk/guard/attack/death/idle/getup 全生成、逐帧 pose 解析成功（pose.json 在 scratch/model_check/pokemon/poses/）。
- **修复前实测 ❌（已修）**：charizard 在 dr1b_attack/death/guard/idle 中网格撕裂成碎片。根因 = **RMV2 权重绑定 L/R 全镜像**：所有 *_left/*_right 侧骨的顶点全部绑到对侧（7/7 单位、~21k 顶点侧骨权重对位 100% 反向；vanilla 同骨架 archer body 对照 0/2847 反向）。顶点离所绑骨轴心达 2×肩宽/翼展，攻击类剪辑中顶点被甩出体外。
  - 修复：scratch/model_check/pokemon/fix_lr_mirror.py —— 对每个顶点 bytes[8:12] 的 joint 索引做 _left↔_right 重映射（骨骼/材质/面序不动）。
  - 修复后量化验证：charizard attack f16 撕裂边(>3x)占比 6.4%→0.6%，Y 范围 -1.55..1.20→-0.11..0.95（不再入地）；charmander walk 2.7%→1.0%；vanilla dragon 同剪辑基线 0.1%。
  - **注意：若日后重新导出这些 RMV2（PM→RMV2 管线重跑），该修复会丢失，需重跑 fix_lr_mirror.py**。
- L3 修复后复验：40 GIF 全部连贯，getup 卧→起、death 倒地、attack 突进均正常，无顶点飞散。
- audit_dangling_refs：0 ERROR / 7 WARN（units_custom_battle_permissions 引 `wh3_main_cth_the_northern_provinces` 不在 vanilla custom_battle_factions 集——与 ia_all_factions/dgm_patch/digimon 同款写法，战役派系确实存在，WARN 可接受）。
- pack 内残留 `_tex_bak/`（7 张备份 dds ~1.9MB）：非阻塞，纯冗余，下次整理时可删。
- **遗留**：data\ 部署包仍是修复前版本；游戏关闭后跑 `tools/build_pack.py zzz_czx_pokemon --deploy` 完成部署并做 L4 实测。

## iter 2 — GLB 资产污染源排查（建模工作室验收衍生）

用户怀疑现有 pm GLB 被本地转换脚本污染，要求"重新下载模型"。排查结论：**原始下载源是 Unity 工程压缩包，不是 GLB**——
scratch/pokemon_home_models.zip（966MB，GitHub Pokemon-HOME-Unity-Models，107k 文件，内容全为 .mat/.asset/.prefab/.png/.anim 序列化资产，**包内零 GLB/FBX**）。解压副本在 scratch/pokemon/01rg/（sandbox 下有 Unity 序列化 Avatar/Skin .asset + 原生贴图 PNG）。

现有 scratch/pokemon/pm####_00_00.glb 是从 Unity .asset 网格导出的中间产物，**skin 的 IBM 平移分量全为 0（transl span=[0,0,0]，det=1 恒等）**——即"手搓 pmXXX rig、绑定姿态即炸顶点"的病根在导出阶段就已注入，是源转换产物问题而非后续污染；pm_batch.py 的存在本身就是为这个缺陷兜底（其 docstring：IBM path gives ~zeros on PM rigs）。

**干净等效资产 = scratch/pokemon_batch/pkm_*/pkm_*_bound.glb**（经 digimon 管线重绑到 vanilla 家族骨架：charizard→dragon01b 134节点/IBM transl span≈10.8、pikachu→biped 77节点、bulbasaur→quad 47节点），蒙皮 IBM 正常、贴图内嵌。

建模工作室（E:\Code\model-studio，iter 23 口径）实测：charizard_bound/pikachu_bound/bulbasaur_bound 均 **17/17 自动映射**、直立贴地、贴图正常、DSL 回旋斩驱动正常、__errs 空——干净资产无任何导入侧问题。原始 pm GLB 的 Z-up+2cm 骨架+零 IBM 缺陷属资产先天问题，不需要"重新下载"（上游也没有干净 GLB 可下）。
