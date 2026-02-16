import re

with open("Scenes/main.tscn", "r") as f:
    content = f.read()

# 1. Replace Camera2D with Camera3D
# Find the Camera2D node inside player structure?
# Wait, main.tscn has:
# [node name="Camera2D" type="Camera3D" parent="EnvironmentalObjects/Units/Player"]
# position = Vector3(0, 0, 1)
#
# The script previously converted type="Camera2D" -> type="Camera3D".
# But position (0, 0, 1) is useless for top down 3D.
# We need (0, 20, 10) and rotation (-60 deg around X).
# rotation_degrees = Vector3(-60, 0, 0)
#
# But wait, Camera is child of Player. Player moves around.
# Camera should follow Player.
# Usually TopDown camera: (0, 10, 5) relative to player. rotation (-60, 0, 0).
# Let's set it to (0, 15, 10) relative position, looking down at player.

def fix_camera(match):
    # match.group(0) is the whole node line.
    return '[node name="Camera3D" type="Camera3D" parent="EnvironmentalObjects/Units/Player"]\nposition = Vector3(0, 15, 10)\nrotation = Vector3(-1.0, 0, 0)'

content = re.sub(r'\[node name="Camera2D" type="Camera3D"[^\]]*\]\nposition = Vector3\([^)]+\)', fix_camera, content)

# 2. Replace TileMapLayer with CSGBox3D (Ground)
# Remove the tile map data block too which is huge.
# Pattern: [node name="TileMapLayer" ... tile_map_data = PackedByteArray("...") ... tile_set = SubResource("...")]
# This spans multiple lines.
# And remove the SubResource for TileSetAtlasSource and TileSet.
# This is hard with regex due to nesting and order.
#
# Easier approach: replace the node definition line and wipe properties until next node?
# Or simply rename it to CSGBox3D and remove incompatible properties.
# Godot scene parser is robust enough to ignore unknown properties usually? No, it might error.
# But "tile_map_data" property on CSGBox3D? It will error.

# Let's try to locate the node by name and replace entirely.
start_marker = '[node name="TileMapLayer" type="TileMapLayer" parent="."]'
end_marker = '[node name="EnvironmentalObjects"' # The next node usually.

if start_marker in content and end_marker in content:
    # Find start index
    start_idx = content.find(start_marker)
    # Find end index (start of next node)
    end_idx = content.find(end_marker)

    # We want to replace everything in between with our new ground node.
    new_ground = """[node name="Ground" type="CSGBox3D" parent="."]
size = Vector3(2000, 1, 2000)
position = Vector3(0, -0.5, 0)
use_collision = true
"""
    content = content[:start_idx] + new_ground + "\n" + content[end_idx:]

# 3. Replace NavigationRegion2D with NavigationRegion3D
# [node name="NavigationRegion2D" type="NavigationRegion2D" parent="EnvironmentalObjects"]
# navigation_polygon = SubResource("NavigationPolygon_fvkhu")
#
# We want:
# [node name="NavigationRegion3D" type="NavigationRegion3D" parent="EnvironmentalObjects"]
# navigation_mesh = SubResource("NavigationMesh_new")

start_nav = '[node name="NavigationRegion2D" type="NavigationRegion2D"'
if start_nav in content:
    # Find the block start
    idx = content.find(start_nav)
    # Replace the line
    content = content.replace(start_nav, '[node name="NavigationRegion3D" type="NavigationRegion3D"')

    # Replace property navigation_polygon with navigation_mesh
    # But we need a valid mesh resource.
    # Let's add a new sub_resource definition at the top and reference it.

    # Add resource
    resource_def = '\n[sub_resource type="NavigationMesh" id="NavigationMesh_new"]\nvertices = PackedVector3Array(-1000, 0, -1000, 1000, 0, -1000, 1000, 0, 1000, -1000, 0, 1000)\npolygons = [PackedInt32Array(0, 1, 2, 3)]\n'
    # Insert after format line?
    # Find first [ext_resource or [sub_resource
    first_res = content.find('[ext_resource')
    if first_res == -1: first_res = content.find('[sub_resource')
    if first_res != -1:
        content = content[:first_res] + resource_def + content[first_res:]

    # Replace usage
    content = re.sub(r'navigation_polygon = SubResource\("NavigationPolygon_[^"]+"\)', 'navigation_mesh = SubResource("NavigationMesh_new")', content)

# 4. Replace Sunlight (CanvasModulate) with DirectionalLight3D
# [node name="Sunlight" type="CanvasModulate" parent="WeatherState"]
# script = ExtResource("20_pdsj5")
#
# Change type to DirectionalLight3D. Parent is WeatherState (Node).
# Add rotation to simulate sun angle.
content = content.replace('[node name="Sunlight" type="CanvasModulate"', '[node name="Sunlight" type="DirectionalLight3D"')
# Add properties for shadow and rotation?
# We can insert them after the script line.
script_line = 'script = ExtResource("20_pdsj5")'
if script_line in content:
    content = content.replace(script_line, script_line + '\nrotation = Vector3(-1.0, 0.5, 0)\nshadow_enabled = true')


with open("Scenes/main.tscn", "w") as f:
    f.write(content)

print("Refactored Scenes/main.tscn")
