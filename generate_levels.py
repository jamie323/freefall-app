#!/usr/bin/env python3
"""
Freefall iOS Game — Level Generator
Generates all 40 level JSON files with mathematically validated physics.

Game: gravity-flip side-scroller. Ball moves RIGHT at constant horizontal velocity.
Player taps to flip gravity (toggle between falling down and up).
Normalized coordinates (0-1 range). iPhone ~393x852 points. Ball diameter = 28pt.
"""

import json
import math
import os
import sys

# --- Constants ----------------------------------------------------------------

SCREEN_W = 393.0
SCREEN_H = 852.0
BALL_DIAMETER_PT = 28.0
BALL_RADIUS_PT = 14.0
BALL_R_Y = BALL_RADIUS_PT / SCREEN_H   # ~0.0164
BALL_R_X = BALL_RADIUS_PT / SCREEN_W   # ~0.0356
BALL_DIAM_Y = BALL_DIAMETER_PT / SCREEN_H  # ~0.0329

# Boundaries
TOP_BAR_Y = 0.06
BOT_BAR_Y = 0.94
TOP_BAR_H = 0.018
BOT_BAR_H = 0.018
PLAY_TOP = TOP_BAR_Y + TOP_BAR_H / 2 + BALL_R_Y   # ~0.0854
PLAY_BOT = BOT_BAR_Y - BOT_BAR_H / 2 - BALL_R_Y   # ~0.9146
PLAY_HEIGHT = PLAY_BOT - PLAY_TOP                    # ~0.829

LAUNCH_X = 0.08
LAUNCH_Y = 0.5
GOAL_X = 0.9
DEFAULT_GOAL_RADIUS = 35
W1L01_GOAL_RADIUS = 44

LEVELS_BASE = "/Users/jamiethomson/freefall-app/src/Freefall/Freefall/levels"

# --- Helpers ------------------------------------------------------------------

def make_boundaries():
    return [
        {
            "id": "top-bar", "type": "rect",
            "position": {"x": 0.5, "y": TOP_BAR_Y},
            "size": {"width": 1.0, "height": TOP_BAR_H},
            "rotation": 0, "style": "solid"
        },
        {
            "id": "bot-bar", "type": "rect",
            "position": {"x": 0.5, "y": BOT_BAR_Y},
            "size": {"width": 1.0, "height": BOT_BAR_H},
            "rotation": 0, "style": "solid"
        }
    ]


def compute_par_time(velocity_dx):
    """parTime = (goalX - launchX) * screenWidth / velocityDX * 1.2"""
    return round((GOAL_X - LAUNCH_X) * SCREEN_W / velocity_dx * 1.2, 1)


def rotated_bbox(cx, cy, w, h, rotation_deg):
    """Compute axis-aligned bounding box of a rotated rectangle in normalized coords."""
    rad = math.radians(rotation_deg)
    cos_a = abs(math.cos(rad))
    sin_a = abs(math.sin(rad))
    half_w = w / 2.0
    half_h = h / 2.0
    eff_half_w = half_w * cos_a + half_h * sin_a
    eff_half_h = half_w * sin_a + half_h * cos_a
    return {
        "x_min": cx - eff_half_w,
        "x_max": cx + eff_half_w,
        "y_min": cy - eff_half_h,
        "y_max": cy + eff_half_h,
    }


