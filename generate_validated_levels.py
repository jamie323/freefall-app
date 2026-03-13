#!/usr/bin/env python3
"""
FreeFall Level Generator v4 — Physics-Validated
Generates all 80 levels (8 worlds × 10 levels) with progressive difficulty.
Every level is validated against the frame-perfect AND human-playability sims.
"""
import json, math, os, random, copy

# ── Constants (match audit_levels_v3.py) ─────────────────────────────
SCREEN_W = 393.0
SCREEN_H = 852.0
BALL_RADIUS = 10.0
DT = 1.0 / 60.0
COLLECTIBLE_RADIUS = 25.0
OOB_MARGIN = 50.0
MAX_FRONTIER = 3000
MAX_FRAMES = 1200
Y_MERGE = 2.0
VY_MERGE = 3.0
MIN_FLIP_INTERVAL = 8

WORLD_PHYSICS = {
    1: {"grav": 38,  "imp": 30, "maxV": 125, "damp": 0.025},  # Floaty — slow, wide arcs
    2: {"grav": 72,  "imp": 52, "maxV": 190, "damp": 0.006},  # Snappy — fast reactions
    3: {"grav": 85,  "imp": 28, "maxV": 115, "damp": 0.04},   # Heavy — high drag, weak flip
    4: {"grav": 68,  "imp": 44, "maxV": 210, "damp": 0.004},  # Wild — low drag, fast
    5: {"grav": 32,  "imp": 26, "maxV": 240, "damp": 0.0},    # Slippery — no friction
    6: {"grav": 105, "imp": 65, "maxV": 105, "damp": 0.05},   # Explosive — huge gravity
    7: {"grav": 55,  "imp": 36, "maxV": 165, "damp": 0.015},  # Inverted — medium
    8: {"grav": 95,  "imp": 48, "maxV": 250, "damp": 0.002},  # Brutal — fast, unforgiving
}

LEVELS_DIR = "/Users/jamiethomson/freefall-app/src/Freefall/Freefall/levels"

# World 7 starts with gravity UP
WORLD_GRAVITY_UP = {7}

# ── Simulation (copied from audit_levels_v3.py) ─────────────────────
class Obs:
    __slots__ = ["cx","cy","hw","hh","cr","sr"]
    def __init__(s, cx, cy, hw, hh, cr, sr):
        s.cx=cx; s.cy=cy; s.hw=hw; s.hh=hh; s.cr=cr; s.sr=sr

def build_lv(data):
    """Build a simulation-ready level dict from raw JSON data."""
    obs = []
    for o in data.get("obstacles", []):
        cx = o["position"]["x"] * SCREEN_W; cy = o["position"]["y"] * SCREEN_H
        hw = (o["size"]["width"] * SCREEN_W) / 2.0; hh = (o["size"]["height"] * SCREEN_H) / 2.0
        rr = math.radians(-o.get("rotation", 0.0))
        obs.append(Obs(cx, cy, hw, hh, math.cos(rr), math.sin(rr)))
    cols = [(c["position"]["x"]*SCREEN_W, c["position"]["y"]*SCREEN_H) for c in data.get("collectibles",[])]
    return {"w":data["worldId"],"l":data["levelId"],
            "lx":data["launchPosition"]["x"]*SCREEN_W,"ly":data["launchPosition"]["y"]*SCREEN_H,
            "dx":data["launchVelocity"]["dx"],"dy":data["launchVelocity"].get("dy",0.0),
            "gx":data["goalPosition"]["x"]*SCREEN_W,"gy":data["goalPosition"]["y"]*SCREEN_H,
            "gr":data["goalRadius"],"gd":data.get("initialGravityDown",True),
            "obs":obs,"cols":cols,"raw":data}

