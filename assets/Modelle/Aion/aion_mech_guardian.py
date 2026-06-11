import bpy, bmesh, math
from mathutils import Vector

# ============================================================
# AION  —  MECH GUARDIAN  |  Roblox-safe FBX
# Mechanischer Titan-Wächter: Die Kugel sitzt im Brust-Reaktor.
# Riesige Panzer-Schultern, mächtige Arme mit Energiekanonen,
# Visor-Helm, Rückenplatten mit Schubdüsen, Energie-Leitungen.
# ============================================================

C_ORB     = (0.04, 0.06, 0.18, 1.0)   # Kugel Dunkelblau
C_ARMOR   = (0.18, 0.20, 0.24, 1.0)   # Panzer Dunkelgrau
C_ARMOR2  = (0.10, 0.12, 0.16, 1.0)   # Panzer Schwarz-Grau
C_TRIM    = (0.08, 0.48, 0.82, 1.0)   # Akzent Blau (Energie)
C_TRIM2   = (0.04, 0.28, 0.55, 1.0)   # Akzent Dunkelblau
C_GLOW    = (0.15, 0.88, 1.00, 1.0)   # Reaktor-Glühen Cyan
C_GLOW2   = (0.04, 0.55, 0.92, 1.0)   # Reaktor-Blau
C_CANNON  = (0.22, 0.24, 0.28, 1.0)   # Kanone Grau
C_VISOR   = (0.08, 0.72, 0.95, 1.0)   # Visor Cyan-Blau
C_PIPE    = (0.30, 0.32, 0.36, 1.0)   # Leitungsrohre
C_BOLT    = (0.55, 0.50, 0.44, 1.0)   # Schrauben/Nieten
C_THRUST  = (0.80, 0.42, 0.04, 1.0)   # Schubdüse Orange

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for c in list(bpy.data.collections):
        bpy.data.collections.remove(c)

def vcol(obj, color):
    if obj.type != 'MESH': return
    mesh = obj.data
    if "Color" not in mesh.color_attributes:
        mesh.color_attributes.new(name="Color", type='FLOAT_COLOR', domain='CORNER')
    for d in mesh.color_attributes["Color"].data:
        d.color = color

def smooth(obj):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.shade_smooth()

def cyl(name, s, e, r=0.05, v=8):
    sv, ev = Vector(s), Vector(e)
    vec = ev - sv
    bpy.ops.mesh.primitive_cylinder_add(
        radius=r, depth=vec.length, vertices=v, location=(sv+ev)*0.5)
    obj = bpy.context.active_object; obj.name = name
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = vec.to_track_quat('Z','Y')
    smooth(obj); return obj

def cone_obj(name, s, e, r1=0.06, r2=0.0, v=6):
    sv, ev = Vector(s), Vector(e)
    vec = ev - sv
    bpy.ops.mesh.primitive_cone_add(
        radius1=r1, radius2=r2, depth=vec.length, vertices=v,
        location=(sv+ev)*0.5)
    obj = bpy.context.active_object; obj.name = name
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = vec.to_track_quat('Z','Y')
    smooth(obj); return obj


# ═══════════════════════════════════════════════════════════════
# KUGEL & REAKTOR-KERN
# ═══════════════════════════════════════════════════════════════
def create_orb():
    parts = []
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, segments=64, ring_count=32, location=(0,0,0))
    orb = bpy.context.active_object; orb.name = "Aion_Orb"; smooth(orb); vcol(orb, C_ORB); parts.append(orb)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.62, segments=24, ring_count=12, location=(0,0,0))
    c1 = bpy.context.active_object; c1.name = "Reactor_Mid"; smooth(c1); vcol(c1, C_TRIM2); parts.append(c1)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.32, subdivisions=2, location=(0,0,0))
    c2 = bpy.context.active_object; c2.name = "Reactor_Core"; smooth(c2); vcol(c2, C_GLOW); parts.append(c2)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.14, segments=10, ring_count=6, location=(0,0,0))
    c3 = bpy.context.active_object; c3.name = "Reactor_Nucleus"; smooth(c3); vcol(c3, (0.90,0.96,1.0,1.0)); parts.append(c3)
    # Reaktor-Ringe
    for i, (maj, col) in enumerate([(1.04, C_GLOW), (1.14, C_TRIM), (1.26, C_ARMOR)]):
        bpy.ops.mesh.primitive_torus_add(major_radius=maj, minor_radius=0.022-i*0.004,
                                          major_segments=64, minor_segments=9, location=(0,0,0))
        r = bpy.context.active_object; r.name = f"Reactor_Ring_{i}"; vcol(r, col); parts.append(r)
    # Energie-Strahlen vom Reaktor
    for i in range(8):
        a = (i/8)*math.tau
        p0 = (math.cos(a)*1.04, math.sin(a)*1.04, 0)
        p1 = (math.cos(a)*1.35, math.sin(a)*1.35, 0)
        ray = cone_obj(f"Reactor_Beam_{i}", p0, p1, 0.020, 0.004, 4)
        vcol(ray, C_GLOW2 if i%2==0 else C_TRIM); parts.append(ray)
    return parts


