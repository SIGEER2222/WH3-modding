-- czx_talk_battle.lua — battle 上下文钩子：轮询单位状态→事件→台本注入
-- 依赖 _lib/mod/czx_talk_data.lua + czx_talk_engine.lua
-- 事件覆盖：battle_start 阵前喊话 / monster_enters / mass_rout / lord_slain / battle_result
-- 未实测 API 一律标注 [需验证]

local E = CZX_TALK_ENGINE
local bm = battle_manager:new(empire_battle:new()) -- [需验证] battle_manager 实例获取方式（CA 脚本惯例 bm = get_bm()）
-- 注：标准取法在 CA 脚本为 local bm = battle_manager:get(); 此处两种取法均存在先例，打包时以实测为准

local S = {
    started = false,
    said_start = false,
    monster_seen = {},
    lord_down = {},
    poll_ms = 2000,
    grace_ms = 6000,       -- 部署期静默
    elapsed = 0,
    rout_threshold = 4,    -- 同时溃逃单位数阈值
    result_said = false,
}

-- 渲染通道：battle_bark → 屏幕文本注入
-- 可用通路优先级：infotext_manager [需验证] → floating text [需验证] → out() 保底（引擎内建）
E.register_channel("battle_bark", function(line, text, ctx)
    local mgr = bm:infotext_manager() -- [需验证] 方法名/可用性
    if mgr and mgr.add_infotext then
        mgr:add_infotext(text)
        return true
    end
    return false
end)

local function unit_persona(u)
    local key = nil
    if u.type then key = u:type() end -- [需验证] script_unit 的 unit key 访问方法（u:type()/u:name()）
    if key then return E.resolve_speaker(key) end
    return nil
end

local function find_lords()
    local lords = {}
    local armies = bm:armies() -- [需验证]
    if not armies then return lords end
    for i = 0, armies:count() - 1 do
        local army = armies:item(i)
        local units = army:units()
        for j = 0, units:count() - 1 do
            local u = units:item(j)
            if u:is_commanding_unit() then -- 官方 API 已确认存在
                table.insert(lords, { unit = u, army_idx = i,
                    persona = unit_persona(u), key = u:type() })
            end
        end
    end
    return lords
end

local function poll()
    S.elapsed = S.elapsed + S.poll_ms

    -- battle_result：胜负判定后一次 [需验证] 结算判定 API
    local is_over = bm:battle_results and bm:battle_results() ~= nil
    if is_over and not S.result_said then
        S.result_said = true
        E.fire({ event = "battle_result", result = "victory" }) -- [需验证] 结果枚举取法
        return
    end
    if is_over then return end

    -- battle_start：部署完成后第一条阵前喊话
    if not S.said_start and S.elapsed >= S.grace_ms then
        S.said_start = true
        local lords = find_lords()
        if #lords >= 2 then
            local a, b = lords[1].persona, lords[2].persona
            E.fire({ event = "battle_start",
                     speaker = lords[1].persona or lords[1].key,
                     rival_pair = (a and b) and {a, b} or nil,
                     tags = {lords[1].key, lords[2].key} })
        elseif #lords == 1 then
            E.fire({ event = "battle_start", speaker = lords[1].persona or lords[1].key })
        end
    end

    -- 单位扫描：monster_enters / lord_slain / mass_rout
    local routing = { ally = 0, enemy = 0 }
    local armies = bm:armies()
    if not armies then return end
    for i = 0, armies:count() - 1 do
        local army = armies:item(i)
        local is_player = army:is_player_controlled() -- [需验证]
        local units = army:units()
        for j = 0, units:count() - 1 do
            local u = units:item(j)
            local key = u:type()
            local side = is_player and "ally" or "enemy"

            -- 巨兽进场：大型单位首次被侦测到（can_fly 或 key 白名单）
            if not S.monster_seen[key] and (u:can_fly() or (CZX_MONSTER_KEYS and CZX_MONSTER_KEYS[key])) then
                S.monster_seen[key] = true
                E.fire({ event = "monster_enters", side = side, unit = key })
            end

            -- 领主倒地
            if u:is_commanding_unit() and not S.lord_down[key] then
                if u:is_routing() or u:is_shattered() or (u.unary_hitpoints and u:unary_hitpoints() <= 0.05) then
                    S.lord_down[key] = true
                    E.fire({ event = "lord_slain", side = side,
                             speaker = unit_persona(u) or key })
                end
            end

            if u:is_routing() or u:is_shattered() then
                routing[side] = routing[side] + 1
            end
        end
    end

    -- 成片溃逃
    for side, n in pairs(routing) do
        if n >= S.rout_threshold then
            E.fire({ event = "mass_rout", side = side })
        end
    end

    bm:callback(poll, S.poll_ms) -- [需验证] 自调度轮询；CA 惯例 bm:callback(fn, ms)
end

-- 入口：战斗脚本加载时启动轮询
bm:callback(function() poll() end, S.grace_ms)
out("CZX_TALK battle hooks loaded")
