# Bridge protocol

The bridge uses a local 32 MiB memory-mapped file. It has four independent single-writer mailboxes.
Each mailbox has a 64-byte header and a fixed payload capacity.

| Lane | Writer | Capacity | Content |
| --- | --- | --- | --- |
| 0 | Source | 64 KiB | Input, session, player origin, acknowledgments |
| 1 | Minecraft | 4 MiB | Player state and world changes |
| 2 | Source | 16 MiB | Static collision batches |
| 3 | Source | 8 MiB | Nearby dynamic collision |

All integers use little endian. Each header contains a sequence at byte 0 and payload length at byte 4.
The writer sets an odd sequence, writes the payload, then publishes the next even sequence.
The reader copies an even sequence, copies the payload, and checks the sequence again.
A changed or odd sequence means the reader must retry on the next frame.
Sequence access uses acquire/release ordering across processes.

Payloads contain UTF-8 JSON. Protocol version 1 rejects other versions.
Positions use Minecraft coordinates: Source `(x,y,z)` maps to `(x/32,z/32,-y/32)`.
Source units per block are fixed at 32. Yaw maps to `-SourceYaw - 90`. Pitch uses the Source pitch.
Minecraft remains the owner of player position after the initial attachment.

Static geometry uses numbered batches and acknowledgments. Input snapshots must not replace geometry batches.
Minecraft releases input after one second without Source. Source stops the bridge after five seconds without Minecraft.

Source issues a monotonically increasing `teleportSeq` on attachment and respawn.
Input origin remains the chosen spawn until Minecraft publishes its matching `teleportAck`.
Both Source movement and camera reject poses with an older acknowledgement.
Minecraft sends a cumulative `deaths` counter to trigger the matching Source respawn.

Lane 3 also supplies a 9-by-9 water-surface grid. Minecraft substitutes this water during entity fluid checks.
## Current clock and camera

The native client reads lane 1 directly. Player state includes previous/current raw tick positions, tick period, and a Windows performance-counter timestamp.
The Source camera interpolates the raw tick history on the same clock. It never treats post-gravity velocity as camera displacement.
Minecraft publishes camera FOV and bob after its render frame. Source converts the vertical FOV to the horizontal 4:3 setting.
Minecraft releases bridge controls after one second without Source input. Source restores its player after five seconds without Minecraft state.
