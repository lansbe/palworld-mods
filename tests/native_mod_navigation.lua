-- Run with Options > Mods > Autonomy open, through the development-only probe.
-- Uses real widgets and settings handlers; restores the original configuration.
local Menu=require('ui.menu')
local Extensions=require('core.extensions')
local instance
for _,candidate in pairs(Menu.instances) do
    if candidate.panel and candidate.modId=='autonomy' and candidate.owner:IsActivated() then
        instance=candidate;break
    end
end
assert(instance,'Open the Autonomy tab first')
local original={}
for key,value in pairs(Extensions.active.autonomy.settings) do original[key]=value end
assert(not original.running,'Stop Autonomy before testing')
local function tab(id)
    Menu.click(assert(instance.tabs.buttons[id]).WBP_PalCommonButton)
    assert(instance.tabs.buttons[id].IsActive,'The destination tab must be selected')
end
local ok,failure=xpcall(function()
    local oldPanel=instance.panel
    local targets
    for _,control in ipairs(instance.controls) do
        if control.field.key=='targets' then targets=control.input end
    end
    assert(targets,'Text input is missing')
    targets:SetText('Lamball=6')
    targets:SetKeyboardFocus()
    tab('minimap')
    assert(instance.modId=='minimap' and instance.panel.key~=oldPanel.key)
    assert(Extensions.active.autonomy.settings.targets=='Lamball=6','Tab changes must commit pending text')
    assert(not oldPanel:GetParent(),'Old panels must be detached')
    tab('updates')
    assert(instance.page=='updates' and #instance.controls==1)
    tab('catalog')
    assert(instance.page=='catalog' and instance.controls[1].field.key=='language')
    tab('autonomy')
    assert(instance.modId=='autonomy' and #instance.controls==18)
    for _,control in ipairs(instance.controls) do
        if control.field.key=='targets' then control.input:SetText('Lamball=7') end
    end
    Menu.click(instance.button)
    assert(instance.page=='catalog' and Extensions.active.autonomy.settings.targets=='Lamball=7',
        'Selecting the Mods category must also commit pending text')
    tab('autonomy')
    for _,control in ipairs(instance.controls) do
        if control.input then
            local style=control.input.WidgetStyle
            assert(style.ForegroundColor.ColorUseRule==0 and style.FocusedForegroundColor.ColorUseRule==0)
            assert(style.TextStyle.SelectedBackgroundColor.ColorUseRule==0)
            assert(style.BackgroundImageNormal.DrawAs==3)
        end
    end
end,debug.traceback)
Extensions.configure('autonomy',original)
Menu.refresh()
assert(ok,failure)
return {passed=true,checks={'native tabs','pending text commit','panel cleanup','all pages','input style','restore'}}
