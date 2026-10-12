local Registry = require('core.registry')
local Menu = require('ui.menu')
local Extensions = require('core.extensions')
local Diagnostics = require('core.diagnostics')
local Commands = require('core.commands')
local function emit(event) print('[PalModsIPC]'..Engine.json_encode(event)) end
local function request(operation, id) emit({event='mod_request', operation=operation, mod=id}) end
Menu.start({list=Extensions.list, active=function(id) return Extensions.active[id]~=nil end,
    install=function(id) request('install',id) end,
    remove=function(id) request('remove',id) end,
    settings=function(instance,id) Menu.settings(instance, id, Extensions) end})
function runtime_tick()
    for _, line in ipairs(Engine.messages()) do
        local decoded, request = pcall(Engine.json_decode,line)
        if decoded then
            local ok, result = xpcall(Commands.run,debug.traceback,request)
            if type(request)=='table' then
                emit({id=request.id,ok=ok,result=result})
                if ok and request.method:match('^mods%.') and request.method~='mods.call' then Menu.refresh() end
            end
        end
    end
    Diagnostics.guard('display',require('core.display').start)
    Diagnostics.guard('motion',require('core.motion').tick)
    Diagnostics.guard('registry',Registry.update)
    Diagnostics.guard('extensions',Extensions.tick)
    for _, button in ipairs(Engine.clicks()) do Diagnostics.guard('menu/click',Menu.click,button) end
    Diagnostics.guard('menu',Menu.tick)
end
emit({event='ready',api=1})
