local function dilemma_saber_cth_unlocked()
    local human_factions = cm:get_human_factions();
    local target_faction = "wh3_main_cth_the_western_provinces";
    local target_faction = "wh3_main_cth_the_northern_provinces";
    local target_faction = "wh3_dlc24_cth_the_celestial_court";
    for i = 1, #human_factions do
        if cm:get_faction(human_factions[i]):subculture() == "wh3_main_sc_cth_cathay" then
            target_faction=human_factions[i]
        end;
    end;
    core:add_listener(
    "Saber_Dilemma_lord",
    "DilemmaChoiceMadeEvent",
    function(context)
        return context:dilemma() == "dilemma_saber";
    end,
    function(context)
        local choice = context:choice();
        if choice == 0 then
            cm:spawn_unique_agent(cm:get_faction(target_faction):command_queue_index(), "saber", false);
        elseif choice == 1 then
            cm:spawn_character_to_pool(target_faction, "names_name_114514191", "", "", "", 18, true, "general", "saber_lord", true, "")
        end;
    end,
    true
	)
end

cm:add_first_tick_callback(function() dilemma_saber_cth_unlocked() end);
