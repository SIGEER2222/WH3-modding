-- zzz_czx_treasury_guard: shadow of !ai_treasury.pack's ai_treasury.lua
-- §10.40（2026-09-28 +0x22c8774 会话复盘）：原版 interval=0 的 RealTimeTrigger
-- 每帧对 diplomacy_dropdown 子树跑 find_uicomponent 全链遍历，且只要节点在树里
-- 就每帧调 SetStateText/SetTooltipText 原生写——post-battle/teardown 重建该子树
-- 时就是常驻写 UAF 轮盘，崩窗静默期里唯一还在写 UI 的 mod 路径。
-- 修补：①间隔 0→500ms；②先查 ui_locked（Lua 字段，不碰树）；
-- ③dropdown 实际可见才写（外交界面关着时 tooltip 本来也没人看）。
-- 同路径遮蔽：本包必须排在 !ai_treasury.pack 之前（靠前胜出）。

local function ai_treasury()
    local player_faction = cm:get_local_faction(true)
    local text = common.get_localised_string("uied_component_texts_localised_string_treasury_icon_Tooltip_560030") .. ": "
    local text2 = common.get_localised_string("random_localisation_strings_string_predicted_income") .. ": "
    local text3 = "\n" .. common.get_localised_string("uied_component_texts_localised_string_tx_slaves_income_NewState_Text_4a000b") .. ": "
    local text4 = "\n" .. common.get_localised_string("uied_component_texts_localised_string_ComponentText_6bbe7f99") .. ": "
    local text5 = common.get_localised_string("campaign_localised_strings_string_varying_regular_income_trade") .. ": "

    local function ui_locked()
        local ok, uim = pcall(function() return cm:get_campaign_ui_manager() end)
        return ok and uim and uim.ui_locked or false
    end

    core:add_listener(
        "ai_treasury_RealTimeTrigger",
        "RealTimeTrigger",
        function(context)
            return context.string == "ai_treasury_real_timer_adjust"
        end,
        function()
            if ui_locked() then return end
            local diplomacy_dropdown = find_uicomponent(core:get_ui_root(), "diplomacy_dropdown")
            if not diplomacy_dropdown then return end
            local ok_vis, vis = pcall(function() return diplomacy_dropdown:Visible(true) end)
            if not ok_vis then
                ok_vis, vis = pcall(function() return diplomacy_dropdown:Visible() end)
            end
            if not ok_vis or not vis then return end
            local r_subpanel_list = find_uicomponent(diplomacy_dropdown, "faction_right_status_panel", "subpanel_list")
            local l_subpanel_list = find_uicomponent(diplomacy_dropdown, "faction_left_status_panel", "subpanel_list")

            local r_list_box = find_uicomponent(r_subpanel_list, "attributes_holder", "trait_list", "list_clip", "list_box")
            local r_trait1 = find_uicomponent(r_list_box,"trait1")
            local r_trait = find_uicomponent(r_list_box,"trait")
            if not r_trait then
                r_trait = UIComponent(r_trait1:CopyComponent("trait"))
            end
            local icon_threat = find_uicomponent(r_subpanel_list, "faction_holder", "icon_threat")
            local faction_key = icon_threat:GetContextObjectId("CcoCampaignFaction")
            local faction = cm:get_faction(faction_key)
            local r_treasury = faction:treasury()
            r_trait1:SetStateText(text .. r_treasury)
            --r_trait1:SetTooltipText(common.get_localised_string("factions_screen_name_"..faction_key),true)
            r_trait1:SetTooltipText(text2 .. faction:net_income() .. text3 .. faction:income() .. text4 .. faction:upkeep() .. text5 .. faction:trade_value(),true)

            local l_list_box = find_uicomponent(l_subpanel_list, "attributes_holder", "trait_list", "list_clip", "list_box")
            local l_trait1 = find_uicomponent(l_list_box,"trait1")
            local l_trait = find_uicomponent(l_list_box,"trait")
            if not l_trait then
                l_trait = UIComponent(l_trait1:CopyComponent("trait"))
            end
            local l_treasury = player_faction:treasury()
            --local income = common.get_context_value("CcoCampaignFaction", player_faction:command_queue_index(), "Income")
            l_trait1:SetStateText(text .. l_treasury)
            l_trait1:SetTooltipText(text2 .. player_faction:net_income() .. text3 .. player_faction:income() .. text4 .. player_faction:upkeep().. text5 .. player_faction:trade_value(),true)
        end,
    true)

end

cm:add_first_tick_callback(function()
    ai_treasury()
    real_timer.unregister("ai_treasury_real_timer_adjust")
    real_timer.register_repeating("ai_treasury_real_timer_adjust", 500)
end);
