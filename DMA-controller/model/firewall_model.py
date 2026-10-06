# -*- coding: utf-8 -*-
"""
Cycle-Accurate Model of DMA-Aware Bus Firewall IP (dma_bus_firewall.v).
Spec Version: V2.4.1 Clarification & Closure Baseline
"""

from dataclasses import dataclass
from typing import List, Dict, Optional, Tuple
from model.config import AXIResp, ErrorMode, NUM_REGIONS, SoCConfig
from model.golden_ref import GoldenACLRegion


@dataclass(frozen=True)
class FaultRecord:
    addr: int
    len_beats: int
    size: int
    is_write: bool
    mid: int
    fault_type_bit: int
    current_cycle: int
    source: str

class APBRegisterFile:
    """
    Secure APB4 Register File with Hardware Sticky Lock (NIST SP 800-193).
    Spec Version: V2.4.1 Clarification & Closure Baseline
    """
    def __init__(self):
        # [0] EN=1 (Fail-Secure Default), [1] IRQ_EN=0, [2] AUTO_CTX_EN=1, [3] ERR_MODE=1 -> 0x0000_000D
        self.fw_control = 0x0000_000D
        self.fw_lock = 0x0000_0000        # [0] STICKY_LOCK (RW1S)
        self.fault_status = 0x0000_0000   # [0] RdErr, [1] WrErr, [2] ProtErr, [3] BndErr, [31] IRQ
        self.fault_addr = 0x0000_0000
        self.fault_info = 0x0000_0000     # [3:0] MID, [11:4] LEN, [14:12] SIZE, [15] TYPE, [31:16] COUNT
        self.fault_timestamp = 0x0000_0000
        self.fault_source = 0x0000_0000    # [1:0] source, [5:2] selected record code
        self.regions: List[GoldenACLRegion] = [GoldenACLRegion() for _ in range(NUM_REGIONS)]
        # Default Dynamic Regions: 4 (RO), 5 (WO), ACTIVE=0
        self.regions[4].perm = 0x0000_0001  # Read-Only, ACTIVE=0
        self.regions[5].perm = 0x0000_0002  # Write-Only, ACTIVE=0
        self.fault_count = 0
        self.sec_irq = False

    @property
    def is_locked(self) -> bool:
        return bool(self.fw_lock & 0x1)

    @property
    def is_fw_enabled(self) -> bool:
        return bool(self.fw_control & (1 << 0))

    @property
    def is_irq_enabled(self) -> bool:
        return bool(self.fw_control & (1 << 1))

    @property
    def is_auto_ctx_enabled(self) -> bool:
        return bool(self.fw_control & (1 << 2))

    @property
    def error_mode(self) -> ErrorMode:
        return ErrorMode.DECERR if bool(self.fw_control & (1 << 3)) else ErrorMode.HONEYPOT

    def _resolve_offset(self, paddr: int) -> Tuple[int, bool]:
        """Resolves APB address to 8-bit offset and validates window/alignment."""
        if (paddr & 0x3) != 0:
            return 0, False  # Misaligned address
        if 0x1000_0000 <= paddr <= 0x1000_00FF:
            return (paddr & 0xFF), True
        elif 0x000 <= paddr <= 0x0FF:
            return paddr, True
        return 0, False  # Out of MMIO window

    def write_apb(self, paddr: int, pwdata: int, pprot: int = 0b001) -> Tuple[bool, bool]:
        """
        Execute APB write. Returns: (success, pslverr)
        Only allows access from Secure Privileged Mode (PPROT[1]=0, PPROT[0]=1).
        """
        is_secure = not bool(pprot & 0b010)
        is_priv   = bool(pprot & 0b001)

        # Check APB Security
        if not is_secure or not is_priv:
            return False, True  # PSLVERR due to privilege/security violation

        offset, valid = self._resolve_offset(paddr)
        if not valid:
            return False, True  # PSLVERR due to misaligned or out-of-window address

        # Check Dynamic Regions 4 & 5: APB Read-Only (Hardware-Owned)
        if 0x060 <= offset < 0x080:
            return False, True  # PSLVERR: Cannot write to Dynamic Region 4 & 5 via APB!

        # Check Sticky Lock (NIST SP 800-193): Locks Region 0-3, 6-7, and FW_CONTROL
        if self.is_locked and offset != 0x008:
            return False, True  # PSLVERR: Cannot write after sticky lock is active

        if offset == 0x000:
            old_auto_ctx_enabled = self.is_auto_ctx_enabled
            self.fw_control = pwdata & 0x0F
            if old_auto_ctx_enabled and not self.is_auto_ctx_enabled:
                self.regions[4].perm &= ~(1 << 31)
                self.regions[5].perm &= ~(1 << 31)
            self.sec_irq = self.is_irq_enabled and bool(self.fault_status & (1 << 31))
        elif offset == 0x004:
            # RW1S: Once bit 0 is written 1, it stays 1 until hardware reset
            if pwdata & 0x1:
                self.fw_lock = 0x0000_0001
        elif offset == 0x008:
            # W1C (Write 1 to clear)
            # Clearing bits [3:0] clears error types
            # Clearing bit [31] clears IRQ_PENDING and deasserts sec_irq
            self.fault_status &= ~pwdata
            self.sec_irq = self.is_irq_enabled and bool(self.fault_status & (1 << 31))
        elif 0x020 <= offset < 0x0A0:
            reg_idx = (offset - 0x020) // 16
            field_idx = (offset - 0x020) % 16
            if reg_idx < NUM_REGIONS and reg_idx not in (4, 5):
                # Region Configuration Protocol: Cannot modify descriptor if Region is ACTIVE
                if self.regions[reg_idx].active:
                    # Only allow writing to PERM (field_idx == 8) if clearing the ACTIVE bit
                    if field_idx != 0x08 or (pwdata & (1 << 31)):
                        return False, True  # PSLVERR: Must deactivate region before editing descriptor!

                if field_idx == 0x00:
                    self.regions[reg_idx].base = pwdata
                elif field_idx == 0x04:
                    self.regions[reg_idx].limit = pwdata
                elif field_idx == 0x08:
                    if (pwdata & (1 << 31)) and self.regions[reg_idx].base > self.regions[reg_idx].limit:
                        return False, True
                    self.regions[reg_idx].perm = pwdata
                elif field_idx == 0x0C:
                    self.regions[reg_idx].mid = pwdata & 0xFF
        else:
            return False, True  # PSLVERR: Unmapped offset

        return True, False

    def read_apb(self, paddr: int, pprot: int = 0b001) -> Tuple[int, bool]:
        """
        Execute APB read. Returns: (data, pslverr)
        """
        is_secure = not bool(pprot & 0b010)
        is_priv   = bool(pprot & 0b001)
        if not is_secure or not is_priv:
            return 0x0000_0000, True

        offset, valid = self._resolve_offset(paddr)
        if not valid:
            return 0x0000_0000, True

        if offset == 0x000:
            return self.fw_control, False
        elif offset == 0x004:
            return self.fw_lock, False
        elif offset == 0x008:
            return self.fault_status, False
        elif offset == 0x00C:
            return self.fault_addr, False
        elif offset == 0x010:
            return ((self.fault_count << 16) | (self.fault_info & 0xFFFF)), False
        elif offset == 0x014:
            return self.fault_timestamp, False
        elif offset == 0x018:
            return self.fault_source, False
        elif 0x020 <= offset < 0x0A0:
            reg_idx = (offset - 0x020) // 16
            field_idx = (offset - 0x020) % 16
            if reg_idx < NUM_REGIONS:
                if field_idx == 0x00:
                    return self.regions[reg_idx].base, False
                elif field_idx == 0x04:
                    return self.regions[reg_idx].limit, False
                elif field_idx == 0x08:
                    return self.regions[reg_idx].perm, False
                elif field_idx == 0x0C:
                    return self.regions[reg_idx].mid, False
        return 0x0000_0000, True  # Unmapped offset

    def record_faults(self, records: List[FaultRecord]):
        """Atomically record simultaneous faults using V2.4.1 priority."""
        if not records:
            return

        self.fault_count = min(0xFFFF, self.fault_count + len(records))
        if not (self.fault_status & 0x8000_000F):
            source_priority = {"context": 0, "write": 1, "read": 2}
            selected = min(
                enumerate(records),
                key=lambda item: (source_priority.get(item[1].source, 3), item[0]),
            )[1]
            self.fault_addr = selected.addr
            self.fault_info = (
                (selected.mid & 0xF) |
                ((selected.len_beats & 0xFF) << 4) |
                ((selected.size & 0x7) << 12) |
                ((1 if selected.is_write else 0) << 15)
            )
            self.fault_timestamp = selected.current_cycle
            source_encoding = {"read": 0b00, "write": 0b01, "context": 0b10}
            self.fault_source = (
                source_encoding.get(selected.source, 0) |
                ((selected.fault_type_bit & 0xF) << 2)
            )

        status_bits = 0
        for record in records:
            status_bits |= 1 << record.fault_type_bit
        self.fault_status |= status_bits | (1 << 31)
        self.sec_irq = self.is_irq_enabled

    def record_fault(self, addr: int, len_beats: int, size: int, is_write: bool,
                     mid: int, fault_type_bit: int, current_cycle: int,
                     source: Optional[str] = None):
        self.record_faults([FaultRecord(
            addr=addr,
            len_beats=len_beats,
            size=size,
            is_write=is_write,
            mid=mid,
            fault_type_bit=fault_type_bit,
            current_cycle=current_cycle,
            source=source or ("write" if is_write else "read"),
        )])


