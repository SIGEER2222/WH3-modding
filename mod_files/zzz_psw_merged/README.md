# zzz_psw_merged — PSW 补丁合并包

《魔女の祈祷》（Prayer of Star Witch）的合并补丁。把原先散落的 4 个 `zzz_psw_*` 补丁合并成一个 pack，并修复了动态天赋上限和重抽功能。

## 这个补丁做什么

给主 MOD「魔女の祈祷」补充三块功能：

### 1. 天赋系统补全

原 `zzz_psw_lua_fix.pack` + `zzz_witch_talent_limit_fix.pack` 的内容。

- **天赋觉醒**：人物升级到一定等级后触发天赋选择，包括救济的魔女、圆环之理、奇迹与星星的魔女、灰之魔女、神圣的祈祷、庭园部の天才魔女、怪力魔女等多条天赋线
- **游戏王抽卡系统**：派系按钮 UI + 抽卡逻辑
- **25 回合祈愿**：25 回合后可选择祈愿装备或天赋
- **难度选择系统**：根据难度调整效果
- **天赋效果实现**：鹿目圆专天（魔法少女之神）、蓝毛红毛专天、夜斗五元神明、mika 本笃会、祈愿水晶每回合自动获得、塞勒姆的魔女外神注视、冰结の魔女等
- **长生久视**：人物 10 级后获得长生效果
- **闪避技能管理**：批量删除/添加闪避相关 effect bundle
- **免疫死亡**：每回合控制免疫死亡次数和生命恢复上限 buff
- **属性提升**：回合开始时重新统计属性

### 2. 动态 EX 天赋上限（已修复）

原 `zzz_psw_dynamic_ex_limit.pack` 的内容，修复后可正常堆叠。

- 每次触发可动态增加 1 点 EX 天赋上限（参考和泉纪愛三星卡效果）
- **最多可堆叠 20 层**（+20 EX 天赋上限）
- 使用独立 effect bundle（`set_ex_shangxian_1` ~ `set_ex_shangxian_20`）实现可堆叠，每层一个独立 bundle
- 第一次触发时播放音效和提示
- 自动初始化玩家数据

> **修复内容**：原版只定义了 `set_ex_shangxian` 一个 bundle，动态堆叠用的 `set_ex_shangxian_1`~`_N` 在 DB 中不存在，导致 `create_effect_bundle` 失败。本补丁新增了 `db/effect_bundles_tables/zzz_psw_merged` 表，定义了 20 个堆叠 bundle。同时修复了函数名不匹配问题（`psw_aplly_costom_effect_bundle_hidden` vs `_fn` 后缀），添加了别名兼容。

### 3. 无限重抽（已修改）

抽卡系统的重抽限制已取消。

- **无限重抽**：不再限制每回合一次，也不限制是否有 `psw_yi_p1ck` 标记
- 只要有抽卡资源（`psw_main_gmsj >= 0`）即可反复抽取
- 部分天赋选择仍会赠送免费重抽次数

> **修改内容**：`psw_can_repick` 始终返回 true；`psw_天赋.lua` 中去掉了 `psw_yi_p1ck` effect bundle 的检查分支，无论是否已选过唯一天赋都可以重抽。

### 4. AI 回合原生闪退修复（v6，已实测有效）

- 根因定位：游戏在**轮到 AI 派系 `wh3_main_cth_eastern_river_lords`（东江诸侯）处理回合时**发生原生崩溃（`0xC0000005`，读空对象偏移 `0x18`），Lua 层无法拦截。
- v6 方案：读档首 tick 即抹除该派系——议和 → `kill_all_armies_for_faction` 杀光军队 → `set_region_abandoned` 放弃全部城镇 → 清理残余人物 → `force_diplomacy` 锁死防复活，并有 `FactionTurnStart` 监听器兜底。
- 仅 AI 控制时生效；玩家选该派系不受影响。
- **代价**：东江诸侯派系从该战役中永久消失。
- 游戏日志出现 `[psw_guard] v6 installed` 和 `v6 KILLED` 表示已生效。

### 文件名说明

源文件使用 `psw_01_global_vars.lua`、`psw_02_tianfu.lua`、`psw_03_tianfu_xiaoguo.lua` 便于维护；`tools/build_pack.py` 打包时把它们映射为主 MOD 的中文内部路径（`psw_全局变量总表.lua`、`psw_天赋.lua`、`psw_天赋效果.lua`），从而覆盖同路径脚本而不是重复加载。`psw_04_dynamic_ex_limit.lua` 是主 MOD 没有的新增脚本。

### 5. Mixu 兼容（Horde 槽位）

原 `zzz_psw_mixu_compat.pack` 的内容。

- 新增 PSW 专属 Horde 军事力量类型 `PSW_HORDE`
- 定义主槽位 `psw_horde_primary` 和副槽位 `psw_horde_secondary`
- 配置 26 条建筑链许可，让 PSW 的 Horde 派系能正常建造
- 槽位上限 14

## 依赖

- **必须**启用主 MOD：`!!Prayer_of_star_witch.pack`（Steam Workshop 订阅）
- 本补丁包含同路径 Lua 覆盖文件，必须在 MOD 管理器中放到主 MOD 上方（更高覆盖优先级）

## 加载顺序

```
zzz_psw_merged.pack           ← 本补丁（更高覆盖优先级）
!!Prayer_of_star_witch.pack   ← 主 MOD
```

不要依赖文件名的默认字母序；确认实际加载顺序后重启游戏，并在最新脚本日志中检查 `[psw_guard] v6 installed`。

## 合并说明

合并前的 4 个原文件已移到 `data/psw_old_backups/`，未删除，可回滚：

| 原文件 | 功能 | 状态 |
|---|---|---|
| `zzz_psw_lua_fix.pack` | 天赋系统 Lua | 已合并 |
| `zzz_psw_mixu_compat.pack` | Mixu 兼容 DB | 已合并 |
| `zzz_psw_dynamic_ex_limit.pack` | 动态 EX 上限 Lua + Loc | 已合并并修复 |
| `zzz_witch_talent_limit_fix.pack` | 天赋效果 Lua | 已合并 |
| `psw_complete_fix.pack.bak` | 旧备份 | 未合并，保留备份 |
| `psw_final_fix.pack.bak` | 旧备份 | 未合并，保留备份 |

## 回滚

删除 `data/zzz_psw_merged.pack` 和 `data/zzz_psw_merged.png`，把 `data/psw_old_backups/` 里的原文件移回 `data/` 即可。
