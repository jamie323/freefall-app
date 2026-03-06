#!/usr/bin/env python3
"""
Freefall Level Generator v2
Generates 80 level JSON files (8 worlds x 10 levels) with logarithmic difficulty scaling.
"""

import json
import math
import os
import random

# -- Constants -----------------------------------------------------------------
BASE_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "src", "Freefall", "Freefall", "levels",
)

WORLDS = 8
LEVELS_PER_WORLD = 10
TOTAL_LEVELS = WORLDS * LEVELS_PER_WORLD  # 80

PLAY_Y_TOP = 0.06      # top bar centre
PLAY_Y_BOT = 0.94      # bottom bar centre
BAR_HEIGHT = 0.018
BALL_DIAMETER = 0.04
MIN_GAP = 0.08          # 2x ball diameter
LAUNCH_X = 0.08
GOAL_X = 0.9
OBS_X_MIN = 0.15
OBS_X_MAX = 0.85

TOP_BAR = {
    "id": "top-bar",
    "type": "rect",
    "position": {"x": 0.5, "y": 0.06},
    "size": {"width": 1.0, "height": 0.018},
    "rotation": 0,
    "style": "solid",
}

BOT_BAR = {
    "id": "bot-bar",
    "type": "rect",
    "position": {"x": 0.5, "y": 0.94},
    "size": {"width": 1.0, "height": 0.018},
    "rotation": 0,
    "style": "solid",
}


# -- Helpers -------------------------------------------------------------------

def lerp(a, b, t):
    return a + (b - a) * t


def r(value, decimals=3):
    """Round a float to *decimals* places."""
    return round(value, decimals)


def difficulty_t(level_index):
    """Normalised difficulty in [0, 1] using logarithmic scaling."""
    return math.log(level_index + 1) / math.log(TOTAL_LEVELS)


def rects_overlap(ax, ay, aw, ah, bx, by, bw, bh, margin=0.0):
    """Axis-aligned overlap check between two rectangles with optional margin."""
    return (
        abs(ax - bx) < (aw + bw) / 2 + margin
        and abs(ay - by) < (ah + bh) / 2 + margin
    )


def point_clear_of_obstacles(px, py, obstacles, clearance=0.06):
    """Return True if (px, py) is at least *clearance* from every obstacle edge."""
    for obs in obstacles:
        ox = obs["position"]["x"]
        oy = obs["position"]["y"]
        ow = obs["size"]["width"]
        oh = obs["size"]["height"]
        if (abs(px - ox) < ow / 2 + clearance) and (abs(py - oy) < oh / 2 + clearance):
            return False
    return True


# -- Core generation -----------------------------------------------------------

