import bpy, bmesh, math
from mathutils import Vector

# ============================================================
# AION  —  DRAGON COIL  |  Roblox-safe FBX
# Östlicher Drache umschlingt die Drachenperle (Sphere).
# Helikaler Körper mit Rückenflossen, detailliertem Kopf
# mit Hörnern/Bartfäden/Zähnen, zwei Greifen-Klauen.
# ============================================================

C_SCALE   = (0.04, 0.10, 0.05, 1.0)  # Jadegrüne Schuppen
C_BELLY   = (0.12, 0.28, 0.09, 1.0)  # helles Bauchgrün
C_FIN     = (0.06, 0.52, 0.22, 1.0)  # leuchtende Rückenflossen
C_CLAW    = (0.72, 0.68, 0.52, 1.0)  # Elfenbein-Krallen
C_EYE_D   = (0.90, 0.65, 0.05, 1.0)  # goldenes Drachenauge
C_PUPIL   = (0.01, 0.01, 0.02, 1.0)  # Pupille schwarz
C_HORN    = (0.58, 0.28, 0.06, 1.0)  # dunkles Drachen-Horn
C_WHISKER = (0.88, 0.74, 0.36, 1.0)  # goldene Bartfäden
C_SPINE   = (0.30, 0.10, 0.03, 1.0)  # dunkler Rücken-Spine
C_GOLD    = (0.88, 0.72, 0.10, 1.0)  # Goldband
C_ORB     = (0.02, 0.03, 0.14, 1.0)  # Drachenperle Tiefblau
C_OCORE   = (0.94, 0.50, 0.06, 1.0)  # Perl-Kern Ember
C_ORING   = (0.88, 0.72, 0.10, 1.0)  # Perl-Ring Gold
C_BREATH  = (0.96, 0.84, 0.20, 1.0)  # Feueratem

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

def cyl(name, s, e, r=0.05, v=8):
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


# ── Helix-Pfad ───────────────────────────────────────────────
def helix_pts(n=58, theta_s=0.30, theta_e=2.72, coils=2.5, r=1.04):
    pts = []
    for i in range(n):
        t = i / (n-1)
        th = theta_s + (theta_e - theta_s) * t
        ph = t * coils * math.tau
        pts.append(Vector((r*math.sin(th)*math.cos(ph),
                            r*math.sin(th)*math.sin(ph),
                            r*math.cos(th))))
    return pts

def body_girth(t):
    return 0.028 + 0.046 * math.sin(math.pi * min(t / 0.65, 1.0))


# ═══════════════════════════════════════════════════════════════
# KUGEL (Drachenperle)
# ═══════════════════════════════════════════════════════════════
def create_orb():
    parts = []
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, segments=64, ring_count=32, location=(0,0,0))
    orb = bpy.context.active_object; orb.name = "Aion_Orb"; smooth(orb); vcol(orb, C_ORB); parts.append(orb)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.62, segments=32, ring_count=16, location=(0,0,0))
    c1 = bpy.context.active_object; c1.name = "Aion_Core1"; smooth(c1); vcol(c1, (0.06,0.05,0.22,1.0)); parts.append(c1)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.34, subdivisions=2, location=(0,0,0))
    c2 = bpy.context.active_object; c2.name = "Aion_Core2"; smooth(c2); vcol(c2, C_OCORE); parts.append(c2)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.15, segments=10, ring_count=6, location=(0,0,0))
    c3 = bpy.context.active_object; c3.name = "Aion_Nucleus"; smooth(c3); vcol(c3, C_BREATH); parts.append(c3)
    # 5 Gold-Ringe
    for i, (z, maj) in enumerate([(0.65,0.76),(0.33,0.94),(0.0,1.01),(-0.33,0.94),(-0.65,0.76)]):
        bpy.ops.mesh.primitive_torus_add(major_radius=maj, minor_radius=0.018, major_segments=52, minor_segments=8, location=(0,0,z))
        r = bpy.context.active_object; r.name = f"Pearl_Ring_{i}"; vcol(r, C_ORING); parts.append(r)
    # Großer schwebender Gold-Halo
    bpy.ops.mesh.primitive_torus_add(major_radius=1.44, minor_radius=0.022, major_segments=72, minor_segments=10, location=(0,0,0))
    halo = bpy.context.active_object; halo.name = "Pearl_Halo"; vcol(halo, C_GOLD); parts.append(halo)
    # 8 Ember-Perlen am Halo
    for i in range(8):
        a = (i/8)*math.tau
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.036, segments=7, ring_count=4, location=(math.cos(a)*1.44, math.sin(a)*1.44, 0))
        b = bpy.context.active_object; b.name = f"Pearl_Bead_{i}"; smooth(b); vcol(b, C_OCORE if i%2==0 else C_ORING); parts.append(b)
    return parts


