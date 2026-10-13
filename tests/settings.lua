package.path='src/runtime/?.lua;'..package.path
package.loaded['ui.native']={}
package.loaded['i18n.service']={core=function(key)return key end}
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
local focused,text,validation=true,'edited',nil
control.input={HasKeyboardFocus=function()return focused end,GetText=function()return text end,
    ClearError=function()validation=nil end,SetError=function(_,message)validation=message end}
control.field={key='targets',type='text'};control.current='original';control.raw='original'
Settings.poll(instance)
assert(value==15,'Typing must not commit an unfinished text field')
Settings.poll(instance,true)
assert(value=='edited','Leaving the page must commit the text field')
focused=false;text='invalid'
control.change=function(updated) count=count+1;assert(updated~='invalid');value=updated end
Settings.poll(instance)
assert(value=='edited' and control.current=='edited' and validation,'Invalid input must retain the saved value and show an error')
local attempts=count
Settings.poll(instance)
assert(count==attempts,'An invalid input must not be retried on every frame')
text='edited';Settings.poll(instance)
assert(validation==nil,'Returning to the saved value must clear the error')
text='corrected';Settings.poll(instance)
assert(value=='corrected' and validation==nil,'Corrected input must save and clear its error')
local selected=0
control.input=nil;control.current='all';control.raw='all'
control.field={key='mode',options={'selected','all'}}
control.row={WBP_OptionSettings_ListContentLR={GetCurrentIndex=function()return selected end},
    SetSelecter_String=function(_,_,index)selected=index end}
control.change=function()error('Goals required')end
Settings.poll(instance)
assert(selected==1 and control.raw=='all','Rejected selections must return to the saved choice')
print('PASS: settings preservation, quantization, text commit, validation and rollback')
