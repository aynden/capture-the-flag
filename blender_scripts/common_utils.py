"""
Shared Blender 5.3.0 modeling, material, UV, and glTF export utilities
for Capture the Flag (Paintball Arena).
"""
import os
import math
import bpy
import bmesh
from mathutils import Vector, Matrix, Euler

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX_DIR = os.path.join(ROOT_DIR, "assets", "textures")
MODEL_DIR = os.path.join(ROOT_DIR, "assets", "models")
BLEND_DIR = os.path.join(ROOT_DIR, "blender_assets")

os.makedirs(MODEL_DIR, exist_ok=True)
os.makedirs(BLEND_DIR, exist_ok=True)


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # Remove any leftover data blocks
    for coll in (bpy.data.objects, bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for item in list(coll):
            coll.remove(item, do_unlink=True)


def load_image(filename, non_color=False):
    path = os.path.join(TEX_DIR, filename)
    img = bpy.data.images.load(path, check_existing=True)
    if non_color:
        try:
            img.colorspace_settings.name = "Non-Color"
        except Exception:
            pass
    return img


def make_pbr_material(
    name,
    base_color=(0.8, 0.8, 0.8, 1.0),
    metallic=0.0,
    roughness=0.5,
    coat=0.0,
    coat_roughness=0.1,
    emission=None,
    emission_strength=0.0,
    alpha=1.0,
    albedo_tex=None,
    normal_tex=None,
    normal_strength=1.0,
    rough_tex=None,
    uv_scale=(1.0, 1.0),
    tint_tex=False,
    double_sided=False,
):
    mat = bpy.data.materials.new(name=name)
    if not mat.use_nodes:
        mat.use_nodes = True
    nt = mat.node_tree
    nodes = nt.nodes
    links = nt.links
    nodes.clear()

    out = nodes.new("ShaderNodeOutputMaterial")
    out.location = (500, 0)

    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (180, 0)
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    if len(base_color) == 3:
        base_color = (base_color[0], base_color[1], base_color[2], 1.0)
    bsdf.inputs["Base Color"].default_value = base_color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Alpha"].default_value = alpha
    if "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = coat
    if "Coat Roughness" in bsdf.inputs:
        bsdf.inputs["Coat Roughness"].default_value = coat_roughness

    if emission is not None and emission_strength > 0.0:
        if len(emission) == 3:
            emission = (emission[0], emission[1], emission[2], 1.0)
        bsdf.inputs["Emission Color"].default_value = emission
        bsdf.inputs["Emission Strength"].default_value = emission_strength

    if alpha < 0.999:
        mat.blend_method = "BLEND" if hasattr(mat, "blend_method") else "HASHED"
    mat.use_backface_culling = not double_sided

    # Shared UV mapping node if any textures are used
    mapping = None
    if albedo_tex or normal_tex or rough_tex:
        tex_coord = nodes.new("ShaderNodeTexCoord")
        tex_coord.location = (-750, 0)
        mapping = nodes.new("ShaderNodeMapping")
        mapping.location = (-550, 0)
        mapping.inputs["Scale"].default_value = (uv_scale[0], uv_scale[1], 1.0)
        links.new(tex_coord.outputs["UV"], mapping.inputs["Vector"])

    if albedo_tex:
        tex_node = nodes.new("ShaderNodeTexImage")
        tex_node.location = (-300, 220)
        tex_node.image = load_image(albedo_tex, non_color=False)
        links.new(mapping.outputs["Vector"], tex_node.inputs["Vector"])
        if tint_tex:
            mix = nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.inputs["Factor"].default_value = 1.0
            mix.inputs["B"].default_value = base_color
            mix.location = (-40, 220)
            links.new(tex_node.outputs["Color"], mix.inputs["A"])
            links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
        else:
            links.new(tex_node.outputs["Color"], bsdf.inputs["Base Color"])

    if rough_tex:
        r_node = nodes.new("ShaderNodeTexImage")
        r_node.location = (-300, -40)
        r_node.image = load_image(rough_tex, non_color=True)
        links.new(mapping.outputs["Vector"], r_node.inputs["Vector"])
        links.new(r_node.outputs["Color"], bsdf.inputs["Roughness"])

    if normal_tex:
        n_node = nodes.new("ShaderNodeTexImage")
        n_node.location = (-300, -300)
        n_node.image = load_image(normal_tex, non_color=True)
        links.new(mapping.outputs["Vector"], n_node.inputs["Vector"])
        nmap = nodes.new("ShaderNodeNormalMap")
        nmap.location = (-40, -280)
        nmap.inputs["Strength"].default_value = normal_strength
        links.new(n_node.outputs["Color"], nmap.inputs["Color"])
        links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])

    return mat


def set_smooth(obj, smooth=True):
    if obj.type != "MESH":
        return
    mesh = obj.data
    mesh.polygons.foreach_set("use_smooth", [smooth] * len(mesh.polygons))
    mesh.update()


def add_bevel(obj, width=0.03, segments=2):
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(32.0)
    return mod


def add_subsurf(obj, levels=1):
    mod = obj.modifiers.new("Subsurf", "SUBSURF")
    mod.levels = levels
    mod.render_levels = levels
    return mod


def apply_all_modifiers(obj):
    bpy.context.view_layer.objects.active = obj
    for mod in list(obj.modifiers):
        try:
            bpy.ops.object.modifier_apply(modifier=mod.name)
        except Exception as e:
            print(f"Warning applying modifier {mod.name} on {obj.name}: {e}")


