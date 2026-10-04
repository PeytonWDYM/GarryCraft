// Adapted from SkyCraft, Copyright (c) 2026 chasmlol. MIT license.
package dev.garrycraft.render;

import it.unimi.dsi.fastutil.longs.LongLinkedOpenHashSet;
import it.unimi.dsi.fastutil.longs.LongOpenHashSet;
import java.util.List;
import net.minecraft.client.Minecraft;
import net.minecraft.core.BlockPos;
import net.minecraft.core.SectionPos;
import net.minecraft.world.level.chunk.status.ChunkStatus;

/** Sends one section until both Source realms acknowledge its model and collision snapshot. */
public final class WorldExporter {
    record Section(String session, String instance, long sequence, String key, boolean clear,
        List<ModelCollector.Batch> meshes, List<double[]> boxes) {}
    private static final LongLinkedOpenHashSet DIRTY = new LongLinkedOpenHashSet();
    private static final LongOpenHashSet SENT = new LongOpenHashSet();
    private static final LongOpenHashSet URGENT = new LongOpenHashSet();
    private static final LongOpenHashSet DEFERRED = new LongOpenHashSet();
    private static Section pending;
    private static SectionBuilder building;
    private static long sequence, scanTick = -1;
    private static int scanColumn = 49, scanSection, scanX, scanZ;
    private static long pendingKey;
    private static final java.util.LinkedHashMap<Long, DetachSection> detached = new java.util.LinkedHashMap<>();
    private static final LongLinkedOpenHashSet committed = new LongLinkedOpenHashSet();
    private static final it.unimi.dsi.fastutil.longs.Long2LongOpenHashMap detachSequences = new it.unimi.dsi.fastutil.longs.Long2LongOpenHashMap();
    private static long pendingDetach, clearSequence;
    private static final java.util.Map<Long, java.util.List<DetachSection>> handoffs = new java.util.HashMap<>();
    private static boolean clear;
    private WorldExporter() {}
    public static void reset() {
        synchronized (DIRTY) { DIRTY.clear(); URGENT.clear(); }
        SENT.clear(); DEFERRED.clear(); pending = null; building = null; sequence = 0; scanTick = -1; scanColumn = 49; clear = true;
        detached.clear(); committed.clear(); detachSequences.clear(); pendingDetach = 0; clearSequence = 0;
        handoffs.clear();
    }
    public static final class DetachSection {
        private final SectionBuilder builder;
        private final BlockPos position;
        private boolean clientChanged;
        private Section snapshot;
        private DetachSection(Minecraft mc, BlockPos position) {
            this.position = position;
            var omitted = new java.util.HashSet<BlockPos>(); omitted.add(position);
            for (var list : handoffs.values()) for (var handoff : list) if (!handoff.clientChanged) omitted.add(handoff.position);
            builder = new SectionBuilder(mc, SectionPos.asLong(position), new DetachedSectionView(mc.level, position, omitted));
        }
        public boolean step() {
            if (!builder.step()) return false;
            snapshot = builder.finish("", "", 0);
            return true;
        }
    }
    public static DetachSection prepareDetach(Minecraft mc, long id, BlockPos position) {
        var section = new DetachSection(mc, position);
        detached.put(id, section);
        return section;
    }
    public static long commitDetach(long id) {
        long sent = detachSequences.get(id);
        if (sent == 0 && committed.add(id)) {
            var section = detached.get(id);
            handoffs.computeIfAbsent(section.builder.key, ignored -> new java.util.ArrayList<>()).add(section);
            if (building != null && building.key == section.builder.key) building = null;
        }
        return sent;
    }
    public static void cancelDetach(long id) { detached.remove(id); committed.remove(id); }
    public static void clearDetaches() {
        if (pendingDetach > 0) {
            dirty(SectionPos.x(pendingKey), SectionPos.y(pendingKey), SectionPos.z(pendingKey));
            pending = null;
            RenderTransport.world(null);
        }
        pendingDetach = 0;
        detached.clear(); committed.clear(); detachSequences.clear(); handoffs.clear();
    }
    public static long clearSequence() { return clearSequence; }
    public static void dirty(int x, int y, int z) {
        synchronized (DIRTY) {
            long key = SectionPos.asLong(x, y, z);
            DIRTY.add(key);
        }
    }
    public static void urgent(BlockPos position) {
        long key = SectionPos.asLong(position);
        synchronized (DIRTY) {
            for (var section : detached.values()) if (section.position.equals(position)) section.clientChanged = true;
            var pending = handoffs.get(key);
            if (pending != null) for (var section : pending) if (section.position.equals(position)) section.clientChanged = true;
            // Face culling and fluid surfaces depend on cells across section boundaries.
            for (int x = (position.getX() - 1) >> 4; x <= (position.getX() + 1) >> 4; x++)
                for (int y = (position.getY() - 1) >> 4; y <= (position.getY() + 1) >> 4; y++)
                    for (int z = (position.getZ() - 1) >> 4; z <= (position.getZ() + 1) >> 4; z++) {
                        long neighbor = SectionPos.asLong(x, y, z);
                        DIRTY.addAndMoveToFirst(neighbor); URGENT.add(neighbor);
                    }
        }
    }
    public static void frame(Minecraft mc, String session, String instance, long ack) {
        synchronized (DIRTY) {
            // An edit can arrive after this section's builder passed the changed cell.
            if (building != null && URGENT.contains(building.key)) building = null;
            if (pending != null && !pending.clear() && pendingDetach == 0 && URGENT.contains(pendingKey)) {
                pending = null;
                RenderTransport.world(null);
            }
        }
        if (pending != null) {
            if (pendingDetach > 0) {
                if (ack < pending.sequence()) return;
                detached.remove(pendingDetach);
                committed.remove(pendingDetach);
                pendingDetach = 0;
            }
            if (ack < pending.sequence()) {
                synchronized (DIRTY) {
                    if (pending.clear() || committed.isEmpty() && (URGENT.isEmpty() || (URGENT.size() == 1 && URGENT.contains(pendingKey)))) return;
                    DIRTY.add(pendingKey);
                }
            }
            pending = null;
            RenderTransport.world(null);
        }
        if (clear) {
            clear = false;
            pending = new Section(session, instance, ++sequence, "", true, List.of(), List.of());
            clearSequence = pending.sequence();
            RenderTransport.world(pending);
            return;
        }
        if (!committed.isEmpty()) {
            long id = committed.firstLong();
            var snapshot = detached.get(id).snapshot;
            pending = new Section(session, instance, ++sequence, snapshot.key(), false,
                snapshot.meshes(), snapshot.boxes());
            pendingKey = detached.get(id).builder.key;
            pendingDetach = id;
            detachSequences.put(id, pending.sequence());
            SENT.add(pendingKey);
            RenderTransport.world(pending);
            // A normal revision may already contain fluid flow or a replacement block. Send it after this handoff.
            dirty(SectionPos.x(pendingKey), SectionPos.y(pendingKey), SectionPos.z(pendingKey));
            return;
        }
        if (building != null) {
            if (building.step()) {
                pending = building.finish(session, instance, ++sequence);
                pendingKey = building.key;
                SENT.add(pendingKey);
                building = null;
                RenderTransport.world(pending);
            }
            return;
        }
        scan(mc);
        // Ignore empty dirty sections without spending the frame budget on their geometry.
        for (int attempts = 0; attempts < 64; attempts++) {
            long key;
            synchronized (DIRTY) {
                if (DIRTY.isEmpty()) return;
                key = DIRTY.removeFirstLong(); URGENT.remove(key);
            }
            var section = build(mc, key);
            if (section == null) continue;
            building = section;
            return;
        }
    }
    /** Spread the mirror world's 6,272 section checks across frames instead of one periodic stall. */
    private static void scan(Minecraft mc) {
        long tick = mc.level.getGameTime();
        if (scanColumn == 49) {
            if (scanTick >= 0 && tick - scanTick < 20) return;
            scanTick = tick;
            scanX = mc.player.getBlockX() >> 4; scanZ = mc.player.getBlockZ() >> 4;
            scanColumn = scanSection = 0;
        }
        long deadline = System.nanoTime() + 250_000L;
        while (scanColumn < 49) {
            int x = scanX - 3 + scanColumn / 7, z = scanZ - 3 + scanColumn % 7;
            var chunk = mc.level.getChunkSource().getChunk(x, z, ChunkStatus.FULL, false);
            if (chunk == null || scanSection == chunk.getSections().length) { scanColumn++; scanSection = 0; continue; }
            int index = scanSection++;
            long key = SectionPos.asLong(x, chunk.getSectionYFromSectionIndex(index), z);
            // An off-range edit can remove the last block. Its clear snapshot must still reach Source.
            if (DEFERRED.remove(key) || (!SENT.contains(key)
                    && !chunk.getSections()[index].hasOnlyAir()))
                dirty(x, SectionPos.y(key), z);
            if (System.nanoTime() >= deadline) return;
        }
    }
    private static SectionBuilder build(Minecraft mc, long key) {
        int sx = SectionPos.x(key), sy = SectionPos.y(key), sz = SectionPos.z(key);
        var pendingHandoffs = handoffs.get(key);
        if (pendingHandoffs != null) {
            if (pendingHandoffs.stream().anyMatch(section -> !section.clientChanged)) { DEFERRED.add(key); return null; }
            handoffs.remove(key);
        }
        if (Math.abs(sx - (mc.player.getBlockX() >> 4)) > 3 || Math.abs(sz - (mc.player.getBlockZ() >> 4)) > 3) {
            if (SENT.contains(key)) DEFERRED.add(key);
            return null;
        }
        var level = mc.level;
        var chunk = level.getChunkSource().getChunk(sx, sz, ChunkStatus.FULL, false);
        if (chunk == null) {
            if (SENT.contains(key)) DEFERRED.add(key);
            return null;
        }
        int index = level.getSectionIndexFromSectionY(sy);
        if (index < 0 || index >= chunk.getSections().length) return null;
        if (chunk.getSections()[index].hasOnlyAir() && !SENT.contains(key)) return null;
        return new SectionBuilder(mc, key);
    }
}
