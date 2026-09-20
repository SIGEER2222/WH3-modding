-- czx_losdog_grant.lua
-- zhaohuanxiaojiejie.pack 通过 campaign_difficulty_handicap_effects 发放
-- armyskilladd 效果（解锁 4 个"召唤小姐姐"军队技能），但该表只在开新档时
-- 结算一次——中途启用 MOD 的存档永远拿不到效果。本脚本补建等价效果包并
-- 幂等补发：人类派系缺少效果包时即挂上（duration -1 永久）。

local CZX_LOSDOG_BUNDLE = "czx_losdog_armyskilladd"

local function czx_losdog_ensure()
    local ok, err = pcall(function()
        local faction_name = cm:get_local_faction_name(true)
        local faction = cm:get_faction(faction_name)
        if faction and not faction:is_null_interface()
            and not faction:has_effect_bundle(CZX_LOSDOG_BUNDLE) then
            cm:apply_effect_bundle(CZX_LOSDOG_BUNDLE, faction_name, -1)
            ModLog("[czx_losdog] granted " .. CZX_LOSDOG_BUNDLE .. " to " .. tostring(faction_name))
        end
    end)
    if not ok then
        ModLog("[czx_losdog] ensure failed: " .. tostring(err))
    end
end

cm:add_first_tick_callback(czx_losdog_ensure)

core:add_listener(
    "czx_losdog_turn",
    "FactionTurnStart",
    function(context)
        return context:faction():name() == cm:get_local_faction_name(true)
    end,
    function(context)
        czx_losdog_ensure()
    end,
    true)
