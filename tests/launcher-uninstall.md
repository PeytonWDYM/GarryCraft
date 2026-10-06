# Launcher isolation and uninstall scenarios

Write these cases before changing startup or uninstall behavior. Use the extracted ZIP and Windows PowerShell 5.1.
Game tests use a marked, separate installation. Record clean runtime and game paths before installation.

| Scenario | Required result |
| --- | --- |
| Launch the installed game normally | GarryCraft is inactive in both Lua realms. Neither native bridge module loads. No Minecraft process starts. |
| Normal launch with an old saved enable setting | The saved setting cannot activate GarryCraft without Play.cmd. Normal weapons and movement remain available. |
| Launch through Play.cmd | GarryCraft starts automatically on a single-player map, with unrelated addons enabled. |
| Disable, change maps, then relaunch normally | The normal session remains inactive. No session opt-in is saved to configuration. |
| Open Play.cmd while GMod is already running | The launcher asks the player to close GMod, instead of silently reusing an ordinary session. |
| Install and uninstall in custom paths with spaces, Unicode, brackets, and another drive | Actual CMD entry points resolve the recorded runtime and game paths without wildcard or shell expansion. |
| Start Minecraft from a runtime path with brackets and Unicode | Java uses the selected mirror world directory. Both output logs exist there and include world save completion. |
| Select a GMod game folder with non-ASCII characters | Setup explains the engine's ASCII game path requirement before downloading or writing files. Unicode player and package folders remain supported. |
| Uninstall from the extracted ZIP or source checkout | Installed addon, native modules, and runtime pointers are removed. GMod and unrelated addons remain. |
| Uninstall from the private player folder | The installed uninstaller works without the extracted ZIP. |
| Default uninstall | Minecraft worlds and shared settings remain. Program files and downloaded dependencies are removed. |
| Uninstall with -Purge | The owned runtime, including its worlds and settings, is removed. The source or extracted package remains. |
| Repeat uninstall | The script reports completion without a missing-file error. |
| Move the extracted ZIP folder after setup | Uninstall still uses its player pointer. |
| Remove the runtime manually before uninstall | The game can be cleaned using its recorded pointer and -GmodPath. No unrelated directory is deleted. |
| Uninstall an older runtime after another runtime owns the game | The active runtime's game payload and pointer remain unchanged. |
| Supply an unmarked directory, drive root, game root, or package root as the runtime | Uninstall rejects it before deleting files. |
| Redirect a runtime child or installed addon through a junction | Uninstall rejects the redirect before deleting files outside the owned installation. |
| Hold a native module open or hold the runtime mutex | Uninstall fails before removing game payload or worlds. Close the game and rerun. |
| Run another GMod installation while testing a marked installer fixture | Installation and uninstall check the selected game path. The unrelated running game remains unchanged. |
| Relocate GMod and pass its new outer folder | Uninstall validates the current game pointer and cleans the new location without engine-version checks. |
| Remove GMod before uninstalling GarryCraft | Uninstall still removes the owned runtime. It does not require the removed game's executable. |
| Reinstall after default uninstall | Preserved worlds and settings retain their contents. Folder launchers work again. |

Save CMD transcripts, game observations, module lists, and JSON results outside tracked source.
