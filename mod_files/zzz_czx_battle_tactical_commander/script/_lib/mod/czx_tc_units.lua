-- czx_tc_units.lua — 单位 facts 抽取 + Role 分类
-- 数据源：adapter 运行时信号（L1）+ CZX_UNIT_PROFILE 烘焙表（L0）
-- Role 链（社区证据 §2.1）：can_fly → 炮兵/战争机器 → 骑兵/战车 → 巨兽
--   → 指挥官 → 弹药射程 → melee 兜底；烘焙表 ai_role 优先，未知单位回退布尔链
-- Lua 5.1。adapter 缺方法/返回 nil 一律容忍（fail-soft）。

CZX_TC_UNITS = CZX_TC_UNITS or {}
local M = CZX_TC_UNITS

local function call(a, name, id, ...)
    local f = a[name]
    if type(f) ~= "function" then return nil end
    local ok, v = pcall(f, id, ...)
    if not ok then return nil end
    return v
end

-- 需要回读的属性集（克制修正用；is/has_attribute 签名 [需验证]，
-- 离线与局内都用同一份清单）
M.PROBE_ATTRS = {
    "charge_defense_vs_large", "charge_reflection",
    "causes_fear", "causes_terror", "immune_to_psychology",
    "unbreakable", "expendable", "stalk", "unspottable", "snipe",
}

-- adapter → UnitFact。所有字段可 nil，调用方必须容忍。
function M.facts(a, id)
    local f = {
        id = id,
        type = call(a, "unit_type", id),                    -- [需验证]
        pos = call(a, "position", id),                      -- {x,y,z}
        hp = call(a, "unary_hitpoints", id),
        men_alive = call(a, "number_of_men_alive", id),
        fatigue = call(a, "fatigue_state", id),
        morale = {
            wavering = call(a, "is_wavering", id),
            routing = call(a, "is_routing", id),
            shattered = call(a, "is_shattered", id),
            crumbling = call(a, "is_crumbling", id),
            rampaging = call(a, "is_rampaging", id),
        },
        in_melee = call(a, "is_in_melee", id),
        under_attack = call(a, "is_under_attack", id),
        under_missile = call(a, "is_under_missile_attack", id),
        flank_threat = {
            left = call(a, "is_left_flank_threatened", id),
            right = call(a, "is_right_flank_threatened", id),
            rear = call(a, "is_rear_flank_threatened", id),
        },
        idle = call(a, "is_idle", id),
        visible = call(a, "is_visible_to_alliance", id),
        hidden = call(a, "is_hidden", id),
        strategic_value = call(a, "strategic_value", id),
        ammo = call(a, "ammo_left", id),
        max_ammo = call(a, "starting_ammo", id),
        missile_range = call(a, "missile_range", id),
        speed = { fast = call(a, "fast_speed", id), slow = call(a, "slow_speed", id) },
        can_use_magic = call(a, "can_use_magic", id),
        invulnerable = call(a, "is_invulnerable", id),
        ordered_pos = call(a, "ordered_position", id),
        current_target = call(a, "current_target", id),
        -- 布尔分类链
        b = {
            infantry = call(a, "is_infantry", id),
            pikemen = call(a, "is_pikemen", id),
            anti_cav_inf = call(a, "is_anti_cavalry_infantry", id),
            cavalry = call(a, "is_cavalry", id),
            lancers = call(a, "is_lancers", id),
            chariot = call(a, "is_chariot", id),
            camels = call(a, "is_camels", id),
            elephants = call(a, "is_elephants", id),
            war_beasts = call(a, "is_war_beasts", id),
            artillery = call(a, "is_artillery", id),
            war_machine = call(a, "is_war_machine", id),
            fixed_artillery = call(a, "is_fixed_artillery", id),
            can_fly = call(a, "can_fly", id),
            flying = call(a, "is_currently_flying", id),
            commanding = call(a, "is_commanding_unit", id),
        },
        attrs = {},
    }
    -- 属性回读（has_attribute 若只认模板属性，L2 误差见设计 §1.5）
    for _, attr in ipairs(M.PROBE_ATTRS) do
        local v = call(a, "has_attribute", id, attr)
        if v == true then f.attrs[attr] = true end
    end
    -- 烘焙档案
    local profs = rawget(_G, "CZX_UNIT_PROFILE")
    f.profile = (f.type and profs) and profs[f.type] or nil
    return f
end

