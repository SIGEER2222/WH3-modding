-- 监牢系统：完全独立于 Eltharion 原生 prison campaign feature。
--
-- 角色状态模型：
--   family_member_cqi 是稳定身份；character_cqi 只是当前实例缓存。
--   收押 = 原角色保持在原派系，但被 cm:wound_character 置为长期不可用。
--   释放 = 原英雄解除负伤；原领主解除负伤后在原派系首都重建军队。
--   领主招降 = 外派系领主按原 subtype、姓名和等级重建，验证成功后清除原角色；已属玩家的领主原位恢复。
--   英雄招降 = 按原事务官类型与 subtype 重建；重建路径不复制原技能加点或装备。
--   领袖附庸 = 为玩家重建该领袖，再永久杀死原派系的原 family member。
-- 所有持久化值均为普通 Lua 表，不保存脚本接口或 UI 地址。

local PREFIX = "WycccPrisonSystem: "
local STATE_KEY = "wyccc_prison_independent_state"
-- Match the root id of the standalone vanilla-derived layout.  The layout is
-- self-owned and has no native prison-feature callback; only its MoviePlayer
-- and ScreenSizedComponent callbacks are retained.
-- Use the shipped Athel Tamarha TWUI as the visual shell.  It contains the
-- real MoviePlayer background, screen-size callback, rune rings, upgrade
-- shards and correctly anchored rite buttons.  The prison state machine still
-- owns all data and callbacks below; the vanilla UI is only a layout/art
-- dependency and is never connected to the native prison feature.
local VANILLA_UI_ROOT = "ui/skins/warhammer2/"
local PORTRAIT_UI_ROOT = "ui/portraits/portholes/no_culture/"
local SVR_DETECTED = "wyccc_prison_battle_target_detected"
local SVR_TARGET_FACTION = "wyccc_prison_battle_target_faction"
local SVR_TARGET_ARMY_INDEX = "wyccc_prison_battle_target_army_index"
local SVR_TARGET_ARMY_ID = "wyccc_prison_battle_target_army_id"
local SVR_TARGET_UNIT_ID = "wyccc_prison_battle_target_unit_id"
local SVR_WARDEN_FACTION = "wyccc_prison_battle_warden_faction"
local SVR_WARDEN_SIDE = "wyccc_prison_battle_warden_side"
local SVR_CAGE_KILLED = "wyccc_prison_cage_target_killed"
local SVR_CAGE_WINDOW_EXPIRED = "wyccc_prison_cage_window_expired"
local SVR_QUEST_BATTLE = "wyccc_prison_battle_is_quest"

local FACILITIES = {"capacity", "recruitment", "ransom", "interrogation"}
local FACILITY_NAMES = {
    capacity = "wyccc_prison_ui_facility_capacity_name",
    recruitment = "wyccc_prison_ui_facility_recruitment_name",
    ransom = "wyccc_prison_ui_facility_ransom_name",
    interrogation = "wyccc_prison_ui_facility_interrogation_name"
}
local FACILITY_COSTS = {3000, 7500, 15000}
local RECRUIT_CHANCE = {25, 40, 55}
local RANSOM_MULTIPLIER = {1.0, 1.5, 2.0}
local INTERROGATION_XP_POOL = {2000, 4000, 6000}
local INTERROGATION_RECRUITMENT_BONUS = {15, 15, 15}
local MAX_FACILITY_LEVEL = 3
local BASE_CAPACITY = 1
local CONVALESCENCE_TURNS = 9999
-- Cross-culture confederation can destroy a wounded legendary lord's original
-- family member instead of transferring it.  Give the native transfer several
-- seconds to settle before rebuilding that unique subtype in the player's pool.
local LEGENDARY_RESTORE_MAX_ATTEMPTS = 50
local LEGENDARY_PRE_CONFEDERATION_MAX_ATTEMPTS = 30
-- spawn_character_to_pool does not infer a unique lord's canonical campaign
-- art set when that lord is rebuilt for a foreign-culture faction.  Keep only
-- verified vanilla mappings here; unknown subtypes continue to use their DB
-- default instead of receiving a guessed model key.
local LEADER_DISPOSITION_DILEMMA = "wyccc_prison_leader_disposition"
local LEADER_DISPOSITION_CHOICES = {annex = 0, vassal = 1, destroy = 2, release = 3}
-- Defined in 基础前置 so lottery and prison systems share the same
-- compensation traits.  These are applied only to a recruited prisoner
-- whose original culture differs from the warden's culture.
local NON_NATIVE_LORD_TRAIT = "wyc_lord"
local NON_NATIVE_HERO_TRAIT = "wyc_hero"
-- New-campaign demonstration hook: find the AI-controlled Alarielle,
-- wound the real character instance, and put that same family member into
-- the independent prison so the full UI/action path can be tested.
local STARTUP_ALARIELLE_TEST_ENABLED = false
local STARTUP_ALARIELLE_SUBTYPE = "wh2_dlc10_hef_alarielle"
local STARTUP_ALARIELLE_FACTION = "wh2_main_hef_avelorn"
local STARTUP_ALARIELLE_MAX_ATTEMPTS = 6
local RECRUIT_UNIT = "wh_main_emp_inf_spearmen_0"
local CAGE_BUNDLE = "wyccc_prison_wardens_cage_bundle"
local HELD_EFFECTS = {
    wh_dlc03_bst_beastmen = "wyccc_prison_held_beastmen",
    wh_main_brt_bretonnia = "wyccc_prison_held_bretonnia",
    wh_main_chs_chaos = "wyccc_prison_held_chaos_warriors",
    wh2_main_def_dark_elves = "wyccc_prison_held_dark_elves",
    wh_main_dwf_dwarfs = "wyccc_prison_held_dwarfs",
    wh_main_emp_empire = "wyccc_prison_held_empire",
    wh3_main_ksl_kislev = "wyccc_prison_held_kislev",
    wh3_main_pro_ksl_kislev = "wyccc_prison_held_kislev",
    wh3_main_cth_cathay = "wyccc_prison_held_cathay",
    wh_main_grn_greenskins = "wyccc_prison_held_greenskins",
    wh2_main_hef_high_elves = "wyccc_prison_held_high_elves",
    wh2_main_lzd_lizardmen = "wyccc_prison_held_lizardmen",
    wh_dlc08_nor_norsca = "wyccc_prison_held_norsca",
    wh2_main_skv_skaven = "wyccc_prison_held_skaven",
    wh2_dlc09_tmb_tomb_kings = "wyccc_prison_held_tomb_kings",
    wh2_dlc11_cst_vampire_coast = "wyccc_prison_held_vampire_coast",
    wh_main_vmp_vampire_counts = "wyccc_prison_held_vampire_counts",
    wh_dlc05_wef_wood_elves = "wyccc_prison_held_wood_elves",
    wh3_main_dae_daemons = "wyccc_prison_held_daemons",
    wh3_main_kho_khorne = "wyccc_prison_held_khorne",
    wh3_main_nur_nurgle = "wyccc_prison_held_nurgle",
    wh3_main_sla_slaanesh = "wyccc_prison_held_slaanesh",
    wh3_main_tze_tzeentch = "wyccc_prison_held_tzeentch",
    wh3_main_ogr_ogre_kingdoms = "wyccc_prison_held_ogre_kingdoms",
    wh2_main_rogue = "wyccc_prison_held_rogue_armies",
    wh3_dlc23_chd_chaos_dwarfs = "wyccc_prison_held_chaos_dwarfs"
}
local HELD_EFFECT_LIST = {}
for _, effect in pairs(HELD_EFFECTS) do
    HELD_EFFECT_LIST[effect] = true
end

local INTERROGATION_EFFECT_BY_CULTURE = {
    wh_dlc03_bst_beastmen = "wyccc_prison_interrogate_beastmen",
    wh_main_brt_bretonnia = "wyccc_prison_interrogate_bretonnia",
    wh3_main_cth_cathay = "wyccc_prison_interrogate_cathay",
    wh3_dlc23_chd_chaos_dwarfs = "wyccc_prison_interrogate_chaos_dwarfs",
    wh_main_chs_chaos = "wyccc_prison_interrogate_chaos_warriors",
    wh3_main_dae_daemons = "wyccc_prison_interrogate_daemons",
    wh3_main_kho_khorne = "wyccc_prison_interrogate_daemons",
    wh3_main_nur_nurgle = "wyccc_prison_interrogate_daemons",
    wh3_main_sla_slaanesh = "wyccc_prison_interrogate_daemons",
    wh3_main_tze_tzeentch = "wyccc_prison_interrogate_daemons",
    wh2_main_def_dark_elves = "wyccc_prison_interrogate_dark_elves",
    wh_main_dwf_dwarfs = "wyccc_prison_interrogate_dwarfs",
    wh_main_emp_empire = "wyccc_prison_interrogate_empire",
    wh_main_grn_greenskins = "wyccc_prison_interrogate_greenskins",
    wh2_main_hef_high_elves = "wyccc_prison_interrogate_high_elves",
    wh3_main_ksl_kislev = "wyccc_prison_interrogate_kislev",
    wh3_main_pro_ksl_kislev = "wyccc_prison_interrogate_kislev",
    wh2_main_lzd_lizardmen = "wyccc_prison_interrogate_lizardmen",
    wh_dlc08_nor_norsca = "wyccc_prison_interrogate_norsca",
    wh3_main_ogr_ogre_kingdoms = "wyccc_prison_interrogate_ogre_kingdoms",
    wh2_main_rogue = "wyccc_prison_interrogate_rogue_army",
    wh2_main_skv_skaven = "wyccc_prison_interrogate_skaven",
    wh2_dlc09_tmb_tomb_kings = "wyccc_prison_interrogate_tomb_kings",
    wh2_dlc11_cst_vampire_coast = "wyccc_prison_interrogate_vampire_coast",
    wh_main_vmp_vampire_counts = "wyccc_prison_interrogate_vampire_counts",
    wh_dlc05_wef_wood_elves = "wyccc_prison_interrogate_wood_elves"
}

local state_by_faction = {}
local panel_uic = nil
local entry_button_uic = nil
local selected_prisoner_index = 0
local recruit_pending = {}
local annex_pool_fallback_spawned = {}
local cross_culture_annex = {
    release_restore_pending = {},
    release_restore_max_attempts = 30
}
cross_culture_annex.panel_key = "wyccc_prison_panel"
cross_culture_annex.panel_ui_path = "ui/campaign ui/wyccc_prison_system.twui.xml"
cross_culture_annex.debug_prefix = "[DEBUG-PRISON-KILL] "
cross_culture_annex.debug_enabled = false
cross_culture_annex.interrogation_effect_duration = 3
cross_culture_annex.recruit_failure_rollback_max_attempts = 30
local recruit_button_uic = nil
local ransom_button_uic = nil
local release_button_uic = nil
local interrogate_button_uic = nil
local recruit_chance_text = nil
local prisoner_slots = {}
local facility_buttons = {}
local facility_nodes = {}
local facility_frames = {}
local facility_detail_title = nil
local facility_detail_text = nil
local facility_detail_icon = nil
local facility_upgrade_button = nil
local facility_upgrade_level_text = nil
local facility_upgrade_cost_text = nil
-- The vanilla tooltip tree only defines the level-1 perform button.  Keep
-- native-looking perform buttons for levels 2/3 here so the arrow follows the
-- currently available shard instead of disappearing after level 1.
local upgrade_action_buttons = {left = {}, right = {}}
-- Handles supplied by the vanilla Athel Tamarha layout.  Keeping these
-- separate from the custom overlays lets refresh_ui update text/actions
-- without moving any of the original anchors.
local vanilla_title_uic = nil
local vanilla_upgrade_total_parent_uic = nil
local vanilla_upgrade_counter_uic = nil
local vanilla_warden_supply_uic = nil
local vanilla_upgrade_total_uic = nil
local vanilla_upgrade_label_uic = nil
local vanilla_upgrade_icon_uic = nil
local vanilla_close_uic = nil
local vanilla_info_uic = nil
local vanilla_left_side_uic = nil
local vanilla_right_side_uic = nil
local slot_portraits = {}
local slot_frames = {}
local slot_labels = {}
local visual_ui_ready = false
local visual_scale = 1
-- BattleCompleted/BattleCompletedCameraMove can fire many times while the
-- player is holding the end-turn button.  A hidden prison panel has no visual
-- state to update, so skip the expensive vanilla-tree traversal in that case;
-- also prevent a UI callback from re-entering refresh_ui while it is binding
-- tooltip/listener state.
local ui_refresh_in_progress = false
local selected_facility_key = "capacity"
local setup_ui
local refresh_ui
local queue_prison_incident
local queue_leader_disposition_event
local perform_recruit
local pending_battle_snapshot = {attackers = {}, defenders = {}, warden_key = "", warden_side = ""}
-- Battle outcome callbacks run while the engine still owns transient character
-- and military-force interfaces.  Store only primitive capture evidence here;
-- the prison transaction is committed after the complete battle
-- sequence, when those interfaces are stable again.
local pending_battle_capture_finalizations = {}
local startup_alarielle_test_done = false

local function log(message)
    out(PREFIX .. tostring(message))
end

local function debug_log(message)
    if not cross_culture_annex.debug_enabled then return end
    out(cross_culture_annex.debug_prefix .. tostring(message))
end

-- All player-facing runtime text must resolve through localisation so the
-- English collection can override it without changing this campaign script.
local function localised(key)
    local value = ""
    if common and common.get_localised_string then
        pcall(function() value = common.get_localised_string(key) or "" end)
    end
    if type(value) == "string" and value ~= "" and value ~= key then
        return value
    end
    return key
end

local function localised_format(key, replacements)
    local value = localised(key)
    for token, replacement in pairs(replacements or {}) do
        value = string.gsub(value, "{" .. tostring(token) .. "}", tostring(replacement))
    end
    return value
end

local function facility_name(facility)
    return localised(FACILITY_NAMES[facility] or tostring(facility or ""))
end

function cross_culture_annex.leader_capture_unlock_count()
    local value = 3
    if type(get_mct) == "function" then
        local ok_mct, mct = pcall(get_mct)
        if ok_mct and mct then
            local ok_mod, mod = pcall(function()
                return mct:get_mod_by_key("wyccc_prison_system")
            end)
            if ok_mod and mod then
                local ok_option, option = pcall(function()
                    return mod:get_option_by_key("leader_capture_unlock_count")
                end)
                if ok_option and option then
                    local ok_value, selected = pcall(function()
                        return option:get_finalized_setting()
                    end)
                    if ok_value then value = tonumber(selected) or value end
                end
            end
        end
    end
    value = math.floor(tonumber(value) or 3)
    if value < 1 or value > 3 then
        return 3
    end
    return value
end

-- CA-owned factions use the wh_, wh2_ or wh3_ namespace.  This admits every
-- vanilla/DLC faction without granting the prison to normally named third-
-- party factions.  Yvresse keeps its own native Athel Tamarha prison system.
function cross_culture_annex.is_prison_faction_key(faction_key)
    local key = tostring(faction_key or "")
    if key == "wh2_dlc15_hef_yvresse" then return false end
    return string.match(key, "^wh_") ~= nil
        or string.match(key, "^wh2_") ~= nil
        or string.match(key, "^wh3_") ~= nil
end

local function is_warden_faction(faction)
    if not faction then return false end
    local ok_null, is_null = pcall(function() return faction:is_null_interface() end)
    -- Treat an unsupported null probe as an unknown (and continue with the
    -- authoritative faction name); only an explicit null result is rejected.
    if ok_null and is_null then return false end
    local ok_name, name = pcall(function() return faction:name() end)
    return ok_name and cross_culture_annex.is_prison_faction_key(name)
end

local function is_player_warden(faction)
    if not is_warden_faction(faction) then return false end
    local human = false
    pcall(function() human = faction:is_human() end)
    return human == true
end

local function new_state()
    return {
        facilities = {capacity = 0, recruitment = 0, ransom = 0, interrogation = 0},
        prisoners = {},
        interrogated_effects = {},
        -- Counts are keyed by source faction and stable family-member CQI so
        -- releasing a leader does not erase the progress needed to unlock
        -- recruitment/interrogation on a later capture.
        leader_capture_counts = {},
        -- One shared prison action is available to the faction per campaign
        -- turn.  The value is persisted with the independent prison state so
        -- reloads cannot reopen an action that was already spent this turn.
        last_action_turn = -1,
        last_action_name = "",
        last_action_family_member_cqi = 0,
        -- A third faction-leader capture pauses here until the player chooses
        -- annexation, vassalage, destruction or release.  Keep this in the
        -- prison save, not a transient Lua table, so saving while the dilemma
        -- is open cannot lose the target.
        pending_leader_dispositions = {},
        -- A rebuilt legendary lord is a CHARACTER_DETAILS while still in the
        -- recruitment pool, so the model override API cannot target it yet.
        -- Persist the exact family member/art set until CharacterRecruited.
        pending_pool_art_sets = {}
    }
end

local function get_state(faction_key)
    if not state_by_faction[faction_key] then
        state_by_faction[faction_key] = new_state()
    end
    local state = state_by_faction[faction_key]
    -- Migrate saves made before the shared action ledger and interrogation
    -- bonus fields existed.  Existing prisoners remain valid and simply start
    -- with no bonus.
    state.facilities = state.facilities or {}
    state.prisoners = state.prisoners or {}
    state.interrogated_effects = state.interrogated_effects or {}
    state.leader_capture_counts = state.leader_capture_counts or {}
    state.pending_leader_dispositions = state.pending_leader_dispositions or {}
    state.pending_pool_art_sets = state.pending_pool_art_sets or {}
    state.last_action_turn = tonumber(state.last_action_turn) or -1
    state.last_action_name = tostring(state.last_action_name or "")
    state.last_action_family_member_cqi = tonumber(state.last_action_family_member_cqi) or 0
    for _, prisoner in ipairs(state.prisoners) do
        prisoner.recruitment_bonus = tonumber(prisoner.recruitment_bonus) or 0
        prisoner.is_faction_leader = prisoner.is_faction_leader == true
        prisoner.is_unique = prisoner.is_unique == true
        prisoner.is_unit = prisoner.is_unit == true
        prisoner.leader_capture_count = tonumber(prisoner.leader_capture_count) or 0
    end
    return state
end

local function current_turn_number()
    local turn = nil
    pcall(function() turn = cm:model():turn_number() end)
    return tonumber(turn) or 0
end

local function prison_action_available(state)
    if not state then return false end
    return tonumber(state.last_action_turn) ~= current_turn_number()
end

local function consume_prison_action(state, action_name, record)
    if not prison_action_available(state) then return false end
    state.last_action_turn = current_turn_number()
    state.last_action_name = tostring(action_name or "")
    state.last_action_family_member_cqi = tonumber(record and record.family_member_cqi or 0) or 0
    return true
end

local function recruitment_chance(state, record)
    local facility_level = tonumber(state and state.facilities and state.facilities.recruitment) or 0
    local base = tonumber(RECRUIT_CHANCE[facility_level]) or 0
    local bonus = tonumber(record and record.recruitment_bonus) or 0
    return math.max(0, math.min(100, base + bonus))
end

local function safe_interface(value)
    if not value then return false end
    local ok, is_null = pcall(function() return value:is_null_interface() end)
    -- Battle-result wrappers can become invalid at engine lifetime boundaries.
    -- Treat a failed probe as unusable instead of forwarding the wrapper into
    -- another C++ interface call that pcall cannot reliably contain.
    if not ok then return false end
    return is_null ~= true
end

-- The campaign runtime is Lua 5.1 (where unpack is global); desktop Lua
-- 5.2+ exposes the same helper as table.unpack.  Keep call_or portable so a
-- failed compatibility lookup does not silently turn every interface call
-- into its fallback value.
local unpack_fn = unpack or table.unpack

local function call_or(object, method, fallback, ...)
    if not object then return fallback end
    local args = {...}
    local ok, value = pcall(function()
        return object[method](object, unpack_fn(args))
    end)
    if ok and value ~= nil then return value end
    return fallback
end

function cross_culture_annex.is_quest_battle()
    -- Battle Lua preserves this flag across the return to campaign, when the
    -- pending-battle cache may already have been cleared by the engine.
    if call_or(core, "svr_load_bool", false, SVR_QUEST_BATTLE) == true then return true end
    return call_or(cm, "pending_battle_cache_is_quest_battle", false) == true
end

function cross_culture_annex.is_garrison_force_cqi(mf_cqi)
    mf_cqi = tonumber(mf_cqi) or 0
    if mf_cqi <= 0 then return false end
    local force = call_or(cm, "get_military_force_by_cqi", nil, mf_cqi)
    return safe_interface(force) and call_or(force, "is_armed_citizenry", false) == true
end

function cross_culture_annex.is_garrison_character(character)
    if not safe_interface(character) then return false end
    -- Generated colonels and settlement heroes cannot be held as persistent
    -- campaign characters. Check their force before asking for family/details.
    if call_or(character, "character_type_key", "") == "colonel" then return true end
    if call_or(character, "has_military_force", false) then
        local force = call_or(character, "military_force", nil)
        if safe_interface(force) and call_or(force, "is_armed_citizenry", false) then return true end
    end
    if call_or(character, "is_embedded_in_military_force", false) then
        local force = call_or(character, "embedded_in_military_force", nil)
        if safe_interface(force) and call_or(force, "is_armed_citizenry", false) then return true end
    end
    -- has_garrison_residence also includes real characters visiting a town.
    return false
end

function cross_culture_annex.after_battle_sequence(name, callback, delay)
    -- CA's progress_on_battle_completed waits for the player-turn-only event.
    -- AI-turn defence needs the general event, including when completion was
    -- emitted before this mod's BattleCompleted listener queued its work.
    delay = delay or 0
    local function resume()
        if call_or(cm, "is_processing_battle", false) then
            core:add_listener(name, "ScriptEventBattleSequenceCompleted", true,
                function() cm:callback(resume, delay) end, false)
        else
            callback()
        end
    end
    if delay > 0 then cm:callback(resume, delay) else resume() end
end

local function character_type_key(character)
    local type_key = call_or(character, "character_type_key", "")
    if type_key == "" then
        local details = call_or(character, "character_details", nil)
        type_key = call_or(details, "character_type_key", "")
    end
    return tostring(type_key or "")
end

local function prisoner_role(record, character)
    local role = tostring(record and record.role or "")
    if role == "lord" or role == "hero" then return role end

    local type_key = tostring(record and record.character_type_key or "")
    if type_key == "" then type_key = character_type_key(character) end
    if type_key == "general" then return "lord" end
    if type_key ~= "" then return "hero" end
    -- Old saves do not have the persisted role/type fields.  A faction leader
    -- is necessarily a lord, so retain the safe fallback for those records.
    if record and record.is_faction_leader == true then return "lord" end
    return nil
end

local function faction_culture_key(faction)
    return tostring(call_or(faction, "culture", "") or "")
end

local function add_non_native_recruitment_trait(warden_faction, record, character)
    if not safe_interface(warden_faction) or not record then return false end

    local role = prisoner_role(record, character)
    if not role then
        log("non-native trait skipped: role unavailable for family member "
            .. tostring(record.family_member_cqi))
        return false
    end

    local player_culture = faction_culture_key(warden_faction)
    local source_culture = tostring(record.source_culture or "")
    if source_culture == "" then
        local source_faction = nil
        pcall(function() source_faction = cm:get_faction(record.source_faction) end)
        source_culture = faction_culture_key(source_faction)
    end
    if player_culture == "" or source_culture == "" then
        log("non-native trait skipped: culture unavailable for family member "
            .. tostring(record.family_member_cqi))
        return false
    end
    if player_culture == source_culture then
        log("non-native trait skipped: same culture for family member "
            .. tostring(record.family_member_cqi))
        return false
    end
    if not safe_interface(character) then return false end

    local char_cqi = tonumber(call_or(character, "command_queue_index", 0)) or 0
    if char_cqi <= 0 then return false end
    local trait = role == "lord" and NON_NATIVE_LORD_TRAIT or NON_NATIVE_HERO_TRAIT
    local ok, err = pcall(function()
        cm:force_add_trait(cm:char_lookup_str(char_cqi), trait, true, 1)
    end)
    if not ok then
        log("non-native trait failed: trait=" .. trait .. ", error=" .. tostring(err))
        return false
    end
    log("non-native recruitment trait added: role=" .. role .. ", trait=" .. trait
        .. ", source_culture=" .. source_culture .. ", player_culture=" .. player_culture)
    return true
end

local function leader_capture_key(source_faction_key, family_member_cqi, subtype)
    local faction_key = tostring(source_faction_key or "")
    local fm_cqi = tonumber(family_member_cqi) or 0
    if fm_cqi > 0 then
        return faction_key .. ":" .. tostring(fm_cqi)
    end
    return faction_key .. ":subtype:" .. tostring(subtype or "")
end

local function faction_leader_status(source_faction, character, family_member_cqi)
    if not safe_interface(source_faction) then return nil end
    local leader = nil
    pcall(function() leader = source_faction:faction_leader() end)
    if not safe_interface(leader) then return nil end

    local leader_fm_cqi = 0
    pcall(function()
        local leader_fm = leader:family_member()
        if safe_interface(leader_fm) then leader_fm_cqi = leader_fm:command_queue_index() end
    end)
    if tonumber(leader_fm_cqi) and tonumber(leader_fm_cqi) > 0 then
        return tonumber(leader_fm_cqi) == tonumber(family_member_cqi)
    end

    local leader_cqi = tonumber(call_or(leader, "command_queue_index", 0)) or 0
    local character_cqi = tonumber(call_or(character, "command_queue_index", 0)) or 0
    if leader_cqi > 0 and character_cqi > 0 then
        return leader_cqi == character_cqi
    end
    return nil
end

local function leader_capture_count(state, record)
    if not record or record.is_faction_leader ~= true then return 0 end
    local count = tonumber(record.leader_capture_count) or 0
    if count > 0 then return count end
    local key = record.leader_capture_key
    if not key or key == "" then
        key = leader_capture_key(record.source_faction, record.family_member_cqi, record.subtype)
    end
    return tonumber(state and state.leader_capture_counts and state.leader_capture_counts[key]) or 0
end

local function leader_actions_unlocked(state, record)
    local required_count = cross_culture_annex.leader_capture_unlock_count()
    return not record or record.is_faction_leader ~= true
        or leader_capture_count(state, record) >= required_count
end

local function leader_action_requirement_text(state, record)
    if not record or record.is_faction_leader ~= true then return nil end
    local count = leader_capture_count(state, record)
    local required_count = cross_culture_annex.leader_capture_unlock_count()
    if count >= required_count then return nil end
    return localised_format("wyccc_prison_runtime_leader_action_locked", {
        REQUIRED_COUNT = required_count,
        CURRENT_COUNT = count
    })
end

local function current_character(family_member_cqi)
    local character = nil
    pcall(function() character = cm:get_character_by_fm_cqi(family_member_cqi) end)
    if safe_interface(character) then
        return character
    end
    local fm = nil
    pcall(function() fm = cm:get_family_member_by_cqi(family_member_cqi) end)
    if safe_interface(fm) then
        pcall(function() character = fm:character() end)
    end
    if safe_interface(character) then
        return character
    end
    return nil
end

local function current_family_member(family_member_cqi)
    local family_member = nil
    pcall(function()
        family_member = cm:get_family_member_by_cqi(family_member_cqi)
    end)
    if safe_interface(family_member) then
        return family_member
    end
    return nil
end

local function character_name(character)
    if not safe_interface(character) then
        return localised("wyccc_prison_runtime_unknown_character")
    end
    local name = ""
    pcall(function()
        name = common.get_localised_string(character:get_forename())
            .. " " .. common.get_localised_string(character:get_surname())
    end)
    if name:gsub("%s", "") == "" then
        pcall(function() name = character:character_subtype_key() end)
    end
    return name
end

local function portrait_for_character_cqi(character_cqi)
    local cqi = tonumber(character_cqi) or 0
    if cqi <= 0 then return nil end
    local portrait = nil
    pcall(function()
        portrait = common.get_context_value("CcoCampaignCharacter", cqi, "PortraitPath")
    end)
    if type(portrait) ~= "string" or portrait == "" then
        return nil
    end
    return portrait
end

-- Dead campaign characters no longer expose a usable CcoCampaignCharacter
-- portrait context.  The prison record still contains the subtype, so retain
-- a native portrait from the subtype's vanilla portrait-settings entry.  This
-- is deliberately a small, verified fallback set: it covers the commander
-- families that can be used by the independent prison and never invents a
-- path for an unknown subtype.
local PORTRAIT_BY_SUBTYPE = {
    wh3_main_cth_lord_magistrate_yang = PORTRAIT_UI_ROOT .. "cth_lord_magistrate_campaign_01_0.png",
    wh3_main_cth_lord_magistrate_yin = PORTRAIT_UI_ROOT .. "cth_lord_magistrate_campaign_01_0.png",
    wh3_dlc24_cth_lord_magistrate_reserves = PORTRAIT_UI_ROOT .. "cth_lord_magistrate_campaign_01_0.png",
    wh3_main_cth_dragon_blooded_shugengan_yang = PORTRAIT_UI_ROOT .. "cth_shugengan_lord_campaign_01_0.png",
    wh3_main_cth_dragon_blooded_shugengan_yin = PORTRAIT_UI_ROOT .. "cth_shugengan_lord_campaign_01_0.png",
    wh3_dlc24_cth_celestial_general = PORTRAIT_UI_ROOT .. "cth_celestial_general_campaign_01_0.png",
    wh3_dlc24_cth_celestial_general_hero = PORTRAIT_UI_ROOT .. "cth_celestial_general_campaign_01_0.png",
}

local PORTRAIT_BY_FACTION = {
    -- The Nan Yang rebel lord roster uses the vanilla Yang magistrate portrait
    -- family.  This is also the fallback when a defeated general's subtype
    -- has already disappeared from the PendingBattle cache.
    wh3_main_cth_rebel_lords_of_nan_yang = PORTRAIT_UI_ROOT .. "cth_lord_magistrate_campaign_01_0.png",
}

-- Saves made while the first independent-capture implementation was active
-- can contain the stable character/family CQIs and portrait, but no subtype.
-- Keep migrations exact: this pair is the vanilla Northern Provinces opening
-- enemy defined in wh3_starting_armies.lua, whose generated general is the
-- Yang Lord Magistrate.  Do not reverse PORTRAIT_BY_SUBTYPE globally because
-- several legitimate Yin/Yang subtypes intentionally share one portrait.
local LEGACY_SUBTYPE_BY_FACTION_AND_PORTRAIT = {
    wh3_main_cth_rebel_lords_of_nan_yang = {
        [PORTRAIT_UI_ROOT .. "cth_lord_magistrate_campaign_01_0.png"] =
            "wh3_main_cth_lord_magistrate_yang",
    },
}

local function portrait_for_subtype(subtype)
    local key = tostring(subtype or "")
    if key == "" then return nil end
    local direct = PORTRAIT_BY_SUBTYPE[key]
    if direct then return direct end
    -- Rebel/variant subtype keys keep the same vanilla portrait family.  Use
    -- family matching only after the exact table lookup so custom subtypes do
    -- not accidentally receive a misleading image.
    if key:find("cth_lord_magistrate", 1, true) then
        return PORTRAIT_UI_ROOT .. "cth_lord_magistrate_campaign_01_0.png"
    end
    if key:find("cth_dragon_blooded_shugengan", 1, true) then
        return PORTRAIT_UI_ROOT .. "cth_shugengan_lord_campaign_01_0.png"
    end
    if key:find("cth_celestial_general", 1, true) then
        return PORTRAIT_UI_ROOT .. "cth_celestial_general_campaign_01_0.png"
    end
    return nil
end

local function portrait_for_identity(subtype, character_cqi, faction_key)
    return portrait_for_character_cqi(character_cqi)
        or portrait_for_subtype(subtype)
        or PORTRAIT_BY_FACTION[tostring(faction_key or "")]
end

local function recover_prisoner_subtype(record)
    if type(record) ~= "table" then return "" end
    local subtype = tostring(record.subtype or "")
    local character = current_character(record.family_member_cqi)
    local family_member = current_family_member(record.family_member_cqi)
    local details = call_or(family_member, "character_details", nil)
    local recovered_character_type_key = character_type_key(character)
    if recovered_character_type_key == "" then
        recovered_character_type_key = tostring(
            call_or(details, "character_type_key", "") or ""
        )
    end

    -- Prefer the surviving campaign identity whenever the engine retained it.
    -- This preserves the exact subtype for every normal/new prisoner and only
    -- reaches the narrow legacy migration when the defeated wrapper is gone.
    if subtype == "" then
        subtype = tostring(call_or(character, "character_subtype_key", "") or "")
    end
    if subtype == "" then
        subtype = tostring(call_or(details, "character_subtype_key", "") or "")
    end

    if subtype == "" then
        local faction_map = LEGACY_SUBTYPE_BY_FACTION_AND_PORTRAIT[
            tostring(record.source_faction or "")
        ]
        if faction_map then
            local portrait = tostring(record.portrait_path or ""):gsub("\\", "/")
            subtype = tostring(faction_map[portrait] or "")
        end
    end

    if subtype ~= "" then
        local subtype_was_missing = tostring(record.subtype or "") == ""
        record.subtype = subtype
        -- Old records predate explicit lord/hero fields. Recover the real agent
        -- type from the persistent family member instead of turning every
        -- embedded hero into a general during load/recruitment.
        if tostring(record.character_type_key or "") == ""
            and recovered_character_type_key ~= ""
        then
            record.character_type_key = recovered_character_type_key
        end
        if tostring(record.role or "") == "" then
            if recovered_character_type_key == "general"
                or record.is_faction_leader == true
            then
                record.role = "lord"
            elseif recovered_character_type_key ~= "" then
                record.role = "hero"
            end
        end
        if subtype_was_missing then
            log("recovered prisoner subtype " .. subtype
                .. "; family_member_cqi=" .. tostring(record.family_member_cqi))
        end
    end
    return subtype
