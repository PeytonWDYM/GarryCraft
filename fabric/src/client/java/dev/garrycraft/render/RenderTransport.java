package dev.garrycraft.render;

import com.google.gson.Gson;
import dev.garrycraft.bridge.Mailbox;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.atomic.AtomicReference;
import java.util.Arrays;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

/** Texture transfers require acknowledgement. Poses and overlay frames retain only the newest snapshot. */
public final class RenderTransport {
    private static final Gson JSON = new Gson();
    private static final ConcurrentLinkedQueue<TexturePacket> TEXTURES = new ConcurrentLinkedQueue<>();
    private static final AtomicReference<AvatarExporter.Scene> SCENE = new AtomicReference<>();
    private static final AtomicReference<WorldExporter.Section> WORLD = new AtomicReference<>();
    private static WorldExporter.Section sentWorld;
    private static byte[] worldBytes;
    private static long nextWorldSend;
    private static String session = "";
    private static String instance = "";
    private static int nextTexture = 1;
    private static long nextTextureSend;
    private static final AtomicInteger TRANSFER = new AtomicInteger();
    private record TextureUpdate(int id, int width, int height, byte[] rgba) {}
    private static final ConcurrentHashMap<Integer, TextureUpdate> UPDATES = new ConcurrentHashMap<>();
    private static final ConcurrentLinkedQueue<Integer> UPDATE_ORDER = new ConcurrentLinkedQueue<>();
    private static byte[] previousScene;
    private record TexturePacket(int id, byte[] bytes) {}
    private record TextureHeader(String session, String instance, int id, int transfer, int width, int height) {}
    public record Tile(int x, int y, int width, int height, int offset, long revision) {}
    public record FrameHeader(String session, String instance, int width, int height, long frame, double capturedAt, java.util.List<Tile> tiles) {}
    private record Overlay(int width, int height, long frame, double capturedAt, byte[] rgba) {}
    private static final AtomicReference<Overlay> HUD = new AtomicReference<>();
    private static Overlay previousOverlay;
    private static final java.util.Map<Integer, TilePixels> TILE_PIXELS = new java.util.HashMap<>();
    private record TilePixels(byte[] rgba, long revision) {}
    private static long tileRevision;
    private RenderTransport() {}
    public static String instance() { return instance; }

    public static synchronized void reset(String nextSession, String process) {
        session = nextSession;
        instance = process;
        TEXTURES.clear();
        UPDATES.clear();
        UPDATE_ORDER.clear();
        TRANSFER.set(0);
        SCENE.set(null);
        HUD.set(null);
        previousOverlay = null;
        TILE_PIXELS.clear();
        WORLD.set(null);
        sentWorld = null; worldBytes = null;
        nextTexture = 1;
        previousScene = null;
        Textures.reset();
        FrameExporter.reset();
        WorldExporter.reset();
        MeshSnapshots.reset();
    }

    public static synchronized int texture(int width, int height, byte[] rgba) {
        int id = nextTexture++;
        int transfer = TRANSFER.incrementAndGet();
        TEXTURES.add(new TexturePacket(transfer, packet(new TextureHeader(session, instance, id, transfer, width, height), rgba)));
        return id;
    }
    public static void textureUpdate(int id, int width, int height, byte[] rgba) {
        dev.garrycraft.testing.GameplayOracle.texture(id, rgba);
        if (UPDATES.put(id, new TextureUpdate(id, width, height, rgba)) == null) UPDATE_ORDER.add(id);
    }

    public static byte[] packet(Object header, byte[] body) {
        byte[] prefix = (JSON.toJson(header) + "\n").getBytes(StandardCharsets.UTF_8);
        byte[] result = java.util.Arrays.copyOf(prefix, prefix.length + body.length);
        System.arraycopy(body, 0, result, prefix.length, body.length);
        return result;
    }

    static void scene(AvatarExporter.Scene scene) { SCENE.set(scene); }
    public static void overlay(int width, int height, long frame, double capturedAt, byte[] rgba) {
        HUD.set(new Overlay(width, height, frame, capturedAt, rgba));
    }
    private static byte[] tiles(Overlay overlay) {
        if (previousOverlay != null && overlay.width() == previousOverlay.width() && overlay.height() == previousOverlay.height()
            && Arrays.equals(overlay.rgba(), previousOverlay.rgba())) return null;
        if (previousOverlay == null || overlay.width() != previousOverlay.width() || overlay.height() != previousOverlay.height()) TILE_PIXELS.clear();
        previousOverlay = overlay;
        var tiles = new java.util.ArrayList<Tile>();
        var body = new java.io.ByteArrayOutputStream();
        int width = overlay.width(), height = overlay.height();
        byte[] rgba = overlay.rgba();
        for (int y = 0; y < height; y += 128) for (int x = 0; x < width; x += 256) {
            int w = Math.min(256, width - x), h = Math.min(128, height - y);
            boolean visible = false;
            for (int row = y; row < y + h && !visible; row++) for (int column = x; column < x + w; column++)
                if (rgba[(row * width + column) * 4 + 3] != 0) { visible = true; break; }
            if (!visible) continue;
            byte[] pixels = new byte[w * h * 4];
            for (int row = 0; row < h; row++) System.arraycopy(rgba, ((y + row) * width + x) * 4, pixels, row * w * 4, w * 4);
            int key = y * width + x;
            var previous = TILE_PIXELS.get(key);
            long revision = previous != null && Arrays.equals(previous.rgba(), pixels) ? previous.revision() : ++tileRevision;
            TILE_PIXELS.put(key, new TilePixels(pixels, revision));
            tiles.add(new Tile(x, height - y - h, w, h, body.size(), revision));
            body.writeBytes(pixels);
        }
        return packet(new FrameHeader(session, instance, width, height, overlay.frame(), overlay.capturedAt(), tiles), body.toByteArray());
    }
    static void world(WorldExporter.Section packet) { WORLD.set(packet); }

    public static synchronized void send(Mailbox mailbox, int textureAck, String textureInstance) {
        if (!instance.equals(textureInstance)) textureAck = 0;
        var texture = TEXTURES.peek();
        while (texture != null && texture.id() <= textureAck) {
            TEXTURES.poll();
            texture = TEXTURES.peek();
        }
        long now = System.nanoTime();
        if (texture == null) {
            // Publish the latest pixels in arrival order without blocking Minecraft's render thread.
            var id = UPDATE_ORDER.poll();
            if (id != null) {
                var update = UPDATES.remove(id);
                int transfer = TRANSFER.incrementAndGet();
                texture = new TexturePacket(transfer, packet(new TextureHeader(session, instance,
                    update.id(), transfer, update.width(), update.height()), update.rgba()));
                TEXTURES.add(texture);
            }
        }
        if (texture != null && now >= nextTextureSend) {
            mailbox.send(4, texture.bytes());
            nextTextureSend = now + 20_000_000L;
        }
        var scene = SCENE.getAndSet(null);
        if (scene != null) {
            byte[] bytes = MeshPackets.scene(scene);
            if (!Arrays.equals(previousScene, bytes)) { previousScene = bytes; mailbox.send(5, bytes); }
        }
        var overlay = HUD.getAndSet(null);
        if (overlay != null) {
            var bytes = tiles(overlay);
            if (bytes != null) mailbox.send(6, bytes);
        }
        var world = WORLD.get();
        if (world != null && now >= nextWorldSend) {
            if (world != sentWorld) { worldBytes = MeshPackets.section(world); sentWorld = world; }
            mailbox.send(7, worldBytes);
            nextWorldSend = now + 20_000_000L;
        }
    }
}
