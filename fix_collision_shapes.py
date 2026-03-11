import os
import re

def process_file(filepath):
    if not filepath.endswith(".tscn"):
        return
    if ".tmp" in filepath:
        return

    with open(filepath, 'r') as f:
        content = f.read()

    # 1. Update node names
    content = content.replace('name="CollisionShape2D" type="CollisionShape3D"', 'name="CollisionShape3D" type="CollisionShape3D"')

    # 2. Update shape resources: e.g. CircleShape2D -> CylinderShape3D
    # Let's find SubResource("CircleShape2D_xxx") and SubResource type definition
    content = re.sub(r'type="CircleShape2D"', 'type="CylinderShape3D"', content)
    content = re.sub(r'CircleShape2D_([a-zA-Z0-9]+)', r'CylinderShape3D_\1', content)

    # 3. Update shape resources: e.g. CapsuleShape2D -> CapsuleShape3D
    content = re.sub(r'type="CapsuleShape2D"', 'type="CapsuleShape3D"', content)
    content = re.sub(r'CapsuleShape2D_([a-zA-Z0-9]+)', r'CapsuleShape3D_\1', content)

    # 4. Update shape resources: e.g. RectangleShape2D -> BoxShape3D
    content = re.sub(r'type="RectangleShape2D"', 'type="BoxShape3D"', content)
    content = re.sub(r'RectangleShape2D_([a-zA-Z0-9]+)', r'BoxShape3D_\1', content)

    with open(filepath, 'w') as f:
        f.write(content)

for root, dirs, files in os.walk("Scenes/"):
    for file in files:
        process_file(os.path.join(root, file))
