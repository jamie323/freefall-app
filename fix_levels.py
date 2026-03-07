#!/usr/bin/env python3
import json,math,os,random,sys,copy

SCREEN_W=393.0;SCREEN_H=852.0;BALL_RADIUS=10.0;DT=1.0/60.0
COLLECTIBLE_RADIUS=25.0;OOB_MARGIN=50.0;MAX_FRONTIER=2000;MAX_FRAMES=1200
Y_MERGE=2.0;VY_MERGE=3.0

WP={1:{"g":50,"i":35,"m":140,"d":0.02},2:{"g":65,"i":48,"m":180,"d":0.008},
   3:{"g":75,"i":32,"m":130,"d":0.03},4:{"g":70,"i":42,"m":200,"d":0.005},
   5:{"g":40,"i":30,"m":220,"d":0.0},6:{"g":95,"i":60,"m":120,"d":0.04},
   7:{"g":60,"i":38,"m":170,"d":0.012},8:{"g":85,"i":45,"m":240,"d":0.003}}

LD="/Users/jamiethomson/freefall-app/src/Freefall/Freefall/levels"
