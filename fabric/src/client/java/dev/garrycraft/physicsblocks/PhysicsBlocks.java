package dev.garrycraft.physicsblocks;

import dev.garrycraft.GarryCraftClient;
import dev.garrycraft.bridge.HostInput;
import dev.garrycraft.item.PhysicsGun;
import dev.garrycraft.render.WorldExporter;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicReference;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerLifecycleEvents;
import net.minecraft.client.Minecraft;
import net.minecraft.core.BlockPos;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.nbt.NbtUtils;
import net.minecraft.server.MinecraftServer;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.state.BlockState;

/** The integrated server owns block transactions. The render thread only captures immutable models. */
public final class PhysicsBlocks {
    public record BlockSnapshot(long id, String session, String instance, BlockPos position,
        net.minecraft.resources.ResourceKey<net.minecraft.world.level.Level> dimension,
        BlockState state, CompoundTag blockEntity, List<double[]> boxes, Path journal, long generation) {}
    public record Result(long id, String status, int x, int y, int z, List<double[]> boxes,
        String error, long worldSequence, String instance) {}
    private record ServerResult(BlockSnapshot block, String error) {}
    private static final JournalWriter WRITER = new JournalWriter();
    private static final ConcurrentLinkedQueue<BlockSnapshot> CAPTURES = new ConcurrentLinkedQueue<>();
    private static final AtomicReference<List<ServerResult>> SERVER_RESULTS = new AtomicReference<>(List.of());
    private static final AtomicReference<List<BlockSnapshot>> BLOCKS = new AtomicReference<>(List.of());
    private static volatile long generation;
    private static volatile String session = "";
    private static volatile boolean active;
    private static volatile boolean canPick;
    private static volatile int recovered;
    private static volatile List<String> conflicts = List.of();
    private static long requested;
    private static String renderInstance = "";
    private static long acknowledged;
    private static List<Result> results = List.of();

    public static void initialize() {
        ServerLifecycleEvents.SERVER_STARTED.register(server -> { if (server.isSingleplayer()) recover(server); });
        ServerLifecycleEvents.SERVER_STOPPING.register(server -> {
            if (!server.isSingleplayer()) return;
            active = false;
            generation++;
            BLOCKS.set(List.of());
            SERVER_RESULTS.set(List.of());
            WRITER.flush();
            recover(server);
        });
    }

    public static void tick(Minecraft mc, HostInput input) {
        boolean linked = GarryCraftClient.linked() && input.active();
        if (!session.equals(input.session()) || active && !linked) {
            generation++;
            active = false;
            session = input.session();
            requested = 0;
            acknowledged = 0;
            results = List.of();
            CAPTURES.clear();
            SERVER_RESULTS.set(List.of());
            BLOCKS.set(List.of());
            var server = mc.getSingleplayerServer();
            WorldExporter.clearDetaches();
            if (server != null) server.execute(() -> { WRITER.flush(); recover(server); });
        }
        active = linked;
        canPick = linked && mc.player != null && PhysicsGun.equipped(mc.player) && mc.gui.screen() == null;
        if (!linked || mc.player == null || mc.getSingleplayerServer() == null) return;
        if (!renderInstance.equals(GarryCraftClient.renderInstance())) {
            renderInstance = GarryCraftClient.renderInstance();
        }
        if (input.blockPick() != null) for (var pick : input.blockPick()) {
            if (pick.id() <= requested) continue;
            requested = pick.id();
            var server = mc.getSingleplayerServer();
            var player = mc.player.getUUID();
            long token = generation;
            String requestSession = session;
            server.execute(() -> prepare(server, player, pick, requestSession, token));
        }
        var published = new ArrayList<Result>();
        long ack = acknowledged;
        for (var reply : SERVER_RESULTS.get()) {
            var block = reply.block();
            if (!block.session().equals(session)) continue;
            long sequence = 0;
            if (reply.error().isEmpty()) {
                sequence = block.instance().equals(renderInstance) ? WorldExporter.commitDetach(block.id()) : WorldExporter.clearSequence();
                if (sequence == 0) continue;
            }
            ack = Math.max(ack, block.id());
            published.add(new Result(block.id(), reply.error().isEmpty() ? "detached" : "rejected",
                block.position().getX(), block.position().getY(), block.position().getZ(), block.boxes(),
                reply.error(), sequence, renderInstance));
        }
        acknowledged = ack;
        results = List.copyOf(published);
    }

