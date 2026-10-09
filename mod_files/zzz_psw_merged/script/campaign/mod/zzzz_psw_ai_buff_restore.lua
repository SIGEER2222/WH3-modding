-- One-time restore: re-apply PSW tianzai/atk/def buffs to ordinary AI armies.
-- The earlier scope-fix stripped these from all non-boss AI forces and disabled
-- the psw_main_boss_nsca_rq listener. The listener only fires for newly
-- recruited characters, so this pass re-runs the same roll for every existing
-- AI character with a military force. psw_tfmw_all_AI_* escalation only
-- upgrades forces that already carry a base psw_tfmw_gongji_/fangyu_ bundle,
-- so without this pass stripped armies never scale again.
-- Runs once per save via cm:get_saved_value("psw_ai_buff_restore_v1_done").

local PSW_RESTORE_BOSS_FACTIONS = {
    wh3_dlc23_chd_chaos_dwarfs_qb1 = true,
    wh3_dlc23_chd_chaos_dwarfs_qb2 = true,
    wh_main_chs_chaos_qb1 = true,
    wh_main_chs_chaos_qb2 = true,
    wh_main_chs_chaos_qb3 = true,
    wh_main_grn_greenskins_qb1 = true,
    wh_dlc05_wef_wood_elves_qb1 = true,
    wh_dlc05_wef_wood_elves_qb2 = true,
    wh2_main_hef_high_elves_qb1 = true,
    wh2_main_def_dark_elves_qb1 = true,
    wh_dlc03_bst_beastmen_qb1 = true,
    wh_dlc03_bst_beastmen_qb2 = true,
    wh2_main_lzd_lizardmen_qb1 = true,
    wh3_main_ksl_kislev_qb1 = true,
}

local PSW_RESTORE_BOSS_UNIT_POOL = {
    "psw_boss_wh2_dlc10_skv_mon_hell_pit_abomination_boss",
    "psw_boss_wh2_dlc17_lzd_mon_dread_saurian_qb_boss",
    "psw_boss_wh2_dlc10_lzd_mon_carnosaur_boss",
    "psw_boss_wh2_dlc10_def_mon_war_hydra_boss",
    "psw_boss_wh_dlc08_wef_mon_treeman_boss",
    "psw_boss_wh_dlc08_nor_mon_frost_wyrm_boss",
    "psw_boss_wh_dlc08_grn_mon_giant_boss",
    "psw_boss_wh_dlc08_wef_forest_dragon_boss",
    "psw_boss_wh_dlc08_bst_mon_cygor_boss",
    "psw_boss_wh2_dlc15_hef_mon_black_dragon_imrik_boss",
    "psw_boss_wh2_dlc15_hef_mon_sun_dragon_imrik_boss",
    "psw_boss_wh2_dlc15_hef_mon_forest_dragon_imrik_boss",
    "psw_boss_wh2_dlc15_hef_mon_moon_dragon_imrik_boss",
    "psw_boss_wh2_dlc15_hef_mon_star_dragon_imrik_boss",
    "psw_dlc6_boss_shiou",
    "psw_dlc6_boss_zhumu",
    "psw_dlc7_boss_xieweishi",
    "psw_dlc7_boss_jishe",
    "psw_dlc7_boss_fengyu",
    "psw_dlc7_boss_tujiu",
    "psw_dlc7_boss_xiaobudian",
    "psw_dlc7_boss_heilong",
    "psw_dlc7_boss_zhizhe",
}

local PSW_RESTORE_TZFS_BUNDLES = {
    "psw_tzfs_bjndmy",
    "psw_tzfs_zzljs",
    "psw_tzfs_shizhu",
    "psw_tzfs_qhs",
    "psw_tzfs_hxhd",
    "psw_tzfs_hyfb",
    "psw_tzfs_kwnz",
    "psw_tzfs_lcdr",
}

local function psw_restore_yihua_bundle_pool()
    if psw_main_data.global_data.set_psw_main_nandu5 then
        return {
            "jnz_yh_mowang",
            "jnz_yh_zhanshen",
            "jnz_yh_juewang",
            "jnz_yh_shenjiang",
            "jnz_yh_kuanglan",
            "jnz_yh_shuaixiu",
            "jnz_yh_zhongyan",
            "jnz_yh_qiyuan",
            "jnz_yh_chiyan",
            "jnz_yh_yongheng",
            "jnz_yh_xiaoan",
            "jnz_yh_yuanchu",
        }
    end
    return {
        "jnz_yh_mowang_3",
        "jnz_yh_zhanshen_3",
        "jnz_yh_juewang_3",
        "jnz_yh_shenjiang_3",
        "jnz_yh_kuanglan_3",
        "jnz_yh_shuaixiu_3",
        "jnz_yh_zhongyan_3",
        "jnz_yh_qiyuan_3",
        "jnz_yh_chiyan_3",
        "jnz_yh_yongheng_3",
        "jnz_yh_xiaoan_3",
        "jnz_yh_yuanchu_3",
    }
