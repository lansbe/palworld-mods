package.path='src/runtime/?.lua;'..package.path
local changed=false
package.loaded['core.registry']={get=function()return {}end,watch=function()return function()end end}
package.loaded['core.game']={update=function()local result=changed;changed=false;return result end}
package.loaded['core.controls']={call=function()end}
Engine={clock=function()return 1 end,json_encode=function()return '{}' end,array=function(t)return t or {}end}
local Extensions=require('core.extensions')
local function package(source)return {api=1,id='fixture',name='Fixture',files={main=source}}end
assert(Extensions.install(package([[api.settings.count=0
api.every(0,function()api.settings.count=api.settings.count+1 end)
api.on_travel(function()api.settings.traveled=true end)
api.on_stop(function()api.settings.cleaned=true end)
api.provide('configure',function(values)assert(type(values.count)=='number');api.settings.count=values.count end)
]])))
local settings=Extensions.active.fixture.settings
Extensions.tick();assert(settings.count==1)
Extensions.enable('fixture',false);Extensions.tick();assert(settings.count==1)
changed=true;Extensions.tick();assert(settings.traveled,'Disabled mods still need travel cleanup')
Extensions.configure('fixture',{count=7});assert(settings.count==7)
assert(not pcall(Extensions.configure,'fixture',{count='bad'}));assert(settings.count==7)
Extensions.remove('fixture');assert(settings.cleaned and not Extensions.active.fixture)
assert(not Extensions.install(package("api.on_stop(function() Engine.cleaned=true end);error('fixture failure')")))
assert(Engine.cleaned and not Extensions.active.fixture,'Failed installation must clean up')
assert(not pcall(Extensions.install,{api=1,id='../escape',files={main=''}}))
assert(not pcall(Extensions.install,{api=2,id='fixture',files={main=''}}))
assert(Extensions.install(package("api.on_stop(function()Engine.stopped=true end)")))
Extensions.shutdown();assert(Engine.stopped and next(Extensions.active)==nil)
print('PASS: installation rollback, disable, travel, validation and shutdown')
