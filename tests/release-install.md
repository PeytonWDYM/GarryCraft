# V1 installer scenarios

Write these scenarios before the installer. Use Windows PowerShell 5.1 and the actual release ZIP.
Keep each run under a new directory outside tracked source.
Use only a separate game installation with a `.garrycraft-lab` marker for game tests.
Linux scenarios use `bash` and the `GarryCraft-<version>-linux-x64.zip` asset with the same rules.

| Scenario | Required result |
| --- | --- |
| Extract the release into a path with spaces and Unicode | Installation succeeds without build tools or PowerShell 7. |
| Package a release with a relative output folder | The manifest contains paths relative to `payload`, with unchanged native and Fabric payload hashes. |
| Open `Install.cmd` from a source checkout without `release.json` | Setup downloads and verifies the matching release, then forwards the chosen game and runtime paths. |
| Run source setup with a matching compiled ZIP and checksum in `release` | Setup verifies the local ZIP and prepares the folder launcher without requiring a published release. |
| Complete setup from a source checkout | The final Play path points to `Play.cmd` beside the source checkout's `Install.cmd`. |
| Open setup from an incomplete release without source files | Setup explains that the entire release ZIP must be extracted. |
| Inspect the extracted ZIP before setup | `Install.cmd` and `Play.cmd` are beside each other. The internal player launcher template uses `.template`. |
| Open the extracted folder's `Play.cmd` before setup | The launcher exits with setup instructions and the full `Install.cmd` path. It does not print a missing-file error. |
| Open a copied player launcher without `install.json` | The launcher explains that setup is incomplete and asks the player to rerun `Install.cmd`. |
| Open the installed launcher after the game folder moves | The launcher asks the player to rerun setup with the new game folder. |
| Launch the player runtime with an installed addon | GMod loads the addon. The launch command has no `-noworkshop` or `-noaddons` flags. |
| Launch with the lab's default video settings | The player launcher opens in 1920×1080 windowed mode and accepts a map command. |
| Install into a game-shaped fixture with real x64 engine files | Both modules, all Lua files, and the runtime pointer match the package. |
| Run setup again | Existing worlds, preferences, and unrelated addons retain their contents. |
| Complete automatic setup | `Play.cmd` in the same extracted folder launches the installed player runtime, including a custom player path. |
| Prepare runtime-only setup | Setup prints the private player launcher path for use after manual game copies. |
| Wrong game path or missing x64 executable | Setup fails before downloads or game writes and explains Steam's folder selection. |
| Unsupported native engine build | Setup rejects the build and prints the mismatched file. |
| Corrupt a packaged DLL | Setup rejects its checksum before game writes. |
| Lock an installed DLL | Setup restores earlier copies and prints all manual copy destinations. |
| Lock the runtime mutex | Setup fails without changing the runtime or game. |
| Interrupt a download or return a wrong checksum | Setup fails with its URL and destination. Rerun replaces the incomplete file. |
| Prepare without game write access | Runtime-only setup creates a complete manual copy tree and launch instructions. |
| Start the production Fabric runtime | Real Minecraft creates a fresh mirror world, reports ready, then saves and exits. |
| Start both games in the owned lab | The bridge links on `gm_construct`, enables, disables, and exits without errors. |

`tools/Test-ReleaseInstall.ps1` records the package checks and failure cases in `release-install-result.json`.
`tools/Test-RuntimeSharing.ps1` records real Minecraft startup and save behavior in `runtime-sharing-result.json`.
`tools/Test-SourceInstall.ps1` checks the source checkout entry point and saves `source-install-result.json`.
`tools/Test-PlayerLaunch.ps1` checks launcher recovery messages from the extracted ZIP and saves `player-launch-result.json`.
`tools/Test-PlayerAddons.ps1 -LabPath <marked-lab> -RuntimeRoot <player-folder> -PackageRoot <extracted-folder>` tests the folder launcher.
It checks addon loading, bridge readiness, and Minecraft shutdown. It saves `player-addons-result.json` and runtime observations.
Save bridge observations and game logs for the paired game run. Read these files before reporting a pass.

## Linux installer scenarios

