# Startup and stability scenarios

Write evidence under an owned run directory. Use single-player and a marked Source lab.

1. Run the entity scenario, then leave normal play active for at least 30 seconds. The citizen and both test props must disappear.
   Repeat with the 24-citizen crowd. Test citizens cannot join the player squad. Save the cleanup counts and crash dump analysis.
2. Prepare the runtime once, then launch GMod without Gradle or a separate Minecraft command.
   Enter `gm_construct`. Wait for geometry and player state. Record the Java PID, world path, and launch status.
3. Issue repeated enable commands. Exactly one managed Java process must run.
4. Place a block and change a Minecraft option. Disable GarryCraft. Verify ordinary movement, the previous weapon,
   frame limits, no bridge bullseyes, no block colliders, and no menu input panel. Minecraft must save and exit.
5. Enable again. The same map must reopen its saved world and settings.
6. Change to `gm_flatgrass`, then return to `gm_construct`. Each map must export collision data and retain a separate world.
7. Disconnect during startup, reconnect, then exit GMod. No managed Minecraft process may remain.
8. Remove the runtime configuration and enable. GMod must stay usable and show a setup error.
9. Run an installed addon in the lab with GarryCraft off, then on. Record the tested addon and map names.

Failure cases include duplicate launches, stale status files, lost world saves, startup timeouts, map changes during saves,
an orphaned Java process after a host crash, and partial player changes after collision export fails.
Pause the map heartbeat for 25 seconds while keeping the host alive, then resume it.
The same Java process must remain active. Video initialization must not start another world writer.
These cases do not certify all maps or addons.

## Minecraft stalls

Use a fresh owned world and an isolated Source installation. Suspend only the managed Java process for eight seconds.
Source must retain the bridge and the launcher must leave the shutdown request false.
Resume Java. The same process and session must resume player state without another collision export or world restart.
Disable must still save and exit normally. Save process IDs and Source snapshots before, during, and after the stall.
Run `tools/Test-Stall.ps1 -LabPath <lab> -RuntimeRoot <prepared-runtime>` to collect `stall-result.json`.

## Shared runtime files

Run the launcher with a fresh owned world and separate settings. Hold its status file open without delete sharing before Minecraft is ready.
Keep the file open for five seconds after the ready marker appears. The launcher and the same Java process must remain alive.
The old status must remain valid JSON. Releasing the reader must publish the pending ready status.
An unchanged ready status must retain its modification time. It must not create repeated rename races.
Hold the shutdown control file open while requesting Disable. The launcher must keep ownership until it can send the save request.
Release the reader and verify normal save and exit with no orphaned Java process.
Save the process IDs, checks, launcher log, and Minecraft log as a repeatable artifact.
