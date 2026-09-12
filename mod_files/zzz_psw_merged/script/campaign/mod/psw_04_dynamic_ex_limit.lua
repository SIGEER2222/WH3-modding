-- PSW动态唯一天赋上限系统
-- 作者：Devin AI
-- 功能：实现动态增加唯一天赋上限，参考和泉纪愛三星卡效果
-- 修改：修复函数名匹配、支持无限重抽、上限可堆叠至20层
-- 调试：使用 ModLog() 输出到 lua_mod_log.txt

-- PSW主要数据管理模块
if not psw_main_data then
    psw_main_data = {}
end

if not psw_main_data.player_data then
    psw_main_data.player_data = {}
end

-- 初始化玩家数据
local function psw_init_player_data(faction_name)
    if not psw_main_data.player_data[faction_name] then
        psw_main_data.player_data[faction_name] = {
            ex_limit_count = 0,  -- 当前EX天赋上限增加次数
            repick_count = 0,   -- 重新抽取次数
            last_repick_turn = -1 -- 上次重新抽取的回合（已停用，保留兼容）
        }
    end
    return psw_main_data.player_data[faction_name]
end

-- Effect Bundle应用函数（隐藏效果）
-- 兼容主MOD中 psw_02/psw_03 调用的 _fn 版本
function psw_aplly_costom_effect_bundle_hidden(effect_key, faction)
    if not faction or not effect_key then
        ModLog("PSW Error: Missing parameters for effect bundle application")
        return false
    end

    local faction_name = faction:name()

    -- 检查是否已有该效果，避免重复应用
    if faction:has_effect_bundle(effect_key) then
        ModLog("PSW: Effect bundle " .. effect_key .. " already exists for " .. faction_name)
        return true
    end

    -- 尝试方式1：cm:create_new_custom_effect_bundle + cm:apply_custom_effect_bundle_to_faction
    local ok1, effect_bundle = pcall(function()
        return cm:create_new_custom_effect_bundle(effect_key)
    end)
    if ok1 and effect_bundle then
        effect_bundle:set_duration(0)  -- 0 = 永久效果
        effect_bundle:add_effect("wh_main_effect_bundle_dummy", "faction_to_faction_own", 1)
        local ok_apply, err_apply = pcall(function()
            cm:apply_custom_effect_bundle_to_faction(effect_bundle, faction)
        end)
        if ok_apply then
            ModLog("PSW: [方式1] Applied effect bundle " .. effect_key .. " to " .. faction_name)
            return true
        else
            ModLog("PSW: [方式1] apply failed: " .. tostring(err_apply))
        end
    else
        ModLog("PSW: [方式1] create failed: " .. tostring(effect_bundle))
    end

    -- 尝试方式2：cm:model():create_effect_bundle + faction:apply_effect_bundle（原始API）
    local ok2, model_bundle = pcall(function()
        local model = cm:model()
        return model:create_effect_bundle(effect_key, faction_name)
    end)
    if ok2 and model_bundle then
        model_bundle:set_duration(-1)
        local ok_add, err_add = pcall(function()
            model_bundle:add_effect("wh_main_effect_bundle_dummy", 1)
        end)
        ModLog("PSW: [方式2] add_effect result: ok=" .. tostring(ok_add) .. " err=" .. tostring(err_add))
        local ok_apply2, err_apply2 = pcall(function()
            faction:apply_effect_bundle(model_bundle)
        end)
        if ok_apply2 then
            ModLog("PSW: [方式2] Applied effect bundle " .. effect_key .. " to " .. faction_name)
            return true
        else
            ModLog("PSW: [方式2] apply failed: " .. tostring(err_apply2))
        end
    else
        ModLog("PSW: [方式2] create failed: " .. tostring(model_bundle))
    end

    ModLog("PSW Error: All methods failed for effect bundle " .. effect_key)
    return false
end

-- _fn 别名：主MOD的 psw_02/psw_03 调用的是带 _fn 后缀的版本
psw_aplly_costom_effect_bundle_hidden_fn = psw_aplly_costom_effect_bundle_hidden

