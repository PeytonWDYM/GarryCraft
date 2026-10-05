# Install and recover GarryCraft V1

Use Windows 10 or 11 on an Intel or AMD x64 processor. Use single-player 64-bit Garry's Mod.
Own Garry's Mod and Minecraft Java Edition. Setup needs internet access for its first run.
Allow about 2 GB for the runtime and downloads, plus space for worlds and backups.

## Automatic setup

1. Select **Garry's Mod > Properties > Betas > x86-64** in Steam.
2. Wait for Steam to complete the update.
3. Close Garry's Mod.
4. Extract the entire release ZIP.
5. Open `Install.cmd`.

Setup checks the package, detects Steam libraries, and downloads pinned dependencies with checksum verification.
Setup installs its private Java 25 runtime without changing `JAVA_HOME` or `PATH`.
It preserves existing worlds, preferences, and unrelated addons when you rerun it.
It saves replaced game files under the player installation's `backups` directory.

Open the printed `Play.cmd` path after setup. Keep Steam open with your Garry's Mod license available.
Select **Start New Game > Sandbox > gm_construct > Single Player**.
Minecraft starts automatically. Its first start can take longer while it creates the mirror world.
The control panel shows startup and save status.

## Select a folder explicitly

In Steam, select **Garry's Mod > Properties > Installed Files > Browse**.
Use that outer folder, such as `D:\SteamLibrary\steamapps\common\GarrysMod`.
Do not select its inner `garrysmod` folder.

From PowerShell in the extracted release folder:

```powershell
.\Install.cmd -GmodPath "D:\SteamLibrary\steamapps\common\GarrysMod"
```

To select a new player installation location:

```powershell
.\Install.cmd -GmodPath "D:\SteamLibrary\steamapps\common\GarrysMod" -InstallRoot "D:\GarryCraft"
```

Use a new directory or an existing marked GarryCraft player installation.
Setup resolves redirected Windows paths and prints the actual paths used by both games.

## Files and settings

| Location | Contents |
| --- | --- |
| `<GMod>\garrysmod\addons\garrycraft\lua` | GarryCraft Lua addon |
| `<GMod>\garrysmod\lua\bin` | `gmcl_garrycraft_win64.dll` and `gmsv_garrycraft_win64.dll` |
| `<GMod>\garrysmod\data\garrycraft-runtime.json` | Path to the private Minecraft runtime |
| `<Player>\minecraft\mods` | GarryCraft and Fabric API jars |
| `<Player>\java`, `libraries`, `versions`, `assets` | Private Java and downloaded Minecraft dependencies |
| `<Player>\worlds\<map>\minecraft` | Separate game directory and mirror save for each GMod map |
| `<Player>\settings\options.txt` | Shared preferences for GarryCraft's mirror worlds |

`<Player>` defaults to `%LOCALAPPDATA%\GarryCraft\player`.
Fabric loads the two jars in `minecraft\mods` through the generated Java argument file.
Normal Minecraft saves and launcher profiles remain separate. Setup never asks for account credentials.
V1 uses a local `GarryCraft` player identity and has no multiplayer support.

The player launcher uses `-insecure -novid +sv_lan 1 +maxplayers 1`.
The bridge selects a 240 FPS Source cap while active and restores previous caps when disabled.
New mirror preferences use Unlimited FPS. Existing preferences remain unchanged.
Keep normal GMod video settings. Native rendering requires the supported engine builds below.

## Supported engine builds

V1's native texture and shadow adapters require these Windows x64 PE identifiers from `native/src/sdkcompat.hpp`.
Setup checks all four files under `<GMod>\bin\win64` before it writes game files.

| File | Timestamp | Image size | Checksum |
| --- | --- | --- | --- |
| `client.dll` | `0x6ab2b438` | `0xb78000` | `0x9ba819` |
| `engine.dll` | `0x6ab2b381` | `0xe52000` | `0x572c76` |
| `studiorender.dll` | `0x6aa9c7cb` | `0x835000` | `0xe281d` |
| `materialsystem.dll` | `0x6aa9c7a1` | `0x2151000` | `0x128def` |

Selecting x86-64 does not guarantee these identifiers after a Steam update.
If setup reports an unsupported build, use a matching GarryCraft release. Do not replace engine DLLs with downloaded copies.

