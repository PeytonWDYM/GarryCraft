local GC = GarryCraft
local leftArm, rightArm = {}, {}
local leftRevision, rightRevision
local retired = {}
local lastGrips, lastGunBones = {}, {}
local lastGripAt, armsDrawn = 0, 0
local hookCalls, drawStatus, rearElbowError = 0, "not-called", 0
local support

-- The installed citizen skeleton supplies the gun's merged support pose, independently
-- of the selected player model and its optional hands entity.
hook.Add("Think", "GarryCraftPhysgunArmSupport", function()
    local player = LocalPlayer()
    if not IsValid(player) or not player:GetNWBool("GarryCraft") then
        if IsValid(support) then support:Remove() end
        support = nil
        return
    end
    if not IsValid(support) then
        support = ClientsideModel("models/weapons/c_arms_citizen.mdl", RENDERGROUP_OTHER)
        if not IsValid(support) then return end
        support:SetNoDraw(true)
        support:AddEffects(EF_BONEMERGE)
    end
    support:SetParent(player:GetViewModel())
end)

hook.Add("Think", "GarryCraftPhysgunArmRetirement", function()
    for _, batches in ipairs(retired) do GC.DestroyRenderMeshes(batches) end
    retired = {}
end)

function GC.ClearPhysgunArms()
    retired[#retired + 1], retired[#retired + 2] = leftArm, rightArm
    leftArm, rightArm = {}, {}
    leftRevision, rightRevision = nil, nil
    lastGrips, lastGunBones, lastGripAt, armsDrawn = {}, {}, 0, 0
    drawStatus = "cleared"
end

function GC.AcceptPhysgunArms(scene, body)
    if leftRevision ~= scene.leftArm.revision then
        retired[#retired + 1] = leftArm
        leftArm = GC.BuildRenderMeshes(scene.leftArm.batches, false, false, body)
        leftRevision = scene.leftArm.revision
    end
    if rightRevision ~= scene.rightArm.revision then
        retired[#retired + 1] = rightArm
        rightArm = GC.BuildRenderMeshes(scene.rightArm.batches, false, false, body)
        rightRevision = scene.rightArm.revision
    end
end

-- The native gun contains a left-hand skeleton. Its rear grip uses the animated gun bone,
-- since the support skeleton's unmerged right-hand bones remain in their resting pose.
local function armPose(viewmodel)
    if #leftArm == 0 or #rightArm == 0 then return nil, "missing-mesh" end
    for _, arm in ipairs({leftArm, rightArm}) do
        for _, batch in ipairs(arm) do
            if not GC.RenderTexture(batch.texture) then return nil, "missing-texture" end
        end
    end
    if not IsValid(support) then return nil, "pending-support" end
    support:SetupBones()
    local handBone = support:LookupBone("ValveBiped.Bip01_L_Hand")
    local forearmBone = support:LookupBone("ValveBiped.Bip01_L_Forearm")
    if not handBone or not forearmBone then return nil, "missing-support-bone" end
    local hand, forearm = support:GetBoneMatrix(handBone), support:GetBoneMatrix(forearmBone)
    if not hand or not forearm then return nil, "missing-support-pose" end
    local rearBone = viewmodel:LookupBone("square")
    local rear = rearBone and viewmodel:GetBoneMatrix(rearBone)
    if not rear then return nil, "missing-gun-pose" end
    return {hand = hand, forearm = forearm, rear = rear}
end

hook.Add("PreDrawPlayerHands", "GarryCraftSuppressPhysgunHands", function(_, viewmodel, player)
    if GC.PhysgunActive(player) and armPose(viewmodel) then return true end
end)

hook.Add("PostDrawViewModel", "GarryCraftMinecraftPhysgunArms", function(viewmodel, player, weapon)
    hookCalls = hookCalls + 1
    if not GC.PhysgunActive(player) then drawStatus = "inactive" return end
    armsDrawn, lastGrips = 0, {}
    local pose, reason = armPose(viewmodel)
    if not pose then drawStatus = reason return end
    lastGunBones = {}
    for _, name in ipairs({"Base", "square"}) do
        local bone = viewmodel:LookupBone(name)
        local transform = bone and viewmodel:GetBoneMatrix(bone)
        if transform then lastGunBones[name] = {position = tostring(transform:GetTranslation()), angles = tostring(transform:GetAngles())} end
    end
    local grips = {}
    for _, side in ipairs({{name = "L", batches = leftArm}, {name = "R", batches = rightArm}}) do
        local wrist, elbow, tip, roll
        if side.name == "L" then
            local handMatrix, forearmMatrix = pose.hand, pose.forearm
            wrist, elbow = handMatrix:GetTranslation(), forearmMatrix:GetTranslation()
            tip = wrist + handMatrix:GetAngles():Forward() * 2.5
            roll = forearmMatrix:GetAngles().r
        else
            local rearMatrix = pose.rear
            tip = rearMatrix:GetTranslation()
            local view = viewmodel:GetAngles()
            elbow = viewmodel:GetPos() + view:Forward() * 16 + view:Right() * 14 - view:Up() * 14
            rearElbowError = WorldToLocal(elbow, Angle(), viewmodel:GetPos(), view):Distance(Vector(16, -14, -14))
            wrist = tip - (tip - elbow):GetNormalized() * 2.5
            roll = view.r
        end
        local direction = tip - elbow
        local angles = direction:Angle()
        angles.r = roll
        local minimum, maximum = math.huge, -math.huge
        for _, batch in ipairs(side.batches) do
            minimum = math.min(minimum, batch.minimum.x)
            maximum = math.max(maximum, batch.maximum.x)
        end
        grips[#grips + 1] = {side = side.name, batches = side.batches, wrist = wrist, elbow = elbow,
            tip = tip, angles = angles, scale = Vector(direction:Length() / (maximum - minimum), .45, .45)}
    end
    lastGrips = {}
    armsDrawn = 0
    for _, grip in ipairs(grips) do
        local transform = Matrix()
        transform:SetTranslation(grip.tip)
        transform:SetAngles(grip.angles)
        transform:Scale(grip.scale)
        armsDrawn = armsDrawn + GC.DrawRenderMeshes(grip.batches, false, grip.wrist, transform)
        lastGrips[#lastGrips + 1] = {side = grip.side, wrist = tostring(grip.wrist), elbow = tostring(grip.elbow),
            tip = tostring(grip.tip), angles = tostring(grip.angles), scale = tostring(grip.scale),
            elbowLocal = tostring(WorldToLocal(grip.elbow, Angle(), viewmodel:GetPos(), viewmodel:GetAngles()))}
    end
    lastGripAt = RealTime()
    drawStatus = armsDrawn > 0 and "drawn" or "missing-texture"
end)

function GC.PhysgunArmReport()
    local function armReport(batches)
        local result = {vertices = 0, batches = {}}
        for _, batch in ipairs(batches) do
            result.vertices = result.vertices + batch.vertices
            result.batches[#result.batches + 1] = {texture = batch.texture, vertices = batch.vertices,
                minimum = tostring(batch.minimum), maximum = tostring(batch.maximum), textureReady = GC.RenderTexture(batch.texture) ~= nil}
        end
        return result
    end
    return {leftArmBatches = #leftArm, rightArmBatches = #rightArm,
        leftArm = armReport(leftArm), rightArm = armReport(rightArm), grips = lastGrips,
        gunBones = lastGunBones, armsDrawn = armsDrawn, rearElbowError = rearElbowError,
        hookCalls = hookCalls, drawStatus = drawStatus, leftRevision = leftRevision, rightRevision = rightRevision,
        sourceHandsSuppressed = drawStatus == "drawn" and #lastGrips == 2 and RealTime() - lastGripAt < .5}
end

hook.Add("ShutDown", "GarryCraftPhysgunArmCleanup", function()
    if IsValid(support) then support:Remove() end
    GC.ClearPhysgunArms()
    for _, batches in ipairs(retired) do GC.DestroyRenderMeshes(batches) end
    retired = {}
end)
