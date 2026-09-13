# lalolalo9_autoconstruction —— Lalolalo9 自动建设（默认开启版）

来源：游戏 `data\Lalolalo9Autoconstruction.pack`（本地 pack，mod_id `local:data:3dd38215e25f07e687`）的脚本副本 + 默认值修改。

## 改动（2026-09-12）

原 MOD 的自动建设开关 `Lalolalo9AutoConstructionEnabled` 默认 `0`（关），顶部状态条显示 "Currently disabled"，且开关按**存档**持久化——每个新存档都要手动点一次启用。

本副本把默认值改为 `1`（开）：

- 第 1 行 `local Lalolalo9AutoConstructionEnabled = 0` → `= 1`
- `lalolalo9_Autoconstruction_init` 里无存档值时的 else 分支 `= 0` → `= 1`

行为：

- **无存档值**（新战役/从未设置过的存档）：默认开启，回合开始时自动建设+升级（`StartEnd=0` start、`AutoConstructAutoupgrade=0` construct+upgrade、默认优先级表=全部建筑）
- **已有存档值**：尊重存档里的设置——在本 MOD 里手动关过的存档仍然保持关
- 顶部状态条点击 → Building Browser → 红叉按钮仍可随时关闭并写回 `0`

## 重建

```powershell
python tools/build_pack.py lalolalo9_autoconstruction
# 输出 mod_output/lalolalo9_autoconstruction.pack
# 部署时改名覆盖 data\Lalolalo9Autoconstruction.pack（保持原文件名 → playset mod_id 不变）
```

原版备份：`scratch\Lalolalo9Autoconstruction.pack.bak`（2026-09-12 修改前）。
