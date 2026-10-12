local Targets={values={},order={}}
function Targets.remember(object)
    assert(Engine.valid(object),'Object has expired')
    local key=object.key
    if not Targets.values[key] then
        Targets.order[#Targets.order+1]=key
        if #Targets.order>2048 then Targets.values[table.remove(Targets.order,1)]=nil end
    end
    Targets.values[key]=object
    return key
end
function Targets.get(key)
    local object=Targets.values[key]
    assert(Engine.valid(object),'Target has expired; observe again')
    return object
end
function Targets.clear() Targets.values={};Targets.order={} end
return Targets
