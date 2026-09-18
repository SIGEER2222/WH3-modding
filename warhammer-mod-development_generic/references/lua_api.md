# Lua 常用 API 与脚本模式（通用版）

## 核心原则

- WH3 战役脚本按 Lua 5.1 写法处理。
- 任何未在官方文档、原版脚本或实测中确认的 API，生成前必须 grep。
- `core:add_listener` 必须使用 5 参数签名。
- 访问 campaign model/object 的初始化逻辑推荐放 First Tick。
- 读档仍需存在的监听器，不要只放在 `add_first_tick_callback_new`。

## `core:add_listener` 正确签名

```lua
core:add_listener(
    listener_name,         -- string：监听器名称
    event_name,            -- string：事件名
    condition_fn_or_true,  -- function(context) -> boolean，或 true
    callback_fn,           -- function(context)
    persistent             -- boolean：true 持续监听；false 触发一次后移除
)
```

正确示例：

```lua
core:add_listener(
    "custom_example_feature_faction_turn_start",
    "FactionTurnStart",
    function(context)
        return context:faction():is_human()
    end,
    function(context)
        out("custom_example_feature: human faction turn = " .. tostring(context:faction():name()))
    end,
    true
)
```

错误示例：

```lua
-- 错误：少了第 4 参数 callback_fn，true 被错误放到 callback 位置
core:add_listener(
    "custom_example_feature_faction_turn_start",
    "FactionTurnStart",
    function(context)
        return context:faction():is_human()
    end,
    true
)
```

## 推荐脚本模板

```lua
-- custom_<feature>.lua

local MODULE_KEY = "custom_<feature>"

local function log(message)
    out(MODULE_KEY .. ": " .. tostring(message))
end

local function is_valid_faction(faction)
    return faction and not faction:is_null_interface() and not faction:is_dead()
end

local function init_listeners()
    core:remove_listener(MODULE_KEY .. "_faction_turn_start")

    core:add_listener(
        MODULE_KEY .. "_faction_turn_start",
        "FactionTurnStart",
        function(context)
            return is_valid_faction(context:faction())
        end,
        function(context)
            local faction = context:faction()
            log("FactionTurnStart " .. tostring(faction:name()))
        end,
        true
    )
end

cm:add_first_tick_callback(function()
    log("first tick start")
    init_listeners()

    if cm:is_new_game() then
        log("new campaign initialisation")
        -- 只在新战役执行的一次性逻辑
    end
end)
```

## First Tick 说明

| 函数/模式 | 用途 | 注意 |
|---|---|---|
| `cm:add_first_tick_callback(function() ... end)` | 新战役和读档都执行的首帧初始化 | 默认用于注册监听器、读取存档值、访问 campaign object |
| `cm:add_first_tick_callback_new(function() ... end)` | 仅新战役首帧执行 | 不适合注册读档仍需存在的监听器 |
| `cm:is_new_game()` | 判断当前是否新战役 | 可放在 `add_first_tick_callback` 内做分支 |
| 顶层代码 | 定义常量、本地函数、静态表 | 避免顶层直接访问 campaign object |

## 常用事件

| 事件 | 触发时机 | 常见 context |
|---|---|---|
| `FactionTurnStart` | 派系回合开始 | `context:faction()` |
| `WorldStartRound` | 新一轮开始 | 视事件而定 |
| `CharacterTurnStart` | 角色回合开始 | `context:character()` |
| `BattleCompleted` | 战斗结束 | 常配合 `cm:model():pending_battle()` |
| `IncidentRequest` | Incident 请求 | 需查原版用法 |
| `UICreated` | UI 创建 | UI 逻辑优先考虑 `core:add_ui_created_callback` |
| `PanelOpenedCampaign` | 面板打开 | `context.string`（**字段**不是方法）= 面板名 |
| `ComponentLClickUp` | 组件左键点击 | `context.string` = 组件 id |

注意：`PanelOpenedCampaign` / `ComponentLClickUp` 等事件的字符串参数在当前引擎是**字段** `context.string`，不是 `context:string()`；误写成方法调用会报 `attempt to call method 'string' (a string value)`，且该监听器条件函数内抛错会导致监听器整个不触发 `[实测/需随版本复查]`。

