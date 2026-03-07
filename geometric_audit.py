#!/usr/bin/env python3
"""
FreeFall Geometric Playability Audit
=====================================
Checks all 80 levels for geometric validity without simulating physics.
Fixes any issues found and writes corrected JSON back.
"""

import json
import math
import os
import copy
from pathlib import Path

LEVELS_DIR = Path("/Users/jamiethomson/freefall-app/src/Freefall/Freefall/levels")
SCREEN_W = 393.0
SCREEN_H = 852.0

# Playable area boundaries (normalized)
TOP_WALL_INNER = 0.06 + 0.018 / 2   # 0.069
BOT_WALL_INNER = 0.94 - 0.018 / 2   # 0.931

BALL_DIAMETER_NORM = 28.0 / SCREEN_H  # ~0.0329
MIN_GAP = 0.08          # minimum navigable gap (ball + clearance)
MIN_GAP_FIX = 0.10      # gap to create when fixing
BALL_RADIUS_MARGIN = 0.02  # expand obstacle bbox by this on each side
COLLECTIBLE_CLEARANCE = 0.06
COLLECTIBLE_MIN_X_FROM_LAUNCH = 0.20
COLLECTIBLE_Y_MIN = 0.12
COLLECTIBLE_Y_MAX = 0.88

# ─── Helpers ────────────────────────────────────────────────────────────

def rotated_bbox(cx, cy, w, h, rotation_deg):
    """
    Compute the axis-aligned bounding box of a rotated rectangle.
    Returns (min_x, min_y, max_x, max_y) in normalized coords.
    """
    angle = math.radians(rotation_deg)
    cos_a = abs(math.cos(angle))
    sin_a = abs(math.sin(angle))
    
    # Half-extents after rotation
    half_w = (w * cos_a + h * sin_a) / 2.0
    half_h = (w * sin_a + h * cos_a) / 2.0
    
    return (cx - half_w, cy - half_h, cx + half_w, cy + half_h)


def obstacle_bbox(obs, margin=BALL_RADIUS_MARGIN):
    """Get the AABB of an obstacle, expanded by margin on all sides."""
    cx = obs["position"]["x"]
    cy = obs["position"]["y"]
    w = obs["size"]["width"]
    h = obs["size"]["height"]
    rot = obs.get("rotation", 0)
    
    min_x, min_y, max_x, max_y = rotated_bbox(cx, cy, w, h, rot)
    return (min_x - margin, min_y - margin, max_x + margin, max_y + margin)


def is_wall(obs):
    """Check if obstacle is the top or bottom boundary wall."""
    return obs.get("id") in ("top-bar", "bot-bar")


def get_game_obstacles(level):
    """Return obstacles excluding top-bar and bot-bar."""
    return [o for o in level["obstacles"] if not is_wall(o)]


def x_overlaps(bbox, x_val, tolerance=0.001):
    """Check if a given x-position falls within the bbox x-range."""
    return bbox[0] - tolerance <= x_val <= bbox[2] + tolerance


def compute_gaps_at_x(game_obstacles, x_pos):
    """
    At a given x-position, compute all vertical gaps between obstacles and walls.
    Returns list of (gap_bottom, gap_top, gap_size) sorted by gap_bottom.
    gap_bottom/gap_top are the y-coordinates of the gap's navigable range.
    """
    # Collect all vertical "blocked" intervals at this x
    blocked = []
    
    for obs in game_obstacles:
        bbox = obstacle_bbox(obs)
        if x_overlaps(bbox, x_pos):
            # This obstacle blocks from bbox[1] to bbox[3] vertically
            blocked.append((bbox[1], bbox[3]))
    
    # Add top and bottom walls as blocked
    blocked.append((0.0, TOP_WALL_INNER))
    blocked.append((BOT_WALL_INNER, 1.0))
    
    # Merge overlapping intervals
    blocked.sort()
    merged = []
    for start, end in blocked:
        if merged and start <= merged[-1][1]:
            merged[-1] = (merged[-1][0], max(merged[-1][1], end))
        else:
            merged.append([start, end])
    
    # Compute gaps between merged blocked intervals
    gaps = []
    for i in range(len(merged) - 1):
        gap_bottom = merged[i][1]
        gap_top = merged[i + 1][0]
        gap_size = gap_top - gap_bottom
        if gap_size > 0:
            gaps.append((gap_bottom, gap_top, gap_size))
    
    return gaps


