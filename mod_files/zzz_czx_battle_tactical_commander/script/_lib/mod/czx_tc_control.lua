-- czx_tc_control.lua
-- czx_battle_tactical_commander v2 / Phase 2c: delegated 生命周期状态机
-- （Control Governor 的所有权核心）
--
-- 语义来源：社区证据评估 §1.1 —— Unified Tactics 66 条 hotfix 的主战区：
--   lease（托管确认窗口）/ settle（就绪等待）/ serialize（同单位操作串行
--   + debounce）/ authoritative disengage（清 pending、停旧指令、验证 detach）
-- 硬约束（v1 实测倒推，RFC §3.1/复核 §0）：
--   UC 指令隐式夺权；release_control() 还给"玩家/AI"而非原 planner
--   → 只在确实空闲时干预、下完指令立即 release、没下指令绝不 release
-- 原则：fail-closed —— 任何信号不可确认时默认 NO ACTION，绝不 fallthrough。
--
-- 引擎无关：所有游戏 I/O 走注入的 adapter，离线 mock 可全量回归。
--
-- adapter 契约（WH3 侧实现在 battle 入口装配，API 名 [需验证] 项以 probe 为准）：
--   now_ms()                      -> number   单调时钟（bm 时钟/累计 tick）
--   is_script_controlled(id)      -> bool|nil 我们或他方脚本持有（nil=不可确认）
--   is_ai_controlled(id)          -> bool|nil native planner 持有
--   is_player_controlled(id)      -> bool|nil 玩家可下令
--   is_controllable(id)           -> bool|nil 还能不能控（溃逃/离场→false）
--   acquire(id)                   -> 可选：显式 take_control [需验证]；
--                                  缺省=隐式（首个 UC 夺权），此时 settle 确认
--                                  依赖 executor 随后真正发 UC
--   release(id)                   -> release_control()
--   halt(id)                      -> 可选：停旧指令（disengage 时清 stale order）
--
-- log 契约：function(tag: string, fields: table) end
--   由 czx_tc_log 的 emit 直接满足。
--
-- Lua 5.1（WH3 battle 沙箱）。
-- 注册全局 CZX_TC_CONTROL（_lib/mod 加载约定），同时 return 供离线 dofile。

CZX_TC_CONTROL = CZX_TC_CONTROL or {}
local M = CZX_TC_CONTROL

-- 状态
M.STATE = {
    FREE = "FREE",             -- 不持权：native planner / 玩家 / 未知方持有
    ACQUIRING = "ACQUIRING",   -- 已决定接管，等待 is_script_controlled 确认（lease）
    DELEGATED = "DELEGATED",   -- 确认持权
    RELEASING = "RELEASING",   -- 已发 release，等待 detach 确认
}

-- 动作优先级（RFC §18）；>= override 阈值可穿 cooldown
M.PRIORITY = {
    emergency_retreat = 100,
    commander_save = 95,
    artillery_breakthrough = 90,
    immediate_protection = 85,
    tactical_intercept = 70,
    flank_hunt = 60,
    reposition = 40,
    cleanup = 20,
}

local DEFAULTS = {
    settle_window_ms = 1500,        -- engage lease：等待确认窗口
    release_timeout_ms = 1500,      -- 单次 detach 等待
    release_max_attempts = 3,       -- detach 重试次数（UT: battle-end 需重试）
    min_flip_ms = 3000,             -- release 完成→再 engage 的 debounce
    action_cooldown_ms = 20000,     -- v1 retry_ms：同类动作冷却
    cooldown_override_priority = 85,-- >= 此优先级无视 cooldown
    unconfirmed_drop_ms = 3000,     -- 信号持续不可确认→放弃持权登记（stale lease）
    max_engages_per_tick = 4,       -- Action Budget §26
    allow_army_scope = false,       -- 全军托管默认关闭（Phase 6 才考虑）
}

