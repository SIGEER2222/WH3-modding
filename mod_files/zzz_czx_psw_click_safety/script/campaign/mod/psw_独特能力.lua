
-- ==== zzz_czx_psw_click_safety 补丁 ====
-- 本文件遮蔽 !!Prayer_of_star_witch.pack 同名脚本。原版 10 个能力回调
-- 注册全局 ComponentLClickUp（condition 恒 true），对每一次点击——包括
-- 引擎在面板构建/拆除期合成的 tab_details 等点击——裸调
-- GetContextObject/Call。组件半销毁时该调用读写死 context 数组 =
-- +0x22c0f80 读 / +0x132c34c 写 崩族（09-29 13:19 与 13:42 dump，
-- 崩前 4s RLH 日志捕获本文件同批回调连续 'ccc nil' 报错，证明其在
-- 回合级联窗内被合成点击触发）。
-- 修补：condition 换 psw_ctx_safe()——ui_locked / blocking 面板 /
-- 最近 0.6s 内有面板开合时拒绝进入回调（纯 Lua 字段读，零原生调用，
-- 点击派发期安全）；海上航行按钮不属于本 MOD，直接跳过；回调体内
-- 再补 is_uicomponent 存活检查与 cco nil 防护（顺带消除 'ccc nil' 报错）。
local psw_last_panel_clock = -10
core:remove_listener("psw_click_guard_stamp")
core:add_listener(
    "psw_click_guard_stamp",
    "PanelOpenedCampaign",
    true,
    function() psw_last_panel_clock = os.clock() end,
    true
)
core:remove_listener("psw_click_guard_close_stamp")
core:add_listener(
    "psw_click_guard_close_stamp",
    "PanelClosedCampaign",
    true,
    function() psw_last_panel_clock = os.clock() end,
    true
)

local function psw_ctx_safe(context)
    if context and context.string == "teleport_sea_lane" then
        return false
    end
    local ok_uim, uim = pcall(function() return cm:get_campaign_ui_manager() end)
    if not ok_uim or not uim or uim.ui_locked then return false end
    local ok_bp, bp = pcall(function() return uim:get_open_blocking_panel() end)
    if ok_bp and bp then return false end
    local ok_clk, clk = pcall(os.clock)
    if ok_clk and clk and (clk - psw_last_panel_clock) <= 0.6 then return false end
    return true
end
-- ==== 补丁结束 ====

local psw_tf_ex_btmmfs_1 = "ui_dtnl_psw_tf_ex_btmmfs_1"
local psw_tf_ex_btmmfs_2 = "ui_dtnl_psw_tf_ex_btmmfs_2"
local psw_tf_ex_btmmfs_3 = "ui_dtnl_psw_tf_ex_btmmfs_3"
local psw_tf_nor_bszzw_nor = "ui_dtnl_psw_tf_nor_bszzw_nor"
local psw_tf_nor_yjdzf_nor = "ui_dtnl_psw_tf_nor_yjdzf_nor"
local psw_tf_ex_you_ex = "ui_dtnl_psw_tf_ex_you_ex"
local psw_tf_ex_zhenbu_2 = "ui_dtnl_psw_tf_ex_zhenbu_2"
local psw_tf_ex_fia_3 = "ui_dtnl_psw_tf_ex_fia_3"
local psw_tf_ex_amly_1 = "ui_dtnl_psw_tf_ex_amly_1"
local psw_tf_sp_xxdqj_ex = "ui_dtnl_psw_tf_sp_xxdqj_ex"




local function psw_xxdqj_qjdmf_1(psw_tf_sp_xxdqj_ex)
    core:add_listener(
        "psw_xxdqj_qjdmf_1",
        "ComponentLClickUp",
        function(context)
            return psw_ctx_safe(context)
        end,
        function(context)
            local uic = UIComponent(context.component)
            if not is_uicomponent(uic) then return end
            local ccc = uic:GetContextObject("CcoCampaignBuildingSlot")
            
            if not ccc or not ccc:Call("IsHordeSlot") then
                return
            end
            local tf_key_cco = uic:GetContextObject("CcoBuildingLevelRecord")
            if not tf_key_cco then return end
            local dilemma_key = tf_key_cco:Call("Key")
            if dilemma_key ~= "psw_tf_sp_xxdqj_ex" then
                return
            end
            
            local faction_name = ccc:Call("FactionContext.FactionRecordContext.Key")
            local faction = cm:get_faction(faction_name)
            local faction_cqi = faction:command_queue_index()
            CampaignUI.TriggerCampaignScriptEvent(faction_cqi, psw_tf_sp_xxdqj_ex)
        end,
        true
    )
