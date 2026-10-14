---------------------------------------------------------------------------------------------------
-- czx_disband_army.lua
-- 按钮入口：
--   [✕] 一键撤编（button_group_army 部队面板）：整队解散，所有单位
--       （key/兵力%/经验等级/成本）存入本派系"军备池"，将领受伤回池
--       （装备保留）——仿全战三国"撤回整编"：部队不丢，存在池里。
--   [＋] 打开军备池浏览面板（settlement_panel 城卡右上角，仅城内有驻军
--       部队时可见）：运行时拼装的勾选面板——每行显示兵种图标/名称/兵
--       力%/勋级/成本，逐队勾选后点「重组所选」经 czx_remuster_pick 补入
--       该城驻军（至多满编20格），按单位成本×兵力% 逐队扣国库
--       （treasury_mod），并按存入时的兵力%与经验等级恢复
--       （set_unit_hp_to_unary_of_maximum / add_experience_to_unit）。
--       国库不足/发放失败的队留在池里；未勾选的队不动。
--       v9 起召回钮从军队面板挪到定居点面板（用户诉求"召回按钮应该在
--       建筑上"）；v12 起改浏览+勾选确认，不再一键全发（"不能点一下
--       就召出来了"）。野战军面板不再有补员入口。
--
-- v4（2026-10-07）：三国式"撤编+存储"——
--   ① 撤编前把非领主/英雄单位逐一快照进 unit_bank（save_named_value 持久化，
--      随存档保存）；
--   ② 将领撤编沿用 wound_character（回池不剥装），兜底 kill_character；
--   ③ 重组= grant_unit_to_character 逐队发放，发完按"发放前同 key 单位数"跳过
--      原有单位，仅对新发单位恢复 hp/rank；
--   ④ 单位池按派系存储、可跨军队混编；驻军将领拒绝撤编。
--
-- v3 遗留修复点（选人链路/重试/UI闸）全部保留：
--   uim:get_char_selected_cqi() 权威选择 → SelectedOrContainedCharacter 兜底 →
--   uim:get_mf_selected_cqi() 反查；随军英雄经 embedded_in_military_force()
--   回溯宿主军 + general_character() 锁主将。
---------------------------------------------------------------------------------------------------

local disband_txt = "Disband: store all units into the reserve pool (lord wounded, gear kept)"
local remuster_txt = "Remuster: refill this settlement's garrisoned army from the reserve pool"
local language = common.get_context_value("LocLanguage")
if language == "CN" or language == "ZH" then
    disband_txt = "一键撤编：部队存入军备池，将领受伤回池（装备保留，可重组）"
    remuster_txt = "一键重组：向本城驻军从军备池补满（按成本×兵力扣国库，恢复兵力与经验）"
end

local MAX_FORCE_SLOTS = 20          -- 军队卡片上限（含将领位与随军英雄位）
local BANK_SAVE_KEY = "czx_unit_bank"
-- 重组计费系数：get_unit_custom_battle_cost 与战役招募价同量级（略低），
-- 乘兵力%计残兵折价。调 0 = 免费重组。
local REMUSTER_COST_FACTOR = 1.0

local unit_bank = {}                -- [faction_key] = { {key=, hp=, rank=}, ... }
local bank_panel_refresh            -- 军备池面板刷新（first_tick 内赋值，pick 发放后复用）

local function log(msg)
    pcall(out, "[czx_disband] " .. tostring(msg))
end

-- 拒绝/空池时给玩家一条事件 feed 提示（loc 在 !!!czx_ancillary_sell.loc）
local EFT_SCRIPTED_EVENT = 225
local function notify_feed(subkey)
    local okf, fname = pcall(function() return cm:get_local_faction_name(true) end)
    if okf and fname then
        pcall(cm.show_message_event, cm, fname,
            "event_feed_strings_text_czx_bank_title",
            "event_feed_strings_text_" .. subkey,
            "event_feed_strings_text_czx_bank_title",
            false, EFT_SCRIPTED_EVENT)
    end
end

