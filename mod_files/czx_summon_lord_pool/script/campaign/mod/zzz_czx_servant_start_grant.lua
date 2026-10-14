-- 英灵从者开局发放自愈补丁
-- 背景：Lin_Summon_Servant 的开局发放监听条件是 turn_number()==1 的一次性窗口，
-- 且回调内 `if mct then ... end` 在 MCT 静态对象缺失时静默保持 "no"、无任何日志；
-- create_agent 之后的 CCO 改名段出错也会静默中断。窗口错过（读档进的第 2 回合、
-- MCT 初始化竞态、发放中途出错）后该档永远拿不到从者。
-- 本补丁在回合 >=2 的 FactionTurnStart 补一次：MCT 仍为 random/all 且派系里
-- 一个 lin_all_* 从者都没有时，直接复用 Lin 模组自身的发放函数（random_character
-- / all_character，含选址/改名/换装/回满行动力）补发，per-faction saved_value 幂等。
-- 回合 1 不插手，避免与原版监听在同一事件里重复发放。

local function has_any_servant(faction)
    local ok, found = pcall(function()
        local cl = faction:character_list()
        for i = 0, cl:num_items() - 1 do
            local c = cl:item_at(i)
            local subtype = c:character_subtype_key()
            if type(subtype) == "string" and string.find(subtype, "lin_all_", 1, true) then
                -- 只认英雄类（champion/dignitary/wizard/spy/engineer/runesmith）。
                -- 领主池招出来的 lin_all_* 领主 character_type_key()=="general"，
                -- 不算"已有从者"——否则先招了英灵领主会误跳过从者补发。
                if c:character_type_key() ~= "general" then
                    return true
                end
            end
        end
        return false
    end)
    if not ok then return true end  -- 查询失败宁可不发，避免误发
    return found
end

local function read_mct_setting()
    local setting = nil
    pcall(function()
        local mct = core:get_static_object("mod_configuration_tool")
        if mct then
            local mct_mod = mct:get_mod_by_key("summon_servant")
            if mct_mod then
                setting = mct_mod:get_option_by_key("summon_servant_get_servant"):get_finalized_setting()
            end
        end
    end)
    return setting
end

local function grant_servant(faction, setting)
    local ss = rawget(_G, "summon_servant")
    if not ss or type(ss.random_character) ~= "function" then
        out("[czx_servant_grant] summon_servant global object unavailable")
        return false
    end
    local ok, err = pcall(function()
        if setting == "all" then
            ss:all_character(faction)
        else
            ss:random_character(faction)
        end
    end)
    if not ok then
        out("[czx_servant_grant] grant failed: " .. tostring(err))
        return false
    end
    return true
end

core:add_listener(
    "CzxServantStartGrant",
    "FactionTurnStart",
    function(context)
        return cm:turn_number() >= 2 and context:faction():is_human()
    end,
    function(context)
        local faction = context:faction()
        local faction_key = faction:name()
        -- create_agent 会触发 CharacterRecruited -> 原版 initiative 重复解锁 ->
        -- remove_listener 错误；绝不在回合开始级联内联做（§10.40 教训），
        -- 推迟 10s 出级联窗，届时复查存档标记。
        cm:real_callback(function()
            local ok_f, f = pcall(function()
                return cm:get_faction(faction_key)
            end)
            if not ok_f or not f or not f:is_human() then return end
            local key = "czx_servant_grant_" .. faction_key
            if cm:get_saved_value(key) then return end

            local setting = read_mct_setting()
            if setting == nil then
                -- MCT 对象缺失：跟随全局默认（本机全局默认 random），但只在
                -- 派系确实没有从者时才发，行为保守
                setting = "random"
            end
            if setting ~= "random" and setting ~= "all" then
                cm:set_saved_value(key, true)  -- 用户明确关闭，不再补发
                return
            end
            if has_any_servant(f) then
                cm:set_saved_value(key, true)  -- 原版 turn-1 发放已成功
                return
            end

            if grant_servant(f, setting) then
                cm:set_saved_value(key, true)
                out("[czx_servant_grant] " .. faction_key
                    .. " servant granted retroactively (setting=" .. tostring(setting) .. ")")
            end
        end, 10000, "czx_servant_grant_" .. faction_key)
    end,
    true
)

out("[czx_servant_grant] self-heal listener installed")