def simulate(lv):
    ph = WORLD_PHYSICS[lv["w"]]
    grav=ph["grav"]; imp=ph["imp"]; maxV=ph["maxV"]; damp=ph["damp"]
    obs=lv["obs"]; cols=lv["cols"]; nc=len(cols)
    gx=lv["gx"]; gy=lv["gy"]; grsq=lv["gr"]**2; br=BALL_RADIUS
    crsq=COLLECTIBLE_RADIUS**2
    frontier = [(lv["ly"], lv["dy"], lv["gd"], 0)]
    x = lv["lx"]; dx_v = lv["dx"]
    completable = False; goal_masks = set(); ever = 0
    for frame in range(MAX_FRAMES):
        if not frontier: break
        nm = {}
        for sy, svy, sgd, sc in frontier:
            for df in (False, True):
                vy=svy; gd=sgd
                if df:
                    gd = not gd; vy = -vy*0.3 + (-imp if gd else imp)
                vy *= (1.0-damp)
                if vy > maxV: vy = maxV
                elif vy < -maxV: vy = -maxV
                g_dy = -grav if gd else grav
                vy += g_dy * DT
                nx = x + dx_v * DT; ny = sy + vy * DT
                if ny < -OOB_MARGIN or ny > SCREEN_H+OOB_MARGIN: continue
                if nx < -OOB_MARGIN or nx > SCREEN_W+OOB_MARGIN: continue
                hit = False
                for o in obs:
                    lxx=(nx-o.cx)*o.cr+(ny-o.cy)*o.sr
                    lyy=-(nx-o.cx)*o.sr+(ny-o.cy)*o.cr
                    if abs(lxx)<=o.hw+br and abs(lyy)<=o.hh+br:
                        hit=True; break
                if hit: continue
                ncc = sc
                for ci in range(nc):
                    bit=1<<ci
                    if ncc&bit: continue
                    ddx=nx-cols[ci][0]; ddy=ny-cols[ci][1]
                    if ddx*ddx+ddy*ddy<=crsq: ncc|=bit
                ever |= ncc
                ddx=nx-gx; ddy=ny-gy
                if ddx*ddx+ddy*ddy<=grsq:
                    completable=True; goal_masks.add(ncc)
                yb=round(ny/Y_MERGE); vb=round(vy/VY_MERGE)
                key=(yb,vb,gd,ncc)
                if key not in nm: nm[key]=(ny,vy,gd,ncc)
                else:
                    ex=nm[key]
                    if ex[3]!=ncc and bin(ncc).count("1")>bin(ex[3]).count("1"):
                        nm[key]=(ny,vy,gd,ncc)
        frontier = list(nm.values())
        if len(frontier) > MAX_FRONTIER:
            frontier.sort(key=lambda s: (-bin(s[3]).count("1"), abs(s[0]-gy)))
            frontier = frontier[:MAX_FRONTIER]
        x += dx_v * DT
        if x > SCREEN_W + OOB_MARGIN: break
    cog = set()
    for m in goal_masks:
        for i in range(nc):
            if m & (1<<i): cog.add(i)
    ce = set()
    for i in range(nc):
        if ever & (1<<i): ce.add(i)
    return {"comp":completable,"cog":cog,"ce":ce,"nc":nc,"gm":goal_masks}

def simulate_human(lv, flip_interval=MIN_FLIP_INTERVAL):
    ph = WORLD_PHYSICS[lv["w"]]
    grav=ph["grav"]; imp=ph["imp"]; maxV=ph["maxV"]; damp=ph["damp"]
    obs=lv["obs"]; cols=lv["cols"]; nc=len(cols)
    gx=lv["gx"]; gy=lv["gy"]; grsq=lv["gr"]**2; br=BALL_RADIUS
    crsq=COLLECTIBLE_RADIUS**2
    frontier = [(lv["ly"], lv["dy"], lv["gd"], 0, flip_interval)]
    x = lv["lx"]; dx_v = lv["dx"]
    completable = False; goal_masks = set(); ever = 0
    for frame in range(MAX_FRAMES):
        if not frontier: break
        nm = {}
        for sy, svy, sgd, sc, sf in frontier:
            can_flip = sf >= flip_interval
            options = [False]
            if can_flip: options.append(True)
            for df in options:
                vy=svy; gd=sgd; nsf = sf + 1
                if df:
                    gd = not gd; vy = -vy*0.3 + (-imp if gd else imp)
                    nsf = 0
                vy *= (1.0-damp)
                if vy > maxV: vy = maxV
                elif vy < -maxV: vy = -maxV
                g_dy = -grav if gd else grav
                vy += g_dy * DT
                nx = x + dx_v * DT; ny = sy + vy * DT
                if ny < -OOB_MARGIN or ny > SCREEN_H+OOB_MARGIN: continue
                if nx < -OOB_MARGIN or nx > SCREEN_W+OOB_MARGIN: continue
                hit = False
                for o in obs:
                    lxx=(nx-o.cx)*o.cr+(ny-o.cy)*o.sr
                    lyy=-(nx-o.cx)*o.sr+(ny-o.cy)*o.cr
                    if abs(lxx)<=o.hw+br and abs(lyy)<=o.hh+br:
                        hit=True; break
                if hit: continue
                ncc = sc
                for ci in range(nc):
                    bit=1<<ci
                    if ncc&bit: continue
                    ddx=nx-cols[ci][0]; ddy=ny-cols[ci][1]
                    if ddx*ddx+ddy*ddy<=crsq: ncc|=bit
                ever |= ncc
                ddx=nx-gx; ddy=ny-gy
                if ddx*ddx+ddy*ddy<=grsq:
                    completable=True; goal_masks.add(ncc)
                sf_capped = min(nsf, flip_interval)
                yb=round(ny/Y_MERGE); vb=round(vy/VY_MERGE)
                key=(yb,vb,gd,ncc,sf_capped)
                if key not in nm: nm[key]=(ny,vy,gd,ncc,nsf)
                else:
                    ex=nm[key]
                    if ex[3]!=ncc and bin(ncc).count("1")>bin(ex[3]).count("1"):
                        nm[key]=(ny,vy,gd,ncc,nsf)
        frontier = list(nm.values())
        if len(frontier) > MAX_FRONTIER:
            frontier.sort(key=lambda s: (-bin(s[3]).count("1"), abs(s[0]-gy)))
            frontier = frontier[:MAX_FRONTIER]
        x += dx_v * DT
        if x > SCREEN_W + OOB_MARGIN: break
    cog = set()
    for m in goal_masks:
        for i in range(nc):
            if m & (1<<i): cog.add(i)
    ce = set()
    for i in range(nc):
        if ever & (1<<i): ce.add(i)
    return {"comp":completable,"cog":cog,"ce":ce,"nc":nc,"gm":goal_masks}

