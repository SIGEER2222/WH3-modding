local function dilemma_saber_ksl_unlocked()
    local human_factions = cm:get_human_factions();
    local target_faction = "wh3_main_ksl_the_ice_court";
    local target_faction = "wh3_main_ksl_the_great_orthodoxy";
    local target_faction = "wh3_main_ksl_ursun_revivalists";
    local target_faction = "wh3_dlc24_ksl_daughters_of_the_forest";
    for i = 1, #human_factions do
        if cm:get_faction(human_factions[i]):subculture() == "wh3_main_sc_ksl_kislev" then
            target_faction=human_factions[i]
        end;
    end;
    core:add_listener(
    "Saber_Dilemma_lord_ksl",
    "DilemmaChoiceMadeEvent",
    function(context)
        return context:dilemma() == "dilemma_saber_ksl";
    end,
    function(context)
        local choice = context:choice();
        if choice == 0 then
            cm:spawn_unique_agent(cm:get_faction(target_faction):command_queue_index(), "saber", false);
        elseif choice == 1 then
            cm:spawn_character_to_pool(target_faction, "names_name_114514193", "", "", "", 18, true, "general", "saber_lord", true, "")
        end;
    end,
    true
	)
end

cm:add_first_tick_callback(function() dilemma_saber_ksl_unlocked() end);
