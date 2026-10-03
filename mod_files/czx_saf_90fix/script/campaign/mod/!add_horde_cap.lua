
-- czx_saf_90fix: engine force_declare_war() hard-errors on faction keys that
-- don't exist on this map/version, and this file's saf_buff_ai() runs inside a
-- first-tick callback whose abort kills every later first-tick callback of
-- every mod (buttons, starting heroes, lord pools). Wrap each call so a stale
-- key only skips that one war declaration instead of cascading.
-- 2026-10-03: the known-stale WH2-only key wh2_dlc13_wef_laurelorn_forest has
-- been REMOVED (wh3_main_wef_laurelorn already declares the same war); the
-- pcall wrapper stays as a guard for any stale key not yet discovered. If a
-- "[czx_saf_90fix] force_declare_war skipped" line ever shows up in
-- script_log, prune that pair the same way.
local function saf_force_declare_war(faction_a, faction_b, p3, p4)
	local ok, err = pcall(cm.force_declare_war, cm, faction_a, faction_b, p3, p4);
	if not ok then
		out("[czx_saf_90fix] force_declare_war skipped: " .. tostring(faction_a) .. " vs " .. tostring(faction_b) .. " | " .. tostring(err));
	end;
end


local factionsOfSAFAI = {
    beastmen = {
        "wh2_dlc17_bst_taurox",
        "wh2_dlc13_lzd_spirits_of_the_jungle",
        "wh2_dlc17_bst_malagor",
        "wh_dlc05_bst_morghur_herd",
        "wh_dlc03_bst_beastmen",
    },
    settle_chaos = {
        "wh_main_chs_chaos",
        "wh3_main_chs_shadow_legion",
        "wh3_dlc20_chs_vilitch",
        "wh3_dlc20_chs_valkia",
        "wh3_dlc20_chs_sigvald",
        "wh3_dlc20_chs_kholek",
        "wh3_dlc20_chs_festus",
        "wh3_dlc20_chs_azazel",
    },
    chaos = {
        "wh_main_chs_chaos",
        "wh3_main_chs_shadow_legion",
        "wh3_dlc20_chs_vilitch",
        "wh3_dlc20_chs_valkia",
        "wh3_dlc20_chs_sigvald",
        "wh3_dlc20_chs_kholek",
        "wh3_dlc20_chs_festus",
        "wh3_dlc20_chs_azazel",
        "wh3_main_dae_daemon_prince",
        "wh2_dlc17_bst_malagor",
        "wh_dlc05_bst_morghur_herd",
        "wh_dlc03_bst_beastmen",
        "wh2_dlc17_bst_taurox",
        "wh3_main_tze_oracles_of_tzeentch",
        "wh3_main_nur_poxmakers_of_nurgle",
        "wh3_main_sla_seducers_of_slaanesh",
        "wh3_main_kho_exiles_of_khorne",
        "wh2_main_skv_clan_skryre",
        "wh2_main_skv_clan_pestilens",
        "wh2_dlc09_skv_clan_rictus",
        "wh2_main_skv_clan_eshin",
        "wh2_main_skv_clan_mors",
        "wh2_main_skv_clan_moulder",
        "wh_dlc08_nor_norsca",
        "wh_dlc08_nor_wintertooth",
        "wh3_dlc23_chd_astragoth",
        "wh3_dlc23_chd_legion_of_azgorh",
        "wh3_dlc23_chd_zhatan",
        "wh3_dlc24_tze_the_deceivers",
        "wh3_dlc25_nur_epidemius",
        "wh3_dlc25_nur_tamurkhan",
        "wh3_dlc26_kho_arbaal",
        "wh3_dlc26_kho_skulltaker",
        "wh3_dlc27_nor_sayl",
        "wh3_dlc27_sla_masque_of_slaanesh",
        "wh3_dlc27_sla_the_tormentors"
    },
    chd = {
        "wh3_dlc23_chd_astragoth",
        "wh3_dlc23_chd_legion_of_azgorh",
        "wh3_dlc23_chd_zhatan"
    }
}

local mct_setting = {
    isAdditionalInitialFactionbasedDiplomaticCheckbox = true,
    isChaosWarriorFactionSpecialEnhancementsCheckbox = true,
    isChaosDwarfFactionSpecialEnhancementsCheckbox = true
}

local IS_DEBUG = false

local function saf_out(text)
    if IS_DEBUG then
        out("SAFAI_AddHordeCap: " .. text)
    end
end

local function update_settings(mct)
    local mct_mod = mct:get_mod_by_key("ai_stronger_and_fairer")
    
    -- Debug setting
    local mct_option_debug = mct_mod:get_option_by_key("debug_log_checkbox")
    if mct_option_debug then
        IS_DEBUG = mct_option_debug:get_finalized_setting()
    end
    
    --Army
    local mct_option_isAdditionalInitialFactionbasedDiplomaticCheckbox = mct_mod:get_option_by_key("additional_initial_factionbased_diplomatic_checkbox")
    mct_setting.isAdditionalInitialFactionbasedDiplomaticCheckbox = mct_option_isAdditionalInitialFactionbasedDiplomaticCheckbox:get_finalized_setting()
    
    
    local mct_option_isChaosWarriorFactionSpecialEnhancementsCheckbox = mct_mod:get_option_by_key("chaos_warrior_faction_special_enhancements_checkbox")
    mct_setting.isChaosWarriorFactionSpecialEnhancementsCheckbox = mct_option_isChaosWarriorFactionSpecialEnhancementsCheckbox:get_finalized_setting()
    
    
    local mct_option_isChaosDwarfFactionSpecialEnhancementsCheckbox = mct_mod:get_option_by_key("chaos_dwarf_faction_special_enhancements_checkbox")
    mct_setting.isChaosDwarfFactionSpecialEnhancementsCheckbox = mct_option_isChaosDwarfFactionSpecialEnhancementsCheckbox:get_finalized_setting()
    
