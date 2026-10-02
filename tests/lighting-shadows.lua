-- Run after garrycraft_test lighting in the isolated single-player lab.
-- The collector reads paired Minecraft and Source phases plus PNG evidence.
local samples = util.JSONToTable(file.Read("garrycraft-lighting-source.json", "DATA")).samples
assert(samples.enclosed.exposure == 0, "A closed Minecraft room must block Source ambient light")
assert(samples.enclosed.modelLights == 0, "A torch outside the room must not light its interior")
assert(samples.roomTorch.modelLights > 0, "An interior torch must light the closed room")
assert(samples.opened.exposure > samples.enclosed.exposure, "Removing a wall must admit ambient light")
assert(samples.glass.exposure == samples.opened.exposure, "A glass window must preserve collision and admit ambient light")
assert(samples.roomTorch.avatar.vertices > 0 and samples.roomTorch.avatar.camera == 0,
    "First person must retain the Minecraft avatar as a shadow caster")
assert(samples.removed.lights.exported == 0, "Fixture cleanup must remove its lights")
assert(samples.shadowOn.shadows.avatarReceiver == "minecraft", "The avatar shadow must use the Minecraft floor")
assert(samples.shadowOff.shadowPixels.avatar.luminance > samples.shadowOn.shadowPixels.avatar.luminance + 5,
    "The avatar silhouette must visibly darken the same floor pixels")
assert(samples.shadowOff.shadowPixels.block.luminance > samples.shadowOn.shadowPixels.block.luminance + 5,
    "The block silhouette must visibly darken its separate floor pixels")
print("GarryCraft lighting shadow probes passed. Inspect the phase screenshots for shadow shape.")
