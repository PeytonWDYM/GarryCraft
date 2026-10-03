package dev.garrycraft.physicsblocks;

import java.io.DataOutputStream;
import java.io.IOException;
import java.nio.channels.Channels;
import java.nio.channels.FileChannel;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.nio.file.StandardOpenOption;
import java.util.ArrayList;
import java.util.List;
import net.minecraft.core.BlockPos;
import net.minecraft.core.registries.Registries;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.nbt.NbtIo;
import net.minecraft.nbt.NbtUtils;
import net.minecraft.resources.Identifier;
import net.minecraft.resources.ResourceKey;
import net.minecraft.server.MinecraftServer;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.storage.LevelResource;

/** A forced journal file must exist before the server removes a block. */
final class PhysicsBlockJournal {
    record Recovery(int restored, List<String> conflicts) {}
    static Path directory(MinecraftServer server) {
        return server.getWorldPath(LevelResource.DATA).resolve("garrycraft-physics-blocks");
    }
    static void write(Path target, CompoundTag block) throws IOException {
        Files.createDirectories(target.getParent());
        Path pending = target.resolveSibling(target.getFileName() + ".pending");
        try (var channel = FileChannel.open(pending, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING, StandardOpenOption.WRITE)) {
            var output = new DataOutputStream(Channels.newOutputStream(channel));
            NbtIo.write(block, output);
            output.flush();
            channel.force(true);
        }
        Files.move(pending, target, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);
    }
    static Recovery restore(MinecraftServer server) throws IOException {
        var directory = directory(server);
        if (!Files.isDirectory(directory)) return new Recovery(0, List.of());
        var complete = new ArrayList<Path>();
        var conflicts = new ArrayList<String>();
        try (var files = Files.list(directory)) {
            for (var file : files.filter(path -> path.getFileName().toString().endsWith(".nbt")).toList()) {
                var saved = NbtIo.read(file);
                String phase = saved.getString("phase").orElseThrow();
                if (phase.equals("prepared")) { Files.delete(file); continue; }
                if (phase.equals("delivered")) { Files.delete(file); continue; }
                if (!phase.equals("detached") && !phase.equals("restoring") && !phase.equals("broken"))
                    throw new IOException("Unknown block recovery phase: " + phase);
                var dimension = ResourceKey.create(Registries.DIMENSION, Identifier.parse(saved.getString("dimension").orElseThrow()));
                var level = server.getLevel(dimension);
                var position = new BlockPos(saved.getInt("x").orElseThrow(), saved.getInt("y").orElseThrow(), saved.getInt("z").orElseThrow());
                if (level == null) { conflicts.add(dimension.identifier() + " " + position + ": missing dimension"); continue; }
                if (phase.equals("broken")) { DetachedBlockLoot.recover(server, level, file, saved); continue; }
                var state = NbtUtils.readBlockState(server.registryAccess().lookupOrThrow(Registries.BLOCK), saved.getCompound("state").orElseThrow());
                var current = level.getBlockState(position);
                var entityTag = saved.getCompound("blockEntity");
                if (current.isAir()) {
                    // The persisted restore intent proves that this task owned an empty cell.
                    saved.putString("phase", "restoring");
                    write(file, saved);
                    if (!level.setBlock(position, state, Block.UPDATE_CLIENTS | Block.UPDATE_SKIP_ALL_SIDEEFFECTS))
                        throw new IOException("Minecraft did not restore the block at " + position);
                    if (entityTag.isPresent()) {
                        var entity = BlockEntity.loadStatic(position, state, entityTag.get(), level.registryAccess());
                        if (entity == null) throw new IOException("Cannot restore block entity at " + position);
                        level.setBlockEntity(entity);
                        entity.setChanged();
                    }
                } else if (!phase.equals("restoring") || !current.equals(state) || entityTag.isPresent() && (level.getBlockEntity(position) == null
                    || !entityTag.get().equals(level.getBlockEntity(position).saveWithFullMetadata(level.registryAccess())))) {
                    conflicts.add(dimension.identifier() + " " + position + ": original cell is occupied");
                    continue;
                }
                complete.add(file);
            }
        }
        if (!complete.isEmpty()) {
            // Keep the journal until restored chunks reach disk. A crash can then repeat recovery safely.
            for (var level : server.getAllLevels()) level.getChunkSource().save(true);
            for (var file : complete) Files.delete(file);
        }
        return new Recovery(complete.size(), List.copyOf(conflicts));
    }
    private PhysicsBlockJournal() {}
}
