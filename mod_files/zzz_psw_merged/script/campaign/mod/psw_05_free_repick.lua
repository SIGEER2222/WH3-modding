-- PSW free repick override v3
-- 新版主 MOD 的重抽有两个卡口：
--   1. psw_main_repick 检查 free_repick_num/psw_main_gmsj 资源，不够直接 return
--   2. UI 按钮显示的数字就是 free_repick_num，归零后重抽可能不响应
-- 对策：重定义 psw_main_repick 为免费直抽 + 每回合把 free_repick_num 顶回 99
-- 用 first_tick 保证覆盖发生在所有 mod 脚本加载完之后，不依赖文件加载顺序
--
-- v4（2026-10-06）：补回祈愿水晶的独立回合/战斗入账入口。原版这两条
-- listener 依赖长 first-tick 初始化链，读档时可能静默未注册；战斗入口
-- 还会被旧存档里的 15 点上限卡住。安全适配器带余额校验、去重和重试。
--
-- v3（2026-10-06）：共鸣水晶每回合 +1 与讨伐进度兜底从 first_tick 内注册改为
-- 文件顶层注册。v2 实测（存档资源账本 + script log）：first_tick 内注册的
-- FactionTurnStart 监听器从未产生效果——水晶 huihe 因子 0 到账、讨伐进度
-- 卡在初始值、无任何 psw_repick 回合日志；而同为文件顶层注册的
-- talent_state_export 监听器每回合正常触发。v3 改动：
--   1. 顶层注册 FactionTurnStart/FactionTurnEnd 监听器，不依赖 first_tick 存活
--   2. 水晶发放带余额回读校验；直加无效（回合切换上下文被引擎吞）时延迟 2 秒重试
--   3. 讨伐进度改为回合开始直接推进（guard 防重复，Lua 表写入不经过引擎资源）
--   4. 全部外部调用 pcall 包裹并输出日志，便于下次实测定位

local _repick_topup = 99
local _max_ex_shangxian = 20
local _resonance_crystal_per_turn = 1
local _qysj_battle_cap_per_turn = 15
local _qysj_turn_marker_prefix = "czx_psw_qysj_turn_done_"
local _qysj_battle_turn_prefix = "czx_psw_qysj_battle_turn_"
local _qysj_battle_used_prefix = "czx_psw_qysj_battle_used_"
local _qysj_battle_last_prefix = "czx_psw_qysj_battle_last_"

local function _tfmw_progress_value()
    local global_data = psw_main_data and psw_main_data.global_data
    local mowang_key = psw_mowang_data and psw_mowang_data.mowang_faction_key
    local mowang_data = mowang_key and psw_mowang_data[mowang_key]
    if not global_data or not mowang_data then
        return nil
    end
    return mowang_data.progress
end

local function _read_qysj(faction_name)
    local ok, value = pcall(function()
        local faction = cm:get_faction(faction_name)
        if not faction or faction:is_null_interface() then
            return nil
        end
        return faction:pooled_resource_manager()
            :resource("psw_main_qysj"):value()
    end)
    if ok and type(value) == "number" then
        return value
    end
    return nil
end

local function _current_battle_key()
    local ok, key = pcall(function()
        local attacker_cqi, _, attacker_name =
            cm:pending_battle_cache_get_attacker(1)
        local defender_cqi, _, defender_name =
            cm:pending_battle_cache_get_defender(1)
        local pending_battle = cm:model():pending_battle()
        return tostring(cm:turn_number())
            .. ":" .. tostring(attacker_cqi)
            .. ":" .. tostring(defender_cqi)
            .. ":" .. tostring(attacker_name)
            .. ":" .. tostring(defender_name)
            .. ":" .. tostring(pending_battle:attacker_battle_result())
            .. ":" .. tostring(pending_battle:defender_battle_result())
    end)
    return ok and key or nil
end

