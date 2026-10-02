local GC = GarryCraft
local textures = {}
local materialTints = {}
local avatar = {}
local hands = {}
local avatarRevision, handsRevision
local avatarDepthDraws = 0
local shadowOwner
local handFov = 70
local instance
local session
local overlay
local overlayAt = 0
local overlayMaterials = {}
local overlayRevisions = {}
local waitingVideo
local stats = {textures = 0, vertices = 0, frames = 0}
local timing = {}
local nextTiming = 0
local meshFormat = CreateMaterial("garrycraft/mesh-format", "VertexLitGeneric", {
    ['$basetexture'] = "color/white", ['$model'] = 1, ['$vertexcolor'] = 1, ['$vertexalpha'] = 1, ['$translucent'] = 1})
local colorFormat = CreateMaterial("garrycraft/color-format", "UnlitGeneric", {
    ['$basetexture'] = "color/white", ['$model'] = 1, ['$vertexcolor'] = 1, ['$vertexalpha'] = 1, ['$translucent'] = 1})

local function clearMeshes()
    for _, batch in ipairs(avatar) do batch.mesh:Destroy() end
    for _, batch in ipairs(hands) do batch.mesh:Destroy() end
    avatar = {}
    hands = {}
    avatarRevision, handsRevision = nil, nil
end

function GC.TextureName(id, width, height)
    return "garrycraft/runtime/" .. id .. "/" .. width .. "x" .. height
end

local function valid(header)
    local state = GC.State
    return state and header.session == state.session and header.instance == state.renderInstance
end

local function packet(lane)
    local header, body = garrycraft_bridge.receive_render(lane)
    if header then return util.JSONToTable(header), body end
end

local function material(name, texture, shader)
    local result = CreateMaterial(name, shader, {['$basetexture'] = texture, ['$model'] = 1,
        ['$vertexcolor'] = 1, ['$vertexalpha'] = 0, ['$nocull'] = 1,
        ['$alphatest'] = 1, ['$alphatestreference'] = 0.1})
    result:SetTexture("$basetexture", texture)
    return result
end

local function buildMeshes(batches, viewmodel, world, body)
    local result = {}
    for _, batch in ipairs(batches) do
        local mesh = Mesh(batch.unlit and colorFormat or meshFormat)
        garrycraft_bridge.build_mesh(mesh, body, batch.offset, batch.count, viewmodel and 2 or world and 1 or 0, GC.GridHeight)
        result[#result + 1] = {mesh = mesh, texture = batch.texture, translucent = batch.translucent, unlit = batch.unlit,
            tintId = batch.tint,
            tint = Vector(bit.rshift(batch.tint, 16) / 255, bit.band(bit.rshift(batch.tint, 8), 255) / 255, bit.band(batch.tint, 255) / 255),
            vertices = batch.count, center = GC.ToSource(batch.x, batch.y, batch.z), lighting = {colors = {}}}
    end
    return result
end
GC.ReceiveRenderPacket = packet
GC.BuildRenderMeshes = buildMeshes

function GC.DestroyRenderMeshes(batches)
    for _, batch in ipairs(batches) do batch.mesh:Destroy() end
end

function GC.DrawRenderMeshes(batches, unlit, position, depth)
    local drawn = 0
    for _, batch in ipairs(batches) do
        local texture = textures[batch.texture]
        if texture then
            if not depth and not unlit and not batch.unlit then
                local samplePosition = position or batch.center + (EyePos() - batch.center):GetNormalized() * .5
                GC.PrepareLighting(samplePosition, batch.lighting)
            end
            local material = (unlit or batch.unlit) and (batch.translucent and texture.unlit or texture.emissive)
                or batch.translucent and texture.translucent or texture.opaque
            if materialTints[material] ~= batch.tintId then
                material:SetVector("$color2", batch.tint)
                materialTints[material] = batch.tintId
            end
            render.SetMaterial(material)
            batch.mesh:Draw()
            drawn = drawn + batch.vertices
        end
    end
    return drawn
