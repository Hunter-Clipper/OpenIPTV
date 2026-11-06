#!/usr/bin/env python3
"""Counts torn frames on a device that is playing the stream made by
make-stream.sh full screen (#157).

    python3 tools/tear-test/tear.py <adb-serial> <screenshots> <label>

Takes screenshots over adb and reads the frame number drawn at the top,
middle and bottom of each one. If they disagree, the picture on screen was
put together from more than one video frame: a tear. Needs Pillow and adb
on PATH (or set ADB). A control: paste the top half of one frame onto the
bottom half of another and the three numbers differ, also after scaling.
"""
import sys, subprocess, io, time
from PIL import Image
import os
ADB=os.environ.get("ADB","adb"); DEV=sys.argv[1]; N=int(sys.argv[2]); label=sys.argv[3]
def grab():
    t=time.time(); raw=subprocess.run([ADB,"-s",DEV,"exec-out","screencap","-p"],capture_output=True).stdout
    return Image.open(io.BytesIO(raw)).convert("RGB"), t
def decode(im,y0):
    w,h=im.size; sx=w/1280; sy=h/720; v=0; ok=True
    for k in range(12):
        x=int((20+k*40+18)*sx); y=int((y0+30)*sy); r,g,b=im.getpixel((x,y))
        bit = g>150 and r<120 and b<120
        dark = g<60 and r<60 and b<60
        if not (bit or dark): ok=False
        if bit: v|=1<<k
    return v,ok
res=[]; bad=0; tears=0; unreadable=0; nums=[]
for i in range(N):
    im,t=grab(); top,o1=decode(im,20); mid,o2=decode(im,330); bot,o3=decode(im,640)
    if not (o1 and o2 and o3): unreadable+=1; continue
    nums.append(top)
    if not (top==mid==bot):
        tears+=1; print(f"  TEAR shot {i}: top={top} mid={mid} bottom={bot}")
n=len(nums)
print(f"[{label}] distinct frames seen={len(set(nums))} readable screenshots={n} unreadable={unreadable} tears={tears} ({100*tears/max(n,1):.1f}%)")
