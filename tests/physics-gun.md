# Native physics gun

Write paired Source and Minecraft snapshots under a fresh owned lab run.
Use single-player `gm_construct`, separate Minecraft settings, and a fresh mirror world.
Compare each input sequence with the installed GMod `weapon_physgun` in an equivalent unlinked fixture.
Never change the player's existing worlds. Remove test props and restore inventory after the scenario.

## Failure cases and expected behavior

1. Search for **Physics Gun** in Minecraft's creative inventory. The item has a name and a visible icon.
2. Equip `garrycraft:physics_gun` in the main hand. Source selects the installed `weapon_physgun`.
3. Hold a Minecraft block in the offhand. Gun inputs must not place blocks, mine blocks, or attack Minecraft entities.
4. Pick up a native loose prop with primary fire. Source renders its normal beam and viewmodel.
5. Move and look while holding the prop. Minecraft owns player movement. Source owns the held physics body.
6. Release primary fire. The prop drops with the native gun's release behavior.
7. Hold primary fire and use secondary fire. The native gun freezes the prop.
8. Pick up a frozen prop. The native gun unfreezes and moves it.
9. Use the mouse wheel while holding a prop. The native gun changes distance. The Minecraft hotbar remains selected.
10. Hold Source's bound Use key and move the mouse. The native gun rotates the prop. Minecraft's inventory stays closed.
11. Apply the native rotation snap modifier. Compare the prop's angle with the unlinked reference.
12. Use reload and double reload on frozen props. Compare single-prop and group unfreeze behavior with native GMod.
13. Open Minecraft inventory with I while equipped. Mouse clicks edit inventory and cannot operate the native gun.
14. Close inventory and change to a block with a number key. The native gun drops its held body. Minecraft places blocks normally.
15. Put the gun only in the offhand. Minecraft does not select the native gun.
16. Die, respawn, disconnect, disable the bridge, or replace the session while holding a prop. The native gun releases its body.
17. Reconnect and equip the gun. Old held bodies and old button state cannot return.
18. Test a restricted prop, ragdoll, and native constrained assembly. Native GMod hooks and permissions decide the result.
19. Aim into world geometry or a clear sky ray before the double-reload comparison. Record `HitNonWorld` before sending R.
    A Minecraft section collision entity on the ray is not equivalent to Source world geometry; reject that fixture before input.
    Use the same native floor and clear prop corridor in both passes. Unsettled collisions cannot establish distance parity.

## Evidence

Save the installed gun class, selected Minecraft item, lane 1 `physgunEquipped`, menu state, held body, frozen state,
body position, body angle, Minecraft player pose, input sequence, and cleanup state at each step.
Save screenshots of the creative item, native beam, native viewmodel, and open Minecraft inventory.
Keep these files outside tracked source. Report which native comparison cases ran and which remain unverified.

The bridge equips the actual installed Source weapon. It does not implement another physics gun solver.
Its target set follows that weapon's rules. Detachable Minecraft blocks become separate native bodies; section collision mirrors remain fixed.
Addon weapon replacements and addon permission hooks require separate comparisons.
