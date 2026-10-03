package dev.garrycraft.mixin;

import dev.garrycraft.physicsblocks.DetachedBlockView;
import net.minecraft.world.entity.player.Player;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(Player.class)
abstract class DetachedBlockExhaustionMixin {
    @Inject(method = "causeFoodExhaustion", at = @At("HEAD"), cancellable = true)
    private void garrycraft$detachedExhaustion(float amount, CallbackInfo callback) {
        var player = (Player) (Object) this;
        var view = DetachedBlockView.active(player);
        if (view != null) { view.playerEffect(() -> player.causeFoodExhaustion(amount)); callback.cancel(); }
    }
}
