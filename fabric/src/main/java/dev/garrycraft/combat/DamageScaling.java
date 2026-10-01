package dev.garrycraft.combat;

import dev.garrycraft.bridge.SourceDamage;
import dev.garrycraft.physics.SourceWorld;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.Mob;
import net.minecraft.world.entity.player.Player;

/** Scales incoming damage before vanilla armor, shields, and invulnerability rules run. */
public final class DamageScaling {
    public record Settings(float mobToPlayer, float playerToMob, float mobToMob, float environment) {}
    public static final Settings DEFAULTS = new Settings(1, 1, 1, 1);
    private static volatile Settings settings = DEFAULTS;
    private DamageScaling() {}
    public static void update(Settings value) { settings = value; }
    public static Settings settings() { return settings; }
    public static float amount(LivingEntity victim, DamageSource source, float amount) {
        if (!SourceWorld.active || source instanceof SourceDamage || source.getEntity() instanceof SourceActor
                || !(victim instanceof Player || victim instanceof Mob)) return amount;
        var attacker = source.getEntity();
        var current = settings;
        float scale = attacker instanceof Mob ? (victim instanceof Player ? current.mobToPlayer() : current.mobToMob())
            : attacker instanceof Player && victim instanceof Mob ? current.playerToMob() : current.environment();
        return amount * scale;
    }
}
