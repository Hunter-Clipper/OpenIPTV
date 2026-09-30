"""Exports the OpenIPTV brand PNGs from assets/branding/*.svg.

Needs Firefox (rendered headless), Pillow and numpy. Transparent artwork is
rendered on black and on white and un-composited to recover alpha.

    python3 assets/branding/export.py
    dart run flutter_launcher_icons
    dart run flutter_native_splash:create
"""
import os, re, subprocess, tempfile
import numpy as np
from PIL import Image
ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),'..','..'))
BR=f'{ROOT}/assets/branding'; IMG=f'{ROOT}/assets/images'; RES=f'{ROOT}/android/app/src/main/res'
TMP=tempfile.mkdtemp()
PROF=os.path.join(TMP,'profile'); os.makedirs(PROF)
def svg_src(name, scale=1.0):
    s=open(f'{BR}/{name}').read()
    s=s.replace('url(../fonts/', f'url(file://{ROOT}/assets/fonts/')
    if scale!=1.0:  # scale the drawing about the canvas centre
        w=int(re.search(r'width="(\d+)"',s).group(1)); h=int(re.search(r'height="(\d+)"',s).group(1))
        head,rest=s.split('>',1); defs_end=rest.index('</defs>')+7 if '</defs>' in rest else 0
        inner=rest[defs_end:rest.rindex('</svg>')]
        t=f'<g transform="translate({w/2} {h/2}) scale({scale}) translate({-w/2} {-h/2})">{inner}</g>'
        s=head+'>'+rest[:defs_end]+t+'</svg>'
    return s
def shoot(svg, w, h, bg):
    html=f'<html><body style="margin:0;background:{bg}">{svg.replace("<svg ", f"<svg style=\"display:block;width:{w}px;height:{h}px\" ",1)}</body></html>'
    p=f'{TMP}/p.html'; open(p,'w').write(html); out=f'{TMP}/o.png'
    if os.path.exists(out): os.remove(out)
    subprocess.run(['firefox','--headless','--no-remote','--profile',PROF,'--screenshot',out,f'--window-size={w},{h}',f'file://{p}'],
                   env={**os.environ,'MOZ_HEADLESS':'1'},stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=120)
    return np.asarray(Image.open(out).convert('RGB'),dtype=np.float64)[:h,:w]
def render(name, w, h, transparent, scale=1.0):
    svg=svg_src(name, scale)
    if not transparent: return Image.fromarray(shoot(svg,w,h,'#000').astype(np.uint8))
    B=shoot(svg,w,h,'#000'); W=shoot(svg,w,h,'#fff')
    a=np.clip(1-(W-B).mean(axis=2)/255,0,1)
    rgb=np.where(a[...,None]>0.002, B/np.maximum(a[...,None],1e-6), 0)
    return Image.fromarray(np.dstack([np.clip(rgb,0,255),a*255]).astype(np.uint8),'RGBA')
def save(im, path, size=None):
    if size: im=im.resize(size, Image.LANCZOS)
    os.makedirs(os.path.dirname(path),exist_ok=True); im.save(path, optimize=True); print('wrote',path.replace(ROOT+'/',''),im.size)
# --- app assets (fed to flutter_launcher_icons / flutter_native_splash) ---
save(render('icon.svg',1024,1024,False), f'{BR}/png/app_icon.png')
save(render('mark.svg',1024,1024,True,scale=1.25), f'{BR}/png/icon_foreground.png')
save(render('mark_mono.svg',1024,1024,True,scale=1.25), f'{BR}/png/icon_monochrome.png')
save(render('mark.svg',1024,1024,True), f'{IMG}/logo_mark.png', (512,512))
mark=render('mark.svg',1024,1024,True)
splash=Image.new('RGBA',(1152,1152),(0,0,0,0)); splash.paste(mark,(64,64),mark)
save(splash, f'{BR}/png/splash_mark.png')
save(render('wordmark.svg',1200,300,True), f'{IMG}/wordmark.png', (800,200))
# --- Android-only resources made directly ---
tv=render('tv_banner.svg',1280,720,False)
save(tv, f'{RES}/drawable/tv_banner.png', (320,180)); save(tv, f'{RES}/drawable-xhdpi/tv_banner.png', (640,360))
stat=render('mark_mono.svg',1024,1024,True,scale=1.3)
for d,px in [('mdpi',24),('hdpi',36),('xhdpi',48),('xxhdpi',72),('xxxhdpi',96)]:
    save(stat, f'{RES}/drawable-{d}/ic_stat_open_iptv.png', (px,px))
# README / GitHub
save(render('icon_tile.svg',1024,1024,True), f'{ROOT}/docs/images/icon.png', (256,256))
save(render('readme_banner.svg',1600,560,True), f'{ROOT}/docs/images/banner.png', (1200,420))
