local function czx_kerrigan_dilemma_setup()
    local target_faction = "wh_main_emp_empire";
    local human_factions = cm:get_human_factions();
    for i = 1, #human_factions do
        if cm:get_faction(human_factions[i]):subculture() == "wh_main_sc_emp_empire" then
            target_faction = human_factions[i];
        end;
    end;

    core:add_listener(
        "CZX_Kerrigan_Dilemma",
        "DilemmaChoiceMadeEvent",
        function(context)
            return context:dilemma() == "dilemma_czx_kerrigan";
        end,
        function(context)
            local choice = context:choice();
            if choice == 0 then
                cm:spawn_unique_agent(cm:get_faction(target_faction):command_queue_index(), "czx_kerrigan", false);
            elseif choice == 1 then
                cm:spawn_character_to_pool(target_faction, "names_name_789900001", "", "", "", 18, false, "general", "czx_kerrigan_lord", true, "");
            end;
        end,
        true
    );
end;

cm:add_first_tick_callback(function() czx_kerrigan_dilemma_setup() end);
