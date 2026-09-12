-- PSW动态唯一天赋上限系统
-- 作者：Devin AI
-- 功能：实现动态增加唯一天赋上限，参考和泉纪愛三星卡效果

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
            last_repick_turn = -1 -- 上次重新抽取的回合
        }
    end
    return psw_main_data.player_data[faction_name]
end

-- Effect Bundle应用函数（隐藏效果）
function psw_aplly_costom_effect_bundle_hidden(effect_key, faction)
    if not faction or not effect_key then
        out("PSW Error: Missing parameters for effect bundle application")
        return false
    end
    
    local faction_name = faction:name()
    
    -- 检查是否已有该效果，避免重复应用
    if faction:has_effect_bundle(effect_key) then
        out("PSW: Effect bundle " .. effect_key .. " already exists for " .. faction_name)
        return true
    end
    
    -- 应用效果bundle
    local model = cm:model()
    local effect_bundle = model:create_effect_bundle(effect_key, faction_name)
    
    if effect_bundle then
        effect_bundle:set_duration(-1)  -- 永久效果
        effect_bundle:add_effect("wh_main_effect_bundle_dummy", 1)
        faction:apply_effect_bundle(effect_bundle)
        out("PSW: Applied effect bundle " .. effect_key .. " to " .. faction_name)
        return true
    else
        out("PSW Error: Failed to create effect bundle " .. effect_key)
        return false
    end
end

-- 检查派系是否有特定效果bundle
function psw_faction_has_effect_bundle(faction_name, effect_key)
    local faction = cm:get_faction(faction_name)
    if faction then
        return faction:has_effect_bundle(effect_key)
    end
    return false
end

-- 动态增加EX天赋上限函数（参考和泉纪愛效果）
function psw_add_ex_limit_jiefang(faction_name)
    local faction = cm:get_faction(faction_name)
    if not faction then
        out("PSW Error: Faction " .. faction_name .. " not found")
        return false
    end
    
    -- 初始化或获取玩家数据
    local data = psw_init_player_data(faction_name)
    data.ex_limit_count = (data.ex_limit_count or 0) + 1  -- 增加计数
    
    -- 应用唯一的效果bundle（可堆叠）
    local effect_key = "set_ex_shangxian_" .. data.ex_limit_count
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
            
            out("PSW: 第一次解除EX天赋上限限制！当前上限+1")
        else
            out("PSW: EX天赋上限再次增加！当前总增加: " .. data.ex_limit_count)
        end
        
        return true
    else
        out("PSW Error: Failed to apply EX limit increase")
        return false
    end
end

-- 重新抽取功能
function psw_enable_repick(faction_name)
    local faction = cm:get_faction(faction_name)
    if not faction then
        out("PSW Error: Faction " .. faction_name .. " not found")
        return false
    end
    
    local data = psw_init_player_data(faction_name)
    data.repick_count = (data.repick_count or 0) + 1
    data.last_repick_turn = cm:turn_number()
    
    out("PSW: 启用重新抽取功能，当前回合: " .. data.last_repick_turn)
    return true
end

-- 检查是否可以重新抽取
function psw_can_repick(faction_name)
    local data = psw_main_data.player_data[faction_name]
    if not data then
        return false
    end
    
    -- 检查当前回合是否与上次重新抽取不同
    local current_turn = cm:turn_number()
    return data.last_repick_turn ~= current_turn
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
        out("PSW动态上限系统已加载")
        
        -- 为当前玩家派系初始化数据
        local local_faction_name = cm:get_local_faction_name(true)
        if local_faction_name then
            psw_init_player_data(local_faction_name)
            out("PSW: 已为派系 " .. local_faction_name .. " 初始化数据")
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

out("PSW动态唯一天赋上限系统脚本已加载完成")