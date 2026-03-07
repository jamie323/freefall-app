#!/usr/bin/env python3
import json, math, os, sys

SCREEN_W = 393.0
SCREEN_H = 852.0
BALL_RADIUS = 14.0
DT = 1.0 / 60.0
COLLECTIBLE_RADIUS = 25.0
OOB_MARGIN = 50.0
MAX_FRONTIER = 1500
MAX_FRAMES = 1200

Y_MERGE = 3.0
VY_MERGE = 5.0

WORLD_PHYSICS = {
    1: {"gravity": 50, "impulse": 35, "maxVel": 140, "damping": 0.02},
    2: {"gravity": 65, "impulse": 48, "maxVel": 180, "damping": 0.008},
    3: {"gravity": 75, "impulse": 32, "maxVel": 130, "damping": 0.03},
    4: {"gravity": 70, "impulse": 42, "maxVel": 200, "damping": 0.005},
    5: {"gravity": 40, "impulse": 30, "maxVel": 220, "damping": 0.0},
    6: {"gravity": 95, "impulse": 60, "maxVel": 120, "damping": 0.04},
    7: {"gravity": 60, "impulse": 38, "maxVel": 170, "damping": 0.012},
    8: {"gravity": 85, "impulse": 45, "maxVel": 240, "damping": 0.003},
}

LEVELS_DIR = "/Users/jamiethomson/freefall-app/src/Freefall/Freefall/levels"

class Obs:
    __slots__ = ["cx","cy","hw","hh","cr","sr"]
    def __init__(s, cx, cy, hw, hh, cr, sr):
        s.cx=cx; s.cy=cy; s.hw=hw; s.hh=hh; s.cr=cr; s.sr=sr

class Col:
    __slots__ = ["x","y","i"]
    def __init__(s, x, y, i):
        s.x=x; s.y=y; s.i=i

def load_level(fp):
    with open(fp) as f:
        data = json.load(f)
    w = data["worldId"]; l = data["levelId"]
    lx = data["launchPosition"]["x"] * SCREEN_W
    ly = data["launchPosition"]["y"] * SCREEN_H
    dx = data["launchVelocity"]["dx"]
    dy = data["launchVelocity"].get("dy", 0.0)
    gx = data["goalPosition"]["x"] * SCREEN_W
    gy = data["goalPosition"]["y"] * SCREEN_H
    gr = data["goalRadius"]
    gd = data.get("initialGravityDown", True)
    obstacles = []
    for o in data.get("obstacles", []):
        cx = o["position"]["x"] * SCREEN_W
        cy = o["position"]["y"] * SCREEN_H
        hw = (o["size"]["width"] * SCREEN_W) / 2.0
        hh = (o["size"]["height"] * SCREEN_H) / 2.0
        rd = o.get("rotation", 0.0)
        rr = math.radians(-rd)
        obstacles.append(Obs(cx, cy, hw, hh, math.cos(rr), math.sin(rr)))
    cols = []
    for i, c in enumerate(data.get("collectibles", [])):
        cols.append(Col(c["position"]["x"]*SCREEN_W, c["position"]["y"]*SCREEN_H, i))
    return {"w":w, "l":l, "lx":lx, "ly":ly, "dx":dx, "dy":dy,
            "gx":gx, "gy":gy, "gr":gr, "gd":gd,
            "obs":obstacles, "cols":cols, "fp":fp, "raw":data}

