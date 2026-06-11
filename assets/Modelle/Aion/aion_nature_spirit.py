import bpy, bmesh, math
from mathutils import Vector

# ============================================================
# AION  —  NATURE SPIRIT  |  Roblox-safe FBX
# Kugelförmiger Begleiter: Tiefer Waldgeist —
# dunkelgrüne Kugel mit spiralisierenden Ranken,
# organischen Blättern, Blumenkrone und Glühwürmchen.
# ============================================================

C_DARK_G = (0.04, 0.12, 0.03, 1.0)   # Tief-Waldgrün (Kugel)
C_MID_G  = (0.08, 0.22, 0.06, 1.0)   # mittleres Grün
C_LEAF   = (0.14, 0.38, 0.08, 1.0)   # frisches Blattgrün
C_BRIGHT_G=(0.30, 0.65, 0.12, 1.0)   # helles Blattgrün
C_BARK   = (0.22, 0.12, 0.04, 1.0)   # Rinden-Braun
C_VINE   = (0.18, 0.22, 0.05, 1.0)   # Ranken-Olivgrün
C_GOLD_N = (0.78, 0.65, 0.08, 1.0)   # Gold-Pollen
C_PETAL  = (0.90, 0.58, 0.68, 1.0)   # Blütenblatt Rosa
C_PETAL2 = (1.00, 0.85, 0.35, 1.0)   # Blütenblatt Gelb
C_GLOW_N = (0.62, 1.00, 0.28, 1.0)   # Glühwürmchen-Grün
C_MUSH   = (0.72, 0.24, 0.12, 1.0)   # Pilz-Rot
C_MUSH2  = (0.96, 0.90, 0.82, 1.0)   # Pilz-Weiß

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
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = vec.to_track_quat('Z','Y')
    smooth(obj)
    return obj

def cone(name, s, e, r1=0.05, r2=0.0, v=8):
    sv, ev = Vector(s), Vector(e)
    vec = ev - sv
    bpy.ops.mesh.primitive_cone_add(
        radius1=r1, radius2=r2, depth=vec.length, vertices=v,
        location=(sv+ev)*0.5)
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = vec.to_track_quat('Z','Y')
    smooth(obj)
    return obj

def membrane(name, verts, thick=0.018):
    mesh = bpy.data.meshes.new(name)
    obj  = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bm = bmesh.new()
    top = [bm.verts.new((v[0], v[1]+thick, v[2])) for v in verts]
    bot = [bm.verts.new((v[0], v[1]-thick, v[2])) for v in verts]
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    n = len(top)
    for i in range(n):
        j = (i+1)%n
        bm.faces.new([top[i], top[j], bot[j], bot[i]])
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    smooth(obj)
    return obj

def sph_pt(theta, phi, r=1.0):
    return (r*math.sin(theta)*math.cos(phi),
            r*math.sin(theta)*math.sin(phi),
            r*math.cos(theta))


# ── Organisches Blatt ─────────────────────────────────────────
def make_leaf(name, theta, phi, length, width, lean=0.0, color=None):
    """Blatt-Polygon an Kugelposition, zeigt nach außen."""
    r = 1.03
    base = sph_pt(theta, phi, r)
    tip  = sph_pt(theta + lean, phi, r + length)

    # Blattform: breite Mitte, spitze Enden
    mid_x = (base[0] + tip[0])*0.5
    mid_y = (base[1] + tip[1])*0.5
    mid_z = (base[2] + tip[2])*0.5
    # Richtung Basis→Spitze
    dx = tip[0]-base[0]; dy = tip[1]-base[1]; dz = tip[2]-base[2]
    ln = math.sqrt(dx**2+dy**2+dz**2)
    if ln < 0.001: ln = 0.001
    dx/=ln; dy/=ln; dz/=ln
    # Senkrechte (beliebige)
    if abs(dx) < 0.9:
        px, py, pz = 0, dz, -dy
    else:
        px, py, pz = -dz, 0, dx
    pln = math.sqrt(px**2+py**2+pz**2)
    if pln > 0: px/=pln; py/=pln; pz/=pln
    hw = width*0.5
    verts = [
        (base[0], base[1], base[2]),
        (mid_x+px*hw*1.1, mid_y+py*hw*1.1, mid_z+pz*hw*1.1),
        (tip[0]+px*hw*0.1, tip[1]+py*hw*0.1, tip[2]+pz*hw*0.1),
        tip,
        (tip[0]-px*hw*0.1, tip[1]-py*hw*0.1, tip[2]-pz*hw*0.1),
        (mid_x-px*hw*1.1, mid_y-py*hw*1.1, mid_z-pz*hw*1.1),
    ]
    mem = membrane(name, verts, 0.016)
    vcol(mem, color if color else C_LEAF)
    return mem


