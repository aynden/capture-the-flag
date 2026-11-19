#!/usr/bin/env python3
"""
POLISH PASS — High-quality sculpted Paintball Arena cover & objective assets in Blender 5.3.0:
- Fix #1: Cleanly aligned plump Dorito bunkers (zero cone-rotation clipping!)
- Fix #5: Authentic pinched-pillow brick-bond tactical Sandbag Walls
- Fix #6: Chunky, heroic Timber Barricades with steel reinforcement & hazard trim
- Inflatable Speedball Bunkers (Dorito, Temple, Cylinder, Snake) in Gold/Blue/Red styles
- Heroic Octagonal Flag Pedestals & High-Subdivision Cloth Pennant Flags
"""
import os
import sys
import math
import bpy
import bmesh
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common_utils import (
    clear_scene,
    make_pbr_material,
    create_mesh_obj,
    make_empty,
    bm_box,
    bm_cylinder,
    bm_cone,
    bm_sphere,
    bm_capsule,
    set_smooth,
    export_asset,
)


def make_bunker_mats(style_name, primary_col, stripe_col):
    mat_main = make_pbr_material(
        f"Vinyl_{style_name}_Main",
        base_color=primary_col,
        roughness=0.26,
        coat=0.52,
        coat_roughness=0.16,
        albedo_tex="vinyl_bunker_albedo.png",
        normal_tex="vinyl_bunker_normal.png",
        normal_strength=1.15,
        rough_tex="vinyl_bunker_rough.png",
        tint_tex=True,
        uv_scale=(1.4, 1.4),
    )
    mat_dark = make_pbr_material(
        f"Vinyl_{style_name}_Dark",
        base_color=(0.14, 0.17, 0.22, 1.0),
        roughness=0.34,
        coat=0.32,
        albedo_tex="vinyl_bunker_albedo.png",
        normal_tex="vinyl_bunker_normal.png",
        normal_strength=1.0,
        tint_tex=True,
        uv_scale=(1.6, 1.6),
    )
    mat_stripe = make_pbr_material(
        f"Vinyl_{style_name}_Stripe",
        base_color=stripe_col,
        roughness=0.20,
        coat=0.60,
        albedo_tex="vinyl_bunker_albedo.png",
        normal_tex="vinyl_bunker_normal.png",
        normal_strength=0.65,
        tint_tex=True,
        uv_scale=(1.6, 1.6),
    )
    mat_strap = make_pbr_material(f"Strap_{style_name}", base_color=(0.08, 0.09, 0.11, 1.0), roughness=0.75)
    mat_metal = make_pbr_material(f"Grommet_{style_name}", base_color=(0.70, 0.74, 0.78, 1.0), metallic=0.86, roughness=0.26)
    return mat_main, mat_dark, mat_stripe, mat_strap, mat_metal


def add_tie_down_straps(root, positions, mat_strap, mat_metal):
    for i, (x, y, ang) in enumerate(positions):
        piv = make_empty(f"Anchor_{i}", (x, y, 0.0), (0, 0, ang), parent=root)
        create_mesh_obj(
            f"Strap_{i}",
            bm_box((0.07, 0.36, 0.018), center=(0, 0.14, 0.11), bevel_width=0.005),
            mat_strap,
            rotation=(-0.55, 0, 0),
            parent=piv,
        )
        create_mesh_obj(
            f"Ring_{i}",
            bm_cylinder(0.032, 0.025, segments=12, axis="X", center=(0, 0.01, 0.20)),
            mat_metal,
            parent=piv,
        )
        create_mesh_obj(
            f"Stake_{i}",
            bm_cylinder(0.024, 0.09, segments=10, center=(0, 0.28, 0.03), bevel_width=0.006),
            mat_metal,
            parent=piv,
        )