class WriteDrainFSM:
    """
    Deadlock-Free Write Drain FSM (fw_drain_fsm.v).
    Sinks and discards all malicious WDATA at 1 beat/cycle and completes standard AXI handshake.
    """
    def __init__(self):
        self.state = "IDLE"
        self.wready = False
        self.bvalid = False
        self.bresp = AXIResp.OKAY
        self.bid = 0
        self.drained_beats = 0
        self.expected_beats: Optional[int] = None
        self.protocol_error = False

    def step(self, w_fault_trigger: bool, wvalid: bool, wlast: bool, bready: bool, 
             err_mode: ErrorMode, master_id: int, awlen: Optional[int] = None):
        if self.state == "IDLE":
            self.wready = False
            self.bvalid = False
            if w_fault_trigger:
                self.state = "SINK"
                self.wready = True
                self.drained_beats = 0
                self.expected_beats = None if awlen is None else awlen + 1
                self.protocol_error = False
                self.bid = master_id
                self.bresp = AXIResp.OKAY if err_mode == ErrorMode.HONEYPOT else AXIResp.DECERR

        elif self.state == "SINK":
            self.wready = True
            if wvalid and self.wready:
                self.drained_beats += 1
                expected_last = (
                    self.expected_beats is None or
                    self.drained_beats == self.expected_beats
                )
                if self.expected_beats is not None and bool(wlast) != expected_last:
                    self.protocol_error = True

                enough_beats = (
                    self.expected_beats is None or
                    self.drained_beats >= self.expected_beats
                )
                if wlast and enough_beats:
                    self.wready = False
                    self.bvalid = True
                    self.state = "RESP"

        elif self.state == "RESP":
            self.bvalid = True
            if bready and self.bvalid:
                self.bvalid = False
                self.state = "IDLE"


