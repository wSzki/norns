local metaparam = {}
local metaparams = {}

local scopes = { 'global', 'track', 'preset' }
local sepocs = tab.invert(scopes)

function metaparam:new(args)
    local m = setmetatable({}, { __index = self })

    m.random_min_id = args.id..'_random_min'
    m.random_max_id = args.id..'_random_max'

    if args.type == 'control' then
        args.random_min_default = args.random_min_default or args.controlspec.minval
        args.random_max_default = args.random_max_default or args.controlspec.maxval
        args.randomize = function(self, param_id, silent)
            local min = math.min(
                params:get_raw(m.random_min_id), params:get_raw(m.random_max_id)
            )
            local max = math.max(
                params:get_raw(m.random_min_id), params:get_raw(m.random_max_id)
            )
            local rand = math.random()*(max-min) + min

            params:set_raw(param_id, rand, silent)
        end
    elseif args.type == 'number' then
        args.random_min_default = args.random_min_default or args.min_preset
        args.random_max_default = args.random_max_default or args.max_preset
        args.randomize = function(self, param_id, silent)
            local min = math.min(
                params:get(m.random_min_id), params:get(m.random_max_id)
            )
            local max = math.max(
                params:get(m.random_min_id), params:get(m.random_max_id)
            )
            local rand = math.random(min, max)

            params:set(param_id, rand, silent)
        end
    elseif args.type == 'option' then
        args.randomize = function(self, param_id, silent)
            local min = 1
            local max = #self.args.options
            local rand = math.random(min, max)

            params:set(param_id, rand, silent)
        end
    elseif args.type == 'binary' then
        args.randomize = function(self, param_id, silent)
            --TODO: probabalility
            local rand = math.random(0, 1)

            params:set(param_id, rand, silent)
        end
    end

    args.default_scope = args.default_scope or 'track'
    args.default_reset_preset_action = args.default_reset_preset_action or 'default'

    args.action = args.action or function() end
    
    --for k,v in pairs(args) do m[k] = v end
    m.args = args

    m.id = args.id

    m.name = args.name or args.id
    
    m.reset_func = args.reset or metaparams.resets.default
    m.random_func = args.randomize
    
    m.scope_id = args.scope_id or args.id..'_scope'

    m.global_id = args.id..'_global'

    m.hidden = args.hidden

    --TODO: slew time data
    
    m.track_id = {}
    for t = 1,tracks do
        local id = (
            args.id
            ..'_track_'..t
        )
        m.track_id[t] = id
    end
    m.preset_id = {}
    for t = 1,tracks do
        m.preset_id[t] = {}
        for b = 1,buffers do
            m.preset_id[t][b] = {}
            for p = 1, presets do
                local id = (
                    args.id
                    ..'_t'..t
                    ..'_buf'..b
                    ..'_pre'..p
                )
                m.preset_id[t][b][p] = id
            end
        end
    end

    return m
end

function metaparam:default_func(param_id, silent)
    local p = params:lookup_param(param_id)
    params:set(
        param_id, p.default or (p.controlspec and p.controlspec.default) or 0, silent
    )
end

function metaparam:get_scope()
    return scopes[params:get(self.scope_id)]
end

function metaparam:randomize(t, b, p, silent)
    b = b or sc.buffer[t]
    p = p or preset:get(t)

    local scope = self:get_scope()

    local p_id = scope == 'preset' and self.preset_id[t][b][p] or self.track_id[t]
    
    self.random_func(self, p_id, silent)
end

function metaparam:defaultize(t, b, p, silent)
    b = b or sc.buffer[t]
    p = p or preset:get(t)

    local scope = self:get_scope()

    local p_id = scope == 'preset' and self.preset_id[t][b][p] or self.track_id[t]
    
    self.default_func(self, p_id, silent)
end

metaparams.resets = {
    -- none = function() end,
    default = function(self, param_id)
        local silent = true
        self:default_func(param_id, silent)
    end,
    random = function(self, param_id, t, b, p)
        local silent = true
        if p == 1 then
            --metaparams.resets.default(self, param_id) ----?
        else
            --self:randomize(t, b, p, silent)
            self.random_func(self, param_id, silent)
        end
    end
}
function metaparam:set_reset_presets(func)
    self.reset_func = func
end

function metaparam:reset_presets(t, b)
    local scope = self:get_scope()

    for p = 1, presets do
        local p_id = self.preset_id[t][b][p]
        self.reset_func(self, p_id, t, b, p)
    end
end

function metaparam:get_id(track)
    local scope = self:get_scope()

    if scope == 'preset' then
        local b = sc.buffer[track]
        local p = preset:get(track)

        return self.preset_id[track][b][p]
    elseif scope == 'track' then
        return self.track_id[track]
    elseif scope == 'global' then
        return self.global_id
    end