def validate_level(level_data, world_id, level_id):
    """Validate that a level is physically possible. Returns (passed, min_gap, messages)."""
    messages = []
    passed = True
    obstacles = level_data["obstacles"]
    collectibles = level_data["collectibles"]

    game_obs = [o for o in obstacles if o["id"] not in ("top-bar", "bot-bar")]

    # 1. Compute bounding boxes for all game obstacles
    obs_bboxes = []
    for obs in game_obs:
        cx = obs["position"]["x"]
        cy = obs["position"]["y"]
        w = obs["size"]["width"]
        h = obs["size"]["height"]
        rot = obs.get("rotation", 0)
        bb = rotated_bbox(cx, cy, w, h, rot)
        obs_bboxes.append((obs["id"], bb))

    # 2. Check no obstacle at x < 0.12
    for oid, bb in obs_bboxes:
        if bb["x_min"] < 0.12:
            messages.append(f"  WARN: {oid} extends to x={bb['x_min']:.3f} (< 0.12)")

    # 3. Check obstacles don't overlap each other
    for i in range(len(obs_bboxes)):
        for j in range(i + 1, len(obs_bboxes)):
            id_i, bb_i = obs_bboxes[i]
            id_j, bb_j = obs_bboxes[j]
            if (bb_i["x_min"] < bb_j["x_max"] and bb_i["x_max"] > bb_j["x_min"] and
                bb_i["y_min"] < bb_j["y_max"] and bb_i["y_max"] > bb_j["y_min"]):
                messages.append(f"  FAIL: {id_i} overlaps {id_j}")
                passed = False

    # 4. For each x where an obstacle exists, verify continuous vertical gap >= min_gap
    min_gap_map = {
        1: {1: 0.15, 2: 0.12, 3: 0.12, 4: 0.10, 5: 0.10,
            6: 0.08, 7: 0.08, 8: 0.08, 9: 0.07, 10: 0.07},
        2: {1: 0.08, 2: 0.08, 3: 0.08, 4: 0.07, 5: 0.07,
            6: 0.07, 7: 0.06, 8: 0.06, 9: 0.06, 10: 0.06},
        3: {1: 0.07, 2: 0.07, 3: 0.07, 4: 0.065, 5: 0.065,
            6: 0.065, 7: 0.06, 8: 0.06, 9: 0.06, 10: 0.06},
        4: {1: 0.065, 2: 0.065, 3: 0.065, 4: 0.06, 5: 0.06,
            6: 0.06, 7: 0.055, 8: 0.055, 9: 0.055, 10: 0.05},
    }
    min_gap = min_gap_map[world_id][level_id]

    x_samples = [LAUNCH_X + i * 0.005 for i in range(int((GOAL_X - LAUNCH_X) / 0.005) + 1)]
    min_found_gap = 1.0

    for x in x_samples:
        blocking = []
        for oid, bb in obs_bboxes:
            if bb["x_min"] - BALL_R_X <= x <= bb["x_max"] + BALL_R_X:
                blocking.append((bb["y_min"] - BALL_R_Y, bb["y_max"] + BALL_R_Y))

        # Add boundaries as blockers
        blocking.append((0.0, PLAY_TOP))
        blocking.append((PLAY_BOT, 1.0))

        blocking.sort(key=lambda b: b[0])

        # Merge overlapping intervals
        merged = []
        for b_start, b_end in blocking:
            if merged and b_start <= merged[-1][1]:
                merged[-1] = (merged[-1][0], max(merged[-1][1], b_end))
            else:
                merged.append((b_start, b_end))

        # Find largest gap between merged intervals
        largest_gap = 0.0
        prev_end = 0.0
        for b_start, b_end in merged:
            gap = b_start - prev_end
            if gap > largest_gap:
                largest_gap = gap
            prev_end = b_end
        gap = 1.0 - prev_end
        if gap > largest_gap:
            largest_gap = gap

        if largest_gap < min_found_gap:
            min_found_gap = largest_gap

        if largest_gap < min_gap:
            messages.append(f"  FAIL: At x={x:.3f}, largest gap={largest_gap:.4f} < min_gap={min_gap}")
            passed = False
            break

    # 5. Verify collectibles don't overlap obstacles
    for ci, coll in enumerate(collectibles):
        cx = coll["position"]["x"]
        cy = coll["position"]["y"]
        if cy - BALL_R_Y < PLAY_TOP:
            messages.append(f"  FAIL: Collectible {ci} at y={cy:.3f} too close to top boundary")
            passed = False
        if cy + BALL_R_Y > PLAY_BOT:
            messages.append(f"  FAIL: Collectible {ci} at y={cy:.3f} too close to bottom boundary")
            passed = False
        for oid, bb in obs_bboxes:
            margin = BALL_R_Y
            if (cx + margin > bb["x_min"] and cx - margin < bb["x_max"] and
                cy + margin > bb["y_min"] and cy - margin < bb["y_max"]):
                messages.append(f"  FAIL: Collectible {ci} at ({cx:.3f},{cy:.3f}) overlaps {oid}")
                passed = False

    # 6. Verify goal y is reachable
    goal_y = level_data["goalPosition"]["y"]
    if goal_y < PLAY_TOP + BALL_R_Y or goal_y > PLAY_BOT - BALL_R_Y:
        messages.append(f"  FAIL: Goal y={goal_y} outside playable range [{PLAY_TOP + BALL_R_Y:.4f}, {PLAY_BOT - BALL_R_Y:.4f}]")
        passed = False

    return passed, min_found_gap, messages


