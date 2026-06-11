import bpy, bmesh, math
from mathutils import Vector

# ============================================================
# AION  —  PHOENIX WINGS  |  Roblox-safe FBX
# Feuerphönix: 2 riesige Flügel aus Flammen-Federn,
# Phönix-Kopf mit Schnabel, Feuerkrone, Schweiffedern,
# Ember-Partikel-Strom, goldener Glorienschein.
# ============================================================

C_ORB     = (0.20, 0.06, 0.01, 1.0)   # Kugel Tiefrot
C_CORE    = (0.90, 0.55, 0.05, 1.0)   # Kern Gold
C_FEATHER = (0.72, 0.18, 0.02, 1.0)   # Federn Dunkelrot
C_FEATHER2= (0.92, 0.42, 0.04, 1.0)   # Federn Orange
C_TIP     = (1.00, 0.82, 0.20, 1.0)   # Feder-Spitzen Gold
C_FLAME   = (0.98, 0.62, 0.04, 1.0)   # Flammen Orange
C_FLAME2  = (1.00, 0.90, 0.28, 1.0)   # Flammen Gelb
C_EMBER   = (0.95, 0.32, 0.02, 1.0)   # Ember Rot-Orange
C_BEAK    = (0.75, 0.60, 0.08, 1.0)   # Schnabel Gold
C_EYE_P   = (0.96, 0.72, 0.04, 1.0)   # Auge Gold-Gelb
C_CROWN   = (0.98, 0.78, 0.10, 1.0)   # Krone Gold
C_TAIL    = (0.80, 0.20, 0.02, 1.0)   # Schweif Dunkelrot
C_HALO    = (0.98, 0.70, 0.10, 1.0)   # Halo Gold

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
# KUGEL & GLUT-KERN
# ═══════════════════════════════════════════════════════════════
def create_orb():
    parts = []
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, segments=64, ring_count=32, location=(0,0,0))
    orb = bpy.context.active_object; orb.name = "Aion_Orb"; smooth(orb); vcol(orb, C_ORB); parts.append(orb)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.65, segments=24, ring_count=12, location=(0,0,0))
    c1 = bpy.context.active_object; c1.name = "Phoenix_Ember1"; smooth(c1); vcol(c1, (0.65,0.22,0.03,1.0)); parts.append(c1)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.35, subdivisions=2, location=(0,0,0))
    c2 = bpy.context.active_object; c2.name = "Phoenix_Core"; smooth(c2); vcol(c2, C_CORE); parts.append(c2)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.15, segments=10, ring_count=6, location=(0,0,0))
    c3 = bpy.context.active_object; c3.name = "Phoenix_Nucleus"; smooth(c3); vcol(c3, C_FLAME2); parts.append(c3)
    # Glut-Ringe
    for i, (maj, col) in enumerate([(1.05, C_FLAME), (1.20, C_EMBER), (1.38, (0.60,0.12,0.02,1.0))]):
        bpy.ops.mesh.primitive_torus_add(major_radius=maj, minor_radius=0.022-i*0.003,
                                          major_segments=60, minor_segments=8, location=(0,0,0))
        r = bpy.context.active_object; r.name = f"Orb_FireRing_{i}"; vcol(r, col); parts.append(r)
    # Glorie-Halo (großer goldener Ring)
    bpy.ops.mesh.primitive_torus_add(major_radius=1.62, minor_radius=0.040, major_segments=80, minor_segments=12, location=(0,0,0))
    halo = bpy.context.active_object; halo.name = "Phoenix_Halo"; vcol(halo, C_HALO); parts.append(halo)
    # 16 Halo-Strahlen
    for i in range(16):
        a = (i/16)*math.tau
        p0 = (math.cos(a)*1.62, math.sin(a)*1.62, 0)
        p1 = (math.cos(a)*2.00, math.sin(a)*2.00, 0)
        ray = cone_obj(f"Halo_Ray_{i}", p0, p1, 0.022, 0.005, 4)
        vcol(ray, C_CROWN if i%2==0 else C_FLAME2); parts.append(ray)
    return parts


