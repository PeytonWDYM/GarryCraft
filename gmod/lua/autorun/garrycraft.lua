GarryCraft = GarryCraft or {}
if SERVER then
    AddCSLuaFile("garrycraft/cl_view.lua")
    AddCSLuaFile("garrycraft/cl_camera.lua")
    AddCSLuaFile("garrycraft/cl_render.lua")
    AddCSLuaFile("garrycraft/cl_input.lua")
    AddCSLuaFile("garrycraft/cl_framerate.lua")
    AddCSLuaFile("garrycraft/sh_coordinates.lua")
    include("garrycraft/sh_coordinates.lua")
    include("garrycraft/sv_displacements.lua")
    include("garrycraft/sv_geometry.lua")
    include("garrycraft/sv_water.lua")
    include("garrycraft/sv_respawn.lua")
    include("garrycraft/sv_damage.lua")
    include("garrycraft/sv_bridge.lua")
    include("garrycraft/sv_lab.lua")
else
    include("garrycraft/sh_coordinates.lua")
    include("garrycraft/cl_camera.lua")
    include("garrycraft/cl_view.lua")
    include("garrycraft/cl_render.lua")
    include("garrycraft/cl_input.lua")
    include("garrycraft/cl_framerate.lua")
end
