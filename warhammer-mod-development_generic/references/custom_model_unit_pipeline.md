# 外部模型 → 自造兵种完整管线

本文件记录"用户提供一个 `.glb` 模型文件，到游戏里能招募、能动、数值合理的新兵种"的端到端流程。与 `unit_creation_workflow.md`（纯 DB 派生单位）互补：本文档覆盖**自定义网格资产**一侧。

适用前提：工作区 `tools/` 下已有以下脚本（本项目在 `E:\Code\WH3-modding\tools\`）：

| 脚本 | 用途 |
|---|---|
| `blender_rig2.py` | Blender 无头：建骨架 → 导入 GLB → 拓扑感知蒙皮 → 导出 skinned GLB（首绑/供体缺失时） |
| `transfer_weights.py` | **供体权重转移**（首选）：原版同骨架 RMV2 → 我们 GLB 的 JOINTS/WEIGHTS，纯 numpy/trimesh 不开 Blender |
| `rigidify_core.py` | 球状躯干性化：`--ymin` 以上顶点刚性绑最近躯干骨（爆虫大球囊专用） |
| `dump_donor_groundtruth.py` + `blender_donor_render.py` | **地面真值渲染**：原版供体+真 CA 权重过同一渲染管线——先证渲染器可信，再谈权重好坏 `[实测]` |
| `convert_new_units.py` | skinned GLB → RMV2 v8 + DDS + wsmodel + material + variantmeshdefinition |
| `add_inf_units_db.py` / 生成脚本 | land_units/main_units/variants/loc/招募建筑等 DB 行 |
| `gen_new_unit_cards.py` | 单位卡 PNG（60×130）+ infopic |
| `build_pack.py` | `mod_files/<mod>` → `.pack` |
| `parse_anim_skeleton.py` / `parse_anim_clip.py` | 解析 `.anim` 骨架/动画片段（v7/v8 含 bitrate 压缩） |
| `blender_pose_render.py` / `blender_render_rmv2.py` | 无头渲染：绑定姿态 / 摆动画姿势截图 |
| `blender_pose_anim.py` + `make_unit_anim_gifs.py` | 无头动画逐帧渲染 + GIF 组装（评审用动图） |
| `export_gamedata.py` | 读游戏 pack 条目（支持压缩条目解压） |
| `unity_bundle_extract.py` | Unity AssetBundle → 原始资产（Texture2D→PNG、Mesh→OBJ、AnimationClip→JSON） |
| `unity_smr_to_glb.py` | Unity AssetBundle → **带骨架蒙皮 GLB**（按根层级逐 prefab 导出，嵌贴图；产出即本文档管线入口 GLB） |
| `dgm_pub_convert.py` / `glb_reorient.py` / `normalize_scale.py` | 公开模型源批转：站点归档→GLB、关节位自动定向、对齐旧 mesh_h 缩放 |
| `wh3_export_unit_glb.py` | **原版单位→GLB 导出**（pack→VMD→RMV2→GLB 含真骨架+权重+clip，进模型工作室当蒙皮质量基线） |

## 端到端流程

```
用户 GLB
  → 1. 检查 GLB（顶点数/贴图/是否已带骨）
  → 2. 选骨架（形态对照表）→ blender_rig2.py → skinned GLB
  → 2b. 供体权重转移 transfer_weights.py（同骨架原版 RMV2 → CA 手工权重）
  → 3. convert_new_units.py → RMV2 v8 + 贴图 + wsmodel/material + VMD
  → 4. DB 生成脚本 → land/main_units/variants/unit_variants/描述/招募/loc
  → 5. 数值对标原版供体（见 tsv_format.md「新单位数值对标法」）
  → 6. 技能/属性：复用现有链或按列名克隆原版链
  → 7. gen_new_unit_cards.py → 图标
  → 8. build_pack.py → 部署 data 目录
  → 9. AssetEditor 日志验证骨架加载（或二进制读 RMV2 头 offset 12）
  → 10. blender_pose_render 多帧动作截图验收
  → 11. Mod Manager 游戏内实测
