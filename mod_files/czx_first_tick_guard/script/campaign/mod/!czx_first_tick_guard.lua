-- czx_first_tick_guard.lua
-- 9.0 修复：vanilla call_each() 逐个同步调用 first-tick 回调且不做错误隔离，
-- 任何一个回调抛错都会让同列表后续回调全部跳过（2026-10-01 实测：
-- wyc_choujiang 抽奖按钮、wyccc_starting_characters 开局英雄、
-- wyccc_base_incident_queue、PSW 系等所有 shared 回调整批沉默丢失，
-- 且 script_log 无任何 SCRIPT ERROR）。
-- 本补丁替换 campaign_manager.process_first_tick_callbacks / ui_created：
-- 每个回调单独 xpcall，失败时打印来源文件与行号，其余回调继续执行。

local TAG = "[czx_ft_guard] ";

local function callback_source(cb)
    local g = rawget(_G, "CZX_LUA_GUARD");
    local mapped = g and g._src_map and g._src_map[cb];
    if mapped then return mapped end;
    local info = debug and debug.getinfo and debug.getinfo(cb, "S");
    if info then
        return tostring(info.short_src or info.source) .. ":" .. tostring(info.linedefined or 0);
    end;
    return "?";
end;

-- 2026-10-02 二分支持：CZX_SKIP_PAT（逗号分隔 short_src 子串）命中即跳过；
-- CZX_GUARD_TRACE 为真时逐回调 out() 来源（定位崩前最后一个回调）。
local SKIP = {};
local function load_skip()
    local raw = rawget(_G, "CZX_SKIP_PAT");
    if type(raw) == "string" then
        for pat in string.gmatch(raw, "[^,]+") do
            SKIP[#SKIP + 1] = pat;
        end;
    end;
end;
local TRACE = rawget(_G, "CZX_GUARD_TRACE") ~= false;

local function should_skip(src)
    for _, pat in ipairs(SKIP) do
        if string.find(src, pat, 1, true) then
            return true;
        end;
    end;
    return false;
end;

local function guarded_call_each(list, list_name, context)
    if type(list) ~= "table" then
        out(TAG .. "list " .. list_name .. " is " .. type(list) .. ", skipped");
        return;
    end;
    load_skip();
    local total = #list;
    local done = 0;
    for i = 1, total do
        local cb = list[i];
        if type(cb) == "function" then
            local src = callback_source(cb);
            if should_skip(src) then
                out(TAG .. list_name .. "[" .. i .. "/" .. total .. "] SKIPPED " .. src);
            else
                if TRACE then
                    out(TAG .. list_name .. "[" .. i .. "/" .. total .. "] run <- " .. src);
                end;
                local ok, err = xpcall(
                    function()
                        cb(context);
                    end,
                    function(e)
                        return tostring(e) .. "\n" .. tostring(debug.traceback("", 2));
                    end
                );
                if ok then
                    done = done + 1;
                else
                    out(TAG .. list_name .. "[" .. i .. "/" .. total .. "] " .. src .. " threw: " .. tostring(err));
                end;
            end;
        else
            out(TAG .. list_name .. "[" .. i .. "/" .. total .. "] is " .. type(cb) .. ", skipped");
        end;
    end;
    out(TAG .. list_name .. " done: " .. done .. "/" .. total .. " callbacks ran");
end;

local function guarded_process_first_tick_callbacks(self, context)
    out(TAG .. "processing first-tick callbacks with isolation");
    guarded_call_each(self.pre_first_tick_callbacks, "pre", context);
    if self:is_multiplayer() then
        if self:is_new_game() then
            guarded_call_each(self.first_tick_callbacks_mp_new, "mp_new", context);
        end;
        guarded_call_each(self.first_tick_callbacks_mp_each, "mp_each", context);
    else
        if self:is_new_game() then
            guarded_call_each(self.first_tick_callbacks_sp_new, "sp_new", context);
        end;
        guarded_call_each(self.first_tick_callbacks_sp_each, "sp_each", context);
    end;
    guarded_call_each(self.first_tick_callbacks, "shared", context);
    guarded_call_each(self.post_first_tick_callbacks, "post", context);
    out(TAG .. "all first-tick callback lists processed");
end;

local function guarded_ui_created(self, context)
    self.is_processing_ui_created_callbacks = true;
    guarded_call_each(self.ui_created_callbacks, "ui_created", context);
    if self:is_multiplayer() then
        if self:is_new_game() then
            guarded_call_each(self.ui_created_callbacks_mp_new, "ui_mp_new", context);
        end;
        guarded_call_each(self.ui_created_callbacks_mp_each, "ui_mp_each", context);
    else
        if self:is_new_game() then
            guarded_call_each(self.ui_created_callbacks_sp_new, "ui_sp_new", context);
        end;
        guarded_call_each(self.ui_created_callbacks_sp_each, "ui_sp_each", context);
    end;
    self.is_processing_ui_created_callbacks = false;
end;

if type(campaign_manager) == "table" then
    campaign_manager.process_first_tick_callbacks = guarded_process_first_tick_callbacks;
    campaign_manager.ui_created = guarded_ui_created;
    out(TAG .. "process_first_tick_callbacks + ui_created wrapped");
else
    out(TAG .. "WARNING: campaign_manager class not found at load time; patch inactive");
end;