end

local function psw_btmmfs_sjgx_1(psw_tf_ex_btmmfs_1)
    core:add_listener(
        "psw_btmmfs_sjgx",
        "ComponentLClickUp",
        function(context)
            return psw_ctx_safe(context)
        end,
        function(context)
            local uic = UIComponent(context.component)
            if not is_uicomponent(uic) then return end
            local ccc = uic:GetContextObject("CcoCampaignBuildingSlot")
            
            if not ccc or not ccc:Call("IsHordeSlot") then
                return
            end
            local tf_key_cco = uic:GetContextObject("CcoBuildingLevelRecord")
            if not tf_key_cco then return end
            local dilemma_key = tf_key_cco:Call("Key")
            if dilemma_key ~= "psw_tf_ex_btmmfs_1" then
                return
            end
            
            local faction_name = ccc:Call("FactionContext.FactionRecordContext.Key")
            local faction = cm:get_faction(faction_name)
            local faction_cqi = faction:command_queue_index()
            CampaignUI.TriggerCampaignScriptEvent(faction_cqi, psw_tf_ex_btmmfs_1)
        end,
        true
    )
end

local function psw_btmmfs_sjgx_2(psw_tf_ex_btmmfs_2)
    core:add_listener(
        "psw_btmmfs_sjgx_2",
        "ComponentLClickUp",
        function(context)
            return psw_ctx_safe(context)
        end,
        function(context)
            local uic = UIComponent(context.component)
            if not is_uicomponent(uic) then return end
            local ccc = uic:GetContextObject("CcoCampaignBuildingSlot")
            
            if not ccc or not ccc:Call("IsHordeSlot") then
                return
            end
            local tf_key_cco = uic:GetContextObject("CcoBuildingLevelRecord")
            if not tf_key_cco then return end
            local dilemma_key = tf_key_cco:Call("Key")
            if dilemma_key ~= "psw_tf_ex_btmmfs_2" then
                return
            end
            
            local faction_name = ccc:Call("FactionContext.FactionRecordContext.Key")
            local faction = cm:get_faction(faction_name)
            local faction_cqi = faction:command_queue_index()
            CampaignUI.TriggerCampaignScriptEvent(faction_cqi, psw_tf_ex_btmmfs_2)
        end,
        true
    )
end

local function psw_btmmfs_sjgx_3(psw_tf_ex_btmmfs_3)
    core:add_listener(
        "psw_btmmfs_sjgx_3",
        "ComponentLClickUp",
        function(context)
            return psw_ctx_safe(context)
        end,
        function(context)
            local uic = UIComponent(context.component)
            if not is_uicomponent(uic) then return end
            local ccc = uic:GetContextObject("CcoCampaignBuildingSlot")
            
            if not ccc or not ccc:Call("IsHordeSlot") then
                return
            end
            local tf_key_cco = uic:GetContextObject("CcoBuildingLevelRecord")
            if not tf_key_cco then return end
            local dilemma_key = tf_key_cco:Call("Key")
            if dilemma_key ~= "psw_tf_ex_btmmfs_3" then
                return
            end
            
            local faction_name = ccc:Call("FactionContext.FactionRecordContext.Key")
            local faction = cm:get_faction(faction_name)
            local faction_cqi = faction:command_queue_index()
            CampaignUI.TriggerCampaignScriptEvent(faction_cqi, psw_tf_ex_btmmfs_3)
        end,
        true
    )
end


------ 不死者之王-星星祈愿 ------
local function psw_bszzw_xxqy(psw_tf_nor_bszzw_nor)
    core:add_listener(
        "psw_bszzw_xxqy",
        "ComponentLClickUp",
        function(context)
            return psw_ctx_safe(context)
        end,
        function(context)
            local uic = UIComponent(context.component)
            if not is_uicomponent(uic) then return end
            local ccc = uic:GetContextObject("CcoCampaignBuildingSlot")
            
            if not ccc or not ccc:Call("IsHordeSlot") then
                return
            end
            local tf_key_cco = uic:GetContextObject("CcoBuildingLevelRecord")
            if not tf_key_cco then return end
            local dilemma_key = tf_key_cco:Call("Key")
            if dilemma_key ~= "psw_tf_nor_bszzw_nor" then
                return
            end
            
            local faction_name = ccc:Call("FactionContext.FactionRecordContext.Key")
            local faction = cm:get_faction(faction_name)
            local faction_cqi = faction:command_queue_index()
            CampaignUI.TriggerCampaignScriptEvent(faction_cqi, psw_tf_nor_bszzw_nor)
        end,
        true
    )
