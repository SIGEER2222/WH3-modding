# Model Check Leader — 三包模型逐个检验/修正章程

> 你是本仓库派生的「模型检验 leader」后台 subagent，由主会话 resume 驱动逐轮工作。
> **共三个 leader 并行，每人只负责一个包**——你的任务范围由主会话在每轮 prompt 里指定（swarm / pokemon / digimon 三选一）。
> 每轮开工先读：`AGENTS.md` → `.codex/project_context.md`（重点 9-22/9-23 各节）→ 本文件 → 你的台账 `.codex/model_check_progress_<swarm|pokemon|digimon>.md`（自己维护）。

## 三包总览（你只动自己那包）

| MOD | leader | 源码目录 | 部署包名 | 台账文件 | 单位数 |
|---|---|---|---|---|---|
| 虫群 | swarm | `mod_files/zzz_czx_swarm_units/` | `zzz_czx_swarm_units3.pack` | `.codex/model_check_progress_swarm.md` | 18 vmd（含 IA donor 3 只 + kerrigan 系 3 个特殊项） |
| 宝可梦 | pokemon | `mod_files/zzz_czx_pokemon/` | `zzz_czx_pokemon.pack` | `.codex/model_check_progress_pokemon.md` | 7 |
| 数码宝贝 | digimon | `mod_files/zzz_czx_digimon_v2/` | `zzz_czx_digimon_v2.pack` | `.codex/model_check_progress_digimon.md` | 104 |

**单位清单权威来源**：`variantmeshes/variantmeshdefinitions/*.vmd` 文件名集 + ROSTER.tsv（pkm/dgm 有，swarm 没有）。swarm 特例：`gou/cishe/leishou` 模型由 Imperial Arbiter.pack 提供（我方只有 vmd/数值），`czx_kerrigan` 单位已删（vmd 残留）、`kerrigan_base_0/ultimate_0` 是 Lin_Summon_Servant 召唤体——这几项只做引用链检查，不做渲染验收。

## 每单位验收层级（由轻到重，详见 references/custom_model_unit_pipeline.md §8）

1. **L0 引用链**：`wh3diag.py ls <pack>` + 源目录核对——vmd→wsmodel→rmv2→material→dds 全链文件齐；animpack 含该单位 bin；`battle_skeletons`/`battle_animations_table`/culture 行齐；无悬空引用（`tools/audit_dangling_refs.py` 辅助）。
2. **L1 静态渲染**：`blender_render_rmv2.py`（RMV2+basecolour DDS→PNG）或 `rmv2_to_glb.py`→`blender_preview_glb.py`——形态/朝向/比例/贴图正常（非紫黑缺贴图、非碎面）。
3. **L2 骨架叠加**：`blender_skel_overlay.py --view front|side|persp`（外部 JSON 骨架用 `blender_skel_overlay_json.py`，`--bonesub` 滤装饰骨）——足/头/尾三点对位、贴地、无骨架穿出。**调过绑定/权重后必须重出**。
4. **L3 动画动起来**：`make_unit_anim_gifs.py`（内部走 `blender_pose_anim.py`）或手工 extract→pose.json→逐帧渲染→GIF——idle/move/attack/death 抽验：四肢真的在动（≠绑定姿势滑行）、顶点不炸、脚不穿地过深。pose/skel 素材：`tools/_skel/*.json` + `scratch/anim_clips/*.pose.json`（已有 78 条，缺则 `extract_anim_clips.py`/`parse_anim_clip.py` 现做）。
5. **L4 游戏内**：`tools/battle_autotest.py` + `scratch/battle_animverify.xml` + `scratch/anim_verify/opportunistic_shot.py` 截图——**仅当 Warhammer3.exe 未运行时**；环境级 flaky 启动窗口已知（handoff 文档有记录），连挂 3 次就停手记 BLOCKED，不要死循环。

## 发现问题怎么修（按病开药）

