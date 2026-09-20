-- Diagnostic: dump army AP / stance / suspect effect bundles when a human
-- character is selected or a human faction turn starts.

local function czx_mv_out(msg)
    out("[czx_move] " .. msg)
end

local CZX_MV_SUSPECT_BUNDLES = {
    "psw_xnm_ycks_effect_bundle",
    "psw_moyin_wenyi",
    "psw_moyin_zaie",
}

local function czx_mv_dump(character, tag)
    local ok, err = pcall(function()
        if not character or character:is_null_interface() then return end
        if not character:has_military_force() then return end
        local mf = character:military_force()
        if not mf or mf:is_null_interface() then return end

        local ap = character:action_points_remaining_percent()
        local stance = "?"
        local oks, sv = pcall(function() return mf:active_stance() end)
        if oks and sv then stance = sv end

        local ft = "?"
        local okf, fv = pcall(function() return mf:force_type():key() end)
        if okf and fv then ft = fv end

        local units = "?"
        local oku, uv = pcall(function() return mf:unit_list():num_items() end)
        if oku then units = tostring(uv) end

        local bundles = {}
        for _, b in ipairs(CZX_MV_SUSPECT_BUNDLES) do
            local okb, bv = pcall(function() return mf:has_effect_bundle(b) end)
            if okb and bv then table.insert(bundles, b) end
            local okb2, bv2 = pcall(function() return character:has_effect_bundle(b) end)
            if okb2 and bv2 then table.insert(bundles, b .. "(char)") end
        end

        czx_mv_out(tag
            .. " cqi=" .. character:command_queue_index()
            .. " sub=" .. tostring(character:character_subtype_key())
            .. " faction=" .. tostring(character:faction():name())
            .. " AP=" .. tostring(ap)
            .. " stance=" .. stance
            .. " force_type=" .. ft
            .. " units=" .. units
            .. " in_settlement=" .. tostring(character:in_settlement())
            .. " bundles=" .. table.concat(bundles, ","))
    end)
    if not ok then czx_mv_out(tag .. " err: " .. tostring(err)) end
end

core:add_listener(
    "czx_mv_char_selected",
    "CharacterSelected",
    function(context)
        local c = context:character()
        return c and not c:is_null_interface() and c:faction():is_human()
    end,
    function(context) czx_mv_dump(context:character(), "selected") end,
    true
)

core:add_listener(
    "czx_mv_turn_start",
    "FactionTurnStart",
    function(context) return context:faction():is_human() end,
    function(context)
        local faction = context:faction()
        local cl = faction:character_list()
        for i = 0, cl:num_items() - 1 do
            local c = cl:item_at(i)
            if cm:char_is_general_with_army(c) then
                czx_mv_dump(c, "turn_start")
            end
        end
    end,
    true
)

czx_mv_out("loaded")
