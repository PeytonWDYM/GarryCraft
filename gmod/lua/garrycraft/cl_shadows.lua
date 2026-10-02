local GC = GarryCraft
local material = CreateMaterial("garrycraft/planar-shadow", "UnlitGeneric", {
    ['$basetexture'] = "color/white", ['$color'] = "[0 0 0]", ['$alpha'] = .35,
    ['$translucent'] = 1, ['$nocull'] = 1, ['$model'] = 1})
local selected, nextSelection, revision = {}, 0, -1
local report = {avatar = 0, blocks = 0, milliseconds = 0, receiverLimit = 64, mode = "planar"}
local zero = Vector(0, 0, 0)
local enabled = CreateClientConVar("garrycraft_planar_shadows", "1", true, false,
    "Draw nearby Minecraft silhouettes on Source receiver planes", 0, 1)

local function receiver(position, avatar)
    local trace = util.TraceLine({start = position + Vector(0, 0, 8), endpos = position - Vector(0, 0, 1024),
        mask = MASK_SOLID_BRUSHONLY})
    local block = garrycraft_bridge.shadow_receiver(position + Vector(0, 0, avatar and .5 or -.5))
    if block and (not trace.Hit or trace.StartSolid or block.z > trace.HitPos.z) then
        return {HitPos = block, HitNormal = Vector(0, 0, 1), minecraft = true}
    end
    if trace.Hit and not trace.StartSolid and trace.HitNormal.z > .5 then return trace end
end

-- Each caster uses one receiver plane. Silhouettes do not clip or wrap across changes in receiver height.
local function projection(origin, trace, direction)
    local normal = trace.HitNormal
    local denominator = normal:Dot(direction)
    if denominator >= -.05 then return end
    local transform = Matrix()
    for row = 1, 3 do for column = 1, 3 do
        transform:SetField(row, column, (row == column and 1 or 0) - direction[row] * normal[column] / denominator)
    end end
    transform:SetTranslation(origin + direction * normal:Dot(trace.HitPos - origin) / denominator + normal * .15)
    return transform
end

local function draw(batches, transform)
    cam.PushModelMatrix(transform)
    local vertices = 0
    for _, batch in ipairs(batches) do
        if not batch.unlit then batch.mesh:Draw() vertices = vertices + batch.vertices end
    end
    cam.PopModelMatrix()
    return vertices
end

hook.Add("PostDrawTranslucentRenderables", "GarryCraftShadows", function(depth, skybox)
    if not enabled:GetBool() then report.avatar, report.blocks, report.minecraftReceivers = 0, 0, 0 return end
    if depth or skybox or GC.VideoReset or not GC.State or not GC.State.linked or not GC.RenderFeet then return end
    if not IsValid(LocalPlayer()) or not LocalPlayer():GetNWBool("GarryCraft") or not LocalPlayer():Alive() then return end
    local start = SysTime()
    local sun = util.GetSunInfo()
    local direction = sun and -sun.direction or Vector(.35, .25, -1):GetNormalized()
    if RealTime() >= nextSelection or revision ~= GC.LightRevision() then
        nextSelection, revision, selected = RealTime() + .25, GC.LightRevision(), {}
        local eye, candidates = EyePos(), {}
        for _, batch in ipairs(GC.BlockShadowMeshes()) do
            local distance = eye:DistToSqr(batch.center)
            if not batch.unlit and distance < 1024 * 1024 then
                candidates[#candidates + 1] = {batch = batch, distance = distance}
            end
        end
        table.sort(candidates, function(a, b) return a.distance < b.distance end)
        for index = 1, math.min(report.receiverLimit, #candidates) do
            local batch = candidates[index].batch
            local trace = receiver(batch.center)
            if trace then
                local transform = projection(zero, trace, direction)
                if transform then selected[#selected + 1] = {batch = batch, transform = transform, minecraft = trace.minecraft} end
            end
        end
    end
    render.ClearStencil()
    render.SetStencilEnable(true)
    render.SetStencilWriteMask(1)
    render.SetStencilTestMask(1)
    render.SetStencilReferenceValue(0)
    render.SetStencilCompareFunction(STENCIL_EQUAL)
    render.SetStencilPassOperation(STENCIL_INCRSAT)
    render.SetStencilFailOperation(STENCIL_KEEP)
    render.SetStencilZFailOperation(STENCIL_KEEP)
    render.SetMaterial(material)
    report.avatar, report.blocks, report.minecraftReceivers = 0, 0, 0
    local trace = receiver(GC.RenderFeet, true)
    if trace then
        local transform = projection(GC.RenderFeet, trace, direction)
        if transform then
            report.avatar = draw(GC.AvatarMeshes(), transform)
            report.avatarReceiver = trace.minecraft and "minecraft" or "source"
        end
    end
    for _, caster in ipairs(selected) do
        report.blocks = report.blocks + draw({caster.batch}, caster.transform)
        if caster.minecraft then report.minecraftReceivers = report.minecraftReceivers + 1 end
    end
    render.SetStencilEnable(false)
    render.SetStencilWriteMask(255)
    render.SetStencilTestMask(255)
    render.SetStencilReferenceValue(0)
    render.SetStencilCompareFunction(STENCIL_ALWAYS)
    render.SetStencilPassOperation(STENCIL_KEEP)
    report.milliseconds = (SysTime() - start) * 1000
end)

function GC.ShadowReport() return report end

-- Test probes use the same plane and direction as the silhouette pass.
function GC.ProjectShadowPoint(position, feet)
    local trace = receiver(feet, true)
    if not trace then return end
    local sun = util.GetSunInfo()
    local direction = sun and -sun.direction or Vector(.35, .25, -1):GetNormalized()
    local normal = trace.HitNormal
    return position + direction * normal:Dot(trace.HitPos - position) / normal:Dot(direction)
end