## campaign_manager 常用 API

生成前仍建议在本地 `gamedata/documentation/script` 或 `gamedata/script/` grep。

### 派系与模型

```lua
cm:get_faction(faction_key)              -- 返回 faction interface 或 nil/null interface
cm:model():turn_number()                 -- 当前回合数
cm:model():campaign_name_key()           -- 战役 key
cm:is_new_game()                         -- 是否新战役
```

派系对象常用检查：

```lua
local faction = cm:get_faction(faction_key)
if faction and not faction:is_null_interface() and not faction:is_dead() then
    out("Faction ok: " .. tostring(faction:name()))
end
```

### Effect Bundle

```lua
cm:apply_effect_bundle(bundle_key, faction_key, turns)  -- 本地官方文档说明 turns = -1 可永久应用
cm:remove_effect_bundle(bundle_key, faction_key)
cm:create_new_custom_effect_bundle(bundle_key)
cm:apply_custom_effect_bundle_to_faction(effect_bundle, faction_object)
```

动态 bundle 对象常见方法：

```lua
effect_bundle:add_effect(effect_key, scope, value)
effect_bundle:set_duration(turns)
```

使用动态 bundle 前必须确认：

- effect key 在原版或自定义 `effects_tables` 中存在。
- scope 是有效 scope，并且原版有相似用法。
- value 正负符合 `is_positive_value_good`。

### 开局军队小改

若只需要在新战役调整某个派系领袖的开局部队，优先考虑 `script/campaign/mod/<prefix>_<feature>.lua` 的 First Tick 小脚本，避免直接覆盖 startpos `[已查原版脚本 / 需游戏内复查]`：

```lua
cm:add_first_tick_callback(function()
    if cm:is_new_game() and not cm:get_saved_value("custom_starting_army_adjusted") then
        local faction = cm:get_faction("faction_key")
        if faction and not faction:is_null_interface() and not faction:is_dead() then
            local leader = faction:faction_leader()
            local lookup = cm:char_lookup_str(leader)
            cm:remove_unit_from_character(lookup, "old_main_unit_key")
            cm:grant_unit_to_character(lookup, "new_main_unit_key")
            cm:set_saved_value("custom_starting_army_adjusted", true)
        end
    end
end)
```

本地官方脚本文档说明：`cm:remove_unit_from_character` 会移除目标角色军队中第一个匹配的 `main_units`；`cm:grant_unit_to_character` 会在军队有空位时创建并加入指定单位。

### 用首回合 Dilemma 替代 startpos 开局改动

如果主菜单初始军队兵牌可以保持原版，只要求玩家进战役后选择奖励，优先用 Lua 首回合 dilemma，避免覆盖 `startpos.esf` `[已查原版脚本 / 实测需随版本复查]`。

最小链路：

1. 在 `dilemmas_tables` 新建 dilemma key，`generate=false`，用 Loc 补 `dilemmas_localised_title_<dilemma_key>` 与 `dilemmas_localised_description_<dilemma_key>`。
2. 在 `cdir_events_dilemma_choice_details_tables` 为该 dilemma 添加 `FIRST`、`SECOND` 等原版全局 choice key；按钮文本用 `cdir_events_dilemma_choice_details_localised_choice_label_<dilemma_key><CHOICE>` 与 `...choice_title_<dilemma_key><CHOICE>`。
3. 在 `cdir_events_dilemma_option_junctions_tables` 添加最小目标/条件行，例如 `GEN_TARGET_NONE` + `default`，具体条件按目标事件查原版同类。
4. 在 Lua `cm:add_first_tick_callback` 中注册 `DilemmaChoiceMadeEvent` 监听器，再在 `cm:is_new_game()` 且目标派系为人类时用 `cm:create_dilemma_builder`、`cm:create_payload`、`payload_builder:text_display`、`cm:launch_custom_dilemma_from_builder` 触发。
5. 用 saved value 分别记录“已触发”和“已结算”，避免新战役首帧、读档或异常重复触发/重复发奖。