```

## 1. GLB 入库前检查

- **Unity 系游戏 MOD 是现成模型源**：创意工坊 MOD 用 `steamcmd +login anonymous +workshop_download_item <appid> <itemid> +quit` 匿名拉取（例：部落与弯刀「数码宝贝1.0」= appid 1094520 / item 2011281573，已存 `E:\Tools\steamcmd\steamapps\workshop\content\1094520\2011281573`，解包产物在 `scratch/salzaar_digimon/glb/`——104 只数码兽、491 个带骨蒙皮 GLB）。Unity 打包后原始 FBX/DAE 已序列化为引擎对象，**不是源文件**——必须走 `unity_smr_to_glb.py` 重建：蒙皮权重在顶点流 channel 12/13（BlendWeight/BlendIndices，非 m_Skin），骨架按 SMR.m_Bones→Transform 层级重建，容器 path 只指向主对象（fbx 主对象是 Avatar 不是根 GameObject），用根 GO 名回查资源目录 `[实测]`。
- 先拷到 `scratch/` 用 **ASCII 文件名**——bash/Python 管道传中文路径给 Blender 会乱码。
- `blender_render_rmv2.py`（或同套 GLB 渲染脚本）先出绑定姿态图，确认模型形态、朝向、比例，再决定骨架。
- 用户模型不精致没关系——先保管线通，美术问题后期再调。

## 2. 骨架选择

按**形态**选动画集，不按名字猜。本项目实测映射 `[实测/需随版本复查]`：

| 模型形态 | 骨架 | 参考单位 |
|---|---|---|
| 普通双足人形 | `humanoid01b` | 多数步兵/英雄 |
| 2.4m 宽体人形 | `humanoid06` | 牛头人级怪步 |
| 9m 级巨兽（佝偻指行） | `humanoid11b` | Ghorgon |
| 多足爬虫/球腹虫 | `spider01` | 巨蛛 |
| 多足蟹形兽 | `crab01` | 腐烂普罗米修斯 |
| 四足猛兽 | `bigcat01` | 战神獒（73 个 clip） |
| 四足重装巨兽（鞍座） | `heavyquadruped01` | 野生三角龙 Stegadon |
| 车辆/战争机器 | `steamtank01` | 蒸汽坦克（25 骨，含 barrel_*/wheel_*/exhaust_*） |
| 恐狼形 | `wolf01` | （338 个 clip） |
| 蝎形 | `scorpion01` | 古墓巨蝎（138 clip） |
| 飞鸟 | `bird01b` | 鹰/凤凰系 |

补充实测 `[实测/需随版本复查]`：

- `heavyquadruped01` 骨架包围盒被 howdah/鞍座骨拉高（y 0..7.2 但腿区只到 ~2.6），fit 轴要用 `x`（体宽）而非 `auto`，否则模型被过度放大、腿骨区绑不到权重。
- `steamtank01` 的车辆"炮管/排气管"骨可以借给模型的长颈/尾状突起——绑定后会随开火后座/行进动画摆动。
- donor RMV2 里没有的骨架可去 `warmachines.pack`（蒸汽坦克在 `warmachines/engines/emp_steam_tank/`）。

骨架候选可先扫 anim pack 提取 `.anim` + `.bone_inv_trans_mats` 边车，用 `parse_anim_skeleton.py` 看骨骼规模。**注意：pack 里部分条目是 ZSTD/LZ4 压缩的**（magic `28 b5 2f fd`），`export_gamedata.py` 已处理解压，手工 extract 时注意 `[实测/需随版本复查]`。

## 3. 蒙皮绑定

### 3a. 首选：原版供体权重转移（transfer_weights.py）`[实测]`

**凡是有同骨架的原版供体 RMV2，一律走权重转移，不要再手写几何蒙皮**。CA 手工权重天然贴合骨骼语义（腿骨管腿、躯干骨管壳），比任何"最近骨段"启发式都好一个量级。

```
python tools/transfer_weights.py <donor.rmv2[,donor2.rmv2,...]> <skinned.glb> <skel.json> [--mode face|knn] [--k 8]
```

原理：同骨架 ⇒ 同一骨骼索引空间（RMV2 boneidx 直接索引骨架 .anim 骨骼表）。把我们 GLB 顶点 **bbox 归一化进供体包围盒**，默认 `--mode face`：trimesh 最近面查询 + 重心坐标插值三角面三顶点权重（连续权重场，同 Blender data transfer 思路）→ top-4 截断归一化 → 沿网格面邻接 3 轮投票平滑。`--mode knn` 是旧版顶点投票（保留对照）。

要点 `[实测]`：

- **必须 bbox 归一化**（脚本内置）：我们 fitted 网格常比供体大 2-3 倍（畸变体 6.6m vs 兽主 2.05m），不归一化会把顶部尖刺映射到供体头顶 → 头骨一动整柱翻折。
- **供体覆盖要全**：hu1b 原版单位全是 head/torso/legs 分件——单件供体只覆盖局部（sorceress body 只有 y0.83-1.47 上身），多件合并成全身供体。选**贴身少布料**的单位（wardancers 优于长袍法师——披风布料骨是撕面元凶）。排除 weapon/shield/cape/hair 件。
- **RMV2 v32 顶点有两种布局**：pos f32×3@0+boneidx@12+bonew@16（兽主）或 pos f16×3+pad2@0+boneidx@8+bonew@12（Ghorgon）。脚本按 f32 解码后做合理性检查（|pos|>1000 → 切 f16 布局）。
- **bonew 的 0xFF 空槽**要清零（Ghorgon 文件里大量 boneidx=255 填充位）。
- **球状躯干单位**（爆虫）：球囊表面离腿骨段比离躯干链更近，NN 转移把球囊剪碎。转移后跑 `rigidify_core.py --ymin <球囊底高>`，把球囊区全部刚性绑 rear/spine 躯干骨，腿保留转移权重 `[实测]`。
- **先做地面真值渲染再评判权重**：`dump_donor_groundtruth.py` 把供体 RMV2 导成静态 GLB+权重 NPZ，`blender_donor_render.py` 建骨架、应用真 CA 权重、过同一动画渲染——若原版都碎说明渲染/姿态管线有错，若原版丝滑则差异纯在权重 `[实测]`。
- **外部正经路线**：AssetEditor Kitbash Editor 支持导入网格→re-rigging（骨骼 1:1 映射）+ Fit mesh to skeleton + 实时动画预览，适合单个单位的精修；自动化批量仍走本管线 `[实测]`。

### 3b. 备选：拓扑感知蒙皮（blender_rig2.py）

供体缺失或异形骨架时用。**不要用旧的 `blender_rig.py`**——v1 纯空间距离算法，薄片甲壳/刃臂被邻近无关骨撕碎 `[实测]`。

v2 算法（拓扑感知）：

1. 最近骨段 → 每顶点初始归属（owner）。
2. **沿网格邻接做 4 轮多数投票**平滑标签——消灭孤立错配和跨身抢夺，骨权区域跟随表面拓扑。
3. 把 one-hot 归属向量沿邻接扩散 3 轮——只在区域边界产生渐变权重，内部保持刚性，关节过渡自然。
4. 截断到 top-4 权重并归一化（RMV2 weighted4 上限）。

不要尝试 `bpy.ops.object.parent_set(ARMATURE_AUTO)`（Blender 自带测地线体素蒙皮）：对非流形游戏网格直接报 `Bone Heat Weighting: failed to find solution`，全顶点零权重 `[实测]`。

- **必须启用装饰骨黑名单**：`skirt_*/cape_*/belt_*/platform_section_*/feather_*` 等布料/挂载/羽毛骨在动画里独立甩动，抢到权重必撕裂 `[实测]`。
- 脚本内置通用黑名单（`prop|cape|skirt|platform|finger|be_|feather|hair|weapon|attach|slot|mount` 等）；骨架特有装饰骨用第 5 个可选参数追加排除正则，如 hq1 的 `skulls_*`（鞍座吊骷髅）/`pole_*`/`gut_*`/`belly_*`/`tongue_*`/`eyelid_*`、`hu11b` 的 `eyelid|eyebrow`、`hu1` 的 `eyebrow|eye_|jaw`。绑定前先 dump 骨架 bone 名单对照检查 `[实测]`。
- **`animroot` 必须永远在黑名单里** `[实测 2026-09-26]`：绑到原点的顶点在身体离地动画（腾空/跳跃/飞扑）时原地不动、和躯干之间拉成细丝。已修两处：内置排除正则含 `animroot`；keep 权重快照里也单独剥掉 animroot 列（双保险——Blender glTF 导入会把全零权重行规整成 joint0=1.0=animroot，只在 weightmap 端清零不够）。症状画像：bound.glb 顶点审计 `animroot` 主导顶点 >0 = 必出问题（数码兽 104 只曾 92 只中招）。
- **keep 模式（argv[8] `'keep'`）保留源美术权重** `[实测 2026-09-26 修复后真正生效]`：输入 GLB 自带以**目标骨名**命名的顶点组（`glb_bindspace.write_glb(weights=, bone_names=)` 产出的合成 skin，源 JOINTS 先经 jmap.json 映射到目标骨索引）。顶点组被保留的顶点跳过自动绑，用源权重——披风/翼/武器等非人形件靠它避免最近段撕裂。关键实现坑：
  - bake 循环里 `o.vertex_groups.clear()` 会先于 keep 快照把权重清光——keep 模式必须跳过该行（此 bug 曾致 `weightmap override verts: 0` 全失效，旧管线跑了很久没人发现）。
  - Blender 4.5 `VertexGroupElement` 字段是 `.group` 不是 `.index`。
  - jmap 里映射到 helper 骨（animroot/未映射名→lut 兜底 animroot）的顶点会被剥光→自动回退 auto-bind，等于"jmap 只管它能管的，剩下自动补"。
- **jmap.json（源骨名→目标骨名）是单兵修型的主要旋钮** `[实测]`：放单位工作目录 `<unit>/jmap.json` 即被 batch 拾取。写法定参：主肢体链按解剖对应（J_arm→upperarm 等）；披风/mantle 链映射到骨架的 `cape_*` 链（骨架有的话，比塌到躯干骨好——披风骨在动画里真的会动）；武器 `J_wep*`→`hand_right/left`（刚性跟手，武器不会钉地/跟脚）；helper 节点（chr###/GRP_*/Ef_*/*Target）→`animroot`（反正会被剥掉→auto-bind）。被排除骨也能吃 keep 权重（keep 不看 weightable 名单），所以可以把源权重直接指到 cape/skirt/weapon 骨上。
- 绑定产物：`<unit>_skinned.glb`（`tools/_out/`）。
- 第 6 个可选参数 `save.blend`：绑定后把 骨架+网格+权重 存成 `.blend`，供人工 Weight Paint 微调——改完 File→Export→glTF 2.0（GLB，勾 Skinning）→ 重跑 convert+pack。本项目产物在 `manual_edit/`。
- 第 7 个可选参数 `yaw_deg`：fit 前绕竖直轴旋转网格（网格朝向与骨架不一致时用）。**必须用顶点半径渲染验证**——早先版本用 `transform_apply` 在 `-b` 后台模式静默失效（日志打印 yaw applied 但顶点没变）；已改为直接 `mesh.data.transform` `[实测]`。
- 第 8 个可选参数 `rules_json`（JSON 串或 .json 路径）：**空间区域→骨骼白名单**规则，修"突起部位被近处无关骨抢权"。在初始归属后、平滑投票前强制改写：
  `[{"name":"head","when":[{"axis":"z","op":">","pct":68},{"axis":"y","op":">","pct":55}],"allow":"neck|head|gullet"}]`
  轴为游戏空间（x 横向 / y 竖直 / z 前向），pct 为该轴百分位阈值，多个 when 取交集；命中的顶点改绑 allow 正则圈定骨中最近者 `[实测]`。
  - 本批实例：暴龙兽头/角 `z>68pct & y>55pct → neck|head|gullet|clav|spine`；尾 `z<18pct → tail|spine_0|root`；枪兵臂炮 `z>78pct & 35<y<78pct → lowerarm|hand|upperarm|clav|spine_2`（修好枪管跟腿甩的问题）。
  - 先跑 `diag_rig2.py` 看"区域顶点→主导骨"分布再写规则；轴向定义别搞错（游戏是 **Y-up**！）。
- ⚠️ `exclude_regex` 传空串 `""` 会编译成"匹配一切"的空正则把全部骨禁掉（weightable 0/N，所有顶点堆到 bone0 且完全不动）——不传或传真实正则 `[实测]`。

### 3c. 定制贴合骨架（fit_skeleton.py + retarget_clip.py）`[实测]`

**当模型解剖/姿态与原版骨架差异大时**（如俯身虫族 vs 直立人形），最优路线是给模型定制骨架：借模板骨架的骨名/层级，按模型实测界标重摆关节位置。

```
blender -b -P tools/blender_grid_views.py -- <glb> <out_prefix>   # 0.25m 网格三视图读坐标
# 手写 scratch/landmarks_<u>.json: {骨名: [x,y,z]}，只标关键骨（落足点/头/爪/躯干链）
python tools/fit_skeleton.py tools/_skel/<template>.json scratch/landmarks_<u>.json scratch/skel_czx_<u>.json
blender -b -P tools/blender_rig2.py -- scratch/skel_czx_<u>.json <skinned输入.glb> <bound.glb> nofit <exclude_re> <save.blend>
python tools/retarget_clip.py <原版clip.anim> scratch/skel_czx_<u>.json <out.anim> --pose <pose.json> --delta tools/_skel/<template>.json --ref frame0
blender -b -P tools/blender_pose_anim.py -- <bound.glb> <pose.json> <skel.json> <outdir> <step>
blender -b -P tools/blender_skel_overlay.py -- <bound.glb> <out.png>   # 网格+骨骼叠加验收图
```

关键坑 `[实测]`：

- **坐标空间必须一致**：landmarks 是在 `_out/<u>_skinned.glb`（已放大到游戏尺寸的空间）上读出来的，`nofit` 模式的绑定输入也必须是同空间的 glb——把 `_out` 皮肤文件直接喂给 rig2 即可（v2 已内置剥旧蒙皮：删导入的 armature、清顶点组/ARMATURE 修改器，否则同名顶点组变 `.001` 丢权重）。**喂 raw 源 glb 会出现"骨架比模型大 3-5 倍、顶点全堆中央骨"的假象**——刚体化、跟随 root 飞走。
- **`nofit` vs `auto`**：`nofit`=骨架已贴合、网格不动；`auto`=按骨架最大轴等比放大网格并对中——只能用于粗对齐，比例不同会错位。
- **v7 clip 自动转 v8**：retarget_clip.load_clip 已内置 v6/v7→v8 转换（f32 轨道→bitrate 12/8，映射表 >=10000→static 槽）。hu11b/cr1 等骨架的 clip 是 v7 `[实测]`。
- **跳扑类 clip 可能不适合重定向**：`sp1_jump_attack_01` 把贴合骨架叠成一根杆（估计有 launch/root 特殊轨道），换普通 `sp1_attack_01` 即正常——挑 clip 时多试一个备选 `[实测]`。
- **浑身是刺的球状模型**（莽兽）：密集骨+尖刺面必攒球。方案=rig2 排除装饰链后跑 `rigidify_core.py <bound.glb> <skel.json> <躯干骨列表> --ymin <壳底高>`——上半身整壳刚性绑脊柱/壳骨，只腿参与混合，模型按整体移动 `[实测]`。
- **动画集=fragment JSON**：`animations/database/battle/fragments/<key>.txt` 是解压后的 JSON（`Properties.SkeletonName` + `SlotData.<SLOT>.Entries.#01.animation` 路径）。MOD 可新写 fragment 文件定义整套动画槽——这是自定义骨架进游戏的接入点 `[实测/需随版本复查]`。
- **`man_animation` 键→fragment 文件名**直查：`hu6_gor_dual_axe`→`hu6_gor_dual_axe.txt`；注意有例外（`hu11b_dlc17_ghorgon`→`hu11b_ghorgon_base.txt`），映射在 `animation_tables.animpack` 里 `[需验证]`。
- **必须 `--delta` 走世界增量重定向**：裸 `retarget()` 把供体 clip 的绝对局部旋转照抄——只要我方绑定姿态≠供体绑定姿态（异形几乎必然），肢体就绕错误的轴折进身体里，"idle 全程前倾弓背"（暴龙兽实测）。`--delta <供体_skel.json> --ref frame0` 把"供体每帧世界旋转增量"叠到我方绑定世界朝向上，我方剪影不变、只借运动 `[实测]`。
- **fit_skeleton 已加朝向重瞄**：移动关节后每根骨的世界四元数按"指向延续子骨"做最短弧 swing 旋转（链末端骨随父 swing 刚性跟随），写入 `world_quat_frame0` 并重算 local。旧版"quats 沿用模板"会让骨局部轴指向供体的肢体方向——是 delta 重定向生效的前提，也是绑定图里骨柱方向的依据 `[实测]`。
- **模型可能本身不对称/偏轴**：AI 生成模型常见左右爪大小不同、中轴偏离 x=0。落点界标前先实测网格（侧向极值、近地顶点聚类、中轴 x 偏移），**每侧按实测足位独立放界标、中轴骨放到实测中线**——对称界标放在歪模型上叠加图必歪（暴龙兽实测：右爪 x+1.47 vs 左爪 -1.09，中轴 x+0.2）`[实测]`。
- **叠加图自验必查项**：足/头/尾落点 vs 网格实测极值数值比对 + 逐视图目检渲染图（含 top）；链末端骨的 Blender 默认 tail 画法会画出"飞出身体的假骨柱"——blender_skel_overlay.py 已改为 head→首子骨画法 `[实测]`。

