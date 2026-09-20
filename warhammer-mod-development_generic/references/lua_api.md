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

## 同名监听器与脚本加载顺序（补丁型 MOD 必读）

- `core:add_listener` 对同名监听器是**追加共存**而非覆盖（`lib_core.lua` 内部 `table.insert`），同名监听器按注册顺序依次触发；`core:remove_listener(name)` 会清掉**所有**同名监听器。
- 所有 pack 的 `script/` 文件按**文件路径字典序**全局统一加载（UTF-8 字节序：`!` 前缀最前，ASCII 次之，中文名靠后，`zzz_*` 最后），与 pack 在 playset 中的位置无关。同路径文件才被 pack 顺序遮蔽（靠前胜出）。
- 推论一：补丁包里的 `<ascii>_xxx.lua` 副本会**先于**主包的 `<中文名>.lua` 加载；若对方文件在文件作用域执行 `core:remove_listener("X") + add_listener("X",...)`，我们先注册的同名监听器会被**整个清掉**（死代码）。
- 推论二：同名全局函数以后定义者为准，中文名文件里的定义会盖掉 ASCII 名文件里的同名定义。
- 可靠覆盖手法：在补丁包里放一个 `zzz_*` 命名的文件，在 `cm:add_first_tick_callback` 里 `remove_listener + add_listener` 重新注册——`zzz_` 排序保证该回调在所有 `psw_*`/中文字符文件的 first-tick 之后执行，此时 remove 会把对方 first-tick 里注册的也一并清掉。
- 若不想移除对方监听器只想先执行：同名共存时先注册者先触发，可在先触发的回调里设置互斥标记（如 effect bundle 锁）让后触发者早退。`[实测 2026-09 / WH3]`

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

### 传送角色（cm:teleport_to）

`cm:teleport_to(cm:char_lookup_str(char), x, y)` 对**不在地图上带军的角色静默失效**——不报错、不移动，日志只写 `Teleporting [character_cqi:N] to [x, y]`。`faction:faction_leader()` 不保证可传送：派系领袖可能受伤休整、未带兵、或仅为嵌入其他军队的英雄形态 `[实测/需随版本复查]`。

传送前必须先确认目标可派遣，领袖不可用时回退到第一支在图军队：

```lua
local function char_deployable(char)
    return char and not char:is_null_interface() and not char:is_wounded()
        and not char:is_at_sea() and cm:char_is_general_with_army(char)
end

local function tp_commander(faction)
    local leader = faction:faction_leader()
    if char_deployable(leader) then return leader end
    local mf_list = faction:military_force_list()
    local fallback
    for i = 0, mf_list:num_items() - 1 do
        local force = mf_list:item_at(i)
        if not force:is_null_interface() and not force:is_armed_citizenry() and force:has_general() then
            local gen = force:general_character()
            if char_deployable(gen) then
                local ok, ft = pcall(function() return force:force_type():key() end)
                if ok and ft == "ARMY" then return gen
                elseif not fallback then fallback = gen end
            end
        end
    end
    return fallback
end
```

配套要点：

- "传送到目标旁"用 `cm:find_valid_spawn_location_for_character_from_character(faction_name, cm:char_lookup_str(target), true, radius)`；目标角色同样要先过 `char_deployable`，对存储的 cqi 用 `cm:get_character_by_cqi` 取不到时返回 `false`（不抛错）。
- 若提供"传送回原位置"，去程应记录**实际被传送者**的 `command_queue_index()`，回程按 cqi 找回同一角色（领袖可能已回图/换人），cqi 失效再回退 `tp_commander`。
- 排查"点了没反应"先看 `script_log_*.txt` 是否出现 `Teleporting` 行：有则分支已执行、只是目标 cqi 无军队；无则是 dilemma/监听器层面没走到。

### roster 单位不是角色：grant_unit_to_character 授军单位 `[实测/需随版本复查]`

`cm:grant_unit_to_character(cm:char_lookup_str(general), unit_key)` 把 `main_units` 单位直接塞进将领 roster。若该单位是 lord/hero 种姓（caste），它会以"指挥官级单位"参与战斗、可被指挥官限定类军队技能锁定，但**战役侧永远不是角色**：