奖励如果需要精确操作角色军队，通常由 `DilemmaChoiceMadeEvent` 回调执行 `cm:grant_unit_to_character`、`cm:treasury_mod` 等；payload 可只负责 UI 奖励预览，Loc key 为 `campaign_payload_ui_details_description_<payload_text_key>`。

### Dilemma 选项分支兜底

`DilemmaChoiceMadeEvent` 监听器中，若只处理 `SECOND` 而不处理 `FIRST`，且后续 `if/elseif` 链存在默认分支（例如 `elseif 1 == 1 then`），未处理的选项会被默认分支捕获。例如 PSW 25 回合祈愿选择里 `FIRST`（祈愿天赋）未处理，导致后续抽奖默认进入“唯一物品抽奖”。

处理多选弹窗时，应：
- 每个 choice 都显式处理或显式清理对立状态；
- 默认分支尽量不包含会覆盖未处理选项的全局逻辑；
- 若用 effect bundle 作为状态标记，未选中项应及时 `cm:remove_effect_bundle` 移除对立 bundle。

`[实测/需随版本复查]`

### 抹除派系（灭国）

`cm:kill_faction` **不存在**——原版脚本里的 `kill_faction()` 只是 wh3_tol 剧本的全局辅助函数。脚本层灭派系的正确组合（与原版实现等价）`[实测/需随版本复查]`：

```lua
-- 1. 先与所有交战方议和，避免清理中触发战斗
local enemies = faction:factions_at_war_with()
for i = 0, enemies:num_items() - 1 do
    local enemy = enemies:item_at(i)
    if enemy and not enemy:is_null_interface() and not enemy:is_dead() then
        cm:force_make_peace(faction:name(), enemy:name())
    end
end

-- 2. 杀光所有军队（连带销毁军队对象）
cm:kill_all_armies_for_faction(faction)

-- 3. 放弃全部城镇（无城无军的派系随即灭亡）
local region_list = faction:region_list()
for i = 0, region_list:num_items() - 1 do
    cm:set_region_abandoned(region_list:item_at(i):name())
end

-- 4. 清理残余无军队人物；cm:kill_character 原版只传 2 参
local char_list = faction:character_list()
for i = 0, char_list:num_items() - 1 do
    local char = char_list:item_at(i)
    if not char:is_null_interface() and not char:is_wounded() then
        cm:kill_character(char:command_queue_index(), true)
    end
end

-- 5. 锁死外交防复活/附庸拉尸
cm:force_diplomacy("faction:" .. faction:name(), "all", "all", false, false, true)
```

用途边界：这是解决“某派系回合内存在坏原生对象导致 `0xC0000005` 崩溃”的最终手段——Lua 的 `pcall` 拦不住原生访问冲突，阻止该派系战斗（议和/锁宣战）也不够，因为回合内对军队对象的其他处理仍会触发；只有销毁对象本体才有效。副作用是该派系从战役中永久消失。

### 存档值

```lua
local value = cm:get_saved_value("custom_example_feature_counter") or 0
cm:set_saved_value("custom_example_feature_counter", value + 1)
```

规则：

- saved value key 使用项目唯一前缀 + module + state；本模板示例为 `custom_`。
- 读取值必须处理 `nil`。
- 存 table/复杂结构前先查项目已验证序列化方法；不要假设所有 Lua table 都安全。

### 延迟回调

```lua
cm:callback(function()
    out("delayed call")
end, 0.2)
```

用于让 UI/model 状态稳定后再读，但不要用延迟回调掩盖 API 错误。
战役开局事件或 dilemma 如果会撞上新战役加载后的镜头动画，不要只在 First Tick 里直接 `cm:callback` 延迟；该延迟可能在加载/开场镜头阶段就被消耗。更稳妥的做法是 First Tick 注册 `PanelOpenedCampaign` 等 UI 已打开后的监听器，再从该监听器里 `cm:callback` 延迟数秒触发，并把延迟值做成本地常量 `[实测/需随版本复查]`。

