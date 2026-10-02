package dev.garrycraft.mixin;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import net.minecraft.client.Options;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.ModifyArg;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

/** All owned mirror worlds share one options file. World resets keep the user's settings. */
@Mixin(Options.class)
public abstract class MirrorSettingsMixin {
    @ModifyArg(method = "<init>", at = @At(value = "INVOKE",
        target = "Ljava/io/File;<init>(Ljava/io/File;Ljava/lang/String;)V"), index = 0)
    private File garrycraft$settings(File runDirectory) {
        if (!Boolean.getBoolean("garrycraft.autoWorld")) return runDirectory;
        Path directory = Path.of(System.getProperty("garrycraft.settings", System.getenv("LOCALAPPDATA") + "/GarryCraft/settings"));
        try {
            Files.createDirectories(directory);
            Path saved = directory.resolve("options.txt"), current = runDirectory.toPath().resolve("options.txt");
            if (!Files.exists(saved) && Files.exists(current)) Files.copy(current, saved);
        } catch (IOException failure) { throw new IllegalStateException("Cannot preserve mirror settings", failure); }
        return directory.toFile();
    }
    @Inject(method = "load", at = @At("RETURN"))
    private void garrycraft$unlimitedDefault(CallbackInfo callback) {
        var options = (Options) (Object) this;
        if (Boolean.getBoolean("garrycraft.autoWorld") && !options.getFile().exists())
            options.framerateLimit().set(Options.UNLIMITED_FRAMERATE_CUTOFF);
    }
}
