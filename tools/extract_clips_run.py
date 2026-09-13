# -*- coding: utf-8 -*-
"""Extract chosen battle anim clips from anim2.pack into scratch/anim_clips/."""
import sys, json
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from export_gamedata import iter_pack_entries, GAME_DATA
from parse_anim_skeleton import parse_anim, world_transforms

OUT = Path(r'E:\Code\WH3-modding\scratch\anim_clips')
OUT.mkdir(parents=True, exist_ok=True)

WANTS = [
    'animations/battle/humanoid06/axe_and_shield/attacks/hu6_axs_attack_01.anim',
    'animations/battle/humanoid06/axe_and_shield/stand/hu6_axs_stand_idle_10.anim',
    'animations/battle/humanoid01b/sword_and_shield/attacks/hu1b_sws_attack_01.anim',
    'animations/battle/humanoid01b/sword_and_shield/stand/hu1b_sws_stand_idle_05.anim',
    'animations/battle/humanoid11b/ghorgon/attacks/hu11b_attack_01.anim',
    'animations/battle/humanoid11b/ghorgon/stand/hu11b_ghorgon_stand_idle_05.anim',
    'animations/battle/spider01/attacks/sp1_jump_attack_01.anim',
    'animations/battle/spider01/stand/sp1_stand_idle_04.anim',
    'animations/battle/crab01/attacks/cr1_attack_01.anim',
    'animations/battle/crab01/stand/cr1_stand_01.anim',
]

want_set = set(WANTS)
pack = GAME_DATA / 'anim2.pack'
found = {}
for e in iter_pack_entries(pack, prefixes=('animations/battle/',)):
    if e.name in want_set:
        found[e.name] = e.payload
        if len(found) == len(want_set):
            break

missing = want_set - set(found)
for m in missing:
    print('MISSING:', m)

for name, payload in found.items():
    out = OUT / Path(name).name
    out.write_bytes(payload)
    try:
        d = parse_anim(out)
        # attach world transforms for every frame for easy posing
        wp_all, wq_all = [], []
        for fi in range(d['frame_count']):
            wp, wq = world_transforms(d, fi)
            wp_all.append(wp); wq_all.append(wq)
        d['world_pos'] = wp_all
        d['world_quat'] = wq_all
        js = out.with_suffix('.json')
        js.write_text(json.dumps(d), encoding='utf-8')
        print(f'{out.name}: frames={d["frame_count"]} bones={d["bone_count"]} skel={d["skeleton_name"]}')
    except Exception as ex:
        print(out.name, 'PARSE FAIL', ex)
