import subprocess
from pathlib import Path

LIB_PATH = "/home/nhat/.ciel/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"

def run_openroad_tcl(tcl_content: str) -> str:
    cmd = [
        "wsl", "-e",
        "/home/nhat/AIHDL/OpenROAD/build/bin/openroad",
        "-exit", "-no_splash"
    ]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    out, _ = p.communicate(input=tcl_content)
    return out

def generate_internal_report():
    tcl = f"""
read_liberty {LIB_PATH}
read_db /mnt/d/domixi/output/physical/sky130_dma_bus_firewall/dma_bus_firewall.odb
read_spef /mnt/d/domixi/output/physical/sky130_dma_bus_firewall/dma_bus_firewall.spef
read_sdc /mnt/d/domixi/output/physical/sky130_dma_bus_firewall/dma_bus_firewall.sdc

set_propagated_clock [all_clocks]
set_case_analysis 0 [get_ports test_mode]
set_false_path -from [get_ports test_mode]

puts "\\n========================================================"
puts ">>> TYPICAL TT CORNER (1.80V, 25C, 26.315ns / 38.00 MHz) INTERNAL FLOP-TO-FLOP TIMING FOR dma_bus_firewall"
puts "========================================================"
puts "\\n>>> INTERNAL SETUP CHECKS (FLOP-TO-FLOP):"
report_checks -path_delay max -from [all_registers] -to [all_registers] -fields {{slew cap input fanout}} -digits 3

puts "\\n>>> INTERNAL HOLD CHECKS (FLOP-TO-FLOP):"
report_checks -path_delay min -from [all_registers] -to [all_registers] -fields {{slew cap input fanout}} -digits 3

exit
"""
    out = run_openroad_tcl(tcl)
    target_path = Path("D:/domixi/output/physical/sky130_dma_bus_firewall/sta_tt_025C_1v80_38mhz_internal.rpt")
    target_path.write_text(out, encoding="utf-8")
    print(f"Saved: {target_path} ({len(out)} bytes)")

if __name__ == "__main__":
    generate_internal_report()
