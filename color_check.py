from PIL import Image
import sys

img_path = sys.argv[1]
try:
    img = Image.open(img_path)
    width, height = img.size
    print(f"Image size: {width}x{height}")
    
    # We know "Create A Registry" text is at x:0.19, y:0.57 (from bottom left, or wait... Vision is bottom-left origin)
    # Vision origin: bottom-left. y=0 is bottom, y=1 is top.
    # So y=0.57 in Vision means pixel y is height * (1 - 0.57) = height * 0.43 from top.
    
    def get_color(u, v_from_bottom):
        px = int(width * u)
        py = int(height * (1.0 - v_from_bottom))
        return img.getpixel((px, py))
    
    print("Background at Create A Registry (x:0.5, y:0.57):", get_color(0.5, 0.57))
    print("Background at Find A Registry (x:0.5, y:0.47):", get_color(0.5, 0.47))
    print("Background at Categories Grid (x:0.5, y:0.35):", get_color(0.5, 0.35))
    print("Background at Category 'Cookware' (x:0.22, y:0.30):", get_color(0.22, 0.30))
    print("Background at Registry Header (x:0.5, y:0.88):", get_color(0.5, 0.88))
except Exception as e:
    print(e)
