# 魔女塔（PSW Roguelike 爬塔）改造计划

> 状态：调研完成，待评审。本文档区分【实测事实】（已读源码确认）、【设计方案】（拟实现）
> 与【需验证】（API/数值/行为未确认，标注 `[需验证]`）。
>
> 调研对象（已下载并拆包，源码抽在 `scratch/_spire_src/`、`scratch/_gm_src/`、`scratch/_zzz_src/`）：
> - `adam_rogue_warhammer.pack` — RogueTotalWar: Warhammer Spire（wsid 3753323752，下称 Spire）
> - `GMrogue.pack` — slay the warhammer(rogue)（wsid 3781549276，下称 GM）
> - `zzzrougeheji.pack` — Roguelike Warhammer Simulator（wsid 3767769934，下称 zzz）
> - `adam_rogue_warhammer[EN].pack`（wsid 3753323879，Spire 英化补丁，仅 .loc 文本）

---

## 1. 外部 MOD 实现事实摘要

### 1.1 Spire（adamrogue）— 最完整，但架构与目标不同

**文件布局**【事实】：`adamrogue_mvp.lua` 26.6 万字节主编排 + `adamrogue/` 目录 14 个模块
（battle_generator / force_snapshot / reinforcement_battle / travel_anchor_manager /
runtime_state / ancillary_generator / enemy_skill_allocator / data_nodes / data_players /
data_battle_pools / data_ancillaries / 每种族一份 enemy_skills 数据 / balance_config /
data_cth）。MCT 设置脚本 1 个。入口按钮 twui 1 个。

**状态机**【事实】（`adamrogue_runtime_state.lua`）：

```
INIT -> OPENING_PENDING -> ARMY_PREVIEW_PENDING
     -> (UNIT_REWARD_PENDING | HERO_REWARD_PENDING)
     -> BATTLE_PENDING
     -> EQUIPMENT_REWARD_PENDING (胜)
     -> DESTINATION_PENDING -> 选目的地 -> 回到奖励/战斗
     -> FIRST_DEFEAT_PENDING (首败) / GAME_OVER (连败3次)
PAUSED 可从任意态挂起
```

**Run 载体**【事实】：run 的军队是**真实出生在战役地图上的部队**。
`cm:create_force_with_general` 在玩家母城附近生成"预览军"，经 ARMY_PREVIEW 困境确认后
成为 run 部队；层间通过 `travel_anchor_manager`（缓存约 30 个锚点坐标）把部队传送
到不同位置以换战斗地形。首次进 run 前 `force_peace_with_all_player_enemies` 强制
与所有交战派系议和（防原版外交战争的援军混入 mod 战斗）。

**战斗**【事实】：敌方用 `cm:create_force_with_general` 生成在玩家 run 部队旁边
（经 `EnemySpawn` 多层回退选址），`cm:force_declare_war` 后立即
`cm:force_attack_of_opportunity` 强开战斗。**不用** `teleport_and_prepare_for_battle`。
源码注释明确写了弃用商队 `create_caravan_battle` 传送方案的原因：会把玩家部队
拉到敌人生成点旁导致战斗无法正常触发。

**难度曲线**【事实】（`adamrogue_balance_config.lua`）：以 `cycle`（层数）为自变量。
敌军预算 = 4400 基数 + 每层按阶段累加 500/850/1100/1200/1400 的 multiplayer_cost
（`main_units_tables.multiplayer_cost`）；精英层固定 {5,10,15,20,25,30} 预算×1.4 且
锁自动战斗；最少兵牌数 7+1/层、11 层起 ≥18、19 层起满编；敌军主将按 cycle 等级
`cm:add_agent_experience` 提级 + 按种族技能表分配技能点；敌英雄数量随层数 0→3。
预算 ≥25000 时 90% 概率额外生成 1 支援军。

**战后恢复**【事实】：`force_snapshot` 在战前序列化部队兵牌与随军英雄，战后按快照
恢复（败北时 `force_respawn` 整支重建）。这就是"每战满编恢复"的实现方式——不是
补血，是**按快照重建部队**。

**奖励**【事实】：胜利 → 装备困境（rarity 按 cycle 分层解锁 common→crafted）；
选目的地（2 随机节点 + 原地 + 暂停）→ 部队奖励或英雄奖励（英雄层固定）。
兵牌奖励按 multiplayer_cost 价值带（每层 min/max）过滤抽取。

**持久化**【事实】：约 40 个 `cm:set_saved_value` 键；事件 payload 编码为
`key=value|key=value` 字符串存档。目的地候选在生成时即落盘，暂停/读档不重掷。

**入口**【事实】：`button_group_management`（左下 faction_buttons_docker）挂
`round_large_button`，按钮 twui 内部发 `ContextTriggerEvent`（前缀
`adamrogue_phase_a_entry:<faction>`）开事件。精英战锁撤退/自动战斗用
`cm:get_campaign_ui_manager():override(...):lock()`。

**已知问题**（工坊页）：30 层后卡顿；特定领主变身/特定遭遇崩溃。源码量大
（单文件 266KB + 每族 20 万–134 万字节的技能数据表），不可直接移植。

### 1.2 GMrogue — Spire 同源精简版，状态机参考价值高

【事实】与 Spire 同架构（同样是 `GMrogue_mvp.lua` 主编排 + 同套模块名），差异：

- `MAX_CONSECUTIVE_DEFEATS = 1` — **一败即 run 结束**（更接近杀戮尖塔）
- `FINAL_BOSS_CYCLE = 39`，3 个 stage：boss_cycle = {13, 26, 39}，boss_multiplier = {1.8, 1.9, 2.0}
- 每层事件类型由 `BalanceCycle.select_round_event(cycle)` 决定【事实】：
  - cycle == boss_cycle → BOSS_BATTLE
  - cycle == 该 stage 预生成的 shop_cycle（run 开始时在 [min,max] 区间内随机并落盘）→ SHOP
  - cycle < random_start_cycle → NORMAL_BATTLE
  - 否则按 stage 权重 roll：normal_chance% → 战斗 / +special_chance% → 特殊事件 / 余量 → 精英战
- **尖塔币经济**【事实】：独立 pooled resource，战斗胜利按档发币，SHOP 困境消费；
  国库金币与尖塔币分离（事件里可互相转换）
- **事件池 DSL**【事实】（`GMrogue_event_pool.lua`）：事件 = 编号 + 每选项一串可序列化
  step：spire_gain / spire_cost / treasury / grant_units / remove_units / effect /
  equipment(rarity|item_key) / battle(multiplier[, faction]) / hero / chance(roll, %) /
  outcome / skip。数据驱动，主脚本只解释执行。这个设计可直接借鉴。
- 另有策反赏金（defection_bounty）与 campaign effect 收藏品（effect bundle 池）

### 1.3 zzz 模拟器 — 回合即楼层，有独特的调度与品质机制

【事实】架构完全不同：**不开独立状态机，复用战役回合**。2~13 回合每回合即一层，
敌军数量按回合 1→4 队满编。开局 `zzz_only_player` 杀光所有 AI 派系（弃城+杀军）。

可借鉴件【事实】：

- `zzz_turn_scheduler.lua`：**顺序困境调度器**。注册表 `zzz_scheduler_register({key,
  dilemma_keys, trigger, handle_choice, should_trigger})`，每回合按固定序
  `buffs → hero_grant → units → battle` 依次弹各子系统的困境，步骤队列
  `cm:set_saved_value` 落盘，刷新 = 重触发同一子系统不插队。这正好解决
  "一层内有多个奖励子系统要依次弹困境"的排序问题。
- `zzz_unit_acquisition.lua`：每回合兵种二选一 + **刷新**（reroll，每回合 ≤5 次）
  + **存贮**（reserve，额外多选 1 项，≤3 次，消耗累积次数）；单位按
  `main_units.tier` 重算 1~5 阶，`TURN_TIER_PROBS` 回合→各阶概率表；第 7 回合
  保底精英单位；随机种子按 `faction+refresh_count` 重置保联机一致。
- `zzz_test_buffs.lua`：**N/R/S 品质增益**。5 类兵卡位（近战/远程/巨兽/骑兵/魔法）
  × 3 品质池，品质概率按前期{60,36,4}/中期{46,47,7}/后期{35,55,10} 递进；
  buff = `cm:create_new_custom_effect_bundle` + `set_duration(999)` 永久派系效果包，
  用 dilemma payload 的 `effect_bundle_to_faction` 发放。
- `zzz_dilemma_battle.lua`：敌人也是 `create_force_with_general` + 技能分配 +
  `force_attack_of_opportunity`，支持一次生多支（最多 4 队）依次入场；
  `zzz_shadow_rift` 记录玩家坐标用于战后归位/联机传送。

### 1.4 三家共性结论

| 维度 | Spire | GM | zzz |
|---|---|---|---|
| run 载体 | 地图上真实部队 | 地图上真实部队 | 玩家现有最强部队 |
| 战斗触发 | 生敌军+强袭 | 同 | 同（可最多4队） |
| 层数驱动 | 自管 cycle | 自管 cycle+stage | 战役回合 2–13 |
| 败北 | 连败3次结束 | 1败即结束 | 无显式 run 结束 |
| 敌军 | 预算制生成 | 预算制生成 | 预算制生成 |
| 奖励池 | 原版兵种/装备 | 原版+收藏品 | 原版+N/R/S buff |