# ═══════════════════════════════════════════════════════════════
# HAUPTKUGEL
# ═══════════════════════════════════════════════════════════════
def create_orb():
    parts = []

    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=1.0, segments=64, ring_count=32, location=(0,0,0))
    orb = bpy.context.active_object; orb.name = "Aion_Orb"
    smooth(orb); vcol(orb, C_DARK_G); parts.append(orb)

    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=0.65, segments=32, ring_count=16, location=(0,0,0))
    c1 = bpy.context.active_object; c1.name = "Aion_Orb_Core"
    smooth(c1); vcol(c1, C_MID_G); parts.append(c1)

    bpy.ops.mesh.primitive_ico_sphere_add(
        radius=0.35, subdivisions=2, location=(0,0,0))
    c2 = bpy.context.active_object; c2.name = "Aion_Orb_IcoCore"
    smooth(c2); vcol(c2, C_LEAF); parts.append(c2)

    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=0.14, segments=10, ring_count=6, location=(0,0,0))
    c3 = bpy.context.active_object; c3.name = "Aion_Orb_Nucleus"
    smooth(c3); vcol(c3, C_GOLD_N); parts.append(c3)

    # Organische Rinden-Ringe (Torus, leicht unregelmäßig durch z-Offset)
    for i, (z, maj, mn, col) in enumerate([
        ( 0.68, 0.73, 0.020, C_BARK),
        ( 0.00, 1.01, 0.028, C_VINE),    # Äquator (Hauptring)
        (-0.68, 0.73, 0.020, C_BARK),
    ]):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=maj, minor_radius=mn,
            major_segments=48, minor_segments=10, location=(0,0,z))
        ring = bpy.context.active_object; ring.name = f"Aion_Ring_{i}"
        vcol(ring, col); parts.append(ring)

    # 4 Vertikale Rinden-Bögen
    for i in range(4):
        rz = (i/4)*math.pi
        bpy.ops.mesh.primitive_torus_add(
            major_radius=1.10, minor_radius=0.014,
            major_segments=48, minor_segments=8,
            location=(0,0,0), rotation=(math.pi/2, 0, rz))
        arc = bpy.context.active_object; arc.name = f"Aion_BarkArc_{i}"
        bpy.ops.object.transform_apply(rotation=True)
        vcol(arc, C_BARK); parts.append(arc)

    # Großer Blüten-Ring
    bpy.ops.mesh.primitive_torus_add(
        major_radius=1.42, minor_radius=0.022,
        major_segments=72, minor_segments=10, location=(0,0,0))
    halo = bpy.context.active_object; halo.name = "Aion_Halo"
    vcol(halo, C_VINE); parts.append(halo)

    # 12 Blüten-Knospen auf dem Ring
    for i in range(12):
        a = (i/12)*math.tau
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.040, segments=8, ring_count=5,
            location=(math.cos(a)*1.42, math.sin(a)*1.42, 0))
        bud = bpy.context.active_object; bud.name = f"Aion_RingBud_{i}"
        smooth(bud)
        vcol(bud, C_PETAL if i%3==0 else C_BRIGHT_G if i%3==1 else C_GOLD_N)
        parts.append(bud)

    return parts


# ═══════════════════════════════════════════════════════════════
# SPIRALRANKEN (3 Stück, je ~18 Segmente)
# ═══════════════════════════════════════════════════════════════
def create_vines():
    parts = []

    for vine_i in range(3):
        phi_offset = vine_i * (math.tau / 3)
        n = 18
        for seg_i in range(n-1):
            t0 = seg_i    / (n-1)
            t1 = (seg_i+1)/ (n-1)
            # Parametrische Spirale auf Kugeloberfläche
            for t, label in [(t0,''), (t1,'_')]:
                theta = math.pi*0.12 + t*math.pi*0.76
                phi   = phi_offset + t*math.pi*2.8
                pass
            theta0 = math.pi*0.12 + t0*math.pi*0.76
            phi0   = phi_offset + t0*math.pi*2.8
            theta1 = math.pi*0.12 + t1*math.pi*0.76
            phi1   = phi_offset + t1*math.pi*2.8

            # Radius leicht über Kugeloberfläche
            r_vine = 1.03 + math.sin(t0*math.pi)*0.04

            p0 = sph_pt(theta0, phi0, r_vine)
            p1 = sph_pt(theta1, phi1, r_vine + (t1-t0)*0.06)

            vine_r = 0.030 - seg_i*0.001  # wird dünner
            seg = cyl(f"Aion_Vine_{vine_i}_{seg_i}", p0, p1,
                      max(vine_r, 0.014), 6)
            vcol(seg, C_VINE if seg_i%2==0 else C_BARK)
            parts.append(seg)

            # Knospen/Blätter an bestimmten Segmenten
            if seg_i % 3 == 1:
                bpy.ops.mesh.primitive_uv_sphere_add(
                    radius=0.038, segments=7, ring_count=4, location=p0)
                bud = bpy.context.active_object
                bud.name = f"Aion_VineBud_{vine_i}_{seg_i}"
                smooth(bud)
                vcol(bud, C_PETAL if (vine_i+seg_i)%2==0 else C_BRIGHT_G)
                parts.append(bud)

    return parts


