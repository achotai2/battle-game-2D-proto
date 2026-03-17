import re

def main():
    with open("Scenes/Buildings/house.tscn") as f:
        content = f.read()

    print("\nSprite2D section:")
    match = re.search(r'\[node name="Sprite2D".*?\n(.*?)\n\[', content, re.DOTALL)
    if match:
        print(match.group(1))

if __name__ == "__main__":
    main()
