local Registry = require('core.registry')
local Diagnostics = require('core.diagnostics')
local Game = require('core.game')
local Extensions = {active={}, catalog={}, cache={}}
local function emit(event) print('[PalModsIPC]'..Engine.json_encode(event)) end
local function identifier(value)
    return type(value)=='string' and #value<=64 and value:match('^[a-z][a-z0-9%-]*$')
end
function Extensions.remove(id, transient)
    local item = Extensions.active[id]
    if not item then return false end
    Extensions.active[id] = nil
    for i=#item.cleanup,1,-1 do Diagnostics.guard(id..'/cleanup', item.cleanup[i]) end
    if not transient then emit({event='mod_state', mod=id, installed=false}) end
    return true
end
function Extensions.install(package, settings, enabled)
    assert(type(package)=='table' and identifier(package.id), 'Invalid package ID')
    assert(package.api==1 and type(package.files)=='table', 'Unsupported package API')
    assert(type(package.files.main)=='string', 'Missing package entry point')
    local total, count = 0, 0
    for name, source in pairs(package.files) do
        assert(type(name)=='string' and name:match('^[%w_%.]+$') and type(source)=='string', 'Invalid module')
        total, count = total+#source, count+1
    end
    assert(total<=1024*1024 and count<=64, 'Package exceeds limits')
    Extensions.remove(package.id, true)
    local item = {id=package.id, name=package.name, settings=settings or {}, enabled=true,
        cleanup={}, toggles={}, timers={}, travel={}, services={}, loaded={}}
    local api = {controls=require('core.controls').call,remember=require('core.targets').remember,
        target=require('core.targets').get,traceback=debug.traceback, engine=Engine, game=Game, settings=item.settings, cache=Extensions.cache}
    function api.on_stop(fn) item.cleanup[#item.cleanup+1]=fn end
    function api.on_toggle(fn) item.toggles[#item.toggles+1]=fn end
    function api.on_travel(fn) item.travel[#item.travel+1]=fn end
    function api.objects(class) return Registry.get(class) end
    function api.watch(class, fn) api.on_stop(Registry.watch(class, fn)) end
    function api.every(seconds, fn)
        assert(type(seconds)=='number' and seconds>=0, 'Invalid interval')
        item.timers[#item.timers+1] = {interval=seconds, next=0, run=fn}
    end
    function api.provide(name, fn) item.services[name]=fn end
    function api.log(message) print('[PalMods/'..item.id..'] '..tostring(message)) end
    local environment = {api=api, Engine=Engine, assert=assert, error=error, ipairs=ipairs,
        pairs=pairs, next=next, pcall=pcall, xpcall=xpcall, select=select, tonumber=tonumber,
        tostring=tostring, type=type, setmetatable=setmetatable, getmetatable=getmetatable,
        math=math, string=string, table=table, utf8=utf8, print=api.log}
    environment.require = function(name)
        if item.loaded[name]~=nil then return item.loaded[name] end
        local source = assert(package.files[name], 'Unknown package module: '..tostring(name))
        item.loaded[name]=false
        local run = assert(load(source, '@'..package.id..'/'..name..'.lua', 't', environment))
        local value = run()
        item.loaded[name]=value or true
        return item.loaded[name]
    end
    local ok, error = Diagnostics.guard(package.id..'/install', environment.require, 'main')
    if not ok then
        for i=#item.cleanup,1,-1 do Diagnostics.guard(package.id..'/rollback', item.cleanup[i]) end
        return false, error
    end
    Extensions.active[package.id]=item
    if enabled==false then item.enabled=false; for _,fn in ipairs(item.toggles) do fn(false) end end
    emit({event='mod_state', mod=package.id, installed=true, enabled=item.enabled, settings=item.settings})
    return true
end
function Extensions.call(id, method, arguments)
    local item = assert(Extensions.active[id], 'Mod is not installed')
    return assert(item.services[method], 'Unknown mod method')(arguments or {})
end
function Extensions.enable(id, enabled)
    assert(type(enabled)=='boolean','Expected enabled flag')
    local item=assert(Extensions.active[id],'Mod is not installed')
    if item.enabled~=enabled then
        for _,fn in ipairs(item.toggles) do fn(enabled) end
        item.enabled=enabled
        emit({event='mod_state', mod=id, installed=true, enabled=enabled})
    end
    return enabled
end
function Extensions.configure(id, values)
    local item = assert(Extensions.active[id], 'Mod is not installed')
    assert(type(values)=='table', 'Expected settings object')
    local apply = assert(item.services.configure, 'Mod has no settings')
    apply(values)
    emit({event='settings', mod=id, settings=item.settings})
    return item.settings
end
function Extensions.tick()
    local travel = Game.update()
    local now = Engine.clock()
    for id, item in pairs(Extensions.active) do
        if travel then for _, fn in ipairs(item.travel) do Diagnostics.guard(id..'/travel', fn) end end
        if item.enabled then
            for _, timer in ipairs(item.timers) do
                if now>=timer.next then
                    timer.next=now+timer.interval
                    local ok = Diagnostics.measure(id, timer.run)
                    if not ok then timer.next=now+3 end
                end
            end
        end
    end
end
function Extensions.list()
    local result = Engine.array()
    for _, entry in ipairs(Extensions.catalog) do
        local item = Extensions.active[entry.id]
        result[#result+1]={id=entry.id, name=entry.name, installed=item~=nil, enabled=item and item.enabled or false}
    end
    return result
end
function Extensions.shutdown()
    local ids = {}; for id in pairs(Extensions.active) do ids[#ids+1]=id end
    for _, id in ipairs(ids) do Extensions.remove(id, true) end
end
return Extensions
