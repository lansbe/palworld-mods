local Diagnostics = require('core.diagnostics')
local Registry = {lists={}, callbacks={}}
function Registry.watch(class, callback)
    if not Registry.lists[class] then
        Registry.lists[class] = Engine.objects(class)
        Engine.subscribe(class)
    end
    if callback then
        Registry.callbacks[class] = Registry.callbacks[class] or {}
        local entry = {run=callback}
        table.insert(Registry.callbacks[class], entry)
        return function() entry.run=nil end
    end
    return Registry.lists[class]
end
function Registry.get(class)
    Registry.watch(class)
    local list = Registry.lists[class]
    for i = #list, 1, -1 do if not Engine.valid(list[i]) then table.remove(list, i) end end
    return list
end
function Registry.update()
    for class, additions in pairs(Engine.discoveries()) do
        local list = Registry.lists[class]
        if list then
            local callbacks = Registry.callbacks[class] or {}
            for i = #callbacks, 1, -1 do if not callbacks[i].run then table.remove(callbacks, i) end end
            local seen = {}
            for _, object in ipairs(list) do if Engine.valid(object) then seen[object.key]=true end end
            for _, object in ipairs(additions) do
                if Engine.valid(object) and not seen[object.key] then
                    list[#list + 1] = object
                    for _, callback in ipairs(callbacks) do Diagnostics.guard('discovery/'..class, callback.run, object) end
                end
            end
        end
    end
end
return Registry
