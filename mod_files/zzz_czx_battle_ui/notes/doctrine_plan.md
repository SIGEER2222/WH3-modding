# czx_battle_auto_ability — doctrine 引擎功能方案

> 状态：v1 已实现并部署（`zzz_czx_battle_ui5.pack`），运行时行为待实战校准。
> 本文档为功能级设计说明，实现细节以 `script/battle/mod/czx_battle_auto_ability.lua` 为准；
> 生成器模板 `tools/gen_auto_ability.py` 与源文件保持逐字节同步。
>
> **2026-09-19 v1.6.2（指纹自伤修复，script_log_1056 实证）**：
> 干净 playset（无 tc、无测试包）下仍在 9200ms 全员 reclaimed-ordered——
> 病根不在外部 mod：uc 指令异步翻转 is_ai_controlled，下一 tick 走
> `prev_ai` 跳变分支时 `order_dest` 已被置 nil，基线退到 `prev_ordered`
> （下单前的旧目的地），与刚发的 advance 目的地比对必爆 → 自己的批量令
> 被自己当玩家接管。`note_our_order` 现直接记录目的地（移动令=目标点，
> 攻击令=目标位置快照，漂移由追击豁免覆盖）。另查明：`bait ->` 日志只是
> 选人记录，rush 下 bait_step 正确未激活，非 bug。
>
> **2026-09-19 v1.6.1（战局实证修复，script_log_0957）**：
> ① 指纹接管检测修复——`atk_target_uid` 豁免原先只看 `current_target` uid
> 匹配，而 current_target 永远返回旧目标 → 豁免永久成立 → 接管全 MISS；
> 现要求新目的地距该目标 ≤70m（真追击才豁免）。② 隐身对峙修复——敌军全员
> stalk/超视距时 `enemies` 为空、攻击令空转（木精堆实站 16 分钟）；attack
> 兜底改为目标不可见时 `advance` 朝其位置进军（移动令对隐身单位合法）。
> ③ dodge 救活——`Special Ability` 事件实测 `get_unit()`=nil（无施法者，
> 拿不到敌我），但 `get_position()`=落点有效、`s1`=技能 key；改为有落点
> 即躲。④ sim 记账修正——back 只统计真正 reclaimed 过的单位。
> 另实测确认：`Move Orientation Width` 命令事件 `get_unit()`=nil，
> `Attack Unit` 事件的 unit 是**目标**而非下令者——cmd_reclaim 指令事件
> 收回路径不可用，接管检测只能靠指纹。
>
> **2026-09-19 v1.6（排兵布阵 + 勾引）**：delegation 完成时按角色摆一次阵型
> （`formation`）——朝敌军质心取朝向，melee/monster 前排、shooter 二排、
> artillery 后排、cav/flyer/cav_shot 分两翼、lord 中后，列距 45m；敌军质心已
> 在 250m 内（伏击贴脸）则跳过。勾引（`bait`）：gunline/balanced 下挑最便宜的
> 地面机动单位（cav/cav_shot，空军骗不动地面）前出到 150m 撩拨，敌军贴近 90m
> 即向射手线逃（`bait-bit`/`bait-run`），甩开 220m 后重新出钩——把追兵拖进火力网。
>
> **2026-09-19 v1.5.5（克制矩阵补全）**：`monster→artillery +35`（巨兽砸炮组）、
> `lord` 行补 `lord+15/monster-10/melee-15`（领主找决斗、不绞肉）、`melee→cav_shot/
> flyer -20`（步兵不追追不上的目标）、`shooter→flyer +15`（对空）、`cav_shot→shooter
> +15`；骑射 harass 也吃追溃（`nearest_router` 提取共用）。
>
> **2026-09-19 v1.5.4（战术层补洞）**：法师类领主/英雄（`mage` 旗标）不再
> free_engagement 送脸，除 rush 外一律 `sheltered`——贴射手线、只拦 70m 内贴身敌；
> `kite_step` 威胁角色加 `flyer`（敌方空军俯冲后排也触发撤退）；屏线/拦截的
> anti_large 加成覆盖骑兵目标（与 attack 任务一致）；balanced `free_fire` 射手
> 自动开 skirmish（`no_skirmish` 单位跳过）；循环冲锋对 `flyer` 同样武装。
>
> **2026-09-19 v1.5.3**：伤员处理改为**脱战跳步**——hp < `wounded_hp`(0.35) 且仍
> 在近战的高价值单位（lord/monster/cav/highvalue）朝远离最近敌人的方向跳出
> `wounded_pull_m`(80m)，脱离近战立刻回任务层继续打；每 `wounded_retry_ms`(12s)
> 最多一跳。战斗内血量不回复，"撤到后场等回血"等于永久减员，已废弃；planner
> 成员资格全程不动。
>
> **2026-09-18 v1.1（脱离 AI General 依赖）**：新增 `ensure_delegation`——开局 ~3s 自动
> 把本地军全量交给 `script_ai_planner("czx_auto")`（野战白名单 gated，攻城不托管），
> 玩家经原版组 UI 收回的单位记 `reclaimed` 永不重夺，后进场单位（增援/召唤）自动补托管；
> `order_attack` 加 `focus_cap=3` 每 tick 每目标指令上限；三处目标评分加 `COUNTER_BONUS`
> 攻防克制项；tick 回调套 `pcall`（裸错会杀 timer_manager 泵——czx_tc `bm:armies()` 实测教训）。

