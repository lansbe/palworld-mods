local I18n=require('i18n.service')
local Settings=require('ui.settings')
local Native=require('ui.native')
local Updates={state={automatic=true,status='idle',current='',version='',connected=false}}
local allowed={idle='updates.current',checking='updates.checking',available='updates.available',
    downloading='updates.downloading',ready='updates.ready',latest='updates.latest',
    failed='updates.failed',authentication='updates.authentication'}
local function request(operation,values)
    local event=values or {}
    event.event,event.operation='update_request',operation
    print('[PalModsIPC]'..Engine.json_encode(event))
end
function Updates.set(state)
    assert(type(state)=='table' and allowed[state.status],'Invalid update state')
    Updates.state=state
    local Menu=require('ui.menu')
    for _,instance in pairs(Menu.instances) do
        if instance.page=='updates' then Menu.refresh();break end
    end
    return true
end
function Updates.render(instance,action)
    local state=Updates.state
    Settings.field(instance,{key='automatic',type='boolean',label=I18n.core('updates.automatic')},state.automatic,function(value)
        request('configure',{automatic=value})
    end)
    Native.heading(instance.owner,instance.list,I18n.core('updates.current',{version=state.current}))
    if state.status~='idle' then
        Native.heading(instance.owner,instance.list,I18n.core(allowed[state.status],{version=state.version}))
    end
    if not state.busy and not state.ready then
        action(instance,I18n.core('updates.check'),function() request('check') end)
        if state.available then action(instance,I18n.core('updates.install'),function() request('install') end) end
    end
    if not state.connected and state.status=='authentication' then
        action(instance,I18n.core('updates.connect'),function() request('connect') end)
    elseif state.connected then
        action(instance,I18n.core('updates.disconnect'),function() request('disconnect') end)
    end
end
return Updates
