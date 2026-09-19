---------------------------------------------------------------------------------------------
-- czx_battle_auto_ability.lua
-- Auto-cast non-passive special abilities for delegated (AI-controlled) player units.
-- Complements AI General-style delegation: planner units never self-cast, so we poll and
-- fire ready abilities through their script_unit's unitcontroller (order + release_control,
-- which does not detach the unit from its ai_planner).
---------------------------------------------------------------------------------------------

local CONFIG = {
    enabled          = true,
    poll_ms          = 3000,    -- scan interval
    retry_ms         = 20000,   -- min delay between attempts of the same ability on the same unit
    cast_spells      = true,    -- false = skip abilities with mana_cost > 0
    engage_range_m   = 120,     -- only attempt casts when nearest enemy is within this distance (m)
    unit_keys        = {},      -- non-empty = only these unit keys auto-cast, e.g. {"czx_dgm_wargreymon"}
    banned_abilities = {},      -- ability keys never auto-cast
    auto_cast        = false,   -- master switch: false = never call perform_special_ability (sim-freeze kill switch)
    cast_on_summons  = false,   -- summoned units despawn mid-effect and can wedge the sim; skip their abilities
    cast_quiet_ms    = 6000,    -- after a successful cast, suppress task orders on that unit this long
    -- idle-kicker: delegated units the planner leaves standing around get nudged
    -- toward the nearest enemy. Ordering an already-idle unit interrupts nothing.
    idle_kick        = true,
    idle_kick_after_s= 3,       -- unit must stay continuously idle this long first
    order_retry_ms   = 6000,    -- min gap between task orders to the same unit
                                -- (shorter than ability retry — re-targeting a
                                -- unit whose enemy just died must be fast)
    idle_kick_range_m= 400,     -- only nudge if nearest enemy within this distance
    -- doctrine engine: pick a battle plan from delegated army composition each
    -- tick, then run per-role behaviours. "auto" detects; or force a doctrine.
    doctrine         = "auto",  -- "auto" | "gunline" | "balanced" | "rush" | "kite" | "none"
    gunline_min_share= 0.35,    -- auto: gunline if >=35% of delegated units carry ammo
    rush_max_shooter_share = 0.15, -- auto: rush if <=15% carry ammo
    kite_min_mobile_share  = 0.70, -- auto: kite if >=70% are cav/flyers
    -- role classification thresholds
    cav_min_speed    = 60,      -- fast_speed() >= this counts as cavalry-class
    artillery_min_range = 250,  -- missile_range() >= this counts as artillery
    -- screen radii (gunline tight / balanced loose)
    intercept_radius_m = 110,   -- screens attack enemies within this of themselves
    protect_radius_m = 100,     -- ... or within this of a delegated ranged unit
    leash_radius_m   = 160,     -- screens farther than this from the line fall back toward it
    bal_intercept_radius_m = 150,
    bal_leash_radius_m   = 220,
    cav_intercept_radius_m = 200, -- cav reserve intercepts threats further out
    flank_hunt_range_m = 400,   -- cav in non-gunline doctrines hunt enemy shooters within this
    flyer_hunt_range_m = 500,   -- flyers hunt enemy flyers/artillery within this
    shooter_hold_mult  = 1.3,   -- gunline shooters only attack enemies within missile_range * this
    -- auto-delegation: hand the whole local army to a script_ai_planner so the
    -- doctrine engine works standalone (no AI General needed). Units the player
    -- takes back via vanilla group UI are never re-delegated.
    auto_delegate    = true,
    delegate_after_ms= 3000,    -- wait this long before creating the planner
    focus_cap        = 3,       -- max delegated units ordered onto the same target per tick
    -- planner directive: an orderless planner drops its units (observed: whole
    -- army leaked out of ai-control within ~3min), so always keep a standing
    -- order on it. rush/kite = attack the front-most enemy; hold doctrines =
    -- defend_position on the group centre (same as the vanilla defend button).
    directive_refresh_ms = 20000, -- re-issue/retarget this often
    defend_radius_m  = 120,       -- radius for defend_position
    -- reclaim fingerprint: OUR uc orders flip is_ai_controlled=false (script
    -- control) and planner orders call release_control() first — the flag is
    -- useless as an ownership signal. Ownership is the managed[] set; the only
    -- trustworthy player-takeover evidence is a fresh ordered_position the
    -- engine got while the unit was NOT under AI control.
    order_grace_ms   = 9000,      -- after OUR uc order, ordered_position drift
                                  --   is just the order executing — wait this long
    reclaim_move_m   = 30,        -- ordered_position moved this far past grace
                                  --   = a fresh player order -> reclaim
    -- hotkey handoff (AI General-style, engine ShortcutTriggered events):
    -- bind "Save Camera Bookmark" keys in game settings, select unit cards,
    -- press to move them between AI and player control.
    hotkey_toggle    = "camera_bookmark_save0", -- toggle selected AI<->player
    hotkey_override  = "camera_bookmark_save6", -- temp override; returns when idle
    override_grace_s = 20,        -- min battle-seconds before idle can end an override
    override_idle_s  = 10,        -- overridden unit returns after this much idle time
    -- command-event reclaim: UI order commands landing on a delegated unit
    -- outside our task pass can only be the player -> instant reclaim.
    cmd_reclaim      = true,
    cmd_probe        = true,      -- log first events per command name (schema verify)
    -- tactical micro (community-informed)
    cycle_charge     = true,      -- cav pulls out after engagement, re-charges
    charge_fight_ms  = 9000,      -- stay in melee this long before pulling out
    charge_regroup_ms= 6000,      -- regroup this long before re-charging
    charge_pull_m    = 50,        -- pull-out distance from the target
    kite_fallback    = true,      -- shooters retreat when a melee enemy closes in
    kite_threat_m    = 30,        -- enemy this close triggers fallback
    kite_dest_m      = 60,        -- fallback distance from the threat
    wounded_pullout  = true,      -- badly hurt high-value units hop out of melee
    wounded_hp       = 0.35,      -- unary_hitpoints below this = wounded
    wounded_pull_m   = 80,        -- disengage distance when caught in melee
    wounded_retry_ms = 12000,     -- cooldown between disengage hops
    dodge            = true,      -- scatter units out of enemy ability AoE
    dodge_radius_m   = 45,        -- scatter if within this of the ability target
    dodge_dest_m     = 60,        -- scatter destination distance from blast centre
    dodge_cooldown_ms= 8000,      -- per-unit dodge order throttle
    -- autotest driver: simulate player micro so handoff/reclaim paths get
    -- exercised without a human at the controls. DISABLE for normal play.
    test_sim         = false, -- master switch for the sim cycles below
    test_speed       = 4,         -- bm:modify_battle_speed multiplier at start
    test_batch       = 4,         -- units grabbed per sim cycle
    test_cycle_ms    = 25000,     -- pause between cycles
    test_verify_ms   = 15000,     -- how long to wait for a transition before
                                  --   declaring it missed
    -- v1.5 community-informed additions
    harass_range_m   = 160,       -- mounted shooters engage within this radius
    rundown_range_m  = 120,       -- mobile units finish routing enemies inside this
}

-- ABILITY_FLAGS[ability_key] = "mask,recharge_seconds"
-- mask bits: 1=target_ground 2=target_enemies 4=target_friends 8=self 16=spell(mana_cost>0)
local ABILITY_FLAGS = {
    ["czx_ability_cishe_spine_volley"] = "8,90",
    ["czx_ability_feilong_glaive_storm"] = "8,90",
    ["czx_ability_gou_swarm_frenzy"] = "8,90",
    ["czx_ability_leishou_burrow_charge"] = "3,90",
    ["czx_ability_zhanglang_acid_spray"] = "2,60",
    ["czx_dgm_ab_aerovdramon_1"] = "8,90",
    ["czx_dgm_ab_aerovdramon_2"] = "2,60",
    ["czx_dgm_ab_aerovdramon_3"] = "2,60",
    ["czx_dgm_ab_agumon_1"] = "2,70",
    ["czx_dgm_ab_agumon_2"] = "8,90",
    ["czx_dgm_ab_agumon_3"] = "2,70",
    ["czx_dgm_ab_alphamon_1"] = "8,90",
    ["czx_dgm_ab_alphamon_2"] = "0,90",
    ["czx_dgm_ab_angemon_1"] = "8,90",
    ["czx_dgm_ab_angemon_2"] = "2,65",
    ["czx_dgm_ab_angemon_3"] = "3,90",
    ["czx_dgm_ab_angewomon_1"] = "2,60",
    ["czx_dgm_ab_angewomon_2"] = "2,60",
    ["czx_dgm_ab_angewomon_3"] = "8,90",
    ["czx_dgm_ab_apocalymon_1"] = "3,90",
    ["czx_dgm_ab_apocalymon_2"] = "8,90",
    ["czx_dgm_ab_apocalymon_3"] = "8,90",
    ["czx_dgm_ab_birdramon_1"] = "2,65",
    ["czx_dgm_ab_birdramon_2"] = "2,65",
    ["czx_dgm_ab_biyomon_1"] = "2,70",
    ["czx_dgm_ab_biyomon_2"] = "2,70",
    ["czx_dgm_ab_blitzgreymon_1"] = "2,55",
    ["czx_dgm_ab_blitzgreymon_2"] = "8,90",
    ["czx_dgm_ab_chaosdramon_1"] = "2,55",
    ["czx_dgm_ab_chaosdramon_2"] = "2,55",
    ["czx_dgm_ab_cresgarurumon_1"] = "8,90",
    ["czx_dgm_ab_cresgarurumon_2"] = "8,90",
    ["czx_dgm_ab_dorugamon_1"] = "2,65",
    ["czx_dgm_ab_dorugamon_2"] = "8,90",
    ["czx_dgm_ab_dorugoramon_1"] = "2,55",
    ["czx_dgm_ab_dorugoramon_2"] = "8,90",
    ["czx_dgm_ab_dorumon_1"] = "2,70",
    ["czx_dgm_ab_dorumon_2"] = "8,90",
    ["czx_dgm_ab_duramon_1"] = "8,90",
    ["czx_dgm_ab_duramon_2"] = "2,60",
    ["czx_dgm_ab_durandamon_1"] = "8,90",
    ["czx_dgm_ab_durandamon_2"] = "8,90",
    ["czx_dgm_ab_fairymon_1"] = "3,90",
    ["czx_dgm_ab_fairymon_2"] = "3,90",
    ["czx_dgm_ab_fairymon_3"] = "8,90",
    ["czx_dgm_ab_fujinmon_1"] = "8,90",
    ["czx_dgm_ab_fujinmon_2"] = "3,90",
    ["czx_dgm_ab_gabumon_1"] = "2,70",
    ["czx_dgm_ab_gabumon_2"] = "8,90",
    ["czx_dgm_ab_gabumon_3"] = "8,90",
    ["czx_dgm_ab_gallantmon_1"] = "8,90",
    ["czx_dgm_ab_gallantmon_2"] = "8,90",
    ["czx_dgm_ab_gallantmon_3"] = "8,90",
    ["czx_dgm_ab_gallantmoncm_1"] = "8,90",
    ["czx_dgm_ab_gallantmoncm_2"] = "8,90",
    ["czx_dgm_ab_gallantmonx_1"] = "8,90",
    ["czx_dgm_ab_gallantmonx_2"] = "8,90",
    ["czx_dgm_ab_garudamon_1"] = "2,60",
    ["czx_dgm_ab_garudamon_2"] = "3,90",
    ["czx_dgm_ab_garurumon_1"] = "2,65",
    ["czx_dgm_ab_garurumon_2"] = "8,90",
    ["czx_dgm_ab_gatomon_1"] = "8,90",
    ["czx_dgm_ab_gatomon_2"] = "8,90",
    ["czx_dgm_ab_gatomon_3"] = "0,90",
    ["czx_dgm_ab_geogreymon_1"] = "8,90",
    ["czx_dgm_ab_geogreymon_2"] = "2,65",
    ["czx_dgm_ab_gomamon_1"] = "2,70",
    ["czx_dgm_ab_gomamon_2"] = "8,90",
    ["czx_dgm_ab_greymon_1"] = "2,65",
    ["czx_dgm_ab_greymon_2"] = "8,90",
    ["czx_dgm_ab_greymon_3"] = "8,90",
    ["czx_dgm_ab_growlmon_1"] = "8,90",
    ["czx_dgm_ab_growlmon_2"] = "2,65",
    ["czx_dgm_ab_guilmon_1"] = "2,70",
    ["czx_dgm_ab_guilmon_2"] = "8,90",
    ["czx_dgm_ab_guilmon_3"] = "8,90",
    ["czx_dgm_ab_heraklekabuterimon_1"] = "2,55",
    ["czx_dgm_ab_heraklekabuterimon_2"] = "8,90",
    ["czx_dgm_ab_hououmon_1"] = "8,90",
    ["czx_dgm_ab_hououmon_2"] = "2,55",
    ["czx_dgm_ab_ikkakumon_1"] = "2,65",
    ["czx_dgm_ab_ikkakumon_2"] = "8,90",
    ["czx_dgm_ab_imperialdm_1"] = "8,90",
    ["czx_dgm_ab_imperialdm_2"] = "2,50",
    ["czx_dgm_ab_imperialfm_1"] = "2,50",
    ["czx_dgm_ab_imperialfm_2"] = "8,90",
    ["czx_dgm_ab_imperialpm_1"] = "8,90",
    ["czx_dgm_ab_jesmon_1"] = "8,90",
    ["czx_dgm_ab_jesmon_2"] = "2,50",
    ["czx_dgm_ab_jesmonx_1"] = "8,90",
    ["czx_dgm_ab_jesmonx_2"] = "2,50",
    ["czx_dgm_ab_jetsilphymon_1"] = "2,60",
    ["czx_dgm_ab_jetsilphymon_2"] = "3,90",
    ["czx_dgm_ab_kabuterimon_1"] = "2,65",
    ["czx_dgm_ab_kabuterimon_2"] = "2,65",
    ["czx_dgm_ab_kyubimon_1"] = "2,65",
    ["czx_dgm_ab_kyubimon_2"] = "2,65",
    ["czx_dgm_ab_lalamon_1"] = "2,70",
    ["czx_dgm_ab_lalamon_2"] = "8,90",
    ["czx_dgm_ab_lalamon_3"] = "8,90",
    ["czx_dgm_ab_lilamon_1"] = "2,60",
    ["czx_dgm_ab_lilamon_2"] = "8,90",
    ["czx_dgm_ab_lilamon_3"] = "8,90",
    ["czx_dgm_ab_lilimon_1"] = "2,60",
    ["czx_dgm_ab_lilimon_2"] = "0,90",
    ["czx_dgm_ab_lilimon_3"] = "0,90",
    ["czx_dgm_ab_lucemon_1"] = "8,90",
    ["czx_dgm_ab_lucemon_2"] = "8,90",
    ["czx_dgm_ab_lucemonfm_1"] = "3,90",
    ["czx_dgm_ab_lucemonfm_2"] = "8,90",
    ["czx_dgm_ab_machinedramon_1"] = "2,55",
    ["czx_dgm_ab_machinedramon_2"] = "8,90",
    ["czx_dgm_ab_magnaangemon_1"] = "8,90",
    ["czx_dgm_ab_magnaangemon_2"] = "8,90",
    ["czx_dgm_ab_magnadramon_1"] = "8,90",
    ["czx_dgm_ab_magnadramon_2"] = "8,90",
    ["czx_dgm_ab_magnamon_1"] = "2,50",
    ["czx_dgm_ab_magnamon_2"] = "8,90",
    ["czx_dgm_ab_magnamonx_1"] = "2,50",
    ["czx_dgm_ab_magnamonx_2"] = "8,90",
    ["czx_dgm_ab_mastemon_1"] = "2,50",
    ["czx_dgm_ab_mastemon_2"] = "0,90",
    ["czx_dgm_ab_mastemon_3"] = "8,90",
    ["czx_dgm_ab_megakabuterimon_1"] = "2,60",
    ["czx_dgm_ab_megaseadramon_1"] = "2,60",
    ["czx_dgm_ab_megaseadramon_2"] = "3,90",
    ["czx_dgm_ab_metalgarurumon_1"] = "2,55",
    ["czx_dgm_ab_metalgarurumon_2"] = "2,55",
    ["czx_dgm_ab_metalgarurumon_3"] = "8,90",
    ["czx_dgm_ab_metalgarurumonx_1"] = "2,50",
    ["czx_dgm_ab_metalgarurumonx_2"] = "2,50",
    ["czx_dgm_ab_metalgreymon_1"] = "2,60",
    ["czx_dgm_ab_metalgreymon_2"] = "8,90",
    ["czx_dgm_ab_metalseadramon_1"] = "2,55",
    ["czx_dgm_ab_metalseadramon_2"] = "8,90",
    ["czx_dgm_ab_metaltyranomon_1"] = "2,60",
    ["czx_dgm_ab_metaltyranomon_2"] = "2,60",
    ["czx_dgm_ab_omegamon_1"] = "8,90",
    ["czx_dgm_ab_omegamon_2"] = "2,50",
    ["czx_dgm_ab_omegamonab_1"] = "8,90",
    ["czx_dgm_ab_omegamonab_2"] = "2,50",
    ["czx_dgm_ab_omegamonas_1"] = "8,90",
    ["czx_dgm_ab_omegamonas_2"] = "2,50",
    ["czx_dgm_ab_omegamond_1"] = "8,90",
    ["czx_dgm_ab_omegamond_2"] = "8,90",
    ["czx_dgm_ab_omegamonm_1"] = "8,90",
    ["czx_dgm_ab_omegamonm_2"] = "2,50",
    ["czx_dgm_ab_omegamonx_1"] = "8,90",
    ["czx_dgm_ab_omegamonx_2"] = "8,90",
    ["czx_dgm_ab_omegamonx_3"] = "2,50",
    ["czx_dgm_ab_ophanimon_1"] = "2,50",
    ["czx_dgm_ab_ophanimon_2"] = "2,50",
    ["czx_dgm_ab_ophanimonfm_1"] = "8,90",
    ["czx_dgm_ab_ophanimonfm_2"] = "8,90",
    ["czx_dgm_ab_paildramon_1"] = "2,60",
    ["czx_dgm_ab_paildramon_2"] = "8,90",
    ["czx_dgm_ab_palmon_1"] = "0,90",
    ["czx_dgm_ab_palmon_2"] = "2,70",
    ["czx_dgm_ab_patamon_1"] = "2,70",
    ["czx_dgm_ab_patamon_2"] = "8,90",
    ["czx_dgm_ab_plesiomon_1"] = "0,90",
    ["czx_dgm_ab_plesiomon_2"] = "8,90",
    ["czx_dgm_ab_plotmon_1"] = "0,90",
    ["czx_dgm_ab_plotmon_2"] = "8,90",
    ["czx_dgm_ab_renamon_1"] = "2,70",
    ["czx_dgm_ab_renamon_2"] = "8,90",
    ["czx_dgm_ab_rizegreymon_1"] = "2,60",
    ["czx_dgm_ab_rizegreymon_2"] = "2,60",
    ["czx_dgm_ab_rosemon_1"] = "8,90",
    ["czx_dgm_ab_rosemon_2"] = "8,90",
    ["czx_dgm_ab_rosemon_3"] = "0,90",
    ["czx_dgm_ab_sakuyamon_1"] = "2,55",
    ["czx_dgm_ab_seadramon_1"] = "2,65",
    ["czx_dgm_ab_seadramon_2"] = "8,90",
    ["czx_dgm_ab_seadramon_3"] = "2,65",
    ["czx_dgm_ab_seraphimon_1"] = "8,90",
    ["czx_dgm_ab_shinegreymon_1"] = "8,90",
    ["czx_dgm_ab_shinegreymon_2"] = "8,90",
    ["czx_dgm_ab_shinegreymon_3"] = "8,90",
    ["czx_dgm_ab_shinegreymonbm_1"] = "8,90",
    ["czx_dgm_ab_shinegreymonbm_2"] = "8,90",
    ["czx_dgm_ab_skullgreymon_1"] = "2,60",
    ["czx_dgm_ab_skullgreymon_2"] = "2,60",
    ["czx_dgm_ab_sunflowmon_1"] = "2,70",
    ["czx_dgm_ab_sunflowmon_2"] = "8,90",
    ["czx_dgm_ab_susanoomon_1"] = "2,50",
    ["czx_dgm_ab_susanoomon_2"] = "8,90",
    ["czx_dgm_ab_taomon_1"] = "8,90",
    ["czx_dgm_ab_taomon_2"] = "2,60",
    ["czx_dgm_ab_tentomon_1"] = "2,70",
    ["czx_dgm_ab_tentomon_2"] = "2,70",
    ["czx_dgm_ab_tinkermon_1"] = "0,90",
    ["czx_dgm_ab_tinkermon_2"] = "0,90",
    ["czx_dgm_ab_tinkermon_3"] = "0,90",
    ["czx_dgm_ab_togemon_1"] = "8,90",
    ["czx_dgm_ab_togemon_2"] = "2,65",
    ["czx_dgm_ab_tyranomon_1"] = "2,65",
    ["czx_dgm_ab_tyranomon_2"] = "8,90",
    ["czx_dgm_ab_tyranomon_3"] = "8,90",
    ["czx_dgm_ab_ulforcev_1"] = "2,50",
    ["czx_dgm_ab_ulforcev_2"] = "8,90",
    ["czx_dgm_ab_ulforcevx_1"] = "2,50",
    ["czx_dgm_ab_ulforcevx_2"] = "2,50",
    ["czx_dgm_ab_veedramon_1"] = "2,65",
    ["czx_dgm_ab_veedramon_2"] = "8,90",
    ["czx_dgm_ab_veedramon_3"] = "8,90",
    ["czx_dgm_ab_veemon_1"] = "8,90",
    ["czx_dgm_ab_veemon_2"] = "8,90",
    ["czx_dgm_ab_veemonex_1"] = "2,65",
    ["czx_dgm_ab_veemonex_2"] = "0,90",
    ["czx_dgm_ab_vikemon_1"] = "3,90",
    ["czx_dgm_ab_vikemon_2"] = "8,90",
    ["czx_dgm_ab_vikemon_3"] = "8,90",
    ["czx_dgm_ab_vritramon_1"] = "3,90",
    ["czx_dgm_ab_vritramon_2"] = "8,90",
    ["czx_dgm_ab_wargreymon_1"] = "8,90",
    ["czx_dgm_ab_wargreymon_2"] = "8,90",
    ["czx_dgm_ab_wargreymon_3"] = "3,90",
    ["czx_dgm_ab_wargreymonx_1"] = "8,90",
    ["czx_dgm_ab_wargreymonx_2"] = "2,50",
    ["czx_dgm_ab_wargreymonx_3"] = "8,90",
    ["czx_dgm_ab_wargrowlmon_1"] = "2,60",
    ["czx_dgm_ab_wargrowlmon_2"] = "8,90",
    ["czx_dgm_ab_weregarurumon_1"] = "8,90",
    ["czx_dgm_ab_weregarurumon_2"] = "8,90",
    ["czx_dgm_ab_weregarurumon_3"] = "8,90",
    ["czx_dgm_ab_zeedmillennium_1"] = "8,90",
    ["czx_dgm_ab_zeedmillennium_2"] = "0,90",
    ["czx_dgm_ab_zubaeagermon_1"] = "8,90",
    ["czx_dgm_ab_zubaeagermon_2"] = "8,90",
    ["czx_dgm_ab_zubamon_1"] = "8,90",
    ["czx_dgm_ab_zudomon_1"] = "2,60",
    ["czx_dgm_ab_zudomon_2"] = "2,60",
    ["hefadk_unit_abilities_star_dragons_breath_eden_valley"] = "2,60",
    ["hefadk_unit_abilities_star_dragons_breath_once"] = "2,60",
    ["wh2_dlc09_army_abilities_barrage_of_the_legion"] = "3,90",
    ["wh2_dlc09_army_abilities_realm_of_souls_ushabti"] = "3,0",
    ["wh2_dlc09_army_abilities_rictus_clanstone"] = "1,120",
    ["wh2_dlc09_army_abilities_sand_veil"] = "4,90",
    ["wh2_dlc09_army_abilities_tomb_swarm"] = "1,120",
    ["wh2_dlc09_character_abilities_curse_of_djaf"] = "3,0",
    ["wh2_dlc09_character_abilities_curse_of_khsar"] = "3,0",
    ["wh2_dlc09_character_abilities_restore"] = "4,60",
    ["wh2_dlc09_character_abilities_stay_here_ill_get_help"] = "13,90",
    ["wh2_dlc09_character_abilities_strike_of_nagash"] = "8,120",
    ["wh2_dlc09_character_abilities_strike_of_nehekhara"] = "8,120",
    ["wh2_dlc09_character_abilities_strike_of_tombs"] = "8,90",
    ["wh2_dlc09_character_abilities_tomb_king_rally"] = "8,60",
    ["wh2_dlc09_character_abilities_tomb_king_rally_upgraded"] = "8,90",
    ["wh2_dlc09_item_abilities_amulet_of_phastah"] = "3,120",
    ["wh2_dlc09_item_abilities_cloak_of_the_dunes"] = "8,90",
    ["wh2_dlc09_item_abilities_elixir_of_might"] = "12,60",
    ["wh2_dlc09_item_abilities_enkhils_kanopi"] = "8,120",
    ["wh2_dlc09_item_abilities_hieratic_jar"] = "8,60",
    ["wh2_dlc09_item_abilities_neferras_scrolls_of_mighty_incantations"] = "8,90",
    ["wh2_dlc09_item_abilities_staff_of_nagash"] = "8,120",
    ["wh2_dlc09_lord_abilities_sand_storm"] = "3,90",
    ["wh2_dlc09_lord_abilities_the_liber_mortis"] = "9,90",
    ["wh2_dlc09_lord_abilities_venom_wave"] = "8,90",
    ["wh2_dlc09_lord_abilities_wrath_of_ptra"] = "8,90",
    ["wh2_dlc09_spell_death_spirit_leech_bound"] = "2,45",
    ["wh2_dlc09_spell_nehekhara_djafs_incantation_of_cursed_blades"] = "28,28",
    ["wh2_dlc09_spell_nehekhara_djafs_incantation_of_cursed_blades_upgraded"] = "28,28",
    ["wh2_dlc09_spell_nehekhara_nerus_incantation_of_protection"] = "28,30",
    ["wh2_dlc09_spell_nehekhara_nerus_incantation_of_protection_upgraded"] = "28,30",
    ["wh2_dlc09_spell_nehekhara_ptras_incantation_of_righteous_smiting"] = "28,43",
    ["wh2_dlc09_spell_nehekhara_ptras_incantation_of_righteous_smiting_upgraded"] = "28,43",
    ["wh2_dlc09_spell_nehekhara_sakhmets_incantation_of_the_skullstorm"] = "19,49",
    ["wh2_dlc09_spell_nehekhara_sakhmets_incantation_of_the_skullstorm_upgraded"] = "19,49",
    ["wh2_dlc09_spell_nehekhara_usekhps_incantation_of_desiccation"] = "19,51",
    ["wh2_dlc09_spell_nehekhara_usekhps_incantation_of_desiccation_upgraded"] = "19,51",
    ["wh2_dlc09_spell_nehekhara_usirians_incantation_of_vengeance"] = "18,38",
    ["wh2_dlc09_spell_nehekhara_usirians_incantation_of_vengeance_upgraded"] = "18,38",
    ["wh2_dlc09_unit_abilities_death_from_above"] = "0,0",
    ["wh2_dlc09_weapon_abilities_blade_of_setep"] = "2,90",
    ["wh2_dlc09_weapon_abilities_blessed_blade_of_ptra"] = "8,120",
    ["wh2_dlc09_weapon_abilities_tomb_blade_of_arkhan"] = "13,120",
    ["wh2_dlc09_weapon_abilities_venom_staff"] = "2,30",
    ["wh2_dlc10_character_abilities_entangle"] = "3,120",
    ["wh2_dlc10_item_abilities_fear_of_aramar"] = "2,120",
    ["wh2_dlc10_item_abilities_horn_of_the_ancestors"] = "13,120",
    ["wh2_dlc10_item_abilities_sceptre_of_stone"] = "3,90",
    ["wh2_dlc10_item_abilities_speed_of_lykos"] = "12,60",
    ["wh2_dlc10_item_abilities_star_of_avelorn"] = "9,120",
    ["wh2_dlc10_item_abilities_stave_of_avelorn"] = "8,60",
    ["wh2_dlc10_item_abilities_the_amber_trance"] = "10,60",
    ["wh2_dlc10_item_bound_arnizipals_black_horror"] = "3,120",
    ["wh2_dlc10_item_bound_assault_of_stone"] = "3,90",
    ["wh2_dlc10_item_bound_blast"] = "2,60",
    ["wh2_dlc10_lord_abilities_deadly_mislead"] = "9,90",
    ["wh2_dlc10_lord_abilities_gaze_of_khaine"] = "1,90",
    ["wh2_dlc10_lord_abilities_mislead"] = "9,90",
    ["wh2_dlc10_lord_abilities_oath_of_vengeance"] = "2,60",
    ["wh2_dlc10_lord_abilities_red_ruin"] = "8,90",
    ["wh2_dlc10_quest_abilities_fiery_head"] = "8,25",
    ["wh2_dlc10_quest_abilities_flame_storm"] = "3,25",
    ["wh2_dlc10_quest_abilities_magic_fiery_convocation"] = "3,25",
    ["wh2_dlc10_quest_abilities_regenerating_head"] = "8,15",
    ["wh2_dlc10_quest_abilities_unidentified_hydra_head"] = "8,135",
    ["wh2_dlc10_quest_passive_the_rats_overwhelm"] = "8,70",
    ["wh2_dlc10_spell_bound_lesser_doombolt"] = "2,90",
    ["wh2_dlc10_spell_bound_magic_fiery_convocation"] = "3,120",
    ["wh2_dlc10_spell_bound_soul_stealer_ror"] = "11,120",
    ["wh2_dlc10_spell_bound_soulblight"] = "3,90",
    ["wh2_dlc10_spell_bound_word_of_pain"] = "2,90",
    ["wh2_dlc10_unit_abilities_frost_breath"] = "2,60",
    ["wh2_dlc10_unit_abilities_frost_wyrm_breath"] = "2,60",
    ["wh2_dlc10_weapon_abilities_sword_of_khaine"] = "3,120",
    ["wh2_dlc10_weapon_abilities_the_moonbow"] = "2,120",
    ["wh2_dlc11_army_abilities_norse_roar"] = "3,90",
    ["wh2_dlc11_army_abilities_rod_of_the_storm"] = "3,90",
    ["wh2_dlc11_army_abilities_sartosa_grapeshot"] = "3,90",
    ["wh2_dlc11_army_abilities_shanty_verse_1"] = "0,120",
    ["wh2_dlc11_army_abilities_shanty_verse_1_ai"] = "4,120",
    ["wh2_dlc11_army_abilities_shanty_verse_2"] = "0,120",
    ["wh2_dlc11_army_abilities_shanty_verse_2_ai"] = "4,120",
    ["wh2_dlc11_army_abilities_shanty_verse_3"] = "0,120",
    ["wh2_dlc11_army_abilities_shanty_verse_3_ai"] = "4,120",
    ["wh2_dlc11_army_abilities_wraith_storm"] = "2,90",
    ["wh2_dlc11_army_abilities_zhufbar_42_pounders"] = "3,90",
    ["wh2_dlc11_character_abilities_all_hands_hoay"] = "8,90",
    ["wh2_dlc11_character_abilities_avast_ye"] = "8,60",
    ["wh2_dlc11_character_abilities_ballistic_enchantment"] = "8,90",
    ["wh2_dlc11_character_abilities_beyond_the_realm"] = "13,120",
    ["wh2_dlc11_character_abilities_cackle_fruit"] = "2,90",
    ["wh2_dlc11_character_abilities_ghosts_of_the_past_0"] = "13,120",
    ["wh2_dlc11_character_abilities_ghosts_of_the_past_1"] = "13,120",
    ["wh2_dlc11_character_abilities_ghosts_of_the_past_2"] = "13,120",
    ["wh2_dlc11_character_abilities_hornswaggle"] = "2,90",
    ["wh2_dlc11_character_abilities_pyromaniac"] = "2,90",
    ["wh2_dlc11_character_abilities_sacrilege"] = "13,120",
    ["wh2_dlc11_character_abilities_taunt"] = "2,60",
    ["wh2_dlc11_hero_abilities_bomb_throw"] = "2,60",
    ["wh2_dlc11_hero_abilities_more_powder"] = "4,60",
    ["wh2_dlc11_item_abilities_captain_roths_moondial"] = "13,120",
    ["wh2_dlc11_item_abilities_moonshine"] = "8,60",
    ["wh2_dlc11_item_abilities_slann_gold"] = "2,120",
    ["wh2_dlc11_lord_abilities_claws_of_mourkain"] = "8,120",
    ["wh2_dlc11_lord_abilities_dark_protection"] = "8,90",
    ["wh2_dlc11_lord_abilities_dreaded_duelist"] = "8,60",
    ["wh2_dlc11_lord_abilities_ghoul_king_of_ushoran"] = "8,120",
    ["wh2_dlc11_lord_abilities_heart_piercing"] = "8,120",
    ["wh2_dlc11_lord_abilities_lightning_reflexes"] = "8,90",
    ["wh2_dlc11_lord_abilities_mananns_luck"] = "8,60",
    ["wh2_dlc11_lord_abilities_power_siphon"] = "2,60",
    ["wh2_dlc11_lord_abilities_seduction"] = "0,120",
    ["wh2_dlc11_lord_abilities_song_of_enthrallment"] = "0,90",
    ["wh2_dlc11_lord_abilities_spearfishers_net"] = "2,90",
    ["wh2_dlc11_lord_abilities_storm_of_the_night"] = "2,90",
    ["wh2_dlc11_lord_abilities_transfix"] = "8,120",
    ["wh2_dlc11_lord_abilities_wraith_storm"] = "2,90",
    ["wh2_dlc11_quest_battle_supply"] = "0,120",
    ["wh2_dlc11_spell_beasts_transformation_of_kadon"] = "29,45",
    ["wh2_dlc11_spell_bound_the_purple_sun_of_xereus"] = "3,120",
    ["wh2_dlc11_spell_bound_tidecall"] = "11,60",
    ["wh2_dlc11_spell_bound_wind_blast"] = "3,60",
    ["wh2_dlc11_spell_deep_denizens_of_the_deep"] = "29,43",
    ["wh2_dlc11_spell_deep_fog_of_the_damned"] = "17,44",
    ["wh2_dlc11_spell_deep_fog_of_the_damned_upgraded"] = "17,44",
    ["wh2_dlc11_spell_deep_ghost_ship"] = "19,54",
    ["wh2_dlc11_spell_deep_ghost_ship_upgraded"] = "19,54",
    ["wh2_dlc11_spell_deep_krakens_pull"] = "19,49",
    ["wh2_dlc11_spell_deep_krakens_pull_upgraded"] = "19,49",
    ["wh2_dlc11_spell_deep_spiteful_shot"] = "28,28",
    ["wh2_dlc11_spell_deep_spiteful_shot_upgraded"] = "28,28",
    ["wh2_dlc11_spell_deep_tidecall"] = "27,32",
    ["wh2_dlc11_spell_deep_tidecall_upgraded"] = "19,32",
    ["wh2_dlc11_spell_vampires_drowned_dead"] = "29,41",
    ["wh2_dlc11_spell_vampires_drowned_dead_upgraded"] = "29,41",
    ["wh2_dlc12_army_abilities_great_invocation_of_sotek"] = "3,120",
    ["wh2_dlc12_army_abilities_jungle_swarm"] = "3,90",
    ["wh2_dlc12_army_abilities_warpstorm_doomrocket"] = "3,45",
    ["wh2_dlc12_army_abilities_warpstorm_doomrocket_upgraded"] = "3,45",
    ["wh2_dlc12_character_abilities_brass_orb"] = "3,90",
    ["wh2_dlc12_character_abilities_brass_orb_tech_lab_doom_flayer"] = "3,90",
    ["wh2_dlc12_character_abilities_brass_orb_upgrade"] = "3,90",
    ["wh2_dlc12_character_abilities_supreme_shield_of_the_old_ones"] = "9,120",
    ["wh2_dlc12_lord_abilities_drop_sphere_of_tepok"] = "0,5",
    ["wh2_dlc12_lord_abilities_drop_sphere_of_tepok_upgraded"] = "0,5",
    ["wh2_dlc12_lord_abilities_focus_instincts"] = "8,90",
    ["wh2_dlc12_lord_abilities_master_of_the_skies"] = "8,60",
    ["wh2_dlc12_lord_abilities_unlimited_power"] = "8,90",
    ["wh2_dlc12_lord_abilities_warriors_crest"] = "8,90",
    ["wh2_dlc12_spell_kroak_deliverance_of_itza_1"] = "19,15",
    ["wh2_dlc12_spell_kroak_deliverance_of_itza_2"] = "19,20",
    ["wh2_dlc12_spell_kroak_deliverance_of_itza_3"] = "19,25",
    ["wh2_dlc12_unit_abilities_ark_of_sotek"] = "8,90",
    ["wh2_dlc12_unit_abilities_burning_alignment"] = "3,120",
    ["wh2_dlc12_unit_abilities_drop_rocks_character"] = "0,5",
    ["wh2_dlc12_unit_abilities_drop_rocks_of_chotec"] = "0,5",
    ["wh2_dlc12_unit_abilities_drop_rocks_of_sundering"] = "0,5",
    ["wh2_dlc12_unit_abilities_refuse_to_die"] = "8,60",
    ["wh2_dlc12_unit_abilities_shield_of_chaqua"] = "8,90",
    ["wh2_dlc12_unit_abilities_toad_rage"] = "8,60",
    ["wh2_dlc12_weapon_abilities_storm_daemon"] = "2,120",
    ["wh2_dlc13_army_abilities_amber_bow_cannons"] = "3,60",
    ["wh2_dlc13_army_abilities_beasts_of_itzl"] = "3,120",
    ["wh2_dlc13_army_abilities_beasts_of_itzl_upgraded"] = "3,90",
    ["wh2_dlc13_army_abilities_protection_of_quetzl"] = "12,120",
    ["wh2_dlc13_army_abilities_protection_of_quetzl_upgraded"] = "12,90",
    ["wh2_dlc13_army_abilities_storm_of_xholankha"] = "11,-1",
    ["wh2_dlc13_army_abilities_storm_of_xholankha_upgraded"] = "11,90",
    ["wh2_dlc13_character_abilities_big_boom"] = "2,120",
    ["wh2_dlc13_character_abilities_patch_up"] = "4,90",
    ["wh2_dlc13_character_ability_hunters_call"] = "8,120",
    ["wh2_dlc13_character_ability_ishas_rain"] = "3,120",
    ["wh2_dlc13_character_ability_shatter"] = "3,120",
    ["wh2_dlc13_final_battle_abilities_shield_of_the_old_ones"] = "9,90",
    ["wh2_dlc13_item_abilities_shield_of_aeons"] = "8,120",
    ["wh2_dlc13_lord_abilities_arrows_of_aqshy"] = "2,90",
    ["wh2_dlc13_lord_abilities_aura_of_inertia"] = "0,90",
    ["wh2_dlc13_lord_abilities_executioner"] = "2,90",
    ["wh2_dlc13_lord_abilities_fire_arrow"] = "2,90",
    ["wh2_dlc13_lord_abilities_funnel_of_flame"] = "8,90",
    ["wh2_dlc13_lord_abilities_hail_of_fire"] = "8,90",
    ["wh2_dlc13_lord_abilities_hunters_snare"] = "3,90",
    ["wh2_dlc13_lord_abilities_hunters_trap"] = "3,90",
    ["wh2_dlc13_lord_abilities_kill_shot"] = "2,120",
    ["wh2_dlc13_lord_abilities_miasma_of_despair"] = "0,90",
    ["wh2_dlc13_lord_abilities_monstrous_strength"] = "8,90",
    ["wh2_dlc13_lord_abilities_oil_flask"] = "2,90",
    ["wh2_dlc13_lord_abilities_primal_roar"] = "8,120",
    ["wh2_dlc13_lord_abilities_rock_of_itza"] = "8,60",
    ["wh2_dlc13_unit_abilities_emergency_vent"] = "8,60",
    ["wh2_dlc13_weapon_abilities_amber_bow"] = "2,120",
    ["wh2_dlc13_weapon_abilities_averland_runefang"] = "2,120",
    ["wh2_dlc13_weapon_abilities_drakwald_runefang"] = "8,120",
    ["wh2_dlc13_weapon_abilities_hochland_runefang"] = "0,120",
    ["wh2_dlc13_weapon_abilities_mace_of_ulumak"] = "8,120",
    ["wh2_dlc13_weapon_abilities_nordland_runefang"] = "0,120",
    ["wh2_dlc13_weapon_abilities_ostermark_runefang"] = "8,120",
    ["wh2_dlc13_weapon_abilities_ostland_runefang"] = "8,120",
    ["wh2_dlc13_weapon_abilities_talabecland_runefang"] = "8,120",
    ["wh2_dlc13_weapon_abilities_wissenland_runefang"] = "0,120",
    ["wh2_dlc14_character_abilities_cracklebomb"] = "2,90",
    ["wh2_dlc14_character_abilities_from_the_shadows"] = "9,90",
    ["wh2_dlc14_final_battle_ability_summon_snikch"] = "3,0",
    ["wh2_dlc14_lord_abilities_beastslaver"] = "8,60",
    ["wh2_dlc14_lord_abilities_bloodstorm"] = "8,60",
    ["wh2_dlc14_lord_abilities_deathmasters_sigil"] = "2,90",
    ["wh2_dlc14_lord_abilities_halo_of_maidenly_wrath"] = "8,120",
    ["wh2_dlc14_lord_abilities_looming_dread"] = "2,90",
    ["wh2_dlc14_lord_abilities_reaper_of_souls"] = "8,90",
    ["wh2_dlc14_lord_abilities_the_blood_price"] = "8,90",
    ["wh2_dlc14_lord_abilities_the_daemons_curse"] = "0,120",
    ["wh2_dlc14_lord_abilities_tzarkan"] = "8,0",
    ["wh2_dlc14_lord_abilities_tzarkan_mp"] = "8,0",
    ["wh2_dlc14_lord_abilities_tzarkan_snikch"] = "8,0",
    ["wh2_dlc14_lord_abilities_tzarkan_spite"] = "8,0",
    ["wh2_dlc14_lord_abilities_tzarkan_spite_mp"] = "8,0",
    ["wh2_dlc14_lord_abilities_whiplash"] = "12,90",
    ["wh2_dlc14_spell_bound_warpfireball"] = "2,60",
    ["wh2_dlc14_spell_grey_seer_the_dreaded_thirteenth_spell_upgraded"] = "19,52",
    ["wh2_dlc14_spell_ruin_flensing_ruin"] = "19,52",
    ["wh2_dlc14_spell_ruin_flensing_ruin_upgraded"] = "19,52",
    ["wh2_dlc14_spell_stealth_armour_of_darkness"] = "28,43",
    ["wh2_dlc14_spell_stealth_armour_of_darkness_upgraded"] = "29,43",
    ["wh2_dlc14_spell_stealth_black_whirlwind"] = "27,47",
    ["wh2_dlc14_spell_stealth_black_whirlwind_upgraded"] = "27,47",
    ["wh2_dlc14_spell_stealth_brittle_bone"] = "18,47",
    ["wh2_dlc14_spell_stealth_brittle_bone_upgraded"] = "19,47",
    ["wh2_dlc14_spell_stealth_veil_of_shadows"] = "27,38",
    ["wh2_dlc14_spell_stealth_veil_of_shadows_upgraded"] = "27,38",
    ["wh2_dlc14_spell_stealth_warp_stars"] = "26,28",
    ["wh2_dlc14_spell_stealth_warp_stars_upgraded"] = "26,28",
    ["wh2_dlc14_unit_abilities_doppelgang"] = "13,90",
    ["wh2_dlc14_unit_abilities_seismic_snare"] = "0,60",
    ["wh2_dlc14_unit_abilities_wail_of_malice"] = "0,90",
    ["wh2_dlc14_unit_abilities_warp_quake"] = "0,90",
    ["wh2_dlc14_weapon_abilities_sword_of_lyonesse"] = "8,120",
    ["wh2_dlc14_weapon_abilities_whirl_of_weeping_blades"] = "8,120",
    ["wh2_dlc15_army_abilities_azhags_big_waaagh"] = "0,-1",
    ["wh2_dlc15_army_abilities_azhags_waaagh"] = "0,-1",
    ["wh2_dlc15_army_abilities_big_waaagh"] = "0,-1",
    ["wh2_dlc15_army_abilities_doom_diver_strike"] = "1,90",
    ["wh2_dlc15_army_abilities_doom_diver_strike_enhanced"] = "1,45",
    ["wh2_dlc15_army_abilities_envelop_in_mist"] = "1,120",
    ["wh2_dlc15_army_abilities_flood_trap"] = "3,0",
    ["wh2_dlc15_army_abilities_grimgors_big_waaagh"] = "0,-1",
    ["wh2_dlc15_army_abilities_grimgors_waaagh"] = "0,-1",
    ["wh2_dlc15_army_abilities_groms_big_waaagh"] = "0,-1",
    ["wh2_dlc15_army_abilities_groms_waaagh"] = "0,-1",
    ["wh2_dlc15_army_abilities_invocation_of_ending"] = "1,120",
    ["wh2_dlc15_army_abilities_lightning_trap_1"] = "3,0",
    ["wh2_dlc15_army_abilities_lightning_trap_2"] = "3,0",
    ["wh2_dlc15_army_abilities_oath_of_replenishment"] = "0,120",
    ["wh2_dlc15_army_abilities_oath_of_replenishment_upgraded"] = "0,120",
    ["wh2_dlc15_army_abilities_skarsniks_big_waaagh"] = "0,-1",
    ["wh2_dlc15_army_abilities_skarsniks_waaagh"] = "0,-1",
    ["wh2_dlc15_army_abilities_summon_the_sentinels"] = "1,120",
    ["wh2_dlc15_army_abilities_summon_the_sentinels_upgraded"] = "1,120",
    ["wh2_dlc15_army_abilities_unleash_the_winds"] = "0,60",
    ["wh2_dlc15_army_abilities_waaagh"] = "0,-1",
    ["wh2_dlc15_army_abilities_wind_trap_1a"] = "3,0",
    ["wh2_dlc15_army_abilities_wind_trap_1b"] = "3,0",
    ["wh2_dlc15_army_abilities_wind_trap_2a"] = "3,0",
    ["wh2_dlc15_army_abilities_wind_trap_2b"] = "3,0",
    ["wh2_dlc15_army_abilities_wind_trap_3a"] = "3,0",
    ["wh2_dlc15_army_abilities_wind_trap_3b"] = "3,0",
    ["wh2_dlc15_army_abilities_wurrzags_big_waaagh"] = "0,-1",
    ["wh2_dlc15_army_abilities_wurrzags_waaagh"] = "0,-1",
    ["wh2_dlc15_character_abilities_burp_of_grom_0"] = "8,60",
    ["wh2_dlc15_character_abilities_burp_of_grom_1"] = "8,60",
    ["wh2_dlc15_character_abilities_burp_of_grom_2"] = "8,60",
    ["wh2_dlc15_character_abilities_fishy_breathe"] = "3,32",
    ["wh2_dlc15_character_abilities_goggly_glare"] = "2,60",
    ["wh2_dlc15_character_abilities_sausage_busta"] = "8,120",
    ["wh2_dlc15_character_abilities_slimy_smoothie"] = "13,30",
    ["wh2_dlc15_character_abilities_they_needs_stabbin"] = "2,60",
    ["wh2_dlc15_character_abilities_wardens_cage"] = "2,120",
    ["wh2_dlc15_hero_abilities_mither"] = "2,60",
    ["wh2_dlc15_hero_abilities_swamp_breath"] = "2,60",
    ["wh2_dlc15_item_abilities_armour_of_caledor"] = "8,180",
    ["wh2_dlc15_item_abilities_azhags_ard_armour"] = "8,120",
    ["wh2_dlc15_item_abilities_blacktoofs_conjuration"] = "13,300",
    ["wh2_dlc15_item_abilities_blood_forged_armour"] = "8,30",
    ["wh2_dlc15_item_abilities_helm_of_yvresse"] = "12,120",
    ["wh2_dlc15_item_abilities_lucky_banner"] = "8,120",
    ["wh2_dlc15_item_abilities_vine_dragon_scale"] = "0,120",
    ["wh2_dlc15_lord_abilities_da_boss_loons"] = "3,30",
    ["wh2_dlc15_lord_abilities_da_great_un_iz_ere"] = "8,90",
    ["wh2_dlc15_lord_abilities_dont_even_try_it"] = "2,90",
    ["wh2_dlc15_lord_abilities_dragonhorn"] = "8,120",
    ["wh2_dlc15_lord_abilities_fermented_fungi"] = "2,90",
    ["wh2_dlc15_lord_abilities_lord_of_dragons"] = "2,90",
    ["wh2_dlc15_lord_abilities_smash_em_faster"] = "8,90",
    ["wh2_dlc15_lord_abilities_youre_next"] = "2,90",
    ["wh2_dlc15_spell_beasts_transformation_of_kadon"] = "29,45",
    ["wh2_dlc15_spell_bound_chain_lightning"] = "3,50",
    ["wh2_dlc15_spell_bound_gaze_of_nagash"] = "2,90",
    ["wh2_dlc15_spell_bound_wind_of_death"] = "3,120",
    ["wh2_dlc15_unit_abilities_arachneruption"] = "0,90",
    ["wh2_dlc15_unit_abilities_emberstorm"] = "8,90",
    ["wh2_dlc15_unit_abilities_mighty_roar"] = "0,90",
    ["wh2_dlc15_unit_abilities_mimic_cold_blooded"] = "8,60",
    ["wh2_dlc15_unit_abilities_mimic_feint_and_riposte"] = "8,90",
    ["wh2_dlc15_unit_abilities_mimic_grand_hammer_of_faith"] = "8,90",
    ["wh2_dlc15_unit_abilities_mimic_grom_waaagh"] = "8,120",
    ["wh2_dlc15_unit_abilities_mimic_loecs_shroud"] = "8,120",
    ["wh2_dlc15_unit_abilities_mimic_ruinshelter"] = "8,90",
    ["wh2_dlc15_unit_abilities_mimic_waaagh"] = "8,90",
    ["wh2_dlc15_unit_abilities_noxious_breath_imrik"] = "2,60",
    ["wh2_dlc15_unit_abilities_rock_bottom"] = "8,45",
    ["wh2_dlc15_unit_abilities_sun_dragon_breath_imrik"] = "2,60",
    ["wh2_dlc15_weapon_abilities_axe_of_grom"] = "8,120",
    ["wh2_dlc15_weapon_abilities_fangsword_of_eltharion"] = "8,120",
    ["wh2_dlc15_weapon_abilities_star_lance"] = "8,120",
    ["wh2_dlc16_army_abilities_call_to_ceithin_har"] = "13,120",
    ["wh2_dlc16_army_abilities_siege_attacker_hidden"] = "8,-1",
    ["wh2_dlc16_army_abilities_transformation_of_kadon"] = "13,45",
    ["wh2_dlc16_character_abilities_befuddlement_of_mischiefs"] = "3,90",
    ["wh2_dlc16_character_abilities_blight_of_terrors"] = "0,90",
    ["wh2_dlc16_character_abilities_muster_of_malevolents"] = "2,90",
    ["wh2_dlc16_character_abilities_pageant_of_shrikes"] = "2,90",
    ["wh2_dlc16_hero_abilities_evisceration"] = "8,90",
    ["wh2_dlc16_hero_abilities_shock_collar"] = "12,60",
    ["wh2_dlc16_hero_abilities_tide_of_death"] = "13,120",
    ["wh2_dlc16_hero_abilities_tide_of_pox"] = "13,120",
    ["wh2_dlc16_hero_abilities_warp_frenzy"] = "8,90",
    ["wh2_dlc16_item_abilities_acorns_of_the_oak_of_ages"] = "11,120",
    ["wh2_dlc16_item_abilities_berry_wine"] = "12,120",
    ["wh2_dlc16_item_abilities_dart_of_doom"] = "2,120",
    ["wh2_dlc16_item_abilities_dreaming_cloak_i"] = "13,120",
    ["wh2_dlc16_item_abilities_dreaming_cloak_ii"] = "13,120",
    ["wh2_dlc16_item_abilities_dreaming_cloak_iii"] = "13,120",
    ["wh2_dlc16_item_abilities_dreaming_ring_i"] = "12,60",
    ["wh2_dlc16_item_abilities_dreaming_ring_ii"] = "12,90",
    ["wh2_dlc16_item_abilities_dreaming_ring_iii"] = "12,120",
    ["wh2_dlc16_item_abilities_eagle_quiver"] = "2,120",
    ["wh2_dlc16_item_abilities_twilight_horn_i"] = "12,60",
    ["wh2_dlc16_item_abilities_twilight_horn_ii"] = "13,90",
    ["wh2_dlc16_lord_abilities_beast_pack"] = "13,120",
    ["wh2_dlc16_lord_abilities_call_to_ceithin_har"] = "13,120",
    ["wh2_dlc16_lord_abilities_call_to_gwindalor"] = "13,120",
    ["wh2_dlc16_lord_abilities_loecs_blessing"] = "13,90",
    ["wh2_dlc16_lord_abilities_remouldered"] = "12,120",
    ["wh2_dlc16_lord_abilities_roused_to_wrath"] = "13,90",
    ["wh2_dlc16_lord_abilities_roused_to_wrath_2"] = "13,90",
    ["wh2_dlc16_lord_abilities_roused_to_wrath_3"] = "13,90",
    ["wh2_dlc16_spell_bound_death_frenzy"] = "8,90",
    ["wh2_dlc16_spell_bound_earth_blood"] = "13,60",
    ["wh2_dlc16_spell_bound_flesh_to_stone"] = "12,90",
    ["wh2_dlc16_spell_bound_regrowth"] = "12,120",
    ["wh2_dlc16_spell_bound_the_curse_of_anraheir"] = "3,120",
    ["wh2_dlc16_spell_bound_vampires_lesser_raise_dead"] = "13,0",
    ["wh2_dlc16_unit_abilities_acidic_musk_glands"] = "8,60",
    ["wh2_dlc16_unit_abilities_cellular_instability"] = "8,90",
    ["wh2_dlc16_unit_abilities_fluid_injection"] = "8,60",
    ["wh2_dlc16_unit_abilities_neuroparasites"] = "8,120",
    ["wh2_dlc16_unit_abilities_volley_of_kurnous"] = "2,90",
    ["wh2_dlc16_unit_abilities_warp_lightning_rod"] = "8,60",
    ["wh2_dlc16_unit_abilities_whirling_death"] = "8,1",
    ["wh2_dlc16_weapon_abilities_creature_killer"] = "8,120",
    ["wh2_dlc16_weapon_abilities_dragon_spear"] = "8,120",
    ["wh2_dlc16_weapon_abilities_eagle_bow"] = "12,60",
    ["wh2_dlc17_army_abilities_ancestral_rune_of_grimnir"] = "1,120",
    ["wh2_dlc17_army_abilities_ancestral_rune_of_grungni"] = "1,120",
    ["wh2_dlc17_army_abilities_ancestral_rune_of_valaya"] = "1,120",
    ["wh2_dlc17_army_abilities_chaos_spawn_summon_qb_scripted"] = "3,0",
    ["wh2_dlc17_army_abilities_cygor_summon_qb_scripted"] = "13,0",
    ["wh2_dlc17_army_abilities_ghorgon_summon_qb_scripted"] = "1,0",
    ["wh2_dlc17_army_abilities_shatterstone"] = "3,45",
    ["wh2_dlc17_army_abilities_soteks_sanctum"] = "3,90",
    ["wh2_dlc17_army_abilities_touched_by_the_moon"] = "4,90",
    ["wh2_dlc17_army_abilities_tzcatlis_sanctum"] = "3,60",
    ["wh2_dlc17_army_abilities_vile_entropy"] = "3,90",
    ["wh2_dlc17_army_abilities_viletide"] = "3,90",
    ["wh2_dlc17_army_abilities_xapatis_sanctum"] = "3,60",
    ["wh2_dlc17_army_abilities_zhufbar_42_pounders_engineer"] = "3,90",
    ["wh2_dlc17_character_abilities_hunter_of_champions_upgraded"] = "2,90",
    ["wh2_dlc17_hero_abilities_cinderblast_shell"] = "2,90",
    ["wh2_dlc17_hero_abilities_more_powder_generic"] = "4,60",
    ["wh2_dlc17_lord_abilities_barbed_knuckle_boxing"] = "8,90",
    ["wh2_dlc17_lord_abilities_bloodbeast"] = "8,90",
    ["wh2_dlc17_lord_abilities_brass_body"] = "8,120",
    ["wh2_dlc17_lord_abilities_master_predator"] = "8,1",
    ["wh2_dlc17_lord_abilities_rune_of_doom"] = "8,120",
    ["wh2_dlc17_rune_abilities_master_rune_of_breaking"] = "12,180",
    ["wh2_dlc17_rune_abilities_master_rune_of_flight"] = "2,120",
    ["wh2_dlc17_rune_abilities_master_rune_of_immolation"] = "0,30",
    ["wh2_dlc17_rune_abilities_master_rune_of_slowness"] = "2,180",
    ["wh2_dlc17_rune_abilities_master_rune_of_speed"] = "13,180",
    ["wh2_dlc17_rune_abilities_rune_of_breaking"] = "12,120",
    ["wh2_dlc17_rune_abilities_rune_of_slowness"] = "2,120",
    ["wh2_dlc17_rune_abilities_rune_of_speed"] = "13,120",
    ["wh2_dlc17_spell_bound_lesser_banishment"] = "3,120",
    ["wh2_dlc17_spell_bound_lesser_chain_lightning"] = "3,120",
    ["wh2_dlc17_spell_bound_savage_dominion"] = "13,120",
    ["wh2_dlc17_spell_bound_shield_of_thorns"] = "12,90",
    ["wh2_dlc17_spell_bound_urannons_thunderbolt"] = "3,90",
    ["wh2_dlc17_spell_bound_urannons_thunderbolt_upgraded"] = "3,30",
    ["wh2_dlc17_spell_heavens_comet_of_casandora_bound_skink_oracle"] = "3,120",
    ["wh2_dlc17_spell_wild_mantle_of_ghorok_upgraded"] = "28,47",
    ["wh2_dlc17_unit_abilities_primeval_roar"] = "8,60",
    ["wh2_dlc17_weapon_abilities_the_golden_blowpipe_of_ptoohee"] = "2,120",
    ["wh2_main_army_abilities_bloodwrack_cauldron"] = "3,60",
    ["wh2_main_army_abilities_bolt_of_spite"] = "2,120",
    ["wh2_main_army_abilities_brazen_cauldron"] = "3,60",
    ["wh2_main_army_abilities_carnosaur_qb_scripted"] = "3,80",
    ["wh2_main_army_abilities_channeling_spire"] = "1,60",
    ["wh2_main_army_abilities_dark_conduit"] = "4,120",
    ["wh2_main_army_abilities_eagle_sanctuary"] = "5,120",
    ["wh2_main_army_abilities_eshin_clanstone"] = "1,120",
    ["wh2_main_army_abilities_feral_cold_ones"] = "3,120",
    ["wh2_main_army_abilities_feral_cold_ones_qb_scripted"] = "3,80",
    ["wh2_main_army_abilities_geomantic_nexus"] = "5,90",
    ["wh2_main_army_abilities_holy_stela"] = "1,60",
    ["wh2_main_army_abilities_khaines_flail"] = "3,60",
    ["wh2_main_army_abilities_khaines_lash"] = "3,60",
    ["wh2_main_army_abilities_khaines_scourge"] = "3,60",
    ["wh2_main_army_abilities_lure_of_the_pale_queen"] = "1,90",
    ["wh2_main_army_abilities_mors_clanstone"] = "1,120",
    ["wh2_main_army_abilities_moulder_clanstone"] = "1,120",
    ["wh2_main_army_abilities_pestilens_clanstone"] = "1,120",
    ["wh2_main_army_abilities_shadows_of_anlec"] = "3,60",
    ["wh2_main_army_abilities_skryre_clanstone"] = "1,120",
    ["wh2_main_army_abilities_sky_cauldron"] = "3,60",
    ["wh2_main_army_abilities_soul_rain"] = "3,60",
    ["wh2_main_army_abilities_soul_storm"] = "3,60",
    ["wh2_main_army_abilities_soul_torrent"] = "3,60",
    ["wh2_main_army_abilities_stegadon_qb_scripted"] = "3,80",
    ["wh2_main_army_abilities_temple_of_mists"] = "1,120",
    ["wh2_main_army_abilities_the_menace_below"] = "3,45",
    ["wh2_main_army_abilities_vauls_hammer"] = "3,120",
    ["wh2_main_army_abilities_vortic_blast"] = "3,30",
    ["wh2_main_army_abilities_vortic_enrichment"] = "1,30",
    ["wh2_main_army_abilities_warpbomb"] = "4,60",
    ["wh2_main_character_abilities_arcane_vassal"] = "12,120",
    ["wh2_main_character_abilities_assassins_trophy"] = "2,60",
    ["wh2_main_character_abilities_black_lotus"] = "8,60",
    ["wh2_main_character_abilities_cold_blooded"] = "12,60",
    ["wh2_main_character_abilities_concealment_bombs"] = "8,90",
    ["wh2_main_character_abilities_dark_venom"] = "8,60",
    ["wh2_main_character_abilities_shield_of_the_old_ones"] = "9,90",
    ["wh2_main_character_abilities_swiftness_of_itzl"] = "8,90",
    ["wh2_main_character_abilities_verminous_valour"] = "8,60",
    ["wh2_main_character_abilities_volley_of_dark_arrows"] = "2,90",
    ["wh2_main_character_abilities_volley_of_high_arrows"] = "2,90",
    ["wh2_main_character_abilities_witchbrew"] = "8,90",
    ["wh2_main_hero_abilities_doomrocket"] = "2,90",
    ["wh2_main_item_abilities_amulet_of_itzl"] = "8,60",
    ["wh2_main_item_abilities_armour_of_the_stars"] = "8,90",
    ["wh2_main_item_abilities_aura_of_quetzl"] = "8,90",
    ["wh2_main_item_abilities_black_dragon_egg"] = "3,90",
    ["wh2_main_item_abilities_blade_of_bel_korhadris"] = "8,90",
    ["wh2_main_item_abilities_blood_statuette_of_spite"] = "2,60",
    ["wh2_main_item_abilities_book_of_hoeth"] = "8,90",
    ["wh2_main_item_abilities_cube_of_darkness"] = "2,60",
    ["wh2_main_item_abilities_dragonhorn"] = "8,0",
    ["wh2_main_item_abilities_pearl_of_infinite_bleakness"] = "8,60",
    ["wh2_main_item_abilities_plaque_of_dominion"] = "0,60",
    ["wh2_main_item_abilities_rival_hide_talisman"] = "0,60",
    ["wh2_main_item_abilities_rod_of_corruption"] = "0,120",
    ["wh2_main_item_abilities_scrying_stone"] = "8,60",
    ["wh2_main_item_abilities_skalm"] = "8,60",
    ["wh2_main_item_abilities_skavenbrew"] = "12,90",
    ["wh2_main_item_abilities_starwood_staff"] = "8,90",
    ["wh2_main_item_abilities_talisman_of_loec"] = "8,0",
    ["wh2_main_item_abilities_the_bane_shield"] = "8,0",
    ["wh2_main_item_abilities_the_guiding_eye"] = "8,60",
    ["wh2_main_item_abilities_the_horn_of_kygor"] = "8,90",
    ["wh2_main_item_abilities_the_liber_bubonicus"] = "2,120",
    ["wh2_main_item_abilities_the_tricksters_pendant"] = "3,60",
    ["wh2_main_item_abilities_the_vortex_shard"] = "2,60",
    ["wh2_main_item_abilities_warpstorm_scroll"] = "3,60",
    ["wh2_main_item_abilities_worlds_edge_armour"] = "8,60",
    ["wh2_main_item_bound_gilded_horn_of_galon_konook"] = "3,90",
    ["wh2_main_lord_abilities_feint_and_reposte"] = "8,90",
    ["wh2_main_lord_abilities_gaze_of_malice"] = "3,90",
    ["wh2_main_lord_abilities_potion_of_charoi"] = "8,60",
    ["wh2_main_lord_abilities_sacred_spawning_of_xhotl"] = "8,60",
    ["wh2_main_lord_abilities_the_ruination_of_cities"] = "3,120",
    ["wh2_main_lord_abilities_trophy_heads"] = "2,90",
    ["wh2_main_mount_abilities_unholy_clamour"] = "8,120",
    ["wh2_main_mount_bound_pestilent_breath"] = "3,60",
    ["wh2_main_mount_bound_scorch"] = "3,90",
    ["wh2_main_spell_bound_black_staff"] = "12,90",
    ["wh2_main_spell_bound_embers_of_the_phoenix"] = "13,90",
    ["wh2_main_spell_bound_hand_of_gods"] = "2,120",
    ["wh2_main_spell_bound_khaines_ring_of_fury"] = "3,120",
    ["wh2_main_spell_bound_radiant_gem_of_hoeth"] = "12,60",
    ["wh2_main_spell_bound_ring_of_corin"] = "3,90",
    ["wh2_main_spell_bound_rod_of_the_storm"] = "3,90",
    ["wh2_main_spell_bound_rubric_of_dark_dimensions"] = "3,90",
    ["wh2_main_spell_bound_the_gem_of_sunfire"] = "3,90",
    ["wh2_main_spell_bound_the_seerstaff_of_saphery"] = "12,60",
    ["wh2_main_spell_bound_tome_of_furion"] = "2,60",
    ["wh2_main_spell_bound_wand_of_the_kharaidon"] = "2,120",
    ["wh2_main_spell_bound_whip_of_agony"] = "2,90",
    ["wh2_main_spell_dark_magic_bladewind"] = "19,38",
    ["wh2_main_spell_dark_magic_bladewind_upgraded"] = "19,38",
    ["wh2_main_spell_dark_magic_chillwind"] = "19,29",
    ["wh2_main_spell_dark_magic_chillwind_upgraded"] = "19,29",
    ["wh2_main_spell_dark_magic_doombolt"] = "18,47",
    ["wh2_main_spell_dark_magic_doombolt_upgraded"] = "18,47",
    ["wh2_main_spell_dark_magic_power_of_darkness"] = "28,28",
    ["wh2_main_spell_dark_magic_soul_stealer"] = "27,54",
    ["wh2_main_spell_dark_magic_word_of_pain"] = "18,44",
    ["wh2_main_spell_dark_magic_word_of_pain_upgraded"] = "18,44",
    ["wh2_main_spell_grey_seer_the_dreaded_thirteenth_spell"] = "19,52",
    ["wh2_main_spell_high_magic_apotheosis"] = "28,29",
    ["wh2_main_spell_high_magic_apotheosis_upgraded"] = "28,29",
    ["wh2_main_spell_high_magic_arcane_unforging"] = "18,52",
    ["wh2_main_spell_high_magic_arcane_unforging_upgraded"] = "18,52",
    ["wh2_main_spell_high_magic_fiery_convocation"] = "19,52",
    ["wh2_main_spell_high_magic_fiery_convocation_upgraded"] = "19,52",
    ["wh2_main_spell_high_magic_hand_of_glory"] = "28,28",
    ["wh2_main_spell_high_magic_hand_of_glory_upgraded"] = "28,28",
    ["wh2_main_spell_high_magic_soul_quench"] = "18,43",
    ["wh2_main_spell_high_magic_soul_quench_upgraded"] = "18,43",
    ["wh2_main_spell_high_magic_tempest"] = "18,37",
    ["wh2_main_spell_high_magic_tempest_upgraded"] = "18,44",
    ["wh2_main_spell_plague_bless_with_filth"] = "29,29",
    ["wh2_main_spell_plague_bless_with_filth_upgraded"] = "29,29",
    ["wh2_main_spell_plague_pestilent_birth"] = "29,48",
    ["wh2_main_spell_plague_pestilent_breath"] = "19,32",
    ["wh2_main_spell_plague_pestilent_breath_upgraded"] = "19,32",
    ["wh2_main_spell_plague_plague"] = "19,50",
    ["wh2_main_spell_plague_plague_upgraded"] = "19,50",
    ["wh2_main_spell_plague_vermintide"] = "29,41",
    ["wh2_main_spell_plague_wither"] = "19,37",
    ["wh2_main_spell_plague_wither_upgraded"] = "19,37",
    ["wh2_main_spell_ruin_cracks_call"] = "19,52",
    ["wh2_main_spell_ruin_cracks_call_upgraded"] = "19,52",
    ["wh2_main_spell_ruin_death_frenzy"] = "28,43",
    ["wh2_main_spell_ruin_death_frenzy_upgraded"] = "29,43",
    ["wh2_main_spell_ruin_howling_warpgale"] = "19,30",
    ["wh2_main_spell_ruin_howling_warpgale_upgraded"] = "19,30",
    ["wh2_main_spell_ruin_scorch"] = "19,44",
    ["wh2_main_spell_ruin_scorch_upgraded"] = "19,44",
    ["wh2_main_spell_ruin_skitterleap"] = "29,29",
    ["wh2_main_spell_ruin_skitterleap_upgraded"] = "29,29",
    ["wh2_main_spell_ruin_warp_lightning"] = "19,30",
    ["wh2_main_spell_ruin_warp_lightning_upgraded"] = "19,30",
    ["wh2_main_unit_abilities_concealment_bombs"] = "8,90",
    ["wh2_main_unit_abilities_dark_fire_of_chaos"] = "2,60",
    ["wh2_main_unit_abilities_death_shriek"] = "2,60",
    ["wh2_main_unit_abilities_drop_rocks"] = "0,5",
    ["wh2_main_unit_abilities_fiery_breath"] = "2,60",
    ["wh2_main_unit_abilities_fury_of_khaine"] = "4,90",
    ["wh2_main_unit_abilities_moon_dragons_breath"] = "2,60",
    ["wh2_main_unit_abilities_noxious_breath"] = "2,60",
    ["wh2_main_unit_abilities_pestilential_breath"] = "2,60",
    ["wh2_main_unit_abilities_revivification_crystal"] = "4,60",
    ["wh2_main_unit_abilities_soporific_breath"] = "2,60",
    ["wh2_main_unit_abilities_star_dragons_breath"] = "2,60",
    ["wh2_main_unit_abilities_sun_dragons_breath"] = "2,60",
    ["wh2_main_unit_abilities_wake_of_fire"] = "0,0",
    ["wh2_main_weapon_abilities_bow_of_the_seafarer"] = "2,90",
    ["wh2_main_weapon_abilities_dwarf_gouger"] = "8,120",
    ["wh2_main_weapon_abilities_hydra_blade"] = "8,120",
    ["wh2_main_weapon_abilities_sunfang"] = "3,120",
    ["wh2_main_weapon_abilities_sword_of_teclis"] = "8,120",
    ["wh2_main_weapon_abilities_web_of_shadows"] = "0,60",
    ["wh2_main_weapon_bound_reaver_bow"] = "2,90",
    ["wh2_main_weapon_bound_winged_staff"] = "3,60",
    ["wh2_pro08_character_abilities_gotrek_doom"] = "8,120",
    ["wh2_pro08_character_abilities_helping_hand"] = "4,120",
    ["wh2_pro08_weapon_abilities_karaghul"] = "8,120",
    ["wh2_pro08_weapon_abilities_rune_axe_of_gotrek"] = "8,120",
    ["wh2_twa03_lord_abilities_beastlords_gaze"] = "12,60",
    ["wh2_twa03_weapon_abilities_whip_of_agony"] = "2,120",
    ["wh3_cp1_army_abilities_tiger_warrior_reinforcements"] = "5,120",
    ["wh3_cp1_character_abilities_magic_prayer"] = "8,120",
    ["wh3_cp1_character_abilities_offense_prayer"] = "12,120",
    ["wh3_cp1_character_abilities_protection_prayer"] = "12,120",
    ["wh3_cp1_character_abilities_terrifying_presence"] = "8,120",
    ["wh3_cp1_item_abilities_heavens_gate"] = "1,120",
    ["wh3_cp1_lord_abilities_guiding_strike"] = "8,90",
    ["wh3_cp1_lord_abilities_hidden_huntress"] = "2,60",
    ["wh3_cp1_lord_abilities_hidden_huntress_upgraded"] = "2,90",
    ["wh3_cp1_lord_abilities_mastered_strike"] = "8,120",
    ["wh3_cp1_lord_abilities_predatory_instincts"] = "12,90",
    ["wh3_cp1_spell_beasts_transformation_of_kadon"] = "29,45",
    ["wh3_cp1_weapon_abilities_blades_of_shang_yang"] = "8,120",
    ["wh3_cp1_weapon_abilities_tyrants_talon"] = "8,120",
    ["wh3_dlc20_cataclysm_bound_ashes_and_dust"] = "3,120",
    ["wh3_dlc20_cataclysm_bound_dance_of_despair"] = "3,120",
    ["wh3_dlc20_cataclysm_bound_gehennas_golden_globe"] = "1,120",
    ["wh3_dlc20_cataclysm_bound_magma_storm"] = "1,120",
    ["wh3_dlc20_cataclysm_bound_merciws_monstrous_regiment"] = "4,120",
    ["wh3_dlc20_cataclysm_bound_storm_of_renewal"] = "1,120",
    ["wh3_dlc20_cataclysm_bound_thorsens_thunderstorm"] = "1,120",
    ["wh3_dlc20_cataclysm_bound_time_amok"] = "1,120",
    ["wh3_dlc20_item_abilities_daemonshield"] = "8,120",
    ["wh3_dlc20_item_abilities_pestilent_potions"] = "2,120",
    ["wh3_dlc20_item_abilities_rod_of_torment"] = "2,90",
    ["wh3_dlc20_item_abilities_the_armour_of_morkar"] = "8,120",
    ["wh3_dlc20_lord_abilities_harbinger_of_pestilence"] = "0,30",
    ["wh3_dlc20_lord_abilities_healing_elixirs"] = "8,30",
    ["wh3_dlc20_lord_abilities_tempest_rage"] = "8,120",
    ["wh3_dlc20_lord_abilities_temptator"] = "8,120",
    ["wh3_dlc20_spell_bound_flame_storm"] = "3,50",
    ["wh3_dlc20_spell_bound_fleshy_abundance"] = "12,54",
    ["wh3_dlc20_spell_bound_gehennas_golden_hounds"] = "3,45",
    ["wh3_dlc20_spell_bound_infernal_gateway"] = "3,54",
    ["wh3_dlc20_spell_bound_pink_fire_of_tzeentch"] = "3,30",
    ["wh3_dlc20_spell_bound_slicing_shards"] = "3,48",
    ["wh3_dlc20_spell_bound_stream_of_corruption"] = "3,29",
    ["wh3_dlc20_spell_bound_the_penumbral_pendulum"] = "3,40",
    ["wh3_dlc20_unit_abilities_storm_rage"] = "8,90",
    ["wh3_dlc20_unit_abilities_violent_wind"] = "8,120",
    ["wh3_dlc20_weapon_abilities_aether_sword"] = "8,90",
    ["wh3_dlc20_weapon_abilities_daemonblade"] = "8,120",
    ["wh3_dlc20_weapon_abilities_rapier_of_ecstasy"] = "8,90",
    ["wh3_dlc20_weapon_abilities_sliverslash"] = "8,120",
    ["wh3_dlc20_weapon_abilities_the_spear_slaupnir"] = "3,120",
    ["wh3_dlc23_army_abilities_armour_of_contempt"] = "13,120",
    ["wh3_dlc23_army_abilities_doom_of_hashut"] = "3,120",
    ["wh3_dlc23_army_abilities_guns_of_zharr"] = "3,60",
    ["wh3_dlc23_army_abilities_tower_ballistics"] = "1,90",
    ["wh3_dlc23_army_abilities_tower_ballistics_upgraded_toz"] = "1,90",
    ["wh3_dlc23_army_abilities_wrath_of_zharr"] = "3,90",
    ["wh3_dlc23_bound_abilities_breath_of_hatred"] = "13,90",
    ["wh3_dlc23_character_abilities_breath_of_hatred"] = "13,90",
    ["wh3_dlc23_character_abilities_reforge"] = "12,60",
    ["wh3_dlc23_character_abilities_skjalandirs_fall"] = "8,120",
    ["wh3_dlc23_character_abilities_sword_dance"] = "8,120",
    ["wh3_dlc23_hero_abilities_crooked_dice"] = "8,90",
    ["wh3_dlc23_hero_abilities_get_tha_gitz!"] = "3,120",
    ["wh3_dlc23_item_abilities_ancestral_vengeance"] = "1,120",
    ["wh3_dlc23_item_abilities_armour_of_gazrakh"] = "8,120",
    ["wh3_dlc23_item_abilities_black_gem_of_gnar"] = "8,90",
    ["wh3_dlc23_item_abilities_daemon_flask_of_ashak"] = "8,120",
    ["wh3_dlc23_item_abilities_darkened_mist"] = "2,120",
    ["wh3_dlc23_item_abilities_dweomer_leach_orb"] = "10,90",
    ["wh3_dlc23_item_abilities_hammer_of_smednir"] = "3,120",
    ["wh3_dlc23_item_abilities_morgrims_eye"] = "8,120",
    ["wh3_dlc23_item_abilities_rune_of_thungni"] = "12,120",
    ["wh3_dlc23_item_abilities_slayer_for_chaos"] = "8,120",
    ["wh3_dlc23_item_abilities_the_vial_of_hashut"] = "2,120",
    ["wh3_dlc23_lord_abilities_blood_and_fireborn"] = "13,120",
    ["wh3_dlc23_lord_abilities_flame_and_shadow"] = "3,90",
    ["wh3_dlc23_lord_abilities_sadistic_snare"] = "2,120",
    ["wh3_dlc23_spell_bound_burning_wrath"] = "2,30",
    ["wh3_dlc23_spell_bound_enfeebling_foe"] = "2,60",
    ["wh3_dlc23_spell_bound_hell_hammer"] = "3,50",
    ["wh3_dlc23_spell_bound_the_withering"] = "2,90",
    ["wh3_dlc23_spell_hashut_ash_storm"] = "25,37",
    ["wh3_dlc23_spell_hashut_ash_storm_upgraded"] = "25,37",
    ["wh3_dlc23_spell_hashut_burning_wrath"] = "18,30",
    ["wh3_dlc23_spell_hashut_burning_wrath_upgraded"] = "18,30",
    ["wh3_dlc23_spell_hashut_curse_of_hashut"] = "18,38",
    ["wh3_dlc23_spell_hashut_curse_of_hashut_upgraded"] = "18,38",
    ["wh3_dlc23_spell_hashut_dark_subjugation"] = "18,31",
    ["wh3_dlc23_spell_hashut_dark_subjugation_upgraded"] = "18,31",
    ["wh3_dlc23_spell_hashut_flames_of_azgorh"] = "19,52",
    ["wh3_dlc23_spell_hashut_flames_of_azgorh_upgraded"] = "19,52",
    ["wh3_dlc23_spell_hashut_hell_hammer"] = "19,50",
    ["wh3_dlc23_spell_hashut_hell_hammer_upgraded"] = "19,50",
    ["wh3_dlc23_unit_abilities_flaming_breath"] = "2,90",
    ["wh3_dlc23_unit_abilities_more_power"] = "8,90",
    ["wh3_dlc23_weapon_abilities_black_hammer_of_hashut"] = "8,120",
    ["wh3_dlc23_weapon_abilities_dagger_of_malice"] = "8,120",
    ["wh3_dlc23_weapon_abilities_dark_mace"] = "8,90",
    ["wh3_dlc23_weapon_abilities_silver_dagger"] = "8,120",
    ["wh3_dlc23_weapon_abilities_spell_wrought_sceptre"] = "12,90",
    ["wh3_dlc23_weapon_abilities_the_graven_sceptre"] = "8,120",
    ["wh3_dlc24_character_abilities_bastions_defenders"] = "12,90",
    ["wh3_dlc24_character_abilities_change_or_die"] = "8,90",
    ["wh3_dlc24_character_abilities_colossal_strike"] = "8,90",
    ["wh3_dlc24_character_abilities_colossal_strike_summoned"] = "8,90",
    ["wh3_dlc24_character_abilities_fury_of_the_land"] = "8,120",
    ["wh3_dlc24_character_abilities_giant_leap"] = "8,120",
    ["wh3_dlc24_character_abilities_tacticians_rally"] = "13,60",
    ["wh3_dlc24_character_abilities_tacticians_stand_your_ground"] = "13,90",
    ["wh3_dlc24_character_abilities_watched_by_the_watcher"] = "0,120",
    ["wh3_dlc24_hero_abilities_koldunjas_spirit"] = "9,120",
    ["wh3_dlc24_hero_abilities_thorns_aura"] = "8,120",
    ["wh3_dlc24_hero_abilities_vorozhejas_foresight"] = "2,120",
    ["wh3_dlc24_hero_abilities_windblade"] = "2,120",
    ["wh3_dlc24_hero_abilities_znarkharjas_ward"] = "8,90",
    ["wh3_dlc24_item_abilities_blessed_helm_of_the_oblast"] = "8,90",
    ["wh3_dlc24_item_abilities_book_of_secrets"] = "2,90",
    ["wh3_dlc24_item_abilities_mirror_of_knowledge"] = "9,37",
    ["wh3_dlc24_item_abilities_ritual_of_the_beast"] = "13,300",
    ["wh3_dlc24_item_abilities_the_golden_eye_of_tzeentch"] = "8,120",
    ["wh3_dlc24_item_abilities_wind_bow"] = "2,120",
    ["wh3_dlc24_lord_abilities_celestial_sweep"] = "8,120",
    ["wh3_dlc24_lord_abilities_formless_horror"] = "8,60",
    ["wh3_dlc24_lord_abilities_formless_horror_changeling"] = "8,60",
    ["wh3_dlc24_lord_abilities_formless_horror_quest_battle"] = "8,60",
    ["wh3_dlc24_lord_abilities_formless_horror_quest_battle_changeling_form"] = "8,60",
    ["wh3_dlc24_lord_abilities_gulyas"] = "9,120",
    ["wh3_dlc24_lord_abilities_jade_dragon_dragon_form"] = "8,120",
    ["wh3_dlc24_lord_abilities_jade_dragon_human_form"] = "8,120",
    ["wh3_dlc24_lord_abilities_lord_of_grand_cathay"] = "9,120",
    ["wh3_dlc24_lord_abilities_spirit_bear"] = "2,120",
    ["wh3_dlc24_lord_abilities_spirit_bear_upgrade"] = "2,120",
    ["wh3_dlc24_lord_abilities_taals_judgement"] = "2,90",
    ["wh3_dlc24_lord_abilities_the_emperors_executioner"] = "2,120",
    ["wh3_dlc24_lord_abilities_the_emperors_executioner_upgrade"] = "2,120",
    ["wh3_dlc24_lord_item_deceiving_shadows"] = "9,120",
    ["wh3_dlc24_spell_hags_curse_of_the_ancient_witch"] = "18,27",
    ["wh3_dlc24_spell_hags_curse_of_the_ancient_witch_upgraded"] = "28,35",
    ["wh3_dlc24_spell_hags_cursed_cauldron"] = "19,18",
    ["wh3_dlc24_spell_hags_cursed_cauldron_upgraded"] = "19,18",
    ["wh3_dlc24_spell_hags_malediction_of_madness"] = "18,45",
    ["wh3_dlc24_spell_hags_malediction_of_madness_upgraded"] = "28,45",
    ["wh3_dlc24_spell_hags_the_forbidden_fens"] = "17,31",
    ["wh3_dlc24_spell_hags_the_forbidden_fens_upgraded"] = "25,32",
    ["wh3_dlc24_spell_hags_vengeance_of_spirits"] = "17,38",
    ["wh3_dlc24_spell_hags_vengeance_of_spirits_upgraded"] = "25,40",
    ["wh3_dlc24_spell_hags_witchbrew"] = "19,30",
    ["wh3_dlc24_spell_hags_witchbrew_upgraded"] = "25,30",
    ["wh3_dlc24_spell_the_changeling_drowned_dead"] = "13,60",
    ["wh3_dlc24_tze_changeling_theatre_scheme_grand_cathay_doom_rocket"] = "3,0",
    ["wh3_dlc24_unit_abilities_bastion_of_the_great_cities"] = "8,30",
    ["wh3_dlc24_unit_abilities_disdain_of_the_dragon_emperor"] = "8,30",
    ["wh3_dlc24_unit_abilities_fearsome_roar"] = "0,90",
    ["wh3_dlc24_unit_abilities_fury_of_the_falling_blade"] = "8,30",
    ["wh3_dlc24_unit_abilities_hags_denial"] = "8,120",
    ["wh3_dlc24_unit_abilities_howl_of_the_great_beast"] = "0,90",
    ["wh3_dlc24_unit_abilities_ice_breath"] = "2,60",
    ["wh3_dlc24_unit_abilities_jade_dragons_breath"] = "3,30",
    ["wh3_dlc24_unit_abilities_lampreys_bite"] = "9,90",
    ["wh3_dlc24_unit_abilities_maelstrom_of_change"] = "2,60",
    ["wh3_dlc24_unit_abilities_mark_of_yin"] = "2,120",
    ["wh3_dlc24_unit_abilities_moon_flare"] = "8,90",
    ["wh3_dlc24_unit_abilities_nan_gau_grenades"] = "0,60",
    ["wh3_dlc24_unit_abilities_pack_trap"] = "2,90",
    ["wh3_dlc24_unit_abilities_witchbrew"] = "8,90",
    ["wh3_dlc24_unit_bound_missile_mirror"] = "2,44",
    ["wh3_dlc24_unit_passive_petrifying_gaze"] = "2,120",
    ["wh3_dlc24_weapon_abilities_dragons_fang"] = "8,120",
    ["wh3_dlc24_weapon_abilities_ursuns_claw"] = "8,120",
    ["wh3_dlc25_abilities_restock_gunnery_school"] = "4,60",
    ["wh3_dlc25_army_abilities_bjuna_bombard"] = "1,120",
    ["wh3_dlc25_army_abilities_call_of_the_wild"] = "5,120",
    ["wh3_dlc25_army_abilities_gyrocopter_bomb"] = "0,0",
    ["wh3_dlc25_army_abilities_launch_gyrocopters"] = "1,120",
    ["wh3_dlc25_army_abilities_pandemicium"] = "1,120",
    ["wh3_dlc25_army_abilities_purple_eclipse"] = "1,120",
    ["wh3_dlc25_army_abilities_spirit_barrage"] = "2,120",
    ["wh3_dlc25_army_abilities_spirit_of_grungni"] = "1,120",
    ["wh3_dlc25_army_abilities_summon_miners"] = "3,45",
    ["wh3_dlc25_cataclysm_beasts_merciws_monstrous_regiment_com"] = "20,120",
    ["wh3_dlc25_cataclysm_death_ashes_and_dust_com"] = "19,120",
    ["wh3_dlc25_cataclysm_fire_magma_storm_com"] = "17,120",
    ["wh3_dlc25_cataclysm_heavens_thorsens_thunderstorm_com"] = "17,120",
    ["wh3_dlc25_cataclysm_life_storm_of_renewal_com"] = "17,120",
    ["wh3_dlc25_cataclysm_light_time_amok_com"] = "17,120",
    ["wh3_dlc25_cataclysm_metal_gehennas_golden_globe_com"] = "17,120",
    ["wh3_dlc25_cataclysm_shadow_dance_of_despair_com"] = "19,120",
    ["wh3_dlc25_character_abilities_children_of_the_forest"] = "13,90",
    ["wh3_dlc25_character_abilities_get_em"] = "3,90",
    ["wh3_dlc25_character_abilities_guardian_of_the_forest"] = "13,120",
    ["wh3_dlc25_character_abilities_hurricane_of_death"] = "8,120",
    ["wh3_dlc25_character_abilities_kettles_call"] = "5,120",
    ["wh3_dlc25_character_abilities_mercurial_shot"] = "2,90",
    ["wh3_dlc25_character_abilities_pigeon_bomb"] = "3,120",
    ["wh3_dlc25_character_abilities_sands_of_sickness"] = "8,120",
    ["wh3_dlc25_character_abilities_surprise_squig"] = "13,60",
    ["wh3_dlc25_character_abilities_tallymans_blades"] = "5,120",
    ["wh3_dlc25_character_abilities_tallymans_blades_2"] = "5,120",
    ["wh3_dlc25_character_abilties_epidemic_outbreak"] = "8,90",
    ["wh3_dlc25_character_abilties_epidemic_outbreak_improved"] = "8,90",
    ["wh3_dlc25_hero_abilities_titan_headsman"] = "2,90",
    ["wh3_dlc25_item_abilities_deaths_timekeeper"] = "10,120",
    ["wh3_dlc25_item_abilities_necrotic_phylactry"] = "8,90",
    ["wh3_dlc25_item_abilities_ominous_powder"] = "8,120",
    ["wh3_dlc25_item_abilities_stormlance"] = "8,120",
    ["wh3_dlc25_item_abilities_the_gold_standard"] = "12,90",
    ["wh3_dlc25_lord_abilities_cinderblast_cluster_bomb"] = "2,120",
    ["wh3_dlc25_lord_abilities_darkwalker"] = "8,120",
    ["wh3_dlc25_lord_abilities_deranged_munitions"] = "12,90",
    ["wh3_dlc25_lord_abilities_deranged_munitions_upgraded"] = "8,90",
    ["wh3_dlc25_lord_abilities_glorious_death"] = "8,120",
    ["wh3_dlc25_lord_abilities_nemesis_crown"] = "3,120",
    ["wh3_dlc25_lord_abilities_nurgles_favoured_son"] = "8,120",
    ["wh3_dlc25_lord_abilities_rot_or_die"] = "8,90",
    ["wh3_dlc25_spell_Bound_doom_and_darkness_gunnery_school"] = "2,90",
    ["wh3_dlc25_spell_bound_fire_the_burning_head"] = "3,90",
    ["wh3_dlc25_spell_bound_spirit_leech"] = "2,32",
    ["wh3_dlc25_spell_bound_spirit_leech_gunnery_school"] = "2,32",
    ["wh3_dlc25_spell_bound_the_fate_of_bjuna"] = "2,52",
    ["wh3_dlc25_unit_abilities_coruscating_blast"] = "2,120",
    ["wh3_dlc25_unit_abilities_full_power"] = "8,90",
    ["wh3_dlc25_unit_abilities_gyrobomber_fire_bomb"] = "0,3",
    ["wh3_dlc25_unit_abilities_gyrocopter_bomb_anti_large"] = "0,0",
    ["wh3_dlc25_unit_abilities_marienburg_land_mines"] = "0,10",
    ["wh3_dlc25_unit_abilities_spear_of_grungni"] = "2,120",
    ["wh3_dlc25_unit_abilities_thunderbarge_fire_bomb"] = "0,3",
    ["wh3_dlc25_unit_abilities_thunderburner"] = "8,30",
    ["wh3_dlc25_unit_abilities_thunderburner_upgraded"] = "8,30",
    ["wh3_dlc25_unit_abilities_unspeakable_foulness"] = "2,60",
    ["wh3_dlc25_unit_abilities_whirlwind_of_death"] = "8,90",
    ["wh3_dlc25_unit_abilities_whirlwind_of_death_ror"] = "8,60",
    ["wh3_dlc25_unit_abilities_whirlwind_of_death_ror_upgraded"] = "8,60",
    ["wh3_dlc25_unit_abilities_whirlwind_of_death_upgraded"] = "8,90",
    ["wh3_dlc25_unit_formation_shieldwall"] = "8,-1",
    ["wh3_dlc25_unit_formation_shieldwall_upgraded"] = "8,-1",
    ["wh3_dlc25_weapon_abilities_axes_of_kadrin"] = "8,120",
    ["wh3_dlc25_weapon_abilities_experimental_explosive"] = "2,120",
    ["wh3_dlc25_weapon_abilities_liarsbane"] = "8,60",
    ["wh3_dlc25_weapon_abilities_makaissons_persuader"] = "12,120",
    ["wh3_dlc25_weapon_abilities_sword_of_filth"] = "2,120",
    ["wh3_dlc25_weapon_abilities_the_black_cleaver"] = "8,120",
    ["wh3_dlc25_weapon_abilities_the_father_of_blades"] = "8,90",
    ["wh3_dlc26_army_abilities_blood_gods_shackles"] = "2,120",
    ["wh3_dlc26_army_abilities_blood_gods_shackles_upgraded"] = "2,120",
    ["wh3_dlc26_army_abilities_boiling_cauldron"] = "3,120",
    ["wh3_dlc26_army_abilities_cut_da_chains"] = "13,120",
    ["wh3_dlc26_army_abilities_da_plan_foot_of_gork"] = "3,180",
    ["wh3_dlc26_army_abilities_fly_at_da_smoke"] = "3,120",
    ["wh3_dlc26_army_abilities_gorbads_big_waaagh"] = "0,-1",
    ["wh3_dlc26_army_abilities_gorbads_waaagh"] = "0,-1",
    ["wh3_dlc26_army_abilities_khornes_wrath"] = "2,120",
    ["wh3_dlc26_character_abilities_bloody_onslaught"] = "2,90",
    ["wh3_dlc26_character_abilities_cash_cascade"] = "5,120",
    ["wh3_dlc26_character_abilities_crimson_juggernaut"] = "8,120",
    ["wh3_dlc26_character_abilities_da_boss_as_a_plan"] = "4,90",
    ["wh3_dlc26_character_abilities_dead_eye"] = "2,120",
    ["wh3_dlc26_character_abilities_dinner_bell"] = "8,90",
    ["wh3_dlc26_character_abilities_empowering_shrooms"] = "13,90",
    ["wh3_dlc26_character_abilities_headhunt"] = "2,90",
    ["wh3_dlc26_character_abilities_inevitable_horror"] = "0,120",
    ["wh3_dlc26_character_abilities_inventory_of_hatchlings"] = "3,120",
    ["wh3_dlc26_character_abilities_inventory_of_hatchlings_upgraded"] = "3,60",
    ["wh3_dlc26_character_abilities_kill_for_khorne"] = "8,120",
    ["wh3_dlc26_character_abilities_mumbo_jumbo_chant"] = "8,120",
    ["wh3_dlc26_character_abilities_orcs_are_da_best"] = "4,90",
    ["wh3_dlc26_character_abilities_puncture"] = "8,90",
    ["wh3_dlc26_character_abilities_spider_web_attack"] = "2,120",
    ["wh3_dlc26_character_abilities_squig_thinkin"] = "9,90",
    ["wh3_dlc26_character_abilities_sting_of_snagla"] = "2,120",
    ["wh3_dlc26_character_abilities_were_you_goin"] = "4,90",
    ["wh3_dlc26_hero_abilities_savage_predators"] = "5,120",
    ["wh3_dlc26_item_abilities_bugmans_xxxxxx"] = "8,120",
    ["wh3_dlc26_item_tmb_liche_priest_viziers_kanopi"] = "13,-1",
    ["wh3_dlc26_lord_abilities_blood_sacrifice"] = "12,60",
    ["wh3_dlc26_lord_abilities_boiling_cauldron"] = "3,120",
    ["wh3_dlc26_lord_abilities_eye_of_khorne"] = "2,120",
    ["wh3_dlc26_lord_abilities_feasting_frenzy"] = "0,-1",
    ["wh3_dlc26_lord_abilities_gaze_of_khorne"] = "8,120",
    ["wh3_dlc26_lord_abilities_gorger_onslaught_upgraded"] = "3,90",
    ["wh3_dlc26_lord_abilities_murderous_exhortations"] = "0,120",
    ["wh3_dlc26_lord_abilities_pilgrimage_of_skulls"] = "12,120",
    ["wh3_dlc26_lord_abilities_simmering_pot"] = "3,90",
    ["wh3_dlc26_lord_abilities_wild_abandon"] = "12,90",
    ["wh3_dlc26_spell_bound_bonecrusher"] = "3,90",
    ["wh3_dlc26_spell_bound_trollguts"] = "12,90",
    ["wh3_dlc26_unit_abilities_acid_vomit"] = "8,120",
    ["wh3_dlc26_unit_abilities_eat_da_runts"] = "12,90",
    ["wh3_dlc26_unit_abilities_immovable_bulwark"] = "8,1",
    ["wh3_dlc26_unit_abilities_maneater_smoke_bomb"] = "8,90",
    ["wh3_dlc26_unit_abilities_marked_for_eatin"] = "2,120",
    ["wh3_dlc26_unit_abilities_net_dem_up"] = "2,90",
    ["wh3_dlc26_unit_abilities_splode_da_big_one"] = "8,0",
    ["wh3_dlc26_unit_abilities_unstoppable_choppas"] = "8,1",
    ["wh3_dlc26_unit_abilities_waaagh_in_combat"] = "8,90",
    ["wh3_dlc26_weapon_abilities_bloodstorm_blades"] = "8,120",
    ["wh3_dlc26_weapon_abilities_fangspike"] = "8,120",
    ["wh3_dlc26_weapon_abilities_great_gutgouger"] = "8,120",
    ["wh3_dlc26_weapon_abilities_morglor_the_mangler"] = "8,120",
    ["wh3_dlc26_weapon_abilities_the_slayer_sword"] = "8,120",
    ["wh3_dlc27_army_abilities_asuryans_fury"] = "3,60",
    ["wh3_dlc27_army_abilities_asuryans_rage"] = "3,60",
    ["wh3_dlc27_army_abilities_asuryans_wrath"] = "3,60",
    ["wh3_dlc27_army_abilities_decadence_in_praise_of_sla_i"] = "2,180",
    ["wh3_dlc27_army_abilities_dragonship_assault"] = "3,60",
    ["wh3_dlc27_army_abilities_dragonship_blitz"] = "3,60",
    ["wh3_dlc27_army_abilities_dragonship_volley"] = "3,60",
    ["wh3_dlc27_army_abilities_eternal_dance_tempo_3_carver_of_ways"] = "1,120",
    ["wh3_dlc27_army_abilities_eternal_dance_tempo_3_denial_of_death"] = "4,90",
    ["wh3_dlc27_army_abilities_eternal_dance_tempo_3_fate_of_desperation"] = "1,120",
    ["wh3_dlc27_army_abilities_eternal_dance_tempo_3_insidious_allure"] = "1,120",
    ["wh3_dlc27_army_abilities_eternal_dance_tempo_3_jesters_laughter"] = "1,120",
    ["wh3_dlc27_army_abilities_eternal_dance_tempo_3_nectar_of_the_daemonette"] = "4,120",
    ["wh3_dlc27_army_abilities_eternal_dance_tempo_3_needful_caress"] = "1,120",
    ["wh3_dlc27_army_abilities_eternal_dance_tempo_3_path_of_indulgence"] = "1,120",
    ["wh3_dlc27_army_abilities_eternal_dance_tempo_3_poisonous_aroma"] = "2,120",
    ["wh3_dlc27_army_abilities_eternal_dance_tempo_3_revelry_and_madness"] = "1,120",
    ["wh3_dlc27_army_abilities_eternal_dance_tempo_3_streams_of_euphoria"] = "1,120",
    ["wh3_dlc27_army_abilities_eternal_dance_tempo_3_submission_to_the_prince"] = "2,90",
    ["wh3_dlc27_army_abilities_eternal_dance_tempo_3_tempest_of_depravity"] = "1,120",
    ["wh3_dlc27_army_abilities_sayl_manipulations_spawn_shaman_death"] = "5,90",
    ["wh3_dlc27_army_abilities_sayl_manipulations_spawn_shaman_fire"] = "5,90",
    ["wh3_dlc27_army_abilities_sayl_manipulations_spawn_shaman_metal"] = "5,90",
    ["wh3_dlc27_army_abilities_ships_of_the_line"] = "5,60",
    ["wh3_dlc27_army_abilities_war_supplies"] = "5,60",
    ["wh3_dlc27_army_high_magic_apotheosis"] = "12,29",
    ["wh3_dlc27_army_high_magic_hand_of_glory"] = "12,28",
    ["wh3_dlc27_army_high_magic_tempest"] = "2,44",
    ["wh3_dlc27_cataclysm_bound_ashes_and_dust"] = "3,120",
    ["wh3_dlc27_cataclysm_bound_dance_of_despair"] = "3,120",
    ["wh3_dlc27_cataclysm_bound_gehennas_golden_globe"] = "1,120",
    ["wh3_dlc27_cataclysm_bound_magma_storm"] = "1,120",
    ["wh3_dlc27_cataclysm_bound_merciws_monstrous_regiment"] = "4,120",
    ["wh3_dlc27_cataclysm_bound_storm_of_renewal"] = "1,120",
    ["wh3_dlc27_cataclysm_bound_thorsens_thunderstorm"] = "1,120",
    ["wh3_dlc27_cataclysm_bound_time_amok"] = "1,120",
    ["wh3_dlc27_character_abilities_captain_of_the_phoenix_guard"] = "4,120",
    ["wh3_dlc27_character_abilities_envelop_in_mist_bound"] = "1,120",
    ["wh3_dlc27_character_abilities_iron_hand_captain"] = "4,120",
    ["wh3_dlc27_character_abilities_master_of_mists"] = "9,120",
    ["wh3_dlc27_character_abilities_master_of_mists_custom"] = "9,120",
    ["wh3_dlc27_character_abilities_nightmaw"] = "3,45",
    ["wh3_dlc27_character_abilities_slezuzus_voice"] = "4,120",
    ["wh3_dlc27_character_abilities_the_black_tongue"] = "2,120",
    ["wh3_dlc27_hero_abilities_favoured_by_the_matriarch"] = "8,90",
    ["wh3_dlc27_item_abilities_bear_fang_talisman"] = "8,90",
    ["wh3_dlc27_item_abilities_eagle_feather_torc"] = "8,120",
    ["wh3_dlc27_item_abilities_elixir_of_damnation"] = "8,120",
    ["wh3_dlc27_item_abilities_mask_of_the_merlord"] = "1,120",
    ["wh3_dlc27_item_abilities_null_stone"] = "0,120",
    ["wh3_dlc27_item_abilities_power_familiar"] = "8,90",
    ["wh3_dlc27_item_abilities_preyton_horns"] = "10,90",
    ["wh3_dlc27_item_abilities_schalkains_teeth"] = "2,90",
    ["wh3_dlc27_item_abilities_spurting_bile_blood"] = "8,0",
    ["wh3_dlc27_item_abilities_staff_of_the_masque"] = "10,120",
    ["wh3_dlc27_item_abilities_warrior_familiar"] = "8,90",
    ["wh3_dlc27_item_passive_petrifying_gaze"] = "2,-1",
    ["wh3_dlc27_lord_abilities_chanson_of_caging"] = "8,20",
    ["wh3_dlc27_lord_abilities_daggerdance"] = "8,30",
    ["wh3_dlc27_lord_abilities_dance_of_destruction"] = "8,30",
    ["wh3_dlc27_lord_abilities_offering_to_the_gods"] = "4,120",
    ["wh3_dlc27_lord_abilities_quicksilver_strike"] = "8,60",
    ["wh3_dlc27_lord_abilities_the_dance_of_dreaming"] = "8,20",
    ["wh3_dlc27_lord_abilities_the_praise_of_slaanesh"] = "8,30",
    ["wh3_dlc27_lord_abilities_the_waltz_of_lethargy"] = "8,20",
    ["wh3_dlc27_lord_abilities_whirlwind_of_pleasure"] = "8,120",
    ["wh3_dlc27_qb_unit_abilities_bitter_sting"] = "2,60",
    ["wh3_dlc27_qb_unit_abilities_copious_phlegm"] = "3,45",
    ["wh3_dlc27_qb_unit_abilities_dissolving_bone"] = "2,60",
    ["wh3_dlc27_qb_unit_abilities_frenzied_challenge"] = "2,90",
    ["wh3_dlc27_qb_unit_abilities_guttural_roar"] = "0,90",
    ["wh3_dlc27_qb_unit_abilities_insanity"] = "2,-1",
    ["wh3_dlc27_qb_unit_abilities_terrible_malice"] = "2,90",
    ["wh3_dlc27_qb_unit_abilities_visions_of_madness"] = "2,120",
    ["wh3_dlc27_recipe_mark_of_vindictiveness_ascendancy_i"] = "8,-1",
    ["wh3_dlc27_recipe_mark_of_vindictiveness_ascendancy_ii"] = "8,-1",
    ["wh3_dlc27_recipe_mark_of_vindictiveness_ascendancy_iii"] = "8,-1",
    ["wh3_dlc27_spell_bound_acquiescence"] = "2,60",
    ["wh3_dlc27_spell_bound_enfeebling_foe"] = "2,60",
    ["wh3_dlc27_spell_bound_fireball_upgraded"] = "2,60",
    ["wh3_dlc27_spell_bound_lash_of_slaanesh"] = "3,60",
    ["wh3_dlc27_spell_bound_pit_of_shades"] = "3,120",
    ["wh3_dlc27_spell_bound_runecaller_death_doom_and_darkness"] = "2,90",
    ["wh3_dlc27_spell_bound_runecaller_flock_of_doom"] = "3,60",
    ["wh3_dlc27_spell_bound_soul_stealer"] = "11,120",
    ["wh3_dlc27_spell_bound_transformation_of_kadon"] = "13,45",
    ["wh3_dlc27_spell_dark_magic_chillwind_bound"] = "3,29",
    ["wh3_dlc27_spell_dark_magic_word_of_pain_bound_1use"] = "2,90",
    ["wh3_dlc27_spell_death_doom_and_darkness_summoned"] = "19,43",
    ["wh3_dlc27_spell_death_spirit_leech_summoned"] = "18,32",
    ["wh3_dlc27_spell_death_the_purple_sun_of_xereus_summoned"] = "19,54",
    ["wh3_dlc27_spell_fire_fireball_summoned"] = "18,29",
    ["wh3_dlc27_spell_fire_flame_storm_summoned"] = "19,50",
    ["wh3_dlc27_spell_fire_the_burning_head_summoned"] = "19,37",
    ["wh3_dlc27_spell_heavens_chain_lightning"] = "18,50",
    ["wh3_dlc27_spell_heavens_chain_lightning_bound"] = "2,50",
    ["wh3_dlc27_spell_heavens_chain_lightning_bound_unit"] = "2,60",
    ["wh3_dlc27_spell_metal_final_transmutation_summoned"] = "19,54",
    ["wh3_dlc27_spell_metal_gehennas_golden_hounds_summoned"] = "19,45",
    ["wh3_dlc27_spell_metal_searing_doom_summoned"] = "19,30",
    ["wh3_dlc27_spell_mists_flensing_haar"] = "18,45",
    ["wh3_dlc27_spell_mists_flensing_haar_upgraded"] = "18,45",
    ["wh3_dlc27_spell_mists_ladrielles_shroud"] = "28,40",
    ["wh3_dlc27_spell_mists_ladrielles_shroud_upgraded"] = "28,40",
    ["wh3_dlc27_spell_mists_mathlanns_spite"] = "18,37",
    ["wh3_dlc27_spell_mists_mathlanns_spite_upgraded"] = "18,37",
    ["wh3_dlc27_spell_mists_mistress_of_the_deeps"] = "29,46",
    ["wh3_dlc27_spell_mists_the_writhing_mist"] = "29,56",
    ["wh3_dlc27_spell_mists_the_writhing_mist_bound"] = "13,56",
    ["wh3_dlc27_spell_mists_the_writhing_mist_upgraded"] = "29,56",
    ["wh3_dlc27_spell_mists_walk_between_worlds"] = "28,45",
    ["wh3_dlc27_spell_mists_walk_between_worlds_upgraded"] = "28,45",
    ["wh3_dlc27_spell_shadow_melkoths_mystifying_miasma_bound"] = "2,29",
    ["wh3_dlc27_unit_abilities_burrow"] = "1,60",
    ["wh3_dlc27_unit_abilities_consuming_hatred"] = "8,120",
    ["wh3_dlc27_unit_abilities_dread_maw_surface"] = "8,25",
    ["wh3_dlc27_unit_abilities_dread_maw_underground"] = "8,20",
    ["wh3_dlc27_unit_abilities_elfish_healing_herbs"] = "4,90",
    ["wh3_dlc27_unit_abilities_flaming_breath"] = "2,90",
    ["wh3_dlc27_unit_abilities_perfect_predator"] = "8,120",
    ["wh3_dlc27_weapon_abilities_tenebrous_forge_hammer"] = "8,90",
    ["wh3_dlc27_weapon_abilities_the_phoenix_blade"] = "8,120",
    ["wh3_main_abilities_call_horse_archers"] = "1,120",
    ["wh3_main_army_abilities_ancestral_warriors"] = "5,120",
    ["wh3_main_army_abilities_arcane_surge"] = "4,60",
    ["wh3_main_army_abilities_blade_of_khorne"] = "3,120",
    ["wh3_main_army_abilities_bolt_of_change"] = "2,90",
    ["wh3_main_army_abilities_celestial_intervention"] = "3,120",
    ["wh3_main_army_abilities_curse_of_the_slug"] = "2,60",
    ["wh3_main_army_abilities_fascination"] = "2,120",
    ["wh3_main_army_abilities_fecundity"] = "12,90",
    ["wh3_main_army_abilities_gluttony"] = "4,90",
    ["wh3_main_army_abilities_horn_of_khorne"] = "5,90",
    ["wh3_main_army_abilities_narcissism"] = "2,90",
    ["wh3_main_army_abilities_relentless_rage"] = "4,90",
    ["wh3_main_army_abilities_rot_glorious_rot"] = "2,120",
    ["wh3_main_army_abilities_stoneshaker"] = "3,120",
    ["wh3_main_army_abilities_storm_of_fire"] = "3,120",
    ["wh3_main_army_abilities_summoned_from_beyond_daemon_prince"] = "3,90",
    ["wh3_main_army_abilities_summoned_from_beyond_khorne"] = "3,120",
    ["wh3_main_army_abilities_summoned_from_beyond_nurgle"] = "3,120",
    ["wh3_main_army_abilities_summoned_from_beyond_slaanesh"] = "3,120",
    ["wh3_main_army_abilities_summoned_from_beyond_tzeentch"] = "3,120",
    ["wh3_main_army_abilities_sweet_sorrow"] = "4,60",
    ["wh3_main_army_abilities_the_bitterness_of_winter"] = "3,90",
    ["wh3_main_army_abilities_the_land_awakened"] = "3,120",
    ["wh3_main_army_abilities_thunder_charge"] = "3,120",
    ["wh3_main_army_abilities_wrath_of_the_bear"] = "4,90",
    ["wh3_main_banner_abilities_banner_of_hellfire"] = "0,120",
    ["wh3_main_cataclysm_beasts_merciws_monstrous_regiment"] = "4,0",
    ["wh3_main_cataclysm_death_ashes_and_dust"] = "3,0",
    ["wh3_main_cataclysm_fire_magma_storm"] = "1,0",
    ["wh3_main_cataclysm_heavens_thorsens_thunderstorm"] = "1,0",
    ["wh3_main_cataclysm_khorne_greater_gate_of_khorne"] = "13,0",
    ["wh3_main_cataclysm_life_storm_of_renewal"] = "1,0",
    ["wh3_main_cataclysm_light_time_amok"] = "1,0",
    ["wh3_main_cataclysm_metal_gehennas_golden_globe"] = "1,0",
    ["wh3_main_cataclysm_shadow_dance_of_despair"] = "3,0",
    ["wh3_main_character_abilities_arsebelcher"] = "8,120",
    ["wh3_main_character_abilities_crippling_throw"] = "2,90",
    ["wh3_main_character_abilities_dazs_song_of_winter_sunlight"] = "8,90",
    ["wh3_main_character_abilities_enchanted_metallurgy"] = "13,60",
    ["wh3_main_character_abilities_enchanted_metallurgy_flaming"] = "13,90",
    ["wh3_main_character_abilities_enchanted_metallurgy_piercing"] = "13,90",
    ["wh3_main_character_abilities_enchanted_metallurgy_poison"] = "13,90",
    ["wh3_main_character_abilities_eruption"] = "8,120",
    ["wh3_main_character_abilities_extra_ingredients"] = "8,90",
    ["wh3_main_character_abilities_fire_breath"] = "2,60",
    ["wh3_main_character_abilities_flame_incarnate"] = "8,90",
    ["wh3_main_character_abilities_from_the_shadows"] = "8,120",
    ["wh3_main_character_abilities_gate_of_khorne"] = "5,120",
    ["wh3_main_character_abilities_gate_of_nurgle"] = "5,120",
    ["wh3_main_character_abilities_gate_of_slaanesh"] = "5,120",
    ["wh3_main_character_abilities_gate_of_tzeentch"] = "5,120",
    ["wh3_main_character_abilities_glacial_blast"] = "8,90",
    ["wh3_main_character_abilities_greater_gate_of_khorne"] = "13,120",
    ["wh3_main_character_abilities_greater_gate_of_nurgle"] = "13,120",
    ["wh3_main_character_abilities_greater_gate_of_slaanesh"] = "13,120",
    ["wh3_main_character_abilities_greater_gate_of_tzeentch"] = "13,120",
    ["wh3_main_character_abilities_groundbreaker"] = "8,90",
    ["wh3_main_character_abilities_guardian_call"] = "3,0",
    ["wh3_main_character_abilities_guardian_call_ii"] = "3,0",
    ["wh3_main_character_abilities_guardian_call_iii"] = "3,0",
    ["wh3_main_character_abilities_ice_shard"] = "2,90",
    ["wh3_main_character_abilities_locus_of_abjuration"] = "8,90",
    ["wh3_main_character_abilities_locus_of_beguilement"] = "0,90",
    ["wh3_main_character_abilities_locus_of_change"] = "8,90",
    ["wh3_main_character_abilities_locus_of_conjuration"] = "8,90",
    ["wh3_main_character_abilities_locus_of_contagion"] = "0,90",
    ["wh3_main_character_abilities_locus_of_fecundity"] = "8,90",
    ["wh3_main_character_abilities_locus_of_fury"] = "8,90",
    ["wh3_main_character_abilities_locus_of_grace"] = "8,90",
    ["wh3_main_character_abilities_locus_of_swiftness"] = "8,90",
    ["wh3_main_character_abilities_locus_of_transmogrification"] = "13,90",
    ["wh3_main_character_abilities_locus_of_virulence"] = "8,90",
    ["wh3_main_character_abilities_locus_of_wrath"] = "8,90",
    ["wh3_main_character_abilities_no_escape"] = "2,90",
    ["wh3_main_character_abilities_salyaks_lullaby"] = "8,90",
    ["wh3_main_character_abilities_silence_the_prey"] = "2,60",
    ["wh3_main_character_abilities_tors_battle_hymn"] = "8,90",
    ["wh3_main_character_abilities_unyielding_defender"] = "8,90",
    ["wh3_main_character_abilities_ursuns_roar"] = "8,60",
    ["wh3_main_daemon_arms_abilities_blue_fire"] = "1,30",
    ["wh3_main_daemon_arms_abilities_blue_fire_upgraded"] = "1,30",
    ["wh3_main_daemon_arms_abilities_gate_of_chaos"] = "1,120",
    ["wh3_main_daemon_arms_abilities_gate_of_chaos_upgraded"] = "1,120",
    ["wh3_main_daemon_arms_abilities_mortal_blow"] = "8,60",
    ["wh3_main_daemon_arms_abilities_mortal_blow_upgraded"] = "8,90",
    ["wh3_main_daemon_body_abilities_winds_of_change"] = "8,120",
    ["wh3_main_daemon_head_abilities_call_for_power"] = "8,120",
    ["wh3_main_daemon_head_abilities_pestilent_regeneration"] = "8,120",
    ["wh3_main_daemon_head_abilities_sonic_boom"] = "0,90",
    ["wh3_main_daemon_head_abilities_word_of_change"] = "2,120",
    ["wh3_main_daemon_legs_abilities_daemonic_onslaught"] = "8,90",
    ["wh3_main_daemon_wings_abilities_purge_the_weak"] = "8,90",
    ["wh3_main_daemon_wings_abilities_trophy_heads"] = "2,120",
    ["wh3_main_item_abilities_alchemists_elixir_of_iron_skin"] = "12,90",
    ["wh3_main_item_abilities_alchemists_elixir_of_puissance"] = "12,90",
    ["wh3_main_item_abilities_alchemists_elixir_of_venom"] = "12,90",
    ["wh3_main_item_abilities_bangstick"] = "3,90",
    ["wh3_main_item_abilities_bloodstone"] = "9,120",
    ["wh3_main_item_abilities_crackleblaze"] = "3,90",
    ["wh3_main_item_abilities_deaths_head"] = "3,120",
    ["wh3_main_item_abilities_fistful_of_laurels"] = "8,120",
    ["wh3_main_item_abilities_gastuvas_egg"] = "8,-1",
    ["wh3_main_item_abilities_gruts_sickle"] = "4,60",
    ["wh3_main_item_abilities_kovsh_breath"] = "3,60",
    ["wh3_main_item_abilities_maw_shard"] = "8,60",
    ["wh3_main_item_abilities_potion_of_farsight"] = "8,60",
    ["wh3_main_item_abilities_prismatic_amplifier"] = "8,90",
    ["wh3_main_item_abilities_saint_annushkas_finger_bone"] = "8,60",
    ["wh3_main_item_abilities_scales_of_the_celestial_court"] = "8,120",
    ["wh3_main_item_abilities_scroll_of_destiny"] = "8,120",
    ["wh3_main_item_abilities_snowflake_pendant"] = "8,90",
    ["wh3_main_item_abilities_staff_of_wu_xing"] = "8,120",
    ["wh3_main_item_abilities_steppe_hunters_horn"] = "8,60",
    ["wh3_main_item_abilities_the_bloody_shackle"] = "8,-1",
    ["wh3_main_item_abilities_the_chromatic_tome"] = "8,60",
    ["wh3_main_item_abilities_the_portalglyph"] = "3,120",
    ["wh3_main_item_abilities_the_rock_of_inevitability"] = "0,90",
    ["wh3_main_item_abilities_void_pendulum"] = "10,90",
    ["wh3_main_item_abilities_zak_aloooog"] = "13,300",
    ["wh3_main_item_passive_rock_eye"] = "0,0",
    ["wh3_main_lord_abilities_ballet_of_blows"] = "8,90",
    ["wh3_main_lord_abilities_bellow_of_endless_fury"] = "2,60",
    ["wh3_main_lord_abilities_bellow_of_fury"] = "2,60",
    ["wh3_main_lord_abilities_blight_swarm"] = "2,60",
    ["wh3_main_lord_abilities_bloodthirst"] = "8,60",
    ["wh3_main_lord_abilities_burning_rage"] = "8,90",
    ["wh3_main_lord_abilities_daemonic_possession"] = "2,90",
    ["wh3_main_lord_abilities_deathbringer"] = "8,90",
    ["wh3_main_lord_abilities_deathbringer_upgraded"] = "8,90",
    ["wh3_main_lord_abilities_everyone_has_their_price"] = "0,120",
    ["wh3_main_lord_abilities_eye_of_the_storm"] = "8,120",
    ["wh3_main_lord_abilities_fury_of_ursun"] = "8,90",
    ["wh3_main_lord_abilities_gaze_of_fate"] = "2,90",
    ["wh3_main_lord_abilities_gorger_onslaught"] = "3,60",
    ["wh3_main_lord_abilities_hidden_in_time"] = "8,90",
    ["wh3_main_lord_abilities_inspired_assault_i"] = "4,60",
    ["wh3_main_lord_abilities_inspired_assault_ii"] = "4,90",
    ["wh3_main_lord_abilities_inspired_assault_iii"] = "4,120",
    ["wh3_main_lord_abilities_inspired_defence_i"] = "4,60",
    ["wh3_main_lord_abilities_inspired_defence_ii"] = "4,90",
    ["wh3_main_lord_abilities_inspired_defence_iii"] = "4,120",
    ["wh3_main_lord_abilities_inspired_marksmanship_i"] = "4,60",
    ["wh3_main_lord_abilities_inspired_marksmanship_ii"] = "4,90",
    ["wh3_main_lord_abilities_inspired_marksmanship_iii"] = "4,120",
    ["wh3_main_lord_abilities_iron_dragon_dragon_form"] = "8,120",
    ["wh3_main_lord_abilities_iron_dragon_human_form"] = "8,120",
    ["wh3_main_lord_abilities_master_of_alchemy"] = "13,90",
    ["wh3_main_lord_abilities_master_of_alchemy_flaming"] = "13,120",
    ["wh3_main_lord_abilities_master_of_alchemy_piercing"] = "13,120",
    ["wh3_main_lord_abilities_master_of_alchemy_poison"] = "13,120",
    ["wh3_main_lord_abilities_nurgling_tide"] = "8,90",
    ["wh3_main_lord_abilities_oracle_of_eternity"] = "8,90",
    ["wh3_main_lord_abilities_plaguefathers_oration"] = "8,90",
    ["wh3_main_lord_abilities_rage_embodied"] = "0,90",
    ["wh3_main_lord_abilities_rage_incarnate"] = "0,90",
    ["wh3_main_lord_abilities_seductive_glory"] = "0,90",
    ["wh3_main_lord_abilities_shadow_shroud"] = "8,120",
    ["wh3_main_lord_abilities_storm_dragon_dragon_form"] = "8,120",
    ["wh3_main_lord_abilities_storm_dragon_human_form"] = "8,120",
    ["wh3_main_lord_abilities_the_dark_master"] = "2,90",
    ["wh3_main_lord_abilities_virulent_contagion"] = "2,120",
    ["wh3_main_lord_abilities_virulent_contagion_upgraded"] = "2,120",
    ["wh3_main_lord_abilities_willing_prey"] = "2,90",
    ["wh3_main_lord_abilities_wrath_of_the_storm"] = "8,120",
    ["wh3_main_lord_abilities_wrathful_reaper"] = "8,60",
    ["wh3_main_mount_bound_celestial_comet"] = "3,49",
    ["wh3_main_mount_bound_celestial_lightning"] = "3,42",
    ["wh3_main_prisoners_butcher"] = "4,120",
    ["wh3_main_prisoners_dismember"] = "2,60",
    ["wh3_main_prisoners_massacre"] = "5,90",
    ["wh3_main_pro_character_abilities_heroic_killing_blow_1"] = "8,90",
    ["wh3_main_pro_character_abilities_heroic_killing_blow_2"] = "8,90",
    ["wh3_main_pro_character_abilities_ursuns_roar"] = "8,60",
    ["wh3_main_pro_character_abilities_ursuns_roar_1"] = "8,60",
    ["wh3_main_pro_character_abilities_ursuns_roar_2"] = "8,60",
    ["wh3_main_pro_character_abilities_ursuns_roar_3"] = "8,60",
    ["wh3_main_spell_bound_ancestral_warriors"] = "5,120",
    ["wh3_main_spell_bound_banishment"] = "3,120",
    ["wh3_main_spell_bound_cascading_fire_cloak"] = "12,60",
    ["wh3_main_spell_bound_comet_of_casandora"] = "3,120",
    ["wh3_main_spell_bound_earth_blood"] = "13,60",
    ["wh3_main_spell_bound_enfeebling_foe"] = "2,60",
    ["wh3_main_spell_bound_flame_storm"] = "3,120",
    ["wh3_main_spell_bound_flock_of_doom"] = "3,60",
    ["wh3_main_spell_bound_harmonic_convergence"] = "12,60",
    ["wh3_main_spell_bound_lash_of_slaanesh"] = "3,30",
    ["wh3_main_spell_bound_lash_of_slaanesh_keeper_of_secrets"] = "3,30",
    ["wh3_main_spell_bound_pestilent_breath"] = "3,60",
    ["wh3_main_spell_bound_phas_protection"] = "12,60",
    ["wh3_main_spell_bound_pit_of_shades"] = "3,120",
    ["wh3_main_spell_bound_plague_of_rust"] = "2,60",
    ["wh3_main_spell_bound_rancid_visitations"] = "2,90",
    ["wh3_main_spell_bound_spirit_leech"] = "2,60",
    ["wh3_main_spell_bound_the_curse_of_anraheir"] = "3,120",
    ["wh3_main_spell_bound_the_dwellers_below"] = "3,120",
    ["wh3_main_spell_bound_the_fate_of_bjuna"] = "2,120",
    ["wh3_main_spell_bound_transmutation_of_lead"] = "3,120",
    ["wh3_main_spell_bound_wall_of_wind_and_fire"] = "3,90",
    ["wh3_main_spell_great_maw_bonecrusher"] = "19,43",
    ["wh3_main_spell_great_maw_bonecrusher_upgraded"] = "19,43",
    ["wh3_main_spell_great_maw_braingobbler"] = "18,28",
    ["wh3_main_spell_great_maw_braingobbler_upgraded"] = "18,28",
    ["wh3_main_spell_great_maw_bullgorger"] = "28,29",
    ["wh3_main_spell_great_maw_bullgorger_upgraded"] = "28,29",
    ["wh3_main_spell_great_maw_the_maw"] = "19,54",
    ["wh3_main_spell_great_maw_the_maw_upgraded"] = "19,54",
    ["wh3_main_spell_great_maw_toothcracker"] = "29,44",
    ["wh3_main_spell_great_maw_toothcracker_upgraded"] = "29,44",
    ["wh3_main_spell_great_maw_trollguts"] = "28,52",
    ["wh3_main_spell_great_maw_trollguts_upgraded"] = "28,52",
    ["wh3_main_spell_ice_crystal_sanctuary"] = "28,50",
    ["wh3_main_spell_ice_crystal_sanctuary_upgraded"] = "29,50",
    ["wh3_main_spell_ice_death_frost"] = "18,38",
    ["wh3_main_spell_ice_death_frost_upgraded"] = "18,38",
    ["wh3_main_spell_ice_frost_blades"] = "28,43",
    ["wh3_main_spell_ice_frost_blades_upgraded"] = "28,43",
    ["wh3_main_spell_ice_heart_of_winter"] = "17,54",
    ["wh3_main_spell_ice_heart_of_winter_upgraded"] = "17,54",
    ["wh3_main_spell_ice_ice_maidens_kiss"] = "19,30",
    ["wh3_main_spell_ice_ice_maidens_kiss_upgraded"] = "19,30",
    ["wh3_main_spell_ice_ice_sheet"] = "17,27",
    ["wh3_main_spell_nurgle_curse_of_the_leper"] = "28,43",
    ["wh3_main_spell_nurgle_curse_of_the_leper_bound"] = "12,-1",
    ["wh3_main_spell_nurgle_curse_of_the_leper_upgraded"] = "28,43",
    ["wh3_main_spell_nurgle_fleshy_abundance"] = "28,54",
    ["wh3_main_spell_nurgle_fleshy_abundance_bound"] = "12,-1",
    ["wh3_main_spell_nurgle_fleshy_abundance_upgraded"] = "29,54",
    ["wh3_main_spell_nurgle_miasma_of_pestilence"] = "18,28",
    ["wh3_main_spell_nurgle_miasma_of_pestilence_bound"] = "2,-1",
    ["wh3_main_spell_nurgle_miasma_of_pestilence_upgraded"] = "19,28",
    ["wh3_main_spell_nurgle_pestilent_pustule"] = "19,49",
    ["wh3_main_spell_nurgle_pestilent_pustule_bound"] = "3,-1",
    ["wh3_main_spell_nurgle_pestilent_pustule_upgraded"] = "19,49",
    ["wh3_main_spell_nurgle_rancid_visitations"] = "18,43",
    ["wh3_main_spell_nurgle_rancid_visitations_bound"] = "2,-1",
    ["wh3_main_spell_nurgle_rancid_visitations_upgraded"] = "18,43",
    ["wh3_main_spell_nurgle_stream_of_corruption"] = "19,29",
    ["wh3_main_spell_nurgle_stream_of_corruption_bound"] = "3,29",
    ["wh3_main_spell_nurgle_stream_of_corruption_upgraded"] = "19,29",
    ["wh3_main_spell_slaanesh_acquiescence"] = "18,29",
    ["wh3_main_spell_slaanesh_acquiescence_bound"] = "2,-1",
    ["wh3_main_spell_slaanesh_acquiescence_upgraded"] = "18,29",
    ["wh3_main_spell_slaanesh_hysterical_frenzy"] = "28,43",
    ["wh3_main_spell_slaanesh_hysterical_frenzy_bound"] = "12,43",
    ["wh3_main_spell_slaanesh_hysterical_frenzy_upgraded"] = "28,43",
    ["wh3_main_spell_slaanesh_lash_of_slaanesh"] = "19,30",
    ["wh3_main_spell_slaanesh_lash_of_slaanesh_upgraded"] = "19,30",
    ["wh3_main_spell_slaanesh_pavane_of_slaanesh"] = "18,38",
    ["wh3_main_spell_slaanesh_pavane_of_slaanesh_bound"] = "2,-1",
    ["wh3_main_spell_slaanesh_pavane_of_slaanesh_upgraded"] = "18,38",
    ["wh3_main_spell_slaanesh_phantasmagoria"] = "19,54",
    ["wh3_main_spell_slaanesh_phantasmagoria_bound"] = "3,-1",
    ["wh3_main_spell_slaanesh_phantasmagoria_upgraded"] = "19,54",
    ["wh3_main_spell_slaanesh_slicing_shards"] = "19,48",
    ["wh3_main_spell_slaanesh_slicing_shards_bound"] = "3,-1",
    ["wh3_main_spell_slaanesh_slicing_shards_upgraded"] = "19,48",
    ["wh3_main_spell_tempest_biting_wind"] = "19,39",
    ["wh3_main_spell_tempest_biting_wind_army"] = "3,0",
    ["wh3_main_spell_tempest_biting_wind_upgraded"] = "19,39",
    ["wh3_main_spell_tempest_blizzard"] = "19,54",
    ["wh3_main_spell_tempest_blizzard_upgraded"] = "19,54",
    ["wh3_main_spell_tempest_gust_of_true_flight"] = "29,28",
    ["wh3_main_spell_tempest_gust_of_true_flight_upgraded"] = "29,28",
    ["wh3_main_spell_tempest_hailstorm"] = "19,30",
    ["wh3_main_spell_tempest_hailstorm_upgraded"] = "19,30",
    ["wh3_main_spell_tempest_hawks_of_miska"] = "19,49",
    ["wh3_main_spell_tempest_hawks_of_miska_upgraded"] = "19,49",
    ["wh3_main_spell_tempest_swiftwing"] = "29,44",
    ["wh3_main_spell_tempest_swiftwing_upgraded"] = "29,44",
    ["wh3_main_spell_tzeentch_blue_fire_of_tzeentch"] = "18,28",
    ["wh3_main_spell_tzeentch_blue_fire_of_tzeentch_bound"] = "2,-1",
    ["wh3_main_spell_tzeentch_blue_fire_of_tzeentch_upgraded"] = "18,28",
    ["wh3_main_spell_tzeentch_glean_magic"] = "26,44",
    ["wh3_main_spell_tzeentch_glean_magic_bound"] = "10,-1",
    ["wh3_main_spell_tzeentch_glean_magic_upgraded"] = "26,44",
    ["wh3_main_spell_tzeentch_infernal_gateway"] = "19,54",
    ["wh3_main_spell_tzeentch_infernal_gateway_bound"] = "3,-1",
    ["wh3_main_spell_tzeentch_infernal_gateway_upgraded"] = "19,54",
    ["wh3_main_spell_tzeentch_pink_fire_of_tzeentch"] = "19,30",
    ["wh3_main_spell_tzeentch_pink_fire_of_tzeentch_bound"] = "3,30",
    ["wh3_main_spell_tzeentch_pink_fire_of_tzeentch_upgraded"] = "19,30",
    ["wh3_main_spell_tzeentch_treason_of_tzeentch"] = "17,45",
    ["wh3_main_spell_tzeentch_treason_of_tzeentch_bound"] = "1,-1",
    ["wh3_main_spell_tzeentch_treason_of_tzeentch_upgraded"] = "17,45",
    ["wh3_main_spell_tzeentch_tzeentchs_firestorm"] = "19,51",
    ["wh3_main_spell_tzeentch_tzeentchs_firestorm_bound"] = "3,-1",
    ["wh3_main_spell_tzeentch_tzeentchs_firestorm_upgraded"] = "19,51",
    ["wh3_main_spell_yang_constellation_of_the_dragon"] = "19,54",
    ["wh3_main_spell_yang_constellation_of_the_dragon_upgraded"] = "19,54",
    ["wh3_main_spell_yang_dragons_breath"] = "19,30",
    ["wh3_main_spell_yang_dragons_breath_upgraded"] = "19,30",
    ["wh3_main_spell_yang_jade_shield"] = "28,28",
    ["wh3_main_spell_yang_jade_shield_upgraded"] = "28,28",
    ["wh3_main_spell_yang_might_of_heaven_and_earth"] = "28,47",
    ["wh3_main_spell_yang_might_of_heaven_and_earth_upgraded"] = "28,47",
    ["wh3_main_spell_yang_stone_ground_stance"] = "29,44",
    ["wh3_main_spell_yang_stone_ground_stance_upgraded"] = "29,44",
    ["wh3_main_spell_yang_wall_of_wind_and_fire"] = "19,43",
    ["wh3_main_spell_yang_wall_of_wind_and_fire_upgraded"] = "19,43",
    ["wh3_main_spell_yin_ancestral_warriors"] = "29,52",
    ["wh3_main_spell_yin_ancestral_warriors_upgraded"] = "29,52",
    ["wh3_main_spell_yin_blossom_wind"] = "19,45",
    ["wh3_main_spell_yin_blossom_wind_upgraded"] = "19,45",
    ["wh3_main_spell_yin_cloak_of_jet"] = "28,28",
    ["wh3_main_spell_yin_cloak_of_jet_upgraded"] = "28,28",
    ["wh3_main_spell_yin_missile_mirror"] = "18,44",
    ["wh3_main_spell_yin_missile_mirror_upgraded"] = "18,44",
    ["wh3_main_spell_yin_storm_of_shadows"] = "18,28",
    ["wh3_main_spell_yin_storm_of_shadows_upgraded"] = "19,28",
    ["wh3_main_spell_yin_talons_of_night"] = "19,50",
    ["wh3_main_spell_yin_talons_of_night_upgraded"] = "19,50",
    ["wh3_main_unit_abilities_elemental_breath"] = "2,60",
    ["wh3_main_unit_abilities_necrotic_explosion"] = "8,0",
    ["wh3_main_unit_abilities_sky_junk_bomb"] = "0,30",
    ["wh3_main_unit_abilities_stun_bomb"] = "1,90",
    ["wh3_main_weapon_abilities_axe_of_tor"] = "3,90",
    ["wh3_main_weapon_abilities_banespear"] = "0,120",
    ["wh3_main_weapon_abilities_frost_fang"] = "3,120",
    ["wh3_main_weapon_abilities_frost_shard_glaive"] = "2,120",
    ["wh3_main_weapon_abilities_godkiller_pistol"] = "2,120",
    ["wh3_main_weapon_abilities_nuku_chos_crossbow"] = "2,90",
    ["wh3_main_weapon_abilities_sceptre_of_titans"] = "8,120",
    ["wh3_main_weapon_abilities_shard_blade"] = "0,120",
    ["wh3_main_weapon_abilities_siegebreaker"] = "3,120",
    ["wh3_main_weapon_abilities_skars_kraken_killer"] = "8,120",
    ["wh3_main_weapon_abilities_soulnetter"] = "2,120",
    ["wh3_main_weapon_abilities_staff_of_tomorrow"] = "8,120",
    ["wh3_main_weapon_abilities_the_eternal_blade"] = "8,120",
    ["wh3_main_weapon_abilities_the_tenderiser"] = "8,90",
    ["wh3_main_weapon_abilities_the_traitors_sword"] = "2,90",
    ["wh3_main_weapon_abilities_thundermace"] = "8,90",
    ["wh3_main_weapon_abilities_torment_blade"] = "2,60",
    ["wh3_main_weapon_abilities_ursuns_claws"] = "8,60",
    ["wh3_main_weapon_abilities_witstealer_sword"] = "8,120",
    ["wh3_pro10_army_abilities_diabolical_puppetry"] = "11,90",
    ["wh3_pro10_army_abilities_diabolical_puppetry_upgrade_1"] = "3,75",
    ["wh3_pro10_army_abilities_diabolical_puppetry_upgrade_2"] = "3,60",
    ["wh3_pro10_army_abilities_diabolical_puppetry_upgrade_3"] = "3,45",
    ["wh3_pro10_army_abilities_inevitable_fate"] = "12,150",
    ["wh3_pro10_army_abilities_inevitable_fate_upgrade_1"] = "12,120",
    ["wh3_pro10_army_abilities_inevitable_fate_upgrade_2"] = "12,105",
    ["wh3_pro10_army_abilities_inevitable_fate_upgrade_3"] = "12,90",
    ["wh3_pro10_army_abilities_tempest_of_blue_flame"] = "9,90",
    ["wh3_pro10_army_abilities_tempest_of_blue_flame_upgrade_1"] = "9,75",
    ["wh3_pro10_army_abilities_tempest_of_blue_flame_upgrade_2"] = "9,60",
    ["wh3_pro10_army_abilities_tempest_of_blue_flame_upgrade_3"] = "9,45",
    ["wh3_pro10_cataclysm_fire_magma_storm_bound"] = "1,120",
    ["wh3_pro10_cataclysm_metal_gehennas_golden_globe_bound"] = "1,120",
    ["wh3_pro11_weapon_abilities_the_hammer_of_harry"] = "8,120",
    ["wh3_pro12_hero_abilities_karanaks_howl"] = "13,120",
    ["wh3_pro12_hero_abilities_prey_of_the_blood_god"] = "2,120",
    ["wh3_supplies_replenishment_ability_recharge_01"] = "8,-1",
    ["wh3_supplies_replenishment_ammunition_01"] = "8,-1",
    ["wh3_supplies_replenishment_encourage_01"] = "8,-1",
    ["wh3_supplies_replenishment_fatigue_01"] = "8,-1",
    ["wh3_supplies_replenishment_full_restore_01"] = "8,-1",
    ["wh3_supplies_replenishment_regen_01"] = "8,-1",
    ["wh3_supplies_replenishment_regen_magical_01"] = "8,-1",
    ["wh3_supplies_replenishment_winds_of_magic_01"] = "8,-1",
    ["wh3_supplies_upgrade_armour_01"] = "8,-1",
    ["wh3_supplies_upgrade_armour_02"] = "8,-1",
    ["wh3_supplies_upgrade_armour_03"] = "8,-1",
    ["wh3_supplies_upgrade_missiles_01"] = "8,-1",
    ["wh3_supplies_upgrade_missiles_02"] = "8,-1",
    ["wh3_supplies_upgrade_missiles_03"] = "8,-1",
    ["wh3_supplies_upgrade_shields_01"] = "8,-1",
    ["wh3_supplies_upgrade_shields_02"] = "8,-1",
    ["wh3_supplies_upgrade_shields_03"] = "8,-1",
    ["wh3_supplies_upgrade_weapons_01"] = "8,-1",
    ["wh3_supplies_upgrade_weapons_02"] = "8,-1",
    ["wh3_supplies_upgrade_weapons_03"] = "8,-1",
    ["wh3_supplies_upgrade_weapons_imbue_01"] = "8,-1",
    ["wh3_supplies_upgrade_weapons_imbue_02"] = "8,-1",
    ["wh3_twa06_unit_abilities_dazs_song_of_winter_sunlight"] = "8,90",
    ["wh3_twa06_unit_active_conduit_of_infinity"] = "8,-1",
    ["wh3_twa07_spell_bound_call_of_tor"] = "0,90",
    ["wh3_twa07_unit_abilities_searing_torrent"] = "0,60",
    ["wh3_twa08_spell_bound_enfeebling_foe_keeper_of_secrets_ror"] = "2,60",
    ["wh3_twa08_spell_bound_heart_of_winter_elemental_bear_ror"] = "0,120",
    ["wh3_twa08_spell_bound_searing_doom"] = "3,60",
    ["wh3_twa08_spell_bound_spirit_leech_great_unclean_one_ror"] = "2,60",
    ["wh3_twa08_spell_bound_the_withering"] = "2,90",
    ["wh3_twa08_unit_abilities_defiling_deluge"] = "8,120",
    ["wh3_twa08_unit_abilities_glacial_defence"] = "8,60",
    ["wh_dlc01_item_passive_helm_of_many_eyes"] = "8,90",
    ["wh_dlc01_weapon_abilities_starcrusher"] = "8,120",
    ["wh_dlc01_weapon_abilities_sword_of_change"] = "5,90",
    ["wh_dlc01_weapon_abilities_the_slayer_of_kings"] = "8,120",
    ["wh_dlc03_character_abilities_apocalyptic_vision"] = "8,90",
    ["wh_dlc03_character_abilities_blood_lust"] = "12,60",
    ["wh_dlc03_character_abilities_call_of_violence"] = "8,60",
    ["wh_dlc03_character_abilities_deadly_onslaught"] = "8,90",
    ["wh_dlc03_character_abilities_foe_seeker"] = "8,60",
    ["wh_dlc03_item_abilities_chalice_of_dark_rain"] = "3,90",
    ["wh_dlc03_item_abilities_hagtree_fetish"] = "8,60",
    ["wh_dlc03_item_abilities_horn_of_the_first_beast"] = "8,120",
    ["wh_dlc03_item_abilities_jagged_dagger"] = "8,60",
    ["wh_dlc03_item_abilities_skull_of_rarkos"] = "8,120",
    ["wh_dlc03_spell_beasts_flock_of_doom"] = "19,45",
    ["wh_dlc03_spell_beasts_flock_of_doom_upgraded"] = "19,45",
    ["wh_dlc03_spell_beasts_panns_impenetrable_pelt"] = "28,43",
    ["wh_dlc03_spell_beasts_panns_impenetrable_pelt_summoned"] = "28,43",
    ["wh_dlc03_spell_beasts_panns_impenetrable_pelt_upgraded"] = "29,43",
    ["wh_dlc03_spell_beasts_the_amber_spear"] = "18,43",
    ["wh_dlc03_spell_beasts_the_amber_spear_upgraded"] = "18,43",
    ["wh_dlc03_spell_beasts_the_curse_of_anraheir"] = "19,47",
    ["wh_dlc03_spell_beasts_the_curse_of_anraheir_upgraded"] = "19,47",
    ["wh_dlc03_spell_beasts_transformation_of_kadon"] = "29,45",
    ["wh_dlc03_spell_beasts_wyssans_wildform"] = "28,28",
    ["wh_dlc03_spell_beasts_wyssans_wildform_upgraded"] = "29,28",
    ["wh_dlc03_spell_bound_the_amber_spear"] = "2,90",
    ["wh_dlc03_spell_bound_viletide"] = "3,60",
    ["wh_dlc03_spell_wild_bray_scream"] = "19,29",
    ["wh_dlc03_spell_wild_bray_scream_upgraded"] = "19,29",
    ["wh_dlc03_spell_wild_devolve"] = "18,30",
    ["wh_dlc03_spell_wild_devolve_upgraded"] = "19,30",
    ["wh_dlc03_spell_wild_mantle_of_ghorok"] = "28,47",
    ["wh_dlc03_spell_wild_savage_dominion"] = "29,48",
    ["wh_dlc03_spell_wild_traitor_kin"] = "19,39",
    ["wh_dlc03_spell_wild_traitor_kin_upgraded"] = "19,39",
    ["wh_dlc03_spell_wild_viletide"] = "19,31",
    ["wh_dlc03_spell_wild_viletide_upgraded"] = "19,31",
    ["wh_dlc03_weapon_abilities_axe_of_men"] = "8,120",
    ["wh_dlc03_weapon_abilities_hunting_spear"] = "2,120",
    ["wh_dlc03_weapon_abilities_scourge"] = "8,120",
    ["wh_dlc04_item_abilities_the_carstein_ring"] = "8,120",
    ["wh_dlc04_item_abilities_the_liber_noctus"] = "8,120",
    ["wh_dlc04_lord_abilities_beguile"] = "2,90",
    ["wh_dlc04_quest_abilities_servant_of_nagash"] = "12,8",
    ["wh_dlc04_spell_bound_banishment"] = "3,120",
    ["wh_dlc04_spell_bound_banishment_innate"] = "3,120",
    ["wh_dlc04_spell_bound_hammer_of_sigmar_upgraded"] = "8,90",
    ["wh_dlc04_spell_bound_net_of_amyntok"] = "2,90",
    ["wh_dlc04_spell_bound_shield_of_faith_upgraded"] = "8,120",
    ["wh_dlc04_spell_bound_soulfire_upgraded"] = "0,120",
    ["wh_dlc04_spell_death_doom_and_darkness_strigoi"] = "18,43",
    ["wh_dlc04_spell_death_soulblight_strigoi"] = "19,45",
    ["wh_dlc04_spell_death_spirit_leech_strigoi"] = "18,32",
    ["wh_dlc04_spell_vampires_curse_of_years_helman"] = "19,47",
    ["wh_dlc04_spell_vampires_gaze_of_nagash_helman"] = "18,44",
    ["wh_dlc04_spell_vampires_gaze_of_nagash_strigoi"] = "18,44",
    ["wh_dlc04_spell_vampires_invocation_of_nehek_helman"] = "28,30",
    ["wh_dlc04_spell_vampires_invocation_of_nehek_strigoi"] = "28,30",
    ["wh_dlc04_spell_vampires_raise_dead_helman"] = "29,48",
    ["wh_dlc04_spell_vampires_raise_dead_strigoi"] = "29,57",
    ["wh_dlc04_spell_vampires_raise_dead_upgraded_helman"] = "29,48",
    ["wh_dlc04_spell_vampires_raise_dead_upgraded_strigoi"] = "29,57",
    ["wh_dlc04_spell_vampires_vanhels_danse_macabre_helman"] = "28,28",
    ["wh_dlc04_spell_vampires_wind_of_death_helman"] = "19,44",
    ["wh_dlc05_character_abilities_prey_of_anath_raema"] = "2,90",
    ["wh_dlc05_hero_abilities_arrow_of_kurnous"] = "2,90",
    ["wh_dlc05_item_abilities_hail_of_doom_arrow"] = "2,90",
    ["wh_dlc05_item_abilities_horn_of_the_wild_hunt"] = "8,120",
    ["wh_dlc05_lord_abilities_lamentation_of_despair"] = "2,90",
    ["wh_dlc05_lord_abilities_spirit_essence_of_eternal_chaos"] = "2,20",
    ["wh_dlc05_lord_ablities_grey_wolves"] = "3,90",
    ["wh_dlc05_spell_bound_shield_of_thorns"] = "12,90",
    ["wh_dlc05_spell_bound_the_curse_of_anraheir"] = "3,120",
    ["wh_dlc05_spell_life_awakening_of_the_wood"] = "19,31",
    ["wh_dlc05_spell_life_awakening_the_wood_branchwraith"] = "19,31",
    ["wh_dlc05_spell_life_earth_blood"] = "29,30",
    ["wh_dlc05_spell_life_earth_blood_branchwraith"] = "29,30",
    ["wh_dlc05_spell_life_earth_blood_upgraded"] = "29,30",
    ["wh_dlc05_spell_life_flesh_to_stone"] = "28,43",
    ["wh_dlc05_spell_life_flesh_to_stone_upgraded"] = "28,43",
    ["wh_dlc05_spell_life_regrowth"] = "28,48",
    ["wh_dlc05_spell_life_regrowth_upgraded"] = "28,48",
    ["wh_dlc05_spell_life_shield_of_thorns"] = "28,44",
    ["wh_dlc05_spell_life_shield_of_thorns_branchwraith"] = "28,44",
    ["wh_dlc05_spell_life_shield_of_thorns_upgraded"] = "28,44",
    ["wh_dlc05_spell_life_the_dwellers_below"] = "19,45",
    ["wh_dlc05_spell_life_the_dwellers_below_upgraded"] = "19,45",
    ["wh_dlc05_spell_shadow_melkoths_mystifying_miasma"] = "18,29",
    ["wh_dlc05_spell_shadow_melkoths_mystifying_miasma_branchwraith"] = "18,29",
    ["wh_dlc05_spell_shadow_melkoths_mystifying_miasma_upgraded"] = "18,29",
    ["wh_dlc05_spell_shadow_okkams_mindrazor"] = "28,46",
    ["wh_dlc05_spell_shadow_okkams_mindrazor_upgraded"] = "29,46",
    ["wh_dlc05_spell_shadow_pit_of_shades"] = "19,49",
    ["wh_dlc05_spell_shadow_pit_of_shades_bound"] = "3,49",
    ["wh_dlc05_spell_shadow_pit_of_shades_upgraded"] = "19,49",
    ["wh_dlc05_spell_shadow_the_enfeebling_foe"] = "18,30",
    ["wh_dlc05_spell_shadow_the_enfeebling_foe_upgraded"] = "18,30",
    ["wh_dlc05_spell_shadow_the_penumbral_pendulum"] = "19,40",
    ["wh_dlc05_spell_shadow_the_penumbral_pendulum_branchwraith"] = "19,40",
    ["wh_dlc05_spell_shadow_the_penumbral_pendulum_upgraded"] = "19,40",
    ["wh_dlc05_spell_shadow_the_withering"] = "18,43",
    ["wh_dlc05_spell_shadow_the_withering_branchwraith"] = "18,43",
    ["wh_dlc05_spell_shadow_the_withering_upgraded"] = "19,43",
    ["wh_dlc05_unit_abilities_storm_of_blades"] = "8,1",
    ["wh_dlc05_unit_abilities_the_shadows_coil"] = "8,1",
    ["wh_dlc05_unit_abilities_woven_mist"] = "8,1",
    ["wh_dlc05_weapon_abilities_daiths_sword"] = "3,120",
    ["wh_dlc05_weapon_abilities_el_syf"] = "2,90",
    ["wh_dlc05_weapon_abilities_hawks_talon"] = "3,90",
    ["wh_dlc05_weapon_abilities_spear_of_kurnous"] = "2,120",
    ["wh_dlc05_weapon_abilities_stave_of_ruinous_corruption"] = "3,120",
    ["wh_dlc05_weapon_abilities_the_bow_of_loren"] = "3,60",
    ["wh_dlc06_character_abilities_effagee_of_da_git"] = "2,120",
    ["wh_dlc06_lord_abilities_mighty_oath_stone"] = "8,90",
    ["wh_dlc06_lord_abilities_revenge_incarnate"] = "8,120",
    ["wh_dlc06_lord_abilities_spite_of_da_bad_moon"] = "13,90",
    ["wh_dlc06_lord_abilities_tricksy_traps"] = "8,120",
    ["wh_dlc06_quest_abilities_grand_faiths_bastion"] = "8,0",
    ["wh_dlc06_rune_abilities_master_rune_of_negation"] = "12,180",
    ["wh_dlc06_rune_abilities_master_rune_of_oath_and_steel"] = "13,180",
    ["wh_dlc06_rune_abilities_master_rune_of_wrath_and_ruin"] = "3,180",
    ["wh_dlc06_spell_bound_vindictive_glare"] = "2,60",
    ["wh_dlc06_unit_abilities_marked_by_ulthar"] = "2,120",
    ["wh_dlc06_unit_abilities_maternal_instinct"] = "3,60",
    ["wh_dlc06_unit_abilities_skyhammer_bomb"] = "0,0",
    ["wh_dlc06_unit_abilities_skyhammer_fire_bomb"] = "0,0",
    ["wh_dlc06_unit_abilities_smoke_bomb"] = "0,90",
    ["wh_dlc06_unit_abilities_the_loons_of_eight_peaks"] = "3,30",
    ["wh_dlc06_weapon_abilities_skarsniks_prodder"] = "2,120",
    ["wh_dlc07_character_abilities_heroic_killing_blow"] = "8,90",
    ["wh_dlc07_hero_abilities_dolorous_blade"] = "8,120",
    ["wh_dlc07_item_abilities_chalice_of_potions"] = "3,120",
    ["wh_dlc07_item_abilities_wrath_of_manann"] = "3,120",
    ["wh_dlc07_lord_abilities_favour_of_the_fay"] = "4,90",
    ["wh_dlc07_lord_abilities_lions_shield"] = "8,90",
    ["wh_dlc07_unit_formation_lance"] = "8,-1",
    ["wh_dlc08_character_abilities_hunter_of_champions"] = "2,90",
    ["wh_dlc08_item_abilities_ancient_frost_wyrm_scale"] = "3,120",
    ["wh_dlc08_item_abilities_arachnarok_eggs"] = "3,60",
    ["wh_dlc08_item_abilities_great_horn_of_dragon_ogre"] = "11,120",
    ["wh_dlc08_item_abilities_terrorgheist_skull"] = "12,120",
    ["wh_dlc08_item_abilities_the_wintertooth_crown"] = "8,120",
    ["wh_dlc08_item_abilities_vial_of_troll_blood"] = "8,90",
    ["wh_dlc08_lord_abilities_copious_vomit"] = "2,60",
    ["wh_dlc08_lord_abilities_fight_or_die"] = "8,90",
    ["wh_dlc08_lord_abilities_seafang"] = "3,90",
    ["wh_dlc08_lord_abilities_seduction_of_the_serpent"] = "8,90",
    ["wh_dlc08_quest_abilities_howling_winter"] = "3,3",
    ["wh_dlc08_quest_abilities_master_of_souls"] = "28,5",
    ["wh_dlc08_spell_bound_death_doom_and_darkness"] = "2,90",
    ["wh_dlc08_spell_bound_flock_of_doom"] = "3,60",
    ["wh_dlc08_spell_bound_the_dwellers_below"] = "3,120",
    ["wh_dlc08_spell_death_aspect_of_the_dreadknight_arzik"] = "28,29",
    ["wh_dlc08_spell_death_soulblight_arzik"] = "19,45",
    ["wh_dlc08_spell_death_the_fate_of_bjuna_arzik"] = "18,52",
    ["wh_dlc08_spell_fire_fireball_kihar"] = "18,29",
    ["wh_dlc08_spell_fire_flaming_sword_of_rhuin_kihar"] = "29,44",
    ["wh_dlc08_spell_metal_final_transmutation_arzik"] = "19,54",
    ["wh_dlc08_spell_metal_gehennas_golden_hounds_arzik"] = "19,45",
    ["wh_dlc08_spell_metal_plague_of_rust_kihar"] = "18,28",
    ["wh_dlc08_spell_metal_searing_doom_arzik"] = "19,30",
    ["wh_dlc08_spell_metal_transmutation_of_lead_kihar"] = "19,47",
    ["wh_dlc08_spell_shadow_pit_of_shades_kihar"] = "19,49",
    ["wh_dlc08_spell_shadow_the_penumbral_pendulum_kihar"] = "19,40",
    ["wh_dlc08_weapon_abilities_stinky_giant_club"] = "8,120",
    ["wh_dlc08_weapon_abilities_sword_of_torgald"] = "8,120",
    ["wh_main_character_abilities_blood_lust"] = "12,60",
    ["wh_main_character_abilities_deadly_onslaught"] = "8,90",
    ["wh_main_character_abilities_foe_seeker"] = "8,60",
    ["wh_main_character_abilities_foe_seeker_summoned"] = "8,60",
    ["wh_main_character_abilities_get_back_ere"] = "8,60",
    ["wh_main_character_abilities_heroic_killing_blow"] = "8,90",
    ["wh_main_character_abilities_magical_animus"] = "8,60",
    ["wh_main_character_abilities_rally"] = "8,60",
    ["wh_main_character_abilities_red_fury"] = "12,90",
    ["wh_main_character_abilities_stand_or_die"] = "8,90",
    ["wh_main_character_abilities_stand_your_ground"] = "8,90",
    ["wh_main_character_abilities_undeath_resurgent"] = "8,90",
    ["wh_main_character_abilities_waaagh"] = "8,90",
    ["wh_main_hero_abilities_accusation"] = "2,90",
    ["wh_main_hero_abilities_ballistics_calibration"] = "9,90",
    ["wh_main_hero_abilities_faiths_bastion"] = "8,60",
    ["wh_main_hero_abilities_immortal_will"] = "8,60",
    ["wh_main_hero_abilities_mad_cap_mushrooms"] = "8,90",
    ["wh_main_hero_abilities_slippery"] = "8,60",
    ["wh_main_item_abilities_black_periapt"] = "8,120",
    ["wh_main_item_abilities_channelling_staff"] = "8,60",
    ["wh_main_item_abilities_cloak_of_mists_and_shadows"] = "8,120",
    ["wh_main_item_abilities_crown_of_command"] = "12,90",
    ["wh_main_item_abilities_daemonic_strength"] = "8,60",
    ["wh_main_item_abilities_dark_fortune"] = "8,60",
    ["wh_main_item_abilities_earthing_rod"] = "8,60",
    ["wh_main_item_abilities_fiery_ring_of_thori"] = "3,90",
    ["wh_main_item_abilities_forbidden_rod"] = "8,90",
    ["wh_main_item_abilities_opal_amulet"] = "8,60",
    ["wh_main_item_abilities_pendant_of_slaanesh"] = "8,60",
    ["wh_main_item_abilities_potion_of_foolhardiness"] = "8,60",
    ["wh_main_item_abilities_potion_of_healing"] = "8,60",
    ["wh_main_item_abilities_potion_of_speed"] = "8,60",
    ["wh_main_item_abilities_potion_of_strength"] = "8,60",
    ["wh_main_item_abilities_potion_of_toughness"] = "8,60",
    ["wh_main_item_abilities_power_stone"] = "8,60",
    ["wh_main_item_abilities_regenerating_flesh"] = "8,60",
    ["wh_main_item_abilities_sceptre_of_stability"] = "12,60",
    ["wh_main_item_abilities_scroll_of_leeching"] = "2,60",
    ["wh_main_item_abilities_scroll_of_power"] = "8,0",
    ["wh_main_item_abilities_scroll_of_shielding"] = "12,60",
    ["wh_main_item_abilities_silver_horn_of_vengeance"] = "8,60",
    ["wh_main_item_abilities_skull_of_katam"] = "8,60",
    ["wh_main_item_abilities_skull_wand_of_kaloth"] = "8,120",
    ["wh_main_item_abilities_staff_of_volans"] = "8,120",
    ["wh_main_item_abilities_tricksters_shard"] = "3,90",
    ["wh_main_item_abilities_van_horstmanns_speculum"] = "0,90",
    ["wh_main_item_abilities_wand_of_jet"] = "8,60",
    ["wh_main_lord_abilities_lord_of_the_storm"] = "3,90",
    ["wh_main_lord_abilities_master_of_the_black_arts"] = "8,90",
    ["wh_main_rune_abilities_rune_of_negation"] = "12,120",
    ["wh_main_rune_abilities_rune_of_oath_and_steel"] = "13,120",
    ["wh_main_rune_abilities_rune_of_wrath_and_ruin"] = "3,120",
    ["wh_main_spell_big_waaagh_brain_bursta"] = "19,31",
    ["wh_main_spell_big_waaagh_brain_bursta_upgraded"] = "19,31",
    ["wh_main_spell_big_waaagh_eadbutt"] = "19,45",
    ["wh_main_spell_big_waaagh_eadbutt_upgraded"] = "19,45",
    ["wh_main_spell_big_waaagh_ere_we_go"] = "28,47",
    ["wh_main_spell_big_waaagh_fists_of_gork"] = "28,43",
    ["wh_main_spell_big_waaagh_foot_of_gork"] = "19,54",
    ["wh_main_spell_big_waaagh_foot_of_gork_upgraded"] = "19,54",
    ["wh_main_spell_big_waaagh_gaze_of_mork"] = "18,29",
    ["wh_main_spell_big_waaagh_gaze_of_mork_upgraded"] = "18,29",
    ["wh_main_spell_bound_bironas_timewarp"] = "13,47",
    ["wh_main_spell_bound_book_of_arkhan"] = "12,60",
    ["wh_main_spell_bound_chain_lightning_ror"] = "3,60",
    ["wh_main_spell_bound_fireball"] = "2,60",
    ["wh_main_spell_bound_hammer_of_sigmar"] = "8,60",
    ["wh_main_spell_bound_piercing_bolts_of_burning"] = "3,120",
    ["wh_main_spell_bound_shield_of_faith"] = "8,90",
    ["wh_main_spell_bound_soulfire"] = "0,90",
    ["wh_main_spell_bound_staff_of_damnation"] = "12,90",
    ["wh_main_spell_death_aspect_of_the_dreadknight"] = "28,29",
    ["wh_main_spell_death_aspect_of_the_dreadknight_upgraded"] = "29,29",
    ["wh_main_spell_death_doom_and_darkness"] = "18,43",
    ["wh_main_spell_death_doom_and_darkness_upgraded"] = "19,43",
    ["wh_main_spell_death_soulblight"] = "19,45",
    ["wh_main_spell_death_soulblight_upgraded"] = "19,45",
    ["wh_main_spell_death_spirit_leech"] = "18,32",
    ["wh_main_spell_death_spirit_leech_upgraded"] = "18,32",
    ["wh_main_spell_death_the_fate_of_bjuna"] = "18,52",
    ["wh_main_spell_death_the_purple_sun_of_xereus"] = "19,54",
    ["wh_main_spell_death_the_purple_sun_of_xereus_upgraded"] = "19,54",
    ["wh_main_spell_fire_cascading_fire_cloak"] = "28,28",
    ["wh_main_spell_fire_fireball"] = "18,29",
    ["wh_main_spell_fire_fireball_upgraded"] = "18,29",
    ["wh_main_spell_fire_flame_storm"] = "19,50",
    ["wh_main_spell_fire_flame_storm_upgraded"] = "19,50",
    ["wh_main_spell_fire_flaming_sword_of_rhuin"] = "29,44",
    ["wh_main_spell_fire_flaming_sword_of_rhuin_upgraded"] = "29,44",
    ["wh_main_spell_fire_piercing_bolts_of_burning"] = "19,47",
    ["wh_main_spell_fire_piercing_bolts_of_burning_upgraded"] = "19,47",
    ["wh_main_spell_fire_the_burning_head"] = "19,37",
    ["wh_main_spell_fire_the_burning_head_upgraded"] = "19,37",
    ["wh_main_spell_heavens_chain_lightning"] = "19,50",
    ["wh_main_spell_heavens_comet_of_casandora"] = "19,49",
    ["wh_main_spell_heavens_comet_of_casandora_summoned"] = "19,49",
    ["wh_main_spell_heavens_comet_of_casandora_upgraded"] = "19,49",
    ["wh_main_spell_heavens_curse_of_the_midnight_wind"] = "19,38",
    ["wh_main_spell_heavens_curse_of_the_midnight_wind_upgraded"] = "19,38",
    ["wh_main_spell_heavens_harmonic_convergence"] = "28,30",
    ["wh_main_spell_heavens_harmonic_convergence_upgraded"] = "28,30",
    ["wh_main_spell_heavens_urannons_thunderbolt"] = "19,42",
    ["wh_main_spell_heavens_urannons_thunderbolt_upgraded"] = "19,42",
    ["wh_main_spell_heavens_wind_blast"] = "19,32",
    ["wh_main_spell_heavens_wind_blast_summoned"] = "19,32",
    ["wh_main_spell_heavens_wind_blast_upgraded"] = "19,32",
    ["wh_main_spell_light_banishment"] = "19,54",
    ["wh_main_spell_light_banishment_upgraded"] = "19,54",
    ["wh_main_spell_light_bironas_timewarp"] = "29,47",
    ["wh_main_spell_light_bironas_timewarp_upgraded"] = "29,47",
    ["wh_main_spell_light_light_of_battle"] = "29,43",
    ["wh_main_spell_light_light_of_battle_upgraded"] = "29,43",
    ["wh_main_spell_light_net_of_amyntok"] = "18,38",
    ["wh_main_spell_light_net_of_amyntok_upgraded"] = "19,38",
    ["wh_main_spell_light_phas_protection"] = "28,29",
    ["wh_main_spell_light_phas_protection_upgraded"] = "29,29",
    ["wh_main_spell_light_shems_burning_gaze"] = "18,30",
    ["wh_main_spell_light_shems_burning_gaze_bound"] = "2,60",
    ["wh_main_spell_light_shems_burning_gaze_upgraded"] = "18,30",
    ["wh_main_spell_lil_waaagh_curse_of_da_bad_moon"] = "19,47",
    ["wh_main_spell_lil_waaagh_curse_of_da_bad_moon_upgraded"] = "19,47",
    ["wh_main_spell_lil_waaagh_gorkll_fix_it"] = "19,43",
    ["wh_main_spell_lil_waaagh_itchy_nuisance"] = "19,44",
    ["wh_main_spell_lil_waaagh_night_shroud"] = "29,48",
    ["wh_main_spell_lil_waaagh_night_shroud_upgraded"] = "29,48",
    ["wh_main_spell_lil_waaagh_sneaky_stabbin"] = "28,28",
    ["wh_main_spell_lil_waaagh_vindictive_glare"] = "18,29",
    ["wh_main_spell_lil_waaagh_vindictive_glare_upgraded"] = "18,29",
    ["wh_main_spell_metal_final_transmutation"] = "19,54",
    ["wh_main_spell_metal_final_transmutation_upgraded"] = "19,54",
    ["wh_main_spell_metal_gehennas_golden_hounds"] = "19,45",
    ["wh_main_spell_metal_gehennas_golden_hounds_upgraded"] = "19,45",
    ["wh_main_spell_metal_glittering_robe"] = "28,42",
    ["wh_main_spell_metal_glittering_robe_upgraded"] = "29,42",
    ["wh_main_spell_metal_plague_of_rust"] = "18,28",
    ["wh_main_spell_metal_plague_of_rust_upgraded"] = "18,28",
    ["wh_main_spell_metal_searing_doom"] = "19,30",
    ["wh_main_spell_metal_searing_doom_upgraded"] = "19,30",
    ["wh_main_spell_metal_transmutation_of_lead"] = "19,47",
    ["wh_main_spell_metal_transmutation_of_lead_upgraded"] = "19,47",
    ["wh_main_spell_vampires_curse_of_years"] = "19,47",
    ["wh_main_spell_vampires_gaze_of_nagash"] = "18,44",
    ["wh_main_spell_vampires_gaze_of_nagash_upgraded"] = "18,44",
    ["wh_main_spell_vampires_invocation_of_nehek"] = "28,30",
    ["wh_main_spell_vampires_invocation_of_nehek_upgraded"] = "29,30",
    ["wh_main_spell_vampires_raise_dead"] = "29,39",
    ["wh_main_spell_vampires_raise_dead_upgraded"] = "29,39",
    ["wh_main_spell_vampires_vanhels_danse_macabre"] = "28,28",
    ["wh_main_spell_vampires_vanhels_danse_macabre_upgraded"] = "28,28",
    ["wh_main_spell_vampires_wind_of_death"] = "19,44",
    ["wh_main_spell_vampires_wind_of_death_upgraded"] = "19,44",
    ["wh_main_unit_abilities_blooood"] = "8,60",
    ["wh_main_unit_abilities_boom"] = "8,90",
    ["wh_main_unit_abilities_entrenchment"] = "12,90",
    ["wh_main_unit_abilities_gyrobomber_bomb"] = "0,0",
    ["wh_main_unit_abilities_gyrocopter_bomb"] = "0,0",
    ["wh_main_unit_abilities_killing_blow"] = "8,60",
    ["wh_main_unit_abilities_spinning_loons"] = "3,30",
    ["wh_main_weapon_abilities_axe_of_dargo"] = "8,120",
    ["wh_main_weapon_abilities_charmed_shield"] = "8,60",
    ["wh_main_weapon_abilities_filth_mace"] = "8,90",
    ["wh_main_weapon_abilities_ghal_maraz"] = "8,120",
    ["wh_main_weapon_abilities_gitsnik"] = "8,120",
    ["wh_main_weapon_abilities_hellfire_sword"] = "8,90",
    ["wh_main_weapon_abilities_helm_of_discord"] = "0,90",
    ["wh_main_weapon_abilities_runefang"] = "8,120",
    ["wh_main_weapon_abilities_skabscrath"] = "3,90",
    ["wh_main_weapon_abilities_sword_of_anti_heroes"] = "8,90",
    ["wh_main_weapon_abilities_the_hammer_of_karak_drazh"] = "2,90",
    ["wh_main_weapon_abilities_the_mace_of_helsturm"] = "8,90",
    ["wh_main_weapon_abilities_the_reikland_runefang"] = "8,120",
    ["wh_main_weapon_abilities_the_sword_of_couronne"] = "0,120",
    ["wh_main_weapon_abilities_tormentor_sword"] = "0,90",
    ["wh_pro01_lord_abilities_flash_bomb"] = "2,90",
    ["wh_pro01_lord_passive_grombrindal_has_no_fear"] = "8,120",
    ["wh_pro01_weapon_abilities_rune_axe_of_grombrindal"] = "8,120",
    ["wh_pro02_item_abilities_blood_chalice_of_bathori"] = "12,120",
    ["wh_pro03_lord_abilities_lord_of_undeath"] = "13,120",
    ["wh_pro03_lord_abilities_lord_of_undeath_0"] = "13,120",
    ["wh_pro03_lord_abilities_lord_of_undeath_1"] = "13,120",
    ["wh_pro03_lord_abilities_lord_of_undeath_2"] = "13,120",
    ["wh_pro03_lord_abilities_lord_of_undeath_3"] = "13,120",
    ["wh_pro03_lord_abilities_lord_of_undeath_4"] = "13,120",
    ["wh_pro04_unit_abilities_apocalyptic_charge"] = "8,120",
    ["wh_pro04_unit_abilities_enrage"] = "8,90",
    ["wh_pro04_unit_abilities_loecs_shroud"] = "8,120",
    ["wh_pro04_unit_abilities_warp_gaze"] = "2,90",
}

if not CONFIG.enabled then return end
if bm:is_replay() or bm:is_tutorial() then return end

local function out_log(msg)
    out(">>> czx_auto_ability >>> " .. tostring(msg))
end

local cast_log = {} -- [unit_ui_id] = { [ability_key] = last_attempt_ms }

-- auto-delegation state
local planner = nil           -- script_ai_planner holding the delegated army
local delegate_ms = 0         -- when the planner was created (diagnostics)
local delegate_err_logged = false
local managed = {}        -- [uid] = true: this commander owns tasking. NOT the
                          --   same as is_ai_controlled — our own uc orders flip
                          --   that flag to false (script control) and planner
                          --   orders release_control() first, so it flaps.
                          --   managed[] is the stable ownership record.
local our_order_ms = {}   -- [uid] = last battle-ms WE issued a uc order
local order_dest = {}     -- [uid] = baseline ordered_position for the player-
                          --   order fingerprint (nil = disarmed/unknown)
local atk_target_uid = {} -- [uid] = enemy uid our last attack order pointed at
local prev_ai = {}        -- [uid] = is_ai_controlled() last tick (edge detect)
local prev_ordered = {}   -- [uid] = last ordered_position seen while AI-flagged
                          -- (the planner's intent — baseline for the fingerprint)
local saw_enemies = false -- set once any enemy is seen; gates outcome detection
local outcome_logged = false
local roster_logged = false
local reclaimed = {}      -- [uid] = true once the player takes a unit back; never re-delegate
local focus_count = {}    -- [enemy_uid] = attack orders issued this tick
local directive_doc = nil     -- doctrine the standing planner order was issued under
local directive_ms = 0        -- when it was issued
local directive_target = nil  -- enemy unit the standing attack order points at
local directive_pos = nil     -- defend_position anchor (attack uses live target pos)

-- every uc order we issue flips the unit to script control and rewrites
-- ordered_position; record it so the reclaim fingerprint doesn't flag our
-- own orders as player takeovers. target_uid kept for attack-order checks.
local function note_our_order(uid, now_ms, target_uid)
    our_order_ms[uid] = now_ms
    order_dest[uid] = nil           -- disarm until the order settles
    atk_target_uid[uid] = target_uid
end
-- handoff / micro state
local overridden = {}         -- [uid] = {at=ms, idle_at=ms} temp player control, auto-returns
local charge_state = {}       -- [uid] = {phase="in"|"out", at=ms} cav cycle-charge
local role_of = {}            -- [uid] = role, snapshot map for order arming
local wounded_pull = {}       -- [uid] = battle-ms of last disengage hop
local dodge_at = {}           -- [uid] = last dodge-order ms
local cmd_seen = {}           -- [command name] = count, probe throttle
local in_task_pass = false    -- true while our own uc orders are being issued

-- 野战白名单：攻城/任务战不自动托管（CA 官方不建议攻城用 planner，同 v2 gate）
local DELEGATE_TYPES = {
    land_normal = true, land_ambush = true,
    underground = true, underway = true,
    chokepoint = true, crossing = true,
}

-- 攻防克制加成（v2 counter 矩阵，社区共识 2026-09 修订）：
-- attacker_role -> target_role -> score。
-- 要点：骑兵/飞行猎后排炮兵射手；远程集火克巨兽（大多无甲）；
-- 反大步兵靠 anti_large 旗标额外加成分（对骑兵和巨兽都生效，不止巨兽）；
-- 近战线列怕骑兵冲、远程怕一切贴身；骑射是永远风筝的骚扰兵。
local COUNTER_BONUS = {
    melee     = { shooter = 30, artillery = 40, monster = -20, cav = -15 },
    monster   = { melee = 20, shooter = 25, cav = 10, cav_shot = 15 },
    cav       = { shooter = 40, artillery = 50, monster = -30, melee = -10,
                  cav_shot = 35 },
    cav_shot  = { melee = 10, artillery = 30, monster = -15 }, -- harass, avoid monsters
    flyer     = { artillery = 40, shooter = 30, monster = -20, cav_shot = 25 },
    shooter   = { monster = 30, cav = 10, melee = 10 },  -- ranged focus melts big unarmoured things
    artillery = { melee = 10, monster = 10 },
    lord      = {},
}
local function counter_of(att_role, def_role)
    local row = COUNTER_BONUS[att_role]
    return (row and row[def_role]) or 0
end

local function for_each_player_unit(cb)
    local alliance = bm:alliances():item(bm:local_alliance())
    if not alliance then return end
    local army = alliance:armies():item(bm:local_army())
    if not army then return end
    local units = army:units()
    for i = 1, units:count() do
        cb(units:item(i))
    end
end

local function nearest_enemy(unit)
    local alliance = bm:get_non_player_alliance()
    if not alliance then return nil, math.huge end
    local best, best_d = nil, math.huge
    local up = unit:position()
    local armies = alliance:armies()
    for a = 1, armies:count() do
        local units = armies:item(a):units()
        for u = 1, units:count() do
            local e = units:item(u)
            if e and not e:is_routing() then
                local ok, d = pcall(function() return up:distance_xz(e:position()) end)
                if ok and d and d < best_d then
                    best, best_d = e, d
                end
            end
        end
    end
    return best, best_d
end

local function ability_allowed(unit, key)
    if CONFIG.banned_abilities[key] then return false end
    if next(CONFIG.unit_keys) ~= nil then
        local ut = unit:type()
        if not CONFIG.unit_keys[ut] then return false end
    end
    return true
end

local unsupported = {} -- [uid.."|"..key] = true once the engine reports the unit doesn't support the ability
local denied_keys = {} -- [ability_key] = true once a maneuver ability was skipped and logged
local cast_at = {}     -- [unit_ui_id] = battle ms of last successful cast on the unit
local summon_probe = {} -- [unit_type] = true once a summoned unit type was logged as cast-skipped

local function try_cast(su, unit, key, now_ms)
    local uid = tostring(unit:unique_ui_id())
    local combo = uid .. "|" .. key
    if unsupported[combo] then return end
    local ulog = cast_log[uid]
    if ulog and ulog[key] and (now_ms - ulog[key]) < CONFIG.retry_ms then
        return
    end
    -- formation abilities are unit-shape toggles, not fire-and-forget casts:
    -- re-toggling churns control and can wedge the engine's formation solver
    -- (observed: sim froze 1.7s after formation_lance was auto-cast on a
    -- single-model monster). Covers mod abilities missing the baked flag.
    if key:find("formation") then return end
    -- maneuver abilities (bomb drops / flyover attacks) require the unit to fly
    -- over a target point; unbaked mod keys fall through to the self-cast path,
    -- which makes the flyer maneuver toward its own position forever and deadlocks
    -- the sim thread (observed: two freezes ~1s after casting djs_fw_190_zhadan).
    if key:find("zhadan") or key:find("gyrobomber_bomb") or key:find("copter_bomb")
        or key:find("bomb_drop") or key:find("djs_f4u_t0") then
        if not denied_keys[key] then
            denied_keys[key] = true
            out_log("denied-maneuver " .. key)
        end
        return
    end
    local flag_str = ABILITY_FLAGS[key]
    local mask, recharge = 0, 0
    if flag_str then
        mask, recharge = flag_str:match("^(%d+),(%d+)")
        mask, recharge = tonumber(mask) or 0, tonumber(recharge) or 0
    end
    if mask >= 16 then
        if not CONFIG.cast_spells then return end
        mask = mask - 16
    end
    if not unit:can_perform_special_ability(key) then
        return
    end
    -- engagement gate: don't churn unit control for abilities that can't matter yet
    local e, dist = nearest_enemy(unit)
    if not e or dist > CONFIG.engage_range_m then
        return
    end
    local fired = false
    if mask % 2 >= 1 then -- target_ground
        su.uc:perform_special_ability_ground(key, e:position())
        fired = true
    elseif mask % 4 >= 2 then -- target_enemies
        su.uc:perform_special_ability(key, e)
        fired = true
    else -- self / aura / target_friends -> cast on self (engine requires the target arg; pass own unit)
        su.uc:perform_special_ability(key, unit)
        fired = true
    end
    if fired then
        -- issuing an order implicitly takes script control; release it back so the
        -- ai planner can keep commanding the unit
        su.uc:release_control()
        note_our_order(uid, now_ms)
        cast_log[uid] = cast_log[uid] or {}
        cast_log[uid][key] = now_ms
        cast_at[uid] = now_ms -- quiet window: suppress task orders while the cast resolves
        out_log("cast " .. key .. " on " .. uid)
    end
end

local idle_since = {} -- [unit_ui_id] = battle ms when the unit was first seen idle
local kicked_at = {}  -- [unit_ui_id] = battle ms of last nudge, to avoid spamming orders
local guard_set = {}  -- [unit_ui_id] = true once a behaviour flag was applied
local unit_task = {}  -- [unit_ui_id] = last assigned task id
local seen_types = {} -- [unit_type] = true once role-probe info was logged

local function unit_dist(a, b)
    local ok, d = pcall(function() return a:position():distance_xz(b:position()) end)
    return (ok and is_number(d)) and d or math.huge
end

local function nearest_of(unit, list)
    local best, bd = nil, math.huge
    for _, o in ipairs(list) do
        local d = unit_dist(unit, o)
        if d < bd then best, bd = o, d end
    end
    return best, bd
end

-- baked unit profiles: [unit_type] = "ai_role|category|class|is_large"
local CZX_UNIT_PROFILE = {
    ["cthdce_cth_inf_dragon_guard_crossbowmen_elite"] = "ranged_no_skirmish|inf_ranged|inf_mis|0",
    ["cthdcv_cth_inf_dragon_guard_crossbowmen_vanguard"] = "ranged_no_skirmish|inf_ranged|inf_mis|0",
    ["czx_baochong"] = "melee_flanker|inf_melee|inf_mel|1",
    ["czx_baolongshou"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dehaka"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_aerovdramon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_agumon"] = "melee_gatecrusher|inf_melee|inf_mel|0",
    ["czx_dgm_alphamon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_angemon"] = "melee_gatecrusher|inf_melee|inf_mel|0",
    ["czx_dgm_angewomon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_apocalymon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_birdramon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_biyomon"] = "melee_gatecrusher|inf_melee|inf_mel|0",
    ["czx_dgm_blitzgreymon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_chaosdramon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_cresgarurumon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_dorugamon"] = "melee_gatecrusher|inf_melee|inf_mel|0",
    ["czx_dgm_dorugoramon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_dorumon"] = "melee_gatecrusher|inf_melee|inf_mel|0",
    ["czx_dgm_duramon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_durandamon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_fairymon"] = "melee_gatecrusher|inf_melee|inf_mel|0",
    ["czx_dgm_fujinmon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_gabumon"] = "melee_gatecrusher|inf_melee|inf_mel|0",
    ["czx_dgm_gallantmon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_gallantmoncm"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_gallantmonx"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_garudamon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_garurumon"] = "melee_gatecrusher|inf_melee|inf_mel|0",
    ["czx_dgm_gatomon"] = "melee_gatecrusher|inf_melee|inf_mel|0",
    ["czx_dgm_geogreymon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_gomamon"] = "melee_gatecrusher|inf_melee|inf_mel|0",
    ["czx_dgm_greymon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_growlmon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_guilmon"] = "melee_gatecrusher|inf_melee|inf_mel|0",
    ["czx_dgm_heraklekabuterimon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_hououmon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_ikkakumon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_imperialdm"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_imperialfm"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_imperialpm"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_jesmon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_jesmonx"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_jetsilphymon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_kabuterimon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_kyubimon"] = "melee_gatecrusher|inf_melee|inf_mel|0",
    ["czx_dgm_lalamon"] = "melee_gatecrusher|inf_melee|inf_mel|0",
    ["czx_dgm_lilamon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_lilimon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_lucemon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_lucemonfm"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_machinedramon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_magnaangemon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_magnadramon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_magnamon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_magnamonx"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_mastemon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_megakabuterimon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_megaseadramon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_metalgarurumon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_metalgarurumonx"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_metalgreymon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_metalseadramon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_metaltyranomon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_omegamon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_omegamonab"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_omegamonas"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_omegamond"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_omegamonm"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_omegamonx"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_ophanimon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_ophanimonfm"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_paildramon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_palmon"] = "melee_gatecrusher|inf_melee|inf_mel|0",
    ["czx_dgm_patamon"] = "melee_gatecrusher|inf_melee|inf_mel|0",
    ["czx_dgm_plesiomon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_plotmon"] = "melee_gatecrusher|inf_melee|inf_mel|0",
    ["czx_dgm_renamon"] = "melee_gatecrusher|inf_melee|inf_mel|0",
    ["czx_dgm_rizegreymon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_rosemon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_rosemonbm"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_sakuyamon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_seadramon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_seraphimon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_shinegreymon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_shinegreymonbm"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_skullgreymon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_sunflowmon"] = "melee_gatecrusher|inf_melee|inf_mel|0",
    ["czx_dgm_susanoomon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_taomon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_tentomon"] = "melee_gatecrusher|inf_melee|inf_mel|0",
    ["czx_dgm_tinkermon"] = "melee_gatecrusher|inf_melee|inf_mel|0",
    ["czx_dgm_togemon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_tyranomon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_ulforcev"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_ulforcevx"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_veedramon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_veemon"] = "melee_gatecrusher|inf_melee|inf_mel|0",
    ["czx_dgm_veemonex"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_vikemon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_vritramon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_wargreymon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_wargreymonx"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_wargrowlmon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_weregarurumon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_zeedmillennium"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_dgm_zubaeagermon"] = "melee_gatecrusher|inf_melee|inf_mel|0",
    ["czx_dgm_zubamon"] = "melee_gatecrusher|inf_melee|inf_mel|0",
    ["czx_dgm_zudomon"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_feilong"] = "flying_ranged_harasser_flanker|inf_ranged|inf_mis|1",
    ["czx_hd_black"] = "melee|inf_melee|inf_mel|0",
    ["czx_hd_dblack"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_hd_green"] = "melee_gatecrusher_shock|inf_melee|inf_mel|0",
    ["czx_hd_white"] = "melee|inf_melee|inf_mel|0",
    ["czx_inf_diamondback"] = "melee_flanker|inf_melee|inf_mel|1",
    ["czx_inf_marine"] = "ranged_direct|inf_ranged|inf_mis|0",
    ["czx_inf_tank"] = "ranged_direct_highvalue|war_machine|chariot|1",
    ["czx_jibian"] = "melee_gatecrusher_shock|inf_melee|inf_mel|0",
    ["czx_kerrigan"] = "mage_highvalue|inf_melee|com|0",
    ["czx_kerrigan_lord"] = "mage_highvalue|inf_melee|com|0",
    ["czx_mangshou"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["czx_zhanglang"] = "melee_gatecrusher_undead|inf_melee|inf_mel|1",
    ["hefadk_hef_cav_avelorn_dragon_knights"] = "flying_hybrid_highvalue|war_beast|com|1",
    ["hefadk_hef_cav_eden_valley_dragon_knights_ror"] = "flying_hybrid_highvalue|war_beast|com|1",
    ["hefps_hef_cha_princess_mod_0"] = "hybrid_highvalue|inf_ranged|com|0",
    ["hefps_hef_cha_princess_mod_1"] = "hybrid_cav_highvalue|cavalry|com|1",
    ["hefps_hef_cha_princess_mod_3"] = "flying_hybrid_highvalue|war_beast|com|1",
    ["hefps_hef_cha_princess_mod_4"] = "flying_hybrid_highvalue|war_beast|com|1",
    ["hefps_hef_cha_princess_mod_5"] = "flying_hybrid_highvalue|war_beast|com|1",
    ["hefps_hef_cha_princess_mod_6"] = "flying_hybrid_highvalue|war_beast|com|1",
    ["wh2_dlc09_skv_cha_tretch_craventail"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_dlc09_tmb_art_casket_of_souls_0"] = "ranged_indirect_arty_undead|war_machine|chariot|1",
    ["wh2_dlc09_tmb_art_screaming_skull_catapult_0"] = "ranged_indirect_arty_undead|artillery|art_fld|0",
    ["wh2_dlc09_tmb_cav_hexwraiths"] = "melee_flanker_undead|cavalry|cav_mel|0",
    ["wh2_dlc09_tmb_cav_necropolis_knights_0"] = "melee_flanker_shock_undead|cavalry|cav_shk|1",
    ["wh2_dlc09_tmb_cav_necropolis_knights_1"] = "melee_flanker_shock_undead|cavalry|cav_shk|1",
    ["wh2_dlc09_tmb_cav_necropolis_knights_ror"] = "melee_flanker_shock_undead|cavalry|cav_shk|1",
    ["wh2_dlc09_tmb_cav_nehekhara_horsemen_0"] = "melee_flanker_undead|cavalry|cav_mel|1",
    ["wh2_dlc09_tmb_cav_nehekhara_horsemen_ror"] = "melee_flanker_undead|cavalry|cav_mel|1",
    ["wh2_dlc09_tmb_cav_skeleton_horsemen_0"] = "melee_flanker_undead|cavalry|cav_mel|1",
    ["wh2_dlc09_tmb_cav_skeleton_horsemen_archers_0"] = "ranged_harasser_flanker_undead|cavalry|cav_mis|1",
    ["wh2_dlc09_tmb_cha_arkhan_0"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh2_dlc09_tmb_cha_arkhan_1"] = "melee_highvalue_undead|cavalry|com|1",
    ["wh2_dlc09_tmb_cha_arkhan_2"] = "melee_flanker_shock_highvalue_undead|war_machine|com|1",
    ["wh2_dlc09_tmb_cha_khalida_0"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh2_dlc09_tmb_cha_khalida_1"] = "melee_highvalue_undead|cavalry|com|1",
    ["wh2_dlc09_tmb_cha_khalida_2"] = "melee_flanker_shock_highvalue_undead|war_machine|com|1",
    ["wh2_dlc09_tmb_cha_khatep_0"] = "mage_highvalue_undead|inf_melee|com|0",
    ["wh2_dlc09_tmb_cha_khatep_1"] = "mage_highvalue_undead|cavalry|com|1",
    ["wh2_dlc09_tmb_cha_khatep_2"] = "mage_highvalue_undead|war_machine|com|1",
    ["wh2_dlc09_tmb_cha_khatep_3"] = "ranged_highvalue_undead|war_machine|com|1",
    ["wh2_dlc09_tmb_cha_liche_priest_death_0"] = "mage_highvalue_undead|inf_melee|com|0",
    ["wh2_dlc09_tmb_cha_liche_priest_death_1"] = "mage_highvalue_undead|cavalry|com|1",
    ["wh2_dlc09_tmb_cha_liche_priest_light_0"] = "mage_highvalue_undead|inf_melee|com|0",
    ["wh2_dlc09_tmb_cha_liche_priest_light_1"] = "mage_highvalue_undead|cavalry|com|1",
    ["wh2_dlc09_tmb_cha_liche_priest_nehekhara_0"] = "mage_highvalue_undead|inf_melee|com|0",
    ["wh2_dlc09_tmb_cha_liche_priest_nehekhara_1"] = "mage_highvalue_undead|cavalry|com|1",
    ["wh2_dlc09_tmb_cha_liche_priest_shadow_0"] = "mage_highvalue_undead|inf_melee|com|0",
    ["wh2_dlc09_tmb_cha_liche_priest_shadow_1"] = "mage_highvalue_undead|cavalry|com|1",
    ["wh2_dlc09_tmb_cha_necrotect_0"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh2_dlc09_tmb_cha_necrotect_1"] = "melee_flanker_shock_highvalue_undead|war_machine|com|1",
    ["wh2_dlc09_tmb_cha_settra_0"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh2_dlc09_tmb_cha_settra_1"] = "melee_flanker_shock_highvalue_undead|cavalry|com|1",
    ["wh2_dlc09_tmb_cha_settra_2"] = "melee_flanker_shock_highvalue_undead|war_machine|com|1",
    ["wh2_dlc09_tmb_cha_settra_3"] = "melee_flanker_shock_highvalue_undead|war_beast|com|1",
    ["wh2_dlc09_tmb_cha_tomb_king_0"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh2_dlc09_tmb_cha_tomb_king_1"] = "melee_flanker_shock_highvalue_undead|cavalry|com|1",
    ["wh2_dlc09_tmb_cha_tomb_king_2"] = "melee_flanker_shock_highvalue_undead|war_machine|com|1",
    ["wh2_dlc09_tmb_cha_tomb_king_3"] = "melee_flanker_shock_highvalue_undead|war_beast|com|1",
    ["wh2_dlc09_tmb_cha_tomb_prince_0"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh2_dlc09_tmb_cha_tomb_prince_1"] = "melee_flanker_shock_highvalue_undead|cavalry|com|1",
    ["wh2_dlc09_tmb_cha_tomb_prince_2"] = "melee_flanker_shock_highvalue_undead|war_machine|com|1",
    ["wh2_dlc09_tmb_inf_crypt_ghouls"] = "melee_undead|inf_melee|inf_mel|0",
    ["wh2_dlc09_tmb_inf_nehekhara_warriors_0"] = "melee_undead|inf_melee|inf_mel|0",
    ["wh2_dlc09_tmb_inf_nehekhara_warriors_ror"] = "melee_undead|inf_melee|inf_mel|0",
    ["wh2_dlc09_tmb_inf_skeleton_archers_0"] = "ranged_undead|inf_ranged|inf_mis|0",
    ["wh2_dlc09_tmb_inf_skeleton_archers_ror"] = "ranged_undead|inf_ranged|inf_mis|0",
    ["wh2_dlc09_tmb_inf_skeleton_spearmen_0"] = "melee_anti_large_undead|inf_melee|inf_spr|0",
    ["wh2_dlc09_tmb_inf_skeleton_spearmen_ror"] = "melee_anti_large_undead|inf_melee|inf_spr|0",
    ["wh2_dlc09_tmb_inf_skeleton_warriors_0"] = "melee_undead|inf_melee|inf_mel|0",
    ["wh2_dlc09_tmb_inf_skeleton_warriors_0_summoned"] = "melee_undead|inf_melee|inf_mel|0",
    ["wh2_dlc09_tmb_inf_tomb_guard_0"] = "melee_undead|inf_melee|inf_mel|0",
    ["wh2_dlc09_tmb_inf_tomb_guard_1"] = "melee_anti_large_undead|inf_melee|inf_mel|0",
    ["wh2_dlc09_tmb_inf_tomb_guard_ror"] = "melee_undead|inf_melee|inf_mel|0",
    ["wh2_dlc09_tmb_mon_carrion_0"] = "flying_melee_flanker_undead|inf_melee|inf_mel|0",
    ["wh2_dlc09_tmb_mon_carrion_ror"] = "flying_fast_melee_flanker_bomber_undead|inf_melee|inf_mel|0",
    ["wh2_dlc09_tmb_mon_dire_wolves"] = "melee_flanker_undead|inf_melee|inf_mel|0",
    ["wh2_dlc09_tmb_mon_fell_bats"] = "flying_melee_flanker_undead|inf_melee|inf_mel|0",
    ["wh2_dlc09_tmb_mon_heirotitan_0"] = "melee_gatecrusher_undead|inf_melee|inf_mel|1",
    ["wh2_dlc09_tmb_mon_khemrian_warsphinx_0"] = "melee_gatecrusher_undead|war_beast|inf_mel|1",
    ["wh2_dlc09_tmb_mon_necrosphinx_0"] = "melee_gatecrusher_undead|inf_melee|inf_mel|1",
    ["wh2_dlc09_tmb_mon_necrosphinx_ror"] = "melee_gatecrusher_undead|inf_melee|inf_mel|1",
    ["wh2_dlc09_tmb_mon_sepulchral_stalkers_0"] = "melee_undead|inf_ranged|inf_mis|1",
    ["wh2_dlc09_tmb_mon_sepulchral_stalkers_ror"] = "ranged_stalkers_flanker_undead|inf_ranged|inf_mis|1",
    ["wh2_dlc09_tmb_mon_tomb_scorpion_0"] = "melee_gatecrusher_undead|inf_melee|inf_mel|1",
    ["wh2_dlc09_tmb_mon_ushabti_0"] = "melee_gatecrusher_undead|inf_melee|inf_mel|1",
    ["wh2_dlc09_tmb_mon_ushabti_0_summoned"] = "melee_gatecrusher_undead|inf_melee|inf_mel|1",
    ["wh2_dlc09_tmb_mon_ushabti_1"] = "ranged_undead|inf_ranged|inf_mis|1",
    ["wh2_dlc09_tmb_mon_ushabti_ror"] = "ranged_undead|inf_ranged|inf_mis|1",
    ["wh2_dlc09_tmb_veh_skeleton_archer_chariot_0"] = "hybrid_flanker_shock_harasser_undead|war_machine|chariot|1",
    ["wh2_dlc09_tmb_veh_skeleton_chariot_0"] = "melee_flanker_shock_undead|war_machine|chariot|1",
    ["wh2_dlc10_def_cav_doomfire_warlocks_0"] = "melee_flanker_shock|cavalry|cav_mel|1",
    ["wh2_dlc10_def_cav_knights_of_the_ebon_claw_ror_0"] = "melee_flanker|cavalry|cav_mel|1",
    ["wh2_dlc10_def_cav_raven_heralds_ror_0"] = "flying_ranged_harasser_flanker|cavalry|cav_mis|1",
    ["wh2_dlc10_def_cav_slaanesh_harvesters_ror_0"] = "melee_flanker|cavalry|cav_mel|1",
    ["wh2_dlc10_def_cha_crone_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_dlc10_def_cha_crone_1"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh2_dlc10_def_cha_crone_4"] = "melee_highvalue|war_machine|com|1",
    ["wh2_dlc10_def_cha_crone_5"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh2_dlc10_def_cha_sorceress_beasts_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc10_def_cha_sorceress_beasts_1"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc10_def_cha_sorceress_beasts_2"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc10_def_cha_sorceress_beasts_3"] = "flying_mage_highvalue|cavalry|com|1",
    ["wh2_dlc10_def_cha_sorceress_death_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc10_def_cha_sorceress_death_1"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc10_def_cha_sorceress_death_2"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc10_def_cha_sorceress_death_3"] = "flying_mage_highvalue|cavalry|com|1",
    ["wh2_dlc10_def_cha_supreme_sorceress_beasts_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc10_def_cha_supreme_sorceress_beasts_1"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc10_def_cha_supreme_sorceress_beasts_2"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc10_def_cha_supreme_sorceress_beasts_3"] = "flying_mage_highvalue|cavalry|com|1",
    ["wh2_dlc10_def_cha_supreme_sorceress_beasts_4"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh2_dlc10_def_cha_supreme_sorceress_beasts_5"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh2_dlc10_def_cha_supreme_sorceress_dark_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc10_def_cha_supreme_sorceress_dark_1"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc10_def_cha_supreme_sorceress_dark_2"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc10_def_cha_supreme_sorceress_dark_3"] = "flying_mage_highvalue|cavalry|com|1",
    ["wh2_dlc10_def_cha_supreme_sorceress_dark_4"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh2_dlc10_def_cha_supreme_sorceress_dark_5"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh2_dlc10_def_cha_supreme_sorceress_death_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc10_def_cha_supreme_sorceress_death_1"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc10_def_cha_supreme_sorceress_death_2"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc10_def_cha_supreme_sorceress_death_3"] = "flying_mage_highvalue|cavalry|com|1",
    ["wh2_dlc10_def_cha_supreme_sorceress_death_4"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh2_dlc10_def_cha_supreme_sorceress_death_5"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh2_dlc10_def_cha_supreme_sorceress_fire_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc10_def_cha_supreme_sorceress_fire_1"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc10_def_cha_supreme_sorceress_fire_2"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc10_def_cha_supreme_sorceress_fire_3"] = "flying_mage_highvalue|cavalry|com|1",
    ["wh2_dlc10_def_cha_supreme_sorceress_fire_4"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh2_dlc10_def_cha_supreme_sorceress_fire_5"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh2_dlc10_def_cha_supreme_sorceress_shadow_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc10_def_cha_supreme_sorceress_shadow_1"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc10_def_cha_supreme_sorceress_shadow_2"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc10_def_cha_supreme_sorceress_shadow_3"] = "flying_mage_highvalue|cavalry|com|1",
    ["wh2_dlc10_def_cha_supreme_sorceress_shadow_4"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh2_dlc10_def_cha_supreme_sorceress_shadow_5"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh2_dlc10_def_inf_blades_of_the_blood_queen_ror_0"] = "melee|inf_melee|inf_mel|0",
    ["wh2_dlc10_def_inf_sisters_of_slaughter"] = "melee_undead|inf_melee|inf_mel|0",
    ["wh2_dlc10_def_inf_sisters_of_the_singing_doom_ror_0"] = "melee_undead|inf_melee|inf_mel|0",
    ["wh2_dlc10_def_inf_the_bolt_fiends_ror_0"] = "ranged|inf_ranged|inf_mis|0",
    ["wh2_dlc10_def_inf_the_hellebronai_ror_0"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh2_dlc10_def_mon_chill_of_sontar_ror_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh2_dlc10_def_mon_feral_manticore_0"] = "flying_melee_flanker_shock|inf_melee|inf_mel|1",
    ["wh2_dlc10_def_mon_kharibdyss_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh2_dlc10_def_mon_war_hydra_boss"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh2_dlc10_dwf_cha_thane_ghost_summoned_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_dlc10_dwf_inf_giant_slayers"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh2_dlc10_hef_cav_the_fireborn_ror_0"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh2_dlc10_hef_cav_the_heralds_of_the_wind_ror_0"] = "ranged_harasser_flanker|cavalry|cav_mis|1",
    ["wh2_dlc10_hef_cha_alarielle_the_radiant_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc10_hef_cha_alarielle_the_radiant_1"] = "mage_flanker_highvalue|cavalry|com|1",
    ["wh2_dlc10_hef_cha_alarielle_the_radiant_2"] = "mage_flanker_highvalue|cavalry|com|1",
    ["wh2_dlc10_hef_cha_alarielle_the_radiant_3"] = "flying_melee_shock_mage_highvalue|war_beast|com|1",
    ["wh2_dlc10_hef_cha_alith_anar_0"] = "hybrid_highvalue|inf_ranged|com|0",
    ["wh2_dlc10_hef_cha_alith_anar_summoned_0"] = "hybrid_highvalue|inf_ranged|com|0",
    ["wh2_dlc10_hef_cha_alith_anar_summoned_1"] = "hybrid_highvalue|inf_ranged|com|0",
    ["wh2_dlc10_hef_cha_handmaiden_0"] = "hybrid_highvalue|inf_ranged|com|0",
    ["wh2_dlc10_hef_cha_handmaiden_1"] = "ranged_cav_highvalue|cavalry|com|1",
    ["wh2_dlc10_hef_cha_handmaiden_2"] = "ranged_cav_highvalue|cavalry|com|1",
    ["wh2_dlc10_hef_cha_mage_heavens_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc10_hef_cha_mage_heavens_1"] = "mage_flanker_highvalue|cavalry|com|1",
    ["wh2_dlc10_hef_cha_mage_heavens_2"] = "mage_highvalue|war_machine|com|1",
    ["wh2_dlc10_hef_cha_mage_shadows_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc10_hef_cha_mage_shadows_1"] = "mage_flanker_highvalue|cavalry|com|1",
    ["wh2_dlc10_hef_cha_mage_shadows_2"] = "mage_highvalue|war_machine|com|1",
    ["wh2_dlc10_hef_cha_shadow_walker"] = "hybrid_highvalue|inf_ranged|com|0",
    ["wh2_dlc10_hef_inf_dryads_0"] = "melee|inf_melee|inf_mel|0",
    ["wh2_dlc10_hef_inf_everqueens_court_guards_ror_0"] = "ranged|inf_ranged|inf_mis|0",
    ["wh2_dlc10_hef_inf_keepers_of_the_flame_ror_0"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh2_dlc10_hef_inf_shadow_walkers_0"] = "ranged_stalkers_harasser|inf_ranged|inf_mis|0",
    ["wh2_dlc10_hef_inf_shadow_warriors_0"] = "ranged_stalkers_harasser|inf_ranged|inf_mis|0",
    ["wh2_dlc10_hef_inf_sisters_of_avelorn_0"] = "ranged_no_skirmish|inf_ranged|inf_mis|0",
    ["wh2_dlc10_hef_inf_the_grey_ror_0"] = "ranged_stalkers_harasser|inf_ranged|inf_mis|0",
    ["wh2_dlc10_hef_inf_the_scions_of_mathlann_ror_0"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh2_dlc10_hef_inf_the_silverpelts_ror_0"] = "melee|inf_melee|inf_mel|0",
    ["wh2_dlc10_hef_inf_the_storm_riders_ror_0"] = "hybrid_melee|inf_ranged|inf_mis|0",
    ["wh2_dlc10_hef_mon_treekin_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh2_dlc10_hef_mon_treeman_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh2_dlc10_lzd_mon_carnosaur_boss"] = "melee_highvalue|inf_melee|inf_mel|1",
    ["wh2_dlc10_nor_mon_phoenix_flamespyre_boss"] = "flying_melee_flanker|inf_melee|com|1",
    ["wh2_dlc10_skv_mon_hell_pit_abomination_boss"] = "melee_highvalue|inf_melee|inf_mel|1",
    ["wh2_dlc11_cst_art_carronade"] = "ranged_direct_arty_undead|artillery|art_fld|0",
    ["wh2_dlc11_cst_art_mortar"] = "ranged_indirect_arty_undead|artillery|art_fld|0",
    ["wh2_dlc11_cst_art_queen_bess"] = "ranged_indirect_arty_undead|artillery|art_fld|0",
    ["wh2_dlc11_cst_cav_deck_droppers_0"] = "flying_ranged_harasser_flanker_undead|cavalry|cav_mis|1",
    ["wh2_dlc11_cst_cav_deck_droppers_1"] = "flying_ranged_harasser_flanker_undead|cavalry|cav_mis|1",
    ["wh2_dlc11_cst_cav_deck_droppers_2"] = "flying_ranged_harasser_flanker_undead|cavalry|cav_mis|1",
    ["wh2_dlc11_cst_cav_deck_droppers_ror_0"] = "flying_ranged_harasser_flanker_undead|cavalry|cav_mis|1",
    ["wh2_dlc11_cst_cav_knights_errant_0"] = "melee_flanker_shock_undead|cavalry|cav_shk|0",
    ["wh2_dlc11_cst_cav_knights_errant_1"] = "melee_flanker_shock_undead|cavalry|cav_shk|0",
    ["wh2_dlc11_cst_cav_knights_errant_2"] = "melee_flanker_shock_undead|cavalry|cav_shk|0",
    ["wh2_dlc11_cst_cav_knights_of_the_realm"] = "melee_flanker_shock_undead|cavalry|cav_shk|0",
    ["wh2_dlc11_cst_cav_questing_knights_0"] = "melee_flanker_shock_undead|cavalry|cav_shk|0",
    ["wh2_dlc11_cst_cha_aranessa_0"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh2_dlc11_cst_cha_aranessa_1"] = "melee_highvalue_undead|war_beast|com|1",
    ["wh2_dlc11_cst_cha_cylostra_direfin_0"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh2_dlc11_cst_cha_cylostra_direfin_1"] = "melee_highvalue_undead|war_beast|com|1",
    ["wh2_dlc11_cst_cha_damned_paladin_0"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh2_dlc11_cst_cha_damned_paladin_1"] = "melee_flanker_shock_highvalue_undead|cavalry|com|0",
    ["wh2_dlc11_cst_cha_gunnery_wight_0"] = "ranged_direct_highvalue_undead|inf_ranged|com|0",
    ["wh2_dlc11_cst_cha_gunnery_wight_1"] = "ranged_direct_highvalue_undead|war_beast|com|1",
    ["wh2_dlc11_cst_cha_luthor_harkon_0"] = "hybrid_highvalue_undead|inf_ranged|com|0",
    ["wh2_dlc11_cst_cha_luthor_harkon_1"] = "flying_hybrid_highvalue_undead|war_beast|com|1",
    ["wh2_dlc11_cst_cha_mourngul_haunter"] = "melee_highvalue_undead|inf_melee|com|1",
    ["wh2_dlc11_cst_cha_vampire_fleet_admiral_0"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh2_dlc11_cst_cha_vampire_fleet_admiral_1"] = "melee_highvalue_undead|war_beast|com|1",
    ["wh2_dlc11_cst_cha_vampire_fleet_admiral_death_0"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh2_dlc11_cst_cha_vampire_fleet_admiral_death_1"] = "melee_highvalue_undead|war_beast|com|1",
    ["wh2_dlc11_cst_cha_vampire_fleet_admiral_deeps_0"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh2_dlc11_cst_cha_vampire_fleet_admiral_deeps_1"] = "melee_highvalue_undead|war_beast|com|1",
    ["wh2_dlc11_cst_cha_vampire_fleet_admiral_female_0"] = "melee_highvalue_undead|inf_ranged|com|0",
    ["wh2_dlc11_cst_cha_vampire_fleet_admiral_female_1"] = "melee_highvalue_undead|war_beast|com|1",
    ["wh2_dlc11_cst_cha_vampire_fleet_admiral_female_death_0"] = "melee_highvalue_undead|inf_ranged|com|0",
    ["wh2_dlc11_cst_cha_vampire_fleet_admiral_female_death_1"] = "melee_highvalue_undead|war_beast|com|1",
    ["wh2_dlc11_cst_cha_vampire_fleet_admiral_female_deeps_0"] = "melee_highvalue_undead|inf_ranged|com|0",
    ["wh2_dlc11_cst_cha_vampire_fleet_admiral_female_deeps_1"] = "melee_highvalue_undead|war_beast|com|1",
    ["wh2_dlc11_cst_cha_vampire_fleet_captain_0"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh2_dlc11_cst_cha_vampire_fleet_captain_1"] = "melee_highvalue_undead|war_beast|com|1",
    ["wh2_dlc11_cst_cha_vampire_fleet_captain_death_0"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh2_dlc11_cst_cha_vampire_fleet_captain_death_1"] = "melee_highvalue_undead|war_beast|com|1",
    ["wh2_dlc11_cst_cha_vampire_fleet_captain_deeps_0"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh2_dlc11_cst_cha_vampire_fleet_captain_deeps_1"] = "melee_highvalue_undead|war_beast|com|1",
    ["wh2_dlc11_cst_inf_count_noctilus_0"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh2_dlc11_cst_inf_count_noctilus_1"] = "hybrid_highvalue_undead|war_beast|com|1",
    ["wh2_dlc11_cst_inf_deck_gunners_0"] = "ranged_direct_no_skirmish_undead|inf_ranged|inf_mis|0",
    ["wh2_dlc11_cst_inf_deck_gunners_ror_0"] = "ranged_direct_no_skirmish_undead|inf_ranged|inf_mis|0",
    ["wh2_dlc11_cst_inf_depth_guard_0"] = "melee_undead|inf_melee|inf_mel|0",
    ["wh2_dlc11_cst_inf_depth_guard_1"] = "melee_anti_large_undead|inf_melee|inf_mel|0",
    ["wh2_dlc11_cst_inf_depth_guard_ror_0"] = "melee_anti_large_undead|inf_melee|inf_mel|0",
    ["wh2_dlc11_cst_inf_sartosa_free_company_0"] = "melee_undead|inf_melee|inf_mel|0",
    ["wh2_dlc11_cst_inf_sartosa_militia_0"] = "ranged_direct_undead|inf_ranged|inf_mis|0",
    ["wh2_dlc11_cst_inf_syreens"] = "melee_undead|inf_melee|inf_mel|0",
    ["wh2_dlc11_cst_inf_zombie_deckhands_mob_0"] = "melee_undead|inf_melee|inf_mel|0",
    ["wh2_dlc11_cst_inf_zombie_deckhands_mob_1"] = "melee_anti_large_undead|inf_melee|inf_mel|0",
    ["wh2_dlc11_cst_inf_zombie_deckhands_mob_necrofex_summoned_0"] = "melee_undead|inf_melee|inf_mel|0",
    ["wh2_dlc11_cst_inf_zombie_deckhands_mob_ror_0"] = "melee_undead|inf_melee|inf_mel|0",
    ["wh2_dlc11_cst_inf_zombie_deckhands_mob_summoned_0"] = "melee_undead|inf_melee|inf_mel|0",
    ["wh2_dlc11_cst_inf_zombie_gunnery_mob_0"] = "ranged_direct_no_skirmish_undead|inf_ranged|inf_mis|0",
    ["wh2_dlc11_cst_inf_zombie_gunnery_mob_1"] = "ranged_direct_no_skirmish_undead|inf_ranged|inf_mis|0",
    ["wh2_dlc11_cst_inf_zombie_gunnery_mob_2"] = "ranged_direct_no_skirmish_undead|inf_ranged|inf_mis|0",
    ["wh2_dlc11_cst_inf_zombie_gunnery_mob_3"] = "ranged_direct_no_skirmish_undead|inf_ranged|inf_mis|0",
    ["wh2_dlc11_cst_inf_zombie_gunnery_mob_ror_0"] = "ranged_direct_no_skirmish_undead|inf_ranged|inf_mis|0",
    ["wh2_dlc11_cst_inf_zombie_gunnery_mob_summoned_0"] = "ranged_direct_no_skirmish_undead|inf_ranged|inf_mis|0",
    ["wh2_dlc11_cst_mon_animated_hulks_0"] = "melee_gatecrusher_undead|inf_melee|inf_mel|1",
    ["wh2_dlc11_cst_mon_bloated_corpse_0"] = "melee_flanker_undead|inf_melee|inf_mel|1",
    ["wh2_dlc11_cst_mon_fell_bats"] = "flying_melee_flanker_undead|inf_melee|inf_mel|0",
    ["wh2_dlc11_cst_mon_mournguls_0"] = "melee_gatecrusher_undead|inf_melee|inf_mel|1",
    ["wh2_dlc11_cst_mon_mournguls_ror_0"] = "melee_gatecrusher_undead|inf_melee|inf_mel|1",
    ["wh2_dlc11_cst_mon_necrofex_colossus_0"] = "melee_gatecrusher_undead|war_beast|inf_mis|1",
    ["wh2_dlc11_cst_mon_necrofex_colossus_ror_0"] = "melee_gatecrusher_undead|war_beast|inf_mis|1",
    ["wh2_dlc11_cst_mon_rotting_leviathan_0"] = "melee_gatecrusher_undead|war_beast|inf_mel|1",
    ["wh2_dlc11_cst_mon_rotting_prometheans_0"] = "melee_gatecrusher_undead|inf_melee|inf_mel|1",
    ["wh2_dlc11_cst_mon_rotting_prometheans_gunnery_mob_0"] = "ranged_no_skirmish_gatecrusher_undead|war_beast|inf_mis|1",
    ["wh2_dlc11_cst_mon_rotting_prometheans_gunnery_mob_ror"] = "ranged_no_skirmish_gatecrusher_undead|war_beast|inf_mis|1",
    ["wh2_dlc11_cst_mon_rotting_prometheans_summoned_0"] = "melee_gatecrusher_undead|inf_melee|inf_mel|1",
    ["wh2_dlc11_cst_mon_scurvy_dogs"] = "melee_flanker_undead|inf_melee|inf_mel|0",
    ["wh2_dlc11_cst_mon_terrorgheist"] = "flying_melee_flanker_undead|inf_melee|inf_mel|1",
    ["wh2_dlc11_def_cha_lokhir_fellheart_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_dlc11_def_cha_lokhir_fellheart_1"] = "flying_melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh2_dlc11_vmp_cha_bloodline_blood_dragon_lord_0"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh2_dlc11_vmp_cha_bloodline_blood_dragon_lord_1"] = "melee_flanker_shock_highvalue_undead|cavalry|com|1",
    ["wh2_dlc11_vmp_cha_bloodline_blood_dragon_lord_2"] = "flying_melee_highvalue_undead|cavalry|com|1",
    ["wh2_dlc11_vmp_cha_bloodline_blood_dragon_lord_3"] = "flying_melee_highvalue_undead|war_beast|com|1",
    ["wh2_dlc11_vmp_cha_bloodline_lahmian_lord_0"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh2_dlc11_vmp_cha_bloodline_lahmian_lord_1"] = "melee_flanker_shock_highvalue_undead|cavalry|com|1",
    ["wh2_dlc11_vmp_cha_bloodline_lahmian_lord_2"] = "flying_melee_highvalue_undead|cavalry|com|1",
    ["wh2_dlc11_vmp_cha_bloodline_lahmian_lord_3"] = "flying_melee_highvalue_undead|war_beast|com|1",
    ["wh2_dlc11_vmp_cha_bloodline_necrarch_lord_0"] = "mage_highvalue_undead|inf_melee|com|0",
    ["wh2_dlc11_vmp_cha_bloodline_necrarch_lord_1"] = "melee_flanker_shock_highvalue_undead|cavalry|com|1",
    ["wh2_dlc11_vmp_cha_bloodline_necrarch_lord_2"] = "flying_mage_highvalue_undead|cavalry|com|1",
    ["wh2_dlc11_vmp_cha_bloodline_necrarch_lord_3"] = "flying_melee_mage_highvalue_undead|war_beast|com|1",
    ["wh2_dlc11_vmp_cha_bloodline_strigoi_lord_0"] = "melee_flanker_shock_highvalue_undead|inf_melee|com|0",
    ["wh2_dlc11_vmp_cha_bloodline_strigoi_lord_1"] = "flying_melee_highvalue_undead|war_beast|com|1",
    ["wh2_dlc11_vmp_cha_bloodline_von_carstein_lord_0"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh2_dlc11_vmp_cha_bloodline_von_carstein_lord_1"] = "melee_flanker_shock_highvalue_undead|cavalry|com|1",
    ["wh2_dlc11_vmp_cha_bloodline_von_carstein_lord_2"] = "flying_melee_highvalue_undead|cavalry|com|1",
    ["wh2_dlc11_vmp_cha_bloodline_von_carstein_lord_3"] = "flying_melee_highvalue_undead|war_beast|com|1",
    ["wh2_dlc11_vmp_cha_heinrich_kemmler_1"] = "mage_flanker_highvalue_undead|cavalry|com|1",
    ["wh2_dlc11_vmp_inf_crossbowmen"] = "ranged_undead|inf_ranged|inf_mis|0",
    ["wh2_dlc11_vmp_inf_handgunners"] = "ranged_direct_undead|inf_ranged|inf_mis|0",
    ["wh2_dlc11_vmp_mon_varghulf_summoned"] = "melee_gatecrusher_shock_undead|inf_melee|inf_mel|1",
    ["wh2_dlc12_lzd_cav_cold_one_spearriders_ror_0"] = "melee_flanker_shock|cavalry|cav_mel|1",
    ["wh2_dlc12_lzd_cav_ripperdactyl_riders_0"] = "flying_melee_flanker|cavalry|cav_mel|1",
    ["wh2_dlc12_lzd_cav_ripperdactyl_riders_0_blessed"] = "flying_melee_flanker|cavalry|cav_mel|1",
    ["wh2_dlc12_lzd_cav_ripperdactyl_riders_ror_0"] = "flying_melee_flanker|cavalry|cav_mel|1",
    ["wh2_dlc12_lzd_cav_terradon_riders_0_tlaqua"] = "flying_ranged_harasser_flanker|cavalry|cav_mis|1",
    ["wh2_dlc12_lzd_cav_terradon_riders_1_tlaqua"] = "flying_ranged_harasser_flanker|cavalry|cav_mis|1",
    ["wh2_dlc12_lzd_cav_terradon_riders_ror_0"] = "flying_ranged_harasser_flanker|cavalry|cav_mis|1",
    ["wh2_dlc12_lzd_cha_skink_chief_red_crested_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_dlc12_lzd_cha_skink_chief_red_crested_1"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh2_dlc12_lzd_cha_skink_chief_red_crested_2"] = "flying_melee_highvalue|cavalry|com|1",
    ["wh2_dlc12_lzd_cha_skink_chief_red_crested_3"] = "melee_gatecrusher_highvalue|war_beast|com|1",
    ["wh2_dlc12_lzd_cha_skink_priest_beasts_4"] = "melee_gatecrusher_highvalue|war_beast|com|1",
    ["wh2_dlc12_lzd_cha_skink_priest_heavens_4"] = "melee_gatecrusher_highvalue|war_beast|com|1",
    ["wh2_dlc12_lzd_cha_tehenhauin_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_dlc12_lzd_cha_tehenhauin_1"] = "melee_highvalue|cavalry|com|1",
    ["wh2_dlc12_lzd_cha_tehenhauin_2"] = "flying_melee_highvalue|cavalry|com|1",
    ["wh2_dlc12_lzd_cha_tehenhauin_3"] = "melee_gatecrusher_highvalue|war_beast|com|1",
    ["wh2_dlc12_lzd_cha_tiktaqto_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_dlc12_lzd_cha_tiktaqto_1"] = "flying_melee_highvalue|cavalry|com|1",
    ["wh2_dlc12_lzd_inf_saurus_warriors_ror_0"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh2_dlc12_lzd_inf_skink_red_crested_0"] = "melee|inf_melee|inf_mel|0",
    ["wh2_dlc12_lzd_inf_skink_red_crested_ror_0"] = "melee|inf_melee|inf_mel|0",
    ["wh2_dlc12_lzd_inf_temple_guards_ror_0"] = "melee|inf_melee|inf_mel|0",
    ["wh2_dlc12_lzd_lzd_cha_kroak_0"] = "mage_highvalue|war_machine|com|1",
    ["wh2_dlc12_lzd_lzd_cha_kroak_0_boss"] = "mage_highvalue|war_machine|com|1",
    ["wh2_dlc12_lzd_mon_ancient_salamander_0"] = "ranged_harasser|inf_ranged|inf_mis|1",
    ["wh2_dlc12_lzd_mon_ancient_salamander_0_blessed"] = "ranged_harasser|inf_ranged|inf_mis|1",
    ["wh2_dlc12_lzd_mon_ancient_stegadon_1"] = "melee_passiveshooter_gatecrusher_highvalue|war_beast|inf_mel|1",
    ["wh2_dlc12_lzd_mon_ancient_stegadon_ror_0"] = "melee_gatecrusher_highvalue|war_beast|inf_mel|1",
    ["wh2_dlc12_lzd_mon_bastiladon_3"] = "melee_passiveshooter_gatecrusher|war_beast|inf_mel|1",
    ["wh2_dlc12_lzd_mon_salamander_pack_0"] = "ranged_harasser|inf_ranged|inf_mis|1",
    ["wh2_dlc12_lzd_mon_salamander_pack_0_blessed"] = "ranged_harasser|inf_ranged|inf_mis|1",
    ["wh2_dlc12_lzd_mon_salamander_pack_ror_0"] = "ranged_harasser|inf_ranged|inf_mis|1",
    ["wh2_dlc12_skv_art_warp_lightning_cannon_ror_0"] = "ranged_direct_arty|artillery|art_fld|0",
    ["wh2_dlc12_skv_art_warplock_jezzails_ror_tech_lab_0"] = "ranged_direct|inf_ranged|inf_mis|0",
    ["wh2_dlc12_skv_cha_ikit_claw_0"] = "ranged_direct_highvalue|inf_melee|com|0",
    ["wh2_dlc12_skv_cha_ikit_claw_1"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh2_dlc12_skv_cha_ikit_claw_2"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh2_dlc12_skv_cha_warlock_master_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_dlc12_skv_cha_warlock_master_1"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh2_dlc12_skv_cha_warlock_master_2"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh2_dlc12_skv_inf_clanrats_ror_0"] = "melee|inf_melee|inf_mel|0",
    ["wh2_dlc12_skv_inf_plague_monk_censer_bearer_ror_0"] = "melee|inf_melee|inf_mel|0",
    ["wh2_dlc12_skv_inf_ratling_gun_0"] = "ranged_direct|inf_ranged|inf_mis|0",
    ["wh2_dlc12_skv_inf_ratling_gun_ror_0"] = "ranged_direct|inf_ranged|inf_mis|0",
    ["wh2_dlc12_skv_inf_ratling_gun_ror_tech_lab_0"] = "ranged_direct|inf_ranged|inf_mis|0",
    ["wh2_dlc12_skv_inf_stormvermin_ror_0"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh2_dlc12_skv_inf_warpfire_thrower_ror_tech_lab_0"] = "ranged_direct|inf_ranged|inf_mis|0",
    ["wh2_dlc12_skv_inf_warplock_jezzails_0"] = "ranged_direct|inf_ranged|inf_mis|0",
    ["wh2_dlc12_skv_inf_warplock_jezzails_ror_0"] = "ranged_direct|inf_ranged|inf_mis|0",
    ["wh2_dlc12_skv_veh_doom_flayer_0"] = "melee_flanker_shock|war_machine|chariot|1",
    ["wh2_dlc12_skv_veh_doom_flayer_ror_0"] = "melee_flanker_shock|war_machine|chariot|1",
    ["wh2_dlc12_skv_veh_doom_flayer_ror_tech_lab_0"] = "melee_flanker_shock|war_machine|chariot|1",
    ["wh2_dlc12_skv_veh_doomwheel_ror_0"] = "melee_flanker_shock|war_machine|chariot|1",
    ["wh2_dlc12_skv_veh_doomwheel_ror_tech_lab_0"] = "melee_flanker_shock|war_machine|chariot|1",
    ["wh2_dlc13_emp_art_mortar_ror_0"] = "ranged_indirect_arty|artillery|art_fld|0",
    ["wh2_dlc13_emp_cav_empire_knights_ror_0"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh2_dlc13_emp_cav_empire_knights_ror_1"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh2_dlc13_emp_cav_empire_knights_ror_2"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh2_dlc13_emp_cav_outriders_ror_0"] = "ranged_direct_flanker_harasser|cavalry|cav_mis|1",
    ["wh2_dlc13_emp_cav_pistoliers_ror_0"] = "ranged_direct_flanker_harasser|cavalry|cav_mis|1",
    ["wh2_dlc13_emp_cha_hunter_doctor_hertwig_van_hal_0"] = "ranged_highvalue|inf_ranged|com|0",
    ["wh2_dlc13_emp_cha_hunter_jorek_grimm_0"] = "ranged_highvalue|inf_ranged|com|0",
    ["wh2_dlc13_emp_cha_hunter_kalara_of_wydrioth_0"] = "ranged_stalkers_harasser_highvalue|inf_ranged|com|0",
    ["wh2_dlc13_emp_cha_hunter_rodrik_l_anguille_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_dlc13_emp_cha_huntsmarshal_0"] = "hybrid_highvalue|inf_ranged|com|0",
    ["wh2_dlc13_emp_cha_markus_wulfhart_0"] = "hybrid_highvalue|inf_ranged|com|0",
    ["wh2_dlc13_emp_inf_archers_0"] = "ranged|inf_ranged|inf_mis|0",
    ["wh2_dlc13_emp_inf_archers_ror_0"] = "ranged|inf_ranged|inf_mis|0",
    ["wh2_dlc13_emp_inf_crossbowmen_ror_0"] = "ranged|inf_ranged|inf_mis|0",
    ["wh2_dlc13_emp_inf_greatswords_ror_0"] = "melee|inf_melee|inf_mel|0",
    ["wh2_dlc13_emp_inf_halberdiers_ror_0"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh2_dlc13_emp_inf_handgunners_ror_0"] = "ranged_direct|inf_ranged|inf_mis|0",
    ["wh2_dlc13_emp_inf_huntsmen_0"] = "ranged|inf_ranged|inf_mis|0",
    ["wh2_dlc13_emp_inf_huntsmen_ror_0"] = "ranged|inf_ranged|inf_mis|0",
    ["wh2_dlc13_emp_inf_spearmen_ror_0"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh2_dlc13_emp_inf_swordsmen_ror_0"] = "melee|inf_melee|inf_mel|0",
    ["wh2_dlc13_emp_veh_steam_tank_driver_ror_0"] = "hybrid_direct_shock_arty|war_machine|chariot|1",
    ["wh2_dlc13_emp_veh_war_wagon_0"] = "ranged_harasser_undead|war_machine|chariot|1",
    ["wh2_dlc13_emp_veh_war_wagon_1"] = "ranged_harasser_undead|war_machine|chariot|1",
    ["wh2_dlc13_emp_veh_war_wagon_ror_0"] = "ranged_harasser_undead|war_machine|chariot|1",
    ["wh2_dlc13_huntmarshall_veh_obsinite_gyrocopter_0"] = "gyrocopter|inf_ranged|inf_mis|1",
    ["wh2_dlc13_lzd_cha_gor_rok_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_dlc13_lzd_cha_kroxigor_ancient_0"] = "melee_highvalue|inf_melee|com|1",
    ["wh2_dlc13_lzd_cha_nakai_0"] = "melee_highvalue|inf_melee|com|1",
    ["wh2_dlc13_lzd_cha_slann_mage_priest_beasts_0"] = "mage_highvalue|war_machine|com|1",
    ["wh2_dlc13_lzd_cha_slann_mage_priest_death_0"] = "mage_highvalue|war_machine|com|1",
    ["wh2_dlc13_lzd_cha_slann_mage_priest_fire_0"] = "mage_highvalue|war_machine|com|1",
    ["wh2_dlc13_lzd_cha_slann_mage_priest_life_0"] = "mage_highvalue|war_machine|com|1",
    ["wh2_dlc13_lzd_cha_slann_mage_priest_metal_0"] = "mage_highvalue|war_machine|com|1",
    ["wh2_dlc13_lzd_cha_slann_mage_priest_shadows_0"] = "mage_highvalue|war_machine|com|1",
    ["wh2_dlc13_lzd_mon_dread_saurian_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh2_dlc13_lzd_mon_dread_saurian_1"] = "hybrid_gatecrusher|war_beast|inf_mel|1",
    ["wh2_dlc13_lzd_mon_dread_saurian_ror_0"] = "hybrid_gatecrusher|war_beast|inf_mel|1",
    ["wh2_dlc13_lzd_mon_razordon_pack_0"] = "ranged_harasser|inf_ranged|inf_mis|1",
    ["wh2_dlc13_lzd_mon_razordon_pack_0_blessed"] = "ranged_harasser|inf_ranged|inf_mis|1",
    ["wh2_dlc13_lzd_mon_razordon_pack_ror_0"] = "ranged_harasser|inf_ranged|inf_mis|1",
    ["wh2_dlc13_lzd_mon_razordon_pack_summoned_0"] = "ranged_harasser|inf_ranged|inf_mis|1",
    ["wh2_dlc13_lzd_mon_sacred_kroxigors_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh2_dlc13_lzd_mon_sacred_kroxigors_0_blessed"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh2_dlc13_lzd_mon_sacred_kroxigors_ror_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh2_dlc14_brt_cha_henri_le_massif_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_dlc14_brt_cha_henri_le_massif_3"] = "flying_melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh2_dlc14_brt_cha_henri_le_massif_4"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh2_dlc14_brt_cha_repanse_de_lyonesse_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_dlc14_brt_cha_repanse_de_lyonesse_1"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh2_dlc14_def_cav_scourgerunner_chariot_0"] = "ranged_harasser_flanker|war_machine|chariot|1",
    ["wh2_dlc14_def_cav_scourgerunner_chariot_ror_0"] = "ranged_harasser_flanker|war_machine|chariot|1",
    ["wh2_dlc14_def_cha_high_beastmaster_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_dlc14_def_cha_high_beastmaster_1"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh2_dlc14_def_cha_high_beastmaster_2"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh2_dlc14_def_cha_malus_darkblade_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_dlc14_def_cha_malus_darkblade_0_mp"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_dlc14_def_cha_malus_darkblade_1"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh2_dlc14_def_cha_malus_darkblade_1_mp"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh2_dlc14_def_cha_malus_darkblade_tzarkan_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_dlc14_def_cha_malus_darkblade_tzarkan_0_final_battle"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_dlc14_def_cha_malus_darkblade_tzarkan_1"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh2_dlc14_def_cha_master_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_dlc14_def_cha_master_1"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh2_dlc14_def_cha_master_2"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh2_dlc14_def_cha_master_3"] = "flying_melee_highvalue|cavalry|com|1",
    ["wh2_dlc14_def_cha_master_4"] = "hybrid_flanker_shock_harasser|war_machine|com|1",
    ["wh2_dlc14_def_inf_harpies_ror_0"] = "flying_melee_flanker|inf_melee|inf_mel|0",
    ["wh2_dlc14_def_mon_bloodwrack_medusa_0"] = "ranged_direct_highvalue|inf_melee|inf_mel|1",
    ["wh2_dlc14_def_mon_bloodwrack_medusa_ror_0"] = "ranged_direct_highvalue|inf_melee|inf_mel|1",
    ["wh2_dlc14_def_veh_bloodwrack_shrine_0"] = "melee_cav|war_machine|chariot|1",
    ["wh2_dlc14_skv_cha_deathmaster_snikch_0"] = "melee_flanker_shock_highvalue|inf_melee|com|0",
    ["wh2_dlc14_skv_cha_deathmaster_snikch_tzarkan_0"] = "melee_flanker_shock_highvalue|inf_melee|com|0",
    ["wh2_dlc14_skv_cha_eshin_sorcerer_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc14_skv_cha_master_assassin_0"] = "ranged_stalkers_harasser_highvalue|inf_ranged|com|0",
    ["wh2_dlc14_skv_inf_death_runners_ror_0"] = "melee_stalkers_flankers|inf_melee|inf_mel|0",
    ["wh2_dlc14_skv_inf_eshin_triads_0"] = "melee_stalkers_flankers|inf_melee|inf_mel|0",
    ["wh2_dlc14_skv_inf_eshin_triads_ror_0"] = "melee_stalkers_flankers|inf_melee|inf_mel|0",
    ["wh2_dlc14_skv_inf_eshin_triads_ror_summoned_0"] = "melee|inf_melee|inf_mel|0",
    ["wh2_dlc14_skv_inf_poison_wind_mortar_0"] = "ranged|inf_ranged|inf_mis|0",
    ["wh2_dlc14_skv_inf_poison_wind_mortar_ror_0"] = "ranged|inf_ranged|inf_mis|0",
    ["wh2_dlc14_skv_inf_stormvermin_1_summoned"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh2_dlc14_skv_inf_warp_grinder_0"] = "melee_gatecrusher_highvalue|inf_melee|inf_mel|0",
    ["wh2_dlc15_grn_cav_forest_goblin_spider_riders_waaagh_0"] = "ranged_harasser_flanker|cavalry|cav_mis|1",
    ["wh2_dlc15_grn_cav_squig_hoppers_waaagh_0"] = "melee_cav|cavalry|cav_mel|1",
    ["wh2_dlc15_grn_cha_grom_the_paunch_0"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh2_dlc15_grn_cha_night_goblin_warboss_0_big"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_dlc15_grn_cha_river_troll_hag_0"] = "mage_highvalue|inf_melee|com|1",
    ["wh2_dlc15_grn_mon_arachnarok_spider_waaagh_0"] = "melee_gatecrusher|war_beast|inf_mel|1",
    ["wh2_dlc15_grn_mon_feral_hydra_waaagh_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh2_dlc15_grn_mon_river_trolls_0"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh2_dlc15_grn_mon_river_trolls_ror_0"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh2_dlc15_grn_mon_rogue_idol_0"] = "melee_gatecrusher_highvalue|inf_melee|inf_mel|1",
    ["wh2_dlc15_grn_mon_rogue_idol_ror_0"] = "melee_gatecrusher_highvalue|inf_melee|inf_mel|1",
    ["wh2_dlc15_grn_mon_rogue_idol_summoned_0"] = "melee_gatecrusher_highvalue|inf_melee|inf_mel|1",
    ["wh2_dlc15_grn_mon_stone_trolls_0"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh2_dlc15_grn_mon_wyvern_waaagh_0"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh2_dlc15_grn_veh_snotling_pump_wagon_0"] = "melee_flanker_shock|war_machine|chariot|1",
    ["wh2_dlc15_grn_veh_snotling_pump_wagon_flappas_0"] = "melee_flanker_shock|war_machine|chariot|1",
    ["wh2_dlc15_grn_veh_snotling_pump_wagon_roller_0"] = "melee_flanker_shock|war_machine|chariot|1",
    ["wh2_dlc15_grn_veh_snotling_pump_wagon_ror_0"] = "melee_flanker_shock|war_machine|chariot|1",
    ["wh2_dlc15_hef_cha_alastar_1"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh2_dlc15_hef_cha_archmage_beasts_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc15_hef_cha_archmage_beasts_1"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc15_hef_cha_archmage_beasts_2"] = "mage_highvalue|war_machine|com|1",
    ["wh2_dlc15_hef_cha_archmage_beasts_3"] = "flying_hybrid_highvalue|war_beast|com|1",
    ["wh2_dlc15_hef_cha_archmage_beasts_4"] = "flying_melee_mage_highvalue|war_beast|com|1",
    ["wh2_dlc15_hef_cha_archmage_death_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc15_hef_cha_archmage_death_1"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc15_hef_cha_archmage_death_2"] = "mage_highvalue|war_machine|com|1",
    ["wh2_dlc15_hef_cha_archmage_death_3"] = "flying_hybrid_highvalue|war_beast|com|1",
    ["wh2_dlc15_hef_cha_archmage_death_4"] = "flying_melee_mage_highvalue|war_beast|com|1",
    ["wh2_dlc15_hef_cha_archmage_fire_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc15_hef_cha_archmage_fire_1"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc15_hef_cha_archmage_fire_2"] = "mage_highvalue|war_machine|com|1",
    ["wh2_dlc15_hef_cha_archmage_fire_3"] = "flying_hybrid_highvalue|war_beast|com|1",
    ["wh2_dlc15_hef_cha_archmage_fire_4"] = "flying_melee_mage_highvalue|war_beast|com|1",
    ["wh2_dlc15_hef_cha_archmage_heavens_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc15_hef_cha_archmage_heavens_1"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc15_hef_cha_archmage_heavens_2"] = "mage_highvalue|war_machine|com|1",
    ["wh2_dlc15_hef_cha_archmage_heavens_3"] = "flying_hybrid_highvalue|war_beast|com|1",
    ["wh2_dlc15_hef_cha_archmage_heavens_4"] = "flying_melee_mage_highvalue|war_beast|com|1",
    ["wh2_dlc15_hef_cha_archmage_high_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc15_hef_cha_archmage_high_1"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc15_hef_cha_archmage_high_2"] = "mage_highvalue|war_machine|com|1",
    ["wh2_dlc15_hef_cha_archmage_high_3"] = "flying_hybrid_highvalue|war_beast|com|1",
    ["wh2_dlc15_hef_cha_archmage_high_4"] = "flying_melee_mage_highvalue|war_beast|com|1",
    ["wh2_dlc15_hef_cha_archmage_life_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc15_hef_cha_archmage_life_1"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc15_hef_cha_archmage_life_2"] = "mage_highvalue|war_machine|com|1",
    ["wh2_dlc15_hef_cha_archmage_life_3"] = "flying_hybrid_highvalue|war_beast|com|1",
    ["wh2_dlc15_hef_cha_archmage_life_4"] = "flying_melee_mage_highvalue|war_beast|com|1",
    ["wh2_dlc15_hef_cha_archmage_light_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc15_hef_cha_archmage_light_1"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc15_hef_cha_archmage_light_2"] = "mage_highvalue|war_machine|com|1",
    ["wh2_dlc15_hef_cha_archmage_light_3"] = "flying_hybrid_highvalue|war_beast|com|1",
    ["wh2_dlc15_hef_cha_archmage_light_4"] = "flying_melee_mage_highvalue|war_beast|com|1",
    ["wh2_dlc15_hef_cha_archmage_metal_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc15_hef_cha_archmage_metal_1"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc15_hef_cha_archmage_metal_2"] = "mage_highvalue|war_machine|com|1",
    ["wh2_dlc15_hef_cha_archmage_metal_3"] = "flying_hybrid_highvalue|war_beast|com|1",
    ["wh2_dlc15_hef_cha_archmage_metal_4"] = "flying_melee_mage_highvalue|war_beast|com|1",
    ["wh2_dlc15_hef_cha_archmage_shadows_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc15_hef_cha_archmage_shadows_1"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc15_hef_cha_archmage_shadows_2"] = "mage_highvalue|war_machine|com|1",
    ["wh2_dlc15_hef_cha_archmage_shadows_3"] = "flying_hybrid_highvalue|war_beast|com|1",
    ["wh2_dlc15_hef_cha_archmage_shadows_4"] = "flying_melee_mage_highvalue|war_beast|com|1",
    ["wh2_dlc15_hef_cha_eltharion_the_grim_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_dlc15_hef_cha_eltharion_the_grim_1"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh2_dlc15_hef_cha_eltharion_the_grim_2"] = "flying_melee_shock_highvalue|war_beast|com|1",
    ["wh2_dlc15_hef_cha_imrik_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_dlc15_hef_cha_imrik_1"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh2_dlc15_hef_cha_imrik_2"] = "flying_melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh2_dlc15_hef_cha_mage_beasts_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc15_hef_cha_mage_beasts_1"] = "mage_flanker_highvalue|cavalry|com|1",
    ["wh2_dlc15_hef_cha_mage_beasts_2"] = "mage_highvalue|war_machine|com|1",
    ["wh2_dlc15_hef_cha_mage_death_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc15_hef_cha_mage_death_1"] = "mage_flanker_highvalue|cavalry|com|1",
    ["wh2_dlc15_hef_cha_mage_death_2"] = "mage_highvalue|war_machine|com|1",
    ["wh2_dlc15_hef_cha_mage_fire_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc15_hef_cha_mage_fire_1"] = "mage_flanker_highvalue|cavalry|com|1",
    ["wh2_dlc15_hef_cha_mage_fire_2"] = "mage_highvalue|war_machine|com|1",
    ["wh2_dlc15_hef_cha_mage_fire_3"] = "flying_melee_mage_highvalue|war_beast|com|1",
    ["wh2_dlc15_hef_cha_mage_metal_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc15_hef_cha_mage_metal_1"] = "mage_flanker_highvalue|cavalry|com|1",
    ["wh2_dlc15_hef_cha_mage_metal_2"] = "mage_highvalue|war_machine|com|1",
    ["wh2_dlc15_hef_cha_prince_6"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh2_dlc15_hef_cha_princess_6"] = "flying_hybrid_highvalue|war_beast|com|1",
    ["wh2_dlc15_hef_cha_teclis_2"] = "flying_melee_mage_highvalue|war_beast|com|1",
    ["wh2_dlc15_hef_inf_archers_ror_0"] = "ranged|inf_ranged|inf_mis|0",
    ["wh2_dlc15_hef_inf_mistwalkers_faithbearers_0"] = "melee|inf_melee|inf_mel|0",
    ["wh2_dlc15_hef_inf_mistwalkers_griffon_knights_0"] = "flying_melee_highvalue|war_beast|cav_shk|1",
    ["wh2_dlc15_hef_inf_mistwalkers_sentinels_0"] = "ranged_no_skirmish|inf_ranged|inf_mis|0",
    ["wh2_dlc15_hef_inf_mistwalkers_skyhawks_0"] = "ranged_harasser_flanker|inf_ranged|inf_mis|0",
    ["wh2_dlc15_hef_inf_mistwalkers_spireguard_0"] = "ranged_harasser_flanker|inf_ranged|inf_mis|0",
    ["wh2_dlc15_hef_inf_rangers_0"] = "melee|inf_melee|inf_mel|0",
    ["wh2_dlc15_hef_inf_silverin_guard_0"] = "melee|inf_melee|inf_mel|0",
    ["wh2_dlc15_hef_mon_arcane_phoenix_0"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh2_dlc15_hef_mon_arcane_phoenix_ror_0"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh2_dlc15_hef_mon_black_dragon_imrik"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh2_dlc15_hef_mon_black_dragon_imrik_boss"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh2_dlc15_hef_mon_forest_dragon_0"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh2_dlc15_hef_mon_forest_dragon_imrik"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh2_dlc15_hef_mon_forest_dragon_imrik_boss"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh2_dlc15_hef_mon_moon_dragon_imrik"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh2_dlc15_hef_mon_moon_dragon_imrik_boss"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh2_dlc15_hef_mon_star_dragon_imrik"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh2_dlc15_hef_mon_star_dragon_imrik_boss"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh2_dlc15_hef_mon_sun_dragon_imrik"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh2_dlc15_hef_mon_sun_dragon_imrik_boss"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh2_dlc15_hef_mon_war_lions_of_chrace_0"] = "melee_flanker|inf_melee|inf_mel|1",
    ["wh2_dlc15_hef_mon_war_lions_of_chrace_ror_0"] = "melee_flanker|inf_melee|inf_mel|1",
    ["wh2_dlc15_hef_veh_lion_chariot_of_chrace_0"] = "melee_flanker_shock|war_machine|chariot|1",
    ["wh2_dlc16_skv_cha_chieftain_0"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh2_dlc16_skv_cha_chieftain_1"] = "melee_highvalue|war_beast|com|1",
    ["wh2_dlc16_skv_cha_ghoritch_0"] = "melee_highvalue|inf_melee|com|1",
    ["wh2_dlc16_skv_cha_ghoritch_0_boss"] = "melee_highvalue|inf_melee|com|1",
    ["wh2_dlc16_skv_cha_packmaster_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_dlc16_skv_cha_packmaster_2"] = "melee_highvalue|cavalry|com|1",
    ["wh2_dlc16_skv_cha_throt_the_unclean_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_dlc16_skv_cha_throt_the_unclean_2"] = "melee_highvalue|cavalry|com|1",
    ["wh2_dlc16_skv_cha_warlord_2"] = "melee_highvalue|cavalry|com|1",
    ["wh2_dlc16_skv_mon_brood_horror_0"] = "melee_gatecrusher_flanker|inf_melee|inf_mel|1",
    ["wh2_dlc16_skv_mon_hell_pit_abomination_ror_0"] = "melee|inf_melee|inf_mel|1",
    ["wh2_dlc16_skv_mon_rat_ogre_mutant"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh2_dlc16_skv_mon_rat_ogre_mutant_ror_0"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh2_dlc16_skv_mon_rat_ogres_ror_0"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh2_dlc16_skv_mon_rat_ogres_summoned"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh2_dlc16_skv_mon_wolf_rats_0"] = "melee_flanker|inf_melee|inf_mel|0",
    ["wh2_dlc16_skv_mon_wolf_rats_0_summoned"] = "melee_flanker|inf_melee|inf_mel|0",
    ["wh2_dlc16_skv_mon_wolf_rats_1"] = "melee_flanker|inf_melee|inf_mel|0",
    ["wh2_dlc16_skv_mon_wolf_rats_1_summoned"] = "melee_flanker|inf_melee|inf_mel|0",
    ["wh2_dlc16_wef_cav_glade_riders_2"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh2_dlc16_wef_cav_great_stag_knights_0"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh2_dlc16_wef_cav_great_stag_knights_ror_0"] = "melee_flanker_shock|cavalry|cav_shk|0",
    ["wh2_dlc16_wef_cha_ancient_treeman_coeddil_0"] = "melee_gatecrusher_highvalue|inf_melee|com|1",
    ["wh2_dlc16_wef_cha_ariel_0"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh2_dlc16_wef_cha_drycha_0"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh2_dlc16_wef_cha_female_glade_lord_4"] = "ranged_cav_highvalue|cavalry|com|1",
    ["wh2_dlc16_wef_cha_glade_lord_4"] = "ranged_cav_highvalue|cavalry|com|1",
    ["wh2_dlc16_wef_cha_malicious_ancient_treeman_beasts_0"] = "melee_gatecrusher_highvalue|inf_melee|com|1",
    ["wh2_dlc16_wef_cha_malicious_ancient_treeman_life_0"] = "melee_gatecrusher_highvalue|inf_melee|com|1",
    ["wh2_dlc16_wef_cha_malicious_ancient_treeman_shadows_0"] = "melee_gatecrusher_highvalue|inf_melee|com|1",
    ["wh2_dlc16_wef_cha_malicious_branchwraith_beasts_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc16_wef_cha_malicious_branchwraith_life_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc16_wef_cha_malicious_branchwraith_shadows_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc16_wef_cha_sisters_of_twilight_0"] = "flying_hybrid_highvalue|war_beast|com|1",
    ["wh2_dlc16_wef_cha_sisters_of_twilight_1"] = "flying_hybrid_highvalue|war_beast|com|1",
    ["wh2_dlc16_wef_cha_spellweaver_beasts_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc16_wef_cha_spellweaver_beasts_1"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc16_wef_cha_spellweaver_beasts_2"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc16_wef_cha_spellweaver_beasts_3"] = "mage_highvalue|war_beast|com|1",
    ["wh2_dlc16_wef_cha_spellweaver_dark_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc16_wef_cha_spellweaver_dark_1"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc16_wef_cha_spellweaver_dark_2"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc16_wef_cha_spellweaver_dark_3"] = "flying_mage_highvalue|war_beast|com|1",
    ["wh2_dlc16_wef_cha_spellweaver_high_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc16_wef_cha_spellweaver_high_1"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc16_wef_cha_spellweaver_high_2"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc16_wef_cha_spellweaver_high_3"] = "flying_mage_highvalue|war_beast|com|1",
    ["wh2_dlc16_wef_cha_spellweaver_life_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc16_wef_cha_spellweaver_life_1"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc16_wef_cha_spellweaver_life_2"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc16_wef_cha_spellweaver_life_3"] = "flying_mage_highvalue|war_beast|com|1",
    ["wh2_dlc16_wef_cha_spellweaver_shadows_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_dlc16_wef_cha_spellweaver_shadows_1"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc16_wef_cha_spellweaver_shadows_2"] = "mage_highvalue|cavalry|com|1",
    ["wh2_dlc16_wef_cha_spellweaver_shadows_3"] = "flying_mage_highvalue|war_beast|com|1",
    ["wh2_dlc16_wef_inf_bladesingers_0"] = "melee|inf_melee|inf_mel|0",
    ["wh2_dlc16_wef_inf_dryads_0_summoned"] = "melee|inf_melee|inf_mel|0",
    ["wh2_dlc16_wef_inf_dryads_ror_0"] = "melee|inf_melee|inf_mel|0",
    ["wh2_dlc16_wef_inf_malicious_dryads_0"] = "melee|inf_melee|inf_mel|0",
    ["wh2_dlc16_wef_mon_cave_bats"] = "flying_melee_flanker_undead|inf_melee|inf_mel|0",
    ["wh2_dlc16_wef_mon_ceithin_har_summoned"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh2_dlc16_wef_mon_feral_manticore"] = "flying_melee_highvalue|inf_melee|inf_mel|1",
    ["wh2_dlc16_wef_mon_giant_spiders_0"] = "melee_flanker|inf_melee|inf_mel|1",
    ["wh2_dlc16_wef_mon_gwindalor_summoned"] = "flying_melee_flanker_shock|inf_melee|inf_mel|1",
    ["wh2_dlc16_wef_mon_harpies_0"] = "flying_melee_flanker|inf_melee|inf_mel|0",
    ["wh2_dlc16_wef_mon_hawks_0"] = "flying_melee_flanker_shock|inf_melee|inf_mel|1",
    ["wh2_dlc16_wef_mon_malicious_treekin_0"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh2_dlc16_wef_mon_malicious_treeman_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh2_dlc16_wef_mon_spider_hatchlings_0"] = "melee_flanker|inf_melee|inf_mel|0",
    ["wh2_dlc16_wef_mon_wolves_0"] = "melee_flanker|inf_melee|inf_mel|0",
    ["wh2_dlc16_wef_mon_zoats"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh2_dlc16_wef_mon_zoats_ror_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh2_dlc17_bst_cav_tuskgor_chariot_0"] = "melee_flanker_shock|war_machine|chariot|1",
    ["wh2_dlc17_bst_cha_beastlord_2"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh2_dlc17_bst_cha_bray_shaman_beasts_2"] = "mage_highvalue|war_machine|com|1",
    ["wh2_dlc17_bst_cha_bray_shaman_death_2"] = "mage_highvalue|war_machine|com|1",
    ["wh2_dlc17_bst_cha_bray_shaman_shadows_2"] = "mage_highvalue|war_machine|com|1",
    ["wh2_dlc17_bst_cha_bray_shaman_wild_2"] = "mage_highvalue|war_machine|com|1",
    ["wh2_dlc17_bst_cha_doombull_0"] = "melee_highvalue|inf_melee|com|1",
    ["wh2_dlc17_bst_cha_khazrak_one_eye_2"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh2_dlc17_bst_cha_taurox_the_brass_bull_0"] = "melee_highvalue|inf_melee|com|1",
    ["wh2_dlc17_bst_cha_wargor_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_dlc17_bst_cha_wargor_1"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh2_dlc17_bst_cha_wargor_2"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh2_dlc17_bst_inf_centigors_ror_1"] = "ranged_flanker|inf_ranged|inf_mis|1",
    ["wh2_dlc17_bst_mon_ghorgon_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh2_dlc17_bst_mon_ghorgon_boss_0"] = "melee_gatecrusher_highvalue|inf_melee|inf_mel|1",
    ["wh2_dlc17_bst_mon_ghorgon_ror_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh2_dlc17_bst_mon_jabberslythe_0"] = "melee_highvalue|inf_melee|inf_mel|1",
    ["wh2_dlc17_bst_mon_jabberslythe_ror_0"] = "melee_highvalue|inf_melee|inf_mel|1",
    ["wh2_dlc17_dwf_cha_thane_ghost_2"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_dlc17_dwf_cha_thorek_ironbrow_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_dlc17_dwf_cha_thorek_ironbrow_1"] = "melee_highvalue|inf_melee|com|1",
    ["wh2_dlc17_dwf_mon_carnosaur_thorek_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh2_dlc17_emp_inf_prisoners_0"] = "melee|inf_melee|inf_mel|0",
    ["wh2_dlc17_lzd_cha_oxyotl_0"] = "ranged_harasser_highvalue|inf_ranged|com|0",
    ["wh2_dlc17_lzd_cha_skink_oracle_troglodon_0"] = "hybrid_mage_highvalue|war_beast|com|1",
    ["wh2_dlc17_lzd_inf_chameleon_stalkers_0"] = "melee_stalkers_flankers|inf_melee|inf_mel|0",
    ["wh2_dlc17_lzd_inf_chameleon_stalkers_0_blessed"] = "melee_stalkers_flankers|inf_melee|inf_mel|0",
    ["wh2_dlc17_lzd_mon_carnosaur_ror_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh2_dlc17_lzd_mon_coatl_0"] = "flying_melee_mage_highvalue|inf_melee|inf_mel|1",
    ["wh2_dlc17_lzd_mon_coatl_ror_0"] = "flying_melee_mage_highvalue|inf_melee|inf_mel|1",
    ["wh2_dlc17_lzd_mon_dread_saurian_qb_boss"] = "hybrid_gatecrusher|inf_melee|inf_mel|1",
    ["wh2_dlc17_lzd_mon_troglodon_0"] = "hybrid_highvalue|inf_melee|inf_mel|1",
    ["wh2_dlc17_lzd_mon_troglodon_ror_0"] = "hybrid_highvalue|inf_melee|inf_mel|1",
    ["wh2_main_def_art_reaper_bolt_thrower"] = "ranged_direct_arty|artillery|art_fld|0",
    ["wh2_main_def_cav_cold_one_chariot"] = "hybrid_flanker_shock_harasser|war_machine|chariot|1",
    ["wh2_main_def_cav_cold_one_knights_0"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh2_main_def_cav_cold_one_knights_1"] = "melee_flanker|cavalry|cav_mel|1",
    ["wh2_main_def_cav_dark_riders_0"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh2_main_def_cav_dark_riders_1"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh2_main_def_cav_dark_riders_2"] = "ranged_harasser_flanker|cavalry|cav_mis|1",
    ["wh2_main_def_cha_death_hag_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_main_def_cha_death_hag_1"] = "melee_highvalue|war_machine|com|1",
    ["wh2_main_def_cha_dreadlord_0"] = "hybrid_highvalue|inf_ranged|com|0",
    ["wh2_main_def_cha_dreadlord_1"] = "hybrid_cav_highvalue|cavalry|com|1",
    ["wh2_main_def_cha_dreadlord_2"] = "hybrid_cav_highvalue|cavalry|com|1",
    ["wh2_main_def_cha_dreadlord_4"] = "flying_hybrid_highvalue|war_beast|com|1",
    ["wh2_main_def_cha_dreadlord_5"] = "flying_hybrid_highvalue|cavalry|com|1",
    ["wh2_main_def_cha_dreadlord_female_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_main_def_cha_dreadlord_female_1"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh2_main_def_cha_dreadlord_female_2"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh2_main_def_cha_dreadlord_female_4"] = "flying_melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh2_main_def_cha_dreadlord_female_5"] = "flying_melee_highvalue|cavalry|com|1",
    ["wh2_main_def_cha_khainite_assassin_0"] = "melee_gatecrusher_highvalue|inf_ranged|com|0",
    ["wh2_main_def_cha_malekith_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_main_def_cha_malekith_1"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh2_main_def_cha_malekith_2"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh2_main_def_cha_malekith_3"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh2_main_def_cha_morathi_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_main_def_cha_morathi_1"] = "flying_melee_mage_highvalue|cavalry|com|1",
    ["wh2_main_def_cha_sorceress_dark_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_main_def_cha_sorceress_dark_1"] = "mage_highvalue|cavalry|com|1",
    ["wh2_main_def_cha_sorceress_dark_2"] = "mage_highvalue|cavalry|com|1",
    ["wh2_main_def_cha_sorceress_dark_3"] = "flying_mage_highvalue|cavalry|com|1",
    ["wh2_main_def_cha_sorceress_fire_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_main_def_cha_sorceress_fire_1"] = "mage_highvalue|cavalry|com|1",
    ["wh2_main_def_cha_sorceress_fire_2"] = "mage_highvalue|cavalry|com|1",
    ["wh2_main_def_cha_sorceress_fire_3"] = "flying_mage_highvalue|cavalry|com|1",
    ["wh2_main_def_cha_sorceress_shadow_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_main_def_cha_sorceress_shadow_1"] = "mage_highvalue|cavalry|com|1",
    ["wh2_main_def_cha_sorceress_shadow_2"] = "mage_highvalue|cavalry|com|1",
    ["wh2_main_def_cha_sorceress_shadow_3"] = "flying_mage_highvalue|cavalry|com|1",
    ["wh2_main_def_inf_black_ark_corsairs_0"] = "melee|inf_melee|inf_mel|0",
    ["wh2_main_def_inf_black_ark_corsairs_1"] = "ranged_harasser|inf_ranged|inf_mis|0",
    ["wh2_main_def_inf_black_guard_0"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh2_main_def_inf_bleakswords_0"] = "melee|inf_melee|inf_mel|0",
    ["wh2_main_def_inf_darkshards_0"] = "ranged|inf_ranged|inf_mis|0",
    ["wh2_main_def_inf_darkshards_1"] = "ranged|inf_ranged|inf_mis|0",
    ["wh2_main_def_inf_dreadspears_0"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh2_main_def_inf_har_ganeth_executioners_0"] = "melee|inf_melee|inf_mel|0",
    ["wh2_main_def_inf_harpies"] = "flying_melee_flanker|inf_melee|inf_mel|0",
    ["wh2_main_def_inf_shades_0"] = "ranged_stalkers_harasser|inf_ranged|inf_mis|0",
    ["wh2_main_def_inf_shades_1"] = "ranged_stalkers_harasser|inf_ranged|inf_mis|0",
    ["wh2_main_def_inf_shades_2"] = "ranged_stalkers_harasser|inf_ranged|inf_mis|0",
    ["wh2_main_def_inf_witch_elves_0"] = "melee_undead|inf_melee|inf_mel|0",
    ["wh2_main_def_mon_black_dragon"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh2_main_def_mon_war_hydra_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh2_main_hef_art_eagle_claw_bolt_thrower"] = "ranged_direct_arty|artillery|art_fld|0",
    ["wh2_main_hef_cav_dragon_princes"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh2_main_hef_cav_ellyrian_reavers_0"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh2_main_hef_cav_ellyrian_reavers_1"] = "ranged_harasser_flanker|cavalry|cav_mis|1",
    ["wh2_main_hef_cav_ithilmar_chariot"] = "melee_flanker_shock|war_machine|chariot|1",
    ["wh2_main_hef_cav_silver_helms_0"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh2_main_hef_cav_silver_helms_1"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh2_main_hef_cav_tiranoc_chariot"] = "ranged_cav_harasser|war_machine|chariot|1",
    ["wh2_main_hef_cha_alastar_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_main_hef_cha_alastar_3"] = "flying_melee_shock_highvalue|war_beast|com|1",
    ["wh2_main_hef_cha_alastar_4"] = "flying_melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh2_main_hef_cha_alastar_5"] = "flying_melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh2_main_hef_cha_loremaster_of_hoeth_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_main_hef_cha_mage_high_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_main_hef_cha_mage_high_1"] = "mage_flanker_highvalue|cavalry|com|1",
    ["wh2_main_hef_cha_mage_high_4"] = "mage_highvalue|war_machine|com|1",
    ["wh2_main_hef_cha_mage_life_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_main_hef_cha_mage_life_1"] = "mage_flanker_highvalue|cavalry|com|1",
    ["wh2_main_hef_cha_mage_life_4"] = "mage_highvalue|war_machine|com|1",
    ["wh2_main_hef_cha_mage_light_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_main_hef_cha_mage_light_1"] = "mage_flanker_highvalue|cavalry|com|1",
    ["wh2_main_hef_cha_mage_light_4"] = "mage_highvalue|war_machine|com|1",
    ["wh2_main_hef_cha_noble_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_main_hef_cha_noble_2"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh2_main_hef_cha_noble_3"] = "flying_melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh2_main_hef_cha_noble_4"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh2_main_hef_cha_prince_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_main_hef_cha_prince_2"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh2_main_hef_cha_prince_3"] = "flying_melee_shock_highvalue|war_beast|com|1",
    ["wh2_main_hef_cha_prince_4"] = "flying_melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh2_main_hef_cha_prince_5"] = "flying_melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh2_main_hef_cha_princess_0"] = "hybrid_highvalue|inf_ranged|com|0",
    ["wh2_main_hef_cha_princess_1"] = "hybrid_cav_highvalue|cavalry|com|1",
    ["wh2_main_hef_cha_princess_3"] = "flying_hybrid_highvalue|war_beast|com|1",
    ["wh2_main_hef_cha_princess_4"] = "flying_hybrid_highvalue|war_beast|com|1",
    ["wh2_main_hef_cha_princess_5"] = "flying_hybrid_highvalue|war_beast|com|1",
    ["wh2_main_hef_cha_teclis_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_main_hef_cha_teclis_1"] = "mage_highvalue|cavalry|com|1",
    ["wh2_main_hef_cha_tyrion_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_main_hef_cha_tyrion_1"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh2_main_hef_inf_archers_0"] = "ranged|inf_ranged|inf_mis|0",
    ["wh2_main_hef_inf_archers_1"] = "ranged|inf_ranged|inf_mis|0",
    ["wh2_main_hef_inf_gate_guard"] = "ranged_no_skirmish|inf_ranged|inf_mis|0",
    ["wh2_main_hef_inf_lothern_sea_guard_0"] = "hybrid_melee|inf_ranged|inf_mis|0",
    ["wh2_main_hef_inf_lothern_sea_guard_1"] = "hybrid_melee|inf_ranged|inf_mis|0",
    ["wh2_main_hef_inf_phoenix_guard"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh2_main_hef_inf_spearmen_0"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh2_main_hef_inf_swordmasters_of_hoeth_0"] = "melee|inf_melee|inf_mel|0",
    ["wh2_main_hef_inf_white_lions_of_chrace_0"] = "melee|inf_melee|inf_mel|0",
    ["wh2_main_hef_mon_great_eagle"] = "flying_melee_flanker_shock|inf_melee|inf_mel|1",
    ["wh2_main_hef_mon_great_eagle_summoned"] = "flying_melee_flanker_shock|inf_melee|inf_mel|1",
    ["wh2_main_hef_mon_moon_dragon"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh2_main_hef_mon_phoenix_flamespyre"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh2_main_hef_mon_phoenix_frostheart"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh2_main_hef_mon_star_dragon"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh2_main_hef_mon_sun_dragon"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh2_main_lzd_cav_cold_one_spearriders_1"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh2_main_lzd_cav_cold_one_spearriders_blessed_0"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh2_main_lzd_cav_cold_ones_1"] = "melee_flanker|cavalry|cav_mel|1",
    ["wh2_main_lzd_cav_cold_ones_feral_0"] = "melee_flanker|inf_melee|inf_mel|1",
    ["wh2_main_lzd_cav_cold_ones_feral_0_summoned"] = "melee_flanker|inf_melee|inf_mel|1",
    ["wh2_main_lzd_cav_horned_ones_0"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh2_main_lzd_cav_horned_ones_blessed_0"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh2_main_lzd_cav_terradon_riders_0"] = "flying_ranged_harasser_flanker|cavalry|cav_mis|1",
    ["wh2_main_lzd_cav_terradon_riders_0_blessed"] = "flying_ranged_harasser_flanker|cavalry|cav_mis|1",
    ["wh2_main_lzd_cav_terradon_riders_1"] = "flying_ranged_harasser_flanker|cavalry|cav_mis|1",
    ["wh2_main_lzd_cav_terradon_riders_blessed_1"] = "flying_ranged_harasser_flanker|cavalry|cav_mis|1",
    ["wh2_main_lzd_cha_kroq_gar_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_main_lzd_cha_kroq_gar_1"] = "melee_highvalue|war_beast|com|1",
    ["wh2_main_lzd_cha_kroq_gar_2"] = "melee_highvalue|cavalry|com|1",
    ["wh2_main_lzd_cha_kroq_gar_3"] = "melee_highvalue|cavalry|com|1",
    ["wh2_main_lzd_cha_lord_mazdamundi_0"] = "mage_highvalue|war_machine|com|1",
    ["wh2_main_lzd_cha_lord_mazdamundi_1"] = "melee_highvalue|war_beast|com|1",
    ["wh2_main_lzd_cha_saurus_old_blood_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_main_lzd_cha_saurus_old_blood_1"] = "melee_highvalue|cavalry|com|1",
    ["wh2_main_lzd_cha_saurus_old_blood_2"] = "melee_highvalue|war_beast|com|1",
    ["wh2_main_lzd_cha_saurus_scar_veteran_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_main_lzd_cha_saurus_scar_veteran_1"] = "melee_highvalue|cavalry|com|1",
    ["wh2_main_lzd_cha_saurus_scar_veteran_2"] = "melee_highvalue|war_beast|com|1",
    ["wh2_main_lzd_cha_skink_chief_0"] = "ranged_harasser_highvalue|inf_ranged|com|0",
    ["wh2_main_lzd_cha_skink_chief_1"] = "flying_ranged_harasser_flanker_highvalue|cavalry|com|1",
    ["wh2_main_lzd_cha_skink_chief_2"] = "ranged_no_skirmish_gatecrusher|war_beast|com|1",
    ["wh2_main_lzd_cha_skink_chief_3"] = "melee_gatecrusher_highvalue|war_beast|com|1",
    ["wh2_main_lzd_cha_skink_priest_0_summoned"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_main_lzd_cha_skink_priest_beasts_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_main_lzd_cha_skink_priest_beasts_1"] = "flying_mage_highvalue|cavalry|com|1",
    ["wh2_main_lzd_cha_skink_priest_beasts_2"] = "ranged_no_skirmish_gatecrusher|war_beast|com|1",
    ["wh2_main_lzd_cha_skink_priest_beasts_3"] = "melee_gatecrusher_highvalue|war_beast|com|1",
    ["wh2_main_lzd_cha_skink_priest_heavens_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_main_lzd_cha_skink_priest_heavens_1"] = "flying_mage_highvalue|cavalry|com|1",
    ["wh2_main_lzd_cha_skink_priest_heavens_2"] = "ranged_no_skirmish_gatecrusher|war_beast|com|1",
    ["wh2_main_lzd_cha_skink_priest_heavens_3"] = "melee_gatecrusher_highvalue|war_beast|com|1",
    ["wh2_main_lzd_cha_slann_mage_priest_campaign_0"] = "mage_highvalue|war_machine|com|1",
    ["wh2_main_lzd_cha_slann_mage_priest_heavens_0"] = "mage_highvalue|war_machine|com|1",
    ["wh2_main_lzd_cha_slann_mage_priest_high_0"] = "mage_highvalue|war_machine|com|1",
    ["wh2_main_lzd_cha_slann_mage_priest_life_0_qb"] = "mage_highvalue|war_machine|com|1",
    ["wh2_main_lzd_cha_slann_mage_priest_light_0"] = "mage_highvalue|war_machine|com|1",
    ["wh2_main_lzd_inf_chameleon_skinks_0"] = "ranged_stalkers_harasser|inf_ranged|inf_mis|0",
    ["wh2_main_lzd_inf_chameleon_skinks_blessed_0"] = "ranged_stalkers_harasser|inf_ranged|inf_mis|0",
    ["wh2_main_lzd_inf_saurus_spearmen_0"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh2_main_lzd_inf_saurus_spearmen_1"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh2_main_lzd_inf_saurus_spearmen_blessed_1"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh2_main_lzd_inf_saurus_warriors_0"] = "melee|inf_melee|inf_mel|0",
    ["wh2_main_lzd_inf_saurus_warriors_1"] = "melee|inf_melee|inf_mel|0",
    ["wh2_main_lzd_inf_saurus_warriors_blessed_1"] = "melee|inf_melee|inf_mel|0",
    ["wh2_main_lzd_inf_skink_cohort_0"] = "melee|inf_melee|inf_mel|0",
    ["wh2_main_lzd_inf_skink_cohort_1"] = "hybrid|inf_ranged|inf_mis|0",
    ["wh2_main_lzd_inf_skink_cohort_1_blessed"] = "hybrid|inf_ranged|inf_mis|0",
    ["wh2_main_lzd_inf_skink_skirmishers_0"] = "ranged_harasser|inf_ranged|inf_mis|0",
    ["wh2_main_lzd_inf_skink_skirmishers_blessed_0"] = "ranged_harasser|inf_ranged|inf_mis|0",
    ["wh2_main_lzd_inf_temple_guards"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh2_main_lzd_inf_temple_guards_blessed"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh2_main_lzd_mon_ancient_stegadon"] = "melee_gatecrusher_highvalue|war_beast|inf_mel|1",
    ["wh2_main_lzd_mon_ancient_stegadon_blessed"] = "melee_gatecrusher_highvalue|war_beast|inf_mel|1",
    ["wh2_main_lzd_mon_bastiladon_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh2_main_lzd_mon_bastiladon_1"] = "melee_passiveshooter_gatecrusher|war_beast|inf_mel|1",
    ["wh2_main_lzd_mon_bastiladon_2"] = "ranged_no_skirmish_gatecrusher|war_beast|inf_mis|1",
    ["wh2_main_lzd_mon_bastiladon_blessed_2"] = "ranged_no_skirmish_gatecrusher|war_beast|inf_mis|1",
    ["wh2_main_lzd_mon_carnosaur_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh2_main_lzd_mon_carnosaur_blessed_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh2_main_lzd_mon_kroxigors"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh2_main_lzd_mon_kroxigors_blessed"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh2_main_lzd_mon_stegadon_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh2_main_lzd_mon_stegadon_1"] = "melee_gatecrusher|war_beast|inf_mis|1",
    ["wh2_main_lzd_mon_stegadon_blessed_1"] = "melee_gatecrusher|war_beast|inf_mis|1",
    ["wh2_main_skv_art_plagueclaw_catapult"] = "ranged_indirect_arty|artillery|art_fld|0",
    ["wh2_main_skv_art_warp_lightning_cannon"] = "ranged_direct_arty|artillery|art_fld|0",
    ["wh2_main_skv_cha_assassin"] = "melee_flanker_shock_highvalue|inf_melee|com|0",
    ["wh2_main_skv_cha_grey_seer_plague_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_main_skv_cha_grey_seer_plague_1"] = "melee_highvalue|war_machine|com|1",
    ["wh2_main_skv_cha_grey_seer_ruin_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_main_skv_cha_grey_seer_ruin_1"] = "melee_highvalue|war_machine|com|1",
    ["wh2_main_skv_cha_lord_skrolk"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_main_skv_cha_plague_priest_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_main_skv_cha_plague_priest_2"] = "melee_highvalue|war_machine|com|1",
    ["wh2_main_skv_cha_queek_headtaker"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_main_skv_cha_warlock_engineer"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_main_skv_cha_warlord_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_main_skv_cha_warlord_1"] = "melee_highvalue|war_beast|com|1",
    ["wh2_main_skv_inf_clanrat_spearmen_0"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh2_main_skv_inf_clanrat_spearmen_1"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh2_main_skv_inf_clanrats_0"] = "melee|inf_melee|inf_mel|0",
    ["wh2_main_skv_inf_clanrats_0_summoned"] = "melee|inf_melee|inf_mel|0",
    ["wh2_main_skv_inf_clanrats_0_summoned_small"] = "melee|inf_melee|inf_mel|0",
    ["wh2_main_skv_inf_clanrats_1"] = "melee|inf_melee|inf_mel|0",
    ["wh2_main_skv_inf_death_globe_bombardiers"] = "ranged|inf_ranged|inf_mis|0",
    ["wh2_main_skv_inf_death_runners_0"] = "melee_stalkers_flankers|inf_melee|inf_mel|0",
    ["wh2_main_skv_inf_death_runners_0_summoned"] = "melee_stalkers_flankers|inf_melee|inf_mel|0",
    ["wh2_main_skv_inf_gutter_runner_slingers_0"] = "ranged_stalkers_flanker_harasser|inf_ranged|inf_mis|0",
    ["wh2_main_skv_inf_gutter_runner_slingers_1"] = "ranged_stalkers_flanker_harasser|inf_ranged|inf_mis|0",
    ["wh2_main_skv_inf_gutter_runners_0"] = "ranged_stalkers_flanker_harasser|inf_ranged|inf_mis|0",
    ["wh2_main_skv_inf_gutter_runners_1"] = "ranged_stalkers_flanker_harasser|inf_ranged|inf_mis|0",
    ["wh2_main_skv_inf_night_runners_0"] = "ranged_stalkers_flanker_harasser|inf_ranged|inf_mis|0",
    ["wh2_main_skv_inf_night_runners_1"] = "ranged_stalkers_flanker_harasser|inf_ranged|inf_mis|0",
    ["wh2_main_skv_inf_plague_monk_censer_bearer"] = "melee|inf_melee|inf_mel|0",
    ["wh2_main_skv_inf_plague_monks"] = "melee|inf_melee|inf_mel|0",
    ["wh2_main_skv_inf_plague_monks_summoned"] = "melee|inf_melee|inf_mel|0",
    ["wh2_main_skv_inf_poison_wind_globadiers"] = "ranged|inf_ranged|inf_mis|0",
    ["wh2_main_skv_inf_skavenslave_slingers_0"] = "ranged_harasser|inf_ranged|inf_mis|0",
    ["wh2_main_skv_inf_skavenslave_spearmen_0"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh2_main_skv_inf_skavenslave_spearmen_0_summoned"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh2_main_skv_inf_skavenslaves_0"] = "melee|inf_melee|inf_mel|0",
    ["wh2_main_skv_inf_stormvermin_0"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh2_main_skv_inf_stormvermin_0_quest"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh2_main_skv_inf_stormvermin_0_summoned"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh2_main_skv_inf_stormvermin_1"] = "melee|inf_melee|inf_mel|0",
    ["wh2_main_skv_inf_warpfire_thrower"] = "ranged_direct|inf_ranged|inf_mis|0",
    ["wh2_main_skv_mon_hell_pit_abomination"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh2_main_skv_mon_rat_ogres"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh2_main_skv_veh_doomwheel"] = "melee_flanker_shock|war_machine|chariot|1",
    ["wh2_pro06_tmb_mon_bone_giant_0"] = "ranged_direct_highvalue_undead|inf_ranged|inf_mis|1",
    ["wh2_pro07_emp_cha_wizard_death_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_pro07_emp_cha_wizard_death_1"] = "mage_highvalue|cavalry|com|1",
    ["wh2_pro07_emp_cha_wizard_death_2"] = "flying_mage_highvalue|cavalry|com|1",
    ["wh2_pro07_emp_cha_wizard_death_3"] = "mage_highvalue|cavalry|com|1",
    ["wh2_pro08_neu_cha_felix"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_pro08_neu_cha_gotrek"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_pro09_grn_cha_black_orc_big_boss_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_pro09_grn_cha_black_orc_big_boss_1"] = "melee_highvalue|cavalry|com|1",
    ["wh2_twa01_grn_cha_goblin_great_shaman_3"] = "melee_mage_highvalue|war_beast|com|1",
    ["wh2_twa02_wef_cha_glade_captain_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_twa02_wef_cha_glade_captain_1"] = "ranged_cav_highvalue|cavalry|com|1",
    ["wh2_twa02_wef_cha_glade_captain_2"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh2_twa02_wef_cha_glade_captain_3"] = "ranged_cav_highvalue|cavalry|com|1",
    ["wh2_twa03_def_cha_rakarth_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh2_twa03_def_cha_rakarth_1"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh2_twa03_def_cha_rakarth_2"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh2_twa03_def_cha_rakarth_3"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh2_twa03_def_mon_war_mammoth_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh2_twa03_def_mon_wolves_0"] = "melee_flanker|inf_melee|inf_mel|0",
    ["wh2_twa04_bst_cha_great_bray_shaman_beasts_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_twa04_bst_cha_great_bray_shaman_beasts_1"] = "mage_flanker_highvalue|war_machine|com|0",
    ["wh2_twa04_bst_cha_great_bray_shaman_beasts_2"] = "mage_flanker_highvalue|war_machine|com|0",
    ["wh2_twa04_bst_cha_great_bray_shaman_death_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_twa04_bst_cha_great_bray_shaman_death_1"] = "mage_flanker_highvalue|war_machine|com|0",
    ["wh2_twa04_bst_cha_great_bray_shaman_death_2"] = "mage_flanker_highvalue|war_machine|com|0",
    ["wh2_twa04_bst_cha_great_bray_shaman_shadows_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_twa04_bst_cha_great_bray_shaman_shadows_1"] = "mage_flanker_highvalue|war_machine|com|0",
    ["wh2_twa04_bst_cha_great_bray_shaman_shadows_2"] = "mage_flanker_highvalue|war_machine|com|0",
    ["wh2_twa04_bst_cha_great_bray_shaman_wild_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh2_twa04_bst_cha_great_bray_shaman_wild_1"] = "mage_flanker_highvalue|war_machine|com|0",
    ["wh2_twa04_bst_cha_great_bray_shaman_wild_2"] = "mage_flanker_highvalue|war_machine|com|0",
    ["wh3_cp1_cth_cha_bhashiva"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_cp1_cth_cha_clawspeaker_beasts"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh3_cp1_cth_cha_clawspeaker_life"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh3_cp1_cth_cha_clawspeaker_shadows"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh3_cp1_cth_cha_sawai"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_cp1_cth_cha_taoyan"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_cp1_cth_inf_iron_claw_guandao"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh3_cp1_cth_inf_iron_claw_guandao_summoned"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh3_cp1_cth_inf_stalkers_throwing_disc"] = "ranged_stalkers_flanker_harasser|inf_ranged|inf_mis|0",
    ["wh3_cp1_cth_inf_tiger_warriors_dual_axe"] = "melee|inf_melee|inf_mel|0",
    ["wh3_cp1_cth_mon_celestial_lion_summoned"] = "flying_melee_highvalue|inf_melee|inf_mel|1",
    ["wh3_cp1_tze_cha_qb_exalted_lord_of_change_boss"] = "flying_melee_highvalue|inf_melee|com|1",
    ["wh3_dlc20_chs_cav_chaos_chariot_mkho"] = "melee_flanker_shock|war_machine|chariot|1",
    ["wh3_dlc20_chs_cav_chaos_chariot_mnur"] = "melee_flanker_shock|war_machine|chariot|1",
    ["wh3_dlc20_chs_cav_chaos_chariot_msla"] = "melee_flanker_shock|war_machine|chariot|1",
    ["wh3_dlc20_chs_cav_chaos_chariot_msla_ror"] = "melee_flanker_shock|war_machine|chariot|1",
    ["wh3_dlc20_chs_cav_chaos_chariot_mtze"] = "melee_flanker_shock|war_machine|chariot|1",
    ["wh3_dlc20_chs_cav_chaos_knights_mkho"] = "melee_flanker|war_beast|cav_mel|1",
    ["wh3_dlc20_chs_cav_chaos_knights_mkho_lances"] = "melee_flanker_shock|war_beast|cav_shk|1",
    ["wh3_dlc20_chs_cav_chaos_knights_mnur"] = "melee_flanker|war_beast|cav_mel|1",
    ["wh3_dlc20_chs_cav_chaos_knights_mnur_lances"] = "melee_flanker_shock|war_beast|cav_shk|1",
    ["wh3_dlc20_chs_cav_chaos_knights_msla"] = "melee_flanker|war_beast|cav_mel|1",
    ["wh3_dlc20_chs_cav_chaos_knights_msla_lances"] = "melee_flanker_shock|war_beast|cav_shk|1",
    ["wh3_dlc20_chs_cav_chaos_knights_mtze_lances"] = "melee_flanker_shock|war_beast|cav_shk|1",
    ["wh3_dlc20_chs_cav_marauder_horsemen_mkho_throwing_axes"] = "ranged_harasser_flanker|war_beast|cav_mis|1",
    ["wh3_dlc20_chs_cav_marauder_horsemen_mnur_throwing_axes"] = "ranged_harasser_flanker|war_beast|cav_mis|1",
    ["wh3_dlc20_chs_cav_marauder_horsemen_msla_javelins"] = "ranged_harasser_flanker|war_beast|cav_mis|1",
    ["wh3_dlc20_chs_cav_marauder_horsemen_mtze_javelins"] = "ranged_harasser_flanker|war_beast|cav_mis|1",
    ["wh3_dlc20_chs_cha_chaos_lord_mkho"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc20_chs_cha_chaos_lord_mkho_chaos_steed"] = "melee_cav_shock_highvalue|war_beast|com|1",
    ["wh3_dlc20_chs_cha_chaos_lord_mkho_gorebeast_chariot"] = "melee_flanker_shock|war_machine|com|1",
    ["wh3_dlc20_chs_cha_chaos_lord_mkho_juggernaut"] = "melee_cav_shock_highvalue|cavalry|com|1",
    ["wh3_dlc20_chs_cha_chaos_lord_msla"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc20_chs_cha_chaos_lord_msla_chaos_chariot"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh3_dlc20_chs_cha_chaos_lord_msla_chaos_steed"] = "melee_highvalue|war_beast|com|1",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_death_warshrine"] = "melee_mage_highvalue|war_beast|com|1",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_fire_warshrine"] = "melee_mage_highvalue|war_beast|com|1",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_lord_death_mnur"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_lord_death_mnur_chaos_steed"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_lord_death_mnur_warshrine"] = "melee_mage_highvalue|war_beast|com|1",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_lord_death_warshrine"] = "melee_mage_highvalue|war_beast|com|1",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_lord_fire_warshrine"] = "melee_mage_highvalue|war_beast|com|1",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_lord_metal_mtze"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_lord_metal_mtze_chaos_steed"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_lord_metal_mtze_disc"] = "flying_melee_mage_highvalue|inf_melee|com|1",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_lord_metal_mtze_warshrine"] = "melee_mage_highvalue|war_beast|com|1",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_lord_metal_warshrine"] = "melee_mage_highvalue|war_beast|com|1",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_lord_nurgle_mnur"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_lord_nurgle_mnur_chaos_steed"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_lord_nurgle_mnur_warshrine"] = "melee_mage_highvalue|war_beast|com|1",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_lord_shadows_warshrine"] = "melee_mage_highvalue|war_beast|com|1",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_lord_tzeentch_mtze"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_lord_tzeentch_mtze_chaos_steed"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_lord_tzeentch_mtze_disc"] = "flying_melee_mage_highvalue|inf_melee|com|1",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_lord_tzeentch_mtze_warshrine"] = "melee_mage_highvalue|war_beast|com|1",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_metal_mtze"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_metal_mtze_chaos_steed"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_metal_mtze_disc"] = "flying_melee_mage_highvalue|inf_melee|com|1",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_metal_mtze_warshrine"] = "melee_mage_highvalue|war_beast|com|1",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_metal_warshrine"] = "melee_mage_highvalue|war_beast|com|1",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_shadows_msla"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_shadows_msla_chaos_steed"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_shadows_msla_warshrine"] = "melee_mage_highvalue|war_beast|com|1",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_shadows_warshrine"] = "melee_mage_highvalue|war_beast|com|1",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_slaanesh_msla"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_slaanesh_msla_chaos_steed"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_slaanesh_msla_warshrine"] = "melee_mage_highvalue|war_beast|com|1",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_tzeentch_mtze"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_tzeentch_mtze_chaos_steed"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_tzeentch_mtze_disc"] = "flying_melee_mage_highvalue|inf_melee|com|1",
    ["wh3_dlc20_chs_cha_chaos_sorcerer_tzeentch_mtze_warshrine"] = "melee_mage_highvalue|war_beast|com|1",
    ["wh3_dlc20_chs_cha_cultist_msla_warshrine"] = "melee_gatecrusher_shock|war_beast|com|1",
    ["wh3_dlc20_chs_cha_daemon_prince"] = "flying_melee_highvalue|inf_melee|com|1",
    ["wh3_dlc20_chs_cha_daemon_prince_mkho"] = "flying_melee_highvalue|inf_melee|com|1",
    ["wh3_dlc20_chs_cha_daemon_prince_mnur"] = "flying_melee_highvalue|inf_melee|com|1",
    ["wh3_dlc20_chs_cha_daemon_prince_msla"] = "flying_melee_highvalue|inf_melee|com|1",
    ["wh3_dlc20_chs_cha_daemon_prince_mtze"] = "flying_melee_highvalue|inf_melee|com|1",
    ["wh3_dlc20_chs_cha_exalted_hero_mkho"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc20_chs_cha_exalted_hero_mkho_chaos_steed"] = "melee_cav_shock_highvalue|war_beast|com|1",
    ["wh3_dlc20_chs_cha_exalted_hero_mkho_gorebeast_chariot"] = "melee_flanker_shock|war_machine|com|1",
    ["wh3_dlc20_chs_cha_exalted_hero_mkho_juggernaut"] = "melee_cav_shock_highvalue|cavalry|com|1",
    ["wh3_dlc20_chs_cha_exalted_hero_mnur"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc20_chs_cha_exalted_hero_mnur_chaos_chariot"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh3_dlc20_chs_cha_exalted_hero_mnur_chaos_steed"] = "melee_highvalue|war_beast|com|1",
    ["wh3_dlc20_chs_inf_aspiring_champions_mtze_ror"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh3_dlc20_chs_inf_chaos_marauders_mkho"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc20_chs_inf_chaos_marauders_mkho_dualweapons"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc20_chs_inf_chaos_marauders_mnur"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc20_chs_inf_chaos_marauders_mnur_greatweapons"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc20_chs_inf_chaos_marauders_msla"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc20_chs_inf_chaos_marauders_msla_hellscourges"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc20_chs_inf_chaos_marauders_mtze"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc20_chs_inf_chaos_marauders_mtze_spears"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh3_dlc20_chs_inf_chaos_warriors_mnur"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc20_chs_inf_chaos_warriors_mnur_greatweapons"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc20_chs_inf_chaos_warriors_msla"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc20_chs_inf_chaos_warriors_msla_hellscourges"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc20_chs_inf_chaos_warriors_mtze"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc20_chs_inf_chaos_warriors_mtze_halberds"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh3_dlc20_chs_inf_chosen_mkho"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc20_chs_inf_chosen_mkho_dualweapons"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc20_chs_inf_chosen_mnur"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc20_chs_inf_chosen_mnur_greatweapons"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc20_chs_inf_chosen_msla"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc20_chs_inf_chosen_msla_hellscourges"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc20_chs_inf_chosen_mtze"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc20_chs_inf_chosen_mtze_halberds"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh3_dlc20_chs_inf_forsaken_mkho"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc20_chs_inf_forsaken_msla"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc20_chs_mon_giant_mnur_ror"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_dlc20_chs_mon_warshrine"] = "melee_gatecrusher_shock|war_beast|inf_mel|1",
    ["wh3_dlc20_chs_mon_warshrine_mkho"] = "melee_gatecrusher_shock|war_beast|inf_mel|1",
    ["wh3_dlc20_chs_mon_warshrine_mnur"] = "melee_gatecrusher_shock|war_beast|inf_mel|1",
    ["wh3_dlc20_chs_mon_warshrine_msla"] = "melee_gatecrusher_shock|war_beast|inf_mel|1",
    ["wh3_dlc20_chs_mon_warshrine_mtze"] = "melee_gatecrusher_shock|war_beast|inf_mel|1",
    ["wh3_dlc20_kho_cav_skullcrushers_mkho_ror"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh3_dlc20_kho_cha_cultist_mkho_warshrine"] = "melee_gatecrusher_shock|war_beast|com|1",
    ["wh3_dlc20_kho_cha_valkia"] = "flying_melee_highvalue|inf_melee|com|0",
    ["wh3_dlc20_nur_cha_cultist_mnur_warshrine"] = "melee_gatecrusher_shock|war_beast|com|1",
    ["wh3_dlc20_nur_cha_festus"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh3_dlc20_sla_cha_azazel"] = "flying_melee_mage_highvalue|inf_melee|com|1",
    ["wh3_dlc20_tze_cha_cultist_mtze_warshrine"] = "melee_gatecrusher_shock|war_beast|com|1",
    ["wh3_dlc20_tze_cha_vilitch"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh3_dlc23_chd_cav_bull_centaurs_axe"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh3_dlc23_chd_cav_bull_centaurs_dual_axe"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh3_dlc23_chd_cav_bull_centaurs_dual_axe_ror"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh3_dlc23_chd_cav_bull_centaurs_greatweapons"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh3_dlc23_chd_cav_hobgoblin_wolf_raiders_bows"] = "melee_flanker|cavalry|cav_mis|1",
    ["wh3_dlc23_chd_cav_hobgoblin_wolf_raiders_ror"] = "melee_flanker|cavalry|cav_mis|1",
    ["wh3_dlc23_chd_cav_hobgoblin_wolf_raiders_spears"] = "melee_flanker|cavalry|cav_mel|1",
    ["wh3_dlc23_chd_cha_astragoth_ironhand"] = "melee_mage_highvalue|inf_melee|com|1",
    ["wh3_dlc23_chd_cha_bull_centaur_taurruk"] = "melee_highvalue|inf_melee|com|1",
    ["wh3_dlc23_chd_cha_daemonsmith_sorcerer_death"] = "hybrid_mage_highvalue|inf_melee|com|0",
    ["wh3_dlc23_chd_cha_daemonsmith_sorcerer_death_bale_taurus"] = "flying_melee_shock_mage_hybrid_highvalue|war_beast|com|1",
    ["wh3_dlc23_chd_cha_daemonsmith_sorcerer_death_great_taurus"] = "flying_melee_shock_mage_hybrid_highvalue|war_beast|com|1",
    ["wh3_dlc23_chd_cha_daemonsmith_sorcerer_death_lammasu"] = "flying_melee_mage_hybrid_highvalue|war_beast|com|1",
    ["wh3_dlc23_chd_cha_daemonsmith_sorcerer_fire"] = "hybrid_mage_highvalue|inf_melee|com|0",
    ["wh3_dlc23_chd_cha_daemonsmith_sorcerer_fire_bale_taurus"] = "flying_melee_shock_mage_hybrid_highvalue|war_beast|com|1",
    ["wh3_dlc23_chd_cha_daemonsmith_sorcerer_fire_great_taurus"] = "flying_melee_shock_mage_hybrid_highvalue|war_beast|com|1",
    ["wh3_dlc23_chd_cha_daemonsmith_sorcerer_fire_lammasu"] = "flying_melee_mage_hybrid_highvalue|war_beast|com|1",
    ["wh3_dlc23_chd_cha_daemonsmith_sorcerer_hashut"] = "hybrid_mage_highvalue|inf_melee|com|0",
    ["wh3_dlc23_chd_cha_daemonsmith_sorcerer_hashut_bale_taurus"] = "flying_melee_shock_mage_hybrid_highvalue|war_beast|com|1",
    ["wh3_dlc23_chd_cha_daemonsmith_sorcerer_hashut_great_taurus"] = "flying_melee_shock_mage_hybrid_highvalue|war_beast|com|1",
    ["wh3_dlc23_chd_cha_daemonsmith_sorcerer_hashut_lammasu"] = "flying_melee_mage_hybrid_highvalue|war_beast|com|1",
    ["wh3_dlc23_chd_cha_daemonsmith_sorcerer_metal"] = "hybrid_mage_highvalue|inf_melee|com|0",
    ["wh3_dlc23_chd_cha_daemonsmith_sorcerer_metal_bale_taurus"] = "flying_melee_shock_mage_hybrid_highvalue|war_beast|com|1",
    ["wh3_dlc23_chd_cha_daemonsmith_sorcerer_metal_great_taurus"] = "flying_melee_shock_mage_hybrid_highvalue|war_beast|com|1",
    ["wh3_dlc23_chd_cha_daemonsmith_sorcerer_metal_lammasu"] = "flying_melee_mage_hybrid_highvalue|war_beast|com|1",
    ["wh3_dlc23_chd_cha_drazhoath_the_ashen"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh3_dlc23_chd_cha_drazhoath_the_ashen_bale_taurus_cinderbreath"] = "flying_melee_shock_mage_highvalue|war_beast|com|1",
    ["wh3_dlc23_chd_cha_gorduz_backstabber"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc23_chd_cha_gorduz_backstabber_giant_wolf"] = "melee_highvalue|cavalry|com|1",
    ["wh3_dlc23_chd_cha_infernal_castellan"] = "ranged_highvalue|inf_ranged|com|0",
    ["wh3_dlc23_chd_cha_overseer"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc23_chd_cha_overseer_great_taurus"] = "flying_melee_shock_highvalue|war_beast|com|1",
    ["wh3_dlc23_chd_cha_overseer_lammasu"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh3_dlc23_chd_cha_sorcerer_prophet_death"] = "hybrid_mage_highvalue_slow|inf_melee|com|0",
    ["wh3_dlc23_chd_cha_sorcerer_prophet_death_bale_taurus"] = "flying_melee_shock_mage_hybrid_highvalue|war_beast|com|1",
    ["wh3_dlc23_chd_cha_sorcerer_prophet_death_great_taurus"] = "flying_melee_shock_mage_hybrid_highvalue|war_beast|com|1",
    ["wh3_dlc23_chd_cha_sorcerer_prophet_death_lammasu"] = "flying_melee_mage_hybrid_highvalue|war_beast|com|1",
    ["wh3_dlc23_chd_cha_sorcerer_prophet_fire"] = "hybrid_mage_highvalue_slow|inf_melee|com|0",
    ["wh3_dlc23_chd_cha_sorcerer_prophet_fire_bale_taurus"] = "flying_melee_shock_mage_hybrid_highvalue|war_beast|com|1",
    ["wh3_dlc23_chd_cha_sorcerer_prophet_fire_great_taurus"] = "flying_melee_shock_mage_hybrid_highvalue|war_beast|com|1",
    ["wh3_dlc23_chd_cha_sorcerer_prophet_fire_lammasu"] = "flying_melee_mage_hybrid_highvalue|war_beast|com|1",
    ["wh3_dlc23_chd_cha_sorcerer_prophet_hashut"] = "hybrid_mage_highvalue_slow|inf_melee|com|0",
    ["wh3_dlc23_chd_cha_sorcerer_prophet_hashut_bale_taurus"] = "flying_melee_shock_mage_hybrid_highvalue|war_beast|com|1",
    ["wh3_dlc23_chd_cha_sorcerer_prophet_hashut_great_taurus"] = "flying_melee_shock_mage_hybrid_highvalue|war_beast|com|1",
    ["wh3_dlc23_chd_cha_sorcerer_prophet_hashut_lammasu"] = "flying_melee_mage_hybrid_highvalue|war_beast|com|1",
    ["wh3_dlc23_chd_cha_sorcerer_prophet_metal"] = "hybrid_mage_highvalue_slow|inf_melee|com|0",
    ["wh3_dlc23_chd_cha_sorcerer_prophet_metal_bale_taurus"] = "flying_melee_shock_mage_hybrid_highvalue|war_beast|com|1",
    ["wh3_dlc23_chd_cha_sorcerer_prophet_metal_great_taurus"] = "flying_melee_shock_mage_hybrid_highvalue|war_beast|com|1",
    ["wh3_dlc23_chd_cha_sorcerer_prophet_metal_lammasu"] = "flying_melee_mage_hybrid_highvalue|war_beast|com|1",
    ["wh3_dlc23_chd_cha_zhatan_the_black"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc23_chd_cha_zhatan_the_black_great_taurus"] = "flying_melee_shock_highvalue|war_beast|com|1",
    ["wh3_dlc23_chd_cha_zhatan_the_black_lammasu"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh3_dlc23_chd_inf_chaos_dwarf_blunderbusses"] = "hybrid_melee_direct_no_skirmish|inf_ranged|inf_mis|0",
    ["wh3_dlc23_chd_inf_chaos_dwarf_blunderbusses_ror"] = "hybrid_melee_direct_no_skirmish|inf_ranged|inf_mis|0",
    ["wh3_dlc23_chd_inf_chaos_dwarf_warriors"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc23_chd_inf_chaos_dwarf_warriors_great_weapons"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc23_chd_inf_chaos_dwarf_warriors_ror"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc23_chd_inf_goblin_labourers"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc23_chd_inf_hobgoblin_archers"] = "ranged|inf_ranged|inf_mis|0",
    ["wh3_dlc23_chd_inf_hobgoblin_cutthroats"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc23_chd_inf_hobgoblin_cutthroats_summoned"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc23_chd_inf_hobgoblin_sneaky_gits"] = "melee_stalkers|inf_melee|inf_mel|0",
    ["wh3_dlc23_chd_inf_infernal_guard"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc23_chd_inf_infernal_guard_fireglaives"] = "hybrid_melee_direct_no_skirmish|inf_ranged|inf_mis|0",
    ["wh3_dlc23_chd_inf_infernal_guard_great_weapons"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc23_chd_inf_infernal_ironsworn"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc23_chd_inf_infernal_ironsworn_ror"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc23_chd_inf_orc_labourers"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc23_chd_mon_bale_taurus"] = "flying_melee_flanker_shock|inf_melee|inf_mel|1",
    ["wh3_dlc23_chd_mon_great_taurus"] = "flying_melee_flanker_shock|inf_melee|inf_mel|1",
    ["wh3_dlc23_chd_mon_kdaai_destroyer"] = "melee_gatecrusher_highvalue|inf_melee|inf_mel|1",
    ["wh3_dlc23_chd_mon_kdaai_fireborn"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh3_dlc23_chd_mon_kdaai_fireborn_summoned"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh3_dlc23_chd_mon_lammasu"] = "flying_melee_mage_highvalue|inf_melee|inf_mel|1",
    ["wh3_dlc23_chd_veh_deathshrieker_rocket_launcher"] = "ranged_indirect_arty|war_machine|chariot|1",
    ["wh3_dlc23_chd_veh_dreadquake_mortar"] = "ranged_indirect_arty|war_machine|chariot|1",
    ["wh3_dlc23_chd_veh_iron_daemon"] = "hybrid_direct_shock_gatecrusher|war_machine|chariot|1",
    ["wh3_dlc23_chd_veh_iron_daemon_1dreadquake"] = "hybrid_indirect_shock_arty_gatecrusher|war_machine|chariot|1",
    ["wh3_dlc23_chd_veh_iron_daemon_3payload_qb"] = "melee_gatecrusher_shock|war_machine|chariot|1",
    ["wh3_dlc23_chd_veh_iron_daemon_ror"] = "hybrid_direct_shock_gatecrusher|war_machine|chariot|1",
    ["wh3_dlc23_chd_veh_iron_daemon_ror_1dreadquake"] = "hybrid_indirect_shock_arty_gatecrusher|war_machine|chariot|1",
    ["wh3_dlc23_chd_veh_magma_cannon"] = "ranged_direct_arty|war_machine|chariot|1",
    ["wh3_dlc23_chd_veh_skullcracker"] = "melee_gatecrusher_shock|war_machine|chariot|1",
    ["wh3_dlc23_chd_veh_skullcracker_1dreadquake"] = "hybrid_indirect_shock_arty_gatecrusher|war_machine|chariot|1",
    ["wh3_dlc23_neu_cha_ulrika"] = "hybrid_mage_highvalue|inf_melee|com|0",
    ["wh3_dlc23_neu_cha_ulrika_warhorse"] = "hybrid_mage_highvalue|cavalry|com|1",
    ["wh3_dlc24_chs_cha_chaos_lord_mtze"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc24_chs_cha_chaos_lord_mtze_chaos_chariot"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh3_dlc24_chs_cha_chaos_lord_mtze_chaos_steed"] = "melee_highvalue|war_beast|com|1",
    ["wh3_dlc24_chs_cha_chaos_lord_mtze_disc"] = "flying_melee_highvalue|inf_melee|com|1",
    ["wh3_dlc24_chs_cha_exalted_hero_mtze"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc24_chs_cha_exalted_hero_mtze_chaos_chariot"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh3_dlc24_chs_cha_exalted_hero_mtze_chaos_steed"] = "melee_highvalue|war_beast|com|1",
    ["wh3_dlc24_chs_cha_exalted_hero_mtze_disc"] = "flying_melee_highvalue|inf_melee|com|1",
    ["wh3_dlc24_cth_cha_astromancer_great_moon_bird"] = "flying_melee_mage_highvalue|war_beast|com|1",
    ["wh3_dlc24_cth_cha_celestial_general_yang"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc24_cth_cha_celestial_general_yang_cathayan_horse"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_dlc24_cth_cha_celestial_general_yang_celestial_lion"] = "flying_melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_dlc24_cth_cha_celestial_general_yang_longma"] = "flying_melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_dlc24_cth_cha_gate_master"] = "hybrid_lowvalue|inf_melee|com|0",
    ["wh3_dlc24_cth_cha_gate_master_warhorse"] = "hybrid_cav_highvalue|war_beast|com|1",
    ["wh3_dlc24_cth_cha_saytang_the_watcher"] = "melee_gatecrusher|inf_ranged|com|1",
    ["wh3_dlc24_cth_cha_yuan_bo_dragon"] = "flying_melee_highvalue|inf_melee|com|1",
    ["wh3_dlc24_cth_cha_yuan_bo_human"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc24_cth_inf_dragon_guard_crossbowmen_ror"] = "ranged_no_skirmish|inf_ranged|inf_mis|0",
    ["wh3_dlc24_cth_inf_onyx_crowmen"] = "flying_melee_flanker|inf_melee|inf_mel|0",
    ["wh3_dlc24_cth_inf_onyx_crowmen_ror"] = "flying_fast_melee_flanker_bomber|inf_melee|inf_mel|0",
    ["wh3_dlc24_cth_mon_celestial_lion"] = "flying_melee_highvalue|inf_melee|inf_mel|1",
    ["wh3_dlc24_cth_mon_great_moon_bird"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh3_dlc24_cth_mon_jade_lion"] = "melee|inf_melee|inf_mel|1",
    ["wh3_dlc24_cth_mon_jet_lion"] = "melee|inf_melee|inf_mel|1",
    ["wh3_dlc24_cth_veh_zhangu_war_drum"] = "mage_highvalue|war_machine|chariot|1",
    ["wh3_dlc24_cth_veh_zhangu_war_drum_ror"] = "mage_highvalue|war_machine|chariot|1",
    ["wh3_dlc24_grn_cha_grimgor_ironhide_quest_battle"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc24_ksl_cha_druzhina"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc24_ksl_cha_druzhina_warhorse"] = "melee_highvalue|war_beast|com|0",
    ["wh3_dlc24_ksl_cha_golden_knight"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc24_ksl_cha_golden_knight_warhorse"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_dlc24_ksl_cha_hag_witch_beast"] = "mage_flanker_highvalue|war_machine|com|1",
    ["wh3_dlc24_ksl_cha_hag_witch_death"] = "mage_flanker_highvalue|war_machine|com|1",
    ["wh3_dlc24_ksl_cha_hag_witch_hag"] = "mage_flanker_highvalue|war_machine|com|1",
    ["wh3_dlc24_ksl_cha_hag_witch_shadow"] = "mage_flanker_highvalue|war_machine|com|1",
    ["wh3_dlc24_ksl_cha_ice_witch_ice_frost_wyrm"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_dlc24_ksl_cha_ice_witch_tempest_frost_wyrm"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_dlc24_ksl_cha_katarin_frost_wyrm"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_dlc24_ksl_cha_katarin_ice_court_sled"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh3_dlc24_ksl_cha_mother_ostankya"] = "mage_flanker_highvalue|war_machine|com|1",
    ["wh3_dlc24_ksl_inf_akshina_ambushers"] = "ranged|inf_ranged|inf_mis|0",
    ["wh3_dlc24_ksl_inf_akshina_ambushers_ror"] = "ranged|inf_ranged|inf_mis|0",
    ["wh3_dlc24_ksl_inf_kislevite_warriors"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh3_dlc24_ksl_inf_streltsi_ror"] = "hybrid|inf_ranged|inf_mis|0",
    ["wh3_dlc24_ksl_mon_frost_wyrm"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_dlc24_ksl_mon_incarnate_elemental_of_beasts"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_dlc24_ksl_mon_incarnate_elemental_of_beasts_summoned"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_dlc24_ksl_mon_the_things_in_the_woods"] = "melee_flanker_shock|inf_melee|spcl|1",
    ["wh3_dlc24_ksl_mon_the_things_in_the_woods_ror"] = "melee_flanker_shock|inf_melee|spcl|1",
    ["wh3_dlc24_ksl_mon_the_things_in_the_woods_summoned"] = "melee_flanker_shock|inf_melee|spcl|0",
    ["wh3_dlc24_qb_cst_cav_knights_errant_0"] = "melee_flanker_shock_undead|cavalry|cav_shk|0",
    ["wh3_dlc24_qb_cst_cav_knights_of_the_realm"] = "melee_flanker_shock_undead|cavalry|cav_shk|0",
    ["wh3_dlc24_qb_cst_cav_questing_knights_0"] = "melee_flanker_shock_undead|cavalry|cav_shk|0",
    ["wh3_dlc24_tze_cha_aekold_helbrass"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc24_tze_cha_blue_scribes"] = "flying_mage_highvalue|inf_melee|com|1",
    ["wh3_dlc24_tze_cha_changeling"] = "mage_highvalue|inf_melee|com|0",
    ["wh3_dlc24_tze_cha_changeling_quest_battle"] = "mage_highvalue|inf_melee|com|0",
    ["wh3_dlc24_tze_cha_changeling_summoned_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh3_dlc24_tze_inf_centigors_great_weapons"] = "melee_flanker_shock|inf_melee|inf_mel|1",
    ["wh3_dlc24_tze_inf_pink_horrors_ror"] = "ranged_no_skirmish|inf_ranged|inf_mis|0",
    ["wh3_dlc24_tze_inf_tzaangors"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc24_tze_mon_cockatrice"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh3_dlc24_tze_mon_flamers_changebringers"] = "flying_ranged_harasser_flanker|inf_melee|inf_mis|1",
    ["wh3_dlc24_tze_mon_mutalith_vortex_beast"] = "melee_gatecrusher_highvalue|inf_melee|spcl|1",
    ["wh3_dlc24_tze_mon_mutalith_vortex_beast_ror"] = "melee_gatecrusher_highvalue|inf_melee|spcl|1",
    ["wh3_dlc24_tze_mon_screamers_ror"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh3_dlc25_bst_mon_jabberslythe_qb_boss"] = "melee_highvalue|inf_melee|inf_mel|1",
    ["wh3_dlc25_chs_cha_chaos_lord_mnur"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc25_chs_cha_chaos_lord_mnur_chaos_chariot"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh3_dlc25_chs_cha_chaos_lord_mnur_chaos_steed"] = "melee_highvalue|war_beast|com|1",
    ["wh3_dlc25_chs_cha_chaos_lord_mnur_rot_beast"] = "melee_highvalue|war_beast|com|1",
    ["wh3_dlc25_chs_cha_chaos_sorcerer_death_mnur"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh3_dlc25_chs_cha_chaos_sorcerer_death_mnur_chaos_steed"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_dlc25_chs_cha_chaos_sorcerer_death_mnur_rot_beast"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_dlc25_chs_cha_chaos_sorcerer_death_mnur_warshrine"] = "melee_mage_highvalue|war_beast|com|1",
    ["wh3_dlc25_chs_cha_chaos_sorcerer_lord_death_mnur_rot_beast"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_dlc25_chs_cha_chaos_sorcerer_lord_nurgle_mnur_rot_beast"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_dlc25_chs_cha_chaos_sorcerer_nurgle_mnur"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh3_dlc25_chs_cha_chaos_sorcerer_nurgle_mnur_chaos_steed"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_dlc25_chs_cha_chaos_sorcerer_nurgle_mnur_rot_beast"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_dlc25_chs_cha_chaos_sorcerer_nurgle_mnur_warshrine"] = "melee_mage_highvalue|war_beast|com|1",
    ["wh3_dlc25_chs_cha_exalted_hero_mnur_rot_beast"] = "melee_highvalue|war_beast|com|1",
    ["wh3_dlc25_dwf_art_flame_cannon_grudge_unit"] = "ranged_direct_arty|artillery|art_fld|0",
    ["wh3_dlc25_dwf_art_goblin_hewer"] = "ranged_direct_arty|artillery|art_fld|0",
    ["wh3_dlc25_dwf_art_grudge_thrower_grudge_unit"] = "ranged_indirect_arty|artillery|art_fld|0",
    ["wh3_dlc25_dwf_cha_daemon_slayer"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc25_dwf_cha_dragon_slayer"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc25_dwf_cha_garagrim_ironfist"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc25_dwf_cha_malakai_makaisson"] = "ranged_direct_highvalue|inf_melee|com|0",
    ["wh3_dlc25_dwf_inf_doomseekers"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc25_dwf_inf_doomseekers_ror"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc25_dwf_inf_hammerers_grudge_unit"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc25_dwf_inf_irondrakes_0_grudge_unit"] = "ranged_direct_no_skirmish|inf_ranged|inf_mis|0",
    ["wh3_dlc25_dwf_inf_longbeards_1_grudge_unit"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc25_dwf_inf_miners_1_summoned"] = "melee_gatecrusher|inf_melee|inf_mel|0",
    ["wh3_dlc25_dwf_inf_quarrellers_1_grudge_unit"] = "ranged_no_skirmish|inf_ranged|inf_mis|0",
    ["wh3_dlc25_dwf_inf_slayer_pirates"] = "hybrid_melee|inf_ranged|inf_mis|0",
    ["wh3_dlc25_dwf_inf_slayer_pirates_ror"] = "hybrid_melee|inf_ranged|inf_mis|0",
    ["wh3_dlc25_dwf_inf_slayers_grudge_unit"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh3_dlc25_dwf_inf_thunderers_grudge_rakers"] = "ranged_direct_no_skirmish|inf_ranged|inf_mis|0",
    ["wh3_dlc25_dwf_inf_thunderers_ror"] = "ranged_direct_no_skirmish|inf_ranged|inf_mis|0",
    ["wh3_dlc25_dwf_veh_gyrocopter_1_grudge_unit"] = "gyrocopter|inf_ranged|inf_mis|1",
    ["wh3_dlc25_dwf_veh_gyrocopter_summoned_0"] = "gyrocopter|inf_ranged|inf_mis|1",
    ["wh3_dlc25_dwf_veh_thunderbarge"] = "thunderbarge|war_beast|inf_mis|1",
    ["wh3_dlc25_dwf_veh_thunderbarge_grungni"] = "thunderbarge|war_beast|inf_mis|1",
    ["wh3_dlc25_dwf_veh_thunderbarge_grungni_mp"] = "thunderbarge|war_beast|inf_mis|1",
    ["wh3_dlc25_emp_art_helstorm_rocket_battery_morr"] = "ranged_indirect_arty|artillery|art_fld|0",
    ["wh3_dlc25_emp_cav_knights_of_the_black_rose"] = "melee_flanker|cavalry|cav_mel|1",
    ["wh3_dlc25_emp_cav_outriders_morr"] = "ranged_direct_flanker_harasser|cavalry|cav_mis|1",
    ["wh3_dlc25_emp_cha_elspeth_von_draken"] = "mage_highvalue|inf_melee|com|0",
    ["wh3_dlc25_emp_cha_elspeth_von_draken_carmine_dragon"] = "flying_melee_mage_highvalue|war_beast|com|1",
    ["wh3_dlc25_emp_cha_elspeth_von_draken_warhorse"] = "mage_flanker_highvalue|cavalry|com|1",
    ["wh3_dlc25_emp_cha_engineer"] = "ranged_highvalue|inf_melee|com|0",
    ["wh3_dlc25_emp_cha_engineer_mechanical_steed"] = "ranged_cav_highvalue|cavalry|com|1",
    ["wh3_dlc25_emp_cha_engineer_warhorse"] = "ranged_cav_highvalue|cavalry|com|1",
    ["wh3_dlc25_emp_cha_master_engineer"] = "ranged_highvalue|inf_melee|com|0",
    ["wh3_dlc25_emp_cha_master_engineer_mechanical_steed"] = "ranged_cav_highvalue|cavalry|com|1",
    ["wh3_dlc25_emp_cha_master_engineer_steam_tank"] = "ranged_direct_highvalue|war_machine|com|1",
    ["wh3_dlc25_emp_cha_master_engineer_warhorse"] = "ranged_cav_highvalue|cavalry|com|1",
    ["wh3_dlc25_emp_cha_theodore_bruckner"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc25_emp_cha_theodore_bruckner_demigryph_reaper"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh3_dlc25_emp_cha_wizard_metal"] = "mage_highvalue|inf_melee|com|0",
    ["wh3_dlc25_emp_cha_wizard_metal_pegasus"] = "flying_mage_highvalue|cavalry|com|1",
    ["wh3_dlc25_emp_cha_wizard_metal_warhorse"] = "mage_flanker_highvalue|cavalry|com|1",
    ["wh3_dlc25_emp_inf_hochland_long_rifles"] = "ranged_direct|inf_ranged|inf_mis|0",
    ["wh3_dlc25_emp_inf_hochland_long_rifles_ror"] = "ranged_direct|inf_ranged|inf_mis|0",
    ["wh3_dlc25_emp_inf_nuln_ironsides"] = "ranged_direct|inf_ranged|inf_mis|0",
    ["wh3_dlc25_emp_inf_nuln_ironsides_morr"] = "hybrid_melee|inf_ranged|inf_mis|0",
    ["wh3_dlc25_emp_inf_spearmen_shields_ror"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh3_dlc25_emp_mon_hawks_summoned"] = "flying_melee_flanker_shock|inf_melee|inf_mel|1",
    ["wh3_dlc25_emp_mon_incarnate_elemental_of_beasts_summoned"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_dlc25_emp_veh_marienburg_land_ship"] = "ranged_direct_arty|war_machine|chariot|1",
    ["wh3_dlc25_emp_veh_marienburg_land_ship_morr"] = "ranged_direct_arty|war_machine|chariot|1",
    ["wh3_dlc25_emp_veh_marienburg_land_ship_ror"] = "ranged_direct_arty|war_machine|chariot|1",
    ["wh3_dlc25_emp_veh_steam_tank_volley_gun"] = "ranged_direct_arty|war_machine|chariot|1",
    ["wh3_dlc25_grn_mon_arachnarok_spider_boss"] = "melee_gatecrusher|war_beast|inf_mel|1",
    ["wh3_dlc25_grn_mon_rogue_idol_qb_boss"] = "melee_gatecrusher_highvalue|inf_melee|inf_mel|1",
    ["wh3_dlc25_hef_mon_sun_dragon_boss"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh3_dlc25_nur_cav_plague_drones_1_ror"] = "flying_ranged_flanker|cavalry|cav_mis|1",
    ["wh3_dlc25_nur_cav_rot_knights"] = "melee_flanker_shock|war_beast|cav_shk|1",
    ["wh3_dlc25_nur_cav_rot_knights_ror"] = "melee_flanker_shock|war_beast|cav_shk|1",
    ["wh3_dlc25_nur_cha_bray_shaman_wild_chieftain"] = "mage_highvalue|inf_melee|com|0",
    ["wh3_dlc25_nur_cha_bray_shaman_wild_chieftain_razorgor_chariot"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh3_dlc25_nur_cha_bray_shaman_wild_chieftain_tuskgor_chariot"] = "mage_flanker_highvalue|war_machine|com|1",
    ["wh3_dlc25_nur_cha_epidemius"] = "melee_highvalue|cavalry|com|0",
    ["wh3_dlc25_nur_cha_exalted_great_unclean_one_nurgle_qb_boss"] = "melee_gatecrusher_highvalue|inf_melee|com|1",
    ["wh3_dlc25_nur_cha_exalted_hero_chieftain"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc25_nur_cha_exalted_hero_chieftain_chaos_chariot"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh3_dlc25_nur_cha_exalted_hero_chieftain_chaos_dragon"] = "flying_melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_dlc25_nur_cha_exalted_hero_chieftain_chaos_steed"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_dlc25_nur_cha_fimir_balefiend_shadow_chieftain"] = "melee_highvalue|inf_melee|com|1",
    ["wh3_dlc25_nur_cha_infernal_castellan_chieftain"] = "ranged_highvalue|inf_ranged|com|0",
    ["wh3_dlc25_nur_cha_kayzk_the_befouled"] = "melee_cav_shock_highvalue|war_beast|com|1",
    ["wh3_dlc25_nur_cha_skin_wolf_werekin_chieftain"] = "melee_highvalue|inf_melee|com|1",
    ["wh3_dlc25_nur_cha_tamurkhan"] = "melee_highvalue|inf_melee|com|1",
    ["wh3_dlc25_nur_cha_tamurkhan_bubebolos"] = "melee_gatecrusher_highvalue|war_beast|com|1",
    ["wh3_dlc25_nur_inf_nurglings_summoned"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc25_nur_inf_pestigors"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc25_nur_inf_plague_ogres"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh3_dlc25_nur_inf_plague_ogres_great_weapons"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh3_dlc25_nur_mon_bile_trolls"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh3_dlc25_nur_mon_soul_grinder_0_ror"] = "ranged_no_skirmish_gatecrusher|inf_ranged|spcl|1",
    ["wh3_dlc25_nur_mon_toad_dragon"] = "melee_gatecrusher_highvalue|inf_melee|inf_mel|1",
    ["wh3_dlc26_chs_inf_chosen_mkho_ror"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc26_grn_art_bolt_throwa"] = "ranged_indirect_arty|artillery|art_fld|0",
    ["wh3_dlc26_grn_art_bolt_throwa_ror"] = "ranged_indirect_arty|artillery|art_fld|0",
    ["wh3_dlc26_grn_cav_mangler_squig"] = "melee_flanker|inf_melee|inf_mel|1",
    ["wh3_dlc26_grn_cha_gorbad_ironclaw"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc26_grn_cha_gorbad_ironclaw_gnarla"] = "melee_highvalue|cavalry|com|1",
    ["wh3_dlc26_grn_cha_night_goblin_big_boss"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc26_grn_cha_night_goblin_big_boss_squig"] = "melee_highvalue|cavalry|com|1",
    ["wh3_dlc26_grn_cha_savage_orc_great_shaman"] = "mage_highvalue|inf_melee|com|0",
    ["wh3_dlc26_grn_cha_savage_orc_great_shaman_boar"] = "mage_flanker_highvalue|cavalry|com|1",
    ["wh3_dlc26_grn_cha_savage_orc_great_shaman_wyvern"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_dlc26_grn_cha_snagla_grobspit"] = "melee_highvalue|cavalry|com|1",
    ["wh3_dlc26_grn_inf_black_orcs_shield"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc26_grn_inf_rugluds_armoured_orcs"] = "ranged|inf_ranged|inf_mis|0",
    ["wh3_dlc26_grn_inf_squig_herd_0_summoned"] = "melee|inf_melee|inf_mel|1",
    ["wh3_dlc26_grn_mon_arachnarok_spider_flinger"] = "melee_gatecrusher|war_beast|inf_mel|1",
    ["wh3_dlc26_grn_mon_colossal_squig"] = "melee|inf_melee|inf_mel|1",
    ["wh3_dlc26_grn_mon_colossal_squig_ror"] = "melee|inf_melee|inf_mel|1",
    ["wh3_dlc26_grn_mon_wyvern_summoned"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh3_dlc26_kho_cha_arbaal"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc26_kho_cha_arbaal_flesh_hound"] = "melee_cav_shock_highvalue|war_beast|com|1",
    ["wh3_dlc26_kho_cha_bloodspeaker"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh3_dlc26_kho_cha_bloodspeaker_chaos_steed"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_dlc26_kho_cha_bloodspeaker_warshrine"] = "melee_mage_highvalue|war_beast|com|1",
    ["wh3_dlc26_kho_cha_scyla_anfingrimm"] = "melee_highvalue|inf_melee|com|1",
    ["wh3_dlc26_kho_cha_skarr_bloodwrath"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc26_kho_cha_skulltaker"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc26_kho_cha_skulltaker_bloodthrone"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_dlc26_kho_cha_skulltaker_juggernaut"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh3_dlc26_kho_inf_khorngors"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc26_kho_inf_skullreapers"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc26_kho_inf_wrathmongers"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc26_kho_inf_wrathmongers_ror"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc26_kho_mon_bloodbeast_of_khorne"] = "melee_highvalue|inf_melee|inf_mel|1",
    ["wh3_dlc26_kho_mon_slaughterbrute"] = "melee_highvalue|inf_melee|inf_mel|1",
    ["wh3_dlc26_kho_mon_spawn_of_khorne_0_summoned"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_dlc26_kho_veh_skullcannon_ror"] = "hybrid_direct_shock_arty|war_beast|chariot|1",
    ["wh3_dlc26_ogr_cha_bragg_the_gutsman"] = "melee_highvalue|inf_melee|com|1",
    ["wh3_dlc26_ogr_cha_bruiser"] = "melee_highvalue|inf_melee|com|1",
    ["wh3_dlc26_ogr_cha_butcher_death"] = "melee_gatecrusher_highvalue|inf_melee|com|1",
    ["wh3_dlc26_ogr_cha_butcher_heavens"] = "melee_gatecrusher_highvalue|inf_melee|com|1",
    ["wh3_dlc26_ogr_cha_golgfag_maneater"] = "melee_gatecrusher_highvalue|inf_melee|com|1",
    ["wh3_dlc26_ogr_cha_paymaster"] = "melee_gatecrusher_highvalue|inf_melee|com|1",
    ["wh3_dlc26_ogr_cha_slaughtermaster_death"] = "melee_gatecrusher_highvalue|inf_melee|com|1",
    ["wh3_dlc26_ogr_cha_slaughtermaster_heavens"] = "melee_gatecrusher_highvalue|inf_melee|com|1",
    ["wh3_dlc26_ogr_inf_eshin_maneater_ror"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_dlc26_ogr_inf_golgfags_maneaters"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh3_dlc26_ogr_inf_pigback_riders"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh3_dlc26_ogr_inf_pigback_riders_ror"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh3_dlc26_ogr_mon_blood_vultures"] = "flying_melee_flanker|inf_melee|inf_mel|0",
    ["wh3_dlc26_ogr_mon_sabretusk_pack_0_summoned"] = "melee_flanker_shock|inf_melee|spcl|1",
    ["wh3_dlc26_ogr_mon_thundertusk"] = "melee_gatecrusher_shock|war_beast|inf_mel|1",
    ["wh3_dlc26_ogr_mon_yhetees"] = "melee_highvalue|inf_melee|inf_mel|1",
    ["wh3_dlc26_ogr_mon_yhetees_ror"] = "melee_highvalue|inf_melee|inf_mel|1",
    ["wh3_dlc27_bst_mon_ghorgon_boss"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_dlc27_bst_mon_jabberslythe_boss"] = "melee_highvalue|inf_melee|inf_mel|1",
    ["wh3_dlc27_chd_mon_bale_taurus_boss"] = "flying_melee_flanker_shock|inf_melee|inf_mel|1",
    ["wh3_dlc27_chd_mon_lammasu_boss"] = "flying_melee_mage_highvalue|inf_melee|inf_mel|1",
    ["wh3_dlc27_chs_cha_chaos_lord_msla_daemonic_steed"] = "melee_highvalue|war_beast|com|1",
    ["wh3_dlc27_chs_cha_chaos_sorcerer_shadows_msla_daemonic_steed"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_dlc27_chs_cha_chaos_sorcerer_slaanesh_msla_daemonic_steed"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_dlc27_chs_cha_daemon_prince_mkho_qb"] = "flying_melee_highvalue|inf_melee|com|1",
    ["wh3_dlc27_chs_cha_exalted_hero_msla"] = "melee_highvalue|inf_melee|com|1",
    ["wh3_dlc27_chs_cha_exalted_hero_msla_chaos_chariot"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh3_dlc27_chs_cha_exalted_hero_msla_chaos_steed"] = "melee_highvalue|war_beast|com|1",
    ["wh3_dlc27_chs_cha_exalted_hero_msla_daemonic_steed"] = "melee_highvalue|war_beast|com|1",
    ["wh3_dlc27_chs_cha_sorcerer_lord_shadows_msla"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh3_dlc27_chs_cha_sorcerer_lord_shadows_msla_chaos_steed"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_dlc27_chs_cha_sorcerer_lord_shadows_msla_daemonic_steed"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_dlc27_chs_cha_sorcerer_lord_shadows_msla_warshrine"] = "melee_mage_highvalue|war_beast|com|0",
    ["wh3_dlc27_chs_cha_sorcerer_lord_slaanesh_msla"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh3_dlc27_chs_cha_sorcerer_lord_slaanesh_msla_chaos_steed"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_dlc27_chs_cha_sorcerer_lord_slaanesh_msla_daemonic_steed"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_dlc27_chs_cha_sorcerer_lord_slaanesh_msla_warshrine"] = "melee_mage_highvalue|war_beast|com|0",
    ["wh3_dlc27_chs_feral_manticore_boss"] = "flying_melee_flanker_shock|inf_melee|inf_mel|1",
    ["wh3_dlc27_cth_mon_celestial_lion_boss"] = "flying_melee_highvalue|inf_melee|inf_mel|1",
    ["wh3_dlc27_def_mon_black_dragon_boss"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh3_dlc27_hef_cha_caradryan"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc27_hef_cha_caradryan_ashtari"] = "flying_melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_dlc27_hef_cha_caradryan_chariot"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh3_dlc27_hef_cha_caradryan_steed"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh3_dlc27_hef_cha_mist_mage"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc27_hef_cha_mist_mage_eagle"] = "flying_melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_dlc27_hef_cha_mist_mage_skycutter"] = "flying_melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_dlc27_hef_cha_sea_helm"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc27_hef_cha_sea_helm_eagle"] = "flying_melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_dlc27_hef_cha_sea_helm_skycutter"] = "flying_melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_dlc27_hef_cha_sea_lord_aislinn"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc27_hef_cha_sea_lord_aislinn_dragon"] = "flying_melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_dlc27_hef_cha_sea_lord_aislinn_skycutter"] = "flying_melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_dlc27_hef_inf_militia_qb"] = "ranged|inf_melee|inf_mel|0",
    ["wh3_dlc27_hef_inf_oceanids"] = "melee|inf_melee|inf_mel|1",
    ["wh3_dlc27_hef_inf_oceanids_split_up_summoned"] = "melee|inf_melee|inf_mel|1",
    ["wh3_dlc27_hef_inf_oceanids_summoned"] = "melee|inf_melee|inf_mel|1",
    ["wh3_dlc27_hef_inf_ships_company"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc27_hef_inf_ships_company_ror"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc27_hef_inf_swordmasters_of_hoeth_ror"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc27_hef_mon_merwyrm"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_dlc27_hef_mon_merwyrm_ror"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_dlc27_hef_mon_merwyrm_summoned"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_dlc27_hef_mon_sea_elemental"] = "melee_gatecrusher_highvalue|inf_melee|inf_mel|1",
    ["wh3_dlc27_hef_veh_skycutter_bolt_thrower"] = "flying_ranged_harasser_flanker|war_beast|chariot|1",
    ["wh3_dlc27_hef_veh_skycutter_bows"] = "flying_ranged_harasser_flanker|war_beast|chariot|1",
    ["wh3_dlc27_lzd_mon_dread_saurian_boss"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_dlc27_nor_cav_chaos_chariot_ror"] = "melee_flanker_shock|war_machine|chariot|1",
    ["wh3_dlc27_nor_cav_kurgan_horsemen_dualweapons"] = "melee_cav_shock|war_beast|cav_shk|1",
    ["wh3_dlc27_nor_cav_kurgan_horsemen_greatweapons"] = "melee_cav_shock|war_beast|cav_shk|1",
    ["wh3_dlc27_nor_cav_marauder_horsemen_ror"] = "ranged_harasser_flanker|war_beast|cav_mis|1",
    ["wh3_dlc27_nor_cha_beorg_bearstruck"] = "melee_highvalue|inf_melee|com|1",
    ["wh3_dlc27_nor_cha_fimir_noble"] = "melee_highvalue|inf_melee|com|1",
    ["wh3_dlc27_nor_cha_great_shaman_sorcerer_death"] = "mage_highvalue|inf_melee|com|0",
    ["wh3_dlc27_nor_cha_great_shaman_sorcerer_death_chariot"] = "mage_highvalue|war_machine|com|1",
    ["wh3_dlc27_nor_cha_great_shaman_sorcerer_death_mammoth"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_dlc27_nor_cha_great_shaman_sorcerer_death_warhorse"] = "mage_highvalue|cavalry|com|1",
    ["wh3_dlc27_nor_cha_great_shaman_sorcerer_fire"] = "mage_highvalue|inf_melee|com|0",
    ["wh3_dlc27_nor_cha_great_shaman_sorcerer_fire_chariot"] = "mage_highvalue|war_machine|com|1",
    ["wh3_dlc27_nor_cha_great_shaman_sorcerer_fire_mammoth"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_dlc27_nor_cha_great_shaman_sorcerer_fire_warhorse"] = "mage_highvalue|cavalry|com|1",
    ["wh3_dlc27_nor_cha_great_shaman_sorcerer_metal"] = "mage_highvalue|inf_melee|com|0",
    ["wh3_dlc27_nor_cha_great_shaman_sorcerer_metal_chariot"] = "mage_highvalue|war_machine|com|1",
    ["wh3_dlc27_nor_cha_great_shaman_sorcerer_metal_mammoth"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_dlc27_nor_cha_great_shaman_sorcerer_metal_warhorse"] = "mage_highvalue|cavalry|com|1",
    ["wh3_dlc27_nor_cha_sayl_the_faithless"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh3_dlc27_nor_cha_sayl_the_faithless_chariot"] = "mage_flanker_highvalue|war_machine|com|1",
    ["wh3_dlc27_nor_cha_sayl_the_faithless_mammoth"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_dlc27_nor_cha_sayl_the_faithless_warhorse"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_dlc27_nor_cha_shaman_sorcerer_death_2_summoned"] = "mage_highvalue|war_machine|com|1",
    ["wh3_dlc27_nor_cha_shaman_sorcerer_fire_2_summoned"] = "mage_highvalue|war_machine|com|1",
    ["wh3_dlc27_nor_cha_shaman_sorcerer_metal_2_summoned"] = "mage_highvalue|war_machine|com|1",
    ["wh3_dlc27_nor_inf_chaos_marauders_great_weapons_ror"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc27_nor_inf_marauder_bearmen"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc27_nor_inf_marauder_bearmen_greatweapons"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc27_nor_mon_chimera"] = "flying_melee_flanker_shock|inf_melee|inf_mel|1",
    ["wh3_dlc27_nor_mon_chimera_boss"] = "flying_melee_flanker_shock|inf_melee|inf_mel|1",
    ["wh3_dlc27_nor_mon_chimera_ror"] = "flying_melee_flanker_shock|inf_melee|inf_mel|1",
    ["wh3_dlc27_nor_mon_cursd_ettin"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_dlc27_nor_mon_cursd_ettin_runecaller"] = "melee_mage_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_dlc27_nor_mon_dread_maw"] = "hybrid_melee_direct_no_skirmish|inf_melee|inf_mel|0",
    ["wh3_dlc27_nor_mon_dread_maw_underground"] = "hybrid_melee_direct_no_skirmish|inf_melee|inf_mel|0",
    ["wh3_dlc27_nur_mon_toad_dragon_boss"] = "melee_gatecrusher_highvalue|inf_melee|inf_mel|1",
    ["wh3_dlc27_ogr_mon_thundertusk_boss"] = "melee_gatecrusher_shock|war_beast|inf_mel|1",
    ["wh3_dlc27_sla_cav_pleasureseekers"] = "melee_flanker_shock|war_beast|cav_shk|1",
    ["wh3_dlc27_sla_cha_alluress_shadow_daemonic_steed"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_dlc27_sla_cha_alluress_slaanesh_daemonic_steed"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_dlc27_sla_cha_dechala"] = "melee_highvalue|inf_melee|com|1",
    ["wh3_dlc27_sla_cha_druchii_anointed"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh3_dlc27_sla_cha_druchii_anointed_cold_one"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh3_dlc27_sla_cha_druchii_anointed_daemonic_steed"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_dlc27_sla_cha_herald_of_slaanesh_shadow_daemonic_steed"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_dlc27_sla_cha_herald_of_slaanesh_slaanesh_daemonic_steed"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_dlc27_sla_cha_masque_of_slaanesh"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_dlc27_sla_cha_styrkaar_the_sortsvinaer"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh3_dlc27_sla_cha_styrkaar_the_sortsvinaer_daemonic_steed"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_dlc27_sla_cha_styrkaar_the_sortsvinaer_steed_of_slaanesh"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_dlc27_sla_inf_chaos_furies_summoned"] = "flying_melee_flanker|inf_melee|inf_mel|0",
    ["wh3_dlc27_sla_inf_devotees_of_slaanesh"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc27_sla_inf_devotees_of_slaanesh_crossbows"] = "ranged_harasser_flanker|inf_ranged|inf_mis|0",
    ["wh3_dlc27_sla_inf_slaangors"] = "melee|inf_melee|inf_mel|0",
    ["wh3_dlc27_sla_inf_vengeful_furies_summoned"] = "flying_melee_flanker|inf_melee|inf_mel|0",
    ["wh3_dlc27_sla_mon_champions_of_slaanesh"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh3_dlc27_sla_mon_champions_of_slaanesh_ror"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh3_dlc27_sla_mon_giant_spawn_of_sla_summoned_i"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_dlc27_sla_mon_preyton"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh3_dlc27_sla_mon_preyton_boss"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh3_dlc27_sla_mon_preyton_ror"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh3_dlc27_sla_veh_seeker_chariot_ror"] = "melee_flanker_shock|war_machine|chariot|1",
    ["wh3_dlc27_tmb_mon_carrion_boss"] = "flying_melee_flanker_shock_undead|inf_melee|inf_mel|1",
    ["wh3_dlc27_tze_mon_cockatrice_boss"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh3_main_chd_art_hobgob_bolt_thrower"] = "ranged_direct_arty|artillery|art_fld|0",
    ["wh3_main_chs_art_hellcannon_prologue"] = "ranged_indirect_arty|artillery|art_fld|0",
    ["wh3_main_cth_art_fire_rain_rocket_battery_0"] = "ranged_indirect_arty|artillery|art_fld|0",
    ["wh3_main_cth_art_grand_cannon_0"] = "ranged_direct_arty|artillery|art_fld|0",
    ["wh3_main_cth_cav_jade_lancers_0"] = "melee_flanker_shock|war_beast|cav_shk|1",
    ["wh3_main_cth_cav_jade_longma_riders_0"] = "flying_melee_flanker_shock|war_beast|cav_shk|1",
    ["wh3_main_cth_cav_peasant_horsemen_0"] = "melee_flanker_shock|war_beast|cav_mel|1",
    ["wh3_main_cth_cha_alchemist_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh3_main_cth_cha_alchemist_1"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_main_cth_cha_alchemist_2"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_main_cth_cha_astromancer_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh3_main_cth_cha_astromancer_1"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_main_cth_cha_astromancer_2"] = "mage_highvalue|war_machine|com|1",
    ["wh3_main_cth_cha_dragon_blooded_shugengan_lord_yang_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh3_main_cth_cha_dragon_blooded_shugengan_lord_yang_1"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_main_cth_cha_dragon_blooded_shugengan_lord_yang_2"] = "flying_mage_highvalue|war_beast|com|1",
    ["wh3_main_cth_cha_dragon_blooded_shugengan_lord_yin_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh3_main_cth_cha_dragon_blooded_shugengan_lord_yin_1"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_main_cth_cha_dragon_blooded_shugengan_lord_yin_2"] = "flying_mage_highvalue|war_beast|com|1",
    ["wh3_main_cth_cha_iron_dragon_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_main_cth_cha_iron_dragon_1"] = "flying_melee_highvalue|inf_melee|com|1",
    ["wh3_main_cth_cha_lord_magistrate_0"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh3_main_cth_cha_lord_magistrate_1"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_main_cth_cha_lord_magistrate_2"] = "flying_hybrid_highvalue|war_beast|com|1",
    ["wh3_main_cth_cha_storm_dragon_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_main_cth_cha_storm_dragon_1"] = "flying_melee_highvalue|inf_melee|com|1",
    ["wh3_main_cth_inf_ancestral_warriors_summoned_0"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh3_main_cth_inf_crane_gunners_0"] = "ranged_direct|inf_ranged|inf_mis|0",
    ["wh3_main_cth_inf_dragon_guard_0"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh3_main_cth_inf_dragon_guard_crossbowmen_0"] = "ranged_no_skirmish|inf_ranged|inf_mis|0",
    ["wh3_main_cth_inf_grenadiers"] = "ranged_direct_no_skirmish|inf_ranged|inf_mis|0",
    ["wh3_main_cth_inf_iron_hail_gunners_0"] = "ranged_direct|inf_ranged|inf_mis|0",
    ["wh3_main_cth_inf_jade_warrior_crossbowmen_0"] = "ranged_no_skirmish|inf_ranged|inf_mis|0",
    ["wh3_main_cth_inf_jade_warrior_crossbowmen_1"] = "ranged_no_skirmish|inf_ranged|inf_mis|0",
    ["wh3_main_cth_inf_jade_warriors_0"] = "melee|inf_melee|inf_mel|0",
    ["wh3_main_cth_inf_jade_warriors_1"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh3_main_cth_inf_peasant_archers_0"] = "ranged|inf_ranged|inf_mis|0",
    ["wh3_main_cth_inf_peasant_spearmen_1"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh3_main_cth_mon_terracotta_sentinel_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_main_cth_veh_sky_junk_0"] = "sky_junk|war_beast|inf_mis|1",
    ["wh3_main_cth_veh_sky_lantern_0"] = "sky_lantern|war_beast|inf_mis|1",
    ["wh3_main_cth_veh_war_compass_0"] = "mage_highvalue|war_machine|chariot|1",
    ["wh3_main_dae_cha_be_lakor_0"] = "flying_melee_highvalue|inf_melee|com|1",
    ["wh3_main_dae_cha_daemon_prince_0"] = "melee_highvalue|inf_melee|com|1",
    ["wh3_main_dae_cha_daemon_prince_MP"] = "melee_highvalue|inf_melee|com|1",
    ["wh3_main_dae_cha_daemon_prince_khorne_0"] = "melee_highvalue|inf_melee|com|1",
    ["wh3_main_dae_cha_daemon_prince_khorne_MP"] = "flying_melee_highvalue|inf_melee|com|1",
    ["wh3_main_dae_cha_daemon_prince_nurgle_0"] = "melee_highvalue|inf_melee|com|1",
    ["wh3_main_dae_cha_daemon_prince_nurgle_MP"] = "melee_highvalue|inf_melee|com|1",
    ["wh3_main_dae_cha_daemon_prince_slaanesh_0"] = "melee_highvalue|inf_melee|com|1",
    ["wh3_main_dae_cha_daemon_prince_slaanesh_MP"] = "flying_melee_highvalue|inf_melee|com|1",
    ["wh3_main_dae_cha_daemon_prince_tzeentch_0"] = "melee_highvalue|inf_melee|com|1",
    ["wh3_main_dae_cha_daemon_prince_tzeentch_MP"] = "flying_melee_highvalue|inf_melee|com|1",
    ["wh3_main_dae_inf_chaos_furies_0"] = "flying_melee_flanker|inf_melee|inf_mel|0",
    ["wh3_main_dae_inf_chaos_furies_summoned_0"] = "flying_melee_flanker|inf_melee|inf_mel|0",
    ["wh3_main_grn_inf_goblins_sword_shield"] = "melee|inf_melee|inf_mel|0",
    ["wh3_main_grn_inf_orc_boyz_spear_shield"] = "melee|inf_melee|inf_mel|0",
    ["wh3_main_ie_nor_cha_exalted_great_unclean_one_burplesmirk_spewpit"] = "melee_gatecrusher_highvalue|inf_melee|com|1",
    ["wh3_main_ie_nor_cha_exalted_hero_mkho_killgore_slaymaim"] = "melee_cav_shock_highvalue|cavalry|com|1",
    ["wh3_main_kho_cav_bloodcrushers_0"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh3_main_kho_cav_gorebeast_chariot"] = "melee_flanker_shock|war_machine|chariot|1",
    ["wh3_main_kho_cav_skullcrushers_0"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh3_main_kho_cha_bloodreaper_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_main_kho_cha_bloodreaper_1"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh3_main_kho_cha_bloodreaper_2"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_main_kho_cha_cultist_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_main_kho_cha_cultist_1"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_main_kho_cha_exalted_bloodthirster_0"] = "flying_melee_highvalue|inf_melee|com|1",
    ["wh3_main_kho_cha_herald_of_khorne_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_main_kho_cha_herald_of_khorne_1"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh3_main_kho_cha_herald_of_khorne_2"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_main_kho_cha_skarbrand_0"] = "melee_highvalue|inf_melee|com|1",
    ["wh3_main_kho_inf_bloodletters_0"] = "melee|inf_melee|inf_mel|0",
    ["wh3_main_kho_inf_bloodletters_1"] = "melee|inf_melee|inf_mel|0",
    ["wh3_main_kho_inf_bloodletters_summoned_0"] = "melee|inf_melee|inf_mel|0",
    ["wh3_main_kho_inf_chaos_furies_0"] = "flying_melee_flanker|inf_melee|inf_mel|0",
    ["wh3_main_kho_inf_chaos_warhounds_0"] = "melee_flanker|inf_melee|inf_mel|0",
    ["wh3_main_kho_inf_chaos_warriors_0"] = "melee|inf_melee|inf_mel|0",
    ["wh3_main_kho_inf_chaos_warriors_1"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh3_main_kho_inf_chaos_warriors_2"] = "melee|inf_melee|inf_mel|0",
    ["wh3_main_kho_inf_flesh_hounds_of_khorne_0"] = "melee_flanker_shock|inf_melee|spcl|1",
    ["wh3_main_kho_mon_bloodthirster_0"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh3_main_kho_mon_bloodthirster_summoned_0"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh3_main_kho_mon_khornataurs_0"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh3_main_kho_mon_khornataurs_1"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh3_main_kho_mon_soul_grinder_0"] = "hybrid_gatecrusher|inf_ranged|spcl|1",
    ["wh3_main_kho_mon_spawn_of_khorne_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_main_kho_veh_blood_shrine_0"] = "melee_flanker_shock_highvalue|war_beast|chariot|1",
    ["wh3_main_kho_veh_skullcannon_0"] = "hybrid_direct_shock_arty|war_beast|chariot|1",
    ["wh3_main_ksl_cav_gryphon_legion_0"] = "melee_flanker_shock_highvalue|war_beast|cav_shk|1",
    ["wh3_main_ksl_cav_horse_archers_0"] = "ranged_harasser_flanker|war_beast|cav_mis|1",
    ["wh3_main_ksl_cav_kossovite_dervishes_0"] = "melee_flanker_shock_highvalue|war_beast|cav_mel|1",
    ["wh3_main_ksl_cav_war_bear_riders_1"] = "melee_flanker_shock_highvalue|war_beast|cav_mel|1",
    ["wh3_main_ksl_cav_winged_lancers_0"] = "melee_flanker_shock_highvalue|war_beast|cav_shk|1",
    ["wh3_main_ksl_cha_ataman"] = "hybrid_highvalue|inf_melee|com|0",
    ["wh3_main_ksl_cha_boris_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_main_ksl_cha_boris_1"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_main_ksl_cha_boris_2"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_main_ksl_cha_boyar_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_main_ksl_cha_boyar_1"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_main_ksl_cha_boyar_2"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_main_ksl_cha_frost_maiden_ice_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh3_main_ksl_cha_frost_maiden_ice_1"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_main_ksl_cha_frost_maiden_ice_2"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_main_ksl_cha_frost_maiden_tempest_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh3_main_ksl_cha_frost_maiden_tempest_1"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_main_ksl_cha_frost_maiden_tempest_2"] = "melee_highvalue|war_beast|com|1",
    ["wh3_main_ksl_cha_ice_witch_ice_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh3_main_ksl_cha_ice_witch_ice_1"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_main_ksl_cha_ice_witch_ice_2"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_main_ksl_cha_ice_witch_tempest_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh3_main_ksl_cha_ice_witch_tempest_1"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_main_ksl_cha_ice_witch_tempest_2"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_main_ksl_cha_katarin_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh3_main_ksl_cha_katarin_1"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_main_ksl_cha_katarin_2"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_main_ksl_cha_kostaltyn_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_main_ksl_cha_kostaltyn_1"] = "melee_highvalue|war_beast|com|1",
    ["wh3_main_ksl_cha_kostaltyn_2"] = "melee_highvalue|war_beast|com|1",
    ["wh3_main_ksl_cha_patriarch_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_main_ksl_cha_patriarch_1"] = "melee_highvalue|war_beast|com|1",
    ["wh3_main_ksl_cha_patriarch_2"] = "melee_highvalue|war_beast|com|1",
    ["wh3_main_ksl_inf_armoured_kossars_0"] = "hybrid_melee|inf_ranged|inf_mis|0",
    ["wh3_main_ksl_inf_armoured_kossars_1"] = "hybrid_melee|inf_ranged|inf_mis|0",
    ["wh3_main_ksl_inf_ice_guard_0"] = "hybrid_melee|inf_ranged|inf_mis|0",
    ["wh3_main_ksl_inf_ice_guard_1"] = "hybrid_melee|inf_ranged|inf_mis|0",
    ["wh3_main_ksl_inf_kossars_0"] = "hybrid|inf_ranged|inf_mis|0",
    ["wh3_main_ksl_inf_kossars_1"] = "hybrid_melee|inf_ranged|inf_mis|0",
    ["wh3_main_ksl_inf_kossars_tutorial_0"] = "melee|inf_melee|inf_mel|0",
    ["wh3_main_ksl_inf_kossars_tutorial_1"] = "melee_anti_large|inf_melee|inf_spr|0",
    ["wh3_main_ksl_inf_streltsi_0"] = "hybrid|inf_ranged|inf_mis|0",
    ["wh3_main_ksl_inf_tzar_guard_0"] = "melee|inf_melee|inf_mel|0",
    ["wh3_main_ksl_inf_tzar_guard_1"] = "melee|inf_melee|inf_mel|0",
    ["wh3_main_ksl_mon_elemental_bear_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_main_ksl_mon_elemental_bear_summoned_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_main_ksl_mon_snow_leopard_0"] = "melee_flanker_shock_highvalue|inf_melee|inf_mel|1",
    ["wh3_main_ksl_mon_snow_leopard_summoned_0"] = "melee_flanker_shock|inf_melee|inf_mel|1",
    ["wh3_main_ksl_mon_snow_leopard_summoned_1"] = "melee_flanker_shock|inf_melee|inf_mel|1",
    ["wh3_main_ksl_mon_snow_leopard_summoned_2"] = "melee_flanker_shock|inf_melee|inf_mel|1",
    ["wh3_main_ksl_veh_heavy_war_sled_0"] = "hybrid_flanker_shock_harasser_highvalue|war_machine|chariot|1",
    ["wh3_main_ksl_veh_light_war_sled_0"] = "hybrid_flanker_shock_harasser_highvalue|war_machine|chariot|1",
    ["wh3_main_ksl_veh_little_grom_0"] = "ranged_indirect_arty|war_machine|chariot|1",
    ["wh3_main_monster_feral_bears"] = "melee_flanker|inf_melee|inf_mel|1",
    ["wh3_main_monster_feral_ice_bears"] = "melee_flanker|inf_melee|inf_mel|1",
    ["wh3_main_nur_cav_plague_drones_0"] = "flying_melee_flanker|cavalry|cav_mel|1",
    ["wh3_main_nur_cav_plague_drones_1"] = "flying_ranged_flanker|cavalry|cav_mis|1",
    ["wh3_main_nur_cav_pox_riders_of_nurgle_0"] = "melee_flanker|cavalry|cav_mel|1",
    ["wh3_main_nur_cha_cultist_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_main_nur_cha_cultist_1"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh3_main_nur_cha_exalted_great_unclean_one_death_0"] = "melee_gatecrusher_highvalue|inf_melee|com|1",
    ["wh3_main_nur_cha_exalted_great_unclean_one_nurgle_0"] = "melee_gatecrusher_highvalue|inf_melee|com|1",
    ["wh3_main_nur_cha_herald_of_nurgle_death_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_main_nur_cha_herald_of_nurgle_death_1"] = "melee_highvalue|cavalry|com|1",
    ["wh3_main_nur_cha_herald_of_nurgle_death_2"] = "flying_melee_highvalue|cavalry|com|1",
    ["wh3_main_nur_cha_herald_of_nurgle_nurgle_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_main_nur_cha_herald_of_nurgle_nurgle_1"] = "melee_highvalue|cavalry|com|1",
    ["wh3_main_nur_cha_herald_of_nurgle_nurgle_2"] = "flying_melee_highvalue|cavalry|com|1",
    ["wh3_main_nur_cha_ku_gath_plaguefather_0"] = "hybrid_highvalue|war_beast|com|1",
    ["wh3_main_nur_cha_plagueridden_death_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_main_nur_cha_plagueridden_death_1"] = "melee_highvalue|cavalry|com|1",
    ["wh3_main_nur_cha_plagueridden_death_2"] = "flying_melee_highvalue|cavalry|com|1",
    ["wh3_main_nur_cha_plagueridden_nurgle_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_main_nur_cha_plagueridden_nurgle_1"] = "melee_highvalue|cavalry|com|1",
    ["wh3_main_nur_cha_plagueridden_nurgle_2"] = "flying_melee_highvalue|cavalry|com|1",
    ["wh3_main_nur_inf_chaos_furies_0"] = "flying_melee_flanker|inf_melee|inf_mel|0",
    ["wh3_main_nur_inf_forsaken_0"] = "melee|inf_melee|inf_mel|0",
    ["wh3_main_nur_inf_nurglings_0"] = "melee|inf_melee|inf_mel|0",
    ["wh3_main_nur_inf_nurglings_summoned_0"] = "melee|inf_melee|inf_mel|0",
    ["wh3_main_nur_inf_plaguebearers_0"] = "melee|inf_melee|inf_mel|0",
    ["wh3_main_nur_inf_plaguebearers_1"] = "melee|inf_melee|inf_mel|0",
    ["wh3_main_nur_inf_plaguebearers_1_summoned"] = "melee|inf_melee|inf_mel|0",
    ["wh3_main_nur_inf_plaguebearers_summoned_0"] = "melee|inf_melee|inf_mel|0",
    ["wh3_main_nur_mon_beast_of_nurgle_0"] = "melee_gatecrusher_highvalue|inf_melee|inf_mel|1",
    ["wh3_main_nur_mon_great_unclean_one_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_main_nur_mon_great_unclean_one_summoned_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_main_nur_mon_plague_toads_0"] = "melee_flanker|inf_melee|inf_mel|1",
    ["wh3_main_nur_mon_rot_flies_0"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh3_main_nur_mon_soul_grinder_0"] = "ranged_no_skirmish_gatecrusher|inf_ranged|spcl|1",
    ["wh3_main_nur_mon_spawn_of_nurgle_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_main_nur_mon_spawn_of_nurgle_0_summoned"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_main_ogr_cav_crushers_0"] = "melee_gatecrusher_flanker_shock|cavalry|inf_mel|1",
    ["wh3_main_ogr_cav_crushers_1"] = "melee_gatecrusher_flanker_shock|cavalry|inf_mel|1",
    ["wh3_main_ogr_cav_mournfang_cavalry_0"] = "melee_gatecrusher_flanker_shock|cavalry|inf_mel|1",
    ["wh3_main_ogr_cav_mournfang_cavalry_1"] = "melee_gatecrusher_flanker_shock|cavalry|inf_mel|1",
    ["wh3_main_ogr_cav_mournfang_cavalry_2"] = "melee_gatecrusher_flanker_shock|cavalry|inf_mel|1",
    ["wh3_main_ogr_cha_butcher_beasts_0"] = "melee_gatecrusher_highvalue|inf_melee|com|1",
    ["wh3_main_ogr_cha_butcher_great_maw_0"] = "melee_gatecrusher_highvalue|inf_melee|com|1",
    ["wh3_main_ogr_cha_firebelly_0"] = "melee_gatecrusher_highvalue|inf_melee|com|1",
    ["wh3_main_ogr_cha_greasus_goldtooth_0"] = "melee_gatecrusher_highvalue|inf_melee|com|1",
    ["wh3_main_ogr_cha_hunter_0"] = "hybrid_gatecrusher_highvalue|inf_melee|com|1",
    ["wh3_main_ogr_cha_hunter_1"] = "melee_gatecrusher_highvalue|war_beast|com|1",
    ["wh3_main_ogr_cha_skrag_the_slaughterer_0"] = "melee_gatecrusher_highvalue|inf_melee|com|1",
    ["wh3_main_ogr_cha_slaughtermaster_beasts_0"] = "melee_gatecrusher_highvalue|inf_melee|com|1",
    ["wh3_main_ogr_cha_slaughtermaster_great_maw_0"] = "melee_gatecrusher_highvalue|inf_melee|com|1",
    ["wh3_main_ogr_cha_tyrant_0"] = "melee_gatecrusher_highvalue|inf_melee|com|1",
    ["wh3_main_ogr_feral_manticore_summoned"] = "flying_melee_flanker_shock|inf_melee|inf_mel|1",
    ["wh3_main_ogr_inf_gnoblars_0"] = "melee|inf_melee|inf_mel|0",
    ["wh3_main_ogr_inf_gnoblars_1"] = "hybrid_lowvalue|inf_melee|inf_mel|0",
    ["wh3_main_ogr_inf_gnoblars_flingers"] = "ranged_harasser|inf_ranged|inf_mis|0",
    ["wh3_main_ogr_inf_ironguts_0"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh3_main_ogr_inf_leadbelchers_0"] = "ranged_direct_gatecrusher|inf_ranged|inf_mis|1",
    ["wh3_main_ogr_inf_maneaters_0"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh3_main_ogr_inf_maneaters_1"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh3_main_ogr_inf_maneaters_2"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh3_main_ogr_inf_maneaters_3"] = "hybrid_gatecrusher|inf_ranged|inf_mis|1",
    ["wh3_main_ogr_inf_maneaters_summoned_0"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh3_main_ogr_inf_ogres_0"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh3_main_ogr_inf_ogres_1"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh3_main_ogr_inf_ogres_2"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh3_main_ogr_mon_giant_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_main_ogr_mon_gorgers_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_main_ogr_mon_gorgers_summoned_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_main_ogr_mon_sabretusk_pack_0"] = "melee_flanker_shock|inf_melee|spcl|1",
    ["wh3_main_ogr_mon_stonehorn_0"] = "melee_gatecrusher_shock|war_beast|inf_mel|1",
    ["wh3_main_ogr_mon_stonehorn_1"] = "melee_gatecrusher_shock|war_beast|inf_mel|1",
    ["wh3_main_ogr_veh_gnoblar_scraplauncher_0"] = "ranged_direct_arty|war_machine|chariot|1",
    ["wh3_main_ogr_veh_ironblaster_0"] = "ranged_direct_arty|war_machine|chariot|1",
    ["wh3_main_pro_kho_cha_bloodreaper_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_main_pro_kho_cha_bloodreaper_1"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh3_main_pro_kho_cha_bloodreaper_2"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_main_pro_kho_cha_cultist_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_main_pro_kho_cha_cultist_1"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_main_pro_kho_cha_herald_of_khorne_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_main_pro_kho_cha_herald_of_khorne_1"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh3_main_pro_kho_cha_herald_of_khorne_2"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_main_pro_kho_inf_bloodletters_0"] = "melee|inf_melee|inf_mel|0",
    ["wh3_main_pro_kho_inf_chaos_furies_0"] = "flying_melee_flanker|inf_melee|inf_mel|0",
    ["wh3_main_pro_kho_inf_chaos_warhounds_0"] = "melee_flanker|inf_melee|inf_mel|0",
    ["wh3_main_pro_kho_inf_chaos_warriors_0"] = "melee|inf_melee|inf_mel|0",
    ["wh3_main_pro_kho_inf_flesh_hounds_of_khorne_0"] = "melee_flanker_shock|inf_melee|spcl|1",
    ["wh3_main_pro_kho_inf_flesh_hounds_of_khorne_simaergul_0"] = "melee_flanker_shock|inf_melee|spcl|1",
    ["wh3_main_pro_ksl_cav_kossovite_dervishes_0"] = "melee_flanker_shock_highvalue|war_beast|cav_mel|1",
    ["wh3_main_pro_ksl_cav_war_bear_riders_1"] = "melee_flanker_shock_highvalue|war_beast|cav_mel|1",
    ["wh3_main_pro_ksl_cav_winged_lancers_0"] = "melee_flanker_shock_highvalue|war_beast|cav_shk|1",
    ["wh3_main_pro_ksl_cha_boyar_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_main_pro_ksl_cha_boyar_1"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_main_pro_ksl_cha_boyar_2"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_main_pro_ksl_cha_frost_maiden_ice_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh3_main_pro_ksl_cha_frost_maiden_ice_1"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_main_pro_ksl_cha_frost_maiden_ice_2"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh3_main_pro_ksl_cha_gerik_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_main_pro_ksl_cha_patriarch_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_main_pro_ksl_cha_patriarch_1"] = "melee_highvalue|war_beast|com|1",
    ["wh3_main_pro_ksl_cha_patriarch_2"] = "melee_highvalue|war_beast|com|1",
    ["wh3_main_pro_ksl_cha_sergi_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_main_pro_ksl_cha_slavin_0"] = "melee_cav_shock_highvalue|war_beast|com|1",
    ["wh3_main_pro_ksl_cha_yuri_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_main_pro_ksl_cha_yuri_1"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_main_pro_ksl_cha_yuri_2"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_main_pro_ksl_cha_yuri_3"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_main_pro_ksl_cha_yuri_4"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_main_pro_ksl_cha_yuri_5"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_main_pro_ksl_cha_yuri_5_brazen_altar"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_main_pro_ksl_cha_yuri_5_howling_citadel"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_main_pro_ksl_inf_armoured_kossars_0"] = "melee|inf_ranged|inf_mis|0",
    ["wh3_main_pro_ksl_inf_armoured_kossars_1"] = "melee|inf_ranged|inf_mis|0",
    ["wh3_main_pro_ksl_inf_kossars_0"] = "hybrid|inf_ranged|inf_mis|0",
    ["wh3_main_pro_ksl_inf_kossars_1"] = "hybrid|inf_ranged|inf_mis|0",
    ["wh3_main_pro_ksl_inf_streltsi_0"] = "hybrid|inf_ranged|inf_mis|0",
    ["wh3_main_pro_ksl_inf_tzar_guard_0"] = "melee|inf_melee|inf_mel|0",
    ["wh3_main_pro_ksl_mon_elemental_bear_ror_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_main_pro_ksl_veh_little_grom_0"] = "ranged_direct_arty|war_machine|chariot|1",
    ["wh3_main_pro_tze_cav_chaos_knights_0"] = "melee_flanker|war_beast|cav_mel|1",
    ["wh3_main_pro_tze_cha_cultist_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh3_main_pro_tze_cha_cultist_1"] = "mage_highvalue|cavalry|com|1",
    ["wh3_main_pro_tze_cha_herald_of_tzeentch_tzeentch_0"] = "ranged_highvalue|inf_melee|com|0",
    ["wh3_main_pro_tze_cha_herald_of_tzeentch_tzeentch_1"] = "flying_ranged_harasser_flanker_highvalue|inf_melee|com|1",
    ["wh3_main_pro_tze_cha_herald_of_tzeentch_tzeentch_2"] = "flying_ranged_harasser_flanker_highvalue|war_beast|com|1",
    ["wh3_main_pro_tze_inf_blue_horrors_0"] = "hybrid|inf_ranged|inf_mis|0",
    ["wh3_main_pro_tze_inf_pink_horrors_0"] = "ranged_no_skirmish|inf_ranged|inf_mis|0",
    ["wh3_main_pro_tze_mon_flamers_0"] = "ranged_direct|inf_ranged|inf_mis|1",
    ["wh3_main_pro_tze_mon_screamers_0"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh3_main_sla_cav_heartseekers_of_slaanesh_0"] = "melee_flanker_shock|war_beast|cav_shk|1",
    ["wh3_main_sla_cav_hellstriders_0"] = "melee_flanker_shock|war_beast|cav_shk|1",
    ["wh3_main_sla_cav_hellstriders_1"] = "melee_flanker_shock|war_beast|cav_shk|1",
    ["wh3_main_sla_cav_seekers_of_slaanesh_0"] = "melee_flanker_shock|war_beast|cav_shk|1",
    ["wh3_main_sla_cha_alluress_shadow_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_main_sla_cha_alluress_shadow_1"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_main_sla_cha_alluress_shadow_2"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh3_main_sla_cha_alluress_shadow_3"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh3_main_sla_cha_alluress_slaanesh_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_main_sla_cha_alluress_slaanesh_1"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_main_sla_cha_alluress_slaanesh_2"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh3_main_sla_cha_alluress_slaanesh_3"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh3_main_sla_cha_cultist_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_main_sla_cha_cultist_1"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh3_main_sla_cha_exalted_keeper_of_secrets_shadow_0"] = "melee_highvalue|inf_melee|com|1",
    ["wh3_main_sla_cha_exalted_keeper_of_secrets_slaanesh_0"] = "melee_highvalue|inf_melee|com|1",
    ["wh3_main_sla_cha_herald_of_slaanesh_shadow_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_main_sla_cha_herald_of_slaanesh_shadow_1"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_main_sla_cha_herald_of_slaanesh_shadow_2"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh3_main_sla_cha_herald_of_slaanesh_shadow_3"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh3_main_sla_cha_herald_of_slaanesh_slaanesh_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_main_sla_cha_herald_of_slaanesh_slaanesh_1"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_main_sla_cha_herald_of_slaanesh_slaanesh_2"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh3_main_sla_cha_herald_of_slaanesh_slaanesh_3"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh3_main_sla_cha_nkari_0"] = "melee_highvalue|inf_melee|com|1",
    ["wh3_main_sla_inf_chaos_furies_0"] = "flying_melee_flanker|inf_melee|inf_mel|0",
    ["wh3_main_sla_inf_daemonette_0"] = "melee|inf_melee|inf_mel|0",
    ["wh3_main_sla_inf_daemonette_1"] = "melee|inf_melee|inf_mel|0",
    ["wh3_main_sla_inf_daemonette_summoned_0"] = "melee|inf_melee|inf_mel|0",
    ["wh3_main_sla_inf_marauders_0"] = "melee|inf_melee|inf_mel|0",
    ["wh3_main_sla_inf_marauders_1"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh3_main_sla_inf_marauders_2"] = "melee|inf_melee|inf_mel|0",
    ["wh3_main_sla_mon_fiends_of_slaanesh_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_main_sla_mon_keeper_of_secrets_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_main_sla_mon_keeper_of_secrets_summoned_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_main_sla_mon_soul_grinder_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_main_sla_mon_spawn_of_slaanesh_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_main_sla_veh_exalted_seeker_chariot_0"] = "melee_flanker_shock|war_machine|chariot|1",
    ["wh3_main_sla_veh_hellflayer_0"] = "melee_flanker_shock|war_machine|chariot|1",
    ["wh3_main_sla_veh_seeker_chariot_0"] = "melee_flanker_shock|war_machine|chariot|1",
    ["wh3_main_tze_cav_chaos_knights_0"] = "melee_flanker|war_beast|cav_mel|1",
    ["wh3_main_tze_cav_doom_knights_0"] = "flying_melee_flanker_shock|inf_melee|inf_mel|1",
    ["wh3_main_tze_cha_cultist_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh3_main_tze_cha_cultist_1"] = "mage_highvalue|cavalry|com|1",
    ["wh3_main_tze_cha_exalted_lord_of_change_metal_0"] = "flying_melee_highvalue|inf_melee|com|1",
    ["wh3_main_tze_cha_exalted_lord_of_change_tzeentch_0"] = "flying_melee_highvalue|inf_melee|com|1",
    ["wh3_main_tze_cha_herald_of_tzeentch_metal_0"] = "ranged_highvalue|inf_melee|com|0",
    ["wh3_main_tze_cha_herald_of_tzeentch_metal_1"] = "flying_ranged_harasser_flanker_highvalue|inf_melee|com|1",
    ["wh3_main_tze_cha_herald_of_tzeentch_metal_2"] = "flying_ranged_harasser_flanker_highvalue|war_beast|com|1",
    ["wh3_main_tze_cha_herald_of_tzeentch_tzeentch_0"] = "ranged_highvalue|inf_melee|com|0",
    ["wh3_main_tze_cha_herald_of_tzeentch_tzeentch_1"] = "flying_ranged_harasser_flanker_highvalue|inf_melee|com|1",
    ["wh3_main_tze_cha_herald_of_tzeentch_tzeentch_2"] = "flying_ranged_harasser_flanker_highvalue|war_beast|com|1",
    ["wh3_main_tze_cha_iridescent_horror_metal_0"] = "ranged_highvalue|inf_melee|com|0",
    ["wh3_main_tze_cha_iridescent_horror_metal_1"] = "flying_ranged_harasser_flanker_highvalue|inf_melee|com|1",
    ["wh3_main_tze_cha_iridescent_horror_metal_2"] = "flying_ranged_harasser_flanker_highvalue|war_beast|com|1",
    ["wh3_main_tze_cha_iridescent_horror_tzeentch_0"] = "ranged_highvalue|inf_melee|com|0",
    ["wh3_main_tze_cha_iridescent_horror_tzeentch_1"] = "flying_ranged_harasser_flanker_highvalue|inf_melee|com|1",
    ["wh3_main_tze_cha_iridescent_horror_tzeentch_2"] = "flying_ranged_harasser_flanker_highvalue|war_beast|com|1",
    ["wh3_main_tze_cha_kairos_fateweaver_0"] = "flying_melee_highvalue|inf_melee|com|1",
    ["wh3_main_tze_inf_blue_horrors_0"] = "hybrid|inf_ranged|inf_mis|0",
    ["wh3_main_tze_inf_blue_horrors_summoned_0"] = "hybrid|inf_ranged|inf_mis|0",
    ["wh3_main_tze_inf_chaos_furies_0"] = "flying_melee_flanker|inf_melee|inf_mel|0",
    ["wh3_main_tze_inf_forsaken_0"] = "melee|inf_melee|inf_mel|0",
    ["wh3_main_tze_inf_pink_horrors_0"] = "ranged_no_skirmish|inf_ranged|inf_mis|0",
    ["wh3_main_tze_inf_pink_horrors_1"] = "ranged_no_skirmish|inf_ranged|inf_mis|0",
    ["wh3_main_tze_inf_pink_horrors_summoned_0"] = "ranged_no_skirmish|inf_ranged|inf_mis|0",
    ["wh3_main_tze_mon_exalted_flamer_0"] = "ranged_direct|inf_ranged|inf_mis|1",
    ["wh3_main_tze_mon_flamers_0"] = "ranged_direct|inf_ranged|inf_mis|1",
    ["wh3_main_tze_mon_lord_of_change_0"] = "flying_melee|inf_melee|inf_mel|1",
    ["wh3_main_tze_mon_lord_of_change_summoned_0"] = "flying_melee|inf_melee|inf_mel|1",
    ["wh3_main_tze_mon_screamers_0"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh3_main_tze_mon_soul_grinder_0"] = "hybrid_direct_shock_arty_gatecrusher|inf_ranged|spcl|1",
    ["wh3_main_tze_mon_spawn_of_tzeentch_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_main_tze_veh_burning_chariot_0"] = "flying_ranged_harasser_flanker|war_beast|chariot|1",
    ["wh3_main_vmp_blood_knights_sword_shield"] = "melee_flanker_undead|cavalry|cav_mel|1",
    ["wh3_main_vmp_inf_grave_guard_2"] = "melee_undead|inf_melee|inf_mel|0",
    ["wh3_pro10_tze_cha_cultist_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh3_pro10_tze_cha_daemon_prince_of_tzeentch"] = "melee_highvalue|inf_melee|com|1",
    ["wh3_pro11_chs_cha_harald_hammerstorm"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_pro12_kho_cha_karanak"] = "melee_flanker_shock_highvalue|inf_melee|com|1",
    ["wh3_pro12_kho_inf_flesh_hounds_of_khorne_summoned"] = "melee_flanker_shock|inf_melee|spcl|1",
    ["wh3_prologue_test_general_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh3_survival_dae_cha_be_lakor_01"] = "flying_melee_highvalue|inf_melee|com|1",
    ["wh3_survival_dae_cha_be_lakor_02"] = "flying_melee_highvalue|inf_melee|com|1",
    ["wh3_survival_kho_cha_bloodreaper"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh3_survival_kho_cha_daemon_prince_of_khorne"] = "melee_highvalue|inf_melee|com|1",
    ["wh3_survival_kho_cha_exalted_bloodthirster"] = "flying_melee_highvalue|inf_melee|com|1",
    ["wh3_survival_kho_cha_exalted_bloodthirster_0"] = "flying_melee_highvalue|inf_melee|com|1",
    ["wh3_survival_nur_cha_daemon_prince_of_nurgle"] = "melee_highvalue|inf_melee|com|1",
    ["wh3_survival_nur_cha_exalted_great_unclean_one_nurgle"] = "melee_gatecrusher_highvalue|inf_melee|com|1",
    ["wh3_survival_nur_cha_exalted_great_unclean_one_nurgle_01"] = "melee_gatecrusher_highvalue|inf_melee|com|1",
    ["wh3_survival_nur_cha_plagueridden_death"] = "flying_melee_highvalue|cavalry|com|1",
    ["wh3_survival_sla_cha_alluress_shadow"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh3_survival_sla_cha_daemon_prince_of_slaanesh"] = "melee_highvalue|inf_melee|com|1",
    ["wh3_survival_sla_cha_exalted_keeper_of_secrets_slaanesh"] = "melee_highvalue|inf_melee|com|1",
    ["wh3_survival_tze_cha_daemon_prince_of_tzeentch"] = "melee_highvalue|inf_melee|com|1",
    ["wh3_survival_tze_cha_exalted_lord_of_change_tzeentch"] = "flying_melee_highvalue|inf_melee|com|1",
    ["wh3_survival_tze_cha_iridescent_horror_metal"] = "flying_ranged_harasser_flanker_highvalue|war_beast|com|1",
    ["wh3_twa06_cth_inf_dragon_guard_ror_0"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh3_twa06_kho_inf_bloodletters_ror_0"] = "melee|inf_melee|inf_mel|0",
    ["wh3_twa06_ksl_inf_tzar_guard_ror_0"] = "melee|inf_melee|inf_mel|0",
    ["wh3_twa06_nur_inf_plaguebearers_ror_0"] = "melee|inf_melee|inf_mel|0",
    ["wh3_twa06_ogr_inf_maneaters_ror_0"] = "hybrid_gatecrusher|inf_ranged|inf_mis|1",
    ["wh3_twa06_sla_inf_daemonette_ror_0"] = "melee|inf_melee|inf_mel|0",
    ["wh3_twa06_tze_inf_pink_horrors_ror_0"] = "ranged_no_skirmish|inf_ranged|inf_mis|0",
    ["wh3_twa07_cth_cav_jade_longma_riders_ror_0"] = "flying_melee_flanker_shock|war_beast|cav_shk|1",
    ["wh3_twa07_kho_cav_bloodcrushers_ror_0"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh3_twa07_ksl_cav_war_bear_riders_ror_0"] = "melee_flanker_shock_highvalue|war_beast|cav_mel|1",
    ["wh3_twa07_nur_cav_pox_riders_of_nurgle_ror_0"] = "melee_flanker|cavalry|cav_mel|1",
    ["wh3_twa07_ogr_cav_crushers_ror_0"] = "melee_gatecrusher_flanker_shock|cavalry|inf_mel|1",
    ["wh3_twa07_sla_cav_heartseekers_of_slaanesh_ror_0"] = "melee_flanker_shock|war_beast|cav_shk|1",
    ["wh3_twa07_tze_cav_doom_knights_ror_0"] = "flying_melee_flanker_shock|inf_melee|inf_mel|1",
    ["wh3_twa08_cth_mon_terracotta_sentinel_0_ror"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_twa08_kho_mon_bloodthirster_0_ror"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh3_twa08_ksl_mon_elemental_bear_0_ror"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_twa08_nur_mon_great_unclean_one_0_ror"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_twa08_ogr_mon_stonehorn_0_ror"] = "melee_gatecrusher_shock|war_beast|inf_mel|1",
    ["wh3_twa08_sla_mon_keeper_of_secrets_0_ror"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh3_twa08_tze_mon_lord_of_change_0_ror"] = "flying_melee|inf_melee|inf_mel|1",
    ["wh3_twa10_cth_inf_peasant_archers_ror"] = "hybrid|inf_ranged|inf_mis|0",
    ["wh3_twa10_kho_inf_flesh_hounds_of_khorne_ror"] = "melee_flanker_shock|inf_melee|spcl|1",
    ["wh3_twa10_ksl_inf_armoured_kossars_ror"] = "melee|inf_melee|inf_mel|0",
    ["wh3_twa10_nur_inf_nurglings_ror"] = "melee|inf_melee|inf_mel|0",
    ["wh3_twa10_ogr_inf_gnoblars_ror"] = "melee_stalkers|inf_melee|inf_mel|0",
    ["wh3_twa10_sla_inf_marauders_spears_ror"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh3_twa10_tze_inf_blue_horrors_ror"] = "hybrid|inf_ranged|inf_mis|0",
    ["wh_dlc01_chs_cav_gorebeast_chariot"] = "melee_flanker_shock|war_machine|chariot|1",
    ["wh_dlc01_chs_cha_chaos_lord_10"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh_dlc01_chs_cha_chaos_lord_2"] = "flying_melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh_dlc01_chs_cha_chaos_lord_9"] = "melee_highvalue|war_machine|com|1",
    ["wh_dlc01_chs_cha_chaos_sorcerer_death_8"] = "mage_flanker_highvalue|war_machine|com|1",
    ["wh_dlc01_chs_cha_chaos_sorcerer_fire_8"] = "mage_flanker_highvalue|war_machine|com|1",
    ["wh_dlc01_chs_cha_chaos_sorcerer_lord_death_0"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh_dlc01_chs_cha_chaos_sorcerer_lord_death_10"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh_dlc01_chs_cha_chaos_sorcerer_lord_death_12"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh_dlc01_chs_cha_chaos_sorcerer_lord_death_13"] = "mage_flanker_highvalue|cavalry|com|1",
    ["wh_dlc01_chs_cha_chaos_sorcerer_lord_death_7"] = "mage_flanker_highvalue|war_machine|com|1",
    ["wh_dlc01_chs_cha_chaos_sorcerer_lord_death_8"] = "mage_flanker_highvalue|war_machine|com|1",
    ["wh_dlc01_chs_cha_chaos_sorcerer_lord_death_9"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh_dlc01_chs_cha_chaos_sorcerer_lord_fire_0"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh_dlc01_chs_cha_chaos_sorcerer_lord_fire_10"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh_dlc01_chs_cha_chaos_sorcerer_lord_fire_12"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh_dlc01_chs_cha_chaos_sorcerer_lord_fire_13"] = "mage_flanker_highvalue|cavalry|com|1",
    ["wh_dlc01_chs_cha_chaos_sorcerer_lord_fire_7"] = "mage_flanker_highvalue|war_machine|com|1",
    ["wh_dlc01_chs_cha_chaos_sorcerer_lord_fire_8"] = "mage_flanker_highvalue|war_machine|com|1",
    ["wh_dlc01_chs_cha_chaos_sorcerer_lord_fire_9"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh_dlc01_chs_cha_chaos_sorcerer_lord_metal_0"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh_dlc01_chs_cha_chaos_sorcerer_lord_metal_10"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh_dlc01_chs_cha_chaos_sorcerer_lord_metal_12"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh_dlc01_chs_cha_chaos_sorcerer_lord_metal_13"] = "mage_flanker_highvalue|cavalry|com|1",
    ["wh_dlc01_chs_cha_chaos_sorcerer_lord_metal_7"] = "mage_flanker_highvalue|war_machine|com|1",
    ["wh_dlc01_chs_cha_chaos_sorcerer_lord_metal_8"] = "mage_flanker_highvalue|war_machine|com|1",
    ["wh_dlc01_chs_cha_chaos_sorcerer_lord_metal_9"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh_dlc01_chs_cha_chaos_sorcerer_lord_shadows_0"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh_dlc01_chs_cha_chaos_sorcerer_lord_shadows_1"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh_dlc01_chs_cha_chaos_sorcerer_lord_shadows_2"] = "mage_flanker_highvalue|cavalry|com|1",
    ["wh_dlc01_chs_cha_chaos_sorcerer_lord_shadows_3"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh_dlc01_chs_cha_chaos_sorcerer_lord_shadows_4"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh_dlc01_chs_cha_chaos_sorcerer_metal_8"] = "mage_flanker_highvalue|war_machine|com|1",
    ["wh_dlc01_chs_cha_chaos_sorcerer_shadows_0"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh_dlc01_chs_cha_chaos_sorcerer_shadows_1"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh_dlc01_chs_cha_chaos_sorcerer_shadows_2"] = "mage_flanker_highvalue|cavalry|com|1",
    ["wh_dlc01_chs_cha_chaos_sorcerer_shadows_3"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh_dlc01_chs_cha_exalted_hero_10"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh_dlc01_chs_cha_exalted_hero_8"] = "melee_highvalue|war_machine|com|1",
    ["wh_dlc01_chs_cha_kholek"] = "melee_highvalue|inf_melee|com|1",
    ["wh_dlc01_chs_cha_prince_sigvald_the_magnificent"] = "melee_highvalue|inf_melee|com|0",
    ["wh_dlc01_chs_cha_qb_lord_of_change_0"] = "flying_melee_highvalue|inf_melee|com|1",
    ["wh_dlc01_chs_inf_chaos_warriors_2"] = "melee|inf_melee|inf_mel|0",
    ["wh_dlc01_chs_inf_chosen_2"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh_dlc01_chs_inf_forsaken_0"] = "melee|inf_melee|inf_mel|0",
    ["wh_dlc01_chs_mon_dragon_ogre"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh_dlc01_chs_mon_dragon_ogre_shaggoth"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh_dlc01_chs_mon_trolls_1"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh_dlc01_nor_cha_chaos_sorcerer_lord_0"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh_dlc01_nor_cha_chaos_sorcerer_lord_1"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh_dlc01_nor_cha_chaos_sorcerer_lord_2"] = "mage_flanker_highvalue|war_machine|com|1",
    ["wh_dlc02_vmp_cav_blood_knights_0"] = "melee_flanker_shock_undead|cavalry|cav_shk|1",
    ["wh_dlc03_bst_cav_razorgor_chariot_0"] = "melee_flanker_shock|war_machine|chariot|1",
    ["wh_dlc03_bst_cha_beastlord_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_dlc03_bst_cha_beastlord_0_qb"] = "melee_highvalue|inf_melee|com|0",
    ["wh_dlc03_bst_cha_beastlord_1"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh_dlc03_bst_cha_bray_shaman_beasts_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh_dlc03_bst_cha_bray_shaman_beasts_1"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh_dlc03_bst_cha_bray_shaman_death_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh_dlc03_bst_cha_bray_shaman_death_1"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh_dlc03_bst_cha_bray_shaman_shadows_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh_dlc03_bst_cha_bray_shaman_shadows_1"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh_dlc03_bst_cha_bray_shaman_wild_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh_dlc03_bst_cha_bray_shaman_wild_0_qb"] = "mage_highvalue|inf_melee|com|0",
    ["wh_dlc03_bst_cha_bray_shaman_wild_1"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh_dlc03_bst_cha_gorebull_0"] = "melee_highvalue|inf_melee|com|1",
    ["wh_dlc03_bst_cha_graktar_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_dlc03_bst_cha_khazrak_one_eye_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_dlc03_bst_cha_khazrak_one_eye_1"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh_dlc03_bst_cha_malagor_the_dark_omen_0"] = "flying_mage_highvalue|inf_melee|com|0",
    ["wh_dlc03_bst_feral_manticore"] = "flying_melee_flanker_shock|inf_melee|inf_mel|1",
    ["wh_dlc03_bst_inf_bestigor_herd_0"] = "melee|inf_melee|inf_mel|0",
    ["wh_dlc03_bst_inf_centigors_0"] = "melee_flanker|inf_melee|inf_mel|1",
    ["wh_dlc03_bst_inf_centigors_1"] = "ranged_harasser_flanker|inf_ranged|inf_mis|1",
    ["wh_dlc03_bst_inf_centigors_2"] = "melee_flanker_shock|inf_melee|inf_mel|1",
    ["wh_dlc03_bst_inf_chaos_warhounds_0"] = "melee_flanker|inf_melee|inf_mel|0",
    ["wh_dlc03_bst_inf_chaos_warhounds_1"] = "melee_flanker|inf_melee|inf_mel|0",
    ["wh_dlc03_bst_inf_cygor_0"] = "ranged_no_skirmish_gatecrusher|inf_ranged|spcl|1",
    ["wh_dlc03_bst_inf_cygor_0_summoned"] = "ranged_no_skirmish_gatecrusher|inf_ranged|spcl|1",
    ["wh_dlc03_bst_inf_gor_herd_0"] = "melee|inf_melee|inf_mel|0",
    ["wh_dlc03_bst_inf_gor_herd_1"] = "melee|inf_melee|inf_mel|0",
    ["wh_dlc03_bst_inf_minotaurs_0"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh_dlc03_bst_inf_minotaurs_1"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh_dlc03_bst_inf_minotaurs_2"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh_dlc03_bst_inf_razorgor_herd_0"] = "melee_flanker_shock|inf_melee|spcl|1",
    ["wh_dlc03_bst_inf_ungor_herd_1"] = "melee|inf_melee|inf_mel|0",
    ["wh_dlc03_bst_inf_ungor_raiders_0"] = "ranged_stalkers|inf_ranged|inf_mis|0",
    ["wh_dlc03_bst_inf_ungor_spearmen_0"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh_dlc03_bst_inf_ungor_spearmen_1"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh_dlc03_bst_mon_chaos_spawn_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh_dlc03_bst_mon_chaos_spawn_0_summoned"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh_dlc03_bst_mon_giant_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh_dlc03_emp_cha_boris_todbringer_0"] = "melee_highvalue|inf_melee|com|1",
    ["wh_dlc03_emp_cha_boris_todbringer_1"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh_dlc03_emp_cha_boris_todbringer_2"] = "flying_melee_shock_highvalue|cavalry|com|1",
    ["wh_dlc03_emp_cha_boris_todbringer_3"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh_dlc03_emp_cha_wizard_beasts_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh_dlc03_emp_cha_wizard_beasts_1"] = "mage_highvalue|cavalry|com|1",
    ["wh_dlc03_emp_cha_wizard_beasts_2"] = "mage_highvalue|cavalry|com|1",
    ["wh_dlc03_emp_cha_wizard_beasts_3"] = "flying_melee_shock_mage_highvalue|war_beast|com|1",
    ["wh_dlc03_emp_cha_wizard_beasts_4"] = "flying_mage_highvalue|cavalry|com|1",
    ["wh_dlc04_emp_art_hammer_of_the_witches_0"] = "ranged_direct_arty|artillery|art_fld|0",
    ["wh_dlc04_emp_art_sunmaker_0"] = "ranged_indirect_arty|artillery|art_fld|0",
    ["wh_dlc04_emp_cav_knights_blazing_sun_0"] = "melee_flanker_shock|cavalry|cav_mel|1",
    ["wh_dlc04_emp_cav_royal_altdorf_gryphites_0"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh_dlc04_emp_cav_zintlers_reiksguard_0"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh_dlc04_emp_cha_arch_lector_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_dlc04_emp_cha_arch_lector_1"] = "melee_highvalue|cavalry|com|1",
    ["wh_dlc04_emp_cha_arch_lector_2"] = "melee_highvalue|cavalry|com|1",
    ["wh_dlc04_emp_cha_volkmar_the_grim_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_dlc04_emp_cha_volkmar_the_grim_1"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh_dlc04_emp_cha_volkmar_the_grim_2"] = "melee_highvalue|cavalry|com|1",
    ["wh_dlc04_emp_cha_volkmar_the_grim_3"] = "melee_highvalue|cavalry|com|1",
    ["wh_dlc04_emp_inf_flagellants_0"] = "melee|inf_melee|inf_mel|0",
    ["wh_dlc04_emp_inf_free_company_militia_0"] = "hybrid_melee|inf_ranged|inf_mis|0",
    ["wh_dlc04_emp_inf_sigmars_sons_0"] = "melee|inf_melee|inf_mel|0",
    ["wh_dlc04_emp_inf_silver_bullets_0"] = "ranged_stalkers_direct|inf_ranged|inf_mis|0",
    ["wh_dlc04_emp_inf_stirlands_revenge_0"] = "ranged_stalkers_direct_no_skirmish|inf_ranged|inf_mis|0",
    ["wh_dlc04_emp_inf_tattersouls_0"] = "melee|inf_melee|inf_mel|0",
    ["wh_dlc04_emp_veh_templehof_luminark_0"] = "ranged_direct|war_machine|chariot|1",
    ["wh_dlc04_vmp_cav_chillgheists_0"] = "melee_flanker_undead|cavalry|cav_mel|0",
    ["wh_dlc04_vmp_cav_vereks_reavers_0"] = "melee_flanker_shock_undead|cavalry|cav_shk|1",
    ["wh_dlc04_vmp_cha_helman_ghorst_0"] = "mage_highvalue_undead|inf_melee|com|0",
    ["wh_dlc04_vmp_cha_helman_ghorst_1"] = "mage_highvalue_undead|war_machine|com|1",
    ["wh_dlc04_vmp_cha_master_necromancer_1"] = "mage_highvalue_undead|war_machine|com|1",
    ["wh_dlc04_vmp_cha_master_necromancer_2"] = "mage_highvalue_undead|war_machine|com|1",
    ["wh_dlc04_vmp_cha_master_necromancer_3"] = "mage_highvalue_undead|war_machine|com|1",
    ["wh_dlc04_vmp_cha_necromancer_1"] = "mage_highvalue_undead|war_machine|com|1",
    ["wh_dlc04_vmp_cha_necromancer_2"] = "mage_highvalue_undead|war_machine|com|1",
    ["wh_dlc04_vmp_cha_necromancer_3"] = "mage_highvalue_undead|war_machine|com|1",
    ["wh_dlc04_vmp_cha_strigoi_ghoul_king_0"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh_dlc04_vmp_cha_strigoi_ghoul_king_0_boss"] = "melee_flanker_shock_highvalue_undead|inf_melee|com|0",
    ["wh_dlc04_vmp_cha_strigoi_ghoul_king_1"] = "flying_melee_highvalue_undead|war_beast|com|1",
    ["wh_dlc04_vmp_cha_vlad_von_carstein_0"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh_dlc04_vmp_inf_feasters_in_the_dusk_0"] = "melee_stalkers_undead|inf_melee|inf_mel|0",
    ["wh_dlc04_vmp_inf_konigstein_stalkers_0"] = "melee_undead|inf_melee|inf_mel|0",
    ["wh_dlc04_vmp_inf_sternsmen_0"] = "melee_undead|inf_melee|inf_mel|0",
    ["wh_dlc04_vmp_inf_tithe_0"] = "melee_undead|inf_melee|inf_mel|0",
    ["wh_dlc04_vmp_mon_devils_swartzhafen_0"] = "flying_melee_flanker_undead|inf_melee|inf_mel|1",
    ["wh_dlc04_vmp_mon_direpack_0"] = "melee_flanker_undead|inf_melee|inf_mel|0",
    ["wh_dlc04_vmp_veh_claw_of_nagash_0"] = "melee_highvalue_undead|war_machine|chariot|1",
    ["wh_dlc04_vmp_veh_corpse_cart_0"] = "melee_highvalue_undead|war_machine|chariot|1",
    ["wh_dlc04_vmp_veh_corpse_cart_1"] = "melee_highvalue_undead|war_machine|chariot|1",
    ["wh_dlc04_vmp_veh_corpse_cart_2"] = "melee_highvalue_undead|war_machine|chariot|1",
    ["wh_dlc04_vmp_veh_mortis_engine_0"] = "melee_highvalue_undead|war_machine|chariot|1",
    ["wh_dlc05_bst_cha_morghur_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_dlc05_bst_cha_morghur_0_boss"] = "melee_highvalue|inf_melee|com|0",
    ["wh_dlc05_bst_mon_chaos_spawn_0_boss"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh_dlc05_bst_mon_harpies_0"] = "flying_melee_flanker|inf_melee|inf_mel|0",
    ["wh_dlc05_emp_cha_wizard_life_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh_dlc05_emp_cha_wizard_life_1"] = "mage_highvalue|cavalry|com|1",
    ["wh_dlc05_emp_cha_wizard_life_2"] = "mage_highvalue|cavalry|com|1",
    ["wh_dlc05_emp_cha_wizard_life_3"] = "flying_mage_highvalue|cavalry|com|1",
    ["wh_dlc05_emp_cha_wizard_shadows_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh_dlc05_emp_cha_wizard_shadows_1"] = "mage_highvalue|cavalry|com|1",
    ["wh_dlc05_emp_cha_wizard_shadows_2"] = "mage_highvalue|cavalry|com|1",
    ["wh_dlc05_emp_cha_wizard_shadows_3"] = "flying_mage_highvalue|cavalry|com|1",
    ["wh_dlc05_vmp_cha_red_duke_0"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh_dlc05_vmp_cha_red_duke_1"] = "flying_melee_highvalue_undead|cavalry|com|1",
    ["wh_dlc05_vmp_cha_red_duke_2"] = "melee_flanker_shock_highvalue_undead|cavalry|com|1",
    ["wh_dlc05_vmp_cha_red_duke_3"] = "flying_melee_highvalue_undead|war_beast|com|1",
    ["wh_dlc05_vmp_cha_vampire_shadows_0"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh_dlc05_vmp_cha_vampire_shadows_1"] = "melee_flanker_shock_highvalue_undead|cavalry|com|1",
    ["wh_dlc05_vmp_cha_vampire_shadows_2"] = "flying_melee_highvalue_undead|cavalry|com|1",
    ["wh_dlc05_wef_cav_glade_riders_0"] = "ranged_harasser_flanker|cavalry|cav_mis|1",
    ["wh_dlc05_wef_cav_glade_riders_1"] = "ranged_harasser_flanker|cavalry|cav_mis|1",
    ["wh_dlc05_wef_cav_glade_riders_1_qb"] = "ranged_harasser_flanker|cavalry|cav_mis|1",
    ["wh_dlc05_wef_cav_hawk_riders_0"] = "flying_ranged_harasser_flanker|cavalry|cav_mis|1",
    ["wh_dlc05_wef_cav_sisters_thorn_0"] = "ranged_harasser_flanker|cavalry|cav_mis|1",
    ["wh_dlc05_wef_cav_wild_riders_0"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh_dlc05_wef_cav_wild_riders_1"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh_dlc05_wef_cha_ancient_treeman_0"] = "melee_gatecrusher_highvalue|inf_melee|com|1",
    ["wh_dlc05_wef_cha_branchwraith_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_dlc05_wef_cha_durthu_0"] = "melee_gatecrusher_highvalue|inf_melee|com|1",
    ["wh_dlc05_wef_cha_female_glade_lord_0"] = "ranged_highvalue|inf_ranged|com|0",
    ["wh_dlc05_wef_cha_female_glade_lord_0_qb"] = "ranged_highvalue|inf_ranged|com|0",
    ["wh_dlc05_wef_cha_female_glade_lord_1"] = "ranged_cav_highvalue|cavalry|com|1",
    ["wh_dlc05_wef_cha_female_glade_lord_2"] = "flying_hybrid_highvalue|war_beast|com|1",
    ["wh_dlc05_wef_cha_female_glade_lord_2_qb"] = "flying_hybrid_highvalue|war_beast|com|1",
    ["wh_dlc05_wef_cha_female_glade_lord_3"] = "flying_hybrid_highvalue|war_beast|com|1",
    ["wh_dlc05_wef_cha_glade_lord_0"] = "ranged_highvalue|inf_ranged|com|0",
    ["wh_dlc05_wef_cha_glade_lord_1"] = "ranged_cav_highvalue|cavalry|com|1",
    ["wh_dlc05_wef_cha_glade_lord_2"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh_dlc05_wef_cha_glade_lord_3"] = "flying_hybrid_highvalue|war_beast|com|1",
    ["wh_dlc05_wef_cha_orion_0"] = "hybrid_highvalue|inf_ranged|com|1",
    ["wh_dlc05_wef_cha_spellsinger_beasts_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh_dlc05_wef_cha_spellsinger_beasts_1"] = "mage_highvalue|cavalry|com|1",
    ["wh_dlc05_wef_cha_spellsinger_beasts_2"] = "flying_mage_highvalue|war_beast|com|1",
    ["wh_dlc05_wef_cha_spellsinger_beasts_3"] = "mage_highvalue|cavalry|com|1",
    ["wh_dlc05_wef_cha_spellsinger_life_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh_dlc05_wef_cha_spellsinger_life_1"] = "mage_highvalue|cavalry|com|1",
    ["wh_dlc05_wef_cha_spellsinger_life_2"] = "flying_mage_highvalue|war_beast|com|1",
    ["wh_dlc05_wef_cha_spellsinger_life_3"] = "mage_highvalue|cavalry|com|1",
    ["wh_dlc05_wef_cha_spellsinger_shadows_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh_dlc05_wef_cha_spellsinger_shadows_1"] = "mage_highvalue|cavalry|com|1",
    ["wh_dlc05_wef_cha_spellsinger_shadows_2"] = "flying_mage_highvalue|war_beast|com|1",
    ["wh_dlc05_wef_cha_spellsinger_shadows_3"] = "mage_highvalue|cavalry|com|1",
    ["wh_dlc05_wef_cha_waystalker_0"] = "ranged_stalkers_harasser_highvalue|inf_ranged|com|0",
    ["wh_dlc05_wef_forest_dragon_0"] = "flying_melee_flanker|inf_melee|inf_mel|1",
    ["wh_dlc05_wef_inf_deepwood_scouts_0"] = "ranged_stalkers_harasser|inf_ranged|inf_mis|0",
    ["wh_dlc05_wef_inf_deepwood_scouts_1"] = "ranged_stalkers_harasser|inf_ranged|inf_mis|0",
    ["wh_dlc05_wef_inf_deepwood_scouts_1_qb"] = "ranged_stalkers_harasser|inf_ranged|inf_mis|0",
    ["wh_dlc05_wef_inf_dryads_0"] = "melee|inf_melee|inf_mel|0",
    ["wh_dlc05_wef_inf_eternal_guard_0"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh_dlc05_wef_inf_eternal_guard_1"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh_dlc05_wef_inf_eternal_guard_1_qb"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh_dlc05_wef_inf_glade_guard_0"] = "ranged_harasser|inf_ranged|inf_mis|0",
    ["wh_dlc05_wef_inf_glade_guard_1"] = "ranged_harasser|inf_ranged|inf_mis|0",
    ["wh_dlc05_wef_inf_glade_guard_1_qb"] = "ranged|inf_ranged|inf_mis|0",
    ["wh_dlc05_wef_inf_glade_guard_2"] = "ranged_harasser|inf_ranged|inf_mis|0",
    ["wh_dlc05_wef_inf_wardancers_0"] = "melee|inf_melee|inf_mel|0",
    ["wh_dlc05_wef_inf_wardancers_1"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh_dlc05_wef_inf_waywatchers_0"] = "ranged_stalkers_harasser|inf_ranged|inf_mis|0",
    ["wh_dlc05_wef_inf_wildwood_rangers_0"] = "melee|inf_melee|inf_mel|0",
    ["wh_dlc05_wef_mon_great_eagle_0"] = "flying_melee_flanker_shock|inf_melee|inf_mel|1",
    ["wh_dlc05_wef_mon_treekin_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh_dlc05_wef_mon_treeman_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh_dlc06_chs_cav_marauder_horsemasters_0"] = "ranged_harasser_flanker|war_beast|cav_mis|1",
    ["wh_dlc06_chs_cha_chaos_sorcerer_death_9"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh_dlc06_chs_cha_chaos_sorcerer_fire_9"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh_dlc06_chs_cha_chaos_sorcerer_metal_9"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh_dlc06_chs_feral_manticore"] = "flying_melee_flanker_shock|inf_melee|inf_mel|1",
    ["wh_dlc06_chs_inf_aspiring_champions_0"] = "melee|inf_melee|inf_mel|0",
    ["wh_dlc06_dwf_art_bolt_thrower_0"] = "ranged_direct_arty|artillery|art_fld|0",
    ["wh_dlc06_dwf_art_gob_lobber_0"] = "ranged_indirect_arty|artillery|art_fld|0",
    ["wh_dlc06_dwf_cha_belegar_ironhammer_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_dlc06_dwf_cha_master_engineer_ghost_0"] = "ranged_highvalue|inf_ranged|com|0",
    ["wh_dlc06_dwf_cha_runelord_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_dlc06_dwf_cha_runelord_1"] = "melee_highvalue|inf_melee|com|1",
    ["wh_dlc06_dwf_cha_runesmith_ghost_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_dlc06_dwf_cha_thane_ghost_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_dlc06_dwf_cha_thane_ghost_1"] = "melee_highvalue|inf_melee|com|0",
    ["wh_dlc06_dwf_inf_bugmans_rangers_0"] = "ranged_stalkers_no_skirmish|inf_ranged|inf_mis|0",
    ["wh_dlc06_dwf_inf_dragonback_slayers_0"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh_dlc06_dwf_inf_ekrund_miners_0"] = "hybrid_gatecrusher|inf_melee|inf_mel|0",
    ["wh_dlc06_dwf_inf_norgrimlings_ironbreakers_0"] = "hybrid_melee|inf_melee|inf_mel|0",
    ["wh_dlc06_dwf_inf_norgrimlings_irondrakes_0"] = "ranged_direct_no_skirmish|inf_ranged|inf_mis|0",
    ["wh_dlc06_dwf_inf_old_grumblers_0"] = "melee|inf_melee|inf_mel|0",
    ["wh_dlc06_dwf_inf_peak_gate_guard_0"] = "melee|inf_melee|inf_mel|0",
    ["wh_dlc06_dwf_inf_rangers_0"] = "ranged_stalkers_no_skirmish|inf_ranged|inf_mis|0",
    ["wh_dlc06_dwf_inf_rangers_1"] = "ranged_stalkers_no_skirmish|inf_ranged|inf_mis|0",
    ["wh_dlc06_dwf_inf_ulthars_raiders_0"] = "ranged_stalkers_no_skirmish|inf_ranged|inf_mis|0",
    ["wh_dlc06_dwf_inf_warriors_dragonfire_pass_0"] = "melee|inf_melee|inf_mel|0",
    ["wh_dlc06_dwf_veh_skyhammer_0"] = "gyrocopter|inf_ranged|inf_mis|1",
    ["wh_dlc06_emp_cha_arch_lector_0_boss"] = "melee_highvalue|inf_melee|com|0",
    ["wh_dlc06_emp_cha_captain_0_boss"] = "melee_highvalue|inf_melee|com|0",
    ["wh_dlc06_emp_cha_witch_hunter_boss"] = "ranged_direct_highvalue|inf_ranged|com|0",
    ["wh_dlc06_grn_art_hammer_of_gork_0"] = "ranged_indirect_arty|artillery|art_fld|0",
    ["wh_dlc06_grn_cav_broken_tusks_mob_0"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh_dlc06_grn_cav_deff_creepers_0"] = "ranged_stalkers_flanker_harasser|cavalry|cav_mis|1",
    ["wh_dlc06_grn_cav_durkits_squigs_0"] = "melee_flanker_shock|cavalry|cav_mel|1",
    ["wh_dlc06_grn_cav_mogrubbs_marauders_0"] = "ranged_harasser_flanker|cavalry|cav_mis|1",
    ["wh_dlc06_grn_cav_moon_howlers_0"] = "melee_flanker|cavalry|cav_mel|1",
    ["wh_dlc06_grn_cav_squig_hoppers_0"] = "melee_flanker_shock|cavalry|cav_mel|1",
    ["wh_dlc06_grn_cav_teef_robbers_0"] = "ranged_harasser_flanker|war_machine|chariot|1",
    ["wh_dlc06_grn_cha_night_goblin_warboss_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_dlc06_grn_cha_night_goblin_warboss_1"] = "melee_highvalue|cavalry|com|1",
    ["wh_dlc06_grn_cha_skarsnik_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_dlc06_grn_cha_wurrzag_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh_dlc06_grn_cha_wurrzag_1"] = "mage_flanker_highvalue|cavalry|com|1",
    ["wh_dlc06_grn_inf_da_eight_peaks_loonies_0"] = "melee_stalkers|inf_melee|inf_mel|0",
    ["wh_dlc06_grn_inf_da_rusty_arrers_0"] = "ranged_stalkers|inf_ranged|inf_mis|0",
    ["wh_dlc06_grn_inf_da_warlords_boyz_0"] = "melee_stalkers|inf_melee|inf_mel|0",
    ["wh_dlc06_grn_inf_krimson_killerz_0"] = "melee|inf_melee|inf_mel|0",
    ["wh_dlc06_grn_inf_nasty_skulkers_0"] = "melee_stalkers|inf_melee|inf_mel|0",
    ["wh_dlc06_grn_inf_squig_explosive_0"] = "melee_flanker_shock_undead|inf_melee|inf_mel|1",
    ["wh_dlc06_grn_inf_squig_herd_0"] = "melee|inf_melee|inf_mel|1",
    ["wh_dlc06_grn_mon_spider_hatchlings_0"] = "melee_flanker|inf_melee|inf_mel|0",
    ["wh_dlc06_grn_mon_spider_hatchlings_0_summoned"] = "melee_flanker|inf_melee|inf_mel|0",
    ["wh_dlc06_grn_mon_venom_queen_0"] = "melee_gatecrusher|war_beast|inf_mel|1",
    ["wh_dlc07_brt_art_blessed_field_trebuchet_0"] = "ranged_indirect_arty|artillery|art_fld|0",
    ["wh_dlc07_brt_cav_grail_guardians_0"] = "melee_flanker|cavalry|cav_mel|1",
    ["wh_dlc07_brt_cav_knights_errant_0"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh_dlc07_brt_cav_questing_knights_0"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh_dlc07_brt_cav_royal_hippogryph_knights_0"] = "flying_melee_flanker_shock|war_beast|cav_shk|1",
    ["wh_dlc07_brt_cav_royal_pegasus_knights_0"] = "flying_melee_flanker_shock|cavalry|cav_shk|1",
    ["wh_dlc07_brt_cha_alberic_bordeleaux_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_dlc07_brt_cha_alberic_bordeleaux_1"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh_dlc07_brt_cha_alberic_bordeleaux_2"] = "flying_melee_shock_highvalue|cavalry|com|1",
    ["wh_dlc07_brt_cha_alberic_bordeleaux_3"] = "flying_melee_shock_highvalue|war_beast|com|1",
    ["wh_dlc07_brt_cha_damsel_beasts_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh_dlc07_brt_cha_damsel_beasts_1"] = "mage_highvalue|cavalry|com|1",
    ["wh_dlc07_brt_cha_damsel_beasts_2"] = "mage_highvalue|cavalry|com|1",
    ["wh_dlc07_brt_cha_damsel_beasts_3"] = "mage_highvalue|cavalry|com|1",
    ["wh_dlc07_brt_cha_damsel_life_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh_dlc07_brt_cha_damsel_life_1"] = "mage_highvalue|cavalry|com|1",
    ["wh_dlc07_brt_cha_damsel_life_2"] = "mage_highvalue|cavalry|com|1",
    ["wh_dlc07_brt_cha_damsel_life_3"] = "mage_highvalue|cavalry|com|1",
    ["wh_dlc07_brt_cha_fay_enchantress_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_dlc07_brt_cha_fay_enchantress_1"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh_dlc07_brt_cha_green_knight_0"] = "melee_flanker_shock_highvalue|cavalry|com|0",
    ["wh_dlc07_brt_cha_prophetess_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh_dlc07_brt_cha_prophetess_1"] = "mage_highvalue|cavalry|com|1",
    ["wh_dlc07_brt_cha_prophetess_2"] = "mage_highvalue|cavalry|com|1",
    ["wh_dlc07_brt_cha_prophetess_3"] = "flying_mage_highvalue|cavalry|com|1",
    ["wh_dlc07_brt_cha_prophetess_beasts_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh_dlc07_brt_cha_prophetess_beasts_1"] = "mage_highvalue|cavalry|com|1",
    ["wh_dlc07_brt_cha_prophetess_beasts_2"] = "mage_highvalue|cavalry|com|1",
    ["wh_dlc07_brt_cha_prophetess_beasts_3"] = "flying_mage_highvalue|cavalry|com|1",
    ["wh_dlc07_brt_cha_prophetess_heavens_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh_dlc07_brt_cha_prophetess_heavens_1"] = "mage_highvalue|cavalry|com|1",
    ["wh_dlc07_brt_cha_prophetess_heavens_2"] = "mage_highvalue|cavalry|com|1",
    ["wh_dlc07_brt_cha_prophetess_heavens_3"] = "flying_mage_highvalue|cavalry|com|1",
    ["wh_dlc07_brt_inf_battle_pilgrims_0"] = "melee|inf_melee|inf_mel|0",
    ["wh_dlc07_brt_inf_foot_squires_0"] = "melee|inf_melee|inf_mel|0",
    ["wh_dlc07_brt_inf_grail_reliquae_0"] = "melee_highvalue|inf_melee|spcl|1",
    ["wh_dlc07_brt_inf_men_at_arms_1"] = "melee|inf_melee|inf_mel|0",
    ["wh_dlc07_brt_inf_men_at_arms_2"] = "melee|inf_melee|inf_mel|0",
    ["wh_dlc07_brt_inf_peasant_bowmen_1"] = "ranged|inf_ranged|inf_mis|0",
    ["wh_dlc07_brt_inf_peasant_bowmen_2"] = "ranged|inf_ranged|inf_mis|0",
    ["wh_dlc07_brt_inf_peasant_mob_0"] = "melee|inf_melee|inf_mel|0",
    ["wh_dlc07_brt_inf_spearmen_at_arms_1"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh_dlc08_bst_mon_cygor_boss"] = "ranged_indirect_arty|inf_ranged|com|1",
    ["wh_dlc08_chs_cha_chaos_lord_2_qb"] = "flying_melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh_dlc08_chs_mon_dragon_ogre_shaggoth_boss"] = "melee_gatecrusher_highvalue|inf_melee|com|1",
    ["wh_dlc08_chs_mon_dragon_ogre_shaggoth_minor_boss"] = "melee_gatecrusher_highvalue|inf_melee|inf_mel|1",
    ["wh_dlc08_grn_mon_arachnarok_spider_boss"] = "melee_gatecrusher|war_beast|inf_mel|1",
    ["wh_dlc08_grn_mon_giant_boss"] = "melee_gatecrusher|inf_melee|com|1",
    ["wh_dlc08_nor_art_hellcannon_battery"] = "ranged_indirect_arty|artillery|art_fld|0",
    ["wh_dlc08_nor_cav_marauder_horsemasters_0"] = "ranged_harasser_flanker|war_beast|cav_mis|1",
    ["wh_dlc08_nor_cav_marauder_warwolves_chariot_0"] = "melee_flanker_shock|war_machine|chariot|1",
    ["wh_dlc08_nor_cha_arzik_0"] = "melee_highvalue|inf_melee|com|1",
    ["wh_dlc08_nor_cha_fimir_balefiend_fire_0"] = "melee_highvalue|inf_melee|com|1",
    ["wh_dlc08_nor_cha_fimir_balefiend_shadow_0"] = "melee_highvalue|inf_melee|com|1",
    ["wh_dlc08_nor_cha_kihar_0"] = "flying_melee_highvalue|war_beast|com|1",
    ["wh_dlc08_nor_cha_shaman_sorcerer_death_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh_dlc08_nor_cha_shaman_sorcerer_death_1"] = "mage_highvalue|cavalry|com|1",
    ["wh_dlc08_nor_cha_shaman_sorcerer_death_2"] = "mage_highvalue|war_machine|com|1",
    ["wh_dlc08_nor_cha_shaman_sorcerer_fire_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh_dlc08_nor_cha_shaman_sorcerer_fire_1"] = "mage_highvalue|cavalry|com|1",
    ["wh_dlc08_nor_cha_shaman_sorcerer_fire_2"] = "mage_highvalue|war_machine|com|1",
    ["wh_dlc08_nor_cha_shaman_sorcerer_metal_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh_dlc08_nor_cha_shaman_sorcerer_metal_1"] = "mage_highvalue|cavalry|com|1",
    ["wh_dlc08_nor_cha_shaman_sorcerer_metal_2"] = "mage_highvalue|war_machine|com|1",
    ["wh_dlc08_nor_cha_skin_wolf_werekin_0"] = "melee_highvalue|inf_melee|com|1",
    ["wh_dlc08_nor_cha_throgg_0"] = "melee_gatecrusher_highvalue|inf_melee|com|1",
    ["wh_dlc08_nor_cha_wulfrik_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_dlc08_nor_cha_wulfrik_1"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh_dlc08_nor_cha_wulfrik_2"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh_dlc08_nor_cha_wulfrik_3"] = "melee_cav_shock_highvalue|war_beast|com|1",
    ["wh_dlc08_nor_feral_manticore"] = "flying_melee_flanker_shock|inf_melee|inf_mel|1",
    ["wh_dlc08_nor_inf_marauder_berserkers_0"] = "melee|inf_melee|inf_mel|0",
    ["wh_dlc08_nor_inf_marauder_champions_0"] = "melee|inf_melee|inf_mel|0",
    ["wh_dlc08_nor_inf_marauder_champions_1"] = "melee|inf_melee|inf_mel|0",
    ["wh_dlc08_nor_inf_marauder_hunters_0"] = "ranged|inf_ranged|inf_mis|0",
    ["wh_dlc08_nor_inf_marauder_hunters_1"] = "ranged|inf_ranged|inf_mis|0",
    ["wh_dlc08_nor_inf_marauder_spearman_0"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh_dlc08_nor_mon_fimir_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh_dlc08_nor_mon_fimir_1"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh_dlc08_nor_mon_frost_wyrm_0"] = "flying_melee_flanker_shock|inf_melee|inf_mel|1",
    ["wh_dlc08_nor_mon_frost_wyrm_boss"] = "flying_melee_highvalue|inf_melee|com|1",
    ["wh_dlc08_nor_mon_frost_wyrm_ror_0"] = "flying_melee_flanker_shock|inf_melee|inf_mel|1",
    ["wh_dlc08_nor_mon_marauder_warwolves_0"] = "melee_flanker|inf_melee|inf_mel|0",
    ["wh_dlc08_nor_mon_norscan_giant_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh_dlc08_nor_mon_norscan_ice_trolls_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh_dlc08_nor_mon_skinwolves_0"] = "melee_flanker|inf_melee|inf_mel|1",
    ["wh_dlc08_nor_mon_skinwolves_1"] = "melee_flanker|inf_melee|inf_mel|1",
    ["wh_dlc08_nor_mon_war_mammoth_0"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh_dlc08_nor_mon_war_mammoth_1"] = "melee_gatecrusher_shock|war_beast|inf_mel|1",
    ["wh_dlc08_nor_mon_war_mammoth_2"] = "melee_gatecrusher_shock|war_beast|inf_mel|1",
    ["wh_dlc08_nor_mon_war_mammoth_boss"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh_dlc08_nor_mon_war_mammoth_ror_1"] = "melee_gatecrusher_shock|inf_melee|inf_mel|1",
    ["wh_dlc08_vmp_mon_terrorgheist_boss"] = "flying_melee_highvalue_undead|inf_melee|com|1",
    ["wh_dlc08_wef_forest_dragon_boss"] = "flying_melee_highvalue|inf_melee|com|1",
    ["wh_dlc08_wef_mon_treeman_boss"] = "melee_gatecrusher|inf_melee|com|1",
    ["wh_main_brt_art_field_trebuchet"] = "ranged_indirect_arty|artillery|art_fld|0",
    ["wh_main_brt_cav_grail_knights"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh_main_brt_cav_knights_of_the_realm"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh_main_brt_cav_mounted_yeomen_0"] = "melee_flanker_shock|cavalry|cav_mel|1",
    ["wh_main_brt_cav_mounted_yeomen_1"] = "ranged_harasser_flanker|cavalry|cav_mis|1",
    ["wh_main_brt_cav_pegasus_knights"] = "flying_melee_flanker_shock|cavalry|cav_shk|1",
    ["wh_main_brt_cha_damsel_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh_main_brt_cha_damsel_1"] = "mage_highvalue|cavalry|com|1",
    ["wh_main_brt_cha_damsel_2"] = "mage_highvalue|cavalry|com|1",
    ["wh_main_brt_cha_damsel_3"] = "mage_highvalue|cavalry|com|1",
    ["wh_main_brt_cha_king_louen_leoncoeur_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_main_brt_cha_king_louen_leoncoeur_1"] = "flying_melee_shock_highvalue|war_beast|com|1",
    ["wh_main_brt_cha_king_louen_leoncoeur_2"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh_main_brt_cha_king_louen_leoncoeur_3"] = "flying_melee_shock_highvalue|cavalry|com|1",
    ["wh_main_brt_cha_king_louen_leoncoeur_4"] = "flying_melee_shock_highvalue|war_beast|com|1",
    ["wh_main_brt_cha_lord_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_main_brt_cha_lord_2"] = "flying_melee_shock_highvalue|war_beast|com|1",
    ["wh_main_brt_cha_lord_3"] = "flying_melee_shock_highvalue|cavalry|com|1",
    ["wh_main_brt_cha_lord_4"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh_main_brt_cha_paladin_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_main_brt_cha_paladin_3"] = "flying_melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh_main_brt_cha_paladin_4"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh_main_brt_inf_men_at_arms"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh_main_brt_inf_peasant_bowmen"] = "ranged|inf_ranged|inf_mis|0",
    ["wh_main_brt_inf_spearmen_at_arms"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh_main_bst_feral_manticore_summoned"] = "flying_melee_flanker_shock|inf_melee|inf_mel|1",
    ["wh_main_chs_art_hellcannon"] = "ranged_indirect_arty|artillery|art_fld|0",
    ["wh_main_chs_cav_chaos_chariot"] = "melee_flanker_shock|war_machine|chariot|1",
    ["wh_main_chs_cav_chaos_knights_0"] = "melee_flanker|war_beast|cav_mel|1",
    ["wh_main_chs_cav_chaos_knights_1"] = "melee_flanker_shock|war_beast|cav_shk|1",
    ["wh_main_chs_cav_marauder_horsemen_0"] = "ranged_harasser_flanker|war_beast|cav_mis|1",
    ["wh_main_chs_cav_marauder_horsemen_1"] = "ranged_harasser_flanker|war_beast|cav_mis|1",
    ["wh_main_chs_cha_archaon_the_everchosen_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_main_chs_cha_archaon_the_everchosen_1"] = "melee_highvalue|war_beast|com|1",
    ["wh_main_chs_cha_chaos_lord_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_main_chs_cha_chaos_lord_11"] = "melee_highvalue|war_beast|com|1",
    ["wh_main_chs_cha_chaos_lord_12"] = "melee_highvalue|cavalry|com|1",
    ["wh_main_chs_cha_chaos_lord_8"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh_main_chs_cha_chaos_sorcerer_death_0"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh_main_chs_cha_chaos_sorcerer_death_10"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh_main_chs_cha_chaos_sorcerer_death_11"] = "mage_flanker_highvalue|cavalry|com|1",
    ["wh_main_chs_cha_chaos_sorcerer_death_7"] = "mage_flanker_highvalue|war_machine|com|1",
    ["wh_main_chs_cha_chaos_sorcerer_fire_0"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh_main_chs_cha_chaos_sorcerer_fire_10"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh_main_chs_cha_chaos_sorcerer_fire_11"] = "mage_flanker_highvalue|cavalry|com|1",
    ["wh_main_chs_cha_chaos_sorcerer_fire_7"] = "mage_flanker_highvalue|war_machine|com|1",
    ["wh_main_chs_cha_chaos_sorcerer_metal_0"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh_main_chs_cha_chaos_sorcerer_metal_10"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh_main_chs_cha_chaos_sorcerer_metal_11"] = "mage_flanker_highvalue|cavalry|com|1",
    ["wh_main_chs_cha_chaos_sorcerer_metal_7"] = "mage_flanker_highvalue|war_machine|com|1",
    ["wh_main_chs_cha_exalted_hero_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_main_chs_cha_exalted_hero_12"] = "melee_highvalue|war_beast|com|1",
    ["wh_main_chs_cha_exalted_hero_13"] = "melee_highvalue|cavalry|com|1",
    ["wh_main_chs_cha_exalted_hero_7"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh_main_chs_cha_lord_of_change_0"] = "flying_melee_highvalue|inf_melee|com|1",
    ["wh_main_chs_inf_chaos_marauders_0"] = "melee|inf_melee|inf_mel|0",
    ["wh_main_chs_inf_chaos_marauders_1"] = "melee|inf_melee|inf_mel|0",
    ["wh_main_chs_inf_chaos_warriors_0"] = "melee|inf_melee|inf_mel|0",
    ["wh_main_chs_inf_chaos_warriors_1"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh_main_chs_inf_chosen_0"] = "melee|inf_melee|inf_mel|0",
    ["wh_main_chs_inf_chosen_1"] = "melee|inf_melee|inf_mel|0",
    ["wh_main_chs_mon_chaos_spawn"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh_main_chs_mon_chaos_spawn_summoned"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh_main_chs_mon_chaos_warhounds_0"] = "melee_flanker|inf_melee|inf_mel|0",
    ["wh_main_chs_mon_chaos_warhounds_1"] = "melee_flanker|inf_melee|inf_mel|0",
    ["wh_main_chs_mon_giant"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh_main_chs_mon_trolls"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh_main_dwf_art_cannon"] = "ranged_direct_arty|artillery|art_fld|0",
    ["wh_main_dwf_art_flame_cannon"] = "ranged_direct_arty|artillery|art_fld|0",
    ["wh_main_dwf_art_grudge_thrower"] = "ranged_indirect_arty|artillery|art_fld|0",
    ["wh_main_dwf_art_organ_gun"] = "ranged_direct_arty|artillery|art_fld|0",
    ["wh_main_dwf_cha_high_king_thorgrim_grudgebearer_1"] = "melee_highvalue|inf_melee|com|1",
    ["wh_main_dwf_cha_lord_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_main_dwf_cha_master_engineer_0"] = "ranged_highvalue|inf_ranged|com|0",
    ["wh_main_dwf_cha_rune_smith_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_main_dwf_cha_thane"] = "melee_highvalue|inf_melee|com|0",
    ["wh_main_dwf_cha_ungrim_ironfist"] = "melee_highvalue|inf_melee|com|0",
    ["wh_main_dwf_inf_dwarf_warrior_0"] = "melee|inf_melee|inf_mel|0",
    ["wh_main_dwf_inf_dwarf_warrior_1"] = "melee|inf_melee|inf_mel|0",
    ["wh_main_dwf_inf_hammerers"] = "melee|inf_melee|inf_mel|0",
    ["wh_main_dwf_inf_ironbreakers"] = "hybrid_melee|inf_melee|inf_mel|0",
    ["wh_main_dwf_inf_irondrakes_0"] = "ranged_direct_no_skirmish|inf_ranged|inf_mis|0",
    ["wh_main_dwf_inf_irondrakes_2"] = "ranged_direct_no_skirmish|inf_ranged|inf_mis|0",
    ["wh_main_dwf_inf_longbeards"] = "melee|inf_melee|inf_mel|0",
    ["wh_main_dwf_inf_longbeards_1"] = "melee|inf_melee|inf_mel|0",
    ["wh_main_dwf_inf_miners_0"] = "melee_gatecrusher|inf_melee|inf_mel|0",
    ["wh_main_dwf_inf_miners_1"] = "hybrid_gatecrusher|inf_melee|inf_mel|0",
    ["wh_main_dwf_inf_quarrellers_0"] = "ranged_no_skirmish|inf_ranged|inf_mis|0",
    ["wh_main_dwf_inf_quarrellers_1"] = "ranged_no_skirmish|inf_ranged|inf_mis|0",
    ["wh_main_dwf_inf_slayers"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh_main_dwf_inf_thunderers_0"] = "ranged_direct_no_skirmish|inf_ranged|inf_mis|0",
    ["wh_main_dwf_veh_gyrobomber"] = "gyrocopter|inf_ranged|inf_mis|1",
    ["wh_main_dwf_veh_gyrocopter_0"] = "gyrocopter|inf_ranged|inf_mis|1",
    ["wh_main_dwf_veh_gyrocopter_1"] = "gyrocopter|inf_ranged|inf_mis|1",
    ["wh_main_emp_art_great_cannon"] = "ranged_direct_arty|artillery|art_fld|0",
    ["wh_main_emp_art_helblaster_volley_gun"] = "ranged_direct_arty|artillery|art_fld|0",
    ["wh_main_emp_art_helstorm_rocket_battery"] = "ranged_indirect_arty|artillery|art_fld|0",
    ["wh_main_emp_art_mortar"] = "ranged_indirect_arty|artillery|art_fld|0",
    ["wh_main_emp_cav_demigryph_knights_0"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh_main_emp_cav_demigryph_knights_1"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh_main_emp_cav_empire_knights"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh_main_emp_cav_outriders_0"] = "ranged_direct_flanker_harasser|cavalry|cav_mis|1",
    ["wh_main_emp_cav_outriders_1"] = "ranged_direct_flanker_harasser|cavalry|cav_mis|1",
    ["wh_main_emp_cav_pistoliers_1"] = "ranged_direct_flanker_harasser|cavalry|cav_mis|1",
    ["wh_main_emp_cav_reiksguard"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh_main_emp_cha_balthasar_gelt_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh_main_emp_cha_balthasar_gelt_1"] = "flying_mage_highvalue|cavalry|com|1",
    ["wh_main_emp_cha_balthasar_gelt_2"] = "mage_highvalue|cavalry|com|1",
    ["wh_main_emp_cha_balthasar_gelt_3"] = "mage_highvalue|cavalry|com|1",
    ["wh_main_emp_cha_captain_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_main_emp_cha_captain_1"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh_main_emp_cha_captain_2"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh_main_emp_cha_captain_3"] = "flying_melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh_main_emp_cha_general_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_main_emp_cha_general_1"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh_main_emp_cha_general_2"] = "flying_melee_shock_highvalue|cavalry|com|1",
    ["wh_main_emp_cha_general_3"] = "flying_melee_shock_highvalue|war_beast|com|1",
    ["wh_main_emp_cha_general_4"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh_main_emp_cha_karl_franz_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_main_emp_cha_karl_franz_1"] = "flying_melee_shock_highvalue|war_beast|com|1",
    ["wh_main_emp_cha_karl_franz_2"] = "flying_melee_shock_highvalue|cavalry|com|1",
    ["wh_main_emp_cha_karl_franz_3"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh_main_emp_cha_karl_franz_4"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh_main_emp_cha_warrior_priest_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_main_emp_cha_warrior_priest_1"] = "melee_highvalue|cavalry|com|1",
    ["wh_main_emp_cha_warrior_priest_2"] = "melee_highvalue|cavalry|com|1",
    ["wh_main_emp_cha_witch_hunter"] = "ranged_highvalue|inf_ranged|com|0",
    ["wh_main_emp_cha_wizard_fire_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh_main_emp_cha_wizard_fire_1"] = "mage_highvalue|cavalry|com|1",
    ["wh_main_emp_cha_wizard_fire_2"] = "flying_mage_highvalue|cavalry|com|1",
    ["wh_main_emp_cha_wizard_fire_3"] = "mage_highvalue|cavalry|com|1",
    ["wh_main_emp_cha_wizard_heavens_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh_main_emp_cha_wizard_heavens_1"] = "mage_highvalue|cavalry|com|1",
    ["wh_main_emp_cha_wizard_heavens_2"] = "flying_mage_highvalue|cavalry|com|1",
    ["wh_main_emp_cha_wizard_heavens_4"] = "mage_highvalue|cavalry|com|1",
    ["wh_main_emp_cha_wizard_light_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh_main_emp_cha_wizard_light_1"] = "mage_highvalue|cavalry|com|1",
    ["wh_main_emp_cha_wizard_light_2"] = "flying_mage_highvalue|cavalry|com|1",
    ["wh_main_emp_cha_wizard_light_4"] = "mage_highvalue|cavalry|com|1",
    ["wh_main_emp_inf_crossbowmen"] = "ranged|inf_ranged|inf_mis|0",
    ["wh_main_emp_inf_greatswords"] = "melee|inf_melee|inf_mel|0",
    ["wh_main_emp_inf_halberdiers"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh_main_emp_inf_handgunners"] = "ranged_direct|inf_ranged|inf_mis|0",
    ["wh_main_emp_inf_spearmen_0"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh_main_emp_inf_spearmen_1"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh_main_emp_inf_swordsmen"] = "melee|inf_melee|inf_mel|0",
    ["wh_main_emp_veh_luminark_of_hysh_0"] = "ranged_direct|war_machine|chariot|1",
    ["wh_main_emp_veh_steam_tank_driver"] = "ranged_direct_highvalue|war_machine|chariot|1",
    ["wh_main_grn_art_doom_diver_catapult"] = "ranged_indirect_arty|artillery|art_fld|0",
    ["wh_main_grn_art_goblin_rock_lobber"] = "ranged_indirect_arty|artillery|art_fld|0",
    ["wh_main_grn_cav_forest_goblin_spider_riders_0"] = "melee_flanker|cavalry|cav_mel|1",
    ["wh_main_grn_cav_forest_goblin_spider_riders_1"] = "ranged_harasser_flanker|cavalry|cav_mis|1",
    ["wh_main_grn_cav_goblin_wolf_chariot"] = "ranged_harasser_flanker|war_machine|chariot|1",
    ["wh_main_grn_cav_goblin_wolf_riders_0"] = "melee_flanker|cavalry|cav_mel|1",
    ["wh_main_grn_cav_goblin_wolf_riders_1"] = "ranged_harasser_flanker|cavalry|cav_mis|1",
    ["wh_main_grn_cav_orc_boar_boy_big_uns"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh_main_grn_cav_orc_boar_boyz"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh_main_grn_cav_orc_boar_chariot"] = "melee_flanker_shock|war_machine|chariot|1",
    ["wh_main_grn_cav_savage_orc_boar_boy_big_uns"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh_main_grn_cav_savage_orc_boar_boyz"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh_main_grn_cha_azhag_the_slaughterer_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_main_grn_cha_azhag_the_slaughterer_1"] = "flying_melee_shock_highvalue|war_beast|com|1",
    ["wh_main_grn_cha_goblin_big_boss_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_main_grn_cha_goblin_big_boss_1"] = "melee_highvalue|cavalry|com|1",
    ["wh_main_grn_cha_goblin_big_boss_2"] = "melee_highvalue|cavalry|com|1",
    ["wh_main_grn_cha_goblin_big_boss_4"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh_main_grn_cha_goblin_great_shaman_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh_main_grn_cha_goblin_great_shaman_1"] = "mage_flanker_highvalue|cavalry|com|1",
    ["wh_main_grn_cha_goblin_great_shaman_2"] = "mage_flanker_highvalue|war_machine|com|1",
    ["wh_main_grn_cha_grimgor_ironhide"] = "melee_highvalue|inf_melee|com|0",
    ["wh_main_grn_cha_night_goblin_shaman"] = "mage_stalkers_highvalue|inf_melee|com|0",
    ["wh_main_grn_cha_orc_shaman_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh_main_grn_cha_orc_shaman_1"] = "mage_highvalue|cavalry|com|1",
    ["wh_main_grn_cha_orc_warboss_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_main_grn_cha_orc_warboss_1"] = "flying_melee_shock_highvalue|war_beast|com|1",
    ["wh_main_grn_cha_orc_warboss_2"] = "melee_highvalue|cavalry|com|1",
    ["wh_main_grn_cha_orc_warboss_3"] = "melee_flanker_shock_highvalue|war_machine|com|1",
    ["wh_main_grn_inf_black_orcs"] = "melee|inf_melee|inf_mel|0",
    ["wh_main_grn_inf_goblin_archers"] = "ranged|inf_ranged|inf_mis|0",
    ["wh_main_grn_inf_goblin_spearmen"] = "melee|inf_melee|inf_mel|0",
    ["wh_main_grn_inf_night_goblin_archers"] = "ranged_stalkers|inf_ranged|inf_mis|0",
    ["wh_main_grn_inf_night_goblin_fanatics"] = "melee_stalkers|inf_melee|inf_mel|0",
    ["wh_main_grn_inf_night_goblin_fanatics_1"] = "ranged_stalkers|inf_ranged|inf_mis|0",
    ["wh_main_grn_inf_night_goblins"] = "melee_stalkers|inf_melee|inf_mel|0",
    ["wh_main_grn_inf_orc_arrer_boyz"] = "ranged|inf_ranged|inf_mis|0",
    ["wh_main_grn_inf_orc_big_uns"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh_main_grn_inf_orc_boyz"] = "melee|inf_melee|inf_mel|0",
    ["wh_main_grn_inf_savage_orc_arrer_boyz"] = "ranged|inf_ranged|inf_mis|0",
    ["wh_main_grn_inf_savage_orc_big_uns"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh_main_grn_inf_savage_orcs"] = "melee|inf_melee|inf_mel|0",
    ["wh_main_grn_mon_arachnarok_spider_0"] = "melee_gatecrusher|war_beast|inf_mel|1",
    ["wh_main_grn_mon_giant"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh_main_grn_mon_giant_qb_tall_roff"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh_main_grn_mon_trolls"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh_main_ksl_cha_captain_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_main_ksl_cha_captain_1"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh_main_ksl_cha_captain_2"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh_main_ksl_cha_general_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_main_ksl_cha_general_1"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh_main_ksl_cha_general_2"] = "melee_flanker_shock_highvalue|cavalry|com|1",
    ["wh_main_ksl_cha_wizard_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh_main_ksl_cha_wizard_1"] = "mage_highvalue|cavalry|com|1",
    ["wh_main_nor_cav_chaos_chariot"] = "melee_flanker_shock|war_machine|chariot|1",
    ["wh_main_nor_cav_marauder_horsemen_0"] = "ranged_harasser_flanker|war_beast|cav_mis|1",
    ["wh_main_nor_cav_marauder_horsemen_1"] = "ranged_harasser_flanker|war_beast|cav_mis|1",
    ["wh_main_nor_cha_chaos_sorcerer_0"] = "melee_mage_highvalue|inf_melee|com|0",
    ["wh_main_nor_cha_chaos_sorcerer_1"] = "mage_flanker_highvalue|war_beast|com|1",
    ["wh_main_nor_cha_chaos_sorcerer_2"] = "mage_flanker_highvalue|war_machine|com|1",
    ["wh_main_nor_cha_marauder_chieftan_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_main_nor_cha_marauder_chieftan_1"] = "melee_highvalue|war_beast|com|1",
    ["wh_main_nor_cha_marauder_chieftan_2"] = "melee_highvalue|war_machine|com|1",
    ["wh_main_nor_cha_marauder_chieftan_3"] = "melee_flanker_shock_highvalue|war_beast|com|1",
    ["wh_main_nor_inf_chaos_marauders_0"] = "melee|inf_melee|inf_mel|0",
    ["wh_main_nor_inf_chaos_marauders_1"] = "melee|inf_melee|inf_mel|0",
    ["wh_main_nor_mon_chaos_trolls"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh_main_nor_mon_chaos_warhounds_0"] = "melee_flanker|inf_melee|inf_mel|0",
    ["wh_main_nor_mon_chaos_warhounds_1"] = "melee_flanker|inf_melee|inf_mel|0",
    ["wh_main_teb_cha_captain_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_main_teb_cha_captain_1"] = "melee_highvalue|cavalry|com|1",
    ["wh_main_teb_cha_captain_2"] = "melee_highvalue|cavalry|com|1",
    ["wh_main_teb_cha_general_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_main_teb_cha_general_1"] = "melee_highvalue|cavalry|com|1",
    ["wh_main_teb_cha_general_2"] = "melee_highvalue|cavalry|com|1",
    ["wh_main_teb_cha_wizard_0"] = "mage_highvalue|inf_melee|com|0",
    ["wh_main_teb_cha_wizard_1"] = "mage_highvalue|cavalry|com|1",
    ["wh_main_vmp_cav_black_knights_0"] = "melee_flanker_undead|cavalry|cav_mel|1",
    ["wh_main_vmp_cav_black_knights_3"] = "melee_flanker_shock_undead|cavalry|cav_shk|1",
    ["wh_main_vmp_cav_hexwraiths"] = "melee_flanker_undead|cavalry|cav_mel|0",
    ["wh_main_vmp_cha_banshee"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh_main_vmp_cha_heinrich_kemmler"] = "mage_highvalue_undead|inf_melee|com|0",
    ["wh_main_vmp_cha_mannfred_von_carstein_0"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh_main_vmp_cha_mannfred_von_carstein_2"] = "flying_melee_highvalue_undead|cavalry|com|1",
    ["wh_main_vmp_cha_mannfred_von_carstein_3"] = "flying_melee_highvalue_undead|war_beast|com|1",
    ["wh_main_vmp_cha_mannfred_von_carstein_4"] = "melee_flanker_shock_highvalue_undead|cavalry|com|1",
    ["wh_main_vmp_cha_master_necromancer_0"] = "mage_highvalue_undead|inf_melee|com|0",
    ["wh_main_vmp_cha_master_necromancer_4"] = "flying_mage_highvalue_undead|cavalry|com|1",
    ["wh_main_vmp_cha_master_necromancer_5"] = "mage_highvalue_undead|cavalry|com|1",
    ["wh_main_vmp_cha_necromancer_0"] = "mage_highvalue_undead|inf_melee|com|0",
    ["wh_main_vmp_cha_necromancer_5"] = "mage_flanker_highvalue_undead|cavalry|com|1",
    ["wh_main_vmp_cha_vampire_0"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh_main_vmp_cha_vampire_1"] = "melee_flanker_shock_highvalue_undead|cavalry|com|1",
    ["wh_main_vmp_cha_vampire_2"] = "flying_melee_highvalue_undead|cavalry|com|1",
    ["wh_main_vmp_cha_vampire_lord_0"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh_main_vmp_cha_vampire_lord_2"] = "flying_melee_highvalue_undead|cavalry|com|1",
    ["wh_main_vmp_cha_vampire_lord_3"] = "flying_melee_highvalue_undead|war_beast|com|1",
    ["wh_main_vmp_cha_vampire_lord_5"] = "melee_flanker_shock_highvalue_undead|cavalry|com|1",
    ["wh_main_vmp_cha_wight_king_0"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh_main_vmp_cha_wight_king_0_summoned"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh_main_vmp_cha_wight_king_1"] = "melee_flanker_shock_highvalue_undead|cavalry|com|1",
    ["wh_main_vmp_cha_wight_king_2"] = "melee_flanker_shock_highvalue_undead|cavalry|com|1",
    ["wh_main_vmp_inf_cairn_wraiths"] = "melee_flanker_undead|inf_melee|inf_mel|0",
    ["wh_main_vmp_inf_crypt_ghouls"] = "melee_undead|inf_melee|inf_mel|0",
    ["wh_main_vmp_inf_crypt_ghouls_summoned"] = "melee_undead|inf_melee|inf_mel|0",
    ["wh_main_vmp_inf_grave_guard_0"] = "melee_undead|inf_melee|inf_mel|0",
    ["wh_main_vmp_inf_grave_guard_0_summoned"] = "melee_undead|inf_melee|inf_mel|0",
    ["wh_main_vmp_inf_grave_guard_1"] = "melee_undead|inf_melee|inf_mel|0",
    ["wh_main_vmp_inf_skeleton_warriors_0"] = "melee_undead|inf_melee|inf_mel|0",
    ["wh_main_vmp_inf_skeleton_warriors_0_summoned"] = "melee_undead|inf_melee|inf_mel|0",
    ["wh_main_vmp_inf_skeleton_warriors_1"] = "melee_anti_large_undead|inf_melee|inf_mel|0",
    ["wh_main_vmp_inf_zombie"] = "melee_undead|inf_melee|inf_mel|0",
    ["wh_main_vmp_inf_zombie_summoned"] = "melee_undead|inf_melee|inf_mel|0",
    ["wh_main_vmp_mon_crypt_horrors"] = "melee_gatecrusher_undead|inf_melee|inf_mel|1",
    ["wh_main_vmp_mon_crypt_horrors_summoned"] = "melee_gatecrusher_undead|inf_melee|inf_mel|1",
    ["wh_main_vmp_mon_dire_wolves"] = "melee_flanker_undead|inf_melee|inf_mel|0",
    ["wh_main_vmp_mon_fell_bats"] = "flying_melee_flanker_undead|inf_melee|inf_mel|0",
    ["wh_main_vmp_mon_terrorgheist"] = "flying_melee_flanker_undead|inf_melee|inf_mel|1",
    ["wh_main_vmp_mon_terrorgheist_qb"] = "flying_melee_flanker_undead|inf_melee|inf_mel|1",
    ["wh_main_vmp_mon_vargheists"] = "flying_melee_flanker_undead|inf_melee|inf_mel|1",
    ["wh_main_vmp_mon_varghulf"] = "melee_gatecrusher_shock_undead|inf_melee|inf_mel|1",
    ["wh_main_vmp_veh_black_coach"] = "melee_flanker_shock_undead|war_machine|chariot|1",
    ["wh_pro01_dwf_cha_grombrindal_0"] = "melee_highvalue|inf_melee|com|0",
    ["wh_pro02_vmp_cha_isabella_von_carstein_0"] = "melee_highvalue_undead|inf_melee|com|0",
    ["wh_pro02_vmp_cha_isabella_von_carstein_2"] = "flying_melee_highvalue_undead|cavalry|com|1",
    ["wh_pro02_vmp_cha_isabella_von_carstein_4"] = "melee_flanker_shock_highvalue_undead|cavalry|com|1",
    ["wh_pro03_vmp_cha_krell_0"] = "melee_highvalue_undead|inf_melee|inf_mel|0",
    ["wh_pro03_vmp_cha_krell_campaign_0"] = "melee_highvalue_undead|inf_melee|inf_mel|0",
    ["wh_pro03_vmp_cha_krell_campaign_1"] = "melee_highvalue_undead|inf_melee|inf_mel|0",
    ["wh_pro03_vmp_cha_krell_campaign_2"] = "melee_highvalue_undead|inf_melee|inf_mel|0",
    ["wh_pro03_vmp_cha_krell_campaign_3"] = "melee_highvalue_undead|inf_melee|inf_mel|0",
    ["wh_pro03_vmp_cha_krell_campaign_4"] = "melee_highvalue_undead|inf_melee|inf_mel|0",
    ["wh_pro04_brt_cav_knights_errant_ror_0"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh_pro04_brt_cav_knights_of_the_realm_ror_0"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh_pro04_brt_cav_mounted_yeomen_ror_0"] = "ranged_harasser_flanker|cavalry|cav_mis|1",
    ["wh_pro04_brt_cav_questing_knights_ror_0"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh_pro04_brt_inf_battle_pilgrims_ror_0"] = "melee|inf_melee|inf_mel|0",
    ["wh_pro04_brt_inf_foot_squires_ror_0"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh_pro04_bst_inf_bestigor_herd_ror_0"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh_pro04_bst_inf_centigors_ror_0"] = "melee_flanker_shock|inf_melee|inf_mel|1",
    ["wh_pro04_bst_inf_cygor_ror_0"] = "ranged_no_skirmish_gatecrusher|inf_ranged|spcl|1",
    ["wh_pro04_bst_inf_gor_herd_ror_0"] = "melee|inf_melee|inf_mel|0",
    ["wh_pro04_bst_inf_minotaurs_ror_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh_pro04_bst_inf_ungor_spearmen_ror_0"] = "melee_anti_large|inf_melee|inf_spr|0",
    ["wh_pro04_chs_art_hellcannon_ror_0"] = "ranged_indirect_arty|artillery|art_fld|0",
    ["wh_pro04_chs_cav_chaos_knights_ror_0"] = "melee_flanker_shock|war_beast|cav_mel|1",
    ["wh_pro04_chs_inf_chaos_warriors_ror_0"] = "melee|inf_melee|inf_mel|0",
    ["wh_pro04_chs_inf_forsaken_ror_0"] = "melee|inf_melee|inf_mel|0",
    ["wh_pro04_chs_mon_chaos_spawn_ror_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh_pro04_chs_mon_dragon_ogre_ror_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh_pro04_nor_inf_chaos_marauders_ror_0"] = "melee|inf_melee|inf_mel|0",
    ["wh_pro04_nor_inf_marauder_berserkers_ror_0"] = "melee|inf_melee|inf_mel|0",
    ["wh_pro04_nor_mon_fimir_ror_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh_pro04_nor_mon_marauder_warwolves_ror_0"] = "melee_flanker|inf_melee|inf_mel|0",
    ["wh_pro04_nor_mon_skinwolves_ror_0"] = "melee_flanker|inf_melee|inf_mel|1",
    ["wh_pro04_nor_mon_war_mammoth_ror_0"] = "melee_gatecrusher_shock|war_beast|inf_mel|1",
    ["wh_pro04_wef_cav_wild_riders_ror_0"] = "melee_flanker_shock|cavalry|cav_shk|1",
    ["wh_pro04_wef_inf_eternal_guard_ror_0"] = "melee_anti_large|inf_melee|inf_spr|0",
    ["wh_pro04_wef_inf_wardancers_ror_0"] = "melee|inf_melee|inf_spr|0",
    ["wh_pro04_wef_inf_waywatchers_ror_0"] = "ranged_stalkers_harasser|inf_ranged|inf_mis|0",
    ["wh_pro04_wef_inf_wildwood_rangers_ror_0"] = "melee_anti_large|inf_melee|inf_mel|0",
    ["wh_pro04_wef_mon_treekin_ror_0"] = "melee_gatecrusher|inf_melee|inf_mel|1",
    ["wh_twa03_def_inf_squig_explosive_0"] = "melee_flanker_shock|inf_melee|inf_mel|1",
}

local function profile_of(unit)
    local s = CZX_UNIT_PROFILE[unit:type()]
    if not s then return nil end
    local ai, cat, cls, lg = s:match("^([^|]*)|([^|]*)|([^|]*)|(%d)")
    ai = ai or ""
    return {
        ai = ai, cat = cat or "", cls = cls or "", large = (lg == "1"),
        -- ai_usage_group taxonomy flags (community-informed):
        anti_large  = ai:find("anti_large") ~= nil,  -- halberds/spears: +BvL vs cav & monsters
        shock       = ai:find("shock") ~= nil,       -- charge bonus is their main damage -> cycle
        highvalue   = ai:find("highvalue") ~= nil,   -- expensive -> wounded pull-out priority
        no_skirmish = ai:find("no_skirmish") ~= nil, -- cannot skirmish; don't rely on it
        harasser    = ai:find("harasser") ~= nil,    -- shoot-and-scoot, never stand in melee
        mage        = ai:find("mage") ~= nil,
    }
end

local function ubool(unit, method)
    local ok, v = pcall(function() return unit[method](unit) end)
    return ok and v == true
end

-- engine's own unit-value estimate [需验证取值范围]
local function sv_of(unit)
    local ok, v = pcall(function() return unit:strategic_value() end)
    return (ok and is_number(v)) and v or 0
end

-- pick the best target from a list of enemy units by utility score;
-- score_fn returns -inf to exclude a candidate.
local function best_scored(unit, list, score_fn)
    local best, bs = nil, -math.huge
    for _, e in ipairs(list) do
        local s = score_fn(e)
        if s and s > bs then best, bs = e, s end
    end
    return best
end

-- role classification: baked profile first (exact, covers vanilla + our mods),
-- runtime boolean chain for unbaked (foreign mod) units. First match wins.
local function classify(unit, p)
    local prof = p.prof
    if prof then
        local cat = prof.cat
        if cat == "war_machine" or cat == "artillery" then return "artillery" end
        if prof.cls == "com" then return "lord" end
        -- mounted/ranged hybrids are skirmishers, not shock troops: they harass
        -- and kite, and melt if they stand in melee (community consensus)
        if p.flies then return (p.ammo ~= 0 or prof.harasser) and "cav_shot" or "flyer" end
        if prof.large or cat == "war_beast" then return "monster" end
        if cat == "cavalry" then
            return (p.ammo ~= 0 or prof.harasser or prof.ai:find("ranged_cav"))
                and "cav_shot" or "cav"
        end
        if cat == "inf_ranged" or p.ammo ~= 0 then return "shooter" end
        return "melee"
    end
    if ubool(unit, "is_artillery") or ubool(unit, "is_war_machine") then return "artillery" end
    if ubool(unit, "is_commanding_unit") then return "lord" end
    if p.flies then return p.ammo ~= 0 and "cav_shot" or "flyer" end
    if ubool(unit, "is_war_beasts") or ubool(unit, "is_elephants") then return "monster" end
    if ubool(unit, "is_cavalry") or ubool(unit, "is_chariot") or p.speed >= CONFIG.cav_min_speed then
        return p.ammo ~= 0 and "cav_shot" or "cav"
    end
    if p.ammo ~= 0 and p.range >= CONFIG.artillery_min_range then return "artillery" end
    if p.ammo ~= 0 then return "shooter" end
    return "melee"
end

local function probe_unit(unit)
    local p = {}
    local ok_a, ammo = pcall(function() return unit:ammo_left() end)
    p.ammo = (ok_a and is_number(ammo)) and ammo or 0
    local ok_r, range = pcall(function() return unit:missile_range() end)
    p.range = (ok_r and is_number(range)) and range or 0
    local ok_s, speed = pcall(function() return unit:fast_speed() end)
    p.speed = (ok_s and is_number(speed)) and speed or 0
    local ok_f, flies = pcall(function() return unit:can_fly() end)
    p.flies = ok_f and flies or false
    p.prof = profile_of(unit)
    local t = unit:type()
    if not seen_types[t] then
        seen_types[t] = true
        out_log("role-probe " .. t
            .. " prof=" .. (p.prof and (p.prof.cat .. "/" .. p.prof.ai .. (p.prof.large and "/L" or "")) or "none")
            .. " spd=" .. p.speed .. " ammo=" .. p.ammo .. " range=" .. p.range .. " fly=" .. tostring(p.flies))
    end
    return p
end

local function idle_long_enough(unit, now_ms)
    if not CONFIG.idle_kick then return false end -- master switch for movement orders
    local uid = tostring(unit:unique_ui_id())
    if not unit:is_idle() then
        idle_since[uid] = nil
        return false
    end
    if not idle_since[uid] then
        idle_since[uid] = now_ms
        return false
    end
    if (now_ms - idle_since[uid]) < CONFIG.idle_kick_after_s * 1000 then return false end
    if kicked_at[uid] and (now_ms - kicked_at[uid]) < CONFIG.order_retry_ms then return false end
    return true
end

-- stale-order detection: is_idle() lies for units carrying an old order —
-- a unit told to hold/defend stands forever with is_idle()=false and the task
-- layer never sees it. "Has an order but is neither moving nor fighting" is
-- the real idle signature. Shooters get a pass while a target is in range
-- (standing and firing = working).
local function effectively_idle(d, unit, ctx)
    if unit:is_idle() then return true end
    local ok_m, moving = pcall(function() return unit:is_moving() end)
    if ok_m and moving then return false end
    local ok_f, melee = pcall(function() return unit:is_in_melee() end)
    if ok_f and melee then return false end
    if d.role == "shooter" or d.role == "artillery" or d.role == "cav_shot" then
        local e, dist = nearest_enemy(unit)
        if e then
            local ok_r, rng = pcall(function() return unit:missile_range() end)
            if ok_r and is_number(rng) and rng > 0 and dist <= rng then
                return false -- standing in range = firing
            end
        end
    end
    return true
end

-- task gate: effectively idle for idle_kick_after_s, then throttled by
-- order_retry_ms (not the 20s ability retry)
local function task_ready(d, ctx)
    if not CONFIG.idle_kick then return false end
    local unit, now_ms = d.unit, ctx.now_ms
    local uid = tostring(unit:unique_ui_id())
    if not effectively_idle(d, unit, ctx) then
        idle_since[uid] = nil
        return false
    end
    if not idle_since[uid] then
        idle_since[uid] = now_ms
        return false
    end
    if (now_ms - idle_since[uid]) < CONFIG.idle_kick_after_s * 1000 then return false end
    if kicked_at[uid] and (now_ms - kicked_at[uid]) < CONFIG.order_retry_ms then return false end
    return true
end

local function order_attack(su, unit, e, now_ms, tag, force)
    local uid = tostring(unit:unique_ui_id())
    -- focus cap: don't pile the whole line onto one target this tick
    -- (force bypasses: a capped target still beats standing idle)
    local euid = tostring(e:unique_ui_id())
    if not force and (focus_count[euid] or 0) >= CONFIG.focus_cap then return end
    local ok, err = pcall(function()
        su.uc:attack_unit(e, true, true)
        su.uc:release_control()
    end)
    if ok then
        note_our_order(uid, now_ms, euid)
        focus_count[euid] = (focus_count[euid] or 0) + 1
        kicked_at[uid] = now_ms
        idle_since[uid] = nil
        -- arm cycle-charge: a cavalry attack order starts the fight timer
        if role_of[uid] == "cav" or role_of[uid] == "flyer" then
            charge_state[uid] = { phase = "in", at = now_ms, target = e }
        end
        out_log(tag .. " " .. unit:type() .. " (" .. uid .. ") -> " .. e:type())
    else
        out_log("ERROR " .. tag .. " " .. tostring(err))
        idle_since[uid] = now_ms -- restart the idle timer so we don't retry every poll
    end
end

local function order_return(su, unit, anchor, now_ms)
    local uid = tostring(unit:unique_ui_id())
    local ok, err = pcall(function()
        local ok_b, bearing = pcall(function() return unit:bearing() end)
        local deg = (ok_b and is_number(bearing)) and bearing * 180 / math.pi or 0
        local ok_w, width = pcall(function() return unit:ordered_width() end)
        su.uc:goto_location_angle_width(anchor:position(), deg, (ok_w and is_number(width)) and width or 20, true)
        su.uc:release_control()
    end)
    if ok then
        note_our_order(uid, now_ms)
        kicked_at[uid] = now_ms
        idle_since[uid] = nil
        out_log("screen-return " .. unit:type() .. " (" .. uid .. ")")
    else
        out_log("ERROR screen-return " .. tostring(err))
        idle_since[uid] = now_ms
    end
end

local function set_behaviour_once(su, unit, behaviour, flag_key)
    local uid = tostring(unit:unique_ui_id())
    local k = uid .. "|" .. (flag_key or behaviour)
    if guard_set[k] then return end
    guard_set[k] = true
    local ok, can = pcall(function() return unit:can_use_behaviour(behaviour) end)
    if not (ok and can) then return end
    local ok2, active = pcall(function() return unit:is_behaviour_active(behaviour) end)
    if ok2 and active then return end
    pcall(function()
        su.uc:change_behaviour_active(behaviour, true, false)
        su.uc:release_control()
    end)
end

-- generic screen behaviour: hold near an anchor list, intercept close threats,
-- fall back when dragged too far out. Threats are scored, not just nearest:
-- big threats and high-value enemies get intercepted first.
local function screen_hold(d, ctx, intercept_r, leash_r, tag)
    if not task_ready(d, ctx) then return end
    local anchor = ctx.shooters and nearest_of(d.unit, ctx.shooters)
    local t = best_scored(d.unit, ctx.enemies, function(e)
        local dist = unit_dist(d.unit, e)
        local near = dist <= intercept_r
            or (anchor and unit_dist(e, anchor) <= CONFIG.protect_radius_m)
        if not near then return -math.huge end
        local s = -dist * 0.5 + counter_of(d.role, ctx.erole[e])
        if ctx.erole[e] == "monster" then s = s + 50 end
        if d.anti_large and (ctx.erole[e] == "monster" or ctx.erole[e] == "cav") then s = s + 40 end
        return s + sv_of(e) * 0.2
    end)
    if t then
        order_attack(d.su, d.unit, t, ctx.now_ms, tag .. "-intercept")
        return
    end
    if anchor and unit_dist(d.unit, anchor) > leash_r then
        order_return(d.su, d.unit, anchor, ctx.now_ms)
    end
end

local function kick_if_idle(su, unit, now_ms)
    if not idle_long_enough(unit, now_ms) then return end
    local e, dist = nearest_enemy(unit)
    if e and dist <= CONFIG.idle_kick_range_m then
        order_attack(su, unit, e, now_ms, "idle-kick")
    end
end

---------------------------------------------------------------------------------------------
-- handoff layer: explicit player<->AI control via hotkey + engine command events
---------------------------------------------------------------------------------------------

-- read the currently selected unit cards (AI General's for_each_accessible_unit_card
-- approach: battle_orders -> cards_panel -> review_DY, card Id() == unique_ui_id)
local function selected_uids()
    local ids = {}
    local ok_p, parent = pcall(function()
        return find_uicomponent(core:get_ui_root(), "battle_orders", "cards_panel", "review_DY")
    end)
    if not (ok_p and parent) then return ids end
    for i = 0, parent:ChildCount() - 1 do
        local ok_c, card = pcall(function() return UIComponent(parent:Find(i)) end)
        if ok_c and card and tostring(card:CallbackId()) == "UnitCard" then
            local ok_s, st = pcall(function() return card:CurrentState() end)
            if ok_s and st and tostring(st):lower():find("selected") then
                ids[tostring(card:Id())] = true
            end
        end
    end
    return ids
end

-- hotkey toggle: selected AI units -> player (never re-delegated);
-- selected player units -> back to the planner
local function handoff_toggle()
    local sel = selected_uids()
    if next(sel) == nil then out_log("handoff: nothing selected") return end
    local gave, took = 0, 0
    for_each_player_unit(function(unit)
        local uid = tostring(unit:unique_ui_id())
        if sel[uid] then
            local su = bm:get_scriptunit_for_unit(unit)
            if su and su.uc then
                if managed[uid] and not reclaimed[uid] then
                    reclaimed[uid] = true
                    overridden[uid] = nil
                    order_dest[uid] = nil
                    if planner then pcall(function() planner:remove_sunits(su) end) end
                    took = took + 1
                    out_log("handoff take " .. unit:type() .. " (" .. uid .. ")")
                else
                    reclaimed[uid] = nil
                    overridden[uid] = nil
                    order_dest[uid] = nil
                    managed[uid] = true
                    if planner then pcall(function() planner:add_sunits(su) end) end
                    gave = gave + 1
                    out_log("handoff give " .. unit:type() .. " (" .. uid .. ")")
                end
            end
        end
    end)
    out_log("handoff give=" .. gave .. " take=" .. took)
end

-- hotkey override: selected AI units go to the player temporarily; the tick
-- loop hands them back once they sit idle (micro the unit, then forget it)
local function handoff_override(now_ms)
    local sel = selected_uids()
    local n = 0
    for_each_player_unit(function(unit)
        local uid = tostring(unit:unique_ui_id())
        if sel[uid] and managed[uid] and not reclaimed[uid] and not overridden[uid] then
            local su = bm:get_scriptunit_for_unit(unit)
            if su then
                overridden[uid] = { at = now_ms, idle_at = nil }
                order_dest[uid] = nil
                if planner then pcall(function() planner:remove_sunits(su) end) end
                n = n + 1
                out_log("override " .. unit:type() .. " (" .. uid .. ")")
            end
        end
    end)
    if n > 0 then out_log("override n=" .. n) end
end

local function add_handoff_listener(name, shortcut, fn)
    if not shortcut then return end
    local ok, err = pcall(function()
        core:add_listener(name, "ShortcutTriggered",
            function(ctx) return ctx.string == shortcut end,
            function() bm:callback(fn, 0, name .. "_cb") end,
            true)
    end)
    if not ok then out_log("ERROR hotkey " .. name .. " " .. tostring(err)) end
end

-- engine command events: UI orders (Move/Attack/etc.) arriving OUTSIDE our task
-- pass on a delegated unit are the player clicking -> instant reclaim. Our own
-- uc orders fire inside the tick where in_task_pass filters them out.
local function cmd_probe_log(ctx, name)
    if not CONFIG.cmd_probe then return end
    local n = (cmd_seen[name] or 0) + 1
    cmd_seen[name] = n
    if n > 8 then return end
    local ok_u, u = pcall(function() return ctx:get_unit() end)
    local ok_s, s1 = pcall(function() return ctx:get_string1() end)
    local ok_p, pos = pcall(function() return ctx:get_position() end)
    local ok_b, b1 = pcall(function() return ctx:get_bool1() end)
    out_log("cmd " .. name .. " #" .. n
        .. " unit=" .. (ok_u and u and u:type() or "nil")
        .. " uid=" .. (ok_u and u and tostring(u:unique_ui_id()) or "-")
        .. " ai=" .. tostring(ok_u and u and u:is_ai_controlled())
        .. " s1=" .. tostring(ok_s and s1)
        .. " pos=" .. tostring(ok_p and pos)
        .. " b1=" .. tostring(ok_b and b1)
        .. " inpass=" .. tostring(in_task_pass))
end

local function add_order_listener(name)
    local ok, err = pcall(function()
        bm:register_command_handler_callback(name, function(ctx)
            cmd_probe_log(ctx, name)
            if not CONFIG.cmd_reclaim or in_task_pass then return end
            local ok_u, u = pcall(function() return ctx:get_unit() end)
            if not (ok_u and u) then return end
            local uid = tostring(u:unique_ui_id())
            -- player-issued order on a unit we think we own = they took it
            if managed[uid] and not reclaimed[uid] and not overridden[uid] then
                reclaimed[uid] = true
                order_dest[uid] = nil
                -- must leave the planner's sunit list or the next directive
                -- refresh stomps the player's order
                if planner then
                    local ok_s, su_r = pcall(function()
                        return bm:get_scriptunit_for_unit(u)
                    end)
                    if ok_s and su_r then
                        pcall(function() planner:remove_sunits(su_r) end)
                    end
                end
                out_log("reclaimed-cmd " .. name .. " " .. u:type() .. " (" .. uid .. ")")
            end
        end, "czx_cmd_" .. name)
    end)
    if not ok then out_log("ERROR cmd " .. name .. " " .. tostring(err)) end
end

---------------------------------------------------------------------------------------------
-- tactical micro
---------------------------------------------------------------------------------------------

-- move d's unit away from a world position (fallback / dodge / pull-out)
local function order_flee_pos(su, unit, from_pos, dist_m, now_ms, tag)
    local uid = tostring(unit:unique_ui_id())
    local ok, err = pcall(function()
        local up = unit:position()
        local dx, dz = up:get_x() - from_pos:get_x(), up:get_z() - from_pos:get_z()
        local len = math.sqrt(dx * dx + dz * dz)
        if len < 1 then dx, dz, len = 0, 1, 1 end -- degenerate: flee "north"
        local dest = v(up:get_x() + dx / len * dist_m, up:get_z() + dz / len * dist_m)
        local ok_b, bearing = pcall(function() return unit:bearing() end)
        local deg = (ok_b and is_number(bearing)) and bearing * 180 / math.pi or 0
        local ok_w, width = pcall(function() return unit:ordered_width() end)
        su.uc:goto_location_angle_width(dest, deg, (ok_w and is_number(width)) and width or 20, true)
        su.uc:release_control()
    end)
    if ok then
        note_our_order(uid, now_ms)
        kicked_at[uid] = now_ms
        idle_since[uid] = nil
        out_log(tag .. " " .. unit:type() .. " (" .. uid .. ")")
    else
        out_log("ERROR " .. tag .. " " .. tostring(err))
    end
    return ok
end

-- cav cycle-charge: fight briefly, pull out, re-charge. Returns true when it
-- issued an order this tick (caller skips other behaviour for this unit).
local function cycle_charge_step(d, ctx)
    if not CONFIG.cycle_charge then return false end
    local uid = tostring(d.unit:unique_ui_id())
    local st = charge_state[uid]
    if not st then return false end -- set on first attack order below
    local now_ms = ctx.now_ms
    if st.phase == "in" then
        -- target died or routed: cycle done; a fresh attack order re-arms it
        local ok_t, alive = pcall(function()
            return st.target ~= nil and not st.target:is_routing()
        end)
        if not (ok_t and alive) then charge_state[uid] = nil; return false end
        local ok_m, melee = pcall(function() return d.unit:is_in_melee() end)
        if ok_m and melee and (now_ms - st.at) > CONFIG.charge_fight_ms then
            local ok_p, tp = pcall(function() return st.target:position() end)
            if ok_p and tp then
                order_flee_pos(d.su, d.unit, tp, CONFIG.charge_pull_m, now_ms, "charge-out")
                st.phase, st.at = "out", now_ms
                return true
            end
        end
    elseif st.phase == "out" then
        if (now_ms - st.at) > CONFIG.charge_regroup_ms then
            local ok_v, moving = pcall(function() return d.unit:is_moving() end)
            if not (ok_v and moving) or (now_ms - st.at) > CONFIG.charge_regroup_ms * 3 then
                charge_state[uid] = nil -- fall through; a fresh attack order re-arms it
            end
        else
            return true -- still pulling out; hold other orders
        end
    end
    return false
end

-- wounded disengage: high-value units below the hp threshold hop out of melee
-- when caught in it, then go straight back to the task layer once clear — hp
-- doesn't regen mid-battle, so parking them out back is just losing the unit.
-- Planner membership untouched; the standing directive can keep using them.
local function wounded_step(d, ctx)
    if not CONFIG.wounded_pullout then return false end
    local uid = tostring(d.unit:unique_ui_id())
    if d.role ~= "lord" and d.role ~= "monster" and d.role ~= "cav"
        and not d.highvalue then return false end -- highvalue flag pulls elites of any role
    local ok_h, hp = pcall(function() return d.unit:unary_hitpoints() end)
    if not (ok_h and is_number(hp)) then return false end
    local ok_m, melee = pcall(function() return d.unit:is_in_melee() end)
    if hp >= CONFIG.wounded_hp or not (ok_m and melee) then
        wounded_pull[uid] = nil -- healthy, or clear of melee: normal tasking
        return false
    end
    -- wounded AND still in melee: hop away from the nearest enemy, throttled
    local last = wounded_pull[uid] or 0
    if (ctx.now_ms - last) < CONFIG.wounded_retry_ms then return true end
    local threat = nearest_of(d.unit, ctx.enemies)
    if not threat then return false end
    local ok_p, tp = pcall(function() return threat:position() end)
    if not (ok_p and tp) then return false end
    if order_flee_pos(d.su, d.unit, tp, CONFIG.wounded_pull_m, ctx.now_ms, "wounded-pull") then
        wounded_pull[uid] = ctx.now_ms
    end
    return true
end

-- shooter kiting: a melee-role enemy closing in triggers a fallback move; the
-- unit resumes firing once clear (skirmish flag alone retreats too early)
local function kite_step(d, ctx)
    if not CONFIG.kite_fallback then return false end
    if d.role ~= "shooter" and d.role ~= "cav_shot" then return false end
    local threat, td = nil, math.huge
    for _, e in ipairs(ctx.enemies) do
        local r = ctx.erole[e]
        if r == "melee" or r == "monster" or r == "cav" or r == "flyer" then
            local ok_d, dist = pcall(function()
                return e:position():distance_xz(d.unit:position())
            end)
            if ok_d and dist and dist < td then threat, td = e, dist end
        end
    end
    if not (threat and td <= CONFIG.kite_threat_m) then return false end
    local ok_v, moving = pcall(function() return d.unit:is_moving() end)
    if ok_v and moving then return true end -- already falling back; hold
    local ok_p, tp = pcall(function() return threat:position() end)
    if ok_p and tp then
        order_flee_pos(d.su, d.unit, tp, CONFIG.kite_dest_m, ctx.now_ms, "kite-back")
    end
    return true
end

---------------------------------------------------------------------------------------------
-- pass 2.5: task assignment (v2 ActionSelector v1).
-- doctrine + role + context -> task id; tasks are the vocabulary the squad
-- layer will later assign explicitly. Executors keyed by task below.
local function assign_task(d, ctx)
    local role, doc = d.role, ctx.doctrine
    if role == "artillery" then return "hold_position" end
    if role == "cav_shot" then return "harass" end -- mounted shooters skirmish in every doctrine
    if role == "lord" and d.mage and doc ~= "rush" then return "sheltered" end -- casters sit with the shooters (in rush everyone pushes)
    if doc == "gunline" then
        if role == "melee" or role == "monster" then return "protect_gunline" end
        if role == "cav" then return "intercept_breakthrough" end
        if role == "flyer" then return "hunt_backline" end
        if role == "shooter" then return "hold_fire_line" end
        if role == "lord" then return "free_engagement" end
    elseif doc == "balanced" then
        if role == "melee" or role == "monster" then return "protect_gunline" end
        if role == "cav" or role == "flyer" then return "hunt_backline" end
        if role == "lord" then return "free_engagement" end
        if role == "shooter" then return "free_fire" end
    elseif doc == "kite" then
        if role == "cav" or role == "flyer" then return "hunt_backline" end
        if role == "shooter" then return "hold_fire_line" end
        return "attack"
    end
    -- rush / none / unknown: everything pushes
    return "attack"
end

-- task executors; ctx = {now_ms, doctrine, shooters, enemies, ...}
local TASK_EXEC = {}

TASK_EXEC.protect_gunline = function(d, ctx)
    set_behaviour_once(d.su, d.unit, "defend")
    if ctx.doctrine == "gunline" then
        screen_hold(d, ctx, CONFIG.intercept_radius_m, CONFIG.leash_radius_m, "screen")
    else
        screen_hold(d, ctx, CONFIG.bal_intercept_radius_m, CONFIG.bal_leash_radius_m, "screen")
    end
end

TASK_EXEC.intercept_breakthrough = function(d, ctx)
    -- gunline cav reserve: intercept whatever presses the line, strongly
    -- preferring monsters threatening the anchor
    if not task_ready(d, ctx) then return end
    local anchor = nearest_of(d.unit, ctx.shooters)
    local t = best_scored(d.unit, ctx.enemies, function(e)
        local dist = unit_dist(d.unit, e)
        local near = dist <= CONFIG.cav_intercept_radius_m
            or (anchor and unit_dist(e, anchor) <= CONFIG.protect_radius_m * 2)
        if not near then return -math.huge end
        local s = -dist * 0.3 + sv_of(e) * 0.3 + counter_of("cav", ctx.erole[e])
        if ctx.erole[e] == "monster" then s = s + 80 end
        if d.anti_large and (ctx.erole[e] == "monster" or ctx.erole[e] == "cav") then s = s + 40 end
        return s
    end)
    if t then
        order_attack(d.su, d.unit, t, ctx.now_ms,
            ctx.erole[t] == "monster" and "cav-antilarge" or "cav-intercept")
        return
    end
    if anchor and unit_dist(d.unit, anchor) > CONFIG.bal_leash_radius_m then
        order_return(d.su, d.unit, anchor, ctx.now_ms)
    end
end

TASK_EXEC.hunt_backline = function(d, ctx)
    if not task_ready(d, ctx) then return end
    -- flyers prefer enemy flyers/artillery over ground backline
    if d.role == "flyer" then
        local t = best_scored(d.unit, ctx.enemies_airarty, function(e)
            local dist = unit_dist(d.unit, e)
            if dist > CONFIG.flyer_hunt_range_m then return -math.huge end
            return sv_of(e) - dist * 0.2
        end)
        if t then
            order_attack(d.su, d.unit, t, ctx.now_ms, "flyer-hunt")
            return
        end
    end
    local t = best_scored(d.unit, ctx.enemies_ranged, function(e)
        local dist = unit_dist(d.unit, e)
        if dist > CONFIG.flank_hunt_range_m then return -math.huge end
        return sv_of(e) - dist * 0.2 + counter_of(d.role, ctx.erole[e])
    end)
    if t then
        order_attack(d.su, d.unit, t, ctx.now_ms, "cav-hunt")
        return
    end
    -- nothing to hunt: gunline falls back to reserve interception, else loose screen
    if ctx.doctrine == "gunline" then
        TASK_EXEC.intercept_breakthrough(d, ctx)
    else
        screen_hold(d, ctx, CONFIG.bal_intercept_radius_m, CONFIG.bal_leash_radius_m, d.role)
    end
end

TASK_EXEC.free_engagement = function(d, ctx)
    -- lords act freely: intercept close threats but never get leashed back;
    -- among nearby enemies they prefer high-value targets
    set_behaviour_once(d.su, d.unit, "defend")
    if not task_ready(d, ctx) then return end
    local t = best_scored(d.unit, ctx.enemies, function(e)
        local dist = unit_dist(d.unit, e)
        if dist > CONFIG.bal_intercept_radius_m then return -math.huge end
        return sv_of(e) - dist
    end)
    if t then order_attack(d.su, d.unit, t, ctx.now_ms, "lord-intercept") end
end

TASK_EXEC.hold_fire_line = function(d, ctx)
    set_behaviour_once(d.su, d.unit, "skirmish")
    if not task_ready(d, ctx) then return end
    local e, dist = nearest_enemy(d.unit)
    local ok_r, rng = pcall(function() return d.unit:missile_range() end)
    local hold = (ok_r and is_number(rng) and rng > 0) and rng * CONFIG.shooter_hold_mult or CONFIG.intercept_radius_m
    if e and dist <= hold then
        order_attack(d.su, d.unit, e, ctx.now_ms, "shooter-engage")
    end
    -- beyond hold range: stay put, don't walk past the screen
end

TASK_EXEC.sheltered = function(d, ctx)
    -- caster lord/hero: sit with the shooters, only swat what gets close
    set_behaviour_once(d.su, d.unit, "defend")
    screen_hold(d, ctx, 70, 90, "shelter")
end

TASK_EXEC.free_fire = function(d, ctx)
    -- skirmish where supported: engine auto-retreat beats our flee hops
    if not d.no_skirmish then set_behaviour_once(d.su, d.unit, "skirmish") end
    kick_if_idle(d.su, d.unit, ctx.now_ms)
end

TASK_EXEC.attack = function(d, ctx)
    if not task_ready(d, ctx) then return end
    -- finish off routing units first when we're mobile: free kills and they
    -- can't rally (community: run routers down with cavalry)
    if (d.role == "cav" or d.role == "flyer" or d.role == "cav_shot")
        and ctx.enemies_routing then
        local r, rd = nil, CONFIG.rundown_range_m
        for _, e in ipairs(ctx.enemies_routing) do
            local dist = unit_dist(d.unit, e)
            if dist < rd then r, rd = e, dist end
        end
        if r then
            order_attack(d.su, d.unit, r, ctx.now_ms, "run-down")
            return
        end
    end
    -- counter-aware pick: distance dominates but role counters and value sway it
    local t = best_scored(d.unit, ctx.enemies, function(e)
        local dist = unit_dist(d.unit, e)
        if dist > CONFIG.idle_kick_range_m then return -math.huge end
        local s = sv_of(e) * 0.5 - dist * 0.5 + counter_of(d.role, ctx.erole[e])
        if d.anti_large and (ctx.erole[e] == "monster" or ctx.erole[e] == "cav") then
            s = s + 40 -- halberds/spears counter BOTH monsters and cavalry
        end
        if ctx.erole[e] == "lord" then s = s + 25 end -- decapitating value
        return s
    end)
    if t then
        order_attack(d.su, d.unit, t, ctx.now_ms, "engage")
        return
    end
    -- every candidate capped or out of range: piling on beats standing idle
    local e2 = nearest_enemy(d.unit)
    if e2 then order_attack(d.su, d.unit, e2, ctx.now_ms, "engage-forced", true) end
end

-- mobile shooters (missile cav, ranged flyers, harassers): skirmish forever,
-- pick soft backline targets, never ordered into melee
TASK_EXEC.harass = function(d, ctx)
    set_behaviour_once(d.su, d.unit, "skirmish")
    if not task_ready(d, ctx) then return end
    local t = best_scored(d.unit, ctx.enemies, function(e)
        local dist = unit_dist(d.unit, e)
        if dist > CONFIG.harass_range_m then return -math.huge end
        local s = sv_of(e) * 0.4 - dist * 0.4 + counter_of("cav_shot", ctx.erole[e])
        if ctx.erole[e] == "artillery" then s = s + 30 end
        return s
    end)
    if t then order_attack(d.su, d.unit, t, ctx.now_ms, "harass") end
end

TASK_EXEC.hold_position = function() end -- artillery: never ordered; fires on its own

local function select_doctrine(delegated, shooters, n_mobile)
    if CONFIG.doctrine ~= "auto" then return CONFIG.doctrine end
    local n = #delegated
    if n == 0 then return "none" end
    if n_mobile / n >= CONFIG.kite_min_mobile_share then return "kite" end
    local share = #shooters / n
    if share >= CONFIG.gunline_min_share and #shooters >= 2 then return "gunline" end
    if share <= CONFIG.rush_max_shooter_share then return "rush" end
    return "balanced"
end

local last_doctrine = nil
local tick_n = 0

-- pass 0: auto-delegate the whole local army to a script_ai_planner so the
-- doctrine engine runs standalone (no AI General button needed). Only in
-- battle-start roster dump: both armies grouped by unit_type/role, one line
-- each — the post-battle review record for doctrine tuning
local function roster_dump()
    if roster_logged then return end
    roster_logged = true
    local tally = {}
    for_each_player_unit(function(u)
        local p = probe_unit(u)
        local k = u:type() .. "/" .. classify(u, p)
        tally[k] = (tally[k] or 0) + 1
    end)
    for k, n in pairs(tally) do out_log("roster ally " .. k .. " x" .. n) end
    tally = {}
    local alliance = bm:get_non_player_alliance()
    if alliance then
        local armies = alliance:armies()
        for a = 1, armies:count() do
            local units = armies:item(a):units()
            for u = 1, units:count() do
                local e = units:item(u)
                if e then
                    local p = probe_unit(e)
                    local k = e:type() .. "/" .. classify(e, p)
                    tally[k] = (tally[k] or 0) + 1
                end
            end
        end
    end
    for k, n in pairs(tally) do out_log("roster enemy " .. k .. " x" .. n) end
end

-- field battle types; sieges stay manual (CA warns planners do badly there).
local function ensure_delegation(now_ms)
    if not CONFIG.auto_delegate or planner then return end
    if now_ms < CONFIG.delegate_after_ms then return end
    local ok_t, btype = pcall(function() return bm:battle_type() end)
    if ok_t and btype and not DELEGATE_TYPES[btype] then return end
    local ok, sus = pcall(function() return bm:get_scriptunits_for_local_players_army() end)
    if not (ok and sus and sus:count() > 0) then return end
    local ok2, p = pcall(function() return script_ai_planner:new("czx_auto", sus) end)
    if ok2 and p then
        planner = p
        delegate_ms = now_ms
        -- the managed set owns tasking regardless of is_ai_controlled flaps
        for i = 1, sus:count() do
            local su0 = sus:item(i)
            local ok_u, u = pcall(function() return su0.unit end)
            if ok_u and u then
                local ok_i, id = pcall(function() return u:unique_ui_id() end)
                if ok_i and id then managed[tostring(id)] = true end
            end
        end
        out_log("auto-delegate units=" .. sus:count() .. " type=" .. tostring(btype))
        roster_dump()
        -- an orderless planner leaks its units back to the player within a
        -- tick; plant a hold order NOW so the warmup flag flap never starts
        pcall(function()
            planner:defend_position(planner:get_centre_point(), CONFIG.defend_radius_m)
        end)
    elseif not delegate_err_logged then
        delegate_err_logged = true
        out_log("ERROR auto-delegate " .. tostring(p))
    end
end

-- pass 0.5: keep a standing order on the planner. With no order the engine
-- silently hands its units back to the player (the "idle" army we observed);
-- with attack_unit/defend_position the engine commander keeps driving them,
-- and our per-unit uc orders layer on top for target choice.
local function issue_planner_directive(now_ms, doctrine, delegated, enemies)
    if not planner or doctrine == "none" then return end
    if doctrine == "rush" or doctrine == "kite" then
        -- refresh when the doctrine just changed, the target died/routed, or
        -- the refresh window elapsed (keeps the push aimed at the front line)
        local stale = true
        if directive_target then
            local ok_s, r = pcall(function() return directive_target:is_routing() end)
            stale = (not ok_s) or r == true
        end
        if doctrine == directive_doc and not stale
            and (now_ms - directive_ms) < CONFIG.directive_refresh_ms then
            return
        end
        -- closest enemy to any of our units = what the front line is facing
        local best, best_d = nil, math.huge
        for _, e in ipairs(enemies) do
            for _, d in ipairs(delegated) do
                local ok_d, dist = pcall(function()
                    return e:position():distance_xz(d.unit:position())
                end)
                if ok_d and dist and dist < best_d then best, best_d = e, dist end
            end
        end
        if not best then return end
        local ok_o, err = pcall(function() planner:attack_unit(best) end)
        if ok_o then
            directive_doc, directive_ms, directive_target = doctrine, now_ms, best
            directive_pos = nil -- attack directives track the live target unit
            out_log("directive attack -> " .. tostring(best:type())
                .. " d=" .. math.floor(best_d))
        else
            out_log("directive-fail attack " .. tostring(err))
        end
    else
        -- hold doctrines: defend the ground the group stands on; the planner's
        -- own should_reorder re-issues every 30s, we only re-issue on change
        if doctrine == directive_doc
            and (now_ms - directive_ms) < CONFIG.directive_refresh_ms then
            return
        end
        local ok_o, err = pcall(function()
            planner:defend_position(planner:get_centre_point(), CONFIG.defend_radius_m)
        end)
        if ok_o then
            directive_doc, directive_ms, directive_target = doctrine, now_ms, nil
            local ok_cp, cp = pcall(function() return planner:get_centre_point() end)
            directive_pos = (ok_cp and cp) or nil
            out_log("directive defend r=" .. CONFIG.defend_radius_m)
        else
            out_log("directive-fail defend " .. tostring(err))
        end
    end
end

---------------------------------------------------------------------------------------------
-- autotest sim: exercise the player-handoff paths without a human. Each cycle
-- picks a batch of managed units, issues a FOREIGN move order (no
-- note_our_order, outside in_task_pass — the same signature a real player
-- click produces), verifies the fingerprint reclaim fires, then hands them
-- back through the planner (group-AI signature) and verifies adoption.
---------------------------------------------------------------------------------------------
local sim = { phase = "off", uids = {}, at = 0, cycle = 0, did_speed = false }

local function sim_step(now_ms)
    if not CONFIG.test_sim or not planner then return end
    if not sim.did_speed then
        sim.did_speed = true
        local ok, err = pcall(function() bm:modify_battle_speed(CONFIG.test_speed) end)
        out_log("sim speed x" .. tostring(CONFIG.test_speed) .. " ok=" .. tostring(ok)
            .. (ok and "" or (" err=" .. tostring(err))))
    end

    if sim.phase == "off" then
        local managed_n = 0
        for_each_player_unit(function(unit)
            local uid = tostring(unit:unique_ui_id())
            if managed[uid] and not reclaimed[uid] and not overridden[uid] then
                managed_n = managed_n + 1
            end
        end)
        if managed_n >= CONFIG.test_batch * 2 then
            sim.phase, sim.at = "cooldown", now_ms
            out_log("sim begin managed=" .. managed_n)
        end
        return
    end

    if sim.phase == "cooldown" then
        if now_ms - sim.at < CONFIG.test_cycle_ms then return end
        local picks = {}
        for_each_player_unit(function(unit)
            if #picks >= CONFIG.test_batch then return end
            local uid = tostring(unit:unique_ui_id())
            if managed[uid] and not reclaimed[uid] and not overridden[uid]
                and not unit:is_routing() then
                picks[#picks + 1] = { uid = uid, unit = unit }
            end
        end)
        if #picks == 0 then return end
        sim.uids = {}
        for _, p in ipairs(picks) do
            local su = bm:get_scriptunit_for_unit(p.unit)
            if su and su.uc then
                local ok, err = pcall(function()
                    local up = p.unit:position()
                    -- no release_control: a real player grab leaves the unit
                    -- off AI control — that flag state is half the signature
                    su.uc:goto_location_angle_width(
                        v(up:get_x() + 40, up:get_z() + 40), 0, 20, true)
                end)
                if ok then
                    sim.uids[p.uid] = true
                    out_log("sim-order " .. p.uid)
                else
                    out_log("ERROR sim-order " .. tostring(err))
                end
            end
        end
        sim.cycle, sim.phase, sim.at = sim.cycle + 1, "await-reclaim", now_ms
        out_log("sim-cycle " .. sim.cycle .. " ordered=" .. #picks)
        return
    end

    if sim.phase == "await-reclaim" then
        local done, missing = 0, 0
        for uid in pairs(sim.uids) do
            if reclaimed[uid] then done = done + 1 else missing = missing + 1 end
        end
        if missing == 0 or now_ms - sim.at > CONFIG.test_verify_ms then
            out_log("sim-cycle " .. sim.cycle .. " reclaim=" .. done .. "/" .. (done + missing)
                .. (missing > 0 and " MISS" or ""))
            sim.phase, sim.at = "handback", now_ms
        end
        return
    end

    if sim.phase == "handback" then
        -- group-AI signature: planner add -> engine flips is_ai_controlled,
        -- the unmanaged+ai path adopts them back into managed[]
        for_each_player_unit(function(unit)
            local uid = tostring(unit:unique_ui_id())
            if sim.uids[uid] and reclaimed[uid] and not unit:is_routing() then
                local su = bm:get_scriptunit_for_unit(unit)
                if su then pcall(function() planner:add_sunits(su) end) end
            end
        end)
        sim.phase, sim.at = "await-back", now_ms
        return
    end

    if sim.phase == "await-back" then
        local done, missing = 0, 0
        for uid in pairs(sim.uids) do
            if managed[uid] and not reclaimed[uid] then done = done + 1 else missing = missing + 1 end
        end
        if missing == 0 or now_ms - sim.at > CONFIG.test_verify_ms then
            out_log("sim-cycle " .. sim.cycle .. " back=" .. done .. "/" .. (done + missing)
                .. (missing > 0 and " MISS" or ""))
            sim.phase, sim.at = "cooldown", now_ms
        end
        return
    end
end

local function tick()
    local now_ms = bm:time_elapsed_ms()
    focus_count = {} -- per-tick per-target order budget
    ensure_delegation(now_ms)

    -- pass 1: snapshot managed units + enemies, classify roles
    -- Ownership = the managed[] set, NOT is_ai_controlled: our uc orders flip
    -- that flag false (script control) and planner orders release_control()
    -- first, so it flaps under normal operation. The flag is only consulted
    -- for handback detection (unmanaged unit turning ai=true = the player
    -- enabled the vanilla group AI toggle) and to arm the order fingerprint.
    local delegated, shooters, n_mobile = {}, {}, 0
    for_each_player_unit(function(unit)
        local uid0 = tostring(unit:unique_ui_id())
        local ai_now = unit:is_ai_controlled()

        -- handback / adoption: a unit we don't own turning ai-controlled can
        -- only mean the player enabled its group AI (reinforcements arriving
        -- pre-toggled land here too) -> take it into management
        if ai_now and (reclaimed[uid0] or not managed[uid0]) then
            local tag = reclaimed[uid0] and "handed-back " or "adopted "
            reclaimed[uid0] = nil
            managed[uid0] = true
            order_dest[uid0] = nil
            prev_ordered[uid0] = nil
            atk_target_uid[uid0] = nil
            our_order_ms[uid0] = 0
            out_log(tag .. unit:type() .. " (" .. uid0 .. ")")
        end
        -- brand-new units arriving while uncontrolled (summons, reinforcements)
        if planner and not managed[uid0] and not reclaimed[uid0]
            and not overridden[uid0] and not ai_now and not unit:is_routing() then
            local su0 = bm:get_scriptunit_for_unit(unit)
            if su0 then
                pcall(function() planner:add_sunits(su0) end)
                managed[uid0] = true
                out_log("adopted-new " .. unit:type() .. " (" .. uid0 .. ")")
            end
        end

        local is_man = managed[uid0] and not reclaimed[uid0] and not overridden[uid0]

        -- reclaim fingerprint: while a managed unit sits uncontrolled
        -- (ai=false covers both our script-control and real player grabs),
        -- ordered_position is the receipt of the LAST order issued. If it
        -- moves well past our order's grace window, someone else gave a fresh
        -- order — in a single-player battle that can only be the player.
        if is_man and not ai_now then
            if prev_ai[uid0] then
                -- ai=true -> false this tick. The foreign order has ALREADY
                -- landed so ordered_position is the foreign dest — snapshotting
                -- it as baseline would erase the evidence. Use the last
                -- planner-seen destination instead, UNLESS our own recorded
                -- order is fresh (then order_dest already holds our intent).
                if order_dest[uid0] == nil
                    or (now_ms - (our_order_ms[uid0] or 0)) > CONFIG.order_grace_ms then
                    order_dest[uid0] = prev_ordered[uid0]
                end
            elseif order_dest[uid0] == nil
                and (now_ms - (our_order_ms[uid0] or 0)) > CONFIG.order_grace_ms then
                local ok_b, base = pcall(function() return unit:ordered_position() end)
                order_dest[uid0] = (ok_b and base) or nil
            end
            local base = order_dest[uid0]
            if base then
                local ok_n, np = pcall(function() return unit:ordered_position() end)
                if ok_n and np then
                    local ok_d, dd = pcall(function() return np:distance_xz(base) end)
                    local moved = ok_d and dd and dd > CONFIG.reclaim_move_m
                    if moved and atk_target_uid[uid0] then
                        -- attack-ordered units: ordered_position may track the
                        -- moving target; only reclaim if the target changed
                        local ok_c, ct = pcall(function() return unit:current_target() end)
                        local ok_i, cid = pcall(function()
                            return ct and ct:unique_ui_id()
                        end)
                        moved = not (ok_c and ok_i and cid
                            and tostring(cid) == atk_target_uid[uid0])
                    end
                    if moved then
                        -- directive flap: attack_unit/defend_position releases
                        -- control then re-orders every unit — a fresh
                        -- ordered_position near the directive target is the
                        -- PLANNER's order, not a player grab (observed: mass
                        -- reclaimed-ordered within seconds of each refresh)
                        local ok_dp, dp = nil, nil
                        if directive_target then
                            ok_dp, dp = pcall(function()
                                return directive_target:position()
                            end)
                        else
                            dp = directive_pos
                        end
                        if dp then
                            local ok_d2, d2 = pcall(function() return np:distance_xz(dp) end)
                            if ok_d2 and d2 and d2 <= 120 then
                                moved = false
                                order_dest[uid0] = np -- adopt the directive dest as baseline
                            end
                        end
                    end
                    if moved then
                        reclaimed[uid0] = true
                        order_dest[uid0] = nil
                        if planner then
                            local ok_s, su_r = pcall(function()
                                return bm:get_scriptunit_for_unit(unit)
                            end)
                            if ok_s and su_r then
                                pcall(function() planner:remove_sunits(su_r) end)
                            end
                        end
                        out_log("reclaimed-ordered " .. unit:type() .. " (" .. uid0 .. ")")
                        is_man = false
                    end
                end
            end
        end

        -- override decay: after the grace window, an idle overridden unit goes
        -- back to the AI (player finished microing it and walked away)
        local ov = overridden[uid0]
        if ov and not ai_now then
            if (now_ms - ov.at) > CONFIG.override_grace_s * 1000 then
                if unit:is_idle() then
                    ov.idle_at = ov.idle_at or now_ms
                    if (now_ms - ov.idle_at) > CONFIG.override_idle_s * 1000 then
                        overridden[uid0] = nil
                        -- back under the planner so the standing directive reaches it
                        if planner then
                            local su1 = bm:get_scriptunit_for_unit(unit)
                            if su1 then pcall(function() planner:add_sunits(su1) end) end
                        end
                        out_log("override-end " .. unit:type() .. " (" .. uid0 .. ")")
                    end
                else
                    ov.idle_at = nil -- still being microed
                end
            end
        end
        if ai_now then
            -- track the planner's live intent so a foreign order landing next
            -- tick can be measured against it
            local ok_o, op = pcall(function() return unit:ordered_position() end)
            if ok_o and op then prev_ordered[uid0] = op end
        end
        prev_ai[uid0] = ai_now

        if is_man and not unit:is_routing() and not unit:is_shattered() then
            local su = bm:get_scriptunit_for_unit(unit)
            if su and su.uc then
                local p = probe_unit(unit)
                local role = classify(unit, p)
                role_of[uid0] = role
                delegated[#delegated + 1] = {
                    su = su, unit = unit, role = role,
                    anti_large = p.prof and p.prof.anti_large,
                    highvalue = p.prof and p.prof.highvalue,
                    shock = p.prof and p.prof.shock,
                    no_skirmish = p.prof and p.prof.no_skirmish,
                    mage = p.prof and p.prof.mage,
                }
                if role == "shooter" or role == "artillery" then shooters[#shooters + 1] = unit end
                if role == "cav" or role == "flyer" or role == "cav_shot" then
                    n_mobile = n_mobile + 1
                end
            end
        else
            local uid = tostring(unit:unique_ui_id())
            idle_since[uid] = nil -- reset when not delegated
            guard_set[uid .. "|defend"] = nil
            guard_set[uid .. "|skirmish"] = nil
            unit_task[uid] = nil
            role_of[uid] = nil
            charge_state[uid] = nil
            wounded_pull[uid] = nil
            atk_target_uid[uid] = nil
            order_dest[uid] = nil
            prev_ordered[uid] = nil
        end
    end)

    -- enemy snapshot with roles for threat/target selection
    local enemies, enemies_ranged, enemies_monster, enemies_airarty = {}, {}, {}, {}
    local enemies_routing = {} -- routing-but-alive: cavalry runs these down
    local erole = {} -- [enemy unit] = role
    do
        local alliance = bm:get_non_player_alliance()
        -- visibility check asks "visible to OUR alliance"; pass our side explicitly
        local my_alliance = bm:alliances():item(bm:local_alliance())
        if alliance then
            local armies = alliance:armies()
            for a = 1, armies:count() do
                local units = armies:item(a):units()
                for u = 1, units:count() do
                    local e = units:item(u)
                    -- skip enemies hidden from our alliance (stalk/unspottable) so we
                    -- don't react to units the player can't even see
                    local visible = true
                    if my_alliance then
                        local ok_v, vis = pcall(function() return e:is_visible_to_alliance(my_alliance) end)
                        if ok_v and vis == false then visible = false end
                    end
                    local ok_h, hid = pcall(function() return e:is_hidden() end)
                    if ok_h and hid == true then visible = false end
                    if e and visible and not e:is_routing() then
                        local p = probe_unit(e)
                        local role = classify(e, p)
                        enemies[#enemies + 1] = e
                        erole[e] = role
                        if role == "shooter" or role == "artillery" then enemies_ranged[#enemies_ranged + 1] = e end
                        if role == "monster" then enemies_monster[#enemies_monster + 1] = e end
                        if role == "flyer" or role == "artillery" then enemies_airarty[#enemies_airarty + 1] = e end
                    elseif e and visible then
                        local ok_sh, sh = pcall(function() return e:is_shattered() end)
                        if not (ok_sh and sh) then
                            enemies_routing[#enemies_routing + 1] = e
                        end
                    end
                end
            end
        end
    end

    local doctrine = select_doctrine(delegated, shooters, n_mobile)
    if doctrine ~= last_doctrine then
        out_log("doctrine -> " .. doctrine .. " (delegated=" .. #delegated
            .. " shooters=" .. #shooters .. " mobile=" .. n_mobile .. ")")
        last_doctrine = doctrine
    end
    issue_planner_directive(now_ms, doctrine, delegated, enemies)

    -- heartbeat every ~60s: lets us tell "no threats in range" from "handler
    -- never ran" when reading logs after a battle
    if #enemies > 0 then saw_enemies = true end

    tick_n = tick_n + 1
    if tick_n % 20 == 0 then
        local n_idle, n_planned = 0, -1
        local hp_a, hp_e, n_ally_alive = 0, 0, 0
        for _, d in ipairs(delegated) do
            -- "standing with a stale order" counts as idle — is_idle() alone
            -- misses units frozen on a completed hold/defend order
            if effectively_idle(d, d.unit, nil) then n_idle = n_idle + 1 end
        end
        -- army hp accounting for post-battle review + win/loss detection
        for_each_player_unit(function(u)
            local ok_r, rt = pcall(function() return u:is_routing() end)
            if not (ok_r and rt) then n_ally_alive = n_ally_alive + 1 end
            local ok, h = pcall(function() return u:unary_hitpoints() end)
            if ok and is_number(h) then hp_a = hp_a + h end
        end)
        for _, e in ipairs(enemies) do
            local ok, h = pcall(function() return e:unary_hitpoints() end)
            if ok and is_number(h) then hp_e = hp_e + h end
        end
        if planner then
            local ok_c, c = pcall(function() return planner:count() end)
            if ok_c then n_planned = c end
        end
        out_log("tick-stats doctrine=" .. doctrine .. " del=" .. #delegated
            .. " planner=" .. n_planned .. " idle=" .. n_idle
            .. " enemies=" .. #enemies .. " routing=" .. #enemies_routing
            .. " hp=" .. math.floor(hp_a) .. "/" .. math.floor(hp_e))
        -- battle outcome (once): all enemies dead-or-routing = win,
        -- all our units routing = loss
        if saw_enemies and not outcome_logged then
            if #enemies == 0 then
                outcome_logged = true
                out_log("outcome WIN — enemy army routed or destroyed, hp ally/enemy="
                    .. math.floor(hp_a) .. "/" .. math.floor(hp_e))
            elseif n_ally_alive == 0 then
                outcome_logged = true
                out_log("outcome LOSS — player army routed")
            end
        end
    end

    -- pass 2: abilities + role behaviour
    local ctx = {
        now_ms = now_ms, doctrine = doctrine, shooters = shooters,
        enemies = enemies, enemies_ranged = enemies_ranged,
        enemies_monster = enemies_monster, enemies_airarty = enemies_airarty,
        enemies_routing = enemies_routing,
        erole = erole,
    }
    for _, d in ipairs(delegated) do
        local su, unit = d.su, d.unit
        local uid = tostring(unit:unique_ui_id())
        -- summoned units can despawn while an ability effect is still resolving;
        -- both observed freezes happened on psw_summon_* flyers, so their
        -- abilities stay manual (orders/tasks are unaffected)
        local is_summon = unit:type():find("summon") ~= nil
        local abilities = CONFIG.auto_cast
            and (not is_summon or CONFIG.cast_on_summons)
            and unit:owned_non_passive_special_abilities() or nil
        if is_summon and not summon_probe[unit:type()] then
            summon_probe[unit:type()] = true
            out_log("summon-skip " .. unit:type() .. " (" .. uid .. ")")
        end
        if abilities then
            for k, v in pairs(abilities) do
                local key = is_string(v) and v or (is_string(k) and k or nil)
                if key and ability_allowed(unit, key) then
                    local ok, err = pcall(try_cast, su, unit, key, now_ms)
                    if not ok then
                        -- any perform failure is permanent for this combo:
                        -- can_perform lies for some abilities, and retrying a
                        -- cast that can never succeed just spams errors
                        unsupported[uid .. "|" .. key] = true
                        out_log("cast-fail " .. key .. " on " .. uid .. ": " .. tostring(err))
                    end
                end
            end
        end
        local task = assign_task(d, ctx)
        if unit_task[uid] ~= task then
            out_log("task " .. unit:type() .. " (" .. uid .. ") role=" .. d.role .. " -> " .. task)
            unit_task[uid] = task
        end
        -- quiet window: never issue an order while a cast is still resolving;
        -- a same-tick cast+order pair raced a bomb maneuver into a sim deadlock
        if cast_at[uid] and (now_ms - cast_at[uid]) < CONFIG.cast_quiet_ms then
            -- cast still resolving; hold the task order this tick
        else
            in_task_pass = true
            -- tactical micro overrides the doctrine task when it triggers:
            -- wounded pull-out > shooter kiting > cav cycle-charge > task
            local ok_h, handled = pcall(function()
                return wounded_step(d, ctx) or kite_step(d, ctx) or cycle_charge_step(d, ctx)
            end)
            if not (ok_h and handled) then
                local exec = TASK_EXEC[task] or TASK_EXEC.attack
                pcall(exec, d, ctx)
            end
            in_task_pass = false
        end
    end

    sim_step(now_ms)
end

---------------------------------------------------------------------------------------------
-- listeners: hotkey handoff + engine command events (reclaim probe + dodge)
---------------------------------------------------------------------------------------------

-- hotkey handoff: select unit cards, press the bound shortcut (camera bookmark
-- saves by default — rebindable under Settings > Camera)
add_handoff_listener("czx_handoff_toggle", CONFIG.hotkey_toggle,
    function() handoff_toggle() end)
add_handoff_listener("czx_handoff_override", CONFIG.hotkey_override,
    function() handoff_override(bm:time_elapsed_ms()) end)

-- UI order commands on delegated units = the player took over. Events arriving
-- while in_task_pass is true are our own uc orders and get filtered out.
for _, name in ipairs({
    "Attack Unit", "Move Orientation Width", "Move Rotation Angle",
    "Change Speed", "Change Melee", "Change Skirmish", "Fire At Will",
}) do
    add_order_listener(name)
end

-- enemy ability casts: the Special Ability command context exposes the caster
-- (get_unit) and hopefully the target point (get_position) -> scatter our units
-- standing in the blast. Probe logging verifies the schema in live games.
pcall(function()
    bm:register_command_handler_callback("Special Ability", function(ctx)
        cmd_probe_log(ctx, "Special Ability")
        if not CONFIG.dodge or in_task_pass then return end
        local ok_u, caster = pcall(function() return ctx:get_unit() end)
        local ok_p, pos = pcall(function() return ctx:get_position() end)
        if not (ok_u and caster and ok_p and pos) then return end
        local ok_a, al = pcall(function() return caster:alliance_index() end)
        if not (ok_a and al and al ~= bm:local_alliance()) then return end
        local now_ms = bm:time_elapsed_ms()
        local n_scatter = 0
        for_each_player_unit(function(unit)
            local uid = tostring(unit:unique_ui_id())
            if managed[uid] and not reclaimed[uid] and not overridden[uid]
                and not unit:is_routing()
                and (now_ms - (dodge_at[uid] or 0)) > CONFIG.dodge_cooldown_ms then
                local ok_d, dist = pcall(function() return unit:position():distance_xz(pos) end)
                if ok_d and dist and dist <= CONFIG.dodge_radius_m then
                    local su = bm:get_scriptunit_for_unit(unit)
                    if su and su.uc then
                        dodge_at[uid] = now_ms
                        order_flee_pos(su, unit, pos, CONFIG.dodge_dest_m, now_ms, "dodge")
                        n_scatter = n_scatter + 1
                    end
                end
            end
        end)
        if n_scatter > 0 then
            local ok_k, key = pcall(function() return ctx:get_string1() end)
            out_log("dodge n=" .. n_scatter .. " <- " .. tostring(ok_k and key))
        end
    end, "czx_cmd_special")
end)

-- pcall 兜底：tick 内任何报错只记日志——裸错会中断 timer_manager 泵的
-- singleshot 重武装，把全场所有脚本的计时器一起打死（czx_tc 实测教训）
bm:repeat_callback(function()
    local ok, err = pcall(tick)
    if not ok then out_log("ERROR tick " .. tostring(err)) end
end, CONFIG.poll_ms, "czx_auto_ability_tick")
out_log("loaded, poll " .. CONFIG.poll_ms .. "ms, auto_cast=" .. tostring(CONFIG.auto_cast)
    .. " auto_delegate=" .. tostring(CONFIG.auto_delegate)
    .. " hotkey=" .. tostring(CONFIG.hotkey_toggle) .. "/" .. tostring(CONFIG.hotkey_override))
