

function psw_main_set_bianliang(faction_name)
    if 1 == 1 then
        local faction = cm:get_faction(faction_name)
        ----- 基础变量 -----
        local psw_shenxing =  faction:pooled_resource_manager():resource("psw_shenxing"):value()

        local psw_moli =  faction:pooled_resource_manager():resource("psw_moli"):value()

        local psw_xingyun =  faction:pooled_resource_manager():resource("psw_xingyun"):value()

        ----- 各种计数 -----
        local jishu_mofashaonv =  faction:pooled_resource_manager():resource("jishu_mofashaonv"):value()

        local jishu_guangmi =  faction:pooled_resource_manager():resource("jishu_guangmi"):value()

        local jishu_heian =  faction:pooled_resource_manager():resource("jishu_heian"):value()

        local jishu_alxy_lvzhe =  faction:pooled_resource_manager():resource("jishu_alxy_lvzhe"):value()


    end
end

-------------  人物10级长生久视  --------------
function psw_lv10_csjs()
    core:remove_listener("psw_lv10_csjs")
    core:add_listener(
    "psw_lv10_csjs",
    "CharacterRankUp",
    function(context)
        local character = context:character();
        local rank = character:rank()
        if rank >= 10 and not character:has_effect_bundle("psw_bundle_main_csjs") and psw_main_data.global_data.set_psw_main_nandu4 then
            return true
        end
    end,
    function(context)
        local character = context:character()
        local effect_bundle = cm:create_new_custom_effect_bundle("psw_bundle_main_csjs")
        effect_bundle:set_duration(0)
        effect_bundle:add_effect("wh2_main_effect_grant_immortality_lord", "character_to_character_own", 1)
        cm:apply_custom_effect_bundle_to_character(effect_bundle, character)
    end,
    true
    )
end

-------------  闪避技能删除  --------------
function psw_main_shanbi_delete(psw_main_character)
    cm:remove_effect_bundle_from_character("jnz_main_shanbi", psw_main_character);
    cm:remove_effect_bundle_from_character("jnz_kqrn_dyz1", psw_main_character);
    cm:remove_effect_bundle_from_character("jnz_jn_shanbi_sywh_ssz", psw_main_character);
    cm:remove_effect_bundle_from_character("jnz_jn_shanbi_sywh_sj", psw_main_character);
    cm:remove_effect_bundle_from_character("jnz_jn_shanbi_alxy_rmcx", psw_main_character);
    cm:remove_effect_bundle_from_character("jnz_jn_shanbi_alxy_wxys", psw_main_character);
    cm:remove_effect_bundle_from_character("psw_dlc6_shanbi_yhzl_2", psw_main_character);
    cm:remove_effect_bundle_from_character("psw_dlc6_shanbi_yhzl_3", psw_main_character);
    cm:remove_effect_bundle_from_character("jnz_jn_shanbi_yls_qg", psw_main_character);
    cm:remove_effect_bundle_from_character("jnz_jn_shanbi_skd_yl", psw_main_character);
    cm:remove_effect_bundle_from_character("jnz_jn_shanbi_skd_ycbg", psw_main_character);
    cm:remove_effect_bundle_from_character("jnz_jn_shanbi_kqrn_dyz", psw_main_character);
    cm:remove_effect_bundle_from_character("jnz_jn_shanbi_swwh_ssz", psw_main_character);
    cm:remove_effect_bundle_from_character("jnz_jn_shanbi_swwh_sj", psw_main_character);
    cm:remove_effect_bundle_from_character("jnz_jn_shanbi_amly_bjzb", psw_main_character);
    cm:remove_effect_bundle_from_character("jnz_jn_shanbi_bingli_bhfc", psw_main_character);
    cm:remove_effect_bundle_from_character("jn_shanbi_ybbb_wydjy", psw_main_character);
    cm:remove_effect_bundle_from_character("jn_shanbi_azsyz_fxfy", psw_main_character);
    cm:remove_effect_bundle_from_character("jn_shanbi_ejtzh_sjgx", psw_main_character);
    cm:remove_effect_bundle_from_character("jn_shanbi_zzhgt_kjzy", psw_main_character);
    cm:remove_effect_bundle_from_character("jn_shanbi_rwyyr_shun2", psw_main_character);
    cm:remove_effect_bundle_from_character("jn_shanbi_rwyyr_shun1", psw_main_character);
    cm:remove_effect_bundle_from_character("jn_shanbi_yqdjb_csg", psw_main_character);
    cm:remove_effect_bundle_from_character("shanbi_alice_sjdfz", psw_main_character);
    cm:remove_effect_bundle_from_character("shanbi_youxiang_ljylx", psw_main_character);
    cm:remove_effect_bundle_from_character("shanbi_fia_fydsh", psw_main_character);
    cm:remove_effect_bundle_from_character("shanbi_djs_cbdsy", psw_main_character);
    
    cm:remove_effect_bundle_from_character("psw_moyin_ex_hsl_shanbi_sxhy", psw_main_character);
    cm:remove_effect_bundle_from_character("psw_dlc6_shanbi_syd_nzly", psw_main_character);
    cm:remove_effect_bundle_from_character("psw_dlc6_shanbi_fuxuan_bie", psw_main_character);
    cm:remove_effect_bundle_from_character("psw_dlc6_shanbi_qiyana_yjyq", psw_main_character);
    cm:remove_effect_bundle_from_character("psw_dlc6_shanbi_yln_mlld", psw_main_character);
    cm:remove_effect_bundle_from_character("psw_dlc6_shanbi_wydygn_lzzl", psw_main_character);
    cm:remove_effect_bundle_from_character("psw_dlc7_feilin_shanbi_yhdt", psw_main_character);
    cm:remove_effect_bundle_from_character("psw_dlc7_shanbi_zaomiao_szf", psw_main_character);
end




------ 律者能量 --------
function alxy_lznl_hh()
	core:add_listener(
	"alxy_lznl_hh",
	"FactionTurnStart",
    function(context)
        local faction_name = context:faction():name()
        local faction = cm:get_faction(faction_name)
        if context:faction():is_human() == true and faction:has_effect_bundle("set_psw_tf_ex_alxy_1") then
            return true
        end
    end,
	function(context)
        local faction_name = context:faction():name()
        local faction = cm:get_faction(faction_name)
        local lznl = faction:pooled_resource_manager():resource("jishu_alxy_lvzhe"):value()
        psw_add_jishu_alxy_lvzhe(faction_name, 1)
	end,
	true
	)
end


------ 鹿目圆香 魔法少女 轮回计数增长 --------
function lmyx_mfsn_lhjs_hh()
    core:remove_listener("lmyx_mfsn_lhjs_hh")
	core:add_listener(
	"lmyx_mfsn_lhjs_hh",
	"FactionTurnStart",
    function(context)
        local faction_name = context:faction():name()
        local faction = cm:get_faction(faction_name)
        if context:faction():is_human() == true and faction:has_effect_bundle("hero_select_lmyx") then
            return true
        end
    end,
	function(context)
        
        local faction_name = context:faction():name()
        local faction = cm:get_faction(faction_name)
        
        if faction:has_effect_bundle("set_psw_tf_nor_xmy_zt") then
            psw_main_data.player_data[faction_name].jishu_lmyx_lunhui = psw_main_data.player_data[faction_name].jishu_lmyx_lunhui + 2
        elseif not faction:has_effect_bundle("set_psw_tf_nor_xmy_zt") then
            psw_main_data.player_data[faction_name].jishu_lmyx_lunhui = psw_main_data.player_data[faction_name].jishu_lmyx_lunhui + 1
        end

	end,
	true
	)
end

----鹿目圆香 初始天赋 污染度计数增长----

function psw_lmyx_tfjh_jjdmn()
    core:remove_listener("psw_lmyx_tfjh_jjdmn")
	core:add_listener(
	"psw_lmyx_tfjh_jjdmn",
	"BattleCompleted",
    function(context)
        
        local faction_name = cm:pending_battle_cache_get_attacker_faction_name(1)
        local faction = cm:get_faction(faction_name)
        return cm:pending_battle_cache_human_is_involved() and faction:has_effect_bundle("hero_select_lmyx")
    end,
	function(context)
        
        
        local faction_name = cm:pending_battle_cache_get_attacker_faction_name(1)
        local attacker_cqi, attacker_force_cqi, attacker_name = cm:pending_battle_cache_get_attacker(1)
        local defender_cqi, defender_force_cqi, defender_name = cm:pending_battle_cache_get_defender(1);
        local attacker = cm:get_faction(attacker_name)

        
        local bmm_attacker_result = cm:model():pending_battle():attacker_battle_result();
		local bmm_defender_result = cm:model():pending_battle():defender_battle_result();
		
		if bmm_attacker_result == "close_defeat" and bmm_defender_result == "close_defeat" then
			-- They've both had a close defeat, must have been a retreat not a battle!
			return;
		elseif bmm_attacker_result == nil or bmm_defender_result == nil then
			return;
		end
		
        
		psw_main_data.player_data[faction_name].jishu_lmyx_wurandu = psw_main_data.player_data[faction_name].jishu_lmyx_wurandu + 4
            
		
		
	end,
	true
	)
end


------ 姬宫真布-童话王国效果结束 ------
function psw_zhenbu_thwg_end()
    core:remove_listener("psw_zhenbu_thwg_end")
    core:add_listener(
    "psw_zhenbu_thwg_end",
    "FactionTurnStart",
    function(context)
        local faction = context:faction()
        local faction_name = faction:name()
        local turn = cm:turn_number()
        local duration = (psw_main_data.player_data[faction_name] or {}).thwg_duration or 0
        local thwg_turn = (psw_main_data.player_data[faction_name] or {}).thwg_turn or -8
       local end_turn = thwg_turn + duration
if context:faction():is_human() == true and psw_faction_has_effect_bundle(faction_name, "zhenbu_thwg_buff") and end_turn <= turn then
return true
        end
    end,
    function(context)
        local faction = context:faction()
        local faction_name = faction:name()
        local thwg_zhiyu_add = psw_main_data.player_data[faction_name].thwg_zhiyu_add
        
        local zb_fac_list = cm:model():world():faction_list();
        for i = 0, zb_fac_list:num_items() - 1 do
            local crt_zhenbu_faction = zb_fac_list:item_at(i);
            local crt_zhenbu_faction_name = crt_zhenbu_faction:name();
            if crt_zhenbu_faction:is_human() == true then
                psw_add_jishu_zhiyu(crt_zhenbu_faction_name, -thwg_zhiyu_add)
            end
        end
        cm:remove_effect_bundle("zhenbu_thwg_buff", faction_name)
    end,
    true
    )
end

------ 虹 爱莉希雅  赤字回合数判断 --------

function alxy_chizi_huihe()
    core:remove_listener("alxy_chizi_huihe")
	core:add_listener(
	"alxy_chizi_huihe",
	"FactionTurnStart",
    function(context)
        
        local faction_name = context:faction():name()
        local faction = context:faction()
        if context:faction():is_human() == true and faction:has_effect_bundle("set_psw_tf_ex_alxy_2") then
            return true
        end
    end,
	function(context)
        local faction = context:faction()
        local faction_name = context:faction():name()
        local treasury = context:faction():treasury()
        
        local yx_subtype = psw_main_data.player_data[faction_name].yx_subtype
        local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
        
        
        
        
        if treasury == 0 then
            psw_main_data.player_data[faction_name].jishu_huihe_chizi = psw_main_data.player_data[faction_name].jishu_huihe_chizi + 1
        elseif treasury > 0 then
            psw_main_data.player_data[faction_name].jishu_huihe_chizi = 0
        end
        local jishu_huihe_chizi = psw_main_data.player_data[faction_name].jishu_huihe_chizi

        if jishu_huihe_chizi >= 3 and not faction:has_effect_bundle("set_psw_tf_ex_alxy_3") then
            local random_number_face = cm:random_number(100, 1)
            
            
            local main_xingyunzhi = 50
            cm:callback(function()
                if random_number_face > main_xingyunzhi then
                    common.trigger_soundevent("alxy_3_2")
                    advice_psw_tf_ex_alxy_3_2_1()
                elseif random_number_face <= main_xingyunzhi then
                    common.trigger_soundevent("alxy_3_1")
                    advice_psw_tf_ex_alxy_3_1_1()
                end
            end, 3)
            

            psw_delete_shanbi_effect(faction_name, "jn_shanbi_alxy_wxys")
            cm:remove_effect_bundle_from_character("jnz_tf_ex_rzlz", psw_main_character);
            cm:apply_effect_bundle_to_character("jnz_tf_ex_alxy", psw_main_character, 0)
            
            psw_add_jishu_zhongmo(5)
            psw_add_jishu_shenxing(faction_name, 1)
            
            cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                {
                "psw_tf_ex_alxy_3"
                }
                )
            psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_alxy_3", faction_name)
            psw_add_jishu_miansi(faction_name, 3)
            
            psw_add_hong_count(faction_name, 1)
            
            psw_aplly_costom_effect_bundle_hidden_fn("set_faction_hace_hong_ex", faction_name)
        end
		
	end,
	true
	)
end



------------ 空崎日奈好感度增加/觉醒 -------------
function kqrn_hgd_zj()
    core:remove_listener("kqrn_hgd_zj")
    core:add_listener(
    "kqrn_hgd_zj",
    "CharacterRankUp",
    function(context)
        local character = context:character();
        local faction = character:faction()
        local faction_name = faction:name()
        if faction:is_human() == true and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_kqrn_1") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_kqrn_2") then
            return true
        end
    end,
    function(context)
        local character = context:character();
        local faction = character:faction()
        local faction_name = faction:name()

        local yx_subtype = psw_main_data.player_data[faction_name].yx_subtype
        local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
        local add_num = 2
        if faction:has_effect_bundle("psw_tf_ex_jwts_1") then
            add_num = 4
        end
        
        psw_main_data.player_data[faction_name].kqrn_hgd = psw_main_data.player_data[faction_name].kqrn_hgd + add_num
        
        local char_not_exist = not psw_main_character or psw_main_character:is_null_interface() or psw_main_character:is_wounded() or psw_main_character:is_at_sea() or not cm:char_is_general_with_army(psw_main_character)
        
        if psw_main_data.player_data[faction_name].kqrn_hgd >= 100 and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_kqrn_2") and not char_not_exist and not ex_char_not_exist then
            
            common.trigger_soundevent("kqrn_2")
            advice_psw_tf_ex_kqrn_2_1()
            
            
            cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                {
                "psw_tf_ex_kqrn_2"
                }
            )
            psw_add_jishu_shenxing(faction_name, 2)
            cm:remove_effect_bundle_from_character("jnz_tf_ex_psw_tf_ex_kqrn_1", psw_main_character);
            cm:apply_effect_bundle_to_character("jnz_tf_ex_psw_tf_ex_kqrn_2", psw_main_character, 0)
            
            psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_kqrn_2", faction_name)
        end
    end,
    true
    )
end



------------ 优香好感度增加/觉醒 -------------
function youxiang_hgd_zj()
    core:remove_listener("youxiang_hgd_zj")
    core:add_listener(
    "youxiang_hgd_zj",
    "CharacterRankUp",
    function(context)
        local character = context:character();
        local faction = character:faction()
        local faction_name = faction:name()
        if faction:is_human() == true and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_youxiang_1") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_youxiang_2") then
            return true
        end
    end,
    function(context)
        local character = context:character();
        local faction = character:faction()
        local faction_name = faction:name()

        local yx_subtype = psw_main_data.player_data[faction_name].yx_subtype
        local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
        local add_num = 2
        if faction:has_effect_bundle("psw_tf_ex_jwts_1") then
            add_num = 4
        end

        psw_main_data.player_data[faction_name].youxiang_hgd = psw_main_data.player_data[faction_name].youxiang_hgd + add_num
        
        local char_not_exist = psw_main_character:is_null_interface() or psw_main_character:is_wounded() or psw_main_character:is_at_sea() or not cm:char_is_general_with_army(psw_main_character)
        
        if psw_main_data.player_data[faction_name].youxiang_hgd >= 100 and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_youxiang_2") and not char_not_exist then
            advice_youxiang_2_1()
            
            cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                {
                "psw_tf_ex_youxiang_2"
                }
            )
            
            psw_add_jishu_miansi(faction_name, 1)
            
            psw_add_jishu_zhixing(faction_name, 2)
            cm:add_ancillary_to_faction(faction, "youxiang_dzjsq", false)
            cm:remove_effect_bundle_from_character("jnz_tf_ex_youxiang_1", psw_main_character);
            cm:apply_effect_bundle_to_character("jnz_tf_ex_youxiang_2", psw_main_character, 0)
            
            psw_delete_shanbi_effect(faction_name, "shanbi_youxiang_ljylx")
            psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_youxiang_2", faction_name)
        end
    end,
    true
    )
end


local yls_jichu_get = 2

------ 幽灵鲨/斯卡蒂 同化度-回合相关 --------