def make_obstacle(obs_id, x, y, width, height, rotation=0):
    return {
        "id": obs_id,
        "type": "rect",
        "position": {"x": round(x, 4), "y": round(y, 4)},
        "size": {"width": round(width, 4), "height": round(height, 4)},
        "rotation": rotation,
        "style": "solid"
    }


def make_collectible(x, y):
    return {"position": {"x": round(x, 4), "y": round(y, 4)}}


def make_level(world_id, level_id, velocity_dx, goal_y, par_flips,
               obstacle_defs, collectible_defs, goal_radius=None):
    if goal_radius is None:
        goal_radius = DEFAULT_GOAL_RADIUS

    obstacles = make_boundaries()
    for i, od in enumerate(obstacle_defs):
        x, y, w, h, rot = od
        obstacles.append(make_obstacle(f"obs-{i}", x, y, w, h, rot))

    collectibles = [make_collectible(cx, cy) for cx, cy in collectible_defs]
    par_time = compute_par_time(velocity_dx)

    return {
        "worldId": world_id,
        "levelId": level_id,
        "launchPosition": {"x": LAUNCH_X, "y": LAUNCH_Y},
        "launchVelocity": {"dx": velocity_dx, "dy": 0},
        "goalPosition": {"x": GOAL_X, "y": round(goal_y, 4)},
        "goalRadius": goal_radius,
        "initialGravityDown": True,
        "parFlips": par_flips,
        "parTime": par_time,
        "obstacles": obstacles,
        "collectibles": collectibles,
    }


# ==============================================================================
# WORLD 1: THE BLOCK — floaty, forgiving (gravity=50, flipImpulse=35)
# ==============================================================================

def generate_world1():
    levels = []

    # W1L01: Tutorial — 1 obstacle, huge gaps, slow velocity
    levels.append(make_level(1, 1, 120, 0.5, 2,
        obstacle_defs=[
            (0.50, 0.50, 0.04, 0.18, 0),
        ],
        collectible_defs=[
            (0.35, 0.35),
            (0.55, 0.70),
            (0.75, 0.40),
        ],
        goal_radius=W1L01_GOAL_RADIUS
    ))

    # W1L02: 1 obstacle, slightly taller
    levels.append(make_level(1, 2, 140, 0.45, 2,
        obstacle_defs=[
            (0.48, 0.55, 0.04, 0.22, 0),
        ],
        collectible_defs=[
            (0.30, 0.30),
            (0.55, 0.25),
            (0.75, 0.70),
        ],
    ))

    # W1L03: 2 obstacles, generous gaps
    levels.append(make_level(1, 3, 140, 0.55, 3,
        obstacle_defs=[
            (0.38, 0.35, 0.04, 0.20, 0),
            (0.62, 0.65, 0.04, 0.20, 0),
        ],
        collectible_defs=[
            (0.28, 0.65),
            (0.50, 0.50),
            (0.75, 0.30),
        ],
    ))

    # W1L04: 2 obstacles, moderate gaps
    levels.append(make_level(1, 4, 150, 0.40, 3,
        obstacle_defs=[
            (0.35, 0.30, 0.045, 0.22, 0),
            (0.60, 0.70, 0.045, 0.22, 0),
        ],
        collectible_defs=[
            (0.25, 0.65),
            (0.48, 0.55),
            (0.75, 0.30),
        ],
    ))

    # W1L05: 2 obstacles, staggered high/low
    levels.append(make_level(1, 5, 150, 0.60, 3,
        obstacle_defs=[
            (0.40, 0.25, 0.045, 0.20, 0),
            (0.65, 0.75, 0.045, 0.20, 0),
        ],
        collectible_defs=[
            (0.30, 0.70),
            (0.52, 0.50),
            (0.80, 0.35),
        ],
    ))

    # W1L06: 2 obstacles + tighter, collectibles more challenging
    levels.append(make_level(1, 6, 160, 0.35, 3,
        obstacle_defs=[
            (0.35, 0.40, 0.05, 0.25, 0),
            (0.60, 0.65, 0.05, 0.20, 0),
        ],
        collectible_defs=[
            (0.25, 0.75),
            (0.48, 0.20),
            (0.78, 0.80),
        ],
    ))

    # W1L07: 3 obstacles, weaving path
    levels.append(make_level(1, 7, 160, 0.70, 4,
        obstacle_defs=[
            (0.30, 0.35, 0.045, 0.22, 0),
            (0.52, 0.65, 0.045, 0.22, 0),
            (0.74, 0.35, 0.045, 0.22, 0),
        ],
        collectible_defs=[
            (0.22, 0.70),
            (0.42, 0.50),
            (0.63, 0.25),
        ],
    ))

    # W1L08: 3 obstacles, varied sizes
    levels.append(make_level(1, 8, 160, 0.30, 4,
        obstacle_defs=[
            (0.32, 0.60, 0.05, 0.25, 0),
            (0.54, 0.30, 0.04, 0.20, 0),
            (0.76, 0.65, 0.05, 0.22, 0),
        ],
        collectible_defs=[
            (0.22, 0.30),
            (0.43, 0.80),
            (0.65, 0.50),
        ],
    ))

    # W1L09: 3 obstacles, tighter gaps
    levels.append(make_level(1, 9, 170, 0.25, 4,
        obstacle_defs=[
            (0.30, 0.45, 0.05, 0.28, 0),
            (0.52, 0.70, 0.05, 0.25, 0),
            (0.74, 0.35, 0.05, 0.25, 0),
        ],
        collectible_defs=[
            (0.22, 0.78),
            (0.42, 0.22),
            (0.63, 0.55),
        ],
    ))

    # W1L10: 3 obstacles, world 1 finale
    levels.append(make_level(1, 10, 170, 0.75, 5,
        obstacle_defs=[
            (0.28, 0.35, 0.05, 0.30, 0),
            (0.52, 0.65, 0.05, 0.28, 0),
            (0.76, 0.40, 0.05, 0.28, 0),
        ],
        collectible_defs=[
            (0.20, 0.72),
            (0.40, 0.20),
            (0.64, 0.82),
        ],
    ))

    return levels


