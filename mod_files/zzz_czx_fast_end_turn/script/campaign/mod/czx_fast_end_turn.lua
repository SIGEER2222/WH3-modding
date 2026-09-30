-- czx_fast_end_turn.lua
-- 过回合显示选项：把 军队/英雄/舰队 的观察移动速度设为“最快”，
-- 并让设置作用于“全部”派系分组，缩短每回合等待时间。
-- 数据面：这些下拉背后是模型层 observation_options（原版 prologue 实证，
-- wh3_prologue_kislev_expedition_stage_1.lua:590），非 UI 组件状态——
-- 直接走模型 API 写入，不再 SimulateLClick 点开下拉。
local _LOG = "[czx_fast_end_turn]"

-- 观察速度枚举（zz_obs_probe 实测枚举全集）：NORMAL / FAST / VERYFAST。
-- "最快" = VERYFAST；SLOW/FASTEST/VERY_FAST 等非法值被引擎静默拒绝（保持原值）。
local SPEED_VALUE = "VERYFAST"
-- 镜头跟随枚举：OFF/LOW/MEDIUM/HIGH/VERYHIGH；置 nil 表示不动镜头列。
local CAMERA_VALUE = nil

-- 观察选项分组 ↔ 原版面板作用范围按钮映射（apply_all = 四组全写）
local _OBS_SCOPES = {
	{ get = "observation_options_for_faction",  set = "set_character_observation_options_for_faction",  tag = "faction" },
	{ get = "observation_options_for_allies",   set = "set_character_observation_options_for_allies",   tag = "allies" },
	{ get = "observation_options_for_enemies",  set = "set_character_observation_options_for_enemies",  tag = "enemies" },
	{ get = "observation_options_for_neutrals", set = "set_character_observation_options_for_neutrals", tag = "neutrals" },
}
local _OBS_RECS = {
	{ get = "armies_options", set = "set_armies_options" },   -- 军队
	{ get = "agents_options", set = "set_agents_options" },   -- 英雄/事务官
	{ get = "navies_options", set = "set_navies_options" },   -- 舰队
}

-- 实测结论（zz_obs_probe 九轮）：
--  * observation_options_for_faction(a,b) 的 b 被引擎忽略——返回 OPT[a]，
--    即"派系 a 自己的观察选项"一系一录。
--  * set_character_observation_options_for_faction(f, obs) 可写任意派系
--    的 OPT[f]（远程派系实测落库），全量 799 派系写入仅 ~4ms。
--  * observation_options_for_allies/enemies/neutrals 三组 getter 返回的是
--    不绑定模型的默认对象（写后读恒 NORMAL、多实例互不影响）——组 setter
--    调用照常发（原生 apply 按钮同款，harmless），但不做组 getter 回读。
--  * 覆盖策略：枚举全部派系逐写 OPT[f] + 组 setter 兜底——无论引擎读
--    观察方记录还是被观察方记录都全命中。
local function _write_one(world, f)
	local ok1, obs = pcall(function() return world:observation_options_for_faction(f, f) end)
	if not (ok1 and obs) then return false end
	for _, rec in ipairs(_OBS_RECS) do
		local ok2, ro = pcall(function() return obs[rec.get](obs) end)
		if ok2 and ro then
			pcall(function() ro:set_locomotion_speed(SPEED_VALUE) end)
			if CAMERA_VALUE then
				pcall(function() ro:set_camera_follow_behaviour(CAMERA_VALUE) end)
			end
			pcall(function() obs[rec.set](obs, ro) end)
		end
	end
	return pcall(function() return cm:set_character_observation_options_for_faction(f, obs) end)
end

local function _apply_all()
	local ok_f, faction = pcall(function() return cm:get_faction(cm:get_local_faction_name()) end)
	if not (ok_f and faction) then
		out(_LOG .. " no local faction, skip")
		return
	end
	local world = cm:model():world()
	local n, nfail = 0, 0
	local flist = world:faction_list()
	for i = 0, flist:num_items() - 1 do
		if _write_one(world, flist:item_at(i)) then n = n + 1 else nfail = nfail + 1 end
	end
	out(_LOG .. " per-faction writes ok=" .. n .. " fail=" .. nfail)
	-- 组 setter 兜底（原生 apply_* 按钮同款接口；组 getter 不可回读故只发不验）
	local ok_g, g_obs = pcall(function() return world:observation_options_for_faction(faction, faction) end)
	if ok_g and g_obs then
		for _, scope in ipairs(_OBS_SCOPES) do
			if scope.tag ~= "faction" then
				local ok3 = pcall(function() return cm[scope.set](cm, faction, g_obs) end)
				out(_LOG .. " scope " .. scope.tag .. " -> " .. tostring(ok3))
			end
		end
	end
	-- 本地派系记录回读核验
	local rb = world:observation_options_for_faction(faction, faction)
	for _, rec in ipairs(_OBS_RECS) do
		local ok5, cur = pcall(function()
			return rb[rec.get](rb):locomotion_speed()
		end)
		out(_LOG .. "   readback me." .. rec.get .. "=" .. tostring(ok5 and cur or "?"))
	end
