#!/usr/bin/env python3
"""
Procedural High-Resolution PBR & Decal Texture Generator for Capture the Flag.
Run with Blender's bundled Python (which includes numpy).
"""
import os
import struct
import zlib
import math
import numpy as np

OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "textures")
os.makedirs(OUT_DIR, exist_ok=True)


def write_png(path, rgba_u8):
    """Write an HxWx4 (or HxWx3) uint8 numpy array to a PNG file."""
    h, w = rgba_u8.shape[:2]
    channels = rgba_u8.shape[2] if rgba_u8.ndim == 3 else 1
    if channels == 4:
        color_type = 6
    elif channels == 3:
        color_type = 2
    else:
        color_type = 0
        rgba_u8 = rgba_u8.reshape(h, w, 1)

    # Prepend filter byte 0 to each scanline
    raw_rows = np.concatenate(
        [np.zeros((h, 1), dtype=np.uint8), np.ascontiguousarray(rgba_u8, dtype=np.uint8).reshape(h, w * channels)],
        axis=1
    )
    compressed = zlib.compress(raw_rows.tobytes(), level=6)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, color_type, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", compressed) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def tileable_value_noise(size, grid, seed=0):
    """Smooth tileable 2D value noise in [0, 1]."""
    rng = np.random.default_rng(seed)
    vals = rng.random((grid, grid), dtype=np.float32)
    y = np.linspace(0, grid, size, endpoint=False, dtype=np.float32)
    x = np.linspace(0, grid, size, endpoint=False, dtype=np.float32)
    xi = np.floor(x).astype(np.int32)
    yi = np.floor(y).astype(np.int32)
    xf = x - xi
    yf = y - yi
    # Quintic fade
    u = xf * xf * xf * (xf * (xf * 6 - 15) + 10)
    v = yf * yf * yf * (yf * (yf * 6 - 15) + 10)
    x0 = xi % grid
    x1 = (xi + 1) % grid
    y0 = yi % grid
    y1 = (yi + 1) % grid

    c00 = vals[np.ix_(y0, x0)]
    c10 = vals[np.ix_(y0, x1)]
    c01 = vals[np.ix_(y1, x0)]
    c11 = vals[np.ix_(y1, x1)]
    nx0 = c00 * (1 - u[None, :]) + c10 * u[None, :]
    nx1 = c01 * (1 - u[None, :]) + c11 * u[None, :]
    return nx0 * (1 - v[:, None]) + nx1 * v[:, None]


def fbm_tileable(size, base_grid=4, octaves=5, seed=0):
    acc = np.zeros((size, size), dtype=np.float32)
    amp = 0.5
    norm = 0.0
    for o in range(octaves):
        g = base_grid * (2 ** o)
        if g > size:
            break
        acc += amp * tileable_value_noise(size, g, seed=seed + o * 137)
        norm += amp
        amp *= 0.5
    return acc / max(norm, 1e-6)


def height_to_normal(height, strength=3.0):
    """Convert tileable heightfield [0,1] into OpenGL tangent-space normal RGB uint8."""
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5 * strength
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5 * strength
    nx = -dx
    ny = -dy
    nz = np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz) + 1e-8
    nx /= length
    ny /= length
    nz /= length
    rgb = np.stack([nx * 0.5 + 0.5, ny * 0.5 + 0.5, nz * 0.5 + 0.5], axis=-1)
    return np.clip(rgb * 255.0, 0, 255).astype(np.uint8)