# ==============================================================================
# WORLD 2: NEON YARD — snappy, responsive (gravity=65, flipImpulse=48)
# ==============================================================================

def generate_world2():
    levels = []

    # W2L01: 3 obstacles, gaps 0.08+
    levels.append(make_level(2, 1, 175, 0.45, 4,
        obstacle_defs=[
            (0.30, 0.35, 0.05, 0.25, 0),
            (0.52, 0.65, 0.05, 0.25, 0),
            (0.74, 0.40, 0.05, 0.22, 0),
        ],
        collectible_defs=[
            (0.22, 0.70),
            (0.42, 0.25),
            (0.64, 0.80),
        ],
    ))

    # W2L02: 3 obstacles, different layout
    levels.append(make_level(2, 2, 175, 0.60, 4,
        obstacle_defs=[
            (0.32, 0.60, 0.05, 0.28, 0),
            (0.54, 0.35, 0.05, 0.25, 0),
            (0.76, 0.60, 0.05, 0.25, 0),
        ],
        collectible_defs=[
            (0.22, 0.30),
            (0.44, 0.75),
            (0.65, 0.20),
        ],
    ))

    # W2L03: 3 obstacles with one slightly rotated
    levels.append(make_level(2, 3, 175, 0.35, 4,
        obstacle_defs=[
            (0.30, 0.45, 0.05, 0.28, 0),
            (0.52, 0.70, 0.05, 0.22, 10),
            (0.74, 0.35, 0.05, 0.25, 0),
        ],
        collectible_defs=[
            (0.22, 0.75),
            (0.42, 0.25),
            (0.64, 0.55),
        ],
    ))

    # W2L04: 3 obstacles, rotations
    levels.append(make_level(2, 4, 180, 0.70, 4,
        obstacle_defs=[
            (0.28, 0.35, 0.05, 0.25, -10),
            (0.50, 0.60, 0.05, 0.28, 15),
            (0.72, 0.40, 0.05, 0.25, -10),
        ],
        collectible_defs=[
            (0.20, 0.70),
            (0.40, 0.25),
            (0.62, 0.78),
        ],
    ))

    # W2L05: 4 obstacles
    levels.append(make_level(2, 5, 180, 0.40, 5,
        obstacle_defs=[
            (0.25, 0.40, 0.045, 0.25, 0),
            (0.42, 0.65, 0.045, 0.22, 10),
            (0.59, 0.35, 0.045, 0.25, 0),
            (0.76, 0.60, 0.045, 0.22, -10),
        ],
        collectible_defs=[
            (0.20, 0.72),
            (0.34, 0.25),
            (0.68, 0.80),
        ],
    ))

    # W2L06: 4 obstacles, rotated
    levels.append(make_level(2, 6, 180, 0.30, 5,
        obstacle_defs=[
            (0.26, 0.60, 0.05, 0.28, 10),
            (0.44, 0.35, 0.05, 0.25, -15),
            (0.62, 0.65, 0.05, 0.22, 10),
            (0.80, 0.40, 0.05, 0.25, 0),
        ],
        collectible_defs=[
            (0.20, 0.30),
            (0.35, 0.78),
            (0.72, 0.22),
        ],
    ))

    # W2L07: 4 obstacles, tighter gaps
    levels.append(make_level(2, 7, 185, 0.65, 5,
        obstacle_defs=[
            (0.25, 0.40, 0.05, 0.30, 0),
            (0.44, 0.68, 0.05, 0.28, 15),
            (0.63, 0.35, 0.05, 0.28, -10),
            (0.80, 0.60, 0.05, 0.25, 0),
        ],
        collectible_defs=[
            (0.20, 0.75),
            (0.35, 0.22),
            (0.72, 0.82),
        ],
    ))

    # W2L08: 4 obstacles, varied rotations
    levels.append(make_level(2, 8, 185, 0.35, 5,
        obstacle_defs=[
            (0.26, 0.55, 0.05, 0.30, -15),
            (0.44, 0.35, 0.05, 0.25, 10),
            (0.62, 0.70, 0.05, 0.28, -10),
            (0.80, 0.40, 0.05, 0.25, 15),
        ],
        collectible_defs=[
            (0.20, 0.80),
            (0.35, 0.20),
            (0.72, 0.55),
        ],
    ))

    # W2L09: 4 obstacles, aggressive placement
    levels.append(make_level(2, 9, 190, 0.75, 5,
        obstacle_defs=[
            (0.25, 0.40, 0.055, 0.30, 10),
            (0.43, 0.65, 0.055, 0.28, -15),
            (0.61, 0.35, 0.055, 0.28, 10),
            (0.79, 0.65, 0.055, 0.25, -10),
        ],
        collectible_defs=[
            (0.20, 0.75),
            (0.34, 0.22),
            (0.70, 0.50),
        ],
    ))

    # W2L10: 4 obstacles, world 2 finale
    levels.append(make_level(2, 10, 190, 0.25, 6,
        obstacle_defs=[
            (0.24, 0.60, 0.055, 0.32, -10),
            (0.42, 0.35, 0.055, 0.28, 15),
            (0.60, 0.65, 0.055, 0.30, -15),
            (0.78, 0.38, 0.055, 0.28, 10),
        ],
        collectible_defs=[
            (0.18, 0.30),
            (0.34, 0.78),
            (0.70, 0.22),
        ],
    ))

    return levels