def generate_level(world_id, level_id):
    level_index = (world_id - 1) * LEVELS_PER_WORLD + (level_id - 1)  # 0-79
    t = difficulty_t(level_index)

    rng = random.Random(world_id * 100 + level_id)

    # -- Scaled parameters -----------------------------------------------------
    num_obstacles = max(1, round(lerp(1, 8, t)))
    dx = r(lerp(120, 250, t), 1)
    max_rotation = lerp(0, 35, t)
    max_obs_height = lerp(0.15, 0.35, t)
    min_obs_width = lerp(0.05, 0.03, t)
    goal_radius = round(lerp(44, 28, t))
    par_flips = max(2, round(lerp(2, 9, t)))
    par_time = r(lerp(3.2, 1.2, t), 1)

    # -- Goal position ---------------------------------------------------------
    if t < 0.3:
        goal_y = r(rng.uniform(0.4, 0.6))
    else:
        goal_y = r(rng.uniform(0.2, 0.8))

    # -- Gravity ---------------------------------------------------------------
    initial_gravity_down = (world_id != 7)

    # -- Obstacle placement ----------------------------------------------------
    obstacles_data = []   # dicts ready for JSON (excluding bars)

    span = OBS_X_MAX - OBS_X_MIN
    slot_width = span / num_obstacles

    for i in range(num_obstacles):
        # Even horizontal distribution + jitter
        base_x = OBS_X_MIN + slot_width * (i + 0.5)
        jitter = rng.uniform(-0.03, 0.03)
        ox = r(max(OBS_X_MIN, min(OBS_X_MAX, base_x + jitter)))

        # Zigzag: alternate top-half / bottom-half
        playable_top = PLAY_Y_TOP + BAR_HEIGHT / 2 + 0.04
        playable_bot = PLAY_Y_BOT - BAR_HEIGHT / 2 - 0.04
        mid = (playable_top + playable_bot) / 2

        if i % 2 == 0:
            oy = r(rng.uniform(playable_top + 0.05, mid - 0.02))
        else:
            oy = r(rng.uniform(mid + 0.02, playable_bot - 0.05))

        # Size
        ow = r(max(min_obs_width, rng.uniform(min_obs_width, min_obs_width + 0.025)))
        oh = r(rng.uniform(0.12, max_obs_height))

        # Rotation
        rot = round(rng.uniform(-max_rotation, max_rotation), 1)

        # Overlap check against already-placed obstacles
        placed = True
        for existing in obstacles_data:
            ex = existing["position"]["x"]
            ey = existing["position"]["y"]
            ew = existing["size"]["width"]
            eh = existing["size"]["height"]
            if rects_overlap(ox, oy, ow, oh, ex, ey, ew, eh, margin=MIN_GAP):
                # Nudge y toward centre and retry once
                oy = r(mid + rng.uniform(-0.05, 0.05))
                if rects_overlap(ox, oy, ow, oh, ex, ey, ew, eh, margin=MIN_GAP):
                    placed = False
                    break

        if not placed:
            continue  # skip this obstacle rather than create an impossible gap

        # Gap to top/bottom bar must be passable
        top_edge = oy - oh / 2
        bot_edge = oy + oh / 2
        gap_to_top = top_edge - (PLAY_Y_TOP + BAR_HEIGHT / 2)
        gap_to_bot = (PLAY_Y_BOT - BAR_HEIGHT / 2) - bot_edge

        if gap_to_top < MIN_GAP and gap_to_bot < MIN_GAP:
            # Shrink obstacle so at least one gap is passable
            oh = r(min(oh, (PLAY_Y_BOT - PLAY_Y_TOP) - BAR_HEIGHT - 2 * MIN_GAP - 0.02))
            oy = r(mid + rng.uniform(-0.05, 0.05))

        obs = {
            "id": f"obs-{i+1}",
            "type": "rect",
            "position": {"x": ox, "y": oy},
            "size": {"width": ow, "height": oh},
            "rotation": rot,
            "style": "solid",
        }
        obstacles_data.append(obs)

    # -- Build full obstacle list (bars + custom) ------------------------------
    all_obstacles = [TOP_BAR, BOT_BAR] + obstacles_data

    # -- Collectible placement -------------------------------------------------
    collectibles = []

    # Sort obstacles by x so we can place collectibles in gaps
    sorted_obs = sorted(obstacles_data, key=lambda o: o["position"]["x"])

    # Build list of gap x-centres (before first, between each pair, after last)
    gap_xs = []
    if sorted_obs:
        gap_xs.append(r((LAUNCH_X + sorted_obs[0]["position"]["x"]) / 2))
        for j in range(len(sorted_obs) - 1):
            gap_xs.append(r((sorted_obs[j]["position"]["x"] + sorted_obs[j + 1]["position"]["x"]) / 2))
        gap_xs.append(r((sorted_obs[-1]["position"]["x"] + GOAL_X) / 2))
    else:
        gap_xs = [0.3, 0.5, 0.7]

    # Pick 3 gap positions (spread out)
    if len(gap_xs) >= 3:
        step = len(gap_xs) / 3
        chosen_gaps = [gap_xs[int(step * k)] for k in range(3)]
    else:
        chosen_gaps = (gap_xs * 3)[:3]

    # Heights: top third, middle, bottom third
    height_zones = [
        (PLAY_Y_TOP + 0.08, 0.38),   # upper
        (0.38, 0.62),                  # middle
        (0.62, PLAY_Y_BOT - 0.08),   # lower
    ]
    rng.shuffle(height_zones)

    for idx, cx in enumerate(chosen_gaps):
        zone = height_zones[idx % 3]
        cy = r(rng.uniform(zone[0], zone[1]))

        # Validate clearance -- nudge if needed (up to 5 attempts)
        for _ in range(5):
            if point_clear_of_obstacles(cx, cy, obstacles_data, clearance=0.06):
                break
            cy = r(rng.uniform(zone[0], zone[1]))

        collectibles.append({"x": cx, "y": cy})

    # -- Assemble JSON ---------------------------------------------------------
    level = {
        "worldId": world_id,
        "levelId": level_id,
        "launchPosition": {"x": 0.08, "y": 0.5},
        "launchVelocity": {"dx": dx, "dy": 0},
        "goalPosition": {"x": 0.9, "y": goal_y},
        "goalRadius": goal_radius,
        "initialGravityDown": initial_gravity_down,
        "parFlips": par_flips,
        "parTime": par_time,
        "obstacles": all_obstacles,
        "collectibles": collectibles,
    }
    return level


