-- better_recruit_filter.lua
-- 更好的招募UI - 兵种分类筛选功能
-- 读取招募卡片 CcoMainUnitRecord.UiUnitGroupContext.ParentGroup.Key 进行分类
-- 按钮间为或条件（OR），筛选通过 SetVisible 控制
--
-- [czx safety patch v1] 同路径遮蔽修补版（zzz_czx_brf_safety.pack 提供）：
-- 原版在 PanelOpenedCampaign/ComponentLClickUp 派发内联做全树遍历 +
-- CreateComponent/SetVisible——lock_ui 级联窗内组件正被拆除，内联碰树
-- 反复触发原生空指针崩（+0x22c0f80/+0x112e6a6 族）。修补：派发回调只做
-- Lua 侧判断，树操作一律 cm:callback 推迟出派发窗；进树前复查 ui_locked
-- 与面板仍开；持锁有限重试，面板已关即放弃。

-- ============================================================
-- 安全闸门（Lua 侧字段，零原生树访问）
-- ============================================================
local function brf_ui_locked()
    local ok, locked = pcall(function()
        local uim = cm:get_campaign_ui_manager()
        return uim and uim.ui_locked
    end)
    return not ok or locked == true
end

local function brf_panel_open(name)
    local ok, open = pcall(function()
        return cm:get_campaign_ui_manager():is_panel_open(name)
    end)
    return ok and open == true
end

-- AI 回合处理中（whose_turn_is_it 列表非空且不含本地派系）。AI 回合里引擎会为镜头跟随的
-- AI 军队打开 units_panel 并高频拆建 recruitment_options 子树（09-29 2232 会话：纳迦什
-- 合邦后 0.1s 内 Character selected x5 / close x15，随后 +0x22c0f80 崩）。此时注入
-- filter bar 会写进半析构子树；且 AI 面板无交互价值，直接整轮跳过。
local function brf_ai_turn_processing()
    local ok, res = pcall(function()
        local list = cm:whose_turn_is_it()
        if not list then return false end
        local me = cm:get_local_faction_name(true)
        local any = false
        for _, f in model_pairs(list) do
            any = true
            if me and me ~= "" and f:name() == me then return false end
        end
        return any
    end)
    return ok and res == true
end

-- ============================================================
-- 常量：7 个筛选按钮定义
-- ============================================================
local PARENT_GROUP_DEFS = {
    { key = "infantry",                 path = "ui/common ui/unit_category_icons/infantry_sword.png",       tooltip_key = "better_recruit_filter_group_infantry",       tooltip_cn = "近战步兵",       tooltip_en = "Melee Infantry" },
    { key = "missile_infantry",         path = "ui/common ui/unit_category_icons/missile_infantry_bow.png", tooltip_key = "better_recruit_filter_group_missile_infantry", tooltip_cn = "远程步兵",       tooltip_en = "Missile Infantry" },
    { key = "cavalry_chariots",         path = "ui/common ui/unit_category_icons/cavalry.png",              tooltip_key = "better_recruit_filter_group_cavalry_chariots", tooltip_cn = "骑兵/战车",       tooltip_en = "Cavalry / Chariots" },
    { key = "missile_cavalry_chariots", path = "ui/common ui/unit_category_icons/missile_cavalry_bow.png",  tooltip_key = "better_recruit_filter_group_missile_cavalry_chariots", tooltip_cn = "远程骑兵/战车", tooltip_en = "Missile Cavalry / Chariots" },
    { key = "monster_beasts",           path = "ui/common ui/unit_category_icons/dragon.png",                tooltip_key = "better_recruit_filter_group_monster_beasts",   tooltip_cn = "怪兽/巨兽",     tooltip_en = "Monsters / Beasts" },
    { key = "missile_monster_beasts",   path = "ui/common ui/unit_category_icons/wh2_dlc09_tmb_monstrous_inf_bow_ushabti.png", tooltip_key = "better_recruit_filter_group_missile_monster_beasts", tooltip_cn = "远程怪兽", tooltip_en = "Missile Monsters" },
    { key = "artillery_war_machines",   path = "ui/common ui/unit_category_icons/artillery_cannon.png",     tooltip_key = "better_recruit_filter_group_artillery_war_machines", tooltip_cn = "火炮/战争机器", tooltip_en = "Artillery / War Machines" },
}

local TIER_DEFS = {
    { tier = 1, key = "tier_1", path = "ui/skins/default/unit_tier_1.png", tooltip_key = "better_recruit_filter_tier_1", tooltip_cn = "1阶兵种", tooltip_en = "Tier 1 Unit" },
    { tier = 2, key = "tier_2", path = "ui/skins/default/unit_tier_2.png", tooltip_key = "better_recruit_filter_tier_2", tooltip_cn = "2阶兵种", tooltip_en = "Tier 2 Unit" },
    { tier = 3, key = "tier_3", path = "ui/skins/default/unit_tier_3.png", tooltip_key = "better_recruit_filter_tier_3", tooltip_cn = "3阶兵种", tooltip_en = "Tier 3 Unit" },
    { tier = 4, key = "tier_4", path = "ui/skins/default/unit_tier_4.png", tooltip_key = "better_recruit_filter_tier_4", tooltip_cn = "4阶兵种", tooltip_en = "Tier 4 Unit" },
    { tier = 5, key = "tier_5", path = "ui/skins/default/unit_tier_5.png", tooltip_key = "better_recruit_filter_tier_5", tooltip_cn = "5阶兵种", tooltip_en = "Tier 5 Unit" },
}

local FILTER_BAR_TEMPLATE = "ui/campaign ui/better_recruit_filter_bar.twui.xml"
local FILTER_BAR_ID = "better_recruit_filter_bar"
local FILTER_BUTTON_ICON_SIZE = 32
local FILTER_BUTTON_Y_OFFSET = 0
local FILTER_FOOTER_WIDTH = 660
local FILTER_FOOTER_HEIGHT = 48
local FILTER_BAR_DOCK_Y_OFFSET = -24

-- 有按钮的分组集合（用于筛选逻辑判断）
local BUTTON_GROUPS = {}
for _, def in ipairs(PARENT_GROUP_DEFS) do
    BUTTON_GROUPS[def.key] = true
end

-- 将没有独立按钮的分类映射到已有按钮分组
-- flying_war_machine（飞行战争机器）归入 artillery_war_machines（火炮/战争机器）
local GROUP_REMAP = {
    flying_war_machine = "artillery_war_machines",
}

local BUTTON_TIERS = {}
for _, def in ipairs(TIER_DEFS) do
    BUTTON_TIERS[def.tier] = true
end

