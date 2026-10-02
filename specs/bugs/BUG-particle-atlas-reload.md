# Particle atlas reload

## Reproduce

The updated launcher linked on a fresh single-player `gm_flatgrass` world.
A manual resource reload changed the block atlas from 4096x4096 to 8192x4096.
The next frame failed in `Textures.spriteAt`, called by `ParticleExporter`.
The crash report remains outside source in `runtime-update/main-a835199/artifacts/particle-crash.txt`.

## Isolate

Extracted particle quads retain their sprite coordinates. Atlas quads look up those coordinates in the current atlas.
The crash occurred immediately after the atlas upload. The old coordinates no longer locate a sprite.

## Hypothesize

1. Cached particle quads outlive their atlas layout. Reload with long-lived block particles to reproduce.
2. Ordinary particle UV conversion is wrong. Render the same particles before reload to falsify this alternative.

## Verify

Run the owned `garrycraft_test reload` scenario before the fix. Require exported particles before reload.
Change mipmap packing with live terrain particles, then reload resources.
After the fix, require changed atlas dimensions, removal of stale particles, and new exported particles after reload.
Restore the saved mipmap option and reload again. Save paired Minecraft and Source traces outside tracked source.
Cancel by switching to another scenario. Restore and save the original mipmap setting before that scenario runs.
Wait for the restoration reload before a new reload scenario captures its state.

The first scripted run exposed a test-report parsing error. Minecraft reports particle counts with type labels.
The corrected scenario keeps those labels and pauses the menu during reload, as in the original crash.
`particle-baseline2` reproduced the original sprite lookup crash with actual atlas resizing.
Clearing only extracted quads still crashed on restoration in `particle-final`.
Vanilla's separate particle listener cannot guarantee cleanup at the block atlas upload boundary.
The input-age link guard can also skip cleanup during reload stalls.
Clear live particles, queued particles, and extracted quads at every atlas upload without that guard.
`particle-final2` passed all nine paired checks with changed atlas dimensions and fresh particles in both games.
Cancellation restored saved mipmaps, and the next lighting scenario passed all ten checks.
