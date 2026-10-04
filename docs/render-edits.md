# Block edits and physics gun arms

The October 4 fix draws Minecraft arms from an owned, installed citizen support skeleton.
It does not depend on the selected Source player model's hands entity.
The skeleton survives hotbar switches and retires when the bridge stops.

Native mesh construction chooses a real triangle near each face batch's center for its lighting probe.
This avoids solid cells in concave gaps and the first triangle's preference for low corners.
Block edits prioritize neighboring sections. Geometry allows up to two ticks for pending light propagation.
Light-only callbacks reuse nearby geometry. The cache evicts sections outside the export range.

The native module records bounded light and occluder change regions.
Cached sun rays and native lightmap receivers retain results when those regions cannot affect them.
Native uploads retain their existing frame budgets.

The later October 4 hitch fix retains unchanged section mesh batches and their Source model and shadow ownership.
The transport worker merges touching collision boxes with identical perpendicular spans.
Source retains the resulting physics bodies when only lighting changes.
Nearby section scans use a 0.25 ms scheduling target across frames.

The launcher also retains its last complete Source heartbeat through temporary file read failures.
Source rewrites that JSON in place. Reading an empty file previously ordered Minecraft to save and exit.
Failed reads do not extend the existing 120-second heartbeat deadline.
Logs now state why the launcher stops Minecraft.

## Verification

Run `tools/Build.ps1` with Java 25. Use a separate, marked single-player lab and a fresh Minecraft world.
Run `Test-RenderEdits.ps1`, `Test-PhysgunViewmodel.ps1 -MissingSourceHands`, and the receiver, directional, and density scripts.
Each script accepts `-GamePid`, `-LabPath`, and `-RunRoot`. Read its JSON traces and PNGs.

Artifacts: `%LOCALAPPDATA%/GarryCraft/render-edits-verified/20261004-081413/artifacts`.
The candidate passed six edit checks, 14 missing-hands checks, 31 receiver checks, 11 directional checks, and seven density checks.
All 5,972 edit frames had exterior probes. Arms drew in all 2,145 active input frames.
Density baseline P99 was 5.855 ms. Steady P99 was 5.761 ms. The maximum frame interval was 11.296 ms.
The largest lightmap update was 4.555 ms. These timings exclude startup.

The linked Downtown map imported 234,050 collision triangles and 1,836 static props.
The eight-second performance phases passed with zero and 32 awake test props.
Source frame P99 was 5.899 ms and 6.869 ms. Maximum intervals were 18.660 ms and 29.702 ms.
This is candidate coverage, without a matched pre-fix Downtown timing comparison.
The lab lacks assets for 52 static props, which limits its geometry coverage.

Review follow-up artifacts: `%LOCALAPPDATA%/GarryCraft/render-review-verified/20261004-084126/artifacts`.
The mixed-direction probe checks failed in all three coordinate spaces before the fix.
The native mesh fixture then passed all 15 checks, including public/native pixel comparisons.
The edit fixture passed seven checks, including a torch lighting change on matching faces.
Both physics gun passes passed 14 checks after the shared pose and texture readiness changes.

Hitch artifacts: `%LOCALAPPDATA%/GarryCraft/frame-hitches-baseline/20261004-115434/artifacts` and
`%LOCALAPPDATA%/GarryCraft/frame-hitches-candidate/20261004-120406/artifacts`.
The paired edit maximum fell from 33.152 ms to 9.915 ms. Frames above 16.667 ms fell from 13 to zero.
Edit P99 was 6.137 ms before and 5.902 ms afterward. Idle P99 was 5.678 ms before and 5.467 ms afterward.
The collision fixture passed all seven checks, including slab and stair heights, holes, and retained bodies during torch updates.
The rapid input fixture passed all six checks with the lab's native floor at Minecraft Y -12.
The Warden stress case completed 120 path requests and removed its owned mob.
An initial rapid input run used Y -6, above the native floor. It did not exercise placement and does not count as a pass.

Shutdown artifacts: `%LOCALAPPDATA%/GarryCraft/heartbeat-baseline-20261004` and `heartbeat-candidate-20261004`.
An empty heartbeat caused the original launcher to stop real Minecraft in a fresh world.
The candidate passed all 12 sharing and heartbeat checks with one Minecraft process, then saved and exited on explicit Disable.
This reproduces a shutdown that matches the reported 10:55 log. The old log does not record its precise shutdown trigger.

CMD artifacts: `%LOCALAPPDATA%/GarryCraft/cmd-hitches-final/20261004-122330`.
The copied repository CMD launched a fresh linked world and passed all seven collision checks.
Explicit Disable saved and stopped Minecraft. Both launcher and Minecraft logs recorded the shutdown reason.
The authorized daily build now uses matching Java classes, Lua files, and launcher scripts.
Its shortcut keeps the existing world and settings paths.

## Limits

Lighting still uses one sample per face batch and estimates the sun's share of baked Source irradiance.
Native lightmap tiles update over several frames. Shadows do not update instantly everywhere.
These fixtures do not certify every map, material, player addon, or large-map frame budget.
All fixtures used the separate lab and owned test worlds.
