local Native=require('ui.native')
local TextField={}
function TextField.create(owner,row,field,current)
    row:SetClickableButton()
    -- Use UMG's native defaults, which exist even before world-creation assets load.
    local input=Native.make(owner,'EditableTextBox')
    input.WidgetStyle.TextStyle.Font=row.BP_PalTextBlock_Name.Font
    input.WidgetStyle.ForegroundColor=row.BP_PalTextBlock_Name.ColorAndOpacity
    input.WidgetStyle.FocusedForegroundColor=row.BP_PalTextBlock_Name.ColorAndOpacity
    input.WidgetStyle.BackgroundColor={SpecifiedColor={R=.025,G=.05,B=.065,A=1},ColorUseRule=0}
    input.WidgetStyle.Padding={Left=12,Top=6,Right=12,Bottom=6}
    input.RevertTextOnEscape=true
    input.ClearKeyboardFocusOnCommit=true
    local area=row.WBP_OptionSettings_ClickableButton
    local slot=area:GetParent():AddChildToCanvas(input)
    slot:SetLayout(area.Slot.LayoutData)
    input:SetText(tostring(current or ''))
    input:SetHintText(field.hint or field.label)
    area:SetVisibility(1)
    row.Button:SetVisibility(1)
    return input
end
return TextField
