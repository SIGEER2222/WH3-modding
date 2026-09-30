-- czx_auto_manage.lua
-- 自动管理：自动加点 / 自动建造（新地区） / 自动研究科技
-- 仅对玩家派系生效

--===========================================================
-- 级联安静窗门控（§10.40 +0x22c0f80 家族）
-- 回合开始/面板开合爆发期内做模型写（instantly_research_technology /
-- instantly_upgrade_building / force_add_skill）会与 vanilla 事件面板
-- 构建互踩：events 面板 mission_review 构建时引擎自选 tab_details，
-- 点击回调读半构建 context = null+0x58 读崩（09-29 13:19 dump,
-- schwartzhafen T4：研究写与 Panel opened events 同拍 145.1s）。
-- 判据 = 非 ui_locked + 无 blocking 面板 + 连续 2 个 0.5s 拍无新
-- PanelOpenedCampaign。面板长开不挡——只挡"正在开合"的窗。
--===========================================================
local czx_panel_seq = 0
core:remove_listener("czx_auto_panel_stamp")
core:add_listener(
    "czx_auto_panel_stamp",
    "PanelOpenedCampaign",
    true,
    function() czx_panel_seq = czx_panel_seq + 1 end,
    true
)

local function czx_ui_busy()
    local ok, uim = pcall(function() return cm:get_campaign_ui_manager() end)
    if not ok or not uim then return true end
    if uim.ui_locked then return true end
    local ok_bp, bp = pcall(function() return uim:get_open_blocking_panel() end)
    if ok_bp and bp then return true end
    return false
end

-- fn 推迟到安静窗执行：无锁无 blocking 面板且 ~1s 内无新面板开合。
-- 兜底 40 拍（20s）仍不安静则照常跑——自动化不得被无限饿死。
local function czx_run_when_quiet(tag, fn)
    local last_seq = -1
    local stable = 0
    local polls = 0
    local cb_base = "czx_quiet_" .. tag
    local function probe()
        polls = polls + 1
        if czx_ui_busy() then
            stable = 0
            last_seq = czx_panel_seq
        elseif czx_panel_seq == last_seq then
            stable = stable + 1
        else
            last_seq = czx_panel_seq
            stable = 0
        end
        if stable >= 2 or polls >= 40 then
            if polls >= 40 and stable < 2 then
                ModLog("[czx_auto] " .. tag .. " ran at quiet cap (UI still churning)")
            end
            local ok, err = pcall(fn)
            if not ok then
                ModLog("[czx_auto] deferred " .. tag .. " failed: " .. tostring(err))
            end
            return
        end
        cm:real_callback(probe, 500, cb_base .. "_" .. polls)
    end
    cm:real_callback(probe, 500, cb_base .. "_0")
end

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
    -- 注意：字段名必须与 gamedata/ui/metadata.json 的 CcoCampaignCharacter 符号一致，
    -- 正确名是 SkillPointsAvailable（不是 SkillPointsToSpend）；pcall 吞错会让点数
    -- 静默变 0，所以调用失败要打日志，不能默走。
    local skill_points = 0
    local ok_sp, sp_result = pcall(function() return char_ctx:Call("SkillPointsAvailable") end)
    if ok_sp and sp_result ~= nil then
        skill_points = tonumber(sp_result) or 0
    else
        ModLog("[czx_auto] SkillPointsAvailable call failed on char " .. tostring(char_cqi))
        return
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
        -- 技能项上没有 MaxLevel，正确名是 TotalLevels
        local ok_max, max_level = pcall(function() return char_ctx:Call("SkillList.At(" .. i .. ").TotalLevels") end)
        -- Status: available / complete / locked —— locked 技能 force_add_skill 会绕过前置
        local ok_st, skill_status = pcall(function() return char_ctx:Call("SkillList.At(" .. i .. ").Status") end)

        if ok_key and skill_key and ok_ind and skill_indent and ok_lvl and ok_max then
            local indent = tonumber(skill_indent) or 0
            local level = tonumber(skill_level) or 0
            local max_lvl = tonumber(max_level) or 0
            -- 只处理 indent 1-6 且状态为 available 的普通技能
            if indent >= 1 and indent <= 6 and level < max_lvl
                and (not ok_st or skill_status == "available") then
                cm:force_add_skill(char_str, skill_key)
                spent = spent + 1
                ModLog("[czx_auto] auto-leveled skill " .. tostring(skill_key) .. " on char " .. tostring(char_cqi))
            end
        end
    end
    ModLog("[czx_auto] spent " .. tostring(spent) .. " skill points on char " .. tostring(char_cqi))
