-- ============================================================================
-- zzzz_psw_doctrine.lua — 星巫战法轮转 + 抽卡收敛
--
-- 目的：收敛 PSW 每回合抽卡带来的无差别永久数值膨胀；把新增量改造成
-- 按派系文化定向、互斥可切换的"战法"效果；并把召唤英雄/无双/监狱/
-- Lin 集成战略接入同一水晶经济（受产量与成本约束，不白送）。
--
-- 设计要点（用户已确认：并入祈愿按钮、旧存档只设新规则不清存量）：
--   A. 收敛
--      1) 抽卡递增成本：已持天赋每 15 个，本抽额外 -1 共鸣水晶（耗尽为止）。
--      2) 天赋过载线性税：持有天赋 >45 后每超 1 个按统一税率缴"过载税"
--         （psw_dampen_t{n} 十位 + psw_dampen_u{m} 个位，超出部分封顶50），
--         覆盖天赋审计出的全部主增益线：攻防/武器威力/护甲/特保/士气/
--         远程与破甲伤害/移速/双抗/射程/法术冷却。
--   B. 战法轮转
--      - 祈愿槽位面板常驻一张「星巫战法」卡（新档第 5 槽位常驻；
--        旧档 4 槽位时利用天赋选完后的空槽位落位）。
--      - 点击战法卡 -> 战法困境：本命战法（按文化自动适配的推荐项）/
--        远击号令 / 坚壁号令 / 破军号令 / 更多号令（秘法/巨兽/联动/休整）。
--        全部战法均可自由选择，文化仅决定推荐项。战法效果为派系级效果包，
--        互斥、可随时更换，全部走 unit_set 定向被动（远击只buff远程、坚壁
--        只buff步兵近战等），不再全军无差别堆叠。
--   C. 联动（路由式，不耗水晶）：打开各 mod 原生入口，费用按各 mod
--      自身货币规则收取（金币/票券），缺席 mod 对应选项无效。
--      - 英灵召唤：锚定派系领袖后 summon_servant:dilemma_prize_draw（其
--        原生三档困境，金币 648/3240/6480 自收）
--      - 无双招贤：wyccc_wushuang_hero_lottery:open_panel（面板内自收国库）
--      - 集成战略：锚定将领 + integrated_strategies:dilemma_nodes +
--        按其规则自收 1 票券（无票券则选项无效）
--      - 狱政管理：SimulateLClick 其 wyccc_prison_entry_button（面板已开
--        则跳过避免误关）
--      - 魔女高塔：本mod自带试炼入口 psw_tower.enter（zzzz_psw_tower.lua）
--      - 战锤尖塔：SimulateLClick 其 button_adamrogue_phase_a_entry
--        （adamrogue RogueTotalWar 原生入口，缺席则无效）
--   D. AI 本命战法：全体存活非人类派系按自身文化获得对应的定向战法包
--      （与玩家同一套 unit_set 被动），AI 各派系保留自己的兵种特色，
--      而非反制玩家选择；叠加在 ai_difficulty_ramp 的每回合爬坡之上。
-- ============================================================================

local DOCT_LOG_PREFIX = "[psw_doct] "
local function psw_doct_log(msg)
    out(DOCT_LOG_PREFIX .. tostring(msg))
end

