local Widgets = {}
local buttonClass
Widgets.__index = Widgets
local function color(r, g, b, a) return {R=r, G=g, B=b, A=a or 1} end
Widgets.colors = {
    background=color(.018, .036, .048, .99), row=color(.04, .075, .094),
    hover=color(.045, .2, .27), accent=color(.2, .8, .96),
    text=color(.88, .96, 1), muted=color(.43, .5, .55),
}
function Widgets.new(owner)
    return setmetatable({owner=owner, tree=owner.WidgetTree, controls={}, callbacks={}}, Widgets)
end
function Widgets:make(kind)
    return assert(Engine.construct(Engine.find('/Script/UMG.' .. kind), self.tree), 'Cannot create ' .. kind)
end
function Widgets:add(parent, widget, x, y, width, height, order)
    local slot = parent:AddChildToCanvas(widget)
    slot:SetPosition({X=x, Y=y})
    slot:SetSize({X=width, Y=height})
    slot:SetZOrder(order or 0)
    return slot
end
function Widgets:fill(parent, widget, order)
    local slot = parent:AddChildToCanvas(widget)
    slot:SetAnchors({Minimum={X=0, Y=0}, Maximum={X=1, Y=1}})
    slot:SetOffsets({Left=0, Top=0, Right=0, Bottom=0})
    slot:SetZOrder(order or 0)
    return slot
end
function Widgets:box(parent, x, y, width, height, tint)
    local box = self:make('Border')
    box:SetBrushColor(tint)
    box:SetVisibility(3)
    self:add(parent, box, x, y, width, height)
    return box
end
function Widgets:text(parent, value, x, y, width, height, size, tint)
    local widget = self:make('TextBlock')
    widget.Font.Size = size or 22
    widget.Font.TypefaceFontName='Regular'
    widget.ColorAndOpacity.SpecifiedColor = tint or self.colors.text
    widget.ColorAndOpacity.ColorUseRule = 0
    widget:SetText(value)
    widget:SetVisibility(3)
    self:add(parent, widget, x, y, width, height, 1)
    return widget
end
function Widgets:button(parent, label, x, y, width, height, callback, muted)
    local group = self:make('CanvasPanel')
    self:add(parent, group, x, y, width, height, 2)
    local backdrop = self:box(group, 0, 0, width, height, self.colors.row)
    local caption = self:text(group, label, 18, (height-30)/2, width-36, 32, 21, muted and self.colors.muted or self.colors.text)
    local class = Engine.valid(buttonClass) and buttonClass or Engine.find('/Game/Pal/Blueprint/UI/Utility/WBP_PalInvisibleButton.WBP_PalInvisibleButton_C')
    if not class then
        local sample = Engine.objects('WBP_PalInvisibleButton_C')[1]
        class = sample and sample.class
    end
    assert(class, 'Game button class is unavailable')
    buttonClass=class
    local library = Engine.find('/Script/UMG.Default__WidgetBlueprintLibrary')
    local input = library:Create(self.owner, class, self.owner:GetOwningPlayer())
    self:add(group, input, 0, 0, width, height, 3)
    self.callbacks[input.key] = callback
    local control = {input=input, background=backdrop, caption=caption, group=group}
    self.controls[#self.controls + 1] = control
    return control
end
function Widgets:dispatch(input)
    local callback = Engine.valid(input) and self.callbacks[input.key]
    if callback then callback(); return true end
end
function Widgets:hover()
    for _, control in ipairs(self.controls) do
        if Engine.valid(control.input) then
            local hovered = control.input:IsHovered() or control.input:HasKeyboardFocus()
            if hovered ~= control.hovered then
                control.background:SetBrushColor(hovered and self.colors.hover or self.colors.row)
                control.hovered = hovered
            end
        end
    end
end
return Widgets