function yls_skd_thd_hh()
    core:remove_listener("yls_skd_thd_hh")
	core:add_listener(
	"yls_skd_thd_hh",
	"FactionTurnStart",
    function(context)
        local faction_name = context:faction():name()
        local yls_thd = (psw_main_data.player_data[faction_name] or {}).yls_thd or 0
        local skd_thd = (psw_main_data.player_data[faction_name] or {}).skd_thd or 0
  local faction = cm:get_faction(faction_name)
if context:faction():is_human() == true and ((faction:has_effect_bundle("set_psw_tf_ex_yls_1") and yls_thd <= 60) or (faction:has_effect_bundle("set_psw_tf_ex_skd_1"))) then
return true
        end
    end,
	function(context)
        
        local faction_name = context:faction():name()
        
        
        local jishu_shenhai = psw_main_data.player_data[faction_name].jishu_shenhai
        local faction = context:faction()
        local faction_leader = faction:faction_leader()
        local yx_subtype = psw_main_data.player_data[faction_name].yx_subtype
        local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
        
        if faction:has_effect_bundle("set_psw_tf_ex_yls_1") and faction:has_effect_bundle("set_psw_tf_ex_skd_1") then
            if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yrhtdsj_nor") then
                psw_main_data.player_data[faction_name].yls_thd = psw_main_data.player_data[faction_name].yls_thd + (yls_jichu_get*4)
                psw_main_data.player_data[faction_name].skd_thd = psw_main_data.player_data[faction_name].skd_thd + (yls_jichu_get*4)
            elseif not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yrhtdsj_nor") then
                psw_main_data.player_data[faction_name].yls_thd = psw_main_data.player_data[faction_name].yls_thd + (yls_jichu_get*2)
                psw_main_data.player_data[faction_name].skd_thd = psw_main_data.player_data[faction_name].skd_thd + (yls_jichu_get*2)
            end
            
        elseif faction:has_effect_bundle("set_psw_tf_ex_yls_1") then
            if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yrhtdsj_nor") then
                psw_main_data.player_data[faction_name].yls_thd = psw_main_data.player_data[faction_name].yls_thd + (yls_jichu_get*2)
            elseif not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yrhtdsj_nor") then
                psw_main_data.player_data[faction_name].yls_thd = psw_main_data.player_data[faction_name].yls_thd + yls_jichu_get
            end
        elseif faction:has_effect_bundle("set_psw_tf_ex_skd_1") then
            if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yrhtdsj_nor") then
                psw_main_data.player_data[faction_name].skd_thd = psw_main_data.player_data[faction_name].skd_thd + (yls_jichu_get*2)
            elseif not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yrhtdsj_nor") then
                psw_main_data.player_data[faction_name].skd_thd = psw_main_data.player_data[faction_name].skd_thd + yls_jichu_get
            end
        end
        local yls_thd = psw_main_data.player_data[faction_name].yls_thd
        local skd_thd = psw_main_data.player_data[faction_name].skd_thd
        
        local char_not_exist = psw_main_character:is_null_interface() or psw_main_character:is_wounded() or psw_main_character:is_at_sea() or not cm:char_is_general_with_army(psw_main_character)
        
        ---- 幽灵鲨觉醒
        
        if yls_thd >= 50 and not faction:has_effect_bundle("set_psw_tf_ex_yls_2") and not char_not_exist then
        
            cm:callback(function()
                common.trigger_soundevent("yls_2")
                advice_psw_tf_ex_yls_2()
            end, 5)
            
            cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                {
                "psw_tf_ex_yls_2"
                }
            )
            
            psw_delete_shanbi_effect(faction_name, "jn_shanbi_yls_qg")
            cm:remove_effect_bundle_from_character("jnz_tf_ex_psw_tf_ex_yls_1", psw_main_character);
            cm:apply_effect_bundle_to_character("jnz_tf_ex_psw_tf_ex_yls_2", psw_main_character, 0)
            
            psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_yls_2", faction_name)
            
        ---- 斯卡蒂觉醒
        
		elseif skd_thd >= 50 and not faction:has_effect_bundle("set_psw_tf_ex_skd_2") and not char_not_exist then
		
            cm:callback(function()
                common.trigger_soundevent("skd_2")
                advice_psw_tf_ex_skd_2_1()
            end, 5)
            
            cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                {
                "psw_tf_ex_skd_2"
                }
            )
            
            psw_add_jishu_miansi(faction_name, 1)
            
            
            psw_add_jishu_xingyun(faction_name, 3)
            
            psw_delete_shanbi_effect(faction_name, "jn_shanbi_skd_yl")
            cm:remove_effect_bundle_from_character("jnz_tf_ex_psw_tf_ex_skd_1", psw_main_character);
            cm:apply_effect_bundle_to_character("jnz_tf_ex_psw_tf_ex_skd_2", psw_main_character, 0)
            
            psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_skd_2", faction_name)
        
        ---- 虹斯卡蒂
        elseif skd_thd >= 100 and faction:has_effect_bundle("set_psw_tf_ex_skd_2") and jishu_shenhai >= 5 and not faction:has_effect_bundle("set_psw_tf_ex_skd_3") and not char_not_exist then
        
            cm:callback(function()
                common.trigger_soundevent("skd_3")
                advice_psw_tf_ex_skd_3_1()
            end, 5)
            
            psw_add_hong_count(faction_name, 1)
            
            cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                {
                "psw_tf_ex_skd_3"
                }
            )
            
            local psw_faction_list = cm:model():world():faction_list();
            
            for i = 0, psw_faction_list:num_items() - 1 do
                local current_faction = psw_faction_list:item_at(i);
                local current_faction_name = current_faction:name()
                if current_faction:is_human() then
                    psw_add_jishu_zhiyu(current_faction_name, 3)
                    cm:apply_effect_bundle("jnz_skd_tgstzy", current_faction_name, 0);
                    psw_add_jishu_shenxing(current_faction_name, 2)
                end
            end
            
            psw_delete_shanbi_effect(faction_name, "jn_shanbi_skd_ycbg")
            cm:remove_effect_bundle_from_character("jnz_tf_ex_psw_tf_ex_skd_2", psw_main_character);
            cm:apply_effect_bundle_to_character("jnz_tf_ex_psw_tf_ex_skd_3", psw_main_character, 0)
            
            psw_add_jishu_miansi(faction_name, 3)
            
            psw_add_jishu_zhongmo(5)
            
            psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_skd_3", faction_name)
            psw_aplly_costom_effect_bundle_hidden_fn("set_faction_hace_hong_ex", faction_name)
        
        
        ---深海羁绊
        elseif faction:has_effect_bundle("set_psw_tf_ex_yls_2") and faction:has_effect_bundle("set_psw_tf_ex_skd_2") and not psw_faction_has_effect_bundle(faction_name, "set_shjb_1") and not char_not_exist then
            
            common.trigger_soundevent("skd_yls_shjb")
            advice_yls_skd_shjb_1()
                
            cm:remove_effect_bundle_from_character("jnz_tf_ex_psw_tf_ex_yls_2", psw_main_character);
            cm:apply_effect_bundle_to_character("jnz_tf_ex_yls_3", psw_main_character, 0)
            
            psw_aplly_costom_effect_bundle_hidden_fn("set_shjb_1", faction_name)
        end
	end,
	true
	)
end

------ 幽灵鲨/斯卡蒂 同化度-战斗相关 --------

function yls_skd_thd_battle()
    core:remove_listener("yls_skd_thd_battle")
	core:add_listener(
	"yls_skd_thd_battle",
	"BattleCompleted",
    function(context)
        local faction_name = cm:pending_battle_cache_get_attacker_faction_name(1)
    local yls_thd=(psw_main_data.player_data[faction_name]or{}).yls_thd
    local skd_thd=(psw_main_data.player_data[faction_name]or{}).skd_thd
        local faction = cm:get_faction(faction_name)
        return cm:pending_battle_cache_human_is_involved() and ((faction:has_effect_bundle("set_psw_tf_ex_yls_1") and yls_thd <= 60) or (faction:has_effect_bundle("set_psw_tf_ex_skd_1")))
    end,
	function(context)
        
        local faction_name = cm:pending_battle_cache_get_attacker_faction_name(1)
        
        local attacker_cqi, attacker_force_cqi, attacker_name = cm:pending_battle_cache_get_attacker(1);
        local defender_cqi, defender_force_cqi, defender_name = cm:pending_battle_cache_get_defender(1);
        local attacker = cm:get_faction(attacker_name)
        local faction_leader = attacker:faction_leader()
    local jishu_shenhai=(psw_main_data.player_data[faction_name]or{}).jishu_shenhai

        local bmm_attacker_result = cm:model():pending_battle():attacker_battle_result();
    		local bmm_defender_result=cm:model():pending_battle():defender_battle_result();
local yls_faction_c,skd_faction_c=(psw_main_data.player_data[faction_name]or{}).yls_faction,(psw_main_data.player_data[faction_name]or{}).skd_faction
		if bmm_attacker_result == "close_defeat" and bmm_defender_result == "close_defeat" then
			-- They've both had a close defeat, must have been a retreat not a battle!
			return;
		elseif bmm_attacker_result == nil or bmm_defender_result == nil then
			return;
		end
		
		local attacker_won = (bmm_attacker_result == "heroic_victory") or (bmm_attacker_result == "decisive_victory") or (bmm_attacker_result == "close_victory") or (bmm_attacker_result == "pyrrhic_victory")
		
		if not attacker_won then
            return
        end
        
        local faction = cm:get_faction(faction_name)
    local yx_subtype=(psw_main_data.player_data[faction_name]or{}).yx_subtype
        local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
        
		if attacker_name == yls_faction_c or attacker_name == skd_faction_c then
		
            if faction:has_effect_bundle("set_psw_tf_ex_yls_1") and faction:has_effect_bundle("set_psw_tf_ex_skd_1") then
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yrhtdsj_nor") then
                    psw_main_data.player_data[faction_name].yls_thd = psw_main_data.player_data[faction_name].yls_thd + (yls_jichu_get*4)
                    psw_main_data.player_data[faction_name].skd_thd = psw_main_data.player_data[faction_name].skd_thd + (yls_jichu_get*4)
                elseif not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yrhtdsj_nor") then
                    psw_main_data.player_data[faction_name].yls_thd = psw_main_data.player_data[faction_name].yls_thd + (yls_jichu_get*2)
                    psw_main_data.player_data[faction_name].skd_thd = psw_main_data.player_data[faction_name].skd_thd + (yls_jichu_get*2)
                end
                
                local random_num_yls2 = cm:random_number(100, 1)
                if random_num_yls2 >=0 and random_num_yls2 <= 33 then
                    common.trigger_soundevent("yls_battle_1")
                elseif random_num_yls2 > 33 and random_num_yls2 <=66 then
                    common.trigger_soundevent("yls_battle_2")
                elseif random_num_yls2 > 66 and random_num_yls2 <=100 then
                    common.trigger_soundevent("yls_battle_3")
                end
                
                local random_num_skd2 = cm:random_number(100, 1)
                if random_num_skd2 >=0 and random_num_skd2 <= 33 and not faction:has_effect_bundle("set_psw_tf_ex_skd_3") then
                    common.trigger_soundevent("skd_battle_1")
                elseif random_num_skd2 > 33 and random_num_skd2 <=66 and not faction:has_effect_bundle("set_psw_tf_ex_skd_3") then
                    common.trigger_soundevent("skd_battle_2")
                elseif random_num_skd2 > 66 and random_num_skd2 <=100 and not faction:has_effect_bundle("set_psw_tf_ex_skd_3") then
                    common.trigger_soundevent("skd_battle_3")
                end
                if random_num_skd2 >=0 and random_num_skd2 <= 25 and faction:has_effect_bundle("set_psw_tf_ex_skd_3") then
                    common.trigger_soundevent("zsskd_battle_1")
                elseif random_num_skd2 > 25 and random_num_skd2 <=50 and faction:has_effect_bundle("set_psw_tf_ex_skd_3") then
                    common.trigger_soundevent("zsskd_battle_2")
                elseif random_num_skd2 > 50 and random_num_skd2 <=75 and faction:has_effect_bundle("set_psw_tf_ex_skd_3") then
                    common.trigger_soundevent("zsskd_battle_3")
                elseif random_num_skd2 > 75 and random_num_skd2 <=100 and faction:has_effect_bundle("set_psw_tf_ex_skd_3") then
                    common.trigger_soundevent("zsskd_battle_4")
                end
                
            elseif faction:has_effect_bundle("set_psw_tf_ex_yls_1") then
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yrhtdsj_nor") then
                    psw_main_data.player_data[faction_name].yls_thd = psw_main_data.player_data[faction_name].yls_thd + (yls_jichu_get*2)
                elseif not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yrhtdsj_nor") then
                    psw_main_data.player_data[faction_name].yls_thd = psw_main_data.player_data[faction_name].yls_thd + yls_jichu_get
                end
                
                local random_num_yls1 = cm:random_number(100, 1)
                if random_num_yls1 >=0 and random_num_yls1 <= 33 then
                    common.trigger_soundevent("yls_battle_1")
                elseif random_num_yls1 > 33 and random_num_yls1 <=66 then
                    common.trigger_soundevent("yls_battle_2")
                elseif random_num_yls1 > 66 and random_num_yls1 <=100 then
                    common.trigger_soundevent("yls_battle_3")
                end
            elseif faction:has_effect_bundle("set_psw_tf_ex_skd_1") then
                if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yrhtdsj_nor") then
                    psw_main_data.player_data[faction_name].skd_thd = psw_main_data.player_data[faction_name].skd_thd + (yls_jichu_get*2)
                    
                elseif not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yrhtdsj_nor") then
                    psw_main_data.player_data[faction_name].skd_thd = psw_main_data.player_data[faction_name].skd_thd + yls_jichu_get
                    
                end
                
                local random_num_skd1 = cm:random_number(100, 1)
                if random_num_skd1 >=0 and random_num_skd1 <= 33 and not faction:has_effect_bundle("set_psw_tf_ex_skd_3") then
                    common.trigger_soundevent("skd_battle_1")
                elseif random_num_skd1 > 33 and random_num_skd1 <=66 and not faction:has_effect_bundle("set_psw_tf_ex_skd_3") then
                    common.trigger_soundevent("skd_battle_2")
                elseif random_num_skd1 > 66 and random_num_skd1 <=100 and not faction:has_effect_bundle("set_psw_tf_ex_skd_3") then
                    common.trigger_soundevent("skd_battle_3")
                end
                if random_num_skd1 >=0 and random_num_skd1 <= 25 and faction:has_effect_bundle("set_psw_tf_ex_skd_3") then
                    common.trigger_soundevent("zsskd_battle_1")
                elseif random_num_skd1 > 25 and random_num_skd1 <=50 and faction:has_effect_bundle("set_psw_tf_ex_skd_3") then
                    common.trigger_soundevent("zsskd_battle_2")
                elseif random_num_skd1 > 50 and random_num_skd1 <=75 and faction:has_effect_bundle("set_psw_tf_ex_skd_3") then
                    common.trigger_soundevent("zsskd_battle_3")
                elseif random_num_skd1 > 75 and random_num_skd1 <=100 and faction:has_effect_bundle("set_psw_tf_ex_skd_3") then
                    common.trigger_soundevent("zsskd_battle_4")
                end
            end
            local yls_thd = psw_main_data.player_data[faction_name].yls_thd
            local skd_thd = psw_main_data.player_data[faction_name].skd_thd
            
            local char_not_exist = psw_main_character:is_null_interface() or psw_main_character:is_wounded() or psw_main_character:is_at_sea() or not cm:char_is_general_with_army(psw_main_character)
            
            ---- 幽灵鲨觉醒
            
            if yls_thd >= 50 and not faction:has_effect_bundle("set_psw_tf_ex_yls_2") and not char_not_exist then
                
                common.trigger_soundevent("yls_2")
                advice_psw_tf_ex_yls_2()
                
                
                cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                    {
                    "psw_tf_ex_yls_2"
                    }
                )
                
                psw_delete_shanbi_effect(faction_name, "jn_shanbi_yls_qg")
                cm:remove_effect_bundle_from_character("jnz_tf_ex_psw_tf_ex_yls_1", psw_main_character);
                cm:apply_effect_bundle_to_character("jnz_tf_ex_psw_tf_ex_yls_2", psw_main_character, 0)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_yls_2", faction_name)
                
            ---- 斯卡蒂觉醒
            
            elseif skd_thd >= 50 and not faction:has_effect_bundle("set_psw_tf_ex_skd_2") and not char_not_exist then
                
                common.trigger_soundevent("skd_2")
                advice_psw_tf_ex_skd_2_1()
                
                
                
                
                cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                    {
                    "psw_tf_ex_skd_2"
                    }
                )
                
                psw_add_jishu_xingyun(faction_name, 3)
                psw_add_jishu_miansi(faction_name, 1)
                
                psw_delete_shanbi_effect(faction_name, "jn_shanbi_skd_yl")
                cm:remove_effect_bundle_from_character("jnz_tf_ex_psw_tf_ex_skd_1", psw_main_character);
                cm:apply_effect_bundle_to_character("jnz_tf_ex_psw_tf_ex_skd_2", psw_main_character, 0)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_skd_2", faction_name)
            
            ---- 虹斯卡蒂
            elseif skd_thd >= 100 and faction:has_effect_bundle("set_psw_tf_ex_skd_2") and jishu_shenhai >= 5 and not faction:has_effect_bundle("set_psw_tf_ex_skd_3") and not char_not_exist then
                
                common.trigger_soundevent("skd_3")
                advice_psw_tf_ex_skd_3_1()
                

                
                cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                    {
                    "psw_tf_ex_skd_3"
                    }
                )
                psw_add_hong_count(faction_name, 1)
                
                local psw_faction_list = cm:model():world():faction_list();
            
                for i = 0, psw_faction_list:num_items() - 1 do
                    local current_faction = psw_faction_list:item_at(i);
                    local current_faction_name = current_faction:name()
                    if current_faction:is_human() then
                        psw_add_jishu_zhiyu(current_faction_name, 3)
                        cm:apply_effect_bundle("jnz_skd_tgstzy", current_faction_name, 0);
                        psw_add_jishu_shenxing(current_faction_name, 2)
                    end
                end
                
                psw_add_jishu_zhongmo(5)

                psw_add_jishu_miansi(faction_name, 3)
                
                psw_delete_shanbi_effect(faction_name, "jn_shanbi_skd_ycbg")
                cm:remove_effect_bundle_from_character("jnz_tf_ex_psw_tf_ex_skd_2", psw_main_character);
                cm:apply_effect_bundle_to_character("jnz_tf_ex_psw_tf_ex_skd_3", psw_main_character, 0)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_skd_3", faction_name)
                psw_aplly_costom_effect_bundle_hidden_fn("set_faction_hace_hong_ex", faction_name)
            
            
            ---深海羁绊
            elseif faction:has_effect_bundle("set_psw_tf_ex_yls_2") and faction:has_effect_bundle("set_psw_tf_ex_skd_2") and not psw_faction_has_effect_bundle(faction_name, "set_shjb_1") and not char_not_exist then
                
                common.trigger_soundevent("skd_yls_shjb")
                advice_yls_skd_shjb_1()
                
                cm:remove_effect_bundle_from_character("jnz_tf_ex_psw_tf_ex_yls_2", psw_main_character);
                cm:apply_effect_bundle_to_character("jnz_tf_ex_yls_3", psw_main_character, 0)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_shjb_1", faction_name)
            end
		end
	end,
	true
	)
end



--- 布雷斯特 好感度获取 ---

function blst_love_level_battle()
    core:remove_listener("blst_love_level_battle")
    core:add_listener(
    "blst_love_level_battle",
    "BattleCompleted",
    function(context)
        local faction_name = cm:pending_battle_cache_get_attacker_faction_name(1)
        return cm:pending_battle_cache_human_is_involved() and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_blst_1") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_blst_2")
    end,
    function(context)
        local faction_name = cm:pending_battle_cache_get_attacker_faction_name(1)
        local faction = cm:get_faction(faction_name)
        local yx_subtype = psw_main_data.player_data[faction_name].yx_subtype
        local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
        local bmm_attacker_result = cm:model():pending_battle():attacker_battle_result();
        local bmm_defender_result = cm:model():pending_battle():defender_battle_result();

        if bmm_attacker_result == "close_defeat" and bmm_defender_result == "close_defeat" then
            return;
        elseif bmm_attacker_result == nil or bmm_defender_result == nil then
            return;
        end

        
            
        if bmm_attacker_result == "pyrrhic_victory" then
            psw_main_data.player_data[faction_name].blst_love = psw_main_data.player_data[faction_name].blst_love + 2
        elseif bmm_attacker_result == "close_victory" then
            psw_main_data.player_data[faction_name].blst_love = psw_main_data.player_data[faction_name].blst_love + 3
        elseif bmm_attacker_result == "decisive_victory" then
            psw_main_data.player_data[faction_name].blst_love = psw_main_data.player_data[faction_name].blst_love + 5
        elseif bmm_attacker_result == "heroic_victory" then
            psw_main_data.player_data[faction_name].blst_love = psw_main_data.player_data[faction_name].blst_love + 7
        end
        local blst_love = psw_main_data.player_data[faction_name].blst_love
        
        local char_not_exist = psw_main_character:is_null_interface() or psw_main_character:is_wounded() or psw_main_character:is_at_sea() or not cm:char_is_general_with_army(psw_main_character)

        if blst_love >= 100 and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_blst_2") and not char_not_exist then
            advice_blst_2_1()
            psw_add_jishu_miansi(faction_name, 2)
            
            cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                {
                "psw_tf_ex_blst_2"
                }
            )
            
            psw_add_jingying_unit_to_facion(faction_name, true, "psw_dlc6_blst_dkek", 1, 0.25)
            cm:remove_effect_bundle_from_character("jnz_tf_ex_blst_1", psw_main_character);
            cm:apply_effect_bundle_to_character("jnz_tf_ex_blst_2", psw_main_character, 0)

            psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_blst_2", faction_name)
        end
        
    end,
    true
    )
end



--- 独角兽 好感度获取 ---

