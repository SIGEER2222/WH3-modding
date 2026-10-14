-- ============================================================================
-- zzzz_psw_tower.lua — 魔女高塔·肉鸽试炼 (P0)
--
-- 入口：星巫战法 -> 联动祈愿 -> 「星塔试炼」。
-- 玩法：30 层爬塔。每层择路——迎战守卫 / 探索秘境 / 星屑商铺 / 原地休整 /
--       离开高塔。祈愿军为试炼专属部队（战后自动补员，通关/撤退/败北即解散）。
--       星尘为独立通货（pooled resource，跨试炼保留），商铺消费。
-- 结构：floor 由玩家手动推进（不等回合）；第 5/15/25 层精英 x1.4，
--       第 10/20/30 层层主 x1.8/1.9/2.0；败北 = 试炼终结（GM式一命制）。
-- 平衡：敌军预算 = 2400 + floor*320，单位取自文化池 MP 造价带；玩家靠
--       招募奖励 + 商铺 + 将领升级成长；休整放弃收益仍会推层，防"躲层"白嫖。
-- ============================================================================

psw_tower = psw_tower or {}

local TLOG = "[psw_tower] "
local function tlog(msg) out(TLOG .. tostring(msg)) end
local function tpcall(name, fn)
    local ok, err = pcall(fn)
    if not ok then tlog(name .. " error: " .. tostring(err)) end
    return ok
end

-- ---------- 常量 ----------
local RES_KEY = "psw_tower_stardust"
local RES_FACTOR = "other"
local RES_FACTOR_EV = "events"

local DL = {
    OPENING = "psw_dilemma_tower_opening",
    NODE    = "psw_dilemma_tower_node",
    BATTLE  = "psw_dilemma_tower_battle",
    REWARD  = "psw_dilemma_tower_reward",
    BOON    = "psw_dilemma_tower_boon",
    REST    = "psw_dilemma_tower_rest",
    CD      = "psw_dilemma_tower_cd",
    SHOP    = "psw_dilemma_tower_shop",
    EVENT   = "psw_dilemma_tower_event",
    DEFEAT  = "psw_dilemma_tower_defeat",
    VICTORY = "psw_dilemma_tower_victory",
    SCHOOL  = "psw_dilemma_tower_school",
    SCHOOL2 = "psw_dilemma_tower_school2",
    DIGONG  = "psw_dilemma_tower_digong",
    CARDS   = "psw_dilemma_tower_cards",
}

local FLOORS_MAX = 30
local ELITE_FLOORS = { [5] = true, [15] = true, [25] = true }
local BOSS_FLOORS  = { [10] = 1.8, [20] = 1.9, [30] = 2.0 }
local SHOP_FLOORS  = { [3] = true, [8] = true, [13] = true, [18] = true, [23] = true, [28] = true }
local ELITE_MULT = 1.4
local AMBUSH_MULT = 1.3

-- 阶段主题分层：I 凡俗军势 / II 中坚混编 / III 超凡精锐；
-- Boss 层固定恶魔原体（exalted 将领是招牌）
local STAGE_THEMES = {
    [1] = { "grn", "nor", "bst", "emp", "tmb", "brt" },
    [2] = { "nur", "skv", "vmp", "chs", "def", "cth", "cst", "ksl" },
    [3] = { "tze", "sla", "dae", "ogr", "kho", "lzd", "hef", "chd", "wef",
            "dwf", "nag" },
}
local STAGE_BOSS_THEME = { [1] = "kho", [2] = "nur", [3] = "dae" }

-- 扩展敌方主题：塔之守卫是星辉凝成的各族回响，不限于混沌。
-- qb1 宿主派系全派系在 factions 表存在；将领 subtype 与 PLAYER_GENERALS 同源。
-- 运行时懒合并进 psw_tower_pools.ENEMY_THEMES——pools 文件自动生成不手改。
local EXTRA_THEMES = {
    lzd = { faction = "wh2_main_lzd_lizardmen_qb1",
            general = "wh2_main_lzd_saurus_old_blood",
            exalted = "wh2_main_lzd_saurus_old_blood",
            subculture = "wh2_main_sc_lzd_lizardmen" },
    hef = { faction = "wh2_main_hef_high_elves_qb1",
            general = "wh2_main_hef_prince", exalted = "wh2_main_hef_prince",
            subculture = "wh2_main_sc_hef_high_elves" },
    def = { faction = "wh2_main_def_dark_elves_qb1",
            general = "wh2_main_def_dreadlord",
            exalted = "wh2_main_def_dreadlord",
            subculture = "wh2_main_sc_def_dark_elves" },
    dwf = { faction = "wh_main_dwf_dwarfs_qb1",
            general = "wh_main_dwf_lord", exalted = "wh_main_dwf_lord",
            subculture = "wh_main_sc_dwf_dwarfs" },
    emp = { faction = "wh_main_emp_empire_qb1",
            general = "wh_main_emp_lord", exalted = "wh_main_emp_lord",
            subculture = "wh_main_sc_emp_empire" },
    cth = { faction = "wh3_main_cth_cathay_qb1",
            general = "wh3_main_cth_lord_magistrate_yang",
            exalted = "wh3_main_cth_lord_magistrate_yang",
            subculture = "wh3_main_sc_cth_cathay" },
    ksl = { faction = "wh3_main_ksl_kislev_qb1",
            general = "wh3_main_ksl_boyar", exalted = "wh3_main_ksl_boyar",
            subculture = "wh3_main_sc_ksl_kislev" },
    brt = { faction = "wh_main_brt_bretonnia_qb1",
            general = "wh_main_brt_lord", exalted = "wh_main_brt_lord",
            subculture = "wh_main_sc_brt_bretonnia" },
    wef = { faction = "wh_dlc05_wef_wood_elves_qb1",
            general = "wh_dlc05_wef_glade_lord",
            exalted = "wh_dlc05_wef_glade_lord",
            subculture = "wh_dlc05_sc_wef_wood_elves" },
    tmb = { faction = "wh2_dlc09_tmb_tombking_qb1",
            general = "wh2_dlc09_tmb_tomb_king",
            exalted = "wh2_dlc09_tmb_tomb_king",
            subculture = "wh2_dlc09_sc_tmb_tomb_kings" },
    cst = { faction = "wh2_dlc11_cst_vampire_coast_qb1",
            general = "wh2_dlc11_cst_admiral_vampires",
            exalted = "wh2_dlc11_cst_admiral_vampires",
            subculture = "wh2_dlc11_sc_cst_vampire_coast" },
    chd = { faction = "wh3_dlc23_chd_chaos_dwarfs_qb1",
            general = "wh3_dlc23_chd_overseer",
            exalted = "wh3_dlc23_chd_overseer",
            subculture = "wh3_dlc23_chd_chaos_dwarfs" },
    nag = { faction = "wh3_dlc29_nag_host_of_nagash_qb1",
            general = "wh_main_vmp_lord", exalted = "wh_main_vmp_lord",
            subculture = "wh3_dlc29_sc_nag_undead_legions" },
}
local themes_merged = false
local function enemy_themes()
    if not themes_merged and psw_tower_pools then
        psw_tower_pools.ENEMY_THEMES = psw_tower_pools.ENEMY_THEMES or {}
        for k, v in pairs(EXTRA_THEMES) do
            psw_tower_pools.ENEMY_THEMES[k] =
                psw_tower_pools.ENEMY_THEMES[k] or v
        end
        themes_merged = true
    end
    return (psw_tower_pools and psw_tower_pools.ENEMY_THEMES) or {}
end

local REST_STARDUST = 8
local SKIP_EVENT_STARDUST = 5
local REWARD_SKIP_STARDUST = 25
local VICTORY_TREASURY = 12000
local VICTORY_STARDUST = 200

local SHOP_TIERS = {
    { price = 350,  min = 300, max = 700,  text = "psw_tower_pl_shop_unit_low"  },
    { price = 700,  min = 701, max = 1200, text = "psw_tower_pl_shop_unit_mid"  },
    { price = 1300, min = 1201,max = 2000, text = "psw_tower_pl_shop_unit_high" },
}

-- ---------- saved value 键 ----------
local SK = {
    run     = "psw_twr_run",
    state   = "psw_twr_state",     -- node/battle_pending/battle/reward/shop/event
    floor   = "psw_twr_floor",
    pf      = "psw_twr_pfaction",
    pgen    = "psw_twr_pgen_sub",
    pfcqi   = "psw_twr_pforce",
    pl      = "psw_twr_pleader",
    region  = "psw_twr_region",
    ef      = "psw_twr_efaction",
    efcqi   = "psw_twr_eforce",
    el      = "psw_twr_eleader",
    pend    = "psw_twr_pend",      -- kind|theme|budget|units_csv
    snap    = "psw_twr_snap",
    rank    = "psw_twr_rank",
    rewards = "psw_twr_rewards",
    shop    = "psw_twr_shop",
    shopuse = "psw_twr_shopuse",
    ev      = "psw_twr_ev",
    st      = "psw_twr_stage",
    sdust   = "psw_twr_sdust",
    paths   = "psw_twr_paths",     -- 本层掷出的路径 CSV
    boonopt = "psw_twr_boonopt",   -- 本局祝福三选一选项 CSV
    boons   = "psw_twr_boons",     -- 已获祝福 CSV
    lastend = "psw_twr_lastend",   -- 上次 run 结束回合（冷却用）
    modsd   = "psw_twr_mod_sd",    -- 星尘获取加成
    modshop = "psw_twr_mod_shop",  -- 商店折扣
    modrest = "psw_twr_mod_rest",  -- 休整收益加成
    modev   = "psw_twr_mod_ev",    -- 事件星尘加成
    riv     = "psw_twr_rival",     -- 竞逐者当前层数
    rivmark = "psw_twr_rivmark",   -- 已播报里程碑 CSV
    rivwon  = "psw_twr_rivwon",    -- 竞逐者已抢先登顶
    el2     = "psw_twr_eleader2",  -- Boss 援军敌将 cqi
    cdann   = "psw_twr_cdann",     -- 本冷却期"高塔再启"是否已播报
    school  = "psw_twr_school",    -- 本局试炼流派
    mut     = "psw_twr_mut",       -- 本局敌军词缀（fury/bulwark/swift/blood/ward）
    digong  = "psw_twr_digong",    -- 帝弓垂询待决："fname|target_fname"
    cards   = "psw_twr_cards",     -- 星辉卡牌手牌，逗号串（≤CARD_MAX）
    dlg     = "psw_twr_dlg",       -- 待决困境锁（防重复入塔叠困境；跨回合自动过期）
    dlgturn = "psw_twr_dlgturn",   -- dlg 锁记下的签发回合号，跨回合即视为僵尸锁
    wager   = "psw_twr_wager",     -- 星赌押注：下战胜利返还额
    selfmald = "psw_twr_selfmald", -- 自谴试炼标志（开局自加难度换加成）
    pthemes = "psw_twr_pthemes",   -- 路径预掷敌主题 CSV "kind:theme"（节点揭示）
    lastfl  = "psw_twr_lastfl",    -- 上次播报楼层（层数 feed 去重）
}
local RUN_CD = 3                                   -- run 结束后冷却回合数
local SD_CAP_RETREAT = 4                           -- 主动撤退清算上限（>败北的2——push-your-luck）
-- ---------- 试炼流派（school） ----------
-- 入塔选定流派，整局约束编队/招募池/文化祝福——同一座塔，五种道。
-- castes 为空=全池；cul 覆盖文化祝福组；want=初始编队配额；startcap=初始造价上限。
local SCHOOLS = {
    standard = { name = "psw_twr_sch_standard",
        want = { frontline = 3, missile = 2, cavalry = 1 } },
    melee    = { name = "psw_twr_sch_melee", cul = "melee",
        castes = { melee_infantry = true, melee_cavalry = true,
                   chariot = true, monstrous_infantry = true },
        want = { frontline = 4, cavalry = 2 } },
    shoot    = { name = "psw_twr_sch_shoot", cul = "shoot",
        castes = { missile_infantry = true, missile_cavalry = true,
                   artillery = true },
        want = { frontline = 1, missile = 4, cavalry = 1 } },
    arcane   = { name = "psw_twr_sch_arcane", cul = "arcane",
        want = { frontline = 2, missile = 2, cavalry = 1, monster = 1 } },
    monster  = { name = "psw_twr_sch_monster", cul = "wall",
        castes = { monster = true, monstrous_infantry = true,
                   monstrous_cavalry = true },
        want = { monster = 3, cavalry = 2 }, startcap = 1200 },
    -- 英杰·御灵：单将领主启程，招募=灵契召唤兽（巨兽系，消耗品）；
    -- 将领起15级挂专属效果包，每胜+2级，星尘×1.3 孤胆加成。
    lord     = { name = "psw_twr_sch_lord", cul = "arcane",
        castes = {}, nofb = true, summon = true, want = {},
        sd_mult = 1.3, start_rank = 15 },
}
-- 第一页四道+FIFTH 翻页；第二页 monster/lord/back（可续加新道）
local SCHOOL_ORDER = { "standard", "melee", "shoot", "arcane" }
local SCHOOL_ORDER2 = { "monster", "lord" }

-- 星辉竞逐者（rlt_spire 竞速机制移植）：玩家回合权重推进，
-- 抢先登顶 → 终层 Boss +1 援军且通关收益减半
local RIVAL_TOP = 30
local RIVAL_MILESTONES = { {10, "m1"}, {20, "m2"}, {29, "m3"} }
local RIVAL_REINF_BUDGET = 0.45   -- 援军预算占本层 Boss 预算比例

local function sv(k, d)
    local v = cm:get_saved_value(k)
    if v == nil then return d end
    return v
end
local function svn(k, d) return tonumber(sv(k, d)) or d end
local function svs(k, v) cm:set_saved_value(k, v) end

-- cm:random_number 是方法调用，不能作为裸回调传递（self 会变成数字）
local function rnd(n) return cm:random_number(n) end

local function tower_faction()
    local fk = sv(SK.pf, "")
    if fk == "" then return nil end
    local f = cm:get_faction(fk)
    if f and not f:is_null_interface() then return f end
    return nil
end

local function tower_general()
    local cqi = svn(SK.pl, 0)
    if cqi <= 0 then return nil end
    local ch = cm:get_character_by_cqi(cqi)
    if ch and not ch:is_null_interface() then return ch end
    return nil
end

local function tower_force()
    local cqi = svn(SK.pfcqi, 0)
    if cqi <= 0 then return nil end
    local f = cm:get_military_force_by_cqi(cqi)
    if f and not f:is_null_interface() then return f end
    return nil
end

-- 星尘权威余额存 saved_value：campaign_group 授予的 pooled resource 只在
-- 新档初始化时创建，旧存档/未授予派系拿不到资源对象，余额必须以 sv 为准；
-- pooled resource 仅作镜像（存在时顺带点亮资源栏）。
local function stardust(faction)
    return svn(SK.sdust, 0)
end

local function mirror_stardust(faction_name, amount, ev_factor)
    pcall(function()
        cm:faction_add_pooled_resource(faction_name, RES_KEY,
            ev_factor and RES_FACTOR_EV or RES_FACTOR, amount)
    end)
end

-- ---------- PSW 本体经济融合 ----------
-- 共鸣水晶双向流通：通关/清算星尘→水晶；商店水晶→星尘。
local GMSJ_KEY = "psw_main_gmsj"
local GMSJ_FACTOR = "psw_main_gmsj_event_good"
local VICTORY_GMSJ = 5          -- 登顶固定收益
local SD_RATE = 150             -- 星尘→水晶清算率
local SD_CAP_VICTORY = 5        -- 通关清算上限
local SD_CAP_QUIT = 2           -- 撤退/败北清算上限
local TALENT_RANK_PER = 20      -- 每20个本体天赋，祈愿军将领+1级
local TALENT_RANK_CAP = 5
local SHOP_GMSJ_STARDUST = 150  -- 商店兑换：1水晶→150星尘

local function add_gmsj(faction_name, amount)
    if not amount or amount == 0 then return end
    cm:faction_add_pooled_resource(faction_name, GMSJ_KEY, GMSJ_FACTOR, amount)
end

local function tower_gmsj(faction)
    local ok, res = pcall(function()
        return faction:pooled_resource_manager():resource(GMSJ_KEY):value()
    end)
    return (ok and res) or 0
end

local function tower_talent_count(faction_name)
    local pd = psw_main_data and psw_main_data.player_data
        and psw_main_data.player_data[faction_name] or nil
    if not pd then return 0 end
    return (pd.nor_count or 0) + (pd.ex_count or 0)
end

local function add_stardust(faction_name, amount, ev_factor)
    amount = math.floor(tonumber(amount) or 0)
    if amount == 0 then return end
    svs(SK.sdust, math.max(0, svn(SK.sdust, 0) + amount))
    mirror_stardust(faction_name, amount, ev_factor)
end

-- ---------- 星辉赐福（boon）系统 ----------
-- 祝福 = 部队级效果包挂在祈愿军上（run 结束随部队解散/移除），
-- lua= 类祝福走 SK.mod* 数值修正，不落 DB 包。
local BOON_INDEX = {}
for _, b in ipairs((psw_tower_pools and psw_tower_pools.BOONS) or {}) do
    BOON_INDEX[b.key] = b
end

local function mod_val(key) return svn(key, 0) end

-- ---------- MCT（groovy_mct 软依赖） ----------
-- MCT 缺席/mid-campaign 加载失败时全部取默认值；运行时逐次读取，
-- 玩家在设置面板改完立即生效（无需重启）。选项定义见
-- script/mct/settings/psw_tower_mct.lua。
local function mct_opt(key)
    if type(get_mct) ~= "function" then return nil end
    local ok, v = pcall(function()
        local mct = get_mct()
        local mod = mct and mct:get_mod_by_key("psw_tower")
        local opt = mod and mod:get_option_by_key(key)
        return opt and opt:get_finalized_setting()
    end)
    return ok and v or nil
