
function psw_apply_effect_bundle_to_fac(faction_name, effect_bundle_name, effect_bundle_duration, effect_key, effect_scope, effect_value)
    local faction = cm:get_faction(faction_name)
    if faction:has_effect_bundle(effect_bundle_name) then
        cm:remove_effect_bundle(effect_bundle_name, faction_name)
    end
    local effect_bundle = cm:create_new_custom_effect_bundle(effect_bundle_name)
    effect_bundle:set_duration(effect_bundle_duration)
    effect_bundle:add_effect(effect_key, effect_scope, effect_value)
    cm:apply_custom_effect_bundle_to_faction(effect_bundle, faction)
end

local effect_scope_pool = {
    "faction_to_character_own",--所有人物
    "faction_to_force_own",--所有军队
    "faction_to_faction_leader",--派系领袖
    "faction_to_region_own",--所有地区（建筑成本、时间）
    "faction_to_province_own",--所有行省
    "faction_to_faction_own",--派系范围（全局招募时间）
    "faction_to_province_own_factionwide",--派系行省范围（本地招募时间、容量、新募领主等级...）
    "faction_to_faction_own_unseen",--派系范围（科技）
    "faction_to_province_own_factionwide",
}
function psw_jichu_effect_nandu4(faction_name)
    local faction = cm:get_faction(faction_name)
    local culture = faction:culture()
    local effect_bundle = cm:create_new_custom_effect_bundle("psw_jichu_effect_nandu")
    effect_bundle:set_duration(40)
    ---混矮补正
    if culture == "wh3_dlc23_chd_chaos_dwarfs" then
        effect_bundle:add_effect("wh3_dlc23_pooled_resource_chd_armaments_modifier", "faction_to_faction_own_unseen", 50);
        effect_bundle:add_effect("wh3_dlc23_chd_ritual_unit_cap_cost_mod_all_toz", "faction_to_faction_own_unseen", -50);
        effect_bundle:add_effect("wh3_main_effect_building_construction_time_add_mod_all", "faction_to_region_own_unseen", -1);
    ---纳垢补正
    elseif culture == "wh3_main_nur_nurgle" then
        effect_bundle:add_effect("wh3_main_effect_building_cyclical_construction_time_mod_military_basic", "faction_to_region_own", -2);
        effect_bundle:add_effect("wh3_main_effect_building_cyclical_construction_time_mod_military_advanced", "faction_to_region_own", -4);
    ---恶魔亲王补正
    elseif culture == "wh3_main_dae_daemons" then
        effect_bundle:add_effect("wh3_main_effect_dae_all_points_percentage_multiplier_mod", "faction_to_faction_own_unseen", 75);
        effect_bundle:add_effect("wh3_main_effect_building_construction_time_add_mod_all", "faction_to_region_own_unseen", -2);
    ---古墓王派系
    elseif culture == "wh2_dlc09_tmb_tomb_kings" then
        effect_bundle:add_effect("wh3_main_effect_building_construction_time_add_mod_all", "faction_to_region_own_unseen", -1);
        effect_bundle:add_effect("wh2_dlc09_effect_increase_army_capacity", "faction_to_faction_own_unseen", 1);
    end
    effect_bundle:add_effect("psw_growth_horde_hidden", "faction_to_force_own", 5)
    effect_bundle:add_effect("psw_local_unit_recruitment_points_hidden", "faction_to_province_own_factionwide", 1)
    effect_bundle:add_effect("wh3_main_effect_allegiance_points_mod", "faction_to_faction_own_unseen", 100)
    effect_bundle:add_effect("wh_main_effect_character_wound_recovery_time_mod", "faction_to_character_own_unseen", -4)
    effect_bundle:add_effect("psw_technology_research_points_hidden", "faction_to_faction_own_unseen", 100)
    ---战后掳掠
    --effect_bundle:add_effect("wh_main_effect_force_all_campaign_post_battle_loot_mod", "faction_to_faction_own_unseen", -50)
    
    cm:apply_custom_effect_bundle_to_faction(effect_bundle, faction)
end


function psw_jichu_effect_nandu4_AI(faction_name)
    local faction = cm:get_faction(faction_name)
    local effect_bundle = cm:create_new_custom_effect_bundle("psw_jichu_effect_nandu_AI")
    local culture = faction:culture()
    effect_bundle:set_duration(30)
    effect_bundle:add_effect("psw_growth_horde_hidden", "faction_to_force_own", 20)
    effect_bundle:add_effect("psw_building_construction_time_mod_hidden", "faction_to_region_own", -50)
    if culture == "wh3_dlc23_chd_chaos_dwarfs" or culture == "wh_dlc05_wef_wood_elves" then
        effect_bundle:add_effect("psw_building_construction_time_mod_hidden", "faction_to_region_own", 85)
    elseif culture == "wh_dlc03_bst_beastmen" then
        effect_bundle:add_effect("wh2_dlc17_effect_unit_cap_ghorgon_jabberslythe_giant_cygor", "faction_to_faction_own", 100)
        effect_bundle:add_effect("wh2_dlc17_effect_unit_cap_bst_ghorgon", "faction_to_faction_own", 100)
        effect_bundle:add_effect("wh2_dlc17_effect_unit_cap_giant", "faction_to_faction_own", 100)
        effect_bundle:add_effect("wh2_dlc17_effect_unit_cap_cygor", "faction_to_faction_own", 100)
        effect_bundle:add_effect("wh2_dlc17_effect_unit_cap_jabberslythe", "faction_to_faction_own", 100)
        effect_bundle:add_effect("wh2_dlc17_effect_unit_cap_bst_minotaurs_all", "faction_to_faction_own", 100)
        effect_bundle:add_effect("wh2_dlc17_effect_unit_cap_bst_chaos_spawn", "faction_to_faction_own", 100)
        effect_bundle:add_effect("wh2_dlc17_effect_unit_cap_razorgor_herd", "faction_to_faction_own", 100)
        effect_bundle:add_effect("wh2_dlc17_effect_unit_cap_razorgor_chariots", "faction_to_faction_own", 100)
        effect_bundle:add_effect("wh2_dlc17_effect_unit_cap_bst_centigors", "faction_to_faction_own", 100)
        effect_bundle:add_effect("wh2_dlc17_effect_unit_cap_centirgors_great_weapons", "faction_to_faction_own", 100)
        effect_bundle:add_effect("wh2_dlc17_effect_unit_cap_centigors_throwing_axes", "faction_to_faction_own", 100)
        effect_bundle:add_effect("wh2_dlc17_effect_unit_cap_gor_herd_shields", "faction_to_faction_own", 100)
        effect_bundle:add_effect("wh2_dlc17_effect_unit_cap_bst_bestigors", "faction_to_faction_own", 100)
        effect_bundle:add_effect("wh2_dlc17_effect_unit_cap_gor_herd", "faction_to_faction_own", 100)
    end
    effect_bundle:add_effect("psw_growth_hidden", "faction_to_province_own", 60)
    effect_bundle:add_effect("psw_character_campaign_experience_hidden", "faction_to_character_own", 50)
    effect_bundle:add_effect("psw_army_xp_gain_hidden", "faction_to_force_own", 25)
    effect_bundle:add_effect("psw_technology_research_points_hidden", "faction_to_faction_own_unseen", 1000)
    effect_bundle:add_effect("psw_character_experience_per_turn_hidden", "faction_to_character_own", 300)
    effect_bundle:add_effect("psw_level_new_recruit_generals_hidden", "faction_to_province_own_factionwide", 5)
    effect_bundle:add_effect("psw_level_new_recruit_army_hidden", "faction_to_force_own", 2)
    effect_bundle:add_effect("wh_main_effect_unit_recruitment_points", "faction_to_force_own", 6)
    effect_bundle:add_effect("wh_main_effect_force_all_campaign_recruitment_cost_all", "faction_to_force_own", -60)
    effect_bundle:add_effect("wh2_main_effect_agent_recruitment_cost_mod_general", "faction_to_force_own", -50)
    cm:apply_custom_effect_bundle_to_faction(effect_bundle, faction)
end
            


local ex_get_sound = {
    "cj_ex1",
    "cj_ex2",
}

local nor_get_sound = {
    "cj_nor1",
    "cj_nor2",
    "cj_nor3",
}





