-- czx_tactical_commander.lua — battle 入口（v2 管线装配层）
-- 依赖 _lib/mod/*.lua 注册的全局：CZX_TC_LOG / CZX_TC_CONTROL / CZX_TC_UNITS
--   / CZX_TC_ASSESS / CZX_TC_COUNTER / CZX_TC_TARGET / CZX_TC_DECISION
--   / CZX_TC_GATE / CZX_UNIT_PROFILE
-- 本文件只做装配：adapter → 各层 → tick 管线。所有局内 API 标 [需验证]，
-- 以 czx_probe.lua 实测结果回填。

if not bm then return end                                        -- bm 为 battle 全局（同 czx_bridge/v1），无 get_bm()

local Log = CZX_TC_LOG
local Control = CZX_TC_CONTROL
local Units = CZX_TC_UNITS
local Assess = CZX_TC_ASSESS
local Target = CZX_TC_TARGET
local Decision = CZX_TC_DECISION
local Gate = CZX_TC_GATE

local log = Log.new(function(line) out(line) end)
log:emit("loaded", { mod = "czx_tactical_commander", phase = "2abc+assess" })

-- ================================================================ adapter
-- 单位枚举：bm.scriptunits 三级缓存（lib_battle_manager 已确认）
-- num_alliances → num_armies_in_alliance → get_scriptunits_for_army(al,ar[,r])
-- 集合为 Lua script_units（:count()/:item(i)，非引擎 num_items）
-- bm:armies() 不存在——裸调用会杀死 timer_manager 泵，勿改回
local function each_army_units(f)
    local player_al = bm:get_player_alliance_num()               -- → local_alliance()，lib 确认
    for al = 1, bm:num_alliances() or 0 do
        local friendly = (al == player_al)
        for ar = 1, bm:num_armies_in_alliance(al) or 0 do        -- 出错返回 false → or 0 跳过
            local sus = bm:get_scriptunits_for_army(al, ar)
            if sus then
                for j = 1, sus:count() do f(friendly, sus:item(j)) end
            end
            for r = 1, bm:num_reinforcing_armies_for_army_in_alliance(al, ar) or 0 do
                local rsus = bm:get_scriptunits_for_army(al, ar, r)
                if rsus then
                    for j = 1, rsus:count() do f(friendly, rsus:item(j)) end
                end
            end
        end
    end
end

local su_by_id = {}
local enemy_ids, friendly_ids = {}, {}

local function rebuild_index()
    su_by_id, enemy_ids, friendly_ids = {}, {}, {}
    each_army_units(function(friendly, su)
        local id = su.name                                       -- script_unit.name 字段（set_name 必填，unique_ui_id[:ref]）
        su_by_id[id] = su
        if friendly then
            friendly_ids[#friendly_ids + 1] = id
        else
            enemy_ids[#enemy_ids + 1] = id
        end
    end)
end

local function find_su(id) return su_by_id[id] end

-- unit fact 读取：battle_unit 方法（社区 §2 已确认存在，签名 [需验证]）
local function unit_call(method)
    return function(id, arg)
        local su = find_su(id)
        if not su then return nil end
        local u = su.unit                                        -- script_unit.unit 字段（battle_unit 接口）
        local f = u and u[method]
        if type(f) ~= "function" then return nil end
        if arg ~= nil then return f(u, arg) end
        return f(u)
    end
end

local tick_ms = 3000                                             -- [需校准] §25 tick 周期
local elapsed = 0

local adapter = {
    now_ms = function() return elapsed end,                      -- [需验证] bm 时钟
    battle_type = function()
        return bm:battle_type()                                  -- [需验证]
    end,

    is_script_controlled = unit_call("is_script_controlled"),
    is_ai_controlled = unit_call("is_ai_controlled"),
    is_player_controlled = unit_call("is_player_controlled"),
    is_controllable = unit_call("is_controllable"),

    release = function(id)
        local su = find_su(id)
        if su then su:release_control() end                      -- [需验证]
    end,
    halt = function(id)
        local su = find_su(id)
        if su then su:halt() end                                 -- [需验证]
    end,
}

-- facts 需要的全部信号名（units.facts 按需取用）
local FACT_SIGNALS = {
    "unit_type", "position", "unary_hitpoints", "number_of_men_alive",
    "fatigue_state", "is_wavering", "is_routing", "is_shattered",
    "is_crumbling", "is_rampaging", "is_in_melee", "is_under_attack",
    "is_under_missile_attack", "is_left_flank_threatened",
    "is_right_flank_threatened", "is_rear_flank_threatened",
    "is_idle", "is_visible_to_alliance", "is_hidden",
    "strategic_value", "ammo_left", "starting_ammo", "missile_range",
    "fast_speed", "slow_speed", "can_use_magic", "is_invulnerable",
    "ordered_position", "current_target", "has_attribute",
    "is_infantry", "is_pikemen", "is_anti_cavalry_infantry",
    "is_cavalry", "is_lancers", "is_chariot", "is_camels",
    "is_elephants", "is_war_beasts", "is_artillery", "is_war_machine",
    "is_fixed_artillery", "can_fly", "is_currently_flying",
    "is_commanding_unit",
}
for _, m in ipairs(FACT_SIGNALS) do
    adapter[m] = unit_call(m)
end
adapter.unit_type = function(id)                                 -- battle_unit:type() [需验证]
    local su = find_su(id)
    local u = su and su.unit
    return u and u:type() or nil
end

-- ================================================================ 各层实例
local gate = Gate.new()
local gov = Control.new(adapter, nil, function(t, f) log:emit(t, f) end)
local te = Target.new()
local dec = Decision.new(nil, function(t, f) log:emit(t, f) end)

CZX_TC_GOVERNOR = gov
CZX_TC_TARGET_EVAL = te
CZX_TC_DECISIONS = dec

-- ================================================================ world 查询
local world = {
    unit_alive = function(id) return find_su(id) ~= nil end,
    unit_broken = function(id)
        local su = find_su(id)
        if not su then return nil end
        local u = su.unit                                        -- script_unit.unit 字段
        return u and (u:is_shattered() or u:is_routing()) or nil
    end,
}

-- ================================================================ tick 管线
local function tick()
    elapsed = elapsed + tick_ms

    -- 门控：战斗类型不允许 → 只跑对账（释放残留托管），不做决策
    local enabled, gate_reason = gate:evaluate(adapter.battle_type())
    if not enabled then
        log:emit("CONTROL_REJECT", { reason = "gate:" .. gate_reason })
        gov:tick({})
        return
    end

    rebuild_index()

    -- 敌方 facts：只取可见（fail-closed 视野）
    local my_facts, enemy_facts = {}, {}
    for _, id in ipairs(friendly_ids) do
        my_facts[#my_facts + 1] = Units.facts(adapter, id)
    end
    for _, id in ipairs(enemy_ids) do
        local f = Units.facts(adapter, id)
        if f.visible ~= false then enemy_facts[#enemy_facts + 1] = f end
    end

    -- 评估 → 意图（供后续 TaskPlanner；当前只产出观测日志）
    local a = Assess.assess(my_facts, enemy_facts)
    local ranked = Assess.intent(a)
    log:emit("ASSESSMENT", {
        phase = a.phase, engaged = a.engaged_share,
        backline = a.backline.threat, range_adv = a.range_advantage,
        hp_ratio = a.hp_pool_ratio,
    })
    if ranked[1] then
        log:emit("INTENT", { action = ranked[1][1], score = ranked[1][2] })
    end

    -- 决策生命周期监控（replan 事件暂存，TaskPlanner 接入后消费）
    dec:tick(elapsed, world)
    dec:drain_events()

    -- 控制对账
    gov:tick(friendly_ids)
end

-- pcall 兜底：tick 内任何报错只记日志，不得杀死 timer_manager 泵
--（callback 异常会中断 pump 在重武装 singleshot 之前，全脚本计时器瘫痪）
bm:repeat_callback(function()                                     -- [需验证]
    local ok, err = pcall(tick)
    if not ok then
        log:emit("CZX_ERROR", { err = tostring(err) })
    end
end, tick_ms, "czx_tc_tick")                                      -- [需验证]

-- 战斗结束清理
local function on_battle_end()                                    -- [需验证] 结束事件
    gov:shutdown("battle_end")
end

log:emit("ready", { mod = "czx_tactical_commander", tick_ms = tick_ms })
