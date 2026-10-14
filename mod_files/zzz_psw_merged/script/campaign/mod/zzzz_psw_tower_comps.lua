-- 签名编队（ENEMY_COMPS.md 移植）：精英/Boss/伏击战时的派系招牌 doomstack。
-- 数据来源：社区公认 doomstack（LotW/1d6chan/GT26）按"AI 驾驶仍难打"改写——
-- 单体巨兽堆/精锐混编/铁砧重炮优先，回避依赖玩家微操的阵（纯远程、法爷阵）。
-- 全部 unit key 已对 gamedata/db/main_units_tables 2675 键逐个验证（含 DLC29）。
-- 用法：kind∈{elite,boss,ambush} 且主题有签名编队时整队替换信条构建；
-- 列表按"招牌优先"排序，army_cap 截断时先砍尾部填充位。
psw_tower_comps = {}

-- 每主题 1 套签名编队；kinds 默认 {elite,boss,ambush}
local C = {
    -- F2 中级精锐：圣杯+鹰鹫混编的全骑冲锋教
    brt = { units = {
        "wh_main_brt_cav_grail_knights","wh_main_brt_cav_grail_knights",
        "wh_dlc07_brt_cav_grail_guardians_0","wh_dlc07_brt_cav_questing_knights_0",
        "wh_dlc07_brt_cav_questing_knights_0","wh_dlc07_brt_cav_knights_errant_0",
        "wh_dlc07_brt_cav_knights_errant_0","wh_dlc07_brt_cav_royal_pegasus_knights_0",
        "wh_main_brt_cav_pegasus_knights","wh_main_brt_cav_mounted_yeomen_0",
        "wh_main_brt_cav_mounted_yeomen_0","wh_dlc07_brt_inf_battle_pilgrims_0",
        "wh_dlc07_brt_inf_battle_pilgrims_0","wh_dlc07_brt_inf_grail_reliquae_0",
        "wh_main_brt_inf_men_at_arms","wh_main_brt_inf_men_at_arms",
        "wh_main_brt_inf_peasant_bowmen","wh_main_brt_inf_peasant_bowmen",
        "wh_dlc07_brt_art_blessed_field_trebuchet_0" } },
    -- 古墓构装阵：乌沙比特+死灵斯芬克斯体系
    tmb = { units = {
        "wh2_dlc09_tmb_inf_tomb_guard_0","wh2_dlc09_tmb_inf_tomb_guard_0",
        "wh2_dlc09_tmb_inf_nehekhara_warriors_0","wh2_dlc09_tmb_inf_nehekhara_warriors_0",
        "wh2_dlc09_tmb_inf_skeleton_archers_0","wh2_dlc09_tmb_inf_skeleton_archers_0",
        "wh2_dlc09_tmb_mon_ushabti_0","wh2_dlc09_tmb_mon_ushabti_0",
        "wh2_dlc09_tmb_mon_ushabti_1","wh2_dlc09_tmb_mon_ushabti_1",
        "wh2_dlc09_tmb_mon_sepulchral_stalkers_0","wh2_dlc09_tmb_mon_sepulchral_stalkers_0",
        "wh2_dlc09_tmb_cav_necropolis_knights_0","wh2_dlc09_tmb_cav_necropolis_knights_0",
        "wh2_dlc09_tmb_veh_skeleton_archer_chariot_0","wh2_dlc09_tmb_veh_skeleton_chariot_0",
        "wh2_dlc09_tmb_art_screaming_skull_catapult_0","wh2_pro06_tmb_mon_bone_giant_0",
        "wh2_dlc09_tmb_cha_tomb_prince_0" } },
    -- 绿皮 WAAAGH：黑兽人+石巨魔+阿拉克纳洛克
    grn = { units = {
        "wh_main_grn_inf_black_orcs","wh_main_grn_inf_black_orcs",
        "wh_main_grn_inf_black_orcs","wh_main_grn_inf_savage_orc_big_uns",
        "wh_main_grn_inf_savage_orc_big_uns","wh_main_grn_inf_savage_orc_big_uns",
        "wh_main_grn_inf_savage_orc_arrer_boyz","wh_main_grn_inf_savage_orc_arrer_boyz",
        "wh_main_grn_cav_savage_orc_boar_boy_big_uns","wh_main_grn_cav_savage_orc_boar_boy_big_uns",
        "wh_main_grn_cav_savage_orc_boar_boyz","wh_main_grn_mon_trolls",
        "wh_main_grn_mon_trolls","wh2_dlc15_grn_mon_stone_trolls_0",
        "wh_main_grn_mon_arachnarok_spider_0","wh_main_grn_mon_giant",
        "wh_main_grn_art_doom_diver_catapult","wh_main_grn_art_goblin_rock_lobber",
        "wh_main_grn_inf_savage_orcs" } },
    -- 野兽人兽群：牛魔+獠牙兽+战车
    bst = { units = {
        "wh_dlc03_bst_inf_minotaurs_0","wh_dlc03_bst_inf_minotaurs_0",
        "wh_dlc03_bst_inf_gor_herd_0","wh_dlc03_bst_inf_gor_herd_0",
        "wh_dlc03_bst_inf_gor_herd_1","wh_dlc03_bst_inf_gor_herd_1",
        "wh_dlc03_bst_inf_ungor_spearmen_0","wh_dlc03_bst_inf_ungor_spearmen_0",
        "wh_dlc03_bst_inf_ungor_raiders_0","wh_dlc03_bst_inf_ungor_raiders_0",
        "wh_dlc03_bst_inf_chaos_warhounds_0","wh_dlc03_bst_inf_chaos_warhounds_0",
        "wh_dlc03_bst_inf_chaos_warhounds_1","wh_dlc03_bst_inf_chaos_warhounds_1",
        "wh_dlc03_bst_inf_razorgor_herd_0","wh_dlc03_bst_inf_razorgor_herd_0",
        "wh2_dlc17_bst_cav_tuskgor_chariot_0","wh2_dlc17_bst_cav_tuskgor_chariot_0",
        "wh_dlc03_bst_mon_giant_0" } },
    -- 诺斯卡猛犸群（LotW 社区榜 #2）：战猛犸单体海
    nor = { units = {
        "wh_dlc08_nor_mon_war_mammoth_0","wh_dlc08_nor_mon_war_mammoth_0",
        "wh_dlc08_nor_mon_war_mammoth_0","wh_dlc08_nor_mon_war_mammoth_0",
        "wh_dlc08_nor_mon_war_mammoth_0","wh_dlc08_nor_mon_war_mammoth_0",
        "wh_dlc08_nor_mon_war_mammoth_1","wh_dlc08_nor_mon_war_mammoth_1",
        "wh_dlc08_nor_mon_war_mammoth_1","wh_dlc08_nor_mon_war_mammoth_1",
        "wh_dlc08_nor_mon_fimir_0","wh_dlc08_nor_mon_fimir_1",
        "wh_dlc08_nor_mon_skinwolves_0","wh_dlc08_nor_mon_skinwolves_1",
        "wh_dlc08_nor_inf_marauder_champions_0","wh_dlc08_nor_inf_marauder_champions_0",
        "wh_dlc08_nor_inf_marauder_champions_1","wh_dlc08_nor_inf_marauder_champions_1",
        "wh_dlc08_nor_mon_norscan_ice_trolls_0" } },
    -- 矮人重炮阵地：铁眉式铁龙+风琴+火焰炮铁砧阵（火力考试）
    dwf = { units = {
        "wh_main_dwf_inf_ironbreakers","wh_main_dwf_inf_ironbreakers",
        "wh_main_dwf_inf_ironbreakers","wh_main_dwf_inf_hammerers",
        "wh_main_dwf_inf_hammerers","wh_main_dwf_inf_longbeards_1",
        "wh_main_dwf_inf_quarrellers_1","wh_main_dwf_inf_quarrellers_1",
        "wh_main_dwf_inf_thunderers_0","wh_main_dwf_inf_thunderers_0",
        "wh_main_dwf_inf_irondrakes_0","wh_main_dwf_inf_irondrakes_0",
        "wh_main_dwf_art_organ_gun","wh_main_dwf_art_organ_gun",
        "wh_main_dwf_art_flame_cannon","wh_main_dwf_art_flame_cannon",
        "wh_main_dwf_art_grudge_thrower","wh_main_dwf_art_grudge_thrower",
        "wh_main_dwf_cha_master_engineer_0" } },
    -- 鼠人武器队（配氏族鼠肉垫修正版）：Jezzail/鼠特林/毒气迫击炮
    skv = { units = {
        "wh2_dlc12_skv_inf_ratling_gun_0","wh2_dlc12_skv_inf_ratling_gun_0",
        "wh2_dlc12_skv_inf_ratling_gun_0","wh2_dlc12_skv_inf_ratling_gun_0",
        "wh2_dlc12_skv_inf_warplock_jezzails_0","wh2_dlc12_skv_inf_warplock_jezzails_0",
        "wh2_dlc14_skv_inf_poison_wind_mortar_0","wh2_dlc14_skv_inf_poison_wind_mortar_0",
        "wh2_main_skv_inf_warpfire_thrower","wh2_main_skv_inf_warpfire_thrower",
        "wh2_main_skv_inf_clanrats_0","wh2_main_skv_inf_clanrats_0",
        "wh2_main_skv_inf_clanrat_spearmen_0","wh2_main_skv_inf_clanrat_spearmen_0",
        "wh2_main_skv_inf_stormvermin_1","wh2_main_skv_inf_stormvermin_1",
        "wh2_main_skv_art_plagueclaw_catapult","wh2_main_skv_art_warp_lightning_cannon",
        "wh2_dlc12_skv_veh_doomwheel_ror_0" } },
    -- 蒸克炮团：Necrofex 雏形（重火力+深卫线）
    cst = { units = {
        "wh2_dlc11_cst_mon_necrofex_colossus_0","wh2_dlc11_cst_inf_depth_guard_0",
        "wh2_dlc11_cst_inf_depth_guard_0","wh2_dlc11_cst_inf_zombie_deckhands_mob_0",
        "wh2_dlc11_cst_inf_zombie_deckhands_mob_0","wh2_dlc11_cst_inf_zombie_deckhands_mob_1",
        "wh2_dlc11_cst_inf_zombie_deckhands_mob_1","wh2_dlc11_cst_inf_zombie_gunnery_mob_0",
        "wh2_dlc11_cst_inf_zombie_gunnery_mob_1","wh2_dlc11_cst_inf_zombie_gunnery_mob_2",
        "wh2_dlc11_cst_inf_deck_gunners_0","wh2_dlc11_cst_inf_deck_gunners_0",
        "wh2_dlc11_cst_mon_rotting_prometheans_0","wh2_dlc11_cst_mon_rotting_prometheans_gunnery_mob_0",
        "wh2_dlc11_cst_art_mortar","wh2_dlc11_cst_art_carronade",
        "wh2_dlc11_cst_art_carronade","wh2_dlc11_cst_cav_deck_droppers_0",
        "wh2_dlc11_cst_cha_gunnery_wight_0" } },
    -- 帝国蒸汽坦克团（Steam Tank 正牌 doomstack）
    emp = { units = {
        "wh_main_emp_veh_steam_tank","wh_main_emp_veh_steam_tank",
        "wh_main_emp_veh_steam_tank","wh_main_emp_veh_steam_tank",
        "wh3_dlc25_emp_veh_steam_tank_volley_gun","wh3_dlc25_emp_veh_steam_tank_volley_gun",
        "wh3_dlc25_emp_veh_steam_tank_volley_gun","wh3_dlc25_emp_veh_marienburg_land_ship",
        "wh3_dlc25_emp_veh_marienburg_land_ship","wh_main_emp_inf_greatswords",
        "wh_main_emp_inf_greatswords","wh_main_emp_inf_halberdiers",
        "wh_main_emp_inf_halberdiers","wh_main_emp_inf_handgunners",
        "wh_main_emp_inf_handgunners","wh_main_emp_art_helblaster_volley_gun",
        "wh_main_emp_art_helstorm_rocket_battery","wh_main_emp_art_helstorm_rocket_battery",
        "wh_main_emp_cha_warrior_priest_0" } },
    -- 混矮列车炮阵（Dreadquake——全游戏最重火力阵之一）
    chd = { units = {
        "wh3_dlc23_chd_veh_dreadquake_mortar","wh3_dlc23_chd_veh_dreadquake_mortar",
        "wh3_dlc23_chd_veh_dreadquake_mortar","wh3_dlc23_chd_veh_iron_daemon",
        "wh3_dlc23_chd_veh_skullcracker","wh3_dlc23_chd_inf_infernal_ironsworn",
        "wh3_dlc23_chd_inf_infernal_ironsworn","wh3_dlc23_chd_inf_infernal_guard_great_weapons",
        "wh3_dlc23_chd_inf_infernal_guard_great_weapons","wh3_dlc23_chd_inf_chaos_dwarf_blunderbusses",
        "wh3_dlc23_chd_inf_chaos_dwarf_blunderbusses","wh3_dlc23_chd_inf_chaos_dwarf_blunderbusses",
        "wh3_dlc23_chd_inf_infernal_guard_fireglaives","wh3_dlc23_chd_inf_infernal_guard_fireglaives",
        "wh3_dlc23_chd_cav_bull_centaurs_greatweapons","wh3_dlc23_chd_cav_bull_centaurs_dual_axe",
        "wh3_dlc23_chd_mon_kdaai_destroyer","wh3_dlc23_chd_mon_kdaai_fireborn",
        "wh3_dlc23_chd_mon_kdaai_fireborn" } },
    -- 蜥蜴人巨兽群（LotW #3 远古甲龙堆——单体海不看操作）
    lzd = { units = {
        "wh2_dlc13_lzd_mon_dread_saurian_0","wh2_dlc12_lzd_mon_ancient_stegadon_1",
        "wh2_dlc12_lzd_mon_ancient_stegadon_1","wh2_main_lzd_mon_ancient_stegadon",
        "wh2_main_lzd_mon_bastiladon_2","wh2_main_lzd_mon_bastiladon_2",
        "wh2_main_lzd_mon_carnosaur_0","wh2_main_lzd_mon_carnosaur_0",
        "wh2_main_lzd_mon_kroxigors","wh2_main_lzd_mon_kroxigors",
        "wh2_dlc13_lzd_mon_sacred_kroxigors_0","wh2_dlc13_lzd_mon_sacred_kroxigors_0",
        "wh2_main_lzd_inf_temple_guards","wh2_main_lzd_inf_temple_guards",
        "wh2_main_lzd_inf_saurus_warriors_1","wh2_main_lzd_inf_saurus_warriors_1",
        "wh2_main_lzd_inf_saurus_spearmen_1","wh2_main_lzd_inf_saurus_spearmen_1",
        "wh2_dlc13_lzd_cha_slann_mage_priest_life_0" } },
    -- 高精龙庭（Sisters of Avelorn 堆+龙凤双翼）
    hef = { units = {
        "wh2_dlc10_hef_inf_sisters_of_avelorn_0","wh2_dlc10_hef_inf_sisters_of_avelorn_0",
        "wh2_dlc10_hef_inf_sisters_of_avelorn_0","wh2_dlc10_hef_inf_sisters_of_avelorn_0",
        "wh2_dlc10_hef_inf_sisters_of_avelorn_0","wh2_main_hef_inf_phoenix_guard",
        "wh2_main_hef_inf_phoenix_guard","wh2_main_hef_inf_phoenix_guard",
        "wh2_main_hef_inf_phoenix_guard","wh2_main_hef_inf_phoenix_guard",
        "wh2_main_hef_inf_white_lions_of_chrace_0","wh2_main_hef_inf_white_lions_of_chrace_0",
        "wh2_main_hef_cav_dragon_princes","wh2_main_hef_cav_dragon_princes",
        "wh2_main_hef_cav_silver_helms_0","wh2_main_hef_mon_star_dragon",
        "wh2_main_hef_mon_star_dragon","wh2_main_hef_mon_phoenix_frostheart",
        "wh2_main_hef_mon_phoenix_flamespyre" } },
    -- 暗精屠戮团（War Hydra 堆）
    def = { units = {
        "wh2_main_def_inf_black_guard_0","wh2_main_def_inf_black_guard_0",
        "wh2_main_def_inf_black_guard_0","wh2_main_def_inf_black_guard_0",
        "wh2_main_def_inf_black_guard_0","wh2_main_def_inf_har_ganeth_executioners_0",
        "wh2_main_def_inf_har_ganeth_executioners_0","wh2_main_def_inf_witch_elves_0",
        "wh2_main_def_inf_witch_elves_0","wh2_main_def_inf_shades_2",
        "wh2_main_def_inf_shades_2","wh2_main_def_inf_darkshards_1",
        "wh2_main_def_inf_darkshards_1","wh2_main_def_cav_cold_one_knights_0",
        "wh2_main_def_cav_cold_one_knights_0","wh2_main_def_cav_dark_riders_2",
        "wh2_main_def_mon_war_hydra","wh2_main_def_mon_war_hydra",
        "wh2_dlc10_def_mon_kharibdyss_0" } },
    -- 木精伏击阵（Waywatcher 堆——伏击战专用签名）
    wef = { units = {
        "wh_dlc05_wef_inf_waywatchers_0","wh_dlc05_wef_inf_waywatchers_0",
        "wh_dlc05_wef_inf_waywatchers_0","wh_dlc05_wef_inf_waywatchers_0",
        "wh_dlc05_wef_inf_waywatchers_0","wh_dlc05_wef_inf_waywatchers_0",
        "wh_dlc05_wef_inf_deepwood_scouts_0","wh_dlc05_wef_inf_deepwood_scouts_0",
        "wh_dlc05_wef_inf_wardancers_1","wh_dlc05_wef_inf_wardancers_1",
        "wh_dlc05_wef_inf_wardancers_1","wh_dlc05_wef_inf_wardancers_1",
        "wh_dlc05_wef_inf_wildwood_rangers_0","wh_dlc05_wef_inf_wildwood_rangers_0",
        "wh_dlc05_wef_inf_eternal_guard_1","wh_dlc05_wef_cav_wild_riders_0",
        "wh_dlc05_wef_cav_wild_riders_0","wh2_dlc16_wef_cav_great_stag_knights_0",
        "wh_dlc05_wef_mon_treeman_0" } },
    -- 基斯里夫熊团（War Bear Riders 堆，Boris 式）
    ksl = { units = {
        "wh3_main_ksl_cav_war_bear_riders_1","wh3_main_ksl_cav_war_bear_riders_1",
        "wh3_main_ksl_cav_war_bear_riders_1","wh3_main_ksl_cav_war_bear_riders_1",
        "wh3_main_ksl_cav_war_bear_riders_1","wh3_main_ksl_cav_war_bear_riders_1",
        "wh3_main_ksl_mon_elemental_bear_0","wh3_main_ksl_mon_elemental_bear_0",
        "wh3_main_ksl_mon_elemental_bear_0","wh3_main_ksl_inf_tzar_guard_0",
        "wh3_main_ksl_inf_tzar_guard_0","wh3_main_ksl_inf_tzar_guard_0",
        "wh3_main_ksl_inf_tzar_guard_0","wh3_main_ksl_inf_ice_guard_1",
        "wh3_main_ksl_inf_ice_guard_1","wh3_main_ksl_inf_ice_guard_1",
        "wh3_main_ksl_inf_ice_guard_1","wh3_main_ksl_inf_ice_guard_1",
        "wh3_main_ksl_veh_little_grom_0" } },
    -- 震旦天廷军（陶俑+天舟堆）
    cth = { units = {
        "wh3_main_cth_mon_terracotta_sentinel_0","wh3_main_cth_mon_terracotta_sentinel_0",
        "wh3_main_cth_mon_terracotta_sentinel_0","wh3_dlc24_cth_mon_jade_lion",
        "wh3_dlc24_cth_mon_jet_lion","wh3_dlc24_cth_mon_great_moon_bird",
        "wh3_main_cth_inf_dragon_guard_0","wh3_main_cth_inf_dragon_guard_0",
        "wh3_main_cth_inf_dragon_guard_0","wh3_main_cth_inf_dragon_guard_0",
        "wh3_main_cth_inf_dragon_guard_crossbowmen_0","wh3_main_cth_inf_dragon_guard_crossbowmen_0",
        "wh3_main_cth_inf_jade_warrior_crossbowmen_1","wh3_main_cth_inf_jade_warrior_crossbowmen_1",
        "wh3_main_cth_inf_crane_gunners_0","wh3_main_cth_inf_crane_gunners_0",
        "wh3_main_cth_inf_jade_warriors_1","wh3_main_cth_cav_jade_longma_riders_0",
        "wh3_main_cth_veh_sky_junk_0" } },
    -- 食人魔碾压团（石角兽/铅嘴/铁炮堆）
    ogr = { units = {
        "wh3_main_ogr_mon_stonehorn_1","wh3_main_ogr_mon_stonehorn_1",
        "wh3_dlc26_ogr_mon_thundertusk","wh3_main_ogr_veh_ironblaster_0",
        "wh3_main_ogr_inf_ironguts_0","wh3_main_ogr_inf_ironguts_0",
        "wh3_main_ogr_inf_ironguts_0","wh3_main_ogr_inf_ironguts_0",
        "wh3_main_ogr_inf_maneaters_3","wh3_main_ogr_inf_maneaters_3",
        "wh3_main_ogr_inf_maneaters_3","wh3_main_ogr_inf_maneaters_3",
        "wh3_main_ogr_cav_crushers_1","wh3_main_ogr_cav_crushers_1",
        "wh3_main_ogr_cav_crushers_1","wh3_main_ogr_cav_crushers_1",
        "wh3_main_ogr_inf_leadbelchers_0","wh3_main_ogr_inf_leadbelchers_0",
        "wh3_main_ogr_mon_gorgers_0" } },
    -- 吸系亡者潮（9.0 吸系大改口径：墓穴卫+血骑士+恶鬼）
    vmp = { units = {
        "wh_main_vmp_inf_grave_guard_1","wh_main_vmp_inf_grave_guard_1",
        "wh_main_vmp_inf_grave_guard_1","wh_main_vmp_inf_grave_guard_1",
        "wh_main_vmp_mon_crypt_horrors","wh_main_vmp_mon_crypt_horrors",
        "wh_main_vmp_mon_crypt_horrors","wh_main_vmp_mon_crypt_horrors",
        "wh_dlc02_vmp_cav_blood_knights_0","wh_dlc02_vmp_cav_blood_knights_0",
        "wh_dlc02_vmp_cav_blood_knights_0","wh3_main_vmp_blood_knights_sword_shield",
        "wh_main_vmp_mon_vargheists","wh_main_vmp_mon_vargheists",
        "wh_main_vmp_mon_varghulf","wh_main_vmp_mon_terrorgheist",
        "wh_main_vmp_mon_terrorgheist","wh_dlc04_vmp_veh_corpse_cart_0",
        "wh_main_vmp_inf_cairn_wraiths" } },
    -- 纳迦什不死军团（DLC29 亡者王座——灵体肉垫+摩竭+泰坦）
    nag = { units = {
        "wh3_dlc29_tmb_mon_khemric_titan","wh3_dlc29_vmp_mon_morghast_archai",
        "wh3_dlc29_vmp_mon_morghast_archai","wh3_dlc29_vmp_mon_morghast_harbingers",
        "wh3_dlc29_vmp_mon_morghast_harbingers","wh3_dlc29_vmp_cav_drakenhof_templars",
        "wh3_dlc29_vmp_cav_drakenhof_templars","wh3_dlc29_vmp_inf_spirit_host",
        "wh3_dlc29_vmp_inf_spirit_host","wh3_dlc29_vmp_inf_spirit_host",
        "wh2_dlc09_tmb_inf_tomb_guard_0","wh2_dlc09_tmb_inf_tomb_guard_0",
        "wh_main_vmp_inf_grave_guard_0","wh_main_vmp_inf_grave_guard_0",
        "wh_main_vmp_inf_grave_guard_0","wh_main_vmp_inf_skeleton_warriors_0",
        "wh_main_vmp_inf_skeleton_warriors_0","wh_main_vmp_inf_skeleton_warriors_0",
        "wh2_dlc09_tmb_mon_ushabti_1" } },
    -- 恐虐绞肉机
    kho = { units = {
        "wh3_dlc26_kho_inf_skullreapers","wh3_dlc26_kho_inf_skullreapers",
        "wh3_dlc26_kho_inf_wrathmongers","wh3_dlc26_kho_inf_wrathmongers",
        "wh3_main_kho_inf_bloodletters_0","wh3_main_kho_inf_bloodletters_0",
        "wh3_main_kho_inf_bloodletters_1","wh3_main_kho_cav_skullcrushers_0",
        "wh3_main_kho_cav_skullcrushers_0","wh3_main_kho_cav_bloodcrushers_0",
        "wh3_main_kho_inf_flesh_hounds_of_khorne_0","wh3_main_kho_inf_flesh_hounds_of_khorne_0",
        "wh3_main_kho_mon_khornataurs_0","wh3_main_kho_mon_khornataurs_1",
        "wh3_dlc26_kho_mon_slaughterbrute","wh3_dlc26_kho_mon_bloodbeast_of_khorne",
        "wh3_main_kho_mon_spawn_of_khorne_0","wh3_main_kho_mon_bloodthirster_0",
        "wh3_main_kho_veh_skullcannon_0" } },
    -- 纳垢磨尸场（大不净者+疫父食人魔+蟾蜍龙）
    nur = { units = {
        "wh3_main_nur_mon_great_unclean_one_0","wh3_main_nur_mon_great_unclean_one_0",
        "wh3_dlc25_nur_mon_toad_dragon","wh3_main_nur_inf_plaguebearers_0",
        "wh3_main_nur_inf_plaguebearers_0","wh3_main_nur_inf_plaguebearers_1",
        "wh3_main_nur_inf_plaguebearers_1","wh3_dlc29_chs_inf_putrid_blightkings_great_weapons",
        "wh3_dlc29_chs_inf_putrid_blightkings_great_weapons","wh3_dlc25_nur_inf_plague_ogres_great_weapons",
        "wh3_dlc25_nur_inf_plague_ogres","wh3_main_nur_cav_plague_drones_0",
        "wh3_main_nur_cav_plague_drones_1","wh3_main_nur_cav_pox_riders_of_nurgle_0",
        "wh3_main_nur_mon_beast_of_nurgle_0","wh3_main_nur_mon_beast_of_nurgle_0",
        "wh3_main_nur_mon_plague_toads_0","wh3_main_nur_mon_soul_grinder_0",
        "wh3_main_nur_inf_nurglings_0" } },
    -- 奸奇火力网（变化之主+高阶焰妖）
    tze = { units = {
        "wh3_main_tze_mon_lord_of_change_0","wh3_main_tze_mon_lord_of_change_0",
        "wh3_main_tze_mon_lord_of_change_0","wh3_dlc24_tze_mon_mutalith_vortex_beast",
        "wh3_main_tze_inf_pink_horrors_0","wh3_main_tze_inf_pink_horrors_0",
        "wh3_main_tze_inf_pink_horrors_1","wh3_main_tze_inf_pink_horrors_1",
        "wh3_main_tze_inf_forsaken_0","wh3_main_tze_mon_flamers_0",
        "wh3_main_tze_mon_flamers_0","wh3_main_tze_mon_exalted_flamers_0",
        "wh3_main_tze_mon_exalted_flamers_0","wh3_main_tze_veh_burning_chariot_0",
        "wh3_main_tze_veh_burning_chariot_0","wh3_main_tze_mon_soul_grinder_0",
        "wh3_main_tze_mon_soul_grinder_0","wh3_main_tze_inf_chaos_furies_0",
        "wh3_main_tze_inf_chaos_furies_0" } },
    -- 色孽极速猎群（守密者+恶魔车骑）
    sla = { units = {
        "wh3_main_sla_mon_keeper_of_secrets_0","wh3_main_sla_mon_keeper_of_secrets_0",
        "wh3_main_sla_mon_keeper_of_secrets_0","wh3_main_sla_mon_fiends_of_slaanesh_0",
        "wh3_main_sla_mon_fiends_of_slaanesh_0","wh3_main_sla_mon_fiends_of_slaanesh_0",
        "wh3_main_sla_inf_daemonette_0","wh3_main_sla_inf_daemonette_0",
        "wh3_main_sla_inf_daemonette_1","wh3_main_sla_inf_daemonette_1",
        "wh3_main_sla_inf_daemonette_1","wh3_main_sla_cav_seekers_of_slaanesh_0",
        "wh3_main_sla_cav_seekers_of_slaanesh_0","wh3_main_sla_cav_heartseekers_of_slaanesh_0",
        "wh3_main_sla_cav_heartseekers_of_slaanesh_0","wh3_main_sla_veh_exalted_seeker_chariot_0",
        "wh3_main_sla_veh_hellflayer_0","wh3_main_sla_mon_soul_grinder_0",
        "wh3_main_sla_inf_chaos_furies_0" } },
    -- 混神 Chosen 军团（Archaon 式——Boss 签名主军）
    chs = { units = {
        "wh3_dlc20_chs_inf_chosen_mkho","wh3_dlc20_chs_inf_chosen_mkho",
        "wh3_dlc20_chs_inf_chosen_mkho_dualweapons","wh3_dlc20_chs_inf_chosen_mkho_dualweapons",
        "wh3_dlc20_chs_inf_chosen_mtze","wh3_dlc20_chs_inf_chosen_mtze_halberds",
        "wh3_dlc20_chs_inf_chosen_mnur_greatweapons","wh3_dlc20_chs_inf_chosen_msla",
        "wh3_dlc20_chs_cav_chaos_knights_mkho_lances","wh3_dlc20_chs_cav_chaos_knights_mkho_lances",
        "wh3_dlc20_chs_cav_chaos_knights_mtze_lances","wh3_dlc20_chs_mon_warshrine_mkho",
        "wh3_dlc20_chs_mon_warshrine_mtze","wh_dlc01_chs_mon_dragon_ogre_shaggoth",
        "wh3_dlc29_chs_inf_putrid_blightkings_great_weapons","wh3_dlc29_chs_inf_putrid_blightkings_great_weapons",
        "wh_main_chs_art_hellcannon","wh_main_chs_art_hellcannon",
        "wh3_dlc20_chs_cha_exalted_hero_mkho_chaos_steed" } },
    -- 恶魔原体（四神大魔混编单体海——Boss 签名）
    dae = { units = {
        "wh3_main_kho_mon_bloodthirster_0","wh3_main_nur_mon_great_unclean_one_0",
        "wh3_main_tze_mon_lord_of_change_0","wh3_main_sla_mon_keeper_of_secrets_0",
        "wh3_main_kho_mon_soul_grinder_0","wh3_main_nur_mon_soul_grinder_0",
        "wh3_main_tze_mon_soul_grinder_0","wh3_main_sla_mon_soul_grinder_0",
        "wh3_main_kho_cav_bloodcrushers_0","wh3_main_kho_cav_bloodcrushers_0",
        "wh3_main_sla_mon_fiends_of_slaanesh_0","wh3_main_sla_mon_fiends_of_slaanesh_0",
        "wh3_main_nur_mon_beast_of_nurgle_0","wh3_main_nur_mon_beast_of_nurgle_0",
        "wh3_main_tze_mon_exalted_flamers_0","wh3_main_tze_mon_exalted_flamers_0",
        "wh3_main_kho_inf_flesh_hounds_of_khorne_0","wh3_main_kho_inf_flesh_hounds_of_khorne_0",
        "wh3_main_kho_mon_spawn_of_khorne_0" } },
}
psw_tower_comps.SIGNATURE_COMPS = C

