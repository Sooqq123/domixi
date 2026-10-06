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

def generate_reports():
    configs = [
        ("sky130_dma_bus_firewall", "dma_bus_firewall", 25.000, "40mhz", "40.00 MHz"),
        ("sky130_dma_bus_firewall", "dma_bus_firewall", 26.315, "38mhz", "38.00 MHz"),
        ("sky130_aegis_soc_top", "aegis_soc_top", 25.000, "40mhz", "40.00 MHz"),
        ("sky130_aegis_soc_top", "aegis_soc_top", 26.315, "38mhz", "38.00 MHz"),
    ]
    
    for dir_name, top, period, tag, label in configs:
        out_rpt = f"/mnt/d/domixi/output/physical/{dir_name}/sta_tt_025C_1v80_{tag}.rpt"
        print(f"Generating {out_rpt} for {top} at {label} ({period} ns)...")
        
        tcl = f"""
read_liberty {LIB_PATH}
read_db /mnt/d/domixi/output/physical/{dir_name}/{top}.odb
read_spef /mnt/d/domixi/output/physical/{dir_name}/{top}.spef
read_sdc /mnt/d/domixi/output/physical/{dir_name}/{top}.sdc

create_clock -name clk -period {period:.3f} [get_ports clk]
set_propagated_clock [all_clocks]
set_case_analysis 0 [get_ports test_mode]
set_false_path -from [get_ports test_mode]

puts "\\n========================================================"
puts ">>> TYPICAL TT CORNER (1.80V, 25C, {period:.3f}ns / {label}) FOR {top}"
puts "========================================================"
report_checks -path_delay max -fields {{slew cap input fanout}} -digits 3

puts "\\n>>> HOLD CHECKS FOR TT CORNER ({top}):"
report_checks -path_delay min -fields {{slew cap input fanout}} -digits 3

puts "\\n>>> SLACK SUMMARY AT {period:.3f}ns ({label}):"
puts -nonewline "worst slack max "
report_worst_slack -max
puts -nonewline "tns max "
report_tns -max
puts -nonewline "worst slack min "
report_worst_slack -min
puts -nonewline "tns min "
report_tns -min

exit
"""
        out = run_openroad_tcl(tcl)
        target_path = Path(f"D:/domixi/output/physical/{dir_name}/sta_tt_025C_1v80_{tag}.rpt")
        target_path.write_text(out, encoding="utf-8")
        print(f"Saved: {target_path} ({len(out)} bytes)")

if __name__ == "__main__":
    generate_reports()
