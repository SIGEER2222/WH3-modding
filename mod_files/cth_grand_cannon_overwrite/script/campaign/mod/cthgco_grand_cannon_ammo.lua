local CTHGCO_AMMO_BUNDLE = "cthgco_bundle_grand_cannon_explosive_ammo"

cm:add_first_tick_callback(function()
	local faction_list = cm:get_faction_list()

	for i = 0, faction_list:num_items() - 1 do
		local faction = faction_list:item_at(i)

		if faction and not faction:is_null_interface() then
			cm:apply_effect_bundle(CTHGCO_AMMO_BUNDLE, faction:name(), -1)
		end
	end
end)
