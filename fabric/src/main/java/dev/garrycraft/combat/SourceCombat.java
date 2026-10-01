// Adapted from SkyCraft, Copyright (c) 2026 chasmlol. MIT license.
package dev.garrycraft.combat;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.fabricmc.fabric.api.object.builder.v1.entity.FabricDefaultAttributeRegistry;
import net.minecraft.core.Registry;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.core.registries.Registries;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.Identifier;
import net.minecraft.resources.ResourceKey;
import net.minecraft.server.MinecraftServer;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.InsideBlockEffectApplier;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.MobCategory;
import net.minecraft.world.level.block.BasePressurePlateBlock;
import net.minecraft.world.level.block.TripWireBlock;
import net.minecraft.core.BlockPos;

/** Minecraft weapons hit stand-ins through vanilla combat. Acknowledged events apply those hits in Source. */
public final class SourceCombat {
    public record Actor(int id, int generation, String name, double x, double y, double z, float yaw, float width, float height, boolean npc) {}
    public record Hit(long id, int entity, int generation, float damage, float environmentDamage, double pushX, double pushY, double pushZ,
                      float power, boolean projectile, boolean fire, boolean explosion, String attacker) {}
    private record Snapshot(String session, boolean active, long ack, List<Actor> actors) {}
    private static final ResourceKey<EntityType<?>> KEY = ResourceKey.create(Registries.ENTITY_TYPE,
        Identifier.fromNamespaceAndPath("garrycraft", "source_actor"));
    public static final EntityType<SourceActor> TYPE = Registry.register(BuiltInRegistries.ENTITY_TYPE, KEY,
        EntityType.Builder.<SourceActor>of(SourceActor::new, MobCategory.MISC).sized(0.6f, 1.8f)
            .noSave().noSummon().noLootTable().clientTrackingRange(16).updateInterval(1).build(KEY));
    private static volatile Snapshot snapshot = new Snapshot("", false, 0, List.of());
    private static volatile List<Hit> outgoing = List.of();
    private static final Map<Integer, SourceActor> PROXIES = new HashMap<>();
    private static final List<Hit> PENDING = new ArrayList<>();
    private static String session = "";
    private static long sequence;
    private SourceCombat() {}

    public static void init() {
        FabricDefaultAttributeRegistry.register(TYPE, LivingEntity.createLivingAttributes());
        ServerTickEvents.END_SERVER_TICK.register(SourceCombat::tick);
    }
    public static void update(String nextSession, boolean active, long ack, List<Actor> actors) {
        snapshot = new Snapshot(nextSession, active, ack, actors);
    }
    public static List<Hit> hits() { return outgoing; }
    public static List<Actor> actors() { return snapshot.actors(); }
    public static SourceActor proxy(int id, int generation) {
        var actor = PROXIES.get(id);
        return actor != null && actor.generation() == generation ? actor : null;
    }

    private static void clear() {
        PROXIES.values().forEach(Entity::discard);
        PROXIES.clear();
        PENDING.clear();
        outgoing = List.of();
    }
    private static void tick(MinecraftServer server) {
        var current = snapshot;
        if (!session.equals(current.session())) { clear(); session = current.session(); sequence = 0; }
        var players = server.getPlayerList().getPlayers();
        if (!current.active() || players.isEmpty()) { clear(); return; }
        var level = players.getFirst().level();
        PENDING.removeIf(hit -> hit.id() <= current.ack());
        var live = new HashMap<Integer, Actor>();
        for (var actor : current.actors()) live.put(actor.id(), actor);
        PROXIES.entrySet().removeIf(entry -> {
            var actor = live.get(entry.getKey());
            if (actor == null || entry.getValue().isRemoved() || entry.getValue().level() != level
                    || entry.getValue().generation() != actor.generation()) {
                entry.getValue().discard();
                return true;
            }
            return false;
        });
        for (var actor : live.values()) {
            var proxy = PROXIES.get(actor.id());
            if (proxy == null) {
                proxy = new SourceActor(TYPE, level);
                proxy.identify(actor.id(), actor.generation());
                proxy.setCustomName(Component.literal(actor.name()));
                proxy.setSize(actor.width(), actor.height());
                proxy.snapTo(actor.x(), actor.y(), actor.z(), actor.yaw(), 0);
                level.addFreshEntity(proxy);
                PROXIES.put(actor.id(), proxy);
            } else {
                var hit = proxy.drain(sequence + 1);
                if (hit != null) { sequence++; PENDING.add(hit); }
                proxy.setSize(actor.width(), actor.height());
                proxy.setPos(actor.x(), actor.y(), actor.z());
                proxy.setYRot(actor.yaw());
            }
            var box = proxy.getBoundingBox().deflate(1e-5);
            proxy.hostNpc(actor.npc());
            for (var pos : BlockPos.betweenClosed(BlockPos.containing(box.minX, box.minY, box.minZ),
                    BlockPos.containing(box.maxX, box.maxY, box.maxZ))) {
                var state = level.getBlockState(pos);
                if (state.getBlock() instanceof BasePressurePlateBlock || state.getBlock() instanceof TripWireBlock)
                    state.entityInside(level, pos, proxy, InsideBlockEffectApplier.NOOP, true);
            }
        }
        outgoing = List.copyOf(PENDING);
    }
}
