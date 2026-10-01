package dev.garrycraft.mixin;

import dev.garrycraft.combat.DamageScaling;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.LivingEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.ModifyVariable;

@Mixin(LivingEntity.class)
public abstract class DamageScalingMixin {
    @ModifyVariable(method = "hurtServer", at = @At("HEAD"), argsOnly = true)
    private float garrycraft$damage(float amount, ServerLevel level, DamageSource source, float original) {
        return DamageScaling.amount((LivingEntity) (Object) this, source, amount);
    }
}
