import re

src = 'output/physical/sky130_aegis_soc_top/aegis_soc_top.sdf'
dst = 'output/physical/sky130_aegis_soc_top/aegis_soc_top_cells.sdf'

print(f'Processing {src} -> {dst}...')
with open(src, 'r') as fin, open(dst, 'w') as fout:
    in_top_cell = False
    for line in fin:
        if '(CELLTYPE "aegis_soc_top")' in line:
            in_top_cell = True
            continue
        if in_top_cell:
            if line.strip() == '(CELL':
                in_top_cell = False
            else:
                continue
        # Convert (a::b) to (a:b:b)
        line = re.sub(r'\((\d+\.?\d*)::(\d+\.?\d+)\)', r'(\1:\2:\2)', line)
        line = re.sub(r'\((\d+\.?\d+):(\d+\.?\d+)\)', r'(\1:\2:\2)', line)
        fout.write(line)

print('Done generating aegis_soc_top_cells.sdf')
