from PIL import Image, ImageDraw

# Create simple arrow icons for page buttons
# Size: 64x64, transparent background, white arrow

def make_arrow(size, direction, save_path):
    img = Image.new('RGBA', size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    w, h = size
    # Background: dark semi-transparent rounded-ish circle
    draw.ellipse([0, 0, w-1, h-1], fill=(30, 30, 30, 220), outline=(200, 200, 200, 255), width=2)
    # Arrow
    color = (255, 255, 255, 255)
    if direction == 'left':
        # Left pointing triangle/arrow
        points = [
            (w*0.55, h*0.25),
            (w*0.30, h*0.50),
            (w*0.55, h*0.75),
            (w*0.55, h*0.60),
            (w*0.70, h*0.60),
            (w*0.70, h*0.40),
            (w*0.55, h*0.40),
        ]
    else:
        # Right pointing triangle/arrow
        points = [
            (w*0.45, h*0.25),
            (w*0.70, h*0.50),
            (w*0.45, h*0.75),
            (w*0.45, h*0.60),
            (w*0.30, h*0.60),
            (w*0.30, h*0.40),
            (w*0.45, h*0.40),
        ]
    draw.polygon(points, fill=color)
    img.save(save_path)
    print(f"saved {save_path}")

make_arrow((64, 64), 'left', r'E:\Code\WH3-modding\mod_files\zzz_czx_auto_tools\ui\skins\default\czx_arrow_left.png')
make_arrow((64, 64), 'right', r'E:\Code\WH3-modding\mod_files\zzz_czx_auto_tools\ui\skins\default\czx_arrow_right.png')
