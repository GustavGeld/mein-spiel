import bpy
import math

# =========================================================================
# SYSTEM-RESET: Alte Meshes löschen für eine saubere Generierung
# =========================================================================
if bpy.ops.object.mode_set.poll():
    bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

# =========================================================================
# HILFSFUNKTION: REGEL 1 - Vertex Colors auf Corner-Domain anwenden
# =========================================================================
def apply_vertex_color(obj, color_rgba):
    mesh = obj.data
    color_attr = mesh.color_attributes.get("Color")
    if not color_attr:
        color_attr = mesh.color_attributes.new(
            name="Color", 
            type='FLOAT_COLOR', 
            domain='CORNER'
        )
    for corner in mesh.loops:
        color_attr.data[corner.index].color = color_rgba

# Drei-Farben-Palette für maximalen Detailgrad (RGBA Floats 0.0 - 1.0)
COLOR_IVORY = (0.95, 0.95, 0.92, 1.0)  # Die heilige Kern-Kugel
COLOR_GOLD  = (1.0, 0.72, 0.08, 1.0)   # Das massive Gold-Relief & Krone
COLOR_GEM   = (0.0, 0.85, 1.0, 1.0)    # Leuchtende Edelsteine (Perfekt für Roblox Neon!)

# =========================================================================
# KOMPONENTE 1: REGEL 2 & 3 - Die Götter-Zentralkugel
# =========================================================================
bpy.ops.mesh.primitive_uv_sphere_add(radius=2.0, location=(0, 0, 0))
core_obj = bpy.context.active_object  # REGEL 2
core_obj.name = "God_Orb_Core"
apply_vertex_color(core_obj, COLOR_IVORY)
bpy.ops.object.shade_smooth()

# =========================================================================
# KOMPONENTE 2: Filigraner Hüllen-Käfig (Mehrschichtige Relief-Bänder)
# =========================================================================
# Haupt-Äquatorring (Mitte)
bpy.ops.mesh.primitive_torus_add(location=(0, 0, 0), major_radius=2.03, minor_radius=0.06)
band_master = bpy.context.active_object
apply_vertex_color(band_master, COLOR_GOLD)
bpy.ops.object.shade_smooth()

# Zwei dünnere Begleit-Ringe (Ober- und unterhalb des Äquators für Schichtung)
for z_offset in [0.25, -0.25]:
    bpy.ops.mesh.primitive_torus_add(location=(0, 0, z_offset), major_radius=2.01, minor_radius=0.02)
    accent_ring = bpy.context.active_object
    apply_vertex_color(accent_ring, COLOR_GOLD)
    bpy.ops.object.shade_smooth()

# 4 Vertikale Meridian-Ringe, die ein majestätisches Gitter bilden
for i in range(4):
    rot_z = (i / 4) * math.pi
    bpy.ops.mesh.primitive_torus_add(location=(0, 0, 0), major_radius=2.02, minor_radius=0.03, rotation=(math.pi/2, 0, rot_z))
    meridian = bpy.context.active_object
    apply_vertex_color(meridian, COLOR_GOLD)
    bpy.ops.object.shade_smooth()

# =========================================================================
# KOMPONENTE 3: Äquator-Prunkplatten & eingebettete Kristalle (8 Segmente)
# =========================================================================
num_segments = 8
for i in range(num_segments):
    angle = (i / num_segments) * 2 * math.pi
    x = math.cos(angle) * 2.03
    y = math.sin(angle) * 2.03
    
    # Goldene Trägerplatte (Ein Würfel, der durch Rotation wie ein Diamant wirkt)
    bpy.ops.mesh.primitive_cube_add(
        size=1.0, 
        scale=(0.08, 0.35, 0.35), # REGEL 3: Direktes Erstellungs-Scaling
        location=(x, y, 0), 
        rotation=(0, math.pi/4, angle)
    )
    plate = bpy.context.active_object
    apply_vertex_color(plate, COLOR_GOLD)
    bpy.ops.object.shade_smooth()
    
    # Eingebetteter cyan-farbener Kristall im Zentrum der Platte (4-seitige Doppel-Pyramide)
    bpy.ops.mesh.primitive_cone_add(
        vertices=4, 
        radius1=0.12, 
        depth=0.25, 
        location=(x * 1.03, y * 1.03, 0), 
        rotation=(0, math.pi/2, angle)
    )
    gem = bpy.context.active_object
    apply_vertex_color(gem, COLOR_GEM)
    bpy.ops.object.shade_smooth()

