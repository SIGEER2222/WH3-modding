local _native_pcall = pcall
local _native_xpcall = xpcall
local G = rawget(_G, "CZX_LUA_GUARD") or {}
-- 2026-10-02 埋点：69 个会话日志里 czx_lua_guard 零输出——先在 head 打点定因
--（_campaign_installed 被谁预置 / chunk 是否根本没跑到 emit）。
out("[czx_lua_guard] file head; preexisting installed=" .. tostring(G._campaign_installed))
out(string.format("[czx_lua_guard] env: core=%s cm=%s core_object=%s out=%s",
    type(core), type(cm), type(core_object), type(out)))
if G._campaign_installed then return end
G._campaign_installed = true
G._counts = G._counts or {}
G._wrapped_methods = G._wrapped_methods or {}

local unpack_fn = unpack or (table and table.unpack)

local function emit(message)
    local msg = "[czx_lua_guard] " .. tostring(message)
    -- 2026-10-02：WH3 环境里 out 是带 __call 的 table（type=="table"），
    -- 旧的 type(out)=="function" 判断让全部 emit 落进 print 旁路而哑掉。
    -- pcall 直接调用即可：function 与 callable table 都能走通。
    local ok = _native_pcall(out, msg)
    if not ok and type(print) == "function" then
        _native_pcall(print, msg)
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

G._src_map = G._src_map or {}

-- These helpers only handle Lua-visible nil/null/dead interfaces. They do not
-- make a stale native pointer safe; callers still need to avoid retaining UI
-- handles across panel destruction.
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

