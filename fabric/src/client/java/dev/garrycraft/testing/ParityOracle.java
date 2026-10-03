package dev.garrycraft.testing;

import com.google.gson.Gson;
import dev.garrycraft.GarryCraftClient;
import dev.garrycraft.bridge.HostInput;
import dev.garrycraft.bridge.InputBridge;
import dev.garrycraft.combat.SourceActor;
import dev.garrycraft.physics.SourceWorld;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import net.minecraft.client.Minecraft;
import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.world.entity.EntityTypes;
import net.minecraft.world.entity.projectile.arrow.Arrow;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Items;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.phys.EntityHitResult;
import net.minecraft.world.phys.Vec3;
import dev.garrycraft.physics.SourceClip;

/** Replays a bounded vanilla comparison and combat scenario in an owned test world. */
public final class ParityOracle {
    private record Sample(int tick, double x, double y, double z, double vx, double vy, double vz, boolean grounded, boolean forward) {}
    private static final List<Sample> BASELINE = new ArrayList<>(), SOURCE = new ArrayList<>();
    private static String request = "", phase = "waiting";
    private static int stage, tick, settle;
    private static boolean running, sampling;
    private static CompletableFuture<Void> prepared;
    private static double x, y, z;
    private static Path output;
    private static int meleeRequests;
    private static int crosshairHits;
    private static BlockPos placed;
    private static boolean placementPassed;
    private static boolean removalPassed;
    private static BlockPos floorTorch, wallTorch;
    private static boolean floorTorchPassed, wallTorchPassed;
    private static int particleVertices, explosionVertices;
    private static Vec3 wallAim;
    private static String wallState;
    private static net.minecraft.world.entity.monster.zombie.Zombie zombie;
    private static Vec3 zombieStart;
    private static double zombieTravel;
    private static float zombieHealth;
    private static boolean zombieTarget;
    private record MobSample(int tick, Vec3 position, Vec3 velocity, float health, int target, Vec3 targetPosition, boolean pathDone, String end) {}
    private static final List<MobSample> MOB_TRACE = new ArrayList<>();
    private static final List<net.minecraft.world.entity.Entity> COWS = new ArrayList<>();
    private ParityOracle() {}
    public static boolean running() { return running; }
    public static String phase() { return phase; }
    public static String request() { return request; }
    public static int tick() { return tick; }
    public static void particles(int vertices) {
        if (!running) return;
        particleVertices = Math.max(particleVertices, vertices);
        if (phase.equals("tnt-explosion")) explosionVertices = Math.max(explosionVertices, vertices);
    }

