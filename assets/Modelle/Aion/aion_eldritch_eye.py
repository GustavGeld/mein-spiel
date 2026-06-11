import bpy, bmesh, math
from mathutils import Vector

# ============================================================
# AION  —  ELDRITCH EYE  |  Roblox-safe FBX
# Die Kugel IST ein riesiges kosmisches Auge. Konzentrische
# Iris-Ringe, fleischige Lider (bmesh), 16 Tentakel-Wimpern
# mit Gelenkknoten, Blutgefäß-Ranken, 5 schwebende Neben-Augen.
# ============================================================

C_PUPIL   = (0.01, 0.01, 0.02, 1.0)  # Pupille Schwarz
C_IRIS1   = (0.95, 0.65, 0.04, 1.0)  # Gold-Iris innen
C_IRIS2   = (0.72, 0.38, 0.04, 1.0)  # Amber-Iris Mitte
C_IRIS3   = (0.48, 0.18, 0.02, 1.0)  # Dunkel-Iris außen
C_SCLERA  = (0.45, 0.12, 0.10, 1.0)  # blutiges Weißes (alien)
C_VEIN    = (0.55, 0.04, 0.04, 1.0)  # Blut-Adern rot
C_LID     = (0.28, 0.08, 0.06, 1.0)  # Augenlid fleischig dunkel
C_LASH    = (0.04, 0.03, 0.06, 1.0)  # Wimpern schwarz-lila
C_SUCKER  = (0.62, 0.10, 0.08, 1.0)  # Saugnapf rot
C_BONE    = (0.70, 0.62, 0.48, 1.0)  # Außen-Knorpel
C_SEC_EYE = (0.10, 0.55, 0.80, 1.0)  # Neben-Augen blaues Iris
C_TENDR   = (0.10, 0.04, 0.18, 1.0)  # dunkle Tendril-Lila

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for col in list(bpy.data.collections):
        bpy.data.collections.remove(col)

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

def cyl(name, s, e, r=0.04, v=8):
    sv, ev = Vector(s), Vector(e)
    vec = ev - sv
    bpy.ops.mesh.primitive_cylinder_add(
        radius=r, depth=vec.length, vertices=v, location=(sv+ev)*0.5)
    obj = bpy.context.active_object; obj.name = name
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = vec.to_track_quat('Z','Y')
    smooth(obj); return obj

def cone(name, s, e, r1=0.05, r2=0.0, v=6):
    sv, ev = Vector(s), Vector(e)
    vec = ev - sv
    bpy.ops.mesh.primitive_cone_add(
        radius1=r1, radius2=r2, depth=vec.length, vertices=v,
        location=(sv+ev)*0.5)
    obj = bpy.context.active_object; obj.name = name
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = vec.to_track_quat('Z','Y')
    smooth(obj); return obj

def make_membrane(name, verts_list, color):
    """Erstellt ein flaches Polygon aus einer Vertexliste."""
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bm = bmesh.new()
    bvs = [bm.verts.new(v) for v in verts_list]
    bm.faces.new(bvs)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh); bm.free()
    vcol(obj, color)
    return obj