## 背景与结论

- 托管实现（AI General 系）= 把 `script_unit` 交给引擎 `script_ai_planner`。planner 只下移动/攻击指令，**从不放技能**，规划间隔 ~15–30s，间隙里单位发呆；攻城战/任务战更弱。
- 直控系实现（Attack Move & Countercharge / Aerial Pursuit）= `unitcontroller` 每 ~0.7s 高频下指令，单位被"锁"在 mod 指令上。
- 引擎限制：指令回调不区分来源（玩家/uc/planner）；任何 uc 指令隐式夺权；`release_control()` 还给"玩家/AI"而不是 planner——所以**只在单位确实空闲时才干预**，把控制振荡降到最低。
- 玩家社区微操共识：远程阵容里近战是护卫不是主力——守线、拦截贴身敌人、开 guard 不追击、给直射火力留射界、留反大后备拦巨兽。

## 架构（混合过渡，预留全接管）

```
tick() 每 poll_ms=3000 执行：
  pass 1  snapshot   托管单位+敌军快照，逐单位角色分类
  pass 2  doctrine   按阵容构成选策略（auto/强制）
  pass 3  角色行为    每角色独立 handler，仅对"持续空闲"的单位下指令
技能释放（try_cast）与 doctrine 正交，pass 3 里对所有角色先跑。
```

将来若弃用 planner 改全接管：只需把 pass 3 的"仅空闲干预"换成常驻状态机，pass 1/2 复用。

## 角色分类（classify，首个命中生效）

**两级判定**：烘焙档案 `CZX_UNIT_PROFILE`（2616 条：原版全量 + 本仓库各 mod 的 land_units）优先，未收录单位（敌方第三方 mod 兵种）走运行时布尔链。

烘焙格式 `["type"] = "ai_role|category|class|is_large"`，由 `gen_auto_ability.py` 从 land_units TSV 生成（`ai_usage_group`/`category`/`class`/`ground_stat_effect_group`）。

| 角色 | profile 路径 | 运行时兜底 |
|---|---|---|
| `artillery` | category=war_machine/artillery | `is_artillery`/`is_war_machine`，或弹药+射程≥250 |
| `lord` | class=`com`（领主/英雄统一此类） | `is_commanding_unit()` |
| `flyer` | `can_fly()`（lord 判定之后） | 同 |
| `monster` | is_large=1 或 category=war_beast | `is_war_beasts`/`is_elephants` |
| `cav` | category=cavalry | `is_cavalry`/`is_chariot`/速度≥60 |
| `shooter` | category=inf_ranged 或有弹药 | 有弹药 |
| `melee` | 兜底 | 兜底 |

**重要教训**：`unit_class()` 只返回 `land_units.class` 的 10 个粗值（com/inf_mel/inf_mis/inf_spr/cav_*/chariot/art_fld/spcl），**所有巨兽（龙/巨人）都是 `inf_mel`**——字符串匹配 monster/lord 完全失效，已废弃为仅日志用途。敌军快照加 `is_visible_to_alliance()`/`is_hidden()` 门槛，不响应看不见的单位。

