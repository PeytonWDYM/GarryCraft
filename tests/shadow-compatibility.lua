-- Run with the player's enabled addons in a marked single-player lab.
assert(CLIENT and game.SinglePlayer(), "Use an owned single-player lab")
local failure = RunString(file.Read("garrycraft-source-shadow-path.lua", "DATA"), "source-shadow-path", false)
file.Write("garrycraft-shadow-compatibility.json", util.TableToJSON({
    registered = failure == nil, failure = failure or garrycraft_bridge.shadow_stats().installFailure,
    native = garrycraft_bridge.shadow_stats(), addons = engine.GetAddons(),
    dlibLoaded = DLib ~= nil, queuedRendering = GetConVar("mat_queue_mode"):GetInt(),
    engineVersion = VERSIONSTR,
    fixtureCalls = garrycraft_shadow_test and garrycraft_shadow_test.model_calls() or nil
}, true))
