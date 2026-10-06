import os
import sys
import xml.etree.ElementTree as ET
import re
import pya

def patch_gds_from_report(rpt_file, in_gds, out_gds, top_name):
    print(f"[PATCH] Parsing DRC report: {rpt_file}")
    tree = ET.parse(rpt_file)
    root = tree.getroot()
    items = [it for it in root.findall('.//item') if it.findtext('category') == "'m3.6'"]
    print(f"[PATCH] Found {len(items)} m3.6 violation items.")

    layout = pya.Layout()
    layout.read(in_gds)
    top = layout.cell(top_name)
    if not top:
        top = layout.top_cell()
    dbu = layout.dbu
    m3_layer = layout.layer(70, 20)

    # Extension delta: 80 nm = 0.080 um
    dx = int(round(0.080 / dbu))

    count = 0
    for it in items:
        val = it.findtext('values/value')
        pts = re.findall(r'([\d.]+),([\d.]+)', val)
        xs = [float(p[0]) for p in pts]
        ys = [float(p[1]) for p in pts]
        xmin = int(round(min(xs) / dbu))
        xmax = int(round(max(xs) / dbu))
        ymin = int(round(min(ys) / dbu))
        ymax = int(round(max(ys) / dbu))

        patch_box = pya.Box(xmin - dx, ymin, xmax + dx, ymax)
        top.shapes(m3_layer).insert(patch_box)
        count += 1

    print(f"[PATCH] Inserted {count} patch shapes into layer 70/20 of cell {top_name}.")
    layout.write(out_gds)
    print(f"[PATCH] Saved patched GDS to {out_gds}.")

def main():
    _rpt = globals().get('rpt_file')
    _in = globals().get('in_gds')
    _out = globals().get('out_gds')
    _top = globals().get('top_name')
    if not (_rpt and _in and _out and _top):
        if len(sys.argv) >= 5:
            _rpt, _in, _out, _top = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
        else:
            print("Usage: patch_drc_m3_from_rpt.py <rpt> <in_gds> <out_gds> <top_name>")
            pya.Application.instance().exit(1)
            return
    patch_gds_from_report(_rpt, _in, _out, _top)
    pya.Application.instance().exit(0)

if __name__ == "__main__":
    main()