def generate_paint_splatters():
    """Generate 4 distinct organic wet paint splatters (albedo + normal)."""
    size = 512
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    cx = (xx - size * 0.5) / (size * 0.5)
    cy = (yy - size * 0.5) / (size * 0.5)
    rr = np.sqrt(cx * cx + cy * cy) + 1e-6
    ang = np.arctan2(cy, cx)

    for idx in range(4):
        rng = np.random.default_rng(1001 + idx * 73)
        # Organic central blob radius modulation via angular harmonics
        rad = np.full_like(ang, 0.38)
        for k in range(2, 11):
            amp = rng.uniform(0.015, 0.075) * (5.0 / (k + 3.0))
            phase = rng.uniform(0, 2 * math.pi)
            rad += amp * np.sin(k * ang + phase)

        # Add high-frequency splat fingers
        for _ in range(rng.integers(7, 13)):
            f_ang = rng.uniform(-math.pi, math.pi)
            f_width = rng.uniform(0.08, 0.22)
            f_len = rng.uniform(0.14, 0.36)
            da = np.arctan2(np.sin(ang - f_ang), np.cos(ang - f_ang))
            rad += f_len * np.exp(-0.5 * (da / f_width) ** 2)

        noise = fbm_tileable(size, base_grid=6, octaves=4, seed=200 + idx * 17)
        dist = rr - (rad + (noise - 0.5) * 0.08)
        field = np.clip(0.5 - dist * 16.0, 0.0, 1.0)

        # Add satellite droplets & radial streaks
        for _ in range(rng.integers(14, 24)):
            d_ang = rng.uniform(0, 2 * math.pi)
            d_dist = rng.uniform(0.42, 0.86)
            dx = math.cos(d_ang) * d_dist
            dy = math.sin(d_ang) * d_dist
            r_drop = rng.uniform(0.016, 0.055)
            # Slightly elongated radially
            rx = (cx - dx) * math.cos(d_ang) + (cy - dy) * math.sin(d_ang)
            ry = -(cx - dx) * math.sin(d_ang) + (cy - dy) * math.cos(d_ang)
            elong = rng.uniform(1.1, 2.3)
            d_val = np.sqrt((rx / elong) ** 2 + ry ** 2)
            drop_mask = np.clip((r_drop - d_val) * 55.0, 0.0, 1.0)
            field = np.maximum(field, drop_mask)

        # Smooth height for raised wet paint rim
        alpha = np.clip(field, 0.0, 1.0)
        # Rim thickness: paint pools slightly thicker near the outer edge of each blob
        edge_bump = np.sin(np.clip(alpha, 0.0, 1.0) * math.pi) * 0.35 + alpha * 0.65
        height = edge_bump * (0.85 + 0.15 * noise)

        # Albedo: bright pure white core with subtle organic paint sheen variation
        # (Godot Decal modulate tints this into Cobalt Blue or Ember Coral!)
        val = np.clip(0.92 + 0.08 * noise + 0.06 * (1.0 - np.clip(rr * 1.2, 0, 1)), 0.0, 1.0)
        rgba = np.stack([
            (val * 255).astype(np.uint8),
            (val * 255).astype(np.uint8),
            (val * 255).astype(np.uint8),
            (alpha * 255).astype(np.uint8),
        ], axis=-1)
        write_png(os.path.join(OUT_DIR, f"splat_{idx}.png"), rgba)
        write_png(os.path.join(OUT_DIR, f"splat_normal_{idx}.png"), height_to_normal(height, strength=4.5))


def generate_vinyl_bunker_textures():
    """Ripstop PVC inflatable speedball bunker tarpaulin textures."""
    size = 512
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    # Fine ripstop grid
    grid_x = np.abs(np.sin(xx * math.pi / 8.0)) ** 16
    grid_y = np.abs(np.sin(yy * math.pi / 8.0)) ** 16
    ripstop = np.maximum(grid_x, grid_y)
    # Micro woven vinyl grain
    weave = 0.5 * (np.sin(xx * math.pi * 0.5) * np.sin(yy * math.pi * 0.5) * 0.5 + 0.5)
    soft_wrinkle = fbm_tileable(size, base_grid=4, octaves=4, seed=310)
    # Subtle welded seam bands
    seam = np.exp(-((yy - size * 0.5) / 4.0) ** 2) * 0.7

    height = 0.5 * soft_wrinkle + 0.25 * ripstop + 0.12 * weave + 0.3 * seam
    # Subtle gray-white neutral variation so material tint works cleanly
    base = np.clip(0.92 - 0.07 * ripstop - 0.05 * (1.0 - soft_wrinkle) - 0.1 * seam, 0.65, 1.0)
    rgb = np.stack([base, base, base], axis=-1)
    write_png(os.path.join(OUT_DIR, "vinyl_bunker_albedo.png"), (rgb * 255).astype(np.uint8))
    write_png(os.path.join(OUT_DIR, "vinyl_bunker_normal.png"), height_to_normal(height, strength=2.6))
    rough = np.clip(0.24 + 0.14 * ripstop + 0.10 * (1.0 - soft_wrinkle), 0.12, 0.55)
    write_png(os.path.join(OUT_DIR, "vinyl_bunker_rough.png"), (rough * 255).astype(np.uint8))


