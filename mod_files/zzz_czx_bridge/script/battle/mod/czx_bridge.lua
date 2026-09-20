---------------------------------------------------------------------------------------------
-- czx_bridge.lua — czx_bridge T1 telemetry agent (v0.1)
-- Streams battle state snapshots and diff-derived events to a JSONL file that an external
-- daemon tails (see czx_bridge/app/bridge_daemon.py).
--
-- READ-ONLY BY DESIGN: this script never issues orders, never calls a unitcontroller,
-- never changes selection or behaviour flags. Every engine call is pcall-guarded and the
-- whole tick is xpcall-wrapped; if file IO fails it degrades to out() with a "CZXB|"
-- prefix, and if the tick errors it logs and keeps going (or disables itself after
-- repeated failures). Zero gameplay impact is the contract.
--
-- Protocol: one JSON object per line. kinds = hello | snap | evt | bye. v = 1.
---------------------------------------------------------------------------------------------

local CONFIG = {
    enabled    = true,
    poll_ms    = 1000,                        -- snapshot cadence (ms)
    path       = "czx_bridge_telemetry.jsonl",-- game-dir relative (RLH/AI General precedent)
    also_out   = false,                       -- mirror every line to the script log (debug)
    extended   = true,                        -- emit orders/target/fatigue/visibility fields
}

if not CONFIG.enabled then return end
if not bm then return end -- battle_manager global missing -> nothing we can do

---------------------------------------------------------------------------------------------
-- environment probe (this doubles as the sandbox capability report for the bridge docs)
---------------------------------------------------------------------------------------------
local caps = {
    io       = (type(io) == "table" and type(io.open) == "function"),
    os_time  = (type(os) == "table" and type(os.time) == "function"),
    os_clock = (type(os) == "table" and type(os.clock) == "function"),
}

local function wall_time()
    if caps.os_time then
        local ok, v = pcall(os.time)
        if ok and v then return v end
    end
    return nil
end

local function clock_s()
    if caps.os_clock then
        local ok, v = pcall(os.clock)
        if ok and v then return v end
    end
    return nil
end

---------------------------------------------------------------------------------------------
-- output sink
---------------------------------------------------------------------------------------------
local out_file = nil
local io_dead  = false

local function try_open()
    if not caps.io or io_dead then return false end
    local ok, f = pcall(io.open, CONFIG.path, "w")
    if ok and f then
        out_file = f
        return true
    end
    io_dead = true
    out("CZXB|io.open failed for " .. CONFIG.path .. " - degrading to script log")
    return false
end

local function emit(line)
    if CONFIG.also_out or io_dead then
        out("CZXB|" .. line)
    end
    if io_dead then return end
    if not out_file and not try_open() then return end
    local ok, err = pcall(function()
        out_file:write(line, "\n")
        out_file:flush()
    end)
    if not ok then
        io_dead = true
        if out_file then pcall(function() out_file:close() end) end
        out("CZXB|write failed (" .. tostring(err) .. ") - degrading to script log")
        out("CZXB|" .. line)
    end
end

---------------------------------------------------------------------------------------------
-- tiny JSON writers (flat records only; all strings escaped)
---------------------------------------------------------------------------------------------
local function num(v, dp)
    if type(v) ~= "number" or v ~= v then return "null" end -- NaN guard
    if dp then return string.format("%." .. dp .. "f", v) end
    return tostring(v)
end

local function jstr(s)
    if s == nil then return "null" end
    return '"' .. tostring(s):gsub('([%c"\\])', function(c)
        if c == '"' then return '\\"' end
        if c == '\\' then return '\\\\' end
        return string.format('\\u%04x', string.byte(c))
    end) .. '"'
end

local function bool(v)
    if v == nil then return "null" end
    return v and "true" or "false"
end

-- call u:<method>() under pcall; nil on any failure
local function probe(u, m)
    local ok, v = pcall(function() return u[m](u) end)
    if ok then return v end
    return nil
end

local function vec3(v, dp)
    if not v then return "null" end
    local ok, x, y, z = pcall(function()
        return v:get_x(), v:get_y(), v:get_z()
    end)
    if ok and x then
        return "[" .. num(x, dp) .. "," .. num(y, dp) .. "," .. num(z, dp) .. "]"
    end
    return jstr(tostring(v))
end

---------------------------------------------------------------------------------------------
-- unit snapshot
---------------------------------------------------------------------------------------------
local FLAG_PROBES = { -- {char, method}
    { "i", "is_idle" }, { "r", "is_routing" }, { "w", "is_wavering" },
    { "s", "is_shattered" }, { "m", "is_in_melee" }, { "a", "is_under_attack" },
    { "A", "is_under_missile_attack" }, { "f", "is_currently_flying" },
    { "h", "is_hidden" }, { "p", "is_rampaging" }, { "c", "is_controllable" },
    { "d", "is_deployed" },
}