## doctrine 选择（select_doctrine）

| doctrine | auto 触发条件（基于**托管**单位构成） |
|---|---|
| `kite` | cav+flyer 占比 ≥ `kite_min_mobile_share`（0.70） |
| `gunline` | shooter+artillery 占比 ≥ `gunline_min_share`（0.35）且 ≥2 队 |
| `rush` | 射手占比 ≤ `rush_max_shooter_share`（0.15） |
| `balanced` | 其他 |

`CONFIG.doctrine` 可强制 `"gunline"/"balanced"/"rush"/"kite"/"none"`。切换时打 `doctrine -> xxx` 日志（含 delegated/shooters/mobile 计数）。

## 角色 × 策略行为矩阵（全部仅作用于持续空闲 ≥8s 的单位）

| 角色 | gunline | balanced | rush | kite |
|---|---|---|---|---|
| melee/monster | 护卫：拦截自身 110m 内或距最近射手 100m 内的敌人；离锚点 >160m 自动回防；一次性开 `defend`（guard） | 同左但放宽：拦截 150m/回防 220m | 空闲即攻最近敌 | 同 rush |
| cav | 反大后备：优先拦距锚点 200m 内的敌方 monster，其次拦 200m 内贴身敌；>220m 回防 | 侧翼猎手：400m 内优先攻敌方射手/炮兵，否则松护卫 | 冲锋最近敌 | 同 balanced |
| flyer | 500m 内优先猎敌方 flyer/artillery，否则按 cav 规则 | 同 | 同 | 同 |
| lord | 拦截 150m 内近敌，**不拴回防**（自由行动） | 同 | 空闲即攻 | 同 |
| shooter | 开 `skirmish` 自动风筝；只打 `missile_range()*1.3` 内的敌人（不前出越过护卫线） | 空闲即攻 | 空闲即攻 | 同 gunline |
| artillery | 永不下指令 | 同 | 同 | 同 |

## 全局约束（所有 doctrine 共享）

- 干预前提：`unit:is_idle()` 连续 ≥ `idle_kick_after_s`（8s）且距上次指令 ≥ `retry_ms`（20s）
- 每条 uc 指令后 `release_control()`；**没下指令绝不 release**（否则制造控制振荡）
- `defend`/`skirmish` 行为一次性设置，`can_use_behaviour` 前置判定；单位解除托管后标记重置
- 技能释放不受 `idle_kick` 总开关影响（开关只管移动类指令）

## 日志标签（实战验证对照表）

| 日志 | 含义 |
|---|---|
| `loaded, poll Xms` | 脚本加载 |
| `role-probe <type> class=.. spd=.. ammo=.. range=.. fly=..` | 新兵种类型分类数据（校阈值用） |
| `doctrine -> <name> (delegated=N shooters=N mobile=N)` | 策略切换 |
| `cast <ability> on <uid>` | 技能释放成功 |
| `idle-kick` / `screen-intercept` / `screen-return` | melee/monster 兜底/拦截/回防 |
| `cav-antilarge` / `cav-intercept` / `cav-hunt` | 骑兵反大/拦截/猎后排 |
| `flyer-hunt` / `lord-intercept` / `shooter-engage` | 飞行猎杀/领主拦截/射手接战 |

## 可调参数（CONFIG 顶部）

```lua
poll_ms=3000  retry_ms=20000  cast_spells=true  engage_range_m=120
unit_keys={}  banned_abilities={}
idle_kick=true  idle_kick_after_s=8  idle_kick_range_m=400
doctrine="auto"  gunline_min_share=0.35  rush_max_shooter_share=0.15
kite_min_mobile_share=0.70
cav_min_speed=60  artillery_min_range=250
intercept_radius_m=110  protect_radius_m=100  leash_radius_m=160
bal_intercept_radius_m=150  bal_leash_radius_m=220
cav_intercept_radius_m=200  flank_hunt_range_m=400  flyer_hunt_range_m=500
shooter_hold_mult=1.3
```

## 已知风险与待验证项

