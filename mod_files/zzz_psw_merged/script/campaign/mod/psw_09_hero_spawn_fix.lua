-- 扭蛋英雄生成修复：派系领袖养伤/不在场时改用派系主城做生成锚点。
-- 原版 psw_hero_creat_suiji / psw_hero_creat_zixuan 使用 faction_leader:region_data():key()
-- 作为生成区域，领袖养伤（无 region）时生成失败；本文件以同名全局函数覆盖之。

local distance_from_shoudu = 1

local function psw_leader_anchor_valid(faction_leader)
    return not faction_leader:is_null_interface()
        and not faction_leader:is_wounded()
        and not faction_leader:is_at_sea()
        and not faction_leader:region():is_null_interface()
end

-- create_force_with_existing_general() requires a non-empty unit list even
-- when the intended result is a general-only force.  This unit is only a
-- bootstrap entry; it is removed after the existing family member is attached.
local psw_restore_bootstrap_unit = "wh_main_emp_inf_spearmen_0"
local psw_restore_pending = {}
local psw_no_movement_bundle = "wh3_main_bundle_military_upkeep_free_force_no_movement"

-- The merged pack does not always include the original music helper.  A
-- missing optional sound effect must not abort hero creation.
if type(psw_play_dlc_music) ~= "function" then
    function psw_play_dlc_music(key)
        local ok, error_message = pcall(function()
            common.trigger_soundevent("Play_" .. tostring(key))
        end)
        if not ok then
            out("[psw_debug] optional hero music skipped key="
                .. tostring(key) .. " error=" .. tostring(error_message))
        end
    end
    out("[psw_debug] installed fallback psw_play_dlc_music")
end

local function psw_restore_log(message)
    out("[psw_debug] hero force restore: " .. tostring(message))
end

local function psw_restore_valid_character(character)
    return character ~= nil
        and character ~= false
        and not character:is_null_interface()
end

local function psw_restore_movement_for_character(character, reason)
    if not psw_restore_valid_character(character) then
        return false
    end

    local char_cqi = character:command_queue_index()
    local char_lookup = cm:char_lookup_str(character)
    local has_force = false
    local has_no_movement_bundle = false
    local action_points_before = "n/a"

    pcall(function()
        action_points_before = character:action_points_remaining_percent()
    end)
    pcall(function()
        has_force = character:has_military_force()
    end)
    if has_force then
        pcall(function()
            has_no_movement_bundle = character:military_force():has_effect_bundle(
                psw_no_movement_bundle
            )
        end)
    end

    local removed_bundle = false
    if has_no_movement_bundle then
        local remove_ok = pcall(function()
            cm:remove_effect_bundle_from_characters_force(
                psw_no_movement_bundle,
                char_cqi
            )
        end)
        removed_bundle = remove_ok
    end

    local enable_ok = pcall(function()
        cm:enable_movement_for_character(char_lookup)
    end)
    local replenish_ok = pcall(function()
        cm:replenish_action_points(char_lookup)
    end)

    psw_restore_log(
        "movement repair reason=" .. tostring(reason)
        .. " cqi=" .. tostring(char_cqi)
        .. " has_force=" .. tostring(has_force)
        .. " no_movement_bundle=" .. tostring(has_no_movement_bundle)
        .. " removed_bundle=" .. tostring(removed_bundle)
        .. " ap_before=" .. tostring(action_points_before)
        .. " enable_ok=" .. tostring(enable_ok)
        .. " replenish_ok=" .. tostring(replenish_ok)
    )

    cm:callback(function()
        local refreshed = cm:get_character_by_cqi(char_cqi)
        if not psw_restore_valid_character(refreshed) then
            psw_restore_log(
                "movement verify character missing cqi=" .. tostring(char_cqi)
            )
            return
        end

        local verify_has_force = false
        local verify_has_no_movement_bundle = false
        local action_points_after = "n/a"
        pcall(function()
            action_points_after = refreshed:action_points_remaining_percent()
        end)
        pcall(function()
            verify_has_force = refreshed:has_military_force()
        end)
        if verify_has_force then
            pcall(function()
                verify_has_no_movement_bundle = refreshed:military_force():has_effect_bundle(
                    psw_no_movement_bundle
                )
            end)
        end
        psw_restore_log(
            "movement verify reason=" .. tostring(reason)
            .. " cqi=" .. tostring(char_cqi)
            .. " has_force=" .. tostring(verify_has_force)
            .. " no_movement_bundle=" .. tostring(verify_has_no_movement_bundle)
            .. " ap_after=" .. tostring(action_points_after)
        )
    end, 0.5)

    return true
