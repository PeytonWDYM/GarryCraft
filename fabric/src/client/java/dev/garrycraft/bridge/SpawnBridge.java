package dev.garrycraft.bridge;

import net.minecraft.client.Minecraft;
import net.minecraft.client.player.LocalPlayer;

/** Source chooses spawn positions. A sequence acknowledges each completed mirror teleport. */
public final class SpawnBridge {
    private static long requested;
    private static long acknowledged;
    private static long deaths;
    private static boolean dead;
    private static LocalPlayer previousPlayer;
    private static String session = "";

    private SpawnBridge() {}
    public static long acknowledged() { return acknowledged; }
    public static long deaths() { return deaths; }

    /** Returns true while input must remain frozen for a death or pending teleport. */
    public static boolean update(Minecraft mc, HostInput host) {
        if (!host.session().equals(session)) {
            session = host.session();
            requested = acknowledged = deaths = 0;
            dead = false;
            previousPlayer = null;
        }
        var player = mc.player;
        boolean dying = player.isDeadOrDying();
        if (dying && !dead) deaths++;
        dead = dying;
        if (host.teleportSeq() != requested) {
            requested = host.teleportSeq();
            previousPlayer = null;
            if (dying) player.respawn();
        }
        if (dying) return true;
        if (requested == acknowledged) return false;

        player.noPhysics = true;
        player.setNoGravity(true);
        player.setPos(host.x(), host.y(), host.z());
        player.setDeltaMovement(0, 0, 0);
        if (previousPlayer != player) {
            previousPlayer = player;
            long sequence = requested;
            String pendingSession = session;
            double x = host.x(), y = host.y(), z = host.z();
            var server = mc.getSingleplayerServer();
            server.execute(() -> {
                var peer = server.getPlayerList().getPlayer(player.getUUID());
                if (sequence > 1) {
                    peer.setHealth(peer.getMaxHealth());
                    peer.setAirSupply(peer.getMaxAirSupply());
                    peer.getFoodData().setFoodLevel(20);
                    peer.removeAllEffects();
                }
                peer.teleportTo(x, y, z);
                peer.setDeltaMovement(0, 0, 0);
                peer.resetFallDistance();
                mc.execute(() -> {
                    if (requested != sequence || !session.equals(pendingSession)) return;
                    player.setPos(x, y, z);
                    player.xo = x;
                    player.yo = y;
                    player.zo = z;
                    player.setDeltaMovement(0, 0, 0);
                    player.resetFallDistance();
                    acknowledged = sequence;
                });
            });
        }
        return true;
    }
}