## culture 与 subculture

WH3 派系检查通常使用 `subculture()`。不要把 subculture key 拿去和 `culture()` 比较。

```lua
local CATHAY_SUBCULTURE = "wh3_main_sc_cth_cathay"

local function is_cathay_faction(faction)
    return faction
        and not faction:is_null_interface()
        and faction:subculture() == CATHAY_SUBCULTURE
end
```

确认 key 类型：

```text
gamedata/db/cultures_tables/
gamedata/db/cultures_subcultures_tables/
gamedata/db/factions_tables/
```

## Lua 5.1 禁止语法

不要使用：

```lua
-- Lua 5.2+，WH3 Lua 5.1 不可用
goto continue
::continue::

-- Lua 5.3+，不可用
local x = a // b
local y = a ~ b
```

代替写法：

```lua
for _, item in ipairs(list) do
    if item then
        -- do work
    end
end
```

## 日志输出规范

```lua
local MODULE_KEY = "custom_example_feature"

local function log(message)
    out(MODULE_KEY .. ": " .. tostring(message))
end
```

建议输出点：

- 文件加载开始。
- First Tick 开始。
- 监听器注册完成。
- 条件函数关键判断。
- 回调执行。
- 关键 API 返回值。
- 错误分支。

## 原生崩溃与全局 hook 边界

- Lua `pcall`/`xpcall` 只能捕获 Lua 错误，不能捕获 `0xC0000005` 等原生访问冲突。若 `.mdmp`/stack 只有游戏本体与系统 DLL，应先定位最后一个 Lua→原生 API 边界，不要继续扩大 `pcall` 包装。
- `campaign_manager` 的包装函数可能先写日志、再调用 `game_interface`；日志最后停在 `force_add_trait()` 等输出，只能证明故障边界高度相关，不能单凭时间顺序证明 trait/effect 本身是唯一根因。
- 不要全局替换 `core.add_listener` 来保护单个 MOD。第三参数合法值包括函数和 `true`；包装器若只接受函数，会静默禁用所有 `condition=true` 的 listener。
- 如果不得不代理 listener，先执行无需调用原 condition 的排除条件，再调用原 condition；否则原 condition 中的原生 API 仍可能先崩溃。
- 直接写入全局 `events.<EventName>` 数组的原版回调不经过 `core:add_listener`，覆盖 `core.add_listener` 无法拦截这类调用。
- 不要全局替换 `cm.callback` 后丢弃第三个可选名称参数；命名 callback 依赖该参数执行后续取消。
- 已确认某个非必要原生调用稳定触发崩溃时，优先在该 API 的 Lua 包装层做“明确对象 + 明确条件”的窄范围调用前拦截，并保留玩家路径和其他调用；此类规避必须标注 `[实测/需随版本复查]`。

## UI 组件操作：Cco 绑定控件的脚本化

WH3 的 twui 控件常通过 `<callbacks_with_context>` 绑定 Cco（component context object），例如"技能"页签的"自动分配技能点数"复选框 `checkbox_auto_management`：

```xml
<callback_with_context callback_id="ContextCommandLeftClick"
    context_object_id="CcoCampaignCharacterAutoManagement"
    context_function_id="ToggleAutoManaging"/>
<callback_with_context callback_id="ContextCommandGiverOnContextSet"
    context_object_id="CcoCampaignCharacterAutoManagement"
    context_function_id="self.SetSelected(this.IsAutoManaging)"/>
```

要点：

