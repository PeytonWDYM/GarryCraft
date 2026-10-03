package dev.garrycraft.mixin;

import dev.garrycraft.physicsblocks.DetachedBlockView;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.stats.Stat;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(ServerPlayer.class)
abstract class DetachedBlockStatMixin {
    @Inject(method = "awardStat(Lnet/minecraft/stats/Stat;I)V", at = @At("HEAD"), cancellable = true)
    private void garrycraft$detachedStat(Stat<?> stat, int amount, CallbackInfo callback) {
        var player = (ServerPlayer) (Object) this;
        var view = DetachedBlockView.active(player);
        if (view != null) { view.playerEffect(() -> player.awardStat(stat, amount)); callback.cancel(); }
    }
}
