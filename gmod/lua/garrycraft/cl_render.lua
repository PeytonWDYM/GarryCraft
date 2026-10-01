local GC = GarryCraft
local textures = {}
local avatar = {}
local hands = {}
local handFov = 70
local instance
local session
local overlay
local overlayAt = 0
local lightingModel = ClientsideModel("models/player/kleiner.mdl", RENDERGROUP_OTHER)
lightingModel:SetNoDraw(true)
lightingModel:SetSolid(SOLID_NONE)
local stats = {textures = 0, vertices = 0, frames = 0}

local function clearMeshes()
    for _, batch in ipairs(avatar) do batch.mesh:Destroy() end
    for _, batch in ipairs(hands) do batch.mesh:Destroy() end
    avatar = {}
    hands = {}
end

local function valid(header)
    local state = GC.State
    return state and header.session == state.session and header.instance == state.instance
end

local function packet(payload)
    local boundary = assert(string.find(payload, "\n", 1, true), "Missing render packet header")
    return util.JSONToTable(string.sub(payload, 1, boundary - 1)), string.sub(payload, boundary + 1)
end

local function material(name, texture, shader)
    local result = CreateMaterial(name, shader, {['$basetexture'] = texture:GetName(), ['$model'] = 1,
        ['$vertexcolor'] = 1, ['$vertexalpha'] = 0, ['$nocull'] = 1,
        ['$alphatest'] = 1, ['$alphatestreference'] = 0.1})
    result:SetTexture("$basetexture", texture)
    return result
end