# ═══════════════════════════════════════════════════════════════
# DRACHENKÖRPER (Helix)
# ═══════════════════════════════════════════════════════════════
def create_dragon_body(pts):
    parts = []
    n = len(pts)
    for i in range(n - 1):
        t = i / (n - 2)
        g = body_girth(t)
        seg = cyl(f"Dragon_Body_{i:02d}", pts[i], pts[i+1], g, 8)
        vcol(seg, C_BELLY if i%4 < 2 else C_SCALE); parts.append(seg)

        # Gelenk-Kugeln alle 5 Segmente
        if i % 5 == 0:
            bpy.ops.mesh.primitive_uv_sphere_add(radius=g*1.25, segments=7, ring_count=4, location=pts[i])
            jt = bpy.context.active_object; jt.name = f"Dragon_Joint_{i:02d}"
            smooth(jt); vcol(jt, C_SCALE); parts.append(jt)

        # Rücken-Flossen alle 3 Segmente (nicht zu nah am Kopf/Schwanz)
        if i % 3 == 1 and 0.08 < t < 0.88:
            mid = (pts[i] + pts[i+1]) * 0.5
            body_dir = (pts[i+1] - pts[i]).normalized()
            outward  = mid.normalized()
            # Flossen-Richtung: senkrecht zu Körper UND weg von der Kugel
            lat = body_dir.cross(outward)
            if lat.length < 0.001:
                lat = Vector((0, 0, 1))
            lat.normalize()
            fin_dir = outward - body_dir * outward.dot(body_dir)
            if fin_dir.length < 0.001:
                fin_dir = outward
            fin_dir.normalize()
            fin_base = mid + outward * g
            fin_h = 0.045 + g * 1.0
            fin_tip = fin_base + fin_dir * fin_h
            fin = cone(f"Dragon_Fin_{i:02d}", fin_base, fin_tip, g*0.60, 0.002, 4)
            vcol(fin, C_FIN); parts.append(fin)

        # Gold-Ringe-Band alle 9 Segmente
        if i % 9 == 4:
            mid = (pts[i] + pts[i+1]) * 0.5
            body_dir = (pts[i+1] - pts[i]).normalized()
            bpy.ops.mesh.primitive_torus_add(
                major_radius=g*1.6, minor_radius=g*0.28,
                major_segments=12, minor_segments=5,
                location=mid)
            band = bpy.context.active_object; band.name = f"Dragon_Band_{i:02d}"
            band.rotation_mode = 'QUATERNION'
            band.rotation_quaternion = body_dir.to_track_quat('Z','Y')
            bpy.ops.object.transform_apply(rotation=True)
            vcol(band, C_GOLD); parts.append(band)

    return parts


