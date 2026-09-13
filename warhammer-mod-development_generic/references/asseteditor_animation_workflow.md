# AssetEditor 模型/动画预览与重绑定工作流

本文档记录用 AssetEditor 在不启动游戏的情况下预览 WH3 模型动画、诊断骨骼绑定问题、以及用 Skin Wrap 修复未蒙皮网格的完整流程。全部为本机实测（AssetEditor v0.78，2026-09-12）。`[实测/需随版本复查]` 标注可能随版本变化的点。

## 工具与路径

| 项 | 路径 |
|---|---|
| AssetEditor 可执行 | `E:\Code\WH3-modding\tools\AssetEditor\AssetEditor\AssetEditor.exe` |
| 另一份安装 | `C:\Users\22448\AssetEditor\AssetEditor.exe` |
| 日志 | `C:\Users\22448\AssetEditor\Logs\YYYY_M_D(N).log` —— **UI 自动化排障必读**，每次命令执行、动画加载、皮肤包裹都有日志行 |
| 缓存 | `C:\Users\22448\AssetEditor\Cache\`（首次启动扫全部 pack 建缓存，要几分钟） |
| 安装包 | `C:\Users\22448\AssetEditor_078.rar`（本机有存档） |

- 首次运行选 **Warhammer III**，数据目录指到 `<Steam>\steamapps\common\Total War WARHAMMER III\data`（指游戏根目录会找不到 pack）。
- 界面已本地化中文；命令行可传 pack 路径参数直接载入。
- 源码在 GitHub `donkeyProgramming/TheAssetEditor`（本机无源码树，需要时 webfetch raw 文件）。

## 预览动画的标准流程

1. **载入 pack**：左侧 Pack 文件浏览器上方菜单 → 「文件」→「打开参考 Packfile」→ 选目标 `.pack`。
2. **打开模型**：树里过滤/定位 `xxx_01.rigid_model_v2`，**双击 `.rigid_model_v2`**，进 Kitbash Editor。
   - ⚠️ 不要开 `.variantmeshdefinition`——VMD 是壳文件，不吃动画（踩过的坑）。
3. **动画面板**（底部「动画」区，可展开）：
   - `Skeleton` 字段：选 `animations\skeletons\<骨架名>.anim`（RMV2 自带骨架时自动填好）
   - `动画` 字段：用「浏览」或下方筛选列表选 clip（如 `sc1_jump_attack_01.anim`）
   - ▶ 播放；`帧 x/N` 计数器应非 0 且递增；模型应明显改变姿态。
4. **验证成功的判据**：日志出现 `Loading animation: <skel>.anim` 与 `Loading animation: <clip>.anim`，且帧计数 >0、模型随帧变形。

## 骨骼/动画前缀速查（本项目兵种）

| 单位 | RMV2 所在 | 骨架 | clip 前缀 | 验证过的 clip |
|---|---|---|---|---|
| 蟑螂 zhanglang | 本包 | `scorpion01` | `sc1_` | `sc1_jump_attack_01`（63 帧）✅ |
| 飞龙 feilong | 本包 | `bird01b` | `bi1b_` | `bi1b_stand_idle_04` ✅ |
| 凯瑞甘 kerrigan | 本包 | `humanoid01b` | `hu1b_` | `hu1b_sws_stand_idle_05`（95 帧）✅ |
| 刺蛇 cishe(es2) | Imperial Arbiter | `snake01` | `sn01_` | `sn01_stand_idle_alt_05`（45 帧）✅ |
| 雷兽 leishou | Imperial Arbiter | `bigcat01`（目标） | `bc1_` | 修复中 |
| 跳虫 gou | Imperial Arbiter | `wolf01`（目标） | `wf1_`/`wolf01` 系 | 修复中 |

原版骨架 donor 与 clip 量：bigcat01=战神獒 73 clips（含擒杀 matched_attack、喷吐、跳跃攻击）；scorpion01=古墓巨蝎 138；bird01b=腐尸秃鹫 119；wolf01=恐狼 338；snake01=幽冥行者 889；humanoid01b=5050。

## RMV2 绑定诊断（二进制层）

- v8 RMV2 头 offset 8 起是**骨架名 ASCII 字段**（如 `bigcat01`、`scorpion01`、`humanoid01b`），肉眼可直接读。
- 未蒙皮 v7 文件特征：该字段为空，且全文无 bone/skin/weight 相关字符串；AssetEditor 显示 `No Skeleton`、动画 `0/0` 帧。
- 网格信息面板的「顶点类型」：`Cinematic` = 蒙皮格式（有骨骼权重槽位）；静态格式则不会动。
- ⚠️ 判断绑定坏没坏以"日志有 clip 加载 + 帧计数 >0 + 模型变形"为准；只改文件头骨架名**不够**（缺真实权重数据）。

## Skin Wrap 重绑定流程（实测于 leishou_2）

适用：网格无蒙皮（No Skeleton）但形状与某原版单位接近，想把权重从原版蒙皮网格按距离抄过来。

1. 打开坏模型（leishou_2）进 Kitbash。
2. 工具栏「Import Reference model」（文件夹+图标）→ pack 选择器 → 搜 `tmb_warsphinx_01.rigid_model_v2` → 选中 → 确定。
   - ⚠️ 参考网格会落进 `Editable Model > Lod 0`（不是单独的 Reference 节点）——**保存前必须删掉**，否则会被写进输出文件。
3. 开 Pin 工具（工具栏红色图钉图标）→ 模式下拉选 `SkinWrap`（用 UIA SelectionItemPattern 选最稳）。
4. **目标列表**：在右侧对象树右键任一 `lzd_bastiladon_03` 行 → `Select Similarly Named`（同前缀全选，状态栏变 `Selected Objects: 19`）→ 点第一个「添加选中的 Mesh」。
5. **源列表**：Ctrl+点击选中 `merged_tmb_warsphinx_armour_01` + `tmb_warsphinx_body_01`（status: 2 objects）→ 点第二个「添加选中的 Mesh」。
6. 点「应用」。日志确认：`Applying SkinWrap to 19 meshes` → `SkinWrapRiggingCommand::Execute ... 19 target meshes, 2 source meshes, vertex format 'Cinematic'` → 大量 VertexBuffer 重建。
7. **删掉参考网格**：选中 2 个 warsphinx 网格 → 按 `Delete` 键（DeleteObjectCommand 热键就是裸 Delete；工具栏垃圾桶图标在 Merge 右边——别点错，Merge 会弹 Combine Errors）。`Objects` 数从 26→24。
8. ⚠️ 同文件内其他未蒙皮部件（如 `bst_warhounds_head_02` ×2）**不在** "Similarly Named" 选择里，要单独再做一次包裹。

## 保存与覆盖

- 当前两个 pack 都显示 `[Read Only]`——保存前需对 `zzz_czx_swarm_units` 设为可编辑（Pack 浏览器右键）或走 File → Save As 指定目标 pack/路径。
- 输出目标：同路径 `variantmeshes/wh_variantmodels/bc1/tmb/tmb_warsphinx/leishou_2.rigid_model_v2` 写进 `zzz_czx_swarm_units.pack`，靠"靠前 pack 同路径遮蔽"覆盖 Arbiter 的坏文件（加载顺序已在 playset 里调好：swarm_units 在 Arbiter 之前）。

## UI 自动化要点（本机实测）

- **坐标换算**：截图是 2560×1440 全桌面，AssetEditor 窗口内 UIA/物理坐标 ≈ 截图坐标 ×1.58（再视窗口偏移微调）。先 `_shot.ps1` 截图，再按比例算真实坐标点击。
- `scratch/` 下的辅助脚本（全 ASCII，勿写中文字面量——PS1 编码会炸）：
  - `_shot.ps1` 截屏到 `scratch/shot.png`；`_crop.ps1 -x -y -w -h -scale -out` 区域放大裁图
  - `_click.ps1`/`_dclick.ps1`/`_rclick.ps1`/`_ctrlclick.ps1`/`_hover.ps1`/`_wheel.ps1`/`_drag.ps1`/`_keys.ps1`（SendKeys）
  - `_uia_*.ps1`：`_uia_allwins` 列顶层窗口、`_uia_findname` 按名字找控件、`_uia_invoke -x -y` 按坐标 Invoke 按钮、`_uia_selmeshes`/`_uia_pinbtns`/`_uia_combo`/`_uia_menu2`/`_uia_tip` 等专用探测
- UIA 可见：菜单栏、状态栏、ComboBox、标准按钮、Pack 文件树（TreeItem）。**不可见**：右侧对象树、3D 视口（自绘控件）——那棵树只能坐标点击；右键行的上下文菜单含 `Lock / Invert Selection / Select Similarly Named / Remove`。
- 点击坑位：单行复选框在行首（点偏会切可见性而非选中）；对象树选中**不高亮**（看状态栏 `Selected Objects: N` 确认）；Pin 工具按钮有时要点两次，用 `_uia_invoke` 更稳。
- 工具栏图标顺序（源码 MenuBarViewModel.CreateButtons）：Save → ImportRef → Undo │ DivideSubMesh → Merge → Duplicate → **Delete** → FreezeAnim │ ReduceMesh → MeshFitter(人形) → ReRigging(骨架) → **Pin(红图钉)** → AssignTexture → PhotoStudio(相机)。
- Pin 工具窗口关键坐标（窗口位于主窗口左上，real 坐标）：目标「添加选中的 Mesh」≈(413,521)，目标「移除全部」≈(611,521)，源「添加选中的 Mesh」≈(413,681)，「应用」≈(512,706)。模式下拉 ComboBox ≈(408,348)。
- 模态错误框（如 Combine Errors）渲染在主窗口**内部**，不是独立 HWND；「关闭」按钮用 UIA 找（相邻「保存报告」按钮 @747,684 可作参照）。

## 无头动画验收管线（Blender 出图）[实测]

AssetEditor 的 D3D 视口在本机截图里始终黑/白（UI 树和日志正常，渲染层截不到），因此最终动作验收改用 Blender 无头渲染，脚本已入库：

- `tools/parse_anim_clip.py`：完整 .anim clip 解码器（v6/v7/v8），按 AssetEditor 源码 `Shared/GameFiles/Animation/AnimationFile.cs` 移植：
  - 头：`version u32, unk u32, frame_rate f32, skeleton_name str16, flag_count u32 + flag str16*（v8 也写，恒 0）, play_time f32`
  - v8：bones 之后是 `unk u32 + part_count u32`；每个 part = 两张 `bone_count` sbyte bitrate 表（平移/旋转，>0=动态轨道，<0=静态轨道，0=不動）→ `range_map` 两个长度+数据 → 静态帧（bitrate 取负解读）→ 动态帧数+逐帧数据。bitrate 12=vec3 float，3=sbyte×3 按 range_map 解码（`v = max + b/127*min`）；旋转 8=short×4/32767，4=sbyte×4 按 range_map。
  - v7：bones 之后是两张 `bone_count` int32 映射表 + 静态帧计数/数据 + 动态帧。
  - clip 可有多个 part（hu6 攻击 clip 有 2 个：主动画+第二段），取帧数最多的。
  - 映射值 -1 的骨骼=未动，要回退到骨架 bind pose 局部 TRS（从 `world_pos/quat_frame0` 反推：local_pos = qrot(conj(parent_wq), wp-wp_par)）。
- `tools/blender_pose_render.py`：`blender -b -P ... -- <skinned.glb> <pose.json> <frame> <out.png> <skel.json>`，Cycles CPU 700×700，加地面+双太阳灯。
  - **关键坑**：glTF 往返后 Blender 骨骼 `matrix_local` 的朝向（roll）与骨架 frame0 节点朝向**不一致**——`pb.matrix = anim世界矩阵` 直接设会把网格扭碎（摆到 bind pose 也碎）。正确目标 = `C@(A·B⁻¹)@C_inv @ bone.matrix_local`（动画世界增量 × Blender rest 帧）。bone 顺序按 parent 索引升序保证父先子后。
  - 用 `pb.matrix_basis` 设姿态；验证过全部骨骼 `pb.matrix == desired` 零误差。
- `tools/blender_rig.py` 已加**装饰骨黑名单**（prop/cape/skirt/belt/sleeve/cloth/loincloth/flag/feather/wing/finger/thumb/platform/antenna/eyestalk 等，正则匹配）——否则薄片状甲壳/刃臂会被最近的布料/挂载骨抢走，动画一播就撕碎。[实测：爆虫上半身曾被 platform_section_* 抢走，小白刃臂曾被 skirt_*/cape_* 抢走]
- 验收矩阵驱动：`scratch/_render_matrix.py`（每单位 idle×1帧 + attack×3帧，输出 `scratch/pose_shots/`）。
- 检查要点：剪影连贯、无放射状碎片、脚/爪贴地、攻击帧有实际位移。

## 遗留问题（进行中）

- leishou_2 已完成 Skin Wrap（19 个 lzd 网格）并删除参考网格，但**动画预览仍未播放**：场景 Skeleton 节点为空，动画面板显示 `bigcat01.anim - bc1_attack_01.anim` 而日志无 `Loading animation: bigcat01.anim`——骨架文件未被引擎加载。待解：可能是预览控件状态问题，也可能需要让 RMV2 先写骨架名。下一步：保存文件→二进制验证 offset 8 骨架名与权重串→重开文件再播动画。
- `bst_warhounds_head_02` ×2（雷兽头部件）未包裹，需对它们单独跑一轮 Skin Wrap（重新导入 warsphinx 参考→删）。
- `g.rigid_model_v2`（跳虫，wolf01 骨架）同样未蒙皮，流程相同，参考源用原版恐狼网格（anim pack `animations\skeletons\wolf01.anim`）。
