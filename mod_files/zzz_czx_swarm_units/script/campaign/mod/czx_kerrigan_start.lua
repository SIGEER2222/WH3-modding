local function czx_kerrigan_dilemma_setup()
    core:add_listener(
        "CZX_Kerrigan_Dilemma",
        "DilemmaChoiceMadeEvent",
        function(context)
            return context:dilemma() == "dilemma_czx_kerrigan";
        end,
        function(context)
            local faction = context:faction();
            local faction_key = faction:name();
            local choice = context:choice();
            if choice == 0 then
                cm:spawn_unique_agent(faction:command_queue_index(), "czx_kerrigan", false);
            elseif choice == 1 then
                cm:spawn_character_to_pool(faction_key, "names_name_789900001", "", "", "", 18, false, "general", "czx_kerrigan_lord", true, "");
            end;
        end,
        true
    );
end;

cm:add_first_tick_callback(function() czx_kerrigan_dilemma_setup() end);