def validate_level(data):
    """Returns True if level passes both frame-perfect and human sims."""
    lv = build_lv(data)
    r = simulate(lv)
    if not r["comp"] or len(r["cog"]) != r["nc"]:
        return False
    rh = simulate_human(lv)
    if not rh["comp"] or len(rh["cog"]) != rh["nc"]:
        return False
    return True

# ── Difficulty Curves ────────────────────────────────────────────────
def lerp(a, b, t):
    return a + (b - a) * t

def get_params(world, level):
    """Compute generation parameters from difficulty.

    AGGRESSIVE ramp: by L3 the player needs multiple attempts.
    L1 is intro, L2 adds challenge, L3+ is real difficulty.
    """
    lt = (level - 1) / 9.0   # 0..1 within world
    wt = (world - 1) / 7.0   # 0..1 across worlds

    # Combined t for obstacle sizes, rotation (level-weighted)
    t = wt * 0.4 + lt * 0.6

    # ── Obstacle count: STEEP ramp ──
    # W1: L1=1, L2=2, L3=3, L4=4, L5=5, L6+=5
    # W8: L1=3, L2=4, L3=5, L4=6, L5+=6
    base_obs = 1 + int(wt * 2)                    # 1 for W1, 3 for W8
    level_obs = min(4, max(0, level - 1))          # L1=0, L2=1, L3=2, L4=3, L5=4
    num_obs = min(6, base_obs + level_obs)

    # ── Obstacle sizes: BIGGER — actually block the path ──
    obs_h_min = lerp(0.065, 0.090, t)
    obs_h_max = lerp(0.095, 0.150, t)
    obs_w_min = lerp(0.045, 0.065, t)
    obs_w_max = lerp(0.070, 0.095, t)

    # ── Rotation range (degrees) ──
    rot_max = lerp(0, 22, t)

    # ── Launch velocity: faster baseline ──
    base_vel = lerp(110, 150, wt)
    level_vel = lerp(0, 70, lt)
    max_vel = lerp(165, 220, wt)
    velocity = min(max_vel, base_vel + level_vel)

    # ── Goal radius: shrinks faster ──
    base_radius = lerp(40, 32, wt)
    level_shrink = lerp(0, 14, lt)
    goal_radius = max(22, base_radius - level_shrink)

    # Playable y range (where obstacles can appear)
    y_min = 0.18
    y_max = 0.82

    # Par flips & time
    par_flips = max(2, int(2 + t * 8))
    par_time = lerp(4.0, 1.8, t)

    return {
        "num_obs": num_obs,
        "obs_h_min": obs_h_min, "obs_h_max": obs_h_max,
        "obs_w_min": obs_w_min, "obs_w_max": obs_w_max,
        "rot_max": rot_max,
        "velocity": velocity,
        "goal_radius": goal_radius,
        "y_min": y_min, "y_max": y_max,
        "par_flips": par_flips, "par_time": par_time,
    }

