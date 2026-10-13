package.path='src/runtime/?.lua;'..package.path
package.loaded['ui.native']={}
package.loaded['ui.menu']={feedback=function()end}
Engine={valid=function(value)return value~=nil end}
local Settings=require('ui.settings')
local count,value=0,9
local slider={CurrentValue=9}
local control={field={key='x',min=0,max=100,step=5},current=9,raw=9,
    row={WBP_OptionSettings_ListContentSlider=slider},change=function(updated) count=count+1;value=updated end}
local instance={controls={control}}
Settings.poll(instance)
assert(count==0 and value==9,'Opening a menu must preserve a saved value between steps')
slider.CurrentValue=16
Settings.poll(instance)
assert(count==1 and value==15,'User changes must respect the setting step')
Settings.poll(instance)
assert(count==1,'Idle polling must not write settings repeatedly')
local focused,text=true,'edited'
control.input={HasKeyboardFocus=function()return focused end,GetText=function()return text end}
control.field={key='targets',type='text'};control.current='original';control.raw='original'
Settings.poll(instance)
assert(value==15,'Typing must not commit an unfinished text field')
Settings.poll(instance,true)
assert(value=='edited','Leaving the page must commit the text field')
print('PASS: settings preservation, quantization, idle polling and text commit')