#### 3c-i. 完整自洽自定义骨架接入 `[实测 2026-09-13 坦克单位]`

仅改蒙皮不动骨架时，动画 clip 的世界变换仍落在原版骨架关节点上 → 顶点绕错位置的轴心旋转 = 模型"扭曲"。彻底修法是让骨架本身贴合模型：

1. `fit_skeleton.py` 按 landmarks 重摆骨位 → `write_skeleton()` 从模板 `.anim` 生成新骨架 `animations/skeletons/<新名>.anim` + `write_invmats()` 生成 `<新名>.bone_inv_trans_mats`；`.anm.meta` 直接复制原版改名即可（内部不含骨架名）。
2. `retarget_clip.py` 把所需 clips 重定向：clip 内 `skeleton_name` 改新名、static/动态轨道写新 bind local。**注意 retarget 读 `skel['custom_name']`**——fitted JSON 里加 `"custom_name": "<新名>"`。
3. 动画集接入：`man_animation`/`gun_animation_table` 键 → `battle_animations_table`（key→skeleton 两列）→ `animations/database/battle/bin/<key>.bin`。bin 内嵌 clip 路径全集（非引用 fragment）——fragment .txt 不必提供。
   **⚠ 实测修正（2026-09-19，数码兽白模 T-pose 根因）**：loose `.bin` 放在 `database/battle/bin/` **不会被战斗系统加载**——扫遍本机全部创意工坊包（SFO/银影/arbiter 等 20+ mod）与 vanilla 数据，战斗套件**无一例外**用 `.animpack` 容器（内部嵌 `<key>.bin` 定义+骨架名+clip 路径表）；loose `.bin` 仅用于战役 agent。症状：单位进场但渲染为白色半透明占位人形、全程绑定姿势（骨架从未注册）。配套表：自定义骨架必须有 `battle_skeletons` 行（骨节点语义映射）+ `culture_to_battle_animation` 行（套件挂到文化包，**每个会用到的文化包一行**，vanilla 同套件本就映射 5+ 文化）`[实测/需随版本复查]`。`.animpack` 由 AssetEditor 生成，**或离线用 `tools/pack_animsets.py` 直接打包**（格式已逆向：u32 条目数 + 每条 {str16 内部路径 `animations/database/battle/bin/<key>.bin` + u32 长度 + bin 原字节}，文件名自由，可命名为 `<mod>_animsets.animpack`；vanilla `animation_tables*.animpack`、Imperial Arbiter `h3_yu_monsters.animpack`、数码 v1 `chr*.animpack` 均同构）；没有工具链时优先移植已验证 mod 的整套 animpack+骨架资产。**生成后离线验证法**：解析 animpack 列出全部 animset 路径并检查每个 bin 在包内存在——loose bin 集合 = animpack 条目集合时必须逐一相等。**animpack 落地后删除 loose `.bin`**：已验证工作范本（数码 v1）= 50 animpack + 0 loose bin，并存有重复注册/遮蔽风险（2026-09-23 三包补容器部署，离线解析通过，游戏内移动/攻击确认待用户实测 `[实测/需随版本复查]`）。animpack 载荷两种都认：裸表（count+str16+len+bytes，v1 格式）或 u32 解压尺寸 + LZ4 frame 包裹表（vanilla/IA 格式）。（数码兽原包 chr050/chr151 即此结构：J_* 原生骨架 + animpack + rmv2 直连 VMD）。
4. **bin 克隆技巧**：bin 全是 u16 长度前缀字符串+定长二进制字段，**选等长新名即可原位打补丁**：骨架名 `steamtank01`(11)→`czx_stank01`(11)，集名 `wm_steam_tank01`(15)→`czx_steamtank01`(15)，clip 目录 `engine/steamtank01/`→`engine/czx_stank01/`（文件名不变）。
   **致命细节（实测崩溃）**：`crab01`→`czx_ms` 这种裸词全局替换会把 `.anm.meta`/`.meta`/`animations/audio/...snd.meta` 也改名 → 引擎找不到文件崩溃。只能改两处：`animations/battle/<skel>/**/*.anim`（我们提供的 clip）和 `animations/skeletons/<skel>.anim` + 裸骨架名字段；`.anm.meta`/`.meta`/`.snd.meta`/persistent/locomotion_graphs 引用必须保留原版路径。改写时逐字节流复制——找到旧名后只写新名、**continuation 字节必须原样写回**（跳过一次文件名就把 bin 截短 2KB，结构性损坏）。
5. RMV2 头骨架名写新名（`convert_new_units.py` 支持 `rmv2_skel_name` 字段覆盖 donor 骨架名）。
6. land_units.man_animation 与 battlefield_engines.gun_animation_table 都改成新集名。

实例：被感染的坦克 = `czx_stank01` 骨架（exhaust 4 骨链重摆成颈链、barrel 簇当头炮、wheel/axel 对履带轮）+ `czx_steamtank01` 动画集（克隆 wm_steam_tank01.bin）。产物见 `scratch/_build_tank_skel.py`/`_retarget_tank.py`/`_patch_tank_bin.py`、`scratch/landmarks_inf_tank.json`。

实例（数码宝贝/人形贴合 2026-09-13）：战斗暴龙兽 = `czx_wgm001` 骨架（hu1 模板 + Unity J_* 骨点界标——源模型自带骨架位即最佳界标，映射 `J_arm/J_elbow/J_weapon→upperarm/lowerarm/hand` 等 22 点）+ `czx_dgm_wargreymon_emp_sws1` 动画集（克隆 `hu1_empire_sword_and_shield.bin`，27→27 等长；`animations/battle/humanoid01/`→`czx_wgm001/` 仅改 .anim 条目，`.anm.meta`/`.snd.meta`/`reference_poses` 保留原版）。**注意替换时只盖骨名 10 字节、不含末尾 `/`**——多吞 1 字节会截短 bin。bin 里 ~380 条 clip 路径允许缺文件（实测 marine 只发 23 条也正常），可只重定向近战核心集（stand/combat_idles/locomotion/movement/attacks/defends/reactions/deaths/knockback/knockdown/celebrate/shield_up/porthole/jumps_falls）。产物：`scratch/salzaar_digimon/skel_czx_wgm001.json`、`landmarks_wargreymon.json`、`wargreymon_wgm001_bound.glb`、验收图 `wgm001_overlay_*.png`、`pose_wgm_*/`。`convert_new_units.py` 已支持 `--mod <mod名>` 选择输出目录。

#### 3c-ii. 公开模型源批量管线（数码宝贝 v2，104 只全量 2026-09-25/26）`[实测]`

场景：成批换源（Salzaar 解包模型有缺陷 → The Models Resource/Spriters Resource 公开带骨模型）。链路：

