local Native=require('ui.native')
local I18n=require('i18n.service')
local TextField=require('ui.text_field')
local Settings={}
local function restore(control)
    local row,field,current=control.row,control.field,control.current
    if field.type=='boolean' then row:SetSwitcher(current)
    elseif field.options then
        for index,option in ipairs(field.options) do
            if option==current then row:SetSelecter_String(field.optionLabels or field.options,index-1);break end
        end
    else row:SetSlider(current,field.min,field.max,field.step,true) end
end
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
        control.input=TextField.create(instance.owner,row,field,current)
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
                    if ok then
                        control.current=updated
                        if control.input then control.input:ClearError() end
                    else
                        local message=I18n.core('error.invalid_value',{field=field.label})
                        if control.input then control.input:SetError(message)
                        else
                            restore(control)
                            raw=control.current
                            require('ui.menu').feedback(message)
                        end
                    end
                elseif control.input then
                    control.input:ClearError()
                end
                control.raw=raw
            end
        end
    end
end
return Settings
