-- czx_tc_target.lua — TargetEvaluator（RFC §15 + 社区实证规则）
--   TargetScore = Threat + Tactical + RoleMatch + KillProb + Protect + Objective
--                 − Distance − Exposure − Chase
--   社区规则：focus cap ≤3（UT TAC-012.4）；保持原目标直到 shattered（Babysitter）
-- Lua 5.1，纯函数；CounterScore 由 czx_tc_counter 提供。

CZX_TC_TARGET = CZX_TC_TARGET or {}
local M = CZX_TC_TARGET

local Counter = CZX_TC_COUNTER

M.CFG = {
    w = {
        threat = 25, tactical = 20, rolematch = 20, killprob = 15,
        protect = 30, objective = 10,
        distance = 20, exposure = 15, chase = 15,
    },
    focus_cap = 3,               -- UT 实测：同目标最多 3 个单位
    sticky_bonus = 15,           -- 保持原目标的加分（未 shattered 不换）
    threat_ref = 1500,           -- strategic_value/cost 归一参考
    dist_ref = 400,              -- 距离成本归一参考（m）
    routing_value = 0.2,         -- 溃逃目标价值系数（别追炮灰）
}

function M.new(cfg)
    local self = { _cfg = {}, _focus = {} }
    for k, v in pairs(M.CFG) do
        if type(v) == "table" then
            self._cfg[k] = {}
            for k2, v2 in pairs(v) do self._cfg[k][k2] = v2 end
        else self._cfg[k] = v end
    end
    if cfg then
        for k, v in pairs(cfg) do
            if type(v) == "table" and type(self._cfg[k]) == "table" then
                for k2, v2 in pairs(v) do self._cfg[k][k2] = v2 end
            else self._cfg[k] = v end
        end
    end
    return setmetatable(self, { __index = M })
end

local function clamp01(x)
    if x < 0 then return 0 elseif x > 1 then return 1 end
    return x
end

-- ------------------------------------------------------ 分量（全部 0..1）
local function threat_of(target)
    local sv = target.strategic_value or (target.profile and target.profile.cost) or 0
    local t = clamp01(sv / 1500)
    if target.profile and target.profile.is_high_threat then
        t = math.min(1, t + 0.3)
    end
    return t
end

local function killprob_of(me, target, counter_mine)
    local base = 0.4 + (counter_mine - 1) * 0.3
    local hp = target.hp
    if hp then base = base + (1 - hp) * 0.3 end
    if target.morale and (target.morale.wavering or target.morale.routing) then
        base = base + 0.15
    end
    return clamp01(base)
end

local function chase_cost(me, target)
    if target.morale and target.morale.shattered then return 1 end
    local ms = me.speed and me.speed.fast
        or (me.profile and me.profile.run_speed)
    local ts = target.speed and target.speed.fast
        or (target.profile and target.profile.run_speed)
    if ms and ts and ts > ms then return clamp01((ts - ms) / 4) end
    return 0
end

-- ------------------------------------------------------ 评分
-- ctx: {dist, exposure, protect, objective, assigned_count}
function M.score(self, me, target, ctx)
    ctx = ctx or {}
    local counter, cdetail = Counter.score(me, target)
    local w = self._cfg.w
    local comp = {}

    comp.threat = threat_of(target)
    comp.rolematch = clamp01((counter + 1) / 3)
    comp.killprob = killprob_of(me, target, cdetail.mine)
    comp.tactical = ctx.tactical or 0.5
    comp.protect = ctx.protect or 0
    comp.objective = ctx.objective or 0
    comp.distance = clamp01((ctx.dist or 0) / self._cfg.dist_ref)
    comp.exposure = ctx.exposure or 0
    comp.chase = chase_cost(me, target)

    -- 溃逃/消亡目标价值打折（UT：不追 routing）
    local morale_mult = 1
    if target.morale and (target.morale.shattered or target.morale.routing) then
        morale_mult = self._cfg.routing_value
    end

    local positive = w.threat * comp.threat + w.tactical * comp.tactical
        + w.rolematch * comp.rolematch + w.killprob * comp.killprob
        + w.protect * comp.protect + w.objective * comp.objective
    local negative = w.distance * comp.distance + w.exposure * comp.exposure
        + w.chase * comp.chase
    local s = positive * morale_mult - negative

    -- focus cap：同目标人满 → 强降权（不硬排除，允许高优先破例由 Governor 定）
    if (ctx.assigned_count or 0) >= self._cfg.focus_cap then
        s = s - 50
        comp.focus_capped = true
    end
    -- 目标保持
    if ctx.is_current_target then s = s + self._cfg.sticky_bonus end

    return s, comp
end

-- ------------------------------------------------------ 选择 + 分配登记
-- candidates: target fact 列表；ctx_fn(target) -> per-candidate ctx
function M.select(self, me, candidates, ctx_fn)
    local best, best_s, best_comp = nil, -math.huge, nil
    for _, t in ipairs(candidates or {}) do
        if t.visible ~= false then                     -- 不可见不评（fail-closed）
            local ctx = ctx_fn and ctx_fn(t) or {}
            if ctx.is_current_target == nil and me.current_target then
                ctx.is_current_target = (me.current_target == t.id)
            end
            local s, comp = self:score(me, t, ctx)
            if s > best_s then best, best_s, best_comp = t, s, comp end
        end
    end
    return best, best_s, best_comp
end

-- focus 登记簿：assigned_count 由调用方经 ctx_fn 注入
function M.assign(self, unit_id, target_id)
    self:release(unit_id)
    self._focus[target_id] = self._focus[target_id] or {}
    self._focus[target_id][unit_id] = true
end

function M.release(self, unit_id)
    for tid, set in pairs(self._focus) do
        if set[unit_id] then
            set[unit_id] = nil
            if next(set) == nil then self._focus[tid] = nil end
            return tid
        end
    end
    return nil
end

function M.release_target(self, target_id)
    self._focus[target_id] = nil
end

function M.assigned_count(self, target_id)
    local set = self._focus[target_id]
    if not set then return 0 end
    local n = 0
    for _ in pairs(set) do n = n + 1 end
    return n
end

return M
