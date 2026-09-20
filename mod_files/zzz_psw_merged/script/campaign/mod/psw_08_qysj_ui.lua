-- psw_08_qysj_ui.lua
-- 幂等补建 PSW 资源顶栏计数器，覆盖原 MOD 两套文化过滤都没照顾到的情况：
--   1. psw_main_qysj（祈愿水晶）：主 MOD psw_资源UI显示.lua 只对 17 个 culture 白名单
--      创建 psw_main_qysj_holder，鼠人/帝国/诺斯卡/暗精/蜥蜴人/古墓王/吸血鬼海岸
--      不在其中，水晶正常累积但顶栏不显示。
--   2. psw_main_gmsj（共鸣水晶）：主 MOD 对巴托/绿皮/高精/吸血鬼伯爵 4 个 culture
--      主动禁止创建计数器，但这些派系的扭蛋照样消耗 gmsj，玩家看不到余量。
-- 组件已存在则跳过，与原 MOD 及后续真实变更互不冲突。

local PSW_RESOURCE_UI = {
    { resource_key = "psw_main_qysj", holder_id = "psw_main_qysj_holder" },
    { resource_key = "psw_main_gmsj", holder_id = "psw_main_gmsj_holder" },
}

local function czx_ensure_psw_resource_ui()
    local ok, err = pcall(function()
        local resource_bar = find_uicomponent(core:get_ui_root(), "hud_campaign", "resources_bar_holder", "resources_bar")
        if not resource_bar then
            return
        end
        local faction_ctx = cco("CcoCampaignFaction", cm:get_local_faction_name(true))
        for _, def in ipairs(PSW_RESOURCE_UI) do
            if not find_uicomponent(resource_bar, def.holder_id) then
                local prui = UIComponent(resource_bar:CreateComponent(
                    def.holder_id, "ui/campaign ui/custom_" .. def.holder_id))
                prui:SetContextObject(faction_ctx)
                prui:SetVisible(true)
                ModLog("[psw_qysj] created " .. def.holder_id .. " for " .. tostring(cm:get_local_faction_name(true)))
            end
        end
    end)
    if not ok then
        ModLog("[psw_qysj] ensure failed: " .. tostring(err))
    end
end

cm:add_first_tick_callback(function()
    core:progress_on_loading_screen_dismissed(function()
        cm:real_callback(czx_ensure_psw_resource_ui, 600, "czx_add_qysj_ui")
    end)

    core:add_listener(
        "czx_qysj_ui_turn",
        "FactionTurnStart",
        function(context)
            return context:faction():name() == cm:get_local_faction_name(true)
        end,
        function(context)
            czx_ensure_psw_resource_ui()
        end,
        true)

    core:add_listener(
        "czx_qysj_ui_prc",
        "PooledResourceChanged",
        function(context)
            local ok, hit = pcall(function()
                return not context:faction():is_null_interface()
                    and context:faction():name() == cm:get_local_faction_name(true)
                    and (context:resource():key() == "psw_main_qysj"
                        or context:resource():key() == "psw_main_gmsj")
            end)
            return ok and hit == true
        end,
        function(context)
            czx_ensure_psw_resource_ui()
        end,
        true)
end)