end


------ 妖精之祝福-神力【妖精】 ------
local function psw_yjzzf_slyj(psw_tf_nor_yjdzf_nor)
    core:add_listener(
        "psw_yjzzf_slyj",
        "ComponentLClickUp",
        function(context)
            return psw_ctx_safe(context)
        end,
        function(context)
            local uic = UIComponent(context.component)
            if not is_uicomponent(uic) then return end
            local ccc = uic:GetContextObject("CcoCampaignBuildingSlot")
            
            if not ccc or not ccc:Call("IsHordeSlot") then
                return
            end
            local tf_key_cco = uic:GetContextObject("CcoBuildingLevelRecord")
            if not tf_key_cco then return end
            local dilemma_key = tf_key_cco:Call("Key")
            if dilemma_key ~= "psw_tf_nor_yjdzf_nor" then
                return
            end
            
            local faction_name = ccc:Call("FactionContext.FactionRecordContext.Key")
            local faction = cm:get_faction(faction_name)
            local faction_cqi = faction:command_queue_index()
            CampaignUI.TriggerCampaignScriptEvent(faction_cqi, psw_tf_nor_yjdzf_nor)
        end,
        true
    )
end


------ 优-金色的记忆 ------
local function psw_jsdjy_zt(psw_tf_ex_you_ex)
    core:add_listener(
        "psw_jsdjy_zt",
        "ComponentLClickUp",
        function(context)
            return psw_ctx_safe(context)
        end,
        function(context)
            local uic = UIComponent(context.component)
            if not is_uicomponent(uic) then return end
            local ccc = uic:GetContextObject("CcoCampaignBuildingSlot")
            
            if not ccc or not ccc:Call("IsHordeSlot") then
                return
            end
            local tf_key_cco = uic:GetContextObject("CcoBuildingLevelRecord")
            if not tf_key_cco then return end
            local dilemma_key = tf_key_cco:Call("Key")
            if dilemma_key ~= "psw_tf_ex_you_ex" then
                return
            end
            
            local faction_name = ccc:Call("FactionContext.FactionRecordContext.Key")
            local faction = cm:get_faction(faction_name)
            local faction_cqi = faction:command_queue_index()
            CampaignUI.TriggerCampaignScriptEvent(faction_cqi, psw_tf_ex_you_ex)
        end,
        true
    )
end


------ 姬宫真布-童话王国 ------
local function psw_zhenbu_thwg(psw_tf_ex_zhenbu_2)
    core:add_listener(
        "psw_zhenbu_thwg",
        "ComponentLClickUp",
        function(context)
            return psw_ctx_safe(context)
        end,
        function(context)
            local uic = UIComponent(context.component)
            if not is_uicomponent(uic) then return end
            local ccc = uic:GetContextObject("CcoCampaignBuildingSlot")
            
            if not ccc or not ccc:Call("IsHordeSlot") then
                return
            end
            local tf_key_cco = uic:GetContextObject("CcoBuildingLevelRecord")
            if not tf_key_cco then return end
            local dilemma_key = tf_key_cco:Call("Key")
            if dilemma_key ~= "psw_tf_ex_zhenbu_2" then
                return
            end
            
            local faction_name = ccc:Call("FactionContext.FactionRecordContext.Key")
            local faction = cm:get_faction(faction_name)
            local faction_cqi = faction:command_queue_index()
            CampaignUI.TriggerCampaignScriptEvent(faction_cqi, psw_tf_ex_zhenbu_2)
            
            
            
        end,
        true
    )
end



------ 菲娅 - 菲娅的祝福 ------
local function psw_fia_fydzf_click(psw_tf_ex_fia_3)
    core:add_listener(
        "psw_fia_fydzf_click",
        "ComponentLClickUp",
        function(context)
            return psw_ctx_safe(context)
        end,
        function(context)
            local uic = UIComponent(context.component)
            if not is_uicomponent(uic) then return end
            local ccc = uic:GetContextObject("CcoCampaignBuildingSlot")
            
            if not ccc or not ccc:Call("IsHordeSlot") then
                return
            end
            local tf_key_cco = uic:GetContextObject("CcoBuildingLevelRecord")
            if not tf_key_cco then return end
            local dilemma_key = tf_key_cco:Call("Key")
            if dilemma_key ~= "psw_tf_ex_fia_3" then
                return
            end
            
            local faction_name = ccc:Call("FactionContext.FactionRecordContext.Key")
            local faction = cm:get_faction(faction_name)
            local faction_cqi = faction:command_queue_index()
            CampaignUI.TriggerCampaignScriptEvent(faction_cqi, psw_tf_ex_fia_3)
            
            
            
        end,
        true
    )