**三家都没有用 `teleport_and_prepare_for_battle`，全走地图生军+强袭**。原因可考：
要让玩家带"run 专属部队"作战，且战后能恢复/重建这支部队，部队必须在地图上
真实存在；同时敌军由脚本生成才能精确控制预算、技能、入场时序。

而 Lin 集成战略用 `teleport_and_prepare_for_battle` 是因为它把**玩家现有将领**传送
进 CA 原生的脚本化任务战（mission），敌我编成在 mission 表里写死，不需要地图生军。

---

## 2. 自家现状盘点（已有零件）

| 功能 | 现有实现 | 文件 |
|---|---|---|
| 节点二选一菜单 | `integrated_strategies:dilemma_nodes`：node_list 权重表(WISH/ENCOUNTER×4/DREADFUL FOE×4/ROGUE TRADER)随机 2 项，dilemma_builder+payload_builder 构建 | `scratch/integrated_strategies.lua`（Lin pack 内） |
| 战斗节点 | `dreadful_foe` → `cm:teleport_and_prepare_for_battle`，mission 池按 `difficulty_modifier()` 分 EASY/NORMAL/HARD | 同上 L1627 |
| 奖励节点 | `wish`/`rogue_trader` → `summon_servant:select_ancillary(rarity)` 装备池(60/30/10)；`encounter` → 60+ 脚本事件困境 | 同上 + `scratch/summon_servant.lua` |
| 货币 | 票券 lin_all_coupon（+1/回合，进菜单-1）、源石 lin_all_originium_ingot（事件/商店结算） | 同上 |
| 收藏品 | `tongbao` 随机常驻 effect bundle（天圆地方） | 同上 |
| 动态难度 | `difficulty_modifier()`：回合+将领等级/2+特质/2+收入/1000+科技/2 → EASY<40/NORMAL<100/HARD | 同上 L1695 |
| 战法菜单 | `zzzz_psw_doctrine.lua`：dilemma 树路由 summon_servant/无双/集成战略/监狱 | `mod_files/zzz_psw_merged/script/campaign/mod/zzzz_psw_doctrine.lua` |
| Boss 战 | `cm:trigger_mission` 按回合触发 5 个 boss 任务战，胜利监听加 jishu 计数 | `scratch/psw_orig_scripts/psw_boss战斗.lua`（原 pack 内） |
| AI 爬坡 | `jishu_zhongmo` → `psw_tfmw_all_AI_def_atk_up` 全局攻防，cap 45 | `mod_files/zzz_psw_merged/script/campaign/mod/zzzz_psw_ai_difficulty_ramp.lua` |
| 天赋三选一 | `psw_main_pickup` 祈愿抽卡（gmsj 共鸣水晶计费） | `mod_files/zzz_psw_merged/script/campaign/mod/psw_额外函数.lua` L306 |
| 存档模型 | `psw_main_data.global_data/player_data`（原 mod 自带持久化，`[需验证]`序列化机制） | `psw_01_global_vars.lua` |
| 英灵抽卡 | `summon_servant:dilemma_prize_draw`（金币 648/3240/6480 三档） | `scratch/summon_servant.lua` |
| 无双招贤 | `wyccc_wushuang_hero_lottery:open_panel` | doctrine 已接 |
| 监狱 | `wyccc_prison_entry_button` SimulateLClick | doctrine 已接 |

**缺口**：run/楼层状态机、节点序列生成、楼层间失败/通关结算、run 专属部队管理——
即"把这些散件串成一局"的编排层。这正是三个外部 mod 的 `*_mvp.lua` 干的事。

---

## 3. 总体架构决策

### 3.1 战斗方案：地图生军 + 强袭（采 Spire/GM/zzz 路线），不用 teleport

【设计方案】塔内战斗沿用三家的 `cm:create_force_with_general` +
`cm:force_declare_war` + `cm:force_attack_of_opportunity` 方案，而非 Lin 的
`teleport_and_prepare_for_battle`。理由：

1. teleport 方案要求敌我编成写死在 mission 表里（Lin 每个任务一份固定脚本），
   无法按楼层预算动态生成敌军，也无法混入我方 MOD 兵种；
2. teleport 会把玩家现有将领拉进任务战——将领死/伤影响主战役，且打的是原版兵；
3. 生军方案敌军可用预算制装配（含 PSW 兵种池），战后由快照恢复玩家塔部队，
   不污染主战役；
4. Lin 自身 BattleCompleted 监听里"失败取消任务"的处理说明任务战方案在失败
   路径上更麻烦。

【需验证】`teleport_and_prepare_for_battle` 是否支持自定义双方编成（参数 5/6 含义
未确认）——若支持带编成表的任务战，可作为备选，评估后决定。

### 3.2 run 载体：玩家现有将领不入场，新建"塔部队"

【设计方案】run 开始时在玩家母城附近 `create_force_with_general` 生成一支专属
塔部队（领主 subtype 按玩家派系从配置表取），作为整局的战斗载体：

- 塔部队只在塔内战斗，不参与主战役（玩家也可手操它，但设计上不依赖）
- 战前快照（学 `adamrogue_force_snapshot`：序列化兵牌 key+数量+随军英雄），
  战后按快照恢复 → 实现"每战满编复活"
- 层间不需要传送换地形（一期可先固定出生点；二期加锚点池）
- 首次进塔时是否强制议和：`[需验证]`——Spire 做了，因为地图生军的 pending battle
  会卷入同战争状态派系的邻近部队；我们也要做，但改为"与塔敌军生成范围内的
  交战派系议和"还是"全局议和"需实测

### 3.3 楼层驱动：自管 cycle + 手动推进（非回合驱动）

【设计方案】层数 `cycle` 用 `cm:set_saved_value` 自管，**不与战役回合绑定**：
玩家点塔入口 → 弹当前层事件 → 结算 → 弹下一层选择。想停就停（PAUSED 态），
想打就连打。这比 zzz 的回合制灵活，也避免和回合事件拥堵。

【设计方案】层循环（采 GM 的 select_round_event 简化版）：

```
进入塔 → OPENING(首局一次) → [层事件] → DESTINATION(选下一节点)
   ↑________________________________________________|
层事件类型 select_floor_event(cycle):
  cycle == boss_cycle → BOSS_BATTLE
  cycle == 本层预生成 shop_cycle → SHOP
  else 权重 roll → BATTLE / SPECIAL_EVENT / ELITE_BATTLE / REWARD
```

阶段(stage)结构可选：一期单层曲线（Spire 式 ~30 层）；二期按 GM 做 3 stage ×
固定 boss 层。建议一期直接做 2 stage（boss_cycle={15,30}），兼顾节奏与开发量。
`[需验证]`层数上限对存档/性能的影响（Spire 报告 30 层后卡顿，疑似
payload 序列化体积或快照累积）。

### 3.4 编排器：新文件 `zzzz_psw_tower.lua`（独立模块，不动现有文件逻辑）

【设计方案】新增一个 tower 编排器，复用但不改写现有系统：

```
mod_files/zzz_psw_merged/script/campaign/mod/
  zzzz_psw_tower.lua            -- 主编排：状态机、监听器、层循环、困境分发
  zzzz_psw_tower/               -- 子模块目录（package.path 注入）
    tower_state.lua             -- STATE 枚举 + SAVE_KEYS + payload 编解码
    tower_balance.lua           -- 预算/奖励带/品质概率曲线（全部配置在此）
    tower_battle.lua            -- 敌军生成、选址、强袭、快照、恢复
    tower_events.lua            -- 特殊事件池（DSL 数据驱动）
    tower_rewards.lua           -- 兵牌/英雄/装备/天赋/收藏品奖励池
    tower_ui.lua                -- 入口按钮
```

【设计方案】入口接现有 doctrine 菜单：**塔作为 doctrine 联动菜单第 5 项**
（"魔女塔"），点开后打开塔自己的事件流——不新占 HUD 角落（与监狱/无双入口
共存区域紧张），避免 Spire 的右下角冲突问题。HUD 独立按钮二期再议。

---

## 4. 状态机与持久化

### 4.1 状态枚举（采 Spire 结构精简）

```lua
STATE = {
  INIT,                    -- 无 run 或 run 已重置
  OPENING_PENDING,         -- 开局说明困境已备
  FLOOR_EVENT_PENDING,     -- 本层事件(战斗/事件/商店/奖励)已备待开
  BATTLE_PENDING,          -- 战斗困境已备
  DESTINATION_PENDING,     -- 选下一节点困境已备
  PAUSED,                  -- 玩家选了"稍后"（从某态挂起，记 paused_from_state）
  GAME_OVER,               -- 败北达上限
  RUN_COMPLETE,            -- 通关最终 boss
}
```

### 4.2 存档键（前缀 `psw_tower_`，全部 `cm:set_saved_value`）

```lua
psw_tower_run_started          -- run 是否进行中
psw_tower_player_faction_key   -- 归属派系（只服务人类派系）
psw_tower_force_cqi / leader_cqi
psw_tower_state / paused_from
psw_tower_cycle                -- 当前层
psw_tower_event_type/key/seed  -- 当前事件上下文
psw_tower_payload              -- k=v|k=v 编码（学 runtime_state.lua）
psw_tower_completed_battles / victories / defeats / consec_defeats
psw_tower_prebattle_snapshot   -- 战前部队快照（兵牌表+英雄表序列化）
psw_tower_current_node_key     -- 当前"区域主题"（决定敌池与奖励风味）
psw_tower_shop_cycle_s{n}      -- 各 stage 预生成商店层
psw_tower_currency             -- 塔币余额（见 §6.3）
psw_tower_final_boss_done      -- 通关标记
```

