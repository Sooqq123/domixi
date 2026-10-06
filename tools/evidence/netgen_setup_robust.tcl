# Source base sky130A setup
if {[info exists env(PDK_ROOT)] && [file exists "$env(PDK_ROOT)/sky130A/libs.tech/netgen/sky130A_setup.tcl"]} {
    source "$env(PDK_ROOT)/sky130A/libs.tech/netgen/sky130A_setup.tcl"
} else {
    source /home/nhat/.ciel/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.tech/netgen/sky130A_setup.tcl
}

# Robustly ignore all physical-only cells in circuit 1 and 2
set physical_cells {
    sky130_fd_sc_hd__fill_1
    sky130_fd_sc_hd__fill_2
    sky130_fd_sc_hd__fill_4
    sky130_fd_sc_hd__fill_8
    sky130_fd_sc_hd__tapvpwrvgnd_1
    sky130_fd_sc_hd__decap_3
    sky130_fd_sc_hd__decap_4
    sky130_fd_sc_hd__decap_6
    sky130_fd_sc_hd__decap_8
    sky130_fd_sc_hd__decap_12
    sky130_fd_sc_hd__diode_2
}

foreach pcell $physical_cells {
    catch {ignore class "-circuit1 $pcell"}
    catch {ignore class "-circuit2 $pcell"}
}

# Equate shorted top-level ports in firewall
catch {equate nodes "-circuit2 dma_bus_firewall/aegis_threat_level\[1\]" "-circuit2 dma_bus_firewall/aegis_anomaly_alert"}
catch {equate nodes "-circuit1 dma_bus_firewall/aegis_threat_level\[1\]" "-circuit1 dma_bus_firewall/aegis_anomaly_alert"}

# Equate shorted top-level ports in SoC (NMI reflex loop: aegis_nmi_irq to cpu_irq3)
catch {equate nodes "-circuit2 aegis_soc_top/cpu_irq3" "-circuit2 aegis_soc_top/aegis_nmi_irq"}
catch {equate nodes "-circuit1 aegis_soc_top/cpu_irq3" "-circuit1 aegis_soc_top/aegis_nmi_irq"}
catch {equate nodes "-circuit2 aegis_soc_top/aegis_threat_level\[1\]" "-circuit2 aegis_soc_top/aegis_anomaly_alert"}
catch {equate nodes "-circuit1 aegis_soc_top/aegis_threat_level\[1\]" "-circuit1 aegis_soc_top/aegis_anomaly_alert"}

# Explicitly match top-level cell pins by name
catch {equate pins "-circuit1 dma_bus_firewall" "-circuit2 dma_bus_firewall"}
catch {equate pins "-circuit1 aegis_soc_top" "-circuit2 aegis_soc_top"}

# Permute shorted top-level pins to allow symmetric matching
catch {permute "-circuit1 dma_bus_firewall" {aegis_threat_level[1]} aegis_anomaly_alert}
catch {permute "-circuit2 dma_bus_firewall" {aegis_threat_level[1]} aegis_anomaly_alert}
catch {permute "-circuit1 aegis_soc_top" {aegis_threat_level[1]} aegis_anomaly_alert}
catch {permute "-circuit2 aegis_soc_top" {aegis_threat_level[1]} aegis_anomaly_alert}
catch {permute "-circuit1 aegis_soc_top" cpu_irq3 aegis_nmi_irq}
catch {permute "-circuit2 aegis_soc_top" cpu_irq3 aegis_nmi_irq}