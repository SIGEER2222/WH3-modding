-- czx_hero_grants
-- Grant Luke King-of-Knight hero (saber) + Lin Summon-Servant prize draw to the
-- human player at the start of their next turn.
--
-- Why: Luke_King_of_Knight_hero_WH3 only registers dilemma choices for the six
-- order cultures (cth/ksl/emp/brt/hef/dwf) — a vampire-counts player never gets
-- the dilemma. Lin_Summon_Servant's free grant only fires on turn 1, so an
-- established save can only summon via the UI button (which can be hidden by
-- UI mods). This grants both once, directly.

local GRANT_KEY = "czx_hero_grants_fired";

local function czx_log(msg)
    out("[czx_hero_grants] " .. tostring(msg));
end;

local function czx_grant_saber(faction)
    local fname = faction:name();
    local cqi = faction:command_queue_index();

    -- agent version: unique champion "saber" placed on the map
    local ok, err = pcall(function()
        cm:spawn_unique_agent(cqi, "saber", false);
    end);
    czx_log("spawn_unique_agent saber -> " .. fname .. ": ok=" .. tostring(ok) .. " " .. tostring(err or ""));

    -- lord version: recruit-pool "saber_lord" (mirrors the Luke dilemma's
    -- second choice; uses the same name key as the original scripts)
    ok, err = pcall(function()
        cm:spawn_character_to_pool(fname, "names_name_114514195", "", "", "", 18, true, "general", "saber_lord", true, "");
    end);
    czx_log("spawn_character_to_pool saber_lord -> " .. fname .. ": ok=" .. tostring(ok) .. " " .. tostring(err or ""));
end;

local function czx_grant_servant_draw(faction)
    local fname = faction:name();

    -- Prefer calling the mod's own prize-draw so the player gets the real
    -- four-choice summoning dilemma; fall back to its ContextTriggerEvent API.
    local ok, err = pcall(function()
        if summon_servant and summon_servant.dilemma_prize_draw then
            summon_servant:dilemma_prize_draw(faction);
        else
            core:trigger_event("ContextTriggerEvent", "summon_servant_faction:" .. fname);
        end;
    end);
    czx_log("summon_servant prize draw -> " .. fname .. ": ok=" .. tostring(ok) .. " " .. tostring(err or ""));
end;

-- Subcultures the Luke mod covers natively — skip the saber grant for those or
-- the player would get Saber twice (native dilemma + this patch).
local SABER_NATIVE_CULTURES = {
    wh3_main_sc_cth_cathay = true,
    wh3_main_sc_ksl_kislev = true,
    wh_main_sc_emp_empire = true,
    wh_main_sc_brt_bretonnia = true,
    wh2_main_sc_hef_high_elves = true,
    wh_main_sc_dwf_dwarfs = true
};

local function czx_grant_heroes()
    if cm:get_saved_value(GRANT_KEY) then
        return;
    end;
    cm:set_saved_value(GRANT_KEY, true);

    for _, fname in ipairs(cm:get_human_factions()) do
        local faction = cm:get_faction(fname);
        if faction and not faction:is_null_interface() then
            if not SABER_NATIVE_CULTURES[faction:subculture()] then
                czx_grant_saber(faction);
            else
                czx_log("saber skipped for " .. fname .. ": native dilemma covers this culture");
            end;
            czx_grant_servant_draw(faction);
        end;
    end;
end;

core:add_listener(
    "czx_hero_grants_next_turn",
    "FactionTurnStart",
    function(context)
        local faction = context:faction();
        return faction:is_human() and cm:turn_number() >= 2;
    end,
    function(context)
        czx_grant_heroes();
    end,
    false
);