# ═══════════════════════════════════════════════════════════════
# PHÖNIX-KOPF
# ═══════════════════════════════════════════════════════════════
def create_phoenix_head():
    parts = []
    # Hals-Zylinder
    bpy.ops.mesh.primitive_cylinder_add(radius=0.18, depth=0.38, vertices=10, location=(0, -0.85, 1.10))
    neck = bpy.context.active_object; neck.name = "Head_Neck"; smooth(neck); vcol(neck, C_FEATHER); parts.append(neck)
    # Schädelkugel
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.28, segments=16, ring_count=10, location=(0, -0.95, 1.38))
    skull = bpy.context.active_object; skull.name = "Head_Skull"; smooth(skull); vcol(skull, C_FEATHER); parts.append(skull)
    # Schnabel (oben + unten)
    beak_base = (0, -1.16, 1.36)
    beak_tip  = (0, -1.72, 1.32)
    upper_beak = cone_obj("Beak_Upper", beak_base, beak_tip, 0.08, 0.012, 6)
    vcol(upper_beak, C_BEAK); parts.append(upper_beak)
    lower_base = (0, -1.16, 1.28)
    lower_tip  = (0, -1.65, 1.26)
    lower_beak = cone_obj("Beak_Lower", lower_base, lower_tip, 0.062, 0.010, 6)
    vcol(lower_beak, C_BEAK); parts.append(lower_beak)
    # Nasenkerbe
    bpy.ops.mesh.primitive_cube_add(size=0.04, scale=(1.5,1.0,0.6), location=(0,-1.28,1.40))
    nostril = bpy.context.active_object; nostril.name = "Beak_Nostril"; vcol(nostril, (0.55,0.42,0.05,1.0)); parts.append(nostril)
    # 2 Augen
    for side, ex in [("L", -0.15), ("R", 0.15)]:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.068, segments=10, ring_count=6, location=(ex, -1.08, 1.42))
        eye = bpy.context.active_object; eye.name = f"Head_Eye_{side}"; smooth(eye); vcol(eye, C_EYE_P); parts.append(eye)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.035, segments=8, ring_count=5, location=(ex, -1.14, 1.42))
        pupil = bpy.context.active_object; pupil.name = f"Head_Pupil_{side}"; smooth(pupil); vcol(pupil, (0.05,0.03,0.01,1.0)); parts.append(pupil)
        bpy.ops.mesh.primitive_torus_add(major_radius=0.075, minor_radius=0.012, major_segments=16, minor_segments=5, location=(ex,-1.08,1.42))
        erim = bpy.context.active_object; erim.name = f"Head_EyeRim_{side}"; vcol(erim, C_FLAME2); parts.append(erim)
    # Feuerkrone (7 Flammen-Kegel auf dem Kopf)
    for i in range(7):
        a = (i/7)*math.tau
        cr = 0.22
        cx = math.cos(a)*cr; cy = -0.95 + math.sin(a)*cr*0.5
        base = (cx, cy, 1.58)
        heights = [0.32, 0.48, 0.38, 0.55, 0.34, 0.50, 0.40]
        tip  = (cx*0.5, cy - 0.05, 1.58 + heights[i])
        fc = cone_obj(f"Crown_Flame_{i}", base, tip, 0.055, 0.008, 5)
        vcol(fc, C_FLAME if i%2==0 else C_FLAME2); parts.append(fc)
        # Flammen-Kern
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.025, segments=6, ring_count=4, location=tip)
        fk = bpy.context.active_object; fk.name = f"Crown_FlameTip_{i}"; smooth(fk); vcol(fk, C_FLAME2); parts.append(fk)
    # Kopf-Federn (6 Kragen-Federn um den Hals)
    for i in range(6):
        a = (i/6)*math.tau
        fb = (math.cos(a)*0.18, -0.85 + math.sin(a)*0.18, 1.06)
        ft = (math.cos(a)*0.40, -0.85 + math.sin(a)*0.30, 0.88)
        nf = cone_obj(f"Neck_Feather_{i}", fb, ft, 0.045, 0.008, 5)
        vcol(nf, C_FEATHER2 if i%2==0 else C_FEATHER); parts.append(nf)
    return parts