- `unit:associated_character()` / `unit:unit_commander()` 返回 null 接口；没有 `family_member`，没有 `character_details`，`agent_subtypes` 表不需要（也不应）有对应条目。
- 典型实例：魔女 mod 的 `psw_tfmw_*_boss_*` 魔王单位（`psw_新BOSS.lua` 用 `grant_unit_to_character` 加进仪式军队）；日志表现为 `UnitCreated: unit=<key> ... -> no_commander`。
- 凡是按 `family_member_cqi` 建身份的系统（监狱收监、战-役桥接按 roster index 回填 fm）对这类单位解析失败，现象是"标记/击杀都正常但事后没抓到"。必须把它当单位处理：记录 `unit_key`，需要放回地图时用 `cm:grant_unit_to_character` 重新授予某支有空位军队的将领（roster `force:unit_list():num_items() < 20`）。
- 战役侧 `unit` 接口无法直接判断单位种姓；战斗侧 DB 标志（如 `unit_is_not_commander_class`）已在锁定阶段过滤，战役结果侧只需处理"精确目标匹配到 fm=0 单位"这一种情况，不要给普通兵种加 fm=0 桥接之外的特判。

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

### 过回合显示选项面板（end turn display options）`[实测/需随版本复查]`

战役 HUD 空格面板（spacebar options）里控制 AI 回合显示强度的组件树：

```text
settings_panel > camera_settings > dropdowns_list > {armies, heroes, fleets}
    每行: dropdown_<row>_speed（速度）/ dropdown_<row>_camera（镜头）
    下拉内: dy_selected_txt（当前值文本）+ popup_menu > popup_list > 选项行(含 row_tx 文本)
同级按钮组（ButtonGroupButton 单选作用范围）:
    apply_all / apply_allies / apply_current_faction / apply_enemies / apply_neutrals
面板整体绑原生回调 CampaignEndTurnDisplayOptions（非 Cco，状态不在 metadata.json）
```

- 速度档位 loc key：`end_turn_camera_settings_{off,low,medium,high,veryhigh,normal,fast,follow}` = 关闭/较低/中等/较高/战略/快速/最快/影片；镜头列共用同一组档位文本。
- 脚本化：`SimulateLClick` 点开下拉 → `popup_list` 的克隆行（排除模板 `row_example`）按 `row_tx:GetStateText()` 匹配目标档（如 "最快"/"Fastest"）再 `SimulateLClick`；先点 `apply_all` 把作用范围选成"全部派系"。参考实现 `mod_files/zzz_czx_fast_end_turn/`。
- 文本读取：`uic:GetStateText()` 返回 `(unparsed_text, source)`；子节点遍历 `uic:ChildCount()` + `UIComponent(uic:Find(i))`。
- 引擎 pref 运行时写入：`common.call_context_command("SetPrefAsBool('fast_forward_end_turns', true)")`（另有 SetPrefAsInt/SetPrefAsFloat）；`CcoCampaignPendingActionNotificationQueue.ToggleSupressNotificationType('<TYPE>', true)` 可抑制指定过回合通知（vanilla 用它压 `ALLIED_BUILDINGS_CONSTRUCTION_AVAILABLE`）。

### 地图轮廓选项面板（campaign spacebar options）`[实测/需随版本复查]`

战役地图右侧"轮廓/边界/额外信息"选项面板的组件树（twui 文件 `campaign_spacebar_options.twui.xml`，**运行时根组件 id 是 `campaign_space_bar_options`**，与布局名不同）：

```text
campaign_space_bar_options > background > options_list
    header_overlay（"轮廓"节头，含 checkbox 总开关）
    overlay_ownership / overlay_diplomatic_status / overlay_attitude / overlay_public_order /
    overlay_growth / overlay_winds_of_magic / overlay_climate_suitability / overlay_attrition /
    overlay_corruption（每行含 label + icon + radio_button，radio 绑 ButtonGroupButton）
    header_campaign_borders / campaign_border_mode_parent / header_filter ...
```

- 隐藏某行（"屏蔽所有者"）：`slot:SetVisible(false)`——原版序章 `wh3_prologue_kislev_expedition_start.lua` 同款用法；面板重开后组件可能重建，需挂 `ComponentLClickUp` 守卫重隐。
- 默认选中某轮廓：`radio_button` 子组件 `CurrentState()` 非 `selected*` 时 `SimulateLClick()`。
- `RegionFactionChangeEvent` 的 context **没有** `new_faction()`，新领主是 `context:region():owning_faction()`，旧领主是 `context:previous_faction()`（原版 `wh3_dlc27_nor_generic.lua`）。

### 给第三方 UI MOD 打 Lua 补丁的时序与技巧 `[实测/需随版本复查]`

以 `!ancillary_panel.pack`（工坊 3253398688，脚本 `xyz_ancillary_panel.lua`，面板 `ancillary_panel`）的补丁 `zzz_czx_ancillary_sell` 为例：