# ═══════════════════════════════════════════════════════════════
# HELM
# ═══════════════════════════════════════════════════════════════
def create_helm():
    parts = []
    # Haupt-Helm-Körper
    bpy.ops.mesh.primitive_cylinder_add(radius=0.65, depth=0.45, vertices=12, location=(0, -0.65, 1.18))
    helm_body = bpy.context.active_object; helm_body.name = "Helm_Body"; smooth(helm_body); vcol(helm_body, C_ARMOR); parts.append(helm_body)
    # Helm-Haube (Oberseite)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.66, segments=12, ring_count=7, location=(0, -0.65, 1.35))
    helm_top = bpy.context.active_object; helm_top.name = "Helm_Top"; smooth(helm_top); vcol(helm_top, C_ARMOR); parts.append(helm_top)
    # Visor (Sicht-Panel, abgeflachter Würfel)
    bpy.ops.mesh.primitive_cube_add(size=1.0, scale=(0.90, 0.08, 0.28),
                                     location=(0, -1.18, 1.22))
    visor = bpy.context.active_object; visor.name = "Helm_Visor"; vcol(visor, C_VISOR); parts.append(visor)
    # Visor-Leuchten (2 Augen)
    for ex in [-0.20, 0.20]:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.068, segments=8, ring_count=5, location=(ex, -1.22, 1.24))
        eye = bpy.context.active_object; eye.name = f"Helm_Eye_{int(ex*10)}"; smooth(eye); vcol(eye, C_GLOW); parts.append(eye)
    # Helm-Kinn-Schutz
    bpy.ops.mesh.primitive_cube_add(size=1.0, scale=(0.70, 0.25, 0.18), location=(0, -1.08, 0.98))
    chin = bpy.context.active_object; chin.name = "Helm_Chin"; vcol(chin, C_ARMOR2); parts.append(chin)
    # 2 Seiten-Lüftungsrippen
    for sx in [-0.62, 0.62]:
        for ri in range(3):
            bpy.ops.mesh.primitive_cube_add(size=1.0, scale=(0.06, 0.20, 0.08),
                                             location=(sx, -0.90, 1.08 + ri*0.12))
            vent = bpy.context.active_object; vent.name = f"Helm_Vent_{int(sx*10)}_{ri}"
            vcol(vent, C_TRIM2 if ri%2==0 else C_ARMOR2); parts.append(vent)
    # Helm-Antenne (oben links)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.018, depth=0.40, vertices=5, location=(-0.35, -0.68, 1.80))
    ant = bpy.context.active_object; ant.name = "Helm_Antenna"; smooth(ant); vcol(ant, C_ARMOR2); parts.append(ant)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.030, segments=6, ring_count=4, location=(-0.35, -0.68, 2.01))
    ant_tip = bpy.context.active_object; ant_tip.name = "Helm_AntennaTip"; smooth(ant_tip); vcol(ant_tip, C_GLOW); parts.append(ant_tip)
    # Helm-Randleiste
    bpy.ops.mesh.primitive_torus_add(major_radius=0.66, minor_radius=0.030, major_segments=24, minor_segments=7,
                                      location=(0, -0.65, 1.12), rotation=(math.pi/2, 0, 0))
    helm_rim = bpy.context.active_object; helm_rim.name = "Helm_Rim"
    bpy.ops.object.transform_apply(rotation=True)
    vcol(helm_rim, C_TRIM); parts.append(helm_rim)
    return parts


