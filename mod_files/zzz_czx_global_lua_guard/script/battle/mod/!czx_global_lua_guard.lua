local _native_pcall = pcall
local _native_xpcall = xpcall
local G = rawget(_G, "CZX_LUA_GUARD") or {}
if G._battle_installed then return end
G._battle_installed = true
G._counts = G._counts or {}
G._wrapped_methods = G._wrapped_methods or {}

local unpack_fn = unpack or (table and table.unpack)

local function emit(message)
    local ok = _native_pcall(out, "[czx_lua_guard] " .. tostring(message))
    if not ok and type(print) == "function" then
        _native_pcall(print, "[czx_lua_guard] " .. tostring(message))
    end
end

local function error_text(err)
    local message = tostring(err)
    if type(debug) == "table" and type(debug.traceback) == "function" then
        local ok, trace = _native_pcall(debug.traceback, message, 3)
        if ok and trace then return trace end
    end
    return message
end

local function report(tag, err)
    local key = tostring(tag)
    local count = (G._counts[key] or 0) + 1
    G._counts[key] = count
    if count <= 5 or count % 100 == 0 then
        emit(key .. " error #" .. count .. ": " .. tostring(err))
    end
end

function G.is_valid(value, label)
    local key = tostring(label or "value")
    if value == nil or value == false then
        report("invalid:" .. key, "nil/false")
        return false
    end
    local ok_method, null_method = _native_pcall(function()
        return value.is_null_interface
    end)
    if not ok_method then
        report("invalid:" .. key, "cannot inspect is_null_interface")
        return false
    end
    if type(null_method) == "function" then
        local ok_null, is_null = _native_pcall(function()
            return null_method(value)
        end)
        if not ok_null then
            report("invalid:" .. key, "is_null_interface failed")
            return false
        end
        if is_null then
            report("invalid:" .. key, "null interface")
            return false
        end
    end
    return true
end

function G.is_alive(value, label)
    local key = tostring(label or "value")
    if not G.is_valid(value, key) then return false end
    local ok_method, dead_method = _native_pcall(function()
        return value.is_dead
    end)
    if not ok_method then
        report("dead:" .. key, "cannot inspect is_dead")
        return false
    end
    if type(dead_method) == "function" then
        local ok_dead, is_dead = _native_pcall(function()
            return dead_method(value)
        end)
        if not ok_dead then
            report("dead:" .. key, "is_dead failed")
            return false
        end
        if is_dead then
            report("dead:" .. key, "dead interface")
            return false
        end
    end
    return true
end