end
-- 调试直写文件：绕过脚本日志缓冲（崩溃前最后的输出也会落盘）
local DBGLOG = "E:\\Code\\WH3-modding\\scratch\\tower_dbg.log"
local function flog(s)
    out(TLOG .. "fl " .. tostring(s))   -- 同步进 script_log，io 沙箱下也能看到
    local ok, h = pcall(io.open, DBGLOG, "a")
    if ok and h then h:write(tostring(s) .. "\n"); h:close() end
end

-- MCT 值缓存：同一选项一次读取后复用纯 Lua 值——实测连续两次对同一
-- option 走 get_mod_by_key→get_option_by_key→get_finalized_setting 原生链
-- 会在第二次调用触发引擎空指针崩溃（Warhammer3.exe+0x244a397 三次同址）。
-- 每回合 FactionTurnStart 清空，MCT 面板改动最迟下回合生效。
local _mctv = {}
local _miss = {}
local function mct_cached(key)
    local v = _mctv[key]
    if v == nil then
        v = mct_opt(key)
        _mctv[key] = (v == nil) and _miss or v
    end
    if v == _miss then return nil end
    return v
end
local function mct_num(key, d)
    return tonumber(mct_cached(key)) or d
end
local function mct_bool(key, d)
    local v = mct_cached(key)
    return type(v) == "boolean" and v or d
end

-- 军队单位上限：原版 20，当前环境装了改上限 mod（默认 30，MCT 可调）。
-- 起步编成/敌军满编数一律按 cap 动态推导，不写死 20。
local function army_cap()
    return math.max(20, math.floor(mct_num("army_cap", 30)))
end

-- 正向收益统一走这里，吃 聚星/星库 类加成与 MCT 倍率
local function gain_stardust(fname, amount, ev_factor)
    if amount and amount > 0 then
        local mult = (1 + mod_val(SK.modsd)) * mct_num("sd_mult", 1)
        if ev_factor then mult = mult + mod_val(SK.modev) end
        local sch = SCHOOLS[sv(SK.school, "standard")]
        mult = mult * ((sch and sch.sd_mult) or 1)
        amount = math.floor(amount * mult)
    end
    add_stardust(fname, amount, ev_factor)
end

local function shop_price(base)
    return math.max(1, math.floor(base * (1 - mod_val(SK.modshop))
        * mct_num("shop_price_mult", 1)))
end

local function boon_culture_group(faction)
    -- 流派覆盖优先：选定流派的专属祝福组取代派系文化映射
    local s = SCHOOLS and SCHOOLS[sv(SK.school, "standard")]
    if s and s.cul then return s.cul end
    local ok, sc = pcall(function() return faction:subculture() end)
    local m = psw_tower_pools and psw_tower_pools.BOON_CULTURE
    if ok and type(sc) == "string" and m and m[sc] then return m[sc] end
    return "wall"
end