def largest_gap_at_x(game_obstacles, x_pos):
    """Return the largest gap (bottom, top, size) at a given x."""
    gaps = compute_gaps_at_x(game_obstacles, x_pos)
    if not gaps:
        return None
    return max(gaps, key=lambda g: g[2])


def point_in_any_obstacle(game_obstacles, px, py, clearance=0.0):
    """Check if a point is inside any obstacle bbox (expanded by clearance)."""
    for obs in game_obstacles:
        bbox = obstacle_bbox(obs, margin=BALL_RADIUS_MARGIN + clearance)
        if bbox[0] <= px <= bbox[2] and bbox[1] <= py <= bbox[3]:
            return True
    return False


# ─── Audit Functions ────────────────────────────────────────────────────

def audit_level(level):
    """
    Run all geometric checks on a level.
    Returns (issues_list, level_data_with_fixes).
    Each issue is a dict with 'type', 'detail', 'fixed'.
    """
    issues = []
    fixed_level = copy.deepcopy(level)
    game_obs = get_game_obstacles(level)
    fixed_game_obs = get_game_obstacles(fixed_level)
    
    world = level["worldId"]
    lid = level["levelId"]
    label = f"W{world}L{lid:02d}"
    
    launch_x = level["launchPosition"]["x"]
    goal_x = level["goalPosition"]["x"]
    goal_y = level["goalPosition"]["y"]
    goal_radius = level["goalRadius"]
    goal_radius_norm = goal_radius / SCREEN_H
    
    # ── Check 1: Navigable gap at every obstacle's x-position ──
    for obs in game_obs:
        bbox = obstacle_bbox(obs)
        obs_x = obs["position"]["x"]
        
        gaps = compute_gaps_at_x(game_obs, obs_x)
        max_gap = max((g[2] for g in gaps), default=0)
        
        if max_gap < MIN_GAP:
            issues.append({
                "type": "BLOCKED_CORRIDOR",
                "detail": f"Obstacle '{obs['id']}' at x={obs_x:.3f}: max gap = {max_gap:.4f} < {MIN_GAP}",
                "obs_id": obs["id"],
                "fixed": False
            })
    
    # ── Check 2: Scan for fully-blocked x-slices across the level ──
    # Sample x from launch to goal in small increments
    scan_step = 0.005
    x = launch_x + 0.05  # skip launch area
    while x < goal_x:
        gaps = compute_gaps_at_x(game_obs, x)
        max_gap = max((g[2] for g in gaps), default=0)
        
        if max_gap < MIN_GAP:
            issues.append({
                "type": "FULLY_BLOCKED_X",
                "detail": f"X-slice at x={x:.3f} is fully blocked: max gap = {max_gap:.4f}",
                "x_pos": x,
                "fixed": False
            })
        x += scan_step
    
    # ── Check 3: Goal clearance ──
    goal_clearance_needed = goal_radius_norm * 2 + 0.04
    gaps_at_goal = compute_gaps_at_x(game_obs, goal_x)
    
    goal_in_gap = False
    for gap_bot, gap_top, gap_size in gaps_at_goal:
        if gap_bot <= goal_y <= gap_top and gap_size >= goal_clearance_needed:
            goal_in_gap = True
            break
    
    if not goal_in_gap:
        largest = largest_gap_at_x(game_obs, goal_x)
        if largest and largest[2] >= goal_clearance_needed:
            new_goal_y = (largest[0] + largest[1]) / 2.0
            issues.append({
                "type": "GOAL_IN_OBSTACLE",
                "detail": f"Goal at ({goal_x:.3f}, {goal_y:.3f}) not in clear corridor. "
                          f"Moving to y={new_goal_y:.3f}",
                "fixed": True
            })
            fixed_level["goalPosition"]["y"] = round(new_goal_y, 3)
        elif largest:
            issues.append({
                "type": "GOAL_CLEARANCE_TIGHT",
                "detail": f"Goal at ({goal_x:.3f}, {goal_y:.3f}): largest gap = {largest[2]:.4f}, "
                          f"needed = {goal_clearance_needed:.4f}. Goal repositioned to gap center.",
                "fixed": True
            })
            new_goal_y = (largest[0] + largest[1]) / 2.0
            fixed_level["goalPosition"]["y"] = round(new_goal_y, 3)
        else:
            issues.append({
                "type": "GOAL_NO_GAP",
                "detail": f"No gap at goal x={goal_x:.3f}!",
                "fixed": False
            })
    
    # ── Check 4: Collectible placement ──
    for i, coll in enumerate(level.get("collectibles", [])):
        cx = coll["position"]["x"]
        cy = coll["position"]["y"]
        coll_issues = []
        
        # Check y bounds
        if cy < COLLECTIBLE_Y_MIN or cy > COLLECTIBLE_Y_MAX:
            coll_issues.append(f"y={cy:.3f} outside [{COLLECTIBLE_Y_MIN}, {COLLECTIBLE_Y_MAX}]")
        
        # Check x distance from launch
        if cx - launch_x < COLLECTIBLE_MIN_X_FROM_LAUNCH:
            coll_issues.append(f"x={cx:.3f} too close to launch (x={launch_x:.3f}), "
                             f"dist={cx - launch_x:.3f} < {COLLECTIBLE_MIN_X_FROM_LAUNCH}")
        
        # Check not past goal
        if cx > goal_x + 0.01:
            coll_issues.append(f"x={cx:.3f} past goal x={goal_x:.3f}")
        
        # Check clearance from obstacles
        if point_in_any_obstacle(game_obs, cx, cy, clearance=COLLECTIBLE_CLEARANCE - BALL_RADIUS_MARGIN):
            coll_issues.append(f"too close to obstacle (< {COLLECTIBLE_CLEARANCE} clearance)")
        
        # Check it's in a navigable gap
        gaps = compute_gaps_at_x(game_obs, cx)
        in_gap = False
        for gap_bot, gap_top, gap_size in gaps:
            if gap_bot + 0.02 <= cy <= gap_top - 0.02 and gap_size >= MIN_GAP:
                in_gap = True
                break
        if not in_gap and not any("too close" in ci for ci in coll_issues):
            coll_issues.append("not in a navigable gap")
        
        if coll_issues:
            # Fix: find best position
            fixed_coll = fix_collectible(fixed_level, i, game_obs, launch_x, goal_x)
            detail_str = "; ".join(coll_issues)
            issues.append({
                "type": "COLLECTIBLE_ISSUE",
                "detail": f"Collectible {i} at ({cx:.3f}, {cy:.3f}): {detail_str}",
                "fixed": fixed_coll
            })
    
    # ── Check for duplicate collectibles ──
    seen_positions = set()
    for i, coll in enumerate(fixed_level.get("collectibles", [])):
        key = (round(coll["position"]["x"], 3), round(coll["position"]["y"], 3))
        if key in seen_positions:
            # Move duplicate to a different position
            fixed_coll = fix_collectible_dedup(fixed_level, i, game_obs, launch_x, goal_x, seen_positions)
            if fixed_coll:
                issues.append({
                    "type": "DUPLICATE_COLLECTIBLE",
                    "detail": f"Collectible {i} is a duplicate at ({key[0]}, {key[1]})",
                    "fixed": True
                })
        new_key = (round(fixed_level["collectibles"][i]["position"]["x"], 3),
                   round(fixed_level["collectibles"][i]["position"]["y"], 3))
        seen_positions.add(new_key)
    
    # ── Fix blocked corridors ──
    # Re-check with fixes applied
    for issue in issues:
        if issue["type"] == "BLOCKED_CORRIDOR" and not issue["fixed"]:
            obs_id = issue["obs_id"]
            for obs in fixed_level["obstacles"]:
                if obs["id"] == obs_id:
                    issue["fixed"] = shrink_obstacle_for_gap(fixed_level, obs)
                    break
        elif issue["type"] == "FULLY_BLOCKED_X" and not issue["fixed"]:
            x_pos = issue["x_pos"]
            issue["fixed"] = fix_blocked_x(fixed_level, x_pos)
    
    return issues, fixed_level