-- All fallback and legacy PSW paths use this adapter so a successful qysj
-- grant is observable and the two listeners cannot pay the same turn twice.
function czx_psw_add_qysj(
    faction_name,
    amount,
    factor,
    reason,
    marker_key,
    on_success,
    can_attempt
)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        return false
    end

    local turn = cm:turn_number()
    if marker_key and cm:get_saved_value(marker_key) == turn then
        out("[psw_repick] qysj duplicate skipped: " .. tostring(reason)
            .. ", faction=" .. tostring(faction_name)
            .. ", turn=" .. tostring(turn))
        return true
    end

    local function attempt()
        if can_attempt and not can_attempt() then
            return true
        end
        if marker_key and cm:get_saved_value(marker_key) == turn then
            return true
        end

        local before = _read_qysj(faction_name)
        local call_ok, call_error = pcall(function()
            cm:faction_add_pooled_resource(
                faction_name,
                "psw_main_qysj",
                factor,
                amount)
        end)
        local after = _read_qysj(faction_name)
        local confirmed = call_ok and before ~= nil and after ~= nil and after > before

        if confirmed then
            if marker_key then
                cm:set_saved_value(marker_key, turn)
            end
            out("[psw_repick] qysj +" .. tostring(amount) .. " ok: "
                .. tostring(reason) .. ", factor=" .. tostring(factor)
                .. ", balance=" .. tostring(before) .. "->" .. tostring(after))
            if on_success then
                local callback_ok, callback_error = pcall(on_success)
                if not callback_ok then
                    out("[psw_repick] qysj success callback error: "
                        .. tostring(callback_error))
                end
            end
            return true
        end

        if not call_ok then
            out("[psw_repick] qysj add error: " .. tostring(reason)
                .. ", error=" .. tostring(call_error))
        else
            out("[psw_repick] qysj add no change: " .. tostring(reason)
                .. ", balance=" .. tostring(before) .. "->" .. tostring(after))
        end
        return false
    end

    if attempt() then
        return true
    end

    cm:callback(function()
        attempt()
    end, 2)
    return false
end

local function _grant_turn_qysj(faction_name, reason)
    local player_data = psw_main_data
        and psw_main_data.player_data
        and psw_main_data.player_data[faction_name]
    local amount = player_data and tonumber(player_data.qysj_turn_num) or 0
    if amount <= 0 then
        out("[psw_repick] qysj turn reward is zero: faction="
            .. tostring(faction_name))
        return
    end

    czx_psw_add_qysj(
        faction_name,
        amount,
        "psw_main_qysj_huihe_get_good",
        reason,
        _qysj_turn_marker_prefix .. faction_name)
end

---读当前派系共鸣水晶余额；取不到（接口/资源缺失）返回 nil
local function _read_gmsj(faction_name)
    local ok, value = pcall(function()
        return cm:get_faction(faction_name)
            :pooled_resource_manager():resource("psw_main_gmsj"):value()
    end)
    if ok and type(value) == "number" then
        return value
    end
    return nil
end

---加 1 个共鸣水晶并回读校验；返回是否确认到账
local function _add_gmsj_once(faction_name)
    local before = _read_gmsj(faction_name)
    local ok, err = pcall(function()
        cm:faction_add_pooled_resource(
            faction_name,
            "psw_main_gmsj",
            "psw_main_gmsj_huihe_get_good",
            _resonance_crystal_per_turn)
    end)
    local after = _read_gmsj(faction_name)
    if not ok then
        out("[psw_repick] gmsj add error: " .. tostring(err))
        return false
    end
    if before ~= nil and after ~= nil and after > before then
        out("[psw_repick] gmsj +" .. _resonance_crystal_per_turn
            .. " ok (" .. before .. "->" .. after .. ")")
        return true
    end
    out("[psw_repick] gmsj add no change ("
        .. tostring(before) .. "->" .. tostring(after) .. ")")
    return false
end

