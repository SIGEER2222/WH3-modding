-- czx_horde_paging.lua
-- 游牧军队建筑面板翻页支持
--
-- 工作原理：horde_slot_list 的子组件由 CcoCampaignMilitaryForceHorde.BuildingSlotList
-- 生成，数量 = military_force_type_horde_details.slot_cap。翻页不创建新槽，
-- 只是把本页槽位 SetVisible(true) 并 MoveTo 到前两行网格位置，
-- 其余槽位 SetVisible(false)。页数由实际槽数动态计算（不再固定 4 页）。

local SLOTS_PER_PAGE = 14
local COLS_PER_PAGE = 7
local _current_page = 1
local _slot_list_ref = nil
local _horde_view_ref = nil
local _baseline = nil      -- {x0, y0, px, py}
local _prev_btn = nil
local _next_btn = nil

local function log(msg)
    ModLog("[czx_paging] " .. msg)
end

-- §10.40：干预级联 lock_ui 持锁期间 UI 树正在析构，此时 find_uicomponent/
-- CreateComponent/MoveTo 撞半销毁节点 = +0x22c0f80 族原生 UAF（pcall 兜不住）。
-- uim.ui_locked 是 Lua 侧表字段，不碰原生树，必须先于任何树遍历判。
local function _ui_locked()
    local ok, uim = pcall(function() return cm:get_campaign_ui_manager() end)
    return not (ok and uim) or uim.ui_locked == true
end

local function safe_call(fn, ...)
    local ok, ret = pcall(fn, ...)
    if not ok then
        log("error: " .. tostring(ret))
    end
    return ok, ret
end

local function get_child_by_id(parent, id)
    if not parent then return nil end
    local ok, addr = pcall(function() return parent:Find(id) end)
    if ok and addr then
        return UIComponent(addr)
    end
    return nil
end

local function get_slot_children(slot_list)
    if not slot_list then return {} end
    local ok_count, n = pcall(function() return slot_list:ChildCount() end)
    if not ok_count or not n then return {} end
    local result = {}
    for i = 0, n - 1 do
        local ok, addr = pcall(function() return slot_list:Find(i) end)
        if ok and addr then
            local child = UIComponent(addr)
            -- 跳过 template_building_slot 模板占位组件
            local ok_id, id = pcall(function() return child:Id() or child:Name() end)
            if ok_id and tostring(id) == "template_building_slot" then
                -- skip template
            else
                table.insert(result, child)
            end
        end
    end
    return result
end

local function cco_call(ctx, expr)
    local ok, v = pcall(function() return ctx:Call(expr) end)
    if not ok then return "ERR" end
    return v
end

