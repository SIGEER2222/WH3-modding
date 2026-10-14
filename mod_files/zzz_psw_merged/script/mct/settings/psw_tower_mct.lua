-- 魔女高塔 · MCT 配置项（groovy_mct 缺席时本文件不被加载，
-- 运行时读取亦走 psw_tower.lua 的 mct_num/mct_bool 软依赖回退默认值）
if not get_mct then return end
local mct = get_mct()
local p = "mct_psw_twr_"
local mod = mct:register_mod("psw_tower")
mod:set_title(p .. "mod_title", true)
mod:set_author("wyccc")
mod:set_description(p .. "mod_desc", true)

mod:add_new_section("economy", p .. "sec_economy", true)

local sd_mult = mod:add_new_option("sd_mult", "slider")
sd_mult:set_text(p .. "sd_mult_txt", true)
sd_mult:set_tooltip_text(p .. "sd_mult_tt", true)
sd_mult:slider_set_precision(2)
sd_mult:slider_set_step_size(0.05, 2)
sd_mult:slider_set_min_max(0, 3)
sd_mult:set_default_value(1)

local shop_mult = mod:add_new_option("shop_price_mult", "slider")
shop_mult:set_text(p .. "shop_price_mult_txt", true)
shop_mult:set_tooltip_text(p .. "shop_price_mult_tt", true)
shop_mult:slider_set_precision(2)
shop_mult:slider_set_step_size(0.05, 2)
shop_mult:slider_set_min_max(0.2, 3)
shop_mult:set_default_value(1)

local vic_mult = mod:add_new_option("victory_mult", "slider")
vic_mult:set_text(p .. "victory_mult_txt", true)
vic_mult:set_tooltip_text(p .. "victory_mult_tt", true)
vic_mult:slider_set_precision(2)
vic_mult:slider_set_step_size(0.05, 2)
vic_mult:slider_set_min_max(0, 3)
vic_mult:set_default_value(1)

local rchance = mod:add_new_option("reward_chance", "slider")
rchance:set_text(p .. "reward_chance_txt", true)
rchance:set_tooltip_text(p .. "reward_chance_tt", true)
rchance:slider_set_min_max(0, 100)
rchance:set_default_value(100)

local lchance = mod:add_new_option("link_chance", "slider")
lchance:set_text(p .. "link_chance_txt", true)
lchance:set_tooltip_text(p .. "link_chance_tt", true)
lchance:slider_set_min_max(0, 100)
lchance:set_default_value(100)

local sch_gmsj = mod:add_new_option("school_gmsj", "slider")
sch_gmsj:set_text(p .. "school_gmsj_txt", true)
sch_gmsj:set_tooltip_text(p .. "school_gmsj_tt", true)
sch_gmsj:slider_set_min_max(0, 20)
sch_gmsj:set_default_value(5)

mod:add_new_section("paths", p .. "sec_paths", true)

local function path_w(key, d)
    local o = mod:add_new_option(key, "slider")
    o:set_text(p .. key .. "_txt", true)
    o:set_tooltip_text(p .. key .. "_tt", true)
    o:slider_set_min_max(0, 80)
    o:set_default_value(d)
end
path_w("w_event", 32)
path_w("w_rest", 26)
path_w("w_elite", 18)
path_w("w_shop", 14)

mod:add_new_section("enemies", p .. "sec_enemies", true)

local eb_mult = mod:add_new_option("enemy_budget_mult", "slider")
eb_mult:set_text(p .. "enemy_budget_mult_txt", true)
eb_mult:set_tooltip_text(p .. "enemy_budget_mult_tt", true)
eb_mult:slider_set_precision(2)
eb_mult:slider_set_step_size(0.05, 2)
eb_mult:slider_set_min_max(0.5, 3)
eb_mult:set_default_value(1)

local ror = mod:add_new_option("ror_cap", "slider")
ror:set_text(p .. "ror_cap_txt", true)
ror:set_tooltip_text(p .. "ror_cap_tt", true)
ror:slider_set_min_max(0, 5)
ror:set_default_value(1)

local sig = mod:add_new_option("sig_comp", "checkbox")
sig:set_text(p .. "sig_comp_txt", true)
sig:set_tooltip_text(p .. "sig_comp_tt", true)
sig:set_default_value(true)

local mut = mod:add_new_option("mutator", "checkbox")
mut:set_text(p .. "mutator_txt", true)
mut:set_tooltip_text(p .. "mutator_tt", true)
mut:set_default_value(true)

mod:add_new_section("rival", p .. "sec_rival", true)

local riv_on = mod:add_new_option("rival_enable", "checkbox")
riv_on:set_text(p .. "rival_enable_txt", true)
riv_on:set_tooltip_text(p .. "rival_enable_tt", true)
riv_on:set_default_value(true)

local riv_pace = mod:add_new_option("rival_pace", "slider")
riv_pace:set_text(p .. "rival_pace_txt", true)
riv_pace:set_tooltip_text(p .. "rival_pace_tt", true)
riv_pace:slider_set_precision(2)
riv_pace:slider_set_step_size(0.1, 2)
riv_pace:slider_set_min_max(0, 3)
riv_pace:set_default_value(1)

local riv_reinf = mod:add_new_option("rival_reinf", "slider")
riv_reinf:set_text(p .. "rival_reinf_txt", true)
riv_reinf:set_tooltip_text(p .. "rival_reinf_tt", true)
riv_reinf:slider_set_precision(2)
riv_reinf:slider_set_step_size(0.05, 2)
riv_reinf:slider_set_min_max(0, 1)
riv_reinf:set_default_value(0.45)

local riv_chase = mod:add_new_option("rival_chase", "slider")
riv_chase:set_text(p .. "rival_chase_txt", true)
riv_chase:set_tooltip_text(p .. "rival_chase_tt", true)
riv_chase:slider_set_precision(0)
riv_chase:slider_set_step_size(5, 1)
riv_chase:slider_set_min_max(0, 100)
riv_chase:set_default_value(30)

mod:add_new_section("rules", p .. "sec_rules", true)

local acap = mod:add_new_option("army_cap", "slider")
acap:set_text(p .. "army_cap_txt", true)
acap:set_tooltip_text(p .. "army_cap_tt", true)
acap:slider_set_min_max(20, 40)
acap:set_default_value(30)

local cd = mod:add_new_option("run_cd", "slider")
cd:set_text(p .. "run_cd_txt", true)
cd:set_tooltip_text(p .. "run_cd_tt", true)
cd:slider_set_min_max(0, 10)
cd:set_default_value(3)
