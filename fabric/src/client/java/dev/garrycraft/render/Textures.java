package dev.garrycraft.render;

import com.mojang.blaze3d.platform.NativeImage;
import dev.garrycraft.GarryCraftClient;
import dev.garrycraft.mixin.SpriteContentsAccessor;
import dev.garrycraft.mixin.TextureAtlasAccessor;
import dev.garrycraft.mixin.TextureManagerAccessor;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.texture.DynamicTexture;
import net.minecraft.client.renderer.texture.TextureAtlas;
import net.minecraft.client.renderer.texture.TextureAtlasSprite;
import net.minecraft.resources.Identifier;

/** Reads the installed resources and runtime skin. Each block/item sprite has its own small host texture. */
final class Textures {
    private static final Map<String, Integer> IDS = new HashMap<>();
    private Textures() {}
    static void reset() { IDS.clear(); }

    static int sprite(TextureAtlasSprite sprite) {
        String key = "sprite:" + sprite.contents().name();
        return IDS.computeIfAbsent(key, ignored -> {
            var pixels = ((SpriteContentsAccessor) sprite.contents()).garrycraft$originalImage();
            return send(pixels, sprite.contents().width(), sprite.contents().height());
        });
    }

    static TextureAtlasSprite spriteAt(Identifier atlasName, float u, float v) {
        var registered = ((TextureManagerAccessor) Minecraft.getInstance().getTextureManager()).garrycraft$byPath();
        var atlas = (TextureAtlasAccessor) registered.get(atlasName);
        for (var sprite : atlas.garrycraft$sprites().values()) {
            if (u >= sprite.getU0() && u <= sprite.getU1() && v >= sprite.getV0() && v <= sprite.getV1()) return sprite;
        }
        throw new IllegalStateException("No sprite at " + atlasName + " " + u + "," + v);
    }

    static int resource(Identifier location) {
        return IDS.computeIfAbsent(location.toString(), ignored -> {
            var mc = Minecraft.getInstance();
            var resource = mc.getResourceManager().getResource(location);
            if (resource.isPresent()) {
                try (var stream = resource.get().open(); var image = NativeImage.read(stream)) {
                    return send(image, image.getWidth(), image.getHeight());
                } catch (IOException error) { throw new IllegalStateException("Cannot read " + location, error); }
            }
            var texture = ((TextureManagerAccessor) mc.getTextureManager()).garrycraft$byPath().get(location);
            if (texture instanceof DynamicTexture dynamic && dynamic.getPixels() != null) {
                var image = dynamic.getPixels();
                return send(image, image.getWidth(), image.getHeight());
            }
            if (texture instanceof TextureAtlas atlas) {
                var accessor = (TextureAtlasAccessor) atlas;
                int width = accessor.garrycraft$width(), height = accessor.garrycraft$height();
                try (var image = new NativeImage(width, height, true)) {
                    for (var sprite : accessor.garrycraft$sprites().values()) {
                        var source = ((SpriteContentsAccessor) sprite.contents()).garrycraft$originalImage();
                        int ox = Math.round(sprite.getU0() * width), oy = Math.round(sprite.getV0() * height);
                        for (int y = 0; y < sprite.contents().height(); y++) for (int x = 0; x < sprite.contents().width(); x++) {
                            image.setPixel(ox + x, oy + y, source.getPixel(x, y));
                        }
                    }
                    return send(image, width, height);
                }
            }
            GarryCraftClient.LOG.warn("Cannot export runtime texture {}", location);
            return -1;
        });
    }

    private static int send(NativeImage image, int width, int height) {
        byte[] rgba = new byte[width * height * 4];
        int offset = 0;
        for (int y = 0; y < height; y++) for (int x = 0; x < width; x++) {
            int argb = image.getPixel(x, y);
            rgba[offset++] = (byte) (argb >> 16);
            rgba[offset++] = (byte) (argb >> 8);
            rgba[offset++] = (byte) argb;
            rgba[offset++] = (byte) (argb >>> 24);
        }
        return RenderTransport.texture(width, height, rgba);
    }
}
