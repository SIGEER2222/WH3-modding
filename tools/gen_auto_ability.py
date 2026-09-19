"""Generate czx_battle_auto_ability.lua (flags data + logic) into mod_files/zzz_czx_battle_ui."""
import csv, glob, io, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "mod_files" / "zzz_czx_battle_ui" / "script" / "battle" / "mod" / "czx_battle_auto_ability.lua"

sources = [ROOT / "gamedata" / "db" / "unit_special_abilities_tables" / "data__.tsv"]
sources += sorted(glob.glob(str(ROOT / "mod_files" / "*" / "db" / "unit_special_abilities_tables" / "*.tsv")))

rows = {}
for p in sources:
    p = Path(p)
    with open(p, encoding="utf-8-sig", newline="") as f:
        rd = csv.reader(f, delimiter="\t")
        lines = [r for r in rd if r and r[0] and not r[0].startswith("#")]
        if not lines:
            continue
        h = lines[0]
        idx = {k: h.index(k) for k in ("key", "passive", "target_ground", "target_enemies",
                                      "target_friends", "affect_self", "target_self",
                                      "mana_cost", "recharge_time") if k in h}
        for r in lines[1:]:
            key = r[idx["key"]].strip()
            if not key:
                continue
            def b(col):
                return idx.get(col) is not None and r[idx[col]].strip().lower() == "true"
            def num(col):
                try:
                    return float(r[idx[col]]) if idx.get(col) is not None and r[idx[col]].strip() else 0.0
                except ValueError:
                    return 0.0
            if b("passive"):
                continue
            mask = (1 if b("target_ground") else 0) | (2 if b("target_enemies") else 0)                  | (4 if b("target_friends") else 0) | (8 if (b("affect_self") or b("target_self")) else 0)                  | (16 if num("mana_cost") > 0 else 0)
            rows[key] = (mask, int(num("recharge_time")))

data_lines = [f'    ["{k}"] = "{m},{r}",' for k, (m, r) in sorted(rows.items())]
data = "\n".join(data_lines)

# --- unit profiles for role classification, baked from land_units ---
# vanilla export lives in the tactical-commander RFC workspace; mod units come
# from each mod's own land_units tsv. Format: "ai_role|category|class|is_large"
lu_sources = [
    ROOT / "mod_files" / "czx_battle_tactical_commander" / "czx_battle_tactical_commander"
    / "data" / "vanilla" / "land_units_tables.tsv"
]
lu_sources += sorted(glob.glob(str(ROOT / "mod_files" / "*" / "db" / "land_units_tables" / "*.tsv")))

profiles = {}
for p in lu_sources:
    p = Path(p)
    if not p.is_file():
        continue
    with open(p, encoding="utf-8-sig", newline="") as f:
        rd = csv.reader(f, delimiter="\t")
        lines = [r for r in rd if r and r[0] and not r[0].startswith("#")]
        if not lines:
            continue
        h = lines[0]
        idx = {k: h.index(k) for k in ("key", "ai_usage_group", "category", "class",
                                      "ground_stat_effect_group") if k in h}
        if "key" not in idx:
            continue
        for r in lines[1:]:
            if len(r) <= max(idx.values()):
                continue
            key = r[idx["key"]].strip()
            if not key:
                continue
            def cell(col):
                return r[idx[col]].strip() if col in idx else ""
            is_large = "large" in cell("ground_stat_effect_group").lower()
            profiles[key] = "|".join([
                cell("ai_usage_group"), cell("category"), cell("class"),
                "1" if is_large else "0"])

profile_lines = [f'    ["{k}"] = "{v}",' for k, v in sorted(profiles.items())]
profile_data = "\n".join(profile_lines)