    public static boolean beforeTick(Minecraft mc, HostInput host) {
        if (!running && host.test() != null && host.test().startsWith("entities:") && !host.test().equals(request)) {
            request = host.test();
            x = host.x(); y = host.y(); z = host.z();
            output = Path.of(System.getProperty("garrycraft.artifacts", System.getenv("LOCALAPPDATA") + "/GarryCraft/artifacts/parity"));
            BASELINE.clear(); SOURCE.clear(); meleeRequests = crosshairHits = 0;
            placed = null; placementPassed = removalPassed = false;
            floorTorch = wallTorch = null; floorTorchPassed = wallTorchPassed = false;
            wallState = "";
            particleVertices = explosionVertices = 0;
            zombie = null; zombieTravel = 0; zombieHealth = 100; zombieTarget = false;
            MOB_TRACE.clear();
            FrameTimings.reset();
            running = true; stage = 0; phase = "vanilla-npc-bounds";
            prepared = prepare(mc, true);
            tick = 0; settle = 12;
        }
        if (!running) return false;
        if (!host.test().equals(request)) { finish(mc); return false; }
        mc.gui.setScreen(null);
        mc.player.noPhysics = false;
        mc.player.setNoGravity(false);
        sampling = false;
        PhysicsOracle.reference = stage == 0;
        PhysicsOracle.sampledReference = stage == 0;
        SourceWorld.active = stage != 0;
        if (!prepared.isDone()) { InputBridge.apply(mc, HostInput.idle()); return true; }
        prepared.join();
        if (!mc.player.connection.hasClientLoaded() || (stage == 0 && !mc.level.getBlockState(new BlockPos(128, 63, 128)).is(Blocks.STONE))) {
            InputBridge.apply(mc, HostInput.idle()); return true;
        }
        if (settle > 0) {
            settle--;
            reset(mc, stage == 0);
            controls(mc, host, false, 6);
            return true;
        }
        sampling = true;
        controls(mc, host, stage < 2, 6);
        if (stage == 2 && tick < 150) {
            var npc = target(mc, "garrycraft-test-npc");
            if (npc != null) aim(mc, npc.getBoundingBox().getCenter());
            if (tick >= 10 && tick <= 130 && (tick - 10) % 30 == 0) attackCrosshair(mc);
        }
        if (stage == 2 && tick == 150) {
            var prop = target(mc, "garrycraft-test-prop");
            if (prop != null) {
                var position = new Vec3(prop.getX(), y, prop.getZ() - 2);
                mc.player.setPos(position); aim(mc, prop.getBoundingBox().getCenter());
                var uuid = mc.player.getUUID();
                prepared = mc.getSingleplayerServer().submit(() -> mc.getSingleplayerServer().getPlayerList().getPlayer(uuid)
                    .teleportTo(position.x, position.y, position.z));
            }
        }
        if (stage == 2 && tick >= 150 && tick < 215) {
            var prop = target(mc, "garrycraft-test-prop");
            if (prop != null) aim(mc, prop.getBoundingBox().getCenter());
        }
        if (stage == 2 && (tick == 160 || tick == 190)) attackCrosshair(mc);
        if (stage == 2 && tick == 215) { reset(mc, false); prepared = prepare(mc, false); }
        if (stage == 2 && tick == 220) projectiles(mc);
        if (stage == 2 && tick == 245) place(mc);
        if (stage == 2 && tick == 250) blocks(mc);
        if (stage == 2 && tick == 280 && placed != null) placementPassed = mc.level.getBlockState(placed).is(Blocks.STONE);
        if (stage == 2 && tick >= 300 && tick <= 340 && placed != null) {
            aim(mc, Vec3.atCenterOf(placed));
            mc.player.getInventory().setSelectedSlot(5);
            if (tick == 300) mc.gameMode.startDestroyBlock(placed, net.minecraft.core.Direction.UP);
            else mc.gameMode.continueDestroyBlock(placed, net.minecraft.core.Direction.UP);
        }
        if (stage == 2 && tick == 345 && placed != null) removalPassed = mc.level.getBlockState(placed).isAir();
        if (stage == 2 && tick == 350) torch(mc, false);
        if (stage == 2 && tick == 380 && floorTorch != null) floorTorchPassed = mc.level.getBlockState(floorTorch).is(Blocks.TORCH);
        if (stage == 2 && tick == 400) approachWall(mc);
        if (stage == 2 && tick == 405 && wallAim != null) torch(mc, true);
        if (stage == 2 && tick == 425) {
            if (wallTorch != null) {
                wallState = mc.level.getBlockState(wallTorch).toString();
                wallTorchPassed = mc.level.getBlockState(wallTorch).is(Blocks.WALL_TORCH);
            }
            reset(mc, false); prepared = prepare(mc, false);
        }
        if (stage == 2 && tick >= 250 && tick <= 390) {
            for (int i = 0; i < 4; i++) mc.level.addParticle(ParticleTypes.FLAME, x, y + 1.5, z + 2, 0, .02, 0);
        }
        if (stage == 2 && tick == 450) { phase = "fifteen-cows"; cows(mc, 0); }
        if (stage == 2 && tick == 570) { phase = "cow-drops"; cows(mc, 1); }
        if (stage == 2 && tick == 650) { phase = "after-pickup"; cows(mc, 2); }
        if (stage == 2 && tick == 850) {
            phase = "tnt-fuse";
            var server = mc.getSingleplayerServer(); var uuid = mc.player.getUUID();
            server.execute(() -> {
                var peer = server.getPlayerList().getPlayer(uuid);
                var tnt = new net.minecraft.world.entity.item.PrimedTnt(peer.level(), x + 6, y + .1, z + 4, peer);
                tnt.setFuse(80); peer.level().addFreshEntity(tnt);
            });
        }
        if (stage == 2 && tick == 920) phase = "tnt-explosion";
        if (stage == 2 && tick == 960) phase = "tnt-recovery";
        if (stage == 2 && tick == 1040) phase = "mob-combat";
        if (stage == 2 && tick == 1060) {
            var server = mc.getSingleplayerServer(); var uuid = mc.player.getUUID();
            prepared = server.submit(() -> {
                var peer = server.getPlayerList().getPlayer(uuid); var level = peer.level();
                peer.setGameMode(net.minecraft.world.level.GameType.CREATIVE);
                var target = level.getEntitiesOfClass(SourceActor.class, new net.minecraft.world.phys.AABB(
                    x - 32, y - 8, z - 32, x + 32, y + 8, z + 32), actor -> actor.getName().getString().equals("garrycraft-test-npc")).getFirst();
                zombie = new net.minecraft.world.entity.monster.zombie.Zombie(EntityTypes.ZOMBIE, level);
                zombie.setPos(target.getX() + .5, Math.floor(target.getY()), target.getZ() - 7);
                zombie.setItemSlot(net.minecraft.world.entity.EquipmentSlot.HEAD, new ItemStack(Items.IRON_HELMET));
                zombie.getAttribute(net.minecraft.world.entity.ai.attributes.Attributes.MAX_HEALTH).setBaseValue(100);
                zombie.setHealth(100); zombie.setPersistenceRequired();
                level.addFreshEntity(zombie); zombieStart = zombie.position();
            });
        }
        if (stage == 2 && tick > 1060 && zombie != null) {
            var server = mc.getSingleplayerServer();
            prepared = server.submit(() -> {
                zombieTravel = Math.max(zombieTravel, zombie.position().distanceTo(zombieStart));
                zombieHealth = zombie.getHealth(); zombieTarget |= zombie.getTarget() instanceof SourceActor;
                var path = zombie.getNavigation().getPath();
                MOB_TRACE.add(new MobSample(tick, zombie.position(), zombie.getDeltaMovement(), zombie.getHealth(),
                    zombie.getTarget() instanceof SourceActor actor ? actor.sourceId() : 0,
                    zombie.getTarget() == null ? Vec3.ZERO : zombie.getTarget().position(),
                    path == null || path.isDone(), path == null ? "" : String.valueOf(path.getEndNode())));
            });
        }
        return true;
    }
    private static void approachWall(Minecraft mc) {
            wallAim = null;
            var from = new Vec3(x, y + 1.5, z);
            net.minecraft.world.phys.BlockHitResult nearest = null;
            for (var direction : net.minecraft.core.Direction.Plane.HORIZONTAL) {
                var to = from.add(direction.getStepX() * 16, 0, direction.getStepZ() * 16);
                var hit = SourceClip.refine(from, to, net.minecraft.world.phys.BlockHitResult.miss(to, direction, BlockPos.containing(to)), SourceClip.Use.PICK);
                if (hit instanceof SourceClip.HostHit && hit.getDirection().getAxis().isHorizontal()
                        && (nearest == null || from.distanceToSqr(hit.getLocation()) < from.distanceToSqr(nearest.getLocation()))) nearest = hit;
            }
            if (nearest == null) return;
            var face = nearest.getDirection();
            var approach = nearest.getLocation().add(face.getStepX() * 2, -1.5, face.getStepZ() * 2);
            wallAim = nearest.getLocation();
            mc.player.setPos(approach);
            var uuid = mc.player.getUUID();
            prepared = mc.getSingleplayerServer().submit(() -> mc.getSingleplayerServer().getPlayerList().getPlayer(uuid)
                .teleportTo(approach.x, approach.y, approach.z));
    }
    private static void torch(Minecraft mc, boolean wall) {
        mc.player.getInventory().setSelectedSlot(8);
        aim(mc, wall ? wallAim : new Vec3(x + 2, y - 1, z - 2));
        var hit = mc.player.pick(5, 1, false);
        if (hit instanceof SourceClip.HostHit floor) {
            if (wall) wallTorch = floor.getBlockPos(); else floorTorch = floor.getBlockPos();
            mc.gameMode.useItemOn(mc.player, InteractionHand.MAIN_HAND, floor);
        }
    }
    private static void cows(Minecraft mc, int action) {
        var server = mc.getSingleplayerServer(); var uuid = mc.player.getUUID();
        server.execute(() -> {
            var peer = server.getPlayerList().getPlayer(uuid); var level = peer.level();
            if (action == 0) {
                COWS.clear();
                for (int i = 0; i < 15; i++) {
                    var cow = new net.minecraft.world.entity.animal.cow.Cow(EntityTypes.COW, level);
                    cow.setPos(x + (i % 5) - 2, Math.floor(y), z + 7 + (i / 5));
                    level.addFreshEntity(cow); COWS.add(cow);
                }
            } else if (action == 1) {
                for (var cow : COWS) cow.hurtServer(level, level.damageSources().playerAttack(peer), 1000);
            } else {
                for (var item : level.getEntitiesOfClass(net.minecraft.world.entity.item.ItemEntity.class,
                        new net.minecraft.world.phys.AABB(x - 16, y - 8, z - 16, x + 16, y + 8, z + 24))) item.playerTouch(peer);
                COWS.clear();
            }
        });
    }