function djs_love_level_battle()
    core:remove_listener("djs_love_level_battle")
    core:add_listener(
    "djs_love_level_battle",
    "BattleCompleted",
    function(context)
        local faction_name = cm:pending_battle_cache_get_attacker_faction_name(1)
        return cm:pending_battle_cache_human_is_involved() and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_djs_1") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_djs_2")
    end,
    function(context)
        local faction_name = cm:pending_battle_cache_get_attacker_faction_name(1)
        local faction = cm:get_faction(faction_name)
        local yx_subtype = psw_main_data.player_data[faction_name].yx_subtype
        local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
        local bmm_attacker_result = cm:model():pending_battle():attacker_battle_result();
        local bmm_defender_result = cm:model():pending_battle():defender_battle_result();

        if bmm_attacker_result == "close_defeat" and bmm_defender_result == "close_defeat" then
            return;
        elseif bmm_attacker_result == nil or bmm_defender_result == nil then
            return;
        end

        local hgd_djs = psw_main_data.player_data[faction_name].hgd_djs
            
        if bmm_attacker_result == "pyrrhic_victory" then
            psw_add_hgd_djs(faction_name, 2)
        elseif bmm_attacker_result == "close_victory" then
            psw_add_hgd_djs(faction_name, 3)
        elseif bmm_attacker_result == "decisive_victory" then
            psw_add_hgd_djs(faction_name, 5)
        elseif bmm_attacker_result == "heroic_victory" then
            psw_add_hgd_djs(faction_name, 7)
        end
        
        local char_not_exist = psw_main_character:is_null_interface() or psw_main_character:is_wounded() or psw_main_character:is_at_sea() or not cm:char_is_general_with_army(psw_main_character)

        if hgd_djs >= 100 and not psw_faction_has_effect_bundle(faction_name, "set_djs_syzj") and not char_not_exist then
            
            cm:add_ancillary_to_faction(faction, "djs_syzj", false)

            psw_aplly_costom_effect_bundle_hidden_fn("set_djs_syzj", faction_name)
        end
        
    end,
    true
    )
end


------ 独角兽 天使的My Night 觉醒--------

function djs_my_night_jx()
    core:remove_listener("djs_my_night_jx")
    core:add_listener(
    "djs_my_night_jx",
    "CharacterAncillaryGained",
    function(context)
        local faction_name = context:character():faction():name()
        return psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_djs_1") and context:ancillary() == "djs_syzj" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_djs_2")
    end,
    function(context)
        local faction_name = context:character():faction():name()
        local faction = cm:get_faction(faction_name)
        if not faction or not psw_main_data.player_data[faction_name] then
            return
        end
        local yx_subtype = psw_main_data.player_data[faction_name].yx_subtype
        local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
        local djs_meili = psw_main_data.player_data[faction_name].psw_meili
        local jishu_jianniang = psw_main_data.player_data[faction_name].jishu_jianniang
        
        if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_guanghui_nor") then
            jishu_jianniang = jishu_jianniang - 1
        end
        
        if jishu_jianniang <= 1 and djs_meili >= 10 and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_guanghui_nor") then
            
            advice_djs_3_1()
            cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                {
                "psw_tf_ex_djs_3"
                }
            )
            
            cm:add_ancillary_to_faction(faction, "djs_flt0", false)
            cm:remove_effect_bundle_from_character("jnz_tf_ex_djs_1", psw_main_character);
            cm:apply_effect_bundle_to_character("jnz_tf_ex_djs_3", psw_main_character, 0);
            
            local djs_faction_list = cm:model():world():faction_list();
            for i = 0, djs_faction_list:num_items() - 1 do
                local current_faction = djs_faction_list:item_at(i);
                if current_faction:is_human() == true then
                    psw_add_jishu_meili(faction_name, 1)
                end
            end
            
            psw_add_jishu_miansi(faction_name, 3)
        
            psw_add_jishu_zhongmo(5)
            
            psw_add_hong_count(faction_name, 1)
            
            psw_delete_shanbi_effect(faction_name, "shanbi_djs_cbdsy")
            
            psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_djs_2", faction_name)
            psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_djs_3", faction_name)
        elseif 1 == 1 then
            advice_djs_2_1()
            cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                {
                "psw_tf_ex_djs_2"
                }
            )
            psw_add_jishu_meili(faction_name, 2)
            
            cm:remove_effect_bundle_from_character("jnz_tf_ex_djs_1", psw_main_character);
            cm:apply_effect_bundle_to_character("jnz_tf_ex_djs_2", psw_main_character, 0);
                    
            psw_add_jishu_moli(faction_name, 5)
            
            psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_djs_2", faction_name)
        end
    end,
	true
	)
end


------ 独角兽 支援空母 --------

function psw_djs_zykm()
    core:remove_listener("psw_djs_zykm")
    core:add_listener(
    "psw_djs_zykm",
    "CharacterAncillaryGained",
    function(context)
        return (context:ancillary() == "djs_fw190" or context:ancillary() == "djs_f4ut0" or context:ancillary() == "djs_dym" or context:ancillary() == "djs_flt0")
    end,
    function(context)
        local faction_name = context:character():faction():name()
        local faction = cm:get_faction(faction_name)
        local ancillary = context:ancillary()
        psw_delete_ancillary_with_time_delay(faction, ancillary, 0.1)
        
        cm:callback(function()
            cm:add_ancillary_to_faction(faction, ancillary, true)
            
            
            local crt_bundle
            local jzj_sx = 1
            if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_djs_3") then
                jzj_sx = 2
            end
            
            
            if ancillary == "djs_fw190" then
                cm:apply_effect_bundle("jnz_tf_ex_djs_fw190", faction_name, 0)
                crt_bundle = "jnz_tf_ex_djs_fw190"
                psw_main_data.player_data[faction_name].crt_bundle_jishu = psw_main_data.player_data[faction_name].crt_bundle_jishu + 1
            elseif ancillary == "djs_f4ut0" then
                cm:apply_effect_bundle("jnz_tf_ex_djs_F4U", faction_name, 0)
                crt_bundle = "jnz_tf_ex_djs_F4U"
                psw_main_data.player_data[faction_name].crt_bundle_jishu = psw_main_data.player_data[faction_name].crt_bundle_jishu + 1
            elseif ancillary == "djs_dym" then
                cm:apply_effect_bundle("jnz_tf_ex_djs_F6F", faction_name, 0)
                crt_bundle = "jnz_tf_ex_djs_F6F"
                psw_main_data.player_data[faction_name].crt_bundle_jishu = psw_main_data.player_data[faction_name].crt_bundle_jishu + 1
            elseif ancillary == "djs_flt0" then
                cm:apply_effect_bundle("jnz_tf_ex_djs_FLT0", faction_name, 0)
                crt_bundle = "jnz_tf_ex_djs_FLT0"
                psw_main_data.player_data[faction_name].crt_bundle_jishu = psw_main_data.player_data[faction_name].crt_bundle_jishu + 1
            end
            
            local crt_bundle_jishu = psw_main_data.player_data[faction_name].crt_bundle_jishu
            if crt_bundle_jishu > jzj_sx then
                if faction:has_effect_bundle("jnz_tf_ex_djs_fw190") then
                    cm:remove_effect_bundle("jnz_tf_ex_djs_fw190", faction_name)
                end
                if faction:has_effect_bundle("jnz_tf_ex_djs_F4U") then
                    cm:remove_effect_bundle("jnz_tf_ex_djs_F4U", faction_name)
                end
                if faction:has_effect_bundle("jnz_tf_ex_djs_F6F") then
                    cm:remove_effect_bundle("jnz_tf_ex_djs_F6F", faction_name)
                end
                if faction:has_effect_bundle("jnz_tf_ex_djs_FLT0") then
                    cm:remove_effect_bundle("jnz_tf_ex_djs_FLT0", faction_name)
                end
                psw_main_data.player_data[faction_name].crt_bundle_jishu = 0
                local djs_random_2 = cm:random_number(100, 1)
                if djs_random_2 <= 33 then
                    advice_djs_zykm_ts_1_jj()
                elseif djs_random_2 <= 66 and djs_random > 33 then
                    advice_djs_zykm_ts_2_hb()
                elseif djs_random_2 <= 100 and djs_random > 66 then
                    advice_djs_zykm_ts_3_br()
                end
                --common.trigger_soundevent("Play_wh2_dlc17_bst_taurox_dip_neg_nor_01")
            elseif 1 == 1 then
                local djs_random = cm:random_number(100, 1)
                if djs_random <= 50 then
                    advice_djs_zykm_1_jgwb()
                elseif djs_random <= 100 and djs_random > 50 then
                    advice_djs_zykm_2_bjzd()
                end

            end
            
        end, 1)
    end,
    true
    )
end


--- 独角兽 装填指挥 ---

function psw_djs_ztzh()
    core:remove_listener("psw_djs_ztzh")
    core:add_listener(
    "psw_djs_ztzh",
    "CharacterRankUp",
    function(context)
        local character = context:character();
        local faction = character:faction()
        local faction_name = faction:name()
        local faction_leader = faction:faction_leader()
        if faction:is_human() == true and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_djs_1") and character == faction_leader then
            return true
        end
    end,
    function(context)
        local character = context:character();
        local faction = character:faction()
        local faction_name = faction:name()
        local rank = character:rank()
        local rank_up_level = math.floor(rank/2)
        if faction:has_effect_bundle("psw_bundle_djs_ztzh") then
            cm:remove_effect_bundle("psw_bundle_djs_ztzh", faction_name)
        end
        local effect_bundle = cm:create_new_custom_effect_bundle("psw_bundle_djs_ztzh")
        effect_bundle:set_duration(0)
        effect_bundle:add_effect("psw_stat_reload_time_hidden", "faction_to_force_own", rank_up_level);
        cm:apply_custom_effect_bundle_to_faction(effect_bundle, faction)
	end,
	true
	)
end


------------ 菲娅计数 - 效果赋予 ----------------

function fia_main_effect_apply(faction_name, fia_main_js)
    local faction = cm:get_faction(faction_name)
    if faction:has_effect_bundle("psw_bundle_fia") then
        cm:remove_effect_bundle("psw_bundle_fia", faction_name)
    end
    local effect_bundle = cm:create_new_custom_effect_bundle("psw_bundle_fia")
    local xishu = math.floor(fia_main_js * 0.3)
    effect_bundle:set_duration(0)
    effect_bundle:add_effect("wh2_main_effect_character_stat_weapon_strength_base", "faction_to_character_own", fia_main_js * 2);
    effect_bundle:add_effect("wh_main_effect_character_stat_ap_damage", "faction_to_character_own", fia_main_js * 3);
    effect_bundle:add_effect("psw_stat_armour_hidden", "faction_to_force_own", xishu);
    effect_bundle:add_effect("psw_stat_morale_mult_hidden", "faction_to_force_own", xishu);
    effect_bundle:add_effect("psw_stat_speed_hidden", "faction_to_force_own", xishu);
    effect_bundle:add_effect("psw_stat_melee_attack_mult_hidden", "faction_to_force_own", xishu);
    effect_bundle:add_effect("psw_stat_melee_defence_mult_hidden", "faction_to_force_own", xishu);
    effect_bundle:add_effect("psw_stat_weapon_strength_mult_hidden", "faction_to_force_own", xishu);
    effect_bundle:add_effect("psw_stat_missile_rongliang_hidden", "faction_to_force_own", xishu);
    effect_bundle:add_effect("missile_damage_hidden", "faction_to_force_own", xishu);
    effect_bundle:add_effect("psw_stat_charge_bonus_mult_hidden", "faction_to_force_own", xishu);
    cm:apply_custom_effect_bundle_to_faction(effect_bundle, faction)
end

------------ 菲娅计数 - 效果组提示 ----------------

function fia_main_effect_xianshi(faction_name, fia_main_js)
    local faction = cm:get_faction(faction_name)
    local yx_subtype = psw_main_data.player_data[faction_name].yx_subtype
    local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
    
    local fia_xiaohao_js = psw_main_data.player_data[faction_name].fia_xiaohao_js
    local fia_kyjs = fia_main_js - fia_xiaohao_js
    
    local xingyun_bundle = "jnz_fia_fyjs_"
    
    if fia_kyjs <= 0 then
        return
    end

    for i = 0, 100 do
        local bundle = xingyun_bundle .. i
        cm:remove_effect_bundle_from_character(bundle, psw_main_character)
        if fia_kyjs > 100 then
            cm:apply_effect_bundle_to_character("jnz_fia_fyjs_100", psw_main_character, 0)     
        elseif fia_kyjs == i then
            cm:apply_effect_bundle_to_character(bundle, psw_main_character, 0)
        end
    end
end

------------ 菲娅计数 - 变化 - 觉醒 ----------------

function fia_main_jsbh_jx(faction_name)
    if not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_fia_1") then
        return
    end
    local faction = cm:get_faction(faction_name)
    local fia_cz1_js = psw_main_data.player_data[faction_name].fia_cz1_js
    local fia_cz2_js = psw_main_data.player_data[faction_name].fia_cz2_js
    local fia_cz3_js = psw_main_data.player_data[faction_name].fia_cz3_js
    psw_main_data.player_data[faction_name].fia_main_js = fia_cz1_js + fia_cz2_js + fia_cz3_js
    if psw_main_data.player_data[faction_name].fia_main_js > 100 then
        psw_main_data.player_data[faction_name].fia_main_js = 100
        fia_main_effect_apply(faction_name, psw_main_data.player_data[faction_name].fia_main_js)
        fia_main_effect_xianshi(faction_name, psw_main_data.player_data[faction_name].fia_main_js)
        return
    end
    local fia_main_js = psw_main_data.player_data[faction_name].fia_main_js
    fia_main_effect_apply(faction_name, fia_main_js)
    fia_main_effect_xianshi(faction_name, fia_main_js)
    local yx_subtype = psw_main_data.player_data[faction_name].yx_subtype
    local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
    if fia_main_js >= 30 and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_fia_2") then
        psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_fia_2", faction_name)
        cm:callback(function()
            advice_fia_2_1()
            cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                {
                "psw_tf_ex_fia_2"
                }
            )
            
            cm:apply_effect_bundle_to_character("jnz_tf_ex_fia_2", psw_main_character, 0);
            psw_add_jishu_xingyun(faction_name, 2)
            psw_hh_start_yydwy(faction_name)

        end, 2)
    elseif fia_main_js >= 60 and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_fia_3") then
        psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_fia_3", faction_name)
        cm:callback(function()
            advice_fia_3_1()
            cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                {
                "psw_tf_ex_fia_3"
                }
            )
            
            psw_add_hong_count(faction_name, 1)
            
            psw_add_jishu_miansi(faction_name, 5)
    
            cm:remove_effect_bundle_from_character("jnz_tf_ex_fia_2", psw_main_character);
            cm:apply_effect_bundle_to_character("jnz_tf_ex_fia_3", psw_main_character, 0);
            
            psw_add_jishu_zhongmo(3)
            
            psw_delete_shanbi_effect(faction_name, "shanbi_fia_fydsh")
            
            psw_hh_start_yydwy(faction_name)
            
        end, 2)
    end
end
------------ 菲娅-成长Ⅰ- 完成任务 ----------------

function fia_cz1_rwwc()
    core:remove_listener("fia_cz1_rwwc")
    core:add_listener(
        "fia_cz1_rwwc",
        "MissionSucceeded",
        function(context)
            local faction_name = context:faction():name()
            return psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_fia_1") and not psw_faction_has_effect_bundle(faction_name, "fia_cz1_js_sx")
        end,
        function(context)
            local faction_name = context:faction():name()
            psw_main_data.player_data[faction_name].fia_cz1_js = psw_main_data.player_data[faction_name].fia_cz1_js + 1
            if psw_main_data.player_data[faction_name].fia_cz1_js >= 40 then
                psw_main_data.player_data[faction_name].fia_cz1_js = 40
                psw_aplly_costom_effect_bundle_hidden_fn("fia_cz1_js_sx", faction_name)
            end
            fia_main_jsbh_jx(faction_name)
        end,
        true
    );
end

------------ 菲娅-成长Ⅱ- 派系领袖升级 ----------------
function fia_cz2_lxsj()
    core:remove_listener("fia_cz2_lxsj")
    core:add_listener(
    "fia_cz2_lxsj",
    "CharacterRankUp",
    function(context)
        local character = context:character();
        local faction = character:faction()
        local faction_name = faction:name()
        local faction_leader = faction:faction_leader()
        if faction:is_human() == true and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_fia_1") and character == faction_leader and not psw_faction_has_effect_bundle(faction_name, "fia_cz2_js_sx") then
            return true
        end
    end,
    function(context)
        local character = context:character();
        local faction = character:faction()
        local faction_name = faction:name()
        local rank = character:rank()
        local fia_cz2_js = psw_main_data.player_data[faction_name].fia_cz2_js
        local get_rank = psw_main_data.player_data[faction_name].fia_ledear_rank or 0
        local crt_rank_to_add = rank - get_rank
        if fia_cz2_js >= 40 then
            crt_rank_to_add = 40
            psw_aplly_costom_effect_bundle_hidden_fn("fia_cz2_js_sx", faction_name)
        end
        
        psw_main_data.player_data[faction_name].fia_cz2_js = crt_rank_to_add
        fia_main_jsbh_jx(faction_name)
    end,
    true
    )
end

------------ 菲娅-成长Ⅲ - BOSS/传奇野兽击败 ----------------
function fia_cz3_victory_vs_boss(faction_name, is_legend)
    if psw_faction_has_effect_bundle(faction_name, "fia_cz3_js_sx") then
        return
    end
    if is_legend then
        psw_main_data.player_data[faction_name].fia_cz3_js = psw_main_data.player_data[faction_name].fia_cz3_js + 4
    elseif not is_legend then
        psw_main_data.player_data[faction_name].fia_cz3_js = psw_main_data.player_data[faction_name].fia_cz3_js + 5
    end
    if psw_main_data.player_data[faction_name].fia_cz3_js >= 20 then
        psw_main_data.player_data[faction_name].fia_cz3_js = 20
        psw_aplly_costom_effect_bundle_hidden_fn("fia_cz3_js_sx", faction_name)
    end
    fia_main_jsbh_jx(faction_name)
end

------------ 斯卡蒂 - 古神猎杀 ----------------
function skd_victory_vs_boss(faction_name)
    local faction = cm:get_faction(faction_name)
    if not faction:has_effect_bundle("set_psw_tf_ex_skd_1") then
        return
    end
    local skd_gsls_cs = psw_main_data.player_data[faction_name].skd_gsls_cs
    if skd_gsls_cs >= 3 then
        return
    end
    local skd_shenxing =  faction:pooled_resource_manager():resource("psw_shenxing"):value()
    psw_add_jishu_shenxing(faction_name, 1)
    psw_main_data.player_data[faction_name].skd_gsls_cs = psw_main_data.player_data[faction_name].skd_gsls_cs + 1
end


------------ 爱丽丝 - 沉眠的无名少女 - 苏醒 -------------

---苏醒主函数
function psw_dlc5_alice_suxing(faction_name)
    local faction = cm:get_faction(faction_name)
    local faction_leader = faction:faction_leader()
    cm:callback(function()
        advice_alice_2_1()
    end, 7)
    local yx_subtype = psw_main_data.player_data[faction_name].yx_subtype
    local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
    cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
        {
        "psw_tf_ex_alice_2"
        }
    )
        
    local alice_ledear_rank = faction_leader:rank()
    psw_main_data.player_data[faction_name].alice_ledear_rank = alice_ledear_rank
    psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_alice_2", faction_name)
end

function alice_sleep_sx()
    core:remove_listener("alice_sleep_sx")
	core:add_listener(
	"alice_sleep_sx",
	"FactionTurnStart",
    function(context)
        local faction_name = context:faction():name()
        if context:faction():is_human() == true and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_alice_1") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_alice_2") then
            return true
        end
    end,
    function(context)
        local faction = context:faction()
        
        local faction_name = context:faction():name()
        local alice_sx = faction:pooled_resource_manager():resource("psw_shenxing"):value()
        local alice_jwts = psw_main_data.player_data[faction_name].jishu_xilie_jwts
        local alice_qnkx = psw_main_data.player_data[faction_name].jishu_xilie_qnkx
        local random_number = cm:random_number(100, 1)
        local sx_gailv = alice_sx + (alice_jwts * 2) + (alice_qnkx * 2) + 1
        if random_number < sx_gailv or faction:has_effect_bundle("set_psw_tf_ex_jwts_1") then
            psw_dlc5_alice_suxing(faction_name)
        end
    end,
    true
    )
