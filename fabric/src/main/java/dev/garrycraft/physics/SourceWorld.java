package dev.garrycraft.physics;

/** Immutable collision snapshots serve both Minecraft threads. Source owns these surfaces. */
public final class SourceWorld {
    public static final CollisionWorld COLLISION = new CollisionWorld();
    public static volatile boolean active;
    private SourceWorld() {}
}