# ==============================================================================
# WORLD 3: UNDERGROUND — heavy, sluggish (gravity=75, flipImpulse=32)
# ==============================================================================

def generate_world3():
    levels = []

    # W3L01: 4 obstacles
    levels.append(make_level(3, 1, 190, 0.50, 5,
        obstacle_defs=[
            (0.25, 0.35, 0.05, 0.25, 0),
            (0.43, 0.65, 0.05, 0.25, 0),
            (0.61, 0.35, 0.05, 0.22, 10),
            (0.79, 0.65, 0.05, 0.22, 0),
        ],
        collectible_defs=[
            (0.20, 0.70),
            (0.34, 0.25),
            (0.70, 0.50),
        ],
    ))

    # W3L02: 4 obstacles, different layout
    levels.append(make_level(3, 2, 190, 0.35, 5,
        obstacle_defs=[
            (0.27, 0.60, 0.05, 0.28, 0),
            (0.45, 0.35, 0.05, 0.25, -10),
            (0.63, 0.60, 0.05, 0.25, 10),
            (0.80, 0.40, 0.05, 0.25, 0),
        ],
        collectible_defs=[
            (0.20, 0.30),
            (0.36, 0.75),
            (0.72, 0.20),
        ],
    ))

    # W3L03: 4 obstacles, rotations
    levels.append(make_level(3, 3, 190, 0.65, 5,
        obstacle_defs=[
            (0.26, 0.40, 0.05, 0.28, 10),
            (0.44, 0.65, 0.05, 0.25, -15),
            (0.62, 0.38, 0.05, 0.28, 10),
            (0.80, 0.62, 0.05, 0.22, -10),
        ],
        collectible_defs=[
            (0.20, 0.75),
            (0.35, 0.22),
            (0.72, 0.82),
        ],
    ))

    # W3L04: 4 obstacles, wider obstacles
    levels.append(make_level(3, 4, 195, 0.30, 5,
        obstacle_defs=[
            (0.25, 0.55, 0.055, 0.28, -10),
            (0.43, 0.35, 0.055, 0.25, 15),
            (0.61, 0.65, 0.055, 0.28, -10),
            (0.79, 0.40, 0.055, 0.25, 10),
        ],
        collectible_defs=[
            (0.18, 0.30),
            (0.34, 0.78),
            (0.70, 0.22),
        ],
    ))

    # W3L05: 5 obstacles
    levels.append(make_level(3, 5, 195, 0.70, 6,
        obstacle_defs=[
            (0.22, 0.40, 0.045, 0.25, 0),
            (0.37, 0.65, 0.045, 0.22, 10),
            (0.52, 0.38, 0.045, 0.25, -10),
            (0.67, 0.62, 0.045, 0.22, 10),
            (0.82, 0.40, 0.045, 0.22, 0),
        ],
        collectible_defs=[
            (0.18, 0.72),
            (0.30, 0.25),
            (0.60, 0.80),
        ],
    ))

    # W3L06: 5 obstacles, tighter
    levels.append(make_level(3, 6, 195, 0.40, 6,
        obstacle_defs=[
            (0.23, 0.58, 0.05, 0.28, 10),
            (0.39, 0.35, 0.05, 0.25, -10),
            (0.55, 0.62, 0.05, 0.25, 15),
            (0.71, 0.38, 0.05, 0.25, -10),
            (0.84, 0.62, 0.045, 0.22, 0),
        ],
        collectible_defs=[
            (0.18, 0.30),
            (0.32, 0.78),
            (0.63, 0.22),
        ],
    ))

    # W3L07: 5 obstacles
    levels.append(make_level(3, 7, 200, 0.75, 6,
        obstacle_defs=[
            (0.22, 0.40, 0.05, 0.28, -10),
            (0.38, 0.65, 0.05, 0.25, 15),
            (0.54, 0.35, 0.05, 0.28, -10),
            (0.70, 0.62, 0.05, 0.25, 10),
            (0.84, 0.38, 0.045, 0.22, 0),
        ],
        collectible_defs=[
            (0.18, 0.75),
            (0.30, 0.22),
            (0.62, 0.82),
        ],
    ))

    # W3L08: 5 obstacles, corridors
    levels.append(make_level(3, 8, 200, 0.30, 6,
        obstacle_defs=[
            (0.22, 0.55, 0.05, 0.30, 10),
            (0.39, 0.35, 0.05, 0.25, -15),
            (0.56, 0.65, 0.05, 0.28, 10),
            (0.73, 0.38, 0.05, 0.25, -10),
            (0.85, 0.62, 0.045, 0.22, 0),
        ],
        collectible_defs=[
            (0.18, 0.82),
            (0.32, 0.20),
            (0.65, 0.50),
        ],
    ))

    # W3L09: 5 obstacles, tight
    levels.append(make_level(3, 9, 200, 0.25, 7,
        obstacle_defs=[
            (0.22, 0.42, 0.05, 0.30, -10),
            (0.38, 0.68, 0.05, 0.25, 15),
            (0.54, 0.38, 0.05, 0.28, -10),
            (0.70, 0.62, 0.05, 0.28, 10),
            (0.84, 0.40, 0.045, 0.25, 0),
        ],
        collectible_defs=[
            (0.18, 0.78),
            (0.30, 0.22),
            (0.62, 0.85),
        ],
    ))

    # W3L10: 5 obstacles, world 3 finale
    levels.append(make_level(3, 10, 200, 0.80, 7,
        obstacle_defs=[
            (0.22, 0.45, 0.055, 0.30, 10),
            (0.38, 0.70, 0.055, 0.25, -15),
            (0.54, 0.35, 0.055, 0.28, 10),
            (0.70, 0.65, 0.055, 0.28, -10),
            (0.84, 0.40, 0.05, 0.25, 0),
        ],
        collectible_defs=[
            (0.18, 0.80),
            (0.30, 0.20),
            (0.62, 0.50),
        ],
    ))

    return levels


