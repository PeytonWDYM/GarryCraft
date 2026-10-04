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

## Limits

Lighting still uses one sample per face batch and estimates the sun's share of baked Source irradiance.
Native lightmap tiles update over several frames. Shadows do not update instantly everywhere.
These fixtures do not certify every map, material, player addon, or large-map frame budget.
All fixtures used the separate lab and owned test worlds.