def generate_wood_textures():
    """Warm slatted tactical timber / crate wood planks."""
    size = 512
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    n1 = fbm_tileable(size, base_grid=4, octaves=5, seed=401)
    n2 = fbm_tileable(size, base_grid=16, octaves=4, seed=402)
    # Horizontal wood grain fibers
    grain_coord = yy * 0.16 + n1 * 9.0 + np.sin(xx * 0.025) * 1.5
    grain = 0.5 + 0.5 * np.sin(grain_coord * 2.4)
    fine_fiber = 0.5 + 0.5 * np.sin(yy * 0.9 + n2 * 6.0)

    # 4 horizontal plank seams
    plank_h = size / 4.0
    plank_idx = np.floor(yy / plank_h).astype(np.int32)
    local_y = (yy % plank_h) / plank_h
    seam_groove = np.clip(np.minimum(local_y, 1.0 - local_y) * 28.0, 0.0, 1.0)
    # Per-plank slight tone variation
    plank_tones = np.array([0.96, 1.05, 0.91, 1.02], dtype=np.float32)[plank_idx % 4]

    # Base warm cedar wood color
    wood_val = (0.72 + 0.18 * grain + 0.08 * fine_fiber) * plank_tones * (0.45 + 0.55 * seam_groove)
    r = np.clip(wood_val * 0.68, 0, 1)
    g = np.clip(wood_val * 0.45, 0, 1)
    b = np.clip(wood_val * 0.27, 0, 1)
    rgb = np.stack([r, g, b], axis=-1)
    write_png(os.path.join(OUT_DIR, "wood_plank_albedo.png"), (rgb * 255).astype(np.uint8))

    height = seam_groove * 0.6 + grain * 0.22 + fine_fiber * 0.10 + n2 * 0.08
    write_png(os.path.join(OUT_DIR, "wood_plank_normal.png"), height_to_normal(height, strength=3.8))
    rough = np.clip(0.58 + 0.22 * (1.0 - grain) + 0.15 * (1.0 - seam_groove), 0.35, 0.95)
    write_png(os.path.join(OUT_DIR, "wood_plank_rough.png"), (rough * 255).astype(np.uint8))


def generate_concrete_textures():
    """Warm sunlit architectural concrete for base pads and jersey walls."""
    size = 512
    n_large = fbm_tileable(size, base_grid=4, octaves=4, seed=501)
    n_med = fbm_tileable(size, base_grid=16, octaves=4, seed=502)
    n_fine = fbm_tileable(size, base_grid=64, octaves=3, seed=503)
    pits = np.clip((n_fine - 0.72) * 5.0, 0.0, 1.0)

    val = np.clip(0.76 + 0.10 * (n_large - 0.5) + 0.08 * (n_med - 0.5) - 0.14 * pits, 0.45, 0.92)
    rgb = np.stack([val * 1.03, val * 1.00, val * 0.93], axis=-1)
    write_png(os.path.join(OUT_DIR, "concrete_albedo.png"), np.clip(rgb * 255, 0, 255).astype(np.uint8))

    height = 0.45 * n_med + 0.35 * n_fine - 0.35 * pits
    write_png(os.path.join(OUT_DIR, "concrete_normal.png"), height_to_normal(height, strength=3.0))
    rough = np.clip(0.68 + 0.18 * n_med + 0.12 * pits, 0.45, 0.95)
    write_png(os.path.join(OUT_DIR, "concrete_rough.png"), (rough * 255).astype(np.uint8))


def generate_canvas_textures():
    """Woven tactical burlap/canvas for sandbags."""
    size = 512
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    warp = 0.5 + 0.5 * np.sin(xx * math.pi / 3.0)
    weft = 0.5 + 0.5 * np.sin(yy * math.pi / 3.0)
    checker = ((np.floor(xx / 3.0).astype(np.int32) + np.floor(yy / 3.0).astype(np.int32)) & 1).astype(np.float32)
    weave = warp * checker + weft * (1.0 - checker)
    n = fbm_tileable(size, base_grid=6, octaves=4, seed=601)

    val = np.clip(0.66 + 0.12 * weave + 0.12 * (n - 0.5), 0.35, 0.9)
    rgb = np.stack([val * 0.98, val * 0.87, val * 0.67], axis=-1)
    write_png(os.path.join(OUT_DIR, "canvas_sandbag_albedo.png"), (rgb * 255).astype(np.uint8))
    write_png(os.path.join(OUT_DIR, "canvas_sandbag_normal.png"), height_to_normal(weave * 0.65 + n * 0.35, strength=3.5))


