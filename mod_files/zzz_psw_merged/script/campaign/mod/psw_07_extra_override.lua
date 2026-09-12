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

    if final_tf_count >= 13 then
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