end

local function psw_restore_force_has_any_bundle(force, bundles)
    for i = 1, #bundles do
        if force:has_effect_bundle(bundles[i]) then
            return true
        end
    end
    return false
end

local function psw_restore_force_has_fangyu(force)
    for i = 1, 50 do
        if force:has_effect_bundle("psw_tfmw_fangyu_" .. i) then
            return true
        end
    end
    return false
end

local function psw_restore_remove_character_bundles(character, bundles)
    for i = 1, #bundles do
        local bundle = bundles[i]
        if character:has_effect_bundle(bundle) then
            cm:remove_effect_bundle_from_character(bundle, character)
        end
    end
end

local function psw_restore_roll_character(character, ctx)
    local force = character:military_force()
    local faction_key = character:faction():name()

    -- nandu4: same boss-unit grant roll as the original listener.
    if ctx.nandu4 then
        for _ = 1, 3 do
            if cm:random_number(100, 1) <= ctx.rq_gailv then
                cm:grant_unit_to_character(
                    cm:char_lookup_str(character),
                    PSW_RESTORE_BOSS_UNIT_POOL[cm:random_number(#PSW_RESTORE_BOSS_UNIT_POOL, 1)]
                )
            end
        end
    end

    local is_have_tianzai = psw_restore_force_has_any_bundle(force, ctx.yihua_bundle)
    if not psw_restore_force_has_fangyu(force) then
        psw_tfmw_apply_initial_atk_def_buff_to_army(character)
    end

    psw_restore_remove_character_bundles(character, ctx.yihua_bundle)
    psw_restore_remove_character_bundles(character, PSW_RESTORE_TZFS_BUNDLES)

    if ctx.tfmw_is_start and faction_key == ctx.mowang_faction_key then
        is_have_tianzai = true
    end

    if is_have_tianzai or ctx.sx == 0 or PSW_RESTORE_BOSS_FACTIONS[faction_key] then
        return
    end
    for _ = 1, ctx.sx do
        local bundle = ctx.yihua_bundle[cm:random_number(#ctx.yihua_bundle)]
        if cm:random_number(100, 1) < ctx.yh_gailv then
            if bundle:starts_with("jnz_yh_xiaoan") then
                cm:military_force_add_temporary_stance(
                    force:command_queue_index(),
                    "MILITARY_FORCE_ACTIVE_STANCE_TYPE_STALKING",
                    0
                )
            end
            cm:apply_effect_bundle_to_character(bundle, character, 0)
            psw_tzfs_suiji_apply(character)
        end
    end
end

local function psw_restore_existing_ai()
    if cm:get_saved_value("psw_ai_buff_restore_v1_done") == 1 then
        return
    end
    local global_data = psw_main_data and psw_main_data.global_data
    if not (global_data and global_data.set_psw_main_nandu3) then
        return
    end
    local turn_number = cm:turn_number()
    local start_turn = 10
    if global_data.set_psw_tianqi_ms_start then
        start_turn = 2
    end
    if turn_number < start_turn then
        return
    end
    local zhongmo = global_data.jishu_zhongmo
    local ctx = {
        nandu4 = global_data.set_psw_main_nandu4,
        rq_gailv = math.min((zhongmo * 0.4 + 4) * (1 - 0.05 * (global_data.psw_main_renshu or 0)), 15),
        yihua_bundle = psw_restore_yihua_bundle_pool(),
        tfmw_is_start = global_data.tfmw_is_start,
        mowang_faction_key = psw_mowang_data and psw_mowang_data.mowang_faction_key,
        sx = turn_number > 20 and 2 or (turn_number > 10 and 1 or 0),
        yh_gailv = math.min(
            (global_data.set_psw_tianqi_ms_start and (zhongmo * 3.5 + 15)) or (zhongmo * 2.5 + 10),
            85
        ),
    }
    local restored = 0
    local factions = cm:model():world():faction_list()
    for i = 0, factions:num_items() - 1 do
        local faction = factions:item_at(i)
        if not faction:is_null_interface() and not faction:is_dead() and not faction:is_human() then
            local characters = faction:character_list()
            for j = 0, characters:num_items() - 1 do
                local character = characters:item_at(j)
                if not character:is_null_interface() and character:has_military_force() then
                    psw_restore_roll_character(character, ctx)
                    restored = restored + 1
                end
            end
        end
    end
    cm:set_saved_value("psw_ai_buff_restore_v1_done", 1)
    out("[psw_ai_restore] re-applied tianzai/atk/def rolls to " .. restored .. " AI characters")
end

cm:add_first_tick_callback(function()
    local ok, err = pcall(psw_restore_existing_ai)
    if not ok then
        out("[psw_ai_restore] ERROR " .. tostring(err))
    end
end)
