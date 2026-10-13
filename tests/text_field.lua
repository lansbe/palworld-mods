package.path='src/runtime/?.lua;'..package.path
local input={WidgetStyle={TextStyle={},BackgroundImageNormal={},BackgroundImageHovered={},
    BackgroundImageFocused={},BackgroundImageReadOnly={}}}
function input:SetText(value)self.text=value end
function input:SetHintText(value)self.hint=value end
local area={Slot={LayoutData={}},SetVisibility=function()end}
function area:GetParent()
    return {AddChildToCanvas=function(_,widget)
        assert(widget.WidgetStyle.TextStyle.ColorAndOpacity.ColorUseRule==0,
            'Set explicit colors before constructing the Slate control')
        return {SetLayout=function()end}
    end}
end
local row={SetClickableButton=function()end,BP_PalTextBlock_Name={Font={Size=20}},
    WBP_OptionSettings_ClickableButton=area,Button={SetVisibility=function()end}}
package.loaded['ui.native']={make=function()return input end}
require('ui.text_field').create({},row,{label='Targets',hint='Lamball=5'},'Cattiva=3')
local style=input.WidgetStyle
local function luminance(color)
    assert(color.ColorUseRule==0,'Colors must not inherit the same foreground')
    local c=color.SpecifiedColor
    assert(c.A==1,'Text and backgrounds must remain opaque')
    return .2126*c.R+.7152*c.G+.0722*c.B
end
local foreground=luminance(style.TextStyle.ColorAndOpacity)
for _,background in ipairs({style.TextStyle.SelectedBackgroundColor,style.TextStyle.HighlightColor,
    style.BackgroundImageNormal.TintColor,style.BackgroundImageHovered.TintColor,
    style.BackgroundImageFocused.TintColor,style.BackgroundImageReadOnly.TintColor}) do
    assert((foreground+.05)/(luminance(background)+.05)>=4.5,'Insufficient text contrast')
end
assert(luminance(style.ForegroundColor)==foreground and luminance(style.FocusedForegroundColor)==foreground)
for _,brush in ipairs({style.BackgroundImageNormal,style.BackgroundImageHovered,
    style.BackgroundImageFocused,style.BackgroundImageReadOnly}) do
    assert(brush.DrawAs==3 and brush.ResourceName=='None' and brush.ResourceObject==nil,
        'Packaged inputs must not require editor-only image resources')
end
assert(input.text=='Cattiva=3' and input.hint=='Lamball=5')
print('PASS: native input foreground, focus, selection contrast and packaged brushes')