local function new_record(id)
    return {
        id = id,
        state = M.STATE.FREE,
        op = nil,                  -- {kind, started_ms, deadline_ms, attempts, priority}
        foreign = false,           -- 他方脚本持有
        lost = false,              -- is_controllable==false
        unconfirmed_ms = 0,        -- DELEGATED 下信号连续不可确认的累计时长
        signal_ok = true,          -- 最近一次对账是否确认了 script 持权
        last_release_ms = nil,
        cooldowns = {},            -- action_class -> expiry_ms
        cooldown_rem_ms = 0,
    }
end

function M.new(adapter, config, log)
    assert(adapter and adapter.now_ms, "adapter.now_ms required")
    local self = {
        _a = adapter,
        _cfg = {},
        _log = log or function() end,
        _units = {},
        _engages_this_tick = 0,
    }
    for k, v in pairs(DEFAULTS) do self._cfg[k] = v end
    if config then for k, v in pairs(config) do self._cfg[k] = v end end
    return setmetatable(self, { __index = M })
end

-- ---------------------------------------------------------------- 内部

local function rec_of(self, id)
    local r = self._units[id]
    if not r then
        r = new_record(id)
        self._units[id] = r
    end
    return r
end

local function start_op(r, kind, now, timeout_ms, priority)
    r.op = {
        kind = kind,
        started_ms = now,
        deadline_ms = now + timeout_ms,
        attempts = 1,
        priority = priority or 0,
    }
end

local function to_free(self, r, now, tag, reason)
    r.state = M.STATE.FREE
    r.op = nil
    r.unconfirmed_ms = 0
    r.signal_ok = true
    if tag == "CONTROL_RELEASE" then
        r.last_release_ms = now
    end
    self._log(tag, { unit = r.id, state = r.state, reason = reason })
end

local function check_cooldown(self, r, now, action_class, priority)
    if priority >= self._cfg.cooldown_override_priority then return nil end
    local expiry = r.cooldowns[action_class or "_any"]
    if expiry and now < expiry then
        return "cooldown:" .. tostring(action_class or "_any")
            .. "(" .. tostring(expiry - now) .. "ms)"
    end
    return nil
end

-- ---------------------------------------------------------------- 对外 API

-- 每 tick 调用：unit_ids = 当前存在的友方单位 id 列表
-- 驱动 lease/detach 超时、所有权对账、foreign/lost 检测
function M.tick(self, unit_ids)
    local now = self._a.now_ms()
    local dt = self._last_tick_ms and (now - self._last_tick_ms) or 0
    self._last_tick_ms = now
    self._engages_this_tick = 0

    -- 登记新出现的单位 + foreign/lost 感知
    for _, id in ipairs(unit_ids or {}) do
        local r = rec_of(self, id)
        local controllable = self._a.is_controllable(id)
        r.lost = (controllable == false)
        if r.state == M.STATE.FREE and not r.op then
            local sc = self._a.is_script_controlled(id)
            if sc == true then
                -- 我们没在 engage 它却被 script 持有 → 他方 mod（或重启残留）
                -- fail-closed：绝不介入
                if not r.foreign then
                    r.foreign = true
                    self._log("CONTROL_REJECT", {
                        unit = id, reason = "foreign_held_detected" })
                end
            elseif sc == false then
                r.foreign = false
            end
        end
    end

    -- 状态机推进
    for id, r in pairs(self._units) do
        self:_advance(r, now, dt)
    end
end

