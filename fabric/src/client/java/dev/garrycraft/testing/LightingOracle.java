package dev.garrycraft.testing;

import com.google.gson.Gson;
import dev.garrycraft.bridge.HostInput;
import dev.garrycraft.bridge.InputBridge;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.concurrent.CompletableFuture;
import net.minecraft.client.Minecraft;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.GameType;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.WallTorchBlock;

/** Repeats a fixed dark-room view with floor, wall, distant, and over-budget lights. */
public final class LightingOracle {
    public static final BlockPos PROBE = new BlockPos(35, -3, -1);
    private static final BlockPos WATER = PROBE.south().below();
    private static String request = "", phase = "waiting";
    private static boolean running;
    private static int tick;
    private static CompletableFuture<?> pending = CompletableFuture.completedFuture(null);
    private static GameType mode;
    private static ItemStack held;
    private static int fixtureSize;
    private static final ArrayList<BlockPos> owned = new ArrayList<>();
    private static final BlockPos FLOOR = PROBE.east().below(), WALL = PROBE.east();
    private LightingOracle() {}
    public static String request() { return request; }
    public static String phase() { return phase; }
    public static boolean running() { return running; }

    public static boolean beforeTick(Minecraft mc, HostInput host) {
        if (!running && host.test().startsWith("lighting:") && !host.test().equals(request)) {
            request = host.test(); phase = "prepare"; running = true; tick = 0; owned.clear();
            var server = mc.getSingleplayerServer(); var uuid = mc.player.getUUID();
            pending = server.submit(() -> {
                var peer = server.getPlayerList().getPlayer(uuid);
                mode = peer.gameMode.getGameModeForPlayer(); held = peer.getInventory().getItem(0).copy();
                peer.setGameMode(GameType.CREATIVE);
                peer.getInventory().setItem(0, new ItemStack(Blocks.STONE));
                for (var pos : new BlockPos[]{PROBE, PROBE.below()}) {
                    peer.level().setBlock(pos, Blocks.STONE.defaultBlockState(), 3); owned.add(pos);
                }
                for (var pos : new BlockPos[]{WATER.below(), WATER.north(), WATER.south(), WATER.east(), WATER.west()}) {
                    peer.level().setBlock(pos, Blocks.STONE.defaultBlockState(), 3); owned.add(pos);
                }
                peer.level().setBlock(WATER, Blocks.WATER.defaultBlockState(), 3); owned.add(WATER);
                fixtureSize = owned.size();
            });
        }
        if (!running) return false;
        InputBridge.apply(mc, HostInput.idle()); mc.gui.setScreen(null);
        if (!pending.isDone()) return true;
        pending.join();
        if (!host.test().equals(request)) { finish(mc); return false; }
        tick++;
        double x = phase.equals("far") ? 39.5 : 37.5;
        // Look down into the basin so screenshots prove water shading, not only the material flag.
        mc.player.setPos(x, -2, .5); mc.player.setDeltaMovement(0, 0, 0);
        mc.player.setYRot(90); mc.player.setXRot((float) Math.toDegrees(Math.atan2(2.73, x - 35.5)));
        mc.player.yRotO = mc.player.getYRot(); mc.player.xRotO = mc.player.getXRot();
        mc.player.getInventory().setSelectedSlot(0);
        if (tick == 40) phase = "dark";
        if (tick == 120) {
            phase = "floor";
            set(mc, FLOOR, Blocks.TORCH.defaultBlockState());
        }
        if (tick == 200) {
            phase = "wall";
            set(mc, WALL, Blocks.WALL_TORCH.defaultBlockState().setValue(WallTorchBlock.FACING, Direction.EAST));
        }
        if (tick == 280) phase = "far";
        if (tick == 360) {
            phase = "budget";
            var server = mc.getSingleplayerServer(); var uuid = mc.player.getUUID();
            pending = server.submit(() -> {
                var level = server.getPlayerList().getPlayer(uuid).level();
                for (int i = 0; i < 40; i++) {
                    var pos = new BlockPos(35 + i % 10, -4, 2 + i / 10);
                    owned.add(pos); level.setBlock(pos, Blocks.GLOWSTONE.defaultBlockState(), 3);
                }
            });
        }
        if (tick == 440) {
            phase = "removed";
            var server = mc.getSingleplayerServer(); var uuid = mc.player.getUUID();
            pending = server.submit(() -> {
                var level = server.getPlayerList().getPlayer(uuid).level();
                for (int i = fixtureSize; i < owned.size(); i++) level.setBlock(owned.get(i), Blocks.AIR.defaultBlockState(), 3);
            });
        }
        if (tick == 520) finish(mc);
        return true;
    }
    private static void set(Minecraft mc, BlockPos position, net.minecraft.world.level.block.state.BlockState state) {
        var server = mc.getSingleplayerServer(); var uuid = mc.player.getUUID(); owned.add(position);
        pending = server.submit(() -> server.getPlayerList().getPlayer(uuid).level().setBlock(position, state, 3));
    }
    private static void finish(Minecraft mc) {
        running = false; phase = "done";
        var server = mc.getSingleplayerServer(); var uuid = mc.player.getUUID();
        server.execute(() -> {
            var peer = server.getPlayerList().getPlayer(uuid);
            for (var pos : owned) peer.level().setBlock(pos, Blocks.AIR.defaultBlockState(), 3);
            peer.setGameMode(mode); peer.getInventory().setItem(0, held);
        });
        try {
            var output = Path.of(System.getProperty("garrycraft.artifacts")); Files.createDirectories(output);
            Files.writeString(output.resolve("lighting-minecraft.json"), new Gson().toJson(java.util.Map.of("request", request, "completed", true)));
        } catch (IOException failure) { throw new IllegalStateException("Could not save lighting trace", failure); }
    }
}
