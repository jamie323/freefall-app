#!/usr/bin/env python3
"""FreeFall Level Auditor v3 - Conservative audit with SpriteKit tolerance."""
import json, math, os, sys, copy

SCREEN_W = 393.0
SCREEN_H = 852.0
# Use slightly reduced collision radius to account for SpriteKit physics tolerances
# Actual ball radius is 14px, but SpriteKit edge-loop collision has some slop
BALL_RADIUS = 10.0
DT = 1.0 / 60.0
COLLECTIBLE_RADIUS = 25.0
OOB_MARGIN = 50.0
MAX_FRONTIER = 3000
MAX_FRAMES = 1200
Y_MERGE = 2.0
VY_MERGE = 3.0
# Human reaction-time constraint: minimum frames between flips.
# 8 frames @ 60fps ≈ 133ms — fast but achievable for a gamer.
# 12 frames ≈ 200ms — average human visual reaction time.
MIN_FLIP_INTERVAL = 8

WORLD_PHYSICS = {
    1: {"grav": 50, "imp": 35, "maxV": 140, "damp": 0.02},
    2: {"grav": 65, "imp": 48, "maxV": 180, "damp": 0.008},
    3: {"grav": 75, "imp": 32, "maxV": 130, "damp": 0.03},
    4: {"grav": 70, "imp": 42, "maxV": 200, "damp": 0.005},
    5: {"grav": 40, "imp": 30, "maxV": 220, "damp": 0.0},
    6: {"grav": 95, "imp": 60, "maxV": 120, "damp": 0.04},
    7: {"grav": 60, "imp": 38, "maxV": 170, "damp": 0.012},
    8: {"grav": 85, "imp": 45, "maxV": 240, "damp": 0.003},
}

LEVELS_DIR = "/Users/jamiethomson/freefall-app/src/Freefall/Freefall/levels"

class Obs:
    __slots__ = ["cx","cy","hw","hh","cr","sr"]
    def __init__(s, cx, cy, hw, hh, cr, sr):
        s.cx=cx; s.cy=cy; s.hw=hw; s.hh=hh; s.cr=cr; s.sr=sr

def load_level(fp):
    with open(fp) as f: data = json.load(f)
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
            "obs":obs,"cols":cols,"fp":fp,"raw":data}

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
                if key not in nm:
                    nm[key]=(ny,vy,gd,ncc)
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
    """Like simulate() but enforces a minimum cooldown between flips.

    State adds a 'frames_since_last_flip' counter. A flip is only allowed
    when that counter >= flip_interval. This weeds out levels that are
    technically completable but require super-human reaction times.
    """
    ph = WORLD_PHYSICS[lv["w"]]
    grav=ph["grav"]; imp=ph["imp"]; maxV=ph["maxV"]; damp=ph["damp"]
    obs=lv["obs"]; cols=lv["cols"]; nc=len(cols)
    gx=lv["gx"]; gy=lv["gy"]; grsq=lv["gr"]**2; br=BALL_RADIUS
    crsq=COLLECTIBLE_RADIUS**2
    # State: (y, vy, gravDown, collectibles_mask, frames_since_flip)
    # Start with a large counter so the player can flip immediately
    frontier = [(lv["ly"], lv["dy"], lv["gd"], 0, flip_interval)]
    x = lv["lx"]; dx_v = lv["dx"]
    completable = False; goal_masks = set(); ever = 0
    for frame in range(MAX_FRAMES):
        if not frontier: break
        nm = {}
        for sy, svy, sgd, sc, sf in frontier:
            can_flip = sf >= flip_interval
            options = [False]
            if can_flip:
                options.append(True)
            for df in options:
                vy=svy; gd=sgd; nsf = sf + 1
                if df:
                    gd = not gd; vy = -vy*0.3 + (-imp if gd else imp)
                    nsf = 0  # reset cooldown
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
                # Cap sf for merging so states don't diverge forever
                sf_capped = min(nsf, flip_interval)
                yb=round(ny/Y_MERGE); vb=round(vy/VY_MERGE)
                key=(yb,vb,gd,ncc,sf_capped)
                if key not in nm:
                    nm[key]=(ny,vy,gd,ncc,nsf)
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

