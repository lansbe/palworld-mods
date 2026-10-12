local Motion=require('core.motion')
local Targets=require('core.targets')
local Navigation={}
function Navigation.location(object)
    if Engine.is_a(object,'Actor') then return object:K2_GetActorLocation() end
    assert(Engine.is_a(object,'SceneComponent'),'Expected actor or scene component')
    return object:K2_GetComponentLocation()
end
function Navigation.path(command)
    local _,player=Motion.player()
    local destination
    if command.target then destination=Navigation.location(Targets.get(command.target))
    else
        local position=assert(command.position,'Missing position')
        for _,key in ipairs({'x','y','z'}) do
            local value=position[key]
            assert(type(value)=='number' and value==value and math.abs(value)<1e8,'Invalid position')
        end
        destination={X=position.x,Y=position.y,Z=position.z}
    end
    local origin=player:K2_GetActorLocation()
    assert((origin.X-destination.X)^2+(origin.Y-destination.Y)^2+(origin.Z-destination.Z)^2<=50000^2,'Path destination is too far away')
    local nav=Engine.find('/Script/NavigationSystem.Default__NavigationSystemV1')
    local filter=Engine.find('/Script/NavigationSystem.NavigationQueryFilter')
    local path=nav:FindPathToLocationSynchronously(player,origin,destination,player,filter)
    assert(Engine.valid(path),'Navigation is unavailable here')
    local points=Engine.array()
    for i,point in ipairs(path.PathPoints) do
        if i>128 then break end
        points[#points+1]={x=point.X,y=point.Y,z=point.Z}
    end
    return {points=points,partial=path:IsPartial()}
end
function Navigation.aim(command)
    local controller,player=Motion.player()
    local destination=Navigation.location(Targets.get(command.target))
    local camera=controller.PlayerCameraManager
    local origin=command.melee and player:K2_GetActorLocation() or camera:GetCameraLocation()
    local dx,dy,dz=destination.X-origin.X,destination.Y-origin.Y,destination.Z-origin.Z
    assert(dx*dx+dy*dy+dz*dz<=50000^2,'Target is too far away')
    local yaw=math.deg(math.atan(dy,dx))
    local pitch=command.melee and 0 or math.deg(math.atan(dz,math.sqrt(dx*dx+dy*dy)))
    pitch=math.max(math.max(-60,camera.ViewPitchMin+.2),math.min(math.min(60,camera.ViewPitchMax-.2),pitch))
    Motion.look({yaw=yaw,pitch=pitch,smooth=command.smooth~=false})
    local current=controller:GetControlRotation()
    return {aligned=math.abs((yaw-current.Yaw+180)%360-180)<2 and math.abs(pitch-((current.Pitch+180)%360-180))<2}
end
return Navigation