end

local function character_portrait(character)
    if not safe_interface(character) then
        return nil
    end
    local subtype = call_or(character, "character_subtype_key", "")
    local faction = call_or(character, "faction", nil)
    return portrait_for_identity(subtype, call_or(character, "command_queue_index", 0),
        call_or(faction, "name", ""))
end

local function faction_display_name(faction_key)
    local key = tostring(faction_key or "")
    if key == "" then return localised("wyccc_prison_runtime_unknown_faction") end
    local localisation_key = "factions_screen_name_" .. key
    local localized = ""
    pcall(function() localized = common.get_localised_string(localisation_key) or "" end)
    -- Rebel factions have a second vanilla key in some campaigns.  Prefer the
    -- normal faction name, then use the rebel-specific key when the normal one
    -- is absent; never replace the raw key in the saved prisoner record.
    if localized == "" or localized == localisation_key then
        local rebel_key = "factions_screen_name_when_rebels_" .. key
        pcall(function() localized = common.get_localised_string(rebel_key) or "" end)
        if localized == rebel_key then localized = "" end
    end
    return localized ~= "" and localized or key
end

local function prisoner_display_name(record)
    if record and record.is_unit == true then
        local unit_key = tostring(record.unit_key or "")
        if unit_key == "" then
            return localised("wyccc_prison_runtime_unknown_character")
        end
        local name = ""
        pcall(function()
            name = common.get_localised_string(
                "land_units_onscreen_name_" .. unit_key
            ) or ""
        end)
        if name == "" or name == ("land_units_onscreen_name_" .. unit_key) then
            name = unit_key
        end
        return name
    end
    local character = current_character(record.family_member_cqi)
    if safe_interface(character) then
        return character_name(character)
    end
    local forename = tostring(record.forename or "")
    local surname = tostring(record.surname or "")
    local name = ""
    if forename ~= "" then
        pcall(function() forename = common.get_localised_string(forename) end)
        name = forename
    end
    if surname ~= "" then
        pcall(function() surname = common.get_localised_string(surname) end)
        name = name == "" and surname or (name .. " " .. surname)
    end
    if name:gsub("%s", "") == "" then
        name = tostring(record.subtype or localised("wyccc_prison_runtime_unknown_character"))
    end
    return name
end

local function prisoner_count(state)
    return #state.prisoners
end

local function prisoner_capacity(state)
    return BASE_CAPACITY + (state.facilities.capacity or 0)
end

local function prisoner_for_index(state, index)
    return state.prisoners[index]
end

local function remove_value(list, value)
    for i = #list, 1, -1 do
        if list[i] == value then
            table.remove(list, i)
            return true
        end
    end
    return false
end

local function find_prisoner(state, family_member_cqi)
    for _, prisoner in ipairs(state.prisoners) do
        if prisoner.family_member_cqi == family_member_cqi then
            return prisoner
        end
    end
    return nil
end

-- Character prisoners are identified by their stable family member; unit
-- prisoners have fm=0 and must match on their unique record_id instead.
local function prisoner_record_key(record)
    if type(record) ~= "table" then return nil end
    if record.is_unit == true then
        return "unit:" .. tostring(record.record_id or "")
    end
    return tonumber(record.family_member_cqi) or 0
end

local function remove_prisoner_record(state, record)
    local key = prisoner_record_key(record)
    if key == nil then return nil end
    for i = #state.prisoners, 1, -1 do
        if prisoner_record_key(state.prisoners[i]) == key then
            return table.remove(state.prisoners, i)
        end
    end
    return nil
end

local function set_immortality(character, value)
    if not safe_interface(character) then return false end
    local ok, result = pcall(function()
        return cm:set_character_immortality(cm:char_lookup_str(character), value)
    end)
    return ok and result ~= false
end

local function wound_for_detention(character)
    if not safe_interface(character) then return false end
    -- is_wounded() says nothing about the remaining recovery time. A captive
    -- wounded by the battle may be only one turn away from reappointment.
    local character_cqi = call_or(character, "command_queue_index", 0)
    local family_member = call_or(character, "family_member", nil)
    local family_member_cqi = call_or(family_member, "command_queue_index", 0)
    local was_wounded = call_or(character, "is_wounded", false)
    -- Cache the lookup before any native mutation. Follow subjugation:wound_lord
    -- in wh3_campaign_subjugation.lua: an existing wound must end before a new
    -- convalescence period is applied. Neither command needs the old wrapper.
    local lookup = cm:char_lookup_str(character_cqi)
    local ok, result = pcall(function()
        if was_wounded then
            cm:stop_character_convalescing(character_cqi)
        end
        return cm:wound_character(lookup, CONVALESCENCE_TURNS)
    end)
    local accepted = ok and result ~= false
    log("detention wound " .. (accepted and "requested" or "request failed")
        .. "; family_member_cqi=" .. tostring(family_member_cqi)
        .. ", character_cqi=" .. tostring(character_cqi)
        .. ", was_wounded=" .. tostring(was_wounded)
        .. ", turns=" .. tostring(CONVALESCENCE_TURNS))
    if not accepted then
        log("detention wound error: " .. tostring(result))
    end
    return accepted
end

local function apply_held_effects(faction, state)
    for effect in pairs(HELD_EFFECT_LIST) do
        pcall(function() cm:remove_effect_bundle(effect, faction:name()) end)
    end
    for _, prisoner in ipairs(state.prisoners) do
        local effect = HELD_EFFECTS[prisoner.source_culture]
        if effect then
            pcall(function() cm:apply_effect_bundle(effect, faction:name(), 0) end)
        end
    end
end

local function update_cage_ability(faction, state)
    local bundle = CAGE_BUNDLE
    if prisoner_count(state) < prisoner_capacity(state) then
        pcall(function() cm:apply_effect_bundle(bundle, faction:name(), 0) end)
    else
        pcall(function() cm:remove_effect_bundle(bundle, faction:name()) end)
    end
end

local function enforce_prisoners(faction, state)
    for _, prisoner in ipairs(state.prisoners) do
        local character = current_character(prisoner.family_member_cqi)
        if safe_interface(character) then
            prisoner.character_cqi = character:command_queue_index()
            set_immortality(character, true)
            -- Also migrate existing saves whose captives still have the
            -- ordinary battle-wound timer. This runs on load/prison changes,
            -- never inside the faction turn-boundary callback.
            wound_for_detention(character)
        end
    end
    apply_held_effects(faction, state)
    update_cage_ability(faction, state)
end

local function trigger_incident(faction, incident_key, character)
    if not safe_interface(faction) then return false end
    local prisoner_cqi = 0
    local prisoner_faction_cqi = 0
    if safe_interface(character) then
        prisoner_cqi = character:command_queue_index()
        pcall(function() prisoner_faction_cqi = character:faction():command_queue_index() end)
    end
    local ok, result = pcall(function()
        if character == nil then
            -- Capture notices use saved prison data and do not require a live
            -- character target. The wound command may have invalidated it.
            return cm:trigger_incident(faction:name(), incident_key, true, true)
        end
        return cm:trigger_incident_with_targets(
            faction:command_queue_index(), incident_key, 0, prisoner_faction_cqi,
            prisoner_cqi, 0, 0, 0
        )
    end)
    if ok and result ~= false then return true end

    -- Targeted incidents are preferable because they can resolve the prisoner
    -- portrait/name.  If a wounded or destroyed character wrapper is rejected
    -- by the engine, still show the DB incident instead of swallowing the
    -- player's one action for the turn without any feedback.
    local fallback_ok, fallback_result = pcall(function()
        return cm:trigger_incident(faction:name(), incident_key, true, true)
    end)
    if not fallback_ok or fallback_result == false then
        log("incident failed: " .. tostring(incident_key)
            .. "; targeted_error=" .. tostring(ok and result or result)
            .. "; fallback_error=" .. tostring(fallback_result))
        return false
    end
    return true
end

local function faction_is_alive(faction)
    if not safe_interface(faction) then return false end
    local dead = false
    local ok = pcall(function() dead = faction:is_dead() end)
    return ok and dead ~= true
end

function cross_culture_annex.exact_prisoner_character(record)
    if type(record) ~= "table" then return nil end
    local expected_fm_cqi = tonumber(record.family_member_cqi) or 0
    if expected_fm_cqi <= 0 then return nil end

    local character = current_character(expected_fm_cqi)
    if not safe_interface(character) then
        local stored_character_cqi = tonumber(record.character_cqi) or 0
        if stored_character_cqi > 0 then
            pcall(function() character = cm:get_character_by_cqi(stored_character_cqi) end)
        end
    end
    if not safe_interface(character) then return nil end

    local family_member = call_or(character, "family_member", nil)
    local actual_fm_cqi = tonumber(call_or(family_member, "command_queue_index", 0)) or 0
    if actual_fm_cqi ~= expected_fm_cqi then
        log("released prisoner identity mismatch; expected fm_cqi="
            .. tostring(expected_fm_cqi) .. ", actual=" .. tostring(actual_fm_cqi))
        return nil
    end
    return character
end

function cross_culture_annex.released_lord_has_exact_force(record, character)
    if not safe_interface(character)
        or call_or(character, "has_military_force", false) ~= true
    then
        return false
    end
    local force = call_or(character, "military_force", nil)
    if not safe_interface(force) or call_or(force, "has_general", false) ~= true then
        return false
    end
    local general = call_or(force, "general_character", nil)
    local general_family_member = call_or(general, "family_member", nil)
    local general_fm_cqi = tonumber(call_or(
        general_family_member, "command_queue_index", 0
    )) or 0
    return general_fm_cqi > 0
        and general_fm_cqi == (tonumber(record.family_member_cqi) or 0)
end

function cross_culture_annex.restore_released_prisoner(record)
    if type(record) ~= "table" then return false end
    local family_member_cqi = tonumber(record.family_member_cqi) or 0
    local stored_character_cqi = tonumber(record.character_cqi) or 0
    local source_faction_key = tostring(record.source_faction or "")
    if family_member_cqi <= 0 or source_faction_key == "" then
        log("released prisoner restore rejected: incomplete original identity")
        return false
    end

    local pending_key = source_faction_key .. ":" .. tostring(family_member_cqi)
    if cross_culture_annex.release_restore_pending[pending_key] then return true end
    local pending_token = {}
    cross_culture_annex.release_restore_pending[pending_key] = pending_token

    local function finish(success, reason, character)
        if cross_culture_annex.release_restore_pending[pending_key] ~= pending_token then return false end
        cross_culture_annex.release_restore_pending[pending_key] = nil
        if safe_interface(character) then
            record.character_cqi = tonumber(call_or(
                character, "command_queue_index", record.character_cqi
            )) or record.character_cqi
            set_immortality(character, record.was_immortal == true)
        end
        log("released prisoner restore " .. (success and "completed" or "failed")
            .. "; fm_cqi=" .. tostring(family_member_cqi)
            .. "; reason=" .. tostring(reason or ""))
        return success
    end

    local function verify_exact_lord_force(character, callback_cqi)
        local exact_character = cross_culture_annex.exact_prisoner_character(record)
        if not safe_interface(exact_character)
            or not cross_culture_annex.released_lord_has_exact_force(record, exact_character)
        then
            return false
        end
        local exact_owner = call_or(exact_character, "faction", nil)
        if not safe_interface(exact_owner)
            or call_or(exact_owner, "name", "") ~= source_faction_key
        then
            return false
        end
        local exact_cqi = tonumber(call_or(exact_character, "command_queue_index", 0)) or 0
        if tonumber(callback_cqi) and tonumber(callback_cqi) ~= exact_cqi then
            log("released lord force callback returned another character; callback_cqi="
                .. tostring(callback_cqi) .. ", exact_cqi=" .. tostring(exact_cqi)
                .. "; accepting only the family-member-verified force")
        end
        pcall(function() cm:remove_all_units_from_general(exact_character) end)
        return finish(true, "original lord restored at source capital", exact_character)
    end

    local attempt_restore
    attempt_restore = function(attempt)
        if cross_culture_annex.release_restore_pending[pending_key] ~= pending_token then return end
        attempt = tonumber(attempt) or 1

        local character = cross_culture_annex.exact_prisoner_character(record)
        if not safe_interface(character) then
            if stored_character_cqi > 0 then
                pcall(function() cm:stop_character_convalescing(stored_character_cqi) end)
            end
            if attempt < cross_culture_annex.release_restore_max_attempts then
                cm:callback(function() attempt_restore(attempt + 1) end, 0.1)
            else
                finish(false, "original character interface did not return", nil)
            end
            return
        end

        local owner = call_or(character, "faction", nil)
        if not safe_interface(owner) or call_or(owner, "name", "") ~= source_faction_key then
            finish(false, "original character is not owned by the source faction", character)
            return
        end

        local character_cqi = tonumber(call_or(
            character, "command_queue_index", stored_character_cqi
        )) or stored_character_cqi
        record.character_cqi = character_cqi
        if call_or(character, "is_wounded", false) == true then
            pcall(function() cm:stop_character_convalescing(character_cqi) end)
            if attempt < cross_culture_annex.release_restore_max_attempts then
                cm:callback(function() attempt_restore(attempt + 1) end, 0.1)
            else
                finish(false, "original character remained wounded", character)
            end
            return
        end

        if prisoner_role(record, character) ~= "lord" then
            finish(true, "original hero convalescence cleared", character)
            return
        end
        if cross_culture_annex.released_lord_has_exact_force(record, character) then
            finish(true, "original lord already commands a force", character)
            return
        end

        local source_faction = nil
        pcall(function() source_faction = cm:get_faction(source_faction_key) end)
        if not faction_is_alive(source_faction) then
            finish(false, "source faction is unavailable", character)
            return
        end
        local home_region = call_or(source_faction, "home_region", nil)
        local home_region_key = tostring(call_or(home_region, "name", "") or "")
        if home_region_key == "" then
            finish(false, "source faction has no capital region", character)
            return
        end

        local x, y = nil, nil
        pcall(function()
            x, y = cm:find_valid_spawn_location_for_character_from_settlement(
                source_faction_key, home_region_key, false, true, 5
            )
        end)
        if not tonumber(x) or not tonumber(y) or x < 0 or y < 0 then
            finish(false, "no valid source-capital spawn location", character)
            return
        end

        -- The campaign-manager wrapper requires a non-empty unit list.  Use the
        -- existing bootstrap unit only to make the force, then remove it after
        -- family-member verification so the released lord returns alone.
        cm:create_force_with_existing_general(
            cm:char_lookup_str(character), source_faction_key, RECRUIT_UNIT,
            home_region_key, x, y,
            function(created_character_cqi)
                verify_exact_lord_force(character, created_character_cqi)
            end
        )
        cm:callback(function()
            if cross_culture_annex.release_restore_pending[pending_key] ~= pending_token then return end
            if not verify_exact_lord_force(character, nil) then
                finish(false, "existing-general force creation timed out", character)
            end
        end, 2.0)
    end

    attempt_restore(1)
    return true
end

local function faction_command_queue_index(faction)
    return tonumber(call_or(faction, "command_queue_index", 0)) or 0
end

local function break_vassal_relation(master_key, vassal_key)
    -- Match the vanilla diplomacy call: the current master is the first
    -- faction and the vassal is the second faction.  This is needed only on
    -- the annex branch because surrender first establishes the vassal state.
    pcall(function()
        cm:force_diplomacy(
            "faction:" .. tostring(master_key),
            "faction:" .. tostring(vassal_key),
            "break vassal", false, false, true
        )
    end)
end

local function make_leader_faction_vassal(warden_faction, source_faction_key, on_complete)
    local callback_fired = false
    local function finish(success, reason)
        if callback_fired then return end
        callback_fired = true
        if type(on_complete) == "function" then
            pcall(on_complete, success == true, tostring(reason or ""))
        end
    end
    if not safe_interface(warden_faction) then
        finish(false, "warden faction is unavailable")
        return false
    end
    local warden_key = warden_faction:name()
    if source_faction_key == nil or source_faction_key == "" or source_faction_key == warden_key then
        finish(false, "source faction is invalid")
        return false
    end
    local source_faction = nil
    pcall(function() source_faction = cm:get_faction(source_faction_key) end)
    if not faction_is_alive(source_faction) then
        log("leader disposition vassal skipped: source faction is unavailable " .. tostring(source_faction_key))
        finish(false, "source faction is unavailable")
        return false
    end
    local ok, err = pcall(function()
        -- force_make_vassal(master, vassal)
        cm:force_make_vassal(warden_key, source_faction_key)
    end)
    if not ok then
        log("leader disposition vassal failed for " .. tostring(source_faction_key) .. ": " .. tostring(err))
        finish(false, err)
        return false
    end
    -- Vassalage is command-queued.  Verify the requested relationship after
    -- the dilemma closes, independently of the separate leader-recruitment
    -- path, and retry once if the first command has not settled yet.
    local function verify_vassalage(attempt)
        local current_warden = nil
        local current_source = nil
        pcall(function() current_warden = cm:get_faction(warden_key) end)
        pcall(function() current_source = cm:get_faction(source_faction_key) end)
        local confirmed = false
        if faction_is_alive(current_warden) and faction_is_alive(current_source) then
            pcall(function() confirmed = current_source:is_vassal_of(current_warden) == true end)
        end
        if confirmed then
            log("leader disposition vassal confirmed: " .. tostring(source_faction_key)
                .. " -> " .. tostring(warden_key))
            finish(true, "")
            return
        end
        if attempt == 3 then
            pcall(function() cm:force_make_vassal(warden_key, source_faction_key) end)
        end
        if attempt < 6 then
            cm:callback(function() verify_vassalage(attempt + 1) end, 0.2)
        else
            log("leader disposition vassal not confirmed after command: "
                .. tostring(source_faction_key) .. " -> " .. tostring(warden_key))
            finish(false, "vassal relationship was not confirmed")
        end
    end
    cm:callback(function() verify_vassalage(1) end, 0.2)
    return true
end

cross_culture_annex.art_set_by_subtype = {
    wh2_dlc10_hef_alarielle = "wh2_dlc10_art_set_hef_alarielle",
    wh_dlc07_brt_fay_enchantress = "wh_dlc07_art_set_brt_fay_enchantress"
}

function cross_culture_annex.character_snapshot(character)
    if not safe_interface(character) then return nil end
    local family_member = call_or(character, "family_member", nil)
    local family_member_cqi = tonumber(call_or(family_member, "command_queue_index", 0)) or 0
    local character_cqi = tonumber(call_or(character, "command_queue_index", 0)) or 0
    if family_member_cqi <= 0 or character_cqi <= 0 then return nil end

    local details = call_or(character, "character_details", nil)
    local owner = call_or(character, "faction", nil)
    local type_key = character_type_key(character)
    local subtype = tostring(call_or(character, "character_subtype_key", "") or "")
    return {
        family_member_cqi = family_member_cqi,
        character_cqi = character_cqi,
        subtype = subtype,
        art_set = tostring(cross_culture_annex.art_set_by_subtype[subtype] or ""),
        role = type_key == "general" and "lord" or "hero",
        rank = math.max(1, tonumber(call_or(character, "rank", call_or(details, "rank", 1))) or 1),
        forename = tostring(call_or(character, "get_forename", call_or(details, "get_forename", "")) or ""),
        surname = tostring(call_or(character, "get_surname", call_or(details, "get_surname", "")) or ""),
        age = math.max(18, tonumber(call_or(details, "age", 30)) or 30),
        is_male = call_or(details, "character_subtype_has_female_name", false) ~= true,
        source_culture = tostring(call_or(owner, "culture", "") or ""),
        is_unique = call_or(details, "is_unique", false) == true,
        is_wounded = call_or(character, "is_wounded", false) == true
    }
end

