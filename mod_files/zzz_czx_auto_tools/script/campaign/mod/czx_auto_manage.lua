-- czx_auto_manage.lua
-- 自动管理：自动加点 / 自动建造（新地区） / 自动研究科技
-- 仅对玩家派系生效

--===========================================================
-- 1. 自动加点
--    监听 CharacterCreated 和 CharacterRankUp
--    使用 cm:force_add_skill 自动分配技能点
--===========================================================

local function czx_auto_level_character(character)
    if not character or character:is_null_interface() then return end
    local faction = character:faction()
    if not faction or not faction:is_null_interface() == false then return end
    if not faction:is_human() then return end

    local char_cqi = character:command_queue_index()
    local char_str = cm:char_lookup_str(character)
    ModLog("[czx_auto] checking character " .. tostring(char_cqi) .. " for auto-level")

    -- 使用 CCO 接口获取技能信息
    local char_ctx = cco("CcoCampaignCharacter", char_cqi)
    if not char_ctx then
        ModLog("[czx_auto] no CCO context for character " .. tostring(char_cqi))
        return
    end

    -- 获取当前未分配技能点
    local skill_points = 0
    local ok_sp, sp_result = pcall(function() return char_ctx:Call("SkillPointsToSpend") end)
    if ok_sp and sp_result then
        skill_points = tonumber(sp_result) or 0
    end
    ModLog("[czx_auto] character " .. tostring(char_cqi) .. " has " .. tostring(skill_points) .. " skill points")
    if skill_points <= 0 then return end

    -- 获取可用技能列表
    local num_skills = 0
    local ok_ns, ns_result = pcall(function() return char_ctx:Call("SkillList.Size") end)
    if ok_ns and ns_result then
        num_skills = tonumber(ns_result) or 0
    end
    if num_skills <= 0 then return end

    local spent = 0
    for i = 0, num_skills - 1 do
        if spent >= skill_points then break end
        local ok_key, skill_key = pcall(function() return char_ctx:Call("SkillList.At(" .. i .. ").Key") end)
        local ok_ind, skill_indent = pcall(function() return char_ctx:Call("SkillList.At(" .. i .. ").Indent") end)
        local ok_lvl, skill_level = pcall(function() return char_ctx:Call("SkillList.At(" .. i .. ").Level") end)
        local ok_max, max_level = pcall(function() return char_ctx:Call("SkillList.At(" .. i .. ").MaxLevel") end)

        if ok_key and skill_key and ok_ind and skill_indent and ok_lvl and ok_max then
            local indent = tonumber(skill_indent) or 0
            local level = tonumber(skill_level) or 0
            local max_lvl = tonumber(max_level) or 0
            -- 只处理 indent 1-6 的普通技能
            if indent >= 1 and indent <= 6 and level < max_lvl then
                cm:force_add_skill(char_str, skill_key)
                spent = spent + 1
                ModLog("[czx_auto] auto-leveled skill " .. tostring(skill_key) .. " on char " .. tostring(char_cqi))
            end
        end
    end
    ModLog("[czx_auto] spent " .. tostring(spent) .. " skill points on char " .. tostring(char_cqi))
end

-- 事件触发瞬间技能点可能尚未入账，延迟重试一次
local function czx_auto_level_deferred(char_cqi)
    cm:callback(function()
        local character = cm:get_character_by_cqi(char_cqi)
        if character and not character:is_null_interface() then
            czx_auto_level_character(character)
        end
    end, 1.0)
end

core:remove_listener("czx_auto_char_created")
core:add_listener(
    "czx_auto_char_created",
    "CharacterCreated",
    function(context)
        local character = context:character()
        if not character or character:is_null_interface() then return false end
        local faction = character:faction()
        return faction and not faction:is_null_interface() and faction:is_human()
    end,
    function(context)
        local character = context:character()
        czx_auto_level_character(character)
        czx_auto_level_deferred(character:command_queue_index())
    end,
    true
)

core:remove_listener("czx_auto_char_rankup")
core:add_listener(
    "czx_auto_char_rankup",
    "CharacterRankUp",
    function(context)
        local character = context:character()
        if not character or character:is_null_interface() then return false end
        local faction = character:faction()
        return faction and not faction:is_null_interface() and faction:is_human()
    end,
    function(context)
        local character = context:character()
        czx_auto_level_character(character)
        czx_auto_level_deferred(character:command_queue_index())
    end,
    true
)

--===========================================================
-- 2. 自动建造（新地区）
--    监听 RegionFactionChangeEvent
--===========================================================

local czx_auto_base_buildings = {
    ["wh_main_emp_empire"] = "wh_main_emp_settlement_minor",
    ["wh_main_dwf_dwarfs"] = "wh_main_dwf_settlement_minor",
    ["wh_main_grn_greenskins"] = "wh_main_grn_settlement_minor",
    ["wh_main_vmp_vampire_counts"] = "wh_main_vmp_settlement_minor",
    ["wh2_main_hef_high_elves"] = "wh2_main_hef_settlement_minor",
    ["wh2_main_def_dark_elves"] = "wh2_main_def_settlement_minor",
    ["wh2_main_skv_skaven"] = "wh2_main_skv_settlement_minor",
    ["wh2_dlc09_tmb_tomb_kings"] = "wh2_dlc09_tmb_settlement_minor",
    ["wh2_dlc11_cst_vampire_coast"] = "wh2_dlc11_cst_settlement_minor",
    ["wh3_main_cth_cathay"] = "wh3_main_cth_settlement_minor",
    ["wh3_main_ksl_kislev"] = "wh3_main_ksl_settlement_minor",
    ["wh3_main_kho_khorne"] = "wh3_main_kho_settlement_minor",
    ["wh3_main_nur_nurgle"] = "wh3_main_nur_settlement_minor",
    ["wh3_main_tze_tzeentch"] = "wh3_main_tze_settlement_minor",
    ["wh3_main_sla_slaanesh"] = "wh3_main_sla_settlement_minor",
    ["wh3_main_dae_daemons"] = "wh3_main_dae_settlement_minor",
    ["wh_dlc03_bst_beastmen"] = "wh_dlc03_bst_settlement_minor",
    ["wh_dlc05_wef_wood_elves"] = "wh_dlc05_wef_settlement_minor",
    ["wh3_main_ogr_ogre_kingdoms"] = "wh3_main_ogr_settlement_minor",
    ["wh3_dlc23_chd_chaos_dwarfs"] = "wh3_dlc23_chd_settlement_minor",
    ["wh_main_chs_chaos"] = "wh_main_chs_settlement_minor",
    ["wh_dlc08_nor_norsca"] = "wh_dlc08_nor_settlement_minor",
}

