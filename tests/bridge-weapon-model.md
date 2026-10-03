# Bridge weapon models

Use an owned single-player lab with the Minecraft physics gun selected.
Save Source console offsets, warning counts, and screenshots outside tracked source.

1. Open Minecraft inventory with the bound inventory key, then close it with Escape.
2. Repeat while Source switches between `weapon_physgun` and `weapon_garrycraft`.
3. Check for `Bad pstudiohdr in GetSequenceLinearMotion()` in the new console output.
4. Install valid hidden bridge weapon models and repeat the same Windows input.

The bridge weapon must have a valid studio header during native animation queries.
Its Source viewmodel and world model must remain hidden during Minecraft play.
The native physics gun must still show its viewmodel, beam, and Minecraft skin arms.
Disable must restore the previous Source weapon without hiding its model.