local function bank_push(faction_name, entry)
    if not faction_name or faction_name == "" then return end
    local b = unit_bank[faction_name]
    if not b then
        b = {}
        unit_bank[faction_name] = b
    end
    b[#b + 1] = entry
end

local function bank_count(faction_name)
    local b = unit_bank[faction_name]
    return b and #b or 0
end

-- ---------- 存档持久化 ----------
cm:add_loading_game_callback(function(context)
    local t = {}
    if cm:is_new_game() == false then
        t = cm:load_named_value(BANK_SAVE_KEY, {}, context)
    end
    if type(t) == "table" then
        unit_bank = t
    end
    local total = 0
    for _, b in pairs(unit_bank) do total = total + #b end
    log("bank loaded, " .. total .. " stored units across factions")
end)

cm:add_saving_game_callback(function(context)
    cm:save_named_value(BANK_SAVE_KEY, unit_bank, context)
end)

-- ---------- 选中军队解析（点击侧与服务端共用逻辑） ----------
-- 返回 force, general；失败返回 nil
local function resolve_selected_force(char_cqi, mf_cqi)
    local force
    local okc, char = pcall(function()
        if char_cqi and char_cqi > 0 then
            return cm:get_character_by_cqi(char_cqi)
        end
    end)
    if okc and char and not char:is_null_interface() then
        local okf, faction_human = pcall(function() return char:faction():is_human() end)
        if not (okf and faction_human) then
            log("char " .. tostring(char_cqi) .. " not human faction, refuse")
            return nil
        end
        local okm, mf = pcall(function()
            if char:has_military_force() then
                return char:military_force()
            elseif char:is_embedded_in_military_force() then
                return char:embedded_in_military_force()
            end
        end)
        if okm and mf then
            force = mf
            local okgen, is_gen = pcall(function() return char:has_military_force() end)
            log("resolved via char " .. tostring(char_cqi)
                .. (okgen and is_gen and " (general)" or " (embedded hero -> host force)"))
        end
    end
    if not force and mf_cqi then
        local okm2, mf2 = pcall(function() return cm:get_military_force_by_cqi(mf_cqi) end)
        if okm2 and mf2 then
            local okf2, human2 = pcall(function() return mf2:faction():is_human() end)
            if okf2 and human2 then
                force = mf2
                log("resolved via mf_cqi " .. tostring(mf_cqi))
            end
        end
    end
    if not force then
        log("no force resolved, abort")
        return nil
    end
    -- 城防守备队（armed citizenry）不是可补员目标：colonel 带队、unit_list()
    -- 不暴露给战役 API，grant_unit_to_character 对它静默无效。
    local okcit, is_cit = pcall(function() return force:is_armed_citizenry() end)
    if okcit and is_cit then
        log("resolved force is armed citizenry (settlement watch), refuse")
        return nil
    end
    local okg, general = pcall(function() return force:general_character() end)
    if not (okg and general) or general:is_null_interface() then
        log("force has no general, abort")
        return nil
    end
    return force, general
end

local function collect_selection()
    local char_cqi, mf_cqi
    local ok_uim, uim = pcall(function() return cm:get_campaign_ui_manager() end)
    if ok_uim and uim then
        local ok1, v1 = pcall(function() return uim:get_char_selected_cqi() end)
        -- uim 无选中返回 -1（非 0/false）；只收正数 cqi，否则 -1 会顶掉 CQI 兜底
        if ok1 and type(v1) == "number" and v1 > 0 then char_cqi = v1 end
        local ok2, v2 = pcall(function() return uim:get_mf_selected_cqi() end)
        if ok2 and type(v2) == "number" and v2 > 0 then mf_cqi = v2 end
    end
    if not char_cqi then
        local ok3, v3 = pcall(function() return common.get_context_value("SelectedOrContainedCharacter.CQI") end)
        if ok3 and type(v3) == "number" and v3 > 0 then char_cqi = v3 end
    end
    return char_cqi, mf_cqi
end

cm:add_first_tick_callback(function()
    -- create the buttons whenever the units panel opens with an army selected
    -- §10.40：PanelOpened 派发窗口内面板子树还在建/拆，内联 find_uicomponent+
    -- CreateComponent 撞半构建节点 = +0x22c0f80 族 UAF（2052/2125 会话崩在
    -- units_panel open 后 <0.5s）。推迟 0.3s 出派发窗；lock_ui/AI 回合等闸
    -- 不过时**重试**而非弃轮。
    core:add_listener(
        "czx_disband_panel_open",
        "PanelOpenedCampaign",
        function(context)
            return context.string == "units_panel"
        end,
        function(context)
            local attempt = 0
            local function try_create()
                attempt = attempt + 1
                local ok_uim, uim = pcall(function() return cm:get_campaign_ui_manager() end)
                if not ok_uim or not uim or uim.ui_locked then
                    log("create retry " .. attempt .. ": ui_locked")
                    return false
                end
                local ok_open, open = pcall(function() return uim:is_panel_open("units_panel") end)
                if not (ok_open and open) then
                    log("create retry " .. attempt .. ": units_panel closed")
                    return true  -- 面板已关，停止重试（下次打开重建）
                end
                local ok_ai, ai_turn = pcall(function()
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
                if ok_ai and ai_turn then
                    log("create retry " .. attempt .. ": ai_turn")
                    return false
                end
                local button_parent = find_uicomponent(core:get_ui_root(), "hud_campaign", "hud_center_docker", "hud_center", "small_bar", "button_subpanel_parent", "button_subpanel", "button_group_army")
                if not button_parent then
                    log("create retry " .. attempt .. ": button_group_army not found")
                    return false
                end
                local btn = core:get_or_create_component("czx_button_disband_army", "ui/templates/square_medium_button.twui.xml", button_parent)
                if btn then
                    btn:SetImagePath("ui/skins/default/icon_cross_square.png")
                    btn:SetTooltipText(disband_txt, true)
                end
                local okf, fname = pcall(function() return cm:get_local_faction_name(true) end)
                local bank_n = (okf and fname) and bank_count(fname) or 0
                if btn then
                    log("buttons created (attempt " .. attempt .. ", bank " .. bank_n .. ")")
                    return true
                end
                return false
            end
            local function retry_loop()
                if try_create() then return end
                if attempt >= 10 then
                    log("create gave up after " .. attempt .. " attempts")
                    return
                end
                cm:callback(retry_loop, 0.3)
            end
            cm:callback(retry_loop, 0.3)
        end,
        true
    )

    core:add_listener(
        "czx_disband_click",
        "ComponentLClickUp",
        function(context)
            return context.string == "czx_button_disband_army"
        end,
        function(context)
            local char_cqi, mf_cqi = collect_selection()
            log("disband clicked, char_cqi=" .. tostring(char_cqi) .. " mf_cqi=" .. tostring(mf_cqi))
            if char_cqi or mf_cqi then
                CampaignUI.TriggerCampaignScriptEvent(
                    char_cqi or 0,
                    "czx_disband_army|" .. tostring(char_cqi) .. "|" .. tostring(mf_cqi)
                )
            else
                log("clicked but nothing selected, ignored")
            end
        end,
        true
    )

    -- ---------- 定居点驻军补员按钮（三国式：召回钮长在建筑上） ----------
    -- settlement_panel > settlement_list > CcoCampaignSettlement<region_key>
    -- 每城卡右上角一枚 [+]；仅当城内有本派系驻军部队时可见。点击 → 解析
    -- 城内驻军 → 复用 czx_remuster_army|char|mf 服务端路径
    -- （has_garrison_residence 权威校验兜底）。
    -- garrison_residence:army() 给的是城防守备队（armed citizenry，colonel 带队，
    -- 不接受 grant_unit）。将领驻防军要遍历派系军力表，按"非守备队 + 有将领 +
    -- garrison_residence 落在该 region"匹配。
    local function settle_garrison_cqis(region_key)
        local okf, fname = pcall(function() return cm:get_local_faction_name() end)
        if not (okf and fname) then return nil end
        local okfa, faction = pcall(function() return cm:get_faction(fname) end)
        if not (okfa and faction) then return nil end
        local okl, fl = pcall(function() return faction:military_force_list() end)
        if not (okl and fl) then return nil end
        local okn, n = pcall(function() return fl:num_items() end)
        if not (okn and n) then return nil end
        for i = 0, n - 1 do
            local oki, mf = pcall(function() return fl:item_at(i) end)
            if oki and mf then
                local okc, is_cit = pcall(function() return mf:is_armed_citizenry() end)
                local okh, has_gr = pcall(function() return mf:has_garrison_residence() end)
                local okg, has_gen = pcall(function() return mf:has_general() end)
                if okc and not is_cit and okh and has_gr and okg and has_gen then
                    local okr, rk = pcall(function()
                        return mf:garrison_residence():region():name()
                    end)
                    if okr and rk == region_key then
                        local mf_cqi
                        pcall(function() mf_cqi = mf:command_queue_index() end)
                        local char_cqi
                        local okgen, g = pcall(function() return mf:general_character() end)
                        if okgen and g then
                            pcall(function()
                                if not g:is_null_interface() then
                                    char_cqi = g:command_queue_index()
                                end
                            end)
                        end
                        return char_cqi, mf_cqi
                    end
                end
            end
        end
        return nil
    end

    -- ---------- 军备池浏览面板：点城卡 [+] 打开，勾选后确认发放 ----------
    -- 全运行时拼装（监狱面板同套路，无 twui）：script_dummy 根 + groovy/text、
    -- groovy/image + square_medium_text_button_toggle 行钮。勾选态存
    -- bank_ui.sel（池下标），确认把下标随 czx_remuster_pick 发给服务端逐队补入。
    local BANK_PANEL_ID = "czx_bank_panel"
    local BANK_ROWS = 10
    local bank_ui = { region_key = nil, char_cqi = nil, mf_cqi = nil, sel = {}, page = 0 }

    local function bp_find()
        return find_uicomponent(core:get_ui_root(), BANK_PANEL_ID)
    end

    local function bp_place(c, w, h, x, y)
        c:SetCanResizeWidth(true)
        c:SetCanResizeHeight(true)
        c:Resize(w, h)
        c:SetDockingPoint(5)
        c:SetDockOffset(x, y)
    end

    local function bp_set_text(c, txt)
        txt = tostring(txt or "")
        pcall(function() c:SetStateText(txt) end)
        for _, lbl in ipairs({ "button_txt", "dy_province" }) do
            local ok, l = pcall(function() return find_uicomponent(c, lbl) end)
            if ok and l then
                pcall(function() l:SetStateText(txt) end)
            end
        end
    end

    local function bp_button(parent, id, tpl, w, h, x, y, txt, cb)
        local b = core:get_or_create_component(id, tpl, parent)
        if not b then return nil end
        bp_place(b, w, h, x, y)
        bp_set_text(b, txt)
        b:SetVisible(true)
        if cb then
            core:remove_listener("czx_bp_" .. id)
            core:add_listener("czx_bp_" .. id, "ComponentLClickUp",
                function(context) return context.string == id end, cb, true)
        end
        return b
    end

    local function bp_image(parent, id, path, w, h, x, y)
        local img
        pcall(function()
            img = core:get_or_create_component(id, "ui/groovy/image", parent)
        end)
        if not img then return nil end
        bp_place(img, w, h, x, y)
        pcall(function() img:SetImagePath(path) end)
        pcall(function() img:SetInteractive(false) end)
        img:SetVisible(true)
        return img
    end

    local function bp_text(parent, id, w, h, x, y, txt)
        local t
        pcall(function()
            t = core:get_or_create_component(id, "ui/groovy/text/fe_default", parent)
        end)
        if not t then return nil end
        bp_place(t, w, h, x, y)
        bp_set_text(t, txt)
        t:SetVisible(true)
        return t
    end

    local function unit_disp_name(key)
        local name = common.get_localised_string("land_units_onscreen_name_" .. key)
        if type(name) ~= "string" or name == ""
            or name == "land_units_onscreen_name_" .. key then
            return key
        end
        return name
    end

    local function entry_charge(e)
        return math.floor((e.cost or 0) * ((e.hp or 100) / 100)
            * REMUSTER_COST_FACTOR + 0.5)
    end

    local function local_bank()
        local okf, fname = pcall(function() return cm:get_local_faction_name(true) end)
        if not (okf and fname) then return {}, nil end
        return unit_bank[fname] or {}, fname
    end

    local function bank_panel_hide()
        local p = bp_find()
        if p then p:SetVisible(false) end
        cm:release_escape_key_with_callback("czx_bank_hide")
    end

    function bank_panel_refresh(clear_sel)
        local panel = bp_find()
        if not panel then return end
        -- clear_sel：发放后池内剩余条目下标整体前移，旧勾选下标已失真，
        -- 必须全清（否则未勾选的队会继承被发走队的下标显示为已选）
        if clear_sel then bank_ui.sel = {} end
        local bank, fname = local_bank()
        local nb = #bank
        for i in pairs(bank_ui.sel) do
            if i > nb or not bank[i] then bank_ui.sel[i] = nil end
        end
        local nsel, cost_sel = 0, 0
        for i in pairs(bank_ui.sel) do
            nsel = nsel + 1
            cost_sel = cost_sel + entry_charge(bank[i])
        end
        local okt, treasury = pcall(function()
            return cm:get_faction(fname):treasury()
        end)
        local purse = (okt and type(treasury) == "number") and treasury or 0

        local status = find_uicomponent(panel, "czx_bank_status")
        if status then
            bp_set_text(status, string.format(
                "在库 %d 队 · 已选 %d 队 · 预计军费 %d · 国库 %d",
                nb, nsel, cost_sel, purse))
        end
        local pages = math.max(1, math.ceil(nb / BANK_ROWS))
        if bank_ui.page > pages - 1 then bank_ui.page = pages - 1 end
        if bank_ui.page < 0 then bank_ui.page = 0 end
        local first = bank_ui.page * BANK_ROWS + 1
        for r = 1, BANK_ROWS do
            local i = first + r - 1
            local row = find_uicomponent(panel, "czx_bank_row_" .. r)
            if row then
                if i <= nb then
                    local e = bank[i]
                    row:SetVisible(true)
                    bp_set_text(row, string.format("%s  兵%d%%  ★%d  军费%d",
                        unit_disp_name(e.key), math.floor(e.hp or 100),
                        e.rank or 0, entry_charge(e)))
                    local ic = find_uicomponent(row, "czx_bank_icon_" .. r)
                    if ic then
                        pcall(function()
                            ic:SetImagePath("ui/units/icons/" .. e.key .. ".png")
                        end)
                    end
                    row:SetState(bank_ui.sel[i] and "selected" or "active")
                else
                    row:SetVisible(false)
                end
            end
        end
        local pg = find_uicomponent(panel, "czx_bank_pageinfo")
        if pg then
            bp_set_text(pg, pages > 1
                and string.format("%d / %d", bank_ui.page + 1, pages) or "")
            pg:SetVisible(pages > 1)
        end
        for _, id in ipairs({ "czx_bank_prev", "czx_bank_next" }) do
            local b = find_uicomponent(panel, id)
            if b then b:SetVisible(pages > 1) end
        end
        local go = find_uicomponent(panel, "czx_bank_go")
        if go then
            if nsel > 0 then
                go:SetState("active")
                bp_set_text(go, string.format("重组所选 (%d)", nsel))
            else
                go:SetState("inactive")
                bp_set_text(go, "勾选要补入的部队")
            end
        end
    end

    local function bank_panel_open(region_key)
        local char_cqi, mf_cqi = settle_garrison_cqis(region_key)
        if not mf_cqi then
            notify_feed("czx_bank_no_army")
            return
        end
        local panel = bp_find()
        if not panel then
            -- 监狱面板同款：script_dummy 直接挂 ui_root（无父参）
            panel = core:get_or_create_component(
                BANK_PANEL_ID, "ui/campaign ui/script_dummy")
            if not panel then return end
            panel:PropagatePriority(300)
            local W = 640
            local H = 110 + BANK_ROWS * 56 + 86
            bp_place(panel, W, H, 0, -10)
            bp_image(panel, "czx_bank_bg",
                "ui/skins/default/panel_back_tile.png", W, H, 0, 0)
            bp_image(panel, "czx_bank_border",
                "ui/skins/default/panel_back_border.png", W, H, 0, 0)
            bp_text(panel, "czx_bank_title", W - 80, 30, 0, -H / 2 + 24, "军备池")
            bp_text(panel, "czx_bank_status", W - 60, 26, 0, -H / 2 + 60, "")
            local x = bp_button(panel, "czx_bank_close",
                "ui/templates/round_small_button.twui.xml",
                30, 30, W / 2 - 22, -H / 2 + 20, "", bank_panel_hide)
            if x then
                pcall(function()
                    x:SetImagePath("ui/skins/default/icon_cross.png")
                end)
            end
            for r = 1, BANK_ROWS do
                local row_y = -H / 2 + 108 + (r - 1) * 56
                local row = bp_button(panel, "czx_bank_row_" .. r,
                    "ui/templates/square_medium_text_button_toggle.twui.xml",
                    W - 36, 52, 0, row_y, "", function()
                        local bank = local_bank()
                        local i = bank_ui.page * BANK_ROWS + r
                        if i <= #bank then
                            if bank_ui.sel[i] then
                                bank_ui.sel[i] = nil
                            else
                                bank_ui.sel[i] = true
                            end
                            bank_panel_refresh()
                        end
                    end)
                if row then
                    bp_image(row, "czx_bank_icon_" .. r,
                        "ui/skins/default/0_placeholder.png",
                        42, 42, -W / 2 + 46, 0)
                end
            end
            bp_text(panel, "czx_bank_pageinfo", 60, 30, 0, H / 2 - 40, "")
            bp_button(panel, "czx_bank_prev",
                "ui/templates/square_medium_text_button.twui.xml",
                60, 44, -70, H / 2 - 40, "◀", function()
                    if bank_ui.page > 0 then
                        bank_ui.page = bank_ui.page - 1
                    end
                    bank_panel_refresh()
                end)
            bp_button(panel, "czx_bank_next",
                "ui/templates/square_medium_text_button.twui.xml",
                60, 44, 70, H / 2 - 40, "▶", function()
                    local bank = local_bank()
                    if (bank_ui.page + 1) * BANK_ROWS < #bank then
                        bank_ui.page = bank_ui.page + 1
                    end
                    bank_panel_refresh()
                end)
            bp_button(panel, "czx_bank_all",
                "ui/templates/square_medium_text_button.twui.xml",
                140, 44, -W / 2 + 100, H / 2 - 40, "全选/清空", function()
                    local bank = local_bank()
                    local nsel = 0
                    for _ in pairs(bank_ui.sel) do nsel = nsel + 1 end
                    if nsel < #bank then
                        for i = 1, #bank do bank_ui.sel[i] = true end
                    else
                        bank_ui.sel = {}
                    end
                    bank_panel_refresh()
                end)
            bp_button(panel, "czx_bank_go",
                "ui/templates/square_medium_text_button.twui.xml",
                190, 44, W / 2 - 120, H / 2 - 40, "重组所选", function()
                    local bank = local_bank()
                    local picks = {}
                    for i = 1, #bank do
                        if bank_ui.sel[i] then picks[#picks + 1] = i end
                    end
                    if #picks == 0 then
                        notify_feed("czx_bank_pick_none")
                        return
                    end
                    CampaignUI.TriggerCampaignScriptEvent(
                        bank_ui.char_cqi or 0,
                        "czx_remuster_pick|" .. tostring(bank_ui.mf_cqi)
                            .. "|" .. table.concat(picks, ","))
                end)
        end
        bank_ui.region_key, bank_ui.char_cqi, bank_ui.mf_cqi =
            region_key, char_cqi, mf_cqi
        bank_ui.sel = {}
        bank_ui.page = 0
        local bank = local_bank()
        for i = 1, #bank do bank_ui.sel[i] = true end
        local title = find_uicomponent(panel, "czx_bank_title")
        if title then
            local okn, rname = pcall(function()
                return common.get_localised_string("regions_onscreen_" .. region_key)
            end)
            if okn and type(rname) == "string" and rname ~= ""
                and rname ~= "regions_onscreen_" .. region_key then
                bp_set_text(title, "军备池——" .. rname .. " 驻军整补")
            else
                bp_set_text(title, "军备池——驻军整补")
            end
        end
        bank_panel_refresh()
        panel:SetVisible(true)
        cm:release_escape_key_with_callback("czx_bank_hide")
        cm:steal_escape_key_with_callback("czx_bank_hide", bank_panel_hide)
    end

    core:add_listener(
        "czx_bank_panel_watch",
        "PanelClosedCampaign",
        function(context) return context.string == "settlement_panel" end,
        function() bank_panel_hide() end,
        true)

    local function ensure_settle_buttons()
        local okp, panel = pcall(function()
            return find_uicomponent(core:get_ui_root(), "settlement_panel")
        end)
        if not (okp and panel) then return end
        local slist = find_uicomponent(panel, "settlement_list")
        if not slist then return end
        local okf, fname = pcall(function() return cm:get_local_faction_name(true) end)
        local bank_n = (okf and fname) and bank_count(fname) or 0
        for i = 0, slist:ChildCount() - 1 do
            local okc, child = pcall(function()
                return UIComponent(slist:Find(i))
            end)
            if okc and child then
                local oki, id = pcall(function() return child:Id() end)
                local rk = oki and id and id:match("^CcoCampaignSettlement(.+)$")
                if rk and rk ~= "" then
                    local btn = find_uicomponent(child, "czx_button_remuster_settle")
                    if not btn then
                        btn = core:get_or_create_component(
                            "czx_button_remuster_settle",
                            "ui/templates/square_medium_button.twui.xml", child)
                    end
                    if btn then
                        btn:SetImagePath("ui/skins/default/icon_income_plus.png")
                        btn:SetDockingPoint(3)          -- 城卡右上角内
                        btn:SetDockOffset(-44, 4)
                        btn:SetTooltipText(remuster_txt
                            .. "（在库 " .. bank_n .. " 队）", true)
                        local _, mf_cqi = settle_garrison_cqis(rk)
                        btn:SetVisible(mf_cqi ~= nil)
                    end
                end
            end
        end
    end

    -- 面板打开后低频常驻扫描：视图切换/布局重建/驻军进出都会自动补建与刷新。
    -- 每 tick 双闸（ui_locked 跳帧续扫、面板关闭退出），UI 操作只在
    -- 定时器回调里跑——与 units_panel 建钮同一安全模式。
    local settle_scan_running = false
    core:add_listener(
        "czx_settle_panel_open",
        "PanelOpenedCampaign",
        function(context)
            return context.string == "settlement_panel"
        end,
        function(context)
            if settle_scan_running then return end
            settle_scan_running = true
            local function tick()
                local ok_uim, uim = pcall(function() return cm:get_campaign_ui_manager() end)
                if not ok_uim or not uim then
                    settle_scan_running = false
                    return
                end
                if uim.ui_locked then
                    cm:callback(tick, 0.5)
                    return
                end
                local ok_open, open = pcall(function()
                    return uim:is_panel_open("settlement_panel")
                end)
                if not (ok_open and open) then
                    settle_scan_running = false
                    return
                end
                pcall(ensure_settle_buttons)
                cm:callback(tick, 0.7)
            end
            cm:callback(tick, 0.4)
        end,
        true
    )

    core:add_listener(
        "czx_remuster_settle_click",
        "ComponentLClickUp",
        function(context)
            return context.string == "czx_button_remuster_settle"
        end,
        function(context)
            -- 父链回溯取城卡 region_key（按钮父=CcoCampaignSettlement<rk>）
            local region_key
            local okc, c = pcall(function() return UIComponent(context.component) end)
            local depth = 0
            while okc and c and depth < 6 do
                depth = depth + 1
                local oki, id = pcall(function() return c:Id() end)
                if oki and id then
                    local rk = id:match("^CcoCampaignSettlement(.+)$")
                    if rk and rk ~= "" then
                        region_key = rk
                        break
                    end
                end
                local okp, par = pcall(function() return c:Parent() end)
                if okp and par then
                    c = UIComponent(par)
                else
                    break
                end
            end
            log("settle remuster clicked, region=" .. tostring(region_key))
            if not region_key then return end
            bank_panel_open(region_key)
        end,
        true
    )
end)

-- ---------- 撤编：快照单位入池 → 将领受伤回池 → 校验 → 兜底击杀 ----------
core:add_listener(
    "czx_disband_army_UITrigger",
    "UITrigger",
    function(context)
        return context:trigger():starts_with("czx_disband_army|")
    end,
    function(context)
        local trig = context:trigger()
        local char_cqi = tonumber(trig:match("czx_disband_army|(%d+)"))
        local mf_cqi = tonumber(trig:match("|(%d+)$"))
        log("disband trigger: " .. tostring(trig) .. " -> char=" .. tostring(char_cqi) .. " mf=" .. tostring(mf_cqi))

        local force, general = resolve_selected_force(char_cqi, mf_cqi)
        if not force then return end
        local okgr, is_garrison = pcall(function() return general:has_garrison_residence() end)
        if okgr and is_garrison then
            log("garrison commander, refuse (disband via settlement)")
            notify_feed("czx_bank_garrison_disband")
            return
        end

        local mf_key = force:command_queue_index()
        local gen_cqi = general:command_queue_index()
        local okfn, fname = pcall(function() return force:faction():name() end)

        -- ① 快照全部非将领/英雄单位进军备池（将领位 caste=lord 随将领回池、
        --    随军英雄 caste=hero 由引擎处置，均不入池）
        local stored = 0
        local okl, ul = pcall(function() return force:unit_list() end)
        local n_units
        if okl and ul then
            local okn, n = pcall(function() return ul:num_items() end)
            if okn and type(n) == "number" then n_units = n end
        end
        if n_units then
            for j = 0, n_units - 1 do
                local oku, u = pcall(function() return ul:item_at(j) end)
                if oku and u then
                    local okca, caste = pcall(function() return u:unit_caste() end)
                    -- item_at(0) 恒为主将亲卫位（caravans_core 同款假设）；
                    -- caste 读不出来时按位序兜底
                    local is_command_slot = (j == 0)
                        or (okca and (caste == "lord" or caste == "hero"))
                    if not is_command_slot then
                        local okk, key = pcall(function() return u:unit_key() end)
                        local okh, hp = pcall(function() return u:percentage_proportion_of_full_strength() end)
                        local okr, rank = pcall(function() return u:experience_level() end)
                        local okco, cost = pcall(function() return u:get_unit_custom_battle_cost() end)
                        if okfn and fname and okk and key then
                            bank_push(fname, {
                                key = key,
                                hp = (okh and type(hp) == "number") and hp or 100,
                                rank = (okr and type(rank) == "number") and rank or 0,
                                cost = (okco and type(cost) == "number") and math.max(0, cost) or 0,
                            })
                            stored = stored + 1
                        end
                    end
                end
            end
        end
        log("disbanding force cqi=" .. tostring(mf_key) .. " units=" .. tostring(n_units)
            .. " general=" .. tostring(gen_cqi) .. " stored=" .. stored
            .. " bank_total=" .. bank_count(fname))

        -- ② 将领受伤回池（装备保留），军队连座解散
        local char_str = cm:char_lookup_str(general)
        local okcv, conv = pcall(function() return general:compute_convalesence_time() end)
        if not (okcv and type(conv) == "number" and conv > 0) then conv = 4 end
        local okw = pcall(function() cm:wound_character(char_str, conv) end)
        log("wound_character ok=" .. tostring(okw) .. " convalescence=" .. tostring(conv))

        -- ③ 0.6s 后校验军队消失。注意：wound_character 只伤角色——军队失去将领后
        --    引擎会自动补位一名新将领接管（"领主替换"），军队连同兵牌依然存活。
        --    此时旧 gen_cqi 已无军，直接 kill 只会误杀回池的原将领；
        --    必须取军队的当前将领（补位者），kill_character(destroy_force) 连军毁。
        cm:callback(function()
            local okv, exists = pcall(function()
                return cm:model():has_military_force_command_queue_index(mf_key)
            end)
            if not (okv and exists) then
                log("force gone, disband complete")
                return
            end
            local okm, mf = pcall(function()
                return cm:get_military_force_by_cqi(mf_key)
            end)
            local victim
            if okm and mf then
                local okg, g = pcall(function() return mf:general_character() end)
                if okg and g and not g:is_null_interface() then victim = g end
            end
            if not victim then
                log("force still exists but no current general found, abort fallback")
                return
            end
            local victim_cqi = victim:command_queue_index()
            log("force still exists after wound (engine replaced lord), "
                .. "killing current general cqi=" .. tostring(victim_cqi)
                .. " with destroy_force=true")
            -- 补位者是引擎白送的占位将领，直接杀；若罕见地仍查到原将领
            -- （wound 未生效），先挂永生挡死，杀完还原——保证他回池而非阵亡。
            local victim_str = cm:char_lookup_str(victim)
            local guard = (victim_cqi == gen_cqi)
            local oki, imm = pcall(function()
                return victim:character_details():is_immortal()
            end)
            if guard and oki and not imm then
                pcall(function() cm:set_character_immortality(victim_str, true) end)
            end
            local okk = pcall(function() cm:kill_character(victim_cqi, true, false) end)
            log("kill_character(current general) ok=" .. tostring(okk))
            if guard and oki and not imm then
                cm:callback(function()
                    pcall(function()
                        cm:set_character_immortality(victim_str, false)
                    end)
                    log("restored immortality=false for " .. tostring(victim_str))
                end, 0.5)
            end
        end, 0.6)
    end,
    true
)

-- ---------- 发放核心：把条目对象发还军队，恢复兵力/经验 ----------
-- entries = bank 条目对象快照（不是下标——发放会即时删池使下标漂移）。
-- 返回 granted_n, failed_n, total_cost。
local function bank_remove_ref(bank, e)
    for i = #bank, 1, -1 do
        if rawequal(bank[i], e) then
            table.remove(bank, i)
            return true
        end
    end
    return false
end

local function grant_bank_entries(force, general, fname, bank, entries)
        local char_str = cm:char_lookup_str(general)
        -- 记录发放前各 key 已有数量，恢复 hp/rank 时跳过这些原有单位
        local pre = {}
        local okn0, n0 = pcall(function() return force:unit_list():num_items() end)
        if okn0 and n0 then
            for j = 0, n0 - 1 do
                local oku, u = pcall(function() return force:unit_list():item_at(j) end)
                if oku and u then
                    local okk, k = pcall(function() return u:unit_key() end)
                    if okk and k then pre[k] = (pre[k] or 0) + 1 end
                end
            end
        end

        -- 逐队发放；grant 成功（槽位数增加）才把条目从池里删掉。
        -- 计费 = 快照成本 × 兵力% × 系数；国库不足跳过该队留在池里。
        local okt, treasury = pcall(function() return force:faction():treasury() end)
        local purse = (okt and type(treasury) == "number") and treasury or 0
        local total_cost = 0
        local granted = {}   -- 已发放条目对象（hp/rank 恢复队列用）
        local failed = 0
        for _, e in ipairs(entries) do
            local okc0, cur = pcall(function() return force:unit_list():num_items() end)
            if not (okc0 and cur) then
                log("unit_list unreadable (ok=" .. tostring(okc0)
                    .. " cur=" .. tostring(cur) .. "), stop granting")
                break
            end
            if cur >= MAX_FORCE_SLOTS then
                log("force full at " .. cur .. " slots, stop granting")
                if failed == 0 and #granted == 0 then
                    notify_feed("czx_bank_full")
                end
                break
            end
            local charge = math.floor((e.cost or 0)
                * ((e.hp or 100) / 100) * REMUSTER_COST_FACTOR + 0.5)
            if charge > 0 and purse - total_cost < charge then
                failed = failed + 1
                log("skip " .. tostring(e.key) .. ": needs " .. charge
                    .. ", treasury left " .. (purse - total_cost))
            else
                local okg = pcall(function() cm:grant_unit_to_character(char_str, e.key) end)
                local okc1, now = pcall(function() return force:unit_list():num_items() end)
                if okg and okc1 and now and cur and now > cur then
                    granted[#granted + 1] = e
                    total_cost = total_cost + charge
                    bank_remove_ref(bank, e)
                else
                    failed = failed + 1
                    log("grant failed for " .. tostring(e.key) .. " (kept in pool)")
                end
            end
        end
        if total_cost > 0 then
            pcall(function() cm:treasury_mod(fname, -total_cost) end)
        end
        log("remuster granted " .. #granted .. " units, failed " .. failed
            .. ", cost " .. total_cost .. ", pool left " .. bank_count(fname))

        -- 恢复兵力/经验：每 key 跳过发放前就存在的原有单位，只对新发的生效
        if #granted > 0 then
            local want = {}   -- key -> { entry, entry, ... } 待恢复队列
            for _, g in ipairs(granted) do
                want[g.key] = want[g.key] or {}
                table.insert(want[g.key], g)
            end
            local seen = {}
            local restored = 0
            local okn2, n2 = pcall(function() return force:unit_list():num_items() end)
            if okn2 and n2 then
                for j = 0, n2 - 1 do
                    local oku, u = pcall(function() return force:unit_list():item_at(j) end)
                    if oku and u then
                        local okk, key = pcall(function() return u:unit_key() end)
                        if okk and key then
                            seen[key] = (seen[key] or 0) + 1
                            if want[key] and #want[key] > 0
                                and seen[key] > (pre[key] or 0) then
                                local e = table.remove(want[key], 1)
                                if e.rank and e.rank > 0 then
                                    pcall(function() cm:add_experience_to_unit(u, e.rank) end)
                                end
                                if e.hp and e.hp < 100 then
                                    pcall(function()
                                        cm:set_unit_hp_to_unary_of_maximum(u, math.max(0.05, e.hp / 100))
                                    end)
                                end
                                restored = restored + 1
                            end
                        end
                    end
                end
            end
            log("remuster restored hp/rank on " .. restored .. " units")
        end
        return #granted, failed, total_cost
end

-- ---------- 重组：把军备池单位发还选中军队并恢复兵力/经验 ----------
core:add_listener(
    "czx_remuster_army_UITrigger",
    "UITrigger",
    function(context)
        return context:trigger():starts_with("czx_remuster_army|")
    end,
    function(context)
        local trig = context:trigger()
        local char_cqi = tonumber(trig:match("czx_remuster_army|(%d+)"))
        local mf_cqi = tonumber(trig:match("|(%d+)$"))
        log("remuster trigger: " .. tostring(trig) .. " -> char=" .. tostring(char_cqi) .. " mf=" .. tostring(mf_cqi))

        local force, general = resolve_selected_force(char_cqi, mf_cqi)
        if not force then return end
        -- 三国式重组：军备池挂在定居点上——仅驻扎城内的军队可补员，
        -- 野战军一律拒绝（否则任意野战军远程免费补员，绕开征募体系）
        local okgr, is_garrison = pcall(function() return general:has_garrison_residence() end)
        if not (okgr and is_garrison) then
            log("field army, refuse (remuster requires garrisoned army)")
            notify_feed("czx_bank_need_garrison")
            return
        end

        local okfn, fname = pcall(function() return force:faction():name() end)
        local bank = okfn and fname and unit_bank[fname]
        if not bank or #bank == 0 then
            log("remuster: reserve pool empty for " .. tostring(fname))
            notify_feed("czx_bank_empty")
            return
        end

        -- 全量发放：快照全部条目后走共享发放（快照防遍历时删池漂移）
        local todo = {}
        for _, e in ipairs(bank) do todo[#todo + 1] = e end
        grant_bank_entries(force, general, fname, bank, todo)
        if bank_panel_refresh then pcall(bank_panel_refresh, true) end
    end,
    true
)

-- ---------- 勾选发放：czx_remuster_pick|mf_cqi|idx,idx,... ----------
-- 军备池面板确认路径：按勾选下标快照条目对象后走共享发放，
-- 发完直接刷新面板（同 Lua 状态，bank_panel_refresh 可见）。
core:add_listener(
    "czx_remuster_pick_UITrigger",
    "UITrigger",
    function(context)
        return context:trigger():starts_with("czx_remuster_pick|")
    end,
    function(context)
        local trig = context:trigger()
        local mf_cqi = tonumber(trig:match("czx_remuster_pick|(%d+)|"))
        local csv = tostring(trig:match("czx_remuster_pick|%d+|(.+)$") or "")
        log("remuster pick: " .. tostring(trig))

        local force, general = resolve_selected_force(nil, mf_cqi)
        if not force then return end
        local okgr, is_garrison = pcall(function() return general:has_garrison_residence() end)
        if not (okgr and is_garrison) then
            log("field army, refuse (remuster requires garrisoned army)")
            notify_feed("czx_bank_need_garrison")
            return
        end

        local okfn, fname = pcall(function() return force:faction():name() end)
        local bank = okfn and fname and unit_bank[fname]
        if not bank or #bank == 0 then
            log("remuster pick: reserve pool empty for " .. tostring(fname))
            notify_feed("czx_bank_empty")
            return
        end

        -- 先按勾选下标快照条目对象，再发放（发放即删条目，下标必须冻结）；
        -- 条目对象去重——同一下标重复传入不能发两次
        local todo, seen_e = {}, {}
        for n in csv:gmatch("%d+") do
            local i = tonumber(n)
            if i and bank[i] and not seen_e[bank[i]] then
                seen_e[bank[i]] = true
                todo[#todo + 1] = bank[i]
            end
        end
        if #todo == 0 then
            log("remuster pick: no valid picks in " .. csv)
            notify_feed("czx_bank_pick_none")
            return
        end
        local granted_n, failed_n, total_cost =
            grant_bank_entries(force, general, fname, bank, todo)
        log(string.format("remuster pick done: granted %d/%d, failed %d, cost %d",
            granted_n, #todo, failed_n, total_cost))
        if bank_panel_refresh then pcall(bank_panel_refresh, true) end
    end,
    true
)
