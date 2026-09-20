-- PSW merged: 天赋点击监听器去重修正
-- 原版 psw_天赋.lua 与本包 psw_02_tianfu.lua 路径不同，两个文件都会加载，
-- 且 core:add_listener 对同名监听器是"追加共存"而非覆盖（lib_core.lua: table.insert）。
-- 结果：点击任何 UI 组件时原版的 psw_main_tfxz 回调仍会触发，
-- 对非建筑槽组件 GetContextObject("CcoCampaignBuildingSlot") 返回 nil 直接报错刷屏
-- （sm0_log 中 psw_天赋.lua:2007/2009/2022 大量 attempt to index local 'ccc'/'tf_key_cco'），
-- 且每次有效点击会重复 TriggerCampaignScriptEvent 两次。
-- 本文件名按路径排序在所有 psw_* 之后加载，其 first_tick 回调最后执行：
-- 清掉所有同名监听器，只重新注册 nil 安全版本 psw_main_tfxz_merged（定义于 psw_02_tianfu.lua）。

cm:add_first_tick_callback(function()
    -- psw_main_tfxz_merged 内部已做 remove_listener("psw_main_tfxz") + add_listener
    if type(psw_main_tfxz_merged) == "function" then
        psw_main_tfxz_merged()
        out("[psw_talent_fix] psw_main_tfxz re-registered (nil-safe handler only)")
    else
        out("[psw_talent_fix] WARN: psw_main_tfxz_merged not found")
    end

    -- ui_psw_main_tfxz：原版文件加载时会先 remove_listener 清掉我们在 psw_02 里注册的同名监听器，
    -- 这里最后重新注册，确保生效的是带诊断/自动补抽的修正版
    if type(ui_psw_main_tfxz_merged_cb) == "function" then
        core:remove_listener("ui_psw_main_tfxz")
        core:add_listener(
            "ui_psw_main_tfxz",
            "UITrigger",
            ui_psw_main_tfxz_merged_condition,
            ui_psw_main_tfxz_merged_cb,
            true
        )
        out("[psw_talent_fix] ui_psw_main_tfxz re-registered (merged handler)")
    else
        out("[psw_talent_fix] WARN: ui_psw_main_tfxz_merged_cb not found")
    end
end)