【需验证】`psw_main_data` 序列化机制——若其本身就是 saved_value 持久化，
塔状态也可以挂进 `psw_main_data.player_data[faction].tower` 复用原体系；
否则独立 set_saved_value。倾向独立键：塔是可开关子系统，污染原存档模型最小。

### 4.3 存档兼容

- 塔为新子系统，老档无这些键 → 全部默认值初始化，`reset_saved_flow_state_if_needed`
  式规范化（非法 state 落回 INIT）
- 版本迁移预留 `psw_tower_state_version` 键（GM 的 SHOP_CYCLE_CONFIG_VERSION 做法）

---

## 5. 节点与事件类型

### 5.1 层事件类型与权重（一期）

| 类型 | 触发规则 | 内容 |
|---|---|---|
| BATTLE | 默认层，权重 ~55% | 预算制生成敌军→强袭 |
| ELITE_BATTLE | 权重 ~15% 且 cycle≥4 | 预算×1.4，锁自动战斗 `[需验证]` uim override 可用性 |
| SPECIAL_EVENT | 权重 ~20% 且 cycle≥3 | 事件池随机一条（见 5.2） |
| SHOP | 每 stage 在窗口层预生成 1 层 | 塔币消费（见 §6.3） |
| REWARD | 权重 ~10% | 直接奖励困境（兵牌/装备/天赋三选一） |
| BOSS_BATTLE | cycle ∈ boss_cycle 集合 | PSW boss 任务战或预算×1.8 生成战（见 §8） |

层序列**生成时即落盘**（学 Spire：候选不事后重掷，防 SL 刷）。

### 5.2 特殊事件 DSL（学 GMrogue_event_pool）

【设计方案】事件 = 编号 + 每选项 step 序列，解释器统一执行。step 类型一期支持：

```lua
tower_currency(±n)        -- 塔币增减
treasury(±n)              -- 国库
units(unit_key, count)    -- 授兵到塔部队
remove_units(count)       -- 移除兵牌
equipment(rarity|key)     -- 装备（先走 summon_servant 池，二期扩 PSW 池）
effect(bundle_key)        -- 派系效果包（收藏品）
talent(tag)               -- PSW 天赋定向抽（[需验证]能否按标签定向调用抽卡）
battle(mult)              -- 事件内战（预算×mult）
servant_draw()            -- 转 summon_servant:dilemma_prize_draw 原生入口
wushuang()                -- 转无双面板
prison()                  -- 转监狱入口
lin_node()                -- 转集成战略节点菜单（按原生票券计费）
chance(roll, %, ok, fail) -- 概率分支
skip()
```

跨 mod 选项（servant/wushuang/prison/lin）复用 doctrine 的缺席检测模式
（`type(xxx) == "table" and type(xxx.fn) == "function"`），缺席时该选项
生成前剔除或显示无效文案——**不新增第四个入口，只做事件内路由**。

### 5.3 目的地/区域主题（可选二期）

Spire 的 NODE_POOL 是"文化目的地"（影响敌池+奖励风味）。一期可简化为：
每层 DESTINATION 困境给 2~3 个**下一层事件类型候选**（比如"稳妥的商店"或
"危险的精英战"），而不是文化节点——更贴近爬塔选路且实现量小。
二期再考虑文化/种族主题节点（敌池风味化）。

---

## 6. 奖励与经济

### 6.1 兵牌奖励

【设计方案】战斗胜利后兵牌困境：从"该层价值带"内抽 2~3 个候选兵牌三选一，
`cm:grant_unit_to_character` 入塔部队。价值源 `main_units_tables.multiplayer_cost`。
池构成分层：

- 1 期：玩家派系所属文化池 + 通用池（先复用 PSW/原版混编表，`[需验证]`PSW
  自定义兵种是否可被 grant_unit_to_character 授予——它们多数走任务/特殊招募）
- 双倍线(double_line)机制可留二期（Spire：价值超过线时一选给俩）

### 6.2 装备/收藏品奖励

- 装备：`summon_servant:select_ancillary(rarity)` 直接复用（已证实
  common/uncommon/rare 三档可用），品质按 cycle 解锁带（照抄 Spire 的
  equipment_rarity_by_cycle 思路）
- 收藏品：复用 doctrine 的定向 effect bundle 概念——做"塔收藏品"池
  （unit_set 定向被动，N/R/S 三品质），永久或本 run 内有效
  `[需验证]` effect bundle 是否有 run 级时限表达（set_duration 有限=回合数；
  "本 run 有效"需要 run 结束时手动 remove_effect_bundle 清单）
- 英雄奖励：无双面板路由（原生入口）或直接生成（`[需验证]`生成函数签名）

### 6.3 塔币

【设计方案】新增独立 pooled resource `psw_tower_coin`（不并入 gmsj/qysj/票券/源石）：

- 战斗胜利 +N（基础值×难度档），事件选项 ±，商店消费 -
- 理由：doctrine 已确立"路由式联动、各 mod 货币各管各"的原则，塔币是塔自己的
  经济，不侵蚀共鸣水晶/祈愿水晶主经济；同时避免源石/票券双货币挤占
- 商店（SHOP 层）：卖兵牌/装备/收藏品/移除兵牌位/刷新城池——价格按品质档
- `[需验证]`新 pooled resource 需要 db/pooled_resources_tables + 资源栏 UI 组件
  （或学 zzz 直接不进资源栏，只在困境文案里显示余额——一期推荐后者，零 db）

### 6.4 与主经济的关系

- 塔部队维护费：0（脚本部队，不挂招募/维护逻辑）
- 塔奖励不直接给国库金币（防塔刷钱破坏主经济）；事件内允许少量 treasury ±
  （±3000 量级，参考 GM 事件数值）
- 共鸣水晶/祈愿水晶：塔内不产出、不消耗（保持 doctrine 收敛设计不变）

---

## 7. AI 难度

### 7.1 敌军生成（核心：预算制）

【设计方案】复用 Spire/GM 的预算制思路但表数据重写（它们的 data_battle_pools
是原版池，我们换混编池）：

```
enemy_budget(cycle) = base 4400 + Σ growth_per_cycle(cycle)   -- multiplayer_cost
elite: ×1.4   boss: ×1.8~2.0   mct_multiplier: 0.5~3.0
最少兵牌 = 7 + cycle（上限 20）；cycle≥11 → ≥18；≥19 → 满编
敌将等级 = cycle（cm:add_agent_experience + 技能分配表）
敌英雄数 = growth 表 hero_num（0→3）
```

兵牌装配算法（三阶段，照 Spire 概念）：从候选池按权重随机抽，价值累加到
85% 预算后允许提前停（phase A），精锐编队吃满 100%（phase B/C）。
**敌军兵池一期只用原版+PSW 兵牌 key 表**（手工维护 JSON/Lua 表），
不接 data_battle_pools（它含全种族 300KB 数据，体积大且全是原版）。

### 7.2 与现有 AI 爬坡的关系

- 塔内敌军的强度 = 预算制（数量质量），**不叠加 `jishu_zhongmo` 全局 ramp**
  ——ramp 是给主战役 AI 的，塔自成体系；否则双重爬坡失控
- 但塔战绩可回写：`psw_add_jishu_meili` / `jishu_ybbb_zhongzu` 在 boss 层
  胜利时按现有 boss 结算逻辑走（若复用 psw boss mission，结算监听天然生效）
- `[需验证]` tower 战斗是否会被现有 AI ramp 的监听器误伤（ramp 监听
  FactionTurnStart/招募事件，不监听 battle，预计安全）

### 7.3 技能分配

敌方将领技能表：一期简化为"按等级随机分配通用技能线"
（`cm:add_agent_experience` + 随机点），不做 Spire 的每族定制技能树
（那是 200KB+/族的工作量）。二期再按敌将 subtype 做 3~5 套模板。

---

## 8. Boss 层

【设计方案】boss_cycle = {15, 30}（一期两层楼boss）：

- **优先方案 A**：预算×1.8~2.0 生成战 + 精英锁自动战斗 + 战利品翻档。
  与普通战斗同一条代码路径，稳。
- **方案 B**（二期）：`cm:trigger_mission` 复用 `psw_ie_unique_battle_quest_*`
  系列任务战——但原 mission 绑定固定回合窗口与 effect_bundle 前提
  （`*_mission_start`），作为塔层触发需要绕过其回合/标记条件
  `[需验证]`直接 trigger_mission 是否可脱离原 turn/bundle 门控，以及
  任务完成后计数器是否照常累加（`psw_add_jishu_ybbb_zhongzu` 等监听
  是按 mission key 匹配的，若可复用则白拿结算）

一期按 A 落地，B 留验证点。

---

## 9. UI 与入口

【设计方案】一期零新 UI 组件：

- 入口：doctrine 联动菜单新增第 5 选项"魔女塔"（`DOCT_LINK_FUNCS` 加一项），
  内部调 `psw_tower:open(faction)` → 塔自己的第一个困境
- 全部交互走 dilemma（dilemma_builder + payload_builder），与 Lin/Spire 同构，
  不写 twui