# ═══════════════════════════════════════════════════════════════
# BLÄTTER (8 organische Blatt-Polygone)
# ═══════════════════════════════════════════════════════════════
def create_leaves():
    parts = []
    leaf_cfg = [
        (math.pi/2,  0.20, 0.55, 0.26,  0.10, C_LEAF),
        (math.pi/2,  1.80, 0.50, 0.22,  0.12, C_BRIGHT_G),
        (math.pi/2,  3.40, 0.52, 0.24,  0.08, C_LEAF),
        (math.pi/2,  5.00, 0.48, 0.22,  0.10, C_BRIGHT_G),
        (math.pi/3,  0.80, 0.44, 0.20,  0.14, C_LEAF),
        (math.pi/3,  2.60, 0.46, 0.21,  0.12, C_BRIGHT_G),
        (2*math.pi/3,1.20, 0.44, 0.20, -0.12, C_LEAF),
        (2*math.pi/3,4.00, 0.42, 0.19, -0.10, C_BRIGHT_G),
    ]
    for i, (th, ph, ln, wd, lean, col) in enumerate(leaf_cfg):
        lf = make_leaf(f"Aion_Leaf_{i}", th, ph, ln, wd, lean, col)
        parts.append(lf)
        # Mittelader des Blattes
        r0 = sph_pt(th, ph, 1.04)
        r1 = sph_pt(th+lean, ph, 1.04+ln*0.85)
        vein = cyl(f"Aion_LeafVein_{i}", r0, r1, 0.009, 6)
        vcol(vein, C_BARK); parts.append(vein)

    return parts


# ═══════════════════════════════════════════════════════════════
# BLUMENKRONE (Nordpol)
# ═══════════════════════════════════════════════════════════════
def create_flower_crown():
    parts = []

    # Grüner Kelch
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.22, depth=0.08, vertices=12, location=(0,0,0.94))
    calyx = bpy.context.active_object; calyx.name = "Aion_Calyx"
    smooth(calyx); vcol(calyx, C_VINE); parts.append(calyx)

    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.20, minor_radius=0.020,
        major_segments=20, minor_segments=7, location=(0,0,0.98))
    cr = bpy.context.active_object; cr.name = "Aion_Calyx_Ring"
    vcol(cr, C_BARK); parts.append(cr)

    # 6 Blütenblätter (Rosa) um den Kelch
    for i in range(6):
        a = (i/6)*math.tau
        # Jedes Blütenblatt: flache Membran-Form
        bx, by = math.cos(a)*0.18, math.sin(a)*0.18
        tip_x, tip_y = math.cos(a)*0.48, math.sin(a)*0.48
        perp_x, perp_y = -math.sin(a)*0.12, math.cos(a)*0.12
        petal_verts = [
            (bx-perp_x, by-perp_y, 1.00),
            (tip_x-perp_x*0.5, tip_y-perp_y*0.5, 1.04),
            (tip_x, tip_y, 1.06),
            (tip_x+perp_x*0.5, tip_y+perp_y*0.5, 1.04),
            (bx+perp_x, by+perp_y, 1.00),
        ]
        pet = membrane(f"Aion_Petal_{i}", petal_verts, 0.014)
        vcol(pet, C_PETAL if i%2==0 else C_PETAL2); parts.append(pet)

    # 8 kleinere Innen-Blütenblätter
    for i in range(8):
        a = (i/8)*math.tau + math.pi/8
        bx, by = math.cos(a)*0.10, math.sin(a)*0.10
        tx, ty = math.cos(a)*0.26, math.sin(a)*0.26
        px, py = -math.sin(a)*0.07, math.cos(a)*0.07
        inner_v = [
            (bx-px, by-py, 1.02),
            (tx-px*0.5, ty-py*0.5, 1.05),
            (tx, ty, 1.07),
            (tx+px*0.5, ty+py*0.5, 1.05),
            (bx+px, by+py, 1.02),
        ]
        ip = membrane(f"Aion_InnerPetal_{i}", inner_v, 0.012)
        vcol(ip, C_PETAL2 if i%2==0 else C_GOLD_N); parts.append(ip)

    # Goldenes Pollenzentrum
    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=0.090, segments=12, ring_count=8, location=(0,0,1.07))
    center = bpy.context.active_object; center.name = "Aion_FlowerCenter"
    smooth(center); vcol(center, C_GOLD_N); parts.append(center)

    # Pollen-Staubfäden (6 kleine Stiele mit Kugeln)
    for i in range(6):
        a = (i/6)*math.tau
        sx, sy = math.cos(a)*0.06, math.sin(a)*0.06
        ex, ey = math.cos(a)*0.10, math.sin(a)*0.10
        stamen = cyl(f"Aion_Stamen_{i}", (sx,sy,1.08), (ex,ey,1.14), 0.008, 6)
        vcol(stamen, C_GOLD_N); parts.append(stamen)
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.016, segments=5, ring_count=4, location=(ex,ey,1.15))
        pollen = bpy.context.active_object; pollen.name = f"Aion_Pollen_{i}"
        smooth(pollen); vcol(pollen, C_GOLD_N); parts.append(pollen)

    return parts


