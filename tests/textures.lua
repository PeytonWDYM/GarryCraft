-- Client E2E: run before and after changelevel, using the same procedural texture name.
concommand.Add("garrycraft_test_textures", function()
    local texture = garrycraft_bridge.upload("garrycraft/e2e-map-texture", 16, 16,
        string.rep(string.char(255, 0, 0, 255), 256))
    local material = CreateMaterial("garrycraft/e2e-map-material", "UnlitGeneric", {
        ["$basetexture"] = texture, ["$ignorez"] = 1})
    material:SetTexture("$basetexture", texture)
    hook.Add("HUDPaint", "GarryCraftTextureTest", function()
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(material)
        surface.DrawTexturedRect(100, 100, 64, 64)
    end)
    local frames = 0
    hook.Add("PostRender", "GarryCraftTextureTestRead", function()
        frames = frames + 1
        if frames < 3 then return end
        render.CapturePixels()
        local red, green, blue = render.ReadPixel(120, 120)
        file.Write("garrycraft-texture-test.json", util.TableToJSON({map = game.GetMap(), texture = texture,
            red = red, green = green, blue = blue, passed = red > 240 and green < 10 and blue < 10}, true))
        hook.Remove("HUDPaint", "GarryCraftTextureTest")
        hook.Remove("PostRender", "GarryCraftTextureTestRead")
    end)
end)
