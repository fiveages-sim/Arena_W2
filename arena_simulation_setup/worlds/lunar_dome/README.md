# lunar_dome + LunarBot — step-by-step launch

Same flow as GRScenes: Arena container → `arena launch` → Isaac + RViz + Nav2 → **Reset Task**.

Do **not** open `LunarSim_Smooth_*_HuNav.usda` by hand, and do **not** run the capsule / stdin teleop scripts for this path.

## 0. Stop leftover host processes

In every terminal that still runs ped sim / teleop / Script Editor Isaac:

```bash
# Ctrl+C until the prompt returns
```

Close any Isaac window you opened with `./isaac-sim.sh` on the host. Arena will start its own Isaac.

## 1. One-time: mount LunarBot into Docker (required once after `.env` change)

On the **host**:

```bash
cd ~/SocialNav/arena_ws
# Confirm .env has:
#   HOST_LUNARBOT_DIR=/home/zy/Isaac_Projects/LunarSim-Isaac/LunarBot-Nav2
grep HOST_LUNARBOT_DIR .env

source arena
arena_docker_compose up -d --force-recreate arena isaac
```

Exit the container shell if you entered it (`exit`), then verify mounts from the **host**:

```bash
docker exec arena-arena_ws-arena-1 bash -lc \
  'test -f /data/lunarbot/LunarBot-Isaac/urdf/chassis/env/LunarSim_Smooth_Dome_Yellow_Arena.usda && echo LUNAR_MOUNT_OK'

docker exec arena-arena_ws-isaac-1 bash -lc \
  'test -f /data/lunarbot/LunarBot-Isaac/urdf/chassis/LunarBot_ROS2_Arena.usda && echo LUNAR_ISAAC_MOUNT_OK'
```

You want both `LUNAR_*_OK`. If missing, fix `HOST_LUNARBOT_DIR` in `.env` and recreate again.

Refresh install share (host; already done if you just synced, safe to re-run):

```bash
cp -a ~/SocialNav/arena_ws/src/Arena/arena_simulation_setup/worlds/lunar_dome \
  ~/SocialNav/arena_ws/install/arena_simulation_setup/share/arena_simulation_setup/worlds/
cp -a ~/SocialNav/arena_ws/src/Arena/arena_robots/arena_robots/robots/LunarBot \
  ~/SocialNav/arena_ws/install/arena_robots/share/arena_robots/robots/
```

## 2. Every session: enter Arena

On the **host**:

```bash
cd ~/SocialNav/arena_ws
source arena
```

Prompt should look like `arena@...:/opt/arena_ws$`. Stay in this shell.

## 3. Launch lunar world + LunarBot + HuNav

Inside the Arena container:

```bash
arena launch sim:=isaac robot:=LunarBot world:=lunar_dome \
  tm_robots:=scenario tm_obstacles:=scenario \
  human:=hunav scenario:=default save_data:=false
```

Wait until Isaac and RViz appear (same timing as a GRScenes launch).

## 4. Play + Reset Task

1. In **Isaac**: press **Play** if it is not already playing.
2. In **RViz**: open **TaskGeneratorPanel** → click **Reset Task**.
3. If the robot stays idle or you see “out of map bounds”, click **Reset Task** again (same as GRScenes).

**Success:** HuNav human figures walk the lunar corridor and LunarBot drives toward the yellow dome.

## 5. Optional checks (second host terminal)

Arena uses `ROS_DOMAIN_ID=1` by default:

```bash
export ROS_DOMAIN_ID=1
# If you use host ROS tools against the stack:
source /opt/ros/jazzy/setup.bash
ros2 topic list | head
```

## 6. Stop

Ctrl+C in the `arena launch` terminal.

## What not to run

| Skip | Why |
|------|-----|
| `python3 Scripts/lunarbot_pedestrian_sim.py` | Not HuNav / not Reset Task |
| Script Editor `isaac_gui_move_pedestrians.py` | Capsule debug only |
| `SwerveKeyboard_stdin_cmd_vel.py` | Not Nav2 |
| Opening HuNav USDA in host `./isaac-sim.sh` | Bypasses Arena spawn |

## Smoke without HuNav (robot + scene only)

```bash
arena launch sim:=isaac robot:=LunarBot world:=lunar_dome \
  tm_robots:=scenario tm_obstacles:=scenario \
  human:=dummy save_data:=false
```

Expect lunar yard + LunarBot in Stage; no walking characters until `human:=hunav`.

## Troubleshooting (your current failure)

### Rocks missing on RViz costmap

The **static map** (`map/map.png`) fills the global costmap. An early map had only walls + dome, so rocks did not appear there. Rocks in Isaac are separate meshes; they mark the **local** costmap only when lidar (`…/LunarBot/scan`) is live.

`map.png` was updated to bake approximate rock obstacles. **Restart the launch** so `map_server` reloads it.

### Reset Task but nothing moves

Your log matches this pattern:

| Log | Meaning |
|-----|---------|
| `human:=dummy` | No HuNav characters. Use `human:=hunav`. |
| `/World/Pedestrians/hunav_* does not exist` | Scenario lists agents; dummy never spawned them. |
| `odom TF frame not available` | Odom/TF not ready before the goal. |
| `Costmap timed out waiting for update` | Local costmap never got a fresh `/scan` (or TF) → planner aborts. |
| `spin failed` / `Goal failed` | Nav2 recovery after plan failure — rover will not drive. |

**Do this:**

1. Ctrl+C the launch.
2. Relaunch with **`human:=hunav`** (not dummy), Isaac **Playing**, then Reset Task.
3. Diagnose sensors (`ROS_DOMAIN_ID=1`):

```bash
export ROS_DOMAIN_ID=1
source /opt/ros/jazzy/setup.bash
ros2 topic hz /task_generator_node/LunarBot/scan
ros2 topic hz /task_generator_node/LunarBot/odom
```

If `scan`/`odom` are silent, Nav2 cannot move LunarBot until the Isaac ROS lidar/odom graph publishes under that namespace.

### MDL Plastic_ABS / Aluminum errors

Missing `chassis/Materials` symlink (now restored). Restart Isaac so materials load; pink robot / broken shaders otherwise.
