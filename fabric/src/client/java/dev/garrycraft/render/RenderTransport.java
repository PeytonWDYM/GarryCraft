package dev.garrycraft.render;

import com.google.gson.Gson;
import dev.garrycraft.bridge.Mailbox;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.atomic.AtomicReference;
import java.util.Arrays;

/** Texture transfers require acknowledgement. Poses and overlay frames retain only the newest snapshot. */
public final class RenderTransport {
    private static final Gson JSON = new Gson();
    private static final ConcurrentLinkedQueue<TexturePacket> TEXTURES = new ConcurrentLinkedQueue<>();
    private static final AtomicReference<byte[]> SCENE = new AtomicReference<>();
    private static final AtomicReference<byte[]> OVERLAY = new AtomicReference<>();
    private static String session = "";
    private static String instance = "";
    private static int nextTexture = 1;
    private static long nextTextureSend;
    private static byte[] previousScene;
    private record TexturePacket(int id, byte[] bytes) {}
    private record TextureHeader(String session, String instance, int id, int width, int height) {}
    public record FrameHeader(String session, String instance, int width, int height, long frame) {}
    private RenderTransport() {}

    public static void reset(String nextSession, String process) {
        session = nextSession;
        instance = process;
        TEXTURES.clear();
        SCENE.set(null);
        OVERLAY.set(null);
        nextTexture = 1;
        previousScene = null;
        Textures.reset();
        FrameExporter.reset();
    }

    public static int texture(int width, int height, byte[] rgba) {
        int id = nextTexture++;
        TEXTURES.add(new TexturePacket(id, packet(new TextureHeader(session, instance, id, width, height), rgba)));
        return id;
    }

    public static byte[] packet(Object header, byte[] body) {
        byte[] prefix = (JSON.toJson(header) + "\n").getBytes(StandardCharsets.UTF_8);
        byte[] result = java.util.Arrays.copyOf(prefix, prefix.length + body.length);
        System.arraycopy(body, 0, result, prefix.length, body.length);
        return result;
    }

    public static void scene(Object scene) {
        byte[] bytes = JSON.toJson(scene).getBytes(StandardCharsets.UTF_8);
        if (!Arrays.equals(previousScene, bytes)) {
            previousScene = bytes;
            SCENE.set(bytes);
        }
    }
    public static void overlay(int width, int height, long frame, byte[] rgba) {
        OVERLAY.set(packet(new FrameHeader(session, instance, width, height, frame), rgba));
    }

    public static void send(Mailbox mailbox, int textureAck, String textureInstance) {
        if (!instance.equals(textureInstance)) textureAck = 0;
        var texture = TEXTURES.peek();
        while (texture != null && texture.id() <= textureAck) {
            TEXTURES.poll();
            texture = TEXTURES.peek();
        }
        long now = System.nanoTime();
        if (texture != null && now >= nextTextureSend) {
            mailbox.send(4, texture.bytes());
            nextTextureSend = now + 100_000_000L;
        }
        var scene = SCENE.getAndSet(null);
        if (scene != null) mailbox.send(5, scene);
        var overlay = OVERLAY.getAndSet(null);
        if (overlay != null) mailbox.send(6, overlay);
    }
}
