package dev.garrycraft.testing;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import dev.garrycraft.GarryCraftClient;
import dev.garrycraft.bridge.HostInput;
import dev.garrycraft.bridge.InputBridge;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import net.minecraft.client.Minecraft;
import net.minecraft.core.BlockPos;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.phys.Vec3;

/** Replays the same inputs through the real LocalPlayer, first on blocks, then on Source geometry. */
public final class PhysicsOracle {
    public record Scenario(String name, int ticks, boolean forward, boolean sprint, boolean sneak,
                           int[] jumpTicks, double startHeight, boolean wall, boolean ceiling,
                           double startZOffset, boolean step, boolean right) {}
    public record Plan(int version, double toleranceBlocks, List<Scenario> cases) {}
    public record Sample(int tick, double x, double y, double z, double vx, double vy, double vz, boolean ground, double beforeVx, double beforeVz, boolean sprint) {}
    public record Result(String scenario, double maxPositionError, double maxVelocityError, boolean groundMatches, boolean passed) {}
    private static final Gson JSON = new Gson();
    public static volatile boolean reference;
    public static boolean sampledReference;
    private static String lastRequest = "";
    private static Plan plan;
    private static int scenarioIndex;
    private static int tick;
    private static int settle;
    private static boolean running;
    private static boolean sampling;
    private static double beforeVx;
    private static double beforeVz;
    private static CompletableFuture<Void> prepare;
    private static final List<Sample> baseline = new ArrayList<>();
    private static final List<Sample> actual = new ArrayList<>();
    private static final List<Result> results = new ArrayList<>();
    private static Path output;
    private static double sourceX, sourceY, sourceZ;

    private PhysicsOracle() {}
    public static boolean running() { return running; }
    public static String fixture() { return running ? plan.cases().get(scenarioIndex).name() : ""; }

    public static boolean beforeTick(Minecraft mc, HostInput host) {
        if (host.test() != null && (host.test().startsWith("entities:") || host.test().startsWith("damage:") || host.test().startsWith("terrain:") || host.test().startsWith("lighting:") || host.test().startsWith("responsiveness:"))) return false;
        if (!running && host.test() != null && !host.test().isEmpty() && !host.test().equals(lastRequest)) {
            lastRequest = host.test();
            sourceX = host.x();
            sourceY = host.y();
            sourceZ = host.z();
            try {
                try (var scenarios = PhysicsOracle.class.getResourceAsStream("/garrycraft/scenarios.json")) {
                    plan = JSON.fromJson(new java.io.InputStreamReader(scenarios, java.nio.charset.StandardCharsets.UTF_8), Plan.class);
                }
                output = Path.of(System.getProperty("garrycraft.artifacts", "../../artifacts/physics"));
                Files.createDirectories(output);
            } catch (IOException error) { throw new IllegalStateException("Could not load physics scenarios", error); }
            running = true;
            reference = true;
            scenarioIndex = 0;
            results.clear();
            prepare(mc);
        }
        if (running && (host.test() == null || host.test().isEmpty())) {
            running = false;
            reference = false;
        }
        sampling = false;
        if (!running) return false;
        mc.gui.setScreen(null);
        mc.player.noPhysics = false;
        mc.player.setNoGravity(false);
        if (!prepare.isDone()) { InputBridge.apply(mc, HostInput.idle()); return true; }
        if (settle > 0) {
            settle--;
            reset(mc);
            InputBridge.apply(mc, HostInput.idle());
            return true;
        }
        sampling = true;
        beforeVx = mc.player.getDeltaMovement().x;
        beforeVz = mc.player.getDeltaMovement().z;
        Scenario scenario = plan.cases().get(scenarioIndex);
        boolean jump = false;
        if (scenario.jumpTicks() != null) for (int scheduled : scenario.jumpTicks()) if (scheduled == tick) jump = true;
        InputBridge.apply(mc, new HostInput(1, host.session(), host.frame(), true, 0, 0, 0, 0, 0,
                scenario.forward(), false, false, scenario.right(), jump, scenario.sneak(), scenario.sprint(),
                false, false, 0, "", 0, host.teleportSeq(), host.damageTotal(), 0, false, false, false, 0, 0, "", host.targetFps(), false, List.of(), List.of(), host.viewportWidth(), host.viewportHeight(), 0, 0, "", List.of(), host.renderEpoch(), host.damageScaling()));
        return true;
    }