1. ~~`unit_class()` 返回集未知~~ 已消解：class 只有 10 个粗值（巨兽全是 inf_mel），改用 CZX_UNIT_PROFILE 烘焙表 + `is_*` 布尔链兜底。
2. `is_visible_to_alliance`/`is_hidden` 对敌军的实际行为差异 `[需验证]`——误判方向最多是不主动攻击潜行单位，可接受。
3. 骑兵在 gunline 里当后备可能浪费机动力——若实测觉得骑兵该永远侧翼，改 `HANDLER.cav` gunline 分支即可。
4. planner 仍会在规划间隙给我们的护卫单位下进攻指令——guard 模式 + 回防兜底，但无法完全阻止 planner 间歇性"抽风"；根治只能走全接管。
5. 攻城战/任务战 planner 本身就弱，doctrine 兜底只能减轻不能消除发呆。
6. 门槛值（35%/15%/70%、110/160/400m 等）全是初值，需实战日志校准。

## TargetEvaluator v1（Utility 评分选目标，已实装）

`best_scored(unit, list, score_fn)` 通用选择器；各 handler 的目标从"就近"升级为加权评分：

| 场景 | 评分公式 | 说明 |
|---|---|---|
| 护卫拦截（melee/monster 屏线） | `-dist*0.5 + 50*(敌monster) + 40*(己方anti_large∩敌monster) + sv*0.2` | 大怪和高价值目标优先被拦 |
| 骑兵枪阵后备 | `-dist*0.3 + 80*(敌monster) + sv*0.3` | 距锚点 2×protect 内的巨兽最重 |
| 骑兵侧翼/飞行猎杀 | `sv - dist*0.2` | 敌方射手/炮兵里挑最贵的打 |
| lord 拦截 | `sv - dist` | 150m 内挑高价值目标 |

`sv` = `unit:strategic_value()`（引擎自带价值估值，`[需验证取值范围]`）。候选集先按角色 zone 过滤（不在拦截圈内的返回 `-inf` 排除），再在集内比评分。rush/idle-kick 仍用就近——冲锋场景不该想太多。

## 实战验证记录（script_log_160926_1837.txt，混沌矮人敌 vs 震旦玩家军）

- 加载 ✓ `loaded, poll 3000ms`
- doctrine 自动选择 ✓ `none`(delegated=0) → `gunline`(del=40, shooters=32, mobile=1)
- role-probe 正确分类 ✓：诸葛亮 `fly=true`→flyer、天灯 `range=397`→artillery 边界、混沌矮人巨兽 `inf_mel+is_large`→monster、罗德发射器 `chariot+range320`→artillery
- TargetEvaluator 实战 ✓：`flyer-hunt zhugeliang -> deathshrieker_rocket_launcher`（flyer 主动猎敌方炮兵）
- 自动施放 ✓：`cast psw_dlc7_delisha_bjsr`、`formation_lance`、`djs_fw_190_zhadan`（mod 自定义技能正常工作）
- 全程零 ERROR；screen-intercept/idle-kick 未出现（战斗 173s 内敌军未压进拦截圈 / 单位未持续空闲——待区分，已加 `tick-stats` 心跳日志每 ~60s 输出 doctrine/del/idle/enemies 计数）

**注意**：`unit:ammo_left()`/`missile_range()` 在战斗中返回的是**含战役加成**的实时值（诸葛亮 ammo=0 但 range=270 的混合型单位观察到的 range 是加成后米数）；分类用的是烘焙 profile 的静态标注 + 运行时布尔谓词，不受影响。

## ActionSelector v1（任务分配层，已实装）

`assign_task(d, ctx)` 把 doctrine×role 映射为任务 id，handler 按任务（而非角色）分发——决策与执行分离，为 Squad/HTN 升级留好接口。任务变更打 `task <type> (<uid>) role=<r> -> <task>` 日志。

| 任务 | 来源 | 执行内容 |
|---|---|---|
| `protect_gunline` | gunline/balanced 的 melee+monster | 屏线护卫（半径随 doctrine 松紧） |
| `intercept_breakthrough` | gunline 的 cav | 反大后备拦截 |
| `hunt_backline` | balanced/kite 的 cav+flyer，gunline 的 flyer | flyer 先猎敌 flyer/炮兵，再猎敌后排；无目标时按 doctrine 退回护卫/拦截 |
| `free_engagement` | gunline/balanced 的 lord | 自由拦截（不拴绳） |
| `hold_fire_line` | gunline/kite 的 shooter | skirmish + 射程内才接战 |
| `free_fire` | balanced 的 shooter | 空闲即攻 |
| `attack` | rush/kite 其余、未知兜底 | 空闲即攻 |
| `hold_position` | artillery | 永不下指令 |

