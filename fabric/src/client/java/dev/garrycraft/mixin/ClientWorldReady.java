package dev.garrycraft.mixin;

import net.minecraft.client.multiplayer.ClientPacketListener;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.gen.Invoker;

/** Completes Minecraft's normal loaded-player handshake after the Source mesh is ready. */
@Mixin(ClientPacketListener.class)
public interface ClientWorldReady {
    @Invoker("notifyPlayerLoaded") void garrycraft$worldReady();
}
