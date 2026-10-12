local Game=require('core.game')
local Registry=require('core.registry')
local Targets=require('core.targets')
local Scanner={};Scanner.__index=Scanner
local function position(value)return {x=value.X,y=value.Y,z=value.Z}end
function Scanner.new()
    return setmetatable({ready=false,characters={},resources={},metadata={}},Scanner)
end
function Scanner.character(object)
    local component=object.CharacterParameterComponent
    if not Engine.valid(component) then return nil end
    local individual=component:GetIndividualParameter()
    return {character_id=individual:GetCharacterID(),level=component:GetLevel(),hp_ratio=component:GetHPRate(),
        dead=component:IsDead(),dying=component:IsDying()}
end
function Scanner:step(command)
    local controller=assert(Game.controller(),'Player is unavailable')
    local player=assert(Game.subject(controller),'Player is unavailable')
    local now=Engine.clock()
    local utility=Engine.find('/Script/Pal.Default__PalUtility')
    local database=utility:GetDatabaseCharacterParameter(player)
    if not self.work then
        if now<(self.next_scan or 0) then return {ready=self.ready} end
        self.work={kind=1,index=1,characters={},resources={},metadata={},origin=player:K2_GetActorLocation(),
            radius=math.max(1,math.min(command.radius_m or 100,500)),
            lists={command.capture==false and {} or Registry.get('PalCharacter'),Registry.get('PalMapObject')}}
    end
    local work=self.work
    local deadline=now+.0006
    local visited=0
    while Engine.clock()<deadline and visited<24 do
        local list=work.lists[work.kind]
        local object=list and list[work.index]
        if not object then
            work.kind=work.kind+1;work.index=1
            if work.kind>2 then
                self.characters,self.resources,self.metadata=work.characters,work.resources,work.metadata
                self.ready=true;self.work=nil;self.next_scan=Engine.clock()+.8
                return {ready=true}
            end
        else
            work.index=work.index+1;visited=visited+1
            if Engine.valid(object) and object.key~=player.key then
                local location=object:K2_GetActorLocation()
                local origin=work.origin
                local distance=math.sqrt((location.X-origin.X)^2+(location.Y-origin.Y)^2+(location.Z-origin.Z)^2)/100
                if distance<=work.radius then
                    if work.kind==1 then
                        local component=object.CharacterParameterComponent
                        if Engine.valid(component) and utility:IsWildNPC(object) then
                            local individual=component:GetIndividualParameter();local id=individual:GetCharacterID()
                            if database:GetIsPal(id) and not individual:IsUncapturable() and not database:GetIsBoss(id)
                                and not database:GetIsTowerBoss(id) and not database:GetIsRaidBoss(id) and not database:GetIsPredatorBoss(id) then
                                work.characters[#work.characters+1]={target=Targets.remember(object),position=position(location),distance_m=distance,
                                    wild=true,is_pal=true,player=false,boss=false,uncapturable=false,capturing=component:GetIsCapturedProcessing(),
                                    character=Scanner.character(object)}
                            end
                        end
                    else
                        local key=object.key
                        local metadata=self.metadata[key]
                        if not metadata then
                            local name=object.class.name
                            local component,kind
                            if name:find('PickupItem',1,true) and Engine.valid(object.PalMapObjectPickupItemParameter) then
                                component=object.PalMapObjectPickupItemParameter;kind='pickup'
                            elseif name:find('DamagableRock',1,true) and Engine.valid(object.DropItemParameter) then
                                component=object.DropItemParameter;kind='node'
                            end
                            metadata={kind=kind,items={}}
                            if component then
                                metadata.target=Targets.remember(object)
                                if Engine.valid(object.BP_InteractableSphere) then metadata.interaction=Targets.remember(object.BP_InteractableSphere) end
                                for _,item in ipairs(component.DropItems) do
                                    if item.StaticItemId.Key~='None' and item.Num>0 then metadata.items[#metadata.items+1]=item.StaticItemId.Key end
                                end
                            end
                        end
                        work.metadata[key]=metadata
                        if metadata.kind and not object.bHidden then
                            for _,id in ipairs(metadata.items) do
                                work.resources[#work.resources+1]={target=metadata.target,position=position(location),distance_m=distance,
                                    item_id=id,kind=metadata.kind,interaction=metadata.interaction}
                            end
                        end
                    end
                end
            end
        end
    end
    return {ready=self.ready}
end
return Scanner
