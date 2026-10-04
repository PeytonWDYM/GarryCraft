package dev.garrycraft.mixin;

import dev.garrycraft.render.WorldExporter;
import net.minecraft.client.renderer.extract.LevelExtractor;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(LevelExtractor.class)
public abstract class WorldChangesMixin {
    @Inject(method = "setBlocksDirty(IIIIII)V", at = @At("HEAD"))
    private void garrycraft$blocks(int minX, int minY, int minZ, int maxX, int maxY, int maxZ, CallbackInfo callback) {
        for (int x = (minX - 1) >> 4; x <= (maxX + 1) >> 4; x++)
            for (int y = (minY - 1) >> 4; y <= (maxY + 1) >> 4; y++)
                for (int z = (minZ - 1) >> 4; z <= (maxZ + 1) >> 4; z++) WorldExporter.dirty(x, y, z);
    }
    @Inject(method = "setBlockDirty(Lnet/minecraft/core/BlockPos;Z)V", at = @At("HEAD"))
    private void garrycraft$block(net.minecraft.core.BlockPos pos, boolean neighbors, CallbackInfo callback) { WorldExporter.urgent(pos); }
    @Inject(method = "setBlockDirty(Lnet/minecraft/core/BlockPos;Lnet/minecraft/world/level/block/state/BlockState;Lnet/minecraft/world/level/block/state/BlockState;)V", at = @At("HEAD"))
    private void garrycraft$changedBlock(net.minecraft.core.BlockPos pos, net.minecraft.world.level.block.state.BlockState oldState,
        net.minecraft.world.level.block.state.BlockState newState, CallbackInfo callback) { WorldExporter.urgent(pos); }
}
