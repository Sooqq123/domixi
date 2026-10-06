# -*- coding: utf-8 -*-
"""
Integration Tests & 4 Core Attack Vectors Verification for System-Level SoC Model.
Spec Version: V2.4.1 Clarification & Closure Baseline
"""

import sys
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding='utf-8')

import unittest
import random
from model.config import SoCConfig, AXIResp, ErrorMode
from model.soc_system_sim import SoCSystemSimulator
from model.soc_components import DMACore
from model.firewall_model import DMAAwareBusFirewall
from model.golden_ref import GoldenFirewallEngine

class TestSoCIntegration(unittest.TestCase):

    def test_normal_dma_transfer_golden_match(self):
        """TC_NORMAL: Verify clean DMA transfer with 100% data integrity."""
        sim = SoCSystemSimulator()
        
        SRC_ADDR = 0x0001_0000
        DST_ADDR = 0x0002_0000
        TEST_BYTES = 256  # 64 words

        # 1. Populate source memory with deterministic test pattern
        test_payload = bytes([(i * 7 + 13) & 0xFF for i in range(TEST_BYTES)])
        sim.main_mem.load_bytes(SRC_ADDR, test_payload)

        # 2. Configure Static Regions (Region 0 for Src, Region 1 for Dst)
        sim.configure_firewall_static_region(0, SRC_ADDR, SRC_ADDR + TEST_BYTES - 1, read_en=True, write_en=False)
        sim.configure_firewall_static_region(1, DST_ADDR, DST_ADDR + TEST_BYTES - 1, read_en=False, write_en=True)

        # 3. Start DMA transfer
        sim.dma.start_transfer(SRC_ADDR, DST_ADDR, TEST_BYTES)
        results = sim.run_simulation(max_cycles=10000)

        # 4. Verifications
        self.assertTrue(results["completed"], "DMA did not complete successfully")
        self.assertEqual(results["fault_count"], 0, "Unexpected fault detected in clean transfer")
        self.assertFalse(results["sec_irq_asserted"], "Unexpected sec_irq asserted")

        # 5. Verify Destination Memory against Source Payload
        dst_result = sim.main_mem.read_bytes(DST_ADDR, TEST_BYTES)
        self.assertEqual(dst_result, test_payload, "Destination payload mismatch!")

    def test_end_to_end_fifo32_and_aw_before_w(self):
        """A complete transfer never forwards W before the matching AW handshake."""
        sim = SoCSystemSimulator()
        src_addr = 0x0003_0000
        dst_addr = 0x0004_0000
        payload = bytes((index * 11 + 5) & 0xFF for index in range(512))
        sim.main_mem.load_bytes(src_addr, payload)
        sim.configure_firewall_static_region(
            0, src_addr, src_addr + len(payload) - 1,
            read_en=True, write_en=False,
        )
        sim.configure_firewall_static_region(
            1, dst_addr, dst_addr + len(payload) - 1,
            read_en=False, write_en=True,
        )

        downstream_aw_seen = False
        w_before_aw = False
        observed_provenance = []
        original_step = sim.firewall.step_cycle

        def tracked_step(*args, **kwargs):
            nonlocal downstream_aw_seen, w_before_aw
            if kwargs["s_awvalid"]:
                observed_provenance.append(("AW", kwargs["s_awprot"], kwargs["s_awid"]))
            if kwargs["s_arvalid"]:
                observed_provenance.append(("AR", kwargs["s_arprot"], kwargs["s_arid"]))
            result = original_step(*args, **kwargs)
            if result["m_awvalid"] and kwargs["m_awready"]:
                downstream_aw_seen = True
            if result["m_wvalid"] and not downstream_aw_seen:
                w_before_aw = True
            if result["m_bready"] and kwargs["m_bvalid"]:
                downstream_aw_seen = False
            return result

        sim.firewall.step_cycle = tracked_step
        self.assertTrue(sim.dma.start_transfer(src_addr, dst_addr, len(payload)))
        result = sim.run_simulation(max_cycles=10000)

        self.assertEqual(sim.dma.fifo.depth, 32)
        self.assertTrue(result["completed"])
        self.assertFalse(w_before_aw)
        self.assertTrue(observed_provenance)
        self.assertTrue(all(prot == 0b001 and txn_id == 0 for _, prot, txn_id in observed_provenance))
        self.assertEqual(sim.main_mem.read_bytes(dst_addr, len(payload)), payload)

    def test_dma_aborts_on_firewall_read_decerr_after_drain(self):
        """Connect DMA and firewall directly and verify denied R drains then aborts."""
        config = SoCConfig(default_error_mode=ErrorMode.DECERR)
        dma = DMACore(config)
        firewall = DMAAwareBusFirewall(config)
        self.assertTrue(dma.start_transfer(0x1000, 0x2000, 4))

        terminal_error_seen = False
        for _ in range(16):
            firewall.update_sideband_context(False, 0, 0, 0, False)
            out = firewall.step_cycle(
                s_awvalid=dma.aw_valid, s_awaddr=dma.aw_addr,
                s_awlen=dma.aw_len, s_awsize=2, s_awprot=0, s_awid=0,
                s_wvalid=dma.w_valid, s_wdata=dma.w_data,
                s_wlast=dma.w_last, s_bready=dma.b_ready,
                s_arvalid=dma.ar_valid, s_araddr=dma.ar_addr,
                s_arlen=dma.ar_len, s_arsize=2, s_arprot=0, s_arid=0,
                s_rready=dma.r_ready,
                m_awready=True, m_wready=True,
                m_bvalid=False, m_bresp=AXIResp.OKAY,
                m_arready=True, m_rvalid=False, m_rdata=0,
                m_rlast=False, m_rresp=AXIResp.OKAY,
            )
            dma.step_cycle(
                out["s_arready"], out["s_rvalid"], out["s_rdata"],
                out["s_rlast"], out["s_rresp"], out["s_awready"],
                out["s_wready"], out["s_bvalid"], out["s_bresp"],
            )
            if dma.error_set_event:
                terminal_error_seen = True
                break

        self.assertTrue(terminal_error_seen)
        self.assertTrue(dma.status_error)
        self.assertFalse(dma.done_set_event)
        self.assertFalse(dma.status_busy)
        self.assertTrue(dma.dma_ctx_done)
        self.assertEqual(firewall.regs.fault_count, 1)

    def test_attack_vector_1_cross_bound(self):
        """TC_CROSS_BOUND: AXI Burst crossing 4KB page boundary must be trapped immediately."""
        config = SoCConfig(default_firewall_enabled=True, default_error_mode=ErrorMode.DECERR)
        sim = SoCSystemSimulator(config)
        sim.firewall.regs.fw_control = 0x0000_000F  # EN=1, IRQ_EN=1, AUTO_CTX_EN=1, ERR_MODE=1
        sim.configure_firewall_static_region(0, 0x0000_0000, 0x0001_0000, read_en=True, write_en=True)

        # A compromised/malicious master injects an unsplit 16-beat burst starting at 0x0000_0FE0 (crosses 0x0000_1000 boundary)
        BAD_SRC = 0x0000_0FE0
        sim.firewall.step_cycle(
            s_awvalid=False, s_awaddr=0, s_awlen=0, s_awsize=2, s_awprot=0, s_awid=0,
            s_wvalid=False, s_wdata=0, s_wlast=False, s_bready=False,
            s_arvalid=True, s_araddr=BAD_SRC, s_arlen=15, s_arsize=2, s_arprot=0b001, s_arid=1,
            s_rready=False,
            m_awready=True, m_wready=True, m_bvalid=False, m_bresp=AXIResp.OKAY,
            m_arready=True, m_rvalid=False, m_rdata=0, m_rlast=False, m_rresp=AXIResp.OKAY
        )

        # Verify boundary fault detection
        self.assertTrue(sim.firewall.r_active_fault, "Firewall failed to detect 4KB boundary wrap-around!")
        self.assertGreater(sim.firewall.regs.fault_count, 0, "Fault counter was not incremented!")
        self.assertTrue(sim.firewall.regs.sec_irq, "Firewall failed to assert sec_irq alert!")
        # Fault bit 3 is Boundary Overflow
        self.assertTrue(bool(sim.firewall.regs.fault_status & (1 << 3)), "FAULT_STATUS[3] boundary flag not set!")

    def test_attack_vector_2_tamper_lock(self):
        """TC_TAMPER_LOCK: Malicious APB write after Sticky Lock must be blocked with PSLVERR."""
        sim = SoCSystemSimulator()

        # Step 1: Initial configuration
        sim.configure_firewall_static_region(0, 0x1000_0000, 0x1000_0FFF, read_en=True, write_en=True)
        data, err = sim.firewall.regs.read_apb(0x020)
        self.assertFalse(err)
        self.assertEqual(data, 0x1000_0000)

        # Step 2: Lock Firewall (Secure Boot completed)
        sim.lock_firewall()
        self.assertTrue(sim.firewall.regs.is_locked)

        # Step 3: Malicious software attempts to overwrite Region 0 base address
        success, pslverr = sim.firewall.regs.write_apb(0x020, 0x9000_0000, 0b001)
        self.assertFalse(success, "Malicious write succeeded despite Sticky Lock!")
        self.assertTrue(pslverr, "Firewall failed to return PSLVERR on locked write attempt!")
        data, err = sim.firewall.regs.read_apb(0x020)
        self.assertFalse(err)
        self.assertEqual(data, 0x1000_0000, "Region 0 base address was corrupted!")

    def test_attack_vector_3_toctou_forgery(self):
        """TC_TOCTOU_FORGERY: Accessing an old buffer after DMA completion must be blocked after synchronous revocation."""
        sim = SoCSystemSimulator()

        SRC_ADDR = 0x0005_0000
        DST_ADDR = 0x0006_0000
        TEST_BYTES = 64

        sim.configure_firewall_static_region(0, SRC_ADDR, SRC_ADDR + TEST_BYTES - 1, read_en=True, write_en=False)
        sim.configure_firewall_static_region(1, DST_ADDR, DST_ADDR + TEST_BYTES - 1, read_en=False, write_en=True)

        # 1. Clean DMA transfer using Auto Dynamic Context
        sim.dma.start_transfer(SRC_ADDR, DST_ADDR, TEST_BYTES)
        res1 = sim.run_simulation(max_cycles=5000)
        self.assertTrue(res1["completed"])
        self.assertEqual(res1["fault_count"], 0)

        # 2. DMA has completed (dma_ctx_done was fired) -> Dynamic regions 4 & 5 MUST be revoked
        self.assertFalse(sim.firewall.regs.regions[4].active, "Region 4 was not revoked on DMA completion!")
        self.assertFalse(sim.firewall.regs.regions[5].active, "Region 5 was not revoked on DMA completion!")

        # 3. Simulate an attacker attempting to access the old source address directly via AXI
        engine = GoldenFirewallEngine()
        engine.enabled = True
        # Regions are empty / revoked
        allowed, resp, reason = engine.evaluate_access(SRC_ADDR, 15, 2, is_write=False, prot=0, master_id=0)
        self.assertFalse(allowed, "Attacker was able to read old buffer after DMA completion!")
        self.assertEqual(resp, AXIResp.DECERR)

    def test_attack_vector_4_deadlock_stress(self):
        """TC_DEADLOCK_STRESS: 1,000 back-to-back violation bursts must not deadlock the Sink Drain FSM."""
        sim = SoCSystemSimulator()
        sim.firewall.regs.fw_control = (1 << 0) | (1 << 1) | (1 << 3)  # Active + IRQ + DECERR Mode

        total_violations = 1000
        drained_transactions = 0

        # Simulate 1,000 bursts of random lengths sent to unmapped/forbidden addresses
        rng = random.Random(0xD4A)
        for _ in range(total_violations):
            burst_len = rng.randint(0, 15)  # 1 to 16 beats
            master_id = rng.randint(0, 15)
            bad_addr = 0xF000_0000 + rng.randint(0, 0xFFFF) * 4

            # Step 1: AW phase (violation triggered)
            sim.firewall.step_cycle(
                s_awvalid=True, s_awaddr=bad_addr, s_awlen=burst_len, s_awsize=2, s_awprot=0, s_awid=master_id,
                s_wvalid=False, s_wdata=0, s_wlast=False, s_bready=False,
                s_arvalid=False, s_araddr=0, s_arlen=0, s_arsize=2, s_arprot=0, s_arid=0, s_rready=False,
                m_awready=True, m_wready=True, m_bvalid=False, m_bresp=AXIResp.OKAY,
                m_arready=True, m_rvalid=False, m_rdata=0, m_rlast=False, m_rresp=AXIResp.OKAY
            )

            # Step 2: Sink all WDATA beats
            for beat in range(burst_len + 1):
                is_last = (beat == burst_len)
                sim.firewall.step_cycle(
                    s_awvalid=False, s_awaddr=0, s_awlen=0, s_awsize=2, s_awprot=0, s_awid=0,
                    s_wvalid=True, s_wdata=0xDEAD_0000 + beat, s_wlast=is_last, s_bready=False,
                    s_arvalid=False, s_araddr=0, s_arlen=0, s_arsize=2, s_arprot=0, s_arid=0, s_rready=False,
                    m_awready=True, m_wready=True, m_bvalid=False, m_bresp=AXIResp.OKAY,
                    m_arready=True, m_rvalid=False, m_rdata=0, m_rlast=False, m_rresp=AXIResp.OKAY
                )

            # Step 3: B response phase
            out = sim.firewall.step_cycle(
                s_awvalid=False, s_awaddr=0, s_awlen=0, s_awsize=2, s_awprot=0, s_awid=0,
                s_wvalid=False, s_wdata=0, s_wlast=False, s_bready=True,
                s_arvalid=False, s_araddr=0, s_arlen=0, s_arsize=2, s_arprot=0, s_arid=0, s_rready=False,
                m_awready=True, m_wready=True, m_bvalid=False, m_bresp=AXIResp.OKAY,
                m_arready=True, m_rvalid=False, m_rdata=0, m_rlast=False, m_rresp=AXIResp.OKAY
            )
            
            drained_transactions += 1

        self.assertEqual(drained_transactions, 1000)
        self.assertEqual(sim.firewall.write_drain_fsm.state, "IDLE", "Drain FSM ended in non-IDLE state (Deadlock)!")
        self.assertEqual(sim.firewall.regs.fault_count, 1000, f"Expected 1000 faults, recorded {sim.firewall.regs.fault_count}")

    def test_attack_vector_5_unaligned_and_profile_violations(self):
        """TC_PROFILE_VIOLATION: Unaligned burst (ADDR[1:0]!=00) or size!=2 must be trapped as BOUND_ERR."""
        sim = SoCSystemSimulator()
        sim.firewall.regs.fw_control = (1 << 0) | (1 << 1) | (1 << 3)  # Active + IRQ + DECERR Mode
        sim.configure_firewall_static_region(0, 0x1000_0000, 0x1000_FFFF, read_en=True, write_en=True)

        # 1. Send Unaligned AWADDR = 0x1000_0002
        sim.firewall.step_cycle(
            s_awvalid=True, s_awaddr=0x1000_0002, s_awlen=0, s_awsize=2, s_awprot=0, s_awid=1,
            s_wvalid=False, s_wdata=0, s_wlast=False, s_bready=False,
            s_arvalid=False, s_araddr=0, s_arlen=0, s_arsize=2, s_arprot=0, s_arid=0, s_rready=False,
            m_awready=True, m_wready=True, m_bvalid=False, m_bresp=AXIResp.OKAY,
            m_arready=True, m_rvalid=False, m_rdata=0, m_rlast=False, m_rresp=AXIResp.OKAY
        )
        self.assertTrue(sim.firewall.w_active_fault, "Unaligned address did not trigger fault!")
        self.assertTrue(bool(sim.firewall.regs.fault_status & (1 << 3)), "BOUND_ERR not set on unaligned address!")

        # Sink the beat and finish
        sim.firewall.step_cycle(
            s_awvalid=False, s_awaddr=0, s_awlen=0, s_awsize=2, s_awprot=0, s_awid=0,
            s_wvalid=True, s_wdata=0x1234, s_wlast=True, s_bready=False,
            s_arvalid=False, s_araddr=0, s_arlen=0, s_arsize=2, s_arprot=0, s_arid=0, s_rready=False,
            m_awready=True, m_wready=True, m_bvalid=False, m_bresp=AXIResp.OKAY,
            m_arready=True, m_rvalid=False, m_rdata=0, m_rlast=False, m_rresp=AXIResp.OKAY
        )
        sim.firewall.step_cycle(
            s_awvalid=False, s_awaddr=0, s_awlen=0, s_awsize=2, s_awprot=0, s_awid=0,
            s_wvalid=False, s_wdata=0, s_wlast=False, s_bready=True,
            s_arvalid=False, s_araddr=0, s_arlen=0, s_arsize=2, s_arprot=0, s_arid=0, s_rready=False,
            m_awready=True, m_wready=True, m_bvalid=False, m_bresp=AXIResp.OKAY,
            m_arready=True, m_rvalid=False, m_rdata=0, m_rlast=False, m_rresp=AXIResp.OKAY
        )
        self.assertEqual(sim.firewall.write_drain_fsm.state, "IDLE")

if __name__ == "__main__":
    unittest.main()