---讨伐进度推进一次（guard 防重复；成功后置 guard，与原版 5 秒链互斥）
local function _advance_tfmw_progress_once(reason)
    local global_data = psw_main_data and psw_main_data.global_data
    if not global_data or not global_data.tfmw_is_start
        or global_data.set_tfmw_end
        or global_data.set_mowang_progress_hh
    then
        return
    end
    if type(psw_main_mowang_progress_change_effect) ~= "function" then
        out("[psw_repick] WARN: tfmw progress function is unavailable")
        return
    end
    local before = _tfmw_progress_value()
    local ok, err = pcall(psw_main_mowang_progress_change_effect, 1)
    local after = _tfmw_progress_value()
    if ok and after ~= nil and before ~= nil and after > before then
        global_data.set_mowang_progress_hh = true
        out("[psw_repick] tfmw progress advanced (" .. reason .. ") to "
            .. tostring(after))
    elseif not ok then
        out("[psw_repick] tfmw progress fallback error: " .. tostring(err))
    end
end

local function _apply_ex_shangxian_bundles(faction_name)
    local faction = cm:get_faction(faction_name)
    if not faction then return end
    for i = 1, _max_ex_shangxian do
        local key = "set_ex_shangxian_" .. i
        if not faction:has_effect_bundle(key) then
            cm:apply_effect_bundle(key, faction_name, 0)
        end
    end
    -- 同时挂上原始标记 bundle（部分分支会检测它）
    if not faction:has_effect_bundle("set_ex_shangxian") then
        cm:apply_effect_bundle("set_ex_shangxian", faction_name, 0)
    end
end

local function _repick_topup_all()
    if not psw_main_data or not psw_main_data.player_data then
        return
    end
    for faction_name, d in pairs(psw_main_data.player_data) do
        if type(d) == "table" then
            d.free_repick_num = _repick_topup
            d.repick_cost = 0
            -- 唯一天赋上限直接开到最大（jishu_ex_count 只要<=1就能继续选）
            d.jishu_ex_count = -99
            d.ex_limit_count = _max_ex_shangxian
            _apply_ex_shangxian_bundles(faction_name)
        end
    end
end

-- 重抽覆盖：必须在 first_tick（等主 MOD 的 psw_main_pickup 定义完成）
cm:add_first_tick_callback(function()
    local ok, err = pcall(function()
        if type(psw_main_pickup) == "function" then
            -- 绕过 psw_main_pickup 里的 final_tf_count >= 13 天赋总数上限：
            -- 调用期间临时把 ex_count/nor_count 归零，结束后还原
            local _orig_pickup = psw_main_pickup
            psw_main_pickup = function(faction_name)
                local d = psw_main_data and psw_main_data.player_data
                    and psw_main_data.player_data[faction_name]
                if not d then
                    return _orig_pickup(faction_name)
                end
                -- 解锁：总上限、EX 上限在原生 pickup 读取时暂时归零，让抽卡过程无限制
                local e, n = d.ex_count, d.nor_count
                d.ex_count, d.nor_count = 0, 0
                d.jishu_ex_count = -99
                local ok_pickup, err_pickup = pcall(_orig_pickup, faction_name)
                d.ex_count, d.nor_count = e, n
                d.jishu_ex_count = -99  -- 选牌分支还要再看这个数，也保持解锁
                if not ok_pickup then
                    out("[psw_repick] pickup error: " .. tostring(err_pickup))
                end
            end

            psw_main_repick = function(faction_name)
                if not psw_main_data or not psw_main_data.player_data
                    or not psw_main_data.player_data[faction_name] then
                    return
                end
                psw_main_data.player_data[faction_name].free_repick_num = _repick_topup
                psw_main_data.player_data[faction_name].psw_repick_in_progress = true
                local _ok_repick, _err_repick = pcall(psw_main_pickup, faction_name)
                psw_main_data.player_data[faction_name].psw_repick_in_progress = nil
                if not _ok_repick then
                    out("[psw_repick] repick error: " .. tostring(_err_repick))
                end
            end
            out("[psw_repick] free repick override installed")
        else
            out("[psw_repick] psw_main_pickup not found, skipping override")
        end

        _repick_topup_all()
    end)
    if not ok then
        out("[psw_repick] first_tick setup error: " .. tostring(err))
    end

    -- 读档会保留上一会话的 guard；复位保证下一个回合开始能正常推进
    if psw_main_data and psw_main_data.global_data then
        psw_main_data.global_data.set_mowang_progress_hh = false
    end
end)

