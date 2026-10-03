package dev.garrycraft.mixin;

import net.minecraft.client.gui.screens.inventory.CreativeModeInventoryScreen;
import net.minecraft.client.gui.components.EditBox;
import net.minecraft.world.item.CreativeModeTab;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.gen.Accessor;
import org.spongepowered.asm.mixin.gen.Invoker;

/** Local input scenarios observe vanilla scrolling and search without replacing their handlers. */
@Mixin(CreativeModeInventoryScreen.class)
public interface CreativeScreenAccessor {
    @Accessor("scrollOffs") float garrycraft$scroll();
    @Accessor("searchBox") EditBox garrycraft$searchBox();
    @Invoker("selectTab") void garrycraft$tab(CreativeModeTab tab);
}
