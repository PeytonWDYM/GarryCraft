package dev.garrycraft.bridge;

import net.minecraft.core.Holder;
import net.minecraft.network.chat.Component;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.damagesource.DamageType;
import net.minecraft.world.entity.LivingEntity;

/** Uses Minecraft's localized death messages with the Source attacker's displayed name. */
public final class SourceDamage extends DamageSource {
    private final String attacker;
    private final String kind;
    public SourceDamage(Holder<DamageType> type, String attacker, String kind) {
        super(type);
        this.attacker = attacker;
        this.kind = kind;
    }
    @Override public Component getLocalizedDeathMessage(LivingEntity victim) {
        if (attacker.isEmpty()) return super.getLocalizedDeathMessage(victim);
        String message = switch (kind) {
            case "bullet" -> "death.attack.arrow";
            case "blast" -> "death.attack.explosion.player";
            default -> "death.attack.mob";
        };
        return Component.translatable(message, victim.getDisplayName(), Component.literal(attacker));
    }
}
