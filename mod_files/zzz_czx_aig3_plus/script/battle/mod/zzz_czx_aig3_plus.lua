---------------------------------------------------------------------------------------------
-- zzz_czx_aig3_plus.lua
-- Companion mod for AI General III (paperpancake). Requires aigeneral_iii_pancake.
-- Filename must sort AFTER aigeneral_iii_main.lua so pan_aigeneral already exists
-- when this file executes (battle/mod scripts load alphabetically, not in
-- playset order).
--
-- Two jobs:
--  1. Doctrine directives: keep a standing army-level order on
--     pan_aigeneral.player_ai — attack_unit for push doctrines, defend_position
--     (with stalemate creep) for hold doctrines. An orderless planner was
--     observed leaking delegated units back to the player; a standing order
--     also gives the delegated army one coherent intent instead of letting
--     every unit drift on its own engine AI.
--  2. Auto-ability: poll delegated units' ready non-passive abilities and cast
--     them via script_unit.uc + release_control — this does NOT detach the
--     unit from the planner (v1 battle-tested). Uses the baked ABILITY_FLAGS
--     table from zzz_czx_aig3_data.lua, including the sim-freeze blacklists.
--  3. Detachments (拉扯): small claim-based micro for units whose value comes
--     from movement, not standing orders — shock cavalry cycle-charges,
--     skirmishers kiting toward priority prey, wounded high-value units pulled
--     out of melee and parked. Claims go through modder_API_uc_manager, which
--     cleanly detaches the unit from AIG3's planner (its release callback
--     fires set_ai_enabled(false)+exclusion); releasing a claim plus
--     set_ai_enabled(true) hands the unit back. Per-unit UC orders are ONLY
--     ever issued on units we currently claim — never on planner-held units,
--     which is what caused v1's control oscillation.
---------------------------------------------------------------------------------------------

local CONFIG = {
    enabled              = true,
    debug                = true,    -- >>> AIG3+ >>> lines into script_log
    tick_ms              = 3000,    -- main poll interval

    -- doctrine directives (planner-level orders)
    directives           = true,    -- master switch; false = never order player_ai
    directive_refresh_ms = 20000,   -- re-issue/retarget standing order this often
    defend_radius_m      = 120,     -- defend_position radius (vanilla defend = 120ish)
    stale_creep_ms       = 60000,   -- no contact this long -> creep the anchor
    creep_step_m         = 150,     -- metres per creep step toward the enemy
    contact_range_m      = 200,     -- nearest-enemy distance that counts as "in contact"
    doctrine             = "auto",  -- "auto" | "gunline" | "balanced" | "rush" | "none"
    gunline_min_share    = 0.35,    -- auto: gunline if >=35% of delegated carry ammo
    rush_max_shooter_share = 0.15,  -- auto: rush if <=15% carry ammo
    rush_min_mobile_share  = 0.60,  -- auto: rush if >=60% are cav/flyer/mounted
    -- field battle whitelist for directives: sieges/quests stay on AIG3's own
    -- behaviour (CA does not recommend ai planner in sieges anyway). Ability
    -- casts are NOT gated — they are safe in any battle type.
    directive_types      = {
        land_normal = true, land_ambush = true, underground = true,
        underway = true, chokepoint = true, crossing = true,
    },

    -- auto-ability (delegated units only)
    auto_cast            = true,    -- master switch: false = never call perform_special_ability
    cast_spells          = true,    -- false = skip abilities with mana_cost > 0 (mask bit 16)
    engage_range_m       = 120,     -- only attempt casts when nearest enemy within this
    retry_ms             = 20000,   -- min delay between attempts of same ability on same unit
    cast_on_summons      = false,   -- summoned units despawn mid-effect; skip them
    banned_abilities     = {},      -- {["ability_key"]=true} never auto-cast
    unit_keys            = {},      -- non-empty = only these unit types auto-cast

    -- detachments (claim-based micro; uc orders only on units we claim)
    detach               = true,    -- master switch for pass 3
    max_claimed          = 6,       -- hard cap on simultaneously claimed units
    detach_min_battle_ms = 10000,   -- no claims in the first seconds of a battle
    claim_engage_m       = 350,     -- only claim mobile units once an enemy is this close to them
    order_retry_ms       = 2500,    -- min gap between our orders to the same claimed unit
    -- charger (shock cav cycle-charge)
    charger_dwell_ms     = 9000,    -- stay in melee this long before pulling out
    charger_rearm_ms     = 12000,   -- after pullout, wait this long before re-charging
    charger_target_m     = 450,     -- pick charge targets within this of the unit
    withdraw_offset_m    = 90,      -- pull-out distance toward our own rear
    -- skirmisher (cav_shot / harasser kiting)
    skirmish_engage_mult = 0.8,     -- close to this fraction of missile_range
    skirmish_threat_m    = 70,      -- enemy closer than this -> fall back
    -- wounded pull-out (highvalue/lord at low hp)
    wounded_hp           = 0.35,    -- unary_hitpoints fraction
    rear_offset_m        = 130,     -- park this far behind the army centroid
    -- guard (backline countercharge — paperpancake's own AttackMove mod
    -- proves the anchor+leash pattern): melee units parked near threatened
    -- shooters/artillery, engage inside leash, return to anchor
    guard_trigger_m      = 150,     -- enemy mobile near a shooter/art within this -> want a guard
    guard_leash_m        = 90,      -- guards never chase farther than this from anchor
    guard_engage_m       = 65,      -- guards attack enemies within this of themselves
    guard_release_s      = 15,      -- no threat near anchor this long -> release
    -- shooter skirmish-flag management (top AIG3 complaint: foot shooters
    -- walked into melee). Behaviour toggles go through uc + release_control,
    -- same as casts — no claim needed
    skirmish_manage      = true,
    skirmish_on_m        = 70,      -- foot shooters: enemy this close -> skirmish on
    skirmish_off_m       = 110,     -- enemy farther than this -> skirmish off (hysteresis)
    -- cast discipline (community: "a lot of magic goes to waste")
    friendly_splash_m    = 35,      -- skip target_ground casts if a friendly is this close to impact
    self_cast_range_m    = 45,      -- self/friend buffs only when enemy this close or in melee
}

