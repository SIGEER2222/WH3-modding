-- czx_hero_grants
-- Grant Luke King-of-Knight hero (saber) + zt_chanliuzi pool lord + Lin
-- Summon-Servant prize draw to the human player on the first eligible tick.
--
-- Why: Luke_King_of_Knight_hero_WH3 only registers dilemma choices for the six
-- order cultures (cth/ksl/emp/brt/hef/dwf) — a vampire-counts player never gets
-- the dilemma. zt_chanliuzi only fires on add_first_tick_callback_new, so a
-- save created while its script was absent never gets her. Lin_Summon_Servant's
-- free grant only fires on turn 1, so an established save can only summon via
-- the UI button (which can be hidden by UI mods). This grants all three once,
-- directly, at campaign start (new game or load).

local GRANT_KEY = "czx_hero_grants_fired";
local CHANLIUZI_KEY = "zt_chanliuzi_spawned";

local function czx_log(msg)
    out("[czx_hero_grants] " .. tostring(msg));
end;

local function czx_grant_saber(faction)
    local fname = faction:name();
    local cqi = faction:command_queue_index();

    -- Agent spawns queue an agent event-feed panel; during the loading/intro
    -- window that panel only materialises when the intro re-enables event
    -- panels (~dismiss+18s, inside the §10.40 crash window) — suppress the
    -- feed around the spawn so nothing queues there.
    cm:disable_event_feed_events(true, "wh_event_category_agent", "", "");

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

    cm:callback(function()
        cm:disable_event_feed_events(false, "wh_event_category_agent", "", "");
    end, 0.5);
end;

-- Run fn only after the intro/dismiss sequence has been fully quiet for a
-- while. The dilemma panel must never materialise inside the §10.40 window
-- (dismiss → overlay → flyover → narrative panels): a queued dilemma only
-- opens when enable_event_panel_auto_open fires mid-intro — the exact crash
-- point observed in session 1429 (~321s).
local function _draw_when_settled(fn)
    local guard = rawget(_G, "CZX_LUA_GUARD");
    if guard and type(guard.defer_until_intro_settled) == "function" then
        guard.defer_until_intro_settled(fn);
        return;
    end;
    -- fallback: local settle probe (guard pack absent)
    -- §10.40 v3 死区盲区：级联结束→flyover 起步间 ~40s 静默带里瞬时判据全绿，
    -- 必须等 flyover 剧场的 CinematicTrigger end_cinematic（cap 兜底）。
    local cine_done = true;
    local ok_ng, ng = pcall(function() return cm:is_new_game() end);
    if ok_ng and ng then
        cine_done = false;
        pcall(function()
            core:add_listener("czx_draw_cine_end", "CinematicTrigger",
                function(c) return c.string == "end_cinematic" end,
                function() cine_done = true end, false);
        end);
        cm:real_callback(function() cine_done = true end, 150000, "czx_draw_cine_cap");
    end;
    local polls = 0;
    local stable = 0;
    -- §10.40 v4：UI 锁/面板忙期间发放 dilemma 会插进 vanilla 锁链级联；
    -- uim.ui_locked / panels_open 纯 Lua 字段，不碰原生 UI 树。
    local function _ui_idle()
        local ok_uim, uim = pcall(function() return cm:get_campaign_ui_manager() end);
        if not ok_uim or not uim then return false end;
        if uim.ui_locked then return false end;
        local ok_bp, blocking = pcall(function() return uim:get_open_blocking_panel() end);
        if ok_bp and blocking then return false end;
        local ok_ev, events_open = pcall(function() return uim:is_panel_open("events") end);
        if ok_ev and events_open then return false end;
        return true;
    end;
    local function probe()
        polls = polls + 1;
        local clear = cine_done and _ui_idle();
        local ok_play, playing = pcall(function() return cm:is_intro_cutscene_playing() end);
        if ok_play and playing then clear = false end;
        local ok_cs, any_cs = pcall(function() return cm:is_any_cutscene_running() end);
        if ok_cs and any_cs then clear = false end;
        if clear then stable = stable + 1 else stable = 0 end;
        if (polls >= 20 and stable >= 10) or polls > 200 then
            pcall(fn);
        else
            cm:real_callback(probe, 1000, "czx_draw_probe");
        end;
    end;
    cm:real_callback(probe, 2000, "czx_draw_probe");
end;

local function czx_grant_servant_draw(faction)
    local fname = faction:name();

    -- Prefer calling the mod's own prize-draw so the player gets the real
    -- four-choice summoning dilemma; fall back to its ContextTriggerEvent API.
    -- Deferred until the intro sequence is settled (see _draw_when_settled).
    _draw_when_settled(function()
        -- v4 次序隔离：draw 会打开 dilemma 面板并把 UI 拉进锁链；
        -- 延后 ~45s 让 fet 下拉点击/overlay 面板写先在无锁干净窗口完成，
        -- 避免"面板锁 + 模拟点击"同框（0728 崩点正是该组合）。
        cm:real_callback(function()
            local ok, err = pcall(function()
                if summon_servant and summon_servant.dilemma_prize_draw then
                    summon_servant:dilemma_prize_draw(faction);
                else
                    core:trigger_event("ContextTriggerEvent", "summon_servant_faction:" .. fname);
                end;
            end);
            czx_log("summon_servant prize draw -> " .. fname .. ": ok=" .. tostring(ok) .. " " .. tostring(err or ""));
        end, 45000, "czx_draw_post_settle");
    end);
end;

-- chanliuzi: !!!zt_chanliuzi grants her into the lord pool only on a new-campaign
-- first tick. Reuse its own saved key so a campaign where it already ran (or
-- where it fires alongside us) never gets her twice.
local function czx_grant_chanliuzi(faction)
    local fname = faction:name();
    if cm:get_saved_value(CHANLIUZI_KEY) then
        czx_log("chanliuzi skipped for " .. fname .. ": already granted");
        return;
    end;
    cm:set_saved_value(CHANLIUZI_KEY, true);
    local ok, err = pcall(function()
        cm:spawn_character_to_pool(fname, "names_name_2024070401", "", "", "", 50, true, "general", "zt_chanliuzi", true, "");
    end);
    czx_log("spawn_character_to_pool zt_chanliuzi -> " .. fname .. ": ok=" .. tostring(ok) .. " " .. tostring(err or ""));
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

    local humans = cm:get_human_factions();
    if #humans == 0 then
        return;  -- faction list not ready yet; let a later trigger retry
    end;
    cm:set_saved_value(GRANT_KEY, true);

    for _, fname in ipairs(humans) do
        local faction = cm:get_faction(fname);
        if faction and not faction:is_null_interface() then
            if not SABER_NATIVE_CULTURES[faction:subculture()] then
                czx_grant_saber(faction);
            else
                czx_log("saber skipped for " .. fname .. ": native dilemma covers this culture");
            end;
            czx_grant_chanliuzi(faction);
            czx_grant_servant_draw(faction);
        end;
    end;
end;

-- Primary trigger: first tick of every session (covers new campaigns at turn 1
-- and established saves on load).
cm:add_first_tick_callback(function()
    czx_grant_heroes();
end);

-- Fallback in case the first tick ran before the human faction list was ready.
core:add_listener(
    "czx_hero_grants_next_turn",
    "FactionTurnStart",
    function(context)
        local faction = context:faction();
        return faction:is_human();
    end,
    function(context)
        czx_grant_heroes();
    end,
    false
);