def simulate(lv):
    ph = WORLD_PHYSICS[lv["w"]]
    gm = ph["gravity"]; fi = ph["impulse"]; mv = ph["maxVel"]; dp = ph["damping"]
    obs = lv["obs"]; cols = lv["cols"]; nc = len(cols)
    gx = lv["gx"]; gy = lv["gy"]; grsq = lv["gr"]**2
    cx = [c.x for c in cols]; cy = [c.y for c in cols]
    crsq = COLLECTIBLE_RADIUS**2
    br = BALL_RADIUS
    frontier = [(lv["ly"], lv["dy"], lv["gd"], 0)]
    x = lv["lx"]; dx = lv["dx"]
    completable = False; goal_masks = set(); ever = 0
    for frame in range(MAX_FRAMES):
        if not frontier: break
        x += dx * DT
        if x > SCREEN_W + OOB_MARGIN: break
        nm = {}
        for sy, svy, sgd, sc in frontier:
            for df in (False, True):
                vy = svy; gd = sgd
                if df:
                    gd = not gd
                    vy = -vy * 0.3 + (fi if not gd else -fi)
                vy += (gm if gd else -gm) * DT
                vy *= (1.0 - dp)
                if vy > mv: vy = mv
                elif vy < -mv: vy = -mv
                ny = sy + vy * DT
                if ny < -OOB_MARGIN or ny > SCREEN_H + OOB_MARGIN: continue
                hit = False
                for o in obs:
                    lxx = (x-o.cx)*o.cr + (ny-o.cy)*o.sr
                    lyy = -(x-o.cx)*o.sr + (ny-o.cy)*o.cr
                    if abs(lxx) <= o.hw+br and abs(lyy) <= o.hh+br:
                        hit = True; break
                if hit: continue
                ncc = sc
                for ci in range(nc):
                    bit = 1 << ci
                    if ncc & bit: continue
                    ddx = x - cx[ci]; ddy = ny - cy[ci]
                    if ddx*ddx + ddy*ddy <= crsq: ncc |= bit
                ever |= ncc
                ddx = x - gx; ddy = ny - gy
                if ddx*ddx + ddy*ddy <= grsq:
                    completable = True; goal_masks.add(ncc)
                yb = round(ny/Y_MERGE); vb = round(vy/VY_MERGE)
                key = (yb, vb, gd, ncc)
                if key not in nm:
                    nm[key] = (ny, vy, gd, ncc)
                else:
                    ex = nm[key]
                    if ex[3] != ncc:
                        if bin(ncc).count("1") > bin(ex[3]).count("1"):
                            nm[key] = (ny, vy, gd, ncc)
                        else:
                            nm[(yb,vb,gd,ncc)] = (ny, vy, gd, ncc)
        frontier = list(nm.values())
        if len(frontier) > MAX_FRONTIER:
            frontier.sort(key=lambda s: (-bin(s[3]).count("1"), abs(s[0]-gy)))
            frontier = frontier[:MAX_FRONTIER]
    cog = set()
    for m in goal_masks:
        for i in range(nc):
            if m & (1<<i): cog.add(i)
    ce = set()
    for i in range(nc):
        if ever & (1<<i): ce.add(i)
    return {"comp": completable, "cog": cog, "ce": ce, "nc": nc, "gm": goal_masks}

def y_range_at_x(lv, tx):
    ph = WORLD_PHYSICS[lv["w"]]
    gm=ph["gravity"]; fi=ph["impulse"]; mv=ph["maxVel"]; dp=ph["damping"]
    obs = lv["obs"]; br = BALL_RADIUS
    frontier = [(lv["ly"], lv["dy"], lv["gd"])]
    x = lv["lx"]; dx = lv["dx"]
    for frame in range(MAX_FRAMES):
        if not frontier: return None
        x += dx * DT
        if x >= tx:
            ys = [s[0] for s in frontier]
            return (min(ys), max(ys))
        if x > SCREEN_W + OOB_MARGIN: return None
        nm = {}
        for sy, svy, sgd in frontier:
            for df in (False, True):
                vy=svy; gd=sgd
                if df:
                    gd = not gd
                    vy = -vy*0.3 + (fi if not gd else -fi)
                vy += (gm if gd else -gm)*DT
                vy *= (1.0-dp)
                if vy > mv: vy = mv
                elif vy < -mv: vy = -mv
                ny = sy + vy * DT
                if ny < -OOB_MARGIN or ny > SCREEN_H+OOB_MARGIN: continue
                hit = False
                for o in obs:
                    lxx=(x-o.cx)*o.cr+(ny-o.cy)*o.sr
                    lyy=-(x-o.cx)*o.sr+(ny-o.cy)*o.cr
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
    return None

