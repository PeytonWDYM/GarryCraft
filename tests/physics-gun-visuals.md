# Physics gun visual checks

Use the marked single-player lab and a fresh owned Minecraft world. Save screenshots and reports outside tracked source.

1. Give the player `garrycraft:physics_gun`. Select it in first person.
2. Capture an idle screenshot. Confirm the installed Source gun appears once with two Minecraft skin arms.
3. Hold a prop. Turn, change distance, rotate with E, and freeze it. Capture the beam and both grips.
4. Confirm both grips follow the gun animation during pickup and release.
   Confirm the right hand touches the rear grip and remains visible above the hotbar during turns.
   Save separate idle, pickup, and release screenshots with the native gun bone and hand-tip report.
5. Change between wide and slim Minecraft skins. Confirm the arm textures and widths match each skin.
6. Put a totem in the offhand and switch to third person. Capture the Minecraft avatar with both hands supporting the installed cyan physics gun.
   Confirm the gun's skin, materials, and glow match the native Source physics gun. The held totem must disappear while its inventory slot stays occupied.
   Change the main arm to left, repeat, and then select a sword. Confirm the offhand item returns with the normal item pose.
7. Switch to a sword and then empty hands. Confirm Minecraft restores its normal arms and item meshes.
8. Open inventory, reload resources, disable the bridge, and reconnect. Confirm no duplicate arms or retained gun models.
9. Read `garrycraft-native-items.json`. Confirm hand bones, arm mesh counts, and runtime model references.

The addon references the user's installed Source models at runtime. It does not distribute Valve models or textures.
This scenario checks the default installed physics gun. Custom viewmodels require a separate check.
