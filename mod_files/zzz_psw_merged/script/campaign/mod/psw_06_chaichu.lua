-- 天赋卡拆除支持：双击建筑 → 确认 → 移除效果包 + 尝试原生拆除军队建筑

local function starts_with(s, prefix)
    if type(s) ~= "string" or type(prefix) ~= "string" then
        return false
    end
    return #s >= #prefix and string.sub(s, 1, #prefix) == prefix
end

local _double_click_window = 0.4
local _last_click_time = 0
local _last_click_id = nil

local _pending_key = nil
local _pending_faction = nil
local _pending_uic = nil

local function _is_talent_key(key)
    return type(key) == "string" and (starts_with(key, "psw_tf_nor_") or starts_with(key, "psw_tf_ex_") or starts_with(key, "psw_tf_sp_"))
end

local function _card_key_of(uic)
    local ok, tt = pcall(function() return uic:TooltipText() end)
    if not ok or not tt then
        return nil
    end
    -- 卡片名 tooltip 通常直接是 building key
    local key = tt:match("^([^%s]+)") or tt
    return _is_talent_key(key) and key or nil
end

local function _is_dismantled(faction_name, key)
    local d = psw_main_data and psw_main_data.player_data
        and psw_main_data.player_data[faction_name]
    if not d or not d.dismantled_keys then
        return false
    end
    return d.dismantled_keys[key] == true
end

local function _mark_dismantled(faction_name, key)
    local d = psw_main_data and psw_main_data.player_data
        and psw_main_data.player_data[faction_name]
    if not d then
        return
    end
    if not d.dismantled_keys then
        d.dismantled_keys = {}
    end
    d.dismantled_keys[key] = true
end

local function _cleanup_talent_effects(faction_name, building_key)
    cm:remove_effect_bundle("set_" .. building_key, faction_name)
    cm:remove_effect_bundle("set_main_" .. building_key, faction_name)
    cm:remove_effect_bundle(building_key .. "_effect_bundle", faction_name)
    cm:remove_effect_bundle("psw_yi_pick", faction_name)
    cm:remove_effect_bundle("psw_yi_p1ck", faction_name)
    cm:remove_effect_bundle("main_yi_pick", faction_name)

    local d = psw_main_data and psw_main_data.player_data
        and psw_main_data.player_data[faction_name]
    if d then
        if starts_with(building_key, "psw_tf_nor_") then
            d.nor_count = math.max((d.nor_count or 0) - 1, 0)
        else
            d.ex_count = math.max((d.ex_count or 0) - 1, 0)
            d.jishu_ex_count = math.max((d.jishu_ex_count or 0) - 1, 0)
        end
    end

    if type(psw_aplly_costom_effect_bundle_hidden_fn) == "function" then
        psw_aplly_costom_effect_bundle_hidden_fn("main_yi_pick", faction_name)
    end
end

-- 向上找到带 CcoCampaignBuildingSlot 上下文的 UI 组件
local function _find_slot_uic(uic)
    local max_depth = 5
    local cur = uic
    for i = 1, max_depth do
        if not cur then
            return nil
        end
        -- 如果 CanDismantle 不报错，大概率就是 slot 上下文
        local ok, can = pcall(function() return cur:Call("CanDismantle") end)
        if ok and can ~= nil then
            return cur
        end
        local ok_parent, parent = pcall(function() return cur:Parent() end)
        if ok_parent and parent then
            cur = UIComponent(parent)
        else
            return nil
        end
    end
    return nil
end

local function _native_dismantle(building_key, uic)
    local slot_uic = _find_slot_uic(uic)
    if not slot_uic then
        out("[psw_chaichu] no slot uic found for " .. building_key)
        return false
    end

    -- 1) 槽位上下文
    local ok_can1, can1 = pcall(function() return slot_uic:Call("CanDismantle") end)
    out("[psw_chaichu] slot CanDismantle=" .. tostring(can1) .. " key=" .. building_key)
    if ok_can1 and can1 then
        local ok_dis1 = pcall(function() return slot_uic:Call("Dismantle") end)
        out("[psw_chaichu] slot Dismantle ok=" .. tostring(ok_dis1))
        if ok_dis1 then
            return true
        end
    end

    -- 2) 从槽位取 Building 对象，调用 BuildingContext.Dismantle
    local ok_build, building = pcall(function() return slot_uic:Call("Building") end)
    out("[psw_chaichu] slot.Building=" .. tostring(building) .. " type=" .. type(building))
    if ok_build and building then
        -- 有时 Call 返回的是字符串/路径而不是 CCO；安全包装一下
        local b = building
        if type(b) ~= "userdata" then
            b = slot_uic
        end
        local ok_can2, can2 = pcall(function() return b:Call("CanDismantle") end)
        out("[psw_chaichu] building CanDismantle=" .. tostring(can2))
        if ok_can2 and can2 then
            local ok_dis2 = pcall(function() return b:Call("Dismantle") end)
            out("[psw_chaichu] building Dismantle ok=" .. tostring(ok_dis2))
            if ok_dis2 then
                return true
            end
        end
        -- 硬调，无论 CanDismantle 是什么
        local ok_dis3 = pcall(function() return b:Call("Dismantle") end)
        out("[psw_chaichu] building Dismantle forced ok=" .. tostring(ok_dis3))
        if ok_dis3 then
            return true
        end
    end

    -- 3) 尝试直接从槽位调用 Building.Dismantle()
    local ok_dis4 = pcall(function() return slot_uic:Call("Building.Dismantle()") end)
    out("[psw_chaichu] Building.Dismantle() ok=" .. tostring(ok_dis4))
    if ok_dis4 then
        return true
    end

    return false
