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

local function psw_hero_creat_impl(faction_name, hero_key)
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

            cm:add_foreign_slot_set_to_region_for_faction(faction_cqi, region_cqi, "psw_cult_slot_set_key")


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
