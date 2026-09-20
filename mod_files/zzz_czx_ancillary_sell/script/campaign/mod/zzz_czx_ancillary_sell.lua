---------------------------------------------------------------------------------------------------
-- zzz_czx_ancillary_sell.lua
-- Patch for !ancillary_panel.pack (xyz_ancillary_panel): adds sell-selected / sell-all-owned
-- buttons and an "owned only" filter toggle to the ancillary panel.
-- NOTE: script/campaign/mod/*.lua load in alphabetical filename order (observed in script_log:
-- czx_*.lua at 6.6s, xyz_ancillary_panel.lua at 8.7s), NOT in playset order. This file must sort
-- AFTER xyz_ancillary_panel.lua so the panel exists when our first-tick callback runs; a retry
-- loop covers the remaining edge cases. MP-safe: mutations go through UITrigger script events.
---------------------------------------------------------------------------------------------------

local SELL_RATIO = 0.3 -- fraction of panel buy price returned when selling
local SELL_MAX_SCORE = 199 -- uniqueness_score >= 199 (crafted/unique-legendary) is never sellable

local sell_one_txt = common.get_localised_string("czx_ancillary_sell_one")
local sell_all_txt = common.get_localised_string("czx_ancillary_sell_all")
local sell_checked_txt = common.get_localised_string("czx_ancillary_sell_checked")
local sell_check_tip_txt = common.get_localised_string("czx_ancillary_sell_check")
local sell_gain_txt = common.get_localised_string("czx_ancillary_sell_gain")
local sell_equipped_txt = common.get_localised_string("czx_ancillary_sell_equipped")
local sell_not_owned_txt = common.get_localised_string("czx_ancillary_sell_not_owned")
local sell_protected_txt = common.get_localised_string("czx_ancillary_sell_protected")
local sell_result_txt = common.get_localised_string("czx_ancillary_sell_result")
local owned_on_txt = common.get_localised_string("czx_ancillary_sell_owned_on")
local owned_off_txt = common.get_localised_string("czx_ancillary_sell_owned_off")

local language = common.get_context_value("LocLanguage")
if language == "CN" or language == "ZH" then
    sell_one_txt = "出售选中装备（双击列表中的装备可直接出售）"
    sell_all_txt = "一键出售当前筛选中未装备的物品（不含传奇/锻造）"
    sell_checked_txt = "出售所有勾选的装备"
    sell_check_tip_txt = "勾选，用于批量出售"
    sell_gain_txt = "出售可获得[[img:icon_treasury]][[/img]]"
    sell_equipped_txt = "该装备正被人物使用，无法出售"
    sell_not_owned_txt = "尚未拥有该装备"
    sell_protected_txt = "传奇/锻造装备不可出售"
    sell_result_txt = "已出售 %d 件装备，获得[[img:icon_treasury]][[/img]]%d"
    owned_on_txt = "只显示已拥有装备（可与类别/稀有度/搜索叠加）"
    owned_off_txt = "显示全部装备图鉴"
end

-- price model: same as the panel's cost_calculation, scaled by SELL_RATIO
local function sell_price(ancillary_cco)
    if not ancillary_cco then return 0 end
    local score = ancillary_cco:Call("UniquenessScore")
    if score < 20 then score = 20 end
    local basic = score * 50
    local extra = 0
    local size = ancillary_cco:Call("EffectList.Size")
    for i = 0, size - 1 do
        local effect_cco = ancillary_cco:Call("EffectList.At(" .. i .. ")")
        local effect_key = effect_cco:Call("EffectKey")
        if effect_cco:Call("IsPositive") then
            local value = math.abs(effect_cco:Call("Value"))
            if string.find(effect_key, "ward_save") then extra = extra + 500 * value
            elseif string.find(effect_key, "physical_resistance") then extra = extra + 250 * value
            elseif string.find(effect_key, "missile_resistance") then extra = extra + 250 * value
            elseif string.find(effect_key, "fire_resistance") then extra = extra + 50 * value
            elseif string.find(effect_key, "magic_resistance") then extra = extra + 50 * value
            elseif string.find(effect_key, "melee_attack") then extra = extra + 100 * value
            elseif string.find(effect_key, "melee_defence") then extra = extra + 100 * value
            elseif string.find(effect_key, "stat_ap") then extra = extra + 50 * value
            elseif string.find(effect_key, "stat_weapon") then extra = extra + 100 * value
            elseif string.find(effect_key, "stat_armour") then extra = extra + 100 * value
            elseif string.find(effect_key, "missile_damage") then extra = extra + 50 * value
            elseif string.find(effect_key, "growth_characters") then extra = extra + 50 * value
            elseif string.find(effect_key, "research_points") then extra = extra + 250 * value
            elseif string.find(effect_key, "upkeep") then extra = extra + 250 * value
            elseif string.find(effect_key, "cost") then extra = extra + 250 * value
            elseif string.find(effect_key, "gdp_mod") then extra = extra + 250 * value
            elseif string.find(effect_key, "tariff_mod") then extra = extra + 150 * value
            elseif string.find(effect_key, "movement_range") then extra = extra + 150 * value
            elseif string.find(effect_key, "winds_of_magic") then extra = extra + 150 * value
            elseif string.find(effect_key, "public_order") then extra = extra + 200 * value
            elseif string.find(effect_key, "replenishment") then extra = extra + 400 * value
            elseif string.find(effect_key, "experience_mod") then extra = extra + 100 * value
            elseif string.find(effect_key, "unit_xp") then extra = extra + 500 * value
            elseif string.find(effect_key, "cooldown") then extra = extra + 400 * value
            elseif string.find(effect_key, "wom_cost") then extra = extra + 500 * value
            elseif string.find(effect_key, "battle_loot") then extra = extra + 50 * value
            elseif string.find(effect_key, "ancillary_steal") then extra = extra + 50 * value
            elseif string.find(effect_key, "magic_attacks") then extra = extra + 3000
            elseif string.find(effect_key, "frenzy") then extra = extra + 3000
            elseif string.find(effect_key, "regeneration") then extra = extra + 4000
            elseif string.find(effect_key, "unbreakable") then extra = extra + 5000
            elseif string.find(effect_key, "enable") then extra = extra + 1000
            else extra = extra + 500 end
        else
            extra = extra - 500
        end
    end
    return math.floor((basic + extra) * SELL_RATIO)
end

-- owned ancillary keys -> "key1, key2, ..., " whitelist string for the panel's xx_sets context
-- (the list binding does StringContains(xx_sets, Key + ", "); "__czx_none__" matches nothing)
local function owned_keys_string(faction_name)
    local ok, s = pcall(function()
        return cco("CcoCampaignFaction", faction_name)
            :Call("AncillaryList.JoinString(AncillaryRecordContext.Key, ', ')")
    end)
    if ok and type(s) == "string" then
        if s == "" then return "__czx_none__" end
        return s .. ", "
    end
    local ok2, list = pcall(function()
        return cco("CcoCampaignFaction", faction_name):Call("AncillaryList")
    end)
    if ok2 and type(list) == "table" then
        local keys = {}
        for i = 1, #list do
            local ok3, k = pcall(function()
                return list[i]:Call("AncillaryRecordContext.Key")
            end)
            if ok3 and type(k) == "string" then keys[#keys + 1] = k end
        end
        if #keys > 0 then return table.concat(keys, ", ") .. ", " end
    end
    return "__czx_none__"
end

local function attach(ancillary_panel)
    local ancillary_detail = find_uicomponent(ancillary_panel, "ancillary_detail")
    local list_box = find_uicomponent(ancillary_panel, "list", "list_clip", "list_box")
    local button_list = find_uicomponent(ancillary_panel, "button_list")
    if not ancillary_detail or not list_box or not button_list then return false end

    local selected_key = ""
    local last_written_sets = nil
    local checked = {}
    local last_click_key = ""
    local dbl_ticks = 0

    local function is_equipped(key)
        local ok, list = pcall(function()
            return cm:model():world():characters_owning_ancillary(key)
        end)
        return ok and list and list:num_items() > 0
    end

    local function is_protected(key)
        local ok, score = pcall(function()
            return cco("CcoAncillaryRecord", key):Call("UniquenessScore")
        end)
        return (ok and score and score >= SELL_MAX_SCORE) or false
    end

    local function can_sell(key, faction)
        return faction and faction:ancillary_exists(key) and not is_equipped(key) and not is_protected(key)
    end

    -- only items currently visible in the panel list (respects its category/rarity/search filters)
    local function owned_unequipped_keys()
        local keys = {}
        local faction = cm:get_local_faction(true)
        if not faction or not list_box then return keys end
        for i = 0, list_box:ChildCount() - 1 do
            local child = UIComponent(list_box:Find(i))
            local id = child:Id()
            if id:starts_with("CcoAncillaryRecord") and child:Visible() then
                local key = id:gsub("CcoAncillaryRecord", "")
                if key ~= "" and can_sell(key, faction) then
                    keys[#keys + 1] = key
                end
            end
        end
        return keys
    end

    -- sell buttons: bottom-right INSIDE ancillary_detail, left of the panel's buy button
    -- (xx_button_add_ancillary sits at point 9 offset +6; positive X goes OUT of the panel,
    -- so ours use negative offsets to stay visible inside the box)
    local btn_sell_one = UIComponent(ancillary_detail:CreateComponent("czx_button_sell_one", "ui/templates/square_medium_button.twui.xml"))
    btn_sell_one:SetCanResizeWidth(true)
    btn_sell_one:SetCanResizeHeight(true)
    btn_sell_one:Resize(40, 40)
    btn_sell_one:SetDockingPoint(9)
    btn_sell_one:SetDockOffset(-48, 0)
    btn_sell_one:SetImagePath("ui/skins/default/icon_income.png")
    btn_sell_one:SetState("inactive")
    btn_sell_one:SetTooltipText(sell_one_txt, true)

    -- sell checked
    local btn_sell_checked = UIComponent(ancillary_detail:CreateComponent("czx_button_sell_checked", "ui/templates/square_medium_button.twui.xml"))
    btn_sell_checked:SetCanResizeWidth(true)
    btn_sell_checked:SetCanResizeHeight(true)
    btn_sell_checked:Resize(40, 40)
    btn_sell_checked:SetDockingPoint(9)
    btn_sell_checked:SetDockOffset(-98, 0)
    btn_sell_checked:SetImagePath("ui/skins/default/icon_income_plus.png")
    btn_sell_checked:SetState("inactive")
    btn_sell_checked:SetTooltipText(sell_checked_txt, true)

    -- sell all owned (unequipped)
    local btn_sell_all = UIComponent(ancillary_detail:CreateComponent("czx_button_sell_all", "ui/templates/square_medium_button.twui.xml"))
    btn_sell_all:SetCanResizeWidth(true)
    btn_sell_all:SetCanResizeHeight(true)
    btn_sell_all:Resize(40, 40)
    btn_sell_all:SetDockingPoint(9)
    btn_sell_all:SetDockOffset(-148, 0)
    btn_sell_all:SetImagePath("ui/skins/default/icon_treasury.png")
    btn_sell_all:SetTooltipText(sell_all_txt, true)

    -- owned-only filter toggle: hijacks the list binding's xx_sets key whitelist
    local btn_owned = UIComponent(button_list:CreateComponent("czx_button_owned", "ui/templates/square_medium_button_toggle.twui.xml"))
    btn_owned:SetCanResizeWidth(true)
    btn_owned:SetCanResizeHeight(true)
    btn_owned:Resize(48, 48)
    btn_owned:SetImagePath("ui/skins/default/icon_item_set.png")
    btn_owned:SetTooltipText(owned_on_txt, true)

    local function refresh_sell_one()
        local faction = cm:get_local_faction(true)
        if selected_key == "" or not faction or not faction:ancillary_exists(selected_key) then
            btn_sell_one:SetState("inactive")
            btn_sell_one:SetTooltipText(sell_not_owned_txt, true)
            return
        end
        if is_equipped(selected_key) then
            btn_sell_one:SetState("inactive")
            btn_sell_one:SetTooltipText(sell_equipped_txt, true)
            return
        end
        if is_protected(selected_key) then
            btn_sell_one:SetState("inactive")
            btn_sell_one:SetTooltipText(sell_protected_txt, true)
            return
        end
        local price = sell_price(cco("CcoAncillaryRecord", selected_key))
        btn_sell_one:SetState("active")
        btn_sell_one:SetTooltipText(sell_one_txt .. "\n" .. sell_gain_txt .. price, true)
    end

    local function refresh_sell_checked()
        local faction = cm:get_local_faction(true)
        local n, total = 0, 0
        for key in pairs(checked) do
            if can_sell(key, faction) then
                n = n + 1
                total = total + sell_price(cco("CcoAncillaryRecord", key))
            end
        end
        if n == 0 then
            btn_sell_checked:SetState("inactive")
            btn_sell_checked:SetTooltipText(sell_checked_txt, true)
        else
            btn_sell_checked:SetState("active")
            btn_sell_checked:SetTooltipText(sell_checked_txt .. "\n" .. n .. " x " .. sell_gain_txt .. total, true)
        end
    end

    -- double-click window + per-row checkbox maintenance: rows are created/destroyed by the
    -- panel's own list binding, so a lightweight tick attaches a checkbox to any new row and
    -- keeps check states in sync with the `checked` set
    real_timer.register_repeating("czx_sell_ui_tick", 150)
    core:add_listener(
        "czx_sell_ui_tick",
        "RealTimeTrigger",
        function(context)
            return context.string == "czx_sell_ui_tick"
        end,
        function(context)
            if not ancillary_panel:Visible() then return end
            if dbl_ticks > 0 then
                dbl_ticks = dbl_ticks - 1
                if dbl_ticks == 0 then last_click_key = "" end
            end
            for i = 0, list_box:ChildCount() - 1 do
                local child = UIComponent(list_box:Find(i))
                local id = child:Id()
                if id:starts_with("CcoAncillaryRecord") then
                    local chk = find_uicomponent(child, "czx_checkbox")
                    if not chk then
                        chk = UIComponent(child:CreateComponent("czx_checkbox", "ui/templates/square_medium_button_toggle.twui.xml"))
                        chk:SetCanResizeWidth(true)
                        chk:SetCanResizeHeight(true)
                        chk:Resize(20, 20)
                        chk:SetDockingPoint(3)
                        chk:SetDockOffset(-4, 4)
                        chk:SetImagePath("ui/skins/default/icon_check.png")
                        chk:SetTooltipText(sell_check_tip_txt, true)
                    end
                    local key = id:gsub("CcoAncillaryRecord", "")
                    local want_selected = checked[key] == true
                    if chk:CurrentState():starts_with("selected") ~= want_selected then
                        chk:SetState(want_selected and "selected" or "active")
                    end
                end
            end
        end,
        true
    )

    -- row checkbox toggle: all row checkboxes share the id "czx_checkbox" (each scoped to its
    -- own parent row); the clicked component's parent gives the ancillary key
    core:add_listener(
        "czx_sell_check_click",
        "ComponentLClickUp",
        function(context)
            return context.string == "czx_checkbox" and ancillary_panel:Visible()
        end,
        function(context)
            local chk = UIComponent(context.component)
            local row = UIComponent(chk:Parent())
            local key = row:Id():gsub("CcoAncillaryRecord", "")
            if key == "" then return end
            if checked[key] then
                checked[key] = nil
                chk:SetState("active")
            else
                checked[key] = true
                chk:SetState("selected")
            end
            refresh_sell_checked()
        end,
        true
    )

    core:add_listener(
        "czx_sell_checked_click",
        "ComponentLClickUp",
        function(context)
            return context.string == "czx_button_sell_checked" and ancillary_panel:Visible()
        end,
        function(context)
            local faction = cm:get_local_faction(true)
            if not faction then return end
            local keys = {}
            for key in pairs(checked) do
                if can_sell(key, faction) then keys[#keys + 1] = key end
            end
            checked = {}
            local cqi = faction:command_queue_index()
            for _, key in ipairs(keys) do
                CampaignUI.TriggerCampaignScriptEvent(cqi, "czx_sell_item:" .. key)
            end
            local total = 0
            for _, key in ipairs(keys) do
                total = total + sell_price(cco("CcoAncillaryRecord", key))
            end
            btn_sell_checked:SetState("inactive")
            btn_sell_checked:SetTooltipText(string.format(sell_result_txt, #keys, total), true)
            out(">>> czx_sell >>> selling " .. #keys .. " checked items for " .. total)
        end,
        true
    )

    -- keep the xx_sets whitelist enforced while the owned toggle is on; the panel's own
    -- reset buttons write "all" (we rewrite ours), and search_set writes a real set
    -- whitelist (we yield via the click hook below + this fallback check)
    real_timer.register_repeating("czx_owned_filter_tick", 250)
    core:add_listener(
        "czx_owned_filter_tick",
        "RealTimeTrigger",
        function(context)
            return context.string == "czx_owned_filter_tick"
        end,
        function(context)
            if not ancillary_panel:Visible() then return end
            if not btn_owned:CurrentState():starts_with("selected") then return end
            local faction = cm:get_local_faction(true)
            if not faction then return end
            local s = owned_keys_string(faction:name())
            local cur = common.get_context_value("xx_sets")
            if type(cur) ~= "string" or cur == s then return end
            if cur == "all" or cur == last_written_sets then
                last_written_sets = s
                common.set_context_value("xx_sets", s)
            else
                btn_owned:SetState("active")
                btn_owned:SetTooltipText(owned_on_txt, true)
            end
        end,
        true
    )

    -- the detail panel's "search this set" button writes its own xx_sets whitelist:
    -- yield to it by switching our toggle off (its listener runs before ours since xyz
    -- registered first, so their xx_sets write is already in place)
    core:add_listener(
        "czx_owned_yield_search_set",
        "ComponentLClickUp",
        function(context)
            return context.string == "search_set" and ancillary_panel:Visible()
        end,
        function(context)
            if btn_owned:CurrentState():starts_with("selected") then
                btn_owned:SetState("active")
                btn_owned:SetTooltipText(owned_on_txt, true)
                last_written_sets = nil
            end
        end,
        true
    )

    core:add_listener(
        "czx_owned_toggle",
        "ComponentLClickUp",
        function(context)
            return context.string == "czx_button_owned" and ancillary_panel:Visible()
        end,
        function(context)
            if btn_owned:CurrentState():starts_with("selected") then
                local faction = cm:get_local_faction(true)
                if faction then
                    local s = owned_keys_string(faction:name())
                    last_written_sets = s
                    common.set_context_value("xx_sets", s)
                end
                btn_owned:SetTooltipText(owned_off_txt, true)
            else
                last_written_sets = nil
                common.set_context_value("xx_sets", "all")
                btn_owned:SetTooltipText(owned_on_txt, true)
            end
        end,
        true
    )

    -- track selection (same event the panel listens to); a second click on the same row within
    -- the window armed by dbl_ticks sells it directly (server re-validates)
    core:add_listener(
        "czx_sell_track_select",
        "ComponentLClickUp",
        function(context)
            return context.string:starts_with("CcoAncillaryRecord") and ancillary_panel:Visible()
        end,
        function(context)
            local key = context.string:gsub("CcoAncillaryRecord", "")
            local faction = cm:get_local_faction(true)
            if key == last_click_key and dbl_ticks > 0 and can_sell(key, faction) then
                CampaignUI.TriggerCampaignScriptEvent(faction:command_queue_index(), "czx_sell_item:" .. key)
                last_click_key = ""
                dbl_ticks = 0
                checked[key] = nil
            else
                last_click_key = key
                dbl_ticks = 4 -- ~600ms double-click window at the 150ms ui tick
            end
            selected_key = key
            refresh_sell_one()
        end,
        true
    )

    core:add_listener(
        "czx_sell_one_click",
        "ComponentLClickUp",
        function(context)
            return context.string == "czx_button_sell_one" and ancillary_panel:Visible()
        end,
        function(context)
            local faction = cm:get_local_faction(true)
            if selected_key ~= "" and can_sell(selected_key, faction) then
                CampaignUI.TriggerCampaignScriptEvent(faction:command_queue_index(), "czx_sell_item:" .. selected_key)
                btn_sell_one:SetState("inactive")
            end
        end,
        true
    )

    core:add_listener(
        "czx_sell_all_click",
        "ComponentLClickUp",
        function(context)
            return context.string == "czx_button_sell_all" and ancillary_panel:Visible()
        end,
        function(context)
            local faction = cm:get_local_faction(true)
            if not faction then return end
            local keys = owned_unequipped_keys()
            local cqi = faction:command_queue_index()
            for _, key in ipairs(keys) do
                CampaignUI.TriggerCampaignScriptEvent(cqi, "czx_sell_item:" .. key)
            end
            local total = 0
            for _, key in ipairs(keys) do
                total = total + sell_price(cco("CcoAncillaryRecord", key))
            end
            btn_sell_all:SetTooltipText(string.format(sell_result_txt, #keys, total), true)
            out(">>> czx_sell >>> selling " .. #keys .. " items for " .. total)
        end,
        true
    )
    return true
end

-- the panel is created by xyz_ancillary_panel's own first-tick callback, which may run after
-- ours depending on script filename order; retry until it exists
cm:add_first_tick_callback(function()
    local attempts = 0
    local function try_attach()
        attempts = attempts + 1
        local panel = find_uicomponent(core:get_ui_root(), "ancillary_panel")
        if panel and attach(panel) then
            out(">>> czx_sell >>> sell patch active (attempt " .. attempts .. ")")
            return
        end
        if attempts < 240 then
            cm:callback(try_attach, 0.5)
        else
            out(">>> czx_sell >>> ancillary_panel never appeared, sell patch inactive")
        end
    end
    try_attach()
end)

-- server side: validate + remove + pay
core:add_listener(
    "czx_sell_item_UITrigger",
    "UITrigger",
    function(context)
        return context:trigger():starts_with("czx_sell_item:")
    end,
    function(context)
        local key = context:trigger():gsub("czx_sell_item:", "")
        local faction = cm:model():faction_for_command_queue_index(context:faction_cqi())
        if not faction or not faction:ancillary_exists(key) then return end
        local equipped = cm:model():world():characters_owning_ancillary(key)
        if equipped and equipped:num_items() > 0 then return end -- equipped items are not sellable
        local ok, score = pcall(function()
            return cco("CcoAncillaryRecord", key):Call("UniquenessScore")
        end)
        if ok and score and score >= SELL_MAX_SCORE then return end -- crafted/legendary not sellable
        local price = sell_price(cco("CcoAncillaryRecord", key))
        cm:force_remove_ancillary_from_faction(faction, key)
        cm:treasury_mod(faction:name(), price)
    end,
    true
)
