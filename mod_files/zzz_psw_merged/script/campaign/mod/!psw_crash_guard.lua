-- PSW crash guard v7
-- 直接删除与 Mixu 冲突导致原生崩溃的 AI 阵营：
--   wh3_main_cth_eastern_river_lords  东江诸侯（v6 已验证）
--   wh2_dlc13_lzd_spirits_of_the_jungle  纳卡伊（v7 新增，horde 事务官检查崩溃）
-- 仅在 AI 控制时生效；玩家使用该派系不受影响
-- 复刻原版 kill_faction 实现：杀光军队 -> 放弃所有城镇 -> 锁外交防复活

local _targets = {
    "wh3_main_cth_eastern_river_lords",
    "wh2_dlc13_lzd_spirits_of_the_jungle",
}
local _listener_name = "psw_guard_kill_conflicting_factions"

local function _valid(faction)
    return faction and not faction:is_null_interface() and not faction:is_dead()
end

local function _kill_faction(faction_key)
    local faction = cm:get_faction(faction_key)
    if not _valid(faction) then
        return false
    end
    if faction:is_human() then
        out("[psw_guard] " .. faction_key .. " is human-controlled, skipping")
        return false
    end

    -- 先强制与所有交战方议和，避免清理过程中触发战斗
    local enemies = faction:factions_at_war_with()
    for i = 0, enemies:num_items() - 1 do
        local enemy = enemies:item_at(i)
        if _valid(enemy) then
            cm:force_make_peace(faction_key, enemy:name())
        end
    end

    -- 原版 kill_faction 等价实现：杀光所有军队，放弃所有城镇
    cm:kill_all_armies_for_faction(faction)
    local region_list = faction:region_list()
    for i = 0, region_list:num_items() - 1 do
        cm:set_region_abandoned(region_list:item_at(i):name())
    end

    -- 清理剩余的无军队人物（事务官等），确保派系彻底死亡
    local char_list = faction:character_list()
    for i = 0, char_list:num_items() - 1 do
        local char = char_list:item_at(i)
        if not char:is_null_interface() and not char:is_wounded() then
            cm:kill_character(char:command_queue_index(), true)
        end
    end

    -- 锁死外交，防止复活/附庸拉尸
    cm:force_diplomacy("faction:" .. faction_key, "all", "all", false, false, true)

    out("[psw_guard] v7 KILLED faction=" .. faction_key)
    return true
end

local function _kill_all_targets()
    for _, key in ipairs(_targets) do
        _kill_faction(key)
    end
end

cm:add_first_tick_callback(function()
    _kill_all_targets()
    core:remove_listener(_listener_name)
    core:add_listener(
        _listener_name,
        "FactionTurnStart",
        function()
            for _, key in ipairs(_targets) do
                local f = cm:get_faction(key)
                if _valid(f) and not f:is_human() then
                    return true
                end
            end
            return false
        end,
        function()
            _kill_all_targets()
        end,
        true
    )
end)

out("[psw_guard] v7 installed: eastern river lords + spirits of the jungle will be destroyed on load")