function psw_main_pickup(faction_name)
    local faction = cm:get_faction(faction_name)
    local xy_xingyun = faction:pooled_resource_manager():resource("psw_xingyun"):value()
    local psw_ewai_xingyun = psw_main_data.player_data[faction_name].psw_ewai_xingyun
    local main_xingyunzhi = (psw_ewai_xingyun + xy_xingyun)
    if main_xingyunzhi > 25 then
        main_xingyunzhi = 25
    end
    local jishu_ex = psw_main_data.player_data[faction_name].jishu_ex_count
    local jishu_nor = psw_main_data.player_data[faction_name].nor_count or 0
    local ex_count = psw_main_data.player_data[faction_name].ex_count or 0
    local jishu_xuanze = psw_main_data.player_data[faction_name].jishu_xuanze
    psw_aplly_costom_effect_bundle_hidden_fn("psw_yi_pick", faction_name);
    local final_tf_count = ex_count + jishu_nor
    
    cm:remove_effect_bundle("main_yi_pick", faction_name)

    local ex_jishu = 0
    
    
    if final_tf_count >= 99 then
        advice_alice_tf_norsx()
        return
    end
    
    local is_zhongduan = false
    local zhongduan_name = false
    for i = 1, jishu_xuanze do
        
        if i == 1 then
            
            local jishu_mofashaonv = faction:pooled_resource_manager():resource("jishu_mofashaonv"):value()
            local psw_moli = faction:pooled_resource_manager():resource("psw_moli"):value()
            local psw_jianshu = psw_main_data.player_data[faction_name].psw_jianshu
            local psw_zhixing = psw_main_data.player_data[faction_name].psw_zhixing or 0
            local jishu_jingling = psw_main_data.player_data[faction_name].jishu_jingling
            local psw_xingyun = faction:pooled_resource_manager():resource("psw_xingyun"):value()
            local lmyx_yinguo_jishu = psw_main_data.player_data[faction_name].lmyx_yinguo_jishu
            local psw_meili = psw_main_data.player_data[faction_name].psw_meili
            
            local zd_num_10 = 10
            local zd_num_4 = 4
            if faction:has_effect_bundle("set_psw_tf_sp_xlfh") then
                zd_num_10 = 5
                zd_num_4 = 2
            end
            
            local ex_xy10 = psw_xingyun >= zd_num_10 and not psw_faction_has_effect_bundle(faction_name, "set_main_xxdqj_1") and jishu_ex <= 1
            
            local ex_ml10 = psw_moli >= zd_num_10 and not psw_faction_has_effect_bundle(faction_name, "set_main_zzhgt_1") and jishu_ex <= 1
            local ex_jingling = jishu_jingling >= zd_num_4 and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_you_ex") and jishu_ex <= 1
            local ex_jianshu = psw_jianshu >= zd_num_10 and not psw_faction_has_effect_bundle(faction_name, "set_main_qlwh_1") and jishu_ex <= 1
            local ex_zhixing10 = psw_zhixing >= zd_num_10 and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_pql") and jishu_ex <= 1
            local ex_meili10 = psw_meili >= zd_num_10 and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_shaonv") and jishu_ex <= 1
            local ex_mfsn = jishu_mofashaonv >= zd_num_4 and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_xzwlsy") and jishu_ex <= 1
            
            local ex_yhzl = lmyx_yinguo_jishu >= 10 and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_yhzl_1") and jishu_ex <= 1
            local ex_xzwlsy_xdzk = psw_faction_has_effect_bundle(faction_name, "xzwlsy_blxdzk_install") and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_xzwlsy")
            local ex_baiye_100 = psw_faction_has_effect_bundle(faction_name, "psw_tf_nor_canmou_baiye100_effect") and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_sp_baiye")
            local nor_mmyzt = psw_faction_has_effect_bundle(faction_name, "psw_tf_nor_baizi_abds_hftz") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_mmyzt")
            
            
            is_zhongduan = ex_xy10 or ex_ml10 or ex_jingling or ex_jianshu or ex_mfsn or ex_zhixing10 or ex_yhzl or ex_xzwlsy_xdzk or ex_baiye_100 or nor_mmyzt or ex_meili10
            
            
            if ex_xy10 then
                zhongduan_name = "psw_tf_sp_xxdqj_ex"
            elseif ex_jingling then
                zhongduan_name = "psw_tf_ex_you_ex"
            elseif ex_zhixing10 then
                zhongduan_name = "psw_tf_ex_pql"
            elseif ex_meili10 then
                zhongduan_name = "psw_tf_ex_shaonv"
            elseif ex_mfsn or ex_xzwlsy_xdzk then
                zhongduan_name = "psw_tf_ex_xzwlsy"
            elseif ex_ml10 then
                zhongduan_name = "psw_tf_ex_zzhgt_ex"
            elseif ex_jianshu then
                zhongduan_name = "psw_tf_ex_qlwh_ex"
            elseif ex_yhzl then
                zhongduan_name = "psw_tf_ex_yhzl_1"
            elseif ex_baiye_100 then
                zhongduan_name = "psw_tf_sp_baiye"
                cm:remove_effect_bundle("psw_tf_nor_canmou_baiye100_effect", faction_name)
            elseif nor_mmyzt then
                zhongduan_name = "psw_tf_nor_mmyzt"
                cm:remove_effect_bundle("psw_tf_nor_baizi_abds_hftz", faction_name)
            end
        end
        
        local random_number = cm:random_number(100, 1)
        if is_zhongduan and i == 1 then
            psw_main_ex_pool(faction_name, i, true, zhongduan_name)
        elseif ((random_number > main_xingyunzhi and not (faction:has_effect_bundle("set_qiyuan_100ex") or psw_faction_has_effect_bundle(faction_name, "blhx_xzmf_3_use"))) or (jishu_ex == 2) or faction:has_effect_bundle("set_qiyuan_100zt")) then
            psw_main_nor_pool(faction_name, i)
        elseif ((random_number <= main_xingyunzhi) and jishu_ex <= 1) or ((faction:has_effect_bundle("set_qiyuan_100ex") or psw_faction_has_effect_bundle(faction_name, "blhx_xzmf_3_use")) and jishu_ex <= 1) then
            psw_main_ex_pool(faction_name, i, false, false)
            
            ex_jishu = ex_jishu + 1
        end
    end
    
    local index_sound
    local tf_get_sound
    if ex_jishu >= 1 then
        index_sound = cm:random_number(#ex_get_sound)
        tf_get_sound = ex_get_sound[index_sound]
        cm:callback(function()
        common.trigger_soundevent(tf_get_sound)
        end, 0.1)
    elseif ex_jishu == 0 then
        index_sound = cm:random_number(#nor_get_sound)
        tf_get_sound = nor_get_sound[index_sound] 
        cm:callback(function()
        common.trigger_soundevent(tf_get_sound)
        end, 0.1)
    end
end

local psw_main_ceshi_pool = {
    "psw_tf_nor_zhu_nor",
    "psw_tf_nor_shengya",
    "psw_tf_nor_lbe",
    "psw_tf_nor_cjzg",
    "psw_tf_nor_clj",
    "psw_tf_nor_glmn",
    "psw_tf_nor_feilin",
    "psw_tf_ex_chazuo",
    "psw_tf_ex_shaonv",
    "psw_tf_sp_xlfh",
    "psw_tf_sp_luluka",
}

local psw_ceshi_tf_ex_pool_2 = {
    "psw_tf_ex_zhenhong_1",
    "psw_tf_ex_syd_1",
    "psw_tf_ex_fuxuan_1",
    "psw_tf_ex_anying_1",
    "psw_tf_ex_qiyana_1",
    "psw_tf_ex_xingfa_1",
    "psw_tf_ex_yln_1",
    "psw_tf_ex_pql",
}


local function insert_more_tf_to_pool(tf_name, pool_name, insert_num)
    for i = 1, insert_num do
        local insert_tf = tf_name
        table.insert(pool_name, insert_tf)
    end
end

---圣三一天赋
local shengya_ssy_tf_pool = {
    "psw_tf_nor_hecheng_nor",
    "psw_tf_nor_yingzi_nor",
    "psw_tf_nor_zhu_nor",
    "psw_tf_nor_bzz_nor",
}

---兰德索尔普通天赋
local gzqs_ldsr_tf_pool = {
    "psw_tf_nor_xxydz_nor",
    "psw_tf_nor_xxyds_nor",
    "psw_tf_nor_jgrs_nor",
    "psw_tf_nor_chgz_nor",
    "psw_tf_nor_mermfs_nor",
    "psw_tf_nor_bhsn",
}

---魔法少女小圆普通天赋
local mfsnxy_nor_tf_pool = {
    "psw_tf_nor_xmy_zt",
    "psw_tf_nor_lmyx_zt",
    "psw_tf_nor_bmm_zt",
    "psw_tf_nor_mssyx_zt",
    "psw_tf_nor_zcxz_zt",
}

---蔷薇少女普通天赋
local qwsn_nor_tf_pool = {
    "psw_tf_nor_jsq",
    "psw_tf_nor_cuixs",
    "psw_tf_nor_cangxs",
    "psw_tf_nor_chumei",
}

---第一人偶 人偶残件
local syd_nor_rocj_pool = {
    "psw_tf_nor_syd_rocj_tuibu",
    "psw_tf_nor_syd_rocj_xiongbu",
    "psw_tf_nor_syd_rocj_wanbu",
    "psw_tf_nor_syd_rocj_toubu",
    "psw_tf_nor_syd_fatiao",
}

---暗影庭院 七影
local ayty_qiying_pool = {
    "psw_tf_nor_arf",
    "psw_tf_nor_beita",
    "psw_tf_nor_gama",
    "psw_tf_nor_delt",
    "psw_tf_nor_ypxl",
    "psw_tf_nor_jieta",
    "psw_tf_nor_xita",
}


---阿拜多斯 普通天赋
local abds_tx_tf_pool = {
    "psw_tf_nor_qinxiang",
    "psw_tf_nor_yegong",
    "psw_tf_nor_rifumei",
}

---游戏开发部 普通天赋
local yxkfb_tf_nor_pool = {
    "psw_tf_nor_lv_nor",
    "psw_tf_nor_taojing_nor",
}

---精灵特性普通天赋
local jingling_tx_tf = {
    "psw_tf_nor_emt",
    "psw_tf_nor_nnk",
    "psw_tf_nor_abak",
    "psw_tf_nor_aly",
    "psw_tf_nor_jgrs_nor",
    "psw_tf_nor_xxydz_nor",
    "psw_tf_nor_xxyds_nor",
    "psw_tf_nor_yxmj_nor",
    "psw_tf_nor_chusheng",
    "psw_tf_nor_aisite",
    "psw_tf_nor_bzyj_nor",
    "psw_tf_nor_yjdzf_nor",
}

---共鸣者普通天赋
local gmz_nor_tf_pool = {
    "psw_tf_nor_chun",
    "psw_tf_nor_sar",
    "psw_tf_nor_ktll",
    "psw_tf_nor_anke",
    "psw_tf_nor_weilinai",
}

---共鸣者唯一天赋
local gmz_ex_tf_pool = {
    "psw_tf_ex_feibi_1",
    "psw_tf_ex_klt_1",
    "psw_tf_ex_jinxi_1",
}

    
function psw_main_nor_pool(faction_name, slot_number)
    local faction = cm:get_faction(faction_name)
    local tf_pool = {
        "psw_tf_nor_alu_nor",
        "psw_tf_nor_hecheng_nor",
        "psw_tf_nor_sly_nor",
        "psw_tf_nor_shanling_nor",
        "psw_tf_nor_yeying_nor",
        "psw_tf_nor_zaomiao_nor",
        "psw_tf_nor_ytzd_nor",
        "psw_tf_nor_lmtg_nor",
        "psw_tf_nor_sllh_nor",
        "psw_tf_nor_shgxh_nor",
        "psw_tf_nor_yingzi_nor",
        "psw_tf_nor_zhu_nor",
        "psw_tf_nor_ylb_nor",
        "psw_tf_nor_qingnai_nor",
        "psw_tf_nor_plshy_nor",
        "psw_tf_nor_wcbldsj_nor",
        "psw_tf_nor_wcbldsg_nor",
        "psw_tf_nor_yrhtdsj_nor",
        "psw_tf_nor_jgrs_nor",
        "psw_tf_nor_xxydz_nor",
        "psw_tf_nor_xxyds_nor",
        "psw_tf_nor_chgz_nor",
        "psw_tf_nor_mermfs_nor",
        "psw_tf_nor_ljsf_nor",
        "psw_tf_nor_slmdmn_nor1",
        "psw_tf_nor_yqdjb_nor1",
        "psw_tf_nor_rwyyr_nor1",
        "psw_tf_nor_xsdjy_nor1",
        "psw_tf_nor_bzyj_nor",
        "psw_tf_nor_hrxn_nor",
        "psw_tf_nor_sqf_nor",
        "psw_tf_nor_zqxy_nor",
        "psw_tf_nor_cptnw_nor",
        "psw_tf_nor_blmf_nor",
        "psw_tf_nor_hbszx_nor",
        "psw_tf_nor_lbszx_nor",
        "psw_tf_nor_hzmn_nor",
        "psw_tf_nor_yzk_nor",
        "psw_tf_nor_tyms_nor",
        "psw_tf_nor_wxjz_nor",
        "psw_tf_nor_yzm_nor",
        "psw_tf_nor_yxmj_nor",
        "psw_tf_nor_wkll_nor",
        "psw_tf_nor_ysw_nor",
        "psw_tf_nor_nswn_nor",
        "psw_tf_nor_ldzl_nor",
        "psw_tf_nor_jddjsz_nor",
        "psw_tf_nor_ssznp_nor",
        "psw_tf_nor_kewei_nor",
        "psw_tf_nor_guanghui_nor",
        "psw_tf_nor_chaijun_nor",
        "psw_tf_nor_daiduo_nor",
        "psw_tf_nor_qiye_nor",
        "psw_tf_nor_bzz_nor",
        "psw_tf_nor_yazi_nor",
        "psw_tf_nor_taojing_nor",
        "psw_tf_nor_lv_nor",
        "psw_tf_nor_fssn_nor",
        "psw_tf_nor_szhx_nor",
        "psw_tf_nor_bszzw_nor",
        "psw_tf_nor_zhxx_nor",
        "psw_tf_nor_cbem_nor",
        "psw_tf_nor_kfsdmf_nor",
        "psw_tf_nor_fxdhd_nor",
        "psw_tf_nor_lzjy_nor",
        "psw_tf_nor_zdyx_nor",
        "psw_tf_nor_yjdzf_nor",
        "psw_tf_nor_dark_nor",
        "psw_tf_nor_dygz_nor",
        "psw_tf_nor_xyz_nor",
        "psw_tf_nor_edu_nor",
        "psw_tf_nor_yanjie",
        "psw_tf_nor_jsq",
        "psw_tf_nor_cuixs",
        "psw_tf_nor_cangxs",
        "psw_tf_nor_chumei",
        "psw_tf_nor_bhsn",
        "psw_tf_nor_heimao",
        "psw_tf_nor_tina",
        "psw_tf_nor_shayou_1",
        "psw_tf_nor_diya",
        "psw_tf_nor_chusheng",
        "psw_tf_nor_hqfa",
        "psw_tf_nor_lhz",
        "psw_tf_nor_bfsm",
        "psw_tf_nor_nimufu",
        "psw_tf_nor_ssqk",
        "psw_tf_nor_youjiou",
        "psw_tf_nor_tghr",
        "psw_tf_nor_yasina",
        "psw_tf_nor_juejian",
        "psw_tf_nor_paojie",
        "psw_tf_nor_meipulu",
        "psw_tf_nor_nvshenguan",
        "psw_tf_nor_sxly",
        "psw_tf_nor_lls",
        "psw_tf_nor_gengxj",
        "psw_tf_nor_latifa",
        "psw_tf_nor_wunvji",
        "psw_tf_nor_bshu",
        "psw_tf_nor_gosick",
        "psw_tf_nor_xiaojiu",
        "psw_tf_nor_shanshan",
        "psw_tf_nor_heitu",
        "psw_tf_nor_xiaoniao",
        "psw_tf_nor_gjb",
        "psw_tf_nor_aisite",
        "psw_tf_nor_yeye",
        "psw_tf_nor_shengya",
        "psw_tf_nor_gzqs",
        "psw_tf_nor_klastl",
        "psw_tf_nor_canmou",
        "psw_tf_nor_lilika",
        "psw_tf_nor_baihua",
        "psw_tf_nor_tangtang",
        "psw_tf_nor_ctj",
        "psw_tf_nor_feiyu",
        "psw_tf_nor_baizi",
        "psw_tf_nor_qinxiang",
        "psw_tf_nor_xuefeng",
        "psw_tf_nor_yegong",
        "psw_tf_nor_rifumei",
        "psw_tf_nor_zuozhu",
        "psw_tf_nor_mingren",
        "psw_tf_nor_zak",
        "psw_tf_nor_ruijier",
        "psw_tf_nor_ssdqd",
        "psw_tf_nor_noa",
        "psw_tf_nor_yozi",
        "psw_tf_nor_xiaochun",
        "psw_tf_nor_guhezhu",
        "psw_tf_nor_fuko",
        "psw_tf_nor_delisha",
        "psw_tf_nor_liuhua",
        "psw_tf_nor_dxl",
        "psw_tf_nor_qiesi",
        "psw_tf_nor_emt",
        "psw_tf_nor_weilinai",
        "psw_tf_nor_chun",
        "psw_tf_nor_sar",
        "psw_tf_nor_ktll",
        "psw_tf_nor_anke",
        "psw_tf_nor_zgn",
        "psw_tf_nor_jingliu",
        "psw_tf_nor_luna",
        "psw_tf_nor_zfz",
        "psw_tf_nor_snz",
        "psw_tf_nor_zhenbai",
        "psw_tf_nor_akuya",
        "psw_tf_nor_jsluna",
        "psw_tf_nor_amm",
        "psw_tf_nor_xnm",
        "psw_tf_nor_xinghui",
        "psw_tf_nor_hxss",
        "psw_tf_nor_xfl",
        "psw_tf_nor_mjyrx",
        "psw_tf_nor_ryr",
        "psw_tf_nor_lxlql",
        "psw_tf_nor_nws",
        "psw_tf_nor_youyue",
        "psw_tf_nor_xiaoye",
        "psw_tf_nor_mdx",
        "psw_tf_nor_anne",
        "psw_tf_nor_aly",
        "psw_tf_nor_nnk",
        "psw_tf_nor_huahuo",
        "psw_tf_nor_xiana",
        "psw_tf_nor_abak",
        "psw_tf_nor_zdn",
        "psw_tf_nor_lbe",
        "psw_tf_nor_cjzg",
        "psw_tf_nor_clj",
        "psw_tf_nor_glmn",
        "psw_tf_nor_feilin",
    }
    local is_ceshi = false
    ---测试
    --tf_pool = psw_main_ceshi_pool
    --is_ceshi = true
    
    local index_normal
    local psw_nor_tf
    local region_name = psw_main_data.player_data[faction_name].region_name
    local tf_region = cm:get_region(region_name)
    if not tf_region or tf_region:is_null_interface() then
        local _home_region = faction:home_region()
        if _home_region and not _home_region:is_null_interface() then
            tf_region = _home_region
            region_name = _home_region:name()
        else
            return
        end
    end
    local _fsm = tf_region:foreign_slot_manager_for_faction(faction_name)
    if not _fsm or _fsm:is_null_interface() then
        cm:add_foreign_slot_set_to_region_for_faction(faction:command_queue_index(), tf_region:cqi(), "psw_cult_slot_set_key")
        _fsm = tf_region:foreign_slot_manager_for_faction(faction_name)
        if not _fsm or _fsm:is_null_interface() then return end
    end
    local slot_n_list = _fsm:slots()
    if not slot_n_list or slot_n_list:num_items() < slot_number then return end
    local slot = slot_n_list:item_at(slot_number-1)
    if not slot or slot:is_null_interface() then return end
    local turn = cm:turn_number()
    local jishu_ayty = psw_main_data.player_data[faction_name].jishu_ayty or 0
    local jishu_heian = psw_resource_value(faction, "jishu_heian")
    local is_firefly = false
    if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_ex_firefly_2") then
        local firefly_yinghuo_num = psw_main_data.global_data.firefly_yinghuo_num or 0
        firefly_yinghuo_num = firefly_yinghuo_num * 2
        local firefly_ran_num = cm:random_number(100, 1)
        local firefly_get_num = 15 + firefly_yinghuo_num
        if firefly_ran_num <= firefly_get_num then
            is_firefly = true
        end
    end
    local ex_count = psw_main_data.player_data[faction_name].ex_count or 0
    local jishu_nor = psw_main_data.player_data[faction_name].nor_count or 0
    
    local recipient_culture = faction:culture()
    
    local culture_wang = (recipient_culture == "wh_main_emp_empire" or recipient_culture == "wh_main_brt_bretonnia" or recipient_culture == "wh3_main_cth_cathay" or recipient_culture == "wh_dlc08_nor_norsca" or recipient_culture == "wh3_main_ksl_kislev" or recipient_culture == "wh_main_chs_chaos")
    
    
    ------------------ 保底相关 -------------------
    ----------游戏胜利的方法----------
    if not is_ceshi then
        if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_ybbb_1") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yxsldff_nor") then
            insert_more_tf_to_pool("psw_tf_nor_yxsldff_nor", tf_pool, 4)
        end
        if culture_wang then
            table.insert(tf_pool, "psw_tf_nor_yxsldff_nor")
        end
        ---春庭天赋
        if (ex_count + jishu_nor) <= 1 then
            table.insert(tf_pool, "psw_tf_nor_hehuan")
            table.insert(tf_pool, "psw_tf_nor_bkh")
            table.insert(tf_pool, "psw_tf_nor_tsh")
            table.insert(tf_pool, "psw_tf_nor_xiangcao")
            table.insert(tf_pool, "psw_tf_nor_mec")
        end
    end
    
    
    ----------白圣女 预知梦----------
    if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_sxly") and not psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_lls") then
        insert_more_tf_to_pool("psw_tf_nor_lls", tf_pool, 4)
    end
    ----------红宝石之星----------
    if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_hbszx_nor") and not psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_lbszx_nor") then
        insert_more_tf_to_pool("psw_tf_nor_lbszx_nor", tf_pool, 4)
    end
    ----------蓝宝石之星----------
    if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_lbszx_nor") and not psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_hbszx_nor") then
        insert_more_tf_to_pool("psw_tf_nor_hbszx_nor", tf_pool, 4)
    end
    ----------圣娅 预知梦----------
    if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_shengya") then
        for i = 1, #shengya_ssy_tf_pool do
            local insert_tf = shengya_ssy_tf_pool[i]
            if not psw_faction_has_effect_bundle(faction_name, "set_"..tostring(insert_tf)) then
                insert_more_tf_to_pool(insert_tf, tf_pool, 4)
            end
        end
    end
    ----------公主骑士 连结之力----------
    if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_gzqs") then
        for i = 1, #gzqs_ldsr_tf_pool do
            local insert_tf = gzqs_ldsr_tf_pool[i]
            if not psw_faction_has_effect_bundle(faction_name, "set_"..tostring(insert_tf)) then
                insert_more_tf_to_pool(insert_tf, tf_pool, 4)
            end
        end
    end
    
    ---------- 丘比 ----------
    if psw_faction_has_effect_bundle(faction_name, "set_main_qb_1") then
        if not psw_faction_has_effect_bundle(faction_name, "set_lhbs_player") then
            local insert_num = 1
            if faction:has_effect_bundle("hero_select_lmyx") and not psw_main_data.global_data.set_main_psw_tf_nor_lmyx_zt then
                insert_more_tf_to_pool("psw_tf_nor_lmyx_zt", tf_pool, insert_num)
            else
                for i = 1, #mfsnxy_nor_tf_pool do
                    local insert_tf = mfsnxy_nor_tf_pool[i]
                    if not psw_faction_has_effect_bundle(faction_name, "set_main_"..tostring(insert_tf)) then
                        insert_more_tf_to_pool(insert_tf, tf_pool, insert_num)
                    end
                end
            end
        end
    end
    
    ----------第五人偶 最接近爱丽丝的人偶----------
    if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_ex_zhenhong_1") then
        for i = 1, #qwsn_nor_tf_pool do
            local insert_tf = qwsn_nor_tf_pool[i]
            if not psw_faction_has_effect_bundle(faction_name, "set_"..tostring(insert_tf)) then
                insert_more_tf_to_pool(insert_tf, tf_pool, 4)
            end
        end
    end
    
    ----------第一人偶 人偶残件----------
    if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_ex_syd_1") then
        local syd_ro_wzd = psw_main_data.player_data[faction_name].syd_ro_wzd or 0
        if syd_ro_wzd < 100 then
            for i = 1, #syd_nor_rocj_pool do
                local insert_tf = syd_nor_rocj_pool[i]
                local num = psw_main_data.player_data[faction_name].psw_tf_nor_syd_rocj_tuibu_jishu or 0
                if insert_tf == "psw_tf_nor_syd_rocj_xiongbu" then
                    num = psw_main_data.player_data[faction_name].psw_tf_nor_syd_rocj_xiongbu_jishu or 0
                elseif insert_tf == "psw_tf_nor_syd_rocj_wanbu" then
                    num = psw_main_data.player_data[faction_name].psw_tf_nor_syd_rocj_wanbu_jishu or 0
                elseif insert_tf == "psw_tf_nor_syd_rocj_toubu" then
                    num = psw_main_data.player_data[faction_name].psw_tf_nor_syd_rocj_toubu_jishu or 0
                elseif insert_tf == "psw_tf_nor_syd_fatiao" then
                    num = psw_main_data.player_data[faction_name].psw_tf_nor_syd_fatiao_jishu or 0
                end
                if num < 3 then
                    insert_more_tf_to_pool(insert_tf, tf_pool, 4)
                end
            end
        end
    end
    
    ----------暗影庭院----------
    if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_ex_anying_1") then
        for i = 1, #ayty_qiying_pool do
            local insert_tf = ayty_qiying_pool[i]
            if not psw_faction_has_effect_bundle(faction_name, "set_"..tostring(insert_tf)) then
                insert_more_tf_to_pool(insert_tf, tf_pool, 3)
            end
        end
    end
    
    ----------白子----------
    if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_baizi") then
        for i = 1, #abds_tx_tf_pool do
            local insert_tf = abds_tx_tf_pool[i]
            if not psw_faction_has_effect_bundle(faction_name, "set_"..tostring(insert_tf)) then
                insert_more_tf_to_pool(insert_tf, tf_pool, 4)
            end
        end
    end
    
    ----------杀戮的天使----------
    if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_ruijier") and not psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_zak") then
        insert_more_tf_to_pool("psw_tf_nor_zak", tf_pool, 4)
    elseif psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_zak") and not psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_ruijier") then
        insert_more_tf_to_pool("psw_tf_nor_ruijier", tf_pool, 4)
    end
    
    ----------柚子----------
    if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_yozi") then
        for i = 1, #yxkfb_tf_nor_pool do
            local insert_tf = yxkfb_tf_nor_pool[i]
            if not psw_faction_has_effect_bundle(faction_name, "set_"..tostring(insert_tf)) then
                insert_more_tf_to_pool(insert_tf, tf_pool, 4)
            end
        end
    end
    
    
    
    
    index_normal = cm:random_number(#tf_pool)
    psw_nor_tf = tf_pool[index_normal]
    
    --测试
    --psw_nor_tf = "psw_tf_nor_xnm"
    
    ----------心智魔方1/2----------
    if slot_number == 1 then
        if psw_faction_has_effect_bundle(faction_name, "blhx_xzmf_1_use") then
            tf_pool = {}
            if not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_kewei_nor") then
                table.insert(tf_pool, "psw_tf_nor_kewei_nor")
            end
            if not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_guanghui_nor") then
                table.insert(tf_pool, "psw_tf_nor_guanghui_nor")
            end
            if not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_chaijun_nor") then
                table.insert(tf_pool, "psw_tf_nor_chaijun_nor")
            end
            if not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_daiduo_nor") then
                table.insert(tf_pool, "psw_tf_nor_daiduo_nor")
            end
            if not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_qiye_nor") then
                table.insert(tf_pool, "psw_tf_nor_qiye_nor")
            end
            if not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_edu_nor") then
                table.insert(tf_pool, "psw_tf_nor_edu_nor")
            end
            index_normal = cm:random_number(#tf_pool)
            psw_nor_tf = tf_pool[index_normal]
            cm:remove_effect_bundle("blhx_xzmf_1_use", faction_name)
            cm:remove_effect_bundle("pick_up_dingxiang", faction_name)
        ----------记忆碎片-六道之力----------
        elseif faction:has_effect_bundle("set_jysp_ldzl") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_ldzl_nor") then
            psw_nor_tf = "psw_tf_nor_ldzl_nor"
            cm:remove_effect_bundle("set_jysp_ldzl", faction_name)
        ----------记忆碎片-雪音----------
        elseif faction:has_effect_bundle("set_jysp_xueyin") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_zqxy_nor") then
            psw_nor_tf = "psw_tf_nor_zqxy_nor"
            cm:remove_effect_bundle("set_jysp_xueyin", faction_name)
        ----------圣娅 预知梦-渚----------
        elseif psw_faction_has_effect_bundle(faction_name, "psw_dlc6_shengya_yzm_zhu") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_zhu_nor") then
            psw_nor_tf = "psw_tf_nor_zhu_nor"
            cm:remove_effect_bundle("psw_dlc6_shengya_yzm_zhu", faction_name);
        ----------日富美的青春宣言----------
        elseif psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_rifumei") and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_sywh_1") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_bzz_nor") and not psw_faction_has_effect_bundle(faction_name, "psw_tf_nor_rifumei_xuanyan") then
            psw_nor_tf = "psw_tf_nor_bzz_nor"
            psw_aplly_costom_effect_bundle_hidden_fn("psw_tf_nor_rifumei_xuanyan", faction_name)
        
        ----------丘比----------
        elseif psw_faction_has_effect_bundle(faction_name, "qb_cw_mfsn") then
            tf_pool = {}
            if not psw_main_data.global_data.set_main_psw_tf_nor_lmyx_zt then
                table.insert(tf_pool, "psw_tf_nor_lmyx_zt")
            end
            if not psw_main_data.global_data.set_main_psw_tf_nor_xmy_zt then
                table.insert(tf_pool, "psw_tf_nor_xmy_zt")
            end
            if not psw_main_data.global_data.set_main_psw_tf_nor_bmm_zt then
                table.insert(tf_pool, "psw_tf_nor_bmm_zt")
            end
            if not psw_main_data.global_data.set_main_psw_tf_nor_mssyx_zt then
                table.insert(tf_pool, "psw_tf_nor_mssyx_zt")
            end
            if not psw_main_data.global_data.set_main_psw_tf_nor_zcxz_zt then
                table.insert(tf_pool, "psw_tf_nor_zcxz_zt")
            end
            index_normal = cm:random_number(#tf_pool)
            psw_nor_tf = tf_pool[index_normal]
            cm:remove_effect_bundle("qb_cw_mfsn", faction_name)
            
        ----------第七人偶 无心の人偶----------
        elseif psw_faction_has_effect_bundle(faction_name, "psw_qwsn_100") then
            local qwsn_pool = {}
            if not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_jsq") then
                table.insert(qwsn_pool, "psw_tf_nor_jsq")
            end
            if not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_cuixs") then
                table.insert(qwsn_pool, "psw_tf_nor_cuixs")
            end
            if not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_cangxs") then
                table.insert(qwsn_pool, "psw_tf_nor_cangxs")
            end
            if not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_chumei") then
                table.insert(qwsn_pool, "psw_tf_nor_chumei")
            end
            cm:remove_effect_bundle("psw_qwsn_100", faction_name)
            index_normal = cm:random_number(#qwsn_pool)
            psw_nor_tf = qwsn_pool[index_normal]
        ----------古河渚 海星的祝福----------
        elseif faction:has_effect_bundle("psw_zhu_guangyu5_effect") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_fuko") then
            psw_nor_tf = "psw_tf_nor_fuko"
            cm:remove_effect_bundle("psw_zhu_guangyu5_effect", faction_name)
            
        ----------星咏真白 精灵眼----------
        elseif faction:has_effect_bundle("psw_dlc7_shiro_jinglingyan") then
            local jly_pool = {}
            for i = 1, #jingling_tx_tf do
                local insert_tf = jingling_tx_tf[i]
                if not psw_faction_has_effect_bundle(faction_name, "set_"..tostring(insert_tf)) then
                    table.insert(jly_pool, insert_tf)
                end
            end
            index_normal = cm:random_number(#jly_pool)
            psw_nor_tf = jly_pool[index_normal]
            cm:remove_effect_bundle("psw_dlc7_shiro_jinglingyan", faction_name)
            
        ----------深森白夜 写作敌人，读作恋人----------
        elseif faction:has_effect_bundle("set_main_psw_tf_sp_baiye") and jishu_heian >= 5 and not psw_faction_has_effect_bundle(faction_name, "psw_dlc7_baiye_xzlr_effect_bundle") then
            psw_nor_tf = "psw_tf_nor_canmou"
            psw_aplly_costom_effect_bundle_hidden_fn("psw_dlc7_baiye_xzlr_effect_bundle", faction_name)
            
        ----------飞萤扑火----------
        elseif psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_ex_firefly_2") and not psw_faction_has_effect_bundle(faction_name, "psw_dlc7_firefly_feph_fnish_effect_bundle") and is_firefly then
            psw_nor_tf = "psw_tf_nor_firefly"
            
        ----------引导妖精 爱梅斯----------
        elseif not psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_gzqs") and psw_faction_has_effect_bundle(faction_name, "psw_dlc7_ams_ydyj_gzqs_100") then
            psw_nor_tf = "psw_tf_nor_gzqs"
            cm:remove_effect_bundle("psw_dlc7_ams_ydyj_gzqs_100", faction_name)
            
        ----------爱梅斯 静流 记忆碎片----------
        elseif not psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_jingliu") and psw_faction_has_effect_bundle(faction_name, "set_psw_dlc7_ams_shop_jingliu") then
            psw_nor_tf = "psw_tf_nor_jingliu"
            cm:remove_effect_bundle("set_psw_dlc7_ams_shop_jingliu", faction_name)
        
        ----------爱梅斯 凯露 记忆碎片----------
        elseif not psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_mermfs_nor") and psw_faction_has_effect_bundle(faction_name, "set_psw_dlc7_ams_shop_kailu") then
            psw_nor_tf = "psw_tf_nor_mermfs_nor"
            cm:remove_effect_bundle("set_psw_dlc7_ams_shop_kailu", faction_name)
            
        ----------爱梅斯 栞 记忆碎片----------
        elseif not psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_bhsn") and psw_faction_has_effect_bundle(faction_name, "set_psw_dlc7_ams_shop_kan") then
            psw_nor_tf = "psw_tf_nor_bhsn"
            cm:remove_effect_bundle("set_psw_dlc7_ams_shop_kan", faction_name)
            
        ----------爱梅斯 似似花 记忆碎片----------
        elseif not psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_nnk") and psw_faction_has_effect_bundle(faction_name, "set_psw_dlc7_ams_shop_nnk") then
            psw_nor_tf = "psw_tf_nor_nnk"
            cm:remove_effect_bundle("set_psw_dlc7_ams_shop_nnk", faction_name)
            
        ----------爱梅斯 可可萝（普通） 记忆碎片----------
        elseif not psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_xxydz_nor") and psw_faction_has_effect_bundle(faction_name, "set_psw_dlc7_ams_shop_norkokora") then
            psw_nor_tf = "psw_tf_nor_xxydz_nor"
            cm:remove_effect_bundle("set_psw_dlc7_ams_shop_norkokora", faction_name)
            
        ----------爱梅斯 小仓唯（普通） 记忆碎片----------
        elseif not psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_xxyds_nor") and psw_faction_has_effect_bundle(faction_name, "set_psw_dlc7_ams_shop_norxcw") then
            psw_nor_tf = "psw_tf_nor_xxyds_nor"
            cm:remove_effect_bundle("set_psw_dlc7_ams_shop_norxcw", faction_name)
            
        ----------爱梅斯 佩可莉姆 记忆碎片----------
        elseif not psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_chgz_nor") and psw_faction_has_effect_bundle(faction_name, "set_psw_dlc7_ams_shop_pklm") then
            psw_nor_tf = "psw_tf_nor_chgz_nor"
            cm:remove_effect_bundle("set_psw_dlc7_ams_shop_pklm", faction_name)
            
        ----------爱梅斯 亚丽莎 记忆碎片----------
        elseif not psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_jgrs_nor") and psw_faction_has_effect_bundle(faction_name, "set_psw_dlc7_ams_shop_yls") then
            psw_nor_tf = "psw_tf_nor_jgrs_nor"
            cm:remove_effect_bundle("set_psw_dlc7_ams_shop_yls", faction_name)
            
        ----------莉莉卡 月夜下的命运相逢----------
        elseif not psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_lilika") and psw_faction_has_effect_bundle(faction_name, "psw_dlc7_lilika_yueye_100_effect") then
            psw_nor_tf = "psw_tf_nor_lilika"
            cm:remove_effect_bundle("psw_dlc7_lilika_yueye_100_effect", faction_name)
            

        ----------共鸣者 ----------
        elseif faction:has_effect_bundle("psw_dlc7_mc_gmz100") then
            local ran_num_gmz = cm:random_number(#gmz_nor_tf_pool)
            psw_nor_tf = gmz_nor_tf_pool[ran_num_gmz]
            cm:remove_effect_bundle("psw_dlc7_mc_gmz100", faction_name)





            
        ----------专属天赋----------
        elseif faction:has_effect_bundle("set_qiyuan_100zt") then
            if faction:has_effect_bundle("hero_select_sllh") then
                psw_nor_tf = "psw_tf_nor_sllh_nor"
            elseif faction:has_effect_bundle("hero_select_edu") then
                psw_nor_tf = "psw_tf_nor_edu_nor"
            elseif faction:has_effect_bundle("hero_select_lmyx") and not psw_main_data.global_data.set_main_psw_tf_nor_lmyx_zt then
                psw_nor_tf = "psw_tf_nor_lmyx_zt"
            elseif faction:has_effect_bundle("hero_select_niao") then
                local niao_random_num = cm:random_number(100,1)
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_zdyx_nor") and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_lzjy_nor") then
                    if niao_random_num >= 50 then
                        psw_nor_tf = "psw_tf_nor_lzjy_nor"
                    elseif 1 == 1 then
                        psw_nor_tf = "psw_tf_nor_zdyx_nor"
                    end
                elseif psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_zdyx_nor") then
                    psw_nor_tf = "psw_tf_nor_lzjy_nor"
                elseif psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_lzjy_nor") then
                    psw_nor_tf = "psw_tf_nor_zdyx_nor"
                else
                    if niao_random_num >= 50 then
                        psw_nor_tf = "psw_tf_nor_lzjy_nor"
                    elseif 1 == 1 then
                        psw_nor_tf = "psw_tf_nor_zdyx_nor"
                    end
                end
                
            elseif faction:has_effect_bundle("hero_select_yly") then
                psw_nor_tf = "psw_tf_nor_cjzg"
            elseif faction:has_effect_bundle("hero_select_shiki") then
                psw_nor_tf = "psw_tf_nor_glmn"
            elseif faction:has_effect_bundle("hero_select_nanaya") then
                local mika_zt_pool = {}
                if not faction:has_effect_bundle("set_psw_tf_nor_clj") then
                    table.insert(mika_zt_pool, "psw_tf_nor_clj")
                end
                if not faction:has_effect_bundle("set_psw_tf_nor_zhu_nor") then
                    table.insert(mika_zt_pool, "psw_tf_nor_zhu_nor")
                end
                if not faction:has_effect_bundle("set_psw_tf_nor_shengya") then
                    table.insert(mika_zt_pool, "psw_tf_nor_shengya")
                end
                if #mika_zt_pool > 0 then
                    index_normal = cm:random_number(#mika_zt_pool)
                    psw_nor_tf = mika_zt_pool[index_normal]
                else
                    index_normal = cm:random_number(#tf_pool)
                    psw_nor_tf = tf_pool[index_normal]
                end
            end
            cm:remove_effect_bundle("set_qiyuan_100zt", faction_name)
            
        
        ----------其他----------
        elseif 1 == 1 then
            index_normal = cm:random_number(#tf_pool)
            psw_nor_tf = tf_pool[index_normal]
            
        end
        -------------------------------------
        
    elseif slot_number == 2 then
        if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_ex_anying_1") and jishu_ayty <= 7 and not faction:has_effect_bundle("psw_dlc6_anying_baodi_effect") then
            if turn == 15 or turn == 25 then
                tf_pool = {}
                for j = 1, #ayty_qiying_pool do
                    local insert_e = ayty_qiying_pool[j]
                    if not psw_faction_has_effect_bundle(faction_name, "set_"..tostring(insert_e)) then
                        table.insert(tf_pool, insert_e)
                    end
                end
                index_normal = cm:random_number(#tf_pool)
                psw_nor_tf = tf_pool[index_normal]
                psw_aplly_costom_effect_bundle_with_time_hidden("psw_dlc6_anying_baodi_effect", faction, 1)
            end
        elseif psw_faction_has_effect_bundle(faction_name, "psw_dlc6_shengya_yzm_zhu") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_zhu_nor") then
            psw_nor_tf = "psw_tf_nor_zhu_nor"
            cm:remove_effect_bundle("psw_dlc6_shengya_yzm_zhu", faction_name);
        elseif psw_faction_has_effect_bundle(faction_name, "psw_tf_nor_shengya_zt_effect_bundle") and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_sywh_1") then
            psw_nor_tf = "psw_tf_ex_sywh_1"
            cm:remove_effect_bundle("psw_tf_nor_shengya_zt_effect_bundle", faction_name);
        end
    else
        if psw_faction_has_effect_bundle(faction_name, "psw_dlc6_shengya_yzm_zhu") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_zhu_nor") then
            psw_nor_tf = "psw_tf_nor_zhu_nor"
            cm:remove_effect_bundle("psw_dlc6_shengya_yzm_zhu", faction_name);
        end
    end
    
    --测试
    --psw_nor_tf = "psw_tf_ex_yhzl_1"
    
    
    ---------------------
    
    --[merged] 抽中已拥有天赋时从当前池的未拥有子集重抽，避免点卡走"获取天赋失败"兜底
    local function _tf_owned(key)
        return psw_faction_has_effect_bundle(faction_name, "set_" .. tostring(key))
            or psw_faction_has_effect_bundle(faction_name, "set_main_" .. tostring(key))
            or (psw_main_data.global_data ~= nil and psw_main_data.global_data["set_main_" .. tostring(key)] == true)
    end
    if psw_nor_tf and _tf_owned(psw_nor_tf) then
        local _avail = {}
        for _, _t in ipairs(tf_pool) do
            if not _tf_owned(_t) then
                table.insert(_avail, _t)
            end
        end
        if #_avail > 0 then
            psw_nor_tf = _avail[cm:random_number(#_avail)]
        else
            psw_nor_tf = nil
        end
    end

    if slot:has_building() then
        cm:foreign_slot_instantly_dismantle_building(slot)
    end
    if psw_nor_tf then
        cm:foreign_slot_instantly_upgrade_building(slot, psw_nor_tf)
    end
end

local psw_ceshi_tf_ex_pool = {
    "psw_tf_nor_akuya",
    "psw_tf_ex_syd_1",
    "psw_tf_ex_fuxuan_1",
    "psw_tf_ex_qiyana_1",
    "psw_tf_ex_pql",
    "psw_tf_ex_yln_1",
    "psw_tf_ex_qiyana_1",
    "psw_tf_ex_pql",
    "psw_tf_ex_yln_1",
}

local ex_tf_to_insert_pool = {
    "psw_tf_ex_alxy_1",
    "psw_tf_ex_sywh_1",
    "psw_tf_ex_kqrn_1",
    "psw_tf_ex_bass_1",
    "psw_tf_ex_amly_1",
    "psw_tf_ex_xxdyq_1",
    "psw_tf_ex_azsyz_1",
    "psw_tf_ex_alice_1",
    "psw_tf_ex_youxiang_1",
    "psw_tf_ex_blst_1",
    "psw_tf_ex_djs_1",
    "psw_tf_ex_zhenbu_1",
    "psw_tf_ex_fuxuan_1",
    "psw_tf_ex_qiyana_1",
    "psw_tf_ex_yln_1",
    "psw_tf_ex_xingfa_1",
    "psw_tf_ex_yls_1",
    "psw_tf_ex_skd_1",
    "psw_tf_ex_miao_1",
    "psw_tf_ex_tsg_1",
    "psw_tf_ex_firefly_1",
    "psw_tf_ex_jwts_1",
    "psw_tf_ex_ams_1",
    "psw_tf_ex_jinxi_1",
    "psw_tf_ex_klt_1",
    "psw_tf_ex_feibi_1",
    "psw_tf_ex_xingye_1",
    "psw_tf_ex_xuefeng_1",
    "psw_tf_ex_lilika_1",
    "psw_tf_sp_baiye",
    "psw_tf_sp_kokoro",
    "psw_tf_sp_feixiao",
    "psw_tf_sp_tifeng",
    "psw_tf_ex_chazuo",
    "psw_tf_sp_luluka",
}

---兰德索尔唯一天赋
local gzqs_ldsr_tf_pool_ex = {
    "psw_tf_ex_xxdyq_1",
    "psw_tf_ex_zhenbu_1",
    "psw_tf_ex_xingfa_1",
}

---蔷薇少女唯一天赋
local qwsn_tf_pool_ex = {
    "psw_tf_sp_qwsj",
}



---精灵特性唯一天赋
local jingling_tx_tf_ex = {
    "psw_tf_sp_kokoro",
    "psw_tf_ex_ams_1",
    "psw_tf_ex_amly_1",
    "psw_tf_ex_xxdyq_1",
    "psw_tf_ex_blst_1",
    "psw_tf_ex_xingfa_1",
}

---共鸣者 唯一判定
local gmz_ex_tf_pd = {
    psw_tf_ex_feibi_1 = true,
    psw_tf_ex_klt_1 = true,
    psw_tf_ex_jinxi_1 = true,
}


local function get_beilv_tf(pool)
    
    local index_ex = cm:random_number(#pool)
    local tf = tostring(pool[index_ex])
    if tf:starts_with("psw_tf_ex_fia_1") then
        tf = "psw_tf_ex_fia_1"
    end
    return tf
end

function psw_main_ex_pool(faction_name, slot_number, is_zhongduan, zhongduan_name)
    local faction = cm:get_faction(faction_name)
    local recipient_culture = faction:culture()
    
    local culture_wang = (recipient_culture == "wh_main_emp_empire" or recipient_culture == "wh_main_brt_bretonnia" or recipient_culture == "wh3_main_cth_cathay" or recipient_culture == "wh_dlc08_nor_norsca" or recipient_culture == "wh3_main_ksl_kislev" or recipient_culture == "wh_main_chs_chaos")
    local psw_ex_tf_pool = {}
    
    local ex_count = psw_main_data.player_data[faction_name].ex_count or 0
    local jishu_nor = psw_main_data.player_data[faction_name].nor_count or 0
    local turn = cm:turn_number()
    local jishu_ayty = psw_main_data.player_data[faction_name].jishu_ayty or 0
    local psw_zhixing = psw_main_data.player_data[faction_name].psw_zhixing or 0
    local jishu_long = psw_main_data.player_data[faction_name].jishu_long or 0
    
    for i = 1, #ex_tf_to_insert_pool do
        local insert_tf = ex_tf_to_insert_pool[i]
        if not psw_faction_has_effect_bundle(faction_name, "set_main_"..tostring(insert_tf)) then
            table.insert(psw_ex_tf_pool, insert_tf)
        end
    end
    
    ---真红/水银灯 爱与恨的宿命交织
    if not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_zhenhong_1") then
        if not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_syd_1") then
            table.insert(psw_ex_tf_pool, "psw_tf_ex_syd_1")
        end
    end
    if not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_syd_1") then
        if not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_zhenhong_1") then
            table.insert(psw_ex_tf_pool, "psw_tf_ex_zhenhong_1")
        end
    end
    
    ---丘比
    if not psw_faction_has_effect_bundle(faction_name, "set_main_qb_1") and not faction:has_effect_bundle("set_qiyuan_100ex") and ((ex_count + jishu_nor) < 6 or faction:has_effect_bundle("hero_select_lmyx")) then
        insert_more_tf_to_pool("psw_tf_sp_qb_tf", psw_ex_tf_pool, 3)
    end
    
    ---帕秋莉
    if not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_pql") and psw_zhixing >= 4 then
        table.insert(psw_ex_tf_pool, "psw_tf_ex_pql")
    end
    
    ---暗影大人
    if (ex_count + jishu_nor) < 6 and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_anying_1") then
        insert_more_tf_to_pool("psw_tf_ex_anying_1", psw_ex_tf_pool, 1)
    end
    
    ---绚丽凤凰·小凤
    if jishu_long >= 1 and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_sp_xlfh") then
        insert_more_tf_to_pool("psw_tf_sp_xlfh", psw_ex_tf_pool, 1)
    end
    
    if culture_wang and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_ybbb_1") then
        table.insert(psw_ex_tf_pool, "psw_tf_ex_ybbb_1")
    end

    if not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_sp_qwsj") and not faction:has_effect_bundle("set_qiyuan_100ex") then
        table.insert(psw_ex_tf_pool, "psw_tf_sp_qwsj")
        if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_ex_zhenhong_1") then
            insert_more_tf_to_pool("psw_tf_sp_qwsj", psw_ex_tf_pool, 4)
        end
    end
    
    if not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_btmmfs_1") and (psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_wcbldsj_nor") or psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yrhtdsj_nor") or psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_wcbldsg_nor")) then
        insert_more_tf_to_pool("psw_tf_ex_btmmfs_1", psw_ex_tf_pool, 2)
    end
    
    ----------圣娅 预知梦----------
    if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_shengya") and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_sywh_1") then
        insert_more_tf_to_pool("psw_tf_ex_sywh_1", psw_ex_tf_pool, 4)
    end
    
    ----------公主骑士 连结之力----------
    if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_gzqs") then
        for i = 1, #gzqs_ldsr_tf_pool_ex do
            local insert_tf = gzqs_ldsr_tf_pool_ex[i]
            if not psw_faction_has_effect_bundle(faction_name, "set_main_"..tostring(insert_tf)) then
                insert_more_tf_to_pool(insert_tf, psw_ex_tf_pool, 4)
            end
        end
    end
    
    ----------丘比----------
    if psw_faction_has_effect_bundle(faction_name, "set_main_qb_1") and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_yhzl_1") then
        insert_more_tf_to_pool("psw_tf_ex_yhzl_1", psw_ex_tf_pool, 1)
    end
    
    ----------白子----------
    if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_baizi") and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_xingye_1") then
        insert_more_tf_to_pool("psw_tf_ex_xingye_1", psw_ex_tf_pool, 4)
    end
    
    ----------柚子----------
    if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yozi") then
        if not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_alice_1") then
            insert_more_tf_to_pool("psw_tf_ex_alice_1", psw_ex_tf_pool, 4)
        end
        if not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_youxiang_1") then
            insert_more_tf_to_pool("psw_tf_ex_youxiang_1", psw_ex_tf_pool, 4)
        end
    end
    
    ----------莉莉卡----------
    if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_lilika") and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_lilika_1") then
        insert_more_tf_to_pool("psw_tf_ex_lilika_1", psw_ex_tf_pool, 4)
    end
    
    
    
    local psw_ex_tf
    local index_ex
    
    
    
    ------------------ 保底相关 -------------------
    ----------心智魔方3----------
    
    
    if slot_number == 1 then
        if psw_faction_has_effect_bundle(faction_name, "blhx_xzmf_3_use") then
            psw_ex_tf_pool = {}
            if not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_blst_1") then
                table.insert(psw_ex_tf_pool, "psw_tf_ex_blst_1")
            elseif not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_yls_1") then
                table.insert(psw_ex_tf_pool, "psw_tf_ex_yls_1")
            elseif not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_skd_1") then
                table.insert(psw_ex_tf_pool, "psw_tf_ex_skd_1")
            elseif not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_djs_1") then
                table.insert(psw_ex_tf_pool, "psw_tf_ex_djs_1")
            end
            index_ex = cm:random_number(#psw_ex_tf_pool)
            psw_ex_tf = psw_ex_tf_pool[index_ex]
            cm:remove_effect_bundle("blhx_xzmf_3_use", faction_name)
            cm:remove_effect_bundle("pick_up_dingxiang", faction_name)
        ----------记忆碎片-琳芙斯----------
        elseif faction:has_effect_bundle("set_jysp_azsyz") and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_azsyz_1") then
            psw_ex_tf = "psw_tf_ex_azsyz_1"
            cm:remove_effect_bundle("set_jysp_azsyz", faction_name)
        ----------圣娅-预知梦-未花----------
        elseif psw_faction_has_effect_bundle(faction_name, "psw_dlc6_shengya_yzm_mika") and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_sywh_1") then
            psw_ex_tf = "psw_tf_ex_sywh_1"
            cm:remove_effect_bundle("psw_dlc6_shengya_yzm_mika", faction_name);
        ----------丘比----------
        elseif psw_faction_has_effect_bundle(faction_name, "qb_cw_mfsn") and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_yhzl_1") then
            psw_ex_tf = "psw_tf_ex_yhzl_1"
            cm:remove_effect_bundle("qb_cw_mfsn", faction_name);
        ----------第七人偶 无心の人偶----------
        elseif psw_faction_has_effect_bundle(faction_name, "psw_qwsn_100") and (not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_zhenhong_1") or not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_syd_1")) then
            local qwsn_pool = {}
            if not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_zhenhong_1") then
                table.insert(qwsn_pool, "psw_tf_ex_zhenhong_1")
            end
            if not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_syd_1") then
                table.insert(qwsn_pool, "psw_tf_ex_syd_1")
            end
            index_ex = cm:random_number(#qwsn_pool)
            psw_ex_tf = qwsn_pool[index_ex]
            cm:remove_effect_bundle("psw_qwsn_100", faction_name);
        ---------- 柚子 我们的冒险 ----------
        elseif psw_faction_has_effect_bundle(faction_name, "psw_jyjj_wmdmx_effect") and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_alice_1") then
            psw_ex_tf = "psw_tf_ex_alice_1"
            cm:remove_effect_bundle("psw_jyjj_wmdmx_effect", faction_name);
            
        ----------星咏真白 精灵眼----------
        elseif faction:has_effect_bundle("psw_dlc7_shiro_jinglingyan") then
            local jly_pool = {}
            for i = 1, #jingling_tx_tf_ex do
                local insert_tf = jingling_tx_tf_ex[i]
                if not psw_faction_has_effect_bundle(faction_name, "set_main_"..tostring(insert_tf)) then
                    table.insert(jly_pool, insert_tf)
                end
            end
            if (ex_count + jishu_nor) == 2 and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_fia_1") then
                table.insert(jly_pool, "psw_tf_ex_fia_1")
            end
            index_ex = cm:random_number(#jly_pool)
            psw_ex_tf = jly_pool[index_ex]
            cm:remove_effect_bundle("psw_dlc7_shiro_jinglingyan", faction_name)
            
        ----------爱梅斯 小仓唯（唯一） 记忆碎片----------
        elseif not psw_faction_has_effect_bundle(faction_name, "set_main_" .. "psw_tf_ex_xxdyq_1") and psw_faction_has_effect_bundle(faction_name, "set_psw_dlc7_ams_shop_exxcw") then
            psw_ex_tf = "psw_tf_ex_xxdyq_1"
            cm:remove_effect_bundle("set_psw_dlc7_ams_shop_exxcw", faction_name)
            
        ----------爱梅斯 可可萝（唯一） 记忆碎片----------
        elseif not psw_faction_has_effect_bundle(faction_name, "set_main_" .. "psw_tf_sp_kokoro") and psw_faction_has_effect_bundle(faction_name, "set_psw_dlc7_ams_shop_spkokora") then
            psw_ex_tf = "psw_tf_sp_kokoro"
            cm:remove_effect_bundle("set_psw_dlc7_ams_shop_spkokora", faction_name)
            
        ----------爱梅斯 星法 记忆碎片----------
        elseif not psw_faction_has_effect_bundle(faction_name, "set_main_" .. "psw_tf_ex_xingfa_1") and psw_faction_has_effect_bundle(faction_name, "set_psw_dlc7_ams_shop_xingfa") then
            psw_ex_tf = "psw_tf_ex_xingfa_1"
            cm:remove_effect_bundle("set_psw_dlc7_ams_shop_xingfa", faction_name)
            
        ----------爱梅斯 真歩 记忆碎片----------
        elseif not psw_faction_has_effect_bundle(faction_name, "set_main_" .. "psw_tf_ex_zhenbu_1") and psw_faction_has_effect_bundle(faction_name, "set_psw_dlc7_ams_shop_zhenbu") then
            psw_ex_tf = "psw_tf_ex_zhenbu_1"
            cm:remove_effect_bundle("set_psw_dlc7_ams_shop_zhenbu", faction_name)
            
            
        ----------共鸣者 ----------
        elseif faction:has_effect_bundle("psw_dlc7_mc_gmz100") then
            
            
            local gmz_pool = {}
            for i = 1, #gmz_ex_tf_pool do
                local gmz_tf = gmz_ex_tf_pool[i]
                if not psw_faction_has_effect_bundle(faction_name, "set_main_"..tostring(gmz_tf)) then
                    table.insert(gmz_pool, gmz_tf)
                end
            end
            if #gmz_pool > 0 then
                local ran_num_gmz = cm:random_number(#gmz_pool)
                psw_ex_tf = gmz_pool[ran_num_gmz]
            else
                index_ex = cm:random_number(#psw_ex_tf_pool)
                psw_ex_tf = psw_ex_tf_pool[index_ex]
            end
            
            cm:remove_effect_bundle("psw_dlc7_mc_gmz100", faction_name)

            
            
        ----------唯一保底----------
        elseif faction:has_effect_bundle("set_qiyuan_100ex") then
            index_ex = cm:random_number(#psw_ex_tf_pool)
            psw_ex_tf = psw_ex_tf_pool[index_ex]
            cm:remove_effect_bundle("set_qiyuan_100ex", faction_name)
        ----------终端----------
        elseif is_zhongduan and slot_number == 1 then
            psw_ex_tf = zhongduan_name
        ----------特殊----------
        ---菲娅
        elseif (ex_count + jishu_nor) == 2 and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_fia_1") and slot_number == 1 then
            insert_more_tf_to_pool("psw_tf_ex_fia_1", psw_ex_tf_pool, 6)
            index_ex = cm:random_number(#psw_ex_tf_pool)
            psw_ex_tf = psw_ex_tf_pool[index_ex]
            
        
        ----------其他情况----------
        else
            index_ex = cm:random_number(#psw_ex_tf_pool)
            psw_ex_tf = psw_ex_tf_pool[index_ex]
            
        end
    elseif slot_number == 2 then
        ---暗影庭院
        if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_ex_anying_1") and jishu_ayty <= 7 and not faction:has_effect_bundle("psw_dlc6_anying_baodi_effect") then
            index_ex = cm:random_number(#psw_ex_tf_pool)
            psw_ex_tf = psw_ex_tf_pool[index_ex]
            if turn == 2 or turn == 25 then
                psw_ex_tf_pool = {}
                for j = 1, #ayty_qiying_pool do
                    local insert_e = ayty_qiying_pool[j]
                    if not psw_faction_has_effect_bundle(faction_name, "set_"..tostring(insert_e)) then
                        table.insert(psw_ex_tf_pool, insert_e)
                    end
                end
                index_ex = cm:random_number(#psw_ex_tf_pool)
                psw_ex_tf = psw_ex_tf_pool[index_ex]
                psw_aplly_costom_effect_bundle_with_time_hidden("psw_dlc6_anying_baodi_effect", faction, 1)
            end
        elseif psw_faction_has_effect_bundle(faction_name, "psw_dlc6_shengya_yzm_mika") and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_sywh_1") then
            psw_ex_tf = "psw_tf_ex_sywh_1"
            cm:remove_effect_bundle("psw_dlc6_shengya_yzm_mika", faction_name);
        ---菲娅
        elseif (ex_count + jishu_nor) == 2 and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_fia_1") then
            insert_more_tf_to_pool("psw_tf_ex_fia_1", psw_ex_tf_pool, 6)
            index_ex = cm:random_number(#psw_ex_tf_pool)
            psw_ex_tf = psw_ex_tf_pool[index_ex]
        else
            index_ex = cm:random_number(#psw_ex_tf_pool)
            psw_ex_tf = psw_ex_tf_pool[index_ex]
        end
    else
        if psw_faction_has_effect_bundle(faction_name, "psw_dlc6_shengya_yzm_mika") and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_sywh_1") then
            psw_ex_tf = "psw_tf_ex_sywh_1"
            cm:remove_effect_bundle("psw_dlc6_shengya_yzm_mika", faction_name);
        elseif psw_faction_has_effect_bundle(faction_name, "psw_tf_nor_shengya_zt_effect_bundle") and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_sywh_1") then
            psw_nor_tf = "psw_tf_ex_sywh_1"
            cm:remove_effect_bundle("psw_tf_nor_shengya_zt_effect_bundle", faction_name);
        ---菲娅
        elseif (ex_count + jishu_nor) == 2 and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_fia_1") then
            insert_more_tf_to_pool("psw_tf_ex_fia_1", psw_ex_tf_pool, 6)
            index_ex = cm:random_number(#psw_ex_tf_pool)
            psw_ex_tf = psw_ex_tf_pool[index_ex]
        else
            index_ex = cm:random_number(#psw_ex_tf_pool)
            psw_ex_tf = psw_ex_tf_pool[index_ex]
        end
    end
    -------------------------------------
    
    
    
    
    ---------------------


    
    local yx_subtype = psw_main_data.player_data[faction_name].yx_subtype or "yx_lmyx"
    local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
    local region_name = psw_main_data.player_data[faction_name].region_name
    local tf_region = cm:get_region(region_name)
    if not tf_region or tf_region:is_null_interface() then
        local _home_region = faction:home_region()
        if _home_region and not _home_region:is_null_interface() then
            tf_region = _home_region
            region_name = _home_region:name()
        else
            return
        end
    end
    local _fsm = tf_region:foreign_slot_manager_for_faction(faction_name)
    if not _fsm or _fsm:is_null_interface() then
        cm:add_foreign_slot_set_to_region_for_faction(faction:command_queue_index(), tf_region:cqi(), "psw_cult_slot_set_key")
        _fsm = tf_region:foreign_slot_manager_for_faction(faction_name)
        if not _fsm or _fsm:is_null_interface() then return end
    end
    local slot_n_list = _fsm:slots()
    if not slot_n_list or slot_n_list:num_items() < slot_number then return end
    local slot = slot_n_list:item_at(slot_number-1)
    if not slot or slot:is_null_interface() then return end
    --[merged] 抽中已拥有唯一天赋时从未拥有子集重抽，避免点卡走"获取天赋失败"兜底
    local function _ex_tf_owned(key)
        return psw_faction_has_effect_bundle(faction_name, "set_" .. tostring(key))
            or psw_faction_has_effect_bundle(faction_name, "set_main_" .. tostring(key))
            or (psw_main_data.global_data ~= nil and psw_main_data.global_data["set_main_" .. tostring(key)] == true)
    end
    if psw_ex_tf and _ex_tf_owned(psw_ex_tf) then
        local _avail = {}
        for _, _t in ipairs(psw_ex_tf_pool) do
            if not _ex_tf_owned(_t) then
                table.insert(_avail, _t)
            end
        end
        if #_avail > 0 then
            psw_ex_tf = _avail[cm:random_number(#_avail)]
        else
            psw_ex_tf = nil
        end
    end
    if slot:has_building() then
        cm:foreign_slot_instantly_dismantle_building(slot)
    end
    if psw_ex_tf then
        cm:foreign_slot_instantly_upgrade_building(slot, psw_ex_tf)
    end
end









--------------------------------------------------------------
----------------------- 仪式完成监听主函数 -------------------------
-------------------------------------------------------------- 


function psw_ritual_main_listener()
    core:remove_listener("psw_ritual_main_listener")
    core:add_listener(
        "psw_ritual_main_listener",
        "RitualCompletedEvent",
        function(context)
            return true
        end,
        function(context)
            
            local ritual = context:ritual()
            local ritual_key = ritual:ritual_key()
            local ritual_target = ritual:ritual_target()
            local target_type = ritual_target:target_type()
            local target_force_commander_cqi = 0
            local target_region_cqi = 0
            local target_faction
            local target_faction_name
            local faction = context:performing_faction()
            local target_character_cqi
            local target_character
            
            local faction_name = faction:name()
            local psw_main_character = psw_get_main_character(faction_name)
            
            if target_type == "MILITARY_FORCE" or target_type == "REGION" then
                if target_type == "MILITARY_FORCE" then 
                    local mf = ritual_target:get_target_force()
                    target_faction = mf:faction()
                    target_faction_name = target_faction:name()
                    if mf:has_general() then
                        target_character_cqi = mf:general_character():command_queue_index()
                        target_character = cm:get_character_by_cqi(target_character_cqi)
                    end
                    
                elseif target_type == "REGION" then 
                    local target_faction_cqi = ritual_target:get_target_region():faction():cqi()
                    target_region_cqi = ritual_target:get_target_region():cqi()
                end
            end
            
            
            ---爱丽丝决斗
            if ritual_key:starts_with("psw_dlc6_alice_game_juedou") and psw_main_data.global_data.psw_alice_game_start and not psw_main_data.global_data.psw_alice_game_is_end then
                if (not psw_faction_has_effect_bundle(faction_name, "alice_game_player")) or (psw_faction_has_effect_bundle(faction_name, "alice_game_battler")) then
                    return
                end
                if (not psw_faction_has_effect_bundle(target_faction_name, "alice_game_player")) or (psw_faction_has_effect_bundle(target_faction_name, "alice_game_battler")) then
                    return
                end
                
                cm:trigger_dilemma(target_faction_name, "dilemma_tf_alice_game_yqh")
                
                psw_main_data.player_data[target_faction_name].psw_alice_game_jdfqz_name = faction_name
                
            ---梗小姐 恶魔的契约
            elseif ritual_key:starts_with("psw_dlc6_gxj_emqy") and psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_gengxj") and not psw_faction_has_effect_bundle(faction_name, "psw_dlc6_gxj_yqy") and not psw_faction_has_effect_bundle(target_faction_name, "is_gxj_qyz") then
                
                psw_dlc6_gxj_qdqy(faction_name, target_faction_name)
                
            ---符玄 帝弓降世
            elseif ritual_key:starts_with("psw_dlc6_ex_fuxuan_dgjs") and psw_faction_has_effect_bundle(faction_name, "fuxuan_dgjs_can_use") then
                psw_dlc6_fuxuan_dgjs_effect(faction, target_faction, target_character)
                
            ---暗影 I...Am...Atomic
            elseif ritual_key:starts_with("psw_dlc6_anying_atomic") and not faction:has_effect_bundle("ewnl_cd_psw_tf_ex_anying_2") then
                psw_dlc6_anying_atomic_apply(faction, target_faction, target_character)
                
                
                
                
                
            ---帕秋莉 七曜元素祝福
            elseif ritual_key:starts_with("psw_pql_") then
                if target_character == psw_main_character then
                    local music_list = {
                        "pql_jd_1",
                        "pql_jd_2",
                        "pql_jd_3",
                    }
                    psw_play_random_music(music_list)
                    local psw_pql_qyyszf = faction:pooled_resource_manager():resource("psw_pql_qyyszf"):value()
                    if ritual_key == "psw_pql_huo" and psw_pql_qyyszf >= 1 then
                        psw_add_pql_qyyszf(faction_name, -1)
                        psw_pql_huo_level(faction_name, 1)
                    elseif ritual_key == "psw_pql_shui" and psw_pql_qyyszf >= 1 then
                        psw_add_pql_qyyszf(faction_name, -1)
                        psw_pql_shui_level(faction_name, 1)
                    elseif ritual_key == "psw_pql_mu" and psw_pql_qyyszf >= 1 then
                        psw_add_pql_qyyszf(faction_name, -1)
                        psw_pql_mu_level(faction_name, 1)
                    elseif ritual_key == "psw_pql_jin" and psw_pql_qyyszf >= 1 then
                        psw_add_pql_qyyszf(faction_name, -1)
                        psw_pql_jin_level(faction_name, 1)
                    elseif ritual_key == "psw_pql_tu" and psw_pql_qyyszf >= 1 then
                        psw_add_pql_qyyszf(faction_name, -1)
                        psw_pql_tu_level(faction_name, 1)
                    elseif ritual_key == "psw_pql_ri" and psw_pql_qyyszf >= 2 then
                        psw_add_pql_qyyszf(faction_name, -2)
                        psw_pql_ri_level(faction_name, 1)
                    elseif ritual_key == "psw_pql_yue" and psw_pql_qyyszf >= 2 then
                        psw_add_pql_qyyszf(faction_name, -2)
                        psw_pql_yue_level(faction_name, 1)
                    else
                        alice_dlc6_pql_qyyszf_not_enough()
                    end
                    ewnl_ui_display_pql(faction_name)
                ---符卡配置
                else
                    psw_dlc6_pql_fkpz(faction_name, ritual_key)
                    ewnl_ui_display_pql(faction_name)
                end
                
                
            ---帕秋莉 诺亚的大洪水
            elseif ritual_key:starts_with("psw_dlc6_pql_ewnl_nyddhs") then
                pql_shui_tu_effect(faction, target_faction, target_character)
                
            ---琪亚娜 异界跃迁 选择自己 效果赋予/界面切换
            elseif ritual_key:starts_with("psw_dlc6_qiyana_yjyq_own") then
                ewnl_ui_display_qiyana_yjyq_ally(faction_name)
                psw_dlc6_qiyana_yjyq_cha_own_apply(faction, target_character)
                
            ---琪亚娜 异界跃迁 选择友军
            elseif ritual_key:starts_with("psw_dlc6_qiyana_yjyq_ally") then
                psw_dlc6_qiyana_yjyq_cha_ally_apply(faction, target_character)
                
           ---星法 流星雨
            elseif ritual_key:starts_with("psw_dlc6_xingfa_cnl_liuxing") then
                psw_dlc6_xingfa_cnl_liuxing_effect(faction, target_faction, target_character)
                
            ---圣园未花 未花的援护
            elseif ritual_key:starts_with("psw_dlc6_ex_mika_mulu_whdwh") then
                psw_dlc6_sywh_effect_apply_whdyh(faction, target_character)
                
            ---飞雷神
            elseif ritual_key:starts_with("psw_jyjj_xg_main_feileishen") then
                psw_jyjj_feileishen_effect(faction_name, target_character)
                local music_list = {
                    "jyjj_feileishen_1",
                    "jyjj_feileishen_2",
                }
                psw_play_random_music(music_list)
                
            ---瞳术天照 
            elseif ritual_key:starts_with("psw_jyjj_xg_zuozhu_tstz") then
                psw_jyjj_tstz_effect(target_character)
                local music_list = {
                    "zuozhu_xly",
                }
                psw_play_random_music(music_list)
                
            ---慈爱的飞吻 
            elseif ritual_key:starts_with("psw_jyjj_xg_mali_chu") then
                psw_dlc7_cadfw_effect(faction_name, target_character)
                local music_list = {
                    "jyjj_mali_cadfw_2",
                    "jyjj_mali_cadfw_1",
                }
                psw_play_random_music(music_list)
                
            ---起源弹
            elseif ritual_key:starts_with("psw_jyjj_xg_qiesi_qyd") then
                psw_dlc7_qeisi_qyd_effect(target_character)
                local music_list = {
                    "jyjj_qs_qyd",
                }
                psw_play_random_music(music_list)
                
            ---演出开始
            elseif ritual_key:starts_with("psw_jyjj_xg_xnm_ycks") then
                psw_dlc7_xnm_ycks_effect(faction_name, target_character)
                local music_list = {
                    "xnm_bgm_2",
                    "xnm_bgm_1",
                }
                psw_play_random_music(music_list)
                
            ---该剪票了哦~ 咲夜时符
            elseif ritual_key:starts_with("psw_jyjj_xg_main_jianpiao") or ritual_key:starts_with("psw_jyjj_xd_xiaoye_shifu") then
                psw_dlc7_main_jp_effect(target_character)
                if ritual_key == "psw_jyjj_xg_main_jianpiao" then
                    local music_list = {
                        "jyjj_jianpiao",
                    }
                    psw_play_random_music(music_list)
                else
                    local music_list = {
                        "jyjj_xiaoye",
                    }
                    psw_play_random_music(music_list)
                end
            ---安的巨大英灵
            elseif ritual_key:starts_with("psw_jyjj_xd_anne_jdyl") then
                psw_jyjj_effect_anne_jdyl(target_character)
                local music_list = {
                    "jyjj_anne_yl_1",
                    "jyjj_anne_yl_2",
                }
                psw_play_random_music(music_list)
            ---菲比 镜之环
            elseif ritual_key:starts_with("psw_jyjj_xd_feibi_jzh") then
                psw_dlc7_jyjj_effect_jzh(faction_name, target_character)
                local music_list = {
                    "jyjj_feibi_jzh_2",
                    "jyjj_feibi_jzh_1",
                }
                psw_play_random_music(music_list)
                
            ---坎特蕾拉 感知汲取
            elseif ritual_key:starts_with("psw_jyjj_xg_ktll_gzjq") then
                psw_dlc7_jyjj_ktll_gzjq_effect(faction_name, target_character)
                local music_list = {
                    "jyjj_ktll_gzjq_2",
                    "jyjj_ktll_gzjq_1",
                    "jyjj_ktll_gzjq_3",
                }
                psw_play_random_music(music_list)
                
            ------------------------------------
                
            end
            
            
        end,
        true
    )
end

--------------------------------------------------------------
----------------------- 物品使用监听主函数 -------------------------
-------------------------------------------------------------- 
local can_use_ancillary_list = {
    psw_moyin_shendou = true,
    psw_moyin_emgs_s = true,
    psw_moyin_emgs_n = true,
    psw_moyin_emgs_k = true,
    psw_moyin_emgs_t = true,
    psw_cssj_xuefeng = true,
}

function psw_main_AncillaryGained_listner()
    core:remove_listener("psw_main_AncillaryGained_listner")
    core:add_listener(
    "psw_main_AncillaryGained_listner",
    "CharacterAncillaryGained",
    function(context)
        return context:ancillary():starts_with("psw_dlc") or context:ancillary() == "psw_boss_sjszy" or context:ancillary():starts_with("psw_moyin_ex_") or can_use_ancillary_list[ context:ancillary() ]
    end,
    function(context)
        local faction_name = context:character():faction():name()
        local faction = cm:get_faction(faction_name)
        local ancillary = context:ancillary()
        local character = context:character()
        local effect_list
        local psw_main_character = psw_get_main_character(faction_name)
        
        ---爱丽丝决斗邀请函
        if ancillary == "psw_dlc6_alice_game_yqh" then
            if not character:has_military_force() then
                return
            end
            psw_delete_character_ancillary_with_time(character, ancillary, 0.1)
            psw_dlc6_alice_game_teleport_to(faction_name, character)
            
        ---诺艾尔的卵
        elseif ancillary == "psw_dlc6_chusheng_luan" then
            psw_delete_character_ancillary_with_time(character, ancillary, 0.1)
            cm:add_ancillary_to_faction(faction, "psw_dlc6_chusheng_jiandan", false)
        ---诺艾尔的煎蛋
        elseif ancillary == "psw_dlc6_chusheng_jiandan" then
            psw_delete_character_ancillary_with_time(character, ancillary, 0.1)
            psw_main_heal_character_force(character, 20)
        
        ---金色的记忆
        elseif ancillary == "psw_boss_sjszy" and psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_ex_you_ex") then
            psw_delete_character_ancillary_with_time(character, ancillary, 0.1)
            cm:add_ancillary_to_faction(faction, "you_jsdjy", false)
            psw_add_jishu_zhiyu(faction_name, 2)
        ---金苹果
        elseif ancillary == "psw_boss_sjszy" and psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_bshu") then
            psw_delete_character_ancillary_with_time(character, ancillary, 0.1)
            cm:add_ancillary_to_faction(faction, "psw_dlc6_bshu_jpg", false)
        ---南小鸟
        elseif ancillary == "psw_dlc6_nxn_xndyz" then
            psw_delete_character_ancillary_with_time(character, ancillary, 0.1)
            local nxn_zhiyu = psw_main_data.player_data[faction_name].psw_zhiyu
            local nxn_heal_num = 10 + (nxn_zhiyu * 3)
            psw_main_heal_character_force(character, nxn_heal_num)
            common.trigger_soundevent("xndyz_fight")
            effect_list = {
                {effect = "wh_main_effect_force_stat_leadership", effect_scope = "character_to_force_own", effect_num = 8},
                {effect = "wh_main_effect_force_stat_magic_resistance", effect_scope = "character_to_force_own", effect_num = 10},
                {effect = "wh_main_effect_force_stat_speed", effect_scope = "character_to_force_own", effect_num = 12},
            }
            
            psw_main_apply_effect_to_character(character, "psw_tf_nor_nxn_xndyz_effect", 1, effect_list)
            
        ---悲叹之种
        elseif ancillary == "psw_dlc6_mfsnxy_btzz" then
            psw_delete_character_ancillary_with_time(character, ancillary, 0.1)
            psw_dlc6_btzz_use_effect(faction_name)
            
        ---佐仓杏子 苹果
        elseif ancillary == "psw_dlc6_zcxz_pg" then
            psw_delete_character_ancillary_with_time(character, ancillary, 0.1)
            psw_main_heal_character_force(character, 20)
            effect_list = {
                {effect = "wh_main_effect_force_stat_melee_attack", effect_scope = "character_to_force_own", effect_num = 4},
            }
            
            psw_main_apply_effect_to_character(character, "psw_dlc6_zcxz_pingguo", 0, effect_list)
        
        ---唯一遗物 换生灵
        elseif ancillary == "psw_moyin_ex_hsl" then
            psw_remove_all_faction_ancillary(ancillary)
            psw_add_jishu_zhongmo(1)
            psw_dlc6_yiwu_ex_hsl_effect_apply(faction_name)
            psw_aplly_costom_effect_bundle_hidden_fn("psw_moyin_ex_hsl_get", faction_name)
        ---唯一遗物 提亚马特
        elseif ancillary == "psw_moyin_ex_tymt" then
            psw_remove_all_faction_ancillary(ancillary)
            psw_add_jishu_zhongmo(1)
            psw_dlc6_yiwu_ex_tymt_effect_apply(faction_name)
            psw_aplly_costom_effect_bundle_hidden_fn("psw_moyin_ex_tymt_get", faction_name)
        ---唯一遗物 日神之乌
        elseif ancillary == "psw_moyin_ex_rszw" then
            psw_remove_all_faction_ancillary(ancillary)
            psw_add_jishu_zhongmo(1)
            psw_dlc6_yiwu_ex_rszw_effect_apply(faction_name)
            psw_aplly_costom_effect_bundle_hidden_fn("psw_moyin_ex_rszw_get", faction_name)
        ---唯一遗物 三株树
        elseif ancillary == "psw_moyin_ex_szs" then
            psw_remove_all_faction_ancillary(ancillary)
            psw_add_jishu_zhongmo(1)
            psw_dlc6_yiwu_ex_szs_effect_apply(faction_name)
            psw_aplly_costom_effect_bundle_hidden_fn("psw_moyin_ex_szs_get", faction_name)
        ---唯一遗物 星之彩
        elseif ancillary == "psw_moyin_ex_xzc" then
            psw_remove_all_faction_ancillary(ancillary)
            psw_add_jishu_zhongmo(1)
            psw_dlc6_yiwu_ex_xzc_effect_apply(faction_name)
            psw_aplly_costom_effect_bundle_hidden_fn("psw_moyin_ex_xzc_get", faction_name)
        
        
        ---神豆
        elseif ancillary == "psw_moyin_shendou" then
            psw_delete_character_ancillary_with_time(character, ancillary, 0.1)
            psw_main_data.player_data[faction_name].psw_shendou_add_qsx = psw_main_data.player_data[faction_name].psw_shendou_add_qsx + 1
            local psw_shendou_add_qsx = psw_main_data.player_data[faction_name].psw_shendou_add_qsx
            psw_add_all_sx_to_faction(psw_main_character, "psw_dlc6_moyin_shendou_effect", psw_shendou_add_qsx, 1)
        
        ---恶魔果实
        elseif ancillary:starts_with("psw_moyin_emgs") then
            psw_delete_character_ancillary_with_time(character, ancillary, 0.1)
            psw_moyin_emgs_effect_apply(character, ancillary)
        
        ---妮可冒险谭
        elseif ancillary:starts_with("psw_dlc6_yln_nkmxt") then
            psw_dlc6_mnrj_nike(faction_name)
            
        ---伊蕾娜 止痛药
        elseif ancillary:starts_with("psw_dlc6_yln_zty") then
            psw_delete_character_ancillary_with_time(character, ancillary, 0.1)
            psw_main_heal_character_force(character, 35)
        
        ---伊蕾娜 蘑菇
        elseif ancillary:starts_with("psw_dlc6_yln_mogu") then
            psw_delete_character_ancillary_with_time(character, ancillary, 0.1)
            local ran_yln_mogu = cm:random_number(50, 25)
            psw_main_cost_faction_to_force_all(faction_name, ran_yln_mogu)
            cm:callback(function()
                cm:add_ancillary_to_faction(faction, "psw_dlc6_yln_mogu", true)
                psw_yln_jishu_mogu(faction_name, 1)
            end, 1)
            
        ---百可花
        elseif ancillary:starts_with("psw_dlc7_bkh_") then
            psw_delete_character_ancillary_with_time(character, ancillary, 0.1)
            if ancillary == "psw_dlc7_bkh_1" then
                psw_add_jishu_xingyun(faction_name, 1)
            elseif ancillary == "psw_dlc7_bkh_2" then
                psw_add_jishu_xingyun(faction_name, 1)
                psw_add_jishu_ewai_xingyun(faction_name, 3)
            else
                psw_add_jishu_xingyun(faction_name, 2)
                psw_add_jishu_ewai_xingyun(faction_name, 5)
            end
        ---合欢
        elseif ancillary:starts_with("psw_dlc7_hehuan_") then
            psw_delete_character_ancillary_with_time(character, ancillary, 0.1)
            if ancillary == "psw_dlc7_hehuan_1" then
                psw_add_jishu_xingyun(faction_name, 1)
            elseif ancillary == "psw_dlc7_hehuan_2" then
                psw_add_jishu_xingyun(faction_name, 1)
                psw_add_free_repick_num(faction_name, 1)
            else
                psw_add_jishu_xingyun(faction_name, 2)
                psw_add_free_repick_num(faction_name, 2)
            end
        ---美耳草
        elseif ancillary:starts_with("psw_dlc7_mec_") then
            psw_delete_character_ancillary_with_time(character, ancillary, 0.1)
            if ancillary == "psw_dlc7_hehuan_1" then
                psw_add_jishu_xingyun(faction_name, 1)
            elseif ancillary == "psw_dlc7_hehuan_2" then
                psw_add_jishu_xingyun(faction_name, 1)
                psw_jyjj_tili_num_change(faction_name, 1, "max_level_up")
            else
                psw_add_jishu_xingyun(faction_name, 2)
                psw_jyjj_tili_num_change(faction_name, 1, "max_level_up")
                psw_tfmw_main_hp_effect(1, faction_name, "levelup")
            end
        ---香草
        elseif ancillary:starts_with("psw_dlc7_xiangcao_") then
            psw_delete_character_ancillary_with_time(character, ancillary, 0.1)
            if ancillary == "psw_dlc7_hehuan_1" then
                psw_add_jishu_xingyun(faction_name, 1)
            elseif ancillary == "psw_dlc7_hehuan_2" then
                psw_add_jishu_xingyun(faction_name, 1)
                psw_tfmw_main_atk_effect(1, faction_name, "default")
            else
                psw_add_jishu_xingyun(faction_name, 2)
                psw_tfmw_main_atk_effect(1, faction_name, "default")
                psw_tfmw_main_def_effect(1, faction_name, "default")
            end
        ---天使花
        elseif ancillary:starts_with("psw_dlc7_tsh_") then
            psw_delete_character_ancillary_with_time(character, ancillary, 0.1)
            if ancillary == "psw_dlc7_hehuan_1" then
                psw_add_jishu_xingyun(faction_name, 1)
            elseif ancillary == "psw_dlc7_hehuan_2" then
                psw_add_jishu_xingyun(faction_name, 1)
                psw_add_jishu_zhiyu(faction_name, 1)
            else
                psw_add_jishu_xingyun(faction_name, 2)
                psw_add_jishu_zhiyu(faction_name, 2)
            end
            
        ---雪风传送水晶
        elseif ancillary:starts_with("psw_cssj_xuefeng") then
            local xuefeng_fac_key = psw_main_data.global_data.xuefeng_fac_key
            local xf_fac = cm:get_faction(xuefeng_fac_key)
            local xf_fac_leader = xf_fac:faction_leader()
            if xuefeng_fac_key ~= nil then
                if xuefeng_fac_key == faction_name then
                    local x = psw_main_data.player_data[xuefeng_fac_key].xf_leader_x
                    local y = psw_main_data.player_data[xuefeng_fac_key].xf_leader_y
                    local m, n = cm:find_valid_spawn_location_for_character_from_position(xuefeng_fac_key, x, y, true, 1)
                    cm:teleport_to(cm:char_lookup_str(xf_fac_leader), m, n)
                else
                    
                    local x, y = cm:find_valid_spawn_location_for_character_from_character(xuefeng_fac_key, cm:char_lookup_str(character), true, 1)
                    psw_main_data.player_data[xuefeng_fac_key].xf_tp_cha_x = x
                    psw_main_data.player_data[xuefeng_fac_key].xf_tp_cha_y = y
                    local m, n = cm:find_valid_spawn_location_for_character_from_character(xuefeng_fac_key, cm:char_lookup_str(xf_fac_leader), true, 1)
                    psw_main_data.player_data[xuefeng_fac_key].xf_leader_x = m
                    psw_main_data.player_data[xuefeng_fac_key].xf_leader_y = n
                    cm:trigger_dilemma(xuefeng_fac_key, "dilemma_tf_dlc7_xf_zy")
                end
                psw_delete_character_ancillary_with_time(character, ancillary, 0.1)
                cm:add_ancillary_to_faction(faction, "psw_cssj_xuefeng", true)
                
            end
            
            
            
        -------------------------
        
        end
    end,
    true
    )
end

--------------------------------------------------------------
----------------------- 物品合成 监听主函数 -------------------------
-------------------------------------------------------------- 


----检测另一个角色是否有相同装备
local function jiance_other_character_is_have(faction, character_get, ancillary_get, character_other, ancillary_other, target_ancillary)
    local faction_name = faction:name()
    if character_other:has_ancillary(ancillary_other) then
        cm:add_ancillary_to_faction(faction, target_ancillary, false)
        psw_delete_character_ancillary_with_time(character_get, ancillary_get, 0.1)
        psw_delete_character_ancillary_with_time(character_other, ancillary_other, 0.1)
        if target_ancillary == "psw_dlc6_yln_zty" then
            psw_yln_jishu_zty(faction_name, 1)
        end
    end
end

local can_hec_ancillary = {
    psw_dlc6_yln_yaocao = true,
    psw_dlc6_yln_bhw = true,
}

----监听主函数
function psw_main_CharacterAncillaryHecheng_listner()
    core:remove_listener("psw_main_CharacterAncillaryHecheng_listner")
    core:add_listener(
    "psw_main_CharacterAncillaryHecheng_listner",
    "CharacterAncillaryGained",
    function(context)
        return can_hec_ancillary[ context:ancillary() ]
    end,
    function(context)
        local faction_name = context:character():faction():name()
        local psw_main_character = psw_get_main_character(faction_name)
        local character = context:character()
        local faction = cm:get_faction(faction_name)
        local faction_leader = faction:faction_leader()
        if character ~= psw_main_character and character ~= faction_leader then
            return
        end
        
        local ancillary = context:ancillary()
        
        
        local character_get = faction_leader
        local character_other = psw_main_character
        if character == psw_main_character then
            character_get = psw_main_character
            character_other = faction_leader
        end
        
        local ancillary_get = ancillary
        local ancillary_other
        local target_ancillary
        
        ---止痛药制作
        if ancillary == "psw_dlc6_yln_yaocao" then
            ancillary_other = "psw_dlc6_yln_bhw"
            target_ancillary = "psw_dlc6_yln_zty"
        elseif ancillary == "psw_dlc6_yln_bhw" then
            ancillary_other = "psw_dlc6_yln_yaocao"
            target_ancillary = "psw_dlc6_yln_zty"
        end
        
        jiance_other_character_is_have(faction, character_get, ancillary_get, character_other, ancillary_other, target_ancillary)

    end,
    true
    )
end

--------------------------------------------------------------
----------------------- 角色战斗完成 监听主函数 -------------------------
-------------------------------------------------------------- 
----------伊蕾娜检测蜘蛛池
local yln_zhizhu_test_pool = {
    "wh2_dlc16_wef_mon_spider_hatchlings_0",
    "wh_dlc06_grn_mon_spider_hatchlings_0",
    "wh2_dlc16_wef_mon_giant_spiders_0",
    "wh_dlc06_grn_cav_deff_creepers_0",
    "wh_main_grn_cav_forest_goblin_spider_riders_0",
    "wh_main_grn_cav_forest_goblin_spider_riders_1",
    "wh2_dlc15_grn_cav_forest_goblin_spider_riders_waaagh_0",
    "wh_dlc06_grn_mon_venom_queen_0",
    "wh2_dlc15_grn_mon_arachnarok_spider_waaagh_0",
    "wh3_dlc25_grn_mon_arachnarok_spider_boss",
    "wh_main_grn_mon_arachnarok_spider_0",
    "psw_dlc6_boss_zhumu",
    "psw_arachnarok_spider_wyc_hunted_ex",
    "psw_arachnarok_spider_wyc_hunted",
}

local boss_fac_name_pool = {
    wh3_dlc23_chd_chaos_dwarfs_qb2 = true,
    wh_main_chs_chaos_qb2 = true,
    wh_dlc05_wef_wood_elves_qb2 = true,
    wh_main_grn_greenskins_qb1 = true,
    wh3_dlc23_chd_chaos_dwarfs_qb1 = true,
    wh2_main_hef_high_elves_qb1 = true,
    wh3_main_ksl_kislev_qb1 = true,
    wh2_main_def_dark_elves_qb1 = true,
    wh_dlc03_bst_beastmen_qb2 = true,
    wh_main_chs_chaos_qb3 = true,
}

------四神瞩目效果
local sszm_effect_bundle = {
    "psw_dlc7_tfmw_sszm_kho",
    "psw_dlc7_tfmw_sszm_sla",
    "psw_dlc7_tfmw_sszm_nur",
    "psw_dlc7_tfmw_sszm_tze",
    "psw_dlc7_tfmw_sszm_chaos",
    "psw_dlc7_tfmw_wef_kuanglie_buff",
}

function delete_boss_limit()
    local faction_list = cm:model():world():faction_list();
    for k = 0, faction_list:num_items() - 1 do
        local current_faction_human = faction_list:item_at(k);
        if current_faction_human:is_human() then
            local crt_name = current_faction_human:name()
            cm:remove_effect_bundle("psw_main_boss_is_alive", crt_name);
        end
    end
end

function psw_main_CharacterBattleCompleted_listner()
    core:remove_listener("psw_main_CharacterBattleCompleted_listner")
    core:add_listener(
    "psw_main_CharacterBattleCompleted_listner",
    "CharacterCompletedBattle",
    function(context)
        return cm:pending_battle_cache_human_is_involved()
    end,
    function(context)
        
        local faction_name = cm:pending_battle_cache_get_attacker_faction_name(1)
        local faction = cm:get_faction(faction_name)
        
        local attacker_cqi, attacker_force_cqi, attacker_name = cm:pending_battle_cache_get_attacker(1);
        local defender_cqi, defender_force_cqi, defender_name = cm:pending_battle_cache_get_defender(1);
        
        local bmm_attacker_result = cm:model():pending_battle():attacker_battle_result();
        local bmm_defender_result = cm:model():pending_battle():defender_battle_result();
        
        local attacker = cm:get_faction(attacker_name)
        local defender = cm:get_faction(defender_name)
        
        if bmm_attacker_result == "close_defeat" and bmm_defender_result == "close_defeat" then
            -- They've both had a close defeat, must have been a retreat not a battle!
            return;
        elseif bmm_attacker_result == nil or bmm_defender_result == nil then
            return;
        end
        
        local atk_character = cm:get_character_by_cqi(attacker_cqi)
        local def_character = cm:get_character_by_cqi(defender_cqi)
        local unit_list = cm:pending_battle_cache_get_defender_units(1)
        
        local attacker_won = (bmm_attacker_result == "heroic_victory") or (bmm_attacker_result == "decisive_victory") or (bmm_attacker_result == "close_victory") or (bmm_attacker_result == "pyrrhic_victory")
        
        local defender_won = (bmm_defender_result == "heroic_victory") or (bmm_defender_result == "decisive_victory") or (bmm_defender_result == "close_victory") or (bmm_defender_result == "pyrrhic_victory")
        
        local lose_character = def_character
        local lose_faction = defender
        local lose_mf_cqi = defender_force_cqi
        local win_character = atk_character
        
        
        local human_is_win = true
        if attacker:is_human() and not defender:is_human() then
            faction = attacker
            faction_name = faction:name()
            if defender_won then
                human_is_win = false
                win_character = def_character
                lose_character = atk_character
                lose_faction = attacker
                lose_mf_cqi = attacker_force_cqi
            end
        elseif defender:is_human() and not attacker:is_human() then
            faction = defender
            faction_name = faction:name()
            if attacker_won then
                human_is_win = false
            else
                win_character = def_character
                lose_character = atk_character
                lose_faction = attacker
                lose_mf_cqi = attacker_force_cqi
            end
        elseif defender:is_human() and attacker:is_human() then
            human_is_win = false
            win_character = def_character
            lose_character = atk_character
            lose_faction = attacker
            lose_mf_cqi = attacker_force_cqi
        end
        local tfmw_is_start = psw_main_data.global_data.tfmw_is_start
        local mowang_faction_key = nil
        local mowang_faction
        if tfmw_is_start then
            mowang_faction_key = psw_mowang_data.mowang_faction_key
            mowang_faction = cm:get_faction(mowang_faction_key)
        end
        local lose_mf = cm:get_military_force_by_cqi(lose_mf_cqi)
        local lose_culture = lose_faction:culture()
        
        ---爱丽丝决斗
        if psw_main_data.global_data.psw_alice_game_start and not psw_main_data.global_data.psw_alice_game_is_end then
            local index_bundle = "psw_dlc6_qwsn_a_g_index"
            if attacker:is_human() and defender:is_human() then
                
                
                if atk_character:has_effect_bundle(index_bundle) and def_character:has_effect_bundle(index_bundle) then
                    local attacker_num = cm:pending_battle_cache_num_attackers()
                    local defender_num = cm:pending_battle_cache_num_defenders()
                    if attacker_num > 1 then
                        psw_dlc6_alice_juedou_win(defender_name)
                        psw_dlc6_alice_game_boduo_qwsm(attacker_name, defender_name)
                    elseif defender_num > 1 then
                        psw_dlc6_alice_juedou_win(attacker_name)
                        psw_dlc6_alice_game_boduo_qwsm(defender_name, attacker_name)
                    else
                        if attacker_won then
                            psw_dlc6_alice_juedou_win(attacker_name)
                            psw_dlc6_alice_game_boduo_qwsm(defender_name, attacker_name)
                        elseif defender_won then
                            psw_dlc6_alice_juedou_win(defender_name)
                            psw_dlc6_alice_game_boduo_qwsm(attacker_name, defender_name)
                        end
                    end
                    cm:callback(function()
                        cm:force_make_peace(attacker_name, defender_name)
                        cm:force_alliance(attacker_name, defender_name, true)
                        local mf_atk = cm:get_military_force_by_cqi(attacker_force_cqi)
                        local mf_def = cm:get_military_force_by_cqi(defender_force_cqi)
                        local tp_atk_cha = mf_atk:general_character()
                        local tp_def_cha = mf_def:general_character()
                        psw_dlc6_alice_juedou_tp_home(attacker_name, tp_atk_cha)
                        psw_dlc6_alice_juedou_tp_home(defender_name, tp_def_cha)
                        psw_main_heal_character_force(tp_atk_cha, 100)
                        psw_main_heal_character_force(tp_def_cha, 100)
                    end, 15)
                    cm:remove_effect_bundle_from_character(index_bundle, atk_character)
                    cm:remove_effect_bundle_from_character(index_bundle, def_character)
                end
            end
        end
        ---梗小姐
        if psw_faction_has_effect_bundle(attacker_name, "is_gxj_qyz") then
            if def_character:is_faction_leader() then
                psw_add_jiyizhi_gxj(attacker_name, 2)
            end
        elseif psw_faction_has_effect_bundle(defender_name, "is_gxj_qyz") then
            if atk_character:is_faction_leader() then
                psw_add_jiyizhi_gxj(defender_name, 2)
            end
        end
        
        ---Bshu 海德拉试炼
        if psw_faction_has_effect_bundle(attacker_name, "set_psw_tf_nor_bshu") and not psw_main_data.player_data[attacker_name].bshu_hdl_complete then
            local hdl_unit_list = cm:pending_battle_cache_get_defender_units(1)
            local hdl_sl = false
            if hdl_unit_list ~= nil then
                for i = 0, #hdl_unit_list do
                    local current_unit = hdl_unit_list[i]
                    if current_unit ~= nil then
                        local unit_key = current_unit.unit_key
                        if unit_key == "psw_boss_wh2_dlc10_def_mon_war_hydra_boss" then
                            hdl_sl = true
                            
                        end
                    end
                end
            end
            if hdl_sl then
                if not psw_main_data.player_data[attacker_name].bshu_hdl_complete then
                    psw_add_jishu_shenxing(attacker_name, 1)
                    local hdl_effect_list = {
                        {effect = "psw_dlc6_bshu_ssbt", effect_scope = "faction_to_character_own", effect_num = 1},
                    }
                    
                    psw_main_apply_effect_to_faction(attacker_name, "psw_dlc6_bshu_ssbt_effect", 0, hdl_effect_list)
                    psw_main_data.player_data[attacker_name].bshu_hdl_complete = true
                end
            end
        end
        
        ---圆环之理 战斗获得因果
        if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_ex_yhzl_1") and human_is_win and lose_character:has_effect_bundle("psw_mnh_effect") then
            if #unit_list >= 14 then
                local random_number_yhzl = cm:random_number(100, 1)
                if random_number_yhzl <= 33 then
                    psw_add_lmyx_yeli_jishu(faction_name, 1)
                    local music_list_yhzl = {
                        "yhzl_yinguo_1",
                        "yhzl_yinguo_2",
                        "yhzl_yinguo_3",
                        "yhzl_yinguo_4",
                    }
                    psw_play_random_music(music_list_yhzl)
                end
            end
        end
        
        ---灵魂宝石 污染度
        if psw_faction_has_effect_bundle(faction_name, "set_lhbs_player") and not psw_faction_has_effect_bundle(faction_name, "lhbs_monvhua") then
            local wrd_xishu = 2
            if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_lmyx_zt") then
                wrd_xishu = 2.5
            elseif faction:has_effect_bundle("set_psw_tf_nor_xmy_zt") then
                wrd_xishu = 4
            elseif faction:has_effect_bundle("set_psw_tf_nor_bmm_zt") then
                wrd_xishu = 3
            elseif faction:has_effect_bundle("set_psw_tf_nor_mssyx_zt") then
                wrd_xishu = 3
            end
            psw_add_lhbs_wurandu(faction_name, wrd_xishu, false, "jh_key")
            if human_is_win and lose_character:has_effect_bundle("psw_mnh_effect") then
                cm:remove_effect_bundle_from_character("psw_mnh_effect", lose_character)
                local ran_num_btzz = cm:random_number(100, 1)
                local btzz_drop_gl = 20
                if faction:has_effect_bundle("set_psw_tf_nor_bmm_zt") then
                    btzz_drop_gl = 100
                    local bmm_fc_leader_rank = faction:faction_leader():rank()
                    if bmm_fc_leader_rank > 25 then
                        bmm_fc_leader_rank = 25
                    end
                    cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_event_kkdqb", bmm_fc_leader_rank)
                end
                if faction:has_effect_bundle("set_psw_tf_nor_zcxz_zt") then
                    local ran_num_pg = cm:random_number(100, 1)
                    local zcxz_drop_gl = 50
                    if ran_num_pg <= zcxz_drop_gl then
                        cm:add_ancillary_to_faction(faction, "psw_dlc6_zcxz_pg", false)
                    end
                end
                if ran_num_btzz <= btzz_drop_gl then
                    cm:add_ancillary_to_faction(faction, "psw_dlc6_mfsnxy_btzz", false)
                end
            end
        end
        
        ---笼中鸟 死之诅咒
        if faction:has_effect_bundle("psw_dlc6_cstf_niao_si_effect") and human_is_win then
            psw_dlc6_cstf_niao_szzz(lose_character, lose_faction, faction_name)
        end
        
        ---星法 解除睡眠
        if faction:has_effect_bundle("psw_dlc6_cstf_niao_si_effect") then
            psw_dlc6_xingfa_shui_delete(faction_name)
        end
        
        ---流萤 万界之癌 获得地区
        if faction:has_effect_bundle("set_psw_tf_ex_firefly_2") and human_is_win then
            if win_character:has_region() and not win_character:is_at_sea() then
                local firefly_region = win_character:region()
                if firefly_region:has_effect_bundle("psw_firefly_wjza") then
                    local firefly_region_key = win_character:region():name()
                    psw_main_data.player_data[faction_name].firefly_num.wjza_region_key = firefly_region_key
                end
            end
        end
        
        
        
        ---BOSS击败判定
        if lose_mf:has_effect_bundle("psw_dlc7_boss_pd_bandle") and human_is_win and not psw_faction_has_effect_bundle(faction_name, "psw_dlc7_boss_pd_cd") then
            if lose_mf:has_effect_bundle("psw_dlc7_boss_pd_bandle_1") then
                psw_main_data.global_data.psw_boss_create_lhz = false
                psw_main_data.global_data.psw_boss_create_jwsq = false
                psw_main_data.global_data.psw_tfmw_is_tp_boss1 = false
            elseif lose_mf:has_effect_bundle("psw_dlc7_boss_pd_bandle_2") then
                psw_main_data.global_data.psw_boss_create_sznw = false
                psw_main_data.global_data.psw_boss_create_slzz = false
                psw_main_data.global_data.psw_tfmw_is_tp_boss2 = false
            elseif lose_mf:has_effect_bundle("psw_dlc7_boss_pd_bandle_3") then
                psw_main_data.global_data.psw_boss_create_lyzm = false
                psw_main_data.global_data.psw_boss_create_lyjl = false
                psw_main_data.global_data.psw_tfmw_is_tp_boss3 = false
            elseif lose_mf:has_effect_bundle("psw_dlc7_boss_pd_bandle_end") then
                psw_main_data.global_data.psw_tfmw_is_tp_boss_end = false
                psw_tfmw_win_check(mowang_faction_key)
            end
            
            psw_apply_non_effect_bundle_to_all_player_with_time("psw_dlc7_boss_pd_cd", 1)
            
            cm:callback(function()
                ---boss奖励
                psw_dlc7_boss_reward_apply()
            end, 2)
        end
        
        
        
        ---讨伐魔王
        if tfmw_is_start then
            if human_is_win then
                ---玩家任务
                for k = 1, #sszm_effect_bundle do
                    local remove_bundle = sszm_effect_bundle[k]
                    if lose_mf:has_effect_bundle(remove_bundle) then
                        psw_tfmw_dlc7_chaos_mission_1_check(lose_mf_cqi, remove_bundle, "tfmw_sszm_mf")
                        psw_dlc7_ams_mission_effect(faction_name, "psw_dlc7_ams_mulu_mission_def_qd")
                        if mowang_faction_key == "wh_dlc05_wef_wood_elves" then
                            psw_dlc7_tfmw_wef_csys_sucess_effect(mowang_faction_key)
                        end
                    end
                end
                if lose_mf:has_effect_bundle("psw_dlc7_tfmw_zako_bundle") then
                    psw_tfmw_dlc7_chaos_mission_1_check(lose_mf_cqi, remove_bundle, "tfmw_zako_mf")
                end
                ---击败奖励
                --木精灵击败
                if lose_faction == mowang_faction and mowang_faction_key == "wh_dlc05_wef_wood_elves" then
                    if #unit_list >= 14 then
                        local add_sdjc = -1
                        local renshu = psw_main_data.global_data.psw_main_renshu
                        if renshu == 3 then
                            add_sdjc = -1.5
                        elseif renshu == 2 then
                            add_sdjc = -2
                        elseif renshu == 1 then
                            add_sdjc = -4
                        end
                        psw_add_wef_sdjc_num(add_sdjc, mowang_faction_key)
                        --清除buff
                        psw_dlc7_tfmw_wef_delete_buff(faction_name)
                    end
                end
            end
        end
    end,
    true
    )
end


--------------------------------------------------------------
----------------------- 战斗阶段完成 监听主函数 -------------------------
-------------------------------------------------------------- 
local ast_mwsj_culture = {
    wh3_main_kho_khorne = true,
    wh3_main_nur_nurgle = true,
    wh3_main_sla_slaanesh = true,
    wh3_main_tze_tzeentch = true,
    wh3_main_dae_daemons = true,
    wh_main_vmp_vampire_counts = true,
    wh2_dlc11_cst_vampire_coast = true,
    wh2_dlc09_tmb_tomb_kings = true,
}

----------BOSS检测池
local boss_unit_pool = {
    "psw_boss_hexin_hef",
}
local boss_unit_pool_turn_1 = {
    "psw_boss_ex_lhz",
    "psw_war_mammoth_wyc_hunted_ex",
}
local boss_unit_pool_turn_2 = {
    "psw_arachnarok_spider_wyc_hunted_ex",
    "psw_boss_ex_slzz",
}
local boss_unit_pool_turn_3 = {
    "psw_phoenix_flamespyre_wyc_hunted_ex",
    "psw_boss_ex_lyjl",
}

local boss_unit_pool_turn_end = {
    "psw_boss_legend_yumu",
    "psw_boss_legend_emeng",
    "psw_boss_ex_lmys",
    "psw_dragon_ogre_shaggoth_wyc_hunted_ex",
    "psw_boss_ex_wupo",
}

---虫族派系池子
local wjza_chongzu_culture_pool = {
    wh_main_vmp_vampire_counts = true,
    wh_dlc08_nor_norsca = true,
    wh_main_chs_chaos = true,
    wh3_dlc23_chd_chaos_dwarfs = true,
    wh3_main_kho_khorne = true,
    wh3_main_nur_nurgle = true,
    wh3_main_sla_slaanesh = true,
    wh3_main_tze_tzeentch = true,
    wh3_main_dae_daemons = true,
    wh_dlc03_bst_beastmen = true,
    wh2_main_skv_skaven = true,
    wh2_dlc11_cst_vampire_coast = true,
}


function psw_main_BattleCompleted_listner()
    core:remove_listener("psw_main_BattleCompleted_listner")
    core:add_listener(
    "psw_main_BattleCompleted_listner",
    "BattleCompleted",
    function(context)
        return cm:pending_battle_cache_human_is_involved()
    end,
    function(context)
        
        local faction_name = cm:pending_battle_cache_get_attacker_faction_name(1)
        local faction = cm:get_faction(faction_name)
        local turn = cm:turn_number()
        
        local attacker_cqi, attacker_force_cqi, attacker_name = cm:pending_battle_cache_get_attacker(1);
        local defender_cqi, defender_force_cqi, defender_name = cm:pending_battle_cache_get_defender(1);
        
        local bmm_attacker_result = cm:model():pending_battle():attacker_battle_result();
        local bmm_defender_result = cm:model():pending_battle():defender_battle_result();
        
        local attacker = cm:get_faction(attacker_name)
        local defender = cm:get_faction(defender_name)
        
        if bmm_attacker_result == "close_defeat" and bmm_defender_result == "close_defeat" then
            -- They've both had a close defeat, must have been a retreat not a battle!
            return;
        elseif bmm_attacker_result == nil or bmm_defender_result == nil then
            return;
        end
        
        local lose_culture = defender:culture()
        
        local attacker_won = (bmm_attacker_result == "heroic_victory") or (bmm_attacker_result == "decisive_victory") or (bmm_attacker_result == "close_victory") or (bmm_attacker_result == "pyrrhic_victory")
        
        local defender_won = (bmm_defender_result == "heroic_victory") or (bmm_defender_result == "decisive_victory") or (bmm_defender_result == "close_victory") or (bmm_defender_result == "pyrrhic_victory")
        
        local human_is_win = true
        local atk_character = cm:get_character_by_cqi(attacker_cqi)
        local def_character = cm:get_character_by_cqi(defender_cqi)
        local lose_faction = defender
        local lose_character = def_character
        local win_character = atk_character
        local lose_mf_cqi = defender_force_cqi
        
        if attacker:is_human() and not defender:is_human() then
            faction = attacker
            faction_name = faction:name()
            if defender_won then
                human_is_win = false
                lose_culture = attacker:culture()
                lose_character = atk_character
                lose_faction = attacker
                win_character = def_character
                lose_mf_cqi = attacker_force_cqi
            else
                lose_culture = defender:culture()
            end
        elseif defender:is_human() and not attacker:is_human() then
            faction = defender
            faction_name = faction:name()
            if attacker_won then
                human_is_win = false
                lose_culture = defender:culture()
                
            else
                lose_culture = attacker:culture()
                lose_character = atk_character
                lose_faction = attacker
                win_character = def_character
                lose_mf_cqi = attacker_force_cqi
            end
        elseif defender:is_human() and attacker:is_human() then
            human_is_win = false
            if attacker_won then
                lose_culture = defender:culture()
            else
                lose_culture = attacker:culture()
                lose_character = atk_character
                lose_faction = attacker
                win_character = def_character
                lose_mf_cqi = attacker_force_cqi
            end
        end
        local unit_list = cm:pending_battle_cache_get_defender_units(1)
        local lose_faction_name = lose_faction:name()
        local faction_leader = faction:faction_leader()
        
        local psw_xingyun =  faction:pooled_resource_manager():resource("psw_xingyun"):value()
        local tfmw_is_start = psw_main_data.global_data.tfmw_is_start
        local mowang_faction_key = nil
        if tfmw_is_start then
            mowang_faction_key = psw_mowang_data.mowang_faction_key
        end
        
        
        ---诺艾尔的卵
        if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_chusheng") and not human_is_win then
            local random_number_chusheng = cm:random_number(100, 1)
            local luan_drop_gl = 55 + (psw_xingyun * 5)
            if random_number_chusheng <= luan_drop_gl then
                cm:add_ancillary_to_faction(faction, "psw_dlc6_chusheng_luan", false)
            end
        end
        
        ---灭杀魔王之圣剑
        if psw_faction_has_effect_bundle(attacker_name, "set_psw_tf_nor_aisite") and not psw_main_data.player_data[attacker_name].ast_sjjf_complete and human_is_win and ast_mwsj_culture[ lose_culture ] then
            
            if #unit_list >= 14 then
                psw_main_data.player_data[attacker_name].ast_mwsj_jishu = psw_main_data.player_data[attacker_name].ast_mwsj_jishu + 1
                local ast_mwsj_jishu = psw_main_data.player_data[attacker_name].ast_mwsj_jishu
                if ast_mwsj_jishu >= 20 then
                    psw_main_data.player_data[attacker_name].ast_sjjf_complete = true
                    psw_dlc6_ast_jmsj_juexing(attacker_name)
                end
            end
        end
        
        
        
        ---月光鸟 生灵眷羽 与 辉光逐月
        if faction:has_effect_bundle("psw_dlc6_cstf_niao_wydygn_have") and human_is_win then
            if #unit_list >= 14 then
                local ran_num_ygn = cm:random_number(100, 1)
                local music_list_ygn
                if ran_num_ygn <= 20 then
                    music_list_ygn = {
                        "ygn_sljy_1",
                        "ygn_sljy_2",
                    }
                    psw_play_random_music(music_list_ygn)
                    psw_dlc6_ygn_sljy_apply(faction_name, win_character, false)
                elseif ran_num_ygn <= 40 and ran_num_ygn > 20 then
                    psw_dlc6_ygn_hgzy_apply(faction_name, win_character, false)
                    music_list_ygn = {
                        "ygn_hgzy_1",
                        "ygn_hgzy_2",
                        "ygn_hgzy_3",
                    }
                    psw_play_random_music(music_list_ygn)
                end
            end
        end
        
        ---换生灵 万物冬藏
        if faction:has_effect_bundle("psw_dlc6_yiwu_ex_hsl_effect") then
            local battle_region = win_character:region()
            local climate = battle_region:settlement():get_climate()
            if climate == "climate_frozen" then
                local ran_num_hsl_wwdc = cm:random_number(100, 1)
                if ran_num_hsl_wwdc <= 50 then
                    psw_dlc6_yiwu_ex_hsl_wwdc(win_character)
                end
            end
        end
        
        ---水银灯 飘翎计数
        if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_ex_syd_1") and human_is_win then
            psw_dlc6_syd_piaoling_effect(faction_name, 1)
        end
        
        
        
        ---星之彩 沉梦
        if faction:has_effect_bundle("psw_dlc6_yiwu_ex_xzc_have") and human_is_win then
            local ran_num_xzc_cm = cm:random_number(100, 1)
            if ran_num_xzc_cm <= 25 then
                psw_yiwu_xzc_hh(faction_name, win_character, 1)
            end
            local music_list_xzc = {
                "xzc_scts_1",
                "xzc_scts_2",
                "xzc_scts_3",
            }
            psw_play_random_music(music_list_xzc)
        end
        
        
        ---伊蕾娜 再抓五只壁虎！
        if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_ex_yln_2") and human_is_win then
            if lose_culture == "wh2_main_lzd_lizardmen" then
                local ran_num_yln_bh = cm:random_number(100, 1)
                if ran_num_yln_bh <= 50 then
                    cm:add_ancillary_to_faction(faction, "psw_dlc6_yln_bhw", false)
                    psw_yln_jishu_bihu(faction_name, 1)
                end
            end
        end
        
        ---伊蕾娜 星尘魔女测试 检测胜利失败
        if psw_faction_has_effect_bundle(faction_name, "yln_xcmn_start") and not psw_faction_has_effect_bundle(faction_name, "yln_xcmn_complete") then
            if attacker_name == "wh2_main_hef_high_elves_qb2" then
                if human_is_win then
                    psw_dlc6_mnrj_winmonv(faction_name)
                else
                    psw_dlc6_mnrj_losemonv(faction_name)
                end
                cm:cancel_custom_mission(faction_name, "psw_dlc6_yln_xcmn_mission")
            end
        end
        
        ---发育遗物
        if human_is_win and (win_character:has_ancillary("psw_moyin_fayu_1") or win_character:has_ancillary("psw_moyin_fayu_2") or win_character:has_ancillary("psw_moyin_fayu_3") or win_character:has_ancillary("psw_moyin_fayu_4") or win_character:has_ancillary("psw_moyin_fayu_5") or win_character:has_ancillary("psw_moyin_fayu_5_plus")) then
            local fayu_yiwu_sj = 5
            if win_character:has_ancillary("psw_moyin_fayu_1") then
                fayu_yiwu_sj = 1
            elseif win_character:has_ancillary("psw_moyin_fayu_2") then
                fayu_yiwu_sj = 2
            elseif win_character:has_ancillary("psw_moyin_fayu_3") then
                fayu_yiwu_sj = 3
            elseif win_character:has_ancillary("psw_moyin_fayu_4") then
                fayu_yiwu_sj = 4
            end
            cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_get_fayu", fayu_yiwu_sj)
        end
        ---伊蕾娜 赶走浴室蜘蛛！
        if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_yln_2") and not faction:has_effect_bundle("psw_tf_sp_mnrj_zhizhu_have") and human_is_win then
            if cm:pending_battle_cache_faction_won_battle_against_unit(faction_name, yln_zhizhu_test_pool) then
                
                psw_yln_jishu_zhizhu(faction_name, 1)
            end
        end
        
        ---超天酱 获得粉丝
        if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_ctj") and human_is_win then
            local ctj_fensi_gailv = cm:random_number(100, 1)
            if ctj_fensi_gailv <= 20 then
                psw_dlc7_ctj_fensi_add(faction_name, lose_faction_name, true)
            end
        end
        
        ---早苗 战斗获得信仰
        if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_miao_1") and human_is_win then
            psw_dlc7_miao_battle_get_xy(faction_name)
        end
        
        ---塔什干 获得好感度
        if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_tsg_1") and human_is_win then
            local tsg_num = 2
            if attacker_won then
                if bmm_attacker_result == "heroic_victory" then
                    tsg_num = tsg_num + 5
                elseif bmm_attacker_result == "decisive_victory" then
                    tsg_num = tsg_num + 2
                elseif bmm_attacker_result == "close_victory" then
                    tsg_num = tsg_num + 1
                end
            else
                if bmm_defender_result == "heroic_victory" then
                    tsg_num = tsg_num + 5
                elseif bmm_defender_result == "decisive_victory" then
                    tsg_num = tsg_num + 2
                elseif bmm_defender_result == "close_victory" then
                    tsg_num = tsg_num + 1
                end
            end
            psw_add_tsg_hgd(faction_name, tsg_num)
        end
        
        ---流萤 战斗获得萤火值
        if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_firefly_2") and human_is_win and wjza_chongzu_culture_pool[ lose_culture ] then
            
            if #unit_list >= 14 then
                local ran_num_firefly = cm:random_number(10, 1)
                if ran_num_firefly <= 1 then
                    psw_firefly_add_yinghuo_num(faction_name, 1)
                end
            end
        end
        
        
        
        ---基沃托斯 战斗失败获得色彩值
        if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_jwts_2") and not human_is_win then
            if not faction:has_effect_bundle("set_psw_tf_ex_jwts_3") then
                psw_dlc7_jwts_color_turn_get(faction_name)
            end
        end
        
        ---可可萝 战斗获得光蝶
        if faction:has_effect_bundle("set_psw_tf_sp_kokoro") and human_is_win then
            if #unit_list >= 14 then
                local kokora_ran_num = cm:random_number(100, 1)
                local xz_num = 35
                if faction:has_effect_bundle("psw_tf_ex_ams_1") then
                    xz_num = 70
                end
                if kokora_ran_num <= xz_num then
                    psw_dlc7_kokora_add_die_num(faction_name, 1)
                end
            end
        end
        
        ---爱梅斯 战斗效果
        if faction:has_effect_bundle("set_psw_tf_ex_ams_1") and human_is_win then
            if #unit_list >= 14 then
                psw_dlc7_ams_battle_get_mishi(faction_name)
                psw_dlc7_ams_mission_effect(faction_name, "psw_dlc7_ams_mulu_mission_defeat")
                if win_character == faction_leader then
                    psw_dlc7_ams_mission_effect(faction_name, "psw_dlc7_ams_mulu_mission_levelup")
                end
                if tfmw_is_start then
                    if lose_faction:name() == mowang_faction_key or lose_faction:is_vassal_of(cm:get_faction(mowang_faction_key)) == true then
                        psw_dlc7_ams_mission_effect(faction_name, "psw_dlc7_ams_mulu_mission_def_mow")
                    end
                end
            end
        end
        
        ---珂莱塔 战斗效果
        if faction:has_effect_bundle("set_psw_tf_ex_klt_1") and human_is_win then
            if #unit_list >= 14 then
                psw_dlc7_klt_get_ksjz_by_battle(faction_name)
            end
        end
        
        ---维里奈 战斗效果
        if faction:has_effect_bundle("set_psw_tf_nor_weilinai") and human_is_win then
            psw_dlc7_wln_battle_ghnl(faction_name)
        end
        
        ---椿 战斗效果
        if faction:has_effect_bundle("set_psw_tf_nor_chun") and human_is_win then
            psw_dlc7_chun_battle_hcr(faction_name)
        end
        
        ---鸣潮 战斗效果
        if faction:has_effect_bundle("psw_dlc7_mc_qd") and human_is_win then
            psw_dlc7_mc_get_xznl_by_battle(faction_name)
        end
        
        ---雪风 获得好感度
        if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_xuefeng_1") and human_is_win then
            local xuefeng_num = 2
            if attacker_won then
                if bmm_attacker_result == "heroic_victory" then
                    xuefeng_num = xuefeng_num + 5
                elseif bmm_attacker_result == "decisive_victory" then
                    xuefeng_num = xuefeng_num + 2
                elseif bmm_attacker_result == "close_victory" then
                    xuefeng_num = xuefeng_num + 1
                end
            else
                if bmm_defender_result == "heroic_victory" then
                    xuefeng_num = xuefeng_num + 5
                elseif bmm_defender_result == "decisive_victory" then
                    xuefeng_num = xuefeng_num + 2
                elseif bmm_defender_result == "close_victory" then
                    xuefeng_num = xuefeng_num + 1
                end
            end
            psw_dlc7_xuefeng_add_hgd(faction_name, xuefeng_num)
        end
        
        
        ---提丰 提丰证章
        if faction:has_effect_bundle("set_psw_tf_sp_tifeng") and human_is_win then
            local tf_add_num = 0
            if #unit_list >= 7 then
                tf_add_num = 1
            elseif #unit_list >=14 and #unit_list < 7 then
                tf_add_num = 2
            elseif #unit_list >= 20 then
                tf_add_num = 3
            end
            if tf_add_num > 0 then
                psw_dlc7_tifeng_battle_get_zz(faction_name, lose_culture, tf_add_num)
            end
        end
        
        
        ---莉莉卡
        if faction:has_effect_bundle("set_psw_tf_ex_lilika_1") and human_is_win then
            if cm:pending_battle_cache_faction_won_battle_against_unit(faction_name, "psw_dlc7_lilika_bmt") then
                psw_dlc7_lilika_battle_effect(faction_name)
            end
        end
        
        ---事件战斗效果
        if human_is_win then
            psw_dlc7_event_battle_effect(faction_name)
            ---战斗获得水晶
            local add_qysj = math.floor(#unit_list/2)
            psw_main_battle_effect(faction_name, add_qysj)
        end
        
        ---
        
        
    end,
    true
    )
end


























function psw_main_turn_effect(faction_name, turn)
    local faction = cm:get_faction(faction_name)
    local main_faction_name = psw_main_data.global_data.psw_main_boss_create_faction or nil
    local psw_main_character = psw_get_main_character(faction_name)
    local mowang_faction_key = nil
    local psw_moli = faction:pooled_resource_manager():resource("psw_moli"):value()
    local tfmw_is_start = psw_main_data.global_data.tfmw_is_start
    
    if tfmw_is_start then
        mowang_faction_key = psw_mowang_data.mowang_faction_key
        psw_dlc7_tfmw_wef_jcgx_buff_apply(faction_name, mowang_faction_key)
    end
    if not psw_main_data.global_data.set_mowang_progress_hh and tfmw_is_start then
        psw_main_mowang_progress_change_effect(1)
        psw_main_data.global_data.set_mowang_progress_hh = true
    end
    
    
    
    ---BUFF栏变化
    psw_main_data.player_data[faction_name].tfmw_buff["psw_dlc7_buff_mlyd"].num = 0
    psw_main_data.player_data[faction_name].tfmw_buff["psw_dlc7_buff_mlyd"].num = psw_main_data.player_data[faction_name].tfmw_buff["psw_dlc7_buff_mlyd"].num + psw_moli
    
    local shouhu_num = psw_main_data.player_data[faction_name].tfmw_buff["psw_dlc7_buff_jiangu"].num
    local jiangu_add_num = math.floor(shouhu_num/2)
    psw_buff_add_jiangu_num(faction_name, -jiangu_add_num)
    local zhiyu_num = psw_main_data.player_data[faction_name].tfmw_buff["psw_dlc7_buff_zhiyu"].num
    local add_zhiyu_num = math.floor(zhiyu_num/2)
    ---治愈效果
    psw_buff_add_zhiyu_num(faction_name, -add_zhiyu_num)
    zhiyu_num = psw_main_data.player_data[faction_name].tfmw_buff["psw_dlc7_buff_zhiyu"].num
    psw_tfmw_main_hp_effect(zhiyu_num, faction_name, "heal")
    
    
    ---每回合记忆结晶奖励
    if psw_main_data.player_data[faction_name].turn_jyjj_reward > 0 then
        local turn_jyjj_reward = psw_main_data.player_data[faction_name].turn_jyjj_reward
        for k = 1, turn_jyjj_reward do
            psw_jyjj_main_pickup(faction_name, "default")
        end
    end
    
    ---每回合祈愿水晶奖励
    local qysj_turn_num = psw_main_data.player_data[faction_name].qysj_turn_num
    if qysj_turn_num > 0 then
        cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_huihe_get_good", qysj_turn_num)
    end
    
    ---事件开始效果
    psw_dlc7_main_event_turn_effect(faction_name)
    if turn % 3 == 0 and psw_main_data.global_data.set_psw_main_nandu3 then
        psw_dlc7_main_event_effect(faction_name)
    end
    
    psw_main_data.player_data[faction_name].player_tili_crt = psw_main_data.player_data[faction_name].player_tili_sx
    psw_main_data.player_data[faction_name].card_use_num_crt = psw_main_data.player_data[faction_name].card_use_num_sx
    
    ---每回合boss限伤清0
    psw_mowang_data.turn_hard_num = 0
    ---每回合战斗水晶清0
    psw_main_data.player_data[faction_name].battle_qysj_num = 0
    
    ---种族补正
    psw_zhongzu_buzheng_effect(faction_name, turn)
    
    ---爱丽丝游戏结束/爱丽丝决斗输赢
    if psw_main_data.global_data.psw_alice_game_start and not psw_main_data.global_data.psw_alice_game_is_end and psw_faction_has_effect_bundle(faction_name, "alice_game_player") then
        local a_g_end_turn = psw_main_data.global_data.psw_alice_game_start_turn
        local juedou_xianzhi_turn = psw_main_data.player_data[faction_name].a_g_xz_turn or 200
        local juedou_js_xianzhi_turn = psw_main_data.player_data[faction_name].alice_game_battler_turn or 200
        juedou_js_xianzhi_turn = juedou_js_xianzhi_turn + 3
        juedou_xianzhi_turn = juedou_xianzhi_turn + 1
        a_g_end_turn = a_g_end_turn + 10
        if turn == a_g_end_turn then
            psw_dlc6_alice_game_the_end()
        elseif turn == juedou_xianzhi_turn then
            psw_dlc6_alice_juedou_deadtime(faction_name)
        elseif turn == juedou_js_xianzhi_turn then
            psw_dlc6_alice_juedou_deadtime(faction_name)
        end
    end
    
    ---爱丽丝游戏 权重
    if psw_main_data.global_data.psw_alice_game_start and not psw_main_data.global_data.psw_alice_game_is_end and psw_faction_has_effect_bundle(faction_name, "alice_game_player") then
        local a_g_province_crt = cm:num_provinces_controlled_by_faction(faction)
        local a_g_faction_rank_crt = cm:model():world():faction_strength_rank(faction)
        local a_g_province_start = psw_main_data.player_data[faction_name].a_g_province_start or 0 
        local a_g_faction_rank_start = psw_main_data.player_data[faction_name].a_g_faction_rank_start or 273
        
        local a_g_province_qz_has_add = psw_main_data.player_data[faction_name].a_g_province_qz_has_add 
        local a_g_rank_qz_has_add = psw_main_data.player_data[faction_name].a_g_rank_qz_has_add 
        local a_g_province_qz = psw_main_data.player_data[faction_name].a_g_province_qz
        local a_g_rank_qz = psw_main_data.player_data[faction_name].a_g_rank_qz
        
        local a_g_province_qz_to_add = math.floor(a_g_province_crt/2)
        a_g_province_qz_to_add = a_g_province_qz_to_add - a_g_province_qz_has_add
        psw_main_data.player_data[faction_name].a_g_province_qz_has_add = psw_main_data.player_data[faction_name].a_g_province_qz_has_add + a_g_province_qz_to_add
        psw_main_data.player_data[faction_name].a_g_province_qz = psw_main_data.player_data[faction_name].a_g_province_qz + a_g_province_qz_to_add
        
        local a_g_rank_qz_to_add = 0
        local up_rank
        if a_g_faction_rank_crt < a_g_faction_rank_start then
            if a_g_faction_rank_start >= 100 then
                
                if a_g_faction_rank_crt >= 100 then
                    up_rank = a_g_faction_rank_start - a_g_faction_rank_crt
                    a_g_rank_qz_to_add = a_g_rank_qz_to_add + math.floor(up_rank/50)
                elseif a_g_faction_rank_crt >= 40 and a_g_faction_rank_crt < 100 then
                    up_rank = a_g_faction_rank_start - 100
                    a_g_rank_qz_to_add = a_g_rank_qz_to_add + math.floor(up_rank/50)
                    up_rank = 100 - a_g_faction_rank_crt
                    a_g_rank_qz_to_add = a_g_rank_qz_to_add + math.floor(up_rank/20)
                elseif a_g_faction_rank_crt < 40 then
                    up_rank = a_g_faction_rank_start - 100
                    a_g_rank_qz_to_add = a_g_rank_qz_to_add + math.floor(up_rank/50)
                    up_rank = 100 - 40
                    a_g_rank_qz_to_add = a_g_rank_qz_to_add + math.floor(up_rank/20)
                    up_rank = 40 - a_g_faction_rank_crt
                    a_g_rank_qz_to_add = a_g_rank_qz_to_add + math.floor(up_rank/10)
                end
                
            elseif a_g_faction_rank_start >= 40 and a_g_faction_rank_start < 100 then
                if a_g_faction_rank_crt >= 40 and a_g_faction_rank_crt < 100 then
                    up_rank = a_g_faction_rank_start - a_g_faction_rank_crt
                    a_g_rank_qz_to_add = a_g_rank_qz_to_add + math.floor(up_rank/20)
                elseif a_g_faction_rank_crt < 40 then
                    up_rank = a_g_faction_rank_start - 40
                    a_g_rank_qz_to_add = a_g_rank_qz_to_add + math.floor(up_rank/20)
                    up_rank = 40 - a_g_faction_rank_crt
                    a_g_rank_qz_to_add = a_g_rank_qz_to_add + math.floor(up_rank/10)
                end
            elseif a_g_faction_rank_start < 40 then
                up_rank = a_g_faction_rank_start - a_g_faction_rank_crt
                a_g_rank_qz_to_add = a_g_rank_qz_to_add + math.floor(up_rank/10)
            end
        end
        a_g_rank_qz_to_add = a_g_rank_qz_to_add - a_g_rank_qz_has_add
        psw_main_data.player_data[faction_name].a_g_rank_qz_has_add = psw_main_data.player_data[faction_name].a_g_rank_qz_has_add + a_g_rank_qz_to_add
        psw_main_data.player_data[faction_name].a_g_rank_qz = psw_main_data.player_data[faction_name].a_g_rank_qz + a_g_rank_qz_to_add
        
    end
    
    ---雏莓效果
    if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_chumei") then
        local chumei_turn = turn
        if chumei_turn > 15 then
            chumei_turn = 15
        end
        cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_huihe_get_good", chumei_turn)
    end
    
    
    ---救赎沙优
    if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_shayou_1") and psw_is_character_interface(psw_main_character) then
        local shayou_get_turn = psw_main_data.player_data[faction_name].shayou_get_turn or 0
        shayou_get_turn = shayou_get_turn + 15
        if turn == shayou_get_turn then
            if not psw_main_character:has_effect_bundle("dtnl_effect_psw_tf_nor_shayou_1") then
                psw_dlc6_shayou_up_jiushu(psw_main_character, faction_name)
            end
        end
        if not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_shayou_2") then
            cm:treasury_mod(faction_name, -800)
        end
    end
    
    ---蒂亚 可能性之卵
    if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_diya") and not faction:has_effect_bundle("psw_dlc6_diya_knxzl") then
        local diya_turn = psw_main_data.player_data[faction_name].diya_get_turn or 0
        diya_turn = diya_turn + 5
        if turn == diya_turn then
            psw_dlc6_diya_knxzl_effect_apply(faction_name)
        end
    end
    
    
    
    
    ---塞西莉亚 两人的羁绊
    if faction:has_effect_bundle("psw_dlc6_sxly_lrdjb") then
        psw_dlc6_sxly_lrdjb(faction_name)
    end
    
    ---梗小姐
    if psw_faction_has_effect_bundle(faction_name, "is_gxj_qyz") then
        local random_number_gxj = cm:random_number(100, 1)
        if random_number_gxj <= 33 then
            psw_add_jiyizhi_gxj(faction_name, 1)
        end
    end
    
    ---梗小姐效果删除
    if not faction:has_effect_bundle("dtnl_cd_psw_tf_nor_gengxj") then
        cm:remove_effect_bundle("dtnl_effect_psw_tf_nor_gengxj", faction_name)
        cm:remove_effect_bundle("dtnl_effect_psw_tf_nor_gengxj_emdbf", faction_name)
        cm:remove_effect_bundle("dtnl_effect_psw_tf_nor_gengxj_emddr", faction_name)
    end
    
    ---拉媞珐
    if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_latifa") and turn >= 15 and faction:has_effect_bundle("psw_dlc6_latifa_cd") then
        cm:remove_effect_bundle_from_character("psw_dlc6_bundle_latifa", psw_main_character)
        cm:remove_effect_bundle("psw_dlc6_latifa_cd", faction_name)
        psw_add_ex_limit_jiefang(faction_name)
        advice_dlc6_latifa_1()
    end
    
    ---Bshu 试炼 三头犬
    if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_bshu") and not psw_faction_has_effect_bundle(faction_name, "bshu_stq_complete") then
        local stq_faction = cm:get_faction("wh3_main_kho_exiles_of_khorne")
        if not cm:faction_is_alive(stq_faction) then
            psw_add_jishu_miansi(faction_name, 1)
            psw_aplly_costom_effect_bundle_hidden_fn("bshu_stq_complete", faction_name)
        end
    end
    
    ---小鸠
    if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_xiaojiu") then
        psw_dlc6_xiaojiu_effect_apply(faction_name)
    end
    
    ---南小鸟
    if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_xiaoniao") then
        cm:add_ancillary_to_faction(faction, "psw_dlc6_nxn_xndyz", false)
    end
    
    ---艾斯特
    if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_aisite") and not psw_main_data.player_data[faction_name].ast_sjjf_complete then
        psw_main_cost_faction_to_force_all(faction_name, 8)
    end
    
    ---英雄王
    if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_shanshan") and not psw_main_data.player_data[faction_name].ast_sjjf_complete then
        cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_huihe_get_good", 15)
        psw_main_apply_random_ancillary(faction_name)
        psw_main_apply_random_ancillary(faction_name)
    end
    
    ---与小圆纺织的因果
    if (psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_lmyx_zt") or faction:has_effect_bundle("set_psw_tf_ex_yhzl_1")) and psw_main_data.global_data.set_main_psw_tf_nor_xmy_zt then
        local fzdyg_jishu = psw_main_data.player_data[faction_name].fzdyg_jishu
        if fzdyg_jishu < 10 then
            psw_main_data.player_data[faction_name].fzdyg_jishu = psw_main_data.player_data[faction_name].fzdyg_jishu + 1
            psw_add_lmyx_yinguo_jishu(faction_name, 1)
        end
    end
    
    ---QB AI魔女化
    if faction:has_effect_bundle("set_psw_tf_sp_qb_tf") then
        psw_dlc6_mnh_apply_to_all_faction()
        local qb_mnh_jdjishu = psw_main_data.player_data[faction_name].qb_mnh_jdjishu or 0
        local qb_add_num = math.floor(qb_mnh_jdjishu/5)
        if qb_add_num > 25 then
            qb_add_num = 25
        end
        cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_huihe_get_good", qb_add_num)
    end
    
    ---美树沙耶香 痛觉的止符 爆发
    if faction:has_effect_bundle("set_psw_tf_nor_mssyx_zt") and not psw_faction_has_effect_bundle(faction_name, "lhbs_monvhua") then
        local mssyx_bundle_key = {
            "psw_dlc6_mssyx_tkdzf_1",
            "psw_dlc6_mssyx_tkdzf_2",
            "psw_dlc6_mssyx_tkdzf_3",
            "psw_dlc6_mssyx_tkdzf_4",
        }
        for i = 1, #mssyx_bundle_key do
            local get_turn = psw_main_data.player_data[faction_name].mssyx_tkdzf_turn1
            if i == 2 then
                get_turn = psw_main_data.player_data[faction_name].mssyx_tkdzf_turn2
            elseif i == 3 then
                get_turn = psw_main_data.player_data[faction_name].mssyx_tkdzf_turn3
            elseif i == 4 then
                get_turn = psw_main_data.player_data[faction_name].mssyx_tkdzf_turn4
            end
            if get_turn ~= 0 then
                local dead_time = get_turn + 5
                if turn == dead_time then
                    local bundle_key = mssyx_bundle_key[i]
                    if faction:has_effect_bundle(bundle_key) then
                        cm:remove_effect_bundle(bundle_key, faction_name)
                        psw_add_lhbs_wurandu(faction_name, 20, false, "jh_key")
                    end
                end
            end
        end
    end
    
    ---圆环之理 消除魔女化
    if faction:has_effect_bundle("set_psw_tf_ex_yhzl_3") then
        psw_dlc6_yhzl_every_turn_mnh()
    end
    
    ---符玄 大吉 幸运消失
    if faction:has_effect_bundle("psw_dlc6_cstf_fuxuan_ybjx_daji_have") then
        local fuxuan_daji_turn = psw_main_data.player_data[faction_name].fuxuan_daji_turn or 0
        if fuxuan_daji_turn ~= 0 and turn == (fuxuan_daji_turn + 3) then
            cm:remove_effect_bundle("psw_dlc6_cstf_fuxuan_ybjx_daji_have", faction_name)
            psw_add_jishu_xingyun(faction_name, -3)
        end
    ---符玄 小吉 输送金币
    elseif faction:has_effect_bundle("psw_dlc6_cstf_fuxuan_ybjx_xiaojiji_have") then
        local fuxuan_xiaoji_turn = psw_main_data.player_data[faction_name].fuxuan_xiaoji_turn or 0
        if fuxuan_xiaoji_turn ~= 0 then
            if turn < (fuxuan_xiaoji_turn + 3) then
                psw_dlc6_cstf_fuxuan_xiaoji_effect(faction_name, turn)
            elseif turn == (fuxuan_xiaoji_turn + 3) then
                cm:remove_effect_bundle("psw_dlc6_cstf_fuxuan_ybjx_xiaojiji_have", faction_name)
            end
        end
    ---符玄 大凶 恢复幸运
    elseif faction:has_effect_bundle("psw_dlc6_cstf_fuxuan_ybjx_daxiong_have") then
        local fuxuan_daxiong_turn = psw_main_data.player_data[faction_name].fuxuan_daxiong_turn or 0
        if fuxuan_daxiong_turn ~= 0 and turn == (fuxuan_daxiong_turn + 1) then
            cm:remove_effect_bundle("psw_dlc6_cstf_fuxuan_ybjx_daxiong_have", faction_name)
            local dx_xy = psw_main_data.player_data[faction_name].fuxuan_daxiong_xy or 0
            psw_add_jishu_xingyun(faction_name, dx_xy)
        end
    end
    
    ---笼中鸟 生命祝福与死之叹息
    if faction:has_effect_bundle("hero_select_niao") then
        local ran_num_nzl = cm:random_number(100, 1)
        if ran_num_nzl >= 33 then
            local lzn_anc_pool = {
                "psw_cook_niao_smzf",
                "psw_cook_niao_sztx",
            }
            local lzn_index = cm:random_number(#lzn_anc_pool)
            local lzn_recipi = lzn_anc_pool[lzn_index]
            cm:force_cook_recipe(faction, lzn_recipi, false, false)
        end
    end
    
    
    ---三株树
    if faction:has_effect_bundle("psw_dlc6_yiwu_ex_szs_have") then
        local ran_num_szs = cm:random_number(3, 1)
        for i = 1, ran_num_szs do
            cm:force_cook_recipe(faction, "psw_cook_xzc_hdfw", false, false)
        end
        psw_dlc6_yiwu_ex_szs_jsyz(faction_name)
    end
    
    ---星之彩
    if faction:has_effect_bundle("psw_dlc6_yiwu_ex_xzc_have") then
        if psw_is_character_interface(psw_main_character) then
            local ran_num_xzc = cm:random_number(3, 1)
            local recipe
            if psw_main_character:has_effect_bundle("psw_yiwu_ex_xzc_red") then
                recipe = "psw_cook_xzc_jzqs"
            elseif psw_main_character:has_effect_bundle("psw_yiwu_ex_xzc_yellow") then
                recipe = "psw_cook_xzc_qxdns"
            elseif psw_main_character:has_effect_bundle("psw_yiwu_ex_xzc_blue") then
                recipe = "psw_cook_xzc_crjm"
            elseif psw_main_character:has_effect_bundle("psw_yiwu_ex_xzc_yslz") then
                recipe = "psw_cook_xzc_skdhh"
                if ran_num_xzc == 1 then
                    ran_num_xzc = 0
                elseif ran_num_xzc > 1 then
                    ran_num_xzc = 1
                end
            end
            if ran_num_xzc > 0 then
                for i = 1, ran_num_xzc do
                    cm:force_cook_recipe(faction, recipe, false, false)
                end
            end
        end
    end
    
    ---每回合模因赋予
    if main_faction_name ~= nil then
        if faction_name == main_faction_name then
            psw_moyin_main_apply_every_turn()
        end
    end
    
    
    ---符玄 未适应的法眼
    if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_ex_fuxuan_1") and not psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_ex_fuxuan_2") then
        psw_main_cost_faction_to_force_all(faction_name, 8)
    end
    
    ---符玄 丰饶的祝福
    if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_ex_fuxuan_2") then
        psw_dlc6_fuxuan_frdzf_apply_to_faction(faction_name)
    end
    
    
    ---暗影庭院 洁塔 获取视野
    if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_jieta") then
        psw_dlc6_anty_jieta_effect(faction_name)
    end
    
    
    ---帕秋莉 不动的大图书馆/水 治愈力恢复
    if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_ex_pql") then
        if turn % 3 == 0 then
            psw_dlc6_pql_bdd_tsg(faction_name)
        end
        if faction:has_effect_bundle("psw_dlc6_pql_qyyszs_effect_shui_have_use") then
            if not faction:has_effect_bundle("psw_dlc6_pql_qyyszs_effect_shui_cd") then
                local delete_num = psw_main_data.player_data[faction_name].pql_shui_zhiyu_add or 0
                psw_add_jishu_zhiyu(faction_name, delete_num)
                cm:remove_effect_bundle("psw_dlc6_pql_qyyszs_effect_shui_have_use", faction_name)
            end
        end
    end
    
    ---琪亚娜 律者侵蚀
    if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_ex_qiyana_1") and not psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_ex_qiyana_2") then
        psw_dlc6_qiyana_juexing(faction_name)
    end
    
    ---星法 幸运魔力 效果恢复
    if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_ex_xingfa_2") and faction:has_effect_bundle("psw_dlc6_xingfa_ewnl_xyml_have_use") and not faction:has_effect_bundle("psw_dlc6_xingfa_xyml_cd") then
        
        if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_sp_zqxy") then
            xingfa_ex_effect_apply(psw_main_character)
        else
            xingfa_nor_effect_apply(psw_main_character)
        end
        cm:remove_effect_bundle("psw_dlc6_xingfa_ewnl_xyml_have_use", faction_name);
    end
    
    ---伊蕾娜 
    if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_ex_yln_2") then
        ---每回合获得止痛药
        if faction:has_effect_bundle("psw_tf_sp_mnrj_zhitongyao") then
            cm:add_ancillary_to_faction(faction, "psw_dlc6_yln_zty", false)
        end
        ---星尘魔女测试发布
        if psw_faction_has_effect_bundle(faction_name, "yln_wsss_complete") then
            local yln_wsss_complete_turn = psw_main_data.player_data[faction_name].yln_wsss_complete_turn or 0
            if turn == (yln_wsss_complete_turn + 1) then
                cm:callback(function()
                    psw_dlc6_yln_xcmn_mission_start(faction_name)
                end, 0.5)
            end
        end
        ---魔力充能
        if faction:has_effect_bundle("yln_arrived_wh3_main_combi_region_white_tower_of_hoeth") then
            local count_moli = psw_main_data.player_data[faction_name].count_moli
            local add_num = count_moli + 2
            psw_add_yln_mlcn(faction_name, add_num)
        end
    end
    
    ---终末计数
    if turn <= 35 then
        local zhongmo_xishu = 8
        if psw_main_data.global_data.set_psw_main_nandu4 then
            zhongmo_xishu = 5
        end
        if turn % zhongmo_xishu == 0 and not psw_main_data.global_data.set_zmjs_hh and not psw_main_data.global_data.set_psw_main_nandu1 then
            psw_add_jishu_zhongmo(1)
            psw_main_data.global_data.set_zmjs_hh = true
        end
    end
    
    ---二阶堂真红觉醒
    if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_btmmfs_1") and not faction:has_effect_bundle("set_psw_tf_ex_btmmfs_2") and not psw_faction_has_effect_bundle(faction_name, "set_btmmfs_yixiaoshi") then
        local ejtzh_jiyizhi = psw_main_data.player_data[faction_name].ejtzh_jiyizhi
        local ejtzh_get_turn = psw_main_data.player_data[faction_name].ejtzh_get_turn or 200
        local ejtzh_jx_turn = ejtzh_get_turn + 12
        if ejtzh_jiyizhi > 0 and ejtzh_jiyizhi <= 10 then
            ejtzh_jx_turn = ejtzh_jx_turn + 6
        elseif ejtzh_jiyizhi > 10 and ejtzh_jiyizhi <= 25 then
            ejtzh_jx_turn = ejtzh_jx_turn + 5
        elseif ejtzh_jiyizhi > 25 and ejtzh_jiyizhi <= 40 then
            ejtzh_jx_turn = ejtzh_jx_turn + 4
        elseif ejtzh_jiyizhi > 40 and ejtzh_jiyizhi <= 55 then
            ejtzh_jx_turn = ejtzh_jx_turn + 3
        elseif ejtzh_jiyizhi > 55 and ejtzh_jiyizhi <= 70 then
            ejtzh_jx_turn = ejtzh_jx_turn + 2
        elseif ejtzh_jiyizhi > 70 and ejtzh_jiyizhi <= 85 then
            ejtzh_jx_turn = ejtzh_jx_turn + 1
        end
        
        local ejtzh_crt_turn = cm:turn_number()
        if ejtzh_crt_turn >= ejtzh_jx_turn or psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_fia_3") then
            local ejtzh_jiyizhi = psw_main_data.player_data[faction_name].ejtzh_jiyizhi
            common.trigger_soundevent("ejtzh_2")
            advice_ejtzh_2_1()
            
            cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                {
                "psw_tf_ex_btmmfs_2"
                }
            )
            psw_main_data.player_data[faction_name].ejtzh_jiyizhi = 100
            cm:add_ancillary_to_faction(faction, "ejtzh_gqdrj", false)
            
            psw_aplly_costom_effect_bundle_hidden("set_psw_tf_ex_btmmfs_2", faction)
            
            psw_delete_shanbi_effect(faction_name, "jn_shanbi_ejtzh_sjgx")
            
            psw_ejtzh_main_jyz(faction)
            psw_hh_start_btmmfs(faction_name)
        end
    end
    
    ---圣园未花 茶话会
    if faction:has_effect_bundle("psw_dlc6_swyh_main_effect_chh") then
        local mika_recipe_1 = "psw_cook_mika_sydyh"
        local mika_recipe_2 = "psw_cook_mika_zdyh"
        if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_sywh_3") then
            mika_recipe_1 = "psw_cook_mika_sydyh_plus"
            mika_recipe_2 = "psw_cook_mika_zdyh_plus"
        end
        local random_number_mika_recipe = cm:random_number(100, 1)
        if random_number_mika_recipe <= 50 then
            cm:force_cook_recipe(faction, mika_recipe_1, false, false)
        else
            cm:force_cook_recipe(faction, mika_recipe_2, false, false)
        end
    end
    
    ---白花 白花的留恋
    if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_baihua") and not psw_faction_has_effect_bundle(faction_name, "psw_dlc7_baihua_songgui") then
        psw_add_jishu_bhdll(faction_name, 4)
    end
    
    ---轮次奖励
    if turn % 3 == 0 then
        psw_main_round_effect(faction_name)
    end
    
    ---佩洛洛的应援
    if turn % 5 == 0 and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_rifumei") then
        psw_rifumei_yingyuan_effect(faction_name)
    end
    
    ---鸣人 仙人模式回血
    if psw_faction_has_effect_bundle(faction_name, "psw_dlc7_mingren_xrms_on") then
        psw_tfmw_main_hp_effect(3, faction_name, "heal")
    end
    
    ---佐助 永恒万花筒写轮眼
    if psw_faction_has_effect_bundle(faction_name, "psw_dlc7_zuozhu_whtxly") and faction:has_effect_bundle("dtnl_on_psw_tf_nor_zuozhu") then
        local random_number_zuozhu = cm:random_number(100, 1)
        local card_key_zz
        if random_number_zuozhu > 50 then
            card_key_zz = "psw_jyjj_xg_zuozhu_tstz"
        else
            card_key_zz = "psw_jyjj_xd_zuozhu_jjtm"
        end
        psw_jyjj_main_get(faction_name, card_key_zz)
    end
    
    ---德丽莎 血印变化
    if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_delisha") then
        psw_dlc7_delisha_xueyin_huihe_add(faction_name)
    end
    
    ---六花 邪王真眼使
    if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_liuhua") then
        psw_dlc7_liuhua_xwzys_effect(faction_name)
        if not psw_faction_has_effect_bundle(faction_name, "psw_dlc7_liuhua_jingjie_cd") then
            psw_dlc7_liuhua_jingjie_huihe_effect(faction_name)
        end
    end
    
    ---emt 死亡回归
    if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_emt") and not psw_faction_has_effect_bundle(faction_name, "psw_dlc7_emt_swhg_cd_bundle") then
        psw_main_data.player_data[faction_name].tfmw_buff["psw_dlc7_buff_emt_swhg"].num = 1
    end
    
    ---卡里奥斯特罗   备用身体
    if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_klastl") and not psw_faction_has_effect_bundle(faction_name, "psw_dlc7_klastl_byst_cd_bundle") then
        psw_main_data.player_data[faction_name].tfmw_buff["psw_dlc7_buff_klastl_byst"].num = 1
    end
    
    
    ---小肥龙 充能
    if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_xfl") then
        psw_dlc7_xfl_cd_effect(faction_name)
    end
    
    ---梦见月瑞希
    if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_mjyrx") then
        psw_jyjj_main_pickup(faction_name, "default")
    end
    
    ---春庭
    if psw_faction_has_effect_bundle(faction_name, "psw_set_chunting_unlock") then
        psw_dlc7_chunting_main_czz_add(faction_name)
    end
    
    ---香草 永垂不朽
    if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_xiangcao") and not psw_faction_has_effect_bundle(faction_name, "psw_dlc7_xiangcao_ycbx_cd_bundle") then
        psw_main_data.player_data[faction_name].tfmw_buff["psw_dlc7_buff_xiangcao_ycbx"].num = 1
    end
    
    ---早苗 守矢神社
    if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_miao_1") then
        local miao_money_level = psw_main_data.player_data[faction_name].miao_money_level
        local miao_xy_num = psw_main_data.player_data[faction_name].miao_xy_num
        ---塞钱箱
        psw_main_data.player_data[faction_name].miao_money = psw_main_data.player_data[faction_name].miao_money + (miao_xy_num * miao_money_level)
        ---被动 收集信仰
        psw_dlc7_miao_xy_huihe_add(faction_name)
        psw_dlc7_miao_hadsf_turn_add_zaidong(faction_name)
        psw_dlc7_miao_mxzqj_turn_test(faction_name)
        psw_dlc7_miao_qj_wugu_turn_effect(faction_name)
    end
    
    
    ---基沃托斯
    if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_jwts_1") then
        ---破产的对策委员会
        psw_dlc7_pc_dcwyh_effect(faction_name)
        ---觉醒后函数
        if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_jwts_2") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_jwts_3") then
            psw_dlc7_jwts_color_turn_get(faction_name)
        end
    end
    
    
    ---爱梅斯
    if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_ams_1") then
        if not faction:has_effect_bundle("psw_dlc7_ams_mission_select") then
            psw_dlc7_ams_mission_refresh(faction_name)
        end
        psw_dlc7_ams_add_turn_sjxz(faction_name)
    end
    
    ---今汐
    if faction:has_effect_bundle("set_psw_tf_ex_jinxi_1") then
        psw_dlc7_jinxi_delete_cslx(faction_name, false)
        psw_dlc7_jinxi_turn_effect(faction_name)
        
    end
    
    ---鸣潮 每回合回复缓存/效果
    if faction:has_effect_bundle("psw_dlc7_mc_qd") then
        psw_dlc7_main_turn_effect(faction_name)
    end
    
    ---菲比 每回合回复缓存/效果
    if faction:has_effect_bundle("set_psw_tf_ex_feibi_1") then
        psw_dlc7_feibi_turn_start_effect(faction_name)
    end
    
    ---星野
    if faction:has_effect_bundle("set_psw_tf_ex_xingye_1") then
        psw_dlc7_xingye_turn_effect(faction_name)
    end
    
    ---莉莉卡
    if faction:has_effect_bundle("set_psw_tf_ex_lilika_1") then
        psw_dlc7_lilika_turn_effect(faction_name)
    end
    
    ---知更鸟
    if faction:has_effect_bundle("set_psw_tf_nor_zgn") then
        psw_dlc7_zgn_jishu_add(faction_name)
    end
    
    ---橘雪莉 回复推理次数
    if faction:has_effect_bundle("hero_select_shiki") then
        psw_main_data.player_data[faction_name].xueli_tuili_turn_num = 0
    end
    
    ---少女 月兆
    if faction:has_effect_bundle("set_psw_tf_ex_shaonv") then
        psw_dlc7_shaonv_turn_effect(faction_name, false)
    end
    
    ---曼城茶座 更新缓存
    if faction:has_effect_bundle("set_psw_tf_ex_chazuo") then
        psw_dlc7_chazuo_turn_xl_num_refresh(faction_name)
        psw_main_data.player_data[faction_name].saima_data.xd_point_crt = psw_main_data.player_data[faction_name].saima_data.xd_point_sx
    end
    
    
    
    ---星核猎手 万界之癌
    if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_firefly_2") then
        psw_dlc7_wjza_ks_turn()
        psw_dlc7_firefly_wqrs_off_effect(faction_name)
        if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_firefly_3") then
            psw_dlc7_firefly_add_jyjj_turn()
        end
        
    end
    
    
    
end








--------------------------------------------------------------
----------------------- 回合开始 监听主函数 -------------------------
-------------------------------------------------------------- 


function psw_main_FactionTurnStart_listner()
    core:remove_listener("psw_main_FactionTurnStart_listner")
	core:add_listener(
	"psw_main_FactionTurnStart_listner",
	"FactionTurnStart",
    function(context)
        if context:faction():is_human() == true then
            return true
        end
    end,
	function(context)
        local faction_name = context:faction():name()
        
        local turn = cm:turn_number()
        
        if turn == 1 then
            return
        end
        
        
        cm:callback(function()
            psw_main_turn_effect(faction_name, turn)
            
            
            
        end, 5)
        
        
    end,
    true
    )
end


































---移除所有禁止移动buff
local function remove_all_buff_hp0(faction_name)
    local faction = cm:get_faction(faction_name)
    local character_list = faction:character_list()
    for j = 0, character_list:num_items() - 1 do
        local current_character = character_list:item_at(j)
        if cm:char_is_general_with_army(current_character) then
            cm:remove_effect_bundle_from_character("psw_dlc7_tfmw_hp0_effect", current_character)
        end
    end
end



--------------------------------------------------------------
----------------------- 回合结束 监听主函数 -------------------------
-------------------------------------------------------------- 

function psw_main_FactionTurnEnd_listner()
    core:remove_listener("psw_main_FactionTurnEnd_listner")
	core:add_listener(
	"psw_main_FactionTurnEnd_listner",
	"FactionTurnEnd",
    function(context)
        local faction = context:faction()
        return faction:is_human()
    end,
	function(context)
        local faction = context:faction()
        local faction_name = faction:name()
        
        local psw_main_character = psw_get_main_character(faction_name)
        
        psw_main_data.global_data.set_zmjs_hh = false
        psw_main_data.global_data.set_yb_main = false
        psw_main_data.global_data.set_mowang_progress_hh = false
        local tfmw_is_start = psw_main_data.global_data.tfmw_is_start
        local mowang_faction_key = nil
        local turn = cm:turn_number()
        
        if tfmw_is_start then
            mowang_faction_key = psw_mowang_data.mowang_faction_key
            psw_dlc7_tfmw_wef_jcgx_buff_hp_effect(faction_name, mowang_faction_key)
        end
        
        local effect_list_csyx = {
            {effect = "wh2_main_effect_grant_immortality_lord", effect_scope = "character_to_character_own", effect_num = 1},
        }
        psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_jzyd_csyx", 0, effect_list_csyx)
        
        ---星法 嗜睡的睡美人
        if faction:has_effect_bundle("psw_dlc6_xingfa_ewnl_cnl_have_use") then
            psw_dlc6_xingfa_shui_apply(faction_name)
        end
        ---血雨
        if faction:has_effect_bundle("psw_main_ybdtq_xueyu") then
            psw_main_cost_faction_to_force_all(faction_name, 15)
        ---初霁
        elseif faction:has_effect_bundle("psw_main_ybdtq_chuji") then
            psw_main_heal_faction_to_force_all(faction_name, 15)
        end
        
        ---讨伐魔王效果区
        if tfmw_is_start then
            ---hp0效果结束
            if psw_main_data.player_data[faction_name].under_hp0_protect.is_under_hp0_protect then
                local hp0_turn = psw_main_data.player_data[faction_name].under_hp0_protect.turn
                if hp0_turn > 0 then
                    psw_main_data.player_data[faction_name].under_hp0_protect.turn = psw_main_data.player_data[faction_name].under_hp0_protect.turn - 1
                end
                if psw_main_data.player_data[faction_name].under_hp0_protect.turn == 0 then
                    psw_main_data.player_data[faction_name].under_hp0_protect.is_under_hp0_protect = false
                    remove_all_buff_hp0(faction_name)
                    local hp_sx = psw_main_data.player_data[faction_name].hp_sx
                    psw_tfmw_main_hp_effect(hp_sx, faction_name, "heal")
                end
            end
        end
        
        ---BOSS未挑战成功
        local boss_faction_name = nil
        if psw_main_data.global_data.psw_tfmw_is_tp_boss1 then
            psw_main_data.global_data.psw_tfmw_is_tp_boss1 = false
            psw_main_mowang_progress_change_effect(1)
            psw_tfmw_all_AI_atk_up(3)
            
            ---消灭BOSS派系
            if psw_main_data.global_data.psw_boss_create_lhz then
                psw_main_data.global_data.psw_boss_create_lhz = false
                boss_faction_name = "wh3_dlc23_chd_chaos_dwarfs_qb2"
            elseif psw_main_data.global_data.psw_boss_create_jwsq then
                psw_main_data.global_data.psw_boss_create_jwsq = false
                boss_faction_name = "wh_main_chs_chaos_qb2"
            end
            
            custom_starts:kill_faction(boss_faction_name)
            alice_tfmw_boss_defeat()
        elseif psw_main_data.global_data.psw_tfmw_is_tp_boss2 then
            psw_main_data.global_data.psw_tfmw_is_tp_boss2 = false
            psw_main_mowang_progress_change_effect(1)
            psw_tfmw_all_AI_def_up(3)
            
            
            ---消灭BOSS派系
            if psw_main_data.global_data.psw_boss_create_sznw then
                psw_main_data.global_data.psw_boss_create_sznw = false
                boss_faction_name = "wh_main_grn_greenskins_qb1"
            elseif psw_main_data.global_data.psw_boss_create_slzz then
                psw_main_data.global_data.psw_boss_create_slzz = false
                boss_faction_name = "wh_dlc05_wef_wood_elves_qb2"
            end
            
            custom_starts:kill_faction(boss_faction_name)
            alice_tfmw_boss_defeat()
        elseif psw_main_data.global_data.psw_tfmw_is_tp_boss3 then
            psw_main_data.global_data.psw_tfmw_is_tp_boss3 = false
            psw_main_mowang_progress_change_effect(1)
            psw_tfmw_all_AI_def_atk_up(3)
            
            
            ---消灭BOSS派系
            if psw_main_data.global_data.psw_boss_create_lyzm then
                psw_main_data.global_data.psw_boss_create_lyzm = false
                boss_faction_name = "wh2_main_hef_high_elves_qb1"
            elseif psw_main_data.global_data.psw_boss_create_lyjl then
                psw_main_data.global_data.psw_boss_create_lyjl = false
                boss_faction_name = "wh3_dlc23_chd_chaos_dwarfs_qb1"
            end
            
            custom_starts:kill_faction(boss_faction_name)
            alice_tfmw_boss_defeat()
        end
        
        if psw_main_data.global_data.psw_tfmw_is_tp_boss_end then
            psw_main_data.global_data.psw_tfmw_is_tp_boss_end = false
            psw_main_mowang_progress_change_effect(1)
            psw_tfmw_all_AI_def_atk_up(1)
            alice_tfmw_boss_defeat()
        end
        
        ---清除临时攻击力与防御力
        psw_clear_temp_atk_def(faction_name)
        
        ---清除旅途商店缓存
        if turn % 3 == 0 then
            psw_main_data.player_data[faction_name].have_open_shop = false
            psw_main_data.player_data[faction_name].shop_card_pool = {}
            psw_main_data.player_data[faction_name].gmsj_purchase_num = 2
        end
        
        ---记忆结晶每回合检测
        psw_main_data.player_data[faction_name].jyjj_sx_test_hh = true
        
        ---连击点 清0
        psw_main_data.player_data[faction_name].yzs_lianji_num = 0
        
        ---糖糖 感情过量摄入
        if psw_faction_has_effect_bundle(faction_name, "psw_dlc7_tangtang_gqglsr_install") then
            local jishu_tangtang_ai = psw_main_data.player_data[faction_name].jishu_tangtang_ai
            psw_add_jishu_tangtang_ai(faction_name, -jishu_tangtang_ai)
            cm:remove_effect_bundle("psw_dlc7_tangtang_gqglsr_install", faction_name)
        end
        
        ---负债效果
        psw_fuzhai_effect(faction_name)
        
        ---佐助 写轮眼 扣血
        if psw_faction_has_effect_bundle(faction_name, "dtnl_on_psw_tf_nor_zuozhu") then
            psw_dlc7_zuozhu_hp_effect(faction_name)
        end
        
        ---六花 邪王真眼使
        if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_liuhua") then
            psw_dlc7_liuhua_turn_yichu(faction_name)
        end
        
        ---切嗣
        
        if psw_faction_has_effect_bundle(faction_name, "psw_dlc7_qiesi_gysyz_bundle") then
            psw_dlc7_qiesi_turn_end_effect(faction_name)
        end
        
        ---静流
        if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_jingliu") then
            psw_buff_add_jiangu_num(faction_name, 3)
        end
        
        ---星绘
        if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_xinghui") then
            psw_buff_add_jiangu_num(faction_name, 3)
        end
        
        ---梦见月瑞希
        if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_mjyrx") then
            psw_tfmw_main_hp_effect(2, faction_name, "heal")
            psw_main_heal_faction_to_force_all(faction_name, 20)
        end
        
        ---百可花
        if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_bkh") then
            psw_buff_add_jiangu_num(faction_name, 3)
        end
        
        ---可可萝 结束时消耗光蝶
        if faction:has_effect_bundle("set_psw_tf_sp_kokoro") then
            local kokora_die_num = psw_main_data.player_data[faction_name].kokora_die
            if kokora_die_num >= 2 then
                psw_dlc7_kokora_add_die_num(faction_name, -2)
                psw_tfmw_main_hp_effect(2, faction_name, "heal")
                psw_main_heal_faction_to_force_all(faction_name, 20)
            end
        end
        
        ---珂莱塔
        if faction:has_effect_bundle("set_psw_tf_ex_klt_1") then
            psw_dlc7_klt_delete_ksjz_turn_end(faction_name)
        end
        
        ---菲比
        if faction:has_effect_bundle("set_psw_tf_ex_feibi_1") then
            psw_dlc7_feibi_turn_end_effect(faction_name)
        end
        
        ---雪风
        if faction:has_effect_bundle("set_psw_tf_ex_xuefeng_1") then
            psw_dlc7_xuefeng_turn_end_effect(faction_name)
        end
        
        ---雪风2
        if faction:has_effect_bundle("set_main_psw_tf_ex_xuefeng_2") then
            psw_dlc7_xuefeng_huhang_huifu(faction_name)
        end
        
        ---晓美焰
        if faction:has_effect_bundle("set_psw_tf_ex_xmy_2") and not faction:has_effect_bundle("set_psw_tf_ex_xmy_3") then
            psw_dlc7_xmy_turn_end_effect(faction_name)
        end
        
        ---菲比 七美德
        if faction:has_effect_bundle("hero_select_yly") then
            psw_dlc7_feibi_turn_end_qmd_effect(faction_name)
        end
        
        ---露露卡 幻影怪盗团
        if faction:has_effect_bundle("set_psw_tf_sp_luluka") then
            psw_dlc7_luluka_turn_end_effect(faction_name)
        end
        
        
        ---事件回合结束效果
        psw_dlc7_main_event_turn_end_effect(faction_name)
        
        
	end,
	true
	)
end

--------------------------------------------------------------
----------------------- 角色回合结束 监听主函数 -------------------------
-------------------------------------------------------------- 
local forest_region_pool = {
    wh3_main_combi_region_vauls_anvil_loren = true,
    wh3_main_combi_region_waterfall_palace = true,
    wh3_main_combi_region_crag_halls_of_findol = true,
    wh3_main_combi_region_the_oak_of_ages = true,
    wh3_main_combi_region_kings_glade = true,
    wh3_dlc23_chaos_region_the_haunted_forest = true,
    wh3_main_combi_region_laurelorn_forest = true,
    wh3_main_combi_region_the_witchwood = true,
    wh3_main_combi_region_gryphon_wood = true,
    wh3_main_combi_region_forest_of_gloom = true,
    wh3_main_combi_region_jungles_of_chian = true,
    wh3_main_combi_region_oreons_camp = true,
    wh3_main_combi_region_the_sacred_pools = true,
    wh3_main_combi_region_gaean_vale = true,
}

function psw_main_CharacterTurnEnd_listner()
    core:remove_listener("psw_main_CharacterTurnEnd_listner")
    core:add_listener(
    "psw_main_CharacterTurnEnd_listner",
    "CharacterTurnEnd",
    function(context)
        local character = context:character();
        local faction = character:faction()
        return faction:is_human()
    end,
    function(context)
        local character = context:character();
        local faction = character:faction()
        local faction_name = faction:name()
        local region = character:region()
        local region_key = region:name()
        local faction_leader = faction:faction_leader()
        local stance = faction_leader:military_force():active_stance()
        
        ---伊蕾娜 先去采集药草！
        if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_yln_2") then
            if forest_region_pool[ region_key ] then
                local yln_yc_gl = 50
                local ran_num_yln_yc = cm:random_number(100, 1)
                if ran_num_yln_yc <= yln_yc_gl then
                    cm:add_ancillary_to_faction(faction, "psw_dlc6_yln_yaocao", false)
                    psw_yln_jishu_yaocao(faction_name, 1)
                end
            end
        end
        
        ---鸣人 仙人模式
        if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_mingren") then
            if stance == "MILITARY_FORCE_ACTIVE_STANCE_TYPE_CHANNELING" and not psw_faction_has_effect_bundle(faction_name, "psw_dlc7_mingren_xrms_on") then
                psw_dlc7_mingren_xrms_on(faction_name)
                psw_aplly_costom_effect_bundle_hidden_fn("psw_dlc7_mingren_xrms_on", faction_name)
            elseif stance ~= "MILITARY_FORCE_ACTIVE_STANCE_TYPE_CHANNELING" and psw_faction_has_effect_bundle(faction_name, "psw_dlc7_mingren_xrms_on") then
                psw_dlc7_mingren_xrms_off(faction_name)
                cm:remove_effect_bundle("psw_dlc7_mingren_xrms_on", faction_name)
            end
        end
        
        
    end,
    true
    )
end


------ 优香-高速心算 ------
function psw_dlc7_youxiang_gsxs_effect()
    local youxiang_faction_list = cm:model():world():faction_list();
    for i = 0, youxiang_faction_list:num_items() - 1 do
        local current_faction = youxiang_faction_list:item_at(i);
        if current_faction:is_human() == true then
            local crt_faction_name = current_faction:name();
            cm:apply_effect_bundle("jnz_tf_ex_youxiang_gsxs", crt_faction_name, 1)
            local character_list = current_faction:character_list()
            for j = 0, character_list:num_items() - 1 do
                local current_character = character_list:item_at(j)
                psw_repenishi_action_points(current_character:cqi())
            end
        end
    end
end

--------------------------------------------------------------
----------------------- 独特能力 监听主函数 -------------------------
-------------------------------------------------------------- 
local yzs_tf_pool = {
    psw_tf_nor_anne = true,
    psw_tf_nor_aly = true,
    psw_tf_nor_feilin = true,
    psw_tf_sp_xlfh = true,
}

------ 独特能力 效果触发 ------
core:remove_listener("ui_psw_main_dtnl_listner")
core:add_listener("ui_psw_main_dtnl_listner",
    "UITrigger",
    function(context)
        return context:trigger():starts_with("dtnl_main_psw_")
    end,
    function(context)
        local faction = cm:model():faction_for_command_queue_index(context:faction_cqi())
        local faction_name = faction:name()
        local turn = cm:turn_number()
        local psw_main_character = psw_get_main_character(faction_name)
        
        local trigger_name = context:trigger()
        local dilemma_key = string.gsub(trigger_name, "dtnl_main_", "")
        local treasury = faction:treasury()
        
        local cd_bundle_key = "dtnl_cd_" .. dilemma_key
        local effect_bundel_key = "dtnl_effect_" .. dilemma_key
        
        local effect_list
        
        
        
        ---沙优 
        if dilemma_key == "psw_tf_nor_shayou_1" and not faction:has_effect_bundle(cd_bundle_key) then
            if faction:has_effect_bundle("psw_dlc6_bundle_shayou") then
                local shayou_bkz = psw_main_data.player_data[faction_name].shayou_bkz
                if shayou_bkz < 100 then
                    if treasury >= 5000 then
                        psw_aplly_costom_effect_bundle_with_time_hidden(cd_bundle_key, faction, 2)
                        cm:treasury_mod(faction_name, -5000)
                        psw_add_jishu_meili(faction_name, -1)
                        psw_add_shayou_bkz(faction_name, 20)
                        local music_list_shayou = {
                            "shayou_1",
                            "shayou_2",
                        }
                        psw_play_random_music(music_list_shayou)
                        if psw_is_character_interface(psw_main_character) then
                            local psw_shayou_qsx = 0
                            if psw_main_character:has_effect_bundle(effect_bundel_key) then
                                psw_main_data.player_data[faction_name].psw_shayou_qsx = psw_main_data.player_data[faction_name].psw_shayou_qsx + 1
                                psw_shayou_qsx = psw_main_data.player_data[faction_name].psw_shayou_qsx
                                psw_add_all_sx_to_faction(psw_main_character, effect_bundel_key, psw_shayou_qsx, 1)
                            else
                                psw_main_data.player_data[faction_name].psw_shayou_qsx = psw_main_data.player_data[faction_name].psw_shayou_qsx + 4
                                psw_shayou_qsx = psw_main_data.player_data[faction_name].psw_shayou_qsx
                                psw_add_all_sx_to_faction(psw_main_character, effect_bundel_key, psw_shayou_qsx, 1)
                            end
                        end
                    end
                else
                    cm:remove_effect_bundle("psw_dlc6_bundle_shayou", faction_name)
                end
            end
        
        
        ---梗小姐 
        elseif dilemma_key == "psw_tf_nor_gengxj" and psw_faction_has_effect_bundle(faction_name, "psw_dlc6_gxj_yqy") then
            local qyz_faction_naem = psw_main_data.player_data[faction_name].gxj_qy_fc_name
            local jiyizhi_gxj = psw_main_data.player_data[qyz_faction_naem].jiyizhi_gxj
            if jiyizhi_gxj > 0 then
                psw_add_jiyizhi_gxj(qyz_faction_naem, -1)
                local music_list = {
                    "gxj_dtnl_1",
                    "gxj_dtnl_3",
                    "gxj_dtnl_4",
                    "gxj_dtnl_5",
                }
                psw_play_random_music(music_list)
                
                psw_main_data.player_data[faction_name].dtnl_gxj_jishu = psw_main_data.player_data[faction_name].dtnl_gxj_jishu + 1
                
                
                if not faction:has_effect_bundle(cd_bundle_key) then
                    psw_main_data.player_data[faction_name].dtnl_gxj_jishu = 1
                    cm:remove_effect_bundle("dtnl_effect_psw_tf_nor_gengxj", faction_name)
                    cm:remove_effect_bundle("dtnl_effect_psw_tf_nor_gengxj_emdbf", faction_name)
                    cm:remove_effect_bundle("dtnl_effect_psw_tf_nor_gengxj_emddr", faction_name)
                end
                local dtnl_gxj_jishu = psw_main_data.player_data[faction_name].dtnl_gxj_jishu
                effect_list = {
                    {effect = "wh_main_effect_force_stat_melee_attack", effect_scope = "faction_to_force_own", effect_num = dtnl_gxj_jishu * 1},
                    {effect = "wh_main_effect_force_stat_melee_defence", effect_scope = "faction_to_force_own", effect_num = dtnl_gxj_jishu * 1},
                    {effect = "wh_main_effect_force_stat_armour", effect_scope = "faction_to_force_own", effect_num = dtnl_gxj_jishu * 3},
                    {effect = "wh_main_effect_force_stat_ward_save", effect_scope = "faction_to_force_own", effect_num = dtnl_gxj_jishu},
                    {effect = "wh_main_effect_force_stat_magic_resistance", effect_scope = "faction_to_force_own", effect_num = dtnl_gxj_jishu},
                    {effect = "wh_main_effect_force_stat_missile_resistance", effect_scope = "faction_to_force_own", effect_num = dtnl_gxj_jishu},
                    {effect = "wh_main_effect_force_stat_fire_resistance", effect_scope = "faction_to_force_own", effect_num = dtnl_gxj_jishu},
                    {effect = "wh_main_effect_force_stat_physical_resistance", effect_scope = "faction_to_force_own", effect_num = dtnl_gxj_jishu},
                    {effect = "wh_main_effect_character_stat_ward_save", effect_scope = "faction_to_character_own", effect_num = -dtnl_gxj_jishu},
                }
                if dtnl_gxj_jishu >= 3 and not faction:has_effect_bundle("dtnl_effect_psw_tf_nor_gengxj_emdbf") then
                    local effect_list_emdbf = {
                        {effect = "psw_dlc6_gxj_emdbf", effect_scope = "faction_to_force_own", effect_num = 1},
                    }
                    psw_main_apply_effect_to_faction(faction_name, "dtnl_effect_psw_tf_nor_gengxj_emdbf", 0, effect_list_emdbf)
                end
                if dtnl_gxj_jishu >= 6 and not faction:has_effect_bundle("dtnl_effect_psw_tf_nor_gengxj_emddr") then
                    local effect_list_emddr = {
                        {effect = "psw_dlc6_gxj_emddr", effect_scope = "faction_to_force_own", effect_num = 1},
                    }
                    psw_main_apply_effect_to_faction(faction_name, "dtnl_effect_psw_tf_nor_gengxj_emddr", 0, effect_list_emddr)
                end
                
                psw_main_apply_effect_to_faction(faction_name, "dtnl_effect_psw_tf_nor_gengxj", 0, effect_list)
                if not faction:has_effect_bundle(cd_bundle_key) then
                    psw_aplly_costom_effect_bundle_with_time_hidden(cd_bundle_key, faction, 3)
                end
            end
            
        
        ---巫女姬 神乐舞
        elseif dilemma_key == "psw_tf_nor_wunvji" and not faction:has_effect_bundle(cd_bundle_key) then
            psw_aplly_costom_effect_bundle_with_time_hidden(cd_bundle_key, faction, 5)
            psw_dlc6_wunvji_slw(faction_name)
            common.trigger_soundevent("wunvji_cialo")
        
        ---黑兔 史诗·摩诃婆罗多的碎片
        elseif dilemma_key == "psw_tf_nor_heitu" and not faction:has_effect_bundle(cd_bundle_key) then
            psw_aplly_costom_effect_bundle_with_time_hidden(cd_bundle_key, faction, 3)
            effect_list = {
                {effect = "psw_dlc6_heitu_rtk", effect_scope = "faction_to_force_own", effect_num = 1},
                {effect = "psw_dlc6_heitu_fsq", effect_scope = "faction_to_character_own", effect_num = 1},
            }
            psw_main_apply_effect_to_faction(faction_name, effect_bundel_key, 1, effect_list)
            psw_main_cost_faction_to_force_all(faction_name, 20)
            
        ---丘比 愿望实现
        elseif dilemma_key == "psw_tf_sp_qb_tf" and not faction:has_effect_bundle(cd_bundle_key) then
            psw_aplly_costom_effect_bundle_with_time_hidden(cd_bundle_key, faction, 0)
            cm:trigger_dilemma(faction_name, "dilemma_tf_qb_yysx")
        
        ---圆环之理 苏生之福音
        elseif (dilemma_key == "psw_tf_ex_yhzl_2" or dilemma_key == "psw_tf_ex_yhzl_3") and not faction:has_effect_bundle(cd_bundle_key) then
            common.trigger_soundevent("yhzl_ssdfy")
            psw_aplly_costom_effect_bundle_with_time_hidden(cd_bundle_key, faction, 3)
            psw_dlc6_sszfy_effect_apply(faction_name)
            
        ---三株树
        elseif dilemma_key == "psw_yiwu_ex_szs" and not faction:has_effect_bundle(cd_bundle_key) then
            psw_aplly_costom_effect_bundle_with_time_hidden(cd_bundle_key, faction, 5)
            psw_main_heal_faction_to_force_all(faction_name, 100)
            common.trigger_soundevent("szs_dtnl")
            
        ---提亚马特
        elseif dilemma_key == "psw_yiwu_ex_tymt" and not faction:has_effect_bundle(cd_bundle_key) then
            psw_aplly_costom_effect_bundle_with_time_hidden(cd_bundle_key, faction, 5)
            psw_main_reheal_xd_juli(faction_name)
            common.trigger_soundevent("tymt_qszy")
            
        ---星之彩 异色流转
        elseif dilemma_key == "psw_yiwu_ex_xzc" then
            psw_dlc6_yiwu_ex_xzc_yslz(faction_name)
        
        ---真红 武器切换
        elseif dilemma_key == "psw_tf_ex_zhenhong_2" and not faction:has_effect_bundle(cd_bundle_key) then
            psw_aplly_costom_effect_bundle_with_time_hidden(cd_bundle_key, faction, 3)
            psw_dlc6_zhenhong_wqqh_effect_apply(faction_name)
            
            
        ---水银灯 黑羽散射
        elseif dilemma_key == "psw_tf_ex_syd_2" or dilemma_key == "psw_tf_ex_syd_3" then
            psw_dlc6_syd_hyss_effect(faction_name)
            
            
        ---符玄 天律大衍，历劫归一
        elseif dilemma_key == "psw_tf_ex_fuxuan_2" and not faction:has_effect_bundle(cd_bundle_key) then
            psw_aplly_costom_effect_bundle_with_time_hidden(cd_bundle_key, faction, 3)
            psw_dlc6_ex_fuxuan_tldy_ljgy_effect(faction_name)
            
            
        ---暗影庭院 狩猎暗影之人
        elseif dilemma_key == "psw_tf_sp_ayty" and not faction:has_effect_bundle(cd_bundle_key) then
            psw_dlc6_ayty_slanzr_main_effect(faction_name)
            
        ---帕秋莉 七曜元素之书
        elseif dilemma_key == "psw_tf_ex_pql" and not faction:has_effect_bundle(cd_bundle_key) then
            psw_dlc6_qyyszs_main_effect_apply(faction_name)
            
        ---向着未来闪耀 梦幻召唤
        elseif dilemma_key == "psw_tf_ex_xzwlsy" then
            psw_dlc6_xzwlsy_mhzh_effect(faction_name)
            
        ---伊蕾娜 旅行记录
        elseif dilemma_key == "psw_tf_sp_mnrj" and not faction:has_effect_bundle(cd_bundle_key) then
        --elseif dilemma_key == "psw_tf_sp_mnrj" then
            
            
            psw_dlc6_mnrj_dtnl_effect_apply(faction_name)
            
        ---伊蕾娜 魔法扫帚
        elseif dilemma_key:starts_with("psw_tf_ex_yln_") then
            psw_dlc6_yln_mlcn_mfsz(faction_name, dilemma_key)
            
        
        ---白花 白花的留恋
        elseif dilemma_key == "psw_tf_nor_baihua" then
            if not psw_faction_has_effect_bundle(faction_name, "psw_dlc7_baihua_bhdll") then
                psw_aplly_costom_effect_bundle_hidden_fn("psw_dlc7_baihua_bhdll", faction_name)
                cm:trigger_dilemma(faction_name, "dilemma_tf_dlc7_baihua")
            end
        
            
        ---糖糖 感情过量摄入
        elseif dilemma_key == "psw_tf_nor_tangtang" and not faction:has_effect_bundle(cd_bundle_key) then
            psw_aplly_costom_effect_bundle_with_time_hidden(cd_bundle_key, faction, 3)
            psw_dlc7_tangtang_gkqlsr_effect(faction_name)
            
        ---超天酱 网络天使
        elseif dilemma_key == "psw_tf_nor_ctj" and not faction:has_effect_bundle(cd_bundle_key) then
            psw_aplly_costom_effect_bundle_with_time_hidden(cd_bundle_key, faction, 5)
            psw_dlc7_ctj_wlts_effect(faction_name)
            
        ---佐助 写轮眼开
        elseif dilemma_key == "psw_tf_nor_zuozhu" and not faction:has_effect_bundle("dtnl_on_psw_tf_nor_zuozhu") and not faction:has_effect_bundle(cd_bundle_key) then
            psw_aplly_costom_effect_bundle_with_time_hidden("dtnl_on_psw_tf_nor_zuozhu", faction, 3)
            psw_dlc7_zuozhu_xielunyan_on_effect(faction_name)
        ---佐助 写轮眼关
        elseif dilemma_key == "psw_tf_nor_zuozhu" and faction:has_effect_bundle("dtnl_on_psw_tf_nor_zuozhu") then
            psw_dlc7_zuozhu_xielunyan_off_effect(faction_name)
            psw_aplly_costom_effect_bundle_with_time_hidden(cd_bundle_key, faction, 3)
            
        ---柚子 来做游戏吧
        elseif dilemma_key == "psw_tf_nor_yozi" and not faction:has_effect_bundle(cd_bundle_key) then
            psw_dlc7_yozi_game_play(faction_name)
            psw_aplly_costom_effect_bundle_with_time_hidden(cd_bundle_key, faction, 2)
            
        ---渚 实现愿望之所
        elseif dilemma_key == "psw_tf_nor_guhezhu" and faction:has_effect_bundle("psw_zhu_guangyu13_effect") and not faction:has_effect_bundle(cd_bundle_key) then
            cm:trigger_dilemma(faction_name, "dilemma_tf_dlc7_guhezhu")
            cm:remove_effect_bundle("psw_zhu_guangyu13_effect", faction_name)
            psw_aplly_costom_effect_bundle_with_time_hidden(cd_bundle_key, faction, 0)
            
        ---德丽莎 逾越命运的告白
        elseif dilemma_key == "psw_tf_nor_delisha" and faction:has_effect_bundle("psw_dlc7_delisha_xueyin10_bundle") and not faction:has_effect_bundle(cd_bundle_key) then
            
            psw_dlc7_delisha_gaobai_effect(faction_name)
            psw_aplly_costom_effect_bundle_with_time_hidden(cd_bundle_key, faction, 0)
            
        
            
        ---切嗣 固有时制御
        elseif dilemma_key == "psw_tf_nor_qiesi" and not faction:has_effect_bundle(cd_bundle_key) then
            common.trigger_soundevent("qiesi_gysyz")
            psw_aplly_costom_effect_bundle_with_time_hidden(cd_bundle_key, faction, 5)
            psw_aplly_costom_effect_bundle_hidden_fn("psw_dlc7_qiesi_gysyz_bundle", faction_name)
            
        ---知更鸟 千音迭奏
        elseif dilemma_key == "psw_tf_nor_zgn" then
            psw_dlc7_zgn_qydz_effect(faction_name)
            
        ---小肥龙 充能激发
        elseif dilemma_key == "psw_tf_nor_xfl" then
            psw_dlc7_xfl_cnjf_effect(faction_name)
            
        ---影之诗 进化
        elseif yzs_tf_pool[ dilemma_key ] then
            psw_yzs_main_jinhua_effect(faction_name, dilemma_key)
            
        ---早苗 引发奇迹
        elseif (dilemma_key == "psw_tf_ex_miao_2" or dilemma_key == "psw_tf_ex_miao_3") and not faction:has_effect_bundle("dtnl_cd_psw_tf_ex_miao_2") then
            
            psw_aplly_costom_effect_bundle_with_time_hidden("dtnl_cd_psw_tf_ex_miao_2", faction, 1)
            psw_dlc7_miao_yfqj_main_effect(faction_name)
            
        ---塔什干 觉醒
        elseif dilemma_key == "psw_tf_ex_tsg_1" then
            psw_dlc7_tsg_tls_juexing(faction_name)
            
        
            
        ---可可萝 极光圣域
        elseif dilemma_key == "psw_tf_sp_kokoro" and not faction:has_effect_bundle(cd_bundle_key) then
            psw_dlc7_kokora_jgsy_effect(faction_name)
            psw_aplly_costom_effect_bundle_with_time_hidden(cd_bundle_key, faction, 5)
            
        ---今汐 移岁诛邪
        elseif dilemma_key == "psw_tf_ex_jinxi_2" or dilemma_key == "psw_tf_ex_jinxi_3" then
            psw_dlc7_jinxi_gmjf_effect(faction_name, dilemma_key)
            
        ---珂莱塔 新浪潮时代
        elseif dilemma_key == "psw_tf_ex_klt_2" then
            psw_dlc7_klt_gmjf_effect(faction_name, dilemma_key)
            
        ---菲比 启明之誓愿
        elseif dilemma_key == "psw_tf_ex_feibi_2" then
            psw_dlc7_feibi_gmjf_effect(faction_name, dilemma_key)
            
        ---椿 一日花
        elseif dilemma_key == "psw_tf_nor_chun" and not faction:has_effect_bundle(cd_bundle_key) then
            psw_dlc7_chun_yrh_effect(faction_name)
            
        ---晓美焰 少女的决意
        elseif dilemma_key == "psw_tf_nor_xmy_zt" then
            psw_dlc7_xmy_sndjy_effect(faction_name)
            
        ---晓美焰 时间冻结
        elseif dilemma_key == "psw_tf_ex_xmy_2" and not faction:has_effect_bundle(cd_bundle_key) then
            psw_dlc7_xmy_dtnl_sjdj_effect(faction_name)
            
        ---晓美焰 事象改篡
        elseif dilemma_key == "psw_tf_ex_xmy_3" and not faction:has_effect_bundle(cd_bundle_key) then
            psw_dlc7_xmy_sxgc_effect(faction_name)
            
        ---莉莉卡 月夜下的告白
        elseif dilemma_key == "psw_tf_nor_lilika" then
            psw_dlc7_lilika_gaobai_effect(faction_name)
            
        
            
        ---优香
        elseif dilemma_key == "psw_tf_ex_youxiang_2" and not faction:has_effect_bundle(cd_bundle_key) then
            psw_aplly_costom_effect_bundle_with_time_hidden(cd_bundle_key, faction, 5)
            local advice_number = cm:random_number(100, 1)
            if advice_number <= 33 then
                advice_youxiang_gsxs_1_zl()
            elseif advice_number <= 66 and advice_number > 33 then
                advice_youxiang_gsxs_2_xsd()
            elseif advice_number <= 100 and advice_number > 66 then
                advice_youxiang_gsxs_3_yqsb()
            end
            psw_dlc7_youxiang_gsxs_effect()
            
            
        ---少女 她的乡愁
        elseif dilemma_key == "psw_tf_ex_shaonv" and not faction:has_effect_bundle(cd_bundle_key) then
            psw_dlc7_shaonv_xc_effect(faction_name)
        
        
        ---露露卡 爱吃冰淇淋的美少女
        elseif dilemma_key == "psw_tf_sp_luluka" and not faction:has_effect_bundle(cd_bundle_key) then
            psw_dlc7_luluka_ice_cream(faction_name)
            
            
        ---------------结束
        end
    end,
    true
)









--------------------------------------------------------------
----------------------- 建筑完成 监听主函数 -------------------------
-------------------------------------------------------------- 
function psw_main_BuildingCompleted_listner()
    core:remove_listener("psw_main_BuildingCompleted_listner")
    core:add_listener(
        "psw_main_BuildingCompleted_listner",
        "BuildingCompleted",
        function(context)
            local building = context:building()
            local building_name = building:name()
            local faction = building:faction()
            return (building_name == "psw_dlc6_cstf_fuxuan_qgz_4" or building_name == "psw_dlc7_feibi_dgwu_1") and faction:is_human()
        end,
        function(context)
            local building = context:building()
            local faction = building:faction()
            local faction_name = building:faction():name()
            local building_name = building:name()
            local garrison_residence = context:garrison_residence()
            local region_key = garrison_residence:region():name()
            local turn = cm:turn_number()
            
            if building_name == "psw_dlc6_cstf_fuxuan_qgz_4" then
                if not faction:has_effect_bundle("psw_dlc6_cstf_fuxuan_sjsx_bundle") then
                    local effect_list = {
                        {effect = "psw_dlc6_cstf_fuxuan_sjsx", effect_scope = "faction_to_force_own", effect_num = 1},
                    }
                    
                    psw_main_apply_effect_to_faction(faction_name, "psw_dlc6_cstf_fuxuan_sjsx_bundle", 0, effect_list)
                end
            elseif building_name == "psw_dlc7_feibi_dgwu_1" then
                
                local agent_x, agent_y = cm:find_valid_spawn_location_for_character_from_settlement(faction_name, region_key, false, true, 2)
            
                local cultist = cm:create_agent(faction_name, "dignitary", "psw_dlc7_feibi_jiaoshi_0", agent_x, agent_y, true)
                if cultist then
                    cm:replenish_action_points(cm:char_lookup_str(cultist))
                    if turn >= 10 then
                        cm:add_agent_experience(cm:char_lookup_str(cultist), turn * 1500)
                    end
                end
            end
            
        end,
        true
    );
end












--------------------------------------------------------------
----------------------- 额外能力 点击使用 监听主函数 -------------------------
-------------------------------------------------------------- 


core:remove_listener("ui_ewnl_psw_main_listner")
core:add_listener("ui_ewnl_psw_main_listner",
    "UITrigger",
    function(context)
        return context:trigger():starts_with("ewnl_main_")
    end,
    function(context)
        local faction = cm:model():faction_for_command_queue_index(context:faction_cqi())
        local faction_name = faction:name()
        local trigger_name = context:trigger()
        local dilemma_key = string.gsub(trigger_name, "ewnl_main_", "")
        local psw_shenxing = faction:pooled_resource_manager():resource("psw_shenxing"):value()
        local psw_xingyun =  faction:pooled_resource_manager():resource("psw_xingyun"):value()
        local psw_jianshu = psw_main_data.player_data[faction_name].psw_jianshu
        local psw_moli =  faction:pooled_resource_manager():resource("psw_moli"):value()
        local psw_meili = psw_main_data.player_data[faction_name].psw_meili
        local psw_zhixing = psw_main_data.player_data[faction_name].psw_zhixing or 0
        local psw_zhiyu = psw_main_data.player_data[faction_name].psw_zhiyu
        local psw_kxct = psw_main_data.player_data[faction_name].psw_kxct
        
        ---笼中鸟 生形态切换死
        if dilemma_key == "psw_dlc6_cstf_niao_sheng" then
            ewnl_ui_display_niao_si(faction_name)
            lzn_si_xt_effect(faction_name)
        ---笼中鸟 死形态切换生
        elseif dilemma_key == "psw_dlc6_cstf_niao_si" then
            ewnl_ui_display_niao_sheng(faction_name)
            lzn_sheng_xt_effect(faction_name)
        ---月光鸟 启示之翼
        elseif dilemma_key == "psw_dlc6_cstf_ygn_qszy" and not faction:has_effect_bundle("ewnl_cd_psw_dlc6_ygn_qszy") then
            psw_dlc6_ygn_qszy_apply(faction_name)
            
        ---符玄 以额间之眼观之
        elseif dilemma_key == "psw_dlc6_ex_fuxuan_ejzy" then
            if faction:has_effect_bundle("ewnl_cd_psw_tf_ex_fuxuan_1") then
                advice_dlc6_alice_ewnl_crt_cd()
            else
                psw_dlc6_ex_fuxuan_ejzy_effect_apply(faction_name)
            end
            
        ---符玄 预卜吉凶
        elseif dilemma_key == "psw_dlc6_cstf_fuxuan_ybjx" then
            if faction:has_effect_bundle("psw_dlc6_cstf_fuxuan_ybjx_cd") then
                advice_dlc6_alice_ewnl_crt_cd()
            else
                psw_dlc6_cstf_fuxuan_ybjx_effect(faction_name)
            end
            
            
            
        ---星法 超能力 飞行
        elseif dilemma_key == "psw_dlc6_xingfa_cnl_fei" then
            psw_dlc6_xingfa_cnl_fei_effect(faction_name)
        ---星法 超能力 时间回溯
        elseif dilemma_key == "psw_dlc6_xingfa_cnl_sjhs" then
            psw_dlc6_xingfa_cnl_sjhs_effect(faction_name)
        ---星法 超能力 幸运魔力
        elseif dilemma_key == "psw_dlc6_xingfa_cnl_xyml" then
            psw_dlc6_xingfa_cnl_xyml_effect(faction_name)
            
        ---圣园未花 愿主垂怜
        elseif dilemma_key == "psw_dlc6_ex_mika_mulu_yzcl" then
            psw_dlc6_sywh_effect_apply_yzcl(faction_name)
            
        ---圣园未花 不眠不休
        elseif dilemma_key == "psw_dlc6_ex_mika_mulu_bmbx" then
            psw_dlc6_sywh_effect_apply_bmbx(faction_name)
            
        ---圣园未花 神名效果激活
        elseif dilemma_key:starts_with("psw_dlc6_ex_mika_syxy_") then
            psw_dlc6_sywh_effect_apply_smxg(faction_name, dilemma_key)
            
        -------------------面板选择----------------------
        elseif dilemma_key == "psw_main_mulu_mb_1" then
            ewnl_ui_display_jcsx_1(faction_name, psw_shenxing, psw_xingyun, psw_zhixing, psw_moli, psw_jianshu, psw_meili, psw_zhiyu, psw_kxct)
            
        elseif dilemma_key == "psw_main_mulu_mb_2" then
            ewnl_ui_display_jcsx_2(faction_name)
            
        elseif dilemma_key == "psw_main_mulu_mb_3" then
            ewnl_ui_display_jcsx_3(faction_name)
            
        elseif dilemma_key == "psw_main_mulu_mb_4" then
            ewnl_ui_display_jcsx_4(faction_name)
            
        elseif dilemma_key == "psw_main_mulu_a_g" then
            ewnl_ui_display_zhenhong(faction_name)
            
        elseif dilemma_key == "psw_main_mulu_pql" then
            ewnl_ui_display_pql(faction_name)
            
        elseif dilemma_key == "psw_main_mulu_dlc6_gxj_emqy" then
            ewnl_ui_display_gxj_emdqy(faction_name)
            
        elseif dilemma_key == "psw_main_mulu_fuxuan_ybjx" then
            ewnl_ui_display_fuxuan_ybjx(faction_name)
            
        elseif dilemma_key == "psw_main_mulu_ygn_qszy" then
            ewnl_ui_display_ygn_qszy(faction_name)
            
        elseif dilemma_key == "psw_main_mulu_niao_sheng" then
            ewnl_ui_display_niao_si(faction_name)
            lzn_si_xt_effect(faction_name)
            
        elseif dilemma_key == "psw_main_mulu_niao_si" then
            ewnl_ui_display_niao_sheng(faction_name)
            lzn_sheng_xt_effect(faction_name)
            
        elseif dilemma_key == "psw_main_mulu_ex_fuxuan_ejzy" then
            ewnl_ui_display_fuxuan_ejzy(faction_name)
        
        elseif dilemma_key == "psw_main_mulu_ex_fuxuan_dgjs" then
            ewnl_ui_display_fuxuan_dgjs(faction_name)
            
        elseif dilemma_key == "psw_main_mulu_anying_atomic" then
            ewnl_ui_display_anying_atomic(faction_name)
        
        elseif dilemma_key == "psw_main_mulu_pql_ewnl_nyddhs" then
            ewnl_ui_display_pql_nyddhs(faction_name)
            
        elseif dilemma_key == "psw_main_mulu_qiyana_yjyq" then
            ewnl_ui_display_qiyana_yjyq_own(faction_name)
        
        elseif dilemma_key == "psw_main_mulu_xingfa_cnl" then
            ewnl_ui_display_xingfa_cnl(faction_name)
            
        elseif dilemma_key == "psw_main_mulu_syd_pl" then
            
            ewnl_ui_display_syd_pl_pljs(faction_name)
            
        elseif dilemma_key == "psw_main_mulu_mika" then
            
            ewnl_ui_display_sywh_glldgz(faction_name)
            if not faction:has_effect_bundle("psw_dlc6_swyh_advice_cd") then
                local random_number_mika_huanyin = cm:random_number(100, 1)
                if random_number_mika_huanyin <= 50 then
                    common.trigger_soundevent("sywh_huanyin_1")
                    advice_dlc6_mika_huanyin1()
                else
                    common.trigger_soundevent("sywh_huanyin_2")
                    advice_dlc6_mika_huanyin2()
                end
            end
        
        elseif dilemma_key == "psw_dlc6_ex_mika_mulu_ssy" then
            ewnl_ui_display_sywh_ssyzhxy(faction_name)
        
        elseif dilemma_key == "psw_dlc7_tfmw_mulu_main" then
            ewnl_ui_display_tfmw(faction_name)
            
        ---BUFF栏 查看
        elseif dilemma_key:starts_with("psw_dlc7_tfmw_mb_mowang") or dilemma_key:starts_with("psw_dlc7_tfmw_mb_player") then
            psw_dlc7_tfmw_buff_effect(faction_name, dilemma_key)
            
        ---BOSS传送
        elseif dilemma_key:starts_with("psw_dlc7_mw_buff_boss") then
            psw_dlc7_tfmw_boss_tp(faction_name, dilemma_key)
            
        ---重抽
        elseif dilemma_key:starts_with("psw_main_sx_2_repick") then
            psw_main_repick(faction_name)
            
        ---查看记忆结晶
        elseif dilemma_key:starts_with("psw_dlc7_tfmw_mb_card") then
            ewnl_ui_display_jyjj(faction_name)
            
        ---使用记忆结晶
        elseif dilemma_key:starts_with("psw_jyjj_") or dilemma_key:starts_with("psw_dlc7_shop_") then
            local is_on_shop = psw_main_data.player_data[faction_name].is_on_shop
            if not is_on_shop then
                local jyjj_num_is_sx = psw_main_data.player_data[faction_name].jyjj_num_is_sx
                if jyjj_num_is_sx then
                    psw_jyjj_num_sx_pickdown(faction_name, dilemma_key)
                elseif not jyjj_num_is_sx then
                    psw_jyjj_main_use_effect(faction_name, dilemma_key)
                end
            elseif is_on_shop then
                psw_main_purchase_card(faction_name, dilemma_key)
            end
        
        ---打开旅途商店
        elseif dilemma_key == "psw_main_mulu_shop" then
            ewnl_ui_display_shop(faction_name)
            
        ---春庭
        elseif dilemma_key == "psw_dlc7_mulu_chunting" then
            ewnl_ui_display_chunting(faction_name)
            
        ---主动浇灌
        elseif dilemma_key:starts_with("psw_dlc7_chunting_") then
            psw_add_czz_by_jg(faction_name, dilemma_key)
            
        ---守矢神社
        elseif dilemma_key:starts_with("psw_dlc7_mulu_zaomiao_ssss") then
            ewnl_ui_display_ssss(faction_name)
            
        ---守矢神社-功能性效果
        elseif dilemma_key:starts_with("psw_dlc7_zaomiao_ssss_") then
            psw_dlc7_ssss_main_effect(faction_name, dilemma_key)
            
        ---火萤Ⅳ型战略强袭装甲「萨姆」
        elseif dilemma_key:starts_with("psw_dlc7_mulu_firefly") then
            ewnl_ui_display_firefly(faction_name)
            
        ---升级火萤Ⅳ型/完全燃烧
        elseif dilemma_key:starts_with("psw_dlc7_firefly_samu_") then
            psw_dlc7_firefly_samu_effect(faction_name, dilemma_key)
            
        ---基沃托斯 目录
        elseif dilemma_key:starts_with("psw_main_mulu_jwts") then
            ewnl_ui_display_jwts_mulu(faction_name)
            
        ---基沃托斯 其他项目
        elseif dilemma_key:starts_with("psw_dlc7_jwts_") then
            ---查看学生/招募学生/大人的卡片
            if dilemma_key:starts_with("psw_dlc7_jwts_mulu_") then
                psw_dlc7_jwts_stu_drdkp(faction_name, dilemma_key)
            ---抽取学生
            elseif dilemma_key:starts_with("psw_dlc7_jwts_zhaomu_table") then
                psw_dlc7_zhaomu_stu_effect(faction_name)
            ---选择学生
            else
                local zhaomu_pool = psw_main_data.player_data[faction_name].jwts_data.zhaomu_pool
                local zhaomu_pool_num = #zhaomu_pool
                if zhaomu_pool_num > 0 and faction:has_effect_bundle("psw_dlc7_jwts_is_pick_stu") then
                    local student_num = psw_main_data.player_data[faction_name].jwts_data.student_num
                    local student_sx = psw_main_data.player_data[faction_name].jwts_data.student_sx
                    if student_num < student_sx then
                        psw_dlc7_jwts_select_stu(faction_name, dilemma_key)
                    else
                        alice_jwts_pick_fault()
                    end
                end
            end
            
        ---爱梅斯 目录
        elseif dilemma_key:starts_with("psw_dlc7_mulu_ams") then
            ewnl_ui_display_ams_mulu(faction_name)
            
        ---爱梅斯 记忆碎片目录
        elseif dilemma_key:starts_with("psw_dlc7_ams_mulu_shop") then
            ewnl_ui_display_ams_shop(faction_name)
            
        ---爱梅斯 使用记忆碎片
        elseif dilemma_key:starts_with("psw_dlc7_ams_shop_") then
            psw_dlc7_ams_jysp_click_effect(faction_name, dilemma_key)
            
        ---鸣潮 启动
        elseif dilemma_key:starts_with("psw_dlc7_mulu_mc") then
            ewnl_ui_display_mc_qd(faction_name)
        
        ---变奏技能触发
        elseif dilemma_key:starts_with("psw_dlc7_mc_") then
            psw_dlc7_mc_main_bz_effect(faction_name, dilemma_key)
            
        
        ---再动效果
        elseif dilemma_key:starts_with("psw_main_sx_2_zaidong") then
            psw_zaidong_main_effect(faction_name)
            
        ---莉莉卡 目录
        elseif dilemma_key:starts_with("psw_dlc7_mulu_lilika") then
            ewnl_ui_display_lilika_mulu(faction_name)
            
        ---莉莉卡 升级
        elseif dilemma_key:starts_with("psw_dlc7_lilika_") then
            psw_dlc7_lilika_level_up(faction_name, dilemma_key)
            
        ---木精灵 阻止仪式
        elseif dilemma_key:starts_with("psw_dlc7_mw_buff_zzys") then
            cm:trigger_dilemma(faction_name, "dilemma_tf_duoren_legend_tp")
            
        ---雪莉的推理时间 目录
        elseif dilemma_key:starts_with("psw_dlc7_xueli_mulu") then
            if faction:has_effect_bundle("psw_dlc7_xueli_tuili_cd") then
                advice_dlc6_alice_ewnl_crt_cd()
            else
                ewnl_ui_display_xueli_mulu(faction_name)
            end
        ---雪莉的推理时间 魔女目录
        elseif dilemma_key:starts_with("psw_dlc7_xueli_mnsp_sp") then
            ewnl_ui_display_xueli_monv(faction_name)
            
        ---雪莉的推理时间 进行推理
        elseif dilemma_key:starts_with("psw_dlc7_xueli_monv_") then
            psw_dlc7_xueli_tuili_main_effect(faction_name, dilemma_key)
        
        ---菲比 七美德
        elseif dilemma_key:starts_with("psw_dlc7_feibi_mulu") then
            ewnl_ui_display_feibi_qmd(faction_name)
            
        ---菲比 七美德启用效果
        elseif dilemma_key:starts_with("psw_dlc7_feibi_qmd_") then
            psw_dlc7_feibi_qmd_on_effect(faction_name, dilemma_key)
            
        ---三株树 效果
        elseif dilemma_key:starts_with("psw_moyin_ex_szs") then
            
            if faction:has_effect_bundle("psw_moyin_ex_szs_get_cd") then
                advice_dlc6_alice_ewnl_crt_cd()
            else
                common.trigger_soundevent("szs_dtnl")
                psw_aplly_costom_effect_bundle_with_time_hidden("psw_moyin_ex_szs_get_cd", faction, 4)
                psw_main_heal_faction_to_force_all(faction_name, 100)
            end
            
        ---提亚马特 启示之翼 效果
        elseif dilemma_key:starts_with("psw_moyin_ex_tymt") then
            
            if faction:has_effect_bundle("psw_moyin_ex_tymt_get_cd") then
                advice_dlc6_alice_ewnl_crt_cd()
            else
                common.trigger_soundevent("tymt_qszy")
                psw_aplly_costom_effect_bundle_with_time_hidden("psw_moyin_ex_tymt_get_cd", faction, 4)
                psw_main_reheal_xd_juli(faction_name)
            end
            
            
            
        ---赛马娘 目录
        elseif dilemma_key:starts_with("psw_dlc7_saima_mulu") then
            psw_play_dlc_music("chazuo_xl_2")
            ewnl_ui_display_saima_mulu(faction_name)
            
        ---赛马娘 比赛目录
        elseif dilemma_key:starts_with("psw_dlc7_saima_bisai") then
            ewnl_ui_display_saima_bisai_mulu(faction_name)
            
        ---赛马娘 训练项目
        elseif dilemma_key:starts_with("psw_dlc7_saima_") then
            psw_dlc7_saima_xl_effect(faction_name, dilemma_key)
            
            
        -----------------------------------------------
        
                
        end


    end,
    true
)












--------------------------------------------------------------
-----------------------人物升级 -------------------------
-------------------------------------------------------------- 
function psw_main_CharacterRankUp_listner()
    core:remove_listener("psw_main_CharacterRankUp_listner")
    core:add_listener(
    "psw_main_CharacterRankUp_listner",
    "CharacterRankUp",
    function(context)
        local character = context:character();
        local faction = character:faction()
        if faction:is_human() == true then
            return true
        end
    end,
    function(context)
        local character = context:character();
        local faction = character:faction()
        local faction_name = faction:name()
        local rank = character:rank()
        local effect_list = {}
        
        --橘雪莉
        if faction:has_effect_bundle("hero_select_shiki") then
            local xishu = 0.5
            if faction:has_effect_bundle("psw_tf_nor_glmn_zt_effect_bundle") then
                xishu = 1
            end
            local add_num = math.floor(rank * xishu)
            effect_list = {
                {effect = "wh_main_effect_character_stat_weapon_strength", effect_scope = "character_to_character_own", effect_num = add_num},
            }
            
            psw_main_apply_effect_to_character(character, "psw_dlc7_xueli_rankup_effect", 0, effect_list)
        end
    end,
    true
    )
end

-- Override psw_main_pickup to add nil-safe player_data reads for old saves.
local _orig_psw_main_pickup = psw_main_pickup
psw_main_pickup = function(faction_name)
    if psw_ensure_player_data then
        psw_ensure_player_data(faction_name)
    end
    local faction = cm:get_faction(faction_name)
    local xy_xingyun = psw_resource_value(faction, "psw_xingyun")
    local _pd = psw_main_data.player_data[faction_name] or {}
    local psw_ewai_xingyun = _pd.psw_ewai_xingyun or 0
    local main_xingyunzhi = (psw_ewai_xingyun + xy_xingyun)
    if main_xingyunzhi > 25 then
        main_xingyunzhi = 25
    end
    local jishu_ex = _pd.jishu_ex_count or 0
    local jishu_nor = _pd.nor_count or 0
    local ex_count = _pd.ex_count or 0
    local jishu_xuanze = _pd.jishu_xuanze or 3
    psw_aplly_costom_effect_bundle_hidden_fn("psw_yi_pick", faction_name);
    local final_tf_count = ex_count + jishu_nor

    cm:remove_effect_bundle("main_yi_pick", faction_name)

    local ex_jishu = 0

    if final_tf_count >= 99 then
        advice_alice_tf_norsx()
        return
    end

    local is_zhongduan = false
    local zhongduan_name = false
    for i = 1, jishu_xuanze do
        if i == 1 then
            local jishu_mofashaonv = psw_resource_value(faction, "jishu_mofashaonv")
            local psw_moli = psw_resource_value(faction, "psw_moli")
            local psw_jianshu = _pd.psw_jianshu or 0
            local psw_zhixing = _pd.psw_zhixing or 0
            local jishu_jingling = _pd.jishu_jingling or 0
            local psw_xingyun = psw_resource_value(faction, "psw_xingyun")
            local lmyx_yinguo_jishu = _pd.lmyx_yinguo_jishu or 0
            local psw_meili = _pd.psw_meili or 0

            local zd_num_10 = 10
            local zd_num_4 = 4
            if faction:has_effect_bundle("set_psw_tf_sp_xlfh") then
                zd_num_10 = 5
                zd_num_4 = 2
            end

            local ex_xy10 = psw_xingyun >= zd_num_10 and not psw_faction_has_effect_bundle(faction_name, "set_main_xxdqj_1") and jishu_ex <= 1
            local ex_ml10 = psw_moli >= zd_num_10 and not psw_faction_has_effect_bundle(faction_name, "set_main_zzhgt_1") and jishu_ex <= 1
            local ex_jingling = jishu_jingling >= zd_num_4 and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_you_ex") and jishu_ex <= 1
            local ex_jianshu = psw_jianshu >= zd_num_10 and not psw_faction_has_effect_bundle(faction_name, "set_main_qlwh_1") and jishu_ex <= 1
            local ex_zhixing10 = psw_zhixing >= zd_num_10 and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_pql") and jishu_ex <= 1
            local ex_meili10 = psw_meili >= zd_num_10 and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_shaonv") and jishu_ex <= 1
            local ex_mfsn = jishu_mofashaonv >= zd_num_4 and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_xzwlsy") and jishu_ex <= 1
            local ex_yhzl = lmyx_yinguo_jishu >= 10 and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_yhzl_1") and jishu_ex <= 1
            local ex_xzwlsy_xdzk = psw_faction_has_effect_bundle(faction_name, "xzwlsy_blxdzk_install") and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_xzwlsy")
            local ex_baiye_100 = psw_faction_has_effect_bundle(faction_name, "psw_tf_nor_canmou_baiye100_effect") and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_sp_baiye")
            local nor_mmyzt = psw_faction_has_effect_bundle(faction_name, "psw_tf_nor_baizi_abds_hftz") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_mmyzt")

            is_zhongduan = ex_xy10 or ex_ml10 or ex_jingling or ex_jianshu or ex_mfsn or ex_zhixing10 or ex_yhzl or ex_xzwlsy_xdzk or ex_baiye_100 or nor_mmyzt or ex_meili10

            if ex_xy10 then
                zhongduan_name = "psw_tf_sp_xxdqj_ex"
            elseif ex_jingling then
                zhongduan_name = "psw_tf_ex_you_ex"
            elseif ex_zhixing10 then
                zhongduan_name = "psw_tf_ex_pql"
            elseif ex_meili10 then
                zhongduan_name = "psw_tf_ex_shaonv"
            elseif ex_mfsn or ex_xzwlsy_xdzk then
                zhongduan_name = "psw_tf_ex_xzwlsy"
            elseif ex_ml10 then
                zhongduan_name = "psw_tf_ex_zzhgt_ex"
            elseif ex_jianshu then
                zhongduan_name = "psw_tf_ex_qlwh_ex"
            elseif ex_yhzl then
                zhongduan_name = "psw_tf_ex_yhzl_1"
            elseif ex_baiye_100 then
                zhongduan_name = "psw_tf_sp_baiye"
                cm:remove_effect_bundle("psw_tf_nor_canmou_baiye100_effect", faction_name)
            elseif nor_mmyzt then
                zhongduan_name = "psw_tf_nor_mmyzt"
                cm:remove_effect_bundle("psw_tf_nor_baizi_abds_hftz", faction_name)
            end
        end

        local random_number = cm:random_number(100, 1)
        if is_zhongduan and i == 1 then
            psw_main_ex_pool(faction_name, i, true, zhongduan_name)
        elseif ((random_number > main_xingyunzhi and not (faction:has_effect_bundle("set_qiyuan_100ex") or psw_faction_has_effect_bundle(faction_name, "blhx_xzmf_3_use"))) or (jishu_ex == 2) or faction:has_effect_bundle("set_qiyuan_100zt")) then
            psw_main_nor_pool(faction_name, i)
        elseif ((random_number <= main_xingyunzhi) and jishu_ex <= 1) or ((faction:has_effect_bundle("set_qiyuan_100ex") or psw_faction_has_effect_bundle(faction_name, "blhx_xzmf_3_use")) and jishu_ex <= 1) then
            psw_main_ex_pool(faction_name, i, false, false)
            ex_jishu = ex_jishu + 1
        end
    end

    local index_sound
    local tf_get_sound
    if ex_jishu >= 1 then
        index_sound = cm:random_number(#ex_get_sound)
        tf_get_sound = ex_get_sound[index_sound]
        cm:callback(function()
        common.trigger_soundevent(tf_get_sound)
        end, 0.1)
    elseif ex_jishu == 0 then
        index_sound = cm:random_number(#nor_get_sound)
        tf_get_sound = nor_get_sound[index_sound]
        cm:callback(function()
        common.trigger_soundevent(tf_get_sound)
        end, 0.1)
    end
end