def generate_turf_detail():
    """Fine grass blade detail normal + organic variation noise for the athletic turf shader."""
    size = 512
    n_blades = fbm_tileable(size, base_grid=32, octaves=4, seed=701)
    n_clump = fbm_tileable(size, base_grid=8, octaves=4, seed=702)
    rng = np.random.default_rng(703)
    speckle = rng.random((size, size), dtype=np.float32)
    # Slight directional blur for grass blades
    blades = 0.5 * speckle + 0.25 * np.roll(speckle, 1, axis=0) + 0.25 * np.roll(speckle, -1, axis=0)
    height = 0.45 * blades + 0.35 * n_blades + 0.20 * n_clump
    write_png(os.path.join(OUT_DIR, "turf_detail_normal.png"), height_to_normal(height, strength=3.2))
    # Pack multi-frequency organic noise into RGB
    noise_rgb = np.stack([n_clump, n_blades, blades], axis=-1)
    write_png(os.path.join(OUT_DIR, "turf_noise.png"), np.clip(noise_rgb * 255, 0, 255).astype(np.uint8))


def generate_team_flags():
    """Crisp woven tournament team flags (Cobalt Blue & Ember Coral) with bold heraldic emblems."""
    w, h = 1024, 512
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    u = xx / w
    v = yy / h

    # Woven nylon/ripstop fabric sheen
    weave = 0.5 + 0.5 * (np.sin(xx * 0.9) * np.sin(yy * 0.9))
    fabric_mod = 0.94 + 0.06 * weave

    specs = [
        ("flag_blue.png", (0.08, 0.44, 0.96), (0.02, 0.22, 0.62), (0.00, 0.86, 1.00), (0.96, 0.98, 1.00), "bolt"),
        ("flag_red.png",  (0.95, 0.22, 0.12), (0.60, 0.08, 0.06), (1.00, 0.66, 0.12), (1.00, 0.96, 0.92), "flame"),
    ]

    for fname, c_main, c_dark, c_accent, c_white, emblem in specs:
        img = np.zeros((h, w, 3), dtype=np.float32)
        # Gradient from hoist (left) to fly (right)
        grad = np.clip(u * 0.65 + 0.35, 0, 1)
        for ch in range(3):
            img[:, :, ch] = c_dark[ch] * (1.0 - grad) + c_main[ch] * grad

        # Bold diagonal racing stripes near the fly end
        diag = u + (v - 0.5) * 0.35
        stripe1 = (diag > 0.72) & (diag < 0.78)
        stripe2 = (diag > 0.82) & (diag < 0.90)
        for ch in range(3):
            img[:, :, ch] = np.where(stripe1, c_white[ch], img[:, :, ch])
            img[:, :, ch] = np.where(stripe2, c_accent[ch], img[:, :, ch])

        # Hoist vertical reinforcement band
        hoist = u < 0.06
        for ch in range(3):
            img[:, :, ch] = np.where(hoist, c_white[ch] * 0.92, img[:, :, ch])

        # Top & bottom stitched border hem
        border = (v < 0.06) | (v > 0.94)
        for ch in range(3):
            img[:, :, ch] = np.where(border, c_dark[ch] * 0.85, img[:, :, ch])

        # Center-left crisp geometric shield & emblem
        ex = (u - 0.42) * 2.0  # aspect corrected
        ey = (v - 0.50) * 1.0
        # Diamond / hex crest outline
        diamond = np.abs(ex) * 0.85 + np.abs(ey)
        outer_ring = (diamond < 0.33) & (diamond > 0.27)
        inner_fill = diamond <= 0.27
        for ch in range(3):
            img[:, :, ch] = np.where(inner_fill, c_dark[ch] * 0.75, img[:, :, ch])
            img[:, :, ch] = np.where(outer_ring, c_white[ch], img[:, :, ch])

        if emblem == "bolt":
            # Sharp chevron / lightning emblem
            chev1 = (np.abs(ey + 0.04 + np.abs(ex) * 0.7) < 0.045) & (np.abs(ex) < 0.16)
            chev2 = (np.abs(ey - 0.09 + np.abs(ex) * 0.7) < 0.045) & (np.abs(ex) < 0.16)
            mask = (chev1 | chev2) & inner_fill
        else:
            # Sharp phoenix / cross-diamond emblem
            star1 = (np.abs(ex) * 1.1 + np.abs(ey) < 0.15)
            star2 = (np.abs(ex) < 0.035) & (np.abs(ey) < 0.20)
            star3 = (np.abs(ey) < 0.035) & (np.abs(ex) < 0.20)
            mask = (star1 | star2 | star3) & inner_fill

        for ch in range(3):
            img[:, :, ch] = np.where(mask, c_accent[ch], img[:, :, ch])

        # Subtle center emblem highlight
        core = (np.abs(ex) + np.abs(ey)) < 0.06
        for ch in range(3):
            img[:, :, ch] = np.where(core, c_white[ch], img[:, :, ch])

        img *= fabric_mod[:, :, None]
        write_png(os.path.join(OUT_DIR, fname), np.clip(img * 255, 0, 255).astype(np.uint8))