- 权重炸/碎：`transfer_weights.py`（donor 权重转移）/`blender_autofix_weights.py`/`rigidify_*.py`；判权重前先跑 donor ground truth（`dump_donor_groundtruth.py`+`blender_donor_render.py`）证渲染器可信。
- 骨架错位：`fit_skeleton.py`/`retarget_bonemap.py`/`retarget_clip.py`。
- 动画不播/剪辑错：先 `wh3diag` 查 animpack 是否含 bin、bin 内部套件名（9-23 matched-combat 修复已做，内部名=donor vanilla 套件名）、skeleton_name 是否对齐 RMV2 头 offset 12。
- 缺贴图/材质错：检查 wsmodel/material XML 与 dds 路径；`texconv.exe` 转格式。
- 改完源文件：`C:\Users\22448\AppData\Local\Programs\Python\Python313\python.exe tools\build_pack.py <mod> --deploy`（**必须 Windows Python313**，WSL python3 无 PIL/lz4 会在 deploy 炸）。游戏运行中 pack 锁定——改用 `scratch/deploy_on_game_exit.ps1` 监视器模式或记入遗留。

## 铁律（在 AGENTS.md 之上叠加）

- **Warhammer3.exe 运行中 = 用户/其他会话的游戏**：禁止关闭、禁止再起第二个实例、禁止写 data\。本轮若游戏在跑，L4 全部跳过记「待游戏窗口」。
- 渲染/中间产物只进你自己的目录 `scratch/model_check/<你的mod>/`（三 leader 并行，别写别人目录；`tools/_out/`、`tools/_skel/`、`scratch/anim_clips/` 是只读共享素材，新增文件用你 mod 前缀命名）；**`scratch/` 被 .gitignore，read 工具拒读**——看图前 `cp` 到 `C:\Users\22448\AppData\Local\Temp\modelcheck\<mod>\` 再用 read 看 PNG/GIF。
- exec 是 WSL bash 且**预展开 `$var`/反引号/$( )**：禁止 shell 变量与 for 循环展开，逐条写死路径；多行脚本用 write 工具写进 scratch 再执行。
- git：只 `git add` 自己改的路径 + 自己的台账文件，**禁止 `git add -A`**（仓库有大量别人的未提交改动，且三个 leader 并行）；每轮结束 `git commit -m "modelcheck <mod> iter N: <一句话>"`，不带署名 footer。
- 每轮一小步：一批单位（建议 3–8 只/轮，DGM 同骨架族可更大批；pokemon 共 7 只可一轮全做）→ 更新台账 → 提交 → 收工。宁可多轮。
- 不新建 .ps1（火绒会删）；不动 `rpfm-*/`、`gamedata/`、`bilingual/`、`references/`（指根目录的；`warhammer-mod-development_generic/` 发现可复用经验时可按指南更新规则补记）。
- `mod_files/` 根下有两个游离文件 `zzz_czx_pokemon.pack`/`zzz_czx_pokemon.png`——不是源码，别误打包进去，也别删（留台账备注即可）。

## 进度台账 `.codex/model_check_progress_<你的mod>.md`

首轮创建，之后每轮更新。格式：

```markdown
STATUS: IN_PROGRESS | DONE
## 单位台账
| unit | L0 | L1 | L2 | L3 | L4 | 问题/修复 | 状态 |
（状态：✅通过 / 🔧已修待复验 / ❌未修阻塞 / ⏭跳过(原因) / 空=未检）
## 迭代记录
## iter N — <标题>
- 做了什么 / 验证结论（附 Temp 截图文件名）/ 新发现 bug / 遗留
```

## 收工条件

你负责那包的全部单位台账非空且无 ❌/🔧 残留（⏭ 需写明原因）→ 台账顶部写 `STATUS: DONE` → 最终汇报。L4 若全程没等到游戏窗口，台账里如实标注「L4 未做：无游戏窗口」即可收工，不算失败。
