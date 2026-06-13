import fitz
import sys

doc = fitz.open(r'C:\Users\Claudiop\Downloads\taller XR190L.pdf')
print(f'Total pages: {len(doc)}', file=sys.stderr)

mode = sys.argv[1] if len(sys.argv) > 1 else 'all'

if mode == 'index':
    # First 15 pages (cover, index, info)
    for i in range(min(15, len(doc))):
        page = doc[i]
        text = page.get_text()
        print(f'===== PAGE {i+1} =====')
        print(text)
        print()
elif mode == 'search':
    # Search for wiring/ECU keywords across the document
    keywords = ['wiring', 'wire', 'harness', 'ECU', 'ECM', 'FI control', 'ignition coil', 'cable', 'color', 'colour', 'wiring diagram', 'pin', 'conector']
    for i, page in enumerate(doc):
        text = page.get_text().lower()
        for kw in keywords:
            if kw.lower() in text:
                # Get surrounding context
                idx = text.find(kw.lower())
                snippet = text[max(0, idx-50):idx+150]
                print(f'p{i+1}: kw={kw!r}  ...{snippet}...')
                break
elif mode == 'all':
    # Dump all pages text
    with open(r'C:\Users\Claudiop\Documents\CV Automatizacion\xr190l_full.txt', 'w', encoding='utf-8') as f:
        for i, page in enumerate(doc):
            text = page.get_text()
            f.write(f'\n===== PAGE {i+1} =====\n')
            f.write(text)
    print('Done', file=sys.stderr)