end

local function acceptAvatar(scene, body)
    if avatarRevision ~= scene.avatar.revision then
        GC.DestroyRenderMeshes(avatar) avatar = buildMeshes(scene.avatar.batches, false, false, body) avatarRevision = scene.avatar.revision
    end
    if handsRevision ~= scene.hands.revision then
        GC.DestroyRenderMeshes(hands) hands = buildMeshes(scene.hands.batches, true, false, body) handsRevision = scene.hands.revision
    end
    stats.vertices = 0
    for _, group in ipairs({avatar, hands}) do
        for _, batch in ipairs(group) do stats.vertices = stats.vertices + batch.vertices end
    end
    handFov = scene.handFov
    GC.AcceptWorldScene(scene, body)
    GC.AcceptBlockEffects(scene, body)
end

hook.Add("PreRender", "GarryCraftRenderTransfers", function()
    if garrycraft_bridge.textures_reset() then
        overlayRevisions = {}
        waitingVideo = GC.State and GC.State.renderInstance
        GC.VideoReset = true
        overlay = nil
        if IsValid(LocalPlayer()) and LocalPlayer():GetNWBool("GarryCraft") then
            net.Start("garrycraft_render_reset") net.SendToServer()
        end
    end
    if not IsValid(LocalPlayer()) or not LocalPlayer():GetNWBool("GarryCraft") or not GC.State then
        if instance then clearMeshes() GC.ClearWorldScene() GC.ClearBlockEffects() instance = nil end
        GC.OverlayReady = false
        overlay = nil waitingVideo = nil return
    end
    if waitingVideo == GC.State.renderInstance then return end
    waitingVideo = nil
    GC.VideoReset = false
    if instance ~= GC.State.renderInstance or session ~= GC.State.session then
        clearMeshes()
        instance = GC.State.renderInstance
        session = GC.State.session
        textures = {}
        materialTints = {}
        overlayRevisions = {}
        overlay = nil
        stats = {textures = 0, vertices = 0, frames = 0}
        timing = {}
        GC.ClearWorldScene()
        GC.ClearBlockEffects()
    end
    local header, rgba = packet(4)
    if header then
        if valid(header) then
            local name = GC.TextureName(header.id, header.width, header.height)
            local texture = garrycraft_bridge.upload(name, header.width, header.height, rgba)
            stats.textureUpdates = stats.textureUpdates or {}
            stats.textureUpdates[header.id] = (stats.textureUpdates[header.id] or 0) + 1
            if not textures[header.id] then
                local opaque = material(name, texture, "VertexLitGeneric")
                local translucent = CreateMaterial(name .. "/alpha", "VertexLitGeneric", {['$basetexture'] = texture,
                    ['$model'] = 1, ['$translucent'] = 1, ['$vertexcolor'] = 1, ['$vertexalpha'] = 1, ['$nocull'] = 1})
                local unlit = CreateMaterial(name .. "/particle", "UnlitGeneric", {['$basetexture'] = texture,
                    ['$translucent'] = 1, ['$model'] = 1, ['$vertexcolor'] = 1, ['$vertexalpha'] = 1, ['$nocull'] = 1})
                local emissive = CreateMaterial(name .. "/emissive", "UnlitGeneric", {['$basetexture'] = texture,
                    ['$model'] = 1, ['$vertexcolor'] = 1, ['$alphatest'] = 1, ['$alphatestreference'] = 0.1})
                translucent:SetTexture("$basetexture", texture)
                unlit:SetTexture("$basetexture", texture)
                emissive:SetTexture("$basetexture", texture)
                textures[header.id] = {opaque = opaque, translucent = translucent, unlit = unlit, emissive = emissive, name = name}
                stats.textures = stats.textures + 1
            end
            net.Start("garrycraft_texture_ack")
            net.WriteUInt(header.transfer, 24)
            net.WriteString(instance)
            net.SendToServer()
        end
        garrycraft_bridge.release_packet(rgba)
    end
    local scene, body = packet(5)
    if scene then
        local before = SysTime()
        if valid(scene) then acceptAvatar(scene, body) end
        garrycraft_bridge.release_packet(body)
        stats.sceneMs = (stats.sceneMs or 0) * 0.9 + (SysTime() - before) * 100
        stats.poses = (stats.poses or 0) + 1
    end
    local header, rgba = packet(6)
    if header then
        local before = SysTime()
        if valid(header) then
            overlay = {}
            for _, tile in ipairs(header.tiles) do
                local name = "garrycraft/overlay/runtime/" .. header.width .. "x" .. header.height .. "/" .. tile.x .. "/" .. tile.y
                local material = overlayMaterials[name]
                if overlayRevisions[name] ~= tile.revision then
                    local texture = garrycraft_bridge.upload(name, tile.width, tile.height,
                        rgba, true, tile.offset, tile.width * tile.height * 4)
                    overlayRevisions[name] = tile.revision
                    stats.tileUploads = (stats.tileUploads or 0) + 1
                    if not material then
                        material = CreateMaterial(name, "UnlitGeneric", {['$basetexture'] = texture,
                            ['$translucent'] = 1, ['$vertexcolor'] = 1, ['$vertexalpha'] = 1, ['$ignorez'] = 1})
                        overlayMaterials[name] = material
                    end
                    material:SetTexture("$basetexture", texture)
                end
                overlay[#overlay + 1] = {material = material, x = tile.x, y = tile.y, width = tile.width, height = tile.height}
            end
            overlayAt = RealTime()
            stats.width, stats.height = header.width, header.height
            stats.frames = stats.frames + 1
            GC.OverlayFrame = header.frame
            GC.OverlayAgeMs = (garrycraft_bridge.clock() - header.capturedAt) * 1000
            stats.overlayAgeMs = GC.OverlayAgeMs
            stats.overlayMs = (stats.overlayMs or 0) * 0.9 + (SysTime() - before) * 100
            GC.OverlayReady = true
        end
        garrycraft_bridge.release_packet(rgba)
    end
end)
function GC.RenderTexture(id) return textures[id] end
function GC.AvatarMeshes() return avatar end
function GC.AvatarReport()
    local vertices = 0
    for _, batch in ipairs(avatar) do vertices = vertices + batch.vertices end
    return {vertices = vertices, camera = GC.State.camera, depthDraws = avatarDepthDraws,
        sourceShadowDisabled = LocalPlayer():IsEffectActive(EF_NOSHADOW)}
end

-- Minecraft supplies the hand animation. Source supplies its camera and lighting.
hook.Add("PostDrawTranslucentRenderables", "GarryCraftHands", function(depth, skybox)
    if depth or skybox or GC.VideoReset or not GC.State or GC.State.camera ~= 0 or not GC.ViewOrigin then return end
    if not IsValid(LocalPlayer()) or not LocalPlayer():GetNWBool("GarryCraft") or not LocalPlayer():Alive() then return end
    local fov = math.deg(2 * math.atan(math.tan(math.rad(handFov) / 2) * 4 / 3))
    cam.Start3D(GC.ViewOrigin, GC.ViewAngles, fov, 0, 0, ScrW(), ScrH(), 0.1, 4096)
    GC.PrepareLighting(GC.ViewOrigin)
    local transform = Matrix()
    transform:SetTranslation(GC.ViewOrigin)
    transform:SetAngles(GC.ViewAngles)
    cam.PushModelMatrix(transform)
    render.DepthRange(0, 0.01)
    local function drawHands()
        for _, batch in ipairs(hands) do
            local material = textures[batch.texture]
            if material then render.SetMaterial(material.opaque) batch.mesh:Draw() end
        end
    end
    if RealTime() >= nextTiming then
        nextTiming = RealTime() + 0.5
        timing[#timing + 1] = {time = RealTime(), fps = GC.FrameStats, sceneMs = stats.sceneMs,
            overlayMs = stats.overlayMs, blocks = GC.BlockRenderReport()}
        if #timing > 180 then table.remove(timing, 1) end
    end
    drawHands()
    render.RenderFlashlights(drawHands)
    render.DepthRange(0, 1)
    cam.PopModelMatrix()
    cam.End3D()
    GC.RestoreLighting()
end)

hook.Add("PrePlayerDraw", "GarryCraftHideSourceBody", function(player)
    if player:GetNWBool("GarryCraft") then return true end
end)

-- The server owns EF_NOSHADOW. Remove the existing client shadow handle at bridge transitions.
hook.Add("Think", "GarryCraftHideSourceShadow", function()
    local player = LocalPlayer()
    local linked = IsValid(player) and player:GetNWBool("GarryCraft")
    if shadowOwner and (shadowOwner ~= player or not linked) then
        if IsValid(shadowOwner) then
            shadowOwner:DrawShadow(true)
        end
        shadowOwner = nil
    end
    if linked and not shadowOwner then
        player:DrawShadow(false)
        player:DestroyShadow()
        shadowOwner = player
    end
end)

hook.Add("PostDrawOpaqueRenderables", "GarryCraftAvatar", function(depth, skybox)
    if skybox or GC.VideoReset or not GC.State or (GC.State.camera == 0 and not depth) or not GC.RenderFeet then return end
    if not IsValid(LocalPlayer()) or not LocalPlayer():GetNWBool("GarryCraft") or not LocalPlayer():Alive() then return end
    if not depth then GC.PrepareLighting(GC.RenderFeet + Vector(0, 0, 32)) end
    local transform = Matrix()
    transform:SetTranslation(GC.RenderFeet)
    cam.PushModelMatrix(transform)
    local function drawMeshes()
        for _, batch in ipairs(avatar) do
            local material = textures[batch.texture]
            if material then render.SetMaterial(material.opaque) batch.mesh:Draw() end
        end
    end
    drawMeshes()
    if depth then avatarDepthDraws = avatarDepthDraws + 1 else render.RenderFlashlights(drawMeshes) end
    cam.PopModelMatrix()
    GC.RestoreLighting()
end)

hook.Add("HUDPaint", "GarryCraftMinecraftOverlay", function()
    if not IsValid(LocalPlayer()) or not LocalPlayer():GetNWBool("GarryCraft") or not overlay or not GC.State.linked then return end
    surface.SetDrawColor(255, 255, 255, 255)
    local scaleX, scaleY = ScrW() / stats.width, ScrH() / stats.height
    for _, tile in ipairs(overlay) do
        surface.SetMaterial(tile.material)
        surface.DrawTexturedRect(tile.x * scaleX, tile.y * scaleY, tile.width * scaleX, tile.height * scaleY)
    end
end)

hook.Add("HUDShouldDraw", "GarryCraftNativeHUD", function(name)
    if IsValid(LocalPlayer()) and LocalPlayer():GetNWBool("GarryCraft") and GC.OverlayReady and
        (name == "CHudHealth" or name == "CHudBattery" or name == "CHudAmmo" or name == "CHudSecondaryAmmo" or name == "CHudCrosshair") then return false end
end)

concommand.Add("garrycraft_render_report", function()
    stats.session = session
    stats.polishRequest = GC.State.polishRequest
    stats.fps = GC.FrameStats
    stats.lights = GC.LightReport()
    stats.timing = timing
    file.Write("garrycraft-render.json", util.TableToJSON(stats))
    print("GarryCraft render: " .. util.TableToJSON(stats))
end)

hook.Add("ShutDown", "GarryCraftRenderCleanup", function()
    if IsValid(shadowOwner) then
        shadowOwner:DrawShadow(true)
    end
    clearMeshes()
end)
