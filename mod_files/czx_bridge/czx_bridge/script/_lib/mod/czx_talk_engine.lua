-- czx_talk_engine.lua — 台本引擎：tag 构建 / 台本选择 / 冷却轮转 / 渲染分发
-- 依赖：czx_talk_data.lua（同目录，提供 CZX_PERSONA / CZX_LORE / CZX_TALK）
-- 双上下文通用（campaign + battle 均加载 _lib/mod/）

CZX_TALK_ENGINE = CZX_TALK_ENGINE or {}
local E = CZX_TALK_ENGINE

E.config = {
    enabled = true,
    cooldown_per_event = 30,     -- 同事件类型全局最短间隔（秒）
    cooldown_per_speaker = 90,   -- 同说话人最短间隔
    max_lines_per_tick = 2,      -- 单 tick 最多注入条数
    debug = true,                -- out() 输出命中信息
}

E._state = {
    last_event_at = {},          -- event -> timestamp
    last_speaker_at = {},        -- speaker -> timestamp
    used_lines = {},             -- "event|speaker" -> {idx=true} 轮转池
}

local function now()
    if os and os.time then return os.time() end
    return 0 -- [需验证] battle 环境 os.time 可用性；不可用则退化为帧计数
end

-- context -> tag set；context 字段：event/speaker/race/target_race/side/location/result/outcome/rival_pair{}/tags{}
function E.build_tags(ctx)
    local tags = { [ctx.event or ""] = true }
    for _, f in ipairs({"speaker","race","target_race","side","location","result","outcome"}) do
        if ctx[f] then tags[ctx[f]] = true end
    end
    if ctx.rival_pair then
        for _, x in ipairs(ctx.rival_pair) do tags[x] = true end
    end
    if ctx.tags then
        for _, x in ipairs(ctx.tags) do tags[x] = true end
    end
    return tags
end

local function set_has(set, key) return set[key] == true end
local function set_intersect(a, b) for k in pairs(a) do if b[k] then return true end end return false end
local function set_subset(a, b) for k in pairs(a) do if not b[k] then return false end end return true end
local function set_count_intersect(a, b)
    local n = 0 for k in pairs(a) do if b[k] then n = n + 1 end end return n
end

local function cond_match(cond, ctx)
    if not cond then return true, 0 end
    local n = 0
    for k, v in pairs(cond) do
        if type(v) == "table" then
            local ok = false
            for _, vv in ipairs(v) do if ctx[k] == vv then ok = true break end end
            if not ok then return false, 0 end
        elseif ctx[k] ~= v then
            return false, 0
        end
        n = n + 1
    end
    return true, n
end

local function cooldown_ok(ctx, t)
    local ev_at = E._state.last_event_at[ctx.event]
    if ev_at and (t - ev_at) < E.config.cooldown_per_event then return false end
    local sp = ctx.speaker
    if sp and sp ~= "*" and sp ~= "narrator" and sp ~= "agent" then
        local sp_at = E._state.last_speaker_at[sp]
        if sp_at and (t - sp_at) < E.config.cooldown_per_speaker then return false end
    end
    return true
end

-- 选择台本行：特异度(cond命中数+副键命中数) → priority 降序 → order 升序 → 未用轮转
function E.select(ctx)
    if not E.config.enabled or not CZX_TALK then return nil end
    local tags = E.build_tags(ctx)
    local t = now()
    if not cooldown_ok(ctx, t) then
        if E.config.debug then out("CZX_TALK: cooldown skip " .. tostring(ctx.event)) end
        return nil
    end

    local cands = {}
    for i, ln in ipairs(CZX_TALK) do
        if set_intersect(ln.keys or {}, tags) then
            local selective_ok = (not ln.selective) or set_subset(ln.keys2 or {}, tags)
            if selective_ok then
                local ok, cn = cond_match(ln.cond, ctx)
                if ok then
                    local spec = cn + set_count_intersect(ln.keys2 or {}, tags)
                    table.insert(cands, { spec = spec, priority = ln.priority or 50,
                                          order = ln.order or 100, idx = i, ln = ln })
                end
            end
        end
    end
    if #cands == 0 then
        if E.config.debug then out("CZX_TALK: no match for " .. tostring(ctx.event)) end
        return nil
    end

    table.sort(cands, function(a, b)
        if a.spec ~= b.spec then return a.spec > b.spec end
        if a.priority ~= b.priority then return a.priority > b.priority end
        return a.order < b.order
    end)

    local top = cands[1].spec
    local pool = {}
    for _, c in ipairs(cands) do
        if c.spec == top then table.insert(pool, c) end
    end

    -- 轮转：同池内优先未用；池耗尽重置
    local pool_key = (ctx.event or "") .. "|" .. (ctx.speaker or "")
    E._state.used_lines[pool_key] = E._state.used_lines[pool_key] or {}
    local used = E._state.used_lines[pool_key]
    local fresh = {}
    for _, c in ipairs(pool) do
        if not used[c.idx] then table.insert(fresh, c) end
    end
    if #fresh == 0 then
        used = {}
        E._state.used_lines[pool_key] = used
        fresh = pool
    end
    local pick = fresh[math.random(#fresh)]
    used[pick.idx] = true

    E._state.last_event_at[ctx.event] = t
    if ctx.speaker then E._state.last_speaker_at[ctx.speaker] = t end
    if E.config.debug then
        out(string.format("CZX_TALK: pick #%d spec=%d -> %s", pick.idx, pick.spec,
            string.sub(pick.ln.content or "", 1, 60)))
    end
    return pick.ln
end

-- unit_key -> persona id（CZX_PERSONA[*].unit_keys 匹配）
function E.resolve_speaker(unit_key)
    if not CZX_PERSONA or not unit_key then return nil end
    for id, p in pairs(CZX_PERSONA) do
        for _, k in ipairs(p.unit_keys or {}) do
            if k == unit_key then return id end
        end
    end
    return nil
end

-- 渲染：模板变量填充 + 分通道下发
function E.fill_template(text, ctx)
    if not text then return "" end
    return (text:gsub("{(%w+)}", function(k)
        local v = ctx[k]
        if type(v) == "table" then return tostring(v[1] or "") end
        return tostring(v or "{" .. k .. "}")
    end))
end

-- 注入通道实现（按上下文各自注册；默认仅 out() 保底）
E.renderers = E.renderers or {}

function E.register_channel(name, fn)
    E.renderers[name] = fn
end

function E.render(line, ctx)
    if not line then return false end
    local text = E.fill_template(line.content, ctx or {})
    local channel = line.channel or "event_feed"
    local fn = E.renderers[channel]
    local delivered = false
    if fn then
        local ok, res = pcall(fn, line, text, ctx)
        delivered = ok and res
    end
    -- 保底：结构化日志（遥测/daemon 消费 + 调试可见）
    out(string.format("CZX|t=%s|ch=%s|sp=%s|%s",
        tostring(now()), channel, tostring(line.speaker or ""), text))
    return delivered
end

-- 一条调用：fire(ctx) = select + render
function E.fire(ctx)
    local ln = E.select(ctx)
    if ln then return E.render(ln, ctx) end
    return false
end