```
站点 zip（curl 需 UA；CF 直链可在浏览器侧用 tabbit 原生下载事件落盘）
  → 解压盘点 → dgm_pub_convert.py 转 GLB（优选 DAE>二进制FBX，ASCII FBX 常坏）
  → glb_reorient.py 按同名关节位自动定旋转（err=0 = 与旧骨架逐点重合）
  → normalize_scale.py 归一化到旧 mesh_h（源模型尺度差异巨大，必须做）
  → index.json 登记 digimon→文件映射（CN_ALIAS 补别名）
  → digimon_batch.py --glb-dir scratch/dgm_pub_src/glb 全链路
```

单兵覆盖旋钮（`digimon_batch.py` 内表）：`GLB_OVERRIDE`（多形态包挑件/回退旧源）、`TEX_OVERRIDE`（FBX 丢贴图时指外部 PNG→DDS）、`BIND_YAW`（朝向修正）、jmap.json（见 §3b）。**改源/改映射必须删 `world.glb`+`bound.glb` 并清 `report.json` 对应 phase**——world.glb 只在不存在时重建，相位 done 会静默跳过 `[实测]`。

批量 jmap 策略 `[实测]`：biped 族搬旧 jmap（骨架无翼/披风骨，旧映射把附肢塌到躯干，比 auto-bind 散到腿/趾好）；骨架自带对应骨的族（bird 有 wing_*/feather_*、quad 有 tail_*）**不搬**——旧 jmap 会把翼顶点塌到 neck/leg 反而退化。骨架含 `cape_*` 链的 biped 把 `J_mant*` 重指披风骨。

**工作室 QA 闭环**（AI 迭代单兵修型的可行回路）：`bound.glb` 拷进 `model-studio/models/` → 程序化动作库播极端 clip（腾空必杀/俯冲）→ tabbit 截图 → 顶点审计（`glb_bindspace` 读 JOINTS_0/WEIGHTS_0 数主导骨分布：animroot>0、披风顶点落腿/趾 = 病灶）→ 改 jmap/排除规则 → 单兵 `--units` 重绑 → 复截。原版导出模型（`tools/wh3_export_unit_glb.py`，pack→GLB 含真骨架权重）放同目录当**流畅度基线**——CA 官方蒙皮在工作室里丝滑即证明骨架/动作库没问题，差异纯在权重映射 `[实测]`。

关键教训：

- **源 GLB 质量参差，必须逐候选 Blender 渲染挑选**：同一数码兽常有多个变体文件（`_chr<N>` / `_2` / `with animations` / 武器拆分件）。实测坑型：① rest≠bind 时 raw POSITION 可能是爆炸态（杰斯兽x chr468）；② 整文件 0.01 退化缩放（v仔兽 chr114、奥米加兽x chr357、慈悲 chr448）——Blender 渲染正常因相机自适应，但蒙皮空间全错；③ `_2` 变体是空壳/纯武器件（闪光暴龙兽 chr776_2_3 只是一把剑）；④ 部分文件 rest 姿势是躺平的。判据：候选文件逐个 `_rest_probe` 渲染 + 比对关节高度 h 与网格尺度一致（h<0.25 或 j/mesh 尺度不匹配即弃）。
- **多 skin 文件要取并集**：`glb_scene` 只读 `skins[0]` 会漏掉手臂等关节（杰斯兽x 分 backpack/body/scarf 三个 skin）——joints 应 union 全部 skins。
- 退化缩放文件可以整体预放大（POSITION/IBM平移/节点translation ×S 重写 glb，见 `scratch/` 缩放脚本思路）。
- `eff_*`/`fx_*` 材质片是技能特效板，绑定前必须剔除，否则成大旗布乱飘。
- jmap 安全兜底=空间最近骨，配件链（bkpk_arm/scarf/武器）→trunk/cape 系；`toe` slot 目标骨名是 `toe_left_0`/`toe_right_0`。
- QA 高度比阈值对鸟/蛇误报（展翅/昂首攻击高度翻倍属正常），需人工看图复核。

- 输出 RMV2 **v8** 格式，头部 offset 12 写骨架名（offset 4=版本 u32=8，offset 8=u32，offset 12 起 null 结尾 ASCII；旧记"offset 8"实测有误）——游戏靠这个字段挂动画。
- **单 LOD** 可把 6MB 压到 ~1.5MB/模型；贴图 base 2048、normal/mr 1024 再省体积。
- 每个单位产物：`.rigid_model_v2`、`.wsmodel`、`.xml.material`、DDS×5、`.variantmeshdefinition`。
- VMD 必须指向真实存在的 wsmodel——死链会让单位无声失败（本项目 leishou 曾有此坑）。
- **graft/retarget 产出的剪辑要补 `be_prop_*` 轨道**：供体 clip 的 prop 挂点轨道在重定向后变恒等（钉 animroot 原点），启用 CA 式 `<SLOT attach_point="be_prop_N">` 武器槽前必须补写：`scratch/fix_beprop_tracks.py`（全动态剪辑）+ `fix_beprop_tracks_dyn.py`（tb/rb 混合压缩剪辑→重建全动态）。逐帧 `L_prop=inv(W_animroot)⊗W_driver`，映射见 vanilla_bone_conventions.md 惯例 2。**⚠ 压缩编码解出的 quat 可能非单位（|q|=1.0011 实测），FK/求逆前逐 quat 归一化，否则 |q|² 缩放在长力臂上放大成 mm~cm 级偏差 `[实测 2026-09-26]`**。

### 3d. 复合特征骨架（逐模型保附肢链）`[设计 2026-09-26，工具待建]`

动机：固定模板族是"有就有、没有就塌"——hu1 零翼零尾，有翼有尾的模型绑上去翼变披风、尾冻结（数码兽实测：天使兽六翼→cape 骨、圣龙兽源 20 翼骨→wf1 全废，见 vanilla_bone_conventions.md 惯例 6）。**复合骨架 = wh3 模板主干照常接 donor 剪辑/graft + 源 rig 特征链原样移植**（`x_*` 前缀骨挂进主干），特征链吃源剪辑真数据。

```
1. 附肢盘点（逐模型，落盘）：扫源 rig 关节名
   （wing|hane|feather|tail|sippo|ear|fin|horn|mimi…），产出
   <unit>_anatomy.json：每条特征链骨数/侧别/链根挂点。
   参考 scratch/scan_dgm_wing_tail.py。
2. 特征链 spec：<unit>/feature_chains.json
   [{"name":"x_wing_l","src":"J_hane.*_L|J_wing.*_l","parent":"spine_2","keep":"all"}]
   - parent 只能是主干模板骨名（wing→spine_2/肩骨，尾→pelvis/root，
     耳→head，鳍→spine_*）
   - keep=all 或 top N（源骨数>N 时保近端 N 节，末端骨弃）
   - 翼型决定链结构：羽扇抄 bird01 布局、膜翼抄 dragon01b 布局（惯例 6）
3. 合成骨架 [待建 tools/synth_composite_skel.py]：
   fitted JSON（fit_skeleton 产物）bones[] 末尾追加 x_* 骨：
   - 链根世界位 = parent 骨位 +（源链根-源躯干参照）× fit 缩放
   - 链内世界姿态抄源 rig rest（保原轴向/骨距 → 源轨道可直接写）
   - 重算 local_pos/local_quat + IBM；custom_name 照常 czx_<u>
   - 骨架 .anim/invmats 仍走 write_skeleton/write_invmats，接口不变
4. 蒙皮：rig2 keep 模式；jmap 把附肢顶点组 1:1 指到 x_* 骨
   （J_hane1_L→x_wing_l_0）。附肢权重 100% 继承源美术、零启发式；
   主干照旧走 jmap/auto-bind。
5. 动画：
   - 源剪辑 graft：主干 bonemap 照旧；x_* 通道直接写源骨局部轨道——
     父骨运动差由 delta 层吸收（与 retarget_delta 同构，[需验证]）
   - donor/vanilla 剪辑没有源数据：x_* 轨道必须生成，禁止恒等摆烂——
     v1 方案 = 父骨世界增量阻尼跟随（旋转=父 Δ×damp、平移恒等）
     [待建 gen_follow_tracks]；或写"收翼/贴尾"常量姿势轨道
   - 纯装饰链可在 spec 标 "static_ok":true 显式豁免
6. 接入照旧（§3c-i）：骨架 .anim + invmats + bin/animpack +
   battle_skeletons 行 + RMV2 头骨名。
```

**硬性验收门（复合骨架专用，与 §8 通用门叠加执行）**：

| 门 | 要求 | 拒收条件 |
|---|---|---|
| G0 盘点留证 | `<unit>_anatomy.json` 落盘，含源附肢链骨数/挂点 | 无盘点文件直接拒 |
| G1 骨数底线 | `bone_count ≥ 模板骨数 + Σ声明链骨数`；源侧 ≥3 骨的链成品不得为 0；翼链每侧 ≥3、尾链 ≥3（源不足按源数）；总关节 ≤255（weighted4 u8 上限） | 任一不达标即拒 |
| G2 附肢顶点归属 | 源附肢顶点组顶点的主导骨 ∈ 对应 x_* 链 | 附肢顶点主导骨落在 cape/spine/leg/animroot 的计数 >0 = 拒收（animroot>0 原规则不变） |
| G3 轨道活性 | 每根 x_* 骨在发货剪辑集中 ≥1 条非常量旋转轨道 | 全剪辑恒等的链须 spec `static_ok` 豁免，否则拒收 |
| G4 形态验收 | 叠加三视图 + 中段帧 + LBS max_r ≤ ~1×体型 + 证据全路径 | 同 §8 既有规则 |

当前债：数码兽 v2 的 21 只"翼+尾"单位里只有鸟系 3 只达标（bi1 骨架自带羽/尾链）；18 只需按本流程逐个重做复合骨架才能解锁翼尾表现。人形系（天使/天女/座天使等）是最差档，优先处理。

