# Glass and fluid depth

Place glass between the viewer and water on bare Source ground. Repeat with lava.
View the scene from the opposite side, then move across the glass and fluid boundaries.
Repeat across a Minecraft section boundary.

Opaque blocks and lava must write depth before transparent surfaces.
Draw transparent faces from far to near across all sections, independent of texture upload order.
Water behind glass must remain visible through the glass. Glass edges must remain visible in front of water.
Capture both views in Source. Record transparent face counts and frame times with the entity/TNT scenario.
