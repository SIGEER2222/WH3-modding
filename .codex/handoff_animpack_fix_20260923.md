# 交接：宝可梦/数码宝贝/虫群 无移动/攻击动画修复（2026-09-23）

> 给接手 AI：先读 `AGENTS.md` + `.codex/project_context.md`（续6/续7 两节有同内容精简版）。本文件是完整技术交接。

## 一句话状态

根因已修复并部署完毕：**离线验证全通过，游戏内实测因环境级启动崩溃未完成**——三包已在 `data\`，用户随时可玩验证，或由下一个 AI 继续等启动窗口截图验证。

## 根因

三个自制单位包的战斗动画集以 loose `.bin` 放在 `animations/database/battle/bin/`——**战斗系统不索引 loose bin**，必须装 `.animpack` 容器。症状：模型正常进场、全程绑定姿势、无任何动画（非白模，是正常材质+零动画）。

证据链（全部离线验证过）：
- vanilla：`animations/database/battle/bin/animation_tables*.animpack`
- Imperial Arbiter（工坊确定能动）：`animations/database/battle/bin/h3_yu_monsters.animpack`
- 数码宝贝 v1（确定能动）：50 个 `chr###.animpack` + **0 个 loose bin**
- 我们的三包原先：loose `.bin` ×7/104/4，无 animpack

## 已完成的修复

1. **新工具 `tools/pack_animsets.py`**：离线把 loose bin 打成 animpack（无需 AssetEditor）。
   - 格式：`u32 条目数` + 每条 `{str16 内部路径 + u32 长度 + bin 原字节}`
   - 内部路径约定 `animations/database/battle/bin/<animset_key>.bin`
   - 用法：`python tools/pack_animsets.py <mod_dir名> [--out x.animpack] [--remove-loose]`
2. **三包各生成 `<mod>_animsets.animpack`**：pokemon 7 条 / digimon_v2 104 条 / swarm 4 条 animset。
3. **删除全部 loose `.bin`**：对齐 v1 范本"animpack-only"布局，消除重复注册/遮蔽风险。swarm 的 `.bin.bak` 挪到 `scratch/swm_bin_bak/`。
4. **附带修复**：4 个 bin 引用 `reference_poses/czx_*.anim` 但文件名是旧名 `pm###.anim` → 已用 `tools/anim_rw.py` 改 skeleton_name 落盘为 czx_* 名 + 补 invmats。
5. **重建+部署**：`zzz_czx_pokemon.pack`→同名、`zzz_czx_digimon_v2.pack`→同名、`zzz_czx_swarm_units.pack`→**`zzz_czx_swarm_units3.pack`（部署名不同！）**。三包 SHA-256 与 mod_output 一致，playset/used_mods 未动。
6. **用户改动已并入**：`!!pkm_pokemon.tsv` land_units 5 只 blood 列统一为 `wh_main_monster_wolf_hound_blood`——已重建部署（37.5MB/2336 文件）。
7. **并行会话成果已并入**：宝可梦 bin 换成完整 donor animset（hu1 系 107KB/只 ≈380 clip 引用），clip 树扩到 1181 个 `.anim`（deaths/docking/face/hands 全套）。审计：3206 条引用中 0 条 `.anim` 缺失；缺的 `.anm.meta`/`.snd.meta`/`locomotion_graph` 全是指 vanilla 的软引用（原版容忍，与 vanilla bin 行为一致）。

## animpack 格式细则（已逆向确认）

| 范本 | 结构 |
|---|---|
| 数码 v1 `chr###.animpack` | **裸表**：u32 count + 每条 {str16 path + u32 len + bin bytes}，无压缩 |
| vanilla `animation_tables*.animpack` / IA `h3_yu_monsters.animpack` | u32 解压尺寸 + LZ4 frame（magic `04 22 4d 18`）包裹同一张表 |

两种游戏都认。我们的用裸表（=v1 同构）。文件名自由（IA 名 `h3_yu_monsters` 证明任意名可）→ 游戏扫描 `animations/` 下全部 `*.animpack` 合并。

## 离线验证清单（全过）

