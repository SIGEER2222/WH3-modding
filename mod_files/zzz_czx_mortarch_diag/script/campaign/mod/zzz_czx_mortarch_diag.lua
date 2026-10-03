-- zzz_czx_mortarch_diag
-- DLC29 死亡统帅（Mortarch）面板诊断 + 强制收服按钮。
-- 背景：原版按钮可见性绑定 (twui ContextVisibilitySetter) 要求
--   IsComplete == false && ExNagashConfederationRitual_IsOwnedByOtherPlayer == false
--   && (IsContextValid(mission) && mission.IsCancelled == false)
-- 任一不满足按钮整体消失（灰→消失的差别在此）。本补丁：
--   1) 面板打开时输出每条仪式三个开关的真实值（定位是哪一条挡住）；
--   2) footer 注入「强制收服」按钮：吞并型走引擎 Perform，失败回退
--      cm:force_confederation；生成型走 spawn_character 等价路径不可行时提示。

local TAG = "[czx_mortarch_diag] ";
local NAGASH = "wh3_dlc29_nag_host_of_nagash";

-- 吞并型仪式 → 目标派系（源：wh3_dlc29_nag_mortarchs.lua initial_missions）
local TARGETS = {
	wh3_dlc29_nag_mortarchs_arkhan = "wh2_dlc09_tmb_followers_of_nagash",
	wh3_dlc29_nag_mortarchs_luthor = "wh2_dlc11_cst_vampire_coast",
	wh3_dlc29_nag_mortarchs_mannfred = "wh_main_vmp_vampire_counts",
	wh3_dlc29_nag_mortarchs_neferata = "wh3_dlc29_vmp_neferata",
	wh3_dlc29_nag_mortarchs_vlad = "wh_main_vmp_schwartzhafen",
};

local selected = "";
local panel_open = false;

local function log(m)
	pcall(out, TAG .. tostring(m));
end;

core:add_listener(
	"czx_md_card_click",
	"ComponentLClickUp",
	function(context)
		return context.string:starts_with("CcoCampaignRitual2wh3_dlc29_nag_mortarchs");
	end,
	function(context)
		selected = context.string:gsub("CcoCampaignRitual2", "");
		log("selected ritual: " .. selected);
	end,
	true
);

local function probe_rituals()
	for key in pairs(TARGETS) do
		local ok, r = pcall(function()
			local c = cco("CcoCampaignRitual", key);
			return "CanPerform=" .. tostring(c:Call("CanPerformRitual"))
				.. " IsComplete=" .. tostring(c:Call("IsComplete"))
				.. " OwnedByOtherPlayer=" .. tostring(c:Call("ExNagashConfederationRitual_IsOwnedByOtherPlayer"));
		end);
		log(key .. ": " .. (ok and r or "cco fail: " .. tostring(r)));
	end;
	local okm, m = pcall(function()
		return cco("CcoCampaignFaction", NAGASH):Call("MissionList.JoinString(Key, ', ')");
	end);
	log("faction MissionList: " .. (okm and tostring(m) or "fail: " .. tostring(m)));
end;

local function inject_button(panel)
	local footer = find_uicomponent(panel, "mortarchs", "footer");
	if not footer then
		log("footer not found");
		return;
	end;
	if find_uicomponent(footer, "czx_force_subjugate") then return end;
	local btn = UIComponent(footer:CreateComponent("czx_force_subjugate", "ui/templates/square_medium_button.twui.xml"));
	btn:SetImagePath("ui/skins/default/icon_item_set.png");
	btn:SetTooltipText("诊断：输出仪式状态\n点击=强制收服当前选中的死亡统帅（吞并型走引擎 Perform，失败回退 force_confederation）", true);
	core:add_listener(
		"czx_md_force_click",
		"ComponentLClickUp",
		function(context)
			return panel_open and context.string == "czx_force_subjugate";
		end,
		function()
			log("force clicked, selected=" .. tostring(selected));
			if selected == "" then
				log("no ritual card selected — 先点选一张死亡统帅头像");
				return;
			end;
			local tf = TARGETS[selected];
			if tf then
				local ok, err = pcall(function()
					cco("CcoCampaignRitual", selected):Call("Perform");
				end);
				log("Perform " .. selected .. ": ok=" .. tostring(ok) .. " " .. tostring(err));
				if not ok then
					local ok2, err2 = pcall(cm.force_confederation, cm, NAGASH, tf);
					log("fallback force_confederation " .. tf .. ": ok=" .. tostring(ok2) .. " " .. tostring(err2));
				end;
			else
				log(selected .. " 为生成型仪式，无吞并目标；尝试 Perform");
				local ok, err = pcall(function()
					cco("CcoCampaignRitual", selected):Call("Perform");
				end);
				log("Perform " .. selected .. ": ok=" .. tostring(ok) .. " " .. tostring(err));
			end;
		end,
		true
	);
	log("force button injected");
end;

core:add_listener(
	"czx_md_panel_open",
	"PanelOpenedCampaign",
	function(context)
		return context.string == "dlc29_nag_mortarchs";
	end,
	function(context)
		panel_open = true;
		cm:callback(function()
			local ok, panel = pcall(function()
				return core:get_or_create_component("dlc29_nag_mortarchs", "ui/campaign ui/dlc29_nag_mortarchs.twui.xml");
			end);
			if ok and panel then
				inject_button(UIComponent(panel));
			else
				log("panel component fail: " .. tostring(panel));
			end;
			probe_rituals();
		end, 1);
	end,
	true
);

core:add_listener(
	"czx_md_panel_close",
	"PanelClosedCampaign",
	function(context)
		return context.string == "dlc29_nag_mortarchs";
	end,
	function()
		panel_open = false;
	end,
	true
);

log("loaded; panel-open diagnostics armed");
