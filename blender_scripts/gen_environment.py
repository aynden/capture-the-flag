#!/usr/bin/env python3
"""
POLISH PASS — Tournament Stadium & Lush Park Environment Assets in Blender 5.3.0:
- Fix #2: ArenaWallSegment with proud inner/outer tournament banners + translucent safety netting
          + new ArenaCornerTower seamlessly closing all 4 stadium corners!
- Fix #3: Deep rich evergreen StylizedPine + new StylizedOak broadleaf tree + Rolling Park Hills!
- Fix #10: SpectatorBleacher populated with cheerful stylized fans & hanging tournament pennants!
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


def build_arena_wall_segment():
    """6.0m jersey concrete barrier + proud tournament sponsor banners + safety netting mesh."""
    clear_scene()
    mat_conc = make_pbr_material(
        "WallConcrete",
        base_color=(0.94, 0.92, 0.88, 1.0),
        roughness=0.72,
        albedo_tex="concrete_albedo.png",
        normal_tex="concrete_normal.png",
        normal_strength=1.2,
        rough_tex="concrete_rough.png",
        tint_tex=True,
        uv_scale=(0.6, 0.6),
    )
    mat_steel = make_pbr_material("WallSteel", base_color=(0.15, 0.18, 0.23, 1.0), metallic=0.80, roughness=0.34)
    mat_banner = make_pbr_material(
        "ArenaBannerMat",
        base_color=(1.0, 1.0, 1.0, 1.0),
        roughness=0.38,
        coat=0.25,
        albedo_tex="banner_arena.png",
        double_sided=True,
    )
    mat_cap = make_pbr_material("WallCapTrim", base_color=(0.94, 0.70, 0.14, 1.0), roughness=0.32)
    mat_net = make_pbr_material(
        "SafetyNetting",
        base_color=(0.06, 0.08, 0.11, 1.0),
        roughness=0.85,
        alpha=0.22,
        double_sided=True,
    )

    root = make_empty("ArenaWallSegment")

    # Trapezoidal Jersey Concrete Barrier (6m long, 1.15m tall)
    bm = bmesh.new()
    L = 3.0
    b = [bm.verts.new((-L, -0.45, 0)), bm.verts.new((L, -0.45, 0)), bm.verts.new((L, 0.45, 0)), bm.verts.new((-L, 0.45, 0))]
    m = [bm.verts.new((-L, -0.34, 0.32)), bm.verts.new((L, -0.34, 0.32)), bm.verts.new((L, 0.34, 0.32)), bm.verts.new((-L, 0.34, 0.32))]
    t = [bm.verts.new((-L, -0.20, 1.15)), bm.verts.new((L, -0.20, 1.15)), bm.verts.new((L, 0.20, 1.15)), bm.verts.new((-L, 0.20, 1.15))]
    bm.faces.new(list(reversed(b)))
    bm.faces.new(t)
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new([b[i], b[j], m[j], m[i]])
        bm.faces.new([m[i], m[j], t[j], t[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=0.04, segments=2, affect="EDGES", clamp_overlap=True)
    create_mesh_obj("JerseyBarrier", bm, mat_conc, uv_scale=0.4, parent=root)

    create_mesh_obj("BarrierCapRail", bm_box((5.98, 0.44, 0.09), center=(0, 0, 1.17), bevel_width=0.015), mat_cap, parent=root)

    # Vertical steel netting stanchions + crossbars
    for px in (-2.85, 0.0, 2.85):
        create_mesh_obj(f"Stanchion_{px:.1f}", bm_box((0.12, 0.12, 2.25), center=(px, 0.0, 2.25), bevel_width=0.015), mat_steel, parent=root)
        create_mesh_obj(f"StanchionBracket_{px:.1f}", bm_box((0.20, 0.34, 0.16), center=(px, 0.0, 1.24), bevel_width=0.01), mat_steel, parent=root)
    create_mesh_obj("TopCrossbar", bm_cylinder(0.045, 6.0, segments=12, axis="X", center=(0, 0, 3.35)), mat_steel, parent=root)
    create_mesh_obj("MidCrossbar", bm_cylinder(0.032, 6.0, segments=12, axis="X", center=(0, 0, 2.25)), mat_steel, parent=root)

    # Translucent dark safety netting stretched cleanly between stanchions (1.20m .. 3.35m)
    bm_net = bmesh.new()
    nv = [bm_net.verts.new((-2.95, 0.0, 1.22)), bm_net.verts.new((2.95, 0.0, 1.22)), bm_net.verts.new((2.95, 0.0, 3.34)), bm_net.verts.new((-2.95, 0.0, 3.34))]
    bm_net.faces.new(nv)
    create_mesh_obj("SafetyNetting", bm_net, mat_net, smooth=False, uv_scale=1.0, parent=root)

    # Proudly mounted colorful Tournament Banners on BOTH sloped sides (+Y and -Y) so inner wall always pops!
    for y_sign, name_sfx in ((1.0, "PosY"), (-1.0, "NegY")):
        bm_ban = bmesh.new()
        v0 = bm_ban.verts.new((-2.68, y_sign * 0.37, 0.34))
        v1 = bm_ban.verts.new((2.68, y_sign * 0.37, 0.34))
        v2 = bm_ban.verts.new((2.68, y_sign * 0.25, 1.07))
        v3 = bm_ban.verts.new((-2.68, y_sign * 0.25, 1.07))
        f = bm_ban.faces.new([v0, v1, v2, v3] if y_sign > 0 else [v1, v0, v3, v2])
        uv_layer = bm_ban.loops.layers.uv.verify()
        for loop, uv in zip(f.loops, [(0, 0), (1, 0), (1, 1), (0, 1)]):
            loop[uv_layer].uv = uv
        create_mesh_obj(f"ArenaBanner_{name_sfx}", bm_ban, mat_banner, smooth=False, uv_scale=None, parent=root)

    export_asset("arena_wall_segment")


def build_arena_corner_tower():
    """Chunky architectural stadium corner pylon seamlessly joining perimeter walls."""
    clear_scene()
    mat_conc = make_pbr_material(
        "CornerConc",
        base_color=(0.94, 0.92, 0.88, 1.0),
        roughness=0.70,
        albedo_tex="concrete_albedo.png",
        normal_tex="concrete_normal.png",
        tint_tex=True,
    )
    mat_steel = make_pbr_material("CornerSteel", base_color=(0.16, 0.19, 0.24, 1.0), metallic=0.82, roughness=0.30)
    mat_gold = make_pbr_material("CornerGold", base_color=(0.96, 0.72, 0.14, 1.0), roughness=0.26, coat=0.4)
    mat_glow = make_pbr_material("CornerBeacon", base_color=(1.0, 0.85, 0.35, 1.0), emission=(1.0, 0.82, 0.32, 1.0), emission_strength=2.4)

    root = make_empty("ArenaCornerTower")
    create_mesh_obj("CornerBase", bm_box((1.35, 1.35, 1.30), center=(0, 0, 0.65), bevel_width=0.06), mat_conc, parent=root)
    create_mesh_obj("CornerGoldTrim", bm_box((1.42, 1.42, 0.14), center=(0, 0, 1.24), bevel_width=0.02), mat_gold, parent=root)
    create_mesh_obj("CornerColumn", bm_box((0.52, 0.52, 2.35), center=(0, 0, 2.45), bevel_width=0.04), mat_steel, parent=root)
    create_mesh_obj("CornerCap", bm_box((0.68, 0.68, 0.16), center=(0, 0, 3.65), bevel_width=0.03), mat_steel, parent=root)
    create_mesh_obj("CornerBeacon", bm_sphere(0.16, scale=(1.0, 1.0, 1.3), center=(0, 0, 3.92), segs=12, rings=8), mat_glow, parent=root)

    export_asset("arena_corner_tower")


def build_floodlight_tower():
    clear_scene()
    mat_steel = make_pbr_material("TowerSteel", base_color=(0.18, 0.21, 0.26, 1.0), metallic=0.80, roughness=0.34)
    mat_conc = make_pbr_material(
        "TowerConcrete",
        base_color=(0.94, 0.92, 0.88, 1.0),
        roughness=0.72,
        albedo_tex="concrete_albedo.png",
        normal_tex="concrete_normal.png",
        tint_tex=True,
    )
    mat_lamp_housing = make_pbr_material("LampHousing", base_color=(0.13, 0.15, 0.19, 1.0), metallic=0.72, roughness=0.3)
    mat_lamp_glow = make_pbr_material(
        "LampLensGlow",
        base_color=(1.0, 0.95, 0.80, 1.0),
        roughness=0.1,
        emission=(1.0, 0.90, 0.68, 1.0),
        emission_strength=5.5,
    )

    root = make_empty("FloodlightTower")
    create_mesh_obj("Footing", bm_cone(0.78, 0.62, 0.88, segments=8, center=(0, 0, 0.44), bevel_width=0.04), mat_conc, parent=root)
    create_mesh_obj("MainPole", bm_cone(0.28, 0.14, 9.2, segments=12, center=(0, 0, 5.2), bevel_width=0.015), mat_steel, parent=root)
    for cz in (2.5, 5.0, 7.5):
        create_mesh_obj(f"Collar_{cz:.1f}", bm_cylinder(0.26 - cz * 0.012, 0.16, segments=12, center=(0, 0, cz), bevel_width=0.01), mat_steel, parent=root)

    gantry = make_empty("LampGantry", (0, 0.15, 9.55), (0.48, 0, 0), parent=root)
    create_mesh_obj("CrossBar", bm_box((3.2, 0.18, 0.18), center=(0, 0, 0), bevel_width=0.02), mat_steel, parent=gantry)
    create_mesh_obj("TopCrossBar", bm_box((3.0, 0.14, 0.14), center=(0, 0, 0.62), bevel_width=0.02), mat_steel, parent=gantry)
    for idx, lx in enumerate((-1.15, -0.38, 0.38, 1.15)):
        create_mesh_obj(f"LampBody_{idx}", bm_box((0.64, 0.32, 0.48), center=(lx, 0.12, 0.30), bevel_width=0.03), mat_lamp_housing, parent=gantry)
        create_mesh_obj(f"LampLens_{idx}", bm_box((0.54, 0.06, 0.38), center=(lx, 0.28, 0.30), bevel_width=0.01), mat_lamp_glow, parent=gantry)

    export_asset("floodlight_tower")


def build_stylized_pine():
    """Deep, rich, sunlit Pacific-Northwest evergreen pine (no chalky pale mint!)."""
    clear_scene()
    mat_bark = make_pbr_material("PineBark", base_color=(0.28, 0.16, 0.09, 1.0), roughness=0.90)
    mat_fol_dark = make_pbr_material("PineFoliageDark", base_color=(0.06, 0.20, 0.10, 1.0), roughness=0.78)
    mat_fol_mid = make_pbr_material("PineFoliageMid", base_color=(0.09, 0.28, 0.12, 1.0), roughness=0.74)
    mat_fol_sun = make_pbr_material("PineFoliageSun", base_color=(0.16, 0.38, 0.14, 1.0), roughness=0.70)

    root = make_empty("StylizedPine")
    create_mesh_obj("Trunk", bm_cone(0.38, 0.12, 3.2, segments=10, center=(0, 0, 1.6)), mat_bark, parent=root)

    tiers = [
        (2.4, 2.35, 0.72, 2.25, mat_fol_dark, 0.0),
        (3.85, 1.88, 0.52, 2.15, mat_fol_mid, 0.38),
        (5.2, 1.42, 0.34, 1.90, mat_fol_mid, 0.75),
        (6.45, 0.94, 0.06, 1.70, mat_fol_sun, 1.10),
    ]
    for i, (z_c, r1, r2, h, mat, rot_z) in enumerate(tiers):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=16, radius1=r1, radius2=r2, depth=h)
        for v in bm.verts:
            if v.co.z < 0.0:
                ang = math.atan2(v.co.y, v.co.x)
                scallop = 1.0 + 0.16 * math.sin(ang * 8.0 + i * 1.4)
                v.co.x *= scallop
                v.co.y *= scallop
                v.co.z -= 0.16 * math.cos(ang * 8.0 + i)
        bmesh.ops.translate(bm, vec=(0, 0, z_c), verts=bm.verts)
        bmesh.ops.bevel(bm, geom=[e for e in bm.edges if len(e.link_faces) == 2], offset=0.05, segments=1, affect="EDGES", clamp_overlap=True)
        create_mesh_obj(f"PineTier_{i}", bm, mat, rotation=(0, 0, rot_z), parent=root)

    export_asset("stylized_pine")


def build_stylized_oak():
    """Warm golden-hour broadleaf park tree to add rich silhouette variety alongside pines!"""
    clear_scene()
    mat_bark = make_pbr_material("OakBark", base_color=(0.30, 0.18, 0.10, 1.0), roughness=0.90)
    mat_deep = make_pbr_material("OakLeafDeep", base_color=(0.12, 0.30, 0.11, 1.0), roughness=0.76)
    mat_warm = make_pbr_material("OakLeafWarm", base_color=(0.22, 0.42, 0.13, 1.0), roughness=0.72)
    mat_gold = make_pbr_material("OakLeafGold", base_color=(0.42, 0.50, 0.14, 1.0), roughness=0.68)

    root = make_empty("StylizedOak")
    create_mesh_obj("OakTrunk", bm_cone(0.42, 0.24, 3.0, segments=10, center=(0, 0, 1.5)), mat_bark, parent=root)
    # Angled boughs
    create_mesh_obj("Branch1", bm_cone(0.18, 0.09, 1.8, segments=8, center=(0.55, 0.2, 3.0)), mat_bark, rotation=(0.2, 0.55, 0), parent=root)
    create_mesh_obj("Branch2", bm_cone(0.18, 0.09, 1.8, segments=8, center=(-0.55, -0.2, 2.9)), mat_bark, rotation=(-0.2, -0.58, 0), parent=root)

    clusters = [
        (0.0, 0.0, 4.5, 1.75, (1.15, 1.10, 0.88), mat_warm),
        (-1.25, 0.35, 3.9, 1.25, (1.08, 1.05, 0.86), mat_deep),
        (1.30, -0.25, 4.0, 1.30, (1.10, 1.02, 0.85), mat_deep),
        (0.25, 1.15, 3.85, 1.18, (1.05, 1.05, 0.84), mat_deep),
        (-0.30, -1.10, 3.8, 1.15, (1.05, 1.05, 0.82), mat_deep),
        (0.45, 0.20, 5.45, 1.15, (1.12, 1.08, 0.78), mat_gold),
        (-0.65, -0.25, 5.15, 0.98, (1.05, 1.0, 0.80), mat_gold),
    ]
    for i, (x, y, z, r, sc, mat) in enumerate(clusters):
        create_mesh_obj(f"OakCanopy_{i}", bm_sphere(r, scale=sc, center=(x, y, z), segs=16, rings=12), mat, parent=root)

    export_asset("stylized_oak")


def build_stylized_bush():
    clear_scene()
    mat_dark = make_pbr_material("BushDark", base_color=(0.08, 0.24, 0.11, 1.0), roughness=0.78)
    mat_mid = make_pbr_material("BushMid", base_color=(0.14, 0.35, 0.14, 1.0), roughness=0.72)
    mat_top = make_pbr_material("BushTop", base_color=(0.24, 0.48, 0.17, 1.0), roughness=0.68)

    root = make_empty("StylizedBush")
    puffs = [
        (0.0, 0.0, 0.58, 0.85, (1.15, 1.05, 0.82), mat_mid),
        (-0.65, 0.18, 0.46, 0.65, (1.05, 0.95, 0.80), mat_dark),
        (0.68, -0.14, 0.48, 0.68, (1.0, 1.1, 0.82), mat_dark),
        (0.18, 0.45, 0.52, 0.62, (1.05, 0.95, 0.88), mat_mid),
        (-0.22, -0.40, 0.45, 0.60, (1.1, 0.95, 0.78), mat_dark),
        (0.10, 0.06, 0.92, 0.52, (1.1, 1.0, 0.75), mat_top),
        (-0.35, 0.12, 0.76, 0.42, (1.0, 1.0, 0.80), mat_top),
    ]
    for i, (x, y, z, r, sc, mat) in enumerate(puffs):
        create_mesh_obj(f"BushPuff_{i}", bm_sphere(r, scale=sc, center=(x, y, z), segs=16, rings=12), mat, parent=root)

    export_asset("stylized_bush")


def build_spectator_bleacher():
    """Tournament bleacher stand WITH cheerful stylized fans & hanging team pennants!"""
    clear_scene()
    mat_wood = make_pbr_material(
        "BleacherWood",
        base_color=(1.0, 1.0, 1.0, 1.0),
        roughness=0.58,
        albedo_tex="wood_plank_albedo.png",
        normal_tex="wood_plank_normal.png",
        uv_scale=(0.8, 0.8),
    )
    mat_steel = make_pbr_material("BleacherSteel", base_color=(0.18, 0.21, 0.26, 1.0), metallic=0.80, roughness=0.34)
    mat_canopy = make_pbr_material("BleacherCanopy", base_color=(0.95, 0.94, 0.90, 1.0), roughness=0.55)
    mat_trim = make_pbr_material("BleacherGold", base_color=(0.95, 0.70, 0.14, 1.0), roughness=0.32)

    # Spectator fan jersey palette (Cobalt, Ember, Gold, White, Teal)
    fan_mats = [
        make_pbr_material("FanBlue", base_color=(0.10, 0.48, 0.96, 1.0), roughness=0.55),
        make_pbr_material("FanRed", base_color=(0.94, 0.26, 0.14, 1.0), roughness=0.55),
        make_pbr_material("FanGold", base_color=(0.96, 0.74, 0.16, 1.0), roughness=0.55),
        make_pbr_material("FanWhite", base_color=(0.92, 0.94, 0.96, 1.0), roughness=0.55),
        make_pbr_material("FanSlate", base_color=(0.24, 0.30, 0.38, 1.0), roughness=0.58),
    ]
    mat_skin = make_pbr_material("FanHead", base_color=(0.86, 0.68, 0.54, 1.0), roughness=0.62)

    root = make_empty("SpectatorBleacher")

    for row in range(4):
        y = -row * 0.78
        z = 0.46 + row * 0.46
        create_mesh_obj(f"SeatBench_{row}", bm_box((7.4, 0.42, 0.08), center=(0, y, z), bevel_width=0.012), mat_wood, parent=root)
        create_mesh_obj(f"FootDeck_{row}", bm_box((7.4, 0.34, 0.06), center=(0, y + 0.36, z - 0.30), bevel_width=0.01), mat_steel, parent=root)

    for sx in (-3.4, -1.15, 1.15, 3.4):
        create_mesh_obj(f"RiserBack_{sx:.1f}", bm_box((0.14, 0.14, 3.55), center=(sx, -2.55, 1.78), bevel_width=0.015), mat_steel, parent=root)
        create_mesh_obj(f"RiserFront_{sx:.1f}", bm_box((0.12, 0.12, 0.55), center=(sx, 0.25, 0.28), bevel_width=0.012), mat_steel, parent=root)
        create_mesh_obj(f"RiserDiag_{sx:.1f}", bm_box((0.12, 3.3, 0.14), center=(sx, -1.15, 1.10), bevel_width=0.012), mat_steel, rotation=(-0.52, 0, 0), parent=root)

    create_mesh_obj("CanopyRoof", bm_box((7.8, 3.4, 0.10), center=(0, -1.25, 3.65), bevel_width=0.025), mat_canopy, rotation=(0.14, 0, 0), parent=root)
    create_mesh_obj("CanopyFascia", bm_box((7.84, 0.14, 0.24), center=(0, 0.42, 3.84), bevel_width=0.015), mat_trim, parent=root)

    # Festive hanging triangular tournament pennants along canopy front edge!
    for idx in range(9):
        px = -3.2 + idx * 0.8
        p_mat = fan_mats[idx % 3]
        create_mesh_obj(f"Pennant_{idx}", bm_cone(0.22, 0.02, 0.42, segments=4, center=(px, 0.48, 3.52)), p_mat, rotation=(math.pi, 0, 0), parent=root)

    for sx in (-3.65, 3.65):
        create_mesh_obj(f"SideRail_{sx:.1f}", bm_box((0.06, 2.9, 0.06), center=(sx, -1.15, 1.85), bevel_width=0.01), mat_trim, rotation=(-0.52, 0, 0), parent=root)

    # Cheerful stylized spectators seated across the 4 rows!
    fan_spots = [
        (0, -2.7), (0, -1.3), (0, 0.2), (0, 1.8), (0, 2.9),
        (1, -2.1), (1, -0.6), (1, 1.1), (1, 2.5),
        (2, -2.9), (2, -1.5), (2, 0.5), (2, 1.9), (2, 3.1),
        (3, -2.3), (3, -0.3), (3, 1.4), (3, 2.8),
    ]
    for f_i, (row, fx) in enumerate(fan_spots):
        fy = -row * 0.78
        fz = 0.50 + row * 0.46
        fmat = fan_mats[(f_i * 7 + row * 3) % len(fan_mats)]
        create_mesh_obj(f"FanTorso_{f_i}", bm_capsule(0.18, 0.56, segs=10, rings=6, center=(fx, fy, fz + 0.30)), fmat, parent=root)
        create_mesh_obj(f"FanHead_{f_i}", bm_sphere(0.15, center=(fx, fy + 0.02, fz + 0.72), segs=10, rings=8), mat_skin, parent=root)
        # Cute sports cap on half the fans
        if f_i % 2 == 0:
            create_mesh_obj(f"FanCap_{f_i}", bm_sphere(0.155, scale=(1.0, 1.15, 0.55), center=(fx, fy + 0.05, fz + 0.80), segs=10, rings=6), fmat, parent=root)

    export_asset("spectator_bleacher")


if __name__ == "__main__":
    print("Rebuilding Polished Stadium & Park Environment Assets...")
    build_arena_wall_segment()
    build_arena_corner_tower()
    build_floodlight_tower()
    build_stylized_pine()
    build_stylized_oak()
    build_stylized_bush()
    build_spectator_bleacher()
    print("Polished Environment assets complete!")