def _bm_tri_frustum(r_bottom, r_top, z0, z1, bevel_w=0.14, bevel_segs=3, mid_bulge=1.0):
    """Creates a perfectly aligned 3-sided speedball prism using exact 90 + i*120 angles."""
    bm = bmesh.new()
    b_verts = []
    m_verts = []
    t_verts = []
    z_mid = (z0 + z1) * 0.5
    r_mid = (r_bottom + r_top) * 0.5 * mid_bulge
    for i in range(3):
        a = math.radians(90 + i * 120)
        ca, sa = math.cos(a), math.sin(a)
        b_verts.append(bm.verts.new((ca * r_bottom, sa * r_bottom, z0)))
        m_verts.append(bm.verts.new((ca * r_mid, sa * r_mid, z_mid)))
        t_verts.append(bm.verts.new((ca * r_top, sa * r_top, z1)))
    bm.faces.new(list(reversed(b_verts)))
    bm.faces.new(t_verts)
    for i in range(3):
        j = (i + 1) % 3
        bm.faces.new([b_verts[i], b_verts[j], m_verts[j], m_verts[i]])
        bm.faces.new([m_verts[i], m_verts[j], t_verts[j], t_verts[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel_w, segments=bevel_segs, profile=0.55, affect="EDGES", clamp_overlap=True)
    return bm


def build_bunker_dorito(style_name, primary, stripe):
    """Clean, plump, zero-clipping inflatable triangular speedball Dorito."""
    clear_scene()
    mat_main, mat_dark, mat_stripe, mat_strap, mat_metal = make_bunker_mats(style_name, primary, stripe)
    root = make_empty("BunkerDorito")

    # Main inflated Dorito body (slight pressurized bulge in middle)
    bm_body = _bm_tri_frustum(1.48, 0.22, 0.02, 2.08, bevel_w=0.18, bevel_segs=4, mid_bulge=1.10)
    obj_main = create_mesh_obj("DoritoBody", bm_body, mat_main, uv_scale=0.65, parent=root)
    mod = obj_main.modifiers.new("Subsurf", "SUBSURF")
    mod.levels = 1
    mod.render_levels = 1

    # Perfectly aligned lower dark scuff skirt collar
    bm_skirt = _bm_tri_frustum(1.52, 1.38, 0.0, 0.34, bevel_w=0.09, bevel_segs=3, mid_bulge=1.02)
    create_mesh_obj("DoritoBaseSkirt", bm_skirt, mat_dark, uv_scale=0.7, parent=root)

    # Perfectly aligned mid athletic stripe collar hugging the body cleanly!
    bm_band = _bm_tri_frustum(1.06, 0.90, 0.88, 1.16, bevel_w=0.06, bevel_segs=3, mid_bulge=1.03)
    create_mesh_obj("DoritoStripeBand", bm_band, mat_stripe, uv_scale=0.8, parent=root)

    # Top dark air-cap crown
    bm_cap = _bm_tri_frustum(0.44, 0.18, 1.80, 2.12, bevel_w=0.07, bevel_segs=3, mid_bulge=1.02)
    create_mesh_obj("DoritoTopCap", bm_cap, mat_dark, uv_scale=0.8, parent=root)

    anchors = []
    for i in range(3):
        a = math.radians(90 + i * 120)
        anchors.append((math.cos(a) * 1.28, math.sin(a) * 1.28, a - math.pi * 0.5))
    add_tie_down_straps(root, anchors, mat_strap, mat_metal)

    export_asset(f"bunker_dorito_{style_name}")


def build_bunker_temple(style_name, primary, stripe):
    """Sculpted trapezoidal 'Temple / Brick' inflatable bunker with quilted baffles."""
    clear_scene()
    mat_main, mat_dark, mat_stripe, mat_strap, mat_metal = make_bunker_mats(style_name, primary, stripe)
    root = make_empty("BunkerTemple")

    bm = bmesh.new()
    w0, d0 = 1.44, 0.80
    w1, d1 = 1.14, 0.60
    h = 2.08
    b = [bm.verts.new((-w0, -d0, 0)), bm.verts.new((w0, -d0, 0)), bm.verts.new((w0, d0, 0)), bm.verts.new((-w0, d0, 0))]
    m = [bm.verts.new((-w0 * 0.98, -d0 * 1.02, h * 0.45)), bm.verts.new((w0 * 0.98, -d0 * 1.02, h * 0.45)), bm.verts.new((w0 * 0.98, d0 * 1.02, h * 0.45)), bm.verts.new((-w0 * 0.98, d0 * 1.02, h * 0.45))]
    t = [bm.verts.new((-w1, -d1, h)), bm.verts.new((w1, -d1, h)), bm.verts.new((w1, d1, h)), bm.verts.new((-w1, d1, h))]
    bm.faces.new(list(reversed(b)))
    bm.faces.new(t)
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new([b[i], b[j], m[j], m[i]])
        bm.faces.new([m[i], m[j], t[j], t[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=0.18, segments=4, profile=0.58, affect="EDGES", clamp_overlap=True)
    create_mesh_obj("TempleMain", bm, mat_main, uv_scale=0.6, parent=root)

    for rx in (-0.75, 0.0, 0.75):
        create_mesh_obj(
            f"TempleRib_{rx:.2f}",
            bm_box((0.56, 1.62, 1.62), center=(rx, 0, 1.02), bevel_width=0.14, bevel_segs=3),
            mat_main if rx != 0.0 else mat_dark,
            uv_scale=0.65,
            parent=root,
        )

    create_mesh_obj(
        "TempleCrownStripe",
        bm_box((2.18, 1.28, 0.26), center=(0, 0, 1.72), bevel_width=0.08, bevel_segs=3),
        mat_stripe,
        uv_scale=0.8,
        parent=root,
    )
    create_mesh_obj(
        "TempleSkirt",
        bm_box((2.92, 1.64, 0.30), center=(0, 0, 0.15), bevel_width=0.09, bevel_segs=3),
        mat_dark,
        uv_scale=0.7,
        parent=root,
    )
    create_mesh_obj(
        "AirValve",
        bm_cylinder(0.08, 0.08, segments=16, axis="X", center=(1.44, 0.0, 0.42), bevel_width=0.015),
        mat_strap,
        parent=root,
    )

    add_tie_down_straps(
        root,
        [
            (-1.35, -0.74, math.radians(135)),
            (1.35, -0.74, math.radians(-135)),
            (1.35, 0.74, math.radians(-45)),
            (-1.35, 0.74, math.radians(45)),
        ],
        mat_strap,
        mat_metal,
    )

    export_asset(f"bunker_temple_{style_name}")


def build_bunker_cylinder(style_name, primary, stripe):
    """Tall inflatable 'Can / Tower' speedball cylinder."""
    clear_scene()
    mat_main, mat_dark, mat_stripe, mat_strap, mat_metal = make_bunker_mats(style_name, primary, stripe)
    root = make_empty("BunkerCylinder")

    create_mesh_obj("CylBody", bm_cylinder(0.84, 2.18, segments=28, center=(0, 0, 1.09), bevel_width=0.14), mat_main, uv_scale=0.65, parent=root)
    create_mesh_obj("CylTopDome", bm_sphere(0.82, scale=(1.0, 1.0, 0.34), center=(0, 0, 2.16), segs=28, rings=12), mat_dark, uv_scale=0.65, parent=root)
    create_mesh_obj("CylBaseRing", bm_cylinder(0.88, 0.34, segments=28, center=(0, 0, 0.17), bevel_width=0.06), mat_dark, uv_scale=0.7, parent=root)
    create_mesh_obj("CylBandUpper", bm_cylinder(0.875, 0.25, segments=28, center=(0, 0, 1.58), bevel_width=0.04), mat_stripe, uv_scale=0.8, parent=root)
    create_mesh_obj("CylBandLower", bm_cylinder(0.87, 0.12, segments=28, center=(0, 0, 1.24), bevel_width=0.03), mat_dark, uv_scale=0.8, parent=root)

    anchors = []
    for i in range(4):
        a = math.radians(45 + i * 90)
        anchors.append((math.cos(a) * 0.82, math.sin(a) * 0.82, a - math.pi * 0.5))
    add_tie_down_straps(root, anchors, mat_strap, mat_metal)

    export_asset(f"bunker_cylinder_{style_name}")


def build_bunker_snake(style_name, primary, stripe):
    """Low elongated segmented 'Snake' flank beam bunker."""
    clear_scene()
    mat_main, mat_dark, mat_stripe, mat_strap, mat_metal = make_bunker_mats(style_name, primary, stripe)
    root = make_empty("BunkerSnake")

    for idx, x_off in enumerate((-1.15, 0.0, 1.15)):
        mat = mat_main if idx != 1 else mat_dark
        create_mesh_obj(f"SnakeSeg_{idx}", bm_capsule(0.56, 1.48, segs=22, rings=10, center=(x_off, 0, 0.54), axis="X"), mat, uv_scale=0.7, parent=root)
    for sx in (-0.58, 0.58):
        create_mesh_obj(f"SnakeBand_{sx:.2f}", bm_cylinder(0.585, 0.16, segments=22, axis="X", center=(sx, 0, 0.54), bevel_width=0.03), mat_stripe, uv_scale=0.8, parent=root)
    create_mesh_obj("SnakeSkirt", bm_box((3.38, 1.14, 0.22), center=(0, 0, 0.11), bevel_width=0.06), mat_dark, uv_scale=0.7, parent=root)

    add_tie_down_straps(
        root,
        [
            (-1.55, -0.52, math.radians(160)),
            (1.55, -0.52, math.radians(-160)),
            (1.55, 0.52, math.radians(-20)),
            (-1.55, 0.52, math.radians(20)),
        ],
        mat_strap,
        mat_metal,
    )

    export_asset(f"bunker_snake_{style_name}")


def _bm_sculpted_sandbag(length=0.82, width=0.44, height=0.25, seed=0):
    """Pinched-pillow rectangular burlap sandbag (NOT a flat disc!)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.subdivide_edges(bm, edges=list(bm.edges), cuts=3, use_grid_fill=True)
    for v in bm.verts:
        x, y, z = v.co.x, v.co.y, v.co.z
        # Pinched tied ends along X, plump belly in center, flattened bottom
        end_taper = 1.0 - 0.52 * (abs(x) * 2.0) ** 2.4
        belly_bulge = 1.0 + 0.16 * (1.0 - (x * 2.0) ** 2) * (1.0 - (y * 2.0) ** 2)
        crease = -0.025 * math.exp(-((x * 3.0) ** 2)) if z > 0 else 0.0
        # Subtle organic lumpiness
        lump = 0.022 * math.sin(x * 7.0 + seed * 1.7) * math.cos(y * 6.0 - seed)
        nx = x * length
        ny = y * width * (0.72 + 0.28 * end_taper) * belly_bulge
        nz = z * height * (0.48 + 0.52 * end_taper) * belly_bulge + crease + lump
        if nz < -height * 0.42:
            nz = -height * 0.42 # Sit flat on lower course
        v.co = Vector((nx, ny, nz))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def build_barricade_wood():
    """Chunky, heroic tactical timber barricade with heavy beams, steel cap, hazard stripes & sandbags."""
    clear_scene()
    mat_wood = make_pbr_material(
        "WoodTimber",
        base_color=(1.0, 0.96, 0.92, 1.0),
        roughness=0.64,
        albedo_tex="wood_plank_albedo.png",
        normal_tex="wood_plank_normal.png",
        normal_strength=1.5,
        rough_tex="wood_plank_rough.png",
        uv_scale=(0.8, 0.8),
    )
    mat_wood_dark = make_pbr_material(
        "WoodPosts",
        base_color=(0.55, 0.40, 0.27, 1.0),
        roughness=0.75,
        albedo_tex="wood_plank_albedo.png",
        normal_tex="wood_plank_normal.png",
        normal_strength=1.3,
        tint_tex=True,
        uv_scale=(1.2, 1.2),
    )
    mat_steel = make_pbr_material("BracketSteel", base_color=(0.18, 0.21, 0.26, 1.0), metallic=0.82, roughness=0.35)
    mat_gold = make_pbr_material("BarricadeHazard", base_color=(0.95, 0.72, 0.14, 1.0), roughness=0.32)
    mat_canvas = make_pbr_material(
        "CanvasBag",
        base_color=(0.88, 0.82, 0.72, 1.0),
        roughness=0.88,
        albedo_tex="canvas_sandbag_albedo.png",
        normal_tex="canvas_sandbag_normal.png",
        normal_strength=1.6,
        tint_tex=True,
        uv_scale=(2.2, 2.2),
    )

    root = make_empty("BarricadeWood")

    # Chunky 3-post timber fortress wall (reads boldly from top-down!)
    for px in (-1.45, 0.0, 1.45):
        create_mesh_obj(f"Post_{px:.2f}", bm_box((0.24, 0.26, 1.68), center=(px, -0.06, 0.84), bevel_width=0.024), mat_wood_dark, parent=root)
        create_mesh_obj(f"Foot_{px:.2f}", bm_box((0.26, 0.96, 0.16), center=(px, -0.14, 0.08), bevel_width=0.02), mat_wood_dark, parent=root)
        create_mesh_obj(f"SteelCap_{px:.2f}", bm_box((0.28, 0.30, 0.14), center=(px, -0.06, 1.66), bevel_width=0.015), mat_steel, parent=root)
        # Compact sturdy rear gusset
        create_mesh_obj(f"Gusset_{px:.2f}", bm_box((0.18, 0.44, 0.76), center=(px, -0.32, 0.42), bevel_width=0.02), mat_wood_dark, rotation=(0.35, 0, 0), parent=root)

    # Thick chunky horizontal timber logs/planks (0.20m deep so they have bold top-down thickness!)
    for idx, pz in enumerate((0.24, 0.58, 0.92, 1.26, 1.54)):
        if idx < 4:
            create_mesh_obj(f"Plank_{idx}", bm_box((3.22, 0.20, 0.29), center=(0, 0.06, pz), bevel_width=0.022), mat_wood, parent=root)
        else:
            for sx in (-1.04, 1.04):
                create_mesh_obj(f"TopPlank_{sx:.1f}", bm_box((1.14, 0.22, 0.24), center=(sx, 0.06, pz), bevel_width=0.022), mat_wood, parent=root)
            # Steel reinforcement sill across center shooting notch
            create_mesh_obj("NotchSill", bm_box((0.96, 0.24, 0.08), center=(0, 0.06, 1.43), bevel_width=0.015), mat_steel, parent=root)

    # Bold top-readable yellow sport-chevron corner caps
    for sx in (-1.28, 1.28):
        create_mesh_obj(f"TopStripe_{sx:.1f}", bm_box((0.55, 0.25, 0.06), center=(sx, 0.06, 1.68), bevel_width=0.012), mat_gold, parent=root)

    # Sculpted pinched sandbags anchoring both sides of the base
    for i, (bx, by, rot) in enumerate(((-0.92, 0.32, 0.08), (-0.10, 0.34, -0.05), (0.76, 0.32, 0.06), (-0.52, -0.34, -0.04), (0.52, -0.34, 0.07))):
        create_mesh_obj(
            f"BaseBag_{i}",
            _bm_sculpted_sandbag(0.78, 0.40, 0.24, seed=i),
            mat_canvas,
            location=(bx, by, 0.12),
            rotation=(0, 0, rot),
            parent=root,
        )

    export_asset("barricade_wood")


def build_crate_stack():
    """Stacked beveled supply crates with recessed panels, steel corners, and hazard trim."""
    clear_scene()
    mat_wood = make_pbr_material(
        "CrateWood",
        base_color=(0.96, 0.90, 0.80, 1.0),
        roughness=0.60,
        albedo_tex="wood_plank_albedo.png",
        normal_tex="wood_plank_normal.png",
        normal_strength=1.35,
        rough_tex="wood_plank_rough.png",
        tint_tex=True,
        uv_scale=(1.1, 1.1),
    )
    mat_frame = make_pbr_material(
        "CrateFrame",
        base_color=(0.54, 0.37, 0.22, 1.0),
        roughness=0.72,
        albedo_tex="wood_plank_albedo.png",
        normal_tex="wood_plank_normal.png",
        tint_tex=True,
        uv_scale=(1.4, 1.4),
    )
    mat_steel = make_pbr_material("CrateSteel", base_color=(0.18, 0.21, 0.25, 1.0), metallic=0.82, roughness=0.32)
    mat_gold = make_pbr_material("CrateAccentGold", base_color=(0.95, 0.70, 0.14, 1.0), roughness=0.34)

    root = make_empty("CrateStack")

    def add_crate(name, size, loc, rot_z=0.0):
        c_root = make_empty(name, loc, (0, 0, rot_z), parent=root)
        sx, sy, sz = size
        create_mesh_obj(f"{name}_Core", bm_box((sx * 0.92, sy * 0.92, sz * 0.92), center=(0, 0, sz * 0.5), bevel_width=0.02), mat_wood, parent=c_root)
        t = 0.088
        for z_pos in (t * 0.5, sz - t * 0.5):
            create_mesh_obj(f"{name}_RailX1_{z_pos:.2f}", bm_box((sx, t, t), center=(0, -sy * 0.5 + t * 0.5, z_pos), bevel_width=0.012), mat_frame, parent=c_root)
            create_mesh_obj(f"{name}_RailX2_{z_pos:.2f}", bm_box((sx, t, t), center=(0, sy * 0.5 - t * 0.5, z_pos), bevel_width=0.012), mat_frame, parent=c_root)
            create_mesh_obj(f"{name}_RailY1_{z_pos:.2f}", bm_box((t, sy, t), center=(-sx * 0.5 + t * 0.5, 0, z_pos), bevel_width=0.012), mat_frame, parent=c_root)
            create_mesh_obj(f"{name}_RailY2_{z_pos:.2f}", bm_box((t, sy, t), center=(sx * 0.5 - t * 0.5, 0, z_pos), bevel_width=0.012), mat_frame, parent=c_root)
        for cx in (-sx * 0.5 + t * 0.5, sx * 0.5 - t * 0.5):
            for cy in (-sy * 0.5 + t * 0.5, sy * 0.5 - t * 0.5):
                create_mesh_obj(f"{name}_Post_{cx:.2f}_{cy:.2f}", bm_box((t, t, sz), center=(cx, cy, sz * 0.5), bevel_width=0.012), mat_frame, parent=c_root)
                for cz in (0.055, sz - 0.055):
                    create_mesh_obj(f"{name}_Corner_{cx:.1f}_{cy:.1f}_{cz:.1f}", bm_box((t * 1.28, t * 1.28, 0.11), center=(cx, cy, cz), bevel_width=0.01), mat_steel, parent=c_root)
        create_mesh_obj(f"{name}_Stencil", bm_box((sx * 0.55, sy * 0.94, 0.08), center=(0, 0, sz * 0.52), bevel_width=0.008), mat_gold, parent=c_root)

    add_crate("CrateBottomL", (1.28, 1.18, 1.05), (-0.52, 0.0, 0.0), rot_z=0.06)
    add_crate("CrateBottomR", (1.12, 1.08, 0.92), (0.68, -0.08, 0.0), rot_z=-0.12)
    add_crate("CrateTop", (0.98, 0.96, 0.86), (-0.28, 0.04, 1.05), rot_z=0.28)

    export_asset("crate_stack")


def build_sandbag_wall():
    """Authentic curved defensive wall of pinched-pillow brick-bond burlap sandbags."""
    clear_scene()
    mat_a = make_pbr_material(
        "SandbagCanvasA",
        base_color=(0.86, 0.78, 0.65, 1.0),
        roughness=0.90,
        albedo_tex="canvas_sandbag_albedo.png",
        normal_tex="canvas_sandbag_normal.png",
        normal_strength=1.8,
        tint_tex=True,
        uv_scale=(2.4, 2.4),
    )
    mat_b = make_pbr_material(
        "SandbagCanvasB",
        base_color=(0.74, 0.66, 0.54, 1.0),
        roughness=0.92,
        albedo_tex="canvas_sandbag_albedo.png",
        normal_tex="canvas_sandbag_normal.png",
        normal_strength=1.8,
        tint_tex=True,
        uv_scale=(2.4, 2.4),
    )
    mat_c = make_pbr_material(
        "SandbagCanvasC",
        base_color=(0.80, 0.74, 0.60, 1.0),
        roughness=0.88,
        albedo_tex="canvas_sandbag_albedo.png",
        normal_tex="canvas_sandbag_normal.png",
        normal_strength=1.8,
        tint_tex=True,
        uv_scale=(2.4, 2.4),
    )
    mats = [mat_a, mat_b, mat_c]

    root = make_empty("SandbagWall")
    radius = 2.25
    # Double-thick staggered courses so it reads as a gritty military fortification!
    courses = [
        (0.11, 5, -0.66, 0.66, 0.0),
        (0.11, 4, -0.52, 0.52, -0.34), # Inner backing row
        (0.32, 4, -0.54, 0.54, -0.05),
        (0.32, 3, -0.38, 0.38, -0.36),
        (0.53, 4, -0.50, 0.50, -0.10),
        (0.73, 3, -0.36, 0.36, -0.14),
        (0.92, 2, -0.20, 0.20, -0.16),
    ]
    bag_idx = 0
    for z_h, count, a0, a1, r_off in courses:
        for k in range(count):
            t = k / max(1, count - 1) if count > 1 else 0.5
            ang = a0 + (a1 - a0) * t
            r = radius + r_off + 0.025 * math.sin(bag_idx * 2.1)
            x = math.sin(ang) * r
            y = math.cos(ang) * r - radius
            create_mesh_obj(
                f"Sandbag_{bag_idx}",
                _bm_sculpted_sandbag(0.84, 0.44, 0.25, seed=bag_idx),
                mats[bag_idx % 3],
                location=(x, y, z_h),
                rotation=(0.04 * math.sin(bag_idx), 0.05 * math.cos(bag_idx), -ang + 0.04 * math.sin(bag_idx * 1.3)),
                parent=root,
            )
            bag_idx += 1

    export_asset("sandbag_wall")


def build_flag_pedestal(team_name, primary, accent):
    clear_scene()
    mat_conc = make_pbr_material(
        f"PedConcrete_{team_name}",
        base_color=(1.0, 1.0, 1.0, 1.0),
        roughness=0.68,
        albedo_tex="concrete_albedo.png",
        normal_tex="concrete_normal.png",
        normal_strength=1.2,
        rough_tex="concrete_rough.png",
        uv_scale=(0.8, 0.8),
    )
    mat_steel = make_pbr_material(f"PedSteel_{team_name}", base_color=(0.18, 0.22, 0.28, 1.0), metallic=0.80, roughness=0.28)
    mat_team = make_pbr_material(f"PedTeam_{team_name}", base_color=primary, roughness=0.26, coat=0.50)
    mat_led = make_pbr_material(f"PedLED_{team_name}", base_color=accent, roughness=0.15, emission=accent, emission_strength=2.2)

    root = make_empty(f"FlagPedestal_{team_name}")
    create_mesh_obj("BaseSlabOuter", bm_cone(2.68, 2.48, 0.22, segments=8, center=(0, 0, 0.11), bevel_width=0.04), mat_conc, uv_scale=0.5, parent=root)
    create_mesh_obj("BaseLEDRing", bm_cylinder(2.12, 0.06, segments=32, center=(0, 0, 0.22), bevel_width=0.01), mat_led, parent=root)
    create_mesh_obj("BaseSlabInner", bm_cone(1.94, 1.80, 0.18, segments=8, center=(0, 0, 0.30), bevel_width=0.03), mat_steel, parent=root)
    create_mesh_obj("BaseTeamMedallion", bm_cylinder(1.40, 0.05, segments=24, center=(0, 0, 0.40), bevel_width=0.01), mat_team, parent=root)
    create_mesh_obj("FlagSocket", bm_cone(0.38, 0.24, 0.28, segments=16, center=(0, 0, 0.54), bevel_width=0.02), mat_steel, parent=root)
    create_mesh_obj("FlagSocketGlow", bm_cylinder(0.26, 0.04, segments=16, center=(0, 0, 0.68)), mat_led, parent=root)

    for i in range(4):
        ang = math.radians(45 + i * 90)
        bx, by = math.cos(ang) * 2.15, math.sin(ang) * 2.15
        create_mesh_obj(f"Bollard_{i}", bm_cone(0.18, 0.13, 0.72, segments=8, center=(bx, by, 0.48), bevel_width=0.02), mat_steel, parent=root)
        create_mesh_obj(f"BollardTeam_{i}", bm_cylinder(0.155, 0.18, segments=8, center=(bx, by, 0.58), bevel_width=0.015), mat_team, parent=root)
        create_mesh_obj(f"BollardCap_{i}", bm_cylinder(0.12, 0.06, segments=8, center=(bx, by, 0.86), bevel_width=0.01), mat_led, parent=root)

    export_asset(f"flag_pedestal_{team_name}")


def build_flag_assembly(team_name, primary, accent, flag_tex):
    clear_scene()
    mat_pole = make_pbr_material(f"FlagPoleMetal_{team_name}", base_color=(0.84, 0.87, 0.91, 1.0), metallic=0.90, roughness=0.20)
    mat_finial = make_pbr_material(f"FlagFinialGlow_{team_name}", base_color=accent, metallic=0.3, roughness=0.18, emission=accent, emission_strength=1.5)
    mat_cloth = make_pbr_material(f"FlagCloth_{team_name}", base_color=(1.0, 1.0, 1.0, 1.0), roughness=0.44, albedo_tex=flag_tex, double_sided=True)

    root = make_empty(f"Flag_{team_name}")
    create_mesh_obj("PoleShaft", bm_cylinder(0.045, 3.25, segments=16, center=(0, 0, 1.625)), mat_pole, parent=root)
    create_mesh_obj("PoleBaseCollar", bm_cylinder(0.082, 0.16, segments=16, center=(0, 0, 0.08), bevel_width=0.015), mat_pole, parent=root)
    for rz in (2.00, 3.08):
        create_mesh_obj(f"MountRing_{rz:.2f}", bm_cylinder(0.065, 0.05, segments=16, center=(0, 0, rz), bevel_width=0.008), mat_pole, parent=root)
    create_mesh_obj("FinialBase", bm_cylinder(0.078, 0.08, segments=12, center=(0, 0, 3.26), bevel_width=0.01), mat_pole, parent=root)
    create_mesh_obj("FinialDiamond", bm_sphere(0.125, scale=(0.75, 0.75, 1.65), center=(0, 0, 3.45), segs=8, rings=6), mat_finial, parent=root)

    bm = bmesh.new()
    nx, ny = 28, 12
    flag_len, flag_h, z_bottom = 1.95, 1.12, 2.00
    verts = [[None] * (ny + 1) for _ in range(nx + 1)]
    for ix in range(nx + 1):
        u = ix / nx
        taper = 1.0 - 0.15 * (u ** 1.4)
        for iy in range(ny + 1):
            v = iy / ny
            y_pos = -0.05 - u * flag_len
            z_center = z_bottom + flag_h * 0.5
            z_pos = z_center + (v - 0.5) * flag_h * taper
            x_wave = math.sin(u * math.pi * 2.2) * 0.05 * (u ** 1.1)
            verts[ix][iy] = bm.verts.new((x_wave, y_pos, z_pos))

    uv_layer = bm.loops.layers.uv.verify()
    for ix in range(nx):
        for iy in range(ny):
            f = bm.faces.new([verts[ix][iy], verts[ix + 1][iy], verts[ix + 1][iy + 1], verts[ix][iy + 1]])
            u0, u1 = ix / nx, (ix + 1) / nx
            v0, v1 = 1.0 - (iy / ny), 1.0 - ((iy + 1) / ny)
            for loop, uv in zip(f.loops, [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]):
                loop[uv_layer].uv = uv

    obj_cloth = create_mesh_obj("FlagCloth", bm, mat_cloth, smooth=True, uv_scale=None, parent=root)
    set_smooth(obj_cloth, True)

    export_asset(f"flag_{team_name}")


if __name__ == "__main__":
    print("Rebuilding Polished Arena Props (Doritos, Sandbags, Barricades, Crates, Pedestals, Flags)...")
    styles = [
        ("gold", (0.95, 0.70, 0.14, 1.0), (0.98, 0.98, 0.96, 1.0)),
        ("blue", (0.10, 0.46, 0.96, 1.0), (0.04, 0.88, 1.00, 1.0)),
        ("red",  (0.94, 0.24, 0.14, 1.0), (1.00, 0.74, 0.16, 1.0)),
    ]
    for s_name, pri, strp in styles:
        build_bunker_dorito(s_name, pri, strp)
        build_bunker_temple(s_name, pri, strp)
        build_bunker_cylinder(s_name, pri, strp)
        build_bunker_snake(s_name, pri, strp)

    build_barricade_wood()
    build_crate_stack()
    build_sandbag_wall()
    build_flag_pedestal("blue", (0.08, 0.44, 0.96, 1.0), (0.02, 0.88, 1.00, 1.0))
    build_flag_pedestal("red",  (0.95, 0.22, 0.12, 1.0), (1.00, 0.68, 0.14, 1.0))
    build_flag_assembly("blue", (0.08, 0.44, 0.96, 1.0), (0.02, 0.88, 1.00, 1.0), "flag_blue.png")
    build_flag_assembly("red",  (0.95, 0.22, 0.12, 1.0), (1.00, 0.68, 0.14, 1.0), "flag_red.png")
    print("Polished Arena Props complete!")
