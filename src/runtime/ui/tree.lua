local Tree = {}
function Tree.walk(root, visit, maximum)
    local queue, seen, cursor = {root}, {}, 1
    while queue[cursor] and cursor <= (maximum or 800) do
        local widget = queue[cursor]
        cursor = cursor + 1
        if Engine.valid(widget) and not seen[widget.key] then
            seen[widget.key] = true
            local result = visit(widget)
            if result ~= nil then return result end
            if widget.GetChildrenCount then
                for i = 0, widget:GetChildrenCount() - 1 do queue[#queue + 1] = widget:GetChildAt(i) end
            end
            if widget.GetDisplayedEntryWidgets then
                for _,entry in ipairs(widget:GetDisplayedEntryWidgets()) do queue[#queue+1]=entry end
            end
            if widget.WidgetTree then queue[#queue + 1] = widget.WidgetTree.RootWidget end
        end
    end
end
function Tree.find(root, name)
    return Tree.walk(root, function(widget) if widget.name == name then return widget end end)
end
function Tree.visible(widget)
    for _ = 1, 32 do
        if not Engine.valid(widget) then return false end
        if Engine.is_a(widget, 'Widget') then
            if not widget:IsVisible() then return false end
            if widget.IsInViewport and widget:IsInViewport() then return true end
            widget = widget:GetParent() or widget.outer
        elseif Engine.is_a(widget, 'WidgetTree') then widget = widget.outer
        else return false end
    end
    return false
end
return Tree
