package dev.garrycraft.physicsblocks;

import dev.garrycraft.GarryCraftClient;
import dev.garrycraft.bridge.HostInput;
import dev.garrycraft.item.PhysicsGun;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.minecraft.client.Minecraft;
import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.BlockParticleOption;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.server.MinecraftServer;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.phys.Vec3;

/** Source identifies the moving body. Minecraft advances vanilla block mining once per server tick. */
public final class DetachedBlockMining {
    public record State(long id, float progress, int stage, String error) {}
    private record Target(String session, long generation, UUID player, HostInput.BlockMine block, long received) {}
    private static volatile Target target;
    private static volatile State state = new State(0, 0, -1, "");
    private static volatile List<Long> consumed = List.of();
    private static long inputFrame = -1, miningId, press = -1;
    private static volatile long generation = -1;
    private static float progress;
    private static int miningTicks;
    // MultiPlayerGameMode.continueDestroyBlock uses five ticks in installed Minecraft 26.3.
    private static int destroyDelay;
    private static ItemStack tool = ItemStack.EMPTY;

    public static void initialize() { ServerTickEvents.END_SERVER_TICK.register(DetachedBlockMining::tick); }
    public static void input(Minecraft mc, HostInput input) {
        if (input.frame() == inputFrame && input.active()) return;
        inputFrame = input.frame();
        target = suppressAttack(mc, input) ? new Target(input.session(), PhysicsBlocks.generation(), mc.player.getUUID(), input.blockMine(), System.nanoTime()) : null;
        if (target != null && target.block().attack() && !mc.player.isUsingItem())
            mc.player.swing(InteractionHand.MAIN_HAND, mc.player.getMainHandItem().getAttackAnimation(), false);
    }
    public static boolean suppressAttack(Minecraft mc, HostInput input) {
        return input.active() && GarryCraftClient.linked() && mc.player != null && mc.gui.screen() == null
            && !PhysicsGun.equipped(mc.player) && input.blockMine() != null && input.blockMine().id() > 0;
    }
    private static void reset() {
        miningId = 0; progress = 0; miningTicks = 0; tool = ItemStack.EMPTY;
        state = new State(0, 0, -1, "");
    }
    private static void tick(MinecraftServer server) {
        if (!server.isSingleplayer()) return;
        if (generation != PhysicsBlocks.generation()) {
            consumed = List.of(); destroyDelay = 0; press = -1; reset();
            generation = PhysicsBlocks.generation();
        }
        var current = target;
        if (current == null || current.generation() != generation || System.nanoTime() - current.received() > 250_000_000L || !current.block().attack()) {
            reset(); return;
        }
        var hit = current.block();
        var block = PhysicsBlocks.blocks().stream().filter(candidate -> candidate.id() == hit.id() && candidate.session().equals(current.session())).findFirst().orElse(null);
        var player = server.getPlayerList().getPlayer(current.player());
        if (block == null || player == null || PhysicsGun.equipped(player) || !player.isAlive() || player.isSpectator() || player.isUsingItem()) { reset(); return; }
        // A new click uses vanilla's start-destroy path. Held attack uses its post-break delay.
        if (press != hit.press()) { press = hit.press(); destroyDelay = 0; }
        if (destroyDelay > 0) { destroyDelay--; reset(); return; }
        var point = new Vec3(hit.hx(), hit.hy(), hit.hz());
        var center = new Vec3(hit.x(), hit.y(), hit.z());
        var level = server.getLevel(block.dimension());
        var position = BlockPos.containing(center);
        double range = player.blockInteractionRange();
        if (!Double.isFinite(center.lengthSqr()) || !Double.isFinite(point.lengthSqr()) || player.level() != level
            || player.getEyePosition().distanceToSqr(point) > range * range || !level.mayInteract(player, position) || !level.isLoaded(position)) {
            reset(); return;
        }
        var held = player.getMainHandItem();
        if (miningId != block.id() || !ItemStack.isSameItemSameComponents(tool, held)) {
            reset(); miningId = block.id(); tool = held.copy();
        }
        float speed;
        try (var view = new DetachedBlockView(level, player, position, block)) {
            if (!held.canDestroyBlock(block.state(), level, position, player)
                || player.blockActionRestricted(level, position, player.gameMode.getGameModeForPlayer())) { reset(); return; }
            speed = block.state().getDestroyProgress(player, level, position);
            if (miningTicks == 0) block.state().attack(level, position, player);
        }
        if (speed <= 0) { reset(); return; }
        progress = player.gameMode.isCreative() ? 1 : progress + speed;
        state = new State(block.id(), Math.min(progress, 1), Math.min(9, (int) (progress * 10)), "");
        if (progress < 1) {
            if (miningTicks++ % 4 == 0) {
                var sound = block.state().getSoundType();
                level.playSound(null, point.x, point.y, point.z, sound.getHitSound(), net.minecraft.sounds.SoundSource.BLOCKS,
                    (sound.getVolume() + 1) / 8, sound.getPitch() * .5f);
                level.sendParticles(new BlockParticleOption(ParticleTypes.BLOCK, block.state()), point.x, point.y, point.z, 1, 0, 0, 0, 0);
                player.swing(InteractionHand.MAIN_HAND, held.getAttackAnimation(), false);
            }
            return;
        }
        var before = held.copy();
        List<net.minecraft.world.entity.Entity> loot;
        List<Runnable> effects;
        List<Runnable> playerEffects;
        try (var view = new DetachedBlockView(level, player, position, block)) {
            if (!player.gameMode.destroyBlock(position)) { reset(); return; }
            loot = view.spawned();
            effects = view.effects();
            playerEffects = view.playerEffects();
        }
        try {
            DetachedBlockLoot.commit(server, level, block, loot, playerEffects);
            for (var effect : effects) effect.run();
            PhysicsBlocks.consume(block.id());
            var completed = new ArrayList<>(consumed); completed.add(block.id()); consumed = List.copyOf(completed);
            destroyDelay = 5;
            reset();
        } catch (IOException failure) {
            GarryCraftClient.LOG.error("Cannot commit detached block mining", failure);
            // A failed pre-commit write leaves the detached block available and restores its tool.
            // A durable consumed journal instead owns the loot. Recovery must finish that transaction.
            if (DetachedBlockLoot.committed(block.journal())) {
                PhysicsBlocks.consume(block.id());
                var completed = new ArrayList<>(consumed); completed.add(block.id()); consumed = List.copyOf(completed);
                destroyDelay = 5;
            } else player.setItemInHand(InteractionHand.MAIN_HAND, before);
            miningId = 0; progress = 0; miningTicks = 0;
            state = new State(block.id(), 0, -1, "cannot save detached block mining");
        }
    }
    public static State state() { return generation == PhysicsBlocks.generation() ? state : new State(0, 0, -1, ""); }
    public static List<Long> consumed() { return generation == PhysicsBlocks.generation() ? consumed : List.of(); }
    private DetachedBlockMining() {}
}
