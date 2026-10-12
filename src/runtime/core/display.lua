local Registry=require('core.registry')
local Display={initialized=false}
local function settings()
    return assert(Registry.get('GameUserSettings')[1],'Display settings are not ready')
end
function Display.get()
    local value=settings()
    return {mode=value:GetFullscreenMode(),confirmed=value:GetLastConfirmedFullscreenMode(),resolution=value:GetScreenResolution()}
end
function Display.fullscreen()
    local value=settings()
    value:SetFullscreenMode(0)
    value:ApplyResolutionSettings(false)
    value:ConfirmVideoMode()
    value:SaveSettings()
    Display.initialized=true
    return Display.get()
end
function Display.start()
    if not Display.initialized and Registry.get('GameUserSettings')[1] then
        Display.fullscreen()
        Display.initialized=true
    end
end
return Display