# ═══════════════════════════════════════════════════════════════
# HAUPTKUGEL = PUPILLE + IRIS-RINGE
# ═══════════════════════════════════════════════════════════════
def create_eye_orb():
    parts = []
    # Pupille: schwarze Kugel
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, segments=64, ring_count=32, location=(0,0,0))
    orb = bpy.context.active_object; orb.name = "Eye_Pupil"; smooth(orb); vcol(orb, C_PUPIL); parts.append(orb)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.55, segments=32, ring_count=16, location=(0,0,0))
    c1 = bpy.context.active_object; c1.name = "Eye_Core1"; smooth(c1); vcol(c1, (0.04,0.01,0.10,1.0)); parts.append(c1)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.24, subdivisions=2, location=(0,0,0))
    c2 = bpy.context.active_object; c2.name = "Eye_Core2"; smooth(c2); vcol(c2, C_IRIS1); parts.append(c2)
    # 10 konzentrische Iris-Ringe (von innen nach außen, Farbe variiert)
    iris_cfg = [
        (0.22, 0.018, C_IRIS1), (0.36, 0.022, C_IRIS1),
        (0.50, 0.026, C_IRIS2), (0.62, 0.026, C_IRIS2),
        (0.73, 0.025, C_IRIS2), (0.83, 0.024, C_IRIS3),
        (0.91, 0.022, C_IRIS3), (0.97, 0.020, C_IRIS3),
        (1.005,0.016, C_SCLERA),(1.01, 0.012, C_VEIN),
    ]
    for i, (maj, mn, col) in enumerate(iris_cfg):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=maj, minor_radius=mn,
            major_segments=60, minor_segments=8, location=(0,0,0))
        ring = bpy.context.active_object; ring.name = f"Eye_IrisRing_{i}"
        vcol(ring, col); parts.append(ring)
    # Weiße (blutrot-alien) Sklera: flacher Torus-Band außen
    bpy.ops.mesh.primitive_torus_add(
        major_radius=1.22, minor_radius=0.22,
        major_segments=72, minor_segments=16, location=(0,0,0))
    sclera = bpy.context.active_object; sclera.name = "Eye_Sclera"
    smooth(sclera); vcol(sclera, C_SCLERA); parts.append(sclera)
    # Knorpel-Rahmen (äußerer Ring)
    bpy.ops.mesh.primitive_torus_add(
        major_radius=1.46, minor_radius=0.048,
        major_segments=64, minor_segments=12, location=(0,0,0))
    frame = bpy.context.active_object; frame.name = "Eye_Frame"
    smooth(frame); vcol(frame, C_BONE); parts.append(frame)
    # 12 Knorpel-Noppen am Rahmen
    for i in range(12):
        a = (i/12)*math.tau
        bpy.ops.mesh.primitive_ico_sphere_add(radius=0.042, subdivisions=1, location=(math.cos(a)*1.46, math.sin(a)*1.46, 0))
        n = bpy.context.active_object; n.name = f"Eye_FrameNub_{i}"; vcol(n, C_BONE); parts.append(n)
    return parts


# ═══════════════════════════════════════════════════════════════
# AUGENLIDER (bmesh Membrane)
# ═══════════════════════════════════════════════════════════════
def create_eyelids():
    parts = []
    # Oberlid: großer Bogen über dem Auge, etwas angehoben
    upper_verts = []
    n = 20
    for i in range(n):
        a = math.pi + (i / (n-1)) * math.pi  # pi → 2pi = untere Halbkreis
        # Oberlid liegt im Ring von r=1.42 bis r=1.65, Z positiv
        r_out = 1.50 + 0.08 * math.sin(i / (n-1) * math.pi)
        z     = 0.18 + 0.12 * math.sin(i / (n-1) * math.pi)
        upper_verts.append(Vector((r_out * math.cos(a), r_out * math.sin(a), z)))
    # Innenkante schließen (über Sklera)
    for i in range(n-1, -1, -1):
        a = math.pi + (i / (n-1)) * math.pi
        upper_verts.append(Vector((1.42 * math.cos(a), 1.42 * math.sin(a), 0.06)))
    ul = make_membrane("Eye_UpperLid", upper_verts, C_LID)
    parts.append(ul)

    # Unterlid: gespiegelt, leicht heruntergezogen
    lower_verts = []
    for i in range(n):
        a = math.pi + (i / (n-1)) * math.pi
        r_out = 1.50 + 0.06 * math.sin(i / (n-1) * math.pi)
        z     = -0.14 - 0.08 * math.sin(i / (n-1) * math.pi)
        lower_verts.append(Vector((r_out * math.cos(a), r_out * math.sin(a), z)))
    for i in range(n-1, -1, -1):
        a = math.pi + (i / (n-1)) * math.pi
        lower_verts.append(Vector((1.42 * math.cos(a), 1.42 * math.sin(a), -0.04)))
    ll = make_membrane("Eye_LowerLid", lower_verts, C_LID)
    parts.append(ll)

    # Lid-Rand-Verdickung (2 Torii als Lid-Kanten)
    bpy.ops.mesh.primitive_torus_add(
        major_radius=1.48, minor_radius=0.030,
        major_segments=60, minor_segments=8,
        location=(0,0,0.14), rotation=(math.pi/8, 0, 0))
    uledge = bpy.context.active_object; uledge.name = "Eye_UpperLidEdge"
    bpy.ops.object.transform_apply(rotation=True)
    vcol(uledge, C_LID); parts.append(uledge)

    bpy.ops.mesh.primitive_torus_add(
        major_radius=1.48, minor_radius=0.026,
        major_segments=60, minor_segments=8,
        location=(0,0,-0.12), rotation=(-math.pi/9, 0, 0))
    lledge = bpy.context.active_object; lledge.name = "Eye_LowerLidEdge"
    bpy.ops.object.transform_apply(rotation=True)
    vcol(lledge, C_LID); parts.append(lledge)
    return parts


