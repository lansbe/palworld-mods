package.path='src/runtime/?.lua;'..package.path
local actions,fields,headings,refreshes={},{},{},0
package.loaded['i18n.service']={core=function(key)return key end}
package.loaded['ui.settings']={field=function(_,field,value,change)fields[field.key]={value=value,change=change}end}
package.loaded['ui.native']={heading=function(_,_,text)headings[#headings+1]=text end}
package.loaded['ui.menu']={instances={},refresh=function()refreshes=refreshes+1 end}
local Updates=require('ui.updates')
local function render(state)
    actions,fields,headings={},{},{}
    Updates.set(state)
    Updates.render({},function(_,label,callback)actions[label]=callback end)
end
render({automatic=true,status='idle',connected=false})
assert(fields.automatic.value==true and actions['updates.check'] and not actions['updates.connect'])
assert(not actions['common.back'],'Page navigation belongs in the top tabs')
assert(not actions['updates.install'])
render({automatic=false,status='available',connected=false,available=true})
assert(actions['updates.check'] and actions['updates.install'],'Public updates must not require sign-in')
render({automatic=true,status='authentication',connected=false})
assert(actions['updates.connect'] and actions['updates.check'],'Rate-limited users can retry or connect')
render({automatic=false,status='available',connected=true,available=true})
assert(fields.automatic.value==false and actions['updates.check'] and actions['updates.install'])
render({automatic=true,status='downloading',connected=true,busy=true,available=true})
assert(not actions['updates.check'] and not actions['updates.install'],'Busy updates must not offer duplicate actions')
render({automatic=true,status='ready',connected=true,ready=true})
assert(not actions['updates.install'] and headings[2]=='updates.ready')
assert(refreshes==0,'Background status must not rebuild other pages')
package.loaded['ui.menu'].instances={{page='updates'}}
Updates.set({status='latest'})
assert(refreshes==1)
assert(not pcall(Updates.set,{status='arbitrary'}))
print('PASS: update menu, opt-out, manual actions, busy states and scoped refresh')
