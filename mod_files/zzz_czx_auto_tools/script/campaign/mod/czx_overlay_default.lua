-- czx_overlay_default.lua
-- 战役地图轮廓默认"外交状态"，屏蔽"所有者"选项
-- options_list 子项 id 对照：overlay_ownership(所有者) / overlay_diplomatic_status(外交状态) 等

local _LOG = "[czx_overlay_default]"

local function czx_overlay_apply()
    local options_list = find_uicomponent(core:get_ui_root(), "campaign_space_bar_options", "background", "options_list")
    if not options_list then
        return false
    end
    for i = 0, options_list:ChildCount() - 1 do
        local slot = UIComponent(options_list:Find(i))
        if slot:Id() == "overlay_ownership" then
            if slot:Visible() then
                slot:SetVisible(false)
                out(_LOG .. " ownership row hidden")
            end
        elseif slot:Id() == "overlay_diplomatic_status" then
            local radio = find_uicomponent(slot, "radio_button")
            if radio then
                local state = radio:CurrentState()
                if state ~= "selected" and state ~= "selected_hover" and state ~= "selected_down" then
                    radio:SimulateLClick()
                    out(_LOG .. " diplomatic_status selected")
                end
            end
        end
    end
    return true
end

cm:add_first_tick_callback(function()
    cm:callback(function()
        if not czx_overlay_apply() then
            cm:callback(czx_overlay_apply, 2.0)
        end
    end, 0.5)
end)

-- 面板重开/重排后 ownership 又可见时重新屏蔽
core:add_listener(
    "czx_overlay_default_guard",
    "ComponentLClickUp",
    function(context)
        local ownership = find_uicomponent(core:get_ui_root(), "campaign_space_bar_options", "background", "options_list", "overlay_ownership")
        return ownership ~= nil and ownership:Visible()
    end,
    function(context)
        czx_overlay_apply()
    end,
    true
)

out(_LOG .. " installed")