# ═══════════════════════════════════════════════════════════════
# FLÜGEL
# ═══════════════════════════════════════════════════════════════
def create_wing(side, sx):
    parts = []
    # Flügel-Ansatz-Koordinaten (links: sx=-1, rechts: sx=1)
    anchor = Vector((sx*1.02, 0, 0.20))

    # Flügel-Knochen-Arm (3 Segmente: Oberarm -> Unterarm -> Handwurzel)
    arm_pts = [
        anchor,
        anchor + Vector((sx*0.80, -0.25, 0.55)),
        anchor + Vector((sx*1.65, -0.30, 0.88)),
        anchor + Vector((sx*2.55, -0.15, 0.60)),
    ]
    for i in range(len(arm_pts)-1):
        bone = cyl(f"Wing{side}_Bone{i}", arm_pts[i], arm_pts[i+1], 0.055, 7)
        vcol(bone, C_FEATHER); parts.append(bone)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.068, segments=8, ring_count=5, location=arm_pts[i+1])
        jt = bpy.context.active_object; jt.name = f"Wing{side}_Joint{i}"; smooth(jt); vcol(jt, C_EMBER); parts.append(jt)

    # Primärfedern (12 lange Federn, von Handwurzel ausgehend)
    for fi in range(12):
        t = fi / 11
        # Basis-Punkt entlang Unterarm
        base_interp = arm_pts[2] + (arm_pts[3] - arm_pts[2]) * (fi / 11)
        spread_angle = math.pi*0.10 + t * math.pi*0.35  # Fächer
        feather_len = 0.75 + t*0.60  # äußere Federn länger
        tip = base_interp + Vector((
            sx * math.cos(spread_angle) * feather_len,
            -math.sin(spread_angle) * feather_len * 0.30,
            -math.sin(spread_angle) * feather_len * 0.55))
        pf = cone_obj(f"Wing{side}_Primary{fi}", base_interp, tip,
                      0.045 + t*0.020, 0.008, 6)
        t3 = fi % 3
        vcol(pf, C_TIP if t3==0 else (C_FLAME if t3==1 else C_FEATHER2)); parts.append(pf)
        # Flammen-Glut an Feder-Spitzen
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.028, segments=5, ring_count=4, location=tip)
        fg = bpy.context.active_object; fg.name = f"Wing{side}_PrimTip{fi}"; smooth(fg); vcol(fg, C_FLAME2); parts.append(fg)

    # Sekundärfedern (10 mittlere Federn entlang Oberarm)
    for fi in range(10):
        t = fi / 9
        base_interp = arm_pts[1] + (arm_pts[2] - arm_pts[1]) * t
        feather_len = 0.50 + t*0.22
        tip = base_interp + Vector((
            sx * 0.18,
            -feather_len * 0.80,
            -feather_len * 0.55))
        sf = cone_obj(f"Wing{side}_Secondary{fi}", base_interp, tip, 0.038, 0.007, 5)
        vcol(sf, C_FEATHER if fi%2==0 else C_FEATHER2); parts.append(sf)

    # Obere Decken-Federn (8 kleine Federn über Oberarm)
    for fi in range(8):
        t = fi / 7
        base_interp = arm_pts[0] + (arm_pts[1] - arm_pts[0]) * t
        tip = base_interp + Vector((sx*0.10, -0.28, 0.35 - t*0.15))
        cf = cone_obj(f"Wing{side}_Covert{fi}", base_interp, tip, 0.028, 0.006, 5)
        vcol(cf, C_FEATHER if fi%2==0 else C_EMBER); parts.append(cf)

    # Flammen-Federn am Flügelrand (6 extra Flammen)
    for fi in range(6):
        base = arm_pts[3] + Vector((sx*fi*0.15, 0, -fi*0.08))
        tip  = base + Vector((sx*0.25, -0.10, -0.30))
        ff = cone_obj(f"Wing{side}_FlameFeather{fi}", base, tip, 0.030, 0.005, 4)
        vcol(ff, C_FLAME if fi%2==0 else C_FLAME2); parts.append(ff)

    return parts