end

------ 爱蜜莉雅 - 觉醒 ------
local function psw_amly_jx_click(psw_tf_ex_amly_1)
    core:add_listener(
        "psw_amly_jx_click",
        "ComponentLClickUp",
        function(context)
            return psw_ctx_safe(context)
        end,
        function(context)
            local uic = UIComponent(context.component)
            if not is_uicomponent(uic) then return end
            local ccc = uic:GetContextObject("CcoCampaignBuildingSlot")
            
            if not ccc or not ccc:Call("IsHordeSlot") then
                return
            end
            local tf_key_cco = uic:GetContextObject("CcoBuildingLevelRecord")
            if not tf_key_cco then return end
            local dilemma_key = tf_key_cco:Call("Key")
            if dilemma_key ~= "psw_tf_ex_amly_1" then
                return
            end
            
            local faction_name = ccc:Call("FactionContext.FactionRecordContext.Key")
            local faction = cm:get_faction(faction_name)
            local faction_cqi = faction:command_queue_index()
            CampaignUI.TriggerCampaignScriptEvent(faction_cqi, psw_tf_ex_amly_1)
        end,
        true
    )
end





cm:add_first_tick_callback(

    --Whenever the game first starts, we run this function. Which calls an event listener
    function()
        psw_btmmfs_sjgx_1(psw_tf_ex_btmmfs_1)
        psw_btmmfs_sjgx_2(psw_tf_ex_btmmfs_2)
        psw_btmmfs_sjgx_3(psw_tf_ex_btmmfs_3)
        psw_bszzw_xxqy(psw_tf_nor_bszzw_nor)
        psw_yjzzf_slyj(psw_tf_nor_yjdzf_nor)
        psw_jsdjy_zt(psw_tf_ex_you_ex)
        psw_zhenbu_thwg(psw_tf_ex_zhenbu_2)
        psw_fia_fydzf_click(psw_tf_ex_fia_3)
        psw_amly_jx_click(psw_tf_ex_amly_1)
        psw_xxdqj_qjdmf_1(psw_tf_sp_xxdqj_ex)
    end
)


------ 奇迹与星星的魔女 - 奇迹的魔法 ------

core:remove_listener("ui_psw_tf_sp_xxdqj_ex")
core:add_listener("ui_psw_tf_sp_xxdqj_ex",
    "UITrigger",
    function(context)
        return context:trigger():starts_with(psw_tf_sp_xxdqj_ex)
    end,
    function(context)
        local faction = cm:model():faction_for_command_queue_index(context:faction_cqi())
        local faction_name = faction:name()
        
        if 1 == 1 then
            
            local xxdqj_qjjs = psw_main_data.player_data[faction_name].xxdqj_qjjs

            if xxdqj_qjjs <= 0 then
                return
            end
            local yx_subtype = psw_main_data.player_data[faction_name].yx_subtype
            local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
            
            psw_main_data.player_data[faction_name].xxdqj_qjjs = psw_main_data.player_data[faction_name].xxdqj_qjjs - 1
            
            psw_main_pickup(faction_name)
            
        end
    end,
    true
)
local ejtzh_jyz_gx_1 = 15
local ejtzh_jyz_gx_2 = 25

------ 真红 - 世界改写1 ------
core:remove_listener("ui_psw_btmmfs_sjgx_1")
core:add_listener("ui_psw_btmmfs_sjgx_1",
    "UITrigger",
    function(context)
        return context:trigger():starts_with(psw_tf_ex_btmmfs_1)
    end,
    function(context)
        local faction = cm:model():faction_for_command_queue_index(context:faction_cqi())
        local faction_name = faction:name()
        
        if 1 == 1 then
            
            local yx_subtype = psw_main_data.player_data[faction_name].yx_subtype
            local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
            
            local ejtzh_lv1 = psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_btmmfs_1")
            local ejtzh_lv2 = faction:has_effect_bundle("set_psw_tf_ex_btmmfs_2")
            local ejtzh_lv3 = psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_btmmfs_3")
            local ejtzh_lv0 = psw_faction_has_effect_bundle(faction_name, "set_btmmfs_yixiaoshi")
            local ejtzh_jiyizhi = psw_main_data.player_data[faction_name].ejtzh_jiyizhi or 100
            
            if not ejtzh_lv1 or ejtzh_lv0 then
                return
            end
            
            
            
            if ejtzh_lv1 and not ejtzh_lv2 and not ejtzh_lv3 and ejtzh_jiyizhi > ejtzh_jyz_gx_1 then
                psw_main_data.player_data[faction_name].ejtzh_jiyizhi = psw_main_data.player_data[faction_name].ejtzh_jiyizhi - ejtzh_jyz_gx_1
                psw_main_pickup(faction_name)
            elseif (ejtzh_lv2 or ejtzh_lv3) and ejtzh_jiyizhi > ejtzh_jyz_gx_2 then
                psw_main_data.player_data[faction_name].ejtzh_jiyizhi = psw_main_data.player_data[faction_name].ejtzh_jiyizhi - ejtzh_jyz_gx_2
                psw_main_pickup(faction_name)
            end
            
            psw_ejtzh_main_jyz(faction)
            psw_hh_start_btmmfs(faction_name)
        end
    end,
    true
)

