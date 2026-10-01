local GC = GarryCraft
local textures = {}
local avatar = {}
local hands = {}
local avatarRevision, handsRevision
local handFov = 70
local instance
local session
local overlay
local overlayAt = 0
local overlayMaterials = {}
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

local function valid(header)
    local state = GC.State
    return state and header.session == state.session and header.instance == state.renderInstance
end

local function packet(payload)
    local boundary = assert(string.find(payload, "\n", 1, true), "Missing render packet header")
    return util.JSONToTable(string.sub(payload, 1, boundary - 1)), string.sub(payload, boundary + 1)
end

local function material(name, texture, shader)
    local result = CreateMaterial(name, shader, {['$basetexture'] = texture, ['$model'] = 1,
        ['$vertexcolor'] = 1, ['$vertexalpha'] = 0, ['$nocull'] = 1,
        ['$alphatest'] = 1, ['$alphatestreference'] = 0.1})
    return result
end

local function buildMeshes(batches, viewmodel, world, body)
    local result = {}
    for _, batch in ipairs(batches) do
        local mesh = Mesh(batch.unlit and colorFormat or meshFormat)
        garrycraft_bridge.build_mesh(mesh, body, batch.offset, batch.count, viewmodel and 2 or world and 1 or 0, GC.GridHeight)
        result[#result + 1] = {mesh = mesh, texture = batch.texture, translucent = batch.translucent, unlit = batch.unlit,
            vertices = batch.count, center = GC.ToSource(batch.x, batch.y, batch.z), lighting = {colors = {}}}
    end
    return result
end
GC.RenderPacket = packet
GC.BuildRenderMeshes = buildMeshes

function GC.DestroyRenderMeshes(batches)
    for _, batch in ipairs(batches) do batch.mesh:Destroy() end
end

function GC.DrawRenderMeshes(batches, unlit, position)
    local drawn = 0
    for _, batch in ipairs(batches) do
        local texture = textures[batch.texture]
        if texture then
            if not unlit and not batch.unlit then GC.PrepareLighting(position or batch.center, batch.lighting) end
            render.SetMaterial((unlit or batch.unlit) and (batch.translucent and texture.unlit or texture.emissive)
                or batch.translucent and texture.translucent or texture.opaque)
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
        waitingVideo = GC.State and GC.State.renderInstance
        GC.VideoReset = true
        overlay = nil
        if IsValid(LocalPlayer()) and LocalPlayer():GetNWBool("GarryCraft") then
            net.Start("garrycraft_render_reset") net.SendToServer()
        end
    end
    if not IsValid(LocalPlayer()) or not LocalPlayer():GetNWBool("GarryCraft") or not GC.State then
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
        overlay = nil
        stats = {textures = 0, vertices = 0, frames = 0}
        timing = {}
        GC.ClearWorldScene()
        GC.ClearBlockEffects()
    end
    local pixels = garrycraft_bridge.receive(4)
    if pixels then
        local header, rgba = packet(pixels)
        if valid(header) then
            local name = "garrycraft/" .. instance .. "/" .. util.CRC(session) .. "/" .. header.id
            local texture = garrycraft_bridge.upload(name, header.width, header.height, rgba)
            if not textures[header.id] then
                local opaque = material(name, texture, "VertexLitGeneric")
                local translucent = CreateMaterial(name .. "/alpha", "VertexLitGeneric", {['$basetexture'] = texture,
                    ['$model'] = 1, ['$translucent'] = 1, ['$vertexcolor'] = 1, ['$vertexalpha'] = 1, ['$nocull'] = 1})
                local unlit = CreateMaterial(name .. "/particle", "UnlitGeneric", {['$basetexture'] = texture,
                    ['$translucent'] = 1, ['$model'] = 1, ['$vertexcolor'] = 1, ['$vertexalpha'] = 1, ['$nocull'] = 1})
                local emissive = CreateMaterial(name .. "/emissive", "UnlitGeneric", {['$basetexture'] = texture,
                    ['$model'] = 1, ['$vertexcolor'] = 1, ['$alphatest'] = 1, ['$alphatestreference'] = 0.1})
                textures[header.id] = {opaque = opaque, translucent = translucent, unlit = unlit, emissive = emissive}
                stats.textures = stats.textures + 1
            end
            net.Start("garrycraft_texture_ack")
            net.WriteUInt(header.transfer, 24)
            net.WriteString(instance)
            net.SendToServer()
        end
    end
    local snapshot = garrycraft_bridge.receive(5)
    if snapshot then
        local before = SysTime()
        local scene, body = packet(snapshot)
        if valid(scene) then acceptAvatar(scene, body) end
        stats.sceneMs = (stats.sceneMs or 0) * 0.9 + (SysTime() - before) * 100
        stats.poses = (stats.poses or 0) + 1
    end
    local frame = garrycraft_bridge.receive(6)
    if frame then
        local before = SysTime()
        local header, rgba = packet(frame)
        if valid(header) then
            overlay = {}
            for _, tile in ipairs(header.tiles) do
                local name = "garrycraft/overlay/" .. instance .. "/" .. header.width .. "x" .. header.height .. "/" .. tile.x .. "/" .. tile.y
                local texture = garrycraft_bridge.upload(name, tile.width, tile.height,
                    string.sub(rgba, tile.offset + 1, tile.offset + tile.width * tile.height * 4), true)
                local material = overlayMaterials[name]
                if not material then
                    material = CreateMaterial(name, "UnlitGeneric", {['$basetexture'] = texture,
                        ['$translucent'] = 1, ['$vertexcolor'] = 1, ['$vertexalpha'] = 1, ['$ignorez'] = 1})
                    overlayMaterials[name] = material
                end
                overlay[#overlay + 1] = {material = material, x = tile.x, y = tile.y, width = tile.width, height = tile.height}
            end
            overlayAt = RealTime()
            stats.width, stats.height = header.width, header.height
            stats.frames = stats.frames + 1
            stats.overlayMs = (stats.overlayMs or 0) * 0.9 + (SysTime() - before) * 100
            GC.OverlayReady = true
        end
    end
end)

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
end)

hook.Add("PrePlayerDraw", "GarryCraftHideSourceBody", function(player)
    if player:GetNWBool("GarryCraft") then return true end
end)

hook.Add("PostDrawOpaqueRenderables", "GarryCraftAvatar", function(depth, skybox)
    if depth or skybox or GC.VideoReset or not GC.State or GC.State.camera == 0 or not GC.RenderFeet then return end
    if not IsValid(LocalPlayer()) or not LocalPlayer():GetNWBool("GarryCraft") or not LocalPlayer():Alive() then return end
    GC.PrepareLighting(GC.RenderFeet)
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
    render.RenderFlashlights(drawMeshes)
    cam.PopModelMatrix()
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
    stats.fps = GC.FrameStats
    stats.lights = GC.LightReport()
    stats.timing = timing
    file.Write("garrycraft-render.json", util.TableToJSON(stats))
    print("GarryCraft render: " .. util.TableToJSON(stats))
end)

hook.Add("ShutDown", "GarryCraftRenderCleanup", function()
    clearMeshes()
end)