## 5. DB 生成

沿用 `unit_creation_workflow.md` 的最小链：main_units / land_units / variants / unit_variants / 属性组 / unit_set / 招募 / 自定义战权限 / loc。本项目约定：

- 招募建筑与该 MOD 既有兵种**同一套主招募建筑表**，不单独发明。
- `man_animation`/`man_entity` 直接用供体单位的（如牛头人 entity + `humanoid06` 动画集），不新建 entity，除非要改速度/质量/碰撞。
- `primary_melee_weapon` 也优先复用原版武器 key，要改数值才克隆新 key。

### 5a. 载具/战争机器单位的特殊链路 `[实测/需随版本复查]`

蒸汽坦克这类"引擎单位"的视觉网格不走 `unit_variants → variants → VMD` 主链，而是：

```
land_units.engine ──→ battlefield_engines_tables.key
                        ├─ model = <VMD 名>（引擎可见网格的 variantmeshdefinition）
                        ├─ gun_animation_table = wm_steam_tank01（引擎动画集）
                        ├─ battle_entity（碰撞/移动实体）
                        └─ destroyed_model / destruction_animation（可复用原版被毁模型）
land_units.articulated_record ──→ land_unit_articulated_vehicles_tables（车轮关节，原样复用）
land_units.mount = emp_hidden_mount_steam_tank（隐藏骑乘座）
unit_variants.variant ──→ 乘员 VMD（原版是 wh_emp_state_troops：乘员模型站在车体挂点上，
                          由引擎骨架驱动时保持绑定姿态；可换成同 hu1 骨架的自造变体）
```

要点：

- `battlefield_engines.model` 填的是 **VMD 文件名**（如 `emp_steam_tank` → `variantmeshes/variantmeshdefinitions/emp_steam_tank.variantmeshdefinition`），不是 wsmodel 路径。
- `main_units` 的主键列是 `unit`；蒸汽坦克供体行按 `land_unit` 列匹配（其 `unit` 是另一个 imperial_supply 记录）。
- `num_engines`/`num_mounts`/`primary_missile_weapon`（炮弹）沿供体整行克隆即可。

## 6. 数值对标

详 `tsv_format.md`「新单位数值对标法」。要点回顾：

- 供体 = 同骨架动画集 + 同 caste + 相近模型数。
- `bonus_hit_points` 是**每模型**血量；总血池 ≈ 供体 ±20%。
- `recruitment_cost`（战役）与 `multiplayer_cost` 分开同步。
- 一对多的相似单位（如两种混合体）用武器/属性区分定位，不要数值完全雷同。

## 7. 技能与属性

- 优先**复用本 MOD 已有技能链**直接加 junction 行。
- 需要新技能时，按列名对齐克隆原版整链：`unit_abilities` → `unit_special_abilities`（新 `unique_id`）→ `special_ability_phases` → `special_ability_to_special_ability_phase_junctions` → junction → loc。
- 自爆类：`wh2_dlc15_unit_abilities_exploding_unit` 是引擎级"死亡即爆"标记（隐藏 active，`wh_type_augment`，phase 本身无效果）；原版自爆单位全是**单模型**（膨胀尸 1×1600HP/425 金、自爆蛆 1×660HP/425 金），配 `expendable` 属性。多模型自爆单位按"每模型一发炸弹"定价 `[已查原版 DB / 需游戏内复查]`。
- 属性组按定位给：fear/terror/wallbreaker/expendable/guerrilla/hide_forest 不要无脑全套。

## 8. 验收层级（由轻到重）

1. **二进制**：RMV2 头 offset 12 骨架名非空；文件含权重数据。
2. **AssetEditor 日志**：打开 RMV2 后日志出现 `<skel>.anim` + 自动匹配 idle clip 即绑定成功。**WPF/D3D 视口截图可能全黑/白屏，日志才是可靠证据** `[实测]`。
3. **无头 pose render / GIF 动图**：
   - 单帧：`blender_pose_render.py`。
   - 动图：`python tools/make_unit_anim_gifs.py [单位名]` 一条命令出 attack+idle GIF（内部调 `blender_pose_anim.py` 单会话渲整段 clip，PIL 拼 GIF）。产物在 `scratch/anim_frames/`。
   - 取景必须按**姿态下网格包围盒**（跨采样帧求并集），不能按骨骼关节范围——关节在体内，渲出来模型只占画面 1/4 `[实测]`。
   - 深色模型（虫族紫黑配色）要亮背景 + 曝光提升（AgX Medium High Contrast + exposure≈0.8），否则黑底上什么都看不清 `[实测]`。
   - Blender 传路径用**绝对 Windows 路径**——从 WSL/bash 调 blender.exe 时相对路径会解析到错误 cwd，渲完找不到文件 `[实测]`。
   - 姿态应用公式：`pose = C·(A·B⁻¹)·C⁻¹·bone_rest`（glTF 往返后 rest 帧 roll 不一致，必须相对绑定姿态增量驱动）`[实测]`。
   - **骨骼匹配检查图**：`blender_pose_bones.py`（同参数）双通道渲染——solid/ 实体模型 + bones/ 橙色八面体骨骼（透明底），PIL 叠加后骨骼恒在最上层，一眼看出骨架是否穿出模型 `[实测]`。注意 Blender `parent_type='BONE'` 锚点在骨尾，八面体要 `Translation(0,-L,0)` 补偿回骨首。
   - **预览目录只留最新一轮**：`scratch/_preview/` 每次出新图前删掉上一轮旧图（用户验收只看当前版本），多版本对比图放 `scratch/cmp/` 不进 `_preview`。预览产物一律放 `scratch/` 内，禁止在仓库根目录建 `_preview/`（见 `AGENTS.md` 工作区卫生）。
   - **绑定叠加验收图（强制）**：**每次调整骨骼/绑定/权重后，必须先出一张"网格+骨架"叠加图确认绑定关系**——`blender -b -P tools/blender_skel_overlay.py -- <bound.glb> <out.png>`（绑完的内嵌骨架实体骨柱+半透明网格，参考 `scratch/jibian_bound_overlay.png`）；若骨架来自外部 JSON 用 `blender_skel_overlay_json.py`。验收点：**足/头/尾三点必须对位**——足/踝/趾关节落在模型足上并贴地（y≈0），头/颈/颚骨在头腔内，尾/后肢骨在尾部内（非人形单位 rear_*/tail_* 同理）；腿链进腿、脊柱链穿躯干、臂链进臂，装饰骨明确排除；骨架穿出/偏离/尺度不符（大数倍）一律先修再进动画验收。三视图各出一张（`--view front|side|persp`）+ `--bonesub` 只画参与蒙皮的结构骨（装饰骨白噪声会糊住判断）`[实测]`。
   - 审图重点：炸面/脱肢/漂浮碎块/贴地/朝向。
   - **运行时蒙皮审计（强制，2026-09-26 起）**：文件层 `JOINTS_0` 干净 ≠ 渲染正确——studio 加载时 `rebindStrayWeights`/`graftVestigialFace` 会**改写 skinIndex**。验收必须读 `__studio.modelReport.rebind`（steal/tail/trunk/byBone 计数）+ `lastGraft`：steal 非零且 byBone 落在 hand/wrist/weapon/爪 = 拒收；graft 抓到非头骨主导的躯干/胸口顶点 = 拒收。判别法：`#nojaw` hash 开关禁用 jaw 补蒙做 A/B 对照 `[实测]`。
   - **中段帧三视图强制**：奔跑、combat_walk、至少两条 attack（含跳跃/移动攻击）各抽 ≥1 个中间帧出正/侧/顶（或等效角）三视图——钉死顶点/抢蒙/内衬外露只在运动中段帧暴露，静态 bind 通过不算过 `[实测]`。
   - **渲染完必须自己先抽帧检查再向用户汇报**：至少看首帧+中段帧；有供体时先渲供体地面真值作基线。汇报要写明"看过哪些帧、看到什么现象"，渲染成功不等于通过 `[实测]`。
   - **证据图必须留全路径（强制，2026-09-26 起）**：声称"已修复/验收通过"时，汇报必须附验收图的**磁盘绝对路径**（如 `E:\Code\...\scratch\_preview\xxx.png` 或 tabbit 截图落盘路径），不许只说"截图确认正常"。图必须留在磁盘上可复查——口头描述不算证据，矩阵/自检日志同理需给出 JSON/log 文件路径 `[实测]`。
   - **视觉证据闸（强制，2026-09-27 起，加鲁鲁兽颌部三轮假阳性根因）**：写任何"图上看到 X"的判词前，必须确认**本轮上下文中实际接收了该图的像素数据**——`read`/截图工具返回 "Images omitted"、占位符、或全糊图时，该轮**禁止输出视觉结论**，只能写"未获得有效图像"并重渲/重截。禁止用"我刚改了 X 所以图上应该是 Y"的预期补全观察描述——验收描述的每个断言必须能指出图中具体区域依据 `[实测]`。
   - **验收图分辨门**：验收截图/渲染必须能分辨目标解剖结构（嘴缝、齿列、下颌线、翼缘、关节轮廓）；目标区域只占几十像素或被截出画框的图一律作废重渲，不算样本 `[实测]`。
   - **变形类验收须带对照与双向检查**：开口/关节变形验收 = 同机位 闭/开 两张 + 同类参照（供体或源模型同视角）；判定标准是"不该动的部位未动"（上吻/面颊/喉部零位移），不是"有缝/有位移"。位移量、漂移值等数值指标只用于定位病灶，不作定案依据 `[实测]`。
   - **可动骨位审查先于权重手术**：下颌/指爪/翼等可动部位变形异常时，先核对该骨**原点是否为解剖铰链位**（对供体骨架相对位置，如 donor jaw_0 在头骨后下方而非吻尖），再谈权重选区——铰链错了改权重永远修不对 `[实测，加鲁鲁兽 2026-09-27]`。
