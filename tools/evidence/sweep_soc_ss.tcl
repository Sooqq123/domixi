read_liberty /home/nhat/.ciel/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ss_100C_1v60.lib
read_db /mnt/d/domixi/output/physical/sky130_aegis_soc_top/aegis_soc_top.odb
read_spef /mnt/d/domixi/output/physical/sky130_aegis_soc_top/aegis_soc_top.spef
read_sdc /mnt/d/domixi/output/physical/sky130_aegis_soc_top/aegis_soc_top.sdc

foreach p {25.0 35.0 45.0 50.0 52.0 55.0} {
    create_clock -name clk -period $p [get_ports clk]
    set_propagated_clock [all_clocks]
    puts -nonewline ">>> SoC Period ${p}ns: "
    report_worst_slack -max
}
exit
