# 原版骨架/挂载/动画惯例（导出实测笔记）

来源：`tools/wh3_export_unit_glb.py <unit> --out scratch/ref_export --clips auto` 导出 7 只代表单位后逐个解析 GLB 骨架/动画轨道。用于自定义单位（尤其多部件/挂载件/羽骨类）的结构决策。

## 导出样本

| 样本 | skeleton | VMD 结构 | 说明 |
|---|---|---|---|
| stegadon | heavyquadruped01 (82j) | body / **platform** / bolt(prop) | 背炮台的"人+载具"代表 |
| giant_spider | spider01 (74j) | body / legs | 阿拉纳克炮台蛛 |
| greatswords | humanoid01 (72j) | head/torso/legs/**weapon_1** | 双手剑士，武器槽 |
| eagle | bird01 (95j) | body / wings | 羽骨全链 |
| medusa | snake02 (126j) | body | 蛇系 20 节尾链+发蛇 |
| dragon | dragon01b (132j) | body | 双头龙翼爪羽 |
| hurricanum | hurricanum01 (21j) | body | 飞舆（wizards 是独立 rider 模型） |

## 惯例 1：载具/平台件 = 专用骨链，不焊肢体

- stegadon：`platform_back_0`、`platform_front_0` 挂在 `root` 下；`bow_0` 挂在 `platform_front_0` 下。平台网格 rigid bind 到这些骨（platform_0 prim 顶点 6075 个给 platform_back_0、2524 给 front）。**剪辑给每个 platform 骨写轨道**（每个样本剪辑 6-8 条 channel）——行进中 howdah 的晃动是动画师手 K 的，不是物理。
- spider01：`platform_0` + `platform_section_0..7` 链挂在 `root/rear_0` 下，同样全有轨道。
- 推论：custom 模型里"站在飞行器/平台上"的结构 = 源件独立 mesh → **刚性绑到专用骨（或 animroot）**，绝不最近骨配重到腿。czx_dgm_susanoomon 的 Orochi 平台即按此修（全顶点→animroot，人摔下平台悬空）。若要平台有晃动生命感，需生成专用骨轨道；绑 animroot = 绝对悬停，已够用。

## 惯例 2：武器/道具 = 无骨架 prop + VMD `attach_point`

```xml
<SLOT name="weapon_1" attach_point="be_prop_0">
  <VARIANT_MESH model=".../emp_greatswords_sword_2h_01.wsmodel"/>
</SLOT>
```

- prop rmv2 **无骨架**（skeleton-less），引擎运行时挂到 `attach_point` 指定的骨上；可换 variant。
- hu1 原版剪辑里 `be_prop_0..5`（animroot 的直属子骨）每根都有轨道——`be_prop_0` 就是武器轨道骨，剪辑按武器弧线 key 它（跟手但不等于手）。
- **graft 管线注意 [实测 2026-09-26]**：graft_batch/batch_chr 重定向后 `be_prop_*` 与 `root` 轨道全是恒等/零（probe 实测 czx_imper0 attack clip 55 帧 be_prop_0 恒在原点）。**已修**：`scratch/fix_beprop_tracks.py`（全动态剪辑）+ `scratch/fix_beprop_tracks_dyn.py`（压缩/static-map 剪辑重建为全动态）按 CA 惯例补写 prop 轨道，逐帧 `L_prop = inv(W_animroot) ⊗ W_driver`。driver 映射：`be_prop_0/1→hand_right`（weapon_1/2）、`be_prop_2→hand_left`（shield）、`be_prop_3→spine_2`（weapon_3 背挂）、`be_prop_4→root`（weapon_4 胯挂）、`be_prop_5→hand_left`（weapon_5）。digimon_v2 全量 9496 剪辑：ok=8765 / no-prop=731（无 prop 骨骨架正常跳过）/ other=0；抽样 140 剪辑归一化 FK 下 prop 世界位置与 driver **逐帧零偏差**，四元数半球连续。**坑：非单位四元数**——压缩编码（rb=4 s8-range）解出的 quat 可能 |q|≠1（实测 animroot |q|=1.0011），`q·v·conj(q)` 会按 |q|² 缩放向量，1.8m 力臂产生 ~8mm 偏差；FK/求逆前必须逐 quat 归一化（引擎按单位 quat 处理）。imperialpm 的 Omega Blade 仍是"顶点搬手部 bind 位 + 全绑 hand_right"的焊接方案，与 prop 槽不冲突。
- **轨道 ≠ 挂载**：剪辑里有 be_prop 轨道只是挂点会动；要让武器真正出现还需 VMD `<SLOT attach_point="be_prop_N">` 指到对应 prop rmv2/wsmodel + variant 表配装。digimon 各 VMD 当前武器仍以 skinned 方式进 body 网格，prop 槽挂载是后续可选项。

## 惯例 3：羽骨全链且全部带动画轨道

bird01/dragon01b：`wing_shoulder_* → wing_*_0/1/2` 主链，每级挂 `feather_{primary,secondary,tertiary}_{inner,middle,outer}_{side}_{idx}` 叶骨；dragon 另有 `wing_webbing_*` 翼膜骨和 `wing_claw_*` 翼爪。**grafted 剪辑实测 feather 轨道有真数据**（czx_bi/czx_ho 外层羽活动幅度 2-3.4m），所以 bind 期羽骨 fit 必须落在 mesh 上——轨道是活的，bind 错=甩飞。之前三只鸟翼骨 fit 修复正确。

## 惯例 4：蛇/多节链

snake02：`tail_0..19` 主链 20 节 + `tail_left/right_{upper,lower}_{0..5}` 侧链 + 每条发蛇 `head_snake_a..f` 带 `*_jaw`。metalseadramon 类蛇形 digimon 若要从 vanilla 蛇套 graft，源剪辑的 tail_N 节数远超目标骨数时末端衰减要按节数比例而不是按骨名。

## 惯例 6：附肢骨量基线（复合骨架验收参照）`[实测 2026-09-26]`

逐个解析 GLB 骨架的附肢骨量，作为"模型带翼/尾时骨架至少该给多少骨"的底线参照：

| skeleton | joints | 单侧翼 | 尾 | 附肢占骨比 |
|---|---|---|---|---|
| humanoid01 (hu1) | 72 | 0 | 0 | 0% —— 附肢挂 cape/spine 的元凶 |
| wolf (wf1) | ~42 | 0 | 3 | 尾仅摆动级 |
| bird01/eagle | 95 | ~21（wing×3 + feather 初9/次6/三6） | 13（tail_0+左中右扇×4） | ~40% |
| dragon01b 双头龙 | 132 | ~20（wing×2+肩+爪×2+webbing×3+指骨×6+36 feather 双侧） | 12（7 链 + 5 尾尖扇） | ~45% |
| hef_sun_dragon | 127 | 同 dragon01b（膜翼蝠翼式，非羽扇） | 同 12 | ~45% |
| snake02 medusa | 126 | 0 | 20 主链 + 双侧链 + 发蛇 head_snake_a..f | ~50% |

- **能动的附肢 = 骨数堆出来的**：CA 给会飞的模型 40-50% 的骨量都花在翼/尾上；反过来说，凡骨架把附肢塌成 ≤2 根的，该附肢在动画里注定静止或随躯干晃。
- 数码兽源 rig 对照：莫斯提兽 48 翼骨、圣龙兽 20 翼骨、九尾狐 17 尾骨、杰斯兽X 15 尾骨——源模型精度不低于 CA，丢的是绑定端（绑 hu1/wf1 后翼尾骨量归零）。
- 翼的两派结构：**羽扇式**（bird01，feather 叶骨挂 wing 主链）vs **膜翼式**（dragon，指骨撑膜 + webbing 膜骨 + feather 骨做膜面细分）。选/造特征链时按模型翼型决定链结构，蝠翼型抄 dragon 布局，羽翼型抄 bird 布局。
- 引擎侧容量：weighted4 顶点权重 u8 索引 → 骨架总关节数硬上限 255；comp skeleton 预算大头照附肢分，主干骨数不退让。

## 惯例 5：be_prop / animroot / root 分工

- `animroot`：实体根（移动/朝向）。**不是恒等**——grafted 剪辑里 animroot 带常量 X 轴 180° 姿态（坐标系翻转），写 be_prop 局部值必须 `inv(W_animroot)` 换算，不能直接抄 driver 局部/世界值。
- `root`：骨架运动根（躯干基准）。
- `be_prop_0..5`：animroot 直属、道具挂点、剪辑按武器轨迹 key。
- grafted 剪辑里 be_prop 曾全静态（已按惯例 2 修复补写）；animroot 常量翻转保留。

## 复用工具

- `tools/wh3_export_unit_glb.py`：VMD→wsmodel→RMV2+骨架+剪辑+贴图→GLB。支持 stem 模糊匹配 VMD；`--clips auto` 每类挑代表剪辑；`stump` 槽（断肢）自动跳过；无骨架 prop 自动识别跳过。
- `scratch/_sweep/probe_beprop_track.py`：采样剪辑里任意骨世界轨迹（探 prop 骨动没动）。
- `scratch/_sweep/probe_graft_tracks.py`：批量看指定骨在剪辑里的活动幅度（静/动判定）。
