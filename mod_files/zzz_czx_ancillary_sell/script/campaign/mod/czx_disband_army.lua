---------------------------------------------------------------------------------------------------
-- czx_disband_army.lua
-- One-click "disband all units" button on the army button bar (button_group_army).
-- Reuses the starting-army replacement approach: cm:remove_unit_from_character per unit
-- (engine keeps the general's own unit, so the lord survives).
---------------------------------------------------------------------------------------------------

local disband_txt = "Disband all units in this army (lord is kept)"
local language = common.get_context_value("LocLanguage")
if language == "CN" or language == "ZH" then
    disband_txt = "一键撤编：解散该部队全部单位（将领保留）"
end

cm:add_first_tick_callback(function()
    -- create the button whenever the units panel opens with an army selected
    -- §10.40：PanelOpened 派发窗口内面板子树还在建/拆，内联 find_uicomponent+
    -- CreateComponent 撞半构建节点 = +0x22c0f80 族 UAF（2052/2125 会话崩在
    -- units_panel open 后 <0.5s）。推迟 0.3s 出派发窗，且 lock_ui 级联/面板已关
    -- 时直接弃本轮（uim.ui_locked 是 Lua 表字段，零原生树访问，先于树遍历判）。
    core:add_listener(
        "czx_disband_panel_open",
        "PanelOpenedCampaign",
        function(context)
            return context.string == "units_panel"
        end,
        function(context)
            cm:callback(function()
                local ok_uim, uim = pcall(function() return cm:get_campaign_ui_manager() end)
                if not ok_uim or not uim or uim.ui_locked then return end
                local ok_open, open = pcall(function() return uim:is_panel_open("units_panel") end)
                if not (ok_open and open) then return end
                -- AI 回合：引擎为镜头跟随的 AI 军队开 units_panel 时子树高频拆建，
                -- 此时 CreateComponent 写进半析构树 = +0x22c0f80 族（09-29 2232 会话）。
                -- AI 面板无交互价值，整轮跳过。
                local ok_ai, ai_turn = pcall(function()
                    local list = cm:whose_turn_is_it()
                    if not list then return false end
                    local me = cm:get_local_faction_name(true)
                    local any = false
                    for _, f in model_pairs(list) do
                        any = true
                        if me and me ~= "" and f:name() == me then return false end
                    end
                    return any
                end)
                if ok_ai and ai_turn then return end
                out("[czx_disband] deferred create begin") -- canary
                local button_parent = find_uicomponent(core:get_ui_root(), "hud_campaign", "hud_center_docker", "hud_center", "small_bar", "button_subpanel_parent", "button_subpanel", "button_group_army")
                if button_parent then
                    local btn = core:get_or_create_component("czx_button_disband_army", "ui/templates/square_medium_button.twui.xml", button_parent)
                    if btn then
                        btn:SetImagePath("ui/skins/default/icon_cross_square.png")
                        btn:SetTooltipText(disband_txt, true)
                    end
                end
                out("[czx_disband] deferred create done") -- canary
            end, 0.3)
        end,
        true
    )

    core:add_listener(
        "czx_disband_click",
        "ComponentLClickUp",
        function(context)
            return context.string == "czx_button_disband_army"
        end,
        function(context)
            local cqi = common.get_context_value("SelectedOrContainedCharacter.CQI")
            if cqi then
                CampaignUI.TriggerCampaignScriptEvent(cqi, "czx_disband_army|")
            end
        end,
        true
    )
end)

-- server side: remove every unit of the character's military force (lord unit is protected by the engine)
core:add_listener(
    "czx_disband_army_UITrigger",
    "UITrigger",
    function(context)
        return context:trigger():starts_with("czx_disband_army|")
    end,
    function(context)
        local character = cm:get_character_by_cqi(context:faction_cqi())
        if not character or not character:faction():is_human() then return end
        cm:callback(function()
            -- 原版 for 循环持一次抓取的 unit_list 逐个 remove——每删一个底层容器
            -- 即变，后续 item_at 读悬空槽（与 starting_units RemoveStartingArmy 同款
            -- 隐患，2026-10-02 修复）。改为每 tick 重取列表、固定删 item_at(1)
            --（item_at(0) 是将领亲卫位，引擎也保护），角色接口失效即停。
            local char_str = cm:char_lookup_str(character)
            local function step_disband()
                local ok, left = pcall(function()
                    local mf = character:military_force()
                    if not mf then return 0 end
                    local ul = mf:unit_list()
                    if not ul or ul:num_items() <= 1 then return 0 end
                    cm:remove_unit_from_character(char_str, ul:item_at(1):unit_key())
                    return ul:num_items()
                end)
                if ok and left and left > 1 then
                    cm:callback(step_disband, 0.15)
                elseif ok then
                    out(">>> czx_disband >>> disbanded all units of " .. tostring(character:character_type_key()))
                end
            end
            step_disband()
        end, 0)
    end,
    true
)
