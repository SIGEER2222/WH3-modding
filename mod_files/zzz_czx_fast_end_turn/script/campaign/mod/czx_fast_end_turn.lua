-- czx_fast_end_turn.lua
-- 过回合显示选项：把 军队/英雄/舰队 的“速度”下拉默认拉到“最快”，
-- 并让设置作用于“全部”派系分组，缩短每回合等待时间。
-- 面板：settings_panel > camera_settings > dropdowns_list > {armies,heroes,fleets}
--        每行 dropdown_<row>_speed / dropdown_<row>_camera
--        apply_all/apply_allies/apply_current_faction/apply_enemies/apply_neutrals 选作用范围
local _LOG = "[czx_fast_end_turn]"

-- 速度列目标文本（本地化选项名）。原版 loc: end_turn_camera_settings_fast = 最快 / Fastest
local SPEED_OPTION = { "最快", "Fastest" }
-- 镜头列目标文本；置 nil 表示不动镜头列。
-- 可选 "关闭"/"Off"（完全不跟随 AI 行动，过回合最快，但看不到敌方行动画面）。
local CAMERA_OPTION = nil
-- 作用范围按钮：apply_all = 全部派系
local APPLY_BUTTON = "apply_all"

local function _match(txt, targets)
	if not txt then return false end
	for _, t in ipairs(targets) do
		if txt == t then return true end
	end
	return false
end

-- 在 popup_list 里找目标选项行；找不到目标文本时回退到最后一行
local function _pick_option(list_uic, targets)
	local fallback
	for i = 0, list_uic:ChildCount() - 1 do
		local opt = UIComponent(list_uic:Find(i))
		if opt and opt:Id() ~= "row_example" then
			local tx = find_uicomponent(opt, "row_tx")
			local s = tx and tx:GetStateText() or nil
			out(_LOG .. " option[" .. i .. "] id=" .. tostring(opt:Id()) .. " text=" .. tostring(s))
			if _match(s, targets) then
				return opt
			end
			fallback = opt
		end
	end
	return fallback
end

-- 点开下拉并选择目标项；popup 可能需要一帧填充，做有限重试
local function _set_dropdown(dropdown_id, targets, attempt)
	attempt = attempt or 1
	local dd = find_uicomponent(core:get_ui_root(), dropdown_id)
	if not dd then
		if attempt <= 10 then
			cm:callback(function() _set_dropdown(dropdown_id, targets, attempt + 1) end, 0.5)
		end
		return
	end
	local selected = find_uicomponent(dd, "dy_selected_txt")
	local s = selected and selected:GetStateText() or nil
	if _match(s, targets) then
		out(_LOG .. " " .. dropdown_id .. " already=" .. tostring(s))
		return
	end
	dd:SimulateLClick()
	cm:callback(function()
		local list = find_uicomponent(dd, "popup_menu", "popup_list")
		if not list or list:ChildCount() == 0 then
			if attempt <= 10 then
				_set_dropdown(dropdown_id, targets, attempt + 1)
			end
			return
		end
		local opt = _pick_option(list, targets)
		if opt then
			opt:SimulateLClick()
			out(_LOG .. " " .. dropdown_id .. " -> clicked " .. tostring(opt:Id()))
		end
	end, 0.1)
end

local function _apply_all()
	-- 先选“全部”派系分组，再调各速度下拉
	local btn = find_uicomponent(core:get_ui_root(), APPLY_BUTTON)
	if btn then
		btn:SimulateLClick()
		out(_LOG .. " scope -> " .. APPLY_BUTTON)
	else
		out(_LOG .. " scope button not found: " .. APPLY_BUTTON)
	end
	for _, row in ipairs({ "armies", "heroes", "fleets" }) do
		_set_dropdown("dropdown_" .. row .. "_speed", SPEED_OPTION)
		if CAMERA_OPTION then
			_set_dropdown("dropdown_" .. row .. "_camera", CAMERA_OPTION)
		end
	end
end

cm:add_first_tick_callback(function()
	if cm:is_multiplayer() then return end
	common.call_context_command("SetPrefAsBool('fast_forward_end_turns', true)")
	-- 兜底：确保过回合 fast-forward 开关处于开启
	-- 图形与内存偏好由 preferences 配置管理，不在战役首帧动态切换。
	cm:callback(_apply_all, 0.5)
	out(_LOG .. " installed")
end)
