# Package a release

Use PowerShell 7, JDK 25, Visual Studio 2022 C++ tools, and CMake.
Keep release archives and test evidence outside tracked source.

1. Set the version in `fabric/gradle.properties`.
2. Run `tools/Package-Release.ps1 -OutputRoot <new-directory>`.
3. Run `tools/Test-ReleaseInstall.ps1 -Package <zip> -LabPath <marked-lab>`.
4. Run `tools/Test-PlayerLaunch.ps1 -Package <zip>` with Windows PowerShell 5.1.
5. Run `tools/Test-RuntimeSharing.ps1 -RuntimeRoot <installed-test-runtime>`.
6. Start both games in the owned lab with the release's installed runtime.
7. Read the generated results and game logs.
8. Rebase the release branch onto the latest `main` before opening its PR.

The package script runs `Build.ps1`. It includes the Fabric mod, both x64 native modules, Lua, installers, README, license, and notices.
The native modules link the C++ runtime statically, so users need no Visual C++ redistributable installation for these modules.
The generated `release.json` records the source commit, versions, download URLs, checksums, and supported engine identifiers.
The archive excludes Minecraft jars, assets, Java, user settings, game files, and test worlds.
The installer downloads dependencies from their original sources. It uses the versions pinned by the Fabric build.

`Test-ReleaseInstall.ps1` creates a fresh runtime and game fixture for each run.
It disables external download caches and records the clean state in `release-install-result.json`.
It tests repeat installation separately, including preservation of worlds, preferences, and unrelated addons.
For a requested wipe, save the deleted paths and confirm their absence before setup.
Use `Test-PlayerAddons.ps1` with the extracted folder to check real game startup, bridge readiness, and Minecraft shutdown.
Run `Test-NormalLaunch.ps1` against the installed lab to prove that an ordinary launch loads no bridge code or native modules.
Run `Test-Uninstall.ps1` with Windows PowerShell 5.1 against a marked fixture. Include a second drive and custom paths.
Read its removal and preservation results, including installed-entry purge, locked files, ownership, redirects, and moved folders.

Publish `GarryCraft-<version>-windows-x64.zip` and its `.sha256` file with a `v<version>` tag on the tested source commit.
Use the generated `GarryCraft-<version>-release-notes.md` as the release description.
Keep its five installation steps. Do not add a change log.
Do not merge the PR without the user's requested disposition.

## Linux releases

On Linux x64 with JDK 25, CMake, and a C++20 compiler:

1. Build inside the Steam Runtime sniper SDK (`registry.gitlab.steamos.cloud/steamrt/sniper/sdk`).
   GMod loads modules under glibc 2.31, and packaging rejects modules that need newer glibc symbols.
   The C++ runtime is linked statically. Host builds on newer distributions are for local testing only.
2. Optionally pass `--gmod-path <game>` to measure the local Linux engine `.so` files into `release.json` pins.
3. Run `tools/Package-Release.sh --output-root <new-directory>`.
4. Run `tools/Test-ReleaseInstall.sh --package <zip>` for offline package checks.
5. Rerun with `--download` for a runtime-only fixture install with caches disabled, and read `release-install-result.json`.
6. Start both games in the owned lab with the release's installed runtime and read the game logs.

The script runs `tools/Build.sh`. It publishes `GarryCraft-<version>-linux-x64.zip`, its `.sha256`,
and Linux release notes from `docs/RELEASE_NOTES_LINUX.md` with the same five-step rule.
