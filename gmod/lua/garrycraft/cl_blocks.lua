local GC = GarryCraft
local sections = {}
local session
local instance
local acknowledged = 0
local opaque, transparent = {}, {}
local sortedFrom

local function collect()
    opaque, transparent, sortedFrom = {}, {}, nil
    for _, section in pairs(sections) do
        for _, mesh in ipairs(section.meshes) do
            local target = mesh.translucent and transparent or opaque
            target[#target + 1] = mesh
        end
    end
    GC.SetBlockLights(sections)
end

local function clear()
    for _, section in pairs(sections) do GC.DestroyRenderMeshes(section.meshes) end
    sections = {}
    collect()
end

hook.Add("PreRender", "GarryCraftBlockTransfers", function()
    if not IsValid(LocalPlayer()) or not LocalPlayer():GetNWBool("GarryCraft") or not GC.State then
        if session then clear() session = nil end
        return
    end
    if GC.VideoReset then return end
    if session ~= GC.State.session or instance ~= GC.State.renderInstance then
        clear()
        session, instance = GC.State.session, GC.State.renderInstance
        acknowledged = 0
    end
    local payload = garrycraft_bridge.receive(7)
    if not payload then return end
    local section, body = GC.RenderPacket(payload)
    if section.session ~= session or section.instance ~= instance then return end
    if section.sequence > acknowledged then
        if section.clear then clear() else
            local previous = sections[section.key]
            if previous then GC.DestroyRenderMeshes(previous.meshes) end
            sections[section.key] = {meshes = GC.BuildRenderMeshes(section.meshes, false, true, body), lights = section.lights}
            collect()
        end
        acknowledged = section.sequence
    end
    -- Repeat acknowledgments because the server may receive the clear packet after the client does.
    net.Start("garrycraft_world_ack")
    net.WriteUInt(acknowledged, 32)
    net.WriteString(instance)
    net.SendToServer()
end)

local function active(depth, skybox)
    return not depth and not skybox and not GC.VideoReset and GC.State and GC.State.linked
        and IsValid(LocalPlayer()) and LocalPlayer():GetNWBool("GarryCraft")
end
local function drawOpaque() GC.DrawRenderMeshes(opaque, false) end
hook.Add("PostDrawOpaqueRenderables", "GarryCraftOpaqueBlocks", function(depth, skybox)
    if not active(depth, skybox) then return end
    drawOpaque()
    render.RenderFlashlights(drawOpaque)
end)
hook.Add("PostDrawTranslucentRenderables", "GarryCraftTransparentBlocks", function(depth, skybox)
    if not active(depth, skybox) then return end
    local eye = EyePos()
    if not sortedFrom or eye:DistToSqr(sortedFrom) > 1 then
        for _, mesh in ipairs(transparent) do mesh.distance = eye:DistToSqr(mesh.center) end
        table.sort(transparent, function(a, b) return a.distance > b.distance end)
        sortedFrom = eye
    end
    GC.DrawRenderMeshes(transparent, false)
end)

function GC.BlockRenderReport()
    local report = {sections = table.Count(sections), lights = 0, vertices = 0, transparentFaces = #transparent,
        ack = acknowledged, gridHeight = GC.GridHeight, lighting = GC.LightReport()}
    for _, section in pairs(sections) do
        report.lights = report.lights + #section.lights
        for _, batch in ipairs(section.meshes) do report.vertices = report.vertices + batch.vertices end
    end
    return report
end
concommand.Add("garrycraft_blocks_report", function()
    file.Write("garrycraft-blocks.json", util.TableToJSON(GC.BlockRenderReport()))
end)
hook.Add("ShutDown", "GarryCraftBlockRenderCleanup", clear)
