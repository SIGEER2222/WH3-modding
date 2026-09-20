-- Diagnostic: trace elite/mercenary unit recruitment delivery.
-- Listens to UnitCreated / UnitTrained / RecruitmentItemIssuedByPlayer /
-- UnitDisbanded / UnitMergedAndDestroyed and dumps where each new unit lands.

-- 2026-09-19 崩溃排查后停用：过回合时 AI 征兵集中交付单回合 8000+ 条
-- UnitCreated，本探针每条再做约 10 次 pcall 原生接口调用，放大事件风暴。
-- 需要时把下面这行改成 true 即可恢复。
local CZX_DEBUG_RECRUIT_ENABLED = false
if not CZX_DEBUG_RECRUIT_ENABLED then
    out("[czx_recruit] disabled")
    return
end

local function czx_dr_out(msg)
    out("[czx_recruit] " .. msg)
end

local function czx_dr_char_info(char)
    if not char or char:is_null_interface() then
        return "char=nil"
    end
    local ok, s = pcall(function()
        local mf_str = "no_force"
        if char:has_military_force() then
            local mf = char:military_force()
            if not mf:is_null_interface() then
                local ft = "?"
                local okf, ftv = pcall(function() return mf:force_type():key() end)
                if okf and ftv then ft = ftv end
                local n = "?"
                local okn, nv = pcall(function() return mf:unit_list():num_items() end)
                if okn then n = tostring(nv) end
                mf_str = "force_type=" .. ft .. " units=" .. n
            end
        end
        local st = "?"
        local oks, sv = pcall(function() return char:character_subtype_key() end)
        if oks and sv then st = sv end
        return "char_cqi=" .. char:command_queue_index() .. " subtype=" .. st .. " " .. mf_str
    end)
    if ok then return s end
    return "char_info_err"
end

local function czx_dr_dump_unit(context, evname)
    local ok, err = pcall(function()
        local u = context:unit()
        if not u or u:is_null_interface() then
            czx_dr_out(evname .. ": unit null")
            return
        end
        local key = "?"
        local okk, kv = pcall(function() return u:unit_key() end)
        if okk and kv then key = kv end
        local src = "?"
        local oks2, sv2 = pcall(function() return u:recruitment_source_key() end)
        if oks2 and sv2 then src = sv2 end
        local fac = "?"
        local okf, fv = pcall(function() return u:faction():name() end)
        if okf and fv then fac = fv end
        local charinfo = "no_commander"
        local okc, cv = pcall(function()
            local c = u:force_commander()
            if c and not c:is_null_interface() then
                return czx_dr_char_info(c)
            end
            return "no_commander"
        end)
        if okc and cv then charinfo = cv end
        czx_dr_out(evname .. ": unit=" .. key .. " src=" .. src .. " faction=" .. fac .. " -> " .. charinfo)
    end)
    if not ok then
        czx_dr_out(evname .. " dump error: " .. tostring(err))
    end
end

core:add_listener(
    "czx_dr_unit_created",
    "UnitCreated",
    true,
    function(context) czx_dr_dump_unit(context, "UnitCreated") end,
    true
)

core:add_listener(
    "czx_dr_unit_trained",
    "UnitTrained",
    true,
    function(context) czx_dr_dump_unit(context, "UnitTrained") end,
    true
)

core:add_listener(
    "czx_dr_unit_disbanded",
    "UnitDisbanded",
    true,
    function(context) czx_dr_dump_unit(context, "UnitDisbanded") end,
    true
)

core:add_listener(
    "czx_dr_unit_merged",
    "UnitMergedAndDestroyed",
    true,
    function(context) czx_dr_dump_unit(context, "UnitMergedAndDestroyed") end,
    true
)

core:add_listener(
    "czx_dr_recruit_issued",
    "RecruitmentItemIssuedByPlayer",
    true,
    function(context)
        local ok, err = pcall(function()
            local key = "?"
            local okk, kv = pcall(function() return context:unit() end)
            if okk and kv then
                local okk2, kv2 = pcall(function() return kv:unit_key() end)
                if okk2 and kv2 then key = kv2 else key = tostring(kv) end
            end
            czx_dr_out("RecruitmentItemIssuedByPlayer: " .. key)
        end)
        if not ok then czx_dr_out("RecruitIssued dump error: " .. tostring(err)) end
    end,
    true
)

czx_dr_out("loaded")