The Linux release carries `gmcl_garrycraft_linux64.dll` and `gmsv_garrycraft_linux64.dll`
(ELF shared objects under GMod's Linux module names) beside the same Lua addon.
Setup is `install.sh`; play and uninstall are `play.sh` and `uninstall.sh`.
The private player folder defaults to `$HOME/.local/share/GarryCraft/player`.
Steam libraries resolve from `~/.steam/steam`, `~/.local/share/Steam`, and their
`steamapps/libraryfolders.vdf` files. The private Java runtime is an Adoptium
Linux x64 JRE 25; Minecraft natives filter on `os.name == 'linux'`.

| Scenario | Required result |
| --- | --- |
| Extract the Linux release into a path with spaces and Unicode | `install.sh` succeeds with only `bash`, `curl`, `python3`, `tar`, and `unzip` (plus JDK 25, CMake, and a C++20 compiler for builds). |
| Inspect the extracted Linux ZIP before setup | `install.sh` and `play.sh` are beside each other. No `.cmd` or `.ps1` file is required. |
| Open `play.sh` before setup | The launcher exits with setup instructions and the full `install.sh` path. |
| Install into a game-shaped fixture with Linux engine files | Both `*_linux64.dll` modules, all Lua files, and the runtime pointer match the package. |
| Wrong game path or missing Linux game binary | Setup fails before downloads or game writes and explains Steam's folder selection. |
| Unsupported Linux engine build | Setup rejects the build and prints the mismatched `.so` file and measured identity. |
| Corrupt a packaged `.so` | Setup rejects its checksum before game writes. |
| Run setup again | Existing worlds, preferences, and unrelated addons retain their contents. |
| Prepare runtime-only setup | Setup prints the private player launcher path for use after manual game copies. |
| Start both games in the owned lab | The bridge links on `gm_construct`, enables, disables, and exits without errors. |
| Run the Windows ZIP scenarios | Unchanged: Windows coverage in the table above still passes on Windows. |
| Flatpak Steam (`com.valvesoftware.Steam`) with GMod in a `/mnt` library | Setup finds GMod through `~/.var/app/com.valvesoftware.Steam/.local/share/Steam` and its `libraryfolders.vdf`. |
| Flatpak Steam with no `--install-root` | The player folder defaults to `~/.var/app/com.valvesoftware.Steam/.local/share/GarryCraft/player`, which the sandboxed game can read. |
| Flatpak Steam with an `--install-root` under `~/.local/share` | Setup rejects the folder before downloads and prints the `flatpak override` command. |
| Open `play.sh` with Flatpak Steam and no `steam` command | The launcher requests the session through `flatpak run com.valvesoftware.Steam -applaunch 4000`. |
| Open `play.sh` while Steam is running | Steam's `console_log.txt` shows no `command not found` for `sv_lan`, `maxplayers`, or `exec`, and the GMod command line contains `+exec garrycraft-session.cfg`. |
| Open `play.sh --map gm_construct` | GMod starts `gm_construct` in single-player without the main menu, which fails to load under Flatpak Steam. |
| Start both games through Flatpak Steam | `runtime.sh` starts inside the sandbox, Minecraft starts, and the bridge links on `gm_construct`. |

Linux engine `.so` identities are pinned after the first verified Linux game build
reports them; until then setup checks ELF 64-bit identity plus file size and
SHA-256 against `release.json` and records measured values in the install log.
Native mesh-shadow hooks stay disabled on Linux until their offsets are verified
against real Linux binaries; rendering and gameplay continue without custom mesh
shadows. `tools/Test-ReleaseInstall.sh` mirrors the PowerShell checks and saves
`release-install-result.json` with the same clean-state rules (exact folders,
absent runtime and game payload, `-NoDownloadCache` equivalent first-download run).

## Clean installation evidence

Every clean-install run must record the exact game and runtime folders before setup.
Confirm that the runtime, addon, native modules, and runtime pointer are absent.
Use `-NoDownloadCache` for a first-download test. Record that external cache reuse is disabled in the result.
Report repeat-install checks separately from the clean-install checks.
For a requested wipe, record the deleted GarryCraft paths and confirm their absence before setup.
Keep the deletion record outside the removed installation. Preserve the game itself and unrelated addons.