    private static void prepare(MinecraftServer server, UUID playerId, HostInput.BlockPick request, String requestSession, long token) {
        if (!current(requestSession, token)) return;
        var player = server.getPlayerList().getPlayer(playerId);
        if (player == null) return;
        var position = new BlockPos(request.x(), request.y(), request.z());
        var level = player.level();
        String error = "";
        if (!request.instance().equals(GarryCraftClient.renderInstance())) error = "stale render instance";
        else if (!canPick || !PhysicsGun.equipped(player) || !player.getAbilities().mayBuild || !level.mayInteract(player, position)) error = "block pickup is not permitted";
        else if (player.distanceToSqr(position.getX() + .5, position.getY() + .5, position.getZ() + .5) > 256 * 256) error = "block is outside physics gun range";
        else if (level.isOutsideBuildHeight(position) || !level.isLoaded(position)) error = "block cell is not loaded";
        if (!error.isEmpty()) {
            reply(new BlockSnapshot(request.id(), requestSession, request.instance(), position, level.dimension(),
                Blocks.AIR.defaultBlockState(), null, List.of(), null, token), error);
            return;
        }
        var state = level.getBlockState(position);
        var entity = level.getBlockEntity(position);
        var boxes = state.getCollisionShape(level, position).toAabbs();
        if (boxes.isEmpty()) boxes = state.getShape(level, position).toAabbs();
        var snapshot = new BlockSnapshot(request.id(), requestSession, request.instance(), position, level.dimension(), state,
            entity == null ? null : entity.saveWithFullMetadata(level.registryAccess()), boxes.stream().map(box -> new double[]{
                box.minX - .5, box.minY - .5, box.minZ - .5, box.maxX - .5, box.maxY - .5, box.maxZ - .5}).toList(),
            PhysicsBlockJournal.directory(server).resolve(UUID.randomUUID() + ".nbt"), token);
        if (state.isAir() || snapshot.boxes().isEmpty()) error = "block has no solid or selection shape";
        else if (state.getDestroySpeed(level, position) < 0) error = "block cannot be removed";
        if (!error.isEmpty()) { reply(snapshot, error); return; }
        CAPTURES.add(snapshot);
    }

    public static BlockSnapshot capture() { return CAPTURES.poll(); }
    public static List<BlockSnapshot> blocks() { return BLOCKS.get(); }
    static void consume(long id) {
        BLOCKS.set(BLOCKS.get().stream().filter(block -> block.id() != id).toList());
        SERVER_RESULTS.set(SERVER_RESULTS.get().stream().filter(result -> result.block().id() != id).toList());
    }
    public static void reject(Minecraft mc, BlockSnapshot block, String error) {
        mc.getSingleplayerServer().execute(() -> reply(block, error));
    }

    public static void captured(Minecraft mc, BlockSnapshot block, boolean visible) {
        if (!current(block.session(), block.generation())) return;
        canPick = PhysicsGun.equipped(mc.player) && mc.gui.screen() == null;
        var server = mc.getSingleplayerServer();
        if (!block.instance().equals(GarryCraftClient.renderInstance())) {
            server.execute(() -> reply(block, "stale render instance"));
            return;
        }
        if (!visible) { server.execute(() -> reply(block, "block renderer produced no geometry")); return; }
        var playerId = mc.player.getUUID();
        server.execute(() -> {
            if (!current(block.session(), block.generation())) return;
            var saved = new CompoundTag();
            saved.putString("phase", "prepared");
            saved.putString("dimension", block.dimension().identifier().toString());
            saved.putInt("x", block.position().getX()); saved.putInt("y", block.position().getY()); saved.putInt("z", block.position().getZ());
            saved.put("state", NbtUtils.writeBlockState(block.state()));
            if (block.blockEntity() != null) saved.put("blockEntity", block.blockEntity());
            WRITER.execute(() -> {
                try {
                    PhysicsBlockJournal.write(block.journal(), saved);
                    server.execute(() -> detach(server, playerId, block, saved));
                } catch (IOException failure) {
                    GarryCraftClient.LOG.error("Cannot save detached block", failure);
                    server.execute(() -> reply(block, "cannot save block recovery journal"));
                }
            });
        });
    }