function M._advance(self, r, now, dt)
    local a = self._a

    if r.lost then
        if r.state ~= M.STATE.FREE then
            -- 溃逃/离场/死亡：直接放弃登记，不补 release
            -- （unit 已不可控，release 无意义）
            to_free(self, r, now, "CONTROL_RELEASE", "unit_lost")
        end
        return
    end

    if r.state == M.STATE.ACQUIRING then
        local sc = a.is_script_controlled(r.id)
        if sc == true then
            r.state = M.STATE.DELEGATED
            r.op = nil
            r.unconfirmed_ms = 0
            r.signal_ok = true
            self._log("CONTROL_ACCEPT", { unit = r.id, state = r.state })
        elseif now >= r.op.deadline_ms then
            -- lease 超时：没拿到权（UC 未夺权 / 信号异常）
            to_free(self, r, now, "CONTROL_REJECT", "lease_timeout")
        end

    elseif r.state == M.STATE.DELEGATED then
        local sc = a.is_script_controlled(r.id)
        if sc == false then
            -- 控制权丢了（引擎回收/玩家干预/未知）
            to_free(self, r, now, "CONTROL_RELEASE", "ownership_lost")
        elseif sc == nil then
            -- 不可确认：立即禁止发新指令（fail-closed）；
            -- 累计超限才放弃登记（信号抖动不立即掉权）
            r.signal_ok = false
            r.unconfirmed_ms = r.unconfirmed_ms + dt
            if r.unconfirmed_ms >= self._cfg.unconfirmed_drop_ms then
                to_free(self, r, now, "CONTROL_RELEASE", "stale_lease")
            end
        else
            r.unconfirmed_ms = 0
            r.signal_ok = true
        end

    elseif r.state == M.STATE.RELEASING then
        local sc = a.is_script_controlled(r.id)
        if sc == false then
            to_free(self, r, now, "CONTROL_RELEASE", "released")
        elseif now >= r.op.deadline_ms then
            if r.op.attempts < self._cfg.release_max_attempts then
                -- detach 未确认 → 重发 release（authoritative disengage）
                a.release(r.id)
                if a.halt then a.halt(r.id) end
                r.op.attempts = r.op.attempts + 1
                r.op.deadline_ms = now + self._cfg.release_timeout_ms
                self._log("CONTROL_RELEASE", {
                    unit = r.id, reason = "detach_retry", attempts = r.op.attempts })
            else
                -- 重试耗尽：登记放弃 + 标记未验证（battle-end 复查清单）
                to_free(self, r, now, "CONTROL_RELEASE", "detach_unverified")
            end
        end
    end
end

-- 请求接管某单位。opts: {priority, action_class}
-- 返回 ok, reason。ACQUIRING 状态下重复 engage 拒绝（serialize）。
function M.request_engage(self, id, opts)
    opts = opts or {}
    local now = self._a.now_ms()
    local r = rec_of(self, id)
    local priority = opts.priority or 0

    if r.lost then return false, "unit_lost" end
    if r.foreign then
        self._log("CONTROL_REJECT", { unit = id, reason = "foreign_held" })
        return false, "foreign_held"
    end
    if r.state == M.STATE.ACQUIRING or r.state == M.STATE.RELEASING then
        self._log("CONTROL_REJECT", { unit = id, reason = "op_in_flight:" .. r.state })
        return false, "op_in_flight"
    end
    if r.state == M.STATE.DELEGATED then
        return true, "already_delegated"   -- 幂等：已持有不算错
    end

    -- debounce：刚 release 完不允许立即再 engage
    if r.last_release_ms and (now - r.last_release_ms) < self._cfg.min_flip_ms then
        self._log("CONTROL_REJECT", {
            unit = id, reason = "debounce",
            ms = self._cfg.min_flip_ms - (now - r.last_release_ms) })
        return false, "debounce"
    end

    -- action cooldown（高优先级可穿）
    local cd = check_cooldown(self, r, now, opts.action_class, priority)
    if cd then
        self._log("CONTROL_REJECT", { unit = id, reason = cd, priority = priority })
        return false, cd
    end

    -- tick 预算
    if self._engages_this_tick >= self._cfg.max_engages_per_tick then
        self._log("CONTROL_REJECT", { unit = id, reason = "tick_budget" })
        return false, "tick_budget"
    end

    -- 发起接管：有显式 acquire 就调，没有则等 executor 的首个 UC 隐式夺权
    if self._a.acquire then self._a.acquire(id) end
    r.state = M.STATE.ACQUIRING
    start_op(r, "engage", now, self._cfg.settle_window_ms, priority)
    self._engages_this_tick = self._engages_this_tick + 1
    self._log("CONTROL_ACCEPT", { unit = id, state = r.state, priority = priority })
    return true, nil
