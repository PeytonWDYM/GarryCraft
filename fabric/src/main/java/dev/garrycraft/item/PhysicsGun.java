package dev.garrycraft.item;

import net.fabricmc.fabric.api.creativetab.v1.CreativeModeTabEvents;
import net.minecraft.core.Registry;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.core.registries.Registries;
import net.minecraft.resources.Identifier;
import net.minecraft.resources.ResourceKey;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.CreativeModeTabs;
import net.minecraft.world.item.Item;

/** This inventory item selects Source's installed physics gun. Source owns its props and physics. */
public final class PhysicsGun {
    private static final ResourceKey<Item> KEY = ResourceKey.create(Registries.ITEM,
        Identifier.fromNamespaceAndPath("garrycraft", "physics_gun"));
    public static final Item ITEM = Registry.register(BuiltInRegistries.ITEM, KEY,
        new Item(new Item.Properties().setId(KEY).stacksTo(1)));

    private PhysicsGun() {}

    public static void init() {
        CreativeModeTabEvents.modifyOutputEvent(CreativeModeTabs.TOOLS_AND_UTILITIES)
            .register(output -> output.accept(ITEM));
    }

    public static boolean equipped(Player player) {
        return !player.isDeadOrDying() && !player.isSpectator() && player.getMainHandItem().is(ITEM);
    }
}
