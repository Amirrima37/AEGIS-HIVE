import bpy
import math
from mathutils import Vector

def run():
    print("=== STARTING ROTATED AND CORNER BUILDINGS GENERATION ===")
    scene = bpy.context.scene

    # 1. Render Settings
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.image_settings.color_depth = '8'

    # 2. Camera Setup
    cam = bpy.data.objects.get("IsometricCamera")
    if not cam:
        cam_data = bpy.data.cameras.new("IsometricCamera")
        cam = bpy.data.objects.new("IsometricCamera", cam_data)
        scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.type = 'ORTHO'
    cam.rotation_euler = (math.radians(60.0), 0.0, math.radians(45.0))

    # 3. Materials Lookup
    mat_rim_cyan = bpy.data.materials.get("M_Diegetic_Rim_Cyan")
    mat_rim_amber = bpy.data.materials.get("M_Diegetic_Rim_Amber")
    mat_rim_amber_yellow = bpy.data.materials.get("M_Diegetic_Rim_AmberYellow")
    mat_conc_main = bpy.data.materials.get("M_Concrete_Main")
    mat_conc_dark = bpy.data.materials.get("M_Concrete_Dark")
    mat_steel_dark = bpy.data.materials.get("M_Steel_Dark")
    mat_steel_galv = bpy.data.materials.get("M_Steel_Galv")
    mat_cable_rubber = bpy.data.materials.get("M_Cable_Rubber")
    mat_hazard = bpy.data.materials.get("M_Hazard_Yellow")
    mat_ore = bpy.data.materials.get("M_Rock_Ore")
    mat_beacon_amber = bpy.data.materials.get("M_Beacon_Amber")
    mat_beacon_red = bpy.data.materials.get("M_Beacon_Red")
    mat_embrasure = bpy.data.materials.get("M_Embrasures_Warm")
    mat_copper = bpy.data.materials.get("M_Copper_Coil")

    def make_cube(coll, root, name, loc, dim, mat=None, rot=(0,0,0)):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
        obj = bpy.context.active_object
        obj.name = name
        obj.scale = dim
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        if mat:
            obj.data.materials.append(mat)
        obj.parent = root
        if coll not in obj.users_collection:
            coll.objects.link(obj)
        for c in list(obj.users_collection):
            if c != coll:
                c.objects.unlink(obj)
        return obj

    def make_cylinder(coll, root, name, loc, radius, depth, rot=(0,0,0), mat=None, vertices=16):
        bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, vertices=vertices, location=loc, rotation=rot)
        obj = bpy.context.active_object
        obj.name = name
        if mat:
            obj.data.materials.append(mat)
        obj.parent = root
        if coll not in obj.users_collection:
            coll.objects.link(obj)
        for c in list(obj.users_collection):
            if c != coll:
                c.objects.unlink(obj)
        return obj

    def make_cable(coll, root, name, points, radius=0.035, mat=None):
        curve_data = bpy.data.curves.new(name=name, type='CURVE')
        curve_data.dimensions = '3D'
        curve_data.bevel_depth = radius
        curve_data.bevel_resolution = 4
        polyline = curve_data.splines.new('POLY')
        polyline.points.add(len(points) - 1)
        for i, pt in enumerate(points):
            polyline.points[i].co = (pt.x, pt.y, pt.z, 1.0)
        obj = bpy.data.objects.new(name, curve_data)
        if mat:
            obj.data.materials.append(mat)
        obj.parent = root
        coll.objects.link(obj)
        return obj

    def get_or_create_collection(col_name, root_name):
        coll = bpy.data.collections.get(col_name)
        if not coll:
            coll = bpy.data.collections.new(col_name)
            scene.collection.children.link(coll)
        root = bpy.data.objects.get(root_name)
        if not root:
            root = bpy.data.objects.new(root_name, None)
            coll.objects.link(root)
        return coll, root

    # =========================================================================
    # BUILD CORNER MODEL 1: Building_PowerCable_Corner
    # =========================================================================
    print("Building PowerCable Corner...")
    col_pcc, root_pcc = get_or_create_collection("Building_PowerCable_Corner", "PowerCable_Corner_Root")
    # Clean previous children if any
    for obj in list(col_pcc.objects):
        if obj != root_pcc:
            bpy.data.objects.remove(obj, do_unlink=True)

    # 1x1 Rim (Cyan)
    make_cube(col_pcc, root_pcc, "PCC_Rim_N", (0.0, 0.965, 0.01), (2.0, 0.07, 0.02), mat_rim_cyan)
    make_cube(col_pcc, root_pcc, "PCC_Rim_S", (0.0, -0.965, 0.01), (2.0, 0.07, 0.02), mat_rim_cyan)
    make_cube(col_pcc, root_pcc, "PCC_Rim_E", (0.965, 0.0, 0.01), (0.07, 1.86, 0.02), mat_rim_cyan)
    make_cube(col_pcc, root_pcc, "PCC_Rim_W", (-0.965, 0.0, 0.01), (0.07, 1.86, 0.02), mat_rim_cyan)

    # Base concrete slab
    make_cube(col_pcc, root_pcc, "PCC_Base_Plinth", (0.0, 0.0, 0.035), (1.86, 1.86, 0.05), mat_conc_dark)

    # L-Shaped Tray Rails (Arm along -X from -0.95 to 0.0; Arm along -Y from 0.0 to -0.95)
    # Outer rails
    make_cube(col_pcc, root_pcc, "PCC_Tray_Outer_X", (-0.45, 0.28, 0.12), (1.00, 0.04, 0.12), mat_steel_galv)
    make_cube(col_pcc, root_pcc, "PCC_Tray_Outer_Y", (0.28, -0.45, 0.12), (0.04, 1.00, 0.12), mat_steel_galv)
    make_cube(col_pcc, root_pcc, "PCC_Tray_Outer_Corner", (0.28, 0.28, 0.12), (0.04, 0.04, 0.12), mat_steel_galv)

    # Inner rails
    make_cube(col_pcc, root_pcc, "PCC_Tray_Inner_X", (-0.62, -0.28, 0.12), (0.66, 0.04, 0.12), mat_steel_galv)
    make_cube(col_pcc, root_pcc, "PCC_Tray_Inner_Y", (-0.28, -0.62, 0.12), (0.04, 0.66, 0.12), mat_steel_galv)
    make_cube(col_pcc, root_pcc, "PCC_Tray_Inner_Corner", (-0.28, -0.28, 0.12), (0.04, 0.04, 0.12), mat_steel_galv)

    # Rungs on Arm X
    for i, rx in enumerate([-0.80, -0.55, -0.35]):
        make_cube(col_pcc, root_pcc, f"PCC_Rung_X_{i}", (rx, 0.0, 0.07), (0.04, 0.54, 0.02), mat_steel_galv)
    # Rungs on Arm Y
    for i, ry in enumerate([-0.80, -0.55, -0.35]):
        make_cube(col_pcc, root_pcc, f"PCC_Rung_Y_{i}", (0.0, ry, 0.07), (0.54, 0.04, 0.02), mat_steel_galv)
    # Corner diagonal rungs
    make_cube(col_pcc, root_pcc, "PCC_Rung_Corner_1", (-0.05, -0.05, 0.07), (0.42, 0.04, 0.02), mat_steel_galv, rot=(0, 0, math.radians(45)))
    make_cube(col_pcc, root_pcc, "PCC_Rung_Corner_2", (0.10, 0.10, 0.07), (0.30, 0.04, 0.02), mat_steel_galv, rot=(0, 0, math.radians(45)))

    # Support stanchions
    make_cube(col_pcc, root_pcc, "PCC_Stanchion_X", (-0.65, 0.0, 0.04), (0.08, 0.62, 0.04), mat_steel_dark)
    make_cube(col_pcc, root_pcc, "PCC_Stanchion_Y", (0.0, -0.65, 0.04), (0.62, 0.08, 0.04), mat_steel_dark)
    make_cube(col_pcc, root_pcc, "PCC_Stanchion_C", (0.16, 0.16, 0.04), (0.28, 0.28, 0.04), mat_steel_dark)

    # 3 Curved Armored Cables turning 90°
    cable_offsets = [-0.14, 0.0, 0.14]
    for i, coff in enumerate(cable_offsets):
        pts = [
            Vector((-0.95, coff, 0.11)),
            Vector((-0.35 + coff * 0.4, coff, 0.11)),
            Vector((coff * 0.5, coff * 0.5, 0.11)),
            Vector((coff, -0.35 + coff * 0.4, 0.11)),
            Vector((coff, -0.95, 0.11))
        ]
        make_cable(col_pcc, root_pcc, f"PCC_Cable_{i}", pts, radius=0.035, mat=mat_cable_rubber)

    # Cable saddle clamps at straight sections
    make_cube(col_pcc, root_pcc, "PCC_Clamp_X", (-0.65, 0.0, 0.15), (0.04, 0.54, 0.025), mat_steel_dark)
    make_cube(col_pcc, root_pcc, "PCC_Clamp_Y", (0.0, -0.65, 0.15), (0.54, 0.04, 0.025), mat_steel_dark)

    # Cast-Steel Corner Junction Box with cooling fins
    make_cube(col_pcc, root_pcc, "PCC_Junc_Body", (0.52, 0.52, 0.24), (0.50, 0.50, 0.36), mat_steel_dark)
    make_cube(col_pcc, root_pcc, "PCC_Junc_Lid", (0.52, 0.52, 0.44), (0.54, 0.54, 0.04), mat_steel_dark)
    # Cooling fins
    for fi in range(4):
        make_cube(col_pcc, root_pcc, f"PCC_Fin_{fi}", (0.52, 0.32 + fi * 0.12, 0.47), (0.46, 0.02, 0.04), mat_steel_galv)

    # Cable Couplings / Packing Glands into junction box
    make_cylinder(col_pcc, root_pcc, "PCC_Gland_X", (0.26, 0.52, 0.18), 0.05, 0.08, rot=(0, math.radians(90), 0), mat=mat_copper)
    make_cylinder(col_pcc, root_pcc, "PCC_Gland_Y", (0.52, 0.26, 0.18), 0.05, 0.08, rot=(math.radians(90), 0, 0), mat=mat_copper)

    # Hazard plate on front of junction box
    make_cube(col_pcc, root_pcc, "PCC_Hazard_Plate", (0.52, 0.26, 0.28), (0.34, 0.015, 0.14), mat_hazard)

    # Indicator lights on junction box
    make_cylinder(col_pcc, root_pcc, "PCC_LED_1", (0.42, 0.25, 0.38), 0.022, 0.02, rot=(math.radians(90), 0, 0), mat=mat_rim_cyan)
    make_cylinder(col_pcc, root_pcc, "PCC_LED_2", (0.52, 0.25, 0.38), 0.022, 0.02, rot=(math.radians(90), 0, 0), mat=mat_rim_cyan)
    make_cylinder(col_pcc, root_pcc, "PCC_Beacon", (0.62, 0.25, 0.38), 0.022, 0.02, rot=(math.radians(90), 0, 0), mat=mat_beacon_amber)

    # Heavy grounding busbar with copper contact
    make_cube(col_pcc, root_pcc, "PCC_Ground_Bar", (0.78, 0.52, 0.08), (0.04, 0.50, 0.08), mat_steel_galv)
    make_cylinder(col_pcc, root_pcc, "PCC_Copper_Lug", (0.78, 0.52, 0.13), 0.03, 0.04, mat=mat_copper)

    # =========================================================================
    # BUILD CORNER MODEL 2: Building_Conveyor_Corner
    # =========================================================================
    print("Building Conveyor Corner...")
    col_cvc, root_cvc = get_or_create_collection("Building_Conveyor_Corner", "Conveyor_Corner_Root")
    for obj in list(col_cvc.objects):
        if obj != root_cvc:
            bpy.data.objects.remove(obj, do_unlink=True)

    # 1x1 Rim (Amber)
    make_cube(col_cvc, root_cvc, "CVC_Rim_N", (0.0, 0.965, 0.01), (2.0, 0.07, 0.02), mat_rim_amber)
    make_cube(col_cvc, root_cvc, "CVC_Rim_S", (0.0, -0.965, 0.01), (2.0, 0.07, 0.02), mat_rim_amber)
    make_cube(col_cvc, root_cvc, "CVC_Rim_E", (0.965, 0.0, 0.01), (0.07, 1.86, 0.02), mat_rim_amber)
    make_cube(col_cvc, root_cvc, "CVC_Rim_W", (-0.965, 0.0, 0.01), (0.07, 1.86, 0.02), mat_rim_amber)

    # Concrete foundation pedestals
    make_cube(col_cvc, root_cvc, "CVC_Pedestal_X", (-0.55, 0.0, 0.10), (0.44, 0.82, 0.20), mat_conc_main)
    make_cube(col_cvc, root_cvc, "CVC_Pedestal_Y", (0.0, -0.55, 0.10), (0.82, 0.44, 0.20), mat_conc_main)
    make_cube(col_cvc, root_cvc, "CVC_Pedestal_C", (0.48, 0.48, 0.12), (0.65, 0.65, 0.24), mat_conc_main)

    # Steel baseplates
    make_cube(col_cvc, root_cvc, "CVC_Baseplate_X", (-0.55, 0.0, 0.21), (0.40, 0.74, 0.03), mat_steel_dark)
    make_cube(col_cvc, root_cvc, "CVC_Baseplate_Y", (0.0, -0.55, 0.21), (0.74, 0.40, 0.03), mat_steel_dark)
    make_cube(col_cvc, root_cvc, "CVC_Baseplate_C", (0.48, 0.48, 0.25), (0.58, 0.58, 0.03), mat_steel_dark)

    # Trestle legs for Arm X (rising to Z=0.88)
    for sy in [-0.28, 0.28]:
        make_cylinder(col_cvc, root_cvc, f"CVC_Leg_X_{sy}", (-0.55, sy * 0.65, 0.54), 0.04, 0.68, mat=mat_steel_dark)
    # Trestle legs for Arm Y (rising to Z=0.80)
    for sx in [-0.28, 0.28]:
        make_cylinder(col_cvc, root_cvc, f"CVC_Leg_Y_{sx}", (sx * 0.65, -0.55, 0.50), 0.04, 0.60, mat=mat_steel_dark)

    # Arm 1 Conveyor Frame (Input from -X, Z = 0.88)
    make_cube(col_cvc, root_cvc, "CVC_Bed_X", (-0.55, 0.0, 0.84), (0.85, 0.56, 0.06), mat_steel_dark)
    make_cube(col_cvc, root_cvc, "CVC_Belt_X", (-0.55, 0.0, 0.88), (0.85, 0.48, 0.02), mat_cable_rubber)
    make_cube(col_cvc, root_cvc, "CVC_Guide_X_L", (-0.55, 0.26, 0.92), (0.85, 0.03, 0.12), mat_steel_galv)
    make_cube(col_cvc, root_cvc, "CVC_Guide_X_R", (-0.55, -0.26, 0.92), (0.85, 0.03, 0.12), mat_steel_galv)

    # Arm 2 Conveyor Frame (Output to -Y, cascade drop Z = 0.78)
    make_cube(col_cvc, root_cvc, "CVC_Bed_Y", (0.0, -0.55, 0.74), (0.56, 0.85, 0.06), mat_steel_dark)
    make_cube(col_cvc, root_cvc, "CVC_Belt_Y", (0.0, -0.55, 0.78), (0.48, 0.85, 0.02), mat_cable_rubber)
    make_cube(col_cvc, root_cvc, "CVC_Guide_Y_L", (0.26, -0.55, 0.82), (0.03, 0.85, 0.12), mat_steel_galv)
    make_cube(col_cvc, root_cvc, "CVC_Guide_Y_R", (-0.26, -0.55, 0.82), (0.03, 0.85, 0.12), mat_steel_galv)

    # Heavy Angular Transfer Chute / Transition Hood at corner (0.0, 0.0)
    make_cube(col_cvc, root_cvc, "CVC_Chute_Main", (0.0, 0.0, 1.15), (0.68, 0.68, 0.58), mat_steel_dark)
    make_cube(col_cvc, root_cvc, "CVC_Chute_Hopper", (0.0, 0.0, 1.48), (0.54, 0.54, 0.12), mat_steel_galv)
    make_cube(col_cvc, root_cvc, "CVC_Chute_Hatch", (0.0, -0.35, 1.15), (0.24, 0.04, 0.24), mat_steel_dark)
    make_cube(col_cvc, root_cvc, "CVC_Chute_Hazard", (0.0, -0.36, 0.96), (0.52, 0.015, 0.10), mat_hazard)

    # Corner Electric Drive Motor & Heavy Gearbox
    make_cube(col_cvc, root_cvc, "CVC_Motor_Bed", (0.48, 0.48, 0.45), (0.40, 0.40, 0.36), mat_steel_dark)
    make_cylinder(col_cvc, root_cvc, "CVC_Motor_Body", (0.48, 0.48, 0.82), 0.15, 0.42, rot=(math.radians(90), 0, math.radians(45)), mat=mat_steel_dark)
    make_cylinder(col_cvc, root_cvc, "CVC_Motor_Cowl", (0.62, 0.62, 0.82), 0.17, 0.08, rot=(math.radians(90), 0, math.radians(45)), mat=mat_steel_galv)
    make_cube(col_cvc, root_cvc, "CVC_Motor_Guard", (0.35, 0.35, 0.82), (0.20, 0.20, 0.26), mat_hazard)

    # Heavy electrical conduit from motor to foundation
    make_cylinder(col_cvc, root_cvc, "CVC_Motor_Conduit", (0.55, 0.32, 0.55), 0.025, 0.55, mat=mat_steel_galv)

    # Ore pieces on input belt, chute, and output belt
    ore_locs = [
        (-0.80, 0.05, 0.92), (-0.55, -0.06, 0.92), (-0.30, 0.02, 0.92),
        (0.04, -0.32, 0.82), (-0.05, -0.58, 0.82), (0.02, -0.80, 0.82)
    ]
    for i, oloc in enumerate(ore_locs):
        make_cube(col_cvc, root_cvc, f"CVC_Ore_{i}", oloc, (0.10, 0.09, 0.07), mat_ore, rot=(0.2*i, 0.4*i, 0.1*i))

    # Corner warning beacon mast
    make_cylinder(col_cvc, root_cvc, "CVC_Beacon_Mast", (0.28, 0.28, 1.55), 0.03, 0.30, mat=mat_steel_dark)
    make_cylinder(col_cvc, root_cvc, "CVC_Beacon_Lamp", (0.28, 0.28, 1.72), 0.045, 0.08, mat=mat_beacon_amber)

    # =========================================================================
    # BUILD CORNER MODEL 3: Building_DefenseWall_Corner
    # =========================================================================
    print("Building DefenseWall Corner...")
    col_dwc, root_dwc = get_or_create_collection("Building_DefenseWall_Corner", "DefenseWall_Corner_Root")
    for obj in list(col_dwc.objects):
        if obj != root_dwc:
            bpy.data.objects.remove(obj, do_unlink=True)

    # 1x1 Rim (Amber-Yellow #FFB300)
    make_cube(col_dwc, root_dwc, "DWC_Rim_N", (0.0, 0.965, 0.01), (2.0, 0.07, 0.02), mat_rim_amber_yellow)
    make_cube(col_dwc, root_dwc, "DWC_Rim_S", (0.0, -0.965, 0.01), (2.0, 0.07, 0.02), mat_rim_amber_yellow)
    make_cube(col_dwc, root_dwc, "DWC_Rim_E", (0.965, 0.0, 0.01), (0.07, 1.86, 0.02), mat_rim_amber_yellow)
    make_cube(col_dwc, root_dwc, "DWC_Rim_W", (-0.965, 0.0, 0.01), (0.07, 1.86, 0.02), mat_rim_amber_yellow)

    # Base concrete slab
    make_cube(col_dwc, root_dwc, "DWC_Base_Slab", (0.0, 0.0, 0.12), (1.86, 1.86, 0.24), mat_conc_dark)

    # Monolithic Concrete Walls (Arm along -X and Arm along -Y)
    make_cube(col_dwc, root_dwc, "DWC_Wall_X", (-0.45, -0.10, 1.15), (0.95, 0.65, 1.80), mat_conc_main)
    make_cube(col_dwc, root_dwc, "DWC_Wall_Y", (-0.10, -0.45, 1.15), (0.65, 0.95, 1.80), mat_conc_main)

    # Massive Octagonal/Beveled Corner Pylon at junction (-0.10, -0.10)
    make_cube(col_dwc, root_dwc, "DWC_Corner_Pylon", (-0.10, -0.10, 1.35), (0.80, 0.80, 2.20), mat_conc_main)

    # Sloped Front Glacis Deflection Plates
    # Glacis on Arm X
    make_cube(col_dwc, root_dwc, "DWC_Glacis_X", (-0.48, -0.42, 0.90), (0.92, 0.18, 1.40), mat_conc_main, rot=(math.radians(18), 0, 0))
    make_cube(col_dwc, root_dwc, "DWC_Armor_X", (-0.48, -0.46, 0.95), (0.94, 0.06, 1.10), mat_steel_dark, rot=(math.radians(18), 0, 0))
    # Glacis on Arm Y
    make_cube(col_dwc, root_dwc, "DWC_Glacis_Y", (-0.42, -0.48, 0.90), (0.18, 0.92, 1.40), mat_conc_main, rot=(0, math.radians(-18), 0))
    make_cube(col_dwc, root_dwc, "DWC_Armor_Y", (-0.46, -0.48, 0.95), (0.06, 0.94, 1.10), mat_steel_dark, rot=(0, math.radians(-18), 0))

    # Corner Nose Heavy Armor Plate at 45°
    make_cube(col_dwc, root_dwc, "DWC_Armor_Corner", (-0.46, -0.46, 1.15), (0.42, 0.08, 1.50), mat_steel_dark, rot=(math.radians(14), math.radians(-14), math.radians(45)))

    # Bolts/Rivets along armor belts
    for i, bx in enumerate([-0.80, -0.50, -0.25]):
        make_cylinder(col_dwc, root_dwc, f"DWC_Bolt_X_{i}", (bx, -0.48, 1.45), 0.025, 0.03, rot=(math.radians(90), 0, 0), mat=mat_steel_galv)
    for i, by in enumerate([-0.80, -0.50, -0.25]):
        make_cylinder(col_dwc, root_dwc, f"DWC_Bolt_Y_{i}", (-0.48, by, 1.45), 0.025, 0.03, rot=(0, math.radians(90), 0), mat=mat_steel_galv)

    # Crenellated Parapet with Firing Slits
    make_cube(col_dwc, root_dwc, "DWC_Parapet_X", (-0.48, -0.32, 2.22), (0.94, 0.22, 0.38), mat_steel_dark)
    make_cube(col_dwc, root_dwc, "DWC_Parapet_Y", (-0.32, -0.48, 2.22), (0.22, 0.94, 0.38), mat_steel_dark)
    make_cube(col_dwc, root_dwc, "DWC_Parapet_C", (-0.28, -0.28, 2.32), (0.44, 0.44, 0.58), mat_steel_dark)

    # Embrasures (warm illuminated slits)
    make_cube(col_dwc, root_dwc, "DWC_Slit_X", (-0.50, -0.38, 2.15), (0.35, 0.05, 0.12), mat_embrasure)
    make_cube(col_dwc, root_dwc, "DWC_Slit_Y", (-0.38, -0.50, 2.15), (0.05, 0.35, 0.12), mat_embrasure)

    # Interior Walkway / Catwalk on the inside (+X, +Y side)
    make_cube(col_dwc, root_dwc, "DWC_Catwalk_Deck", (0.22, 0.22, 1.25), (0.80, 0.80, 0.06), mat_steel_dark)
    # Handrails
    make_cube(col_dwc, root_dwc, "DWC_Railing_X", (0.22, 0.60, 1.70), (0.76, 0.03, 0.03), mat_steel_galv)
    make_cube(col_dwc, root_dwc, "DWC_Railing_Y", (0.60, 0.22, 1.70), (0.03, 0.76, 0.03), mat_steel_galv)
    make_cylinder(col_dwc, root_dwc, "DWC_RailPost_1", (0.60, 0.60, 1.48), 0.02, 0.45, mat=mat_steel_galv)
    make_cylinder(col_dwc, root_dwc, "DWC_RailPost_2", (-0.14, 0.60, 1.48), 0.02, 0.45, mat=mat_steel_galv)
    make_cylinder(col_dwc, root_dwc, "DWC_RailPost_3", (0.60, -0.14, 1.48), 0.02, 0.45, mat=mat_steel_galv)

    # Heavy Triangular Concrete Buttress bracing the interior corner
    make_cube(col_dwc, root_dwc, "DWC_Buttress_Core", (0.32, 0.32, 0.85), (0.36, 0.36, 1.40), mat_conc_dark, rot=(math.radians(-20), math.radians(20), math.radians(45)))

    # Corner technical spire and amber warning beacon
    make_cylinder(col_dwc, root_dwc, "DWC_Mast", (-0.28, -0.28, 2.75), 0.035, 0.36, mat=mat_steel_dark)
    make_cylinder(col_dwc, root_dwc, "DWC_Beacon", (-0.28, -0.28, 2.95), 0.045, 0.08, mat=mat_beacon_amber)

    # Hazard chevron stripe plate along parapet
    make_cube(col_dwc, root_dwc, "DWC_Hazard_X", (-0.48, -0.20, 2.38), (0.80, 0.02, 0.06), mat_hazard)
    make_cube(col_dwc, root_dwc, "DWC_Hazard_Y", (-0.20, -0.48, 2.38), (0.02, 0.80, 0.06), mat_hazard)

    # =========================================================================
    # SAVE MASTER BLEND FILE
    # =========================================================================
    master_blend_path = "c:/dev/MegaProject/assets/models/buildings_master.blend"
    print(f"Saving updated master blend file to {master_blend_path}...")
    bpy.ops.wm.save_as_mainfile(filepath=master_blend_path)
    print("Master blend file saved successfully!")

    # =========================================================================
    # RENDER TASKS (18 ROTATED + 3 CORNERS = 21 RENDERS)
    # =========================================================================
    all_building_cols = [c.name for c in bpy.data.collections if c.name.startswith("Building_")]

    render_tasks = [
        # --- 18 ROTATED VERSIONS (rot_z = 90 deg) ---
        {
            "id": "command_center_rot",
            "col": "Building_CommandCenter",
            "root": "CommandCenter_Root",
            "rot_z": 90.0,
            "res": (768, 768),
            "ortho": 12.6,
            "target": Vector((0.0, 0.0, 2.20)),
            "out": "c:/dev/MegaProject/assets/sprites/buildings_backup/command_center_rot.png"
        },
        {
            "id": "fusion_reactor_rot",
            "col": "Building_FusionReactor",
            "root": "FusionReactor_Root",
            "rot_z": 90.0,
            "res": (512, 512),
            "ortho": 6.8,
            "target": Vector((0.0, 0.0, 1.40)),
            "out": "c:/dev/MegaProject/assets/sprites/buildings_backup/fusion_reactor_rot.png"
        },
        {
            "id": "quarry_rot",
            "col": "Building_Quarry",
            "root": "Quarry_Root",
            "rot_z": 90.0,
            "res": (512, 512),
            "ortho": 6.8,
            "target": Vector((0.0, 0.0, 1.40)),
            "out": "c:/dev/MegaProject/assets/sprites/buildings_backup/quarry_rot.png"
        },
        {
            "id": "factory_rot",
            "col": "Building_Factory",
            "root": "Factory_Root",
            "rot_z": 90.0,
            "res": (512, 512),
            "ortho": 6.8,
            "target": Vector((0.0, 0.0, 1.40)),
            "out": "c:/dev/MegaProject/assets/sprites/buildings_backup/factory_rot.png"
        },
        {
            "id": "habitation_block_rot",
            "col": "Building_HabitationBlock",
            "root": "HabitationBlock_Root",
            "rot_z": 90.0,
            "res": (256, 256),
            "ortho": 5.2,
            "target": Vector((0.0, 0.0, 1.60)),
            "out": "c:/dev/MegaProject/assets/sprites/buildings_backup/habitation_block_rot.png"
        },
        {
            "id": "support_pillar_rot",
            "col": "Building_SupportPillar",
            "root": "SupportPillar_Root",
            "rot_z": 90.0,
            "res": (256, 256),
            "ortho": 5.2,
            "target": Vector((0.0, 0.0, 1.60)),
            "out": "c:/dev/MegaProject/assets/sprites/buildings_backup/support_pillar_rot.png"
        },
        {
            "id": "excavation_rig_rot",
            "col": "Building_ExcavationRig",
            "root": "ExcavationRig_Root",
            "rot_z": 90.0,
            "res": (512, 512),
            "ortho": 6.8,
            "target": Vector((0.0, 0.0, 1.40)),
            "out": "c:/dev/MegaProject/assets/sprites/buildings_backup/excavation_rig_rot.png"
        },
        {
            "id": "power_cable_rot",
            "col": "Building_PowerCable",
            "root": "PowerCable_Root",
            "rot_z": 90.0,
            "res": (256, 256),
            "ortho": 5.2,
            "target": Vector((0.0, 0.0, 1.60)),
            "out": "c:/dev/MegaProject/assets/sprites/buildings_backup/power_cable_rot.png"
        },
        {
            "id": "conveyor_rot",
            "col": "Building_Conveyor",
            "root": "Conveyor_Root",
            "rot_z": 90.0,
            "res": (256, 256),
            "ortho": 5.2,
            "target": Vector((0.0, 0.0, 1.60)),
            "out": "c:/dev/MegaProject/assets/sprites/buildings_backup/conveyor_rot.png"
        },
        {
            "id": "shaft_elevator_rot",
            "col": "Building_ShaftElevator",
            "root": "ShaftElevator_Root",
            "rot_z": 90.0,
            "res": (512, 512),
            "ortho": 6.8,
            "target": Vector((0.0, 0.0, 1.40)),
            "out": "c:/dev/MegaProject/assets/sprites/buildings_backup/shaft_elevator_rot.png"
        },
        {
            "id": "warehouse_rot",
            "col": "Building_Warehouse",
            "root": "Warehouse_Root",
            "rot_z": 90.0,
            "res": (512, 512),
            "ortho": 6.8,
            "target": Vector((0.0, 0.0, 1.40)),
            "out": "c:/dev/MegaProject/assets/sprites/buildings_backup/warehouse_rot.png"
        },
        {
            "id": "defense_wall_rot",
            "col": "Building_DefenseWall",
            "root": "DefenseWall_Root",
            "rot_z": 90.0,
            "res": (256, 256),
            "ortho": 5.2,
            "target": Vector((0.0, 0.0, 1.60)),
            "out": "c:/dev/MegaProject/assets/sprites/buildings_backup/defense_wall_rot.png"
        },
        {
            "id": "autocannon_turret_rot",
            "col": "Building_AutocannonTurret",
            "root": "AutocannonTurret_Root",
            "rot_z": 90.0,
            "res": (256, 256),
            "ortho": 5.2,
            "target": Vector((0.0, 0.0, 1.60)),
            "out": "c:/dev/MegaProject/assets/sprites/buildings_backup/autocannon_turret_rot.png"
        },
        {
            "id": "heavy_railgun_rot",
            "col": "Building_HeavyRailgun",
            "root": "HeavyRailgun_Root",
            "rot_z": 90.0,
            "res": (512, 512),
            "ortho": 6.8,
            "target": Vector((0.0, 0.0, 1.40)),
            "out": "c:/dev/MegaProject/assets/sprites/buildings_backup/heavy_railgun_rot.png"
        },
        {
            "id": "shield_generator_rot",
            "col": "Building_ShieldGenerator",
            "root": "ShieldGenerator_Root",
            "rot_z": 90.0,
            "res": (512, 512),
            "ortho": 6.8,
            "target": Vector((0.0, 0.0, 1.40)),
            "out": "c:/dev/MegaProject/assets/sprites/buildings_backup/shield_generator_rot.png"
        },
        {
            "id": "munitions_factory_rot",
            "col": "Building_MunitionsFactory",
            "root": "MunitionsFactory_Root",
            "rot_z": 90.0,
            "res": (512, 512),
            "ortho": 6.8,
            "target": Vector((0.0, 0.0, 1.40)),
            "out": "c:/dev/MegaProject/assets/sprites/buildings_backup/munitions_factory_rot.png"
        },
        {
            "id": "sensor_tower_rot",
            "col": "Building_SensorTower",
            "root": "SensorTower_Root",
            "rot_z": 90.0,
            "res": (256, 256),
            "ortho": 5.2,
            "target": Vector((0.0, 0.0, 1.60)),
            "out": "c:/dev/MegaProject/assets/sprites/buildings_backup/sensor_tower_rot.png"
        },
        {
            "id": "repair_depot_rot",
            "col": "Building_RepairDepot",
            "root": "RepairDepot_Root",
            "rot_z": 90.0,
            "res": (512, 512),
            "ortho": 6.8,
            "target": Vector((0.0, 0.0, 1.40)),
            "out": "c:/dev/MegaProject/assets/sprites/buildings_backup/repair_depot_rot.png"
        },

        # --- 3 CORNER VERSIONS (rot_z = 0 deg) ---
        {
            "id": "power_cable_corner",
            "col": "Building_PowerCable_Corner",
            "root": "PowerCable_Corner_Root",
            "rot_z": 0.0,
            "res": (256, 256),
            "ortho": 5.2,
            "target": Vector((0.0, 0.0, 1.60)),
            "out": "c:/dev/MegaProject/assets/sprites/buildings_backup/power_cable_corner.png"
        },
        {
            "id": "conveyor_corner",
            "col": "Building_Conveyor_Corner",
            "root": "Conveyor_Corner_Root",
            "rot_z": 0.0,
            "res": (256, 256),
            "ortho": 5.2,
            "target": Vector((0.0, 0.0, 1.60)),
            "out": "c:/dev/MegaProject/assets/sprites/buildings_backup/conveyor_corner.png"
        },
        {
            "id": "defense_wall_corner",
            "col": "Building_DefenseWall_Corner",
            "root": "DefenseWall_Corner_Root",
            "rot_z": 0.0,
            "res": (256, 256),
            "ortho": 5.2,
            "target": Vector((0.0, 0.0, 1.60)),
            "out": "c:/dev/MegaProject/assets/sprites/buildings_backup/defense_wall_corner.png"
        }
    ]

    dist = 30.0
    fwd = Vector((-math.sqrt(6)/4, math.sqrt(6)/4, -0.5))

    for task in render_tasks:
        print(f"\n--- RENDERING {task['id']} ---")
        # Isolate collection
        for cname in all_building_cols:
            col = bpy.data.collections.get(cname)
            if col:
                is_target = (cname == task["col"])
                col.hide_render = not is_target
                col.hide_viewport = not is_target

        root_obj = bpy.data.objects.get(task["root"])
        if root_obj:
            root_obj.rotation_euler.z = math.radians(task["rot_z"])

        scene.render.resolution_x = task["res"][0]
        scene.render.resolution_y = task["res"][1]
        scene.render.filepath = task["out"]

        cam.data.ortho_scale = task["ortho"]
        cam.location = task["target"] - dist * fwd

        print(f"Task: {task['id']}, Res: {task['res']}, Ortho: {task['ortho']}, Cam Loc: {[round(v, 2) for v in cam.location]}")
        print(f"Output: {task['out']}")

        bpy.ops.render.render(write_still=True)

        # Reset rotation if rotated
        if root_obj and task["rot_z"] != 0.0:
            root_obj.rotation_euler.z = 0.0

        print(f"Render finished for {task['id']}!")

    # Reset all collections visibility
    for cname in all_building_cols:
        col = bpy.data.collections.get(cname)
        if col:
            col.hide_render = False
            col.hide_viewport = False

    print("\n=== ALL ROTATED AND CORNER RENDERS COMPLETED SUCCESSFULLY! ===")

if __name__ == "__main__":
    run()