end

local function psw_restore_get_main_character(faction_name, subtype)
    local character = nil
    if type(psw_get_main_character) == "function" then
        local ok, result = pcall(psw_get_main_character, faction_name)
        if ok then
            character = result
        end
    end

    if psw_restore_valid_character(character) then
        return character
    end

    local faction = cm:get_faction(faction_name)
    if faction == nil or faction:is_null_interface() then
        return nil
    end

    local characters = faction:character_list()
    for index = 0, characters:num_items() - 1 do
        local candidate = characters:item_at(index)
        local candidate_subtype = nil
        local ok = pcall(function()
            candidate_subtype = candidate:character_subtype_key()
        end)
        if ok and candidate_subtype == subtype then
            return candidate
        end
    end

    return nil
end

local function psw_restore_poll(faction_name, family_member_cqi, attempt)
    if psw_restore_pending[faction_name] ~= family_member_cqi then
        return
    end

    local character = cm:get_character_by_fm_cqi(family_member_cqi)
    if psw_restore_valid_character(character)
        and not character:is_wounded()
        and cm:char_is_general_with_army(character)
    then
        local remove_ok, removed_count = pcall(function()
            return cm:remove_all_units_from_general(character)
        end)
        if remove_ok then
            psw_restore_movement_for_character(character, "revival")
            psw_restore_log(
                "restored existing family member fm_cqi=" .. tostring(family_member_cqi)
                .. " cqi=" .. tostring(character:command_queue_index())
                .. " force_cqi=" .. tostring(character:military_force():command_queue_index())
                .. " bootstrap_units_removed=" .. tostring(removed_count)
            )
        else
            psw_restore_log(
                "force restored but bootstrap cleanup failed fm_cqi="
                .. tostring(family_member_cqi) .. " error=" .. tostring(removed_count)
            )
        end

        -- The force/unit mutation is command queued.  Verify after it settles
        -- before allowing another recovery attempt on the next faction turn.
        cm:callback(function()
            local settled = cm:get_character_by_fm_cqi(family_member_cqi)
            local has_army = psw_restore_valid_character(settled)
                and cm:char_is_general_with_army(settled)
            psw_restore_log(
                "settled fm_cqi=" .. tostring(family_member_cqi)
                .. " has_army=" .. tostring(has_army)
            )
            psw_restore_pending[faction_name] = nil
        end, 0.5)
        return
    end

    if attempt < 12 then
        cm:callback(function()
            psw_restore_poll(faction_name, family_member_cqi, attempt + 1)
        end, 0.25)
    else
        psw_restore_pending[faction_name] = nil
        psw_restore_log(
            "existing-general force creation did not settle fm_cqi="
            .. tostring(family_member_cqi)
        )
    end
end

local function psw_restore_main_hero_force(faction_name)
    if psw_restore_pending[faction_name] then
        return
    end

    local faction = cm:get_faction(faction_name)
    if faction == nil or faction:is_null_interface() or faction:is_dead() then
        return
    end

    local player_data = psw_main_data
        and psw_main_data.player_data
        and psw_main_data.player_data[faction_name]
    local subtype = player_data and player_data.yx_subtype
    if subtype == nil or not faction:has_effect_bundle("t_hero_lmyx") then
        return
    end

    local character = psw_restore_get_main_character(faction_name, subtype)
    if not psw_restore_valid_character(character)
        or character:character_subtype_key() ~= subtype
        or character:is_wounded()
        or character:is_at_sea()
        or cm:char_is_general_with_army(character)
    then
        return
    end

    local family_member_cqi = 0
    local family_ok = pcall(function()
        family_member_cqi = character:family_member():command_queue_index()
    end)
    if not family_ok or tonumber(family_member_cqi) == nil or family_member_cqi <= 0 then
        psw_restore_log("cannot identify family member for subtype=" .. tostring(subtype))
        return
    end

    local region = faction:home_region()
    if region == nil or region:is_null_interface() then
        local regions = faction:region_list()
        if regions:num_items() > 0 then
            region = regions:item_at(0)
        end
    end
    if region == nil or region:is_null_interface() then
        psw_restore_log("no settlement available for fm_cqi=" .. tostring(family_member_cqi))
        return
    end

    local region_key = region:name()
    local x, y = cm:find_valid_spawn_location_for_character_from_settlement(
        faction_name, region_key, false, true, distance_from_shoudu
    )
    if tonumber(x) == nil or tonumber(y) == nil or x < 0 or y < 0 then
        psw_restore_log("no valid spawn location for fm_cqi=" .. tostring(family_member_cqi))
        return
    end

    local character_lookup = cm:char_lookup_str(character)
    psw_restore_pending[faction_name] = family_member_cqi
    local create_ok, create_error = pcall(function()
        cm:create_force_with_existing_general(
            character_lookup,
            faction_name,
            psw_restore_bootstrap_unit,
            region_key,
            x,
            y,
            function()
                psw_restore_poll(faction_name, family_member_cqi, 1)
            end
        )
    end)
    if not create_ok then
        psw_restore_pending[faction_name] = nil
        psw_restore_log(
            "create_force_with_existing_general failed fm_cqi="
            .. tostring(family_member_cqi) .. " error=" .. tostring(create_error)
        )
        return
    end

    psw_restore_log(
        "queued existing-general force fm_cqi=" .. tostring(family_member_cqi)
        .. " subtype=" .. tostring(subtype)
    )
    cm:callback(function()
        psw_restore_poll(faction_name, family_member_cqi, 1)
    end, 2.0)
