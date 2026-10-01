// Adapted from SkyCraft, Copyright (c) 2026 chasmlol. MIT license.
package dev.garrycraft.render;

import it.unimi.dsi.fastutil.longs.LongLinkedOpenHashSet;
import it.unimi.dsi.fastutil.longs.LongOpenHashSet;
import java.util.List;
import net.minecraft.client.Minecraft;
import net.minecraft.core.BlockPos;
import net.minecraft.core.SectionPos;
import net.minecraft.world.level.chunk.status.ChunkStatus;

/** Sends one section until both Source realms acknowledge its model, light, and collision snapshot. */
public final class WorldExporter {
    record Light(float x, float y, float z, int emission, int color) {}
    record Section(String session, String instance, long sequence, String key, boolean clear,
        List<ModelCollector.Batch> meshes, List<double[]> boxes, List<Light> lights) {}
    private static final LongLinkedOpenHashSet DIRTY = new LongLinkedOpenHashSet();
    private static final LongOpenHashSet SENT = new LongOpenHashSet();
    private static final LongOpenHashSet URGENT = new LongOpenHashSet();
    private static Section pending;
    private static SectionBuilder building;
    private static long sequence, scanTick = -1;
    private static long pendingKey;
    private static boolean clear;
    private WorldExporter() {}
    public static void reset() {
        synchronized (DIRTY) { DIRTY.clear(); }
        SENT.clear(); URGENT.clear(); pending = null; building = null; sequence = 0; scanTick = -1; clear = true;
    }
    public static void dirty(int x, int y, int z) { synchronized (DIRTY) { DIRTY.add(SectionPos.asLong(x, y, z)); } }
    public static void urgent(BlockPos position) {
        long key = SectionPos.asLong(position);
        synchronized (DIRTY) { DIRTY.addAndMoveToFirst(key); URGENT.add(key); }
    }
    public static void frame(Minecraft mc, String session, String instance, long ack) {
        if (pending != null) {
            if (ack < pending.sequence()) {
                synchronized (DIRTY) {
                    if (pending.clear() || URGENT.isEmpty() || (URGENT.size() == 1 && URGENT.contains(pendingKey))) return;
                    DIRTY.add(pendingKey);
                }
            }
            pending = null;
            RenderTransport.world(null);
        }
        if (clear) {
            clear = false;
            pending = new Section(session, instance, ++sequence, "", true, List.of(), List.of(), List.of());
            RenderTransport.world(pending);
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
        long tick = mc.level.getGameTime();
        if (scanTick < 0 || tick - scanTick >= 20) {
            scanTick = tick;
            int cx = SectionPos.blockToSectionCoord(mc.player.getBlockX()), cz = SectionPos.blockToSectionCoord(mc.player.getBlockZ());
            for (int x = cx - 3; x <= cx + 3; x++) for (int z = cz - 3; z <= cz + 3; z++) {
                var chunk = mc.level.getChunkSource().getChunk(x, z, ChunkStatus.FULL, false);
                if (chunk == null) continue;
                for (int i = 0; i < chunk.getSections().length; i++) {
                    long key = SectionPos.asLong(x, chunk.getSectionYFromSectionIndex(i), z);
                    if (!chunk.getSections()[i].hasOnlyAir() && !SENT.contains(key)) dirty(x, SectionPos.y(key), z);
                }
            }
        }
        // Ignore empty dirty sections without spending the frame budget on their geometry.
        for (int attempts = 0; attempts < 64; attempts++) {
            long key;
            synchronized (DIRTY) { if (DIRTY.isEmpty()) return; key = DIRTY.removeFirstLong(); URGENT.remove(key); }
            var section = build(mc, key);
            if (section == null) continue;
            building = section;
            return;
        }
    }
    private static SectionBuilder build(Minecraft mc, long key) {
        int sx = SectionPos.x(key), sy = SectionPos.y(key), sz = SectionPos.z(key);
        if (Math.abs(sx - (mc.player.getBlockX() >> 4)) > 3 || Math.abs(sz - (mc.player.getBlockZ() >> 4)) > 3) return null;
        var level = mc.level;
        var chunk = level.getChunkSource().getChunk(sx, sz, ChunkStatus.FULL, false);
        if (chunk == null) return null;
        int index = level.getSectionIndexFromSectionY(sy);
        if (index < 0 || index >= chunk.getSections().length) return null;
        if (chunk.getSections()[index].hasOnlyAir() && !SENT.contains(key)) return null;
        return new SectionBuilder(mc, key);
    }
}