- 勾选状态由引擎按角色持久化（`IsAutoManaging`），**改 twui 文件改变不了默认值**——状态不在 UI 层。
- Lua 改状态的可靠方式：`find_uicomponent` 找到控件 → `uic:CurrentState()` 读状态 → `uic:SimulateLClick()` 模拟点击（触发 ContextCommand，等价于玩家点击；vanilla `wh_campaign_interventions.lua` 同款用法）。
- 另一条路：`uic:GetContextObject("CcoXxx")` 拿到 context object 后 `:Call("IsAutoManaging")`/`:Call("ToggleAutoManaging")` 直接读写，绕过 UI 状态；context 类型与可用函数查 `gamedata/ui/metadata.json` `[需验证]`。
- `PanelOpenedCampaign` 的 `context.string` 是布局名，注意 `character_panel` 与 `character_details_panel` 两种写法都出现过，监听时两者都要兼容；兜底方案是 `ComponentLClickUp` 上挂"面板是否已打开"条件 + `cm:callback` 延迟 0.1s 检查——打开面板的点击触发后回调执行时面板已建好。
- `SimulateLClick` 会再次触发 `ComponentLClickUp`，监听器内必须做幂等检查（已勾选就不再点），避免自激循环。

## 常见错误对照

| 错误 | 后果 | 修正 |
|---|---|---|
| `core:add_listener(name,event,cond,true)` | 第 4 参数错误，脚本报错或监听器无效 | 补 callback_fn，第 5 参数才是 persistent |
| 用 `add_first_tick_callback_new` 注册长期监听器 | 读档后监听器不存在 | 用 `add_first_tick_callback` |
| 顶层访问 `cm:get_faction()` 并立即操作对象 | 初始化时机不稳定 | 放 First Tick |
| `faction:is_dead()` 前未判空 | nil/null interface 报错 | 先检查 `faction` 和 `is_null_interface()` |
| 使用 `goto`/`continue` | Lua 5.1 语法失败 | 改 if/else |
| `out("value=" .. value)` 但 value 是 nil/userdata | 拼接报错 | 用 `tostring(value)` |

## 生成代码前 grep 清单

- [ ] 事件名是否在原版脚本或文档中存在。
- [ ] API 函数名和参数是否正确。
- [ ] context 是否拥有所调用接口。
- [ ] effect/bundle key 是否存在。
- [ ] faction/subculture/culture key 是否来自原版表。
- [ ] `out()` 是否能定位到模块。

## 战斗脚本（battle scope）实测记录 `[实测/需随版本复查]`

托管/自动施法相关（实现见 `zzz_czx_battle_ui` 的 `czx_battle_auto_ability.lua`）：

- `unit:is_ai_controlled()`：识别"托管"单位（AI General 把单位交给 `script_ai_planner` 后此项为真）。CA planner 只下移动/攻击指令，**从不放技能**。
- `su.uc:perform_special_ability(key, target)`：目标参数**必填**，自放/光环也传 `unit` 自身（CA benchmark 用法）。`perform_special_ability_ground(key, position)` 走地面目标。
- `owned_non_passive_special_abilities()` 可能返回 uc 不支持的 key，`can_perform_special_ability` 不可靠 → 首次报 `does not support this special ability` 后把 (unit,ability) 永久拉黑，否则脚本错误刷屏本身就是卡顿源。
- **任何 uc 指令都会隐式夺取单位控制权**；`release_control()` 把单位还给"玩家/AI"，不是还给 planner。没下指令时调 release = 制造控制振荡（发呆/乱激活的根源之一）。
- 单位分类：`ammo_left() ~= 0`（含 -1 无限弹药）= 有远程武器；`missile_range()`、`has_attribute("shoot_disabled")` 可用。
- 行为开关：`uc:change_behaviour_active("defend", true)` = 原版 guard mode（不追击）；合法值含 "defend"/"fire_at_will"/"skirmish" 等。前置 `unit:can_use_behaviour(name)` 判定。
- 移动指令：`uc:goto_location_angle_width(pos, bearing_deg, width, run)`，bearing 是**角度制**（`unit:bearing()` 返回弧度需乘 180/pi），width 用 `unit:ordered_width()`。
- 敌我距离：`a:position():distance_xz(b:position())`。
- 冗余脚本包教训：`script/battle/mod/` 下不同文件名的旧版脚本会**同时运行**（同路径才去重）——旧 `czx_auto_skill_manage.lua` 与新脚本并行导致双重抢权，是"乱激活"的确认原因之一。改包部署时必须同时清理 playset 里的旧条目与 data\ 旧文件。
- Mod Manager `local:data:` mod_id = `sha256(path.resolve() 转正斜杠转小写)[:18]`（源码 `backend/scanner.py::_path_fingerprint`），同文件名覆盖部署无需改 playset。

