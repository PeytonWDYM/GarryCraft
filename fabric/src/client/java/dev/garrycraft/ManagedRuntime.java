package dev.garrycraft;

import com.google.gson.JsonParser;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import net.minecraft.client.Minecraft;

/** The owned launcher requests a normal client shutdown so Minecraft saves its world. */
public final class ManagedRuntime {
    private static final String CONTROL = System.getProperty("garrycraft.control", "");
    private static long nextPoll;
    private static boolean ready;

    private ManagedRuntime() {}

    public static void tick(Minecraft minecraft) {
        if (CONTROL.isEmpty() || System.nanoTime() < nextPoll) return;
        nextPoll = System.nanoTime() + 500_000_000L;
        try {
            if (!ready && minecraft.level != null) {
                Files.writeString(Path.of(CONTROL).resolveSibling("ready.json"), "{\"ready\":true}");
                ready = true;
            }
            if (JsonParser.parseString(Files.readString(Path.of(CONTROL))).getAsJsonObject().get("stop").getAsBoolean()) {
                GarryCraftClient.LOG.info("GarryCraft launcher requested Minecraft shutdown");
                GarryCraftClient.restoreOptions(minecraft);
                minecraft.options.save();
                minecraft.stop();
            }
        } catch (IOException error) {
            GarryCraftClient.LOG.error("Cannot read managed shutdown request", error);
        }
    }
}