# -- Main ----------------------------------------------------------------------

def main():
    summary_rows = []

    for w in range(1, WORLDS + 1):
        world_dir = os.path.join(BASE_DIR, f"world{w}")
        os.makedirs(world_dir, exist_ok=True)

        for l in range(1, LEVELS_PER_WORLD + 1):
            level = generate_level(w, l)
            filename = f"w{w}l{l:02d}.json"
            filepath = os.path.join(world_dir, filename)

            with open(filepath, "w") as f:
                json.dump(level, f, indent=2)

            num_obs = len(level["obstacles"]) - 2  # exclude bars
            summary_rows.append((
                w, l, num_obs, level["launchVelocity"]["dx"],
                level["goalRadius"], level["parFlips"], level["parTime"],
                level["initialGravityDown"],
            ))

    # -- Validation ------------------------------------------------------------
    print("=" * 90)
    print("FREEFALL LEVEL GENERATION -- VALIDATION REPORT")
    print("=" * 90)

    missing = []
    invalid_json = []
    for w in range(1, WORLDS + 1):
        for l in range(1, LEVELS_PER_WORLD + 1):
            filepath = os.path.join(BASE_DIR, f"world{w}", f"w{w}l{l:02d}.json")
            if not os.path.exists(filepath):
                missing.append(filepath)
            else:
                try:
                    with open(filepath) as f:
                        json.load(f)
                except json.JSONDecodeError:
                    invalid_json.append(filepath)

    if missing:
        print(f"\nMISSING FILES ({len(missing)}):")
        for p in missing:
            print(f"  {p}")
    else:
        print(f"\nAll 80 level files present.")

    if invalid_json:
        print(f"\nINVALID JSON ({len(invalid_json)}):")
        for p in invalid_json:
            print(f"  {p}")
    else:
        print("All 80 JSON files are valid.\n")

    # -- Summary table ---------------------------------------------------------
    header = f"{'World':>5}  {'Level':>5}  {'Obs':>3}  {'Velocity':>8}  {'GoalR':>5}  {'ParF':>4}  {'ParT':>5}  {'GravDown':>8}"
    print(header)
    print("-" * len(header))
    for row in summary_rows:
        w, l, nobs, vel, gr, pf, pt, gd = row
        print(f"{w:>5}  {l:>5}  {nobs:>3}  {vel:>8}  {gr:>5}  {pf:>4}  {pt:>5}  {str(gd):>8}")

    print(f"\nTotal levels generated: {len(summary_rows)}")


if __name__ == "__main__":
    main()
