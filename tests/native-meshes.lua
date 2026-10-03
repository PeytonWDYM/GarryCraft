-- Run in the isolated single-player client after loading gmcl_garrycraft.
-- Failure cases: bad range, fractional count, destroyed mesh, invalid space,
-- and nonfinite vertices must fail before the native mesh lock.
-- Native/public pixels must match in all three coordinate spaces.
-- Repeated create/build/draw/destroy cycles must leave the renderer usable.
assert(game.SinglePlayer(), "Native mesh tests require single-player")
local bridge = garrycraft_bridge
local zero = string.char(0, 0, 0, 0)
local one = string.char(0, 0, 128, 63)
local function vertex(x, y, z, u, v, r, g, b, a)
    return x .. y .. z .. u .. v .. string.char(r, g, b, a)
end
local triangle = vertex(zero, zero, zero, zero, zero, 255, 64, 32, 255)
    .. vertex(one, zero, zero, one, zero, 32, 255, 64, 255)
    .. vertex(zero, one, zero, zero, one, 64, 32, 255, 128)
local material = CreateMaterial("garrycraft/test/native-meshes", "UnlitGeneric", {
    ["$basetexture"] = "color/white", ["$vertexcolor"] = 1,
    ["$vertexalpha"] = 1, ["$translucent"] = 1, ["$nocull"] = 1
})
local result = {backend = bridge.mesh_backend(), checks = {}, timings = {}}
local function check(name, passed)
    result.checks[#result.checks + 1] = {name = name, passed = passed}
end
local function reject(name, body, offset, count, space, height, destroyed)
    local object = Mesh(material)
    if destroyed then object:Destroy() end
    local success = pcall(bridge.build_mesh, object, body, offset, count, space, height)
    check(name, not success)
    if not destroyed then object:Destroy() end
end
reject("negative offset", triangle, -1, 3, 0, 0)
reject("truncated packet", triangle, 1, 3, 0, 0)
reject("fractional count", triangle, 0, 3.5, 0, 0)
reject("invalid coordinate space", triangle, 0, 3, 3, 0)
reject("destroyed mesh", triangle, 0, 3, 0, 0, true)
local nan = string.char(0, 0, 192, 127)
reject("nonfinite vertex", nan .. string.sub(triangle, 5), 0, 3, 0, 0)
local target = GetRenderTarget("garrycraft/test/native-meshes", 64, 64)
local checker = GetRenderTarget("garrycraft/test/native-meshes-uv", 64, 64)
material:SetTexture("$basetexture", checker)
local function pixels(object, space)
    render.PushRenderTarget(target)
    render.Clear(0, 0, 0, 255, true, true)
    local origin = space == 2 and Vector(-64, -16, 16) or Vector(16, -64, space == 1 and 80 or 16)
    cam.Start3D(origin, space == 2 and Angle(0, 0, 0) or Angle(0, 90, 0), 60, 0, 0, 64, 64, 1, 1000)
    render.SetMaterial(material)
    object:Draw()
    cam.End3D()
    render.CapturePixels()
    local values = {}
    local drawn = 0
    for y = 0, 63 do
        for x = 0, 63 do
            local r, g, b = render.ReadPixel(x, y)
            values[#values + 1] = string.char(r, g, b)
            if r + g + b > 0 then drawn = drawn + 1 end
        end
    end
    render.PopRenderTarget()
    return table.concat(values), drawn
end
hook.Add("PostRender", "GarryCraftNativeMeshTest", function()
    hook.Remove("PostRender", "GarryCraftNativeMeshTest")
    render.PushRenderTarget(checker)
    render.Clear(255, 255, 255, 255, true, true)
    cam.Start2D()
    surface.SetDrawColor(255, 0, 0, 255)
    surface.DrawRect(0, 0, 32, 32)
    surface.SetDrawColor(0, 255, 0, 255)
    surface.DrawRect(32, 0, 32, 32)
    surface.SetDrawColor(0, 0, 255, 255)
    surface.DrawRect(0, 32, 32, 32)
    cam.End2D()
    render.PopRenderTarget()
    for space = 0, 2 do
        local native, public = Mesh(material), Mesh(material)
        local height = space == 1 and 64 or 0
        bridge.build_mesh(native, triangle, 0, 3, space, height)
        bridge.build_mesh(public, triangle, 0, 3, space, height, true)
        local nativePixels, nativeDrawn = pixels(native, space)
        local publicPixels = pixels(public, space)
        check("coordinate space " .. space .. " matches public pixels", nativeDrawn > 10 and nativePixels == publicPixels)
        local rebuilt = string.sub(triangle, 1, 20) .. string.char(255, 255, 255, 255) .. string.sub(triangle, 25)
        bridge.build_mesh(native, rebuilt, 0, 3, space, height)
        bridge.build_mesh(public, rebuilt, 0, 3, space, height, true)
        local rebuiltPixels = pixels(native, space)
        check("coordinate space " .. space .. " rebuild updates pixels", rebuiltPixels ~= nativePixels and rebuiltPixels == pixels(public, space))
        native:Destroy()
        public:Destroy()
    end
    local large = string.rep(triangle, 4096)
    for _, public in ipairs({false, true}) do
        local start = SysTime()
        for iteration = 1, 6 do
            local object = Mesh(material)
            bridge.build_mesh(object, large, 0, 12288, 0, 0, public)
            object:Destroy()
        end
        result.timings[public and "publicMilliseconds" or "nativeMilliseconds"] = (SysTime() - start) * 1000
    end
    result.stats = bridge.mesh_stats()
    result.passed = result.backend == "native"
    for _, entry in ipairs(result.checks) do result.passed = result.passed and entry.passed end
    file.CreateDir("garrycraft")
    file.Write("garrycraft/native-meshes-result.json", util.TableToJSON(result, true))
    print("GarryCraft native mesh test: " .. tostring(result.passed))
end)
