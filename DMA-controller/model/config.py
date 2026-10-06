# -*- coding: utf-8 -*-
"""
System Configuration Parameters for DMA Controller & DMA-Aware Bus Firewall IP.
Spec Version: V2.4.1 Clarification & Closure Baseline
"""

from dataclasses import dataclass
from enum import IntEnum

# Global Clock & Frequency Settings
CLOCK_FREQ_ASIC_28NM_HZ = 800_000_000   # 800 MHz (1.25 ns period)
CLOCK_FREQ_FPGA_HZ        = 300_000_000   # 300 MHz (3.33 ns period)
CLOCK_FREQ_SKYWATER_HZ    = 150_000_000   # 150 MHz (6.67 ns period)

# Bus Width & Profile Configurations (DMA-Constrained)
ADDR_WIDTH     = 32
DATA_WIDTH     = 32
ID_WIDTH       = 4
NUM_REGIONS    = 8
MAX_BURST_BEATS = 16  # AxLEN <= 15
MAX_AXLEN      = 15
WORD_SIZE_EXP  = 2   # AxSIZE == 2 (4 bytes / 32-bit word)

class AXIResp(IntEnum):
    OKAY   = 0b00
    EXOKAY = 0b01
    SLVERR = 0b10
    DECERR = 0b11

class AXIBurst(IntEnum):
    FIXED = 0b00
    INCR  = 0b01
    WRAP  = 0b10

class ErrorMode(IntEnum):
    HONEYPOT = 0  # Mode 0: Deceptive Defense (return OKAY 2'b00, discard data)
    DECERR   = 1  # Mode 1: Fail-Secure (return DECERR 2'b11, discard data)

@dataclass
class SoCConfig:
    clock_freq_hz: int = CLOCK_FREQ_ASIC_28NM_HZ
    fifo_depth: int = 32
    mem_read_latency_cycles: int = 1
    mem_write_latency_cycles: int = 1
    bus_contention_rate: float = 0.0  # Probability of interconnect delay
    default_firewall_enabled: bool = True
    default_error_mode: ErrorMode = ErrorMode.DECERR
    auto_context_enabled: bool = True

    @property
    def clock_period_ns(self) -> float:
        return 1.0e9 / self.clock_freq_hz
