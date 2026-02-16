import os
import re

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    replacements = {
        'StaticBody2D': 'StaticBody3D',
        'RigidBody2D': 'RigidBody3D',
        'Sprite2D': 'Sprite3D',
        'AnimatedSprite2D': 'AnimatedSprite3D',
        'NavigationObstacle2D': 'NavigationObstacle3D',
        'CharacterBody2D': 'CharacterBody3D',
        'Area2D': 'Area3D', # Just in case missed
        'CollisionShape2D': 'CollisionShape3D',
        'LightOccluder2D': 'Node3D', # Fallback
    }

    # Simple replace is dangerous if "Sprite2D" is part of a string or variable name?
    # But for a refactor script, it's usually acceptable if variables follow snake_case.
    # Class names are PascalCase.
    # So replacing these keywords is mostly safe.

    for old, new in replacements.items():
        content = content.replace(old, new)

    with open(filepath, 'w') as f:
        f.write(content)
    print(f"Fixed types in {filepath}")

for root, dirs, files in os.walk("."):
    for file in files:
        if file.endswith(".gd"):
            process_file(os.path.join(root, file))