# ═══════════════════════════════════════════════════════════════
# SCHWEIFFEDERN
# ═══════════════════════════════════════════════════════════════
def create_tail():
    parts = []
    tail_configs = [
        # (phi, length, tilt_out, color)
        (math.pi*0.50, 1.40, 0.20, C_TAIL),
        (math.pi*0.62, 1.65, 0.30, C_FEATHER),
        (math.pi*0.75, 1.90, 0.00, C_FEATHER2),
        (math.pi*0.88, 1.65, -0.30, C_FEATHER),
        (math.pi*1.00, 1.40, -0.20, C_TAIL),
        # Obere Schweiffedern
        (math.pi*0.55, 1.10, 0.40, C_FLAME),
        (math.pi*0.70, 1.25, 0.15, C_FLAME2),
        (math.pi*0.85, 1.10, -0.40, C_FLAME),
    ]
    for i, (phi, length, tilt, col) in enumerate(tail_configs):
        r_anchor = 1.02
        base = Vector((math.cos(phi+math.pi*0.5)*r_anchor, math.sin(phi+math.pi*0.5)*r_anchor, -r_anchor*0.55))
        tip  = base + Vector((tilt, -0.05, -length))
        tf = cone_obj(f"Tail_Feather_{i}", base, tip, 0.048 + (i%3)*0.010, 0.008, 6)
        vcol(tf, col); parts.append(tf)
        # Glühen an Schweif-Spitzen
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.022, segments=5, ring_count=4, location=tip)
        tg = bpy.context.active_object; tg.name = f"Tail_Glow_{i}"; smooth(tg); vcol(tg, C_FLAME2); parts.append(tg)
    # Schweif-Basis Wulst
    bpy.ops.mesh.primitive_torus_add(major_radius=0.35, minor_radius=0.05, major_segments=20, minor_segments=7, location=(0,0,-1.10))
    tb = bpy.context.active_object; tb.name = "Tail_Base"; vcol(tb, C_EMBER); parts.append(tb)
    return parts


# ═══════════════════════════════════════════════════════════════
# EMBER-PARTIKEL
# ═══════════════════════════════════════════════════════════════
def create_embers():
    parts = []
    ember_pos = [
        (2.80, -0.60, 0.90), (-2.70, -0.40, 1.10), (1.90, -0.80, 1.60),
        (-2.00, -0.55, 1.45), (3.20, 0.20, 0.40), (-3.10, 0.15, 0.55),
        (2.40, 0.70, -0.30), (-2.50, 0.80, -0.20), (1.50, -1.10, -0.80),
        (-1.60, -0.90, -0.70), (2.10, -1.40, 0.20), (-2.20, -1.30, 0.30),
    ]
    for i, pos in enumerate(ember_pos):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.030+i%3*0.010, segments=5, ring_count=4, location=pos)
        em = bpy.context.active_object; em.name = f"Ember_{i:02d}"; smooth(em)
        vcol(em, C_FLAME2 if i%3==0 else (C_FLAME if i%3==1 else C_EMBER)); parts.append(em)
    return parts


clear_scene()
col = bpy.data.collections.new("Aion_PhoenixWings")
bpy.context.scene.collection.children.link(col)

all_parts = (create_orb()
           + create_phoenix_head()
           + create_wing("L", -1)
           + create_wing("R",  1)
           + create_tail()
           + create_embers())

for obj in all_parts:
    for c in list(obj.users_collection): c.objects.unlink(obj)
    col.objects.link(obj)
print(f"✅ Aion Phoenix Wings — {len(all_parts)} Teile")
