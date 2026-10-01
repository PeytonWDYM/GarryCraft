package dev.garrycraft.render;

import com.mojang.blaze3d.platform.NativeImage;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.texture.TextureAtlasSprite;
import net.minecraft.client.resources.metadata.animation.AnimationMetadataSection;

/** Reads the installed animation metadata. The transport keeps only the newest frame per texture. */
final class SpriteAnimation {
    private record Frame(int index, int duration) {}
    private final int[] pixels;
    private final int imageWidth;
    private final int id, width, height, cycle;
    private final boolean interpolate;
    private final List<Frame> frames;
    private long lastTick = Long.MIN_VALUE;

    SpriteAnimation(int id, TextureAtlasSprite sprite, NativeImage image) {
        this.id = id;
        imageWidth = image.getWidth();
        pixels = new int[imageWidth * image.getHeight()];
        for (int y = 0; y < image.getHeight(); y++) for (int x = 0; x < imageWidth; x++) pixels[y * imageWidth + x] = image.getPixel(x, y);
        width = sprite.contents().width(); height = sprite.contents().height();
        var name = sprite.contents().name().withPath(path -> "textures/" + path + ".png");
        try {
            var metadata = Minecraft.getInstance().getResourceManager().getResource(name).orElseThrow()
                .metadata().getSection(AnimationMetadataSection.TYPE).orElseThrow();
            frames = new ArrayList<>();
            if (metadata.frames().isPresent()) {
                for (var frame : metadata.frames().get()) frames.add(new Frame(frame.index(), frame.timeOr(metadata.defaultFrameTime())));
            } else {
                int count = (image.getWidth() / width) * (image.getHeight() / height);
                for (int i = 0; i < count; i++) frames.add(new Frame(i, metadata.defaultFrameTime()));
            }
            cycle = frames.stream().mapToInt(Frame::duration).sum();
            interpolate = metadata.interpolatedFrames();
        } catch (IOException failure) { throw new IllegalStateException("Cannot read animation " + name, failure); }
    }

    void tick(long tick) {
        if (lastTick == tick) return;
        long previous = lastTick;
        lastTick = tick;
        int time = (int) Math.floorMod(tick, cycle), current = 0;
        while (time >= frames.get(current).duration()) time -= frames.get(current++).duration();
        var frame = frames.get(current);
        if (!interpolate && previous != Long.MIN_VALUE && time != 0) return;
        int next = frames.get((current + 1) % frames.size()).index();
        float fraction = interpolate ? (float) time / frame.duration() : 0;
        int columns = imageWidth / width;
        int ax = frame.index() % columns * width, ay = frame.index() / columns * height;
        int bx = next % columns * width, by = next / columns * height;
        byte[] rgba = new byte[width * height * 4];
        int offset = 0;
        for (int y = 0; y < height; y++) for (int x = 0; x < width; x++) {
            int a = pixels[(ay + y) * imageWidth + ax + x], b = pixels[(by + y) * imageWidth + bx + x];
            for (int shift : new int[]{16, 8, 0, 24})
                rgba[offset++] = (byte) Math.round(((a >>> shift) & 255) * (1 - fraction) + ((b >>> shift) & 255) * fraction);
        }
        RenderTransport.textureUpdate(id, width, height, rgba);
    }
}
