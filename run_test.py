import sys

def parse_tscn(path):
    with open(path, 'r') as f:
        content = f.read()
    print("Read", path)

if __name__ == '__main__':
    parse_tscn("./Scenes/Buildings/house.tscn")
