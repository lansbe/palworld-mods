local Native=require('ui.native')
local TextField={}
local function color(r,g,b)
    return {SpecifiedColor={R=r,G=g,B=b,A=1},ColorUseRule=0}
end
local function background(brush,tint)
    -- Solid brushes do not depend on editor-only Slate image files.
    brush.ResourceName='None'
    brush.ResourceObject=nil
    brush.DrawAs=3
    brush.TintColor=tint
    brush.Margin={Left=0,Top=0,Right=0,Bottom=0}
end
function TextField.create(owner,row,field,current)
    row:SetClickableButton()
    -- Use UMG's native defaults, which exist even before world-creation assets load.
    local input=Native.make(owner,'EditableTextBox')
    local style=input.WidgetStyle
    local foreground,selection=color(.9,.95,1),color(0,.13,.25)
    style.TextStyle.Font=row.BP_PalTextBlock_Name.Font
    style.TextStyle.ColorAndOpacity=foreground
    style.TextStyle.SelectedBackgroundColor=selection
    style.TextStyle.HighlightColor=selection
    style.ForegroundColor=foreground
    style.FocusedForegroundColor=foreground
    style.ReadOnlyForegroundColor=color(.45,.55,.6)
    style.BackgroundColor=color(1,1,1)
    background(style.BackgroundImageNormal,color(.012,.022,.03))
    background(style.BackgroundImageHovered,color(.018,.035,.045))
    background(style.BackgroundImageFocused,color(.018,.035,.045))
    background(style.BackgroundImageReadOnly,color(.012,.022,.03))
    style.Padding={Left=12,Top=6,Right=12,Bottom=6}
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
