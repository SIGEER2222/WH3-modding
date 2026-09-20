-- czx_tc_counter.lua — 克制矩阵 + 双向 CounterScore
-- 设计：notes/design_army_composition_counters.md §3
--   CounterScore(me, target) = MyVsTarget − ThreatVsMe + context（context 由
--   TargetEvaluator 叠加，本模块只管克制净胜分）
-- 矩阵基准值为经验初值（设计 §3.1），全部可配置覆盖。
-- Lua 5.1，纯函数无 adapter 依赖（输入为 units.facts 产物）。

CZX_TC_COUNTER = CZX_TC_COUNTER or {}
local M = CZX_TC_COUNTER

-- 行=我方角色 列=目标类别
-- 列序：infantry / anti_large_inf / shooter / cav / monster / artillery / flyer / lord
M.COLS = { "infantry", "anti_large_inf", "shooter", "cav",
           "monster", "artillery", "flyer", "lord" }

M.MATRIX = {
    anti_large_inf = { 1.0, 1.0, 1.1, 1.5, 1.5, 1.2, 0.3, 1.1 },
    anti_inf       = { 1.3, 1.0, 1.2, 0.8, 0.6, 1.1, 0.3, 0.9 },
    melee          = { 1.0, 0.8, 1.2, 0.7, 0.5, 1.1, 0.3, 0.8 },
    shooter        = { 1.1, 1.0, 1.0, 1.2, 1.3, 0.8, 1.0, 1.2 },
    shooter_ap     = { 1.2, 1.1, 1.1, 1.2, 1.4, 0.8, 1.0, 1.4 },
    artillery_row  = { 1.4, 1.4, 0.8, 0.8, 1.2, 0.5, 0.4, 1.0 },
    shock_cav      = { 1.2, 0.5, 1.5, 0.8, 0.6, 1.5, 0.5, 0.9 },
    cav_ranged     = { 1.0, 0.6, 1.3, 0.9, 0.9, 1.3, 0.8, 0.8 },
    monster        = { 1.4, 0.9, 1.4, 1.1, 1.0, 1.4, 0.7, 1.0 },
    flyer          = { 0.9, 0.7, 1.4, 0.9, 0.9, 1.5, 1.1, 1.3 },
    mage           = { 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0 },  -- 视法术，中性
}

local function col_idx(col)
    for i, c in ipairs(M.COLS) do if c == col then return i end end
    return nil
end

local function matrix_val(row, col)
    local r = M.MATRIX[row]
    local i = col and col_idx(col)
    if not r or not i then return 1.0 end   -- 烘焙缺失 → 中性
    return r[i]
end

local function me_speed(f)
    if f.speed and f.speed.fast then return f.speed.fast end
    if f.profile and f.profile.run_speed then return f.profile.run_speed end
    return nil
end

-- 单向克制效率：me → target。返回 multiplier（1.0 中性）
function M.my_vs_target(me, me_row, target, target_col)
    local v = matrix_val(me_row, target_col)
    local mp, tp = me.profile, target.profile

    -- 反大确认：目标大型且我有 bonus_v_large → 加成量加权
    if tp and tp.is_large and mp and (mp.bonus_v_large or 0) > 0 then
        v = v * (1 + math.min(mp.bonus_v_large, 30) / 100)
    end
    -- 高甲低 AP：目标重甲且我 ap 占比低 → 打折
    if tp and (tp.armour or 0) >= 80 and mp and (mp.dmg or 0) > 0
        and (mp.ap_dmg or 0) / mp.dmg < 0.3 then
        v = v * 0.8
    end
    -- 冲锋防御/反冲锋：我是冲击骑或大型，目标有 charge_defense → 冲锋收益砍半
    if (me_row == "shock_cav" or me_row == "monster")
        and (CZX_TC_UNITS.has_attr(target, "charge_defense_vs_large")
             or CZX_TC_UNITS.has_attr(target, "charge_reflection")) then
        v = v * 0.5
    end
    -- outrange：先手加分（射程差 >20m）
    if (me.missile_range or 0) > 0 and (target.missile_range or 0) > 0
        and me.missile_range - target.missile_range > 20 then
        v = v * 1.15
    end
    -- 追不上：目标快于我 → 追击可行性扣分
    local ms, ts = me_speed(me), me_speed(target)
    if ms and ts and ts > ms then v = v * 0.85 end
    -- 恐惧：目标恐惧源且我不免疫 → 交战意愿扣分
    if (CZX_TC_UNITS.has_attr(target, "causes_fear") or CZX_TC_UNITS.has_attr(target, "causes_terror"))
        and not CZX_TC_UNITS.has_attr(me, "immune_to_psychology") then
        v = v * 0.85
    end
    -- 炮灰：击杀价值降权
    if CZX_TC_UNITS.has_attr(target, "expendable") then v = v * 0.7 end
    return v
end

-- 双向克制净胜分：[-1..~2] 区间，>0 我占便宜，<0 我被克
function M.score(me, target, opts)
    opts = opts or {}
    local me_row = opts.me_row or CZX_TC_UNITS.own_row(me)
    local target_col = opts.target_col or CZX_TC_UNITS.target_class(target)
    local mine = M.my_vs_target(me, me_row, target, target_col)
    -- 威胁侧：目标打我的效率（目标行=own_row(target)，我列=target_class(me)）
    local theirs = matrix_val(CZX_TC_UNITS.own_row(target), CZX_TC_UNITS.target_class(me))
    return mine - theirs, { mine = mine, theirs = theirs,
                            me_row = me_row, target_col = target_col }
end

return M
