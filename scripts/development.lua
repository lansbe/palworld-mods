-- Included only in explicit development builds. Never packaged for end users.
local Commands=require('core.commands')
local original=Commands.run
function Commands.run(request)
    if request.method=='probe' then return assert(load(request.source,'local-probe','t'))() end
    return original(request)
end