end

local isPlayersContainsChaos = 0

local function judgePlayerContainsChaos()
    --saf_out("Judge start")
    isPlayersContainsChaos = 0 
    for k, fc in pairs(factionsOfSAFAI.chaos) do
        local faction = cm:get_faction(fc);
        if faction:is_human() then
            isPlayersContainsChaos = 1
        end
    end
    --saf_out("Judge result: "..tostring(isPlayersContainsChaos))
    --saf_out("Judge end")
end

local function beastmenArmyCap()
    saf_out("Cap start")
    for k, fc in pairs(factionsOfSAFAI.beastmen) do
        local faction = cm:get_faction(fc);
        if faction:is_human() == false then
            cm:apply_effect_bundle("horde_buff_ai", fc, 0)
        end;
    end;
    saf_out("Cap end")
end

local function apply_changeling_buff()
    saf_out("apply_changeling_buff Start")
	local FactionList = cm:model():world():faction_list()

	for i=0, FactionList:num_items()-1 do
        local factionI = FactionList:item_at(i)
        if (
            factionI:is_null_interface() == false and
            factionI:is_dead() == false and
            factionI:is_rebel() == false and
            factionI:is_human() == false 
            )
        then
            if factionI:can_be_human() == true then
                saf_out("apply_changeling_buff apply yes: "..tostring(factionI:name()))
                cm:apply_effect_bundle("changeling_debuff_ai", factionI:name(), 0)
            else
                saf_out("apply_changeling_buff apply no: "..tostring(factionI:name()))
            end
        end
	end
end