# ═══════════════════════════════════════════════════════════════
# SCHULTER-PANZER
# ═══════════════════════════════════════════════════════════════
def create_shoulder(side, sx):
    parts = []
    # Haupt-Schulterball (runde Panzerplatte)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.52, segments=14, ring_count=8,
                                          location=(sx*1.55, -0.10, 0.55))
    sp = bpy.context.active_object; sp.name = f"Shoulder_{side}_Main"; smooth(sp); vcol(sp, C_ARMOR); parts.append(sp)
    # Schulter-Überpanzer (flacher Halbkegel)
    bpy.ops.mesh.primitive_cone_add(radius1=0.58, radius2=0.22, depth=0.30, vertices=10,
                                     location=(sx*1.55, -0.05, 0.80))
    top_plate = bpy.context.active_object; top_plate.name = f"Shoulder_{side}_TopPlate"
    smooth(top_plate); vcol(top_plate, C_ARMOR2); parts.append(top_plate)
    # 3 Schulter-Rippen
    for ri in range(3):
        a = (ri/3)*math.pi - math.pi/6
        rx = sx*1.55 + math.cos(a)*0.50
        ry = -0.10 + math.sin(a)*0.25
        bpy.ops.mesh.primitive_cube_add(size=1.0, scale=(0.28, 0.06, 0.14),
                                         location=(rx, ry, 0.58), rotation=(0, 0, a))
        rib = bpy.context.active_object; rib.name = f"Shoulder_{side}_Rib{ri}"
        vcol(rib, C_TRIM2); parts.append(rib)
    # Schulter-Nieten (5 Bolzen)
    for ni in range(5):
        na = (ni/5)*math.tau
        nx = sx*1.55 + math.cos(na)*0.40
        ny = -0.10 + math.sin(na)*0.40
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.026, segments=5, ring_count=4, location=(nx, ny, 0.60))
        bolt = bpy.context.active_object; bolt.name = f"Shoulder_{side}_Bolt{ni}"; smooth(bolt); vcol(bolt, C_BOLT); parts.append(bolt)
    # Energie-Kanäle
    bpy.ops.mesh.primitive_torus_add(major_radius=0.46, minor_radius=0.018, major_segments=20, minor_segments=6,
                                      location=(sx*1.55, -0.10, 0.55))
    ec = bpy.context.active_object; ec.name = f"Shoulder_{side}_EnergyRing"; vcol(ec, C_TRIM); parts.append(ec)
    return parts


