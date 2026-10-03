package dev.garrycraft;

import dev.garrycraft.combat.SourceCombat;
import dev.garrycraft.combat.SourceMobs;
import dev.garrycraft.item.PhysicsGun;
import net.fabricmc.api.ModInitializer;

public final class GarryCraft implements ModInitializer {
    @Override public void onInitialize() { SourceCombat.init(); SourceMobs.init(); PhysicsGun.init(); }
}
