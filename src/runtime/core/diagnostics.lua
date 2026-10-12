local Diagnostics = {errors={}, samples={}}
function Diagnostics.guard(label, fn, ...)
    local ok, value = xpcall(fn, debug.traceback, ...)
    if not ok then
        local now = Engine.clock()
        local previous = Diagnostics.errors[label]
        if not previous or previous.message ~= value or now - previous.time >= 10 then
            print('[PalMods] ' .. label .. ': ' .. tostring(value))
        end
        Diagnostics.errors[label] = {message=tostring(value), time=now}
    end
    return ok, value
end
function Diagnostics.measure(label, fn)
    local start = Engine.clock()
    local ok, value = Diagnostics.guard(label, fn)
    local elapsed = (Engine.clock() - start) * 1000
    local sample = Diagnostics.samples[label] or {count=0, total_ms=0, max_ms=0}
    sample.count = sample.count + 1
    sample.total_ms = sample.total_ms + elapsed
    sample.max_ms = math.max(sample.max_ms, elapsed)
    sample.mean_ms = sample.total_ms / sample.count
    Diagnostics.samples[label] = sample
    return ok, value
end
return Diagnostics