4. **游戏内**：Mod Manager 启动 → 自定义战看模型/动画/技能/自爆表现；战役看招募建筑图标/兵牌/porthole。

## 8b. 反向导出：原版单位 → GLB（wh3_export_unit_glb.py）`[实测 2026-09-26]`

用途：把游戏里原版单位连骨架+权重+贴图+动画整条链导成自包含 GLB，丢进 `model-studio/models/` 当**蒙皮质量基线**和骨骼/动画研究样本。

```bash
# 裸名自动解 VMD 链；多 slot VMD 每槽取第一个 variant（stump_* 断肢槽自动跳过）
python tools/wh3_export_unit_glb.py emp_greatswords \
  --clips "animations/battle/humanoid01/2handed_sword/stand/hu1_2hsw_stand_idle_01.anim,..." \
  --name wh3_emp_greatswords
# 产出 scratch/wh3_export/out/<name>.glb → 拷 model-studio/models/ 自动出现在样例下拉
```

链路：`VMD(xml) → 每 SLOT 第一个 VARIANT_MESH → wsmodel(xml) → .rigid_model_v2`；slot 的 model 属性也可直引 `.rigid_model_v2`（断肢件/道具走这条，无 wsmodel 包装）。武器/道具 rmv2 无骨架字段（游戏用 attach_point 挂接），导出器跳过。

**RMV2 顶点格式（关键坑）**：材质块首个 u16 = `vertex_type`（BinaryVertexFormat）。v8 文件里会混两种——
- `4` Cinematic 36B：`pos4f16 | bi u8x4 | bw u8x4 | nrm u8x4 | uv f16x2 | binorm u8x4 | tan u8x4 | colour u8x4`
- `3` Weighted 32B（双权重！）：`pos4f16 | bi u8x2@8 | bw u8x2@10 | nrm u8x4@12 | uv f16x2@16 | binorm u8x4@20 | tan u8x4@24 | pad4@28`

把 32B 当 4 权重解码会得到 bi≈254 越界索引，GLTFLoader 直接崩 `matrixWorld`。判据看材质 vertex_type，不要按字节宽猜。

动画：clip 是 `animations/battle/<skel>/<武器类别>/...` 层级，`--anim-dir` 限定子目录（默认 auto 按字母序抓会拿到错的武器类型，如 greatswords 抓到 2handed_hammer）。`*_pose_*.anim` 是 0 帧静态姿势文件会被跳过。`resolve_locals(clip, part, frame, skel_frame)` 直接给每骨局部 TRS；`parse_anim(skeleton .anim)` frame0 = 绑定姿态，IBM = inv(frame0世界矩阵)（与 .anim 尾部 `.bone_inv_trans_mats` 一致，实测可对拍）。

实测结果（进 model-studio）：
- `hef_sun_dragon`（dragon01, 127骨, 2 mesh, 4 内嵌 clip）→ morph=quad，映射 17/17 + 附加骨 14（尾/翼/爪/jaw），自检 FAIL 集中在辅助骨阈值口径（14m 巨兽飞行 clip），非导出缺陷
- `emp_greatswords`（humanoid01, 72骨, 6 mesh, 4 clip）→ morph=biped，自检 14P/3W/0F，WARN 全是 run/charge 位移动画真实位移触发

## 8c. 原版动画注入自制 GLB（inject_anims_glb.py）`实测 2026-09-26`

用途：给 `model-studio/models/` 里已绑定的自制单位 GLB **原地追加**原版 clip 轨道，让 studio 预览所见 = 游戏所得（自制单位本就挂游戏真动画，只是 bound.glb 没带）。修「自制单位动作太呆」的根因——DSL 相位合成 vs CA 真数据。

```bash
python tools/inject_anims_glb.py models/czx_dgm_agumon_bound.glb          # 自动检测骨架+挑 clip
python tools/inject_anims_glb.py x.glb --skeleton humanoid01 --anim-dir 2handed_sword
python tools/inject_anims_glb.py x.glb --clips a.anim,b.anim --dry       # 只看不写
```

机制：
- **骨架检测**：扫 pack 全部 `animations/skeletons/*.anim`，按 GLB 节点名重合数排序；同分（czx_* 克隆骨架骨名全同）按单位名前缀亲和度选本单位自己的骨架（`czx_dgm_agumon` → `czx_agumon`）。
- **clip 挑选**：`animations/battle/<骨架>/` 全树按语义取 ≤10 条：stand_idle×2 / walk / combat_walk / run / charge / attack×3 / hit / death / celebrate；`pose` 文件跳过（0 帧）。
- **轨道（重定向式，关键）**：旋转全绑；**平移只给 clip 里真实运动的骨**写轨道，且以 GLB rest 为锚、按 rest 骨长比缩放差量——直接写绝对平移会把 clip 骨架的骨长套到自适配过比例的 bound 骨架上，肢节长度漂移 segDrift 爆表（第一版踩过）。GLB 缺的骨跳过，clip 没动的骨保持 GLB rest。
- clip 内部 `skeleton_name` 与所认骨架不一致时拒收（防止跨骨架污染）。

实测（model-studio 全库 136 GLB）：
- **114 个 bound GLB 全部注入成功**，132/136 现有动画（4 个 ref_* 战争机器无 animset 属正常）。
- czx 系自动对到单位专属骨架目录：agumon→czx_agumon（95 clips 库）、birdramon→czx_bi（bi1_ 鸟系飞行动画）、charizard→dr1b 龙系、jibian→centaur01 半人马系。
- studio 定量验证：attack hand 位移 0.29m、fly_charge 翼骨 0.27m、stand_idle 有呼吸级微动——全为 CA 真实曲线。
- 批量脚本 `scratch/batch_inject_anims.py`：遍历 models/ 无动画 GLB 原地注入（skel_cache 缓存骨架文件）。

--strip：剥掉已有 animations 并压实 BIN（孤儿 accessor/bufferView 回收），重注入不胖文件。

坑：czx_* 与 humanoid01 骨名完全相同 → 检测必须加单位名亲和度，否则谁排在前面就认谁（aerovd≺agumon）。

## 8d. 颌部（嘴/颚）验收与修复规程 `实测 2026-09-27，加鲁鲁兽四轮迭代定案`

颌部是全身最容易"指标全绿但视觉报废"的部位（位移/漂移/口缝增量都能造假——只证明选中的顶点刚体旋转，不证明选对了顶点）。单独列门。

### 验收门（M0–M4，全过才算过）

| 门 | 内容 | 拒收信号 |
|---|---|---|
| **M0 骨位审查** | 颌骨原点必须是**解剖铰链位**（头骨后下方耳下关节处），对 donor 同骨架相对位置核（如 wf1 donor jaw_0 在头骨 -0.05/+0.04）。源锚点≠铰链：`J_tooth`/`J_kuti` 常是牙列/吻尖锚点，fit 时 landmark 会错落在吻尖 | jaw 骨世界坐标贴近吻尖/牙列而非头后；对 donor 相对位置偏差 >20% 头长 |
| **M1 选区审查** | 颌权重顶点必须严格在嘴线以下。首选**源蒙皮迁移**（源 rig 的 `J_tooth`/`J_ago`/`J_joe` 蒙皮组经颌部规范坐标系——头骨原点+头→颌轴归一化——近邻匹配到 bound 网格）；空间几何过滤只能当补充（canonical up<0 剔除嘴线以上）。**禁止纯空间球/半径盲选**——会把面颊/喉肉一起拽走 | 颌主导顶点 canonical up>0（嘴线以上有点）；张嘴时上吻/鼻桥/面颊有位移 |
| **M2 源能力审查** | 动手修之前先核源模型两件事：① 源剪辑里颌骨**真的会转吗**（逐帧局部旋转 vs rest 角度扫描全剪辑取最大摆幅——"骨存在"≠"骨会动"，chr012 J_tooth 13 条全恒定）；② 源模型**有口腔内壁吗**（内壳/舌/上下颚面片）。无内壁张嘴必穿帮——这是**换源/补壳**的信号，不是权重能修的 | 源剪辑颌骨旋转全恒定=死骨，张嘴得人工注铰链包络或换源；内壁缺失张嘴露楔形缺口见背景 |
| **M3 变形视觉验收** | 同机位**闭/开两张**特写（相机钉 head_0+snout_0 中点，侧前 3/4 视角），开大摆幅原生剪辑里实测颌角最大的帧（别挑保守帧）+ 至少一条含颌驱动的 donor/studio 剪辑。判定标准="不该动的没动"+内壁封闭不露底 | 垂肉/甩下巴（铰链错位）、裂脸掀鼻桥（选区越线）、楔形穿帮（无内壁）、颌动但不动画里没轨道 |
| **M4 报告规范** | 每条视觉断言标：哪张图（绝对路径）、哪个像素区域、是否过分辨门、图像是否实际入上下文。数值（颌角/位移/漂移）只能作 M0–M2 的**定位**依据 | "截图确认正常"无路径、Images omitted 仍写结论、远景几十像素当样本 |

### 修复顺序（严格按序，跳步必返工）

