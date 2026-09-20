-- czx_luke_saber_fix
-- 修复 Luke_King_of_Knight_hero_WH3 在 WH3 8.1+ 下「英灵召唤」dilemma 不自动弹出的问题。
-- 原 mod 依赖原版事件池 generate=true 自动发放，8.1 后不再触发；
-- 本脚本在第二回合起的人类回合开始时主动 trigger_dilemma，每档只弹一次。

local CZX_SABER_DILEMMAS = {
    wh3_main_sc_cth_cathay   = "dilemma_saber",
    wh3_main_sc_ksl_kislev   = "dilemma_saber_ksl",
    wh_main_sc_emp_empire    = "dilemma_saber_emp",
    wh_main_sc_brt_bretonnia = "dilemma_saber_brt",
    wh2_main_sc_hef_high_elves = "dilemma_saber_hef",
    wh_main_sc_dwf_dwarfs    = "dilemma_saber_dwf"
};

local SAVED_KEY = "czx_saber_dilemma_fired";

local function czx_saber_try_fire()
    if cm:get_saved_value(SAVED_KEY) then
        return;
    end;

    local human_factions = cm:get_human_factions();
    for i = 1, #human_factions do
        local faction = cm:get_faction(human_factions[i]);
        local dilemma_key = CZX_SABER_DILEMMAS[faction:subculture()];
        if dilemma_key then
            cm:set_saved_value(SAVED_KEY, true);
            cm:trigger_dilemma(human_factions[i], dilemma_key);
            return;
        end;
    end;
end

core:add_listener(
    "czx_saber_dilemma_fix_turn_start",
    "FactionTurnStart",
    function(context)
        local faction = context:faction();
        return faction:is_human() and cm:turn_number() >= 2;
    end,
    function(context)
        czx_saber_try_fire();
    end,
    true
);

-- 存档已过第二回合时，载入后立即补弹一次。
cm:add_first_tick_callback(function()
    if cm:turn_number() >= 2 then
        czx_saber_try_fire();
    end;
end);
