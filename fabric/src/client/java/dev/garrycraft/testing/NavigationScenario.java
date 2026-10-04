package dev.garrycraft.testing;

import com.google.gson.Gson;
import dev.garrycraft.physics.SourceNavigation;
import dev.garrycraft.physics.SourceWorld;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.minecraft.commands.Commands;
import net.minecraft.server.MinecraftServer;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntitySpawnReason;
import net.minecraft.world.entity.EntityTypes;
import net.minecraft.world.entity.monster.warden.Warden;
import net.minecraft.world.phys.Vec3;

/** Failures: Warden paths crash, never find native support, never move, or leave test mobs behind. */
public final class NavigationScenario {
    private record Sample(int tick, Vec3 position, boolean path, int nodes, double queryMs) {}
    private static Warden warden;
    private static Vec3 start;
    private static int tick, paths;
    private static final List<Sample> samples = new ArrayList<>();
    private NavigationScenario() {}

    public static void register() {
        CommandRegistrationCallback.EVENT.register((dispatcher, registry, environment) -> dispatcher.register(
            Commands.literal("garrycraft_navigation_test").executes(context -> {
                var peer = context.getSource().getPlayerOrException();
                if (!context.getSource().getServer().isSingleplayer() || !SourceWorld.active || warden != null)
                    throw new IllegalStateException("Use an idle linked single-player lab");
                warden = EntityTypes.WARDEN.create(peer.level(), EntitySpawnReason.COMMAND);
                start = peer.position().add(12, 0, 0);
                warden.setPos(start.x, start.y, start.z);
                warden.setPersistenceRequired();
                peer.level().addFreshEntity(warden);
                tick = paths = 0;
                samples.clear();
                return 1;
            })));
        ServerTickEvents.END_SERVER_TICK.register(NavigationScenario::tick);
    }

    private static void tick(MinecraftServer server) {
        if (warden == null) return;
        tick++;
        if (tick % 5 == 0) {
            var peer = server.getPlayerList().getPlayers().getFirst();
            var target = peer.blockPosition();
            long began = System.nanoTime();
            // Exercise the same vanilla navigation and terrain queries used during pursuit.
            for (int x = -16; x <= 16; x++) for (int z = -16; z <= 16; z++)
                SourceNavigation.floor(target.offset(x, 0, z));
            var path = warden.getNavigation().createPath(target, 0);
            if (path != null) { paths++; warden.getNavigation().moveTo(path, 1); }
            samples.add(new Sample(tick, warden.position(), path != null, path == null ? 0 : path.getNodeCount(),
                (System.nanoTime() - began) / 1e6));
        }
        if (tick < 600) return;
        double travel = samples.stream().mapToDouble(sample -> sample.position().distanceTo(start)).max().orElse(0);
        warden.remove(Entity.RemovalReason.DISCARDED);
        var report = Map.of("completed", true, "ticks", tick, "paths", paths, "travel", travel,
            "removed", warden.isRemoved(), "samples", List.copyOf(samples));
        warden = null;
        try {
            var output = Path.of(System.getProperty("garrycraft.artifacts"));
            Files.createDirectories(output);
            Files.writeString(output.resolve("warden-navigation.json"), new Gson().toJson(report));
        } catch (java.io.IOException failure) { throw new IllegalStateException("Cannot save Warden trace", failure); }
    }
}