local function buildMeshes(batches, viewmodel)
    local result = {}
    local function position(vertex)
        if viewmodel then return Vector(-vertex[3] * 32, -vertex[1] * 32, vertex[2] * 32) end
        return GC.ToSource(vertex[1], vertex[2], vertex[3])
    end
    for _, batch in ipairs(batches) do
        local vertices = {}
        for index = 1, #batch.vertices, 3 do
            local a, b, c = batch.vertices[index], batch.vertices[index + 1], batch.vertices[index + 2]
            local normal = (position(b) - position(a)):Cross(position(c) - position(a)):GetNormalized()
            -- Source culls clockwise faces. Keep the outward normal and reverse Minecraft's winding.
            for _, vertex in ipairs({a, c, b}) do
                vertices[#vertices + 1] = {pos = position(vertex), normal = normal,
                    u = vertex[4], v = vertex[5], color = Color(vertex[6], vertex[7], vertex[8], vertex[9])}
            end
        end
        local mesh = Mesh()
        mesh:BuildFromTriangles(vertices)
        result[#result + 1] = {mesh = mesh, texture = batch.texture}
        stats.vertices = stats.vertices + #vertices
    end
    return result
end

local function acceptAvatar(scene)
    clearMeshes()
    stats.vertices = 0
    avatar = buildMeshes(scene.avatar, false)
    hands = buildMeshes(scene.hands, true)
    handFov = scene.handFov
end

hook.Add("PreRender", "GarryCraftRenderTransfers", function()
    if not IsValid(LocalPlayer()) or not LocalPlayer():GetNWBool("GarryCraft") or not GC.State then overlay = nil return end
    if instance ~= GC.State.instance or session ~= GC.State.session then
        clearMeshes()
        instance = GC.State.instance
        session = GC.State.session
        textures = {}
        overlay = nil
        stats = {textures = 0, vertices = 0, frames = 0}
    end
    local pixels = garrycraft_bridge.receive(4)
    if pixels then
        local header, rgba = packet(pixels)
        if valid(header) then
            if not textures[header.id] then
                local name = "garrycraft/" .. instance .. "/" .. util.CRC(session) .. "/" .. header.id
                local texture = garrycraft_bridge.upload(name, header.width, header.height, rgba)
                textures[header.id] = material(name, texture, "VertexLitGeneric")
                stats.textures = stats.textures + 1
            end
            net.Start("garrycraft_texture_ack")
            net.WriteUInt(header.id, 24)
            net.WriteString(instance)
            net.SendToServer()
        end
    end
    local snapshot = garrycraft_bridge.receive(5)
    if snapshot then
        local before = SysTime()
        local scene = util.JSONToTable(snapshot)
        if valid(scene) then acceptAvatar(scene) end
        stats.sceneMs = (stats.sceneMs or 0) * 0.9 + (SysTime() - before) * 100
        stats.poses = (stats.poses or 0) + 1
    end
    local frame = garrycraft_bridge.receive(6)
    if frame then
        local before = SysTime()
        local header, rgba = packet(frame)
        if valid(header) then
            local name = "garrycraft/overlay/" .. header.width .. "x" .. header.height
            local texture = garrycraft_bridge.upload(name, header.width, header.height, rgba, true)
            if not overlay or stats.width ~= header.width or stats.height ~= header.height then
                overlay = CreateMaterial(name, "UnlitGeneric", {['$basetexture'] = texture:GetName(),
                    ['$translucent'] = 1, ['$vertexcolor'] = 1, ['$vertexalpha'] = 1, ['$ignorez'] = 1})
                overlay:SetTexture("$basetexture", texture)
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
    if depth or skybox or not GC.State or GC.State.camera ~= 0 or not GC.ViewOrigin then return end
    if not IsValid(LocalPlayer()) or not LocalPlayer():GetNWBool("GarryCraft") or not LocalPlayer():Alive() then return end
    local fov = math.deg(2 * math.atan(math.tan(math.rad(handFov) / 2) * 4 / 3))
    cam.Start3D(GC.ViewOrigin, GC.ViewAngles, fov, 0, 0, ScrW(), ScrH(), 0.1, 4096)
    lightingModel:SetPos(GC.RenderFeet)
    render.SetLightingOrigin(GC.ViewOrigin)
    render.SetBlend(0)
    render.OverrideDepthEnable(true, false)
    lightingModel:DrawModel()
    render.OverrideDepthEnable(false, false)
    render.SetBlend(1)
    local transform = Matrix()
    transform:SetTranslation(GC.ViewOrigin)
    transform:SetAngles(GC.ViewAngles)
    cam.PushModelMatrix(transform)
    render.DepthRange(0, 0.01)
    local function drawHands()
        for _, batch in ipairs(hands) do
            local material = textures[batch.texture]
            if material then render.SetMaterial(material) batch.mesh:Draw() end
        end
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
    if depth or skybox or not GC.State or GC.State.camera == 0 or not GC.RenderFeet then return end
    if not IsValid(LocalPlayer()) or not LocalPlayer():GetNWBool("GarryCraft") or not LocalPlayer():Alive() then return end
    lightingModel:SetPos(GC.RenderFeet)
    render.SetLightingOrigin(GC.RenderFeet)
    render.SetBlend(0)
    render.OverrideDepthEnable(true, false)
    lightingModel:DrawModel()
    render.OverrideDepthEnable(false, false)
    render.SetBlend(1)
    local transform = Matrix()
    transform:SetTranslation(GC.RenderFeet)
    cam.PushModelMatrix(transform)
    local function drawMeshes()
        for _, batch in ipairs(avatar) do
            local material = textures[batch.texture]
            if material then render.SetMaterial(material) batch.mesh:Draw() end
        end
    end
    drawMeshes()
    render.RenderFlashlights(drawMeshes)
    cam.PopModelMatrix()
end)

hook.Add("HUDPaint", "GarryCraftMinecraftOverlay", function()
    if not IsValid(LocalPlayer()) or not LocalPlayer():GetNWBool("GarryCraft") or not overlay or not GC.State.linked then return end
    surface.SetMaterial(overlay)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
end)

hook.Add("HUDShouldDraw", "GarryCraftNativeHUD", function(name)
    if IsValid(LocalPlayer()) and LocalPlayer():GetNWBool("GarryCraft") and GC.OverlayReady and
        (name == "CHudHealth" or name == "CHudBattery" or name == "CHudAmmo" or name == "CHudSecondaryAmmo" or name == "CHudCrosshair") then return false end
end)

concommand.Add("garrycraft_render_report", function()
    stats.fps = GC.FrameStats
    file.Write("garrycraft-render.json", util.TableToJSON(stats))
    print("GarryCraft render: " .. util.TableToJSON(stats))
end)

hook.Add("ShutDown", "GarryCraftRenderCleanup", function()
    clearMeshes()
    lightingModel:Remove()
end)
