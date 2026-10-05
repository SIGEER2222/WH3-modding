-- PSW free repick override v2
-- 新版主 MOD 的重抽有两个卡口：
--   1. psw_main_repick 检查 free_repick_num/psw_main_gmsj 资源，不够直接 return
--   2. UI 按钮显示的数字就是 free_repick_num，归零后重抽可能不响应
-- 对策：重定义 psw_main_repick 为免费直抽 + 每回合把 free_repick_num 顶回 99
-- 用 first_tick 保证覆盖发生在所有 mod 脚本加载完之后，不依赖文件加载顺序

local _repick_topup = 99
local _max_ex_shangxian = 20
local _resonance_crystal_per_turn = 1
local _tfmw_progress_callback_delay = 5.5

local function _tfmw_progress_value()
    local global_data = psw_main_data and psw_main_data.global_data
    local mowang_key = psw_mowang_data and psw_mowang_data.mowang_faction_key
    local mowang_data = mowang_key and psw_mowang_data[mowang_key]
    if not global_data or not mowang_data then
        return nil
    end
    return mowang_data.progress
end

local function _advance_tfmw_progress_once(start_progress, turn_number)
    local global_data = psw_main_data and psw_main_data.global_data
    if not global_data or not global_data.tfmw_is_start
        or global_data.set_tfmw_end
        or global_data.set_mowang_progress_hh
    then
        return
    end

    local current_progress = _tfmw_progress_value()
    -- The original delayed callback may already have advanced the value but
    -- failed before setting its guard flag. Treat that as this turn's advance.
    if start_progress ~= nil and current_progress ~= nil
        and current_progress > start_progress
    then
        global_data.set_mowang_progress_hh = true
        return
    end

    if type(psw_main_mowang_progress_change_effect) ~= "function" then
        out("[psw_repick] WARN: tfmw progress function is unavailable")
        return
    end

    local before = current_progress
    local ok, err = pcall(psw_main_mowang_progress_change_effect, 1)
    local after = _tfmw_progress_value()
    if after ~= nil and before ~= nil and after > before then
        global_data.set_mowang_progress_hh = true
        out("[psw_repick] tfmw progress advanced at turn "
            .. tostring(turn_number) .. " to " .. tostring(after))
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

cm:add_first_tick_callback(function()
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
            local ok, err = pcall(_orig_pickup, faction_name)
            d.ex_count, d.nor_count = e, n
            d.jishu_ex_count = -99  -- 选牌分支还要再看这个数，也保持解锁
            if not ok then
                out("[psw_repick] pickup error: " .. tostring(err))
            end
        end

        psw_main_repick = function(faction_name)
            if not psw_main_data or not psw_main_data.player_data
                or not psw_main_data.player_data[faction_name] then
                return
            end
            psw_main_data.player_data[faction_name].free_repick_num = _repick_topup
            psw_main_pickup(faction_name)
        end
        out("[psw_repick] free repick override installed")
    else
        out("[psw_repick] psw_main_pickup not found, skipping override")
    end

    _repick_topup_all()
    core:add_listener(
        "psw_repick_topup",
        "FactionTurnStart",
        function(context)
            local f = context:faction()
            return f and not f:is_null_interface() and f:is_human()
        end,
        function(context)
            local turn_number = cm:turn_number()
            local start_progress = _tfmw_progress_value()
            -- 接上原作者漏接线的每回合水晶 +1（DB 里有 huihe 因子但从未调用）
            cm:faction_add_pooled_resource(
                context:faction():name(),
                "psw_main_gmsj",
                "psw_main_gmsj_huihe_get_good",
                _resonance_crystal_per_turn)
            _repick_topup_all()
            -- Keep the original five-second turn routine intact. This delayed
            -- fallback only fills the progress gap if that routine is absent
            -- or errors before setting its once-per-turn guard.
            cm:callback(function()
                _advance_tfmw_progress_once(start_progress, turn_number)
            end, _tfmw_progress_callback_delay)
        end,
        true
    )

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

    -- A loaded save can retain the original guard from the previous session.
    -- The next FactionTurnStart must be allowed to advance normally.
    if psw_main_data and psw_main_data.global_data then
        psw_main_data.global_data.set_mowang_progress_hh = false
    end
end)
