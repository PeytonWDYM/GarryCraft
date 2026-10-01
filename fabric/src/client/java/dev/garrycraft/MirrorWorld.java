package dev.garrycraft;

import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.screens.TitleScreen;
import net.minecraft.core.registries.Registries;
import net.minecraft.resources.Identifier;
import net.minecraft.resources.ResourceKey;
import net.minecraft.world.Difficulty;
import net.minecraft.world.level.GameType;
import net.minecraft.world.level.LevelSettings;
import net.minecraft.world.level.WorldDataConfiguration;
import net.minecraft.world.level.levelgen.WorldOptions;
import net.minecraft.world.level.levelgen.presets.WorldPreset;

/** Owns only the GarryCraft world in this instance. It never opens a user's existing world. */
public final class MirrorWorld {
    private static final String NAME = "GarryCraft";
    private static final ResourceKey<WorldPreset> PRESET = ResourceKey.create(Registries.WORLD_PRESET,
            Identifier.fromNamespaceAndPath("garrycraft", "mirror"));
    private static boolean attempted;

    private MirrorWorld() {}

    public static boolean autoLoading(String name) {
        return Boolean.getBoolean("garrycraft.autoWorld") && attempted && NAME.equals(name);
    }

    public static void open(Minecraft minecraft) {
        if (!Boolean.getBoolean("garrycraft.autoWorld") || attempted || minecraft.level != null
                || minecraft.gui.overlay() != null) return;
        if (!(minecraft.gui.screen() instanceof TitleScreen title)) {
            if (minecraft.gui.screen() == null || minecraft.gui.screen().getClass().getSimpleName().contains("Onboarding")) {
                minecraft.gui.setScreen(new TitleScreen());
            }
            return;
        }
        attempted = true;
        if (minecraft.getLevelSource().levelExists(NAME)) {
            minecraft.createWorldOpenFlows().openWorld(NAME, () -> minecraft.gui.setScreen(title));
        } else {
            var settings = new LevelSettings(NAME, GameType.SURVIVAL,
                    new LevelSettings.DifficultySettings(Difficulty.NORMAL, false, false), true,
                    WorldDataConfiguration.DEFAULT);
            minecraft.createWorldOpenFlows().createFreshLevel(NAME, settings, new WorldOptions(0, false, false),
                    registries -> registries.lookupOrThrow(Registries.WORLD_PRESET).getOrThrow(PRESET)
                            .value().createWorldDimensions(), title);
        }
    }
}