------ 真红 - 世界改写2 ------
core:remove_listener("ui_psw_btmmfs_sjgx_2")
core:add_listener("ui_psw_btmmfs_sjgx_2",
    "UITrigger",
    function(context)
        return context:trigger():starts_with(psw_tf_ex_btmmfs_2)
    end,
    function(context)
        local faction = cm:model():faction_for_command_queue_index(context:faction_cqi())
        local faction_name = faction:name()
        
        if 1 == 1 then
            
            local yx_subtype = psw_main_data.player_data[faction_name].yx_subtype
            local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
            
            local ejtzh_lv1 = psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_btmmfs_1")
            local ejtzh_lv2 = faction:has_effect_bundle("set_psw_tf_ex_btmmfs_2")
            local ejtzh_lv3 = psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_btmmfs_3")
            local ejtzh_lv0 = psw_faction_has_effect_bundle(faction_name, "set_btmmfs_yixiaoshi")
            local ejtzh_jiyizhi = psw_main_data.player_data[faction_name].ejtzh_jiyizhi or 100
            
            if not ejtzh_lv1 or ejtzh_lv0 then
                return
            end
            
            
            
            if ejtzh_lv1 and not ejtzh_lv2 and not ejtzh_lv3 and ejtzh_jiyizhi > ejtzh_jyz_gx_1 then
                psw_main_data.player_data[faction_name].ejtzh_jiyizhi = psw_main_data.player_data[faction_name].ejtzh_jiyizhi - ejtzh_jyz_gx_1
                psw_main_pickup(faction_name)
            elseif (ejtzh_lv2 or ejtzh_lv3) and ejtzh_jiyizhi > ejtzh_jyz_gx_2 then
                psw_main_data.player_data[faction_name].ejtzh_jiyizhi = psw_main_data.player_data[faction_name].ejtzh_jiyizhi - ejtzh_jyz_gx_2
                psw_main_pickup(faction_name)
            end
            psw_ejtzh_main_jyz(faction)
            psw_hh_start_btmmfs(faction_name)
        end
    end,
    true
)

------ 真红 - 世界改写3 ------
core:remove_listener("ui_psw_btmmfs_sjgx_3")
core:add_listener("ui_psw_btmmfs_sjgx_3",
    "UITrigger",
    function(context)
        return context:trigger():starts_with(psw_tf_ex_btmmfs_3)
    end,
    function(context)
        local faction = cm:model():faction_for_command_queue_index(context:faction_cqi())
        local faction_name = faction:name()
        
        if 1 == 1 then
            
            local yx_subtype = psw_main_data.player_data[faction_name].yx_subtype
            local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
            
            local ejtzh_lv1 = psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_btmmfs_1")
            local ejtzh_lv2 = faction:has_effect_bundle("set_psw_tf_ex_btmmfs_2")
            local ejtzh_lv3 = psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_btmmfs_3")
            local ejtzh_lv0 = psw_faction_has_effect_bundle(faction_name, "set_btmmfs_yixiaoshi")
            local ejtzh_jiyizhi = psw_main_data.player_data[faction_name].ejtzh_jiyizhi or 100
            
            if not ejtzh_lv1 or ejtzh_lv0 then
                return
            end
            
            
            
            if ejtzh_lv1 and not ejtzh_lv2 and not ejtzh_lv3 and ejtzh_jiyizhi > ejtzh_jyz_gx_1 then
                psw_main_data.player_data[faction_name].ejtzh_jiyizhi = psw_main_data.player_data[faction_name].ejtzh_jiyizhi - ejtzh_jyz_gx_1
                psw_main_pickup(faction_name)
            elseif (ejtzh_lv2 or ejtzh_lv3) and ejtzh_jiyizhi > ejtzh_jyz_gx_2 then
                psw_main_data.player_data[faction_name].ejtzh_jiyizhi = psw_main_data.player_data[faction_name].ejtzh_jiyizhi - ejtzh_jyz_gx_2
                psw_main_pickup(faction_name)
            end
            psw_ejtzh_main_jyz(faction)
            psw_hh_start_btmmfs(faction_name)
        end
    end,
    true
)

