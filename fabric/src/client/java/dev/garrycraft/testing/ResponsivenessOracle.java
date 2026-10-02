package dev.garrycraft.testing;

import com.google.gson.Gson;
import dev.garrycraft.GarryCraftClient;
import dev.garrycraft.bridge.BridgeClock;
import dev.garrycraft.bridge.HostInput;
import dev.garrycraft.mixin.CreativeScreenAccessor;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Map;
import net.minecraft.client.Minecraft;
import net.minecraft.client.CameraType;
import net.minecraft.client.gui.components.AbstractSelectionList;
import net.minecraft.client.gui.screens.inventory.CreativeModeInventoryScreen;
import net.minecraft.client.gui.screens.options.VideoSettingsScreen;
import net.minecraft.client.tutorial.TutorialSteps;
import net.minecraft.world.item.CreativeModeTabs;
import net.minecraft.world.level.GameType;

/** Exercises actual client input packets, vanilla screen handlers, and the yaw wrap boundary in both games. */
public final class ResponsivenessOracle {
    private static String request = "", phase = "waiting";
    private static int tick;
    private static boolean running;
    private static GameType savedMode;
    private static CameraType savedCamera;
    private static final ArrayList<Map<String, Object>> samples = new ArrayList<>();
    private static final ArrayList<Double> ages = new ArrayList<>();
    private static final ArrayList<Map<String, Object>> searches = new ArrayList<>();
    private static float previousYaw, maxYawStep;
    private static long previousFrame;
    private static double videoScroll, creativeScroll;
    private ResponsivenessOracle() {}
    public static String phase() { return phase; }
    public static String request() { return request; }
    public static boolean running() { return running; }

    public static void tick(Minecraft mc, HostInput input) {
        if (!running && input.test().startsWith("responsiveness:") && !input.test().equals(request)) {
            request = input.test(); phase = "look"; tick = 0; running = true;
            samples.clear(); ages.clear(); maxYawStep = 0; previousFrame = 0; videoScroll = 0; creativeScroll = 0;
            searches.clear();
            previousYaw = mc.player.getYRot();
            savedMode = mc.gameMode.getPlayerMode();
            savedCamera = mc.options.getCameraType();
            mc.options.setCameraType(CameraType.FIRST_PERSON);
            FrameTimings.reset();
        }
        if (!running) return;
        if (!input.test().equals(request)) { finish(mc, false); return; }
        tick++;
        if (tick == 60) {
            phase = "video";
            mc.gui.setScreen(new VideoSettingsScreen(null, mc, mc.options));
        }
        if (phase.equals("video")) {
            var list = mc.gui.screen().children().stream().filter(child -> child instanceof AbstractSelectionList<?>).findFirst().orElseThrow();
            videoScroll = Math.max(videoScroll, ((AbstractSelectionList<?>) list).scrollAmount());
        }
        if (tick == 140) {
            phase = "creative";
            mc.gameMode.setLocalMode(GameType.CREATIVE);
            var screen = new CreativeModeInventoryScreen(mc.player, mc.level.enabledFeatures(), true);
            mc.gui.setScreen(screen);
            ((CreativeScreenAccessor) screen).garrycraft$tab(CreativeModeTabs.searchTab());
        }
        if (tick == 180) phase = "search";
        if (tick == 220) phase = "edit-search";
        if (phase.equals("creative")) creativeScroll = Math.max(creativeScroll,
            ((CreativeScreenAccessor) mc.gui.screen()).garrycraft$scroll());
        if (tick == 215 || tick == 255) {
            var screen = (CreativeModeInventoryScreen) mc.gui.screen();
            searches.add(Map.of("phase", phase, "query", ((CreativeScreenAccessor) screen).garrycraft$searchBox().getValue(),
                "items", screen.getMenu().items.stream().map(stack -> stack.getHoverName().getString()).toList()));
        }
        samples.add(Map.of("tick", tick, "phase", phase, "videoScroll", videoScroll, "creativeScroll", creativeScroll));
        if (tick == 260) finish(mc, true);
    }

    public static void frame(Minecraft mc) {
        if (!running) return;
        var controls = GarryCraftClient.controls();
        if (controls == null || controls.frame() == previousFrame) return;
        previousFrame = controls.frame();
        ages.add((BridgeClock.seconds() - controls.time()) * 1000);
        float yaw = mc.player.getYRot();
        if (tick >= 10 && previousFrame != 0) maxYawStep = Math.max(maxYawStep, Math.abs(yaw - previousYaw));
        previousYaw = yaw;
    }

    private static void finish(Minecraft mc, boolean completed) {
        running = false; phase = "done";
        mc.gui.setScreen(null); mc.gameMode.setLocalMode(savedMode); mc.options.setCameraType(savedCamera);
        try {
            var output = Path.of(System.getProperty("garrycraft.artifacts")); Files.createDirectories(output);
            Files.writeString(output.resolve("responsiveness-minecraft.json"), new Gson().toJson(Map.of(
                "request", request, "completed", completed, "videoScroll", videoScroll, "creativeScroll", creativeScroll,
                "maxYawStep", maxYawStep, "inputAgesMs", ages, "samples", samples,
                "tutorialDisabled", mc.options.tutorialStep == TutorialSteps.NONE, "fpsLimit", mc.options.framerateLimit().get(),
                "searches", searches)));
            FrameTimings.save(output);
        } catch (IOException failure) { throw new IllegalStateException("Cannot save responsiveness trace", failure); }
    }
}
