-- Run through the development probe with Options > Mods > Autonomy open.
-- Exercises rendered UMG controls and the normal settings/persistence broker.
-- Restores the original configuration, including on assertion failure.
local Menu=require('ui.menu')
local Settings=require('ui.settings')
local Extensions=require('core.extensions')
local instance
for _,candidate in pairs(Menu.instances) do
    if candidate.panel and candidate.modId=='autonomy' and candidate.owner:IsActivated() then
        instance=candidate;break
    end
end
assert(instance,'Open the Autonomy settings first')
local item=assert(Extensions.active.autonomy)
assert(not item.settings.running,'Stop Autonomy before testing its settings')
local original,controls={},{}
for key,value in pairs(item.settings) do original[key]=value end
for _,control in ipairs(instance.controls) do controls[control.field.key]=control end
local function set(key,value)
    local control=assert(controls[key],'Missing control: '..key)
    if control.input then control.input:SetText(value)
    elseif control.field.type=='boolean' then control.row:SetSwitcher(value)
    elseif control.field.options then
        for index,option in ipairs(control.field.options) do
            if option==value then control.row:SetSelecter_String(control.field.optionLabels,index-1);break end
        end
    else control.row:SetSlider(value,control.field.min,control.field.max,control.field.step,true) end
    Settings.poll(instance,true)
    return control
end
local ok,failure=xpcall(function()
    assert(#instance.controls==18,'All Autonomy settings must render')
    set('capture_mode','all')
    set('wood',0);set('stone',0)
    set('targets','Lamball=5; Cattiva=3')
    assert(item.settings.targets=='Lamball=5; Cattiva=3','Capture targets must save from the native input')
    set('materials','Wood=100; Stone=50')
    assert(item.settings.materials=='Wood=100; Stone=50','Materials must save from the native input')
    set('capture_mode','selected')
    assert(item.settings.capture_mode=='selected','Selected mode must save')
    set('capture_mode','off')
    assert(item.settings.capture_mode=='off','Gather-only mode must save')
    local input=set('targets','UnknownPal=0').input
    assert(item.settings.targets=='Lamball=5; Cattiva=3' and input:HasError(),'Invalid targets must show an inline error without saving')
    set('targets','Lamball=6')
    assert(item.settings.targets=='Lamball=6' and not input:HasError(),'Corrected targets must save and clear the error')
    set('capture_mode','all');set('materials','')
    for key,value in pairs({quota=6,wood=100,stone=50,radius=120,max_level=10,health=50,
        sphere_reserve=4,max_throws=6,session_minutes=46,weaken=true,explore=false,eat=false,return_home=false}) do
        set(key,value)
        assert(item.settings[key]==value,'Native setting did not save: '..key)
    end
end,debug.traceback)
Extensions.configure('autonomy',original)
Menu.refresh()
assert(ok,failure)
return {passed=true,controls=18,checks={'capture goals','material goals','capture modes','inline errors','limits','toggles','restore'}}
