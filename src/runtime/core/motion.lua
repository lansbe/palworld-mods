local Game=require('core.game')
local Motion={held={}}
local function finite(value,low,high)
    assert(type(value)=='number' and value==value and value>=low and value<=high,'Input is out of range')
    return value
end
function Motion.player()
    local controller=Game.controller()
    local player,body,mounted=Game.subject(controller)
    assert(player and not mounted,'An on-foot player is required')
    assert(Game.state().playable,'Wait until the player is ready and menus are closed')
    return controller,player,body
end
local function release(name)
    local held=Motion.held[name];Motion.held[name]=nil
    if held and Engine.valid(held.owner) then held.release(held.owner) end
end
function Motion.hold(name,owner,start,finish,seconds)
    finite(seconds,.05,2);release(name)
    Motion.held[name]={owner=owner,release=finish,until_time=Engine.clock()+seconds}
    local ok,failure=pcall(start,owner)
    if not ok then Motion.held[name]=nil;error(failure) end
end
function Motion.stop()
    Motion.camera=nil
    local movement=Motion.movement;Motion.movement=nil
    if movement and Engine.valid(movement.controller) then Engine.axes(movement.controller,0,0) end
    local keys={};for key in pairs(Motion.held) do keys[#keys+1]=key end
    for _,key in ipairs(keys) do release(key) end
    return {stopped=true}
end
function Motion.move(command)
    local controller,player=Motion.player()
    assert(not controller:IsMoveInputIgnored(),'Movement is blocked by the game')
    local forward=finite(command.forward or 0,-1,1)
    local right=finite(command.right or 0,-1,1)
    local seconds=finite(command.seconds or .2,.05,2)
    local yaw=math.rad(controller:GetControlRotation().Yaw)
    local x,y=forward*math.cos(yaw)-right*math.sin(yaw),forward*math.sin(yaw)+right*math.cos(yaw)
    local length=math.max(1,math.sqrt(x*x+y*y))
    Motion.movement={controller=controller,player=player,x=x/length,y=y/length,until_time=Engine.clock()+seconds}
    return {accepted=true}
end
function Motion.look(command)
    local controller=Motion.player()
    assert(not controller:IsLookInputIgnored(),'Camera is blocked by the game')
    local yaw=finite(command.yaw,-360,360)
    local pitch=finite(command.pitch or -12,-60,60)
    if command.smooth==false then controller:SetControlRotation({Yaw=yaw,Pitch=pitch,Roll=0});Motion.camera=nil
    else
        local now=Engine.clock()
        Motion.camera={controller=controller,yaw=yaw,pitch=pitch,last=now,until_time=now+finite(command.seconds or .4,.1,2)}
    end
    return {accepted=true}
end
function Motion.action(command)
    local controller,player=Motion.player()
    local action=assert(command.name,'Missing action')
    local seconds=finite(command.seconds or .15,.05,2)
    assert(not controller:IsMoveInputIgnored(),'Actions are blocked by the game')
    if action=='interact' then
        local component=player.InteractComponent
        assert(component:IsEnableInteract() and Engine.valid(component.TargetInteractiveObject),'No interaction is available')
        local kind=finite(command.kind or 1,1,4);assert(kind==math.floor(kind),'Invalid interaction type')
        Motion.hold(action,component,function(o)o:StartTriggerInteract(kind,false)end,function(o)o:EndTriggerInteract(kind)end,seconds)
    elseif action=='weapon_next' then controller:OnPressedWeaponNextButtonKeyboard()
    elseif action=='weapon_previous' then controller:OnPressedWeaponPrevButton()
    elseif action=='pal' then
        Motion.hold(action,controller,function(o)o:OnOtomo_Pressed()end,function(o)o:OnOtomo_ShortReleased()end,seconds)
    else
        Motion.hold(action,controller,function(o)Engine.input(o,action,true)end,function(o)Engine.input(o,action,false)end,seconds)
    end
    return {accepted=true}
end
local function angle(value) return (value+180)%360-180 end
function Motion.tick()
    if not Motion.camera and not Motion.movement and not next(Motion.held) then return end
    local now=Engine.clock()
    local state=Game.state()
    if not state.playable then Motion.stop();return end
    local expired={}
    for key,held in pairs(Motion.held) do if now>=held.until_time then expired[#expired+1]=key end end
    for _,key in ipairs(expired) do release(key) end
    local goal=Motion.camera
    if goal then
        if now>=goal.until_time or not Engine.valid(goal.controller) or goal.controller:IsLookInputIgnored() then Motion.camera=nil
        else
            local rotation=goal.controller:GetControlRotation()
            local dt=math.max(0,math.min(.05,now-goal.last));goal.last=now
            local alpha=1-math.exp(-dt/.12)
            local function step(delta,speed) return math.max(-speed*dt,math.min(speed*dt,delta*alpha)) end
            goal.controller:SetControlRotation({Yaw=angle(rotation.Yaw+step(angle(goal.yaw-rotation.Yaw),220)),
                Pitch=angle(rotation.Pitch)+step(goal.pitch-angle(rotation.Pitch),100),Roll=0})
        end
    end
    local movement=Motion.movement
    if movement then
        local controller=movement.controller
        if now>=movement.until_time or not Engine.valid(controller) or controller:IsMoveInputIgnored() then
            Motion.movement=nil;if Engine.valid(controller) then Engine.axes(controller,0,0) end
        else
            local yaw=math.rad(controller:GetControlRotation().Yaw)
            Engine.axes(controller,movement.x*math.cos(yaw)+movement.y*math.sin(yaw),-movement.x*math.sin(yaw)+movement.y*math.cos(yaw))
        end
    end
end
return Motion