local function boon_list()  -- 已获祝福 key 列表
    local t = {}
    for k in sv(SK.boons, ""):gmatch("[^,]+") do t[#t + 1] = k end
    return t
end

local function boon_count()
    local n = 0
    for _ in sv(SK.boons, ""):gmatch("[^,]+") do n = n + 1 end
    return n
end

local function curse_list()
    local t = {}
    for k in sv(SK.boons, ""):gmatch("[^,]+") do
        local b = BOON_INDEX[k]
        if b and b.rar == "c" then t[#t + 1] = k end
    end
    return t
end

local function apply_boon(key)
    local b = BOON_INDEX[key]
    if not b then return end
    if b.fx then
        local cqi = svn(SK.pfcqi, 0)
        if cqi > 0 then
            tpcall("apply_boon_" .. key, function()
                cm:remove_effect_bundle_from_force("psw_twr_boon_" .. key, cqi)
                cm:apply_effect_bundle_to_force("psw_twr_boon_" .. key, cqi, 0)
            end)
        end
    end
    if b.lua then
        for pair in b.lua:gmatch("[^;]+") do
            local m, v = pair:match("(%a+):([%d%.%-]+)")
            local sk = ({sd=SK.modsd, shop=SK.modshop, rest=SK.modrest, ev=SK.modev})[m]
            if sk and v then svs(sk, mod_val(sk) + tonumber(v)) end
        end
    end
    svs(SK.boons, (sv(SK.boons, "") ~= "" and sv(SK.boons, "") .. "," or "") .. key)
    tlog("boon gained: " .. key .. " (" .. (b.name or "?") .. ")")
end

local function remove_boon(key)
    local b = BOON_INDEX[key]
    if not b then return end
    if b.fx then
        local cqi = svn(SK.pfcqi, 0)
        if cqi > 0 then
            tpcall("remove_boon_" .. key, function()
                cm:remove_effect_bundle_from_force("psw_twr_boon_" .. key, cqi)
            end)
        end
    end
    local kept = {}
    for _, k in ipairs(boon_list()) do if k ~= key then kept[#kept + 1] = k end end
    svs(SK.boons, table.concat(kept, ","))
end

local function clear_boons()
    local cqi = svn(SK.pfcqi, 0)
    for _, k in ipairs(boon_list()) do
        local b = BOON_INDEX[k]
        if b and b.fx and cqi > 0 then
            tpcall("clear_boon_" .. k, function()
                cm:remove_effect_bundle_from_force("psw_twr_boon_" .. k, cqi)
            end)
        end
    end
    svs(SK.boons, ""); svs(SK.boonopt, "")
    svs(SK.modsd, 0); svs(SK.modshop, 0); svs(SK.modrest, 0); svs(SK.modev, 0)
end

-- ---------- 星辉竞逐者（rival）----------
-- 吸收 rlt_spire 竞速对手：run 进行中每个玩家回合权重推进 0~2 层，
-- 里程碑事件推送；抢先登顶 → 终层 Boss 带援军 + 通关收益减半。
-- index 225 = event_feed_events 中 scripted_transient_event 行（图标类型；
-- 偏差只影响 feed 图标，CA 自家脚本也有用超界值的先例）
local EFT_SCRIPTED_EVENT = 225
local function tower_msg(faction, title_key, body_key, sub_key)
    tpcall("tower_msg", function()
        cm:show_message_event(faction:name(),
            "event_feed_strings_text_" .. title_key,
            "event_feed_strings_text_" .. body_key,
            "event_feed_strings_text_" .. (sub_key or title_key),
            false, EFT_SCRIPTED_EVENT)
    end)
end

-- 竞逐者推进到指定层：里程碑播报+抢先登顶判定（回合推进与层间咬尾共用）
local function rival_set(faction, nf)
    svs(SK.riv, nf)
    local raw = sv(SK.rivmark, "")
    local seen = "," .. raw .. (raw ~= "" and "," or "")
    for _, m in ipairs(RIVAL_MILESTONES) do
        if nf >= m[1] and not seen:find("," .. m[2] .. ",", 1, true) then
            raw = (raw ~= "" and raw .. "," or "") .. m[2]
            svs(SK.rivmark, raw)
            seen = seen .. m[2] .. ","
            tower_msg(faction, "psw_twr_rival_title", "psw_twr_rival_" .. m[2],
                "psw_twr_rival_sub")
        end
    end
    if nf >= RIVAL_TOP then
        svs(SK.rivwon, true)
        tower_msg(faction, "psw_twr_rival_title", "psw_twr_rival_win",
            "psw_twr_rival_sub")
        tlog("rival reached top first")
    end
end

local function rival_tick(faction)
    if not mct_bool("rival_enable", true) then return end
    if not sv(SK.run, false) or sv(SK.rivwon, false) then return end
    -- 推进倍率作用于两档概率（默认 55%走1层/25%走2层，期望 0.95 层/回合）
    local pace = mct_num("rival_pace", 1)
    local p1 = math.min(100, math.floor(55 * pace))
    local p2 = math.min(100 - p1, math.floor(25 * pace))
    local r = rnd(100)
    local step = (r <= p1) and 1 or (r <= p1 + p2) and 2 or 0
    if step > 0 then rival_set(faction, svn(SK.riv, 0) + step) end
end

-- 层间咬尾：玩家每进一层竞逐者有概率跟进——快玩家也会被咬
-- （原版只按回合推进，一心爬塔者一两回合刷完则竞逐者形同虚设）
local function rival_chase(faction)
    if not mct_bool("rival_enable", true) or sv(SK.rivwon, false) then return end
    if rnd(100) <= mct_num("rival_chase", 30) then
        rival_set(faction, svn(SK.riv, 0) + 1)
    end
end

-- 冷却到点 → 事件推送一次"高塔再启"（rlt_spire 的裂隙周期开合等价物：
-- 入塔走 doctrine 随时可点，周期开合退化为"冷却结束通知"）
local function reopen_notice(faction)
    if sv(SK.run, false) or sv(SK.cdann, false) then return end
    local last = svn(SK.lastend, -99)
    if last < 0 then return end
    if cm:turn_number() - last >= mct_num("run_cd", RUN_CD) then
        svs(SK.cdann, true)
        tower_msg(faction, "psw_twr_reopen_title", "psw_twr_reopen_body",
            "psw_twr_reopen_sub")
        tlog("reopen notice fired")
    end
end

-- ---------- 生态联动（软依赖：Lin 集成战略/英灵召唤/无双英雄） ----------
-- 全部走存在性探测 + tpcall；缺席回退星尘/水晶，"有联动更赚，无联动可玩"。
local LIN_COUPON = "lin_all_coupon"            -- 集成战略·通宝
local LIN_INGOT  = "lin_all_originium_ingot"   -- 集成战略·源石锭

local function link_msg(faction, body_key)
    tower_msg(faction, "psw_twr_link_title", body_key, "psw_twr_link_sub")
end

-- 资源是否对该派系实际存在（campaign_group 新档才初始化，旧档可能缺席）
local function res_value(faction, res_key)
    local ok, v = pcall(function()
        local r = faction:pooled_resource(res_key)
        return r and r:value() or -1
    end)
    if not ok or v == nil then return -1 end
    return v
end

local function grant_lin_res(faction, res_key, amount)
    local before = res_value(faction, res_key)
    if before < 0 then return false end   -- 资源未初始化=mod缺席/旧档无此资源
    tpcall("link_res", function()
        cm:faction_add_pooled_resource(faction:name(), res_key, amount, "events")
    end)
    local after = res_value(faction, res_key)
    if after > before then return true end
    -- 读数未涨视为发放失败（资源存在但写不进），回退交给调用方
    return false
end

local function find_faction_subtype(faction, subtype)
    local ok, found = pcall(function()
        local list = faction:character_list()
        for i = 0, list:num_items() - 1 do
            local c = list:item_at(i)
            if c:character_subtype_key() == subtype then return c end
        end
    end)
    return ok and found or nil
end

-- 英灵召唤（lin_summon_servant）：随机未拥有从者入世于领袖旁
local function grant_servant(faction)
    if type(summon_servant) ~= "table"
        or type(summon_servant.select_character) ~= "function"
        or type(summon_servant.add_character) ~= "function" then return false end
    local sel
    tpcall("link_servant_sel", function()
        sel = summon_servant:select_character(faction)
    end)
    if not sel then return false end
    return tpcall("link_servant", function()
        summon_servant:add_character(faction, sel)
    end)
end

-- Lin 装备池（英灵召唤附属）：60/30/10 三档随机随从装
local function grant_lin_ancillary(faction)
    if type(summon_servant) ~= "table"
        or type(summon_servant.add_ancillary) ~= "function" then return false end
    return tpcall("link_anc", function() summon_servant:add_ancillary(faction) end)
end

-- 塔限定圣物（本包自制 ancillary，unique_to_faction 防重复；
-- psw_twr_rels 存档键记录已发，避免重复抽到）
local TOWER_RELICS = {
    "psw_twr_anc_weapon_starblade",
    "psw_twr_anc_armour_starplate",
    "psw_twr_anc_talisman_dust",
    "psw_twr_anc_ench_starmap",
    "psw_twr_anc_ench_rival",
    "psw_twr_anc_arcane_starglobe",
    "psw_twr_anc_weapon_starbow",
}
local REL_OWN = "psw_twr_rels"
local function grant_tower_relic(faction)
    local own = {}
    for k in sv(REL_OWN, ""):gmatch("[^,]+") do own[k] = true end
    local avail = {}
    for _, k in ipairs(TOWER_RELICS) do
        if not own[k] then avail[#avail + 1] = k end
    end
    if #avail == 0 then return false end
    local key = avail[cm:random_number(#avail)]
    local ok = tpcall("link_relic", function()
        cm:add_ancillary_to_faction(faction, key, false)
    end)
    if ok then
        svs(REL_OWN, (sv(REL_OWN, "") ~= "" and sv(REL_OWN, "") .. "," or "") .. key)
    end
    return ok
end

-- 魔女亲授：从 PSW 本体 EX 天赋池抽一，直接写入派系祈愿槽
-- （走官方 foreign_slot 授予链，槽满则不发）
local function grant_psw_talent(faction)
    if type(psw_get_talent_slot_manager) ~= "function" then return false end
    local fname = faction:name()
    local pool = {}
    for _, k in ipairs(psw_tower_pools.PSW_EX_TALENTS or {}) do
        if not faction:has_effect_bundle("set_" .. k)
            and not faction:has_effect_bundle("set_main_" .. k)
            and not (psw_main_data and psw_main_data.global_data
                and psw_main_data.global_data["set_main_" .. k] == true) then
            pool[#pool + 1] = k
        end
    end
    if #pool == 0 then return false end
    local key = pool[cm:random_number(#pool)]
    local granted = false
    tpcall("link_talent", function()
        local fsm = psw_get_talent_slot_manager(fname)
        if not fsm then return end
        local slots = fsm:slots()
        if not slots then return end
        for i = 0, slots:num_items() - 1 do
            local slot = slots:item_at(i)
            if slot and not slot:is_null_interface() and not slot:has_building() then
                cm:foreign_slot_instantly_upgrade_building(slot, key)
                granted = true
                tlog("talent granted: " .. key)
                return
            end
        end
    end)
    return granted
end

-- 记忆结晶馈赠：把"真结晶"直接解锁进玩家什亭之匣（PSW 原生卡槽，
-- 原生 UI/消耗/音效全保留）。品级沿用 PSW 原生 lv1-5 分池：
-- JYJJ_N=lv1-2+基础卡，JYJJ_R=lv3-4 战役侧有效卡，JYJJ_S=lv5 真·超能力卡。
-- 鸣潮系卡（"mc:共鸣者键|卡键"格式）仅在该共鸣者已激活时入池。
local function jyjj_pool_of(tier)
    return psw_tower_pools and psw_tower_pools["JYJJ_" .. tier] or {}
end

local function jyjj_card_ready(fname, entry)
    -- "mc:<gmz_key>|<card_key>" → 鸣潮共鸣者过滤；纯卡键直通
    local gmz, key = entry:match("^mc:([a-z0-9_]+)|(.+)$")
    key = key or entry
    if not (psw_main_data and psw_main_data.player_data
        and psw_main_data.player_data[fname]
        and psw_main_data.player_data[fname].crt_card
        and psw_main_data.player_data[fname].crt_card[key]) then
        return nil  -- 玩家无结晶槽（非 PSW 体系派系或数据未初始化）
    end
    if gmz then
        local g = psw_main_data.player_data[fname].mc_data
            and psw_main_data.player_data[fname].mc_data.gmz_data
        if not (g and g[gmz] and g[gmz].is_on) then return nil end
    end
    return key
end

local function grant_jyjj_card(faction, tier)
    if type(psw_jyjj_main_unlock) ~= "function" then return false end
    local fname = faction:name()
    local pool = {}
    for _, e in ipairs(jyjj_pool_of(tier)) do
        local k = jyjj_card_ready(fname, e)
        if k then pool[#pool + 1] = k end
    end
    if #pool == 0 then return false end
    local key = pool[cm:random_number(#pool)]
    return tpcall("jyjj_grant", function()
        psw_jyjj_main_unlock(fname, key, true)   -- 解锁 + card_num+1
        -- 附赠使用资源：体力+2、次数+1（结晶消耗这两项，光发卡不够使）
        if type(psw_jyjj_tili_num_change) == "function" then
            psw_jyjj_tili_num_change(fname, 2, "heal")
        end
        if type(psw_jyjj_use_num_change) == "function" then
            psw_jyjj_use_num_change(fname, 1, "heal")
        end
        tlog("jyjj card granted [" .. tier .. "]: " .. key)
        return true
    end) == true
end

-- 登顶临时馈赠：派系全军效果包 3 回合
local VICTORY_GIFTS = { "psw_twr_gift_might", "psw_twr_gift_ward" }
local function grant_victory_buff(fname)
    tpcall("gift_buff", function()
        cm:apply_effect_bundle(
            VICTORY_GIFTS[cm:random_number(#VICTORY_GIFTS)], fname, 3)
    end)
end

-- 帝弓降世：复刻符玄仪式语义——屠灭目标派系全部「将领带军」角色
-- （kill_character_and_commanded_unit）。守卫照抄 PSW 本体规则：
-- 非人类目标 + 排除 _qb<数字> 剧情战役派系 + 魔王派系豁免；
-- 另加塔自有限定：仅与玩家交战派系（馈赠用途，不打中立）。
local function digong_has_armies(f)
    local ok, n = pcall(function()
        local cl = f:character_list()
        for j = 0, cl:num_items() - 1 do
            if cm:char_is_general_with_army(cl:item_at(j)) then return 1 end
        end
        return 0
    end)
    return ok and n == 1
end

local function digong_target(player_faction)
    local best, best_rank = nil, nil
    local mw_key = (psw_main_data and psw_main_data.global_data
        and psw_main_data.global_data.tfmw_is_start
        and psw_mowang_data and psw_mowang_data.mowang_faction_key) or nil
    tpcall("digong_scan", function()
        local fl = cm:model():world():faction_list()
        for i = 0, fl:num_items() - 1 do
            local f = fl:item_at(i)
            local name = f:name()
            if not f:is_null_interface() and not f:is_human()
                and name ~= player_faction:name() and name ~= mw_key
                and not name:find("_qb%d+$")
                and f:at_war_with(player_faction)
                and digong_has_armies(f) then
                local r = cm:model():world():faction_strength_rank(f)
                if type(r) == "number" and (not best_rank or r < best_rank) then
                    best, best_rank = f, r
                end
            end
        end
    end)
    return best
end

local function fire_digong(player_faction, target_name)
    local n = 0
    tpcall("digong_fire", function()
        local tf = cm:get_faction(target_name)
        if not tf or tf:is_null_interface() then return end
        local cl = tf:character_list()
        for j = 0, cl:num_items() - 1 do
            local ch = cl:item_at(j)
            if cm:char_is_general_with_army(ch) then
                cm:kill_character_and_commanded_unit(
                    cm:char_lookup_str(ch), true)
                n = n + 1
            end
        end
    end)
    tlog("digong fired at " .. target_name .. ", armies wiped=" .. n)
    return n
end

-- ---------- 星辉卡牌（roguelike 主动道具：出塔可用的战役侧超能力） ----------
-- 存 SK.cards 逗号串（最多 CARD_MAX 张），入手即存、用时即销；
-- 经 OPENING THIRD / CD SECOND 的「星辉手牌」进入牌单困境使用。
local CARD_MAX = 4

local function card_list()
    local t = {}
    for k in sv(SK.cards, ""):gmatch("[^,]+") do t[#t + 1] = k end
    return t
end

local function card_add(faction, key)
    local t = card_list()
    if #t >= CARD_MAX then
        -- 手牌满：自动折价为星尘馈赠，不丢不卡死
        add_stardust(faction:name(), 30)
        link_msg(faction, "psw_twr_card_overflow")
        return false
    end
    t[#t + 1] = key
    svs(SK.cards, table.concat(t, ","))
    return true
end

local CARD_ORDER = { "march", "recall", "heal", "winds",
                     "sight", "order", "smith", "crystal" }

local function card_random(faction)
    local key = CARD_ORDER[cm:random_number(#CARD_ORDER)]
    if card_add(faction, key) then
        tlog("card gained: " .. key)
        link_msg(faction, "psw_twr_card_gain_" .. key)
    end
end

-- 塔军自身不计入卡牌目标（防止对祈愿军/塔领主动作破坏 run 空间模型）
local function is_tower_force_cqi(cqi) return cqi > 0 and cqi == svn(SK.pfcqi, 0) end

local function player_generals(faction)
    local out = {}
    local mfl = faction:military_force_list()
    for i = 0, mfl:num_items() - 1 do
        local mf = mfl:item_at(i)
        if not is_tower_force_cqi(mf:command_queue_index())
            and mf:has_general() then
            out[#out + 1] = mf:general_character()
        end
    end
    return out
end

local CARD_DEFS = {
    -- 星步：全军行动力回满（含英雄）
    march = function(faction)
        local n = 0
        for _, gen in ipairs(player_generals(faction)) do
            cm:replenish_action_points(cm:char_lookup_str(gen)); n = n + 1
        end
        return n > 0
    end,
    -- 归星：派系领袖（无则任一领军将领）折返首都
    recall = function(faction)
        local gen = nil
        local lead = faction:faction_leader()
        if lead and not lead:is_null_interface()
            and cm:char_is_general_with_army(lead)
            and not is_tower_force_cqi(lead:military_force():command_queue_index()) then
            gen = lead
        else
            gen = player_generals(faction)[1]
        end
        local home = faction:home_region()
        if gen and home and not home:is_null_interface() then
            cm:teleport_to(cm:char_lookup_str(gen),
                home:logical_position_x(), home:logical_position_y())
            return true
        end
        return false
    end,
    -- 星愈：全军单位血量回满
    heal = function(faction)
        local n = 0
        for _, gen in ipairs(player_generals(faction)) do
            local ul = gen:military_force():unit_list()
            for i = 0, ul:num_items() - 1 do
                cm:set_unit_hp_to_unary_of_maximum(ul:item_at(i), 1); n = n + 1
            end
        end
        return n > 0
    end,
    -- 星风：全军队魔风储备+15，持续 1 回合（DB 效果包）
    winds = function(faction)
        cm:apply_effect_bundle("psw_twr_card_winds", faction:name(), 1)
        return true
    end,
    -- 星眸：揭开全图迷雾
    sight = function(faction)
        local rl = cm:model():world():region_manager():region_list()
        for i = 0, rl:num_items() - 1 do
            cm:make_region_visible_in_shroud(faction:name(),
                rl:item_at(i):name())
        end
        return true
    end,
    -- 星律：派系行省公共秩序+4，持续 2 回合
    order = function(faction)
        cm:apply_effect_bundle("psw_twr_card_order", faction:name(), 2)
        return true
    end,
    -- 星锻：随机一件塔圣物（无新物则回退 Lin 装备/水晶）
    smith = function(faction)
        if grant_tower_relic(faction) or grant_lin_ancillary(faction) then
            return true
        end
        add_gmsj(faction:name(), 2)
        return true
    end,
    -- 星晶：共鸣水晶 +2
    crystal = function(faction)
        add_gmsj(faction:name(), 2)
        return true
    end,
    -- 【禁咒】星陨：流星雨复刻——最强交战派系全部军队兵力 -40~60%（下限 1% 不灭）
    starfall = function(faction)
        local tgt = digong_target(faction)
        if not tgt then return false end
        local cost = cm:random_number(60, 40) / 100
        local n = 0
        local cl = tgt:character_list()
        for j = 0, cl:num_items() - 1 do
            local ch = cl:item_at(j)
            if cm:char_is_general_with_army(ch) then
                local ul = ch:military_force():unit_list()
                for i = 0, ul:num_items() - 1 do
                    local u = ul:item_at(i)
                    local cur = u:percentage_proportion_of_full_strength() / 100
                    cm:set_unit_hp_to_unary_of_maximum(u, math.max(cur - cost, 0.01))
                    n = n + 1
                end
            end
        end
        return n > 0
    end,
    -- 【禁咒】星缚：镜之环复刻——最强交战派系全部军队冻结 1 回合（PSW 禁行包）
    starbind = function(faction)
        local tgt = digong_target(faction)
        if not tgt then return false end
        local n = 0
        local cl = tgt:character_list()
        for j = 0, cl:num_items() - 1 do
            local ch = cl:item_at(j)
            if cm:char_is_general_with_army(ch) then
                cm:apply_effect_bundle_to_force("psw_character_xianzhi_yidong_5ci",
                    ch:military_force():command_queue_index(), 1)
                n = n + 1
            end
        end
        return n > 0
    end,
}

-- 禁咒牌不入普通随机池：仅登顶大赏等顶格馈赠发放
local CARD_RARE = { "starfall", "starbind" }

local function card_random_rare(faction)
    local key = CARD_RARE[cm:random_number(#CARD_RARE)]
    if card_add(faction, key) then
        tlog("rare card gained: " .. key)
        link_msg(faction, "psw_twr_card_gain_" .. key)
    end
end

local function use_card(faction, idx)
    local t = card_list()
    local key = t[idx]
    if not key or not CARD_DEFS[key] then return false end
    local ok = false
    tpcall("card_" .. key, function() ok = CARD_DEFS[key](faction) end)
    if not ok then
        link_msg(faction, "psw_twr_card_fail")
        return false
    end
    table.remove(t, idx)
    svs(SK.cards, table.concat(t, ","))
    tlog("card used: " .. key .. ", left=" .. #t)
    link_msg(faction, "psw_twr_card_used_" .. key)
    return true
end

-- 无双英雄（wyccc_shojo）：从未认领英雄中抽一人入世，沿用官方 prepare
local function grant_wushuang(faction)
    local cfg = wyccc_wushuang_hero_lottery_config
    if type(cfg) ~= "table" or type(cfg.entries) ~= "table" then return false end
    local lot = wyccc_wushuang_hero_lottery
    local claimed = (type(lot) == "table" and type(lot.state) == "table"
        and type(lot.state.claimed) == "table" and lot.state.claimed) or {}
    local avail = {}
    for _, e in ipairs(cfg.entries) do
        if e.subtype and not claimed[e.subtype] then avail[#avail + 1] = e end
    end
    if #avail == 0 then return false end
    local entry = avail[cm:random_number(#avail)]
    local hr = faction:has_home_region() and faction:home_region() or nil
    if not hr or hr:is_null_interface() then return false end
    return tpcall("link_wushuang", function()
        local x, y = cm:find_valid_spawn_location_for_character_from_settlement(
            faction:name(), hr:name(), false, true)
        cm:create_agent(faction:name(), entry.agent_type or "champion",
            entry.subtype, x, y, true)
        local ch = find_faction_subtype(faction, entry.subtype)
        if ch and type(wyccc_wushuang_character_setup) == "table"
            and type(wyccc_wushuang_character_setup.prepare) == "function" then
            wyccc_wushuang_character_setup:prepare(ch, entry)
        end
        if type(lot) == "table" and type(lot.state) == "table"
            and type(lot.state.claimed) == "table" then
            lot.state.claimed[entry.subtype] = faction:name()
            if type(lot.save) == "function" then lot:save() end
        end
    end)
end

-- 楼层里程碑：boss/精英层战斗胜利后联动馈赠（on_victory 钩子）
-- 联动奖励概率（MCT link_chance）：未中则本档只发保底星尘/水晶
local function link_ok()
    return cm:random_number(100) <= mct_num("link_chance", 100)
end

local function grant_milestone(faction, floor)
    local fname = faction:name()
    if floor == 10 then
        if link_ok() and grant_lin_res(faction, LIN_INGOT, 10) then
            link_msg(faction, "psw_twr_link_m10_ingot")
        else
            gain_stardust(fname, 150); link_msg(faction, "psw_twr_link_m10_sd")
        end
    elseif floor == 15 then
        if link_ok() and (grant_tower_relic(faction) or grant_lin_ancillary(faction)) then
            link_msg(faction, "psw_twr_link_m15_relic")
        else
            gain_stardust(fname, 100); link_msg(faction, "psw_twr_link_m15_sd")
        end
    elseif floor == 20 then
        if link_ok() and grant_servant(faction) then
            link_msg(faction, "psw_twr_link_m20_servant")
        else
            add_gmsj(fname, 3); link_msg(faction, "psw_twr_link_m20_gmsj")
        end
    elseif floor == 25 then
        if link_ok() and grant_lin_res(faction, LIN_COUPON, 2) then
            link_msg(faction, "psw_twr_link_m25_coupon")
        else
            gain_stardust(fname, 200); link_msg(faction, "psw_twr_link_m25_sd")
        end
    end
end

-- 登顶大赏：无双英雄 > 英灵从者 > 塔圣物（返回播报 loc key 或 nil）
local function grant_final_link(faction)
    if link_ok() and grant_wushuang(faction) then return "psw_twr_link_top_wushuang" end
    if link_ok() and grant_servant(faction) then return "psw_twr_link_top_servant" end
    if link_ok() and grant_tower_relic(faction) then return "psw_twr_link_top_relic" end
    return nil
end

-- 稀有度权重：精英/Boss 掉率倾斜高阶
local BOON_RARITY = {
    normal = { n = 55, r = 30, s = 10, c = 5 },
    elite  = { n = 25, r = 45, s = 22, c = 8 },
    boss   = { n = 0,  r = 60, s = 32, c = 8 },
    ambush = { n = 40, r = 40, s = 15, c = 5 },
}

local function roll_boons(faction, kind)
    local w = BOON_RARITY[kind] or BOON_RARITY.normal
    local grp = boon_culture_group(faction)
    local owned = {}
    for k in sv(SK.boons, ""):gmatch("[^,]+") do owned[k] = true end
    local by_rar = { n = {}, r = {}, s = {}, c = {} }
    for _, b in ipairs(BOON_INDEX and psw_tower_pools.BOONS or {}) do
        if not owned[b.key] and (not b.cul or b.cul == grp) then
            local t = by_rar[b.rar]; if t then t[#t + 1] = b.key end
        end
    end
    local picks, used = {}, {}
    for _ = 1, 3 do
        for _try = 1, 10 do
            local roll = cm:random_number(w.n + w.r + w.s + w.c)
            local rar = roll <= w.n and "n" or roll <= w.n + w.r and "r"
                or roll <= w.n + w.r + w.s and "s" or "c"
            local pool = by_rar[rar]
            if pool and #pool > 0 then
                local k = pool[cm:random_number(#pool)]
                if not used[k] then used[k] = true; picks[#picks + 1] = k; break end
            end
            -- 该稀有度池空 -> 降级重掷
            if rar == "s" then w = { n = w.n, r = w.r + w.s, s = 0, c = w.c }
            elseif rar == "c" then w = { n = w.n + w.c, r = w.r, s = w.s, c = 0 }
            else break end
        end
    end
    return picks
end

-- 按稀有度直选一件未拥有祝福（献祭/契约/道印用；rars={s=true,r=true}）
local function pick_boon_rar(rars, grp)
    local owned = {}
    for k in sv(SK.boons, ""):gmatch("[^,]+") do owned[k] = true end
    local cands = {}
    for _, b in ipairs(psw_tower_pools and psw_tower_pools.BOONS or {}) do
        if rars[b.rar] and not owned[b.key]
            and (not b.cul or b.cul == grp) then
            cands[#cands + 1] = b.key
        end
    end
    return #cands > 0 and cands[cm:random_number(#cands)] or nil
end

-- 道印：某流派证道后再入塔，开局直赠一件普通祝福（轻量 meta，不引第二货币）
local function grant_seal(faction)
    local k = pick_boon_rar({ n = true }, boon_culture_group(faction))
    if k then
        apply_boon(k)
        link_msg(faction, "psw_twr_seal")
    end
end

-- ---------- 单位池工具 ----------
local function pool_of(subculture)
    local t = psw_tower_pools and psw_tower_pools.UNIT_POOLS
    return (t and t[subculture]) or nil
end

local function faction_subculture(faction)
    local ok, sc = pcall(function() return faction:subculture() end)
    if ok and type(sc) == "string" and sc ~= "" then return sc end
    return nil
end

local function player_pool(faction)
    return pool_of(faction_subculture(faction))
        or pool_of(psw_tower_pools.DEFAULT_SUBCULTURE)
end

local function school_key() return sv(SK.school, "standard") end
local function school_def() return SCHOOLS[school_key()] or SCHOOLS.standard end

-- 本局招募池：流派 caste 过滤；滤完太薄回退全池保底
local function run_pool(faction)
    local pool = player_pool(faction) or {}
    local s = school_def()
    local cs = s.castes
    if not cs then return pool end
    local out = {}
    for _, u in ipairs(pool) do
        if cs[u.caste] or cs[u.role] then out[#out + 1] = u end
    end
    if #out < 5 and not s.nofb then return pool end
    return out
end

-- 灵契召唤池：英杰道的"招募"其实是唤灵——只出巨兽/怪兽骑兵
local function summon_pool(faction)
    local pool, out = player_pool(faction) or {}, {}
    for _, u in ipairs(pool) do
        if u.caste == "monster" or u.caste == "monstrous_cavalry"
            or u.role == "monster" then out[#out + 1] = u end
    end
    if #out == 0 then return pool end
    return out
end

-- 战利品/商铺/事件招募统一走这里
local function recruit_pool(faction)
    if school_def().summon then return summon_pool(faction) end
    return run_pool(faction)
end

local function pick_from_pool(pool, lo, hi, rng, exclude)
    local cands = {}
    for _, u in ipairs(pool or {}) do
        if u.cost >= lo and u.cost <= hi and not (exclude and exclude[u.key]) then
            cands[#cands + 1] = u
        end
    end
    if #cands == 0 then return nil end
    return cands[rng(#cands)]
end

-- ---------- 敌军编成 ----------
local function enemy_budget(floor, kind)
    local b = 2400 + floor * 320
    if kind == "elite" then b = math.floor(b * ELITE_MULT) end
    if kind == "boss" then b = math.floor(b * (BOSS_FLOORS[floor] or 1.8)) end
    if kind == "ambush" then b = math.floor(b * AMBUSH_MULT) end
    return math.floor(b * mct_num("enemy_budget_mult", 1))
end

local function stage_of(floor)
    if floor <= 10 then return 1 elseif floor <= 20 then return 2 end
    return 3
end

local function floor_kind(floor)
    if BOSS_FLOORS[floor] then return "boss" end
    if ELITE_FLOORS[floor] then return "elite" end
    return "normal"
end

-- ---------- 派系编成信条 ----------
-- 各角色预算占比（%，加权抽取）：决定敌军"像哪个派系"——恐虐零远程、
-- 吸血鬼无弹药、食人魔巨兽主导、鼠人步炮混编、色孽骑兵过半。
-- 权重按池内实际兵种结构校准；cap_monster 为该主题巨兽硬上限（缺省 4）。
local THEME_DOCTRINE = {
    kho = { frontline = 50, cavalry = 20, monster = 30, missile = 0 },
    nur = { frontline = 45, cavalry = 10, monster = 40, missile = 5,
            cap_monster = 6 },
    tze = { frontline = 25, missile = 25, monster = 35, cavalry = 15 },
    sla = { frontline = 40, cavalry = 35, monster = 25, missile = 0 },
    grn = { frontline = 45, missile = 15, cavalry = 25, monster = 15 },
    skv = { frontline = 40, missile = 35, monster = 20, cavalry = 5 },
    vmp = { frontline = 45, cavalry = 30, monster = 25, missile = 0,
            cap_monster = 6 },
    chs = { frontline = 50, missile = 10, cavalry = 20, monster = 20 },
    nor = { frontline = 50, cavalry = 15, monster = 35, missile = 0,
            cap_monster = 6 },
    bst = { frontline = 40, cavalry = 20, monster = 35, missile = 5,
            cap_monster = 6 },
    ogr = { frontline = 15, cavalry = 10, monster = 65, missile = 10,
            cap_monster = 9 },
    dae = { frontline = 30, missile = 15, cavalry = 15, monster = 40,
            cap_monster = 6 },
    -- 扩展主题（EXTRA_THEMES）：权重同样按池内实际结构校准
    lzd = { frontline = 25, missile = 15, cavalry = 10, monster = 50,
            cap_monster = 7 },          -- 恐龙军势：巨兽当家
    hef = { frontline = 30, missile = 30, cavalry = 25, monster = 15 },
    def = { frontline = 30, missile = 20, cavalry = 30, monster = 20 },
    dwf = { frontline = 55, missile = 45, cavalry = 0, monster = 0,
            cap_monster = 0 },          -- 矮人：纯步炮，无骑无兽
    emp = { frontline = 30, missile = 30, cavalry = 30, monster = 10,
            cap_monster = 2 },
    cth = { frontline = 25, missile = 35, cavalry = 15, monster = 25 },
    ksl = { frontline = 20, missile = 35, cavalry = 25, monster = 20 },
    brt = { frontline = 30, missile = 10, cavalry = 55, monster = 5,
            cap_monster = 2 },          -- 巴托：骑士冲锋
    wef = { frontline = 30, missile = 25, cavalry = 25, monster = 20 },
    tmb = { frontline = 30, missile = 10, cavalry = 20, monster = 40,
            cap_monster = 6 },          -- 古墓：构装体
    cst = { frontline = 30, missile = 35, cavalry = 0, monster = 35,
            cap_monster = 6 },          -- 吸血鬼海岸：火枪+海怪
    chd = { frontline = 40, missile = 20, cavalry = 20, monster = 20 },
    nag = { frontline = 35, missile = 10, cavalry = 20, monster = 35,
            cap_monster = 6 },          -- 纳加什亡者军团
}
local DOCTRINE_DEFAULT = { frontline = 50, missile = 15, cavalry = 15,
    monster = 20 }
-- 伏击战信条：伏击 = 快速部队贴脸，骑兵/巨兽占比整体抬升
local AMBUSH_DOCTRINE = { frontline = 35, cavalry = 35, monster = 20,
    missile = 10 }
-- 名将团（_ror）按难度限编，防全队精锐模板化
-- RoR 限编：基准 1（MCT ror_cap 可调），elite +1、boss +2（见 build_army）
local ARMY_ROLES = { "frontline", "missile", "cavalry", "monster" }

local function roll_role(weights, wsum)
    local r = rnd(wsum)
    for _, role in ipairs(ARMY_ROLES) do
        r = r - (weights[role] or 0)
        if r <= 0 then return role end
    end
    return "frontline"
end

-- 共享构建器：主军与 Boss 援军同路径（kind 决定品质窗/限编）
local function build_army(theme_key, pool, budget, hi, kind, max_units)
    flog("ba0 enter " .. tostring(theme_key) .. " k=" .. tostring(kind)
        .. " b=" .. tostring(budget) .. " hi=" .. tostring(hi) .. " max=" .. tostring(max_units))
    local doc = (kind == "ambush" and AMBUSH_DOCTRINE)
        or THEME_DOCTRINE[theme_key] or DOCTRINE_DEFAULT
    local mon_cap = doc.cap_monster or 4
    -- MCT ror_cap 为基准值（normal/ambush），elite +1、boss +2
    local ror_bonus = ({ normal = 0, elite = 1, boss = 2, ambush = 0 })[kind] or 0
    local ror_cap = math.max(0, math.floor(mct_num("ror_cap", 1) + ror_bonus))
    flog("ba1 doc=" .. tostring(doc and doc.name or "?") .. " ror=" .. tostring(ror_cap))
    -- 核心造价窗：elite/boss 前 60% 预算只抽高价件搭骨架，填充期放开到 250
    local core_lo = (kind ~= "normal" and kind ~= "ambush")
        and math.floor(hi * 0.55) or 250

    local by_role = {}
    for _, r in ipairs(ARMY_ROLES) do by_role[r] = {} end
    for _, u in ipairs(pool) do
        if type(u) == "table" and type(u.key) == "string" and u.key ~= ""
            and type(u.cost) == "number" and by_role[u.role] then
            by_role[u.role][#by_role[u.role] + 1] = u
        end
    end
    local wsum = 0
    for _, r in ipairs(ARMY_ROLES) do wsum = wsum + (doc[r] or 0) end
    if wsum <= 0 then wsum = 1 end

    local units, used, spent = {}, {}, 0
    local n_mon, n_ror = 0, 0
    local function try_add(role, lo, cap)
        if role == "monster" and n_mon >= mon_cap then return nil end
        local cands = {}
        for _, u in ipairs(by_role[role] or {}) do
            if not used[u.key] and u.cost >= lo
                and u.cost <= math.min(cap, budget - spent + 200)
                and not (u.key:find("_ror", 1, true) and n_ror >= ror_cap)
            then cands[#cands + 1] = u end
        end
        if #cands == 0 then return nil end
        local u = cands[rnd(#cands)]
        used[u.key] = true
        units[#units + 1] = u.key
        spent = spent + u.cost
        if role == "monster" then n_mon = n_mon + 1 end
        if u.key:find("_ror", 1, true) then n_ror = n_ror + 1 end
        return u
    end

    -- Boss 旗舰：最昂贵可用巨兽先入座，保证层主战有招牌单位
    if kind == "boss" then
        local best
        for _, u in ipairs(by_role.monster) do
            if not used[u.key] and u.cost <= budget
                and not (u.key:find("_ror", 1, true) and n_ror >= ror_cap)
                and (not best or u.cost > best.cost) then best = u end
        end
        if best then
            used[best.key] = true
            units[#units + 1] = best.key
            spent = best.cost
            n_mon = 1
            if best.key:find("_ror", 1, true) then n_ror = 1 end
        end
    end

    local guard = 0
    flog("ba2 preloop wsum=" .. tostring(wsum) .. " roles=" .. tostring(#ARMY_ROLES))
    while spent < budget and #units < max_units and guard < 300 do
        guard = guard + 1
        local role = roll_role(doc, wsum)
        local lo = (spent < budget * 0.6) and core_lo or 250
        if not try_add(role, lo, hi) then
            local added = false
            for _, r2 in ipairs(ARMY_ROLES) do
                if r2 ~= role and try_add(r2, lo, hi) then
                    added = true; break
                end
            end
            if not added then
                -- 当前造价窗内任何角色都无候选：放开全价窗再试，仍空则收工
                if not try_add(role, 250, hi) then break end
            end
        end
    end

    -- 前排兜底 ≥4（保持原契约）
    local frontline_n = 0
    for _, u in ipairs(pool) do
        if used[u.key] and u.role == "frontline" then
            frontline_n = frontline_n + 1
        end
    end
    for _ = frontline_n + 1, 4 do
        if not try_add("frontline", 250, 900) then break end
    end
    if #units < 4 then flog("ba8 underflow") return nil end
    flog("ba9 done units=" .. tostring(#units))
    return table.concat(units, ",")
end

-- 签名编队（zzzz_psw_tower_comps.lua，ENEMY_COMPS.md 移植）：
-- 精英/Boss/伏击战时整队替换信条构建——"每层 = 派系招牌 doomstack"。
-- 列表按招牌优先排序，cap 截断砍尾部填充位；签名编队不走预算窗
-- （强度由编排本身保证），预算仍按公式入账供日志/星尘结算。
local function signature_csv(theme_key, kind, max_units)
    if not mct_bool("sig_comp", true) then return nil end
    if kind ~= "elite" and kind ~= "boss" and kind ~= "ambush" then return nil end
    local comp = psw_tower_comps and psw_tower_comps.SIGNATURE_COMPS
        and psw_tower_comps.SIGNATURE_COMPS[theme_key]
    if not comp or not comp.units or #comp.units < 6 then return nil end
    -- §7.2 sub-faction 变体：存在第二套签名时 1/3 掷签替换
    local v = psw_tower_comps.VARIANTS and psw_tower_comps.VARIANTS[theme_key]
    if v and v.units and #v.units >= 6 and cm:random_number(3) == 1 then
        comp = v
        tlog("signature variant: " .. theme_key)
    end
    local out = {}
    for i, k in ipairs(comp.units) do
        if i > max_units then break end
        out[#out + 1] = k
    end
    tlog("signature comp: " .. theme_key .. " " .. #out .. " units")
    return table.concat(out, ",")
end

-- 签名编队效果包：仅当本战实际走签名路径（kind 合格且主题有签名）才挂
local function sig_bundle(theme_key, kind)
    if not mct_bool("sig_comp", true) then return nil end
    if kind ~= "elite" and kind ~= "boss" and kind ~= "ambush" then return nil end
    local comp = psw_tower_comps and psw_tower_comps.SIGNATURE_COMPS
        and psw_tower_comps.SIGNATURE_COMPS[theme_key]
    if not (comp and comp.units and #comp.units >= 6) then return nil end
    return psw_tower_comps.SIG_BUNDLES and psw_tower_comps.SIG_BUNDLES[theme_key]
end

-- §7.3 词缀：每 run 一签挂全体敌军（db/effect_bundles_tables/zzz_psw_tower_sig.tsv）
local MUT_POOL = { "fury", "bulwark", "swift", "blood", "ward" }

-- Ascension NG+：通关次数按派系持久化，敌人分三阶强化（asc1/2/3 bundle）
local function asc_key(fname) return "psw_twr_asc_" .. tostring(fname) end

local function gen_enemy_list(floor, kind, forced_theme)
    if not psw_tower_pools then return nil end
    local stage = stage_of(floor)
    local theme_key
    if forced_theme then
        theme_key = forced_theme   -- 节点预掷主题（精英签揭示与实战同源）
    elseif kind == "boss" then
        theme_key = STAGE_BOSS_THEME[stage]
    else
        local themes = STAGE_THEMES[stage]
        theme_key = themes[cm:random_number(#themes) or 1]
    end
    local theme = enemy_themes()[theme_key]
    tlog("gel1 theme=" .. tostring(theme_key)); flog("gel1 "..tostring(theme_key))
    if not theme then return nil end

    local budget = enemy_budget(floor, kind)
    tlog("gel2 budget=" .. tostring(budget)); flog("gel2 "..tostring(budget))
    -- 签名编队优先（精英/Boss/伏击）；缺席或无签名回退信条构建
    local cap = army_cap() - 1   -- 单次求值：重复 MCT 原生读曾致崩，见 mct_cached
    flog("gel3a cap=" .. tostring(cap))
    local csv = signature_csv(theme_key, kind, cap)
    tlog("gel3 sig=" .. tostring(csv ~= nil)); flog("gel3")
    if not csv then
        local pool = pool_of(theme.subculture)
        flog("gel4 pool=" .. tostring(pool and #pool))
        if not pool then return nil end
        local hi = floor <= 10 and 1000 or (floor <= 20 and 1500 or 2000)
        csv = build_army(theme_key, pool, budget, hi, kind, cap)
        flog("gel5 build done csv=" .. tostring(csv))
    end
    if not csv then return nil end
    return theme_key, budget, csv
end

-- Boss 援军编成：同主题信条、小预算、约四成满编（援军本就少而精）
-- share_mult：竞逐者抢先登顶=1.0 满额，常驻档=0.6
local function gen_reinforce_csv(theme_key, floor, share_mult)
    local theme = enemy_themes()[theme_key]
    local pool = theme and pool_of(theme.subculture)
    if not pool then return nil end
    local share = mct_num("rival_reinf", RIVAL_REINF_BUDGET) * (share_mult or 1)
    if share <= 0 then return nil end  -- MCT 可关闭援军
    local budget = math.floor(enemy_budget(floor, "boss") * share)
    return build_army(theme_key, pool, budget, 1500, "normal",
        math.floor(army_cap() * 0.4))
end

-- 援军落位：主敌将旁小半径，进主军攻击的增援圈随战入场
local function spawn_boss_reinforce(enemy_fk, echar, region_key, theme_key, share_mult)
    local csv = gen_reinforce_csv(theme_key, svn(SK.floor, 1), share_mult)
    if not csv then tlog("boss reinforce: no units"); return end
    local theme = enemy_themes()[theme_key]
    local lookup = cm:char_lookup_str(echar)
    local rx, ry
    for _, r in ipairs({2, 4, 6}) do
        local x, y = cm:find_valid_spawn_location_for_character_from_character(
            enemy_fk, lookup, true, r)
        if x and y and x >= 0 and y >= 0 then rx, ry = x, y; break end
    end
    if not rx then tlog("boss reinforce: no spawn pos"); return end
    cm:create_force_with_general(
        enemy_fk, csv, region_key, rx, ry,
        "general", (theme and theme.general) or "wh_main_chs_lord",
        "", "", "", "", false,
        function(rcqi)
            svs(SK.el2, rcqi or 0)
            tlog("boss reinforcement spawned: general=" .. tostring(rcqi))
        end)
end

-- ---------- 玩家塔军 ----------
local function starting_unit_list(faction)
    local pool = run_pool(faction) or {}
    local picks, used = {}, {}
    local s = school_def()
    local want = s.want or { frontline = 3, missile = 2, cavalry = 1 }
    local cap = s.startcap or 700
    -- 起步编成随军队上限缩放：约三成编制，want 配额按比例摊
    local wsum = 0
    for _, n in pairs(want) do wsum = wsum + n end
    if wsum <= 0 then return "" end   -- 英杰道：want={} 单将启程
    local size = math.max(6, math.min(army_cap() - 6, math.floor(army_cap() * 0.3)))
    for role, n in pairs(want) do
        local need = math.max(1, math.floor(n * size / wsum + 0.5))
        local added = 0
        local tries = 0
        while added < need and tries < 40 do
            tries = tries + 1
            local u = pick_from_pool(pool, 300, cap, rnd, used)
            if u and u.role == role then
                used[u.key] = true
                picks[#picks + 1] = u.key
                added = added + 1
            end
        end
    end
    if #picks == 0 then
        local n0 = math.min(math.floor(army_cap() * 0.3), #pool)
        for i = 1, n0 do picks[#picks + 1] = pool[i].key end
    end
    return table.concat(picks, ",")
end

local function player_general_subtype(faction)
    local sc = faction_subculture(faction)
    local t = psw_tower_pools and psw_tower_pools.PLAYER_GENERALS or {}
    return (sc and t[sc]) or (psw_tower_pools and psw_tower_pools.DEFAULT_PLAYER_GENERAL)
        or "wh_main_emp_lord"
end

local function save_snapshot(force)
    local keys = {}
    local ul = force:unit_list()
    for i = 0, ul:num_items() - 1 do
        keys[#keys + 1] = ul:item_at(i):unit_key()
    end
    svs(SK.snap, table.concat(keys, ","))
    local gen = force:general_character()
    svs(SK.rank, gen and gen:rank() or 0)
end

local function restore_after_victory()
    local force = tower_force()
    local gen = tower_general()
    if not force or not gen then return end
    -- 补员：现存按 key 计数，缺的补回；全部满血
    local live = {}
    local ul = force:unit_list()
    for i = 0, ul:num_items() - 1 do
        local u = ul:item_at(i)
        live[u:unit_key()] = (live[u:unit_key()] or 0) + 1
        cm:set_unit_hp_to_unary_of_maximum(u, 1)
    end
    local snap = sv(SK.snap, "")
    if snap ~= "" then
        local want = {}
        for k in snap:gmatch("[^,]+") do want[k] = (want[k] or 0) + 1 end
        local lookup = cm:char_lookup_str(gen)
        for k, n in pairs(want) do
            local have = live[k] or 0
            for _ = have + 1, n do
                tpcall("restore_unit", function()
                    cm:grant_unit_to_character(lookup, k)
                end)
            end
        end
    end
    cm:replenish_action_points(cm:char_lookup_str(gen))
end

-- ---------- 敌我部队清理 ----------
local function cleanup_enemy()
    for _, sk in ipairs({ SK.el, SK.el2 }) do
        local el = svn(sk, 0)
        if el > 0 then
            local ch = cm:get_character_by_cqi(el)
            if ch and not ch:is_null_interface() then
                tpcall("kill_enemy", function()
                    cm:kill_character(cm:char_lookup_str(el), true)
                end)
            end
        end
    end
    svs(SK.ef, ""); svs(SK.efcqi, 0); svs(SK.el, 0); svs(SK.el2, 0)
end

local function cleanup_player_force()
    local ch = tower_general()
    if ch then
        tpcall("disband_tower_army", function()
            cm:kill_character(cm:char_lookup_str(ch:command_queue_index()), true)
        end)
    end
    svs(SK.pfcqi, 0); svs(SK.pl, 0); svs(SK.pgen, "")
end

local function clear_run()
    svs(SK.run, false); svs(SK.state, ""); svs(SK.pend, "")
    svs(SK.rewards, ""); svs(SK.shop, ""); svs(SK.ev, ""); svs(SK.shopuse, "")
    svs(SK.sdust, 0); svs(SK.paths, ""); svs(SK.boonopt, "")
    svs(SK.school, "")
    svs(SK.dlg, ""); svs(SK.dlgturn, -99); svs(SK.wager, 0); svs(SK.pthemes, ""); svs(SK.lastfl, 0)
    svs(SK.mut, ""); svs(SK.selfmald, false)
end

local function end_run(reason)
    tlog("run ended: " .. tostring(reason))
    -- 星尘清算：按率折算共鸣水晶并归零，每局资源独立；
    -- 通关另发固定水晶收益，撤退/败北只保留小额折算。
    local f = tower_faction()
    if f and not f:is_null_interface() then
        local fname = f:name()
        if reason == "victory" then
            local g = sv(SK.rivwon, false)
                and math.floor(VICTORY_GMSJ * mct_num("victory_mult", 1) / 2)
                or math.floor(VICTORY_GMSJ * mct_num("victory_mult", 1))
            add_gmsj(fname, g)
            -- Ascension NG+：通关次数+1，下局敌军挂 asc 阶位效果包
            local ak = asc_key(fname)
            local nv = svn(ak, 0) + 1
            svs(ak, nv)
            tlog("ascension: " .. fname .. " -> " .. nv)
        end
        local sd = stardust(f)
        -- 清算差异化：主动撤退保留大额（push-your-luck），
        -- 败北先腰斩余额再按低档清算——"见好就收"成为真选项
        local cap
        if reason == "victory" then
            cap = sv(SK.rivwon, false)
                and math.floor(SD_CAP_VICTORY / 2) or SD_CAP_VICTORY
        elseif reason == "quit" then
            cap = SD_CAP_RETREAT
        else
            cap = SD_CAP_QUIT
            sd = math.floor(sd / 2)
        end
        local conv = math.min(cap, math.floor(sd / SD_RATE))
        if conv > 0 then
            add_gmsj(fname, conv)
            tlog("stardust liquidated: " .. sd .. " -> +" .. conv .. " gmsj")
        end
        -- 清算按腰斩余额计，但星尘全额清空
        local full = stardust(f)
        if full > 0 then add_stardust(fname, -full) end
    end
    clear_boons()
    cleanup_enemy()
    cleanup_player_force()
    clear_run()
    -- 爬塔冷却：防连续刷水晶
    tpcall("run_cd", function() svs(SK.lastend, cm:turn_number()) end)
    svs(SK.cdann, false)
end

-- ---------- 困境发射 ----------
local DILEMMA_CHOICES = {
    [DL.OPENING] = { "FIRST", "SECOND", "THIRD", "FOURTH" },
    [DL.SCHOOL]  = { "FIRST", "SECOND", "THIRD", "FOURTH", "FIFTH" },  -- 首页四道+翻页
    [DL.SCHOOL2] = { "FIRST", "SECOND", "THIRD" },                     -- 异道页+重择
    [DL.NODE]    = { "FIRST", "SECOND", "THIRD", "FOURTH", "FIFTH" },  -- 三签+撤退+手牌
    [DL.BATTLE]  = { "FIRST", "SECOND" },
    [DL.REWARD]  = { "FIRST", "SECOND", "THIRD", "FOURTH" },
    [DL.SHOP]    = { "FIRST", "SECOND", "THIRD", "FOURTH", "FIFTH" },
    [DL.EVENT]   = { "FIRST", "SECOND", "THIRD", "FOURTH" },
    [DL.BOON]    = { "FIRST", "SECOND", "THIRD", "FOURTH" },  -- 三选祝福+放弃
    [DL.REST]    = { "FIRST", "SECOND", "THIRD", "FOURTH", "FIFTH" },  -- +遣散/离开
    [DL.CD]      = { "FIRST", "SECOND" },  -- 确认+星辉手牌
    [DL.DEFEAT]  = { "FIRST" },
    [DL.VICTORY] = { "FIRST" },
    [DL.DIGONG]  = { "FIRST", "SECOND" },
    [DL.CARDS]   = { "FIRST", "SECOND", "THIRD", "FOURTH", "FIFTH" },
}

local function fire(dilemma_key, faction, payloads)
    svs(SK.dlg, dilemma_key)   -- 待决锁：同一时刻只允许一张塔困境
    svs(SK.dlgturn, cm:turn_number())
    local b = cm:create_dilemma_builder(dilemma_key)
    local p = cm:create_payload()
    for _, choice in ipairs(DILEMMA_CHOICES[dilemma_key] or {}) do
        local pay = (payloads or {})[choice]
        if pay then pay(p) else p:text_display("psw_tower_pl_none") end
        b:add_choice_payload(choice, p)
        p:clear()
    end
    local f = tower_force()
    if f then b:add_target("default", f) end
    tlog("fire: launching " .. dilemma_key)
    local ok = cm:launch_custom_dilemma_from_builder(b, faction)
    tlog("fire: launched " .. dilemma_key .. " result=" .. tostring(ok))
    if ok == false then
        -- 引擎拒签（典型：有事件卡/困境还挂在事件队列）。锁不挂死，
        -- 下回合 enter 的过期检查会放人重试。
        svs(SK.dlg, "")
        svs(SK.dlgturn, -99)
    end
end

local function txt(key) return function(p) p:text_display(key) end end

-- 帝弓垂询：登顶后可选馈赠——向最强交战派系降下「帝弓降世」。
-- 待决标志 pack "fname|target"，供存档恢复/回合重发。
local function launch_digong(faction)
    local tgt = digong_target(faction)
    if not tgt then
        tlog("digong: no eligible target (no war / all _qb / no armies)")
        svs(SK.digong, "")
        return
    end
    svs(SK.digong, faction:name() .. "|" .. tgt:name())
    tlog("digong target: " .. tgt:name())
    fire(DL.DIGONG, faction, {
        FIRST  = txt("psw_twr_digong_fire"),
        SECOND = txt("psw_twr_digong_hold"),
    })
end

-- 星辉手牌：逐张列出手牌（≤4），用完连发；空手无卡则提示并关单
local function launch_cards(faction)
    local t = card_list()
    if #t == 0 then
        link_msg(faction, "psw_twr_card_empty")
        return
    end
    local pays = {}
    for i, key in ipairs(t) do
        pays[({"FIRST","SECOND","THIRD","FOURTH"})[i]] =
            txt("psw_twr_card_" .. key)
    end
    pays.FIFTH = txt("psw_twr_card_leave")
    fire(DL.CARDS, faction, pays)
end

-- ---------- 流派抉择 ----------
-- 每次入塔选定一道；登顶/败北后清除，重复爬塔的意义=解锁五种体验。
local launch_school2  -- 前向声明：第一页 FIFTH 翻页用

local function launch_school(faction)
    svs(SK.state, "school")
    local pays = {}
    local slots = { "FIRST", "SECOND", "THIRD", "FOURTH" }
    for i, slot in ipairs(slots) do
        pays[slot] = txt("psw_twr_school_" .. SCHOOL_ORDER[i])
    end
    pays.FIFTH = txt("psw_twr_school_more")
    fire(DL.SCHOOL, faction, pays)
end

launch_school2 = function(faction)
    svs(SK.state, "school")
    fire(DL.SCHOOL2, faction, {
        FIRST = txt("psw_twr_school_" .. SCHOOL_ORDER2[1]),
        SECOND = txt("psw_twr_school_" .. SCHOOL_ORDER2[2]),
        THIRD = txt("psw_twr_school_back"),
    })
end

-- ---------- 节点掷签（路径取舍） ----------
-- 非 Boss 层掷三条路径：守卫战保底 + 从牌堆抽两条；Boss 层强制开战。
local PATH_DECK_W = { event = 32, rest = 26, elite = 18, shop = 14 }

local function roll_paths(floor)
    if BOSS_FLOORS[floor] then return { "boss" } end
    local paths = {}
    local in_paths = {}
    -- 固定精英层（5/15/25）：首签必为精英守卫——"已知硬仗"的节奏锚点
    if ELITE_FLOORS[floor] then
        paths[#paths + 1] = "elite"; in_paths.elite = true
    else
        paths[#paths + 1] = "battle"; in_paths.battle = true
    end
    -- 商铺层保底一条 shop 路径（每层限购一次）
    if SHOP_FLOORS[floor] and sv(SK.shopuse, "") ~= tostring(floor) then
        paths[#paths + 1] = "shop"; in_paths.shop = true
    end
    while #paths < 3 do
        local total, deck = 0, {}
        -- MCT 可逐类调权重（0=该类路径不再出现）
        local weights = {
            event = mct_num("w_event", PATH_DECK_W.event),
            rest = mct_num("w_rest", PATH_DECK_W.rest),
            elite = mct_num("w_elite", PATH_DECK_W.elite),
            shop = mct_num("w_shop", PATH_DECK_W.shop),
        }
        for t, w in pairs(weights) do
            if not in_paths[t] and not (t == "elite" and floor < 5)
                and not (t == "shop" and (in_paths.shop
                    or sv(SK.shopuse, "") == tostring(floor))) then
                deck[#deck + 1] = { t, w }; total = total + w
            end
        end
        if total <= 0 then paths[#paths + 1] = "event"
        else
            local roll = cm:random_number(total)
            local acc = 0
            for _, d in ipairs(deck) do
                acc = acc + d[2]
                if roll <= acc then paths[#paths + 1] = d[1]; in_paths[d[1]] = true; break end
            end
        end
    end
    return paths
end

-- 精英签预掷敌主题并存盘：节点揭示与实战同源（SK.pthemes "elite:nor"）
local function preroll_elite_theme(faction, floor, paths)
    local stage = stage_of(floor)
    local kept = {}
    for pair in sv(SK.pthemes, ""):gmatch("[^,]+") do
        if not pair:find("^elite:") then kept[#kept + 1] = pair end
    end
    for _, p in ipairs(paths) do
        if p == "elite" then
            local themes = STAGE_THEMES[stage]
            local t = themes[rnd(#themes)]
            kept[#kept + 1] = "elite:" .. t
            -- 敌情揭示：签面即见守卫
            link_msg(faction, "psw_twr_theme_" .. t)
        end
    end
    svs(SK.pthemes, table.concat(kept, ","))
end

local function launch_node(faction)
    local floor = svn(SK.floor, 1)
    local saved = sv(SK.paths, "")
    local paths
    if saved ~= "" then
        -- 存档恢复/同层重返：复用已掷签面，杜绝 SL 重掷
        paths = {}
        for p in saved:gmatch("[^,]+") do paths[#paths + 1] = p end
    else
        paths = roll_paths(floor)
        svs(SK.paths, table.concat(paths, ","))
        preroll_elite_theme(faction, floor, paths)
    end
    svs(SK.state, "node")
    -- 层数播报（同层去重）
    if svn(SK.lastfl, 0) ~= floor and floor <= FLOORS_MAX then
        svs(SK.lastfl, floor)
        link_msg(faction, "psw_twr_floor_" .. floor)
    end
    local pays = {}
    local slots = { "FIRST", "SECOND", "THIRD" }
    for i, slot in ipairs(slots) do
        local pt = paths[i]
        pays[slot] = pt and txt("psw_twr_node_" .. pt) or txt("psw_twr_node_sealed")
    end
    pays.FOURTH = txt("psw_tower_pl_quit")
    pays.FIFTH  = txt("psw_twr_card_menu")   -- 星辉手牌：run 内随时可用
    fire(DL.NODE, faction, pays)
end

local function launch_battle(faction)
    svs(SK.state, "battle_pending")
    fire(DL.BATTLE, faction, {
        FIRST = txt("psw_tower_pl_fight"), SECOND = txt("psw_tower_pl_wait"),
    })
end

local function launch_reward(faction)
    svs(SK.state, "reward")
    -- 星赌结算：上一战胜出则押注翻倍返还
    local w = svn(SK.wager, 0)
    if w > 0 then
        svs(SK.wager, 0)
        gain_stardust(faction:name(), w)
        link_msg(faction, "psw_twr_wager_win")
    end
    local saved = sv(SK.rewards, "")
    local opts = {}
    if saved ~= "" then
        -- 存档恢复：复用已掷奖励，杜绝 SL 重掷
        for k in saved:gmatch("[^,]+") do opts[#opts + 1] = k end
    else
        -- 奖励概率（MCT reward_chance）：未中则直接发星尘推进，不弹抉择
        if cm:random_number(100) > mct_num("reward_chance", 100) then
            tlog("reward skipped by chance")
            add_stardust(faction:name(), REWARD_SKIP_STARDUST)
            psw_tower._advance(faction)
            return
        end
        local floor = svn(SK.floor, 1)
        local band = floor <= 8 and {300, 900} or floor <= 16 and {500, 1300}
            or floor <= 24 and {700, 1700} or {900, 2000}
        local pool = recruit_pool(faction)
        local used = {}
        for _ = 1, 3 do
            local u = pick_from_pool(pool, band[1], band[2], rnd, used)
            if u then used[u.key] = true; opts[#opts + 1] = u.key end
        end
        svs(SK.rewards, table.concat(opts, ","))
    end
    local f = tower_force()
    if not f or #opts == 0 then
        -- 无军或无奖励 -> 直接发星尘并推进
        add_stardust(faction:name(), REWARD_SKIP_STARDUST)
        psw_tower._advance(faction)
        return
    end
    local pays = {}
    local keys = { "FIRST", "SECOND", "THIRD" }
    for i, uk in ipairs(opts) do
        pays[keys[i]] = function(p) p:add_unit(f, uk, 1, 0, true) end
    end
    pays.FOURTH = txt("psw_tower_pl_reward_skip")
    fire(DL.REWARD, faction, pays)
end

local function launch_shop(faction)
    svs(SK.state, "shop")
    local saved = sv(SK.shop, "")
    local stock, pays = {}, {}
    if saved ~= "" then
        -- 存档恢复：复用已掷货架
        for k in saved:gmatch("[^,]+") do stock[#stock + 1] = k end
        for i, _ in ipairs(stock) do
            pays[({"FIRST","SECOND","THIRD"})[i]] = txt(SHOP_TIERS[i].text)
        end
    else
        local floor = svn(SK.floor, 1)
        local pool = recruit_pool(faction)
        local used = {}
        for i, tier in ipairs(SHOP_TIERS) do
            local u = pick_from_pool(pool, tier.min, tier.max, rnd, used)
            if u then
                used[u.key] = true
                stock[i] = u.key
                pays[({"FIRST","SECOND","THIRD"})[i]] = txt(tier.text)
            end
        end
        svs(SK.shop, table.concat(stock, ","))
    end
    pays.FOURTH = txt("psw_tower_pl_shop_gmsj")
    pays.FIFTH = txt("psw_tower_pl_back")
    fire(DL.SHOP, faction, pays)
end

-- ---------- 祝福抉择 / 休整 ----------
local function last_battle_kind()
    local pend = sv(SK.pend, "")
    local kind = pend:match("^(%a+)|") or "normal"
    if kind == "elite" or kind == "boss" or kind == "ambush" then return kind end
    return "normal"
end

local function launch_boon(faction)
    local saved = sv(SK.boonopt, "")
    local picks = {}
    if saved ~= "" then
        for k in saved:gmatch("[^,]+") do picks[#picks + 1] = k end
    else
        local kind = last_battle_kind()
        picks = roll_boons(faction, kind)
    end
    if #picks == 0 then
        gain_stardust(faction:name(), 30)  -- 池子抽空保底
        psw_tower._advance(faction); return
    end
    svs(SK.boonopt, table.concat(picks, ","))
    svs(SK.state, "boon")
    local pays = {}
    local slots = { "FIRST", "SECOND", "THIRD" }
    for i, slot in ipairs(slots) do
        local k = picks[i]
        pays[slot] = k and txt("psw_twr_pl_boon_" .. k) or txt("psw_tower_pl_boon_none")
    end
    pays.FOURTH = txt("psw_tower_pl_boon_skip")
    fire(DL.BOON, faction, pays)
end

local function resolve_boon(faction, c)
    if c == "FOURTH" then
        gain_stardust(faction:name(), 15)
        psw_tower._advance(faction); return
    end
    local opts = {}
    for k in sv(SK.boonopt, ""):gmatch("[^,]+") do opts[#opts + 1] = k end
    svs(SK.boonopt, "")  -- 已兑现即清档
    local idx = ({ FIRST = 1, SECOND = 2, THIRD = 3 })[c]
    local key = idx and opts[idx]
    if key and BOON_INDEX[key] then apply_boon(key) end
    psw_tower._advance(faction)
end

local function launch_rest(faction)
    svs(SK.state, "rest")
    fire(DL.REST, faction, {
        FIRST  = txt("psw_tower_pl_rest_meditate"),
        SECOND = txt("psw_tower_pl_rest_train"),
        THIRD  = txt("psw_tower_pl_rest_purify"),
        FOURTH = txt("psw_tower_pl_rest_disband"),
        FIFTH  = txt("psw_tower_pl_rest_leave"),
    })
end

local REST_PURIFY_COST = 50
local REST_DISBAND_GAIN = 60
local function resolve_rest(faction, c)
    local fname = faction:name()
    if c == "FIRST" then
        gain_stardust(fname, math.floor(REST_STARDUST * (1 + mod_val(SK.modrest))))
    elseif c == "SECOND" then
        local gen = tower_general()
        if gen then
            tpcall("rest_train", function()
                cm:add_experience_to_units_commanded_by_character(
                    cm:char_lookup_str(gen), 2)
            end)
        else
            gain_stardust(fname, 20)
        end
    elseif c == "THIRD" then
        local curses = curse_list()
        if #curses > 0 and stardust(faction) >= REST_PURIFY_COST then
            add_stardust(fname, -REST_PURIFY_COST)
            local k = curses[1]
            remove_boon(k)
            tlog("purified curse: " .. k)
        else
            gain_stardust(fname, 15)  -- 无诅咒或星尘不足 -> 保底安慰
        end
    elseif c == "FOURTH" then
        -- 遣散：移除末位兵牌换星尘——卡组只进不出的"删牌"出口
        local gen = tower_general()
        local removed = false
        if gen then
            local ul = gen:military_force():unit_list()
            if ul:num_items() > 1 then
                tpcall("rest_disband", function()
                    cm:remove_unit_from_character(cm:char_lookup_str(gen),
                        ul:item_at(ul:num_items() - 1):unit_key())
                end)
                removed = true
            end
        end
        if removed then
            gain_stardust(fname, REST_DISBAND_GAIN)
            link_msg(faction, "psw_twr_rest_disband")
        else
            gain_stardust(fname, 15)  -- 只剩将领无可遣 -> 保底安慰
        end
    end
    -- FIFTH = 不休整直接离开
    psw_tower._advance(faction)
end

-- ---------- 事件池（GM式数据驱动，P0 精简） ----------
local EVENTS = {
    { id = "shrine",    opts = { "psw_tower_pl_ev_stardust", "psw_tower_pl_ev_pray" } },
    { id = "cache",     opts = { "psw_tower_pl_ev_cache", "psw_tower_pl_ev_salvage" } },
    { id = "merchant",  opts = { "psw_tower_pl_ev_buy", "psw_tower_pl_ev_sell" } },
    { id = "ambush",    opts = { "psw_tower_pl_ev_ambush" } },
    { id = "portal",    opts = { "psw_tower_pl_ev_portal" } },
    { id = "fountain",  opts = { "psw_tower_pl_ev_fountain" } },
    { id = "trap",      opts = { "psw_tower_pl_ev_trap" } },
    { id = "echo",      opts = { "psw_tower_pl_ev_echo" } },
    -- 生态联动事件（软依赖：缺席时各选项退化为星尘/水晶兜底）
    { id = "star_gate", opts = { "psw_tower_pl_ev_gate", "psw_tower_pl_ev_gate_gem" } },
    { id = "captive",   opts = { "psw_tower_pl_ev_captive", "psw_tower_pl_ev_sacrifice", "psw_tower_pl_ev_loot" } },
    { id = "relic",     opts = { "psw_tower_pl_ev_relic" } },
    { id = "omen",      opts = { "psw_tower_pl_ev_omen_seer", "psw_tower_pl_ev_omen_jam" } },
    { id = "deck",      opts = { "psw_tower_pl_ev_deck", "psw_tower_pl_ev_deck_buy" } },
    -- 带牙齿的交易：献祭末位兵牌换S级祝福 / 蚀星诅咒换大额星尘 / 押注下战
    { id = "sacrifice", opts = { "psw_tower_pl_ev_sac_offer", "psw_tower_pl_ev_sac_dust" } },
    { id = "pact",      opts = { "psw_tower_pl_ev_pact" } },
    { id = "wager",     opts = { "psw_tower_pl_ev_wager", "psw_tower_pl_ev_wager_big" } },
}

local function launch_event(faction)
    local ev
    local saved_id = sv(SK.ev, "")
    if saved_id ~= "" then
        -- 存档恢复：复用已定事件
        for _, e in ipairs(EVENTS) do
            if e.id == saved_id then ev = e break end
        end
    end
    if not ev then
        ev = EVENTS[cm:random_number(#EVENTS) or 1]
        svs(SK.ev, ev.id)
    end
    svs(SK.state, "event")
    local pays = {}
    for i, tk in ipairs(ev.opts) do
        pays[({"FIRST","SECOND","THIRD"})[i]] = txt(tk)
    end
    pays.FOURTH = txt("psw_tower_pl_ev_skip")
    fire(DL.EVENT, faction, pays)
end

local function resolve_event(faction, choice)
    local ev_id = sv(SK.ev, "")
    svs(SK.ev, "")          -- 已决事件立即清档，防恢复重入再触发
    local fname = faction:name()
    local floor = svn(SK.floor, 1)
    local function advance() psw_tower._advance(faction) end
    if choice == "FOURTH" then
        gain_stardust(fname, SKIP_EVENT_STARDUST, true); advance(); return
    end
    if ev_id == "shrine" then
        if choice == "FIRST" then gain_stardust(fname, 60, true)
        else
            if cm:random_number(100) <= 60 then gain_stardust(fname, 120, true)
            else add_stardust(fname, -40, true) end
        end
        advance()
    elseif ev_id == "cache" then
        if choice == "FIRST" then
            local band = floor <= 16 and {500, 1200} or {700, 1600}
            local u = pick_from_pool(recruit_pool(faction), band[1], band[2], rnd)
            local gen = tower_general()
            if u and gen then
                cm:grant_unit_to_character(cm:char_lookup_str(gen), u.key)
            else
                gain_stardust(fname, 60, true)
            end
        else gain_stardust(fname, 90, true) end
        advance()
    elseif ev_id == "merchant" then
        if choice == "FIRST" then
            if stardust(faction) >= 350 then
                add_stardust(fname, -350)
                local u = pick_from_pool(recruit_pool(faction), 500, 1200, rnd)
                local gen = tower_general()
                if u and gen then cm:grant_unit_to_character(cm:char_lookup_str(gen), u.key) end
            end
        else
            if stardust(faction) >= 50 then
                add_stardust(fname, -50); cm:treasury_mod(fname, 4000)
            end
        end
        advance()
    elseif ev_id == "ambush" then
        psw_tower._start_battle(faction, "ambush")
    elseif ev_id == "portal" then
        advance()  -- 免费越层
    elseif ev_id == "fountain" then
        local gen = tower_general()
        if gen then
            tpcall("fountain_xp", function()
                cm:add_agent_experience(cm:char_lookup_str(gen), (gen:rank() or 0) + 1, true)
            end)
        end
        gain_stardust(fname, 30, true)
        advance()
    elseif ev_id == "trap" then
        add_stardust(fname, -40, true); advance()
    elseif ev_id == "echo" then
        local u = pick_from_pool(recruit_pool(faction), 300, 800, rnd)
        local gen = tower_general()
        if u and gen then cm:grant_unit_to_character(cm:char_lookup_str(gen), u.key) end
        advance()
    elseif ev_id == "star_gate" then
        -- 星门献祭：星尘签(50)或水晶签(1水晶，档位更优)，掷联动馈赠
        local better = false
        if choice == "FIRST" and stardust(faction) >= 50 then
            add_stardust(fname, -50)
        elseif choice == "SECOND" and tower_gmsj(faction) >= 1 then
            add_gmsj(fname, -1); better = true
        else
            gain_stardust(fname, 10, true); advance(); return
        end
        -- 档位：通宝/源石锭/装备/星尘兜底；水晶签档位更优且数量+1
        local t = better and {40, 75, 95} or {35, 60, 85}
        local roll = cm:random_number(100)
        if roll <= t[1] and grant_lin_res(faction, LIN_COUPON, better and 3 or 2) then
            link_msg(faction, "psw_twr_link_ev_coupon")
        elseif roll <= t[2] and grant_lin_res(faction, LIN_INGOT, better and 6 or 4) then
            link_msg(faction, "psw_twr_link_ev_ingot")
        elseif roll <= t[3] and grant_lin_ancillary(faction) then
            link_msg(faction, "psw_twr_link_ev_anc")
        else
            gain_stardust(fname, better and 130 or 90, true)
        end
        advance()
    elseif ev_id == "sacrifice" then
        -- 星墟献祭：遣散末位兵牌 → 换一件高阶祝福（S 优先无则 R；无兵可遣退化星尘）
        if choice == "FIRST" then
            local gen = tower_general()
            local removed = false
            if gen then
                local ul = gen:military_force():unit_list()
                if ul:num_items() > 1 then
                    tpcall("ev_sacrifice", function()
                        cm:remove_unit_from_character(cm:char_lookup_str(gen),
                            ul:item_at(ul:num_items() - 1):unit_key())
                    end)
                    removed = true
                end
            end
            if removed then
                local k = pick_boon_rar({ s = true, r = true },
                    boon_culture_group(faction))
                if k then
                    apply_boon(k)
                    link_msg(faction, "psw_twr_sac_done")
                else
                    gain_stardust(fname, 100, true)
                end
            else
                gain_stardust(fname, 60, true)
            end
        else
            gain_stardust(fname, 40, true)
        end
        advance()
    elseif ev_id == "pact" then
        -- 蚀星契约：自愿吞一条蚀星诅咒 → 大额星尘（无诅咒可给时退化星尘）
        if choice == "FIRST" then
            local k = pick_boon_rar({ c = true }, boon_culture_group(faction))
            if k then
                apply_boon(k)
                gain_stardust(fname, 200, true)
                link_msg(faction, "psw_twr_pact_done")
            else
                gain_stardust(fname, 80, true)
            end
        else
            gain_stardust(fname, 20, true)
        end
        advance()
    elseif ev_id == "wager" then
        -- 星赌：押星尘，下战胜利翻倍返还（败北清零——SK.wager 随 run 结束消亡）
        local bet = (choice == "SECOND") and 300 or 100
        if stardust(faction) >= bet then
            add_stardust(fname, -bet)
            svs(SK.wager, bet * 2)
            link_msg(faction, "psw_twr_wager_on")
        else
            gain_stardust(fname, 15, true)
        end
        advance()
    elseif ev_id == "captive" then
        if choice == "FIRST" then
            add_gmsj(fname, 1)
        elseif choice == "SECOND" then
            gain_stardust(fname, 80, true)
        else
            gain_stardust(fname, 30, true)
        end
        advance()
    elseif ev_id == "relic" then
        if choice == "FIRST" and tower_gmsj(faction) >= 2 then
            add_gmsj(fname, -2)
            if grant_tower_relic(faction) or grant_lin_ancillary(faction) then
                link_msg(faction, "psw_twr_link_ev_relic")
            else
                gain_stardust(fname, 120, true)
            end
        else
            gain_stardust(fname, 20, true)
        end
        advance()
    elseif ev_id == "omen" then
        if choice == "FIRST" then
            -- 星象占卜：探知竞逐者进度（免费）
            local rf = svn(SK.riv, 0)
            local band = (sv(SK.rivwon, false) and "won")
                or (rf >= 20 and "high") or (rf >= 10 and "mid") or "low"
            link_msg(faction, "psw_twr_link_omen_" .. band)
        elseif choice == "SECOND" then
            -- 扰乱星路：-100 星尘令竞逐者退 3 层（已登顶者无法撼动）
            if not sv(SK.rivwon, false) and stardust(faction) >= 100 then
                add_stardust(fname, -100)
                svs(SK.riv, math.max(0, svn(SK.riv, 0) - 3))
                link_msg(faction, "psw_twr_link_omen_jammed")
            else
                gain_stardust(fname, 15, true)
            end
        end
        advance()
    elseif ev_id == "deck" then
        -- 星辉牌室：免费抽1张 或 -60星尘购2张（手牌满自动折价）
        if choice == "FIRST" then
            card_random(faction)
        elseif choice == "SECOND" and stardust(faction) >= 60 then
            add_stardust(fname, -60)
            card_random(faction); card_random(faction)
        else
            gain_stardust(fname, 20, true)
        end
        advance()
    else
        advance()
    end
end

-- ---------- 战斗发起 ----------
function psw_tower._start_battle(faction, kind)
    tlog("sb0 enter start_battle kind=" .. tostring(kind)); flog("sb0 "..tostring(kind))
    local floor = svn(SK.floor, 1)
    kind = kind or floor_kind(floor)
    local gen = tower_general()
    local force = tower_force()
    tlog("sb0a gen/force fetched"); flog("sb0a")
    if not gen or not force then
        tlog("start_battle aborted: tower army missing")
        end_run("army_lost"); return
    end
    -- 取节点预掷主题（精英签揭示过的守卫），用完即清
    local tkey
    local kept = {}
    for pair in sv(SK.pthemes, ""):gmatch("[^,]+") do
        local k = pair:match("^(%a+):")
        if k == kind and not tkey then
            tkey = pair:sub(#k + 2)
        else
            kept[#kept + 1] = pair
        end
    end
    tlog("sb0b pthemes parsed"); flog("sb0b")
    svs(SK.pthemes, table.concat(kept, ","))
    tlog("sb0c pthemes saved"); flog("sb0c")
    local theme_key, budget, units_csv = gen_enemy_list(floor, kind, tkey)
    tlog("sb1 enemy list: " .. tostring(theme_key) .. " b=" .. tostring(budget)); flog("sb1 "..tostring(theme_key).." "..tostring(units_csv))
    if not theme_key then
        tlog("start_battle aborted: enemy gen failed, auto-advance")
        psw_tower._advance(faction); return
    end
    local theme = enemy_themes()[theme_key]
    svs(SK.pend, kind .. "|" .. theme_key .. "|" .. budget .. "|" .. units_csv)
    svs(SK.ef, theme.faction)
    tlog("sb2 theme saved: " .. tostring(theme.faction)); flog("sb2")
    -- 敌情揭示：Boss 具名播报；未预掷的主题（普通战）开战前揭示守卫身份
    if kind == "boss" then
        link_msg(faction, "psw_twr_boss_" .. theme_key)
    elseif not tkey then
        link_msg(faction, "psw_twr_theme_" .. theme_key)
    end
    tlog("sb3 theme msg done"); flog("sb3")
    save_snapshot(force)
    tlog("sb4 snapshot done"); flog("sb4")
    launch_battle(faction)
    tlog("sb5 battle dilemma fired"); flog("sb5")
end

local function do_attack(faction)
    flog("da0 enter")
    local pend = sv(SK.pend, "")
    local parts = {}
    for s in pend:gmatch("[^|]+") do parts[#parts + 1] = s end
    local kind = parts[1] or "normal"
    local theme_key = parts[2]
    local units_csv = parts[4]
    if not units_csv or units_csv == "" then
        tlog("do_attack: empty enemy list"); psw_tower._advance(faction); return
    end
    local gen = tower_general()
    local faction_name = faction:name()
    if not gen then end_run("no_general"); return end
    local enemy_fk = sv(SK.ef, "")
    local ef = cm:get_faction(enemy_fk)
    if not ef or ef:is_null_interface() then
        enemy_fk = "wh_main_chs_chaos_qb1"
        ef = cm:get_faction(enemy_fk)
    end
    if not ef or ef:is_null_interface() then
        tlog("do_attack: no enemy host faction"); end_run("no_enemy_faction"); return
    end

    -- 找玩家附近的敌军出生点
    local ex, ey
    local lookup = cm:char_lookup_str(gen)
    for _, r in ipairs({6, 12, 20}) do
        local x, y = cm:find_valid_spawn_location_for_character_from_character(
            enemy_fk, lookup, true, r)
        if x and y and x >= 0 and y >= 0 then ex, ey = x, y; break end
    end
    if not ex then
        local x, y = cm:find_valid_spawn_location_for_character_from_position(
            enemy_fk, gen:logical_position_x(), gen:logical_position_y(), true)
        if x and y and x >= 0 and y >= 0 then ex, ey = x, y end
    end
    local region_key = sv(SK.region, "")
    if not ex or region_key == "" then
        tlog("do_attack: no spawn pos/region"); end_run("no_spawn"); return
    end

    -- 敌将 subtype（boss 用 exalted）
    local theme = enemy_themes()[theme_key] or enemy_themes().chs or {}
    local gen_sub = (kind == "boss" and theme.exalted) or theme.general or "wh_main_chs_lord"

    svs(SK.state, "battle")
    flog("da1 spawning enemy " .. tostring(enemy_fk) .. " @" .. tostring(ex) .. "," .. tostring(ey) .. " region=" .. tostring(region_key) .. " units=" .. tostring(units_csv))
    cm:disable_event_feed_events(true, "", "", "diplomacy_war_declared")
    cm:disable_event_feed_events(true, "", "", "diplomacy_faction_destroyed")
    cm:disable_event_feed_events(true, "", "", "character_dies_battle")
    cm:create_force_with_general(
        enemy_fk, units_csv, region_key, ex, ey,
        "general", gen_sub, "", "", "", "", false,
        function(char_cqi)
            flog("da2 enemy spawned cqi=" .. tostring(char_cqi))
            svs(SK.el, char_cqi or 0)
            local echar = char_cqi and cm:get_character_by_cqi(char_cqi)
            local pforce = tower_force()
            if not (echar and not echar:is_null_interface() and echar:has_military_force())
                or not pforce then
                tlog("do_attack cb: enemy/player force invalid")
                cm:callback(function()
                    cm:disable_event_feed_events(false, "", "", "diplomacy_war_declared")
                end, 0.2)
                return
            end
            svs(SK.efcqi, echar:military_force():command_queue_index())
            -- 敌将等级随层数（Spire 式）：10+floor 封顶 40
            tpcall("enemy_rank", function()
                cm:add_agent_experience(
                    cm:char_lookup_str(echar:command_queue_index()),
                    math.min(10 + svn(SK.floor, 1), 40), true)
            end)
            -- 兵牌勋级随层数（ENEMY_COMPS §7.3）：阶段1=2/阶段2=5/阶段3=8，
            -- 精英+1、Boss 到顶 9——敌方单位也有成长曲线
            tpcall("enemy_chevron", function()
                local fl = svn(SK.floor, 1)
                local chev = fl <= 10 and 2 or (fl <= 20 and 5 or 8)
                if kind == "elite" then chev = chev + 1
                elseif kind == "boss" then chev = 9 end
                cm:add_experience_to_units_commanded_by_character(
                    cm:char_lookup_str(echar:command_queue_index()),
                    math.min(chev, 9))
            end)
            -- 效果包三层：签名编队加成 + 本局词缀(可多签) + Ascension 阶位
            tpcall("enemy_bundles", function()
                local fcqi = echar:military_force():command_queue_index()
                local function eb(k)
                    if k then cm:apply_effect_bundle_to_force(k, fcqi, 0) end
                end
                eb(sig_bundle(theme_key, kind))
                local mks = {}
                for m in sv(SK.mut, ""):gmatch("[^,]+") do
                    mks[#mks + 1] = m; eb("psw_twr_mut_" .. m)
                end
                local asc = svn(asc_key(faction_name), 0)
                if asc >= 1 then eb("psw_twr_asc" .. math.min(asc, 3)) end
                -- Boss 专属：额外一条不重复词缀 + 塔圣物星弓（层主战真正差异化）
                if kind == "boss" then
                    local p2 = {}
                    for _, m in ipairs(MUT_POOL) do
                        local dup = false
                        for _, m2 in ipairs(mks) do
                            if m2 == m then dup = true break end
                        end
                        if not dup then p2[#p2 + 1] = m end
                    end
                    if #p2 > 0 then
                        local bm = p2[cm:random_number(#p2)]
                        eb("psw_twr_mut_" .. bm)
                        link_msg(faction, "psw_twr_boss_affix_" .. bm)
                    end
                    tpcall("boss_anc", function()
                        cm:force_add_ancillary(echar,
                            "psw_twr_anc_weapon_starbow", true, true)
                    end)
                end
            end)
            local function attack()
                flog("da3 declare war")
                cm:force_declare_war(enemy_fk, faction_name, false, false, false)
                cm:callback(function()
                    cm:disable_event_feed_events(false, "", "", "diplomacy_war_declared")
                end, 0.2)
                flog("da4 replenish+attack")
                cm:replenish_action_points(cm:char_lookup_str(echar:command_queue_index()))
                tpcall("force_attack", function()
                    flog("da5 force_attack_of_opportunity")
                    cm:force_attack_of_opportunity(
                        echar:military_force():command_queue_index(),
                        pforce:command_queue_index(), false, true)
                    flog("da6 attack issued")
                end)
            end
            -- Boss 常驻援军：层主战必带一支随军（rivwon 时满额 1.0，否则 0.6）
            if kind == "boss" then
                spawn_boss_reinforce(enemy_fk, echar, region_key, theme_key,
                    sv(SK.rivwon, false) and 1.0 or 0.6)
                cm:callback(attack, 0.4)   -- 留一拍让援军实体化进增援圈
            else
                attack()
            end
        end
    )
end

-- ---------- 层推进 ----------
function psw_tower._advance(faction)
    local floor = svn(SK.floor, 1) + 1
    svs(SK.floor, floor)
    svs(SK.shopuse, "")
    svs(SK.paths, "")   -- 上一层签面作废，新层重新掷签
    rival_chase(faction)  -- 层间咬尾：玩家每进一层竞逐者有概率跟进
    if floor > FLOORS_MAX then
        svs(SK.state, "victory")
        fire(DL.VICTORY, faction, { FIRST = txt("psw_tower_pl_confirm") })
        return
    end
    launch_node(faction)
end

-- ---------- 战后 ----------
local function on_victory(faction)
    local floor = svn(SK.floor, 1)
    local kind = last_battle_kind()
    local gain = math.floor((20 + floor * 4)
        * (kind == "boss" and 3 or kind == "elite" and 2 or kind == "ambush" and 2 or 1))
    gain_stardust(faction:name(), gain)
    restore_after_victory()
    -- 将领经验：胜一场 +1 阶（英杰道 +2——孤胆快长）
    local gen = tower_general()
    if gen then
        local xp = school_def().summon and 2 or 1
        tpcall("xp", function()
            cm:add_agent_experience(cm:char_lookup_str(gen), math.min((gen:rank() or 0) + xp, 40), true)
        end)
    end
    cleanup_enemy()
    grant_milestone(faction, floor)   -- 联动里程碑：10/15/20/25 层馈赠
    if BOSS_FLOORS[floor] then
        card_random(faction)          -- Boss 层 +1 星辉卡牌
        -- Boss 层 +1 记忆结晶（品级随层：10=N、20=R、30=S——30层即登顶）
        local tier = floor >= 30 and "S" or floor >= 20 and "R" or "N"
        if grant_jyjj_card(faction, tier) then
            link_msg(faction, "psw_twr_jyjj_" .. string.lower(tier))
        end
    end
    launch_reward(faction)
end

local function on_defeat(faction)
    cleanup_enemy()
    svs(SK.state, "defeat")
    fire(DL.DEFEAT, faction, { FIRST = txt("psw_tower_pl_confirm") })
end

-- ---------- 开局 ----------
local function spawn_tower_army(faction)
    local region = faction:home_region()
    if not region or region:is_null_interface() then
        local l = faction:faction_leader()
        region = (l and l:has_region()) and l:region() or nil
    end
    if not region or region:is_null_interface() then
        tlog("spawn aborted: no home region"); return false
    end
    local region_key = region:name()
    local faction_name = faction:name()
    local gen_sub = player_general_subtype(faction)
    local units = starting_unit_list(faction)

    local x, y
    for _, r in ipairs({6, 10, 15, 20}) do
        local sx, sy = cm:find_valid_spawn_location_for_character_from_settlement(
            faction_name, region_key, false, true, r)
        if sx and sy and sx >= 0 and sy >= 0 then x, y = sx, sy; break end
    end
    local leader = faction:faction_leader()
    if not x and leader and not leader:is_null_interface() then
        for _, r in ipairs({6, 12}) do
            local sx, sy = cm:find_valid_spawn_location_for_character_from_character(
                faction_name, cm:char_lookup_str(leader), true, r)
            if sx and sy and sx >= 0 and sy >= 0 then x, y = sx, sy; break end
        end
    end
    if not x then tlog("spawn aborted: no position"); return false end

    svs(SK.region, region_key)
    cm:create_force_with_general(
        faction_name, units, region_key, x, y,
        "general", gen_sub, "", "", "", "", false,
        function(char_cqi)
            local ch = char_cqi and cm:get_character_by_cqi(char_cqi)
            if not (ch and not ch:is_null_interface() and ch:has_military_force()) then
                tlog("spawn cb: general invalid"); end_run("spawn_fail"); return
            end
            local f = ch:military_force()
            svs(SK.pf, faction_name)
            svs(SK.pgen, ch:character_subtype_key())
            svs(SK.pl, char_cqi)
            svs(SK.pfcqi, f:command_queue_index())
            svs(SK.run, true)
            svs(SK.floor, 1)
            svs(SK.st, 1)
            svs(SK.sdust, 0)
            -- 竞逐者随新 run 重置
            svs(SK.riv, 0); svs(SK.rivmark, ""); svs(SK.rivwon, false)
            svs(SK.el2, 0)
            -- 词缀掷签（每 run 一签，SK.mut 逗号列表）；自谴者追加第二签
            local mk = ""
            if mct_bool("mutator", true) then
                mk = MUT_POOL[cm:random_number(#MUT_POOL) or 1] or ""
            end
            if sv(SK.selfmald, false) then
                svs(SK.selfmald, false)
                local p2 = {}
                for _, m in ipairs(MUT_POOL) do
                    if m ~= mk then p2[#p2 + 1] = m end
                end
                if #p2 > 0 then
                    local m2 = p2[cm:random_number(#p2)]
                    mk = (mk ~= "" and mk .. "," .. m2) or m2
                end
                -- 自谴回报：全局星尘获取 +50%
                svs(SK.modsd, mod_val(SK.modsd) + 0.5)
                tower_msg(faction, "psw_twr_selfmald_title", "psw_twr_selfmald_body")
            end
            svs(SK.mut, mk)
            for m in mk:gmatch("[^,]+") do
                tower_msg(faction, "psw_twr_mut_title", "psw_twr_mut_" .. m)
            end
            local asc = svn(asc_key(faction_name), 0)
            if asc >= 1 then
                tower_msg(faction, "psw_twr_asc_title",
                    "psw_twr_asc" .. math.min(asc, 3))
            end
            -- 道印：本流派已证道则开局赠一件普通祝福
            if svn("psw_twr_cl_" .. school_key(), 0) >= 1 then
                grant_seal(faction)
            end
            -- 镜像资源存在时归零，防止上局残留带入新 run
            pcall(function()
                local res = cm:get_faction(faction_name)
                    :pooled_resource_manager():resource(RES_KEY)
                local rv = res:value() or 0
                if rv ~= 0 then
                    cm:faction_add_pooled_resource(faction_name,
                        RES_KEY, RES_FACTOR, -rv)
                end
            end)
            save_snapshot(f)
            -- 天赋带入：本体每20个天赋祈愿军将领+1级（封顶+5）
            local tr = math.min(TALENT_RANK_CAP,
                math.floor(tower_talent_count(faction_name) / TALENT_RANK_PER))
            if tr > 0 then
                tpcall("talent_rank", function()
                    cm:add_agent_experience(cm:char_lookup_str(ch),
                        math.min((ch:rank() or 0) + tr, 40), true)
                end)
                tlog("talent resonance: +" .. tr .. " general ranks")
            end
            -- 英杰道：孤胆将领起 15 级 + 专属效果包挂全军（单机即主力）
            local sch = school_def()
            if sch.start_rank then
                tpcall("sch_rank", function()
                    cm:add_agent_experience(cm:char_lookup_str(ch),
                        math.max(ch:rank() or 0, sch.start_rank), true)
                end)
                tpcall("sch_bundle", function()
                    cm:apply_effect_bundle_to_force("psw_twr_sch_lord",
                        f:command_queue_index(), 0)
                end)
                tlog("lord school: rank>=" .. sch.start_rank .. " + psw_twr_sch_lord bundle")
            end
            cm:replenish_action_points(cm:char_lookup_str(ch:command_queue_index()))
            tlog("tower army spawned. force_cqi=" .. f:command_queue_index()
                .. " units=" .. units)
            launch_node(faction)
        end
    )
    return true
end

-- ---------- 对外入口 ----------
function psw_tower.enter(faction)
    if not faction or faction:is_null_interface() or not faction:is_human() then return end
    -- 待决锁：上一张困境未作答前禁止重入，杜绝连点叠困境。
    -- 锁只对本回合有效——引擎困境未答会阻塞结束回合，能跨回合必然是僵尸锁。
    if sv(SK.dlg, "") ~= "" then
        if svn(SK.dlgturn, -99) >= cm:turn_number() then
            tlog("enter blocked: dilemma pending " .. sv(SK.dlg, ""))
            return
        end
        tlog("enter: stale dilemma lock expired " .. sv(SK.dlg, ""))
        svs(SK.dlg, "")
    end
    local state = sv(SK.state, "")
    if sv(SK.run, false) and state ~= "" then
        -- 恢复待决困境
        if state == "node" then launch_node(faction)
        elseif state == "battle_pending" then launch_battle(faction)
        elseif state == "battle" then
            -- 战斗中存档：敌军可能仍在，清理后允许重打
            cleanup_enemy(); svs(SK.state, "battle_pending"); launch_battle(faction)
        elseif state == "reward" then launch_reward(faction)
        elseif state == "boon" then launch_boon(faction)
        elseif state == "rest" then launch_rest(faction)
        elseif state == "shop" then launch_shop(faction)
        elseif state == "event" then launch_event(faction)
        elseif state == "school" then launch_school(faction)
        elseif state == "defeat" then fire(DL.DEFEAT, faction, { FIRST = txt("psw_tower_pl_confirm") })
        elseif state == "victory" then fire(DL.VICTORY, faction, { FIRST = txt("psw_tower_pl_confirm") })
        else launch_node(faction) end
        return
    end
    -- 新试炼：冷却检查（防连续刷水晶）
    local last = svn(SK.lastend, -99)
    local cd_left = math.floor(mct_num("run_cd", RUN_CD)) - (cm:turn_number() - last)
    if cd_left > 0 then
        svs(SK.state, "")
        fire(DL.CD, faction, {
            FIRST  = txt("psw_tower_pl_cd"),
            SECOND = txt("psw_twr_card_menu"),
        })
        return
    end
    -- 走 builder 而非 trigger_dilemma：后者受"每派系每回合一困境"配额限制，
    -- 玩家本回合答过任意困境（含他 mod）后会被静默拒绝。
    fire(DL.OPENING, faction, {
        FIRST  = txt("psw_tower_pl_enter"),
        SECOND = txt("psw_tower_pl_leave"),
        THIRD  = txt("psw_twr_card_menu"),
        FOURTH = txt("psw_tower_pl_selfmald"),
    })
end

-- ---------- 选择路由 ----------
local function on_choice(context)
    local faction = context:faction()
    if not faction or faction:is_null_interface() or not faction:is_human() then return end
    local d = context:dilemma()
    local c = context:choice_key()
    local fname = faction:name()
    if d == sv(SK.dlg, "") then svs(SK.dlg, ""); svs(SK.dlgturn, -99) end  -- 已答困境解锁

    if d == DL.OPENING then
        if c == "FIRST" then launch_school(faction)
        elseif c == "THIRD" then launch_cards(faction)
        elseif c == "FOURTH" then
            -- 自谴试炼：立誓入局→自选流派，敌军多吃一条词缀换全局星尘+50%
            svs(SK.selfmald, true)
            launch_school(faction)
        end
    elseif d == DL.SCHOOL then
        if c == "FIFTH" then launch_school2(faction); return end
        local key = SCHOOL_ORDER[({ FIRST = 1, SECOND = 2, THIRD = 3,
            FOURTH = 4 })[c] or 1]
        svs(SK.school, key)
        tower_msg(faction, "psw_twr_school_pick", "psw_twr_school_" .. key)
        spawn_tower_army(faction)
    elseif d == DL.SCHOOL2 then
        if c == "THIRD" then launch_school(faction); return end
        local key = SCHOOL_ORDER2[({ FIRST = 1, SECOND = 2 })[c] or 1]
        svs(SK.school, key)
        tower_msg(faction, "psw_twr_school_pick", "psw_twr_school_" .. key)
        spawn_tower_army(faction)
    elseif d == DL.NODE then
        if c == "FOURTH" then end_run("quit"); return end
        if c == "FIFTH" then
            launch_cards(faction)
            -- 空手未发困境：直接回节点签面
            if sv(SK.dlg, "") == "" and sv(SK.state, "") == "node" then
                launch_node(faction)
            end
            return
        end
        local paths = {}
        for p in sv(SK.paths, ""):gmatch("[^,]+") do paths[#paths + 1] = p end
        svs(SK.paths, "")   -- 签面已兑现即清（防恢复重入再兑现）
        local idx = ({ FIRST = 1, SECOND = 2, THIRD = 3 })[c]
        local pt = idx and paths[idx]
        tlog("node choice: " .. tostring(c) .. " -> " .. tostring(pt))
        if pt == "battle" or pt == "boss" then
            psw_tower._start_battle(faction, pt == "boss" and "boss" or "normal")
        elseif pt == "elite" then
            psw_tower._start_battle(faction, "elite")
        elseif pt == "event" then launch_event(faction)
        elseif pt == "shop" then launch_shop(faction)
        elseif pt == "rest" then launch_rest(faction)
        else launch_node(faction)  -- sealed/异常路径重掷
        end
    elseif d == DL.BATTLE then
        if c == "FIRST" then do_attack(faction) end
        -- SECOND 稍后：保持 battle_pending
    elseif d == DL.REWARD then
        if c == "FOURTH" then
            gain_stardust(fname, REWARD_SKIP_STARDUST)
        end
        svs(SK.rewards, "")  -- 奖励已兑现即清档
        -- FIRST/SECOND/THIRD 由 add_unit payload 自动入伍，然后进祝福抉择
        launch_boon(faction)
    elseif d == DL.SHOP then
        local idx = ({FIRST=1,SECOND=2,THIRD=3})[c]
        if idx then
            local stock = {}
            for k in sv(SK.shop, ""):gmatch("[^,]+") do stock[#stock + 1] = k end
            local uk, tier = stock[idx], SHOP_TIERS[idx]
            local price = tier and shop_price(tier.price) or 0
            -- 先验将领/编制再扣款：拿不到货不吞星尘
            local gen = tower_general()
            local f = tower_force()
            local cap = f and f:unit_list():num_items() or 0
            if uk and tier and gen and cap < army_cap()
                and stardust(faction) >= price then
                cm:grant_unit_to_character(cm:char_lookup_str(gen), uk)
                add_stardust(fname, -price)
                svs(SK.shopuse, tostring(svn(SK.floor, 1)))
            else
                tlog("shop buy failed: gen=" .. tostring(gen ~= nil)
                    .. " cap=" .. cap .. " funds=" .. stardust(faction))
            end
            launch_node(faction)
        elseif c == "FOURTH" then
            -- 水晶兑换：1 共鸣水晶 → 150 星尘
            if tower_gmsj(faction) >= 1 then
                add_gmsj(fname, -1)
                add_stardust(fname, SHOP_GMSJ_STARDUST)
            else
                tlog("gmsj exchange failed: funds=0")
            end
            launch_node(faction)
        else launch_node(faction) end
        svs(SK.shop, "")  -- 离店清货架
    elseif d == DL.BOON then
        resolve_boon(faction, c)
    elseif d == DL.REST then
        resolve_rest(faction, c)
    elseif d == DL.CD then
        -- FIRST 仅确认；SECOND 打开星辉手牌（卡牌不受爬塔冷却限制）
        if c == "SECOND" then launch_cards(faction) end
    elseif d == DL.CARDS then
        local idx = ({ FIRST = 1, SECOND = 2, THIRD = 3, FOURTH = 4 })[c]
        if idx then
            use_card(faction, idx)
            if #card_list() > 0 then launch_cards(faction)
            elseif sv(SK.run, false) and sv(SK.state, "") == "node" then
                launch_node(faction)   -- 牌用尽回节点
            end
        else
            -- FIFTH 离开：run 中回节点，冷却期无事
            if sv(SK.run, false) and sv(SK.state, "") == "node" then
                launch_node(faction)
            end
        end
    elseif d == DL.EVENT then
        resolve_event(faction, c)
    elseif d == DL.DEFEAT then
        end_run("defeat")
    elseif d == DL.VICTORY then
        -- 竞逐者抢先登顶：通关国库/星尘减半；MCT victory_mult 总倍率
        local half = sv(SK.rivwon, false)
        local vmult = mct_num("victory_mult", 1) * (half and 0.5 or 1)
        tpcall("victory_reward", function()
            cm:treasury_mod(faction:name(), math.floor(VICTORY_TREASURY * vmult))
        end)
        add_stardust(faction:name(), math.floor(VICTORY_STARDUST * vmult))
        -- 登顶大赏：无双英雄/英灵从者/塔圣物，播报生态联动馈赠
        local link_key = grant_final_link(faction)
        if link_key then link_msg(faction, link_key) end
        -- 魔女亲授：EX 天赋直入祈愿槽 + 星辉临战 3 回合临时强化
        if grant_psw_talent(faction) then
            link_msg(faction, "psw_twr_link_top_talent")
        end
        grant_victory_buff(fname)
        link_msg(faction, "psw_twr_link_top_buff")
        -- 登顶加赏星辉禁咒牌一张（星陨/星缚——仪式级复刻，仅顶格馈赠可获）
        card_random_rare(faction)
        -- 证道记录：每流派首通额外馈赠共鸣水晶——五道集齐是重复爬塔的目标
        local sk = "psw_twr_cl_" .. school_key()
        local sch_bonus = math.floor(mct_num("school_gmsj", 5))
        if svn(sk, 0) == 0 and sch_bonus > 0 then
            add_gmsj(fname, sch_bonus)
            tower_msg(faction, "psw_twr_school_first", "psw_twr_school_" .. school_key())
        end
        svs(sk, svn(sk, 0) + 1)
        end_run("victory")
        -- 帝弓垂询：run 清算完后另起馈赠抉择（有合法目标才弹）
        launch_digong(faction)
    elseif d == DL.DIGONG then
        local pend = sv(SK.digong, "")
        svs(SK.digong, "")
        local tname = pend:match("|([^|]+)$")
        local tgt = (c == "FIRST") and digong_target(faction) or nil
        if c == "FIRST" and tname and tgt and tgt:name() == tname then
            local n = fire_digong(faction, tname)
            if n > 0 then
                link_msg(faction, "psw_twr_digong_done")
            else
                link_msg(faction, "psw_twr_digong_empty")
            end
        elseif c == "FIRST" then
            -- 目标已失效（和谈/灭国/存档复打），静默收弓
            link_msg(faction, "psw_twr_digong_empty")
        else
            -- 收弓：婉拒馈赠换 +2 共鸣水晶
            add_gmsj(fname, 2)
            link_msg(faction, "psw_twr_digong_hold_msg")
        end
    end
end

-- ---------- 战斗结算 ----------
local function tower_side_in_pending_battle()
    local pfcqi = svn(SK.pfcqi, 0)
    local plcqi = svn(SK.pl, 0)
    if pfcqi <= 0 and plcqi <= 0 then return nil end
    -- get_attacker/get_defender 返回 (char_cqi, mf_cqi, faction_name) 三个数值
    local function matches(char_cqi, mf_cqi)
        return (plcqi > 0 and char_cqi == plcqi)
            or (pfcqi > 0 and mf_cqi == pfcqi)
    end
    for i = 1, cm:pending_battle_cache_num_attackers() do
        if matches(cm:pending_battle_cache_get_attacker(i)) then return "attacker" end
    end
    for i = 1, cm:pending_battle_cache_num_defenders() do
        if matches(cm:pending_battle_cache_get_defender(i)) then return "defender" end
    end
    return nil
end

-- ---------- 监听器 ----------
-- 注：必须文件顶层直接注册，不能包 add_first_tick_callback——实测本机播放集
-- first_tick 回调链尾部 ~2 个条目会被静默跳过（疑似他 mod 迭代中删表项），
-- zzzz_* 文件注册最靠后必被吞。文件作用域注册的监听器已验证正常触发。
core:add_listener(
        "psw_tower_choice",
        "DilemmaChoiceMadeEvent",
        function(context)
            local d = context:dilemma()
            return type(d) == "string" and d:starts_with("psw_dilemma_tower_")
        end,
        function(context) tpcall("choice", function() on_choice(context) end) end,
        true
    )

    core:add_listener(
        "psw_tower_battle_done",
        "BattleCompleted",
        function(context)
            return sv(SK.state, "") == "battle" and svn(SK.pfcqi, 0) > 0
        end,
        function(context)
            tpcall("battle_done", function()
                local side = tower_side_in_pending_battle()
                if not side then return end
                local attacker_won = cm:pending_battle_cache_attacker_victory()
                local won = (side == "attacker" and attacker_won)
                    or (side == "defender" and not attacker_won)
                local faction = tower_faction()
                if not faction then
                    end_run("faction_lost"); return
                end
                cm:callback(function()
                    cm:disable_event_feed_events(false, "", "", "diplomacy_faction_destroyed")
                    cm:disable_event_feed_events(false, "", "", "character_dies_battle")
                end, 0.2)
                if won then on_victory(faction) else on_defeat(faction) end
            end)
        end,
        true
    )

    -- 回合钩子：竞逐者推进（仅入塔派系）+ 冷却结束"高塔再启"播报（任意人类派系）
    core:add_listener(
        "psw_tower_turn",
        "FactionTurnStart",
        function(context)
            local f = context:faction()
            return f and not f:is_null_interface() and f:is_human()
        end,
        function(context)
            tpcall("tower_turn", function()
                local f = context:faction()
                _mctv = {}   -- MCT 值缓存回合级失效
                if f:name() == sv(SK.pf, "") and sv(SK.run, false) then
                    rival_tick(f)
                end
                -- 回合交替兜底解锁：跨回合的待决锁必然僵尸（引擎未答困境会卡回合）
                if sv(SK.dlg, "") ~= "" and svn(SK.dlgturn, -99) < cm:turn_number() then
                    svs(SK.dlg, ""); svs(SK.dlgturn, -99)
                end
                reopen_notice(f)
                -- 帝弓垂询存档恢复：待决标志带属主校验，目标失效则清除
                local pend = sv(SK.digong, "")
                if pend ~= "" then
                    local pf, tname = pend:match("^([^|]+)|([^|]+)$")
                    if f:name() == pf then
                        local tgt = digong_target(f)
                        if tgt and tname and tgt:name() == tname then
                            launch_digong(f)
                        else
                            svs(SK.digong, "")
                        end
                    end
                end
            end)
        end,
        true
    )

        tlog("initialised")

-- ---------- 高塔星仪：常驻面板（PSW intel 面板式样，自有实例隔离监听） ----------
-- 顶栏圆钮开启/关闭；行列表 = 试炼入口 + 星辉卡牌 + 已获祝福；悬停看详情，点击出牌。
local HUB_PANEL  = "psw_tower_panel"
local HUB_LAYOUT = "ui/campaign ui/psw_tower_panel.twui.xml"
local HUB_BTN    = "psw_twr_hub_button"
local hub_rowmap = {}

local CARD_META = {
    march    = { name = "星步",   lore = "星辰为路，瞬息千里。" },
    recall   = { name = "归星",   lore = "游子归乡，星光引途。" },
    heal     = { name = "星愈",   lore = "星辉抚慰，创痍尽愈。" },
    winds    = { name = "星风",   lore = "魔风随星而涌。" },
    sight    = { name = "星眸",   lore = "星眸所及，迷雾尽散。" },
    order    = { name = "星律",   lore = "星轨有序，万民安堵。" },
    smith    = { name = "星锻",   lore = "星屑淬炼，圣物自成。" },
    crystal  = { name = "星晶",   lore = "星露凝华，以为馈赠。" },
    starfall = { name = "星陨",   lore = "禁咒——星雨涤荡敌土。" },
    starbind = { name = "星缚",   lore = "禁咒——星环锁敌之行。" },
}
local HUB_RAR = { n = "凡辉", r = "稀辉", s = "璨辉", c = "禁辉" }

local function hub_find()
    local pm = find_uicomponent(core:get_ui_root(), "panel_manager")
    return pm and find_uicomponent(pm, HUB_PANEL) or nil
end

local function hub_hide()
    local p = hub_find()
    if p then p:SetVisible(false) end
    cm:release_escape_key_with_callback("psw_twr_hub_hide")
end

local function hub_status()
    if sv(SK.run, false) then
        return "试炼进行中 · 第 " .. svn(SK.floor, 1) .. " / 30 层", "run"
    end
    local last = svn(SK.lastend, -99)
    local cd = math.floor(mct_num("run_cd", RUN_CD)) - (cm:turn_number() - last)
    if cd > 0 then return "高塔再启冷却：剩余 " .. cd .. " 回合", "cd" end
    return "高塔静默 · 可随时开启试炼", "ok"
end

local function hub_row_add(list, tpl, row)
    local id = row.id
    tpl:CopyComponent(id)
    local row_uic = find_uicomponent(list, id)
    if not row_uic then return end
    find_uicomponent(row_uic, "dy_action_name"):SetStateText(row.name, "")
    find_uicomponent(row_uic, "icon_action"):SetImagePath(
        "ui/skins/default/" .. row.icon .. ".png", 0)
    local holder = find_uicomponent(row_uic, "twr_holder_action")
    holder:SetContextObject(cco("CcoCampaignRoot", ""))
    holder:AddScriptEventReporter()
    find_uicomponent(row_uic, "resource_cost"):SetVisible(false)
    find_uicomponent(row_uic, "dy_cooldown"):SetVisible(false)
    if row.kind == "none" then
        row_uic:SetState("inactive")
    else
        row_uic:SetState("active")
    end
    row_uic:SetVisible(true)
    hub_rowmap[id] = row
end

local function hub_show(faction)
    if not faction or faction:is_null_interface() or not faction:is_human() then return end
    local pm = find_uicomponent(core:get_ui_root(), "panel_manager")
    if not pm then return end
    local panel = find_uicomponent(pm, HUB_PANEL)
    if not panel then
        panel = UIComponent(pm:CreateComponent(HUB_PANEL, HUB_LAYOUT))
    end
    if not panel then return end

    find_uicomponent(panel, "header_holder", "tx_header"):SetStateText("魔女高塔·星仪", "")
    local status, st = hub_status()
    local icon = find_uicomponent(panel, "dy_psw_intel")
    icon:SetStateText(status .. "　·　星尘 " .. svn(SK.sdust, 0)
        .. "　·　共鸣水晶 " .. tower_gmsj(faction), "")
    icon:SetTooltipText(
        "高塔馈赠尽汇于此——星辉卡牌点击即打出（战役侧即刻生效），已获祝福为本局试炼内的增益。", true)

    local list = find_uicomponent(panel, "list_intel_actions")
    local tpl = find_uicomponent(list, "template_action_button")
    for id in pairs(hub_rowmap) do
        local old = find_uicomponent(list, id)
        if old then old:SetVisible(false) end
    end
    hub_rowmap = {}

    if st == "run" then
        hub_row_add(list, tpl, {
            id = "psw_twr_menu_enter", kind = "enter", icon = "psw_twr_menu_enter",
            name = "继续试炼（第 " .. svn(SK.floor, 1) .. " 层）",
            title = "返回高塔", lore = "试炼未尽，星门仍为你敞开。",
            effect = status .. "——回到当前待决节点。" })
    elseif st == "cd" then
        hub_row_add(list, tpl, {
            id = "psw_twr_menu_enter", kind = "none", icon = "psw_twr_menu_enter",
            name = "高塔再启（冷却中）",
            title = "高塔再启", lore = "星门闭合，积蓄星辉。",
            effect = status .. "。下轮试炼冷却结束后可再入塔。" })
    else
        hub_row_add(list, tpl, {
            id = "psw_twr_menu_enter", kind = "enter", icon = "psw_twr_menu_enter",
            name = "开启试炼",
            title = "开启试炼", lore = "星穹之门于此显现。",
            effect = "掷路三十层，登塔问鼎——开启新一轮魔女试炼。" })
    end

    local empty = true
    for _, k in ipairs(card_list()) do
        empty = false
        local meta = CARD_META[k] or { name = k, lore = "" }
        hub_row_add(list, tpl, {
            id = "psw_twr_card_" .. k, kind = "card", key = k,
            icon = "psw_twr_card_" .. k, name = meta.name,
            title = "星辉卡牌·" .. meta.name, lore = meta.lore,
            effect = common.get_localised_string(
                "campaign_payload_ui_details_description_psw_twr_card_" .. k) })
    end
    for bk in sv(SK.boons, ""):gmatch("[^,]+") do
        empty = false
        for _, b in ipairs(psw_tower_pools.BOONS or {}) do
            if b.key == bk then
                hub_row_add(list, tpl, {
                    id = "psw_twr_boon_" .. bk, kind = "none",
                    icon = "psw_twr_boon_" .. (b.rar or "n"),
                    name = "【" .. (HUB_RAR[b.rar] or "凡辉") .. "】" .. (b.name or bk),
                    title = "高塔祝福·" .. (b.name or bk),
                    lore = "本局试炼内的祝福增益。",
                    effect = b.desc or "" })
                break
            end
        end
    end
    if empty then
        hub_row_add(list, tpl, {
            id = "psw_twr_menu_status", kind = "none", icon = "psw_twr_menu_status",
            name = "尚无星辉馈赠",
            title = "尚无馈赠", lore = "塔中试炼可得星辉卡牌与祝福。",
            effect = "Boss 层、登顶大赏与塔内事件均有馈赠——入塔夺取。" })
    end

    tpl:SetVisible(false)
    panel:Resize(panel:Width(), list:Height() + 150, false)
    panel:SetVisible(true)
    cm:release_escape_key_with_callback("psw_twr_hub_hide")
    cm:steal_escape_key_with_callback("psw_twr_hub_hide", hub_hide)
end

local function hub_ensure_button()
    local bg = find_uicomponent(core:get_ui_root(), "menu_bar", "buttongroup")
    if not bg then return end
    local b = find_uicomponent(bg, HUB_BTN)
    if not b then
        b = UIComponent(bg:CreateComponent(HUB_BTN, "ui/templates/round_small_button_toggle"))
        b:Resize(38, 38)
        b:SetImagePath("ui/skins/default/" .. HUB_BTN .. ".png", 0)
        b:SetTooltipText("魔女高塔·星仪——试炼入口、星辉卡牌与已获祝福。", true)
    end
    b:SetVisible(true)
end

core:add_listener(
    "psw_twr_hub_btn",
    "ComponentLClickUp",
    function(context) return context.string == HUB_BTN end,
    function()
        tpcall("hub_btn", function()
            local p = hub_find()
            if p and p:Visible() then
                hub_hide()
            else
                local f = cm:get_local_faction(true)
                if f then hub_show(f) end
            end
        end)
    end,
    true
)

core:add_listener(
    "psw_twr_hub_close",
    "ComponentLClickUp",
    function(context) return context.string == "button_psw_tower_close" end,
    function() hub_hide() end,
    true
)

core:add_listener(
    "psw_twr_hub_click",
    "ComponentLClickUp",
    function(context) return context.string == "twr_holder_action" end,
    function(context)
        tpcall("hub_click", function()
            local uic = UIComponent(context.component)
            local pa = uic and uic:Parent()
            local row = pa and hub_rowmap[UIComponent(pa):Id()]
            if not row then return end
            local f = cm:get_local_faction(true)
            if not f then return end
            if row.kind == "enter" then
                hub_hide()
                psw_tower.enter(f)
            elseif row.kind == "card" then
                for i, k in ipairs(card_list()) do
                    if k == row.key then
                        if use_card(f, i) then hub_show(f) end
                        return
                    end
                end
            end
        end)
    end,
    true
)

core:add_listener(
    "psw_twr_hub_hover",
    "ComponentMouseOn",
    function(context) return context.string == "twr_holder_action" end,
    function(context)
        local panel = hub_find()
        if not panel then return end
        local uic = UIComponent(context.component)
        local pa = uic and uic:Parent()
        local row = pa and hub_rowmap[UIComponent(pa):Id()]
        if not row then return end
        local ap = find_uicomponent(panel, "psw_action_panel")
        if not ap then return end
        ap:SetVisible(true)
        find_uicomponent(ap, "dy_action_title"):SetStateText(row.title or row.name, "")
        find_uicomponent(ap, "dy_action_lore"):SetStateText(row.lore or "", "")
        find_uicomponent(ap, "dy_effect_text"):SetStateText(row.effect or "", "")
        find_uicomponent(ap, "icon_action"):SetImagePath(
            "ui/skins/default/" .. row.icon .. ".png", 0)
        local lb = find_uicomponent(ap, "list_box")
        if lb then ap:Resize(lb:Width() + 20, lb:Height() + 40, false) end
    end,
    true
)

core:add_listener(
    "psw_twr_hub_hover_off",
    "ComponentMouseOff",
    function(context) return context.string == "twr_holder_action" end,
    function()
        local p = hub_find()
        local ap = p and find_uicomponent(p, "psw_action_panel")
        if ap then ap:SetVisible(false) end
    end,
    true
)

core:add_listener(
    "psw_twr_hub_ensure",
    "UICreated",
    function() return true end,
    function() hub_ensure_button() end,
    true
)

cm:add_first_tick_callback(function()
    hub_ensure_button()
    cm:callback(hub_ensure_button, 1)
end)

core:add_listener(
    "psw_twr_hub_ensure_turn",
    "FactionTurnStart",
    function(context)
        local f = context:faction()
        return f and not f:is_null_interface() and f:is_human()
    end,
    function() hub_ensure_button() end,
    true
)

-- ---------- 诊断导出（配合 !psw_tower_diag0.lua 测试，发布前随诊断件一并移除） ----------
psw_tower._dbg = {
    card   = function(f, k) return card_add(f, k) end,
    rare   = function(f) return card_random_rare(f) end,
    use    = function(f, i) return use_card(f, i) end,
    hand   = function(f) launch_cards(f) end,
    jyjj   = function(f, t) return grant_jyjj_card(f, t) end,
    digong = function(f) launch_digong(f) end,
    talent = function(f) return grant_psw_talent(f) end,
    eforce = function(f) svs(SK.lastend, -99) psw_tower.enter(f) end,
    -- 调试菜单（builder 路径，绕 trigger_dilemma 配额）
    menu   = function(f)
        local b = cm:create_dilemma_builder("psw_dilemma_tower_dbg")
        local p = cm:create_payload()
        for _, c in ipairs({ "FIRST", "SECOND", "THIRD", "FOURTH", "FIFTH" }) do
            b:add_choice_payload(c, p)
            p:clear()
        end
        svs(SK.dlg, "psw_dilemma_tower_dbg")
        svs(SK.dlgturn, cm:turn_number())
        cm:launch_custom_dilemma_from_builder(b, f)
    end,
}
