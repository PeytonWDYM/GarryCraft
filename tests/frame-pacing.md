# Frame pacing

Run `tools/Play-Lab.ps1 -FreshWorld -Test`, then `tools/Collect-Lab.ps1` with its printed run directory.
Record p50, p95, p99, and the maximum frame interval in both games.
The 240 FPS percentile gate requires p99 at or below 4.167 ms. Always report the maximum interval separately.
A passing percentile does not prove every frame met the budget. Report a failed gate when p99 exceeds this budget.

Before implementation, check these failure cases:

1. Temporary startup load permanently lowers the frame cap.
2. A high average hides long frames during cow deaths or TNT explosions.
3. A small HUD change uploads the full window texture.
4. HUD tiles retain stale pixels when the mailbox skips a frame.
5. Each rotating dropped item rebuilds identical geometry every frame.
6. An item instance uses the wrong axis, scale, or matrix layout.
7. A removed item retains a mesh or draws after a resource reload.
8. A fresh test world discards the user's options.
9. Uncapped Minecraft fills the trace buffer before the cow and TNT phases.
10. Source's frame timer clamps a long frame to 100 ms and understates a hitch.
11. A network copy overwrites a newer native camera snapshot and parses the same state twice.

Measure the 15-cow, death, pickup, TNT fuse, explosion, and recovery phases separately.
Compare dropped-item mesh construction counts before and after caching.
Save screenshots of rotating drops and the HUD. Restart with a fresh world and compare the saved options.
