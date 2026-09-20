local KERRIGAN_LORD_SUBTYPE = "czx_kerrigan_lord";
local KERRIGAN_NAME_KEY = "names_name_789900001";

local function czx_kerrigan_pool_spawn(faction)
    if faction:is_null_interface() then return end;
    local fname = faction:name();
    if cm:get_saved_value("czx_kerrigan_pool_" .. fname) then return end;
    cm:set_saved_value("czx_kerrigan_pool_" .. fname, true);
    cm:spawn_character_to_pool(fname, KERRIGAN_NAME_KEY, "", "", "", 45, true, "general", KERRIGAN_LORD_SUBTYPE, true, "");
    out("[czx_kerrigan] pool spawn -> " .. fname);
end;

cm:add_first_tick_callback(function()
    local human_factions = cm:get_human_factions();
    for i = 1, #human_factions do
        czx_kerrigan_pool_spawn(cm:get_faction(human_factions[i]));
    end;
end);