# ═══════════════════════════════════════════════════════════════
# ARM & KANONE
# ═══════════════════════════════════════════════════════════════
def create_arm(side, sx):
    parts = []
    # Oberarm
    bpy.ops.mesh.primitive_cylinder_add(radius=0.24, depth=0.70, vertices=10,
                                         location=(sx*1.80, -0.10, 0.10), rotation=(0, math.pi/2, 0))
    upper = bpy.context.active_object; upper.name = f"Arm_{side}_Upper"
    bpy.ops.object.transform_apply(rotation=True)
    smooth(upper); vcol(upper, C_ARMOR); parts.append(upper)
    # Ellenbogen-Kugel
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.26, segments=12, ring_count=7,
                                          location=(sx*2.22, -0.10, 0.10))
    elbow = bpy.context.active_object; elbow.name = f"Arm_{side}_Elbow"; smooth(elbow); vcol(elbow, C_ARMOR2); parts.append(elbow)
    # Unterarm
    bpy.ops.mesh.primitive_cylinder_add(radius=0.20, depth=0.65, vertices=10,
                                         location=(sx*2.62, -0.10, 0.10), rotation=(0, math.pi/2, 0))
    lower = bpy.context.active_object; lower.name = f"Arm_{side}_Lower"
    bpy.ops.object.transform_apply(rotation=True)
    smooth(lower); vcol(lower, C_ARMOR); parts.append(lower)
    # Handgelenk-Ring
    bpy.ops.mesh.primitive_torus_add(major_radius=0.22, minor_radius=0.038, major_segments=18, minor_segments=7,
                                      location=(sx*2.98, -0.10, 0.10), rotation=(0, math.pi/2, 0))
    wrist = bpy.context.active_object; wrist.name = f"Arm_{side}_Wrist"
    bpy.ops.object.transform_apply(rotation=True)
    vcol(wrist, C_TRIM); parts.append(wrist)

    # Energie-Kanone am Ende (Unterarmmündung)
    cannon_base = (sx*3.08, -0.10, 0.10)
    cannon_tip  = (sx*3.78, -0.10, 0.10)
    main_cannon = cyl(f"Arm_{side}_Cannon", cannon_base, cannon_tip, 0.16, 10)
    vcol(main_cannon, C_CANNON); parts.append(main_cannon)
    # Kanonen-Spitze
    ctip = (sx*3.82, -0.10, 0.10); ctip2 = (sx*4.05, -0.10, 0.10)
    muzzle = cyl(f"Arm_{side}_Muzzle", ctip, ctip2, 0.10, 8)
    vcol(muzzle, C_ARMOR2); parts.append(muzzle)
    # Kanonen-Mündungsring
    bpy.ops.mesh.primitive_torus_add(major_radius=0.12, minor_radius=0.020, major_segments=14, minor_segments=6,
                                      location=(sx*4.06, -0.10, 0.10), rotation=(0, math.pi/2, 0))
    mring = bpy.context.active_object; mring.name = f"Arm_{side}_MuzzleRing"
    bpy.ops.object.transform_apply(rotation=True)
    vcol(mring, C_TRIM); parts.append(mring)
    # 2 Neben-Läufe (kleine Zylinder)
    for ni, nz in enumerate([-0.18, 0.18]):
        nb = (sx*3.08, -0.10, 0.10+nz); nt = (sx*3.85, -0.10, 0.10+nz)
        tube = cyl(f"Arm_{side}_Tube{ni}", nb, nt, 0.055, 6)
        vcol(tube, C_CANNON); parts.append(tube)
    # Energie-Leitungsrohre entlang Oberarm (3 Rohre)
    for pi in range(3):
        pa = math.pi*(pi/3)
        pbase = (sx*1.58, -0.10 + math.sin(pa)*0.27, 0.10 + math.cos(pa)*0.27)
        ptip  = (sx*2.98, -0.10 + math.sin(pa)*0.23, 0.10 + math.cos(pa)*0.23)
        pipe = cyl(f"Arm_{side}_Pipe{pi}", pbase, ptip, 0.022, 5)
        vcol(pipe, C_TRIM if pi==1 else C_PIPE); parts.append(pipe)
    return parts


