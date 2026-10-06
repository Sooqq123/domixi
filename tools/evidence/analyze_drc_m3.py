import xml.etree.ElementTree as ET
import re

for top in ['sky130_dma_bus_firewall', 'sky130_aegis_soc_top']:
    rpt = f'/mnt/d/domixi/output/physical/{top}/klayout_drc.rpt'
    tree = ET.parse(rpt)
    root = tree.getroot()
    items = [item for item in root.findall('.//item') if item.findtext('category') == "'m3.6'"]
    dims = set()
    for it in items:
        val = it.findtext('values/value')
        pts = re.findall(r'([\d.]+),([\d.]+)', val)
        xs = [float(p[0]) for p in pts]
        ys = [float(p[1]) for p in pts]
        w = round(max(xs) - min(xs), 4)
        h = round(max(ys) - min(ys), 4)
        dims.add((w, h))
    print(f"{top}: Total {len(items)} items. Distinct bounding box (W, H): {dims}")