    private static void reset(Minecraft mc) {
        double x = reference ? 128.5 : sourceX;
        double z = (reference ? 128.5 : sourceZ) + plan.cases().get(scenarioIndex).startZOffset();
        double y = (reference ? 64 : sourceY) + plan.cases().get(scenarioIndex).startHeight();
        mc.player.setPos(x, y, z);
        mc.player.setDeltaMovement(Vec3.ZERO);
        mc.player.setOnGround(plan.cases().get(scenarioIndex).startHeight() == 0);
        mc.player.setSprinting(false);
        mc.player.fallDistance = 0;
        mc.player.setHealth(20);
        mc.player.getFoodData().setFoodLevel(20);
    }

    private static void prepare(Minecraft mc) {
        tick = 0;
        settle = 30;
        if (reference) baseline.clear(); else actual.clear();
        Scenario scenario = plan.cases().get(scenarioIndex);
        var server = mc.getSingleplayerServer();
        prepare = server.submit(() -> {
            var level = server.overworld();
            for (int x = 120; x <= 168; x++) for (int z = 120; z <= 176; z++) {
                level.setBlock(new BlockPos(x, 63, z), Blocks.STONE.defaultBlockState(), 3);
            }
            for (int x = 125; x <= 132; x++) for (int y = 64; y <= 68; y++) {
                var block = scenario.wall() ? Blocks.STONE.defaultBlockState()
                        : scenario.step() && y == 64 ? Blocks.STONE_SLAB.defaultBlockState() : Blocks.AIR.defaultBlockState();
                level.setBlock(new BlockPos(x, y, 136), block, 3);
            }
            for (int x = 124; x <= 132; x++) for (int z = 124; z <= 132; z++) {
                level.setBlock(new BlockPos(x, 66, z), scenario.ceiling() ? Blocks.STONE.defaultBlockState() : Blocks.AIR.defaultBlockState(), 3);
            }
            var peer = server.getPlayerList().getPlayer(mc.player.getUUID());
            peer.teleportTo(reference ? 128.5 : sourceX, (reference ? 64 : sourceY) + scenario.startHeight(),
                    (reference ? 128.5 : sourceZ) + scenario.startZOffset());
            peer.setDeltaMovement(Vec3.ZERO);
            peer.fallDistance = 0;
            peer.setHealth(20);
            peer.getFoodData().setFoodLevel(20);
        });
        GarryCraftClient.LOG.info("Physics oracle: {} {}", scenario.name(), reference ? "vanilla" : "Source");
    }

    public static void afterTick(Minecraft mc) {
        sampledReference = reference;
        if (!running || !sampling) return;
        var p = mc.player;
        var velocity = p.getDeltaMovement();
        Sample sample = new Sample(tick, p.getX() - (reference ? 128.5 : sourceX), p.getY() - (reference ? 64 : sourceY),
                p.getZ() - (reference ? 128.5 : sourceZ), velocity.x, velocity.y, velocity.z, p.onGround(), beforeVx, beforeVz, p.isSprinting());
        (reference ? baseline : actual).add(sample);
        tick++;
        if (tick < plan.cases().get(scenarioIndex).ticks()) return;
        if (reference) {
            reference = false;
            prepare(mc);
            return;
        }
        finishScenario();
        scenarioIndex++;
        if (scenarioIndex < plan.cases().size()) {
            reference = true;
            prepare(mc);
        } else {
            running = false;
            reference = false;
            write(output.resolve("results.json"), results);
            GarryCraftClient.LOG.info("Physics oracle complete: {}", output.toAbsolutePath());
        }
    }

    private static void finishScenario() {
        double positionError = 0;
        double velocityError = 0;
        boolean ground = true;
        for (int i = 0; i < baseline.size(); i++) {
            Sample a = baseline.get(i), b = actual.get(i);
            positionError = Math.max(positionError, Math.max(Math.abs(a.x() - b.x()), Math.max(Math.abs(a.y() - b.y()), Math.abs(a.z() - b.z()))));
            velocityError = Math.max(velocityError, Math.max(Math.abs(a.vx() - b.vx()), Math.max(Math.abs(a.vy() - b.vy()), Math.abs(a.vz() - b.vz()))));
            ground &= a.ground() == b.ground();
        }
        String name = plan.cases().get(scenarioIndex).name();
        Result result = new Result(name, positionError, velocityError, ground,
                ground && positionError <= plan.toleranceBlocks() && velocityError <= plan.toleranceBlocks());
        results.add(result);
        JsonObject trace = new JsonObject();
        trace.add("vanilla", JSON.toJsonTree(baseline));
        trace.add("source", JSON.toJsonTree(actual));
        write(output.resolve(name + ".json"), trace);
        GarryCraftClient.LOG.info("Physics oracle result: {}", JSON.toJson(result));
    }

    private static void write(Path path, Object value) {
        try { Files.writeString(path, JSON.toJson(value)); }
        catch (IOException error) { throw new IllegalStateException("Could not write physics trace", error); }
    }
}
