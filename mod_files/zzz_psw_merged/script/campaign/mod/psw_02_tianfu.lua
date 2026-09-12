
local pswyoFactionName

local ui_root

--local kroqgar_alignment_button

local ui_tooltip
local ui_button
local ui_button_image_path


local can_repick = true 
local pickup_use = -1


---

-- LIZARDMEN STRINGS

local psw_tooltip = "psw_button_tooltip_key"
local psw_button = "psw_mazdamundi_dilemma_button"
local psw_button_image_path = "ui/skins/wh2_main_lizardmen/psw_chouka.png"

-- 兜底工具：安全调用回调，记录错误但不中断
local function psw_pcall_wrapper(fn)
    return function(context)
        local ok, err = pcall(fn, context)
        if not ok then
            out("### PSW SAFE ERROR: " .. tostring(err) .. " ###")
        end
        return ok
    end
end

-- 兜底工具：安全读取资源，缺失时返回 0
function psw_resource_value(faction, resource_key)
    if not faction or faction:is_null_interface() then return 0 end
    local rm = faction:pooled_resource_manager()
    if not rm then return 0 end
    local r = rm:resource(resource_key)
    if not r or r:is_null_interface() then return 0 end
    return r:value()
end

local psw_main_default_player_data = {
            reward_level = nil,
            reward_culture = nil,
            previous_reward_level = nil,
            previous_reward_culture = nil,
            psw_ceshi_jishu = 0,
            psw_main_renshu = 0,
            set_psw_hero_select = false,
            hero_have_select = false,
            yx_subtype = nil,
            psw_ewai_xingyun = 8,
            nor_count = 0,
            jishu_jiushizhu = 0,
            jishu_jingling = 0,
            ejtzh_jiyizhi = 100,
            jishu_lmyx_wurandu = 0,
            jishu_lmyx_lunhui = 0,
            region_name = nil,
            sllh_mzz_dqcs = 1,
            edu_zzcg_jishu = 0,
            edu_love = 0,
            jishu_ex_count = 0,
            ex_count = 0,
            psw_jianshu = 0,
            psw_meili = 0,
            set_saved_value = 0,
            psw_zhixing = 0,
            psw_zhiyu = 0,
            psw_kxct = 0,
            jishu_miansi = 0,
            hong_count = 0,
            jishu_bing = 0,
            jishu_long = 0,
            jishu_shenhai = 0,
            jishu_shen = 0,
            mika_ssy_tf_jishu = 0,
            ybbb_jishu_zhongzu = 1,
            jishu_jianniang = 0,
            jishu_jiyi = 0,
            jishu_alws = 0,
            hgd_djs = 0,
            jishu_xilie_ldse = 0,
            jishu_xilie_jly = 0,
            jishu_xilie_jwts = 0,
            jishu_xilie_ldd = 0,
            jishu_xilie_sfly = 0,
            jishu_xilie_hxx = 0,
            jishu_xuanze = 3,
            qwsn_jishu = 0,
            lmyx_yeli_jishu = 0,
            yinguo_effect_num = 0,
            lmyx_yinguo_jishu = 0,
            count_moli = 0,
            min_yiwu_level = 1,
            psw_gjyiwu_lcgl = 0,
            jishu_geji = 0,
            psw_battle_huifu = 0,
            ayty_add_shenxing = 0,
            jishu_ayty = 0,
            ayty_add_miansi = 0,
            jishu_monv = 0,
            alice_game_qz = 0,
            shayou_bkz = 0,
            jiyizhi_gxj = 0,
            wrd_yjh_effect_num = 0,
            add_yjh_wurandu = 0,
            lhbs_wurandu = 0,
            niao_huohai = 0,
            ygn_qszy = 0,
            yiwu_xzc_sc = 0,
            psw_yiwu_xzc_hh = 0,
            syd_ro_wzd = 10,
            fuxuan_bs_level = 1,
            fuxuan_bs_jingyan = 0,
            pql_huo_level = 0,
            pql_shui_level = 0,
            pql_mu_level = 0,
            pql_jin_level = 0,
            pql_tu_level = 0,
            pql_ri_level = 0,
            pql_yue_level = 0,
            yly_zhijie = 0,
            yln_mlcn = 0,
            yln_mnrj_yeshu = 0,
            yln_jishu_yaocao = 0,
            yln_jishu_bihu = 0,
            yln_jishu_zty = 0,
            yln_jishu_zhizhu = 0,
            psw_yln_jishu_mogu = 0,
            swyh_install_jishu = 0,
            swyh_install_smxg_jishu = 0,
            swyh_jishu_ssz = 0,
            jishu_xilie_qnkx = 0,
            psw_shendou_add_qsx = 0,
            a_g_province_qz = 0,
            a_g_rank_qz = 0,
            a_g_province_qz_has_add = 0,
            a_g_rank_qz_has_add = 0,
            fzdyg_jishu = 0,
            psw_shayou_qsx = 0,
            dtnl_gxj_jishu = 0,
            a_g_character_x = 0,
            a_g_character_y = 0,
            a_g_province_start = 0,
            a_g_faction_rank_start = 0,
            a_g_xz_turn = 0,
            syd_pl_jishu = 0,
            fuxuan_dgjs_deadtime = 0,
            fuxuan_zb_cishu = 0,
            fuxuan_jishen = 0,
            beita_ayty_qsx = 0,
            pql_bdd_tsg_jishu = 0,
            pql_shui_zhiyu_add = 0,
            qiyana_qinshi_jishu = 0,
            yln_wsss_complete_turn = 0,
            gxj_qy_fc_name = nil,
            mssyx_tsbh_num = 0,
            btzz_qsx_add = 0,
            fuxuan_daji_jishu = 0,
            fuxuan_daji_turn = 0,
            fuxuan_xiaoji_turn = 0,
            fuxuan_daxiong_turn = 0,
            fuxuan_daxiong_xy = 0,
            xxdqj_qjjs = 0,
            bszzw_mlcl = 0,
            gsxs_turn = 0,
            thwg_turn = 0,
            thwg_duration = 0,
            thwg_zhiyu_add = 0,
            mssyx_tkdzf_turn1 = 0,
            mssyx_tkdzf_turn2 = 0,
            mssyx_tkdzf_turn3 = 0,
            mssyx_tkdzf_turn4 = 0,
            hb_cd_turn = 0,
            jws_boss_time = 0,
            spider_boss_time = 0,
            syjxg_boss_time = 0,
            lyzm_boss_time = 0,
            ksz_boss_time = 0,
            ejtzh_mscs = 0,
            mika_ydy_jishu = 0,
            mika_ydr_jishu = 0,
            mika_rys_jishu = 0,
            mika_bmbx_jishu = 0,
            slmmn_abge_wszs_jishu = 0,
            szhx_zhiyu = 0,
            zdyx_sx = 0,
            pql_add_moli = 0,
            jsdjy_zy = 0,
            zzhgt_sx = 0,
            bass_rgqh_li = 0,
            faction_leader_x = 0,
            faction_leader_y = 0,
            leader_legend_x = 0,
            ledear_legend_y = 0,
            alice_game_battler_turn = 0,
            qb_cw_mfsn_jishu = 0,
            fia_xiaohao_js = 0,
            sywh_faction = nil,
            yls_faction = nil,
            skd_faction = nil,
            ybbb_faction = nil,
            ejtzh_get_turn = 0,
            fia_ledear_rank = 0,
            bmm_faction = nil,
            psw_tf_nor_syd_rocj_tuibu_jishu = 0,
            psw_tf_nor_syd_rocj_xiongbu_jishu = 0,
            psw_tf_nor_syd_rocj_wanbu_jishu = 0,
            psw_tf_nor_syd_rocj_toubu_jishu = 0,
            psw_tf_nor_syd_fatiao_jishu = 0,
            shayou_get_turn = 0,
            diya_get_turn = 0,
            jishu_huihe_chizi = 0,
            kqrn_hgd = 0,
            youxiang_hgd = 0,
            yls_thd = 0,
            skd_thd = 0,
            blst_love = 0,
            crt_bundle_jishu = 0,
            fia_main_js = 0,
            fia_cz1_js = 0,
            fia_cz2_js = 0,
            fia_cz3_js = 0,
            skd_gsls_cs = 0,
            alice_ledear_rank = 0,
            alice_cz1_js = 0,
            alice_cz2_js = 0,
            alice_cz3_js = 0,
            alice_cz4_js = 0,
            alice_cz5_js = 0,
            alice_cz6_js = 0,
            crt_alice_bundle_jishu = 0,
            bass_jxcs = 0,
            bass_zdqh_rg = 3,
            amly_clks_jishu = 0,
            amly_yjqh_jishu_hh = 5,
            jishu_xsdjy_hh = 0,
            azsyz_zihui_jishu = 0,
            azsyz_jiyizhi = 0,
            psw_alice_game_jdfqz_name = nil,
            bshu_hdl_complete = false,
            ast_mwsj_jishu = 0,
            ast_sjjf_complete = false,
            kxct_apply_num = 0,
            war_player_num = 0,
            gxj_zhuren_fc_name = nil,
            qb_mnh_jdjishu = 0,
            qb_shenxing_get = 0,
            tianqi_ms_level = 0,
            tianqi_ms_tf_select = false,
            tianqi_ms_tf_key = nil,
            hp_sx = 10,
            hp_crt = 10,
            atk_min = 1,
            atk_max = 1,
            def_min = 1,
            def_max = 1,
            dmg_num = 0,
            toudian_num = 1,
            tfmw_buff = {
                ["psw_dlc7_buff_mlyd"] = {ritual_key = "psw_dlc7_buff_mlyd", num = 0},
                ["psw_dlc7_buff_jiangu"] = {ritual_key = "psw_dlc7_buff_jiangu", num = 0},
                ["psw_dlc7_buff_jiejie"] = {ritual_key = "psw_dlc7_buff_jiejie", num = 0},
                ["psw_dlc7_buff_peiluoluo"] = {ritual_key = "psw_dlc7_buff_peiluoluo", num = 0},
                ["psw_dlc7_buff_xielunyan"] = {ritual_key = "psw_dlc7_buff_xielunyan", num = 0},
                ["psw_dlc7_buff_liuhua_jingjie"] = {ritual_key = "psw_dlc7_buff_liuhua_jingjie", num = 0},
                ["psw_dlc7_buff_emt_swhg"] = {ritual_key = "psw_dlc7_buff_emt_swhg", num = 0},
                ["psw_dlc7_buff_xiangcao_ycbx"] = {ritual_key = "psw_dlc7_buff_xiangcao_ycbx", num = 0},
                ["psw_dlc7_buff_firefly_wqrs"] = {ritual_key = "psw_dlc7_buff_firefly_wqrs", num = 0},
                ["psw_dlc7_buff_zhiyu"] = {ritual_key = "psw_dlc7_buff_zhiyu", num = 0},
                ["psw_dlc7_buff_klt_jmz"] = {ritual_key = "psw_dlc7_buff_klt_jmz", num = 0},
                ["psw_dlc7_buff_mslbd"] = {ritual_key = "psw_dlc7_buff_mslbd", num = 0},
                ["psw_dlc7_buff_klastl_byst"] = {ritual_key = "psw_dlc7_buff_klastl_byst", num = 0},
            },
            under_hp0_protect = {
                is_under_hp0_protect = false,
                turn = 0,
            },
            repick_cost = 1,
            free_repick_num = 0,
            crt_card = {
                ["psw_jyjj_sx_main_fangyu_1"] = {card_key = "psw_jyjj_sx_main_fangyu_1", card_num = 0, cd = -1, level = 1, is_unlock = true},
                ["psw_jyjj_sx_main_fangyu_2"] = {card_key = "psw_jyjj_sx_main_fangyu_2", card_num = 0, cd = -1, level = 2, is_unlock = true},
                ["psw_jyjj_sx_main_fangyu_3"] = {card_key = "psw_jyjj_sx_main_fangyu_3", card_num = 0, cd = -1, level = 3, is_unlock = true},
                ["psw_jyjj_sx_main_fangyu_4"] = {card_key = "psw_jyjj_sx_main_fangyu_4", card_num = 0, cd = -1, level = 4, is_unlock = true},
                ["psw_jyjj_sx_main_fangyu_5"] = {card_key = "psw_jyjj_sx_main_fangyu_5", card_num = 0, cd = -1, level = 5, is_unlock = true},
                ["psw_jyjj_sx_main_gongji_1"] = {card_key = "psw_jyjj_sx_main_gongji_1", card_num = 0, cd = -1, level = 1, is_unlock = true},
                ["psw_jyjj_sx_main_gongji_2"] = {card_key = "psw_jyjj_sx_main_gongji_2", card_num = 0, cd = -1, level = 2, is_unlock = true},
                ["psw_jyjj_sx_main_gongji_3"] = {card_key = "psw_jyjj_sx_main_gongji_3", card_num = 0, cd = -1, level = 3, is_unlock = true},
                ["psw_jyjj_sx_main_gongji_4"] = {card_key = "psw_jyjj_sx_main_gongji_4", card_num = 0, cd = -1, level = 4, is_unlock = true},
                ["psw_jyjj_sx_main_gongji_5"] = {card_key = "psw_jyjj_sx_main_gongji_5", card_num = 0, cd = -1, level = 5, is_unlock = true},
                ["psw_jyjj_xg_main_moli_1"] = {card_key = "psw_jyjj_xg_main_moli_1", card_num = 0, cd = -1, level = 1, is_unlock = true},
                ["psw_jyjj_xg_main_moli_2"] = {card_key = "psw_jyjj_xg_main_moli_2", card_num = 0, cd = -1, level = 2, is_unlock = true},
                ["psw_jyjj_xg_main_moli_3"] = {card_key = "psw_jyjj_xg_main_moli_3", card_num = 0, cd = -1, level = 3, is_unlock = true},
                ["psw_jyjj_xg_main_moli_4"] = {card_key = "psw_jyjj_xg_main_moli_4", card_num = 0, cd = -1, level = 4, is_unlock = true},
                ["psw_jyjj_xg_main_zhiyu_1"] = {card_key = "psw_jyjj_xg_main_zhiyu_1", card_num = 0, cd = -1, level = 1, is_unlock = true},
                ["psw_jyjj_xg_main_zhiyu_2"] = {card_key = "psw_jyjj_xg_main_zhiyu_2", card_num = 0, cd = -1, level = 2, is_unlock = true},
                ["psw_jyjj_xg_main_zhiyu_3"] = {card_key = "psw_jyjj_xg_main_zhiyu_3", card_num = 0, cd = -1, level = 3, is_unlock = true},
                ["psw_jyjj_xg_main_zhiyu_4"] = {card_key = "psw_jyjj_xg_main_zhiyu_4", card_num = 0, cd = -1, level = 4, is_unlock = true},
                ["psw_jyjj_xg_main_heijian"] = {card_key = "psw_jyjj_xg_main_heijian", card_num = 0, cd = -1, level = 1, is_unlock = true},
                ["psw_jyjj_xg_main_xushu"] = {card_key = "psw_jyjj_xg_main_xushu", card_num = 0, cd = -1, level = 2, is_unlock = true},
                ["psw_jyjj_xg_main_mlbf"] = {card_key = "psw_jyjj_xg_main_mlbf", card_num = 0, cd = -1, level = 3, is_unlock = true},
                ["psw_jyjj_xg_main_clzy"] = {card_key = "psw_jyjj_xg_main_clzy", card_num = 0, cd = -1, level = 3, is_unlock = true},
                ["psw_jyjj_xg_main_mhpy"] = {card_key = "psw_jyjj_xg_main_mhpy", card_num = 0, cd = -1, level = 3, is_unlock = true},
                ["psw_jyjj_xd_main_jrdf"] = {card_key = "psw_jyjj_xd_main_jrdf", card_num = 0, cd = -1, level = 3, is_unlock = true},
                ["psw_jyjj_xg_main_nvpu"] = {card_key = "psw_jyjj_xg_main_nvpu", card_num = 0, cd = -1, level = 3, is_unlock = true},
                ["psw_jyjj_xg_main_poyin"] = {card_key = "psw_jyjj_xg_main_poyin", card_num = 0, cd = -1, level = 3, is_unlock = true},
                ["psw_jyjj_xd_main_tyms"] = {card_key = "psw_jyjj_xd_main_tyms", card_num = 0, cd = -1, level = 4, is_unlock = true},
                ["psw_jyjj_xg_main_cisi"] = {card_key = "psw_jyjj_xg_main_cisi", card_num = 0, cd = -1, level = 4, is_unlock = true},
                ["psw_jyjj_xg_main_caibao"] = {card_key = "psw_jyjj_xg_main_caibao", card_num = 0, cd = -1, level = 4, is_unlock = true},
                ["psw_jyjj_xg_main_feileishen"] = {card_key = "psw_jyjj_xg_main_feileishen", card_num = 0, cd = -1, level = 5, is_unlock = true},
                ["psw_jyjj_xg_main_chelun"] = {card_key = "psw_jyjj_xg_main_chelun", card_num = 0, cd = -1, level = 4, is_unlock = true},
                ["psw_jyjj_xd_main_yuzhi"] = {card_key = "psw_jyjj_xd_main_yuzhi", card_num = 0, cd = -1, level = 5, is_unlock = true},
                ["psw_jyjj_xg_main_zhongli"] = {card_key = "psw_jyjj_xg_main_zhongli", card_num = 0, cd = -1, level = 5, is_unlock = true},
                ["psw_jyjj_xg_main_jianpiao"] = {card_key = "psw_jyjj_xg_main_jianpiao", card_num = 0, cd = -1, level = 3, is_unlock = true},
                ["psw_jyjj_sx_firefly_rsdj"] = {card_key = "psw_jyjj_sx_firefly_rsdj", card_num = 0, cd = -1, level = 5, is_unlock = false},
                ["psw_jyjj_sx_jinxi_yishi_1"] = {card_key = "psw_jyjj_sx_jinxi_yishi_1", card_num = 0, cd = -1, level = 1, is_unlock = false},
                ["psw_jyjj_sx_jinxi_yishi_2"] = {card_key = "psw_jyjj_sx_jinxi_yishi_2", card_num = 0, cd = -1, level = 2, is_unlock = false},
                ["psw_jyjj_sx_jinxi_yishi_3"] = {card_key = "psw_jyjj_sx_jinxi_yishi_3", card_num = 0, cd = -1, level = 2, is_unlock = false},
                ["psw_jyjj_sx_jinxi_yishi_4"] = {card_key = "psw_jyjj_sx_jinxi_yishi_4", card_num = 0, cd = -1, level = 3, is_unlock = false},
                ["psw_jyjj_sx_jplr_jydsjh"] = {card_key = "psw_jyjj_sx_jplr_jydsjh", card_num = 0, cd = -1, level = 5, is_unlock = false},
                ["psw_jyjj_sx_klt_blmx"] = {card_key = "psw_jyjj_sx_klt_blmx", card_num = 0, cd = -1, level = 3, is_unlock = false},
                ["psw_jyjj_sx_klt_swcc"] = {card_key = "psw_jyjj_sx_klt_swcc", card_num = 0, cd = -1, level = 4, is_unlock = false},
                ["psw_jyjj_sx_tsg_yy"] = {card_key = "psw_jyjj_sx_tsg_yy", card_num = 0, cd = -1, level = 3, is_unlock = false},
                ["psw_jyjj_sx_xmy_xlhxcd"] = {card_key = "psw_jyjj_sx_xmy_xlhxcd", card_num = 0, cd = -1, level = 3, is_unlock = false},
                ["psw_jyjj_sx_yozi_cqbns"] = {card_key = "psw_jyjj_sx_yozi_cqbns", card_num = 0, cd = -1, level = 1, is_unlock = false},
                ["psw_jyjj_sx_yozi_gzywl"] = {card_key = "psw_jyjj_sx_yozi_gzywl", card_num = 0, cd = -1, level = 3, is_unlock = false},
                ["psw_jyjj_sx_yozi_kslbkm"] = {card_key = "psw_jyjj_sx_yozi_kslbkm", card_num = 0, cd = -1, level = 2, is_unlock = false},
                ["psw_jyjj_xd_anne_jdyl"] = {card_key = "psw_jyjj_xd_anne_jdyl", card_num = 0, cd = -1, level = 4, is_unlock = false},
                ["psw_jyjj_xd_feibi_jzh"] = {card_key = "psw_jyjj_xd_feibi_jzh", card_num = 0, cd = -1, level = 3, is_unlock = false},
                ["psw_jyjj_xd_feibi_zhudao"] = {card_key = "psw_jyjj_xd_feibi_zhudao", card_num = 0, cd = -1, level = 2, is_unlock = false},
                ["psw_jyjj_xd_klt_sizhao"] = {card_key = "psw_jyjj_xd_klt_sizhao", card_num = 0, cd = -1, level = 3, is_unlock = false},
                ["psw_jyjj_xd_kokoro_jlzdy"] = {card_key = "psw_jyjj_xd_kokoro_jlzdy", card_num = 0, cd = -1, level = 5, is_unlock = false},
                ["psw_jyjj_xd_mingren_lxw"] = {card_key = "psw_jyjj_xd_mingren_lxw", card_num = 0, cd = -1, level = 2, is_unlock = false},
                ["psw_jyjj_xd_mingren_xflxw"] = {card_key = "psw_jyjj_xd_mingren_xflxw", card_num = 0, cd = -1, level = 4, is_unlock = false},
                ["psw_jyjj_xd_weilinai_xxhzf"] = {card_key = "psw_jyjj_xd_weilinai_xxhzf", card_num = 0, cd = -1, level = 4, is_unlock = false},
                ["psw_jyjj_xd_xiaoye_shifu"] = {card_key = "psw_jyjj_xd_xiaoye_shifu", card_num = 0, cd = -1, level = 4, is_unlock = false},
                ["psw_jyjj_xd_xingye_sqss"] = {card_key = "psw_jyjj_xd_xingye_sqss", card_num = 0, cd = -1, level = 2, is_unlock = false},
                ["psw_jyjj_xd_xmy_rpg"] = {card_key = "psw_jyjj_xd_xmy_rpg", card_num = 0, cd = -1, level = 5, is_unlock = false},
                ["psw_jyjj_xd_yly_smck"] = {card_key = "psw_jyjj_xd_yly_smck", card_num = 0, cd = -1, level = 3, is_unlock = false},
                ["psw_jyjj_xd_yozi_qxwh"] = {card_key = "psw_jyjj_xd_yozi_qxwh", card_num = 0, cd = -1, level = 4, is_unlock = false},
                ["psw_jyjj_xd_zaomiao_hsfkzr"] = {card_key = "psw_jyjj_xd_zaomiao_hsfkzr", card_num = 0, cd = -1, level = 5, is_unlock = false},
                ["psw_jyjj_xd_zaomiao_ql"] = {card_key = "psw_jyjj_xd_zaomiao_ql", card_num = 0, cd = -1, level = 4, is_unlock = false},
                ["psw_jyjj_xd_zaomiao_xl"] = {card_key = "psw_jyjj_xd_zaomiao_xl", card_num = 0, cd = -1, level = 4, is_unlock = false},
                ["psw_jyjj_xd_zaomiao_ywzjy"] = {card_key = "psw_jyjj_xd_zaomiao_ywzjy", card_num = 0, cd = -1, level = 4, is_unlock = false},
                ["psw_jyjj_xd_zhu_guangyu"] = {card_key = "psw_jyjj_xd_zhu_guangyu", card_num = 0, cd = -1, level = 2, is_unlock = false},
                ["psw_jyjj_xd_zuozhu_jjtm"] = {card_key = "psw_jyjj_xd_zuozhu_jjtm", card_num = 0, cd = -1, level = 3, is_unlock = false},
                ["psw_jyjj_xg_aly_yjyh"] = {card_key = "psw_jyjj_xg_aly_yjyh", card_num = 0, cd = -1, level = 4, is_unlock = false},
                ["psw_jyjj_xg_ams_ghzy"] = {card_key = "psw_jyjj_xg_ams_ghzy", card_num = 0, cd = -1, level = 3, is_unlock = false},
                ["psw_jyjj_xg_ams_smys"] = {card_key = "psw_jyjj_xg_ams_smys", card_num = 0, cd = -1, level = 5, is_unlock = false},
                ["psw_jyjj_xg_ams_yjxs"] = {card_key = "psw_jyjj_xg_ams_yjxs", card_num = 0, cd = -1, level = 5, is_unlock = false},
                ["psw_jyjj_xg_anne_gyzmd"] = {card_key = "psw_jyjj_xg_anne_gyzmd", card_num = 0, cd = -1, level = 4, is_unlock = false},
                ["psw_jyjj_xg_anne_zybj"] = {card_key = "psw_jyjj_xg_anne_zybj", card_num = 0, cd = -1, level = 4, is_unlock = false},
                ["psw_jyjj_xg_bcjh_bqtc"] = {card_key = "psw_jyjj_xg_bcjh_bqtc", card_num = 0, cd = -1, level = 4, is_unlock = false},
                ["psw_jyjj_xg_feibi_guanghui"] = {card_key = "psw_jyjj_xg_feibi_guanghui", card_num = 0, cd = -1, level = 4, is_unlock = false},
                ["psw_jyjj_xg_feibi_zxgmzs"] = {card_key = "psw_jyjj_xg_feibi_zxgmzs", card_num = 0, cd = -1, level = 3, is_unlock = false},
                ["psw_jyjj_xg_feixiao_gwzz"] = {card_key = "psw_jyjj_xg_feixiao_gwzz", card_num = 0, cd = -1, level = 5, is_unlock = false},
                ["psw_jyjj_xg_feixiao_kjfl"] = {card_key = "psw_jyjj_xg_feixiao_kjfl", card_num = 0, cd = -1, level = 5, is_unlock = false},
                ["psw_jyjj_xg_feixiao_xsqj"] = {card_key = "psw_jyjj_xg_feixiao_xsqj", card_num = 0, cd = -1, level = 5, is_unlock = false},
                ["psw_jyjj_xg_firefly_fyzh"] = {card_key = "psw_jyjj_xg_firefly_fyzh", card_num = 0, cd = -1, level = 3, is_unlock = false},
                ["psw_jyjj_xg_jinxi_jlpk"] = {card_key = "psw_jyjj_xg_jinxi_jlpk", card_num = 0, cd = -1, level = 5, is_unlock = false},
                ["psw_jyjj_xg_jinxi_snfm"] = {card_key = "psw_jyjj_xg_jinxi_snfm", card_num = 0, cd = -1, level = 4, is_unlock = false},
                ["psw_jyjj_xg_klt_zsyz"] = {card_key = "psw_jyjj_xg_klt_zsyz", card_num = 0, cd = -1, level = 4, is_unlock = false},
                ["psw_jyjj_xg_ktll_gzjq"] = {card_key = "psw_jyjj_xg_ktll_gzjq", card_num = 0, cd = -1, level = 4, is_unlock = false},
                ["psw_jyjj_xg_lilika_nshf"] = {card_key = "psw_jyjj_xg_lilika_nshf", card_num = 0, cd = -1, level = 3, is_unlock = false},
                ["psw_jyjj_xg_lilika_zhufu"] = {card_key = "psw_jyjj_xg_lilika_zhufu", card_num = 0, cd = -1, level = 5, is_unlock = false},
                ["psw_jyjj_xg_mali_chu"] = {card_key = "psw_jyjj_xg_mali_chu", card_num = 0, cd = -1, level = 4, is_unlock = false},
                ["psw_jyjj_xg_qiesi_qyd"] = {card_key = "psw_jyjj_xg_qiesi_qyd", card_num = 0, cd = -1, level = 3, is_unlock = false},
                ["psw_jyjj_xg_xiaochun_sqzz"] = {card_key = "psw_jyjj_xg_xiaochun_sqzz", card_num = 0, cd = -1, level = 3, is_unlock = false},
                ["psw_jyjj_xg_xingye_yzgj"] = {card_key = "psw_jyjj_xg_xingye_yzgj", card_num = 0, cd = -1, level = 4, is_unlock = false},
                ["psw_jyjj_xg_xnm_ycks"] = {card_key = "psw_jyjj_xg_xnm_ycks", card_num = 0, cd = -1, level = 3, is_unlock = false},
                ["psw_jyjj_xg_yozi_wmdmx"] = {card_key = "psw_jyjj_xg_yozi_wmdmx", card_num = 0, cd = -1, level = 5, is_unlock = false},
                ["psw_jyjj_xg_zaomiao_hf"] = {card_key = "psw_jyjj_xg_zaomiao_hf", card_num = 0, cd = -1, level = 3, is_unlock = false},
                ["psw_jyjj_xg_zaomiao_smg"] = {card_key = "psw_jyjj_xg_zaomiao_smg", card_num = 0, cd = -1, level = 5, is_unlock = false},
                ["psw_jyjj_xg_zuozhu_tstz"] = {card_key = "psw_jyjj_xg_zuozhu_tstz", card_num = 0, cd = -1, level = 3, is_unlock = false},
                ["psw_jyjj_xg_sar_hdll"] = {card_key = "psw_jyjj_xg_sar_hdll", card_num = 0, cd = -1, level = 5, is_unlock = false},
                ["psw_jyjj_xd_delisha_gyzy"] = {card_key = "psw_jyjj_xd_delisha_gyzy", card_num = 0, cd = -1, level = 3, is_unlock = false},
                ["psw_jyjj_xg_xinghui_shxm"] = {card_key = "psw_jyjj_xg_xinghui_shxm", card_num = 0, cd = -1, level = 3, is_unlock = false},
                ["psw_jyjj_xg_shaonv_chuhui"] = {card_key = "psw_jyjj_xg_shaonv_chuhui", card_num = 0, cd = -1, level = 3, is_unlock = false},
                ["psw_jyjj_xg_xlfh_jhly"] = {card_key = "psw_jyjj_xg_xlfh_jhly", card_num = 0, cd = -1, level = 4, is_unlock = false},
                ["psw_jyjj_xg_xlfh_qishi"] = {card_key = "psw_jyjj_xg_xlfh_qishi", card_num = 0, cd = -1, level = 5, is_unlock = false},
                ["psw_jyjj_xg_feilin_tuxi"] = {card_key = "psw_jyjj_xg_feilin_tuxi", card_num = 0, cd = -1, level = 5, is_unlock = false},
            },
            player_tili_sx = 4,
            player_tili_crt = 4,
            card_use_num_sx = 1,
            card_use_num_crt = 1,
            temp_atk = {},
            temp_def = {},
            shop_refresh_num = 4,
            is_on_shop = false,
            shop_card_pool = {},
            have_open_shop = false,
            gmsj_purchase_num = 2,
            jyjj_sx_test_hh = true,
            jyjj_num_is_sx = false,
            jishu_xilie_abds = 0,
            jishu_vtuber = 0,
            jishu_tianshi = 0,
            jishu_bhdll = 0,
            baihua_sx_jishu_pool = 0,
            jishu_tangtang_ai = 0,
            ctj_fensi_factions = {},
            jishu_fuzhai = 0,
            jishu_fuzhai_have_pay = 0,
            round_gmsj_reward = 1,
            round_jyjj_reward = 2,
            mali_fensi = 0,
            jishu_yxkfb = 0,
            jishu_guangyu = 0,
            turn_jyjj_reward = 0,
            jishu_delisha_xueyin = 0,
            gxj_huifu_have_get = 0,
            delisha_xueyin_huifu_get = 0,
            liuhua_card_pool = {},
            qiesi_gysyz_num = 0,
            jishu_zgn = 0,
            xnm_fensi = 0,
            xfl_dl = 0,
            xfl_have_get_dl_xg1 = 0,
            xfl_have_get_dl_xg2 = 0,
            bkh_czz = 0,
            hehuan_czz = 0,
            mec_czz = 0,
            xiangcao_czz = 0,
            tsh_czz = 0,
            chunting_level = 1,
            chunting_exp = 0,
            chunting_zd_jg_cishu = 1,
            chunting_zd_cishu_crt = 1,
            yzs_jh_num = 1,
            yzs_cjh_num = 1,
            yzs_lianji_num = 0,
            nnk_num = 0,
            miao_xy_num = 0,
            miao_ss_level = 1,
            miao_money = 0,
            miao_money_level = 1,
            miao_jj_level = 1,
            miao_xysj_num = 0,
            miao_xy_sx = 5000,
            miao_hv_sj_xy = 0,
            miao_xingyun_add = 0,
            miao_qj_pool = {
                qj_smg = false,
                qj_hadsf = false,
                qj_bzdkx = false,
                qj_mxzqj = false,
                qj_kxhhzy = false,
                qj_shsyfr = false,
                qj_blsqlz = false,
                qj_wugu = false,
                qj_huhuansf = false,
                qj_bbzsf = false,
            },
            miao_qj_cf_num = 0,
            zaidong_num = 0,
            final_point = 0,
            baiye_fac_name = nil,
            hgd_tsg = 0,
            tsg_sp_jishu = {
                num = 0,
                round = 0,
            },
            firefly_feph_get_num = 0,
            firefly_num = {
                xhsp = 3,---星核碎片
                samu_psbf = 0, ---萨姆等级---
                samu_zxzj = 0,
                samu_gzhx = 0,------
                samu_psbf_atk = 0,---萨姆属性上限---
                samu_psbf_def = 0,
                samu_zxzj_tsbh = 0,
                samu_gzhx_qmb = 0,------
                fyph_zt_num = 0,---飞萤扑火获取次数奇偶性
                samu_atk_add = 0,---萨姆已增加属性---
                samu_def_add = 0,
                samu_tsbh_add = 0,
                samu_qmb_add = 0,------
                samu_up_level_num = 0,---萨姆升级次数
                fyph_dead_num = 0,
                wjza_region_key = nil,
            },
            jwts_data = {
                st_data = {
                    ["psw_dlc7_jwts_mulu_abds"] = {
                        {card_key = "psw_dlc7_jwts_abds_baizi", types = "bf", qj_num = 2, is_unlock = false, is_remove = false},
                        {card_key = "psw_dlc7_jwts_abds_qinxiang", types = "bf", qj_num = 1, is_unlock = false, is_remove = false},
                        {card_key = "psw_dlc7_jwts_abds_xingye", types = "bf", qj_num = 1, is_unlock = false, is_remove = false},
                        {card_key = "psw_dlc7_jwts_abds_yegong", types = "gt", qj_num = 3, is_unlock = false, is_remove = false},
                    },
                    ["psw_dlc7_jwts_mulu_alws"] = {
                        {card_key = "psw_dlc7_jwts_alws_meixiao", types = "bf", qj_num = 1, is_unlock = false, is_remove = false},
                        {card_key = "psw_dlc7_jwts_alws_shazhi", types = "bf", qj_num = 2, is_unlock = false, is_remove = false},
                        {card_key = "psw_dlc7_jwts_alws_yjz", types = "bf", qj_num = 1, is_unlock = false, is_remove = false},
                    },
                    ["psw_dlc7_jwts_mulu_blb68"] = {
                        {card_key = "psw_dlc7_jwts_blb68_alu", types = "bf", qj_num = 2, is_unlock = false, is_remove = false},
                        {card_key = "psw_dlc7_jwts_blb68_jdz", types = "bf", qj_num = 1, is_unlock = false, is_remove = false},
                        {card_key = "psw_dlc7_jwts_blb68_muyue", types = "bf", qj_num = 1, is_unlock = false, is_remove = false},
                    },
                    ["psw_dlc7_jwts_mulu_bxskb"] = {
                        {card_key = "psw_dlc7_jwts_bxskb_rifumei", types = "gt", qj_num = 2, is_unlock = false, is_remove = false},
                        {card_key = "psw_dlc7_jwts_bxskb_xiaochun", types = "bf", qj_num = 1, is_unlock = false, is_remove = false},
                        {card_key = "psw_dlc7_jwts_bxskb_zi", types = "bf", qj_num = 2, is_unlock = false, is_remove = false},
                        {card_key = "psw_dlc7_jwts_bxskb_huazi", types = "gt", qj_num = 2, is_unlock = false, is_remove = false},
                    },
                    ["psw_dlc7_jwts_mulu_cac"] = {
                        {card_key = "psw_dlc7_jwts_cac_mrn", types = "sm", qj_num = 1, is_unlock = false, is_remove = false},
                        {card_key = "psw_dlc7_jwts_cac_nilu", types = "gt", qj_num = 2, is_unlock = false, is_remove = false},
                        {card_key = "psw_dlc7_jwts_cac_zhuyin", types = "gt", qj_num = 1, is_unlock = false, is_remove = false},
                    },
                    ["psw_dlc7_jwts_mulu_chh"] = {
                        {card_key = "psw_dlc7_jwts_chh_mika", types = "gt", qj_num = 3, is_unlock = false, is_remove = false},
                        {card_key = "psw_dlc7_jwts_chh_shengya", types = "gt", qj_num = 3, is_unlock = false, is_remove = false},
                        {card_key = "psw_dlc7_jwts_chh_zhu", types = "gt", qj_num = 3, is_unlock = false, is_remove = false},
                    },
                    ["psw_dlc7_jwts_mulu_game"] = {
                        {card_key = "psw_dlc7_jwts_game_alice", types = "sm", qj_num = 3, is_unlock = false, is_remove = false},
                        {card_key = "psw_dlc7_jwts_game_lv", types = "gt", qj_num = 2, is_unlock = false, is_remove = false},
                        {card_key = "psw_dlc7_jwts_game_taojing", types = "gt", qj_num = 2, is_unlock = false, is_remove = false},
                        {card_key = "psw_dlc7_jwts_game_yozi", types = "gt", qj_num = 1, is_unlock = false, is_remove = false},
                    },
                    ["psw_dlc7_jwts_mulu_jhqst"] = {
                        {card_key = "psw_dlc7_jwts_jhqst_meimi", types = "bf", qj_num = 1, is_unlock = false, is_remove = false},
                        {card_key = "psw_dlc7_jwts_jhqst_qinna", types = "sm", qj_num = 1, is_unlock = false, is_remove = false},
                    },
                    ["psw_dlc7_jwts_mulu_rabbit"] = {
                        {card_key = "psw_dlc7_jwts_rabbit_gongzi", types = "bf", qj_num = 2, is_unlock = false, is_remove = false},
                        {card_key = "psw_dlc7_jwts_rabbit_meiyou", types = "bf", qj_num = 2, is_unlock = false, is_remove = false},
                        {card_key = "psw_dlc7_jwts_rabbit_menghui", types = "gt", qj_num = 1, is_unlock = false, is_remove = false},
                        {card_key = "psw_dlc7_jwts_rabbit_xiao", types = "gt", qj_num = 1, is_unlock = false, is_remove = false},
                    },
                    ["psw_dlc7_jwts_mulu_xiunvhui"] = {
                        {card_key = "psw_dlc7_jwts_xiunvhui_mali", types = "sm", qj_num = 1, is_unlock = false, is_remove = false},
                        {card_key = "psw_dlc7_jwts_xiunvhui_rixiang", types = "sm", qj_num = 1, is_unlock = false, is_remove = false},
                        {card_key = "psw_dlc7_jwts_xiunvhui_yingzi", types = "sm", qj_num = 1, is_unlock = false, is_remove = false},
                    },
                    ["psw_dlc7_jwts_mulu_yth"] = {
                        {card_key = "psw_dlc7_jwts_yth_nuoa", types = "sm", qj_num = 1, is_unlock = false, is_remove = false},
                        {card_key = "psw_dlc7_jwts_yth_xiaoxue", types = "sm", qj_num = 1, is_unlock = false, is_remove = false},
                        {card_key = "psw_dlc7_jwts_yth_youxiang", types = "bf", qj_num = 2, is_unlock = false, is_remove = false},
                    },
                    ["psw_dlc7_jwts_mulu_zysxwy"] = {
                        {card_key = "psw_dlc7_jwts_zysxwy_hecheng", types = "gt", qj_num = 1, is_unlock = false, is_remove = false},
                        {card_key = "psw_dlc7_jwts_zysxwy_yihua", types = "sm", qj_num = 1, is_unlock = false, is_remove = false},
                    },
                },
                color_num = 0,
                color_sx = 500,
                student_num = 0,
                student_sx = 9,
                zhaomu_pool = {},
                pick_num = 3,
                jwts_qiji = 0,
                gt_jishu = 0,
                bf_jishu = 0,
                sm_jishu = 0,
                jb_abds_num = 0,
                jb_wmdgs_num = 0,
                jb_rfm_num = 0,
                jb_clj_num = 0,
                jb_rabbit_num = 0,
                color_xishu = 5,
                color_add_atk = 0,
                color_add_sx = 0,
                color_add_fpt = 0,
                abds_st_num = 0,
                alws_st_num = 0,
                blb68_st_num = 0,
                bxskb_st_num = 0,
                cac_st_num = 0,
                chh_st_num = 0,
                game_st_num = 0,
                jhqst_st_num = 0,
                rabbit_st_num = 0,
                xiunvhui_st_num = 0,
                yth_st_num = 0,
                zysxwy_st_num = 0,
            },
            qysj_turn_num = 2,
            kokora_die = 0,
            ams_data = {
                mission_data = {
                    ["psw_dlc7_ams_mulu_mission_def_mow"] = {is_on = false, nandu_num = 1, is_pick = false, mis_num = 0, mis_tj = 0},
                    ["psw_dlc7_ams_mulu_mission_def_qd"] = {is_on = false, nandu_num = 1, is_pick = false, mis_num = 0, mis_tj = 0},
                    ["psw_dlc7_ams_mulu_mission_defeat"] = {is_on = false, nandu_num = 1, is_pick = false, mis_num = 0, mis_tj = 0},
                    ["psw_dlc7_ams_mulu_mission_jyjj"] = {is_on = false, nandu_num = 1, is_pick = false, mis_num = 0, mis_tj = 0},
                    ["psw_dlc7_ams_mulu_mission_levelup"] = {is_on = false, nandu_num = 1, is_pick = false, mis_num = 0, mis_tj = 0},
                    ["psw_dlc7_ams_mulu_mission_tf"] = {is_on = false, nandu_num = 1, is_pick = false, mis_num = 0, mis_tj = 0},
                    ["psw_dlc7_ams_mulu_mission_xuanzhan"] = {is_on = false, nandu_num = 1, is_pick = false, mis_num = 0, mis_tj = 0},
                },
                mission_nandu = {
                    ["psw_dlc7_ams_mulu_mission_def_mow"] = {
                        [1] = {tj = 2, reward_num = 1},
                        [2] = {tj = 4, reward_num = 1},
                        [3] = {tj = 8, reward_num = 1},
                    },
                    ["psw_dlc7_ams_mulu_mission_def_qd"] = {
                        [1] = {tj = 1, reward_num = 1},
                        [2] = {tj = 2, reward_num = 1},
                        [3] = {tj = 4, reward_num = 1},
                    },
                    ["psw_dlc7_ams_mulu_mission_defeat"] = {
                        [1] = {tj = 3, reward_num = 1},
                        [2] = {tj = 6, reward_num = 2},
                        [3] = {tj = 12, reward_num = 3},
                    },
                    ["psw_dlc7_ams_mulu_mission_jyjj"] = {
                        [1] = {tj = 2, reward_num = 1},
                        [2] = {tj = 4, reward_num = 2},
                        [3] = {tj = 8, reward_num = 3},
                    },
                    ["psw_dlc7_ams_mulu_mission_levelup"] = {
                        [1] = {tj = 2, reward_num = 2000},
                        [2] = {tj = 4, reward_num = 4000},
                        [3] = {tj = 8, reward_num = 8000},
                    },
                    ["psw_dlc7_ams_mulu_mission_tf"] = {
                        [1] = {tj = 1, reward_num = 1},
                        [2] = {tj = 2, reward_num = 2},
                        [3] = {tj = 3, reward_num = 3},
                    },
                    ["psw_dlc7_ams_mulu_mission_xuanzhan"] = {
                        [1] = {tj = 2, reward_num = 1},
                        [2] = {tj = 4, reward_num = 1},
                        [3] = {tj = 8, reward_num = 1},
                    },
                },
                mishi_num = 0,
                jysp_data = {
                    {key = "psw_dlc7_ams_shop_ams", crt_num = 0, level = 0, num_sx = 100, bundle_key = "set_psw_tf_ex_ams_3"},
                    {key = "psw_dlc7_ams_shop_exxcw", crt_num = 0, level = 0, num_sx = 120, bundle_key = "set_psw_tf_ex_xxdyq_1"},
                    {key = "psw_dlc7_ams_shop_jingliu", crt_num = 0, level = 0, num_sx = 50, bundle_key = "set_psw_tf_nor_jingliu"},
                    {key = "psw_dlc7_ams_shop_kailu", crt_num = 0, level = 0, num_sx = 50, bundle_key = "set_psw_tf_nor_mermfs_nor"},
                    {key = "psw_dlc7_ams_shop_kan", crt_num = 0, level = 0, num_sx = 50, bundle_key = "set_psw_tf_nor_bhsn"},
                    {key = "psw_dlc7_ams_shop_nnk", crt_num = 0, level = 0, num_sx = 70, bundle_key = "set_psw_tf_nor_nnk"},
                    {key = "psw_dlc7_ams_shop_norkokora", crt_num = 0, level = 0, num_sx = 50, bundle_key = "set_psw_tf_nor_xxydz_nor"},
                    {key = "psw_dlc7_ams_shop_norxcw", crt_num = 0, level = 0, num_sx = 50, bundle_key = "set_psw_tf_nor_xxyds_nor"},
                    {key = "psw_dlc7_ams_shop_pklm", crt_num = 0, level = 0, num_sx = 50, bundle_key = "set_psw_tf_nor_chgz_nor"},
                    {key = "psw_dlc7_ams_shop_spkokora", crt_num = 0, level = 0, num_sx = 120, bundle_key = "set_psw_tf_sp_kokoro"},
                    {key = "psw_dlc7_ams_shop_xingfa", crt_num = 0, level = 0, num_sx = 120, bundle_key = "set_psw_tf_ex_xingfa_1"},
                    {key = "psw_dlc7_ams_shop_yls", crt_num = 0, level = 0, num_sx = 50, bundle_key = "set_psw_tf_nor_jgrs_nor"},
                    {key = "psw_dlc7_ams_shop_zhenbu", crt_num = 0, level = 0, num_sx = 120, bundle_key = "set_psw_tf_ex_zhenbu_1"},
                },
                gzqs_exp = 0,
                gzqs_level = 0,
                ams_sjxz_num = 0,
                ccst_num = 0,
            },
            mc_data = {
                gmz_data = {
                    ["psw_dlc7_mc_anke"] = {is_on = false, is_get = false, xznl = 0, level = -1, gmjf_cd = 0},
                    ["psw_dlc7_mc_chun"] = {is_on = false, is_get = false, xznl = 0, level = -1, gmjf_cd = 0},
                    ["psw_dlc7_mc_feibi"] = {is_on = false, is_get = false, xznl = 0, level = -1, gmjf_cd = 0},
                    ["psw_dlc7_mc_jinxi"] = {is_on = false, is_get = false, xznl = 0, level = -1, gmjf_cd = 0},
                    ["psw_dlc7_mc_klt"] = {is_on = false, is_get = false, xznl = 0, level = -1, gmjf_cd = 0},
                    ["psw_dlc7_mc_ktll"] = {is_on = false, is_get = false, xznl = 0, level = -1, gmjf_cd = 0},
                    ["psw_dlc7_mc_sar"] = {is_on = false, is_get = false, xznl = 0, level = -1, gmjf_cd = 0},
                    ["psw_dlc7_mc_wln"] = {is_on = false, is_get = false, xznl = 0, level = -1, gmjf_cd = 0},
                },
                battle_get_xznl_num = 2,
                jinxi_cslx_num = 0,
                jinxi_shaoguang = 0,
                klt_ksjz = 0,
                klt_have_get_ksjz = 0,
                ksjz_turn_get_num = 2,
                klt_sizhao_num = 0,
                klt_lc = 0,
                feibi_gzxy = 0,
                feibi_fuyin = 0,
                feibi_qiyuan = 0,
                jzh_tp_x = 0,
                jzh_tp_y = 0,
                wln_ghnl = 0,
                ktll_mili = 0,
                sar_qd_num = 0,
                chun_yrh_num = 3,
                chun_hcr_num = 0,
            },
            jishu_xilie_gmz = 0,
            xingye_have_add_hp = 0,
            ewai_hp_num = 0,
            xingye_atk_num = 0,
            xuefeng_hgd = 0,
            xf_dtxy_gjyw = 0,
            xf_dtxy_mysw = 0,
            xf_tp_cha_x = 0,
            xf_tp_cha_y = 0,
            xf_leader_x = 0,
            xf_leader_y = 0,
            tifeng_zz_num = 0,
            tifeng_hv_ad_atk = 0,
            lilika_lh = 0,
            lilika_hv_add_tili = 0,
            lilika_hgd = 0,
            lilika_turn_yueye_num = 0,
            lilika_yueye_all_num = 0,
            lilika_ab_num = 0,
            monvsp_num = 0,
            lilika_get_turn = 0,
            lilika_fac_rank = 0,
            lilika_bmt_num = 0,
            lilika_raoluan_level = 1,
            lilika_jiqiao_level = 1,
            lilika_fuyou_level = 1,
            lilika_wuxiao_level = 1,
            lilika_gudai_level = 1,
            lilika_miyin_level = 1,
            lilika_nvshen_level = 1,
            lilika_yueguang_level = 1,
            lilika_juren_level = 1,
            lilika_qynszg_level = 1,
            lilika_zhufu_level = 1,
            lilika_liliang = false,
            battle_qysj_num = 0,
            sx_level_hv_add = {
                hv_add_atk = 0,
                hv_add_tili_sx = 0,
                hv_add_card_use_sx = 0,
                hv_add_lunci_card = 0,
            },
            card_num_crt = 0,
            alice_cz7_js = 0,
            wef_csys_can_tp = false,
            xueli_mnsp_data = {
                {key = "psw_dlc7_xueli_mnsp_ny", have_finish = false, crt_on = false, level = 1, target_level = 3},
                {key = "psw_dlc7_xueli_mnsp_mly", have_finish = false, crt_on = false, level = 1, target_level = 2},
                {key = "psw_dlc7_xueli_mnsp_yls", have_finish = false, crt_on = false, level = 1, target_level = 2},
                {key = "psw_dlc7_xueli_mnsp_nyx", have_finish = false, crt_on = false, level = 1, target_level = 3},
                {key = "psw_dlc7_xueli_mnsp_mll", have_finish = false, crt_on = false, level = 1, target_level = 3},
                {key = "psw_dlc7_xueli_mnsp_keke", have_finish = false, crt_on = false, level = 1, target_level = 3},
                {key = "psw_dlc7_xueli_mnsp_anan", have_finish = false, crt_on = false, level = 1, target_level = 3},
                {key = "psw_dlc7_xueli_mnsp_aima", have_finish = false, crt_on = false, level = 1, target_level = 2},
            },
            xueli_tuili_turn_num = 0,
            feibi_qmd_sx = 0,
            feibi_qmd_data = {
                {key = "psw_dlc7_feibi_qmd_chengxin", is_on = false},
                {key = "psw_dlc7_feibi_qmd_jiezhi", is_on = false},
                {key = "psw_dlc7_feibi_qmd_kangkai", is_on = false},
                {key = "psw_dlc7_feibi_qmd_zhengyi", is_on = false},
                {key = "psw_dlc7_feibi_qmd_xiwang", is_on = false},
                {key = "psw_dlc7_feibi_qmd_yonggan", is_on = false},
                {key = "psw_dlc7_feibi_qmd_kuanrong", is_on = false},
            },
            luluka_ice_num = 0,
            saima_data = {
                sudu = 0,
                tineng = 0,
                liliang = 0,
                yili = 0,
                zhili = 0,
                juli = 0,
                xd_point_sx = 3,
                xd_point_crt = 3,
                sudu_xl_num = 0,
                tineng_xl_num = 0,
                liliang_xl_num = 0,
                yili_xl_num = 0,
                zhili_xl_num = 0,
                jichu_juli_xl_num = 0,
                jichu_sx_xl_num = 0,
                bnous_all = 0,
                bnous_jichu_sx = 0,
                bnous_jichu_juli = 0,
                juli_xl_cost = 5,
                bisai_chudao = nil,
                bisai_juhua = nil,
                bisai_youma_c = nil,
                bisai_tianh_c = nil,
                bisai_youma_3rd = nil,
                bisai_kaixuan = nil,
                sudu_hv_get = 0,
                tineng_hv_get = 0,
                liliang_hv_get = 0,
                yili_hv_get = 0,
                zhili_hv_get = 0,
            },
            ams_nsdjh_num = 0,
        }

local function psw_copy_table(t)
    if type(t) ~= "table" then return t end
    local r = {}
    for k, v in pairs(t) do
        r[k] = psw_copy_table(v)
    end
    return r
end

function psw_ensure_player_data(faction_name)
    if not psw_main_data.player_data[faction_name] then
        psw_main_data.player_data[faction_name] = {}
    end
    for k, v in pairs(psw_main_default_player_data) do
        if psw_main_data.player_data[faction_name][k] == nil then
            psw_main_data.player_data[faction_name][k] = psw_copy_table(v)
        end
    end
end


local function psw_get_num(faction_name, key)
    local t = psw_main_data.player_data[faction_name]
    return (t and t[key]) or 0
end

local function psw_get_any(faction_name, key)
    local t = psw_main_data.player_data[faction_name]
    return t and t[key]
end


-- ERE WE GO

local function psw_faction_button_created(pswyoFactionName, ui_tooltip, ui_button, ui_button_image_path)
    local button_group_management = find_uicomponent(ui_root, "hud_campaign", "faction_buttons_docker", "button_group_management")
    if not button_group_management then return end
    local main_faction_dilemma_button = find_uicomponent(button_group_management, ui_button)
    if not main_faction_dilemma_button then
        main_faction_dilemma_button = UIComponent(button_group_management:CreateComponent(ui_button, "ui/templates/round_large_button"))
        ---@diagnostic disable-next-line: undefined-field
        button_group_management:Layout()
        local localized_main_tooltip = common.get_localised_string(ui_tooltip)
        main_faction_dilemma_button:SetTooltipText(localized_main_tooltip, localized_main_tooltip, true)
        main_faction_dilemma_button:SetImagePath(ui_button_image_path, 0)
    end
    if not main_faction_dilemma_button then return end
    main_faction_dilemma_button:SetVisible(true)
end

--- Button click listener

local function psw_faction_button_pressed_listener(ui_button)
    core:add_listener(
        "psw_faction_button_pressed",
        "ComponentLClickUp",
        function(context)
            
            if not context or not context.string then return false end
            return context.string == ui_button
        end,
        function()
            out("#### you pressed the button ####")
            local local_faction = cm:get_local_faction_name(true);
			local faction = cm:model():world():faction_by_key(local_faction);
			local faction_cqi = faction:command_queue_index();
            
            CampaignUI.TriggerCampaignScriptEvent(faction_cqi, ui_button);
        end,
    true)
end

--- first tick

cm:add_first_tick_callback(

    --Whenever the game first starts, we run this function. Which calls an event listener
    function()

        ui_root = core:get_ui_root()


        --If the current faction, which is a player, check which lizardmen faction it is


        if 1 == 1 then

            pswyoFactionName = cm:get_local_faction_name(true)
            ui_tooltip = psw_tooltip
            ui_button = psw_button
            ui_button_image_path = psw_button_image_path
            
            psw_faction_button_created(pswyoFactionName, ui_tooltip, ui_button, ui_button_image_path)
            psw_faction_button_pressed_listener(ui_button)
            out("#### wh2_main_lzd_hexoatl buttons ####")

        
        end

    out("#### FIRST STEP ####")
    end
)

 

--- 游戏王 卡牌池 ---
local function psw_main_yqdjb_kachi(faction_name)
    
    local faction = cm:get_faction(faction_name)
    
    
    local yqdjb_ck_voice_random = cm:random_number(100, 1)
    if yqdjb_ck_voice_random >= 50 then
        common.trigger_soundevent("yqdjb_chouka_1")
        advice_yqdjb_chouka_1()
    elseif 1 == 1 then
        common.trigger_soundevent("yqdjb_chouka_2")
        advice_yqdjb_chouka_2()
    end
    
    local crt_card = "jnz_tf_nor_yqdjb_1_gzhfj"
    -- Here be your mission keys
    local random_number = cm:random_number(100, 1)
    
    if random_number <= 8 then
        crt_card = "jnz_tf_nor_yqdjb_1_szss"
        cm:callback(function()
            advice_yqdjb_szss()
        end, 3.5)
    elseif random_number > 8 and random_number <= 16 then
        crt_card = "jnz_tf_nor_yqdjb_1_gzhfj"
        cm:callback(function()
            advice_yqdjb_gzhfj()
        end, 3.5)
    elseif random_number > 16 and random_number <= 21 then
        crt_card = "jnz_tf_nor_yqdjb_1_hmss"
        cm:callback(function()
            advice_yqdjb_hmss()
        end, 3.5)
    elseif random_number > 21 and random_number <= 25 then
        crt_card = "jnz_tf_nor_yqdjb_1_ahqsgy"
        cm:callback(function()
            advice_yqdjb_ahqsgy()
        end, 3.5)
    elseif random_number > 25 and random_number <= 29 then
        crt_card = "jnz_tf_nor_yqdjb_1_lphzjs"
        cm:callback(function()
            advice_yqdjb_lphzjs()
        end, 3.5)
    elseif random_number > 29 and random_number <= 37 then
        crt_card = "jnz_tf_nor_yqdjb_1_zzzl"
        cm:callback(function()
            advice_yqdjb_zzzl()
        end, 3.5)
    elseif random_number > 37 and random_number <= 45 then
        crt_card = "jnz_tf_nor_yqdjb_1_hmdlh"
        cm:callback(function()
            advice_yqdjb_hmdnh()
        end, 3.5)
    elseif random_number > 45 and random_number <= 50 then
        crt_card = "jnz_tf_nor_yqdjb_1_youzu"
        cm:callback(function()
            advice_yqdjb_youzu()
        end, 3.5)
    elseif random_number > 50 and random_number <= 55 then
        crt_card = "jnz_tf_nor_yqdjb_1_zuozu"
        cm:callback(function()
            advice_yqdjb_zuozu()
        end, 3.5)
    elseif random_number > 55 and random_number <= 60 then
        crt_card = "jnz_tf_nor_yqdjb_1_youwan"
        cm:callback(function()
            advice_yqdjb_youwan()
        end, 3.5)
    elseif random_number > 60 and random_number <= 65 then
        crt_card = "jnz_tf_nor_yqdjb_1_zuowan"
        cm:callback(function()
            advice_yqdjb_zuowan()
        end, 3.5)
    elseif random_number > 65 and random_number <= 70 then
        crt_card = "jnz_tf_nor_yqdjb_1_tou"
        cm:callback(function()
            advice_yqdjb_akzdy()
        end, 3.5)
    elseif random_number > 70 and random_number <= 78 then
        crt_card = "jnz_tf_nor_yqdjb_1_ssfhz"
        cm:callback(function()
            advice_yqdjb_ssfhz()
        end, 3.5)
    elseif random_number > 78 and random_number <= 83 then
        crt_card = "jnz_tf_nor_yqdjb_1_ronghe"
        cm:callback(function()
            advice_yqdjb_ronghe()
        end, 3.5)
    elseif random_number > 83 and random_number <= 91 then
        crt_card = "jnz_tf_nor_yqdjb_1_heidong"
        cm:callback(function()
            advice_yqdjb_heidong()
        end, 3.5)
    elseif random_number > 91 and random_number <= 94 then
        crt_card = "jnz_tf_nor_yqdjb_1_jsb"
        cm:callback(function()
            advice_yqdjb_jsb()
        end, 3.5)
        
    elseif random_number > 94 and random_number <= 97 then
        crt_card = "jnz_tf_nor_yqdjb_1_tkl"
        cm:callback(function()
            advice_yqdjb_tkl()
        end, 3.5)
    elseif random_number > 97 and random_number <= 100 then
        crt_card = "jnz_tf_nor_yqdjb_1_ysl"
        cm:callback(function()
            advice_yqdjb_ysl()
        end, 3.5)
    end
    local effect_key = crt_card .. "_effect_bundle"
    psw_aplly_costom_effect_bundle_hidden_fn(effect_key, faction_name)
    
    local yqdjb_fengyinzhe = psw_faction_has_effect_bundle(faction_name, "jnz_tf_nor_yqdjb_1_youzu") and psw_faction_has_effect_bundle(faction_name, "jnz_tf_nor_yqdjb_1_zuozu") and psw_faction_has_effect_bundle(faction_name, "jnz_tf_nor_yqdjb_1_youwan") and psw_faction_has_effect_bundle(faction_name, "jnz_tf_nor_yqdjb_1_zuowan") and psw_faction_has_effect_bundle(faction_name, "jnz_tf_nor_yqdjb_1_tou")
    
    local yqdjb_ronghe_lqsgy = psw_faction_has_effect_bundle(faction_name, "jnz_tf_nor_yqdjb_1_zzzl") and psw_faction_has_effect_bundle(faction_name, "jnz_tf_nor_yqdjb_1_ahqsgy") and psw_faction_has_effect_bundle(faction_name, "jnz_tf_nor_yqdjb_1_ronghe")
    
    local yqdjb_ronghe_cmdjs = psw_faction_has_effect_bundle(faction_name, "jnz_tf_nor_yqdjb_1_hmss") and psw_faction_has_effect_bundle(faction_name, "jnz_tf_nor_yqdjb_1_lphzjs") and psw_faction_has_effect_bundle(faction_name, "jnz_tf_nor_yqdjb_1_ronghe")
    
    local yqdjb_huanshen = psw_faction_has_effect_bundle(faction_name, "jnz_tf_nor_yqdjb_1_jsb") and psw_faction_has_effect_bundle(faction_name, "jnz_tf_nor_yqdjb_1_tkl") and psw_faction_has_effect_bundle(faction_name, "jnz_tf_nor_yqdjb_1_ysl")
    
    cm:apply_effect_bundle(crt_card, faction_name, 5)
    
    if (yqdjb_fengyinzhe or yqdjb_ronghe_lqsgy or yqdjb_ronghe_cmdjs or yqdjb_huanshen) and not psw_faction_has_effect_bundle(faction_name, "set_yqdjb_qnjm_yiget") then
        cm:add_ancillary_to_faction(faction, "yqdjb_qnjm", false)
        psw_aplly_costom_effect_bundle_hidden_fn("set_yqdjb_qnjm_yiget", faction_name)
    end
    
    if yqdjb_ronghe_lqsgy and not psw_faction_has_effect_bundle(faction_name, "set_yqdjb_get_lqsgy") then
        psw_aplly_costom_effect_bundle_hidden_fn("jnz_tf_nor_yqdjb_1_lqsgy", faction_name)
        psw_add_jishu_long(faction_name, 1)
    end
    
    if yqdjb_ronghe_cmdjs and not psw_faction_has_effect_bundle(faction_name, "set_yqdjb_get_cmdjs") then
        psw_aplly_costom_effect_bundle_hidden_fn("jnz_tf_nor_yqdjb_1_cmdjs", faction_name)
        psw_add_jishu_moli(faction_name, 3)
    end

end
    
    
    
    
    
    
    
    
    
    
    
    
-- 决定唯一还是普通，幸运值相关

core:remove_listener("psw_lizardmen_mazda_uitrigger_for_button")
out("########## PSW PATCH tianfu.lua loaded, lottery fix active ##########")
core:add_listener("psw_lizardmen_mazda_uitrigger_for_button",
    "UITrigger",
    function(context)
        return context:trigger():starts_with(psw_button)
    end,
   psw_pcall_wrapper(function(context)

        local main_turn_number = cm:turn_number()
        local faction = cm:model():faction_for_command_queue_index(context:faction_cqi())
        local psw_main_qysj_click = psw_resource_value(faction, "psw_main_gmsj")
        local faction_name = faction:name()
            psw_ensure_player_data(faction_name)
        
local p=psw_main_data.player_data[faction_name]or{}
local nor_count=p.nor_count or 0
local faction_leader=faction:faction_leader()
if not p.set_psw_hero_select then
                                                           
            if faction_name ~= "wh3_dlc24_tze_the_deceivers" and faction_name ~= "wh2_dlc13_lzd_spirits_of_the_jungle" and faction_name ~= "wh3_dlc27_nor_sayl" and faction_name ~= "wh3_dlc27_sla_the_tormentors" and faction_name ~= "wh3_dlc27_sla_masque_of_slaanesh" and faction_name ~= "wh3_dlc27_hef_aislinn" then
                if faction_leader:is_null_interface() or faction_leader:is_wounded() or faction_leader:is_at_sea() then
                    alice_dlc6_character_get_false()
                    return
                end
                local hero_region = faction:home_region()
                
                if (hero_region:is_null_interface()) or (hero_region == nil) or (hero_region:is_abandoned()) then
                    alice_dlc6_character_get_false()
                    return
                end
            end
            
            psw_hero_select(faction)
            if psw_main_data.player_data[faction_name] then
                psw_main_data.player_data[faction_name].set_psw_hero_select = true
            end
            
        elseif not psw_main_data.global_data.set_psw_main_nandu_xz then
            cm:trigger_dilemma(faction_name, "dilemma_tf_psw_main_nandu")
            
            psw_main_data.global_data.psw_main_boss_create_faction = faction_name
            psw_main_data.global_data.set_psw_main_nandu_xz = true
        elseif 1 == 1 then
            
            local psw_shenxing =  psw_resource_value(faction, "psw_shenxing")
            local psw_moli =  psw_resource_value(faction, "psw_moli")
            
            local jishu_mofashaonv =  psw_resource_value(faction, "jishu_mofashaonv")
            local jishu_alxy_lvzhe =  psw_resource_value(faction, "jishu_alxy_lvzhe")
            
            local _pd = psw_main_data.player_data[faction_name] or {}
            local jishu_ex_count = _pd.jishu_ex_count or 0
            local jishu_lmyx_wurandu = _pd.jishu_lmyx_wurandu or 0
            local jishu_lmyx_lunhui = _pd.jishu_lmyx_lunhui or 0
            local psw_jianshu = _pd.psw_jianshu or 0
            local jishu_shenhai = _pd.jishu_shenhai or 0
            
            local psw_meili = _pd.psw_meili or 0
            
            local swyh_install_jishu = _pd.swyh_install_jishu or 0
            local bass_sfjx = psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_bass_2") or false
            local bass_jxcs = _pd.bass_jxcs or 0
            local jishu_xsdjy_hh = _pd.jishu_xsdjy_hh or 0
            local amly_clks_jishu = _pd.amly_clks_jishu or 0
            local azsyz_zihui_jishu = _pd.azsyz_zihui_jishu or 0
            local azsyz_jiyizhi = _pd.azsyz_jiyizhi or 0
            local ybbb_jishu_zhongzu = _pd.ybbb_jishu_zhongzu or 0
            local psw_main_qysj_cj = psw_resource_value(faction, "psw_main_qysj")
            local lmyx_yinguo_jishu = _pd.lmyx_yinguo_jishu or 0
            
            local num_controlled_provinces = cm:num_provinces_controlled_by_faction(faction)
            local turn_number = cm:turn_number()
            
            local yx_subtype = psw_get_any(faction_name, "yx_subtype")
            local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
            
            if not psw_main_character or psw_main_character:is_null_interface() or psw_main_character:is_wounded() or psw_main_character:is_at_sea() or not cm:char_is_general_with_army(psw_main_character) then
                return
            end
            local effect_list = {}
            local effect_list_2 = {}
            
            ------------------- 天赋觉醒 ---------------------
            ----- 救济的祈愿 ------
            if faction:has_effect_bundle("set_psw_tf_ex_yhzl_1") == true and not faction:has_effect_bundle("set_psw_tf_ex_yhzl_2") and lmyx_yinguo_jishu >= 10 then
                common.trigger_soundevent("yhzl_2")
                advice_psw_tf_ex_yhzl_2_1()
                
                psw_add_jishu_zhiyu(faction_name, 2)
                
                cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                        {
                        "psw_tf_ex_yhzl_2"
                        }
                )
                
                psw_add_jishu_shenxing(faction_name, 3)
                psw_add_jishu_miansi(faction_name, 1)
                psw_delete_shanbi_effect(faction_name, "jn_shanbi_lmyx_xzxw")
                
                effect_list = {
                    {effect = "jdjn_yhzl_nsdrzjg1", effect_scope = "faction_to_force_own", effect_num = 1},
                    {effect = "wh_main_effect_character_stat_unit_health", effect_scope = "faction_to_force_own", effect_num = 20},
                    {effect = "wh3_dlc20_effect_xp_gain_all_units", effect_scope = "faction_to_force_own", effect_num = 25},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_ex_yhzl", 0, effect_list)
                
                
                psw_dlc6_xzxw_effct_apply()
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_yhzl_2", faction_name)
                local ran_num_yhzl_2 = cm:random_number(10, 2)
                psw_add_lmyx_yinguo_jishu(faction_name, ran_num_yhzl_2)
                

        ----- 圆环之理 ------


            elseif faction:has_effect_bundle("set_psw_tf_ex_yhzl_2") == true and jishu_mofashaonv >= 4 and lmyx_yinguo_jishu >= 35 and not faction:has_effect_bundle("set_psw_tf_ex_yhzl_3") then
                common.trigger_soundevent("yhzl_3")
                advice_psw_tf_ex_yhzl_3_1()
                
                cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                        {
                        "psw_tf_ex_yhzl_3"
                        }
                )
                
                psw_add_jishu_moli(faction_name, -3)
                psw_add_jishu_shenxing(faction_name, -3)
                psw_add_jishu_zhiyu(faction_name, -5)
                local yhzl_zdsgm_bundle = "jnz_ex_yhzl_zdsdgmz"
                local yhzl_zyjh_bundle = "jnz_ex_yhzl_zyjh"
                
                psw_add_jishu_miansi(faction_name, 2)
                
                psw_add_hong_count(faction_name, 1)
                psw_add_jishu_zhongmo(5)
                
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_yhzl_3", faction_name)
                psw_aplly_costom_effect_bundle_hidden_fn("set_faction_hace_hong_ex", faction_name)
                psw_main_data.global_data.set_main_psw_tf_ex_yhzl_3 = true
                ---回收QB神性 赋予闪避
                psw_dlc6_yhzl_huishou_qb(faction_name)
                ---不会绝望的希望之光
                psw_dlc6_yhzl_bhjwd_xwzg(faction_name)
                yhzl_yinguo_effect_apply(faction_name, 0)
                local xmy_fac_name = psw_main_data.global_data.xmy_faction_name
                cm:callback(function()
                    psw_dlc7_xmy_hong_effect(xmy_fac_name)
                    psw_add_lmyx_yinguo_jishu(faction_name, 0)
                end, 190)

        ----- 人之律者 ------
            elseif faction:has_effect_bundle("set_psw_tf_ex_alxy_1") == true and (jishu_alxy_lvzhe >= 15 or main_turn_number >= 30) and not faction:has_effect_bundle("set_psw_tf_ex_alxy_2") then
                common.trigger_soundevent("alxy_2")
                advice_psw_tf_ex_alxy_2_1()
                

                
                cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                        {
                        "psw_tf_ex_alxy_2"
                        }
                )
                psw_add_yctz_effect_to_faction(faction_name, "fyx")
                psw_add_jishu_miansi(faction_name, 1)
                
                psw_delete_shanbi_effect(faction_name, "jn_shanbi_alxy_rmcx")
                cm:remove_effect_bundle_from_character("jnz_tf_ex_wxzr", psw_main_character);
                cm:apply_effect_bundle_to_character("jnz_tf_ex_rzlz", psw_main_character, 0)
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_alxy_2", faction_name)
        
        
                
                
                
        
        ----- 虹未花 ------
            elseif psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_sywh_2") == true and swyh_install_jishu >= 16 and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_sywh_3") then
            
                common.trigger_soundevent("sywh_3")
                advice_psw_tf_ex_sywh_3_1()
                
                psw_add_jishu_zhixing(faction_name, 2)
                psw_add_jishu_zhiyu(faction_name, 2)
                
                psw_add_jishu_miansi(faction_name, 1)
                
                psw_add_hong_count(faction_name, 1)
                cm:remove_effect_bundle_from_character("jnz_tf_ex_sywh_zy_1", psw_main_character);
                cm:remove_effect_bundle_from_character("jnz_tf_ex_sywh_sp_1", psw_main_character);
                cm:remove_effect_bundle_from_character("jnz_tf_ex_sywh_ty_1", psw_main_character);
                cm:remove_effect_bundle_from_character("jnz_tf_ex_sywh_clj_1", psw_main_character);
                cm:remove_effect_bundle_from_character("jnz_tf_ex_sywh_bdh_1", psw_main_character);
                cm:remove_effect_bundle_from_character("jnz_tf_ex_sywh_rys_1", psw_main_character);
                cm:remove_effect_bundle_from_character("jnz_tf_ex_sywh_ydr_1", psw_main_character);
                cm:remove_effect_bundle_from_character("jnz_tf_ex_sywh_bmbx_1", psw_main_character);
                cm:remove_effect_bundle_from_character("jnz_tf_ex_sywh_dtsz_1", psw_main_character);
                cm:remove_effect_bundle_from_character("jnz_tf_ex_sywh_ydy_1", psw_main_character);
                
                psw_delete_shanbi_effect(faction_name, "jn_shanbi_swwh_sj")
                cm:apply_effect_bundle_to_character("jnz_tf_ex_sywh_zy_2", psw_main_character, 0)
                cm:apply_effect_bundle_to_character("jnz_tf_ex_sywh_sp_2", psw_main_character, 0)
                cm:apply_effect_bundle_to_character("jnz_tf_ex_sywh_ty_2", psw_main_character, 0)
                cm:apply_effect_bundle_to_character("jnz_tf_ex_sywh_clj_2", psw_main_character, 0)
                cm:apply_effect_bundle_to_character("jnz_tf_ex_sywh_bdh_2", psw_main_character, 0)
                cm:apply_effect_bundle_to_character("jnz_tf_ex_sywh_rys_2", psw_main_character, 0)
                cm:apply_effect_bundle_to_character("jnz_tf_ex_sywh_ydr_2", psw_main_character, 0)
                cm:apply_effect_bundle_to_character("jnz_tf_ex_sywh_bmbx_2", psw_main_character, 0)
                cm:apply_effect_bundle_to_character("jnz_tf_ex_sywh_dtsz_2", psw_main_character, 0)
                cm:apply_effect_bundle_to_character("jnz_tf_ex_sywh_ydy_2", psw_main_character, 0)
                cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                        {
                        "psw_tf_ex_sywh_3"
                        }
                        )
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_sywh_3", faction_name)
                psw_aplly_costom_effect_bundle_hidden_fn("set_faction_hace_hong_ex", faction_name)
                psw_aplly_costom_effect_bundle_hidden_fn("jnz_tf_ex_sywh_bdh_2", faction_name)
                
                psw_add_jishu_zhongmo(5)
            
            
            ----- 彼岸双生 ------
            elseif bass_jxcs >= 2 and not bass_sfjx then
            
                common.trigger_soundevent("bass_2")
                advice_psw_tf_ex_bass_2_1()
                
                cm:add_ancillary_to_faction(faction, "bass_bazf", false)
                cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                    {
                    "psw_tf_ex_bass_2"
                    }
                )
                cm:remove_effect_bundle_from_character("jnz_tf_psw_tf_ex_bass_1_b", psw_main_character);
                cm:remove_effect_bundle_from_character("jnz_tf_psw_tf_ex_bass_1_l", psw_main_character);
                cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_ex_bass_2_l", psw_main_character, 0);
                psw_add_yctz_effect_to_faction(faction_name, "fyx")
                
                psw_add_jishu_miansi(faction_name, 1)
                
                psw_main_data.player_data[faction_name].bass_rgqh_li = 1
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_bass_2", faction_name)
                
                
            
                
                
                
                
            
            ----- 冰川镜华 ------
            
            elseif psw_moli >= 10 and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_xxdyq_1") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_xxdyq_2") then
                
                common.trigger_soundevent("xxdyq_2")
                advice_psw_tf_ex_xxdyq_2_1()
                cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                    {
                    "psw_tf_ex_xxdyq_2"
                    }
                )
                cm:add_ancillary_to_faction(faction, "bcjh_xrdymz", false)
                psw_add_jishu_xingyun(faction_name, 1)
                cm:remove_effect_bundle_from_character("jnz_tf_ex_bcjh_1", psw_main_character);
                cm:apply_effect_bundle_to_character("jnz_tf_ex_bcjh_2", psw_main_character, 0);
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_xxdyq_2", faction_name)
                
                
            ----- 星神的记忆 ------
            
            elseif jishu_ex_count <= 1 and turn_number >= 25 and jishu_xsdjy_hh >= 15 and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_xsdjy_nor1") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_xsdjy_nor2") and not psw_main_data.global_data.set_psw_tf_ex_xsdjy_nor2 then
                
                common.trigger_soundevent("xsdjy")
                advice_xsdjy_1_1()
                
                cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                    {
                    "psw_tf_ex_xsdjy_nor2"
                    }
                )
                cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                    {
                    "psw_tf_ex_xsdjy_nor2"
                    }
                )
                
                psw_add_jishu_miansi(faction_name, 1)
                
                cm:add_ancillary_to_faction(faction, "xsdjy_shengjian", false)
                

                cm:apply_effect_bundle_to_character("jnz_tf_nor_xsdjy_2", psw_main_character, 0);
                
                
                psw_add_jishu_shenxing(faction_name, 2)
                psw_add_jishu_xingyun(faction_name, 2)
                psw_add_jishu_ex_count(faction_name, 1)
                
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_xsdjy_nor2", faction_name)
                psw_main_data.global_data.set_psw_tf_ex_xsdjy_nor2 = true
                
            
            ----- 虹 二阶堂真红 ------
            
            
            elseif psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_wcbldsj_nor") and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_wcbldsg_nor") and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yrhtdsj_nor") and faction:has_effect_bundle("set_psw_tf_ex_btmmfs_2") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_btmmfs_3") then
                
                common.trigger_soundevent("ejtzh_3")
                advice_ejtzh_3_1()
                
                cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                    {
                    "psw_tf_ex_btmmfs_3"
                    }
                )
                psw_main_data.player_data[faction_name].ejtzh_jiyizhi = 100
                psw_delete_ancillary_with_time_delay(faction, "ejtzh_gqdrj", 0.1)
                cm:add_ancillary_to_faction(faction, "ejtzh_gqdrj_2", true)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_btmmfs_3", faction_name)
                
                psw_ejtzh_main_jyz(faction)
                psw_hh_start_btmmfs(faction_name)
                psw_add_hong_count(faction_name, 1)
                
                psw_add_jishu_zhongmo(5)
                psw_delete_shanbi_effect(faction_name, "jn_shanbi_ejtzh_sjgx")
                
            
            
            ----- 永不败北 ------
            
            elseif psw_faction_has_effect_bundle(faction_name, "ybbb_zzqz_wang_get") and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_ybbb_1") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_ybbb_2") then
                
                common.trigger_soundevent("ybbb_2")
                advice_psw_tf_ex_ybbb_2_1()
                
                cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                    {
                    "psw_tf_ex_ybbb_2"
                    }
                )
                cm:add_ancillary_to_faction(faction, "ybbb_huangguan", false)
                
                cm:remove_effect_bundle_from_character("jnz_tf_ex_psw_tf_ex_ybbb_1_1", psw_main_character);
                cm:remove_effect_bundle_from_character("jnz_tf_ex_psw_tf_ex_ybbb_1_2", psw_main_character);
                
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yxsldff_nor") then
                    cm:apply_effect_bundle_to_character("jnz_tf_ex_psw_tf_ex_ybbb_2_2", psw_main_character, 0);
                elseif 1 == 1 then
                    cm:apply_effect_bundle_to_character("jnz_tf_ex_psw_tf_ex_ybbb_2_1", psw_main_character, 0);
                end
                
                
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_ybbb_2", faction_name)
                
        ----- 虹 与游戏之神的对弈  ------
            
            elseif psw_faction_has_effect_bundle(faction_name, "ybbb_zzqz_wang_get") and psw_faction_has_effect_bundle(faction_name, "ybbb_zzqz_hou_get") and psw_faction_has_effect_bundle(faction_name, "ybbb_zzqz_xiang_get") and psw_faction_has_effect_bundle(faction_name, "ybbb_zzqz_ma_get") and psw_faction_has_effect_bundle(faction_name, "ybbb_zzqz_che_get") and psw_faction_has_effect_bundle(faction_name, "ybbb_zzqz_bing_get") and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_ybbb_2") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_ybbb_3") then
                
                common.trigger_soundevent("ybbb_3")
                advice_psw_tf_ex_ybbb_3_1()
                
                psw_add_jishu_miansi(faction_name, 2)
                
                cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                    {
                    "psw_tf_ex_ybbb_3"
                    }
                )
                psw_add_hong_count(faction_name, 1)
                
                cm:remove_effect_bundle_from_character("jnz_tf_ex_psw_tf_ex_ybbb_2_1", psw_main_character);
                cm:remove_effect_bundle_from_character("jnz_tf_ex_psw_tf_ex_ybbb_2_2", psw_main_character);
                
                cm:remove_effect_bundle_from_character("jnz_tf_ex_ybbb_xiang", psw_main_character);
                cm:remove_effect_bundle_from_character("jnz_tf_ex_ybbb_ma", psw_main_character);
                cm:remove_effect_bundle_from_character("jnz_tf_ex_ybbb_che", psw_main_character);
                cm:remove_effect_bundle_from_character("jnz_tf_ex_ybbb_bing", psw_main_character);
                
                cm:apply_effect_bundle_to_character("jnz_tf_ex_ybbb_xiang_2", psw_main_character, 0);
                cm:apply_effect_bundle_to_character("jnz_tf_ex_ybbb_ma_2", psw_main_character, 0);
                cm:apply_effect_bundle_to_character("jnz_tf_ex_ybbb_che_2", psw_main_character, 0);
                cm:apply_effect_bundle_to_character("jnz_tf_ex_ybbb_bing_2", psw_main_character, 0);
                
                psw_add_jishu_shenxing(faction_name, 2)
                psw_add_jishu_xingyun(faction_name, 2)
                
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yxsldff_nor") then
                    cm:apply_effect_bundle_to_character("jnz_tf_ex_psw_tf_ex_ybbb_3_2", psw_main_character, 0);
                elseif 1 == 1 then
                    cm:apply_effect_bundle_to_character("jnz_tf_ex_psw_tf_ex_ybbb_3_1", psw_main_character, 0);
                end
                
                psw_add_yctz_effect_to_faction(faction_name, "fyx")
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_ybbb_3", faction_name)
                cm:remove_effect_bundle("set_ybbb_xuyuan", faction_name)
                
                psw_add_jishu_zhongmo(5)
                psw_delete_shanbi_effect(faction_name, "jn_shanbi_ybbb_wydjy")
                
                
            ----- 真步真步王国的公主 ------
            
            elseif psw_meili >= 10 and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_zhenbu_1") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_zhenbu_2") then
                advice_zhenbu_2_1()
                
                
                local zhenbu_fac_list = cm:model():world():faction_list();
                for i = 0, zhenbu_fac_list:num_items() - 1 do
                    local crt_zhenbu_faction = zhenbu_fac_list:item_at(i);
                    local crt_zhenbu_faction_name = crt_zhenbu_faction:name();
                    if crt_zhenbu_faction:is_human() == true then
                        if crt_zhenbu_faction_name == faction_name then
                            psw_add_jishu_zhiyu(crt_zhenbu_faction_name, 5)
                        elseif 1 == 1 then
                            psw_add_jishu_zhiyu(crt_zhenbu_faction_name, 3)
                        end
                    end
                end

                cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                    {
                    "psw_tf_ex_zhenbu_2"
                    }
                )
                cm:add_ancillary_to_faction(faction, "zhenbu_cjthqz", false)
                
                cm:remove_effect_bundle_from_character("jnz_tf_ex_zhenbu_1", psw_main_character);
                cm:apply_effect_bundle_to_character("jnz_tf_ex_zhenbu_2", psw_main_character, 0);
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_zhenbu_2", faction_name)
                psw_add_jishu_meili(faction_name, 2)
                
                
                
                
                
                
                
                
                
                
        ----- 初始天赋 救济的魔女 ------
            elseif jishu_lmyx_wurandu >= 100 and faction:has_effect_bundle("hero_select_lmyx") and not faction:has_effect_bundle("set_cstf_lmyx_jjmn") and not faction:has_effect_bundle("set_cstf_lmyx_yhzl") then
                advice_lmyx_jjmn_heihua()
                cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                        {
                        "cstf_lmyx_jjmn"
                        }
                        )
                cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                        {
                        "cstf_lmyx_jjmn"
                        }
                        )
                cm:remove_effect_bundle_from_character("cstf_lmyx_mfsn", faction:faction_leader());
                cm:apply_effect_bundle_to_character("cstf_lmyx_jjmn", psw_main_character, 0);
                psw_aplly_costom_effect_bundle_hidden_fn("set_cstf_lmyx_jjmn", faction_name)
                psw_add_jishu_ewai_xingyun(faction_name, -5)
        ----- 初始天赋 圆环之理  ------
        
            elseif ((jishu_lmyx_lunhui >= 20) or (psw_shenxing >= 10)) and faction:has_effect_bundle("hero_select_lmyx") and not faction:has_effect_bundle("set_cstf_lmyx_yhzl") and not faction:has_effect_bundle("set_cstf_lmyx_jjmn") then
                advice_lmyx_cstf_yhzl()
                cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                        {
                        "cstf_lmyx_yhzl"
                        }
                        )
                cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                        {
                        "cstf_lmyx_yhzl"
                        }
                        )
                cm:remove_effect_bundle("cstf_lmyx_mfsn", faction_name)
                psw_add_jishu_shenxing(faction_name, 2)
                cm:apply_effect_bundle_to_character("cstf_lmyx_yhzl", psw_main_character, 0);
                psw_aplly_costom_effect_bundle_hidden("set_cstf_lmyx_yhzl", faction)
                psw_add_jishu_ewai_xingyun(faction_name, 5)
                
                
        ----- 游戏王 抽卡  ------
            elseif psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yqdjb_nor1") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_yqdjb_nor2") and not psw_faction_has_effect_bundle(faction_name, "set_yqdjb_yichouka") then
                psw_aplly_costom_effect_bundle_hidden_fn("set_yqdjb_yichouka", faction_name)
                psw_main_yqdjb_kachi(faction_name)
                
                
       
        
        ---------- 奇迹的魔法 许愿 ------------
            elseif psw_faction_has_effect_bundle(faction_name, "set_xxdqj_xuyuan") then
                cm:trigger_dilemma(faction_name, "dilemma_tf_xxdqj_xuyuan")
                cm:remove_effect_bundle("set_xxdqj_xuyuan", faction_name)
            
        ---------- 与游戏之神的对弈 许愿 ------------
            elseif ybbb_jishu_zhongzu > 0 and not psw_faction_has_effect_bundle(faction_name, "set_ybbb_xuyuan") and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_ybbb_3") then
                
                cm:trigger_dilemma(faction_name, "dilemma_tf_ybbb_jishu1")
                
                
                
        ---------- 幸运值抽奖 ------------
            elseif 1 == 1 then 
                local random_number_face = cm:random_number(100, 1)
                local xy_faction = cm:model():faction_for_command_queue_index(context:faction_cqi())
                local xy_xingyun = psw_resource_value(xy_faction, "psw_xingyun")
                local psw_ewai_xingyun = (psw_main_data.player_data[faction_name] or {}).psw_ewai_xingyun or 0
                local main_xingyunzhi = (psw_ewai_xingyun + xy_xingyun)
                if main_xingyunzhi > 25 then
                    main_xingyunzhi = 25
                end
                
                local turn_number = cm:turn_number()
                
                
                --------- 唯一物品抽奖 ---------
                if psw_main_qysj_cj >= 10 then
                    local jishu_heian =  psw_resource_value(faction, "jishu_heian")
                    local jishu_jingling = (psw_main_data.player_data[faction_name] or {}).jishu_jingling or 0
                    local psw_faction_list_cj = cm:model():world():faction_list()
                    local cj_xyz = (xy_xingyun*0.02)
                    local cj_moli = (psw_moli*0.10) + cj_xyz
                    if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_ex_pql") then
                        cj_moli = cj_moli * 2
                    end
                    local cj_jianshu = (psw_jianshu*0.10) + cj_xyz
                    local cj_heian = (jishu_heian*0.2) + cj_xyz
                    local cj_shenhai = (jishu_shenhai*0.2) + cj_xyz
                    local cj_xingyun = (xy_xingyun*0.10) + cj_xyz
                    local cj_all_2 = cj_moli + cj_jianshu
                    local cj_all_3 = cj_moli + cj_jianshu + cj_heian
                    local cj_all_4 = cj_moli + cj_jianshu + cj_heian + cj_shenhai
                    local cj_all_5 = cj_moli + cj_jianshu + cj_heian + cj_shenhai + cj_xingyun
                    local cj_all = cj_all_5 + 6
                    local random_number_cj_ex = cm:random_number(100, 1)
                    
                    local ex_xy10 = xy_xingyun >= 10 and not psw_faction_has_effect_bundle(faction_name, "set_main_xxdqj_1") and jishu_ex_count <= 1
                    local ex_ml10 = psw_moli >= 10 and not psw_faction_has_effect_bundle(faction_name, "set_main_zzhgt_1") and jishu_ex_count <= 1
                    local ex_jingling = jishu_jingling >= 4 and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_you_ex") and jishu_ex_count <= 1
                    local ex_jianshu = psw_jianshu >= 10 and not psw_faction_has_effect_bundle(faction_name, "set_main_qlwh_1") and jishu_ex_count <= 1
                    local ex_zhongduan = ex_xy10 or ex_ml10 or ex_jingling or ex_jianshu
                    
                    
                    if random_number_cj_ex <= cj_all then
                        if random_number_cj_ex <= cj_moli and not psw_main_data.global_data.set_ex_wy_xzzs then
                            if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_ex_pql") then
                                cm:add_ancillary_to_faction(faction, "ex_wy_xzzs", false)
                            else
                                cm:add_ancillary_to_faction(faction, "ex_wy_xzzs_wjx", false)
                            end
                            common.trigger_soundevent("alice_cj")
                            alice_cj_xzzs()

                            psw_add_jishu_zhongmo(1)
                            cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_event_bad", -10)
                            psw_main_data.global_data.set_ex_wy_xzzs = true
                            psw_aplly_costom_effect_bundle_hidden_fn("set_ex_wy_xzzs", faction_name)
                        elseif random_number_cj_ex <= cj_all_2 and random_number_cj_ex > cj_moli and not psw_main_data.global_data.set_ex_wy_zaz then
                            cm:add_ancillary_to_faction(faction, "ex_wy_zaz_wjx", false)
                            common.trigger_soundevent("alice_cj")
                            alice_cj_zaz()

                            psw_add_jishu_zhongmo(1)
                            cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_event_bad", -10)
                            psw_main_data.global_data.set_ex_wy_zaz = true
                        elseif random_number_cj_ex <= cj_all_3 and random_number_cj_ex > cj_all_2 and not psw_main_data.global_data.set_ex_wy_sss then
                            cm:add_ancillary_to_faction(faction, "ex_wy_sss_wjx", false)
                            common.trigger_soundevent("alice_cj")
                            alice_cj_sss()

                            psw_add_jishu_zhongmo(1)
                            cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_event_bad", -10)
                            psw_main_data.global_data.set_ex_wy_sss = true
                        elseif random_number_cj_ex <= cj_all_4 and random_number_cj_ex > cj_all_3 and not psw_main_data.global_data.set_ex_wy_hhjj then
                            cm:add_ancillary_to_faction(faction, "ex_wy_hhjj_wjx", false)
                            common.trigger_soundevent("alice_cj")
                            alice_cj_hhjj()

                            psw_add_jishu_zhongmo(1)
                            cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_event_bad", -10)
                            psw_main_data.global_data.set_ex_wy_hhjj = true
                        elseif random_number_cj_ex <= cj_all_5 and random_number_cj_ex > cj_all_4 and not psw_main_data.global_data.set_ex_wy_xwzm then
                            cm:add_ancillary_to_faction(faction, "ex_wy_xwzm_wjx", false)
                            common.trigger_soundevent("alice_cj")
                            alice_cj_xwzm()

                            psw_add_jishu_zhongmo(1)
                            cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_event_bad", -10)
                            psw_main_data.global_data.set_ex_wy_xwzm = true
                        elseif random_number_cj_ex <= (cj_all_5 + 2) and random_number_cj_ex > cj_all_5 and not psw_main_data.global_data.set_ex_wy_yfdxz then
                            for i = 0, psw_faction_list_cj:num_items() - 1 do
                                local current_faction_1 = psw_faction_list_cj:item_at(i);
                                if current_faction_1:is_human() then
                                    cm:add_ancillary_to_faction(current_faction_1, "ex_wy_yfdxz", false)
                                end
                            end
                            
                            common.trigger_soundevent("alice_cj")
                            alice_cj_yfdxz()
                            cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_event_bad", -10)
                            psw_main_data.global_data.set_ex_wy_yfdxz = true
                        elseif random_number_cj_ex <= (cj_all_5 + 4) and random_number_cj_ex > (cj_all_5 + 2) and not psw_main_data.global_data.set_ex_wy_yfdxz2 then
                            for i = 0, psw_faction_list_cj:num_items() - 1 do
                                local current_faction_2 = psw_faction_list_cj:item_at(i);
                                if current_faction_2:is_human() then
                                    cm:add_ancillary_to_faction(current_faction_2, "ex_wy_yfdxz", false)
                                end
                            end
                            common.trigger_soundevent("alice_cj")
                            alice_cj_yfdxz()
                            cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_event_bad", -10)
                            psw_main_data.global_data.set_ex_wy_yfdxz2 = true
                            
                        elseif random_number_cj_ex <= cj_all and random_number_cj_ex > (cj_all_5 + 4) and not psw_main_data.global_data.set_ex_wy_zxqj then
                            for i = 0, psw_faction_list_cj:num_items() - 1 do
                                local current_faction_3 = psw_faction_list_cj:item_at(i);
                                if current_faction_3:is_human() then
                                    cm:add_ancillary_to_faction(current_faction_3, "ex_wy_zxqj", false)
                                end
                            end
                            
                            common.trigger_soundevent("alice_cj")
                            alice_cj_zxqj()
                            cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_event_bad", -10)
                            psw_main_data.global_data.set_ex_wy_zxqj = true
                            
                        elseif 1 == 1 then
                            alice_main_advice_cj_kongqi()
                            cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_event_bad", -10)
                        end
                    elseif random_number_cj_ex > cj_all then
                        local random_number_cj_nor = cm:random_number(100, 1)
                        if random_number_cj_nor <= 6 and not psw_faction_has_effect_bundle(faction_name, "set_psw_cj_2meili") then
                            psw_add_jishu_meili(faction_name, 2)
                            alice_main_advice_cj_2meili()
                            
                            cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_event_bad", -10)
                            psw_aplly_costom_effect_bundle_hidden_fn("set_psw_cj_2meili", faction_name)
                            
                        elseif random_number_cj_nor <= 12 and random_number_cj_nor > 6 and not psw_faction_has_effect_bundle(faction_name, "set_psw_cj_2moli") then
                            
                            psw_add_jishu_moli(faction_name, 2)
                            cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_event_bad", -10)
                            alice_main_advice_cj_2moli()
                            
                            psw_aplly_costom_effect_bundle_hidden_fn("set_psw_cj_2moli", faction_name)
                            
                        elseif random_number_cj_nor <= 18 and random_number_cj_nor > 12 and not psw_faction_has_effect_bundle(faction_name, "set_psw_cj_2jianshu") then
                            
                            psw_add_jishu_jianshu(faction_name, 2)
                            
                            alice_main_advice_cj_2jianshu()
                            
                            cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_event_bad", -10)
                            psw_aplly_costom_effect_bundle_hidden_fn("set_psw_cj_2jianshu", faction_name)
                        
                        elseif random_number_cj_nor <= 24 and random_number_cj_nor > 18 and not psw_faction_has_effect_bundle(faction_name, "set_psw_cj_2zhixing") then
                            
                            psw_add_jishu_zhixing(faction_name, 2)
                            alice_main_advice_cj_2zhixing()
                            
                            cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_event_bad", -10)
                            psw_aplly_costom_effect_bundle_hidden_fn("set_psw_cj_2zhixing", faction_name)
                            
                        elseif random_number_cj_nor <= 30 and random_number_cj_nor > 24 and not psw_faction_has_effect_bundle(faction_name, "set_psw_cj_2zhiyu") then
                            
                            psw_add_jishu_zhiyu(faction_name, 2)
                            alice_main_advice_cj_2zhiyu()
                            
                            cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_event_bad", -10)
                            psw_aplly_costom_effect_bundle_hidden_fn("set_psw_cj_2zhiyu", faction_name)
                            
                        elseif random_number_cj_nor <= 80 and random_number_cj_nor > 30 then
                        
                            alice_main_advice_cj_kongqi()
                            cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_event_bad", -10)
                            
                        elseif random_number_cj_nor <= 90 and random_number_cj_nor > 80 then
                        
                            cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_event_good", 2)
                            cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_event_bad", -10)
                            alice_main_advice_cj_2sj()
                            
                        elseif random_number_cj_nor <= 94 and random_number_cj_nor > 90 then
                        
                            cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_event_good", 5)
                            cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_event_bad", -10)
                            alice_main_advice_cj_5sj()
                            
                        elseif random_number_cj_nor <= 97 and random_number_cj_nor > 94 then
                        
                            cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_event_good", 10)
                            cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_event_bad", -10)
                            alice_main_advice_cj_10sj()
                            
                        elseif random_number_cj_nor <= 99 and random_number_cj_nor > 97 then
                        
                            cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_event_good", 20)
                            cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_event_bad", -10)
                            alice_main_advice_cj_20sj()
                            
                        elseif random_number_cj_nor <= 100 and random_number_cj_nor > 99 then
                        
                            cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_event_good", 50)
                            cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_event_bad", -10)
                            alice_main_advice_cj_50sj()
                            
                        elseif 1 == 1 then
                            alice_main_advice_cj_kongqi()
                            cm:faction_add_pooled_resource(faction_name, "psw_main_qysj", "psw_main_qysj_event_bad", -10)
                        end
                    end
                
                        
                
                     
                ------------------
                end
                if psw_main_qysj_click >= 0 and (not psw_faction_has_effect_bundle(faction_name, "psw_yi_p1ck") or can_repick) then
                
                    -- fallback：如果已经在 dilemma 里直接抽过了，只清标记、不再重复抽
                    local _pd = psw_main_data.player_data[faction_name] or {}
                    if _pd.psw_25hh_auto_drawn then
                        _pd.psw_25hh_auto_drawn = false
                        out("PSW 25hh button: skipping double draw, already done in dilemma")
                    else
                        cm:faction_add_pooled_resource(faction_name, "psw_main_gmsj", "psw_main_gmsj_event_bad", pickup_use)
                        psw_main_pickup(faction_name)
                    end
                
                    
                elseif psw_faction_has_effect_bundle(faction_name, "psw_yi_p1ck") then
                    advice_alice_tf_xnd()
                elseif psw_main_qysj_click >= 0 then
                    cm:faction_add_pooled_resource(faction_name, "psw_main_gmsj", "psw_main_gmsj_event_bad", pickup_use)
                    advice_alice_tf_kongqi()
                end
            
            
            
            
    ----- end ------
            end
        end

    end),
    true
)

local function is_hero_have_select(hero_key)
    local is_have_select = false
    local pool = psw_main_data.global_data.psw_hero_pool
    if not pool or not pool[hero_key] then
        return false
    end
    if pool[hero_key].num <= 0 then
        is_have_select = true
    end
    return is_have_select
end
core:add_listener(
    "psw_dilemma_choice_yxxz",
    "DilemmaChoiceMadeEvent",
    function(context)
        return context:dilemma():starts_with("dilemma_yxxz");
    end,
	psw_pcall_wrapper(function(context)
        local faction_name = context:faction():name()
        psw_ensure_player_data(faction_name)
        
        local dilemma_key = context:dilemma();
        local choice = context:choice_key();
        local yx_name
        if dilemma_key == "dilemma_yxxz_psw_yxxz_sfsj" and choice == "FIRST" then
            cm:trigger_dilemma(faction_name, "dilemma_yxxz_psw_yxxz_zixuan")
        elseif dilemma_key == "dilemma_yxxz_psw_yxxz_sfsj" and choice == "SECOND" then
            psw_hero_creat_suiji(faction_name)

        elseif dilemma_key == "dilemma_yxxz_psw_yxxz_zixuan" and choice == "FIRST" then
            yx_name = "yx_lmyx"
        elseif dilemma_key == "dilemma_yxxz_psw_yxxz_zixuan" and choice == "SECOND" then
            yx_name = "yx_hero_sllh"
        elseif dilemma_key == "dilemma_yxxz_psw_yxxz_zixuan" and choice == "THIRD" then
            yx_name = "yx_hero_edu"
        elseif dilemma_key == "dilemma_yxxz_psw_yxxz_zixuan" and choice == "FOURTH" then
            yx_name = "yx_hero_niao"
        elseif dilemma_key == "dilemma_yxxz_psw_yxxz_zixuan" and choice == "FIFTH" then
            yx_name = "yx_hero_fuxuan"
        elseif dilemma_key == "dilemma_yxxz_psw_yxxz_zixuan" and choice == "SIXTH" then
            yx_name = "yx_hero_feibi"
        elseif dilemma_key == "dilemma_yxxz_psw_yxxz_zixuan" and choice == "SEVENTH" then
            yx_name = "yx_hero_xueli"
        elseif dilemma_key == "dilemma_yxxz_psw_yxxz_zixuan" and choice == "EIGHTH" then
            yx_name = "yx_hero_mika"
        end
        if dilemma_key == "dilemma_yxxz_psw_yxxz_zixuan" then
            local is_have_select = is_hero_have_select(yx_name)
            if is_have_select then
                alice_hero_have_select()
                cm:trigger_dilemma(faction_name, "dilemma_yxxz_psw_yxxz_zixuan")
            else
                psw_hero_creat_zixuan(faction_name, yx_name)
            end
        end
	end),
	true
)

local edu_cmcd = {
    "advice_edu_cmcd_1",
    "advice_edu_cmcd_2",
    "advice_edu_cmcd_3",
    "advice_edu_cmcd_4",
    "advice_edu_cmcd_5",
    
            
}

--- 菲娅-唯一装备获取 ---


function fia_wyzb_hq(faction_name, is_yiwu)
    local faction = cm:get_faction(faction_name)
    local fia_wyzb_pool = {}
    if not is_yiwu then
        if not psw_main_data.global_data.set_ex_wy_xzzs then
            table.insert(fia_wyzb_pool, "ex_wy_xzzs_wjx")
        end
        if not psw_main_data.global_data.set_ex_wy_zaz then
            table.insert(fia_wyzb_pool, "ex_wy_zaz_wjx")
        end
        if not psw_main_data.global_data.set_ex_wy_sss then
            table.insert(fia_wyzb_pool, "ex_wy_sss_wjx")
        end
        if not psw_main_data.global_data.set_ex_wy_hhjj then
            table.insert(fia_wyzb_pool, "ex_wy_hhjj_wjx")
        end
        if not psw_main_data.global_data.set_ex_wy_xwzm then
            table.insert(fia_wyzb_pool, "ex_wy_xwzm_wjx")
        end
        if not psw_main_data.global_data.set_ex_wy_yfdxz or not psw_main_data.global_data.set_ex_wy_yfdxz2 then
            table.insert(fia_wyzb_pool, "ex_wy_yfdxz")
        end
        if not psw_main_data.global_data.set_ex_wy_zxqj then
            table.insert(fia_wyzb_pool, "ex_wy_zxqj")
        end
    elseif is_yiwu then
        if not psw_main_data.global_data.set_psw_moyin_ex_tymt then
            table.insert(fia_wyzb_pool, "psw_moyin_ex_tymt")
        end
        if not psw_main_data.global_data.set_psw_moyin_ex_xzc then
            table.insert(fia_wyzb_pool, "psw_moyin_ex_xzc")
        end
        if not psw_main_data.global_data.set_psw_moyin_ex_szs then
            table.insert(fia_wyzb_pool, "psw_moyin_ex_szs")
        end
        if not psw_main_data.global_data.set_psw_moyin_ex_hsl then
            table.insert(fia_wyzb_pool, "psw_moyin_ex_hsl")
        end
        if not psw_main_data.global_data.set_psw_moyin_ex_rszw then
            table.insert(fia_wyzb_pool, "psw_moyin_ex_rszw")
        end
    end
    if #fia_wyzb_pool <= 0 then
        return
    end
    if not is_yiwu then
        common.trigger_soundevent("alice_cj")
    end
    
    psw_add_jishu_zhongmo(1)
    
    local index = cm:random_number(#fia_wyzb_pool)
    local psw_ex_ancillary
    psw_ex_ancillary = fia_wyzb_pool[index]
    
    
    if psw_ex_ancillary == "ex_wy_xzzs_wjx" then
        psw_main_data.global_data.set_ex_wy_xzzs = true
        alice_cj_xzzs()
    elseif psw_ex_ancillary == "ex_wy_zaz_wjx" then
        psw_main_data.global_data.set_ex_wy_zaz = true
        alice_cj_zaz()
    elseif psw_ex_ancillary == "ex_wy_sss_wjx" then
        psw_main_data.global_data.set_ex_wy_sss = true
        alice_cj_sss()
    elseif psw_ex_ancillary == "ex_wy_hhjj_wjx" then
        psw_main_data.global_data.set_ex_wy_hhjj = true
        alice_cj_hhjj()
    elseif psw_ex_ancillary == "ex_wy_xwzm_wjx" then
        psw_main_data.global_data.set_ex_wy_xwzm = true
        alice_cj_xwzm()
    elseif psw_ex_ancillary == "ex_wy_yfdxz" then
        if not psw_main_data.global_data.set_ex_wy_yfdxz then
            psw_main_data.global_data.set_ex_wy_yfdxz = true
        elseif not psw_main_data.global_data.set_ex_wy_yfdxz2 then
            psw_main_data.global_data.set_ex_wy_yfdxz2 = true
        end
        alice_cj_yfdxz()
    elseif psw_ex_ancillary == "ex_wy_zxqj" then
        psw_main_data.global_data.set_ex_wy_zxqj = true
        alice_cj_zxqj()
    end
    if psw_ex_ancillary:starts_with("psw_moyin_ex_") then
        local faction_list = cm:model():world():faction_list();
        for k = 0, faction_list:num_items() - 1 do
            local current_faction_human = faction_list:item_at(k);
            if current_faction_human:is_human() then
                cm:add_ancillary_to_faction(current_faction_human, psw_ex_ancillary, false)
            end
        end
        if psw_ex_ancillary == "psw_moyin_ex_tymt" then
            psw_main_data.global_data.set_psw_moyin_ex_tymt = true
        elseif psw_ex_ancillary == "psw_moyin_ex_xzc" then
            psw_main_data.global_data.set_psw_moyin_ex_xzc = true
        elseif psw_ex_ancillary == "psw_moyin_ex_szs" then
            psw_main_data.global_data.set_psw_moyin_ex_szs = true
        elseif psw_ex_ancillary == "psw_moyin_ex_hsl" then
            psw_main_data.global_data.set_psw_moyin_ex_hsl = true
        elseif psw_ex_ancillary == "psw_moyin_ex_rszw" then
            psw_main_data.global_data.set_psw_moyin_ex_rszw = true
        end
    else
        cm:add_ancillary_to_faction(faction, psw_ex_ancillary, false)
    end
end
---天气池子
local psw_nandu_yb_jnz_poor = {
    "psw_main_ybdtq_fengyu",
    "psw_main_ybdtq_chunxue",
    "psw_main_ybdtq_leibao",
    "psw_main_ybdtq_shuyu",
    "psw_main_ybdtq_lieri",
    "psw_main_ybdtq_huatan",
    "psw_main_ybdtq_shuangdong",
    "psw_main_ybdtq_dawu",
    "psw_main_ybdtq_qinglan",
    "psw_main_ybdtq_tantian",
    "psw_main_ybdtq_cangtian",
    "psw_main_ybdtq_chunxue_bzyj",
    "psw_main_ybdtq_shuangdong_bzyj",
    "psw_main_ybdtq_fengyu_paojie",
    "psw_main_ybdtq_leibao_paojie",
    "psw_main_ybdtq_yongye",
    "psw_main_ybdtq_yongye_tianqi",
    "psw_main_ybdtq_chuji",
    "psw_main_ybdtq_xueyu",
    "psw_main_ybdtq_fuyun",
    "psw_main_ybdtq_yuyu",
    "psw_main_ybdtq_huanwu",
    "psw_main_ybdtq_xueyu_ss",
    "psw_main_ybdtq_fuyun_ss",
    "psw_main_ybdtq_yuyu_ss",
    "psw_main_ybdtq_huanwu_ss",
    "psw_main_ybdtq_qiyu",
}
--- 菲娅-众神眷恋的幻想乡 ---
function fia_zsjldhxx()
    local fac_list = cm:model():world():faction_list();
    for i = 1, #psw_nandu_yb_jnz_poor do
        local remove_bundle = psw_nandu_yb_jnz_poor[i]
        for i = 0, fac_list:num_items() - 1 do
            local current_faction = fac_list:item_at(i);
            if current_faction:is_human() == true then
                if current_faction:has_effect_bundle(remove_bundle) then
                    cm:remove_effect_bundle(remove_bundle, current_faction:name())
                    cm:apply_effect_bundle("nandu_yb_zsjldhxx", current_faction:name(), 4)
                end
            end
        end
    end
    alice_nandu_zsjldhxx()
end
---祈雨之歌
function psw_dlc7_qiyu_effect()
    local fac_list = cm:model():world():faction_list();
    for i = 1, #psw_nandu_yb_jnz_poor do
        local remove_bundle = psw_nandu_yb_jnz_poor[i]
        for i = 0, fac_list:num_items() - 1 do
            local current_faction = fac_list:item_at(i);
            if current_faction:is_human() == true then
                if current_faction:has_effect_bundle(remove_bundle) then
                    cm:remove_effect_bundle(remove_bundle, current_faction:name())
                    cm:apply_effect_bundle("psw_main_ybdtq_qiyu", current_faction:name(), 4)
                end
            end
        end
    end
    alice_nandu_qiyu()
end


        
core:add_listener(
    "psw_dilemma_choice_made_effect",
    "DilemmaChoiceMadeEvent",
    function(context)
        return context:dilemma():starts_with("dilemma_tf_");
    end,
	psw_pcall_wrapper(function(context)
        local faction_name = context:faction():name()
        psw_ensure_player_data(faction_name)
        local faction = cm:get_faction(faction_name)
        local faction_leader = faction:faction_leader()
        local dilemma_key = context:dilemma();
        local choice = context:choice_key();
        local psw_faction_list = cm:model():world():faction_list();
        local turn = cm:turn_number()
        
        local yx_subtype = psw_get_any(faction_name, "yx_subtype")
        local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
        
        local jishu_zhongmo = psw_main_data.global_data.jishu_zhongmo
        
        local jishu_shen = psw_get_num(faction_name, "jishu_shen")
        local nor_count = psw_get_num(faction_name, "nor_count")
        local ex_count = psw_get_num(faction_name, "ex_count")
        local jishu_miansi = psw_get_num(faction_name, "jishu_miansi")
        
        local jishu_ex_count = psw_get_num(faction_name, "jishu_ex_count")
        local fia_main_js = psw_get_num(faction_name, "fia_main_js")
        local fia_xiaohao_js = psw_get_num(faction_name, "fia_xiaohao_js")
        local fia_kyjs = fia_main_js - fia_xiaohao_js
        local tfmw_is_start = psw_main_data.global_data.tfmw_is_start
        local mowang_faction_key = nil
        local mw_faction
        if tfmw_is_start then
            mowang_faction_key = psw_mowang_data.mowang_faction_key
            mw_faction = cm:get_faction(mowang_faction_key)
        end
        
------------------ 种族计数 --------------------
        if dilemma_key == "dilemma_tf_ybbb_jishu1" and choice == "FIRST" then
            psw_add_jishu_guangmi(faction_name, 1)
            psw_add_jishu_ybbb_zhongzu(faction_name, -1)
        elseif dilemma_key == "dilemma_tf_ybbb_jishu1" and choice == "SECOND" then
            psw_add_jishu_heian(faction_name, 1)
            psw_add_jishu_ybbb_zhongzu(faction_name, -1)
        elseif dilemma_key == "dilemma_tf_ybbb_jishu1" and choice == "THIRD" then
            psw_add_jishu_shenhai(faction_name, 1)
            psw_add_jishu_ybbb_zhongzu(faction_name, -1)
        elseif dilemma_key == "dilemma_tf_ybbb_jishu1" and choice == "FOURTH" then
            psw_add_jishu_bing(faction_name, 1)
            psw_add_jishu_ybbb_zhongzu(faction_name, -1)
        elseif dilemma_key == "dilemma_tf_ybbb_jishu1" and choice == "FIFTH" then
            cm:trigger_dilemma(faction_name, "dilemma_tf_ybbb_jishu2")
        elseif dilemma_key == "dilemma_tf_ybbb_jishu2" and choice == "FIRST" then
            psw_add_jishu_long(faction_name, 1)
            psw_add_jishu_ybbb_zhongzu(faction_name, -1)
        elseif dilemma_key == "dilemma_tf_ybbb_jishu2" and choice == "SECOND" then
            psw_add_jishu_shen(faction_name, 1)
            psw_add_jishu_ybbb_zhongzu(faction_name, -1)
        elseif dilemma_key == "dilemma_tf_ybbb_jishu2" and choice == "THIRD" then
            psw_add_jishu_jingling(faction_name, 1)
            psw_add_jishu_ybbb_zhongzu(faction_name, -1)
        elseif dilemma_key == "dilemma_tf_ybbb_jishu2" and choice == "FOURTH" then
            psw_add_jishu_mofashaonv(faction_name, 1)
            psw_add_jishu_ybbb_zhongzu(faction_name, -1)
        elseif dilemma_key == "dilemma_tf_ybbb_jishu2" and choice == "FIFTH" then
            psw_aplly_costom_effect_bundle_hidden_fn("set_ybbb_xuyuan", faction_name)
        
        
------------------ 菲娅的祝福 --------------------
        
        elseif dilemma_key == "dilemma_tf_fia_fydzf_1" and choice == "FIRST" then
            if fia_kyjs < 30 then
                return
            end
            fia_xiaohao_js = fia_xiaohao_js + 30
            psw_add_ex_limit_jiefang(faction_name)

            psw_aplly_costom_effect_bundle_hidden_fn("set_qiyuan_100ex", faction_name)
                

        
        elseif dilemma_key == "dilemma_tf_fia_fydzf_1" and choice == "SECOND" then
            if fia_kyjs < 30 then
                return
            end
            fia_xiaohao_js = fia_xiaohao_js + 30
            psw_aplly_costom_effect_bundle_hidden_fn("set_qiyuan_100zt", faction_name)
        elseif dilemma_key == "dilemma_tf_fia_fydzf_1" and choice == "THIRD" then
            if fia_kyjs < 30 then
                return
            end
            fia_xiaohao_js = fia_xiaohao_js + 30
            cm:trigger_dilemma(faction_name, "dilemma_tf_fia_yiwu_or_wp")
            
            
        elseif dilemma_key == "dilemma_tf_fia_yiwu_or_wp" and choice == "FIRST" then
            fia_wyzb_hq(faction_name, false)
            
        elseif dilemma_key == "dilemma_tf_fia_yiwu_or_wp" and choice == "SECOND" then
            fia_wyzb_hq(faction_name, true)
            
        elseif dilemma_key == "dilemma_tf_fia_fydzf_1" and choice == "FOURTH" then
            if fia_kyjs < 15 then
                return
            end
            fia_xiaohao_js = fia_xiaohao_js + 15
            fia_zsjldhxx()
        elseif dilemma_key == "dilemma_tf_fia_fydzf_1" and choice == "FIFTH" then
            if fia_kyjs < 15 then
                return
            end
            fia_xiaohao_js = fia_xiaohao_js + 15
            psw_add_jishu_shenxing(faction_name, 1)
        elseif dilemma_key == "dilemma_tf_fia_fydzf_1" and choice == "SIXTH" then
            cm:trigger_dilemma(faction_name, "dilemma_tf_fia_fydzf_2")
        
        
        elseif dilemma_key == "dilemma_tf_fia_fydzf_2" and choice == "FIRST" then
            if fia_kyjs < 10 then
                return
            end
            psw_add_jishu_xingyun(faction_name, 1)
        elseif dilemma_key == "dilemma_tf_fia_fydzf_2" and choice == "SECOND" then
            if fia_kyjs < 10 then
                return
            end
            fia_xiaohao_js = fia_xiaohao_js + 10
            psw_add_jishu_zhixing(faction_name, 1)
        elseif dilemma_key == "dilemma_tf_fia_fydzf_2" and choice == "THIRD" then
            if fia_kyjs < 10 then
                return
            end
            fia_xiaohao_js = fia_xiaohao_js + 10
            psw_add_jishu_moli(faction_name, 1)
        elseif dilemma_key == "dilemma_tf_fia_fydzf_2" and choice == "FOURTH" then
            if fia_kyjs < 10 then
                return
            end
            fia_xiaohao_js = fia_xiaohao_js + 10
            psw_add_jishu_jianshu(faction_name, 1)
        elseif dilemma_key == "dilemma_tf_fia_fydzf_2" and choice == "FIFTH" then
            if fia_kyjs < 10 then
                return
            end
            fia_xiaohao_js = fia_xiaohao_js + 10
            psw_add_jishu_meili(faction_name, 1)
        elseif dilemma_key == "dilemma_tf_fia_fydzf_2" and choice == "SIXTH" then
            if fia_kyjs < 10 then
                return
            end
            fia_xiaohao_js = fia_xiaohao_js + 10
            psw_add_jishu_zhiyu(faction_name, 1)
            
            
------------------ 终末抉择 --------------------
        elseif dilemma_key == "dilemma_tf_psw_main_zmjz" and choice == "FIRST" then
            advice_psw_zmjz_n1()
            psw_main_data.global_data.set_psw_main_zmjz_n1 = true
            psw_main_data.global_data.set_psw_main_zmjz_n2 = false
            psw_main_data.global_data.set_psw_main_zmjz_n3 = false
            psw_main_data.global_data.set_psw_main_zmjz_n4 = false
            psw_main_data.global_data.set_psw_main_zmjz_n5 = false
        --elseif dilemma_key == "dilemma_tf_psw_main_zmjz" and choice == "SECOND" and psw_main_data.global_data.set_psw_main_nandu2 then
        elseif dilemma_key == "dilemma_tf_psw_main_zmjz" and choice == "SECOND" then
            advice_psw_zmjz_n2()
            psw_main_data.global_data.set_psw_main_zmjz_n1 = false
            psw_main_data.global_data.set_psw_main_zmjz_n2 = true
            psw_main_data.global_data.set_psw_main_zmjz_n3 = false
            psw_main_data.global_data.set_psw_main_zmjz_n4 = false
            psw_main_data.global_data.set_psw_main_zmjz_n5 = false
        --elseif dilemma_key == "dilemma_tf_psw_main_zmjz" and choice == "THIRD" and psw_main_data.global_data.set_psw_main_nandu3 and jishu_zhongmo >= 15 then
        elseif dilemma_key == "dilemma_tf_psw_main_zmjz" and choice == "THIRD" then
            advice_psw_zmjz_n3()
            psw_main_data.global_data.set_psw_main_zmjz_n1 = false
            psw_main_data.global_data.set_psw_main_zmjz_n2 = false
            psw_main_data.global_data.set_psw_main_zmjz_n3 = true
            psw_main_data.global_data.set_psw_main_zmjz_n4 = false
            psw_main_data.global_data.set_psw_main_zmjz_n5 = false
        elseif dilemma_key == "dilemma_tf_psw_main_zmjz" and choice == "FOURTH" then
        --elseif dilemma_key == "dilemma_tf_psw_main_zmjz" and choice == "FOURTH" and psw_main_data.global_data.set_psw_main_nandu4 and jishu_zhongmo >= 20 then
            advice_psw_zmjz_n4()
            psw_main_data.global_data.set_psw_main_zmjz_n1 = false
            psw_main_data.global_data.set_psw_main_zmjz_n2 = false
            psw_main_data.global_data.set_psw_main_zmjz_n3 = false
            psw_main_data.global_data.set_psw_main_zmjz_n4 = true
            psw_main_data.global_data.set_psw_main_zmjz_n5 = false
        --elseif dilemma_key == "dilemma_tf_psw_main_zmjz" and choice == "FIFTH" and psw_main_data.global_data.set_psw_main_nandu5 and jishu_zhongmo >= 25 then
        elseif dilemma_key == "dilemma_tf_psw_main_zmjz" and choice == "FIFTH" then
            advice_psw_zmjz_n5()
            psw_main_data.global_data.set_psw_main_zmjz_n1 = false
            psw_main_data.global_data.set_psw_main_zmjz_n2 = false
            psw_main_data.global_data.set_psw_main_zmjz_n3 = false
            psw_main_data.global_data.set_psw_main_zmjz_n4 = false
            psw_main_data.global_data.set_psw_main_zmjz_n5 = true
        


------------------ 难度选择 --------------------

        elseif dilemma_key == "dilemma_tf_psw_main_nandu" and choice == "FIRST" then
            psw_main_data.global_data.set_psw_main_nandu1 = true
            alice_nandu_tishi1()
            cm:callback(function()
                game_start_moyin_apply()
            end, 1)
        elseif dilemma_key == "dilemma_tf_psw_main_nandu" and choice == "SECOND" then
            psw_main_data.global_data.set_psw_main_nandu2 = true
            alice_nandu_tishi2()
            cm:callback(function()
                game_start_moyin_apply()
            end, 1)
            cm:trigger_dilemma(faction_name, "dilemma_tf_nandu_tianqi_jueze")
        elseif dilemma_key == "dilemma_tf_psw_main_nandu" and choice == "THIRD" then
            cm:trigger_dilemma(faction_name, "dilemma_tf_psw_boss_nandu")
            psw_main_data.global_data.set_psw_main_nandu2 = true
            psw_main_data.global_data.set_psw_main_nandu3 = true
            alice_nandu_tishi3()
            cm:callback(function()
                game_start_moyin_apply()
                
            end, 1)
            for i = 0, psw_faction_list:num_items() - 1 do
                local current_faction = psw_faction_list:item_at(i);
                local ai_faction_name = current_faction:name();
                if current_faction:is_human() == false then
                    psw_jichu_effect_nandu4_AI(ai_faction_name)
                elseif current_faction:is_human() == true then
                    psw_jichu_effect_nandu4(ai_faction_name)
                end
            end
        elseif dilemma_key == "dilemma_tf_psw_main_nandu" and choice == "FOURTH" then
            cm:trigger_dilemma(faction_name, "dilemma_tf_psw_boss_nandu")
            psw_main_data.global_data.set_psw_main_nandu2 = true
            psw_main_data.global_data.set_psw_main_nandu3 = true
            psw_main_data.global_data.set_psw_main_nandu4 = true
            alice_nandu_tishi4()
            cm:callback(function()
                game_start_moyin_apply()
                
            end, 1)
            for i = 0, psw_faction_list:num_items() - 1 do
                local current_faction = psw_faction_list:item_at(i);
                local ai_faction_name = current_faction:name();
                if current_faction:is_human() == false then
                    psw_jichu_effect_nandu4_AI(ai_faction_name)
                elseif current_faction:is_human() == true then
                    psw_jichu_effect_nandu4(ai_faction_name)
                end
            end
            
        elseif dilemma_key == "dilemma_tf_psw_main_nandu" and choice == "FIFTH" then
            cm:trigger_dilemma(faction_name, "dilemma_tf_psw_boss_nandu")
            psw_main_data.global_data.set_psw_main_nandu2 = true
            psw_main_data.global_data.set_psw_main_nandu3 = true
            psw_main_data.global_data.set_psw_main_nandu4 = true
            psw_main_data.global_data.set_psw_main_nandu5 = true
            alice_nandu_tishi5()
            cm:callback(function()
                game_start_moyin_apply()
                
            end, 1)
            for i = 0, psw_faction_list:num_items() - 1 do
                local current_faction = psw_faction_list:item_at(i);
                local ai_faction_name = current_faction:name();
                if current_faction:is_human() == false then
                    psw_jichu_effect_nandu4_AI(ai_faction_name)
                elseif current_faction:is_human() == true then
                    psw_jichu_effect_nandu4(ai_faction_name)
                end
                
            end
        ---自选还是随机魔王派系
        elseif dilemma_key == "dilemma_tf_psw_boss_nandu" and choice == "FIRST" then
            cm:trigger_dilemma(faction_name, "dilemma_tf_psw_boss_nandu_suiji")
            
        elseif dilemma_key == "dilemma_tf_psw_boss_nandu" and choice == "SECOND" then
        
            psw_main_mowang_initial()
            cm:trigger_dilemma(faction_name, "dilemma_tf_nandu_tianqi_jueze")
        ---自选魔王派系
        elseif dilemma_key == "dilemma_tf_psw_boss_nandu_suiji" then
            psw_main_mowang_initial_zixuan(choice)
            cm:trigger_dilemma(faction_name, "dilemma_tf_nandu_tianqi_jueze")
        ---
        
        elseif dilemma_key == "dilemma_tf_nandu_tianqi_jueze" and choice == "FIRST" then
            psw_main_data.global_data.set_psw_tianqi_ms_start = true
            cm:callback(function()
                alice_nandu_tianqi_start()
            end, 1)
            psw_dlc6_tianqi_ms_effect_apply()
        elseif dilemma_key == "dilemma_tf_nandu_tianqi_jueze" and choice == "SECOND" then
            psw_main_data.global_data.set_psw_tianqi_ms_start = false
            cm:callback(function()
                alice_nandu_tianqi_off()
            end, 1)
            
------------------ 世界BOSS传送 --------------------
        elseif dilemma_key == "dilemma_tf_duoren_tp" and choice == "FIRST" then
            local faction_leader_x, faction_leader_y = cm:find_valid_spawn_location_for_character_from_character(faction_name, cm:char_lookup_str(faction_leader), true, 1)
            
            local boss_current_x = psw_main_data.global_data.jws_boss_location_x
            local boss_current_y = psw_main_data.global_data.jws_boss_location_y
            local boss_tp_num = psw_mowang_data.tp_boss_num
            if boss_tp_num == 2 then
                boss_current_x = psw_main_data.global_data.sznw_boss_location_x
                boss_current_y = psw_main_data.global_data.sznw_boss_location_y
                psw_main_data.global_data.psw_tfmw_is_tp_boss2 = true
            elseif boss_tp_num == 3 then
                boss_current_x = psw_main_data.global_data.lyzm_boss_location_x
                boss_current_y = psw_main_data.global_data.lyzm_boss_location_y
                psw_main_data.global_data.psw_tfmw_is_tp_boss3 = true
            elseif boss_tp_num == 4 then
                local mw_fac_leader = mw_faction:faction_leader()
                local mwx , mwy = cm:find_valid_spawn_location_for_character_from_character(faction_name, cm:char_lookup_str(mw_fac_leader), true, 10)
                boss_current_x = mwx
                boss_current_y = mwy
                psw_main_data.global_data.psw_tfmw_is_tp_boss_end = true
            else
                psw_main_data.global_data.psw_tfmw_is_tp_boss1 = true
            end
            psw_boss_main_ms_smsx_add(faction_name)
            psw_main_miansicf(faction_name)
            local tp_to_boss_x, tp_to_boss_y = cm:find_valid_spawn_location_for_character_from_position(faction_name, boss_current_x, boss_current_y, true, 10)
            
            cm:teleport_to(cm:char_lookup_str(faction_leader), tp_to_boss_x, tp_to_boss_y)
            
            psw_main_data.player_data[faction_name].faction_leader_x = faction_leader_x
            psw_main_data.player_data[faction_name].faction_leader_y = faction_leader_y
            
        elseif dilemma_key == "dilemma_tf_duoren_tp" and choice == "SECOND" then
            local faction_leader_current_x = psw_get_num(faction_name, "faction_leader_x")
            local faction_leader_current_y = psw_get_num(faction_name, "faction_leader_y")
            psw_boss_main_ms_smsx_delete(faction_name)
            local tp_to_boss_1_x, tp_to_boss_2_x = cm:find_valid_spawn_location_for_character_from_position(faction_name, faction_leader_current_x, faction_leader_current_y, true, 1)
            
            local m, n = cm:find_valid_spawn_location_for_character_from_position(faction_name, tp_to_boss_1_x, tp_to_boss_2_x, true, 1)
            cm:teleport_to(cm:char_lookup_str(faction_leader), m, n)
        elseif dilemma_key == "dilemma_tf_duoren_tp" and choice == "THIRD" then
            
------------------ 传奇野兽传送 --------------------
        elseif dilemma_key == "dilemma_tf_duoren_legend_tp" and choice == "FIRST" then
            local csys_cqi = psw_main_data.global_data.creat_sszm_mf_cqi
            local csys_character = cm:get_character_by_cqi(csys_cqi)
            local leader_legend_x, ledear_legend_y = cm:find_valid_spawn_location_for_character_from_character(faction_name, cm:char_lookup_str(faction_leader), true, 1)
            local m_legend, n_legend = cm:find_valid_spawn_location_for_character_from_character(faction_name, cm:char_lookup_str(csys_character), true, 10)
            
            cm:teleport_to(cm:char_lookup_str(faction_leader), m_legend, n_legend)
            
            
            psw_main_data.player_data[faction_name].ledear_legend_y = ledear_legend_y
            psw_main_data.player_data[faction_name].leader_legend_x = leader_legend_x
            
        elseif dilemma_key == "dilemma_tf_duoren_legend_tp" and choice == "SECOND" then
            local crt_leader_legend_x = psw_get_num(faction_name, "leader_legend_x")
            local crt_ledear_legend_y = psw_get_num(faction_name, "ledear_legend_y")
            
            local tp_to_leader_1_x, tp_to_leader_2_x = cm:find_valid_spawn_location_for_character_from_position(faction_name, crt_leader_legend_x, crt_ledear_legend_y, true, 1)
            psw_boss_main_ms_smsx_delete(faction_name)
            cm:teleport_to(cm:char_lookup_str(faction_leader), tp_to_leader_1_x, tp_to_leader_2_x)
            if not faction:has_effect_bundle("psw_dlc7_tfmw_wef_csys_mission_bundle") then
                psw_main_data.player_data[faction_name].wef_csys_can_tp = false
            end
        elseif dilemma_key == "dilemma_tf_duoren_legend_tp" and choice == "THIRD" then

------------------ 坠星の奇迹 许愿 --------------------
        elseif dilemma_key == "dilemma_tf_zsqj_xuyuan" and choice == "FIRST" then
        
            psw_add_jishu_shenxing(faction_name, 2)
            alice_main_advice_sxts_2shenxing()
            common.trigger_soundevent("alice_sxts")
            
        elseif dilemma_key == "dilemma_tf_zsqj_xuyuan" and choice == "SECOND" then
        
            psw_add_jishu_xingyun(faction_name, 2)
            alice_main_advice_sxts_2xingyun()
            common.trigger_soundevent("alice_sxts")
            
        elseif dilemma_key == "dilemma_tf_zsqj_xuyuan" and choice == "THIRD" then
        
            psw_add_jishu_moli(faction_name, 2)
            alice_main_advice_sxts_2moli()
            common.trigger_soundevent("alice_sxts")
            
        elseif dilemma_key == "dilemma_tf_zsqj_xuyuan" and choice == "FOURTH" then
        
            psw_add_jishu_jianshu(faction_name, 2)
            alice_main_advice_sxts_2jianshu()
            common.trigger_soundevent("alice_sxts")
            
        elseif dilemma_key == "dilemma_tf_zsqj_xuyuan" and choice == "FIFTH" then
            
            psw_add_jishu_meili(faction_name, 2)
            alice_main_advice_sxts_2meili()
            common.trigger_soundevent("alice_sxts")

------------------ 奇迹的魔法 许愿 --------------------
        elseif dilemma_key == "dilemma_tf_xxdqj_xuyuan" and choice == "FIRST" then
            psw_aplly_costom_effect_bundle_hidden_fn("set_qiyuan_100ex", faction_name)
            psw_add_ex_limit_jiefang(faction_name)
        
        elseif dilemma_key == "dilemma_tf_xxdqj_xuyuan" and choice == "SECOND" then
            psw_add_jishu_shenxing(faction_name, 2)
            psw_add_jishu_xingyun(faction_name, 2)
            psw_add_jishu_moli(faction_name, 2)
            psw_add_jishu_jianshu(faction_name, 2)
            psw_add_jishu_meili(faction_name, 2)
            psw_add_jishu_zhiyu(faction_name, 2)
            psw_add_jishu_zhixing(faction_name, 2)
        
        elseif dilemma_key == "dilemma_tf_xxdqj_xuyuan" and choice == "THIRD" then
            psw_aplly_costom_effect_bundle_hidden_fn("set_qiyuan_100zt", faction_name)
        
------------------ 25回合后选择 祈愿装备/天赋 --------------------
        
            
        elseif dilemma_key == "dilemma_tf_25hh_tf_zb_xz" and choice == "FIRST" then
            cm:remove_effect_bundle("set_25hh_qy_zb", faction_name)
            cm:set_saved_value("psw_25hh_qy_zb_xz_" .. faction_name, "talent")
            out("PSW 25hh choice FIRST -> talent for " .. faction_name)
            -- fallback：选择天赋后立即抽奖，并标记防止按钮再次抽奖时重复
            if psw_main_data.player_data[faction_name] then
                psw_main_data.player_data[faction_name].psw_25hh_auto_drawn = true
            end
            local ok, err = pcall(function()
                cm:faction_add_pooled_resource(faction_name, "psw_main_gmsj", "psw_main_gmsj_event_bad", pickup_use)
                psw_main_pickup(faction_name)
            end)
            if not ok then
                out("PSW 25hh auto-draw fallback error: " .. tostring(err))
            end
        elseif dilemma_key == "dilemma_tf_25hh_tf_zb_xz" and choice == "SECOND" then
            
            psw_aplly_costom_effect_bundle_hidden_fn("set_25hh_qy_zb", faction_name)
            cm:set_saved_value("psw_25hh_qy_zb_xz_" .. faction_name, "item")
            out("PSW 25hh choice SECOND -> item for " .. faction_name)
            
        
------------------ 爱丽丝游戏 - 邀请函 --------------------
        
            
        elseif dilemma_key == "dilemma_tf_alice_game_yqh" and choice == "FIRST" then
            local psw_alice_game_jdfqz_name = psw_get_any(faction_name, "psw_alice_game_jdfqz_name")
            cm:add_ancillary_to_faction(faction, "psw_dlc6_alice_game_yqh", false)
            advice_dlc6_alice_juedou_sx_arv()
            psw_aplly_costom_effect_bundle_hidden_fn("alice_game_battler", faction_name)
            psw_aplly_costom_effect_bundle_hidden_fn("alice_game_battler_bjdz", faction_name)
            psw_main_data.player_data[faction_name].alice_game_battler_turn = turn
            psw_aplly_costom_effect_bundle_hidden_fn("alice_game_battler", psw_alice_game_jdfqz_name)
            psw_aplly_costom_effect_bundle_hidden_fn("alice_game_battler_jdfqz", psw_alice_game_jdfqz_name)
            cm:force_declare_war(faction_name, psw_alice_game_jdfqz_name, false, false);
            
            
        elseif dilemma_key == "dilemma_tf_alice_game_yqh" and choice == "SECOND" then
            local psw_alice_game_jdfqz_name_2 = psw_get_any(faction_name, "psw_alice_game_jdfqz_name")
            
            psw_add_alice_game_qz(psw_alice_game_jdfqz_name_2, 5)
            cm:treasury_mod(psw_alice_game_jdfqz_name_2, 5000);
            cm:treasury_mod(faction_name, -5000);
        
        
------------------ 丘比 - 愿望实现 --------------------
        
            
        elseif dilemma_key == "dilemma_tf_qb_yysx" then
            if choice == "FIRST" then
                psw_aplly_costom_effect_bundle_hidden_fn("set_qiyuan_100zt", faction_name)
            elseif choice == "SECOND" then
                psw_add_ex_limit_jiefang(faction_name)
                psw_aplly_costom_effect_bundle_hidden_fn("set_qiyuan_100ex", faction_name)
            end
            if not faction:has_effect_bundle("set_psw_tf_ex_yhzl_1") then
                psw_add_jishu_shenxing(faction_name, -1)
                psw_add_jishu_xingyun(faction_name, -1)
            end
            psw_add_jishu_mofashaonv(faction_name, 1)
            
            
------------------ 丘比 - 成为魔法少女 --------------------
        
            
        elseif dilemma_key == "dilemma_tf_qb_cwmfsn" and choice == "FIRST" then
            psw_main_data.player_data[faction_name].qb_cw_mfsn_jishu = psw_main_data.player_data[faction_name].qb_cw_mfsn_jishu + 1
            local qb_cw_mfsn_jishu = psw_get_num(faction_name, "qb_cw_mfsn_jishu")
            psw_aplly_costom_effect_bundle_hidden_fn("qb_cw_mfsn", faction_name)
            psw_dlc6_qb_xxyw_wqwl(qb_cw_mfsn_jishu)
            

------------------ 圣园未花 愿主垂怜 --------------------
        
            
        elseif dilemma_key == "dilemma_tf_mika_yzcl" and choice == "FIRST" then
            psw_add_ex_limit_jiefang(faction_name)
            psw_aplly_costom_effect_bundle_hidden_fn("set_qiyuan_100ex", faction_name)
        elseif dilemma_key == "dilemma_tf_mika_yzcl" and choice == "SECOND" then
            psw_aplly_costom_effect_bundle_hidden_fn("set_qiyuan_100zt", faction_name)
        elseif dilemma_key == "dilemma_tf_mika_yzcl" and choice == "THIRD" then
            fia_wyzb_hq(faction_name, false)
        elseif dilemma_key == "dilemma_tf_mika_yzcl" and choice == "FOURTH" then
            fia_wyzb_hq(faction_name, true)
            
------------------ 记忆结晶-预知梦 --------------------
        
            
        elseif dilemma_key == "dilemma_tf_jyjj_yuzhi" and choice == "FIRST" then
            psw_jyjj_yuzhi_effect(faction_name, "sx")
        elseif dilemma_key == "dilemma_tf_jyjj_yuzhi" and choice == "SECOND" then
            psw_jyjj_yuzhi_effect(faction_name, "xg")
        elseif dilemma_key == "dilemma_tf_jyjj_yuzhi" and choice == "THIRD" then
            psw_jyjj_yuzhi_effect(faction_name, "xd")
            
------------------ 白花-白花的留恋 --------------------
        elseif dilemma_key == "dilemma_tf_dlc7_baihua" and choice == "FIRST" then
            cm:trigger_dilemma(faction_name, "dilemma_tf_dlc7_baihua_sx")
        elseif dilemma_key == "dilemma_tf_dlc7_baihua" and choice == "SECOND" then
            cm:trigger_dilemma(faction_name, "dilemma_tf_dlc7_baihua_jishu")
            
        ---属性
        elseif dilemma_key == "dilemma_tf_dlc7_baihua_sx" and choice == "FIRST" then
            psw_add_jishu_shenxing(faction_name, 2)
            psw_main_data.player_data[faction_name].baihua_sx_jishu_pool = 1
            
        elseif dilemma_key == "dilemma_tf_dlc7_baihua_sx" and choice == "SECOND" then
            psw_add_jishu_xingyun(faction_name, 2)
            psw_main_data.player_data[faction_name].baihua_sx_jishu_pool = 2
            
        elseif dilemma_key == "dilemma_tf_dlc7_baihua_sx" and choice == "THIRD" then
            psw_add_jishu_moli(faction_name, 2)
            psw_main_data.player_data[faction_name].baihua_sx_jishu_pool = 3
            
        elseif dilemma_key == "dilemma_tf_dlc7_baihua_sx" and choice == "FOURTH" then
            psw_add_jishu_jianshu(faction_name, 2)
            psw_main_data.player_data[faction_name].baihua_sx_jishu_pool = 4
            
        elseif dilemma_key == "dilemma_tf_dlc7_baihua_sx" and choice == "FIFTH" then
            psw_add_jishu_meili(faction_name, 2)
            psw_main_data.player_data[faction_name].baihua_sx_jishu_pool = 5
            
        elseif dilemma_key == "dilemma_tf_dlc7_baihua_sx" and choice == "SIXTH" then
            psw_add_jishu_zhixing(faction_name, 2)
            psw_main_data.player_data[faction_name].baihua_sx_jishu_pool = 6
            
        elseif dilemma_key == "dilemma_tf_dlc7_baihua_sx" and choice == "SEVENTH" then
            psw_add_jishu_zhiyu(faction_name, 2)
            psw_main_data.player_data[faction_name].baihua_sx_jishu_pool = 7
            
        
        ---计数
        elseif dilemma_key == "dilemma_tf_dlc7_baihua_jishu" and choice == "FIRST" then
            psw_add_jishu_guangmi(faction_name, 1)
            psw_main_data.player_data[faction_name].baihua_sx_jishu_pool = 8
            
        elseif dilemma_key == "dilemma_tf_dlc7_baihua_jishu" and choice == "SECOND" then
            psw_add_jishu_heian(faction_name, 1)
            psw_main_data.player_data[faction_name].baihua_sx_jishu_pool = 9
            
        elseif dilemma_key == "dilemma_tf_dlc7_baihua_jishu" and choice == "THIRD" then
            psw_add_jishu_shenhai(faction_name, 1)
            psw_main_data.player_data[faction_name].baihua_sx_jishu_pool = 10
            
        elseif dilemma_key == "dilemma_tf_dlc7_baihua_jishu" and choice == "FOURTH" then
            psw_add_jishu_bing(faction_name, 1)
            psw_main_data.player_data[faction_name].baihua_sx_jishu_pool = 11
            
        elseif dilemma_key == "dilemma_tf_dlc7_baihua_jishu" and choice == "FIFTH" then
            psw_add_jishu_long(faction_name, 1)
            psw_main_data.player_data[faction_name].baihua_sx_jishu_pool = 12
            
        elseif dilemma_key == "dilemma_tf_dlc7_baihua_jishu" and choice == "SIXTH" then
            psw_add_jishu_shen(faction_name, 1)
            psw_main_data.player_data[faction_name].baihua_sx_jishu_pool = 13
            
        elseif dilemma_key == "dilemma_tf_dlc7_baihua_jishu" and choice == "SEVENTH" then
            psw_add_jishu_jingling(faction_name, 1)
            psw_main_data.player_data[faction_name].baihua_sx_jishu_pool = 14
            
        elseif dilemma_key == "dilemma_tf_dlc7_baihua_jishu" and choice == "EIGHTH" then
            psw_add_jishu_mofashaonv(faction_name, 1)
            psw_main_data.player_data[faction_name].baihua_sx_jishu_pool = 15
            
            
------------------ 古河渚 实现愿望之所 --------------------
        
            
        elseif dilemma_key == "dilemma_tf_dlc7_guhezhu" and choice == "FIRST" then
            psw_aplly_costom_effect_bundle_hidden_fn("set_qiyuan_100ex", faction_name)
            psw_add_ex_limit_jiefang(faction_name)
        elseif dilemma_key == "dilemma_tf_dlc7_guhezhu" and choice == "SECOND" then
            psw_aplly_costom_effect_bundle_hidden_fn("set_qiyuan_100zt", faction_name)
            
------------------ 影之诗 进化 --------------------
        
        elseif dilemma_key == "dilemma_tf_dlc7_yzs_jh" then
            psw_yzs_trigger_effct(faction_name, choice)
            
------------------ 守矢神社 塞钱箱 --------------------
        
        elseif dilemma_key == "dilemma_tf_dlc7_ssss" then
            psw_ssss_trigger_effct(faction_name, choice)
            
------------------ 守矢神社 白昼的客星 --------------------
        
        elseif dilemma_key == "dilemma_tf_dlc7_bzdkx" then
            psw_dlc7_bzdkx_trigger_effct(faction_name, choice)
            
------------------ 守矢神社 引发奇迹 --------------------
        
        elseif dilemma_key == "dilemma_tf_dlc7_miao_yfqj" then
            psw_ssss_yfqj_trigger_effct(faction_name, choice)
            
------------------ 今汐 移岁诛邪 --------------------
        
        elseif dilemma_key == "dilemma_tf_dlc7_jinxi_yszh" then
            psw_dlc7_trigger_jinxi(faction_name, choice)
            
            
------------------菲比 祈愿 --------------------
        
        elseif dilemma_key == "dilemma_tf_dlc7_feibi_qiyuan" then
            psw_dlc7_feibi_choice(faction_name, choice)
            
------------------ 雪风 --------------------
        
            
        elseif dilemma_key == "dilemma_tf_dlc7_xf_zy" and choice == "FIRST" then
            local xf_x = psw_get_num(faction_name, "xf_tp_cha_x")
            local xf_y = psw_get_num(faction_name, "xf_tp_cha_y")
            local m, n = cm:find_valid_spawn_location_for_character_from_position(faction_name, xf_x, xf_y, true, 10)
            cm:teleport_to(cm:char_lookup_str(faction_leader), m, n)
            
            
------------------end--------------------
        end;
        psw_main_data.player_data[faction_name].fia_xiaohao_js = fia_xiaohao_js
        
        psw_psw_tf_nor_lmyx_ztcf1(faction)
        psw_xxydz_jldqscf(faction)
        psw_unit_zhaomu_jianzhu(faction)
        cstf_lmyx_shenxing_jinghua(faction_name)
	end),
	true
)
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
-- 条件播放音乐，关联天赋，套娃循环，天赋效果

function psw_main_dismantle_tf(faction_name, tf_key)
    local faction = cm:get_faction(faction_name)
    
    local yx_subtype = psw_get_any(faction_name, "yx_subtype")
    local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
    
    cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
        {
        tf_key
        }
    )
end


function psw_main_only_dismantle_tf(faction_name)
    local region_name = psw_get_any(faction_name, "region_name")
    local tf_region = cm:get_region(region_name)
    local slot_n_list = tf_region:foreign_slot_manager_for_faction(faction_name):slots()
    local slot_1 = slot_n_list:item_at(0)
    local slot_2 = slot_n_list:item_at(1)
    local slot_3 = slot_n_list:item_at(2)
    local slot_4 = slot_n_list:item_at(3)
    cm:foreign_slot_instantly_dismantle_building(slot_1)
    cm:foreign_slot_instantly_dismantle_building(slot_2)
    cm:foreign_slot_instantly_dismantle_building(slot_3)
    cm:foreign_slot_instantly_dismantle_building(slot_4)
    psw_aplly_costom_effect_bundle_hidden_fn("main_yi_pick", faction_name)
end















local can_use_dtnl_tf = {
    psw_tf_nor_shayou_1 = true,
    psw_tf_nor_gengxj = true,
    psw_tf_nor_wunvji = true,
    psw_tf_nor_heitu = true,
    psw_tf_sp_qb_tf = true,
    psw_tf_ex_yhzl_2 = true,
    psw_tf_ex_yhzl_3 = true,
    psw_yiwu_ex_szs = true,
    psw_yiwu_ex_tymt = true,
    psw_yiwu_ex_xzc = true,
    psw_tf_ex_zhenhong_2 = true,
    psw_tf_ex_syd_2 = true,
    psw_tf_ex_syd_3 = true,
    psw_tf_ex_fuxuan_2 = true,
    psw_tf_sp_ayty = true,
    psw_tf_ex_pql = true,
    psw_tf_ex_xzwlsy = true,
    psw_tf_sp_mnrj = true,
    psw_tf_ex_yln_1 = true,
    psw_tf_ex_yln_2 = true,
    psw_tf_ex_yln_3 = true,
    psw_tf_nor_baihua = true,
    psw_tf_nor_tangtang = true,
    psw_tf_nor_ctj = true,
    psw_tf_nor_zuozhu = true,
    psw_tf_nor_yozi = true,
    psw_tf_nor_guhezhu = true,
    psw_tf_nor_delisha = true,
    psw_tf_nor_qiesi = true,
    psw_tf_nor_zgn = true,
    psw_tf_nor_xfl = true,
    psw_tf_nor_anne = true,
    psw_tf_nor_aly = true,
    psw_tf_ex_miao_2 = true,
    psw_tf_ex_miao_3 = true,
    psw_tf_ex_tsg_1 = true,
    psw_tf_sp_kokoro = true,
    psw_tf_ex_jinxi_2 = true,
    psw_tf_ex_jinxi_3 = true,
    psw_tf_ex_klt_2 = true,
    psw_tf_ex_feibi_2 = true,
    psw_tf_nor_chun = true,
    psw_tf_nor_xmy_zt = true,
    psw_tf_ex_xmy_2 = true,
    psw_tf_ex_xmy_3 = true,
    psw_tf_nor_lilika = true,
    psw_tf_ex_youxiang_2 = true,
    psw_tf_ex_shaonv = true,
    psw_tf_sp_xlfh = true,
    psw_tf_nor_feilin = true,
    psw_tf_sp_luluka = true,
}



function psw_main_tfxz()
    core:add_listener(
        "psw_main_tfxz",
        "ComponentLClickUp",
        function()
            return true
        end,
        function(context)
            local uic = UIComponent(context.component)
            local ccc = uic:GetContextObject("CcoCampaignBuildingSlot")
            if ccc == nil then return end

            local tf_key_cco = uic:GetContextObject("CcoBuildingLevelRecord")
            if not tf_key_cco then return end
            local dilemma_key = tf_key_cco:Call("Key")
            if not dilemma_key then return end

            local faction_name = ccc:Call("FactionContext.FactionRecordContext.Key")
            local faction = cm:get_faction(faction_name)
            if not faction or faction:is_null_interface() then return end
            local faction_cqi = faction:command_queue_index()

            if ccc:Call("IsForeignSlot") then
                if not dilemma_key:starts_with("psw_tf_") then
                    return
                end
                CampaignUI.TriggerCampaignScriptEvent(faction_cqi, dilemma_key)
            elseif ccc:Call("IsHordeSlot") then
                if not can_use_dtnl_tf[dilemma_key] then
                    return
                end
                local trigger_name = "dtnl_main_" .. dilemma_key
                CampaignUI.TriggerCampaignScriptEvent(faction_cqi, trigger_name)
            elseif dilemma_key:starts_with("psw_tf_") then
                -- 兼容普通城镇建筑插槽的天赋
                CampaignUI.TriggerCampaignScriptEvent(faction_cqi, dilemma_key)
            end
        end,
        true
    )
end

cm:add_first_tick_callback(

    --Whenever the game first starts, we run this function. Which calls an event listener
    function()
        psw_main_tfxz()
    end
)


-------------- 免疫死亡次数 -----------------

function psw_main_miansicf(faction_name)
    local faction = cm:get_faction(faction_name)
    local jishu_miansi = psw_get_num(faction_name, "jishu_miansi")
    local xingyun_bundle = "jnz_com_miansi"
    
    if jishu_miansi <= 0 then
        return
    end
    
    for i = 1, 20 do
                
        local bundle = xingyun_bundle .. i
        
        if faction:has_effect_bundle(bundle) then
            cm:remove_effect_bundle(bundle, faction_name)
        end
        
        if jishu_miansi > 20 then
                    
            cm:apply_effect_bundle("jnz_com_miansi20", faction_name, 0)
                        
        elseif jishu_miansi == i then
                    
            cm:apply_effect_bundle(bundle, faction_name, 0)
                        
        end
    end
end

------------- 免疫死亡与生命恢复上限buff添加 ---------------

function psw_boss_main_ms_smsx_add(faction_name)
    local faction = cm:get_faction(faction_name)
    if faction:is_human() == true then
        if faction:has_effect_bundle("psw_bundle_boss_ms_smsx") then
            cm:remove_effect_bundle("psw_bundle_boss_ms_smsx", faction_name)
        end
        if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_tghr") and psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_yasina") then
            psw_dlc6_tghr_xyj_apply(faction_name)
        end
        local ex_count = psw_get_num(faction_name, "ex_count")
        local hong_count = psw_get_num(faction_name, "hong_count")
            
        local jishu_miansi = psw_get_num(faction_name, "jishu_miansi")
        local effect_bundle = cm:create_new_custom_effect_bundle("psw_bundle_boss_ms_smsx")
        effect_bundle:set_duration(0)
        effect_bundle:add_effect("wh3_main_effect_own_reinforcement_time_percentage_mod", "faction_to_faction_own_unseen", -200);
        if ex_count > 0 then
            effect_bundle:add_effect("wh3_dlc20_effect_healing_cap_modifier", "faction_to_faction_leader", (ex_count * 50 + hong_count * 100));
        end
        cm:apply_custom_effect_bundle_to_faction(effect_bundle, faction)
    end
end
            

------------- 免疫死亡与生命恢复上限buff删除 ---------------
function psw_boss_main_ms_smsx_delete(faction_name)
    local faction = cm:get_faction(faction_name)
    if faction:is_human() == true then
        if faction:has_effect_bundle("psw_bundle_boss_ms_smsx") then
            cm:remove_effect_bundle("psw_bundle_boss_ms_smsx", faction_name)
        end
        if psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_tghr") and psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_yasina") then
            psw_dlc6_tghr_xyj_delete(faction_name)
        end
        local xingyun_bundle = "jnz_com_miansi"
        for i = 1, 20 do
            local bundle = xingyun_bundle .. i
            if faction:has_effect_bundle(bundle) then
                cm:remove_effect_bundle(bundle, faction_name)
            end
        end
    end
end

------ 免疫死亡 每回合删除 --------
function psw_main_ms_hh_delete()
    core:remove_listener("psw_main_ms_hh_delete")
	core:add_listener(
	"psw_main_ms_hh_delete",
	"FactionTurnStart",
    function(context)
        if context:faction():is_human() == true then
            return true
        end
    end,
    function(context)
        local faction_name = context:faction():name()
        psw_boss_main_ms_smsx_delete(faction_name)
	end,
	true
	)
end




local mc_gmz_tf_pool = {
    psw_tf_ex_feibi_1 = true,
    psw_tf_ex_klt_1 = true,
    psw_tf_ex_jinxi_1 = true,
    psw_tf_nor_chun = true,
    psw_tf_nor_sar = true,
    psw_tf_nor_ktll = true,
    psw_tf_nor_anke = true,
    psw_tf_nor_weilinai = true,
}


------ 天赋选择 ------
core:remove_listener("ui_psw_main_tfxz")
core:add_listener("ui_psw_main_tfxz",
    "UITrigger",
    function(context)
        return context:trigger():starts_with("psw_tf_")
    end,
    psw_pcall_wrapper(function(context)
        local faction = cm:model():faction_for_command_queue_index(context:faction_cqi())
        local faction_name = faction:name()
        
        local turn = cm:turn_number()
        local dilemma_key = context:trigger()
        
        local should_add_pick_zhongmo = true
        if 1 == 1 then
            
            
            
            local psw_main_character = psw_get_main_character(faction_name)
            
            if psw_main_character:is_null_interface() or psw_main_character:is_wounded() or psw_main_character:is_at_sea() or not cm:char_is_general_with_army(psw_main_character) then
                return
            end
            cm:remove_effect_bundle("psw_yi_pick", faction_name);
            if psw_faction_has_effect_bundle(faction_name, "main_yi_pick") then
                return
            end
            
            cm:callback(function()
                cm:remove_effect_bundle("main_yi_pick", faction_name)
            end, 1)
            local set = "set_" .. dilemma_key
            local set_main = "set_main_" .. dilemma_key
            local effect_main_key = dilemma_key .. "_effect_bundle"
            
            if dilemma_key:starts_with("psw_tf_nor_syd") then
                local treasury = faction:treasury()
                local requiry_treasury = 3500
                if dilemma_key == "psw_tf_nor_syd_fatiao" and psw_faction_has_effect_bundle(faction_name, set) then
                    requiry_treasury = 0
                elseif dilemma_key == "psw_tf_nor_syd_fatiao" and not psw_faction_has_effect_bundle(faction_name, set) then
                    requiry_treasury = 10000
                end
                if treasury < requiry_treasury then
                    psw_aplly_costom_effect_bundle_hidden_fn("psw_yi_pick", faction_name)
                    return
                else
                    cm:treasury_mod(faction_name, -requiry_treasury)
                end
            end
            
            psw_main_only_dismantle_tf(faction_name)
            
            
            local faction_leader = faction:faction_leader()

            local jishu_ex_count = psw_get_num(faction_name, "jishu_ex_count")
            local nor_count = psw_get_num(faction_name, "nor_count")
            local ex_count = psw_get_num(faction_name, "ex_count")
            
            local effect_bundle
            local effect_list
            
            
                        -------------  爱莉希雅  -------------------
            
            
                
            if jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_alxy_1" and not faction:has_effect_bundle("set_psw_tf_ex_alxy_1") and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_alxy_1") then
                
                common.trigger_soundevent("alxy_1")
                advice_psw_tf_ex_alxy_1_1()
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_jishu_shenxing(faction_name, 2)
                
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_jishu_bing(faction_name, 1)
                psw_add_jishu_guangmi(faction_name, 1)
                
                psw_add_ex_count(faction_name, 1)
                
                cm:add_ancillary_to_faction(faction, "alxy_hylk", false)
                cm:add_ancillary_to_faction(faction, "alxy_ddfr", false)
                cm:add_ancillary_to_faction(faction, "alxy_qxsy", false)
                cm:apply_effect_bundle_to_character("jnz_tf_ex_wxzr", psw_main_character, 0);
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_alxy_1", faction_name)
                psw_apply_non_effect_bundle_to_all_player("set_main_psw_tf_ex_alxy_1")
                psw_add_jishu_xilie_sfly(faction_name, 1)
                
                
                        -------------  圆环之理  -------------------
            

                

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_yhzl_1" and not faction:has_effect_bundle("set_psw_tf_ex_yhzl_1") and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_yhzl_1") then
                common.trigger_soundevent("yhzl_1")
                cm:show_advice("advice_psw_tf_ex_yhzl_1", true, false, nil, 0, 0.5)
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                local yhzl_1_ran_num = cm:random_number(6, 2)
                psw_add_lmyx_yinguo_jishu(faction_name, yhzl_1_ran_num)
                
                psw_add_jishu_moli(faction_name, 3)
                psw_add_jishu_mofashaonv(faction_name, 1)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_jishu_shen(faction_name, 1)
                psw_add_jishu_zhiyu(faction_name, 3)
                psw_add_ex_count(faction_name, 1)
                psw_add_count_moli(faction_name, 1)
                
                effect_list = {
                    {effect = "wh_main_effect_character_stat_unit_health", effect_scope = "faction_to_force_own", effect_num = 10},
                    {effect = "wh3_dlc20_effect_xp_gain_all_units", effect_scope = "faction_to_force_own", effect_num = 15},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_ex_yhzl", 0, effect_list)
                psw_dlc6_mxdxw_mfsn_yinguo_apply(faction_name)
                
                psw_main_data.global_data.yhzl_faction_name = faction_name
                psw_apply_non_effect_bundle_to_all_player("set_main_psw_tf_ex_yhzl_1")
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_yhzl_1", faction_name)
                
                
                
                        -------------  QB  -------------------
            

                
            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_sp_qb_tf" and not faction:has_effect_bundle("set_psw_tf_sp_qb_tf") and not psw_faction_has_effect_bundle(faction_name, "set_main_qb_1") then
            
                
                common.trigger_soundevent("qb_1")
                advice_qb_1()
                
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_jishu_zhongmo(1)
                
                psw_add_nor_count(faction_name, 1)
                
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_sp_qb_tf", faction_name)
                psw_apply_non_effect_bundle_to_all_player("set_main_qb_1")
                psw_main_data.global_data.qb_faction_name = faction_name
                psw_dlc6_mnh_apply_to_all_faction()
                cm:callback(function()
                    psw_dlc6_qb_sfcw_mfsn()
                end, 3)
                
            -------------  神名文字（未花）  -------------------
            

                

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_sywh_1" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_sywh_1") and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_sywh_1") then
                
                
                
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                
                ---------- 垂怜经 ----------
                cm:callback(function()
                    psw_dlc6_swyh_install_clj(faction_name, false)
                end, 19)
                
                
                ---------- 本笃会 ----------
                local mika_bdh_jishu = nor_count + ex_count
                cm:callback(function()
                    psw_dlc6_swyh_install_bdh(faction_name, mika_bdh_jishu, false)
                end, 17.5)
                
                ------
                
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                
                psw_add_ex_count(faction_name, 1)
                
                common.trigger_soundevent("sywh_1")
                advice_psw_tf_ex_sywh_1_1()
                
                psw_apply_non_effect_bundle_to_all_player("set_main_psw_tf_ex_sywh_1")
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_sywh_1", faction_name)
                psw_main_data.player_data[faction_name].sywh_faction = faction_name
                psw_add_jishu_xilie_jwts(faction_name, 1)
                psw_dlc6_bhysy_yzm_jiance(faction_name)
                
                
                psw_add_jishu_ssy_tf(faction_name, 1)
                
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_zhu_nor") == true then
                    cm:remove_effect_bundle_from_character("jnz_tf_psw_tf_nor_zhu_nor", psw_main_character);
                    cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_nor_zhu_nor2", psw_main_character, 0);
                end
                local jishu_alws = psw_get_num(faction_name, "jishu_alws")
                cm:callback(function()
                    psw_add_jishu_guangmi(faction_name, 1)
                end, 21)
                
                cm:callback(function()
                    psw_dlc6_swyh_install_chh(faction_name, false)
                end, 24)
                
                cm:callback(function()
                    psw_dlc6_swyh_install_mn(faction_name, jishu_alws, false)
                end, 26)
                
                local sywh_jingling = psw_get_num(faction_name, "jishu_jingling")
                cm:callback(function()
                    psw_dlc6_swyh_install_zf(faction_name, sywh_jingling, false)
                end, 28)
                
                local sywh_jiushizhu = psw_get_num(faction_name, "jishu_jiushizhu")
                cm:callback(function()
                    psw_dlc6_swyh_install_ty(faction_name, sywh_jiushizhu, false)
                end, 30)
                
                local sywh_shen = psw_get_num(faction_name, "jishu_shen")
                cm:callback(function()
                    psw_dlc6_swyh_install_sp(faction_name, sywh_shen, false)
                end, 32)
                
                
            -------------  神名文字（日奈）  -------------------


                
            
            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_kqrn_1" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_kqrn_1") and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_kqrn_1") then
                
                common.trigger_soundevent("kqrn_1")
                advice_psw_tf_ex_kqrn_1()
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_ex_psw_tf_ex_kqrn_1", psw_main_character, 0);
                
                psw_add_jishu_heian(faction_name, 1)
                
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                
                psw_add_ex_count(faction_name, 1)
                
                psw_apply_non_effect_bundle_to_all_player("set_main_psw_tf_ex_kqrn_1")
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_kqrn_1", faction_name)
                psw_add_jishu_xilie_jwts(faction_name, 1)
            
            
            -------------  幽灵鲨  -------------------
            

                

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_yls_1" and not faction:has_effect_bundle("set_psw_tf_ex_yls_1") and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_yls_1") then
                
                common.trigger_soundevent("yls_1")
                advice_psw_tf_ex_yls_1()
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_ex_psw_tf_ex_yls_1", psw_main_character, 0);
                
                psw_add_jishu_heian(faction_name, 1)
                
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_jishu_bing(faction_name, 1)
                psw_add_jishu_shenhai(faction_name, 1)
                
                psw_add_ex_count(faction_name, 1)
                
                psw_apply_non_effect_bundle_to_all_player("set_main_psw_tf_ex_yls_1")
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_yls_1", faction_name)
                psw_main_data.player_data[faction_name].yls_faction = faction_name
                psw_add_jishu_xilie_ldd(faction_name, 1)
            
            
            -------------  斯卡蒂  -------------------
            

            

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_skd_1" and not faction:has_effect_bundle("set_psw_tf_ex_skd_1") and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_skd_1") then
                
                common.trigger_soundevent("skd_1")
                advice_psw_tf_ex_skd_1()
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_ex_psw_tf_ex_skd_1", psw_main_character, 0);
                
                psw_add_jishu_heian(faction_name, 1)
                psw_add_yctz_effect_to_faction(faction_name, "fyx")
                
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_jishu_bing(faction_name, 1)
                psw_add_jishu_shenhai(faction_name, 1)
                psw_add_gjyiwu_lcgl(faction_name, 15)
                
                psw_add_ex_count(faction_name, 1)
                
                psw_apply_non_effect_bundle_to_all_player("set_main_psw_tf_ex_skd_1")
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_skd_1", faction_name)
                psw_main_data.player_data[faction_name].skd_faction = faction_name
                psw_aplly_costom_effect_bundle_hidden_fn("psw_lj_baoji_2bei", faction_name)
                psw_add_jishu_xilie_ldd(faction_name, 1)
                
            
            
            -------------  希儿·彼岸双生  -------------------
            

            

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_bass_1" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_bass_1") and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_bass_1") then
            
                common.trigger_soundevent("bass_1")
                advice_psw_tf_ex_bass_1_1()

                psw_main_dismantle_tf(faction_name, dilemma_key)
                

                
                cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_ex_bass_1_b", psw_main_character, 0);
                
                psw_add_jishu_shenxing(faction_name, 2)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_heian(faction_name, 1)
                
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                
                psw_add_ex_count(faction_name, 1)
                
                psw_apply_non_effect_bundle_to_all_player("set_main_psw_tf_ex_bass_1")
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_bass_1", faction_name)
                psw_add_jishu_xilie_sfly(faction_name, 1)

                
                
            -------------  爱蜜莉雅  -------------------
            

            

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_amly_1" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_amly_1") and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_amly_1") then
                
                common.trigger_soundevent("amly_1")
                advice_psw_tf_ex_amly_1_1()
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_ex_amly_1", psw_main_character, 0);
                
                psw_add_jishu_moli(faction_name, 2)
                psw_add_jishu_xingyun(faction_name, 1)
                
                psw_add_jishu_bing(faction_name, 1)
                psw_add_jishu_jingling(faction_name, 1)
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_ex_count(faction_name, 1)
                
                psw_apply_non_effect_bundle_to_all_player("set_main_psw_tf_ex_amly_1")
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_amly_1", faction_name)
                
                
                
                
            -------------  永不败北  -------------------
            

            

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_ybbb_1" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_ybbb_1") and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_ybbb_1") then
            
                common.trigger_soundevent("ybbb_1")
                advice_psw_tf_ex_ybbb_1_1()
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_jishu_zhixing(faction_name, 2)
                psw_add_ex_count(faction_name, 1)
                
                
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yxsldff_nor") then
                    psw_delete_ancillary_with_time_delay(faction, "kong_yxxj", 0.1)
                    cm:add_ancillary_to_faction(faction, "kong_yxxj2", false)
                    cm:remove_effect_bundle_from_character("jnz_tf_nor_kong_1", psw_main_character);
                    cm:apply_effect_bundle_to_character("jnz_tf_nor_kong_2", psw_main_character, 0);
                    cm:apply_effect_bundle_to_character("jnz_tf_ex_psw_tf_ex_ybbb_1_2", psw_main_character, 0);
                elseif 1 == 1 then
                    cm:apply_effect_bundle_to_character("jnz_tf_ex_psw_tf_ex_ybbb_1_1", psw_main_character, 0);
                end
                
                psw_main_data.player_data[faction_name].ybbb_faction = faction_name
                
                psw_apply_non_effect_bundle_to_all_player("set_main_psw_tf_ex_ybbb_1")
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_ybbb_1", faction_name)
            
            -------------  小小的勇气  -------------------
            

            

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_xxdyq_1" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_xxdyq_1") and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_xxdyq_1") then
                
                common.trigger_soundevent("xxdyq_1")
                advice_psw_tf_ex_xxdyq_1_1()
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_ex_bcjh_1", psw_main_character, 0);
                
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_xingyun(faction_name, 2)
                psw_add_jishu_moli(faction_name, 3)
                
                psw_add_jishu_jingling(faction_name, 1)
                psw_add_jishu_bing(faction_name, 1)
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_count_moli(faction_name, 1)
                
                psw_add_ex_count(faction_name, 1)
                
                
                psw_apply_non_effect_bundle_to_all_player("set_main_psw_tf_ex_xxdyq_1")
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_xxdyq_1", faction_name)
                psw_add_jishu_xilie_ldse(faction_name, 1)
            
            
            -------------  暗之书意志  -------------------
            

            

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_azsyz_1" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_azsyz_1") and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_azsyz_1") then
                
                advice_azsyz_new_1_1()
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_ex_psw_tf_ex_azsyz_1", psw_main_character, 0);
                
                psw_add_jishu_heian(faction_name, 1)
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_ex_count(faction_name, 1)
                psw_add_count_moli(faction_name, 1)
                
                
                psw_apply_non_effect_bundle_to_all_player("set_main_psw_tf_ex_azsyz_1")
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_azsyz_1", faction_name)
            
            
            
            -------------  半透明の魔法使  -------------------
            

            

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_btmmfs_1" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_btmmfs_1") and not psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_ex_btmmfs_1") then
                
                common.trigger_soundevent("ejtzh_1")
                advice_ejtzh_1_1()
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                local ejtzh_get_turn = cm:turn_number()
                
                
                
                
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_jishu_jiyi(faction_name, 1)
                psw_add_ex_count(faction_name, 1)
                
                
                psw_apply_non_effect_bundle_to_all_player("set_main_psw_tf_ex_btmmfs_1")
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_btmmfs_1", faction_name)
                psw_main_data.player_data[faction_name].ejtzh_get_turn = ejtzh_get_turn
                
                psw_ejtzh_main_jyz(faction)
                psw_hh_start_btmmfs(faction_name)
            
                
            
            -------------  奇迹与星星的魔女  -------------------
            

            

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_sp_xxdqj_ex" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_sp_xxdqj_ex") and not psw_faction_has_effect_bundle(faction_name, "set_main_xxdqj_1") then
                
                common.trigger_soundevent("xxdqj")
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_jiushizhu(faction_name, 1)
                psw_add_jishu_zhongmo(-3)
                psw_add_jishu_xuanze(faction_name, 1)
                psw_add_jishu_geji(faction_name, 1)
                psw_add_min_yiwu_level(faction_name, 1)
                psw_add_jishu_monv(faction_name, 1)
                
                local xxdqj_xingyun = psw_resource_value(faction, "psw_xingyun")
                local xxdqj_qjjs = math.floor(xxdqj_xingyun/4)
                
                local xxdqj_jishu_geji = psw_get_num(faction_name, "jishu_geji")
                psw_add_jishu_meili(faction_name, xxdqj_jishu_geji * 2)
                
                psw_main_data.player_data[faction_name].xxdqj_qjjs = xxdqj_qjjs
                psw_apply_non_effect_bundle_to_all_player("set_main_xxdqj_1")
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_sp_xxdqj_ex", faction_name)
                psw_aplly_costom_effect_bundle_hidden_fn("psw_lj_baoji_2bei", faction_name)
                psw_aplly_costom_effect_bundle_hidden_fn("set_xxdqj_xuyuan", faction_name)
            
            
            -------------  最终号个体  -------------------
            

            

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_zzhgt_ex" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_zzhgt_ex") and not psw_faction_has_effect_bundle(faction_name, "set_main_zzhgt_1") then
                
                common.trigger_soundevent("zzhgt_1_new")
                advice_zzhgt_1_1()
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_ex_zzhgt", psw_main_character, 0);
                
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_jishu_zhixing(faction_name, 3)
                psw_add_ex_count(faction_name, 1)
                psw_add_jishu_miansi(faction_name, 1)
                
                psw_apply_non_effect_bundle_to_all_player("set_main_zzhgt_1")
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_zzhgt_ex", faction_name)
                psw_hh_start_zzhgt(faction_name)
                
                ---凤凰の庭院
                psw_dlc7_xlfh_whty_effect(faction_name)
            
            
            
            -------------  千恋万花  -------------------
            

            

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_qlwh_ex" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_qlwh_ex") and not psw_faction_has_effect_bundle(faction_name, "set_main_qlwh_1") then
                
                common.trigger_soundevent("qlwh_1")
                advice_qlwh_1_1()
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_ex_congyu", psw_main_character, 0);
                cm:add_ancillary_to_faction(faction, "congyu_shendao_cyu", false)
                
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_ex_count(faction_name, 1)
                psw_add_jishu_miansi(faction_name, 1)
                psw_add_jishu_shenxing(faction_name, 3)
                
                psw_apply_non_effect_bundle_to_all_player("set_main_qlwh_1")
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_qlwh_ex", faction_name)
                
                ---凤凰の庭院
                psw_dlc7_xlfh_whty_effect(faction_name)
                
            
            
            -------------  遗迹中的无名少女  -------------------


            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_alice_1" and not psw_faction_has_effect_bundle(faction_name, set) and not psw_faction_has_effect_bundle(faction_name, set_main) then
                advice_alice_1()
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_jishu_yxkfb(faction_name, 1)
                
                psw_add_ex_count(faction_name, 1)
                
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_add_jishu_xilie_jwts(faction_name, 1)
                psw_add_jishu_xilie_qnkx(faction_name, 1)
            -------------  神名文字（优香）  -------------------


            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_youxiang_1" and not psw_faction_has_effect_bundle(faction_name, set) and not psw_faction_has_effect_bundle(faction_name, set_main) then
                advice_youxiang_1()

                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                cm:apply_effect_bundle_to_character("jnz_tf_ex_youxiang_1", psw_main_character, 0)
                psw_add_jishu_zhixing(faction_name, 3)
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_jishu_yxkfb(faction_name, 1)
                psw_add_ex_count(faction_name, 1)
                
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_noa") then
                    psw_add_round_gmsj_reward(faction_name, 1)
                end
                
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_add_jishu_xilie_jwts(faction_name, 1)
                psw_add_jishu_xilie_qnkx(faction_name, 1)
                
            -------------  迷途的二人  -------------------


            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_fia_1" and not psw_faction_has_effect_bundle(faction_name, set) and not psw_faction_has_effect_bundle(faction_name, set_main) then
                advice_fia_1()
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_xingyun(faction_name, 3)
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_jishu_jingling(faction_name, 1)
                psw_add_ex_count(faction_name, 1)
                
                cm:add_ancillary_to_faction(faction, "fia_fia", false)
                local fia_ledear_rank = faction_leader:rank()
                psw_main_data.player_data[faction_name].fia_ledear_rank = fia_ledear_rank
                
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                
            -------------  布雷斯特  -------------------


            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_blst_1" and not psw_faction_has_effect_bundle(faction_name, set) and not psw_faction_has_effect_bundle(faction_name, set_main) then
                advice_blst_1_1()
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                cm:apply_effect_bundle_to_character("jnz_tf_ex_blst_1", psw_main_character, 0)
                psw_add_jishu_guangmi(faction_name, 1)
                
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_jishu_jingling(faction_name, 1)
                psw_add_jishu_shenhai(faction_name, 1)
                psw_add_jishu_jianniang(faction_name, 1)
                psw_add_hgd_djs(faction_name, -3)
                psw_add_ex_count(faction_name, 1)
                psw_add_yctz_effect_to_faction(faction_name, "fyx")
                
                local blst_jljs_0 = psw_get_num(faction_name, "jishu_jingling")
                
                local blst_jljs = blst_jljs_0 * 2
                psw_add_jishu_xingyun(faction_name, blst_jljs)
                psw_add_jishu_zhiyu(faction_name, blst_jljs)
                
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                
                
            
            -------------  独角兽  -------------------


            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_djs_1" and not psw_faction_has_effect_bundle(faction_name, set) and not psw_faction_has_effect_bundle(faction_name, set_main) then
                advice_djs_1_1()
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                cm:add_ancillary_to_faction(faction, "djs_fw190", false)
                cm:add_ancillary_to_faction(faction, "djs_f4ut0", false)
                cm:add_ancillary_to_faction(faction, "djs_dym", false)
                cm:apply_effect_bundle_to_character("jnz_tf_ex_djs_1", psw_main_character, 0)
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_jishu_shenhai(faction_name, 1)
                psw_add_jishu_jianniang(faction_name, 1)
                psw_add_jishu_meili(faction_name, 3)
                psw_add_ex_count(faction_name, 1)
                psw_add_jishu_geji(faction_name, 1)
                
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                
            -------------  童话少女  -------------------


            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_zhenbu_1" and not psw_faction_has_effect_bundle(faction_name, set) and not psw_faction_has_effect_bundle(faction_name, set_main) then
                advice_zhenbu_1_1()
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                cm:apply_effect_bundle_to_character("jnz_tf_ex_zhenbu_1", psw_main_character, 0)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_xingyun(faction_name, 2)
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_jishu_meili(faction_name, 3)
                psw_add_jishu_zhiyu(faction_name, 3)
                
                psw_add_ex_count(faction_name, 1)
                
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_add_jishu_xilie_ldse(faction_name, 1)
                
            -------------  金色の记忆  -------------------


            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_you_ex" and not psw_faction_has_effect_bundle(faction_name, set) and not psw_faction_has_effect_bundle(faction_name, set_main) then
                advice_you_1_1()
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_xingyun(faction_name, 5)
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_jishu_jingling(faction_name, 1)
                local jdjy_jingling = psw_get_num(faction_name, "jishu_jingling")
                psw_add_jishu_zhiyu(faction_name, jdjy_jingling)
                psw_add_ex_count(faction_name, 1)
                psw_add_jishu_miansi(faction_name, 5)
                
                
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_hh_start_jsdjy(faction_name)
                
                ---凤凰の庭院
                psw_dlc7_xlfh_whty_effect(faction_name)
                
            
            -------------  第七人偶  -------------------

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_sp_qwsj" and not psw_faction_has_effect_bundle(faction_name, set) and not psw_faction_has_effect_bundle(faction_name, set_main) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                advice_dlc6_xuehua_1()
                
                psw_add_jishu_zhongmo(1)
                psw_add_nor_count(faction_name, 1)
                psw_add_qwsn_jishu(faction_name, 1)
                local qwsn_jishu = psw_get_num(faction_name, "qwsn_jishu")
                psw_add_jishu_shenxing(faction_name, qwsn_jishu)
                psw_add_jishu_meili(faction_name, 2)
                
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_dlc6_alice_game_linsner(faction_name, 34)
                psw_dlc6_qwsj_wxdro_effect()
                psw_dlc6_zhenhong_juexing(faction_name)
                
                
            -------------  第五人偶  -------------------

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_zhenhong_1" and not psw_faction_has_effect_bundle(faction_name, set) and not psw_faction_has_effect_bundle(faction_name, set_main) and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_syd_1") then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                advice_dlc6_zhenhong_1_1()
                
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_ex_count(faction_name, 1)
                psw_add_qwsn_jishu(faction_name, 1)
                psw_add_count_moli(faction_name, 1)
                
                if not faction:has_effect_bundle("set_ex_shangxian") then
                    psw_add_jishu_ex_count(faction_name, -1)
                    psw_aplly_costom_effect_bundle_hidden("set_ex_shangxian", faction)
                end
                
                effect_list = {
                    {effect = "psw_dlc6_zhenhong_qwcj", effect_scope = "faction_to_character_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_ex_zhenhong", 0, effect_list)
                psw_aplly_costom_effect_bundle_hidden("psw_dlc6_alice_game_qwsm_zhenhong", faction)
                
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_dlc6_alice_game_linsner(faction_name, 11)
                psw_dlc6_qwsm_chain_effect_apply(faction_name, "psw_dlc6_bundle_ex_zhenhong")
                psw_dlc6_qwsm_tf_effect_apply(faction_name, dilemma_key)
                cm:callback(function()
                    psw_dlc6_zhenhong_juexing(faction_name)
                end, 12)
                
            -------------  第一人偶  -------------------

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_syd_1" and not psw_faction_has_effect_bundle(faction_name, set) and not psw_faction_has_effect_bundle(faction_name, set_main) and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_zhenhong_1") then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                advice_dlc6_syd_1_1()
                
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_ex_count(faction_name, 1)
                psw_add_qwsn_jishu(faction_name, 1)
                psw_add_jishu_heian(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden("psw_dlc6_alice_game_qwsm_syd", faction)
                psw_aplly_hidden_effect_bundle_to_character("psw_dlc6_bundle_ex_syd", psw_main_character)
                
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_dlc6_alice_game_linsner(faction_name, 24)
                psw_dlc6_qwsm_chain_effect_apply(faction_name, "psw_dlc6_bundle_ex_syd")
                psw_dlc6_qwsm_tf_effect_apply(faction_name, dilemma_key)
                psw_dlc6_syd_juexing(faction_name, 25)
                psw_add_jishu_moli(faction_name, 0)
                local syd_jianshu = psw_get_num(faction_name, "psw_jianshu")
                psw_dlc6_syd_syj_jianshu_effect(faction_name, syd_jianshu)
                
            -------------  未来的太卜司  -------------------

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_fuxuan_1" and not psw_faction_has_effect_bundle(faction_name, set) and not psw_faction_has_effect_bundle(faction_name, set_main) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:add_ancillary_to_faction(faction, "psw_dlc6_fuxuan_tysp", false)
                advice_dlc6_fuxuan_1_1()
                
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_ex_count(faction_name, 1)
                psw_add_jishu_xingyun(faction_name, 2)
                psw_moyin_mianyi_zaie_apply(faction)
                psw_moyin_mianyi_wenyi_apply(faction)
                
                effect_list = {
                    {effect = "wh3_dlc20_effect_xp_gain_all_units", effect_scope = "faction_to_force_own", effect_num = 25},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_ex_fuxuan", 0, effect_list)
                
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                
            -------------  影之实力者  -------------------

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_anying_1" and not psw_faction_has_effect_bundle(faction_name, set) and not psw_faction_has_effect_bundle(faction_name, set_main) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                advice_dlc6_anying_1_1()
                
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_ex_count(faction_name, 1)
                psw_add_jishu_heian(faction_name, 1)
                
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  知识与避世的少女  -------------------

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_pql" and not psw_faction_has_effect_bundle(faction_name, set) and not psw_faction_has_effect_bundle(faction_name, set_main) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                advice_dlc6_pql_get_1()
                
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_ex_count(faction_name, 1)
                psw_add_jishu_xilie_hxx(faction_name, 1)
                psw_add_count_moli(faction_name, 1)
                
                local psw_zhixing = psw_get_num(faction_name, "psw_zhixing")
                local pql_num = math.floor(psw_zhixing/3)
                local pql_qyys_num = math.floor(psw_zhixing/2)
                psw_add_jishu_moli(faction_name, pql_num)
                psw_add_pql_qyyszf(faction_name, pql_qyys_num)
                
                effect_list = {
                    {effect = "psw_dlc6_pql_sjtr", effect_scope = "faction_to_force_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_ex_pql", 0, effect_list)
                
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                ---凤凰の庭院
                psw_dlc7_xlfh_whty_effect(faction_name)
                
            -------------  天穹游侠  -------------------

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_qiyana_1" and not psw_faction_has_effect_bundle(faction_name, set) and not psw_faction_has_effect_bundle(faction_name, set_main) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_ex_count(faction_name, 1)
                psw_add_jishu_shenxing(faction_name, 2)
                psw_add_jishu_xilie_sfly(faction_name, 1)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_heian(faction_name, 1)
                advice_dlc6_qiyana_1_1()
                
                effect_list = {
                    {effect = "psw_dlc6_ex_qiyana_effect_jzgj", effect_scope = "faction_to_force_own", effect_num = 10},
                    {effect = "psw_dlc6_ex_qiyana_effect_jzfy", effect_scope = "faction_to_force_own", effect_num = 10},
                    {effect = "psw_dlc6_ex_qiyana_effect_yckx", effect_scope = "faction_to_force_own", effect_num = 15},
                    {effect = "wh_main_effect_public_order_faction", effect_scope = "faction_to_province_own", effect_num = 4},
                    {effect = "wh3_main_effect_province_growth_faction", effect_scope = "faction_to_province_own", effect_num = 40},
                    {effect = "psw_dlc6_qyn_bhqs_i", effect_scope = "faction_to_force_own", effect_num = 1},
                    {effect = "psw_dlc6_qyn_bhqs_ii", effect_scope = "faction_to_force_own", effect_num = 1},
                    {effect = "psw_dlc6_ex_qiyana_effect_wlkx", effect_scope = "faction_to_force_own", effect_num = 20},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_ex_qiyana", 0, effect_list)
                
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  少女的旅程  -------------------

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_yln_1" and not psw_faction_has_effect_bundle(faction_name, set) and not psw_faction_has_effect_bundle(faction_name, set_main) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:add_ancillary_to_faction(faction, "psw_dlc6_yln_nkmxt", false)
                advice_dlc6_yln_1_1()
                
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_ex_count(faction_name, 1)
                psw_add_jishu_monv(faction_name, 1)
                psw_add_jishu_xingyun(faction_name, 2)
                psw_add_nor_count(faction_name, 1)
                
                cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                    {
                    "psw_tf_sp_mnrj"
                    }
                )
                
                effect_list = {
                    {effect = "wh3_dlc20_effect_xp_gain_all_units", effect_scope = "faction_to_force_own", effect_num = 15},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_ex_yln", 0, effect_list)
                
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  超能力少女  -------------------

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_xingfa_1" and not psw_faction_has_effect_bundle(faction_name, set) and not psw_faction_has_effect_bundle(faction_name, set_main) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                advice_dlc6_xingfa_1_1()
                
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_ex_count(faction_name, 1)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_jingling(faction_name, 1)
                psw_add_jishu_xilie_ldse(faction_name, 1)
                psw_add_jishu_xingyun(faction_name, 1)
                psw_add_jishu_shenxing(faction_name, 1)
                psw_add_jishu_moli(faction_name, 1)
                psw_add_jishu_jianshu(faction_name, 1)
                psw_add_jishu_zhixing(faction_name, 1)
                psw_add_jishu_meili(faction_name, 1)
                psw_add_jishu_zhiyu(faction_name, 1)
                
                effect_list = {
                    {effect = "psw_dlc6_xingfa_jsbp", effect_scope = "faction_to_character_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_ex_xingfa", 0, effect_list)
                
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_bhsn") then
                    cm:add_ancillary_to_faction(faction, "psw_dlc6_xingfa_hdj", false)
                    cm:add_ancillary_to_faction(faction, "psw_dlc6_bhsn_shs", false)
                    psw_add_jishu_guangmi(faction_name, 1)
                    psw_add_jishu_xilie_ldse(faction_name, 1)
                    psw_dlc6_jbdll_zqxy_effect_apply(faction_name, psw_main_character)
                    cm:callback(function()
                        local ran_num_xingfa = cm:random_number(100, 1)
                        if ran_num_xingfa <= 50 then
                            advice_dlc6_zqxy_2_1()
                        else
                            advice_dlc6_zqxy_1_1()
                        end
                    end, 17.5)
                end
                
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_gzqs") then
                    if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_bhsn") then
                        psw_dlc6_xingfa_juexing(faction_name, 40)
                    else
                        psw_dlc6_xingfa_juexing(faction_name, 17.5)
                    end
                else
                    local xingfa_sx = psw_resource_value(faction, "psw_shenxing")
                    local xingfa_xy =  psw_resource_value(faction, "psw_xingyun")
                    local xingfa_js = psw_get_num(faction_name, "psw_jianshu")
                    local xingfa_ml =  psw_resource_value(faction, "psw_moli")
                    local xingfa_meili = psw_get_num(faction_name, "psw_meili")
                    local xingfa_zx = psw_get_num(faction_name, "psw_zhixing")
                    local xingfa_zhiyu = psw_get_num(faction_name, "psw_zhiyu")
                    local xingfa_delay_time = 17.5
                    if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_bhsn") then
                        xingfa_delay_time = 40
                    end
                    cm:callback(function()
                        psw_dlc6_xingfa_juexing(faction_name, xingfa_sx)
                        psw_dlc6_xingfa_juexing(faction_name, xingfa_xy)
                        psw_dlc6_xingfa_juexing(faction_name, xingfa_js)
                        psw_dlc6_xingfa_juexing(faction_name, xingfa_ml)
                        psw_dlc6_xingfa_juexing(faction_name, xingfa_meili)
                        psw_dlc6_xingfa_juexing(faction_name, xingfa_zx)
                        psw_dlc6_xingfa_juexing(faction_name, xingfa_zhiyu)
                    end, xingfa_delay_time)
                end
                
                
            -------------  向着未来闪耀  -------------------

            elseif (jishu_ex_count <= 1 or psw_faction_has_effect_bundle(faction_name, "xzwlsy_blxdzk_install")) and dilemma_key == "psw_tf_ex_xzwlsy" and not psw_faction_has_effect_bundle(faction_name, set) and not psw_faction_has_effect_bundle(faction_name, set_main) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                advice_dlc6_xzwlsy_1()
                
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_ex_count(faction_name, 1)
                psw_add_jishu_moli(faction_name, 3)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_mofashaonv(faction_name, 1)
                psw_add_count_moli(faction_name, 1)
                psw_add_jishu_meili(faction_name, 3)
                local xzwlsy_mfsnjs = psw_resource_value(faction, "jishu_mofashaonv")
                psw_add_jishu_kxct(faction_name, xzwlsy_mfsnjs*3)
                psw_dlc6_xzwlsy_spell_effect_apply(xzwlsy_mfsnjs, faction_name)
                psw_add_yly_zhijie(faction_name, 1)
                
                effect_list = {
                    {effect = "psw_dlc6_xzwlsy_yly_qxmfsn", effect_scope = "faction_to_character_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_ex_xzwlsy", 0, effect_list)
                
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_bshu") then
                    local effect_list_4 = {
                        {effect = "psw_dlc6_bshu_khyz", effect_scope = "faction_to_character_own", effect_num = 1},
                    }
                    
                    psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_bshu_up", 0, effect_list_4)
                end
                
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_lbszx_nor") then
                    psw_add_yly_zhijie(faction_name, 1)
                    psw_add_jishu_ex_count(faction_name, -1)
                else
                    ---凤凰の庭院
                    psw_dlc7_xlfh_whty_effect(faction_name)
                end
                
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                

                
            -------------  守矢风祝  -------------------

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_miao_1" and not psw_faction_has_effect_bundle(faction_name, set) and not psw_faction_has_effect_bundle(faction_name, set_main) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_ex_count(faction_name, 1)
                
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_xilie_hxx(faction_name, 1)
                psw_add_jishu_xingyun(faction_name, 3)
                psw_moyin_mianyi_zaie_apply(faction)
                psw_moyin_mianyi_wenyi_apply(faction)
                psw_jyjj_main_unlock(faction_name, "psw_jyjj_xd_zaomiao_ywzjy", true)
                common.trigger_soundevent("zaomiao_1")
                advice_dlc7_zaomiao_1_1()
                effect_list = {
                    {effect = "psw_dlc7_zaomiao_hsqs", effect_scope = "faction_to_character_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, effect_main_key, 0, effect_list)
            
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
            
            
            
            
            -------------  天蓝色的巡洋舰  -------------------

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_tsg_1" and not psw_faction_has_effect_bundle(faction_name, set) and not psw_faction_has_effect_bundle(faction_name, set_main) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_ex_count(faction_name, 1)
                
                psw_add_jishu_bing(faction_name, 1)
                psw_add_jishu_shenhai(faction_name, 1)
                psw_add_jishu_jianniang(faction_name, 1)
                psw_dlc7_tsg_get_effect(faction_name)
                common.trigger_soundevent("tsg_1")
                advice_dlc7_tsg_1_1()
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                
            -------------  谜之银发少女  -------------------

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_firefly_1" and not psw_faction_has_effect_bundle(faction_name, set) and not psw_faction_has_effect_bundle(faction_name, set_main) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_ex_count(faction_name, 1)
                
                psw_add_jishu_meili(faction_name, 2)
                psw_add_jishu_xingyun(faction_name, 2)
                psw_jyjj_use_num_change(faction_name, 1, "max_level_up")
                psw_add_jishu_xuanze(faction_name, 1)
                common.trigger_soundevent("firefly_1")
                advice_dlc7_firefly_1_1()
                psw_main_data.global_data.have_firefly = true
                
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                psw_dlc7_firefly_get_test(faction_name)
                psw_dlc7_firefly_xhls_juexing(faction_name)
                
            -------------  基沃托斯与世界的中心  -------------------

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_jwts_1" and not psw_faction_has_effect_bundle(faction_name, set) and not psw_faction_has_effect_bundle(faction_name, set_main) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_ex_count(faction_name, 1)
                
                psw_add_jishu_xilie_jwts(faction_name, 1)
                psw_aplly_costom_effect_bundle_with_time_hidden("psw_dlc7_jwts_abds_test_bundle", faction, 5)
                psw_aplly_costom_effect_bundle_with_time_hidden("psw_dlc7_jwts_wmdgs_test_bundle", faction, 10)
                psw_aplly_costom_effect_bundle_with_time_hidden("psw_dlc7_jwts_rfm_test_bundle", faction, 15)
                psw_aplly_costom_effect_bundle_with_time_hidden("psw_dlc7_jwts_clj_test_bundle", faction, 15)
                psw_aplly_costom_effect_bundle_with_time_hidden("psw_dlc7_jwts_rabbit_test_bundle", faction, 20)
                psw_add_swyh_install_smxg_jishu(faction_name, 1)
                common.trigger_soundevent("jwts_1")
                advice_dlc7_jwts_1_1()
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  引导妖精 菲欧  -------------------

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_ams_1" and not psw_faction_has_effect_bundle(faction_name, set) and not psw_faction_has_effect_bundle(faction_name, set_main) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_ex_count(faction_name, 1)
                
                psw_add_jishu_jingling(faction_name, 1)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_shen(faction_name, 1)
                psw_add_jishu_xilie_ldse(faction_name, 1)
                common.trigger_soundevent("ams_1")
                advice_dlc7_ams_1_1()
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_aplly_costom_effect_bundle_hidden_fn("psw_dlc7_ams_ydyj_gzqs_100", faction_name)
                
            -------------  岁主共鸣者  -------------------

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_jinxi_1" and not psw_faction_has_effect_bundle(faction_name, set) and not psw_faction_has_effect_bundle(faction_name, set_main) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_ex_count(faction_name, 1)
                psw_add_jishu_shenxing(faction_name, 2)
                psw_tfmw_main_atk_effect(1, faction_name, "default")
                cm:add_ancillary_to_faction(faction, "psw_dlc7_jinxi_shsr", false)
                psw_jyjj_main_unlock(faction_name, "psw_jyjj_sx_jinxi_yishi_1", true)
                psw_add_jishu_xilie_gmz(faction_name, 1)
                psw_add_jishu_long(faction_name, 1)
                
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                common.trigger_soundevent("jinxi_1")
                advice_dlc7_jinxi_1()
                psw_dlc7_mc_get_gmz(faction_name, "psw_dlc7_mc_jinxi")
                
                
                
            -------------  向度重塑  -------------------

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_klt_1" and not psw_faction_has_effect_bundle(faction_name, set) and not psw_faction_has_effect_bundle(faction_name, set_main) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_ex_count(faction_name, 1)
                psw_add_jishu_xilie_gmz(faction_name, 1)
                psw_add_free_repick_num(faction_name, 1)
                psw_add_jishu_meili(faction_name, 3)
                psw_add_klt_ksjz(faction_name, 1)
                common.trigger_soundevent("klt_1")
                advice_dlc7_klt_1_1()
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                psw_dlc7_mc_get_gmz(faction_name, "psw_dlc7_mc_klt")
            
            
            -------------  圣祈凝辉  -------------------

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_feibi_1" and not psw_faction_has_effect_bundle(faction_name, set) and not psw_faction_has_effect_bundle(faction_name, set_main) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_ex_count(faction_name, 1)
                psw_add_jishu_xilie_gmz(faction_name, 1)
                
                psw_add_jishu_guangmi(faction_name, 2)
                local feibi_num = psw_resource_value(faction, "jishu_guangmi")
                psw_add_jishu_shenxing(faction_name, feibi_num)
                psw_add_jishu_xingyun(faction_name, feibi_num)
                psw_jyjj_main_get(faction_name, "psw_jyjj_xd_feibi_zhudao")
                
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                psw_dlc7_mc_get_gmz(faction_name, "psw_dlc7_mc_feibi")
                psw_main_play_movie("feibi", 15)
                
                
            -------------  沉睡的鲸鱼  -------------------

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_xingye_1" and not psw_faction_has_effect_bundle(faction_name, set) and not psw_faction_has_effect_bundle(faction_name, set_main) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_ex_count(faction_name, 1)
                
                psw_add_jishu_xilie_abds(faction_name, 1)
                psw_add_jishu_xilie_jwts(faction_name, 1)
                psw_dlc7_xingye_get_effect(faction_name)
                common.trigger_soundevent("xingye_1")
                advice_dlc7_xingye_1_1()
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  阳炎型八号舰  -------------------

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_xuefeng_1" and not psw_faction_has_effect_bundle(faction_name, set) and not psw_faction_has_effect_bundle(faction_name, set_main) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_ex_count(faction_name, 1)
                psw_dlc7_xuefeng_get_effect(faction_name)
                
                psw_add_jishu_shenhai(faction_name, 1)
                psw_add_jishu_jianniang(faction_name, 1)
                common.trigger_soundevent("xuefeng_1")
                advice_dlc7_xuefeng_1_1()
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  魔导操壳  -------------------

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_lilika_1" and not psw_faction_has_effect_bundle(faction_name, set) and not psw_faction_has_effect_bundle(faction_name, set_main) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_ex_count(faction_name, 1)
                psw_dlc7_lilika_get_effect(faction_name)
                
                psw_add_jishu_guangmi(faction_name, 1)
                common.trigger_soundevent("lilika_1")
                advice_dlc7_lilika_1()
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                psw_main_data.global_data.lilika_fac_name = faction_name
                
                
            -------------  魔法少女与恶曾经敌对  -------------------
            
            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_sp_baiye" and not psw_faction_has_effect_bundle(faction_name, set_main) and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_jishu_zhongmo(1)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_mofashaonv(faction_name, 2)
                psw_add_jishu_xingyun(faction_name, 3)
                psw_dlc7_baiye_xfzh_effect(faction_name)
                psw_aplly_costom_effect_bundle_hidden_fn("psw_dlc7_baiye_lucky_effect_bundle", faction_name)
                
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                if not psw_faction_has_effect_bundle(faction_name, "psw_dlc7_baiye_bgm") then
                    common.trigger_soundevent("baiye_start_bgm")
                    psw_apply_non_effect_bundle_to_all_player("psw_dlc7_baiye_bgm")
                end
                
                psw_main_data.player_data[faction_name].baiye_fac_name = faction_name
                
            -------------  纯白之天启  -------------------
            
            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_sp_kokoro" and not psw_faction_has_effect_bundle(faction_name, set_main) and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_jishu_zhongmo(1)
                psw_add_nor_count(faction_name, 1)
                common.trigger_soundevent("kokoro_sp")
                advice_dlc7_kokoro_1()
                psw_add_jishu_jingling(faction_name, 1)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_xilie_ldse(faction_name, 1)
                psw_add_jishu_xingyun(faction_name, 3)
                psw_add_jishu_xuanze(faction_name, 1)
                
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                
            -------------  玄龙门门主  -------------------
            
            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_sp_feixiao" and not psw_faction_has_effect_bundle(faction_name, set_main) and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_jishu_zhongmo(1)
                psw_add_nor_count(faction_name, 1)
                psw_jyjj_main_unlock(faction_name, "psw_jyjj_xg_feixiao_gwzz", false)
                psw_jyjj_main_unlock(faction_name, "psw_jyjj_xg_feixiao_kjfl", false)
                psw_jyjj_main_unlock(faction_name, "psw_jyjj_xg_feixiao_xsqj", false)
                psw_add_jishu_ewai_xingyun(faction_name, 5)
                psw_add_jishu_xingyun(faction_name, 1)
                psw_add_jishu_zhiyu(faction_name, 1)
                psw_add_free_repick_num(faction_name, 1)
                local feixiao_jyjj_pool = {
                    "psw_jyjj_xg_feixiao_gwzz",
                    "psw_jyjj_xg_feixiao_kjfl",
                    "psw_jyjj_xg_feixiao_xsqj",
                }
                local fx_index = cm:random_number(#feixiao_jyjj_pool)
                local feixiao_jyjj = feixiao_jyjj_pool[fx_index]
                psw_jyjj_main_get(faction_name, feixiao_jyjj)
                psw_jyjj_main_lock(faction_name, feixiao_jyjj)
                psw_add_turn_jyjj_reward(faction_name, 1)
                psw_jyjj_use_num_change(faction_name, 1, "max_level_up")
                common.trigger_soundevent("feixiao_sp")
                advice_dlc7_feixiao_1()
                psw_add_jishu_xilie_jwts(faction_name, 1)
                
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                
            -------------  灾异猎人  -------------------
            
            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_sp_tifeng" and not psw_faction_has_effect_bundle(faction_name, set_main) and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_jishu_zhongmo(1)
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_xilie_ldd(faction_name, 1)
                psw_dlc7_tifeng_get_effect(faction_name)
                common.trigger_soundevent("tifeng_sp")
                advice_dlc7_tifeng_1()
                
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                
                
            -------------  绚丽凤凰·小凤  -------------------
            
            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_sp_xlfh" and not psw_faction_has_effect_bundle(faction_name, set_main) and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_jishu_zhongmo(1)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_guangmi(faction_name, 1)
                psw_dlc7_xlfh_get_effect(faction_name)
                
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  光之美少女  -------------------
            
            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_sp_luluka" and not psw_faction_has_effect_bundle(faction_name, set_main) and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_jishu_zhongmo(1)
                psw_add_nor_count(faction_name, 1)
                
                
                psw_add_jishu_mofashaonv(faction_name, 1)
                local jishu_luluka = psw_resource_value(faction, "jishu_mofashaonv")
                local jishu_luluka_2 = psw_resource_value(faction, "jishu_heian")
                psw_dlc7_luluka_get_effect(faction_name)
                psw_add_jishu_meili(faction_name, jishu_luluka * 2)
                psw_add_jishu_guangmi(faction_name, jishu_luluka_2 + 1)
                
                psw_add_jishu_heian(faction_name, 1)
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                
                
            -------------  新月诞生的少女  -------------------

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_shaonv" and not psw_faction_has_effect_bundle(faction_name, set) and not psw_faction_has_effect_bundle(faction_name, set_main) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_ex_count(faction_name, 1)
                
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_shen(faction_name, 1)
                psw_dlc7_shaonv_get_effect(faction_name)
                
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                psw_add_jishu_meili(faction_name, 0)
                
                ---凤凰の庭院
                psw_dlc7_xlfh_whty_effect(faction_name)
                
            -------------  漆黑的摩天楼  -------------------

            elseif jishu_ex_count <= 1 and dilemma_key == "psw_tf_ex_chazuo" and not psw_faction_has_effect_bundle(faction_name, set) and not psw_faction_has_effect_bundle(faction_name, set_main) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_jishu_zhongmo(1)
                psw_add_jishu_ex_count(faction_name, 1)
                psw_add_ex_count(faction_name, 1)
                
                psw_add_jishu_heian(faction_name, 1)
                psw_dlc7_chazuo_get_effect(faction_name)
                
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                
                        -------------  鹿目圆香专天  -------------------

            elseif dilemma_key == "psw_tf_nor_lmyx_zt" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_lmyx_zt") and not psw_faction_has_effect_bundle(faction_name, "set_lhbs_player") and not psw_main_data.global_data.set_main_psw_tf_nor_lmyx_zt then
            
                psw_add_jishu_mofashaonv(faction_name, 1)
                local lmyx_mfsnjs = psw_resource_value(faction, "jishu_mofashaonv")
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:add_ancillary_to_faction(faction, "psw_dlc6_lhbs_lmyx", false)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_moli(faction_name, 2)
                psw_add_lmyx_yinguo_jishu(faction_name, lmyx_mfsnjs + 2)
                psw_add_count_moli(faction_name, 1)
                psw_add_jishu_guangmi(faction_name, 1)
                
                
                
                if faction:has_effect_bundle("hero_select_lmyx") then
                    cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                        {
                        "cstf_psw_tf_nor_lmyx_zt"
                        }
                    )
                    local ran_num_lmyx_cstf = cm:random_number(6, 2)
                    psw_add_lmyx_yinguo_jishu(faction_name, ran_num_lmyx_cstf)
                    psw_add_jishu_shenxing(faction_name, 2)
                    cm:apply_effect_bundle_to_character("cstf_lmyx_yhzl_ztex", psw_main_character, 0);
                    advice_psw_tf_nor_lmyx_zthq()
                    cm:callback(function()
                        psw_lmyx_cstf_jx_xy(faction_name, psw_main_character)
                    end, 70)
                else
                    common.trigger_soundevent("lmyx_nor_get")
                end
                
                psw_main_data.global_data.lmyx_faction_name = faction_name
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_lmyx_zt", faction_name)
                psw_aplly_costom_effect_bundle_hidden_fn("set_lhbs_player", faction_name)
                psw_main_data.global_data.set_main_psw_tf_nor_lmyx_zt = true
                
                
                
                        -------------  晓美焰专天  -------------------

            elseif dilemma_key == "psw_tf_nor_xmy_zt" and not faction:has_effect_bundle("set_psw_tf_nor_xmy_zt") and not psw_faction_has_effect_bundle(faction_name, "set_lhbs_player") and not psw_main_data.global_data.set_main_psw_tf_nor_xmy_zt then
                
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:add_ancillary_to_faction(faction, "psw_dlc6_lhbs_xmy", false)
                
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_moli(faction_name, 2)
                psw_add_jishu_mofashaonv(faction_name, 1)
                psw_add_count_moli(faction_name, 1)
                psw_add_jishu_heian(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_xmy_zt", faction_name)
                psw_aplly_costom_effect_bundle_hidden_fn("set_lhbs_player", faction_name)
                psw_main_data.global_data.set_main_psw_tf_nor_xmy_zt = true
                psw_main_data.global_data.xmy_faction_name = faction_name
                
                
                        -------------  巴麻美专天  -------------------

            elseif dilemma_key == "psw_tf_nor_bmm_zt" and not faction:has_effect_bundle("set_psw_tf_nor_bmm_zt") and not psw_faction_has_effect_bundle(faction_name, "set_lhbs_player") and not psw_main_data.global_data.set_main_psw_tf_nor_bmm_zt then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:add_ancillary_to_faction(faction, "psw_dlc6_lhbs_bmm", false)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_moli(faction_name, 2)
                psw_add_jishu_mofashaonv(faction_name, 1)
                psw_add_count_moli(faction_name, 1)
                
                psw_main_data.global_data.bmm_faction_name = faction_name
                psw_main_data.player_data[faction_name].bmm_faction = faction_name
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_bmm_zt", faction_name)
                psw_aplly_costom_effect_bundle_hidden_fn("set_lhbs_player", faction_name)
                psw_main_data.global_data.set_main_psw_tf_nor_bmm_zt = true

                        -------------  美树沙耶香专天  -------------------

            elseif dilemma_key == "psw_tf_nor_mssyx_zt" and not faction:has_effect_bundle("set_psw_tf_nor_mssyx_zt") and not psw_faction_has_effect_bundle(faction_name, "set_lhbs_player") and not psw_main_data.global_data.set_main_psw_tf_nor_mssyx_zt then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:add_ancillary_to_faction(faction, "psw_dlc6_lhbs_mssyx", false)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_moli(faction_name, 2)
                psw_add_jishu_mofashaonv(faction_name, 1)
                psw_add_count_moli(faction_name, 1)
                
                psw_main_data.global_data.mssyx_faction_name = faction_name
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_mssyx_zt", faction_name)
                psw_aplly_costom_effect_bundle_hidden_fn("set_lhbs_player", faction_name)
                psw_main_data.global_data.set_main_psw_tf_nor_mssyx_zt = true
                
                        -------------  佐仓杏子专天  -------------------

            elseif dilemma_key == "psw_tf_nor_zcxz_zt" and not faction:has_effect_bundle("set_psw_tf_nor_zcxz_zt") and not psw_faction_has_effect_bundle(faction_name, "set_lhbs_player") and not psw_main_data.global_data.set_main_psw_tf_nor_zcxz_zt then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:add_ancillary_to_faction(faction, "psw_dlc6_lhbs_zcxz", false)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_moli(faction_name, 2)
                psw_add_jishu_mofashaonv(faction_name, 1)
                psw_add_count_moli(faction_name, 1)
                
                psw_main_data.global_data.zcxz_faction_name = faction_name
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_zcxz_zt", faction_name)
                psw_aplly_costom_effect_bundle_hidden_fn("set_lhbs_player", faction_name)
                psw_main_data.global_data.set_main_psw_tf_nor_zcxz_zt = true

            
                        -------------  神名文字（阿露）  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_alu_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_alu_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_nor_alu_nor", psw_main_character, 0);
                
                psw_add_jishu_heian(faction_name, 1)
                
                psw_add_yctz_effect_to_faction(faction_name, "kxl")
                
                psw_add_nor_count(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_alu_nor", faction_name)
                psw_add_jishu_xilie_jwts(faction_name, 1)
                        -------------  神名文字（鹤城）  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_hecheng_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_hecheng_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_nor_hecheng_nor", psw_main_character, 0);
                
                
                
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_swyh_install_smxg_jishu(faction_name, 1)
                
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_ssy_tf(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_hecheng_nor", faction_name)
                psw_add_jishu_xilie_jwts(faction_name, 1)
                
                        -------------  庞大巨龙的威势  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_sly_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_sly_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_nor_sly_nor", psw_main_character, 0);
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_long(faction_name, 1)
                
                psw_add_jishu_zhixing(faction_name, 2)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_sly_nor", faction_name)
                psw_add_jishu_xilie_ldd(faction_name, 1)

            
                        -------------  斩破黑与白的剑圣  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_shanling_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_shanling_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_nor_shanling_nor", psw_main_character, 0);
                
                psw_add_jishu_guangmi(faction_name, 1)
                
                
                
                psw_add_jishu_jianshu(faction_name, 2)
                psw_add_nor_count(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_shanling_nor", faction_name)
                psw_add_jishu_xilie_ldd(faction_name, 1)

            
                        -------------  被困的悲悯魔王  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_yeying_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yeying_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_nor_yeying_nor", psw_main_character, 0);
                
                psw_add_jishu_guangmi(faction_name, 1)
                
                psw_add_nor_count(faction_name, 1)
                
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_yeying_nor", faction_name)
                psw_add_jishu_xilie_ldd(faction_name, 1)
                        -------------  奇迹的现人神  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_zaomiao_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_zaomiao_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_jishu_shenxing(faction_name, 1)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_xingyun(faction_name, 2)
                
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_zhiyu(faction_name, 2)
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_zaomiao_nor", faction_name)
                psw_add_jishu_xilie_hxx(faction_name, 1)
            
                        -------------  Le Malin  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_edu_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_edu_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_nor_edu_nor", psw_main_character, 0);
                
                cm:add_ancillary_to_faction(faction, "edu_zsdm", false)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_xingyun(faction_name, 2)
                cm:add_ancillary_to_faction(faction, "blhx_xzmf_1", false)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_bing(faction_name, 1)
                psw_add_jishu_shenhai(faction_name, 1)
                psw_add_hgd_djs(faction_name, -3)
                psw_add_jishu_jianniang(faction_name, 1)
                psw_add_jishu_geji(faction_name, 1)
                
                if faction:has_effect_bundle("hero_select_edu") then
                    advice_edu_zthq()
                    cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                        {
                        "cstf_edu_zt"
                        }
                    )
                    psw_delete_ancillary_with_time_delay(faction, "edu_xfzd", 0.1)
                    cm:add_ancillary_to_faction(faction, "edu_syzj", false)
                    cm:add_ancillary_to_faction(faction, "edu_yldbt", false)
                    cm:remove_effect_bundle_from_character("jnz_tf_psw_tf_nor_edu_nor", psw_main_character);
                    cm:apply_effect_bundle_to_character("cstf_edu_ztex", psw_main_character, 0);
                end
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_edu_nor", faction_name)
                
                        -------------  樱桃炸弹  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_ytzd_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_ytzd_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:add_ancillary_to_faction(faction, "ytzd_smr", false)
                if nor_count <= 2 then
                    cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_nor_ytzd_nor2", psw_main_character, 0);
                elseif nor_count > 2 then
                    cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_nor_ytzd_nor1", psw_main_character, 0);
                end
                
                psw_add_jishu_meili(faction_name, 2)
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_lmtg_nor") then
                    cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_nor_lmtg_nor3", psw_main_character, 0);
                    psw_add_jishu_meili(faction_name, 1)
                end
                
                
                psw_add_nor_count(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_ytzd_nor", faction_name)
                psw_add_jishu_xilie_sfly(faction_name, 1)

                
                        -------------  蓝莓特攻  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_lmtg_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_lmtg_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:add_ancillary_to_faction(faction, "lmtg_teh", false)
                if nor_count <= 2 then
                    cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_nor_lmtg_nor2", psw_main_character, 0);
                elseif nor_count > 2 then
                    cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_nor_lmtg_nor1", psw_main_character, 0);
                end
                
                psw_add_jishu_meili(faction_name, 2)
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_ytzd_nor") then
                    cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_nor_lmtg_nor3", psw_main_character, 0);
                    psw_add_jishu_meili(faction_name, 1)
                end
                
                
                psw_add_nor_count(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_lmtg_nor", faction_name)
                psw_add_jishu_xilie_sfly(faction_name, 1)

                
                        -------------  神里绫华  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_sllh_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_sllh_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:add_ancillary_to_faction(faction, "sllh_wqzhg", false)
                cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_nor_sllh_nor", psw_main_character, 0);
                
                psw_add_jishu_jianshu(faction_name, 2)
                
                if faction:has_effect_bundle("hero_select_sllh") then
                    advice_sllh_zthq()
                    cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                        {
                        "cstf_sllh_zt"
                        }
                    )
                    cm:remove_effect_bundle_from_character("jnz_tf_psw_tf_nor_sllh_nor", psw_main_character);
                    cm:apply_effect_bundle_to_character("cstf_sllh_ztex", psw_main_character, 0);
                end
                
                psw_add_jishu_bing(faction_name, 1)
                psw_add_nor_count(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_sllh_nor", faction_name)
                
                
                        -------------  珊瑚宫心海  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_shgxh_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_shgxh_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_nor_shgxh_nor", psw_main_character, 0);
                
                psw_add_jishu_meili(faction_name, 2)
                
                psw_add_jishu_shenhai(faction_name, 1)
                psw_add_nor_count(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_shgxh_nor", faction_name)
                
                
                        -------------  神名文字（樱子）  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_yingzi_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yingzi_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_nor_yingzi_nor", psw_main_character, 0);
                psw_add_jishu_guangmi(faction_name, 1)
                
                psw_add_swyh_install_smxg_jishu(faction_name, 1)
                
                psw_add_jishu_ssy_tf(faction_name, 1)
                psw_add_nor_count(faction_name, 1)
                
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_yingzi_nor", faction_name)
                psw_add_jishu_xilie_jwts(faction_name, 1)
                
                        -------------  神名文字（渚）  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_zhu_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_zhu_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_jishu_guangmi(faction_name, 1)
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_sywh_1") == true then
                    cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_nor_zhu_nor2", psw_main_character, 0);
                    
                elseif 1 == 1 then
                    cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_nor_zhu_nor", psw_main_character, 0);
                end
                psw_add_jishu_xingyun(faction_name, 1)
                psw_add_jishu_shenxing(faction_name, 1)
                psw_add_swyh_install_smxg_jishu(faction_name, 1)
                
                psw_add_jishu_ssy_tf(faction_name, 1)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_zhixing(faction_name, 2)
                
                --未花专天
                if faction:has_effect_bundle("hero_select_nanaya") then
                    psw_play_dlc_music("mika_zt_zhu")
                    psw_dlc7_mika_zt_effect_zhu(faction_name, psw_main_character)
                end
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_zhu_nor", faction_name)
                psw_add_jishu_xilie_jwts(faction_name, 1)
                psw_dlc6_bhysy_yzm_jiance(faction_name)
                
                psw_dlc6_swyh_install_chh(faction_name, false)
                
                
                        -------------  神名文字（伊吕波）  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_ylb_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_ylb_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:add_ancillary_to_faction(faction, "ylb_hsdz", false)
                cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_nor_ylb_nor", psw_main_character, 0);
                
                psw_add_jishu_heian(faction_name, 1)
                
                psw_add_nor_count(faction_name, 1)
                
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_ylb_nor", faction_name)
                psw_add_jishu_xilie_jwts(faction_name, 1)
                
                
                        -------------  神名文字（晴奈）  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_qingnai_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_qingnai_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:add_ancillary_to_faction(faction, "qingnai_msj", false)
                cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_nor_qingnai_nor", psw_main_character, 0);
                
                psw_add_jishu_heian(faction_name, 1)
                
                psw_add_nor_count(faction_name, 1)
                
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_qingnai_nor", faction_name)
                psw_add_jishu_xilie_jwts(faction_name, 1)
                
                        -------------  蓬莱山辉夜  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_plshy_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_plshy_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_nor_plshy_nor", psw_main_character, 0);
                
                psw_add_jishu_shenxing(faction_name, 1)
                psw_add_jishu_xingyun(faction_name, 1)
                
                cm:trigger_mission(faction_name, "mis_plshy_ljzy", true)
                cm:trigger_mission(faction_name, "mis_plshy_fjs", true)
                cm:trigger_mission(faction_name, "mis_plshy_hsdpy", true)
                cm:trigger_mission(faction_name, "mis_plshy_ymx", true)
                cm:trigger_mission(faction_name, "mis_plshy_plsz", true)
                
                
                
                psw_add_nor_count(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_plshy_nor", faction_name)
                psw_add_jishu_xilie_hxx(faction_name, 1)
                
                        -------------  五彩斑斓的世界  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_wcbldsj_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_wcbldsj_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:add_ancillary_to_faction(faction, "wcbldsj_cjdby", false)
                
                psw_add_jishu_xingyun(faction_name, 2)
                psw_add_jishu_moli(faction_name, 2)
                psw_add_jishu_meili(faction_name, 2)
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_wcbldsg_nor") and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yrhtdsj_nor") then
                    psw_add_jishu_meili(faction_name, 2)
                    psw_add_jishu_xingyun(faction_name, 2)
                    psw_add_jishu_shenxing(faction_name, 2)
                    psw_add_jishu_moli(faction_name, 2)
                    psw_add_jishu_jianshu(faction_name, 2)
                end
                
                psw_add_jishu_jiyi(faction_name, 1)
                psw_add_nor_count(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_wcbldsj_nor", faction_name)
                
                
                        -------------  五彩斑斓的曙光  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_wcbldsg_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_wcbldsg_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_ex_limit_jiefang(faction_name)
                
                psw_add_jishu_ewai_xingyun(faction_name, 5)
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_wcbldsj_nor") and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yrhtdsj_nor") then
                    psw_add_jishu_meili(faction_name, 2)
                    psw_add_jishu_xingyun(faction_name, 2)
                    psw_add_jishu_shenxing(faction_name, 2)
                    psw_add_jishu_moli(faction_name, 2)
                    psw_add_jishu_jianshu(faction_name, 2)
                end
                
                psw_add_jishu_jiyi(faction_name, 1)
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_zhixing(faction_name, 2)
                psw_add_jishu_xuanze(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_wcbldsg_nor", faction_name)
                
                
                        -------------  映入红瞳的世界  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_yrhtdsj_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yrhtdsj_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_nor_yrhtdsj_nor", psw_main_character, 0);
                
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_wcbldsg_nor") and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_wcbldsj_nor") then
                    psw_add_jishu_meili(faction_name, 2)
                    psw_add_jishu_xingyun(faction_name, 2)
                    psw_add_jishu_shenxing(faction_name, 2)
                    psw_add_jishu_moli(faction_name, 2)
                    psw_add_jishu_jianshu(faction_name, 2)
                end
                
                psw_add_jishu_jiyi(faction_name, 1)
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_miansi(faction_name, 1)
                psw_add_jishu_xuanze(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_yrhtdsj_nor", faction_name)
                
                
                        -------------  箭贯汝身！  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_jgrs_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_jgrs_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_nor_jgrs_nor", psw_main_character, 0);
                cm:add_ancillary_to_faction(faction, "jgrs_nwg", false)
                
                psw_add_jishu_xingyun(faction_name, 1)
                psw_add_jishu_guangmi(faction_name, 1)
                
                psw_add_jishu_jingling(faction_name, 1)
                psw_add_nor_count(faction_name, 1)
                
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_jgrs_nor", faction_name)
                psw_add_jishu_xilie_ldse(faction_name, 1)
                
                
                        -------------  小小引导者  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_xxydz_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_xxydz_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:add_ancillary_to_faction(faction, "xxydz_amshf", false)
                
                psw_add_jishu_xingyun(faction_name, 1)
                psw_add_jishu_guangmi(faction_name, 1)
                
                psw_add_jishu_jingling(faction_name, 2)
                psw_add_nor_count(faction_name, 1)
                
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_xxydz_nor", faction_name)
                psw_add_jishu_xilie_ldse(faction_name, 1)
                
                
                        -------------  小小优等生  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_xxyds_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_xxyds_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_nor_xxyds_nor", psw_main_character, 0);
                cm:add_ancillary_to_faction(faction, "xxyds_yzlsfz", false)
                
                psw_add_jishu_xingyun(faction_name, 2)
                psw_add_jishu_moli(faction_name, 2)
                psw_add_count_moli(faction_name, 1)
                psw_add_jishu_guangmi(faction_name, 1)
                
                psw_add_jishu_jingling(faction_name, 1)
                psw_add_jishu_bing(faction_name, 1)
                psw_add_nor_count(faction_name, 1)
                
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_xxyds_nor", faction_name)
                psw_add_jishu_xilie_ldse(faction_name, 1)
                
                
                        -------------  吃货公主  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_chgz_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_chgz_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_nor_chgz_nor", psw_main_character, 0);
                cm:add_ancillary_to_faction(faction, "chgz_gzzj", false)
                
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_jianshu(faction_name, 2)
                
                psw_add_nor_count(faction_name, 1)
                
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_chgz_nor", faction_name)
                psw_add_jishu_xilie_ldse(faction_name, 1)
                
                
                        -------------  猫耳魔法师  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_mermfs_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_mermfs_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:add_ancillary_to_faction(faction, "mermfs_hdmfs", false)
                
                psw_add_jishu_moli(faction_name, 2)
                psw_add_jishu_heian(faction_name, 1)
                psw_add_yctz_effect_to_faction(faction_name, "kxl")
                psw_add_nor_count(faction_name, 1)
                psw_add_count_moli(faction_name, 1)
                psw_add_jishu_kxct(faction_name, 3)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_mermfs_nor", faction_name)
                psw_add_jishu_xilie_ldse(faction_name, 1)
                
                
                        -------------  邻家索菲  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_ljsf_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_ljsf_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_nor_ljsf_nor", psw_main_character, 0);
                
                psw_add_jishu_xingyun(faction_name, 2)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_psw_battle_huifu(faction_name, 5)
                
                psw_add_nor_count(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_ljsf_nor", faction_name)
                
                        -------------  阿比盖尔  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_slmdmn_nor1" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_slmdmn_nor1") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_nor_slmdmn_nor1", psw_main_character, 0);
                
                psw_add_jishu_shenxing(faction_name, 2)
                psw_add_jishu_heian(faction_name, 1)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_shen(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_slmdmn_nor1", faction_name)
                
                
                        -------------  友情的羁绊  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_yqdjb_nor1" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yqdjb_nor1") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_jishu_heian(faction_name, 1)
                psw_add_nor_count(faction_name, 1)
                
                cm:remove_effect_bundle("set_yqdjb_yichouka", faction_name)
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_yqdjb_nor1", faction_name)
            
            
                        -------------  汝为有缘人  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_rwyyr_nor1" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_rwyyr_nor1") then
                
                common.trigger_soundevent("rwyyr_1")
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_nor_rwyyr_1", psw_main_character, 0);
                
                psw_add_jishu_shenxing(faction_name, 1)
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_shen(faction_name, 1)
                psw_add_jishu_jianshu(faction_name, 2)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_rwyyr_nor1", faction_name)
            
                        -------------  星神的记忆  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_xsdjy_nor1" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_xsdjy_nor1") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_jishu_shenxing(faction_name, 1)
                psw_add_jishu_xingyun(faction_name, 1)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_jingling(faction_name, 1)
                psw_add_jishu_shen(faction_name, 1)
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_jiyi(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_xsdjy_nor1", faction_name)
            
                        -------------  游戏胜利的方法  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_yxsldff_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yxsldff_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_nor_kong_1", psw_main_character, 0);
                cm:add_ancillary_to_faction(faction, "kong_yxxj", false)
                
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_ybbb_1") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_ybbb_2") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_ybbb_3") then
                    psw_delete_ancillary_with_time_delay(faction, "kong_yxxj", 0.1)
                    cm:add_ancillary_to_faction(faction, "kong_yxxj2", false)
                    cm:remove_effect_bundle_from_character("jnz_tf_nor_kong_1", psw_main_character);
                    cm:remove_effect_bundle_from_character("jnz_tf_ex_psw_tf_ex_ybbb_1_1", psw_main_character);
                    cm:apply_effect_bundle_to_character("jnz_tf_nor_kong_2", psw_main_character, 0);
                    cm:apply_effect_bundle_to_character("jnz_tf_ex_psw_tf_ex_ybbb_1_2", psw_main_character, 0);
                elseif psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_ybbb_2") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_ybbb_3") then
                    cm:apply_effect_bundle_to_character("jnz_tf_ex_psw_tf_ex_ybbb_2_2", psw_main_character, 0);
                elseif psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_ybbb_3") then
                    cm:apply_effect_bundle_to_character("jnz_tf_ex_psw_tf_ex_ybbb_3_2", psw_main_character, 0);
                end
                
                psw_add_nor_count(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_yxsldff_nor", faction_name)
            
                        -------------  冰之妖精  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_bzyj_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_bzyj_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_nor_bzyj", psw_main_character, 0);
                cm:add_ancillary_to_faction(faction, "bzyj_wmdj", false)
                
                psw_add_jishu_xingyun(faction_name, 2)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_bing(faction_name, 1)
                psw_add_jishu_jingling(faction_name, 1)
                
                
                if faction:has_effect_bundle("psw_main_ybdtq_chunxue") then
                    cm:remove_effect_bundle("psw_main_ybdtq_chunxue", faction_name)
                    cm:apply_effect_bundle("psw_main_ybdtq_chunxue_bzyj", faction_name, 4)
                elseif faction:has_effect_bundle("psw_main_ybdtq_shuangdong") then
                    cm:remove_effect_bundle("psw_main_ybdtq_shuangdong", faction_name)
                    cm:apply_effect_bundle("psw_main_ybdtq_shuangdong_bzyj", faction_name, 4)
                end
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_bzyj_nor", faction_name)
                psw_add_jishu_xilie_hxx(faction_name, 1)
                
                        -------------  華人小娘  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_hrxn_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_hrxn_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_nor_hrxn", psw_main_character, 0);
                cm:add_ancillary_to_faction(faction, "hrxn_psp", false)
                
                psw_add_nor_count(faction_name, 1)
                
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_hrxn_nor", faction_name)
                psw_add_jishu_xilie_hxx(faction_name, 1)
                
                        -------------  神器『绯』  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_sqf_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_sqf_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_nor_sqf", psw_main_character, 0);
                cm:add_ancillary_to_faction(faction, "zq_fei_shenqi_fei", false)
                
                psw_add_jishu_heian(faction_name, 1)
                psw_add_jishu_shenxing(faction_name, 1)
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_jianshu(faction_name, 2)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_sqf_nor", faction_name)
            
                        -------------  祝器『雪音』  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_zqxy_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_zqxy_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_nor_zqxy", psw_main_character, 0);
                cm:add_ancillary_to_faction(faction, "zhuqi_xueyin_zqxy", false)
                
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_xingyun(faction_name, 1)
                psw_add_jishu_shenxing(faction_name, 1)
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_jianshu(faction_name, 2)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_zqxy_nor", faction_name)
            
                        -------------  常盘台的白丝女王  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_cptnw_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_cptnw_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_nor_cptnw", psw_main_character, 0);
                cm:add_ancillary_to_faction(faction, "cptnw_jskzq", false)
                
                psw_add_jishu_xingyun(faction_name, 2)
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_zhixing(faction_name, 2)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_cptnw_nor", faction_name)
            
                        -------------  红魔族第一天才魔法师  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_blmf_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_blmf_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_nor_huihui", psw_main_character, 0);
                
                psw_add_jishu_moli(faction_name, 3)
                psw_add_nor_count(faction_name, 1)
                psw_add_count_moli(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_blmf_nor", faction_name)
            
                        -------------  红宝石之星  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_hbszx_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_hbszx_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_nor_hbszx", psw_main_character, 0);
                cm:add_ancillary_to_faction(faction, "hbszx_hbszx", false)
                
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_moli(faction_name, 2)
                psw_add_jishu_mofashaonv(faction_name, 1)
                psw_add_nor_count(faction_name, 1)
                psw_add_count_moli(faction_name, 1)
                
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_lbszx_nor") then
                    cm:remove_effect_bundle_from_character("jnz_tf_nor_hbszx", psw_main_character);
                    cm:apply_effect_bundle_to_character("jnz_tf_nor_hbszx_2", psw_main_character, 0);
                    psw_aplly_costom_effect_bundle_hidden_fn("xzwlsy_blxdzk_install", faction_name)
                end
                
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_bshu") then
                    local effect_list_3 = {
                        {effect = "psw_dlc6_bshu_khyz", effect_scope = "faction_to_character_own", effect_num = 1},
                    }
                    
                    psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_bshu_up", 0, effect_list_3)
                end
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_hbszx_nor", faction_name)
            
                        -------------  蓝宝石之星  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_lbszx_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_lbszx_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_nor_lbszx", psw_main_character, 0);
                cm:add_ancillary_to_faction(faction, "lbszx_lbszx", false)
                
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_moli(faction_name, 2)
                psw_add_jishu_mofashaonv(faction_name, 1)
                psw_add_nor_count(faction_name, 1)
                psw_add_count_moli(faction_name, 1)
                
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_hbszx_nor") then
                    cm:remove_effect_bundle_from_character("jnz_tf_nor_hbszx", psw_main_character);
                    cm:apply_effect_bundle_to_character("jnz_tf_nor_hbszx_2", psw_main_character, 0);
                    psw_aplly_costom_effect_bundle_hidden_fn("xzwlsy_blxdzk_install", faction_name)
                end
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_xzwlsy") then
                    psw_add_yly_zhijie(faction_name, 1)
                    psw_add_jishu_ex_count(faction_name, -1)
                end
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_lbszx_nor", faction_name)
            
                        -------------  灰之魔女  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_hzmn_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_hzmn_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_nor_hzmn", psw_main_character, 0);
                cm:add_ancillary_to_faction(faction, "mnzl_mnrj", false)
                
                psw_add_jishu_moli(faction_name, 2)
                psw_add_nor_count(faction_name, 1)
                psw_add_count_moli(faction_name, 1)
                psw_add_jishu_monv(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_hzmn_nor", faction_name)
            
                        -------------  悠远的天空  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_yzk_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yzk_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:add_ancillary_to_faction(faction, "yzk_bydyg", false)
                
                psw_add_jishu_xingyun(faction_name, 2)
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_ewai_xingyun(faction_name, 5)
                psw_add_jishu_jiyi(faction_name, 1)
                psw_add_jishu_zhiyu(faction_name, 2)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_yzk_nor", faction_name)
            
                        -------------  投影魔术  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_tyms_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_tyms_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_nor_tyms", psw_main_character, 0);
                
                psw_add_jishu_moli(faction_name, 2)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_jiushizhu(faction_name, 1)
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_jianshu(faction_name, 2)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_tyms_nor", faction_name)
            
                        -------------  无限剑制  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_wxjz_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_wxjz_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_nor_wxjz", psw_main_character, 0);
                
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_jiushizhu(faction_name, 1)
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_geji(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_wxjz_nor", faction_name)
            
                        -------------  樱之梦  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_yzm_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yzm_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_nor_yzm", psw_main_character, 0);
                psw_add_yctz_effect_to_faction(faction_name, "kxl")
                psw_add_jishu_heian(faction_name, 2)
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_miansi(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_yzm_nor", faction_name)
            
                        -------------  宵待月乃的忧伤  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_yxmj_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yxmj_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:add_ancillary_to_faction(faction, "yxmj_pjgj", false)
                
                psw_add_jishu_xingyun(faction_name, 1)
                psw_add_jishu_jingling(faction_name, 1)
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_zhiyu(faction_name, 3)
                psw_add_jishu_geji(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_yxmj_nor", faction_name)
            
                        -------------  无口萝莉  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_wkll_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_wkll_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_nor_wkll", psw_main_character, 0);
                cm:add_ancillary_to_faction(faction, "wkll_cmzj", false)
                
                psw_add_jishu_moli(faction_name, 2)
                psw_add_jishu_heian(faction_name, 1)
                psw_add_nor_count(faction_name, 1)
                psw_add_count_moli(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_wkll_nor", faction_name)
            
                        -------------  亚瑟王  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_ysw_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_ysw_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_nor_ysw", psw_main_character, 0);
                
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_meili(faction_name, 2)
                psw_add_jishu_miansi(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_ysw_nor", faction_name)
            
                        -------------  逆神巫女  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_nswn_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_nswn_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_nor_nswn", psw_main_character, 0);
                cm:add_ancillary_to_faction(faction, "nswn_ldycx", false)
                
                psw_add_jishu_shenxing(faction_name, 1)
                
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_jianshu(faction_name, 2)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_nswn_nor", faction_name)
                psw_add_jishu_xilie_sfly(faction_name, 1)
                
                        -------------  六道之力  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_ldzl_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_ldzl_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_jishu_shenxing(faction_name, 1)
                local ldzl_shenxing =  psw_resource_value(faction, "psw_shenxing")
                if ldzl_shenxing < 10 then
                    cm:apply_effect_bundle_to_character("jnz_tf_nor_ldzl", psw_main_character, 0);
                elseif ldzl_shenxing >= 10 then
                    cm:apply_effect_bundle_to_character("jnz_tf_nor_ldzl_2", psw_main_character, 0);
                end
                psw_add_yctz_effect_to_faction(faction_name, "kxl")
                psw_add_jishu_miansi(faction_name, 1)
                psw_add_nor_count(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_ldzl_nor", faction_name)
            
                        -------------  降临在灭亡之星的救世主  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_jddjsz_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_jddjsz_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_nor_shion", psw_main_character, 0);
                
                psw_add_jishu_shenxing(faction_name, 1)
                psw_add_jishu_xingyun(faction_name, 1)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_jiushizhu(faction_name, 1)
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_zhixing(faction_name, 2)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_jddjsz_nor", faction_name)
            
            -------------  双生子女仆  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_ssznp_nor" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_ssznp_nor") then
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:apply_effect_bundle_to_character("jnz_tf_nor_ssznp", psw_main_character, 0);
                
                psw_add_nor_count(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_ssznp_nor", faction_name)
            
            -------------  海边的“皇家淑女”  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_kewei_nor" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                cm:add_ancillary_to_faction(faction, "blhx_xzmf_1", false)
                cm:apply_effect_bundle_to_character("jnz_tf_nor_kewei", psw_main_character, 0);
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_jianniang(faction_name, 1)
                
                psw_add_hgd_djs(faction_name, -3)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_add_jishu_shenhai(faction_name, 1)
                psw_hh_start_kewei(faction_name)
                
            -------------  爱与希望的晨星  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_guanghui_nor" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                cm:add_ancillary_to_faction(faction, "blhx_xzmf_1", false)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_xingyun(faction_name, 2)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_jianniang(faction_name, 1)
                
                psw_add_jishu_meili(faction_name, 2)
                psw_add_hgd_djs(faction_name, 10)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_add_jishu_shenhai(faction_name, 2)
                psw_hh_start_guanghui(faction_name)
            
            -------------  喵女仆  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_chaijun_nor" and not psw_faction_has_effect_bundle(faction_name, set) then
                advice_chaijun_get_1()
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                cm:add_ancillary_to_faction(faction, "blhx_xzmf_1", false)
                psw_add_jishu_guangmi(faction_name, 1)
                cm:apply_effect_bundle_to_character("jnz_tf_nor_chaijun", psw_main_character, 0);
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_jianniang(faction_name, 1)
                
                psw_add_hgd_djs(faction_name, -3)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_add_jishu_shenhai(faction_name, 1)
                psw_hh_start_chaijun(faction_name)
                
            -------------  多愁的BIsqueDoll  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_daiduo_nor" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                cm:add_ancillary_to_faction(faction, "blhx_xzmf_1", false)
                psw_add_jishu_xingyun(faction_name, 2)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_jianniang(faction_name, 1)
                
                psw_add_hgd_djs(faction_name, -3)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_add_jishu_shenhai(faction_name, 1)
                psw_hh_start_daiduo(faction_name)
                
            -------------  誓约的星光  -------------------        
            
            elseif dilemma_key == "psw_tf_nor_qiye_nor" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                cm:add_ancillary_to_faction(faction, "blhx_xzmf_1", false)
                cm:apply_effect_bundle_to_character("jnz_tf_nor_qiye", psw_main_character, 0);
                
                psw_add_jishu_shenxing(faction_name, 1)
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_jianniang(faction_name, 1)
                
                psw_add_hgd_djs(faction_name, -3)
                psw_add_jishu_miansi(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_add_jishu_shenhai(faction_name, 1)
                
            -------------  神名文字 梓   -------------------        
            
            elseif dilemma_key == "psw_tf_nor_bzz_nor" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                cm:add_ancillary_to_faction(faction, "bzz_wsjx", false)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_shenxing(faction_name, 1)
                psw_add_jishu_alws(faction_name, 1)
                cm:apply_effect_bundle_to_character("jnz_tf_nor_bzz", psw_main_character, 0);
                
                psw_add_swyh_install_smxg_jishu(faction_name, 1)
                
                
                psw_add_jishu_ssy_tf(faction_name, 1)
                psw_add_nor_count(faction_name, 1)
                
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_add_jishu_xilie_jwts(faction_name, 1)
                
            -------------  神名文字 亚子   -------------------        
            
            elseif dilemma_key == "psw_tf_nor_yazi_nor" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                cm:add_ancillary_to_faction(faction, "yazi_shot", false)
                psw_add_jishu_heian(faction_name, 1)
                cm:apply_effect_bundle_to_character("jnz_tf_nor_yazi", psw_main_character, 0);

                psw_add_nor_count(faction_name, 1)
                
                
                if not psw_faction_has_effect_bundle(faction_name, set_main) then
                    local yazi_faction_list = cm:model():world():faction_list();
                    for i = 0, yazi_faction_list:num_items() - 1 do
                        local yazi_faction = yazi_faction_list:item_at(i)
                        local yazi_faction_name = yazi_faction:name()
                        if yazi_faction:is_human() == true then
                            psw_apply_effect_bundle_to_fac(yazi_faction_name, "yazi_bundle_ally", 0, "psw_missile_ap_damage_mult_hidden", "faction_to_force_own", 18)
                        end
                    end
                end
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_apply_non_effect_bundle_to_all_player(set_main)
                psw_add_jishu_xilie_jwts(faction_name, 1)
                
            -------------  神名文字 桃井   -------------------        
            
            elseif dilemma_key == "psw_tf_nor_taojing_nor" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                cm:apply_effect_bundle_to_character("jnz_tf_nor_taojing_1", psw_main_character, 0);
                
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_lv_nor") then
                    cm:remove_effect_bundle_from_character("jnz_tf_nor_taojing_1", psw_main_character);
                    cm:remove_effect_bundle_from_character("jnz_tf_nor_lv_1", psw_main_character);
                    cm:apply_effect_bundle_to_character("jnz_tf_nor_taojing_2", psw_main_character, 0);
                    cm:apply_effect_bundle_to_character("jnz_tf_nor_lv_2", psw_main_character, 0);
                end

                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_yxkfb(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_add_jishu_xilie_jwts(faction_name, 1)
                psw_add_jishu_xilie_qnkx(faction_name, 1)
                
            -------------  神名文字 绿   -------------------        
            
            elseif dilemma_key == "psw_tf_nor_lv_nor" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                cm:apply_effect_bundle_to_character("jnz_tf_nor_lv_1", psw_main_character, 0);
                
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_taojing_nor") then
                    cm:remove_effect_bundle_from_character("jnz_tf_nor_taojing_1", psw_main_character);
                    cm:remove_effect_bundle_from_character("jnz_tf_nor_lv_1", psw_main_character);
                    cm:apply_effect_bundle_to_character("jnz_tf_nor_taojing_2", psw_main_character, 0);
                    cm:apply_effect_bundle_to_character("jnz_tf_nor_lv_2", psw_main_character, 0);
                end

                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_yxkfb(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_add_jishu_xilie_jwts(faction_name, 1)
                psw_add_jishu_xilie_qnkx(faction_name, 1)
                
            -------------  风神少女   -------------------        
            
            elseif dilemma_key == "psw_tf_nor_fssn_nor" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                cm:apply_effect_bundle_to_character("jnz_tf_nor_fssn_1", psw_main_character, 0);

                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_shenxing(faction_name, 1)
                psw_add_jishu_xilie_hxx(faction_name, 1)
                
                local fssn_jishu_xilie_hxx = psw_get_num(faction_name, "jishu_xilie_hxx")
                if fssn_jishu_xilie_hxx >= 3 then
                    cm:remove_effect_bundle_from_character("jnz_tf_nor_fssn_1", psw_main_character);
                    cm:apply_effect_bundle_to_character("jnz_tf_nor_fssn_2", psw_main_character, 0);
                end
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  水之呼吸   -------------------        
            
            elseif dilemma_key == "psw_tf_nor_szhx_nor" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)

                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_jianshu(faction_name, 2)
                local tzl_jianshu = psw_get_num(faction_name, "psw_jianshu")
                psw_add_jishu_zhiyu(faction_name, tzl_jianshu)
                
                psw_main_data.player_data[faction_name].szhx_zhiyu = tzl_jianshu
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_hh_start_szhx(faction_name)
                
            -------------  不死者之王   -------------------        
            
            elseif dilemma_key == "psw_tf_nor_bszzw_nor" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                cm:add_ancillary_to_faction(faction, "bszzw_lxjz", false)
                psw_add_jishu_moli(faction_name, 3)
                psw_add_jishu_shenxing(faction_name, 1)
                psw_add_jishu_heian(faction_name, 1)
                psw_add_count_moli(faction_name, 1)
                
                psw_add_nor_count(faction_name, 1)
                local bszzw_mlcl = psw_resource_value(faction, "psw_moli")
                psw_main_data.player_data[faction_name].bszzw_mlcl = bszzw_mlcl
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  朱红新星   -------------------        
            
            elseif dilemma_key == "psw_tf_nor_zhxx_nor" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                cm:add_ancillary_to_faction(faction, "zhxx_dgcq", false)
                cm:apply_effect_bundle_to_character("jnz_tf_nor_zhxx", psw_main_character, 0);
                psw_add_jishu_shenxing(faction_name, 1)
                psw_add_jishu_heian(faction_name, 1)
                psw_add_psw_battle_huifu(faction_name, 5)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_miansi(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  纯白恶魔   -------------------        
            
            elseif dilemma_key == "psw_tf_nor_cbem_nor" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                cm:add_ancillary_to_faction(faction, "cbem_dysy", false)
                cm:add_ancillary_to_faction(faction, "cbem_sjjkj", false)
                cm:apply_effect_bundle_to_character("jnz_tf_nor_cbem", psw_main_character, 0);
                psw_add_jishu_shenxing(faction_name, 1)
                psw_add_jishu_heian(faction_name, 1)
                
                psw_add_nor_count(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  咖啡师的魔法   -------------------        
            
            elseif dilemma_key == "psw_tf_nor_kfsdmf_nor" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_ex_limit_jiefang(faction_name)

                psw_add_jishu_moli(faction_name, 2)
                psw_add_jishu_xingyun(faction_name, 2)
                psw_add_jishu_mofashaonv(faction_name, 1)
                psw_add_count_moli(faction_name, 1)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_zhiyu(faction_name, 3)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  伏行的混沌   -------------------        
            
            elseif dilemma_key == "psw_tf_nor_fxdhd_nor" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_jishu_heian(faction_name, 2)
                local nyz_heian = psw_resource_value(faction, "jishu_heian")
                local nyz_shenxing = math.floor(nyz_heian/2) + 1
                local nyz_hdfs = nyz_shenxing * 2
                
                psw_add_jishu_shenxing(faction_name, nyz_shenxing)
                psw_apply_effect_bundle_to_fac(faction_name, "psw_bundle_fxdhd_hdfs", 0, "psw_corruption_chaos_events_bad_hidden", "faction_to_province_own", nyz_hdfs)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_shen(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_hh_start_fxdhd(faction_name)
                
            -------------  零之记忆   -------------------        
            
            elseif dilemma_key == "psw_tf_nor_lzjy_nor" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                cm:apply_effect_bundle_to_character("jnz_tf_nor_lzjy", psw_main_character, 0);
                
                psw_add_jishu_jiyi(faction_name, 1)
                psw_add_nor_count(faction_name, 1)
                
                if faction:has_effect_bundle("hero_select_niao") then
                    psw_dlc6_cstf_niao_lzjy_juex(faction_name)
                end
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_hh_start_lzjy(faction_name)
                psw_dlc6_ygn_si_juexing(faction_name)
                
            -------------  祝祷远星   -------------------        
            
            elseif dilemma_key == "psw_tf_nor_zdyx_nor" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                cm:apply_effect_bundle_to_character("jnz_tf_nor_zdyx_1", psw_main_character, 0);
                
                psw_add_jishu_jiyi(faction_name, 1)
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_miansi(faction_name, 1)
                
                if faction:has_effect_bundle("hero_select_niao") then
                    psw_dlc6_cstf_niao_zdyx_juex(faction_name)
                end
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_hh_start_zdyx(faction_name)
                psw_dlc6_ygn_sheng_juexing(faction_name)
                
            -------------  妖精之祝福   -------------------        
            
            elseif dilemma_key == "psw_tf_nor_yjdzf_nor" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_jishu_shenxing(faction_name, 2)
                psw_add_jishu_xingyun(faction_name, 2)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_ewai_xingyun(faction_name, 5)
                psw_add_jishu_jingling(faction_name, 1)
                psw_add_jishu_xuanze(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  Darkness   -------------------        
            
            elseif dilemma_key == "psw_tf_nor_dark_nor" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_yctz_effect_to_faction(faction_name, "kxl")
                cm:apply_effect_bundle_to_character("jnz_tf_nor_dark", psw_main_character, 0);
                psw_add_nor_count(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  第一公主   -------------------        
            
            elseif dilemma_key == "psw_tf_nor_dygz_nor" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                cm:add_ancillary_to_faction(faction, "dygz_bbhhj", false)
                cm:add_ancillary_to_faction(faction, "dygz_xxzzj", false)
                cm:add_ancillary_to_faction(faction, "dygz_ggzkj", false)
                cm:apply_effect_bundle_to_character("jnz_tf_nor_dygz", psw_main_character, 0);
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_zhixing(faction_name, 2)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  小姨子   -------------------        
            
            elseif dilemma_key == "psw_tf_nor_xyz_nor" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_ex_limit_jiefang(faction_name)
                
                cm:apply_effect_bundle_to_character("jnz_tf_nor_xyz", psw_main_character, 0);
                psw_add_jishu_xingyun(faction_name, 2)
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_meili(faction_name, 2)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  人偶残件-腿部   --------------        
            
            elseif dilemma_key == "psw_tf_nor_syd_rocj_tuibu" then
            
                
                psw_main_data.player_data[faction_name].psw_tf_nor_syd_rocj_tuibu_jishu = psw_main_data.player_data[faction_name].psw_tf_nor_syd_rocj_tuibu_jishu + 1
                local rocj_tuib_jishu = psw_get_num(faction_name, "psw_tf_nor_syd_rocj_tuibu_jishu")
                
                effect_list = {
                    {effect = "wh_main_effect_force_stat_melee_attack", effect_scope = "faction_to_force_own", effect_num = rocj_tuib_jishu*2},
                }
                should_add_pick_zhongmo = false
                psw_add_syd_ro_wzd(faction_name, 6)
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_syd_rocj_tuib", 0, effect_list)
                
                
            -------------  人偶残件-胸部   --------------        
            
            elseif dilemma_key == "psw_tf_nor_syd_rocj_xiongbu" then
            
                
                
                psw_main_data.player_data[faction_name].psw_tf_nor_syd_rocj_xiongbu_jishu = psw_main_data.player_data[faction_name].psw_tf_nor_syd_rocj_xiongbu_jishu + 1
                local rocj_xb_jishu = psw_get_num(faction_name, "psw_tf_nor_syd_rocj_xiongbu_jishu")
                
                effect_list = {
                    {effect = "wh_main_effect_force_stat_armour", effect_scope = "faction_to_force_own", effect_num = rocj_xb_jishu*3},
                }
                should_add_pick_zhongmo = false
                psw_add_syd_ro_wzd(faction_name, 6)
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_syd_rocj_xb", 0, effect_list)
                
                
                
                
                
            -------------  人偶残件-腕部   --------------        
            
            elseif dilemma_key == "psw_tf_nor_syd_rocj_wanbu" then
            
                
                
                psw_main_data.player_data[faction_name].psw_tf_nor_syd_rocj_wanbu_jishu = psw_main_data.player_data[faction_name].psw_tf_nor_syd_rocj_wanbu_jishu + 1
                local rocj_wb_jishu = psw_get_num(faction_name, "psw_tf_nor_syd_rocj_wanbu_jishu")
                
                effect_list = {
                    {effect = "wh_main_effect_force_stat_melee_defence", effect_scope = "faction_to_force_own", effect_num = rocj_wb_jishu*2},
                }
                should_add_pick_zhongmo = false
                psw_add_syd_ro_wzd(faction_name, 6)
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_syd_rocj_wb", 0, effect_list)
                
                
                
                
                
            -------------  人偶残件-头部   --------------        
            
            elseif dilemma_key == "psw_tf_nor_syd_rocj_toubu" then
            
                
                
                psw_main_data.player_data[faction_name].psw_tf_nor_syd_rocj_toubu_jishu = psw_main_data.player_data[faction_name].psw_tf_nor_syd_rocj_toubu_jishu + 1
                local rocj_toub_jishu = psw_get_num(faction_name, "psw_tf_nor_syd_rocj_toubu_jishu")
                
                psw_add_jishu_zhixing(faction_name, 1)
                should_add_pick_zhongmo = false
                psw_add_syd_ro_wzd(faction_name, 6)
                
                
                
                
            -------------  人偶残件-发条   --------------        
            
            elseif dilemma_key == "psw_tf_nor_syd_fatiao" then
            
                
                
                psw_main_data.player_data[faction_name].psw_tf_nor_syd_fatiao_jishu = psw_main_data.player_data[faction_name].psw_tf_nor_syd_fatiao_jishu + 1
                local rocj_ft_jishu = psw_get_num(faction_name, "psw_tf_nor_syd_fatiao_jishu")
                
                effect_list = {
                    {effect = "wh_main_effect_force_stat_ward_save", effect_scope = "faction_to_force_own", effect_num = rocj_ft_jishu},
                }
                
                psw_add_syd_ro_wzd(faction_name, 12)
                should_add_pick_zhongmo = false
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_syd_rocj_ft", 0, effect_list)
                
                
                
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  阿尔法   --------------        
            
            elseif dilemma_key == "psw_tf_nor_arf" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                
                psw_add_all_sx_to_faction(faction_leader, "psw_dlc6_ayty_arf", 3, 1)
                psw_add_jishu_xingyun(faction_name, 1)
                psw_add_jishu_jingling(faction_name, 1)
                psw_add_jishu_ayty(faction_name, 1, psw_main_character)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_aplly_costom_effect_bundle_hidden("psw_tf_sp_ayty_5_unlock", faction)
                cm:remove_effect_bundle("psw_tf_sp_ayty_7_unlock", faction_name)
                should_add_pick_zhongmo = false
            -------------  贝塔   --------------        
            
            elseif dilemma_key == "psw_tf_nor_beita" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_add_jishu_meili(faction_name, 2)
                psw_add_jishu_ayty(faction_name, 1, psw_main_character)
                
                effect_list = {
                    {effect = "wh_main_effect_economy_trade_good_commodity_mod", effect_scope = "faction_to_faction_own", effect_num = 50},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_ayty_beita", 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_aplly_costom_effect_bundle_hidden("psw_tf_sp_ayty_2_unlock", faction)
                cm:remove_effect_bundle("psw_tf_sp_ayty_4_lock", faction_name)
                should_add_pick_zhongmo = false
            -------------  伽玛   --------------        
            
            elseif dilemma_key == "psw_tf_nor_gama" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_add_jishu_zhixing(faction_name, 2)
                psw_add_jishu_ayty(faction_name, 1, psw_main_character)
                
                effect_list = {
                    {effect = "wh_main_effect_character_stat_unit_health", effect_scope = "faction_to_force_own", effect_num = -10},
                    {effect = "wh_main_effect_force_stat_weapon_strength", effect_scope = "faction_to_force_own", effect_num = -15},
                    {effect = "wh_main_effect_economy_gdp_mod_all", effect_scope = "faction_to_region_own", effect_num = 25},
                    {effect = "wh_main_effect_economy_trade_tariff_mod", effect_scope = "faction_to_faction_own", effect_num = 300},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_ayty_gama", 0, effect_list)
                
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_aplly_costom_effect_bundle_hidden("psw_tf_sp_ayty_8", faction)
                cm:remove_effect_bundle("psw_tf_sp_ayty_3_lock", faction_name)
                should_add_pick_zhongmo = false
            -------------  戴尔塔   --------------        
            
            elseif dilemma_key == "psw_tf_nor_delt" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_add_jishu_ayty(faction_name, 1, psw_main_character)
                
                effect_list = {
                    {effect = "wh_main_effect_force_stat_melee_attack", effect_scope = "faction_to_force_own", effect_num = 4},
                    {effect = "wh_main_effect_force_stat_melee_defence", effect_scope = "faction_to_force_own", effect_num = 4},
                    {effect = "wh_main_effect_force_stat_weapon_strength", effect_scope = "faction_to_force_own", effect_num = 10},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_ayty_drt", 0, effect_list)
                
                
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_aplly_costom_effect_bundle_hidden("psw_tf_sp_ayty_7_lock", faction)
                cm:remove_effect_bundle("psw_tf_sp_ayty_3_unlock", faction_name)
                should_add_pick_zhongmo = false
            -------------  伊普西龙   --------------        
            
            elseif dilemma_key == "psw_tf_nor_ypxl" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                
                psw_add_jishu_moli(faction_name, 2)
                psw_add_jishu_kxct(faction_name, 3)
                psw_add_jishu_ayty(faction_name, 1, psw_main_character)
                
                effect_list = {
                    {effect = "wh3_main_effect_winds_of_magic_pool_cap", effect_scope = "faction_to_force_own", effect_num = 10},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_ayty_ypxl", 0, effect_list)
                
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_aplly_costom_effect_bundle_hidden("psw_tf_sp_ayty_2_lock", faction)
                cm:remove_effect_bundle("psw_tf_sp_ayty_6_unlock", faction_name)
                should_add_pick_zhongmo = false
            -------------  洁塔   --------------        
            
            elseif dilemma_key == "psw_tf_nor_jieta" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_add_jishu_ayty(faction_name, 1, psw_main_character)
                
                effect_list = {
                    {effect = "wh_main_effect_agent_field_line_of_sight_mod", effect_scope = "faction_to_character_own", effect_num = 25},
                    {effect = "wh_main_effect_agent_movement_range_mod", effect_scope = "faction_to_character_own_factionwide_armytext", effect_num = 12},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_ayty_jt", 0, effect_list)
                
                psw_dlc6_anty_jieta_effect(faction_name)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_aplly_costom_effect_bundle_hidden("psw_tf_sp_ayty_6_lock", faction)
                cm:remove_effect_bundle("psw_tf_sp_ayty_1_unlock", faction_name)
                should_add_pick_zhongmo = false
            -------------  希妲   --------------        
            
            elseif dilemma_key == "psw_tf_nor_xita" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_add_jishu_zhixing(faction_name, 2)
                psw_add_jishu_xingyun(faction_name, 1)
                psw_add_jishu_jingling(faction_name, 1)
                psw_add_jishu_ayty(faction_name, 1, psw_main_character)
                psw_add_gjyiwu_lcgl(faction_name, 15)
                
                psw_dlc6_ssqk_zbqh_main(faction_name)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_aplly_costom_effect_bundle_hidden("psw_tf_sp_ayty_5_lock", faction)
                cm:remove_effect_bundle("psw_tf_sp_ayty_4_unlock", faction_name)
                should_add_pick_zhongmo = false
            -------------  寻求『眼界』的初衷   --------------        
            
            elseif dilemma_key == "psw_tf_nor_yanjie" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_xuanze(faction_name, 1)
                psw_add_jishu_zhixing(faction_name, 2)
                psw_add_jishu_xingyun(faction_name, 2)
                psw_add_jishu_shenxing(faction_name, 1)
                psw_add_jishu_ewai_xingyun(faction_name, 5)
                
                if faction:has_effect_bundle("hero_select_fuxuan") then
                    cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                        {
                        "psw_tf_nor_yanjie_zt"
                        }
                    )
                    psw_add_jishu_shenxing(faction_name, 2)
                    psw_dlc6_cstf_fuxuan_zt_effect(faction_name)
                    advice_dlc6_fuxuan_zt_1()
                end
                
                effect_list = {
                    {effect = "wh_main_faction_political_diplomacy_mod", effect_scope = "faction_to_faction_own_unseen", effect_num = 15},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_ayty_ypxl", 0, effect_list)
                
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  第二人偶   --------------        
            
            elseif dilemma_key == "psw_tf_nor_jsq" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_meili(faction_name, 2)
                psw_add_qwsn_jishu(faction_name, 1)
                
                local jsq_faction_list = cm:model():world():faction_list()
                for i = 0, jsq_faction_list:num_items() - 1 do
                    local jsq_faction = jsq_faction_list:item_at(i)
                    if jsq_faction:is_human() then
                        if jsq_faction:has_effect_bundle("psw_dlc6_bundle_jsq_ally") then
                            cm:remove_effect_bundle("psw_dlc6_bundle_jsq_ally", jsq_faction:name())
                        end
                        
                        local effect_bundle_jsq = cm:create_new_custom_effect_bundle("psw_dlc6_bundle_jsq_ally")
                        effect_bundle_jsq:set_duration(0)
                        effect_bundle_jsq:add_effect("wh_main_effect_force_stat_magic_resistance", "faction_to_force_own", 8);
                        cm:apply_custom_effect_bundle_to_faction(effect_bundle_jsq, jsq_faction)
                    end
                end
                
                
                effect_list = {
                    {effect = "psw_dlc6_jsq_hxxc", effect_scope = "faction_to_character_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_jsq", 0, effect_list)
                psw_aplly_costom_effect_bundle_hidden("psw_dlc6_alice_game_qwsm_jsq", faction)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_dlc6_alice_game_linsner(faction_name, 0.1)
                psw_dlc6_qwsm_chain_effect_apply(faction_name, "psw_dlc6_bundle_jsq")
                psw_dlc6_qwsm_tf_effect_apply(faction_name, dilemma_key)
                psw_dlc6_zhenhong_juexing(faction_name)
                
            -------------  第三人偶   --------------        
            
            elseif dilemma_key == "psw_tf_nor_cuixs" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_meili(faction_name, 2)
                psw_add_jishu_zhiyu(faction_name, 2)
                psw_add_qwsn_jishu(faction_name, 1)
                
                effect_list = {
                    {effect = "psw_dlc6_cuixs_tmcr", effect_scope = "faction_to_character_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_cuixs", 0, effect_list)
                psw_aplly_costom_effect_bundle_hidden("psw_dlc6_alice_game_qwsm_cuixs", faction)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_dlc6_alice_game_linsner(faction_name, 0.1)
                psw_dlc6_qwsm_chain_effect_apply(faction_name, "psw_dlc6_bundle_cuixs")
                psw_dlc6_qwsm_tf_effect_apply(faction_name, dilemma_key)
                psw_dlc6_zhenhong_juexing(faction_name)
                
            -------------  第四人偶   --------------        
            
            elseif dilemma_key == "psw_tf_nor_cangxs" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_meili(faction_name, 2)
                psw_add_qwsn_jishu(faction_name, 1)
                
                effect_list = {
                    {effect = "psw_dlc6_cangxs_ydzj", effect_scope = "faction_to_force_own", effect_num = 1},
                    {effect = "wh_main_effect_force_stat_melee_attack", effect_scope = "faction_to_force_own", effect_num = 4},
                    {effect = "wh_main_effect_force_stat_ap_damage_mult", effect_scope = "faction_to_force_own", effect_num = 15},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_cangxs", 0, effect_list)
                psw_aplly_costom_effect_bundle_hidden("psw_dlc6_alice_game_qwsm_cangxs", faction)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_dlc6_alice_game_linsner(faction_name, 0.1)
                psw_dlc6_qwsm_chain_effect_apply(faction_name, "psw_dlc6_bundle_cangxs")
                psw_dlc6_qwsm_tf_effect_apply(faction_name, dilemma_key)
                psw_dlc6_zhenhong_juexing(faction_name)
                
            -------------  第六人偶   --------------        
            
            elseif dilemma_key == "psw_tf_nor_chumei" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_meili(faction_name, 2)
                psw_add_qwsn_jishu(faction_name, 1)
                psw_add_jishu_xingyun(faction_name, 2)
                
                psw_aplly_costom_effect_bundle_hidden("psw_dlc6_alice_game_qwsm_chumei", faction)
                psw_aplly_hidden_effect_bundle_to_character("psw_dlc6_bundle_chumei", psw_main_character)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_dlc6_alice_game_linsner(faction_name, 0.1)
                psw_dlc6_qwsm_chain_effect_apply(faction_name, "psw_dlc6_bundle_chumei")
                psw_dlc6_qwsm_tf_effect_apply(faction_name, dilemma_key)
                psw_dlc6_zhenhong_juexing(faction_name)
                
            -------------  白虎少女   --------------        
            
            elseif dilemma_key == "psw_tf_nor_bhsn" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_xilie_ldse(faction_name, 1)
                
                effect_list = {
                    {effect = "wh_main_effect_force_stat_range", effect_scope = "faction_to_force_own", effect_num = 8},
                    {effect = "psw_stat_accuracy_hidden", effect_scope = "faction_to_force_own", effect_num = 15},
                    {effect = "psw_dlc6_bhsn_fmjs", effect_scope = "faction_to_force_own", effect_num = 1},
                    {effect = "psw_dlc6_bhsn_fzjs", effect_scope = "faction_to_character_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_bhsn", 0, effect_list)
                
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_xingfa_1") then
                    cm:add_ancillary_to_faction(faction, "psw_dlc6_bhsn_shs", false)
                    cm:add_ancillary_to_faction(faction, "psw_dlc6_xingfa_hdj", false)
                    psw_add_jishu_guangmi(faction_name, 1)
                    psw_add_jishu_xilie_ldse(faction_name, 1)
                    local ran_num_bhsn = cm:random_number(100, 1)
                    if ran_num_bhsn <= 50 then
                        advice_dlc6_zqxy_2_1()
                    else
                        advice_dlc6_zqxy_1_1()
                    end
                    psw_dlc6_jbdll_zqxy_effect_apply(faction_name, psw_main_character)
                end
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  堕天圣黑猫   --------------        
            
            elseif dilemma_key == "psw_tf_nor_heimao" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_meili(faction_name, 2)
                psw_add_jishu_moli(faction_name, 2)
                psw_add_jishu_kxct(faction_name, 5)
                psw_add_jishu_heian(faction_name, 1)
                psw_add_count_moli(faction_name, 1)
                
                effect_list = {
                    {effect = "wh_main_effect_force_stat_speed", effect_scope = "faction_to_force_own", effect_num = -15},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_heimao", 0, effect_list)
                
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  金色呆萌咕   --------------        
            
            elseif dilemma_key == "psw_tf_nor_tina" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:add_ancillary_to_faction(faction, "psw_dlc6_tina_AX338", false)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_xingyun(faction_name, 1)
                
                effect_list = {
                    {effect = "psw_dlc6_tina_xfed", effect_scope = "faction_to_character_own", effect_num = 1},
                    {effect = "psw_dlc6_tina_mtyyz", effect_scope = "faction_to_force_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_tina", 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  捡到的女子高中生   --------------        
            
            elseif dilemma_key == "psw_tf_nor_shayou_1" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_meili(faction_name, 3)
                
                psw_aplly_costom_effect_bundle_hidden("psw_dlc6_bundle_shayou", faction)
                
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_main_data.player_data[faction_name].shayou_get_turn = turn
                
            -------------  空巢小老师   --------------        
            
            elseif dilemma_key == "psw_tf_nor_diya" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_moli(faction_name, 3)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_count_moli(faction_name, 1)
                
                effect_list = {
                    {effect = "psw_dlc6_diya_thdmy", effect_scope = "faction_to_character_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_diya", 0, effect_list)
                psw_aplly_costom_effect_bundle_with_time_hidden("psw_dlc6_diya_knxzl", faction, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_main_data.global_data.set_main_psw_tf_nor_diya = true
                psw_main_data.player_data[faction_name].diya_get_turn = turn
                
            -------------  厨圣   --------------        
            
            elseif dilemma_key == "psw_tf_nor_chusheng" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_gjyiwu_lcgl(faction_name, 15)
                psw_add_jishu_xingyun(faction_name, 2)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_jingling(faction_name, 1)
                
                effect_list = {
                    {effect = "psw_dlc6_chusheng_mfsd", effect_scope = "faction_to_character_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_diya", 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  富婆妹   --------------        
            
            elseif dilemma_key == "psw_tf_nor_hqfa" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_meili(faction_name, 2)
                psw_add_jishu_xingyun(faction_name, 2)
                psw_add_jishu_geji(faction_name, 1)
                
                psw_add_ex_limit_jiefang(faction_name)
                
                psw_aplly_costom_effect_bundle_hidden("psw_dlc6_bundle_hqfa", faction)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  天使的心跳   --------------        
            
            elseif dilemma_key == "psw_tf_nor_lhz" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:add_ancillary_to_faction(faction, "psw_dlc6_lhz_cbyy", false)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_guangmi(faction_name, 1)
                
                effect_list = {
                    {effect = "wh_main_effect_force_stat_speed", effect_scope = "faction_to_force_own", effect_num = 18},
                    {effect = "psw_dlc6_lhz_nqlc", effect_scope = "faction_to_force_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_lhz", 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  金色闪光   --------------        
            
            elseif dilemma_key == "psw_tf_nor_bfsm" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                common.trigger_soundevent("bfsm_get")
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_miansi(faction_name, 1)
                
                effect_list = {
                    {effect = "wh_main_effect_force_stat_speed", effect_scope = "faction_to_force_own", effect_num = 15},
                    {effect = "psw_dlc6_bfsm_sxfy", effect_scope = "faction_to_character_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_bfsm", 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  苹果糖傲娇少女   --------------        
            
            elseif dilemma_key == "psw_tf_nor_nimufu" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_meili(faction_name, 2)
                psw_add_jishu_guangmi(faction_name, 1)
                
                effect_list = {
                    {effect = "wh_main_effect_agent_field_line_of_sight_mod", effect_scope = "faction_to_character_own", effect_num = 10},
                    {effect = "psw_dlc6_nimufu_frzxt", effect_scope = "faction_to_character_own", effect_num = 1},
                    {effect = "psw_dlc6_nimufu_zcfx", effect_scope = "faction_to_character_own", effect_num = 1},
                    {effect = "psw_dlc6_nimufu_lzgrxt", effect_scope = "faction_to_character_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_nimufu", 0, effect_list)
                
                local nmf_faction_list = cm:model():world():faction_list()
                for i = 0, nmf_faction_list:num_items() - 1 do
                    local nmf_faction = nmf_faction_list:item_at(i)
                    if nmf_faction:is_human() then
                        if nmf_faction:has_effect_bundle("psw_dlc6_bundle_nimufu_ally") then
                            cm:remove_effect_bundle("psw_dlc6_bundle_nimufu_ally", nmf_faction:name())
                        end
                        
                        local effect_bundle = cm:create_new_custom_effect_bundle("psw_dlc6_bundle_nimufu_ally")
                        effect_bundle:set_duration(0)
                        effect_bundle:add_effect("wh_main_effect_agent_field_line_of_sight_mod", "faction_to_character_own", 25);
                        cm:apply_custom_effect_bundle_to_faction(effect_bundle, nmf_faction)
                    end
                end
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  石之世界的科学爱好者   --------------        
            
            elseif dilemma_key == "psw_tf_nor_ssqk" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_zhixing(faction_name, 2)
                
                effect_list = {
                    {effect = "psw_dlc6_ssqk_fhy", effect_scope = "faction_to_character_own", effect_num = 1},
                    {effect = "psw_dlc6_ssqk_shzz", effect_scope = "faction_to_character_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_ssqk", 0, effect_list)
                psw_ssqk_get_effect_apply()
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  蓝蔷薇剑士   --------------        
            
            elseif dilemma_key == "psw_tf_nor_youjiou" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:add_ancillary_to_faction(faction, "psw_dlc6_yjo_lqwzj", false)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_jianshu(faction_name, 2)
                
                effect_list = {
                    {effect = "wh_main_effect_force_stat_armour", effect_scope = "faction_to_force_own", effect_num = 10},
                    {effect = "wh_main_effect_force_stat_magic_resistance", effect_scope = "faction_to_force_own", effect_num = 10},
                    {effect = "psw_dlc6_yjo_wqqhs", effect_scope = "faction_to_character_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_yjo", 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  黑衣剑士   --------------        
            
            elseif dilemma_key == "psw_tf_nor_tghr" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:add_ancillary_to_faction(faction, "psw_dlc6_tghr_csz", false)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_jianshu(faction_name, 2)
                
                effect_list = {
                    {effect = "psw_dlc6_tghr_jjlx", effect_scope = "faction_to_force_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_tghr", 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  闪烁之光   --------------        
            
            elseif dilemma_key == "psw_tf_nor_yasina" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:add_ancillary_to_faction(faction, "psw_dlc6_ysn_sszg", false)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_jianshu(faction_name, 2)
                psw_add_jishu_zhiyu(faction_name, 2)
                
                effect_list = {
                    {effect = "wh_main_effect_force_stat_ap_damage", effect_scope = "faction_to_force_own", effect_num = 8},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_ysn", 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  圣母圣咏   --------------        
            
            elseif dilemma_key == "psw_tf_nor_juejian" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:add_ancillary_to_faction(faction, "psw_dlc6_juejian_moliu", false)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_jianshu(faction_name, 2)
                
                effect_list = {
                    {effect = "wh_main_effect_force_stat_melee_defence", effect_scope = "faction_to_force_own", effect_num = 4},
                    {effect = "psw_dlc6_juejian_smsy", effect_scope = "faction_to_character_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_juejian", 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  超电磁炮   --------------        
            
            elseif dilemma_key == "psw_tf_nor_paojie" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_meili(faction_name, 2)
                
                effect_list = {
                    {effect = "psw_dlc6_paojie_dcld", effect_scope = "faction_to_character_own", effect_num = 1},
                }
                
                if faction:has_effect_bundle("psw_main_ybdtq_fengyu") then
                    cm:remove_effect_bundle("psw_main_ybdtq_fengyu", faction_name)
                    cm:apply_effect_bundle("psw_main_ybdtq_fengyu_paojie", faction_name, 4)
                elseif faction:has_effect_bundle("psw_main_ybdtq_leibao") then
                    cm:remove_effect_bundle("psw_main_ybdtq_leibao", faction_name)
                    cm:apply_effect_bundle("psw_main_ybdtq_leibao_paojie", faction_name, 4)
                end
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_paojie", 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  奇怪的技能增加了   --------------        
            
            elseif dilemma_key == "psw_tf_nor_meipulu" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_nor_count(faction_name, 1)
                
                effect_list = {
                    {effect = "psw_dlc6_mpl_effect_myjc", effect_scope = "faction_to_force_own", effect_num = 1},
                    {effect = "psw_dlc6_mpl_effect_hjqd", effect_scope = "faction_to_force_own", effect_num = 25},
                    {effect = "psw_dlc6_mpl_effect_gdgl", effect_scope = "faction_to_force_own", effect_num = 15},
                    {effect = "psw_dlc6_mpl_effect_jzfy", effect_scope = "faction_to_force_own", effect_num = 5},
                    {effect = "psw_dlc6_mpl_effect_jcwl", effect_scope = "faction_to_force_own", effect_num = -5},
                    {effect = "psw_dlc6_mpl_effect_pjwl", effect_scope = "faction_to_force_own", effect_num = -5},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_mpl", 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  小神官   --------------        
            
            elseif dilemma_key == "psw_tf_nor_nvshenguan" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_zhiyu(faction_name, 2)
                
                effect_list = {
                    {effect = "wh_main_effect_force_stat_melee_defence", effect_scope = "faction_to_force_own", effect_num = 4},
                    {effect = "wh_main_effect_force_stat_armour", effect_scope = "faction_to_force_own", effect_num = 10},
                    {effect = "psw_dlc6_nsg_zhiyu", effect_scope = "faction_to_character_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_nsg", 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  白圣女   --------------        
            
            elseif dilemma_key == "psw_tf_nor_sxly" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_shenxing(faction_name, 1)
                psw_add_jishu_meili(faction_name, 2)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_xuanze(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_dlc6_sxly_lrdjb(faction_name)
                
            -------------  黑牧师   --------------        
            
            elseif dilemma_key == "psw_tf_nor_lls" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_zhiyu(faction_name, 2)
                psw_add_jishu_guangmi(faction_name, 2)
                
                psw_add_ex_limit_jiefang(faction_name)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_dlc6_sxly_lrdjb(faction_name)
                
            -------------  梗小姐   --------------        
            
            elseif dilemma_key == "psw_tf_nor_gengxj" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_heian(faction_name, 1)
                
                local gxj_renshu = psw_main_data.global_data.psw_main_renshu
                if gxj_renshu == 1 then
                    psw_dlc6_gxj_qdqy(faction_name, faction_name)
                end
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  红枫之园の公主   --------------        
            
            elseif dilemma_key == "psw_tf_nor_latifa" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_zhixing(faction_name, 2)
                psw_add_jishu_meili(faction_name, 2)
                psw_add_jishu_guangmi(faction_name, 1)
                
                effect_list = {
                    {effect = "wh_main_effect_character_stat_unit_health", effect_scope = "faction_to_character_own", effect_num = -10},
                    {effect = "wh_main_effect_force_stat_ward_save", effect_scope = "faction_to_force_own", effect_num = -5},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_latifa", 0, effect_list)
                psw_aplly_costom_effect_bundle_with_time_hidden("psw_dlc6_latifa_cd", faction, 0)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  穗织の巫女姬   --------------        
            
            elseif dilemma_key == "psw_tf_nor_wunvji" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_zhixing(faction_name, 2)
                psw_add_jishu_xingyun(faction_name, 2)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  Berserker   --------------        
            
            elseif dilemma_key == "psw_tf_nor_bshu" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_heian(faction_name, 1)
                psw_add_jishu_shen(faction_name, 1)
                psw_add_jishu_shenxing(faction_name, 2)
                
                effect_list = {
                    {effect = "psw_dlc6_bshu_kuanghua", effect_scope = "faction_to_force_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_bshu", 0, effect_list)
                
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_hbszx_nor") or psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_xzwlsy") then
                    local effect_list_2 = {
                        {effect = "psw_dlc6_bshu_khyz", effect_scope = "faction_to_character_own", effect_num = 1},
                    }
                    
                    psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_bshu_up", 0, effect_list_2)
                end
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  金发の妖精   --------------        
            
            elseif dilemma_key == "psw_tf_nor_gosick" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_shenxing(faction_name, 1)
                psw_add_jishu_zhixing(faction_name, 2)
                psw_add_jishu_xingyun(faction_name, 2)
                psw_add_jishu_xuanze(faction_name, 1)
                psw_add_jishu_ewai_xingyun(faction_name, 5)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  兄控中二病   --------------        
            
            elseif dilemma_key == "psw_tf_nor_xiaojiu" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_meili(faction_name, 2)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_heian(faction_name, 1)
                psw_dlc6_xiaojiu_effect_apply(faction_name)
                
            -------------  英雄王   --------------        
            
            elseif dilemma_key == "psw_tf_nor_shanshan" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_shenxing(faction_name, 1)
                psw_add_jishu_zhixing(faction_name, 2)
                psw_add_gjyiwu_lcgl(faction_name, 10)
                
                psw_main_apply_random_ancillary(faction_name)
                psw_main_apply_random_ancillary(faction_name)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  月兔の神子   --------------        
            
            elseif dilemma_key == "psw_tf_nor_heitu" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_shenxing(faction_name, 1)
                
                effect_list = {
                    {effect = "wh_main_effect_force_stat_ap_damage", effect_scope = "faction_to_force_own", effect_num = 8},
                    {effect = "wh_main_effect_force_stat_armour", effect_scope = "faction_to_force_own", effect_num = 15},
                    {effect = "wh_main_effect_force_stat_ward_save", effect_scope = "faction_to_force_own", effect_num = 5},
                    {effect = "psw_jichu_tsbh", effect_scope = "faction_to_character_own", effect_num = -5},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_heitu", 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  学园偶像   --------------        
            
            elseif dilemma_key == "psw_tf_nor_xiaoniao" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:add_ancillary_to_faction(faction, "psw_dlc6_nxn_xndyz", false)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_geji(faction_name, 2)
                psw_add_jishu_meili(faction_name, 2)
                local xn_geji_jishu = psw_get_num(faction_name, "jishu_geji")
                psw_add_jishu_zhiyu(faction_name, xn_geji_jishu)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  GJ部の元气部长   --------------        
            
            elseif dilemma_key == "psw_tf_nor_gjb" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_nor_count(faction_name, 1)
                
                effect_list = {
                    {effect = "wh3_main_effect_province_growth_faction", effect_scope = "faction_to_province_own", effect_num = 35},
                    {effect = "psw_dlc6_gjb_mjjc", effect_scope = "faction_to_character_own", effect_num = 1},
                    {effect = "psw_dlc6_gjb_jlws", effect_scope = "faction_to_force_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_gjb", 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  灭杀魔王之圣剑   --------------        
            
            elseif dilemma_key == "psw_tf_nor_aisite" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                common.trigger_soundevent("aisite_get")
                
                psw_add_nor_count(faction_name, 1)
                psw_add_psw_battle_huifu(faction_name, -10)
                psw_add_count_moli(faction_name, 1)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_jingling(faction_name, 1)
                psw_add_jishu_shenxing(faction_name, 1)
                psw_add_jishu_xingyun(faction_name, 1)
                psw_add_jishu_moli(faction_name, 2)
                psw_add_jishu_jianshu(faction_name, 2)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  禁忌人偶   --------------        
            
            elseif dilemma_key == "psw_tf_nor_yeye" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_shenxing(faction_name, 1)
                
                effect_list = {
                    {effect = "wh_main_effect_force_stat_weapon_strength", effect_scope = "faction_to_force_own", effect_num = 10},
                    {effect = "wh_main_effect_force_stat_ap_damage", effect_scope = "faction_to_force_own", effect_num = 8},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, "psw_dlc6_bundle_yeye", 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  神名文字（圣娅）   --------------        
            
            elseif dilemma_key == "psw_tf_nor_shengya" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_swyh_install_smxg_jishu(faction_name, 1)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_ssy_tf(faction_name, 1)
                psw_add_jishu_xilie_jwts(faction_name, 1)
                psw_add_jishu_xingyun(faction_name, 2)
                psw_add_jishu_meili(faction_name, 2)
                psw_add_jishu_xuanze(faction_name, 1)
                
                --未花专天
                if faction:has_effect_bundle("hero_select_nanaya") then
                    psw_play_dlc_music("mika_zt_shengya")
                    psw_dlc7_mika_zt_effect_shengya(faction_name, psw_main_character)
                end
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_dlc6_bhysy_yzm_jiance(faction_name)
                psw_dlc6_swyh_install_chh(faction_name, false)
                
            -------------  公主骑士   --------------        
            
            elseif dilemma_key == "psw_tf_nor_gzqs" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_xilie_ldse(faction_name, 1)
                psw_add_jishu_jianshu(faction_name, 2)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_dlc6_xingfa_juexing(faction_name, 0)
                
            -------------  天才美少女炼金术师   --------------        
            
            elseif dilemma_key == "psw_tf_nor_klastl" and not psw_faction_has_effect_bundle(faction_name, set) then
            
                psw_main_dismantle_tf(faction_name, dilemma_key)
                cm:add_ancillary_to_faction(faction, "psw_dlc6_klastl_wlbls", false)
                
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_miansi(faction_name, 1)
                psw_add_jishu_zhixing(faction_name, 2)
                psw_add_gjyiwu_lcgl(faction_name, 15)
                psw_main_data.player_data[faction_name].tfmw_buff["psw_dlc7_buff_klastl_byst"].num = 1
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                
            -------------  飞萤扑火   --------------        
            
            elseif dilemma_key == "psw_tf_nor_firefly" then
                psw_dlc7_firefly_get_fyph_effect(faction_name)
                should_add_pick_zhongmo = false
                
            -------------  月夜下的命运相逢   --------------        
            
            elseif dilemma_key == "psw_tf_nor_lilika" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_guangmi(faction_name, 2)
                psw_add_jishu_meili(faction_name, 2)
                psw_add_jishu_xingyun(faction_name, 2)
                psw_add_jishu_xuanze(faction_name, 1)
                psw_add_jishu_heian(faction_name, -1)
                psw_add_lilika_hgd(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  沉迷吹泡泡的助手   --------------        
            
            elseif dilemma_key == "psw_tf_nor_baihua" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_ex_limit_jiefang(faction_name)
                psw_add_jishu_ewai_xingyun(faction_name, 10)
                psw_add_jishu_xuanze(faction_name, 1)
                cm:add_ancillary_to_faction(faction, "psw_dlc7_baihua_caomao", false)
                
                effect_list = {
                    {effect = "wh_main_effect_force_stat_physical_resistance", effect_scope = "faction_to_force_own", effect_num = 12},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, effect_main_key, 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  主播女孩   --------------        
            
            elseif dilemma_key == "psw_tf_nor_tangtang" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_vtuber(faction_name, 1)
                psw_add_jishu_meili(faction_name, 2)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  超绝可爱天使酱   --------------        
            
            elseif dilemma_key == "psw_tf_nor_ctj" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_vtuber(faction_name, 1)
                psw_add_jishu_meili(faction_name, 2)
                psw_dlc7_ctj_fensi_add_initial(faction_name)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  唯一の光辉   --------------        
            
            elseif dilemma_key == "psw_tf_nor_feiyu" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_shenxing(faction_name, 1)
                psw_add_jishu_guangmi(faction_name, 2)
                psw_add_jishu_xingyun(faction_name, 2)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                psw_add_jishu_tianshi(faction_name, 2)
                
            -------------  邪恶参谋   --------------        
            
            elseif dilemma_key == "psw_tf_nor_canmou" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_heian(faction_name, 1)
                psw_add_jishu_zhixing(faction_name, 2)
                psw_add_jishu_shenxing(faction_name, 1)
                
                effect_list = {
                    {effect = "psw_dlc7_canmou_effect1", effect_scope = "faction_to_faction_own_unseen", effect_num = 15},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, effect_main_key, 0, effect_list)
                
                ---掌管不幸的魔法少女
                if psw_faction_has_effect_bundle(faction_name, "set_main_psw_tf_sp_baiye") then
                    psw_aplly_costom_effect_bundle_hidden_fn("psw_dlc7_baiye_lucky_effect_bundle", faction_name)
                    local baiye_fac_name = psw_get_any(faction_name, "baiye_fac_name")
                    psw_dlc7_baiye_xfzh_effect(baiye_fac_name)
                    psw_add_jishu_xingyun(faction_name, 2)
                    if not psw_faction_has_effect_bundle(faction_name, "psw_dlc7_baiye_bgm") then
                        common.trigger_soundevent("baiye_end_bgm")
                        psw_apply_non_effect_bundle_to_all_player("psw_dlc7_baiye_bgm")
                    end
                    
                end
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_apply_non_effect_bundle_to_all_player(set_main)
                
                psw_test_canmou_baiye_xingyun2(faction_name)
                
            -------------  不沉的幸运舰   --------------        
            
            elseif dilemma_key == "psw_tf_nor_xuefeng" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_shenhai(faction_name, 1)
                psw_add_jishu_jianniang(faction_name, 1)
                psw_add_jishu_xingyun(faction_name, 2)
                psw_dlc7_xuefeng_nor_xrzm()
                
                effect_list = {
                    {effect = "psw_dlc7_xuefeng_wgzxf", effect_scope = "faction_to_character_own", effect_num = 1},
                    {effect = "psw_dlc7_xuefeng_wgzxf_1", effect_scope = "faction_to_character_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, effect_main_key, 0, effect_list)
                
                cm:add_ancillary_to_faction(faction, "blhx_xzmf_1", false)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  神名文字（白子）   --------------        
            
            elseif dilemma_key == "psw_tf_nor_baizi" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_xilie_abds(faction_name, 1)
                psw_add_jishu_xilie_jwts(faction_name, 1)
                psw_add_jishu_fuzhai(faction_name, 1000)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  神名文字（芹香）   --------------        
            
            elseif dilemma_key == "psw_tf_nor_qinxiang" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_xilie_abds(faction_name, 1)
                psw_add_jishu_xilie_jwts(faction_name, 1)
                psw_add_jishu_fuzhai(faction_name, 1000)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  神名文字（野宫）   --------------        
            
            elseif dilemma_key == "psw_tf_nor_yegong" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_xilie_abds(faction_name, 1)
                psw_add_jishu_xilie_jwts(faction_name, 1)
                psw_add_jishu_fuzhai(faction_name, 1000)
                psw_add_round_gmsj_reward(faction_name, 1)
                psw_add_round_jyjj_reward(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  神名文字（日富美）   --------------        
            
            elseif dilemma_key == "psw_tf_nor_rifumei" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_xilie_abds(faction_name, 1)
                psw_add_jishu_xilie_jwts(faction_name, 1)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_swyh_install_smxg_jishu(faction_name, 1)
                
                local rifumei_num = psw_get_num(faction_name, "mika_ssy_tf_jishu")
                psw_add_jishu_xingyun(faction_name, rifumei_num)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                psw_add_jishu_ssy_tf(faction_name, 1)
                psw_rifumei_yingyuan_effect(faction_name)
                
            -------------  集结！蒙面泳装团！   --------------        
            
            elseif dilemma_key == "psw_tf_nor_mmyzt" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                
                psw_add_jishu_xilie_jwts(faction_name, 1)
                
                local mmyzt_num = psw_get_num(faction_name, "jishu_xilie_abds")
                psw_tfmw_main_atk_effect(mmyzt_num, faction_name, "default")
                psw_tfmw_main_def_effect(mmyzt_num, faction_name, "default")
                local mmyzt_num2 = psw_get_num(faction_name, "jishu_fuzhai_have_pay")
                psw_dlc7_mmyzt_effect(faction_name, mmyzt_num2)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_apply_non_effect_bundle_to_all_player(set_main)
                
                psw_add_jishu_xilie_abds(faction_name, 1)
                
            -------------  万花筒写轮眼   --------------        
            
            elseif dilemma_key == "psw_tf_nor_zuozhu" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                cm:add_ancillary_to_faction(faction, "psw_dlc7_zuozhu_caotijian", false)
                psw_jyjj_main_unlock(faction_name, "psw_jyjj_xd_zuozhu_jjtm", true)
                psw_jyjj_main_unlock(faction_name, "psw_jyjj_xg_zuozhu_tstz", true)
                
                
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                psw_add_jishu_heian(faction_name, 1)
                
            -------------  九尾人柱力   --------------        
            
            elseif dilemma_key == "psw_tf_nor_mingren" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_zhiyu(faction_name, 2)
                psw_jyjj_main_unlock(faction_name, "psw_jyjj_xd_mingren_lxw", true)
                psw_jyjj_main_lock(faction_name, "psw_jyjj_xg_main_heijian")
                
                effect_list = {
                    {effect = "wh_main_effect_force_army_campaign_ambush_defence_success_chance", effect_scope = "faction_to_army_own", effect_num = 20},
                    {effect = "psw_dlc7_mingren_eygz", effect_scope = "faction_to_character_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, effect_main_key, 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  杀戮の天使   --------------        
            
            elseif dilemma_key == "psw_tf_nor_ruijier" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                
                
                
                
                psw_jyjj_use_num_change(faction_name, 1, "max_level_up")
                psw_add_jishu_shenxing(faction_name, 1)
                effect_list = {
                    {effect = "wh_main_effect_force_stat_ward_save", effect_scope = "faction_to_force_own", effect_num = 5},
                    {effect = "psw_jichu_tsbh", effect_scope = "faction_to_character_own", effect_num = -5},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, effect_main_key, 0, effect_list)
                local sldts_num1 = psw_resource_value(faction, "jishu_heian")
                psw_tfmw_main_atk_effect(sldts_num1, faction_name, "default")
                psw_tfmw_main_def_effect(-sldts_num1, faction_name, "default")
                
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                psw_add_jishu_heian(faction_name, 1)
                psw_add_jishu_tianshi(faction_name, 1)
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_zak") then
                    psw_dlc7_sldts_effect(faction_name, dilemma_key)
                else
                    psw_main_dismantle_tf(faction_name, dilemma_key)
                    psw_add_nor_count(faction_name, 1)
                end
                
            -------------  杀人鬼   --------------        
            
            elseif dilemma_key == "psw_tf_nor_zak" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                
                
                
                psw_tfmw_main_atk_effect(2, faction_name, "default")
                local zak_num = psw_resource_value(faction, "jishu_heian")
                psw_tfmw_main_hp_effect(zak_num, faction_name, "levelup")
                psw_jyjj_tili_num_change(faction_name, 1, "max_level_up")
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                psw_add_jishu_heian(faction_name, 1)
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_ruijier") then
                    psw_dlc7_sldts_effect(faction_name, dilemma_key)
                else
                    psw_main_dismantle_tf(faction_name, dilemma_key)
                    psw_add_nor_count(faction_name, 1)
                end
                
            -------------  神圣的祈祷   --------------        
            
            elseif dilemma_key == "psw_tf_nor_ssdqd" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_xilie_jwts(faction_name, 1)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_ssy_tf(faction_name, 1)
                psw_add_swyh_install_smxg_jishu(faction_name, 1)
                
                effect_list = {
                    {effect = "psw_dlc7_ssdqd_sshy", effect_scope = "faction_to_character_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, effect_main_key, 0, effect_list)
                
                psw_add_jishu_zhiyu(faction_name, 2)
                psw_tfmw_main_hp_effect(2, faction_name, "levelup")
                psw_add_jishu_xuanze(faction_name, 1)
                psw_add_round_gmsj_reward(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  慈爱的飞吻   --------------     
            
            elseif dilemma_key == "psw_tf_nor_cadfw" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_xilie_jwts(faction_name, 1)
                psw_add_jishu_ssy_tf(faction_name, 1)
                psw_add_swyh_install_smxg_jishu(faction_name, 1)
                psw_add_jishu_xuanze(faction_name, 1)
                psw_add_round_gmsj_reward(faction_name, 1)
                psw_jyjj_main_unlock(faction_name, "psw_jyjj_xg_mali_chu", true)
                
                effect_list = {
                    {effect = "psw_dlc7_ssdqd_sshy", effect_scope = "faction_to_character_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, effect_main_key, 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
            
            -------------  神名文字（小春）   --------------        
            
            elseif dilemma_key == "psw_tf_nor_xiaochun" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_xilie_jwts(faction_name, 1)
                psw_add_jishu_ssy_tf(faction_name, 1)
                psw_add_swyh_install_smxg_jishu(faction_name, 1)
                psw_add_jishu_zhiyu(faction_name, 2)
                psw_jyjj_main_unlock(faction_name, "psw_jyjj_xg_xiaochun_sqzz", true)
                
                effect_list = {
                    {effect = "psw_dlc7_xiaochun_sssld", effect_scope = "faction_to_character_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, effect_main_key, 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                
            -------------  神名文字（柚子）   --------------        
            
            elseif dilemma_key == "psw_tf_nor_yozi" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_xilie_jwts(faction_name, 1)
                psw_add_jishu_xilie_qnkx(faction_name, 1)
                local yozi_num = psw_get_num(faction_name, "jishu_yxkfb")
                psw_jyjj_tili_num_change(faction_name, yozi_num, "max_level_up")
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                psw_add_jishu_yxkfb(faction_name, 1)
                
            -------------  神名文字（诺亚）   --------------        
            
            elseif dilemma_key == "psw_tf_nor_noa" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_xilie_jwts(faction_name, 1)
                psw_add_jishu_xilie_qnkx(faction_name, 1)
                psw_add_jishu_zhixing(faction_name, 2)
                psw_add_ex_limit_jiefang(faction_name)
                psw_add_round_jyjj_reward(faction_name, 1)
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_youxiang_1") then
                    psw_add_round_gmsj_reward(faction_name, 1)
                end
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  樱花坡道的呼唤   --------------        
            
            elseif dilemma_key == "psw_tf_nor_guhezhu" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                local jishu_zhu = psw_resource_value(faction, "jishu_guangmi")
                psw_jyjj_main_unlock(faction_name, "psw_jyjj_xd_zhu_guangyu", true)
                psw_add_jishu_guangyu(faction_name, jishu_zhu)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                psw_add_jishu_guangmi(faction_name, 1)
                
            -------------  海星的祝福   --------------        
            
            elseif dilemma_key == "psw_tf_nor_fuko" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_shenhai(faction_name, 1)
                psw_add_ex_limit_jiefang(faction_name)
                psw_add_jishu_xingyun(faction_name, 2)
                psw_add_jishu_xuanze(faction_name, 1)
                psw_add_turn_jyjj_reward(faction_name, 1)
                psw_jyjj_use_num_change(faction_name, 1, "max_level_up")
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  以红月为誓   --------------        
            
            elseif dilemma_key == "psw_tf_nor_delisha" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_heian(faction_name, 1)
                psw_add_jishu_xilie_sfly(faction_name, 1)
                psw_jyjj_main_unlock(faction_name, "psw_jyjj_xd_delisha_gyzy", true)
                psw_add_round_jyjj_reward(faction_name, 1)
                
                effect_list = {
                    {effect = "psw_dlc7_delisha_bjsr", effect_scope = "faction_to_force_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_faction(faction_name, effect_main_key, 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  邪王真眼   --------------        
            
            elseif dilemma_key == "psw_tf_nor_liuhua" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_count_moli(faction_name, 1)
                psw_add_jishu_moli(faction_name, 2)
                
                psw_aplly_costom_effect_bundle_hidden_fn("psw_dlc7_liuhua_jingjie_effect", faction_name)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  罕见天后   --------------        
            
            elseif dilemma_key == "psw_tf_nor_dxl" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_vtuber(faction_name, 1)
                psw_add_jishu_geji(faction_name, 1)
                psw_add_jishu_meili(faction_name, 2)
                psw_dlc7_dxl_effect(faction_name)
                
                effect_list = {
                    {effect = "wh3_dlc20_effect_xp_gain_all_units", effect_scope = "faction_to_force_own", effect_num = 25},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, effect_main_key, 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  魔术师杀手   --------------        
            
            elseif dilemma_key == "psw_tf_nor_qiesi" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_jiushizhu(faction_name, 1)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_jyjj_main_unlock(faction_name, "psw_jyjj_xg_qiesi_qyd", true)
                local jishu_qiesi = psw_get_num(faction_name, "count_moli")
                psw_tfmw_main_atk_effect(jishu_qiesi, faction_name, "default")
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  精灵魔法使   --------------        
            
            elseif dilemma_key == "psw_tf_nor_emt" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_bing(faction_name, 1)
                psw_add_jishu_jingling(faction_name, 1)
                psw_add_count_moli(faction_name, 1)
                psw_add_jishu_xingyun(faction_name, 1)
                psw_add_jishu_moli(faction_name, 2)
                psw_jyjj_main_unlock(faction_name, "psw_jyjj_xd_kokoro_jlzdy", true)
                psw_main_data.player_data[faction_name].tfmw_buff["psw_dlc7_buff_emt_swhg"].num = 1
                
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  星星之花   --------------        
            
            elseif dilemma_key == "psw_tf_nor_weilinai" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_xilie_gmz(faction_name, 1)
                psw_add_jishu_zhiyu(faction_name, 2)
                psw_jyjj_main_unlock(faction_name, "psw_jyjj_xd_weilinai_xxhzf", true)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                psw_dlc7_mc_get_gmz(faction_name, "psw_dlc7_mc_wln")
                
            -------------  星序协响   --------------        
            
            elseif dilemma_key == "psw_tf_nor_sar" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_xilie_gmz(faction_name, 1)
                psw_add_ex_limit_jiefang(faction_name)
                psw_jyjj_main_unlock(faction_name, "psw_jyjj_xg_sar_hdll", true)
                
                psw_add_jishu_shenxing(faction_name, 2)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                psw_dlc7_mc_get_gmz(faction_name, "psw_dlc7_mc_sar")
                
            -------------  红椿盛放   --------------        
            
            elseif dilemma_key == "psw_tf_nor_chun" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_heian(faction_name, 1)
                psw_add_jishu_xilie_gmz(faction_name, 1)
                psw_tfmw_main_atk_effect(2, faction_name, "default")
                psw_tfmw_main_def_effect(-3, faction_name, "default")
                psw_main_data.player_data[faction_name].mc_data.battle_get_xznl_num = 3
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                psw_dlc7_mc_get_gmz(faction_name, "psw_dlc7_mc_chun")
                
            -------------  羊咩的童话书   --------------        
            
            elseif dilemma_key == "psw_tf_nor_anke" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_xilie_gmz(faction_name, 1)
                psw_add_jishu_xingyun(faction_name, 2)
                psw_jyjj_tili_num_change(faction_name, 1, "max_level_up")
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                psw_dlc7_mc_get_gmz(faction_name, "psw_dlc7_mc_anke")
                
            -------------  海中梦   --------------        
            
            elseif dilemma_key == "psw_tf_nor_ktll" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_xilie_gmz(faction_name, 1)
                psw_add_jishu_shenhai(faction_name, 1)
                psw_jyjj_use_num_change(faction_name, 1, "max_level_up")
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                psw_dlc7_mc_get_gmz(faction_name, "psw_dlc7_mc_ktll")
                
            -------------  协乐咏叹调   --------------        
            
            elseif dilemma_key == "psw_tf_nor_zgn" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_geji(faction_name, 1)
                psw_add_jishu_meili(faction_name, 2)
                psw_add_jishu_xingyun(faction_name, 2)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  姐姐的力量   --------------        
            
            elseif dilemma_key == "psw_tf_nor_jingliu" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_xilie_ldse(faction_name, 1)
                
                effect_list = {
                    {effect = "psw_dlc7_jingliu_slzy", effect_scope = "faction_to_character_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, effect_main_key, 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  近月少女的礼仪   --------------        
            
            elseif dilemma_key == "psw_tf_nor_luna" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_zhixing(faction_name, 2)
                psw_add_turn_jyjj_reward(faction_name, 1)
                psw_add_gjyiwu_lcgl(faction_name, 15)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  土著神の顶点   --------------        
            
            elseif dilemma_key == "psw_tf_nor_zfz" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_shen(faction_name, 1)
                psw_add_jishu_xilie_hxx(faction_name, 1)
                psw_add_jishu_shenxing(faction_name, 1)
                
                effect_list = {
                    {effect = "wh_main_effect_building_construction_cost_mod_all", effect_scope = "faction_to_region_own", effect_num = -25},
                    {effect = "wh2_main_effect_building_construction_time_mod_all", effect_scope = "faction_to_region_own", effect_num = -25},
                    {effect = "psw_dlc7_zfz_tzs", effect_scope = "faction_to_character_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, effect_main_key, 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  山与湖的化身   --------------        
            
            elseif dilemma_key == "psw_tf_nor_snz" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_shen(faction_name, 1)
                psw_add_jishu_xilie_hxx(faction_name, 1)
                psw_add_jishu_shenxing(faction_name, 2)
                
                effect_list = {
                    {effect = "wh3_main_effect_province_growth_faction", effect_scope = "faction_to_province_own", effect_num = 50},
                    {effect = "psw_dlc7_mf_snz_shefu", effect_scope = "faction_to_force_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, effect_main_key, 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  庭园部の天才魔女   --------------        
            
            elseif dilemma_key == "psw_tf_nor_zhenbai" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_count_moli(faction_name, 1)
                psw_add_jishu_monv(faction_name, 1)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_xingyun(faction_name, 2)
                psw_add_jishu_moli(faction_name, 2)
                psw_add_jishu_xuanze(faction_name, 1)
                psw_add_jishu_jingling(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn("psw_dlc7_shiro_jinglingyan", faction_name)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  海之女仆   --------------        
            
            elseif dilemma_key == "psw_tf_nor_akuya" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_geji(faction_name, 1)
                
                psw_add_jishu_meili(faction_name, 2)
                psw_jyjj_tili_num_change(faction_name, -1, "min_level_down")
                psw_tfmw_main_atk_effect(2, faction_name, "default")
                
                local jishu_aky = psw_get_num(faction_name, "jishu_vtuber")
                psw_add_round_jyjj_reward(faction_name, jishu_aky)
                
                effect_list = {
                    {effect = "wh_main_effect_force_stat_vigour_loss_reduction", effect_scope = "faction_to_force_own", effect_num = 25},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, effect_main_key, 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                psw_add_jishu_vtuber(faction_name, 1)
                
            -------------  糖果王国的公主   --------------        
            
            elseif dilemma_key == "psw_tf_nor_jsluna" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                
                psw_add_jishu_geji(faction_name, 1)
                psw_add_jishu_meili(faction_name, 2)
                psw_add_jishu_xingyun(faction_name, 1)
                cm:faction_add_pooled_resource(faction_name, "psw_main_gmsj", "psw_main_gmsj_event_good", 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                psw_add_jishu_vtuber(faction_name, 1)
                
            -------------  天宫心阿喵喵   --------------        
            
            elseif dilemma_key == "psw_tf_nor_amm" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_vtuber(faction_name, 1)
                local amm_jishu = psw_get_num(faction_name, "jishu_long")
                psw_add_jishu_shenxing(faction_name, amm_jishu)
                psw_add_jishu_xingyun(faction_name, amm_jishu)
                psw_dlc7_amm_effect(faction_name)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                psw_add_jishu_long(faction_name, 1)
                
            -------------  偶像歌姬   --------------        
            
            elseif dilemma_key == "psw_tf_nor_xnm" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_geji(faction_name, 1)
                psw_add_jishu_meili(faction_name, 2)
                cm:add_ancillary_to_faction(faction, "psw_dlc7_xnm_xmq", false)
                psw_jyjj_main_unlock(faction_name, "psw_jyjj_xg_xnm_ycks", true)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  守护星芒   --------------        
            
            elseif dilemma_key == "psw_tf_nor_xinghui" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_xingyun(faction_name, 2)
                psw_jyjj_main_unlock(faction_name, "psw_jyjj_xg_xinghui_shxm", true)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  幻想杀手   --------------        
            
            elseif dilemma_key == "psw_tf_nor_hxss" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_jiushizhu(faction_name, 1)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_xingyun(faction_name, -1)
                psw_add_jishu_shenxing(faction_name, 2)
                
                effect_list = {
                    {effect = "psw_dlc7_stdm_hxss", effect_scope = "faction_to_character_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, effect_main_key, 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  不得了！   --------------        
            
            elseif dilemma_key == "psw_tf_nor_xfl" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                psw_add_jishu_long(faction_name, 1)
                
                psw_tfmw_main_hp_effect(3, faction_name, "levelup")
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  绮梦缱绻   --------------        
            
            elseif dilemma_key == "psw_tf_nor_mjyrx" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_xingyun(faction_name, 2)
                psw_add_jishu_xuanze(faction_name, 1)
                psw_moyin_mianyi_zaie_apply(faction)
                psw_moyin_mianyi_wenyi_apply(faction)
                
                effect_list = {
                    {effect = "psw_dlc7_mjyrx_almtlf", effect_scope = "faction_to_character_own", effect_num = 1},
                    {effect = "psw_boss_sxdw", effect_scope = "faction_to_force_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, effect_main_key, 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  怪异杀手   --------------        
            
            elseif dilemma_key == "psw_tf_nor_ryr" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                cm:add_ancillary_to_faction(faction, "psw_dlc7_ryr_ydxd", false)
                psw_add_jishu_zhiyu(faction_name, 2)
                psw_add_psw_battle_huifu(faction_name, 5)
                psw_add_jishu_miansi(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  理想中的闪亮新星   --------------        
            
            elseif dilemma_key == "psw_tf_nor_bkh" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_dlc7_get_bkh(faction_name, dilemma_key, set)
                
            -------------  谈梦的花之圣女   --------------        
            
            elseif dilemma_key == "psw_tf_nor_hehuan" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_dlc7_get_hehuan(faction_name, dilemma_key, set)
                
            -------------  童话之国的梦   --------------        
            
            elseif dilemma_key == "psw_tf_nor_mec" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_dlc7_get_mec(faction_name, dilemma_key, set)
                
            -------------  永垂不朽之花   --------------        
            
            elseif dilemma_key == "psw_tf_nor_xiangcao" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_dlc7_get_xiangcao(faction_name, dilemma_key, set)
                
            -------------  天使之花   --------------        
            
            elseif dilemma_key == "psw_tf_nor_tsh" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_guangmi(faction_name, 1)
                psw_main_data.global_data.chunting_all_jishu = psw_main_data.global_data.chunting_all_jishu + 1
                psw_add_chunting_exp(faction_name, 0)
                psw_add_jishu_meili(faction_name, 2)
                psw_add_jishu_zhiyu(faction_name, 2)
                
                psw_aplly_costom_effect_bundle_hidden_fn("psw_set_chunting_unlock", faction_name)
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_test_remove_xiangcao(faction_name)
                psw_dlc7_dxszl_effect(faction_name)
                
            -------------  白房の恶魔   --------------        
            
            elseif dilemma_key == "psw_tf_nor_lxlql" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_zhixing(faction_name, 2)
                psw_add_turn_jyjj_reward(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  传说的女武神   --------------        
            
            elseif dilemma_key == "psw_tf_nor_nws" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_shen(faction_name, 1)
                psw_add_jishu_shenxing(faction_name, 1)
                psw_tfmw_main_atk_effect(2, faction_name, "default")
                
                effect_list = {
                    {effect = "psw_dlc7_nws_szlj", effect_scope = "faction_to_character_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, effect_main_key, 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  永远鲜红的幼月   --------------        
            
            elseif dilemma_key == "psw_tf_nor_youyue" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_heian(faction_name, 1)
                psw_add_jishu_xilie_hxx(faction_name, 1)
                local ran_num_youyue = cm:random_number(2,0)
                local ran_num_youyue1 = cm:random_number(15,0)
                psw_add_jishu_xingyun(faction_name, ran_num_youyue)
                psw_add_gjyiwu_lcgl(faction_name, ran_num_youyue1)
                cm:add_ancillary_to_faction(faction, "psw_dlc7_lmly_ggne", false)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  完美而潇洒的从者   --------------        
            
            elseif dilemma_key == "psw_tf_nor_xiaoye" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_xilie_hxx(faction_name, 1)
                psw_add_jishu_zhixing(faction_name, 2)
                psw_jyjj_main_unlock(faction_name, "psw_jyjj_xd_xiaoye_shifu", true)
                psw_jyjj_main_lock(faction_name, "psw_jyjj_xg_main_jianpiao")
                psw_jyjj_main_get(faction_name, "psw_jyjj_xd_xiaoye_shifu")
                
                effect_list = {
                    {effect = "wh2_dlc12_effect_magic_cooldown_all_lores", effect_scope = "faction_to_character_own", effect_num = -15},
                }
                
                
                psw_main_apply_effect_to_character(psw_main_character, effect_main_key, 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  迷迭香   --------------        
            
            elseif dilemma_key == "psw_tf_nor_mdx" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_xilie_ldd(faction_name, 1)
                psw_add_jishu_kxct(faction_name, 5)
                
                effect_list = {
                    {effect = "wh_main_effect_force_stat_reload_time_reduction", effect_scope = "faction_to_force_own", effect_num = 15},
                    {effect = "wh_main_effect_force_stat_missile_damage", effect_scope = "faction_to_force_own", effect_num = 8},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, effect_main_key, 0, effect_list)
                psw_dlc7_mdx_gzwd_effect()
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  玛纳利亚王女   --------------        
            
            elseif dilemma_key == "psw_tf_nor_anne" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_moli(faction_name, 2)
                psw_jyjj_main_unlock(faction_name, "psw_jyjj_xg_anne_gyzmd", true)
                psw_jyjj_main_unlock(faction_name, "psw_jyjj_xg_anne_zybj", true)
                psw_add_count_moli(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_aplly_costom_effect_bundle_hidden_fn("psw_dlc7_yzs_jhxt", faction_name)
                
            -------------  自然妖精公主   --------------        
            
            elseif dilemma_key == "psw_tf_nor_aly" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                
                psw_add_jishu_guangmi(faction_name, 1)
                psw_jyjj_main_unlock(faction_name, "psw_jyjj_xg_aly_yjyh", false)
                local aly_jishu = psw_get_num(faction_name, "jishu_jingling")
                psw_add_jishu_xingyun(faction_name, aly_jishu)
                psw_jyjj_use_num_change(faction_name, 1, "max_level_up")
                psw_add_ex_limit_jiefang(faction_name)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                psw_aplly_costom_effect_bundle_hidden_fn("psw_dlc7_yzs_jhxt", faction_name)
                
                psw_add_jishu_jingling(faction_name, 1)
                
            -------------  变貌大妃   --------------        
            
            elseif dilemma_key == "psw_tf_nor_nnk" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_jingling(faction_name, 1)
                psw_add_jishu_shenxing(faction_name, 2)
                psw_add_jishu_xingyun(faction_name, 2)
                psw_jyjj_use_num_change(faction_name, 1, "max_level_up")
                psw_add_jishu_xilie_ldse(faction_name, 1)
                common.trigger_soundevent("nnk_get")
                advice_dlc7_nnk_1()
                effect_list = {
                    {effect = "psw_dlc7_nnk_zszy", effect_scope = "faction_to_character_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, effect_main_key, 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  诡戏千役   --------------        
            
            elseif dilemma_key == "psw_tf_nor_huahuo" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_jyjj_use_num_change(faction_name, 1, "max_level_up")
                psw_add_turn_jyjj_reward(faction_name, 1)
                
                effect_list = {
                    {effect = "psw_dlc7_huahuo_djx", effect_scope = "faction_to_force_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, effect_main_key, 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  炎发灼眼的讨伐者   --------------        
            
            elseif dilemma_key == "psw_tf_nor_xiana" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_shenxing(faction_name, 1)
                cm:add_ancillary_to_faction(faction, "psw_dlc7_xiana_zdzn", false)
                
                effect_list = {
                    {effect = "psw_dlc7_xiana_hyzy", effect_scope = "faction_to_force_own", effect_num = 1},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, effect_main_key, 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  无光之影   --------------        
            
            elseif dilemma_key == "psw_tf_nor_abak" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_jingling(faction_name, 1)
                psw_add_jishu_heian(faction_name, 1)
                psw_add_jishu_shenxing(faction_name, 1)
                psw_add_jishu_xingyun(faction_name, 2)
                psw_add_jishu_zhongmo(1)
                psw_main_mowang_progress_change_effect(1)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                local jishu_abak = psw_resource_value(faction, "jishu_guangmi")
                psw_dlc7_wgzy_effect(faction_name, jishu_abak)
                
            -------------  女神的神核   --------------        
            
            elseif dilemma_key == "psw_tf_nor_zdn" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_bing(faction_name, 1)
                
                psw_jyjj_use_num_change(faction_name, 1, "max_level_up")
                psw_add_turn_jyjj_reward(faction_name, 1)
                psw_add_jishu_xingyun(faction_name, 2)
                local jishu_zdn = psw_get_num(faction_name, "jishu_shen")
                jishu_zdn = jishu_zdn + 1
                psw_add_jishu_shenxing(faction_name, jishu_zdn)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                psw_add_jishu_shen(faction_name, 1)
                
            -------------  直死之魔眼   --------------        
            
            elseif dilemma_key == "psw_tf_nor_zszmy" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_heian(faction_name, 1)
                psw_tfmw_main_atk_effect(2, faction_name, "default")
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  噩梦具象化   --------------        
            
            elseif dilemma_key == "psw_tf_nor_emjxh" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_heian(faction_name, 1)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  怪力魔女   --------------        
            
            elseif dilemma_key == "psw_tf_nor_glmn" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                if faction:has_effect_bundle("hero_select_shiki") then
                    psw_dlc7_xueli_zt_effect(faction_name, psw_main_character)
                end
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                psw_add_jishu_monv(faction_name, 1)
                
            -------------  纯洁之冠   --------------        
            
            elseif dilemma_key == "psw_tf_nor_cjzg" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_jishu_zhixing(faction_name, 2)
                psw_add_jishu_meili(faction_name, 2)
                psw_add_jishu_guangmi(faction_name, 2)
                cm:add_ancillary_to_faction(faction, "psw_dlc7_feibi_yhsd", false)
                
                
                if faction:has_effect_bundle("hero_select_yly") then
                    advice_feibi_zt_1()
                    psw_dlc7_feibi_zt_effect(faction_name, psw_main_character)
                end
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  献给少女们的垂怜经   --------------        
            
            elseif dilemma_key == "psw_tf_nor_clj" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                if faction:has_effect_bundle("hero_select_nanaya") then
                    advice_mika_zt_clj_1()
                    psw_dlc7_mika_zt_effect_clj(faction_name, psw_main_character)
                end
                
                psw_add_swyh_install_smxg_jishu(faction_name, 1)
                psw_add_jishu_guangmi(faction_name, 1)
                psw_add_jishu_ssy_tf(faction_name, 1)
                psw_add_jishu_xilie_jwts(faction_name, 1)
                psw_add_jishu_meili(faction_name, 2)
                psw_add_jishu_xingyun(faction_name, 1)
                
                effect_list = {
                    {effect = "wh_main_effect_force_stat_range", effect_scope = "faction_to_force_own", effect_num = 5},
                    {effect = "wh_main_effect_force_stat_missile_damage", effect_scope = "faction_to_force_own", effect_num = 10},
                    {effect = "wh_main_effect_unit_recruitment_points", effect_scope = "faction_to_province_own_factionwide", effect_num = 1},
                    {effect = "wh_main_effect_force_stat_ward_save", effect_scope = "faction_to_force_own", effect_num = 5},
                }
                
                psw_main_apply_effect_to_character(psw_main_character, effect_main_key, 0, effect_list)
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
            -------------  深渊书库的管理者   --------------        
            
            elseif dilemma_key == "psw_tf_nor_lbe" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                
                psw_add_count_moli(faction_name, 1)
                psw_add_jishu_moli(faction_name, 2)
                psw_add_jishu_zhixing(faction_name, 2)
                
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                psw_add_jishu_heian(faction_name, 1)
                psw_add_jishu_long(faction_name, 1)
                
            -------------  银冰龙女   --------------        
            
            elseif dilemma_key == "psw_tf_nor_feilin" and not psw_faction_has_effect_bundle(faction_name, set) then
                
                psw_main_dismantle_tf(faction_name, dilemma_key)
                psw_add_nor_count(faction_name, 1)
                psw_play_dlc_music("feilin_1")
                
                psw_jyjj_main_unlock(faction_name, "psw_jyjj_xg_feilin_tuxi", true)
                
                
                psw_aplly_costom_effect_bundle_hidden_fn(set, faction_name)
                
                psw_add_jishu_long(faction_name, 1)
                psw_add_jishu_bing(faction_name, 1)
            
                
    ------------------ 最后 天赋获取失败 --------------------      
                
                
            elseif 1 == 1 then
                
                advice_alice_tf_yyytf()
                local region_name = psw_get_any(faction_name, "region_name")
                local tf_region = cm:get_region(region_name)
                local slot_n_list = tf_region:foreign_slot_manager_for_faction(faction_name):slots()
                local slot_1 = slot_n_list:item_at(0)
                local slot_2 = slot_n_list:item_at(1)
                local slot_3 = slot_n_list:item_at(2)
                cm:foreign_slot_instantly_dismantle_building(slot_1)
                cm:foreign_slot_instantly_dismantle_building(slot_2)
                cm:foreign_slot_instantly_dismantle_building(slot_3)
                should_add_pick_zhongmo = false
    ------------------end--------------------
            end;
            
            
            
            ---是正常抽卡
            if should_add_pick_zhongmo then
                ---白花 再度的相逢
                if (dilemma_key:starts_with("psw_tf_ex_") or dilemma_key:starts_with("psw_tf_sp_")) and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_baihua") and not psw_faction_has_effect_bundle(faction_name, "psw_dlc7_baihua_zddxf") then
                    psw_add_jishu_xuanze(faction_name, -1)
                    psw_add_jishu_ewai_xingyun(faction_name, -10)
                    psw_aplly_costom_effect_bundle_hidden("psw_dlc7_baihua_zddxf", faction)
                end
                ---莉莉卡
                if faction:has_effect_bundle("set_psw_tf_ex_lilika_2") then
                    psw_add_lilika_ab(faction_name, 1)
                end
                
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_baihua") and not psw_faction_has_effect_bundle(faction_name, "psw_dlc7_baihua_songgui") then
                    psw_add_jishu_bhdll(faction_name, 8)
                end
                
                psw_add_zhongmo_by_pick(1)
                if faction:has_effect_bundle("set_psw_tf_ex_ams_1") then
                    psw_dlc7_ams_mission_effect(faction_name, "psw_dlc7_ams_mulu_mission_tf")
                end
            end
            
        end
    end),
    true
)