    private static void aim(Minecraft mc, Vec3 point) {
        var delta = point.subtract(mc.player.getEyePosition());
        float yaw = (float) Math.toDegrees(Math.atan2(-delta.x, delta.z));
        float pitch = (float) -Math.toDegrees(Math.atan2(delta.y, Math.sqrt(delta.x * delta.x + delta.z * delta.z)));
        mc.player.setYRot(yaw); mc.player.yRotO = yaw;
        mc.player.setXRot(pitch); mc.player.xRotO = pitch;
    }
    private static void attackCrosshair(Minecraft mc) {
        meleeRequests++;
        if (mc.hitResult instanceof EntityHitResult hit && hit.getEntity() instanceof SourceActor) {
            crosshairHits++;
            mc.gameMode.attack(mc.player, hit.getEntity());
        }
    }
    private static void place(Minecraft mc) {
        mc.player.getInventory().setSelectedSlot(0);
        aim(mc, new Vec3(x + 2, y - 1, z - 3));
        var hit = mc.player.pick(5, 1, false);
        if (hit instanceof SourceClip.HostHit floor) {
            placed = floor.getBlockPos();
            mc.gameMode.useItemOn(mc.player, InteractionHand.MAIN_HAND, floor);
        }
    }

    private static SourceActor target(Minecraft mc, String name) {
        for (var entity : mc.level.entitiesForRendering())
            if (entity instanceof SourceActor actor && actor.getName().getString().equals(name)) return actor;
        return null;
    }

