local Native=require('ui.native')
local I18n=require('i18n.service')
local Settings={}
local function value(control)
    local field,row=control.field,control.row
    if field.type=='boolean' then return row.WBP_OptionSettings_ListContentSwitch:IsOn() end
    if field.options then return field.options[row.WBP_OptionSettings_ListContentLR:GetCurrentIndex()+1] end
    return row.WBP_OptionSettings_ListContentSlider.CurrentValue
end
function Settings.field(instance,field,current,change)
    local row=Native.row(instance.owner,instance.list,field.label)
    local control={row=row,field=field,current=current,raw=current,change=change}
    if field.type=='boolean' then
        row:SetSwitcher(current)
        local switch=row.WBP_OptionSettings_ListContentSwitch
        for _,value in ipairs({'OFF','ON'}) do
            local label=I18n.core(value=='ON' and 'common.on' or 'common.off')
            Native.label(switch['CanvasPanel'..value],label)
            Native.label(switch['CanvasPanel_'..value..'Hover'],label)
        end
    elseif field.options then
        local selected=0
        for i,option in ipairs(field.options) do if option==current then selected=i-1 end end
        row:SetSelecter_String(field.optionLabels or field.options,selected)
    elseif field.type=='text' then
        row:SetClickableButton()
        local input=Native.make(instance.owner,'EditableTextBox')
        local template=Engine.find('/Game/Pal/Blueprint/UI/UserInterface/Title/'..
            'WBP_Title_WorldSettings_ListContent.WBP_Title_WorldSettings_ListContent_C.WidgetTree.EditableTextBox_46')
        assert(Engine.valid(template),'Native text field is unavailable')
        input.WidgetStyle=template.WidgetStyle
        input.WidgetStyle.TextStyle.Font=row.BP_PalTextBlock_Name.Font
        local area=row.WBP_OptionSettings_ClickableButton
        local panel=area:GetParent()
        local slot=panel:AddChildToCanvas(input)
        slot:SetLayout(area.Slot.LayoutData)
        input:SetText(tostring(current or ''))
        input:SetHintText(field.hint or field.label)
        area:SetVisibility(1)
        row.Button:SetVisibility(1)
        control.input=input
    else
        row:SetSlider(current,field.min,field.max,field.step,true)
        row.WBP_OptionSettings_ListContentSlider.Slider:SetStepSize(field.step/(field.max-field.min))
    end
    instance.controls[#instance.controls+1]=control
end
function Settings.poll(instance,flush)
    for _,control in ipairs(instance.controls or {}) do
        if Engine.valid(control.row) then
            local updated
            if control.input then
                if flush or not control.input:HasKeyboardFocus() then updated=control.input:GetText() end
            else updated=value(control) end
            if updated~=nil and updated~=control.raw then
                local raw=updated
                local field=control.field
                if type(updated)=='number' then
                    updated=math.max(field.min,math.min(field.max,field.min+math.floor((updated-field.min)/field.step+.5)*field.step))
                end
                if updated~=control.current then
                    local ok=pcall(control.change,updated)
                    if ok then control.current=updated
                    else require('ui.menu').feedback(I18n.core('error.invalid_value',{field=field.label})) end
                end
                control.raw=raw
            end
        end
    end
end
return Settings