local function plog(msg) out(">>> AIG3+ >>> " .. tostring(msg)) end
local function dlog(msg) if CONFIG.debug then plog(msg) end end

if not (pan_aigeneral and is_table(pan_aigeneral)) then
    plog("pan_aigeneral not found — aigeneral_iii_pancake missing or load order changed; AIG3+ inert")
    return
end
if not (CZX_AIG3_ABILITY_FLAGS and CZX_AIG3_UNIT_PROFILE) then
    plog("zzz_czx_aig3_data.lua missing — auto-ability disabled")
    CONFIG.auto_cast = false
end

plog("loaded (directives=" .. tostring(CONFIG.directives)
    .. " auto_cast=" .. tostring(CONFIG.auto_cast) .. ")")

---------------------------------------------------------------------------------------------
-- shared state / helpers
---------------------------------------------------------------------------------------------

local unsupported  = {} -- [uid.."|"..ability_key] = true once the engine says no
local denied_keys  = {} -- [ability_key] = true once a maneuver ability was skipped
local cast_log     = {} -- [uid] = { [ability_key] = last_attempt_ms }
local summon_probe = {} -- [unit_type] = true once logged as cast-skipped

local directive_doc     = nil -- doctrine the standing planner order was issued under
local directive_ms      = 0   -- when it was issued
local directive_target  = nil -- enemy unit the standing attack order points at
local last_contact_ms   = 0   -- last time an enemy was inside contact range
local seen_types        = {}  -- [unit_type] = true once role-probe info logged
local battle_type_ok    = nil -- cached directive gate result
local started_logged    = false

-- battle_unit -> role string. Baked profile first; runtime boolean chain for
-- unbaked (foreign mod) units. Ported from v1 classify().
local function role_of(unit, prof, ammo, speed, flies)
    if prof then
        local cat = prof.cat
        if cat == "war_machine" or cat == "artillery" then return "artillery" end
        if prof.cls == "com" then return "lord" end
        if flies then return (ammo ~= 0 or prof.harasser) and "cav_shot" or "flyer" end
        if cat == "cavalry" then
            return (ammo ~= 0 or prof.harasser or prof.ai:find("ranged_cav"))
                and "cav_shot" or "cav"
        end
        if prof.large or cat == "war_beast" then return "monster" end
        if cat == "inf_ranged" or ammo ~= 0 then return "shooter" end
        return "melee"
    end
    local function ub(m)
        local ok, v = pcall(function() return unit[m](unit) end)
        return ok and v == true
    end
    if ub("is_artillery") or ub("is_war_machine") then return "artillery" end
    if ub("is_commanding_unit") then return "lord" end
    if flies then return ammo ~= 0 and "cav_shot" or "flyer" end
    if ub("is_cavalry") or ub("is_chariot") or speed >= 60 then
        return ammo ~= 0 and "cav_shot" or "cav"
    end
    if ub("is_war_beasts") or ub("is_elephants") then return "monster" end
    if ammo ~= 0 then return "shooter" end
    return "melee"
end

local function profile_of(unit)
    if not CZX_AIG3_UNIT_PROFILE then return nil end
    local s = CZX_AIG3_UNIT_PROFILE[unit:type()]
    if not s then return nil end
    local ai, cat, cls, lg = s:match("^([^|]*)|([^|]*)|([^|]*)|(%d)")
    ai = ai or ""
    return {
        ai = ai, cat = cat or "", cls = cls or "", large = (lg == "1"),
        anti_large  = ai:find("anti_large") ~= nil,
        shock       = ai:find("shock") ~= nil,
        highvalue   = ai:find("highvalue") ~= nil,
        no_skirmish = ai:find("no_skirmish") ~= nil,
        harasser    = ai:find("harasser") ~= nil,
        mage        = ai:find("mage") ~= nil,
    }
end

local function probe_unit(unit)
    local p = {}
    local ok_a, ammo  = pcall(function() return unit:ammo_left() end)
    local ok_r, range = pcall(function() return unit:missile_range() end)
    local ok_s, speed = pcall(function() return unit:fast_speed() end)
    local ok_f, flies = pcall(function() return unit:can_fly() end)
    p.ammo  = (ok_a and is_number(ammo))  and ammo  or 0
    p.range = (ok_r and is_number(range)) and range or 0
    p.speed = (ok_s and is_number(speed)) and speed or 0
    p.flies = ok_f and flies or false
    p.prof  = profile_of(unit)
    return p
end

-- delegated = pan_aigeneral.ai_list entries that are alive and actionable
local function collect_delegated()
    local out_t = {}
    local list = pan_aigeneral.ai_list
    if not is_table(list) then return out_t end
    for i = 1, #list do
        local su = list[i]
        local ok, unit = pcall(function() return su.unit end)
        if ok and unit and not is_shattered_or_dead(unit) then
            local p = probe_unit(unit)
            out_t[#out_t + 1] = { su = su, unit = unit, probe = p,
                role = role_of(unit, p.prof, p.ammo, p.speed, p.flies) }
        end
    end
    return out_t
end