end

-- 9.0：加载屏消失级联窗口（LoadingScreenDismissed 逐个内联跑回调 +
-- intro_movie overlay show 动画初始化并发）内任何原生 UI 写都可能踩到
-- 半销毁组件——读 null+0x58 @ +0x22c0f80 / 写哨兵 @ +0x22c8774·+0x132c34c。
-- 历史上 SimulateLClick 点 armies/heroes 下拉在该窗口 + UI 持锁期多次
-- 同址崩（0728 会话末行即 dropdown_armies_speed clicked option2）。
-- 现已改为模型层 observation_options 直写，不再派发原生 UI 回调——
-- 门控意义随之从"防崩"降为"防被原版 intro 脚本覆盖"：原版派系开场
-- （prologue/faction_intro）会在 intro 期间自行写观察选项，过早写入
-- 会被覆盖回默认值，所以仍等 end_cinematic + 稳定窗再写。

-- 任意 movie_overlay_* 根组件存在 = intro 覆盖层播放中/尚未销毁
local function _movie_overlay_present()
	local root = core:get_ui_root()
	if not root then return false end
	for i = 0, root:ChildCount() - 1 do
		local ok, c = pcall(function() return UIComponent(root:Find(i)) end)
		if ok and c and string.sub(tostring(c:Id()), 1, 14) == "movie_overlay_" then
			return true
		end
	end
	return false
end

local _polls = 0
local _stable = 0
local _MIN_POLLS = 15   -- ~30s 游戏时起步宽限
local _STABLE_NEEDED = 10 -- 全绿须连续维持 ~20s（10 次×2s）才放行
-- 注意：has_intro_cutscene_played 对播片被遮蔽的新战役提前置位（flyover 与
-- 开局面板链尚未跑），不能当"intro 完结"信号用——1429 会话它让点击落在
-- dismiss 级联 +1.4s 处（303.8s），崩点 ~321s 同窗口。改用连续稳定判据。
-- §10.40 v3 死区盲区（09-27 三连崩复核）：级联结束→flyover 起步间有 ~40s
-- 静默带，瞬时判据在死区全绿、提前 ~10-25s 放行，点击落进死区后剧场起步
-- 即崩。新战役必须等到 flyover 剧场的 CinematicTrigger end_cinematic。
local _cine_done = true
local _cine_armed = false
local function _arm_cine_gate()
	if _cine_armed then return end
	_cine_armed = true
	local ok_ng, ng = pcall(function() return cm:is_new_game() end)
	if not (ok_ng and ng) then return end          -- 读档局无 intro
	_cine_done = false
	pcall(function()
		core:add_listener(
			"czx_fet_cine_end",
			"CinematicTrigger",
			function(c) return c.string == "end_cinematic" end,
			function() _cine_done = true end,
			false
		)
	end)
	-- 无 flyover 的战役兜底：150s 后照常放行
	cm:real_callback(function() _cine_done = true end, 150000, "czx_fet_cine_cap")
end

local function _safe_now()
	if not _cine_done then return false end
	-- loading screen 组件仍在 = dismiss 级联未跑完
	local ok_ls, _, ls_uic = pcall(function() return core:get_loading_screen() end)
	if ok_ls and ls_uic then return false end
	if _movie_overlay_present() then return false end
	local ok_play, playing = pcall(function() return cm:is_intro_cutscene_playing() end)
	if ok_play and playing then return false end
	local ok_cs, any_cs = pcall(function() return cm:is_any_cutscene_running() end)
	if ok_cs and any_cs then return false end
	-- AI 回合处理中禁止写入：799 派系的 observation 直写与逐派系 FactionTurnStart
	-- 原生数组重建并发 = +0x132c34c 写型 UAF（09-29 2252 会话 apply 落点与崩点同 tick）。
	-- whose_turn_is_it 列表非空且不含本地派系 = AI 处理段，继续等下个玩家回合。
	local ok_t, ai_turn = pcall(function()
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
	if ok_t and ai_turn then return false end
	return true
end

local _applied = false
local function _apply_when_safe()
	if _applied then return end
	_polls = _polls + 1
	if _safe_now() then
		_stable = _stable + 1
	else
		_stable = 0
	end
	if _polls < _MIN_POLLS or _stable < _STABLE_NEEDED then
		cm:callback(_apply_when_safe, 2)
		return
	end
	_applied = true
	-- 兜底：确保过回合 fast-forward 开关处于开启
	-- 图形与内存偏好由 preferences 配置管理，不在战役首帧动态切换。
	common.call_context_command("SetPrefAsBool('fast_forward_end_turns', true)")
	_apply_all()
	out(_LOG .. " applied (polls=" .. _polls .. ")")
end

cm:add_first_tick_callback(function()
	if cm:is_multiplayer() then return end
	_arm_cine_gate()
	cm:callback(_apply_when_safe, 2)
	out(_LOG .. " installed")
end)
