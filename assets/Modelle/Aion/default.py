"""
==============================================================
  AUGE DES RA – KERN-KUGEL  |  Gods of Fate – Roblox Export
  Blender Python Skript (Scripting Tab)
==============================================================
  Anleitung:
  1. Öffne Blender (leer oder neues File)
  2. Gehe zu Scripting > New
  3. Füge dieses Skript ein und klicke "Run Script"
  4. Exportiere alle Objekte als FBX:
     File > Export > FBX (.fbx)
     - Apply Scalings: FBX Units Scale
     - Forward: -Z Forward, Up: Y Up
     - Mesh: Smoothing = Face, Vertex Colors = aktiviert
==============================================================
"""

import bpy
import math
import bmesh
from mathutils import Vector, Matrix


# ── Helfer: Szene leeren ────────────────────────────────────
def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)


# ── Helfer: Vertex Colors setzen ────────────────────────────
def apply_vertex_color(obj, r, g, b, a=1.0):
    """
    Wendet eine einheitliche Vertex-Color auf ALLE Corners
    eines Mesh-Objekts an (Roblox-kompatibel).
    """
    mesh = obj.data
    if not mesh.color_attributes:
        mesh.color_attributes.new(name="Color", type='FLOAT_COLOR', domain='CORNER')
    color_attr = mesh.color_attributes["Color"]
    for i in range(len(color_attr.data)):
        color_attr.data[i].color = (r, g, b, a)


# ── Helfer: Teilweises Einfärben per Gesichts-Index ─────────
def apply_vertex_color_partial(obj, face_indices, r, g, b, a=1.0):
    """
    Färbt nur bestimmte Faces (per Loop) in einer anderen Farbe.
    Wird für Rillen / Runen-Highlights genutzt.
    """
    mesh = obj.data
    if "Color" not in mesh.color_attributes:
        mesh.color_attributes.new(name="Color", type='FLOAT_COLOR', domain='CORNER')
    color_attr = mesh.color_attributes["Color"]

    poly_loop_start = {p.index: p.loop_start for p in mesh.polygons}
    poly_loop_total = {p.index: p.loop_total for p in mesh.polygons}

    for fi in face_indices:
        ls = poly_loop_start[fi]
        lt = poly_loop_total[fi]
        for loop_i in range(ls, ls + lt):
            color_attr.data[loop_i].color = (r, g, b, a)


# ═══════════════════════════════════════════════════════════
#  1. HAUPTKUGEL  –  Der Ra-Kern
# ═══════════════════════════════════════════════════════════
def create_main_sphere():
    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=1.0,
        segments=64,
        ring_count=32,
        location=(0, 0, 0)
    )
    sphere = bpy.context.active_object
    sphere.name = "RaCore_Sphere"

    # Basis-Farbe: warmes, dunkles Goldbraun (Obsidian-Gold)
    apply_vertex_color(sphere, 0.08, 0.06, 0.02, 1.0)

    # Smooth Shading
    bpy.ops.object.shade_smooth()

    return sphere


# ═══════════════════════════════════════════════════════════
#  2. LÄNGENGRAD-RILLEN  (8 vertikale Streifen)
# ═══════════════════════════════════════════════════════════
def create_longitude_grooves():
    grooves = []
    num_grooves = 8

    for i in range(num_grooves):
        angle = (2 * math.pi / num_grooves) * i

        # Schmale, tiefe Quader als Groove-Marker
        bpy.ops.mesh.primitive_cube_add(
            size=1,
            scale=(0.025, 0.025, 1.85),
            location=(
                math.cos(angle) * 1.01,
                math.sin(angle) * 1.01,
                0.0
            )
        )
        groove = bpy.context.active_object
        groove.name = f"RaCore_LongGroove_{i:02d}"

        # Drehe zum Mittelpunkt ausrichten
        groove.rotation_euler[2] = angle

        # Leuchtend goldene Rillen-Farbe
        apply_vertex_color(groove, 1.0, 0.75, 0.0, 1.0)
        grooves.append(groove)

    return grooves


# ═══════════════════════════════════════════════════════════
#  3. BREITENGRAD-RINGE  (5 horizontale Ringe)
# ═══════════════════════════════════════════════════════════
def create_latitude_rings():
    rings = []
    heights   = [0.75, 0.38, 0.0, -0.38, -0.75]
    radii     = [0.66, 0.92,  1.0,  0.92,  0.66]

    for idx, (h, r) in enumerate(zip(heights, radii)):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=r * 1.015,
            minor_radius=0.018,
            major_segments=64,
            minor_segments=12,
            location=(0, 0, h)
        )
        ring = bpy.context.active_object
        ring.name = f"RaCore_LatRing_{idx:02d}"

        # Äquator-Ring: helles Gold; andere: gedämpftes Kupfer
        if idx == 2:
            apply_vertex_color(ring, 1.0, 0.82, 0.1, 1.0)
        else:
            apply_vertex_color(ring, 0.72, 0.45, 0.08, 1.0)
        rings.append(ring)

    return rings


