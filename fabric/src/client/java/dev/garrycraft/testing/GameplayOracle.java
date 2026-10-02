package dev.garrycraft.testing;

import com.google.gson.Gson;
import dev.garrycraft.bridge.HostInput;
import dev.garrycraft.bridge.InputBridge;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.CompletableFuture;
import net.minecraft.client.CameraType;
import net.minecraft.client.Minecraft;
import net.minecraft.core.BlockPos;
import net.minecraft.core.component.DataComponents;
import net.minecraft.world.entity.*;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Items;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.phys.Vec3;

/** Observes vanilla idle AI and actual render exports in a fresh, owned world. */
public final class GameplayOracle {
    private record MobSample(int tick, String type, Vec3 position, boolean pathDone, boolean target, int destinations) {}
    private static final List<PathfinderMob> MOBS = new ArrayList<>();
    private static final List<Vec3> STARTS = new ArrayList<>();
    private static final List<MobSample> SAMPLES = new ArrayList<>();
    private static final Map<Integer, Set<Integer>> TEXTURES = new HashMap<>();
    private static final Map<String, Integer> AVATAR = new HashMap<>();
    private static final List<BlockPos> BLOCKS = new ArrayList<>();
    private static CompletableFuture<?> pending = CompletableFuture.completedFuture(null);
    private static String request = "", phase = "waiting";
    private static boolean running;
    private static int tick;
    private static double x, y, z;
    private static CameraType camera;
    private static ItemStack chest;
    private static BlockPos water;
    private static boolean sourceWater, blockedWater;

    private GameplayOracle() {}
    public static String request() { return request; }
    public static String phase() { return phase; }
    public static void avatar(int vertices) {
        // Allow the real equipment update to reach the client before measuring each phase.
        if (running && tick >= 20 && (tick < 80 || tick >= 100 && tick < 160 || tick >= 180))
            AVATAR.merge(phase, vertices, Math::max);
    }
    public static void texture(int id, byte[] rgba) {
        if (running) TEXTURES.computeIfAbsent(id, ignored -> new HashSet<>()).add(Arrays.hashCode(rgba));
    }

    public static boolean beforeTick(Minecraft mc, HostInput host) {
        if (!running && host.test().startsWith("polish:") && !host.test().equals(request)) {
            request = host.test(); phase = "plain-armor"; tick = 0; running = true;
            x = host.x(); y = host.y(); z = host.z(); camera = mc.options.getCameraType();
            MOBS.clear(); STARTS.clear(); SAMPLES.clear(); TEXTURES.clear(); AVATAR.clear(); BLOCKS.clear();
            mc.options.setCameraType(CameraType.THIRD_PERSON_FRONT);
            var server = mc.getSingleplayerServer(); var uuid = mc.player.getUUID();
            pending = server.submit(() -> {
                var peer = server.getPlayerList().getPlayer(uuid); var level = peer.level();
                chest = peer.getItemBySlot(EquipmentSlot.CHEST).copy();
                peer.setItemSlot(EquipmentSlot.CHEST, new ItemStack(Items.DIAMOND_CHESTPLATE));
                for (var type : List.of(EntityTypes.IRON_GOLEM, EntityTypes.VILLAGER, EntityTypes.COW)) {
                    var mob = (PathfinderMob) type.create(level, EntitySpawnReason.COMMAND);
                    mob.setPos(x + 3 + MOBS.size() * 3, y, z + 3); mob.getRandom().setSeed(42 + MOBS.size());
                    level.addFreshEntity(mob); MOBS.add(mob); STARTS.add(mob.position());
                }
                water = BlockPos.containing(x - 3, y, z + 3);
                for (int dx = -2; dx <= 2; dx++) for (int dz = -2; dz <= 2; dz++) {
                    var floor = water.offset(dx, -1, dz); BLOCKS.add(floor);
                    level.setBlock(floor, Blocks.STONE.defaultBlockState(), 3);
                    var cell = water.offset(dx, 0, dz); BLOCKS.add(cell);
                    if (Math.abs(dx) == 2 || Math.abs(dz) == 2) level.setBlock(cell, Blocks.STONE.defaultBlockState(), 3);
                }
                level.setBlock(water, Blocks.WATER.defaultBlockState(), 3);
            });
        }
        if (!running) return false;
        InputBridge.apply(mc, HostInput.idle()); mc.gui.setScreen(null);
        if (!pending.isDone()) return true;
        pending.join();
        if (!host.test().equals(request)) { finish(mc, false); return false; }
        mc.player.setPos(x, y, z); mc.player.setDeltaMovement(Vec3.ZERO);
        mc.player.setYRot(0); mc.player.setXRot(20); tick++;
        if (tick == 80) {
            phase = "enchanted-armor";
            var server = mc.getSingleplayerServer(); var uuid = mc.player.getUUID();
            pending = server.submit(() -> server.getPlayerList().getPlayer(uuid).getItemBySlot(EquipmentSlot.CHEST)
                .set(DataComponents.ENCHANTMENT_GLINT_OVERRIDE, true));
        }
        if (tick == 160) { phase = "rear-armor"; mc.options.setCameraType(CameraType.THIRD_PERSON_BACK); }
        if (tick % 20 == 0) {
            var server = mc.getSingleplayerServer(); final int sampleTick = tick;
            pending = server.submit(() -> {
                if (sampleTick == 200) {
                    sourceWater = !server.overworld().getFluidState(water).isEmpty();
                    blockedWater = server.overworld().getFluidState(water.east()).isEmpty();
                }
                for (var mob : MOBS) {
                    int destinations = 0;
                    for (int i = 0; i < 20; i++) if (net.minecraft.world.entity.ai.util.LandRandomPos.getPos(mob, 10, 7) != null) destinations++;
                    SAMPLES.add(new MobSample(sampleTick, mob.getType().toString(), mob.position(), mob.getNavigation().isDone(),
                        mob.getTarget() != null, destinations));
                }
            });
        }
        if (tick == 720) finish(mc, true);
        return true;
    }
    private static void finish(Minecraft mc, boolean complete) {
        running = false; phase = "done"; mc.options.setCameraType(camera);
        var server = mc.getSingleplayerServer(); var uuid = mc.player.getUUID();
        pending = server.submit(() -> {
            var peer = server.getPlayerList().getPlayer(uuid); var travel = new ArrayList<Double>();
            for (int i = 0; i < MOBS.size(); i++) {
                var mob = MOBS.get(i); var start = STARTS.get(i);
                travel.add(SAMPLES.stream().filter(sample -> sample.type().equals(mob.getType().toString()))
                    .mapToDouble(sample -> sample.position().distanceTo(start)).max().orElse(0));
                mob.remove(Entity.RemovalReason.DISCARDED);
            }
            for (var pos : BLOCKS) peer.level().setBlock(pos, Blocks.AIR.defaultBlockState(), 3);
            peer.setItemSlot(EquipmentSlot.CHEST, chest);
            var report = Map.of("request", request, "completed", complete, "mobTravel", travel, "mobs", SAMPLES,
                "sourceWater", sourceWater, "nativeWallDry", blockedWater,
                "avatarVertices", AVATAR, "textureFrames", TEXTURES.entrySet().stream()
                    .collect(java.util.stream.Collectors.toMap(Map.Entry::getKey, entry -> entry.getValue().size())));
            try {
                var output = Path.of(System.getProperty("garrycraft.artifacts")); Files.createDirectories(output);
                Files.writeString(output.resolve("polish-minecraft.json"), new Gson().toJson(report));
            } catch (java.io.IOException failure) { throw new IllegalStateException("Could not save gameplay trace", failure); }
        });
    }
}
