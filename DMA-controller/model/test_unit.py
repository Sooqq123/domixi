# -*- coding: utf-8 -*-
"""
Unit Tests for System-Level Architectural Components.
Spec Version: V2.4.1 Clarification & Closure Baseline
"""

import sys
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding='utf-8')

import unittest
from model.config import SoCConfig, AXIResp, ErrorMode
from model.soc_components import DMACore, SynchronousFIFO, SystemMemory
from model.golden_ref import GoldenFirewallEngine, GoldenACLRegion
from model.firewall_model import APBRegisterFile, FaultRecord, WriteDrainFSM, ReadDrainFSM, DMAAwareBusFirewall

class TestUnitComponents(unittest.TestCase):

    def test_default_fifo_depth_matches_architecture(self):
        self.assertEqual(SoCConfig().fifo_depth, 32)
        self.assertEqual(SynchronousFIFO().depth, 32)

    def test_dma_waits_for_aw_handshake_before_w_and_fifo_pop(self):
        core = DMACore(SoCConfig())
        core.fifo.push(0x1234_5678)
        self.assertTrue(core.start_transfer(0x1000, 0x2000, 4))

        core.step_cycle(
            axi_arready=False, axi_rvalid=False, axi_rdata=0, axi_rlast=False, axi_rresp=AXIResp.OKAY,
            axi_awready=False, axi_wready=True, axi_bvalid=False, axi_bresp=AXIResp.OKAY,
        )
        core.step_cycle(
            axi_arready=False, axi_rvalid=False, axi_rdata=0, axi_rlast=False, axi_rresp=AXIResp.OKAY,
            axi_awready=False, axi_wready=True, axi_bvalid=False, axi_bresp=AXIResp.OKAY,
        )
        self.assertTrue(core.aw_valid)
        self.assertFalse(core.w_valid)
        self.assertEqual(core.fifo.count, 1)

        core.step_cycle(
            axi_arready=False, axi_rvalid=False, axi_rdata=0, axi_rlast=False, axi_rresp=AXIResp.OKAY,
            axi_awready=True, axi_wready=False, axi_bvalid=False, axi_bresp=AXIResp.OKAY,
        )
        self.assertTrue(core.aw_accepted)
        self.assertFalse(core.w_valid)
        self.assertEqual(core.fifo.count, 1)

        core.step_cycle(
            axi_arready=False, axi_rvalid=False, axi_rdata=0, axi_rlast=False, axi_rresp=AXIResp.OKAY,
            axi_awready=False, axi_wready=False, axi_bvalid=False, axi_bresp=AXIResp.OKAY,
        )
        self.assertTrue(core.w_valid)
        self.assertEqual(core.fifo.count, 0)

    def test_dma_start_busy_noop_and_sticky_status_w1c(self):
        core = DMACore(SoCConfig())
        core.status_done = True
        core.status_error = True
        self.assertTrue(core.start_transfer(0x1000, 0x2000, 4))
        core.step_cycle(
            axi_arready=False, axi_rvalid=False, axi_rdata=0, axi_rlast=False, axi_rresp=AXIResp.OKAY,
            axi_awready=False, axi_wready=False, axi_bvalid=False, axi_bresp=AXIResp.OKAY,
        )
        self.assertTrue(core.status_done)
        self.assertTrue(core.status_error)
        active_descriptor = (
            core.dma_ctx_src_addr,
            core.dma_ctx_dst_addr,
            core.dma_ctx_byte_len,
        )

        self.assertFalse(core.start_transfer(0x3000, 0x4000, 64))
        self.assertEqual(
            active_descriptor,
            (core.dma_ctx_src_addr, core.dma_ctx_dst_addr, core.dma_ctx_byte_len),
        )

        core.clear_status(done=True)
        self.assertFalse(core.status_done)
        self.assertTrue(core.status_error)
        core.clear_status(error=True)
        self.assertFalse(core.status_error)

        invalid = DMACore(SoCConfig())
        invalid.status_error = True
        invalid.clear_status(error=True)
        self.assertTrue(invalid.start_transfer(0x1001, 0x2000, 4))
        invalid.step_cycle(
            axi_arready=False, axi_rvalid=False, axi_rdata=0, axi_rlast=False, axi_rresp=AXIResp.OKAY,
            axi_awready=False, axi_wready=False, axi_bvalid=False, axi_bresp=AXIResp.OKAY,
        )
        self.assertTrue(invalid.status_error)
        self.assertTrue(invalid.error_set_event)
        self.assertFalse(invalid.status_busy)

    def test_dma_rresp_error_drains_to_rlast_then_aborts(self):
        core = DMACore(SoCConfig())
        self.assertTrue(core.start_transfer(0x1000, 0x2000, 8))
        core.step_cycle(
            axi_arready=False, axi_rvalid=False, axi_rdata=0, axi_rlast=False, axi_rresp=AXIResp.OKAY,
            axi_awready=False, axi_wready=False, axi_bvalid=False, axi_bresp=AXIResp.OKAY,
        )
        core.step_cycle(
            axi_arready=True, axi_rvalid=False, axi_rdata=0, axi_rlast=False, axi_rresp=AXIResp.OKAY,
            axi_awready=False, axi_wready=False, axi_bvalid=False, axi_bresp=AXIResp.OKAY,
        )
        core.step_cycle(
            axi_arready=False, axi_rvalid=True, axi_rdata=0xAAAA, axi_rlast=False, axi_rresp=AXIResp.SLVERR,
            axi_awready=False, axi_wready=False, axi_bvalid=False, axi_bresp=AXIResp.OKAY,
        )
        self.assertTrue(core.abort_pending)
        self.assertTrue(core.status_busy)
        self.assertEqual(core.fifo.count, 0)
        self.assertTrue(core.r_ready)

        core.step_cycle(
            axi_arready=False, axi_rvalid=True, axi_rdata=0xBBBB, axi_rlast=True, axi_rresp=AXIResp.OKAY,
            axi_awready=False, axi_wready=False, axi_bvalid=False, axi_bresp=AXIResp.OKAY,
        )
        self.assertFalse(core.status_busy)
        self.assertTrue(core.status_error)
        self.assertFalse(core.done_set_event)
        self.assertTrue(core.error_set_event)
        self.assertTrue(core.dma_ctx_done)
        self.assertTrue(core.fifo.empty)

    def test_dma_early_rlast_aborts_and_closes_read(self):
        core = DMACore(SoCConfig())
        self.assertTrue(core.start_transfer(0x1000, 0x2000, 8))
        core.step_cycle(False, False, 0, False, AXIResp.OKAY, False, False, False, AXIResp.OKAY)
        core.step_cycle(True, False, 0, False, AXIResp.OKAY, False, False, False, AXIResp.OKAY)

        core.step_cycle(False, True, 0xAAAA, True, AXIResp.OKAY, False, False, False, AXIResp.OKAY)

        self.assertFalse(core.status_busy)
        self.assertTrue(core.status_error)
        self.assertTrue(core.error_set_event)
        self.assertFalse(core.done_set_event)
        self.assertTrue(core.dma_ctx_done)
        self.assertTrue(core.fifo.empty)

    def test_dma_missing_final_rlast_aborts_at_expected_beat(self):
        core = DMACore(SoCConfig())
        self.assertTrue(core.start_transfer(0x1000, 0x2000, 8))
        core.step_cycle(False, False, 0, False, AXIResp.OKAY, False, False, False, AXIResp.OKAY)
        core.step_cycle(True, False, 0, False, AXIResp.OKAY, False, False, False, AXIResp.OKAY)
        core.step_cycle(False, True, 0xAAAA, False, AXIResp.OKAY, False, False, False, AXIResp.OKAY)
        self.assertTrue(core.status_busy)
        self.assertEqual(core.fifo.count, 1)

        core.step_cycle(False, True, 0xBBBB, False, AXIResp.OKAY, False, False, False, AXIResp.OKAY)

        self.assertFalse(core.status_busy)
        self.assertTrue(core.status_error)
        self.assertTrue(core.error_set_event)
        self.assertFalse(core.done_set_event)
        self.assertTrue(core.dma_ctx_done)
        self.assertTrue(core.fifo.empty)

    def test_dma_bresp_error_aborts_after_committed_write(self):
        core = DMACore(SoCConfig())
        self.assertTrue(core.start_transfer(0x1000, 0x2000, 4))
        core.step_cycle(False, False, 0, False, AXIResp.OKAY, False, False, False, AXIResp.OKAY)
        core.step_cycle(True, False, 0, False, AXIResp.OKAY, False, False, False, AXIResp.OKAY)
        core.step_cycle(False, True, 0xCAFE_BABE, True, AXIResp.OKAY, False, False, False, AXIResp.OKAY)
        core.step_cycle(False, False, 0, False, AXIResp.OKAY, True, False, False, AXIResp.OKAY)
        core.step_cycle(False, False, 0, False, AXIResp.OKAY, False, False, False, AXIResp.OKAY)
        core.step_cycle(False, False, 0, False, AXIResp.OKAY, False, True, False, AXIResp.OKAY)
        core.step_cycle(False, False, 0, False, AXIResp.OKAY, False, False, True, AXIResp.SLVERR)

        self.assertFalse(core.status_busy)
        self.assertTrue(core.status_error)
        self.assertTrue(core.error_set_event)
        self.assertTrue(core.dma_ctx_done)
        self.assertTrue(core.fifo.empty)

    def test_dma_sideband_v2_interface(self):
        core = DMACore(SoCConfig())
        for signal in ("dma_ctx_valid", "dma_ctx_src_addr", "dma_ctx_dst_addr", "dma_ctx_byte_len", "dma_ctx_done"):
            self.assertTrue(hasattr(core, signal), f"Missing V2.4.1 sideband signal: {signal}")
        self.assertFalse(hasattr(core, "dma_ctx_state"))

        core.start_transfer(0x2000_0000, 0x3000_0000, 64)
        core.step_cycle(
            axi_arready=False, axi_rvalid=False, axi_rdata=0, axi_rlast=False, axi_rresp=AXIResp.OKAY,
            axi_awready=False, axi_wready=False, axi_bvalid=False, axi_bresp=AXIResp.OKAY,
        )
        self.assertTrue(core.dma_ctx_valid)
        self.assertEqual(core.dma_ctx_src_addr, 0x2000_0000)
        self.assertEqual(core.dma_ctx_dst_addr, 0x3000_0000)
        self.assertEqual(core.dma_ctx_byte_len, 64)
        self.assertFalse(core.dma_ctx_done)

    def test_fifo_push_pop_and_overflow(self):
        fifo = SynchronousFIFO(depth=4, width_bits=32)
        self.assertTrue(fifo.empty)
        self.assertFalse(fifo.full)

        self.assertTrue(fifo.push(0xAAAA_0001))
        self.assertTrue(fifo.push(0xAAAA_0002))
        self.assertEqual(fifo.count, 2)
        self.assertEqual(fifo.peak_occupancy, 2)

        self.assertTrue(fifo.push(0xAAAA_0003))
        self.assertTrue(fifo.push(0xAAAA_0004))
        self.assertTrue(fifo.full)
        self.assertEqual(fifo.peak_occupancy, 4)

        # Overflow attempt
        self.assertFalse(fifo.push(0xDEAD_BEEF))
        self.assertEqual(fifo.overflow_count, 1)

        # Pop all items
        self.assertEqual(fifo.pop(), 0xAAAA_0001)
        self.assertEqual(fifo.pop(), 0xAAAA_0002)
        self.assertEqual(fifo.pop(), 0xAAAA_0003)
        self.assertEqual(fifo.pop(), 0xAAAA_0004)
        self.assertTrue(fifo.empty)

        # Underflow attempt
        self.assertIsNone(fifo.pop())
        self.assertEqual(fifo.underflow_count, 1)

    def test_boundary_calculator_and_4kb_wrap(self):
        engine = GoldenFirewallEngine()
        
        # Valid burst inside 4KB page (0x8000_0000 -> 0x8000_003F)
        end1 = engine.calculate_end_address(0x8000_0000, 15, 2)
        self.assertEqual(end1, 0x8000_003F)
        self.assertFalse(engine.check_4kb_boundary_violation(0x8000_0000, end1))

        # Invalid burst crossing 4KB page (0x8000_0F00 + 128*4 bytes = 0x8000_10FF)
        end2 = engine.calculate_end_address(0x8000_0F00, 127, 2)
        self.assertEqual(end2, 0x8000_10FF)
        self.assertTrue(engine.check_4kb_boundary_violation(0x8000_0F00, end2))

    def test_sticky_lock_rw1s_immutability(self):
        regs = APBRegisterFile()
        
        # 1. Normal configuration write (PPROT = 0b001 -> Secure Privileged)
        success, err = regs.write_apb(0x020, 0x1000_0000, 0b001) # RGN_BASE_0
        self.assertTrue(success)
        self.assertFalse(err)
        data, err = regs.read_apb(0x020)
        self.assertFalse(err)
        self.assertEqual(data, 0x1000_0000)

        # 2. Lock Firewall (Ghi 1 vào FW_LOCK 0x004)
        success, err = regs.write_apb(0x004, 0x0000_0001, 0b001)
        self.assertTrue(success)
        self.assertFalse(err)
        self.assertTrue(regs.is_locked)

        # 3. Tamper attempt: Cố tình ghi đè RGN_BASE_0 sau khi đã Lock
        success, err = regs.write_apb(0x020, 0xDEAD_0000, 0b001)
        self.assertFalse(success)
        self.assertTrue(err) # Must return PSLVERR
        # Value must remain uncorrupted
        data, err = regs.read_apb(0x020)
        self.assertFalse(err)
        self.assertEqual(data, 0x1000_0000)

    def test_dynamic_context_tracker_synchronous_revocation(self):
        config = SoCConfig(default_firewall_enabled=True)
        fw = DMAAwareBusFirewall(config)
        
        # 1. DMA activates transfer (Sideband valid = 1)
        fw.update_sideband_context(dma_valid=True, dma_src=0x2000_0000, dma_dst=0x3000_0000, 
                                   dma_len=1024, dma_done=False)
        
        # Check Region 4 & 5 are active
        self.assertTrue(fw.regs.regions[4].active)
        self.assertTrue(fw.regs.regions[4].read_en)
        self.assertFalse(fw.regs.regions[4].write_en)
        self.assertTrue(fw.regs.regions[4].secure_only)
        self.assertTrue(fw.regs.regions[4].priv_only)
        self.assertEqual(fw.regs.regions[4].mid, 0)
        self.assertEqual(fw.regs.regions[4].limit, 0x2000_0000 + 1024 - 1)

        self.assertTrue(fw.regs.regions[5].active)
        self.assertTrue(fw.regs.regions[5].write_en)
        self.assertFalse(fw.regs.regions[5].read_en)
        self.assertTrue(fw.regs.regions[5].secure_only)
        self.assertTrue(fw.regs.regions[5].priv_only)
        self.assertEqual(fw.regs.regions[5].mid, 0)
        self.assertEqual(fw.regs.regions[5].limit, 0x3000_0000 + 1024 - 1)

        # 2. DMA asserts DONE (Sideband done = 1)
        fw.update_sideband_context(dma_valid=False, dma_src=0, dma_dst=0, dma_len=0, dma_done=True)
        
        # State after the dma_ctx_done sampling edge: both regions are deactivated.
        self.assertFalse(fw.regs.regions[4].active)
        self.assertFalse(fw.regs.regions[5].active)

    def test_dynamic_context_valid_is_one_shot_until_low(self):
        fw = DMAAwareBusFirewall(SoCConfig())
        fw.update_sideband_context(True, 0x1000, 0x2000, 64, False)
        first_descriptor = (
            fw.regs.regions[4].base,
            fw.regs.regions[4].limit,
            fw.regs.regions[5].base,
            fw.regs.regions[5].limit,
        )

        fw.update_sideband_context(True, 0x3000, 0x4000, 128, False)
        self.assertEqual(
            first_descriptor,
            (
                fw.regs.regions[4].base,
                fw.regs.regions[4].limit,
                fw.regs.regions[5].base,
                fw.regs.regions[5].limit,
            ),
        )

        fw.update_sideband_context(False, 0, 0, 0, False)
        fw.update_sideband_context(True, 0x3000, 0x4000, 128, False)
        self.assertEqual(fw.regs.regions[4].base, 0x3000)
        self.assertEqual(fw.regs.regions[5].base, 0x4000)

    def test_auto_context_disable_revokes_and_requires_valid_rearm(self):
        fw = DMAAwareBusFirewall(SoCConfig())
        fw.update_sideband_context(True, 0x1000, 0x2000, 64, False)
        self.assertTrue(fw.regs.regions[4].active)
        self.assertTrue(fw.regs.regions[5].active)

        success, error = fw.regs.write_apb(0x000, 0x0000_0009)
        self.assertTrue(success)
        self.assertFalse(error)
        self.assertFalse(fw.regs.regions[4].active)
        self.assertFalse(fw.regs.regions[5].active)

        success, error = fw.regs.write_apb(0x000, 0x0000_000D)
        self.assertTrue(success)
        self.assertFalse(error)
        fw.update_sideband_context(True, 0x3000, 0x4000, 64, False)
        self.assertFalse(fw.regs.regions[4].active)
        self.assertFalse(fw.regs.regions[5].active)

        fw.update_sideband_context(False, 0, 0, 0, False)
        fw.update_sideband_context(True, 0x3000, 0x4000, 64, False)
        self.assertTrue(fw.regs.regions[4].active)
        self.assertTrue(fw.regs.regions[5].active)

    def test_write_drain_fsm_sink_and_resp(self):
        fsm = WriteDrainFSM()
        self.assertEqual(fsm.state, "IDLE")

        # Trigger write fault for 4-beat burst
        fsm.step(w_fault_trigger=True, wvalid=False, wlast=False, bready=False, 
                 err_mode=ErrorMode.DECERR, master_id=2)
        self.assertEqual(fsm.state, "SINK")
        self.assertTrue(fsm.wready)

        # Beat 0..2
        for _ in range(3):
            fsm.step(w_fault_trigger=False, wvalid=True, wlast=False, bready=False, 
                     err_mode=ErrorMode.DECERR, master_id=2)
            self.assertEqual(fsm.state, "SINK")

        # Beat 3 (WLAST = 1)
        fsm.step(w_fault_trigger=False, wvalid=True, wlast=True, bready=False, 
                 err_mode=ErrorMode.DECERR, master_id=2)
        self.assertEqual(fsm.state, "RESP")
        self.assertTrue(fsm.bvalid)
        self.assertEqual(fsm.bresp, AXIResp.DECERR)
        self.assertEqual(fsm.drained_beats, 4)

        # Master asserts BREADY
        fsm.step(w_fault_trigger=False, wvalid=False, wlast=False, bready=True, 
                 err_mode=ErrorMode.DECERR, master_id=2)
        self.assertEqual(fsm.state, "IDLE")
        self.assertFalse(fsm.bvalid)

    def test_write_drain_requires_awlen_plus_one_and_echoes_bid(self):
        fsm = WriteDrainFSM()
        fsm.step(
            w_fault_trigger=True, wvalid=False, wlast=False, bready=False,
            err_mode=ErrorMode.DECERR, master_id=5, awlen=3,
        )
        fsm.step(False, True, True, False, ErrorMode.DECERR, 0, awlen=0)
        self.assertEqual(fsm.state, "SINK")
        self.assertFalse(fsm.bvalid)
        self.assertTrue(fsm.protocol_error)

        fsm.step(False, True, False, False, ErrorMode.DECERR, 0, awlen=0)
        fsm.step(False, True, False, False, ErrorMode.DECERR, 0, awlen=0)
        fsm.step(False, True, True, False, ErrorMode.DECERR, 0, awlen=0)
        self.assertEqual(fsm.state, "RESP")
        self.assertTrue(fsm.bvalid)
        self.assertEqual(fsm.bid, 5)
        self.assertEqual(fsm.drained_beats, 4)

        fsm.step(False, False, False, False, ErrorMode.HONEYPOT, 0, awlen=0)
        self.assertTrue(fsm.bvalid)
        self.assertEqual(fsm.bresp, AXIResp.DECERR)
        self.assertEqual(fsm.bid, 5)

    def test_read_drain_exact_beats_stable_and_echoes_rid(self):
        fsm = ReadDrainFSM()
        fsm.step(True, 2, False, ErrorMode.DECERR, 9)

        fsm.step(False, 0, False, ErrorMode.HONEYPOT, 0)
        held = (fsm.rvalid, fsm.rdata, fsm.rresp, fsm.rlast, fsm.rid)
        fsm.step(False, 0, False, ErrorMode.HONEYPOT, 0)
        self.assertEqual(held, (fsm.rvalid, fsm.rdata, fsm.rresp, fsm.rlast, fsm.rid))
        self.assertEqual(held, (True, 0, AXIResp.DECERR, False, 9))

        observed = []
        for _ in range(3):
            fsm.step(False, 0, True, ErrorMode.HONEYPOT, 0)
            if fsm.rvalid:
                observed.append((fsm.rlast, fsm.rid))
        self.assertEqual(observed, [(False, 9), (False, 9), (True, 9)])
        self.assertEqual(fsm.state, "IDLE")

    def test_firewall_blocks_w_before_aw_and_enforces_single_outstanding(self):
        fw = DMAAwareBusFirewall(SoCConfig())
        out = fw.step_cycle(
            s_awvalid=False, s_awaddr=0, s_awlen=0, s_awsize=2, s_awprot=0, s_awid=0,
            s_wvalid=True, s_wdata=0x1234, s_wlast=True, s_bready=False,
            s_arvalid=False, s_araddr=0, s_arlen=0, s_arsize=2, s_arprot=0, s_arid=0,
            s_rready=False,
            m_awready=True, m_wready=True, m_bvalid=False, m_bresp=AXIResp.OKAY,
            m_arready=True, m_rvalid=False, m_rdata=0, m_rlast=False, m_rresp=AXIResp.OKAY,
        )
        self.assertFalse(out["s_wready"])
        self.assertFalse(out["m_wvalid"])

        fw.regs.regions[0].base = 0x1000
        fw.regs.regions[0].limit = 0x1FFF
        fw.regs.regions[0].perm = (1 << 31) | 0x3
        fw.regs.regions[0].mid = 0
        first = fw.step_cycle(
            s_awvalid=True, s_awaddr=0x1000, s_awlen=0, s_awsize=2, s_awprot=0, s_awid=0,
            s_wvalid=False, s_wdata=0, s_wlast=False, s_bready=False,
            s_arvalid=False, s_araddr=0, s_arlen=0, s_arsize=2, s_arprot=0, s_arid=0,
            s_rready=False,
            m_awready=True, m_wready=True, m_bvalid=False, m_bresp=AXIResp.OKAY,
            m_arready=True, m_rvalid=False, m_rdata=0, m_rlast=False, m_rresp=AXIResp.OKAY,
        )
        self.assertTrue(first["s_awready"])
        second = fw.step_cycle(
            s_awvalid=True, s_awaddr=0x1004, s_awlen=0, s_awsize=2, s_awprot=0, s_awid=0,
            s_wvalid=False, s_wdata=0, s_wlast=False, s_bready=False,
            s_arvalid=False, s_araddr=0, s_arlen=0, s_arsize=2, s_arprot=0, s_arid=0,
            s_rready=False,
            m_awready=True, m_wready=True, m_bvalid=False, m_bresp=AXIResp.OKAY,
            m_arready=True, m_rvalid=False, m_rdata=0, m_rlast=False, m_rresp=AXIResp.OKAY,
        )
        self.assertFalse(second["s_awready"])

    def test_firewall_permission_snapshot_survives_context_revoke(self):
        fw = DMAAwareBusFirewall(SoCConfig())
        fw.update_sideband_context(True, 0x1000, 0x2000, 64, False)
        first = fw.step_cycle(
            s_awvalid=True, s_awaddr=0x2000, s_awlen=0, s_awsize=2, s_awprot=0b001, s_awid=0,
            s_wvalid=False, s_wdata=0, s_wlast=False, s_bready=False,
            s_arvalid=False, s_araddr=0, s_arlen=0, s_arsize=2, s_arprot=0, s_arid=0,
            s_rready=False,
            m_awready=False, m_wready=True, m_bvalid=False, m_bresp=AXIResp.OKAY,
            m_arready=True, m_rvalid=False, m_rdata=0, m_rlast=False, m_rresp=AXIResp.OKAY,
        )
        self.assertTrue(first["m_awvalid"])
        fault_count = fw.regs.fault_count

        fw.update_sideband_context(False, 0, 0, 0, True)
        second = fw.step_cycle(
            s_awvalid=False, s_awaddr=0, s_awlen=0, s_awsize=2, s_awprot=0, s_awid=0,
            s_wvalid=False, s_wdata=0, s_wlast=False, s_bready=False,
            s_arvalid=False, s_araddr=0, s_arlen=0, s_arsize=2, s_arprot=0, s_arid=0,
            s_rready=False,
            m_awready=True, m_wready=True, m_bvalid=False, m_bresp=AXIResp.OKAY,
            m_arready=True, m_rvalid=False, m_rdata=0, m_rlast=False, m_rresp=AXIResp.OKAY,
        )
        self.assertTrue(second["m_awvalid"])
        self.assertEqual(fw.regs.fault_count, fault_count)

    def test_firewall_profile_enforced_while_acl_disabled(self):
        fw = DMAAwareBusFirewall(SoCConfig(default_firewall_enabled=False))
        denied = fw.step_cycle(
            s_awvalid=True, s_awaddr=0x1002, s_awlen=0, s_awsize=2, s_awprot=0b001, s_awid=0,
            s_wvalid=False, s_wdata=0, s_wlast=False, s_bready=False,
            s_arvalid=False, s_araddr=0, s_arlen=0, s_arsize=2, s_arprot=0b001, s_arid=0,
            s_rready=False,
            m_awready=True, m_wready=True, m_bvalid=False, m_bresp=AXIResp.OKAY,
            m_arready=True, m_rvalid=False, m_rdata=0, m_rlast=False, m_rresp=AXIResp.OKAY,
        )
        self.assertFalse(denied["m_awvalid"])
        self.assertTrue(fw.w_active_fault)
        self.assertTrue(fw.regs.fault_status & (1 << 3))

        bypass = DMAAwareBusFirewall(SoCConfig(default_firewall_enabled=False))
        allowed = bypass.step_cycle(
            s_awvalid=False, s_awaddr=0, s_awlen=0, s_awsize=2, s_awprot=0b001, s_awid=0,
            s_wvalid=False, s_wdata=0, s_wlast=False, s_bready=False,
            s_arvalid=True, s_araddr=0x1000, s_arlen=0, s_arsize=2, s_arprot=0b001, s_arid=0,
            s_rready=False,
            m_awready=True, m_wready=True, m_bvalid=False, m_bresp=AXIResp.OKAY,
            m_arready=False, m_rvalid=False, m_rdata=0, m_rlast=False, m_rresp=AXIResp.OKAY,
        )
        self.assertTrue(allowed["m_arvalid"])
        self.assertEqual(bypass.regs.fault_count, 0)

    def test_firewall_denied_read_and_write_echo_ids(self):
        fw = DMAAwareBusFirewall(SoCConfig())
        fw.step_cycle(
            s_awvalid=True, s_awaddr=0x8000, s_awlen=0, s_awsize=2, s_awprot=0, s_awid=7,
            s_wvalid=False, s_wdata=0, s_wlast=False, s_bready=False,
            s_arvalid=True, s_araddr=0x9000, s_arlen=0, s_arsize=2, s_arprot=0, s_arid=6,
            s_rready=False,
            m_awready=True, m_wready=True, m_bvalid=False, m_bresp=AXIResp.OKAY,
            m_arready=True, m_rvalid=False, m_rdata=0, m_rlast=False, m_rresp=AXIResp.OKAY,
        )
        write = fw.step_cycle(
            s_awvalid=False, s_awaddr=0, s_awlen=0, s_awsize=2, s_awprot=0, s_awid=0,
            s_wvalid=True, s_wdata=0x55, s_wlast=True, s_bready=False,
            s_arvalid=False, s_araddr=0, s_arlen=0, s_arsize=2, s_arprot=0, s_arid=0,
            s_rready=False,
            m_awready=True, m_wready=True, m_bvalid=False, m_bresp=AXIResp.OKAY,
            m_arready=True, m_rvalid=False, m_rdata=0, m_rlast=False, m_rresp=AXIResp.OKAY,
        )
        self.assertTrue(write["s_wready"])
        response = fw.step_cycle(
            s_awvalid=False, s_awaddr=0, s_awlen=0, s_awsize=2, s_awprot=0, s_awid=0,
            s_wvalid=False, s_wdata=0, s_wlast=False, s_bready=False,
            s_arvalid=False, s_araddr=0, s_arlen=0, s_arsize=2, s_arprot=0, s_arid=0,
            s_rready=False,
            m_awready=True, m_wready=True, m_bvalid=False, m_bresp=AXIResp.OKAY,
            m_arready=True, m_rvalid=False, m_rdata=0, m_rlast=False, m_rresp=AXIResp.OKAY,
        )
        self.assertTrue(response["s_bvalid"])
        self.assertEqual(response["s_bid"], 7)
        self.assertTrue(response["s_rvalid"])
        self.assertEqual(response["s_rid"], 6)

    def test_firewall_allowed_response_ids_stable_under_backpressure(self):
        fw = DMAAwareBusFirewall(SoCConfig())
        fw.regs.regions[0].base = 0x1000
        fw.regs.regions[0].limit = 0x1FFF
        fw.regs.regions[0].perm = (1 << 31) | 0x3
        fw.regs.regions[0].mid = 0xF0  # Wildcard all four ID bits.

        fw.step_cycle(
            s_awvalid=True, s_awaddr=0x1000, s_awlen=0, s_awsize=2, s_awprot=0, s_awid=3,
            s_wvalid=False, s_wdata=0, s_wlast=False, s_bready=False,
            s_arvalid=True, s_araddr=0x1004, s_arlen=0, s_arsize=2, s_arprot=0, s_arid=4,
            s_rready=False,
            m_awready=True, m_wready=True, m_bvalid=False, m_bresp=AXIResp.OKAY,
            m_arready=True, m_rvalid=False, m_rdata=0, m_rlast=False, m_rresp=AXIResp.OKAY,
        )
        fw.step_cycle(
            s_awvalid=False, s_awaddr=0, s_awlen=0, s_awsize=2, s_awprot=0, s_awid=0,
            s_wvalid=True, s_wdata=0xA5A5_5A5A, s_wlast=True, s_bready=False,
            s_arvalid=False, s_araddr=0, s_arlen=0, s_arsize=2, s_arprot=0, s_arid=0,
            s_rready=False,
            m_awready=True, m_wready=True, m_bvalid=False, m_bresp=AXIResp.OKAY,
            m_arready=True, m_rvalid=True, m_rdata=0x1122_3344, m_rlast=True,
            m_rresp=AXIResp.OKAY, m_rid=4,
        )
        fw.step_cycle(
            s_awvalid=False, s_awaddr=0, s_awlen=0, s_awsize=2, s_awprot=0, s_awid=0,
            s_wvalid=False, s_wdata=0, s_wlast=False, s_bready=False,
            s_arvalid=False, s_araddr=0, s_arlen=0, s_arsize=2, s_arprot=0, s_arid=0,
            s_rready=False,
            m_awready=True, m_wready=True, m_bvalid=True, m_bresp=AXIResp.OKAY,
            m_arready=True, m_rvalid=False, m_rdata=0, m_rlast=False,
            m_rresp=AXIResp.OKAY, m_bid=3,
        )

        held = fw.step_cycle(
            s_awvalid=False, s_awaddr=0, s_awlen=0, s_awsize=2, s_awprot=0, s_awid=0,
            s_wvalid=False, s_wdata=0, s_wlast=False, s_bready=False,
            s_arvalid=False, s_araddr=0, s_arlen=0, s_arsize=2, s_arprot=0, s_arid=0,
            s_rready=False,
            m_awready=True, m_wready=True, m_bvalid=False, m_bresp=AXIResp.DECERR,
            m_arready=True, m_rvalid=False, m_rdata=0, m_rlast=False,
            m_rresp=AXIResp.DECERR,
        )
        stalled = fw.step_cycle(
            s_awvalid=False, s_awaddr=0, s_awlen=0, s_awsize=2, s_awprot=0, s_awid=0,
            s_wvalid=False, s_wdata=0, s_wlast=False, s_bready=False,
            s_arvalid=False, s_araddr=0, s_arlen=0, s_arsize=2, s_arprot=0, s_arid=0,
            s_rready=False,
            m_awready=True, m_wready=True, m_bvalid=False, m_bresp=AXIResp.DECERR,
            m_arready=True, m_rvalid=False, m_rdata=0, m_rlast=False,
            m_rresp=AXIResp.DECERR,
        )
        fields = ("s_bvalid", "s_bresp", "s_bid", "s_rvalid", "s_rdata", "s_rresp", "s_rlast", "s_rid")
        self.assertEqual(tuple(held[key] for key in fields), tuple(stalled[key] for key in fields))
        self.assertEqual(
            tuple(held[key] for key in fields),
            (True, AXIResp.OKAY, 3, True, 0x1122_3344, AXIResp.OKAY, True, 4),
        )

    def test_fail_secure_reset_default_deny(self):
        """Verify FW_EN=1 out of reset and unconfigured accesses are blocked by DEFAULT_DENY."""
        engine = GoldenFirewallEngine()
        self.assertTrue(engine.enabled)
        for reg in engine.regions:
            self.assertFalse(reg.active)
        
        # Access when no regions configured -> DEFAULT_DENY
        allowed, resp, reason = engine.evaluate_access(
            addr=0x8000_0000, len_beats=3, size_bytes_exp=2, is_write=False, prot=0b001, master_id=0
        )
        self.assertFalse(allowed)
        self.assertEqual(resp, AXIResp.DECERR)
        self.assertEqual(reason, "DEFAULT_DENY_NO_MATCH")

    def test_apb_read_only_dynamic_regions(self):
        """Verify APB writes to Region 4 & 5 return PSLVERR."""
        regs = APBRegisterFile()
        # Attempt to write to RGN_BASE_4 (0x060)
        success, pslverr = regs.write_apb(0x060, 0x1000_0000, 0b001)
        self.assertFalse(success)
        self.assertTrue(pslverr)

        # Attempt to write to RGN_PERM_5 (0x078)
        success, pslverr = regs.write_apb(0x078, 0x8000_0002, 0b001)
        self.assertFalse(success)
        self.assertTrue(pslverr)

    def test_dma_constrained_profile_violations(self):
        """Verify unaligned address, non-word size, burst > 16 beats, and non-INCR are rejected."""
        engine = GoldenFirewallEngine()
        # Configure Region 0 as valid wide range
        engine.regions[0].base = 0x8000_0000
        engine.regions[0].limit = 0x8FFF_FFFF
        engine.regions[0].perm = (1 << 31) | (1 << 0) | (1 << 1)  # Active, Read, Write
        engine.regions[0].mid = 0x00

        # 1. Unaligned address (0x8000_0001)
        allowed, resp, reason = engine.evaluate_access(
            addr=0x8000_0001, len_beats=0, size_bytes_exp=2, is_write=False, prot=0b001, master_id=0
        )
        self.assertFalse(allowed)
        self.assertEqual(reason, "AXI_PROFILE_VIOLATION")

        # 2. Non-word size (size_bytes_exp = 3 for 8-byte beat)
        allowed, resp, reason = engine.evaluate_access(
            addr=0x8000_0000, len_beats=0, size_bytes_exp=3, is_write=False, prot=0b001, master_id=0
        )
        self.assertFalse(allowed)
        self.assertEqual(reason, "AXI_PROFILE_VIOLATION")

        # 3. Burst length > 15 beats (len_beats = 16)
        allowed, resp, reason = engine.evaluate_access(
            addr=0x8000_0000, len_beats=16, size_bytes_exp=2, is_write=False, prot=0b001, master_id=0
        )
        self.assertFalse(allowed)
        self.assertEqual(reason, "AXI_PROFILE_VIOLATION")

        # 4. Non-INCR burst (WRAP = 0b10)
        allowed, resp, reason = engine.evaluate_access(
            addr=0x8000_0000, len_beats=3, size_bytes_exp=2, is_write=False, prot=0b001, master_id=0,
            burst_type=0b10
        )
        self.assertFalse(allowed)
        self.assertEqual(reason, "AXI_PROFILE_VIOLATION")

    def test_sideband_len_zero_and_overflow_protection(self):
        """Verify len=0 or 32-bit overflow prevents dynamic context activation."""
        engine = GoldenFirewallEngine()
        
        # len = 0
        success = engine.allocate_dynamic_dma_context(src=0x2000_0000, dst=0x3000_0000, byte_len=0)
        self.assertFalse(success)
        self.assertFalse(engine.regions[4].active)
        self.assertFalse(engine.regions[5].active)

        # 32-bit overflow (src = 0xFFFF_FF00, len = 512)
        success = engine.allocate_dynamic_dma_context(src=0xFFFF_FF00, dst=0x3000_0000, byte_len=512)
        self.assertFalse(success)
        self.assertFalse(engine.regions[4].active)

    def test_irq_pending_sticky_w1c(self):
        """Verify IRQ_PENDING is sticky and only deasserts when cleared via W1C."""
        regs = APBRegisterFile()
        regs.fw_control = (1 << 0) | (1 << 1)  # FW_EN=1, IRQ_EN=1
        
        # Record fault
        regs.record_fault(addr=0x1000, len_beats=0, size=2, is_write=True, mid=1, fault_type_bit=1, current_cycle=10)
        self.assertTrue(regs.sec_irq)
        self.assertTrue(bool(regs.fault_status & (1 << 31)))  # IRQ_PENDING is set
        self.assertTrue(bool(regs.fault_status & (1 << 1)))   # WRITE_ERR is set

        # Clearing only WRITE_ERR bit [1] does NOT deassert sec_irq
        regs.write_apb(0x008, 0x0000_0002, 0b001)
        self.assertFalse(bool(regs.fault_status & (1 << 1)))  # WRITE_ERR is cleared
        self.assertTrue(bool(regs.fault_status & (1 << 31)))   # IRQ_PENDING is still set
        self.assertTrue(regs.sec_irq)                         # sec_irq remains asserted!

        # Clearing IRQ_PENDING bit [31] deasserts sec_irq
        regs.write_apb(0x008, 0x8000_0000, 0b001)
        self.assertFalse(bool(regs.fault_status & (1 << 31)))
        self.assertFalse(regs.sec_irq)

    def test_fw_control_reset_default_value(self):
        """Verify FW_CONTROL resets to 0x0000_000D (EN=1, IRQ_EN=0, AUTO_CTX_EN=1, ERR_MODE=1)."""
        regs = APBRegisterFile()
        self.assertEqual(regs.fw_control, 0x0000_000D)
        self.assertTrue(regs.is_fw_enabled)
        self.assertFalse(regs.is_irq_enabled)
        self.assertTrue(regs.is_auto_ctx_enabled)
        self.assertEqual(regs.error_mode, ErrorMode.DECERR)

    def test_apb_read_out_of_window_and_unaligned_pslverr(self):
        """Verify APB reads from out-of-window or unaligned addresses return PSLVERR."""
        regs = APBRegisterFile()
        
        # 1. Unaligned address read (0x001)
        data, err = regs.read_apb(0x001)
        self.assertTrue(err)

        # 2. Out of window address read (0x1000_0200)
        data, err = regs.read_apb(0x1000_0200)
        self.assertTrue(err)

        # 3. Unmapped offset read (0x01C)
        data, err = regs.read_apb(0x01C)
        self.assertTrue(err)

    def test_fault_source_apb_reset_retention_and_recapture(self):
        regs = APBRegisterFile()
        data, error = regs.read_apb(0x018)
        self.assertFalse(error)
        self.assertEqual(data, 0)

        regs.record_fault(
            addr=0x1000, len_beats=0, size=2, is_write=True, mid=1,
            fault_type_bit=1, current_cycle=10, source="write",
        )
        expected_write_source = 0b01 | (1 << 2)
        self.assertEqual(regs.read_apb(0x018), (expected_write_source, False))

        regs.record_fault(
            addr=0x2000, len_beats=0, size=2, is_write=False, mid=2,
            fault_type_bit=3, current_cycle=20, source="context",
        )
        self.assertEqual(regs.read_apb(0x018), (expected_write_source, False))

        regs.write_apb(0x008, 0x8000_000F)
        regs.record_fault(
            addr=0x3000, len_beats=0, size=2, is_write=False, mid=3,
            fault_type_bit=3, current_cycle=30, source="context",
        )
        expected_context_source = 0b10 | (3 << 2)
        self.assertEqual(regs.read_apb(0x018), (expected_context_source, False))

    def test_active_region_descriptor_edit_rejected(self):
        """Verify modifying descriptor (BASE/LIMIT/MID) while Region is ACTIVE returns PSLVERR."""
        regs = APBRegisterFile()
        
        # 1. Configure and activate Region 0
        regs.write_apb(0x020, 0x2000_0000)
        regs.write_apb(0x024, 0x2000_0FFF)
        regs.write_apb(0x028, (1 << 31) | 0x3)  # ACTIVE=1
        self.assertTrue(regs.regions[0].active)

        # 2. Attempt to edit BASE while ACTIVE -> PSLVERR
        success, err = regs.write_apb(0x020, 0x3000_0000)
        self.assertFalse(success)
        self.assertTrue(err)

        # 3. Attempt to edit LIMIT while ACTIVE -> PSLVERR
        success, err = regs.write_apb(0x024, 0x3000_0FFF)
        self.assertFalse(success)
        self.assertTrue(err)

        # 4. Deactivate Region 0 first (clear bit 31 in PERM) -> Allowed
        success, err = regs.write_apb(0x028, 0x3)
        self.assertTrue(success)
        self.assertFalse(err)
        self.assertFalse(regs.regions[0].active)

        # 5. Now editing BASE is allowed
        success, err = regs.write_apb(0x020, 0x3000_0000)
        self.assertTrue(success)
        self.assertFalse(err)

    def test_static_region_activation_rejects_base_above_limit_atomically(self):
        regs = APBRegisterFile()
        self.assertEqual(regs.write_apb(0x020, 0x3000), (True, False))
        self.assertEqual(regs.write_apb(0x024, 0x2000), (True, False))
        self.assertEqual(regs.write_apb(0x028, 0x0000_0003), (True, False))
        before = (
            regs.regions[0].base,
            regs.regions[0].limit,
            regs.regions[0].perm,
            regs.regions[0].mid,
        )

        success, error = regs.write_apb(0x028, (1 << 31) | 0x3)
        self.assertFalse(success)
        self.assertTrue(error)
        self.assertEqual(
            before,
            (
                regs.regions[0].base,
                regs.regions[0].limit,
                regs.regions[0].perm,
                regs.regions[0].mid,
            ),
        )
        self.assertFalse(regs.regions[0].active)

    def test_exact_base_address_no_overgrant(self):
        """Verify dynamic buffer at 0x2000_0080 does NOT grant access to 0x2000_0000 (no 4KB round-down)."""
        engine = GoldenFirewallEngine()
        engine.allocate_dynamic_dma_context(src=0x2000_0080, dst=0x3000_0080, byte_len=128)
        
        self.assertEqual(engine.regions[4].base, 0x2000_0080)
        self.assertEqual(engine.regions[4].limit, 0x2000_0080 + 128 - 1)

        # Accessing 0x2000_0000 (below base 0x2000_0080) must be denied
        allowed, resp, reason = engine.evaluate_access(
            addr=0x2000_0000, len_beats=3, size_bytes_exp=2, is_write=False, prot=0b001, master_id=0
        )
        self.assertFalse(allowed)
        self.assertEqual(reason, "DEFAULT_DENY_NO_MATCH")

        # Accessing 0x2000_0080 (inside range) must be allowed
        allowed, resp, reason = engine.evaluate_access(
            addr=0x2000_0080, len_beats=3, size_bytes_exp=2, is_write=False, prot=0b001, master_id=0
        )
        self.assertTrue(allowed)
        self.assertEqual(reason, "ACCESS_ALLOWED")

    def test_misaligned_context_rejected_by_firewall_model(self):
        """Verify Firewall Model rejects misaligned sideband context allocation."""
        config = SoCConfig(default_firewall_enabled=True)
        fw = DMAAwareBusFirewall(config)
        
        # Misaligned src (0x2000_0001)
        fw.update_sideband_context(dma_valid=True, dma_src=0x2000_0001, dma_dst=0x3000_0000, 
                                   dma_len=64, dma_done=False)
        self.assertFalse(fw.regs.regions[4].active, "Region 4 became active on misaligned src!")
        self.assertFalse(fw.regs.regions[5].active, "Region 5 became active on misaligned src!")
        self.assertTrue(bool(fw.regs.fault_status & (1 << 3)), "BOUND_ERR was not set on misaligned context!")

    def test_nonsecure_access_to_secure_region_blocked_with_prot_err(self):
        """Verify Non-Secure transaction to SECURE_ONLY region is blocked and traps PROT_ERR."""
        config = SoCConfig(default_firewall_enabled=True, default_error_mode=ErrorMode.DECERR)
        fw = DMAAwareBusFirewall(config)
        
        # Configure Region 0 as SECURE_ONLY (PERM: ACTIVE=1, RW=1, SECURE_ONLY=1 -> 0x8000_0007)
        fw.regs.write_apb(0x020, 0x5000_0000)
        fw.regs.write_apb(0x024, 0x5000_0FFF)
        fw.regs.write_apb(0x028, (1 << 31) | (1 << 2) | 0x3) # SECURE_ONLY=1
        fw.regs.write_apb(0x02C, 0x00)

        # Inject Non-Secure read (ARPROT[1] = 1 -> Non-Secure)
        fw.step_cycle(
            s_awvalid=False, s_awaddr=0, s_awlen=0, s_awsize=2, s_awprot=0, s_awid=0,
            s_wvalid=False, s_wdata=0, s_wlast=False, s_bready=False,
            s_arvalid=True, s_araddr=0x5000_0000, s_arlen=0, s_arsize=2, s_arprot=0b010, s_arid=0, # Non-Secure
            s_rready=True,
            m_awready=True, m_wready=True, m_bvalid=False, m_bresp=AXIResp.OKAY,
            m_arready=True, m_rvalid=False, m_rdata=0, m_rlast=False, m_rresp=AXIResp.OKAY
        )
        self.assertTrue(fw.r_active_fault, "Non-Secure access was forwarded instead of being trapped!")
        self.assertTrue(bool(fw.regs.fault_status & (1 << 2)), "PROT_ERR bit [2] was not set!")

    def test_first_fault_metadata_persists_until_irq_pending_cleared(self):
        """Verify first-fault address and metadata are locked until BOTH fault bits AND IRQ_PENDING are cleared."""
        regs = APBRegisterFile()
        regs.fw_control = 0x0000_000F # IRQ_EN = 1
        
        # 1. Fault 1 occurs at addr 0x1000
        regs.record_fault(addr=0x1000, len_beats=0, size=2, is_write=True, mid=1, fault_type_bit=1, current_cycle=10)
        self.assertEqual(regs.fault_addr, 0x1000)

        # 2. Fault 2 occurs at addr 0x2000 while Fault 1 is still pending
        regs.record_fault(addr=0x2000, len_beats=3, size=2, is_write=False, mid=2, fault_type_bit=0, current_cycle=20)
        self.assertEqual(regs.fault_addr, 0x1000, "First fault metadata was corrupted by second fault!")

        # 3. Clear only WRITE_ERR bit [1] via W1C (IRQ_PENDING bit [31] remains set)
        regs.write_apb(0x008, 0x0000_0002, 0b001)
        self.assertTrue(bool(regs.fault_status & (1 << 31))) # IRQ_PENDING is still set

        # 4. Fault 3 occurs at addr 0x3000 -> First fault metadata must STILL be locked
        regs.record_fault(addr=0x3000, len_beats=1, size=2, is_write=True, mid=3, fault_type_bit=1, current_cycle=30)
        self.assertEqual(regs.fault_addr, 0x1000, "First fault metadata was overwritten before IRQ_PENDING was cleared!")

        # 5. Clear all fault bits AND IRQ_PENDING bit [31]
        regs.write_apb(0x008, 0x8000_000F, 0b001)
        self.assertEqual(regs.fault_status, 0x0000_0000)

        # 6. Now Fault 4 at addr 0x4000 can capture new first-fault metadata
        regs.record_fault(addr=0x4000, len_beats=0, size=2, is_write=False, mid=4, fault_type_bit=0, current_cycle=40)
        self.assertEqual(regs.fault_addr, 0x4000, "New first fault metadata was not captured after full clear!")

    def test_batch_fault_recording_ors_status_counts_and_prioritizes_metadata(self):
        regs = APBRegisterFile()
        regs.fw_control |= 1 << 1
        regs.fault_count = 0xFFFE
        regs.record_faults([
            FaultRecord(0x3000, 2, 2, False, 3, 0, 30, "read"),
            FaultRecord(0x1000, 0, 2, False, 0, 3, 10, "context"),
            FaultRecord(0x2000, 1, 2, True, 2, 1, 20, "write"),
        ])

        self.assertEqual(regs.fault_count, 0xFFFF)
        self.assertEqual(regs.fault_status & 0xF, 0b1011)
        self.assertTrue(regs.fault_status & (1 << 31))
        self.assertTrue(regs.sec_irq)
        self.assertEqual(regs.fault_addr, 0x1000)
        self.assertEqual(regs.fault_timestamp, 10)
        self.assertEqual(regs.fault_source, 0b10 | (3 << 2))
        self.assertEqual(regs.read_apb(0x018), (0b10 | (3 << 2), False))

    def test_simultaneous_context_write_read_faults_capture_context_source(self):
        fw = DMAAwareBusFirewall(SoCConfig())
        fw.update_sideband_context(
            dma_valid=True, dma_src=0x1001, dma_dst=0x2000,
            dma_len=64, dma_done=False,
        )
        fw.step_cycle(
            s_awvalid=True, s_awaddr=0x3000, s_awlen=0, s_awsize=2, s_awprot=0b001, s_awid=0,
            s_wvalid=False, s_wdata=0, s_wlast=False, s_bready=False,
            s_arvalid=True, s_araddr=0x4000, s_arlen=0, s_arsize=2, s_arprot=0b001, s_arid=0,
            s_rready=False,
            m_awready=True, m_wready=True, m_bvalid=False, m_bresp=AXIResp.OKAY,
            m_arready=True, m_rvalid=False, m_rdata=0, m_rlast=False, m_rresp=AXIResp.OKAY,
        )

        self.assertEqual(fw.regs.fault_count, 3)
        self.assertEqual(fw.regs.fault_status & 0xF, 0b1011)
        self.assertEqual(fw.regs.fault_addr, 0x1001)
        self.assertEqual(fw.regs.fault_source, 0b10 | (3 << 2))

if __name__ == "__main__":
    unittest.main()