入口/对象形态（对照 `gamedata/script/_lib` 原版源码确认，未上机 `[需验证]`）：

- **`bm` 是 battle 全局**（lib 加载时 `battle_manager:new()` 创建并 `core:add_static_object`）；WH3 没有 `get_bm()`——lib dump 只有 campaign 的 `get_cm()`（`lib_campaign_manager.lua`）。入口写法照 czx_bridge：`if not bm then return end`；`local bm = get_bm()` 会在加载即报错。
- **`script_unit` 的 `name`/`unit`/`uc` 是字段不是方法**（`lib_battle_script_unit.lua` 文档标 `@variable`）：`su.name` 为唯一键（`set_name` 在 `new_impl` 必填，格式 `unique_ui_id[:unit_ref]`）；`su.unit` = battle_unit 接口；`su.uc` = unitcontroller。`su:name()` 是"调用字符串"必报错。
- `bm` 经 `set_object_class(bm, battle_manager, b)` 双挂 Lua 层方法与引擎 `empire_battle` 对象方法——`bm:battle_type()` 这类调用走引擎侧，lib dump 查不到属正常。
- 已确认存在：`bm:repeat_callback(cb, ms, name)`、`bm:callback(cb, ms, name)`、`su:halt()/release_control()/take_control()`（均包装 `self.uc:*`）、`army:is_player_controlled()`、`unit:unique_ui_id()`。
- **单位枚举唯一正确路径**（`lib_battle_manager.lua` `build_scriptunits`）：`bm:num_alliances()` → `bm:num_armies_in_alliance(al)` → `bm:get_scriptunits_for_army(al, ar)`；增援军：`bm:num_reinforcing_armies_for_army_in_alliance(al, ar)` → `bm:get_scriptunits_for_army(al, ar, r)`。返回 Lua `script_units` 集合（`:count()`/`:item(i)`，**不是**引擎 `:num_items()`）；出错返回 `false` 不抛错。敌我：`bm:get_player_alliance_num()` 联盟序号比对。**`bm:armies()` 不存在**（局内实锤 `attempt to call method 'armies' (a nil value)`）。
- **`repeat_callback` 裸错 = 全脚本计时器瘫痪**：`timer_manager_battle_callback` 在 while 循环里派发回调，某回调抛错会在 singleshot 重武装前中断泵——**所有**脚本的计时器（含其他 mod）永久静默，游戏不报错只记 `RLH_battle_error_log.txt`/`script_log`。任何挂 `repeat_callback`/`callback` 的体必须 `pcall` 兜底。
- `out` 是可调用对象（table `__call`），`out(str)` 与 `bm:out(str)` 均可用。
- **2026-09-18 局内实测**（land_normal 野战，`czx_probe`）：`io.open` 读/写可用（游戏根目录相对路径可写文件）；`os.clock/os.time/os.date` 可用；`bm:battle_type()` 返回 `land_normal`；`bm:capture_location_manager()` 存在；**`bm:armies()` 不存在（nil value）**——枚举须走 `num_alliances → get_scriptunits_for_army`。
- **`out()` 落点**：游戏根目录 `script_log_DDMMYY_HHMM.txt`——每个游戏会话一个新文件自动滚动，mod 日志无需自己开文件（要结构化数据仍可 `io.open` 写游戏根目录）。

`script_ai_planner` 行为（`lib_battle_script_ai_planner.lua` 源码 + 2026-09-18 局内实测）：