function G.find_ui(tag, root, ...)
    local find_tag = tostring(tag or "find_ui")
    if not G.is_valid(root, find_tag .. ":root") then return false end
    if type(find_uicomponent) ~= "function" then
        report(find_tag, "find_uicomponent is unavailable")
        return false
    end
    local names = {...}
    local ok, uic = _native_pcall(function()
        return find_uicomponent(root, unpack_fn(names, 1, #names))
    end)
    if not ok then
        report(find_tag, uic)
        return false
    end
    if not G.is_valid(uic, find_tag .. ":result") then return false end
    return true, uic
end

function G.ui_call(tag, uic, method, ...)
    return G.call(tag, uic, method, ...)
end

function G.wrap(tag, fn, fallback)
    if type(fn) ~= "function" then return fn end
    local src = "?"
    local ok_i, info = _native_pcall(function() return debug.getinfo(fn, "S") end)
    if ok_i and info then
        src = tostring(info.short_src) .. ":" .. tostring(info.linedefined)
    end
    local tag_text = tostring(tag)
    local is_psw_faction_condition =
        (tag_text:find("condition:FactionTurnStart:", 1, true) ~= nil
            or tag_text:find("condition:FactionTurnEnd:", 1, true) ~= nil)
        and (src:find("psw_英雄.lua", 1, true) ~= nil
            or src:find("psw_天赋效果.lua", 1, true) ~= nil
            or src:find("psw_第六批.lua", 1, true) ~= nil)
    local w = function(...)
        if is_psw_faction_condition then
            local context = select(1, ...)
            local ok_faction, faction = _native_pcall(function()
                if not context or type(context.faction) ~= "function" then
                    return nil
                end
                return context:faction()
            end)
            if ok_faction and faction then
                local ok_null, is_null = _native_pcall(function()
                    return faction:is_null_interface()
                end)
                if not ok_null or is_null then
                    return false
                end
                local ok_human, is_human = _native_pcall(function()
                    return faction:is_human()
                end)
                if not ok_human or not is_human then
                    return false
                end
                local ok_name, faction_name = _native_pcall(function()
                    return faction:name()
                end)
                if ok_name and faction_name then
                    local ok_data, player_data = _native_pcall(function()
                        return psw_main_data
                            and psw_main_data.player_data
                            and psw_main_data.player_data[faction_name]
                    end)
                    if ok_data and not player_data then
                        return false
                    end
                end
            end
        end
        local ok, a, b, c, d = G.run(tag, fn, ...)
        if not ok then return fallback end
        return a, b, c, d
    end
    G._src_map[w] = src .. " <" .. tostring(tag) .. ">"
    return w
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

-- Do not replace core.add_listener globally. The native event registrar is
-- shared by every mod, and wrapping it changes listener identity/lifetime
-- semantics during campaign.lua loading. PSW-specific guards belong at their
-- own call sites; ordinary third-party listeners must use the original API.
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

-- Do not proxy native callback registration methods globally. Their callback
-- identity is part of the engine's registration state; use G.wrap explicitly
-- at a call site when the callback must be isolated.
emit("native callback registration proxies disabled; explicit G.wrap required")

-- ===== 2026-10-04 事件分发保护（结束回合 AI 级联 UAF 修复核心）=====
-- vanilla 发售版的事件分发不设防。core_object:event_callback 的分发循环
-- （lib_core.lua ~1981 条件 / ~2007 回调）经由 chunk 局部 evt_callback 调用，
-- 而它默认指向裸路径：
--   ① show_performance_report 类默认 true（ENABLE_SCRIPT_PERFORMANCE_WARNING_
--      REPORTS 未设时布尔运算为真）→ 分发进 monitor_performance 分支，
--      对 callback_to_call_record.callback 直接裸调，evt_callback 根本不经过；
--   ② 即便走 evt_callback，core:new() 在 USE_PROTECTED_EVENT_CALLBACKS
--      未设时选 event_unprotected_callback（官方注释明言 "it is used during
--      autotests and in the released version of the game"）。
-- 结果：任何监听器回调/条件里的 Lua error 无 pcall 一路穿透引擎事件派发帧
-- ——同事件剩余监听器全部跳过（10-01 SAF force_declare_war 断链先例），
-- 引擎派发上下文被跳过清理 → 堆损坏 → 同级联窗内 UAF（+0x244e743 读空族 /
-- 2026-10-04 下午 6 连崩 rip 落堆地址坏函数指针族）。guard 的注册期 xpcall
-- 代理曾顺带挡住这一层（上午会话级联存活），10-03 移除代理后裸奔。
-- CA 自带保护路径 event_protected_callback（xpcall + log_event_error + 红字
-- + set_script_state）。本块在不碰任何注册身份/闭包的前提下（区别于引发
-- 加载窗崩溃的注册期代理）把分发整体切到保护路径：
--   ① 实例级 show_performance_report=false → 分发固定走 evt_callback 循环；
--   ② debug.setupvalue 翻转 lib_core chunk 共享的上值 evt_callback 到
--      event_protected_callback（条件/回调两个调用点同时覆盖，一次翻转
--      全 chunk 生效）。tweaker 走引擎侧 common.tweaker_value，mod 无法在
--      core:new() 前置位，故只能事后翻上值。
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
        -- Plan B（实测 2026-10-04 16:44 会话：debug.setupvalue 路径不可用，
        -- canary 打出 WARNING dispatch protection incomplete）——整方法替换
        -- core.event_callback 为逐回调 pcall 的忠实重实现（lib_core 9.0.2
        -- event_callback 本体：条件筛选→一次性监听器标删→重建列表→逐个调用）。
        -- 与注册期代理不同：add_listener 存的仍是作者原函数，只是分发循环
        -- 不再让任何 Lua error 穿透引擎事件派发帧。错误限流走 report()，
        -- 不复刻 vanilla 的 draw_2d_text/set_script_state（避免红字刷屏与
        -- autotest 误判）。
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

-- §10.40 loading-dismiss 级联窗口：级联逐个内联跑已注册回调时，加载屏析构
-- 与 intro_movie overlay 创建/销毁并发进行。mod 回调里的原生 UI 操作
-- （find_uicomponent / CreateComponent / SimulateLClick）会命中半销毁组件：
--   +0x22c0f80  call [rax+0x58] 空虚表（UAF 读）
--   +0x22c8774  野指针写 / +0x132c34c 哨兵字段写
-- 这里把 mod 注册的 dismiss 回调统一推迟到 intro 序列真正完结后执行。
-- vanilla faction_start 回调（wh_campaign_faction_start.lua 的 process_start，
-- 即 intro 触发器本体）必须放行——延迟它则 intro 永不开始、
-- has_intro_cutscene_played 永不置位，构成死锁；无法判别来源时同样放行。
local _QUIET_POLLS = 12    -- 引擎静默 12s：无 intro 的战役 flag 不置位，宽限放行
local _UI_PROBE_AFTER = 6  -- 前 6 次探测不碰 UI 树（避开级联窗口期）
local _MIN_POLLS = 20      -- 最早释放不早于 dismiss 后 ~20s（崩点实测散布到 +19s）
local _STABLE_NEEDED = 10  -- 全绿状态须连续维持 10s 才放行（覆盖 flag 早置位空档）
local _CINE_CAP = 150      -- 无 flyover 的战役兜底：150s 后照常放行
local _HARD_CAP = 300      -- 绝对兜底：300s 后无条件放行（v4 曾缺此项，
                           -- how_they_play 的 events 面板长开 → _ui_idle
                           -- 永假 → 探针无限等待 → psw 按钮永不创建，
                           -- 09-28 08:13 后全部会话复现）

-- §10.40 v3 死区盲区（09-27 1749/2008/2050 三崩复核）：dismiss 级联结束到
-- flyover 剧场（wh3_camp_flyover_*）起步之间有 ~40s+ 全静默带——一切瞬时判据
-- （无 cutscene、无 overlay、无加载屏）在死区里全绿，门控在 flyover 起步前
-- ~10-25s 提前放行，mod 动作落进死区，剧场起步（CinematicTrigger 后 ~1s）
-- 踩悬空对象即崩（+0x22c0f80）。唯一可靠的"intro 真完结"锚点是 flyover 剧场的
-- CinematicTrigger id=end_cinematic；新战役必须见到它（或 cap）才放行。
G._intro_cine_done = G._intro_cine_done or false
local _cine_watch_armed = false
local function _arm_cine_watch()
    if _cine_watch_armed then return end
    _cine_watch_armed = true
    if not (core and type(core.add_listener) == "function") then return end
    _native_pcall(function()
        core:add_listener(
            "czx_guard_cine_end",
            "CinematicTrigger",
            function(context) return context.string == "end_cinematic" end,
            function()
                G._intro_cine_done = true
                emit("end_cinematic observed; intro sequence over")
            end,
            false
        )
    end)
end

local function _movie_overlay_present()
    -- movie_overlay_* 根组件存在 = intro 覆盖层播放中或尚未销毁
    local ok_root, root = _native_pcall(function() return core:get_ui_root() end)
    if not ok_root or not root then return false end
    local ok_n, n = _native_pcall(function() return root:ChildCount() end)
    if not ok_n or not n then return false end
    for i = 0, n - 1 do
        local ok_c, c = _native_pcall(function() return UIComponent(root:Find(i)) end)
        if ok_c and c then
            local ok_id, id = _native_pcall(function() return c:Id() end)
            if ok_id and id and string.sub(tostring(id), 1, 14) == "movie_overlay_" then
                return true
            end
        end
    end
    return false
end

-- §10.40 v4 UI 空闲判据（09-28 0728 会话实锤）：deferred 爆发在
-- lock_ui stamp5 持锁 + dilemma 挂起期间放行，fet 模拟点击砸在锁上
-- 崩 +0x22c0f80（DropdownMenuOption 回调读死 context）。uim.ui_locked /
-- panels_open / is_processing_battle 全是 Lua 侧表查询——不碰原生 UI 树，
-- 且必须先于任何树遍历调用（锁定期探针自身遍历也会 UAF，zz_fe_probe 前科）。
local function _ui_idle()
    local ok_uim, uim = _native_pcall(function() return cm:get_campaign_ui_manager() end)
    if not ok_uim or not uim then return false end
    if uim.ui_locked then return false end
    local ok_bp, blocking = _native_pcall(function() return uim:get_open_blocking_panel() end)
    if ok_bp and blocking then return false end
    local ok_ev, events_open = _native_pcall(function() return uim:is_panel_open("events") end)
    if ok_ev and events_open then return false end
    local ok_bat, processing = _native_pcall(function() return cm:is_processing_battle() end)
    if ok_bat and processing then return false end
    return true
end

-- 瞬时危害检查（只读）：返回 true 不代表 intro 完结——
-- has_intro_cutscene_played 在播片被遮蔽时对 nag 战役提前置位（overlay/flyover/
-- 开局面板链尚未跑），故已废弃其早放行语义；放行由"连续稳定"判据决定。
-- 引擎级危害：级联/剧场窗口未结束才需要挡的部分。
local function _engine_clear(polls)
    -- 纯引擎状态先行，级联窗口内不碰 UI 树
    local ok_play, playing = _native_pcall(function() return cm:is_intro_cutscene_playing() end)
    if ok_play and playing then return false end
    local ok_cs, any_cs = _native_pcall(function() return cm:is_any_cutscene_running() end)
    if ok_cs and any_cs then return false end
    if polls < _UI_PROBE_AFTER then return false end
    -- 已过级联窗口期：查 UI 佐证，加载屏/movie_overlay 仍在 = 未落定
    local ok_ls, ls_uic = _native_pcall(function()
        local _, u = core:get_loading_screen()
        return u
    end)
    if ok_ls and ls_uic then return false end
    if _movie_overlay_present() then return false end
    return true
end

-- 从严版危害检查 = 引擎级 + UI 空闲（仅 intro 未完结期间使用；
-- events 面板/ui_lock 在正常游玩态会长时间为真，post-cine 不得再查）。
local function _hazards_clear(polls)
    if not _engine_clear(polls) then return false end
    -- UI 锁/面板忙 = vanilla 干预链正占着 UI 手术台，纯 Lua 判据先挡
    if not _ui_idle() then return false end
    return true
end

-- 诊断：报告当前各判据状态（hard cap/周期日志用）
local function _hazard_report()
    local r = {}
    local ok_play, playing = _native_pcall(function() return cm:is_intro_cutscene_playing() end)
    r[#r + 1] = "intro_playing=" .. tostring(ok_play and playing)
    local ok_cs, any_cs = _native_pcall(function() return cm:is_any_cutscene_running() end)
    r[#r + 1] = "any_cs=" .. tostring(ok_cs and any_cs)
    local ok_ls, ls_uic = _native_pcall(function()
        local _, u = core:get_loading_screen()
        return u
    end)
    r[#r + 1] = "loading_screen=" .. tostring(ok_ls and ls_uic ~= nil)
    r[#r + 1] = "movie_overlay=" .. tostring(_movie_overlay_present())
    local ok_uim, uim = _native_pcall(function() return cm:get_campaign_ui_manager() end)
    if ok_uim and uim then
        r[#r + 1] = "ui_locked=" .. tostring(uim.ui_locked)
        local ok_bp, blocking = _native_pcall(function() return uim:get_open_blocking_panel() end)
        r[#r + 1] = "blocking_panel=" .. tostring(ok_bp and blocking ~= nil)
        local ok_ev, ev = _native_pcall(function() return uim:is_panel_open("events") end)
        r[#r + 1] = "events_open=" .. tostring(ok_ev and ev)
    end
    return table.concat(r, " ")
end

local _gate_probe_seq = 0
local function _run_when_intro_settled(fn)
    -- 2026-10-02 canary：释放与执行点打出回调来源，崩溃日志断行直接指认元凶 mod
    local fn_src = "?"
    local ok_si, si = _native_pcall(function() return debug.getinfo(fn, "S") end)
    if ok_si and si then
        fn_src = tostring(si.short_src) .. ":" .. tostring(si.linedefined)
    end
    _arm_cine_watch()
    local need_cine = false
    local ok_ng, ng = _native_pcall(function() return cm:is_new_game() end)
    if ok_ng and ng then need_cine = true end
    _gate_probe_seq = _gate_probe_seq + 1
    local seq = _gate_probe_seq
    local key = "czx_intro_gate_probe_" .. seq
    local polls = 0
    local stable = 0
    local released = false
    local function probe()
        if released then return end
        polls = polls + 1
        local cine_ok = (not need_cine) or G._intro_cine_done or polls > _CINE_CAP
        if cine_ok then
            -- intro 已完结（或超 cap）：只挡引擎级危害；events 面板、
            -- ui_lock、blocking panel、战斗结算属正常游玩态，可能长时间
            -- 为真——v4 在此卡死（1820 会话 events 面板开至退出）
            if _engine_clear(polls) then
                stable = stable + 1
            else
                stable = 0
            end
        elseif _hazards_clear(polls) then
            -- intro 未完结：从严含 UI 空闲；引擎绿灯但不动 stable——
            -- 不消耗 _STABLE_NEEDED，避免死区提前放行（v3 教训）
            stable = 0
        else
            stable = 0
        end
        if polls % 60 == 0 then
            emit("gate probe polls=" .. polls .. " stable=" .. stable
                .. " cine_ok=" .. tostring(cine_ok) .. " :: " .. _hazard_report())
        end
        if polls >= _MIN_POLLS and stable >= _STABLE_NEEDED then
            released = true
            -- v4 错峰释放：各回调在同一判定帧集中通过会造成 mod 动作爆发
            -- （0728 实测 draw/overlay/fet 8s 内连发后崩），按注册序错开执行
            local delay = (seq % 6) * 2000
            emit("intro settled (polls=" .. polls .. ", stable=" .. stable .. ", seq=" .. seq .. ", delay=" .. delay .. "ms) <- " .. fn_src .. "; running deferred dismiss callback")
            -- 错峰尾段复查：只查引擎级危害，忙则改走硬兜底排程
            cm:real_callback(function()
                if not _engine_clear(_UI_PROBE_AFTER) then
                    polls = _HARD_CAP
                    stable = 0
                    released = false
                    cm:real_callback(probe, 2000, key)
                    return
                end
                emit("releasing seq=" .. seq .. " <- " .. fn_src)
                local ok, err = _native_pcall(fn)
                if not ok then report("polsd:deferred", err) end
            end, delay, key .. "_run")
        elseif polls > _HARD_CAP then
            released = true
            emit("hard cap " .. _HARD_CAP .. "s reached; running deferred callback anyway :: " .. _hazard_report())
            local ok, err = _native_pcall(fn)
            if not ok then report("polsd:deferred", err) end
        else
            cm:real_callback(probe, 1000, key)
        end
    end
    -- 首个探测也不内联跑——此刻仍在级联里
    cm:real_callback(probe, 1500, key)
end

-- 供其它 czx 脚本复用的同一门控：fn 推迟到 intro 序列稳定后才执行。
function G.defer_until_intro_settled(fn)
    if type(fn) ~= "function" then return end
    _run_when_intro_settled(fn)
end

-- 放行名单：vanilla intro 驱动链的 polsd 回调不许被推迟（延迟则 intro
-- movie/flyover 错过窗口被静默跳过，09-27 v3 初版实测 2107/2118 两连证实）。
-- ① wh_campaign_faction_start：process_start 级联触发器本体
-- ② lib_campaign_manager：start_intro_cutscene_on_loading_screen_dismissed
--   内层闭包（source=lib_campaign_manager.lua）——intro movie→flyover 的
--   实际启动器；该文件另一调用点是 exit_benchmark，同样应放行
local _VANILLA_INTRO_SRC = {"wh_campaign_faction_start", "lib_campaign_manager"}
local function _is_vanilla_intro_driver(fn)
    local getinfo = (type(debug) == "table") and debug.getinfo or nil
    if type(getinfo) ~= "function" then return true end
    local ok, info = _native_pcall(getinfo, fn)
    if not ok or not info then return true end
    local src = (tostring(info.source or "") .. "|" .. tostring(info.short_src or "")):gsub("\\", "/")
    for _, pat in ipairs(_VANILLA_INTRO_SRC) do
        if src:find(pat) then return true end
    end
    return false
end

if type(core_object) == "table"
    and type(core_object.progress_on_loading_screen_dismissed) == "function"
    and not G._polsd_wrapped then
    local orig_polsd = core_object.progress_on_loading_screen_dismissed
    local wrap_ok = _native_pcall(function()
        core_object.progress_on_loading_screen_dismissed = function(self, callback, suppress)
            if type(callback) == "function" and not _is_vanilla_intro_driver(callback) then
                local inner = callback
                callback = function() _run_when_intro_settled(inner) end
            end
            return orig_polsd(self, callback, suppress)
        end
    end)
    if wrap_ok then
        G._polsd_wrapped = true
        emit("wrapped core_object.progress_on_loading_screen_dismissed (intro-settle gate)")
    end
end

emit("pre-tail: polsd wrap block done")
-- Do not register the native CinematicTrigger listener while campaign.lua is
-- still loading. The same listener is armed on first deferred callback use,
-- after the campaign event system has finished initialisation.
_G.CZX_LUA_GUARD = G
emit("campaign guard installed; native engine faults are outside Lua catch scope")
