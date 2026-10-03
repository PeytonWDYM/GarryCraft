// Adapted from SkyCraft, Copyright (c) 2026 chasmlol. MIT license.
package dev.garrycraft.physics;

import java.util.ArrayList;
import java.util.List;

/**
 * Smooth collision for the local player against Source's exact triangles.
 *
 * Minecraft still computes every velocity (walking, sprinting, jumping, gravity, friction); this
 * only replaces how that movement is stopped by Source geometry, which vanilla can only represent
 * as axis-aligned boxes (i.e. stair-stepped slopes):
 *  - walkable ground (<= ~45 deg) is followed exactly, stepping up to Minecraft's step height;
 *  - while grounded and not jumping, the player sticks to ground going downhill;
 *  - steeper surfaces are walls: the player's cylinder slides along them;
 *  - ceilings stop upward movement.
 * The resulting movement is handed back to Minecraft, which derives onGround, fall damage,
 * sprint-stopping etc. from it exactly as it would from block collisions.
 */
public final class TriCollider {
	private static final double FLOOR_RADIUS = 0.15;   // normalized footprint, scaled to the entity's actual width
	private static final double SUBSTEP = 0.1;         // horizontal sub-steps so walls can't be tunnelled
	private static final double AIR_STEP = 0.3;        // walkable surfaces this far above the feet catch you mid-air
	private static final double EPS = 1e-4;

	private static final double[][] FLOOR_SAMPLES = buildSamples();

	private TriCollider() {
	}

	private static double[][] buildSamples() {
		List<double[]> samples = new ArrayList<>();
		samples.add(new double[] { 0, 0 });
		for (int i = 0; i < 8; i++) {
			double a = i * Math.PI / 4;
			samples.add(new double[] { Math.cos(a) * FLOOR_RADIUS, Math.sin(a) * FLOOR_RADIUS });
		}
		for (int i = 0; i < 4; i++) {
			double a = Math.PI / 4 + i * Math.PI / 2;
			samples.add(new double[] { Math.cos(a) * FLOOR_RADIUS * Math.sqrt(2), Math.sin(a) * FLOOR_RADIUS * Math.sqrt(2) });
		}
		return samples.toArray(new double[0][]);
	}

	/**
	 * Resolves one tick of movement {@code (mx, my, mz)} for a player whose feet are centred at
	 * {@code (x0, y0, z0)}. Returns the allowed movement.
	 */
	public static double[] resolve(
		List<Triangle> tris, double x0, double y0, double z0, double radius, double height, double step, boolean wasOnGround, double mx, double my, double mz
	) {
		if (tris.isEmpty()) return new double[]{mx, my, mz};
		// Vanilla resolves vertical movement before horizontal movement. A descending glider must
		// meet a low wall at its landing height, rather than pass above it at the previous height.
		double vertical = my;
		if (my > 0) {
			double ceiling = ceilingAbove(tris, x0, y0 + height, z0, radius * .8);
			if (!Double.isNaN(ceiling)) vertical = Math.max(0, Math.min(my, ceiling - y0 - height));
		} else if (my < 0) {
			double ground = floor(tris, x0, y0, z0, radius, false, EPS);
			if (y0 + my <= ground) vertical = ground - y0;
		}
		boolean landed = my < 0 && vertical != my;
		var horizontal = resolveHorizontal(tris, x0, y0 + vertical, z0, radius, height, step, wasOnGround || landed, my <= 0, mx, mz);
		return new double[]{horizontal[0], horizontal[1] == 0 ? vertical : vertical + horizontal[1], horizontal[2]};
	}

