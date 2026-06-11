import bpy, bmesh, math
from mathutils import Vector, Matrix

# ============================================================
# AION  —  CELESTIAL ORRERY  |  Roblox-safe FBX
# Mechanisches Sonnensystem: Kugel als Zentralstern, 5 orbitale
# Planetenringe mit Monden, Kometen, Armillarsphären-Ringe mit
# Gradmarken, Sternburst-Strahlen, Konstellationslinien.
# ============================================================

C_ORB     = (0.10, 0.08, 0.02, 1.0)   # Zentrum Dunkel-Ocker
C_STAR    = (0.98, 0.88, 0.40, 1.0)   # Stern Gold
C_STAR2   = (1.00, 0.96, 0.70, 1.0)   # Stern Hellgelb
C_BRASS   = (0.72, 0.54, 0.12, 1.0)   # Messing Ring-Rahmen
C_BRONZE  = (0.52, 0.36, 0.08, 1.0)   # Bronze Dunkel
C_P1      = (0.28, 0.18, 0.08, 1.0)   # Planet 1 Steinbraun
C_P2      = (0.12, 0.30, 0.52, 1.0)   # Planet 2 Ozean-Blau
C_P3      = (0.52, 0.22, 0.06, 1.0)   # Planet 3 Mars-Rot
C_P4      = (0.36, 0.28, 0.18, 1.0)   # Planet 4 Erdgrau
C_P5      = (0.28, 0.48, 0.62, 1.0)   # Planet 5 Eis-Blau
C_MOON    = (0.62, 0.60, 0.54, 1.0)   # Mond Grau
C_COMET   = (0.82, 0.90, 0.96, 1.0)   # Komet Weiß-Blau
C_COMET_T = (0.40, 0.55, 0.80, 1.0)   # Komet-Schweif
C_RING_M  = (0.58, 0.48, 0.18, 1.0)   # Ring-Markierungen
C_CONST   = (0.55, 0.70, 0.90, 1.0)   # Konstellationslinien
C_ENERGY  = (0.88, 0.78, 0.20, 1.0)   # Energie-Gold

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
# ZENTRALSTERN (Kugel)
# ═══════════════════════════════════════════════════════════════
def create_star_orb():
    parts = []
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, segments=64, ring_count=32, location=(0,0,0))
    orb = bpy.context.active_object; orb.name = "Aion_Orb"; smooth(orb); vcol(orb, C_ORB); parts.append(orb)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.68, segments=24, ring_count=14, location=(0,0,0))
    c1 = bpy.context.active_object; c1.name = "Star_Corona1"; smooth(c1); vcol(c1, (0.55,0.40,0.06,1.0)); parts.append(c1)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.40, subdivisions=2, location=(0,0,0))
    c2 = bpy.context.active_object; c2.name = "Star_Core"; smooth(c2); vcol(c2, C_STAR); parts.append(c2)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.18, segments=10, ring_count=6, location=(0,0,0))
    c3 = bpy.context.active_object; c3.name = "Star_Nucleus"; smooth(c3); vcol(c3, C_STAR2); parts.append(c3)
    # Korona-Ringe
    for i, (maj, col) in enumerate([(1.06, C_STAR), (1.18, (0.88,0.68,0.12,1.0)), (1.30, C_BRASS)]):
        bpy.ops.mesh.primitive_torus_add(major_radius=maj, minor_radius=0.020-i*0.002,
                                          major_segments=64, minor_segments=9, location=(0,0,0))
        r = bpy.context.active_object; r.name = f"Star_CoronaRing_{i}"; vcol(r, col); parts.append(r)
    # 16 Strahlstücke aus dem Stern (kurze Gold-Kegel)
    for i in range(16):
        a = (i/16)*math.tau
        p0 = (math.cos(a)*1.06, math.sin(a)*1.06, 0)
        p1 = (math.cos(a)*1.40, math.sin(a)*1.40, 0)
        ray = cone_obj(f"Star_Ray_{i}", p0, p1, 0.030, 0.005, 4)
        vcol(ray, C_STAR2 if i%2==0 else C_STAR); parts.append(ray)
    return parts