- 层数显示：困境标题/正文文案内嵌"第 N 层"（dummy loc key 拼接）
- 塔币余额：学 zzz 在困境正文 `text_display` 内显示（`[需验证]`loc 文本
  能否运行时拼接数值——Lin 已有 `dummy_xxx` 系列，做法待抄；若不可拼，
  用通用文案+"当前余额见下一选项"的笨办法，或直接写死文案档位）

【设计方案】二期可选：独立 HUD 按钮（挂 button_group_management 学 Spire，
`ContextTriggerEvent` 前缀 `psw_tower_entry:`）；选路图（自定义 twui，工作量大，
仅当用户明确要"杀戮尖塔式地图"时再做）。

---

## 10. 兼容与失败处理

1. **跨存档**：set_saved_value 全键默认值化；旧档无键 → INIT 干净态
2. **跨 mod**：summon_servant/无双/监狱/Lin 缺席时事件池剔除对应选项；
   塔本体不依赖它们也能跑（核心战斗/兵牌/塔币自含）
3. **战斗失败**：consec_defeats+1；达上限(一期 2 次，可 MCT)→ GAME_OVER 困境，
   run 关闭、塔部队解散或保留为普通军 `[需验证]`玩家期望
4. **战斗中存档读档**：`[需验证]` pending battle 期间存档的行为——Spire 靠
   BattleCompleted 监听恢复；我们也要确保 BattleCompleted 里判断"是不是
   塔部队参战"（force_cqi 匹配），非塔战斗直接 return
5. **玩家手动操作塔部队**：允许，但敌军生成点按"塔部队当前位置"选址
   （EnemySpawn 逻辑以玩家将领坐标为圆心搜空地），部队死了=run 失败
6. **错误兜底**：所有 cm 接口调用 pcall 包装 + `out("[psw_tower] ...")` 日志
   （MCT 开关），事件 prepare 失败落回 INIT 不卡死（Spire 每个 prepare
   都有 fallback-to-INIT 分支）
7. **崩溃敏感点**：`create_force_with_general` 回调、CharacterCreated 监听、
   force_attack_of_opportunity 失败重试（≤5 次、换选址）——三家都踩过，
   照抄回退链：主选址 → 备选派系 → 同派系直生 → 放弃本层改发奖励层
8. **Mixu/冲突派系**：塔内不生成 `!psw_crash_guard.lua` 已判死的派系为敌
   （东江诸侯、纳卡伊）

---

## 11. 实施阶段

| 阶段 | 内容 | 验收 |
|---|---|---|
| P0 骨架 | tower_state/balance/battle 三模块 + INIT→层事件→DESTINATION 最小循环；BATTLE=预算制生军+强袭+快照恢复；只发兵牌奖励 | 手开 5 层能连贯打下来、读档续 run、败北 GAME_OVER |
| P1 奖励完备 | 装备(select_ancillary)/收藏品(bundle)/兵牌三选一；塔币+SHOP 层；SPECIAL_EVENT 池 10 条 | 事件池可玩；商店可买；收藏品生效 |
| P2 联动 | 事件 DSL 接 servant/wushuang/prison/lin 路由；缺席检测 | 装了/没装各 mod 两种情况无死菜单 |
| P3 难度 | 精英层、boss_cycle、敌英雄、敌将技能、MCT 滑条(敌预算×/奖励×/连败上限/日志) | 30 层打通数值不失控 |
| P4 打磨 | 锚点换地形、英雄奖励层、目的地选路、独立 HUD 按钮、EN loc | — |

---

## 12. 测试计划

- 单测：`python -m unittest discover -s tools/tests -v`（工具链回归）
- 打包包路径：`C:\...\Python313\python.exe tools/build_pack.py zzz_psw_merged --deploy`
- 冲突：部署后 playset 变更前跑深度冲突扫描（wh3diag compat）
- 实测用例：
  1. 新档开塔 → OPENING → 第 1 层战斗可打、胜后部队满编恢复
  2. 连败 2 场 → GAME_OVER、run 清理
  3. 打 5 层后存档、退出、读档 → 层数/部队/待开事件原样恢复
  4. 战斗中强杀游戏进程（模拟崩溃）→ 读档后状态可恢复或安全落 INIT
  5. 卸载 Lin/servant/无双/监狱各组合 → 事件池无死选项
  6. 塔部队被玩家在地图上手动宣战/被 AI 袭击 → 不卡状态机
  7. 30 层全通 → RUN_COMPLETE、终局结算正确
- `[需验证]` MCT 注册名/选项键不与 psw 现有模块冲突

---

## 13. 开放问题

1. `teleport_and_prepare_for_battle` 能否自定义双方编成？能的话普通层可用它，
   省掉快照/重建整套逻辑 `[需验证]`
2. `psw_main_data` 持久化机制与塔状态挂载点 `[需验证]`
3. PSW 自定义兵种 key 能否被 `grant_unit_to_character`/`create_force_with_general`
   的 unit_list 接受 `[需验证]`
4. `cm:trigger_mission` 脱离原回合/标记门控复用 boss 任务战 `[需验证]`
5. effect bundle 的 "run 内有效" 表达（无限期+手动清 vs set_duration）`[需验证]`
6. 新 pooled resource 是否必须建 db 表+资源栏，还是纯困境文案可替代 `[需验证]`
7. 塔部队被 AI 派系攻击/消灭的事件监听兜底 `[需验证]`（Spire 靠议和+强袭规避，
   我们议和范围待定）
8. loc 文本运行时拼接数值的可行做法 `[需验证]`

---

## 14. 参考文件索引

- Spire 主编排：`scratch/_spire_src/adamrogue_mvp.lua`
- Spire 状态/存档：`scratch/_spire_src/adamrogue_runtime_state.lua`
- Spire 数值曲线：`scratch/_spire_src/adamrogue_balance_config.lua`
- Spire 快照/恢复：`scratch/_spire_src/adamrogue_force_snapshot.lua`
- Spire 选址/锚点：`scratch/_spire_src/adamrogue_travel_anchor_manager.lua`
- GM stage/事件轮盘：`scratch/_gm_src/GMrogue_mvp.lua`（`BalanceCycle.select_round_event`）
- GM 数值：`scratch/_gm_src/GMrogue_balance_config.lua`
- GM 事件 DSL：`scratch/_gm_src/GMrogue_event_pool.lua`
- zzz 回合调度器：`scratch/_zzz_src/zzz_turn_scheduler.lua`
- zzz 品质/刷新/存贮：`scratch/_zzz_src/zzz_unit_acquisition.lua`、`zzz_test_buffs.lua`
- zzz 生军+强袭+技能：`scratch/_zzz_src/zzz_dilemma_battle.lua`
- Lin 节点引擎：`scratch/integrated_strategies.lua`
- 英灵装备池：`scratch/summon_servant.lua`
- 现有 doctrine：`mod_files/zzz_psw_merged/script/campaign/mod/zzzz_psw_doctrine.lua`
- AI 爬坡：`mod_files/zzz_psw_merged/script/campaign/mod/zzzz_psw_ai_difficulty_ramp.lua`
- PSW boss 原版：`scratch/psw_orig_scripts/psw_boss战斗.lua`


---

## 15. P0 已落地（实施记录）

### 新增文件

- script/campaign/mod/zzzz_psw_tower.lua（约880行）：完整状态机
  idle -> opening -> node -> battle_pending -> battle -> reward -> (node)
  外加 shop/event 旁路与 victory/defeat 终局。psw_tower.enter(faction)
  由 doctrine 联动菜单调用；同一入口按 saved state 重发当前待决困境，
  兼顾存档恢复。
- script/campaign/mod/zzzz_psw_tower_pools.lua（gamedata 自动生成）：
  psw_tower_pools.UNIT_POOLS 按子文化聚合原版单位（MP 造价 300-2000、
  过滤 lord/hero/campaign_exclusive）；ENEMY_THEMES 12 主题含 qb 宿主
  派系 + 普通/Exalted 将领 subtype；PLAYER_GENERALS 子文化 -> 通用将领。
- db/pooled_resources_tables/zzz_psw_tower.tsv：psw_tower_stardust
  （星尘，max 99999，icon_spirit_essence.png）。
- db/pooled_resource_factor_junctions_tables/zzz_psw_tower.tsv：
  psw_tower_stardust_other / _events 双 factor（±全幅）。
- db/dilemmas_tables/zzz_psw_tower.tsv：8 个塔困境 + psw_dilemma_doct_link2。
- db/cdir_events_dilemma_option_junctions_tables/zzz_psw_tower.tsv
  （junction id 使用 888900xxx 段）。
- db/cdir_events_dilemma_choice_details_tables/zzz_psw_tower.tsv。
- db/campaign_payload_ui_details_tables/zzz_psw_tower.tsv：31 个 payload
  文本组件（图标全部取原版 effect_bundles 目录）。
- text/psw_tower.loc.tsv：全部中文文案。

### doctrine 变更

- 联动页 DOCT_LINK 改为：FIRST 星塔试炼（本 mod 自带、免费）/
  SECOND 英灵 / THIRD 无双 / FOURTH 集成战略 / FIFTH 更多联动 ->
  psw_dilemma_doct_link2（FIRST 狱政 + FIFTH 返回）。
  狱政降至二级页，但其独立 HUD 按钮不变，代价最小。
  psw_doct_any_link_available 现因塔入口恒真。

### 平衡参数（P0 初值）

- 30 层；敌军预算 2400 + floor*320；精英 {5,15,25} x1.4；
  层主 {10:1.8, 20:1.9, 30:2.0}；伏击事件 x1.3。
