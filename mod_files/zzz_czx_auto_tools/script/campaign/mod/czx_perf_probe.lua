---------------------------------------------------------------------------------------------------
-- czx_perf_probe.lua
-- Profiles every core event listener (callback + condition) and dumps per-round totals
-- to czx_turn_profile.txt (game working dir) each WorldStartRound. Self-contained, read-only.
---------------------------------------------------------------------------------------------------

local PROFILE_FILE = "czx_turn_profile.txt"
local DUMP_TOP_N = 40

local stats = {} -- [listener_key] = {time=seconds, calls=int, event=string}
local round_idx = 0

local function rec_stat(name, event, dt)
    local s = stats[name]
    if not s then
        s = {time = 0, calls = 0, event = event}
        stats[name] = s
    end
    s.time = s.time + dt
    s.calls = s.calls + 1
end

local function wrap_rec(rec, event)
    if not is_table(rec) or rec.__czxp then return end
    rec.__czxp = true
    local name = tostring(rec.name or rec.listener_name or "?")
    if is_function(rec.callback) then
        local orig = rec.callback
        rec.callback = function(ctx)
            local t0 = os.clock()
            local r = orig(ctx)
            rec_stat(name .. "|cb", event, os.clock() - t0)
            return r
        end
    end
    if is_function(rec.condition) then
        local orig = rec.condition
        rec.condition = function(ctx)
            local t0 = os.clock()
            local r = orig(ctx)
            rec_stat(name .. "|cond", event, os.clock() - t0)
            return r
        end
    end
end

local function instrument()
    local wrapped = 0
    for event, list in pairs(core.event_listeners or {}) do
        if is_table(list) then
            for _, r in ipairs(list) do
                if is_table(r) and not r.__czxp then
                    wrap_rec(r, event)
                    wrapped = wrapped + 1
                end
            end
        end
    end
    for lname, lll in pairs(core.all_lookup_listener_lists or {}) do
        if is_table(lll) then
            for _, records in pairs(lll) do
                if is_table(records) then
                    for _, r in pairs(records) do
                        if is_table(r) and not r.__czxp and is_function(r.callback) then
                            wrap_rec(r, tostring(lll.event_name or ("lookup:" .. lname)))
                            wrapped = wrapped + 1
                        end
                    end
                end
            end
        end
    end
    return wrapped
end

local function dump()
    local arr = {}
    local total = 0
    for name, s in pairs(stats) do
        arr[#arr + 1] = {name = name, time = s.time, calls = s.calls, event = s.event}
        total = total + s.time
    end
    table.sort(arr, function(a, b) return a.time > b.time end)

    local lines = {}
    lines[#lines + 1] = string.format("=== round %d | listeners total %.3fs | top %d ===", round_idx, total, DUMP_TOP_N)
    for i = 1, math.min(DUMP_TOP_N, #arr) do
        local e = arr[i]
        lines[#lines + 1] = string.format("%7.3fs  x%-6d %-18s %s", e.time, e.calls, e.event, e.name)
    end
    local text = table.concat(lines, "\n") .. "\n"

    local file = io.open(PROFILE_FILE, "a")
    if file then
        file:write(text)
        file:close()
    end
    out(">>> czx_perf >>> round " .. round_idx .. " listeners " .. string.format("%.3f", total) .. "s, top: " ..
        (#arr > 0 and (arr[1].name .. " " .. string.format("%.3f", arr[1].time) .. "s") or "none"))
end

instrument()
out(">>> czx_perf >>> probe loaded, wrapped " .. tostring(instrument()) .. " listeners")

core:add_listener(
    "czx_perf_probe_round",
    "WorldStartRound",
    true,
    function(context)
        round_idx = context:turn() or round_idx + 1
        instrument() -- pick up listeners registered during/after first tick
        if round_idx > 0 then
            dump()
        end
        stats = {}
    end,
    true
)
