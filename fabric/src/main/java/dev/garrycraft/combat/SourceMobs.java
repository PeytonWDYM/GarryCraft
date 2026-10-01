package dev.garrycraft.combat;

import java.util.List;
import java.util.UUID;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.minecraft.server.MinecraftServer;
import net.minecraft.world.entity.Mob;
import net.minecraft.world.entity.monster.Enemy;

/** Publishes combat targets for Source NPCs and applies acknowledged Source damage on the Minecraft server. */
public final class SourceMobs {
    public record MobState(String uuid, double x, double y, double z, float width, float height, float health, boolean enemy) {}
    public record Damage(long id, String uuid, float amount, int attacker, int generation) {}
    private record Input(String session, boolean active, List<Damage> damage) {}
    private static volatile Input input = new Input("", false, List.of());
    private static volatile List<MobState> outgoing = List.of();
    private static volatile long acknowledged;
    private static String session = "";
    private SourceMobs() {}
    public static void init() { ServerTickEvents.END_SERVER_TICK.register(SourceMobs::tick); }
    public static void update(String session, boolean active, List<Damage> events) { input = new Input(session, active, events); }
    public static List<MobState> states() { return outgoing; }
    public static long acknowledged() { return acknowledged; }
    private static void tick(MinecraftServer server) {
        var current = input;
        if (!session.equals(current.session())) { session = current.session(); acknowledged = 0; outgoing = List.of(); }
        var players = server.getPlayerList().getPlayers();
        if (!current.active() || players.isEmpty()) { outgoing = List.of(); return; }
        var peer = players.getFirst(); var level = peer.level();
        for (var event : current.damage()) {
            if (event.id() <= acknowledged) continue;
            var entity = level.getEntity(UUID.fromString(event.uuid()));
            if (entity instanceof Mob mob && mob.isAlive()) {
                var attacker = SourceCombat.proxy(event.attacker(), event.generation());
                mob.hurtServer(level, attacker != null ? level.damageSources().mobAttack(attacker)
                    : new dev.garrycraft.bridge.SourceDamage(level.damageSources().generic().typeHolder(), "", "melee"), event.amount());
            }
            acknowledged = event.id();
        }
        outgoing = level.getEntitiesOfClass(Mob.class, peer.getBoundingBox().inflate(96)).stream().filter(Mob::isAlive)
            .map(mob -> new MobState(mob.getStringUUID(), mob.getX(), mob.getY(), mob.getZ(), mob.getBbWidth(), mob.getBbHeight(),
                mob.getHealth(), mob instanceof Enemy)).toList();
    }
}