	private static double[] resolveHorizontal(
		List<Triangle> tris, double x0, double y0, double z0, double radius, double height, double step, boolean wasOnGround, boolean followDown, double mx, double mz
	) {
		double x = x0, y = y0, z = z0;

		// 1) Horizontal, in sub-steps, sliding out of walls after each.
		double horizontal = Math.hypot(mx, mz);
		int steps = Math.max(1, (int) Math.ceil(horizontal / SUBSTEP));
		// A landed elytra pose is shorter than the walking step height. Keep its body in the wall test.
		double wallFrom = wasOnGround ? Math.min(step, height * .5) : 0.02;
		boolean hitWall = false;
		for (int i = 0; i < steps; i++) {
			double px = x, pz = z;
			x += mx / steps;
			z += mz / steps;
			double[] out = pushOutOfWalls(tris, x, y, z, radius, height, wallFrom, step, px, pz);
			hitWall |= out[0] != x || out[1] != z;
			x = out[0];
			z = out[1];
		}

		// 2) Follow walkable slopes and step onto low ledges after horizontal movement.
		double walkUp = wasOnGround ? step : AIR_STEP;
		double floorWalk = floor(tris, x, y, z, radius, true, walkUp);
		double floorAny = floor(tris, x, y, z, radius, false, EPS);
		double floor = Math.max(floorWalk, floorAny);
		double outY;
		if (y <= floor) {
			outY = floor - y0; // land / stand / walk up a slope or small ledge
		} else if (wasOnGround && followDown && floorWalk > Double.NEGATIVE_INFINITY
				&& y - floorWalk <= Math.max(step, horizontal * 1.5) && slopeBelow(tris, x, z, radius, floorWalk)) {
			outY = floorWalk - y0; // stick to the ground going downhill instead of hopping
		} else {
			outY = 0; // vertical movement was already resolved at the original footprint
		}
		// Minecraft decides "did I collide?" with exact equality against what it asked for, so any
		// axis we didn't actually change must come back bit-for-bit identical (not (y0 + d) - y0).
		return new double[] { hitWall ? x - x0 : mx, outY, hitWall ? z - z0 : mz };
	}

	/** Follow connected slopes, but let Minecraft fall naturally when walking off a flat ledge. */
	private static boolean slopeBelow(List<Triangle> triangles, double x, double z, double radius, double floor) {
		for (var triangle : triangles) {
			if (!triangle.walkable || Math.abs(triangle.ny) >= 1 - EPS) continue;
			// Ground uses the highest footprint sample, which differs from the center on a ramp.
			for (var sample : FLOOR_SAMPLES) {
				if (Math.abs(triangle.heightAt(x + sample[0] * radius / FLOOR_RADIUS,
						z + sample[1] * radius / FLOOR_RADIUS) - floor) < EPS) return true;
			}
		}
		return false;
	}

	/** Highest ground under the footprint at most {@code maxAbove} above the feet (or -inf). */
	private static double floor(List<Triangle> tris, double x, double y, double z, double radius, boolean walkableOnly, double maxAbove) {
		double best = Double.NEGATIVE_INFINITY;
		double limit = y + maxAbove;
		for (Triangle t : tris) {
			if (walkableOnly && !t.walkable) {
				continue;
			}
			if (t.minY > limit) {
				continue;
			}
			for (double[] s : FLOOR_SAMPLES) {
				double h = t.heightAt(x + s[0] * radius / FLOOR_RADIUS, z + s[1] * radius / FLOOR_RADIUS);
				if (!Double.isNaN(h) && h <= limit && h > best) {
					best = h;
				}
			}
		}
		return best;
	}

	/** Lowest surface above the head within the footprint, or NaN. */
	private static double ceilingAbove(List<Triangle> tris, double x, double head, double z, double r) {
		double best = Double.NaN;
		for (Triangle t : tris) {
			if (t.stairHelper || t.maxY < head - 0.05) {
				continue;
			}
			for (double[] s : FLOOR_SAMPLES) {
				double h = t.heightAt(x + s[0] * r / FLOOR_RADIUS, z + s[1] * r / FLOOR_RADIUS);
				if (!Double.isNaN(h) && h >= head - 0.05 && (Double.isNaN(best) || h < best)) {
					best = h;
				}
			}
		}
		return best;
	}

	/**
	 * Pushes the player's vertical cylinder out of every triangle that intersects its body.
	 * Steep triangles count from {@code wallFrom} above the feet; walkable ones only from the
	 * step height (below that they are ground, handled by {@link #floor}).
	 */
	private static double[] pushOutOfWalls(
		List<Triangle> tris, double x, double y, double z, double radius, double height, double wallFrom, double step, double prevX, double prevZ
	) {
		double[] poly = new double[3 * 6];
		for (int iter = 0; iter < 4; iter++) {
			double bestPen = 0, bestDx = 0, bestDz = 0;
			for (Triangle t : tris) {
				if (t.stairHelper) {
					continue;
				}
				double lo = y + (t.walkable ? step : wallFrom);
				double hi = y + height - 0.02;
				if (t.maxY < lo || t.minY > hi || t.maxX < x - radius || t.minX > x + radius || t.maxZ < z - radius || t.minZ > z + radius) {
					continue;
				}
				int n = clipToSlab(t, lo, hi, poly);
				if (n == 0) {
					continue;
				}
				double[] closest = closestXZ(poly, n, x, z);
				double cx = closest[0], cz = closest[1];
				double ddx = x - cx, ddz = z - cz;
				double d = Math.sqrt(ddx * ddx + ddz * ddz);
				double pen;
				double dirX, dirZ;
				if (d > 1e-6) {
					pen = radius - d;
					dirX = ddx / d;
					dirZ = ddz / d;
				} else {
					// Axis is inside the wall's footprint: push back along its horizontal normal.
					double hl = Math.hypot(t.nx, t.nz);
					if (hl < 1e-6) {
						continue;
					}
					dirX = t.nx / hl;
					dirZ = t.nz / hl;
					if ((prevX - t.ax) * dirX + (prevZ - t.az) * dirZ < 0) {
						dirX = -dirX;
						dirZ = -dirZ;
					}
					pen = radius;
				}
				if (pen > bestPen) {
					bestPen = pen;
					bestDx = dirX;
					bestDz = dirZ;
				}
			}
			if (bestPen <= 1e-9) {
				break;
			}
			x += bestDx * bestPen;
			z += bestDz * bestPen;
		}
		return new double[] { x, z };
	}

