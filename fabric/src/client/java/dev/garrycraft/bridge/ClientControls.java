package dev.garrycraft.bridge;

import java.util.List;

/** Render-rate input from the Source client. Server input still owns movement and session authority. */
public record ClientControls(int version, String session, long teleportSeq, long frame, double time,
                             float yaw, float pitch, double mouseX, double mouseY,
                             boolean camera, boolean inventory, boolean chat, boolean attack, boolean use,
                             boolean shift, boolean control, boolean alt,
                             int viewportWidth, int viewportHeight, int slot, List<Event> events) {
    public record Event(long id, int key, String text, double scroll, int button, boolean down,
                        double mouseX, double mouseY) {}
}
