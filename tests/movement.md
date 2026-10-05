# Bridge presentation and input E2E

- Hold Forward on a flat floor for five seconds. Record authoritative Y and camera Y every frame. Neither can oscillate on that floor.
- Hold Forward and Sprint. Capture Source input, Minecraft input acknowledgement, sprint state, and displacement. Sprint must travel farther than walking with the same hunger.
- Walk and sprint diagonally into a wall. Compare all positions and velocities with vanilla Minecraft at 1e-6 blocks.
- Walk up and down 15, 30, and 45 degree Source ramps. Record position, support contact, and velocity. No penetration, stalls, or unexplained vertical reversals are allowed.
- Approach a steep face. Verify it blocks walking without a jump.
- Save traces and the test result in artifacts. A build alone does not verify movement.

- Start Minecraft twice without keyboard input. GarryCraft must reopen its mirror world past the experimental warning. Record both successful world joins.