-- 目标列分类（克制矩阵列）：lord/artillery/flyer/monster/cav/shooter/anti_large_inf/infantry
-- 烘焙表优先，布尔链兜底。
function M.target_class(f)
    local b = f.b or {}
    local p = f.profile
    if b.commanding == true or (p and p.class == "com") then return "lord" end
    if b.artillery == true or b.war_machine == true
        or (p and (p.category == "artillery" or p.category == "war_machine")) then
        return "artillery"
    end
    if b.can_fly == true or (p and p.fly_speed and p.fly_speed > 0) then return "flyer" end
    if b.war_beasts == true or b.elephants == true or (p and p.is_large) then
        return "monster"
    end
    if b.cavalry == true or b.chariot == true or b.lancers == true
        or b.camels == true or (p and p.category == "cavalry") then
        return "cav"
    end
    -- 射手：烘焙 ai_role ranged* / 有射程弹药
    if p and p.ai_role and p.ai_role:find("^ranged") then return "shooter" end
    if (f.missile_range or 0) > 20 and (f.ammo or 0) > 0 then return "shooter" end
    if p and (p.ai_role == "melee_anti_large" or (p.bonus_v_large or 0) >= 10) then
        return "anti_large_inf"
    end
    if b.pikemen == true or b.anti_cav_inf == true then return "anti_large_inf" end
    return "infantry"
end

-- 我方行分类（克制矩阵行）：命令单位按 archetype 归并
local AI_ROLE_ROW = {
    melee_anti_large = "anti_large_inf",
    melee_gatecrusher = "monster",
    melee_gatecrusher_shock = "monster",
    melee_gatecrusher_highvalue = "monster",
    ranged_indirect_arty = "artillery_row",
    gyrocopter = "flyer",
    thunderbarge = "flyer",
    sky_junk = "flyer",
    sky_lantern = "flyer",
    mage_highvalue = "mage",
    melee_mage_highvalue = "mage",
}

function M.own_row(f)
    local b = f.b or {}
    local p = f.profile
    -- 烘焙 ai_role 优先
    if p and p.ai_role and p.ai_role ~= "" then
        local r = AI_ROLE_ROW[p.ai_role]
        if r then return r end
        if p.ai_role:find("^flying") then return "flyer" end
        if p.ai_role:find("^ranged") then
            -- AP 射手：ap 占比过半
            if (p.ap_dmg or 0) > 0 and (p.dmg or 0) > 0
                and p.ap_dmg / p.dmg >= 0.5 then
                return "shooter_ap"
            end
            return "shooter"
        end
        if p.ai_role:find("^hybrid") then return "mage" end
        if p.ai_role:find("flanker") and p.ai_role:find("shock") then return "shock_cav" end
        if p.ai_role:find("harasser") then return "cav_ranged" end
        -- melee* 步兵按 bonus 细分
        if (p.bonus_v_large or 0) >= 10 then return "anti_large_inf" end
        if (p.bonus_v_inf or 0) >= 10 then return "anti_inf" end
        if p.is_large then return "monster" end
        return "melee"
    end
    -- 布尔链兜底（未知单位）
    if b.cavalry == true or b.chariot == true then
        if (f.missile_range or 0) > 20 and (f.ammo or 0) > 0 then return "cav_ranged" end
        return "shock_cav"
    end
    if b.artillery == true or b.war_machine == true then return "artillery_row" end
    if b.can_fly == true then return "flyer" end
    if b.war_beasts == true or b.elephants == true then return "monster" end
    if f.can_use_magic == true then return "mage" end
    if (f.missile_range or 0) > 20 and (f.ammo or 0) > 0 then return "shooter" end
    if b.pikemen == true or b.anti_cav_inf == true then return "anti_large_inf" end
    return "melee"
end

-- 简版战术角色（行为层用）：artillery/flyer/cav/monster/commander/shooter/melee
-- v1 role-probe 的布尔链升级版
function M.tactical_role(f)
    local b = f.b or {}
    if b.commanding == true then return "commander" end
    if b.artillery == true or b.war_machine == true then return "artillery" end
    if b.can_fly == true then return "flyer" end
    if b.cavalry == true or b.chariot == true then return "cav" end
    if b.war_beasts == true or b.elephants == true then return "monster" end
    if (f.missile_range or 0) > 20 and (f.ammo or 0) > 0 then return "shooter" end
    return "melee"
end

function M.dist(a, b)
    local pa, pb = a.pos, b.pos
    if not pa or not pb then return nil end
    local dx, dy = (pa.x or 0) - (pb.x or 0), (pa.y or 0) - (pb.y or 0)
    return math.sqrt(dx * dx + dy * dy)
end

function M.has_attr(f, attr)
    return (f.attrs and f.attrs[attr] == true)
        or (f.profile and f.profile.attrs and (function()
            for _, x in ipairs(f.profile.attrs) do
                if x == attr then return true end
            end return false end)())
end

return M
