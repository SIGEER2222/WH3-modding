local KERRIGAN_SUBTYPE = "lin_all_kerrigan_zerg";
local KERRIGAN_AGENT_KEY = "wizard";
local KERRIGAN_ART_SET = "lin_art_set_all_kerrigan_base_0";
local LEGACY_SUBTYPES = { "czx_kerrigan", "czx_kerrigan_lord" };

local function czx_faction_has_kerrigan(faction)
    local chars = faction:character_list();
    for i = 0, chars:num_items() - 1 do
        if chars:item_at(i):character_subtype(KERRIGAN_SUBTYPE) then
            return true;
        end;
    end;
    return false;
end;

local function czx_find_kerrigan(faction)
    local chars = faction:character_list();
    for i = 0, chars:num_items() - 1 do
        local char = chars:item_at(i);
        if char:character_subtype(KERRIGAN_SUBTYPE) then
            return char;
        end;
    end;
    return nil;
end;

local function czx_kerrigan_cleanup_legacy(faction)
    local chars = faction:character_list();
    for i = 0, chars:num_items() - 1 do
        local char = chars:item_at(i);
        for _, subtype in ipairs(LEGACY_SUBTYPES) do
            if char:character_subtype(subtype) and not char:is_wounded() and not char:has_military_force() then
                out("[czx_kerrigan] remove legacy " .. subtype .. " cqi=" .. char:command_queue_index());
                cm:kill_character(char:command_queue_index(), false);
            end;
        end;
    end;
end;

local function czx_kerrigan_spawn(faction)
    if faction:is_null_interface() then
        return;
    end;
    czx_kerrigan_cleanup_legacy(faction);
    if czx_faction_has_kerrigan(faction) then
        return;
    end;
    local fname = faction:name();
    local x, y;
    if faction:has_home_region() and not faction:home_region():is_null_interface() then
        x, y = cm:find_valid_spawn_location_for_character_from_settlement(fname, faction:home_region():name(), false, true);
    elseif faction:has_faction_leader() and not faction:faction_leader():is_null_interface() then
        x, y = cm:find_valid_spawn_location_for_character_from_character(fname, cm:char_lookup_str(faction:faction_leader()), true);
    else
        return;
    end;
    out("[czx_kerrigan] summon lin_all_kerrigan_zerg -> " .. fname);
    local ok, new_agent = pcall(cm.create_agent, cm, fname, KERRIGAN_AGENT_KEY, KERRIGAN_SUBTYPE, x, y, true);
    if not ok or not new_agent then
        out("[czx_kerrigan] create_agent failed (Lin_Summon_Servant not loaded?)");
        return;
    end;
    local character = czx_find_kerrigan(faction);
    if character then
        cm:add_character_model_override(character, KERRIGAN_ART_SET);
        cm:replenish_action_points(cm:char_lookup_str(character));
        pcall(function()
            local character_cco = cco("CcoCampaignCharacter", character:cqi());
            local main_cco = character_cco:Call("UnitDetailsContext"):Call("UnitRecordContext");
            cm:change_character_custom_name(character, main_cco:Call("Name"), "", "");
        end);
    end;
end;

local function czx_kerrigan_spawn_all()
    local human_factions = cm:get_human_factions();
    for i = 1, #human_factions do
        czx_kerrigan_spawn(cm:get_faction(human_factions[i]));
    end;
end;

cm:add_first_tick_callback(function()
    czx_kerrigan_spawn_all();
    core:add_listener(
        "CZX_Kerrigan_Respawn",
        "FactionTurnStart",
        function(context)
            return context:faction():is_human();
        end,
        function(context)
            czx_kerrigan_spawn(context:faction());
        end,
        true
    );
end);
