package dev.garrycraft.physicsblocks;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.nbt.ListTag;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.util.ProblemReporter;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityProcessor;
import net.minecraft.world.entity.EntitySpawnReason;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.level.storage.TagValueInput;
import net.minecraft.world.level.storage.TagValueOutput;

/** Replace recovery of a block with recovery of its exact vanilla loot before any entity becomes visible. */
final class DetachedBlockLoot {
    static boolean committed(Path journal) {
        try {
            var phase = net.minecraft.nbt.NbtIo.read(journal).getString("phase").orElse("");
            return phase.equals("broken") || phase.equals("delivered");
        }
        catch (IOException failure) { throw new IllegalStateException("Cannot read detached block mining commit", failure); }
    }
    static void commit(MinecraftServer server, ServerLevel level, PhysicsBlocks.BlockSnapshot block, List<Entity> entities, List<Runnable> playerEffects) throws IOException {
        var saved = net.minecraft.nbt.NbtIo.read(block.journal());
        saved.putString("phase", "broken");
        var loot = new ListTag();
        for (var entity : entities) {
            var output = TagValueOutput.createWithContext(ProblemReporter.DISCARDING, level.registryAccess());
            if (!entity.save(output)) throw new IOException("Cannot save detached block loot " + entity.getUUID());
            loot.add(output.buildResult());
        }
        saved.put("loot", loot);
        PhysicsBlockJournal.write(block.journal(), saved);
        // Statistics and exhaustion become part of the break only after the consumed journal is durable.
        for (var effect : playerEffects) effect.run();
        try {
            for (var entity : entities) if (!level.addFreshEntity(entity))
                throw new IOException("Cannot spawn detached block loot " + entity.getUUID());
            // Vanilla saves player/tool and loot state here. It can stall the Minecraft server.
            // PlayerDataStorage logs player-write failures instead of propagating them through this API.
            server.saveEverything(true, true, true);
            saved.putString("phase", "delivered");
            PhysicsBlockJournal.write(block.journal(), saved);
        } catch (IOException failure) {
            // The server task has not returned, so the new entities have not become collectible.
            for (var entity : entities) entity.discard();
            throw failure;
        }
        try { Files.delete(block.journal()); }
        catch (IOException failure) { dev.garrycraft.GarryCraftClient.LOG.error("Cannot clear delivered detached block journal", failure); }
    }

    static void recover(MinecraftServer server, ServerLevel level, Path journal, CompoundTag saved) throws IOException {
        var recovered = new java.util.ArrayList<Entity>();
        try {
            for (var tag : saved.getListOrEmpty("loot").compoundStream().toList()) {
                var input = TagValueInput.create(ProblemReporter.DISCARDING, level.registryAccess(), tag);
                var entity = EntityType.loadEntityRecursive(input, level, EntitySpawnReason.LOAD, EntityProcessor.NOP);
                if (entity == null) throw new IOException("Cannot read committed detached block loot");
                var cell = entity.blockPosition();
                level.getChunk(cell);
                level.waitForEntities(level.getChunkAt(cell).getPos(), 0);
                var existing = level.getEntityInAnyDimension(entity.getUUID());
                if (existing != null) recovered.add(existing);
                else {
                    if (!level.addFreshEntity(entity)) throw new IOException("Cannot recover detached block loot " + entity.getUUID());
                    recovered.add(entity);
                }
            }
            server.saveEverything(true, true, true);
            saved.putString("phase", "delivered");
            PhysicsBlockJournal.write(journal, saved);
        } catch (IOException failure) {
            for (var entity : recovered) entity.discard();
            throw failure;
        }
        Files.delete(journal);
    }
    private DetachedBlockLoot() {}
}
