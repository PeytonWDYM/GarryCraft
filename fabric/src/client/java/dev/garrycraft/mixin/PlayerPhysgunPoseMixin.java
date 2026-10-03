package dev.garrycraft.mixin;

import dev.garrycraft.GarryCraftClient;
import dev.garrycraft.item.PhysicsGun;
import net.minecraft.client.Minecraft;
import net.minecraft.client.model.player.PlayerModel;
import net.minecraft.client.renderer.entity.state.AvatarRenderState;
import net.minecraft.world.entity.HumanoidArm;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

/** Set the pose after vanilla animation so the skin, sleeves, armor, and held item share the same grip. */
@Mixin(PlayerModel.class)
public abstract class PlayerPhysgunPoseMixin {
    @Inject(method = "setupAnim(Lnet/minecraft/client/renderer/entity/state/AvatarRenderState;)V", at = @At("RETURN"))
    private void garrycraft$physgunPose(AvatarRenderState state, CallbackInfo callback) {
        var player = Minecraft.getInstance().player;
        if (!GarryCraftClient.linked() || player == null || state.id != player.getId() || !PhysicsGun.equipped(player)) return;
        var model = (PlayerModel) (Object) this;
        boolean right = player.getMainArm() == HumanoidArm.RIGHT;
        var grip = right ? model.rightArm : model.leftArm;
        var support = right ? model.leftArm : model.rightArm;
        grip.xRot = model.head.xRot - 1.35f;
        grip.yRot = model.head.yRot + (right ? -.12f : .12f);
        support.xRot = model.head.xRot - 1.25f;
        support.yRot = model.head.yRot + (right ? .65f : -.65f);
    }
}
