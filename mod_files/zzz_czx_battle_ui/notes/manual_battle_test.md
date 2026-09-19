# 手动遭遇战测试流程（已验证可用路径）

`game_startup_mode battle <xml>` 直进战斗的路线在本机上不稳定（多次 init 即退 /
Steam API `loaded no` / 偶发 Mutex error），已验证可用的替代路径：

## 步骤

1. **拉起游戏到主菜单**（离线状态即可，mod 照常加载）：
   - `python scratch/czx_battle_test/launch_autotest.py --menu`
   - 只写 `czx_launch_mods.txt`（全 playset + 测试包替换）后裸启动 exe，
     不传 `game_startup_mode`。**注意：不要加 `--drop-tc`**——实测排除
     `zzz_czx_battle_tactical_commander.pack` 的启动三连崩，包含它才稳
     [实测/原因未明]。
   - 或用 Mod Manager 正常启动《全合集》playset（加载的是正常包）。
2. 主菜单 → **战斗** → **遭遇战（电脑）**。
3. 军队设置：任意混编（领主 + 步兵 + 骑兵 + 远程 + 巨兽最佳，能覆盖
   克制矩阵的所有角色分类）。攻守双方随意。
4. **开始战斗** → `czx_battle_auto_ability` 自动载入：
   - 日志出现 `loaded, poll ...` + `auto-delegate units=N` + `roster ally/enemy`。
   - 若加载的是测试包（`test_sim=true`），还会出现 `sim speed x4` +
     `sim-cycle N ordered/reclaim/back` 自动手操循环。
5. 测托管/接管（真实玩家操作，比 uc:goto 模拟更保真——会触发
   `reclaimed-cmd` 指令事件路径）：
   - 框选/点卡片选中已托管单位 → 下移动/攻击令 → 日志应出
     `reclaimed-cmd` 或 `reclaimed-ordered`。
   - 组 AI 开关重新打开（或点托管按钮）→ `handed-back`/`adopted`，
     单位自动回任务层。
   - 反复交替几次，观察 `tick-stats del=` 数是否稳定回升。
6. 战斗结束后看 `script_log_<date>_<time>.txt`（游戏根目录）：
   - `roster` 双方开局兵种×角色、`tick-stats` 每 60s 战况、`outcome` 胜负。

## 注意事项

- 当前 Digimon 最小集实例（`czx_min_mods.txt`）**没有我们的包**，测试无效。
- 测试包与正常包同名脚本互斥：modlist 里二选一，不要同时挂。
- `battle.xml` 是引擎保留名，`game_startup_mode` 传它会回退主菜单——
  自定义文件名（如 `czx_test_battle.xml`）才行；但该路线整体已弃用。
- 杀进程会写 `no_clean_exit` 标记，偶发影响下次启动；异常时先清
  `%APPDATA%\The Creative Assembly\Warhammer3\logs\no_clean_exit`。
