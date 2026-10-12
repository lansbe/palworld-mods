local Game=require('core.game')
local Inventory={}
local function player()
    local controller=assert(Game.controller(),'Player is unavailable')
    local character=assert(Game.subject(controller),'Player is unavailable')
    return controller,character
end
function Inventory.slots()
    local controller=player()
    local inventory=controller.PlayerState.InventoryData
    local result={}
    for _,kind in ipairs({0,3,5}) do
        local ok,container=inventory:TryGetContainerFromInventoryType(kind,nil)
        if ok and Engine.valid(container) then
            for index=0,math.min(container:Num(),4096)-1 do
                local slot=container:Get(index)
                if Engine.valid(slot) and not slot:IsEmpty() then
                    result[#result+1]={slot=slot,id=slot:GetItemId().StaticId,count=slot:GetStackCount(),index=index}
                end
            end
        end
    end
    return result
end
function Inventory.read()
    local controller,character=player()
    local inventory=controller.PlayerState.InventoryData
    local counts,captures={},{}
    for _,slot in ipairs(Inventory.slots()) do counts[slot.id]=(counts[slot.id] or 0)+slot.count end
    local record=assert(controller.PlayerState.RecordData,'Capture history is unavailable')
    for _,row in ipairs(record.PalCaptureCount.Items) do captures[row.Key]=row.Value end
    local parameter=character.CharacterParameterComponent:GetIndividualParameter()
    return {counts=counts,captures=captures,weight=inventory:GetNowItemWeight(),max_weight=inventory:GetMaxItemWeight(),
        hunger=parameter:GetFullStomachRate(),level=parameter:GetLevel(),ball=character.LoadoutSelectorComponent.NowEquipBallItemID}
end
function Inventory.ball(command)
    local controller,character=player()
    assert(Game.state().playable,'Player is not ready')
    local id=assert(command.id,'Missing sphere ID')
    assert(type(id)=='string' and id:match('^PalSphere'),'Expected sphere item ID')
    assert(controller.PlayerState.InventoryData:CountItemNum(id)>0,'No spheres of this type remain')
    character.LoadoutSelectorComponent:RequestChangeNowEquipBallItemID_ToServer(id)
    return {selected=id}
end
function Inventory.food()
    local controller,character=player()
    assert(Game.state().playable,'Player is not ready')
    local allowed={Berries=true,Baked_Berries=true,Bread=true,BakedMushroom=true,Mushroom=true}
    for _,item in ipairs(Inventory.slots()) do
        if allowed[item.id] then
            local id=character.CharacterParameterComponent:GetIndividualParameter():GetPalId()
            local function guid(value)return {A=value.A,B=value.B,C=value.C,D=value.D}end
            local target={PlayerUId=guid(id.PlayerUId),InstanceId=guid(id.InstanceId)}
            if Engine.use_item(controller,{container=guid(item.slot.ContainerId.ID),index=item.index},target) then
                return {requested=item.id,before=item.count}
            end
        end
    end
    return {missing=true}
end
return Inventory
