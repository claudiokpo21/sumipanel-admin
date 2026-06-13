import fitz
import os

doc = fitz.open(r'C:\Users\Claudiop\Downloads\taller XR190L.pdf')
out_dir = r'C:\Users\Claudiop\Documents\CV Automatizacion\xr190l_pages'
os.makedirs(out_dir, exist_ok=True)

# Render at high DPI for quality
zoom = 3.0  # 3x = ~216 DPI
mat = fitz.Matrix(zoom, zoom)

# Pages of interest: ECM pinout, sensor inspections, wiring diagrams
pages = [
    21, 22, 23, 24,    # routing (1-17 to 1-22)
    91, 92,             # ECM troubleshooting + 33p connector
    93, 94, 95, 96, 97, 98, 99, 100,  # MAP, EOT, TP, IAT sensor inspection
    101, 102, 103, 104, 105, 106, 107,  # INJ, O2, IACV, ECM replacement
    109, 110, 111, 112,  # ignition, charging, starter
    119, 120, 121, 122, 123, 124,  # charging system, fuel level
    135, 136, 137, 138, 139,     # addendum routing
    155, 156, 157,                # wiring diagram + colors
]

for p in pages:
    if p > len(doc):
        continue
    page = doc[p-1]
    pix = page.get_pixmap(matrix=mat, alpha=False)
    out_path = os.path.join(out_dir, f'page_{p:03d}.png')
    pix.save(out_path)
    print(f'Saved p{p} -> {out_path} ({pix.width}x{pix.height})')
