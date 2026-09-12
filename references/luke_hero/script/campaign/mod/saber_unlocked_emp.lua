local function dilemma_saber_emp_unlocked()
    local human_factions = cm:get_human_factions();
    local target_faction = "wh_main_emp_empire";
    local target_faction = "wh2_dlc13_emp_golden_order";
    local target_faction = "wh3_main_emp_cult_of_sigmar";
    local target_faction = "wh2_dlc13_emp_the_huntmarshals_expedition";
    for i = 1, #human_factions do
        if cm:get_faction(human_factions[i]):subculture() == "wh_main_sc_emp_empire" then
            target_faction=human_factions[i]
        end;
    end;
    core:add_listener(
    "Saber_Dilemma_lord_emp",
    "DilemmaChoiceMadeEvent",
    function(context)
        return context:dilemma() == "dilemma_saber_emp";
    end,
    function(context)
        local choice = context:choice();
        if choice == 0 then
            cm:spawn_unique_agent(cm:get_faction(target_faction):command_queue_index(), "saber", false);
        elseif choice == 1 then
            cm:spawn_character_to_pool(target_faction, "names_name_114514197", "", "", "", 50, true, "general", "saber_lord", true, "")
        end;
    end,
    true
	)
end

cm:add_first_tick_callback(function() dilemma_saber_emp_unlocked() end);