# ═══════════════════════════════════════════════════════════════
# PILZE (Südpol)
# ═══════════════════════════════════════════════════════════════
def create_mushrooms():
    parts = []

    mushroom_cfg = [
        (0.00,  0.0, -1.08, 0.12, 0.08, 0.20, 0.24),  # groß, mitte
        (0.18,  1.8, -1.02, 0.08, 0.06, 0.14, 0.18),
        (-0.16, 3.5, -1.02, 0.07, 0.05, 0.12, 0.16),
        (0.10, -1.2, -1.04, 0.06, 0.04, 0.10, 0.14),
        (-0.08, 5.0, -1.03, 0.05, 0.04, 0.09, 0.12),
    ]
    for i, (px, py_a, pz, stem_r, stem_h, cap_r, cap_dep) in enumerate(mushroom_cfg):
        py = math.sin(py_a)*0.08  # leichte Y-Versetzung
        # Stiel
        stem = cyl(f"Aion_Mush_{i}_Stem",
                   (px, py, pz), (px, py, pz+stem_h+stem_h),
                   stem_r, 8)
        vcol(stem, C_MUSH2); parts.append(stem)
        # Hut (abgeflachte Kugel via Kegel)
        bpy.ops.mesh.primitive_cone_add(
            vertices=14, radius1=cap_r, radius2=cap_r*0.25, depth=cap_dep,
            location=(px, py, pz+stem_h*2.2+cap_dep*0.5))
        cap = bpy.context.active_object; cap.name = f"Aion_Mush_{i}_Cap"
        smooth(cap); vcol(cap, C_MUSH); parts.append(cap)
        # Weiße Punkte auf dem Hut
        for j in range(3 if i==0 else 2):
            da = (j/(3 if i==0 else 2))*math.tau
            dot_x = px + math.cos(da)*cap_r*0.5
            dot_y = py + math.sin(da)*cap_r*0.5
            bpy.ops.mesh.primitive_uv_sphere_add(
                radius=cap_r*0.14, segments=5, ring_count=4,
                location=(dot_x, dot_y, pz+stem_h*2.2+cap_dep))
            dot = bpy.context.active_object; dot.name = f"Aion_Mush_{i}_Dot_{j}"
            smooth(dot); vcol(dot, C_MUSH2); parts.append(dot)

    return parts


# ═══════════════════════════════════════════════════════════════
# GLÜHWÜRMCHEN
# ═══════════════════════════════════════════════════════════════
def create_fireflies():
    parts = []
    ff_pos = [
        ( 1.22,-0.18, 0.55), (-1.18,-0.14, 0.50),
        ( 0.68,-0.12,-0.80), (-0.75, 0.10, 0.88),
        ( 0.42,-0.10, 1.18), (-0.48, 0.16,-0.70),
        ( 1.05,-0.08,-0.38), (-0.95, 0.14, 0.30),
    ]
    for i, pos in enumerate(ff_pos):
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.048, segments=8, ring_count=5, location=pos)
        ff = bpy.context.active_object; ff.name = f"Aion_Firefly_{i}"
        smooth(ff)
        vcol(ff, C_GLOW_N if i%3!=2 else C_GOLD_N)
        parts.append(ff)
        # Leucht-Kern
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.022, segments=6, ring_count=4, location=pos)
        fc = bpy.context.active_object; fc.name = f"Aion_Firefly_{i}_Core"
        smooth(fc); vcol(fc, (1.0, 1.0, 0.8, 1.0)); parts.append(fc)

    return parts


