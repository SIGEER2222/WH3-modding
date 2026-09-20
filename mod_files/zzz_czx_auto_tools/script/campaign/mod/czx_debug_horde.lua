-- czx_debug_horde.lua
-- 调试脚本：每回合扫描玩家所有军队，输出游牧军队的 force type 和 slot 数量

local function czx_log_force_info(military, label)
    if not military or military:is_null_interface() then return end
    local ok, ft_key = pcall(function() return military:force_type():key() end)
    if not ok or not ft_key or ft_key == "" then
        ModLog("[czx_debug] " .. label .. " no force_type")
        return
    end

    -- 只记录游牧/horde 军队（force_type key 含 horde/psw，或带 garrison residence）
    local is_horde = tostring(ft_key):lower():find("horde") ~= nil
    local ok2, has_garrison_residence = pcall(function() return military:has_garrison_residence() end)
    if ok2 and has_garrison_residence then
        is_horde = true
    end
    if ft_key == "PSW_HORDE" then
        is_horde = true
    end

    if not is_horde then
        return
    end

    ModLog("[czx_debug] " .. label .. " force_type=" .. tostring(ft_key))

    -- 获取军队 general 名字
    local ok_gen, general = pcall(function() return military:general_character() end)
    if ok_gen and general and not general:is_null_interface() then
        local ok_name, name = pcall(function() return general:character_subtype_key() end)
        ModLog("[czx_debug]   general=" .. (ok_name and tostring(name) or "unknown"))
    end

    -- slot 数量
    local ok3, slot_list = pcall(function() return military:slot_list() end)
    if ok3 and slot_list and not slot_list:is_null_interface() then
        local n = slot_list:num_items()
        ModLog("[czx_debug]   slot_list count=" .. tostring(n))
        -- 逐槽输出建筑 key（slot:building() 返回字符串）
        for i = 0, n - 1 do
            local ok_s, slot = pcall(function() return slot_list:item_at(i) end)
            if ok_s and slot and not slot:is_null_interface() then
                local ok_b, b = pcall(function() return slot:building() end)
                local ok_t, t = pcall(function() return slot:type() end)
                ModLog("[czx_debug]     slot[" .. i .. "] type=" .. tostring(ok_t and t or "?") .. " building=" .. tostring(ok_b and b or "?"))
            end
        end
    end
end

core:remove_listener("czx_debug_turn_start")
core:add_listener(
    "czx_debug_turn_start",
    "FactionTurnStart",
    function(context)
        return context:faction():is_human()
    end,
    function(context)
        local faction = context:faction()
        local military_list = faction:military_force_list()
        ModLog("[czx_debug] turn start for " .. faction:name() .. ", military forces=" .. tostring(military_list:num_items()))
        for i = 0, military_list:num_items() - 1 do
            local military = military_list:item_at(i)
            czx_log_force_info(military, "force_" .. tostring(i))
        end
    end,
    true
)

-- 打开面板时也触发
local panel_names = {
    "units_panel",
    "settlement_panel",
    "horde_panel",
    "army_panel",
    "army_settler",
    "military_force",
}

core:remove_listener("czx_debug_horde_open")
core:add_listener(
    "czx_debug_horde_open",
    "PanelOpenedCampaign",
    function(context)
        for _, name in ipairs(panel_names) do
            if tostring(context.string) == name then
                return true
            end
        end
        return false
    end,
    function(context)
        ModLog("[czx_debug] panel opened: " .. tostring(context.string))
        local ok_sel, selected = pcall(function() return cm:get_campaign_ui_manager():get_char_selected_cqi() end)
        if ok_sel and selected then
            local ok_c, char = pcall(function() return cm:get_character_by_cqi(selected) end)
            if ok_c and char and not char:is_null_interface() then
                local ok_mf, military = pcall(function() return char:military_force() end)
                if ok_mf then
                    czx_log_force_info(military, "selected_panel")
                end
            end
        end
    end,
    true
)

ModLog("[czx_debug] horde debug listener installed")
