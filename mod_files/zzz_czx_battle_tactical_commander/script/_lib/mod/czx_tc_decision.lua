-- czx_tc_decision.lua — Decision 生命周期注册器（RFC §19/§20/§21）
-- Observe→Assess→Candidates→Score→Validate→Issue→Monitor→Complete/Abort/Replan
-- 本模块管后半段：登记已发决策 → 监控有效性 → 产出 replan 触发事件。
-- 三类触发（§21）：周期评估、事件驱动（目标死/威胁变/任务失效）、超时。
-- Lua 5.1，纯逻辑：有效性检查经注入的 world 查询函数，离线可测。

CZX_TC_DECISION = CZX_TC_DECISION or {}
local M = CZX_TC_DECISION

M.CFG = {
    default_ttl_ms = 15000,        -- 决策默认有效期（Timeout Replan §21.3）
    periodic_ms = 3000,            -- Periodic Assessment §21.1
}

function M.new(cfg, log)
    local self = {
        _cfg = {},
        _log = log or function() end,
        _active = {},              -- unit_id -> decision
        _last_periodic_ms = 0,
        _events = {},              -- 待消费 replan 事件队列
    }
    for k, v in pairs(M.CFG) do self._cfg[k] = v end
    if cfg then for k, v in pairs(cfg) do self._cfg[k] = v end end
    return setmetatable(self, { __index = M })
end

local function push_event(self, kind, fields)
    fields = fields or {}
    fields.kind = kind
    self._events[#self._events + 1] = fields
end

-- 登记已发出的决策（Issue 之后调用）
-- d: Decision 对象（czx_tc_log.decision 结构）
function M.issue(self, d)
    if self._active[d.unit_id] then
        push_event(self, "superseded", { unit = d.unit_id, task = d.task })
    end
    self._active[d.unit_id] = d
    self._log("DECISION", {
        unit = d.unit_id, squad = d.squad_id, role = d.role, task = d.task,
        target = d.target_id, action = d.action,
        score = d.score, priority = d.priority,
        reason = table.concat(d.reason or {}, "+"),
    })
end

-- 每 tick 监控。
-- world 查询契约（注入，fail-soft：nil=不可确认→不判死）：
--   unit_alive(id) -> bool|nil      单位还在战场
--   unit_broken(id) -> bool|nil     shattered/routing
--   task_valid(d)   -> bool|nil     任务仍有效（可缺省=恒真）
--   threat_gone(d)  -> bool|nil     触发该决策的威胁已消失
function M.tick(self, now_ms, world)
    world = world or {}
    -- Periodic Assessment
    if now_ms - self._last_periodic_ms >= self._cfg.periodic_ms then
        self._last_periodic_ms = now_ms
        push_event(self, "periodic", { ms = now_ms })
    end

    for uid, d in pairs(self._active) do
        local done, why = false, nil

        if world.unit_alive and world.unit_alive(uid) == false then
            done, why = true, "unit_gone"
        elseif world.task_valid and world.task_valid(d) == false then
            done, why = true, "task_invalid"
        elseif d.target_id then
            if world.unit_alive and world.unit_alive(d.target_id) == false then
                done, why = true, "target_dead"
            elseif world.unit_broken and world.unit_broken(d.target_id) == true then
                done, why = true, "target_broken"
            elseif world.threat_gone and world.threat_gone(d) == true then
                done, why = true, "threat_gone"
            end
        end

        if not done and d.expires_at and d.expires_at > 0 and now_ms >= d.expires_at then
            done, why = true, "expired"
        end

        if done then
            self._active[uid] = nil
            local tag = (why == "target_dead" or why == "task_invalid"
                or why == "threat_gone") and "TASK_COMPLETE" or "TASK_ABORT"
            if why == "target_dead" then tag = "TASK_COMPLETE" end
            self._log(tag, { unit = uid, task = d.task, reason = why })
            push_event(self, "replan", {
                unit = uid, task = d.task, reason = why })
        end
    end
end

-- 事件驱动 replan（§21.2）：外部世界事件直接注入
function M.notify(self, kind, fields)
    push_event(self, kind, fields)
end

-- 取走待消费事件
function M.drain_events(self)
    local ev = self._events
    self._events = {}
    return ev
end

function M.active(self, unit_id)
    return self._active[unit_id]
end

function M.count(self)
    local n = 0
    for _ in pairs(self._active) do n = n + 1 end
    return n
end

return M
