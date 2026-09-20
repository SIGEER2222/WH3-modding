-- czx_tc_log.lua
-- czx_battle_tactical_commander v2 结构化日志 + Decision 对象
-- RFC §19/§29：DECISION / CONTROL_ACCEPT / CONTROL_REJECT / CONTROL_RELEASE
-- Lua 5.1，无引擎依赖；sink 可注入（局内 → out()，离线 → print/io）
--
-- sink 约定：function(line: string) end
-- 用法：
--   local log = CZX_TC_LOG.new(function(l) out(l) end)
--   log:emit("CONTROL_REJECT", {unit="u1", reason="cooldown:move(12s)"})
--   → "CZX CONTROL_REJECT unit=u1 reason=cooldown:move(12s)"

CZX_TC_LOG = CZX_TC_LOG or {}
local M = CZX_TC_LOG

-- 字段输出顺序：高频字段优先，其余按字典序追加
local FIELD_ORDER = {
    "unit", "squad", "state", "action", "target",
    "score", "priority", "reason", "attempts", "ms",
}

local function fmt_value(v)
    if v == nil then return "-" end
    if type(v) == "number" then
        if v ~= math.floor(v) then return string.format("%.2f", v) end
        return tostring(v)
    end
    return tostring(v)
end

function M.new(sink)
    local self = { _sink = sink or function(line) print(line) end }
    return setmetatable(self, { __index = M })
end

function M.emit(self, tag, fields)
    fields = fields or {}
    local parts = { "CZX", tag }
    local seen = {}
    for _, k in ipairs(FIELD_ORDER) do
        if fields[k] ~= nil then
            parts[#parts + 1] = k .. "=" .. fmt_value(fields[k])
            seen[k] = true
        end
    end
    local rest = {}
    for k in pairs(fields) do
        if not seen[k] then rest[#rest + 1] = k end
    end
    table.sort(rest)
    for _, k in ipairs(rest) do
        parts[#parts + 1] = k .. "=" .. fmt_value(fields[k])
    end
    self._sink(table.concat(parts, " "))
end

-- RFC §19 Decision 对象
function M.decision(fields)
    local d = {
        unit_id = nil, squad_id = nil,
        role = nil, doctrine = nil, intent = nil, task = nil,
        target_id = nil, action = nil,
        score = 0, priority = 0,
        reason = {},
        issued_at = 0, expires_at = 0,
    }
    if fields then for k, v in pairs(fields) do d[k] = v end end
    return d
end

-- 把 Decision 打成 DECISION 日志行（reason 表用 + 连接）
function M.emit_decision(self, d)
    self:emit("DECISION", {
        unit = d.unit_id, squad = d.squad_id,
        role = d.role, task = d.task,
        target = d.target_id, action = d.action,
        score = d.score, priority = d.priority,
        reason = table.concat(d.reason or {}, "+"),
    })
end

return M
