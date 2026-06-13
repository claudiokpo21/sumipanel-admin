import fitz
import os

doc = fitz.open(r'C:\Users\Claudiop\Downloads\taller XR190L.pdf')
out_dir = r'C:\Users\Claudiop\Documents\CV Automatizacion\xr190l_pages'
os.makedirs(out_dir, exist_ok=True)

zoom = 3.0
mat = fitz.Matrix(zoom, zoom)

for p in [113, 114, 115, 116, 117, 118, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134]:
    page = doc[p-1]
    pix = page.get_pixmap(matrix=mat, alpha=False)
    out_path = os.path.join(out_dir, f'page_{p:03d}.png')
    pix.save(out_path)
    print(f'Saved p{p}')