def auto_box_uv(obj, scale=1.0):
    """Fast reliable box UV mapping directly via bmesh (works cleanly in headless mode)."""
    if obj.type != "MESH":
        return
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    uv_layer = bm.loops.layers.uv.verify()
    for face in bm.faces:
        n = face.normal
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        for loop in face.loops:
            co = loop.vert.co * scale
            if az >= ax and az >= ay:
                u, v = co.x, co.y
            elif ax >= ay and ax >= az:
                u, v = co.y, co.z
            else:
                u, v = co.x, co.z
            loop[uv_layer].uv = (u, v)
    bm.to_mesh(me)
    bm.free()


def create_mesh_obj(name, bm, mat=None, smooth=True, uv_scale=1.0, parent=None, location=(0, 0, 0), rotation=(0, 0, 0)):
    mesh = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = rotation
    if parent is not None:
        obj.parent = parent
    if mat is not None:
        obj.data.materials.append(mat)
    if uv_scale is not None:
        auto_box_uv(obj, scale=uv_scale)
    set_smooth(obj, smooth)
    return obj


def make_empty(name, location=(0, 0, 0), rotation=(0, 0, 0), parent=None):
    emp = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(emp)
    emp.location = location
    emp.rotation_euler = rotation
    if parent is not None:
        emp.parent = parent
    return emp


def bm_box(size=(1, 1, 1), center=(0, 0, 0), bevel_width=0.0, bevel_segs=2):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    bmesh.ops.translate(bm, vec=center, verts=bm.verts)
    if bevel_width > 0.0:
        bmesh.ops.bevel(
            bm,
            geom=list(bm.edges),
            offset=bevel_width,
            segments=bevel_segs,
            profile=0.5,
            affect="EDGES",
            clamp_overlap=True,
        )
    return bm


def bm_cylinder(radius=0.5, depth=1.0, segments=24, center=(0, 0, 0), axis="Z", cap_ends=True, bevel_width=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm,
        cap_ends=cap_ends,
        cap_tris=False,
        segments=segments,
        radius1=radius,
        radius2=radius,
        depth=depth,
    )
    if axis == "X":
        bmesh.ops.rotate(bm, matrix=Matrix.Rotation(math.pi * 0.5, 3, "Y"), verts=bm.verts)
    elif axis == "Y":
        bmesh.ops.rotate(bm, matrix=Matrix.Rotation(math.pi * 0.5, 3, "X"), verts=bm.verts)
    if bevel_width > 0.0:
        cap_edges = [e for e in bm.edges if len(e.link_faces) == 2 and abs(e.link_faces[0].normal.dot(e.link_faces[1].normal)) < 0.5]
        if cap_edges:
            bmesh.ops.bevel(bm, geom=cap_edges, offset=bevel_width, segments=2, profile=0.5, affect="EDGES", clamp_overlap=True)
    bmesh.ops.translate(bm, vec=center, verts=bm.verts)
    return bm


def bm_cone(r1=0.5, r2=0.2, depth=1.0, segments=24, center=(0, 0, 0), axis="Z", bevel_width=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=segments,
        radius1=r1,
        radius2=r2,
        depth=depth,
    )
    if axis == "X":
        bmesh.ops.rotate(bm, matrix=Matrix.Rotation(math.pi * 0.5, 3, "Y"), verts=bm.verts)
    elif axis == "Y":
        bmesh.ops.rotate(bm, matrix=Matrix.Rotation(math.pi * 0.5, 3, "X"), verts=bm.verts)
    if bevel_width > 0.0:
        cap_edges = [e for e in bm.edges if len(e.link_faces) == 2 and abs(e.link_faces[0].normal.dot(e.link_faces[1].normal)) < 0.7]
        if cap_edges:
            bmesh.ops.bevel(bm, geom=cap_edges, offset=bevel_width, segments=2, profile=0.5, affect="EDGES", clamp_overlap=True)
    bmesh.ops.translate(bm, vec=center, verts=bm.verts)
    return bm


def bm_sphere(radius=0.5, scale=(1, 1, 1), center=(0, 0, 0), segs=24, rings=16):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=radius)
    bmesh.ops.scale(bm, vec=scale, verts=bm.verts)
    bmesh.ops.translate(bm, vec=center, verts=bm.verts)
    return bm


def bm_capsule(radius=0.15, length=0.6, segs=18, rings=8, center=(0, 0, 0), axis="Z"):
    """Smooth capsule centered at `center` along `axis`."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings * 2, radius=radius)
    half = max(0.0, (length - 2.0 * radius) * 0.5)
    for v in bm.verts:
        if v.co.z > 0.0:
            v.co.z += half
        elif v.co.z < 0.0:
            v.co.z -= half
    if axis == "X":
        bmesh.ops.rotate(bm, matrix=Matrix.Rotation(math.pi * 0.5, 3, "Y"), verts=bm.verts)
    elif axis == "Y":
        bmesh.ops.rotate(bm, matrix=Matrix.Rotation(math.pi * 0.5, 3, "X"), verts=bm.verts)
    bmesh.ops.translate(bm, vec=center, verts=bm.verts)
    return bm


def export_asset(name, save_blend=True):
    """Apply modifiers, save .blend source, and export Godot-ready .glb."""
    bpy.context.view_layer.update()
    for obj in list(bpy.data.objects):
        if obj.type == "MESH" and obj.modifiers:
            apply_all_modifiers(obj)

    if save_blend:
        blend_path = os.path.join(BLEND_DIR, f"{name}.blend")
        bpy.ops.wm.save_as_mainfile(filepath=blend_path)

    glb_path = os.path.join(MODEL_DIR, f"{name}.glb")
    bpy.ops.export_scene.gltf(
        filepath=glb_path,
        export_format="GLB",
        use_selection=False,
        export_yup=True,
        export_apply=True,
        export_materials="EXPORT",
        export_texcoords=True,
        export_normals=True,
    )
    print(f"  -> Exported {glb_path}")