class ReadDrainFSM:
    """
    Deadlock-Free Read Drain FSM (fw_drain_fsm.v).
    Generates synthetic poison/zeros with DECERR response to sink read fault cleanly.
    """
    def __init__(self):
        self.state = "IDLE"
        self.rvalid = False
        self.rlast = False
        self.rdata = 0x0000_0000
        self.rresp = AXIResp.OKAY
        self.rid = 0
        self.beats_to_gen = 0
        self.beats_generated = 0

    def step(self, r_fault_trigger: bool, arlen: int, rready: bool, 
             err_mode: ErrorMode, master_id: int):
        if self.state == "IDLE":
            self.rvalid = False
            self.rlast = False
            if r_fault_trigger:
                self.state = "GEN"
                self.beats_to_gen = arlen + 1
                self.beats_generated = 0
                self.rid = master_id
                self.rresp = AXIResp.OKAY if err_mode == ErrorMode.HONEYPOT else AXIResp.DECERR

        elif self.state == "GEN":
            self.rvalid = True
            self.rdata = 0x0000_0000
            self.rlast = (self.beats_generated == (self.beats_to_gen - 1))
            if rready and self.rvalid:
                self.beats_generated += 1
                if self.rlast:
                    self.state = "IDLE"


class DMAAwareBusFirewall:
    """
    Complete Cycle-Accurate Architecture Model of DMA-Aware Bus Firewall IP.
    """
    def __init__(self, config: SoCConfig):
        self.config = config
        self.regs = APBRegisterFile()
        self.write_drain_fsm = WriteDrainFSM()
        self.read_drain_fsm = ReadDrainFSM()

        # Initialize from the model configuration while preserving the V2.4.1
        # bit layout: EN, IRQ_EN, AUTO_CTX_EN, ERR_MODE.
        self.regs.fw_control = (
            (1 if config.default_firewall_enabled else 0) |
            ((1 if config.auto_context_enabled else 0) << 2) |
            ((1 if config.default_error_mode == ErrorMode.DECERR else 0) << 3)
        )

        # 2-Stage Address Pipeline Registers (Stage 1 & Stage 2)
        self.stage1_aw_valid = False
        self.stage1_aw_addr = 0
        self.stage1_aw_len = 0
        self.stage1_aw_size = 2
        self.stage1_aw_burst = 1
        self.stage1_aw_end = 0
        self.stage1_aw_prot = 0
        self.stage1_aw_id = 0

        self.stage1_ar_valid = False
        self.stage1_ar_addr = 0
        self.stage1_ar_len = 0
        self.stage1_ar_size = 2
        self.stage1_ar_burst = 1
        self.stage1_ar_end = 0
        self.stage1_ar_prot = 0
        self.stage1_ar_id = 0

        # Shadow Permission Latch for in-flight transactions
        self.w_active_fault = False
        self.r_active_fault = False
        self.current_cycle = 0

        # One independently outstanding write and read transaction.  The ACL
        # decision and all address metadata are immutable after Ax handshake.
        self.w_txn_active = False
        self.w_txn_allowed = False
        self.w_aw_forwarded = False
        self.w_expected_beats = 0
        self.w_seen_beats = 0
        self.w_protocol_error = False

        self.r_txn_active = False
        self.r_txn_allowed = False
        self.r_ar_forwarded = False
        self.r_expected_beats = 0
        self.r_seen_beats = 0
        self.r_protocol_error = False

        # Response skid registers make payload and IDs stable under upstream
        # backpressure instead of relying on a combinational cut-through path.
        self.b_hold_valid = False
        self.b_hold_resp = AXIResp.OKAY
        self.b_hold_id = 0
        self.r_hold_valid = False
        self.r_hold_data = 0
        self.r_hold_resp = AXIResp.OKAY
        self.r_hold_last = False
        self.r_hold_id = 0
        self._dma_valid_seen = False

    def _evaluate_snapshot(self, *, addr: int, length: int, size: int,
                           burst: int, prot: int, master_id: int,
                           is_write: bool) -> Tuple[bool, Optional[FaultRecord]]:
        """Return one immutable decision and its optional fault record."""
        burst_bytes = (length + 1) * (1 << size)
        end_addr = addr + burst_bytes - 1
        profile_error = (
            size != 2 or (addr & 0x3) != 0 or length > 15 or burst != 1
        )
        boundary_error = (
            end_addr > 0xFFFF_FFFF or
            (addr & 0xFFFF_F000) != (end_addr & 0xFFFF_F000)
        )
        if profile_error or boundary_error:
            return False, FaultRecord(
                addr, length, size, is_write, master_id, 3,
                self.current_cycle, "write" if is_write else "read",
            )

        if not self.regs.is_fw_enabled:
            return True, None

        matches = [r for r in self.regs.regions if r.match_range(addr, end_addr)]
        if not matches:
            return False, FaultRecord(
                addr, length, size, is_write, master_id,
                1 if is_write else 0, self.current_cycle,
                "write" if is_write else "read",
            )

        is_secure = not bool(prot & 0b010)
        is_priv = bool(prot & 0b001)
        for region in matches:
            permission_ok = region.write_en if is_write else region.read_en
            if not permission_ok or not region.match_mid(master_id):
                return False, FaultRecord(
                    addr, length, size, is_write, master_id,
                    1 if is_write else 0, self.current_cycle,
                    "write" if is_write else "read",
                )
            if not region.match_prot(is_secure, is_priv):
                return False, FaultRecord(
                    addr, length, size, is_write, master_id, 2,
                    self.current_cycle, "write" if is_write else "read",
                )
        return True, None

    def update_sideband_context(self, dma_valid: bool, dma_src: int, dma_dst: int, 
                                dma_len: int, dma_done: bool):
        """
        Dynamic Context Tracker Model (V2.4.1):
        Auto-allocates Region 4 (Read-Only) & Region 5 (Write-Only), and performs Zero-Delay Revocation.
        Rejects misaligned addresses/len, len=0, or 32-bit address overflow by staying inactive and logging BOUND_ERR.
        """
        accept_valid = dma_valid and not self._dma_valid_seen
        if dma_valid:
            self._dma_valid_seen = True
        else:
            self._dma_valid_seen = False

        # Priority: dma_done (Revoke) > new dma_valid edge (Allocate)
        if dma_done:
            # Zero-Delay Revocation: Drop active bits immediately
            self.regs.regions[4].perm &= ~(1 << 31)
            self.regs.regions[5].perm &= ~(1 << 31)
        elif accept_valid and self.regs.is_auto_ctx_enabled:
            # Check alignment (4B-aligned), len == 0, or 32-bit range overflow
            is_misaligned = ((dma_src & 3) != 0) or ((dma_dst & 3) != 0) or ((dma_len & 3) != 0)
            is_overflow   = (dma_len == 0) or ((dma_src + dma_len - 1) > 0xFFFF_FFFF) or ((dma_dst + dma_len - 1) > 0xFFFF_FFFF)
            
            if is_misaligned or is_overflow:
                self.regs.record_fault(
                    dma_src, 0, 2, False, 0, 3, self.current_cycle,
                    source="context",
                )
                self.regs.regions[4].perm &= ~(1 << 31)
                self.regs.regions[5].perm &= ~(1 << 31)
            else:
                # Dynamic Region 4: Source (Read-Only) - Exact 32-bit address
                self.regs.regions[4].base = dma_src
                self.regs.regions[4].limit = dma_src + dma_len - 1
                self.regs.regions[4].perm = (
                    (1 << 31) | (1 << 3) | (1 << 2) | (1 << 0)
                )
                self.regs.regions[4].mid = 0x00

                # Dynamic Region 5: Destination (Write-Only) - Exact 32-bit address
                self.regs.regions[5].base = dma_dst
                self.regs.regions[5].limit = dma_dst + dma_len - 1
                self.regs.regions[5].perm = (
                    (1 << 31) | (1 << 3) | (1 << 2) | (1 << 1)
                )
                self.regs.regions[5].mid = 0x00

    def step_cycle(self, 
                   # Slave Interface Inputs (from DMA Master)
                   s_awvalid: bool, s_awaddr: int, s_awlen: int, s_awsize: int, s_awprot: int, s_awid: int,
                   s_wvalid: bool, s_wdata: int, s_wlast: bool, s_bready: bool,
                   s_arvalid: bool, s_araddr: int, s_arlen: int, s_arsize: int, s_arprot: int, s_arid: int,
                   s_rready: bool,
                   # Master Interface Inputs (from Interconnect)
                   m_awready: bool, m_wready: bool, m_bvalid: bool, m_bresp: AXIResp,
                   m_arready: bool, m_rvalid: bool, m_rdata: int, m_rlast: bool, m_rresp: AXIResp,
                   s_awburst: int = 1, s_arburst: int = 1,
                   m_bid: Optional[int] = None, m_rid: Optional[int] = None):
        """
        Step one clock cycle for the entire Firewall IP.
        Enforces DMA-Constrained AXI Profile (INCR, size=2 (4B), aligned addr[1:0]=0, len<=15).
        """
        self.current_cycle += 1

        write_active_at_start = self.w_txn_active
        read_active_at_start = self.r_txn_active
        write_allowed_at_start = self.w_txn_allowed
        read_allowed_at_start = self.r_txn_allowed
        aw_forwarded_at_start = self.w_aw_forwarded
        ar_forwarded_at_start = self.r_ar_forwarded

        s_awready = not write_active_at_start
        s_arready = not read_active_at_start
        aw_accept = s_awvalid and s_awready
        ar_accept = s_arvalid and s_arready
        cycle_faults: List[FaultRecord] = []

        if aw_accept:
            self.stage1_aw_addr = s_awaddr
            self.stage1_aw_len = s_awlen
            self.stage1_aw_size = s_awsize
            self.stage1_aw_burst = s_awburst
            self.stage1_aw_prot = s_awprot
            self.stage1_aw_id = s_awid
            self.stage1_aw_end = s_awaddr + (s_awlen + 1) * (1 << s_awsize) - 1
            self.w_txn_active = True
            self.w_txn_allowed, fault = self._evaluate_snapshot(
                addr=s_awaddr, length=s_awlen, size=s_awsize,
                burst=s_awburst, prot=s_awprot, master_id=s_awid,
                is_write=True,
            )
            if fault is not None:
                cycle_faults.append(fault)
            self.w_aw_forwarded = False
            self.w_expected_beats = s_awlen + 1
            self.w_seen_beats = 0
            self.w_protocol_error = False

        if ar_accept:
            self.stage1_ar_addr = s_araddr
            self.stage1_ar_len = s_arlen
            self.stage1_ar_size = s_arsize
            self.stage1_ar_burst = s_arburst
            self.stage1_ar_prot = s_arprot
            self.stage1_ar_id = s_arid
            self.stage1_ar_end = s_araddr + (s_arlen + 1) * (1 << s_arsize) - 1
            self.r_txn_active = True
            self.r_txn_allowed, fault = self._evaluate_snapshot(
                addr=s_araddr, length=s_arlen, size=s_arsize,
                burst=s_arburst, prot=s_arprot, master_id=s_arid,
                is_write=False,
            )
            if fault is not None:
                cycle_faults.append(fault)
            self.r_ar_forwarded = False
            self.r_expected_beats = s_arlen + 1
            self.r_seen_beats = 0
            self.r_protocol_error = False

        self.regs.record_faults(cycle_faults)

        # Address outputs are driven entirely by the latched transaction.
        m_awvalid = self.w_txn_active and self.w_txn_allowed and not self.w_aw_forwarded
        m_awaddr = self.stage1_aw_addr
        m_awlen = self.stage1_aw_len
        m_awsize = self.stage1_aw_size
        m_awprot = self.stage1_aw_prot
        m_awid = self.stage1_aw_id
        if m_awvalid and m_awready:
            self.w_aw_forwarded = True

        m_arvalid = self.r_txn_active and self.r_txn_allowed and not self.r_ar_forwarded
        m_araddr = self.stage1_ar_addr
        m_arlen = self.stage1_ar_len
        m_arsize = self.stage1_ar_size
        m_arprot = self.stage1_ar_prot
        m_arid = self.stage1_ar_id
        if m_arvalid and m_arready:
            self.r_ar_forwarded = True

        self.stage1_aw_valid = bool(m_awvalid and not m_awready)
        self.stage1_ar_valid = bool(m_arvalid and not m_arready)

        # Denied paths are transaction-owned drain machines.  Capture their
        # pre-edge outputs so READY/VALID describe the handshake of this cycle.
        drain_wready = self.write_drain_fsm.wready
        drain_bvalid = self.write_drain_fsm.bvalid
        drain_bresp = self.write_drain_fsm.bresp
        drain_bid = self.write_drain_fsm.bid
        denied_write_existing = (
            write_active_at_start and not write_allowed_at_start
        )
        self.write_drain_fsm.step(
            aw_accept and not self.w_txn_allowed,
            s_wvalid if denied_write_existing else False,
            s_wlast if denied_write_existing else False,
            s_bready if denied_write_existing else False,
            self.regs.error_mode,
            self.stage1_aw_id,
            awlen=self.stage1_aw_len,
        )

        drain_rvalid = self.read_drain_fsm.rvalid
        drain_rdata = self.read_drain_fsm.rdata
        drain_rresp = self.read_drain_fsm.rresp
        drain_rlast = self.read_drain_fsm.rlast
        drain_rid = self.read_drain_fsm.rid
        denied_read_existing = read_active_at_start and not read_allowed_at_start
        self.read_drain_fsm.step(
            ar_accept and not self.r_txn_allowed,
            self.stage1_ar_len,
            s_rready if denied_read_existing else False,
            self.regs.error_mode,
            self.stage1_ar_id,
        )

        self.w_active_fault = self.w_txn_active and not self.w_txn_allowed
        self.r_active_fault = self.r_txn_active and not self.r_txn_allowed

        # Allowed write data is blocked until AW was accepted in a prior cycle.
        allowed_w_path = (
            write_active_at_start and write_allowed_at_start and
            aw_forwarded_at_start
        )
        m_wvalid = bool(s_wvalid and allowed_w_path)
        m_wdata = s_wdata if allowed_w_path else 0
        m_wlast = bool(s_wlast and allowed_w_path)
        s_wready = bool(m_wready and allowed_w_path)
        if m_wvalid and m_wready:
            self.w_seen_beats += 1
            expected_last = self.w_seen_beats == self.w_expected_beats
            if bool(s_wlast) != expected_last:
                self.w_protocol_error = True

        if denied_write_existing:
            s_wready = drain_wready
            m_wvalid = False
            m_wdata = 0
            m_wlast = False

        # Allowed write responses are buffered so B payload and ID remain stable.
        s_bvalid = self.b_hold_valid
        s_bresp = self.b_hold_resp
        s_bid = self.b_hold_id
        m_bready = bool(
            self.w_txn_active and self.w_txn_allowed and
            self.w_aw_forwarded and not self.b_hold_valid
        )
        if self.b_hold_valid and s_bready:
            self.b_hold_valid = False
            self.w_txn_active = False
        elif m_bvalid and m_bready:
            self.b_hold_valid = True
            self.b_hold_resp = m_bresp
            self.b_hold_id = self.stage1_aw_id if m_bid is None else m_bid

        if denied_write_existing:
            s_bvalid = drain_bvalid
            s_bresp = drain_bresp
            s_bid = drain_bid
            m_bready = False
            if drain_bvalid and s_bready:
                self.w_txn_active = False

        # Allowed read data uses a one-beat skid register and exact beat count.
        s_rvalid = self.r_hold_valid
        s_rdata = self.r_hold_data
        s_rresp = self.r_hold_resp
        s_rlast = self.r_hold_last
        s_rid = self.r_hold_id
        m_rready = bool(
            self.r_txn_active and self.r_txn_allowed and
            self.r_ar_forwarded and not self.r_hold_valid
        )
        if self.r_hold_valid and s_rready:
            completed = self.r_hold_last and self.r_seen_beats == self.r_expected_beats
            self.r_hold_valid = False
            if completed:
                self.r_txn_active = False
        elif m_rvalid and m_rready:
            self.r_seen_beats += 1
            expected_last = self.r_seen_beats == self.r_expected_beats
            if bool(m_rlast) != expected_last:
                self.r_protocol_error = True
            self.r_hold_valid = True
            self.r_hold_data = m_rdata
            self.r_hold_resp = m_rresp
            self.r_hold_last = m_rlast
            self.r_hold_id = self.stage1_ar_id if m_rid is None else m_rid

        if denied_read_existing:
            s_rvalid = drain_rvalid
            s_rdata = drain_rdata
            s_rresp = drain_rresp
            s_rlast = drain_rlast
            s_rid = drain_rid
            m_rready = False
            if drain_rvalid and drain_rlast and s_rready:
                self.r_txn_active = False

        return {
            # Outputs to DMA Master
            "s_awready": s_awready,
            "s_wready": s_wready,
            "s_bvalid": s_bvalid,
            "s_bresp": s_bresp,
            "s_bid": s_bid,
            "s_arready": s_arready,
            "s_rvalid": s_rvalid,
            "s_rdata": s_rdata,
            "s_rresp": s_rresp,
            "s_rlast": s_rlast,
            "s_rid": s_rid,
            # Outputs to Interconnect
            "m_awvalid": m_awvalid,
            "m_awaddr": m_awaddr,
            "m_awlen": m_awlen,
            "m_awsize": m_awsize,
            "m_awprot": m_awprot,
            "m_awid": m_awid,
            "m_wvalid": m_wvalid,
            "m_wdata": m_wdata,
            "m_wlast": m_wlast,
            "m_bready": m_bready,
            "m_arvalid": m_arvalid,
            "m_araddr": m_araddr,
            "m_arlen": m_arlen,
            "m_arsize": m_arsize,
            "m_arprot": m_arprot,
            "m_arid": m_arid,
            "m_rready": m_rready,
            # Security Alert
            "sec_irq": self.regs.sec_irq
        }