# ═══════════════════════════════════════════════════════════════
# DRACHEN-KOPF
# ═══════════════════════════════════════════════════════════════
def create_dragon_head(pts):
    parts = []
    fwd = (pts[-1] - pts[-2]).normalized()
    outward = pts[-1].normalized()
    right = fwd.cross(outward); right.normalize()
    up = right.cross(fwd); up.normalize()
    hc = pts[-1] + fwd * 0.28  # Kopfmittelpunkt

    # Schädel
    cr = cyl("Dragon_Cranium", pts[-1] + fwd*0.05, hc + fwd*0.16, 0.095, 10)
    vcol(cr, C_SCALE); parts.append(cr)
    # Schnauzenknochen
    sn = cone("Dragon_Snout", hc + fwd*0.14, hc + fwd*0.42, 0.072, 0.025, 8)
    vcol(sn, C_SCALE); parts.append(sn)
    # Unterkiefer
    jaw_s = hc + fwd*0.14 - up*0.048
    jaw_e = hc + fwd*0.44 - up*0.060
    jw = cone("Dragon_Jaw", jaw_s, jaw_e, 0.065, 0.018, 8)
    vcol(jw, C_BELLY); parts.append(jw)

    # 4 Hörner
    horn_cfg = [
        (-1, 0.082, 0.14, -0.12, 0.28),  # links gross
        ( 1, 0.082, 0.14, -0.12, 0.28),  # rechts gross
        (-1, 0.062, 0.06, -0.06, 0.16),  # links klein
        ( 1, 0.062, 0.06, -0.06, 0.16),  # rechts klein
    ]
    for hi, (side, rr, uu, ff, hl) in enumerate(horn_cfg):
        hb = hc + right*rr*side + up*uu + fwd*ff
        ht = hb + right*rr*0.6*side + up*(uu + hl) + fwd*(ff - 0.10)
        horn = cone(f"Dragon_Horn_{hi}", hb, ht, 0.020, 0.001, 5)
        vcol(horn, C_HORN); parts.append(horn)

    # 2 Augen
    for side in [-1, 1]:
        ep = hc + right*0.094*side + up*0.040 + fwd*0.08
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.036, segments=8, ring_count=6, location=ep)
        eye = bpy.context.active_object; eye.name = f"Dragon_Eye_{'L' if side<0 else 'R'}"
        smooth(eye); vcol(eye, C_EYE_D); parts.append(eye)
        pp = ep + fwd*0.032 + up*0.002
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.018, segments=6, ring_count=4, location=pp)
        pupil = bpy.context.active_object; pupil.name = f"Dragon_Pupil_{'L' if side<0 else 'R'}"
        smooth(pupil); vcol(pupil, C_PUPIL); parts.append(pupil)

    # 2 Bartfäden (je 2 Segmente)
    for side in [-1, 1]:
        ws = hc + right*0.055*side + fwd*0.32 - up*0.018
        wm = hc + right*0.17*side + fwd*0.52 - up*0.10
        we = hc + right*0.22*side + fwd*0.66 - up*0.24
        w1 = cyl(f"Dragon_Whisker_{side}a", ws, wm, 0.009, 5)
        w2 = cyl(f"Dragon_Whisker_{side}b", wm, we, 0.005, 4)
        vcol(w1, C_WHISKER); vcol(w2, C_WHISKER); parts += [w1, w2]
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.012, segments=5, ring_count=3, location=we)
        wt = bpy.context.active_object; wt.name = f"Dragon_WhiskerTip_{side}"
        smooth(wt); vcol(wt, C_GOLD); parts.append(wt)

    # 8 Zähne (4 oben, 4 unten)
    for ti in range(4):
        for jaw_off, jaw_name in [(-up*0.015, 'U'), (-up*0.062, 'L')]:
            tf = 0.20 + ti * 0.036
            tr_off = (ti - 1.5) * 0.022
            tb = hc + fwd*tf + right*tr_off + jaw_off
            tt = tb - up * 0.046
            th = cone(f"Dragon_Tooth_{ti}_{jaw_name}", tb, tt, 0.010, 0.001, 4)
            vcol(th, C_CLAW); parts.append(th)

    # Rücken-Spine-Kamm (6 Dorsal-Kegel am Kopf)
    for si in range(6):
        t = si / 5
        sp_b = hc + fwd*(-0.14 + t*0.32) + up*0.092
        sp_t = sp_b + up*(0.055 + t*0.030)
        sp = cone(f"Dragon_HeadSpine_{si}", sp_b, sp_t, 0.013, 0.001, 5)
        vcol(sp, C_SPINE); parts.append(sp)

    # Feuer-Atem-Strahl (3 divergierende Energie-Kegel nach vorne)
    for bi in range(3):
        a = (bi - 1) * 0.30
        ba_s = hc + fwd*0.42 + right * math.sin(a)*0.05 - up*0.01
        ba_e = hc + fwd*0.82 + right * math.sin(a)*0.18 - up*0.02
        br = cone(f"Dragon_Breath_{bi}", ba_s, ba_e, 0.028, 0.001, 5)
        vcol(br, C_BREATH if bi==1 else C_OCORE); parts.append(br)

    return parts


