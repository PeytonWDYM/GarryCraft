local GC = GarryCraft
local enabled = CreateClientConVar("garrycraft_source_shadows", "1", true, false,
    "Enable Source engine shadows for Minecraft model proxies", 0, 1)

GC.SetSourceModelShadows(enabled:GetBool())
cvars.AddChangeCallback("garrycraft_source_shadows", function(_, _, value)
    GC.SetSourceModelShadows(tonumber(value) == 1)
    GC.SetPhysicsBlockShadows(tonumber(value) == 1)
end, "GarryCraftSourceShadows")

-- Source owns silhouette projection, clipping, receiver selection, and shadow atlas allocation.
function GC.ShadowReport()
    local models = GC.SourceModelReport()
    return {mode = "source", enabled = enabled:GetBool(), avatar = models.avatar, blocks = models.world,
        items = models.item, pending = models.pending, retiring = models.retiring,
        created = models.created, rebound = models.rebound, colorDraws = models.colorDraws,
        native = garrycraft_bridge.shadow_stats()}
end
