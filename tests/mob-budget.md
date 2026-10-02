# Native NPC target budget

Use a fresh single-player lab world. Run `garrycraft_test_mob_budget`.
The scenario runs the existing entity test and adds 24 frozen, unarmed Source citizens during its fifteen-cow phase.
Each citizen treats the player and Minecraft mobs as hostile. The scenario removes these citizens before the next phase.
The player temporarily uses Source's no-target flag. Test NPCs have no solid collision, so they cannot block another NPC's sight trace.
The scenario restores the player's previous flag after the crowd phase.

Record these failures before implementation:

1. A crowd issues more than 32 target-pair checks or 12 sight traces in one accepted Minecraft tick.
2. The scan cursor never reaches the end of the crowd.
3. Some Source NPCs never select a Minecraft target despite clear sight.
4. Test NPCs or mob bullseyes survive a stop or session change.

Require at least 360 candidate pairs, bounded work, a completed scan, and a mob target for every test NPC.
Count each NPC that selects a mob at least once. Also record the largest simultaneous target count.
Save `garrycraft-mob-budget.json` with the paired entity traces and frame reports.
After the entity test completes, run `garrycraft_test_mob_cleanup` and `tools/Collect-MobBudget.ps1 -RunRoot <directory>`.
Require zero owned bullseyes and zero test NPCs in the cleanup artifact.
The frozen NPCs test target selection. The existing combat phase tests live movement and damage.