# ═══════════════════════════════════════════════════════════════
# KLAUEN
# ═══════════════════════════════════════════════════════════════
def create_claw(prefix, anchor_pt, next_pt):
    parts = []
    # Arm-Richtung: senkrecht zur Körper-Richtung, nach innen zeigend
    body_dir = (next_pt - anchor_pt).normalized()
    outward  = anchor_pt.normalized()
    arm_dir  = outward.cross(body_dir); arm_dir.normalize()
    # Unterarm geht ~0.30 in arm_dir, dann Pfote
    elbow = anchor_pt + arm_dir * 0.30
    wrist = anchor_pt + arm_dir * 0.52 - Vector((0,0,0.08))
    pa = cyl(f"{prefix}_UpperArm", anchor_pt, elbow, 0.052, 8)
    pb = cyl(f"{prefix}_ForeArm",  elbow,  wrist, 0.038, 7)
    vcol(pa, C_SCALE); vcol(pb, C_SCALE); parts += [pa, pb]
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.042, segments=7, ring_count=4, location=wrist)
    jt = bpy.context.active_object; jt.name = f"{prefix}_WristJoint"
    smooth(jt); vcol(jt, C_SCALE); parts.append(jt)
    # 4 Zehen mit je 2 Segmenten + Klaue
    for ti in range(4):
        spread = (ti - 1.5) * 0.14
        # Zehenrichtung: nach unten-vorne, leicht gespreizt
        down = Vector((0, 0, -1))
        toe_fwd = (arm_dir*0.6 + down*0.4 + body_dir*spread).normalized()
        t_s = wrist
        t_m = t_s + toe_fwd * 0.12
        t_e = t_m + toe_fwd * 0.10
        c_e = t_e + toe_fwd * 0.08
        pa_t = cyl(f"{prefix}_Toe{ti}a", t_s, t_m, 0.022, 6)
        pb_t = cyl(f"{prefix}_Toe{ti}b", t_m, t_e, 0.016, 6)
        pc_t = cone(f"{prefix}_Claw{ti}", t_e, c_e, 0.016, 0.001, 5)
        vcol(pa_t, C_SCALE); vcol(pb_t, C_BELLY); vcol(pc_t, C_CLAW)
        parts += [pa_t, pb_t, pc_t]
    # Gold-Armband
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.055, minor_radius=0.008,
        major_segments=12, minor_segments=5, location=elbow)
    gb = bpy.context.active_object; gb.name = f"{prefix}_GoldBand"
    vcol(gb, C_GOLD); parts.append(gb)
    return parts


# ═══════════════════════════════════════════════════════════════
# DRACHENSCHWANZ-SPITZE
# ═══════════════════════════════════════════════════════════════
def create_tail_tip(pts):
    parts = []
    tail_end = pts[0]
    tail_dir = (pts[0] - pts[2]).normalized()
    # Schwanz-Spike-Fächer (5 Kegel)
    outward = tail_end.normalized()
    right_t = tail_dir.cross(outward); right_t.normalize()
    for ti in range(5):
        angle = (ti - 2) * 0.28
        spike_dir = (tail_dir * 0.6 + right_t * math.sin(angle) * 0.5 + outward * math.cos(angle) * 0.2).normalized()
        t_base = tail_end
        t_tip  = tail_end + spike_dir * (0.14 + abs(ti-2)*0.04)
        sp = cone(f"Dragon_TailSpike_{ti}", t_base, t_tip, 0.020, 0.001, 5)
        vcol(sp, C_FIN if ti==2 else C_SPINE); parts.append(sp)
    # Schwanzspitze-Kugel
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.030, segments=6, ring_count=4, location=tail_end)
    tt = bpy.context.active_object; tt.name = "Dragon_TailBall"
    smooth(tt); vcol(tt, C_GOLD); parts.append(tt)
    return parts


# ═══════════════════════════════════════════════════════════════
# HAUPT
# ═══════════════════════════════════════════════════════════════
clear_scene()
col = bpy.data.collections.new("Aion_DragonCoil")
bpy.context.scene.collection.children.link(col)

pts = helix_pts()

all_parts = (create_orb()
    + create_dragon_body(pts)
    + create_dragon_head(pts)
    + create_claw("ClawL", pts[20], pts[21])
    + create_claw("ClawR", pts[32], pts[33])
    + create_tail_tip(pts))

for obj in all_parts:
    for c in list(obj.users_collection): c.objects.unlink(obj)
    col.objects.link(obj)
print(f"✅ Aion Dragon Coil — {len(all_parts)} Teile")
