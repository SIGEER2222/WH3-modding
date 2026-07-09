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
