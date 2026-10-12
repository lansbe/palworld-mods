local Registry = require('core.registry')
local Tree = require('ui.tree')
local Game = {generation=0, previous=nil, traveling=false}
local function valid(value) return Engine.valid(value) end
function Game.controller()
    for _, controller in ipairs(Registry.get('PalPlayerController')) do
        if controller:IsLocalController() then return controller end
    end
end
function Game.subject(controller)
    if not valid(controller) then return end
    local body = controller.Pawn
    if not valid(body) then return end
    if Engine.is_a(body, 'PalPlayerCharacter') then return body, body, false end
    local rider = controller.GetRiderCharacter and controller:GetRiderCharacter()
    if valid(rider) and Engine.is_a(rider, 'PalPlayerCharacter') then return rider, body, true end
end
function Game.loading()
    for _, manager in ipairs(Registry.get('LoadingScreenManager')) do
        local reason = manager:GetDebugReasonForShowingOrHidingLoadingScreen()
        if reason ~= '' and reason ~= '(nothing wants to show it anymore)' then return true end
    end
    for _, instance in ipairs(Registry.get('PalGameInstance')) do
        if instance.IsStartingGame or valid(instance.CurrentLoadingTask) then return true end
    end
    return false
end
function Game.state()
    local controller = Game.controller()
    local player, body, mounted = Game.subject(controller)
    local loading = Game.loading()
    local result = {phase='transition', playable=false, loading=loading, mounted=mounted == true, generation=Game.generation}
    if not player then
        for _,widget in ipairs(Registry.get('WBP_TitleMenu_C')) do
            if Tree.visible(widget) then result.phase='title';result.title_ready=not loading;break end
        end
        return result
    end
    local parameter = player.CharacterParameterComponent
    local dead = valid(parameter) and (parameter:IsDead() or parameter:IsDying())
    local blocked = false
    local passive = {WBP_PalInteractiveObjectIndicatorCanvas_C=true, WBP_PalHUD_InGame_InputListener_C=true}
    for _, widget in ipairs(Registry.get('PalUserWidgetStackableUI')) do
        if not passive[widget.class.name] and widget:IsActivated() and Tree.visible(widget) then blocked=true; break end
    end
    local state = controller.PlayerState
    result.in_dungeon = valid(state) and state:IsInStateByStageType(1) or false
    result.playable = not loading and not dead and not blocked
    result.dead, result.menu = dead == true, blocked
    result.phase='world';result.in_combat=player.bIsBattleMode
    result.position = body:K2_GetActorLocation()
    result.rotation = controller:GetControlRotation()
    result.pose={position={x=result.position.X,y=result.position.Y,z=result.position.Z},
        camera={yaw=result.rotation.Yaw,pitch=result.rotation.Pitch,roll=result.rotation.Roll}}
    result.health = valid(parameter) and parameter:GetHPRate() or 0
    result.hp_ratio=result.health
    return result
end
function Game.update()
    local controller = Game.controller()
    local key = controller and controller.key
    local changed = Game.previous ~= key
    if changed then Game.generation=Game.generation+1; Game.previous=key end
    return changed
end
return Game
