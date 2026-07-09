local hefadk_avelorn_faction = "wh2_main_hef_avelorn";
local hefadk_avelorn_dragon_knights_unit = "hefadk_hef_cav_avelorn_dragon_knights";
local hefadk_eden_valley_ror_unit = "hefadk_hef_cav_eden_valley_dragon_knights_ror";
local hefadk_eden_valley_ror_group = "hefadk_hef_cav_eden_valley_dragon_knights_ror";
local hefadk_alarielle_opening_dilemma = "hefadk_alarielle_opening_dragon_knights";
local hefadk_alarielle_opening_dilemma_triggered_saved_key = "hefadk_alarielle_opening_dilemma_triggered";
local hefadk_alarielle_opening_dilemma_resolved_saved_key = "hefadk_alarielle_opening_dilemma_resolved";
local hefadk_alarielle_gold_reward = 3000;
local hefadk_alarielle_opening_dilemma_delay = 10;
local hefadk_alarielle_opening_dilemma_pending = false;

local hefadk_high_elf_factions = {
	"wh2_dlc15_hef_imrik",
	"wh2_main_hef_avelorn",
	"wh2_main_hef_eataine",
	"wh2_main_hef_nagarythe",
	"wh2_main_hef_order_of_loremasters",
	"wh2_main_hef_yvresse",
	"wh3_dlc27_hef_aislinn",
};

local function hefadk_log(message)
	out("HEFADK: " .. tostring(message));
end;

local function hefadk_is_valid_faction(faction)
	return faction and not faction:is_null_interface() and not faction:is_dead();
end;

local function hefadk_add_eden_valley_ror_to_faction(faction)
	if not faction or faction:is_null_interface() or not faction:is_human() then
		return;
	end;

	local faction_key = faction:name();
	local saved_key = "hefadk_eden_valley_ror_added_" .. faction_key;

	if cm:get_saved_value(saved_key) then
		return;
	end;

	cm:add_unit_to_faction_mercenary_pool(
		faction,
		hefadk_eden_valley_ror_unit,
		"renown",
		1,
		100,
		1,
		0.1,
		"",
		"wh2_main_sc_hef_high_elves",
		"",
		true,
		hefadk_eden_valley_ror_group
	);

	cm:set_saved_value(saved_key, true);
	hefadk_log("added Eden Valley RoR to renown pool for " .. faction_key);
end;

local function hefadk_add_eden_valley_ror()
	for i = 1, #hefadk_high_elf_factions do
		local faction = cm:get_faction(hefadk_high_elf_factions[i]);
		hefadk_add_eden_valley_ror_to_faction(faction);
	end;
end;

local function hefadk_register_alarielle_opening_dilemma_listener()
	core:remove_listener("hefadk_alarielle_opening_dilemma_choice");

	core:add_listener(
		"hefadk_alarielle_opening_dilemma_choice",
		"DilemmaChoiceMadeEvent",
		function(context)
			return context:dilemma() == hefadk_alarielle_opening_dilemma
				and context:faction():name() == hefadk_avelorn_faction;
		end,
		function(context)
			if cm:get_saved_value(hefadk_alarielle_opening_dilemma_resolved_saved_key) then
				return;
			end;

			local choice_key = context:choice_key();

			if choice_key == "FIRST" or context:choice() == 0 then
				cm:treasury_mod(hefadk_avelorn_faction, hefadk_alarielle_gold_reward);
				hefadk_log("Alarielle opening dilemma resolved: granted " .. tostring(hefadk_alarielle_gold_reward) .. " treasury");
			elseif choice_key == "SECOND" or context:choice() == 1 then
				local faction = cm:get_faction(hefadk_avelorn_faction);

				if hefadk_is_valid_faction(faction) then
					local leader = faction:faction_leader();

					if leader and not leader:is_null_interface() then
						cm:grant_unit_to_character(cm:char_lookup_str(leader), hefadk_avelorn_dragon_knights_unit);
						hefadk_log("Alarielle opening dilemma resolved: granted Avelorn Dragon Knights");
					end;
				end;
			end;

			cm:set_saved_value(hefadk_alarielle_opening_dilemma_resolved_saved_key, true);
		end,
		true
	);
end;

local function hefadk_try_launch_alarielle_opening_dilemma()
	if cm:get_saved_value(hefadk_alarielle_opening_dilemma_triggered_saved_key) then
		return;
	end;

	local faction = cm:get_faction(hefadk_avelorn_faction);

	if not hefadk_is_valid_faction(faction) or not faction:is_human() then
		return;
	end;

	local dilemma_builder = cm:create_dilemma_builder(hefadk_alarielle_opening_dilemma);
	local payload_builder = cm:create_payload();

	payload_builder:text_display("hefadk_alarielle_opening_gold");
	dilemma_builder:add_choice_payload("FIRST", payload_builder);
	payload_builder:clear();

	payload_builder:text_display("hefadk_alarielle_opening_unit");
	dilemma_builder:add_choice_payload("SECOND", payload_builder);

	cm:launch_custom_dilemma_from_builder(dilemma_builder, faction);

	cm:set_saved_value(hefadk_alarielle_opening_dilemma_triggered_saved_key, true);
	hefadk_log("triggered Alarielle opening dilemma");
end;

local function hefadk_schedule_alarielle_opening_dilemma()
	if hefadk_alarielle_opening_dilemma_pending
		or cm:get_saved_value(hefadk_alarielle_opening_dilemma_triggered_saved_key) then
		return;
	end;

	local faction = cm:get_faction(hefadk_avelorn_faction);

	if not hefadk_is_valid_faction(faction) or not faction:is_human() then
		return;
	end;

	hefadk_alarielle_opening_dilemma_pending = true;

	cm:callback(function()
		hefadk_try_launch_alarielle_opening_dilemma();
	end, hefadk_alarielle_opening_dilemma_delay);
end;

local function hefadk_register_alarielle_opening_dilemma_trigger()
	core:remove_listener("hefadk_alarielle_opening_panel_opened");

	if not cm:is_new_game()
		or hefadk_alarielle_opening_dilemma_pending
		or cm:get_saved_value(hefadk_alarielle_opening_dilemma_triggered_saved_key) then
		return;
	end;

	core:add_listener(
		"hefadk_alarielle_opening_panel_opened",
		"PanelOpenedCampaign",
		true,
		function()
			hefadk_schedule_alarielle_opening_dilemma();
			core:remove_listener("hefadk_alarielle_opening_panel_opened");
		end,
		true
	);
end;

cm:add_first_tick_callback(function()
	hefadk_add_eden_valley_ror();
	hefadk_register_alarielle_opening_dilemma_listener();
	hefadk_register_alarielle_opening_dilemma_trigger();
end);