- animpack 解析：条目数对、读到 payload 末尾、无缺失引用 bin ✓
- bin 内 animset 名 = 路径 stem ✓
- 引用 `.anim` 全存在（0 缺失）✓
- RMV2 头 offset 12 骨架名 = battle_skeletons.name（czx_bu/ve/charma/chari/squirt/blasto/pikach 等）✓ ——注意：**旧文档记 offset 8 是错的，已改 references 两处**
- culture_to_battle_animation 覆盖 wh_main_vmp_vampire_counts + wh_main_emp_empire（自测 XML 两派系）✓
- pack 内 animpack=1 + loose_bin=0 ✓

## 游戏内自测（被环境阻塞，待续）

**测试资产已备好**：
- `scratch/battle_animverify.xml`：敌方 vmp 10 个自定义单位冲锋（pkm_001/004/006/025、czx_dgm_agumon/wargreymon/guilmon、czx_mangshou/dehaka/inf_marine），我方 emp 5 个原版兵接战——敌冲锋会演 walk/run/attack/death 全套
- `scratch/anim_verify_mods.txt`：modlist（runtime_options + 三包，注意 swarm 部署名 units3）
- `scratch/retry_battle.py <xml名> <modlist路径> [attempts] [watch_s]`：等 Steam-respawn 子进程存活判定
- `scratch/anim_verify/opportunistic_shot.py <时长s> <tag>`：监视 ws>1.5GB 的 Warhammer3 进程自动 ImageGrab 截图（4s 间隔）
- 截图读法：`scratch/` 被 .gitignore，read 工具拒读——拷到 `C:\Users\22448\AppData\Local\Temp\animverify\` 再读
- `tools/battle_autotest.py`（Windows Python313 跑）：单次拉起 + dump 监控

**阻塞**：2026-09-23 19:00–20:15 约 20 次拉起全部死于 gfx/D3D 早期初始化，签名 `+0x2cfe551` / `+0x4926f0` / `+0x2ccd91x`——9-22 已记录的**环境级 flaky 窗口**（vanilla 同签名，与包内容无关；当时疑 GameViewer 远程会话，本次无远程进程但同样全挂）。最好成绩 child 活到 2.7GB/83s cpu 后静默死。**尚未做过 vanilla 基线 A/B**（刚要跑被打断）——若继续受阻，先跑 `--mods none` vanilla 对照彻底排除包因素。

## 下一步（按优先级）

1. **vanilla 基线**：`anim_verify_mods_none.txt`（空 modlist）跑几次——若 vanilla 也全挂 = 纯环境；若 vanilla 过 = 包问题回头查 animpack。
2. **窗口来了**：opportunistic_shot 自动抓帧 → 逐帧看自定义单位四肢/身体姿势是否变化（≠绑定姿势滑行）。
3. **用户侧**：包已在 data\，用户开游戏打一局即可直接验证。
4. **若动画仍不播**：查 `wh3diag.py usedmods` 实际加载包名（旧 `zzz_czx_digimon.pack` 非 v2 不在 playset）→ animpack 扫描约定 → 动画槽语义 → RMV2 权重。
5. **确认后**：`references/custom_model_unit_pipeline.md` L157 的 `[实测/需随版本复查]` 转正；CHANGELOG 已记。

## 关键路径

- 工作区 `E:\Code\WH3-modding`（WSL `/mnt/e/Code/WH3-modding`）
- 游戏 data `E:\Program Files (x86)\Steam2\steamapps\common\Total War WARHAMMER III\data`
- Windows Python313：`C:\Users\22448\AppData\Local\Programs\Python\Python313\python.exe`（含 lz4/PIL；WSL python3 无）
- 打包：`tools/build_pack.py <mod> [--deploy]`（必须 Windows Python，硬编码 E:\ 路径）
- 诊断：`tools/wh3diag.py`（ls/meta/which/db/crashes/usedmods）

## 勿踩的坑

- 游戏运行中 data\ 的 pack 被文件锁——等退出再复制；挂载期间重写包=必崩
- 同一时刻只许一个游戏拉起（16GB 内存，战局 40-55GB commit）
- 禁止关闭玩家手动开的游戏
- heredoc 里写反引号代码段会被本 shell 层吃掉（`bash -c` 双重解析）——写 markdown 用 write/edit 工具
- `scratch/` 在 .gitignore：write/read 工具拒读写，用 exec+重定向写，看图先拷 Temp