# =========================================================================
# KOMPONENTE 4: Die Große Zweistufige Götterkrone (Nordpol)
# =========================================================================
# Kronen-Fundament (Massiver gestufter Ring)
bpy.ops.mesh.primitive_torus_add(location=(0, 0, 1.65), major_radius=1.1, minor_radius=0.07)
crown_base1 = bpy.context.active_object
apply_vertex_color(crown_base1, COLOR_GOLD)

bpy.ops.mesh.primitive_torus_add(location=(0, 0, 1.78), major_radius=0.95, minor_radius=0.04)
crown_base2 = bpy.context.active_object
apply_vertex_color(crown_base2, COLOR_GOLD)

# 8 Gotische Haupt-Zacken (Groß) mit schwebenden Juwelen auf den Spitzen
num_spikes = 8
for i in range(num_spikes):
    a = (i / num_spikes) * 2 * math.pi
    sx = math.cos(a) * 0.95
    sy = math.sin(a) * 0.95
    sz = 2.1
    
    # Haupt-Zacke (Spitz zulaufende Pyramide)
    bpy.ops.mesh.primitive_cone_add(
        vertices=4, 
        radius1=0.15, 
        depth=0.6, # Z-Streckung direkt im Operator
        location=(sx, sy, sz), 
        rotation=(0, 0, a + math.pi/4)
    )
    spike = bpy.context.active_object
    apply_vertex_color(spike, COLOR_GOLD)
    bpy.ops.object.shade_smooth()
    
    # Der Kronen-Edelstein auf der äußersten Spitze der Zacke
    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=0.07, 
        location=(sx, sy, sz + 0.35)
    )
    crown_jewel = bpy.context.active_object
    apply_vertex_color(crown_jewel, COLOR_GEM)
    bpy.ops.object.shade_smooth()

# 8 Zwischen-Zacken (Klein, versetzt angeordnet für mehr Tiefe)
for i in range(num_spikes):
    a_minor = ((i + 0.5) / num_spikes) * 2 * math.pi
    smx = math.cos(a_minor) * 1.02
    smy = math.sin(a_minor) * 1.02
    smz = 1.95
    
    bpy.ops.mesh.primitive_cone_add(
        vertices=4, 
        radius1=0.08, 
        depth=0.3, 
        location=(smx, smy, smz), 
        rotation=(0, 0, a_minor + math.pi/4)
    )
    minor_spike = bpy.context.active_object
    apply_vertex_color(minor_spike, COLOR_GOLD)
    bpy.ops.object.shade_smooth()

# =========================================================================
# KOMPONENTE 5: Das Kosmische Pendel (Südpol-Verzierung)
# =========================================================================
# Südpol-Halterung
bpy.ops.mesh.primitive_torus_add(location=(0, 0, -1.75), major_radius=0.7, minor_radius=0.05)
bottom_ring = bpy.context.active_object
apply_vertex_color(bottom_ring, COLOR_GOLD)

# Großer, nach unten zeigender Splitter-Kristall
bpy.ops.mesh.primitive_cone_add(
    vertices=6, 
    radius1=0.18, 
    depth=0.6, 
    location=(0, 0, -2.2), 
    rotation=(math.pi, 0, 0) # Gedreht, um nach unten zu zeigen
)
pendant_crystal = bpy.context.active_object
apply_vertex_color(pendant_crystal, COLOR_GEM)
bpy.ops.object.shade_smooth()

# =========================================================================
# FINALE ZUSAMMENFASSUNG: Alle Teile zu einem sauberen Roblox-Mesh verbinden
# =========================================================================
bpy.ops.object.select_all(action='DESELECT')

# Alle generierten Meshes auswählen
for obj in bpy.context.scene.objects:
    if obj.type == 'MESH':
        obj.select_set(True)

# Die Zentralkugel wird zum aktiven Hauptobjekt (Hält den Pivot bei 0,0,0)
bpy.context.view_layer.objects.active = core_obj
bpy.ops.object.join()

# Umbenennen für den Asset-Manager
core_obj.name = "God_Orb_Magnum_Relief"
print("[Roblox-Blender Engine] Prunk-Modell mit 3 Farbzonen erfolgreich generiert!")