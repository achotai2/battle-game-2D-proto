def test_texture_classes():
    code = """
extends Node

func check_texture(tex):
    if tex is Texture2D:
        return "Texture2D"
    if tex is CompressedTexture2D:
        return "CompressedTexture2D"
    return "Unknown"
"""
    print("In Godot 4, preload() returns a CompressedTexture2D instead of a regular Texture2D in some contexts.")
    print("If it is a CompressedTexture2D, Godot's 'is Texture2D' check should ideally pass since it inherits from Texture2D.")

test_texture_classes()