# ═══════════════════════════════════════════════════════════════
# ARMILLAR-RINGE (Rahmen-Konstrukt)
# ═══════════════════════════════════════════════════════════════
def create_armillary_rings():
    parts = []
    ring_cfgs = [
        # (major_r, minor_r, tilt_x, tilt_z, n_markers, col)
        (1.55, 0.028, 0.0,          0.0,       24, C_BRASS),   # Äquator
        (1.55, 0.022, math.pi/2,    0.0,       18, C_BRONZE),  # Meridian 0°
        (1.55, 0.022, math.pi/2,    math.pi/3, 18, C_BRONZE),  # Meridian 60°
        (1.55, 0.022, math.pi/2,    math.pi*2/3, 18, C_BRONZE),# Meridian 120°
        (1.48, 0.018, math.pi/4,    math.pi/4, 14, C_BRASS),   # Ekliptik-schräg
        (1.42, 0.015, math.pi/3,    math.pi*0.7, 12, C_BRONZE),# Weitere Schräge
    ]
    for ri, (maj, mnr, tx, tz, n_mark, col) in enumerate(ring_cfgs):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=maj, minor_radius=mnr,
            major_segments=80, minor_segments=10,
            location=(0,0,0), rotation=(tx, 0, tz))
        ring = bpy.context.active_object; ring.name = f"Armillary_Ring_{ri}"
        bpy.ops.object.transform_apply(rotation=True)
        vcol(ring, col); parts.append(ring)
        # Grad-Markierungen entlang Ring
        for mi in range(n_mark):
            a = (mi/n_mark)*math.tau
            # Punkt auf dem Ring nach Rotation
            rx = maj * math.cos(a)
            ry = maj * math.sin(a)
            rz = 0.0
            # Rotation anwenden
            cos_x, sin_x = math.cos(tx), math.sin(tx)
            ry2 = ry*cos_x - rz*sin_x; rz2 = ry*sin_x + rz*cos_x
            cos_z, sin_z = math.cos(tz), math.sin(tz)
            rx3 = rx*cos_z - ry2*sin_z; ry3 = rx*sin_z + ry2*cos_z
            pos = (rx3, ry3, rz2)
            bpy.ops.mesh.primitive_cube_add(
                size=0.04, scale=(0.4, 0.4, 1.6 if mi%6==0 else 0.8),
                location=pos)
            mk = bpy.context.active_object; mk.name = f"Ring_{ri}_Mark_{mi}"
            vcol(mk, C_RING_M if mi%6==0 else C_BRASS); parts.append(mk)
    # Kreuzungs-Knoten (4 goldene Kugeln an Schnittpunkten)
    for i in range(4):
        a = (i/4)*math.tau
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.048, segments=8, ring_count=5,
                                               location=(math.cos(a)*1.55, math.sin(a)*1.55, 0))
        kn = bpy.context.active_object; kn.name = f"Armillary_Node_{i}"; smooth(kn); vcol(kn, C_ENERGY); parts.append(kn)
    return parts


# ═══════════════════════════════════════════════════════════════
# PLANETEN & MONDE
# ═══════════════════════════════════════════════════════════════
def create_planet(name, orbit_r, phi_offset, planet_r, planet_col, tilt=0.0,
                  n_moons=0, moon_r=0.06, ring_planet=False):
    parts = []
    px = math.cos(phi_offset) * orbit_r
    py = math.sin(phi_offset) * orbit_r
    pz = math.sin(tilt) * orbit_r * 0.25
    pos = (px, py, pz)

    bpy.ops.mesh.primitive_uv_sphere_add(radius=planet_r, segments=14, ring_count=8, location=pos)
    pl = bpy.context.active_object; pl.name = name; smooth(pl); vcol(pl, planet_col); parts.append(pl)

    # Planeten-Ring (Saturn-artig)
    if ring_planet:
        bpy.ops.mesh.primitive_torus_add(major_radius=planet_r*2.0, minor_radius=planet_r*0.18,
                                          major_segments=32, minor_segments=7, location=pos,
                                          rotation=(math.pi*0.18, 0, phi_offset))
        pr = bpy.context.active_object; pr.name = f"{name}_Ring"
        bpy.ops.object.transform_apply(rotation=True)
        vcol(pr, C_MOON); parts.append(pr)

    # Monde
    for mi in range(n_moons):
        ma = (mi/max(n_moons,1))*math.tau + phi_offset
        moon_orbit = planet_r * 2.8 + mi*planet_r*0.8
        mx = px + math.cos(ma)*moon_orbit
        my = py + math.sin(ma)*moon_orbit
        mz = pz + math.sin(ma)*planet_r*0.5
        bpy.ops.mesh.primitive_uv_sphere_add(radius=moon_r, segments=8, ring_count=5, location=(mx,my,mz))
        moon = bpy.context.active_object; moon.name = f"{name}_Moon{mi}"; smooth(moon); vcol(moon, C_MOON); parts.append(moon)
        # Verbindungs-Stab zu Planet
        mo_line = cyl(f"{name}_MoonStalk{mi}", pos, (mx,my,mz), 0.010, 5)
        vcol(mo_line, C_BRONZE); parts.append(mo_line)
    return parts