# ── Level Generation ─────────────────────────────────────────────────
def generate_level(world, level, max_attempts=80):
    """Generate a level that passes both sims. Retries with random layouts."""
    params = get_params(world, level)
    grav_down = world not in WORLD_GRAVITY_UP

    for attempt in range(max_attempts):
        data = _try_generate(world, level, params, grav_down, attempt)
        if data and validate_level(data):
            return data

    # If we can't generate after max_attempts, relax constraints progressively
    for relax in range(6):
        relaxed = dict(params)
        relaxed["obs_h_max"] *= (0.85 ** (relax + 1))
        relaxed["obs_h_min"] *= (0.85 ** (relax + 1))
        relaxed["velocity"] *= (0.95 ** (relax + 1))
        relaxed["num_obs"] = max(1, relaxed["num_obs"] - relax)
        # Pull goal toward center — each relax step moves 25% closer to 0.50
        relaxed["_goal_center_pull"] = 0.25 * (relax + 1)  # 0.25, 0.50, 0.75, 1.0...
        for attempt in range(40):
            data = _try_generate(world, level, relaxed, grav_down, attempt + 100 + relax*40)
            if data and validate_level(data):
                return data

    print(f"  WARNING: W{world}L{level:02d} could not be validated!")
    return None

def _try_generate(world, level, params, grav_down, seed_offset):
    """Single attempt to generate a level layout."""
    rng = random.Random(world * 1000 + level * 100 + seed_offset)

    num_obs = params["num_obs"]
    velocity = params["velocity"]

    # ── Goal Y: CLEARLY VISIBLE variation ──
    # Pools of actual Y positions — not subtle math, real positions.
    # L1-2: near center but still varied
    # L3-5: moderate spread — goal clearly top/bottom half
    # L6+: full range — goal can be near edges
    if level <= 2:
        pool = [0.40, 0.50, 0.60]
    elif level <= 5:
        pool = [0.32, 0.42, 0.58, 0.68]
    else:
        pool = [0.27, 0.36, 0.50, 0.64, 0.73]
    base_y = pool[(level + world) % len(pool)]

    # World scaling: W1-2 pull slightly toward center, W5+ use full positions
    world_factor = lerp(0.65, 1.0, (world - 1) / 7.0)
    goal_y = 0.50 + (base_y - 0.50) * world_factor

    # Relaxation: pull goal toward center if requested
    center_pull = params.get("_goal_center_pull", 0.0)
    if center_pull > 0:
        goal_y = goal_y + (0.50 - goal_y) * min(1.0, center_pull)

    # Small jitter per-attempt
    goal_y += rng.uniform(-0.02, 0.02)
    goal_y = max(0.25, min(0.75, goal_y))

    # Obstacles: spread evenly along x, zigzag y
    obstacles = []
    # Always add top/bottom bars
    obstacles.append({
        "id": "top-bar", "type": "rect",
        "position": {"x": 0.5, "y": 0.06},
        "size": {"width": 1.0, "height": 0.018},
        "rotation": 0, "style": "solid"
    })
    obstacles.append({
        "id": "bot-bar", "type": "rect",
        "position": {"x": 0.5, "y": 0.94},
        "size": {"width": 1.0, "height": 0.018},
        "rotation": 0, "style": "solid"
    })

    # Space obstacles evenly — tighter cluster when few, wider when many
    x_start = 0.22 if num_obs >= 3 else 0.28
    x_end = 0.78 if num_obs >= 3 else 0.72
    if num_obs == 1:
        x_positions = [0.5]
    else:
        x_positions = [x_start + i * (x_end - x_start) / (num_obs - 1) for i in range(num_obs)]

    for i, ox in enumerate(x_positions):
        # Zigzag: alternate between upper and lower half
        # Keep obstacles away from the goal's Y zone for navigability
        if i % 2 == 0:
            # Low obstacle: place in lower third, but not blocking goal if goal is low
            lo_min = params["y_min"]
            lo_max = min(0.45, goal_y - 0.12)
            lo_max = max(lo_min + 0.05, lo_max)  # ensure valid range
            oy = rng.uniform(lo_min, lo_max)
        else:
            # High obstacle: place in upper third, but not blocking goal if goal is high
            hi_max = params["y_max"]
            hi_min = max(0.55, goal_y + 0.12)
            hi_min = min(hi_max - 0.05, hi_min)  # ensure valid range
            oy = rng.uniform(hi_min, hi_max)

        ow = round(rng.uniform(params["obs_w_min"], params["obs_w_max"]), 3)
        oh = round(rng.uniform(params["obs_h_min"], params["obs_h_max"]), 3)
        rot = round(rng.uniform(-params["rot_max"], params["rot_max"]), 1)

        # Add slight x jitter so levels feel less mechanical
        ox += rng.uniform(-0.03, 0.03)
        ox = max(0.15, min(0.85, ox))

        obstacles.append({
            "id": f"obs-{i+1}", "type": "rect",
            "position": {"x": round(ox, 3), "y": round(oy, 3)},
            "size": {"width": ow, "height": oh},
            "rotation": rot, "style": "solid"
        })

    # Collectibles: 3 per level, placed between obstacles
    collectibles = []
    # Place them in gaps between obstacles (or before first / after last)
    col_x_slots = []
    if num_obs >= 2:
        for i in range(num_obs - 1):
            mid_x = (x_positions[i] + x_positions[i+1]) / 2.0
            col_x_slots.append(mid_x)
        # Add one before first obstacle
        col_x_slots.insert(0, x_positions[0] - 0.08)
        # Add one after last obstacle
        col_x_slots.append(x_positions[-1] + 0.08)
    else:
        col_x_slots = [0.25, 0.50, 0.75]

    # Pick 3 slots
    rng.shuffle(col_x_slots)
    chosen_slots = sorted(col_x_slots[:3])

    for cx in chosen_slots:
        cx = max(0.12, min(0.88, cx))
        # Place y near center with some variation (avoid extremes)
        cy = rng.uniform(0.35, 0.65)
        collectibles.append({"position": {"x": round(cx, 3), "y": round(cy, 3)}})

    # Goal radius from params
    goal_radius = round(params["goal_radius"])

    # Give ball initial vertical velocity toward goal (helps reach varied positions)
    launch_dy = (goal_y - 0.5) * 60.0  # push in goal direction

    # Ensure no collectibles overlap with goal ring (causes impossible collection)
    goal_x_abs = 0.90 * SCREEN_W
    goal_y_abs = goal_y * SCREEN_H
    exclusion_radius = goal_radius + 20  # goal radius + buffer in pixels
    filtered_collectibles = []
    for c in collectibles:
        cx_abs = c["position"]["x"] * SCREEN_W
        cy_abs = c["position"]["y"] * SCREEN_H
        dist = math.sqrt((cx_abs - goal_x_abs)**2 + (cy_abs - goal_y_abs)**2)
        if dist > exclusion_radius:
            filtered_collectibles.append(c)
        else:
            # Move collectible left to avoid goal overlap
            new_cx = c["position"]["x"] - 0.08
            new_cx = max(0.12, min(0.82, new_cx))
            filtered_collectibles.append({"position": {"x": round(new_cx, 3), "y": c["position"]["y"]}})

    data = {
        "worldId": world,
        "levelId": level,
        "launchPosition": {"x": 0.08, "y": 0.5},
        "launchVelocity": {"dx": round(velocity, 1), "dy": round(launch_dy, 1)},
        "goalPosition": {"x": 0.90, "y": round(goal_y, 3)},
        "goalRadius": goal_radius,
        "initialGravityDown": grav_down,
        "parFlips": params["par_flips"],
        "parTime": round(params["par_time"], 1),
        "obstacles": obstacles,
        "collectibles": filtered_collectibles,
    }
    return data

