-- Run through the development probe with the game's Options screen open.
-- Uses detached native controls; does not change player or game settings.
local Native=require('ui.native')
local Tree=require('ui.tree')
local owner
for _,widget in ipairs(require('core.registry').get('WBP_OptionSettings_C')) do
    if widget:IsActivated() and Tree.visible(widget) then owner=widget;break end
end
assert(owner,'Open Options before running native integration checks')
local row=Native.create(owner,'WBP_OptionSettings_ListContent')
row:SetSwitcher(true)
local switch=row.WBP_OptionSettings_ListContentSwitch
assert(switch:IsOn()==true,'Native boolean parameter must be canonical true')
switch.CurrentIsOn=false
assert(switch:IsOn()==false,'Native boolean property must clear')
switch.CurrentIsOn=true
assert(switch:IsOn()==true,'Native boolean property must be canonical true')
switch.WBP_PalCommonButton_OFF:HandleButtonClicked()
assert(switch:IsOn()==false,'Native OFF click must change the control')
switch.WBP_PalCommonButton_ON:HandleButtonClicked()
assert(switch:IsOn()==true,'Native ON click must change the control')
row:SetSelecter_String({'square','round'},0)
local selector=row.WBP_OptionSettings_ListContentLR
Tree.find(selector.WBP_OptionSettings_ListContentRArrow,'WBP_PalCommonButton'):HandleButtonClicked()
assert(selector:GetCurrentIndex()==1,'Native arrow must select the next choice')
assert(selector.Selections[2]=='round','String arrays must round-trip')
assert(not pcall(function() selector.Selections={'square',{}} end),'Invalid element must be rejected')
assert(selector.Selections[2]=='round','Failed array assignment must preserve the previous array')
assert(not pcall(function() selector.Selections={[1]='square',[3]='round'} end),'Sparse arrays must be rejected')
selector.Selections={}
assert(#selector.Selections==0,'Empty array assignment must clear existing storage')
row:SetSlider(0,0,90,10,true)
row:AddValue()
assert(row.WBP_OptionSettings_ListContentSlider.CurrentValue==10,'Native slider increment must apply its step')
row:RemoveFromParent()
return {passed=true,checks={'native booleans','native clicks','string arrays','array rollback','slider increments'}}