end

local function psw_restore_all_main_hero_forces()
    if psw_main_data == nil or psw_main_data.player_data == nil then
        return
    end
    for faction_name, player_data in pairs(psw_main_data.player_data) do
        if player_data ~= nil and player_data.yx_subtype ~= nil then
            psw_restore_main_hero_force(faction_name)
        end
    end
end

local psw_initial_hero_pool = {
    "yx_lmyx",
    "yx_hero_sllh",
    "yx_hero_edu",
    "yx_hero_niao",
    "yx_hero_fuxuan",
    "yx_hero_feibi",
    "yx_hero_xueli",
    "yx_hero_mika",
}

local psw_hero_creat_impl

local function psw_retry_interrupted_initial_hero_selection()
    if psw_main_data == nil
        or psw_main_data.player_data == nil
        or psw_main_data.global_data == nil
        or psw_main_data.global_data.psw_hero_pool == nil
    then
        return
    end

    for faction_name, player_data in pairs(psw_main_data.player_data) do
        if player_data ~= nil
            and player_data.hero_have_select == true
            and player_data.yx_subtype == nil
        then
            local selected_key = nil
            local zero_count = 0
            for i = 1, #psw_initial_hero_pool do
                local hero_key = psw_initial_hero_pool[i]
                local pool_entry = psw_main_data.global_data.psw_hero_pool[hero_key]
                if pool_entry ~= nil and tonumber(pool_entry.num) ~= nil
                    and pool_entry.num <= 0
                then
                    selected_key = hero_key
                    zero_count = zero_count + 1
                end
            end

            if zero_count == 1 and not cm:get_faction(faction_name):has_effect_bundle("t_hero_lmyx") then
                local pool_entry = psw_main_data.global_data.psw_hero_pool[selected_key]
                pool_entry.num = pool_entry.num + 1
                psw_restore_log(
                    "retrying interrupted initial hero selection faction="
                    .. tostring(faction_name) .. " hero=" .. tostring(selected_key)
                )
                psw_hero_creat_impl(faction_name, selected_key)
            else
                psw_restore_log(
                    "interrupted initial hero selection ambiguous faction="
                    .. tostring(faction_name) .. " zero_count=" .. tostring(zero_count)
                )
            end
        end
    end
end

