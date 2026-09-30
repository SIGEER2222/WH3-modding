local _LOG = "[czx_auto_skill_manage]"

-- §10.40：干预级联 lock_ui 持锁期 UI 树在拆，find_uicomponent/组件调用
-- 撞半销毁节点 = +0x22c0f80 族原生 UAF。uim.ui_locked 是 Lua 侧表字段，
-- 不碰原生树，必须先于任何树遍历判。
local function _ui_locked()
	local ok, uim = pcall(function() return cm:get_campaign_ui_manager() end)
	return not (ok and uim) or uim.ui_locked == true
end

local _click_checkbox  -- 前置声明，_deferred_check 里递归调度用

_click_checkbox = function()
	if _ui_locked() then
		return false
	end
	local uic_holder = find_uicomponent(core:get_ui_root(), "character_details_panel", "auto_management_holder")
	if not uic_holder then
		return false
	end
	local uic_cb = find_uicomponent(uic_holder, "checkbox_auto_management")
	if not uic_cb then
		return false
	end
	-- 首选：直接读写 CCO（引擎态 IsAutoManaging），不依赖 state 名清单
	local ok_ctx, ctx_obj = pcall(function() return uic_cb:GetContextObject("CcoCampaignCharacterAutoManagement") end)
	if ok_ctx and ctx_obj then
		local ok_m, managing = pcall(function() return ctx_obj:Call("IsAutoManaging") end)
		if ok_m then
			if not managing then
				local ok_t = pcall(function() ctx_obj:Call("ToggleAutoManaging") end)
				if ok_t then
					out(_LOG .. " auto-management enabled for character (cco)")
				end
			end
			return true
		end
	end
	-- 兜底：组件状态判定 + SimulateLClick
	local state = uic_cb:CurrentState()
	if state ~= "selected" and state ~= "selected_hover" and state ~= "selected_down" and state ~= "selected_inactive" then
		uic_cb:SimulateLClick()
		out(_LOG .. " auto-management enabled for character")
	end
	return true
end

-- 面板打开/点击时做有限重试：技能页子树按需构建，单次 0.1s 快照可能撞上懒建
local function _deferred_check()
	cm:callback(function()
		if _click_checkbox() then return end
		local tries = 0
		local function retry()
			-- 面板已关就停，不追着不存在的树跑
			if not find_uicomponent(core:get_ui_root(), "character_details_panel") then return end
			tries = tries + 1
			if tries > 6 or _click_checkbox() then return end
			cm:callback(retry, 0.5)
		end
		cm:callback(retry, 0.5)
	end, 0.1)
end

-- §10.40：loading-dismiss→intro 窗口内，本监听器的 condition 对*每次*点击都做
-- find_uicomponent 全树遍历，撞上半销毁节点是原生侧 UAF（Lua xpcall 兜不住，
-- 1452 会话同型的 czx_overlay_default 监听器 cascade+0.2s 内联跑 → flyover
-- 起步即崩）。落定前一律放行不进树。
local _settled = false
local function _overlay_present()
	local ok_root, root = pcall(function() return core:get_ui_root() end)
	if not ok_root or not root then return false end
	local ok_n, n = pcall(function() return root:ChildCount() end)
	if not ok_n or not n then return false end
	for i = 0, n - 1 do
		local ok_c, c = pcall(function() return UIComponent(root:Find(i)) end)
		if ok_c and c then
			local ok_id, id = pcall(function() return c:Id() end)
			if ok_id and id and string.sub(tostring(id), 1, 14) == "movie_overlay_" then
				return true
			end
		end
	end
	return false
end

local function _hazards_clear()
	local ok_play, playing = pcall(function() return cm:is_intro_cutscene_playing() end)
	if ok_play and playing then return false end
	local ok_cs, any_cs = pcall(function() return cm:is_any_cutscene_running() end)
	if ok_cs and any_cs then return false end
	local ok_ls, ls_uic = pcall(function()
		local _, u = core:get_loading_screen()
		return u
	end)
	if ok_ls and ls_uic then return false end
	if _overlay_present() then return false end
	return true
end

cm:add_first_tick_callback(function()
	local polls = 0
	local stable = 0
	local MIN_POLLS = 15      -- ~30s 墙钟起步宽限
	local STABLE_NEEDED = 6   -- 连续 6 次（~12s）全绿
	local function probe_when_settled()
		polls = polls + 1
		if _hazards_clear() then
			stable = stable + 1
		else
			stable = 0
		end
		if polls >= MIN_POLLS and stable >= STABLE_NEEDED then
			_settled = true
			return
		end
		cm:real_callback(probe_when_settled, 2000, "czx_skill_manage_probe")
	end
	cm:real_callback(probe_when_settled, 2000, "czx_skill_manage_probe")
end)

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
		if not _settled then return false end
		if _ui_locked() then return false end
		-- §10.40：派发窗口内不再 find_uicomponent 全树遍历（撞半建/半毁节点 UAF）。
		-- uim:is_panel_open 是 Lua 侧记录表查询，零树访问；真正的树查找放 0.1s 后
		-- 的 _deferred_check 里做（出派发窗，且带持锁复查）。
		local ok, open = pcall(function() return cm:get_campaign_ui_manager():is_panel_open("character_details_panel") end)
		return ok and open == true
	end,
	_deferred_check,
	true
)

out(_LOG .. " installed")
