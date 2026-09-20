-- czx_probe.lua — Telemetry Probe（TESTING.md §0，先于一切新层）
-- 独立探针脚本：每 tick dump 全战场可得字段 + 一次性环境探测。
-- 所有 API 调用包 pcall，失败记 ERR=<err>——失败本身就是要收集的数据。
-- 用法：临时放入 pack 或与主 mod 并存，打一场自定义战斗后收日志。

if not bm then return end                                        -- bm 为 battle 全局（同 czx_bridge/v1），无 get_bm()

local function out_kv(tag, kv)
    local parts = { "CZX_PROBE", tag }
    for k, v in pairs(kv) do
        parts[#parts + 1] = tostring(k) .. "=" .. tostring(v)
    end
    out(table.concat(parts, " "))
end

-- pcall 包装：成功返回值，失败返回 "ERR:..." 字符串
local function try(f, ...)
    local arg = { ... }
    local ok, v = pcall(function() return f(unpack(arg)) end)
    if ok then return v end
    return "ERR:" .. tostring(v)
end

local function probe_bool(u, method)
    local f = u[method]
    if type(f) ~= "function" then return "NO_API" end
    return try(function() return f(u) end)
end

local function probe_val(u, method)
    return probe_bool(u, method)
end

-- ================================================================ 环境探测（一次）
local function probe_env()
    out("CZX_PROBE === ENV START ===")
    -- IPC / 沙箱能力（决定 bridge T2 可行性）
    out_kv("env", { io_open = type(io) ~= "nil" and type(io.open) })
    if io and io.open then
        local f = try(function() return io.open("czx_probe.txt", "w") end)
        out_kv("env", { io_open_write = type(f) })
        if type(f) ~= "string" and f and f.close then
            pcall(function()
                f:write("czx_probe io test\n"); f:close()
            end)
        end
    end
    out_kv("env", { os_clock = try(function() return os.clock() end) })
    out_kv("env", { os_time = try(function() return os.time() end) })
    out_kv("env", { os_date = try(function() return os.date and os.date() end) })
    -- 战斗类型（门控输入）
    out_kv("env", { battle_type = try(function() return bm:battle_type() end) })
    out_kv("env", { battle_sub_type = try(function() return bm.battle_sub_type
        and bm:battle_sub_type() end) })
    -- capture_location（Objectives 层）
    local clm = try(function() return bm:capture_location_manager() end)
    out_kv("env", { capture_location_manager = type(clm) })
    -- serialise_state（离线 replay 输入）
    out_kv("env", { script_units_serialise = "see unit probe" })
    out("CZX_PROBE === ENV END ===")
end

-- ================================================================ 单位 dump
local UNIT_METHODS = {
    -- 分类布尔链（社区 §2.1 已确认）
    "is_infantry", "is_pikemen", "is_anti_cavalry_infantry",
    "is_cavalry", "is_lancers", "is_dismounted_cavalry", "is_chariot",
    "is_camels", "is_elephants", "is_war_beasts",
    "is_artillery", "is_unlimbered", "is_limbered", "is_fixed_artillery",
    "is_war_machine", "can_fly", "is_currently_flying",
    "is_commanding_unit",
    -- 威胁/状态（社区 §2.3）
    "is_left_flank_threatened", "is_right_flank_threatened",
    "is_rear_flank_threatened", "left_flank_threat", "right_flank_threat",
    "rear_threat",
    "is_under_attack", "is_in_melee", "is_under_missile_attack",
    "is_wavering", "is_routing", "is_shattered", "is_crumbling",
    "is_unstable", "is_rampaging",
    "unary_hitpoints", "number_of_men_alive", "fatigue_state",
    -- 控制（社区 §2.2）
    "is_script_controlled", "is_ai_controlled", "is_player_controlled",
    "is_controllable", "ordered_position", "ordered_bearing",
    "ordered_width", "current_target", "can_reach_position",
    -- 视野
    "is_visible_to_alliance", "is_hidden",
    -- 数值/身份
    "unit_class", "type", "name", "strategic_value",
    "missile_range", "ammo_left", "starting_ammo",
    "fast_speed", "slow_speed", "position", "bearing",
    "can_use_magic", "owned_special_abilities",
    "can_perform_special_ability", "is_invulnerable",
    "is_behaviour_active", "is_idle", "is_on_top_of_platform",
    "has_attribute",
}

local function dump_unit(su)
    local kv = {}
    kv.id = try(function() return su.name end)                   -- script_unit.name 字段
    kv.unit_type = try(function() return su.unit and su.unit:type() end)
    local u = try(function() return su.unit end)                 -- script_unit.unit 字段（battle_unit 接口）
    if type(u) ~= "userdata" and type(u) ~= "table" then
        out_kv("unit_err", { id = kv.id, err = u })
        return
    end
    for _, m in ipairs(UNIT_METHODS) do
        -- has_attribute 需要参数，单独探测
        if m == "has_attribute" then
            kv.has_attribute_charge_refl = probe_val(u, m)
        else
            kv[m] = probe_val(u, m)
        end
    end
    -- serialise_state 在 script_units 集合上，这里先记 unit 侧可得性
    out_kv("unit", kv)
end

-- ================================================================ 主循环
local elapsed = 0
local TICK = 3000
local env_done = false

local function probe_tick()
    elapsed = elapsed + TICK
    if not env_done then
        env_done = true
        probe_env()
    end
    local n = 0
    -- bm:armies() 不存在；走 bm.scriptunits 缓存（lib_battle_manager 已确认）
    -- get_scriptunits_for_army 出错返回 false；try 的 ERR 字符串用 tonumber 挡掉
    local function dump_collection(sus)
        if type(sus) ~= "table" and type(sus) ~= "userdata" then return end
        for j = 1, tonumber(try(function() return sus:count() end)) or 0 do
            local su = try(function() return sus:item(j) end)
            if su then
                dump_unit(su)
                n = n + 1
            end
        end
    end
    for al = 1, tonumber(try(function() return bm:num_alliances() end)) or 0 do
        for ar = 1, tonumber(try(function() return bm:num_armies_in_alliance(al) end)) or 0 do
            dump_collection(try(function() return bm:get_scriptunits_for_army(al, ar) end))
            for r = 1, tonumber(try(function()
                return bm:num_reinforcing_armies_for_army_in_alliance(al, ar)
            end)) or 0 do
                dump_collection(try(function() return bm:get_scriptunits_for_army(al, ar, r) end))
            end
        end
    end
    out_kv("tick", { ms = elapsed, units = n })
end

-- pcall 兜底：报错只记日志，不得杀死 timer_manager 泵（同 commander 注释）
bm:repeat_callback(function()                                     -- [需验证]
    local ok, err = pcall(probe_tick)
    if not ok then
        out_kv("ERROR", { ms = elapsed, err = err })
    end
end, TICK, "czx_probe_tick")

out("CZX_PROBE loaded")
