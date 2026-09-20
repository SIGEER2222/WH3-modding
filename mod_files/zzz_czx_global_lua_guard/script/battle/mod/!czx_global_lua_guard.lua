local G = rawget(_G, "CZX_LUA_GUARD") or {}
if G._battle_installed then return end
G._battle_installed = true
G._counts = G._counts or {}
G._wrapped_methods = G._wrapped_methods or {}

local unpack_fn = unpack or (table and table.unpack)

local function emit(message)
    if type(out) == "function" then
        pcall(out, "[czx_lua_guard] " .. tostring(message))
    end
end

local function error_text(err)
    local message = tostring(err)
    if type(debug) == "table" and type(debug.traceback) == "function" then
        local ok, trace = pcall(debug.traceback, message, 3)
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

function G.run(tag, fn, ...)
    if type(fn) ~= "function" then
        report(tag, "not a function")
        return false
    end
    local args = {...}
    local ok, a, b, c, d = xpcall(function()
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
    local read_ok = pcall(function() original = object[method] end)
    if not read_ok or type(original) ~= "function" then return false end
    local replacement = function(self, ...)
        local args = {...}
        local callback = args[callback_index]
        if type(callback) == "function" then
            args[callback_index] = G.wrap(tag, callback)
        end
        return original(self, unpack_fn(args, 1, #args))
    end
    local write_ok = pcall(function() object[method] = replacement end)
    if write_ok then
        G._wrapped_methods[method] = true
        emit("wrapped " .. method)
        return true
    end
    return false
end

if core and type(core.add_listener) == "function" and not G._core_wrapped then
    local original_add_listener = core.add_listener
    local install_ok = pcall(function()
        core.add_listener = function(self, name, event, condition, callback, persistent)
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
            return original_add_listener(self, name, event, safe_condition, safe_callback, persistent)
        end
    end)
    if install_ok then
        G._core_wrapped = true
        emit("wrapped core.add_listener")
    end
end

G.try_wrap_method(bm, "callback", 1, "bm:callback")
G.try_wrap_method(bm, "repeat_callback", 1, "bm:repeat_callback")
G.try_wrap_method(bm, "register_phase_change_callback", 2, "bm:register_phase_change_callback")
G.try_wrap_method(bm, "register_command_handler_callback", 2, "bm:register_command_handler_callback")

_G.CZX_LUA_GUARD = G
emit("battle guard installed; native engine faults are outside Lua catch scope")
