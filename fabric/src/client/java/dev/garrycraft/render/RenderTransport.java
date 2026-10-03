package dev.garrycraft.render;

import com.google.gson.Gson;
import dev.garrycraft.bridge.Mailbox;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.atomic.AtomicReference;
import java.util.Arrays;
import java.util.concurrent.ConcurrentHashMap;

/** Texture transfers require acknowledgement. Poses and overlay frames retain only the newest snapshot. */
public final class RenderTransport {
    private static final Gson JSON = new Gson();
    private record TextureUpdate(int id, int width, int height, byte[] rgba) {}
    private record TexturePacket(int id, byte[] bytes) {}
    private record TextureHeader(String session, String instance, int id, int transfer, int width, int height) {}
    public record Tile(int x, int y, int width, int height, int offset, long revision) {}
    public record FrameHeader(String session, String instance, int width, int height, long frame, double capturedAt, java.util.List<Tile> tiles) {}
    private record Overlay(int width, int height, long frame, double capturedAt, byte[] rgba) {}
    private record TilePixels(byte[] rgba, long revision) {}
    /** The render thread publishes snapshots. Only the transfer thread changes packing and delivery state. */
    private static final class Generation {
        final String session, instance;
        final ConcurrentLinkedQueue<TextureUpdate> textures = new ConcurrentLinkedQueue<>();
        final ConcurrentHashMap<Integer, TextureUpdate> updates = new ConcurrentHashMap<>();
        final ConcurrentLinkedQueue<Integer> updateOrder = new ConcurrentLinkedQueue<>();
        final AtomicReference<AvatarExporter.Scene> scene = new AtomicReference<>();
        final AtomicReference<WorldExporter.Section> world = new AtomicReference<>();
        final AtomicReference<Overlay> hud = new AtomicReference<>();
        // Render-thread ownership ends when reset replaces this generation.
        int nextTexture = 1;
        // Transfer-thread state never crosses a render instance boundary.
        int transfer;
        TexturePacket pendingTexture;
        WorldExporter.Section sentWorld;
        byte[] worldBytes, previousScene;
        long nextTextureSend, nextWorldSend, tileRevision;
        Overlay previousOverlay;
        final java.util.Map<Integer, TilePixels> tilePixels = new java.util.HashMap<>();
        Generation(String session, String instance) { this.session = session; this.instance = instance; }
    }
    private static volatile Generation generation = new Generation("", "");
    private RenderTransport() {}
    public static String instance() { return generation.instance; }

    public static void reset(String nextSession, String process) {
        generation = new Generation(nextSession, process);
        Textures.reset();
        FrameExporter.reset();
        WorldExporter.reset();
        MeshSnapshots.reset();
    }

    public static int texture(int width, int height, byte[] rgba) {
        var current = generation;
        int id = current.nextTexture++;
        current.textures.add(new TextureUpdate(id, width, height, rgba));
        return id;
    }
    public static void textureUpdate(int id, int width, int height, byte[] rgba) {
        dev.garrycraft.testing.GameplayOracle.texture(id, rgba);
        var current = generation;
        if (current.updates.put(id, new TextureUpdate(id, width, height, rgba)) == null) current.updateOrder.add(id);
    }

    public static byte[] packet(Object header, byte[] body) {
        byte[] prefix = (JSON.toJson(header) + "\n").getBytes(StandardCharsets.UTF_8);
        byte[] result = java.util.Arrays.copyOf(prefix, prefix.length + body.length);
        System.arraycopy(body, 0, result, prefix.length, body.length);
        return result;
    }

    static void scene(AvatarExporter.Scene scene) { generation.scene.set(scene); }
    public static void overlay(int width, int height, long frame, double capturedAt, byte[] rgba) {
        generation.hud.set(new Overlay(width, height, frame, capturedAt, rgba));
    }
    private static byte[] tiles(Generation current, Overlay overlay) {
        var previousOverlay = current.previousOverlay;
        if (previousOverlay != null && overlay.width() == previousOverlay.width() && overlay.height() == previousOverlay.height()
            && Arrays.equals(overlay.rgba(), previousOverlay.rgba())) return null;
        if (previousOverlay == null || overlay.width() != previousOverlay.width() || overlay.height() != previousOverlay.height()) current.tilePixels.clear();
        current.previousOverlay = overlay;
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
            var previous = current.tilePixels.get(key);
            long revision = previous != null && Arrays.equals(previous.rgba(), pixels) ? previous.revision() : ++current.tileRevision;
            current.tilePixels.put(key, new TilePixels(pixels, revision));
            tiles.add(new Tile(x, height - y - h, w, h, body.size(), revision));
            body.writeBytes(pixels);
        }
        return packet(new FrameHeader(current.session, current.instance, width, height, overlay.frame(), overlay.capturedAt(), tiles), body.toByteArray());
    }
    static void world(WorldExporter.Section packet) { generation.world.set(packet); }

    public static void send(Mailbox mailbox, int textureAck, String textureInstance) {
        var current = generation;
        if (!current.instance.equals(textureInstance)) textureAck = 0;
        var texture = current.pendingTexture;
        if (texture != null && texture.id() <= textureAck) texture = null;
        long now = System.nanoTime();
        if (texture == null) {
            var update = current.textures.poll();
            if (update == null) {
                // Animated sprites retain their latest pixels and share transfers in arrival order.
                var id = current.updateOrder.poll();
                if (id != null) update = current.updates.remove(id);
            }
            if (update != null) {
                int transfer = ++current.transfer;
                texture = new TexturePacket(transfer, packet(new TextureHeader(current.session, current.instance,
                    update.id(), transfer, update.width(), update.height()), update.rgba()));
            }
        }
        current.pendingTexture = texture;
        if (current != generation) return;
        if (texture != null && now >= current.nextTextureSend) {
            mailbox.send(4, texture.bytes());
            current.nextTextureSend = now + 20_000_000L;
        }
        var scene = current.scene.getAndSet(null);
        if (scene != null) {
            byte[] bytes = MeshPackets.scene(scene);
            if (current != generation) return;
            if (!Arrays.equals(current.previousScene, bytes)) { current.previousScene = bytes; mailbox.send(5, bytes); }
        }
        var overlay = current.hud.getAndSet(null);
        if (overlay != null) {
            var bytes = tiles(current, overlay);
            if (current != generation) return;
            if (bytes != null) mailbox.send(6, bytes);
        }
        var world = current.world.get();
        if (world != null && now >= current.nextWorldSend) {
            if (world != current.sentWorld) { current.worldBytes = MeshPackets.section(world); current.sentWorld = world; }
            if (current != generation) return;
            mailbox.send(7, current.worldBytes);
            current.nextWorldSend = now + 20_000_000L;
        }
    }
}