- 阶段主题：1-10 {kho,grn,nor,bst}；11-20 {nur,skv,vmp,chs}；
  21-30 {tze,sla,dae,ogr}；层主固定 kho/nur/dae Exalted 将领。
- 每层择路：迎战（星尘 20+4*floor + 招募三选一）/ 秘境（随机事件）/
  商铺（3/8/13/18/23/28 层，350/700/1300 三档）/ 休整（+8 星尘跳层）/ 撤退。
- 玩家起始军：派系通用将领 + 前排3/远程2/骑兵1（单件 <=700 造价）。
- 招募奖励造价带：1-8 层 300-900；9-16 层 500-1300；
  17-24 层 700-1700；25+ 层 900-2000。
- 胜场将领 +1 阶；败北即试炼终结（GM 式一命制，星尘保留）。
- 通关：国库 +12000、星尘 +200，祈愿军解散。

### 待验证 [需验证]

- qb 派系在玩家当前战役中是否存在可生军（各战役图 qb 键各异）；
  当前兜底 wh_main_chs_chaos_qb1。
- cm:faction_add_pooled_resource 对新派系资源的初始化（已按原版
  cst_infamy 模式建表；顶栏 icon 显示待实测）。
- payload_builder:add_unit 在 add_target force 缺失时的行为。
- 将领本体 HP 战后恢复：战役 API 无直接接口（Spire 同限）。当前靠
  补员 + replenish_action_points，领主战损会跨层留存——后续可加
  层间自愈或休整层治疗。
- in_battle 状态存档读档的恢复路径（当前实现：清理敌军 ->
  battle_pending 允许重打）。
- PSW 自定义派系 subculture 是否落入 25 个池；否则回退帝国池（已实装）。

### 验证状态

- [x] Lua 语法（luaparser ast.parse）三个文件通过
- [x] pack 构建 54 文件通过；新增 DB 表全部可解码
- [ ] 游戏内实测（走 mod manager 播放集 + 冲突报告后启动）

---

## 16. rlt_spire 设计吸收（P1 增量实施记录）

评审 `DESIGN_v0.md`（rlt_spire 垂直切片）后，吸收其中优于现状的三个机制；
未吸收项及理由见 §16.4。

### 16.1 星辉竞逐者（rival 竞速）

来源：rlt_spire `rlt_rival`（AI 对手同步爬塔）。实现：

- 存档键：`psw_twr_rival`（对手当前层）/ `psw_twr_rivmark`（已播报里程碑）
  / `psw_twr_rivwon`（抢先登顶标记）。`spawn_tower_army` 随新 run 复位。
- 推进：`FactionTurnStart` 监听器（文件顶层注册，非 first_tick 内）——
  仅当 `run` 进行中且回合派系 = `psw_twr_pfaction` 时掷：
  `rnd(100)` ≤55 +1 层、≤80 +2 层、其余 0 层（期望 ≈0.95 层/回合）。
- 里程碑 10/20/29 层与"抢先登顶"各发一次 `cm:show_message_event`
  （非持久），loc 走 `event_feed_strings_text_psw_twr_rival_*`。
- 后果：`psw_twr_rivwon=true` → 终层 Boss 战加援军（§16.2）+
  通关收益减半（`VICTORY_TREASURY/STARDUST/GMSJ` 全 ÷2，含 end_run
  内清算水晶）。
- 与 rlt_spire 差异：对手层数只记数值不模拟编成（够用）；rlt_spire
  用 WorldStartRound，本实现用玩家派系 FactionTurnStart——run 暂停
  不推进语义等价，且不依赖回合事件顺序。

### 16.2 Boss 双军（终层援军）

来源：rlt_spire "对手先到顶 → Boss 战加码" + Spire "预算≥25000 时
额外援军"的复合思路。实现：

- 仅当 `kind=="boss"` 且 `psw_twr_rivwon` 时触发——常态 Boss 难度不变，
  援军是竞逐失败的惩罚而非固定机制。
- `gen_reinforce_csv(theme_key, floor)`：同主题池、预算 =
  `enemy_budget(floor,"boss") × 0.45`、≤12 队、单件 ≤1500。
- `spawn_boss_reinforce`：在主敌将旁 r∈{2,4,6} 选址生第二支军
  （`create_force_with_general` 回调存 `psw_twr_eleader2`）。
  主军攻击延迟 0.4s（`cm:callback`）待援军实体化进增援圈——
  `force_attack_of_opportunity` 的第4参是 force_regular_battle，
  援军判定靠引擎的距离圈，不由参数控制【实测口径：CA 商队脚本
  wh2_forced_battle_manager 同用法】。
- `cleanup_enemy` 扩为遍历 `{SK.el, SK.el2}` 双将领清理。

### 16.3 高塔再启（裂隙周期开合的等价物）

来源：rlt_spire `IDLE→RIFT_OPEN→IN_RUN→COOLDOWN` 显式生命周期。
本系统入塔走 doctrine 随时可点（优于 rift 定时开合），故"周期感"
退化为**冷却结束通知**：`reopen_notice` 在同一 FactionTurnStart
监听器内检查 `turn_number - lastend ≥ RUN_CD` 且本冷却期未播报
（`psw_twr_cdann`，end_run 复位）→ 发一次 `psw_twr_reopen_*`
事件推送。任意人类派系回合都会检查（`is_human()` 过滤）。

### 16.4 评审否决项（不吸收）

| rlt_spire 做法 | 否决理由 |
|---|---|
| 8 层固定线性 | 现有 30 层 + 三签掷路 + Boss/精英/商店层更强 |
| 顺序报价绕静态选项名 | 现有 `fire()` 的 `payload:text_display` 已可逐选项动态注入 |
| `zero_action_points` 定桩等玩家来打 | 现有 `force_attack_of_opportunity` 敌军主动进攻更彻底 |
| 单货币 essence | 现有星尘+共鸣水晶双向流通 + 清算折算 |
| 遗物=动态效果包 | 现有祝福/诅咒体系已超其表达力 |
| 每 run 独立阵营基地 | 塔军队本就是临时生成军，等价已实现 |

### 16.5 新增/变更接口使用记录【已验证存在】

- `cm:show_message_event(faction_key, title_loc, primary_loc, secondary_loc,
  is_persistent, index_num, ...)`——lib_campaign_manager 16718 行；
  index 取 225 = `event_feed_events` 表中 `scripted_transient_event`
  行（图标类型，偏差仅装饰级；CA 脚本亦有超界值先例）。
- `cm:find_valid_spawn_location_for_character_from_character`——沿用既有。
- `FactionTurnStart` + `context:faction():is_human()` 顶层监听——沿用
  本文件已验证的"勿包 first_tick"注册方式。

### 16.6 遗留 [需验证]

- index_num=225 的 feed 图标在游戏中是否为期望样式（仅装饰）。
- 援军 r∈{2,4,6} 落位是否稳定进入增援圈（若 r=2 无空地回退到
  r=6，可能出圈；届时扩大半径或改按玩家部队选址）。
- `show_message_event` 在 WH3 的 secondary loc 空值行为（本实现给了
  真实 key，未踩空值路径）。
- 竞逐者推进期望 0.95 层/回合 vs 玩家实际爬塔速度的体感平衡，
  待实测后调 `rnd(100)` 阈值。

---

## 17. 敌军编成重设计（派系信条制）

原 `gen_enemy_list` 按造价窗 `[250, hi]` 在整池随机抽，仅巨兽/炮兵计数
限编——产出的军队"只有造价曲线、没有派系脸"：恐虐能抽出全巨兽、
鼠人可能零步炮、30 层照样塞满 250 炮灰。重构为三层机制：

### 17.1 派系编成信条 `THEME_DOCTRINE[theme_key]`

每主题一张权重表 `{frontline, missile, cavalry, monster}`（预算占比%，
加权抽取）+ `cap_monster` 巨兽硬上限。权重按池内真实兵种结构校准
（`scratch/` 统计 25 池逐池盘点）：

- 零远程族：`kho/vmp/sla/nor` missile=0（池内本就 0~2 个远程件）
- 巨兽主导：`ogr` monster 65/cap 9、`lzd` 50/`tmb/nag` 35~40
- 混编均衡：`chs/hef/emp/cth/ksl` 四象限分布
- 极端结构：`dwf` 纯步炮（池内 0 骑 0 兽，cavalry=monster=0）、
  `brt` cavalry 55（骑士国）、`skv` 步+炮 75（鼠潮火力）、
  `cst` 火枪+海怪、无骑兵
- `AMBUSH_DOCTRINE`：伏击战整体向骑兵/巨兽倾斜（快速部队贴脸）

### 17.2 两阶段造价窗 + 品质曲线

- 核心期（前 60% 预算）：`[core_lo, hi]`，elite/boss 的 `core_lo =
  hi×0.55`——先搭高价骨架；normal/ambush 全程 [250, hi]
- 填充期（后 40%）：放开到 250 补炮灰，保留"精英+杂兵"的军队感
- Boss 旗舰：最贵可用巨兽预置第一席（恐虐嗜血狂魔/大不净者式招牌）
- RoR 限编：`normal 1 / elite 2 / boss 3`（_ror 名将团防全队模板化）
- 保底契约不变：前排 ≥4、总数 <4 判 nil（上层 auto-advance）

### 17.3 敌方主题扩展 12→25（`EXTRA_THEMES` 运行时并入）