# ═══════════════════════════════════════════════════════════════
# BLUTGEFÄSS-RANKEN
# ═══════════════════════════════════════════════════════════════
def create_veins():
    parts = []
    vein_roots = [
        (1.02, 0.40, 0),  (1.02, 1.20, 0.25), (1.02, 2.20, -0.20),
        (1.02, 3.00, 0),  (1.02, 4.00, 0.30), (1.02, 5.00, -0.15),
        (1.02, 5.80, 0.10),(1.02, 1.80, -0.35),(1.02, 2.80, 0.20),
    ]
    for vi, (r, a, z_off) in enumerate(vein_roots):
        x0 = math.cos(a)*r; y0 = math.sin(a)*r
        prev = Vector((x0, y0, z_off))
        for seg in range(5):
            t = (seg+1)/5
            spread = 1.20 + t*0.30
            x1 = math.cos(a + t*0.28)*spread + (seg%2)*0.04
            y1 = math.sin(a + t*0.28)*spread
            z1 = z_off + t*0.08 * (1 if vi%2==0 else -1)
            nxt = Vector((x1, y1, z1))
            v = cyl(f"Vein_{vi}_{seg}", prev, nxt, 0.014 - seg*0.002, 5)
            vcol(v, C_VEIN); parts.append(v)
            prev = nxt
        # Ast-Verzweigung am Ende
        fork_dir = (prev - Vector((0,0,0))).normalized()
        perp = Vector((-fork_dir.y, fork_dir.x, 0)).normalized()
        for fk in [-1, 1]:
            fe = prev + (fork_dir + perp*fk*0.4).normalized() * 0.14
            fv = cyl(f"Vein_{vi}_fork{fk}", prev, fe, 0.008, 4)
            vcol(fv, C_VEIN); parts.append(fv)
    return parts


# ═══════════════════════════════════════════════════════════════
# TENTAKEL-WIMPERN
# ═══════════════════════════════════════════════════════════════
def create_lashes():
    parts = []
    lash_cfg = [
        # (winkel, z_offset, laenge, krümmung_faktor, curved_dir)
        (0.25,  0.10, 0.80, 0.35, 1),
        (0.65,  0.18, 0.95, 0.30,-1),
        (1.05,  0.22, 1.05, 0.25, 1),
        (1.55,  0.20, 0.90, 0.28,-1),
        (1.95,  0.15, 0.75, 0.32, 1),
        (2.40,  0.08, 0.85, 0.30,-1),
        (2.85,  0.12, 0.92, 0.26, 1),
        (3.30,  0.14, 0.70, 0.34,-1),
        (3.75, -0.10, 0.80, 0.35, 1),
        (4.20, -0.18, 0.95, 0.28,-1),
        (4.65, -0.22, 1.00, 0.30, 1),
        (5.10, -0.20, 0.85, 0.32,-1),
        (5.50, -0.15, 0.75, 0.26, 1),
        (5.90, -0.08, 0.88, 0.30,-1),
        (0.90,  0.02, 0.82, 0.28, 1),
        (4.42, -0.02, 0.80, 0.30,-1),
    ]
    for li, (angle, z_off, length, curve, cdir) in enumerate(lash_cfg):
        # Wimpern-Basis auf dem Lid-Rand
        r_base = 1.50
        bx = math.cos(angle)*r_base; by = math.sin(angle)*r_base
        base = Vector((bx, by, z_off))
        # Auswärts-Richtung vom Augenzentrum
        outward = Vector((bx, by, 0)).normalized()
        up = Vector((0, 0, 1 if z_off > 0 else -1))
        # 4 Tentakel-Segmente mit abnehmender Dicke und Krümmung
        prev = base
        seg_len = length / 4
        for si in range(4):
            t = (si+1)/4
            # Krümmung: Wimpern biegen sich nach außen-oben
            seg_dir = (outward * (1.0 - t*curve) + up * (t*curve*cdir)).normalized()
            nxt = prev + seg_dir * seg_len
            seg_r = 0.022 - si*0.004
            ls = cyl(f"Lash_{li}_S{si}", prev, nxt, max(0.005, seg_r), 6)
            vcol(ls, C_LASH); parts.append(ls)
            # Gelenk-Knoten
            bpy.ops.mesh.primitive_uv_sphere_add(
                radius=max(0.008, seg_r*1.3), segments=6, ring_count=4, location=nxt)
            jnt = bpy.context.active_object; jnt.name = f"Lash_{li}_J{si}"
            smooth(jnt); vcol(jnt, C_SUCKER if si%2==1 else C_LASH); parts.append(jnt)
            prev = nxt
        # Wimpern-Spitze: kleiner Ball
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.016, segments=5, ring_count=3, location=prev)
        tip = bpy.context.active_object; tip.name = f"Lash_{li}_Tip"
        smooth(tip); vcol(tip, C_SUCKER); parts.append(tip)
    return parts


