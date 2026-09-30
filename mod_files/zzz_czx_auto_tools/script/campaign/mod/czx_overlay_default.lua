-- czx_overlay_default.lua
-- 战役地图轮廓默认"外交状态"，屏蔽"所有者"选项
-- options_list 子项 id 对照：overlay_ownership(所有者) / overlay_diplomatic_status(外交状态) 等

local _LOG = "[czx_overlay_default]"

local function czx_overlay_apply()
    -- §10.40：lock_ui 级联持锁期 UI 树在拆，树遍历/组件写 = +0x22c0f80 族 UAF
    local ok_uim, uim = pcall(function() return cm:get_campaign_ui_manager() end)
    if not ok_uim or not uim or uim.ui_locked then return false end
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

-- §10.40：find_uicomponent/SimulateLClick 落在 loading-dismiss→intro 窗口
-- 内会命中半销毁组件（UAF 读/写崩溃族）。cm:callback 在 loading 期不走表、
-- 堆积到 dismiss 瞬间一起触发——先等 intro 序列完结再开始探测。
-- 注意：has_intro_cutscene_played 对播片被遮蔽的新战役提前置位（flyover 与
-- 开局面板链尚未跑），不能当"intro 完结"信号用（1429 会话它让本 mod 的点击
-- 落在 dismiss 动画进行中 301.9s，崩点 ~321s）——改用连续稳定判据：
-- 无加载屏 + 无 movie_overlay + 无过场，连续 ~12s 全绿才动手。

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

-- §10.40 v3 死区盲区（09-27 三连崩复核）：级联结束→flyover 起步间有 ~40s
-- 静默带，瞬时判据在死区全绿、门控提前放行（本 mod 曾在 307.6s 改 overlay/
-- diplomatic_status，flyover 320.5s 起步即崩）。新战役须见到 flyover 剧场的
-- CinematicTrigger end_cinematic 才算落定；cap 兜底无 flyover 的战役。
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
            "czx_overlay_cine_end",
            "CinematicTrigger",
            function(c) return c.string == "end_cinematic" end,
            function() _cine_done = true end,
            false
        )
    end)
    cm:real_callback(function() _cine_done = true end, 150000, "czx_overlay_cine_cap")
end

-- §10.40 v4：UI 锁/面板忙期间连隐藏行/选标签这类写也会踩半析构组件。
-- uim.ui_locked / panels_open 是 Lua 侧字段——不碰原生树，先于树遍历判。
local function _ui_idle()
    local ok_uim, uim = pcall(function() return cm:get_campaign_ui_manager() end)
    if not ok_uim or not uim then return false end
    if uim.ui_locked then return false end
    local ok_bp, blocking = pcall(function() return uim:get_open_blocking_panel() end)
    if ok_bp and blocking then return false end
    local ok_ev, events_open = pcall(function() return uim:is_panel_open("events") end)
    if ok_ev and events_open then return false end
    local ok_bat, processing = pcall(function() return cm:is_processing_battle() end)
    if ok_bat and processing then return false end
    return true
end

local function _hazards_clear()
    if not _cine_done then return false end
    local ok_play, playing = pcall(function() return cm:is_intro_cutscene_playing() end)
    if ok_play and playing then return false end
    local ok_cs, any_cs = pcall(function() return cm:is_any_cutscene_running() end)
    if ok_cs and any_cs then return false end
    if not _ui_idle() then return false end
    local ok_ls, ls_uic = pcall(function()
        local _, u = core:get_loading_screen()
        return u
    end)
    if ok_ls and ls_uic then return false end
    if _overlay_present() then return false end
    return true
end

local _settled = false  -- intro/级联窗口全过后才放行：监听器路径也要被门控

cm:add_first_tick_callback(function()
    _arm_cine_gate()
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
            if not czx_overlay_apply() then
                cm:callback(czx_overlay_apply, 2.0)
            end
        else
            cm:real_callback(probe_when_settled, 2000, "czx_overlay_probe")
        end
    end
    cm:real_callback(probe_when_settled, 2000, "czx_overlay_probe")
end)

-- 面板重开/重排后 ownership 又可见时重新屏蔽。
-- §10.40：未落定前 condition 直接否——此条件对*每次*点击都做 find_uicomponent
-- 全树遍历，级联窗口内撞上半销毁节点是原生侧 UAF，Lua xpcall 兜不住；
-- 条件真时回调里的 SetVisible/SimulateLClick 同是窗口内 UI 写（1452 会话
-- 本监听器 cascade+0.2s 内联跑 → flyover 起步即崩）。
core:add_listener(
    "czx_overlay_default_guard",
    "ComponentLClickUp",
    function(context)
        if not _settled then return false end
        local ok_uim, uim = pcall(function() return cm:get_campaign_ui_manager() end)
        if not ok_uim or not uim or uim.ui_locked then return false end
        -- §10.40：派发窗内不遍历树（撞半建/半毁节点 UAF）——改用 Lua 侧
        -- is_panel_open 判面板在不在；可见性复查交给回调里的 apply（首行锁检）。
        local ok_op, open = pcall(function() return uim:is_panel_open("campaign_space_bar_options") end)
        return ok_op and open == true
    end,
    function(context)
        -- 同样推迟出点击派发窗再动树（apply 首行有 ui_locked 复查）
        cm:callback(czx_overlay_apply, 0.1)
    end,
    true
)

out(_LOG .. " installed")
