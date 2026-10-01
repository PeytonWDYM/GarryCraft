# Minecraft chat and death messages

1. Press T in Source. Type a message and press Enter. The real Minecraft chat must show it once.
2. Enter `/gamemode creative`, then `/gamemode survival`. Minecraft must apply both commands and render their replies.
3. Test backspace, arrows, Tab completion, paste, and Escape. Closing chat must restore Source mouse capture.
4. Take a lethal Source NPC hit. Minecraft chat must name the attacker and use a matching death-message type.
5. Repeat nonlethal hits and reconnect. A damage event or chat character must never replay after acknowledgement.

Failure modes: Source chat opens instead, lost Unicode, duplicate characters, repeated Enter, mouse capture left enabled, generic death messages, and missing command permission.