行为变化 vs 纯角色版：gunline 的 flyer 现在 hunt_backline（先猎敌空军/炮兵，再猎敌后排，兜底才回拦截）——比原来"猎完空军就站桩当后备"更积极。

## 实施记录

- [x] ① 三段式重构 + 全角色分类 + role-probe/doctrine 日志
- [x] ② gunline/balanced 完整行为（screen/cav/flyer/lord/shooter/artillery）
- [x] ③ rush/kite 行为分支
- [x] ④ 打包部署 `zzz_czx_battle_ui4.pack`（生成器同步、块配平、md5 校验）
- [x] ⑤ 分类修正：接入 `czx_battle_tactical_commander` 调研成果——CZX_UNIT_PROFILE 烘焙表（2616 条）+ `is_*` 布尔链兜底 + 敌军可见性门槛；部署 `zzz_czx_battle_ui5.pack`
- [x] ⑥ 首次实战验证：加载/doctrine/role-probe/评分猎杀/施放全部工作，零报错（见上节）
- [x] ⑦ TargetEvaluator v1：best_scored Utility 评分接入 melee/cav/flyer/lord 目标选择 + `tick-stats` 心跳日志
- [ ] ⑧ 继续实战校准：gunline 下 screen-intercept/screen-return 是否触发、控制振荡、idle 单位心跳统计
- [ ] ⑨ v2 升级路径评估：ActionSelector 任务层（protect_gunline/intercept_breakthrough/hunt_backline）→ Squad 分组 → HTN


## 冻结事故追查（2108/2208 两场同图攻城战）

- 症状：模拟线程冻结（battle_ms 停走）而 UI/Lua 事件继续 ~20s+；两场均在 cast 后 ~1-1.7s 冻结。
- 交叉比对：`djs_fw_190_zhadan`（FW190 召唤物投弹，gyrobomber_bomb 类机动技能）是两场冻结 tick 的唯一共同 cast；但它单独出现并不必然冻结（2131 场 cast 后活了 458s）→ 概率性 wedge。
- 已上三层防御：
  1. 机动/投弹技能全局 deny：`zhadan`/`gyrobomber_bomb`/`copter_bomb`/`bomb_drop`/`djs_f4u_t0`（打 `denied-maneuver` 日志）
  2. 召唤物整体不自动施放（`cast_on_summons=false`，`unit:type():find("summon")`）——防"召唤物到期消失时效果仍在结算"的 despawn 竞态；任务/指令不受影响（打 `summon-skip` 日志）
  3. 施放静默窗 `cast_quiet_ms=6000`：成功施放后 6s 内不给该单位发任务指令——防同 tick "cast+order" 把机动动作撕断
- 若再冻结：基本可排除我方 cast 面，下一嫌疑梯队 = aigeneral 指令层 / jg77 attack_unit / RLH 的 5 个常驻全场扫描循环。

## v1.2：planner 常驻指令修复"全军发呆"（2334 局实测驱动）

**症状**（script_log_180926_2334.txt，自定义野战，36 单位托管成功）：
- auto-delegate 36 单位后 18s 起整批被标 reclaimed，del=36→25→20→2→1 持续崩落
- 全程 idle=0，整场战斗 v1 只发出 2 条 idle-kick 指令
- 战果全靠 planner 默认被动 posture 硬撑，视觉上=部队站桩、"战术一坨"

**根因**：
1. script_ai_planner:new() 后不给任何指令，引擎会把单位陆续放回玩家控制（is_ai_controlled→false）——lib 里 defend_position 自带 30s should_reorder 重发循环，orderless planner 没有
2. is_ai_controlled=false 被 reclaim 逻辑一刀切永久除名 → 掉一个少一个
3. planner 的"驻守"指令不算 is_idle → idle-kick 永远够不着 → v1 实质零输出