local function chaosCap()
    saf_out("Cap2 start")
    
    judgePlayerContainsChaos()
    
    if mct_setting.isChaosWarriorFactionSpecialEnhancementsCheckbox then
        if isPlayersContainsChaos == 0 then
            for k, fc in pairs(factionsOfSAFAI.settle_chaos) do
                cm:apply_effect_bundle("chaos_buff_ai", fc, 0)
            end
        end
    end
    
    if mct_setting.isAdditionalInitialFactionbasedDiplomaticCheckbox then
        if isPlayersContainsChaos == 0 then
            cm:force_grant_military_access("wh_dlc08_nor_norsca", "wh_dlc08_nor_wintertooth", false);
            cm:force_grant_military_access("wh_dlc08_nor_wintertooth", "wh_dlc08_nor_norsca", false);
            cm:force_alliance("wh_main_chs_chaos", "wh3_dlc23_chd_astragoth", false);
            cm:force_alliance("wh3_dlc23_chd_zhatan", "wh3_dlc20_chs_vilitch", false);
            
            cm:force_make_vassal("wh_main_chs_chaos", "wh3_main_dae_daemon_prince")
            cm:force_make_vassal("wh3_dlc20_chs_sigvald", "wh3_main_sla_subtle_torture")
            cm:force_make_vassal("wh_main_chs_chaos", "wh2_dlc15_skv_clan_ferrik")
            
            local cst_sar = cm:get_faction("wh2_dlc11_cst_pirates_of_sartosa");
            if not cst_sar:is_human() then
                cm:force_alliance("wh2_dlc11_cst_pirates_of_sartosa", "wh2_main_skv_clan_skryre", false);
                local wh_main_dwf_karak_izor = cm:get_faction("wh_main_dwf_karak_izor");
                if not wh_main_dwf_karak_izor:is_human() then
                    saf_force_declare_war("wh_main_dwf_karak_izor", "wh2_main_skv_clan_skryre", false, false);
                end
                
                local wh2_dlc14_brt_chevaliers_de_lyonesse = cm:get_faction("wh2_dlc14_brt_chevaliers_de_lyonesse");
                if not wh2_dlc14_brt_chevaliers_de_lyonesse:is_human() then
                    saf_force_declare_war("wh2_dlc14_brt_chevaliers_de_lyonesse", "wh2_dlc11_cst_pirates_of_sartosa", false, false);
                end
            end
            
            local wh2_dlc17_dwf_thorek_ironbrow = cm:get_faction("wh2_dlc17_dwf_thorek_ironbrow");
            if not wh2_dlc17_dwf_thorek_ironbrow:is_human() then
                saf_force_declare_war("wh2_dlc17_dwf_thorek_ironbrow", "wh3_main_kho_exiles_of_khorne", false, false);
                saf_force_declare_war("wh2_dlc17_dwf_thorek_ironbrow", "wh2_dlc17_bst_malagor", false, false);
            end
            
            local wh2_dlc17_dwf_thorek_ironbrow = cm:get_faction("wh2_dlc17_dwf_thorek_ironbrow");
            if not wh2_dlc17_dwf_thorek_ironbrow:is_human() then
                saf_force_declare_war("wh2_dlc17_dwf_thorek_ironbrow", "wh3_main_kho_exiles_of_khorne", false, false);
                saf_force_declare_war("wh2_dlc17_dwf_thorek_ironbrow", "wh2_dlc17_bst_malagor", false, false);
            end
            
            local wh_main_grn_greenskins = cm:get_faction("wh_main_grn_greenskins");
            if not wh_main_grn_greenskins:is_human() then
                saf_force_declare_war("wh_main_grn_greenskins", "wh3_main_ogr_blood_guzzlers", false, false);
                saf_force_declare_war("wh_main_grn_greenskins", "wh3_main_cth_celestial_loyalists", false, false);
                saf_force_declare_war("wh_main_grn_greenskins", "wh3_main_cth_the_jade_custodians", false, false);
                saf_force_declare_war("wh_main_grn_greenskins", "wh3_main_grn_drippin_fangs", false, false);
            end
            
            local wh_main_grn_orcs_of_the_bloody_hand = cm:get_faction("wh_main_grn_orcs_of_the_bloody_hand");
            if not wh_main_grn_orcs_of_the_bloody_hand:is_human() then
                saf_force_declare_war("wh_main_grn_orcs_of_the_bloody_hand", "wh_main_dwf_barak_varr", false, false);
                saf_force_declare_war("wh_main_grn_scabby_eye", "wh_main_grn_orcs_of_the_bloody_hand", false, false);
                saf_force_declare_war("wh_main_grn_orcs_of_the_bloody_hand", "wh_main_grn_top_knotz", false, false);
            end
            
            cm:force_make_trade_agreement("wh3_main_kho_exiles_of_khorne", "wh2_main_skv_clan_mors");
            cm:force_make_trade_agreement("wh_main_chs_chaos", "wh3_dlc23_chd_astragoth");
            cm:force_make_trade_agreement("wh3_main_dae_daemon_prince", "wh_main_chs_chaos");
            cm:force_make_trade_agreement("wh3_dlc23_chd_zhatan", "wh3_dlc20_chs_vilitch");
            cm:force_make_trade_agreement("wh3_dlc23_chd_zhatan", "wh3_dlc20_nor_yusak");
            cm:force_make_trade_agreement("wh3_dlc23_chd_legion_of_azgorh", "wh3_main_nur_poxmakers_of_nurgle");
            
            saf_force_declare_war("wh3_main_chs_khazag", "wh3_dlc20_chs_vilitch", false, false)
            saf_force_declare_war("wh3_main_cth_imperial_wardens", "wh3_dlc20_chs_vilitch", false, false)
            saf_force_declare_war("wh3_main_nur_maggoth_kin", "wh_main_chs_chaos", false, false)
            saf_force_declare_war("wh3_main_kho_bloody_sword", "wh_main_chs_chaos", false, false)
            saf_force_declare_war("wh3_main_ksl_ropsmenn_clan", "wh_main_chs_chaos", false, false)
            saf_force_declare_war("wh_dlc08_nor_goromadny_tribe", "wh_main_chs_chaos", false, false)
            saf_force_declare_war("wh_main_emp_middenland", "wh3_dlc20_chs_festus", false, false)
            saf_force_declare_war("wh_main_emp_ostland", "wh3_dlc20_chs_azazel", false, false)
            saf_force_declare_war("wh3_main_ksl_ropsmenn_clan", "wh3_dlc20_chs_azazel", false, false)
            saf_force_declare_war("wh3_main_tze_all_seeing_eye", "wh3_main_dae_daemon_prince", false, false)
            saf_force_declare_war("wh3_main_kho_bloody_sword", "wh3_main_dae_daemon_prince", false, false)
            saf_force_declare_war("wh3_main_ksl_ropsmenn_clan", "wh3_main_dae_daemon_prince", false, false)
            saf_force_declare_war("wh3_main_nur_septic_claw", "wh3_main_dae_daemon_prince", false, false)
            saf_force_declare_war("wh_main_dwf_kraka_drak", "wh3_main_dae_daemon_prince", false, false)
            saf_force_declare_war("wh_main_emp_ostland", "wh3_main_dae_daemon_prince", false, false)
            saf_force_declare_war("wh_main_nor_varg", "wh3_main_dae_daemon_prince", false, false)
            saf_force_declare_war("wh2_main_hef_cothique", "wh3_main_chs_shadow_legion", false, false)
            saf_force_declare_war("wh_main_brt_lyonesse", "wh3_main_chs_shadow_legion", false, false)
            saf_force_declare_war("wh_main_nor_varg", "wh3_dlc20_chs_sigvald", false, false)
            saf_force_declare_war("wh3_main_tze_broken_wheel", "wh3_dlc20_chs_sigvald", false, false)
            saf_force_declare_war("wh3_main_kho_crimson_skull", "wh3_dlc20_chs_sigvald", false, false)
            
            saf_force_declare_war("wh3_main_ogr_lazarghs", "wh3_dlc25_nur_tamurkhan", false, false)
            saf_force_declare_war("wh3_main_ogr_mountaineaters", "wh3_dlc25_nur_tamurkhan", false, false)
            saf_force_declare_war("wh3_dlc23_chd_minor_faction", "wh3_dlc25_nur_tamurkhan", false, false)
            
            saf_force_declare_war("wh_main_teb_tilea", "wh2_main_skv_clan_skryre", false, false)
            saf_force_declare_war("wh_main_teb_border_princes", "wh2_main_skv_clan_skryre", false, false)
            saf_force_declare_war("wh_main_dwf_karak_hirn", "wh2_main_skv_clan_skryre", false, false)
            saf_force_declare_war("wh3_main_ie_vmp_sires_of_mourkain", "wh2_main_skv_clan_mors", false, false)
            saf_force_declare_war("wh3_main_cth_the_jade_custodians", "wh3_main_skv_clan_krizzor", false, false)
            saf_force_declare_war("wh_main_grn_top_knotz", "wh2_main_skv_clan_mors", false, false)
            saf_force_declare_war("wh_main_dwf_karak_azul", "wh2_main_skv_clan_mors", false, false)
            saf_force_declare_war("wh3_dlc23_chd_minor_faction", "wh2_dlc09_skv_clan_rictus", false, false)
            saf_force_declare_war("wh_main_dwf_karak_azul", "wh2_dlc09_skv_clan_rictus", false, false)
            saf_force_declare_war("wh3_main_cth_the_jade_custodians", "wh2_main_skv_clan_eshin", false, false)
            saf_force_declare_war("wh_main_emp_ostland", "wh2_main_skv_clan_moulder", false, false)
            saf_force_declare_war("wh_main_emp_talabecland", "wh2_main_skv_clan_moulder", false, false)
            
            saf_force_declare_war("wh3_main_ie_vmp_sires_of_mourkain", "wh3_main_kho_exiles_of_khorne", false, false)
            saf_force_declare_war("wh2_main_grn_arachnos", "wh3_main_kho_exiles_of_khorne", false, false)
            saf_force_declare_war("wh2_main_hef_cothique", "wh3_main_sla_seducers_of_slaanesh", false, false)
            saf_force_declare_war("wh3_main_sla_rapturous_excess", "wh3_main_tze_oracles_of_tzeentch", false, false)
            saf_force_declare_war("wh2_main_lzd_zlatan", "wh3_main_tze_oracles_of_tzeentch", false, false)
            saf_force_declare_war("wh3_main_tze_broken_wheel", "wh3_dlc25_nur_epidemius", false, false)
            
            saf_force_declare_war("wh3_main_cth_imperial_wardens", "wh3_dlc23_chd_zhatan", false, false)
            saf_force_declare_war("wh3_dlc23_chd_minor_faction", "wh3_dlc23_chd_legion_of_azgorh", false, false)
            saf_force_declare_war("wh3_main_vmp_lahmian_sisterhood", "wh3_dlc23_chd_astragoth", false, false)
            saf_force_declare_war("wh3_main_grn_drippin_fangs", "wh3_dlc23_chd_astragoth", false, false)
            
            saf_force_declare_war("wh3_main_wef_laurelorn", "wh_dlc03_bst_beastmen", false, false)
            saf_force_declare_war("wh_dlc05_wef_torgovann", "wh_dlc03_bst_beastmen", false, false)
            saf_force_declare_war("wh_dlc05_wef_wydrioth", "wh_dlc03_bst_beastmen", false, false)
            saf_force_declare_war("wh_dlc05_wef_torgovann", "wh_dlc05_bst_morghur_herd", false, false)
            saf_force_declare_war("wh_dlc05_wef_wydrioth", "wh_dlc05_bst_morghur_herd", false, false)
            saf_force_declare_war("wh_dlc05_wef_torgovann", "wh2_dlc17_bst_malagor", false, false)
            saf_force_declare_war("wh_dlc05_wef_wydrioth", "wh2_dlc17_bst_malagor", false, false)
            saf_force_declare_war("wh2_main_wef_bowmen_of_oreon", "wh2_dlc17_bst_malagor", false, false)
            saf_force_declare_war("wh2_dlc16_grn_creeping_death", "wh2_dlc17_bst_malagor", false, false)
            
            saf_force_declare_war("wh_main_grn_crooked_moon", "wh3_main_grn_drippin_fangs", false, false);
            
            local ksl_rop = cm:get_faction("wh3_main_ksl_the_ice_court");
            if not ksl_rop:is_human() then
                saf_force_declare_war("wh3_main_ksl_the_ice_court", "wh_main_chs_chaos", false, false)
                saf_force_declare_war("wh3_main_ksl_the_ice_court", "wh3_main_dae_daemon_prince", false, false)
                saf_force_declare_war("wh3_main_ksl_the_ice_court", "wh3_dlc20_chs_azazel", false, false)
            end
            
            local ksl_orthodoxy = cm:get_faction("wh3_main_ksl_the_great_orthodoxy");
            if not ksl_orthodoxy:is_human() then
                saf_force_declare_war("wh3_main_ksl_the_great_orthodoxy", "wh_main_chs_chaos", false, false)
                saf_force_declare_war("wh3_main_ksl_the_great_orthodoxy", "wh3_dlc25_nur_epidemius", false, false)
                saf_force_declare_war("wh3_main_ksl_the_great_orthodoxy", "wh3_main_dae_daemon_prince", false, false)
                saf_force_declare_war("wh3_main_ksl_the_great_orthodoxy", "wh3_dlc20_chs_azazel", false, false)
            end
            
            local ksl_ursun_revivalists = cm:get_faction("wh3_main_ksl_ursun_revivalists");
            if not ksl_ursun_revivalists:is_human() then
                saf_force_declare_war("wh3_main_ksl_ursun_revivalists", "wh_main_chs_chaos", false, false)
                saf_force_declare_war("wh3_main_ksl_ursun_revivalists", "wh3_main_dae_daemon_prince", false, false)
            end
            
            local jade_custodians = cm:get_faction("wh3_main_cth_the_jade_custodians");
            local jiangshi_rebels = cm:get_faction("wh3_dlc21_vmp_jiangshi_rebels");
            if not jade_custodians:is_human() and not jiangshi_rebels:is_human()  then
                saf_force_declare_war("wh3_main_cth_the_jade_custodians", "wh3_dlc21_vmp_jiangshi_rebels", false, false)
            end
            
            local wef_spirits_of_shanlin = cm:get_faction("wh3_dlc21_wef_spirits_of_shanlin");
            local cth_burning_wind_nomads = cm:get_faction("wh3_main_cth_burning_wind_nomads");
            if not wef_spirits_of_shanlin:is_human() and not cth_burning_wind_nomads:is_human()  then
                saf_force_declare_war("wh3_dlc21_wef_spirits_of_shanlin", "wh3_main_cth_burning_wind_nomads", false, false)
                saf_force_declare_war("wh3_dlc21_nor_wyrmkins", "wh3_main_cth_burning_wind_nomads", false, false)
                saf_force_declare_war("wh3_main_cth_celestial_loyalists", "wh3_dlc21_nor_wyrmkins", false, false)
            end
            
            local wh_main_emp_nordland = cm:get_faction("wh_main_emp_nordland");
            local nor_norsca = cm:get_faction("wh_dlc08_nor_norsca");
            local wh_main_emp_marienburg = cm:get_faction("wh_main_emp_marienburg");
            local wh_main_emp_ostland = cm:get_faction("wh_main_emp_ostland");
            local wh_dlc08_nor_wintertooth = cm:get_faction("wh_dlc08_nor_wintertooth");
            
            local wh_main_nor_skaeling = cm:get_faction("wh_main_nor_skaeling");
            if not wh_main_emp_nordland:is_human() and not nor_norsca:is_human() and not wh_main_emp_marienburg:is_human() and not wh_main_emp_ostland:is_human() and not wh_dlc08_nor_wintertooth:is_human() and not wh_main_nor_skaeling:is_human() then
                saf_force_declare_war("wh_main_emp_nordland", "wh_dlc08_nor_norsca", false, false)
                saf_force_declare_war("wh_main_emp_marienburg", "wh_dlc08_nor_norsca", false, false)
                saf_force_declare_war("wh_main_emp_ostland", "wh_dlc08_nor_norsca", false, false)
                saf_force_declare_war("wh_main_nor_skaeling", "wh_dlc08_nor_norsca", false, false)
                saf_force_declare_war("wh_main_emp_nordland", "wh_dlc08_nor_wintertooth", false, false)
                saf_force_declare_war("wh_main_emp_ostland", "wh_dlc08_nor_wintertooth", false, false)
            end
            
            local wh2_main_hef_yvresse = cm:get_faction("wh2_main_hef_yvresse");
            if not wh2_main_hef_yvresse:is_human() then
                saf_force_declare_war("wh2_main_hef_yvresse", "wh3_main_chs_shadow_legion", false, false)
                saf_force_declare_war("wh2_main_hef_yvresse", "wh3_main_sla_seducers_of_slaanesh", false, false)
            end
            
            if not cm:get_faction("wh2_main_def_cult_of_pleasure"):is_human() then
                cm:force_alliance("wh2_main_def_cult_of_pleasure", "wh3_main_sla_seducers_of_slaanesh", false);
            end
            
            local wh2_main_hef_nagarythe = cm:get_faction("wh2_main_hef_nagarythe");
            if not wh2_main_hef_nagarythe:is_human() then
                saf_force_declare_war("wh2_main_hef_nagarythe", "wh3_dlc20_chs_sigvald", false, false)
            end
            
            local wh2_main_def_hag_graef = cm:get_faction("wh2_main_def_hag_graef");
            if not wh2_main_def_hag_graef:is_human() then
                cm:force_grant_military_access("wh2_main_def_hag_graef", "wh3_main_dae_daemon_prince", false)
                cm:force_grant_military_access("wh3_main_dae_daemon_prince", "wh2_main_def_hag_graef", false)
                saf_force_declare_war("wh_main_nor_varg", "wh2_main_def_hag_graef", false, false)
                saf_force_declare_war("wh3_main_kho_crimson_skull", "wh2_main_def_hag_graef", false, false)
                saf_force_declare_war("wh_main_dwf_kraka_drak", "wh2_main_def_hag_graef", false, false)
            end
            
            local wh2_dlc11_def_the_blessed_dread = cm:get_faction("wh2_dlc11_def_the_blessed_dread");
            if not wh2_dlc11_def_the_blessed_dread:is_human() then
                cm:force_grant_military_access("wh2_main_skv_clan_eshin", "wh2_dlc11_def_the_blessed_dread", false)
                cm:force_grant_military_access("wh2_dlc11_def_the_blessed_dread", "wh2_main_skv_clan_eshin", false)
                saf_force_declare_war("wh3_main_cth_eastern_river_lords", "wh2_dlc11_def_the_blessed_dread", false, false)
                saf_force_declare_war("wh3_main_cth_celestial_loyalists", "wh2_dlc11_def_the_blessed_dread", false, false)
            end
            
            local wh2_main_def_naggarond = cm:get_faction("wh2_main_def_naggarond");
            local wh2_main_def_har_ganeth = cm:get_faction("wh2_main_def_har_ganeth");
            if not wh2_main_def_naggarond :is_human() and not wh2_main_def_har_ganeth:is_human() then
                saf_force_declare_war("wh2_main_def_ghrond", "wh2_main_def_naggarond", false, false)
                saf_force_declare_war("wh2_main_def_deadwood_sentinels", "wh2_main_def_naggarond", false, false)
                saf_force_declare_war("wh2_main_def_clar_karond", "wh2_main_def_naggarond", false, false)
                saf_force_declare_war("wh2_main_def_ghrond", "wh2_main_def_har_ganeth", false, false)
                saf_force_declare_war("wh2_main_def_deadwood_sentinels", "wh2_main_def_har_ganeth", false, false)
            end
            
            local wh_main_brt_carcassonne = cm:get_faction("wh_main_brt_carcassonne");
            if not wh_main_brt_carcassonne:is_human() then
                saf_force_declare_war("wh_main_brt_carcassonne", "wh2_main_skv_clan_skryre", false, false)
                saf_force_declare_war("wh_main_brt_carcassonne", "wh_dlc05_bst_morghur_herd", false, false)
            end
            
            local wh2_dlc15_grn_bonerattlaz = cm:get_faction("wh2_dlc15_grn_bonerattlaz");
            if not wh2_dlc15_grn_bonerattlaz:is_human() then
                saf_force_declare_war("wh2_dlc15_grn_bonerattlaz", "wh_main_emp_ostermark", false, false)
                saf_force_declare_war("wh2_dlc15_grn_bonerattlaz", "wh_main_emp_talabecland", false, false)
            end
            
            local wh_main_vmp_schwartzhafen = cm:get_faction("wh_main_vmp_schwartzhafen");
            if not wh_main_vmp_schwartzhafen:is_human() then
                saf_force_declare_war("wh_main_vmp_schwartzhafen", "wh_main_emp_stirland", false, false)
                saf_force_declare_war("wh_main_vmp_schwartzhafen", "wh_main_dwf_zhufbar", false, false)
            end
            
            local wh3_dlc25_dwf_malakai = cm:get_faction("wh3_dlc25_dwf_malakai");
            if not wh3_dlc25_dwf_malakai:is_human() then
                saf_force_declare_war("wh3_dlc25_nur_epidemius", "wh3_dlc25_dwf_malakai", false, false)
                saf_force_declare_war("wh3_main_dae_daemon_prince", "wh3_dlc25_dwf_malakai", false, false)
            end
            
            local wh2_dlc16_wef_sisters_of_twilight = cm:get_faction("wh2_dlc16_wef_sisters_of_twilight");
            if not wh2_dlc16_wef_sisters_of_twilight:is_human() then
                saf_force_declare_war("wh2_dlc17_bst_taurox", "wh2_dlc16_wef_sisters_of_twilight", false, false)
            end
            
            local wh2_dlc16_wef_drycha = cm:get_faction("wh2_dlc16_wef_drycha");
            if not wh2_dlc16_wef_drycha:is_human() then
                saf_force_declare_war("wh_dlc03_bst_beastmen", "wh2_dlc16_wef_drycha", false, false)
            end
            
            if not cm:get_faction("wh2_dlc09_tmb_lybaras"):is_human() then
                saf_force_declare_war("wh2_dlc09_tmb_lybaras", "wh2_main_skv_clan_mors", false, false)
                saf_force_declare_war("wh2_dlc09_tmb_lybaras", "wh3_main_kho_exiles_of_khorne", false, false)
            end
            
            if not cm:get_faction("wh_main_emp_wissenland"):is_human() then
                saf_force_declare_war("wh_main_emp_wissenland", "wh3_dlc25_nur_tamurkhan", false, false)
            end
            
            if not cm:get_faction("wh3_main_vmp_caravan_of_blue_roses"):is_human() then
                saf_force_declare_war("wh3_main_vmp_caravan_of_blue_roses", "wh3_dlc25_nur_tamurkhan", false, false)
            end
            
            if not cm:get_faction("wh2_main_hef_avelorn"):is_human() then
                saf_force_declare_war("wh2_main_hef_avelorn", "wh2_main_def_har_ganeth", false, false)
                saf_force_declare_war("wh2_main_hef_avelorn", "wh2_dlc17_bst_taurox", false, false)
            end
            
        else
            local wh3_dlc24_tze_the_deceivers = cm:get_faction("wh3_dlc24_tze_the_deceivers");
            local wh3_main_sla_seducers_of_slaanesh = cm:get_faction("wh3_main_sla_seducers_of_slaanesh");
            if wh3_dlc24_tze_the_deceivers:is_human() or wh3_main_sla_seducers_of_slaanesh:is_human() then
                apply_changeling_buff()
            end
            
            saf_force_declare_war("wh3_main_sla_rapturous_excess", "wh2_main_hef_tor_elasor", false, false)

            local wh_main_brt_bretonnia = cm:get_faction("wh_main_brt_bretonnia");
            if not wh_main_brt_bretonnia:is_human() then
                saf_force_declare_war("wh_main_emp_marienburg", "wh_main_brt_bretonnia", false, false)
                saf_force_declare_war("wh_main_brt_artois", "wh_main_brt_bretonnia", false, false)
            end
            
            if not cm:get_faction("wh_main_emp_empire"):is_human() then
                saf_force_declare_war("wh_main_emp_marienburg", "wh_main_emp_empire", false, false)
                saf_force_declare_war("wh_main_emp_talabecland", "wh_main_emp_empire", false, false)
                saf_force_declare_war("wh_dlc03_grn_black_pit", "wh_main_emp_empire", false, false)
            end
            
            if not cm:get_faction("wh3_main_cth_the_northern_provinces"):is_human() then
                saf_force_declare_war("wh3_main_cth_dissenter_lords_of_jinshen", "wh3_main_cth_the_northern_provinces", false, false)
            end
            
            if not cm:get_faction("wh3_main_cth_the_western_provinces"):is_human() then
                saf_force_declare_war("wh3_main_cth_the_jade_custodians", "wh3_main_cth_the_western_provinces", false, false)
            end
            
            if not cm:get_faction("wh2_main_hef_eataine"):is_human() and not cm:get_faction("wh2_main_hef_avelorn"):is_human()  then
                saf_force_declare_war("wh2_main_hef_caledor", "wh2_main_hef_eataine", false, false)
            end
            
            if not cm:get_faction("wh3_main_cth_eastern_river_lords"):is_human() and not cm:get_faction("wh2_dlc13_lzd_spirits_of_the_jungle"):is_human()  then
                saf_force_declare_war("wh3_main_cth_eastern_river_lords", "wh2_dlc13_lzd_spirits_of_the_jungle", false, false)
            end
            
            if not cm:get_faction("wh3_main_skv_clan_verms"):is_human() and not cm:get_faction("wh2_dlc15_hef_imrik"):is_human()  then
                saf_force_declare_war("wh3_main_skv_clan_verms", "wh2_dlc15_hef_imrik", false, false)
            end
            
            if not cm:get_faction("wh2_main_hef_order_of_loremasters"):is_human() then
                saf_force_declare_war("wh2_main_hef_order_of_loremasters", "wh2_main_lzd_zlatan", false, false)
            end
            
            if not cm:get_faction("wh2_dlc17_lzd_oxyotl"):is_human() then
                saf_force_declare_war("wh2_dlc17_lzd_oxyotl", "wh3_main_tze_flaming_scribes", false, false)
            end
            
            if not cm:get_faction("wh2_main_lzd_hexoatl"):is_human() then
                saf_force_declare_war("wh2_main_lzd_hexoatl", "wh2_dlc16_skv_clan_gritus", false, false)
                saf_force_declare_war("wh2_main_lzd_hexoatl", "wh2_main_emp_new_world_colonies", false, false)
                
                if not cm:get_faction("wh2_main_def_cult_of_pleasure"):is_human() and not cm:get_faction("wh2_main_hef_eataine"):is_human()  then
                    saf_force_declare_war("wh2_main_lzd_hexoatl", "wh2_main_def_cult_of_pleasure", false, false)
                    saf_force_declare_war("wh2_main_hef_eataine", "wh2_main_def_cult_of_pleasure", false, false)
                    cm:force_make_trade_agreement("wh2_main_lzd_hexoatl", "wh2_main_hef_eataine");
                end
            end
            
            if not cm:get_faction("wh2_dlc12_lzd_cult_of_sotek"):is_human() then
                saf_force_declare_war("wh2_dlc12_lzd_cult_of_sotek", "wh2_main_skv_clan_pestilens", false, false)
                saf_force_declare_war("wh2_dlc12_lzd_cult_of_sotek", "wh3_main_tmb_deserters_of_khatep", false, false)
                saf_force_declare_war("wh2_dlc12_lzd_cult_of_sotek", "wh2_main_lzd_southern_sentinels", false, false)
            end
            
            if not cm:get_faction("wh2_main_lzd_itza"):is_human() then
                saf_force_declare_war("wh2_main_lzd_itza", "wh2_main_skv_clan_pestilens", false, false)
            end
            
            if not cm:get_faction("wh2_main_lzd_tlaqua"):is_human() and not cm:get_faction("wh2_main_hef_order_of_loremasters"):is_human() and not cm:get_faction("wh3_main_tze_oracles_of_tzeentch"):is_human()  then
                saf_force_declare_war("wh2_main_lzd_zlatan", "wh2_main_lzd_tlaqua", false, false)
                saf_force_declare_war("wh3_main_tze_oracles_of_tzeentch", "wh2_main_lzd_tlaqua", false, false)
                saf_force_declare_war("wh3_main_tze_oracles_of_tzeentch", "wh2_main_hef_order_of_loremasters", false, false)
            end
            
            local wh3_main_ksl_the_ice_court = cm:get_faction("wh3_main_ksl_the_ice_court");
            local wh2_main_skv_clan_moulder = cm:get_faction("wh2_main_skv_clan_moulder");
            local wh3_dlc25_dwf_malakai = cm:get_faction("wh3_dlc25_dwf_malakai");
            local wh_main_emp_wissenland = cm:get_faction("wh_main_emp_wissenland");
            
            if not wh3_main_ksl_the_ice_court:is_human() then
                saf_force_declare_war("wh3_main_ksl_the_ice_court", "wh_main_emp_ostermark", false, false)
                saf_force_declare_war("wh3_main_ksl_the_ice_court", "wh_dlc08_nor_goromadny_tribe", false, false)
            end
            
            local wh3_main_ksl_the_great_orthodoxy = cm:get_faction("wh3_main_ksl_the_great_orthodoxy");
            if not wh3_main_ksl_the_great_orthodoxy:is_human() then
                saf_force_declare_war("wh3_main_ksl_the_great_orthodoxy", "wh_main_emp_ostland", false, false)
                saf_force_declare_war("wh3_main_ksl_the_great_orthodoxy", "wh_main_emp_nordland", false, false)
            end
            
            if not wh2_main_skv_clan_moulder:is_human() then
                saf_force_declare_war("wh3_main_ksl_the_great_orthodoxy", "wh2_main_skv_clan_moulder", false, false)
                saf_force_declare_war("wh3_main_ksl_the_ice_court", "wh2_main_skv_clan_moulder", false, false)
            end
            
            if not wh3_dlc25_dwf_malakai:is_human() then
                saf_force_declare_war("wh3_dlc25_dwf_malakai", "wh_dlc08_nor_goromadny_tribe", false, false)
            end
            
            if not wh_main_emp_wissenland:is_human() then
                saf_force_declare_war("wh_main_emp_wissenland", "wh_main_emp_averland", false, false)
                saf_force_declare_war("wh_main_emp_wissenland", "wh_main_grn_black_venom", false, false)
            end
            
            if not cm:get_faction("wh_dlc05_wef_torgovann"):is_human() and not cm:get_faction("wh_dlc05_wef_wydrioth"):is_human()  then
                saf_force_declare_war("wh_dlc05_wef_torgovann", "wh_dlc05_wef_wood_elves", false, false)
                saf_force_declare_war("wh_dlc05_wef_torgovann", "wh_dlc05_wef_argwylon", false, false)
                saf_force_declare_war("wh_dlc05_wef_wydrioth", "wh_dlc05_wef_wood_elves", false, false)
                saf_force_declare_war("wh_dlc05_wef_wydrioth", "wh_dlc05_wef_argwylon", false, false)
            end
            
            if not cm:get_faction("wh2_dlc17_bst_taurox"):is_human() then
                saf_force_declare_war("wh2_main_hef_avelorn", "wh2_main_def_har_ganeth", false, false)
                saf_force_declare_war("wh2_main_hef_avelorn", "wh2_dlc17_bst_taurox", false, false)
            end
        end
    end
    
    saf_out("Cap2 end")
