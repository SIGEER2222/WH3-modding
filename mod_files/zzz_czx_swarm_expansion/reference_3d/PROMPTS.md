# 图生 3D 参考素材说明

本目录图片为本项目生成的**原创正面轮廓参考图**，用于投喂图生 3D 工具
（Meshy、Tripo3D、Rodin、混元 3D 等），不是 SC2 提取素材。

生成脚本：`tools/gen_czx_ref_images.py`

## 使用建议

- 工具支持"图片 + 文字提示词"的，两者一起喂，文字提示词见下文。
- 如果工具只认写实风格图片，这些扁平矢量图效果会差，建议直接用文字提示词生成。
- 输出格式选 `.glb` 或 `.fbx`；能选"自动绑骨/auto-rigging"就打开。
- 生成后把 `.glb/.fbx` 和贴图放到 `sc2_models/<unit>/` 目录交回即可。

## czx_feilong（飞龙 / Mutalisk 风格）

参考图：`czx_feilong.png`

```text
A large alien flying creature, Zerg Mutalisk inspired but original design.
Serpentine purple body with segmented armored chest plates. Two huge
membrane wings with visible bone ribs and spike tips, spread symmetrically.
Glowing orange eyes, horned head crest, sharp mandibles. Three bladed tail
fins hanging below the body. Small clawed forelimbs. Front view, A-pose,
full body visible, centered, orthographic, plain dark background,
game-ready creature model, purple and bone color scheme.
```

中文备注：飞行单位，要套 WH3 Carrion 飞行骨骼，翼展对称最重要。

## czx_zhanglang（蟑螂 / Roach 风格）

参考图：`czx_zhanglang.png`

```text
A bulky armored insectoid creature, Zerg Roach inspired but original
design. Massive green segmented carapace with overlapping armor plates and
bone spikes along the back. Six sturdy insect legs with clawed feet, three
per side. Low beetle-like head with glowing yellow eyes, two glowing green
acid sacs on the cheeks, large bone mandibles. Front view, full body
visible, centered, orthographic, plain dark background, game-ready
creature model, green and bone color scheme.
```

中文备注：地面单位，要套 WH3 巨蝎骨骼，六条腿和厚重甲壳是关键特征。

## czx_kerrigan（凯瑞甘 / Kerrigan 风格）

参考图：`czx_kerrigan.png`

```text
A humanoid female alien queen, Zerg Kerrigan inspired but original design.
Slim female body fully covered in dark purple segmented chitin armor.
Three large bone wing-blades fanning out from the back of each shoulder.
Blade-like claws instead of hands. Armored digitigrade legs with talon
feet. Human face with glowing cyan eyes and a single forehead crest.
Front view, A-pose, arms slightly away from body, full body visible,
centered, orthographic, plain dark background, game-ready character
model, purple chitin and bone color scheme.
```

中文备注：人形单位，要套 WH3 `hu1b` 人形骨骼，A-pose 和标准人形比例最重要，
背翼是附加装饰。英雄版和领主版共用此模型。

## 交付格式

```text
sc2_models/
├── czx_feilong/
│   ├── model.glb (或 .fbx)
│   └── textures/ (basecolor / normal / roughness)
├── czx_zhanglang/
│   └── ...
└── czx_kerrigan/
    └── ...
```

拿到 `.glb/.fbx` 后，下一步是：骨骼检查 → 决定复用 donor 动画还是自做绑定 →
转 WH3 `rigid_model_v2` / `wsmodel` / `variantmeshdefinition` → 接入 pack。
