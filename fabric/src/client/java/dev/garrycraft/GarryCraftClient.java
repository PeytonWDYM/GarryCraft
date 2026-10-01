package dev.garrycraft;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import dev.garrycraft.bridge.HostInput;
import dev.garrycraft.bridge.InputBridge;
import dev.garrycraft.bridge.Mailbox;
import dev.garrycraft.bridge.StatePublisher;
import dev.garrycraft.bridge.SpawnBridge;
import dev.garrycraft.bridge.DamageBridge;
import dev.garrycraft.physics.CollisionWorld;
import dev.garrycraft.physics.SourceWorld;
import dev.garrycraft.combat.SourceCombat;
import dev.garrycraft.combat.SourceActor;
import net.fabricmc.fabric.api.client.rendering.v1.EntityRendererRegistry;
import net.minecraft.client.renderer.entity.NoopRenderer;
import dev.garrycraft.physics.SourceWater;
import dev.garrycraft.render.AvatarExporter;
import dev.garrycraft.render.FrameExporter;
import dev.garrycraft.render.RenderTransport;
import dev.garrycraft.render.WorldExporter;
import dev.garrycraft.testing.PhysicsOracle;
import dev.garrycraft.testing.ParityOracle;
import java.io.IOException;
import java.nio.file.Path;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.atomic.AtomicReference;
import java.util.UUID;
import net.fabricmc.api.ClientModInitializer;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.networking.v1.ServerPlayConnectionEvents;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.screens.LevelLoadingScreen;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Items;
import net.minecraft.world.level.gamerules.GameRules;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public final class GarryCraftClient implements ClientModInitializer {
    public static final Logger LOG = LoggerFactory.getLogger("garrycraft");
    public static final CollisionWorld COLLISION = SourceWorld.COLLISION;
    private static final Gson JSON = new Gson();
    private static final ConcurrentLinkedQueue<Geometry> GEOMETRY = new ConcurrentLinkedQueue<>();
    private static volatile HostInput input = HostInput.idle();
    private static volatile long receivedAt;
    private static String session = "";
    private static long frame;
    private static boolean wasLinked;
    private static boolean savedVsync;
    private static final String INSTANCE = UUID.randomUUID().toString();
    private static boolean resourcesChanged;
    private static long nextScene, nextActors;
    private static boolean captureScene;
    private static long renderEpoch;
    public static boolean captureScene() { return captureScene; }
    public static void resourcesChanged() { resourcesChanged = true; }
    public static String renderInstance() { return RenderTransport.instance(); }
    private record Geometry(JsonObject payload, boolean dynamic) {}

    public static boolean linked() {
        return input.active() && System.nanoTime() - receivedAt < 1_000_000_000L;
    }
    public static int targetFps() { return Math.clamp(input.targetFps(), 10, 1000); }
    public static int viewportWidth() { return Math.clamp(input.viewportWidth(), 320, 4096); }
    public static int viewportHeight() { return Math.clamp(input.viewportHeight(), 240, 4096); }


    @Override
    public void onInitializeClient() {
        EntityRendererRegistry.register(SourceCombat.TYPE, NoopRenderer::new);
        Thread.ofPlatform().daemon().name("garrycraft-bridge").start(this::transport);
        ClientTickEvents.START_CLIENT_TICK.register(GarryCraftClient::beforeTick);
        ClientTickEvents.END_CLIENT_TICK.register(GarryCraftClient::afterTick);
        ServerPlayConnectionEvents.JOIN.register((handler, sender, server) -> {
            if (!server.isSingleplayer()) return;
            var rules = server.getGameRules();
            rules.set(GameRules.PLAYER_MOVEMENT_CHECK, false, server);
            rules.set(GameRules.SPAWN_MOBS, false, server);
            rules.set(GameRules.IMMEDIATE_RESPAWN, false, server);
            rules.set(GameRules.KEEP_INVENTORY, true, server);
            var player = handler.getPlayer();
            if (player.getInventory().isEmpty()) {
                player.getInventory().add(new ItemStack(Items.STONE, 64));
                player.getInventory().add(new ItemStack(Items.OAK_PLANKS, 64));
                player.getInventory().add(new ItemStack(Items.GLASS, 64));
                player.getInventory().add(new ItemStack(Items.WATER_BUCKET));
                player.getInventory().add(new ItemStack(Items.LAVA_BUCKET));
                player.getInventory().add(new ItemStack(Items.DIAMOND_PICKAXE));
                player.getInventory().add(new ItemStack(Items.DIAMOND_SWORD));
                player.getInventory().add(new ItemStack(Items.TNT, 64));
                player.getInventory().add(new ItemStack(Items.FLINT_AND_STEEL));
                player.getInventory().add(new ItemStack(Items.COOKED_BEEF, 64));
            }
            // Upgrade existing mirror inventories without adding another stack on every launch.
            else if (!player.getInventory().contains(stack -> stack.is(Items.COOKED_BEEF))) {
                player.getInventory().add(new ItemStack(Items.COOKED_BEEF, 64));
            }
        });
    }

    private void transport() {
        String defaultPath = System.getenv("LOCALAPPDATA") + "\\GarryCraft\\bridge.bin";
        Path path = Path.of(System.getProperty("garrycraft.bridge", defaultPath));
        try (var mailbox = new Mailbox(path)) {
            while (!Thread.currentThread().isInterrupted()) {
                String controls = mailbox.receive(0);
                if (controls != null) {
                    HostInput next = JSON.fromJson(controls, HostInput.class);
                    if (next.version() != 1) throw new IllegalStateException("Unsupported bridge protocol");
                    input = next;
                    receivedAt = System.nanoTime();
                }
                for (int lane = 2; lane <= 3; lane++) {
                    String payload = mailbox.receive(lane);
                    if (payload != null) GEOMETRY.add(new Geometry(JsonParser.parseString(payload).getAsJsonObject(), lane == 3));
                }
                String outgoing = StatePublisher.drain();
                if (outgoing != null) mailbox.send(1, outgoing);
                RenderTransport.send(mailbox, input.textureAck(), input.textureInstance());
                Thread.sleep(2);
            }
        } catch (IOException | InterruptedException | RuntimeException error) {
            input = HostInput.idle();
            LOG.error("GarryCraft bridge stopped", error);
        }
    }

    public static void beginFrame(Minecraft minecraft) {
        dev.garrycraft.testing.FrameTimings.frame();
        long now = System.nanoTime();
        captureScene = now >= nextScene;
        if (captureScene) nextScene = now + 1_000_000_000L / targetFps();
        if (minecraft.level != null && linked() && now >= nextActors) {
            nextActors = now + 50_000_000L;
            for (var entity : minecraft.level.entitiesForRendering()) {
                if (entity instanceof SourceActor proxy) {
                    for (var actor : COLLISION.actors()) if (actor.id() == proxy.sourceId()) {
                        proxy.setSize(actor.width(), actor.height());
                        proxy.setPos(actor.x(), actor.y(), actor.z());
                        proxy.xo = actor.x(); proxy.yo = actor.y(); proxy.zo = actor.z();
                        break;
                    }
                }
            }
        }
        if (linked() && minecraft.player != null && !minecraft.player.isDeadOrDying()
                && input.teleportSeq() == SpawnBridge.acknowledged() && !PhysicsOracle.running() && !ParityOracle.running() && !dev.garrycraft.testing.DamageOracle.running() && !dev.garrycraft.testing.TerrainUseOracle.running()
                && !dev.garrycraft.testing.LightingOracle.running()) InputBridge.apply(minecraft, input);
    }

    public static void renderFrame(Minecraft minecraft) {
        if (captureScene) StatePublisher.publish(minecraft);
        if (!linked() || minecraft.player == null || minecraft.level == null) return;
        if (PhysicsOracle.sampledReference) return;
        if (captureScene) {
            AvatarExporter.frame(minecraft, session, renderInstance());
            WorldExporter.frame(minecraft, session, renderInstance(), renderInstance().equals(input.worldInstance()) ? input.worldAck() : 0);
        }
        FrameExporter.capture(minecraft);
    }

    private static void beforeTick(Minecraft minecraft) {
        MirrorWorld.open(minecraft);
        boolean active = linked();
        if (!input.session().equals(session)) {
            session = input.session();
            COLLISION.reset(session);
            RenderTransport.reset(session, UUID.randomUUID().toString());
            renderEpoch = input.renderEpoch();
            wasLinked = false;
        }
        if (resourcesChanged || renderEpoch != input.renderEpoch()) {
            resourcesChanged = false;
            renderEpoch = input.renderEpoch();
            RenderTransport.reset(session, UUID.randomUUID().toString());
        }
        Geometry geometry;
        while ((geometry = GEOMETRY.poll()) != null) COLLISION.accept(geometry.payload(), geometry.dynamic());
        SourceCombat.update(session, active, input.entityHitAck(), COLLISION.actors());
        dev.garrycraft.combat.DamageScaling.update(active ? input.damageScaling() : dev.garrycraft.combat.DamageScaling.DEFAULTS);
        dev.garrycraft.combat.SourceMobs.update(session, active && !PhysicsOracle.reference, input.mobDamage());
        if (minecraft.player == null) { SourceWorld.active = false; return; }
        if (active) DamageBridge.update(minecraft, input);
        if (active && SpawnBridge.update(minecraft, input)) {
            InputBridge.apply(minecraft, HostInput.idle());
            return;
        }
        boolean loading = active && COLLISION.acknowledged() < input.geometryBatches() - 1;
        SourceWorld.active = active && !loading && !PhysicsOracle.reference;
        if (!loading && (active || dev.garrycraft.testing.DamageOracle.running())) dev.garrycraft.testing.DamageOracle.update(minecraft, input);
        if (active && !loading && !minecraft.player.connection.hasClientLoaded()) {
            // Source supplies the rendered world, so its complete mesh fulfills Minecraft's render-ready callback.
            ((dev.garrycraft.mixin.ClientWorldReady) minecraft.player.connection).garrycraft$worldReady();
        }
        if (active && !loading && input.teleportSeq() == SpawnBridge.acknowledged()
                && minecraft.gui.screen() instanceof LevelLoadingScreen) minecraft.gui.setScreen(null);
        minecraft.player.noPhysics = !active || loading;
        minecraft.player.setNoGravity(!active || loading);
        if (!active) {
            SourceWater.clear();
            minecraft.player.setDeltaMovement(0, 0, 0);
            minecraft.player.resetFallDistance();
        } else if (loading) {
            minecraft.player.setPos(input.x(), input.y(), input.z());
            minecraft.player.setDeltaMovement(0, 0, 0);
        }
        if (active && !wasLinked) {
            savedVsync = minecraft.options.enableVsync().get();
            minecraft.options.enableVsync().set(false);
            minecraft.options.pauseOnLostFocus = false;
            minecraft.options.autoJump().set(false);
            minecraft.gui.setScreen(null);
            LOG.info("GarryCraft attached to Source session {}", session);
        }
        if (!active && wasLinked) minecraft.options.enableVsync().set(savedVsync);
        if (!loading && active && ParityOracle.beforeTick(minecraft, input)) {
            wasLinked = active;
            return;
        }
        if (!loading && active && dev.garrycraft.testing.TerrainUseOracle.beforeTick(minecraft, input)) {
            wasLinked = active;
            return;
        }
        if (!loading && active && dev.garrycraft.testing.LightingOracle.beforeTick(minecraft, input)) {
            wasLinked = active;
            return;
        }
        if (dev.garrycraft.testing.DamageOracle.running()) {
            InputBridge.apply(minecraft, HostInput.idle());
            wasLinked = active;
            return;
        }
        if (!loading && active && PhysicsOracle.beforeTick(minecraft, input)) {
            wasLinked = active;
            return;
        }
        if (active || wasLinked) InputBridge.apply(minecraft, active && !loading ? input : HostInput.idle());
        wasLinked = active;
    }

    private static void afterTick(Minecraft minecraft) {
        if (minecraft.player == null) return;
        PhysicsOracle.afterTick(minecraft);
        ParityOracle.afterTick(minecraft);
        frame++;
        StatePublisher.tick(minecraft, input, session, INSTANCE);
    }
}
