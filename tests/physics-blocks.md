# Physics gun block scenarios

Run these cases in a fresh, owned single-player world. Use Windows keyboard and mouse input for gun controls.
Save both games' state, screenshots, and the recovery journal after each case.

1. Place dirt, a bottom slab, stairs, glass, and a chest with named items. Hold primary fire on each block.
   The section collision entity must stay fixed. One separate Source physics body must replace the selected Minecraft block.
   Repeat on all six faces, at negative grid coordinates, and beside an air cell. The selected cell must match the visible block.
2. Keep primary fire held during transfer. Move, rotate with Source's bound Use key, snap with Shift, change distance, and freeze with secondary fire.
   Source's installed physics gun must control the body. Minecraft player collision must follow its current Source transform.
3. Repeat a request and skip lane 1 frames. There must be one body, one journal entry, and no duplicate block or item drops.
4. Change hotbar slots or open inventory while transfer is pending. A cancelled transfer must leave the original block intact.
   Switch from Survival or Creative to Adventure during model capture or the journal write.
   Final permission checks must reject the transfer without removing the block or spawning a Source body.
5. Reset video while holding a block. The same server body must retain its transform and obtain the new render generation's mesh.
6. Disable the bridge with loose and frozen blocks. Each block and its block entity must return to its original cell.
   The chest's named items and counts must match. Source must remove all owned detached bodies.
7. Stop Minecraft normally and restart it after a detach. Repeat with an abrupt owned process exit.
   Recovery must restore the saved block before new detach requests can run.
8. Put a different block in a detached block's original cell, then disable. Recovery must preserve the new block.
    The journal must retain the detached block and report the occupied cell. Clear that cell and restart to finish recovery.
    Repeat with identical dirt. Matching state does not prove that the original detached block has returned.
9. Try an air cell, a stale session, an old render instance, a distant cell, and a forbidden block.
   Minecraft must reject each request without changing the world. Rejected IDs must still receive a result.
   Lower Source's `physgun_maxrange`. A block beyond that distance must receive no detach request.
10. Detach a waterlogged block and a block entity. No loot must drop during removal.
    Restore the full block state, fluid state, and block entity data on shutdown.
11. Detach dirt, stone, and a chest with named items. Select a normal Minecraft item, then hold attack.
    Compare break ticks with vanilla Minecraft using the same tool, game mode, effects, and grounded state.
    Use a hand, the correct pickaxe, the wrong tool, and an enchanted tool. Verify durability and exact loot.
12. Mine a moved and rotated detached block. Sounds, particles, cracks, and drops must follow the Source body.
    Release attack, change tools, move out of reach, and aim away. Each action must cancel the old progress.
13. Mine detached dirt and the named chest in creative mode. Break them instantly and emit no block loot.
    Disable and restart afterward. The consumed blocks must not return from their recovery journals.
14. Occupy the original and destination cells before mining. Neither cell may change or flash during mining.
    Break the named chest once. Its contents must drop once and must not return after bridge stop or restart.
15. Skip and repeat mining input frames. Break one body once, then replay the old target and request.
    No second loot, duplicate body, or restored block may appear. Save the consumption journal and item entity UUIDs.
16. Stop an owned game process before and after the durable mining commit. Restart the same owned test world.
    An uncommitted break must retain its block. A committed break must retain its loot and must not restore its block.
    Deny the journal replacement before the mining commit. Record mined-block statistics, exhaustion, tool damage, and loot beforehand.
    The failed commit must leave each recorded value unchanged. The detached body must remain available for another attempt.
    Hold a journal file open to deny deletion after delivery. Pick up the loot, then restart.
    A delivered journal must not emit that loot again. Save its phase and the player's inventory before and after restart.

Record the native held entity class, entity creation ID, local collision convexes, position, angles, and motion state.
Record the Minecraft request ID, result, section sequence, original block state, and recovered journal count.
Do not report block parity from prop-only physics gun tests.