template = '''---------------------------------------------------------------------------------------------
-- czx_battle_auto_ability.lua
-- Auto-cast non-passive special abilities for delegated (AI-controlled) player units.
-- Complements AI General-style delegation: planner units never self-cast, so we poll and
-- fire ready abilities through their script_unit's unitcontroller (order + release_control,
-- which does not detach the unit from its ai_planner).
---------------------------------------------------------------------------------------------

local CONFIG = {
    enabled          = true,
    poll_ms          = 3000,    -- scan interval
    retry_ms         = 20000,   -- min delay between attempts of the same ability on the same unit
    cast_spells      = true,    -- false = skip abilities with mana_cost > 0
    engage_range_m   = 120,     -- only attempt casts when nearest enemy is within this distance (m)
    unit_keys        = {},      -- non-empty = only these unit keys auto-cast, e.g. {"czx_dgm_wargreymon"}
    banned_abilities = {},      -- ability keys never auto-cast
    auto_cast        = false,   -- master switch: false = never call perform_special_ability (sim-freeze kill switch)
    cast_on_summons  = false,   -- summoned units despawn mid-effect and can wedge the sim; skip their abilities
    cast_quiet_ms    = 6000,    -- after a successful cast, suppress task orders on that unit this long
    -- idle-kicker: delegated units the planner leaves standing around get nudged
    -- toward the nearest enemy. Ordering an already-idle unit interrupts nothing.
    idle_kick        = true,
    idle_kick_after_s= 3,       -- unit must stay continuously idle this long first
    order_retry_ms   = 6000,    -- min gap between task orders to the same unit
                                -- (shorter than ability retry — re-targeting a
                                -- unit whose enemy just died must be fast)
    idle_kick_range_m= 400,     -- only nudge if nearest enemy within this distance
    -- doctrine engine: pick a battle plan from delegated army composition each
    -- tick, then run per-role behaviours. "auto" detects; or force a doctrine.
    doctrine         = "auto",  -- "auto" | "gunline" | "balanced" | "rush" | "kite" | "none"
    gunline_min_share= 0.35,    -- auto: gunline if >=35% of delegated units carry ammo
    rush_max_shooter_share = 0.15, -- auto: rush if <=15% carry ammo
    kite_min_mobile_share  = 0.70, -- auto: kite if >=70% are cav/flyers
    -- role classification thresholds
    cav_min_speed    = 60,      -- fast_speed() >= this counts as cavalry-class
    artillery_min_range = 250,  -- missile_range() >= this counts as artillery
    -- screen radii (gunline tight / balanced loose)
    intercept_radius_m = 110,   -- screens attack enemies within this of themselves
    protect_radius_m = 100,     -- ... or within this of a delegated ranged unit
    leash_radius_m   = 160,     -- screens farther than this from the line fall back toward it
    bal_intercept_radius_m = 150,
    bal_leash_radius_m   = 220,
    cav_intercept_radius_m = 200, -- cav reserve intercepts threats further out
    flank_hunt_range_m = 400,   -- cav in non-gunline doctrines hunt enemy shooters within this
    flyer_hunt_range_m = 500,   -- flyers hunt enemy flyers/artillery within this
    shooter_hold_mult  = 1.3,   -- gunline shooters only attack enemies within missile_range * this
    -- auto-delegation: hand the whole local army to a script_ai_planner so the
    -- doctrine engine works standalone (no AI General needed). Units the player
    -- takes back via vanilla group UI are never re-delegated.
    auto_delegate    = true,
    delegate_after_ms= 3000,    -- wait this long before creating the planner
    focus_cap        = 3,       -- max delegated units ordered onto the same target per tick
    -- planner directive: an orderless planner drops its units (observed: whole
    -- army leaked out of ai-control within ~3min), so always keep a standing
    -- order on it. rush/kite = attack the front-most enemy; hold doctrines =
    -- defend_position on the group centre (same as the vanilla defend button).
    directive_refresh_ms = 20000, -- re-issue/retarget this often
    defend_radius_m  = 120,       -- radius for defend_position
    -- reclaim fingerprint: OUR uc orders flip is_ai_controlled=false (script
    -- control) and planner orders call release_control() first — the flag is
    -- useless as an ownership signal. Ownership is the managed[] set; the only
    -- trustworthy player-takeover evidence is a fresh ordered_position the
    -- engine got while the unit was NOT under AI control.
    order_grace_ms   = 9000,      -- after OUR uc order, ordered_position drift
                                  --   is just the order executing — wait this long
    reclaim_move_m   = 30,        -- ordered_position moved this far past grace
                                  --   = a fresh player order -> reclaim
    -- hotkey handoff (AI General-style, engine ShortcutTriggered events):
    -- bind "Save Camera Bookmark" keys in game settings, select unit cards,
    -- press to move them between AI and player control.
    hotkey_toggle    = "camera_bookmark_save0", -- toggle selected AI<->player
    hotkey_override  = "camera_bookmark_save6", -- temp override; returns when idle
    override_grace_s = 20,        -- min battle-seconds before idle can end an override
    override_idle_s  = 10,        -- overridden unit returns after this much idle time
    -- command-event reclaim: UI order commands landing on a delegated unit
    -- outside our task pass can only be the player -> instant reclaim.
    cmd_reclaim      = true,
    cmd_probe        = true,      -- log first events per command name (schema verify)
    -- tactical micro (community-informed)
    cycle_charge     = true,      -- cav pulls out after engagement, re-charges
    charge_fight_ms  = 9000,      -- stay in melee this long before pulling out
    charge_regroup_ms= 6000,      -- regroup this long before re-charging
    charge_pull_m    = 50,        -- pull-out distance from the target
    kite_fallback    = true,      -- shooters retreat when a melee enemy closes in
    kite_threat_m    = 30,        -- enemy this close triggers fallback
    kite_dest_m      = 60,        -- fallback distance from the threat
    wounded_pullout  = true,      -- badly hurt high-value units hop out of melee
    wounded_hp       = 0.35,      -- unary_hitpoints below this = wounded
    wounded_pull_m   = 80,        -- disengage distance when caught in melee
    wounded_retry_ms = 12000,     -- cooldown between disengage hops
    dodge            = true,      -- scatter units out of enemy ability AoE
    dodge_radius_m   = 45,        -- scatter if within this of the ability target
    dodge_dest_m     = 60,        -- scatter destination distance from blast centre
    dodge_cooldown_ms= 8000,      -- per-unit dodge order throttle
    -- autotest driver: simulate player micro so handoff/reclaim paths get
    -- exercised without a human at the controls. DISABLE for normal play.
    test_sim         = __TEST_SIM__, -- master switch for the sim cycles below
    test_speed       = 4,         -- bm:modify_battle_speed multiplier at start
    test_batch       = 4,         -- units grabbed per sim cycle
    test_cycle_ms    = 25000,     -- pause between cycles
    test_verify_ms   = 15000,     -- how long to wait for a transition before
                                  --   declaring it missed
    -- v1.5 community-informed additions
    harass_range_m   = 160,       -- mounted shooters engage within this radius
    rundown_range_m  = 120,       -- mobile units finish routing enemies inside this
}

-- ABILITY_FLAGS[ability_key] = "mask,recharge_seconds"
-- mask bits: 1=target_ground 2=target_enemies 4=target_friends 8=self 16=spell(mana_cost>0)
local ABILITY_FLAGS = {
__DATA__
}

if not CONFIG.enabled then return end
if bm:is_replay() or bm:is_tutorial() then return end

local function out_log(msg)
    out(">>> czx_auto_ability >>> " .. tostring(msg))
end

local cast_log = {} -- [unit_ui_id] = { [ability_key] = last_attempt_ms }

-- auto-delegation state
local planner = nil           -- script_ai_planner holding the delegated army
local delegate_ms = 0         -- when the planner was created (diagnostics)
local delegate_err_logged = false
local managed = {}        -- [uid] = true: this commander owns tasking. NOT the
                          --   same as is_ai_controlled — our own uc orders flip
                          --   that flag to false (script control) and planner
                          --   orders release_control() first, so it flaps.
                          --   managed[] is the stable ownership record.
local our_order_ms = {}   -- [uid] = last battle-ms WE issued a uc order
local order_dest = {}     -- [uid] = baseline ordered_position for the player-
                          --   order fingerprint (nil = disarmed/unknown)
local atk_target_uid = {} -- [uid] = enemy uid our last attack order pointed at
local prev_ai = {}        -- [uid] = is_ai_controlled() last tick (edge detect)
local prev_ordered = {}   -- [uid] = last ordered_position seen while AI-flagged
                          -- (the planner's intent — baseline for the fingerprint)
local saw_enemies = false -- set once any enemy is seen; gates outcome detection
local outcome_logged = false
local roster_logged = false
local reclaimed = {}      -- [uid] = true once the player takes a unit back; never re-delegate
local focus_count = {}    -- [enemy_uid] = attack orders issued this tick
local directive_doc = nil     -- doctrine the standing planner order was issued under
local directive_ms = 0        -- when it was issued
local directive_target = nil  -- enemy unit the standing attack order points at
local directive_pos = nil     -- defend_position anchor (attack uses live target pos)

-- every uc order we issue flips the unit to script control and rewrites
-- ordered_position; record it so the reclaim fingerprint doesn't flag our
-- own orders as player takeovers. target_uid kept for attack-order checks.
local function note_our_order(uid, now_ms, target_uid)
    our_order_ms[uid] = now_ms
    order_dest[uid] = nil           -- disarm until the order settles
    atk_target_uid[uid] = target_uid
end
-- handoff / micro state
local overridden = {}         -- [uid] = {at=ms, idle_at=ms} temp player control, auto-returns
local charge_state = {}       -- [uid] = {phase="in"|"out", at=ms} cav cycle-charge
local role_of = {}            -- [uid] = role, snapshot map for order arming
local wounded_pull = {}       -- [uid] = battle-ms of last disengage hop
local dodge_at = {}           -- [uid] = last dodge-order ms
local cmd_seen = {}           -- [command name] = count, probe throttle
local in_task_pass = false    -- true while our own uc orders are being issued

-- 野战白名单：攻城/任务战不自动托管（CA 官方不建议攻城用 planner，同 v2 gate）
local DELEGATE_TYPES = {
    land_normal = true, land_ambush = true,
    underground = true, underway = true,
    chokepoint = true, crossing = true,
}

-- 攻防克制加成（v2 counter 矩阵，社区共识 2026-09 修订）：
-- attacker_role -> target_role -> score。
-- 要点：骑兵/飞行猎后排炮兵射手；远程集火克巨兽（大多无甲）；
-- 反大步兵靠 anti_large 旗标额外加成分（对骑兵和巨兽都生效，不止巨兽）；
-- 近战线列怕骑兵冲、远程怕一切贴身；骑射是永远风筝的骚扰兵。
local COUNTER_BONUS = {
    melee     = { shooter = 30, artillery = 40, monster = -20, cav = -15 },
    monster   = { melee = 20, shooter = 25, cav = 10, cav_shot = 15 },
    cav       = { shooter = 40, artillery = 50, monster = -30, melee = -10,
                  cav_shot = 35 },
    cav_shot  = { melee = 10, artillery = 30, monster = -15 }, -- harass, avoid monsters
    flyer     = { artillery = 40, shooter = 30, monster = -20, cav_shot = 25 },
    shooter   = { monster = 30, cav = 10, melee = 10 },  -- ranged focus melts big unarmoured things
    artillery = { melee = 10, monster = 10 },
    lord      = {},
}
local function counter_of(att_role, def_role)
    local row = COUNTER_BONUS[att_role]
    return (row and row[def_role]) or 0
end

local function for_each_player_unit(cb)
    local alliance = bm:alliances():item(bm:local_alliance())
    if not alliance then return end
    local army = alliance:armies():item(bm:local_army())
    if not army then return end
    local units = army:units()
    for i = 1, units:count() do
        cb(units:item(i))
    end
end

local function nearest_enemy(unit)
    local alliance = bm:get_non_player_alliance()
    if not alliance then return nil, math.huge end
    local best, best_d = nil, math.huge
    local up = unit:position()
    local armies = alliance:armies()
    for a = 1, armies:count() do
        local units = armies:item(a):units()
        for u = 1, units:count() do
            local e = units:item(u)
            if e and not e:is_routing() then
                local ok, d = pcall(function() return up:distance_xz(e:position()) end)
                if ok and d and d < best_d then
                    best, best_d = e, d
                end
            end
        end
    end
    return best, best_d
end

local function ability_allowed(unit, key)
    if CONFIG.banned_abilities[key] then return false end
    if next(CONFIG.unit_keys) ~= nil then
        local ut = unit:type()
        if not CONFIG.unit_keys[ut] then return false end
    end
    return true
end

local unsupported = {} -- [uid.."|"..key] = true once the engine reports the unit doesn't support the ability
local denied_keys = {} -- [ability_key] = true once a maneuver ability was skipped and logged
local cast_at = {}     -- [unit_ui_id] = battle ms of last successful cast on the unit
local summon_probe = {} -- [unit_type] = true once a summoned unit type was logged as cast-skipped

local function try_cast(su, unit, key, now_ms)
    local uid = tostring(unit:unique_ui_id())
    local combo = uid .. "|" .. key
    if unsupported[combo] then return end
    local ulog = cast_log[uid]
    if ulog and ulog[key] and (now_ms - ulog[key]) < CONFIG.retry_ms then
        return
    end
    -- formation abilities are unit-shape toggles, not fire-and-forget casts:
    -- re-toggling churns control and can wedge the engine's formation solver
    -- (observed: sim froze 1.7s after formation_lance was auto-cast on a
    -- single-model monster). Covers mod abilities missing the baked flag.
    if key:find("formation") then return end
    -- maneuver abilities (bomb drops / flyover attacks) require the unit to fly
    -- over a target point; unbaked mod keys fall through to the self-cast path,
    -- which makes the flyer maneuver toward its own position forever and deadlocks
    -- the sim thread (observed: two freezes ~1s after casting djs_fw_190_zhadan).
    if key:find("zhadan") or key:find("gyrobomber_bomb") or key:find("copter_bomb")
        or key:find("bomb_drop") or key:find("djs_f4u_t0") then
        if not denied_keys[key] then
            denied_keys[key] = true
            out_log("denied-maneuver " .. key)
        end
        return
    end
    local flag_str = ABILITY_FLAGS[key]
    local mask, recharge = 0, 0
    if flag_str then
        mask, recharge = flag_str:match("^(%d+),(%d+)")
        mask, recharge = tonumber(mask) or 0, tonumber(recharge) or 0
    end
    if mask >= 16 then
        if not CONFIG.cast_spells then return end
        mask = mask - 16
    end
    if not unit:can_perform_special_ability(key) then
        return
    end
    -- engagement gate: don't churn unit control for abilities that can't matter yet
    local e, dist = nearest_enemy(unit)
    if not e or dist > CONFIG.engage_range_m then
        return
    end
    local fired = false
    if mask % 2 >= 1 then -- target_ground
        su.uc:perform_special_ability_ground(key, e:position())
        fired = true
    elseif mask % 4 >= 2 then -- target_enemies
        su.uc:perform_special_ability(key, e)
        fired = true
    else -- self / aura / target_friends -> cast on self (engine requires the target arg; pass own unit)
        su.uc:perform_special_ability(key, unit)
        fired = true
    end
    if fired then
        -- issuing an order implicitly takes script control; release it back so the
        -- ai planner can keep commanding the unit
        su.uc:release_control()
        note_our_order(uid, now_ms)
        cast_log[uid] = cast_log[uid] or {}
        cast_log[uid][key] = now_ms
        cast_at[uid] = now_ms -- quiet window: suppress task orders while the cast resolves
        out_log("cast " .. key .. " on " .. uid)
    end
end

local idle_since = {} -- [unit_ui_id] = battle ms when the unit was first seen idle
local kicked_at = {}  -- [unit_ui_id] = battle ms of last nudge, to avoid spamming orders
local guard_set = {}  -- [unit_ui_id] = true once a behaviour flag was applied
local unit_task = {}  -- [unit_ui_id] = last assigned task id
local seen_types = {} -- [unit_type] = true once role-probe info was logged

local function unit_dist(a, b)
    local ok, d = pcall(function() return a:position():distance_xz(b:position()) end)
    return (ok and is_number(d)) and d or math.huge
end

local function nearest_of(unit, list)
    local best, bd = nil, math.huge
    for _, o in ipairs(list) do
        local d = unit_dist(unit, o)
        if d < bd then best, bd = o, d end
    end
    return best, bd
end

-- baked unit profiles: [unit_type] = "ai_role|category|class|is_large"
local CZX_UNIT_PROFILE = {
__PROFILE_DATA__
}

local function profile_of(unit)
    local s = CZX_UNIT_PROFILE[unit:type()]
    if not s then return nil end
    local ai, cat, cls, lg = s:match("^([^|]*)|([^|]*)|([^|]*)|(%d)")
    ai = ai or ""
    return {
        ai = ai, cat = cat or "", cls = cls or "", large = (lg == "1"),
        -- ai_usage_group taxonomy flags (community-informed):
        anti_large  = ai:find("anti_large") ~= nil,  -- halberds/spears: +BvL vs cav & monsters
        shock       = ai:find("shock") ~= nil,       -- charge bonus is their main damage -> cycle
        highvalue   = ai:find("highvalue") ~= nil,   -- expensive -> wounded pull-out priority
        no_skirmish = ai:find("no_skirmish") ~= nil, -- cannot skirmish; don't rely on it
        harasser    = ai:find("harasser") ~= nil,    -- shoot-and-scoot, never stand in melee
        mage        = ai:find("mage") ~= nil,
    }
end

local function ubool(unit, method)
    local ok, v = pcall(function() return unit[method](unit) end)
    return ok and v == true
end

-- engine's own unit-value estimate [需验证取值范围]
local function sv_of(unit)
    local ok, v = pcall(function() return unit:strategic_value() end)
    return (ok and is_number(v)) and v or 0
end

-- pick the best target from a list of enemy units by utility score;
-- score_fn returns -inf to exclude a candidate.
local function best_scored(unit, list, score_fn)
    local best, bs = nil, -math.huge
    for _, e in ipairs(list) do
        local s = score_fn(e)
        if s and s > bs then best, bs = e, s end
    end
    return best
end

-- role classification: baked profile first (exact, covers vanilla + our mods),
-- runtime boolean chain for unbaked (foreign mod) units. First match wins.
local function classify(unit, p)
    local prof = p.prof
    if prof then
        local cat = prof.cat
        if cat == "war_machine" or cat == "artillery" then return "artillery" end
        if prof.cls == "com" then return "lord" end
        -- mounted/ranged hybrids are skirmishers, not shock troops: they harass
        -- and kite, and melt if they stand in melee (community consensus)
        if p.flies then return (p.ammo ~= 0 or prof.harasser) and "cav_shot" or "flyer" end
        if prof.large or cat == "war_beast" then return "monster" end
        if cat == "cavalry" then
            return (p.ammo ~= 0 or prof.harasser or prof.ai:find("ranged_cav"))
                and "cav_shot" or "cav"
        end
        if cat == "inf_ranged" or p.ammo ~= 0 then return "shooter" end
        return "melee"
    end
    if ubool(unit, "is_artillery") or ubool(unit, "is_war_machine") then return "artillery" end
    if ubool(unit, "is_commanding_unit") then return "lord" end
    if p.flies then return p.ammo ~= 0 and "cav_shot" or "flyer" end
    if ubool(unit, "is_war_beasts") or ubool(unit, "is_elephants") then return "monster" end
    if ubool(unit, "is_cavalry") or ubool(unit, "is_chariot") or p.speed >= CONFIG.cav_min_speed then
        return p.ammo ~= 0 and "cav_shot" or "cav"
    end
    if p.ammo ~= 0 and p.range >= CONFIG.artillery_min_range then return "artillery" end
    if p.ammo ~= 0 then return "shooter" end
    return "melee"
end

local function probe_unit(unit)
    local p = {}
    local ok_a, ammo = pcall(function() return unit:ammo_left() end)
    p.ammo = (ok_a and is_number(ammo)) and ammo or 0
    local ok_r, range = pcall(function() return unit:missile_range() end)
    p.range = (ok_r and is_number(range)) and range or 0
    local ok_s, speed = pcall(function() return unit:fast_speed() end)
    p.speed = (ok_s and is_number(speed)) and speed or 0
    local ok_f, flies = pcall(function() return unit:can_fly() end)
    p.flies = ok_f and flies or false
    p.prof = profile_of(unit)
    local t = unit:type()
    if not seen_types[t] then
        seen_types[t] = true
        out_log("role-probe " .. t
            .. " prof=" .. (p.prof and (p.prof.cat .. "/" .. p.prof.ai .. (p.prof.large and "/L" or "")) or "none")
            .. " spd=" .. p.speed .. " ammo=" .. p.ammo .. " range=" .. p.range .. " fly=" .. tostring(p.flies))
    end
    return p
end

local function idle_long_enough(unit, now_ms)
    if not CONFIG.idle_kick then return false end -- master switch for movement orders
    local uid = tostring(unit:unique_ui_id())
    if not unit:is_idle() then
        idle_since[uid] = nil
        return false
    end
    if not idle_since[uid] then
        idle_since[uid] = now_ms
        return false
    end
    if (now_ms - idle_since[uid]) < CONFIG.idle_kick_after_s * 1000 then return false end
    if kicked_at[uid] and (now_ms - kicked_at[uid]) < CONFIG.order_retry_ms then return false end
    return true
end

-- stale-order detection: is_idle() lies for units carrying an old order —
-- a unit told to hold/defend stands forever with is_idle()=false and the task
-- layer never sees it. "Has an order but is neither moving nor fighting" is
-- the real idle signature. Shooters get a pass while a target is in range
-- (standing and firing = working).
local function effectively_idle(d, unit, ctx)
    if unit:is_idle() then return true end
    local ok_m, moving = pcall(function() return unit:is_moving() end)
    if ok_m and moving then return false end
    local ok_f, melee = pcall(function() return unit:is_in_melee() end)
    if ok_f and melee then return false end
    if d.role == "shooter" or d.role == "artillery" or d.role == "cav_shot" then
        local e, dist = nearest_enemy(unit)
        if e then
            local ok_r, rng = pcall(function() return unit:missile_range() end)
            if ok_r and is_number(rng) and rng > 0 and dist <= rng then
                return false -- standing in range = firing
            end
        end
    end
    return true
end

-- task gate: effectively idle for idle_kick_after_s, then throttled by
-- order_retry_ms (not the 20s ability retry)
local function task_ready(d, ctx)
    if not CONFIG.idle_kick then return false end
    local unit, now_ms = d.unit, ctx.now_ms
    local uid = tostring(unit:unique_ui_id())
    if not effectively_idle(d, unit, ctx) then
        idle_since[uid] = nil
        return false
    end
    if not idle_since[uid] then
        idle_since[uid] = now_ms
        return false
    end
    if (now_ms - idle_since[uid]) < CONFIG.idle_kick_after_s * 1000 then return false end
    if kicked_at[uid] and (now_ms - kicked_at[uid]) < CONFIG.order_retry_ms then return false end
    return true
end

local function order_attack(su, unit, e, now_ms, tag, force)
    local uid = tostring(unit:unique_ui_id())
    -- focus cap: don't pile the whole line onto one target this tick
    -- (force bypasses: a capped target still beats standing idle)
    local euid = tostring(e:unique_ui_id())
    if not force and (focus_count[euid] or 0) >= CONFIG.focus_cap then return end
    local ok, err = pcall(function()
        su.uc:attack_unit(e, true, true)
        su.uc:release_control()
    end)
    if ok then
        note_our_order(uid, now_ms, euid)
        focus_count[euid] = (focus_count[euid] or 0) + 1
        kicked_at[uid] = now_ms
        idle_since[uid] = nil
        -- arm cycle-charge: a cavalry attack order starts the fight timer
        if role_of[uid] == "cav" then
            charge_state[uid] = { phase = "in", at = now_ms, target = e }
        end
        out_log(tag .. " " .. unit:type() .. " (" .. uid .. ") -> " .. e:type())
    else
        out_log("ERROR " .. tag .. " " .. tostring(err))
        idle_since[uid] = now_ms -- restart the idle timer so we don't retry every poll
    end
end

local function order_return(su, unit, anchor, now_ms)
    local uid = tostring(unit:unique_ui_id())
    local ok, err = pcall(function()
        local ok_b, bearing = pcall(function() return unit:bearing() end)
        local deg = (ok_b and is_number(bearing)) and bearing * 180 / math.pi or 0
        local ok_w, width = pcall(function() return unit:ordered_width() end)
        su.uc:goto_location_angle_width(anchor:position(), deg, (ok_w and is_number(width)) and width or 20, true)
        su.uc:release_control()
    end)
    if ok then
        note_our_order(uid, now_ms)
        kicked_at[uid] = now_ms
        idle_since[uid] = nil
        out_log("screen-return " .. unit:type() .. " (" .. uid .. ")")
    else
        out_log("ERROR screen-return " .. tostring(err))
        idle_since[uid] = now_ms
    end
end

local function set_behaviour_once(su, unit, behaviour, flag_key)
    local uid = tostring(unit:unique_ui_id())
    local k = uid .. "|" .. (flag_key or behaviour)
    if guard_set[k] then return end
    guard_set[k] = true
    local ok, can = pcall(function() return unit:can_use_behaviour(behaviour) end)
    if not (ok and can) then return end
    local ok2, active = pcall(function() return unit:is_behaviour_active(behaviour) end)
    if ok2 and active then return end
    pcall(function()
        su.uc:change_behaviour_active(behaviour, true, false)
        su.uc:release_control()
    end)
end

-- generic screen behaviour: hold near an anchor list, intercept close threats,
-- fall back when dragged too far out. Threats are scored, not just nearest:
-- big threats and high-value enemies get intercepted first.
local function screen_hold(d, ctx, intercept_r, leash_r, tag)
    if not task_ready(d, ctx) then return end
    local anchor = ctx.shooters and nearest_of(d.unit, ctx.shooters)
    local t = best_scored(d.unit, ctx.enemies, function(e)
        local dist = unit_dist(d.unit, e)
        local near = dist <= intercept_r
            or (anchor and unit_dist(e, anchor) <= CONFIG.protect_radius_m)
        if not near then return -math.huge end
        local s = -dist * 0.5 + counter_of(d.role, ctx.erole[e])
        if ctx.erole[e] == "monster" then s = s + 50 end
        if d.anti_large and ctx.erole[e] == "monster" then s = s + 40 end
        return s + sv_of(e) * 0.2
    end)
    if t then
        order_attack(d.su, d.unit, t, ctx.now_ms, tag .. "-intercept")
        return
    end
    if anchor and unit_dist(d.unit, anchor) > leash_r then
        order_return(d.su, d.unit, anchor, ctx.now_ms)
    end
end

local function kick_if_idle(su, unit, now_ms)
    if not idle_long_enough(unit, now_ms) then return end
    local e, dist = nearest_enemy(unit)
    if e and dist <= CONFIG.idle_kick_range_m then
        order_attack(su, unit, e, now_ms, "idle-kick")
    end
end

---------------------------------------------------------------------------------------------
-- handoff layer: explicit player<->AI control via hotkey + engine command events
---------------------------------------------------------------------------------------------

-- read the currently selected unit cards (AI General's for_each_accessible_unit_card
-- approach: battle_orders -> cards_panel -> review_DY, card Id() == unique_ui_id)
local function selected_uids()
    local ids = {}
    local ok_p, parent = pcall(function()
        return find_uicomponent(core:get_ui_root(), "battle_orders", "cards_panel", "review_DY")
    end)
    if not (ok_p and parent) then return ids end
    for i = 0, parent:ChildCount() - 1 do
        local ok_c, card = pcall(function() return UIComponent(parent:Find(i)) end)
        if ok_c and card and tostring(card:CallbackId()) == "UnitCard" then
            local ok_s, st = pcall(function() return card:CurrentState() end)
            if ok_s and st and tostring(st):lower():find("selected") then
                ids[tostring(card:Id())] = true
            end
        end
    end
    return ids
end

-- hotkey toggle: selected AI units -> player (never re-delegated);
-- selected player units -> back to the planner
local function handoff_toggle()
    local sel = selected_uids()
    if next(sel) == nil then out_log("handoff: nothing selected") return end
    local gave, took = 0, 0
    for_each_player_unit(function(unit)
        local uid = tostring(unit:unique_ui_id())
        if sel[uid] then
            local su = bm:get_scriptunit_for_unit(unit)
            if su and su.uc then
                if managed[uid] and not reclaimed[uid] then
                    reclaimed[uid] = true
                    overridden[uid] = nil
                    order_dest[uid] = nil
                    if planner then pcall(function() planner:remove_sunits(su) end) end
                    took = took + 1
                    out_log("handoff take " .. unit:type() .. " (" .. uid .. ")")
                else
                    reclaimed[uid] = nil
                    overridden[uid] = nil
                    order_dest[uid] = nil
                    managed[uid] = true
                    if planner then pcall(function() planner:add_sunits(su) end) end
                    gave = gave + 1
                    out_log("handoff give " .. unit:type() .. " (" .. uid .. ")")
                end
            end
        end
    end)
    out_log("handoff give=" .. gave .. " take=" .. took)
end

-- hotkey override: selected AI units go to the player temporarily; the tick
-- loop hands them back once they sit idle (micro the unit, then forget it)
local function handoff_override(now_ms)
    local sel = selected_uids()
    local n = 0
    for_each_player_unit(function(unit)
        local uid = tostring(unit:unique_ui_id())
        if sel[uid] and managed[uid] and not reclaimed[uid] and not overridden[uid] then
            local su = bm:get_scriptunit_for_unit(unit)
            if su then
                overridden[uid] = { at = now_ms, idle_at = nil }
                order_dest[uid] = nil
                if planner then pcall(function() planner:remove_sunits(su) end) end
                n = n + 1
                out_log("override " .. unit:type() .. " (" .. uid .. ")")
            end
        end
    end)
    if n > 0 then out_log("override n=" .. n) end
end

local function add_handoff_listener(name, shortcut, fn)
    if not shortcut then return end
    local ok, err = pcall(function()
        core:add_listener(name, "ShortcutTriggered",
            function(ctx) return ctx.string == shortcut end,
            function() bm:callback(fn, 0, name .. "_cb") end,
            true)
    end)
    if not ok then out_log("ERROR hotkey " .. name .. " " .. tostring(err)) end
end

-- engine command events: UI orders (Move/Attack/etc.) arriving OUTSIDE our task
-- pass on a delegated unit are the player clicking -> instant reclaim. Our own
-- uc orders fire inside the tick where in_task_pass filters them out.
local function cmd_probe_log(ctx, name)
    if not CONFIG.cmd_probe then return end
    local n = (cmd_seen[name] or 0) + 1
    cmd_seen[name] = n
    if n > 8 then return end
    local ok_u, u = pcall(function() return ctx:get_unit() end)
    local ok_s, s1 = pcall(function() return ctx:get_string1() end)
    local ok_p, pos = pcall(function() return ctx:get_position() end)
    local ok_b, b1 = pcall(function() return ctx:get_bool1() end)
    out_log("cmd " .. name .. " #" .. n
        .. " unit=" .. (ok_u and u and u:type() or "nil")
        .. " uid=" .. (ok_u and u and tostring(u:unique_ui_id()) or "-")
        .. " ai=" .. tostring(ok_u and u and u:is_ai_controlled())
        .. " s1=" .. tostring(ok_s and s1)
        .. " pos=" .. tostring(ok_p and pos)
        .. " b1=" .. tostring(ok_b and b1)
        .. " inpass=" .. tostring(in_task_pass))
end

local function add_order_listener(name)
    local ok, err = pcall(function()
        bm:register_command_handler_callback(name, function(ctx)
            cmd_probe_log(ctx, name)
            if not CONFIG.cmd_reclaim or in_task_pass then return end
            local ok_u, u = pcall(function() return ctx:get_unit() end)
            if not (ok_u and u) then return end
            local uid = tostring(u:unique_ui_id())
            -- player-issued order on a unit we think we own = they took it
            if managed[uid] and not reclaimed[uid] and not overridden[uid] then
                reclaimed[uid] = true
                order_dest[uid] = nil
                -- must leave the planner's sunit list or the next directive
                -- refresh stomps the player's order
                if planner then
                    local ok_s, su_r = pcall(function()
                        return bm:get_scriptunit_for_unit(u)
                    end)
                    if ok_s and su_r then
                        pcall(function() planner:remove_sunits(su_r) end)
                    end
                end
                out_log("reclaimed-cmd " .. name .. " " .. u:type() .. " (" .. uid .. ")")
            end
        end, "czx_cmd_" .. name)
    end)
    if not ok then out_log("ERROR cmd " .. name .. " " .. tostring(err)) end
end

---------------------------------------------------------------------------------------------
-- tactical micro
---------------------------------------------------------------------------------------------

-- move d's unit away from a world position (fallback / dodge / pull-out)
local function order_flee_pos(su, unit, from_pos, dist_m, now_ms, tag)
    local uid = tostring(unit:unique_ui_id())
    local ok, err = pcall(function()
        local up = unit:position()
        local dx, dz = up:get_x() - from_pos:get_x(), up:get_z() - from_pos:get_z()
        local len = math.sqrt(dx * dx + dz * dz)
        if len < 1 then dx, dz, len = 0, 1, 1 end -- degenerate: flee "north"
        local dest = v(up:get_x() + dx / len * dist_m, up:get_z() + dz / len * dist_m)
        local ok_b, bearing = pcall(function() return unit:bearing() end)
        local deg = (ok_b and is_number(bearing)) and bearing * 180 / math.pi or 0
        local ok_w, width = pcall(function() return unit:ordered_width() end)
        su.uc:goto_location_angle_width(dest, deg, (ok_w and is_number(width)) and width or 20, true)
        su.uc:release_control()
    end)
    if ok then
        note_our_order(uid, now_ms)
        kicked_at[uid] = now_ms
        idle_since[uid] = nil
        out_log(tag .. " " .. unit:type() .. " (" .. uid .. ")")
    else
        out_log("ERROR " .. tag .. " " .. tostring(err))
    end
    return ok
end

-- cav cycle-charge: fight briefly, pull out, re-charge. Returns true when it
-- issued an order this tick (caller skips other behaviour for this unit).
local function cycle_charge_step(d, ctx)
    if not CONFIG.cycle_charge then return false end
    local uid = tostring(d.unit:unique_ui_id())
    local st = charge_state[uid]
    if not st then return false end -- set on first attack order below
    local now_ms = ctx.now_ms
    if st.phase == "in" then
        -- target died or routed: cycle done; a fresh attack order re-arms it
        local ok_t, alive = pcall(function()
            return st.target ~= nil and not st.target:is_routing()
        end)
        if not (ok_t and alive) then charge_state[uid] = nil; return false end
        local ok_m, melee = pcall(function() return d.unit:is_in_melee() end)
        if ok_m and melee and (now_ms - st.at) > CONFIG.charge_fight_ms then
            local ok_p, tp = pcall(function() return st.target:position() end)
            if ok_p and tp then
                order_flee_pos(d.su, d.unit, tp, CONFIG.charge_pull_m, now_ms, "charge-out")
                st.phase, st.at = "out", now_ms
                return true
            end
        end
    elseif st.phase == "out" then
        if (now_ms - st.at) > CONFIG.charge_regroup_ms then
            local ok_v, moving = pcall(function() return d.unit:is_moving() end)
            if not (ok_v and moving) or (now_ms - st.at) > CONFIG.charge_regroup_ms * 3 then
                charge_state[uid] = nil -- fall through; a fresh attack order re-arms it
            end
        else
            return true -- still pulling out; hold other orders
        end
    end
    return false
end

-- wounded disengage: high-value units below the hp threshold hop out of melee
-- when caught in it, then go straight back to the task layer once clear — hp
-- doesn't regen mid-battle, so parking them out back is just losing the unit.
-- Planner membership untouched; the standing directive can keep using them.
local function wounded_step(d, ctx)
    if not CONFIG.wounded_pullout then return false end
    local uid = tostring(d.unit:unique_ui_id())
    if d.role ~= "lord" and d.role ~= "monster" and d.role ~= "cav"
        and not d.highvalue then return false end -- highvalue flag pulls elites of any role
    local ok_h, hp = pcall(function() return d.unit:unary_hitpoints() end)
    if not (ok_h and is_number(hp)) then return false end
    local ok_m, melee = pcall(function() return d.unit:is_in_melee() end)
    if hp >= CONFIG.wounded_hp or not (ok_m and melee) then
        wounded_pull[uid] = nil -- healthy, or clear of melee: normal tasking
        return false
    end
    -- wounded AND still in melee: hop away from the nearest enemy, throttled
    local last = wounded_pull[uid] or 0
    if (ctx.now_ms - last) < CONFIG.wounded_retry_ms then return true end
    local threat = nearest_of(d.unit, ctx.enemies)
    if not threat then return false end
    local ok_p, tp = pcall(function() return threat:position() end)
    if not (ok_p and tp) then return false end
    if order_flee_pos(d.su, d.unit, tp, CONFIG.wounded_pull_m, ctx.now_ms, "wounded-pull") then
        wounded_pull[uid] = ctx.now_ms
    end
    return true
end

-- shooter kiting: a melee-role enemy closing in triggers a fallback move; the
-- unit resumes firing once clear (skirmish flag alone retreats too early)
local function kite_step(d, ctx)
    if not CONFIG.kite_fallback then return false end
    if d.role ~= "shooter" and d.role ~= "cav_shot" then return false end
    local threat, td = nil, math.huge
    for _, e in ipairs(ctx.enemies) do
        local r = ctx.erole[e]
        if r == "melee" or r == "monster" or r == "cav" then
            local ok_d, dist = pcall(function()
                return e:position():distance_xz(d.unit:position())
            end)
            if ok_d and dist and dist < td then threat, td = e, dist end
        end
    end
    if not (threat and td <= CONFIG.kite_threat_m) then return false end
    local ok_v, moving = pcall(function() return d.unit:is_moving() end)
    if ok_v and moving then return true end -- already falling back; hold
    local ok_p, tp = pcall(function() return threat:position() end)
    if ok_p and tp then
        order_flee_pos(d.su, d.unit, tp, CONFIG.kite_dest_m, ctx.now_ms, "kite-back")
    end
    return true
end

---------------------------------------------------------------------------------------------
-- pass 2.5: task assignment (v2 ActionSelector v1).
-- doctrine + role + context -> task id; tasks are the vocabulary the squad
-- layer will later assign explicitly. Executors keyed by task below.
local function assign_task(d, ctx)
    local role, doc = d.role, ctx.doctrine
    if role == "artillery" then return "hold_position" end
    if role == "cav_shot" then return "harass" end -- mounted shooters skirmish in every doctrine
    if doc == "gunline" then
        if role == "melee" or role == "monster" then return "protect_gunline" end
        if role == "cav" then return "intercept_breakthrough" end
        if role == "flyer" then return "hunt_backline" end
        if role == "shooter" then return "hold_fire_line" end
        if role == "lord" then return "free_engagement" end
    elseif doc == "balanced" then
        if role == "melee" or role == "monster" then return "protect_gunline" end
        if role == "cav" or role == "flyer" then return "hunt_backline" end
        if role == "lord" then return "free_engagement" end
        if role == "shooter" then return "free_fire" end
    elseif doc == "kite" then
        if role == "cav" or role == "flyer" then return "hunt_backline" end
        if role == "shooter" then return "hold_fire_line" end
        return "attack"
    end
    -- rush / none / unknown: everything pushes
    return "attack"
end

-- task executors; ctx = {now_ms, doctrine, shooters, enemies, ...}
local TASK_EXEC = {}

TASK_EXEC.protect_gunline = function(d, ctx)
    set_behaviour_once(d.su, d.unit, "defend")
    if ctx.doctrine == "gunline" then
        screen_hold(d, ctx, CONFIG.intercept_radius_m, CONFIG.leash_radius_m, "screen")
    else
        screen_hold(d, ctx, CONFIG.bal_intercept_radius_m, CONFIG.bal_leash_radius_m, "screen")
    end
end

TASK_EXEC.intercept_breakthrough = function(d, ctx)
    -- gunline cav reserve: intercept whatever presses the line, strongly
    -- preferring monsters threatening the anchor
    if not task_ready(d, ctx) then return end
    local anchor = nearest_of(d.unit, ctx.shooters)
    local t = best_scored(d.unit, ctx.enemies, function(e)
        local dist = unit_dist(d.unit, e)
        local near = dist <= CONFIG.cav_intercept_radius_m
            or (anchor and unit_dist(e, anchor) <= CONFIG.protect_radius_m * 2)
        if not near then return -math.huge end
        local s = -dist * 0.3 + sv_of(e) * 0.3 + counter_of("cav", ctx.erole[e])
        if ctx.erole[e] == "monster" then s = s + 80 end
        return s
    end)
    if t then
        order_attack(d.su, d.unit, t, ctx.now_ms,
            ctx.erole[t] == "monster" and "cav-antilarge" or "cav-intercept")
        return
    end
    if anchor and unit_dist(d.unit, anchor) > CONFIG.bal_leash_radius_m then
        order_return(d.su, d.unit, anchor, ctx.now_ms)
    end
end

TASK_EXEC.hunt_backline = function(d, ctx)
    if not task_ready(d, ctx) then return end
    -- flyers prefer enemy flyers/artillery over ground backline
    if d.role == "flyer" then
        local t = best_scored(d.unit, ctx.enemies_airarty, function(e)
            local dist = unit_dist(d.unit, e)
            if dist > CONFIG.flyer_hunt_range_m then return -math.huge end
            return sv_of(e) - dist * 0.2
        end)
        if t then
            order_attack(d.su, d.unit, t, ctx.now_ms, "flyer-hunt")
            return
        end
    end
    local t = best_scored(d.unit, ctx.enemies_ranged, function(e)
        local dist = unit_dist(d.unit, e)
        if dist > CONFIG.flank_hunt_range_m then return -math.huge end
        return sv_of(e) - dist * 0.2 + counter_of(d.role, ctx.erole[e])
    end)
    if t then
        order_attack(d.su, d.unit, t, ctx.now_ms, "cav-hunt")
        return
    end
    -- nothing to hunt: gunline falls back to reserve interception, else loose screen
    if ctx.doctrine == "gunline" then
        TASK_EXEC.intercept_breakthrough(d, ctx)
    else
        screen_hold(d, ctx, CONFIG.bal_intercept_radius_m, CONFIG.bal_leash_radius_m, d.role)
    end
end

TASK_EXEC.free_engagement = function(d, ctx)
    -- lords act freely: intercept close threats but never get leashed back;
    -- among nearby enemies they prefer high-value targets
    set_behaviour_once(d.su, d.unit, "defend")
    if not task_ready(d, ctx) then return end
    local t = best_scored(d.unit, ctx.enemies, function(e)
        local dist = unit_dist(d.unit, e)
        if dist > CONFIG.bal_intercept_radius_m then return -math.huge end
        return sv_of(e) - dist
    end)
    if t then order_attack(d.su, d.unit, t, ctx.now_ms, "lord-intercept") end
end

TASK_EXEC.hold_fire_line = function(d, ctx)
    set_behaviour_once(d.su, d.unit, "skirmish")
    if not task_ready(d, ctx) then return end
    local e, dist = nearest_enemy(d.unit)
    local ok_r, rng = pcall(function() return d.unit:missile_range() end)
    local hold = (ok_r and is_number(rng) and rng > 0) and rng * CONFIG.shooter_hold_mult or CONFIG.intercept_radius_m
    if e and dist <= hold then
        order_attack(d.su, d.unit, e, ctx.now_ms, "shooter-engage")
    end
    -- beyond hold range: stay put, don't walk past the screen
end

TASK_EXEC.free_fire = function(d, ctx)
    kick_if_idle(d.su, d.unit, ctx.now_ms)
end

TASK_EXEC.attack = function(d, ctx)
    if not task_ready(d, ctx) then return end
    -- finish off routing units first when we're mobile: free kills and they
    -- can't rally (community: run routers down with cavalry)
    if (d.role == "cav" or d.role == "flyer" or d.role == "cav_shot")
        and ctx.enemies_routing then
        local r, rd = nil, CONFIG.rundown_range_m
        for _, e in ipairs(ctx.enemies_routing) do
            local dist = unit_dist(d.unit, e)
            if dist < rd then r, rd = e, dist end
        end
        if r then
            order_attack(d.su, d.unit, r, ctx.now_ms, "run-down")
            return
        end
    end
    -- counter-aware pick: distance dominates but role counters and value sway it
    local t = best_scored(d.unit, ctx.enemies, function(e)
        local dist = unit_dist(d.unit, e)
        if dist > CONFIG.idle_kick_range_m then return -math.huge end
        local s = sv_of(e) * 0.5 - dist * 0.5 + counter_of(d.role, ctx.erole[e])
        if d.anti_large and (ctx.erole[e] == "monster" or ctx.erole[e] == "cav") then
            s = s + 40 -- halberds/spears counter BOTH monsters and cavalry
        end
        if ctx.erole[e] == "lord" then s = s + 25 end -- decapitating value
        return s
    end)
    if t then
        order_attack(d.su, d.unit, t, ctx.now_ms, "engage")
        return
    end
    -- every candidate capped or out of range: piling on beats standing idle
    local e2 = nearest_enemy(d.unit)
    if e2 then order_attack(d.su, d.unit, e2, ctx.now_ms, "engage-forced", true) end
end

-- mobile shooters (missile cav, ranged flyers, harassers): skirmish forever,
-- pick soft backline targets, never ordered into melee
TASK_EXEC.harass = function(d, ctx)
    set_behaviour_once(d.su, d.unit, "skirmish")
    if not task_ready(d, ctx) then return end
    local t = best_scored(d.unit, ctx.enemies, function(e)
        local dist = unit_dist(d.unit, e)
        if dist > CONFIG.harass_range_m then return -math.huge end
        local s = sv_of(e) * 0.4 - dist * 0.4 + counter_of("cav_shot", ctx.erole[e])
        if ctx.erole[e] == "artillery" then s = s + 30 end
        return s
    end)
    if t then order_attack(d.su, d.unit, t, ctx.now_ms, "harass") end
end

TASK_EXEC.hold_position = function() end -- artillery: never ordered; fires on its own

local function select_doctrine(delegated, shooters, n_mobile)
    if CONFIG.doctrine ~= "auto" then return CONFIG.doctrine end
    local n = #delegated
    if n == 0 then return "none" end
    if n_mobile / n >= CONFIG.kite_min_mobile_share then return "kite" end
    local share = #shooters / n
    if share >= CONFIG.gunline_min_share and #shooters >= 2 then return "gunline" end
    if share <= CONFIG.rush_max_shooter_share then return "rush" end
    return "balanced"
end

local last_doctrine = nil
local tick_n = 0

-- pass 0: auto-delegate the whole local army to a script_ai_planner so the
-- doctrine engine runs standalone (no AI General button needed). Only in
-- battle-start roster dump: both armies grouped by unit_type/role, one line
-- each — the post-battle review record for doctrine tuning
local function roster_dump()
    if roster_logged then return end
    roster_logged = true
    local tally = {}
    for_each_player_unit(function(u)
        local p = probe_unit(u)
        local k = u:type() .. "/" .. classify(u, p)
        tally[k] = (tally[k] or 0) + 1
    end)
    for k, n in pairs(tally) do out_log("roster ally " .. k .. " x" .. n) end
    tally = {}
    local alliance = bm:get_non_player_alliance()
    if alliance then
        local armies = alliance:armies()
        for a = 1, armies:count() do
            local units = armies:item(a):units()
            for u = 1, units:count() do
                local e = units:item(u)
                if e then
                    local p = probe_unit(e)
                    local k = e:type() .. "/" .. classify(e, p)
                    tally[k] = (tally[k] or 0) + 1
                end
            end
        end
    end
    for k, n in pairs(tally) do out_log("roster enemy " .. k .. " x" .. n) end
end

-- field battle types; sieges stay manual (CA warns planners do badly there).
local function ensure_delegation(now_ms)
    if not CONFIG.auto_delegate or planner then return end
    if now_ms < CONFIG.delegate_after_ms then return end
    local ok_t, btype = pcall(function() return bm:battle_type() end)
    if ok_t and btype and not DELEGATE_TYPES[btype] then return end
    local ok, sus = pcall(function() return bm:get_scriptunits_for_local_players_army() end)
    if not (ok and sus and sus:count() > 0) then return end
    local ok2, p = pcall(function() return script_ai_planner:new("czx_auto", sus) end)
    if ok2 and p then
        planner = p
        delegate_ms = now_ms
        -- the managed set owns tasking regardless of is_ai_controlled flaps
        for i = 1, sus:count() do
            local su0 = sus:item(i)
            local ok_u, u = pcall(function() return su0.unit end)
            if ok_u and u then
                local ok_i, id = pcall(function() return u:unique_ui_id() end)
                if ok_i and id then managed[tostring(id)] = true end
            end
        end
        out_log("auto-delegate units=" .. sus:count() .. " type=" .. tostring(btype))
        roster_dump()
        -- an orderless planner leaks its units back to the player within a
        -- tick; plant a hold order NOW so the warmup flag flap never starts
        pcall(function()
            planner:defend_position(planner:get_centre_point(), CONFIG.defend_radius_m)
        end)
    elseif not delegate_err_logged then
        delegate_err_logged = true
        out_log("ERROR auto-delegate " .. tostring(p))
    end
end

-- pass 0.5: keep a standing order on the planner. With no order the engine
-- silently hands its units back to the player (the "idle" army we observed);
-- with attack_unit/defend_position the engine commander keeps driving them,
-- and our per-unit uc orders layer on top for target choice.
local function issue_planner_directive(now_ms, doctrine, delegated, enemies)
    if not planner or doctrine == "none" then return end
    if doctrine == "rush" or doctrine == "kite" then
        -- refresh when the doctrine just changed, the target died/routed, or
        -- the refresh window elapsed (keeps the push aimed at the front line)
        local stale = true
        if directive_target then
            local ok_s, r = pcall(function() return directive_target:is_routing() end)
            stale = (not ok_s) or r == true
        end
        if doctrine == directive_doc and not stale
            and (now_ms - directive_ms) < CONFIG.directive_refresh_ms then
            return
        end
        -- closest enemy to any of our units = what the front line is facing
        local best, best_d = nil, math.huge
        for _, e in ipairs(enemies) do
            for _, d in ipairs(delegated) do
                local ok_d, dist = pcall(function()
                    return e:position():distance_xz(d.unit:position())
                end)
                if ok_d and dist and dist < best_d then best, best_d = e, dist end
            end
        end
        if not best then return end
        local ok_o, err = pcall(function() planner:attack_unit(best) end)
        if ok_o then
            directive_doc, directive_ms, directive_target = doctrine, now_ms, best
            directive_pos = nil -- attack directives track the live target unit
            out_log("directive attack -> " .. tostring(best:type())
                .. " d=" .. math.floor(best_d))
        else
            out_log("directive-fail attack " .. tostring(err))
        end
    else
        -- hold doctrines: defend the ground the group stands on; the planner's
        -- own should_reorder re-issues every 30s, we only re-issue on change
        if doctrine == directive_doc
            and (now_ms - directive_ms) < CONFIG.directive_refresh_ms then
            return
        end
        local ok_o, err = pcall(function()
            planner:defend_position(planner:get_centre_point(), CONFIG.defend_radius_m)
        end)
        if ok_o then
            directive_doc, directive_ms, directive_target = doctrine, now_ms, nil
            local ok_cp, cp = pcall(function() return planner:get_centre_point() end)
            directive_pos = (ok_cp and cp) or nil
            out_log("directive defend r=" .. CONFIG.defend_radius_m)
        else
            out_log("directive-fail defend " .. tostring(err))
        end
    end
end

---------------------------------------------------------------------------------------------
-- autotest sim: exercise the player-handoff paths without a human. Each cycle
-- picks a batch of managed units, issues a FOREIGN move order (no
-- note_our_order, outside in_task_pass — the same signature a real player
-- click produces), verifies the fingerprint reclaim fires, then hands them
-- back through the planner (group-AI signature) and verifies adoption.
---------------------------------------------------------------------------------------------
local sim = { phase = "off", uids = {}, at = 0, cycle = 0, did_speed = false }

local function sim_step(now_ms)
    if not CONFIG.test_sim or not planner then return end
    if not sim.did_speed then
        sim.did_speed = true
        local ok, err = pcall(function() bm:modify_battle_speed(CONFIG.test_speed) end)
        out_log("sim speed x" .. tostring(CONFIG.test_speed) .. " ok=" .. tostring(ok)
            .. (ok and "" or (" err=" .. tostring(err))))
    end

    if sim.phase == "off" then
        local managed_n = 0
        for_each_player_unit(function(unit)
            local uid = tostring(unit:unique_ui_id())
            if managed[uid] and not reclaimed[uid] and not overridden[uid] then
                managed_n = managed_n + 1
            end
        end)
        if managed_n >= CONFIG.test_batch * 2 then
            sim.phase, sim.at = "cooldown", now_ms
            out_log("sim begin managed=" .. managed_n)
        end
        return
    end

    if sim.phase == "cooldown" then
        if now_ms - sim.at < CONFIG.test_cycle_ms then return end
        local picks = {}
        for_each_player_unit(function(unit)
            if #picks >= CONFIG.test_batch then return end
            local uid = tostring(unit:unique_ui_id())
            if managed[uid] and not reclaimed[uid] and not overridden[uid]
                and not unit:is_routing() then
                picks[#picks + 1] = { uid = uid, unit = unit }
            end
        end)
        if #picks == 0 then return end
        sim.uids = {}
        for _, p in ipairs(picks) do
            local su = bm:get_scriptunit_for_unit(p.unit)
            if su and su.uc then
                local ok, err = pcall(function()
                    local up = p.unit:position()
                    -- no release_control: a real player grab leaves the unit
                    -- off AI control — that flag state is half the signature
                    su.uc:goto_location_angle_width(
                        v(up:get_x() + 40, up:get_z() + 40), 0, 20, true)
                end)
                if ok then
                    sim.uids[p.uid] = true
                    out_log("sim-order " .. p.uid)
                else
                    out_log("ERROR sim-order " .. tostring(err))
                end
            end
        end
        sim.cycle, sim.phase, sim.at = sim.cycle + 1, "await-reclaim", now_ms
        out_log("sim-cycle " .. sim.cycle .. " ordered=" .. #picks)
        return
    end

    if sim.phase == "await-reclaim" then
        local done, missing = 0, 0
        for uid in pairs(sim.uids) do
            if reclaimed[uid] then done = done + 1 else missing = missing + 1 end
        end
        if missing == 0 or now_ms - sim.at > CONFIG.test_verify_ms then
            out_log("sim-cycle " .. sim.cycle .. " reclaim=" .. done .. "/" .. (done + missing)
                .. (missing > 0 and " MISS" or ""))
            sim.phase, sim.at = "handback", now_ms
        end
        return
    end

    if sim.phase == "handback" then
        -- group-AI signature: planner add -> engine flips is_ai_controlled,
        -- the unmanaged+ai path adopts them back into managed[]
        for_each_player_unit(function(unit)
            local uid = tostring(unit:unique_ui_id())
            if sim.uids[uid] and reclaimed[uid] and not unit:is_routing() then
                local su = bm:get_scriptunit_for_unit(unit)
                if su then pcall(function() planner:add_sunits(su) end) end
            end
        end)
        sim.phase, sim.at = "await-back", now_ms
        return
    end

    if sim.phase == "await-back" then
        local done, missing = 0, 0
        for uid in pairs(sim.uids) do
            if managed[uid] and not reclaimed[uid] then done = done + 1 else missing = missing + 1 end
        end
        if missing == 0 or now_ms - sim.at > CONFIG.test_verify_ms then
            out_log("sim-cycle " .. sim.cycle .. " back=" .. done .. "/" .. (done + missing)
                .. (missing > 0 and " MISS" or ""))
            sim.phase, sim.at = "cooldown", now_ms
        end
        return
    end
end

local function tick()
    local now_ms = bm:time_elapsed_ms()
    focus_count = {} -- per-tick per-target order budget
    ensure_delegation(now_ms)

    -- pass 1: snapshot managed units + enemies, classify roles
    -- Ownership = the managed[] set, NOT is_ai_controlled: our uc orders flip
    -- that flag false (script control) and planner orders release_control()
    -- first, so it flaps under normal operation. The flag is only consulted
    -- for handback detection (unmanaged unit turning ai=true = the player
    -- enabled the vanilla group AI toggle) and to arm the order fingerprint.
    local delegated, shooters, n_mobile = {}, {}, 0
    for_each_player_unit(function(unit)
        local uid0 = tostring(unit:unique_ui_id())
        local ai_now = unit:is_ai_controlled()

        -- handback / adoption: a unit we don't own turning ai-controlled can
        -- only mean the player enabled its group AI (reinforcements arriving
        -- pre-toggled land here too) -> take it into management
        if ai_now and (reclaimed[uid0] or not managed[uid0]) then
            local tag = reclaimed[uid0] and "handed-back " or "adopted "
            reclaimed[uid0] = nil
            managed[uid0] = true
            order_dest[uid0] = nil
            prev_ordered[uid0] = nil
            atk_target_uid[uid0] = nil
            our_order_ms[uid0] = 0
            out_log(tag .. unit:type() .. " (" .. uid0 .. ")")
        end
        -- brand-new units arriving while uncontrolled (summons, reinforcements)
        if planner and not managed[uid0] and not reclaimed[uid0]
            and not overridden[uid0] and not ai_now and not unit:is_routing() then
            local su0 = bm:get_scriptunit_for_unit(unit)
            if su0 then
                pcall(function() planner:add_sunits(su0) end)
                managed[uid0] = true
                out_log("adopted-new " .. unit:type() .. " (" .. uid0 .. ")")
            end
        end

        local is_man = managed[uid0] and not reclaimed[uid0] and not overridden[uid0]

        -- reclaim fingerprint: while a managed unit sits uncontrolled
        -- (ai=false covers both our script-control and real player grabs),
        -- ordered_position is the receipt of the LAST order issued. If it
        -- moves well past our order's grace window, someone else gave a fresh
        -- order — in a single-player battle that can only be the player.
        if is_man and not ai_now then
            if prev_ai[uid0] then
                -- ai=true -> false this tick. The foreign order has ALREADY
                -- landed so ordered_position is the foreign dest — snapshotting
                -- it as baseline would erase the evidence. Use the last
                -- planner-seen destination instead, UNLESS our own recorded
                -- order is fresh (then order_dest already holds our intent).
                if order_dest[uid0] == nil
                    or (now_ms - (our_order_ms[uid0] or 0)) > CONFIG.order_grace_ms then
                    order_dest[uid0] = prev_ordered[uid0]
                end
            elseif order_dest[uid0] == nil
                and (now_ms - (our_order_ms[uid0] or 0)) > CONFIG.order_grace_ms then
                local ok_b, base = pcall(function() return unit:ordered_position() end)
                order_dest[uid0] = (ok_b and base) or nil
            end
            local base = order_dest[uid0]
            if base then
                local ok_n, np = pcall(function() return unit:ordered_position() end)
                if ok_n and np then
                    local ok_d, dd = pcall(function() return np:distance_xz(base) end)
                    local moved = ok_d and dd and dd > CONFIG.reclaim_move_m
                    if moved and atk_target_uid[uid0] then
                        -- attack-ordered units: ordered_position may track the
                        -- moving target; only reclaim if the target changed
                        local ok_c, ct = pcall(function() return unit:current_target() end)
                        local ok_i, cid = pcall(function()
                            return ct and ct:unique_ui_id()
                        end)
                        moved = not (ok_c and ok_i and cid
                            and tostring(cid) == atk_target_uid[uid0])
                    end
                    if moved then
                        -- directive flap: attack_unit/defend_position releases
                        -- control then re-orders every unit — a fresh
                        -- ordered_position near the directive target is the
                        -- PLANNER's order, not a player grab (observed: mass
                        -- reclaimed-ordered within seconds of each refresh)
                        local ok_dp, dp = nil, nil
                        if directive_target then
                            ok_dp, dp = pcall(function()
                                return directive_target:position()
                            end)
                        else
                            dp = directive_pos
                        end
                        if dp then
                            local ok_d2, d2 = pcall(function() return np:distance_xz(dp) end)
                            if ok_d2 and d2 and d2 <= 120 then
                                moved = false
                                order_dest[uid0] = np -- adopt the directive dest as baseline
                            end
                        end
                    end
                    if moved then
                        reclaimed[uid0] = true
                        order_dest[uid0] = nil
                        if planner then
                            local ok_s, su_r = pcall(function()
                                return bm:get_scriptunit_for_unit(unit)
                            end)
                            if ok_s and su_r then
                                pcall(function() planner:remove_sunits(su_r) end)
                            end
                        end
                        out_log("reclaimed-ordered " .. unit:type() .. " (" .. uid0 .. ")")
                        is_man = false
                    end
                end
            end
        end

        -- override decay: after the grace window, an idle overridden unit goes
        -- back to the AI (player finished microing it and walked away)
        local ov = overridden[uid0]
        if ov and not ai_now then
            if (now_ms - ov.at) > CONFIG.override_grace_s * 1000 then
                if unit:is_idle() then
                    ov.idle_at = ov.idle_at or now_ms
                    if (now_ms - ov.idle_at) > CONFIG.override_idle_s * 1000 then
                        overridden[uid0] = nil
                        -- back under the planner so the standing directive reaches it
                        if planner then
                            local su1 = bm:get_scriptunit_for_unit(unit)
                            if su1 then pcall(function() planner:add_sunits(su1) end) end
                        end
                        out_log("override-end " .. unit:type() .. " (" .. uid0 .. ")")
                    end
                else
                    ov.idle_at = nil -- still being microed
                end
            end
        end
        if ai_now then
            -- track the planner's live intent so a foreign order landing next
            -- tick can be measured against it
            local ok_o, op = pcall(function() return unit:ordered_position() end)
            if ok_o and op then prev_ordered[uid0] = op end
        end
        prev_ai[uid0] = ai_now

        if is_man and not unit:is_routing() and not unit:is_shattered() then
            local su = bm:get_scriptunit_for_unit(unit)
            if su and su.uc then
                local p = probe_unit(unit)
                local role = classify(unit, p)
                role_of[uid0] = role
                delegated[#delegated + 1] = {
                    su = su, unit = unit, role = role,
                    anti_large = p.prof and p.prof.anti_large,
                    highvalue = p.prof and p.prof.highvalue,
                    shock = p.prof and p.prof.shock,
                    no_skirmish = p.prof and p.prof.no_skirmish,
                }
                if role == "shooter" or role == "artillery" then shooters[#shooters + 1] = unit end
                if role == "cav" or role == "flyer" or role == "cav_shot" then
                    n_mobile = n_mobile + 1
                end
            end
        else
            local uid = tostring(unit:unique_ui_id())
            idle_since[uid] = nil -- reset when not delegated
            guard_set[uid .. "|defend"] = nil
            guard_set[uid .. "|skirmish"] = nil
            unit_task[uid] = nil
            role_of[uid] = nil
            charge_state[uid] = nil
            wounded_pull[uid] = nil
            atk_target_uid[uid] = nil
            order_dest[uid] = nil
            prev_ordered[uid] = nil
        end
    end)

    -- enemy snapshot with roles for threat/target selection
    local enemies, enemies_ranged, enemies_monster, enemies_airarty = {}, {}, {}, {}
    local enemies_routing = {} -- routing-but-alive: cavalry runs these down
    local erole = {} -- [enemy unit] = role
    do
        local alliance = bm:get_non_player_alliance()
        -- visibility check asks "visible to OUR alliance"; pass our side explicitly
        local my_alliance = bm:alliances():item(bm:local_alliance())
        if alliance then
            local armies = alliance:armies()
            for a = 1, armies:count() do
                local units = armies:item(a):units()
                for u = 1, units:count() do
                    local e = units:item(u)
                    -- skip enemies hidden from our alliance (stalk/unspottable) so we
                    -- don't react to units the player can't even see
                    local visible = true
                    if my_alliance then
                        local ok_v, vis = pcall(function() return e:is_visible_to_alliance(my_alliance) end)
                        if ok_v and vis == false then visible = false end
                    end
                    local ok_h, hid = pcall(function() return e:is_hidden() end)
                    if ok_h and hid == true then visible = false end
                    if e and visible and not e:is_routing() then
                        local p = probe_unit(e)
                        local role = classify(e, p)
                        enemies[#enemies + 1] = e
                        erole[e] = role
                        if role == "shooter" or role == "artillery" then enemies_ranged[#enemies_ranged + 1] = e end
                        if role == "monster" then enemies_monster[#enemies_monster + 1] = e end
                        if role == "flyer" or role == "artillery" then enemies_airarty[#enemies_airarty + 1] = e end
                    elseif e and visible then
                        local ok_sh, sh = pcall(function() return e:is_shattered() end)
                        if not (ok_sh and sh) then
                            enemies_routing[#enemies_routing + 1] = e
                        end
                    end
                end
            end
        end
    end

    local doctrine = select_doctrine(delegated, shooters, n_mobile)
    if doctrine ~= last_doctrine then
        out_log("doctrine -> " .. doctrine .. " (delegated=" .. #delegated
            .. " shooters=" .. #shooters .. " mobile=" .. n_mobile .. ")")
        last_doctrine = doctrine
    end
    issue_planner_directive(now_ms, doctrine, delegated, enemies)

    -- heartbeat every ~60s: lets us tell "no threats in range" from "handler
    -- never ran" when reading logs after a battle
    if #enemies > 0 then saw_enemies = true end

    tick_n = tick_n + 1
    if tick_n % 20 == 0 then
        local n_idle, n_planned = 0, -1
        local hp_a, hp_e, n_ally_alive = 0, 0, 0
        for _, d in ipairs(delegated) do
            -- "standing with a stale order" counts as idle — is_idle() alone
            -- misses units frozen on a completed hold/defend order
            if effectively_idle(d, d.unit, nil) then n_idle = n_idle + 1 end
        end
        -- army hp accounting for post-battle review + win/loss detection
        for_each_player_unit(function(u)
            local ok_r, rt = pcall(function() return u:is_routing() end)
            if not (ok_r and rt) then n_ally_alive = n_ally_alive + 1 end
            local ok, h = pcall(function() return u:unary_hitpoints() end)
            if ok and is_number(h) then hp_a = hp_a + h end
        end)
        for _, e in ipairs(enemies) do
            local ok, h = pcall(function() return e:unary_hitpoints() end)
            if ok and is_number(h) then hp_e = hp_e + h end
        end
        if planner then
            local ok_c, c = pcall(function() return planner:count() end)
            if ok_c then n_planned = c end
        end
        out_log("tick-stats doctrine=" .. doctrine .. " del=" .. #delegated
            .. " planner=" .. n_planned .. " idle=" .. n_idle
            .. " enemies=" .. #enemies .. " routing=" .. #enemies_routing
            .. " hp=" .. math.floor(hp_a) .. "/" .. math.floor(hp_e))
        -- battle outcome (once): all enemies dead-or-routing = win,
        -- all our units routing = loss
        if saw_enemies and not outcome_logged then
            if #enemies == 0 then
                outcome_logged = true
                out_log("outcome WIN — enemy army routed or destroyed, hp ally/enemy="
                    .. math.floor(hp_a) .. "/" .. math.floor(hp_e))
            elseif n_ally_alive == 0 then
                outcome_logged = true
                out_log("outcome LOSS — player army routed")
            end
        end
    end

    -- pass 2: abilities + role behaviour
    local ctx = {
        now_ms = now_ms, doctrine = doctrine, shooters = shooters,
        enemies = enemies, enemies_ranged = enemies_ranged,
        enemies_monster = enemies_monster, enemies_airarty = enemies_airarty,
        enemies_routing = enemies_routing,
        erole = erole,
    }
    for _, d in ipairs(delegated) do
        local su, unit = d.su, d.unit
        local uid = tostring(unit:unique_ui_id())
        -- summoned units can despawn while an ability effect is still resolving;
        -- both observed freezes happened on psw_summon_* flyers, so their
        -- abilities stay manual (orders/tasks are unaffected)
        local is_summon = unit:type():find("summon") ~= nil
        local abilities = CONFIG.auto_cast
            and (not is_summon or CONFIG.cast_on_summons)
            and unit:owned_non_passive_special_abilities() or nil
        if is_summon and not summon_probe[unit:type()] then
            summon_probe[unit:type()] = true
            out_log("summon-skip " .. unit:type() .. " (" .. uid .. ")")
        end
        if abilities then
            for k, v in pairs(abilities) do
                local key = is_string(v) and v or (is_string(k) and k or nil)
                if key and ability_allowed(unit, key) then
                    local ok, err = pcall(try_cast, su, unit, key, now_ms)
                    if not ok then
                        -- any perform failure is permanent for this combo:
                        -- can_perform lies for some abilities, and retrying a
                        -- cast that can never succeed just spams errors
                        unsupported[uid .. "|" .. key] = true
                        out_log("cast-fail " .. key .. " on " .. uid .. ": " .. tostring(err))
                    end
                end
            end
        end
        local task = assign_task(d, ctx)
        if unit_task[uid] ~= task then
            out_log("task " .. unit:type() .. " (" .. uid .. ") role=" .. d.role .. " -> " .. task)
            unit_task[uid] = task
        end
        -- quiet window: never issue an order while a cast is still resolving;
        -- a same-tick cast+order pair raced a bomb maneuver into a sim deadlock
        if cast_at[uid] and (now_ms - cast_at[uid]) < CONFIG.cast_quiet_ms then
            -- cast still resolving; hold the task order this tick
        else
            in_task_pass = true
            -- tactical micro overrides the doctrine task when it triggers:
            -- wounded pull-out > shooter kiting > cav cycle-charge > task
            local ok_h, handled = pcall(function()
                return wounded_step(d, ctx) or kite_step(d, ctx) or cycle_charge_step(d, ctx)
            end)
            if not (ok_h and handled) then
                local exec = TASK_EXEC[task] or TASK_EXEC.attack
                pcall(exec, d, ctx)
            end
            in_task_pass = false
        end
    end

    sim_step(now_ms)
end

---------------------------------------------------------------------------------------------
-- listeners: hotkey handoff + engine command events (reclaim probe + dodge)
---------------------------------------------------------------------------------------------

-- hotkey handoff: select unit cards, press the bound shortcut (camera bookmark
-- saves by default — rebindable under Settings > Camera)
add_handoff_listener("czx_handoff_toggle", CONFIG.hotkey_toggle,
    function() handoff_toggle() end)
add_handoff_listener("czx_handoff_override", CONFIG.hotkey_override,
    function() handoff_override(bm:time_elapsed_ms()) end)

-- UI order commands on delegated units = the player took over. Events arriving
-- while in_task_pass is true are our own uc orders and get filtered out.
for _, name in ipairs({
    "Attack Unit", "Move Orientation Width", "Move Rotation Angle",
    "Change Speed", "Change Melee", "Change Skirmish", "Fire At Will",
}) do
    add_order_listener(name)
end

-- enemy ability casts: the Special Ability command context exposes the caster
-- (get_unit) and hopefully the target point (get_position) -> scatter our units
-- standing in the blast. Probe logging verifies the schema in live games.
pcall(function()
    bm:register_command_handler_callback("Special Ability", function(ctx)
        cmd_probe_log(ctx, "Special Ability")
        if not CONFIG.dodge or in_task_pass then return end
        local ok_u, caster = pcall(function() return ctx:get_unit() end)
        local ok_p, pos = pcall(function() return ctx:get_position() end)
        if not (ok_u and caster and ok_p and pos) then return end
        local ok_a, al = pcall(function() return caster:alliance_index() end)
        if not (ok_a and al and al ~= bm:local_alliance()) then return end
        local now_ms = bm:time_elapsed_ms()
        local n_scatter = 0
        for_each_player_unit(function(unit)
            local uid = tostring(unit:unique_ui_id())
            if managed[uid] and not reclaimed[uid] and not overridden[uid]
                and not unit:is_routing()
                and (now_ms - (dodge_at[uid] or 0)) > CONFIG.dodge_cooldown_ms then
                local ok_d, dist = pcall(function() return unit:position():distance_xz(pos) end)
                if ok_d and dist and dist <= CONFIG.dodge_radius_m then
                    local su = bm:get_scriptunit_for_unit(unit)
                    if su and su.uc then
                        dodge_at[uid] = now_ms
                        order_flee_pos(su, unit, pos, CONFIG.dodge_dest_m, now_ms, "dodge")
                        n_scatter = n_scatter + 1
                    end
                end
            end
        end)
        if n_scatter > 0 then
            local ok_k, key = pcall(function() return ctx:get_string1() end)
            out_log("dodge n=" .. n_scatter .. " <- " .. tostring(ok_k and key))
        end
    end, "czx_cmd_special")
end)

-- pcall 兜底：tick 内任何报错只记日志——裸错会中断 timer_manager 泵的
-- singleshot 重武装，把全场所有脚本的计时器一起打死（czx_tc 实测教训）
bm:repeat_callback(function()
    local ok, err = pcall(tick)
    if not ok then out_log("ERROR tick " .. tostring(err)) end
end, CONFIG.poll_ms, "czx_auto_ability_tick")
out_log("loaded, poll " .. CONFIG.poll_ms .. "ms, auto_cast=" .. tostring(CONFIG.auto_cast)
    .. " auto_delegate=" .. tostring(CONFIG.auto_delegate)
    .. " hotkey=" .. tostring(CONFIG.hotkey_toggle) .. "/" .. tostring(CONFIG.hotkey_override))
'''

OUT.parent.mkdir(parents=True, exist_ok=True)
test_sim = "--test" in sys.argv
OUT.write_text(template.replace("__DATA__", data).replace("__PROFILE_DATA__", profile_data)
    .replace("__TEST_SIM__", "true" if test_sim else "false"), encoding="utf-8")
print(f"wrote {OUT} with {len(rows)} abilities, test_sim={test_sim}")