function G.call(tag, object, method, ...)
    local call_tag = tostring(tag or "call")
    if not G.is_valid(object, call_tag .. ":object") then return false end
    if type(method) ~= "string" then
        report(call_tag, "method is not a string")
        return false
    end
    local ok_method, fn = _native_pcall(function()
        return object[method]
    end)
    if not ok_method or type(fn) ~= "function" then
        report(call_tag, "missing method " .. method)
        return false
    end
    local args = {...}
    local ok, a, b, c, d = _native_xpcall(function()
        return fn(object, unpack_fn(args, 1, #args))
    end, error_text)
    if not ok then
        report(call_tag, a)
        return false
    end
    return true, a, b, c, d
end

function G.add_listener(name, event, condition, callback, persistent)
    local register = G._raw_add_listener
    if not register and core and type(core.add_listener) == "function" then
        register = core.add_listener
    end
    if not register then
        report("add_listener:" .. tostring(name), "core.add_listener unavailable")
        return false
    end
    local safe_condition = condition
    if type(condition) == "function" then
        safe_condition = G.wrap(
            "condition:" .. tostring(event) .. ":" .. tostring(name),
            condition,
            false
        )
    end
    local safe_callback = callback
    if type(callback) == "function" then
        safe_callback = G.wrap(
            "listener:" .. tostring(event) .. ":" .. tostring(name),
            callback
        )
    end
    return register(core, name, event, safe_condition, safe_callback, persistent)
end

function G.run(tag, fn, ...)
    if type(fn) ~= "function" then
        report(tag, "not a function")
        return false
    end
    local args = {...}
    local ok, a, b, c, d = _native_xpcall(function()
        return fn(unpack_fn(args, 1, #args))
    end, error_text)
    if not ok then
        report(tag, a)
        return false
    end
    return true, a, b, c, d
end

function G.wrap(tag, fn, fallback)
    if type(fn) ~= "function" then return fn end
    return function(...)
        local ok, a, b, c, d = G.run(tag, fn, ...)
        if not ok then return fallback end
        return a, b, c, d
    end
end

function G.try_wrap_method(object, method, callback_index, tag)
    if not object or G._wrapped_methods[method] then return false end
    local original
    local read_ok = _native_pcall(function() original = object[method] end)
    if not read_ok or type(original) ~= "function" then return false end
    local replacement = function(self, ...)
        local args = {...}
        local callback = args[callback_index]
        if type(callback) == "function" then
            args[callback_index] = G.wrap(tag, callback)
        end
        return original(self, unpack_fn(args, 1, #args))
    end
    local write_ok = _native_pcall(function() object[method] = replacement end)
    if write_ok then
        G._wrapped_methods[method] = true
        emit("wrapped " .. method)
        return true
    end
    return false
end

if rawget(_G, "CZX_LUA_GUARD_WRAP_LISTENERS") == true
    and core and type(core.add_listener) == "function"
    and not G._core_wrapped then
    local original_add_listener = core.add_listener
    G._raw_add_listener = original_add_listener
    local install_ok = _native_pcall(function()
        core.add_listener = function(self, name, event, condition, callback, persistent)
            return G.add_listener(name, event, condition, callback, persistent)
        end
    end)
    if install_ok then
        G._core_wrapped = true
        emit("wrapped core.add_listener (explicit opt-in)")
    end
else
    emit("core.add_listener auto-wrapper disabled; use CZX_LUA_GUARD.add_listener")
end

-- Keep native callback registration methods untouched. Use G.wrap explicitly
-- at a call site when a callback must be isolated.

-- ===== 2026-10-04 事件分发保护（与 campaign 侧同源修复，战斗 VM 独立生效）=====
-- 战斗环境是独立 Lua VM，共享同一份 script/_lib/lib_core.lua：分发同样默认
-- 走 event_unprotected_callback / monitor_performance 裸调分支。战斗中监听器
-- 回调的 Lua error 同样会穿透引擎派发帧。处理方式与 campaign 侧一致：
-- 实例级 show_performance_report=false + debug.setupvalue 翻转 evt_callback
-- 上值到 event_protected_callback（战斗分支 core:is_campaign()=false，
-- 保护路径只 pcall + script_error，不写战役日志）。不改注册身份/闭包。
if not G._evt_dispatch_protected then
    G._evt_dispatch_protected = true
    local parts = {}
    if type(core) == "table" and type(core.event_callback) == "function" then
        local ok_perf, perf_now = _native_pcall(function()
            core.show_performance_report = false
            return core.show_performance_report
        end)
        if ok_perf and perf_now == false then
            parts[#parts + 1] = "show_performance_report=false"
        end
        -- Plan B（与 campaign 侧同源）：整方法替换 core.event_callback 为逐回调
        -- pcall 的忠实重实现。战斗 VM 独立 core，此处独立生效；保护路径在战斗
        -- 侧只有 pcall + report，不写战役日志/红字。
        local function _protected_event_callback(self, eventname, context)
            local listeners = self.event_listeners[eventname]
            if not listeners then return end
            local callbacks_to_call = {}
            local should_rebuild = false
            for i = 1, #listeners do
                local current_listener = listeners[i]
                local cond_ok = false
                if current_listener.condition == true then
                    cond_ok = true
                else
                    local ok_c, r = _native_pcall(current_listener.condition, context)
                    cond_ok = ok_c and r and true or false
                    if not ok_c then
                        report("dispatch-cond:" .. tostring(eventname), r)
                    end
                end
                if cond_ok then
                    callbacks_to_call[#callbacks_to_call + 1] = current_listener
                    if not current_listener.persistent then
                        current_listener.to_remove = true
                        should_rebuild = true
                    end
                end
            end
            if should_rebuild then
                local new_listeners = {}
                for i = 1, #listeners do
                    if not listeners[i].to_remove then
                        new_listeners[#new_listeners + 1] = listeners[i]
                    end
                end
                self.event_listeners[eventname] = new_listeners
            end
            for i = 1, #callbacks_to_call do
                local ok_cb, err = _native_pcall(callbacks_to_call[i].callback, context)
                if not ok_cb then
                    report("dispatch:" .. tostring(eventname), err)
                end
            end
        end
        local ok_w1 = _native_pcall(function() core.event_callback = _protected_event_callback end)
        local ok_w2 = false
        if type(core_object) == "table" then
            ok_w2 = _native_pcall(function() core_object.event_callback = _protected_event_callback end)
        end
        local ok_ver, now_fn = _native_pcall(function() return core.event_callback end)
        if ok_w1 and ok_ver and now_fn == _protected_event_callback then
            parts[#parts + 1] = "event_callback->protected-reimpl (instance"
                .. (ok_w2 and "+class" or "") .. ")"
        end
    end
    if #parts >= 2 then
        emit("event dispatch PROTECTED (unprotected-dispatch UAF fix): "
            .. table.concat(parts, ", "))
    else
        emit("WARNING: dispatch protection incomplete (" .. table.concat(parts, ", ")
            .. "); Lua errors may still unwind through the engine event frame")
    end
end

_G.CZX_LUA_GUARD = G
emit("battle guard installed; native engine faults are outside Lua catch scope")