end

------------ 爱丽丝勇者等级 - 效果赋予 -------------

function alice_main_effect_apply(faction_name, alice_main_js)
    local faction = cm:get_faction(faction_name)
    if faction:has_effect_bundle("psw_bundle_alice_yzdj") then
        cm:remove_effect_bundle("psw_bundle_alice_yzdj", faction_name)
    end
    local effect_bundle = cm:create_new_custom_effect_bundle("psw_bundle_alice_yzdj")
    local xishu = math.floor(alice_main_js/4)
    effect_bundle:set_duration(0)
    effect_bundle:add_effect("psw_stat_melee_attack_mult_hidden", "faction_to_force_own", xishu);
    effect_bundle:add_effect("wh3_main_effect_force_stat_melee_defence_mult", "faction_to_force_own", xishu);
    effect_bundle:add_effect("psw_stat_weapon_strength_mult_hidden", "faction_to_force_own", xishu);
    effect_bundle:add_effect("missile_damage_hidden", "faction_to_force_own", xishu);
    cm:apply_custom_effect_bundle_to_faction(effect_bundle, faction)
end



---- 爱丽丝勇者等级 lv5 ----

function alice_effect_apply_lv5(faction_name)
    local faction = cm:get_faction(faction_name)
    local effect_bundle = cm:create_new_custom_effect_bundle("psw_bundle_alice_yzdj_lv5")
    effect_bundle:set_duration(0)
    effect_bundle:add_effect("wh_main_effect_force_stat_ap_damage", "faction_to_force_own", 10);
    cm:apply_custom_effect_bundle_to_faction(effect_bundle, faction)
end

---- 爱丽丝勇者等级 lv10 ----

function alice_effect_apply_lv10(faction_name)
    local faction = cm:get_faction(faction_name)
    local effect_bundle = cm:create_new_custom_effect_bundle("psw_bundle_alice_yzdj_lv10")
    effect_bundle:set_duration(0)
    effect_bundle:add_effect("wh_main_effect_public_order_faction", "faction_to_province_own", 3);
    cm:apply_custom_effect_bundle_to_faction(effect_bundle, faction)
end

---- 爱丽丝勇者等级 lv20 ----

function alice_effect_apply_lv20(faction_name)
    local faction = cm:get_faction(faction_name)
    local effect_bundle = cm:create_new_custom_effect_bundle("psw_bundle_alice_yzdj_lv20")
    effect_bundle:set_duration(0)
    effect_bundle:add_effect("wh_main_faction_political_diplomacy_mod", "faction_to_faction_own_unseen", 25);
    cm:apply_custom_effect_bundle_to_faction(effect_bundle, faction)
end

---- 爱丽丝勇者等级 lv30 ----

function alice_effect_apply_lv30(faction_name)
    local faction = cm:get_faction(faction_name)
    local effect_bundle = cm:create_new_custom_effect_bundle("psw_bundle_alice_yzdj_lv30")
    effect_bundle:set_duration(0)
    effect_bundle:add_effect("psw_stat_all_resistance_hidden", "faction_to_force_own", 5);
    effect_bundle:add_effect("psw_jichu_tsbh", "faction_to_character_own", -5);
    cm:apply_custom_effect_bundle_to_faction(effect_bundle, faction)
end

---- 爱丽丝勇者等级 lv40 ----

function alice_effect_apply_lv40(faction_name)
    local faction = cm:get_faction(faction_name)
    local effect_bundle = cm:create_new_custom_effect_bundle("psw_bundle_alice_yzdj_lv40")
    effect_bundle:set_duration(0)
    effect_bundle:add_effect("wh_main_effect_force_stat_leadership", "faction_to_force_own", 8);
    cm:apply_custom_effect_bundle_to_faction(effect_bundle, faction)
end

---- 爱丽丝勇者等级 lv50 ----

function alice_effect_apply_lv50(faction_name)
    local faction = cm:get_faction(faction_name)
    local effect_bundle = cm:create_new_custom_effect_bundle("psw_bundle_alice_yzdj_lv50")
    effect_bundle:set_duration(0)
    effect_bundle:add_effect("wh_main_effect_economy_gdp_mod_all", "faction_to_region_own", 25);
    cm:apply_custom_effect_bundle_to_faction(effect_bundle, faction)
end

---- 爱丽丝勇者等级 lv60 ----

function alice_effect_apply_lv60(faction_name)
    local faction = cm:get_faction(faction_name)
    local effect_bundle = cm:create_new_custom_effect_bundle("psw_bundle_alice_yzdj_lv60")
    effect_bundle:set_duration(0)
    effect_bundle:add_effect("wh_main_effect_character_stat_ap_damage", "faction_to_faction_leader", 200);
    effect_bundle:add_effect("wh2_main_effect_character_stat_weapon_strength_base", "faction_to_faction_leader", 100);
    cm:apply_custom_effect_bundle_to_faction(effect_bundle, faction)
end

---- 爱丽丝勇者等级 lv70 ----

function alice_effect_apply_lv70(faction_name)
    local faction = cm:get_faction(faction_name)
    local effect_bundle = cm:create_new_custom_effect_bundle("psw_bundle_alice_yzdj_lv70")
    effect_bundle:set_duration(0)
    effect_bundle:add_effect("psw_stat_magic_resistance_hidden", "faction_to_force_own", 15);
    cm:apply_custom_effect_bundle_to_faction(effect_bundle, faction)
end

---- 爱丽丝勇者等级 lv80 ----

function alice_effect_apply_lv80(faction_name)
    local faction = cm:get_faction(faction_name)
    local effect_bundle = cm:create_new_custom_effect_bundle("psw_bundle_alice_yzdj_lv80")
    effect_bundle:set_duration(0)
    effect_bundle:add_effect("psw_stat_armour_hidden", "faction_to_force_own", 25);
    cm:apply_custom_effect_bundle_to_faction(effect_bundle, faction)
end

---- 爱丽丝勇者等级 lv90 ----

function alice_effect_apply_lv90(faction_name)
    local faction = cm:get_faction(faction_name)
    local effect_bundle = cm:create_new_custom_effect_bundle("psw_bundle_alice_yzdj_lv90")
    effect_bundle:set_duration(0)
    effect_bundle:add_effect("psw_stat_weapon_strength_mult_hidden", "faction_to_force_own", 15);
    cm:apply_custom_effect_bundle_to_faction(effect_bundle, faction)
end

---- 虹爱丽丝 队友BUFF ----

function alice_effect_apply_lv100_ally(faction_name)
    local faction = cm:get_faction(faction_name)
    local alice_faction_list = cm:model():world():faction_list()
    for i = 0, alice_faction_list:num_items() - 1 do
        local current_faction = alice_faction_list:item_at(i);
        local current_faction_name = current_faction:name()
        if current_faction:is_human() == true then
            psw_add_jishu_shenxing(faction_name, 1)
            psw_add_jishu_shenxing(current_faction_name, 2)
            local jishu_xilie_jwts = psw_main_data.player_data[current_faction_name].jishu_xilie_jwts
            psw_main_data.global_data.alice_jwts_jishu = psw_main_data.global_data.alice_jwts_jishu + jishu_xilie_jwts
            if current_faction:has_effect_bundle("psw_bundle_alice_lv100_ally") then
                cm:remove_effect_bundle("psw_bundle_alice_lv100_ally", current_faction_name)
            end
            local effect_bundle = cm:create_new_custom_effect_bundle("psw_bundle_alice_lv100_ally")
            effect_bundle:set_duration(0)
            effect_bundle:add_effect("alice_qldyq", "faction_to_force_own", 1)
            cm:apply_custom_effect_bundle_to_faction(effect_bundle, current_faction)
            
        end
    end
    local alice_faction_list_2 = cm:model():world():faction_list()
    for i = 0, alice_faction_list_2:num_items() - 1 do
        local current_faction_2 = alice_faction_list_2:item_at(i);
        local current_faction_name_2 = current_faction_2:name()
        if current_faction_2:is_human() == true then
            local alice_jwts_jishu_2 = psw_main_data.global_data.alice_jwts_jishu
            local xishu = alice_jwts_jishu_2 * 1
            if current_faction_2:has_effect_bundle("psw_bundle_alice_lv100_ally_2") then
                cm:remove_effect_bundle("psw_bundle_alice_lv100_ally_2", current_faction_name)
            end
            local effect_bundle_2 = cm:create_new_custom_effect_bundle("psw_bundle_alice_lv100_ally_2")
            effect_bundle_2:set_duration(0)
            effect_bundle_2:add_effect("psw_stat_all_resistance_hidden", "faction_to_force_own", xishu)
            effect_bundle_2:add_effect("psw_jichu_tsbh", "faction_to_character_own", -xishu);
            cm:apply_custom_effect_bundle_to_faction(effect_bundle_2, current_faction_2)
        end
    end
end

---- 虹 无名众神的公主 ----

function alice_effect_apply_lv100(faction_name)
    local faction = cm:get_faction(faction_name)
    
    local yx_subtype = psw_main_data.player_data[faction_name].yx_subtype
    local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
    advice_alice_3_1()
    cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
        {
        "psw_tf_ex_alice_3"
        }
    )
    psw_add_yctz_effect_to_faction(faction_name, "fyx")
    psw_add_jishu_zhongmo(5)
    
    cm:apply_effect_bundle_to_character("jnz_tf_ex_alice_3", psw_main_character, 0);
    psw_delete_shanbi_effect(faction_name, "shanbi_alice_sjdfz")
    
    psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_alice_3", faction_name)
    
    psw_add_jishu_miansi(faction_name, 3)
    psw_add_hong_count(faction_name, 1)
    
    local effect_bundle = cm:create_new_custom_effect_bundle("psw_bundle_alice_yzdj_lv100")
    effect_bundle:set_duration(0)
    effect_bundle:add_effect("psw_stat_melee_attack_mult_hidden", "faction_to_force_own", xishu);
    cm:apply_custom_effect_bundle_to_faction(effect_bundle, faction)
    alice_effect_apply_lv100_ally(faction_name)
end



------------ 爱丽丝 - 勇者等级变化 - 语音提示 ----------------

function alice_yzjdbh_voice()
    common.trigger_soundevent("alice_bbkb")
    
end

------------ 爱丽丝 - 勇者等级变化 - 觉醒 ----------------

function alice_main_yzdjbh_jx(faction_name)
    if not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_alice_2") then
        return
    end
    if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_alice_3") then
        return
    end
    local faction = cm:get_faction(faction_name)
    local alice_cz1_js = psw_main_data.player_data[faction_name].alice_cz1_js
    local alice_cz2_js = psw_main_data.player_data[faction_name].alice_cz2_js
    local alice_cz3_js = psw_main_data.player_data[faction_name].alice_cz3_js
    local alice_cz4_js = psw_main_data.player_data[faction_name].alice_cz4_js
    local alice_cz5_js = psw_main_data.player_data[faction_name].alice_cz5_js
    local alice_cz6_js = psw_main_data.player_data[faction_name].alice_cz6_js
    local alice_cz7_js = psw_main_data.player_data[faction_name].alice_cz7_js
    
    psw_main_data.player_data[faction_name].alice_main_js = alice_cz1_js + alice_cz2_js + alice_cz3_js + alice_cz4_js + alice_cz5_js + alice_cz6_js + alice_cz7_js
    if psw_main_data.player_data[faction_name].alice_main_js > 100 then
        psw_main_data.player_data[faction_name].alice_main_js = 100
        alice_main_effect_apply(faction_name, psw_main_data.player_data[faction_name].alice_main_js)
        if not psw_faction_has_effect_bundle(faction_name, "set_alice_yzdj_lv100") then
            alice_effect_apply_lv100(faction_name)
            psw_aplly_costom_effect_bundle_hidden_fn("set_alice_yzdj_lv100", faction_name)
            psw_delete_ancillary_with_time_delay(faction, "alice_wjfdsj", 0.1)
            cm:add_ancillary_to_faction(faction, "alice_csdsj", false)
        end
        return
    end
    local alice_main_js = psw_main_data.player_data[faction_name].alice_main_js
    alice_main_effect_apply(faction_name, alice_main_js)
    local yx_subtype = psw_main_data.player_data[faction_name].yx_subtype
    local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
    
    if alice_main_js >= 5 and not psw_faction_has_effect_bundle(faction_name, "set_alice_yzdj_lv5") then
        alice_yzjdbh_voice()
        alice_effect_apply_lv5(faction_name)
        psw_aplly_costom_effect_bundle_hidden_fn("set_alice_yzdj_lv5", faction_name)
        cm:add_ancillary_to_faction(faction, "alice_wjfdsj", false)
        
    elseif alice_main_js >= 10 and not psw_faction_has_effect_bundle(faction_name, "set_alice_yzdj_lv10") then
        alice_yzjdbh_voice()
        alice_effect_apply_lv10(faction_name)
        psw_aplly_costom_effect_bundle_hidden_fn("set_alice_yzdj_lv10", faction_name)
        cm:add_ancillary_to_faction(faction, "alice_hpys", false)
        
    elseif alice_main_js >= 20 and not psw_faction_has_effect_bundle(faction_name, "set_alice_yzdj_lv20") then
        alice_yzjdbh_voice()
        alice_effect_apply_lv20(faction_name)
        psw_aplly_costom_effect_bundle_hidden_fn("set_alice_yzdj_lv20", faction_name)
        cm:add_ancillary_to_faction(faction, "alice_mfys", false)
        
    elseif alice_main_js >= 30 and not psw_faction_has_effect_bundle(faction_name, "set_alice_yzdj_lv30") then
        alice_yzjdbh_voice()
        alice_effect_apply_lv30(faction_name)
        psw_aplly_costom_effect_bundle_hidden_fn("set_alice_yzdj_lv30", faction_name)
        cm:add_ancillary_to_faction(faction, "alice_sszk", false)
        
    elseif alice_main_js >= 40 and not psw_faction_has_effect_bundle(faction_name, "set_alice_yzdj_lv40") then
        alice_yzjdbh_voice()
        alice_effect_apply_lv40(faction_name)
        psw_aplly_costom_effect_bundle_hidden_fn("set_alice_yzdj_lv40", faction_name)
        cm:add_ancillary_to_faction(faction, "alice_yqdmf", false)
        
    elseif alice_main_js >= 50 and not psw_faction_has_effect_bundle(faction_name, "set_alice_yzdj_lv50") then
        alice_yzjdbh_voice()
        alice_effect_apply_lv50(faction_name)
        psw_aplly_costom_effect_bundle_hidden_fn("set_alice_yzdj_lv50", faction_name)
        
    elseif alice_main_js >= 60 and not psw_faction_has_effect_bundle(faction_name, "set_alice_yzdj_lv60") then
        alice_yzjdbh_voice()
        alice_effect_apply_lv60(faction_name)
        psw_aplly_costom_effect_bundle_hidden_fn("set_alice_yzdj_lv60", faction_name)
        cm:add_ancillary_to_faction(faction, "alice_liaoya", false)
        
    elseif alice_main_js >= 70 and not psw_faction_has_effect_bundle(faction_name, "set_alice_yzdj_lv70") then
        alice_yzjdbh_voice()
        alice_effect_apply_lv70(faction_name)
        psw_aplly_costom_effect_bundle_hidden_fn("set_alice_yzdj_lv70", faction_name)
        
    elseif alice_main_js >= 80 and not psw_faction_has_effect_bundle(faction_name, "set_alice_yzdj_lv80") then
        alice_yzjdbh_voice()
        alice_effect_apply_lv80(faction_name)
        psw_aplly_costom_effect_bundle_hidden_fn("set_alice_yzdj_lv80", faction_name)
        cm:add_ancillary_to_faction(faction, "alice_glm", false)
        
    elseif alice_main_js >= 90 and not psw_faction_has_effect_bundle(faction_name, "set_alice_yzdj_lv90") then
        alice_yzjdbh_voice()
        alice_effect_apply_lv90(faction_name)
        psw_aplly_costom_effect_bundle_hidden_fn("set_alice_yzdj_lv90", faction_name)
        cm:add_ancillary_to_faction(faction, "alice_sjdhx", false)
        
    elseif alice_main_js >= 100 and not psw_faction_has_effect_bundle(faction_name, "set_alice_yzdj_lv100") then
        alice_effect_apply_lv100(faction_name)
        psw_aplly_costom_effect_bundle_hidden_fn("set_alice_yzdj_lv100", faction_name)
        psw_delete_ancillary_with_time_delay(faction, "alice_wjfdsj", 0.1)
        cm:add_ancillary_to_faction(faction, "alice_csdsj", false)
    end
end

------------ 爱丽丝 - 成长Ⅰ- 等级升级 -------------

function alice_cz1_djsj()
    core:remove_listener("alice_cz1_djsj")
    core:add_listener(
    "alice_cz1_djsj",
    "CharacterRankUp",
    function(context)
        local character = context:character();
        local faction = character:faction()
        local faction_name = faction:name()
        local faction_leader = faction:faction_leader()
        if faction:is_human() == true and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_alice_2") and character == faction_leader and not psw_faction_has_effect_bundle(faction_name, "alice_cz1_js_sx") then
            return true
        end
    end,
    function(context)
        local character = context:character();
        local faction = character:faction()
        local faction_name = faction:name()
        local rank = character:rank()
        local get_rank = psw_main_data.player_data[faction_name].alice_ledear_rank
        local crt_rank_to_add = rank - get_rank
        local count_to_add = math.floor(crt_rank_to_add/2)
        if count_to_add >= 20 then
            count_to_add = 20
            psw_aplly_costom_effect_bundle_hidden_fn("alice_cz1_js_sx", faction_name)
        end
        
        psw_main_data.player_data[faction_name].alice_cz1_js = crt_rank_to_add
        alice_main_yzdjbh_jx(faction_name)
    end,
    true
    )
end


------------ 爱丽丝 - 成长Ⅱ- 声望提升 -------------

function alice_cz2_swts()
    core:remove_listener("alice_cz2_swts")
    core:add_listener(
    "alice_cz2_swts",
    "BattleCompleted",
    function(context)
        local faction_name = cm:pending_battle_cache_get_attacker_faction_name(1)
        return cm:pending_battle_cache_human_is_involved() and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_alice_2") and not psw_faction_has_effect_bundle(faction_name, "alice_cz2_js_sx")
    end,
    function(context)
        local faction_name = cm:pending_battle_cache_get_attacker_faction_name(1)
        local faction = cm:get_faction(faction_name)
        local bmm_attacker_result = cm:model():pending_battle():attacker_battle_result();
        local bmm_defender_result = cm:model():pending_battle():defender_battle_result();

        if bmm_attacker_result == "close_defeat" and bmm_defender_result == "close_defeat" then
            return;
        elseif bmm_attacker_result == nil or bmm_defender_result == nil then
            return;
        end
        
        local attacker_won = (bmm_attacker_result == "heroic_victory") or (bmm_attacker_result == "decisive_victory") or (bmm_attacker_result == "close_victory") or (bmm_attacker_result == "pyrrhic_victory")
        
        
        if not attacker_won then
            psw_main_data.player_data[faction_name].alice_cz2_win_js = 0
            return
        end
        
        if attacker_won == true then
            psw_main_data.player_data[faction_name].alice_cz2_win_js = psw_main_data.player_data[faction_name].alice_cz2_win_js + 1
        end
        
        if psw_main_data.player_data[faction_name].alice_cz2_win_js >= 5 then
            psw_main_data.player_data[faction_name].alice_cz2_win_js = 0 
            psw_main_data.player_data[faction_name].alice_cz2_js = psw_main_data.player_data[faction_name].alice_cz2_js + 2
            if psw_main_data.player_data[faction_name].alice_cz2_js >= 20 then
                psw_main_data.player_data[faction_name].alice_cz2_js = 20
                psw_aplly_costom_effect_bundle_hidden_fn("alice_cz2_js_sx", faction_name)
            end
        end
        alice_main_yzdjbh_jx(faction_name)
    end,
    true
    )
