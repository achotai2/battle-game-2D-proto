#!/bin/bash
# Find Godot executable
GODOT_BIN=$(find / -name "godot" -type f -executable 2>/dev/null | grep -v "steam" | head -n 1)
if [ -z "$GODOT_BIN" ]; then
    GODOT_BIN=$(find / -name "godot*" -type f -executable 2>/dev/null | grep -v "steam" | head -n 1)
fi

if [ -n "$GODOT_BIN" ]; then
    echo "Found Godot at $GODOT_BIN"
    $GODOT_BIN --headless -s benchmark_shader.gd
else
    echo "Godot not found"
fi
