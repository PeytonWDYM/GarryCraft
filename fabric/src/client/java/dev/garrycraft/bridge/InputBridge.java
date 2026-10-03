package dev.garrycraft.bridge;

import com.mojang.blaze3d.platform.InputConstants;
import net.minecraft.client.KeyMapping;
import net.minecraft.client.Minecraft;
import net.minecraft.client.input.KeyEvent;
import net.minecraft.client.input.MouseButtonInfo;
import net.minecraft.client.input.CharacterEvent;
import org.lwjgl.sdl.SDLKeyboard;
import net.minecraft.util.Mth;
import dev.garrycraft.item.PhysicsGun;

/** Replays host transitions through Minecraft's handlers, as SkyCraft does for its hidden client. */
public final class InputBridge {
    private static final boolean[] KEYS = new boolean[512];
    private static final boolean[] BUTTONS = new boolean[8];
    private static int selectedSlot = -1;
    private static long acknowledged;
    private static String session = "";
    private static long clientAcknowledged;
    private static long jumpPress = -1;
    private static boolean pendingJump;
    private InputBridge() {}
    public static long acknowledged() { return acknowledged; }
    public static long clientAcknowledged() { return clientAcknowledged; }

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
        apply(mc, input, null, true);
    }

    public static void apply(Minecraft mc, HostInput input, ClientControls controls, boolean movementTick) {
        if (!session.equals(input.session()) && input.active()) {
            session = input.session();
            acknowledged = 0;
            selectedSlot = -1;
            clientAcknowledged = 0;
            jumpPress = -1;
            pendingJump = false;
        }
        if (!input.active()) {
            jumpPress = -1;
            pendingJump = false;
        } else if (input.jumpPress() >= 0) {
            // A negative fixture counter leaves Source's press history unchanged.
            // The first active snapshot establishes the session baseline without replaying old presses.
            if (jumpPress >= 0 && input.jumpPress() > jumpPress) pendingJump = true;
            jumpPress = input.jumpPress();
        }
        // Select the new item before routing its buttons, including a held click during a slot change.
        if (mc.player != null) {
            int slot = controls == null ? input.slot() : controls.slot();
            if (selectedSlot != slot) {
                selectedSlot = slot;
                mc.player.getInventory().setSelectedSlot(selectedSlot);
            }
        }
        boolean nativeGun = input.active() && mc.player != null && PhysicsGun.equipped(mc.player);
        boolean detachedMining = dev.garrycraft.physicsblocks.DetachedBlockMining.suppressAttack(mc, input);
        var options = mc.options;
        key(mc, options.keyUp, input.forward());
        key(mc, options.keyDown, input.back());
        key(mc, options.keyLeft, input.left());
        key(mc, options.keyRight, input.right());
        // Render frames can collect an edge, but only the vanilla movement tick consumes or releases it.
        if (movementTick || !input.active()) {
            key(mc, options.keyJump, input.jump() || pendingJump);
            pendingJump = false;
        }
        key(mc, options.keyShift, input.sneak());
        key(mc, options.keySprint, input.sprint());
        key(mc, options.keyTogglePerspective, controls == null ? input.camera() : controls.camera());
        key(mc, options.keyInventory, controls == null ? input.inventory() : controls.inventory());
        key(mc, options.keyChat, controls == null ? input.chat() : controls.chat());
        key(mc, 226, mc.gui.screen() != null && controls != null && controls.alt());
        if (mc.gui.screen() != null) {
            if (controls != null) {
                key(mc, 225, controls.shift());
                key(mc, 224, controls.control());
            }
            move(mc, controls == null ? input.mouseX() : controls.mouseX(), controls == null ? input.mouseY() : controls.mouseY());
        }
        if (controls == null || mc.gui.screen() == null) {
            boolean minecraftButtons = !nativeGun || mc.gui.screen() != null;
            mouse(mc, 1, minecraftButtons && !detachedMining && (controls == null ? input.attack() : controls.attack()));
            mouse(mc, 3, minecraftButtons && (controls == null ? input.use() : controls.use()));
        }
        if (controls != null) for (var event : controls.events()) {
            if (event.id() <= clientAcknowledged) continue;
            move(mc, event.mouseX(), event.mouseY());
            if (event.key() != 0) {
                key(mc, event.key(), true);
                key(mc, event.key(), false);
            } else if (event.button() != 0) {
                // A queued menu event can arrive after the menu closes. It cannot fire the held gun in Minecraft.
                if ((!nativeGun || mc.gui.screen() != null) && (event.button() != 1 || !detachedMining)) mouse(mc, event.button(), event.down());
            } else if (event.scroll() != 0) {
                if (!nativeGun || mc.gui.screen() != null) mc.mouseHandler.onScroll(mc.getWindow().handle(), 0, event.scroll());
            } else event.text().codePoints().forEach(point -> mc.keyboardHandler.charTyped(mc.getWindow().handle(), new CharacterEvent(point)));
            clientAcknowledged = event.id();
        }
        if (input.uiEvents() != null) for (var event : input.uiEvents()) {
            if (event.id() <= acknowledged) continue;
            if (event.key() != 0) {
                key(mc, event.key(), true);
                key(mc, event.key(), false);
            } else event.text().codePoints().forEach(point -> mc.keyboardHandler.charTyped(mc.getWindow().handle(), new CharacterEvent(point)));
            acknowledged = event.id();
        }
        if (nativeGun && mc.gui.screen() == null) {
            // Mouse releases do not discard clicks already queued before the hotbar selected this item.
            options.keyAttack.setDown(false);
            options.keyUse.setDown(false);
            while (options.keyAttack.consumeClick()) {}
            while (options.keyUse.consumeClick()) {}
        }
        if (detachedMining) {
            options.keyAttack.setDown(false);
            while (options.keyAttack.consumeClick()) {}
        }
        if (mc.player != null) {
            // Keep yaw continuous so vanilla hand sway never interpolates across a 360-degree discontinuity.
            float yaw = controls == null ? input.yaw() : controls.yaw();
            float pitch = controls == null ? input.pitch() : controls.pitch();
            mc.player.setYRot(mc.player.getYRot() + Mth.wrapDegrees(yaw - mc.player.getYRot()));
            mc.player.setXRot(pitch);
            mc.player.yRotO = mc.player.getYRot();
            mc.player.xRotO = pitch;
        }
    }

    private static void move(Minecraft mc, double x, double y) {
        var window = mc.getWindow();
        mc.mouseHandler.onMove(window.handle(), x * window.getScreenWidth(), y * window.getScreenHeight(), 0, 0);
    }
}