end


------------ 爱丽丝 - 成长Ⅲ- 工会委托 -------------

function alice_cz3_ghwt()
    core:remove_listener("alice_cz3_ghwt")
    core:add_listener(
        "alice_cz3_ghwt",
        "MissionSucceeded",
        function(context)
            local faction_name = context:faction():name()
            return psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_alice_2") and not psw_faction_has_effect_bundle(faction_name, "alice_cz3_js_sx")
        end,
        function(context)
            local faction_name = context:faction():name()
            
            psw_main_data.player_data[faction_name].alice_cz3_js = psw_main_data.player_data[faction_name].alice_cz3_js + 1
            if psw_main_data.player_data[faction_name].alice_cz3_js >= 20 then
                psw_main_data.player_data[faction_name].alice_cz3_js = 20
                psw_aplly_costom_effect_bundle_hidden_fn("alice_cz3_js_sx", faction_name)
            end
            alice_main_yzdjbh_jx(faction_name)
        end,
        true
    );
end



------------ 爱丽丝 - 成长Ⅳ- 旅途见闻 -------------

function alice_cz4_ltjw()
    core:remove_listener("alice_cz4_ltjw")
	core:add_listener(
	"alice_cz4_ltjw",
	"PositiveDiplomaticEvent",
    function(context)
        local faction_name = context:proposer():name()
        if context:proposer():is_human() == true and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_alice_2") and not psw_faction_has_effect_bundle(faction_name, "alice_cz4_js_sx") then
            return true
        end
    end,
	function(context)
        local faction = context:proposer()
        local faction_name = context:proposer():name()
        local recipient = context:recipient()
        local recipient_name = recipient:name()
        local diplomatic_positive = context:is_non_aggression_pact() or context:is_trade_agreement() or context:is_military_access() or context:is_peace_treaty() or context:is_defensive_alliance() or context:is_military_alliance() or context:is_vassalage()
        
        if not diplomatic_positive then
            return
        end
        
        if not psw_faction_has_effect_bundle(recipient_name, "alice_cz4_get") then
            psw_main_data.player_data[faction_name].alice_cz4_js = psw_main_data.player_data[faction_name].alice_cz4_js + 1
            if psw_main_data.player_data[faction_name].alice_cz4_js >= 20 then
                psw_main_data.player_data[faction_name].alice_cz4_js = 20
                psw_aplly_costom_effect_bundle_hidden_fn("alice_cz4_js_sx", faction_name)
            end
            psw_aplly_costom_effect_bundle_hidden_fn("alice_cz4_get", recipient_name)

            alice_main_yzdjbh_jx(faction_name)
        end
    end,
    true
    )
end


------------ 爱丽丝 - 成长Ⅴ- 副本攻略 -------------

function alice_cz5_fbgl()
    core:remove_listener("alice_cz5_fbgl")
    core:add_listener(
    "alice_cz5_fbgl",
    "BattleCompleted",
    function(context)
        local faction_name = cm:pending_battle_cache_get_attacker_faction_name(1)
        return cm:pending_battle_cache_human_is_involved() and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_alice_2") and not psw_faction_has_effect_bundle(faction_name, "alice_cz5_js_sx")
    end,
    function(context)
        local faction_name = cm:pending_battle_cache_get_attacker_faction_name(1)
        local faction = cm:get_faction(faction_name)
        local bmm_attacker_result = cm:model():pending_battle():attacker_battle_result();
        local bmm_defender_result = cm:model():pending_battle():defender_battle_result();

        if bmm_attacker_result == "close_defeat" and bmm_defender_result == "close_defeat" then
            return;
        elseif bmm_attacker_result == nil or bmm_defender_result == nil then
            return;
        end
        
        local attacker_won = (bmm_attacker_result == "heroic_victory") or (bmm_attacker_result == "decisive_victory") or (bmm_attacker_result == "close_victory") or (bmm_attacker_result == "pyrrhic_victory")
        
        
        if attacker_won then
            psw_main_data.player_data[faction_name].alice_cz5_js = psw_main_data.player_data[faction_name].alice_cz5_js + 1
            if psw_main_data.player_data[faction_name].alice_cz5_js > 20 then
                psw_main_data.player_data[faction_name].alice_cz5_js = 20
                psw_aplly_costom_effect_bundle_hidden_fn("alice_cz5_js_sx", faction_name)
            end
        end
        
        alice_main_yzdjbh_jx(faction_name)
    end,
    true
    )
end


------------ 爱丽丝 - 成长Ⅵ- 讨伐强敌 -------------

function alice_cz6_victory_vs_boss(faction_name, is_legend)
    if psw_faction_has_effect_bundle(faction_name, "alice_cz6_js_sx") then
        return
    end
    if is_legend then
        psw_main_data.player_data[faction_name].alice_cz6_js = psw_main_data.player_data[faction_name].alice_cz6_js + 3
    elseif not is_legend then
        psw_main_data.player_data[faction_name].alice_cz6_js = psw_main_data.player_data[faction_name].alice_cz6_js + 4
    end
    if psw_main_data.player_data[faction_name].alice_cz6_js >= 20 then
        psw_main_data.player_data[faction_name].alice_cz6_js = 20
        psw_aplly_costom_effect_bundle_hidden_fn("alice_cz6_js_sx", faction_name)
    end
    fia_main_jsbh_jx(faction_name)
    alice_main_yzdjbh_jx(faction_name)
end

------ 爱丽丝 HP药水 效果赋予 ------
function alice_daoju_apply_hpys(faction_name, duration)
    
    local faction = cm:get_faction(faction_name)
    local effect_bundle = cm:create_new_custom_effect_bundle("psw_bundle_alice_daoju_hpys")
    effect_bundle:set_duration(duration)
    effect_bundle:add_effect("alice_daoju_hpys", "faction_to_character_own", 1);
    effect_bundle:add_effect("alice_daoju_hpys_ycx", "faction_to_force_own", 1);
    cm:apply_custom_effect_bundle_to_faction(effect_bundle, faction)
    
end

------ 爱丽丝 强化魔法药水 效果赋予 ------
function alice_daoju_apply_mfys(faction_name, duration)
    
    local faction = cm:get_faction(faction_name)
    local effect_bundle = cm:create_new_custom_effect_bundle("psw_bundle_alice_daoju_mfys")
    effect_bundle:set_duration(duration)
    effect_bundle:add_effect("alice_daoju_mfys", "faction_to_character_own", 1);
    effect_bundle:add_effect("alice_daoju_mfys_2", "faction_to_character_own", 1);
    cm:apply_custom_effect_bundle_to_faction(effect_bundle, faction)
end

------ 爱丽丝 神圣之铠 效果赋予 ------
function alice_daoju_apply_sszk(faction_name, duration)
    
    local faction = cm:get_faction(faction_name)
    local effect_bundle = cm:create_new_custom_effect_bundle("psw_bundle_alice_daoju_sszk")
    effect_bundle:set_duration(duration)
    effect_bundle:add_effect("alice_daoju_sszk", "faction_to_force_own", 1);
    cm:apply_custom_effect_bundle_to_faction(effect_bundle, faction)
end

------ 爱丽丝 勇气の魔法 效果赋予 ------
function alice_daoju_apply_yqdmf(faction_name, duration)
    
    local faction = cm:get_faction(faction_name)
    local effect_bundle = cm:create_new_custom_effect_bundle("psw_bundle_alice_daoju_yqdmf")
    effect_bundle:set_duration(duration)
    effect_bundle:add_effect("alice_daoju_yqmf", "faction_to_force_own", 1);
    effect_bundle:add_effect("alice_daoju_yqmf_2", "faction_to_force_own", 1);
    cm:apply_custom_effect_bundle_to_faction(effect_bundle, faction)
end

------ 爱丽丝 巨魔之王的獠牙 效果赋予 ------
function alice_daoju_apply_liaoya(faction_name, duration)
    
    local faction = cm:get_faction(faction_name)
    local effect_bundle = cm:create_new_custom_effect_bundle("psw_bundle_alice_daoju_liaoya")
    effect_bundle:set_duration(duration)
    effect_bundle:add_effect("alice_daoju_liaoya", "faction_to_character_own", 1);
    effect_bundle:add_effect("alice_daoju_liaoya_2", "faction_to_force_own", 1);
    cm:apply_custom_effect_bundle_to_faction(effect_bundle, faction)
end

------ 爱丽丝 特殊载具-哥雷姆 效果赋予 ------
function alice_daoju_apply_glm(faction_name, duration)
    
    local faction = cm:get_faction(faction_name)
    local effect_bundle = cm:create_new_custom_effect_bundle("psw_bundle_alice_daoju_glm")
    effect_bundle:set_duration(duration)
    effect_bundle:add_effect("alice_daoju_glm_1", "faction_to_faction_leader", 1);
    effect_bundle:add_effect("alice_daoju_glm_1_2", "faction_to_force_own", 1);
    cm:apply_custom_effect_bundle_to_faction(effect_bundle, faction)
end

------ 爱丽丝 圣剑の核心 效果赋予 ------
function alice_daoju_apply_sjdhx(faction_name, duration)
    
    local faction = cm:get_faction(faction_name)
    local effect_bundle = cm:create_new_custom_effect_bundle("psw_bundle_alice_daoju_sjhx")
    effect_bundle:set_duration(duration)
    effect_bundle:add_effect("alice_daoju_sjhx", "faction_to_character_own", 1);
    effect_bundle:add_effect("alice_daoju_sjhx_2", "faction_to_force_own", 1);
    cm:apply_custom_effect_bundle_to_faction(effect_bundle, faction)
end

------------ 爱丽丝 - 道具系统 -------------

function alice_main_daoju_system()
    core:remove_listener("alice_main_daoju_system")
    core:add_listener(
    "alice_main_daoju_system",
    "CharacterAncillaryGained",
    function(context)
        return (context:ancillary() == "alice_hpys" or context:ancillary() == "alice_mfys" or context:ancillary() == "alice_sszk" or context:ancillary() == "alice_yqdmf" or context:ancillary() == "alice_liaoya" or context:ancillary() == "alice_glm" or context:ancillary() == "alice_sjdhx")
    end,
    function(context)
        local faction_name = context:character():faction():name()
        local faction = cm:get_faction(faction_name)
        local ancillary = context:ancillary()
        psw_delete_ancillary_with_time_delay(faction, ancillary, 0.1)
        cm:callback(function()
            cm:add_ancillary_to_faction(faction, ancillary, true)
            
            local jzj_sx = 1
            if psw_faction_has_effect_bundle(faction_name, "set_alice_yzdj_lv70") then
                jzj_sx = 2
            end
            if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_alice_3") then
                jzj_sx = 3
            end
            
            if ancillary == "alice_hpys" then
                if faction:has_effect_bundle("psw_bundle_alice_daoju_hpys") then
                    return
                end
                alice_daoju_apply_hpys(faction_name, 0)
                psw_main_data.player_data[faction_name].crt_alice_bundle_jishu = psw_main_data.player_data[faction_name].crt_alice_bundle_jishu + 1
            elseif ancillary == "alice_mfys" then
                if faction:has_effect_bundle("psw_bundle_alice_daoju_mfys") then
                    return
                end
                alice_daoju_apply_mfys(faction_name, 0)
                psw_main_data.player_data[faction_name].crt_alice_bundle_jishu = psw_main_data.player_data[faction_name].crt_alice_bundle_jishu + 1
            elseif ancillary == "alice_sszk" then
                if faction:has_effect_bundle("psw_bundle_alice_daoju_sszk") then
                    return
                end
                alice_daoju_apply_sszk(faction_name, 0)
                psw_main_data.player_data[faction_name].crt_alice_bundle_jishu = psw_main_data.player_data[faction_name].crt_alice_bundle_jishu + 1
            elseif ancillary == "alice_yqdmf" then
                if faction:has_effect_bundle("psw_bundle_alice_daoju_yqdmf") then
                    return
                end
                alice_daoju_apply_yqdmf(faction_name, 0)
                psw_main_data.player_data[faction_name].crt_alice_bundle_jishu = psw_main_data.player_data[faction_name].crt_alice_bundle_jishu + 1
            elseif ancillary == "alice_liaoya" then
                if faction:has_effect_bundle("psw_bundle_alice_daoju_liaoya") then
                    return
                end
                alice_daoju_apply_liaoya(faction_name, 0)
                psw_main_data.player_data[faction_name].crt_alice_bundle_jishu = psw_main_data.player_data[faction_name].crt_alice_bundle_jishu + 1
            elseif ancillary == "alice_glm" then
                if faction:has_effect_bundle("psw_bundle_alice_daoju_glm") then
                    return
                end
                alice_daoju_apply_glm(faction_name, 0)
                psw_main_data.player_data[faction_name].crt_alice_bundle_jishu = psw_main_data.player_data[faction_name].crt_alice_bundle_jishu + 1
            elseif ancillary == "alice_sjdhx" then
                if faction:has_effect_bundle("psw_bundle_alice_daoju_sjhx") then
                    return
                end
                alice_daoju_apply_sjdhx(faction_name, 0)
                psw_main_data.player_data[faction_name].crt_alice_bundle_jishu = psw_main_data.player_data[faction_name].crt_alice_bundle_jishu + 1
            end
            
            if psw_main_data.player_data[faction_name].crt_alice_bundle_jishu > jzj_sx then
                local alice_daoju_bundle_pool = {}
                if not psw_faction_has_effect_bundle(faction_name, "psw_bundle_alice_daoju_hpys_get") then
                    table.insert(alice_daoju_bundle_pool, "psw_bundle_alice_daoju_hpys")
                end
                if not psw_faction_has_effect_bundle(faction_name, "psw_bundle_alice_daoju_mfys_get") then
                    table.insert(alice_daoju_bundle_pool, "psw_bundle_alice_daoju_mfys")
                end
                if not psw_faction_has_effect_bundle(faction_name, "psw_bundle_alice_daoju_sszk_get") then
                    table.insert(alice_daoju_bundle_pool, "psw_bundle_alice_daoju_sszk")
                end
                if not psw_faction_has_effect_bundle(faction_name, "psw_bundle_alice_daoju_yqdmf_get") then
                    table.insert(alice_daoju_bundle_pool, "psw_bundle_alice_daoju_yqdmf")
                end
                if not psw_faction_has_effect_bundle(faction_name, "psw_bundle_alice_daoju_liaoya_get") then
                    table.insert(alice_daoju_bundle_pool, "psw_bundle_alice_daoju_liaoya")
                end
                if not psw_faction_has_effect_bundle(faction_name, "psw_bundle_alice_daoju_glm_get") then
                    table.insert(alice_daoju_bundle_pool, "psw_bundle_alice_daoju_glm")
                end
                if not psw_faction_has_effect_bundle(faction_name, "psw_bundle_alice_daoju_sjhx_get") then
                    table.insert(alice_daoju_bundle_pool, "psw_bundle_alice_daoju_sjhx")
                end
                
                for i = 1, #alice_daoju_bundle_pool do
                    local remove_bundle = alice_daoju_bundle_pool[i]
                    if faction:has_effect_bundle(remove_bundle) then
                        cm:remove_effect_bundle(remove_bundle, faction_name)
                    end
                end
                psw_main_data.player_data[faction_name].crt_alice_bundle_jishu = 0
                advice_alice_daoju_huishou()
            elseif 1 == 1 then
                if ancillary == "alice_hpys" then
                    advice_alice_daoju_hpys()
                elseif ancillary == "alice_mfys" then
                    advice_alice_daoju_mfys()
                elseif ancillary == "alice_sszk" then
                    advice_alice_daoju_sszk()
                elseif ancillary == "alice_yqdmf" then
                    advice_alice_daoju_yqdmf()
                elseif ancillary == "alice_liaoya" then
                    advice_alice_daoju_liaoya()
                elseif ancillary == "alice_glm" then
                    local glm_random = cm:random_number(100, 1)
                    if glm_random <= 50 then
                        advice_alice_daoju_glm_1_ht()
                    elseif glm_random <= 100 and glm_random > 50 then
                        advice_alice_daoju_glm_2_cwml()
                    end
                elseif ancillary == "alice_sjdhx" then
                    local sjhx_random = cm:random_number(100, 1)
                    if sjhx_random <= 50 then
                        advice_alice_daoju_sjhx_1_mbsd()
                    elseif sjhx_random <= 100 and glm_random > 50 then
                        advice_alice_daoju_sjhx_2_hbdy()
                    end
                end
            end
            
        end, 1)
    end,
    true
    )
end


------------ 爱丽丝 - 随机道具赋予 -------------

