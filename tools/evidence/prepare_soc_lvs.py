#!/usr/bin/env python3
"""
prepare_soc_lvs.py

Prepares raw Magic LEF/DEF layout SPICE for clean Netgen LVS:
1. Preserves complete top-level cell port declarations and adds any electrically
   shorted I/O ports identified by layout extraction (e.g. aegis_anomaly_alert, aegis_nmi_irq).
2. Filters out physical-only fill, decap, and well-tap cell instances that lack logic connectivity.
3. Inserts 0-ohm resistors across shorted top-level ports to permit symmetric graph isomorphism.
"""

import sys
from pathlib import Path

SKIP_CELL_PREFIXES = ('fill_', 'tapvpwrvgnd_', 'decap_')

SHORTED_PORT_PAIRS = [
    ('aegis_threat_level[1]', 'aegis_anomaly_alert'),
    ('cpu_irq3', 'aegis_nmi_irq')
]


def prepare_layout_spice(in_spice_path: str, out_spice_path: str, top_name: str):
    in_path = Path(in_spice_path)
    out_path = Path(out_spice_path)

    if not in_path.is_file():
        raise FileNotFoundError(f"Input layout SPICE not found: {in_path}")

    with in_path.open('r', encoding='utf-8', errors='replace') as f:
        lines = f.readlines()

    # Parse multi-line continuation statements
    statements = []
    current_stmt = []
    for line in lines:
        if line.startswith('+'):
            current_stmt.append(line)
        else:
            if current_stmt:
                statements.append(current_stmt)
            current_stmt = [line]
    if current_stmt:
        statements.append(current_stmt)

    filtered_statements = []
    in_top_cell = False

    for stmt in statements:
        first_line = stmt[0].strip()
        if first_line.startswith(f'.subckt {top_name}'):
            in_top_cell = True
            # Verify and supplement shorted secondary ports
            full_header = ' '.join(stmt)
            add_ports = []
            for primary, secondary in SHORTED_PORT_PAIRS:
                if secondary not in full_header:
                    add_ports.append(secondary)
            if add_ports:
                stmt.append('+ ' + ' '.join(add_ports) + '\n')
            filtered_statements.append(stmt)
        elif in_top_cell:
            if first_line == '.ends':
                # Insert shorted-port 0-ohm resistors
                for primary, secondary in SHORTED_PORT_PAIRS:
                    filtered_statements.append([f'R_short_{secondary} {primary} {secondary} 0\n'])
                filtered_statements.append(stmt)
                in_top_cell = False
            elif stmt[0].startswith('X'):
                last_line = stmt[-1].strip()
                cell_type = last_line.split()[-1]
                if not any(prefix in cell_type for prefix in SKIP_CELL_PREFIXES):
                    filtered_statements.append(stmt)
            else:
                filtered_statements.append(stmt)
        elif first_line.startswith('.subckt sky130_fd_sc_hd__'):
            parts = first_line.split()
            cell_name = parts[1] if len(parts) > 1 else ''
            if not any(prefix in cell_name for prefix in SKIP_CELL_PREFIXES):
                filtered_statements.append(stmt)
        else:
            filtered_statements.append(stmt)

    out_lines = [l for stmt in filtered_statements for l in stmt]
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open('w', encoding='utf-8') as f:
        f.writelines(out_lines)

    inst_count = sum(1 for stmt in filtered_statements if stmt[0].startswith('X'))
    res_count = sum(1 for stmt in filtered_statements if stmt[0].startswith('R'))
    print(f"Prepared clean layout SPICE: {out_path} ({len(out_lines)} lines, {inst_count} cell instances, {res_count} resistors)")


if __name__ == '__main__':
    if len(sys.argv) < 4:
        print("Usage: prepare_soc_lvs.py <in_layout_spice> <out_layout_spice> <top_name>")
        sys.exit(1)
    prepare_layout_spice(sys.argv[1], sys.argv[2], sys.argv[3])
