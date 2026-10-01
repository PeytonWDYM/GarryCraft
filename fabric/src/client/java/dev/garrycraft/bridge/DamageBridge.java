package dev.garrycraft.bridge;

import net.minecraft.client.Minecraft;

/** Applies each Source hit once on Minecraft's server, retaining its attacker and death-message type. */
public final class DamageBridge {
    private static volatile String session = "";
    private static long scheduled;
    private static volatile long acknowledged;
    private DamageBridge() {}
    public static long acknowledged() { return acknowledged; }

    public static void update(Minecraft mc, HostInput input) {
        if (!session.equals(input.session())) {
            session = input.session();
            scheduled = acknowledged = 0;
        }
        if (input.damageEvents() == null) return;
        var server = mc.getSingleplayerServer();
        var uuid = mc.player.getUUID();
        for (var event : input.damageEvents()) {
            if (event.id() <= scheduled) continue;
            scheduled = event.id();
            String pendingSession = session;
            server.execute(() -> {
                if (!session.equals(pendingSession)) return;
                var peer = server.getPlayerList().getPlayer(uuid);
                if (!peer.isDeadOrDying()) {
                    var source = new SourceDamage(peer.damageSources().generic().typeHolder(), event.attacker(), event.kind());
                    peer.hurtServer(peer.level(), source, event.amount());
                }
                acknowledged = event.id();
            });
        }
    }
}
