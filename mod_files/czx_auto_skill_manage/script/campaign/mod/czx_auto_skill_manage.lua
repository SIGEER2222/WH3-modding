local _LOG = "[czx_auto_skill_manage]"

local function _click_checkbox()
	local uic_holder = find_uicomponent(core:get_ui_root(), "character_details_panel", "auto_management_holder")
	if not uic_holder then
		return
	end
	local uic_cb = find_uicomponent(uic_holder, "checkbox_auto_management")
	if not uic_cb then
		return
	end
	local state = uic_cb:CurrentState()
	if state ~= "selected" and state ~= "selected_hover" and state ~= "selected_down" and state ~= "selected_inactive" then
		uic_cb:SimulateLClick()
		out(_LOG .. " auto-management enabled for character")
	end
end

local function _deferred_check()
	cm:callback(_click_checkbox, 0.1)
end

core:add_listener(
	"czx_auto_skill_manage_open",
	"PanelOpenedCampaign",
	function(context)
		return context.string == "character_details_panel" or context.string == "character_panel"
	end,
	_deferred_check,
	true
)

core:add_listener(
	"czx_auto_skill_manage_click",
	"ComponentLClickUp",
	function(context)
		return find_uicomponent(core:get_ui_root(), "character_details_panel", "auto_management_holder") ~= nil
	end,
	_deferred_check,
	true
)

out(_LOG .. " installed")
