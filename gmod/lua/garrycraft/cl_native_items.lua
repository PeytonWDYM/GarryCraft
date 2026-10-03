local GC = GarryCraft
local items = {}
local pending = {}
local leftArm, rightArm = {}, {}
local leftRevision, rightRevision
local lastGrips = {}
local lastGripAt = 0
local lastGunBones = {}
local removals = {}
local retiredMeshes = {}
local pendingSession, pendingInstance
local class = "garrycraft_native_item"

scripted_ents.Register({Type = "anim", Base = "base_anim", RenderGroup = RENDERGROUP_OPAQUE,
    Initialize = function(self)
        self:SetModel("models/weapons/w_physics.mdl")
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
    end,
    Draw = function(self, flags)
        if self.GarryCraftRetired or GC.VideoReset or not GC.PhysgunEquipped() or not GC.State.linked then return end
        local depth = bit.band(flags, STUDIO_SHADOWDEPTHTEXTURE + STUDIO_SSAODEPTHTEXTURE) ~= 0
        if GC.State.camera == 0 and not depth then return end
        self:DrawModel(flags)
    end,
    OnRemove = function(self)
        if not self.GarryCraftRetired then garrycraft_bridge.shadow_remove(self) end
    end}, class)

local function retireModel(model)
    if not IsValid(model) then return end
    model.GarryCraftRetired = true
    model:SetNoDraw(true)
    garrycraft_bridge.shadow_remove(model)
    model:DestroyShadow()
    removals[model] = true
end

-- Retire ownership immediately. Source removes entities and frees meshes outside render hooks.
local function removeRetired()
    for model in pairs(removals) do
        if IsValid(model) then model:Remove() end
        removals[model] = nil
    end
    for _, batches in ipairs(retiredMeshes) do GC.DestroyRenderMeshes(batches) end
    retiredMeshes = {}
end

local function clearItems()
    for _, item in ipairs(items) do retireModel(item) end
    items, pending = {}, {}
    pendingSession, pendingInstance = nil, nil
end

