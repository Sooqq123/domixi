# -*- coding: utf-8 -*-
"""
Top-Level System-on-Chip Simulation Framework.
Integrates DMA Core, DMA-Aware Bus Firewall IP, Interconnect & Memory Models.
Spec Version: V2.4.1 Clarification & Closure Baseline
"""

from typing import Dict, Any, List, Optional
import time
from model.config import SoCConfig, AXIResp, ErrorMode
from model.soc_components import DMACore, SystemMemory
from model.firewall_model import DMAAwareBusFirewall

class SoCSystemSimulator:
    """
    Cycle-Accurate SoC System Simulator.
    Simulates clock ticks, inter-module wiring, bus transactions, and performance metrics.
    """
    def __init__(self, config: Optional[SoCConfig] = None):
        self.config = config or SoCConfig()
        self.dma = DMACore(self.config)
        self.firewall = DMAAwareBusFirewall(self.config)
        self.main_mem = SystemMemory(size_bytes=16 * 1024 * 1024, base_addr=0x0000_0000, 
                                     read_latency=self.config.mem_read_latency_cycles,
                                     write_latency=self.config.mem_write_latency_cycles)
        
        # Interconnect & Memory FSM emulation state
        self.mem_read_pipeline: List[Dict[str, Any]] = []
        self.mem_write_pipeline: List[Dict[str, Any]] = []

        self.cycle_count = 0
        self.history_fifo_occupancy: List[int] = []

    def configure_firewall_static_region(self, index: int, base: int, limit: int, 
                                         read_en: bool = True, write_en: bool = True, 
                                         secure_only: bool = False, priv_only: bool = False, 
                                         whitelist_mid: int = 0, mid_mask: int = 0):
        perm = (1 << 31) | (1 if read_en else 0) | ((1 << 1) if write_en else 0) | \
               ((1 << 2) if secure_only else 0) | ((1 << 3) if priv_only else 0)
        mid_field = (whitelist_mid & 0x0F) | ((mid_mask & 0x0F) << 4)
        
        # Configure via APB write simulation (PPROT = 0b001 -> Secure Privileged)
        self.firewall.regs.write_apb(0x020 + 16 * index, base, 0b001)
        self.firewall.regs.write_apb(0x024 + 16 * index, limit, 0b001)
        self.firewall.regs.write_apb(0x028 + 16 * index, perm, 0b001)
        self.firewall.regs.write_apb(0x02C + 16 * index, mid_field, 0b001)

    def lock_firewall(self):
        """Execute Sticky Lock (NIST SP 800-193)"""
        self.firewall.regs.write_apb(0x004, 0x0000_0001, 0b001)

    def run_simulation(self, max_cycles: int = 50000) -> Dict[str, Any]:
        """
        Run cycle-by-cycle simulation until DMA completion or timeout.
        """
        start_time = time.perf_counter()
        
        # Memory response signals
        m_arready = True
        m_rvalid = False
        m_rdata = 0
        m_rlast = False
        m_rresp = AXIResp.OKAY

        m_awready = True
        m_wready = True
        m_bvalid = False
        m_bresp = AXIResp.OKAY
        m_bid = 0

        # Interconnect write buffers
        cur_write_addr = 0
        cur_write_len = 0
        cur_write_cnt = 0
        cur_write_id = 0
        in_write_burst = False

        # Interconnect read buffers
        cur_read_addr = 0
        cur_read_len = 0
        cur_read_cnt = 0
        in_read_burst = False
        read_delay_cnt = 0
        cur_read_id = 0
        m_rid = 0

        while self.cycle_count < max_cycles:
            self.cycle_count += 1
            self.history_fifo_occupancy.append(self.dma.fifo.count)
            b_was_valid = m_bvalid

            # 1. Update Sideband Channel (DMA Core -> Firewall)
            self.firewall.update_sideband_context(
                dma_valid=self.dma.dma_ctx_valid,
                dma_src=self.dma.dma_ctx_src_addr,
                dma_dst=self.dma.dma_ctx_dst_addr,
                dma_len=self.dma.dma_ctx_byte_len,
                dma_done=self.dma.dma_ctx_done
            )

            # 2. Step Firewall Cycle
            fw_out = self.firewall.step_cycle(
                s_awvalid=self.dma.aw_valid,
                s_awaddr=self.dma.aw_addr,
                s_awlen=self.dma.aw_len,
                s_awsize=2,
                s_awprot=0b001,
                s_awid=0,
                s_wvalid=self.dma.w_valid,
                s_wdata=self.dma.w_data,
                s_wlast=self.dma.w_last,
                s_bready=self.dma.b_ready,
                s_arvalid=self.dma.ar_valid,
                s_araddr=self.dma.ar_addr,
                s_arlen=self.dma.ar_len,
                s_arsize=2,
                s_arprot=0b001,
                s_arid=0,
                s_rready=self.dma.r_ready,
                m_awready=m_awready,
                m_wready=m_wready,
                m_bvalid=m_bvalid,
                m_bresp=m_bresp,
                m_arready=m_arready,
                m_rvalid=m_rvalid,
                m_rdata=m_rdata,
                m_rlast=m_rlast,
                m_rresp=m_rresp,
                m_bid=m_bid,
                m_rid=m_rid,
            )

            # 3. Step DMA Core Cycle
            self.dma.step_cycle(
                axi_arready=fw_out["s_arready"],
                axi_rvalid=fw_out["s_rvalid"],
                axi_rdata=fw_out["s_rdata"],
                axi_rlast=fw_out["s_rlast"],
                axi_rresp=fw_out["s_rresp"],
                axi_awready=fw_out["s_awready"],
                axi_wready=fw_out["s_wready"],
                axi_bvalid=fw_out["s_bvalid"],
                axi_bresp=fw_out["s_bresp"]
            )

            # 4. Memory & Interconnect Backend Processing
            # --- Write Channel ---
            if fw_out["m_awvalid"] and m_awready and not in_write_burst:
                cur_write_addr = fw_out["m_awaddr"]
                cur_write_len = fw_out["m_awlen"]
                cur_write_cnt = 0
                cur_write_id = fw_out["m_awid"]
                in_write_burst = True

            if in_write_burst and fw_out["m_wvalid"] and m_wready:
                self.main_mem.write_word(cur_write_addr + (cur_write_cnt * 4), fw_out["m_wdata"])
                cur_write_cnt += 1
                if fw_out["m_wlast"]:
                    in_write_burst = False
                    m_bvalid = True
                    m_bresp = AXIResp.OKAY
                    m_bid = cur_write_id

            # A response created by WLAST becomes visible on the next cycle;
            # only a BVALID that existed at cycle entry may handshake here.
            if b_was_valid and fw_out["m_bready"]:
                m_bvalid = False

            # --- Read Channel ---
            if fw_out["m_arvalid"] and m_arready and not in_read_burst:
                cur_read_addr = fw_out["m_araddr"]
                cur_read_len = fw_out["m_arlen"]
                cur_read_cnt = 0
                cur_read_id = fw_out["m_arid"]
                in_read_burst = True
                read_delay_cnt = self.config.mem_read_latency_cycles

            if in_read_burst:
                if m_rvalid and fw_out["m_rready"]:
                    cur_read_cnt += 1
                    if m_rlast:
                        in_read_burst = False
                        m_rvalid = False
                        m_rlast = False
                    else:
                        m_rdata = self.main_mem.read_word(cur_read_addr + (cur_read_cnt * 4))
                        m_rlast = (cur_read_cnt == cur_read_len)
                        m_rid = cur_read_id
                elif not m_rvalid:
                    if read_delay_cnt > 0:
                        read_delay_cnt -= 1
                    else:
                        m_rvalid = True
                        m_rdata = self.main_mem.read_word(cur_read_addr + (cur_read_cnt * 4))
                        m_rlast = (cur_read_cnt == cur_read_len)
                        m_rresp = AXIResp.OKAY
                        m_rid = cur_read_id

            # 5. Check Termination Conditions
            if self.dma.done_set_event or self.dma.error_set_event:
                self.firewall.update_sideband_context(
                    dma_valid=self.dma.dma_ctx_valid,
                    dma_src=self.dma.dma_ctx_src_addr,
                    dma_dst=self.dma.dma_ctx_dst_addr,
                    dma_len=self.dma.dma_ctx_byte_len,
                    dma_done=self.dma.dma_ctx_done
                )
                break

            # If a security violation occurred and DMA terminated/drained
            if self.firewall.regs.fault_count > 0 and not self.dma.status_busy and not in_write_burst and not in_read_burst:
                break

        elapsed_time = time.perf_counter() - start_time
        total_bytes = self.dma.total_write_beats * 4
        duration_ns = self.cycle_count * self.config.clock_period_ns
        throughput_gbps = (total_bytes / (duration_ns * 1e-9)) / 1e9 if duration_ns > 0 else 0.0

        avg_fifo_occ = sum(self.history_fifo_occupancy) / len(self.history_fifo_occupancy) if self.history_fifo_occupancy else 0.0

        return {
            "completed": self.dma.last_transfer_succeeded,
            "error": self.dma.status_error,
            "total_cycles": self.cycle_count,
            "duration_ns": duration_ns,
            "sim_wall_time_sec": elapsed_time,
            "total_bytes_transferred": total_bytes,
            "throughput_gb_per_sec": throughput_gbps,
            "throughput_mb_per_sec": throughput_gbps * 1000,
            "peak_fifo_occupancy": self.dma.fifo.peak_occupancy,
            "avg_fifo_occupancy": avg_fifo_occ,
            "fifo_full_stall_cycles": self.dma.read_stall_fifo_full_cycles,
            "fifo_empty_stall_cycles": self.dma.write_stall_fifo_empty_cycles,
            "fault_count": self.firewall.regs.fault_count,
            "sec_irq_asserted": self.firewall.regs.sec_irq,
            "first_fault_status": self.firewall.regs.fault_status,
            "first_fault_addr": hex(self.firewall.regs.fault_addr)
        }
