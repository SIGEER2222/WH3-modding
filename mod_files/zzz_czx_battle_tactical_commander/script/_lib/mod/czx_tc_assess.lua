-- czx_tc_assess.lua — ArmyComposition + BattleAssessment + phase 推导 + Intent 倾向
-- 设计：RFC §9 + design_army_composition_counters.md §2
-- 硬约束（复核 R10）：phase 是派生量 phase = f(assessment)，禁止反向写入。
-- 敌单位只统计 is_visible_to_alliance（fail-closed 视野，防作弊感）。
-- Lua 5.1，纯函数：输入 units.facts 列表，无 adapter 依赖。

CZX_TC_ASSESS = CZX_TC_ASSESS or {}
local M = CZX_TC_ASSESS

M.CFG = {
    armoured_threshold = 80,        -- 烘焙 armour >= 80 算重甲
    crisis_shattered_share = 0.15,  -- 我方 shattered 占比 → crisis
    cleanup_enemy_alive_share = 0.25,
    engagement_contact_share = 0.3, -- 我方 in_melee 占比 → engagement
    large_is_monster = true,
}

-- ------------------------------------------------------------ composition
-- facts: unit fact 列表（单方）；返回 share 向量（§2）
function M.composition(facts)
    local c = {
        n = 0,
        melee = 0, shooter = 0, artillery = 0,
        cav = 0, monster = 0, flyer = 0,
        lord = 0, caster = 0,
        mobile = 0, large = 0, armoured = 0,
        range_sum = 0, range_n = 0,
        hp_pool = 0, hp_pool_max = 0,
        threat_pool = 0,             -- strategic_value 和（粗战力）
    }
    for _, f in ipairs(facts or {}) do
        local role = CZX_TC_UNITS.tactical_role(f)
        local p = f.profile
        c.n = c.n + 1
        if role == "artillery" then c.artillery = c.artillery + 1
        elseif role == "flyer" then c.flyer = c.flyer + 1
        elseif role == "cav" then c.cav = c.cav + 1
        elseif role == "monster" then c.monster = c.monster + 1
        elseif role == "commander" then c.lord = c.lord + 1
        elseif role == "shooter" then c.shooter = c.shooter + 1
        else c.melee = c.melee + 1 end
        if f.can_use_magic == true then c.caster = c.caster + 1 end
        if role == "cav" or role == "flyer" or (f.b and f.b.chariot == true) then
            c.mobile = c.mobile + 1
        end
        if (p and p.is_large) or (f.b and (f.b.war_beasts or f.b.elephants)) then
            c.large = c.large + 1
        end
        if p and (p.armour or 0) >= M.CFG.armoured_threshold then
            c.armoured = c.armoured + 1
        end
        if (f.missile_range or 0) > 0 then
            c.range_sum = c.range_sum + f.missile_range
            c.range_n = c.range_n + 1
        end
        if f.hp and f.men_alive then
            c.hp_pool = c.hp_pool + f.hp * f.men_alive
            c.hp_pool_max = c.hp_pool_max + f.men_alive
        end
        c.threat_pool = c.threat_pool + (f.strategic_value or 0)
    end
    local n = math.max(c.n, 1)
    c.melee_share = c.melee / n
    c.shooter_share = c.shooter / n
    c.artillery_share = c.artillery / n
    c.cav_share = c.cav / n
    c.monster_share = c.monster / n
    c.flyer_share = c.flyer / n
    c.mobile_share = c.mobile / n
    c.large_share = c.large / n
    c.armoured_share = c.armoured / n
    c.avg_range = c.range_n > 0 and c.range_sum / c.range_n or 0
    return c
end

-- ------------------------------------------------------------ assessment
-- my_facts/enemy_facts：facts 列表；敌方已按可见性过滤
-- 返回 RFC §9 结构 + phase（派生）
function M.assess(my_facts, enemy_facts, prev)
    local me = M.composition(my_facts)
    local fo = M.composition(enemy_facts)

    -- 多维威胁（§2.1 敌方构成加权）
    local a = {
        frontline = { pressure = 0, power_ratio = 1.0 },
        left_flank = { pressure = 0, breakthrough = false },
        right_flank = { pressure = 0, breakthrough = false },
        backline = { threat = 0, under_attack = false },
        artillery = { threat = 0, safe = true },
        commander = { threat = 0 },
        engaged_share = 0,
        my_shattered = 0,
    }

    local my_n = math.max(me.n, 1)
    local engaged = 0
    local left_threats, right_threats, rear_threats = 0, 0, 0
    local backline_attackers = 0
    local commander_threat = 0
    local arty_threatened = 0

    for _, f in ipairs(my_facts or {}) do
        if f.in_melee == true then engaged = engaged + 1 end
        if f.morale and (f.morale.shattered or f.morale.routing) then
            a.my_shattered = a.my_shattered + 1
        end
        local ft = f.flank_threat or {}
        if ft.left == true then left_threats = left_threats + 1 end
        if ft.right == true then right_threats = right_threats + 1 end
        if ft.rear == true then rear_threats = rear_threats + 1 end
        local role = CZX_TC_UNITS.tactical_role(f)
        if (role == "shooter" or role == "artillery") and f.under_attack == true then
            backline_attackers = backline_attackers + 1
        end
        if role == "artillery" and (f.under_attack == true or f.in_melee == true) then
            arty_threatened = arty_threatened + 1
        end
        if role == "commander" and (f.under_attack == true or f.in_melee == true
            or (f.hp or 1) < 0.4) then
            commander_threat = commander_threat + 1
        end
    end

    a.engaged_share = engaged / my_n
    a.left_flank.pressure = left_threats / my_n + fo.mobile_share * 0.3
    a.right_flank.pressure = right_threats / my_n + fo.mobile_share * 0.3
    a.left_flank.breakthrough = a.left_flank.pressure > 0.4
    a.right_flank.breakthrough = a.right_flank.pressure > 0.4
    -- 后排威胁：被打的远程/炮兵数 + 敌方机动占比加权
    a.backline.threat = backline_attackers / my_n + fo.mobile_share * 0.4
    a.backline.under_attack = backline_attackers > 0
    a.artillery.threat = arty_threatened / math.max(me.artillery, 1)
    a.artillery.safe = arty_threatened == 0
    a.commander.threat = commander_threat
    a.frontline.power_ratio =
        (fo.threat_pool > 0) and (me.threat_pool / fo.threat_pool) or 1.0
    a.frontline.pressure = engaged / my_n

    -- §2.2 敌我对比量（Intent 输入）
    a.range_advantage = me.avg_range - fo.avg_range
    a.hp_pool_ratio = (fo.hp_pool > 0) and (me.hp_pool / fo.hp_pool) or 1.0
    a.enemy_mobile_share = fo.mobile_share
    a.enemy_large_share = fo.large_share
    a.enemy_armoured_share = fo.armoured_share
    a.enemy_artillery = fo.artillery
    a.enemy_n = fo.n
    a.my_n = me.n

    a.phase = M.phase(a, prev and prev.phase)
    return a
