# V1 installer scenarios

Write these scenarios before the installer. Use Windows PowerShell 5.1 and the actual release ZIP.
Keep each run under a new directory outside tracked source.
Use only a separate game installation with a `.garrycraft-lab` marker for game tests.

| Scenario | Required result |
| --- | --- |
| Extract the release into a path with spaces and Unicode | Installation succeeds without build tools or PowerShell 7. |
| Open `Install.cmd` from a source checkout without `release.json` | Setup downloads and verifies the matching release, then forwards the chosen game and runtime paths. |
| Open setup from an incomplete release without source files | Setup explains that the entire release ZIP must be extracted. |
| Launch the player runtime with an installed addon | GMod loads the addon. The launch command has no `-noworkshop` or `-noaddons` flags. |
| Launch with the lab's default video settings | The player launcher opens in 1920×1080 windowed mode and accepts a map command. |
| Install into a game-shaped fixture with real x64 engine files | Both modules, all Lua files, and the runtime pointer match the package. |
| Run setup again | Existing worlds, preferences, and unrelated addons retain their contents. |
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
`tools/Test-PlayerAddons.ps1` launches the player runtime in the owned lab and saves `player-addons-result.json`.
Save bridge observations and game logs for the paired game run. Read these files before reporting a pass.