def create_all_planets():
    parts = []
    # 5 Orbital-Bahnen (sichtbare Torus-Ringe)
    orbit_data = [
        (2.10, C_BRONZE, 0.0),
        (2.65, C_BRASS,  0.12),
        (3.20, C_BRONZE, 0.0),
        (3.75, C_BRASS,  0.08),
        (4.30, C_BRONZE, 0.0),
    ]
    for oi, (r, col, tilt) in enumerate(orbit_data):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=r, minor_radius=0.014,
            major_segments=80, minor_segments=7,
            location=(0,0,0), rotation=(tilt, 0, 0))
        orb_ring = bpy.context.active_object; orb_ring.name = f"Orbit_Ring_{oi}"
        bpy.ops.object.transform_apply(rotation=True)
        vcol(orb_ring, col); parts.append(orb_ring)

    # Planeten auf den Bahnen
    parts += create_planet("Planet_Mercury", 2.10, 0.80, 0.095, C_P1, 0.0, n_moons=0)
    parts += create_planet("Planet_Ocean",   2.65, 2.10, 0.130, C_P2, 0.12, n_moons=1, moon_r=0.045)
    parts += create_planet("Planet_Mars",    3.20, 3.80, 0.110, C_P3, 0.0, n_moons=2, moon_r=0.040)
    parts += create_planet("Planet_Saturn",  3.75, 5.20, 0.155, C_P4, 0.08, n_moons=2, moon_r=0.050, ring_planet=True)
    parts += create_planet("Planet_Ice",     4.30, 1.40, 0.120, C_P5, 0.0, n_moons=1, moon_r=0.055)
    return parts


# ═══════════════════════════════════════════════════════════════
# KOMETEN
# ═══════════════════════════════════════════════════════════════
def create_comets():
    parts = []
    comet_data = [
        ((3.50, 1.20,  0.80), (-0.80, -0.20, -0.50), 5, 0.06),
        ((-2.80, 2.10, -0.40), (0.60, -0.55, 0.30),  6, 0.055),
        ((1.80, -3.20, 0.60), (-0.40, 0.80, -0.25),  4, 0.050),
    ]
    for ci, (pos, tail_dir, n_trail, head_r) in enumerate(comet_data):
        # Kometen-Kopf
        bpy.ops.mesh.primitive_uv_sphere_add(radius=head_r, segments=9, ring_count=6, location=pos)
        head = bpy.context.active_object; head.name = f"Comet{ci}_Head"; smooth(head); vcol(head, C_COMET); parts.append(head)
        # Leuchtkern
        bpy.ops.mesh.primitive_uv_sphere_add(radius=head_r*0.45, segments=7, ring_count=5, location=pos)
        glow = bpy.context.active_object; glow.name = f"Comet{ci}_Glow"; smooth(glow); vcol(glow, C_STAR2); parts.append(glow)
        # Schweif: verjüngende Zylinder-Kette
        td = Vector(tail_dir)
        prev = Vector(pos)
        for ti in range(n_trail):
            nxt = prev + td * 0.28
            r_trail = head_r * (1.0 - ti/n_trail) * 0.65
            seg = cyl(f"Comet{ci}_Trail{ti}", prev, nxt, r_trail, 6)
            vcol(seg, C_COMET if ti < 2 else C_COMET_T); parts.append(seg)
            prev = nxt
    return parts


# ═══════════════════════════════════════════════════════════════
# KONSTELLATIONSLINIEN
# ═══════════════════════════════════════════════════════════════
def create_constellations():
    parts = []
    # 3 Konstellationsmuster (einfache Polygon-Verbindungen)
    constellations = [
        # (punkte, verbindungen)
        ([(3.20, 0.80, 1.60), (3.80, 1.40, 1.20), (4.20, 0.60, 0.80),
          (3.60, -0.20, 1.40), (3.00, 0.40, 1.80)],
         [(0,1),(1,2),(2,3),(3,4),(4,0),(1,3)]),
        ([(-2.80, 1.50, -0.80), (-3.40, 0.80, -1.20), (-3.80, 1.60, -1.60),
          (-2.60, 2.10, -1.40)],
         [(0,1),(1,2),(2,3),(3,0),(0,2)]),
        ([(0.60, -3.20, 1.20), (1.40, -3.60, 0.80), (0.20, -4.00, 1.60),
          (-0.60, -3.40, 0.60)],
         [(0,1),(1,2),(2,3),(3,0),(0,2)]),
    ]
    for ci, (pts, edges) in enumerate(constellations):
        # Stern-Knoten
        for pi, pt in enumerate(pts):
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.040, segments=7, ring_count=5, location=pt)
            star = bpy.context.active_object; star.name = f"Const{ci}_Star{pi}"; smooth(star); vcol(star, C_STAR2); parts.append(star)
        # Verbindungslinien
        for ei, (a, b) in enumerate(edges):
            line = cyl(f"Const{ci}_Line{ei}", pts[a], pts[b], 0.008, 4)
            vcol(line, C_CONST); parts.append(line)
    return parts


clear_scene()
col = bpy.data.collections.new("Aion_CelestialOrrery")
bpy.context.scene.collection.children.link(col)

all_parts = (create_star_orb()
           + create_armillary_rings()
           + create_all_planets()
           + create_comets()
           + create_constellations())

for obj in all_parts:
    for c in list(obj.users_collection): c.objects.unlink(obj)
    col.objects.link(obj)
print(f"✅ Aion Celestial Orrery — {len(all_parts)} Teile")
