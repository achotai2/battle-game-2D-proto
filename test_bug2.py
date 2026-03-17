import re

def main():
    with open("Scripts/BuildingNodes/BuildingVisuals.gd") as f:
        content = f.read()
    print("Match:", re.findall(r'elif visual is Sprite3D and frames is Texture2D', content))

if __name__ == "__main__":
    main()