1. **先铰链后权重**：M0 不过 → 迁颌骨原点到 donor 比例铰链位 → **重算该骨 IBM**（保 rest 姿态不变形）→ **重写全部动画剪辑里该骨的平移轨道**到新局部系（不改旋转）——漏一步则 rest 对但一播动画骨头跳回旧位。
2. **再选区**：M1 不过 → 源蒙皮迁移（`precise_jaw_fix.py`：源 J_tooth 顶点云→规范坐标→近邻 bound 顶点→0.85 权重），旧错误选区先回滚再写新组。
3. **源不行就换源**：M2 判定死骨/无内壁 → 停止权重手术，走整模换源（NxO 系同源 J_* 骨架直换，jmap 保 `J_tooth→jaw_0` keep 模式即可继承原生颌权重+原生颌动画）。补壳（内缩复制下颌面片翻面）是下策，只在换源不可行时用。
4. **每步留备份**：动 GLB 前 `.bak`，验证失败可逐层回退归因。

### 工具沉淀（scratch/garu_qa/）

| 脚本 | 用途 |
|---|---|
| `bound_jaw_inspect.py` | dump bound GLB 颌骨位/选区分布/主导骨审计（M0/M1 用） |
| `jaw_axis_probe.py` / `jaw_proof.py` | 铰链轴扫描 + 刚体旋转性数值审计（M0 定位） |
| `jaw_hinge_fix.py` / `jaw_anim_trans_fix.py` | 铰链迁移 + IBM 重算 + 全剪辑平移轨道重写（修复步 1） |
| `precise_jaw_fix.py` | 源蒙皮规范坐标系近邻迁移选区（修复步 2，可加 canon up<0 过滤） |
| `dump_src_anim.py` + `inject_src_anim.py` | FBX 原生剪辑采样→glTF 节点空间注入；`dot_*` 辅助节点必须排除（singular matrix） |
| `garu_srcmap.json` | jmap 模板：`J_tooth→jaw_0` keep + 四足 L/R 直通（源 +x=L 即目标 right，不镜像） |

### 邻接坑

- **glTF 材质缺省金属度**：FBX→GLB 不写 `metallicFactor`/`roughnessFactor` 时规范缺省 1/1，无环境贴图的渲染器里近全黑——JSON patch `pbrMetallicRoughness`；Blender 端因 Principled 默认值不同可能正常，**跨端一致才作数**。
- **Blender 导入含动画 GLB 后手动 pose 无效**：armature 挂着最后一条 action，渲染求值覆盖手动姿态——先 `arm.animation_data.action=None`（4.5+ 还要清 action_slot），否则闭/开渲出来一模一样造成"修复无效"假象。
- **slotted action**：Blender 4.4+ 赋 action 不设 `action_slot` → fcurve 有方差但 pose 冻结，采样全成静帧。

## 9. 已知坑速查

| 症状 | 根因 | 修法 |
|---|---|---|
| 摆姿势碎成放射状 | 装饰骨抢权重 / 几何蒙皮质量不够 | 优先换 transfer_weights.py 供体转移 |
| 腾空/跳跃时拉成细丝、地面留碎片 | 顶点绑到 animroot（原点钉死） | 排除正则+keep 快照双端剥 animroot；顶点审计主导骨=animroot>0 即病灶 |
| keep 权重完全不生效（override 0/N） | bake 循环提前 clear 顶点组 / Blender4.5 字段名 | keep 模式跳过 `vertex_groups.clear()`；用 `v.groups` 元素 `.group` 非 `.index` |
| 披风/裙摆在动作里塌成一团 | mant/cloth 链映射到躯干骨 | jmap 重指骨架 `cape_*` 链；无披风骨骨架才塌到 spine/neck |
| 武器静止时平躺在脚边、动作中跟脚甩 | J_wep*→animroot 或被 auto-bind 最近到腿脚 | jmap 指 `hand_right/left` 刚性跟手 |
| 换源/改 jmap 后 bind 输出没变 | world.glb 只在不存在时重建+phase 标记跳跑 | 删 world.glb+bound.glb、清 report.json 相位再跑 |
| 静态姿态正常、大招/腾空解体 | 普通帧不暴露钉死顶点 | 验收必须覆盖腾空类 clip（ult_skyfall/俯冲），静态图通过不算过 |
| 球状躯干被剪碎/塌陷 | 球面离腿骨比躯干骨近 | rigidify_core.py --ymin 刚性绑躯干骨 |
| 连绑定姿态都碎 | rest 帧 roll 不一致，双重坐标转换 | pose 用相对增量公式 |
| AssetEditor 截图全黑 | WPF/D3D 视口截屏问题 | 看日志+二进制，勿当绑定失败 |
| 动画 0 帧 / No Skeleton | RMV2 头无骨架名/无权重 | 补蒙皮重转 |
| VMD 指向不存在 wsmodel | 死链 | 改 VMD 或补 wsmodel |
| 单位血量离谱 | HP 是每模型值，抄了单体巨兽 | 按模型数折算 |
| 中文路径喂 Blender 乱码 | 编码 | 拷 scratch 改 ASCII 名 |
| 贴图细节全丢（没眼睛/牙/爪尖）但大体颜色对 | .dae 源 UV 双重翻转：fbx_to_glb 手动翻 + glTF 导出器自动翻抵消 | 移除 fbx_to_glb 的 .dae 手动翻转；既有 GLB 用 `scratch/vflip_uv.py` 就地翻 TEXCOORD_0；头部顶点采样到贴图下半部=病灶信号 |
| 工作室"自带动画"把模型拉散架 | inject_anims_glb 注的是原版骨架绝对局部 TRS，非重定向 | 预览游戏实际动画用 `scratch/inject_rt.py` 注 mod_files 里已重定向的 czx_* .anim；批量 `scratch/reinject_studio.py` |
| inject_rt 重定向剪辑进 GLB 仍解体 | .anim 局部 TRS（wh3 骨架局部约定）≠ GLB 节点局部约定（Blender 骨轴系），直接写轨道必错位 | `scratch/fix_injected_anims.py` 原地修：世界空间 delta 重定向 `W_glb=ΔW_skel⊗W_glb_bind` 再按父子链解回节点局部，写 `extras.wsFixed` 幂等标记；缺省扫全部 dgm_pub_batch skel json |
| 动画中段肢体折叠/腿过头/揉团（静态 bind 正常） | .anim 量化轨按 donor 局部范围裁剪，retarget 目标值越界被钳到 ±127（toe_left_0 超 740×） | retarget_clip 写回后量化轨自动提升无损（tb3→12/rb4→8）；凡写 .anim 必须回读 `resolve_locals`+`world_from_locals` 对比意图 `[实测]` |
| 待机/张嘴时下颚到胸口垂暗红"领带" | jmap 把下颚源骨（`J_joe/J_ago/J_chin/J_mouth/J_kuti/J_kuci/J_joe_l/r/J_ago2/J_grey_chin/J_garuru_chin`）错配到 head/eyebrow/spine_2/root——头抬起时颚部内衬滞留撕开 | jmap 改指该骨架 `jaw`/`jaw_0`；删 `*_world.glb`+`*_bound.glb` 清 phase_bind/rmv2 重跑（world.glb 存在即跳权重重映射）。验收信号：张嘴帧中线暗红垂带；顶点审计=喉部中线前方顶点主导骨非 jaw |
|| 张嘴时下颌甩出下垂"下巴袋/喉肉"（垂肉） | 颌骨原点错落在吻尖牙列锚点（fit 到 `J_tooth` 而非解剖铰链位），绕吻尖旋转把下颌后段甩开 | §8d 修复步 1：迁铰链到 donor 比例位（头骨后下）→重算该骨 IBM→重写全剪辑该骨平移轨道；改权重永远修不对铰链错位 `[实测 加鲁鲁兽]` |
|| 张嘴连上吻/鼻桥/面颊一起掀起（裂脸） | 颌选区混入嘴线以上顶点（空间球/半径盲选抓了面颊上唇） | §8d 修复步 2：源蒙皮迁移选区 + canonical up<0 剔除嘴线以上；顶点审计=颌主导顶点 canon up>0 即病灶 `[实测]` |
|| 张嘴露楔形缺口、能看穿到背景 | 源模型无口腔内壁网格（手游低模嘴是贴图画出来的） | §8d M2：权重修不了——整模换源（NxO 系同源 J_* 骨架）或补内壳；验收信号=开口帧下颌后方透出场景底色 `[实测]` |
|| 颌骨存在但全部剪辑里嘴纹丝不动 | 源 rig 该骨是定位锚不是动画骨，全部源剪辑旋转恒定（chr012 `J_tooth` 13/13 恒定） | §8d M2：人工注铰链包络或换源（NxO `J_tooth` 为真铰链骨、94 条剪辑驱动 27–65°）；先跑全剪辑颌角扫描再定方案 `[实测]` |
|| GLB 在工作室/无环境贴图渲染器里整体近全黑，贴图明明在 | 材质未写 `metallicFactor`/`roughnessFactor`，glTF 规范缺省 1/1 → 金属面反射空环境=黑 | JSON patch `pbrMetallicRoughness`（metal=0、rough≈0.75）；FBX→GLB 导出端必须补写；Blender 端正常不算数（Principled 默认值不同），跨端一致才作数 `[实测]` |
| 奔跑/攻击时体侧甩出"门板"长条、爪尖滞留不动 | 工作室 importer 运行时 `rebindStrayWeights` steal 规则把 hand_* 爪尖顶点抢挂休眠 cape_*_0（亚古兽 71 顶点） | `STEAL_SRC_RE` 收窄到 arm/forearm/elbow（不含 hand/wrist）；验收=`modelReport.rebind.steal>0` 且 byBone 落 hand/wrist/weapon 即拒收 |
| 自检 fail=0 但视觉明显不对 | 几何自检只测"不爆炸"，不测动画源/贴图方向 | 必做中段帧截图 + 对照 vanilla 导出基线（wh3_export_unit_glb） |
| 工作室里头顶塌陷成锯齿碎块、深色残片挂脸 | 运行时 `rebindStrayWeights` crest 车道按绝对高度阈值（0.55m）抢 head 骨顶点——大头单位连续颅壳被误杀（亚古兽 94 顶点） | crest 车道须叠加 `detachAt` 顶点距空隙判据（importer.js）：连续分布不偷、只偷空隙外游离簇；验收=`rebind.crest` 高计数且 byBone 落 head/skull 即拒收 `[实测]` |
| 自制离线蒙皮脚本渲出假"帆/塌陷"但管线渲染干净 | `W_anim·IBM` 直乘混用坐标约定：GLB 绑定帧=Blender 骨朝向、骨架 frame0=WH3 约定，逐骨 roll 差 90~180° | 离线验证一律走 `tools/blender_pose_render.py` 的 delta 法（`desired = C@(A@B^-1)@C_inv @ matrix_local`）；直乘结果不可作证据 `[实测]` |

