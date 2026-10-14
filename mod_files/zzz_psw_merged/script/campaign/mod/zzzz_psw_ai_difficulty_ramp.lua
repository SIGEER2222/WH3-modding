-- PSW AI stat ramp: keep the enemy buff floor growing with the campaign's
-- escalation counter (jishu_zhongmo), instead of only on player boss-fail
-- events. Stock behaviour lets a winning player out-scale the AI forever:
-- global_AI_atk_up/def_up feed both the per-army psw_tfmw_gongji_/fangyu_
-- bundle level and the recruit-time initial roll (psw_get_mowang_army_*),
-- so raising them lifts existing generals AND future recruits. Bundle level
-- caps at 50 inside psw_tfmw_AI_*_effect_apply; we stop pushing once the
-- global counter reaches RAMP_GLOBAL_CAP.

local RAMP_GLOBAL_CAP = 45
local BOOST_TURN = 10

local function psw_ramp_globals()
    return psw_main_data and psw_main_data.global_data
end

local function psw_ramp_active()
    local gd = psw_ramp_globals()
    if not (gd and gd.set_psw_main_nandu3) then
        return false
    end
    local start_turn = 10
    if gd.set_psw_tianqi_ms_start then
        start_turn = 2
    end
    return cm:turn_number() >= start_turn
end

local function psw_ramp_rate(zhongmo)
    local rate = math.floor((zhongmo or 0) / 30)
    if rate < 1 then
        return 1
    elseif rate > 4 then
        return 4
    end
    return rate
end

local function psw_ramp_raise(delta)
    if delta <= 0 or not psw_ramp_active() then
        return 0
    end
    if type(psw_tfmw_all_AI_def_atk_up) ~= "function" then
        out("[psw_ai_ramp] psw_tfmw_all_AI_def_atk_up missing, skip")
        return 0
    end
    local gd = psw_ramp_globals()
    local headroom = RAMP_GLOBAL_CAP - (gd.global_AI_atk_up or 0)
    local applied = math.min(delta, math.max(headroom, 0))
    if applied <= 0 then
        return 0
    end
    local ok, err = pcall(psw_tfmw_all_AI_def_atk_up, applied)
    if not ok then
        out("[psw_ai_ramp] ERROR " .. tostring(err))
        return 0
    end
    out("[psw_ai_ramp] AI buff floor +" .. applied
        .. " (global_AI_atk_up=" .. tostring(gd.global_AI_atk_up)
        .. ", def_up=" .. tostring(gd.global_AI_def_up) .. ")")
    return applied
end

-- One-time catch-up for campaigns already deep into the escalation counter:
-- restores parity so existing armies are not stranded at the lv~15-24 floor.
local function psw_ramp_catch_up()
    if cm:get_saved_value("psw_ai_difficulty_ramp_v1_done") == 1 then
        return
    end
    if not psw_ramp_active() then
        return
    end
    local gd = psw_ramp_globals()
    if cm:turn_number() < BOOST_TURN then
        return
    end
    local boost = math.floor((gd.jishu_zhongmo or 0) / 6)
    boost = math.min(boost, 20)
    if boost <= 0 then
        cm:set_saved_value("psw_ai_difficulty_ramp_v1_done", 1)
        return
    end
    local applied = psw_ramp_raise(boost)
    if applied > 0 or (gd.global_AI_atk_up or 0) >= RAMP_GLOBAL_CAP then
        cm:set_saved_value("psw_ai_difficulty_ramp_v1_done", 1)
    end
    out("[psw_ai_ramp] catch-up boost applied: +" .. applied)
end

local function psw_ramp_turn()
    local gd = psw_ramp_globals()
    if not psw_ramp_active() then
        return
    end
    psw_ramp_raise(psw_ramp_rate(gd and gd.jishu_zhongmo))
end

cm:add_first_tick_callback(function()
    local ok, err = pcall(psw_ramp_catch_up)
    if not ok then
        out("[psw_ai_ramp] ERROR " .. tostring(err))
    end
end)

core:add_listener(
    "czx_psw_ai_difficulty_ramp",
    "WorldStartRound",
    true,
    function()
        local ok, err = pcall(psw_ramp_turn)
        if not ok then
            out("[psw_ai_ramp] ERROR " .. tostring(err))
        end
    end,
    true
)