**修复**：
- issue_planner_directive()：rush/kite → planner:attack_unit(距我方最近敌单位)，目标死/溃或每 20s 重选；gunline/balanced/none → planner:defend_position(get_centre_point(), 120)（=原版"Defend this position"按钮同款，引擎自带 30s 重发）
- reclaim 改逃逸窗口计数：ai→player 跳变累计，60s 窗口内 ≥2 次才认定玩家收回（planner 偶发掉线当 tick 就被 add_sunits 补回，不累积；玩家想真收回需拿两次）
- tick-stats 加 planner=（planner:count() 实有数，与 del 对账）

**新增日志**：directive attack -> type d=dist / directive defend r=120 / directive-fail / re-delegate type / reclaimed x n

**lib 确认**：attack_unit / defend_position / get_centre_point / count 均见 lib_battle_script_ai_planner.lua；attack_unit 内部 ensure_units_are_released() 后交给引擎 planner 对象——即原版 AI 托管按钮同一机制。

## v1.3：玩家微操/托管双向交接

原版编组 UI 的"AI 托管"开关就是按钮——`is_ai_controlled` 即其状态，无需自制 UI。双向规则：

- **收回**（玩家→手操）：ai→player 掉线分两种——planner 偶发掉线（应当 tick 补回）和玩家真的收回。判据两层：
  1. **订单指纹**（单 tick 快判）：掉线时快照 `ordered_position`；若单位在脱管状态下 ordered_position 位移 >30m = 玩家新下的指令（planner 残余指令不会刷新 ordered_position）→ 立即 `reclaimed-ordered`
  2. **逃逸窗口**（兜底）：60s 内 ≥2 次 ai-drop → `reclaimed x n`（玩家想拿稳 = 拿两次）
- **归还**（手操→AI）：原版组 UI 再开 AI 托管 → `is_ai_controlled→true` → 清 `reclaimed`/`escape_pos`（`handed-back` 日志），单位自动回到任务层。escapes 计数保留衰减（防止 planner 掉线+归还序列误累计）
- **发呆兜底**：非 reclaimed 的脱管单位当 tick 就 `re-delegate` 补回 planner——脱管空窗 ≤1 tick，不存在"没人管"的兵

## v1.4（2026-09-19）：社区调研驱动的战术微操升级

调研源：AI General III 源码（extract 自 workshop 包）+ Steam/Reddit 社区反馈 + exe 字符串。

### 交接层（AI General 机制移植，替代猜测式检测）

- **热键 toggle**：`ShortcutTriggered` 事件 + `camera_bookmark_save0`（游戏设置"Save Camera Bookmark 1"可改绑）。选中卡片按热键：AI 单位→玩家（记名 `reclaimed`，`planner:remove_sunits` 收回）；玩家单位→AI（清记名，`planner:add_sunits` 归还）
- **热键临时 override**：`camera_bookmark_save6`。选中的 AI 单位立刻交还玩家微操；单位**连续闲置 10s**（宽限 20s 起算）自动归还 AI——玩家微操完不用手动还，AI General 验证过的 UX
- **指令事件收回**（`cmd_reclaim`）：`"Attack Unit"`/`"Move Orientation Width"` 等 UI 指令事件在非任务时段落到托管单位 = 玩家点击 → 单事件立即 `reclaimed-cmd`，比指纹更快。`in_task_pass` 标志过滤我们自己的 uc 指令
- **指令探针**（`cmd_probe`）：每种指令名前 8 次事件 dump 全字段（unit/s1/pos/b1/inpass）——验证 schema 用

### 战术微操（社区痛点逐项对应）

- **骑兵循环冲锋**（`cycle_charge`）：攻击令装填 `charge_state{phase="in"}`；`is_in_melee()` 持续 `charge_fight_ms`(9s) 后 `charge-out` 后撤 50m；`charge_regroup_ms`(6s) 后状态清除，下个攻击令重新装填——冲锋加成是骑兵主要伤害，站撸是浪费
- **射手风筝**（`kite_fallback`）：近战系敌人进 `kite_threat_m`(30m) → `kite-back` 后撤 60m；`is_moving()` 判定已在撤即保持——引擎 skirmish 旗标撤太早，显式距离阈值更贴玩家手感
- **残血后拉**（`wounded_pullout`）：lord/monster/cav `unary_hitpoints()<0.35` 且 `is_in_melee()` → 撤向 planner 中心；恢复到 0.55 归队
- **躲技能**（`dodge`）：`"Special Ability"` 指令事件 → 敌方施法者 + `get_position()` 落点 → `dodge_radius_m`(45m) 内我方单位 `dodge` 散开 60m。`[需验证]`：敌方施法是否走指令事件、get_position 是否给落点——cmd_probe 日志先行