-- 诊断：输出每个槽位上下文的关键属性（链 key / 是否空 / 是否应显示）
local function dump_slots(slot_list)
    local slots = get_slot_children(slot_list)
    log("dump_slots total=" .. tostring(#slots))
    safe_call(function()
        local horde_ctx = slot_list:GetContextObject("CcoCampaignMilitaryForceHorde")
        if horde_ctx then
            log("BuildingSlotList.Size=" .. tostring(cco_call(horde_ctx, "BuildingSlotList.Size")))
        end
    end)
    for i, slot in ipairs(slots) do
        local ok_ctx, ctx = pcall(function() return slot:GetContextObject("CcoCampaignBuildingSlot") end)
        if ok_ctx and ctx then
            local bkey = "?"
            local ok2, blr = pcall(function() return ctx:Call("BuildingContext.BuildingLevelRecordContext") end)
            if ok2 and blr then
                local ok3, k = pcall(function() return blr:Call("Key") end)
                if ok3 then bkey = tostring(k) end
            end
            log(string.format("  slot %d: empty=%s show=%s primary=%s building=%s tpl=%s/%s/%s",
                i,
                tostring(cco_call(ctx, "IsEmpty")),
                tostring(cco_call(ctx, "ShouldShowSlot")),
                tostring(cco_call(ctx, "IsPrimary")),
                bkey,
                tostring(cco_call(ctx, "SlotTemplateRecord.Key")),
                tostring(cco_call(ctx, "SlotTypeKey")),
                tostring(cco_call(ctx, "Type"))))
        else
            log("  slot " .. i .. ": no CcoCampaignBuildingSlot context")
        end
    end
end

local function measure_baseline(slots)
    _baseline = nil
    if #slots < 2 then return end
    local ok1, x1, y1 = pcall(function() return slots[1]:Position() end)
    local ok2, x2, y2 = pcall(function() return slots[2]:Position() end)
    local ok3, w, h = pcall(function() return slots[1]:Dimensions() end)
    if ok1 and ok2 and x1 and x2 and x2 ~= x1 then
        _baseline = {
            x0 = x1,
            y0 = y1,
            px = x2 - x1,
            py = ((ok3 and h) or 138) + 5,
        }
        log("baseline x0=" .. tostring(_baseline.x0) .. " y0=" .. tostring(_baseline.y0)
            .. " px=" .. tostring(_baseline.px) .. " py=" .. tostring(_baseline.py))
    else
        log("baseline measure failed")
    end
end

local function update_page_buttons(max_page)
    if _prev_btn then
        safe_call(function() _prev_btn:SetVisible(max_page > 1) end)
    end
    if _next_btn then
        safe_call(function() _next_btn:SetVisible(max_page > 1) end)
    end
end

local function apply_page(slot_list, page)
    local slots = get_slot_children(slot_list)
    local total = #slots
    local max_page = math.max(1, math.ceil(total / SLOTS_PER_PAGE))
    if page > max_page then page = max_page end
    if page < 1 then page = 1 end
    local start_idx = (page - 1) * SLOTS_PER_PAGE + 1
    local end_idx = math.min(page * SLOTS_PER_PAGE, total)
    log("apply_page page=" .. page .. "/" .. max_page .. " total=" .. total .. " show=" .. start_idx .. "-" .. end_idx)

    for i, slot in ipairs(slots) do
        local in_page = i >= start_idx and i <= end_idx
        safe_call(function() slot:SetVisible(in_page) end)
        if in_page and _baseline then
            local j = i - start_idx
            local col = j % COLS_PER_PAGE
            local row = math.floor(j / COLS_PER_PAGE)
            local tx = _baseline.x0 + col * _baseline.px
            local ty = _baseline.y0 + row * _baseline.py
            safe_call(function() slot:SetMoveable(true) end)
            safe_call(function() slot:MoveTo(tx, ty) end)
        end
    end
    _current_page = page
    update_page_buttons(max_page)
end

local function on_page_button_click(direction, slot_list)
    local slots = get_slot_children(slot_list)
    local max_page = math.max(1, math.ceil(#slots / SLOTS_PER_PAGE))
    local new_page = _current_page
    if direction == "prev" and _current_page > 1 then
        new_page = _current_page - 1
    elseif direction == "next" and _current_page < max_page then
        new_page = _current_page + 1
    end
    if new_page ~= _current_page then
        apply_page(slot_list, new_page)
    end
end

local function find_or_create_button(horde_view, name, image_path, x, y)
    -- 先尝试查找现有按钮（可能已存在但隐藏）
    local btn = get_child_by_id(horde_view, name)
    local created = false
    if not btn then
        -- 创建按钮：先尝试 icon 模板，回退到 large/small 按钮
        local ok, addr = pcall(function() return horde_view:CreateComponent(name, "ui/templates/icon") end)
        if not ok or not addr then
            log(name .. " icon template failed: " .. tostring(addr))
            ok, addr = pcall(function() return horde_view:CreateComponent(name, "ui/templates/round_large_button") end)
        end
        if not ok or not addr then
            ok, addr = pcall(function() return horde_view:CreateComponent(name, "ui/templates/round_small_button_toggle") end)
        end
        if not ok or not addr then
            log(name .. " CreateComponent failed: " .. tostring(addr))
            return nil
        end
        btn = UIComponent(addr)
        created = true
    end

    -- 设置尺寸
    safe_call(function() btn:SetCanResizeWidth(true) end)
    safe_call(function() btn:SetCanResizeHeight(true) end)
    safe_call(function() btn:Resize(40, 40) end)

    -- 设置图像
    if image_path then
        safe_call(function() btn:SetImagePath(image_path, 0) end)
    end

    -- 可见、可交互、可移动
    safe_call(function() btn:SetVisible(true) end)
    safe_call(function() btn:SetInteractive(true) end)
    safe_call(function() btn:SetMoveable(true) end)

    -- 定位
    safe_call(function() btn:MoveTo(x, y) end)

    log(name .. (created and " created" or " reused") .. " at " .. tostring(x) .. "," .. tostring(y))
    return btn
end

local function create_page_buttons(horde_view)
    if not horde_view then
        log("create_page_buttons: no horde_view")
        return false
    end

    local ok_pos, vx, vy = pcall(function() return horde_view:Position() end)
    local ok_dim, vw, vh = pcall(function() return horde_view:Dimensions() end)
    if not ok_pos or not ok_dim or not vx or not vw then
        log("horde_view pos/dim failed")
        return false
    end

    -- 按钮放在 horde_view 右上部，避免被底部 tab 栏或建筑槽位遮挡
    local prev_x = vx + vw - 90
    local prev_y = vy + 50
    local next_x = vx + vw - 50
    local next_y = vy + 50

    _prev_btn = find_or_create_button(horde_view, "czx_prev_page", "ui/skins/default/czx_arrow_left.png", prev_x, prev_y)
    _next_btn = find_or_create_button(horde_view, "czx_next_page", "ui/skins/default/czx_arrow_right.png", next_x, next_y)

    if not _prev_btn or not _next_btn then
        log("failed to create page buttons")
        return false
    end

    log("page buttons ready")
    return true
end

local function try_get_slot_list()
    local ui_root = core:get_ui_root()
    if not ui_root then return nil end

    local paths = {
        {"units_panel", "main_units_panel", "horde_building_frame", "units_panel_horde_view", "horde_slot_list"},
        {"units_panel", "main_units_panel", "horde_building_frame", "horde_slot_list"},
        {"units_panel_horde_view", "horde_slot_list"},
    }

    for _, p in ipairs(paths) do
        local ok, comp = pcall(function() return find_uicomponent(ui_root, unpack(p)) end)
        if ok and comp then
            return comp
        end
    end

    log("horde_slot_list not found")
    return nil
end

local function try_get_horde_view()
    local ui_root = core:get_ui_root()
    if not ui_root then return nil end

    local ok, comp = pcall(function() return find_uicomponent(ui_root, "units_panel", "main_units_panel", "horde_building_frame", "units_panel_horde_view") end)
    if ok and comp then
        return comp
    end

    local ok_count, n = pcall(function() return ui_root:ChildCount() end)
    if ok_count and n then
        for i = 0, n - 1 do
            local ok2, addr = pcall(function() return ui_root:Find(i) end)
            if ok2 and addr then
                local child = UIComponent(addr)
                local ok3, name = pcall(function() return child:Id() or child:Name() end)
                if ok3 and tostring(name) == "units_panel_horde_view" then
                    return child
                end
            end
        end
    end
    return nil
end

function init_paging(attempt)
    attempt = attempt or 1
    if _ui_locked() then
        log("init_paging skipped: ui_locked")
        return false
    end
    local slot_list = try_get_slot_list()
    if not slot_list then
        if attempt < 10 then
            log("init_paging: slot_list not found, retry " .. attempt)
            cm:callback(function() init_paging(attempt + 1) end, 0.3)
        else
            log("init_paging: slot_list not found after retries")
        end
        return false
    end

    local slots = get_slot_children(slot_list)
    if #slots == 0 and attempt < 10 then
        log("init_paging: slot_list empty, retry " .. attempt)
        cm:callback(function() init_paging(attempt + 1) end, 0.3)
        return false
    end

    _slot_list_ref = slot_list
    measure_baseline(slots)
    dump_slots(slot_list)

    _horde_view_ref = try_get_horde_view()
    if _horde_view_ref then
        create_page_buttons(_horde_view_ref)
    else
        log("init_paging: horde_view not found")
    end

    -- 默认回到第一页，并应用
    _current_page = 1
    apply_page(slot_list, 1)
    return true
end

-- 尝试激活 horde 建筑 tab 并初始化翻页
local function try_open_and_init()
    local ui_root = core:get_ui_root()
    local ok_up, up = pcall(function() return find_uicomponent(ui_root, "units_panel") end)
    if ok_up and up then
        local ok_tab, tab = pcall(function() return find_uicomponent(up, "main_units_panel", "tabgroup", "tab_horde_buildings") end)
        if ok_tab and tab then
            safe_call(function() tab:SimulateLClick() end)
            log("SimulateLClick tab_horde_buildings")
        end
    end

    -- 延迟等待 UI 填充
    cm:callback(function()
        init_paging()
    end, 0.5)
end

local function on_units_panel_opened(context)
    local panel_name = tostring(context.string)
    if panel_name ~= "units_panel" then return end

    _slot_list_ref = nil
    _horde_view_ref = nil
    _baseline = nil

    -- 延迟初始化，等待 UI 填充；lock_ui 级联（战后占领结算等）期间直接放弃本轮
    cm:callback(function()
        if _ui_locked() then
            log("units_panel deferred init skipped: ui_locked")
            return
        end
        -- AI 回合：镜头跟随的 AI 军队开 units_panel 时子树高频拆建（09-29 2232 纳迦什
        -- 合邦段，+0x22c0f80 族）；AI 面板无交互价值，整轮跳过。
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
        if ok_ai and ai_turn then
            log("units_panel deferred init skipped: AI turn")
            return
        end
        local ok, cqi = pcall(function() return cm:get_campaign_ui_manager():get_char_selected_cqi() end)
        if cqi then
            local ok2, char = pcall(function() return cm:get_character_by_cqi(cqi) end)
            if ok2 and char and not char:is_null_interface() then
                local subtype = char:character_subtype_key()
                local ok3, mf = pcall(function() return char:military_force() end)
                local ft_key = ""
                if ok3 and mf and not mf:is_null_interface() then
                    local ok4, ft = pcall(function() return mf:force_type():key() end)
                    if ok4 and ft then
                        ft_key = ft
                    end
                end
                log("units_panel opened: subtype=" .. tostring(subtype) .. " force_type=" .. tostring(ft_key))
                if ft_key == "PSW_HORDE" or tostring(subtype):find("yx_hero") or tostring(subtype):find("yx_lmyx") then
                    init_paging()
                end
            end
        end
    end, 0.5)
end

local function scan_for_psw_horde()
    log("scanning for PSW_HORDE...")
    local ok_name, local_name = pcall(function() return cm:get_local_faction_name(true) end)
    if not ok_name or not local_name or local_name == "" then
        return nil
    end
    local world = cm:model():world()
    local faction_list = world:faction_list()
    for i = 0, faction_list:num_items() - 1 do
        local faction = faction_list:item_at(i)
        if faction and not faction:is_null_interface() and faction:name() == local_name then
            local ok_mfl, mf_list = pcall(function() return faction:military_force_list() end)
            if ok_mfl and mf_list then
                local ok_n, n = pcall(function() return mf_list:num_items() end)
                for j = 0, (n or 0) - 1 do
                    local ok_mf, mf = pcall(function() return mf_list:item_at(j) end)
                    if ok_mf and mf and not mf:is_null_interface() then
                        local ok_ft, k = pcall(function() return mf:force_type():key() end)
                        if ok_ft and k == "PSW_HORDE" then
                            local ok_gen, gen = pcall(function() return mf:general_character() end)
                            local cqi = nil
                            if ok_gen and gen then
                                cqi = gen:command_queue_index()
                            end
                            log("PSW_HORDE cqi=" .. tostring(cqi))
                            return cqi
                        end
                    end
                end
            end
        end
    end
    return nil
end

cm:add_first_tick_callback(function()
    log("first tick")

    local cqi = scan_for_psw_horde()
    if cqi then
        local ok, err = pcall(function()
            cco("CcoCampaignCharacter", tostring(cqi)):Call("Select")
        end)
        log("auto select cqi=" .. tostring(cqi) .. " ok=" .. tostring(ok))
    end

    -- 首次进战役后延迟打开并初始化。
    -- 9.0 修复：加载屏消失级联窗口内引擎正在析构/重建 UI，此时
    -- find_uicomponent/SimulateLClick 会踩到半销毁组件（+0x22c0f80 UAF）。
    -- cm:callback 的延迟走战役时钟，loading 期间不走表，回调会堆积到
    -- dismiss 瞬间一起触发——所以必须等开场运镜全部结束再探测。
    -- 且只有本局存在 PSW_HORDE 时才需要自动探测，否则跳过。
    if cqi then
        local tries = 0
        local function probe_when_safe()
            tries = tries + 1
            local ok_done, intro_done = pcall(function() return cm:has_intro_cutscene_played() end)
            local ok_intro, intro_playing = pcall(function() return cm:is_intro_cutscene_playing() end)
            local ok_cs, cutscene_running = pcall(function() return cm:is_any_cutscene_running() end)
            local safe = ok_done and intro_done
                and not (ok_intro and intro_playing)
                and not (ok_cs and cutscene_running)
            if safe or tries > 150 then
                log("probe: intro_done=" .. tostring(intro_done)
                    .. " intro_playing=" .. tostring(intro_playing)
                    .. " cutscene=" .. tostring(cutscene_running)
                    .. " tries=" .. tries)
                try_open_and_init()
            else
                cm:callback(probe_when_safe, 2)
            end
        end
        cm:callback(probe_when_safe, 5)
    else
        log("no PSW_HORDE, auto-probe skipped")
    end

    core:remove_listener("czx_paging_panel_opened")
    core:add_listener(
        "czx_paging_panel_opened",
        "PanelOpenedCampaign",
        function(context)
            return context and tostring(context.string) == "units_panel"
        end,
        on_units_panel_opened,
        true
    )

    core:remove_listener("czx_paging_tab_click")
    core:add_listener(
        "czx_paging_tab_click",
        "ComponentLClickUp",
        function(context)
            return tostring(context.string) == "tab_horde_buildings"
        end,
        function(context)
            log("tab_horde_buildings clicked, re-init paging")
            _slot_list_ref = nil
            _horde_view_ref = nil
            _baseline = nil
            cm:callback(function() init_paging() end, 0.3)
        end,
        true
    )

    core:remove_listener("czx_paging_prev_click")
    core:add_listener(
        "czx_paging_prev_click",
        "ComponentLClickUp",
        function(context) return tostring(context.string) == "czx_prev_page" end,
        function(context)
            log("prev page clicked")
            if _slot_list_ref then
                on_page_button_click("prev", _slot_list_ref)
            else
                _slot_list_ref = try_get_slot_list()
                if _slot_list_ref then on_page_button_click("prev", _slot_list_ref) end
            end
        end,
        true
    )

    core:remove_listener("czx_paging_next_click")
    core:add_listener(
        "czx_paging_next_click",
        "ComponentLClickUp",
        function(context) return tostring(context.string) == "czx_next_page" end,
        function(context)
            log("next page clicked")
            if _slot_list_ref then
                on_page_button_click("next", _slot_list_ref)
            else
                _slot_list_ref = try_get_slot_list()
                if _slot_list_ref then on_page_button_click("next", _slot_list_ref) end
            end
        end,
        true
    )

    log("paging listener installed")
end)

log("auto-probe installed")
