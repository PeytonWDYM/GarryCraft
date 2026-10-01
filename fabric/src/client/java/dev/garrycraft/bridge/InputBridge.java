package dev.garrycraft.bridge;

import com.mojang.blaze3d.platform.InputConstants;
import net.minecraft.client.KeyMapping;
import net.minecraft.client.Minecraft;
import net.minecraft.client.input.KeyEvent;
import net.minecraft.client.input.MouseButtonInfo;
import net.minecraft.client.input.CharacterEvent;
import org.lwjgl.sdl.SDLKeyboard;

/** Replays host transitions through Minecraft's handlers, as SkyCraft does for its hidden client. */
public final class InputBridge {
    private static final boolean[] KEYS = new boolean[512];
    private static final boolean[] BUTTONS = new boolean[8];
    private static int selectedSlot = -1;
    private static long acknowledged;
    private static String session = "";
    private InputBridge() {}
    public static long acknowledged() { return acknowledged; }

    public static boolean isKeyDown(int scancode) {
        return scancode >= 0 && scancode < KEYS.length && KEYS[scancode];
    }

    private static int modifiers() {
        return (KEYS[225] ? 1 : 0) | (KEYS[229] ? 2 : 0) | (KEYS[224] ? 64 : 0)
                | (KEYS[228] ? 128 : 0) | (KEYS[226] ? 256 : 0) | (KEYS[230] ? 512 : 0);
    }

    private static void key(Minecraft mc, KeyMapping mapping, boolean down) {
        int scancode = InputConstants.getKey(mapping.saveString()).getValue();
        key(mc, scancode, down);
        // Window focus changes can clear Minecraft's mappings while Source still holds the key.
        mapping.setDown(down);
    }

    private static void key(Minecraft mc, int scancode, boolean down) {
        if (KEYS[scancode] == down) return;
        KEYS[scancode] = down;
        int modifiers = modifiers();
        int keycode = SDLKeyboard.SDL_GetKeyFromScancode(scancode, (short) modifiers, true);
        mc.keyboardHandler.keyPress(mc.getWindow().handle(), down ? 1 : 0, new KeyEvent(scancode, keycode, modifiers));
    }

    private static void mouse(Minecraft mc, int button, boolean down) {
        if (BUTTONS[button] == down) return;
        BUTTONS[button] = down;
        mc.mouseHandler.onButton(mc.getWindow().handle(), new MouseButtonInfo(button, modifiers()), down ? 1 : 0);
    }

    public static void apply(Minecraft mc, HostInput input) {
        if (!session.equals(input.session()) && input.active()) {
            session = input.session();
            acknowledged = 0;
            selectedSlot = -1;
        }
        var options = mc.options;
        key(mc, options.keyUp, input.forward());
        key(mc, options.keyDown, input.back());
        key(mc, options.keyLeft, input.left());
        key(mc, options.keyRight, input.right());
        key(mc, options.keyJump, input.jump());
        key(mc, options.keyShift, input.sneak());
        key(mc, options.keySprint, input.sprint());
        key(mc, options.keyTogglePerspective, input.camera());
        key(mc, options.keyInventory, input.inventory());
        key(mc, options.keyChat, input.chat());
        if (mc.gui.screen() != null) {
            var window = mc.getWindow();
            mc.mouseHandler.onMove(window.handle(), input.mouseX() * window.getScreenWidth(), input.mouseY() * window.getScreenHeight(), 0, 0);
        }
        mouse(mc, 1, input.attack());
        mouse(mc, 3, input.use());
        if (input.uiEvents() != null) for (var event : input.uiEvents()) {
            if (event.id() <= acknowledged) continue;
            if (event.key() != 0) {
                key(mc, event.key(), true);
                key(mc, event.key(), false);
            } else event.text().codePoints().forEach(point -> mc.keyboardHandler.charTyped(mc.getWindow().handle(), new CharacterEvent(point)));
            acknowledged = event.id();
        }
        if (mc.player != null) {
            mc.player.setYRot(input.yaw());
            mc.player.setXRot(input.pitch());
            mc.player.yRotO = input.yaw();
            mc.player.xRotO = input.pitch();
            if (selectedSlot != input.slot()) {
                selectedSlot = input.slot();
                mc.player.getInventory().setSelectedSlot(selectedSlot);
            }
        }
    }
}
