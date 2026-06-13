import asyncio
from playwright.async_api import async_playwright

async def render():
    svg_path = r'C:\Users\Claudiop\Documents\CV Automatizacion\XR190L_wiring_diagram.svg'
    out_path = r'C:\Users\Claudiop\Documents\CV Automatizacion\XR190L_preview.png'

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        page = await browser.new_page(viewport={'width': 2000, 'height': 1300})
        # Wrap SVG in HTML
        html = f'''
        <html><head><style>body{{margin:0;padding:0;background:white;}} svg{{display:block;}}</style></head>
        <body>
        <object type="image/svg+xml" data="file:///{svg_path.replace(chr(92), '/')}" width="1800" height="1200"></object>
        </body></html>
        '''
        html_path = r'C:\Users\Claudiop\Documents\CV Automatizacion\xr_preview.html'
        with open(html_path, 'w', encoding='utf-8') as f:
            f.write(html)
        await page.goto(f'file:///{html_path.replace(chr(92), "/")}')
        await page.wait_for_timeout(2000)
        await page.screenshot(path=out_path, full_page=True, timeout=120000, animations='disabled')
        await browser.close()
    print(f'Saved {out_path}')

asyncio.run(render())