end
            
function metaparam:set(track, v)
    local scope = self:get_scope()

    if scope == 'preset' then
        local b = sc.buffer[track]
        local p = preset:get(track)

        params:set(self.preset_id[track][b][p], v)
    elseif scope == 'track' then
        params:set(self.track_id[track], v)
    elseif scope == 'global' then
        params:set(self.global_id, v)
    end
end

function metaparam:get(track, raw)
    local scope = self:get_scope()

    if scope == 'global' then
        return raw and params:get_raw(self.global_id) or params:get(self.global_id)
    elseif scope == 'track' then
        return raw and params:get_raw(self.track_id[track]) or params:get(self.track_id[track])
    elseif scope == 'preset' then
        local b = sc.buffer[track]
        local p = sc.slice:get(track)

        return raw and (
            params:get_raw(self.preset_id[track][b][p])
        ) or (
            params:get(self.preset_id[track][b][p])
        )
    end
end
function metaparam:get_controlspec(scope)
    return self.args.controlspec
end
function metaparam:get_options()
    return self.args.options
end

for _, name in ipairs{ 'min', 'max', 'default' } do
    metaparam['get_'..name] = function(self, scope)
        return self.args[name]
    end
end

function metaparam:bang(track)
    self.args.action(track, self:get(track), self:get_id(track))
end

function metaparam:global_param_args()
    local args = {}
    for k,v in pairs(self.args) do args[k] = v end

    args.id = self.global_id
    args.name = self.args.name or self.args.id
    args.action = function(v) 
        for t = 1, tracks do
            -- self:bang(t) 
            self.args.action(t, v)
        end
    end
    
    return args
end
function metaparam:add_global_param()
    params:add(self:global_param_args())
end
function metaparam:track_param_args(t)
    local args = {}
    for k,v in pairs(self.args) do args[k] = v end

    args.id = self.track_id[t]
    args.name = self.args.name or self.args.id
    args.action = function(v) 
        -- self:bang(t) 
        self.args.action(t, v)
    end

    return args
end
function metaparam:add_track_param(t)
    params:add(self:track_param_args(t))
end

function metaparam:preset_param_args(t, b, p)
    local args = {}
    for k,v in pairs(self.args) do args[k] = v end

    args.id = self.preset_id[t][b][p]
    args.name = self.args.id
    args.name = self.args.name or self.args.id
    args.action = function(v) 
        if preset:get(t) == p then self.args.action(t, v) end
    end

    return args
end
function metaparam:add_preset_param(t, b, p)
    params:add(self:preset_param_args(t, b, p))
end

local function set_visibility(id, v)
    if v then params:show(id) else params:hide(id) end
end

function metaparam:show_hide_params()
    local scope = self:get_scope()
    local visible = not self.hidden

    set_visibility(self.global_id, visible and scope == 'global')

    for t,id in ipairs(self.track_id) do
        set_visibility(id, visible and scope == 'track')
    end
    for t,bufs in ipairs(self.preset_id) do
        for b, prsts in ipairs(bufs) do
            for p, id in ipairs(prsts) do
                set_visibility(id, visible and scope == 'preset')
            end
        end
    end
end

function metaparam:add_scope_param()
    params:add{
        name = self.args.id, id = self.scope_id, type = 'option',
        options = scopes, default = sepocs[self.args.default_scope],
        action = function()
            for t = 1, tracks do
                self:bang(t) 
            end

            self:show_hide_params()
            _menu.rebuild_params() --questionable?
        end,
        allow_pmap = false,
    }

    set_visibility(self.scope_id, not self.hidden)
end

function metaparam:add_random_range_params()
    local min, max
    if self.args.type == 'number' then
        min = self.args.min_preset
        max = self.args.max_preset
    end

    params:add{
        id = self.random_min_id, type = self.args.type, name = self.args.id..' min',
        controlspec = self.args.type == 'control' and cs.def{
            min = self.args.controlspec.minval, max = self.args.controlspec.maxval, 
            default = self.args.random_min_default
        },
        min = min, max = max, default = self.args.type == 'number' and self.args.random_min_default,
        allow_pmap = false,
    }
    set_visibility(self.random_min_id, not self.hidden)
    params:add{
        id = self.random_max_id, type = self.args.type, name = self.args.id..' max',
        controlspec = self.args.type == 'control' and cs.def{
            min = self.args.controlspec.minval, max = self.args.controlspec.maxval, 
            default = self.args.random_max_default
        },
        min = min, max = max, default = self.args.type == 'number' and self.args.random_max_default,
        allow_pmap = false,
    }
    set_visibility(self.random_max_id, not self.hidden)
    --TODO: probabalility for binary type
