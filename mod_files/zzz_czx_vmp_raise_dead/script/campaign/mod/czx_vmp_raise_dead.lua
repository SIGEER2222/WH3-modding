-- czx_vmp_raise_dead.lua
-- 吸血鬼派系（wh_main_sc_vmp_vampire_counts）驱役亡者池运行时注入。
-- DLC29 之后 wh3_dlc29_vmp_raise_dead_faction 池的静态 junction 行
-- 对自定义单位不生效（已实测：junction/groups 均正确合入但运行时池为空），
-- 因此按 suifu.lua 验证过的方式用 cm:add_unit_to_faction_mercenary_pool 注册。
-- 每个存档只注入一次；池内容随后由存档持久化。

local POOL_SOURCE = "wh3_dlc29_vmp_raise_dead_faction"
local VMP_SUBCULTURE = "wh_main_sc_vmp_vampire_counts"
local SAVE_FLAG = "czx_vmp_raise_dead_injected"

-- unit_key, initial_count, max_units, replenish_chance, max_per_turn
-- 基础兵少量常驻；高阶/成熟期初始 0，靠 chance 随时间补员
local CZX_VMP_POOL_UNITS = {
    { "gou",                  2, 999999, 1.0, 100.0 },
    { "czx_zhanglang",        1, 999999, 1.0, 100.0 },
    { "czx_jibian",           1, 999999, 1.0, 100.0 },
    { "czx_hd_green",         1, 999999, 1.0, 100.0 },
    { "czx_hd_white",         1, 999999, 1.0, 100.0 },
    { "czx_hd_black",         1, 999999, 1.0, 100.0 },
    { "czx_hd_dblack",        1, 999999, 1.0, 100.0 },
    { "czx_baochong",         1, 999999, 1.0, 100.0 },
    { "czx_mangshou",         1, 999999, 1.0, 100.0 },
    { "czx_baolongshou",      1, 999999, 1.0, 100.0 },
    { "cishe",                1, 999999, 1.0, 100.0 },
    { "czx_feilong",          1, 999999, 1.0, 100.0 },
    { "czx_inf_tank",         1, 999999, 1.0, 100.0 },
    { "czx_inf_marine",       1, 999999, 1.0, 100.0 },
    { "czx_inf_diamondback",  1, 999999, 1.0, 100.0 },
    { "czx_dehaka",           1, 999999, 1.0, 100.0 },
    -- digimon
    -- pokemon
}

local function inject_for_faction(faction)
    for _, u in ipairs(CZX_VMP_POOL_UNITS) do
        local ok, err = pcall(function()
            cm:add_unit_to_faction_mercenary_pool(
                faction, u[1], POOL_SOURCE, u[2],
                u[4], u[3], u[5],
                "", "", "",
                false, u[1])
        end)
        if not ok then
            out("[czx_vmp_raise_dead] inject fail " .. tostring(u[1]) .. ": " .. tostring(err))
        end
    end
end

local function inject_all()
    local ok, factions = pcall(function() return cm:model():world():faction_list() end)
    if not ok or not factions then
        return
    end
    for i = 0, factions:num_items() - 1 do
        local f = factions:item_at(i)
        local ok_sc, sc = pcall(function() return f:subculture() end)
        if ok_sc and sc == VMP_SUBCULTURE then
            inject_for_faction(f)
            out("[czx_vmp_raise_dead] injected pool units for " .. tostring(f:name()))
        end
    end
end

cm:add_first_tick_callback(function()
    if not cm:get_saved_value(SAVE_FLAG) then
        inject_all()
        cm:set_saved_value(SAVE_FLAG, true)
    end
end)
