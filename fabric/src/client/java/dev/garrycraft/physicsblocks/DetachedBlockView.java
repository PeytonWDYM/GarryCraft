package dev.garrycraft.physicsblocks;

import java.util.ArrayList;
import java.util.List;
import net.minecraft.core.BlockPos;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;

/** A single server task exposes a virtual block to vanilla mining without changing any world cell. */
public final class DetachedBlockView implements AutoCloseable {
    private static final ThreadLocal<DetachedBlockView> ACTIVE = new ThreadLocal<>();
    private final ServerLevel level;
    private final Player player;
    private final BlockPos position;
    private BlockState state;
    private final BlockEntity entity;
    private final List<Entity> spawned = new ArrayList<>();
    private final List<Runnable> effects = new ArrayList<>();
    private final List<Runnable> playerEffects = new ArrayList<>();

    DetachedBlockView(ServerLevel level, Player player, BlockPos position, PhysicsBlocks.BlockSnapshot block) {
        if (ACTIVE.get() != null) throw new IllegalStateException("Nested detached block transaction");
        this.level = level; this.player = player; this.position = position; state = block.state();
        entity = block.blockEntity() == null ? null : BlockEntity.loadStatic(position, state, block.blockEntity(), level.registryAccess());
        if (entity != null) entity.setLevel(level);
        ACTIVE.set(this);
    }
    public static DetachedBlockView active(Level level) {
        var view = ACTIVE.get();
        return view != null && view.level == level ? view : null;
    }
    public static DetachedBlockView active(Player player) {
        var view = ACTIVE.get();
        return view != null && view.player == player ? view : null;
    }
    public BlockState state(BlockPos point) { return point.equals(position) ? state : Blocks.AIR.defaultBlockState(); }
    public BlockEntity entity(BlockPos point) { return point.equals(position) && !state.isAir() ? entity : null; }
    public boolean set(BlockPos point, BlockState replacement) {
        if (!point.equals(position) || state.equals(replacement)) return false;
        var previous = state;
        if (entity != null && previous.getBlock() != replacement.getBlock()) entity.preRemoveSideEffects(point, previous);
        state = replacement;
        return true;
    }
    public boolean spawn(Entity entity) { spawned.add(entity); return true; }
    public void levelEvent(int event, BlockPos point, int data) { effects.add(() -> level.levelEvent(null, event, point, data)); }
    public void playerEffect(Runnable effect) { playerEffects.add(effect); }
    List<Entity> spawned() { return List.copyOf(spawned); }
    List<Runnable> effects() { return List.copyOf(effects); }
    List<Runnable> playerEffects() { return List.copyOf(playerEffects); }
    public void close() { ACTIVE.remove(); }
}