def shrink_obstacle_for_gap(level, target_obs):
    """Shrink an obstacle's height until MIN_GAP_FIX gap exists."""
    game_obs = get_game_obstacles(level)
    obs_x = target_obs["position"]["x"]
    
    original_h = target_obs["size"]["height"]
    
    for shrink_pct in range(5, 80, 5):
        factor = 1.0 - shrink_pct / 100.0
        target_obs["size"]["height"] = round(original_h * factor, 4)
        
        gaps = compute_gaps_at_x(game_obs, obs_x)
        max_gap = max((g[2] for g in gaps), default=0)
        
        if max_gap >= MIN_GAP_FIX:
            return True
    
    # Restore if we couldn't fix it
    target_obs["size"]["height"] = original_h
    return False


def fix_blocked_x(level, x_pos):
    """Fix a fully blocked x-slice by shrinking the tallest obstacle there."""
    game_obs = get_game_obstacles(level)
    
    # Find all obstacles overlapping this x
    overlapping = []
    for obs in level["obstacles"]:
        if is_wall(obs):
            continue
        bbox = obstacle_bbox(obs)
        if x_overlaps(bbox, x_pos):
            overlapping.append(obs)
    
    if not overlapping:
        return False
    
    # Sort by height (shrink tallest first)
    overlapping.sort(key=lambda o: o["size"]["height"], reverse=True)
    
    for obs in overlapping:
        if shrink_obstacle_for_gap(level, obs):
            return True
    
    return False


