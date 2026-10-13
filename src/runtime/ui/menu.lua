local Native=require('ui.native')
local Settings=require('ui.settings')
local Tabs=require('ui.tabs')
local Tree=require('ui.tree')
local Registry=require('core.registry')
local I18n=require('i18n.service')
local Menu={instances={},model={},subscriptions={}}
local render
local function hide(instance,widget)
    if Engine.valid(widget) then
        instance.hidden[#instance.hidden+1]={widget=widget,visibility=widget:GetVisibility()}
        widget:SetVisibility(1)
    end
end
local function close(instance,nativeSwitch,discard)
    if not instance.panel then return end
    if not discard then Settings.poll(instance,true) end
    Tabs.close(instance,nativeSwitch)
    if Engine.valid(instance.panel) then instance.panel:RemoveFromParent() end
    local owner=instance.owner
    for _,entry in ipairs(instance.hidden) do
        if Engine.valid(entry.widget) then entry.widget:SetVisibility(entry.visibility) end
    end
    if Engine.valid(owner) and owner:IsActivated() then
        owner.DefaultActionBinding=owner:RegisterActionBinding(owner.DefaultActionName,false,0,
            {object=owner,['function']='SetDefaultAction'})
        if not nativeSwitch then owner['Set Tab Action'](owner,owner.WBP_OptionSettings_Tab:IsVisible()) end
    end
    instance.panel,instance.list,instance.page,instance.modId=nil,nil,nil,nil
    instance.controls,instance.callbacks,instance.hidden={},{},{}
end
local function begin(instance,page,modId)
    close(instance,false,true)
    local owner=instance.owner
    owner.CanvasPanel_Settings:SetVisibility(0)
    owner.CanvasPanel_Settings:SetRenderOpacity(1)
    instance.hidden={}
    local panel,list=Native.scroll(owner)
    instance.panel,instance.list,instance.page=panel,list,page
    instance.controls,instance.callbacks={},{ }
    hide(instance,owner.WBP_PalCommonScrollList)
    hide(instance,owner.WBP_PalKeyGuideIcon_Default)
    hide(instance,owner.BP_PalTextBlock_Default)
    owner:UnregisterActionBinding(owner.DefaultActionBinding)
    owner['Set Tab Action'](owner,false)
    local entries={{id='catalog',label=I18n.core('menu.manage')}}
    for _,mod in ipairs(Menu.model.list() or {}) do
        entries[#entries+1]={id=mod.id,label=mod.name,muted=not mod.installed}
    end
    entries[#entries+1]={id='updates',label=I18n.core('updates.title')}
    Tabs.create(instance,entries,modId or page,function(id)
        if id=='catalog' or id=='updates' then render(instance,id)
        elseif Menu.model.active(id) then Menu.model.settings(instance,id)
        else Menu.model.install(id) end
    end)
end
local function action(instance,label,callback,muted,verb)
    return Native.action(instance.owner,instance.list,label,callback,instance.callbacks,muted,verb)
end
render=function(instance,page)
    page=page=='updates' and 'updates' or 'catalog'
    begin(instance,page)
    if page=='updates' then
        require('ui.updates').render(instance,action)
        return
    end
    local ids,labels=I18n.choices()
    Settings.field(instance,{key='language',label=I18n.core('language.title'),options=ids,optionLabels=labels},I18n.mode,Menu.model.language)
    for _,mod in ipairs(Menu.model.list() or {}) do
        action(instance,mod.name,function()
            if not mod.installed then Menu.model.install(mod.id)
            else Menu.model.remove(mod.id) end
        end,not mod.installed,I18n.core(mod.installed and 'common.uninstall' or 'common.install'))
    end
end
local function attach(owner)
    if not Engine.valid(owner) or Menu.instances[owner.key] then return end
    if not owner.WidgetTree or not owner.WidgetTree.RootWidget then return end
    local instance={owner=owner,controls={},callbacks={},hidden={},nativeButtons={}}
    if owner.class.name=='WBP_MenuESC_C' then
        local template=Tree.find(owner,'WBP_MenuESC_Button_Option')
        if not template then return end
        instance.entry,instance.button,instance.caption=Native.sidebar(owner,template,I18n.core('menu.mods'))
        instance.open=function()
            Menu.pending=Engine.clock()+5
            assert(Tree.find(template,'WBP_PalInvisibleButton')):HandleButtonClicked()
        end
    else
        local template=owner.WBP_OptionSettings_MenuButton_Graphic
        if not Engine.valid(template) then return end
        for _,name in ipairs({'Graphic','Sound','Game','Key','Other','S_Mod','S_Form','S_EULA'}) do
            local entry=owner['WBP_OptionSettings_MenuButton_'..name]
            local input=Engine.valid(entry) and Tree.find(entry,'WBP_PalInvisibleButton')
            if input then instance.nativeButtons[input.key]=true end
        end
        instance.entry,instance.button,instance.caption=Native.sidebar(owner,template,I18n.core('menu.mods'))
        instance.open=function() render(instance) end
    end
    Menu.instances[owner.key]=instance
end
function Menu.start(model)
    Menu.model=model
    for _,class in ipairs({'WBP_MenuESC_C','WBP_OptionSettings_C'}) do
        Menu.subscriptions[#Menu.subscriptions+1]=Registry.watch(class,attach)
        for _,owner in ipairs(Registry.get(class)) do attach(owner) end
    end
end
function Menu.refresh()
    for _,instance in pairs(Menu.instances) do
        if Engine.valid(instance.entry) then Native.label(instance.entry,I18n.core('menu.mods')) end
        if Engine.valid(instance.owner) and instance.panel then
            local offset=instance.list:GetScrollOffset()
            if instance.modId and Menu.model.active(instance.modId) then Menu.model.settings(instance,instance.modId)
            else render(instance,instance.page) end
            instance.list:SetScrollOffset(offset)
        end
    end
end
function Menu.stop()
    for _,unsubscribe in ipairs(Menu.subscriptions) do unsubscribe() end
    for _,instance in pairs(Menu.instances) do
        close(instance,false,true)
        if Engine.valid(instance.entry) then instance.entry:RemoveFromParent() end
    end
    Menu.instances,Menu.subscriptions={},{}
end
function Menu.settings(instance,id,extensions)
    local item=assert(extensions.active[id],'Mod is no longer installed')
    begin(instance,'settings',id)
    instance.modId=id
    Settings.field(instance,{key='enabled',label=I18n.core('common.enabled'),type='boolean'},item.enabled,function(value)
        extensions.enable(id,value)
    end)
    for _,field in ipairs(extensions.call(id,'settings')) do
        Settings.field(instance,I18n.field(id,field),item.settings[field.key],function(value)
            extensions.configure(id,{[field.key]=value})
        end)
    end
end
function Menu.feedback(message)
    print('[PalMods] '..tostring(message))
    for _,instance in pairs(Menu.instances) do
        if Engine.valid(instance.panel) then
            if Engine.valid(instance.feedback) then instance.feedback:RemoveFromParent() end
            instance.feedback=Native.heading(instance.owner,instance.list,tostring(message))
        end
    end
end
function Menu.tick()
    local now=Engine.clock()
    if Menu.languageRevision~=I18n.revision then
        Menu.languageRevision=I18n.revision
        for _,instance in pairs(Menu.instances) do if instance.panel then Settings.poll(instance,true) end end
        Menu.refresh()
    end
    if Menu.pending and now>Menu.pending then Menu.pending=nil end
    for key,instance in pairs(Menu.instances) do
        if not Engine.valid(instance.owner) then Menu.instances[key]=nil
        else
            local visible=instance.owner:IsActivated() and Tree.visible(instance.owner)
            if visible and now>=(instance.nextLabel or 0) then
                instance.nextLabel=now+1
                -- Blueprint construction may replace our initial caption after attachment.
                local caption=instance.caption
                if Engine.valid(caption) and caption:GetText()~=I18n.core('menu.mods') then caption:SetText(I18n.core('menu.mods')) end
            end
            if instance.panel and not visible then close(instance) end
            if visible and instance.owner.class.name=='WBP_OptionSettings_C' and Menu.pending then
                Menu.pending=nil;render(instance)
            end
            if visible and instance.panel and now>=(instance.nextPoll or 0) then
                instance.nextPoll=now+.1
                Settings.poll(instance)
            end
        end
    end
end
function Menu.click(button)
    if not Engine.valid(button) then return end
    for _,instance in pairs(Menu.instances) do
        if Engine.valid(instance.owner) then
            if instance.nativeButtons[button.key] then close(instance,true);return end
            if instance.button.key==button.key then Settings.poll(instance,true);instance.open();return end
            local callback=instance.callbacks[button.key]
            if callback then Settings.poll(instance,true);callback();return end
        end
    end
end
return Menu