qb1 宿主派系经查证**全派系存在**（factions 表 25 个 `*_qb1`），
将秩序/中立族纳入塔之守卫（设定：星辉凝成的各族回响）：

- I 阶凡俗（1-10 层）：`grn/nor/bst/emp/tmb/brt`
- II 中坚（11-20）：`nur/skv/vmp/chs/def/cth/cst/ksl`
- III 超凡（21-30）：`tze/sla/dae/ogr/kho/lzd/hef/chd/wef/dwf/nag`
- Boss 层不变：`kho/nur/dae` 恶魔原体（exalted 招牌将领）

将领 subtype 与 `PLAYER_GENERALS` 同源已验证。`enemy_themes()`
懒合并（tower.lua 加载早于 pools 文件——文件名序 'tower.lua' <
'tower_pools.lua'，顶层引用为 nil，必须首次使用时合并）。

### 17.4 仿真验证（scratch/sim_army.py，等概率抽样）

| 场景 | 结果 |
|---|---|
| f6 normal emp | 7 队 4300/4320，骑兵 4——帝国骑士团 |
| f6 normal nor | 6 队 4500，巨兽 3——诺斯卡兽群 |
| f15 elite cth | 11 队 9950，远程 5——震旦火力网 |
| f15 elite cst | 13 队 10275，海怪5+火枪4 |
| f30 boss dae | 19 队 23125，旗舰巨兽+RoR=3 上限生效 |
| f30 boss kho | 19 队全近战系，零远程 ✓ |

### 17.5 遗留 [需验证]

- 低层预算下小队数量 6~9 支对玩家的压迫感（沿用原预算曲线未动）
- skv 远程权重 35% 但高价窗常排除 jezzails 级件（造价窗与权重
  的相互作用可能稀释远程占比，实测观察后可微调 core_lo）
- 新主题 qb1 派系在游戏内 `create_force_with_general` 全数可生军
  （表内存在≠运行时可用，首个新主题实测以 `tlog` 输出为准）
- 伏敌 doctrine 触发路径：event "ambush" 事件 → kind="ambush"
### 17.6 签名编队层（zzzz_psw_tower_comps.lua，merged35_comps）

吸收 Downloads/ENEMY_COMPS.md（rlt_spire 敌军调研姊妹篇）：
精英/Boss/伏击战时整队替换信条构建——**每场硬仗 = 该派系社区公认
doomstack**（诺斯卡猛犸群 LotW#2 / 蜥蜴人甲龙堆 LotW#3 / 蒸坦团 /
混矮列车炮 / 鼠人武器队 / 矮人炮阵 / 四神魔军 / Chosen 王座军 /
DLC29 纳迦什不死军团等 25 主题全覆盖）。

- 文档 §0 核心洞察已吸收：玩家 doomstack≠好敌阵——选敌阵按
  "AI 驾驶下仍难打"过滤（单体巨兽堆/精锐混编/铁砧重炮优先，
  回避纯远程阵与依赖微操的法爷阵）。
- 全部 247 个 unit key 对 gamedata main_units（unit+land_unit 双列，
  2851 键）逐一验证；文档的 8 个旧名已更正（kharibdyss/moon_bird/
  jade_lion/jet_lion/thundertusk/tuskgor/blood_knights/cairn_wraith）。
- 签名表按"招牌优先"排序，army_cap 截断砍尾部填充位；不走预算窗
  （强度由编排保证），budget 仍照公式计算供日志/结算。
- MCT sig_comp 勾选可关；关闭或无签名主题回退信条构建（25 主题
  现全有签名，回退路径仅作保险）。
- 兵牌勋级：enemy_chevron 按层给敌军授勋（F≤10=2 / ≤20=5 / >20=8，
  精英+1，Boss=9）——cm:add_experience_to_units_commanded_by_character
  已在 vanilla chaos_invasion 实证。配合敌将等级 10+floor，
  敌军现在将领/兵牌双成长。
- 文档 §7.1 签名效果包（派系加成等效 bundle）与 §7.3 asc/mutator
  未做：前者要新 DB 行、后者与现有诅咒/竞逐者功能重叠——
  列为远期候选。

---

## 18. 生态联动层（P1 实施记录）

动机：塔的产出原本只有国库+共鸣水晶，通关除资源外零战局影响、无独占奖励。
本节把塔接入既有 mod 生态，全部**软依赖**——mod 缺席自动回退星尘/水晶，
不因缺失报错或扣分。

### 18.1 联动通道（探测 → 发放 → 播报）

| 系统 | 探测方式 | 发放方式 |
|---|---|---|
| Lin 集成战略·通宝/源石锭 | faction:pooled_resource(key) 读数 -1 判缺席；发后回读验证 | faction_add_pooled_resource(..,"events") |
| Lin 英灵召唤·从者 | type(summon_servant)=="table" + 函数存在 | summon_servant:select_character → add_character（官方生成链：命名/art_set/补行动力全套） |
| Lin 装备池 | 同上 | summon_servant:add_ancillary（官方 60/30/10 稀有度掷签） |
| 无双英雄（wyccc_shojo） | wyccc_wushuang_hero_lottery_config.entries + lottery.state.claimed 过滤已得 | cm:create_agent 都城旁入世 → wyccc_wushuang_character_setup:prepare（art/命名/不朽/按回合定级）→ 写回 state.claimed + save |
| 塔圣物 | 无依赖（本包自制 ancillary） | cm:add_ancillary_to_faction（unique_to_faction 防重复发放） |

播报统一走 tower_msg（index 225 feed 事件），loc 键 psw_twr_link_*。

### 18.2 里程碑馈赠（grant_milestone，挂 on_victory）

| 层 | 联动 | 缺席回退 |
|---|---|---|
| 10（Boss） | 源石锭 +10 | 星尘 +150 |
| 15（精英） | 塔圣物 → Lin 装备 | 星尘 +100 |
| 20（Boss） | 英灵从者入世 | 水晶 +3 |
| 25（精英） | 通宝 +2 | 星尘 +200 |
| 30（登顶） | 无双英雄 > 从者 > 塔圣物（grant_final_link） | 无（必有圣物兜底） |

### 18.3 联动事件（EVENTS 池 +4）

- star_gate 星门献祭：50 星尘掷签（通宝35/源石25/装备25/星尘15），
  或 1 水晶掷高档签（40/35/20/5 且数量+1）。
- captive 战俘处置：押送 +1 水晶 / 献祭 +80 星尘 / 搜刮 +30。
- relic 星轨遗藏：2 水晶 → 塔圣物或 Lin 装备（双缺席 +120 星尘）。
- omen 天象异动：占卜免费报竞逐者进度段；扰乱 -100 星尘令
  竞逐者 -3 层（psw_twr_rivwon 已登顶无法撼动）——竞逐者机制
  的玩家交互抓手。

### 18.4 塔圣物（自制 ancillary ×5）

db/ancillaries_tables + db/ancillary_info_tables（注册）+
db/ancillary_to_effects_tables；unique_to_faction 防重复获取。
武器星辉之刃（+6攻/+10%威力）、星路战甲（+12甲/+5特保）、
星尘护符（+8特保/+4士气）、星穹图卷（+2魔风储备/+10魔抗）、
竞逐者印记（+15%战利品/+5%补员）。

### 18.5 已知边界 [需验证]

- summon_servant:add_character 内部对 self.character 判空走
  领袖旁落位——塔领袖是临时军，落点会跟塔军；从者生成在塔军旁，
  run 结束塔军解散后从者**留在地图上**（派系常驻角色，正确）。
- wyccc_wushuang_hero_lottery.state.claimed 直写+save()：
  其 refresh_claims 也会按世界角色复查兜底，双保险。
- 无双 create_agent 后 find_faction_subtype 即时查找——
  官方 summon 链同模式同步生成，若异步落位 prepare 会找不到；
  失败仅影响美术/命名，角色本体仍在（CharacterCreated 监听器
  会触发其 finish，无 pending 时早退不污染状态）。
- 监狱系统 queue_prison_incident 是 local 未导出，**不联动**；
  战俘事件走纯资源（押送换水晶）。

## §19 试炼流派（school）——重复爬塔的意义（merged33_schools 实装，merged34_lord 扩展）

回答「重复爬塔的意义是什么？有区分不同的塔吗？」：同一座塔分**道**，入塔后强制择道，
整局约束编队/招募池/文化祝福。数据复用现有 `caste`/`role`/`cul` 元数据，无新增复杂系统。

### 六道（两页择道：首页四道+FIFTH 翻异道页）
| 道 | 编队约束 | 初始配额 | 专属祝福组 | 说明 |
|---|---|---|---|---|
| 星塔正途 | 无 | 3前排+2远程+1骑 | 派系文化 | 全能基准 |
| 凡武·砺刃 | 近战步兵/骑兵/战车/怪兽步兵 | 4前排+2骑 | melee（血潮汹涌） | 近身血战 |
| 远击·星矢 | 远程步兵/骑兵/炮械 | 1前排+4远程+1骑 | shoot（星弓亲和） | 箭雨覆盖，阵型脆 |
| 秘法·灵穹 | 编队不限 | 2前+2远+1骑+1巨兽 | arcane（魔焰共鸣） | 混编精锐 |
| 百兽·莽原 | 巨兽/怪兽步兵/怪兽骑兵 | 3巨兽+2怪兽骑 | wall（磐石星环） | 单体强横数量稀，初始造价窗放宽1200 |
| 英杰·御灵 | 无凡兵——单将领主启程 | 空（孤胆） | arcane（魔焰共鸣） | 起15级+【御灵孤胆】效果包（近攻/近防/士气/速度+10、特保+8），招募=灵契召唤（巨兽/怪兽骑兵，阵亡不补），每胜+2级，星尘×1.3，hard mode |