-- 检查派系是否有特定效果bundle
function psw_faction_has_effect_bundle(faction_name, effect_key)
    local faction = cm:get_faction(faction_name)
    if faction then
        return faction:has_effect_bundle(effect_key)
    end
    return false
end

-- 动态增加EX天赋上限函数（参考和泉纪愛效果）
-- 每次调用 +1，最多堆叠20层（受 effect_bundles DB 定义数量限制）
function psw_add_ex_limit_jiefang(faction_name)
    ModLog("PSW: psw_add_ex_limit_jiefang called for " .. tostring(faction_name))
    local faction = cm:get_faction(faction_name)
    if not faction then
        ModLog("PSW Error: Faction " .. tostring(faction_name) .. " not found")
        return false
    end

    -- 初始化或获取玩家数据
    local data = psw_init_player_data(faction_name)
    local new_count = (data.ex_limit_count or 0) + 1

    -- 上限保护：DB 中定义了 set_ex_shangxian_1 ~ set_ex_shangxian_20
    if new_count > 20 then
        ModLog("PSW: EX天赋上限已达最大堆叠层数 20，不再增加")
        return false
    end

    data.ex_limit_count = new_count
    ModLog("PSW: new ex_limit_count = " .. tostring(new_count))

    -- 应用唯一的效果bundle（可堆叠，每层一个独立 bundle）
    local effect_key = "set_ex_shangxian_" .. data.ex_limit_count
    ModLog("PSW: applying effect bundle " .. effect_key)
    local success = psw_aplly_costom_effect_bundle_hidden(effect_key, faction)

    if success then
        -- 仅在第一次时播放音效和提示
        if data.ex_limit_count == 1 then
            -- 播放音效（如果存在）
            if common.trigger_soundevent then
                common.trigger_soundevent("alice_exsx")
            end

            -- 显示提示（如果存在）
            if alice_main_advice_exsx then
                alice_main_advice_exsx()
            end

            ModLog("PSW: 第一次解除EX天赋上限限制！当前上限+1")
        else
            ModLog("PSW: EX天赋上限再次增加！当前总增加: " .. tostring(data.ex_limit_count))
        end

        return true
    else
        ModLog("PSW Error: Failed to apply EX limit increase (effect bundle " .. effect_key .. " not found in DB?)")
        return false
    end
end

-- 重新抽取功能
function psw_enable_repick(faction_name)
    local faction = cm:get_faction(faction_name)
    if not faction then
        ModLog("PSW Error: Faction " .. tostring(faction_name) .. " not found")
        return false
    end

    local data = psw_init_player_data(faction_name)
    data.repick_count = (data.repick_count or 0) + 1
    data.last_repick_turn = cm:turn_number()

    ModLog("PSW: 启用重新抽取功能，当前回合: " .. tostring(data.last_repick_turn))
    return true
end

-- 检查是否可以重新抽取
-- 已改为无限重抽：不再限制回合
function psw_can_repick(faction_name)
    return true
end

-- 获取当前EX天赋上限增加数量
function psw_get_ex_limit_count(faction_name)
    local data = psw_main_data.player_data[faction_name]
    if data then
        return data.ex_limit_count or 0
    end
    return 0
end

-- 初始化监听器
cm:add_first_tick_callback(
    function()
        ModLog("PSW: 动态上限系统已加载 (first_tick)")

        -- 为当前玩家派系初始化数据
        local local_faction_name = cm:get_local_faction_name(true)
        if local_faction_name then
            psw_init_player_data(local_faction_name)
            ModLog("PSW: 已为派系 " .. tostring(local_faction_name) .. " 初始化数据")
        else
            ModLog("PSW: 未找到 local_faction_name")
        end
    end
)

-- 导出函数供外部调用
psw_dynamic_ex_limit = {
    add_ex_limit = psw_add_ex_limit_jiefang,
    enable_repick = psw_enable_repick,
    can_repick = psw_can_repick,
    get_ex_limit_count = psw_get_ex_limit_count,
    init_data = psw_init_player_data
}

ModLog("PSW: 动态唯一天赋上限系统脚本已加载完成（无限重抽版 + 调试日志）")
