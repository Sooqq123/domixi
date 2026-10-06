# -*- coding: utf-8 -*-
"""
Cycle-Accurate SoC Components Model: DMA Controller, Synchronous FIFO, System Memories & Interconnect.
Spec Version: V2.4.1 Clarification & Closure Baseline
"""

from collections import deque
from typing import Optional, Dict, List
import random
from model.config import AXIResp, AXIBurst, SoCConfig

class SynchronousFIFO:
    """
    Cycle-accurate model of hardware FIFO buffer (dma_fifo_latch.v)
    Tracks pointers, occupancy, stall events, and peak high-water mark.
    """
    def __init__(self, depth: int = 32, width_bits: int = 32):
        self.depth = depth
        self.width_bits = width_bits
        self.buffer = deque(maxlen=depth)
        self.peak_occupancy = 0
        self.total_writes = 0
        self.total_reads = 0
        self.overflow_count = 0
        self.underflow_count = 0

    @property
    def count(self) -> int:
        return len(self.buffer)

    @property
    def full(self) -> bool:
        return len(self.buffer) >= self.depth

    @property
    def empty(self) -> bool:
        return len(self.buffer) == 0

    def push(self, data: int) -> bool:
        if self.full:
            self.overflow_count += 1
            return False
        self.buffer.append(data & ((1 << self.width_bits) - 1))
        self.total_writes += 1
        if len(self.buffer) > self.peak_occupancy:
            self.peak_occupancy = len(self.buffer)
        return True

    def pop(self) -> Optional[int]:
        if self.empty:
            self.underflow_count += 1
            return None
        self.total_reads += 1
        return self.buffer.popleft()

    def reset(self):
        self.buffer.clear()
        self.peak_occupancy = 0
        self.total_writes = 0
        self.total_reads = 0
        self.overflow_count = 0
        self.underflow_count = 0

    def flush(self):
        """Discard buffered payload without rewriting performance counters."""
        self.buffer.clear()


class SystemMemory:
    """
    Cycle-accurate model of System RAM (DDR / Secure SRAM / MMIO).
    Supports configurable read/write latencies and backpressure wait-states.
    """
    def __init__(self, size_bytes: int = 1024 * 1024, base_addr: int = 0x0000_0000, 
                 read_latency: int = 1, write_latency: int = 1):
        self.size_bytes = size_bytes
        self.base_addr = base_addr
        self.read_latency = read_latency
        self.write_latency = write_latency
        self.memory: Dict[int, int] = {}  # Word-aligned address -> 32-bit word

    def is_in_range(self, addr: int) -> bool:
        return self.base_addr <= addr < (self.base_addr + self.size_bytes)

    def write_word(self, addr: int, data: int):
        aligned_addr = addr & ~0x3
        self.memory[aligned_addr] = data & 0xFFFF_FFFF

    def read_word(self, addr: int) -> int:
        aligned_addr = addr & ~0x3
        return self.memory.get(aligned_addr, 0x0000_0000)

    def load_bytes(self, start_addr: int, data_bytes: bytes):
        for i in range(0, len(data_bytes), 4):
            chunk = data_bytes[i:i+4]
            val = int.from_bytes(chunk, byteorder='little')
            self.write_word(start_addr + i, val)

    def read_bytes(self, start_addr: int, length: int) -> bytes:
        out = bytearray()
        for i in range(0, length, 4):
            val = self.read_word(start_addr + i)
            val_bytes = val.to_bytes(4, byteorder='little')
            out.extend(val_bytes[:min(4, length - i)])
        return bytes(out)


