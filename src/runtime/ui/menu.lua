local Widgets = require('ui.widgets')
local Tree = require('ui.tree')
local Registry = require('core.registry')
local Menu = {instances={}, model={}}
local function close(instance)
    if instance.panel and Engine.valid(instance.panel) then instance.panel:RemoveFromParent() end
    for _,entry in ipairs(instance.hidden or {}) do
        if Engine.valid(entry.widget) then entry.widget:SetVisibility(entry.visibility) end
    end
    instance.hidden={}
    instance.panel = nil
    instance.page = nil
end
local function cover(instance)
    instance.hidden={}
    for index=0,instance.root:GetChildrenCount()-1 do
        local child=instance.root:GetChildAt(index)
        instance.hidden[#instance.hidden+1]={widget=child,visibility=child:GetVisibility()}
        child:SetVisibility(1)
    end
end
local render
render=function(instance, page)
    close(instance)
    cover(instance)
    local widgets = Widgets.new(instance.owner)
    local panel = widgets:make('CanvasPanel')
    widgets:fill(instance.root, panel, 1000)
    widgets:fill(panel, widgets:make('Border'), 0)
    local backdrop = panel:GetChildAt(0)
    backdrop:SetBrushColor(Widgets.colors.background)
    instance.panel, instance.page, instance.route, instance.modId = panel, widgets, page, nil
    widgets:text(panel, page == 'catalog' and 'Manage mods' or 'Mods', 100, 60, 700, 65, 38)
    widgets:button(panel, 'Back', 100, 780, 190, 54, function()
        if page=='catalog' then render(instance) else close(instance) end
    end)
    local rows = Menu.model.list()
    if page ~= 'catalog' then
        widgets:button(panel, 'Manage mods', 100, 150, 800, 64, function() render(instance, 'catalog') end)
    end
    local y = page == 'catalog' and 150 or 238
    for _, mod in ipairs(rows or {}) do
        widgets:button(panel, mod.name .. (page == 'catalog' and mod.installed and '  ·  Uninstall' or ''), 100, y, 800, 64, function()
            if not mod.installed then Menu.model.install(mod.id)
            elseif page == 'catalog' then Menu.model.remove(mod.id)
            else Menu.model.settings(instance, mod.id) end
        end, not mod.installed)
        y = y + 76
    end
end
local function attach(owner)
    if not Engine.valid(owner) or Menu.instances[owner.key] then return end
    local root = owner.WidgetTree and owner.WidgetTree.RootWidget
    if not root or not root.AddChildToCanvas then return end
    local widgets = Widgets.new(owner)
    local top=owner
    if owner.class.name=='WBP_MenuESC_C' then
        for _,candidate in ipairs(Registry.get('WBP_InGameMainMenu_C')) do
            if Tree.visible(candidate) then top=candidate;root=top.WidgetTree.RootWidget;break end
        end
    end
    local instance = {owner=owner,top=top, root=root, entryWidgets=widgets}
    if owner.class.name == 'WBP_MenuESC_C' then
        local group = Tree.find(owner, 'VerticalBox_91')
        if not group then return end
        local size = widgets:make('SizeBox')
        size:SetHeightOverride(64)
        local holder = widgets:make('CanvasPanel')
        size:SetContent(holder)
        group:AddChildToVerticalBox(size)
        local button = widgets:button(holder, 'Mods', 0, 0, 410, 60, function() render(instance) end)
        instance.entry = size
        instance.button = button.input
    else
        local button = widgets:button(root, 'Mods', 100, 660, 300, 60, function() render(instance) end)
        instance.entry, instance.button = button.group, button.input
    end
    Menu.instances[owner.key] = instance
end
function Menu.start(model)
    Menu.model = model
    for _, class in ipairs({'WBP_MenuESC_C', 'WBP_OptionSettings_C'}) do
        Registry.watch(class, attach)
        for _, owner in ipairs(Registry.get(class)) do attach(owner) end
    end
end
function Menu.refresh()
    for _, instance in pairs(Menu.instances) do
        if Engine.valid(instance.owner) and instance.panel then
            if instance.modId and Menu.model.active(instance.modId) then Menu.model.settings(instance,instance.modId)
            else render(instance,instance.route) end
        end
    end
end
function Menu.stop()
    for _, instance in pairs(Menu.instances) do
        close(instance)
        if Engine.valid(instance.entry) then instance.entry:RemoveFromParent() end
    end
    Menu.instances={}
end
function Menu.settings(instance,id,extensions)
    close(instance)
    cover(instance)
    local widgets=Widgets.new(instance.owner)
    local panel=widgets:make('CanvasPanel')
    widgets:fill(instance.root,panel,1000)
    local backdrop=widgets:make('Border'); backdrop:SetBrushColor(Widgets.colors.background)
    widgets:fill(panel,backdrop,0)
    instance.panel,instance.page,instance.modId=panel,widgets,id
    local item=extensions.active[id]
    widgets:text(panel,item.name,100,60,800,65,38)
    widgets:button(panel,'Back',100,780,190,54,function() render(instance) end)
    widgets:button(panel,'Enabled  ·  '..(item.enabled and 'On' or 'Off'),100,132,800,48,function()
        extensions.enable(id,not item.enabled);Menu.settings(instance,id,extensions)
    end)
    local fields=extensions.call(id,'settings')
    local function set(field,value)
        extensions.configure(id,{[field.key]=value})
        Menu.settings(instance,id,extensions)
    end
    for index, field in ipairs(fields) do
        local x=100+math.floor((index-1)/9)*900
        local y=204+(index-1)%9*56
        local value=item.settings[field.key]
        local label=field.label..'  ·  '..tostring(value)
        if field.type=='boolean' then
            label=field.label..'  ·  '..(value and 'On' or 'Off')
            widgets:button(panel,label,x,y,800,48,function() set(field,not value) end)
        elseif field.type=='text' then
            local input=widgets:make('EditableTextBox')
            input:SetText(tostring(value or ''))
            widgets:add(panel,input,x,y,630,48,2)
            input.ToolTipText=field.label
            widgets:button(panel,'Save',x+650,y,150,48,function() set(field,input:GetText()) end)
        elseif field.options then
            widgets:button(panel,label,x,y,800,48,function()
                local next=1
                for i,v in ipairs(field.options) do if v==value then next=i%#field.options+1 end end
                set(field,field.options[next])
            end)
        else
            widgets:text(panel,label,x,y+8,520,38,21)
            widgets:button(panel,'−',x+560,y,110,48,function() set(field,math.max(field.min,value-field.step)) end)
            widgets:button(panel,'+',x+690,y,110,48,function() set(field,math.min(field.max,value+field.step)) end)
        end
    end
end
function Menu.feedback(message)
    print('[PalMods] '..tostring(message))
    for _,instance in pairs(Menu.instances) do
        if instance.panel and instance.page then
            instance.page:text(instance.panel,tostring(message),100,720,1500,44,20)
        end
    end
end
function Menu.tick()
    for key, instance in pairs(Menu.instances) do
        if not Engine.valid(instance.owner) then Menu.instances[key] = nil
        else
            if instance.panel and not Tree.visible(instance.top) then close(instance) end
            instance.entryWidgets:hover()
            if instance.page then instance.page:hover() end
        end
    end
end
function Menu.click(button)
    for _, instance in pairs(Menu.instances) do
        if instance.page and instance.page:dispatch(button) then return end
        if instance.entryWidgets:dispatch(button) then return end
    end
end
return Menu