------ 不死者之王-星星祈愿 ------
core:remove_listener("ui_psw_bszzw_xxqy")
core:add_listener("ui_psw_bszzw_xxqy",
    "UITrigger",
    function(context)
        return context:trigger():starts_with(psw_tf_nor_bszzw_nor)
    end,
    function(context)
        local faction = cm:model():faction_for_command_queue_index(context:faction_cqi())
        local faction_name = faction:name()
        
        if 1 == 1 then
            
            if not psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_nor_bszzw_nor") then
                return
            end
            local faction = cm:get_faction(faction_name)
            
            local bszzw_mlcl = psw_main_data.player_data[faction_name].bszzw_mlcl
            if bszzw_mlcl < 10 then
                return
            end
            psw_main_data.player_data[faction_name].bszzw_mlcl = psw_main_data.player_data[faction_name].bszzw_mlcl - 10
            cm:trigger_dilemma(faction_name, "dilemma_tf_zsqj_xuyuan")
        end
    end,
    true
)

------ 妖精之祝福-神力【妖精】 ------
core:remove_listener("ui_psw_yjzzf_slyj")
core:add_listener("ui_psw_yjzzf_slyj",
    "UITrigger",
    function(context)
        return context:trigger():starts_with(psw_tf_nor_yjdzf_nor)
    end,
    function(context)
        local faction = cm:model():faction_for_command_queue_index(context:faction_cqi())
        local faction_name = faction:name()
        local shenxing = faction:pooled_resource_manager():resource("psw_shenxing"):value()
        if shenxing < 6 or psw_faction_has_effect_bundle(faction_name, "yjzzf_yi_get") then
            return
        end
        if shenxing >= 6 then
            
            psw_add_ex_limit_jiefang(faction_name)
            
            psw_aplly_costom_effect_bundle_hidden_fn("yjzzf_yi_get", faction_name)
            psw_aplly_costom_effect_bundle_hidden_fn("set_qiyuan_100ex", faction_name)
            cm:callback(function()
                common.trigger_soundevent("alice_baodi")
                alice_main_advice_baodi()
            end, 6)
        end
    end,
    true
)

------ 优-金色的记忆 ------
core:remove_listener("ui_psw_jsdjy_zt")
core:add_listener("ui_psw_jsdjy_zt",
    "UITrigger",
    function(context)
        return context:trigger():starts_with(psw_tf_ex_you_ex)
    end,
    function(context)
        local faction = cm:model():faction_for_command_queue_index(context:faction_cqi())
        local faction_name = faction:name()
        
        if 1 == 1 then
            
            if not psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_ex_you_ex") then
                return
            end
            core:remove_listener("psw_jsdjy_zt")
            if not psw_faction_has_effect_bundle(faction_name, "jsdjy_zhufu") then
                return
            end
            
            cm:remove_effect_bundle("jsdjy_zhufu", faction_name)
            psw_aplly_costom_effect_bundle_hidden_fn("set_qiyuan_100zt", faction_name)
        end
    end,
    true
)