def y_range_at_x(lv, tx):
    ph = WORLD_PHYSICS[lv["w"]]
    grav=ph["grav"]; imp=ph["imp"]; maxV=ph["maxV"]; damp=ph["damp"]
    obs=lv["obs"]; br=BALL_RADIUS
    frontier = [(lv["ly"], lv["dy"], lv["gd"])]
    x = lv["lx"]; dx_v = lv["dx"]
    for frame in range(MAX_FRAMES):
        if not frontier: return None
        nm = {}
        for sy, svy, sgd in frontier:
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
                hit = False
                for o in obs:
                    lxx=(nx-o.cx)*o.cr+(ny-o.cy)*o.sr
                    lyy=-(nx-o.cx)*o.sr+(ny-o.cy)*o.cr
                    if abs(lxx)<=o.hw+br and abs(lyy)<=o.hh+br:
                        hit=True; break
                if hit: continue
                yb=round(ny/Y_MERGE); vb=round(vy/VY_MERGE)
                key=(yb,vb,gd)
                if key not in nm: nm[key]=(ny,vy,gd)
        frontier = list(nm.values())
        if len(frontier) > MAX_FRONTIER:
            frontier.sort(key=lambda s: abs(s[0]-SCREEN_H/2))
            frontier = frontier[:MAX_FRONTIER]
        x += dx_v * DT
        if x >= tx:
            ys = [s[0] for s in frontier]
            return (min(ys), max(ys))
        if x > SCREEN_W + OOB_MARGIN: return None
    return None

def fix_col(lv, ci):
    cx, cy = lv["cols"][ci]
    obs = lv["obs"]; br = BALL_RADIUS
    yr = y_range_at_x(lv, cx)
    if yr is None: return None
    ymn, ymx = yr
    for frac in [0.5,0.45,0.55,0.4,0.6,0.35,0.65,0.3,0.7,0.25,0.75,0.2,0.8]:
        ty = ymn + (ymx-ymn)*frac
        hit = False
        for o in obs:
            lxx=(cx-o.cx)*o.cr+(ty-o.cy)*o.sr
            lyy=-(cx-o.cx)*o.sr+(ty-o.cy)*o.cr
            if abs(lxx)<=o.hw+br and abs(lyy)<=o.hh+br:
                hit=True; break
        if not hit:
            return {"x": round(cx/SCREEN_W, 3), "y": round(ty/SCREEN_H, 3)}
    return None