local function unit_json(u, ai, ar)
    local parts = { '"u":' .. num(probe(u, "unique_ui_id")) }
    parts[#parts + 1] = '"k":' .. jstr(probe(u, "type"))
    parts[#parts + 1] = '"al":' .. num(ai)
    parts[#parts + 1] = '"ar":' .. num(ar)
    parts[#parts + 1] = '"pos":' .. vec3(probe(u, "position"), 1)
    parts[#parts + 1] = '"br":' .. num(probe(u, "bearing"), 1)
    parts[#parts + 1] = '"w":' .. num(probe(u, "width"), 1)
    parts[#parts + 1] = '"hp":' .. num(probe(u, "unary_hitpoints"), 3)
    parts[#parts + 1] = '"men":' .. num(probe(u, "number_of_men_alive"))
    parts[#parts + 1] = '"men0":' .. num(probe(u, "initial_number_of_men"))
    parts[#parts + 1] = '"sv":' .. num(probe(u, "strategic_value"))

    local fl = {}
    for _, fp in ipairs(FLAG_PROBES) do
        if probe(u, fp[2]) == true then fl[#fl + 1] = fp[1] end
    end
    parts[#parts + 1] = '"fl":"' .. table.concat(fl) .. '"'

    local ctrl = "?"
    if probe(u, "is_script_controlled") == true then ctrl = "s"
    elseif probe(u, "is_ai_controlled") == true then ctrl = "a"
    elseif probe(u, "is_player_controlled") == true then ctrl = "p" end
    parts[#parts + 1] = '"c":"' .. ctrl .. '"'

    if CONFIG.extended then
        parts[#parts + 1] = '"ammo":' .. num(probe(u, "ammo_left"))
        parts[#parts + 1] = '"rng":' .. num(probe(u, "missile_range"))
        parts[#parts + 1] = '"spd":' .. num(probe(u, "fast_speed"))
        parts[#parts + 1] = '"fat":' .. jstr(probe(u, "fatigue_state"))
        parts[#parts + 1] = '"vis":' .. bool(probe(u, "is_visible_to_alliance"))
        parts[#parts + 1] = '"lord":' .. bool(probe(u, "is_commanding_unit"))
        local ok, tv = pcall(function()
            local t = u:current_target()
            if t then return t:unique_ui_id() end
            return nil
        end)
        parts[#parts + 1] = '"tg":' .. ((ok and tv) and num(tv) or "null")
        local ok2, op = pcall(function() return u:ordered_position() end)
        parts[#parts + 1] = '"ord":' .. ((ok2 and op) and vec3(op, 1) or "null")
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

---------------------------------------------------------------------------------------------
-- state + diff events
---------------------------------------------------------------------------------------------
local state = {
    phase   = "load",
    tick_n  = 0,
    prev    = {},  -- uid -> { m=bool, r=bool, s=bool }
    err_n   = 0,
    done    = false,
}

local function evt(t, name, fields)
    emit('{"v":1,"kind":"evt","t":' .. num(t) .. ',"ph":' .. jstr(state.phase)
        .. ',"e":' .. jstr(name) .. (fields and fields ~= "" and ("," .. fields) or "") .. "}")
end

local function flag_has(fl, ch)
    return fl and fl:find(ch, 1, true) ~= nil
end

local function snapshot()
    local now_ms = 0
    pcall(function() now_ms = bm:time_elapsed_ms() end)
    local rows, cur = {}, {}
    local n_a, n_s, n_p = 0, 0, 0

    local ok, err = pcall(function()
        local alls = bm:alliances()
        if not alls then return end
        for ai = 1, alls:count() do
            local al = alls:item(ai)
            local ok_al = pcall(function() return al:is_null_interface() end)
            if al and ok_al ~= true then
                local armies = al:armies()
                if armies then
                    for ar = 1, armies:count() do
                        local units = armies:item(ar):units()
                        if units then
                            for ui = 1, units:count() do
                                local u = units:item(ui)
                                if u then
                                    local ok_u, row = pcall(unit_json, u, ai, ar)
                                    if ok_u and row then
                                        rows[#rows + 1] = row
                                        local uid = probe(u, "unique_ui_id")
                                        if uid then
                                            local fl = row:match('"fl":"([^"]*)"') or ""
                                            cur[uid] = { m = flag_has(fl, "m"), r = flag_has(fl, "r"), s = flag_has(fl, "s") }
                                            local c = row:match('"c":"([^"]*)"')
                                            if c == "a" then n_a = n_a + 1
                                            elseif c == "s" then n_s = n_s + 1
                                            elseif c == "p" then n_p = n_p + 1 end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    if not ok then
        state.err_n = state.err_n + 1
        evt(now_ms, "snap_error", '"msg":' .. jstr(err) .. ',"n":' .. num(state.err_n))
        return
    end

    emit('{"v":1,"kind":"snap","t":' .. num(now_ms) .. ',"ph":' .. jstr(state.phase)
        .. ',"n":' .. num(#rows)
        .. ',"ctrl":{"a":' .. num(n_a) .. ',"s":' .. num(n_s) .. ',"p":' .. num(n_p) .. '}'
        .. ',"units":[' .. table.concat(rows, ",") .. "]}")
    state.tick_n = state.tick_n + 1

    -- diff events (transition-based; v0.1 set: melee engage, routing, shattered, gone)
    for uid, c in pairs(cur) do
        local p = state.prev[uid]
        if p then
            if c.m and not p.m then evt(now_ms, "engaged", '"u":' .. num(uid)) end
            if c.r and not p.r then evt(now_ms, "routing", '"u":' .. num(uid)) end
            if c.s and not p.s then evt(now_ms, "shattered", '"u":' .. num(uid)) end
        end
    end
    for uid, _ in pairs(state.prev) do
        if not cur[uid] then evt(now_ms, "unit_gone", '"u":' .. num(uid)) end
    end
    state.prev = cur
end

---------------------------------------------------------------------------------------------
-- lifecycle
---------------------------------------------------------------------------------------------
local TICK_NAME = "czx_bridge_tick"

local function shutdown(reason)
    if state.done then return end
    state.done = true
    pcall(function() bm:remove_process(TICK_NAME) end)
    local now_ms = 0
    pcall(function() now_ms = bm:time_elapsed_ms() end)
    evt(now_ms, "bye", '"reason":' .. jstr(reason) .. ',"ticks":' .. num(state.tick_n))
    if out_file then pcall(function() out_file:close() end) out_file = nil end
end

local function tick_wrapped()
    if state.done then return end
    local t0 = clock_s()
    local ok, err = xpcall(snapshot, function(e) return tostring(e) end)
    if not ok then
        state.err_n = state.err_n + 1
        evt(0, "tick_error", '"msg":' .. jstr(err) .. ',"n":' .. num(state.err_n))
        if state.err_n >= 10 then shutdown("too_many_errors") end
        return
    end
    local t1 = clock_s()
    if t0 and t1 and (t1 - t0) > 0.25 then
        pcall(function()
            evt(bm:time_elapsed_ms(), "slow_tick", '"ms":' .. num((t1 - t0) * 1000))
        end)
    end
end

-- phase tracking: engine fires register_phase_change_callback on transitions;
-- phases evidenced in community mods: Startup, PrebattleWeather, Deployment,
-- Deployed, VictoryCountdown, Complete.
for _, ph in ipairs({ "Startup", "PrebattleWeather", "Deployment", "Deployed",
                      "VictoryCountdown", "Complete" }) do
    pcall(function()
        bm:register_phase_change_callback(ph, function()
            state.phase = ph
            local now_ms = 0
            pcall(function() now_ms = bm:time_elapsed_ms() end)
            evt(now_ms, "phase", '"to":' .. jstr(ph))
            if ph == "Complete" then shutdown("battle_complete") end
        end)
    end)
end

-- hello: session header with capability report (the sandbox probe result)
do
    local now_ms = 0
    pcall(function() now_ms = bm:time_elapsed_ms() end)
    local btype, siege, replay, tut
    pcall(function() btype = bm:battle_type() end)
    pcall(function() siege = bm:is_siege_battle() end)
    pcall(function() replay = bm:is_replay() end)
    pcall(function() tut = bm:is_tutorial() end)
    emit('{"v":1,"kind":"hello","agent":"czx_bridge/0.1","t":' .. num(now_ms)
        .. ',"wall":' .. (wall_time() and num(wall_time()) or "null")
        .. ',"caps":{"io":' .. bool(caps.io)
        .. ',"os_time":' .. bool(caps.os_time)
        .. ',"os_clock":' .. bool(caps.os_clock) .. "}"
        .. ',"battle":{"type":' .. jstr(btype)
        .. ',"siege":' .. bool(siege)
        .. ',"replay":' .. bool(replay)
        .. ',"tutorial":' .. bool(tut) .. "}}")
end

local ok_reg, err_reg = pcall(function()
    bm:repeat_callback(tick_wrapped, CONFIG.poll_ms, TICK_NAME)
end)
if not ok_reg then
    evt(0, "register_failed", '"msg":' .. jstr(err_reg))
    shutdown("no_repeat_callback")
else
    out("CZXB|telemetry agent loaded, poll " .. CONFIG.poll_ms .. "ms -> " .. CONFIG.path)
end