end

-- 请求释放。release 可打断 ACQUIRING（abort engage），其余 FREE/RELEASING 幂等。
function M.request_release(self, id, reason)
    local now = self._a.now_ms()
    local r = self._units[id]
    if not r or r.state == M.STATE.FREE then return true, nil end
    if r.state == M.STATE.RELEASING then return true, "already_releasing" end

    -- authoritative disengage：停旧指令 → release → 验证 detach
    if self._a.halt then self._a.halt(id) end
    self._a.release(id)
    r.state = M.STATE.RELEASING
    start_op(r, "release", now, self._cfg.release_timeout_ms, 0)
    self._log("CONTROL_RELEASE", {
        unit = id, state = r.state, reason = reason or "request" })
    return true, nil
end

-- Executor 发 UC 前的门控：当前状态下该不该发这条指令
function M.can_issue(self, id, priority)
    local r = self._units[id]
    if not r then return false, "not_delegated" end
    if r.lost then return false, "unit_lost" end
    if r.foreign then return false, "foreign_held" end
    if r.state == M.STATE.FREE then return false, "not_delegated" end
    if r.state == M.STATE.RELEASING then return false, "releasing" end
    if r.state == M.STATE.DELEGATED and r.signal_ok == false then
        -- 当前对账未能确认持权 → 不发新指令（fail-closed）
        return false, "ownership_unconfirmed"
    end
    return true, nil
end

-- Executor 发完 UC 后登记 action cooldown
function M.set_cooldown(self, id, action_class, duration_ms)
    local r = rec_of(self, id)
    r.cooldowns[action_class or "_any"] =
        self._a.now_ms() + (duration_ms or self._cfg.action_cooldown_ms)
end

-- fail-closed scope 解析：失败绝不 fallthrough 成全军托管
-- scope = {type="unit", id} | {type="selection", resolve=fn} | {type="army"}
-- 返回 id 列表 或 nil, reason
function M.resolve_scope(self, scope)
    if not scope or not scope.type then return nil, "scope_unresolved" end

    if scope.type == "unit" then
        if scope.id == nil then return nil, "scope_unresolved" end
        return { scope.id }

    elseif scope.type == "selection" then
        if type(scope.resolve) ~= "function" then
            return nil, "scope_unresolved"
        end
        local ok, ids = pcall(scope.resolve)
        if not ok or type(ids) ~= "table" or #ids == 0 then
            -- 选中单位解析失败 → fail-closed，绝不扩成全军
            return nil, "scope_unresolved"
        end
        return ids

    elseif scope.type == "army" then
        if not self._cfg.allow_army_scope then
            return nil, "scope_disabled"
        end
        if type(scope.resolve) ~= "function" then
            return nil, "scope_unresolved"
        end
        local ok, ids = pcall(scope.resolve)
        if not ok or type(ids) ~= "table" or #ids == 0 then
            return nil, "scope_unresolved"
        end
        return ids
    end

    return nil, "scope_unresolved"
end

-- 战斗结束/卸载：释放全部持权单位；配合 tick() 做 detach 重试。
function M.shutdown(self, reason)
    for id, r in pairs(self._units) do
        if r.state == M.STATE.DELEGATED or r.state == M.STATE.ACQUIRING then
            self:request_release(id, reason or "shutdown")
        end
    end
end

-- 是否全部释放完毕（battle-end 轮询用）
function M.all_free(self)
    for _, r in pairs(self._units) do
        if r.state ~= M.STATE.FREE then return false end
    end
    return true
end

function M.state(self, id)
    local r = self._units[id]
    return r and r.state or M.STATE.FREE
end

function M.is_delegated(self, id)
    return self:state(id) == M.STATE.DELEGATED
end

function M.is_foreign(self, id)
    local r = self._units[id]
    return r and r.foreign or false
end

return M