# ═══════════════════════════════════════════════════════════════
# RÜCKEN-SCHUBDÜSEN & PLATTEN
# ═══════════════════════════════════════════════════════════════
def create_backpack():
    parts = []
    # Rücken-Basis-Platte
    bpy.ops.mesh.primitive_cube_add(size=1.0, scale=(1.10, 0.25, 0.80), location=(0, 0.88, 0.20))
    back_plate = bpy.context.active_object; back_plate.name = "Back_MainPlate"
    vcol(back_plate, C_ARMOR2); parts.append(back_plate)
    # 4 Schubdüsen (2 links, 2 rechts)
    thruster_pos = [(-0.36, 1.02, 0.42), (0.36, 1.02, 0.42), (-0.36, 1.02, -0.02), (0.36, 1.02, -0.02)]
    for ti, tpos in enumerate(thruster_pos):
        # Düsen-Gehäuse
        bpy.ops.mesh.primitive_cylinder_add(radius=0.14, depth=0.35, vertices=8, location=tpos)
        th_body = bpy.context.active_object; th_body.name = f"Thruster_{ti}_Body"; smooth(th_body); vcol(th_body, C_ARMOR); parts.append(th_body)
        # Düsen-Öffnung
        nozzle_base = (tpos[0], tpos[1]+0.20, tpos[2])
        nozzle_tip  = (tpos[0], tpos[1]+0.38, tpos[2])
        nozzle = cone_obj(f"Thruster_{ti}_Nozzle", nozzle_base, nozzle_tip, 0.14, 0.06, 8)
        vcol(nozzle, C_ARMOR2); parts.append(nozzle)
        # Schub-Glut (Flammen-Innenleuchten)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.065, segments=7, ring_count=5, location=(tpos[0], tpos[1]+0.35, tpos[2]))
        flame = bpy.context.active_object; flame.name = f"Thruster_{ti}_Flame"; smooth(flame); vcol(flame, C_THRUST); parts.append(flame)
        # Düsen-Ring
        bpy.ops.mesh.primitive_torus_add(major_radius=0.14, minor_radius=0.022, major_segments=14, minor_segments=6,
                                          location=(tpos[0], tpos[1]+0.18, tpos[2]), rotation=(math.pi/2, 0, 0))
        dring = bpy.context.active_object; dring.name = f"Thruster_{ti}_Ring"
        bpy.ops.object.transform_apply(rotation=True)
        vcol(dring, C_TRIM); parts.append(dring)
    # Rücken-Energie-Leitung (zentrales Röhrensystem)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.040, depth=0.80, vertices=6, location=(0, 0.94, 0.20))
    spine = bpy.context.active_object; spine.name = "Back_SpinePipe"; smooth(spine); vcol(spine, C_GLOW2); parts.append(spine)
    for si in range(4):
        z_pos = -0.20 + si*0.22
        bpy.ops.mesh.primitive_torus_add(major_radius=0.045, minor_radius=0.015, major_segments=10, minor_segments=5,
                                          location=(0, 0.94, z_pos))
        sr = bpy.context.active_object; sr.name = f"Back_SpineRing_{si}"; vcol(sr, C_GLOW); parts.append(sr)
    # Rücken-Platten-Rippen (6 horizontale Platten)
    for ri in range(6):
        bpy.ops.mesh.primitive_cube_add(size=1.0, scale=(0.80, 0.08, 0.06),
                                         location=(0, 0.98, -0.15 + ri*0.13))
        plate_rib = bpy.context.active_object; plate_rib.name = f"Back_Rib_{ri}"
        vcol(plate_rib, C_TRIM2 if ri%2==0 else C_ARMOR); parts.append(plate_rib)
    return parts


# ═══════════════════════════════════════════════════════════════
# ENERGIE-LEITUNGEN (verbinden Schulter → Reaktor)
# ═══════════════════════════════════════════════════════════════
def create_energy_pipes():
    parts = []
    pipe_paths = [
        # (start, end, radius, color)
        ((1.30, 0.40, 0.55), (1.02, 0.0, 0.55), 0.028, C_GLOW),
        ((-1.30, 0.40, 0.55), (-1.02, 0.0, 0.55), 0.028, C_GLOW),
        ((0.85, 0.92, 0.35), (0, 0.98, 0.20), 0.022, C_TRIM),
        ((-0.85, 0.92, 0.35), (0, 0.98, 0.20), 0.022, C_TRIM),
        ((0, -0.85, 1.10), (0, -0.60, 1.04), 0.018, C_GLOW2),
        ((1.55, -0.10, 0.55), (1.04, 0, 0.20), 0.020, C_TRIM2),
        ((-1.55, -0.10, 0.55), (-1.04, 0, 0.20), 0.020, C_TRIM2),
    ]
    for pi, (s, e, r, col) in enumerate(pipe_paths):
        pipe = cyl(f"EnergyPipe_{pi}", s, e, r, 6)
        vcol(pipe, col); parts.append(pipe)
        # Verbindungs-Knoten-Kugeln
        bpy.ops.mesh.primitive_uv_sphere_add(radius=r*1.8, segments=6, ring_count=4, location=s)
        jt = bpy.context.active_object; jt.name = f"PipeJoint_{pi}_S"; smooth(jt); vcol(jt, C_GLOW if col==C_GLOW else C_TRIM); parts.append(jt)
    return parts


clear_scene()
col = bpy.data.collections.new("Aion_MechGuardian")
bpy.context.scene.collection.children.link(col)

all_parts = (create_orb()
           + create_helm()
           + create_shoulder("L", -1) + create_shoulder("R", 1)
           + create_arm("L", -1) + create_arm("R", 1)
           + create_backpack()
           + create_energy_pipes())

for obj in all_parts:
    for c in list(obj.users_collection): c.objects.unlink(obj)
    col.objects.link(obj)
print(f"✅ Aion Mech Guardian — {len(all_parts)} Teile")
