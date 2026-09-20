-- czx_talk_campaign.lua — campaign 上下文钩子：外交/城市/事务官/回合事件→台本注入
-- 依赖 _lib/mod/czx_talk_data.lua + czx_talk_engine.lua
-- 事件名均按 CA 脚本惯例选取，实测后再固化（[需验证] 标注）

local E = CZX_TALK_ENGINE

-- ---------- 渲染通道 ----------
-- campaign 文本注入候选通路：
--   1) cm:show_message_event —— 官方 API 存在，但 title/primary/secondary 均取 Loc key，
--      不能直接显示动态文本 → 只能配预烘焙 Loc 行（静态模板台词可用）[需验证 loc 占位能力]
--   2) uicomponent 文本改写 —— find_uicomponent + SetText [需验证]
--   3) out() 结构化日志 —— 保底（引擎内建）
local function ui_text_probe(text)
    -- [需验证] 事件流 label 组件路径；原型期先探测组件树再固化路径
    local ok, feed = pcall(find_uicomponent, core:get_ui_root(), "event_feed")
    if ok and feed and feed.SetText then
        pcall(function() feed:SetText(text) end)
        return true
    end
    return false
end

E.register_channel("event_feed", function(line, text) return ui_text_probe(text) end)
E.register_channel("dilemma", function(line, text)
    -- dilemma 需 DB 行；v1 先走 event_feed 降级展示 [需验证]
    return ui_text_probe(text)
end)

-- ---------- 工具 ----------
local function lord_persona(character)
    if not character then return nil end
    local ok, subtype = pcall(function() return character:character_subtype_key() end) -- [需验证]
    if ok and subtype then
        -- 人设匹配按 unit_key；campaign 侧 character 的 subtype≠land_unit key，
        -- 需要 subtype→unit 映射表 [需验证]；暂用 subtype 直接撞人设 id
        if CZX_PERSONA[subtype] then return subtype end
    end
    return nil
end

-- ---------- 事件钩子（5 参数签名，AGENTS.md 规则） ----------

-- T01 宣战檄文
core:add_listener(
    "czx_war_declared",
    "FactionDeclaresWar", -- [需验证] WH3 外交事件名（候选 FactionDeclaresWar / NegativeDiplomaticEvent）
    function(context)
        local f = context:faction()
        return f and not f:is_human() -- 只对"AI 向我方宣战"发言；反向暂不
    end,
    function(context)
        local f = context:faction()
        local speaker = nil
        if f and f.faction_leader then
            speaker = lord_persona(f:faction_leader()) -- [需验证] faction_leader 访问
        end
        E.fire({ event = "war_declared", speaker = speaker or "*",
                 race = f and f:name() or nil })
    end,
    true
)

-- T03 城市易手
core:add_listener(
    "czx_city_changed",
    "RegionFactionChangeEvent", -- [需验证]
    function(context)
        local region = context:region()
        return region and region:settlement() -- 仅定居点易手
    end,
    function(context)
        local region = context:region()
        local key = region and region:name() or nil
        E.fire({ event = "city_lost", location = key,
                 side = "victor", speaker = "narrator" })
    end,
    true
)

-- T07 事务官行动结果
core:add_listener(
    "czx_agent_action",
    "CharacterCharacterTargetAction", -- [需验证]
    function(context) return context:character() ~= nil end,
    function(context)
        local ok, outcome = pcall(function()
            return context:mission_result_critial_success() and "success" or "success" -- [需验证] 结果枚举
        end)
        E.fire({ event = "agent_report", outcome = ok and outcome or "success",
                 speaker = "agent" })
    end,
    true
)

-- T05 回合末·世界彼端
core:add_listener(
    "czx_world_tick",
    "FactionTurnEnd", -- 玩家回合结束
    function(context)
        local f = context:faction()
        return f and f:is_human()
    end,
    function(context)
        -- 在场派系池：随机挑一个非玩家传奇说话对象（v1 简化：模板变量后填）
        E.fire({ event = "world_tick", speaker = "narrator" })
    end,
    true
)

-- T08 仇恨清算（矮人样板）
core:add_listener(
    "czx_grudge",
    "PooledResourceChanged", -- [需验证] 矮人仇恨资源事件名
    function(context)
        local f = context:faction()
        return f and f:name() and f:name():find("dwf") ~= nil
    end,
    function(context)
        E.fire({ event = "grudge_cleared", race = "dwarf",
                 speaker = "narrator" })
    end,
    true
)

out("CZX_TALK campaign hooks loaded")
