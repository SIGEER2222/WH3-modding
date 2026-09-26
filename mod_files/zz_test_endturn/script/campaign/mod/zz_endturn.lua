-- [TEST] auto end-turn for AI-phase crash reproduction.
-- Waits for the campaign UI to settle, then clicks the end turn button once.
local function zzlog(msg)
    out("[zz_endturn] " .. tostring(msg))
end

cm:add_first_tick_callback(function()
    cm:callback(function()
        local root = core:get_ui_root()
        local candidates = {
            {"hud_campaign", "frame", "end_turn_docker", "button_end_turn"},
            {"hud_campaign", "end_turn_docker", "button_end_turn"},
            {"button_end_turn"}
        }
        for _, path in ipairs(candidates) do
            local uic = find_uicomponent(root, unpack(path))
            if uic then
                zzlog("found end turn button, clicking")
                pcall(function() uic:SimulateLClick() end)
                return
            end
        end
        zzlog("end turn button NOT found")
    end, 15)
end)

-- periodic heartbeat so we can tell the session was alive in the log
local ticks = 0
core:add_listener("zz_endturn_heartbeat", "RealTimeTrigger", true, function(context)
    return context and context.ticker == "standard_ui_ticker"
end, function()
    ticks = ticks + 1
    if ticks % 30 == 0 then
        zzlog("alive t+" .. tostring(ticks) .. "s")
    end
end, true)