local function collect_enemies()
    local out_t = {}
    local alliance = bm:get_non_player_alliance()
    if not alliance then return out_t end
    local armies = alliance:armies()
    for a = 1, armies:count() do
        local units = armies:item(a):units()
        for u = 1, units:count() do
            local e = units:item(u)
            if e and e:is_valid_target() and not e:is_routing() then
                out_t[#out_t + 1] = e
            end
        end
    end
    return out_t
end

local function dist_xz(a, b)
    local ok, d = pcall(function() return a:position():distance_xz(b:position()) end)
    return (ok and is_number(d)) and d or math.huge
end

local function nearest_enemy(unit, enemies)
    local best, best_d = nil, math.huge
    for _, e in ipairs(enemies) do
        local d = dist_xz(unit, e)
        if d < best_d then best, best_d = e, d end
    end
    return best, best_d
end

local function centroid(units)
    local cx, cz, n = 0, 0, 0
    for _, u in ipairs(units) do
        local ok, pos = pcall(function() return u:position() end)
        if ok and pos then
            cx = cx + pos:get_x()
            cz = cz + pos:get_z()
            n = n + 1
        end
    end
    if n == 0 then return nil end
    local ok_v, vec = pcall(function() return v(cx / n, cz / n) end)
    return (ok_v and vec) or nil
end

---------------------------------------------------------------------------------------------
-- pass 1: doctrine directives on pan_aigeneral.player_ai
---------------------------------------------------------------------------------------------

local function pick_doctrine(delegated, n_shooters, n_mobile)
    if CONFIG.doctrine ~= "auto" then return CONFIG.doctrine end
    local n = #delegated
    if n == 0 then return "none" end
    if n_mobile / n >= CONFIG.rush_min_mobile_share then return "rush" end
    local share = n_shooters / n
    if share >= CONFIG.gunline_min_share and n_shooters >= 2 then return "gunline" end
    if share <= CONFIG.rush_max_shooter_share then return "rush" end
    return "balanced"
end

local function issue_directive(now_ms, doctrine, delegated, enemies)
    local planner = pan_aigeneral.player_ai
    if not planner or doctrine == "none" then return end

    if doctrine == "rush" then
        -- refresh on doctrine change, target routed, or refresh window elapsed
        local stale = true
        if directive_target then
            local ok_s, r = pcall(function() return directive_target:is_routing() end)
            stale = (not ok_s) or r == true
        end
        if doctrine == directive_doc and not stale
            and (now_ms - directive_ms) < CONFIG.directive_refresh_ms then
            return
        end
        -- closest enemy to any delegated unit = what the front line faces
        local best, best_d = nil, math.huge
        for _, e in ipairs(enemies) do
            for _, d in ipairs(delegated) do
                local dist = dist_xz(e, d.unit)
                if dist < best_d then best, best_d = e, dist end
            end
        end
        if not best then return end
        -- rush_unit over attack_unit: rush goes "without too much reforming"
        -- (CA doc), which is what a push wants — attack_unit's reformation is
        -- the "everyone stops and shoves" pile-up users complain about
        local ok_o, err = pcall(function()
            if planner.rush_unit then
                planner:rush_unit(best)
            else
                planner:attack_unit(best)
            end
        end)
        if ok_o then
            directive_doc, directive_ms, directive_target = doctrine, now_ms, best
            dlog("directive rush -> " .. tostring(best:type()) .. " d=" .. math.floor(best_d))
        else
            plog("directive-fail attack " .. tostring(err))
        end
    else
        -- hold doctrines: defend the ground the group stands on, with
        -- stalemate creep — edge the anchor toward the enemy one step per
        -- refresh when nobody is in contact (AI refusing battle used to stall
        -- the clock for tens of minutes; contact resets the creep timer)
        if doctrine == directive_doc
            and (now_ms - directive_ms) < CONFIG.directive_refresh_ms then
            return
        end
        local ok_cp, anchor = pcall(function() return planner:get_centre_point() end)
        if not (ok_cp and anchor) then
            anchor = centroid((function()
                local t = {}
                for _, d in ipairs(delegated) do t[#t + 1] = d.unit end
                return t
            end)())
        end
        if not anchor then return end
        local stale = (now_ms - last_contact_ms) > CONFIG.stale_creep_ms
        if stale then
            local best = nil
            local best_d = math.huge
            for _, e in ipairs(enemies) do
                local ok_d, dist = pcall(function()
                    return e:position():distance_xz(anchor)
                end)
                if ok_d and dist and dist < best_d then best, best_d = e, dist end
            end
            if best then
                local ok_ep, ep = pcall(function() return best:position() end)
                if ok_ep and ep then
                    local dx = ep:get_x() - anchor:get_x()
                    local dz = ep:get_z() - anchor:get_z()
                    local len = math.sqrt(dx * dx + dz * dz)
                    if len > 1 then
                        local step = math.min(CONFIG.creep_step_m, len)
                        local ok_v, nv = pcall(function()
                            return v(anchor:get_x() + dx / len * step,
                                     anchor:get_z() + dz / len * step)
                        end)
                        if ok_v and nv then anchor = nv end
                    end
                end
            end
        end
        local ok_o, err = pcall(function()
            planner:defend_position(anchor, CONFIG.defend_radius_m)
        end)
        if ok_o then
            directive_doc, directive_ms, directive_target = doctrine, now_ms, nil
            dlog("directive defend r=" .. CONFIG.defend_radius_m .. (stale and " creep" or ""))
        else
            plog("directive-fail defend " .. tostring(err))
        end
    end
end

---------------------------------------------------------------------------------------------
-- pass 2: auto-ability for delegated units (uc order + release_control)
---------------------------------------------------------------------------------------------

local function ability_allowed(unit, key)
    if CONFIG.banned_abilities[key] then return false end
    if next(CONFIG.unit_keys) ~= nil and not CONFIG.unit_keys[unit:type()] then
        return false
    end
    return true
end

local function try_cast(su, unit, key, now_ms, enemies, delegated_ref)
    local uid = tostring(unit:unique_ui_id())
    local combo = uid .. "|" .. key
    if unsupported[combo] then return end
    local ulog = cast_log[uid]
    if ulog and ulog[key] and (now_ms - ulog[key]) < CONFIG.retry_ms then
        return
    end
    -- formation abilities are unit-shape toggles, not fire-and-forget casts:
    -- re-toggling churns control and wedged the formation solver (v1: sim
    -- froze 1.7s after formation_lance on a single-model monster)
    if key:find("formation") then return end
    -- maneuver abilities (bomb drops / flyover attacks) made flyers chase
    -- their own position forever and deadlocked the sim thread (v1: two
    -- freezes ~1s after casting djs_fw_190_zhadan)
    if key:find("zhadan") or key:find("gyrobomber_bomb") or key:find("copter_bomb")
        or key:find("bomb_drop") or key:find("djs_f4u_t0") then
        if not denied_keys[key] then
            denied_keys[key] = true
            dlog("denied-maneuver " .. key)
        end
        return
    end
    local flag_str = CZX_AIG3_ABILITY_FLAGS[key]
    local mask = 0
    if flag_str then
        mask = tonumber(flag_str:match("^(%d+),")) or 0
    end
    if mask >= 16 then
        if not CONFIG.cast_spells then return end
        mask = mask - 16
    end
    if not unit:can_perform_special_ability(key) then
        return
    end
    -- engagement gate: don't churn unit control for abilities that can't matter
    local e, dist = nearest_enemy(unit, enemies)
    if not e or dist > CONFIG.engage_range_m then
        return
    end
    if mask % 2 >= 1 then
        -- target_ground: friendly-splash check — the classic "AI bombs its own
        -- troops" waste (SFO Battle-AI-Tweaks headline fix). Skip if any other
        -- delegated unit is near the impact point.
        local ok_tp, tpos = pcall(function() return e:position() end)
        if ok_tp and tpos then
            for _, d in ipairs(delegated_ref or {}) do
                if d.unit ~= unit then
                    local ok_d, fd = pcall(function()
                        return d.unit:position():distance_xz(tpos)
                    end)
                    if ok_d and fd and fd < CONFIG.friendly_splash_m then
                        return -- friendly in the blast zone
                    end
                end
            end
        end
    elseif mask % 4 < 2 then
        -- self/friend-target buffs: casting at 100m+ while walking in wastes
        -- most of a 30-45s duration — hold until melee or near-contact
        local ok_m, melee = pcall(function() return unit:is_in_melee() end)
        if not (ok_m and melee) and dist > CONFIG.self_cast_range_m then
            return
        end
    end
    local fired = false
    if mask % 2 >= 1 then -- target_ground
        su.uc:perform_special_ability_ground(key, e:position())
        fired = true
    elseif mask % 4 >= 2 then -- target_enemies
        su.uc:perform_special_ability(key, e)
        fired = true
    else -- self / aura / target_friends -> cast on self (engine wants a target arg)
        su.uc:perform_special_ability(key, unit)
        fired = true
    end
    if fired then
        -- issuing an order implicitly takes script control; release it back so
        -- the ai planner keeps commanding the unit (v1 mechanism, battle-tested)
        su.uc:release_control()
        cast_log[uid] = cast_log[uid] or {}
        cast_log[uid][key] = now_ms
        dlog("cast " .. key .. " on " .. uid)
    end
end

local function cast_pass(delegated, enemies, now_ms)
    for _, d in ipairs(delegated) do
        local su, unit = d.su, d.unit
        local uid = tostring(unit:unique_ui_id())
        -- summoned units can despawn mid-effect; both observed v1 freezes
        -- happened on psw_summon_* flyers — their abilities stay manual
        local is_summon = unit:type():find("summon") ~= nil
        if is_summon and not CONFIG.cast_on_summons then
            if not summon_probe[unit:type()] then
                summon_probe[unit:type()] = true
                dlog("summon-skip " .. unit:type() .. " (" .. uid .. ")")
            end
        else
            local abilities = unit:owned_non_passive_special_abilities()
            if abilities then
                for k, v in pairs(abilities) do
                    local key = is_string(v) and v or (is_string(k) and k or nil)
                    if key and ability_allowed(unit, key) then
                        local ok, err = pcall(try_cast, su, unit, key, now_ms, enemies, delegated)
                        if not ok then
                            -- can_perform lies for some abilities; retrying a
                            -- cast that can never succeed just spams errors
                            unsupported[uid .. "|" .. key] = true
                            plog("cast-fail " .. key .. " on " .. uid .. ": " .. tostring(err))
                        end
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------------------------
-- pass 2.5: skirmish-flag management on delegated foot shooters
--
-- The #1 AIG3 user complaint: "sends 500-range units with full ammo into
-- melee". The engine's own "skirmish" behaviour makes ranged units retreat
-- from approaching enemies — planner units respond to the flag (AIG3 itself
-- caches/restores it via pancake_cached_skirmish). Toggling it is a uc call +
-- release_control, same mechanism as ability casts — no claim needed, the
-- planner keeps command. Hysteresis band so we don't flap the flag.
---------------------------------------------------------------------------------------------

local function skirmish_pass(delegated, enemies, now_ms)
    for _, d in ipairs(delegated) do
        if d.role == "shooter" and d.probe and d.probe.ammo > 0 then
            local prof = d.probe.prof
            if not (prof and prof.no_skirmish) then
                local unit = d.unit
                local ok_c, can = pcall(function()
                    return unit:can_use_behaviour("skirmish")
                end)
                if ok_c and can then
                    local _, dist = nearest_enemy(unit, enemies)
                    local ok_a, active = pcall(function()
                        return unit:is_behaviour_active("skirmish")
                    end)
                    local want = nil
                    if dist < CONFIG.skirmish_on_m then want = true
                    elseif dist > CONFIG.skirmish_off_m then want = false end
                    if want ~= nil and active ~= want then
                        local uid = tostring(unit:unique_ui_id())
                        local ok_s, err = pcall(function()
                            d.su:change_behaviour_active("skirmish", want, true)
                        end)
                        if ok_s then
                            dlog("skirmish " .. (want and "on" or "off")
                                .. " " .. unit:type() .. " (" .. uid .. ") d="
                                .. math.floor(dist))
                        else
                            plog("skirmish-fail " .. tostring(err))
                        end
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------------------------
-- pass 3: detachments — claim-based micro (拉扯)
--
-- Claims run through modder_API_uc_manager: claiming an AIG3-held unit makes
-- the uc_manager invoke AIG3's registered release callback, which detaches it
-- from the planner (set_ai_enabled false) and excludes it from auto re-add.
-- While claimed, the unit is a normal player-controlled unit plus our orders —
-- the planner never touches it, so there is no UC-vs-planner oscillation.
-- Releasing: release_claims_without_callbacks + pan_aigeneral:set_ai_enabled
-- (add_to_ai clears the exclusion itself) returns the unit to the planner.
---------------------------------------------------------------------------------------------

local MOD_KEY = "czx_aig3_plus"
local claims      = {} -- [uid] = { su, unit, kind, state, t, target_ref }
local ordered_at  = {} -- [uid] = last ms we issued an order to it
local ntarget_cd  = {} -- [uid] = ms — released for no-target; don't re-claim soon
local uc_ok       = false

if modder_API_uc_manager and is_function(modder_API_uc_manager.register_mod) then
    modder_API_uc_manager:register_mod(MOD_KEY, function(lost_ids)
        -- someone else force-claimed our units — drop our state for them
        for i = 1, #lost_ids do
            claims[lost_ids[i]] = nil
            ordered_at[lost_ids[i]] = nil
        end
    end)
    uc_ok = true
else
    plog("modder_API_uc_manager missing — detachments disabled")
    CONFIG.detach = false
end

local function order_allowed(uid, now_ms)
    local t = ordered_at[uid]
    if t and (now_ms - t) < CONFIG.order_retry_ms then return false end
    return true
end

local function uc_move(su, unit, pos, now_ms, tag, run)
    local uid = tostring(unit:unique_ui_id())
    if not order_allowed(uid, now_ms) then return false end
    local ok, err = pcall(function()
        local ok_b, bearing = pcall(function() return unit:bearing() end)
        local deg = (ok_b and is_number(bearing)) and bearing * 180 / math.pi or 0
        local ok_w, width = pcall(function() return unit:ordered_width() end)
        su.uc:goto_location_angle_width(pos, deg, (ok_w and width) or 0, run ~= false)
        su.uc:release_control()
    end)
    if ok then
        ordered_at[uid] = now_ms
        dlog("move " .. tag .. " " .. unit:type() .. " (" .. uid .. ")")
    else
        plog("move-fail " .. tag .. " " .. tostring(err))
    end
    return ok
end

local function uc_attack(su, unit, e, now_ms, tag)
    local uid = tostring(unit:unique_ui_id())
    if not order_allowed(uid, now_ms) then return false end
    local ok, err = pcall(function()
        su.uc:attack_unit(e, true, true)
        su.uc:release_control()
    end)
    if ok then
        ordered_at[uid] = now_ms
        dlog("charge " .. tag .. " " .. unit:type() .. " (" .. uid .. ") -> " .. e:type())
    else
        plog("charge-fail " .. tag .. " " .. tostring(err))
    end
    return ok
end

-- rear anchor = army centroid mirrored away from the enemy centroid
local function rear_anchor(ally_c, enemy_c, offset)
    if not (ally_c and enemy_c) then return ally_c end
    local dx = ally_c:get_x() - enemy_c:get_x()
    local dz = ally_c:get_z() - enemy_c:get_z()
    local len = math.sqrt(dx * dx + dz * dz)
    if len < 1 then return ally_c end
    local ok_v, nv = pcall(function()
        return v(ally_c:get_x() + dx / len * offset,
                 ally_c:get_z() + dz / len * offset)
    end)
    return (ok_v and nv) or ally_c
end

-- pick a charge target for a cav-type unit: counter-matrix score minus
-- distance penalty, restricted to enemies within charger_target_m
local function pick_charge_target(unit, enemies, probes_by_e)
    local my_pos = unit:position()
    local best, bs = nil, -math.huge
    for _, e in ipairs(enemies) do
        local d = dist_xz(unit, e)
        if d <= CONFIG.charger_target_m then
            local ep = probes_by_e and probes_by_e[e]
            local erole = ep and ep.role or nil
            local bonus = (erole and CZX_AIG3_COUNTER
                           and CZX_AIG3_COUNTER.cav
                           and CZX_AIG3_COUNTER.cav[erole]) or 0
            local score = bonus * 3 - d
            if score > bs then best, bs = e, score end
        end
    end
    return best
end

local function claim_unit(d, kind)
    local uid = tostring(d.unit:unique_ui_id())
    local ok = pcall(function()
        modder_API_uc_manager:claim_units(MOD_KEY, { uid })
    end)
    if ok and modder_API_uc_manager:is_unit_claimed(uid) == MOD_KEY then
        claims[uid] = { su = d.su, unit = d.unit, kind = kind,
                        state = "init", t = 0 }
        dlog("claim " .. kind .. " " .. d.unit:type() .. " (" .. uid .. ")")
        return true
    end
    return false
end

-- to_ai=true hands the unit back to AIG3's planner (exclusion cleared inside
-- add_to_ai); false leaves it player-controlled+excluded (respects a player
-- who grabbed the unit manually, or a dead/routing unit not worth re-adding)
local function release_claim(uid, to_ai, why)
    local c = claims[uid]
    claims[uid] = nil
    ordered_at[uid] = nil
    pcall(function()
        modder_API_uc_manager:release_claims_without_callbacks({ uid }, MOD_KEY)
    end)
    if to_ai then
        local ok, err = pcall(function()
            pan_aigeneral:set_ai_enabled({ uid }, true, false)
        end)
        if not ok then plog("release-fail " .. uid .. " " .. tostring(err)) end
    end
    dlog("release " .. uid .. " to_ai=" .. tostring(to_ai) .. " " .. (why or ""))
end

local function release_all_claims(to_ai, why)
    for uid in pairs(claims) do
        release_claim(uid, to_ai, why)
    end
end

-- which detachment (if any) this delegated unit should join
local function detach_kind(d, now_ms)
    if now_ms < CONFIG.detach_min_battle_ms then return nil end
    local unit, prof = d.unit, d.probe and d.probe.prof
    -- wounded pull-out beats role claims: a dying lord/SEM is worth more parked
    local ok_hp, hp = pcall(function() return unit:unary_hitpoints() end)
    if ok_hp and is_number(hp) and hp < CONFIG.wounded_hp
        and (prof and (prof.highvalue or prof.cls == "com")) then
        local ok_m, melee = pcall(function() return unit:is_in_melee() end)
        if ok_m and melee then return "wounded" end
    end
    -- chargers hold until the lines actually meet — the "AI Coordinated
    -- Assault" complaint is fast units suiciding ahead of the army; claiming
    -- them only once contact exists keeps them from wandering in alone
    if d.role == "cav" and last_contact_ms > 0 then return "charger" end
    if d.role == "cav_shot" or (prof and prof.harasser) then return "skirmisher" end
    return nil
end

-- charger cycle: charge best target -> dwell in melee -> withdraw -> rearm
local function step_charger(c, uid, now_ms, ctx)
    local unit, su = c.unit, c.su
    if c.state == "init" or c.state == "rearmed" then
        local target = pick_charge_target(unit, ctx.enemies, ctx.eprobes)
        if not target then
            -- nothing worth charging: hand back to the planner rather than
            -- idle — and cool down so we don't claim->release->reclaim churn
            ntarget_cd[uid] = now_ms
            release_claim(uid, true, "no-target")
            return
        end
        if uc_attack(su, unit, target, now_ms, "charger") then
            c.state, c.t = "dwell", now_ms
            c.target_ref = target
        end
    elseif c.state == "dwell" then
        local target_dead = false
        if c.target_ref then
            local ok_r, r = pcall(function()
                return c.target_ref:is_routing() or is_shattered_or_dead(c.target_ref)
            end)
            target_dead = ok_r and r == true
        end
        if target_dead or (now_ms - c.t) >= CONFIG.charger_dwell_ms then
            local ok_u, upos = pcall(function() return unit:position() end)
            if ok_u and upos and ctx.ally_c then
                local dx = ctx.ally_c:get_x() - upos:get_x()
                local dz = ctx.ally_c:get_z() - upos:get_z()
                local len = math.sqrt(dx * dx + dz * dz)
                if len > 1 then
                    local ok_v, wp = pcall(function()
                        return v(upos:get_x() + dx / len * CONFIG.withdraw_offset_m,
                                 upos:get_z() + dz / len * CONFIG.withdraw_offset_m)
                    end)
                    if ok_v and wp and uc_move(su, unit, wp, now_ms, "withdraw", true) then
                        c.state, c.t = "rearm", now_ms
                    end
                else
                    c.state, c.t = "rearm", now_ms
                end
            else
                c.state, c.t = "rearm", now_ms
            end
        end
    elseif c.state == "rearm" then
        if (now_ms - c.t) >= CONFIG.charger_rearm_ms then
            c.state = "rearmed" -- next tick picks a fresh target
        end
    end
end

-- skirmisher: engine "skirmish" behaviour does the actual kiting; our job is to
-- keep it enabled and point the unit at prey worth hunting (enemy shooters /
-- artillery / cav_shot per the counter matrix) instead of plinking a meatshield
local function step_skirmisher(c, uid, now_ms, ctx)
    local unit, su = c.unit, c.su
    if c.state == "init" then
        pcall(function()
            if unit:can_use_behaviour("skirmish") then
                su:change_behaviour_active("skirmish", true, true)
            end
        end)
        c.state = "hunt"
    end
    local e, dist = nearest_enemy(unit, ctx.enemies)
    if not e then return end
    if dist < CONFIG.skirmish_threat_m then
        -- too close: fall back toward our own side
        local ok_u, upos = pcall(function() return unit:position() end)
        local ok_e, epos = pcall(function() return e:position() end)
        if ok_u and upos and ok_e and epos then
            local dx = upos:get_x() - epos:get_x()
            local dz = upos:get_z() - epos:get_z()
            local len = math.sqrt(dx * dx + dz * dz)
            if len > 1 then
                local ok_v, wp = pcall(function()
                    return v(upos:get_x() + dx / len * CONFIG.skirmish_threat_m * 1.5,
                             upos:get_z() + dz / len * CONFIG.skirmish_threat_m * 1.5)
                end)
                if ok_v and wp then uc_move(su, unit, wp, now_ms, "kite", true) end
            end
        end
        return
    end
    -- choose a hunting target: prefer artillery/shooter/cav_shot prey
    local best, bs = nil, -math.huge
    for _, en in ipairs(ctx.enemies) do
        local d = dist_xz(unit, en)
        local ep = ctx.eprobes and ctx.eprobes[en]
        local bonus = (ep and ep.role and CZX_AIG3_COUNTER
                       and CZX_AIG3_COUNTER.cav_shot
                       and CZX_AIG3_COUNTER.cav_shot[ep.role]) or 0
        local score = bonus * 3 - d
        if score > bs then best, bs = en, score end
    end
    if not best then return end
    local ok_r, rng = pcall(function() return unit:missile_range() end)
    rng = (ok_r and is_number(rng) and rng > 0) and rng or 100
    local d_best = dist_xz(unit, best)
    if d_best > rng * CONFIG.skirmish_engage_mult then
        -- close to ~70% of range toward the preferred target
        local ok_u, upos = pcall(function() return unit:position() end)
        local ok_t, tpos = pcall(function() return best:position() end)
        if ok_u and upos and ok_t and tpos then
            local dx = tpos:get_x() - upos:get_x()
            local dz = tpos:get_z() - upos:get_z()
            local len = math.sqrt(dx * dx + dz * dz)
            if len > 1 then
                local want = rng * 0.7
                local step = math.min(len - want, 150)
                if step > 5 then
                    local ok_v, wp = pcall(function()
                        return v(upos:get_x() + dx / len * step,
                                 upos:get_z() + dz / len * step)
                    end)
                    if ok_v and wp then uc_move(su, unit, wp, now_ms, "hunt", true) end
                end
            end
        end
    end
end

-- guard: backline countercharge — anchored near the shooters/artillery that
-- are being threatened by enemy mobile units (flyers landing on gun crews is
-- the classic gunline death). Engage inside a leash, always return.
local function step_guard(c, uid, now_ms, ctx)
    local unit, su = c.unit, c.su
    local anchor = c.anchor
    if not anchor then release_claim(uid, true, "no-anchor") return end
    local ok_u, upos = pcall(function() return unit:position() end)
    if not (ok_u and upos) then return end
    local ok_d, d_anchor = pcall(function() return upos:distance_xz(anchor) end)
    if not (ok_d and d_anchor) then return end
    -- find the best enemy to engage: nearest to us, but never beyond leash
    local e, dist = nearest_enemy(unit, ctx.enemies)
    if e and dist <= CONFIG.guard_engage_m then
        local ok_e, ed = pcall(function() return e:position():distance_xz(anchor) end)
        if ok_e and ed and ed <= CONFIG.guard_leash_m then
            if uc_attack(su, unit, e, now_ms, "guard") then
                c.state = "fighting"
            end
            c.safe_since = nil
            return
        end
    end
    -- nothing in leash: drift back to anchor
    if d_anchor > CONFIG.guard_leash_m * 0.5 then
        uc_move(su, unit, anchor, now_ms, "guard-return", true)
        c.state = "returning"
    else
        c.state = "holding"
    end
    -- release when the backline has been safe for a while
    local ok_t, threat_near = pcall(function()
        for _, en in ipairs(ctx.enemies) do
            local ep = ctx.eprobes and ctx.eprobes[en]
            if ep and (ep.role == "flyer" or ep.role == "cav"
                       or ep.role == "cav_shot" or ep.role == "monster") then
                local ed = dist_xz(en, { position = function() return anchor end })
                if ed <= CONFIG.guard_trigger_m then return true end
            end
        end
        return false
    end)
    if ok_t and not threat_near then
        c.safe_since = c.safe_since or now_ms
        if (now_ms - c.safe_since) >= CONFIG.guard_release_s * 1000 then
            release_claim(uid, true, "backline-safe")
        end
    else
        c.safe_since = nil
    end
end

-- wounded: pull out to a rear anchor and stay parked until the mop-up phase;
-- if it heals back past the danger zone it rejoins the planner
local function step_wounded(c, uid, now_ms, ctx)
    local unit, su = c.unit, c.su
    local ok_hp, hp = pcall(function() return unit:unary_hitpoints() end)
    if ok_hp and is_number(hp) and hp > CONFIG.wounded_hp + 0.2 then
        release_claim(uid, true, "healed")
        return
    end
    local anchor = c.anchor
    if not anchor then
        anchor = rear_anchor(ctx.ally_c, ctx.enemy_c, CONFIG.rear_offset_m)
        c.anchor = anchor
    end
    if not anchor then return end
    local ok_u, upos = pcall(function() return unit:position() end)
    if not (ok_u and upos) then return end
    local ok_d, d = pcall(function() return upos:distance_xz(anchor) end)
    if not (ok_d and d) then return end
    -- re-issue only if it never arrived or drifted far off the anchor —
    -- if the player grabbed it and walked it away, one failed re-observe keeps
    -- us from stomping their order every tick (they keep it after one move)
    if d > CONFIG.rear_offset_m * 0.6 then
        if c.refused then
            -- second drift after a confirmed park: either the player grabbed it
            -- (release to player, stay excluded) or it got dragged back into
            -- melee (release to AI — it is committed to the fight anyway)
            local ok_m, melee = pcall(function() return unit:is_in_melee() end)
            release_claim(uid, ok_m and melee == true,
                          melee and "dragged-in" or "player-took")
            return
        end
        if uc_move(su, unit, anchor, now_ms, "wounded-park", true) then
            c.refused = (c.state == "parked") -- a second drift = player hands
            c.state = "to_anchor"
        end
    else
        c.state = "parked"
    end
end

local DETACH_STEP = {
    charger = step_charger,
    skirmisher = step_skirmisher,
    wounded = step_wounded,
    guard = step_guard,
}

local function detach_pass(delegated, enemies, now_ms)
    local enemy_c = centroid(enemies)
    local ally_units = {}
    for _, d in ipairs(delegated) do
        ally_units[#ally_units + 1] = d.unit
    end
    -- claimed units are no longer in ai_list, so ally centroid must include them
    for uid, c in pairs(claims) do
        local ok_u, u = pcall(function() return c.unit end)
        if ok_u and u then ally_units[#ally_units + 1] = u end
    end
    local ally_c = centroid(ally_units)

    -- probes for enemy roles (counter-matrix scoring)
    local eprobes = {}
    for _, e in ipairs(enemies) do
        local p = probe_unit(e)
        eprobes[e] = { role = role_of(e, p.prof, p.ammo, p.speed, p.flies) }
    end

    local ctx = { enemies = enemies, eprobes = eprobes,
                  ally_c = ally_c, enemy_c = enemy_c }

    -- step existing claims; release the dead/routing, keep the rest
    for uid, c in pairs(claims) do
        local ok_u, unit = pcall(function() return c.unit end)
        local dead, routing = true, false
        if ok_u and unit then
            local ok_s, d = pcall(function() return is_shattered_or_dead(unit) end)
            dead = (not ok_s) or d == true
            if not dead then
                local ok_r, r = pcall(function() return unit:is_routing() end)
                routing = ok_r and r == true
            end
        end
        if dead then
            release_claim(uid, false, "gone")
        elseif routing then
            -- routing units ignore orders anyway; hand back so AIG3's
            -- pending-control flow picks them up again once rallied
            release_claim(uid, true, "routing")
        elseif pan_aigeneral.units_overridden
            and pan_aigeneral.units_overridden[uid] then
            release_claim(uid, false, "player-override")
        else
            pcall(DETACH_STEP[c.kind], c, uid, now_ms, ctx)
        end
    end

    -- recruit new claims up to the cap (wounded first — they are emergencies)
    local n_claimed = 0
    for _ in pairs(claims) do n_claimed = n_claimed + 1 end
    if n_claimed >= CONFIG.max_claimed then return end

    for _, pass in ipairs({ "wounded", "charger", "skirmisher" }) do
        for _, d in ipairs(delegated) do
            if n_claimed >= CONFIG.max_claimed then return end
            local uid = tostring(d.unit:unique_ui_id())
            -- claim key: nil = free; "aigeneral_pancake" = under the planner
            -- (claiming fires AIG3's release callback); anything else = another
            -- mod owns it — leave it alone
            local claim_key = modder_API_uc_manager:is_unit_claimed(uid)
            local cd = ntarget_cd[uid]
            if not claims[uid]
                and not (cd and (now_ms - cd) < 15000)
                and not pan_aigeneral:is_excluded_id(uid)
                and not (pan_aigeneral.units_overridden
                         and pan_aigeneral.units_overridden[uid])
                and (claim_key == nil or claim_key == "aigeneral_pancake")
                and detach_kind(d, now_ms) == pass then
                -- don't claim units still deep in our own backfield
                local e, dist = nearest_enemy(d.unit, enemies)
                if pass == "wounded" or (e and dist <= CONFIG.claim_engage_m) then
                    if claim_unit(d, pass) then
                        n_claimed = n_claimed + 1
                    end
                end
            end
        end
    end

    -- guard recruiting: enemy mobile units looming over our shooters/artillery
    -- -> borrow the nearest free melee unit to anchor near the backline
    if n_claimed < CONFIG.max_claimed then
        local threatened = {}
        for _, d in ipairs(delegated) do
            if d.role == "shooter" or d.role == "artillery" then
                for _, en in ipairs(enemies) do
                    local ep = eprobes[en]
                    if ep and (ep.role == "flyer" or ep.role == "cav"
                               or ep.role == "cav_shot" or ep.role == "monster")
                        and dist_xz(d.unit, en) <= CONFIG.guard_trigger_m then
                        threatened[#threatened + 1] = d.unit
                        break
                    end
                end
            end
        end
        if #threatened > 0 then
            local anchor = centroid(threatened)
            if anchor then
                -- prefer a melee unit not already fighting — pulling an engaged
                -- frontliner out of the line to babysit is worse than no guard
                local best, bd = nil, math.huge
                for _, d in ipairs(delegated) do
                    if d.role == "melee" then
                        local uid = tostring(d.unit:unique_ui_id())
                        if not claims[uid] then
                            local ok_m, melee = pcall(function()
                                return d.unit:is_in_melee()
                            end)
                            if ok_m and not melee then
                                local ok_p, upos = pcall(function()
                                    return d.unit:position()
                                end)
                                if ok_p and upos then
                                    local ok_dd, dd = pcall(function()
                                        return upos:distance_xz(anchor)
                                    end)
                                    if ok_dd and dd and dd < bd then
                                        best, bd = d, dd
                                    end
                                end
                            end
                        end
                    end
                end
                if best then
                    local uid = tostring(best.unit:unique_ui_id())
                    if claim_unit(best, "guard") then
                        claims[uid].anchor = anchor
                        n_claimed = n_claimed + 1
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------------------------
-- main tick
---------------------------------------------------------------------------------------------

local function tick()
    if not CONFIG.enabled then return end
    -- deployment phase: the player is arranging the army — no orders at all
    local ok_dp, deploy_phase = pcall(function() return bm:is_deployment_phase() end)
    if ok_dp and deploy_phase then return end
    -- after VictoryCountdown AIG3 releases the planner and runs its own UC
    -- chasing script — hand our claimed units back so the chasing system can
    -- use them, then stand down completely, casts included (a same-tick
    -- cast+order pair is what raced maneuver abilities into sim deadlocks)
    if pan_aigeneral.current_phase >= pan_util.MOCK_VICTORY_COUNTDOWN then
        release_all_claims(true, "victory-countdown")
        return
    end

    local now_ms = bm:time_elapsed_ms()
    local delegated = collect_delegated()
    if #delegated == 0 then
        directive_doc = nil -- reset hysteresis so the next delegation re-plans
        if CONFIG.detach and next(claims) then
            -- everything we own is claimed-by-us or dead — keep stepping the
            -- detachments even with no planner-held units left
            detach_pass(delegated, collect_enemies(), now_ms)
        end
        return
    end
    if not started_logged then
        started_logged = true
        plog("delegated units=" .. #delegated)
    end

    local enemies = collect_enemies()

    -- contact bookkeeping for stalemate creep
    local planner = pan_aigeneral.player_ai
    local ok_cp, cp = pcall(function()
        return planner and planner:get_centre_point() or nil
    end)
    if ok_cp and cp then
        for _, e in ipairs(enemies) do
            local ok_d, dist = pcall(function() return e:position():distance_xz(cp) end)
            if ok_d and dist and dist <= CONFIG.contact_range_m then
                last_contact_ms = now_ms
                break
            end
        end
    end

    -- pass 1: doctrine directive (field battles only)
    if CONFIG.directives and battle_type_ok == nil then
        local ok_t, btype = pcall(function() return bm:battle_type() end)
        battle_type_ok = (ok_t and btype and CONFIG.directive_types[btype]) and true or false
        dlog("battle_type=" .. tostring(ok_t and btype) .. " directives=" .. tostring(battle_type_ok))
    end
    if CONFIG.directives and battle_type_ok and pan_aigeneral.player_ai then
        local n_shooters, n_mobile = 0, 0
        for _, d in ipairs(delegated) do
            if d.role == "shooter" or d.role == "artillery" or d.role == "cav_shot" then
                n_shooters = n_shooters + 1
            end
            if d.role == "cav" or d.role == "cav_shot" or d.role == "flyer" then
                n_mobile = n_mobile + 1
            end
        end
        local doctrine = pick_doctrine(delegated, n_shooters, n_mobile)
        if doctrine ~= directive_doc then
            dlog("doctrine -> " .. doctrine
                .. " (delegated=" .. #delegated .. " shooters=" .. n_shooters
                .. " mobile=" .. n_mobile .. ")")
        end
        issue_directive(now_ms, doctrine, delegated, enemies)
    end

    -- pass 2: auto-ability on delegated units
    if CONFIG.auto_cast then
        cast_pass(delegated, enemies, now_ms)
    end

    -- pass 2.5: skirmish flags on foot shooters (uc flag toggle, no claims)
    if CONFIG.skirmish_manage then
        skirmish_pass(delegated, enemies, now_ms)
    end

    -- pass 3: detachments (claim-based micro; runs even when the cap is full —
    -- it also steps and releases existing claims)
    if CONFIG.detach and uc_ok then
        detach_pass(delegated, enemies, now_ms)
    end
end

-- pcall wrap: a bare error inside a battle repeat_callback kills the timer
-- pump's singleshot re-arm and silently paralyses every scripted timer on the
-- field (v2 lesson, confirmed in script_log_180926_2156.txt)
bm:repeat_callback(function()
    local ok, err = pcall(tick)
    if not ok then plog("ERROR tick " .. tostring(err)) end
end, CONFIG.tick_ms, "czx_aig3_plus_tick")
