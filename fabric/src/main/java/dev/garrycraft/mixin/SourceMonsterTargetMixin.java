package dev.garrycraft.mixin;

import dev.garrycraft.combat.SourceActor;
import net.minecraft.world.entity.Mob;
import net.minecraft.world.entity.monster.Monster;
import net.minecraft.world.entity.ai.goal.GoalSelector;
import net.minecraft.world.entity.ai.goal.target.NearestAttackableTargetGoal;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.Final;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(Mob.class)
public abstract class SourceMonsterTargetMixin {
    @Shadow @Final protected GoalSelector targetSelector;
    @Inject(method = "<init>", at = @At("TAIL"))
    private void garrycraft$hostTargets(CallbackInfo callback) {
        var mob = (Mob) (Object) this;
        if (mob instanceof Monster) targetSelector.addGoal(3,
            new NearestAttackableTargetGoal<>(mob, SourceActor.class, true, (entity, level) -> ((SourceActor) entity).hostNpc()));
    }
}
