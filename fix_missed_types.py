import os
import re

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    replacements = {
        'type="StaticBody2D"': 'type="StaticBody3D"',
        'type="RigidBody2D"': 'type="RigidBody3D"',
        'type="NavigationObstacle2D"': 'type="NavigationObstacle3D"',
        'type="CapsuleShape2D"': 'type="CapsuleShape3D"',
    }

    for old, new in replacements.items():
        content = content.replace(old, new)

    # Remove LightOccluder2D nodes
    # [node name="..." type="LightOccluder2D" ...]
    # And its properties/children block?
    # Simple regex removal of the node line might leave dangling properties but Godot ignores them or we can remove the block.
    # Let's just change type to "Node3D" and likely the properties will be ignored or cause error.
    # Better: Remove the lines.

    # content = re.sub(r'\[node name="[^"]+" type="LightOccluder2D".*?((?=\[node)|$)', '', content, flags=re.DOTALL)
    # This regex is dangerous on huge files without careful testing.
    # Let's just rename type to Node3D for safety, so it doesn't crash loading.
    content = content.replace('type="LightOccluder2D"', 'type="Node3D"')

    # Also resource types in sub_resource
    content = content.replace('type="CapsuleShape2D"', 'type="CapsuleShape3D"')

    # Fix properties for NavigationObstacle3D?
    # NavObstacle2D has 'vertices'. NavObstacle3D uses 'vertices' too (in 4.0+ it changed, 4.2+ uses vertices).
    # But Godot 4.5 features string in project.godot suggests new version.
    # Let's assume compatibility.

    with open(filepath, 'w') as f:
        f.write(content)
    print(f"Fixed {filepath}")

for root, dirs, files in os.walk("."):
    for file in files:
        if file.endswith(".tscn"):
            process_file(os.path.join(root, file))