-- ============================================================
-- i18n：多语言翻译系统
-- 翻译源文件维护在 i18n/*.json；运行时不读文件，避免 io.open 访问 pack/VFS 导致不稳定。
-- ============================================================
-- 游戏语言代码 → 翻译文件语言代码映射
local LANG_MAP = {
    CN = "cn", ZH = "cn", ZH_CN = "cn", ["ZH-CN"] = "cn", CHINESE = "cn",
    EN = "en", ENGLISH = "en",
    RU = "ru", RUSSIAN = "ru",
    DE = "de", GERMAN = "de",
    FR = "fr", FRENCH = "fr",
    KO = "ko", KR = "ko", KOREAN = "ko",
    IT = "it", ITALIAN = "it",
    ES = "es", SP = "es", SPANISH = "es",
    TR = "tr", TURKISH = "tr",
    PT = "pt", BR = "pt", PORTUGUESE = "pt",
    PL = "pl", POLISH = "pl",
    CS = "cs", CZ = "cs", CZECH = "cs",
}

local I18N_DATA = {
    cn = {
        better_recruit_filter_group_infantry = "近战步兵",
        better_recruit_filter_group_missile_infantry = "远程步兵",
        better_recruit_filter_group_cavalry_chariots = "骑兵/战车",
        better_recruit_filter_group_missile_cavalry_chariots = "远程骑兵/战车",
        better_recruit_filter_group_monster_beasts = "怪兽/巨兽",
        better_recruit_filter_group_missile_monster_beasts = "远程怪兽",
        better_recruit_filter_group_artillery_war_machines = "火炮/战争机器",
        better_recruit_filter_tier_1 = "1阶兵种",
        better_recruit_filter_tier_2 = "2阶兵种",
        better_recruit_filter_tier_3 = "3阶兵种",
        better_recruit_filter_tier_4 = "4阶兵种",
        better_recruit_filter_tier_5 = "5阶兵种",
    },
    en = {
        better_recruit_filter_group_infantry = "Melee Infantry",
        better_recruit_filter_group_missile_infantry = "Missile Infantry",
        better_recruit_filter_group_cavalry_chariots = "Cavalry / Chariots",
        better_recruit_filter_group_missile_cavalry_chariots = "Missile Cavalry / Chariots",
        better_recruit_filter_group_monster_beasts = "Monsters / Beasts",
        better_recruit_filter_group_missile_monster_beasts = "Missile Monsters",
        better_recruit_filter_group_artillery_war_machines = "Artillery / War Machines",
        better_recruit_filter_tier_1 = "Tier 1 Unit",
        better_recruit_filter_tier_2 = "Tier 2 Unit",
        better_recruit_filter_tier_3 = "Tier 3 Unit",
        better_recruit_filter_tier_4 = "Tier 4 Unit",
        better_recruit_filter_tier_5 = "Tier 5 Unit",
    },
    ru = {
        better_recruit_filter_group_infantry = "Пехота ближнего боя",
        better_recruit_filter_group_missile_infantry = "Стрелковая пехота",
        better_recruit_filter_group_cavalry_chariots = "Кавалерия / Колесницы",
        better_recruit_filter_group_missile_cavalry_chariots = "Стрелковая кавалерия / Колесницы",
        better_recruit_filter_group_monster_beasts = "Чудовища / Звери",
        better_recruit_filter_group_missile_monster_beasts = "Стрелковые чудовища",
        better_recruit_filter_group_artillery_war_machines = "Артиллерия / Боевые машины",
        better_recruit_filter_tier_1 = "Отряд 1 уровня",
        better_recruit_filter_tier_2 = "Отряд 2 уровня",
        better_recruit_filter_tier_3 = "Отряд 3 уровня",
        better_recruit_filter_tier_4 = "Отряд 4 уровня",
        better_recruit_filter_tier_5 = "Отряд 5 уровня",
    },
    de = {
        better_recruit_filter_group_infantry = "Nahkampf-Infanterie",
        better_recruit_filter_group_missile_infantry = "Fernkampf-Infanterie",
        better_recruit_filter_group_cavalry_chariots = "Kavallerie / Streitwagen",
        better_recruit_filter_group_missile_cavalry_chariots = "Fernkampf-Kavallerie / Streitwagen",
        better_recruit_filter_group_monster_beasts = "Monster / Bestien",
        better_recruit_filter_group_missile_monster_beasts = "Fernkampf-Monster",
        better_recruit_filter_group_artillery_war_machines = "Artillerie / Kriegsmaschinen",
        better_recruit_filter_tier_1 = "Einheit der Stufe 1",
        better_recruit_filter_tier_2 = "Einheit der Stufe 2",
        better_recruit_filter_tier_3 = "Einheit der Stufe 3",
        better_recruit_filter_tier_4 = "Einheit der Stufe 4",
        better_recruit_filter_tier_5 = "Einheit der Stufe 5",
    },
    fr = {
        better_recruit_filter_group_infantry = "Infanterie de mêlée",
        better_recruit_filter_group_missile_infantry = "Infanterie à distance",
        better_recruit_filter_group_cavalry_chariots = "Cavalerie / Chars",
        better_recruit_filter_group_missile_cavalry_chariots = "Cavalerie à distance / Chars",
        better_recruit_filter_group_monster_beasts = "Monstres / Bêtes",
        better_recruit_filter_group_missile_monster_beasts = "Monstres à distance",
        better_recruit_filter_group_artillery_war_machines = "Artillerie / Machines de guerre",
        better_recruit_filter_tier_1 = "Unité de rang 1",
        better_recruit_filter_tier_2 = "Unité de rang 2",
        better_recruit_filter_tier_3 = "Unité de rang 3",
        better_recruit_filter_tier_4 = "Unité de rang 4",
        better_recruit_filter_tier_5 = "Unité de rang 5",
    },
    ko = {
        better_recruit_filter_group_infantry = "근접 보병",
        better_recruit_filter_group_missile_infantry = "사격 보병",
        better_recruit_filter_group_cavalry_chariots = "기병 / 전차",
        better_recruit_filter_group_missile_cavalry_chariots = "사격 기병 / 전차",
        better_recruit_filter_group_monster_beasts = "괴수 / 야수",
        better_recruit_filter_group_missile_monster_beasts = "사격 괴수",
        better_recruit_filter_group_artillery_war_machines = "포병 / 전쟁 기계",
        better_recruit_filter_tier_1 = "1단계 유닛",
        better_recruit_filter_tier_2 = "2단계 유닛",
        better_recruit_filter_tier_3 = "3단계 유닛",
        better_recruit_filter_tier_4 = "4단계 유닛",
        better_recruit_filter_tier_5 = "5단계 유닛",
    },
    it = {
        better_recruit_filter_group_infantry = "Fanteria da mischia",
        better_recruit_filter_group_missile_infantry = "Fanteria da tiro",
        better_recruit_filter_group_cavalry_chariots = "Cavalleria / Carri",
        better_recruit_filter_group_missile_cavalry_chariots = "Cavalleria da tiro / Carri",
        better_recruit_filter_group_monster_beasts = "Mostri / Bestie",
        better_recruit_filter_group_missile_monster_beasts = "Mostri da tiro",
        better_recruit_filter_group_artillery_war_machines = "Artiglieria / Macchine da guerra",
        better_recruit_filter_tier_1 = "Unità di livello 1",
        better_recruit_filter_tier_2 = "Unità di livello 2",
        better_recruit_filter_tier_3 = "Unità di livello 3",
        better_recruit_filter_tier_4 = "Unità di livello 4",
        better_recruit_filter_tier_5 = "Unità di livello 5",
    },
    es = {
        better_recruit_filter_group_infantry = "Infantería cuerpo a cuerpo",
        better_recruit_filter_group_missile_infantry = "Infantería de proyectiles",
        better_recruit_filter_group_cavalry_chariots = "Caballería / Carros",
        better_recruit_filter_group_missile_cavalry_chariots = "Caballería de proyectiles / Carros",
        better_recruit_filter_group_monster_beasts = "Monstruos / Bestias",
        better_recruit_filter_group_missile_monster_beasts = "Monstruos de proyectiles",
        better_recruit_filter_group_artillery_war_machines = "Artillería / Máquinas de guerra",
        better_recruit_filter_tier_1 = "Unidad de nivel 1",
        better_recruit_filter_tier_2 = "Unidad de nivel 2",
        better_recruit_filter_tier_3 = "Unidad de nivel 3",
        better_recruit_filter_tier_4 = "Unidad de nivel 4",
        better_recruit_filter_tier_5 = "Unidad de nivel 5",
    },
    tr = {
        better_recruit_filter_group_infantry = "Yakın dövüş piyadesi",
        better_recruit_filter_group_missile_infantry = "Menzilli piyade",
        better_recruit_filter_group_cavalry_chariots = "Süvari / Savaş arabaları",
        better_recruit_filter_group_missile_cavalry_chariots = "Menzilli süvari / Savaş arabaları",
        better_recruit_filter_group_monster_beasts = "Canavarlar / Yaratıklar",
        better_recruit_filter_group_missile_monster_beasts = "Menzilli canavarlar",
        better_recruit_filter_group_artillery_war_machines = "Topçu / Savaş makineleri",
        better_recruit_filter_tier_1 = "1. seviye birlik",
        better_recruit_filter_tier_2 = "2. seviye birlik",
        better_recruit_filter_tier_3 = "3. seviye birlik",
        better_recruit_filter_tier_4 = "4. seviye birlik",
        better_recruit_filter_tier_5 = "5. seviye birlik",
    },
    pt = {
        better_recruit_filter_group_infantry = "Infantaria corpo a corpo",
        better_recruit_filter_group_missile_infantry = "Infantaria de projéteis",
        better_recruit_filter_group_cavalry_chariots = "Cavalaria / Carruagens",
        better_recruit_filter_group_missile_cavalry_chariots = "Cavalaria de projéteis / Carruagens",
        better_recruit_filter_group_monster_beasts = "Monstros / Bestas",
        better_recruit_filter_group_missile_monster_beasts = "Monstros de projéteis",
        better_recruit_filter_group_artillery_war_machines = "Artilharia / Máquinas de guerra",
        better_recruit_filter_tier_1 = "Unidade de nível 1",
        better_recruit_filter_tier_2 = "Unidade de nível 2",
        better_recruit_filter_tier_3 = "Unidade de nível 3",
        better_recruit_filter_tier_4 = "Unidade de nível 4",
        better_recruit_filter_tier_5 = "Unidade de nível 5",
    },
    pl = {
        better_recruit_filter_group_infantry = "Piechota do walki wręcz",
        better_recruit_filter_group_missile_infantry = "Piechota strzelecka",
        better_recruit_filter_group_cavalry_chariots = "Kawaleria / Rydwany",
        better_recruit_filter_group_missile_cavalry_chariots = "Kawaleria strzelecka / Rydwany",
        better_recruit_filter_group_monster_beasts = "Potwory / Bestie",
        better_recruit_filter_group_missile_monster_beasts = "Potwory strzeleckie",
        better_recruit_filter_group_artillery_war_machines = "Artyleria / Machiny wojenne",
        better_recruit_filter_tier_1 = "Jednostka poziomu 1",
        better_recruit_filter_tier_2 = "Jednostka poziomu 2",
        better_recruit_filter_tier_3 = "Jednostka poziomu 3",
        better_recruit_filter_tier_4 = "Jednostka poziomu 4",
        better_recruit_filter_tier_5 = "Jednostka poziomu 5",
    },
    cs = {
        better_recruit_filter_group_infantry = "Pěchota pro boj zblízka",
        better_recruit_filter_group_missile_infantry = "Střelecká pěchota",
        better_recruit_filter_group_cavalry_chariots = "Jízda / Vozy",
        better_recruit_filter_group_missile_cavalry_chariots = "Střelecká jízda / Vozy",
        better_recruit_filter_group_monster_beasts = "Monstra / Bestie",
        better_recruit_filter_group_missile_monster_beasts = "Střelecká monstra",
        better_recruit_filter_group_artillery_war_machines = "Dělostřelectvo / Válečné stroje",
        better_recruit_filter_tier_1 = "Jednotka 1. úrovně",
        better_recruit_filter_tier_2 = "Jednotka 2. úrovně",
        better_recruit_filter_tier_3 = "Jednotka 3. úrovně",
        better_recruit_filter_tier_4 = "Jednotka 4. úrovně",
        better_recruit_filter_tier_5 = "Jednotka 5. úrovně",
    },
}

local i18n_data = {}    -- 当前语言翻译
local i18n_en_data = {} -- 英文 fallback

--- 加载当前语言的翻译文件
local function load_i18n()
    i18n_data = {}
    i18n_en_data = {}

    -- 检测语言
    local raw_lang = "EN"
    if common and common.get_context_value then
        local ok, lang = pcall(function()
            return common.get_context_value("LocLanguage")
        end)
        if ok and lang then raw_lang = string.upper(tostring(lang)) end
    end
    local lang_code = LANG_MAP[raw_lang] or "en"
    out("BetterRecruitFilter: [i18n] detected language='" .. raw_lang .. "' mapped='" .. lang_code .. "'")

    local data = I18N_DATA[lang_code]
    if data then
        for k, v in pairs(data) do i18n_data[k] = v end
        local c = 0
        for _ in pairs(i18n_data) do c = c + 1 end
        out("BetterRecruitFilter: [i18n] loaded static lang='" .. lang_code .. "' (" .. c .. " keys)")
    else
        out("BetterRecruitFilter: [i18n] no static lang table for '" .. lang_code .. "'")
    end

    if lang_code ~= "en" then
        local en_data = I18N_DATA.en
        if en_data then
            for k, v in pairs(en_data) do i18n_en_data[k] = v end
            out("BetterRecruitFilter: [i18n] loaded EN fallback")
        end
    end

    local key_count = 0
    for _ in pairs(i18n_data) do key_count = key_count + 1 end
    out("BetterRecruitFilter: [i18n] final: lang='" .. lang_code .. "' keys=" .. key_count)

    return lang_code
end

--- 翻译查找：当前语言 → 英文 fallback → 硬编码 fallback
--- @param key string 翻译键（tooltip_key）
--- @param fallback string|nil 硬编码 fallback 文本
local function tr(key, fallback)
    if i18n_data[key] then
        return i18n_data[key]
    end
    if i18n_en_data[key] then
        return i18n_en_data[key]
    end
    out("BetterRecruitFilter: [i18n] fallback to hardcoded for key='" .. key .. "'")
    return fallback or key
end

-- ============================================================
-- 状态变量
-- ============================================================
local active_group_filters = {}
local active_tier_filters = {}
local filter_buttons = {}
local tree_dumped = false
local card_base_visibility = {}
local hidden_by_filter = {}
-- 当前 filter bar 及其定位基准（recruitment_options）的引用，供延迟重定位使用
local current_filter_bar = nil
local current_recruitment_options = nil
local current_search_root = nil
-- 外层容器扩高的基线高度记录，保证多次调用（含延迟回调）扩高的目标值幂等一致
local docker_base_height = nil
local docker_grown = false

-- table 键列表转字符串（用于日志）
local function table_keys_string(t)
    local parts = {}
    for k, v in pairs(t or {}) do
        table.insert(parts, tostring(k))
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end

-- ============================================================
-- 工具函数
-- ============================================================
local function resolve_text(uic)
    if not uic then return "", "" end
    local raw = uic:GetStateText() or ""
    local ok, resolved = pcall(function()
        return common.get_localised_string(raw)
    end)
    if not ok or not resolved or resolved == "" then resolved = raw end
    return raw, resolved
end

local function safe_cco_call(context, expression)
    if not context or not expression then return nil end
    local ok, result = pcall(function()
        return context:Call(expression)
    end)
    if not ok or result == nil then
        out("BetterRecruitFilter: CCO调用失败 '" .. tostring(expression) .. "' ok=" .. tostring(ok) .. " result=" .. tostring(result))
        return nil
    end
    if type(result) == "string" and result == "" then return nil end
    return result
end

local function clean_record_key(value)
    if not value then return nil end
    local key = tostring(value)
    if key == "" then return nil end
    if key:match("^cco %(") or key:match("^UIComponent %(") then return nil end
    return key
end

local function normalize_group_key(group_key, unit_group_key)
    local cleaned_group = clean_record_key(group_key)
    if cleaned_group then
        local remapped = GROUP_REMAP[cleaned_group] or cleaned_group
        if BUTTON_GROUPS[remapped] then
            return remapped, "parent_group"
        end
    end

    local cleaned_unit_group = clean_record_key(unit_group_key)
    if cleaned_unit_group then
        local remapped = GROUP_REMAP[cleaned_unit_group] or cleaned_unit_group
        if BUTTON_GROUPS[remapped] then
            return remapped, "unit_group_parent"
        end
    end

    return nil, "unmatched"
end

local function get_stored_context(component, context_type)
    if not component or not context_type or not component.GetContextObjectId then
        out("BetterRecruitFilter: 组件不支持 GetContextObjectId")
        return nil, nil
    end
    local ok, context_id = pcall(function()
        return component:GetContextObjectId(context_type)
    end)
    if not ok or not context_id or context_id == "" then
        out("BetterRecruitFilter: 获取 " .. context_type .. " 上下文ID失败 ok=" .. tostring(ok))
        return nil, nil
    end
    out("BetterRecruitFilter: 获取 " .. context_type .. " 上下文ID='" .. tostring(context_id) .. "'")
    local ok_context, context = pcall(function()
        return cco(context_type, context_id)
    end)
    if not ok_context then
        out("BetterRecruitFilter: cco() 创建 " .. context_type .. " 失败 id='" .. tostring(context_id) .. "'")
        return nil, context_id
    end
    out("BetterRecruitFilter: 成功获取 " .. context_type .. " 上下文")
    return context, context_id
end

local function get_context_id_quiet(component, context_type)
    if not component or not context_type or not component.GetContextObjectId then return nil end
    local ok, context_id = pcall(function()
        return component:GetContextObjectId(context_type)
    end)
    if ok and context_id and context_id ~= "" then
        return context_id
    end
    return nil
end

-- 招募卡片根节点存有 CcoMainUnitRecord，可直接读取 ui_unit_groupings_tables.parent_group
local function get_card_group_from_unit_record(card)
    local unit_record, record_id = get_stored_context(card, "CcoMainUnitRecord")
    if not unit_record then
        out("BetterRecruitFilter: CCO CcoMainUnitRecord 不可用")
        return nil, nil, nil
    end

    local unit_key = safe_cco_call(unit_record, "Key")
    local parent_group_key = safe_cco_call(unit_record, "UiUnitGroupContext.ParentGroup.Key")
    local parent_group = safe_cco_call(unit_record, "UiUnitGroupContext.ParentGroup")
    local unit_group_key = safe_cco_call(unit_record, "UiUnitGroupContext.Key")
    local group, group_source = normalize_group_key(parent_group_key or parent_group, unit_group_key)

    out("BetterRecruitFilter: CCO 读取结果 key='" .. tostring(unit_key)
        .. "' parent_key='" .. tostring(parent_group_key)
        .. "' parent_raw='" .. tostring(parent_group)
        .. "' unit_group='" .. tostring(unit_group_key)
        .. "' normalized='" .. tostring(group)
        .. "' source='" .. tostring(group_source) .. "'")

    if group then
        return group, tostring(unit_key or ""), tostring(unit_group_key or "")
    end

    -- 部分 CCO 表达式环境不支持链式调用时，尝试先取 group context 再读 ParentGroup。
    local group_context = safe_cco_call(unit_record, "UiUnitGroupContext")
    out("BetterRecruitFilter: CCO UiUnitGroupContext 链式回退 group_context=" .. tostring(group_context) .. " type=" .. type(group_context))
    if group_context and type(group_context) ~= "string" then
        parent_group_key = safe_cco_call(group_context, "ParentGroup.Key")
        parent_group = safe_cco_call(group_context, "ParentGroup")
        unit_group_key = unit_group_key or safe_cco_call(group_context, "Key")
        group, group_source = normalize_group_key(parent_group_key or parent_group, unit_group_key)
        out("BetterRecruitFilter: CCO 链式回退结果 parent_key='" .. tostring(parent_group_key)
            .. "' parent_raw='" .. tostring(parent_group)
            .. "' unit_group='" .. tostring(unit_group_key)
            .. "' normalized='" .. tostring(group)
            .. "' source='" .. tostring(group_source) .. "'")
        if group then
            return group, tostring(unit_key or ""), tostring(unit_group_key or "")
        end
    end

    out("BetterRecruitFilter: CCO 无有效 ParentGroup")
    return nil, tostring(unit_key or ""), tostring(unit_group_key or "")
end

local function normalize_unit_tier(value)
    local tier = tonumber(value)
    if tier and BUTTON_TIERS[tier] then
        return tier
    end
    return nil
end

-- This is main_units_tables.tier only. Do not use rank/veterancy/experience here.
local function get_unit_tier_from_record(unit_record, unit_key)
    local tier = normalize_unit_tier(safe_cco_call(unit_record, "Tier"))
    if tier then return tier, "cco_tier" end

    tier = normalize_unit_tier(safe_cco_call(unit_record, "Record.Tier"))
    if tier then return tier, "cco_record_tier" end

    if common and common.get_context_value and unit_key and unit_key ~= "" then
        local ok, value = pcall(function()
            return common.get_context_value("CcoMainUnitRecord", unit_key, "Tier")
        end)
        tier = ok and normalize_unit_tier(value) or nil
        if tier then return tier, "context_value_tier" end
    end

    return nil, "tier_unmatched"
end

local function get_card_tier(card, unit_key)
    local unit_record = nil
    local record_id = nil
    unit_record, record_id = get_stored_context(card, "CcoMainUnitRecord")
    if not unit_record then
        return nil, "no_unit_record"
    end

    if not unit_key or unit_key == "" then
        unit_key = safe_cco_call(unit_record, "Key")
    end

    local tier, source = get_unit_tier_from_record(unit_record, tostring(unit_key or ""))
    out("BetterRecruitFilter: tier read unit='" .. tostring(unit_key)
        .. "' tier='" .. tostring(tier)
        .. "' source='" .. tostring(source) .. "'")
    return tier, source
end

local function get_card_group(card)
    local group, unit_key, unit_group_key = get_card_group_from_unit_record(card)
    local tier, tier_source = get_card_tier(card, unit_key)
    if group then
        out("BetterRecruitFilter: 卡片分组来源=cco group='" .. group .. "' unit='" .. tostring(unit_key) .. "'")
        return group, "cco", unit_key, unit_group_key, nil, tier, tier_source
    end

    out("BetterRecruitFilter: 卡片分组来源=cco group=nil unit='" .. tostring(unit_key) .. "'")
    return nil, "cco", unit_key, unit_group_key, nil, tier, tier_source
end

-- 递归转储组件树
local function dump_tree(uic, indent, max_depth)
    if not uic or indent > max_depth then return end
    local prefix = string.rep("  ", indent)
    local id = uic:Id() or "?"
    local child_count = uic:ChildCount() or 0
    local extra = ""
    if id == "tx_header" then
        local raw, resolved = resolve_text(uic)
        extra = " raw='" .. raw .. "' display='" .. resolved .. "'"
    end
    if id == "unit_category_icon" then
        local path = ""
        if uic.GetCurrentImagePath then path = uic:GetCurrentImagePath() or "" end
        extra = " image='" .. path .. "'"
    end
    out("BetterRecruitFilter: " .. prefix .. "[" .. id .. "] children=" .. child_count .. extra)
    for i = 0, child_count - 1 do
        local child = UIComponent(uic:Find(i))
        if child then dump_tree(child, indent + 1, max_depth) end
    end
end

local function is_recruitment_card(uic)
    if not uic then return false end
    local id = uic:Id() or ""
    if id == "recruitment_item" then return true end
    return get_context_id_quiet(uic, "CcoMainUnitRecord") ~= nil
end

local function get_component_visible(uic)
    if not uic or not uic.Visible then return true end
    local ok, visible = pcall(function()
        return uic:Visible()
    end)
    if ok and visible ~= nil then
        return visible
    end
    return true
end

local function get_component_identity(uic)
    if not uic then return nil end
    if uic.Address then
        local ok, address = pcall(function()
            return uic:Address()
        end)
        if ok and address then
            return tostring(address)
        end
    end
    return tostring(uic)
end

local function get_card_key(card)
    if not card then return nil end
    local context_id = get_context_id_quiet(card, "CcoMainUnitRecord")
    local id = card:Id() or tostring(card)
    local identity = get_component_identity(card) or tostring(card)
    return tostring(context_id or "") .. "|" .. tostring(id) .. "|" .. identity
end

local function add_layout_target(layout_targets, uic)
    if not layout_targets or not uic or not uic.Layout then return end
    local key = get_component_identity(uic)
    if not key or layout_targets[key] then return end
    layout_targets[key] = uic
end

local function layout_changed_lists(layout_targets, root)
    if layout_targets then
        for _, uic in pairs(layout_targets) do
            pcall(function() uic:Layout() end)
        end
    end
    if root and root.Layout then
        pcall(function() root:Layout() end)
    end
end

local function get_card_base_visible(card)
    local key = get_card_key(card)
    if not key then return get_component_visible(card) end
    if card_base_visibility[key] == nil then
        card_base_visibility[key] = get_component_visible(card)
        out("BetterRecruitFilter: 记录卡片基线可见性 key='" .. key .. "' visible=" .. tostring(card_base_visibility[key]))
    end
    return card_base_visibility[key]
end

-- 查找所有单位卡片：只收集真实 recruitment_item，而不是包含单位图标的上层容器。
local function find_all_unit_cards(root, results, layout_targets)
    if not root then
        out("BetterRecruitFilter: find_all_unit_cards root 为空")
        return
    end
    local found_count = 0
    local function search(uic, depth)
        if not uic or depth > 30 then return end
        local id = uic:Id() or ""

        if id == FILTER_BAR_ID then
            return
        end

        if id == "list_box"
            or id == "listview"
            or id == "recruitment_pool_list"
            or id == "recruitment_listbox"
            or id == "allied_unit_list"
            or id == "mercenary_display" then
            add_layout_target(layout_targets, uic)
        end

        if is_recruitment_card(uic) then
            found_count = found_count + 1
            out("BetterRecruitFilter: 找到单位卡片[" .. found_count .. "] id='" .. id .. "' depth=" .. depth)
            table.insert(results, uic)
            return
        end

        for i = 0, (uic:ChildCount() or 0) - 1 do
            local child = UIComponent(uic:Find(i))
            if child then search(child, depth + 1) end
        end
    end
    search(root, 0)
    out("BetterRecruitFilter: find_all_unit_cards 共找到 " .. #results .. " 张卡片")
end

-- 获取招募内容根容器。使用 recruitment_options 可覆盖全局、本地、游牧、盟友和特殊招募区。
local function get_recruitment_root()
    out("BetterRecruitFilter: 查找 recruitment_options 路径...")
    local units_panel = find_uicomponent(core:get_ui_root(), "units_panel")
    if not units_panel then
        out("BetterRecruitFilter: 未找到 units_panel")
        return nil
    end
    local main_units_panel = find_uicomponent(units_panel, "main_units_panel")
    local search_root = main_units_panel or units_panel
    local recruitment_options = find_uicomponent(
        search_root,
        "recruitment_docker",
        "recruitment_options"
    )
    out("BetterRecruitFilter: recruitment_options=" .. tostring(recruitment_options))
    return recruitment_options
end

-- ============================================================
-- 筛选逻辑（OR 条件）
-- ============================================================
local function apply_filter()
    if brf_ui_locked() then return end -- [czx patch] 锁窗内不进树
    local pool_root = get_recruitment_root()
    if not pool_root then
        out("BetterRecruitFilter: 未找到 recruitment_options")
        return
    end

    out("BetterRecruitFilter: apply_filter groups=" .. table_keys_string(active_group_filters)
        .. " tiers=" .. table_keys_string(active_tier_filters))

    if not tree_dumped then
        out("BetterRecruitFilter: === 组件树转储 ===")
        dump_tree(pool_root, 0, 12)
        out("BetterRecruitFilter: === 转储结束 ===")
        tree_dumped = true
    end

    local cards = {}
    local layout_targets = {}
    find_all_unit_cards(pool_root, cards, layout_targets)
    out("BetterRecruitFilter: 找到 " .. #cards .. " 张单位卡片")

    local has_active_groups = next(active_group_filters) ~= nil
    local has_active_tiers = next(active_tier_filters) ~= nil
    local has_active = has_active_groups or has_active_tiers
    local shown = 0
    local hidden = 0

    for i, card in ipairs(cards) do
        local group, source, unit_key, unit_group_key, icon_fn, tier, tier_source = get_card_group(card)
        local card_key = get_card_key(card)
        local base_visible = get_card_base_visible(card)
        local visible_now = get_component_visible(card)
        local hidden_by_this_filter = card_key and hidden_by_filter[card_key] == true
        local allowed_visible = base_visible and (visible_now or hidden_by_this_filter)
        local should_show

        if not has_active then
            should_show = allowed_visible
        elseif (not has_active_groups or active_group_filters[group]) and (not has_active_tiers or active_tier_filters[tier]) then
            should_show = allowed_visible
        else
            should_show = false
        end

        if i <= 5 or not should_show or not allowed_visible then
            out("BetterRecruitFilter: card[" .. i .. "] source='" .. tostring(source)
                .. "' unit='" .. tostring(unit_key)
                .. "' unit_group='" .. tostring(unit_group_key)
                .. "' icon='" .. tostring(icon_fn)
                .. "' group='" .. tostring(group)
                .. "' tier='" .. tostring(tier)
                .. "' tier_source='" .. tostring(tier_source)
                .. "' base_visible=" .. tostring(base_visible)
                .. "' visible_now=" .. tostring(visible_now)
                .. "' allowed_visible=" .. tostring(allowed_visible)
                .. "' show=" .. tostring(should_show))
        end

        card:SetVisible(should_show)
        if card_key then
            hidden_by_filter[card_key] = allowed_visible and not should_show
        end
        if should_show then shown = shown + 1 else hidden = hidden + 1 end
    end
    layout_changed_lists(layout_targets, pool_root)
    out("BetterRecruitFilter: 结果: 显示=" .. shown .. " 隐藏=" .. hidden)
end

local function show_all()
    if brf_ui_locked() then return end -- [czx patch]
    out("BetterRecruitFilter: show_all 被调用")
    local pool_root = get_recruitment_root()
    if not pool_root then
        out("BetterRecruitFilter: show_all 未找到 recruitment_options")
        return
    end
    local cards = {}
    local layout_targets = {}
    find_all_unit_cards(pool_root, cards, layout_targets)
    for _, card in ipairs(cards) do
        local card_key = get_card_key(card)
        local base_visible = get_card_base_visible(card)
        local visible_now = get_component_visible(card)
        local should_restore = base_visible and (visible_now or hidden_by_filter[card_key] == true)
        card:SetVisible(should_restore)
        if card_key then
            hidden_by_filter[card_key] = false
        end
    end
    layout_changed_lists(layout_targets, pool_root)
end

local function has_active_filters()
    return next(active_group_filters) ~= nil or next(active_tier_filters) ~= nil
end

-- ============================================================
-- 按钮交互
-- ============================================================
local function toggle_group_filter(group_key)
    if brf_ui_locked() then return end -- [czx patch]
    if active_group_filters[group_key] then
        active_group_filters[group_key] = nil
        out("BetterRecruitFilter: 取消筛选 " .. group_key)
    else
        active_group_filters[group_key] = true
        out("BetterRecruitFilter: 添加筛选 " .. group_key)
    end

    if has_active_filters() then
        apply_filter()
    else
        show_all()
    end
end

local function toggle_tier_filter(tier)
    if brf_ui_locked() then return end -- [czx patch]
    if active_tier_filters[tier] then
        active_tier_filters[tier] = nil
        out("BetterRecruitFilter: remove tier filter " .. tostring(tier))
    else
        active_tier_filters[tier] = true
        out("BetterRecruitFilter: add tier filter " .. tostring(tier))
    end

    if has_active_filters() then
        apply_filter()
    else
        show_all()
    end
end

local function shrink_current_state_filter_icon(btn)
    if not btn or not btn.NumCurrentStateImages then return end

    local ok_count, image_count = pcall(function()
        return btn:NumCurrentStateImages()
    end)
    if not ok_count or not image_count then return end

    for i = 0, image_count - 1 do
        local ok_index, component_image_index = pcall(function()
            return btn:GetCurrentStateImageIndex(i)
        end)
        if ok_index and component_image_index == 0 then
            if btn.SetCanResizeCurrentStateImageWidth then
                pcall(function() btn:SetCanResizeCurrentStateImageWidth(i, true) end)
            end
            if btn.SetCanResizeCurrentStateImageHeight then
                pcall(function() btn:SetCanResizeCurrentStateImageHeight(i, true) end)
            end
            pcall(function()
                btn:ResizeCurrentStateImage(i, FILTER_BUTTON_ICON_SIZE, FILTER_BUTTON_ICON_SIZE)
            end)
        end
    end
end

local function apply_filter_button_style(btn)
    if not btn then return end

    local original_state = nil
    if btn.CurrentState then
        local ok, state = pcall(function()
            return btn:CurrentState()
        end)
        if ok then original_state = state end
    end

    local states = {}
    if btn.NumStates and btn.GetStateByIndex then
        local ok_count, state_count = pcall(function()
            return btn:NumStates()
        end)
        if ok_count and state_count then
            for i = 0, state_count - 1 do
                local ok_state, state = pcall(function()
                    return btn:GetStateByIndex(i)
                end)
                if ok_state and state then
                    table.insert(states, state)
                end
            end
        end
    end

    if #states == 0 then
        states = {
            "active", "hover", "down", "down_off", "inactive",
            "selected", "selected_hover", "selected_down", "selected_down_off",
        }
    end

    for _, state in ipairs(states) do
        local ok = true
        if btn.SetState then
            ok = pcall(function()
                return btn:SetState(state)
            end)
        end
        if ok then
            shrink_current_state_filter_icon(btn)
        end
    end

    if original_state and btn.SetState then
        pcall(function()
            btn:SetState(original_state)
        end)
    end
end

-- ============================================================
-- 面板初始化
-- ============================================================
-- [czx patch] 延迟回调不得复用存的 UIComponent：面板子树若被引擎重建，
-- 存引用即成悬指针，MoveTo/Resize 写入 = +0x22c8774 族 UAF 写（22:24 崩）。
-- 每次回调沿固定路径从当前树重寻；组件没了说明刚重建，放弃本轮。
local function brf_resolve_layout()
    local units_panel = find_uicomponent(core:get_ui_root(), "units_panel")
    if not units_panel then return nil end
    local search_root = find_uicomponent(units_panel, "main_units_panel") or units_panel
    local recruitment_options = find_uicomponent(search_root, "recruitment_docker", "recruitment_options")
    if not recruitment_options then return nil end
    local filter_bar = find_uicomponent(recruitment_options, FILTER_BAR_ID)
    return filter_bar, recruitment_options, search_root
end

local function move_filter_buttons_up()
    if brf_ui_locked() then return end -- [czx patch]
    out("BetterRecruitFilter: move_up enter n=" .. #filter_buttons) -- [czx canary]
    local filter_bar = brf_resolve_layout()
    if not filter_bar then
        out("BetterRecruitFilter: move_up 树已重建，弃本轮") -- [czx canary]
        return
    end
    for _, entry in ipairs(filter_buttons) do
        local btn = entry.btn_id and find_uicomponent(filter_bar, entry.btn_id) or entry.btn
        if btn then
            if btn.Position and btn.MoveTo then
                local ok, x, y = pcall(function()
                    return btn:Position()
                end)
                if ok and x and y then
                    local already_moved = entry.base_y and math.abs(y - (entry.base_y + FILTER_BUTTON_Y_OFFSET)) <= 1
                    if not entry.base_x or not entry.base_y or not already_moved then
                        entry.base_x = x
                        entry.base_y = y
                    end
                    pcall(function()
                        btn:MoveTo(entry.base_x, entry.base_y + FILTER_BUTTON_Y_OFFSET)
                    end)
                elseif btn.SetDockOffset then
                    pcall(function()
                        btn:SetDockOffset(0, FILTER_BUTTON_Y_OFFSET)
                    end)
                end
            elseif btn.SetDockOffset then
                pcall(function()
                    btn:SetDockOffset(0, FILTER_BUTTON_Y_OFFSET)
                end)
            end
        end
    end
end

local position_filter_bar
local grow_containers_for_filter_bar

local function reposition_filter_bar()
    if brf_ui_locked() then return end -- [czx patch]
    out("BetterRecruitFilter: reposition enter") -- [czx canary]
    -- [czx patch] 重寻当前树，不复用 current_* 存引用（防跨回调悬指针写）
    local filter_bar, recruitment_options, search_root = brf_resolve_layout()
    if not filter_bar then
        out("BetterRecruitFilter: reposition 树已重建，弃本轮") -- [czx canary]
        return
    end
    if filter_bar and recruitment_options then
        position_filter_bar(filter_bar, recruitment_options)
    end
    -- 面板滑入动画可能重置 docker 高度，故每次重定位时重新确保扩高
    if search_root then
        grow_containers_for_filter_bar(search_root)
    end
    out("BetterRecruitFilter: reposition done") -- [czx canary]
end

local function schedule_filter_button_positioning()
    -- 面板滑入动画 + recruitment_pool_list 高度自适应回调在打开后一段时间内仍在调整
    -- recruitment_options 的尺寸/位置，故延迟多次重定位 filter bar 以保证落点稳定。
    if cm and cm.callback then
        -- [czx patch] 延迟体落到锁窗/面板已关时直接弃本轮
        cm:callback(function()
            if brf_ui_locked() or not brf_panel_open("units_panel") then return end
            move_filter_buttons_up()
            reposition_filter_bar()
        end, 0.05)
        cm:callback(function()
            if brf_ui_locked() or not brf_panel_open("units_panel") then return end
            move_filter_buttons_up()
            reposition_filter_bar()
        end, 0.25)
        cm:callback(function()
            if brf_ui_locked() or not brf_panel_open("units_panel") then return end
            reposition_filter_bar()
        end, 0.6)
    else
        if not brf_ui_locked() then
            move_filter_buttons_up()
            reposition_filter_bar()
        end
    end
end

local function prepare_footer(footer)
    -- 缩小 footer 高度，为 filter bar 腾出空间
    if not footer then return end
    if footer.SetCanResizeHeight then
        pcall(function() footer:SetCanResizeHeight(true) end)
    end
    if footer.SetCanResizeWidth then
        pcall(function() footer:SetCanResizeWidth(true) end)
    end
    if footer.Resize then
        pcall(function() footer:Resize(FILTER_FOOTER_WIDTH, 1) end)
    end
    if footer.SetCanResizeHeight then
        pcall(function() footer:SetCanResizeHeight(false) end)
    end
end

-- 将 filter_bar 绝对定位到 recruitment_options 底部（与其父级 recruitment_options 同坐标系）。
position_filter_bar = function(filter_bar, recruitment_options)
    -- 将 filter bar 放置在 recruitment_options 底部，与 footer 同层
    if not filter_bar then return end
    if filter_bar.SetVisible then
        pcall(function() filter_bar:SetVisible(true) end)
    end
    if filter_bar.SetCanResizeWidth then
        pcall(function() filter_bar:SetCanResizeWidth(true) end)
    end
    if filter_bar.SetCanResizeHeight then
        pcall(function() filter_bar:SetCanResizeHeight(true) end)
    end
    if filter_bar.Resize then
        pcall(function() filter_bar:Resize(FILTER_FOOTER_WIDTH, FILTER_FOOTER_HEIGHT) end)
    end
    -- 使用绝对定位：放在父容器底部
    if recruitment_options and filter_bar.MoveTo then
        local ok, parent_w, parent_h = pcall(function()
            return recruitment_options:Bounds()
        end)
        if ok and parent_w and parent_h then
            local bar_x = math.max(0, (parent_w - FILTER_FOOTER_WIDTH) / 2)
            local bar_y = math.max(0, parent_h - FILTER_FOOTER_HEIGHT + 4)
            pcall(function() filter_bar:MoveTo(bar_x, bar_y) end)
        end
    end
end

-- filter_bar 挂载到 recruitment_options 内部（保持可见性与招募视图同步）。
-- 由于 recruitment_options 的 LayoutEngine=List + sizetocontent，filter_bar 作为子组件
-- 会撑高容器并整体向上扩张。这是预期的（筛选栏本就占用底部空间）。
-- 为避免标题/关闭按钮被顶出屏幕，需要同步提高外层容器高度。
-- search_root 为 main_units_panel（或 units_panel），用于定位 recruitment_docker。
grow_containers_for_filter_bar = function(search_root)
    if not search_root then return end

    local recruitment_docker = find_uicomponent(search_root, "recruitment_docker")
    if not recruitment_docker then
        out("BetterRecruitFilter: grow 找不到 recruitment_docker")
        return
    end

    local function get_dims(uic)
        if not uic or not uic.Bounds then return nil, nil end
        local ok, w, h = pcall(function() return uic:Bounds() end)
        if ok and w and h then return w, h end
        return nil, nil
    end

    local docker_w, docker_h = get_dims(recruitment_docker)
    if not docker_w or not docker_h then
        out("BetterRecruitFilter: grow 无法读取 docker 尺寸")
        return
    end

    -- 首次调用时记录基线高度；docker_grown 保证多次调用（含延迟回调）目标值幂等。
    if docker_base_height == nil then
        docker_base_height = docker_h
    end

    local target_h = docker_base_height + FILTER_FOOTER_HEIGHT
    -- 若已被引擎动画重置回基线高度，则重新扩高；否则跳过。
    if docker_grown and math.abs(docker_h - target_h) <= 1 then
        return
    end

    if recruitment_docker.SetCanResizeHeight and recruitment_docker.Resize then
        pcall(function() recruitment_docker:SetCanResizeHeight(true) end)
        pcall(function() recruitment_docker:Resize(docker_w, target_h) end)
        docker_grown = true
        out("BetterRecruitFilter: docker 扩高 " .. tostring(docker_h) .. " -> " .. tostring(target_h)
            .. " (base=" .. tostring(docker_base_height) .. ")")
    end
end

local function ensure_filter_bar(search_root)
    if brf_ui_locked() then return nil end -- [czx patch]
    -- filter_bar 放在 recruitment_options 下，与 footer 平行（保持可见性随招募视图同步）
    local recruitment_options = find_uicomponent(
        search_root,
        "recruitment_docker",
        "recruitment_options"
    )
    if not recruitment_options then
        out("BetterRecruitFilter: recruitment_options not found")
        return nil
    end

    -- 缩小原版 footer（隐藏原始内容）
    local footer = find_uicomponent(recruitment_options, "footer")
    prepare_footer(footer)

    local filter_bar = find_uicomponent(recruitment_options, FILTER_BAR_ID)
    if filter_bar then
        position_filter_bar(filter_bar, recruitment_options)
        current_filter_bar = filter_bar
        current_recruitment_options = recruitment_options
        current_search_root = search_root
        grow_containers_for_filter_bar(search_root)
        return filter_bar
    end

    filter_bar = UIComponent(recruitment_options:CreateComponent(FILTER_BAR_ID, FILTER_BAR_TEMPLATE))
    if filter_bar then
        position_filter_bar(filter_bar, recruitment_options)
        current_filter_bar = filter_bar
        current_recruitment_options = recruitment_options
        current_search_root = search_root
        grow_containers_for_filter_bar(search_root)
        out("BetterRecruitFilter: injected filter bar via Lua")
        return filter_bar
    end

    current_filter_bar = nil
    current_recruitment_options = nil
    current_search_root = nil
    out("BetterRecruitFilter: failed to create filter bar from " .. FILTER_BAR_TEMPLATE)
    return nil
end

local function create_filter_buttons(filter_bar)
    -- 加载 i18n 翻译
    local lang_code = load_i18n()
    out("BetterRecruitFilter: i18n lang_code='" .. lang_code .. "'")

    for _, def in ipairs(PARENT_GROUP_DEFS) do
        local btn_id = "button_filter_" .. def.key
        local btn = find_uicomponent(filter_bar, btn_id)
        if not btn then
            btn = UIComponent(
                filter_bar:CreateComponent(btn_id, "ui/templates/square_medium_button_toggle.twui.xml")
            )
        end
        if btn then
            btn:SetImagePath(def.path, 0, false)
            apply_filter_button_style(btn)
            btn:SetTooltipText(tr(def.tooltip_key, def.tooltip_en), true)
            core:remove_listener("better_recruit_click_" .. def.key)
            core:add_listener(
                "better_recruit_click_" .. def.key,
                "ComponentLClickUp",
                function(context)
                    return context.string == btn_id
                end,
                function(context)
                    -- [czx patch] 推迟出点击派发窗再动树
                    cm:callback(function()
                        if brf_ui_locked() or not brf_panel_open("units_panel") then return end
                        toggle_group_filter(def.key)
                    end, 0.1)
                end,
                true
            )
            table.insert(filter_buttons, { btn = btn, btn_id = btn_id, group_key = def.key })
            out("BetterRecruitFilter: 创建按钮 '" .. btn_id .. "' lang='" .. lang_code .. "'")
        else
            out("BetterRecruitFilter: 创建按钮失败 '" .. btn_id .. "'")
        end
    end
    for _, def in ipairs(TIER_DEFS) do
        local btn_id = "button_filter_" .. def.key
        local btn = find_uicomponent(filter_bar, btn_id)
        if not btn then
            btn = UIComponent(
                filter_bar:CreateComponent(btn_id, "ui/templates/square_medium_button_toggle.twui.xml")
            )
        end
        if btn then
            btn:SetImagePath(def.path, 0, false)
            apply_filter_button_style(btn)
            btn:SetTooltipText(tr(def.tooltip_key, def.tooltip_en), true)
            core:remove_listener("better_recruit_click_" .. def.key)
            core:add_listener(
                "better_recruit_click_" .. def.key,
                "ComponentLClickUp",
                function(context)
                    return context.string == btn_id
                end,
                function(context)
                    -- [czx patch] 推迟出点击派发窗再动树
                    cm:callback(function()
                        if brf_ui_locked() or not brf_panel_open("units_panel") then return end
                        toggle_tier_filter(def.tier)
                    end, 0.1)
                end,
                true
            )
            table.insert(filter_buttons, { btn = btn, btn_id = btn_id, tier = def.tier })
            out("BetterRecruitFilter: create tier button '" .. btn_id .. "' lang='" .. lang_code .. "'")
        else
            out("BetterRecruitFilter: failed to create tier button '" .. btn_id .. "'")
        end
    end
    schedule_filter_button_positioning()
    out("BetterRecruitFilter: created " .. #filter_buttons .. " filter buttons")
end

local function on_units_panel_opened()
    if brf_ui_locked() then return end -- [czx patch]
    filter_buttons = {}
    card_base_visibility = {}
    hidden_by_filter = {}

    local units_panel = find_uicomponent(core:get_ui_root(), "units_panel")
    if not units_panel then
        out("BetterRecruitFilter: 未找到 units_panel")
        return
    end

    local main_units_panel = find_uicomponent(units_panel, "main_units_panel")
    local search_root = main_units_panel or units_panel
    local filter_bar = ensure_filter_bar(search_root)
    if not filter_bar then
        out("BetterRecruitFilter: 未找到 filter_bar 容器")
        return
    end

    create_filter_buttons(filter_bar)
    out("BetterRecruitFilter: 面板初始化完成")
end

local function reset_panel()
    active_group_filters = {}
    active_tier_filters = {}
    filter_buttons = {}
    card_base_visibility = {}
    hidden_by_filter = {}
    tree_dumped = false
    current_filter_bar = nil
    current_recruitment_options = nil
    current_search_root = nil
    -- docker 基线高度随面板关闭失效，下次打开重新采样
    docker_base_height = nil
    docker_grown = false
    out("BetterRecruitFilter: 面板已关闭，筛选状态已清除")
end

-- ============================================================
-- 模块入口
-- ============================================================
cm:add_first_tick_callback(function()
    core:add_listener(
        "better_recruit_filter_panel_opened",
        "PanelOpenedCampaign",
        function(context) return context.string == "units_panel" end,
        function()
            -- [czx patch] 派发内只做调度：延迟出派发窗，锁窗有限重试，面板已关即弃
            local attempts = 0
            local function deferred_init()
                attempts = attempts + 1
                if not brf_panel_open("units_panel") then return end
                if brf_ai_turn_processing() then return end
                if brf_ui_locked() then
                    if attempts < 8 then cm:callback(deferred_init, 0.5) end
                    return
                end
                on_units_panel_opened()
            end
            cm:callback(deferred_init, 0.2)
        end,
        true
    )
    core:add_listener(
        "better_recruit_filter_panel_closed",
        "PanelClosedCampaign",
        function(context) return context.string == "units_panel" end,
        function() reset_panel() end,
        true
    )
    out("BetterRecruitFilter: 模块已初始化")
end)