function cross_culture_annex.append_character_snapshot(snapshots, seen, character)
    local snapshot = cross_culture_annex.character_snapshot(character)
    if not snapshot or seen[snapshot.family_member_cqi] then return nil end
    seen[snapshot.family_member_cqi] = true
    snapshots[#snapshots + 1] = snapshot
    return snapshot
end

function cross_culture_annex.source_character_snapshots(source_faction)
    local snapshots = {}
    local seen = {}
    local characters = call_or(source_faction, "character_list", nil)
    local count = tonumber(call_or(characters, "num_items", 0)) or 0
    for index = 0, count - 1 do
        cross_culture_annex.append_character_snapshot(
            snapshots, seen, call_or(characters, "item_at", nil, index)
        )
    end
    return snapshots, seen
end

function cross_culture_annex.source_region_keys(source_faction)
    local regions = {}
    local region_list = call_or(source_faction, "region_list", nil)
    local count = tonumber(call_or(region_list, "num_items", 0)) or 0
    for index = 0, count - 1 do
        local region = call_or(region_list, "item_at", nil, index)
        local region_key = tostring(call_or(region, "name", "") or "")
        if region_key ~= "" then regions[#regions + 1] = region_key end
    end
    return regions
end

function cross_culture_annex.remove_character(snapshot)
    if type(snapshot) ~= "table" or (tonumber(snapshot.family_member_cqi) or 0) <= 0 then
        return false
    end

    local character = current_character(snapshot.family_member_cqi)
    if snapshot.is_unique then
        -- A unique character must retain the original family member, level and
        -- skill allocation.  Make that identity immortal before destroying its
        -- current force; it will be restored after the confederation transaction.
        set_immortality(character, true)
        if snapshot.is_wounded then return true end
    else
        -- This is the vanilla scripted-occupation pattern for permanently
        -- excluding ordinary lords and heroes from a subsequent confederation.
        pcall(function()
            cm:suppress_immortality(snapshot.family_member_cqi, true)
        end)
    end

    local ok, err = pcall(function()
        cm:kill_character_and_commanded_unit(
            "family_member_cqi:" .. tostring(snapshot.family_member_cqi), true
        )
    end)
    if not ok then
        log("cross-culture annex character removal failed: fm_cqi="
            .. tostring(snapshot.family_member_cqi) .. ", error=" .. tostring(err))
    end
    return ok
end

function cross_culture_annex.capital_spawn_location(warden_faction)
    if not safe_interface(warden_faction) then return nil, nil end
    local home_region = call_or(warden_faction, "home_region", nil)
    local region_key = tostring(call_or(home_region, "name", "") or "")
    if region_key == "" then return nil, nil end

    local x, y = nil, nil
    pcall(function()
        x, y = cm:find_valid_spawn_location_for_character_from_settlement(
            warden_faction:name(), region_key, false, true, 5
        )
    end)
    if not tonumber(x) or not tonumber(y) or x < 0 or y < 0 then return nil, nil end
    return x, y
end

function cross_culture_annex.find_owned_subtype(warden_faction, subtype)
    if not safe_interface(warden_faction) or tostring(subtype or "") == "" then return nil end
    local characters = call_or(warden_faction, "character_list", nil)
    local count = tonumber(call_or(characters, "num_items", 0)) or 0
    for index = 0, count - 1 do
        local character = call_or(characters, "item_at", nil, index)
        if safe_interface(character)
            and call_or(character, "character_subtype_key", "") == subtype
        then
            return character
        end
    end
    return nil
end

function cross_culture_annex.spawn_legendary_lord_to_pool(warden_faction, snapshot)
    if not safe_interface(warden_faction) or type(snapshot) ~= "table"
        or snapshot.role ~= "lord"
    then
        return false
    end

    local subtype = tostring(snapshot.subtype or "")
    if subtype == "" then
        log("cross-culture annex pool fallback rejected: legendary lord subtype unavailable")
        return false
    end

    local fallback_key = warden_faction:name() .. ":" .. subtype
    if annex_pool_fallback_spawned[fallback_key] then return true end

    -- Do not duplicate a unique lord if a delayed ownership transaction made
    -- it visible immediately before the timeout callback.
    local existing = cross_culture_annex.find_owned_subtype(warden_faction, subtype)
    if safe_interface(existing) then
        local existing_cqi = tonumber(call_or(existing, "command_queue_index", 0)) or 0
        if existing_cqi > 0 and call_or(existing, "is_wounded", false) == true then
            pcall(function() cm:stop_character_convalescing(existing_cqi) end)
        end
        annex_pool_fallback_spawned[fallback_key] = true
        log("cross-culture annex pool fallback found transferred legendary lord: " .. subtype)
        return true
    end

    local spawned_details = nil
    local art_set = tostring(snapshot.art_set or "")
    if art_set == "" then
        art_set = tostring(cross_culture_annex.art_set_by_subtype[subtype] or "")
    end
    local ok, err = pcall(function()
        spawned_details = cm:spawn_character_to_pool(
            warden_faction:name(),
            tostring(snapshot.forename or ""),
            tostring(snapshot.surname or ""),
            "", "",
            math.max(18, tonumber(snapshot.age) or 30),
            snapshot.is_male ~= false,
            "general", subtype, true, art_set
        )
    end)
    if not ok or not safe_interface(spawned_details) then
        log("cross-culture annex legendary lord pool fallback failed: subtype="
            .. subtype .. ", error=" .. tostring(err))
        return false
    end

    local spawned_owner = call_or(spawned_details, "faction", nil)
    local spawned_family_member = call_or(spawned_details, "family_member", nil)
    local spawned_family_member_cqi = tonumber(
        call_or(spawned_family_member, "command_queue_index", 0)
    ) or 0
    if call_or(spawned_details, "character_subtype_key", "") ~= subtype
        or call_or(spawned_details, "character_type_key", "") ~= "general"
        or not safe_interface(spawned_owner)
        or spawned_owner:name() ~= warden_faction:name()
        or spawned_family_member_cqi <= 0
    then
        log("cross-culture annex pool fallback rejected: returned identity differs from " .. subtype)
        return false
    end
    annex_pool_fallback_spawned[fallback_key] = true

    -- Pool characters expose CHARACTER_DETAILS rather than an active army
    -- character.  Apply the shared non-native lord compensation trait through
    -- that interface, and restore the captured rank when the family-member XP
    -- bridge is available in the current campaign runtime.
    local player_culture = faction_culture_key(warden_faction)
    local source_culture = tostring(snapshot.source_culture or "")
    if source_culture ~= "" and player_culture ~= ""
        and source_culture ~= player_culture
    then
        pcall(function()
            cm:force_add_trait_to_character_details(spawned_details, NON_NATIVE_LORD_TRAIT)
        end)
    end
    local rank = math.max(1, tonumber(snapshot.rank) or 1)
    -- Keep the rebuilt family member pending even when no explicit art set is
    -- known: every prison-created pool lord still needs the shared name API
    -- when CharacterRecruited exposes a live CHARACTER interface.
    if spawned_family_member_cqi > 0 then
        local state = get_state(warden_faction:name())
        state.pending_pool_art_sets[tostring(spawned_family_member_cqi)] = {
            subtype = subtype,
            art_set = art_set
        }
    end
    if rank > 1 and safe_interface(spawned_family_member) then
        local xp_by_level = cm.character_xp_per_level
        local target_xp = type(xp_by_level) == "table" and tonumber(xp_by_level[rank]) or nil
        if target_xp and target_xp > 0 then
            pcall(function()
                cm:add_agent_experience_through_family_member(spawned_family_member, target_xp)
            end)
        end
    end

    log("cross-culture annex spawned legendary lord in recruitment pool: subtype="
        .. subtype .. ", rank=" .. tostring(rank)
        .. ", art_set=" .. (art_set ~= "" and art_set or "<db-default>"))
    return true
end

function cross_culture_annex.pending_pool_art_set(character)
    if not safe_interface(character) then return nil, nil, nil end
    local faction = call_or(character, "faction", nil)
    if not safe_interface(faction) or not is_warden_faction(faction) then
        return nil, nil, nil
    end
    local family_member = call_or(character, "family_member", nil)
    local family_member_cqi = tonumber(
        call_or(family_member, "command_queue_index", 0)
    ) or 0
    if family_member_cqi <= 0 then return nil, nil, nil end

    local state = get_state(faction:name())
    local key = tostring(family_member_cqi)
    local entry = state.pending_pool_art_sets[key]
    if type(entry) ~= "table" then return nil, nil, nil end
    if tostring(entry.subtype or "") ~= ""
        and tostring(entry.subtype) ~= tostring(call_or(character, "character_subtype_key", ""))
    then
        return nil, nil, nil
    end
    -- Older saved pool entries still carry an empty appearance override.
    if tostring(entry.art_set or "") == "" then
        entry.art_set = tostring(cross_culture_annex.art_set_by_subtype[entry.subtype] or "")
    end
    return state, key, entry
end

function cross_culture_annex.apply_recruited_pool_art_set(character_cqi, subtype, art_set, phase)
    local character = nil
    pcall(function() character = cm:get_character_by_cqi(character_cqi) end)
    if not safe_interface(character)
        or call_or(character, "character_subtype_key", "") ~= subtype
    then
        log("recruited pool art set refresh skipped: character unavailable or subtype changed; subtype="
            .. tostring(subtype) .. ", phase=" .. tostring(phase))
        return false
    end
    local ok, err = pcall(function()
        cm:add_character_model_override(character, art_set)
    end)
    if not ok then
        log("recruited pool art set refresh failed: subtype=" .. tostring(subtype)
            .. ", art_set=" .. tostring(art_set)
            .. ", phase=" .. tostring(phase)
            .. ", error=" .. tostring(err))
        return false
    end
    log("recruited pool art set refreshed: subtype=" .. tostring(subtype)
        .. ", art_set=" .. tostring(art_set)
        .. ", phase=" .. tostring(phase))
    return true
end

function cross_culture_annex.refresh_recruited_pool_art_set(context)
    local character = nil
    pcall(function() character = context:character() end)
    local state, pending_key, entry = cross_culture_annex.pending_pool_art_set(character)
    if not state or not pending_key or not entry then return end

    local character_cqi = tonumber(call_or(character, "command_queue_index", 0)) or 0
    local subtype = tostring(entry.subtype or call_or(character, "character_subtype_key", ""))
    local art_set = tostring(entry.art_set or "")
    if character_cqi <= 0 then return end

    if wyccc_base and type(wyccc_base.rename_character) == "function" then
        wyccc_base.rename_character(character, subtype)
    else
        log("shared character name API unavailable for recruited pool lord: subtype="
            .. subtype)
    end

    -- A name repair is still valid for a subtype without a verified art set.
    -- Clear the persisted hand-off after the shared API's final retry.
    if art_set == "" then
        cm:callback(function()
            state.pending_pool_art_sets[pending_key] = nil
        end, 1)
        return
    end

    -- Match the shared name service's retry phases, then repeat after
    -- the recruitment transaction and delayed campaign-art initialisation have
    -- each had a chance to overwrite the active model.
    cross_culture_annex.apply_recruited_pool_art_set(
        character_cqi, subtype, art_set, "immediate"
    )
    cm:callback(function()
        cross_culture_annex.apply_recruited_pool_art_set(
            character_cqi, subtype, art_set, "settled"
        )
    end, 0.2)
    cm:callback(function()
        cross_culture_annex.apply_recruited_pool_art_set(
            character_cqi, subtype, art_set, "late"
        )
        state.pending_pool_art_sets[pending_key] = nil
    end, 1)
end

function cross_culture_annex.restore_legendary(warden_faction, snapshot, attempt)
    attempt = tonumber(attempt) or 1
    if not safe_interface(warden_faction) or type(snapshot) ~= "table" then return end

    local character = current_character(snapshot.family_member_cqi)
    local owner = call_or(character, "faction", nil)
    if not safe_interface(character) or not safe_interface(owner)
        or owner:name() ~= warden_faction:name()
    then
        if attempt < LEGENDARY_RESTORE_MAX_ATTEMPTS then
            cm:callback(function()
                cross_culture_annex.restore_legendary(warden_faction, snapshot, attempt + 1)
            end, 0.1)
        else
            if snapshot.role == "lord"
                and cross_culture_annex.spawn_legendary_lord_to_pool(warden_faction, snapshot)
            then
                log("cross-culture annex original legendary lord unavailable; pool fallback used: subtype="
                    .. tostring(snapshot.subtype) .. ", fm_cqi="
                    .. tostring(snapshot.family_member_cqi))
            else
                log("cross-culture annex legendary restore timed out: subtype="
                    .. tostring(snapshot.subtype) .. ", fm_cqi="
                    .. tostring(snapshot.family_member_cqi))
            end
        end
        return
    end

    local character_cqi = tonumber(call_or(character, "command_queue_index", 0)) or 0
    if call_or(character, "is_wounded", false) == true then
        pcall(function() cm:stop_character_convalescing(character_cqi) end)
        if attempt < LEGENDARY_RESTORE_MAX_ATTEMPTS then
            cm:callback(function()
                cross_culture_annex.restore_legendary(warden_faction, snapshot, attempt + 1)
            end, 0.1)
        else
            log("cross-culture annex legendary remained wounded after restore: subtype="
                .. tostring(snapshot.subtype))
        end
        return
    end

    if call_or(character, "has_military_force", false) == true then
        -- A delayed command queue may allow the confederation to finish before
        -- the old army is destroyed.  Remove that exact legendary character's
        -- force once more, keeping the same immortal family member for recovery.
        snapshot.is_wounded = false
        cross_culture_annex.remove_character(snapshot)
        if attempt < LEGENDARY_RESTORE_MAX_ATTEMPTS then
            cm:callback(function()
                cross_culture_annex.restore_legendary(warden_faction, snapshot, attempt + 1)
            end, 0.1)
        end
        return
    end

    if wyccc_base and type(wyccc_base.rename_character) == "function" then
        wyccc_base.rename_character(character, tostring(snapshot.subtype or ""))
    else
        log("shared character name API unavailable for restored legendary: subtype="
            .. tostring(snapshot.subtype))
    end

    if snapshot.role == "hero" then
        -- Heroes return to the map when convalescence ends.  Explicitly place
        -- the original character beside the player's capital so the result is
        -- deterministic even when the source faction's home region was annexed.
        local x, y = cross_culture_annex.capital_spawn_location(warden_faction)
        if x and y then
            local placed, result = pcall(function()
                return cm:teleport_to(cm:char_lookup_str(character), x, y)
            end)
            if not placed or result == false then
                log("cross-culture annex legendary hero capital placement failed: "
                    .. tostring(snapshot.subtype))
                return
            end
        else
            log("cross-culture annex legendary hero restored without a capital spawn point: "
                .. tostring(snapshot.subtype))
            return
        end
        log("cross-culture annex legendary hero restored at capital: "
            .. tostring(snapshot.subtype))
    else
        -- A recovered wounded general with no commanded force is exposed by
        -- the engine in the faction's lord recruitment pool.
        log("cross-culture annex legendary lord restored to recruitment pool: "
            .. tostring(snapshot.subtype))
    end
end

function cross_culture_annex.release_legendary_before_confederation(
    source_faction, snapshots, on_ready, attempt
)
    attempt = tonumber(attempt) or 1
    snapshots = type(snapshots) == "table" and snapshots or {}
    if not safe_interface(source_faction) or type(on_ready) ~= "function" then return false end

    local source_key = source_faction:name()
    local waiting = 0
    for _, snapshot in ipairs(snapshots) do
        local character = current_character(snapshot.family_member_cqi)
        local owner = call_or(character, "faction", nil)
        local character_cqi = tonumber(call_or(
            character, "command_queue_index", snapshot.character_cqi
        )) or 0

        if safe_interface(character) and safe_interface(owner)
            and owner:name() == source_key
        then
            set_immortality(character, true)
            if call_or(character, "is_wounded", false) == true then
                waiting = waiting + 1
                if character_cqi > 0 then
                    local released, release_error = pcall(function()
                        cm:stop_character_convalescing(character_cqi)
                    end)
                    if not released then
                        log("cross-culture annex pre-release failed: subtype="
                            .. tostring(snapshot.subtype) .. ", error="
                            .. tostring(release_error))
                    end
                end
            end
        elseif not safe_interface(character) or not safe_interface(owner) then
            -- The defeated wrapper can briefly disappear while the engine is
            -- rebuilding the wounded family member.  The stored character CQI
            -- remains the authoritative release handle during that boundary.
            waiting = waiting + 1
            if character_cqi > 0 then
                pcall(function() cm:stop_character_convalescing(character_cqi) end)
            end
        end
    end

    if waiting == 0 or attempt >= LEGENDARY_PRE_CONFEDERATION_MAX_ATTEMPTS then
        if waiting == 0 then
            log("cross-culture annex released original legendary characters before confederation: "
                .. tostring(#snapshots))
        else
            log("cross-culture annex pre-release timed out for " .. tostring(waiting)
                .. " legendary characters; retaining post-confederation fallback")
        end
        local completed, completion_error = pcall(on_ready, waiting == 0)
        if not completed then
            log("cross-culture annex continuation failed after pre-release: "
                .. tostring(completion_error))
            return false
        end
        return true
    end

    cm:callback(function()
        cross_culture_annex.release_legendary_before_confederation(
            source_faction, snapshots, on_ready, attempt + 1
        )
    end, 0.1)
    return true
end

function cross_culture_annex.finish_confederation(
    warden_faction, source_faction, regions, snapshots, unique_count, ordinary_count
)
    if not safe_interface(warden_faction) or not safe_interface(source_faction) then
        return false
    end
    local warden_key = warden_faction:name()
    local source_key = source_faction:name()
    local was_vassal = call_or(source_faction, "is_vassal", false) == true
    if was_vassal then break_vassal_relation(warden_key, source_key) end

    local ok, err = pcall(function()
        cm:force_confederation(warden_key, source_key)
    end)
    if not ok then
        log("cross-culture leader disposition annex failed for " .. source_key
            .. ": " .. tostring(err))
        return false
    end

    -- The native transaction normally transfers every settlement.  Retain the
    -- explicit region fallback for campaign variants that defer or partially
    -- reject a cross-culture confederation.
    if faction_is_alive(source_faction) then
        for _, region_key in ipairs(regions) do
            pcall(function() cm:transfer_region_to_faction(region_key, warden_key) end)
        end
    end

    cm:callback(function()
        -- Ordinary characters were already removed before the release wait.
        -- Re-run that removal after ownership changes in case a queued death
        -- landed late.  Legendary characters retain their original identity;
        -- active armies are removed here.  Cross-culture legendary lords use
        -- the proven pool-rebuild path immediately; waiting five seconds for
        -- the original family member to reappear only delayed the same result.
        for _, snapshot in ipairs(snapshots) do
            if snapshot.is_unique then
                if snapshot.role == "lord" then
                    if cross_culture_annex.spawn_legendary_lord_to_pool(
                        warden_faction, snapshot
                    ) then
                        log("cross-culture annex legendary lord completed through immediate pool path: subtype="
                            .. tostring(snapshot.subtype))
                    else
                        log("cross-culture annex immediate legendary lord pool path failed: subtype="
                            .. tostring(snapshot.subtype))
                    end
                else
                    cross_culture_annex.restore_legendary(warden_faction, snapshot, 1)
                end
            else
                local character = current_character(snapshot.family_member_cqi)
                local owner = call_or(character, "faction", nil)
                if safe_interface(character) and safe_interface(owner)
                    and owner:name() == warden_key
                then
                    cross_culture_annex.remove_character(snapshot)
                end
            end
        end
    end, 0.1)

    log("cross-culture annex completed after pre-release: source=" .. source_key
        .. ", regions=" .. tostring(#regions)
        .. ", legendary_characters=" .. tostring(unique_count)
        .. ", ordinary_characters_removed=" .. tostring(ordinary_count))
    return true
end

function cross_culture_annex.execute(warden_faction, source_faction, pending)
    local regions = cross_culture_annex.source_region_keys(source_faction)
    local snapshots, seen = cross_culture_annex.source_character_snapshots(source_faction)

    -- Legacy saves may reach this dilemma after the leader was recruited, while
    -- the new flow reaches it directly from the third capture.  In either case,
    -- include the exact legendary family member in the survivor set.
    local surrendered = current_character(pending.family_member_cqi)
    local surrendered_snapshot = cross_culture_annex.character_snapshot(surrendered)
    if not surrendered_snapshot and pending.is_unique == true then
        surrendered_snapshot = {
            family_member_cqi = tonumber(pending.family_member_cqi) or 0,
            character_cqi = tonumber(pending.character_cqi) or 0,
            subtype = tostring(pending.subtype or ""),
            role = tostring(pending.role or "lord"),
            rank = math.max(1, tonumber(pending.rank) or 1),
            forename = tostring(pending.forename or ""),
            surname = tostring(pending.surname or ""),
            age = math.max(18, tonumber(pending.age) or 30),
            is_male = pending.is_male ~= false,
            source_culture = tostring(pending.source_culture or ""),
            is_unique = true,
            is_wounded = true
        }
    end
    if surrendered_snapshot and surrendered_snapshot.is_unique
        and not seen[surrendered_snapshot.family_member_cqi]
    then
        seen[surrendered_snapshot.family_member_cqi] = true
        snapshots[#snapshots + 1] = surrendered_snapshot
    end

    local unique_snapshots = {}
    local ordinary_count = 0
    for _, snapshot in ipairs(snapshots) do
        if snapshot.is_unique then
            unique_snapshots[#unique_snapshots + 1] = snapshot
            -- Do not kill or re-wound a legendary character before ownership
            -- changes.  Release the exact original first so native
            -- confederation can transfer its family member, rank and skills.
            set_immortality(current_character(snapshot.family_member_cqi), true)
        else
            ordinary_count = ordinary_count + 1
            cross_culture_annex.remove_character(snapshot)
        end
    end

    return cross_culture_annex.release_legendary_before_confederation(
        source_faction,
        unique_snapshots,
        function()
            cross_culture_annex.finish_confederation(
                warden_faction, source_faction, regions, snapshots,
                #unique_snapshots, ordinary_count
            )
        end,
        1
    )
end

function cross_culture_annex.clear_prison_record(warden_faction, state, record, restore_character)
    if not safe_interface(warden_faction) or not state or not record then return false end
    remove_prisoner_record(state, record)
    local effect = HELD_EFFECTS[record.source_culture]
    if effect then
        pcall(function() cm:remove_effect_bundle(effect, warden_faction:name()) end)
    end
    if restore_character then
        cross_culture_annex.restore_released_prisoner(record)
    end
    enforce_prisoners(warden_faction, state)
    return true
end

function cross_culture_annex.destroy_faction(source_faction, captured_family_member_cqi)
    if not faction_is_alive(source_faction) then return false end
    local source_key = source_faction:name()
    local regions = cross_culture_annex.source_region_keys(source_faction)
    local family_member_cqi = tonumber(captured_family_member_cqi) or 0

    cm:disable_event_feed_events(true, "wh_event_category_conquest", "", "")
    cm:disable_event_feed_events(true, "wh_event_category_diplomacy", "", "")
    if family_member_cqi > 0 then
        pcall(function() cm:suppress_immortality(family_member_cqi, true) end)
        pcall(function()
            cm:kill_character_and_commanded_unit(
                "family_member_cqi:" .. tostring(family_member_cqi), true
            )
        end)
    end
    pcall(function() cm:kill_all_armies_for_faction(source_faction) end)
    for _, region_key in ipairs(regions) do
        pcall(function() cm:set_region_abandoned(region_key) end)
    end
    cm:callback(function()
        cm:disable_event_feed_events(false, "wh_event_category_conquest", "", "")
        cm:disable_event_feed_events(false, "wh_event_category_diplomacy", "", "")
    end, 0.2)
    log("leader disposition destroyed faction " .. source_key
        .. "; abandoned_regions=" .. tostring(#regions))
    return true
end

function cross_culture_annex.permanently_kill_original_leader(
    record, replacement_character
)
    if type(record) ~= "table" then return false end
    local original_family_member_cqi = tonumber(record.family_member_cqi) or 0
    if original_family_member_cqi <= 0 then
        log("vassal leader replacement could not kill original: family member CQI unavailable")
        return false
    end

    local replacement_family_member = call_or(replacement_character, "family_member", nil)
    local replacement_family_member_cqi = tonumber(call_or(
        replacement_family_member, "command_queue_index", 0
    )) or 0
    if replacement_family_member_cqi <= 0
        or replacement_family_member_cqi == original_family_member_cqi
    then
        log("vassal leader replacement refused original kill: replacement identity is not distinct")
        return false
    end

    local function kill_original(attempt)
        local original = current_character(original_family_member_cqi)
        if not safe_interface(original) then
            log("vassal leader original permanently killed: fm_cqi="
                .. tostring(original_family_member_cqi)
                .. ", replacement_fm_cqi=" .. tostring(replacement_family_member_cqi))
            return
        end
        if attempt > 6 then
            log("vassal leader original still exposed after permanent-kill retries: fm_cqi="
                .. tostring(original_family_member_cqi))
            return
        end

        -- Legendary lords are normally protected by their DB immortality.
        -- Disable the live flag and suppress the family member's immortality
        -- before issuing the permanent kill against the old identity only.
        set_immortality(original, false)
        pcall(function()
            cm:suppress_immortality(original_family_member_cqi, true)
        end)
        local ok, err = pcall(function()
            cm:kill_character_and_commanded_unit(
                "family_member_cqi:" .. tostring(original_family_member_cqi), true
            )
        end)
        if not ok then
            log("vassal leader original kill command failed: fm_cqi="
                .. tostring(original_family_member_cqi) .. ", error=" .. tostring(err))
        end

        cm:callback(function() kill_original(attempt + 1) end, 0.2)
    end

    kill_original(1)
    return true
end

local function annex_leader_faction(warden_faction, pending)
    if not safe_interface(warden_faction) or type(pending) ~= "table" then return false end
    local warden_key = warden_faction:name()
    local source_key = tostring(pending.source_faction or "")
    if source_key == "" or source_key == warden_key then return false end

    local source_faction = nil
    pcall(function() source_faction = cm:get_faction(source_key) end)
    if not faction_is_alive(source_faction) then
        log("leader disposition annex skipped: source faction is unavailable " .. source_key)
        return false
    end

    local warden_culture = faction_culture_key(warden_faction)
    local source_culture = faction_culture_key(source_faction)
    if warden_culture ~= "" and source_culture ~= ""
        and warden_culture ~= source_culture
    then
        return cross_culture_annex.execute(warden_faction, source_faction, pending)
    end

    -- The native confederation path is intentional here: it transfers the
    -- entire faction roster (including legendary lords/heroes), armies,
    -- regions and settlement ownership in one engine transaction.  Older saves
    -- may already have established the former default-vassal state, so dissolve
    -- that legacy relation before asking the engine to confederate it.
    local was_vassal = false
    pcall(function() was_vassal = source_faction:is_vassal() == true end)
    if was_vassal then
        break_vassal_relation(warden_key, source_key)
    end

    local ok, err = pcall(function()
        cm:force_confederation(warden_key, source_key)
    end)
    if not ok then
        log("leader disposition annex failed for " .. source_key .. ": " .. tostring(err))
        return false
    end

    -- force_confederation normally consumes the source faction immediately.
    -- If a campaign variant defers that transaction, make sure every owned
    -- region still reaches the player rather than silently losing territory.
    if faction_is_alive(source_faction) then
        local regions = {}
        local region_list = nil
        pcall(function() region_list = source_faction:region_list() end)
        if region_list and region_list.num_items then
            for i = 0, region_list:num_items() - 1 do
                local region = region_list:item_at(i)
                if safe_interface(region) then
                    regions[#regions + 1] = region:name()
                end
            end
        end
        for _, region_key in ipairs(regions) do
            pcall(function() cm:transfer_region_to_faction(region_key, warden_key) end)
        end
        log("leader disposition annex fallback transferred " .. tostring(#regions)
            .. " regions from " .. source_key)
    end
    -- In the new third-capture flow the leader is still convalescing when the
    -- same-culture confederation begins.  End that detention after ownership
    -- changes so the exact family member is available to the player's faction.
    cm:callback(function()
        local leader = current_character(pending.family_member_cqi)
        local leader_cqi = tonumber(call_or(leader, "command_queue_index", pending.character_cqi)) or 0
        if leader_cqi > 0 then
            pcall(function() cm:stop_character_convalescing(leader_cqi) end)
        end
        set_immortality(leader, true)
    end, 0.1)
    return true
end

local function pending_disposition_exists(state, source_faction_key, family_member_cqi)
    if not state or type(state.pending_leader_dispositions) ~= "table" then return false end
    for _, pending in ipairs(state.pending_leader_dispositions) do
        if pending.source_faction == source_faction_key
            and tonumber(pending.family_member_cqi) == tonumber(family_member_cqi) then
            return true
        end
    end
    return false
end

local function queue_leader_disposition(warden_faction, state, record, character)
    if not safe_interface(warden_faction) or not state or not record
        or record.is_faction_leader ~= true then
        return false
    end
    local source_key = tostring(record.source_faction or "")
    local warden_key = warden_faction:name()
    if source_key == "" or source_key == warden_key then return false end
    state.pending_leader_dispositions = state.pending_leader_dispositions or {}
    if pending_disposition_exists(state, source_key, record.family_member_cqi) then
        return true
    end

    local source_faction = nil
    pcall(function() source_faction = cm:get_faction(source_key) end)
    if not faction_is_alive(source_faction) then
        log("leader disposition skipped: source faction is unavailable " .. source_key)
        return false
    end

    local target_character = character
    if not safe_interface(target_character) then
        target_character = current_character(record.family_member_cqi)
    end
    local source_faction_cqi = faction_command_queue_index(source_faction)
    local leader_name = safe_interface(target_character)
        and character_name(target_character) or prisoner_display_name(record)
    local pending = {
        source_faction = source_key,
        family_member_cqi = tonumber(record.family_member_cqi) or 0,
        character_cqi = tonumber(call_or(target_character, "command_queue_index", 0)) or 0,
        subtype = tostring(record.subtype or ""),
        role = tostring(record.role or "lord"),
        rank = math.max(1, tonumber(record.rank) or 1),
        forename = tostring(record.forename or ""),
        surname = tostring(record.surname or ""),
        age = math.max(18, tonumber(record.age) or 30),
        is_male = record.is_male ~= false,
        is_unique = record.is_unique == true,
        source_culture = tostring(record.source_culture or ""),
        leader_name = leader_name,
        queued_turn = current_turn_number()
    }
    table.insert(state.pending_leader_dispositions, pending)

    local triggered = false
    if source_faction_cqi > 0 then
        local trigger_ok, trigger_error = pcall(function()
            -- The character CQI can change while a wounded legendary leader is
            -- restored and reassigned.  Resolve the persistent family member
            -- only when the intervention actually opens the dilemma, matching
            -- the dedicated campaign-manager API for death/respawn boundaries.
            triggered = cm:trigger_dilemma_with_targets_internal(
                warden_faction:command_queue_index(),
                LEADER_DISPOSITION_DILEMMA,
                source_faction_cqi, 0, 0,
                tonumber(record.family_member_cqi) or 0,
                0, 0, 0, nil, false
            ) == true
        end)
        if not trigger_ok then
            log("leader disposition target-aware trigger failed for " .. source_key
                .. ": " .. tostring(trigger_error))
        end
    end
    if not triggered then
        -- Keep the state entry even if a transient intervention delays the
        -- target-aware issue; the choice listener consumes it once the
        -- dilemma is eventually delivered.
        pcall(function() triggered = cm:trigger_dilemma(warden_key, LEADER_DISPOSITION_DILEMMA) == true end)
    end
    log("leader disposition queued for " .. leader_name .. " / " .. source_key
        .. "; dilemma_triggered=" .. tostring(triggered))
    return true
end

local DILEMMA_CHOICE_INDEX_BY_KEY = {
    FIRST = 0,
    SECOND = 1,
    THIRD = 2,
    FOURTH = 3
}

local function leader_disposition_choice_index(context)
    local choice = nil
    pcall(function() choice = context:choice() end)
    local numeric_choice = tonumber(choice)
    if numeric_choice ~= nil then return numeric_choice, tostring(choice) end

    local choice_key = tostring(choice or "")
    if choice_key == "" then
        pcall(function() choice_key = tostring(context:choice_key() or "") end)
    end
    return DILEMMA_CHOICE_INDEX_BY_KEY[choice_key] or -1, choice_key
end

local function resolve_leader_disposition(warden_faction, choice)
    if not safe_interface(warden_faction) then return false end
    local state = get_state(warden_faction:name())
    local pending_list = state.pending_leader_dispositions or {}
    local pending = table.remove(pending_list, 1)
    if not pending then
        log("leader disposition choice received without pending target")
        return false
    end
    local selected_choice = tonumber(choice) or -1
    local record = find_prisoner(state, pending.family_member_cqi)
    if selected_choice == LEADER_DISPOSITION_CHOICES.annex then
        if annex_leader_faction(warden_faction, pending) then
            if record then
                cross_culture_annex.clear_prison_record(warden_faction, state, record, false)
            end
            log("leader disposition annexed faction: " .. tostring(pending.source_faction))
        end
    elseif selected_choice == LEADER_DISPOSITION_CHOICES.vassal then
        -- Confirm the diplomatic result before creating the player's copy of
        -- the captured leader.  Once that distinct identity is registered,
        -- the original source-faction family member is permanently killed.
        local vassal_requested = make_leader_faction_vassal(
            warden_faction, pending.source_faction,
            function(vassal_confirmed, vassal_reason)
                if not vassal_confirmed then
                    log("leader disposition vassal leader replacement skipped: "
                        .. tostring(vassal_reason))
                    return
                end

                local current_record = find_prisoner(
                    state, pending.family_member_cqi
                )
                if not current_record then
                    log("leader disposition vassal confirmed without a detained original: "
                        .. tostring(pending.source_faction))
                    return
                end

                local started = perform_recruit(warden_faction, state, current_record, {
                    forced = true,
                    suppress_feedback = true,
                    replace_original_leader = true,
                    on_complete = function(success, reason)
                        if success then
                            log("leader disposition vassal granted a replacement leader and permanently killed the original: "
                                .. tostring(pending.source_faction))
                        else
                            log("leader disposition vassal leader replacement failed: "
                                .. tostring(reason))
                        end
                    end
                })
                if not started then
                    log("leader disposition could not start vassal leader replacement for family member "
                        .. tostring(pending.family_member_cqi))
                end
            end
        )
        if not vassal_requested then
            log("leader disposition could not issue vassal request for "
                .. tostring(pending.source_faction))
        end
    elseif selected_choice == LEADER_DISPOSITION_CHOICES.destroy then
        local source_faction = nil
        pcall(function() source_faction = cm:get_faction(pending.source_faction) end)
        if record then
            cross_culture_annex.clear_prison_record(warden_faction, state, record, false)
        end
        cross_culture_annex.destroy_faction(source_faction, pending.family_member_cqi)
    elseif selected_choice == LEADER_DISPOSITION_CHOICES.release then
        if record then
            cross_culture_annex.clear_prison_record(warden_faction, state, record, true)
        end
        log("leader disposition released leader without further effect: "
            .. tostring(pending.leader_name))
    else
        log("leader disposition ignored unknown choice index " .. tostring(selected_choice))
        if record then
            table.insert(state.pending_leader_dispositions, 1, pending)
        end
    end
    enforce_prisoners(warden_faction, state)
    return true
end

local function capture_prisoner(warden_faction, family_member_cqi, evidence, character_override)
    local warden_name = "?"
    pcall(function() warden_name = warden_faction:name() end)
    debug_log("capture attempt; warden=" .. tostring(warden_name)
        .. ", family_member_cqi=" .. tostring(family_member_cqi)
        .. ", event_character=" .. tostring(safe_interface(character_override)))
    if not is_player_warden(warden_faction) then return false end
    local state = get_state(warden_faction:name())
    if prisoner_count(state) >= prisoner_capacity(state) then
        log("capture rejected: no independent prison capacity")
        return false
    end
    if find_prisoner(state, family_member_cqi) then return false end
    -- A campaign outcome event may arrive while the engine is replacing a
    -- defeated character instance. Prefer its wrapper when available, then
    -- fall back to the stable family-member lookup.
    local character = character_override
    if not safe_interface(character) then
        character = current_character(family_member_cqi)
    end
    if cross_culture_annex.is_garrison_character(character)
        or (evidence and evidence.identity and evidence.identity.character_type_key == "colonel")
    then
        log("capture rejected: temporary settlement garrison character")
        return false
    end
    -- A permanently killed non-immortal general has no live character wrapper
    -- at this point, but its family member and character_details remain
    -- persistent.  Keep that identity as a prisoner record instead of losing
    -- the capture solely because the battle destroyed the transient wrapper.
    local family_member = current_family_member(family_member_cqi)
    local details = nil
    if safe_interface(character) then
        details = call_or(character, "character_details", nil)
    end
    if not safe_interface(details) and safe_interface(family_member) then
        details = call_or(family_member, "character_details", nil)
    end
    local identity = evidence and evidence.identity
    local details_available = safe_interface(details)
    local identity_available = type(identity) == "table"
    if not details_available and not identity_available then
        debug_log("capture rejected: character details unavailable for family_member_cqi="
            .. tostring(family_member_cqi))
        log("capture rejected: character details unavailable " .. tostring(family_member_cqi))
        return false
    end
    -- The DB flag unit_is_not_commander_class accepts both the army general and
    -- embedded hero character units.  CharacterConvalescedOrKilled is already
    -- character-only evidence, so rejecting every non-general here discards a
    -- legitimate hero target and lets a later leader outcome steal the cage.
    local source_faction = call_or(character, "faction", nil)
    if not safe_interface(source_faction) then
        source_faction = call_or(details, "faction", nil)
    end
    local source_faction_key = call_or(source_faction, "name", "")
    if source_faction_key == "" and identity_available then
        source_faction_key = tostring(identity.source_faction or "")
    end
    if source_faction_key == "" then
        debug_log("capture rejected: source faction unavailable for family_member_cqi="
            .. tostring(family_member_cqi))
        log("capture rejected: source faction unavailable " .. tostring(family_member_cqi))
        return false
    end
    local function identity_value(method, identity_key, fallback)
        local value = call_or(character, method, nil)
        if value == nil or value == "" then
            value = call_or(details, method, nil)
        end
        if (value == nil or value == "") and identity_available then
            value = identity[identity_key]
        end
        if value == nil or value == "" then return fallback end
        return value
    end
    local character_cqi = tonumber(identity_value("command_queue_index", "character_cqi", 0)) or 0
    local source_culture = identity_value("culture", "source_culture", "")
    if source_culture == "" then source_culture = call_or(source_faction, "culture", "") end
    local source_subculture = identity_value("subculture", "source_subculture", "")
    if source_subculture == "" then source_subculture = call_or(source_faction, "subculture", "") end
    local subtype = identity_value("character_subtype_key", "subtype", "")
    local persisted_character_type_key = identity_value("character_type_key", "character_type_key", "")
    local rank = identity_value("rank", "rank", 1)
    local forename = identity_value("get_forename", "forename", "")
    local surname = identity_value("get_surname", "surname", "")
    local is_faction_leader = nil
    if identity_available and identity.is_faction_leader ~= nil then
        is_faction_leader = identity.is_faction_leader == true
    end
    if is_faction_leader == nil then
        is_faction_leader = faction_leader_status(source_faction, character, family_member_cqi)
    end
    is_faction_leader = is_faction_leader == true
    local role = ""
    if persisted_character_type_key == "general" then
        role = "lord"
    elseif persisted_character_type_key ~= "" then
        role = "hero"
    elseif is_faction_leader then
        role = "lord"
    end
    local leader_key = ""
    local leader_count = 0
    if is_faction_leader then
        leader_key = leader_capture_key(source_faction_key, family_member_cqi, subtype)
        leader_count = (tonumber(state.leader_capture_counts[leader_key]) or 0) + 1
        state.leader_capture_counts[leader_key] = leader_count
    end
    local portrait_path = ""
    if identity_available then
        portrait_path = tostring(identity.portrait_path or "")
    end
    if portrait_path == "" and safe_interface(character) then
        portrait_path = character_portrait(character) or ""
    end
    if portrait_path == "" then
        portrait_path = portrait_for_identity(subtype, character_cqi, source_faction_key) or ""
    end
    -- The returned target is temporarily made immortal before the outcome
    -- event so the engine wounds rather than deletes a normal hero.  Preserve
    -- the pre-battle value from the identity snapshot, not that temporary flag.
    local was_immortal = nil
    if identity_available and identity.was_immortal ~= nil then
        was_immortal = identity.was_immortal
    else
        was_immortal = call_or(details, "is_immortal", nil)
    end
    was_immortal = was_immortal == true
    local is_unique = call_or(details, "is_unique", nil)
    if is_unique == nil and identity_available then is_unique = identity.is_unique end
    is_unique = is_unique == true
    local is_male = call_or(details, "character_subtype_has_female_name", nil)
    if is_male ~= nil then
        is_male = is_male ~= true
    elseif identity_available and identity.is_male ~= nil then
        is_male = identity.is_male == true
    else
        is_male = true
    end
    local age = call_or(details, "age", nil)
    if age == nil and identity_available then age = identity.age end
    age = math.max(18, tonumber(age) or 30)
    local captured_turn = 0
    pcall(function() captured_turn = cm:model():turn_number() end)
    local record = {
        family_member_cqi = family_member_cqi,
        character_cqi = character_cqi,
        source_faction = source_faction_key,
        source_culture = source_culture,
        source_subculture = source_subculture,
        subtype = subtype,
        character_type_key = persisted_character_type_key,
        role = role,
        rank = rank,
        forename = forename,
        surname = surname,
        age = age,
        is_male = is_male,
        portrait_path = portrait_path,
        was_immortal = was_immortal,
        is_unique = is_unique,
        is_faction_leader = is_faction_leader,
        leader_capture_key = leader_key,
        leader_capture_count = leader_count,
        captured_turn = captured_turn,
        battle_army_index = evidence and evidence.army_index or 0,
        battle_army_id = evidence and evidence.army_id or ""
    }
    -- Battle captures reach this function only after
    -- ScriptEventBattleSequenceCompleted. The returned target was
    -- pre-armed as immortal before its outcome event, so it should already be
    -- wounded, but that ordinary battle wound does not establish detention.
    -- Set the long recovery time even when the character is already wounded.
    state.prisoners[#state.prisoners + 1] = record
    if safe_interface(character) then
        local capture_source = tostring(evidence and evidence.source or "")
        local inside_character_outcome = capture_source == "CharacterConvalescedOrKilled"
            or capture_source == "CharacterDestroyed"
            or capture_source == "CharacterCompletedBattle"
        set_immortality(character, true)
        if not inside_character_outcome then
            wound_for_detention(character)
        end
    end
    -- Native wound/recovery commands can invalidate this wrapper immediately.
    -- Do not even query its CQI for the notice; retain only the prison record.
    character = nil
    apply_held_effects(warden_faction, state)
    update_cage_ability(warden_faction, state)
    if is_faction_leader
        and leader_count >= cross_culture_annex.leader_capture_unlock_count()
    then
        -- The family member is already committed to state.prisoners above.  The
        -- the configured capture threshold and every later capture now opens
        -- the disposition event from
        -- that real detention state instead of waiting for a prison action.
        queue_leader_disposition_event(warden_faction, state, record, character)
    else
        queue_prison_incident(warden_faction, "wyccc_prison_incident_captured", nil)
    end
    log("captured original family member " .. tostring(family_member_cqi)
        .. " from " .. tostring(record.source_faction)
        .. " army=" .. tostring(record.battle_army_index))
    debug_log("capture success; family_member_cqi=" .. tostring(family_member_cqi)
        .. ", character_cqi=" .. tostring(record.character_cqi))
    return true
end

-- Commander-class roster units added by grant_unit_to_character (for example
-- the psw_tfmw_*_boss_* demon-king units) have no campaign character and no
-- family member.  The battle bridge resolves them as fm=0 unit targets; the
-- prison keeps the unit itself as the captive and rebuilds it on the target
-- army when a prison action needs the unit back on the map.
local function capture_unit_prisoner(warden_faction, unit_target, evidence)
    local warden_name = "?"
    pcall(function() warden_name = warden_faction:name() end)
    debug_log("unit capture attempt; warden=" .. tostring(warden_name)
        .. ", unit_key=" .. tostring(unit_target and unit_target.unit_key or ""))
    if not is_player_warden(warden_faction) then return false end
    local unit_key = tostring(unit_target and unit_target.unit_key or "")
    if unit_key == "" then
        log("unit capture rejected: missing unit key")
        return false
    end
    local state = get_state(warden_faction:name())
    if prisoner_count(state) >= prisoner_capacity(state) then
        log("unit capture rejected: no independent prison capacity")
        return false
    end
    local source_faction_key = tostring(unit_target.source_faction or "")
    local source_faction = nil
    if source_faction_key ~= "" then
        pcall(function() source_faction = cm:get_faction(source_faction_key) end)
    end
    state.unit_prisoner_seq = (tonumber(state.unit_prisoner_seq) or 0) + 1
    local captured_turn = 0
    pcall(function() captured_turn = cm:model():turn_number() end)
    local record = {
        is_unit = true,
        -- Unit prisoners are keyed by record_id, not family_member_cqi; all
        -- character-only lookups must see fm=0 instead of a fake identity.
        record_id = "unit:" .. source_faction_key .. ":" .. unit_key
            .. ":" .. tostring(captured_turn) .. ":" .. tostring(state.unit_prisoner_seq),
        family_member_cqi = 0,
        character_cqi = 0,
        unit_key = unit_key,
        unit_cqi = tonumber(unit_target.unit_cqi) or 0,
        source_faction = source_faction_key,
        source_culture = call_or(source_faction, "culture", ""),
        source_subculture = call_or(source_faction, "subculture", ""),
        subtype = "",
        character_type_key = "",
        role = "unit",
        rank = 1,
        forename = "",
        surname = "",
        age = 0,
        is_male = true,
        portrait_path = "ui/units/icons/" .. unit_key .. ".png",
        was_immortal = false,
        is_unique = false,
        is_faction_leader = false,
        leader_capture_key = "",
        leader_capture_count = 0,
        captured_turn = captured_turn,
        battle_army_index = tonumber(evidence and evidence.army_index)
            or tonumber(unit_target.army_index) or 0,
        battle_army_id = tostring(evidence and evidence.army_id or "")
            ~= "" and tostring(evidence and evidence.army_id or "")
            or tostring(unit_target.army_mf_cqi or "")
    }
    state.prisoners[#state.prisoners + 1] = record
    apply_held_effects(warden_faction, state)
    update_cage_ability(warden_faction, state)
    queue_prison_incident(warden_faction, "wyccc_prison_incident_captured", nil)
    log("captured roster unit " .. unit_key .. " from " .. source_faction_key
        .. " army=" .. tostring(record.battle_army_index))
    debug_log("unit capture success; record_id=" .. tostring(record.record_id))
    return true
end

local function queue_battle_capture_finalization(
    warden_faction, family_member_cqi, evidence
)
    if cross_culture_annex.is_quest_battle() then return false end
    if not is_player_warden(warden_faction) then return false end
    family_member_cqi = tonumber(family_member_cqi) or 0
    -- Roster-unit targets (is_unit identities) carry no family member; the
    -- battle-side DB flag already proved they were commander-class.
    local unit_target = nil
    if type(evidence) == "table" and type(evidence.identity) == "table"
        and evidence.identity.is_unit == true
    then
        unit_target = evidence.identity
    end
    if unit_target then
        if tostring(unit_target.unit_key or "") == "" then return false end
    elseif family_member_cqi <= 0 then
        return false
    end

    for _, pending in ipairs(pending_battle_capture_finalizations) do
        if unit_target then
            local pending_target = pending.unit_target
            if type(pending_target) == "table"
                and tostring(pending_target.unit_key) == tostring(unit_target.unit_key)
                and tostring(pending_target.source_faction) == tostring(unit_target.source_faction)
            then
                return true
            end
        elseif tonumber(pending.family_member_cqi) == family_member_cqi then
            return true
        end
    end

    local state = get_state(warden_faction:name())
    if not unit_target and find_prisoner(state, family_member_cqi) then return false end
    if prisoner_count(state) + #pending_battle_capture_finalizations
        >= prisoner_capacity(state)
    then
        log("capture rejected: no independent prison capacity")
        return false
    end

    pending_battle_capture_finalizations[#pending_battle_capture_finalizations + 1] = {
        warden_faction = warden_faction:name(),
        family_member_cqi = family_member_cqi,
        unit_target = unit_target,
        army_index = tonumber(evidence and evidence.army_index) or 0,
        army_id = tostring(evidence and evidence.army_id or ""),
        identity = evidence and evidence.identity or nil,
        source = tostring(evidence and evidence.source or "BattleOutcome")
    }
    log("battle capture queued; family_member_cqi=" .. tostring(family_member_cqi)
        .. ", unit_key=" .. tostring(unit_target and unit_target.unit_key or "")
        .. ", source=" .. tostring(evidence and evidence.source or "BattleOutcome")
        .. ", human_turn=" .. tostring(call_or(cm, "is_human_factions_turn", false)))
    cross_culture_annex.schedule_capture_finalization()
    return true
end

local function finalize_pending_battle_captures()
    -- Each entry was validated when queued. A later battle's quest flag must
    -- not erase an earlier ordinary battle's pending capture.
    if #pending_battle_capture_finalizations == 0 then return end

    local queued = pending_battle_capture_finalizations
    pending_battle_capture_finalizations = {}
    for _, pending in ipairs(queued) do
        local warden_faction = nil
        pcall(function()
            warden_faction = cm:get_faction(pending.warden_faction)
        end)
        local captured = false
        if type(pending.unit_target) == "table" then
            captured = capture_unit_prisoner(
                warden_faction,
                pending.unit_target,
                {
                    source = "PostBattleSequence:" .. tostring(pending.source),
                    army_index = pending.army_index,
                    army_id = pending.army_id
                }
            )
        else
            local character = current_character(pending.family_member_cqi)
            captured = capture_prisoner(
                warden_faction,
                pending.family_member_cqi,
                {
                    source = "PostBattleSequence:" .. tostring(pending.source),
                    army_index = pending.army_index,
                    army_id = pending.army_id,
                    identity = pending.identity
                },
                character
            )
        end
        if captured then
            debug_log("post-battle sequence capture finalized; family_member_cqi="
                .. tostring(pending.family_member_cqi)
                .. ", unit_key=" .. tostring(pending.unit_target and pending.unit_target.unit_key or ""))
        else
            debug_log("post-battle sequence capture finalization failed; family_member_cqi="
                .. tostring(pending.family_member_cqi)
                .. ", unit_key=" .. tostring(pending.unit_target and pending.unit_target.unit_key or ""))
        end
    end
end

function cross_culture_annex.schedule_capture_finalization()
    if cross_culture_annex.capture_finalization_scheduled then return end
    cross_culture_annex.capture_finalization_scheduled = true
    cross_culture_annex.after_battle_sequence("wyccc_prison_capture_finalization", function()
        cross_culture_annex.capture_finalization_scheduled = false
        finalize_pending_battle_captures()
    end, 0.1)
end

local function player_warden_faction()
    local local_faction_key = ""
    pcall(function() local_faction_key = cm:get_local_faction_name(true) or "" end)
    local local_faction = nil
    if local_faction_key ~= "" then
        pcall(function() local_faction = cm:get_faction(local_faction_key) end)
    end
    if is_player_warden(local_faction) then
        return local_faction
    end
    return nil
end

local function snapshot_character_identity(character, family_member, family_member_cqi)
    local details = call_or(character, "character_details", nil)
    if not safe_interface(details) then
        details = call_or(family_member, "character_details", nil)
    end
    local source_faction = call_or(character, "faction", nil)
    if not safe_interface(source_faction) then
        source_faction = call_or(details, "faction", nil)
    end
    local source_faction_key = call_or(source_faction, "name", "")
    local persisted_character_type_key = character_type_key(character)
    if persisted_character_type_key == "" then
        persisted_character_type_key = tostring(call_or(details, "character_type_key", "") or "")
    end
    local is_faction_leader = faction_leader_status(
        source_faction, character, family_member_cqi
    )
    local is_general = call_or(character, "character_type", nil, "general")
    if is_general == nil then
        is_general = persisted_character_type_key == "general" or is_faction_leader == true
    end
    local role = ""
    if persisted_character_type_key == "general" or is_faction_leader == true then
        role = "lord"
    elseif persisted_character_type_key ~= "" then
        role = "hero"
    end
    local subtype = call_or(
        character, "character_subtype_key",
        call_or(details, "character_subtype_key", "")
    )
    local character_cqi = tonumber(call_or(character, "command_queue_index", 0)) or 0
    return {
        family_member_cqi = tonumber(family_member_cqi) or 0,
        character_cqi = character_cqi,
        source_faction = source_faction_key,
        source_culture = call_or(
            character, "culture",
            call_or(details, "culture", call_or(source_faction, "culture", ""))
        ),
        source_subculture = call_or(
            character, "subculture",
            call_or(details, "subculture", call_or(source_faction, "subculture", ""))
        ),
        subtype = subtype,
        character_type_key = persisted_character_type_key,
        role = role,
        rank = call_or(character, "rank", call_or(details, "rank", 1)),
        forename = call_or(character, "get_forename", call_or(details, "get_forename", "")),
        surname = call_or(character, "get_surname", call_or(details, "get_surname", "")),
        age = math.max(18, tonumber(call_or(details, "age", 30)) or 30),
        is_male = call_or(details, "character_subtype_has_female_name", false) ~= true,
        portrait_path = portrait_for_identity(subtype, character_cqi, source_faction_key) or "",
        was_immortal = call_or(details, "is_immortal", false) == true,
        is_unique = call_or(details, "is_unique", false) == true,
        is_general = is_general,
        is_faction_leader = is_faction_leader
    }
end

-- PendingBattle runs in the campaign context before the battle executable is
-- entered.  It serialises each character unit's stable family-member CQI by
-- participant and roster position.  Battle Lua can then save the exact target
-- unit index, and the campaign result can recover the same hero/general even
-- after the live character or unit wrapper has been destroyed.
local function saved_battle_character_entry(
    target_faction, target_army_index, target_army_id,
    target_unit_index, target_unit_key, resolve_identity
)
    local encoded = ""
    pcall(function()
        encoded = core:svr_load_string("wyccc_prison_battle_character_unit_map") or ""
    end)
    local wanted_unit_index = tonumber(target_unit_index) or 0
    if encoded == "" or wanted_unit_index <= 0 then return nil end

    local wanted_faction = tostring(target_faction or "")
    local wanted_army_id = tostring(target_army_id or "")
    local wanted_army_index = tonumber(target_army_index) or 0
    local wanted_unit_key = tostring(target_unit_key or "")
    for entry in string.gmatch(encoded, "[^;]+") do
        local side, army_index, mf_cqi, faction_key,
            unit_index, unit_cqi, unit_key, family_member_cqi,
            original_was_immortal =
            string.match(
                entry,
                "^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$"
            )
        if not side then
            side, army_index, mf_cqi, faction_key,
                unit_index, unit_cqi, unit_key, family_member_cqi =
                string.match(
                    entry,
                    "^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$"
                )
        end
        -- Battle army unique_id() is not guaranteed to be the campaign
        -- military-force CQI, so retain roster position as the bridge when the
        -- two identifiers belong to different namespaces.
        local army_matches = (
            wanted_army_id ~= ""
            and tostring(mf_cqi or "") == wanted_army_id
        ) or tonumber(army_index) == wanted_army_index
        if side and faction_key == wanted_faction
            and army_matches
            and tonumber(unit_index) == wanted_unit_index
        then
            local fm_cqi = tonumber(family_member_cqi) or 0
            -- Reject older bridges too while the original garrison force exists.
            if cross_culture_annex.is_garrison_force_cqi(mf_cqi) then return nil end
            if fm_cqi <= 0 then
                -- An fm=0 map entry is a commander-class roster unit with no
                -- campaign character (see snapshot_pending_battle).  Return a
                -- unit target instead of a family-member identity; Lua 0 is
                -- truthy, so callers must branch on the is_unit flag.
                local unit_target = {
                    is_unit = true,
                    unit_key = tostring(unit_key or ""),
                    unit_cqi = tonumber(unit_cqi) or 0,
                    source_faction = tostring(faction_key or ""),
                    army_index = tonumber(army_index) or 0,
                    army_mf_cqi = tostring(mf_cqi or ""),
                    side = tostring(side or "")
                }
                if resolve_identity == false then return 0 end
                debug_log("exact target resolved as roster unit; side=" .. tostring(side)
                    .. ", army=" .. tostring(army_index)
                    .. ", unit_index=" .. tostring(unit_index)
                    .. ", unit_cqi=" .. tostring(unit_cqi)
                    .. ", unit_key=" .. tostring(unit_key))
                return 0, unit_target, tonumber(unit_cqi) or 0,
                    tostring(unit_key or ""), tostring(side or "")
            end
            if resolve_identity == false then return fm_cqi end
            if wanted_unit_key ~= "" and unit_key ~= ""
                and wanted_unit_key ~= unit_key
            then
                debug_log("exact target unit key differs across contexts; battle="
                    .. wanted_unit_key .. ", campaign=" .. tostring(unit_key))
            end
            -- Campaign characters may be destroyed/replaced while these
            -- result callbacks run. Read only the saved pre-battle snapshot;
            -- the finalizer resolves live interfaces after the whole sequence.
            local roster = side == "attacker" and pending_battle_snapshot.attackers
                or pending_battle_snapshot.defenders
            local army = roster and roster[tonumber(army_index)]
            local unit = army and army.character_units and army.character_units[tonumber(unit_index)]
            local identity = {family_member_cqi = fm_cqi, source_faction = faction_key}
            if unit and tonumber(unit.family_member_cqi) == fm_cqi
                and army.faction_key == faction_key and type(unit.identity) == "table"
            then
                for key, value in pairs(unit.identity) do identity[key] = value end
            end
            if type(identity) == "table"
                and (original_was_immortal == "0" or original_was_immortal == "1")
            then
                identity.was_immortal = original_was_immortal == "1"
            end
            debug_log("exact target map resolved; side=" .. tostring(side)
                .. ", army=" .. tostring(army_index)
                .. ", unit_index=" .. tostring(unit_index)
                .. ", unit_cqi=" .. tostring(unit_cqi)
                .. ", unit_key=" .. tostring(unit_key)
                .. ", fm_cqi=" .. tostring(fm_cqi))
            return fm_cqi, identity, tonumber(unit_cqi) or 0,
                tostring(unit_key or ""), tostring(side or "")
        end
    end
    return nil
end

function cross_culture_annex.has_persistent_cage_target()
    -- Validate the primitive bridge before opening an outcome context's
    -- temporary character/family wrappers. Do not rebuild an identity here.
    return saved_battle_character_entry(
        core:svr_load_string(SVR_TARGET_FACTION) or "",
        tonumber(core:svr_load_string(SVR_TARGET_ARMY_INDEX)) or 0,
        core:svr_load_string(SVR_TARGET_ARMY_ID) or "",
        tonumber(core:svr_load_string("wyccc_prison_battle_target_unit_index")) or 0,
        core:svr_load_string("wyccc_prison_battle_target_unit_key") or "",
        false
    ) ~= nil
end

-- CharacterConvalescedOrKilled is kept as a compatibility path for battle Lua's
-- exact unit marker. An unmarked defeat is never enough evidence: ability-use
-- count proves only that somebody was targeted and must not select the army
-- commander or faction leader on its own.
function cross_culture_annex.queue_recorded_cage_target(source)
    if cross_culture_annex.is_quest_battle() then return false end
    if core:svr_load_bool("wyccc_prison_battle_capture_committed") == true then return false end
    if core:svr_load_bool(SVR_DETECTED) ~= true
        or core:svr_load_bool(SVR_CAGE_KILLED) ~= true then return false end
    local warden = player_warden_faction()
    if not is_player_warden(warden) then return false end
    local warden_key = core:svr_load_string(SVR_WARDEN_FACTION) or ""
    if warden_key ~= "" and warden_key ~= warden:name() then return false end
    if call_or(cm, "pending_battle_cache_faction_won_battle", false, warden:name()) ~= true then
        return false
    end
    local army_index = tonumber(core:svr_load_string(SVR_TARGET_ARMY_INDEX)) or 0
    local army_id = core:svr_load_string(SVR_TARGET_ARMY_ID) or ""
    local fm_cqi, identity = saved_battle_character_entry(
        core:svr_load_string(SVR_TARGET_FACTION) or "", army_index, army_id,
        tonumber(core:svr_load_string("wyccc_prison_battle_target_unit_index")) or 0,
        core:svr_load_string("wyccc_prison_battle_target_unit_key") or "")
    if not fm_cqi then return false end
    local queued = queue_battle_capture_finalization(warden, fm_cqi, {
        source = source, army_index = army_index, army_id = army_id, identity = identity})
    if queued then
        core:svr_save_bool("wyccc_prison_battle_capture_committed", true)
        core:svr_save_bool(SVR_CAGE_KILLED, false)
        core:svr_save_bool(SVR_DETECTED, false)
    end
    return queued
end

local function capture_from_character_outcome(context, event_name)
    if event_name == "CharacterDestroyed" then return end
    -- The battle bridge already identifies the exact unit killed in the cage.
    -- An outcome is only a wake-up signal; its native character/family wrapper
    -- may be invalid, or belong to another casualty in the same battle.
    cross_culture_annex.queue_recorded_cage_target(event_name)
end

-- The native immortal-defeat listener is another opportunity to consume the
-- exact saved cage result. It never supplies our prisoner identity: defeated
-- character wrappers may be replaced as part of the same battle resolution.
local function cage_immortal_defeat_condition()
    if cross_culture_annex.is_quest_battle() then return false end
    if not cross_culture_annex.has_persistent_cage_target() then return false end
    local detected = false
    local cage_killed = false
    pcall(function() detected = core:svr_load_bool(SVR_DETECTED) == true end)
    pcall(function() cage_killed = core:svr_load_bool(SVR_CAGE_KILLED) == true end)
    if not detected or not cage_killed then return false end
    local warden = player_warden_faction()
    if not is_player_warden(warden) then return false end
    local won = false
    pcall(function() won = cm:pending_battle_cache_faction_won_battle(warden:name()) == true end)
    return won
end

local function capture_from_immortal_defeat(victorious_fm, defeated_fm)
    -- Never dereference callback wrappers while the engine is replacing them.
    cross_culture_annex.queue_recorded_cage_target("ImmortalCharacterDefeated")
end

local function find_ai_alarielle_family_member()
    local faction_list = nil
    pcall(function() faction_list = cm:get_faction_list() end)
    if not faction_list then return nil, nil end

    local fallback_fm_cqi = nil
    local fallback_faction_key = nil
    for faction_index = 0, faction_list:num_items() - 1 do
        local faction = faction_list:item_at(faction_index)
        if safe_interface(faction) then
            local is_human = true
            local is_dead = false
            pcall(function() is_human = faction:is_human() end)
            pcall(function() is_dead = faction:is_dead() end)
            if not is_human and not is_dead then
                local characters = nil
                pcall(function() characters = faction:character_list() end)
                if characters then
                    for character_index = 0, characters:num_items() - 1 do
                        local character = characters:item_at(character_index)
                        local subtype = ""
                        local family_member_cqi = 0
                        if safe_interface(character) then
                            pcall(function() subtype = character:character_subtype_key() end)
                            if subtype == STARTUP_ALARIELLE_SUBTYPE then
                                pcall(function()
                                    family_member_cqi = character:family_member():command_queue_index()
                                end)
                                if family_member_cqi > 0 then
                                    local faction_key = faction:name()
                                    if faction_key == STARTUP_ALARIELLE_FACTION then
                                        return family_member_cqi, faction_key
                                    end
                                    if not fallback_fm_cqi then
                                        fallback_fm_cqi = family_member_cqi
                                        fallback_faction_key = faction_key
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return fallback_fm_cqi, fallback_faction_key
end

local function run_startup_alarielle_test()
    if not STARTUP_ALARIELLE_TEST_ENABLED or startup_alarielle_test_done then
        return true
    end

    local new_game = false
    pcall(function() new_game = cm:is_new_game() == true end)
    if not new_game then
        -- This hook is intentionally limited to a fresh campaign; loading a
        -- save must never create a second copy of the test prisoner.
        startup_alarielle_test_done = true
        return true
    end

    local warden_faction = player_warden_faction()
    if not warden_faction then
        log("startup Alarielle test waiting for a human warden faction")
        return false
    end

    local family_member_cqi, source_faction = find_ai_alarielle_family_member()
    if not family_member_cqi then
        log("startup Alarielle test waiting for an AI character")
        return false
    end

    local state = get_state(warden_faction:name())
    if find_prisoner(state, family_member_cqi) then
        startup_alarielle_test_done = true
        log("startup Alarielle test found an existing prison record; no duplicate added")
        return true
    end
    if prisoner_count(state) >= prisoner_capacity(state) then
        log("startup Alarielle test blocked: no independent prison capacity")
        return false
    end

    if capture_prisoner(warden_faction, family_member_cqi, {
        army_index = 0,
        army_id = "startup_alarielle_test"
    }) then
        startup_alarielle_test_done = true
        log("startup Alarielle test captured AI family member " .. tostring(family_member_cqi)
            .. " from " .. tostring(source_faction))
        return true
    end
    log("startup Alarielle test failed to capture family member " .. tostring(family_member_cqi))
    return false
end

local function initialize_startup_alarielle_test()
    if not STARTUP_ALARIELLE_TEST_ENABLED then return end
    local attempts = 0
    local function attempt()
        if startup_alarielle_test_done then return end
        attempts = attempts + 1
        if run_startup_alarielle_test() then
            refresh_ui()
            return
        end
        if attempts < STARTUP_ALARIELLE_MAX_ATTEMPTS then
            cm:callback(attempt, 0.5)
        else
            log("startup Alarielle test stopped after " .. tostring(attempts) .. " attempts")
        end
    end
    attempt()
end

-- Unit prisoners are rebuilt on a field army's roster.  Prefer the faction
-- leader's army, then any regular ARMY force, then any other field force;
-- every candidate must have a living general and a free roster slot.
local function army_general_with_space(faction)
    if not safe_interface(faction) then return nil end
    local leader = call_or(faction, "faction_leader", nil)
    local leader_cqi = tonumber(call_or(leader, "command_queue_index", 0)) or 0
    local mf_list = call_or(faction, "military_force_list", nil)
    local force_count = tonumber(call_or(mf_list, "num_items", 0)) or 0
    local army_fallback, other_fallback = nil, nil
    for i = 0, force_count - 1 do
        local force = call_or(mf_list, "item_at", nil, i)
        if safe_interface(force)
            and call_or(force, "is_armed_citizenry", false) ~= true
            and call_or(force, "has_general", false) == true
        then
            local general = call_or(force, "general_character", nil)
            local units = call_or(force, "unit_list", nil)
            local roster_size = safe_interface(units)
                and tonumber(call_or(units, "num_items", 20)) or 20
            if safe_interface(general)
                and call_or(general, "is_wounded", false) ~= true
                and roster_size < 20
            then
                if leader_cqi > 0
                    and tonumber(call_or(general, "command_queue_index", 0)) == leader_cqi
                then
                    return general
                end
                local force_type = call_or(call_or(force, "force_type", nil), "key", "")
                if force_type == "ARMY" then
                    if not army_fallback then army_fallback = general end
                elseif not other_fallback then
                    other_fallback = general
                end
            end
        end
    end
    return army_fallback or other_fallback
end

-- Release/ransom rebuild a unit prisoner on a source-faction army.  If the
-- source faction has no army with a free slot (or no longer exists) the
-- record is still discarded: the unit simply never re-enters the map.
local function return_captured_unit(record, reason)
    local unit_key = tostring(record and record.unit_key or "")
    if unit_key == "" then return false end
    local source_faction = nil
    pcall(function() source_faction = cm:get_faction(tostring(record.source_faction or "")) end)
    local general = army_general_with_space(source_faction)
    if not safe_interface(general) then
        log("captured unit " .. unit_key .. " could not rejoin "
            .. tostring(record.source_faction) .. " (" .. tostring(reason)
            .. "); no receiving army, record discarded")
        return false
    end
    local grant_ok, grant_error = pcall(function()
        cm:grant_unit_to_character(cm:char_lookup_str(general), unit_key)
    end)
    if not grant_ok then
        log("captured unit " .. unit_key .. " grant back to "
            .. tostring(record.source_faction) .. " failed: " .. tostring(grant_error))
        return false
    end
    log("captured unit " .. unit_key .. " returned to "
        .. tostring(record.source_faction) .. " (" .. tostring(reason) .. ")")
    return true
end

local function release_record(warden_faction, state, record, incident_key)
    local character = current_character(record.family_member_cqi)
    remove_prisoner_record(state, record)
    local effect = HELD_EFFECTS[record.source_culture]
    if effect then pcall(function() cm:remove_effect_bundle(effect, warden_faction:name()) end) end
    if record.is_unit == true then
        -- A unit prisoner is rebuilt on a source-faction army instead of
        -- restoring a campaign character that never existed.
        return_captured_unit(record, incident_key)
    else
        if safe_interface(character) then record.character_cqi = character:command_queue_index() end
        cross_culture_annex.restore_released_prisoner(record)
    end
    queue_prison_incident(warden_faction, incident_key, character)
    enforce_prisoners(warden_faction, state)
end

local function perform_release(warden_faction, state, record)
    -- Releasing a prisoner is always available and does not consume the shared
    -- once-per-turn interrogation/recruitment/ransom action.
    if not record then return false end
    release_record(warden_faction, state, record, "wyccc_prison_incident_escaped")
    log("released " .. (record.is_unit == true
        and ("captured unit " .. tostring(record.unit_key))
        or ("family member " .. tostring(record.family_member_cqi))))
    return true
end

local function ransom_amount(state, record)
    local base = 1000 + (tonumber(record.rank) or 0) * 100
    return math.floor(base * (RANSOM_MULTIPLIER[state.facilities.ransom] or 0))
end

local function interrogation_values(level)
    level = math.max(0, math.min(MAX_FACILITY_LEVEL, tonumber(level) or 0))
    return tonumber(INTERROGATION_RECRUITMENT_BONUS[level]) or 0,
        tonumber(INTERROGATION_XP_POOL[level]) or 0
end

local function distribute_interrogation_experience(faction, experience_pool)
    experience_pool = math.max(0, math.floor(tonumber(experience_pool) or 0))
    if experience_pool <= 0 or not safe_interface(faction) then return 0, 0 end

    local recipients = {}
    local characters = call_or(faction, "character_list", nil)
    if safe_interface(characters) then
        local count = tonumber(call_or(characters, "num_items", 0)) or 0
        for index = 0, count - 1 do
            local character = call_or(characters, "item_at", nil, index)
            local type_key = character_type_key(character)
            local cqi = tonumber(call_or(character, "command_queue_index", 0)) or 0
            -- A faction character list contains its campaign lords and heroes,
            -- plus temporary colonels used by garrisons/reinforcements.  Only
            -- real lords and heroes participate in the shared experience pool.
            if safe_interface(character) and cqi > 0
                and type_key ~= "" and type_key ~= "colonel"
            then
                recipients[#recipients + 1] = {character = character, cqi = cqi}
            end
        end
    end

    table.sort(recipients, function(left, right) return left.cqi < right.cqi end)
    if #recipients == 0 then return 0, 0 end

    local base_share = math.floor(experience_pool / #recipients)
    local remainder = experience_pool - base_share * #recipients
    local granted = 0
    for index, recipient in ipairs(recipients) do
        -- Allocate the indivisible remainder in stable CQI order so the pool
        -- is fully preserved while every recipient differs by at most 1 XP.
        local share = base_share + (index <= remainder and 1 or 0)
        if share > 0 then
            local ok = pcall(function()
                cm:add_agent_experience(cm:char_lookup_str(recipient.character), share)
            end)
            if ok then granted = granted + share end
        end
    end
    return #recipients, granted
end

local function perform_ransom(warden_faction, state, record)
    if (state.facilities.ransom or 0) < 1 then return false end
    if not record or not consume_prison_action(state, "ransom", record) then return false end
    local amount = ransom_amount(state, record)
    cm:treasury_mod(warden_faction:name(), amount)
    release_record(warden_faction, state, record, "wyccc_prison_incident_ransomed")
    log("ransom released " .. (record.is_unit == true
        and ("captured unit " .. tostring(record.unit_key))
        or ("family member " .. tostring(record.family_member_cqi)))
        .. " for " .. tostring(amount))
    return true
end

local function apply_interrogation_effect_bundle(faction, effect)
    if not safe_interface(faction) or not effect or effect == "" then return false end
    local faction_key = faction:name()
    local function faction_has_bundle()
        local current_faction = nil
        pcall(function() current_faction = cm:get_faction(faction_key) end)
        if not safe_interface(current_faction) then return false end
        local has_bundle = false
        pcall(function() has_bundle = current_faction:has_effect_bundle(effect) == true end)
        return has_bundle
    end
    if faction_has_bundle() then
        log("interrogation effect bundle already active; refreshing duration: faction="
            .. tostring(faction_key) .. ", bundle=" .. tostring(effect))
    end

    local apply_ok, apply_error = pcall(function()
        cm:apply_effect_bundle(
            effect, faction_key, cross_culture_annex.interrogation_effect_duration
        )
    end)
    if not apply_ok then
        log("interrogation effect bundle apply failed: faction=" .. tostring(faction_key)
            .. ", bundle=" .. tostring(effect) .. ", error=" .. tostring(apply_error))
        return false
    end

    -- Effect application is command-queued.  Confirm it after the UI action
    -- stack has unwound and retry once before reporting a real failure.
    local function verify_bundle(attempt)
        if faction_has_bundle() then
            log("interrogation effect bundle confirmed: faction=" .. tostring(faction_key)
                .. ", bundle=" .. tostring(effect))
            return
        end
        if attempt == 3 then
            pcall(function()
                cm:apply_effect_bundle(
                    effect, faction_key, cross_culture_annex.interrogation_effect_duration
                )
            end)
        end
        if attempt < 6 then
            cm:callback(function() verify_bundle(attempt + 1) end, 0.2)
        else
            log("interrogation effect bundle not confirmed after apply: faction="
                .. tostring(faction_key) .. ", bundle=" .. tostring(effect))
        end
    end
    cm:callback(function() verify_bundle(1) end, 0.2)
    return true
end

local function grant_interrogation(faction, state, record)
    if (state.facilities.interrogation or 0) < 1 then return false end
    if not record or not leader_actions_unlocked(state, record) then return false end
    if not record or not consume_prison_action(state, "interrogate", record) then return false end
    local effect = INTERROGATION_EFFECT_BY_CULTURE[record.source_culture]
    -- The recruitment progress is the core interrogation result and is
    -- available even for a culture without a bespoke military effect bundle.
    -- Apply the optional culture reward when one exists, without making that
    -- reward a prerequisite for the action.
    local effect_applied = apply_interrogation_effect_bundle(faction, effect)
    local recruitment_bonus, experience_pool = interrogation_values(
        state.facilities.interrogation
    )
    local recipient_count, granted_experience = distribute_interrogation_experience(
        faction, experience_pool
    )
    local previous_bonus = tonumber(record.recruitment_bonus) or 0
    record.recruitment_bonus = math.min(100,
        previous_bonus + recruitment_bonus)
    state.interrogated_effects[prisoner_record_key(record)] = effect_applied and effect or true
    queue_prison_incident(
        faction,
        "wyccc_prison_incident_interrogated",
        current_character(record.family_member_cqi)
    )
    log("interrogated family member " .. tostring(record.family_member_cqi)
        .. "; recruitment bonus=" .. tostring(record.recruitment_bonus) .. "%"
        .. "; experience pool=" .. tostring(experience_pool)
        .. "; recipients=" .. tostring(recipient_count)
        .. "; granted=" .. tostring(granted_experience)
        .. "; culture_effect=" .. tostring(effect or "none")
        .. "; effect_applied=" .. tostring(effect_applied))
    return true
end

local function complete_recruit(warden_faction, state, record, created_cqi, options)
    local character = cm:get_character_by_cqi(created_cqi or record.character_cqi)
    local role = prisoner_role(record, character)
    if not safe_interface(character)
        or (role == "lord" and not character:has_military_force())
        or (role ~= "lord" and role ~= "hero")
    then
        log("recruit completion rejected: character/role unavailable; family_member_cqi="
            .. tostring(record and record.family_member_cqi or 0))
        return false
    end
    local expected_subtype = tostring(record and record.subtype or "")
    local actual_subtype = tostring(call_or(character, "character_subtype_key", ""))
    local actual_type = character_type_key(character)
    if expected_subtype == "" or actual_subtype ~= expected_subtype
        or (role == "lord" and actual_type ~= "general")
        or (role == "hero" and actual_type ~= tostring(record.character_type_key or ""))
    then
        log("recruit completion rejected: expected subtype=" .. expected_subtype
            .. ", actual subtype=" .. actual_subtype .. ", agent type=" .. actual_type)
        return false
    end
    local current_owner = nil
    pcall(function() current_owner = character:faction() end)
    if not safe_interface(current_owner) or current_owner:name() ~= warden_faction:name() then
        -- Creation and same-faction restoration must both resolve to a player
        -- character before any prison state or character properties change.
        log("recruit completion rejected: restored character owner is "
            .. tostring(safe_interface(current_owner) and current_owner:name() or "unavailable")
            .. ", expected " .. tostring(warden_faction:name()))
        return false
    end
    -- Apply the reusable compensation trait after direct ownership restoration.
    -- record.source_culture keeps the original culture needed for the
    -- non-native comparison.
    add_non_native_recruitment_trait(warden_faction, record, character)
    local art_set = tostring(cross_culture_annex.art_set_by_subtype[expected_subtype] or "")
    if art_set ~= "" then
        local character_cqi = character:command_queue_index()
        for _, delay in ipairs({0.2, 1}) do
            cm:callback(function()
                cross_culture_annex.apply_recruited_pool_art_set(
                    character_cqi, expected_subtype, art_set, "recruited prisoner"
                )
            end, delay)
        end
    end
    if wyccc_base and type(wyccc_base.rename_character) == "function" then
        wyccc_base.rename_character(
            character,
            tostring(record.subtype or call_or(character, "character_subtype_key", ""))
        )
    else
        log("shared character name API unavailable after prisoner recruitment: subtype="
            .. tostring(record.subtype or ""))
    end
    remove_prisoner_record(state, record)
    local effect = HELD_EFFECTS[record.source_culture]
    if effect then pcall(function() cm:remove_effect_bundle(effect, warden_faction:name()) end) end
    if role == "lord" then
        pcall(function() cm:remove_all_units_from_general(character) end)
    end
    set_immortality(character, true)
    enforce_prisoners(warden_faction, state)
    if options and options.suppress_feedback == true then
        -- The disposition dilemma is already the visible feedback for its
        -- forced vassal/recruit branch.
    elseif record.is_faction_leader == true then
        -- A leader recruitment uses its disposition dilemma as the success
        -- feedback.  Do not queue the separate full-screen success incident at
        -- the same time: two blocking event panels competing for one MoviePlayer
        -- caused the intervention to lock behind appoint_new_general and crash.
        queue_leader_disposition_event(
            warden_faction, state, record,
            current_character(record.family_member_cqi) or character
        )
    else
        -- Ordinary prisoners still use the dedicated success event.
        queue_prison_incident(warden_faction, "wyccc_prison_incident_recruited", character)
    end
    log("recruited prisoner as " .. tostring(role) .. " character "
        .. tostring(created_cqi or record.character_cqi))
    return true
end

function cross_culture_annex.rollback_failed_recruitment(
    warden_faction, state, record, on_complete
)
    local completed = false
    local family_member_cqi = tonumber(record and record.family_member_cqi) or 0
    local next_wound_attempt = 1

    local function finish(confirmed)
        if completed then return end
        completed = true
        if safe_interface(warden_faction) and state then
            enforce_prisoners(warden_faction, state)
        end
        log("recruit failure rollback " .. (confirmed and "confirmed" or "ended without confirmation")
            .. "; family_member_cqi=" .. tostring(family_member_cqi))
        if type(on_complete) == "function" then
            pcall(on_complete)
        end
    end

    if not safe_interface(warden_faction) or not state or not record
        or family_member_cqi <= 0
    then
        finish(false)
        return
    end

    local function attempt(attempt_number)
        local character = current_character(family_member_cqi)
        if safe_interface(character) then
            record.character_cqi = tonumber(call_or(
                character, "command_queue_index", record.character_cqi
            )) or record.character_cqi
            set_immortality(character, true)
            if call_or(character, "is_wounded", false) == true then
                finish(true)
                return
            end

            -- A failed existing-general transfer can leave the restored lord
            -- commanding a source-faction army in the player's territory. Wound
            -- the exact original family member again; the engine then removes
            -- that transient force instead of leaving a false battle contact.
            if attempt_number >= next_wound_attempt then
                wound_for_detention(character)
                next_wound_attempt = attempt_number + 10
            end
        end

        if attempt_number < cross_culture_annex.recruit_failure_rollback_max_attempts then
            cm:callback(function()
                attempt(attempt_number + 1)
            end, 0.1)
        else
            finish(false)
        end
    end

    attempt(1)
end

local function recruit_failure(warden_faction, state, record, reason)
    log("recruit failed: " .. tostring(reason)
        .. "; family_member_cqi=" .. tostring(record and record.family_member_cqi or 0))
    queue_prison_incident(
        warden_faction,
        "wyccc_prison_incident_recruit_failed",
        record and current_character(record.family_member_cqi) or nil
    )
    return false
end

local function append_recruit_region(regions, seen, region)
    if not safe_interface(region) then return end
    local key = nil
    pcall(function() key = region:name() end)
    if key and key ~= "" and not seen[key] then
        seen[key] = true
        regions[#regions + 1] = region
    end
end

local function recruit_spawn_location(warden_faction, source_faction, spawning_faction)
    local regions = {}
    local seen = {}
    local location_faction = safe_interface(spawning_faction) and spawning_faction or source_faction

    -- Prefer the player's territory: a defeated/rebel source faction commonly
    -- has neither a home region nor a field leader, which was the silent exit
    -- responsible for successful rolls doing nothing.
    pcall(function()
        if warden_faction:has_home_region() then
            append_recruit_region(regions, seen, warden_faction:home_region())
        end
    end)
    pcall(function()
        local leader = warden_faction:faction_leader()
        if safe_interface(leader) and leader:has_region() then
            append_recruit_region(regions, seen, leader:region())
        end
    end)
    pcall(function()
        local list = warden_faction:region_list()
        if list:num_items() > 0 then
            append_recruit_region(regions, seen, list:item_at(0))
        end
    end)
    pcall(function()
        if source_faction:has_home_region() then
            append_recruit_region(regions, seen, source_faction:home_region())
        end
    end)
    pcall(function()
        local leader = source_faction:faction_leader()
        if safe_interface(leader) and leader:has_region() then
            append_recruit_region(regions, seen, leader:region())
        end
    end)

    for _, region in ipairs(regions) do
        local x, y = nil, nil
        pcall(function()
            x, y = cm:find_valid_spawn_location_for_character_from_settlement(
                location_faction:name(), region:name(), false, true, 5
            )
        end)
        if tonumber(x) and tonumber(y) and x >= 0 and y >= 0 then
            return region, x, y
        end
    end
    return nil, nil, nil
end

-- Unit recruitment keeps the same facility/once-per-turn/chance gates as
-- character recruitment, then rebuilds the captive on a warden army's roster.
-- There is no family member to convalesce, so success/failure never touches
-- the character rollback machinery.
local function perform_unit_recruit(warden_faction, state, record, options)
    options = type(options) == "table" and options or {}
    local forced = options.forced == true
    if not forced and (state.facilities.recruitment or 0) < 1 then return false end
    if not forced and not prison_action_available(state) then return false end
    if not forced and not leader_actions_unlocked(state, record) then return false end
    local unit_key = tostring(record.unit_key or "")
    if unit_key == "" then
        return recruit_failure(warden_faction, state, record, "captured unit key unavailable")
    end
    if not forced and not consume_prison_action(state, "recruit", record) then return false end
    if not forced then
        local chance = recruitment_chance(state, record)
        if cm:random_number(100) > chance then
            return recruit_failure(warden_faction, state, record,
                "random roll above " .. tostring(chance) .. "%")
        end
    end
    local general = army_general_with_space(warden_faction)
    if not safe_interface(general) then
        return recruit_failure(warden_faction, state, record,
            "no warden army has a free roster slot")
    end
    local grant_ok, grant_error = pcall(function()
        cm:grant_unit_to_character(cm:char_lookup_str(general), unit_key)
    end)
    if not grant_ok then
        return recruit_failure(warden_faction, state, record,
            "unit grant failed: " .. tostring(grant_error))
    end
    remove_prisoner_record(state, record)
    local effect = HELD_EFFECTS[record.source_culture]
    if effect then pcall(function() cm:remove_effect_bundle(effect, warden_faction:name()) end) end
    enforce_prisoners(warden_faction, state)
    if options.suppress_feedback ~= true then
        queue_prison_incident(warden_faction, "wyccc_prison_incident_recruited", nil)
    end
    log("recruited captured unit " .. unit_key .. " into a warden army; source="
        .. tostring(record.source_faction))
    if type(options.on_complete) == "function" then
        pcall(options.on_complete, true, "")
    end
    return true
end

perform_recruit = function(warden_faction, state, record, options)
    options = type(options) == "table" and options or {}
    local forced = options.forced == true
    local recruitment_restore_started = false
    if not record then return false end
    if record.is_unit == true then
        return perform_unit_recruit(warden_faction, state, record, options)
    end

    local function deliver_failure(reason)
        if options.suppress_feedback == true then
            log("forced recruit failed: " .. tostring(reason)
                .. "; family_member_cqi=" .. tostring(record.family_member_cqi))
        else
            recruit_failure(warden_faction, state, record, reason)
        end
        if type(options.on_complete) == "function" then
            pcall(options.on_complete, false, reason)
        end
    end

    local function report_failure(reason)
        if recruitment_restore_started then
            cross_culture_annex.rollback_failed_recruitment(
                warden_faction, state, record, function()
                deliver_failure(reason)
            end)
        else
            deliver_failure(reason)
        end
        return false
    end
    if not forced and (state.facilities.recruitment or 0) < 1 then return false end
    if not forced and not prison_action_available(state) then return false end
    if not forced and not leader_actions_unlocked(state, record) then return false end
    local key = warden_faction:name() .. ":" .. tostring(record.family_member_cqi)
    if recruit_pending[key] then
        return forced and report_failure("another recruitment is already pending") or false
    end
    -- Repair old saved records before consuming the once-per-turn action or
    -- rolling recruitment.  A 100% roll must not be spent on missing migration
    -- data that can be recovered from the persistent family member/portrait.
    if recover_prisoner_subtype(record) == "" then
        return report_failure("defeated prisoner subtype unavailable before recruitment")
    end
    if not forced and not consume_prison_action(state, "recruit", record) then return false end
    if not forced then
        local chance = recruitment_chance(state, record)
        if cm:random_number(100) > chance then
            return report_failure("random roll above " .. tostring(chance) .. "%")
        end
    end
    local character = current_character(record.family_member_cqi)
    local role = prisoner_role(record, character)
    if role == "hero" then
        local subtype = recover_prisoner_subtype(record)
        local agent_type = tostring(record.character_type_key or "")
        if agent_type == "" then agent_type = character_type_key(character) end
        if subtype == "" or agent_type == "" or agent_type == "general" then
            return report_failure("hero subtype or agent type unavailable after successful roll")
        end

        -- Campaign scripting has no existing-general equivalent for embedded
        -- heroes. Keep the detained original convalescing and rebuild the same
        -- subtype/agent class directly for the warden at a valid home position.
        -- This avoids converting a noble/wizard/etc. into an army commander.
        local source = nil
        if safe_interface(character) then
            pcall(function() source = character:faction() end)
        end
        if not safe_interface(source) then
            pcall(function() source = cm:get_faction(record.source_faction) end)
        end
        local region, x, y = recruit_spawn_location(
            warden_faction, source, warden_faction
        )
        if not safe_interface(region) or not x or not y then
            return report_failure("no valid spawn location for recruited hero")
        end

        local recruited_hero = nil
        local create_ok, create_error = pcall(function()
            recruited_hero = cm:create_agent(
                warden_faction:name(), agent_type, subtype, x, y, true
            )
        end)
        if not create_ok or not safe_interface(recruited_hero) then
            return report_failure("hero reconstruction failed: " .. tostring(create_error or "engine rejected create_agent"))
        end
        pcall(function()
            cm:add_agent_experience(
                cm:char_lookup_str(recruited_hero),
                math.max(1, tonumber(record.rank) or 1),
                true
            )
        end)
        local created_cqi = tonumber(call_or(
            recruited_hero, "command_queue_index", 0
        )) or 0
        if created_cqi <= 0
            or not complete_recruit(warden_faction, state, record, created_cqi, options)
        then
            return report_failure("created hero could not complete ownership registration")
        end
        if type(options.on_complete) == "function" then
            pcall(options.on_complete, true, "")
        end
        return true
    end
    if role ~= "lord" then
        return report_failure("prisoner role unavailable after successful roll")
    end

    local current_owner = call_or(character, "faction", nil)
    if options.replace_original_leader == true
        or not safe_interface(current_owner)
        or current_owner:name() ~= warden_faction:name()
    then
        if options.replace_original_leader == true and record.is_faction_leader ~= true then
            return report_failure("vassal replacement requested for a non-leader prisoner")
        end
        local subtype = recover_prisoner_subtype(record)
        if subtype == "" then
            return report_failure("captured leader subtype unavailable for replacement")
        end

        local source_faction = nil
        pcall(function() source_faction = cm:get_faction(record.source_faction) end)
        local region, x, y = recruit_spawn_location(
            warden_faction, source_faction, warden_faction
        )
        if not safe_interface(region) or not x or not y then
            return report_failure("no valid spawn location for replacement leader")
        end

        local original_family_member_cqi = tonumber(record.family_member_cqi) or 0
        local pending_key = key
        local pending_token = {}
        recruit_pending[pending_key] = pending_token
        local existing_family_members = {}
        local before = warden_faction:character_list()
        for i = 0, before:num_items() - 1 do
            local family_member = call_or(before:item_at(i), "family_member", nil)
            local cqi = tonumber(call_or(family_member, "command_queue_index", 0)) or 0
            if cqi > 0 then existing_family_members[cqi] = true end
        end

        local function finish_replacement_failure(reason)
            if recruit_pending[pending_key] ~= pending_token then return false end
            recruit_pending[pending_key] = nil
            return report_failure(reason)
        end

        local function finish_replacement_success(created_cqi)
            if recruit_pending[pending_key] ~= pending_token then return false end
            local created = nil
            pcall(function() created = cm:get_character_by_cqi(created_cqi) end)
            local created_family_member = call_or(created, "family_member", nil)
            local created_family_member_cqi = tonumber(call_or(
                created_family_member, "command_queue_index", 0
            )) or 0
            local created_owner = call_or(created, "faction", nil)
            if not safe_interface(created)
                or not safe_interface(created_owner)
                or created_owner:name() ~= warden_faction:name()
                or call_or(created, "character_subtype_key", "") ~= subtype
                or created_family_member_cqi <= 0
                or created_family_member_cqi == original_family_member_cqi
                or existing_family_members[created_family_member_cqi]
            then
                return finish_replacement_failure(
                    "replacement leader identity or ownership validation failed"
                )
            end

            pcall(function()
                cm:add_agent_experience(
                    cm:char_lookup_str(created),
                    math.max(1, tonumber(record.rank) or 1),
                    true
                )
            end)
            if not complete_recruit(
                warden_faction, state, record, created_cqi, options
            ) then
                return finish_replacement_failure(
                    "replacement leader could not complete ownership registration"
                )
            end

            recruit_pending[pending_key] = nil
            if safe_interface(current_character(original_family_member_cqi))
                and not cross_culture_annex.permanently_kill_original_leader(record, created)
            then
                log("vassal leader replacement created the player character but could not schedule the original kill")
                if type(options.on_complete) == "function" then
                    pcall(options.on_complete, false, "original permanent kill was not scheduled")
                end
                return false
            end
            if type(options.on_complete) == "function" then
                pcall(options.on_complete, true, "")
            end
            log("recruited lord replacement created: original_fm_cqi="
                .. tostring(original_family_member_cqi)
                .. ", replacement_fm_cqi=" .. tostring(created_family_member_cqi)
                .. ", subtype=" .. subtype)
            return true
        end

        log("recruited lord replacement spawning for player: original_fm_cqi="
            .. tostring(original_family_member_cqi) .. ", subtype=" .. subtype
            .. ", region=" .. tostring(region:name()))
        local create_ok, create_error = pcall(function()
            cm:create_force_with_general(
                warden_faction:name(), "", region:name(), x, y,
                "general", subtype,
                tostring(record.forename or ""), "", tostring(record.surname or ""), "",
                false,
                nil,
                false,
                true
            )
        end)
        if not create_ok then
            return finish_replacement_failure(
                "replacement leader creation failed: " .. tostring(create_error)
            )
        end
        -- Native force-created callbacks scan by coordinates and can return an
        -- older lord standing at the same point. Wait for a NEW family member
        -- of the exact subtype after the creation transaction has settled.
        local function settle_replacement(attempt)
            if recruit_pending[pending_key] ~= pending_token then return end
            local candidate_cqi = nil
            local candidates = 0
            local characters = warden_faction:character_list()
            for i = 0, characters:num_items() - 1 do
                local candidate = characters:item_at(i)
                local family_member = call_or(candidate, "family_member", nil)
                local fm_cqi = tonumber(call_or(family_member, "command_queue_index", 0)) or 0
                if fm_cqi > 0 and fm_cqi ~= original_family_member_cqi
                    and not existing_family_members[fm_cqi]
                    and call_or(candidate, "character_subtype_key", "") == subtype
                    and call_or(candidate, "has_military_force", false) == true
                then
                    candidates = candidates + 1
                    candidate_cqi = tonumber(call_or(candidate, "command_queue_index", 0)) or 0
                end
            end
            if candidates == 1 then
                finish_replacement_success(candidate_cqi)
            elseif attempt < 50 then
                cm:callback(function() settle_replacement(attempt + 1) end, 0.1)
            else
                finish_replacement_failure("new lord identity did not settle uniquely")
            end
        end
        cm:callback(function() settle_replacement(1) end, 0.1)
        return true
    end

    local stored_character_cqi = tonumber(record.character_cqi) or 0
    if safe_interface(character) then
        stored_character_cqi = character:command_queue_index()
        record.character_cqi = stored_character_cqi
        set_immortality(character, true)
    end
    -- Only an existing character already owned by the warden reaches this
    -- path. Foreign and unavailable lords use validated reconstruction above.
    if stored_character_cqi <= 0 then
        return report_failure("stored character CQI unavailable after successful roll")
    end
    local restore_ok, restore_error = pcall(function()
        cm:stop_character_convalescing(stored_character_cqi)
    end)
    if not restore_ok then
        return report_failure("failed to stop character convalescing: " .. tostring(restore_error))
    end
    recruitment_restore_started = true
    local pending_key = warden_faction:name() .. ":" .. tostring(record.family_member_cqi)
    local pending_token = {}
    recruit_pending[pending_key] = pending_token

    local function finish_failure(reason)
        if recruit_pending[pending_key] ~= pending_token then return false end
        recruit_pending[pending_key] = nil
        return report_failure(reason)
    end

    local function finish_success(created_cqi)
        if recruit_pending[pending_key] ~= pending_token then return false end
        if complete_recruit(warden_faction, state, record, created_cqi, options) then
            recruit_pending[pending_key] = nil
            if type(options.on_complete) == "function" then
                pcall(options.on_complete, true, "")
            end
            return true
        end
        return finish_failure("force was created but final ownership transfer failed")
    end

    -- Convalescence and force creation are command-queued. Resolve by family
    -- member throughout; a coordinate-based callback CQI is not identity proof.
    local force_requested = false
    local function settle_original(attempt)
        if recruit_pending[pending_key] ~= pending_token then return end
        local restored = cross_culture_annex.exact_prisoner_character(record)
        if safe_interface(restored) and call_or(restored, "is_wounded", true) ~= true then
            local owner = call_or(restored, "faction", nil)
            if not safe_interface(owner) or owner:name() ~= warden_faction:name() then
                finish_failure("original prisoner ownership changed during restoration")
                return
            end
            if cross_culture_annex.released_lord_has_exact_force(record, restored) then
                finish_success(restored:command_queue_index())
                return
            end
            if not force_requested then
                local region, x, y = recruit_spawn_location(warden_faction, owner, warden_faction)
                if not safe_interface(region) or not x or not y then
                    finish_failure("no valid spawn location in warden territory")
                    return
                end
                force_requested = true
                local ok, err = pcall(function()
                    cm:create_force_with_existing_general(
                        cm:char_lookup_str(restored), warden_faction:name(), RECRUIT_UNIT,
                        region:name(), x, y, nil
                    )
                end)
                if not ok then
                    finish_failure("original force creation failed: " .. tostring(err))
                    return
                end
            end
        end
        if attempt < 50 then
            cm:callback(function() settle_original(attempt + 1) end, 0.1)
        else
            finish_failure("original prisoner restoration timed out")
        end
    end
    cm:callback(function() settle_original(1) end, 0.1)
    return true
end

local function upgrade(faction, facility)
    local state = get_state(faction:name())
    local level = state.facilities[facility] or 0
    if level >= MAX_FACILITY_LEVEL then return end
    local cost = FACILITY_COSTS[level + 1]
    if faction:treasury() < cost then return end
    cm:treasury_mod(faction:name(), -cost)
    state.facilities[facility] = level + 1
    enforce_prisoners(faction, state)
    log("facility " .. facility .. " upgraded to " .. tostring(level + 1))
end

local function clear_prisoner_effects(faction)
    for effect in pairs(HELD_EFFECT_LIST) do
        pcall(function() cm:remove_effect_bundle(effect, faction:name()) end)
    end
end

local function snapshot_pending_battle()
    local character_unit_map = {}
    pending_battle_snapshot = {
        attackers = {},
        defenders = {},
        warden_key = "",
        warden_side = ""
    }
    -- Reset the previous battle before querying any character/unit wrappers.
    -- Quest participants are temporary and must never enter the identity map.
    local quest_battle = call_or(cm, "pending_battle_cache_is_quest_battle", false) == true
    core:svr_save_bool(SVR_QUEST_BATTLE, quest_battle)
    core:svr_save_bool(SVR_DETECTED, false)
    core:svr_save_bool(SVR_CAGE_KILLED, false)
    core:svr_save_bool(SVR_CAGE_WINDOW_EXPIRED, false)
    core:svr_save_bool("wyccc_prison_battle_capture_committed", false)
    core:svr_save_bool("wyccc_prison_battle_target_is_commanding", false)
    for _, key in ipairs({
        SVR_TARGET_FACTION, SVR_TARGET_ARMY_INDEX, SVR_TARGET_ARMY_ID,
        SVR_TARGET_UNIT_ID, SVR_WARDEN_FACTION, SVR_WARDEN_SIDE,
        "wyccc_prison_battle_target_unit_index", "wyccc_prison_battle_target_unit_key",
        "wyccc_prison_battle_character_unit_map"
    }) do
        core:svr_save_string(key, "")
    end
    if quest_battle then
        log("quest battle capture skipped before campaign identity scan")
        return
    end
    local warden_key = ""
    local warden_side = ""
    local faction = player_warden_faction()
    if faction then
        local faction_key = call_or(faction, "name", "")
        local is_attacker = false
        local is_defender = false
        if faction_key ~= "" then
            pcall(function()
                is_attacker = cm:pending_battle_cache_faction_is_attacker(faction_key) == true
            end)
            if not is_attacker then
                pcall(function()
                    is_defender = cm:pending_battle_cache_faction_is_defender(faction_key) == true
                end)
            end
        end
        if is_attacker then
            warden_key = faction_key
            warden_side = "attacker"
        elseif is_defender then
            warden_key = faction_key
            warden_side = "defender"
        end
    end
    pending_battle_snapshot.warden_key = warden_key
    pending_battle_snapshot.warden_side = warden_side
    core:svr_save_string(SVR_WARDEN_FACTION, warden_key)
    core:svr_save_string(SVR_WARDEN_SIDE, warden_side)
    if warden_key == "" then
        debug_log("pending battle ignored: local player prison faction is not participating")
        return
    end

    -- Build an identity from the primitive values that PendingBattle exposes
    -- even when get_character_by_cqi() has already returned a null wrapper.
    -- Battle result callbacks can destroy the transient character object
    -- before the capture listener runs, but these values remain stable in the
    -- cache and are sufficient to create our independent prisoner record.
    local function primitive_identity(family_member_cqi, char_cqi, faction_key, subtype)
        local source_faction = nil
        if faction_key and faction_key ~= "" then
            pcall(function() source_faction = cm:get_faction(faction_key) end)
        end
        return {
            family_member_cqi = tonumber(family_member_cqi) or 0,
            character_cqi = tonumber(char_cqi) or 0,
            source_faction = faction_key or "",
            source_culture = call_or(source_faction, "culture", ""),
            source_subculture = call_or(source_faction, "subculture", ""),
            subtype = subtype or "",
            rank = 1,
            forename = "",
            surname = "",
            portrait_path = portrait_for_identity(subtype, char_cqi, faction_key) or "",
            was_immortal = false,
            -- The cage ability is DB-restricted to commander targets.  Keep
            -- that authoritative marker when the live character wrapper is
            -- unavailable, instead of rejecting a valid defeated commander.
            is_general = true,
            character_type_key = "",
            role = faction_leader_status(source_faction, nil, family_member_cqi) == true and "lord" or "",
            is_faction_leader = faction_leader_status(source_faction, nil, family_member_cqi)
        }
    end

    local function snapshot_side(
        side_key, destination, count, getter, fm_getter,
        subtype_getter, faction_getter, unit_count_getter, unit_getter
    )
        local function snapshot_army(i)
            local char_cqi, mf_cqi, faction_key = 0, 0, ""
            pcall(function()
                char_cqi, mf_cqi, faction_key = getter(cm, i)
            end)
            -- Use the dedicated cache accessors as a second source.  The
            -- combined getter above is the normal path; these are important
            -- on result transitions where one of the returned values is
            -- temporarily blank.
            if (faction_key == nil or faction_key == "") and faction_getter then
                pcall(function() faction_key = faction_getter(cm, i) or "" end)
            end
            -- Reject armed citizenry before opening its generated commander or
            -- any unit's associated_character/family_member interfaces.
            if cross_culture_annex.is_garrison_force_cqi(mf_cqi) then
                destination[i] = {mf_cqi = mf_cqi, faction_key = faction_key,
                    family_member_cqi = 0, character_units = {}}
                log("settlement garrison excluded from capture snapshot; side="
                    .. tostring(side_key) .. ", army=" .. tostring(i) .. ", mf_cqi=" .. tostring(mf_cqi))
                return
            end
            local cached_subtype = ""
            if subtype_getter then
                pcall(function() cached_subtype = subtype_getter(cm, i) or "" end)
            end
            local family_member_cqi = 0
            pcall(function()
                family_member_cqi = fm_getter(cm, i) or 0
            end)
            local character = nil
            pcall(function() character = cm:get_character_by_cqi(char_cqi) end)
            if cross_culture_annex.is_garrison_character(character) then return end
            if safe_interface(character) then
                if family_member_cqi <= 0 then
                    pcall(function() family_member_cqi = character:family_member():command_queue_index() end)
                end
            end
            local identity = snapshot_character_identity(
                character, call_or(character, "family_member", nil), family_member_cqi
            )
            if type(identity) ~= "table" then
                identity = primitive_identity(
                    family_member_cqi, char_cqi, faction_key, cached_subtype
                )
                debug_log("pending identity fallback used; faction="
                    .. tostring(faction_key) .. ", subtype=" .. tostring(cached_subtype)
                    .. ", fm_cqi=" .. tostring(family_member_cqi))
            else
                -- Fill holes in a partially readable wrapper with cache
                -- primitives, so recruitment/UI still retain the source
                -- faction and subtype after the battle destroys the wrapper.
                local fallback = primitive_identity(
                    family_member_cqi, char_cqi, faction_key, cached_subtype
                )
                for key, value in pairs(fallback) do
                    if identity[key] == nil or identity[key] == "" then
                        identity[key] = value
                    end
                end
            end
            destination[i] = {
                char_cqi = char_cqi,
                mf_cqi = mf_cqi,
                faction_key = faction_key,
                family_member_cqi = family_member_cqi,
                identity = identity,
                character_units = {}
            }
            local unit_count = 0
            if unit_count_getter then
                pcall(function() unit_count = unit_count_getter(cm, i) or 0 end)
            end
            for unit_index = 1, tonumber(unit_count) or 0 do
                local unit_cqi, unit_key = 0, ""
                if unit_getter then
                    pcall(function()
                        unit_cqi, unit_key = unit_getter(cm, i, unit_index)
                    end)
                end
                local campaign_unit = nil
                if tonumber(unit_cqi) and tonumber(unit_cqi) > 0 then
                    pcall(function()
                        campaign_unit = cm:model():unit_for_command_queue_index(unit_cqi)
                    end)
                end
                local unit_force = call_or(campaign_unit, "military_force", nil)
                local unit_is_garrison = safe_interface(unit_force)
                    and call_or(unit_force, "is_armed_citizenry", false) == true
                local associated_character = nil
                if not unit_is_garrison then
                    associated_character = call_or(campaign_unit, "associated_character", nil)
                    if not safe_interface(associated_character) then
                        associated_character = call_or(campaign_unit, "unit_commander", nil)
                    end
                end
                local has_character_identity = false
                if safe_interface(associated_character)
                    and not cross_culture_annex.is_garrison_character(associated_character)
                then
                    local associated_family_member = call_or(
                        associated_character, "family_member", nil
                    )
                    local associated_fm_cqi = tonumber(call_or(
                        associated_family_member, "command_queue_index", 0
                    )) or 0
                    if associated_fm_cqi > 0 then
                        has_character_identity = true
                        local associated_identity = snapshot_character_identity(
                            associated_character,
                            associated_family_member,
                            associated_fm_cqi
                        )
                        destination[i].character_units[unit_index] = {
                            unit_cqi = tonumber(unit_cqi) or 0,
                            unit_key = tostring(unit_key or ""),
                            family_member_cqi = associated_fm_cqi,
                            identity = associated_identity
                        }
                        character_unit_map[#character_unit_map + 1] = table.concat({
                            side_key,
                            tostring(i),
                            tostring(mf_cqi or 0),
                            tostring(faction_key or ""),
                            tostring(unit_index),
                            tostring(unit_cqi or 0),
                            tostring(unit_key or ""),
                            tostring(associated_fm_cqi),
                            type(associated_identity) == "table"
                                and associated_identity.was_immortal == true and "1" or "0"
                        }, "|")
                        debug_log("pending character-unit map; side=" .. tostring(side_key)
                            .. ", army=" .. tostring(i)
                            .. ", unit_index=" .. tostring(unit_index)
                            .. ", unit_cqi=" .. tostring(unit_cqi)
                            .. ", unit_key=" .. tostring(unit_key)
                            .. ", fm_cqi=" .. tostring(associated_fm_cqi))
                    end
                end
                if not has_character_identity and not unit_is_garrison
                    and tonumber(unit_cqi) and tonumber(unit_cqi) > 0
                    and not (
                        safe_interface(associated_character)
                        and cross_culture_annex.is_garrison_character(associated_character)
                    )
                then
                    -- Commander-class roster units without a campaign
                    -- character (grant_unit_to_character bosses such as
                    -- psw_tfmw_*_boss_*) can be caged and killed, but have no
                    -- family member. Record an fm=0 bridge entry so the
                    -- result path can imprison the unit itself.  The battle
                    -- DB flag already rejects non-commander targets, so an
                    -- exact match here is never an ordinary troop.
                    destination[i].character_units[unit_index] = {
                        unit_cqi = tonumber(unit_cqi) or 0,
                        unit_key = tostring(unit_key or ""),
                        family_member_cqi = 0,
                        is_unit = true
                    }
                    character_unit_map[#character_unit_map + 1] = table.concat({
                        side_key,
                        tostring(i),
                        tostring(mf_cqi or 0),
                        tostring(faction_key or ""),
                        tostring(unit_index),
                        tostring(unit_cqi or 0),
                        tostring(unit_key or ""),
                        "0",
                        "0"
                    }, "|")
                    debug_log("pending roster-unit map; side=" .. tostring(side_key)
                        .. ", army=" .. tostring(i)
                        .. ", unit_index=" .. tostring(unit_index)
                        .. ", unit_cqi=" .. tostring(unit_cqi)
                        .. ", unit_key=" .. tostring(unit_key))
                end
            end
            debug_log("pending snapshot entry side_count_index=" .. tostring(i)
                .. ", faction=" .. tostring(faction_key)
                .. ", char_cqi=" .. tostring(char_cqi)
                .. ", mf_cqi=" .. tostring(mf_cqi)
                .. ", fm_cqi=" .. tostring(family_member_cqi))
        end
        for i = 1, count do snapshot_army(i) end
    end
    snapshot_side(
        "attacker",
        pending_battle_snapshot.attackers,
        cm:pending_battle_cache_num_attackers(),
        cm.pending_battle_cache_get_attacker,
        cm.pending_battle_cache_get_attacker_fm_cqi,
        cm.pending_battle_cache_get_attacker_subtype,
        cm.pending_battle_cache_get_attacker_faction_name,
        cm.pending_battle_cache_num_attacker_units,
        cm.pending_battle_cache_get_attacker_unit
    )
    snapshot_side(
        "defender",
        pending_battle_snapshot.defenders,
        cm:pending_battle_cache_num_defenders(),
        cm.pending_battle_cache_get_defender,
        cm.pending_battle_cache_get_defender_fm_cqi,
        cm.pending_battle_cache_get_defender_subtype,
        cm.pending_battle_cache_get_defender_faction_name,
        cm.pending_battle_cache_num_defender_units,
        cm.pending_battle_cache_get_defender_unit
    )
    core:svr_save_string(
        "wyccc_prison_battle_character_unit_map",
        table.concat(character_unit_map, ";")
    )
    log("pending battle identity snapshot saved for " .. tostring(warden_key))
end

-- Campaign Lua is recreated before the post-battle result events fire. During
-- that first tick, is_pending_battle_active() can still report an unfought
-- pending battle even though battle Lua has already returned exact cage data.
-- Treat those values as the authoritative handoff and never erase them by
-- rebuilding the pre-battle snapshot.
local function battle_bridge_has_capture_result()
    if cross_culture_annex.is_quest_battle() then return false, false, false end
    local detected = false
    local cage_killed = false
    pcall(function() detected = core:svr_load_bool(SVR_DETECTED) == true end)
    pcall(function() cage_killed = core:svr_load_bool(SVR_CAGE_KILLED) == true end)
    return detected or cage_killed, detected, cage_killed
end

local function prepare_returned_cage_target()
    local _, detected, cage_killed = battle_bridge_has_capture_result()
    if not detected or not cage_killed then return false end
    if not cross_culture_annex.has_persistent_cage_target() then return false end

    local target_faction = core:svr_load_string(SVR_TARGET_FACTION) or ""
    local army_index = tonumber(
        core:svr_load_string(SVR_TARGET_ARMY_INDEX) or "0"
    ) or 0
    local army_id = core:svr_load_string(SVR_TARGET_ARMY_ID) or ""
    local unit_index = tonumber(core:svr_load_string(
        "wyccc_prison_battle_target_unit_index"
    ) or "0") or 0
    local unit_key = core:svr_load_string(
        "wyccc_prison_battle_target_unit_key"
    ) or ""
    local family_member_cqi = saved_battle_character_entry(
        target_faction, army_index, army_id, unit_index, unit_key
    )
    if not family_member_cqi then
        debug_log("returned cage target could not be pre-armed: exact identity unavailable")
        return false
    end

    local character = current_character(family_member_cqi)
    if not safe_interface(character) then
        debug_log("returned cage target could not be pre-armed: character unavailable; family_member_cqi="
            .. tostring(family_member_cqi))
        return false
    end
    if cross_culture_annex.is_garrison_character(character) then return false end
    local protected = set_immortality(character, true)
    debug_log("returned cage target pre-armed before outcome; family_member_cqi="
        .. tostring(family_member_cqi) .. ", immortality=" .. tostring(protected))
    return protected
end

local function find_battle_target_fm_cqi(
    target_faction, target_army_index, warden_key, target_army_id,
    target_unit_index, target_unit_key
)
    local exact_unit_index = tonumber(target_unit_index) or 0
    if exact_unit_index > 0 then
        local exact_fm_cqi, exact_identity, ignored_unit_cqi,
            ignored_unit_key, exact_side = saved_battle_character_entry(
                target_faction,
                target_army_index,
                target_army_id,
                exact_unit_index,
                target_unit_key
            )
        if exact_fm_cqi then
            return exact_fm_cqi, exact_side, exact_identity
        end
        log("exact battle target resolution failed; faction="
            .. tostring(target_faction) .. " army=" .. tostring(target_army_index)
            .. " unit_index=" .. tostring(exact_unit_index))
        -- A known character-unit target must never fall back to the army
        -- commander.  Failing closed loses one capture; falling through here
        -- imprisons the wrong person and can trigger a leader disposition.
        return nil, ""
    end

    local saved_side = pending_battle_snapshot.warden_side or ""
    if saved_side == "" then
        pcall(function() saved_side = core:svr_load_string(SVR_WARDEN_SIDE) or "" end)
    end

    local cache_count = 0
    local getter = nil
    local fm_getter = nil
    local side = ""
    local snapshot = {}
    if saved_side == "attacker" then
        cache_count = cm:pending_battle_cache_num_defenders()
        getter = cm.pending_battle_cache_get_defender
        fm_getter = cm.pending_battle_cache_get_defender_fm_cqi
        side = "defender"
        snapshot = pending_battle_snapshot.defenders
    elseif saved_side == "defender" then
        cache_count = cm:pending_battle_cache_num_attackers()
        getter = cm.pending_battle_cache_get_attacker
        fm_getter = cm.pending_battle_cache_get_attacker_fm_cqi
        side = "attacker"
        snapshot = pending_battle_snapshot.attackers
    elseif cm:pending_battle_cache_faction_is_attacker(warden_key) then
        cache_count = cm:pending_battle_cache_num_defenders()
        getter = cm.pending_battle_cache_get_defender
        fm_getter = cm.pending_battle_cache_get_defender_fm_cqi
        side = "defender"
        snapshot = pending_battle_snapshot.defenders
    elseif cm:pending_battle_cache_faction_is_defender(warden_key) then
        cache_count = cm:pending_battle_cache_num_attackers()
        getter = cm.pending_battle_cache_get_attacker
        fm_getter = cm.pending_battle_cache_get_attacker_fm_cqi
        side = "attacker"
        snapshot = pending_battle_snapshot.attackers
    else
        -- No live pending-battle cache remains.  A side-less fallback is kept
        -- for old saves, but the saved PendingBattle side above is the normal
        -- path and prevents selecting the player's own army as the target.
        cache_count = #pending_battle_snapshot.attackers
        getter = cm.pending_battle_cache_get_attacker
        fm_getter = cm.pending_battle_cache_get_attacker_fm_cqi
        side = "attacker"
        snapshot = pending_battle_snapshot.attackers
    end

    cache_count = math.max(cache_count or 0, #snapshot)
    local participants = {}
    local matching = {}
    for i = 1, cache_count do
        local entry = snapshot[i]
        if not entry and getter then
            local ok, char_cqi, mf_cqi, faction_key = pcall(function()
                return getter(cm, i)
            end)
            if ok then
                entry = {char_cqi = char_cqi, mf_cqi = mf_cqi, faction_key = faction_key}
            end
        end
        if entry and (tonumber(entry.family_member_cqi) or 0) <= 0 and fm_getter then
            pcall(function()
                entry.family_member_cqi = fm_getter(cm, i) or 0
            end)
        end
        if entry then
            participants[i] = entry
        end
        if entry and entry.faction_key == target_faction then
            matching[#matching + 1] = entry
        end
    end
    -- battle_army:army_index() and the pending-battle cache use the same
    -- participant order on a side. Verify the faction before accepting it;
    -- mixed-faction reinforcement battles fall back to the first matching force.
    local selected = nil
    if target_army_id and target_army_id ~= "" then
        for _, entry in pairs(participants) do
            if tostring(entry.mf_cqi or "") == tostring(target_army_id)
                and entry.faction_key == target_faction
            then
                selected = entry
                break
            end
        end
    end
    selected = selected or participants[target_army_index]
    if not selected or selected.faction_key ~= target_faction then
        selected = matching[1]
    end
    if selected then
        -- The snapshot is normally populated before the battle starts.  A
        -- results transition can nevertheless hand us an older/partial
        -- entry (for example after loading a save made during PendingBattle)
        -- with only the primitive target fields.  Synthesize the minimum
        -- independent-prison identity right here so capture does not depend
        -- on character_details() surviving defeat or on callback ordering.
        if type(selected.identity) ~= "table" then
            local source_faction = nil
            if selected.faction_key and selected.faction_key ~= "" then
                pcall(function() source_faction = cm:get_faction(selected.faction_key) end)
            end
            local live_character = nil
            pcall(function() live_character = cm:get_character_by_cqi(selected.char_cqi) end)
            local persisted_character_type_key = character_type_key(live_character)
            local is_faction_leader = faction_leader_status(
                source_faction, live_character, selected.family_member_cqi
            )
            local role = ""
            if persisted_character_type_key == "general" then
                role = "lord"
            elseif persisted_character_type_key ~= "" then
                role = "hero"
            elseif is_faction_leader == true then
                role = "lord"
            end
            selected.identity = {
                family_member_cqi = tonumber(selected.family_member_cqi) or 0,
                character_cqi = tonumber(selected.char_cqi) or 0,
                source_faction = selected.faction_key or "",
                source_culture = call_or(source_faction, "culture", ""),
                source_subculture = call_or(source_faction, "subculture", ""),
                subtype = selected.subtype or "",
                character_type_key = persisted_character_type_key,
                role = role,
                rank = 1,
                forename = "",
                surname = "",
                was_immortal = false,
                -- This ability is restricted in DB to commander targets.
                is_general = true,
                is_faction_leader = is_faction_leader
            }
            debug_log("battle identity synthesized at resolution; faction="
                .. tostring(selected.faction_key) .. ", fm_cqi="
                .. tostring(selected.family_member_cqi))
        end
        debug_log("battle target resolved; side=" .. tostring(side)
            .. ", faction=" .. tostring(selected.faction_key)
            .. ", char_cqi=" .. tostring(selected.char_cqi)
            .. ", mf_cqi=" .. tostring(selected.mf_cqi)
            .. ", fm_cqi=" .. tostring(selected.family_member_cqi)
            .. ", has_identity=" .. tostring(type(selected.identity) == "table"))
        if (selected.family_member_cqi or 0) > 0 then
            return selected.family_member_cqi, side, selected.identity
        end
        local character = cm:get_character_by_cqi(selected.char_cqi)
        if safe_interface(character) then
            return character:family_member():command_queue_index(), side, selected.identity
        end
    end
    log("battle target resolution failed; side=" .. side .. " faction=" .. tostring(target_faction)
        .. " army=" .. tostring(target_army_index))
    return nil, side
end

local function consume_battle_capture_for_faction(faction)
    if cross_culture_annex.is_quest_battle() then return end
    if not is_player_warden(faction) then return end
    if not cross_culture_annex.has_persistent_cage_target() then return end
    local detected = false
    pcall(function() detected = core:svr_load_bool(SVR_DETECTED) == true end)
    local cage_killed = false
    pcall(function() cage_killed = core:svr_load_bool(SVR_CAGE_KILLED) == true end)
    local capture_committed = false
    pcall(function()
        capture_committed = core:svr_load_bool(
            "wyccc_prison_battle_capture_committed"
        ) == true
    end)
    local warden_key = ""
    pcall(function() warden_key = core:svr_load_string(SVR_WARDEN_FACTION) or "" end)
    if capture_committed then
        debug_log("battle capture already committed by an exact target path")
        return
    end
    if not detected or not cage_killed then return end

    local won = false
    pcall(function()
        won = cm:pending_battle_cache_faction_won_battle(faction:name()) == true
    end)
    debug_log("battle capture check; warden=" .. tostring(faction:name())
        .. ", won=" .. tostring(won) .. ", detected=" .. tostring(detected)
        .. ", cage_killed=" .. tostring(cage_killed)
        .. ", saved_warden=" .. tostring(warden_key)
        .. ", committed=" .. tostring(capture_committed))
    if not won then return end

    local fm_cqi = nil
    local queued = false

    -- Preferred path: battle Lua observed the exact target and its death while
    -- the 45-second cage phase was still active.
    if detected and cage_killed
        and (warden_key == "" or warden_key == faction:name())
    then
        local target_faction = core:svr_load_string(SVR_TARGET_FACTION) or ""
        local army_index = tonumber(core:svr_load_string(SVR_TARGET_ARMY_INDEX) or "1") or 1
        local army_id = core:svr_load_string(SVR_TARGET_ARMY_ID) or ""
        local unit_index = tonumber(
            core:svr_load_string("wyccc_prison_battle_target_unit_index") or "0"
        ) or 0
        local unit_key = core:svr_load_string(
            "wyccc_prison_battle_target_unit_key"
        ) or ""
        local target_identity = nil
        fm_cqi, _, target_identity = find_battle_target_fm_cqi(
            target_faction, army_index, faction:name(), army_id,
            unit_index, unit_key
        )
        if fm_cqi then
            queued = queue_battle_capture_finalization(faction, fm_cqi, {
                army_index = army_index,
                army_id = army_id,
                identity = target_identity,
                source = "PendingBattleCageTarget"
            })
        end
    end

    if queued then
        debug_log("custom capture safely deferred; family_member_cqi=" .. tostring(fm_cqi))
        core:svr_save_bool("wyccc_prison_battle_capture_committed", true)
        core:svr_save_bool(SVR_CAGE_KILLED, false)
        core:svr_save_bool(SVR_DETECTED, false)
    elseif detected and cage_killed then
        debug_log("exact custom capture queue failed; family_member_cqi=" .. tostring(fm_cqi))
        log("cage kill was recorded but prisoner capture could not be queued")
    end
end

local function set_button_text(button, text)
    if button and is_uicomponent(button) then
        local label = find_uicomponent(button, "button_txt")
        if label and is_uicomponent(label) then
            label:SetStateText(text)
        else
            pcall(function() button:SetStateText(text) end)
        end
    end
end

local function place(component, width, height, x, y)
    component:SetCanResizeWidth(true)
    component:SetCanResizeHeight(true)
    component:Resize(width, height)
    component:SetDockingPoint(5)
    component:SetDockOffset(x, y)
end

local function create_button(id, template, parent, width, height, x, y, text, callback)
    local button = core:get_or_create_component(id, template, parent)
    place(button, width, height, x, y)
    set_button_text(button, text)
    button:SetVisible(true)
    if callback then
        local listener = "wyccc_prison_ui_click_" .. id
        core:remove_listener(listener)
        core:add_listener(listener, "ComponentLClickUp", function(context)
            return context.string == id
        end, callback, true)
    end
    return button
end

local function facility_effect_text(facility, level)
    level = tonumber(level) or 0
    if level <= 0 then
        return localised("wyccc_prison_runtime_facility_effect_none")
    end
    if facility == "capacity" then
        return localised_format("wyccc_prison_runtime_facility_effect_capacity", {
            LEVEL = level,
            CAPACITY = BASE_CAPACITY + level
        })
    elseif facility == "recruitment" then
        return localised_format("wyccc_prison_runtime_recruitment_chance", {
            CHANCE = RECRUIT_CHANCE[level] or 0
        })
    elseif facility == "ransom" then
        return localised_format("wyccc_prison_runtime_facility_effect_ransom", {
            MULTIPLIER = string.format("%.1f", RANSOM_MULTIPLIER[level] or 0)
        })
    elseif facility == "interrogation" then
        local recruitment_bonus, experience_pool = interrogation_values(level)
        return localised_format("wyccc_prison_runtime_facility_effect_interrogation", {
            BONUS = recruitment_bonus,
            EXPERIENCE = experience_pool
        })
    end
    return localised("wyccc_prison_runtime_no_available_effect")
end

local function facility_upgrade_tooltip(facility, current_level, target_level, faction)
    local name = facility_name(facility)
    if target_level > MAX_FACILITY_LEVEL then
        return localised_format("wyccc_prison_runtime_facility_tooltip_max", {
            NAME = name,
            LEVEL = current_level,
            MAX_LEVEL = MAX_FACILITY_LEVEL,
            EFFECT = facility_effect_text(facility, current_level)
        })
    end
    local cost = FACILITY_COSTS[target_level]
    local status
    if target_level <= current_level then
        status = localised("wyccc_prison_runtime_facility_status_built")
    elseif target_level == current_level + 1 then
        status = faction:treasury() >= cost
            and localised("wyccc_prison_runtime_facility_status_upgradable")
            or localised("wyccc_prison_runtime_facility_status_insufficient_funds")
    else
        status = localised("wyccc_prison_runtime_facility_status_requires_prior")
    end
    return localised_format("wyccc_prison_runtime_facility_tooltip", {
        NAME = name,
        TARGET_LEVEL = target_level,
        EFFECT = facility_effect_text(facility, target_level),
        COST = cost,
        STATUS = status
    })
end

local function facility_tooltip(facility, level, next_level, faction)
    return facility_upgrade_tooltip(facility, level, next_level, faction)
end

refresh_ui = function()
    if not panel_uic or not is_uicomponent(panel_uic) then return end
    local faction_key = cm:get_local_faction_name(true)
    if not cross_culture_annex.is_prison_faction_key(faction_key) then return end
    local faction = cm:get_faction(faction_key)
    local state = get_state(faction_key)
    local title = find_uicomponent(panel_uic, "wyccc_prison_title")
    set_button_text(title, localised_format("wyccc_prison_runtime_prison_title_count", {
        COUNT = prisoner_count(state),
        CAPACITY = prisoner_capacity(state)
    }))
    for i = 1, prisoner_capacity(state) do
        local button = prisoner_slots[i]
        local record = prisoner_for_index(state, i)
        if button then
            button:SetVisible(true)
            if record then
                local character = current_character(record.family_member_cqi)
                local name = prisoner_display_name(record)
                local portrait = character_portrait(character)
                if portrait then pcall(function() button:SetImagePath(portrait) end) end
                set_button_text(button, name)
                button:SetState(selected_prisoner_index == i and "selected" or "active")
                button:SetTooltipText(localised_format("wyccc_prison_runtime_prisoner_source_faction", {
                    NAME = name,
                    FACTION = faction_display_name(record.source_faction)
                }), true)
            else
                set_button_text(button, localised("wyccc_prison_runtime_empty_cell"))
                button:SetState("inactive")
                button:SetTooltipText(localised("wyccc_prison_runtime_no_prisoners"), true)
            end
        end
    end
    for i = prisoner_capacity(state) + 1, #prisoner_slots do
        if prisoner_slots[i] then prisoner_slots[i]:SetVisible(false) end
    end
    local selected = prisoner_for_index(state, selected_prisoner_index)
    local action_available = selected and prison_action_available(state)
    local leader_requirement = selected and leader_action_requirement_text(state, selected)
    local leader_actions_available = selected and leader_actions_unlocked(state, selected)
    local can_recruit = action_available and leader_actions_available and (state.facilities.recruitment or 0) > 0
    local can_ransom = action_available and (state.facilities.ransom or 0) > 0
    local can_release = selected ~= nil
    local can_interrogate = action_available and leader_actions_available and (state.facilities.interrogation or 0) > 0
    local effective_recruitment_chance = selected and recruitment_chance(state, selected) or 0
    local interrogation_bonus, interrogation_experience_pool = interrogation_values(
        state.facilities.interrogation
    )
    if recruit_chance_text then
        recruit_chance_text:SetVisible(selected ~= nil)
        wp_visual_set_text(recruit_chance_text, selected and localised_format(
            "wyccc_prison_runtime_recruitment_chance", {CHANCE = effective_recruitment_chance}
        ) or "")
    end
    if recruit_button_uic then
        recruit_button_uic:SetVisible(selected ~= nil)
        recruit_button_uic:SetState(can_recruit and "active" or "inactive")
        local recruit_tooltip = not selected and localised("wyccc_prison_runtime_select_prisoner")
            or leader_requirement
            or (not action_available and localised("wyccc_prison_runtime_action_used"))
            or (can_recruit and localised_format("wyccc_prison_runtime_recruitment_chance", {
                CHANCE = effective_recruitment_chance
            }) or localised("wyccc_prison_runtime_requires_recruitment_room"))
        recruit_button_uic:SetTooltipText(recruit_tooltip, true)
    end
    if ransom_button_uic then
        ransom_button_uic:SetVisible(selected ~= nil)
        ransom_button_uic:SetState(can_ransom and "active" or "inactive")
        ransom_button_uic:SetTooltipText(can_ransom and localised_format(
            "wyccc_prison_runtime_ransom_value", {AMOUNT = selected and ransom_amount(state, selected) or 0}
        ) or localised("wyccc_prison_runtime_requires_treasury"), true)
    end
    if release_button_uic then
        release_button_uic:SetVisible(selected ~= nil)
        release_button_uic:SetState(can_release and "active" or "inactive")
    end
    if interrogate_button_uic then
        interrogate_button_uic:SetVisible(selected ~= nil)
        interrogate_button_uic:SetState(can_interrogate and "active" or "inactive")
        local interrogate_tooltip = not selected and localised("wyccc_prison_runtime_select_prisoner")
            or leader_requirement
            or (not action_available and localised("wyccc_prison_runtime_action_used"))
            or (can_interrogate and localised_format("wyccc_prison_runtime_interrogation_value", {
                BONUS = interrogation_bonus,
                EXPERIENCE = interrogation_experience_pool
            }) or localised("wyccc_prison_runtime_requires_interrogation_room"))
        interrogate_button_uic:SetTooltipText(interrogate_tooltip, true)
    end
    for facility, levels in pairs(facility_buttons) do
        local level = state.facilities[facility] or 0
        for target_level, button in pairs(levels) do
            button:SetState(target_level == level and "selected" or (target_level == level + 1 and "active" or "inactive"))
            button:SetTooltipText(facility_tooltip(facility, level, target_level, faction), true)
        end
    end
end

local function show_panel()
    if not panel_uic or not is_uicomponent(panel_uic) then return end
    panel_uic:SetVisible(true)
    if entry_button_uic then entry_button_uic:SetState("selected") end
    refresh_ui()
end

local function hide_panel()
    if panel_uic and is_uicomponent(panel_uic) then panel_uic:SetVisible(false) end
    if entry_button_uic then entry_button_uic:SetState("active") end
end

-- The vanilla dungeon and the campaign events panel both own a full-screen
-- background/MoviePlayer.  Opening an incident while the dungeon is still
-- visible lets the two panels fight over that movie context; after the event
-- closes, the dungeon can be left showing the event/campaign background.
-- Finish the dungeon's visibility transition first, then open the incident on
-- the next UI beat.  Reopening the dungeon consequently starts from its own
-- vanilla background state instead of the event panel's state.
queue_prison_incident = function(faction, incident_key, character)
    hide_panel()
    cm:callback(function()
        trigger_incident(faction, incident_key, character)
    end, 0.1)
end

queue_leader_disposition_event = function(faction, state, record, character)
    hide_panel()
    -- The prisoner record has already been committed.  Let the battle-results
    -- transition finish, then open this as the sole blocking event for the
    -- third-capture outcome so it cannot race the ordinary capture incident.
    cm:callback(function()
        queue_leader_disposition(faction, state, record, character)
    end, 0.25)
end

local function toggle_panel()
    if not panel_uic or not is_uicomponent(panel_uic) or not visual_ui_ready then
        if setup_ui then pcall(setup_ui) end
    end
    if not panel_uic or not is_uicomponent(panel_uic) or not visual_ui_ready then
        log("prison entry click ignored because the panel is not ready")
        return
    end
    if panel_uic:Visible() then hide_panel() else show_panel() end
end

setup_ui = function()
    local faction_key = cm:get_local_faction_name(true)
    if not cross_culture_annex.is_prison_faction_key(faction_key) then return end
    local root = core:get_ui_root()
    local button_group = find_uicomponent(root, "hud_campaign", "faction_buttons_docker", "button_group_management")
    if not button_group or not is_uicomponent(button_group) then return end
    entry_button_uic = find_uicomponent(button_group, "wyccc_prison_entry_button")
    if not entry_button_uic then
        entry_button_uic = UIComponent(button_group:CreateComponent("wyccc_prison_entry_button", "ui/templates/round_hud_button_toggle.twui.xml"))
    else
        entry_button_uic = UIComponent(entry_button_uic)
    end
    entry_button_uic:SetCanResizeWidth(true)
    entry_button_uic:SetCanResizeHeight(true)
    entry_button_uic:Resize(55, 55)
    entry_button_uic:SetTooltipText(localised("wyccc_prison_ui_entry_tooltip"), true)
    entry_button_uic:SetVisible(true)
    core:remove_listener("wyccc_prison_entry_click")
    core:add_listener("wyccc_prison_entry_click", "ComponentLClickUp", function(context)
        return context.string == "wyccc_prison_entry_button"
    end, toggle_panel, true)

    if panel_uic and is_uicomponent(panel_uic) then return end
    panel_uic = core:get_or_create_component("wyccc_prison_panel", "ui/campaign ui/script_dummy")
    panel_uic:PropagatePriority(200)
    panel_uic:SetVisible(false)
    local sw, sh = core:get_screen_resolution()
    place(panel_uic, sw * 0.78, sh * 0.76, 0, 0)
    -- Empty TWUI host layouts do not expose Width/Height until their first
    -- layout pass.  Use the current screen dimensions as the authoritative
    -- coordinate space so setup cannot abort before the entry listener works.
    local w, h = sw, sh
    local title = create_button("wyccc_prison_title", "ui/templates/parchment_divider_title", panel_uic, w - 40, 42, 0, -h / 2 + 35, localised("wyccc_prison_ui_title"))
    create_button("wyccc_prison_close", "ui/templates/round_small_button", panel_uic, 32, 32, w / 2 - 45, -h / 2 + 35, "", hide_panel):SetImagePath("ui/skins/default/icon_cross.png")
    create_button("wyccc_prison_capacity_text", "ui/templates/parchment_divider_title", panel_uic, 300, 38, -w / 2 + 180, -h / 2 + 88, localised("wyccc_prison_runtime_prisoner_roster"))
    for i = 1, 4 do
        local slot_index = i
        local row = slot_index - 1
        prisoner_slots[slot_index] = create_button(
            "wyccc_prisoner_slot_" .. tostring(slot_index), "ui/templates/square_medium_text_button", panel_uic,
            230, 70, -w / 2 + 160, -h / 2 + 155 + row * 78, localised("wyccc_prison_runtime_empty_cell"),
            function() selected_prisoner_index = slot_index; refresh_ui() end
        )
    end
    create_button("wyccc_prison_facility_title", "ui/templates/parchment_divider_title", panel_uic, 500, 38, w / 2 - 250, -h / 2 + 88, localised("wyccc_prison_runtime_facility_upgrades"))
    local facility_x = w / 2 - 250
    local facility_y = -h / 2 + 150
    for index, facility in ipairs(FACILITIES) do
        local facility_key = facility
        facility_buttons[facility_key] = {}
        local y = facility_y + (index - 1) * 88
        for level = 1, 3 do
            local target_level = level
            local button = create_button(
                "wyccc_prison_facility_" .. facility_key .. "_" .. tostring(target_level),
                "ui/templates/square_medium_text_button", panel_uic, 145, 64,
                facility_x - 155 + (target_level - 1) * 160, y,
                localised_format("wyccc_prison_runtime_facility_level", {
                    NAME = facility_name(facility_key),
                    LEVEL = target_level
                }),
                function()
                    local f = cm:get_faction(cm:get_local_faction_name(true))
                    local current_level = get_state(f:name()).facilities[facility_key] or 0
                    if target_level == current_level + 1 then
                        upgrade(f, facility_key)
                    end
                    refresh_ui()
                end
            )
            facility_buttons[facility_key][target_level] = button
        end
    end
    recruit_button_uic = create_button("wyccc_prison_action_recruit", "ui/templates/square_medium_text_button", panel_uic, 145, 55, -w / 2 + 80, h / 2 - 65, localised("wyccc_prison_runtime_action_recruit"), function()
        local faction = cm:get_faction(cm:get_local_faction_name(true)); local state = get_state(faction:name()); local record = prisoner_for_index(state, selected_prisoner_index)
        if record then perform_recruit(faction, state, record); refresh_ui() end
    end)
    ransom_button_uic = create_button("wyccc_prison_action_ransom", "ui/templates/square_medium_text_button", panel_uic, 145, 55, -w / 2 + 235, h / 2 - 65, localised("wyccc_prison_runtime_action_ransom"), function()
        local faction = cm:get_faction(cm:get_local_faction_name(true)); local state = get_state(faction:name()); local record = prisoner_for_index(state, selected_prisoner_index)
        if record and perform_ransom(faction, state, record) then selected_prisoner_index = 0; refresh_ui() end
    end)
    release_button_uic = create_button("wyccc_prison_action_release", "ui/templates/square_medium_text_button", panel_uic, 145, 55, -w / 2 + 390, h / 2 - 65, localised("wyccc_prison_runtime_action_release"), function()
        local faction = cm:get_faction(cm:get_local_faction_name(true)); local state = get_state(faction:name()); local record = prisoner_for_index(state, selected_prisoner_index)
        if record and perform_release(faction, state, record) then selected_prisoner_index = 0; refresh_ui() end
    end)
    interrogate_button_uic = create_button("wyccc_prison_action_interrogate", "ui/templates/square_medium_text_button", panel_uic, 145, 55, -w / 2 + 545, h / 2 - 65, localised("wyccc_prison_runtime_action_interrogate"), function()
        local faction = cm:get_faction(cm:get_local_faction_name(true)); local state = get_state(faction:name()); local record = prisoner_for_index(state, selected_prisoner_index)
        if record then grant_interrogation(faction, state, record); refresh_ui() end
    end)
    log("independent prison UI created without original TWUI")
end

local function save_state(context)
    cm:save_named_value(STATE_KEY, state_by_faction, context)
    -- Battle snapshots and queued captures reference transient pending-battle
    -- interfaces. They are invalid after a save/load boundary and must never
    -- be persisted into a campaign save.
end

local function load_state(context)
    state_by_faction = cm:load_named_value(STATE_KEY, state_by_faction, context)
    pending_battle_snapshot = {attackers = {}, defenders = {}, warden_key = "", warden_side = ""}
    pending_battle_capture_finalizations = {}
    for _, key in ipairs({
        SVR_QUEST_BATTLE, SVR_DETECTED, SVR_CAGE_KILLED,
        SVR_CAGE_WINDOW_EXPIRED, "wyccc_prison_battle_capture_committed",
        "wyccc_prison_battle_target_is_commanding"
    }) do
        pcall(function() core:svr_save_bool(key, false) end)
    end
    for _, key in ipairs({
        SVR_TARGET_FACTION, SVR_TARGET_ARMY_INDEX, SVR_TARGET_ARMY_ID,
        SVR_TARGET_UNIT_ID, SVR_WARDEN_FACTION, SVR_WARDEN_SIDE,
        "wyccc_prison_battle_target_unit_index",
        "wyccc_prison_battle_target_unit_key",
        "wyccc_prison_battle_character_unit_map"
    }) do
        pcall(function() core:svr_save_string(key, "") end)
    end
    for faction_key in pairs(state_by_faction or {}) do
        local state = get_state(faction_key)
        for _, record in ipairs(state.prisoners or {}) do
            recover_prisoner_subtype(record)
        end
    end
end

-- The vanilla dilemma text view binds directly to
-- CcoCampaignEventDilemma.Description.  Custom CCO placeholders in that DB
-- description are not expanded by this view even though the target faction
-- and family member are present in the issued-event context.  Keep the
-- standard dilemma layout, then replace only its two native description text
-- components after the events panel has finished constructing them.
cross_culture_annex.leader_disposition_ui = {
    faction_key = "",
    generation = 0,
    last_signature = ""
}

function cross_culture_annex.leader_disposition_ui.description_text(faction_key)
    local faction = nil
    pcall(function() faction = cm:get_faction(faction_key) end)
    if not safe_interface(faction) then return nil end

    local state = get_state(faction_key)
    local pending = state.pending_leader_dispositions
        and state.pending_leader_dispositions[1] or nil
    if not pending then return nil end

    local leader_name = tostring(pending.leader_name or ""):gsub("%s+$", "")
    if leader_name == "" then
        local record = find_prisoner(state, pending.family_member_cqi)
        if record then leader_name = prisoner_display_name(record):gsub("%s+$", "") end
    end
    if leader_name == "" then leader_name = localised("wyccc_prison_runtime_default_faction_leader") end

    local source_faction_name = faction_display_name(pending.source_faction)
    local template = ""
    pcall(function()
        template = common.get_localised_string(
            "wyccc_prison_leader_disposition_runtime_description"
        ) or ""
    end)
    if template == "" or template == "wyccc_prison_leader_disposition_runtime_description" then
        template = localised("wyccc_prison_leader_disposition_runtime_description")
    end
    template = template:gsub("{CHARACTER_NAME}", function() return leader_name end)
    template = template:gsub("{FACTION_NAME}", function() return source_faction_name end)
    return template, leader_name .. "|" .. tostring(pending.source_faction)
end

function cross_culture_annex.leader_disposition_ui.apply(faction_key)
    local description, signature =
        cross_culture_annex.leader_disposition_ui.description_text(faction_key)
    if not description then return false end

    local details = find_uicomponent(
        core:get_ui_root(), "events", "event_layouts", "dilemma_active",
        "dilemma", "background", "main_holder", "details_holder"
    )
    if not details or not is_uicomponent(details) then return false end

    local components = {
        find_uicomponent(details, "dy_details_text", "dy_description"),
        find_uicomponent(details, "dy_details_text_large", "dy_description")
    }
    local updated = 0
    for _, component in ipairs(components) do
        if component and is_uicomponent(component) then
            local ok = pcall(function() component:SetStateText(description) end)
            if ok then updated = updated + 1 end
        end
    end
    if updated > 0
        and cross_culture_annex.leader_disposition_ui.last_signature ~= signature then
        cross_culture_annex.leader_disposition_ui.last_signature = signature
        log("leader disposition runtime description injected: " .. signature)
    end
    return updated > 0
end

function cross_culture_annex.leader_disposition_ui.schedule(faction_key)
    faction_key = tostring(faction_key or "")
    if faction_key == "" then return end
    cross_culture_annex.leader_disposition_ui.faction_key = faction_key
    cross_culture_annex.leader_disposition_ui.generation =
        cross_culture_annex.leader_disposition_ui.generation + 1
    local generation = cross_culture_annex.leader_disposition_ui.generation
    for _, delay in ipairs({0, 0.05, 0.15, 0.4, 0.8}) do
        cm:callback(function()
            if generation ~= cross_culture_annex.leader_disposition_ui.generation
                or cross_culture_annex.leader_disposition_ui.faction_key ~= faction_key then
                return
            end
            cross_culture_annex.leader_disposition_ui.apply(faction_key)
        end, delay)
    end
end

core:add_listener("wyccc_prison_loading_game", "LoadingGame", true, function(context) load_state(context) end, false)
core:add_listener("wyccc_prison_saving_game", "SavingGame", true, function(context) save_state(context) end, true)
core:add_listener("wyccc_prison_pool_art_set_recruited", "CharacterRecruited", function(context)
    local character = nil
    pcall(function() character = context:character() end)
    local state = cross_culture_annex.pending_pool_art_set(character)
    return state ~= nil
end, function(context)
    cross_culture_annex.refresh_recruited_pool_art_set(context)
end, true)
core:add_listener("wyccc_prison_leader_disposition_issued", "DilemmaIssuedEvent", function(context)
    local dilemma = ""
    local faction = nil
    pcall(function() dilemma = context:dilemma() end)
    pcall(function() faction = context:faction() end)
    if dilemma ~= LEADER_DISPOSITION_DILEMMA or not safe_interface(faction) then
        return false
    end
    return is_player_warden(faction)
end, function(context)
    local faction = nil
    pcall(function() faction = context:faction() end)
    if safe_interface(faction) then
        cross_culture_annex.leader_disposition_ui.schedule(faction:name())
    end
end, true)
core:add_listener("wyccc_prison_leader_disposition_panel_opened", "PanelOpenedCampaign", function(context)
    return context.string == "events"
        and cross_culture_annex.leader_disposition_ui.faction_key ~= ""
end, function()
    cross_culture_annex.leader_disposition_ui.schedule(
        cross_culture_annex.leader_disposition_ui.faction_key
    )
end, true)
core:add_listener("wyccc_prison_leader_disposition_choice", "DilemmaChoiceMadeEvent", function(context)
    local dilemma = ""
    local faction = nil
    pcall(function() dilemma = context:dilemma() end)
    pcall(function() faction = context:faction() end)
    if dilemma ~= LEADER_DISPOSITION_DILEMMA or not safe_interface(faction) then
        return false
    end
    return is_player_warden(faction)
end, function(context)
    local faction = nil
    pcall(function() faction = context:faction() end)
    if not safe_interface(faction) then
        log("leader disposition choice ignored: faction context unavailable")
        return
    end
    cross_culture_annex.leader_disposition_ui.faction_key = ""
    cross_culture_annex.leader_disposition_ui.generation =
        cross_culture_annex.leader_disposition_ui.generation + 1
    cross_culture_annex.leader_disposition_ui.last_signature = ""
    local choice, raw_choice = leader_disposition_choice_index(context)
    log("leader disposition choice received: index=" .. tostring(choice)
        .. ", raw=" .. tostring(raw_choice))
    resolve_leader_disposition(faction, choice)
end, true)
core:add_listener("wyccc_prison_pending_battle", "PendingBattle", true, function()
    snapshot_pending_battle()
end, true)
core:add_listener("wyccc_prison_character_convalesced_or_killed", "CharacterConvalescedOrKilled", true, function(context)
    capture_from_character_outcome(context, "CharacterConvalescedOrKilled")
end, true)
core:add_listener("wyccc_prison_character_completed_battle", "CharacterCompletedBattle", true, function(context)
    capture_from_character_outcome(context, "CharacterCompletedBattle")
end, true)
core:add_listener(
    "wyccc_prison_finalize_battle_capture",
    "ScriptEventBattleSequenceCompleted",
    true,
    function()
        -- Schedule even when empty: CA can emit this event before our
        -- BattleCompleted listener adds the exact target to the queue.
        cross_culture_annex.schedule_capture_finalization()
    end,
    true
)
pcall(function()
    cm:add_immortal_character_defeated_listener(
        "wyccc_prison_immortal_cage_defeat",
        cage_immortal_defeat_condition,
        capture_from_immortal_defeat,
        true
    )
end)
-- §10.40 +0x22c0f80: 面板开合序号戳——供回合开始级联安静窗判据。
local wyccc_panel_seq = 0
core:remove_listener("wyccc_prison_panel_stamp")
core:add_listener("wyccc_prison_panel_stamp", "PanelOpenedCampaign", true,
    function() wyccc_panel_seq = wyccc_panel_seq + 1 end, true)
core:add_listener("wyccc_prison_faction_turn", "FactionBeginTurnPhaseNormal", function(context)
    local faction = nil
    pcall(function() faction = context:faction() end)
    return is_player_warden(faction)
end, function(context)
    local faction = nil
    pcall(function() faction = context:faction() end)
    if not is_player_warden(faction) then return end
    -- Prisoner effects and the wounded/immortal state are established when a
    -- capture, release, recruitment or facility upgrade changes the prison.
    -- Re-running those engine mutations at every turn boundary is redundant
    -- and can block the campaign thread while the turn queue is advancing,
    -- especially for a defeated character whose wrapper is being rebuilt.
    -- Keep turn-start work UI-only; the first-tick/load path still performs a
    -- one-time state reconciliation for existing saves.
    -- 9.0: never run setup_ui/refresh_ui inside this dispatch.  Turn start
    -- floods the event feed (mass force_add_trait messages), auto-opens the
    -- events panel and rebuilds HUD subtrees while listeners are still being
    -- dispatched; CreateComponent/SetContextObject work inline here produced
    -- +0x22c8774 wild-pointer writes (09-29 10:30 dump, schwartzhafen T4).
    -- 09-29 13:19 dump (+0x22c0f80 null+0x58 read): 1.5s 固定延迟仍落在
    -- 级联窗内——绑定完成 0.1s 后 events 面板构建、tab_details 自选点击
    -- 读死 context。除 ui_locked 外追加"安静窗"判据：无 blocking 面板且
    -- 连续 2 个 0.5s 拍无新 PanelOpenedCampaign；面板长开不挡，只挡开合。
    local attempts = 0
    local last_seq = -1
    local stable = 0
    local function deferred_turn_ui()
        attempts = attempts + 1
        if uim.ui_locked then
            stable = 0
            last_seq = wyccc_panel_seq
        else
            local blocking = nil
            pcall(function() blocking = uim:get_open_blocking_panel() end)
            if blocking then
                stable = 0
                last_seq = wyccc_panel_seq
            elseif wyccc_panel_seq == last_seq then
                stable = stable + 1
            else
                last_seq = wyccc_panel_seq
                stable = 0
            end
        end
        if stable < 2 then
            if attempts < 40 then cm:callback(deferred_turn_ui, 0.5) end
            return
        end
        if not panel_uic or not is_uicomponent(panel_uic) or not visual_ui_ready
            or not entry_button_uic or not is_uicomponent(entry_button_uic) then
            local setup_ok, setup_error = pcall(setup_ui)
            if not setup_ok then
                log("turn-start UI setup failed safely: " .. tostring(setup_error))
                return
            end
        end
        if panel_uic and is_uicomponent(panel_uic) and panel_uic:Visible() then
            local refresh_ok, refresh_error = pcall(refresh_ui)
            if not refresh_ok then
                ui_refresh_in_progress = false
                log("turn-start UI refresh failed safely: " .. tostring(refresh_error))
            end
        end
    end
    cm:callback(deferred_turn_ui, 1.5)
end, true)
core:add_listener("wyccc_prison_battle_completed", "BattleCompleted", true, function()
    local faction = player_warden_faction()
    if faction then consume_battle_capture_for_faction(faction) end
    cross_culture_annex.after_battle_sequence("wyccc_prison_battle_ui_refresh", refresh_ui, 0.1)
end, true)
core:add_listener("wyccc_prison_battle_camera_completed", "BattleCompletedCameraMove", true, function()
    local faction = player_warden_faction()
    if faction then consume_battle_capture_for_faction(faction) end
    cross_culture_annex.after_battle_sequence("wyccc_prison_battle_ui_refresh", refresh_ui, 0.1)
end, true)

-- UI must be created after the loading screen has been dismissed.  Listening to
-- PanelOpenedCampaign or every ComponentCreated event is unsafe here: the
-- vanilla events intervention locks the UI while its panel is opening, and a
-- prison panel created from that callback can steal the input focus.
cm:add_first_tick_callback(function()
    -- PendingBattle is not replayed when the player loads a save that was made
    -- on the pre-battle panel. A returned battle bridge is authoritative even
    -- if is_pending_battle_active() has already changed state; only rebuild an
    -- unfought snapshot when no battle result marker exists.
    local pending_active = false
    local pending_fought = false
    local returned_capture_bridge = false
    pcall(function()
        pending_active, pending_fought = cm:is_pending_battle_active()
    end)
    local preserve_capture_bridge, bridge_detected, bridge_killed =
        battle_bridge_has_capture_result()
    if preserve_capture_bridge then
        returned_capture_bridge = true
        debug_log("first tick preserved returned battle capture markers; detected="
            .. tostring(bridge_detected) .. ", cage_killed="
            .. tostring(bridge_killed))
        prepare_returned_cage_target()
    elseif pending_active and not pending_fought then
        snapshot_pending_battle()
        debug_log("first tick restored an unfought pending-battle identity snapshot")
    end
    core:progress_on_loading_screen_dismissed(function()
        -- A quest battle returns without cage markers, but its character and
        -- UI teardown still owns these interfaces. Use the native battle-
        -- sequence gate for every load, including uncaptured battle returns.
        -- 9.0: defer past the dismiss cascade. This callback fires inside the
        -- LoadingScreenDismissed dispatch while the screen teardown and the
        -- intro movie overlay are in flight; running CreateComponent-heavy
        -- setup_ui() inline here produced +0x22c8774 wild-pointer writes.
        cross_culture_annex.after_battle_sequence("wyccc_prison_load_reconciliation", function()
            local faction = player_warden_faction()
            if faction then
                if returned_capture_bridge then
                    debug_log("skipped prisoner reconciliation during returned battle sequence")
                else
                    local state = get_state(faction:name())
                    enforce_prisoners(faction, state)
                end
            end
            setup_ui()
            initialize_startup_alarielle_test()
            cross_culture_annex.schedule_capture_finalization()
        end, 0.5)
    end)
end)

-- UI handles are invalid after a campaign UI rebuild.  Drop every cached
-- handle so the next FactionBeginTurnPhaseNormal can recreate the button and
-- panel against the new UI tree.
core:add_ui_destroyed_callback(function()
    core:remove_listener("wyccc_prison_entry_click")
    core:remove_listener("wyccc_prison_vanilla_upgrade")
    panel_uic = nil
    entry_button_uic = nil
    recruit_button_uic = nil
    ransom_button_uic = nil
    release_button_uic = nil
    interrogate_button_uic = nil
    recruit_chance_text = nil
    prisoner_slots = {}
    facility_buttons = {}
    facility_nodes = {}
    facility_frames = {}
    slot_portraits = {}
    slot_frames = {}
    slot_labels = {}
    facility_detail_title = nil
    facility_detail_text = nil
    facility_detail_icon = nil
    facility_upgrade_button = nil
    facility_upgrade_level_text = nil
    facility_upgrade_cost_text = nil
    upgrade_action_buttons = {left = {}, right = {}}
    vanilla_title_uic = nil
    vanilla_upgrade_total_parent_uic = nil
    vanilla_upgrade_counter_uic = nil
    vanilla_warden_supply_uic = nil
    vanilla_upgrade_total_uic = nil
    vanilla_upgrade_label_uic = nil
    vanilla_upgrade_icon_uic = nil
    vanilla_close_uic = nil
    vanilla_info_uic = nil
    vanilla_left_side_uic = nil
    vanilla_right_side_uic = nil
    visual_scale = 1
    ui_refresh_in_progress = false
    visual_ui_ready = false
end)

log("independent prison state machine initialised; no native prison API is used")

-- Visual shell: keep the independent state machine above, but use the
-- Athel Tamarha prison artwork and radial layout for the player-facing panel.
function wp_visual_set_text(component, text)
    if not component or not is_uicomponent(component) then return end
    pcall(function() component:SetStateText(tostring(text or "")) end)
    pcall(function()
        local label = find_uicomponent(component, "button_txt")
        if label and is_uicomponent(label) then label:SetStateText(tostring(text or "")) end
    end)
end

function wp_visual_set_image(component, path)
    if not component or not is_uicomponent(component) or not path then return end
    -- Some vanilla-derived image components expose the image path on the
    -- component itself, while others expose a child named "icon".  Updating
    -- both keeps the original state/frame artwork and prevents an unbound
    -- component from rendering as a white square.
    pcall(function() component:SetImagePath(path) end)
    local child = nil
    pcall(function() child = find_uicomponent(component, "icon") end)
    if child and is_uicomponent(child) then
        pcall(function() child:SetImagePath(path) end)
    end
end

function wp_hide_native_scrollbars()
    if not panel_uic or not is_uicomponent(panel_uic) then return end
    local paths = {
        {"left_side", "left_tooltip_holder"},
        {"right_side", "right_tooltip_holder"}
    }
    for _, path in ipairs(paths) do
        local slider = find_uicomponent(panel_uic, "outer_ring_content_holder", path[1], path[2],
            "tooltip_entry", "tooltip_entry_content", "effect_list", "listview", "vslider")
        if slider and is_uicomponent(slider) then
            slider:SetVisible(false)
        end
    end
end

-- The right-side vanilla tooltip nests upgrade_2/upgrade_3 under
-- upgrade_1/dy_name, while the left-side tooltip keeps them as siblings.
-- Resolve both shapes so every facility exposes the same three-level tree.
function wp_find_upgrade_node(content, level)
    if not content then return nil end
    local id = "upgrade_" .. tostring(level)
    local node = find_uicomponent(content, id)
    if node then return node end
    local first = find_uicomponent(content, "upgrade_1")
    if first then
        node = find_uicomponent(first, "dy_name", id)
    end
    return node
end

function wp_set_portrait_image(component, portrait_path)
    if not component or not is_uicomponent(component) or portrait_path == "" then return false end
    -- commander_portrait is a multi-image UIC.  SetImagePath(path) alone
    -- changes the backing texture but leaves the state image at the template's
    -- old crop rectangle, which is why only the upper-left part was visible.
    local image_index = 0
    pcall(function() image_index = component:GetCurrentStateImageIndex(0) end)
    local applied = pcall(function()
        component:SetImagePath(portrait_path, image_index, true)
    end)
    if not applied then
        pcall(function() component:SetImagePath(portrait_path) end)
    end

    -- Match the vanilla help/tooltip image path routine: resize the current
    -- state image to the component width while preserving the source aspect
    -- ratio.  Do not resize the parent UIC, otherwise the prison-cell layout
    -- itself moves at non-native resolutions.
    pcall(function()
        local img_w, img_h = component:GetCurrentStateImageDimensions(0)
        local comp_w, comp_h = component:Dimensions()
        if type(comp_w) == "number" and comp_w > 0 then
            local new_h = comp_h
            if type(img_w) == "number" and type(img_h) == "number"
                and img_w > 0 and img_h > 0
            then
                new_h = comp_w * img_h / img_w
            end
            if type(new_h) == "number" and new_h > 0 then
                component:ResizeCurrentStateImage(0, comp_w, new_h)
            end
        end
    end)
    -- Do not call SetImagePath again after this point.  On the dead-character
    -- fallback path there is no CCO callback to service, and a second texture
    -- assignment restores the source's intrinsic 300x164 dimensions after the
    -- resize above, recreating the exact upper-left crop we are fixing.
    return true
end

local function set_prisoner_portrait(component, record, visible)
    if not component or not is_uicomponent(component) then return end
    if not visible then
        pcall(function()
            component:SetContextObject(cco("CcoCampaignCharacter", 0))
        end)
        pcall(function() component:SetState("empty") end)
        return
    end

    -- CcoCampaignCharacter is keyed by character CQI, while the prison record
    -- is indexed by the stable family-member CQI.  Passing the latter makes the
    -- native portrait callback resolve an invalid context and leaves the slot
    -- blank after a successful capture.
    local family_member_cqi = 0
    local character_cqi = 0
    local portrait_path = ""
    if type(record) == "table" then
        family_member_cqi = tonumber(record.family_member_cqi) or 0
        character_cqi = tonumber(record.character_cqi) or 0
        portrait_path = tostring(record.portrait_path or "")
    else
        -- Keep compatibility with the legacy refresh path, which still passes
        -- a numeric family-member CQI while old UI handles are present.
        family_member_cqi = tonumber(record) or 0
    end

    local character = current_character(family_member_cqi)
    if safe_interface(character) then
        character_cqi = tonumber(call_or(character, "command_queue_index", character_cqi)) or character_cqi
        if portrait_path == "" then
            portrait_path = character_portrait(character) or ""
        end
    end
    if portrait_path == "" then
        portrait_path = portrait_for_identity(type(record) == "table" and record.subtype or "", character_cqi,
            type(record) == "table" and record.source_faction or "") or ""
    end

    local context_bound = false
    -- Bind the live CCO only when it actually supplied a portrait.  A dead
    -- character's CCO remains valid-looking but has an empty PortraitPath;
    -- binding that context would let the native callback overwrite the
    -- subtype fallback with a blank image.
    local native_portrait = portrait_for_character_cqi(character_cqi)
    if character_cqi > 0 and native_portrait ~= nil then
        pcall(function()
            local context = cco("CcoCampaignCharacter", character_cqi)
            if context then
                component:SetContextObject(context)
                context_bound = true
            end
        end)
    end
    local state_bound = pcall(function() component:SetState("portrait") end)
    -- Dead non-immortal characters can lose their live CCO wrapper between the
    -- battle result and the campaign UI refresh.  The path captured at the
    -- pending-battle boundary is a stable fallback for that case.
    if portrait_path ~= "" then
        wp_set_portrait_image(component, portrait_path)
    end
    pcall(function() component:SetVisible(true) end)
    debug_log("portrait bind; fm_cqi=" .. tostring(family_member_cqi)
        .. ", character_cqi=" .. tostring(character_cqi)
        .. ", path=" .. (portrait_path ~= "" and portrait_path or "<empty>")
        .. ", context=" .. tostring(context_bound)
        .. ", state=" .. tostring(state_bound))
end

function wp_scaled(value)
    return math.floor(value * visual_scale + 0.5)
end

function wp_visual_image(id, parent, path, width, height, x, y)
    local image = nil
    pcall(function() image = core:get_or_create_component(id, "ui/groovy/image", parent) end)
    if not image or not is_uicomponent(image) then return nil end
    place(image, width, height, x, y)
    pcall(function() image:SetImagePath(path) end)
    pcall(function() image:SetInteractive(false) end)
    image:SetVisible(true)
    return image
end

function wp_visual_button(id, parent, width, height, x, y, callback)
    local button = nil
    pcall(function() button = core:get_or_create_component(id, "ui/templates/round_small_button_toggle", parent) end)
    if not button or not is_uicomponent(button) then return nil end
    place(button, width, height, x, y)
    button:SetVisible(true)
    pcall(function() button:SetState("active") end)
    if callback then
        local listener = "wyccc_prison_visual_click_" .. id
        core:remove_listener(listener)
        core:add_listener(listener, "ComponentLClickUp", function(context)
            return context.string == id
        end, callback, true)
    end
    return button
end

function wp_visual_action(id, icon_path, x, y, callback)
    local button = wp_visual_button(id, panel_uic, wp_scaled(64), wp_scaled(64), x, y, callback)
    if not button then return nil end
    pcall(function() button:SetImagePath(VANILLA_UI_ROOT .. "dungeon_rite_button_active.png") end)
    wp_visual_image(id .. "_icon", button, icon_path, wp_scaled(42), wp_scaled(42), 0, 0)
    return button
end

refresh_ui = function()
    if not panel_uic or not is_uicomponent(panel_uic) or not visual_ui_ready then return end
    if not panel_uic:Visible() or ui_refresh_in_progress then return end
    ui_refresh_in_progress = true
    local faction_key = cm:get_local_faction_name(true)
    if not cross_culture_annex.is_prison_faction_key(faction_key) then
        ui_refresh_in_progress = false
        return
    end
    wp_hide_native_scrollbars()
    local faction = cm:get_faction(faction_key)
    local state = get_state(faction_key)
    local capacity = prisoner_capacity(state)
    wp_visual_set_text(vanilla_title_uic or find_uicomponent(panel_uic, "wyccc_prison_visual_title"),
        localised_format("wyccc_prison_runtime_prison_title_count", {
            COUNT = prisoner_count(state),
            CAPACITY = capacity
        }))

    for i = 1, #prisoner_slots do
        local button = prisoner_slots[i]
        if button then button:SetVisible(i <= capacity) end
        if button and i <= capacity then
            local record = prisoner_for_index(state, i)
            if record then
                local character = current_character(record.family_member_cqi)
                local name = prisoner_display_name(record)
                -- Changing the parent cell state can re-apply its child image
                -- state.  Set the frame state first, then bind the portrait so
                -- the native ContextImageSetter cannot immediately clear it.
                button:SetState(selected_prisoner_index == i and "selected" or "active")
                set_prisoner_portrait(slot_portraits[i], record, true)
                if slot_labels[i] then wp_visual_set_text(slot_labels[i], name) end
                if slot_frames[i] then
                    pcall(function() slot_frames[i]:SetImagePath(selected_prisoner_index == i
                        and VANILLA_UI_ROOT .. "athel_tamarha_prison_selected.png"
                        or VANILLA_UI_ROOT .. "athel_tamarha_prison_hover.png") end)
                end
                button:SetTooltipText(localised_format("wyccc_prison_runtime_prisoner_source_faction", {
                    NAME = name,
                    FACTION = faction_display_name(record.source_faction)
                }), true)
            else
                button:SetState("inactive")
                set_prisoner_portrait(slot_portraits[i], nil, false)
                if slot_labels[i] then wp_visual_set_text(slot_labels[i], localised("wyccc_prison_runtime_empty_cell")) end
                if slot_frames[i] then pcall(function() slot_frames[i]:SetImagePath(VANILLA_UI_ROOT .. "athel_tamarha_prison_empty.png") end) end
                button:SetTooltipText(localised("wyccc_prison_runtime_no_prisoners"), true)
            end
        end
    end

    local selected = prisoner_for_index(state, selected_prisoner_index)
    local action_available = selected and prison_action_available(state)
    local leader_requirement = selected and leader_action_requirement_text(state, selected)
    local leader_actions_available = selected and leader_actions_unlocked(state, selected)
    local can_recruit = action_available and leader_actions_available and (state.facilities.recruitment or 0) > 0
    local can_ransom = action_available and (state.facilities.ransom or 0) > 0
    local can_release = selected ~= nil
    local can_interrogate = action_available and leader_actions_available and (state.facilities.interrogation or 0) > 0
    local effective_recruitment_chance = selected and recruitment_chance(state, selected) or 0
    local interrogation_bonus, interrogation_experience_pool = interrogation_values(
        state.facilities.interrogation
    )
    if recruit_chance_text then
        recruit_chance_text:SetVisible(selected ~= nil)
        wp_visual_set_text(recruit_chance_text, selected and localised_format(
            "wyccc_prison_runtime_recruitment_chance", {CHANCE = effective_recruitment_chance}
        ) or "")
    end
    if recruit_button_uic then
        recruit_button_uic:SetVisible(selected ~= nil)
        recruit_button_uic:SetState(can_recruit and "active" or "inactive")
        local recruit_tooltip = not selected and localised("wyccc_prison_runtime_select_prisoner")
            or leader_requirement
            or (not action_available and localised("wyccc_prison_runtime_action_used"))
            or (can_recruit and localised_format("wyccc_prison_runtime_recruitment_chance", {
                CHANCE = effective_recruitment_chance
            }) or localised("wyccc_prison_runtime_requires_recruitment_room"))
        recruit_button_uic:SetTooltipText(recruit_tooltip, true)
    end
    if ransom_button_uic then
        ransom_button_uic:SetVisible(selected ~= nil)
        ransom_button_uic:SetState(can_ransom and "active" or "inactive")
        local ransom_tooltip = can_ransom and localised_format(
            "wyccc_prison_runtime_ransom_value", {AMOUNT = ransom_amount(state, selected)}
        ) or (not action_available and localised("wyccc_prison_runtime_action_used")
            or localised("wyccc_prison_runtime_requires_treasury"))
        ransom_button_uic:SetTooltipText(ransom_tooltip, true)
    end
    if release_button_uic then
        release_button_uic:SetVisible(selected ~= nil)
        release_button_uic:SetState(can_release and "active" or "inactive")
        release_button_uic:SetTooltipText(selected
            and localised("wyccc_prison_runtime_release_current_prisoner")
            or localised("wyccc_prison_runtime_select_prisoner"), true)
    end
    if interrogate_button_uic then
        interrogate_button_uic:SetVisible(selected ~= nil)
        interrogate_button_uic:SetState(can_interrogate and "active" or "inactive")
        local interrogate_tooltip = not selected and localised("wyccc_prison_runtime_select_prisoner")
            or leader_requirement
            or (not action_available and localised("wyccc_prison_runtime_action_used"))
            or (can_interrogate and localised_format("wyccc_prison_runtime_interrogation_value_active", {
                BONUS = interrogation_bonus,
                CHANCE = effective_recruitment_chance,
                EXPERIENCE = interrogation_experience_pool
            }) or localised("wyccc_prison_runtime_requires_interrogation_room"))
        interrogate_button_uic:SetTooltipText(interrogate_tooltip, true)
    end

    for facility, node in pairs(facility_nodes) do
        local level = state.facilities[facility] or 0
        if node then
            node:SetState(selected_facility_key == facility and "selected" or "active")
            node:SetTooltipText(facility_tooltip(facility, level, level + 1, faction), true)
        end
        if facility_frames[facility] then
            pcall(function() facility_frames[facility]:SetImagePath(selected_facility_key == facility
                and VANILLA_UI_ROOT .. "athel_tamarha_building_frame_selected.png"
                or VANILLA_UI_ROOT .. "athel_tamarha_building_frame_active.png") end)
        end
    end

    local detail_level = state.facilities[selected_facility_key] or 0
    -- Capacity/interrogation stay on the left; recruitment/ransom stay on the
    -- right, matching the original two-column outer-ring layout.
    local detail_on_left = selected_facility_key == "capacity"
        or selected_facility_key == "interrogation"
    local detail_side = detail_on_left and vanilla_left_side_uic or vanilla_right_side_uic
    if vanilla_left_side_uic then vanilla_left_side_uic:SetVisible(detail_on_left) end
    if vanilla_right_side_uic then vanilla_right_side_uic:SetVisible(not detail_on_left) end
    if vanilla_left_side_uic then
        local holder = find_uicomponent(vanilla_left_side_uic, "left_tooltip_holder")
        if holder then holder:SetVisible(detail_on_left) end
    end
    if vanilla_right_side_uic then
        local holder = find_uicomponent(vanilla_right_side_uic, "right_tooltip_holder")
        if holder then holder:SetVisible(not detail_on_left) end
    end
    if detail_side then
        local side_title = find_uicomponent(detail_side, "title_holder", "title")
        local tooltip_entry = find_uicomponent(detail_side,
            detail_on_left and "left_tooltip_holder" or "right_tooltip_holder", "tooltip_entry")
        local content = tooltip_entry and find_uicomponent(tooltip_entry, "tooltip_entry_content") or nil
        local icon = content and find_uicomponent(content, "building_icon") or nil
        local name = content and find_uicomponent(content, "dy_name") or nil
        local level_text = name and find_uicomponent(name, "dy_level") or nil
        local icon_name = selected_facility_key == "ransom" and "facility_treasury" or "facility_" .. selected_facility_key
        local icon_path = "ui/skins/wyccc_prison/" .. icon_name .. ".png"
        if side_title then wp_visual_set_text(side_title, facility_name(selected_facility_key)) end
        if icon then wp_visual_set_image(icon, icon_path) end
        if name then wp_visual_set_text(name, facility_name(selected_facility_key)) end
        if level_text then wp_visual_set_text(level_text, localised_format(
            "wyccc_prison_runtime_level", {LEVEL = detail_level, MAX_LEVEL = MAX_FACILITY_LEVEL}
        )) end

        -- The original effect list is a live template.  If it is left
        -- untouched, its design-time text ("dy_effect_bundle") is rendered
        -- verbatim.  Bind the current facility effect and its icon here so
        -- the selected card always describes the independent state machine.
        local effect_list = content and find_uicomponent(content, "effect_list") or nil
        if effect_list then
            effect_list:SetVisible(true)
            local effect_template = find_uicomponent(effect_list, "listview", "list_clip", "list_box", "effect_template")
            if effect_template then
                effect_template:SetVisible(true)
                wp_visual_set_text(effect_template, facility_effect_text(selected_facility_key, detail_level))
                effect_template:SetTooltipText(facility_effect_text(selected_facility_key, detail_level), true)
                local effect_icon = find_uicomponent(effect_template, "icon")
                if effect_icon then wp_visual_set_image(effect_icon, icon_path) end
            end
        end
        local unit_effect_template = content and find_uicomponent(content, "unit_effect_template") or nil
        if unit_effect_template then unit_effect_template:SetVisible(false) end

        local side_key = detail_on_left and "left" or "right"
        local side_actions = upgrade_action_buttons[side_key] or {}
        upgrade_action_buttons[side_key] = side_actions
        for level = 1, MAX_FACILITY_LEVEL do
            local upgrade_node = wp_find_upgrade_node(content, level)
            if upgrade_node then
                upgrade_node:SetVisible(true)
                local tooltip = facility_upgrade_tooltip(selected_facility_key, detail_level, level, faction)
                upgrade_node:SetTooltipText(tooltip, true)
                local upgrade_icon = find_uicomponent(upgrade_node, "building_icon")
                if upgrade_icon then wp_visual_set_image(upgrade_icon, icon_path) end

                local upgrade_name = find_uicomponent(upgrade_node, "dy_name")
                local upgrade_level = upgrade_name and find_uicomponent(upgrade_name, "dy_level") or nil
                if upgrade_name then wp_visual_set_text(upgrade_name, localised_format(
                    "wyccc_prison_runtime_facility_level", {
                        NAME = facility_name(selected_facility_key),
                        LEVEL = level
                    }
                )) end
                if upgrade_level then
                    local upgrade_status = level <= detail_level
                        and localised("wyccc_prison_runtime_facility_status_built")
                        or (level == detail_level + 1
                            and localised("wyccc_prison_runtime_facility_status_upgradable")
                            or localised("wyccc_prison_runtime_facility_status_locked"))
                    wp_visual_set_text(upgrade_level, upgrade_status)
                end

                local cost_uic = find_uicomponent(upgrade_node, "dy_pooled_resource_cost")
                if cost_uic then
                    -- Costs remain in the hover tooltip only.  The original
                    -- pooled-resource widget is deliberately hidden so the
                    -- custom prison uses the clean facility-tree presentation.
                    cost_uic:SetVisible(false)
                end

                -- Vanilla exposes a perform button on the first upgrade
                -- shard.  Keep it anchored by the TWUI, but make its click
                -- and hover text use the same independent facility state.
                local perform_button = find_uicomponent(upgrade_node, "button_perform")
                if perform_button then
                    local next_level = detail_level + 1
                    local is_next = level == next_level
                    local can_upgrade = is_next and faction:treasury() >= FACILITY_COSTS[level]
                    perform_button:SetVisible(is_next)
                    pcall(function() perform_button:SetState(can_upgrade and "active" or "inactive") end)
                    perform_button:SetTooltipText(tooltip, true)
                    local listener_name = "wyccc_prison_upgrade_side_"
                        .. (detail_on_left and "left" or "right") .. "_" .. tostring(level)
                    local button_address = perform_button:Address()
                    core:remove_listener(listener_name)
                    core:add_listener(listener_name, "ComponentLClickUp", function(context)
                        return context.string == "button_perform" and context.component == button_address
                    end, function()
                        local current = get_state(faction:name()).facilities[selected_facility_key] or 0
                        if current < MAX_FACILITY_LEVEL then upgrade(faction, selected_facility_key) end
                        refresh_ui()
                    end, true)
                end

                -- Only the first vanilla shard contains a perform button in
                -- the TWUI hierarchy.  Add the same native artwork to the
                -- level-2/3 shard so the available next level always has a
                -- visible arrow, while costs/effects remain tooltip-only.
                if level > 1 then
                    local target_level = level
                    local action_id = "wyccc_prison_upgrade_perform_"
                        .. side_key .. "_" .. tostring(target_level)
                    local action_button = side_actions[target_level]
                    -- The vanilla level-2/3 shards do not contain a
                    -- perform button.  Parent the custom arrow to the
                    -- 200px facility-name component itself.  The left
                    -- template has the name to the right of its shard, so
                    -- the original +140 center offset is correct there.  On
                    -- the mirrored right template the name block sits to the
                    -- left of the building shard.  Keep the arrow left of the
                    -- shard and below the two-line name, matching the vanilla
                    -- level-2/3 composition instead of letting it overlap the
                    -- facility icon.
                    local action_parent = upgrade_name or upgrade_node
                    local action_x = upgrade_name and (side_key == "left" and 140 or 80)
                        or (side_key == "left" and 119 or 221)
                    local action_y = upgrade_name and (side_key == "left" and 0 or 35)
                        or 49
                    if not action_button or not is_uicomponent(action_button) then
                        action_button = wp_visual_button(action_id, action_parent,
                            wp_scaled(64), wp_scaled(64), wp_scaled(action_x), wp_scaled(action_y), function()
                                local current = get_state(faction:name()).facilities[selected_facility_key] or 0
                                if target_level == current + 1 then
                                    upgrade(faction, selected_facility_key)
                                end
                                refresh_ui()
                        end)
                        side_actions[target_level] = action_button
                        if action_button then
                            pcall(function()
                                action_button:SetImagePath(VANILLA_UI_ROOT .. "dungeon_rite_button_active.png")
                            end)
                            wp_visual_image(action_id .. "_icon", action_button,
                                VANILLA_UI_ROOT .. "athel_tamarha_upgrade_icon.png",
                                wp_scaled(33), wp_scaled(33), 0, 0)
                        end
                    end
                    if action_button then
                        -- Re-apply the anchor after every layout pass because
                        -- the native tooltip can reset child docking when its
                        -- state changes.
                        place(action_button, wp_scaled(64), wp_scaled(64),
                            wp_scaled(action_x), wp_scaled(action_y))
                        local is_next = target_level == detail_level + 1
                        local can_upgrade = is_next and faction:treasury() >= FACILITY_COSTS[target_level]
                        action_button:SetVisible(is_next)
                        pcall(function()
                            action_button:SetState(can_upgrade and "active" or "inactive")
                            action_button:SetImagePath(VANILLA_UI_ROOT .. (can_upgrade
                                and "dungeon_rite_button_active.png"
                                or "dungeon_rite_button_inactive.png"))
                        end)
                        action_button:SetTooltipText(tooltip, true)
                    end
                end
            end
        end
    end
    -- These are the real vanilla upgrade-counter children.  Updating their
    -- state text preserves the original fonts/anchors while the numbers come
    -- from the independent four-facility state machine.
    if vanilla_upgrade_total_uic then
        wp_visual_set_text(vanilla_upgrade_total_uic,
            tostring(detail_level) .. "/" .. tostring(MAX_FACILITY_LEVEL))
    end
    if vanilla_upgrade_label_uic then
        wp_visual_set_text(vanilla_upgrade_label_uic,
            detail_level < MAX_FACILITY_LEVEL
                and localised("wyccc_prison_runtime_upgrade_available")
                or localised("wyccc_prison_runtime_max_level"))
    end
    if vanilla_upgrade_counter_uic then
        local next_level = detail_level + 1
        local can_upgrade = next_level <= MAX_FACILITY_LEVEL
            and faction:treasury() >= FACILITY_COSTS[next_level]
        vanilla_upgrade_counter_uic:SetState(can_upgrade and "active" or "inactive")
        local upgrade_tooltip = facility_upgrade_tooltip(
            selected_facility_key, detail_level, next_level, faction)
        vanilla_upgrade_counter_uic:SetTooltipText(upgrade_tooltip, true)
        if vanilla_upgrade_total_parent_uic then
            vanilla_upgrade_total_parent_uic:SetTooltipText(upgrade_tooltip, true)
        end
    end
    wp_hide_native_scrollbars()
    ui_refresh_in_progress = false
end

setup_ui = function()
    local faction_key = cm:get_local_faction_name(true)
    if not cross_culture_annex.is_prison_faction_key(faction_key) then return end
    local root = core:get_ui_root()
    local button_group = find_uicomponent(root, "hud_campaign", "faction_buttons_docker", "button_group_management")
    if not button_group or not is_uicomponent(button_group) then return end
    entry_button_uic = find_uicomponent(button_group, "wyccc_prison_entry_button")
    if not entry_button_uic then
        entry_button_uic = UIComponent(button_group:CreateComponent("wyccc_prison_entry_button", "ui/templates/round_hud_button_toggle.twui.xml"))
    else
        entry_button_uic = UIComponent(entry_button_uic)
    end
    entry_button_uic:SetCanResizeWidth(true)
    entry_button_uic:SetCanResizeHeight(true)
    entry_button_uic:Resize(55, 55)
    pcall(function() entry_button_uic:SetImagePath(VANILLA_UI_ROOT .. "icon_dungeon_of_athel_tamarha.png") end)
    entry_button_uic:SetTooltipText(localised("wyccc_prison_ui_entry_tooltip"), true)
    entry_button_uic:SetVisible(true)
    core:remove_listener("wyccc_prison_entry_click")
    core:add_listener("wyccc_prison_entry_click", "ComponentLClickUp", function(context)
        return context.string == "wyccc_prison_entry_button"
    end, toggle_panel, true)

    if panel_uic and is_uicomponent(panel_uic) and visual_ui_ready then return end
    panel_uic = core:get_or_create_component(
        cross_culture_annex.panel_key, cross_culture_annex.panel_ui_path)
    panel_uic:PropagatePriority(200)
    panel_uic:SetVisible(false)
    local sw, sh = core:get_screen_resolution()
    place(panel_uic, sw, sh, 0, 0)
    -- The empty TWUI host has no dimensions until its first layout pass.
    -- Keep every visual coordinate in the known screen coordinate space.
    local w, h = sw, sh
    wp_visual_image("wyccc_prison_visual_bg", panel_uic, VANILLA_UI_ROOT .. "dungeon_of_athel_tamarha_bg.png", sw, sh, 0, 0)
    wp_visual_image("wyccc_prison_visual_radial", panel_uic, VANILLA_UI_ROOT .. "dungeon_radial.png", 960, 540, 0, 0)
    wp_visual_image("wyccc_prison_visual_outer_ring", panel_uic, VANILLA_UI_ROOT .. "dungeon_outer_ring.png", 765, 765, 0, 0)
    wp_visual_image("wyccc_prison_visual_inner_ring", panel_uic, VANILLA_UI_ROOT .. "dungeon_inner_ring.png", 708, 708, 0, 0)
    wp_visual_image("wyccc_prison_visual_shards", panel_uic, VANILLA_UI_ROOT .. "athel_tamarha_top_shards.png", 267, 168, 0, -h / 2 + 80)
    wp_visual_image("wyccc_prison_visual_header_icon", panel_uic, VANILLA_UI_ROOT .. "dungeon_header_icon.png", 63, 87, 0, -h / 2 + 56)
    wp_visual_image("wyccc_prison_visual_header_line", panel_uic, VANILLA_UI_ROOT .. "dungeon_header_underline.png", 326, 72, 0, -h / 2 + 102)
    local title = core:get_or_create_component("wyccc_prison_visual_title", "ui/groovy/text/fe_default", panel_uic)
    place(title, 500, 42, 0, -h / 2 + 112)
    wp_visual_set_text(title, localised("wyccc_prison_ui_title"))
    title:SetVisible(true)
    local close = wp_visual_button("wyccc_prison_close", panel_uic, 40, 40, w / 2 - 55, -h / 2 + 48, hide_panel)
    if close then pcall(function() close:SetImagePath("ui/skins/default/icon_cross.png") end) end

    prisoner_slots = {}
    slot_portraits = {}
    slot_frames = {}
    slot_labels = {}
    local slot_positions = {{-125, -145}, {125, -145}, {-125, 95}, {125, 95}}
    for i = 1, 4 do
        local slot_index = i
        local button = wp_visual_button("wyccc_prisoner_slot_" .. tostring(i), panel_uic, 181, 184,
            slot_positions[i][1], slot_positions[i][2], function()
                selected_prisoner_index = slot_index
                refresh_ui()
            end)
        prisoner_slots[i] = button
        if button then
            pcall(function() button:SetImagePath(VANILLA_UI_ROOT .. "athel_tamarha_prison_bg.png") end)
            slot_portraits[i] = wp_visual_image("wyccc_prisoner_portrait_" .. tostring(i), button, VANILLA_UI_ROOT .. "prisoner_silhouette.png", 132, 132, 0, -8)
            slot_frames[i] = wp_visual_image("wyccc_prisoner_frame_" .. tostring(i), button, VANILLA_UI_ROOT .. "athel_tamarha_prison_empty.png", 181, 184, 0, 0)
            slot_labels[i] = core:get_or_create_component("wyccc_prisoner_label_" .. tostring(i), "ui/groovy/text/fe_default", button)
            place(slot_labels[i], 158, 26, 0, 70)
            wp_visual_set_text(slot_labels[i], localised("wyccc_prison_runtime_empty_cell"))
            slot_labels[i]:SetVisible(true)
        end
    end

    facility_buttons = {}
    facility_nodes = {}
    facility_frames = {}
    local facility_positions = {capacity = {-350, -230}, interrogation = {-350, 230}, recruitment = {350, -230}, ransom = {350, 230}}
    for _, facility in ipairs(FACILITIES) do
        local facility_key = facility
        local position = facility_positions[facility_key]
        local node = wp_visual_button("wyccc_prison_facility_node_" .. facility_key, panel_uic, 120, 120, position[1], position[2], function()
            selected_facility_key = facility_key
            refresh_ui()
        end)
        facility_nodes[facility_key] = node
        if node then
            local icon_name = facility_key == "ransom" and "facility_treasury" or "facility_" .. facility_key
            pcall(function() node:SetImagePath("ui/skins/wyccc_prison/" .. icon_name .. ".png") end)
            facility_frames[facility_key] = wp_visual_image("wyccc_prison_facility_frame_" .. facility_key, node, VANILLA_UI_ROOT .. "athel_tamarha_building_frame_active.png", 120, 120, 0, 0)
        end
        facility_buttons[facility_key] = {}
    end

    wp_visual_image("wyccc_prison_facility_detail_bg", panel_uic, VANILLA_UI_ROOT .. "athel_tamarha_top_shards.png", 400, 260, w / 2 - 230, 55)
    facility_detail_icon = wp_visual_image("wyccc_prison_facility_detail_icon", panel_uic, "ui/skins/wyccc_prison/facility_capacity.png", 92, 92, w / 2 - 380, 15)
    facility_detail_title = core:get_or_create_component("wyccc_prison_facility_detail_title", "ui/groovy/text/fe_default", panel_uic)
    place(facility_detail_title, 270, 34, w / 2 - 235, -35)
    facility_detail_title:SetVisible(true)
    facility_detail_text = core:get_or_create_component("wyccc_prison_facility_detail_text", "ui/groovy/text/fe_default", panel_uic)
    place(facility_detail_text, 320, 105, w / 2 - 185, 35)
    facility_detail_text:SetVisible(true)
    facility_upgrade_button = wp_visual_button("wyccc_prison_facility_upgrade", panel_uic, 64, 64, w / 2 - 55, 128, function()
        local f = cm:get_faction(cm:get_local_faction_name(true))
        local current_level = get_state(f:name()).facilities[selected_facility_key] or 0
        if current_level < MAX_FACILITY_LEVEL then upgrade(f, selected_facility_key) end
        refresh_ui()
    end)
    if facility_upgrade_button then
        pcall(function() facility_upgrade_button:SetImagePath(VANILLA_UI_ROOT .. "dungeon_rite_button_active.png") end)
        wp_visual_image("wyccc_prison_facility_upgrade_icon", facility_upgrade_button, VANILLA_UI_ROOT .. "dungeon_header_icon.png", 34, 46, 0, 0)
    end

    recruit_button_uic = wp_visual_action("wyccc_prison_action_recruit", VANILLA_UI_ROOT .. "prisoner_indoctrinate.png", -115, h / 2 - 80, function()
        local faction = cm:get_faction(cm:get_local_faction_name(true)); local state = get_state(faction:name()); local record = prisoner_for_index(state, selected_prisoner_index)
        if record then perform_recruit(faction, state, record); refresh_ui() end
    end)
    ransom_button_uic = wp_visual_action("wyccc_prison_action_ransom", VANILLA_UI_ROOT .. "prisoner_execute.png", -38, h / 2 - 80, function()
        local faction = cm:get_faction(cm:get_local_faction_name(true)); local state = get_state(faction:name()); local record = prisoner_for_index(state, selected_prisoner_index)
        if record and perform_ransom(faction, state, record) then selected_prisoner_index = 0; refresh_ui() end
    end)
    release_button_uic = wp_visual_action("wyccc_prison_action_release", "ui/skins/default/icon_cross.png", 38, h / 2 - 80, function()
        local faction = cm:get_faction(cm:get_local_faction_name(true)); local state = get_state(faction:name()); local record = prisoner_for_index(state, selected_prisoner_index)
        if record and perform_release(faction, state, record) then selected_prisoner_index = 0; refresh_ui() end
    end)
    interrogate_button_uic = wp_visual_action("wyccc_prison_action_interrogate", VANILLA_UI_ROOT .. "prisoner_interrogate.png", 115, h / 2 - 80, function()
        local faction = cm:get_faction(cm:get_local_faction_name(true)); local state = get_state(faction:name()); local record = prisoner_for_index(state, selected_prisoner_index)
        if record then grant_interrogation(faction, state, record); refresh_ui() end
    end)
    visual_ui_ready = true
    log("independent prison UI created with Athel Tamarha visual shell")
end

-- Rebind the local setup entry after all helper functions and state handles
-- have been declared.  This is the only setup implementation used at runtime.
setup_ui = function()
    local faction_key = cm:get_local_faction_name(true)
    if not cross_culture_annex.is_prison_faction_key(faction_key) then return end
    local root = core:get_ui_root()
    local button_group = find_uicomponent(root, "hud_campaign", "faction_buttons_docker", "button_group_management")
    if not button_group or not is_uicomponent(button_group) then return end
    entry_button_uic = find_uicomponent(button_group, "wyccc_prison_entry_button")
    if not entry_button_uic then
        entry_button_uic = UIComponent(button_group:CreateComponent("wyccc_prison_entry_button", "ui/templates/round_hud_button_toggle.twui.xml"))
    else
        entry_button_uic = UIComponent(entry_button_uic)
    end
    entry_button_uic:SetCanResizeWidth(true)
    entry_button_uic:SetCanResizeHeight(true)
    entry_button_uic:Resize(55, 55)
    pcall(function() entry_button_uic:SetImagePath(VANILLA_UI_ROOT .. "icon_dungeon_of_athel_tamarha.png") end)
    entry_button_uic:SetTooltipText(localised("wyccc_prison_ui_entry_tooltip"), true)
    entry_button_uic:SetVisible(true)
    core:remove_listener("wyccc_prison_entry_click")
    core:add_listener("wyccc_prison_entry_click", "ComponentLClickUp", function(context)
        return context.string == "wyccc_prison_entry_button"
    end, toggle_panel, true)

    if panel_uic and is_uicomponent(panel_uic) and visual_ui_ready then return end
    panel_uic = core:get_or_create_component(
        cross_culture_annex.panel_key, cross_culture_annex.panel_ui_path)
    panel_uic:PropagatePriority(200)
    panel_uic:SetVisible(false)
    local sw, sh = core:get_screen_resolution()
    visual_scale = math.min(sw / 1600, sh / 900)
    place(panel_uic, sw, sh, 0, 0)
    visual_ui_ready = false

    wp_visual_image("wyccc_prison_visual_bg", panel_uic, VANILLA_UI_ROOT .. "dungeon_of_athel_tamarha_bg.png", sw, sh, 0, 0)
    wp_visual_image("wyccc_prison_visual_outer_ring", panel_uic, VANILLA_UI_ROOT .. "dungeon_outer_ring_1.png", wp_scaled(1090), wp_scaled(1090), 0, wp_scaled(-3))
    wp_visual_image("wyccc_prison_visual_centre_ring", panel_uic, VANILLA_UI_ROOT .. "dungeon_outer_ring.png", wp_scaled(624), wp_scaled(624), 0, wp_scaled(3))
    wp_visual_image("wyccc_prison_visual_inner_ring", panel_uic, VANILLA_UI_ROOT .. "dungeon_inner_ring.png", wp_scaled(637), wp_scaled(637), wp_scaled(4), wp_scaled(-9))
    wp_visual_image("wyccc_prison_visual_prison_bg", panel_uic, VANILLA_UI_ROOT .. "athel_tamarha_prison_bg.png", wp_scaled(501), wp_scaled(501), wp_scaled(4), wp_scaled(-9))
    wp_visual_image("wyccc_prison_visual_header", panel_uic, VANILLA_UI_ROOT .. "dungeon_header_icon.png", wp_scaled(370), wp_scaled(78), 0, wp_scaled(-198))

    local title = core:get_or_create_component("wyccc_prison_visual_title", "ui/groovy/text/fe_default", panel_uic)
    place(title, wp_scaled(370), wp_scaled(30), 0, wp_scaled(-144))
    wp_visual_set_text(title, localised("wyccc_prison_ui_title"))
    title:SetVisible(true)

    local close = wp_visual_button("wyccc_prison_close", panel_uic, wp_scaled(56), wp_scaled(56), 0, wp_scaled(415), hide_panel)
    if close then
        pcall(function() close:SetImagePath(VANILLA_UI_ROOT .. "dungeon_rite_button_active.png") end)
        wp_visual_image("wyccc_prison_close_icon", close, "ui/skins/default/icon_check.png", wp_scaled(32), wp_scaled(32), 0, 0)
    end
    local info = wp_visual_button("wyccc_prison_info", panel_uic, wp_scaled(38), wp_scaled(38), wp_scaled(770), wp_scaled(-430), nil)
    if info then pcall(function() info:SetImagePath("ui/skins/default/icon_help.png") end) end

    prisoner_slots, slot_portraits, slot_frames, slot_labels = {}, {}, {}, {}
    local slot_positions = {{-92, -40}, {92, -40}, {-92, 125}, {92, 125}}
    for i = 1, 4 do
        local slot_index = i
        local button = wp_visual_button("wyccc_prisoner_slot_" .. tostring(i), panel_uic, wp_scaled(181), wp_scaled(184),
            wp_scaled(slot_positions[i][1]), wp_scaled(slot_positions[i][2]), function()
                selected_prisoner_index = slot_index
                refresh_ui()
            end)
        prisoner_slots[i] = button
        if button then
            pcall(function() button:SetImagePath(VANILLA_UI_ROOT .. "athel_tamarha_prison_bg.png") end)
            slot_portraits[i] = wp_visual_image("wyccc_prisoner_portrait_" .. tostring(i), button, VANILLA_UI_ROOT .. "prisoner_silhouette.png", wp_scaled(120), wp_scaled(120), 0, wp_scaled(-8))
            slot_frames[i] = wp_visual_image("wyccc_prisoner_frame_" .. tostring(i), button, VANILLA_UI_ROOT .. "athel_tamarha_prison_empty.png", wp_scaled(181), wp_scaled(184), 0, 0)
            slot_labels[i] = core:get_or_create_component("wyccc_prisoner_label_" .. tostring(i), "ui/groovy/text/fe_default", button)
            place(slot_labels[i], wp_scaled(158), wp_scaled(26), 0, wp_scaled(70))
            wp_visual_set_text(slot_labels[i], localised("wyccc_prison_runtime_empty_cell"))
            slot_labels[i]:SetVisible(true)
        end
    end

    facility_buttons, facility_nodes, facility_frames = {}, {}, {}
    local facility_positions = {capacity = {-285, -220}, recruitment = {-325, 20}, interrogation = {325, 20}, ransom = {285, 220}}
    for _, facility in ipairs(FACILITIES) do
        local facility_key = facility
        local position = facility_positions[facility_key]
        local node = wp_visual_button("wyccc_prison_facility_node_" .. facility_key, panel_uic, wp_scaled(109), wp_scaled(109),
            wp_scaled(position[1]), wp_scaled(position[2]), function()
                selected_facility_key = facility_key
                refresh_ui()
            end)
        facility_nodes[facility_key] = node
        if node then
            local icon_name = facility_key == "ransom" and "facility_treasury" or "facility_" .. facility_key
            pcall(function() node:SetImagePath("ui/skins/wyccc_prison/" .. icon_name .. ".png") end)
            facility_frames[facility_key] = wp_visual_image("wyccc_prison_facility_frame_" .. facility_key, node, VANILLA_UI_ROOT .. "athel_tamarha_building_frame_active.png", wp_scaled(109), wp_scaled(109), 0, 0)
        end
        facility_buttons[facility_key] = {}
    end

    facility_detail_icon = wp_visual_image("wyccc_prison_facility_detail_icon", panel_uic, "ui/skins/wyccc_prison/facility_capacity.png", wp_scaled(80), wp_scaled(80), wp_scaled(-675), wp_scaled(-175))
    facility_detail_title = core:get_or_create_component("wyccc_prison_facility_detail_title", "ui/groovy/text/fe_default", panel_uic)
    place(facility_detail_title, wp_scaled(300), wp_scaled(34), wp_scaled(-590), wp_scaled(-225))
    facility_detail_title:SetVisible(true)
    facility_detail_text = core:get_or_create_component("wyccc_prison_facility_detail_text", "ui/groovy/text/fe_default", panel_uic)
    place(facility_detail_text, wp_scaled(320), wp_scaled(155), wp_scaled(-590), wp_scaled(-105))
    facility_detail_text:SetVisible(true)

    wp_visual_image("wyccc_prison_upgrade_shards", panel_uic, VANILLA_UI_ROOT .. "athel_tamarha_top_shards.png", wp_scaled(267), wp_scaled(168), 0, wp_scaled(-350))
    facility_upgrade_button = wp_visual_button("wyccc_prison_facility_upgrade", panel_uic, wp_scaled(131), wp_scaled(131), 0, wp_scaled(-320), function()
        local f = cm:get_faction(cm:get_local_faction_name(true))
        local current_level = get_state(f:name()).facilities[selected_facility_key] or 0
        if current_level < MAX_FACILITY_LEVEL then upgrade(f, selected_facility_key) end
        refresh_ui()
    end)
    if facility_upgrade_button then pcall(function() facility_upgrade_button:SetImagePath(VANILLA_UI_ROOT .. "dungeon_rite_button_active.png") end) end
    facility_upgrade_level_text = core:get_or_create_component("wyccc_prison_upgrade_level", "ui/groovy/text/fe_default", panel_uic)
    place(facility_upgrade_level_text, wp_scaled(120), wp_scaled(60), 0, wp_scaled(-325))
    facility_upgrade_level_text:SetVisible(true)
    facility_upgrade_cost_text = core:get_or_create_component("wyccc_prison_upgrade_cost", "ui/groovy/text/fe_default", panel_uic)
    place(facility_upgrade_cost_text, wp_scaled(90), wp_scaled(24), wp_scaled(95), wp_scaled(-315))
    facility_upgrade_cost_text:SetVisible(false)

    recruit_button_uic = wp_visual_action("wyccc_prison_action_recruit", VANILLA_UI_ROOT .. "prisoner_indoctrinate.png", wp_scaled(-115), wp_scaled(220), function()
        local faction = cm:get_faction(cm:get_local_faction_name(true)); local state = get_state(faction:name()); local record = prisoner_for_index(state, selected_prisoner_index)
        if record then perform_recruit(faction, state, record); refresh_ui() end
    end)
    ransom_button_uic = wp_visual_action("wyccc_prison_action_ransom", VANILLA_UI_ROOT .. "prisoner_execute.png", wp_scaled(-38), wp_scaled(220), function()
        local faction = cm:get_faction(cm:get_local_faction_name(true)); local state = get_state(faction:name()); local record = prisoner_for_index(state, selected_prisoner_index)
        if record and perform_ransom(faction, state, record) then selected_prisoner_index = 0; refresh_ui() end
    end)
    release_button_uic = wp_visual_action("wyccc_prison_action_release", "ui/skins/default/icon_cross.png", wp_scaled(38), wp_scaled(220), function()
        local faction = cm:get_faction(cm:get_local_faction_name(true)); local state = get_state(faction:name()); local record = prisoner_for_index(state, selected_prisoner_index)
        if record and perform_release(faction, state, record) then selected_prisoner_index = 0; refresh_ui() end
    end)
    interrogate_button_uic = wp_visual_action("wyccc_prison_action_interrogate", VANILLA_UI_ROOT .. "prisoner_interrogate.png", wp_scaled(115), wp_scaled(220), function()
        local faction = cm:get_faction(cm:get_local_faction_name(true)); local state = get_state(faction:name()); local record = prisoner_for_index(state, selected_prisoner_index)
        if record then grant_interrogation(faction, state, record); refresh_ui() end
    end)
    visual_ui_ready = true
    log("independent prison UI created with vanilla dungeon geometry")
end
-- Final runtime binding: use the actual vanilla Athel Tamarha layout instead
-- of rebuilding its geometry with script_dummy children.  The original TWUI
-- supplies the movie callback, screen-sized root, rune rings, shard upgrade
-- tree and button state artwork.  Only the data-bearing prison slots,
-- facility icons and action callbacks are custom overlays.
setup_ui = function()
    local faction_key = cm:get_local_faction_name(true)
    if not cross_culture_annex.is_prison_faction_key(faction_key) then return end

    local root = core:get_ui_root()
    local button_group = find_uicomponent(root, "hud_campaign", "faction_buttons_docker", "button_group_management")
    if not button_group or not is_uicomponent(button_group) then return end

    entry_button_uic = find_uicomponent(button_group, "wyccc_prison_entry_button")
    if not entry_button_uic then
        entry_button_uic = UIComponent(button_group:CreateComponent(
            "wyccc_prison_entry_button", "ui/templates/round_hud_button_toggle.twui.xml"))
    else
        entry_button_uic = UIComponent(entry_button_uic)
    end
    entry_button_uic:SetCanResizeWidth(true)
    entry_button_uic:SetCanResizeHeight(true)
    entry_button_uic:Resize(55, 55)
    pcall(function() entry_button_uic:SetImagePath(VANILLA_UI_ROOT .. "icon_dungeon_of_athel_tamarha.png") end)
    entry_button_uic:SetTooltipText(localised("wyccc_prison_ui_entry_tooltip"), true)
    entry_button_uic:SetVisible(true)
    core:remove_listener("wyccc_prison_entry_click")
    core:add_listener("wyccc_prison_entry_click", "ComponentLClickUp", function(context)
        return context.string == "wyccc_prison_entry_button"
    end, toggle_panel, true)

    if panel_uic and is_uicomponent(panel_uic) and visual_ui_ready then return end

    local ok, created = pcall(function()
        return core:get_or_create_component(
            cross_culture_annex.panel_key, cross_culture_annex.panel_ui_path)
    end)
    if not ok or not created or not is_uicomponent(created) then
        log("vanilla dungeon TWUI could not be created: " .. tostring(created))
        visual_ui_ready = false
        return
    end
    panel_uic = created
    panel_uic:PropagatePriority(200)
    panel_uic:SetVisible(false)
    -- The vanilla root is ScreenSizedComponent-driven.  Do not resize it
    -- from Lua: doing so is what previously stretched the ring and displaced
    -- every label at non-1600x900 resolutions.
    visual_scale = 1

    vanilla_title_uic = find_uicomponent(panel_uic, "centre_holder", "ward_of_eternity",
        "header_parent", "title_holder", "title")
    vanilla_close_uic = find_uicomponent(panel_uic, "button_close")
    vanilla_info_uic = find_uicomponent(panel_uic, "button_info_holder", "button_info")
    -- Omit the top-center vanilla "upgrades available" summary.  Upgrade
    -- cost/effect details are shown only when hovering an individual shard.
    vanilla_upgrade_total_parent_uic = find_uicomponent(panel_uic, "centre_holder", "upgrade_total_parent")
    if vanilla_upgrade_total_parent_uic and is_uicomponent(vanilla_upgrade_total_parent_uic) then
        vanilla_upgrade_total_parent_uic:SetVisible(false)
    end
    core:remove_listener("wyccc_prison_vanilla_upgrade")
    vanilla_upgrade_total_parent_uic = nil
    vanilla_upgrade_counter_uic = nil
    vanilla_warden_supply_uic = nil
    vanilla_upgrade_total_uic = nil
    vanilla_upgrade_label_uic = nil
    vanilla_upgrade_icon_uic = nil
    vanilla_left_side_uic = find_uicomponent(panel_uic, "outer_ring_content_holder", "left_side")
    vanilla_right_side_uic = find_uicomponent(panel_uic, "outer_ring_content_holder", "right_side")
    wp_hide_native_scrollbars()

    if vanilla_title_uic then
        vanilla_title_uic:SetVisible(true)
        wp_visual_set_text(vanilla_title_uic, localised("wyccc_prison_ui_title"))
    end
    if vanilla_close_uic then
        vanilla_close_uic:SetVisible(true)
        core:remove_listener("wyccc_prison_vanilla_close")
        core:add_listener("wyccc_prison_vanilla_close", "ComponentLClickUp", function(context)
            return context.string == "button_close"
        end, hide_panel, true)
    end
    if vanilla_info_uic then vanilla_info_uic:SetVisible(true) end
    if vanilla_left_side_uic then vanilla_left_side_uic:SetVisible(true) end
    if vanilla_right_side_uic then vanilla_right_side_uic:SetVisible(true) end

    -- The template cell is the original 181x184 prison card.  Copying it keeps
    -- the portrait clip, frame, typography and action-holder anchors exact;
    -- only the CCO context and Lua listeners below are custom.
    local vanilla_template_cell = find_uicomponent(panel_uic, "centre_holder", "ward_of_eternity",
        "prison_cells_parent", "template_cell")
    local cells_parent = find_uicomponent(panel_uic, "centre_holder", "ward_of_eternity", "prison_cells_parent")
    local native_cells = {}
    if vanilla_template_cell and cells_parent then
        vanilla_template_cell:SetVisible(true)
        native_cells[1] = vanilla_template_cell
        for i = 2, 4 do
            local copy = nil
            pcall(function() copy = UIComponent(vanilla_template_cell:CopyComponent("wyccc_prison_cell_" .. tostring(i))) end)
            if copy and is_uicomponent(copy) then
                copy:SetVisible(true)
                native_cells[i] = copy
            end
        end
    end
    local vanilla_left_room = find_uicomponent(panel_uic, "outer_ring_content_holder", "sentinel_list", "left_room_template")
    local vanilla_right_room = find_uicomponent(panel_uic, "outer_ring_content_holder", "watchers_list", "right_room_template")
    if vanilla_left_room then vanilla_left_room:SetVisible(false) end
    if vanilla_right_room then vanilla_right_room:SetVisible(false) end

    prisoner_slots, slot_portraits, slot_frames, slot_labels = {}, {}, {}, {}
    for i = 1, 4 do
        local slot_index = i
        local cell = native_cells[i]
        prisoner_slots[i] = cell
        if cell then
            local cell_id = i == 1 and "template_cell" or "wyccc_prison_cell_" .. tostring(i)
            slot_portraits[i] = find_uicomponent(cell, "portrait_clip", "commander_portrait")
            slot_frames[i] = nil
            slot_labels[i] = nil
            debug_log("portrait component slot=" .. tostring(i)
                .. ", found=" .. tostring(slot_portraits[i] ~= nil)
                .. ", cell=" .. tostring(cell_id))
            core:remove_listener("wyccc_prison_cell_click_" .. tostring(i))
            core:add_listener("wyccc_prison_cell_click_" .. tostring(i), "ComponentLClickUp", function(context)
                return context.string == cell_id
            end, function()
                selected_prisoner_index = slot_index
                refresh_ui()
            end, true)
        end
    end

    -- The standalone TWUI already contains the original two-column outer-ring
    -- facility tree and its selected/hover/inactive frames.  Reuse those
    -- components directly; only their click listeners and state text are
    -- owned by this independent prison script.
    facility_buttons, facility_nodes, facility_frames = {}, {}, {}
    local facility_paths = {
        capacity = {"sentinel_list", "wyccc_prison_facility_capacity"},
        interrogation = {"sentinel_list", "wyccc_prison_facility_interrogation"},
        recruitment = {"watchers_list", "wyccc_prison_facility_recruitment"},
        ransom = {"watchers_list", "wyccc_prison_facility_ransom"}
    }
    for _, facility in ipairs(FACILITIES) do
        local facility_key = facility
        local path = facility_paths[facility_key]
        local node = find_uicomponent(panel_uic, "outer_ring_content_holder", path[1], path[2])
        facility_nodes[facility_key] = node
        facility_buttons[facility_key] = {}
        if node then
            node:SetVisible(true)
            core:remove_listener("wyccc_prison_facility_click_" .. facility_key)
            core:add_listener("wyccc_prison_facility_click_" .. facility_key, "ComponentLClickUp", function(context)
                return context.string == path[2]
            end, function()
                selected_facility_key = facility_key
                refresh_ui()
            end, true)
        end
    end

    -- Detail cards and upgrade shards are part of left_side/right_side in the
    -- TWUI.  Keep the legacy handles nil so refresh_ui never lays a second,
    -- misaligned text card over the original one.
    facility_detail_icon = nil
    facility_detail_title = nil
    facility_detail_text = nil

    recruit_button_uic = wp_visual_action("wyccc_prison_action_recruit",
        VANILLA_UI_ROOT .. "prisoner_indoctrinate.png", -96, 365, function()
            local faction = cm:get_faction(cm:get_local_faction_name(true)); local state = get_state(faction:name())
            local record = prisoner_for_index(state, selected_prisoner_index)
            if record then perform_recruit(faction, state, record); refresh_ui() end
        end)
    ransom_button_uic = wp_visual_action("wyccc_prison_action_ransom",
        VANILLA_UI_ROOT .. "prisoner_execute.png", -32, 365, function()
            local faction = cm:get_faction(cm:get_local_faction_name(true)); local state = get_state(faction:name())
            local record = prisoner_for_index(state, selected_prisoner_index)
            if record and perform_ransom(faction, state, record) then selected_prisoner_index = 0; refresh_ui() end
        end)
    release_button_uic = wp_visual_action("wyccc_prison_action_release",
        "ui/skins/default/icon_cross.png", 32, 365, function()
            local faction = cm:get_faction(cm:get_local_faction_name(true)); local state = get_state(faction:name())
            local record = prisoner_for_index(state, selected_prisoner_index)
            if record and perform_release(faction, state, record) then selected_prisoner_index = 0; refresh_ui() end
        end)
    interrogate_button_uic = wp_visual_action("wyccc_prison_action_interrogate",
        VANILLA_UI_ROOT .. "prisoner_interrogate.png", 96, 365, function()
            local faction = cm:get_faction(cm:get_local_faction_name(true)); local state = get_state(faction:name())
            local record = prisoner_for_index(state, selected_prisoner_index)
            if record then grant_interrogation(faction, state, record); refresh_ui() end
        end)

    -- Keep the current character's effective recruitment rate directly below
    -- the four action buttons, matching the red-box position in the reference
    -- layout.  It is hidden until a prisoner is selected; upgrade costs remain
    -- tooltip-only as requested.
    recruit_chance_text = core:get_or_create_component(
        "wyccc_prison_recruit_chance", "ui/groovy/text/fe_default", panel_uic)
    -- Keep the rate below the action row.  The requested final alignment is
    -- 30px left of the previous 130px anchor.
    place(recruit_chance_text, 300, 34, 100, 415)
    recruit_chance_text:SetVisible(false)

    visual_ui_ready = true
    refresh_ui()
    log("independent prison UI bound to vanilla dungeon_of_athel_tamarha TWUI")
end

-- ===== zzz_czx_prison_default 补丁：回合结束自动招降 =====
-- 玩家回合结束时，若本回合天牢操作未使用，
-- 对第一个可招降的囚徒调用本文件自己的 perform_recruit（含成功率判定），
-- 与手动点击招降按钮完全等价；不模拟任何 UI 操作。
core:add_listener(
    "czx_prison_auto_recruit_turn_end",
    "FactionTurnEnd",
    function(context)
        local faction = context:faction();
        return faction ~= nil and faction:is_human();
    end,
    function(context)
        local faction = context:faction();
        if not safe_interface(faction) then return end;
        local state = get_state(faction:name());
        if not state then return end;
        if not prison_action_available(state) then return end;
        if (state.facilities.recruitment or 0) < 1 then return end;
        for _, record in ipairs(state.prisoners or {}) do
            if leader_actions_unlocked(state, record) then
                perform_recruit(faction, state, record);
                break;
            end;
        end;
    end,
    true
);