    private static void detach(MinecraftServer server, UUID playerId, BlockSnapshot block, CompoundTag saved) {
        var player = server.getPlayerList().getPlayer(playerId);
        if (player == null) return;
        var level = server.getLevel(block.dimension());
        boolean permitted = current(block.session(), block.generation()) && block.instance().equals(GarryCraftClient.renderInstance())
            && canPick && PhysicsGun.equipped(player) && player.getAbilities().mayBuild && level.mayInteract(player, block.position()) && player.level() == level
            && player.distanceToSqr(block.position().getX() + .5, block.position().getY() + .5, block.position().getZ() + .5) <= 256 * 256
            && !level.isOutsideBuildHeight(block.position()) && level.isLoaded(block.position());
        var entity = permitted ? level.getBlockEntity(block.position()) : null;
        if (!permitted
            || !level.getBlockState(block.position()).equals(block.state())
            || block.state().getDestroySpeed(level, block.position()) < 0
            || block.blockEntity() != null && (entity == null || !block.blockEntity().equals(entity.saveWithFullMetadata(level.registryAccess())))) {
            try { Files.deleteIfExists(block.journal()); } catch (IOException failure) { GarryCraftClient.LOG.error("Cannot clear cancelled block journal", failure); }
            reply(block, "block pickup changed before removal");
            return;
        }
        // Commit on the server thread so another block edit cannot occur between validation and removal.
        // The model and NBT preparation ran on their owning thread and the journal worker.
        saved.putString("phase", "detached");
        try { PhysicsBlockJournal.write(block.journal(), saved); }
        catch (IOException failure) {
            GarryCraftClient.LOG.error("Cannot commit detached block", failure);
            reply(block, "cannot commit block recovery journal");
            return;
        }
        if (!level.setBlock(block.position(), Blocks.AIR.defaultBlockState(), Block.UPDATE_CLIENTS | Block.UPDATE_SKIP_ALL_SIDEEFFECTS)) {
            reply(block, "Minecraft did not remove the block");
            return;
        }
        var blocks = new ArrayList<>(BLOCKS.get()); blocks.add(block); BLOCKS.set(List.copyOf(blocks));
        reply(block, "");
    }

    private static boolean current(String requestSession, long token) { return active && generation == token && session.equals(requestSession); }
    private static void reply(BlockSnapshot block, String error) {
        var replies = new ArrayList<>(SERVER_RESULTS.get());
        replies.add(new ServerResult(block, error));
        // Active bodies retain results. Only recent failed requests need repeated delivery.
        if (replies.size() > 128) replies.removeIf(reply -> !reply.error().isEmpty() && reply.block().id() < block.id() - 16);
        SERVER_RESULTS.set(List.copyOf(replies));
    }
    private static void recover(MinecraftServer server) {
        try {
            var report = PhysicsBlockJournal.restore(server);
            recovered = report.restored(); conflicts = report.conflicts();
            for (var conflict : conflicts) GarryCraftClient.LOG.error("Detached block recovery conflict: {}", conflict);
        } catch (IOException failure) {
            conflicts = List.of("cannot read block recovery journal: " + failure.getMessage());
            GarryCraftClient.LOG.error("Cannot restore detached blocks", failure);
        }
    }
    public static long acknowledged() { return acknowledged; }
    public static List<Result> results() { return results; }
    public static int recovered() { return recovered; }
    public static List<String> conflicts() { return conflicts; }
    public static long generation() { return generation; }

    private static final class JournalWriter {
        private final java.util.concurrent.ExecutorService executor = Executors.newSingleThreadExecutor(Thread.ofPlatform().daemon().name("garrycraft-block-journal").factory());
        void execute(Runnable work) { executor.execute(work); }
        void flush() {
            try { executor.submit(() -> {}).get(); }
            catch (InterruptedException failure) { Thread.currentThread().interrupt(); throw new IllegalStateException("Block journal save interrupted", failure); }
            catch (java.util.concurrent.ExecutionException failure) { throw new IllegalStateException("Block journal save failed", failure); }
        }
    }
    private PhysicsBlocks() {}
}