# ==============================================================================
# WORLD 4: STATIC — wild, precise (gravity=70, flipImpulse=42)
# ==============================================================================

def generate_world4():
    levels = []

    # W4L01: 5 obstacles
    levels.append(make_level(4, 1, 200, 0.45, 6,
        obstacle_defs=[
            (0.22, 0.40, 0.05, 0.25, 0),
            (0.37, 0.65, 0.05, 0.22, 10),
            (0.52, 0.38, 0.05, 0.25, -10),
            (0.67, 0.62, 0.05, 0.22, 10),
            (0.82, 0.40, 0.05, 0.22, 0),
        ],
        collectible_defs=[
            (0.18, 0.72),
            (0.30, 0.25),
            (0.60, 0.82),
        ],
    ))

    # W4L02: 5 obstacles, rotated
    levels.append(make_level(4, 2, 200, 0.65, 6,
        obstacle_defs=[
            (0.23, 0.58, 0.05, 0.28, -15),
            (0.39, 0.35, 0.05, 0.25, 10),
            (0.55, 0.62, 0.05, 0.25, -10),
            (0.71, 0.38, 0.05, 0.25, 15),
            (0.84, 0.60, 0.045, 0.22, -10),
        ],
        collectible_defs=[
            (0.18, 0.30),
            (0.32, 0.78),
            (0.63, 0.22),
        ],
    ))

    # W4L03: 5 obstacles, varied
    levels.append(make_level(4, 3, 200, 0.30, 6,
        obstacle_defs=[
            (0.22, 0.42, 0.05, 0.28, 10),
            (0.38, 0.65, 0.05, 0.25, -15),
            (0.54, 0.38, 0.05, 0.28, 10),
            (0.70, 0.60, 0.05, 0.22, -10),
            (0.84, 0.40, 0.045, 0.22, 10),
        ],
        collectible_defs=[
            (0.18, 0.75),
            (0.30, 0.22),
            (0.62, 0.82),
        ],
    ))

    # W4L04: 5 obstacles, tighter with rotations
    levels.append(make_level(4, 4, 205, 0.70, 6,
        obstacle_defs=[
            (0.22, 0.55, 0.055, 0.28, -10),
            (0.38, 0.35, 0.055, 0.25, 15),
            (0.54, 0.65, 0.055, 0.25, -15),
            (0.70, 0.38, 0.055, 0.25, 10),
            (0.84, 0.60, 0.05, 0.22, -10),
        ],
        collectible_defs=[
            (0.18, 0.80),
            (0.30, 0.20),
            (0.62, 0.50),
        ],
    ))

    # W4L05: 6 obstacles
    levels.append(make_level(4, 5, 205, 0.35, 6,
        obstacle_defs=[
            (0.20, 0.40, 0.045, 0.25, 10),
            (0.33, 0.65, 0.045, 0.22, -10),
            (0.46, 0.38, 0.045, 0.25, 10),
            (0.59, 0.62, 0.045, 0.22, -10),
            (0.72, 0.40, 0.045, 0.22, 10),
            (0.84, 0.60, 0.04, 0.20, 0),
        ],
        collectible_defs=[
            (0.17, 0.72),
            (0.39, 0.20),
            (0.66, 0.80),
        ],
    ))

    # W4L06: 6 obstacles, aggressive rotations
    levels.append(make_level(4, 6, 205, 0.25, 7,
        obstacle_defs=[
            (0.20, 0.55, 0.05, 0.28, -15),
            (0.34, 0.35, 0.05, 0.25, 20),
            (0.48, 0.62, 0.05, 0.25, -15),
            (0.62, 0.38, 0.05, 0.25, 20),
            (0.75, 0.62, 0.045, 0.22, -10),
            (0.85, 0.40, 0.04, 0.20, 10),
        ],
        collectible_defs=[
            (0.17, 0.80),
            (0.28, 0.20),
            (0.56, 0.82),
        ],
    ))

    # W4L07: 6 obstacles, corridors
    levels.append(make_level(4, 7, 210, 0.75, 7,
        obstacle_defs=[
            (0.20, 0.42, 0.05, 0.28, 10),
            (0.34, 0.68, 0.05, 0.25, -15),
            (0.48, 0.38, 0.05, 0.28, 10),
            (0.62, 0.62, 0.05, 0.25, -10),
            (0.75, 0.40, 0.045, 0.25, 15),
            (0.85, 0.62, 0.04, 0.22, -10),
        ],
        collectible_defs=[
            (0.17, 0.78),
            (0.28, 0.22),
            (0.56, 0.82),
        ],
    ))

    # W4L08: 6 obstacles, expert corridors
    levels.append(make_level(4, 8, 210, 0.30, 7,
        obstacle_defs=[
            (0.20, 0.55, 0.05, 0.30, -15),
            (0.34, 0.35, 0.05, 0.25, 20),
            (0.48, 0.65, 0.05, 0.28, -15),
            (0.62, 0.38, 0.05, 0.25, 15),
            (0.75, 0.62, 0.045, 0.25, -10),
            (0.85, 0.40, 0.04, 0.22, 10),
        ],
        collectible_defs=[
            (0.17, 0.82),
            (0.28, 0.20),
            (0.54, 0.48),
        ],
    ))

    # W4L09: 6 obstacles, near-expert
    levels.append(make_level(4, 9, 210, 0.80, 7,
        obstacle_defs=[
            (0.20, 0.42, 0.055, 0.28, 10),
            (0.34, 0.68, 0.055, 0.25, -20),
            (0.48, 0.38, 0.055, 0.28, 15),
            (0.62, 0.62, 0.055, 0.25, -10),
            (0.75, 0.40, 0.05, 0.25, 15),
            (0.85, 0.60, 0.04, 0.22, -10),
        ],
        collectible_defs=[
            (0.17, 0.80),
            (0.28, 0.22),
            (0.56, 0.85),
        ],
    ))

    # W4L10: 7 obstacles, THE ULTIMATE CHALLENGE
    levels.append(make_level(4, 10, 215, 0.20, 8,
        obstacle_defs=[
            (0.18, 0.45, 0.045, 0.25, -10),
            (0.30, 0.68, 0.045, 0.22, 15),
            (0.42, 0.38, 0.045, 0.25, -10),
            (0.54, 0.62, 0.045, 0.22, 15),
            (0.66, 0.40, 0.045, 0.25, -10),
            (0.78, 0.62, 0.04, 0.22, 10),
            (0.86, 0.40, 0.035, 0.20, -10),
        ],
        collectible_defs=[
            (0.16, 0.78),
            (0.36, 0.22),
            (0.60, 0.82),
        ],
    ))

    return levels