## Installation failures

| Message or symptom | Recovery |
| --- | --- |
| Cannot find `bin\win64\gmod.exe` | Select Steam's x86-64 branch. Wait for its update. Select the outer game folder. |
| Multiple Steam installations | Paste the intended game folder into the prompt, or pass `-GmodPath`. |
| Unsupported engine build | Read the reported DLL path and the table above. A newer game build needs a compatible GarryCraft release. |
| Package checksum failed | Download the release ZIP again and extract the entire archive. |
| Download failed | Read the printed URL and destination. Check internet access and disk space, then rerun setup. |
| Access denied or locked game file | Close GMod. Use a writable installation, or follow the printed manual copy paths. |
| Minecraft still running or saving | Wait for Minecraft to save and exit before rerunning setup. Read its logs if it remains active. |
| Setup window disappears | Run `Install.cmd` from a terminal to retain the error text. |
| Runtime location moved | Rerun setup with `-InstallRoot` and the correct `-GmodPath` to rebuild absolute paths. |
| Realms or user-properties authentication errors | V1 uses a local identity. These online-service messages do not prevent its single-player mirror world from starting. |

Failed downloads do not become verified files. Reruns reuse downloads that pass checksum checks.
If a game copy fails, setup restores replaced files and retains backups.
If Windows blocks restoration, setup prints the backup and destination that need manual restoration.

## Manual copy

To prepare Minecraft without writing game files:

```powershell
.\Install.cmd -GmodPath "D:\SteamLibrary\steamapps\common\GarrysMod" -RuntimeOnly
```

Setup prints complete source and destination paths. Keep the private runtime in its selected location.

1. Close Garry's Mod.
2. Copy `<Player>\manual\garrysmod\addons\garrycraft` into `<GMod>\garrysmod\addons\garrycraft`.
3. Copy both DLLs from `<Player>\manual\garrysmod\lua\bin` into `<GMod>\garrysmod\lua\bin`.
4. Copy `<Player>\manual\garrysmod\data\garrycraft-runtime.json` into `<GMod>\garrysmod\data`.
5. Open `<Player>\Play.cmd`.

The Minecraft mods are already installed. Do not copy them into your normal `.minecraft\mods` folder.
If setup failed before Minecraft preparation completed, correct the reported error and rerun it before manual copying.

## Runtime failures and logs

| Log | Purpose |
| --- | --- |
| `<Player>\install-*.log` | Installation transcript |
| `<Player>\launcher-*.log` | Minecraft startup, map changes, and shutdown |
| `<Player>\worlds\<map>\minecraft-stderr.log` | Java errors |
| `<Player>\worlds\<map>\minecraft-stdout.log` | Minecraft startup and save output |
| `<Player>\worlds\<map>\minecraft\logs\latest.log` | Fabric and Minecraft details |
| `<Player>\worlds\<map>\minecraft\crash-reports` | Minecraft crash reports |

For missing modules, rerun setup with the correct game folder and start the x64 executable through `Play.cmd`.
For startup failures, try Sandbox on `gm_construct` with conflicting Workshop addons disabled.
For a stalled save, read the logs before restarting. The helper waits for a safe save instead of killing Java.
Include the setup version, reported engine file, and relevant log when you [report an issue](https://github.com/PeytonWDYM/GarryCraft/issues).

## Remove or restore

1. Disable GarryCraft through its control panel.
2. Wait for Minecraft to save and exit.
3. Close Garry's Mod.
4. Remove only the `garrycraft` addon folder, both GarryCraft DLLs, and `garrycraft-runtime.json` from the game paths above.

If setup replaced a previous GarryCraft installation, restore its files from the corresponding backup instead.
Keep the player folder to retain mirror saves. Copy `worlds` and `settings` elsewhere before deleting that folder.

## Download sources

Setup downloads game dependencies locally. The ZIP contains project code and installation scripts, without Minecraft or Valve game files.
See [Minecraft's EULA](https://www.minecraft.net/en-us/eula), [Fabric](https://fabricmc.net), and [Eclipse Adoptium](https://adoptium.net).
See [Facepunch's branch instructions](https://wiki.facepunch.com/gmod/Dev_Branch) for Steam's branch controls.
