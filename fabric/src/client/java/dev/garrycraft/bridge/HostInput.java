package dev.garrycraft.bridge;

import java.util.List;

/** Input is sampled in Source. The Minecraft player integrates it on its own 20 Hz tick.
 * A negative jumpPress identifies fixture input without a Source press counter. */
public record HostInput(int version, String session, long frame, boolean active,
                        double x, double y, double z, float yaw, float pitch,
                        boolean forward, boolean back, boolean left, boolean right,
                        boolean jump, boolean sneak, boolean sprint,
                        boolean attack, boolean use, int slot, String test, int geometryBatches,
                        long teleportSeq, double damageTotal, int textureAck,
                        boolean camera, boolean inventory, boolean escape, double mouseX, double mouseY,
                        String textureInstance, int targetFps, boolean chat,
                        List<UiEvent> uiEvents, List<DamageEvent> damageEvents,
                        int viewportWidth, int viewportHeight, long entityHitAck, long worldAck, String worldInstance,
                        List<dev.garrycraft.combat.SourceMobs.Damage> mobDamage, long renderEpoch,
                        dev.garrycraft.combat.DamageScaling.Settings damageScaling, List<BlockPick> blockPick, BlockMine blockMine,
                        long jumpPress) {
    public record UiEvent(long id, int key, String text) {}
    public record DamageEvent(long id, float amount, String attacker, String kind) {}
    public record BlockPick(long id, String instance, int x, int y, int z) {}
    public record BlockMine(long id, double x, double y, double z, double hx, double hy, double hz, boolean attack, long press) {}
    public static HostInput idle() {
        return new HostInput(1, "", 0, false, 0, 0, 0, 0, 0,
                false, false, false, false, false, false, false, false, false, 0, "", 0, 0, 0, 0, false, false, false, 0, 0, "", 0, false, List.of(), List.of(), 0, 0, 0, 0, "", List.of(), 0, dev.garrycraft.combat.DamageScaling.DEFAULTS, List.of(), null, 0);
    }
}