### 克制矩阵

保留 v1.3 `COUNTER_BONUS`（骑→射手+40/炮兵+50、反大→巨兽、flyer→炮兵/射手）。`anti_large` 标记沿用 unit_set AI profile。

### v1.5 社区战术情报（Steam/CA 论坛 2026-09 调研）

克制共识：
- 戟/矛兵（`anti_large` flag）同时克骑兵和巨兽——不止巨兽
- 远程集火是巨兽第一杀手（巨兽大多无甲）——`shooter→monster` 加权 30
- 骑兵克射手/炮兵（+40/+50），且要**追杀溃兵**防止重整（`enemies_routing` + `rundown_range_m=120`）
- 骑射 = 骚扰兵：永远风筝、绝不站撸 → 新角色 `cav_shot`（`harass` 任务 + skirmish 行为）
- 冲骑（`shock` flag）伤害大头是冲锋加成 → 循环冲锋已是 v1.4 机制
- `ai_usage_group` 列是全种族可用分类法：anti_large/shock/highvalue/no_skirmish/harasser/mage 全部 baked 进 `profile_of()`

对局记录（复盘数据源）：
- `roster ally/enemy <type>/<role> x<n>`：开局双方兵种 × 角色 tally
- `tick-stats ... hp=<ally>/<enemy>`：双方总血量和每 60s 快照
- `outcome WIN/LOSS`：一方全溃/全灭时输出

### v1.6.4 实测修正（battle 1152，2026-09-19）[实测/需随版本复查]

`ordered_position` 语义陷阱：对正在执行**攻击令**的单位，它返回**单位自身位置**（或跟随的追击路径点），不是目标位置。证据：每条 engage 后 ~3s（下一轮询 tick）准时跟一条 reclaimed，d2e 数值精确等于单位到敌人的距离。

接管指纹新增两条抑制（先验签名，误伤面为零）：
- np 距单位自身位置 ≤20m = 不存在外来指令
- np 距我们最近 4 条指令目的地之一 ≤40m = 引擎重放旧指令

残余盲区（已接受）：玩家对敌军的**攻击点击**不会触发 reclaim——attack 令的 ordered_position 可能也退化；移动拖拽仍会正常收回。


### v1.6.5 凝聚力系统（battle 1210/1215 实测）[实测/需随版本复查]

用户反馈"猛冲脱离部队"——快单位（骑兵/飞行/巨兽）idle 后被 attack 任务分配全图目标，孤军深入被围。两层防御：

- **拴绳闸门**（`cohesion_leash_m`=170）：TASK_EXEC.attack 的 engage/run-down 和 hunt_backline（放宽 1.6x）的目标必须落在**任一友军** 170m 内。关键：度量用"距最近友军"而非"距质心"——v1 质心版在 27 前排 ×45m 布阵下把两翼全误判为孤立（6200ms 全军 regroup 刷屏）。超绳目标 → `hold-line` 收拢到绳边等战线推进（质心跟随 blob，环边持续推进不 stall）。
- **孤立归队**（`cohesion_regroup_m`=240）：`cohesion_step` 每 tick 检查——最近友军 >240m、非近战、非炮兵、非诱饵 → `regroup` 走回质心。阈值大于拴绳，给交战目标留缓冲。

指纹误报持续收敛（battle 1215 实锤）：
- **指令风扇扩散不止 5s**——planner 指令刷新后行军航点持续落地十几秒。两条新抑制：
  - 刷新后 5s 窗口内全部翻转视为 planner 噪声（`directive_ms` 时间戳）
  - np 比单位更靠近指令目标 ≥40m = 行军航点（方向签名），抑制并采纳为基线
- **`is_player_controlled` 硬门槛**[实测证伪]：battle 1224 全部 reclaim 均 `pc=true`——该 API 语义是"可被玩家控制"而非"正被玩家操控"，不能当判别器，保留为无副作用的兜底分支。
- **移动门控**（battle 1228 实锤有效）：`ordered_position` 行军时返回**寻路航点**而非终点——移动中一律不评估指纹；只在单位静止时比对 np 与基线。代价：接管检测延迟到单位停稳；收益：行军段误报归零（1228 全场 reclaim 6 次 vs 1210 的 48 次）。

