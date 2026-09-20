local KERRIGAN_SUBTYPE = "czx_kerrigan";

local function czx_faction_has_kerrigan(faction)
    local chars = faction:character_list();
    for i = 0, chars:num_items() - 1 do
        if chars:item_at(i):character_subtype(KERRIGAN_SUBTYPE) then
            return true;
        end;
    end;
    return false;
end;

local function czx_kerrigan_spawn(faction)
    if not faction:is_null_interface() and not czx_faction_has_kerrigan(faction) then
        out("[czx_kerrigan] spawn_unique_agent -> " .. faction:name());
        cm:spawn_unique_agent(faction:command_queue_index(), KERRIGAN_SUBTYPE, false);
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
