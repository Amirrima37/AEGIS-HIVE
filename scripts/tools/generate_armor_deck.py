import bpy
import bmesh
import math
from mathutils import Vector, Matrix

def build_or_update_shader_materials():
    """Creates authentic weathered brutalist materials for the Armor Deck."""
    def ensure_mat(name):
        m = bpy.data.materials.get(name)
        if not m:
            m = bpy.data.materials.new(name)
        m.use_nodes = True
        nt = m.node_tree
        nt.nodes.clear()
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        out.location = (600, 0)
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        bsdf.location = (300, 0)
        nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
        return m, nt, bsdf

    def add_rgba_mix(nt, blend_type, factor_val, loc):
        m = nt.nodes.new("ShaderNodeMix")
        m.data_type = 'RGBA'
        m.blend_type = blend_type
        m.location = loc
        m.inputs[0].default_value = factor_val
        # Return node + explicit RGBA sockets (Factor=0, A=6, B=7, Result=2)
        return m, m.inputs[6], m.inputs[7], m.outputs[2]

    # 1. Weathered Composite Gunmetal Steel (matte blackened steel with noise + grime + AO)
    m_steel, nt, bsdf = ensure_mat("M_Armor_Composite_Steel")
    bsdf.inputs["Metallic"].default_value = 0.80
    tex_coord = nt.nodes.new("ShaderNodeTexCoord")
    tex_coord.location = (-800, 0)
    noise_macro = nt.nodes.new("ShaderNodeTexNoise")
    noise_macro.location = (-550, 120)
    noise_macro.inputs["Scale"].default_value = 3.2
    noise_macro.inputs["Detail"].default_value = 6.0
    noise_macro.inputs["Roughness"].default_value = 0.65
    nt.links.new(tex_coord.outputs["Object"], noise_macro.inputs["Vector"])

    noise_fine = nt.nodes.new("ShaderNodeTexNoise")
    noise_fine.location = (-550, -140)
    noise_fine.inputs["Scale"].default_value = 18.0
    noise_fine.inputs["Detail"].default_value = 8.0
    nt.links.new(tex_coord.outputs["Object"], noise_fine.inputs["Vector"])

    ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao.location = (-300, 260)
    ao.inputs["Distance"].default_value = 0.35

    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.location = (-260, 40)
    ramp.color_ramp.elements[0].position = 0.28
    ramp.color_ramp.elements[0].color = (0.065, 0.072, 0.082, 1.0)
    ramp.color_ramp.elements[1].position = 0.72
    ramp.color_ramp.elements[1].color = (0.145, 0.155, 0.168, 1.0)
    e_rust = ramp.color_ramp.elements.new(0.86)
    e_rust.color = (0.16, 0.115, 0.085, 1.0) # subtle oxide grime streak
    nt.links.new(noise_macro.outputs["Fac"], ramp.inputs["Fac"])

    mix_ao, in_a, in_b, out_res = add_rgba_mix(nt, 'MULTIPLY', 0.75, (40, 140))
    nt.links.new(ramp.outputs["Color"], in_a)
    nt.links.new(ao.outputs["Color"], in_b)
    nt.links.new(out_res, bsdf.inputs["Base Color"])

    rough_ramp = nt.nodes.new("ShaderNodeValToRGB")
    rough_ramp.location = (-200, -180)
    rough_ramp.color_ramp.elements[0].color = (0.46, 0.46, 0.46, 1.0)
    rough_ramp.color_ramp.elements[1].color = (0.74, 0.74, 0.74, 1.0)
    nt.links.new(noise_fine.outputs["Fac"], rough_ramp.inputs["Fac"])
    nt.links.new(rough_ramp.outputs["Color"], bsdf.inputs["Roughness"])

    bump = nt.nodes.new("ShaderNodeBump")
    bump.location = (40, -220)
    bump.inputs["Strength"].default_value = 0.14
    bump.inputs["Distance"].default_value = 0.015
    nt.links.new(noise_fine.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])

    # 2. Brutalist Formwork Concrete (coarse concrete with aggregate noise, seams, zero gloss)
    m_conc, nt, bsdf = ensure_mat("M_Armor_Concrete_Brutal")
    bsdf.inputs["Metallic"].default_value = 0.0
    tc = nt.nodes.new("ShaderNodeTexCoord")
    tc.location = (-850, 0)
    n1 = nt.nodes.new("ShaderNodeTexNoise")
    n1.location = (-580, 120)
    n1.inputs["Scale"].default_value = 6.5
    n1.inputs["Detail"].default_value = 10.0
    n1.inputs["Roughness"].default_value = 0.72
    nt.links.new(tc.outputs["Object"], n1.inputs["Vector"])

    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.location = (-580, -140)
    wave.wave_type = 'BANDS'
    wave.bands_direction = 'X'
    wave.inputs["Scale"].default_value = 1.6
    wave.inputs["Distortion"].default_value = 0.35
    nt.links.new(tc.outputs["Object"], wave.inputs["Vector"])

    ao_c = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao_c.location = (-300, 260)
    ao_c.inputs["Distance"].default_value = 0.40

    cr = nt.nodes.new("ShaderNodeValToRGB")
    cr.location = (-280, 40)
    cr.color_ramp.elements[0].position = 0.25
    cr.color_ramp.elements[0].color = (0.19, 0.20, 0.21, 1.0)
    cr.color_ramp.elements[1].position = 0.75
    cr.color_ramp.elements[1].color = (0.36, 0.37, 0.38, 1.0)
    nt.links.new(n1.outputs["Fac"], cr.inputs["Fac"])

    mix_seam, s_a, s_b, s_res = add_rgba_mix(nt, 'MULTIPLY', 0.20, (-40, 60))
    nt.links.new(cr.outputs["Color"], s_a)
    nt.links.new(wave.outputs["Color"], s_b)

    mix_aoc, c_a, c_b, c_res = add_rgba_mix(nt, 'MULTIPLY', 0.80, (120, 120))
    nt.links.new(s_res, c_a)
    nt.links.new(ao_c.outputs["Color"], c_b)
    nt.links.new(c_res, bsdf.inputs["Base Color"])

    bsdf.inputs["Roughness"].default_value = 0.92
    bump_c = nt.nodes.new("ShaderNodeBump")
    bump_c.location = (80, -180)
    bump_c.inputs["Strength"].default_value = 0.28
    bump_c.inputs["Distance"].default_value = 0.025
    nt.links.new(n1.outputs["Fac"], bump_c.inputs["Height"])
    nt.links.new(bump_c.outputs["Normal"], bsdf.inputs["Normal"])

    # 3. Galvanized Industrial Grate / Piston Steel
    m_galv, nt, bsdf = ensure_mat("M_Armor_Galv_Grate")
    bsdf.inputs["Metallic"].default_value = 0.88
    tc_g = nt.nodes.new("ShaderNodeTexCoord")
    n_g = nt.nodes.new("ShaderNodeTexNoise")
    n_g.inputs["Scale"].default_value = 10.0
    n_g.inputs["Detail"].default_value = 6.0
    nt.links.new(tc_g.outputs["Object"], n_g.inputs["Vector"])
    cr_g = nt.nodes.new("ShaderNodeValToRGB")
    cr_g.color_ramp.elements[0].position = 0.30
    cr_g.color_ramp.elements[0].color = (0.28, 0.30, 0.32, 1.0)
    cr_g.color_ramp.elements[1].position = 0.72
    cr_g.color_ramp.elements[1].color = (0.48, 0.50, 0.54, 1.0)
    nt.links.new(n_g.outputs["Fac"], cr_g.inputs["Fac"])
    nt.links.new(cr_g.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.42

    # 4. Crisp Weathered Technical Hazard Chevrons (Yellow/Black Diagonal)
    m_haz, nt, bsdf = ensure_mat("M_Armor_Hazard_Stripe")
    bsdf.inputs["Metallic"].default_value = 0.08
    tc_h = nt.nodes.new("ShaderNodeTexCoord")
    wave_h = nt.nodes.new("ShaderNodeTexWave")
    wave_h.wave_type = 'BANDS'
    wave_h.bands_direction = 'DIAGONAL'
    wave_h.wave_profile = 'SAW'
    wave_h.inputs["Scale"].default_value = 3.2
    wave_h.inputs["Distortion"].default_value = 0.0
    nt.links.new(tc_h.outputs["Object"], wave_h.inputs["Vector"])

    cr_h = nt.nodes.new("ShaderNodeValToRGB")
    cr_h.color_ramp.interpolation = 'CONSTANT'
    cr_h.color_ramp.elements[0].position = 0.0
    cr_h.color_ramp.elements[0].color = (0.035, 0.035, 0.038, 1.0) # matte soot black
    cr_h.color_ramp.elements[1].position = 0.5
    cr_h.color_ramp.elements[1].color = (0.76, 0.52, 0.03, 1.0)   # industrial ochre-amber
    nt.links.new(wave_h.outputs["Fac"], cr_h.inputs["Fac"])

    n_h = nt.nodes.new("ShaderNodeTexNoise")
    n_h.inputs["Scale"].default_value = 14.0
    n_h.inputs["Detail"].default_value = 7.0
    nt.links.new(tc_h.outputs["Object"], n_h.inputs["Vector"])

    mix_grit, g_a, g_b, g_res = add_rgba_mix(nt, 'MULTIPLY', 0.25, (100, 0))
    nt.links.new(cr_h.outputs["Color"], g_a)
    nt.links.new(n_h.outputs["Color"], g_b)
    nt.links.new(g_res, bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.68

    # 5. Deep Shadow Gap / Damp Sump Pit Grime
    m_grime, nt, bsdf = ensure_mat("M_Armor_Streak_Grime")
    bsdf.inputs["Metallic"].default_value = 0.10
    tc_s = nt.nodes.new("ShaderNodeTexCoord")
    n_s = nt.nodes.new("ShaderNodeTexNoise")
    n_s.inputs["Scale"].default_value = 8.0
    n_s.inputs["Detail"].default_value = 9.0
    nt.links.new(tc_s.outputs["Object"], n_s.inputs["Vector"])
    cr_s = nt.nodes.new("ShaderNodeValToRGB")
    cr_s.color_ramp.elements[0].position = 0.3
    cr_s.color_ramp.elements[0].color = (0.025, 0.024, 0.026, 1.0)
    cr_s.color_ramp.elements[1].position = 0.78
    cr_s.color_ramp.elements[1].color = (0.11, 0.068, 0.042, 1.0) # dark iron-oxide runoff
    nt.links.new(n_s.outputs["Fac"], cr_s.inputs["Fac"])
    nt.links.new(cr_s.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85

    # 6. Chipped Primer Red-Brown Wear (subtle accents)
    m_prim, nt, bsdf = ensure_mat("M_Armor_Primer_Wear")
    bsdf.inputs["Base Color"].default_value = (0.24, 0.075, 0.045, 1.0)
    bsdf.inputs["Metallic"].default_value = 0.15
    bsdf.inputs["Roughness"].default_value = 0.72

    return {
        "steel": m_steel,
        "concrete": m_conc,
        "galv": m_galv,
        "hazard": m_haz,
        "grime": m_grime,
        "primer": m_prim,
        "rim_cyan": bpy.data.materials.get("M_Diegetic_Rim_Cyan"),
        "rubber": bpy.data.materials.get("M_Cable_Rubber"),
        "copper": bpy.data.materials.get("M_Copper_Coil"),
        "beacon_amber": bpy.data.materials.get("M_Beacon_Amber"),
    }


def run():
    print("=== BUILDING AND RENDERING ARMOR DECK (2x2) ===")
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.image_settings.color_depth = '8'

    cam = bpy.data.objects.get("IsometricCamera")
    if not cam:
        cam_data = bpy.data.cameras.new("IsometricCamera")
        cam = bpy.data.objects.new("IsometricCamera", cam_data)
        scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.type = 'ORTHO'
    cam.rotation_euler = (math.radians(60.0), 0.0, math.radians(45.0))

    mats = build_or_update_shader_materials()

    col_name = "Building_ArmorDeck"
    root_name = "ArmorDeck_Root"
    coll = bpy.data.collections.get(col_name)
    if not coll:
        coll = bpy.data.collections.new(col_name)
        scene.collection.children.link(coll)
    root = bpy.data.objects.get(root_name)
    if not root:
        root = bpy.data.objects.new(root_name, None)
        coll.objects.link(root)
    for obj in list(coll.objects):
        if obj != root:
            bpy.data.objects.remove(obj, do_unlink=True)

    def link_to_coll(obj):
        obj.parent = root
        if coll not in obj.users_collection:
            coll.objects.link(obj)
        for c in list(obj.users_collection):
            if c != coll:
                c.objects.unlink(obj)

    def add_bevel(obj, width=0.02, segments=2):
        bev = obj.modifiers.new(name="Bevel", type='BEVEL')
        bev.width = width
        bev.segments = segments
        bev.limit_method = 'ANGLE'
        bev.angle_limit = math.radians(30.0)

    def make_cube(name, loc, dim, mat=None, rot=(0,0,0), bevel=0.0):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
        obj = bpy.context.active_object
        obj.name = name
        obj.scale = dim
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        if mat:
            obj.data.materials.append(mat)
        if bevel > 0.0:
            add_bevel(obj, width=bevel, segments=2)
        link_to_coll(obj)
        return obj

    def make_cylinder(name, loc, radius, depth, rot=(0,0,0), mat=None, vertices=24, bevel=0.0):
        bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, vertices=vertices, location=loc, rotation=rot)
        obj = bpy.context.active_object
        obj.name = name
        if mat:
            obj.data.materials.append(mat)
        if bevel > 0.0:
            add_bevel(obj, width=bevel, segments=2)
        link_to_coll(obj)
        return obj

    def make_frustum_skirt(name, z0, z1, hx0, hy0, hx1, hy1, mat=None):
        """Creates sloped perimeter glacis skirt without a solid top cap so pits stay truly open."""
        mesh = bpy.data.meshes.new(name + "_Mesh")
        bm = bmesh.new()
        b0 = [
            bm.verts.new((-hx0, -hy0, z0)),
            bm.verts.new(( hx0, -hy0, z0)),
            bm.verts.new(( hx0,  hy0, z0)),
            bm.verts.new((-hx0,  hy0, z0)),
        ]
        b1 = [
            bm.verts.new((-hx1, -hy1, z1)),
            bm.verts.new(( hx1, -hy1, z1)),
            bm.verts.new(( hx1,  hy1, z1)),
            bm.verts.new((-hx1,  hy1, z1)),
        ]
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new([b0[i], b0[j], b1[j], b1[i]])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new(name, mesh)
        if mat:
            obj.data.materials.append(mat)
        link_to_coll(obj)
        return obj

    def make_cable(name, points, radius=0.028, mat=None):
        cd = bpy.data.curves.new(name=name, type='CURVE')
        cd.dimensions = '3D'
        cd.bevel_depth = radius
        cd.bevel_resolution = 4
        sp = cd.splines.new('BEZIER')
        sp.bezier_points.add(len(points) - 1)
        for i, pt in enumerate(points):
            bp = sp.bezier_points[i]
            bp.co = pt
            bp.handle_left_type = 'AUTO'
            bp.handle_right_type = 'AUTO'
        obj = bpy.data.objects.new(name, cd)
        if mat:
            obj.data.materials.append(mat)
        link_to_coll(obj)
        return obj

    # =========================================================================
    # 1. DIEGETIC STATUS RIM (2x2 tiles = 4.0 x 4.0 m -> [-2.0, +2.0], Z=0.01)
    # =========================================================================
    make_cube("AD_Rim_N", ( 0.00,  1.97, 0.01), (4.00, 0.06, 0.02), mats["rim_cyan"])
    make_cube("AD_Rim_S", ( 0.00, -1.97, 0.01), (4.00, 0.06, 0.02), mats["rim_cyan"])
    make_cube("AD_Rim_E", ( 1.97,  0.00, 0.01), (0.06, 3.88, 0.02), mats["rim_cyan"])
    make_cube("AD_Rim_W", (-1.97,  0.00, 0.01), (0.06, 3.88, 0.02), mats["rim_cyan"])

    # =========================================================================
    # 2. CONCRETE SUBSTRUCTURE PLINTH & CORNER ANCHOR BUMPERS (Z = 0.02..0.24)
    # =========================================================================
    make_cube("AD_Concrete_SubPlinth", (0.0, 0.0, 0.12), (3.82, 3.82, 0.20), mats["concrete"], bevel=0.03)

    # Exposed structural girder brackets tucked under perimeter glacis edge
    for i, off in enumerate([-1.15, 0.0, 1.15]):
        make_cube(f"AD_Girder_S_{i}", (off, -1.86, 0.15), (0.22, 0.14, 0.16), mats["steel"], bevel=0.015)
        make_cube(f"AD_Girder_E_{i}", (1.86, off, 0.15), (0.14, 0.22, 0.16), mats["steel"], bevel=0.015)
        make_cube(f"AD_Girder_N_{i}", (off, 1.86, 0.15), (0.22, 0.14, 0.16), mats["steel"], bevel=0.015)
        make_cube(f"AD_Girder_W_{i}", (-1.86, off, 0.15), (0.14, 0.22, 0.16), mats["steel"], bevel=0.015)

    # Four Heavy Corner Seismic Bumper Blocks with bevels & primer corner plates
    for ci, (cx, cy) in enumerate([(-1.74, -1.74), (1.74, -1.74), (1.74, 1.74), (-1.74, 1.74)]):
        make_cube(f"AD_Corner_Bumper_{ci}", (cx, cy, 0.20), (0.36, 0.36, 0.34), mats["concrete"], bevel=0.035)
        make_cube(f"AD_Corner_Cap_{ci}", (cx, cy, 0.39), (0.30, 0.30, 0.04), mats["steel"], bevel=0.01)
        make_cylinder(f"AD_Corner_Pin_{ci}", (cx, cy, 0.43), 0.055, 0.05, mat=mats["galv"], bevel=0.01)

    # =========================================================================
    # 3. SLOPED BALLISTIC GLACIS SKIRT (40-deg angled armor edge, Z = 0.22..0.44)
    # =========================================================================
    make_frustum_skirt("AD_Ballistic_Glacis", 0.22, 0.44, 1.88, 1.88, 1.66, 1.66, mat=mats["steel"])

    # Heavy external stiffening ribs straddling the 40-deg glacis face
    rib_offsets = [-1.25, -0.82, 0.38, 1.15]
    for ri, r_pos in enumerate(rib_offsets):
        # South front-left slope (tilted forward toward -Y)
        make_cube(f"AD_Glacis_Rib_S_{ri}", (r_pos, -1.76, 0.34), (0.09, 0.24, 0.18), mats["steel"], rot=(math.radians(42), 0, 0), bevel=0.01)
        # East front-right slope (tilted toward +X)
        make_cube(f"AD_Glacis_Rib_E_{ri}", (1.76, -r_pos, 0.34), (0.24, 0.09, 0.18), mats["steel"], rot=(0, math.radians(42), 0), bevel=0.01)
        # Back-Left / Back-Right ribs
        make_cube(f"AD_Glacis_Rib_N_{ri}", (-r_pos, 1.76, 0.34), (0.09, 0.24, 0.18), mats["steel"], rot=(math.radians(-42), 0, 0), bevel=0.01)
        make_cube(f"AD_Glacis_Rib_W_{ri}", (-1.76, r_pos, 0.34), (0.24, 0.09, 0.18), mats["steel"], rot=(0, math.radians(-42), 0), bevel=0.01)

    # =========================================================================
    # 4. ASYMMETRIC SEGMENTED TOP COMPOSITE DECK WITH OPEN SUMP CAVITY
    # =========================================================================
    # Pit opening bounds in Sector D (front/bottom-right quadrant: X=[0.22, 1.38], Y=[-1.32, -0.44])
    # Solid dark mid substructure & Seam Bed (Z = 0.22..0.45) built strictly AROUND the open sump pit!
    make_cube("AD_SeamBed_LeftHalf", (-0.82, 0.00, 0.335), (1.68, 3.30, 0.23), mats["grime"])
    make_cube("AD_SeamBed_TopRight", (0.83, 0.62, 0.335), (1.64, 2.06, 0.23), mats["grime"])
    make_cube("AD_SeamBed_PitRim_L", (0.11, -1.03, 0.335), (0.22, 1.24, 0.23), mats["grime"])
    make_cube("AD_SeamBed_PitRim_R", (1.51, -1.03, 0.335), (0.26, 1.24, 0.23), mats["grime"])
    make_cube("AD_SeamBed_PitRim_S", (0.80, -1.48, 0.335), (1.16, 0.34, 0.23), mats["grime"])

    # Pit floor and darkened inner sump lining (Z = 0.225..0.52)
    make_cube("AD_Sump_Floor", (0.80, -0.88, 0.23), (1.20, 0.92, 0.03), mats["grime"])
    make_cube("AD_Sump_Wall_N", (0.80, -0.43, 0.37), (1.18, 0.03, 0.28), mats["grime"])
    make_cube("AD_Sump_Wall_S", (0.80, -1.33, 0.37), (1.18, 0.03, 0.28), mats["grime"])
    make_cube("AD_Sump_Wall_W", (0.21, -0.88, 0.37), (0.03, 0.90, 0.28), mats["grime"])
    make_cube("AD_Sump_Wall_E", (1.39, -0.88, 0.37), (0.03, 0.90, 0.28), mats["grime"])

    # --- SECTOR A: NW Main Heavy Composite Armor Slab (X=[-1.62, +0.16], Y=[-0.02, +1.62]) ---
    make_cube("AD_SectorA_Plate", (-0.73, 0.80, 0.50), (1.76, 1.62, 0.11), mats["steel"], bevel=0.02)
    # Raised ballistic stiffening ribs on Sector A
    make_cube("AD_SectorA_Rib1", (-1.15, 0.80, 0.56), (0.14, 1.38, 0.04), mats["steel"], bevel=0.01)
    make_cube("AD_SectorA_Rib2", (-0.12, 1.10, 0.56), (0.14, 0.78, 0.04), mats["steel"], bevel=0.01)
    # Recessed 0.6m human-scale maintenance hatch on Sector A
    make_cylinder("AD_Hatch_Rim", (-0.58, 0.52, 0.56), 0.30, 0.035, vertices=24, mat=mats["galv"], bevel=0.008)
    make_cylinder("AD_Hatch_Lid", (-0.58, 0.52, 0.575), 0.24, 0.03, vertices=24, mat=mats["steel"], bevel=0.006)
    make_cube("AD_Hatch_Grip", (-0.58, 0.52, 0.595), (0.22, 0.04, 0.025), mats["galv"])
    # Red oxide primer chipped armor edge bumper
    make_cube("AD_SectorA_PrimerBump", (-1.52, 1.48, 0.56), (0.18, 0.18, 0.03), mats["primer"], bevel=0.008)

    # --- SECTOR B: NE Brutalist Concrete-Inlay Armor Module (X=[+0.22, +1.62], Y=[+0.02, +1.62]) ---
    # Heavy bolted steel frame bezel + concrete slab core
    make_cube("AD_SectorB_SteelFrame", (0.92, 0.82, 0.49), (1.38, 1.58, 0.09), mats["steel"], bevel=0.018)
    make_cube("AD_SectorB_ConcreteCore", (0.92, 0.82, 0.535), (1.14, 1.34, 0.06), mats["concrete"], bevel=0.015)
    # Expansion seam grooves & lifting anchor rings on concrete core
    make_cube("AD_SectorB_Groove", (0.92, 0.82, 0.568), (1.10, 0.035, 0.015), mats["grime"])
    for li, (lx, ly) in enumerate([(0.52, 1.24), (1.32, 0.40)]):
        make_cube(f"AD_LiftPocket_{li}", (lx, ly, 0.56), (0.22, 0.22, 0.025), mats["grime"])
        make_cube(f"AD_LiftShackle_{li}", (lx, ly, 0.58), (0.12, 0.04, 0.035), mats["galv"], bevel=0.005)
    # Rivet bolts along Sector B steel border
    for bi, by in enumerate([0.14, 0.50, 0.86, 1.22, 1.50]):
        make_cylinder(f"AD_SecB_Bolt_L_{bi}", (0.28, by, 0.545), 0.024, 0.025, mat=mats["galv"])
        make_cylinder(f"AD_SecB_Bolt_R_{bi}", (1.56, by, 0.545), 0.024, 0.025, mat=mats["galv"])

    # --- SECTOR C: SW Hydraulic Valve & Manifold Bay (X=[-1.62, -0.08], Y=[-1.62, -0.08]) ---
    # Framed recessed pocket so hydraulic manifold sits cleanly inside armor deck!
    make_cube("AD_SecC_Deck_N", (-0.85, -0.24, 0.495), (1.52, 0.34, 0.10), mats["steel"], bevel=0.016)
    make_cube("AD_SecC_Deck_S", (-0.85, -1.46, 0.495), (1.52, 0.32, 0.10), mats["steel"], bevel=0.016)
    make_cube("AD_SecC_Deck_W", (-1.47, -0.85, 0.495), (0.30, 0.92, 0.10), mats["steel"], bevel=0.016)
    make_cube("AD_SecC_Deck_E", (-0.21, -0.85, 0.495), (0.28, 0.92, 0.10), mats["steel"], bevel=0.016)
    # Recessed bay floor at Z=0.45
    make_cube("AD_SecC_PocketFloor", (-0.84, -0.85, 0.445), (0.98, 0.90, 0.03), mats["grime"])
    # Valve Manifold Hardware inside pocket
    make_cube("AD_Valve_Block", (-0.84, -0.80, 0.50), (0.48, 0.34, 0.10), mats["steel"], bevel=0.012)
    make_cylinder("AD_Valve_Cap1", (-0.98, -0.80, 0.565), 0.06, 0.04, mat=mats["copper"], bevel=0.006)
    make_cylinder("AD_Valve_Cap2", (-0.70, -0.80, 0.565), 0.06, 0.04, mat=mats["galv"], bevel=0.006)
    make_cylinder("AD_Valve_Dome", (-0.84, -0.96, 0.54), 0.08, 0.09, mat=mats["primer"], bevel=0.01)
    # Protective steel cross guard bars across pocket
    make_cube("AD_SecC_GuardBar", (-0.84, -0.58, 0.545), (0.96, 0.045, 0.035), mats["galv"])

    # --- SECTOR D: SE Drainage Trench Frame & Real 3D Steel Grating (X=[0.00, 1.62], Y=[-1.62, -0.02]) ---
    make_cube("AD_SecD_Plate_L", (0.10, -0.82, 0.495), (0.22, 1.60, 0.10), mats["steel"], bevel=0.015)
    make_cube("AD_SecD_Plate_R", (1.51, -0.82, 0.495), (0.24, 1.60, 0.10), mats["steel"], bevel=0.015)
    make_cube("AD_SecD_Plate_S", (0.80, -1.48, 0.495), (1.18, 0.30, 0.10), mats["steel"], bevel=0.015)
    make_cube("AD_SecD_Plate_N", (0.80, -0.22, 0.495), (1.18, 0.42, 0.10), mats["steel"], bevel=0.015)

    # Raised galvanized steel drain curb lip
    make_cube("AD_Grate_Curb_N", (0.80, -0.43, 0.555), (1.22, 0.045, 0.03), mats["galv"])
    make_cube("AD_Grate_Curb_S", (0.80, -1.33, 0.555), (1.22, 0.045, 0.03), mats["galv"])
    make_cube("AD_Grate_Curb_W", (0.21, -0.88, 0.555), (0.045, 0.88, 0.03), mats["galv"])
    make_cube("AD_Grate_Curb_E", (1.39, -0.88, 0.555), (0.045, 0.88, 0.03), mats["galv"])

    # Real 3D Slatted Grating Bars over the dark open pit!
    for gi in range(11):
        gx = 0.29 + gi * 0.102
        make_cube(f"AD_Grate_Bar_{gi}", (gx, -0.88, 0.52), (0.032, 0.86, 0.045), mats["galv"], bevel=0.005)
    for bi, by in enumerate([-1.14, -0.88, -0.62]):
        make_cube(f"AD_Grate_Bearer_{bi}", (0.80, by, 0.485), (1.16, 0.04, 0.045), mats["steel"])

    # Weathered drainage grime scupper streaks bordering pit (strictly proud of plate top Z=0.545)
    make_cube("AD_Drain_Runoff_1", (0.80, -0.35, 0.552), (0.85, 0.14, 0.010), mats["grime"])

    # =========================================================================
    # 5. TECHNICAL HAZARD MARKINGS AT JOINTS & SEAMS
    # =========================================================================
    # Hazard lip along the drainage pit South & North edges
    make_cube("AD_Hazard_Drain_S", (0.80, -1.45, 0.554), (1.18, 0.10, 0.014), mats["hazard"])
    # Hazard strip dividing Concrete Sector B and Steel Sector A
    make_cube("AD_Hazard_Seam_Mid", (0.19, 0.82, 0.525), (0.07, 1.40, 0.03), mats["hazard"])
    # Corner lifting bay hazard stencil plates
    make_cube("AD_Hazard_Lift_A", (-1.38, -1.45, 0.554), (0.34, 0.12, 0.014), mats["hazard"])
    make_cube("AD_Hazard_Lift_B", (1.42, 1.42, 0.572), (0.26, 0.26, 0.012), mats["hazard"])

    # =========================================================================
    # 6. PERIMETER HYDRAULIC SECTOR LOCKS (4 Asymmetric Tokyo-3 Clamp Bays)
    # =========================================================================
    def build_hydraulic_lock(tag, base_pos, rot_z_deg):
        """Creates a lock housing rotated around Z at base_pos."""
        rz = math.radians(rot_z_deg)
        c_ang = math.cos(rz)
        s_ang = math.sin(rz)

        def to_world(lx, ly, lz):
            wx = base_pos[0] + lx * c_ang - ly * s_ang
            wy = base_pos[1] + lx * s_ang + ly * c_ang
            return (wx, wy, lz)

        # Local frame: +Y points INWARD onto deck, -Y points OUTWARD toward edge!
        # Heavy lock armored saddle housing
        make_cube(f"AD_Lock_{tag}_Hood", to_world(0.0, 0.08, 0.54), (0.76, 0.36, 0.18), mats["steel"], rot=(0, 0, rz), bevel=0.018)
        make_cube(f"AD_Lock_{tag}_CheekL", to_world(-0.30, -0.04, 0.45), (0.12, 0.38, 0.24), mats["steel"], rot=(0, 0, rz), bevel=0.015)
        make_cube(f"AD_Lock_{tag}_CheekR", to_world( 0.30, -0.04, 0.45), (0.12, 0.38, 0.24), mats["steel"], rot=(0, 0, rz), bevel=0.015)

        # Twin hydraulic barrels + gleaming steel piston rods driving clamp jaw outward (-Y)
        for rx_i, rx in enumerate([-0.14, 0.14]):
            make_cylinder(f"AD_Lock_{tag}_Cyl_{rx_i}", to_world(rx, 0.04, 0.43), 0.052, 0.22, rot=(math.radians(90), 0, rz), mat=mats["steel"])
            make_cylinder(f"AD_Lock_{tag}_Rod_{rx_i}", to_world(rx, -0.10, 0.43), 0.032, 0.20, rot=(math.radians(90), 0, rz), mat=mats["galv"])
            make_cylinder(f"AD_Lock_{tag}_Boot_{rx_i}", to_world(rx, -0.04, 0.43), 0.042, 0.06, rot=(math.radians(90), 0, rz), mat=mats["rubber"])

        # Heavy Locking Clamp Wedge Tooth protruding toward sector border
        make_cube(f"AD_Lock_{tag}_Jaw", to_world(0.0, -0.20, 0.40), (0.44, 0.16, 0.16), mats["galv"], rot=(math.radians(15), 0, rz), bevel=0.015)
        make_cube(f"AD_Lock_{tag}_Tooth", to_world(0.0, -0.26, 0.35), (0.34, 0.10, 0.10), mats["steel"], rot=(0, 0, rz), bevel=0.01)

        # Dual hazard chevron bays flanking lock jaw on sloped apron
        make_cube(f"AD_Lock_{tag}_HazL", to_world(-0.52, -0.08, 0.41), (0.24, 0.20, 0.03), mats["hazard"], rot=(math.radians(38), 0, rz))
        make_cube(f"AD_Lock_{tag}_HazR", to_world( 0.52, -0.08, 0.41), (0.24, 0.20, 0.03), mats["hazard"], rot=(math.radians(38), 0, rz))

        # Status light pin tucked under roll hood
        make_cylinder(f"AD_Lock_{tag}_Beacon", to_world(0.0, 0.08, 0.645), 0.032, 0.035, rot=(0, 0, rz), mat=mats["beacon_amber"])

    # Place 4 asymmetric hydraulic sector locks along the 4 edges
    build_hydraulic_lock("FrontL_S", (-0.36, -1.68, 0.0),   0.0)   # Y = -1.68 edge (facing -Y)
    build_hydraulic_lock("FrontR_E", ( 1.68,  0.28, 0.0),  90.0)   # X = +1.68 edge (facing +X)
    build_hydraulic_lock("BackR_N",  ( 0.36,  1.68, 0.0), 180.0)   # Y = +1.68 edge (facing +Y)
    build_hydraulic_lock("BackL_W",  (-1.68, -0.32, 0.0), 270.0)   # X = -1.68 edge (facing -X)

    # =========================================================================
    # 7. CATENARY HYDRAULIC FEEDER HOSES (Manifold -> Locks)
    # =========================================================================
    make_cable("AD_Hose_To_LockS_1", [
        Vector((-0.78, -0.92, 0.50)),
        Vector((-0.58, -1.25, 0.57)),
        Vector((-0.44, -1.52, 0.54)),
    ], radius=0.025, mat=mats["rubber"])

    make_cable("AD_Hose_To_LockS_2", [
        Vector((-0.90, -0.94, 0.50)),
        Vector((-0.72, -1.28, 0.56)),
        Vector((-0.30, -1.52, 0.54)),
    ], radius=0.022, mat=mats["rubber"])

    make_cable("AD_Hose_To_LockW_1", [
        Vector((-1.02, -0.78, 0.50)),
        Vector((-1.32, -0.58, 0.57)),
        Vector((-1.54, -0.36, 0.54)),
    ], radius=0.025, mat=mats["rubber"])

    # Secondary jumper conduit feeding Concrete Sector B to Lock East
    make_cable("AD_Hose_To_LockE_1", [
        Vector((1.35, 0.28, 0.54)),
        Vector((1.48, 0.28, 0.58)),
        Vector((1.58, 0.28, 0.53)),
    ], radius=0.024, mat=mats["rubber"])

    # =========================================================================
    # 8. SAVE MASTER BLEND FILE
    # =========================================================================
    master_blend = "c:/dev/MegaProject/assets/models/buildings_master.blend"
    bpy.ops.wm.save_as_mainfile(filepath=master_blend)
    print(f"Saved Building_ArmorDeck into {master_blend}")

    # =========================================================================
    # 9. RENDER BOTH ORIENTATIONS (0 deg & 90 deg)
    # =========================================================================
    all_building_cols = [c.name for c in bpy.data.collections if c.name.startswith("Building_")]
    dist = 30.0
    fwd = Vector((-math.sqrt(6)/4, math.sqrt(6)/4, -0.5))
    target = Vector((0.0, 0.0, 0.35))

    render_tasks = [
        {
            "id": "armor_deck",
            "rot_z": 0.0,
            "out": "c:/dev/MegaProject/assets/sprites/buildings_backup/armor_deck.png"
        },
        {
            "id": "armor_deck_rot",
            "rot_z": 90.0,
            "out": "c:/dev/MegaProject/assets/sprites/buildings_backup/armor_deck_rot.png"
        }
    ]

    for task in render_tasks:
        for cname in all_building_cols:
            c = bpy.data.collections.get(cname)
            if c:
                is_target = (cname == col_name)
                c.hide_render = not is_target
                c.hide_viewport = not is_target

        root.rotation_euler.z = math.radians(task["rot_z"])
        scene.render.resolution_x = 512
        scene.render.resolution_y = 512
        scene.render.filepath = task["out"]
        cam.data.ortho_scale = 6.4
        cam.location = target - dist * fwd

        print(f"Rendering {task['id']} -> {task['out']}")
        bpy.ops.render.render(write_still=True)

    # Restore clean state
    root.rotation_euler.z = 0.0
    for cname in all_building_cols:
        c = bpy.data.collections.get(cname)
        if c:
            c.hide_render = False
            c.hide_viewport = False

    print("=== ARMOR DECK GENERATION & RENDERS COMPLETED ===")

if __name__ == "__main__":
    run()