def fix_col(lv, ci):
    c = lv["cols"][ci]; obs = lv["obs"]; br = BALL_RADIUS
    yr = y_range_at_x(lv, c.x)
    if yr is None: return None
    ymn, ymx = yr
    for frac in [0.5,0.45,0.55,0.4,0.6,0.35,0.65,0.3,0.7,0.25,0.75,0.2,0.8]:
        ty = ymn + (ymx-ymn)*frac
        hit = False
        for o in obs:
            lxx=(c.x-o.cx)*o.cr+(ty-o.cy)*o.sr
            lyy=-(c.x-o.cx)*o.sr+(ty-o.cy)*o.cr
            if abs(lxx)<=o.hw+br and abs(lyy)<=o.hh+br:
                hit=True; break
        if not hit:
            return {"x": round(c.x/SCREEN_W, 3), "y": round(ty/SCREEN_H, 3)}
    return None

def main():
    print("="*80)
    print("  FREEFALL LEVEL AUDITOR - Physics Simulation")
    print("  Checking all 80 levels")
    print("="*80)
    print()
    files = []
    for w in range(1,9):
        for l in range(1,11):
            fp = os.path.join(LEVELS_DIR, "world{}".format(w), "w{}l{:02d}.json".format(w,l))
            if os.path.exists(fp): files.append(fp)
            else: print("  WARNING: Missing " + fp)
    print("Found {} level files.".format(len(files)))
    print()
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
    print("="*80)
    total = len(files)
    pct = len(files)-len(failures)
    print("  SUMMARY: {}/{} passed, {}/{} failed".format(pct, total, len(failures), total))
    print("="*80)
    if not failures:
        print()
        print("  All levels verified OK.")
        return
    print()
    print("="*80)
    print("  ATTEMPTING FIXES")
    print("="*80)
    fixed = []
    for label, lv, r in failures:
        print()
        print("  Fixing " + label + "...")
        if not r["comp"]:
            print("    CRITICAL: Not completable. Manual redesign needed.")
            print("    Goal: ({:.1f}, {:.1f}) r={}".format(lv["gx"], lv["gy"], lv["gr"]))
            continue
        raw = lv["raw"]; modified = False
        for ci in sorted(set(range(r["nc"])) - r["cog"]):
            old = raw["collectibles"][ci]["position"]
            print("    Col {}: ({:.3f}, {:.3f})".format(ci, old["x"], old["y"]))
            np2 = fix_col(lv, ci)
            if np2:
                print("      -> ({:.3f}, {:.3f})".format(np2["x"], np2["y"]))
                raw["collectibles"][ci]["position"] = np2
                modified = True
            else:
                print("      -> Cannot auto-fix")
        if modified:
            with open(lv["fp"], "w") as f:
                json.dump(raw, f, indent=2)
                f.write("\n")
            print("    Saved " + lv["fp"])
            fixed.append(lv["fp"])
    if fixed:
        print()
        print("="*80)
        print("  RE-AUDIT")
        print("="*80)
        sb = 0
        for fp in files:
            lv = load_level(fp)
            label = "W{}L{:02d}".format(lv["w"], lv["l"])
            r = simulate(lv)
            ok = r["comp"] and len(r["cog"]) == r["nc"]
            if not ok:
                sb += 1
                parts = []
                if not r["comp"]: parts.append("NOT COMPLETABLE")
                ug = set(range(r["nc"])) - r["cog"]
                if ug: parts.append("unreachable: {}".format(sorted(ug)))
                print("  [STILL FAIL] {}: {}".format(label, "; ".join(parts)))
        if sb == 0:
            print("  All {} levels now pass.".format(len(files)))
        else:
            print("  {}/{} still failing.".format(sb, len(files)))
    print()
    print("Done.")

if __name__ == "__main__":
    main()