# ═══════════════════════════════════════════════════════════════
# HAUPT
# ═══════════════════════════════════════════════════════════════
# ═══════════════════════════════════════════════════════════════
# AURA — Wald-Naturgeist-Feld
# ═══════════════════════════════════════════════════════════════
def create_aura():
    parts = []
    # Tiefgrüne Waldgeist-Aura-Hülle
    bpy.ops.mesh.primitive_ico_sphere_add(radius=1.58, subdivisions=1, location=(0,0,0))
    shell = bpy.context.active_object; shell.name = "Aura_Shell"
    vcol(shell, C_DARK_G); parts.append(shell)
    # Innerer Glühwürmchen-Ring
    bpy.ops.mesh.primitive_torus_add(
        major_radius=1.52, minor_radius=0.022,
        major_segments=60, minor_segments=8, location=(0,0,0))
    igr = bpy.context.active_object; igr.name = "Aura_InnerRing"
    vcol(igr, C_GLOW_N); parts.append(igr)
    # 3 Orbit-Ringe: Ranken-Zirkel
    for i, (rx, rz, mr, col) in enumerate([
        (0.0,       0.0,        1.80, C_LEAF),
        (math.pi/2, 0.0,        1.76, C_GLOW_N),
        (math.pi/2, math.pi/3,  1.72, C_VINE),
    ]):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=mr, minor_radius=0.016,
            major_segments=64, minor_segments=8,
            location=(0,0,0), rotation=(rx, 0, rz))
        r = bpy.context.active_object; r.name = f"Aura_Ring_{i}"
        bpy.ops.object.transform_apply(rotation=True)
        vcol(r, col); parts.append(r)
    # Sporen/Glühwürmchen-Partikelwolke (14 schwebende Lichter)
    for i in range(14):
        a = (i / 14) * math.tau
        h = math.sin(i * 1.1) * 0.46
        rd = 1.84 + (i % 3) * 0.07
        pos = (math.cos(a)*rd*math.cos(h), math.sin(a)*rd*math.cos(h), rd*math.sin(h))
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.025 + (i%3)*0.008, segments=6, ring_count=3, location=pos)
        p = bpy.context.active_object; p.name = f"Aura_Spore_{i}"
        smooth(p); vcol(p, C_GLOW_N if i%2==0 else C_GOLD_N); parts.append(p)
    # 6 Ranken-Ausläufer (nach außen gebogene Kegel)
    for i in range(6):
        a = (i / 6) * math.tau
        elev = math.pi / 5 * (1 if i%2==0 else -1)
        r1, r2 = 1.64, 2.04
        cx, cy = math.cos(a), math.sin(a)
        ce, se = math.cos(elev), math.sin(elev)
        vine = cone(f"Aura_Vine_{i}",
                    (cx*r1*ce, cy*r1*ce, r1*se),
                    (cx*r2*ce, cy*r2*ce, r2*se),
                    0.020, 0.003, 5)
        vcol(vine, C_VINE if i%2==0 else C_LEAF); parts.append(vine)
    # 6 schwebende Blatt-Fragmente
    for i in range(6):
        a = (i / 6) * math.tau + math.pi/6
        rd = 2.00 + (i%2)*0.08
        pos = (math.cos(a)*rd*0.88, math.sin(a)*rd*0.88, math.sin(i*1.2)*0.38)
        bpy.ops.mesh.primitive_cube_add(
            size=0.07, scale=(0.6, 1.6, 0.08), location=pos, rotation=(i*0.5, 0, a))
        lf = bpy.context.active_object; lf.name = f"Aura_Leaf_{i}"
        vcol(lf, C_BRIGHT_G if i%2==0 else C_LEAF); parts.append(lf)
    return parts


clear_scene()
col = bpy.data.collections.new("Aion_NatureSpirit")
bpy.context.scene.collection.children.link(col)

all_parts = (create_orb() + create_vines() + create_leaves()
             + create_flower_crown() + create_mushrooms()
             + create_fireflies() + create_aura())

for obj in all_parts:
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    col.objects.link(obj)

print(f"✅ Aion Nature Spirit — {len(all_parts)} Teile")
