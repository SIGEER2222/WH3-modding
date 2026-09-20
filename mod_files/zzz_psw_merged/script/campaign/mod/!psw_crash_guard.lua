-- PSW crash guard v9
-- 直接删除与 Mixu 冲突导致原生崩溃的 AI 阵营：
--   wh3_main_cth_eastern_river_lords  东江诸侯（v6 已验证）
--   wh2_dlc13_lzd_spirits_of_the_jungle  纳卡伊（v7 新增，horde 事务官检查崩溃）
-- 仅在 AI 控制时生效；玩家使用该派系不受影响
-- 复刻原版 kill_faction 实现：杀光军队 -> 放弃所有城镇 -> 锁外交防复活
--
-- v9：过回合原生崩溃（0xc0000005 执行错误地址 -> 0xc0000409 fail-fast）诊断后的
-- 错误风暴熔断。原版 psw 文件里大量 FactionTurnStart/FactionTurnEnd 监听器
-- 条件函数在判 is_human 之前就解引用 player_data[faction_name] /
-- faction:pooled_resource_manager()，约 100 个 AI 派系每回合全踩一遍
-- （含 rebels），每秒几十条错误走 error_wrapping/draw_2d_text 链。
-- 这些监听器语义上只对玩家派系有意义：统一在注册时包一层
-- "取不到派系或非玩家则早退 false"的前置检查，消掉整场错误流，
-- 同时把 psw 对 AI 派系对象的原生调用面缩到接近零。
-- 本段必须在文件顶层执行：本文件先于 psw 原版文件加载，
-- 才能包住它们后续的 add_listener 注册。
-- v9 的 core.add_listener 全局包装已移除：实测启用后游戏在加载
-- !sfai_ai_garbage_cleanup.lua（其后首个注册 FactionTurnStart 的文件）时
-- 触发 0xc0000409 fail-fast 原生崩溃，连续 4 个会话复现。

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
    -- v8: 全局护栏 —— cm:get_faction 对 rebels/已灭派系返回 false，
    -- 原实现 faction:has_effect_bundle 会布尔索引报错；统一按"无该效果组"处理。
    if type(psw_faction_has_effect_bundle) == "function" then
        psw_faction_has_effect_bundle = function(faction_name, effect_bundle)
            local faction = cm:get_faction(faction_name)
            if not faction or type(faction.has_effect_bundle) ~= "function" then
                return false
            end
            local ok, have = pcall(function()
                return faction:has_effect_bundle(effect_bundle)
            end)
            return ok and have == true
        end
        out("[psw_guard] v8 wrapped psw_faction_has_effect_bundle")
    end
    -- v8b: 脚本错误风暴时每条都会 cm:draw_2d_text 画红字，末回合几千条 UI 文本
    -- 会放大原生侧压力；限流 20 条后静默（错误本身仍走 log_event_error/日志）。
    if type(cm.draw_2d_text) == "function" then
        local _orig_draw_2d_text = cm.draw_2d_text
        local _draw_2d_count = 0
        cm.draw_2d_text = function(...)
            _draw_2d_count = _draw_2d_count + 1
            if _draw_2d_count <= 20 then
                return _orig_draw_2d_text(...)
            end
        end
        out("[psw_guard] v8b rate-limited cm.draw_2d_text")
    end
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

out("[psw_guard] v8 installed: eastern river lords + spirits of the jungle will be destroyed on load")