function alice_random_daoju_apply()
    core:remove_listener("alice_random_daoju_apply")
	core:add_listener(
	"alice_random_daoju_apply",
	"FactionTurnStart",
    function(context)
        local faction_name = context:faction():name()
        local turn = cm:turn_number()
        if turn % 4 == 0 and context:faction():is_human() == true and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_alice_2") and psw_faction_has_effect_bundle(faction_name, "set_alice_yzdj_lv50") then
            return true
        end
    end,
    function(context)
        local faction = context:faction()
        local faction_name = context:faction():name()
        local alice_daoju_bundle_pool = {}
        if not faction:has_effect_bundle("psw_bundle_alice_daoju_hpys") and psw_faction_has_effect_bundle(faction_name, "set_alice_yzdj_lv10") then
            table.insert(alice_daoju_bundle_pool, "psw_bundle_alice_daoju_hpys")
        end
        if not faction:has_effect_bundle("psw_bundle_alice_daoju_mfys") and psw_faction_has_effect_bundle(faction_name, "set_alice_yzdj_lv20") then
            table.insert(alice_daoju_bundle_pool, "psw_bundle_alice_daoju_mfys")
        end
        if not faction:has_effect_bundle("psw_bundle_alice_daoju_sszk") and psw_faction_has_effect_bundle(faction_name, "set_alice_yzdj_lv30") then
            table.insert(alice_daoju_bundle_pool, "psw_bundle_alice_daoju_sszk")
        end
        if not faction:has_effect_bundle("psw_bundle_alice_daoju_yqdmf") and psw_faction_has_effect_bundle(faction_name, "set_alice_yzdj_lv40") then
            table.insert(alice_daoju_bundle_pool, "psw_bundle_alice_daoju_yqdmf")
        end
        if not faction:has_effect_bundle("psw_bundle_alice_daoju_liaoya") and psw_faction_has_effect_bundle(faction_name, "set_alice_yzdj_lv60") then
            table.insert(alice_daoju_bundle_pool, "psw_bundle_alice_daoju_liaoya")
        end
        if not faction:has_effect_bundle("psw_bundle_alice_daoju_glm") and psw_faction_has_effect_bundle(faction_name, "set_alice_yzdj_lv80") then
            table.insert(alice_daoju_bundle_pool, "psw_bundle_alice_daoju_glm")
        end
        if not faction:has_effect_bundle("psw_bundle_alice_daoju_sjhx") and psw_faction_has_effect_bundle(faction_name, "set_alice_yzdj_lv90") then
            table.insert(alice_daoju_bundle_pool, "psw_bundle_alice_daoju_sjhx")
        end
        local index = cm:random_number(#alice_daoju_bundle_pool)
        local random_daoju
        random_daoju = alice_daoju_bundle_pool[index]
        
        cm:remove_effect_bundle("psw_bundle_alice_daoju_hpys_get", faction_name)
        cm:remove_effect_bundle("psw_bundle_alice_daoju_mfys_get", faction_name)
        cm:remove_effect_bundle("psw_bundle_alice_daoju_sszk_get", faction_name)
        cm:remove_effect_bundle("psw_bundle_alice_daoju_yqdmf_get", faction_name)
        cm:remove_effect_bundle("psw_bundle_alice_daoju_liaoya_get", faction_name)
        cm:remove_effect_bundle("psw_bundle_alice_daoju_glm_get", faction_name)
        cm:remove_effect_bundle("psw_bundle_alice_daoju_sjhx_get", faction_name)
        if random_daoju == "psw_bundle_alice_daoju_hpys" then
            alice_daoju_apply_hpys(faction_name, 5)
            cm:callback(function()
                advice_alice_daoju_hpys()
            end, 12)
            psw_aplly_costom_effect_bundle_hidden_fn("psw_bundle_alice_daoju_hpys_get", faction_name)
        elseif random_daoju == "psw_bundle_alice_daoju_mfys" then
            alice_daoju_apply_mfys(faction_name, 5)
            cm:callback(function()
                advice_alice_daoju_mfys()
            end, 12)
            psw_aplly_costom_effect_bundle_hidden_fn("psw_bundle_alice_daoju_mfys_get", faction_name)
        elseif random_daoju == "psw_bundle_alice_daoju_sszk" then
            alice_daoju_apply_sszk(faction_name, 5)
            cm:callback(function()
                advice_alice_daoju_sszk()
            end, 12)
            psw_aplly_costom_effect_bundle_hidden_fn("psw_bundle_alice_daoju_sszk_get", faction_name)
        elseif random_daoju == "psw_bundle_alice_daoju_yqdmf" then
            alice_daoju_apply_yqdmf(faction_name, 5)
            cm:callback(function()
                advice_alice_daoju_yqdmf()
            end, 12)
            psw_aplly_costom_effect_bundle_hidden_fn("psw_bundle_alice_daoju_yqdmf_get", faction_name)
        elseif random_daoju == "psw_bundle_alice_daoju_liaoya" then
            alice_daoju_apply_liaoya(faction_name, 5)
            cm:callback(function()
                advice_alice_daoju_liaoya()
            end, 12)
            psw_aplly_costom_effect_bundle_hidden_fn("psw_bundle_alice_daoju_liaoya_get", faction_name)
        elseif random_daoju == "psw_bundle_alice_daoju_glm" then
            alice_daoju_apply_glm(faction_name, 5)
            cm:callback(function()
                advice_alice_daoju_glm_2_cwml()
            end, 12)
            psw_aplly_costom_effect_bundle_hidden_fn("psw_bundle_alice_daoju_glm_get", faction_name)
        elseif random_daoju == "psw_bundle_alice_daoju_sjhx" then
            alice_daoju_apply_sjdhx(faction_name, 5)
            cm:callback(function()
                advice_alice_daoju_sjhx_1_mbsd()
            end, 12)
            psw_aplly_costom_effect_bundle_hidden_fn("psw_bundle_alice_daoju_sjhx_get", faction_name)
        end

        
    end,
    true
    )
end



        
------------ 彼岸双生-人格切换 ----------------

function bass_rgqh()
    core:remove_listener("bass_rgqh")
	core:add_listener(
	"bass_rgqh",
	"FactionTurnStart",
    function(context)
        local turn_number = cm:turn_number()
        local faction_name = context:faction():name()

        if context:faction():is_human() == true and turn_number % 5 == 0 and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_bass_1") then
            return true
        end
    end,
	function(context)
        local faction = context:faction()
        
        local faction_name = context:faction():name()
        local yx_subtype = psw_main_data.player_data[faction_name].yx_subtype
        local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
        local bass_rgqh_li = psw_main_data.player_data[faction_name].bass_rgqh_li
        local bass_sfjx = psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_bass_2") or false
        local bass_zdqh_rg = psw_main_data.player_data[faction_name].bass_zdqh_rg
        if bass_rgqh_li == 0 and not bass_sfjx then
            
            local random_number_bass_rgqh_face = cm:random_number(100, 1)
            local bass_rgqh_gailv = 50
            if random_number_bass_rgqh_face >= bass_rgqh_gailv then
                cm:callback(function()
                    common.trigger_soundevent("bass_rgqh_li1")
                    advice_bass_rgqh_li_1_1()
                end, 9)
            elseif random_number_bass_rgqh_face < bass_rgqh_gailv then
                cm:callback(function()
                    common.trigger_soundevent("bass_rgqh_li2")
                    advice_bass_rgqh_li_2_1()
                end, 9)
            end
            
            cm:remove_effect_bundle_from_character("jnz_tf_psw_tf_ex_bass_1_b", psw_main_character);
            cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_ex_bass_1_l", psw_main_character, 0);
            psw_add_jishu_shenxing(faction_name, 1)
            
            psw_main_data.player_data[faction_name].bass_jxcs = psw_main_data.player_data[faction_name].bass_jxcs + 1
            psw_main_data.player_data[faction_name].bass_rgqh_li = 1
        elseif bass_rgqh_li == 1 and not bass_sfjx then
            
            local random_number_bass_rgqh_face = cm:random_number(100, 1)
            local bass_rgqh_gailv = 50
            if random_number_bass_rgqh_face >= bass_rgqh_gailv then
                cm:callback(function()
                    common.trigger_soundevent("bass_rgqh_b1")
                    advice_bass_rgqh_b_1()
                end, 9)
            elseif random_number_bass_rgqh_face < bass_rgqh_gailv then
                cm:callback(function()
                    common.trigger_soundevent("bass_rgqh_b2")
                    advice_bass_rgqh_b_2()
                end, 9)
            end
            
            cm:remove_effect_bundle_from_character("jnz_tf_psw_tf_ex_bass_1_l", psw_main_character);
            cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_ex_bass_1_b", psw_main_character, 0);
            psw_add_jishu_shenxing(faction_name, -1)
            
            psw_main_data.player_data[faction_name].bass_rgqh_li = 0
        elseif bass_rgqh_li == 0 and bass_sfjx then
            
            local random_number_bass_rgqh_face = cm:random_number(100, 1)
            local bass_rgqh_gailv = 50
            if random_number_bass_rgqh_face >= bass_rgqh_gailv then
                cm:callback(function()
                    common.trigger_soundevent("bass_rgqh_li1")
                    advice_bass_rgqh_li_1_1()
                end, 9)
            elseif random_number_bass_rgqh_face < bass_rgqh_gailv then
                cm:callback(function()
                    common.trigger_soundevent("bass_rgqh_li2")
                    advice_bass_rgqh_li_2_1()
                end, 9)
            end
            
            cm:remove_effect_bundle_from_character("jnz_tf_psw_tf_ex_bass_2_b", psw_main_character);
            cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_ex_bass_2_l", psw_main_character, 0);
            psw_add_jishu_shenxing(faction_name, 1)
            
            
            psw_main_data.player_data[faction_name].bass_zdqh_rg = psw_main_data.player_data[faction_name].bass_zdqh_rg + 1
            psw_main_data.player_data[faction_name].bass_rgqh_li = 1
        elseif bass_rgqh_li == 1 and bass_sfjx then
            
            local random_number_bass_rgqh_face = cm:random_number(100, 1)
            local bass_rgqh_gailv = 50
            if random_number_bass_rgqh_face >= bass_rgqh_gailv then
                cm:callback(function()
                    common.trigger_soundevent("bass_rgqh_b1")
                    advice_bass_rgqh_b_1()
                end, 9)
            elseif random_number_bass_rgqh_face < bass_rgqh_gailv then
                cm:callback(function()
                    common.trigger_soundevent("bass_rgqh_b2")
                    advice_bass_rgqh_b_2()
                end, 9)
            end
            
            cm:remove_effect_bundle_from_character("jnz_tf_psw_tf_ex_bass_2_l", psw_main_character);
            cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_ex_bass_2_b", psw_main_character, 0);
            psw_add_jishu_shenxing(faction_name, -1)
            
            psw_main_data.player_data[faction_name].bass_rgqh_li = 0
            psw_main_data.player_data[faction_name].bass_zdqh_rg = psw_main_data.player_data[faction_name].bass_zdqh_rg + 1
        end
        
	end,
	true
	)
end


------------ 彼岸双生-里人格主动切换 ----------------
function bass_qh_lrg()
    core:remove_listener("bass_qh_lrg")
    core:add_listener(
    "bass_qh_lrg",
    "CharacterAncillaryGained",
    function(context)
        local faction_name = context:character():faction():name()
    local bass_zdqh_rg=(psw_main_data.player_data[faction_name]or{}).bass_zdqh_rg
    local bass_rgqh_li=(psw_main_data.player_data[faction_name]or{}).bass_rgqh_li
        return psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_bass_1") and context:ancillary() == "bass_bazf" and bass_zdqh_rg >= 3 and bass_rgqh_li == 0
    end,
    function(context)
        local faction_name = context:character():faction():name()
        local faction = context:character():faction()
    local yx_subtype=(psw_main_data.player_data[faction_name]or{}).yx_subtype
        local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
        
        local random_number_bass_rgqh_face = cm:random_number(100, 1)
        local bass_rgqh_gailv = 50
        if random_number_bass_rgqh_face >= bass_rgqh_gailv then
            common.trigger_soundevent("bass_rgqh_li1")
            advice_bass_rgqh_li_1_1()
        elseif random_number_bass_rgqh_face < bass_rgqh_gailv then
            common.trigger_soundevent("bass_rgqh_li2")
            advice_bass_rgqh_li_2_1()
        end
        
        cm:remove_effect_bundle_from_character("jnz_tf_psw_tf_ex_bass_2_b", psw_main_character);
        cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_ex_bass_2_l", psw_main_character, 0);
        psw_add_jishu_shenxing(faction_name, 1)
        
        psw_main_data.player_data[faction_name].bass_rgqh_li = 1
        psw_main_data.player_data[faction_name].bass_zdqh_rg = 0
    end,
    true
    );
end

------------ 爱蜜莉雅 - 轮回计数提示 ----------------

function amly_main_effect_xianshi(faction_name, alice_main_js)
    local faction = cm:get_faction(faction_name)
    local yx_subtype = psw_main_data.player_data[faction_name].yx_subtype
    local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
    
    local xingyun_bundle = "amly_lhcs_"
    local final_bundle = "amly_lhcs_15"
    
    if alice_main_js <= 0 then
        return
    end
    if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_amly_2") then
        if psw_main_character:has_effect_bundle(final_bundle) then
            cm:remove_effect_bundle_from_character(final_bundle, psw_main_character)
        end
        return
    end

    for i = 1, 15 do
        local bundle = xingyun_bundle .. i
        cm:remove_effect_bundle_from_character(bundle, psw_main_character)
        if alice_main_js > 15 then
            cm:apply_effect_bundle_to_character(final_bundle, psw_main_character, 0)     
        elseif alice_main_js == i then
            cm:apply_effect_bundle_to_character(bundle, psw_main_character, 0)
        end
    end
end

------------ 冰结の魔女 从零开始计数 回合 ----------------

function bjmn_clks_jishu_hh()
    core:remove_listener("bjmn_clks_jishu_hh")
	core:add_listener(
	"bjmn_clks_jishu_hh",
	"FactionTurnStart",
    function(context)
        
        local faction_name = context:faction():name()

        if context:faction():is_human() == true and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_amly_1") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_amly_3") then
            return true
        end
    end,
	function(context)
        local faction_name = context:faction():name()
        local faction = context:faction()
        local yx_subtype = psw_main_data.player_data[faction_name].yx_subtype
        local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
        local psw_moli = faction:pooled_resource_manager():resource("psw_moli"):value()
        
        ------从零开始计数-----
        local jishu_add_num = 1
        if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_emt") then
            jishu_add_num = 2
        end
        
        psw_main_data.player_data[faction_name].amly_clks_jishu = psw_main_data.player_data[faction_name].amly_clks_jishu + jishu_add_num
        local amly_clks_jishu = psw_main_data.player_data[faction_name].amly_clks_jishu
        amly_main_effect_xianshi(faction_name, amly_clks_jishu)
        
        ------微精灵亲和------
        local wjlqh_gailv = (psw_moli*4)
        local random_number_face = cm:random_number(100, 1)
        local wjlqh_jnz_poor = {
        "jnz_ex_amly_senjl",
        "jnz_ex_amly_guangjl",
        "jnz_ex_amly_yaojl",
        "jnz_ex_amly_anjl",
        "jnz_ex_amly_fengjl",
        "jnz_ex_amly_huojingl",
        "jnz_ex_amly_shuijl",
        "jnz_ex_amly_dijingl"
        }
        local index = cm:random_number(#wjlqh_jnz_poor)
        local wjlqh_jnz_cur = wjlqh_jnz_poor[index]
        if random_number_face <= wjlqh_gailv or psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_emt") then
            cm:callback(function()
                advice_amly_wjlcf()
            end, 10)
            cm:apply_effect_bundle(wjlqh_jnz_cur, faction_name, 6);
            if wjlqh_jnz_cur == "jnz_ex_amly_yaojl" and not psw_faction_has_effect_bundle(faction_name, "set_amly_yjqh") then
                psw_add_jishu_xingyun(faction_name, 2)
                psw_aplly_costom_effect_bundle_hidden_fn("set_amly_yjqh", faction_name)
            end
        end
        if psw_faction_has_effect_bundle(faction_name, "set_amly_yjqh") then
            psw_main_data.player_data[faction_name].amly_yjqh_jishu_hh = psw_main_data.player_data[faction_name].amly_yjqh_jishu_hh - 1
            if psw_main_data.player_data[faction_name].amly_yjqh_jishu_hh == 0 then
                psw_main_data.player_data[faction_name].amly_yjqh_jishu_hh = 5
                psw_add_jishu_xingyun(faction_name, -2)
                cm:remove_effect_bundle("set_amly_yjqh", faction_name)
            end
        end
    end,
    true
    );
end
    

        
------------ 25回合 祈愿天赋/装备 结束存储变量 ----------------

function qy_25hh_tf_zb_end()
    core:remove_listener("qy_25hh_tf_zb_end")
	core:add_listener(
	"qy_25hh_tf_zb_end",
	"FactionTurnEnd",
    function(context)
        
        local faction_name = context:faction():name()
        local turn_number = cm:turn_number()
        if context:faction():is_human() == true and psw_faction_has_effect_bundle(faction_name, "set_qy_tf_zb_xz") and turn_number >= 20 then
            return true
        end
    end,
	function(context)
        local faction_name = context:faction():name()
        cm:remove_effect_bundle("set_qy_tf_zb_xz", faction_name)
        cm:remove_effect_bundle("set_25hh_qy_zb", faction_name)
        cm:set_saved_value("psw_25hh_qy_zb_xz_" .. faction_name, false)
        
    end,
    true
    );
end




















------------ 游戏王抽卡 结束存储变量 ----------------

function psw_yqdjb_chouka_hh_end()
    core:remove_listener("psw_yqdjb_chouka_hh_end")
	core:add_listener(
	"psw_yqdjb_chouka_hh_end",
	"FactionTurnEnd",
    function(context)
        
        local faction_name = context:faction():name()
        if context:faction():is_human() == true and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yqdjb_nor1") and psw_faction_has_effect_bundle(faction_name, "set_yqdjb_yichouka") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_yqdjb_nor2") then
            return true
        end
    end,
	function(context)
        local faction_name = context:faction():name()
        cm:remove_effect_bundle("set_yqdjb_yichouka", faction_name)
        
    end,
    true
    );
end

------------ 与游戏之神的对弈 结束存储变量 ----------------

function psw_ybbb_xuyuan_hh_end()
    core:remove_listener("psw_ybbb_xuyuan_hh_end")
	core:add_listener(
	"psw_ybbb_xuyuan_hh_end",
	"FactionTurnEnd",
    function(context)
        
        local faction_name = context:faction():name()
        if context:faction():is_human() == true and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_ybbb_3") and psw_faction_has_effect_bundle(faction_name, "set_ybbb_xuyuan") then
            return true
        end
    end,
	function(context)
        local faction_name = context:faction():name()
        cm:remove_effect_bundle("set_ybbb_xuyuan", faction_name)
        
    end,
    true
    );
end





------------ 星神的记忆 计数 ----------------

function xsdjy_hh_jishu()
    core:remove_listener("xsdjy_hh_jishu")
	core:add_listener(
	"xsdjy_hh_jishu",
	"FactionTurnStart",
    function(context)
        
        local faction_name = context:faction():name()

        if context:faction():is_human() == true and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_xsdjy_nor1") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_xsdjy_nor2") then
            return true
        end
    end,
	function(context)
        local faction_name = context:faction():name()
        local faction = context:faction()
        local yx_subtype = psw_main_data.player_data[faction_name].yx_subtype
        local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
        psw_main_data.player_data[faction_name].jishu_xsdjy_hh = psw_main_data.player_data[faction_name].jishu_xsdjy_hh + 1
        if psw_main_data.player_data[faction_name].jishu_xsdjy_hh >= 5 and not psw_faction_has_effect_bundle(faction_name, "xsdjy_jishu_10") then
            psw_add_jishu_shenxing(faction_name, 1)
            psw_aplly_costom_effect_bundle_hidden_fn("xsdjy_jishu_10", faction_name)
        end
        if psw_main_data.player_data[faction_name].jishu_xsdjy_hh >= 15 and not psw_faction_has_effect_bundle(faction_name, "xsdjy_jishu_20") then
            psw_add_jishu_shenxing(faction_name, 1)
            psw_aplly_costom_effect_bundle_hidden_fn("xsdjy_jishu_20", faction_name)
        end
        
    end,
    true
    );
end



------------ 暗之书意志 记忆值 ----------------

function azsyz_mlxs_jiyizhi()
    core:remove_listener("azsyz_mlxs_jiyizhi")
	core:add_listener(
	"azsyz_mlxs_jiyizhi",
	"FactionTurnStart",
    function(context)
        local faction_name = context:faction():name()
        if context:faction():is_human() == true and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_azsyz_1") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_azsyz_2") and not psw_faction_has_effect_bundle(faction_name, "azsyz_yizihui") then
            return true
        end
    end,
	function(context)
        local faction_name = context:faction():name()
        local faction = context:faction()
        local yx_subtype = psw_main_data.player_data[faction_name].yx_subtype
        local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
        local faction_leader = faction:faction_leader()
        local mf = faction_leader:military_force();
        local winds_of_magic = mf:pooled_resource_manager():resource("wh3_main_winds_of_magic");
        
        if winds_of_magic:value() < 30 and not psw_faction_has_effect_bundle(faction_name, "azsyz_yixishou") then
            psw_main_data.player_data[faction_name].azsyz_zihui_jishu = psw_main_data.player_data[faction_name].azsyz_zihui_jishu + 1
        elseif winds_of_magic:value() >= 30 and winds_of_magic:value() < 100 then
            if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yrhtdsj_nor") then
                psw_main_data.player_data[faction_name].azsyz_jiyizhi = psw_main_data.player_data[faction_name].azsyz_jiyizhi + 160
            elseif not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yrhtdsj_nor") then
                psw_main_data.player_data[faction_name].azsyz_jiyizhi = psw_main_data.player_data[faction_name].azsyz_jiyizhi + 80
            end
        elseif winds_of_magic:value() >= 100 then
            if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yrhtdsj_nor") then
                psw_main_data.player_data[faction_name].azsyz_jiyizhi = psw_main_data.player_data[faction_name].azsyz_jiyizhi + 240
            elseif not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yrhtdsj_nor") then
                psw_main_data.player_data[faction_name].azsyz_jiyizhi = psw_main_data.player_data[faction_name].azsyz_jiyizhi + 120
            end
        end
        if psw_main_data.player_data[faction_name].azsyz_zihui_jishu >= 10 then
            advice_azsyz_zihui()
            
            cm:remove_effect_bundle_from_character("jnz_tf_ex_psw_tf_ex_azsyz_1", psw_main_character);
            cm:apply_effect_bundle_to_character("jnz_tf_ex_azsyz_zihui", psw_main_character, 0);
            psw_aplly_costom_effect_bundle_hidden_fn("azsyz_yizihui", faction_name)
        end
        
        if (psw_main_data.player_data[faction_name].azsyz_jiyizhi >= 1200 or psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_fia_3")) and not psw_faction_has_effect_bundle(faction_name, "azsyz_yixishou") then
            advice_azsyz_wanbi()
            cm:add_ancillary_to_faction(faction, "azsyz_ytzmds", false)
            cm:remove_effect_bundle_from_character("jnz_tf_ex_psw_tf_ex_azsyz_1", psw_main_character);
            psw_aplly_costom_effect_bundle_hidden_fn("azsyz_yixishou", faction_name)
        end
        
	end,
	true
	)
