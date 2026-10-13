local Native=require('ui.native')
local Tree=require('ui.tree')
local Tabs={}

function Tabs.create(instance,entries,selected,change)
    local owner=instance.owner
    local container=owner.WBP_OptionSettings_Tab
    local original=assert(Tree.find(container,'HorizontalBox_0'),'Native tabs are unavailable')
    local bar=Native.make(owner,'HorizontalBox')
    local slot=container.WidgetTree.RootWidget:AddChildToCanvas(bar)
    slot:SetLayout(original.Slot.LayoutData)
    slot:SetAutoSize(true)
    instance.tabs={bar=bar,original=original,visibility=original:GetVisibility(),
        container=container,containerVisibility=container:GetVisibility(),buttons={}}
    original:SetVisibility(2)
    container:SetVisibility(0)
    for index,entry in ipairs(entries) do
        local button=Native.create(owner,'WBP_OptionSettings_TabButton')
        button:SetName(entry.label,index-1)
        button:SetTabActive(entry.id==selected)
        local child=bar:AddChildToHorizontalBox(button)
        child:SetPadding({Left=0,Top=0,Right=4,Bottom=0})
        if entry.muted then button:SetRenderOpacity(.45) end
        instance.tabs.buttons[entry.id]=button
        instance.callbacks[button.WBP_PalCommonButton.key]=function() change(entry.id) end
    end
end

function Tabs.close(instance,nativeSwitch)
    local tabs=instance.tabs
    if not tabs then return end
    if Engine.valid(tabs.bar) then tabs.bar:RemoveFromParent() end
    if Engine.valid(tabs.original) then tabs.original:SetVisibility(tabs.visibility) end
    if not nativeSwitch and Engine.valid(tabs.container) then
        tabs.container:SetVisibility(tabs.containerVisibility)
    end
    instance.tabs=nil
end

return Tabs
