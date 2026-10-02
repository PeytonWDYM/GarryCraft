package dev.garrycraft.bridge;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import dev.garrycraft.GarryCraftClient;
import dev.garrycraft.testing.PhysicsOracle;
import java.util.concurrent.atomic.AtomicReference;
import net.minecraft.client.Minecraft;
import dev.garrycraft.combat.SourceCombat;
import dev.garrycraft.testing.ParityOracle;

/** Publishes raw ticks and Minecraft's camera state. The Source renderer interpolates the raw ticks. */
public final class StatePublisher {
    private static final Gson JSON = new Gson();
    private static final AtomicReference<String> OUTGOING = new AtomicReference<>();
    private static JsonObject state;
    private static long tick;
    private static long frame;
    private static float eye;
    private static String instance = "";
    private StatePublisher() {}
    public static String drain() { return OUTGOING.getAndSet(null); }

    public static void tick(Minecraft mc, HostInput input, String session, String process) {
        var player = mc.player;
        float tickMs = mc.level.tickRateManager().millisecondsPerTick();
        float remainder = mc.getDeltaTracker().getGameTimeDeltaPartialTick(false);
        float oldEye = eye;
        if (!process.equals(instance)) { instance = process; eye = player.getEyeHeight(); oldEye = eye; }
        eye += (player.getEyeHeight() - eye) * 0.5f;
        state = new JsonObject();
        state.addProperty("version", 1);
        state.addProperty("instance", process);
        state.addProperty("session", session);
        state.addProperty("tick", ++tick);
        state.addProperty("tickTime", BridgeClock.seconds() - remainder * tickMs / 1000.0);
        state.addProperty("tickMs", tickMs);
        state.addProperty("linked", GarryCraftClient.linked());
        state.addProperty("geometryAck", GarryCraftClient.COLLISION.acknowledged());
        state.addProperty("geometryReady", GarryCraftClient.COLLISION.acknowledged() >= input.geometryBatches() - 1);
        state.addProperty("teleportAck", SpawnBridge.acknowledged());
        state.addProperty("deaths", SpawnBridge.deaths());
        state.addProperty("prevX", player.xo);
        state.addProperty("prevY", player.yo);
        state.addProperty("prevZ", player.zo);
        state.addProperty("x", player.getX());
        state.addProperty("y", player.getY());
        state.addProperty("z", player.getZ());
        state.addProperty("vx", player.getDeltaMovement().x);
        state.addProperty("vy", player.getDeltaMovement().y);
        state.addProperty("vz", player.getDeltaMovement().z);
        state.addProperty("eyePrevious", oldEye);
        state.addProperty("eye", eye);
        state.addProperty("height", player.getBbHeight());
        state.addProperty("grounded", player.onGround());
        state.addProperty("health", player.getHealth());
        state.addProperty("sprinting", player.isSprinting());
        state.addProperty("sprintInput", input.sprint());
        state.addProperty("forwardInput", input.forward());
        state.addProperty("swimming", player.isSwimming());
        state.addProperty("inWater", player.isInWater());
        state.addProperty("air", player.getAirSupply());
        state.addProperty("food", player.getFoodData().getFoodLevel());
        state.addProperty("gameMode", mc.gameMode.getPlayerMode().getName());
        state.addProperty("reference", PhysicsOracle.sampledReference);
        state.addProperty("parityPhase", ParityOracle.phase());
        state.addProperty("responsivenessPhase", dev.garrycraft.testing.ResponsivenessOracle.phase());
        state.addProperty("responsivenessRequest", dev.garrycraft.testing.ResponsivenessOracle.request());
        state.addProperty("parityRequest", ParityOracle.request());
        state.addProperty("parityTick", ParityOracle.tick());
        state.addProperty("damageTestRequest", dev.garrycraft.testing.DamageOracle.request());
        state.addProperty("damageTestPhase", dev.garrycraft.testing.DamageOracle.phase());
        state.addProperty("damageTestMob", dev.garrycraft.testing.DamageOracle.mob());
        state.addProperty("terrainTestRequest", dev.garrycraft.testing.TerrainUseOracle.request());
        state.addProperty("terrainTestPhase", dev.garrycraft.testing.TerrainUseOracle.phase());
        state.addProperty("terrainTestYaw", player.getYRot());
        state.addProperty("terrainTestPitch", player.getXRot());
        state.addProperty("lightingTestRequest", dev.garrycraft.testing.LightingOracle.request());
        state.addProperty("lightingTestPhase", dev.garrycraft.testing.LightingOracle.phase());
        state.addProperty("lightingTestYaw", player.getYRot());
        state.addProperty("lightingTestPitch", player.getXRot());
        state.addProperty("fixture", PhysicsOracle.fixture());
        state.add("entityHits", JSON.toJsonTree(SourceCombat.hits()));
        state.add("mobs", JSON.toJsonTree(dev.garrycraft.combat.SourceMobs.states()));
        state.addProperty("mobDamageAck", dev.garrycraft.combat.SourceMobs.acknowledged());
        var avatar = player.avatarState();
        boolean bob = mc.options.bobView().get();
        state.addProperty("walkPrevious", bob ? avatar.getInterpolatedWalkDistance(0) : 0);
        state.addProperty("walk", bob ? avatar.getInterpolatedWalkDistance(1) : 0);
        state.addProperty("bobPrevious", bob ? avatar.getInterpolatedBob(0) : 0);
        state.addProperty("bob", bob ? avatar.getInterpolatedBob(1) : 0);
        publish(mc);
    }

    public static void publish(Minecraft mc) {
        if (state == null || mc.player == null) return;
        state.addProperty("frame", ++frame);
        state.addProperty("fov", mc.gameRenderer.mainCamera().getFov());
        state.addProperty("camera", mc.options.getCameraType().ordinal());
        state.addProperty("screenOpen", mc.gui.screen() != null);
        state.addProperty("fps", mc.getFps());
        state.addProperty("targetFps", GarryCraftClient.targetFps());
        state.addProperty("renderInstance", GarryCraftClient.renderInstance());
        state.addProperty("uiAck", InputBridge.acknowledged());
        state.addProperty("clientUiAck", InputBridge.clientAcknowledged());
        var controls = GarryCraftClient.controls();
        state.addProperty("clientInputFrame", controls == null ? 0 : controls.frame());
        state.addProperty("clientInputAgeMs", controls == null ? -1 : (BridgeClock.seconds() - controls.time()) * 1000);
        state.addProperty("damageAck", DamageBridge.acknowledged());
        state.addProperty("screenType", mc.gui.screen() == null ? "" : mc.gui.screen().getClass().getSimpleName());
        OUTGOING.set(JSON.toJson(state));
    }
}