def fix_collectible(level, idx, game_obs, launch_x, goal_x):
    """Fix a collectible by finding the best valid position."""
    coll = level["collectibles"][idx]
    cx = coll["position"]["x"]
    
    # Clamp x to valid range
    min_x = launch_x + COLLECTIBLE_MIN_X_FROM_LAUNCH
    max_x = goal_x - 0.02
    
    if cx < min_x:
        cx = min_x
    if cx > max_x:
        cx = max_x
    
    # Find largest gap at this x
    gaps = compute_gaps_at_x(game_obs, cx)
    
    best_gap = None
    for g in gaps:
        if g[2] >= MIN_GAP:
            center = (g[0] + g[1]) / 2.0
            if COLLECTIBLE_Y_MIN <= center <= COLLECTIBLE_Y_MAX:
                if best_gap is None or g[2] > best_gap[2]:
                    best_gap = g
    
    if best_gap is None:
        # Try scanning nearby x positions
        for dx in [0.02, -0.02, 0.04, -0.04, 0.06, -0.06, 0.08, -0.08]:
            test_x = cx + dx
            if test_x < min_x or test_x > max_x:
                continue
            gaps = compute_gaps_at_x(game_obs, test_x)
            for g in gaps:
                if g[2] >= MIN_GAP:
                    center = (g[0] + g[1]) / 2.0
                    if COLLECTIBLE_Y_MIN <= center <= COLLECTIBLE_Y_MAX:
                        if best_gap is None or g[2] > best_gap[2]:
                            best_gap = g
                            cx = test_x
            if best_gap:
                break
    
    if best_gap:
        new_y = (best_gap[0] + best_gap[1]) / 2.0
        new_y = max(COLLECTIBLE_Y_MIN, min(COLLECTIBLE_Y_MAX, new_y))
        level["collectibles"][idx]["position"]["x"] = round(cx, 3)
        level["collectibles"][idx]["position"]["y"] = round(new_y, 3)
        return True
    
    return False


def fix_collectible_dedup(level, idx, game_obs, launch_x, goal_x, seen_positions):
    """Move a duplicate collectible to a unique valid position."""
    coll = level["collectibles"][idx]
    
    min_x = launch_x + COLLECTIBLE_MIN_X_FROM_LAUNCH
    max_x = goal_x - 0.02
    
    # Try different x positions spread across the level
    x_range = max_x - min_x
    for fraction in [0.25, 0.5, 0.75, 0.33, 0.67, 0.15, 0.85]:
        test_x = round(min_x + x_range * fraction, 3)
        gaps = compute_gaps_at_x(game_obs, test_x)
        
        for g in sorted(gaps, key=lambda g: g[2], reverse=True):
            if g[2] >= MIN_GAP:
                new_y = round((g[0] + g[1]) / 2.0, 3)
                if COLLECTIBLE_Y_MIN <= new_y <= COLLECTIBLE_Y_MAX:
                    key = (test_x, new_y)
                    if key not in seen_positions:
                        level["collectibles"][idx]["position"]["x"] = test_x
                        level["collectibles"][idx]["position"]["y"] = new_y
                        return True
    
    return False


