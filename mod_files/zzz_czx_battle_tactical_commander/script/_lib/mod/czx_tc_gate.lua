-- czx_tc_gate.lua — 战斗类型门控（fail-closed 骨架）
-- 社区共识：CA 官方警告不建议攻城用 ai planner；AI General 3 自带
-- disable-in-siege。攻城/剧情战默认关闭，未知类型按 fail-closed 处理。
-- Lua 5.1，纯函数。

CZX_TC_GATE = CZX_TC_GATE or {}
local M = CZX_TC_GATE

-- 已知可托管的战斗类型（野战系）；不在表里的类型按配置策略走
M.FIELD_TYPES = {
    land_normal = true, land_ambush = true,
    underground = true, underway = true,
    chokepoint = true, crossing = true,
    dominance = true, survival = true,     -- [需验证] 官方类型名以 probe 为准
}

M.SIEGE_TYPES = {
    siege = true, settlement = true, siege_breakout = true,
    fort = true, minor_settlement = true,   -- [需验证] 同上
}

M.CFG = {
    disable_in_siege = true,        -- 攻城默认关（社区共识）
    allow_unknown = false,          -- 未知类型 fail-closed → 不接管
    allow_siege = false,            -- 显式开关（Phase 5 后再评估）
}

function M.new(cfg)
    local self = { _cfg = {} }
    for k, v in pairs(M.CFG) do self._cfg[k] = v end
    if cfg then for k, v in pairs(cfg) do self._cfg[k] = v end end
    return setmetatable(self, { __index = M })
end

-- battle_type: 字符串|nil（adapter.battle_type() [需验证]）
-- 返回 enabled, reason
function M.evaluate(self, battle_type)
    if battle_type == nil or battle_type == "" then
        if self._cfg.allow_unknown then return true, "unknown_allowed" end
        return false, "battle_type_unknown"     -- fail-closed
    end
    if M.SIEGE_TYPES[battle_type] then
        if self._cfg.allow_siege or not self._cfg.disable_in_siege then
            return true, "siege_override"
        end
        return false, "siege_disabled"
    end
    if M.FIELD_TYPES[battle_type] then return true, "field_battle" end
    -- 认识之外的类型
    if self._cfg.allow_unknown then return true, "unlisted_allowed" end
    return false, "battle_type_unlisted"
end

return M