end



------ 暗之书意志 觉醒--------

function azsyz_mlxs_jx()
    core:remove_listener("azsyz_mlxs_jx")
    core:add_listener(
    "azsyz_mlxs_jx",
    "CharacterAncillaryGained",
    function(context)
        local faction_name = context:character():faction():name()
        return psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_azsyz_1") and context:ancillary() == "azsyz_ytzmds" and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_azsyz_2") and not psw_faction_has_effect_bundle(faction_name, "azsyz_yizihui")
    end,
    function(context)
        local faction_name = context:character():faction():name()
        local faction = context:character():faction()
        if not psw_main_data.player_data[faction_name] then
            return
        end
        local prm = faction:pooled_resource_manager()
        local res_mfs = prm and prm:resource("jishu_mofashaonv")
        local res_moli = prm and prm:resource("psw_moli")
        if not (res_mfs and res_mfs.value and res_moli and res_moli.value) then
            return
        end
        local jishu_mofashaonv =  res_mfs:value()
        local psw_moli =  res_moli:value()
        local yx_subtype = psw_main_data.player_data[faction_name].yx_subtype
        local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
        if jishu_mofashaonv >= 3 and psw_moli >= 10 then
        
            common.trigger_soundevent("azsyz_3")
            advice_psw_tf_ex_azsyz_3_1()
            
            cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                {
                "psw_tf_ex_azsyz_3"
                }
            )
                    
            cm:apply_effect_bundle_to_character("jnz_tf_ex_psw_tf_ex_azsyz_3", psw_main_character, 0); 
            psw_add_jishu_moli(faction_name, 5)
            psw_add_jishu_zhongmo(5)
            psw_add_jishu_miansi(faction_name, 3)
            
            psw_add_hong_count(faction_name, 1)
            
            psw_delete_shanbi_effect(faction_name, "jn_shanbi_azsyz_fxfy")
                    
            psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_azsyz_3", faction_name)
            psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_azsyz_2", faction_name)
        elseif 1 == 1 then
            
            common.trigger_soundevent("azsyz_2")
            cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                {
                "psw_tf_ex_azsyz_2"
                }
            )
            
            psw_add_jishu_miansi(faction_name, 1)
            
            cm:apply_effect_bundle_to_character("jnz_tf_ex_psw_tf_ex_azsyz_2", psw_main_character, 0);
                    
            psw_add_jishu_moli(faction_name, 5)
                    
            psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_azsyz_2", faction_name)
        end

    end,
	true
	)
end



------ 二阶堂真红 记忆值变化 --------

function ejtzh_jyzbh_hh()
    core:remove_listener("ejtzh_jyzbh_hh")
	core:add_listener(
	"ejtzh_jyzbh_hh",
	"FactionTurnStart",
    function(context)
        local faction_name = context:faction():name()
        if context:faction():is_human() == true and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_btmmfs_1") and not psw_faction_has_effect_bundle(faction_name, "set_btmmfs_yixiaoshi") then
            return true
        end
    end,
	function(context)
        local faction_name = context:faction():name()
        local faction = context:faction()
        
        if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_btmmfs_1") and not faction:has_effect_bundle("set_psw_tf_ex_btmmfs_2") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_btmmfs_3") and not psw_faction_has_effect_bundle(faction_name, "set_btmmfs_yixiaoshi") then
            psw_main_data.player_data[faction_name].ejtzh_jiyizhi = psw_main_data.player_data[faction_name].ejtzh_jiyizhi - 2
            if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yrhtdsj_nor") then
                psw_main_data.player_data[faction_name].ejtzh_jiyizhi = psw_main_data.player_data[faction_name].ejtzh_jiyizhi + 2
            end
            
        elseif faction:has_effect_bundle("set_psw_tf_ex_btmmfs_2") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_btmmfs_3") then
            if not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yrhtdsj_nor") then
                psw_main_data.player_data[faction_name].ejtzh_jiyizhi = psw_main_data.player_data[faction_name].ejtzh_jiyizhi + 10
            elseif psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yrhtdsj_nor") then
                psw_main_data.player_data[faction_name].ejtzh_jiyizhi = psw_main_data.player_data[faction_name].ejtzh_jiyizhi + 20
            end
        elseif psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_btmmfs_3") then
            if not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yrhtdsj_nor") then
                psw_main_data.player_data[faction_name].ejtzh_jiyizhi = psw_main_data.player_data[faction_name].ejtzh_jiyizhi + 15
            elseif psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yrhtdsj_nor") then
                psw_main_data.player_data[faction_name].ejtzh_jiyizhi = psw_main_data.player_data[faction_name].ejtzh_jiyizhi + 30
            end
        
        end
        
        
        
        psw_hh_start_btmmfs(faction_name)
        psw_ejtzh_main_jyz(faction)
    end,
	true
	)
end 
        
        
        
        
        
        
        
------ 永不败北 外交权重相关 --------

function ybbb_diplomatic_quanzhong()
    core:remove_listener("ybbb_diplomatic_quanzhong")
	core:add_listener(
	"ybbb_diplomatic_quanzhong",
	"PositiveDiplomaticEvent",
    function(context)
        local faction = context:proposer()
        local recipient = context:recipient()
        local faction_name = context:proposer():name()
        
        if context:proposer():is_human() == true and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_ybbb_1") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_ybbb_3") then
            return true
        end
    end,
	function(context)
        local faction = context:proposer()
        local faction_name = context:proposer():name()
        local yx_subtype = psw_main_data.player_data[faction_name].yx_subtype
        local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
        
        local recipient = context:recipient()
        local recipient_culture = recipient:culture()
        local ybbb_diploma_qz = cm:get_saved_value(recipient_culture .. "ybbb_diploma_qz") or 0
        local ybbb_battle_qz = cm:get_saved_value(recipient_culture .. "ybbb_battle_qz") or 0
        
        ---种族棋子 种族相关
        
        local culture_wang = (recipient_culture == "wh_main_emp_empire" or recipient_culture == "wh_main_brt_bretonnia" or recipient_culture == "wh3_main_cth_cathay" or recipient_culture == "wh_dlc08_nor_norsca" or recipient_culture == "wh3_main_ksl_kislev" or recipient_culture == "wh_main_chs_chaos")
        
        local culture_hou = recipient_culture == "wh2_main_hef_high_elves"
        
        local culture_xiang = (recipient_culture == "wh3_main_cth_cathay" or recipient_culture == "wh3_dlc23_chd_chaos_dwarfs" or recipient_culture == "wh_main_dwf_dwarfs")
        
        local culture_ma = (recipient_culture == "wh3_main_kho_khorne" or recipient_culture == "wh3_main_nur_nurgle" or recipient_culture == "wh3_main_sla_slaanesh" or recipient_culture == "wh3_main_tze_tzeentch" or recipient_culture == "wh3_main_dae_daemons")
        
        local culture_che = (recipient_culture == "wh3_main_ogr_ogre_kingdoms" or recipient_culture == "wh_dlc05_wef_wood_elves")
        
        local culture_bing = (recipient_culture == "wh2_main_hef_high_elves" or recipient_culture == "wh2_main_def_dark_elves" or recipient_culture == "wh_dlc05_wef_wood_elves" or recipient_culture == "wh_dlc03_bst_beastmen" or recipient_culture == "wh2_main_skv_skaven" or recipient_culture == "wh_main_vmp_vampire_counts" or recipient_culture == "wh2_dlc11_cst_vampire_coast" or recipient_culture == "wh2_main_lzd_lizardmen" or recipient_culture == "wh_main_grn_greenskins" or recipient_culture == "wh2_dlc09_tmb_tomb_kings")
        
        ----
        
        if context:is_non_aggression_pact() or context:is_trade_agreement() or context:is_military_access() or context:is_peace_treaty() then
            if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yxsldff_nor") then
                ybbb_diploma_qz = ybbb_diploma_qz + 10
                ybbb_battle_qz = ybbb_battle_qz - 10
            elseif 1 == 1 then
                ybbb_diploma_qz = ybbb_diploma_qz + 5
                ybbb_battle_qz = ybbb_battle_qz - 5
            end
            
        elseif context:is_defensive_alliance() or context:is_military_alliance() or context:is_vassalage() then
            if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yxsldff_nor") then
                ybbb_diploma_qz = ybbb_diploma_qz + 20
                ybbb_battle_qz = ybbb_battle_qz - 20
            elseif 1 == 1 then
                ybbb_diploma_qz = ybbb_diploma_qz + 10
                ybbb_battle_qz = ybbb_battle_qz - 10
            end
        end
        
        ---- 种族棋子 效果赋予 ----
        if culture_wang and not psw_faction_has_effect_bundle(faction_name, "ybbb_zzqz_wang_get") then
            if ybbb_diploma_qz >= 100 then
                local ybbb_qizi_voice_randon = cm:random_number(100, 1)
                if ybbb_qizi_voice_randon >= 50 then
                    common.trigger_soundevent("ybbb_zzqz_1")
                    advice_ybbb_zzqz_1()
                elseif 1 == 1 then
                    common.trigger_soundevent("ybbb_zzqz_2")
                    advice_ybbb_zzqz_2()
                end
                psw_add_jishu_zhixing(faction_name, 1)
                cm:apply_effect_bundle(recipient_culture .. "_ybbb_zzqz", faction_name, 0)
                cm:apply_effect_bundle_to_character("jnz_tf_ex_ybbb_wang", psw_main_character, 0);
                psw_aplly_costom_effect_bundle_hidden_fn("ybbb_zzqz_wang_get", faction_name)
                if not faction:has_effect_bundle("set_ex_shangxian") then
                    psw_add_jishu_ex_count(faction_name, -1)
                    psw_aplly_costom_effect_bundle_hidden("set_ex_shangxian", faction)
                end
            end
        end
        
        
        if culture_hou and not psw_faction_has_effect_bundle(faction_name, "ybbb_zzqz_hou_get") then
            if ybbb_diploma_qz >= 100 then
                local ybbb_qizi_voice_randon_hou = cm:random_number(100, 1)
                if ybbb_qizi_voice_randon_hou >= 50 then
                    common.trigger_soundevent("ybbb_zzqz_1")
                    advice_ybbb_zzqz_1()
                elseif 1 == 1 then
                    common.trigger_soundevent("ybbb_zzqz_2")
                    advice_ybbb_zzqz_2()
                end
                psw_add_jishu_zhixing(faction_name, 1)
                cm:apply_effect_bundle(recipient_culture .. "_ybbb_zzqz", faction_name, 0)
                cm:apply_effect_bundle_to_character("jnz_tf_ex_ybbb_hou", psw_main_character, 0);
                psw_aplly_costom_effect_bundle_hidden_fn("ybbb_zzqz_hou_get", faction_name)
            end
        end
        
        if culture_xiang and not psw_faction_has_effect_bundle(faction_name, "ybbb_zzqz_xiang_get") then
            if ybbb_diploma_qz >= 100 then
                local ybbb_qizi_voice_randon_xiang = cm:random_number(100, 1)
                if ybbb_qizi_voice_randon_xiang >= 50 then
                    common.trigger_soundevent("ybbb_zzqz_1")
                    advice_ybbb_zzqz_1()
                elseif 1 == 1 then
                    common.trigger_soundevent("ybbb_zzqz_2")
                    advice_ybbb_zzqz_2()
                end
                psw_add_jishu_zhixing(faction_name, 1)
                cm:apply_effect_bundle(recipient_culture .. "_ybbb_zzqz", faction_name, 0)
                cm:apply_effect_bundle_to_character("jnz_tf_ex_ybbb_xiang", psw_main_character, 0);
                psw_add_jishu_miansi(faction_name, 1)
                psw_aplly_costom_effect_bundle_hidden_fn("ybbb_zzqz_xiang_get", faction_name)
            end
        end
        
        if culture_ma and not psw_faction_has_effect_bundle(faction_name, "ybbb_zzqz_ma_get") then
            if ybbb_diploma_qz >= 100 then
                local ybbb_qizi_voice_randon_ma = cm:random_number(100, 1)
                if ybbb_qizi_voice_randon_ma >= 50 then
                    common.trigger_soundevent("ybbb_zzqz_1")
                    advice_ybbb_zzqz_1()
                elseif 1 == 1 then
                    common.trigger_soundevent("ybbb_zzqz_2")
                    advice_ybbb_zzqz_2()
                end
                psw_add_jishu_zhixing(faction_name, 1)
                cm:apply_effect_bundle(recipient_culture .. "_ybbb_zzqz", faction_name, 0)
                cm:apply_effect_bundle_to_character("jnz_tf_ex_ybbb_ma", psw_main_character, 0);
                psw_aplly_costom_effect_bundle_hidden_fn("ybbb_zzqz_ma_get", faction_name)
                psw_add_jishu_shenxing(faction_name, 3)
                psw_add_jishu_shen(faction_name, 1)
            end
        end
        
        if culture_che and not psw_faction_has_effect_bundle(faction_name, "ybbb_zzqz_che_get") then
            if ybbb_diploma_qz >= 100 then
                local ybbb_qizi_voice_randon_che = cm:random_number(100, 1)
                if ybbb_qizi_voice_randon_che >= 50 then
                    common.trigger_soundevent("ybbb_zzqz_1")
                    advice_ybbb_zzqz_1()
                elseif 1 == 1 then
                    common.trigger_soundevent("ybbb_zzqz_2")
                    advice_ybbb_zzqz_2()
                end
                psw_add_jishu_zhixing(faction_name, 1)
                cm:apply_effect_bundle(recipient_culture .. "_ybbb_zzqz", faction_name, 0)
                cm:apply_effect_bundle_to_character("jnz_tf_ex_ybbb_che", psw_main_character, 0);
                psw_aplly_costom_effect_bundle_hidden_fn("ybbb_zzqz_che_get", faction_name)
                psw_add_jishu_xingyun(faction_name, 3)
                psw_add_jishu_jingling(faction_name, 1)
            end
        end
        
        if culture_bing and not psw_faction_has_effect_bundle(faction_name, "ybbb_zzqz_bing_get") then
            if ybbb_diploma_qz >= 100 then
                local ybbb_qizi_voice_randon_bing = cm:random_number(100, 1)
                if ybbb_qizi_voice_randon_bing >= 50 then
                    common.trigger_soundevent("ybbb_zzqz_1")
                    advice_ybbb_zzqz_1()
                elseif 1 == 1 then
                    common.trigger_soundevent("ybbb_zzqz_2")
                    advice_ybbb_zzqz_2()
                end
                psw_add_jishu_zhixing(faction_name, 1)
                cm:apply_effect_bundle(recipient_culture .. "_ybbb_zzqz", faction_name, 0)
                cm:apply_effect_bundle_to_character("jnz_tf_ex_ybbb_bing", psw_main_character, 0);
                psw_aplly_costom_effect_bundle_hidden_fn("ybbb_zzqz_bing_get", faction_name)
            end
        end
                
      
        cm:set_saved_value(recipient_culture .. "ybbb_diploma_qz", ybbb_diploma_qz)
        cm:set_saved_value(recipient_culture .. "ybbb_battle_qz", ybbb_battle_qz)

        
    end,
	true
	)
end



        
------ 永不败北 战争权重相关 --------
        