### v1.6.6 走廊布阵 + 反冲预备队（桥战调研 2026-09-19）

社区共识（TWC 桥战指南/锤砧战术/攻城预备队用法）：
- 桥头战骑兵标准位 = **锋线后第二排预备队**，敌压上来时反冲——不是队尾看戏，也不是孤冲送死
- 锤砧前提是有 flank 可绕；窄图无 flank 时骑兵价值 = 反冲预备队 + 追溃
- 冲锋需要直线空间——桥上挤满人时正确位置就是锋线后等缝隙

实现：
- **走廊布阵**（`formation`）：布阵量军队横向展开宽度 <280m 判走廊 → 车道按可走宽度折行进深，地面机动编入 `mobiles` 第二排（近战后排），空军仍甩两翼（能飞过不可走区）。日志带 `corridor=` `spread=` `mobiles=` 字段。
- **`reserve_counter` 任务**：hunt_backline 全目标被拴绳拒（走廊或目标全在绳外）时的兜底——锚定**交战锋线**（在 melee 的友军质心，fallback 战线质心），无压时停锋线后 45m（`reserve-park`），敌进锋线 `bal_intercept_radius_m` 内就 `counter-charge`（counter_of+巨兽优先，走 order_attack 自动带循环冲锋）。
- **修正的兜底 bug**：原兜底 `screen_hold` 锚射手群——窄图上射手在队尾 → 骑兵锚射手 = 停队尾发呆（用户截图实锤）。gunline 阵型除外（射手即战线，intercept_breakthrough 语义正确）。

### v1.6.7 部署阶段闸门 + rush 机动单位修任务（战役战局 1324 实测驱动）

battle 1324（血河渡口，32v32）暴露三个问题：

- **部署期乱动**[已修]：Deployment 阶段 29.9–61.2s 期间 mod 下发了 8×摆位 + 32×advance + 62×hold-line——"准备阶段自动平移靠前"就是 advance 在部署区内推全军。现 `bm:is_deployment_phase()` 为 true 时：planner 指令、任务执行、micro 步全部跳过；formation 保留（自动布阵本来就是部署期功能）；**部署期拖拽只吸收基线不 reclaim**（拖拽摆位≠接管，否则被拖单位整场脱管）。
- **rush 下没人切后排**[已修]：assign_task 的 rush 分支原来全员 `attack`——6 个机动单位（飞蝠×3/吸血魔/飞将×2）全挤进人堆。现 rush 下 cav/flyer/`flanker` 画像 melee（如 dire wolves 的 `melee_flanker_undead`）→ `hunt_backline`，无合法目标落 `reserve_counter`。
- **拴绳锁死飞行切后**[已修]：敌后排隔河 300m+ 超出 272m 拴绳全拒。现 flyer 目标过绳时若 `enemy_support`（90m 内其他敌人 ≤3）判定孤立仍允许俯冲——飞兵无视地形能自行撤离；地面机动保持硬拴绳。

### 测试断言化（battle 1336/1341 验证）

之前漏检的根因：测试 XML 带 `<skip_deployment/>` 导致部署期路径从未被跑；且只看 reclaim/idle 总数，没断言任务分配正确性。现建立：

- `scratch/czx_battle_test/assert_battle_log.py <log> [--expect-win] [--expect-deploy]`——11 项断言：deploy-silent（部署期零战术指令）、mobile-tasking（cav/flyer 不得拿 attack）、mobile-activity、reclaim-bounded（总量≤12 且 2s 突发≤5）、idle-after-contact（接敌 45s 后 idle≤6，容忍 join 尖峰）、del-survival≥40%、outcome、formation-once、no-mod-errors 等。
- `czx_test_battle_deploy.xml` = 去掉 skip_deployment 的变体；测试包 test_sim 在部署 9s 后自动 `SimulateLClick("button_battle_start")` 开战，覆盖部署期路径。
- 实测：1336（部署路径）与 1341（跳部署回归）全部断言 PASS；v1.6.7 修复在旧日志 1324 上回放断言会 FAIL（125 条部署期违禁指令 + 9 个 cav/flyer→attack），确认断言有效。
