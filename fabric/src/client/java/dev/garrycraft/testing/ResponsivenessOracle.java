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
import java.util.Locale;
import net.minecraft.client.Minecraft;
import net.minecraft.client.CameraType;
import net.minecraft.client.gui.components.AbstractSelectionList;
import net.minecraft.client.gui.components.EditBox;
import net.minecraft.client.gui.screens.ChatScreen;
import net.minecraft.client.gui.screens.inventory.CreativeModeInventoryScreen;
import net.minecraft.client.gui.screens.options.VideoSettingsScreen;
import net.minecraft.client.tutorial.TutorialSteps;
import net.minecraft.world.item.CreativeModeTabs;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.TooltipFlag;
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
    private static boolean uiInput;
    private static int allItems;
    private ResponsivenessOracle() {}
    public static String phase() { return phase; }
    public static String request() { return request; }
    public static boolean running() { return running; }

    public static void tick(Minecraft mc, HostInput input) {
        if (!running && input.test().startsWith("responsiveness:") && !input.test().equals(request)) {
            request = input.test(); phase = "look"; tick = 0; running = true;
            uiInput = request.startsWith("responsiveness:ui-input:");
            allItems = 0;
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
        if (uiInput) { tickUiInput(mc); return; }
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
        if (!running || uiInput) return;
        var controls = GarryCraftClient.controls();
        if (controls == null || controls.frame() == previousFrame) return;
        previousFrame = controls.frame();
        ages.add((BridgeClock.seconds() - controls.time()) * 1000);
        float yaw = mc.player.getYRot();
        if (tick >= 10 && previousFrame != 0) maxYawStep = Math.max(maxYawStep, Math.abs(yaw - previousYaw));
        previousYaw = yaw;
    }

    private static void openCreativeSearch(Minecraft mc) {
        mc.gameMode.setLocalMode(GameType.CREATIVE);
        var screen = new CreativeModeInventoryScreen(mc.player, mc.level.enabledFeatures(), true);
        mc.gui.setScreen(screen);
        ((CreativeScreenAccessor) screen).garrycraft$tab(CreativeModeTabs.searchTab());
        allItems = screen.getMenu().items.size();
    }

    private static void uiPhase(Minecraft mc, String next) {
        phase = next;
        double x = .5, y = .5;
        if (mc.gui.screen() instanceof CreativeModeInventoryScreen creative) {
            var search = ((CreativeScreenAccessor) creative).garrycraft$searchBox();
            x = (search.getX() + search.getWidth() / 2.0) / creative.width;
            y = (search.getY() + search.getHeight() / 2.0) / creative.height;
        }
        save("ui-input-live.json", Map.of("request", request, "phase", phase, "mouseX", x, "mouseY", y));
    }

    // Windows sends real input to Source during these phases. The oracle only observes Minecraft widgets.
    private static void tickUiInput(Minecraft mc) {
        if (tick == 1) { openCreativeSearch(mc); uiPhase(mc, "creative-search"); }
        if (tick == 160) { mc.gui.setScreen(null); uiPhase(mc, "creative-close"); }
        if (tick == 180) { openCreativeSearch(mc); uiPhase(mc, "creative-reopen"); }
        if (tick == 320) { mc.gui.setScreen(null); uiPhase(mc, "creative-close-again"); }
        if (tick == 340) { mc.gui.setScreen(new ChatScreen("", true)); uiPhase(mc, "chat-completion"); }
        if (tick == 540) { mc.gui.setScreen(null); uiPhase(mc, "chat-close"); }
        if (tick == 560) { mc.gui.setScreen(new ChatScreen("", true)); uiPhase(mc, "chat-reopen"); }
        var screen = mc.gui.screen();
        String search = "", chat = "";
        int items = 0, matchingItems = 0;
        if (screen instanceof CreativeModeInventoryScreen creative) {
            search = ((CreativeScreenAccessor) creative).garrycraft$searchBox().getValue();
            items = creative.getMenu().items.size();
            String term = search.toLowerCase(Locale.ROOT);
            var context = Item.TooltipContext.of(mc.level.registryAccess());
            var flag = TooltipFlag.NORMAL.asCreative();
            // Vanilla indexes creative tooltip text, including the template's required material.
            matchingItems = (int) creative.getMenu().items.stream()
                .filter(item -> item.getTooltipLines(context, null, flag).stream()
                    .anyMatch(line -> line.getString().toLowerCase(Locale.ROOT).contains(term))).count();
            if (tick == 150 || tick == 300) {
                searches.add(Map.of("phase", phase, "query", search, "items", creative.getMenu().items.stream()
                    .map(item -> Map.of("name", item.getHoverName().getString(), "tooltip",
                        item.getTooltipLines(context, null, flag).stream().map(line -> line.getString()).toList())).toList()));
            }
        }
        if (screen instanceof ChatScreen) {
            var input = (EditBox) screen.children().stream().filter(child -> child instanceof EditBox).findFirst().orElseThrow();
            chat = input.getValue();
        }
        samples.add(Map.of("tick", tick, "phase", phase, "screen", screen == null ? "none" : screen.getClass().getSimpleName(),
            "search", search, "items", items, "allItems", allItems, "matchingItems", matchingItems,
            "chat", chat, "dayTime", mc.level.getOverworldClockTime()));
        if (tick == 700) finish(mc, true);
    }

    private static void save(String name, Object value) {
        try {
            var output = Path.of(System.getProperty("garrycraft.artifacts"));
            Files.createDirectories(output);
            Files.writeString(output.resolve(name), new Gson().toJson(value));
        } catch (IOException failure) { throw new IllegalStateException("Cannot save UI input trace", failure); }
    }

    private static void finish(Minecraft mc, boolean completed) {
        running = false; phase = "done";
        mc.gui.setScreen(null); mc.gameMode.setLocalMode(savedMode); mc.options.setCameraType(savedCamera);
        if (uiInput) {
            save("ui-input-minecraft.json", Map.of("request", request, "completed", completed,
                "samples", samples, "recentChat", mc.gui.hud.getChat().getRecentChat(), "searches", searches));
            uiPhase(mc, "done");
            return;
        }
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
