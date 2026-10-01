package dev.garrycraft.testing;

import com.google.gson.Gson;
import dev.garrycraft.bridge.HostInput;
import dev.garrycraft.combat.DamageScaling;
import dev.garrycraft.combat.SourceActor;
import java.nio.file.Files;
import java.nio.file.Path;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import net.minecraft.client.Minecraft;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.EntityTypes;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.animal.cow.Cow;
import net.minecraft.world.entity.EquipmentSlot;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.GameType;

/** Measures damage through both real game processes in an owned, bounded scenario. */
public final class DamageOracle {
    private record Hit(String direction, float expected, float actual, boolean passed) {}
    private static final List<Hit> HITS = new ArrayList<>();
    private static final Map<String, Float> NATIVE = new LinkedHashMap<>();
    private static String request = "", phase = "waiting", mobId = "";
    private static int tick;
    private static boolean running;
    private static CompletableFuture<?> pending = CompletableFuture.completedFuture(null);
    private static Cow cow;
    private static ServerPlayer player;
    private static GameType mode;
    private static float health;
    private static ItemStack[] armor;
    private static final EquipmentSlot[] ARMOR = {EquipmentSlot.HEAD, EquipmentSlot.CHEST, EquipmentSlot.LEGS, EquipmentSlot.FEET};
    private DamageOracle() {}
    public static String request() { return request; }
    public static String phase() { return phase; }
    public static String mob() { return mobId; }
    public static boolean running() { return running; }
    public static void update(Minecraft mc, HostInput host) {
        if (!running && host.test().startsWith("damage:") && !host.test().equals(request)) {
            request = host.test(); running = true; phase = "prepare"; tick = 0; HITS.clear(); NATIVE.clear();
            var server = mc.getSingleplayerServer(); var uuid = mc.player.getUUID();
            pending = server.submit(() -> {
                player = server.getPlayerList().getPlayer(uuid); mode = player.gameMode.getGameModeForPlayer(); health = player.getHealth();
                armor = new ItemStack[ARMOR.length];
                for (int i = 0; i < ARMOR.length; i++) { armor[i] = player.getItemBySlot(ARMOR[i]); player.setItemSlot(ARMOR[i], ItemStack.EMPTY); }
                player.setGameMode(GameType.SURVIVAL); player.setHealth(20);
                cow = new Cow(EntityTypes.COW, player.level()); cow.setNoAi(true);
                cow.setPos(player.getX() + 2, player.getY(), player.getZ()); player.level().addFreshEntity(cow);
                mobId = cow.getStringUUID();
            });
        }
        if (!running || !pending.isDone()) return;
        pending.join();
        if (!host.test().equals(request) || !host.active()) { finish(mc); return; }
        tick++;
        if (tick % 40 != 0 && !phase.equals("source-player") && !phase.equals("source-mob")) return;
        var server = mc.getSingleplayerServer();
        pending = server.submit(() -> {
            var level = player.level(); var settings = DamageScaling.settings();
            // A video change can delay bridge delivery. Keep the largest observed loss until the phase ends.
            if (phase.equals("source-player")) NATIVE.merge("source-player", 20 - player.getHealth(), Math::max);
            if (phase.equals("source-mob")) NATIVE.merge("source-mob", 10 - cow.getHealth(), Math::max);
            switch (tick) {
                case 40, 80 -> {
                    var target = level.getEntitiesOfClass(SourceActor.class, player.getBoundingBox().inflate(32),
                        actor -> actor.getName().getString().equals("garrycraft-scaling-npc")).getFirst();
                    phase = tick == 40 ? "player-source" : "mob-source";
                    target.hurtServer(level, tick == 40 ? level.damageSources().playerAttack(player) : level.damageSources().mobAttack(cow), tick == 40 ? 7 : 3);
                }
                case 120 -> { phase = "mob-player"; hit(player, level.damageSources().mobAttack(cow), 3, 3 * settings.mobToPlayer()); }
                case 160 -> { phase = "player-mob"; hit(cow, level.damageSources().playerAttack(player), 3, 3 * settings.playerToMob()); }
                case 200 -> { phase = "mob-mob"; hit(cow, level.damageSources().mobAttack(cow), 3, 3 * settings.mobToMob()); }
                case 240 -> { phase = "environment"; hit(player, level.damageSources().generic(), 3, 3 * settings.environment()); }
                case 280 -> { player.setHealth(20); phase = "source-player"; }
                case 320 -> { cow.setHealth(10); phase = "source-mob"; }
                case 360 -> phase = "done";
            }
        });
        if (tick == 400) finish(mc);
    }
    private static void hit(LivingEntity victim, DamageSource source, float amount, float expected) {
        victim.setHealth(victim.getMaxHealth());
        float before = victim.getHealth();
        victim.hurtServer(player.level(), source, amount);
        float actual = before - victim.getHealth();
        HITS.add(new Hit(phase, expected, actual, Math.abs(expected - actual) < .001));
    }
    private static void finish(Minecraft mc) {
        pending.join(); running = false; phase = "done";
        var server = mc.getSingleplayerServer();
        server.execute(() -> {
            cow.discard(); player.setHealth(health); player.setGameMode(mode);
            for (int i = 0; i < ARMOR.length; i++) player.setItemSlot(ARMOR[i], armor[i]);
        });
        try {
            var directory = Path.of(System.getProperty("garrycraft.artifacts"));
            Files.writeString(directory.resolve("damage-minecraft.json"), new Gson().toJson(new Result(request, List.copyOf(HITS), Map.copyOf(NATIVE))));
        } catch (IOException failure) { throw new IllegalStateException("Could not save damage trace", failure); }
    }
    private record Result(String request, List<Hit> hits, Map<String, Float> nativeDamage) {}
}
