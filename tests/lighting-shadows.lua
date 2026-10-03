-- Run after garrycraft_test lighting in the isolated single-player lab.
-- The collector reads paired Minecraft and Source phases plus PNG evidence.
local samples = util.JSONToTable(file.Read("garrycraft-lighting-source.json", "DATA")).samples
assert(samples.enclosed.exposure == 0, "The exported closed room must block the torch visibility probe")
assert(samples.enclosed.modelLights == 0, "A torch outside the room must not light its interior")
assert(samples.roomTorch.modelLights > 0, "An interior torch must light the closed room")
assert(samples.opened.exposure > samples.enclosed.exposure, "Removing a wall must open the visibility probe")
assert(samples.glass.exposure == samples.opened.exposure, "Glass must preserve collision without an opaque lighting wall")
assert(samples.roomTorch.avatar.vertices > 0 and samples.roomTorch.avatar.camera == 0,
    "First person must retain the Minecraft avatar as a shadow caster")
assert(samples.removed.lights.exported == 0, "Fixture cleanup must remove its lights")
assert(samples.shadowOn.shadows.mode == "source" and samples.shadowOn.shadows.native.castDraws > 0,
    "Source must render the registered Minecraft shadow silhouettes")
assert(samples.shadowOff.view == samples.shadowOn.view and samples.shadowOff.angles == samples.shadowOn.angles,
    "Compare the same camera pose")
local darkened = 0
for index, luminance in ipairs(samples.shadowOff.shadowGrid.pixels) do
    if luminance - samples.shadowOn.shadowGrid.pixels[index] > 5 then darkened = darkened + 1 end
end
assert(darkened > 0, "Native Source shadows must darken rendered receiver pixels")
print("GarryCraft lighting shadow probes passed. Inspect the phase screenshots for shadow shape.")
