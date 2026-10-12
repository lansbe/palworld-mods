local Extensions = require('core.extensions')
local Control = require('ui.control')
local Game = require('core.game')
local Diagnostics = require('core.diagnostics')
local Commands = {}
function Commands.run(request)
    assert(type(request)=='table' and type(request.method)=='string', 'Invalid request')
    local method = request.method
    if method=='game.inventory' then return require('core.controls').call('inventory',request) end
    if method=='game.observe' then return require('core.controls').call('scan',request) end
    if method=='game.path' then return require('core.navigation').path(request) end
    if method=='game.aim' then return require('core.navigation').aim(request) end
    if method=='game.move' then return require('core.motion').move(request) end
    if method=='game.look' then return require('core.motion').look(request) end
    if method=='game.action' then return require('core.motion').action(request) end
    if method=='game.stop' then return require('core.motion').stop() end
    if method=='display.get' then return require('core.display').get() end
    if method=='display.fullscreen' then return require('core.display').fullscreen() end
    if method=='ping' then return {api=1, runtime='native'} end
    if method=='game.state' then return Game.state() end
    if method=='ui.open' then return Control.open(request.menu) end
    if method=='ui.back' then return Control.back(request.screen) end
    if method=='ui.scroll' then return Control.scroll(request.element,request.amount) end
    if method=='ui.list' then return Control.list() end
    if method=='ui.activate' then return Control.activate(request.element) end
    if method=='ui.set_text' then return Control.set_text(request.element, request.text) end
    if method=='mods.list' then return Extensions.list() end
    if method=='mods.feedback' then require('ui.menu').feedback(request.message);return true end
    if method=='mods.catalog' then
        assert(type(request.catalog)=='table' and #request.catalog<=32, 'Invalid catalogue')
        Extensions.catalog=request.catalog
        return true
    end
    if method=='mods.install' then
        local ok, error = Extensions.install(request.package, request.settings, request.enabled)
        assert(ok, error)
        return true
    end
    if method=='mods.enable' then return Extensions.enable(request.mod,request.enabled) end
    if method=='mods.remove' then return Extensions.remove(request.mod) end
    if method=='mods.configure' then return Extensions.configure(request.mod, request.settings) end
    if method=='mods.call' then return Extensions.call(request.mod, request.operation, request.arguments) end
    if method=='diagnostics' then return {errors=Diagnostics.errors, timings=Diagnostics.samples} end
    if method=='quit' then assert(Game.state().phase=='title','Return to the title screen before quitting');require('core.motion').stop(); Extensions.shutdown(); Engine.quit(); return true end
    error('Unknown command: '..method)
end
return Commands
