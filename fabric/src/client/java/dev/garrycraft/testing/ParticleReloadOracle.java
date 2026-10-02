package dev.garrycraft.testing;

import com.google.gson.Gson;
import dev.garrycraft.bridge.HostInput;
import dev.garrycraft.mixin.TextureAtlasAccessor;
import dev.garrycraft.mixin.TextureManagerAccessor;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.CompletableFuture;
import net.minecraft.client.Minecraft;
import net.minecraft.client.particle.TerrainParticle;
import net.minecraft.client.renderer.texture.TextureAtlas;
import net.minecraft.client.gui.screens.options.OptionsScreen;
import net.minecraft.world.level.block.Blocks;

/** Reloads actual game resources while terrain particles still use the previous atlas. */
public final class ParticleReloadOracle {
    private record Report(String request, boolean completed, int oldWidth, int oldHeight, int newWidth, int newHeight,
        int restoredWidth, int restoredHeight, int beforeVertices, int afterVertices, String afterReloadParticles,
        boolean mipmapsRestored) {}
    private static String request = "", phase = "waiting";
    private static int tick, savedMipmaps, oldWidth, oldHeight, newWidth, newHeight;
    private static int beforeVertices, afterVertices;
    private static String afterReloadParticles;
    private static boolean running;
    private static CompletableFuture<Void> pending = CompletableFuture.completedFuture(null);
    private ParticleReloadOracle() {}
    public static String request() { return request; }
    public static String phase() { return phase; }
    public static void particles(int vertices) {
        if (phase.equals("before")) beforeVertices = Math.max(beforeVertices, vertices);
        if (phase.equals("after")) afterVertices = Math.max(afterVertices, vertices);
    }
    private static TextureAtlasAccessor atlas(Minecraft mc) {
        return (TextureAtlasAccessor) ((TextureManagerAccessor) mc.getTextureManager()).garrycraft$byPath()
            .get(TextureAtlas.LOCATION_BLOCKS);
    }
    private static void spawn(Minecraft mc) {
        var point = mc.player.getEyePosition().add(mc.player.getLookAngle().scale(2));
        for (int i = 0; i < 16; i++) {
            var particle = new TerrainParticle(mc.level, point.x, point.y, point.z, 0, 0, 0, Blocks.STONE.defaultBlockState());
            particle.setLifetime(600);
            mc.particleEngine.add(particle);
        }
    }
    public static void tick(Minecraft mc, HostInput host) {
        if (!pending.isDone()) return;
        pending.join();
        if (running && (!host.active() || !host.test().equals(request))) {
            mc.options.mipmapLevels().set(savedMipmaps); mc.updateMaxMipLevel(savedMipmaps); mc.options.save();
            running = false; phase = "canceled"; pending = mc.reloadResourcePacks(); return;
        }
        if (host.active() && !running && host.test().startsWith("reload:") && !host.test().equals(request)) {
            request = host.test(); phase = "before"; running = true; tick = beforeVertices = afterVertices = 0;
            savedMipmaps = mc.options.mipmapLevels().get();
            oldWidth = atlas(mc).garrycraft$width(); oldHeight = atlas(mc).garrycraft$height();
            spawn(mc);
        }
        if (!running) return;
        if (phase.equals("reload")) {
            afterReloadParticles = mc.particleEngine.countParticles();
            newWidth = atlas(mc).garrycraft$width(); newHeight = atlas(mc).garrycraft$height();
            phase = "after"; tick = 0; spawn(mc);
        }
        if (phase.equals("restore")) {
            running = false; phase = "done";
            try {
                var output = Path.of(System.getProperty("garrycraft.artifacts")); Files.createDirectories(output);
                Files.writeString(output.resolve("particle-reload-minecraft.json"), new Gson().toJson(new Report(
                    request, true, oldWidth, oldHeight, newWidth, newHeight, atlas(mc).garrycraft$width(),
                    atlas(mc).garrycraft$height(), beforeVertices, afterVertices, afterReloadParticles,
                    mc.options.mipmapLevels().get() == savedMipmaps)));
            } catch (java.io.IOException failure) { throw new IllegalStateException("Cannot save particle reload trace", failure); }
            return;
        }
        tick++;
        if (phase.equals("after") && tick % 5 == 0) spawn(mc);
        if (phase.equals("before") && tick == 10) {
            phase = "reload";
            mc.options.mipmapLevels().set(savedMipmaps == 0 ? 4 : 0);
            mc.updateMaxMipLevel(mc.options.mipmapLevels().get());
            mc.gui.setScreen(new OptionsScreen(null, mc.options));
            pending = mc.reloadResourcePacks().thenRunAsync(() -> mc.gui.setScreen(null), mc);
        } else if (phase.equals("after") && tick == 60) {
            phase = "restore";
            mc.options.mipmapLevels().set(savedMipmaps);
            mc.updateMaxMipLevel(savedMipmaps);
            mc.gui.setScreen(new OptionsScreen(null, mc.options));
            pending = mc.reloadResourcePacks().thenRunAsync(() -> mc.gui.setScreen(null), mc);
        }
    }
}
