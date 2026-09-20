--以下本地函数用于实现向派系添加精英部队招募
local function suifu()
    if cm:get_saved_value("suifu") == nil then
        local cror_list = {
            {faction_key = "wh2_dlc15_grn_broken_axe",source = "renown",unit = "wh_dlc06_grn_inf_da_warlords_boyz_0",
            	count = 0, rcp = 100, munits = 20, murpt = 2, frr = "", srr = "", trr = "",
            	 replen = true,mercenary_group = "wh_dlc06_grn_inf_da_warlords_boyz_0"},
            {faction_key = "wh2_dlc15_grn_broken_axe",source = "renown",unit = "wh_dlc06_grn_inf_da_eight_peaks_loonies_0",
            	count = 0, rcp = 100, munits = 20, murpt = 2, frr = "", srr = "", trr = "",
            	 replen = true,mercenary_group = "wh_dlc06_grn_inf_da_eight_peaks_loonies_0"},
            {faction_key = "wh2_dlc15_grn_broken_axe",source = "renown",unit = "wh_dlc06_grn_inf_krimson_killerz_0",
            	count = 0, rcp = 100, munits = 20, murpt = 2, frr = "", srr = "", trr = "",
            	 replen = true,mercenary_group = "wh_dlc06_grn_inf_krimson_killerz_0"},
            {faction_key = "wh2_dlc15_grn_broken_axe",source = "renown",unit = "wh_dlc06_grn_inf_da_rusty_arrers_0",
            	count = 0, rcp = 100, munits = 20, murpt = 2, frr = "", srr = "", trr = "",
            	 replen = true,mercenary_group = "wh_dlc06_grn_inf_da_rusty_arrers_0"},
            {faction_key = "wh2_dlc15_grn_broken_axe",source = "renown",unit = "wh3_dlc26_grn_inf_rugluds_armoured_orcs",
            	count = 0, rcp = 100, munits = 20, murpt = 2, frr = "", srr = "", trr = "",
            	 replen = true,mercenary_group = "wh3_dlc26_grn_inf_rugluds_armoured_orcs"},
            {faction_key = "wh2_dlc15_grn_broken_axe",source = "renown",unit = "wh_dlc06_grn_cav_moon_howlers_0",
            	count = 0, rcp = 100, munits = 20, murpt = 2, frr = "", srr = "", trr = "",
            	 replen = true,mercenary_group = "wh_dlc06_grn_cav_moon_howlers_0"},
            {faction_key = "wh2_dlc15_grn_broken_axe",source = "renown",unit = "wh_dlc06_grn_cav_durkits_squigs_0",
            	count = 0, rcp = 100, munits = 20, murpt = 2, frr = "", srr = "", trr = "",
            	 replen = true,mercenary_group = "wh_dlc06_grn_cav_durkits_squigs_0"},
            {faction_key = "wh2_dlc15_grn_broken_axe",source = "renown",unit = "wh_dlc06_grn_cav_broken_tusks_mob_0",
            	count = 0, rcp = 100, munits = 20, murpt = 2, frr = "", srr = "", trr = "",
            	 replen = true,mercenary_group = "wh_dlc06_grn_cav_broken_tusks_mob_0"},
            {faction_key = "wh2_dlc15_grn_broken_axe",source = "renown",unit = "wh_dlc06_grn_cav_mogrubbs_marauders_0",
            	count = 0, rcp = 100, munits = 20, murpt = 2, frr = "", srr = "", trr = "",
            	 replen = true,mercenary_group = "wh_dlc06_grn_cav_mogrubbs_marauders_0"},
            {faction_key = "wh2_dlc15_grn_broken_axe",source = "renown",unit = "wh_dlc06_grn_cav_deff_creepers_0",
            	count = 0, rcp = 100, munits = 20, murpt = 2, frr = "", srr = "", trr = "",
            	 replen = true,mercenary_group = "wh_dlc06_grn_cav_deff_creepers_0"},
            {faction_key = "wh2_dlc15_grn_broken_axe",source = "renown",unit = "wh_dlc06_grn_cav_teef_robbers_0",
            	count = 0, rcp = 100, munits = 20, murpt = 2, frr = "", srr = "", trr = "",
            	 replen = true,mercenary_group = "wh_dlc06_grn_cav_teef_robbers_0"},
            {faction_key = "wh2_dlc15_grn_broken_axe",source = "renown",unit = "wh2_dlc15_grn_mon_river_trolls_ror_0",
            	count = 0, rcp = 100, munits = 20, murpt = 2, frr = "", srr = "", trr = "",
            	 replen = true,mercenary_group = "wh2_dlc15_grn_mon_river_trolls_ror_0"},
            {faction_key = "wh2_dlc15_grn_broken_axe",source = "renown",unit = "wh3_dlc26_grn_mon_colossal_squig_ror",
            	count = 0, rcp = 100, munits = 20, murpt = 2, frr = "", srr = "", trr = "",
            	 replen = true,mercenary_group = "wh3_dlc26_grn_mon_colossal_squig_ror"},
            {faction_key = "wh2_dlc15_grn_broken_axe",source = "renown",unit = "wh_dlc06_grn_mon_venom_queen_0",
            	count = 0, rcp = 100, munits = 20, murpt = 2, frr = "", srr = "", trr = "",
            	 replen = true,mercenary_group = "wh_dlc06_grn_mon_venom_queen_0"},
           {faction_key = "wh2_dlc15_grn_broken_axe",source = "renown",unit = "wh2_dlc15_grn_mon_rogue_idol_ror_0",
            	count = 0, rcp = 100, munits = 20, murpt = 2, frr = "", srr = "", trr = "",
            	 replen = true,mercenary_group = "wh2_dlc15_grn_mon_rogue_idol_ror_0"},
            	   {faction_key = "wh2_dlc15_grn_broken_axe",source = "renown",unit = "wh2_dlc15_grn_veh_snotling_pump_wagon_ror_0",
            	count = 0, rcp = 100, munits = 20, murpt = 2, frr = "", srr = "", trr = "",
            	 replen = true,mercenary_group = "wh2_dlc15_grn_veh_snotling_pump_wagon_ror_0"},
            {faction_key = "wh2_dlc15_grn_broken_axe",source = "renown",unit = "wh_dlc06_grn_art_hammer_of_gork_0",
            	count = 0, rcp = 100, munits = 20, murpt = 2, frr = "", srr = "", trr = "",
            	 replen = true,mercenary_group = "wh_dlc06_grn_art_hammer_of_gork_0"},
           {faction_key = "wh2_dlc15_grn_broken_axe",source = "renown",unit = "wh3_dlc26_grn_art_bolt_throwa_ror",
            	count = 0, rcp = 100, munits = 20, murpt = 2, frr = "", srr = "", trr = "",
            	 replen = true,mercenary_group = "wh3_dlc26_grn_art_bolt_throwa_ror"},
            --faction_key填派系代码；
            --source不用改；
            --unit填单位main表的unit代码；
            --count是容量，一般都填1；
            --frr、srr、trr分别是派系限定、子文化限定和科技限定
            --mercenary_group填mercenary_unit_groups_tables里的key代码，需要自己新建，还要分配在mercenary_pool_to_groups_junctions_tables到对应的派系招募池；
            	}--到这里结束，如果要给多个派系添加精英部队的话，加个逗号，后面再填一轮即可
            	 
         for i = 1,#cror_list do  
        	local faction_name = cror_list[i].faction_key;  
        	local faction = cm:get_faction(faction_name);
            local source_key = "renown";
        	local unit_key = cror_list[i].unit;
        	local unit_count = cror_list[i].count;
        	local rcp = 100;
        	local munits = cror_list[i].munits;
        	local murpt = 0.3;
        	local frr = "";
        	local srr = "";
        	local trr = "";
        	local replen = true;
            local group_key = cror_list[i].mercenary_group;
            
            
            
            
            
            
            
            
        	cm:add_unit_to_faction_mercenary_pool(faction, unit_key,source_key, unit_count, rcp, munits, murpt, frr, srr, trr, replen,group_key);
        end;
        cm:set_saved_value("suifu", true);
    end;
end;
cm:add_first_tick_callback(function() suifu() end);