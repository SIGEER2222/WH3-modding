local function dilemma_saber_hef_unlocked()
    local human_factions = cm:get_human_factions();
    local target_faction = "wh2_main_hef_yvresse";
    local target_faction = "wh2_main_hef_nagarythe";
    local target_faction = "wh2_main_hef_eataine";
    local target_faction = "wh2_main_hef_avelorn";
    local target_faction = "wh2_dlc15_hef_imrik";
    local target_faction = "wh2_main_hef_order_of_loremasters";
    for i = 1, #human_factions do
        if cm:get_faction(human_factions[i]):subculture() == "wh2_main_sc_hef_high_elves" then
            target_faction=human_factions[i]
        end;
    end;
    core:add_listener(
    "Saber_Dilemma_lord_hef",
    "DilemmaChoiceMadeEvent",
    function(context)
        return context:dilemma() == "dilemma_saber_hef";
    end,
    function(context)
        local choice = context:choice();
        if choice == 0 then
            cm:spawn_unique_agent(cm:get_faction(target_faction):command_queue_index(), "saber", false);
        elseif choice == 1 then
            cm:spawn_character_to_pool(target_faction, "names_name_114514201", "", "", "", 18, true, "general", "saber_lord", true, "")
        end;
    end,
    true
	)
end

cm:add_first_tick_callback(function() dilemma_saber_hef_unlocked() end);
