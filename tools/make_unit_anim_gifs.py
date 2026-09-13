# -*- coding: utf-8 -*-
"""Render animation clips to PNG frames + assemble review GIFs.

usage:
  python tools/make_unit_anim_gifs.py unit1 [unit2 ...]     # listed units only
  python tools/make_unit_anim_gifs.py                       # all JOBS

Each job: (unit, skinned_glb, clip_pose_json_basename, skeleton, step, fps)
Frames land in scratch/anim_frames/<unit>/<clip>/, GIFs in scratch/anim_frames/.
"""
import subprocess, glob, sys
from pathlib import Path
from PIL import Image

ROOT = Path(r'E:\Code\WH3-modding')
OUT = ROOT / 'tools' / '_out'
CLIPS = ROOT / 'scratch' / 'anim_clips'
SKEL = ROOT / 'tools' / '_skel'
SHOTS = ROOT / 'scratch' / 'anim_frames'
BLENDER = r'C:\Program Files\Blender Foundation\Blender 4.5\blender.exe'
SCRIPT = ROOT / 'tools' / 'blender_pose_anim.py'

JOBS = [
    ('jibian',    'jibian_skinned.glb',    'hu6_axs_attack_01',           'humanoid06',  2, 15),
    ('jibian',    'jibian_skinned.glb',    'hu6_axs_stand_idle_10',       'humanoid06',  2, 12),
    ('hd_green',  'hd_green_skinned.glb',  'hu6_axs_attack_01',           'humanoid06',  2, 15),
    ('hd_green',  'hd_green_skinned.glb',  'hu6_axs_stand_idle_10',       'humanoid06',  2, 12),
    ('hd_white',  'hd_white_skinned.glb',  'hu1b_sws_attack_01',          'humanoid01b', 2, 15),
    ('hd_white',  'hd_white_skinned.glb',  'hu1b_sws_stand_idle_05',      'humanoid01b', 2, 12),
    ('hd_black',  'hd_black_skinned.glb',  'hu1b_sws_attack_01',          'humanoid01b', 2, 15),
    ('hd_black',  'hd_black_skinned.glb',  'hu1b_sws_stand_idle_05',      'humanoid01b', 2, 12),
    ('hd_dblack', 'hd_dblack_skinned.glb', 'hu11b_attack_01',             'humanoid11b', 3, 15),
    ('hd_dblack', 'hd_dblack_skinned.glb', 'hu11b_ghorgon_stand_idle_05', 'humanoid11b', 3, 12),
    ('baochong',  'baochong_skinned.glb',  'sp1_jump_attack_01',          'spider01',    1, 15),
    ('baochong',  'baochong_skinned.glb',  'sp1_stand_idle_04',           'spider01',    2, 12),
    ('mangshou',  'mangshou_skinned.glb',  'cr1_attack_01',               'crab01',      2, 15),
    ('mangshou',  'mangshou_skinned.glb',  'cr1_stand_01',                'crab01',      2, 12),
]

def render(unit, glb, clip, skel, step):
    outdir = SHOTS / unit / clip
    if len(glob.glob(str(outdir / 'f*.png'))) >= 10:
        print('skip', unit, clip)
        return outdir
    cmd = [BLENDER, '-b', '-P', str(SCRIPT), '--',
           str(OUT / glb), str(CLIPS / (clip + '.pose.json')),
           str(SKEL / (skel + '.json')), str(outdir), str(step)]
    print('RENDER', unit, clip, flush=True)
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print('ERR', (r.stderr or r.stdout)[-500:])
    return outdir

def make_gif(unit, clip, outdir, fps):
    frames = sorted(glob.glob(str(outdir / 'f*.png')))
    if not frames:
        print('no frames for', unit, clip); return
    imgs = [Image.open(f).convert('P', palette=Image.ADAPTIVE, colors=128) for f in frames]
    gif = SHOTS / ('%s_%s.gif' % (unit, clip))
    imgs[0].save(str(gif), save_all=True, append_images=imgs[1:],
                 duration=int(1000 / fps), loop=0, optimize=True)
    print('GIF', gif.name, len(frames), 'frames')

want = set(sys.argv[1:])
for unit, glb, clip, skel, step, fps in JOBS:
    if want and unit not in want:
        continue
    make_gif(unit, clip, render(unit, glb, clip, skel, step), fps)
print('DONE')