## 9b. 原版资产离线归档（游戏卸载后可用）[实测 2026-09-27]

游戏卸载前已把管线所需的原版输入全量落盘，此后 `export_gamedata`/`wh3_export_unit_glb` 依赖的 pack 不复存在，下列目录是全部替代源：

| 目录 | 内容 |
|---|---|
| `tools/_skel/` | 全部 597 个骨架原始文件（`animations/skeletons/*.anim` + `.bone_inv_trans_mats` + `.anm.meta`）；410 个 v8 骨架有解析 JSON，其余为 v7（用 clip 解析器读 bind pose） |
| `tools/_clips/<骨架>/` | **全部 343 个有战斗动画的骨架**的 `animations/battle/<skel>/**` 全量（83699 文件约 1.9GB）；retarget donor 从这里取 |
| `tools/_animdb/` | `animations/` 全树除 battle/：`database/`（bin/fragment）+ `persistent/` + campaign/tech/locomotion 等（43074 文件 2.4GB）+ 根级 41 个 `.animpack`（约 2GB，bin clone 模板全集） |
| `tools/_donor/<unit>/` | 36 个原版单位导出的中间产物：RMV2、wsmodel、VMD、骨架 anim、嵌用 clip、DDS；映射见 `_index.json` |
| `tools/_props/` | variantmeshes 下全部 prop/weapon/shield/banner 类文件（11760 文件 2.9GB，含 2583 个 prop RMV2 + wsmodel/material/DDS）；武器挂点素材从这里取 |
| ~~`tools/_vfx/`~~ | **已于 2026-09-29 E 盘清理删除**（游戏仍安装，可从 pack 重导）；model-studio `assets/wh3archive/glb/vfx/` 仍留有转换后 GLB |
| `tools/_shaders_xml/` | `shaders/*.xml.shader` 914 个（24MB）——可重组 shader 描述文件；`.hlsl_compiled` 预编译库未导（不可重组） |
| `tools/_commontex/` | `commontextures/` 全树 256 文件 213MB（渐变 ramp 等，NPR 用） |
| ~~`tools/_warmachines/`~~ | **已于 2026-09-29 E 盘清理删除**（游戏仍安装，可重导）；wh3archive `glb/warmachines/` 留有转换后 GLB |
| ~~`tools/_ui_icons/`~~ | **已于 2026-09-29 E 盘清理删除**（游戏仍安装，可重导）；wh3archive `tex/ui/` 留有转换后 PNG |
| `E:\Code\model-studio\models\ref_*.glb` | **2131 个原版单位**自包含蒙皮 GLB（骨架+权重+代表 clip+512px 贴图），共 7.4GB；3098 个 VMD 按 body RMV2 集合去重后 2432 组，`scratch/_mass_export.py` 驱动、`mass_export_done.txt` 为已导清单、`_vmd_dedup_scan.py` 为分组扫描 |

未归档（与单位/特效制作无关或过大）：terrain/battleterrain 地形（36GB）、rigidmodels 场景建筑（13.6GB）、audio（16GB）、movies（8.3GB）、skyboxes、prefab 部署、`.hlsl_compiled` 编译库；db/script/loc 已有 `gamedata/`/`bilingual/` 文本 dump 覆盖。

**可视化入口**（2026-09-27 加）：起 `E:\Code\model-studio` 的 `python tools\serve.py` 后开 `http://localhost:8787/browse.html` —— `assets/wh3archive/`（gitignore，不在仓库）里有 manifest.json + `glb/{props,warmachines,vfx}/` 3555 个 RMV2 转的静态 GLB（转换器 `scratch/_rmv2_to_glb.py`，含法线自算和贴图内嵌）+ `tex/` 2311 张保比例 PNG；`tools/httpd.py` 的 `GET /wh3/<rel>` 别名直读本目录 `_ui_icons/_vfx/_shaders_xml/_props` 原文件（2026-09-29 清理后仅 `_shaders_xml`/`_props` 仍在线，`_ui_icons`/`_vfx` 别名失效但 wh3archive 转换副本可用）。单位模型组运行时从 `api/models` 并入 ref_*.glb。RMV2 顶点坑：`vsize32-vtype0` 和 `28B` 是 `pos f16×4`（w 可为 0=不缩放），f32 先验会"恰好有限但轴向塌缩"误判，须双路解码比轴向伸展数；**vt0-32B 静态布局 = pos f16×4@0 + uv f16×2@8 + pad@12 + nrm/tan u8 打包@16+**（uv 在 @8 不是 @20——@16 起是 u8 字节，当 f16 读会出 inf/巨值；探测 UV 偏移时须"先到先得"严格大于才替换，否则偏移+2 的 (真v,0) 假对会平分顶掉真 uv 造成 v 恒 0 黑贴图）；28B 布局 = pos8+bi/bw4+nrm4+uv4@16+tan4+4B。

`wh3_export_unit_glb.py` 已支持 v7 骨架（`parse_anim` 失败时自动走 `parse_anim_clip` 取 frame0 作 bind pose，如 humanoid11b）；贴图解析有文件名兜底（老单位引用的 `*_diffuse.dds` 路径不存在时按文件名全索引匹配），嵌入 PNG 默认缩到 512px（`TEX_MAX` 常量，调大可得高清贴图）。骨架目录前缀即骨架短名（`wh_variantmodels/bc1/`=bigcat01、`hu11b/`=humanoid11b、`spt1/`=serpent01、`ce2/`=centaur02、`hc5/`=hybridcreature05、`md1/`=mound01 等）；units 的 VMD 名常是 `bst_minotaur_base`/`bst_centigors_base`/`bst_chaos_spawn_left_side` 这种 `_base`/`_side` 变体才含身体网格。worm01b/worm02/bloodworm01 在 battle clips 与 variantmodels 里均无资产（疑似仅战役/特殊用途骨架）。

## 10. 相关文档

- `unit_creation_workflow.md`：纯 DB 派生单位、招募链、RoR、兵牌/porthole。
- `asseteditor_animation_workflow.md`：AssetEditor 操作细节、Skin Wrap、动画 clip 解码格式。
- `tsv_format.md`：列名对齐克隆、数值对标法、junction 插行去重。
- `references/temari_luna_techniques.md`（仓库根参考样例）：第三方整单位替换拆解——同主键 main_units 行只改 `land_unit` + `unit_variants` 重定向、自定义骨骼/animpack（缺动作槽位回填 idle）、技能播歌纯 DB 链路、vanilla 互斥组复用。适合抄「替换而非新增」的整体结构。

## 重定向的三种模式（retarget_clip.py）

- `retarget()`（原版）：逐字拷贝供体局部旋转——只适合绑定姿态与供体一致的模型（坦克：骨架摆放本来就接近蒸汽坦克形态）。
- `retarget_delta(ref='bind')`：世界空间旋转差 = 供体动画世界旋转 × 供体绑定世界旋转⁻¹，叠到我们绑定姿态上。适用于绑定≈供体绑定姿态的模型。
- `retarget_delta(ref='frame0')`：**异形模型首选**——差值对每条 clip 自己的第 0 帧取，我们的生物保持自身剪影，只借供体的"运动"。枪兵（佝偻怪物 vs 直立人）只有这个模式不塌。
- 静态槽位统一填我们的绑定局部 TRS；root/animroot 平移按根高比缩放。
- `damp={regex: factor}`（仅 delta 模式）：把匹配骨的旋转差向恒等混合。**径向多足模型（蟹/蛛）必用**——我们的腿长比供体短很多时，同一旋转差会让腿尖扫过中线把模型折成球（莽兽实测：腿 damp=0.65 后攻击帧才不散架）。同时把 guess 的、模型上其实不存在的附肢骨（arm/claw/pincer）从权重 allow 里剔除——它们悬空在体外，会抓走附近顶点在攻击时甩飞背刺。

## 姿势渲染验证的坑

- `blender_pose_render.py` 的世界差公式需要 skel.json 作为第 5 参数，且要求 Blender 骨骼 rest 方向 ≈ json 绑定方向——rig2 从 head/tail 建骨，rest 方向与 json 绑定姿态可差 70-280°，但公式里 ML 项会约掉，实测正确。
- 验证姿势数据是否健康：直接比较 pose json 里关节世界坐标 vs 绑定坐标；region spread 不变 = 蒙皮没被撕裂（数值验证脚本 scratch/_skin_check2.py）。
