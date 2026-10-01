local GC = GarryCraft

local testMultiplier = 1
local settings = {
    units = CreateConVar("garrycraft_damage_scale", "10", FCVAR_ARCHIVE, "Source health per Minecraft damage point", .1, 100),
    playerToSource = CreateConVar("garrycraft_player_to_source_damage", "1", FCVAR_ARCHIVE, "Minecraft player damage multiplier against Source entities", 0, 100),
    mobToSource = CreateConVar("garrycraft_mob_to_source_damage", "1", FCVAR_ARCHIVE, "Minecraft mob damage multiplier against Source entities", 0, 100),
    sourceToPlayer = CreateConVar("garrycraft_source_to_player_damage", "0.2", FCVAR_ARCHIVE, "Minecraft player damage per Source damage point", 0, 100),
    sourceToMob = CreateConVar("garrycraft_source_to_mob_damage", "0.1", FCVAR_ARCHIVE, "Minecraft mob damage per Source damage point", 0, 100),
    mobToPlayer = CreateConVar("garrycraft_mob_to_player_damage", "1", FCVAR_ARCHIVE, "Minecraft mob damage multiplier against the player", 0, 100),
    playerToMob = CreateConVar("garrycraft_player_to_mob_damage", "1", FCVAR_ARCHIVE, "Minecraft player damage multiplier against Minecraft mobs", 0, 100),
    mobToMob = CreateConVar("garrycraft_mob_to_mob_damage", "1", FCVAR_ARCHIVE, "Minecraft mob damage multiplier against Minecraft mobs", 0, 100),
    environment = CreateConVar("garrycraft_environment_damage", "1", FCVAR_ARCHIVE, "Minecraft environmental damage multiplier", 0, 100)
}

function GC.DamageScale(direction) return settings[direction]:GetFloat() * (direction == "units" and 1 or testMultiplier) end
function GC.MinecraftDamageSettings()
    return {mobToPlayer = GC.DamageScale("mobToPlayer"), playerToMob = GC.DamageScale("playerToMob"),
        mobToMob = GC.DamageScale("mobToMob"), environment = GC.DamageScale("environment")}
end

-- Test overrides never change archived user settings.
function GC.DamageTestSettings(multiplier)
    testMultiplier = multiplier
end
function GC.RestoreDamageSettings() testMultiplier = 1 end