# ==============================================================================
# Main: Generate, Validate, Write
# ==============================================================================

def main():
    all_worlds = {
        1: generate_world1(),
        2: generate_world2(),
        3: generate_world3(),
        4: generate_world4(),
    }

    total = 0
    total_passed = 0
    total_failed = 0

    print("=" * 80)
    print("FREEFALL LEVEL GENERATION & VALIDATION REPORT")
    print("=" * 80)
    print()

    for world_id in sorted(all_worlds.keys()):
        levels = all_worlds[world_id]
        world_names = {1: "THE BLOCK", 2: "NEON YARD", 3: "UNDERGROUND", 4: "STATIC"}
        print(f"--- World {world_id}: {world_names[world_id]} ---")
        print(f"{'Level':<8} {'Obs':>4} {'Velocity':>9} {'Goal Y':>7} {'MinGap':>8} {'ParFlips':>9} {'ParTime':>8} {'Status':>8}")
        print("-" * 65)

        for level_data in levels:
            level_id = level_data["levelId"]
            game_obs = [o for o in level_data["obstacles"] if o["id"] not in ("top-bar", "bot-bar")]
            obs_count = len(game_obs)
            vel = level_data["launchVelocity"]["dx"]
            goal_y = level_data["goalPosition"]["y"]
            par_flips = level_data["parFlips"]
            par_time = level_data["parTime"]

            passed, min_gap, messages = validate_level(level_data, world_id, level_id)

            status = "PASS" if passed else "FAIL"
            total += 1
            if passed:
                total_passed += 1
            else:
                total_failed += 1

            print(f"W{world_id}L{level_id:02d}   {obs_count:>4} {vel:>9} {goal_y:>7.2f} {min_gap:>8.4f} {par_flips:>9} {par_time:>8.1f} {status:>8}")

            for msg in messages:
                print(msg)

            # Write JSON file
            world_dir = os.path.join(LEVELS_BASE, f"world{world_id}")
            os.makedirs(world_dir, exist_ok=True)
            filename = f"w{world_id}l{level_id:02d}.json"
            filepath = os.path.join(world_dir, filename)
            with open(filepath, "w") as f:
                json.dump(level_data, f, indent=2)
                f.write("\n")

        print()

    print("=" * 80)
    print(f"SUMMARY: {total} levels generated, {total_passed} PASSED, {total_failed} FAILED")
    print(f"Files written to: {LEVELS_BASE}")
    print("=" * 80)

    if total_failed > 0:
        print("\nWARNING: Some levels failed validation. Review the FAIL messages above.")
        sys.exit(1)
    else:
        print("\nAll levels passed validation successfully.")


if __name__ == "__main__":
    main()
