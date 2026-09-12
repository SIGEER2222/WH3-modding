local function dilemma_saber_brt_unlocked()
    local human_factions = cm:get_human_factions();
    local target_faction = "wh_main_brt_bretonnia";
    local target_faction = "wh_main_brt_carcassonne";
    local target_faction = "wh_main_brt_bordeleaux";
    local target_faction = "wh2_dlc14_brt_chevaliers_de_lyonesse";
    for i = 1, #human_factions do
        if cm:get_faction(human_factions[i]):subculture() == "wh_main_sc_brt_bretonnia" then
            target_faction=human_factions[i]
        end;
    end;
    core:add_listener(
    "Saber_Dilemma_lord_brt",
    "DilemmaChoiceMadeEvent",
    function(context)
        return context:dilemma() == "dilemma_saber_brt";
    end,
    function(context)
        local choice = context:choice();
        if choice == 0 then
            cm:spawn_unique_agent(cm:get_faction(target_faction):command_queue_index(), "saber", false);
        elseif choice == 1 then
            cm:spawn_character_to_pool(target_faction, "names_name_114514195", "", "", "", 18, true, "general", "saber_lord", true, "")
        end;
    end,
    true
	)
end

cm:add_first_tick_callback(function() dilemma_saber_brt_unlocked() end);