function GC.ClearNativeItems()
    clearItems()
    retiredMeshes[#retiredMeshes + 1] = leftArm
    retiredMeshes[#retiredMeshes + 1] = rightArm
    leftArm, rightArm = {}, {}
    leftRevision, rightRevision = nil, nil
    lastGrips, lastGripAt = {}, 0
    lastGunBones = {}
end

function GC.AcceptNativeItems(scene, body)
    pending = scene.nativeItems
    pendingSession, pendingInstance = scene.session, scene.instance
    if leftRevision ~= scene.leftArm.revision then
        retiredMeshes[#retiredMeshes + 1] = leftArm
        leftArm = GC.BuildRenderMeshes(scene.leftArm.batches, false, false, body)
        leftRevision = scene.leftArm.revision
    end
    if rightRevision ~= scene.rightArm.revision then
        retiredMeshes[#retiredMeshes + 1] = rightArm
        rightArm = GC.BuildRenderMeshes(scene.rightArm.batches, false, false, body)
        rightRevision = scene.rightArm.revision
    end
end

-- Create runtime model entities outside render hooks. Model files stay in the user's installed game.
hook.Add("Think", "GarryCraftNativeItems", function()
    removeRetired()
    if GC.VideoReset or not GC.PhysgunEquipped() or not GC.State.linked then clearItems() removeRetired() return end
    if pendingSession ~= GC.State.session or pendingInstance ~= GC.State.renderInstance then clearItems() removeRetired() return end
    if not GC.RenderFeet then return end
    local shadows = GetConVar("garrycraft_source_shadows"):GetBool()
    local receiveShadows = garrycraft_bridge.shadow_stats().rttReceiversSupported
    local player = LocalPlayer()
    local weapon = player:GetActiveWeapon()
    for index, item in ipairs(pending) do
        local model = items[index]
        if not IsValid(model) then
            model = ents.CreateClientside(class)
            model.GarryCraftNativeItem = true
            model:Spawn()
            model:SetModel(item.model)
            model.GarryCraftMaterialSlots = #model:GetMaterials()
            model:SetOwner(player)
            model:SetNoDraw(false)
            if receiveShadows then garrycraft_bridge.shadow_receive(model, true) end
            items[index] = model
        end
        -- Source selects the physics gun's skin and material overrides on its native weapon.
        -- The player owner also supplies the installed PlayerWeaponColor material proxy.
        if IsValid(weapon) and weapon:GetClass() == "weapon_physgun" then
            local skin, material, color = weapon:GetSkin(), weapon:GetMaterial(), weapon:GetColor()
            if model:GetSkin() ~= skin then model:SetSkin(skin) end
            if model:GetMaterial() ~= material then model:SetMaterial(material) end
            local currentColor = model:GetColor()
            if currentColor.r ~= color.r or currentColor.g ~= color.g or currentColor.b ~= color.b or currentColor.a ~= color.a then
                model:SetColor(color)
            end
            for slot = 0, model.GarryCraftMaterialSlots - 1 do
                local submaterial = weapon:GetSubMaterial(slot)
                if model:GetSubMaterial(slot) ~= submaterial then model:SetSubMaterial(slot, submaterial) end
            end
        end
        local transform = Matrix()
        for row = 1, 3 do for column = 1, 4 do transform:SetField(row, column, item.transform[(row - 1) * 4 + column]) end end
        transform:SetTranslation(transform:GetTranslation() + GC.RenderFeet)
        -- Minecraft's item layer turns local -Z along the arm. The installed model points along local X.
        transform:Translate(Vector(16, -16, 16))
        transform:Rotate(Angle(0, 90, 0))
        transform:Scale(Vector(.62, .62, .62))
        model.GarryCraftRelativePosition = transform:GetTranslation() - GC.RenderFeet
        local changed = model:GetPos() ~= transform:GetTranslation() or model:GetAngles() ~= transform:GetAngles()
            or model.GarryCraftScale ~= transform:GetScale()
        model:SetPos(transform:GetTranslation())
        model:SetAngles(transform:GetAngles())
        local scale = Matrix()
        model.GarryCraftScale = transform:GetScale()
        scale:Scale(model.GarryCraftScale)
        model:EnableMatrix("RenderMultiply", scale)
        local minimum, maximum = model:GetModelRenderBounds()
        local size = model.GarryCraftScale
        model:SetRenderBounds(Vector(minimum.x * size.x, minimum.y * size.y, minimum.z * size.z),
            Vector(maximum.x * size.x, maximum.y * size.y, maximum.z * size.z))
        if model.GarryCraftShadows ~= shadows then
            model.GarryCraftShadows = shadows
            model:DrawShadow(shadows)
            if shadows then model:CreateShadow() else model:DestroyShadow() end
            changed = true
        end
        if changed and shadows then model:MarkShadowAsDirty() end
    end
    for index = #items, #pending + 1, -1 do retireModel(items[index]) items[index] = nil end
    removeRetired()
end)

-- CalcView moves the native held model with the same interpolated feet as the Minecraft avatar.
function GC.UpdateNativeItemPosition(feet)
    for _, model in ipairs(items) do
        if IsValid(model) then
            local position = feet + model.GarryCraftRelativePosition
            if model:GetPos() ~= position then
                model:SetPos(position)
                if model.GarryCraftShadows then model:MarkShadowAsDirty() end
            end
        end
    end
end

-- The native gun contains a left-hand skeleton. Its rear grip uses the animated gun bone,
-- since c_hands' unmerged right-hand bones remain in their resting pose.
hook.Add("PreDrawPlayerHands", "GarryCraftMinecraftPhysgunArms", function(hands, viewmodel, player, weapon)
    if not GC.PhysgunActive(player) or #leftArm == 0 or #rightArm == 0 then return end
    hands:SetupBones()
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
            local handBone = hands:LookupBone("ValveBiped.Bip01_L_Hand")
            local forearmBone = hands:LookupBone("ValveBiped.Bip01_L_Forearm")
            if not handBone or not forearmBone then return end
            local handMatrix, forearmMatrix = hands:GetBoneMatrix(handBone), hands:GetBoneMatrix(forearmBone)
            if not handMatrix or not forearmMatrix then return end
            wrist, elbow = handMatrix:GetTranslation(), forearmMatrix:GetTranslation()
            tip = wrist + handMatrix:GetAngles():Forward() * 2.5
            roll = forearmMatrix:GetAngles().r
        else
            local rearBone = viewmodel:LookupBone("square")
            local rearMatrix = rearBone and viewmodel:GetBoneMatrix(rearBone)
            if not rearMatrix then return end
            tip = rearMatrix:GetTranslation()
            local view = GC.ViewAngles
            elbow = GC.ViewOrigin + view:Forward() * 16 + view:Right() * 14 - view:Up() * 14
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
    for _, grip in ipairs(grips) do
        local transform = Matrix()
        transform:SetTranslation(grip.tip)
        transform:SetAngles(grip.angles)
        transform:Scale(grip.scale)
        cam.PushModelMatrix(transform)
        GC.DrawRenderMeshes(grip.batches, false, grip.wrist)
        cam.PopModelMatrix()
        lastGrips[#lastGrips + 1] = {side = grip.side, wrist = tostring(grip.wrist), elbow = tostring(grip.elbow),
            tip = tostring(grip.tip), angles = tostring(grip.angles), scale = tostring(grip.scale)}
    end
    lastGripAt = RealTime()
    GC.RestoreLighting()
    return true
end)

function GC.NativeItemReport()
    local function armReport(batches)
        local result = {vertices = 0, batches = {}}
        for _, batch in ipairs(batches) do
            result.vertices = result.vertices + batch.vertices
            result.batches[#result.batches + 1] = {texture = batch.texture, vertices = batch.vertices,
                minimum = tostring(batch.minimum), maximum = tostring(batch.maximum)}
        end
        return result
    end
    local function appearance(entity)
        local materials, slots = entity:GetMaterials(), {}
        for slot = 0, #materials - 1 do slots[#slots + 1] = {slot = slot, material = entity:GetSubMaterial(slot)} end
        return {model = entity:GetModel(), skin = entity:GetSkin(), skinCount = entity:SkinCount(),
            material = entity:GetMaterial(), materials = materials, submaterials = slots, color = entity:GetColor()}
    end
    local world = {}
    for _, item in ipairs(items) do
        local minimum, maximum = item:GetRenderBounds()
        world[#world + 1] = {position = tostring(item:GetPos()), angles = tostring(item:GetAngles()),
            minimum = tostring(minimum), maximum = tostring(maximum),
            appearance = appearance(item), owner = item:GetOwner():EntIndex(),
            noDraw = item:GetNoDraw(), shadowEnabled = item.GarryCraftShadows, entity = item:EntIndex()}
    end
    return {worldModel = "models/weapons/w_physics.mdl", viewmodel = LocalPlayer():GetViewModel():GetModel(),
        nativeWeapon = appearance(LocalPlayer():GetActiveWeapon()), weaponColor = tostring(LocalPlayer():GetWeaponColor()),
        leftArmBatches = #leftArm, rightArmBatches = #rightArm, items = #items, grips = lastGrips, world = world,
        leftArm = armReport(leftArm), rightArm = armReport(rightArm),
        gunBones = lastGunBones, viewOrigin = tostring(GC.ViewOrigin), viewAngles = tostring(GC.ViewAngles),
        sourceHandsSuppressed = #lastGrips == 2 and RealTime() - lastGripAt < .5,
        retiring = table.Count(removals), retiredMeshes = #retiredMeshes}
end

concommand.Add("garrycraft_native_items_report", function()
    file.Write("garrycraft-native-items.json", util.TableToJSON(GC.NativeItemReport(), true))
end)
hook.Add("ShutDown", "GarryCraftNativeItemsCleanup", function()
    GC.ClearNativeItems()
    removeRetired()
end)
