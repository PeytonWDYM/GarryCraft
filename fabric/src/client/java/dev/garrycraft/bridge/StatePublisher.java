package dev.garrycraft.bridge;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import dev.garrycraft.GarryCraftClient;
import dev.garrycraft.testing.PhysicsOracle;
import java.util.concurrent.atomic.AtomicReference;
import net.minecraft.client.Minecraft;
import dev.garrycraft.combat.SourceCombat;
import dev.garrycraft.testing.ParityOracle;
import dev.garrycraft.item.PhysicsGun;
import org.joml.Matrix4f;

/** Publishes raw ticks and Minecraft's camera state. The Source renderer interpolates the raw ticks. */
public final class StatePublisher {
    private static final Gson JSON = new Gson();
    private static final AtomicReference<String> OUTGOING = new AtomicReference<>();
    private static JsonObject state;
    private static long tick;
    private static long frame;
    private static float eye;
    private static String instance = "";
    private static final float[] nativeViewmodelPose = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0};
    private StatePublisher() {}
    public static String drain() { return OUTGOING.getAndSet(null); }

    /** Capture vanilla's hand pose after camera bob and hurt tilt, in Source view coordinates. */
    public static void nativeViewmodelPose(Matrix4f pose) {
        int[] axes = {2, 0, 1}, signs = {-1, -1, 1};
        for (int row = 0; row < 3; row++) {
            for (int column = 0; column < 3; column++)
                nativeViewmodelPose[row * 4 + column] = signs[row] * signs[column] * pose.get(axes[column], axes[row]);
            nativeViewmodelPose[row * 4 + 3] = 32 * signs[row] * pose.get(3, axes[row]);
        }
    }

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
        state.addProperty("geometryShapeAck", GarryCraftClient.COLLISION.shapeAcknowledged());
        state.add("movingGeometry", JSON.toJsonTree(GarryCraftClient.COLLISION.movingTrace()));
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
        state.addProperty("sneaking", player.isShiftKeyDown());
        state.addProperty("flying", player.getAbilities().flying);
        state.addProperty("gliding", player.isFallFlying());
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
        state.addProperty("particleReloadRequest", dev.garrycraft.testing.ParticleReloadOracle.request());
        state.addProperty("particleReloadPhase", dev.garrycraft.testing.ParticleReloadOracle.phase());
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
        state.addProperty("polishRequest", dev.garrycraft.testing.GameplayOracle.request());
        state.addProperty("polishPhase", dev.garrycraft.testing.GameplayOracle.phase());
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
        state.addProperty("physgunEquipped", GarryCraftClient.linked() && PhysicsGun.equipped(mc.player));
        state.add("nativeViewmodelPose", JSON.toJsonTree(nativeViewmodelPose));
        if (PhysicsGun.equipped(mc.player) && mc.hitResult instanceof net.minecraft.world.phys.BlockHitResult hit
            && hit.getType() == net.minecraft.world.phys.HitResult.Type.BLOCK && !mc.level.getBlockState(hit.getBlockPos()).isAir()) {
            var target = new JsonObject();
            var position = hit.getBlockPos(); var point = hit.getLocation();
            target.addProperty("x", position.getX()); target.addProperty("y", position.getY()); target.addProperty("z", position.getZ());
            target.addProperty("hx", point.x); target.addProperty("hy", point.y); target.addProperty("hz", point.z);
            state.add("physicsBlockTarget", target);
        } else state.remove("physicsBlockTarget");
        state.addProperty("physicsBlockEpoch", dev.garrycraft.physicsblocks.PhysicsBlocks.generation());
        state.addProperty("blockPickAck", dev.garrycraft.physicsblocks.PhysicsBlocks.acknowledged());
        state.add("blockPickResults", JSON.toJsonTree(dev.garrycraft.physicsblocks.PhysicsBlocks.results()));
        state.addProperty("physicsBlocksRecovered", dev.garrycraft.physicsblocks.PhysicsBlocks.recovered());
        state.add("physicsBlockConflicts", JSON.toJsonTree(dev.garrycraft.physicsblocks.PhysicsBlocks.conflicts()));
        state.add("physicsBlockMining", JSON.toJsonTree(dev.garrycraft.physicsblocks.DetachedBlockMining.state()));
        state.add("physicsBlockConsumed", JSON.toJsonTree(dev.garrycraft.physicsblocks.DetachedBlockMining.consumed()));
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
