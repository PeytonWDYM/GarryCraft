# Managed shutdown with an acquired render surface

Use an owned single-player lab, separate settings, and a fresh Minecraft world.
Write this scenario before the lifecycle fix. Root runs the live games and saves artifacts outside tracked source.

## Failure to detect

Minecraft 26.3 renders progress frames during disconnect after clearing its client level.
The player and the last block hit can remain available during those frames.
Bridge physics-gun target publication must not read that cleared level after acquiring the render surface.
An export exception can skip vanilla presentation. Final cleanup then reports `Cannot close a surface while it is acquired`.
Moving or suppressing that close exception does not preserve the world-save path.

## Cases

1. Start a linked manual runtime with its normal managed shutdown control file.
2. Place an identifiable block and save a named item in a chest. Record their cells and inventory data.
3. Equip `garrycraft:physics_gun` and aim at a solid Minecraft block without detaching it.
4. Record lane 1 `physgunEquipped` and `physicsBlockTarget`. Keep the player and the last block hit available.
5. Atomically replace the existing control file with `stop: true` through the normal runtime control path.
6. Wait for normal Java exit. Save its exit code, stdout, latest log, crash-report list, and final world metadata.
7. Restart the same owned world. Confirm the placed block, named chest item, and saved options remain intact.
8. Repeat with a detached container block. Confirm shutdown restores its original cell and complete block entity data.
9. Repeat with a replacement block occupying the original cell. Preserve that block and the unresolved recovery journal.
10. Repeat with ordinary Minecraft hands and while its inventory screen is open.

The gun-target case exercises the cleared-level publication path. The ordinary-item and menu cases check the normal save lifecycle.
Detached-block cases require the existing [recovery scenarios](physics-blocks.md), including the journal phase and conflict record.

## Artifact

Write one result JSON with each case, session, selected item, target cell, shutdown request time, process exit, and restored world checks.
Include paths to both games' state, shutdown logs, options before and after, and journal records.
A successful case saves the world and exits without a new client crash or `Shutdown failure!`.
Record missing cases explicitly. A clean process exit alone does not prove world or journal preservation.
