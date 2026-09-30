-- aifaction_name.lua 遮蔽修复版（zzz_czx_treasury_guard）
-- 原版来自 !ai_treasury.pack：在每个 AI 派系的 FactionTurnStart 派发内联期
-- 对 ai_turns 覆盖层裸做 SetVisible/SetStateText/SetState×5——每轮 ~700 次
-- 原生 UI 写。派发内联期组件树可能半建/半拆，写落释放页即
-- Warhammer3.exe+0x22c8774（mov [rax+0x351],bl 写型 UAF）崩溃族。
-- 修复：① 写操作整体延迟出事件派发；② 逐级 nil 校验，组件缺失弃本轮；
-- ③ ui_locked 持锁期直接跳过。功能不变：仍显示"AI 回合中：xx派系"。
local function aifaction_name()

	core:add_listener(
		"ai_FactionTurnStart",
		"FactionTurnStart",
		function(context)
			return context:faction():is_human() == false
		end,
		function(context)
			local faction_name = context:faction():name()
			cm:callback(function()
				local uim = cm:get_campaign_ui_manager()
				if not uim or uim.ui_locked then return end
				local holder = find_uicomponent(core:get_ui_root(), "ai_turns", "main_holder")
				if not holder then return end
				local name = find_uicomponent(holder, "dy_name")
				if not name then return end
				local loc_faction = common.get_localised_string("factions_screen_name_" .. faction_name)
				name:SetVisible(true)
				name:SetStateText(loc_faction)
				for i = 0, 4 do
					local flag = find_uicomponent(holder, "flags", "flag_" .. i)
					if flag then
						flag:SetState("normal")
					end
				end
			end, 0.1, "czx_tg_ai_name")
		end,
	true);

end;
cm:add_first_tick_callback(function() aifaction_name() end);