- **无指令的 planner 会"漏"单位**：`script_ai_planner:new()` 后不给任何 order，引擎把单位陆续放回玩家控制（`is_ai_controlled→false`，实测 36→1 / ~3min）。必须挂常驻指令：`attack_unit(unit)`（进攻 doctrine）或 `defend_position(pos, radius)`（驻守 doctrine=原版"Defend this position"按钮同款，内部 `should_reorder` 自带 30s 重发循环）；`get_centre_point()` 返回 planner 群组中心 vector。
- `is_ai_controlled→false` 语义歧义：planner 自动放人与玩家 UI 收回**签名完全相同**（`is_player_controlled=true`），无法用标志位区分——需要逃逸计数/时间窗消抖，单次掉线应当 tick 补回。
- planner 持有的单位 `is_idle()` 常为 false（"驻守"也算有令在身）——`is_idle` 驱动的补刀逻辑对 planner 单位基本无效，别用它当"该发指令了"的判据。
- `planner:add_sunits(x)` 接受单 script_unit / scriptunits 集合 / script_unit 表；`planner:count()` 返回实有数。
- **跨 `_lib` 文件的全局捕获必须延迟解析**：`script/_lib/mod/` 按文件名字母序加载，`local X = CZX_Y` 在 Y 的注册文件之前执行则永久捕获 nil（实测 `czx_tc_assess` 的 `local Units = CZX_TC_UNITS` 全 tick 报错）。跨模块引用直接在函数内写 `CZX_Y.method()`。

### 引擎指令事件 / 热键 / 单位状态（AI General 源码 + exe 字符串实锤，[需验证]=待上机）

- **`bm:register_command_handler_callback(name, cb, cb_name)`**：UI 指令事件通道。exe 实锤指令名：`"Attack Unit"`、`"Move Orientation Width"`、`"Move Rotation Angle"`、`"Change Speed"`、`"Change Melee"`、`"Change Skirmish"`、`"Fire At Will"`、`"Special Ability"`、`"Attack Building"`、`"Change Formation"`、`"Shot Type"`、`"Double Click"`、`"Group Created"`、`"Battle Results"`、`"Unit Left Battlefield"`。context 访问器：`get_name()`/`get_unit()`/`get_string1()`/`get_position()`/`get_bool1()`/`get_building()`。
- **`"Special Ability"` 指令事件**：理论上是敌我施法检测源（dodge 的前提）——`get_unit()`=施法者，`get_string1()`/`get_position()`=技能键/落点 `[需验证]`。己方 uc 的 `perform_special_ability` 可能同样触发 → 用"指令是否发生在自方 tick 任务段内"标志位过滤。
- **玩家指令识别**：uc/planner 发的指令若也走指令事件管道，`get_unit()+is_ai_controlled()` 无法区分来源 `[需验证]`；可靠区分法=在自方下发指令的代码段内置标志（`in_task_pass`），事件到达时标志为 false 即玩家操作。
- **`"ShortcutTriggered"` + `context.string`**：引擎对每个已绑定快捷键发脚本事件，`context.string` 是动作名（AI General 用 `camera_bookmark_save0..6` = 相机书签保存键，游戏设置里可改绑）。拿来做 mod 热键最省事，不需要自定义 UI 组件。
- **当前选区读取**（AI General `for_each_accessible_unit_card`）：`find_uicomponent(core:get_ui_root(), "battle_orders", "cards_panel", "review_DY")` → 遍历子组件，`CallbackId()=="UnitCard"` 且 `CurrentState()` 含 `selected`；卡片 `Id()` == `unit:unique_ui_id()`。
- **`battle_manager_unit_selection_handler` 是全局函数**：引擎每次选中/取消选中单位时调用，包裹它即可获得选区变化回调（AI General `bm_ext` 做法；需先 `bm:register_unit_selection_handler` 保底注册）。
- **`planner:remove_sunits(x)`**：从 planner 移除单位并放回玩家控制（收回=移除+记名）；`planner:release()` 全军释放。
- **单位状态查询**（exe 字符串实锤存在）：`unit:unary_hitpoints()`（血量分数）、`unit:is_in_melee()`、`unit:is_moving()`/`is_moving_fast()`、`unit:number_of_men_alive()`/`initial_number_of_men()`、`unit:ordered_position()`。
- **AI General 交接模型**（社区验证的 UX）：热键"toggle 选区托管" + "临时 override"（单位闲置 N 秒后自动归还 AI）——玩家微操单位不用想着还回来，闲置即自动回托管。