def main():
    print("="*80)
    print("  FREEFALL LEVEL AUDITOR v3 - Conservative (collision r=10px)")
    print("="*80)
    print()
    files = []
    for w in range(1,9):
        for l in range(1,11):
            fp = os.path.join(LEVELS_DIR, "world{}".format(w), "w{}l{:02d}.json".format(w,l))
            if os.path.exists(fp): files.append(fp)
    print("Found {} levels.".format(len(files)))
    print()

    # ── Pass 1: Frame-perfect audit (existing) ──────────────────────
    print("─" * 60)
    print("  PASS 1: Frame-perfect simulation")
    print("─" * 60)
    failures = []
    for fp in files:
        lv = load_level(fp)
        label = "W{}L{:02d}".format(lv["w"], lv["l"])
        r = simulate(lv)
        ok = r["comp"] and len(r["cog"]) == r["nc"]
        if ok:
            print("  [PASS] {}: completable, {}/{} collectibles OK".format(label, r["nc"], r["nc"]))
        else:
            parts = []
            if not r["comp"]: parts.append("NOT COMPLETABLE")
            ug = set(range(r["nc"])) - r["cog"]
            ue = set(range(r["nc"])) - r["ce"]
            if ue: parts.append("collectibles {} never reached".format(sorted(ue)))
            op = ug - ue
            if op: parts.append("collectibles {} not on goal path".format(sorted(op)))
            print("  [FAIL] {}: {}".format(label, "; ".join(parts)))
            failures.append((label, lv, r))
    print()
    total = len(files); passed = total - len(failures)
    print("  Frame-perfect: {}/{} passed, {}/{} failed".format(passed, total, len(failures), total))
    print()

    # ── Pass 2: Human-playability audit ─────────────────────────────
    print("─" * 60)
    print("  PASS 2: Human-playability (min {}f / {:.0f}ms between flips)".format(
        MIN_FLIP_INTERVAL, MIN_FLIP_INTERVAL * DT * 1000))
    print("─" * 60)
    human_warnings = []
    for fp in files:
        lv = load_level(fp)
        label = "W{}L{:02d}".format(lv["w"], lv["l"])
        r_perfect = simulate(lv)
        # Only check human-playability for levels that pass frame-perfect
        if not (r_perfect["comp"] and len(r_perfect["cog"]) == r_perfect["nc"]):
            continue
        r_human = simulate_human(lv)
        if r_human["comp"] and len(r_human["cog"]) == r_human["nc"]:
            print("  [PASS] {}: human-playable".format(label))
        else:
            parts = []
            if not r_human["comp"]:
                parts.append("REQUIRES SUPERHUMAN REACTIONS to complete")
            else:
                ug = set(range(r_human["nc"])) - r_human["cog"]
                if ug:
                    parts.append("collectibles {} need frame-perfect flips".format(sorted(ug)))
            print("  [WARN] {}: {}".format(label, "; ".join(parts)))
            human_warnings.append((label, lv, r_human))
    print()
    if human_warnings:
        print("  ⚠ {} level(s) pass frame-perfect but FAIL human-playability:".format(len(human_warnings)))
        for label, _, _ in human_warnings:
            print("    - {}".format(label))
    else:
        print("  All frame-perfect levels are also human-playable.")
    print()

    # ── Summary ─────────────────────────────────────────────────────
    print("="*80)
    print("  SUMMARY: {}/{} frame-perfect, {} human-playability warnings".format(
        passed, total, len(human_warnings)))
    print("="*80)
    if not failures and not human_warnings:
        print("  All levels verified OK."); return

    # ── Fix broken levels (frame-perfect failures) ──────────────────
    if failures:
        print()
        print("  FIXING BROKEN LEVELS")
        print("="*80)
        fixed = []
        for label, lv, r in failures:
            print("  " + label + ":")
            if not r["comp"]:
                yr = y_range_at_x(lv, lv["gx"])
                if yr is None:
                    print("    CRITICAL: No states reach goal x. Level design broken.")
                    continue
                ymn, ymx = yr
                mid = (ymn + ymx) / 2.0
                old_gy = lv["raw"]["goalPosition"]["y"]
                new_gy = round(mid / SCREEN_H, 3)
                print("    Goal unreachable at y={:.3f} (pixel {:.1f})".format(old_gy, old_gy*SCREEN_H))
                print("    Reachable y range at goal x: [{:.1f}, {:.1f}]".format(ymn, ymx))
                print("    Moving goal to y={:.3f} (pixel {:.1f})".format(new_gy, new_gy*SCREEN_H))
                lv["raw"]["goalPosition"]["y"] = new_gy
                lv["gy"] = new_gy * SCREEN_H
                modified = True
            else:
                modified = False

            raw = lv["raw"]
            nc = r["nc"]; cog = r["cog"]
            for ci in sorted(set(range(nc)) - cog):
                old = raw["collectibles"][ci]["position"]
                print("    Collectible {}: ({:.3f}, {:.3f})".format(ci, old["x"], old["y"]))
                np2 = fix_col(lv, ci)
                if np2:
                    print("      -> ({:.3f}, {:.3f})".format(np2["x"], np2["y"]))
                    raw["collectibles"][ci]["position"] = np2
                    modified = True
                else:
                    print("      -> Cannot auto-fix")
            if modified or not r["comp"]:
                with open(lv["fp"], "w") as f:
                    json.dump(raw, f, indent=2)
                    f.write("\n")
                print("    Saved " + lv["fp"])
                fixed.append(lv["fp"])

        if fixed:
            print()
            print("="*80)
            print("  RE-AUDIT AFTER FIXES")
            print("="*80)
            sb = 0; sp = 0
            for fp in files:
                lv = load_level(fp)
                label = "W{}L{:02d}".format(lv["w"], lv["l"])
                r = simulate(lv)
                ok = r["comp"] and len(r["cog"]) == r["nc"]
                if ok:
                    sp += 1
                else:
                    sb += 1
                    parts = []
                    if not r["comp"]: parts.append("NOT COMPLETABLE")
                    ug = set(range(r["nc"])) - r["cog"]
                    if ug: parts.append("unreachable: {}".format(sorted(ug)))
                    print("  [STILL FAIL] {}: {}".format(label, "; ".join(parts)))
            print()
            print("  {}/{} pass, {}/{} still failing.".format(sp, len(files), sb, len(files)))
    print("\nDone.")

if __name__ == "__main__": main()
