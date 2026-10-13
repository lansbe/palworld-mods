local Tree = require('ui.tree')
local Native = {}
local optionPath = '/Game/Pal/Blueprint/UI/UserInterface/MainMenu/Option/'
function Native.create(owner, class)
    if type(class)=='string' then class=Engine.find(optionPath..class..'.'..class..'_C') end
    assert(Engine.valid(class), 'Native settings component is unavailable')
    return Engine.find('/Script/UMG.Default__WidgetBlueprintLibrary'):Create(owner,class,owner:GetOwningPlayer())
end
function Native.make(owner, kind)
    return Engine.construct(Engine.find('/Script/UMG.'..kind),owner.WidgetTree)
end
function Native.sidebar(owner, template, label)
    local widget=Native.create(owner,template.class)
    local slot=template:GetParent():AddChildToVerticalBox(widget)
    slot:SetPadding(template.Slot.Padding)
    slot:SetSize(template.Slot.Size)
    slot:SetHorizontalAlignment(template.Slot.HorizontalAlignment)
    slot:SetVerticalAlignment(template.Slot.VerticalAlignment)
    local caption=Tree.find(widget,'BP_PalTextBlock_Name') or Tree.find(widget,'Text_Main')
    assert(caption,'Native button label is unavailable'):SetText(label)
    local input=assert(Tree.find(widget,'WBP_PalInvisibleButton'),'Native button input is unavailable')
    return widget,input
end
function Native.row(owner, parent, label)
    local row=Native.create(owner,'WBP_OptionSettings_ListContent')
    local slot=parent:AddChild(row)
    slot:SetPadding({Left=0,Top=0,Right=0,Bottom=4})
    slot:SetHorizontalAlignment(0)
    row.BP_PalTextBlock_Name:SetText(label)
    return row
end
function Native.heading(owner,parent,label)
    local text=Engine.construct(owner.WBP_OptionSettings_MenuButton_Graphic.BP_PalTextBlock_Name.class,owner.WidgetTree)
    text.Font=owner.WBP_OptionSettings_MenuButton_Graphic.BP_PalTextBlock_Name.Font
    text.Font.Size=22
    text:SetText(label)
    text:SetVisibility(3)
    local slot=parent:AddChild(text)
    slot:SetPadding({Left=0,Top=8,Right=0,Bottom=14})
    return text
end
function Native.action(owner,parent,label,callback,callbacks,muted,verb)
    local row=Native.row(owner,parent,label)
    row:SetClickableButton()
    callbacks[row.Button.key]=callback
    local control=row.WBP_OptionSettings_ClickableButton
    callbacks[control.Button_ON.key]=callback
    Tree.walk(control,function(widget)
        if widget.GetText and widget.SetText then widget:SetText(verb or '›') end
    end,80)
    if muted then row:SetRenderOpacity(.45) end
    return row
end
function Native.scroll(owner)
    local original=owner.WBP_PalCommonScrollList
    local scroll=Native.create(owner,original.class)
    local slot=original:GetParent():AddChildToCanvas(scroll)
    slot:SetLayout(original.Slot.LayoutData)
    slot:SetZOrder(original.Slot.ZOrder+1)
    scroll:SetEnableMouseWheelScroll(true)
    return scroll,scroll:GetScrollBox()
end
return Native
