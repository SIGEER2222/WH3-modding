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
- **graft 管线注意 [实测 2026-09-26]**：graft_batch/batch_chr 重定向后 `be_prop_*` 与 `root` 轨道全是恒等/零（probe 实测 czx_imper0 attack clip 55 帧 be_prop_0 恒在原点）。所以现阶段 prop 槽接 be_prop 会把武器钉在脚底原点——不可用。要启用 CA 式挂法需在 graft 阶段补生成 be_prop 轨道（每帧 = 持械手世界变换）。imperialpm 的 Omega Blade 当前按"顶点搬到手部 bind 位 + 全绑 hand_right"修，视觉等价。

## 惯例 3：羽骨全链且全部带动画轨道

bird01/dragon01b：`wing_shoulder_* → wing_*_0/1/2` 主链，每级挂 `feather_{primary,secondary,tertiary}_{inner,middle,outer}_{side}_{idx}` 叶骨；dragon 另有 `wing_webbing_*` 翼膜骨和 `wing_claw_*` 翼爪。**grafted 剪辑实测 feather 轨道有真数据**（czx_bi/czx_ho 外层羽活动幅度 2-3.4m），所以 bind 期羽骨 fit 必须落在 mesh 上——轨道是活的，bind 错=甩飞。之前三只鸟翼骨 fit 修复正确。

## 惯例 4：蛇/多节链

snake02：`tail_0..19` 主链 20 节 + `tail_left/right_{upper,lower}_{0..5}` 侧链 + 每条发蛇 `head_snake_a..f` 带 `*_jaw`。metalseadramon 类蛇形 digimon 若要从 vanilla 蛇套 graft，源剪辑的 tail_N 节数远超目标骨数时末端衰减要按节数比例而不是按骨名。

## 惯例 5：be_prop / animroot / root 分工

- `animroot`：实体根（移动/朝向），剪辑里通常恒等。
- `root`：骨架运动根（躯干基准）。
- `be_prop_0..5`：animroot 直属、道具挂点、剪辑按武器轨迹 key。
- grafted 剪辑里 animroot/root/be_prop 全静态——自定义单位所有动态都在 root 之下。

## 复用工具

- `tools/wh3_export_unit_glb.py`：VMD→wsmodel→RMV2+骨架+剪辑+贴图→GLB。支持 stem 模糊匹配 VMD；`--clips auto` 每类挑代表剪辑；`stump` 槽（断肢）自动跳过；无骨架 prop 自动识别跳过。
- `scratch/_sweep/probe_beprop_track.py`：采样剪辑里任意骨世界轨迹（探 prop 骨动没动）。
- `scratch/_sweep/probe_graft_tracks.py`：批量看指定骨在剪辑里的活动幅度（静/动判定）。