end

-- phase = f(assessment) 派生；prev 只用于迟滞防抖，不允许反向写
function M.phase(a, prev)
    local cfg = M.CFG
    if a.my_n == 0 then return "cleanup" end
    if a.enemy_n == 0 or (a.my_shattered / a.my_n) >= cfg.crisis_shattered_share then
        -- 敌全灭 → cleanup；我方崩溃面大 → crisis（崩溃优先于 cleanup 判断顺序：
        -- 我方 shattered 才是真 crisis）
        if (a.my_shattered / a.my_n) >= cfg.crisis_shattered_share then return "crisis" end
        if a.enemy_n == 0 then return "cleanup" end
    end
    if a.backline.under_attack or a.commander.threat > 0
        or a.left_flank.breakthrough or a.right_flank.breakthrough then
        return "crisis"
    end
    if a.engaged_share >= cfg.engagement_contact_share then return "engagement" end
    if a.engaged_share > 0 then return "advance" end
    return prev == "advance" and "advance" or "setup"
end

-- ------------------------------------------------------------ intent
-- §2.2 敌我对比 → 倾向排序：返回 {intent=权重, ...} + reasons
function M.intent(a, doctrine_bias)
    local w = {
        maintain_position = 0, protect_gunline = 0, hold_flank = 0,
        advance = 0, force_engagement = 0, counter_attack = 0,
        exploit_breakthrough = 0, preserve_commander = 0,
        recover_formation = 0, cleanup = 0,
        anti_large_posture = 0, protect_backline = 0,
        silence_enemy_artillery = 0,
    }
    local reasons = {}

    local function bump(k, v, why)
        w[k] = w[k] + v
        reasons[#reasons + 1] = why
    end

    -- 远程对射基本盘：outrange 守，被 outrange 必须推进（蹲=慢性死亡）
    if a.range_advantage > 15 then
        bump("maintain_position", 2, "range_advantage>0")
        bump("protect_gunline", 2, "firepower_edge")
    elseif a.range_advantage < -15 then
        bump("advance", 3, "outranged_must_push")
        bump("force_engagement", 2, "ranged_duel_losing")
    end
    -- 敌机动高 + 我后排脆 → 护侧护后排
    if a.enemy_mobile_share > 0.25 and (a.backline.threat > 0.1 or true) then
        bump("hold_flank", 2, "enemy_mobile_high")
        bump("protect_backline", 2, "backline_fragile")
    end
    -- 敌大型高 → 反大预备队
    if a.enemy_large_share > 0.15 then
        bump("anti_large_posture", 2, "enemy_large_share")
    end
    -- 敌炮兵存在 → 压制任务
    if (a.enemy_artillery or 0) > 0 then
        bump("silence_enemy_artillery", 1, "enemy_artillery_present")
    end
    -- 血池悬殊
    if a.hp_pool_ratio > 1.4 then
        bump("counter_attack", 2, "hp_pool_dominant")
        bump("exploit_breakthrough", 1, "advantage")
    elseif a.hp_pool_ratio < 0.7 then
        bump("preserve_commander", 2, "hp_pool_losing")
    end
    -- phase 兜底
    if a.phase == "crisis" then
        bump("recover_formation", 3, "phase_crisis")
        bump("preserve_commander", 2, "phase_crisis")
    elseif a.phase == "cleanup" then
        bump("cleanup", 3, "phase_cleanup")
    end

    -- doctrine bias：gunline 守势加权 / rush 攻势加权
    local d = doctrine_bias or {}
    if d.ranged_protection then bump("protect_gunline", d.ranged_protection - 1, "doctrine") end
    if d.chase_penalty and d.chase_penalty < 1 then
        bump("counter_attack", 1 - d.chase_penalty, "doctrine_rush")
    end

    -- 排序
    local ranked = {}
    for k, v in pairs(w) do if v > 0 then ranked[#ranked + 1] = { k, v } end end
    table.sort(ranked, function(x, y) return x[2] > y[2] end)
    return ranked, reasons
end

return M