- **脚本加载顺序 = 文件名字母序，不是 playset 顺序**：`script/campaign/mod/*.lua` 全部合并后按文件名字典序加载（script_log 里 `czx_*.lua` 6.6s 先于 `xyz_ancillary_panel.lua` 8.7s）。`cm:add_first_tick_callback` 按注册顺序执行 → **补丁脚本文件名必须排序在被补丁脚本之后**（`zzz_` > `xyz_`），否则 first tick 时目标面板还没建。仍要套 retry 兜底：

  ```lua
  cm:add_first_tick_callback(function()
      local attempts = 0
      local function try_attach()
          attempts = attempts + 1
          local panel = find_uicomponent(core:get_ui_root(), "ancillary_panel")
          if panel and attach(panel) then return end
          if attempts < 240 then cm:callback(try_attach, 0.5) end
      end
      try_attach()
  end)
  ```

- **`xx_sets` 白名单过滤 hack**：xyz 面板列表绑定 `RecordList.Filter(... StringContains(xx_sets, Key + ", ") || xx_sets == "all" ...)`——`xx_sets` 本质是"key, " 连接的白名单串（原版用于套装搜索）。`common.set_context_value("xx_sets", owned_str)` 即可原生过滤出"只看已拥有"，与类别/稀有度/搜索条件按 AND 叠加、列表无间隙、计数自动正确。需注意：面板自身重置按钮会写 `xx_sets="all"`（重写回我们的串即可共存）；`search_set` 会写真套装串（检测外部写入后主动放开开关让位）。
- **枚举派系已拥有装备 key**：`cco("CcoCampaignFaction", faction_name):Call("AncillaryList.JoinString(AncillaryRecordContext.Key, ', ')")` 一句出串（JoinString/Filter 等列表方法可直接进 `Call` 表达式；原版 `wh3_campaign_magic_items.lua` 用 `Call("RecordList.Filter(...)")` 返回 Lua table 逐条取 `Call("Key")` 亦可兜底）。逐件校验用 `faction:ancillary_exists(key)`、`cm:model():world():characters_owning_ancillary(key):num_items()`（装备中）、`cco("CcoAncillaryRecord", key):Call("UniquenessScore")`。
- **出售/购买等模型改动**走 `CampaignUI.TriggerCampaignScriptEvent(cqi, "key:...")` + `UITrigger` 服务端监听，MP 安全；服务器端重新校验 `ancillary_exists`/装备中/UniquenessScore 再 `cm:force_remove_ancillary_from_faction` + `cm:treasury_mod`。
- 往 `button_list`（List LayoutEngine 网格）里 `CreateComponent` 一个 `square_medium_button_toggle` 即可加筛选开关；被补丁方的"重置全部按钮"循环会把我们的开关也 `SetState("active")`——开关逻辑每 tick 从 `CurrentState()` 读，不存独立 flag，自动保持一致。
- **`SetDockingPoint` + `SetDockOffset` 方向**：dock 点 1-9 = 3x3 九宫格（9=父组件右下角，角对角对齐）；**dock_offset 是屏幕方向**——右缘 dock 点（3/6/9）+X 会推出父组件外（不可见），要进父组件内部须用负 X；上缘 +Y 向内、下缘 +Y 向外（xyz 的 `xx_button_close` 就是 `docking=8 + offset(0,56)` 挂在面板下缘外 56px）。对照 twui 里 `ancillary_detail docking="Top Right" dock_offset="-30,65"`（负 X 收进面板）可验证。新增按钮贴着面板已有按钮排时，沿它的 dock 点用负 X 往内排，不要正 X 外推。
- **行内勾选框**：list_box 的行（`CcoAncillaryRecord<key>`）由 ContextList 绑定动态建/销，给行加子组件要用 100-250ms `RealTimeTrigger` 扫描补挂；`context.string` 只带被点组件 id（不冒泡到父），`UIComponent(context.component):Parent()` 取行 → `Id()` 得 key。双击检测无 wall-clock API——用 tick 计数做 600ms 窗口。
- 同类已知样例：`mod_files/zzz_czx_ancillary_sell/script/campaign/mod/zzz_czx_ancillary_sell.lua`。

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

### AI General III 扩展接口（aigeneral_iii_pancake 源码确认，2026-09-19）

工坊 2799316652，纯脚本 pack。要"在 AIG3 基础上做战斗 AI"不要另起炉灶——它暴露了完整 submod API，且 `script/battle/mod/` 按文件名字母序加载（`zzz_` 前缀保证排在 `aigeneral_iii_main.lua`/`jg77_*` 之后读到全局）：

