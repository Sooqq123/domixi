import re
import sys

def convert_verilog_to_spice(layout_spice_path, verilog_path, output_spice_path, top_name):
    # 1. Read layout spice headers
    subckts = []
    top_header_lines = []
    cell_pin_order = {}
    
    with open(layout_spice_path, 'r') as f:
        in_top = False
        for line in f:
            line_s = line.strip()
            if line_s.startswith(f'.subckt {top_name}'):
                in_top = True
                top_header_lines.append(line)
            elif in_top:
                if line.startswith('+'):
                    top_header_lines.append(line)
                else:
                    break
            elif line_s.startswith('.subckt sky130_fd_sc_hd__'):
                parts = line_s.split()
                if any(p in parts[1] for p in ['fill', 'tapvpwrvgnd', 'decap']):
                    continue
                subckts.append(line)
                cell_pin_order[parts[1]] = parts[2:]
            elif not in_top:
                if not any(p in line_s for p in ['fill', 'tapvpwrvgnd', 'decap']):
                    subckts.append(line)

    print(f'Found {len(cell_pin_order)} cell templates')
    
    top_ports = set(' '.join(top_header_lines).split()[2:])
    print(f'Found {len(top_ports)} top-level ports in {top_name}')
    
    # 2. Parse Verilog instances
    with open(verilog_path, 'r') as f:
        v_text = f.read()

    # Find assign statements
    assigns = re.findall(r'assign\s+([^=]+)=\s*([^;]+);', v_text)
    print(f'Found {len(assigns)} assign statements')

    alias_map = {}
    port_shorts = []
    # Count occurrences in layout to pick the primary port name that cells attach to
    with open(layout_spice_path, 'r') as lf:
        layout_text = lf.read()

    for lhs, rhs in assigns:
        lhs_clean = lhs.strip().lstrip('\\').replace(' ', '')
        rhs_clean = rhs.strip().lstrip('\\').replace(' ', '')
        if lhs_clean in top_ports and rhs_clean in top_ports:
            # Pick whichever is the primary net in layout
            c_lhs = layout_text.count(lhs_clean)
            c_rhs = layout_text.count(rhs_clean)
            if c_lhs >= c_rhs:
                primary, secondary = lhs_clean, rhs_clean
            else:
                primary, secondary = rhs_clean, lhs_clean
            alias_map[secondary] = primary
            port_shorts.append((primary, secondary))
        elif lhs_clean in top_ports:
            alias_map[rhs_clean] = lhs_clean
        elif rhs_clean in top_ports:
            alias_map[lhs_clean] = rhs_clean
        else:
            alias_map[lhs_clean] = rhs_clean

    print(f'Identified {len(port_shorts)} top-level port shorts and {len(alias_map)} internal wire aliases')

    # Find instances
    inst_pattern = re.compile(r'(sky130_fd_sc_hd__\w+)\s+(\S+)\s*\((.*?)\);', re.DOTALL)
    
    out_lines = []
    out_lines.extend(subckts)
    out_lines.extend(top_header_lines)
    
    inst_count = 0
    for m in inst_pattern.finditer(v_text):
        cell_type = m.group(1)
        if any(p in cell_type for p in ['fill', 'tapvpwrvgnd', 'decap']):
            continue
        raw_name = m.group(2).lstrip('\\').rstrip()
        conn_text = m.group(3)
        
        # Parse port connections
        conns = {}
        for p in re.finditer(r'\.(\w+)\s*\(\s*([^)]*?)\s*\)', conn_text):
            pin_name = p.group(1)
            net_val = p.group(2).strip().lstrip('\\').rstrip()
            conns[pin_name] = net_val
            
        # Get expected pin order for this cell
        expected_pins = cell_pin_order.get(cell_type, [])
        if not expected_pins:
            continue
            
        safe_name = raw_name.replace('/', '_')
        spice_inst_name = 'X' + safe_name
        pin_nets = []
        for p in expected_pins:
            if p in conns:
                net_name = conns[p].replace(' ', '')
                net_name = alias_map.get(net_name, net_name)
                pin_nets.append(net_name)
            elif p in ('VGND', 'VNB'):
                pin_nets.append('VGND')
            elif p in ('VPWR', 'VPB'):
                pin_nets.append('VPWR')
            else:
                dummy = f'{safe_name}/{p}'
                pin_nets.append(dummy)
                
        out_lines.append(f'{spice_inst_name} {" ".join(pin_nets)} {cell_type}\n')
        inst_count += 1
        
    print(f'Converted {inst_count} instances to SPICE')
    
    # Add zero-ohm resistors for top-level shorted ports
    for idx, (primary, secondary) in enumerate(port_shorts):
        out_lines.append(f'R_short_{secondary} {primary} {secondary} 0\n')
        
    out_lines.append('.ends\n')
    
    with open(output_spice_path, 'w', encoding='utf-8') as f:
        f.writelines(out_lines)
        
    print(f'Successfully wrote clean schematic SPICE to {output_spice_path}')

if __name__ == '__main__':
    layout_spice = sys.argv[1]
    verilog = sys.argv[2]
    out_spice = sys.argv[3]
    top = sys.argv[4]
    convert_verilog_to_spice(layout_spice, verilog, out_spice, top)