### 机制
- 流程：开门困境「开始试炼」→ `psw_dilemma_tower_school` 首页四道+「万灵诸道」翻页
  → `psw_dilemma_tower_school2`（百兽/英杰/重择）→ 生成塔军
- `SK.school` 存档键；state=="school" 支持存档恢复重发（恢复显示首页）；clear_run 时重置
- `run_pool(faction)`：caste+role 双键过滤玩家招募池；滤完不足5种回退全池保底
  （nofb 道不回退——英杰道返回空池）；`summon_pool`=巨兽/怪兽骑兵召唤池；
  `recruit_pool` 统一供战利品/商铺/事件招募（英杰走召唤池，其余走流派池）
- 英杰道 spawn 附加：将领等级 `max(当前,15)` + `psw_twr_sch_lord` 效果包挂塔军
- `boon_culture_group`：流派 cul 覆盖派系文化映射——凡武必出破军系祝福等
- `gain_stardust` 乘 `sd_mult`（英杰 ×1.3 孤胆加成）；on_victory 将领经验英杰 +2/胜
- **动态军队上限** `army_cap()`（MCT `army_cap` 滑杆 20-40，默认 30 对应当前改上限 mod）：
  起步编成 ≈ cap×0.3 按 want 比例摊；敌军满编 = cap-1；Boss 援军 ≈ cap×0.4；
  兜底编制同样按 cap 缩放——上限 mod 调整时塔内所有编队同步伸缩
- **证道记录**：`psw_twr_cl_<school>` 存各道登顶次数；每道**首通**额外 +5 共鸣水晶 + 播报——
  六道集齐即重复爬塔的中长期目标
- 敌军生成不受流派影响（塔守军自成体系）

### 待实测
- 择道两页渲染/翻页往返/六道存档恢复/流派过滤池实际兵表/专属祝福实际出现率/首证+5水晶
- 英杰道：空单将 create_force_with_general(units="") 是否如期生成
  孤胆包是否挂上/灵契召唤三选一是否只出巨兽/单将自动结算可玩性

## §20 MCT 可调参数（merged34_mct 实装）

script/mct/settings/psw_tower_mct.lua 注册 psw_tower 模块（groovy_mct
缺席或加载失败时全部取默认值，软依赖）。运行时经 mct_num/mct_bool
逐次读取 get_finalized_setting()——**玩家改设置立即生效**，无需重启。

| 选项 | 类型 | 默认 | 作用点 |
|---|---|---|---|
| sd_mult | 滑条 0–3 | 1 | gain_stardust 全部星尘收入 |
| shop_price_mult | 滑条 0.2–3 | 1 | shop_price 商铺售价 |
| victory_mult | 滑条 0–3 | 1 | 登顶国库+星尘（与 rivwon 减半叠乘） |
| school_gmsj | 滑条 0–20 | 5 | 各流派首通水晶（0=关闭） |
| w_event/w_rest/w_elite/w_shop | 滑条 0–80 | 32/26/18/14 | 掷路签四类权重，0=该类绝迹 |
| enemy_budget_mult | 滑条 0.5–3 | 1 | enemy_budget 全部敌军预算 |
| ror_cap | 滑条 0–5 | 1 | RoR 基准限编，elite+1/boss+2 |
| rival_enable | 勾选 | 开 | 竞逐者整体开关 |
| rival_pace | 滑条 0–3 | 1 | 竞逐者推进概率倍率（0=冻结） |
| rival_reinf | 滑条 0–1 | 0.45 | 抢先登顶惩罚援军预算比（0=无援军） |
| run_cd | 滑条 0–10 | 3 | 试炼冷却回合 |

- 实现：mct_opt 单点 pcall 包
  get_mct():get_mod_by_key():get_option_by_key():get_finalized_setting()，
  任一环节失败回退默认——MCT 未装/未初始化/存档缺该选项均安全。
- loc：mct_psw_twr_* 共 35 键追加在 text/psw_tower.loc.tsv。
- 守卫战保底与商铺层保底路径不受权重影响；权重全 0 时兜底发事件签。
- [需验证] MCT 面板实际渲染（滑条精度/步长）、mid-run 改值的即时生效路径。

## §21 魔女馈赠——PSW 本体奖励回流（merged36_gifts 实装，merged41_digong 校订）

回答「爬塔之后给玩家一些原本魔女mod的技能奖励……以及装备奖励」：
登顶除联动大赏外再发三类 PSW 本体馈赠——**EX 天赋直入祈愿槽** +
**3 回合全军临时强化** + **帝弓降世（可选屠灭敌派全军）**。
另增 2 件塔圣物。

### 21.1 魔女亲授：EX 天赋（grant_psw_talent）

- 池：`psw_tower_pools.PSW_EX_TALENTS` = 60 个 `psw_tf_ex_*` 外槽建筑键
  （来自 PSW 本体 `!!Prayer_of_star_witch.pack`，已剔 `_jzms` 子效果键）。
- 授予：`psw_get_talent_slot_manager(faction)` → 遍历 slot 找
  `not slot:has_building()` 的空槽 → `cm:foreign_slot_instantly_upgrade_building`。
  **只占空槽、不拆已有天赋**——比 PSW 本体授予链保守。
- 去重复刻 PSW `_tf_owned` 三重判据：`set_<key>` / `set_main_<key>`
  效果包 + `psw_main_data.global_data["set_main_<key>"]`，全过才入抽选池。
- 软依赖：`psw_get_talent_slot_manager` 缺失（非 PSW 派系/接口未就绪）
  → return false，馈赠静默跳过；槽满同样跳过。
- 播报：`psw_twr_link_top_talent`（仅成功时发）。

### 21.2 星辉临赐：登顶临时强化（grant_victory_buff）

`VICTORY_GIFTS` 二抽一，`apply_effect_bundle` 派系级 3 回合：
- `psw_twr_gift_might` 星辉临战：近攻/近防+8、冲锋+10%
- `psw_twr_gift_ward` 星幕加护：特保+8、士气+8、魔抗+10%
DB：effect_bundles + junctions 均在 zzz_psw_tower_boons.tsv，loc 已配。
定位是出塔后立刻推一波图的窗口期爆发。

### 21.2b 帝弓降世·可选馈赠（launch_digong / fire_digong）

本体 psw_dlc6_ex_fuxuan_dgjs 仪式复刻——不是 buff，是**核弹**：
kill_character_and_commanded_unit 屠灭目标派系全部领军将领+部队。
- 触发：DL.VICTORY 确认、end_run 清算完后弹 `psw_dilemma_tower_digong`
  「帝弓降世 / 收起星弓(+2 水晶)」二选一——是馈赠抉择不是自动发放。
- 目标 digong_target()：与玩家交战派系中实力排名最前者。
- 守卫照抄本体：非人类 + 排除 `_qb<数字>` 剧情派系 + 魔王派系豁免
  （mowang_faction_key 软读取）+ 塔自有限定「仅交战派系」。
  本体另有「不能打比自己弱」的强度门槛，塔版取消——馈赠应打最强。
- 无合法目标（无交战/全 _qb/敌无领军）→ 不弹困境直接跳过。
- 待决 `SK.digong="fname|target"`：选择目标失效静默收弓；
  FactionTurnStart 校验属主+目标有效则重发困境（存档恢复）。
- 实测语义与本体差异：本体经仪式目标角色定位+全套 VFX；
  塔版纯效果（无 VFX/无目标角色），feed 静态播报不具名派系。

### 21.3 天赋共鸣（tower_talent_count）

入塔生成祈愿军时按本体已有天赋数折算将领等级：
`rank += min(5, (nor_count + ex_count) / 20)`——PSW 玩得越深塔内将领越强，
塔与本体养成互相成就。数据读 `psw_main_data.player_data`。

### 21.4 新增塔圣物（×2，并入 18.4 池）

- `psw_twr_anc_arcane_starglobe` 星穹法球（奥术物品）
- `psw_twr_anc_weapon_starbow` 星轨长弓（武器，
  `wh_main_effect_character_stat_missile_damage` +15 / 远抗 +8——
  注意 vanilla 键是 `missile_damage` 不是 `missile_strength`，后者不存在）

### 21.4b 星辉卡牌——战役侧主动道具（merged42_cards 实装）

roguelike 主动技能位：卡牌入手存 `SK.cards`（≤4 张，第5张自动折 +30 星尘），
打出经 `psw_dilemma_tower_cards` 牌单困境（OPENING THIRD / 冷却困境 SECOND
进入——卡牌不受爬塔 CD 限制）。每张一行 payload 注明效果。

| 牌 | 效果 | 实现 |
|---|---|---|
| 星步 | 全军行动力回满 | 遍历领军将领 replenish_action_points |
| 归星 | 领主（或首位领军）折返首都 | teleport_to→home_region 坐标 |
| 星愈 | 全军单位血量回满 | set_unit_hp_to_unary_of_maximum |
| 星风 | 全军魔风+15（1回合） | bundle psw_twr_card_winds |
| 星眸 | 揭开全图迷雾 | make_region_visible_in_shroud 全区 |
| 星律 | 全行省秩序+4（2回合） | bundle psw_twr_card_order |
| 星锻 | 随机塔圣物（尽得→水晶+2） | grant_tower_relic→lin_anc→gmsj |
| 星晶 | 共鸣水晶 +2 | add_gmsj |