-- 签名编队附加效果包（db/effect_bundles_tables/zzz_psw_tower_sig.tsv；
-- 敌军生成时 apply_effect_bundle_to_force 挂上，等价"派系加成"层）
psw_tower_comps.SIG_BUNDLES = {
    nor = "psw_twr_sig_beast", lzd = "psw_twr_sig_beast", ogr = "psw_twr_sig_beast",
    grn = "psw_twr_sig_beast", bst = "psw_twr_sig_beast", tmb = "psw_twr_sig_beast",
    nag = "psw_twr_sig_beast",
    dwf = "psw_twr_sig_gun", skv = "psw_twr_sig_gun", emp = "psw_twr_sig_gun",
    chd = "psw_twr_sig_gun", cst = "psw_twr_sig_gun", cth = "psw_twr_sig_gun",
    wef = "psw_twr_sig_gun", tze = "psw_twr_sig_gun",
    brt = "psw_twr_sig_cav", ksl = "psw_twr_sig_cav", hef = "psw_twr_sig_cav",
    sla = "psw_twr_sig_cav",
    kho = "psw_twr_sig_melee", vmp = "psw_twr_sig_melee", chs = "psw_twr_sig_melee",
    def = "psw_twr_sig_melee",
    nur = "psw_twr_sig_tank",
    dae = "psw_twr_sig_daemon",
}