function ybbb_battle_quanzhong()
    core:remove_listener("ybbb_battle_quanzhong")
	core:add_listener(
	"ybbb_battle_quanzhong",
	"BattleCompleted",
    function(context)
        local faction_name = cm:pending_battle_cache_get_attacker_faction_name(1)
        return cm:pending_battle_cache_human_is_involved() and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_ybbb_1") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_ybbb_3")
    end,
	function(context)
        local faction_name = cm:pending_battle_cache_get_attacker_faction_name(1)
        
        local attacker_cqi, attacker_force_cqi, attacker_name = cm:pending_battle_cache_get_attacker(1);
        local defender_cqi, defender_force_cqi, defender_name = cm:pending_battle_cache_get_defender(1);
        local attacker = cm:get_faction(attacker_name)
        local faction = attacker
        local yx_subtype = psw_main_data.player_data[faction_name].yx_subtype
        local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
		local bmm_sj_faction_name = cm:pending_battle_cache_get_attacker_faction_name(1)
        local bmm_attacker_result = cm:model():pending_battle():attacker_battle_result();
		local bmm_defender_result = cm:model():pending_battle():defender_battle_result();
		local bmm_faction_c = psw_main_data.player_data[faction_name].ybbb_faction
		if bmm_attacker_result == "close_defeat" and bmm_defender_result == "close_defeat" then
			-- They've both had a close defeat, must have been a retreat not a battle!
			return;
		elseif bmm_attacker_result == nil or bmm_defender_result == nil then
			return;
		end


        local recipient = cm:get_faction(defender_name)
        local recipient_culture = recipient:culture()
        local ybbb_diploma_qz = cm:get_saved_value(recipient_culture .. "ybbb_diploma_qz") or 0
        local ybbb_battle_qz = cm:get_saved_value(recipient_culture .. "ybbb_battle_qz") or 0
        
        ---种族棋子 种族相关
        
        local culture_wang = (recipient_culture == "wh_main_emp_empire" or recipient_culture == "wh_main_brt_bretonnia" or recipient_culture == "wh3_main_cth_cathay" or recipient_culture == "wh_dlc08_nor_norsca" or recipient_culture == "wh3_main_ksl_kislev" or recipient_culture == "wh_main_chs_chaos")
        
        local culture_hou = recipient_culture == "wh2_main_hef_high_elves"
        
        local culture_xiang = (recipient_culture == "wh3_main_cth_cathay" or recipient_culture == "wh3_dlc23_chd_chaos_dwarfs" or recipient_culture == "wh_main_dwf_dwarfs")
        
        local culture_ma = (recipient_culture == "wh3_main_kho_khorne" or recipient_culture == "wh3_main_nur_nurgle" or recipient_culture == "wh3_main_sla_slaanesh" or recipient_culture == "wh3_main_tze_tzeentch" or recipient_culture == "wh3_main_dae_daemons")
        
        local culture_che = (recipient_culture == "wh3_main_ogr_ogre_kingdoms" or recipient_culture == "wh_dlc05_wef_wood_elves")
        
        local culture_bing = (recipient_culture == "wh2_main_hef_high_elves" or recipient_culture == "wh2_main_def_dark_elves" or recipient_culture == "wh_dlc05_wef_wood_elves" or recipient_culture == "wh_dlc03_bst_beastmen" or recipient_culture == "wh2_main_skv_skaven" or recipient_culture == "wh_main_vmp_vampire_counts" or recipient_culture == "wh2_dlc11_cst_vampire_coast" or recipient_culture == "wh2_main_lzd_lizardmen" or recipient_culture == "wh_main_grn_greenskins" or recipient_culture == "wh2_dlc09_tmb_tomb_kings")
        
        ----
        local attacker_won = (bmm_attacker_result == "heroic_victory") or (bmm_attacker_result == "decisive_victory") or (bmm_attacker_result == "close_victory") or (bmm_attacker_result == "pyrrhic_victory")
        
        
        if attacker_won == true then
            if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yxsldff_nor") then
                ybbb_diploma_qz = ybbb_diploma_qz - 10
                ybbb_battle_qz = ybbb_battle_qz + 10
            elseif 1 == 1 then
                ybbb_diploma_qz = ybbb_diploma_qz - 5
                ybbb_battle_qz = ybbb_battle_qz + 5
            end
        elseif attacker_won == false then
            ybbb_battle_qz = ybbb_battle_qz - 5
        end
        ---- 种族棋子 效果赋予 ----
        if culture_wang and not psw_faction_has_effect_bundle(faction_name, "ybbb_zzqz_wang_get") then
            if ybbb_battle_qz >= 100 then
                local ybbb_qizi_voice_randon_bat = cm:random_number(100, 1)
                if ybbb_qizi_voice_randon_bat >= 50 then
                    common.trigger_soundevent("ybbb_zzqz_1")
                    advice_ybbb_zzqz_1()
                elseif 1 == 1 then
                    common.trigger_soundevent("ybbb_zzqz_2")
                    advice_ybbb_zzqz_2()
                end
                psw_add_jishu_zhixing(faction_name, 1)
                cm:apply_effect_bundle(recipient_culture .. "_ybbb_zzqz", faction_name, 0)
                cm:apply_effect_bundle_to_character("jnz_tf_ex_ybbb_wang", psw_main_character, 0);
                psw_aplly_costom_effect_bundle_hidden_fn("ybbb_zzqz_wang_get", faction_name)
                if not faction:has_effect_bundle("set_ex_shangxian") then
                    psw_add_jishu_ex_count(faction_name, -1)
                    psw_aplly_costom_effect_bundle_hidden("set_ex_shangxian", faction)
                end
            end
        end
        
        if culture_hou and not psw_faction_has_effect_bundle(faction_name, "ybbb_zzqz_hou_get") then
            if ybbb_battle_qz >= 100 then
                local ybbb_qizi_voice_randon_bat_hou = cm:random_number(100, 1)
                if ybbb_qizi_voice_randon_bat_hou >= 50 then
                    common.trigger_soundevent("ybbb_zzqz_1")
                    advice_ybbb_zzqz_1()
                elseif 1 == 1 then
                    common.trigger_soundevent("ybbb_zzqz_2")
                    advice_ybbb_zzqz_2()
                end
                psw_add_jishu_zhixing(faction_name, 1)
                cm:apply_effect_bundle(recipient_culture .. "_ybbb_zzqz", faction_name, 0)
                cm:apply_effect_bundle_to_character("jnz_tf_ex_ybbb_hou", psw_main_character, 0);
                psw_aplly_costom_effect_bundle_hidden_fn("ybbb_zzqz_hou_get", faction_name)
            end
        end
        
        if culture_xiang and not psw_faction_has_effect_bundle(faction_name, "ybbb_zzqz_xiang_get") then
            if ybbb_battle_qz >= 100 then
                local ybbb_qizi_voice_randon_bat_xiang = cm:random_number(100, 1)
                if ybbb_qizi_voice_randon_bat_xiang >= 50 then
                    common.trigger_soundevent("ybbb_zzqz_1")
                    advice_ybbb_zzqz_1()
                elseif 1 == 1 then
                    common.trigger_soundevent("ybbb_zzqz_2")
                    advice_ybbb_zzqz_2()
                end
                psw_add_jishu_zhixing(faction_name, 1)
                psw_add_jishu_miansi(faction_name, 1)
                cm:apply_effect_bundle(recipient_culture .. "_ybbb_zzqz", faction_name, 0)
                cm:apply_effect_bundle_to_character("jnz_tf_ex_ybbb_xiang", psw_main_character, 0);
                psw_aplly_costom_effect_bundle_hidden_fn("ybbb_zzqz_xiang_get", faction_name)
            end
        end
        
        if culture_ma and not psw_faction_has_effect_bundle(faction_name, "ybbb_zzqz_ma_get") then
            if ybbb_battle_qz >= 100 then
                local ybbb_qizi_voice_randon_bat_ma = cm:random_number(100, 1)
                if ybbb_qizi_voice_randon_bat_ma >= 50 then
                    common.trigger_soundevent("ybbb_zzqz_1")
                    advice_ybbb_zzqz_1()
                elseif 1 == 1 then
                    common.trigger_soundevent("ybbb_zzqz_2")
                    advice_ybbb_zzqz_2()
                end
                psw_add_jishu_zhixing(faction_name, 1)
                cm:apply_effect_bundle(recipient_culture .. "_ybbb_zzqz", faction_name, 0)
                cm:apply_effect_bundle_to_character("jnz_tf_ex_ybbb_ma", psw_main_character, 0);
                psw_aplly_costom_effect_bundle_hidden_fn("ybbb_zzqz_ma_get", faction_name)
                psw_add_jishu_shenxing(faction_name, 3)
                psw_add_jishu_shen(faction_name, 1)
            end
        end
        
        if culture_che and not psw_faction_has_effect_bundle(faction_name, "ybbb_zzqz_che_get") then
            if ybbb_battle_qz >= 100 then
                local ybbb_qizi_voice_randon_bat_che = cm:random_number(100, 1)
                if ybbb_qizi_voice_randon_bat_che >= 50 then
                    common.trigger_soundevent("ybbb_zzqz_1")
                    advice_ybbb_zzqz_1()
                elseif 1 == 1 then
                    common.trigger_soundevent("ybbb_zzqz_2")
                    advice_ybbb_zzqz_2()
                end
                psw_add_jishu_zhixing(faction_name, 1)
                cm:apply_effect_bundle(recipient_culture .. "_ybbb_zzqz", faction_name, 0)
                cm:apply_effect_bundle_to_character("jnz_tf_ex_ybbb_che", psw_main_character, 0);
                psw_aplly_costom_effect_bundle_hidden_fn("ybbb_zzqz_che_get", faction_name)
                psw_add_jishu_xingyun(faction_name, 3)
                psw_add_jishu_jingling(faction_name, 1)
            end
        end
        
        if culture_bing and not psw_faction_has_effect_bundle(faction_name, "ybbb_zzqz_bing_get") then
            if ybbb_battle_qz >= 100 then
                local ybbb_qizi_voice_randon_bat_bing = cm:random_number(100, 1)
                if ybbb_qizi_voice_randon_bat_bing >= 50 then
                    common.trigger_soundevent("ybbb_zzqz_1")
                    advice_ybbb_zzqz_1()
                elseif 1 == 1 then
                    common.trigger_soundevent("ybbb_zzqz_2")
                    advice_ybbb_zzqz_2()
                end
                psw_add_jishu_zhixing(faction_name, 1)
                cm:apply_effect_bundle(recipient_culture .. "_ybbb_zzqz", faction_name, 0)
                cm:apply_effect_bundle_to_character("jnz_tf_ex_ybbb_bing", psw_main_character, 0);
                psw_aplly_costom_effect_bundle_hidden_fn("ybbb_zzqz_bing_get", faction_name)
            end
        end

        cm:set_saved_value(recipient_culture .. "ybbb_diploma_qz", ybbb_diploma_qz)
        cm:set_saved_value(recipient_culture .. "ybbb_battle_qz", ybbb_battle_qz)
        
        
    end,
	true
	)
end

function psw_add_jingying_unit_to_facion(faction_name, sf_add, unit_key, add_num, per_turn_num)
    if not sf_add then
        return
    end
    cm:add_unit_to_faction_mercenary_pool(cm:get_faction(faction_name), unit_key, "renown", add_num, 100, add_num, per_turn_num, "", "", "", true, unit_key)
end
        
------ 独特兵种 建筑招募 --------
function psw_unit_zhaomu_jianzhu(faction_name)
if not psw_main_data or not psw_main_data.player_data then return end
local p=psw_main_data.player_data[faction_name];if not p then return end
local faction=cm:get_faction(faction_name)
local yx_subtype=p.yx_subtype
local psw_main_character=cm:get_most_recently_created_character_of_type(faction,"general",yx_subtype)
local jishu_xilie_ldse=p.jishu_xilie_ldse or 0
                                 local jishu_xilie_jwts = psw_main_data.player_data[faction_name].jishu_xilie_jwts or 0
    local jishu_xilie_ldd = psw_main_data.player_data[faction_name].jishu_xilie_ldd or 0
    local jishu_xilie_sfly = psw_main_data.player_data[faction_name].jishu_xilie_sfly or 0
    local jishu_shenhai = psw_main_data.player_data[faction_name].jishu_shenhai or 0
    
    local sf_add = false
    local unit_key
    local add_num = 0
    local per_turn_num = 0

    if jishu_xilie_ldse >= 3 and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_chgz_nor") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_chgz_nor_zm") then
        sf_add = true
        unit_key = "chal_bre_kotf"
        add_num = 1
        per_turn_num = 0.25
        
        psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_chgz_nor_zm", faction_name)
        psw_add_jingying_unit_to_facion(faction_name, sf_add, unit_key, add_num, per_turn_num)
    end
    
    if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_hecheng_nor") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_hecheng_nor_zm") then
        sf_add = true
        unit_key = "psw_ba_zjt"
        add_num = 3
        per_turn_num = 0.34
        
        psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_hecheng_nor_zm", faction_name)
        psw_add_jingying_unit_to_facion(faction_name, sf_add, unit_key, add_num, per_turn_num)
    end
    
    if psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yingzi_nor") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_yingzi_nor_zm") then
        sf_add = true
        unit_key = "psw_ba_zysxwy"
        add_num = 2
        per_turn_num = 0.25
        
        psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_yingzi_nor_zm", faction_name)
        psw_add_jingying_unit_to_facion(faction_name, sf_add, unit_key, add_num, per_turn_num)
    end
    
    if jishu_xilie_ldse >= 3 and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_xxydz_nor") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_xxydz_nor_zm") then
        sf_add = true
        unit_key = "psw_ldsr_wgqstp"
        add_num = 1
        per_turn_num = 0.25
        
        psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_xxydz_nor_zm", faction_name)
        psw_add_jingying_unit_to_facion(faction_name, sf_add, unit_key, add_num, per_turn_num)
    end
    
    if jishu_xilie_ldse >= 3 and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_jgrs_nor") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_jgrs_nor_zm") then
        sf_add = true
        unit_key = "psw_ldsr_gzss"
        add_num = 3
        per_turn_num = 0.34
        
        psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_jgrs_nor_zm", faction_name)
        psw_add_jingying_unit_to_facion(faction_name, sf_add, unit_key, add_num, per_turn_num)
    end
    
    if jishu_xilie_jwts >= 2 and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_zhu_nor") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_zhu_nor_zm") then
        sf_add = true
        unit_key = "psw_ba_szjtk"
        add_num = 1
        per_turn_num = 0.25
        
        psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_zhu_nor_zm", faction_name)
        psw_add_jingying_unit_to_facion(faction_name, sf_add, unit_key, add_num, per_turn_num)
    end
    
    if jishu_xilie_jwts >= 2 and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_ylb_nor") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_ylb_nor_zm") then
        sf_add = true
        unit_key = "psw_ba_hs"
        add_num = 1
        per_turn_num = 0.25
        
        psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_ylb_nor_zm", faction_name)
        psw_add_jingying_unit_to_facion(faction_name, sf_add, unit_key, add_num, per_turn_num)
    end
    
    if jishu_xilie_ldd >= 2 and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_shanling_nor") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_shanling_nor_zm") then
        sf_add = true
        unit_key = "psw_mrfz_agexd"
        add_num = 1
        per_turn_num = 0.25
        
        psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_shanling_nor_zm", faction_name)
        psw_add_jingying_unit_to_facion(faction_name, sf_add, unit_key, add_num, per_turn_num)
    end
    
    if jishu_xilie_ldd >= 2 and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_sly_nor") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_sly_nor_zm") then
        sf_add = true
        unit_key = "psw_mrfz_skzbnz"
        add_num = 2
        per_turn_num = 0.34
        
        psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_sly_nor_zm", faction_name)
        psw_add_jingying_unit_to_facion(faction_name, sf_add, unit_key, add_num, per_turn_num)
    end
    
    if jishu_xilie_sfly >= 3 and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_ytzd_nor") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_ytzd_nor_zm") then
        sf_add = true
        unit_key = "psw_bh3_ex_bnls"
        add_num = 1
        per_turn_num = 0.1
        
        psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_ytzd_nor_zm", faction_name)
        psw_add_jingying_unit_to_facion(faction_name, sf_add, unit_key, add_num, per_turn_num)
    end
    
    if jishu_shenhai >= 3 and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_guanghui_nor") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_guanghui_nor_zm") then
        sf_add = true
        unit_key = "psw_dlc6_guanghui-caiyun"
        add_num = 2
        per_turn_num = 0.34
        
        psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_guanghui_nor_zm", faction_name)
        psw_add_jingying_unit_to_facion(faction_name, sf_add, unit_key, add_num, per_turn_num)
    end
    
    if jishu_shenhai >= 3 and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_kewei_nor") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_kewei_nor_zm") then
        sf_add = true
        unit_key = "psw_dlc6_kewei_penhuo"
        add_num = 2
        per_turn_num = 0.34
        
        psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_kewei_nor_zm", faction_name)
        psw_add_jingying_unit_to_facion(faction_name, sf_add, unit_key, add_num, per_turn_num)
    end
    
    if jishu_shenhai >= 3 and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_qiye_nor") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_nor_qiye_nor_zm") then
        sf_add = true
        unit_key = "psw_dlc6_qiye_tianxi"
        add_num = 2
        per_turn_num = 0.34
        
        psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_nor_qiye_nor_zm", faction_name)
        psw_add_jingying_unit_to_facion(faction_name, sf_add, unit_key, add_num, per_turn_num)
    end
    
end




------ BOSS传送/终末抉择 --------

function psw_main_an_boss_tp()
    core:remove_listener("psw_main_an_boss_tp")
    core:add_listener(
    "psw_main_an_boss_tp",
    "CharacterAncillaryGained",
    function(context)
        return (context:ancillary() == "psw_cssj_boss" or context:ancillary() == "psw_cssj_legend" or context:ancillary() == "psw_main_zmjz")
    end,
    function(context)
        local faction_name = context:character():faction():name()
        local faction = cm:get_faction(faction_name)
        local ancillary = context:ancillary()
        psw_delete_ancillary_with_time_delay(faction, ancillary, 0.1)
        cm:callback(function()
            cm:add_ancillary_to_faction(faction, ancillary, true)
            if ancillary == "psw_cssj_boss" then
                cm:trigger_dilemma(faction_name, "dilemma_tf_duoren_tp")
            elseif ancillary == "psw_cssj_legend" then
                cm:trigger_dilemma(faction_name, "dilemma_tf_duoren_legend_tp")
            elseif ancillary == "psw_main_zmjz" then
                cm:trigger_dilemma(faction_name, "dilemma_tf_psw_main_zmjz")
            end
        end, 1)
    end,
	true
	)
end


        
------------ 初始函数启动 ----------------

cm:add_first_tick_callback(
	function()
		if is_function(psw_start_game_all_factions) then
			psw_start_game_all_factions();
		end;
	end
);

function psw_start_game_all_factions()
	out("psw_start_game_all_factions() called");
	out.inc_tab();
	psw_lmyx_tfjh_jjdmn()
	lmyx_mfsn_lhjs_hh()
	alxy_lznl_hh()
	psw_main_boss_nsca_rq()
	alxy_chizi_huihe()
	psw_mission_listener()
	df_sanae_wugu()
	kqrn_hgd_zj()
	yls_skd_thd_hh()
	yls_skd_thd_battle()
	kqrn_zisi()
	mika_jishu_juexing()
	mika_ydr_rys_juexing()
	mika_bmbx_juexing()
	psw_boss_start_sznw()
	psw_boss_start_jwsq()
	psw_boss_start_syjxg()
	psw_boss_start_lyzm()
	psw_boss_start_ksz()
    bass_qh_lrg()
    bass_rgqh()
    bjmn_clks_jishu_hh()
    slmmn_abge_wszs()
    slmmn_yydhmj_jx()
    psw_main_rankup_fl_sx()
    qysj_main_hh_zd()
    qy_25hh_tf_zb_end()
    mika_benduhui_xg()
    xsdjy_hh_jishu()
    rwyyr_hjs_jx()
    rwyyr_wysm_jx()
    azsyz_mlxs_jiyizhi()
    azsyz_mlxs_jx()
    ejtzh_jyzbh_hh()
    psw_yqdjb_chouka_hh_end()
    yqdjb_sszqjdz_jx()
    ybbb_diplomatic_quanzhong()
    ybbb_battle_quanzhong()
    psw_ybbb_xuyuan_hh_end()
    yedou_wysm_qysj()
    psw_main_jysp_huoqu()
    cstf_lmyx_qjzlx_get()
    cstf_sllh_tzgzzc_get()
    cstf_sllh_htxmzc_get()
    psw_main_sllh_mzz_use()
    edu_cstf_kxjqzj_rankup()
    edu_love_level_huihe_end()
    edu_love_level_battle()
    cstf_edu_dwzh_get()
    cstf_edu_zsdm1_get()
    psw_main_hh_start()
    psw_blhx_xzmf()
    youxiang_hgd_zj()
    blst_love_level_battle()
    psw_zhenbu_thwg_end()
    djs_love_level_battle()
    djs_my_night_jx()
    psw_djs_zykm()
    psw_djs_ztzh()
    psw_main_an_boss_tp()
    fia_cz1_rwwc()
    fia_cz2_lxsj()
    alice_cz1_djsj()
    alice_cz2_swts()
    alice_cz3_ghwt()
    alice_cz4_ltjw()
    alice_cz5_fbgl()
    alice_random_daoju_apply()
    alice_main_daoju_system()
    alice_sleep_sx()
    psw_main_zhiyu_effect()
    psw_main_sqyj_use()
    --psw_main_ms_hh_delete()
    psw_lv10_csjs()
    psw_main_ybdtq_apply()
    psw_fxhj_use()
    psw_fxhj_get()
    psw_hh_start_AI_hb_hef()
    psw_hh_start_AI_hb_def()
    psw_hh_start_AI_hb_kisliv()
    psw_hh_start_AI_hb_dwf()
    psw_hh_start_AI_hb_vampire_xewny()
    psw_hh_start_AI_hb_lzd_ytz()
    psw_hh_start_AI_hb_lzd_tlk()
    psw_hh_start_AI_hb_nsc()
    psw_hh_start_AI_hb_wef()
    psw_hh_start_AI_hb_chs_dwf()
    psw_hh_start_AI_hb_emp()
    psw_hh_start_AI_hb_cth()
    psw_delete_yh_buff_and_ys()
    psw_hb_boss_game_over()
    psw_yctz_apply_to_new_hero()
    psw_main_myyw_listener_BattleCompleted()
    psw_all_player_initial()
    psw_main_AncillaryGained_listner()
    psw_main_BattleCompleted_listner()
    psw_main_FactionTurnStart_listner()
    --psw_main_ComponentLClickUp_dtnl()
    psw_main_CharacterBattleCompleted_listner()
    psw_dlc6_ancillary_up_listner()
    psw_main_BuildingCompleted_listner()
    psw_main_moyin_hecheng_listner()
    psw_main_FactionTurnEnd_listner()
    psw_main_CharacterTurnEnd_listner()
    psw_main_CharacterAncillaryHecheng_listner()
    psw_main_initial_start()
    psw_main_tfmw_listner_add()
    psw_dlc7_ams_dip_mission()
    psw_main_CharacterRankUp_listner()
    out.dec_tab();
end