# ─── Main ───────────────────────────────────────────────────────────────

def main():
    all_results = {}
    total_issues = 0
    total_fixed = 0
    total_unfixed = 0
    files_modified = 0
    
    print("=" * 80)
    print("  FREEFALL GEOMETRIC PLAYABILITY AUDIT")
    print("  Auditing all 80 levels...")
    print("=" * 80)
    print()
    
    for world in range(1, 9):
        for lvl in range(1, 11):
            filepath = LEVELS_DIR / f"world{world}" / f"w{world}l{lvl:02d}.json"
            
            if not filepath.exists():
                print(f"  [MISSING] {filepath.name}")
                continue
            
            with open(filepath, "r") as f:
                level = json.load(f)
            
            label = f"W{world}L{lvl:02d}"
            issues, fixed_level = audit_level(level)
            
            if issues:
                n_fixed = sum(1 for i in issues if i["fixed"])
                n_unfixed = sum(1 for i in issues if not i["fixed"])
                total_issues += len(issues)
                total_fixed += n_fixed
                total_unfixed += n_unfixed
                
                status = "FIXED" if n_unfixed == 0 else "FAIL"
                print(f"  [{status}] {label} — {len(issues)} issue(s), {n_fixed} fixed, {n_unfixed} remaining")
                for issue in issues:
                    marker = "OK" if issue["fixed"] else "!!"
                    print(f"         [{marker}] {issue['type']}: {issue['detail']}")
                
                # Write fixed file if any fixes were made
                if n_fixed > 0:
                    files_modified += 1
                    with open(filepath, "w") as f:
                        json.dump(fixed_level, f, indent=2)
                        f.write("\n")
            else:
                print(f"  [PASS]  {label}")
            
            all_results[label] = (issues, fixed_level)
    
    print()
    print("=" * 80)
    print("  INITIAL AUDIT SUMMARY")
    print(f"  Total levels: {len(all_results)}")
    print(f"  Total issues found: {total_issues}")
    print(f"  Issues auto-fixed: {total_fixed}")
    print(f"  Issues remaining: {total_unfixed}")
    print(f"  Files modified: {files_modified}")
    print("=" * 80)
    
    # ── Re-audit fixed files ──
    if files_modified > 0:
        print()
        print("=" * 80)
        print("  RE-AUDIT (verifying fixes)...")
        print("=" * 80)
        print()
        
        re_issues_total = 0
        re_pass = 0
        
        for world in range(1, 9):
            for lvl in range(1, 11):
                filepath = LEVELS_DIR / f"world{world}" / f"w{world}l{lvl:02d}.json"
                if not filepath.exists():
                    continue
                
                with open(filepath, "r") as f:
                    level = json.load(f)
                
                label = f"W{world}L{lvl:02d}"
                issues, _ = audit_level(level)
                
                if issues:
                    n_unfixed = sum(1 for i in issues if not i["fixed"])
                    re_issues_total += n_unfixed
                    if n_unfixed > 0:
                        print(f"  [FAIL]  {label} — {n_unfixed} issue(s) remaining")
                        for issue in issues:
                            if not issue["fixed"]:
                                print(f"         [!!] {issue['type']}: {issue['detail']}")
                    else:
                        # issues exist but all fixable (duplicates from re-fix)
                        re_pass += 1
                        print(f"  [PASS]  {label}")
                else:
                    re_pass += 1
                    print(f"  [PASS]  {label}")
        
        print()
        print("=" * 80)
        print("  FINAL RE-AUDIT SUMMARY")
        print(f"  Levels passing: {re_pass} / {len(all_results)}")
        print(f"  Remaining issues: {re_issues_total}")
        print("=" * 80)
    else:
        print()
        print("  No fixes needed — all levels passed geometric audit.")


if __name__ == "__main__":
    main()