- **`pan_aigeneral` 全局对象**：`ai_list`（script_unit[] 托管集）、`player_ai`（script_ai_planner 句柄）、`current_phase`（对照 `pan_util.NO_PHASE/PREBATTLE/DEPLOYMENT/DEPLOYED/MOCK_VICTORY_COUNTDOWN=5.5/VICTORY_COUNTDOWN/COMPLETE`）、`set_ai_enabled(ui_ids, bool)`、`add_to_ai`/`remove_from_ai`、`add_exclusion(_by_id)`/`clear_exclusion_by_id`、`get_config()`。
- **`modder_API_uc_manager`**（UC 仲裁层，多 mod 共存标准做法）：`register_mod(mod_key, release_cb)` → `claim_units(mod_key, ui_ids)`（抢占时自动回调旧持有方让位——AIG3 注册回调是 `set_ai_enabled(ids,false)`+`add_exclusion`，即被抢=退出托管且不再自动收回）→ `is_unit_claimed(uid)` 返回持有方 mod_key；`release_claims_without_callbacks`、`release_all_claims_without_callbacks_for_mod`。jg77_babysitter 就靠 `is_unit_claimed` 跳过 pancake 单位实现共存。
- **`requests_aigeneral_pancake`**：`register_additional_transformation(ability_key, orig_type, new_type[, cyclical_key, summon_key])` 注册自定义变身；`add_transformation_callback(key, fn(old_unit, new_unit))`。
- **lazy config 通道**：`common.filesystem_lookup("/script/pancake_lazy_config/aigeneral/", "*.lua")` 扫所有 pack——submod 放 `script/pancake_lazy_config/aigeneral/<名>.lua` 即可注入默认配置（优先级：默认值 < lazy config < MCT/file，MCT `option_which_config` 决定后两层谁生效）。
- **`bm:aigeneral_add_listener_for_selections(key, fn(unit, is_selected))`**：选区变化钩子（bm_ext 包裹 `battle_manager_unit_selection_handler` 实现）。
- **阶段界线**：`VictoryCountdown`（≥5.5）起 AIG3 `switch_from_ai_planner_to_unit_controllers()` 释放 planner、全军 UC 接管跑 chasing 脚本（`chasing_channel` 配置 `beta`=pancake 自制 2000 行追剿 / `current|original`=CA 原版）——submod 的 planner 级指令必须在此时停手，否则与 chasing 抢 UC。
- **AIG3 只 add_sunits 不挂常驻 planner 指令**——无指令 planner 的漏单位问题（见上节）在 AIG3 下同样存在；submod 补 `player_ai:attack_unit`/`defend_position` 常驻指令是有效增强（`zzz_czx_aig3_plus` 即此思路）。
- **claim 交接语义（源码确认）**：AIG3 每次 `setup_or_update_ai` 都对全部 `ai_list` 单位 `claim_units(this_mod_key, ...)`——`this_mod_key` 硬编码 `"aigeneral_pancake"`，所以**托管单位的 `is_unit_claimed(uid)` 返回 `"aigeneral_pancake"` 而非 nil**；submod 对 AIG3 单位调 `claim_units(自己的key, {uid})` 会同步触发 AIG3 注册的 release 回调 → `set_ai_enabled(ids,false)`+`add_exclusion_by_id`，单位当场移出 `ai_list`/planner 并被排除（不会再被自动收回）——这是干净的"摘出做专属微操"通道，摘出后 UC 逐单位指令不再与 planner 抢权。归还：`release_claims_without_callbacks({uid}, 自己key)` + `pan_aigeneral:set_ai_enabled({uid}, true, false)`（`add_to_ai` 内部自清 exclusion，无需手动 `clear_exclusion_by_id`；随后 `setup_or_update_ai` 自动重新 claim 回 `"aigeneral_pancake"`）。
- **摘出前必查**：`pan_aigeneral.units_overridden[uid]`（玩家 override 进行中勿抢）、`is_excluded_id(uid)`（玩家/其他 mod 主动排除的勿抢）、`is_unit_claimed(uid)` 非 nil 且非 `"aigeneral_pancake"` = 别家 mod 持有勿抢。routing 单位应归还（`is_routing()`）让 pending 流程在集结后自动重接。
- **摘出单位下单签名**（`lib_battle_script_unit.lua`/`lib_battle_patrol_manager.lua` 实证）：`su.uc:attack_unit(target_unit, bool, true)`、`su.uc:goto_location_angle_width(v(x,z), bearing度, ordered_width, run)`、术毕 `su.uc:release_control()`；引擎原生风筝行为 `su:change_behaviour_active("skirmish", true, true)`（先 `unit:can_use_behaviour("skirmish")` 探测）——拉扯微操能用引擎 behaviour 就别自写状态机。