end

-- 事件触发瞬间技能点可能尚未入账，延迟重试一次；且须等级联安静窗
-- （force_add_skill 是模型写，撞面板构建窗 = +0x22c0f80 读崩家族）
local function czx_auto_level_deferred(char_cqi)
    cm:callback(function()
        czx_run_when_quiet("level_" .. tostring(char_cqi), function()
            local character = cm:get_character_by_cqi(char_cqi)
            if character and not character:is_null_interface() then
                czx_auto_level_character(character)
            end
        end)
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
        -- 不内联跑 CCO 读取：CharacterCreated/RankUp 派发期角色 wrapper 正在重建，
        -- 与 sweep 同理（见下注释），统一走 1s 延迟复查。
        czx_auto_level_deferred(context:character():command_queue_index())
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
        czx_auto_level_deferred(context:character():command_queue_index())
    end,
    true
)

-- 每回合兜底扫描：覆盖存量角色未消耗的技能点
-- 注意：不在事件派发内直接跑——FactionTurnStart 回调期角色/世界对象正在重组，
-- character_list()/CCO 原生调用命中半销毁对象 = 原生崩溃（pcall 兜不住）。
-- 用 real_callback 推迟 3s 墙钟出级联窗口再跑。
core:remove_listener("czx_auto_skill_sweep")
core:add_listener(
    "czx_auto_skill_sweep",
    "FactionTurnStart",
    function(context)
        local faction = context:faction()
        return faction and not faction:is_null_interface() and faction:is_human()
    end,
    function(context)
        local faction_name = context:faction():name()
        cm:real_callback(function()
            czx_run_when_quiet("skill_sweep", function()
                local faction = cm:get_faction(faction_name)
                if not faction or faction == false or faction:is_null_interface() then return end
                local ok, chars = pcall(function() return faction:character_list() end)
                if not ok or not chars then return end
                for i = 0, chars:num_items() - 1 do
                    local ch = chars:item_at(i)
                    if ch and not ch:is_null_interface() then
                        czx_auto_level_character(ch)
                    end
                end
            end)
        end, 3000, "czx_auto_skill_sweep")
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
        -- 地区易主发生在占领结算级联内，instantly_upgrade_building 内联写模型
        -- 撞 UI/character 重建 = UAF 写族（§10.40）。延迟 1s + 安静窗再查再建。
        local region_name = context:region():name()
        cm:callback(function()
            czx_run_when_quiet("build_" .. region_name, function()
                local r = cm:get_region(region_name)
                if r and not r:is_null_interface() then
                    czx_auto_build_in_region(r, r:owning_faction())
                end
            end)
        end, 1.0)
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

    -- CcoCampaignFaction 上可用科技只有 TechnologyList；元素是 CcoCampaignTechnology，
    -- key 字段叫 NodeKey、已研究标志叫 IsResearched（不是 Key/Researched）
    local tech_key = nil
    local ok5, total = pcall(function() return faction_ctx:Call("TechnologyList.Size") end)
    if ok5 and total and tonumber(total) and tonumber(total) > 0 then
        for i = 0, tonumber(total) - 1 do
            local ok6, key = pcall(function() return faction_ctx:Call("TechnologyList.At(" .. i .. ").NodeKey") end)
            local ok7, researched = pcall(function() return faction_ctx:Call("TechnologyList.At(" .. i .. ").IsResearched") end)
            local ok8, can = pcall(function() return faction_ctx:Call("TechnologyList.At(" .. i .. ").CanResearch") end)
            if ok6 and key and ok7 and researched == false and (not ok8 or can == true) then
                tech_key = key
                break
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
        -- 同 sweep：FactionTurnStart 派发内联跑 instantly_research_technology /
        -- grant_research_points 是模型写，与角色 wrapper 重建相撞 = UAF 写；
        -- 且 instantly_research 会立刻产事件卡→events 面板构建→自选
        -- tab_details 点击读半构建 context = +0x22c0f80（09-29 13:19 dump）。
        -- 2s 墙钟后仍须过级联安静窗（面板开合拍稳定 ~1s）才落笔。
        local faction_name = context:faction():name()
        cm:real_callback(function()
            czx_run_when_quiet("research", function()
                local faction = cm:get_faction(faction_name)
                if faction and not faction:is_null_interface() then
                    czx_auto_research_technology(faction)
                end
            end)
        end, 2000, "czx_auto_research")
    end,
    true
)

ModLog("[czx_auto] v2 installed: auto-skill / auto-build / auto-research for player factions")