local function _get_battle_qysj_state(faction_name, turn)
    local saved_turn = tonumber(cm:get_saved_value(
        _qysj_battle_turn_prefix .. faction_name))
    if saved_turn ~= turn then
        return 0, nil
    end

    local used = math.max(0, tonumber(cm:get_saved_value(
        _qysj_battle_used_prefix .. faction_name)) or 0)
    local last_battle = cm:get_saved_value(_qysj_battle_last_prefix .. faction_name)
    return used, last_battle
end

-- 独立战斗奖励入口。不要依赖原版 psw_main_battle_effect 的旧存档计数，
-- 也不要把 Lua table 写进 saved value；旧档可能把 battle_qysj_num 留在 15。
function czx_psw_grant_battle_qysj(faction_name, add_num, reason)
    local amount = math.floor(tonumber(add_num) or 0)
    if amount <= 0 then
        return false
    end

    local turn = cm:turn_number()
    local used, last_battle = _get_battle_qysj_state(faction_name, turn)
    local battle_key = _current_battle_key()
    if battle_key and last_battle == battle_key then
        out("[psw_repick] qysj battle duplicate skipped: faction="
            .. tostring(faction_name))
        return true
    end

    local available = math.max(0, _qysj_battle_cap_per_turn - used)
    amount = math.min(amount, available)
    if amount <= 0 then
        out("[psw_repick] qysj battle cap reached: faction="
            .. tostring(faction_name) .. ", turn=" .. tostring(turn))
        return false
    end

    local function commit_battle_state()
        cm:set_saved_value(_qysj_battle_turn_prefix .. faction_name, turn)
        cm:set_saved_value(_qysj_battle_used_prefix .. faction_name, used + amount)
        if battle_key then
            cm:set_saved_value(_qysj_battle_last_prefix .. faction_name, battle_key)
        end

        local player_data = psw_main_data
            and psw_main_data.player_data
            and psw_main_data.player_data[faction_name]
        if player_data then
            player_data.battle_qysj_num = used + amount
        end
    end

    return czx_psw_add_qysj(
        faction_name,
        amount,
        "psw_main_qysj_battle_good",
        reason or "battle",
        nil,
        commit_battle_state,
        function()
            local _, current_last_battle = _get_battle_qysj_state(faction_name, turn)
            return not (battle_key and current_last_battle == battle_key)
        end)
end

local function _install_qysj_battle_override()
    if type(psw_main_battle_effect) ~= "function" then
        out("[psw_repick] qysj battle override skipped: base function missing")
        return
    end

    psw_main_battle_effect = function(faction_name, add_num)
        czx_psw_grant_battle_qysj(faction_name, add_num, "override")
    end

    out("[psw_repick] qysj battle override installed")
end

-- The base function is defined by the original PSW pack later in the load
-- list, so replace it after all first-tick script loading has completed.
cm:add_first_tick_callback(_install_qysj_battle_override)

