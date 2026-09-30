-- zzz_czx_choujiang_button_fix.lua
-- 兜底：若 wyc_choujiang 的 first-tick 回调因任何原因没建成抽奖按钮，
-- 在加载屏关闭后重试创建（get_or_create_component 幂等，不会重复建）。

local TAG = "[czx_choujiang_fix] ";
local TEMPLATE = "ui/templates/wyc_hud_button.twui.xml";

local function ensure_choujiang(origin)
    local result, created_or_err = pcall(function()
        local parent = find_uicomponent(
            core:get_ui_root(), "hud_campaign", "faction_buttons_docker", "button_group_management");
        if not parent then
            return "parent_missing";
        end;
        if find_uicomponent(parent, "choujiang") then
            return "exists";
        end;
        core:get_or_create_component("choujiang", TEMPLATE, parent);
        return "created";
    end);
    if result then
        out(TAG .. origin .. ": " .. tostring(created_or_err));
        return created_or_err;
    end;
    out(TAG .. origin .. ": error " .. tostring(created_or_err));
    return "error";
end;

local attempts = 0;
local function retry()
    attempts = attempts + 1;
    local r = ensure_choujiang("retry#" .. attempts);
    if r == "created" or r == "exists" then
        return;
    end;
    if attempts < 30 then
        cm:callback(retry, 2.0);
    else
        out(TAG .. "gave up after " .. attempts .. " attempts");
    end;
end;

core:progress_on_loading_screen_dismissed(function()
    ensure_choujiang("loading_dismissed");
    cm:callback(retry, 3.0);
end);
