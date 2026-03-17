import re

def main():
    with open("Scenes/Buildings/house.tscn") as f:
        content = f.read()

    print("BuildingVisuals section:")
    match = re.search(r'\[node name="BuildingVisuals".*?\n(.*?)\n\[', content, re.DOTALL)
    if match:
        print(match.group(1))

    print("\nSprites section:")
    match = re.search(r'\[node name="Sprites".*?\n(.*?)\n\[', content, re.DOTALL)
    if match:
        print(match.group(1))

if __name__ == "__main__":
    main()