------ 姬宫真布-童话王国 ------
core:remove_listener("ui_psw_zhenbu_thwg")
core:add_listener("ui_psw_zhenbu_thwg",
    "UITrigger",
    function(context)
        return context:trigger():starts_with(psw_tf_ex_zhenbu_2)
    end,
    function(context)
        local faction = cm:model():faction_for_command_queue_index(context:faction_cqi())
        local faction_name = faction:name()
        
        if 1 == 1 then
            
            if not psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_ex_zhenbu_2") then
                return
            end
            
            local faction_leader = faction:faction_leader()
            local mf = faction_leader:military_force();
            local winds_of_magic = nil
            winds_of_magic = mf:pooled_resource_manager():resource("wh3_main_winds_of_magic")
            
            if winds_of_magic:is_null_interface() then
                return
            end
            local magic = winds_of_magic:value()
            
            if magic < 20 then
                return
            end
            
            local duration = math.floor(magic/20)
            
            local turn = cm:turn_number()
            local thwg_turn = psw_main_data.player_data[faction_name].thwg_turn
            local allow_turn = thwg_turn + duration + 3
            
            if turn < allow_turn then
                return
            end
            
            if faction:has_effect_bundle("psw_bundle_zhenbu_thwg") then
                cm:remove_effect_bundle("psw_bundle_zhenbu_thwg", faction_name)
            end
            local effect_bundle = cm:create_new_custom_effect_bundle("psw_bundle_zhenbu_thwg")
            local zhenbu_cost_magic = math.floor(magic/2)
            effect_bundle:set_duration(duration)
            effect_bundle:add_effect("wh2_dlc14_effect_magic_cost_all_lores_percentage", "faction_to_character_own", -zhenbu_cost_magic);
            effect_bundle:add_effect("wh3_main_effect_winds_of_magic_change_chance_mod", "faction_to_region_own", math.floor(magic/4));
            effect_bundle:add_effect("zhenbu_thwg", "faction_to_force_own", 1);
            cm:apply_custom_effect_bundle_to_faction(effect_bundle, faction)
            
            local zhenbu_ran = cm:random_number(100, 1)
            if zhenbu_ran <= 25 then
                common.trigger_soundevent("zhenbu_gllb_1")
            elseif zhenbu_ran <= 50 and zhenbu_ran > 25 then
                common.trigger_soundevent("zhenbu_gllb_2")
            elseif zhenbu_ran <= 75 and zhenbu_ran > 50 then
                common.trigger_soundevent("zhenbu_gllb_3")
            elseif zhenbu_ran <= 100 and zhenbu_ran > 75 then
                common.trigger_soundevent("zhenbu_gllb_4")
            end
            
            local zb_fac_list = cm:model():world():faction_list();
            for i = 0, zb_fac_list:num_items() - 1 do
                local crt_zhenbu_faction = zb_fac_list:item_at(i);
                local crt_zhenbu_faction_name = crt_zhenbu_faction:name();
                if crt_zhenbu_faction:is_human() == true then
                    psw_add_jishu_zhiyu(crt_zhenbu_faction_name, math.floor(magic/10))
                    if crt_zhenbu_faction:has_effect_bundle("psw_bundle_zhenbu_thwg_ally") then
                        cm:remove_effect_bundle("psw_bundle_zhenbu_thwg_ally", crt_zhenbu_faction_name)
                    end
                    local effect_bundle_2 = cm:create_new_custom_effect_bundle("psw_bundle_zhenbu_thwg_ally")
                    effect_bundle_2:set_duration(duration)
                    effect_bundle_2:add_effect("wh3_main_effect_winds_of_magic_events", "faction_to_force_own", math.floor(magic/10));
                    cm:apply_custom_effect_bundle_to_faction(effect_bundle_2, crt_zhenbu_faction)
                end
            end
            
            psw_main_data.player_data[faction_name].thwg_turn = turn
            psw_main_data.player_data[faction_name].thwg_duration = duration
            psw_main_data.player_data[faction_name].thwg_zhiyu_add = math.floor(magic/10)
            psw_aplly_costom_effect_bundle_hidden_fn("zhenbu_thwg_buff", faction_name)
        end
    end,
    true
)

------ 菲娅 - 菲娅的祝福 ------
core:remove_listener("ui_psw_fia_fydzf_click")
core:add_listener("ui_psw_fia_fydzf_click",
    "UITrigger",
    function(context)
        return context:trigger():starts_with(psw_tf_ex_fia_3)
    end,
    function(context)
        local faction = cm:model():faction_for_command_queue_index(context:faction_cqi())
        local faction_name = faction:name()
        
        if 1 == 1 then
            
            if not psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_ex_fia_3") then
                return
            end
            
            local fia_main_js = psw_main_data.player_data[faction_name].fia_main_js
            local fia_xiaohao_js = psw_main_data.player_data[faction_name].fia_xiaohao_js
            local fia_kyjs = fia_main_js - fia_xiaohao_js
            
            if fia_kyjs < 10 then
                return
            end
            
            cm:trigger_dilemma(faction_name, "dilemma_tf_fia_fydzf_1")
        end
    end,
    true
)