end

function metaparam:add_reset_preset_action_param()
    local id = self.id
    local names = { 'default', 'random' }
    local seman = tab.invert(names)
    local funcs = { metaparams.resets.default, metaparams.resets.random }
    params:add{
        id = id..'_reset', name = id, type = 'option',
        options = names, default = seman[self.args.default_reset_preset_action], 
        allow_pmap = false,
        action = function(v)
            self:set_reset_presets(funcs[v])
            crops.dirty.screen = true
        end
    }
    set_visibility(id..'_reset', not self.hidden)
end

function metaparams:new()
    local ms = setmetatable({}, { __index = self })

    ms.list = {}
    ms.lookup = {}

    return ms
end

function metaparams:add(args)
    local m = metaparam:new(args)

    table.insert(self.list, m)
    self.lookup[m.id] = m
end

function metaparams:bang(track, id)
    if id then
        self.lookup[id]:bang(track)
    else
        for _,m in ipairs(self.list) do m:bang(track) end
    end
end

function metaparams:set_reset_presets(id, func)
    return self.lookup[id]:set_reset_presets(func)
end
function metaparams:reset_presets(track, buffer, id)
    if id then
        self.lookup[id]:reset_presets(track, buffer)
    else
        for _,m in ipairs(self.list) do m:reset_presets(track, buffer) end
    end
end

-- function metaparams:set_randomize(id, func)
--     return self.lookup[id]:set_randomize(func)
-- end
function metaparams:randomize(track, id, buffer, preset, silent)
    return self.lookup[id]:randomize(track, buffer, preset, silent)
end
function metaparams:defaultize(track, id, buffer, preset, silent)
    return self.lookup[id]:defaultize(track, buffer, preset, silent)
end

function metaparams:get_id(track, id)
    return self.lookup[id]:get_id(track)
end
function metaparams:set(track, id, v)
    return self.lookup[id]:set(track, v)
end
function metaparams:get_controlspec(id)
    return self.lookup[id]:get_controlspec()
end
function metaparams:get_scope(id)
    return self.lookup[id]:get_scope()
end
function metaparams:get_options(id)
    return self.lookup[id]:get_options()
end
for _, name in ipairs{ 'min', 'max', 'default' } do
    local f_name = 'get_'..name
    metaparams[f_name] = function(self, id)
        local m = self.lookup[id]
        return m[f_name](m)
    end
end
function metaparams:get(track, id)
    return self.lookup[id]:get(track)
end
function metaparams:get_raw(track, id)
    local raw = true
    return self.lookup[id]:get(track, raw)
end

function metaparams:global_params_count() return #self.list end
function metaparams:global_param_args()
    local args = {}
    for _,m in ipairs(self.list) do 
        table.insert(args, m:global_param_args())
    end
    return args
end
function metaparams:add_global_params()
    for _,m in ipairs(self.list) do 
        m:add_global_param() 
    end
end
function metaparams:track_params_count() return #self.list end
function metaparams:track_param_args(t)
    local args = {}
    for _,m in ipairs(self.list) do 
        table.insert(args, m:track_param_args(t))
    end
    return args
end
function metaparams:add_track_params(t)
    for _,m in ipairs(self.list) do
        m:add_track_param(t)
    end
end
function metaparams:preset_params_count() return #self.list end
function metaparams:preset_param_args(t, b, p)
    local args = {}
    for _,m in ipairs(self.list) do 
        table.insert(args, m:preset_param_args(t, b, p))
    end
    return args
end
function metaparams:add_preset_params(t, b, p)
    for _,m in ipairs(self.list) do
        m:add_preset_param(t, b, p)
    end
end
        
function metaparams:add_scope_param(id)
    return self.lookup[id]:add_scope_param()
end

function metaparams:show_hide_params(id)
    return self.lookup[id]:show_hide_params()
end

function metaparams:scope_params_count() return #self.list end
function metaparams:add_scope_params()
    for _,m in ipairs(self.list) do 
        local id = m:add_scope_param() 
    end
end
function metaparams:random_range_params_count()
    local n = 0
    for _,m in ipairs(self.list) do 
        if m.args.type == 'number' or m.args.type == 'control' then
            n = n + 2
        end
    end

    return n
end
function metaparams:add_random_range_params()
    for _,m in ipairs(self.list) do 
        --TODO: add for binary type
        if m.args.type == 'number' or m.args.type == 'control' then
            m:add_random_range_params() 
        end
    end
end
function metaparams:reset_preset_action_params_count() return #self.list end
function metaparams:add_reset_preset_action_params()
    for _,m in ipairs(self.list) do 
        m:add_reset_preset_action_param() 
    end
end

return metaparams