-- Sub-faction 变体（ENEMY_COMPS §7.2）：同主题第二套签名，生成时掷签替换
psw_tower_comps.VARIANTS = {
    -- 鼠人·瘟疫僧海（Skyre 武器队之外的面孔）
    skv = { units = {
        "wh2_main_skv_inf_plague_monks","wh2_main_skv_inf_plague_monks",
        "wh2_main_skv_inf_plague_monks","wh2_main_skv_inf_plague_monks",
        "wh2_main_skv_inf_plague_monks","wh2_main_skv_inf_plague_monks",
        "wh2_main_skv_inf_plague_monk_censer_bearer","wh2_main_skv_inf_plague_monk_censer_bearer",
        "wh2_main_skv_inf_plague_monk_censer_bearer","wh2_main_skv_inf_plague_monk_censer_bearer",
        "wh2_dlc12_skv_inf_plague_monk_censer_bearer_ror_0","wh2_main_skv_inf_death_globe_bombardiers",
        "wh2_main_skv_inf_death_globe_bombardiers","wh2_dlc14_skv_inf_warp_grinder_0",
        "wh2_main_skv_inf_stormvermin_0","wh2_main_skv_inf_stormvermin_0",
        "wh2_main_skv_inf_clanrat_spearmen_1","wh2_main_skv_inf_clanrat_spearmen_1",
        "wh2_main_skv_inf_clanrat_spearmen_1" } },
    -- 诺斯卡·冰原狼群（猛犸群之外的面孔）
    nor = { units = {
        "wh_dlc08_nor_mon_norscan_ice_trolls_0","wh_dlc08_nor_mon_norscan_ice_trolls_0",
        "wh_dlc08_nor_mon_norscan_ice_trolls_0","wh_dlc08_nor_mon_norscan_ice_trolls_0",
        "wh_dlc08_nor_mon_skinwolves_0","wh_dlc08_nor_mon_skinwolves_0",
        "wh_dlc08_nor_mon_skinwolves_1","wh_dlc08_nor_mon_skinwolves_1",
        "wh_dlc08_nor_mon_skinwolves_0","wh_dlc08_nor_mon_skinwolves_1",
        "wh_dlc08_nor_mon_fimir_0","wh_dlc08_nor_mon_fimir_0",
        "wh_dlc08_nor_mon_fimir_1","wh_dlc08_nor_inf_marauder_champions_0",
        "wh_dlc08_nor_inf_marauder_champions_0","wh_dlc08_nor_inf_marauder_champions_1",
        "wh_dlc08_nor_inf_marauder_berserkers_0","wh_dlc08_nor_inf_marauder_berserkers_0",
        "wh_dlc08_nor_inf_marauder_spearman_0" } },
    -- 吸血鬼·幽冥骑影（幽体骑军+血骑）
    vmp = { units = {
        "wh_main_vmp_cav_hexwraiths","wh_main_vmp_cav_hexwraiths",
        "wh_main_vmp_cav_hexwraiths","wh_main_vmp_cav_hexwraiths",
        "wh_main_vmp_cav_black_knights_0","wh_main_vmp_cav_black_knights_0",
        "wh_main_vmp_cav_black_knights_3","wh_main_vmp_cav_black_knights_3",
        "wh_main_vmp_inf_cairn_wraiths","wh_main_vmp_inf_cairn_wraiths",
        "wh_main_vmp_inf_cairn_wraiths","wh_main_vmp_mon_terrorgheist",
        "wh_main_vmp_mon_terrorgheist","wh_main_vmp_inf_skeleton_warriors_0",
        "wh_main_vmp_inf_skeleton_warriors_0","wh_main_vmp_inf_skeleton_warriors_0",
        "wh_main_vmp_inf_skeleton_warriors_0","wh_dlc04_vmp_veh_corpse_cart_0",
        "wh_main_vmp_mon_vargheists" } },
    -- 巴托·天马团（全飞行骑军）
    brt = { units = {
        "wh_dlc07_brt_cav_royal_hippogryph_knights_0","wh_dlc07_brt_cav_royal_hippogryph_knights_0",
        "wh_dlc07_brt_cav_royal_pegasus_knights_0","wh_dlc07_brt_cav_royal_pegasus_knights_0",
        "wh_dlc07_brt_cav_royal_pegasus_knights_0","wh_dlc07_brt_cav_royal_pegasus_knights_0",
        "wh_main_brt_cav_pegasus_knights","wh_main_brt_cav_pegasus_knights",
        "wh_main_brt_cav_pegasus_knights","wh_main_brt_cav_pegasus_knights",
        "wh_main_brt_cav_grail_knights","wh_main_brt_cav_grail_knights",
        "wh_main_brt_cav_grail_knights","wh_dlc07_brt_cav_grail_guardians_0",
        "wh_dlc07_brt_cav_questing_knights_0","wh_dlc07_brt_inf_battle_pilgrims_0",
        "wh_dlc07_brt_inf_grail_reliquae_0","wh_dlc07_brt_inf_foot_squires_0",
        "wh_dlc07_brt_inf_foot_squires_0" } },
}