end

local function _dismantle_talent(faction_name, building_key, uic)
    local d = psw_main_data and psw_main_data.player_data
        and psw_main_data.player_data[faction_name]
    if not d then
        return false
    end

    -- 先尝试原生拆除（真正清格子）
    local native_removed = false
    if uic then
        native_removed = _native_dismantle(building_key, uic)
    end

    _cleanup_talent_effects(faction_name, building_key)
    _mark_dismantled(faction_name, building_key)

    -- 如果原生拆除成功，不用隐藏；否则效果已清，卡片保留
    if native_removed then
        out("[psw_chaichu] native dismantle succeeded for " .. building_key)
    else
        out("[psw_chaichu] native dismantle failed; effects removed for " .. building_key)
    end
    return true
end

local function _close_confirm()
    local dlg = find_uicomponent(core:get_ui_root(), "psw_chaichu_confirm")
    if dlg then
        pcall(function() dlg:UnLockPriority() end)
        pcall(function() dlg:Destroy() end)
    end
    _pending_key = nil
    _pending_faction = nil
    _pending_uic = nil
    pcall(function() cm:remove_real_callback("psw_chaichu_timeout") end)
end

local function _show_confirm(faction_name, building_key, uic)
    _close_confirm()
    _pending_key = building_key
    _pending_faction = faction_name
    _pending_uic = uic

    local root = core:get_ui_root()
    local ok, dlg = pcall(function()
        return UIComponent(root:CreateComponent("psw_chaichu_confirm", "UI/Common UI/dialogue_box"))
    end)
    if not ok or not dlg then
        out("[psw_chaichu] failed to create dialogue for " .. tostring(building_key))
        _pending_key = nil
        _pending_faction = nil
        _pending_uic = nil
        return
    end
    local txt = find_uicomponent(root, "psw_chaichu_confirm", "DY_text")
    if txt then
        txt:SetStateText("确认拆除该天赋？\n" .. tostring(building_key))
    end
    dlg:PropagatePriority(99)
    out("[psw_chaichu] confirm shown for " .. tostring(building_key))

    cm:real_callback(function()
        if _pending_key == building_key then
            _close_confirm()
            out("[psw_chaichu] confirm timed out")
        end
    end, 10, "psw_chaichu_timeout")
end

cm:add_first_tick_callback(function()
    core:add_listener(
        "psw_chaichu_dblclick",
        "ComponentLClickUp",
        function(context)
            if context.string ~= "square_building_button" then
                return false
            end
            local uic = UIComponent(context.component)
            local key = _card_key_of(uic)
            if not _is_talent_key(key) then
                return false
            end
            -- 已拆除的不再响应
            local visible = pcall(function() return uic:Visible() end) and uic:Visible()
            return visible
        end,
        function(context)
            local uic = UIComponent(context.component)
            local key = _card_key_of(uic)
            local now = os.clock()
            local id = uic:Address()
            if _last_click_id == id and (now - _last_click_time) <= _double_click_window then
                _last_click_id = nil
                _last_click_time = 0
                _show_confirm(cm:get_local_faction_name(true), key, uic)
            else
                _last_click_id = id
                _last_click_time = now
            end
        end,
        true
    )

    core:add_listener(
        "psw_chaichu_confirm_click",
        "ComponentLClickUp",
        function(context)
            if context.string ~= "button_tick" and context.string ~= "button_cancel" then
                return false
            end
            return _pending_key ~= nil
        end,
        function(context)
            if context.string == "button_tick" and _pending_key and _pending_faction then
                if _dismantle_talent(_pending_faction, _pending_key, _pending_uic) then
                    cm:show_advice("psw_chaichu_done", true, false, nil, 0, 5)
                end
            end
            _close_confirm()
        end,
        true
    )

    out("[psw_chaichu] v4 installed: double-click -> confirm -> native dismantle attempt + effect removal")
end)