-- 顶层注册：不依赖 first_tick 存活（talent_state_export 同款模式，实测每回合触发）
core:remove_listener("psw_repick_topup")
core:add_listener(
    "psw_repick_topup",
    "FactionTurnStart",
    function(context)
        local f = context:faction()
        return f and not f:is_null_interface() and f:is_human()
    end,
    function(context)
        local faction_name = context:faction():name()
        local turn_number = cm:turn_number()

        -- 讨伐进度：回合开始直接推进（Lua 表写入，guard 防与原版 5 秒链重复）
        _advance_tfmw_progress_once("turn " .. turn_number .. " start")

        -- 共鸣水晶：先直加；余额回读无变化（可能被回合切换上下文吞）则 2 秒后重试
        if not _add_gmsj_once(faction_name) then
            cm:callback(function()
                _add_gmsj_once(faction_name)
            end, 2)
        end

        -- 重抽次数顶满（Lua 表写入）
        pcall(_repick_topup_all)
    end,
    true
)

-- 独立回合奖励入口：即使原版 PSW 初始化链中途失败，也保证 qysj_turn_num
-- 能在玩家回合到账；与原版延迟回调通过 marker 去重。
core:remove_listener("czx_psw_qysj_turn_fallback")
core:add_listener(
    "czx_psw_qysj_turn_fallback",
    "FactionTurnStart",
    function(context)
        local faction = context:faction()
        return faction and not faction:is_null_interface() and faction:is_human()
    end,
    function(context)
        local faction_name = context:faction():name()
        _grant_turn_qysj(faction_name, "fallback turn start")
    end,
    true
)

local function _is_battle_victory(result)
    return result == "heroic_victory"
        or result == "decisive_victory"
        or result == "close_victory"
        or result == "pyrrhic_victory"
end

-- Independent battle reward listener. The original listener has a long chain
-- of optional talent effects before reaching psw_main_battle_effect; one
-- exception there can suppress the crystal reward for the whole battle.
core:remove_listener("czx_psw_qysj_battle_fallback")
core:add_listener(
    "czx_psw_qysj_battle_fallback",
    "BattleCompleted",
    function()
        local ok, involved = pcall(function()
            return cm:pending_battle_cache_human_is_involved()
        end)
        return ok and involved == true
    end,
    function()
        local ok, err = pcall(function()
            local attacker_cqi, _, attacker_name =
                cm:pending_battle_cache_get_attacker(1)
            local defender_cqi, _, defender_name =
                cm:pending_battle_cache_get_defender(1)
            local attacker = cm:get_faction(attacker_name)
            local defender = cm:get_faction(defender_name)
            if not attacker or attacker:is_null_interface()
                or not defender or defender:is_null_interface()
            then
                return
            end

            local pending_battle = cm:model():pending_battle()
            local attacker_won =
                _is_battle_victory(pending_battle:attacker_battle_result())
            local defender_won =
                _is_battle_victory(pending_battle:defender_battle_result())
            local faction_name = nil
            local human_won = false

            if attacker:is_human() and not defender:is_human() then
                faction_name = attacker:name()
                human_won = attacker_won
            elseif defender:is_human() and not attacker:is_human() then
                faction_name = defender:name()
                human_won = defender_won
            end

            if not faction_name or not human_won then
                return
            end

            local unit_list = cm:pending_battle_cache_get_defender_units(1) or {}
            local add_num = math.floor(#unit_list / 2)
            out("[psw_repick] qysj battle fallback: faction="
                .. tostring(faction_name) .. ", add=" .. tostring(add_num)
                .. ", attacker_cqi=" .. tostring(attacker_cqi)
                .. ", defender_cqi=" .. tostring(defender_cqi))
            czx_psw_grant_battle_qysj(faction_name, add_num, "fallback")
        end)
        if not ok then
            out("[psw_repick] qysj battle fallback error: " .. tostring(err))
        end
    end,
    true
)

-- guard 的每回合复位：回合结束清掉，下一回合开始才允许再推进
core:remove_listener("psw_tfmw_progress_reset")
core:add_listener(
    "psw_tfmw_progress_reset",
    "FactionTurnEnd",
    function(context)
        local f = context:faction()
        return f and not f:is_null_interface() and f:is_human()
    end,
    function()
        if psw_main_data and psw_main_data.global_data then
            psw_main_data.global_data.set_mowang_progress_hh = false
        end
    end,
    true
)