end

local function chdCap()
    saf_out("Cap3 start")
    for k, fc in pairs(factionsOfSAFAI.chd) do
        local faction = cm:get_faction(fc);
        if faction == false or faction:is_dead() or cm:get_faction(fc):is_human() then
            saf_out("Cap3 isDead Or Human Faction:"..fc)
        else
            cm:apply_effect_bundle("chd_buff_ai", fc, 0)
        end
    end;
    saf_out("Cap3 end")
end

local function chaosCap2()
    saf_out("Cap4 start")
    for k, fc in pairs(factionsOfSAFAI.settle_chaos) do
        local faction = cm:get_faction(fc);
        if faction == false or faction:is_dead() then
            saf_out("Cap4 isDead Faction:"..fc)
        else
            cm:apply_effect_bundle("chaos_buff_ai2", fc, 0)
        end
    end;
    saf_out("Cap4 end")
end

local function saf_buff_ai()
    if cm:is_new_game() and cm:get_campaign_name() == "main_warhammer" then
        beastmenArmyCap()
        chaosCap()
    end;
end

local function saf_buff_ai_mid()
    core:add_listener(
        "MidCampaign",
        "WorldStartRound",
        true,
        function ()
            --saf_out("Cap MidCampaign Start")
            local roundJudge = cm:turn_number()
            --saf_out("Cap MidCampaign Judge Round: "..tostring(roundJudge))
            if roundJudge == 32 and cm:get_campaign_name() == "main_warhammer" then
                --saf_out("Cap MidCampaign 32")
                if mct_setting.isChaosDwarfFactionSpecialEnhancementsCheckbox then
                    chdCap()
                end
                judgePlayerContainsChaos()
                if isPlayersContainsChaos == 0 and mct_setting.isChaosWarriorFactionSpecialEnhancementsCheckbox then
                    chaosCap2()
                end
            end
            --saf_out("Cap MidCampaign End")
        end,
        true
    );
end

cm:add_first_tick_callback_new(function() saf_buff_ai() end);
cm:add_pre_first_tick_callback(function() saf_buff_ai_mid() end);

core:remove_listener("SAFAI_CAP_MCT_INI")
core:add_listener(
    "SAFAI_CAP_MCT_INI",
    "MctInitialized",
    true,
    function(context)
        local mct = context:mct()
        update_settings(mct)
    end,
    true
)

core:remove_listener("SAFAI_CAP_MCT_FINAL")
core:add_listener(
	"SAFAI_CAP_MCT_FINAL",
	"MctFinalized",
	true,
	function(context)
		local mct = context:mct()
        update_settings(mct)
	end,
	true
)
