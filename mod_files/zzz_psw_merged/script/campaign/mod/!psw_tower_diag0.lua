-- ============================================================================
-- zzzz_psw_tower_diag.lua — 魔女高塔临时诊断（测试用，实测完删除）
-- 多通道探针：file scope / loading_game / first_tick / UICreated / 周期回调。
-- ============================================================================

local function dlog(msg) out("[psw_tower_diag] " .. tostring(msg)) end

dlog("file executed, cm=" .. tostring(cm ~= nil) .. " core=" .. tostring(core ~= nil)
    .. " ftc=" .. tostring(type(cm) == "table" and #cm.first_tick_callbacks or "?"))

local function dump_docker()
    local ok, root = pcall(function() return core:get_ui_root() end)
    if not ok or not root then dlog("no ui root"); return end
    local docker = find_uicomponent(root, "hud_campaign", "faction_buttons_docker", "button_group_management")
    if not docker then dlog("docker not found"); return end
    local n = docker:ChildCount()
    dlog("docker children=" .. n)
    for i = 0, n - 1 do
        local c = UIComponent(docker:Find(i))
        local ok2, id = pcall(function() return c:Id() end)
        local ok3, x, y = pcall(function() return c:Position() end)
        local ok4, w, h = pcall(function() return c:Bounds() end)
        local ok5, vis = pcall(function() return c:Visible() end)
        dlog(string.format("btn[%d] id=%s pos=%s,%s size=%s,%s vis=%s",
            i, tostring(id), tostring(x), tostring(y), tostring(w), tostring(h), tostring(vis)))
    end
end

-- 通道1：first_tick（应触发）
cm:add_first_tick_callback(function()
    dlog("diag first_tick fired")
    cm:callback(function()
        local ok, err = pcall(dump_docker)
        if not ok then dlog("dump error: " .. tostring(err)) end
    end, 3)
end)

-- 通道2：UICreated 事件（UI 建立时必发）
core:add_listener(
    "psw_tower_diag_uicreated",
    "UICreated",
    true,
    function()
        dlog("UICreated fired")
        cm:callback(function()
            local ok, err = pcall(dump_docker)
            if not ok then dlog("uic dump error: " .. tostring(err)) end
        end, 2)
    end,
    false
)

-- 通道3：loading_game 回调
cm:add_loading_game_callback(function(context)
    dlog("loading_game callback fired")
end)

-- 通道4：menu_bar>buttongroup 子按钮定位（找星仪钮屏幕坐标用）
local function dump_buttongroup()
    local ok, root = pcall(function() return core:get_ui_root() end)
    if not ok or not root then dlog("no ui root"); return end
    local bg = find_uicomponent(root, "menu_bar", "buttongroup")
    if not bg then dlog("buttongroup not found"); return end
    local n = bg:ChildCount()
    dlog("buttongroup children=" .. n)
    for i = 0, n - 1 do
        local c = UIComponent(bg:Find(i))
        local ok2, id = pcall(function() return c:Id() end)
        local ok3, x, y = pcall(function() return c:Position() end)
        local ok4, w, h = pcall(function() return c:Bounds() end)
        local ok5, vis = pcall(function() return c:Visible() end)
        dlog(string.format("bg[%d] id=%s pos=%s,%s size=%s,%s vis=%s",
            i, tostring(id), tostring(x), tostring(y), tostring(w), tostring(h), tostring(vis)))
    end
end
cm:add_first_tick_callback(function()
    cm:callback(function()
        local ok, err = pcall(dump_buttongroup)
        if not ok then dlog("bg dump error: " .. tostring(err)) end
    end, 6)
end)

dlog("listeners registered")

-- 测试钩子：点 button_diplomacy 弹调试菜单困境（选项内再调 enter/dbg）
local DBG_MENU = "psw_dilemma_tower_dbg"

core:add_listener(
    "psw_tower_diag_hook",
    "ComponentLClickUp",
    function(context)
        local ok, id = pcall(function() return UIComponent(context.component):Id() end)
        return ok and id == "button_diplomacy"
    end,
    function()
        local ok, err = pcall(function()
            local fname = cm:get_local_faction_name()
            dlog("hook fired, faction=" .. tostring(fname) .. " -> debug menu")
            psw_tower._dbg.menu(cm:get_faction(fname))
        end)
        if not ok then dlog("hook error: " .. tostring(err)) end
    end,
    true
)

-- 调试菜单选项路由
core:add_listener(
    "psw_tower_diag_menu",
    "DilemmaChoiceMadeEvent",
    function(context)
        local d = context:dilemma()
        return d == DBG_MENU
    end,
    function(context)
        local ok, err = pcall(function()
            local c = context:choice_key()
            local f = context:faction()
            local d = psw_tower._dbg
            dlog("dbg menu choice=" .. tostring(c))
            if c == "FIRST" then
                d.card(f, "march"); d.card(f, "starfall")
                d.card(f, "starbind"); d.card(f, "heal")
                d.hand(f)
            elseif c == "SECOND" then
                local r = { d.jyjj(f, "N"), d.jyjj(f, "R"), d.jyjj(f, "S") }
                dlog("jyjj N/R/S = " .. tostring(r[1]) .. "/" .. tostring(r[2]) .. "/" .. tostring(r[3]))
            elseif c == "THIRD" then
                d.digong(f)
            elseif c == "FOURTH" then
                local t = d.talent(f)
                dlog("talent = " .. tostring(t))
            elseif c == "FIFTH" then
                d.eforce(f)
            end
        end)
        if not ok then dlog("dbg menu error: " .. tostring(err)) end
    end,
    true
)
dlog("test hook registered")

dlog("dbg menu hook registered")