class DMACore:
    """
    Cycle-Accurate Model of DMA Controller Core (dma_controller.v / dma_axi_master.v).
    Includes FSMs for Read/Write bursts, Internal FIFO, APB slave, and Sideband context outputs.
    """
    def __init__(self, config: SoCConfig):
        self.config = config
        self.fifo = SynchronousFIFO(depth=config.fifo_depth, width_bits=32)

        # Configuration Registers (APB accessible)
        self.cfg_src_addr = 0x0000_0000
        self.cfg_dst_addr = 0x0000_0000
        self.cfg_byte_len = 0
        self.cfg_start = False
        self.status_busy = False
        self.status_done = False
        self.status_error = False
        self.irq_enabled = False
        self.dma_irq = False
        self.done_set_event = False
        self.error_set_event = False
        self.last_transfer_succeeded = False
        self.abort_pending = False

        # Read Engine State
        self.r_state = "IDLE"
        self.read_addr_ptr = 0
        self.read_bytes_left = 0
        self.r_burst_len = 0
        self.r_burst_bytes = 0
        self.r_beat_cnt = 0
        self.r_expected_beats = 0
        self.ar_valid = False
        self.ar_addr = 0
        self.ar_len = 0
        self.r_ready = False

        # Write Engine State
        self.w_state = "IDLE"
        self.write_addr_ptr = 0
        self.write_bytes_left = 0
        self.w_burst_len = 0
        self.w_burst_bytes = 0
        self.w_burst_cnt = 0
        self.aw_valid = False
        self.aw_addr = 0
        self.aw_len = 0
        self.w_valid = False
        self.w_data = 0
        self.w_last = False
        self.b_ready = False
        self.aw_accepted = False

        # Sideband Context Outputs (V2.4.1 Normative Contract)
        self.dma_ctx_valid = False
        self.dma_ctx_src_addr = 0
        self.dma_ctx_dst_addr = 0
        self.dma_ctx_byte_len = 0
        self.dma_ctx_done = False

        # Performance counters
        self.total_read_beats = 0
        self.total_write_beats = 0
        self.read_stall_fifo_full_cycles = 0
        self.write_stall_fifo_empty_cycles = 0

    def start_transfer(self, src: int, dst: int, byte_len: int) -> bool:
        """Queue START.  A START while BUSY (or already pending) is a no-op."""
        if self.status_busy or self.cfg_start:
            return False
        self.cfg_src_addr = src
        self.cfg_dst_addr = dst
        self.cfg_byte_len = byte_len
        self.cfg_start = True
        return True

    def clear_status(self, *, done: bool = False, error: bool = False):
        """Model the APB W1C behavior of the sticky DONE and ERROR bits."""
        if done:
            self.status_done = False
        if error:
            self.status_error = False
        self._update_irq()

    def set_irq_enabled(self, enabled: bool):
        self.irq_enabled = bool(enabled)
        self._update_irq()

    def _update_irq(self):
        self.dma_irq = self.irq_enabled and (self.status_done or self.status_error)

    def _descriptor_valid(self) -> bool:
        if self.cfg_byte_len <= 0:
            return False
        if (self.cfg_src_addr | self.cfg_dst_addr | self.cfg_byte_len) & 0x3:
            return False
        src_end = self.cfg_src_addr + self.cfg_byte_len - 1
        dst_end = self.cfg_dst_addr + self.cfg_byte_len - 1
        return 0 <= self.cfg_src_addr <= src_end <= 0xFFFF_FFFF and \
               0 <= self.cfg_dst_addr <= dst_end <= 0xFFFF_FFFF

    def _latch_abort(self):
        self.abort_pending = True

    def _cancel_uncommitted_work(self):
        """Stop addresses that have not handshaken; committed bursts must drain."""
        if self.r_state == "ADDR":
            self.ar_valid = False
            self.r_ready = False
            self.r_state = "IDLE"
        if self.w_state == "ADDR":
            self.aw_valid = False
            self.w_valid = False
            self.w_last = False
            self.aw_accepted = False
            self.w_state = "IDLE"

    def _finish_transfer(self, *, success: bool):
        self.status_busy = False
        self.last_transfer_succeeded = success
        self.dma_ctx_valid = False
        self.dma_ctx_done = True
        self.abort_pending = False
        self.ar_valid = False
        self.r_ready = False
        self.aw_valid = False
        self.w_valid = False
        self.w_last = False
        self.b_ready = False
        self.aw_accepted = False
        self.r_state = "IDLE"
        self.w_state = "IDLE"
        if success:
            self.status_done = True
            self.done_set_event = True
        else:
            self.fifo.flush()
            self.status_error = True
            self.error_set_event = True
        self._update_irq()

    def step_cycle(self, axi_arready: bool, axi_rvalid: bool, axi_rdata: int, axi_rlast: bool, axi_rresp: AXIResp,
                   axi_awready: bool, axi_wready: bool, axi_bvalid: bool, axi_bresp: AXIResp):
        """
        Step one clock cycle for the DMA Core FSMs.
        """
        self.dma_ctx_done = False
        self.done_set_event = False
        self.error_set_event = False

        # 1. Start trigger logic
        if self.cfg_start:
            self.cfg_start = False
            if not self._descriptor_valid():
                self.last_transfer_succeeded = False
                self.status_error = True
                self.error_set_event = True
                self._update_irq()
            else:
                self.status_busy = True
                self.last_transfer_succeeded = False
                self.abort_pending = False

                # Sideband Context activation. Sticky status bits are not
                # cleared by START; software clears them through W1C.
                self.dma_ctx_valid = True
                self.dma_ctx_src_addr = self.cfg_src_addr
                self.dma_ctx_dst_addr = self.cfg_dst_addr
                self.dma_ctx_byte_len = self.cfg_byte_len

                self.read_addr_ptr = self.cfg_src_addr
                self.read_bytes_left = self.cfg_byte_len
                self.r_state = "ADDR"
                self.r_beat_cnt = 0
                self.r_expected_beats = 0

                self.write_addr_ptr = self.cfg_dst_addr
                self.write_bytes_left = self.cfg_byte_len
                self.w_state = "ADDR"
                self.w_burst_cnt = 0
                self.aw_accepted = False

        # 2. Read Engine FSM
        self._step_read_engine(axi_arready, axi_rvalid, axi_rdata, axi_rlast, axi_rresp)

        # 3. Write Engine FSM
        self._step_write_engine(axi_awready, axi_wready, axi_bvalid, axi_bresp)

        # 4. Coordinate abort/completion.  No new address may be issued after
        # an error, but an AR/AW that already handshook is drained to closure.
        if self.status_busy and self.abort_pending:
            self._cancel_uncommitted_work()
            if self.r_state == "IDLE" and self.w_state == "IDLE":
                self._finish_transfer(success=False)
        elif self.status_busy and (self.r_state == "IDLE") and (self.w_state == "IDLE") and self.fifo.empty:
            self._finish_transfer(success=True)

    def _calc_burst_len(self, addr: int, bytes_left: int) -> int:
        bytes_to_4kb = 4096 - (addr & 0xFFF)
        beats_to_4kb = bytes_to_4kb >> 2
        beats_left = (bytes_left + 3) >> 2
        max_beats = min(16, self.fifo.depth, beats_left, beats_to_4kb)
        return max(0, max_beats - 1)

    def _calc_burst_bytes(self, addr: int, bytes_left: int) -> int:
        blen = self._calc_burst_len(addr, bytes_left)
        return (blen + 1) * 4

    def _step_read_engine(self, arready: bool, rvalid: bool, rdata: int, rlast: bool, rresp: AXIResp):
        if self.r_state == "ADDR":
            self.r_ready = False
            if self.abort_pending or self.read_bytes_left == 0:
                self.r_state = "IDLE"
                self.ar_valid = False
            else:
                address_was_valid = self.ar_valid
                if not self.ar_valid:
                    burst_beats = self._calc_burst_len(self.read_addr_ptr, self.read_bytes_left) + 1
                    fifo_free = self.fifo.depth - self.fifo.count
                    if fifo_free >= burst_beats:
                        self.r_burst_len = self._calc_burst_len(self.read_addr_ptr, self.read_bytes_left)
                        self.r_burst_bytes = self._calc_burst_bytes(self.read_addr_ptr, self.read_bytes_left)
                        self.r_expected_beats = self.r_burst_len + 1
                        self.r_beat_cnt = 0
                        self.ar_addr = self.read_addr_ptr
                        self.ar_len = self.r_burst_len
                        self.ar_valid = True
                    else:
                        self.read_stall_fifo_full_cycles += 1

                if address_was_valid and arready:
                    self.ar_valid = False
                    self.r_ready = True
                    self.r_state = "DATA"

        elif self.r_state == "DATA":
            self.r_ready = True
            if rvalid and self.r_ready:
                self.total_read_beats += 1
                self.r_beat_cnt += 1
                expected_last = self.r_beat_cnt == self.r_expected_beats
                response_error = rresp != AXIResp.OKAY
                framing_error = bool(rlast) != expected_last

                if response_error or framing_error:
                    self._latch_abort()
                elif not self.abort_pending:
                    self.fifo.push(rdata)

                # A faulty slave must not be able to hold the DMA busy forever
                # by asserting RLAST early or omitting it on the ARLEN final
                # beat.  Close the accepted read at the first protocol terminal
                # condition and let the abort coordinator flush partial data.
                close_read = bool(rlast) or expected_last
                if close_read:
                    self.r_ready = False
                    if self.abort_pending:
                        self.r_state = "IDLE"
                    else:
                        self.read_addr_ptr += self.r_burst_bytes
                        self.read_bytes_left = max(0, self.read_bytes_left - self.r_burst_bytes)
                        self.r_state = "ADDR"

    def _step_write_engine(self, awready: bool, wready: bool, bvalid: bool, bresp: AXIResp):
        if self.w_state == "ADDR":
            self.b_ready = False
            if self.abort_pending or self.write_bytes_left == 0:
                self.w_state = "IDLE"
                self.aw_valid = False
                self.aw_accepted = False
            else:
                address_was_valid = self.aw_valid
                if not self.aw_valid:
                    burst_beats = self._calc_burst_len(self.write_addr_ptr, self.write_bytes_left) + 1
                    if self.fifo.count >= burst_beats:
                        self.w_burst_len = self._calc_burst_len(self.write_addr_ptr, self.write_bytes_left)
                        self.w_burst_bytes = self._calc_burst_bytes(self.write_addr_ptr, self.write_bytes_left)
                        self.aw_addr = self.write_addr_ptr
                        self.aw_len = self.w_burst_len
                        self.aw_valid = True
                        self.w_burst_cnt = 0
                    else:
                        self.write_stall_fifo_empty_cycles += 1

                if address_was_valid and awready:
                    self.aw_valid = False
                    self.aw_accepted = True
                    self.w_state = "DATA"

        elif self.w_state == "DATA":
            # 1. Check if previous beat was accepted by slave
            if wready and self.w_valid:
                self.total_write_beats += 1
                self.w_burst_cnt += 1
                self.w_valid = False
                if self.w_last:
                    self.w_last = False
                    self.w_state = "RESP"
                    self.b_ready = True

            # 2. Present next beat if buffer not empty
            if self.w_state == "DATA" and not self.w_valid and not self.fifo.empty:
                val = self.fifo.pop()
                if val is not None:
                    self.w_data = val
                    self.w_valid = True
                    self.w_last = (self.w_burst_cnt == self.w_burst_len)

        elif self.w_state == "RESP":
            self.b_ready = True
            if bvalid and self.b_ready:
                self.b_ready = False
                self.aw_accepted = False
                self.write_addr_ptr += self.w_burst_bytes
                self.write_bytes_left = max(0, self.write_bytes_left - self.w_burst_bytes)
                if bresp != AXIResp.OKAY:
                    self._latch_abort()
                    self.w_state = "IDLE"
                else:
                    self.w_state = "IDLE" if self.abort_pending else "ADDR"
