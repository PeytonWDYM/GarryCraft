package dev.garrycraft.mixin;

import dev.garrycraft.render.WorldExporter;
import net.minecraft.client.multiplayer.ClientLevel;
import net.minecraft.world.level.ChunkPos;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

/** Full chunk and biome packets update geometry without waiting for Minecraft light propagation. */
@Mixin(ClientLevel.class)
public abstract class ChunkGeometryMixin {
    @Inject(method = "onChunkLoaded", at = @At("RETURN"))
    private void garrycraft$chunk(ChunkPos position, CallbackInfo callback) {
        var level = (ClientLevel) (Object) this;
        for (int x = position.x() - 1; x <= position.x() + 1; x++)
            for (int z = position.z() - 1; z <= position.z() + 1; z++)
                for (int y = level.getMinSectionY(); y <= level.getMaxSectionY(); y++) WorldExporter.dirty(x, y, z);
    }
}