def generate_arena_banner():
    """Tournament perimeter sponsor/event banner texture."""
    w, h = 1024, 256
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    u = xx / w
    v = yy / h
    img = np.zeros((h, w, 3), dtype=np.float32)
    # Dark slate athletic base
    img[:, :, 0] = 0.12
    img[:, :, 1] = 0.15
    img[:, :, 2] = 0.20

    # Cobalt left diagonal sweep, Ember right diagonal sweep, bright gold center chevrons
    d = u + (v - 0.5) * 0.18
    left_blue = d < 0.34
    right_red = d > 0.66
    mid_stripe_l = (d >= 0.34) & (d < 0.37)
    mid_stripe_r = (d > 0.63) & (d <= 0.66)
    center_accent = (np.abs(u - 0.5) < 0.07) & (np.abs(v - 0.5) < 0.28)
    center_diamond = (np.abs(u - 0.5) * 3.5 + np.abs(v - 0.5)) < 0.32

    img[left_blue] = [0.10, 0.46, 0.94]
    img[right_red] = [0.94, 0.24, 0.14]
    img[mid_stripe_l] = [0.00, 0.85, 1.00]
    img[mid_stripe_r] = [1.00, 0.66, 0.14]
    img[center_accent] = [0.96, 0.95, 0.90]
    img[center_diamond] = [1.00, 0.78, 0.18]

    # Top and bottom trim rails
    trim = (v < 0.10) | (v > 0.90)
    img[trim] = [0.92, 0.92, 0.90]

    write_png(os.path.join(OUT_DIR, "banner_arena.png"), np.clip(img * 255, 0, 255).astype(np.uint8))


def generate_soft_glow_and_reticle():
    """Radial soft glow sprite + clean tactical reticle texture."""
    size = 256
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    cx = (xx - size * 0.5) / (size * 0.5)
    cy = (yy - size * 0.5) / (size * 0.5)
    rr = np.sqrt(cx * cx + cy * cy)

    # Soft glow
    glow = np.exp(-rr * rr * 5.0) * np.clip(1.0 - rr, 0.0, 1.0)
    rgba = np.zeros((size, size, 4), dtype=np.uint8)
    rgba[:, :, 0:3] = 255
    rgba[:, :, 3] = np.clip(glow * 255, 0, 255).astype(np.uint8)
    write_png(os.path.join(OUT_DIR, "glow_soft.png"), rgba)

    # Crisp tactical aim reticle ring + ticks
    ring = np.exp(-((rr - 0.62) / 0.055) ** 2)
    dot = np.exp(-(rr / 0.09) ** 2)
    cross_h = (np.abs(cy) < 0.045) & (np.abs(cx) > 0.28) & (np.abs(cx) < 0.88)
    cross_v = (np.abs(cx) < 0.045) & (np.abs(cy) > 0.28) & (np.abs(cy) < 0.88)
    ret = np.clip(ring * 0.9 + dot + (cross_h | cross_v).astype(np.float32) * 0.95, 0.0, 1.0)
    ret_rgba = np.zeros((size, size, 4), dtype=np.uint8)
    ret_rgba[:, :, 0:3] = 255
    ret_rgba[:, :, 3] = np.clip(ret * 255, 0, 255).astype(np.uint8)
    write_png(os.path.join(OUT_DIR, "reticle.png"), ret_rgba)


if __name__ == "__main__":
    print("Generating high-res procedural PBR & decal textures...")
    generate_paint_splatters()
    generate_vinyl_bunker_textures()
    generate_wood_textures()
    generate_concrete_textures()
    generate_canvas_textures()
    generate_turf_detail()
    generate_team_flags()
    generate_arena_banner()
    generate_soft_glow_and_reticle()
    print(f"Done! Textures written to {OUT_DIR}")
