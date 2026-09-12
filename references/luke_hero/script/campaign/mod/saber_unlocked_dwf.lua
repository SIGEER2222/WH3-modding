local function dilemma_saber_dwf_unlocked()
    local human_factions = cm:get_human_factions();
    local target_faction = "wh_main_dwf_dwarfs";
    local target_faction = "wh_main_dwf_karak_izor";
    local target_faction = "wh_main_dwf_karak_kadrin";
    local target_faction = "wh3_main_dwf_the_ancestral_throng";
    local target_faction = "wh2_dlc17_dwf_thorek_ironbrow";
    for i = 1, #human_factions do
        if cm:get_faction(human_factions[i]):subculture() == "wh_main_sc_dwf_dwarfs" then
            target_faction=human_factions[i]
        end;
    end;
    core:add_listener(
    "Saber_Dilemma_lord_dwf",
    "DilemmaChoiceMadeEvent",
    function(context)
        return context:dilemma() == "dilemma_saber_dwf";
    end,
    function(context)
        local choice = context:choice();
        if choice == 0 then
            cm:spawn_unique_agent(cm:get_faction(target_faction):command_queue_index(), "saber", false);
        elseif choice == 1 then
            cm:spawn_character_to_pool(target_faction, "names_name_114514199", "", "", "", 18, true, "general", "saber_lord", true, "")
        end;
    end,
    true
	)
end

cm:add_first_tick_callback(function() dilemma_saber_dwf_unlocked() end);
