-- czx_horde_paging.lua
-- 游牧军队建筑面板翻页支持

local SLOTS_PER_PAGE = 14
local MAX_PAGES = 4  -- 固定4页，避免动态计算失败
local _current_page = 1
local _slot_list_ref = nil
local _horde_view_ref = nil

local function log(msg)
    ModLog("[czx_paging] " .. msg)
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

local function apply_page(slot_list, page)
    local slots = get_slot_children(slot_list)
    local total = #slots
    local start_idx = (page - 1) * SLOTS_PER_PAGE + 1
    local end_idx = page * SLOTS_PER_PAGE  -- 不限制上限，空槽位隐藏
    log("apply_page page=" .. page .. " total=" .. total .. " show=" .. start_idx .. "-" .. end_idx)
    for i, slot in ipairs(slots) do
        local show = (i >= start_idx and i <= end_idx)
        safe_call(function() slot:SetVisible(show) end)
    end
    _current_page = page
end

local function on_page_button_click(direction, slot_list)
    local new_page = _current_page
    if direction == "prev" and _current_page > 1 then
        new_page = _current_page - 1
    elseif direction == "next" and _current_page < MAX_PAGES then
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

    local prev = find_or_create_button(horde_view, "czx_prev_page", "ui/skins/default/czx_arrow_left.png", prev_x, prev_y)
    local next = find_or_create_button(horde_view, "czx_next_page", "ui/skins/default/czx_arrow_right.png", next_x, next_y)

    if not prev or not next then
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
    local panel_name = tostring(context:string())
    if panel_name ~= "units_panel" then return end

    _slot_list_ref = nil
    _horde_view_ref = nil

    -- 延迟初始化，等待 UI 填充
    cm:callback(function()
        local ok, cqi = pcall(function() return cm:get_campaign_ui_manager():get_char_selected_cqi() end)
        if cqi then
            local ok2, char = pcall(function() return cm:get_character_by_cqi(cqi) end)
            if ok2 and char and not char:is_null_interface() then
                local subtype = char:character_subtype_key()
                local ok3, mf = pcall(function() return char:military_force() end)
                local ft_key = ""
                if ok3 and mf and not mf:is_null_interface() then
                    local ok4, ft = pcall(function() return mf:force_type() end)
                    if ok4 and ft then
                        ft_key = ft:key() or ""
                    end
                end
                if subtype == "yx_hero_xueli" or ft_key == "PSW_HORDE" then
                    init_paging()
                end
            end
        end
    end, 0.5)
end

local function scan_for_psw_horde()
    log("scanning for PSW_HORDE...")
    local world = cm:model():world()
    local faction_list = world:faction_list()
    for i = 0, faction_list:num_items() - 1 do
        local faction = faction_list:item_at(i)
        if faction and not faction:is_null_interface() and faction:name() == "wh3_main_cth_the_northern_provinces" then
            local ok_mfl, mf_list = pcall(function() return faction:military_force_list() end)
            if ok_mfl and mf_list then
                local ok_n, n = pcall(function() return mf_list:num_items() end)
                for j = 0, (n or 0) - 1 do
                    local ok_mf, mf = pcall(function() return mf_list:item_at(j) end)
                    if ok_mf and mf and not mf:is_null_interface() then
                        local ok_ft, ft = pcall(function() return mf:force_type() end)
                        if ok_ft and ft then
                            local ok_k, k = pcall(function() return ft:key() end)
                            if ok_k and k == "PSW_HORDE" then
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

    -- 首次进战役后延迟打开并初始化
    cm:callback(function()
        try_open_and_init()
    end, 3)

    core:remove_listener("czx_paging_panel_opened")
    core:add_listener(
        "czx_paging_panel_opened",
        "PanelOpenedCampaign",
        function(context)
            return context and tostring(context:string()) == "units_panel"
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
