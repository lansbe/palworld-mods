local Game=require('core.game')
local Motion=require('core.motion')
local Navigation=require('core.navigation')
local Targets=require('core.targets')
local Inventory=require('core.inventory')
local Scanner=require('core.scanner')
local scanner=Scanner.new()
local Controls={}
function Controls.scan(arguments)
    local state=Game.state()
    assert(state.phase=='world' and not state.loading,'Join a world before observing')
    if scanner.generation~=state.generation then scanner=Scanner.new();scanner.generation=state.generation end
    local status=scanner:step(arguments)
    return {ready=status.ready,characters=Engine.array(scanner.characters),resources=Engine.array(scanner.resources)}
end
function Controls.gameplay()
    local _,player=Motion.player()
    local shooter,interaction=player.ShooterComponent,player.InteractComponent
    return {aiming=shooter:IsAiming(),shooting=shooter:IsShooting(),reloading=shooter:IsReloading(),
        can_shoot=shooter:CanShoot(),can_aim=shooter:CanAim(),melee=shooter:IsCurrentWeaponMelee(),
        can_reload=shooter:CanReload(),interacting=interaction:IsInteracting(),can_interact=interaction:IsEnableInteract(),
        interaction_target=Engine.valid(interaction.TargetInteractiveObject) and {object=Targets.remember(interaction.TargetInteractiveObject)} or nil}
end
function Controls.call(action,arguments)
    local handlers={inventory=Inventory.read,select_sphere=Inventory.ball,use_food=Inventory.food,scan=Controls.scan,
        character=function(args)return Scanner.character(Targets.get(args.target))end,state=Game.state,stop=Motion.stop,move=Motion.move,act=Motion.action,
        camera_follow=Motion.look,aim_at=Navigation.aim,path=Navigation.path,gameplay=Controls.gameplay,
        jump=function()return Motion.action({name='jump'})end}
    return assert(handlers[action],'Unknown player command')(arguments or {})
end
return Controls
