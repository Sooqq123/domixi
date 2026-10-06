import os
import sys
import pya

def main():
    print('[INFO] Starting DEF to GDSII stream-out in KLayout...')
    tech = pya.Technology()
    tech.load(tech_file)
    layout_options = tech.load_layout_options
    layout_options.lefdef_config.macro_resolution_mode = 1
    layout_options.lefdef_config.read_lef_with_def = False
    layout_options.lefdef_config.lef_files = lef_files.split(';')
    layout_options.lefdef_config.map_file = map_file

    main_layout = pya.Layout()
    print(f'[INFO] Reading DEF: {def_file}')
    main_layout.read(def_file, layout_options)

    top_cell_obj = main_layout.cell(top_cell)
    if top_cell_obj is None:
        raise ValueError(f'Top cell {top_cell} not found in DEF')
    top_cell_index = top_cell_obj.cell_index()

    print('[INFO] Clearing placeholder cells...')
    for cell in main_layout.each_cell():
        if cell.cell_index() != top_cell_index:
            if not cell.name.startswith('VIA'):
                cell.clear()

    print('[INFO] Merging library GDS files...')
    for gds in gds_files.split(';'):
        if os.path.exists(gds):
            print(f'  Reading library GDS: {gds}')
            main_layout.read(gds)

    print(f'[INFO] Creating clean top layout for {top_cell}...')
    top_only_layout = pya.Layout()
    top_only_layout.dbu = main_layout.dbu
    top = top_only_layout.create_cell(top_cell)
    top.copy_tree(main_layout.cell(top_cell))

    print(f'[INFO] Writing GDSII: {gds_file}')
    top_only_layout.write(gds_file)
    print(f'[INFO] Stream-out successful: {gds_file}')

try:
    main()
except Exception:
    import traceback
    traceback.print_exc()
    pya.Application.instance().exit(1)
else:
    pya.Application.instance().exit(0)