    private static void controls(Minecraft mc, HostInput host, boolean forward, int slot) {
        InputBridge.apply(mc, new HostInput(1, host.session(), host.frame(), true, host.x(), host.y(), host.z(), 0, 0,
            forward, false, false, false, false, false, false, stage == 2 && tick >= 300 && tick <= 340, false,
            stage == 2 && tick >= 300 && tick <= 340 ? 5 : slot, "", 0,
            host.teleportSeq(), host.damageTotal(), 0, false, false, false, 0, 0, "", host.targetFps(),
            false, List.of(), List.of(), host.viewportWidth(), host.viewportHeight(), host.entityHitAck(), host.worldAck(), host.worldInstance(), List.of(), host.renderEpoch(), host.damageScaling(), List.of(), null, -1));
    }

    private static CompletableFuture<Void> prepare(Minecraft mc, boolean reference) {
        var server = mc.getSingleplayerServer();
        var uuid = mc.player.getUUID();
        return server.submit(() -> {
            var peer = server.getPlayerList().getPlayer(uuid);
            var level = peer.level();
            if (reference) {
                for (int bx = 124; bx <= 134; bx++) for (int bz = 124; bz <= 138; bz++)
                    level.setBlock(new BlockPos(bx, 63, bz), Blocks.STONE.defaultBlockState(), 3);
                level.setBlock(new BlockPos(128, 64, 131), Blocks.STONE.defaultBlockState(), 3);
                level.setBlock(new BlockPos(128, 65, 131), Blocks.STONE.defaultBlockState(), 3);
            }
            peer.getInventory().setItem(6, new ItemStack(Items.DIAMOND_SWORD));
            peer.getInventory().setItem(8, new ItemStack(Items.TORCH, 64));
            peer.teleportTo(reference ? 128.5 : x, reference ? 64 : y, reference ? 128.5 : z);
            peer.setDeltaMovement(Vec3.ZERO);
            peer.setOnGround(true);
        });
    }
    private static void reset(Minecraft mc, boolean reference) {
        mc.player.setPos(reference ? 128.5 : x, reference ? 64 : y, reference ? 128.5 : z);
        mc.player.xo = mc.player.getX(); mc.player.yo = mc.player.getY(); mc.player.zo = mc.player.getZ();
        mc.player.setDeltaMovement(Vec3.ZERO);
        mc.player.setOnGround(true);
        mc.player.resetFallDistance();
        mc.player.setSprinting(false);
    }
    private static void projectiles(Minecraft mc) {
        var server = mc.getSingleplayerServer();
        var uuid = mc.player.getUUID();
        server.execute(() -> {
            var peer = server.getPlayerList().getPlayer(uuid);
            var arrow = new Arrow(EntityTypes.ARROW, peer.level());
            arrow.setOwner(peer);
            arrow.setPos(x, y + 1.1, z + 1);
            arrow.shoot(0, 0, 1, 1.5f, 0);
            peer.level().addFreshEntity(arrow);
        });
    }
    private static void blocks(Minecraft mc) {
        var server = mc.getSingleplayerServer();
        var uuid = mc.player.getUUID();
        server.execute(() -> {
            var level = server.getPlayerList().getPlayer(uuid).level();
            var origin = BlockPos.containing(x - 5, Math.floor(y), z + 5);
            level.setBlock(origin, Blocks.STONE.defaultBlockState(), 3);
            level.setBlock(origin.above(), Blocks.TORCH.defaultBlockState(), 3);
            level.setBlock(origin.east(), Blocks.GLASS.defaultBlockState(), 3);
            level.setBlock(origin.east(2), Blocks.STONE_SLAB.defaultBlockState(), 3);
            level.setBlock(origin.east(3), Blocks.CHEST.defaultBlockState(), 3);
            level.setBlock(origin.west(), Blocks.WATER.defaultBlockState(), 3);
            level.setBlock(origin.west(3), Blocks.LAVA.defaultBlockState(), 3);
        });
    }
    public static void afterTick(Minecraft mc) {
        if (!running || !sampling) return;
        if (stage < 2) {
            var velocity = mc.player.getDeltaMovement();
            var sample = new Sample(tick, mc.player.getX() - (stage == 0 ? 128.5 : x),
                mc.player.getY() - (stage == 0 ? 64 : y), mc.player.getZ() - (stage == 0 ? 128.5 : z),
                velocity.x, velocity.y, velocity.z, mc.player.onGround(), mc.options.keyUp.isDown());
            (stage == 0 ? BASELINE : SOURCE).add(sample);
        }
        tick++;
        if (stage == 0 && tick == 24) {
            stage = 1; tick = 0; settle = 12; phase = "source-npc-bounds";
            PhysicsOracle.reference = PhysicsOracle.sampledReference = false;
            SourceWorld.active = true;
            reset(mc, false);
            prepared = prepare(mc, false);
        } else if (stage == 1 && tick == 24) {
            stage = 2; tick = 0; phase = "combat-projectiles-world";
        } else if (stage == 2 && tick == 1420) finish(mc);
    }
    private static void finish(Minecraft mc) {
        running = false;
        PhysicsOracle.reference = PhysicsOracle.sampledReference = false;
        phase = "done";
        double error = 0;
        for (int i = 0; i < Math.min(BASELINE.size(), SOURCE.size()); i++) {
            var a = BASELINE.get(i); var b = SOURCE.get(i);
            error = Math.max(error, Math.sqrt(Math.pow(a.x() - b.x(), 2) + Math.pow(a.y() - b.y(), 2) + Math.pow(a.z() - b.z(), 2)));
        }
        var result = new com.google.gson.JsonObject();
        var json = new Gson();
        result.addProperty("request", request);
        result.add("vanilla", json.toJsonTree(BASELINE));
        result.add("source", json.toJsonTree(SOURCE));
        result.addProperty("maxPositionError", error);
        result.addProperty("collisionPassed", BASELINE.size() == 24 && SOURCE.size() == 24 && error < 0.03
            && BASELINE.getLast().z() > 2 && SOURCE.getLast().z() > 2);
        result.addProperty("meleeRequests", meleeRequests);
        result.addProperty("crosshairHits", crosshairHits);
        result.addProperty("placementPassed", placementPassed);
        result.addProperty("removalPassed", removalPassed);
        result.addProperty("floorTorchPassed", floorTorchPassed);
        result.addProperty("wallTorchPassed", wallTorchPassed);
        result.add("wallAim", json.toJsonTree(wallAim));
        result.add("wallTorch", json.toJsonTree(wallTorch));
        result.addProperty("wallState", wallState);
        result.addProperty("particleVertices", particleVertices);
        result.addProperty("explosionVertices", explosionVertices);
        result.addProperty("mobTravel", zombieTravel);
        result.addProperty("mobHealth", zombieHealth);
        result.addProperty("mobTargetedSourceNpc", zombieTarget);
        result.add("mobTrace", json.toJsonTree(MOB_TRACE));
        result.add("placed", json.toJsonTree(placed));
        try {
            Files.createDirectories(output);
            Files.writeString(output.resolve("parity-minecraft.json"), json.toJson(result));
            FrameTimings.save(output);
        } catch (IOException failure) { throw new IllegalStateException("Could not save parity trace", failure); }
        GarryCraftClient.LOG.info("GarryCraft parity complete: collision error {}, melee requests {}", error, meleeRequests);
        if (zombie != null) mc.getSingleplayerServer().execute(() -> {
            zombie.discard();
            mc.getSingleplayerServer().getPlayerList().getPlayer(mc.player.getUUID()).setGameMode(net.minecraft.world.level.GameType.SURVIVAL);
        });
    }
}
