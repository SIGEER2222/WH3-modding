-- czx_vmp_pool_probe.lua (v5 DISABLED)
-- 2026-09-28 关停：每次 units_panel 开都做 9000 节点全树遍历 + SimulateLClick 隐形
-- button_raise_dead + 枚举佣兵池 unit_record —— 21:50/21:57 两会话均崩在探针执行中
-- (+0x112e6a6 野指针读)。保留代码备查，置 true 才启用。
local CZX_POOL_PROBE_ENABLED = false
if not CZX_POOL_PROBE_ENABLED then return end
-- 诊断：dump 派系池 + 自动点开驱役亡者面板 + dump mercenary_display 下的兵卡 id

local P = "[CZXPOOL] "

local function plog(s)
    out(P .. tostring(s))
end

local function try(f)
    local ok, r = pcall(f)
    if ok then return r end
    return nil
end

local function is_custom(k)
    if type(k) ~= "string" then return false end
    return k == "gou" or k == "cishe"
        or k:sub(1, 4) == "czx_" or k:sub(1, 4) == "pkm_"
end

local function dump_faction_pool(tag)
    local fname = try(function() return cm:get_local_faction(true):name() end)
    plog("PROBE(" .. tag .. ") faction=" .. tostring(fname))
    if not fname then return end
    local fac = try(function() return cm:get_faction(fname) end)
    if not fac then return end
    local mp = try(function() return fac:mercenary_pool() end)
    local list = mp and try(function() return mp:mercenary_pool_units() end)
    if not list then
        plog(tag .. " faction_pool: list=nil")
        return
    end
    local n = try(function() return list:num_items() end) or 0
    local hits = 0
    for i = 0, n - 1 do
        local pu = try(function() return list:item_at(i) end)
        local key = pu and try(function() return pu:unit_record():key() end)
        if key and is_custom(key) then hits = hits + 1 end
    end
    plog(tag .. " faction_pool n=" .. tostring(n) .. " custom_hits=" .. tostring(hits))
end

local function find_any(pred, root, depth, budget, hits)
    if depth > 10 or budget[1] <= 0 then return end
    budget[1] = budget[1] - 1
    local id = try(function() return root:Id() end)
    if id and pred(tostring(id)) then
        hits[#hits + 1] = root
    end
    local n = try(function() return root:ChildCount() end) or 0
    for i = 0, n - 1 do
        local addr = try(function() return root:Find(i) end)
        if addr then
            pcall(find_any, pred, UIComponent(addr), depth + 1, budget, hits)
        end
    end
end

local function merc_display()
    return find_uicomponent(core:get_ui_root(),
        "units_panel", "main_units_panel", "recruitment_docker",
        "recruitment_options", "mercenary_display")
        or find_uicomponent(core:get_ui_root(), "mercenary_display")
end

local function dump_merc_subtree(tag)
    local md = merc_display()
    if not md then
        plog(tag .. " mercenary_display NOT FOUND")
        return
    end
    plog(tag .. " mercenary_display visible=" .. tostring(try(function() return md:Visible() end)))
    local hits, budget = {}, { 6000 }
    find_any(function(id)
        return id:sub(-9) == "_mercenary" or id:find("list_box") or id:find("button")
    end, md, 0, budget, hits)
    local seen, ids = {}, {}
    for _, c in ipairs(hits) do
        local id = tostring(try(function() return c:Id() end))
        if not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    plog(tag .. " merc_subtree(" .. tostring(#ids) .. ")=" .. table.concat(ids, ","))
    local custom = {}
    for _, id in ipairs(ids) do
        local u = id:gsub("_mercenary$", "")
        if is_custom(u) then custom[#custom + 1] = u end
    end
    plog(tag .. " custom_uicards=" .. tostring(#custom) .. " " .. table.concat(custom, ","))
end

local function click_id(id)
    local root = core:get_ui_root()
    local hits, budget = {}, { 9000 }
    find_any(function(x) return x == id end, root, 0, budget, hits)
    if #hits == 0 then
        plog("click_id " .. id .. " not found")
        return false
    end
    plog("clicking " .. id)
    pcall(function() hits[1]:SimulateLClick() end)
    return true
end

local function open_raise_dead()
    -- 军队面板右下角：button_raise_dead 切换驱役亡者视图
    local hits, budget = {}, { 9000 }
    find_any(function(x)
        return x:find("button_raise") or x:find("button_mercenary_recruit") or x == "button_recruitment"
    end, core:get_ui_root(), 0, budget, hits)
    for _, b in ipairs(hits) do
        plog("btn cand " .. tostring(try(function() return b:Id() end))
            .. " vis=" .. tostring(try(function() return b:Visible() end)))
    end
    click_id("button_raise_dead")
end

local sequence = 0
core:add_listener(
    "czx_vmp_pool_probe_panel",
    "PanelOpenedCampaign",
    function(context)
        return context.string == "units_panel"
    end,
    function()
        sequence = sequence + 1
        local tag = "seq" .. tostring(sequence)
        cm:callback(function()
            dump_faction_pool(tag)
            open_raise_dead()
        end, 0.6)
        cm:callback(function()
            dump_merc_subtree(tag .. "_after_click")
        end, 1.2)
        cm:callback(function()
            dump_merc_subtree(tag .. "_after_click2")
        end, 2.4)
    end,
    false
)

cm:add_first_tick_callback(function()
    cm:callback(function()
        dump_faction_pool("first_tick")
    end, 0.5)
end)
