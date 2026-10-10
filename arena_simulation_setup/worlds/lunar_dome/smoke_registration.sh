#!/usr/bin/env bash
# Confirms lunar_dome + LunarBot are registered for Arena.
# Does not start Isaac. Reset Task still requires:
#   arena launch sim:=isaac robot:=LunarBot world:=lunar_dome human:=hunav scenario:=default save_data:=false
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
# this file lives in arena_simulation_setup/worlds/lunar_dome
SETUP_SRC="$(cd "$(dirname "$0")/../.." && pwd)"
ARENA_SRC="$(cd "$SETUP_SRC/.." && pwd)"
WORLD="$ARENA_SRC/arena_simulation_setup/worlds/lunar_dome/world.yaml"
ROBOT="$ARENA_SRC/arena_robots/arena_robots/robots/LunarBot/model_params.yaml"
python3 - "$WORLD" "$ROBOT" << 'PY'
import sys, yaml
from pathlib import Path
world = yaml.safe_load(Path(sys.argv[1]).read_text())
usd = Path(world["usd_scene"]["path"])
assert usd.is_file(), usd
params = yaml.safe_load(Path(sys.argv[2]).read_text())
robot = Path(params["usd_redirect"])
assert robot.is_file(), robot
assert "startTimeCode" in usd.read_text(encoding="utf-8")
assert "LidarFrame" in robot.read_text(encoding="utf-8")
print("PASS registration")
print(" world", usd)
print(" robot", robot)
PY
INSTALL_W="/home/zy/SocialNav/arena_ws/install/arena_simulation_setup/share/arena_simulation_setup/worlds/lunar_dome/world.yaml"
INSTALL_R="/home/zy/SocialNav/arena_ws/install/arena_robots/share/arena_robots/robots/LunarBot/model_params.yaml"
test -f "$INSTALL_W" && test -f "$INSTALL_R"
echo "PASS install share copies"
echo "Next (interactive): arena launch sim:=isaac robot:=LunarBot world:=lunar_dome human:=hunav scenario:=default save_data:=false"
echo "Then RViz TaskGeneratorPanel -> Reset Task"