- 入手：Boss 层(10/20/30)各 +1、登顶 +1、新事件 deck（免费抽1 / -60尘购2）
- 塔军豁免：march/heal/recall 只作用于非塔军（SK.pfcqi 比对）——
  防止对祈愿军/塔将领动作破坏 run 空间模型
- 使用失败（如无领军将领时打星步）→ 卡牌保留 + 播报提示
- [需验证] teleport_to 归星第三参省略（PSW 惯例 3 参）；卡牌连打链路
  （use_card→launch_cards 重发）在 UI 队列中的顺序

### 21.5 已知边界 [需验证]

- 60 键池按"全部 EX 天赋"抽——部分 EX 天赋是角色专属剧情物
  （如 fuxuan/syd 系），对通用祈愿槽的实际效果未逐一核验，
  最差情况是无效占位不生效，不会报错（upgrade 仅写槽）。
- 临时强化在 `end_run("victory")` 之前挂派系——run 清塔军不波及。
- `slot:has_building()` 的空槽判据 [需实测]：foreign_slot API
  在无建筑槽上返回的接口形态以实测为准。

### 17.7 签名效果包 + 词缀 + Ascension（merged40_sig）

继续吸收 ENEMY_COMPS §7.1/§7.2/§7.3 的延期项，敌军从"编队"补到"加成"层：

- **签名效果包**（§7.1）：14 个新 bundle（db/effect_bundles{,_to_effects_junctions}_tables/zzz_psw_tower_sig.tsv）。
  6 种军势按签名风格映射——beast(巨兽:MA怪物+15/冲锋+10%)、gun(火力:射程+12/装填-15%)、
  cav(骑军:冲锋+15%/移速+10%)、melee(肉搏:MA+8/MD+5)、tank(耗军:MD+12/士气+8)、
  daemon(魔域:WS+10/特保+5)；comps.SIG_BUNDLES 按主题映射，do_attack 时
  apply_effect_bundle_to_force(bundle, efcqi, 0) 挂到敌军（sig_bundle() 与
  signature_csv 同条件判定——kind∈{elite,boss,ambush} 且主题有签名才挂）。
- **Sub-faction 变体**（§7.2）：comps.VARIANTS 四主题第二套签名，1/3 掷签替换——
  skv 瘟疫僧海 / nor 冰原狼群 / vmp 幽冥骑影 / brt 天马团。
- **词缀 mutator**（§7.3）：每 run 一签挂**全体**敌军（doctrine+签名均生效），
  SK.mut 存签，5 词缀：狂怒(WS+10)/坚壁(甲+15)/迅捷(冲锋+15%/移速+10)/
  血祭(物抗+10)/魔屏(魔抗+20)；spawn_tower_army 掷签+事件播报「塔之谴」；
  MCT mutator 开关。
- **Ascension NG+**：psw_twr_asc_<派系> 跨 run 持久化，通关+1；
  asc1/2/3 三阶效果包（甲+MA+特保递进）挂全体敌军，入塔事件播报；
  键带派系后缀——各派系独立计次（sv() 是 campaign 全局 saved_value）。
- 验证：loc 26 行入包；tsv 列数齐；深扫 0 项新 missing_reference。

### 17.8 独立评审整改包（merged42_polish）

独立评审指出"工程广度 > 玩家侧打磨"的落差，本包全部落地。

**硬修复**
- `SK.dlg` 待决锁：`fire()` 上锁、`on_choice` 解锁、`FactionTurnStart` 兜底清零；`enter()` 锁内拒绝重入，杜绝连点叠困境/SL 重掷。
- 快照恢复真恢复：`launch_node/reward/boon/shop/event` 均先读 `SK.paths/rewards/boonopt/shop/ev`，有才复用、无才掷签；兑现即清档。
- 精英层接回：`roll_paths` 在 5/15/25 层强制首签 elite（不再靠 floor_kind 缺省死代码）；`preroll_elite_theme` 掷签面时同步预掷敌主题存入 `SK.pthemes`，签面揭示与实战同源。
- 商铺先验后付：将领缺失/满编/星尘不足一律不扣款。
- 清算差异化：主动撤退 cap=4（`SD_CAP_RETREAT`）、败北余额先腰斩再按 cap=2 清算、rivwon 通关折算上限减半；星尘一律全额清零。
- DL.CD 补 SECOND 手牌选项（choices/payload/loc 全链路）。

**可见性包**
- `SK.lastfl` 去重的每层 feed：`psw_twr_floor_1..30` 30 条阶段文案。
- 敌情揭示：精英签掷出即播报主题，普通战/Boss 开战前播报（`psw_twr_theme_<25 主题>` + `psw_twr_boss_<kho|nur|dae>` 具名层主）。

**休整层重做**：五选项——冥想/淬炼/净化/遣散（FOURTH：删队尾兵牌换 60 尘，卡组唯一瘦身出口）/离开。

**Boss 差异化**：常驻援军（rivwon=1.0 满额、常态 0.6、`rival_reinf` 仍可关）；Boss 额外一条不重复词缀并播报 `psw_twr_boss_affix_*`；敌将强制佩戴塔圣物星弓 `psw_twr_anc_weapon_starbow`。

**竞逐者层间咬尾**：`_advance` 内 `rival_chase`——每层 30%（MCT `rival_chase` 可调）跟进一层；回合推进保留但不再是唯一引擎。

**事件牙齿**：sacrifice（献祭队尾兵牌→S/R 祝福）/pact（吞蚀星诅咒→200 尘）/wager（押 100/300 尘下战翻倍返还，`SK.wager` 随 run 结束清零）。

**自谴+道印**：开局 FOURTH「自谴试炼」→ 敌军多吃一条词缀换 `modsd +0.5`；流派证道后（`psw_twr_cl_<school>` ≥1）再入塔 `grant_seal` 开局赠 N 级祝福。

**卡牌 run 内可用**：NODE FIFTH 开手牌，用完/空手自动回节点签面。

**文案纠偏**：星尘不跨局、撤退折算说明、灵契快照补员、商铺限购/歇业语义、节点精英层与手牌签说明。


### 17.9 记忆结晶馈赠（merged43_jyjj）

把 PSW 本体"什亭之匣"结晶直接作为 Boss 层战利品——发的是**真结晶**而非塔仿品。

- `grant_jyjj_card(faction, tier)`：从 `psw_tower_pools.JYJJ_{N,R,S}` 过滤池抽一张 →
  `psw_jyjj_main_unlock(fname, key, true)`（原生解锁+入手）→ 附赠体力+2/次数+1。
- 品级沿用 PSW 原生 lv1-5 池语义（见 `PSW_POWER_CATALOG.md`）：10层=N、20层=R、30层=S。
- 鸣潮系卡以 `mc:<gmz键>|<卡键>` 标记入池，仅当玩家 `mc_data.gmz_data[gmz].is_on` 时可选
  ——无共鸣者不发废牌。
- `crt_card[key]` 槽位判空兜底：非 PSW 体系派系/数据未初始化→直接不发放（返回 false）。
- S 档池含全部 10 张"需选目标"真超能力卡（飞雷神/剪票/时符/镜之环/感知汲取/起源弹/
  演出开始/天照/加具土命/巨大英灵）+ 预知梦/开海/岩王帝君/火萤终式。

**刻意不发**：帝弓/Atomic/流星雨/大洪水等"仪式级"破坏力不借结晶管道——帝弓已有塔专属
垂询流程；区域灭军类如要进塔，应做塔版弱化复刻而非原生发放。

**未实测**：`main_unlock` 对无什亭之匣解锁记录派系的行为、`mc_data` 判空路径、
`tili/use_num_change("heal")` 生效时机。

### 17.10 禁咒卡牌（merged44_rare）

星辉卡牌分两级：普通池（8 张，Boss层/牌室随机）与**禁咒池**（2 张，仅 `card_random_rare`
经登顶大赏发放）——对应品级表的 UR/S 仪式级复刻。

| 牌 | 复刻原型 | 机制（本地实现，不依赖 PSW 全局函数） |
|---|---|---|
| 星陨 | 超能力-流星雨（dlc6_xingfa_cnl_liuxing） | `digong_target` 取最强交战派系 → 全军每队 `set_unit_hp_to_unary_of_maximum(max(cur-40~60%,0.01))`，语义同 `psw_main_cost_character_force` 但全派系范围（原版限单地区） |
| 星缚 | 镜之环（jyjj_xd_feibi_jzh） | 同目标判定 → 每支领军 `apply_effect_bundle_to_force("psw_character_xianzhi_yidong_5ci", cqi, 1)` 冻结 1 回合（原版限单地区 2 回合） |

- 失败返还：无交战目标/`_qb` 黑名单/魔王派系 → return false → 卡牌保留+`psw_twr_card_fail`。
- `use_card` 外层 `tpcall` 兜底：PSW 禁行包缺失时静默失败扣牌。
- **刻意限制**：禁咒只发 1 张/次且仅登顶可得——强度对标帝弓垂询（帝弓灭全军，禁咒是大范围削弱/控场），不与普通牌混池稀释手牌。