# ═══════════════════════════════════════════════════════════════
# NEBEN-AUGEN (5 kleine schwebende Augen)
# ═══════════════════════════════════════════════════════════════
def create_secondary_eyes():
    parts = []
    sec_cfg = [
        (( 1.80,-0.10, 0.62), 0.16),
        ((-1.75, 0.08, 0.55), 0.14),
        (( 0.60,-0.12,-0.95), 0.18),
        ((-0.68, 0.14, 0.90), 0.13),
        (( 1.20,-0.06,-0.55), 0.15),
    ]
    for i, (pos, rad) in enumerate(sec_cfg):
        vp = Vector(pos)
        # Sklera der Neben-Augen
        bpy.ops.mesh.primitive_uv_sphere_add(radius=rad, segments=12, ring_count=8, location=pos)
        se = bpy.context.active_object; se.name = f"SecEye_Sclera_{i}"
        smooth(se); vcol(se, C_SCLERA); parts.append(se)
        # Iris-Ring
        bpy.ops.mesh.primitive_torus_add(
            major_radius=rad*0.65, minor_radius=rad*0.12,
            major_segments=20, minor_segments=6, location=pos)
        ir = bpy.context.active_object; ir.name = f"SecEye_Iris_{i}"
        vcol(ir, C_SEC_EYE); parts.append(ir)
        # Pupille
        forward = -vp.normalized()  # zeigt zur Hauptkugel hin
        p_pos = vp + forward * rad * 0.85
        bpy.ops.mesh.primitive_uv_sphere_add(radius=rad*0.30, segments=8, ring_count=5, location=p_pos)
        pu = bpy.context.active_object; pu.name = f"SecEye_Pupil_{i}"
        smooth(pu); vcol(pu, C_PUPIL); parts.append(pu)
        # 4 Mini-Tentakel
        for ti in range(4):
            a = (ti/4)*math.tau
            perp = Vector((math.cos(a)*rad, math.sin(a)*rad, 0))
            ts = vp + perp
            te = vp + perp * 1.6
            t = cyl(f"SecEye_Tendril_{i}_{ti}", ts, te, 0.010, 5)
            vcol(t, C_TENDR); parts.append(t)
    return parts


clear_scene()
col = bpy.data.collections.new("Aion_EldritchEye")
bpy.context.scene.collection.children.link(col)

all_parts = (create_eye_orb()
    + create_eyelids()
    + create_veins()
    + create_lashes()
    + create_secondary_eyes())

for obj in all_parts:
    for c in list(obj.users_collection): c.objects.unlink(obj)
    col.objects.link(obj)
print(f"✅ Aion Eldritch Eye — {len(all_parts)} Teile")
