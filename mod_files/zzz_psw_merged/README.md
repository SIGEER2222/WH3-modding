# zzz_psw_merged — PSW 补丁合并包

《魔女の祈祷》（Prayer of Star Witch）的合并补丁。把原先散落的 4 个 `zzz_psw_*` 补丁合并成一个 pack，并修复了动态天赋上限和重抽功能。

## 斯卡文抽奖槽位隔离

PSW 抽奖把抽中的天赋写入 `foreign_slot_manager` 的前四个槽。斯卡文地下城也使用这个管理器；旧逻辑只检查管理器是否存在，可能把地下城的四个建筑槽误当作 PSW 抽奖槽。

现在斯卡文会核对 `slot_set_key`，只在玩家拥有且没有其他 foreign slot set 的地区建立独立 `psw_cult_slot_set_key`。抽奖、天赋清理和失败回退都走同一管理器；找不到安全地区时跳过抽奖，不触碰地下城。旧档首次抽奖会迁移到安全地区；此前已被旧版抽奖覆盖的地下城建筑无法从当前存档自动还原。

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

### 6. 祈愿水晶 UI 对全派系可见（2026-09-13）

主 MOD `psw_资源UI显示.lua` 只对 17 个 culture 白名单创建 `psw_main_qysj_holder` 顶栏组件；鼠人（`wh2_main_skv_skaven`）、帝国、诺斯卡、暗精、蜥蜴人、古墓王、吸血鬼海岸不在其中，水晶正常累积但不显示。

修复：新增 `script/campaign/mod/psw_08_qysj_ui.lua`，对人类派系幂等补建该组件（已存在则跳过，与主 MOD 创建互不干扰）。

### 7. Mixu 兼容补丁移到主包之后的 pack（2026-09-13）

原 `zzz_psw_mixu_compat` 片段（4 张表）与主 MOD `psw_*` 片段存在同 key 行冲突（`PSW_HORDE`、各 `remove`/`permitted` 行）。实测 WH3 对**不同名片段的同 key 行**按 **pack 加载顺序、后者胜出**裁决（片段文件名含 `!` 前缀无效）——主包在 playset pos 106、本包 pos 94 → 主包 `slot_cap=14` 一直胜出，`slot_cap=30` 与 `psw_horde_*` 模板**从未生效**（日志实测 `BuildingSlotList` 只有 14 槽）。

修复：4 个片段（改名 `!!czx_psw_mixu`）移到 `zzz_czx_auto_tools.pack`（playset pos 135，在主包之后）：
- `PSW_HORDE` 使用 `psw_horde_primary/secondary` 模板，`slot_cap=30`
- `horde_*` 通用模板上的 PSW 建筑链许可被 `remove` 行移除（不再泄漏给其他原版游牧）
- 其他原版游牧 force 的 `slot_cap` 一并提升为 30
- 注意：Lua 同路径覆盖仍需要本包排在主包**之前**，方向与 DB 行覆盖相反，所以 DB 补丁只能拆到别的 pack

### 8. 拆除天赋提示弹窗修复（2026-09-12）

`psw_06_chaichu.lua` 拆除成功后调用 `cm:show_advice("psw_chaichu_done")`，但此前包内缺少 advice DB 记录，loc 又误用 `advice_info_text_` 前缀 → 点击确认按钮弹出不可关闭的 "Placeholder Body" 模态框。

修复内容（已重建部署）：

- 新增 `db/advice_threads_tables/zzz_psw_chaichu.tsv`：`psw_chaichu_done` / `warhammer3`
- 新增 `db/advice_levels_tables/zzz_psw_chaichu.tsv`：key=`1214413929`，克隆主 MOD `advice_psw_tf_ex_yhzl_1` 行（`advice_lmyx` 头像、Scripted 分类、`force_2d_portrait=true`）
- `text/psw_chaichu.loc.tsv` 追加 `advice_levels_onscreen_text_1214413929` = `已拆除该天赋。`（advice 正文 loc 约定是 `advice_levels_onscreen_text_<levels.key>`，不是 `advice_info_text_` 前缀）

## 回滚

删除 `data/zzz_psw_merged.pack` 和 `data/zzz_psw_merged.png`，把 `data/psw_old_backups/` 里的原文件移回 `data/` 即可。
