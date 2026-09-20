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
    core:add_listener(
        "czx_disband_panel_open",
        "PanelOpenedCampaign",
        function(context)
            return context.string == "units_panel"
        end,
        function(context)
            local button_parent = find_uicomponent(core:get_ui_root(), "hud_campaign", "hud_center_docker", "hud_center", "small_bar", "button_subpanel_parent", "button_subpanel", "button_group_army")
            if button_parent then
                local btn = core:get_or_create_component("czx_button_disband_army", "ui/templates/square_medium_button.twui.xml", button_parent)
                if btn then
                    btn:SetImagePath("ui/skins/default/icon_cross_square.png")
                    btn:SetTooltipText(disband_txt, true)
                end
            end
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
            local mf = character:military_force()
            if not mf then return end
            local unit_list = mf:unit_list()
            -- item_at(0) is the commander's own unit; keep it
            for i = 1, unit_list:num_items() - 1 do
                cm:remove_unit_from_character(cm:char_lookup_str(character), unit_list:item_at(i):unit_key())
            end
            out(">>> czx_disband >>> disbanded all units of " .. tostring(character:character_type_key()))
        end, 0)
    end,
    true
)