# ═══════════════════════════════════════════════════════════
#  4. HEILIGE RUNEN-SCHEIBEN  (Oktoeder-Muster, 3 Ebenen)
# ═══════════════════════════════════════════════════════════
def create_rune_discs():
    discs = []
    levels = [
        {"z": 0.55,  "r": 0.83, "n": 6,  "scale": (0.07, 0.007, 0.07)},
        {"z": 0.0,   "r": 1.0,  "n": 8,  "scale": (0.09, 0.007, 0.09)},
        {"z": -0.55, "r": 0.83, "n": 6,  "scale": (0.07, 0.007, 0.07)},
    ]

    for lvl in levels:
        n = lvl["n"]
        for i in range(n):
            angle = (2 * math.pi / n) * i + (math.pi / n) * (levels.index(lvl) % 2)
            x = math.cos(angle) * lvl["r"] * 1.02
            y = math.sin(angle) * lvl["r"] * 1.02
            z = lvl["z"]

            # Rune als flache Raute (Ico-Sphere, sehr flach)
            bpy.ops.mesh.primitive_ico_sphere_add(
                radius=1,
                subdivisions=1,
                location=(x, y, z)
            )
            rune = bpy.context.active_object
            rune.name = f"RaCore_Rune_{len(discs):03d}"
            rune.scale = lvl["scale"]
            bpy.ops.object.transform_apply(scale=True)

            # Runen leuchten in Turquoise-Gold
            apply_vertex_color(rune, 0.9, 1.0, 0.4, 1.0)
            discs.append(rune)

    return discs


# ═══════════════════════════════════════════════════════════
#  5. POL-KAPPEN  (oben + unten, dekorativ-metallisch)
# ═══════════════════════════════════════════════════════════
def create_pole_caps():
    caps = []

    for sign, name_suffix in [(1, "North"), (-1, "South")]:
        z_base = sign * 0.92

        # Basis-Zylinder der Kappe
        bpy.ops.mesh.primitive_cylinder_add(
            radius=0.28,
            depth=0.10,
            vertices=32,
            location=(0, 0, z_base + sign * 0.05)
        )
        cap_base = bpy.context.active_object
        cap_base.name = f"RaCore_Cap_{name_suffix}_Base"
        apply_vertex_color(cap_base, 0.55, 0.40, 0.05, 1.0)   # Dunkles Messing
        bpy.ops.object.shade_smooth()
        caps.append(cap_base)

        # Innerer Ring (goldener Akzent-Ring)
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.22,
            minor_radius=0.022,
            major_segments=32,
            minor_segments=8,
            location=(0, 0, z_base + sign * 0.10)
        )
        cap_ring = bpy.context.active_object
        cap_ring.name = f"RaCore_Cap_{name_suffix}_Ring"
        apply_vertex_color(cap_ring, 1.0, 0.80, 0.15, 1.0)    # Helles Gold
        caps.append(cap_ring)

        # Zentral-Kegel (Spitze)
        bpy.ops.mesh.primitive_cone_add(
            radius1=0.14,
            radius2=0.0,
            depth=0.18,
            vertices=16,
            location=(0, 0, z_base + sign * 0.18)
        )
        cap_cone = bpy.context.active_object
        cap_cone.name = f"RaCore_Cap_{name_suffix}_Spike"
        # Nordkegel: leuchtendes Weiß-Gold / Südkegel: Kupfer
        if sign == 1:
            apply_vertex_color(cap_cone, 1.0, 0.95, 0.6, 1.0)
        else:
            apply_vertex_color(cap_cone, 0.8, 0.35, 0.05, 1.0)
        bpy.ops.object.shade_smooth()
        caps.append(cap_cone)

        # 4 kleine Zierbolzen rund um die Kappe
        for j in range(4):
            bolt_angle = (math.pi / 2) * j
            bx = math.cos(bolt_angle) * 0.22
            by = math.sin(bolt_angle) * 0.22
            bpy.ops.mesh.primitive_uv_sphere_add(
                radius=0.025,
                segments=8,
                ring_count=6,
                location=(bx, by, z_base + sign * 0.10)
            )
            bolt = bpy.context.active_object
            bolt.name = f"RaCore_Cap_{name_suffix}_Bolt_{j}"
            apply_vertex_color(bolt, 1.0, 0.75, 0.0, 1.0)
            caps.append(bolt)

    return caps