------ 爱蜜莉雅 - 觉醒 ------
core:remove_listener("ui_psw_tf_ex_amly_1")
core:add_listener("ui_psw_tf_ex_amly_1",
    "UITrigger",
    function(context)
        return context:trigger():starts_with(psw_tf_ex_amly_1)
    end,
    function(context)
        local faction = cm:model():faction_for_command_queue_index(context:faction_cqi())
        local faction_name = faction:name()
        
        
        if not psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_ex_amly_2") then
            
            if not psw_faction_has_effect_bundle(faction_name, "set_" .. "psw_tf_ex_amly_1") then
                return
            end
            
            local amly_clks_jishu = psw_main_data.player_data[faction_name].amly_clks_jishu
            local turn_number = cm:turn_number()
            local amly_jishu_bing = psw_main_data.player_data[faction_name].jishu_bing
            local amly_jishu_jingling = psw_main_data.player_data[faction_name].jishu_jingling
            
            
            local yx_subtype = psw_main_data.player_data[faction_name].yx_subtype
            local psw_main_character = cm:get_most_recently_created_character_of_type(faction, "general", yx_subtype)
            if psw_main_character:is_null_interface() or psw_main_character:is_wounded() or psw_main_character:is_at_sea() or not cm:char_is_general_with_army(psw_main_character) then
                return
            end
                
            ----- 虹 爱蜜莉雅 ------
            if (amly_clks_jishu >= 15 or turn_number >= 30) and amly_jishu_bing >= 3 and amly_jishu_jingling >= 3 and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_amly_1") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_amly_2") then
                local random_number_amly_face = cm:random_number(100, 1)
                local amly_bgm_gailv = 50
                if random_number_amly_face >= amly_bgm_gailv then
                    common.trigger_soundevent("amly_3_1")
                    advice_psw_tf_ex_amly_3_1()
                elseif random_number_amly_face < amly_bgm_gailv then
                    common.trigger_soundevent("amly_3_2")
                    advice_psw_tf_ex_amly_3_2_1()
                end
                
                psw_add_jishu_miansi(faction_name, 3)
                psw_add_hong_count(faction_name, 1)
                
                cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                    {
                    "psw_tf_ex_amly_3"
                    }
                )
                
                cm:remove_effect_bundle_from_character("jnz_tf_psw_tf_ex_amly_2", psw_main_character);
                cm:remove_effect_bundle("jnz_ex_amly_senjl", faction_name);
                cm:remove_effect_bundle("jnz_ex_amly_guangjl", faction_name);
                cm:remove_effect_bundle("jnz_ex_amly_yaojl", faction_name);
                cm:remove_effect_bundle("jnz_ex_amly_anjl", faction_name);
                cm:remove_effect_bundle("jnz_ex_amly_fengjl", faction_name);
                cm:remove_effect_bundle("jnz_ex_amly_huojingl", faction_name);
                cm:remove_effect_bundle("jnz_ex_amly_shuijl", faction_name);
                cm:remove_effect_bundle("jnz_ex_amly_dijingl", faction_name);
                
                psw_delete_shanbi_effect(faction_name, "jn_shanbi_amly_bjzb")
                cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_ex_amly_3", psw_main_character, 0);
                cm:apply_effect_bundle("jnz_ex_amly_8jl", faction_name, 0);
                
                psw_add_jishu_xingyun(faction_name, 2)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_amly_2", faction_name)
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_amly_3", faction_name)
                psw_aplly_costom_effect_bundle_hidden_fn("set_faction_hace_hong_ex", faction_name)
                
                if psw_faction_has_effect_bundle(faction_name, "set_amly_yjqh") then
                    psw_add_jishu_xingyun(faction_name, -2)
                end
                
                psw_add_jishu_zhongmo(5)

                
            ----- 冰结の魔女 ------
            
            elseif (amly_clks_jishu >= 15 or turn_number >= 30) and psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_amly_1") and not psw_faction_has_effect_bundle(faction_name, "set_psw_tf_ex_amly_2") then
                common.trigger_soundevent("amly_2")
                advice_psw_tf_ex_amly_2_1()
                
                
                cm:add_building_to_force(psw_main_character:military_force():command_queue_index(), 
                    {
                    "psw_tf_ex_amly_2"
                    }
                )
                cm:remove_effect_bundle_from_character("jnz_tf_psw_tf_ex_amly_1", psw_main_character);
                cm:apply_effect_bundle_to_character("jnz_tf_psw_tf_ex_amly_2", psw_main_character, 0);
                psw_add_jishu_moli(faction_name, 1)
                psw_add_jishu_xingyun(faction_name, 2)
                
                psw_aplly_costom_effect_bundle_hidden_fn("set_psw_tf_ex_amly_2", faction_name)
            end
            
        end
    end,
    true
)
