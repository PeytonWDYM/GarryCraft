package dev.garrycraft.testing;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import dev.garrycraft.bridge.HostInput;
import dev.garrycraft.bridge.InputBridge;
import dev.garrycraft.physics.SourceClip;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.CompletableFuture;
import net.minecraft.client.Minecraft;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Items;
import net.minecraft.world.level.GameType;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.phys.Vec3;

/** Tests normal item use on bare Source ground and mining through Minecraft's held attack. */
public final class TerrainUseOracle {
    private static String request = "", phase = "waiting";
    private static boolean running, waterPassed, firePassed, lavaPassed, stonePassed, removed;
    private static int tick, crackVertices, debrisVertices;
    private static Vec3 origin;
    private static BlockPos water, fire, lava, stone;
    private static GameType mode;
    private static ItemStack[] inventory;
    private static String fireStates = "", fireSupport = "";
    private static CompletableFuture<?> pending = CompletableFuture.completedFuture(null);
    private TerrainUseOracle() {}
    public static String request() { return request; }
    public static String phase() { return phase; }
    public static boolean running() { return running; }
    public static void effects(int cracks, int debris) {
        if (running && phase.equals("breaking")) {
            crackVertices = Math.max(crackVertices, cracks);
            debrisVertices = Math.max(debrisVertices, debris);
        }
    }
    public static boolean beforeTick(Minecraft mc, HostInput host) {
        if (!running && host.test().startsWith("terrain:") && !host.test().equals(request)) {
            request = host.test(); phase = "prepare"; running = true; tick = crackVertices = debrisVertices = 0;
            water = fire = lava = stone = null;
            waterPassed = firePassed = lavaPassed = stonePassed = removed = false;
            origin = new Vec3(host.x(), host.y(), host.z());
            var server = mc.getSingleplayerServer(); var uuid = mc.player.getUUID();
            pending = server.submit(() -> {
                var peer = server.getPlayerList().getPlayer(uuid);
                mode = peer.gameMode.getGameModeForPlayer(); inventory = new ItemStack[9];
                for (int i = 0; i < 9; i++) inventory[i] = peer.getInventory().getItem(i).copy();
                peer.setGameMode(GameType.CREATIVE);
                peer.getInventory().setItem(0, new ItemStack(Items.STONE, 64));
                peer.getInventory().setItem(3, new ItemStack(Items.WATER_BUCKET));
                peer.getInventory().setItem(4, new ItemStack(Items.LAVA_BUCKET));
                peer.getInventory().setItem(5, ItemStack.EMPTY);
                peer.getInventory().setItem(8, new ItemStack(Items.FLINT_AND_STEEL));
            });
        }
        if (!running) return false;
        if (!pending.isDone()) { InputBridge.apply(mc, HostInput.idle()); return true; }
        pending.join();
        if (!host.test().equals(request)) { finish(mc); return false; }
        mc.gui.setScreen(null); InputBridge.apply(mc, HostInput.idle()); tick++;
        if (tick == 20) { phase = "water"; water = use(mc, 3, origin.add(-2, -1, -3), true); }
        if (tick == 45 && water != null) {
            waterPassed = mc.level.getBlockState(water).is(Blocks.WATER);
            var server = mc.getSingleplayerServer(); var uuid = mc.player.getUUID();
            pending = server.submit(() -> {
                var level = server.getPlayerList().getPlayer(uuid).level();
                for (var pos : BlockPos.betweenClosed(water.offset(-9, -2, -9), water.offset(9, 2, 9)))
                    if (level.getBlockState(pos).is(Blocks.WATER)) level.setBlock(pos, Blocks.AIR.defaultBlockState(), 3);
            });
        }
        if (tick == 65) { phase = "fire"; fire = use(mc, 8, origin.add(2, -.01, 2), false); }
        if (tick == 80 && fire != null) {
            firePassed = mc.level.getBlockState(fire).is(Blocks.FIRE);
            fireStates = mc.level.getBlockState(fire.below()) + "/" + mc.level.getBlockState(fire) + "/" + mc.level.getBlockState(fire.above());
            fireSupport = String.valueOf(dev.garrycraft.physics.SourceSurface.supportsFace(fire.below(), Direction.UP));
        }
        if (tick == 120) {
            phase = "clear-fire";
            var server = mc.getSingleplayerServer(); var uuid = mc.player.getUUID();
            pending = server.submit(() -> {
                var peer = server.getPlayerList().getPlayer(uuid); var level = peer.level();
                if (fire != null) for (var pos : BlockPos.betweenClosed(fire.offset(-2, -1, -2), fire.offset(2, 2, 2)))
                    if (level.getBlockState(pos).is(Blocks.FIRE)) level.setBlock(pos, Blocks.AIR.defaultBlockState(), 3);
                for (var actor : level.getEntitiesOfClass(dev.garrycraft.combat.SourceActor.class, peer.getBoundingBox().inflate(16))) actor.clearFire();
            });
        }
        if (tick == 140) { phase = "lava"; lava = use(mc, 4, origin.add(2, -.01, 2), true); }
        if (tick == 170 && lava != null) lavaPassed = mc.level.getBlockState(lava).is(Blocks.LAVA);
        if (tick == 220) {
            phase = "prepare-stone";
            var server = mc.getSingleplayerServer(); var uuid = mc.player.getUUID();
            pending = server.submit(() -> {
                var peer = server.getPlayerList().getPlayer(uuid); var level = peer.level();
                if (lava != null) for (var pos : BlockPos.betweenClosed(lava.offset(-9, -2, -9), lava.offset(9, 2, 9)))
                    if (level.getBlockState(pos).is(Blocks.LAVA)) level.setBlock(pos, Blocks.AIR.defaultBlockState(), 3);
                peer.clearFire(); peer.setHealth(20); peer.setGameMode(GameType.SURVIVAL);
            });
        }
        if (tick == 240) stone = use(mc, 0, origin.add(-2, -1, 2), false);
        if (tick == 265 && stone != null) stonePassed = mc.level.getBlockState(stone).is(Blocks.STONE);
        if (tick >= 280 && tick < 480 && stone != null) {
            phase = "breaking"; mc.player.getInventory().setSelectedSlot(5);
            aim(mc, Vec3.atCenterOf(stone)); mc.options.keyAttack.setDown(true);
            if (tick == 280) mc.gameMode.startDestroyBlock(stone, Direction.UP);
        }
        if (tick == 485 && stone != null) removed = mc.level.getBlockState(stone).isAir();
        if (tick == 500) finish(mc);
        return true;
    }
    private static BlockPos use(Minecraft mc, int slot, Vec3 point, boolean bucket) {
        mc.player.getInventory().setSelectedSlot(slot); aim(mc, point);
        var hit = mc.player.pick(mc.player.blockInteractionRange(), 1, false);
        if (!(hit instanceof SourceClip.HostHit nativeHit)) return null;
        if (bucket) mc.gameMode.useItem(mc.player, InteractionHand.MAIN_HAND);
        else mc.gameMode.useItemOn(mc.player, InteractionHand.MAIN_HAND, nativeHit);
        return nativeHit.getBlockPos();
    }
    private static void aim(Minecraft mc, Vec3 point) {
        var delta = point.subtract(mc.player.getEyePosition());
        mc.player.setYRot((float) Math.toDegrees(Math.atan2(-delta.x, delta.z)));
        mc.player.setXRot((float) -Math.toDegrees(Math.atan2(delta.y, Math.sqrt(delta.x * delta.x + delta.z * delta.z))));
        mc.player.yRotO = mc.player.getYRot(); mc.player.xRotO = mc.player.getXRot();
    }
    private static void finish(Minecraft mc) {
        running = false; phase = "done"; mc.options.keyAttack.setDown(false); mc.gameMode.stopDestroyBlock();
        var result = new JsonObject(); var json = new Gson();
        result.addProperty("request", request); result.addProperty("waterPassed", waterPassed);
        result.addProperty("firePassed", firePassed); result.addProperty("lavaPassed", lavaPassed);
        result.addProperty("stonePassed", stonePassed); result.addProperty("removed", removed);
        result.addProperty("crackVertices", crackVertices); result.addProperty("debrisVertices", debrisVertices);
        result.addProperty("fireStates", fireStates); result.addProperty("fireSupport", fireSupport);
        result.add("water", json.toJsonTree(water)); result.add("fire", json.toJsonTree(fire));
        result.add("lava", json.toJsonTree(lava)); result.add("stone", json.toJsonTree(stone));
        var output = Path.of(System.getProperty("garrycraft.artifacts"));
        try { Files.createDirectories(output); Files.writeString(output.resolve("terrain-minecraft.json"), json.toJson(result)); }
        catch (IOException failure) { throw new IllegalStateException("Could not save terrain trace", failure); }
        var server = mc.getSingleplayerServer(); var uuid = mc.player.getUUID();
        server.execute(() -> {
            var peer = server.getPlayerList().getPlayer(uuid); peer.setGameMode(mode);
            for (int i = 0; i < 9; i++) peer.getInventory().setItem(i, inventory[i]);
            if (lava != null) peer.level().setBlock(lava, Blocks.AIR.defaultBlockState(), 3);
            if (fire != null) peer.level().setBlock(fire, Blocks.AIR.defaultBlockState(), 3);
            if (stone != null) peer.level().setBlock(stone, Blocks.AIR.defaultBlockState(), 3);
        });
    }
}