local function psw_doct_pcall(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        psw_doct_log(name .. " error: " .. tostring(err))
    end
    return ok
end

local DOCT_BUILDING = "psw_doct_menu"
local DOCT_MAIN_DILEMMA = "psw_dilemma_doct_main"
local DOCT_MORE_DILEMMA = "psw_dilemma_doct_more"
local DOCT_LINK_DILEMMA = "psw_dilemma_doct_link"
local DOCT_LINK2_DILEMMA = "psw_dilemma_doct_link2"

-- 战法效果包 key（互斥）
local DOCT_BUNDLES = {
    missile = "psw_doct_bundle_missile",
    bulwark = "psw_doct_bundle_bulwark",
    charge  = "psw_doct_bundle_charge",
    arcane  = "psw_doct_bundle_arcane",
    beast   = "psw_doct_bundle_beast",
}

local DOCT_BUNDLE_LIST = {}
for _, b in pairs(DOCT_BUNDLES) do
    DOCT_BUNDLE_LIST[#DOCT_BUNDLE_LIST + 1] = b
end

-- 派系文化 -> 本命战法
local DOCT_CULTURE_MAP = {
    -- 远击系
    wh_main_emp_empire = "missile",
    wh_main_dwf_dwarfs = "missile",
    wh3_main_cth_cathay = "missile",
    wh3_main_ksl_kislev = "missile",
    wh2_main_skv_skaven = "missile",
    wh2_dlc09_tmb_tomb_kings = "missile",
    wh2_dlc11_cst_vampire_coast = "missile",
    wh_dlc05_wef_wood_elves = "missile",
    wh3_main_chd_chaos_dwarfs = "missile",
    wh2_main_def_dark_elves = "missile",
    -- 近战/冲击系
    wh3_main_kho_khorne = "charge",
    wh_dlc08_nor_norsca = "charge",
    wh_main_grn_greenskins = "charge",
    wh3_main_ogr_ogre_kingdoms = "charge",
    wh_dlc03_bst_beastmen = "charge",
    wh_main_chs_chaos = "charge",
    wh3_main_sla_slaanesh = "charge",
    wh_main_brt_bretonnia = "charge",
    -- 魔法系
    wh3_main_tze_tzeentch = "arcane",
    wh2_main_lzd_lizardmen = "arcane",
    wh_main_vmp_vampire_counts = "arcane",
    wh2_main_hef_high_elves = "arcane",
    wh3_main_dae_daemons = "arcane",
    -- 巨兽系
    wh3_main_nur_nurgle = "beast",
}

local DOCT_COST_MAIN = 1          -- 战法激活/切换耗共鸣水晶
local DOCT_LINK_COSTS = { 0, 0, 0, 0 }  -- 路由式：打开原生入口，费用由各 mod 自收

local function psw_doct_resource(faction, key)
    if not faction or faction:is_null_interface() then return 0 end
    local ok, v = pcall(function()
        return faction:pooled_resource_manager():resource(key):value()
    end)
    if ok and type(v) == "number" then return v end
    return 0
end

local function psw_doct_player_data(faction_name)
    if type(psw_ensure_player_data) == "function" then
        psw_doct_pcall("ensure_pd", function() psw_ensure_player_data(faction_name) end)
    end
    if not psw_main_data or not psw_main_data.player_data then return nil end
    return psw_main_data.player_data[faction_name]
end

-- 初始化未完成（英雄选择/难度选择）时不允许玩战法，避免干扰首次流程
local function psw_doct_ready(faction_name)
    local pd = psw_doct_player_data(faction_name)
    if not pd then return false end
    if not pd.set_psw_hero_select then return false end
    local gd = psw_main_data.global_data
    if gd and not gd.set_psw_main_nandu_xz then return false end
    return true
end

local function psw_doct_talent_count(faction_name)
    local pd = psw_doct_player_data(faction_name)
    if not pd then return 0 end
    return (pd.nor_count or 0) + (pd.ex_count or 0)
end

local function psw_doct_archetype(faction_name)
    local faction = cm:get_faction(faction_name)
    if not faction or faction:is_null_interface() then return "bulwark" end
    local ok, culture = pcall(function() return faction:culture() end)
    return DOCT_CULTURE_MAP[ok and culture or ""] or "bulwark"
end

local function psw_doct_charge_gmsj(faction_name, amount)
    if amount <= 0 then return true end
    if psw_doct_resource(cm:get_faction(faction_name), "psw_main_gmsj") < amount then
        return false
    end
    cm:faction_add_pooled_resource(faction_name, "psw_main_gmsj", "psw_main_gmsj_event_bad", -amount)
    return true
end

-- ============================================================
-- 战法卡放置
-- 新档（5 槽位，本补丁追加了 slot_set_items 行）：卡常驻第 5 槽，
--   psw_main_only_dismantle_tf 只清理 0..3，不会被拆。
-- 旧档（4 槽位）：天赋选中后槽位清空，卡在 slot0 落位；下次抽卡
--   时该槽会被天赋覆盖，选中后再次落位。
-- ============================================================
function psw_doct_place_card(faction_name)
    if not psw_doct_ready(faction_name) then return end
    if type(psw_get_talent_slot_manager) ~= "function" then return end
    local fsm = psw_get_talent_slot_manager(faction_name)
    if not fsm or fsm:is_null_interface() then return end
    local slots = fsm:slots()
    if not slots then return end
    local n = slots:num_items()
    if n <= 0 then return end

    -- 天赋抽取只使用 0..jishu_xuanze-1（最多 3）号槽，索引 >=4 的槽位
    -- 是本补丁为战法卡追加的扩展位（slot_set_items 新行在枚举中的
    -- 位置不确定，遍历找第一个空的扩展位）。
    if n >= 5 then
        for i = 4, n - 1 do
            local slot = slots:item_at(i)
            if slot and not slot:is_null_interface() and not slot:has_building() then
                cm:foreign_slot_instantly_upgrade_building(slot, DOCT_BUILDING)
                psw_doct_log("doctrine card placed in slot " .. tostring(i + 1) .. " for " .. faction_name)
                return
            end
        end
        return
    end

    local slot0 = slots:item_at(0)
    if slot0 and not slot0:is_null_interface() and not slot0:has_building() then
        cm:foreign_slot_instantly_upgrade_building(slot0, DOCT_BUILDING)
        psw_doct_log("doctrine card placed in slot0 for " .. faction_name)
    end
end

-- ============================================================
-- AI 本命战法：按 AI 派系自己的文化适配对应战法包（与玩家
-- 同一套 unit_set 定向包），而非反制玩家选择。全体存活非
-- 人类派系参与，未映射文化给坚壁（通用防御）。
-- ============================================================
local function psw_doct_apply_ai_doctrines()
    local list = cm:model():world():faction_list()
    if not list then return end
    local counts = {}
    for i = 0, list:num_items() - 1 do
        local f = list:item_at(i)
        if f and not f:is_null_interface() and not f:is_human() and not f:is_dead() then
            local fname = f:name()
            local ok, culture = pcall(function() return f:culture() end)
            local doctrine = DOCT_CULTURE_MAP[ok and culture or ""] or "bulwark"
            for _, b in pairs(DOCT_BUNDLES) do
                if b ~= DOCT_BUNDLES[doctrine] then
                    cm:remove_effect_bundle(b, fname)
                end
            end
            -- 旧版 psw_ai_counter_* 迁移清理
            for k, _ in pairs(DOCT_BUNDLES) do
                cm:remove_effect_bundle("psw_ai_counter_" .. k, fname)
            end
            cm:apply_effect_bundle(DOCT_BUNDLES[doctrine], fname, 0)
            counts[doctrine] = (counts[doctrine] or 0) + 1
        end
    end
    local parts = {}
    for k, v in pairs(counts) do parts[#parts + 1] = k .. "=" .. v end
    psw_doct_log("ai doctrines applied: " .. table.concat(parts, ", "))
end

-- ============================================================
-- 战法切换（互斥）
-- ============================================================
local function psw_doct_apply(faction_name, doctrine)
    local faction = cm:get_faction(faction_name)
    if not faction or faction:is_null_interface() then return end
    for _, b in ipairs(DOCT_BUNDLE_LIST) do
        cm:remove_effect_bundle(b, faction_name)
    end
    local pd = psw_doct_player_data(faction_name)
    if pd then
        pd.psw_doct_current = doctrine or ""
    end
    if doctrine and DOCT_BUNDLES[doctrine] then
        cm:apply_effect_bundle(DOCT_BUNDLES[doctrine], faction_name, 0)
        psw_doct_log("doctrine applied: " .. doctrine .. " for " .. faction_name)
    else
        psw_doct_log("doctrine cleared for " .. faction_name)
    end
end

-- ============================================================
-- 联动祈愿实现（路由式：打开各 mod 原生入口，费用由各 mod
-- 按自身货币规则收取，本菜单不再收水晶）
-- ============================================================
local function psw_doct_link_servant(faction_name)
    if type(summon_servant) ~= "table" or type(summon_servant.dilemma_prize_draw) ~= "function" then
        return false, "summon_servant_missing"
    end
    local faction = cm:get_faction(faction_name)
    if not faction or faction:is_null_interface() then return false, "no_faction" end
    -- 与其按钮路径一致：先锚定角色再打开原生三档抽卡困境（金币自收）
    if faction:has_faction_leader() then
        summon_servant.character = faction:faction_leader()
    end
    psw_doct_pcall("servant_open", function()
        summon_servant:dilemma_prize_draw(faction)
    end)
    return true
end

local function psw_doct_link_wushuang(faction_name)
    local lot = wyccc_wushuang_hero_lottery
    if type(lot) ~= "table" or not lot.ready or type(lot.open_panel) ~= "function" then
        return false, "wyccc_lottery_missing"
    end
    -- 打开其原生抽奖面板（面板内按其自身国库费用结算）
    psw_doct_pcall("wyccc_panel", function() lot:open_panel() end)
    return true
end

-- 资源键是否存在（区别于"存在但为0"）
local function psw_doct_has_resource(faction, key)
    if not faction or faction:is_null_interface() then return false end
    local ok, v = pcall(function()
        return faction:pooled_resource_manager():resource(key):value()
    end)
    return ok and type(v) == "number"
end

local function psw_doct_link_lin(faction_name)
    -- 与其按钮路径一致：锚定将领 -> 打开节点菜单 -> 按其规则自收 1 票券
    local s = integrated_strategies
    if type(s) ~= "table" or type(s.dilemma_nodes) ~= "function" then
        return false, "lin_missing"
    end
    local faction = cm:get_faction(faction_name)
    if not faction or faction:is_null_interface() then return false, "no_faction" end
    local coupon_key = s.pr_coupon or "lin_all_coupon"
    if psw_doct_resource(faction, coupon_key) < 1 then
        return false, "no_coupon"
    end
    local general = nil
    local mfl = faction:military_force_list()
    if mfl and not mfl:is_empty() then
        local mf = mfl:item_at(0)
        if mf and mf:has_general() then
            general = mf:general_character()
        end
    end
    if not general and faction:has_faction_leader() then
        general = faction:faction_leader()
    end
    s.character = general
    psw_doct_pcall("lin_nodes", function()
        s:dilemma_nodes(faction)
        cm:faction_add_pooled_resource(
            faction_name, coupon_key, s.pr_factor_events or "events", -1)
    end)
    return true
end

local function psw_doct_link_prison(faction_name)
    if type(cross_culture_annex) ~= "table" then
        return false, "prison_missing"
    end
    -- 其 show_panel 是闭包局部函数不可外部调；改走 SimulateLClick
    -- 点击其 HUD 入口按钮（面板已打开则跳过，避免误关）
    local ok_ui, root = pcall(function() return core:get_ui_root() end)
    if not ok_ui or not root then return false, "no_ui" end
    local btn = find_uicomponent(root, "wyccc_prison_entry_button")
    if not btn then return false, "no_button" end
    psw_doct_pcall("prison_open", function()
        local panel = find_uicomponent(root, "wyccc_prison_panel")
        if panel and panel:Visible() then return end
        btn:SimulateLClick()
    end)
    return true
end

local function psw_doct_link_tower(faction_name)
    -- 魔女高塔：本mod自带试炼入口（无外部依赖），由 zzzz_psw_tower.lua 提供全局 psw_tower
    if type(psw_tower) ~= "table" or type(psw_tower.enter) ~= "function" then
        return false, "tower_missing"
    end
    local faction = cm:get_faction(faction_name)
    if not faction or faction:is_null_interface() then return false, "no_faction" end
    psw_doct_pcall("tower_enter", function()
        psw_tower.enter(faction)
    end)
    return true
end

local function psw_doct_link_spire(faction_name)
    -- 战锤尖塔（adamrogue）：无导出 API，SimulateLClick 其 HUD 入口按钮
    -- 该按钮由 adamrogue 脚本挂到 button_group_management，缺席即视为 mod 未启用
    local ok_ui, root = pcall(function() return core:get_ui_root() end)
    if not ok_ui or not root then return false, "no_ui" end
    local btn = find_uicomponent(root, "button_adamrogue_phase_a_entry")
    if not btn then return false, "spire_missing" end
    psw_doct_pcall("spire_open", function()
        btn:SimulateLClick()
    end)
    return true
end

local DOCT_LINK_FUNCS = {
    psw_doct_link_servant,
    psw_doct_link_wushuang,
    psw_doct_link_lin,
    psw_doct_link_prison,
}

-- 联动子菜单是否有至少一个可用后端（全缺席时不开子菜单，防止死菜单）
local function psw_doct_any_link_available(faction_name)
    if type(summon_servant) == "table" and type(summon_servant.dilemma_prize_draw) == "function" then
        return true
    end
    local lot = wyccc_wushuang_hero_lottery
    if type(lot) == "table" and lot.ready and type(lot.open_panel) == "function" then
        return true
    end
    if type(integrated_strategies) == "table" and type(integrated_strategies.dilemma_nodes) == "function" then
        return true
    end
    if type(cross_culture_annex) == "table" then
        return true
    end
    -- 魔女高塔为本mod自带入口，恒可用
    if type(psw_tower) == "table" and type(psw_tower.enter) == "function" then
        return true
    end
    -- adamrogue 战锤尖塔：脚本加载即导出该全局对象
    if type(adamrogue_reinforcement_battle) == "table" then
        return true
    end
    return false
end

local function psw_doct_do_link(faction_name, idx)
    local cost = DOCT_LINK_COSTS[idx] or 0
    if cost > 0 and psw_doct_resource(cm:get_faction(faction_name), "psw_main_gmsj") < cost then
        psw_doct_log("link aborted: not enough gmsj for " .. faction_name)
        return
    end
    local fn = DOCT_LINK_FUNCS[idx]
    if not fn then return end
    local ok, reason = fn(faction_name)
    if ok then
        if cost > 0 then
            psw_doct_charge_gmsj(faction_name, cost)
        end
        psw_doct_log("link #" .. tostring(idx) .. " done for " .. faction_name)
    else
        psw_doct_log("link #" .. tostring(idx) .. " unavailable: " .. tostring(reason))
    end
end

-- ============================================================
-- 抽卡递增成本 + 战法卡放置（包装 psw_main_pickup）
-- ============================================================
local function psw_doct_install_pickup_wrap()
    if type(psw_main_pickup) ~= "function" then
        psw_doct_log("psw_main_pickup missing, skip wrap")
        return
    end
    local _orig = psw_main_pickup
    psw_main_pickup = function(faction_name)
        local count = psw_doct_talent_count(faction_name)
        local pd = psw_main_data and psw_main_data.player_data
            and psw_main_data.player_data[faction_name] or nil
        -- psw_05 免费重抽路径置位 psw_repick_in_progress，跳过额外成本
        local in_repick = pd and pd.psw_repick_in_progress
        if not in_repick then
            local extra = math.floor(count / 15)
            if extra > 0 then
                local have = psw_doct_resource(cm:get_faction(faction_name), "psw_main_gmsj")
                local charge = math.min(extra, math.max(0, have))
                if charge > 0 then
                    cm:faction_add_pooled_resource(
                        faction_name, "psw_main_gmsj", "psw_main_gmsj_event_bad", -charge)
                    psw_doct_log("draw escalated cost: -" .. tostring(charge)
                        .. " extra gmsj (talents=" .. tostring(count) .. ") " .. faction_name)
                end
            end
        end
        return _orig(faction_name)
    end
    psw_doct_log("pickup wrap installed")
end

-- ============================================================
-- 过载衰减：线性税——超出 45 的每个天赋都按同一税率缴纳全军
-- 过载税（psw_dampen_t{n} 十位包 + psw_dampen_u{m} 个位包），
-- 超出部分封顶 50（等效旧 5 档上限）。不再按 10 档跳变。
-- ============================================================
local DOCT_DAMPEN_FREE = 45
local DOCT_DAMPEN_CAP = 50
local DOCT_DAMPEN_KEYS = {}
for i = 1, 5 do
    DOCT_DAMPEN_KEYS[#DOCT_DAMPEN_KEYS + 1] = "psw_dampen_t" .. i
    DOCT_DAMPEN_KEYS[#DOCT_DAMPEN_KEYS + 1] = "psw_dampen_" .. i  -- 旧版遗留包名，存档迁移
end
for i = 1, 9 do
    DOCT_DAMPEN_KEYS[#DOCT_DAMPEN_KEYS + 1] = "psw_dampen_u" .. i
end

local function psw_doct_apply_dampen(faction_name)
    local faction = cm:get_faction(faction_name)
    if not faction or faction:is_null_interface() or not faction:is_human() then return end
    local count = psw_doct_talent_count(faction_name)
    local over = math.max(0, math.min(DOCT_DAMPEN_CAP, count - DOCT_DAMPEN_FREE))
    for _, key in ipairs(DOCT_DAMPEN_KEYS) do
        cm:remove_effect_bundle(key, faction_name)
    end
    local tens, units = math.floor(over / 10), over % 10
    if tens > 0 then
        cm:apply_effect_bundle("psw_dampen_t" .. tens, faction_name, 0)
    end
    if units > 0 then
        cm:apply_effect_bundle("psw_dampen_u" .. units, faction_name, 0)
    end
    if over > 0 then
        psw_doct_log("overload linear tax: over=" .. over
            .. " (t" .. tens .. "+u" .. units .. ", talents=" .. count .. ") " .. faction_name)
    end
end

local function psw_doct_local_faction_name()
    local ok, name = pcall(function() return cm:get_local_faction_name(true) end)
    if ok and type(name) == "string" and name ~= "" then return name end
    return nil
end

-- ============================================================
-- 监听器
-- ============================================================
cm:add_first_tick_callback(function()
    psw_doct_pcall("install_wrap", psw_doct_install_pickup_wrap)

    -- 战法卡点击 -> 战法困境（复用天赋卡的 cco 取 key 路径）
    core:add_listener(
        "psw_doct_card_click",
        "ComponentLClickUp",
        function() return true end,
        psw_pcall_wrapper(function(context)
            local uic = UIComponent(context.component)
            local ccc = uic:GetContextObject("CcoCampaignBuildingSlot")
            if not ccc then return end
            local rec = uic:GetContextObject("CcoBuildingLevelRecord")
            if not rec then return end
            local bkey = rec:Call("Key")
            if bkey ~= DOCT_BUILDING then return end
            if not ccc:Call("IsForeignSlot") then return end
            local faction_name = ccc:Call("FactionContext.FactionRecordContext.Key")
            local faction = cm:get_faction(faction_name)
            if not faction or faction:is_null_interface() or not faction:is_human() then return end
            if not psw_doct_ready(faction_name) then return end
            cm:trigger_dilemma(faction_name, DOCT_MAIN_DILEMMA)
            psw_doct_log("doctrine menu opened for " .. faction_name)
        end),
        true
    )

    -- 天赋选择后槽位清空 -> 战法卡补位（旧档 4 槽位路径）
    core:add_listener(
        "psw_doct_recard_after_pick",
        "UITrigger",
        function(context)
            local trg = context:trigger()
            return type(trg) == "string" and trg:starts_with("psw_tf_")
        end,
        psw_pcall_wrapper(function(context)
            local ok, cqi = pcall(function() return context:faction_cqi() end)
            if not ok or not cqi then return end
            local faction = cm:model():faction_for_command_queue_index(cqi)
            if not faction or faction:is_null_interface() then return end
            local faction_name = faction:name()
            cm:callback(function()
                psw_doct_pcall("recard", function() psw_doct_place_card(faction_name) end)
            end, 1)
        end),
        true
    )

    -- 困境选择路由
    core:add_listener(
        "psw_doct_dilemma_choice",
        "DilemmaChoiceMadeEvent",
        function(context)
            local d = context:dilemma()
            return type(d) == "string" and d:starts_with("psw_dilemma_doct_")
        end,
        psw_pcall_wrapper(function(context)
            local faction = context:faction()
            if not faction or faction:is_null_interface() then return end
            local faction_name = faction:name()
            if not faction:is_human() then return end
            local dilemma_key = context:dilemma()
            local choice = context:choice_key()

            local function try_apply(doctrine)
                if psw_doct_charge_gmsj(faction_name, DOCT_COST_MAIN) then
                    psw_doct_apply(faction_name, doctrine)
                else
                    psw_doct_log("doctrine " .. tostring(doctrine) .. ": not enough gmsj")
                end
            end

            if dilemma_key == DOCT_MAIN_DILEMMA then
                if choice == "FIRST" then
                    try_apply(psw_doct_archetype(faction_name))
                elseif choice == "SECOND" then
                    try_apply("missile")
                elseif choice == "THIRD" then
                    try_apply("bulwark")
                elseif choice == "FOURTH" then
                    try_apply("charge")
                elseif choice == "FIFTH" then
                    -- 更多号令子菜单（不耗水晶）
                    cm:trigger_dilemma(faction_name, DOCT_MORE_DILEMMA)
                end
            elseif dilemma_key == DOCT_MORE_DILEMMA then
                if choice == "FIRST" then
                    try_apply("arcane")
                elseif choice == "SECOND" then
                    try_apply("beast")
                elseif choice == "THIRD" then
                    -- 联动祈愿子菜单（不耗水晶，进入后再按项收费）
                    if psw_doct_any_link_available(faction_name) then
                        cm:trigger_dilemma(faction_name, DOCT_LINK_DILEMMA)
                    else
                        psw_doct_log("link menu skipped: no backend mods for " .. faction_name)
                    end
                elseif choice == "FOURTH" then
                    -- 休整：清除当前战法（免费）
                    psw_doct_apply(faction_name, nil)
                end
                -- FIFTH = 返回，不做操作
            elseif dilemma_key == DOCT_LINK_DILEMMA then
                if choice == "FIRST" then
                    -- 星塔试炼（本mod自带，不耗水晶）
                    psw_doct_link_tower(faction_name)
                elseif choice == "FIFTH" then
                    -- 更多联动二级页（狱政等）
                    cm:trigger_dilemma(faction_name, DOCT_LINK2_DILEMMA)
                else
                    local idx_map = { SECOND = 1, THIRD = 2, FOURTH = 3 }
                    local idx = idx_map[choice]
                    if idx then
                        psw_doct_do_link(faction_name, idx)
                    end
                end
            elseif dilemma_key == DOCT_LINK2_DILEMMA then
                if choice == "FIRST" then
                    psw_doct_do_link(faction_name, 4)
                elseif choice == "SECOND" then
                    -- 战锤尖塔（adamrogue 原生入口，不耗水晶）
                    local ok, reason = psw_doct_link_spire(faction_name)
                    if not ok then
                        psw_doct_log("link spire unavailable: " .. tostring(reason))
                    end
                end
                -- FIFTH = 返回/取消
            end
        end),
        true
    )

    -- 每回合：补战法卡 + 刷新过载衰减
    core:add_listener(
        "psw_doct_turn_start",
        "FactionTurnStart",
        function(context)
            local f = context:faction()
            return f and not f:is_null_interface() and f:is_human()
        end,
        psw_pcall_wrapper(function(context)
            local faction_name = context:faction():name()
            psw_doct_place_card(faction_name)
            psw_doct_apply_dampen(faction_name)
        end),
        true
    )

    -- 每轮开始：按各派系文化分配 AI 本命战法（与爬坡同事件）
    core:add_listener(
        "psw_doct_ai_doctrines",
        "WorldStartRound",
        function() return true end,
        psw_pcall_wrapper(function()
            psw_doct_apply_ai_doctrines()
        end),
        true
    )

    -- 首 tick：对本地派系补卡/刷新衰减（兼容旧存档）
    psw_doct_pcall("ai_doctrine_init", psw_doct_apply_ai_doctrines)
    local lname = psw_doct_local_faction_name()
    if lname then
        psw_doct_pcall("first_tick_card", function() psw_doct_place_card(lname) end)
        psw_doct_pcall("first_tick_dampen", function() psw_doct_apply_dampen(lname) end)
    end

    psw_doct_log("initialised")
end)
