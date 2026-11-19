#!/usr/bin/env python3
"""
Generates stylized heroic articulated Paintball Competitors (Team Cobalt Blue & Team Ember Coral)
with integrated electronic tournament Paintball Markers, HPA tanks, translucent hoppers filled
with paintballs, thermal visor masks, and 4-pod back harnesses.

Orientation: +Y forward in Blender -> -Z forward in Godot (canonical Godot forward).
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
    export_asset,
)


def build_character(team_name, primary, secondary, accent, paint_col):
    clear_scene()

    # Deliberate cohesive materials
    mat_jersey = make_pbr_material(
        f"{team_name}_Jersey",
        base_color=primary,
        roughness=0.52,
        coat=0.08,
        albedo_tex="vinyl_bunker_albedo.png",
        normal_tex="vinyl_bunker_normal.png",
        normal_strength=0.45,
        tint_tex=True,
        uv_scale=(3.0, 3.0),
    )
    mat_armor = make_pbr_material(
        f"{team_name}_Armor",
        base_color=secondary,
        roughness=0.34,
        metallic=0.15,
        coat=0.35,
    )
    mat_accent = make_pbr_material(
        f"{team_name}_Accent",
        base_color=accent,
        roughness=0.25,
        emission=accent,
        emission_strength=0.65,
    )
    mat_white = make_pbr_material(
        f"{team_name}_TrimWhite",
        base_color=(0.94, 0.95, 0.96, 1.0),
        roughness=0.32,
        coat=0.25,
    )
    mat_charcoal = make_pbr_material(
        f"{team_name}_Charcoal",
        base_color=(0.09, 0.11, 0.14, 1.0),
        roughness=0.52,
        metallic=0.14,
    )
    mat_pants = make_pbr_material(
        f"{team_name}_Pants",
        base_color=(0.11, 0.13, 0.17, 1.0),
        roughness=0.64,
    )
    mat_visor = make_pbr_material(
        f"{team_name}_VisorGlass",
        base_color=(0.04, 0.06, 0.10, 1.0),
        metallic=0.35,
        roughness=0.06,
        coat=1.0,
        coat_roughness=0.03,
        emission=accent,
        emission_strength=0.18,
    )
    mat_metal = make_pbr_material(
        f"{team_name}_GunMetal",
        base_color=(0.24, 0.27, 0.32, 1.0),
        metallic=0.82,
        roughness=0.26,
    )
    mat_anodized = make_pbr_material(
        f"{team_name}_Anodized",
        base_color=primary,
        metallic=0.72,
        roughness=0.22,
        coat=0.4,
    )
    mat_brass = make_pbr_material(
        f"{team_name}_Brass",
        base_color=(0.82, 0.64, 0.26, 1.0),
        metallic=0.88,
        roughness=0.25,
    )
    mat_hopper_smoke = make_pbr_material(
        f"{team_name}_HopperSmoke",
        base_color=(0.12, 0.14, 0.18, 1.0),
        roughness=0.12,
        coat=0.9,
        alpha=0.45,
    )
    mat_paintball = make_pbr_material(
        f"{team_name}_PaintballGlow",
        base_color=paint_col,
        roughness=0.10,
        coat=1.0,
        emission=paint_col,
        emission_strength=0.9,
    )

    root = make_empty("CharacterRoot", (0, 0, 0))

    # ==================== LEGS (Hip pivots at Z=0.84) ====================
    for side, sx in (("L", -1.0), ("R", 1.0)):
        leg_piv = make_empty(f"Leg{side}", (sx * 0.15, 0.0, 0.84), parent=root)
        # Upper thigh
        create_mesh_obj(
            f"Thigh_{side}",
            bm_capsule(0.115, 0.44, center=(0, 0.01, -0.20)),
            mat_pants,
            parent=leg_piv,
        )
        # Sculpted athletic knee pad (team-colored protective shell)
        create_mesh_obj(
            f"KneePad_{side}",
            bm_sphere(0.10, scale=(0.95, 0.72, 1.15), center=(0, 0.085, -0.40)),
            mat_armor,
            parent=leg_piv,
        )
        create_mesh_obj(
            f"KneeTrim_{side}",
            bm_box((0.11, 0.04, 0.05), center=(0, 0.14, -0.40), bevel_width=0.015),
            mat_accent,
            parent=leg_piv,
        )
        # Lower shin
        create_mesh_obj(
            f"Shin_{side}",
            bm_capsule(0.095, 0.42, center=(0, -0.01, -0.58)),
            mat_pants,
            parent=leg_piv,
        )
        # Athletic cleated paintball boot
        create_mesh_obj(
            f"BootUpper_{side}",
            bm_box((0.16, 0.30, 0.13), center=(0, 0.05, -0.76), bevel_width=0.045, bevel_segs=3),
            mat_charcoal,
            parent=leg_piv,
        )
        create_mesh_obj(
            f"BootSole_{side}",
            bm_box((0.175, 0.32, 0.045), center=(0, 0.055, -0.82), bevel_width=0.015),
            mat_white,
            parent=leg_piv,
        )
        create_mesh_obj(
            f"BootStripe_{side}",
            bm_box((0.168, 0.14, 0.035), center=(0, 0.08, -0.75), bevel_width=0.01),
            mat_jersey,
            parent=leg_piv,
        )

    # ==================== UPPER BODY (Waist pivot at Z=0.86) ====================
    upper = make_empty("UpperBody", (0.0, 0.0, 0.86), parent=root)

    # Hips / Pelvis
    create_mesh_obj(
        "Pelvis",
        bm_box((0.40, 0.27, 0.20), center=(0, 0, 0.02), bevel_width=0.075, bevel_segs=3),
        mat_pants,
        parent=upper,
    )
    # Tactical utility belt
    create_mesh_obj(
        "Belt",
        bm_box((0.44, 0.30, 0.085), center=(0, 0, 0.09), bevel_width=0.025),
        mat_charcoal,
        parent=upper,
    )
    create_mesh_obj(
        "BeltBuckle",
        bm_box((0.11, 0.06, 0.075), center=(0, 0.14, 0.09), bevel_width=0.015),
        mat_accent,
        parent=upper,
    )

    # Athletic tapered torso jersey
    bm_torso = bmesh.new()
    bmesh.ops.create_cone(bm_torso, cap_ends=True, cap_tris=False, segments=20, radius1=0.20, radius2=0.28, depth=0.52)
    bmesh.ops.scale(bm_torso, vec=(1.12, 0.78, 1.0), verts=bm_torso.verts)
    bmesh.ops.translate(bm_torso, vec=(0, 0, 0.36), verts=bm_torso.verts)
    bmesh.ops.bevel(bm_torso, geom=[e for e in bm_torso.edges if len(e.link_faces) == 2 and abs(e.link_faces[0].normal.dot(e.link_faces[1].normal)) < 0.6], offset=0.05, segments=3, affect="EDGES", clamp_overlap=True)
    create_mesh_obj("TorsoJersey", bm_torso, mat_jersey, parent=upper)

    # Sculpted Front Chest Protector Plate (crisp layered armor look)
    create_mesh_obj(
        "ChestPlateMain",
        bm_box((0.40, 0.14, 0.34), center=(0, 0.155, 0.40), bevel_width=0.045, bevel_segs=3),
        mat_armor,
        parent=upper,
    )
    create_mesh_obj(
        "ChestAccentV",
        bm_box((0.26, 0.06, 0.10), center=(0, 0.215, 0.46), bevel_width=0.02),
        mat_white,
        parent=upper,
    )
    create_mesh_obj(
        "ChestCoreLED",
        bm_box((0.10, 0.04, 0.06), center=(0, 0.23, 0.46), bevel_width=0.012),
        mat_accent,
        parent=upper,
    )

    # Back Armor Plate & Shoulder Yoke (HIGH VISIBILITY from top-down camera!)
    create_mesh_obj(
        "BackPlate",
        bm_box((0.38, 0.14, 0.36), center=(0, -0.15, 0.40), bevel_width=0.045, bevel_segs=3),
        mat_armor,
        parent=upper,
    )
    create_mesh_obj(
        "ShoulderYoke",
        bm_box((0.62, 0.28, 0.14), center=(0, 0.0, 0.58), bevel_width=0.055, bevel_segs=3),
        mat_white,
        parent=upper,
    )
    create_mesh_obj(
        "CollarGuard",
        bm_cylinder(0.145, 0.10, segments=20, center=(0, 0.0, 0.64), bevel_width=0.02),
        mat_charcoal,
        parent=upper,
    )

    # Iconic 4-Pod Paintball Harness Pack on lower back!
    pod_pack = make_empty("PodPack", (0.0, -0.23, 0.18), parent=upper)
    create_mesh_obj(
        "HarnessStrap",
        bm_box((0.40, 0.10, 0.14), center=(0, 0.02, 0.0), bevel_width=0.025),
        mat_charcoal,
        parent=pod_pack,
    )
    for idx, px in enumerate((-0.14, -0.048, 0.048, 0.14)):
        tilt = (idx - 1.5) * 0.05
        create_mesh_obj(
            f"PodTube_{idx}",
            bm_cylinder(0.036, 0.25, segments=14, center=(px, -0.03, 0.02), bevel_width=0.008),
            mat_hopper_smoke,
            rotation=(0.14, tilt, 0.0),
            parent=pod_pack,
        )
        create_mesh_obj(
            f"PodPaintCore_{idx}",
            bm_cylinder(0.028, 0.20, segments=12, center=(px, -0.03, 0.015)),
            mat_paintball,
            rotation=(0.14, tilt, 0.0),
            parent=pod_pack,
        )
        create_mesh_obj(
            f"PodCap_{idx}",
            bm_cylinder(0.040, 0.032, segments=14, center=(px, -0.048, 0.145), bevel_width=0.008),
            mat_accent,
            rotation=(0.14, tilt, 0.0),
            parent=pod_pack,
        )

    # Anchor where a captured enemy flag attaches on the runner's back
    make_empty("FlagAnchor", (0.0, -0.25, 0.46), parent=upper)

    # ==================== HEAD & THERMAL PAINTBALL MASK ====================
    head = make_empty("Head", (0.0, 0.02, 0.68), parent=upper)

    # Neck
    create_mesh_obj("Neck", bm_cylinder(0.085, 0.12, segments=16, center=(0, 0, 0.02)), mat_charcoal, parent=head)

    # Aerodynamic Paintball Helmet Dome (high readability from top-down!)
    create_mesh_obj(
        "HelmetShell",
        bm_sphere(0.225, scale=(0.94, 1.08, 1.02), center=(0, -0.01, 0.20), segs=28, rings=18),
        mat_jersey,
        parent=head,
    )
    # Bold white/accent racing crest stripe along the top of the helmet (pops in top-down!)
    create_mesh_obj(
        "HelmetCrest",
        bm_box((0.095, 0.36, 0.09), center=(0, -0.01, 0.39), bevel_width=0.035, bevel_segs=3),
        mat_white,
        parent=head,
    )
    create_mesh_obj(
        "HelmetCrestGlow",
        bm_box((0.045, 0.28, 0.05), center=(0, -0.01, 0.425), bevel_width=0.015),
        mat_accent,
        parent=head,
    )
    # Helmet front sun visor peak
    create_mesh_obj(
        "HelmetBrim",
        bm_box((0.32, 0.16, 0.045), center=(0, 0.19, 0.285), bevel_width=0.018),
        mat_armor,
        rotation=(0.24, 0, 0),
        parent=head,
    )
    # Wrap-around Glossy Thermal Paintball Goggle Lens
    create_mesh_obj(
        "ThermalVisor",
        bm_sphere(0.21, scale=(0.96, 0.92, 0.56), center=(0, 0.065, 0.19), segs=28, rings=14),
        mat_visor,
        parent=head,
    )
    # Goggle frame rim
    create_mesh_obj(
        "GoggleStrap",
        bm_cylinder(0.228, 0.085, segments=26, center=(0, -0.015, 0.195), bevel_width=0.012),
        mat_charcoal,
        parent=head,
    )
    # Sculpted Lower Jaw/Chin Paintball Mask (aggressive angular V-guard)
    create_mesh_obj(
        "MaskJaw",
        bm_cone(0.16, 0.20, 0.18, segments=16, center=(0, 0.095, 0.06), bevel_width=0.03),
        mat_armor,
        rotation=(-0.18, 0, 0),
        parent=head,
    )
    create_mesh_obj(
        "MaskChinAccent",
        bm_box((0.12, 0.08, 0.08), center=(0, 0.22, 0.055), bevel_width=0.02),
        mat_white,
        parent=head,
    )
    # Ear protection pods
    for sx in (-1.0, 1.0):
        create_mesh_obj(
            f"EarGuard_{'L' if sx < 0 else 'R'}",
            bm_cylinder(0.075, 0.06, segments=16, axis="X", center=(sx * 0.22, -0.01, 0.16), bevel_width=0.015),
            mat_white,
            parent=head,
        )

    # ==================== ARMS & SHOULDER PAULDRONS ====================
    # Right Arm (trigger hand holding paintball marker pistol grip cleanly at local ~(0.20, 0.37, 0.25))
    arm_r = make_empty("ArmR", (0.31, 0.02, 0.50), parent=upper)
    create_mesh_obj("PauldronR", bm_sphere(0.145, scale=(1.08, 1.18, 0.94), center=(0.02, 0, 0.03)), mat_jersey, parent=arm_r)
    create_mesh_obj("PauldronTrimR", bm_box((0.12, 0.18, 0.055), center=(0.06, 0, 0.115), bevel_width=0.015), mat_accent, parent=arm_r)
    create_mesh_obj("UpperArmR", bm_capsule(0.085, 0.30, center=(0.01, 0.08, -0.11)), mat_jersey, rotation=(0.48, 0, 0.08), parent=arm_r)
    create_mesh_obj("ElbowPadR", bm_sphere(0.088, scale=(0.95, 1.05, 1.0), center=(-0.01, 0.16, -0.23)), mat_armor, parent=arm_r)
    create_mesh_obj("ForearmR", bm_capsule(0.075, 0.26, center=(-0.06, 0.27, -0.24), axis="Y"), mat_charcoal, rotation=(0.0, 0, 0.34), parent=arm_r)
    create_mesh_obj("GloveR", bm_sphere(0.074, scale=(0.95, 1.15, 0.92), center=(-0.11, 0.36, -0.24)), mat_armor, parent=arm_r)

    # Left Arm (reaching cleanly across to clasp marker vertical foregrip at local ~(0.20, 0.59, 0.25))
    arm_l = make_empty("ArmL", (-0.31, 0.02, 0.50), parent=upper)
    create_mesh_obj("PauldronL", bm_sphere(0.145, scale=(1.08, 1.18, 0.94), center=(-0.02, 0, 0.03)), mat_jersey, parent=arm_l)
    create_mesh_obj("PauldronTrimL", bm_box((0.12, 0.18, 0.055), center=(-0.06, 0, 0.115), bevel_width=0.015), mat_accent, parent=arm_l)
    create_mesh_obj("UpperArmL", bm_capsule(0.085, 0.34, center=(0.08, 0.15, -0.11)), mat_jersey, rotation=(0.72, 0, -0.45), parent=arm_l)
    create_mesh_obj("ElbowPadL", bm_sphere(0.088, scale=(0.95, 1.05, 1.0), center=(0.16, 0.28, -0.23)), mat_armor, parent=arm_l)
    create_mesh_obj("ForearmL", bm_capsule(0.075, 0.36, center=(0.33, 0.42, -0.24), axis="Y"), mat_charcoal, rotation=(0.0, 0, -0.82), parent=arm_l)
    create_mesh_obj("GloveL", bm_sphere(0.074, scale=(0.95, 1.15, 0.92), center=(0.49, 0.55, -0.24)), mat_armor, parent=arm_l)

    # ==================== ELECTRONIC TOURNAMENT PAINTBALL MARKER ====================
    marker = make_empty("MarkerPivot", (0.20, 0.42, 0.34), parent=upper)

    # Machined Anodized Receiver Body
    create_mesh_obj(
        "MarkerReceiver",
        bm_box((0.085, 0.36, 0.115), center=(0, 0.06, 0.02), bevel_width=0.02, bevel_segs=3),
        mat_anodized,
        parent=marker,
    )
    # Upper bolt cylinder
    create_mesh_obj(
        "MarkerBoltTube",
        bm_cylinder(0.036, 0.38, segments=16, axis="Y", center=(0, 0.05, 0.075), bevel_width=0.008),
        mat_metal,
        parent=marker,
    )
    # Accent racing strip along receiver sides
    create_mesh_obj(
        "MarkerStripe",
        bm_box((0.094, 0.26, 0.028), center=(0, 0.06, 0.035), bevel_width=0.006),
        mat_accent,
        parent=marker,
    )
    # Long Ported Tournament Barrel
    create_mesh_obj(
        "MarkerBarrelBack",
        bm_cylinder(0.028, 0.22, segments=18, axis="Y", center=(0, 0.33, 0.055), bevel_width=0.005),
        mat_anodized,
        parent=marker,
    )
    create_mesh_obj(
        "MarkerBarrelTip",
        bm_cylinder(0.024, 0.32, segments=18, axis="Y", center=(0, 0.57, 0.055), bevel_width=0.005),
        mat_metal,
        parent=marker,
    )
    # Contrasting bright muzzle crown ring
    create_mesh_obj(
        "MarkerMuzzleCrown",
        bm_cylinder(0.031, 0.045, segments=18, axis="Y", center=(0, 0.72, 0.055), bevel_width=0.006),
        mat_accent,
        parent=marker,
    )
    # Trigger frame & pistol grip + front vertical air regulator foregrip
    create_mesh_obj(
        "PistolGrip",
        bm_box((0.062, 0.085, 0.17), center=(0, -0.05, -0.09), bevel_width=0.015),
        mat_charcoal,
        rotation=(-0.22, 0, 0),
        parent=marker,
    )
    create_mesh_obj(
        "ForegripReg",
        bm_cylinder(0.032, 0.16, segments=16, center=(0, 0.17, -0.09), bevel_width=0.008),
        mat_charcoal,
        rotation=(0.10, 0, 0),
        parent=marker,
    )
    create_mesh_obj(
        "TriggerGuard",
        bm_box((0.042, 0.16, 0.025), center=(0, 0.06, -0.155), bevel_width=0.008),
        mat_metal,
        parent=marker,
    )
    # Rear Compressed-Air HPA Carbon Tank (iconic paintball marker silhouette!)
    create_mesh_obj(
        "HPABrassReg",
        bm_cylinder(0.034, 0.08, segments=16, axis="Y", center=(0, -0.14, -0.115), bevel_width=0.006),
        mat_brass,
        parent=marker,
    )
    create_mesh_obj(
        "HPACarbonTank",
        bm_capsule(0.068, 0.28, segs=18, rings=8, center=(0, -0.29, -0.115), axis="Y"),
        mat_charcoal,
        parent=marker,
    )
    create_mesh_obj(
        "HPATankBand",
        bm_cylinder(0.071, 0.05, segments=18, axis="Y", center=(0, -0.29, -0.115), bevel_width=0.005),
        mat_accent,
        parent=marker,
    )

    # Top Electronic Paintball Hopper / Loader (curved egg shell + visible glowing paintballs!)
    create_mesh_obj(
        "Feedneck",
        bm_cylinder(0.032, 0.10, segments=16, center=(0, 0.09, 0.14), bevel_width=0.006),
        mat_metal,
        parent=marker,
    )
    # Translucent smoked hopper shell
    create_mesh_obj(
        "HopperShell",
        bm_sphere(0.115, scale=(0.82, 1.48, 0.92), center=(0.0, 0.04, 0.255), segs=22, rings=14),
        mat_hopper_smoke,
        parent=marker,
    )
    # Hopper top speed-feed lid rim
    create_mesh_obj(
        "HopperLid",
        bm_cylinder(0.068, 0.025, segments=16, center=(0.0, -0.02, 0.35), bevel_width=0.008),
        mat_anodized,
        rotation=(-0.18, 0, 0),
        parent=marker,
    )
    # Cluster of bright glowing paintballs visible inside the hopper!
    pb_offsets = [
        (0.00, 0.05, 0.24),
        (-0.04, 0.09, 0.24),
        (0.04, 0.09, 0.24),
        (-0.04, 0.01, 0.24),
        (0.04, 0.01, 0.24),
        (0.00, -0.05, 0.25),
        (-0.03, 0.05, 0.29),
        (0.03, 0.05, 0.29),
        (0.00, 0.12, 0.27),
        (0.00, 0.00, 0.29),
    ]
    for i, pos in enumerate(pb_offsets):
        create_mesh_obj(f"HopperBall_{i}", bm_sphere(0.030, center=pos, segs=10, rings=8), mat_paintball, parent=marker)

    # Muzzle Point empty at barrel tip for Godot projectiles & muzzle VFX!
    make_empty("MuzzlePoint", (0.0, 0.77, 0.055), parent=marker)

    export_asset(f"player_{team_name}")


if __name__ == "__main__":
    print("Building Team Cobalt (Blue) & Team Ember (Red) Paintball Competitors...")
    # Team Cobalt (Blue)
    build_character(
        "blue",
        primary=(0.08, 0.42, 0.94, 1.0),
        secondary=(0.06, 0.18, 0.42, 1.0),
        accent=(0.02, 0.86, 1.00, 1.0),
        paint_col=(0.06, 0.72, 1.00, 1.0),
    )
    # Team Ember (Coral-Orange / Vermilion)
    build_character(
        "red",
        primary=(0.95, 0.21, 0.12, 1.0),
        secondary=(0.40, 0.10, 0.08, 1.0),
        accent=(1.00, 0.66, 0.12, 1.0),
        paint_col=(1.00, 0.36, 0.12, 1.0),
    )
    print("Character assets complete!")