# ── Main ─────────────────────────────────────────────────────────────
def main():
    print("=" * 70)
    print("  FREEFALL LEVEL GENERATOR v4 — Physics-Validated")
    print("=" * 70)
    print()

    total = 0
    passed = 0
    failed_levels = []

    for world in range(1, 9):
        world_dir = os.path.join(LEVELS_DIR, f"world{world}")
        os.makedirs(world_dir, exist_ok=True)
        print(f"  World {world}:")

        for level in range(1, 11):
            total += 1
            label = f"W{world}L{level:02d}"
            data = generate_level(world, level)

            if data is None:
                print(f"    [{label}] FAILED — could not generate valid level")
                failed_levels.append(label)
                continue

            # Save
            fp = os.path.join(world_dir, f"w{world}l{level:02d}.json")
            with open(fp, "w") as f:
                json.dump(data, f, indent=2)
                f.write("\n")

            p = get_params(world, level)
            n_obs = len(data["obstacles"]) - 2  # exclude bars
            print(f"    [{label}] ✓  obs={n_obs}  vel={data['launchVelocity']['dx']}  "
                  f"h=[{p['obs_h_min']:.3f}-{p['obs_h_max']:.3f}]  "
                  f"rot=±{p['rot_max']:.0f}°  goal_r={data['goalRadius']}")
            passed += 1

        print()

    print("=" * 70)
    print(f"  RESULT: {passed}/{total} generated and validated")
    if failed_levels:
        print(f"  FAILED: {', '.join(failed_levels)}")
    print("=" * 70)

if __name__ == "__main__":
    main()
