// Adapted from SkyCraft, Copyright (c) 2026 chasmlol. MIT license.
package dev.garrycraft.combat;

import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.EntityDataSerializers;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.tags.DamageTypeTags;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityDimensions;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.HumanoidArm;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.Pose;
import net.minecraft.world.entity.projectile.Projectile;
import net.minecraft.world.level.Level;
import org.jspecify.annotations.Nullable;

/** Invisible combat target. Source retains its position and health. */
public final class SourceActor extends LivingEntity {
    private static final EntityDataAccessor<Integer> SOURCE_ID = SynchedEntityData.defineId(SourceActor.class, EntityDataSerializers.INT);
    private static final EntityDataAccessor<Float> WIDTH = SynchedEntityData.defineId(SourceActor.class, EntityDataSerializers.FLOAT);
    private static final EntityDataAccessor<Float> HEIGHT = SynchedEntityData.defineId(SourceActor.class, EntityDataSerializers.FLOAT);
    private static final EntityDataAccessor<Boolean> NPC = SynchedEntityData.defineId(SourceActor.class, EntityDataSerializers.BOOLEAN);
    private int generation;
    private float damage, environmentDamage, power;
    private double pushX, pushY, pushZ;
    private boolean projectile, fire, explosion;
    private String attacker = "";

    public SourceActor(EntityType<? extends SourceActor> type, Level level) {
        super(type, level);
        setNoGravity(true);
        noPhysics = true;
        setSilent(true);
    }

    public int sourceId() { return entityData.get(SOURCE_ID); }
    public int generation() { return generation; }
    public boolean hostNpc() { return entityData.get(NPC); }
    public void hostNpc(boolean value) { entityData.set(NPC, value); }
    public void identify(int id, int creation) { entityData.set(SOURCE_ID, id); generation = creation; }

    @Override protected void defineSynchedData(SynchedEntityData.Builder builder) {
        super.defineSynchedData(builder);
        builder.define(SOURCE_ID, 0);
        builder.define(WIDTH, 0.6f);
        builder.define(HEIGHT, 1.8f);
        builder.define(NPC, false);
    }

    public void setSize(float width, float height) {
        entityData.set(WIDTH, width);
        entityData.set(HEIGHT, height);
    }
    @Override public void onSyncedDataUpdated(EntityDataAccessor<?> accessor) {
        super.onSyncedDataUpdated(accessor);
        if (WIDTH.equals(accessor) || HEIGHT.equals(accessor)) refreshDimensions();
    }
    @Override protected EntityDimensions getDefaultDimensions(Pose pose) {
        return EntityDimensions.scalable(entityData.get(WIDTH), entityData.get(HEIGHT));
    }
    @Override protected void actuallyHurt(ServerLevel level, DamageSource source, float amount) {
        if (isInvulnerableTo(level, source) || amount <= 0) return;
        if (source.getEntity() == null) environmentDamage += amount;
        else damage += amount;
        projectile |= source.getDirectEntity() instanceof Projectile;
        fire |= source.is(DamageTypeTags.IS_FIRE);
        if (source.getEntity() instanceof net.minecraft.world.entity.Mob mob) attacker = mob.getStringUUID();
        getCombatTracker().recordDamage(source, amount);
    }
    @Override public void knockback(double strength, double x, double z, DamageSource source, float amount, boolean effect) {
        double length = Math.sqrt(x * x + z * z);
        if (length > 1e-6 && strength > power) {
            power = (float) strength;
            pushX = -x / length;
            pushZ = -z / length;
        }
    }
    @Override public void pushFromExplosion(net.minecraft.world.phys.Vec3 impulse) {
        pushX = impulse.x; pushY = impulse.y; pushZ = impulse.z;
        power = 1; explosion = true;
    }
    SourceCombat.Hit drain(long sequence) {
        if (damage == 0 && environmentDamage == 0 && power == 0) return null;
        var hit = new SourceCombat.Hit(sequence, sourceId(), generation, damage, environmentDamage, pushX, pushY, pushZ, power, projectile, fire, explosion, attacker);
        damage = environmentDamage = power = 0;
        pushX = pushY = pushZ = 0;
        projectile = fire = explosion = false;
        attacker = "";
        return hit;
    }
    @Override public void tick() { baseTick(); applyEffectsFromBlocks(); setHealth(getMaxHealth()); }
    // Source owns movement, but fire, lava, and other vanilla block effects still apply to this target.
    @Override protected boolean isAffectedByBlocks() { return !isRemoved(); }
    @Override public boolean isPushable() { return false; }
    @Override protected void doPush(Entity entity) {}
    @Override public boolean canBeCollidedWith(@Nullable Entity other) { return false; }
    @Override public boolean shouldShowName() { return false; }
    @Override public boolean shouldBeSaved() { return false; }
    @Override public HumanoidArm getMainArm() { return HumanoidArm.RIGHT; }
}