psw_hero_creat_impl = function(faction_name, hero_key)
    local faction = cm:get_faction(faction_name)
    local culture = faction:culture()

    local yx_subtype = "yx_lmyx"
    local yx_name = common.get_localised_string("psw_yx_name_lmyx")
    local yx_name_ex = common.get_localised_string("psw_yx_name_lmyx2")
    local building = "cstf_lmyx_mfsn"
    if psw_main_data.player_data[faction_name] == nil then
        psw_main_data.player_data[faction_name] = {}
    end
    psw_main_data.player_data[faction_name].hero_have_select = true
    local unique_hero_key = nil
    local unique_hero_type = nil
    local unique_hero_name = nil
    local faction_leader = faction:faction_leader()

    if hero_key == nil then
        cm:faction_add_pooled_resource(faction_name, "psw_main_gmsj", "psw_main_gmsj_event_good", 1)
        local hero_pool = {
            "yx_lmyx",
            "yx_hero_sllh",
            "yx_hero_edu",
            "yx_hero_niao",
            "yx_hero_fuxuan",
            "yx_hero_feibi",
            "yx_hero_xueli",
            "yx_hero_mika",
        }
        local main_hero_pool = {}
        for i = 1, #hero_pool do
            local h_key = hero_pool[i]
            local hero_num = psw_main_data.global_data.psw_hero_pool[h_key].num
            if hero_num > 0 then
                table.insert(main_hero_pool, h_key)
            end
        end
        if #main_hero_pool == 0 then
            hero_key = "yx_lmyx"
        else
            hero_key = main_hero_pool[cm:random_number(#main_hero_pool)]
        end
    end
    psw_main_data.global_data.psw_hero_pool[hero_key].num = psw_main_data.global_data.psw_hero_pool[hero_key].num - 1
    ---神里绫华---
    if hero_key == "yx_hero_sllh" and not faction:has_effect_bundle("hero_select_sllh") then
        yx_subtype = "yx_hero_sllh"
        yx_name = common.get_localised_string("psw_yx_name_sllh")
        yx_name_ex = common.get_localised_string("psw_yx_name_sllh2")
        building = "cstf_sllh"
        psw_add_jishu_jianshu(faction_name, 3)

        cm:apply_effect_bundle("jnz_cstf_blgz_1", faction_name, 0);
        cm:add_ancillary_to_faction(faction, "sllh_mzz_xhz", false)

        psw_aplly_costom_effect_bundle_hidden("hero_select_sllh", faction)

    ---恶毒---
    elseif hero_key == "yx_hero_edu" and not faction:has_effect_bundle("hero_select_edu") then
        yx_subtype = "yx_hero_edu"
        yx_name = common.get_localised_string("psw_yx_name_edu")
        yx_name_ex = common.get_localised_string("psw_yx_name_edu2")
        building = "cstf_edu"

        cm:apply_effect_bundle("jnz_cstf_edu_xfzd_1", faction_name, 0);
        cm:add_ancillary_to_faction(faction, "edu_xfzd", false)

        psw_aplly_costom_effect_bundle_hidden("hero_select_edu", faction)

    ---鹿目圆香---
    elseif hero_key == "yx_lmyx" and not faction:has_effect_bundle("hero_select_lmyx") then

        psw_add_jishu_moli(faction_name, 3)
        cm:apply_effect_bundle("cstf_lmyx_mfsn", faction_name, 0);
        psw_aplly_costom_effect_bundle_hidden("hero_select_lmyx", faction)

    ---笼中鸟---
    elseif hero_key == "yx_hero_niao" and not faction:has_effect_bundle("hero_select_niao") then
        yx_subtype = "yx_hero_niao"
        yx_name = common.get_localised_string("psw_yx_name_niao")
        yx_name_ex = common.get_localised_string("psw_yx_name_niao2")
        building = "cstf_building_niao_sheng"
        local music_list = {
            "niao_select_1",
            "niao_select_2",
            "niao_select_3",
        }
        psw_play_random_music(music_list)

        psw_aplly_costom_effect_bundle_hidden("hero_select_niao", faction)

    ---符玄---
    elseif hero_key == "yx_hero_fuxuan" and not faction:has_effect_bundle("hero_select_fuxuan") then
        yx_subtype = "yx_hero_fuxuan"
        yx_name = common.get_localised_string("psw_yx_name_fuxuan")
        yx_name_ex = common.get_localised_string("psw_yx_name_fuxuan2")
        building = "cstf_building_fuxuan"
        common.trigger_soundevent("fuxuan_select")

        psw_dlc6_cstf_fuxuan_remove_restrict(faction_name)
        psw_aplly_costom_effect_bundle_hidden("hero_select_fuxuan", faction)

    ---菲比---
    elseif hero_key == "yx_hero_feibi" and not faction:has_effect_bundle("hero_select_yly") then
        yx_subtype = "yx_hero_feibi"
        yx_name = common.get_localised_string("psw_yx_name_yly")
        yx_name_ex = common.get_localised_string("psw_yx_name_yly2")
        building = "cstf_building_yly"
        unique_hero_key = "psw_hero_feibi_1"
        unique_hero_type = "wizard"
        unique_hero_name = "psw_hero_name_feibi"
        psw_play_dlc_music("feibi_hero_select_1")

        psw_aplly_costom_effect_bundle_hidden("hero_select_yly", faction)
        psw_dlc7_feibi_get_effect(faction_name)
    ---橘雪莉---
    elseif hero_key == "yx_hero_xueli" and not faction:has_effect_bundle("hero_select_shiki") then
        yx_subtype = "yx_hero_xueli"
        yx_name = common.get_localised_string("psw_yx_name_shiki")
        yx_name_ex = common.get_localised_string("psw_yx_name_shiki2")
        building = "cstf_building_shiki"
        unique_hero_key = "psw_hero_xueli_1"
        unique_hero_type = "champion"
        unique_hero_name = "psw_hero_name_xueli"
        psw_play_dlc_music("hero_select_xueli")

        psw_aplly_costom_effect_bundle_hidden("hero_select_shiki", faction)
        psw_dlc7_xueli_get_effect(faction_name)
    ---圣园未花---
    elseif hero_key == "yx_hero_mika" and not faction:has_effect_bundle("hero_select_nanaya") then
        yx_subtype = "yx_hero_mika"
        yx_name = common.get_localised_string("psw_yx_name_nanaya")
        yx_name_ex = common.get_localised_string("psw_yx_name_nanaya2")
        building = "cstf_building_nanaya"
        unique_hero_key = "psw_hero_mika_1"
        unique_hero_type = "engineer"
        unique_hero_name = "psw_hero_name_mika"
        psw_play_dlc_music("hero_select_mika_1")

        psw_aplly_costom_effect_bundle_hidden("hero_select_nanaya", faction)
        psw_dlc7_mika_get_effect(faction_name)
    end

    psw_main_data.player_data[faction_name].yx_subtype = yx_subtype

    if 1 == 1 then
        if not faction:has_effect_bundle("t_hero_lmyx") then

            -------- 初始计数 ----------
            psw_aplly_costom_effect_bundle_hidden("t_hero_lmyx", faction)

            -----天赋计数

            ------创建英雄

            local leader_anchor_ok = psw_leader_anchor_valid(faction_leader)

            if leader_anchor_ok and (faction_name == "wh2_dlc13_lzd_spirits_of_the_jungle" or faction_name == "wh3_dlc24_tze_the_deceivers" or faction_name == "wh2_main_hef_yvresse" or faction_name == "wh3_dlc27_hef_aislinn" or faction_name == "wh3_dlc27_nor_sayl" or faction_name == "wh3_dlc27_sla_the_tormentors" or faction_name == "wh3_dlc27_sla_masque_of_slaanesh") then
                if faction_name == "wh2_dlc13_lzd_spirits_of_the_jungle" then
                    cm:apply_effect_bundle("psw_gmw_jdrl1", faction_name, 0)
                end

                local a, b = cm:find_valid_spawn_location_for_character_from_character(faction_name, cm:char_lookup_str(faction_leader), true, distance_from_shoudu)

                cm:create_force_with_general(
                    faction_name,
                    "",
                    faction_leader:region_data():key(),
                    a,
                    b,
                    "general",
                    yx_subtype,
                    "psw_yx_name_lmyx2",
                    "",
                    "",
                    "",
                    false,
                    function(cqi)
                        local character = cm:get_character_by_cqi(cqi)

                        cm:change_character_custom_name(character, yx_name, "","","")
                        cm:set_character_immortality(cqi, true)
                        psw_restore_movement_for_character(character, "initial_spawn")
                    end
                );

            elseif 1 == 1 then
                local region = faction:home_region():name()
                local x, y = cm:find_valid_spawn_location_for_character_from_settlement(faction_name, region, false, true, distance_from_shoudu);
                cm:create_force_with_general(
                    faction_name,
                    "",
                    region,
                    x,
                    y,
                    "general",
                    yx_subtype,
                    "psw_yx_name_lmyx2",
                    "",
                    "",
                    "",
                    false,
                    function(cqi)
                        local character = cm:get_character_by_cqi(cqi)

                        cm:change_character_custom_name(character, yx_name, "","","")
                        cm:set_character_immortality(cqi, true)
                        psw_restore_movement_for_character(character, "initial_spawn")
                    end
                );

            end

            local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
            if psw_main_character == nil or psw_main_character:is_null_interface() then
                out("[psw_debug] hero spawn failed, no new general of subtype " .. tostring(yx_subtype) .. " for " .. tostring(faction_name))
                return
            end

            local tf_region = psw_main_character:region()
            local faction_cqi = faction:command_queue_index()
            local region_cqi = tf_region:cqi()
            local region_name = tf_region:name()

            psw_main_data.player_data[faction_name].region_name = region_name

            if faction:culture() == "wh2_main_skv_skaven" then
                -- Skaven home regions can already contain an Under-Empire
                -- manager. Let the shared helper allocate PSW's own manager
                -- on an owned, otherwise-unused region instead of reusing it.
                if type(psw_get_talent_slot_manager) == "function" then
                    psw_get_talent_slot_manager(faction_name)
                else
                    out("[psw_skaven_slots] helper unavailable during hero spawn; skipping unsafe slot setup")
                end
            else
                cm:add_foreign_slot_set_to_region_for_faction(faction_cqi, region_cqi, "psw_cult_slot_set_key")
            end


            psw_delete_shanbi_effect(faction_name, "jn_main_shanbi")

            if culture == "wh2_dlc09_tmb_tomb_kings" then
                cm:apply_effect_bundle("psw_gmw_jdrl1", faction_name, 0)
            elseif culture == "wh_dlc03_bst_beastmen" then
                cm:apply_effect_bundle("psw_gmw_jdrl_bst", faction_name, 0)
            elseif faction_name == "wh3_cp1_cth_tiger_warriors" then
                cm:apply_effect_bundle("psw_gmw_jdrl_bst", faction_name, 0)
            end

            cm:modify_character_personal_loyalty_factor(cm:char_lookup_str(psw_main_character), 10)


            cm:apply_effect_bundle_to_character("psw_main_player_jichu", psw_main_character, 0);


            cm:add_building_to_force(psw_main_character:military_force():command_queue_index(),
                {building
                }
            )

            if yx_subtype == "yx_hero_niao" then
                lzn_sheng_xt_effect(faction_name)
            end

            local effect_list_csyx = {
                {effect = "wh_main_effect_force_army_campaign_attrition_all_immunity", effect_scope = "general_to_force_own", effect_num = 1},
                {effect = "wh2_main_effect_grant_immortality_lord", effect_scope = "character_to_character_own", effect_num = 1},
            }
            psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_jzyd_csyx", 0, effect_list_csyx)

            if unique_hero_key ~= nil then
                local agent_x, agent_y = cm:find_valid_spawn_location_for_character_from_character(faction_name, cm:char_lookup_str(psw_main_character), true, 5)

                local cultist = cm:create_agent(faction_name, unique_hero_type, unique_hero_key, agent_x, agent_y, true)
                if cultist then
                    cm:add_character_model_override(cultist, yx_subtype)
                    cm:replenish_action_points(cm:char_lookup_str(cultist))
                end
                local unique_yx_name = common.get_localised_string(unique_hero_name)
                cm:change_character_custom_name(cultist, unique_yx_name, "","","")
            end

        end
    end
end

function psw_hero_creat_suiji(faction_name)
    psw_hero_creat_impl(faction_name, nil)
end

function psw_hero_creat_zixuan(faction_name, yx_name_zixuan)
    psw_hero_creat_impl(faction_name, yx_name_zixuan)
end

-- 原版 psw_英雄.lua 可能在本文件之后加载并把同名全局函数覆盖回去；
-- 用 first_tick 回调在所有 mod 脚本加载完之后再赋值一次，与文件顺序解耦。
cm:add_first_tick_callback(function()
    psw_hero_creat_suiji = function(faction_name)
        psw_hero_creat_impl(faction_name, nil)
    end
    psw_hero_creat_zixuan = function(faction_name, yx_name_zixuan)
        psw_hero_creat_impl(faction_name, yx_name_zixuan)
    end
    out("[psw_debug] hero spawn fix installed at first_tick")
end)

cm:add_first_tick_callback(function()
    core:remove_listener("psw_restore_main_hero_force")
    core:add_listener(
        "psw_restore_main_hero_force",
        "FactionTurnStart",
        function(context)
            local faction = context:faction()
            return faction ~= nil
                and not faction:is_null_interface()
                and psw_main_data ~= nil
                and psw_main_data.player_data ~= nil
                and psw_main_data.player_data[faction:name()] ~= nil
        end,
        function(context)
            psw_restore_main_hero_force(context:faction():name())
        end,
        true
    )

    -- Also repair a save that was already past convalescence before this fix
    -- was installed.  The short delay lets the loaded campaign finish settling.
    cm:callback(psw_restore_all_main_hero_forces, 2.0)
    cm:callback(psw_retry_interrupted_initial_hero_selection, 2.5)
    out("[psw_debug] hero force restore listener installed at first_tick")
end)
