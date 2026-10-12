local Tree = require('ui.tree')
local Registry = require('core.registry')
local Control = {targets={}}
local function labels(widget)
    local result=Engine.array()
    local root=widget:GetParent() or widget
    Tree.walk(root,function(child)
        if child.GetText and Tree.visible(child) and #result<12 then
            local text=child:GetText()
            if type(text)=='string' and text~='' then result[#result+1]=text end
        end
    end,80)
    return result
end
function Control.list()
    local result, targets = Engine.array(), {}
    for _, owner in ipairs(Registry.get('PalUserWidgetStackableUI')) do
        if owner:IsActivated() and Tree.visible(owner) then
            local screen = {id=owner.key, class=owner.class.name, elements=Engine.array()}
            targets[owner.key]=owner
            Tree.walk(owner, function(widget)
                if #screen.elements>=300 or not Tree.visible(widget) then return end
                local button = Engine.is_a(widget, 'CommonButtonBase')
                local editable = Engine.is_a(widget, 'EditableTextBox') or Engine.is_a(widget, 'EditableText')
                local text = widget.GetText and widget:GetText() or nil
                if button or editable or widget.SetScrollOffset or (type(text)=='string' and text~='') then
                    local entry = {id=widget.key, name=widget.name, class=widget.class.name,
                        text=type(text)=='string' and text or nil, clickable=button, editable=editable,
                        enabled=widget:GetIsEnabled() and (not button or widget:IsInteractionEnabled()),
                        labels=button and labels(widget) or nil, owner=widget.outer and widget.outer.outer and widget.outer.outer.name}
                    screen.elements[#screen.elements+1]=entry
                    targets[widget.key]=widget
                end
            end, 1200)
            result[#result+1]=screen
        end
    end
    Control.targets=targets
    return result
end
function Control.activate(id)
    local target = Control.targets[id]
    assert(Engine.valid(target) and Tree.visible(target), 'Refresh the menu: this element is no longer visible')
    assert(Engine.is_a(target,'CommonButtonBase'),'Element is not a button')
    assert(target:GetIsEnabled() and target:IsInteractionEnabled() and target.HandleButtonClicked, 'Element is not an enabled button')
    target:HandleButtonClicked()
    return true
end
function Control.set_text(id, value)
    local target = Control.targets[id]
    assert(type(value)=='string' and #value<=256, 'Text exceeds the allowed length')
    assert(Engine.valid(target) and Tree.visible(target), 'Refresh the menu before editing')
    assert(Engine.is_a(target, 'EditableTextBox') or Engine.is_a(target, 'EditableText'), 'Element is not editable')
    target:SetText(value)
    return true
end
function Control.open(name)
    local methods={options='OnTriggerEscape',inventory='On Trigger Open Inventory Menu',
        technology='OnTriggerOpenTechnologyMenu',pals='OnTriggerOpenPalStatus',map='OnTriggerWorldMap',build='OpenBuildRadialMenu'}
    local method=assert(methods[name],'Unknown menu')
    local game=require('core.game').state()
    assert(game.phase=='world' and not game.loading,'Wait until the world is ready')
    local listener=assert(Registry.get('WBP_PalHUD_InGame_InputListener_C')[1],'Game menu input is unavailable')
    if name=='build' then listener[method](listener,'None') else listener[method](listener) end
    return true
end
function Control.back(id)
    local target=Control.targets[id]
    assert(Engine.valid(target) and Tree.visible(target),'Refresh the menu before closing')
    assert(Engine.is_a(target,'PalUserWidgetStackableUI') and target.Close,'This screen cannot be closed directly')
    target:Close();return true
end
function Control.scroll(id,amount)
    local target=Control.targets[id]
    assert(Engine.valid(target) and Tree.visible(target),'Refresh the list before scrolling')
    assert(type(amount)=='number' and amount==amount and math.abs(amount)<=2000,'Invalid scroll distance')
    assert(target.GetScrollOffset and target.SetScrollOffset,'Element is not a scrollable list')
    local maximum=target.GetScrollOffsetOfEnd and target:GetScrollOffsetOfEnd() or math.max(0,target:GetNumItems()-1)
    target:SetScrollOffset(math.max(0,math.min(maximum,target:GetScrollOffset()+amount)))
    return true
end
return Control