# ═══════════════════════════════════════════════════════════
#  6. ÄQUATORIAlER SCHWEBERING  (großer äußerer Energiering)
# ═══════════════════════════════════════════════════════════
def create_equatorial_halo():
    bpy.ops.mesh.primitive_torus_add(
        major_radius=1.35,
        minor_radius=0.04,
        major_segments=80,
        minor_segments=16,
        location=(0, 0, 0)
    )
    halo = bpy.context.active_object
    halo.name = "RaCore_EquatorialHalo"
    apply_vertex_color(halo, 1.0, 0.60, 0.0, 1.0)   # Orange-Gold (Energiestrom)
    bpy.ops.object.shade_smooth()

    # 12 kleine Energie-Kugeln auf dem Halo-Ring
    energy_beads = []
    for i in range(12):
        angle = (2 * math.pi / 12) * i
        bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.055,
            segments=8,
            ring_count=6,
            location=(math.cos(angle) * 1.35, math.sin(angle) * 1.35, 0.0)
        )
        bead = bpy.context.active_object
        bead.name = f"RaCore_EnergyBead_{i:02d}"
        # Abwechselnd gold und weiß
        if i % 2 == 0:
            apply_vertex_color(bead, 1.0, 0.85, 0.2, 1.0)
        else:
            apply_vertex_color(bead, 0.95, 0.95, 1.0, 1.0)
        energy_beads.append(bead)

    return halo, energy_beads


# ═══════════════════════════════════════════════════════════
#  7. DIAGONALE ENERGIE-BÖGEN  (3 Großkreis-Bögen)
# ═══════════════════════════════════════════════════════════
def create_energy_arcs():
    arcs = []
    rotations = [0.0, math.pi / 3, (2 * math.pi) / 3]

    for idx, rot in enumerate(rotations):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=1.28,
            minor_radius=0.022,
            major_segments=80,
            minor_segments=8,
            location=(0, 0, 0)
        )
        arc = bpy.context.active_object
        arc.name = f"RaCore_Arc_{idx:02d}"
        arc.rotation_euler = (math.pi / 2, rot, 0)
        bpy.ops.object.transform_apply(rotation=True)
        apply_vertex_color(arc, 0.85, 1.0, 0.5, 1.0)   # Gelblich-Grünes Energielicht
        bpy.ops.object.shade_smooth()
        arcs.append(arc)

    return arcs


# ═══════════════════════════════════════════════════════════
#  HAUPT-AUFBAU
# ═══════════════════════════════════════════════════════════
clear_scene()

print("▶ Erstelle Ra-Kern...")
sphere         = create_main_sphere()
print("▶ Längengrad-Rillen...")
lon_grooves    = create_longitude_grooves()
print("▶ Breitengrad-Ringe...")
lat_rings      = create_latitude_rings()
print("▶ Heilige Runen...")
rune_discs     = create_rune_discs()
print("▶ Pol-Kappen...")
pole_caps      = create_pole_caps()
print("▶ Äquatorial-Halo...")
halo, beads    = create_equatorial_halo()
print("▶ Energie-Bögen...")
arcs           = create_energy_arcs()

# ── Alle Objekte in Collection zusammenfassen ───────────────
col = bpy.data.collections.new("AugeDesRa_Kern")
bpy.context.scene.collection.children.link(col)

all_objects = (
    [sphere]
    + lon_grooves
    + lat_rings
    + rune_discs
    + pole_caps
    + [halo]
    + beads
    + arcs
)

for obj in all_objects:
    # Aus Default-Collection entfernen
    for c in obj.users_collection:
        c.objects.unlink(obj)
    col.objects.link(obj)

print("✅ Auge des Ra – Kern fertig!")
print(f"   {len(all_objects)} Objekte in Collection 'AugeDesRa_Kern'")
print()
print("═══ EXPORT-ANLEITUNG ════════════════════════════════")
print("File > Export > FBX (.fbx)")
print("  Path Mode      : Copy")
print("  Apply Scalings : FBX Units Scale")
print("  Forward        : -Z Forward")
print("  Up             : Y Up")
print("  ✓ Apply Unit")
print("  ✓ Vertex Colors (unter Geometry)")
print("  Smoothing      : Face")
print("════════════════════════════════════════════════════")