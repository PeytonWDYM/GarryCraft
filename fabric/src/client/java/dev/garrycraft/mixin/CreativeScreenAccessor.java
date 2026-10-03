package dev.garrycraft.mixin;

import net.minecraft.client.gui.screens.inventory.CreativeModeInventoryScreen;
import net.minecraft.world.item.CreativeModeTab;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.gen.Accessor;
import org.spongepowered.asm.mixin.gen.Invoker;

/** The local responsiveness scenario observes vanilla scrolling without replacing its handlers. */
@Mixin(CreativeModeInventoryScreen.class)
public interface CreativeScreenAccessor {
    @Accessor("searchBox") net.minecraft.client.gui.components.EditBox garrycraft$searchBox();
    @Accessor("scrollOffs") float garrycraft$scroll();
    @Invoker("selectTab") void garrycraft$tab(CreativeModeTab tab);
}