	/** Sutherland-Hodgman clip of the triangle to lo <= y <= hi. Writes xyz triples, returns vertex count. */
	private static int clipToSlab(Triangle t, double lo, double hi, double[] out) {
		double[] a = { t.ax, t.ay, t.az, t.bx, t.by, t.bz, t.cx, t.cy, t.cz };
		double[] tmp = new double[3 * 6];
		int n = clipPlane(a, 3, tmp, lo, true);
		if (n == 0) {
			return 0;
		}
		return clipPlane(tmp, n, out, hi, false);
	}

	private static int clipPlane(double[] in, int n, double[] out, double level, boolean keepAbove) {
		int m = 0;
		for (int i = 0; i < n; i++) {
			int j = (i + 1) % n;
			double ay = in[i * 3 + 1], by = in[j * 3 + 1];
			boolean aIn = keepAbove ? ay >= level : ay <= level;
			boolean bIn = keepAbove ? by >= level : by <= level;
			if (aIn) {
				out[m * 3] = in[i * 3];
				out[m * 3 + 1] = ay;
				out[m * 3 + 2] = in[i * 3 + 2];
				m++;
			}
			if (aIn != bIn) {
				double s = (level - ay) / (by - ay);
				out[m * 3] = in[i * 3] + (in[j * 3] - in[i * 3]) * s;
				out[m * 3 + 1] = level;
				out[m * 3 + 2] = in[i * 3 + 2] + (in[j * 3 + 2] - in[i * 3 + 2]) * s;
				m++;
			}
		}
		return m;
	}

	/** Closest point on the XZ projection of a convex polygon to (x, z). */
	private static double[] closestXZ(double[] poly, int n, double x, double z) {
		// Inside test (only meaningful if the projection has area).
		double area = 0;
		for (int i = 0; i < n; i++) {
			int j = (i + 1) % n;
			area += poly[i * 3] * poly[j * 3 + 2] - poly[j * 3] * poly[i * 3 + 2];
		}
		if (Math.abs(area) > 1e-9) {
			boolean inside = true;
			for (int i = 0; i < n && inside; i++) {
				int j = (i + 1) % n;
				double cross = (poly[j * 3] - poly[i * 3]) * (z - poly[i * 3 + 2]) - (poly[j * 3 + 2] - poly[i * 3 + 2]) * (x - poly[i * 3]);
				inside = area > 0 ? cross >= -1e-12 : cross <= 1e-12;
			}
			if (inside) {
				return new double[] { x, z };
			}
		}
		double bestD = Double.MAX_VALUE, bx = poly[0], bz = poly[2];
		for (int i = 0; i < n; i++) {
			int j = (i + 1) % n;
			double x0 = poly[i * 3], z0 = poly[i * 3 + 2], x1 = poly[j * 3], z1 = poly[j * 3 + 2];
			double ex = x1 - x0, ez = z1 - z0;
			double l2 = ex * ex + ez * ez;
			double s = l2 > 1e-12 ? Math.max(0, Math.min(1, ((x - x0) * ex + (z - z0) * ez) / l2)) : 0;
			double px = x0 + ex * s, pz = z0 + ez * s;
			double d = (px - x) * (px - x) + (pz - z) * (pz - z);
			if (d < bestD) {
				bestD = d;
				bx = px;
				bz = pz;
			}
		}
		return new double[] { bx, bz };
	}

	/** Highest surface at or below {@code maxAbove} over the feet at (x, y, z), or NaN. */
	public static double groundAt(List<Triangle> tris, double x, double y, double z, double maxAbove) {
		double f = floor(tris, x, y, z, FLOOR_RADIUS, false, maxAbove);
		return f == Double.NEGATIVE_INFINITY ? Double.NaN : f;
	}
}