local function czx_auto_build_in_region(region, faction)
    if not region or region:is_null_interface() then return end
    if not faction or faction:is_null_interface() or not faction:is_human() then return end

    local settlement = region:settlement()
    if not settlement or settlement:is_null_interface() then return end

    local primary_slot = settlement:primary_slot()
    if not primary_slot or primary_slot:is_null_interface() then return end

    ModLog("[czx_auto] checking region " .. region:name() .. " for auto-build")

    if primary_slot:is_empty() then
        local culture = faction:culture()
        local building = czx_auto_base_buildings[culture]
        if building then
            cm:region_slot_instantly_upgrade_building(primary_slot, building)
            ModLog("[czx_auto] auto-built " .. building .. " in region " .. region:name())
        else
            ModLog("[czx_auto] no building mapping for culture " .. tostring(culture))
        end
    else
        ModLog("[czx_auto] primary slot not empty in " .. region:name())
    end
end

core:remove_listener("czx_auto_region_acquired")
core:add_listener(
    "czx_auto_region_acquired",
    "RegionFactionChangeEvent",
    function(context)
        local region = context:region()
        if not region or region:is_null_interface() then return false end
        local new_faction = region:owning_faction()
        return new_faction and not new_faction:is_null_interface() and new_faction:is_human()
    end,
    function(context)
        czx_auto_build_in_region(context:region(), context:region():owning_faction())
    end,
    true
)

--===========================================================
-- 3. 自动研究科技
--    监听 FactionTurnStart
--===========================================================

local function czx_auto_research_technology(faction)
    if not faction or faction:is_null_interface() or not faction:is_human() then return end
    if not faction:has_available_technologies() then return end

    local faction_name = faction:name()

    -- 如果正在研究，不干预
    if faction:is_currently_researching() then
        ModLog("[czx_auto] faction " .. faction_name .. " is already researching, skip")
        return
    end

    ModLog("[czx_auto] faction " .. faction_name .. " not researching, trying to auto-research")

    -- 使用 CCO 接口获取可用科技列表
    local faction_ctx = cco("CcoCampaignFaction", faction:command_queue_index())
    if not faction_ctx then
        ModLog("[czx_auto] no CCO context for faction " .. faction_name)
        -- fallback: 直接给予研究点数
        cm:grant_research_points(faction_name, 500)
        return
    end

    -- 尝试多种 CCO 路径获取可用科技
    local tech_key = nil

    -- 方法1：AvailableTechnologyList
    local ok1, size1 = pcall(function() return faction_ctx:Call("AvailableTechnologyList.Size") end)
    if ok1 and size1 and tonumber(size1) and tonumber(size1) > 0 then
        local ok2, key = pcall(function() return faction_ctx:Call("AvailableTechnologyList.At(0).Key") end)
        if ok2 and key then tech_key = key end
    end

    -- 方法2：ResearchableTechnologyList
    if not tech_key then
        local ok3, size2 = pcall(function() return faction_ctx:Call("ResearchableTechnologyList.Size") end)
        if ok3 and size2 and tonumber(size2) and tonumber(size2) > 0 then
            local ok4, key = pcall(function() return faction_ctx:Call("ResearchableTechnologyList.At(0).Key") end)
            if ok4 and key then tech_key = key end
        end
    end

    -- 方法3：TechnologyList 过滤
    if not tech_key then
        local ok5, total = pcall(function() return faction_ctx:Call("TechnologyList.Size") end)
        if ok5 and total and tonumber(total) and tonumber(total) > 0 then
            for i = 0, tonumber(total) - 1 do
                local ok6, key = pcall(function() return faction_ctx:Call("TechnologyList.At(" .. i .. ").Key") end)
                local ok7, researched = pcall(function() return faction_ctx:Call("TechnologyList.At(" .. i .. ").Researched") end)
                if ok6 and key and ok7 and researched == false then
                    tech_key = key
                    break
                end
            end
        end
    end

    if tech_key then
        cm:instantly_research_technology(faction_name, tech_key, false)
        ModLog("[czx_auto] auto-researched technology " .. tech_key .. " for " .. faction_name)
    else
        -- fallback: 给予研究点数
        cm:grant_research_points(faction_name, 500)
        ModLog("[czx_auto] no tech found, granted 500 research points to " .. faction_name)
    end
end

core:remove_listener("czx_auto_research")
core:add_listener(
    "czx_auto_research",
    "FactionTurnStart",
    function(context)
        return context:faction():is_human()
    end,
    function(context)
        czx_auto_research_technology(context:faction())
    end,
    true
)

ModLog("[czx_auto] v2 installed: auto-skill / auto-build / auto-research for player factions")

