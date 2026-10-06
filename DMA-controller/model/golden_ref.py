# -*- coding: utf-8 -*-
"""
Golden Reference Algorithm Model for DMA Controller & DMA-Aware Bus Firewall IP.
Spec Version: V2.4.1 Clarification & Closure Baseline
"""

from typing import List, Dict, Tuple, Optional
from model.config import AXIResp, ErrorMode, NUM_REGIONS

class GoldenACLRegion:
    def __init__(self, base: int = 0, limit: int = 0, perm: int = 0, mid: int = 0):
        self.base = base                  # Exact 32-bit address (no 4KB over-grant)
        self.limit = limit
        self.perm = perm
        self.mid = mid

    @property
    def active(self) -> bool:
        return bool(self.perm & (1 << 31))

    @property
    def read_en(self) -> bool:
        return bool(self.perm & (1 << 0))

    @property
    def write_en(self) -> bool:
        return bool(self.perm & (1 << 1))

    @property
    def secure_only(self) -> bool:
        return bool(self.perm & (1 << 2))

    @property
    def priv_only(self) -> bool:
        return bool(self.perm & (1 << 3))

    @property
    def whitelist_mid(self) -> int:
        return self.mid & 0x0F

    @property
    def mid_mask(self) -> int:
        return (self.mid >> 4) & 0x0F

    def match_range(self, start_addr: int, end_addr: int) -> bool:
        if not self.active:
            return False
        # Both start and end must fall within [base, limit]
        return (start_addr >= self.base) and (end_addr <= self.limit)

    def match_mid(self, master_id: int) -> bool:
        masked_id = master_id & ~self.mid_mask
        masked_white = self.whitelist_mid & ~self.mid_mask
        return masked_id == masked_white

    def match_prot(self, is_secure: bool, is_priv: bool) -> bool:
        if self.secure_only and not is_secure:
            return False
        if self.priv_only and not is_priv:
            return False
        return True


class GoldenFirewallEngine:
    """
    Algorithmic reference for Bus Firewall access control decision.
    Spec Version: V2.4.1 Clarification & Closure Baseline
    """
    def __init__(self):
        self.enabled = True   # Fail-Secure Default: Enabled out of reset
        self.locked = False
        self.error_mode = ErrorMode.DECERR
        self.auto_ctx_en = True
        self.regions: List[GoldenACLRegion] = [GoldenACLRegion() for _ in range(NUM_REGIONS)]
        self.fault_count = 0
        self.first_fault: Optional[Dict] = None

    def calculate_end_address(self, addr: int, len_beats: int, size_bytes_exp: int) -> int:
        burst_bytes = (len_beats + 1) * (1 << size_bytes_exp)
        return addr + burst_bytes - 1

    def check_4kb_boundary_violation(self, start_addr: int, end_addr: int) -> bool:
        return (start_addr & 0xFFFF_F000) != (end_addr & 0xFFFF_F000)

    def evaluate_access(self, addr: int, len_beats: int, size_bytes_exp: int, 
                        is_write: bool, prot: int, master_id: int, timestamp: int = 0,
                        burst_type: int = 0b01) -> Tuple[bool, AXIResp, str]:
        """
        Evaluate if an AXI access is allowed or violates firewall rules.
        Enforces DMA-Constrained Profile: INCR only, AxSIZE==2 (4B), Word-aligned, AxLEN<=15.
        Returns: (is_allowed, response_code, fault_reason)
        """
        # 0. Check DMA-Constrained AXI Profile
        # - Burst Type must be INCR (0b01)
        # - Beat size must be 4 Bytes (size_bytes_exp == 2)
        # - Address must be word-aligned (addr[1:0] == 00)
        # - Burst length must be <= 15 (max 16 beats)
        is_profile_violation = (
            (burst_type != 0b01) or
            (size_bytes_exp != 2) or
            ((addr & 0x3) != 0) or
            (len_beats > 15)
        )
        if is_profile_violation:
            self._log_fault(addr, len_beats, size_bytes_exp, is_write, master_id, "AXI_PROFILE_VIOLATION", timestamp)
            resp = AXIResp.OKAY if self.error_mode == ErrorMode.HONEYPOT else AXIResp.DECERR
            return False, resp, "AXI_PROFILE_VIOLATION"

        end_addr = self.calculate_end_address(addr, len_beats, size_bytes_exp)

        # 1. Check Burst 4KB Boundary wrap-around
        if self.check_4kb_boundary_violation(addr, end_addr):
            self._log_fault(addr, len_beats, size_bytes_exp, is_write, master_id, "BOUNDARY_OVERFLOW", timestamp)
            resp = AXIResp.OKAY if self.error_mode == ErrorMode.HONEYPOT else AXIResp.DECERR
            return False, resp, "BOUNDARY_OVERFLOW"

        if not self.enabled:
            return True, AXIResp.OKAY, "FIREWALL_BYPASS"

        # 2. Check ACL Regions (Most-Restrictive Overlap Rule: MITRE CWE-1260)
        matched_regions = []
        for i, reg in enumerate(self.regions):
            if reg.match_range(addr, end_addr):
                matched_regions.append((i, reg))

        if not matched_regions:
            # Zero-Trust Default Deny
            self._log_fault(addr, len_beats, size_bytes_exp, is_write, master_id, "DEFAULT_DENY_NO_MATCH", timestamp)
            resp = AXIResp.OKAY if self.error_mode == ErrorMode.HONEYPOT else AXIResp.DECERR
            return False, resp, "DEFAULT_DENY_NO_MATCH"

        # If matched, must satisfy ALL matched regions
        is_secure = not bool(prot & 0b010)  # AxPROT[1] == 0 is Secure
        is_priv   = bool(prot & 0b001)      # AxPROT[0] == 1 is Privileged

        for idx, reg in enumerate([r for _, r in matched_regions]):
            # Check read/write permission
            if is_write and not reg.write_en:
                self._log_fault(addr, len_beats, size_bytes_exp, is_write, master_id, f"WRITE_PERMISSION_DENIED_RGN_{idx}", timestamp)
                resp = AXIResp.OKAY if self.error_mode == ErrorMode.HONEYPOT else AXIResp.DECERR
                return False, resp, "WRITE_PERMISSION_DENIED"
            if not is_write and not reg.read_en:
                self._log_fault(addr, len_beats, size_bytes_exp, is_write, master_id, f"READ_PERMISSION_DENIED_RGN_{idx}", timestamp)
                resp = AXIResp.OKAY if self.error_mode == ErrorMode.HONEYPOT else AXIResp.DECERR
                return False, resp, "READ_PERMISSION_DENIED"

            # Check PROT
            if reg.secure_only and not is_secure:
                self._log_fault(addr, len_beats, size_bytes_exp, is_write, master_id, "NON_SECURE_ACCESS_TO_SECURE_REGION", timestamp)
                resp = AXIResp.OKAY if self.error_mode == ErrorMode.HONEYPOT else AXIResp.DECERR
                return False, resp, "PROT_MISMATCH_SECURE"
            if reg.priv_only and not is_priv:
                self._log_fault(addr, len_beats, size_bytes_exp, is_write, master_id, "UNPRIVILEGED_ACCESS_TO_PRIV_REGION", timestamp)
                resp = AXIResp.OKAY if self.error_mode == ErrorMode.HONEYPOT else AXIResp.DECERR
                return False, resp, "PROT_MISMATCH_PRIV"

            # Check Master ID Whitelist
            if not reg.match_mid(master_id):
                self._log_fault(addr, len_beats, size_bytes_exp, is_write, master_id, "MASTER_ID_NOT_WHITELISTED", timestamp)
                resp = AXIResp.OKAY if self.error_mode == ErrorMode.HONEYPOT else AXIResp.DECERR
                return False, resp, "MASTER_ID_REJECTED"

        return True, AXIResp.OKAY, "ACCESS_ALLOWED"

    def _log_fault(self, addr: int, len_beats: int, size: int, is_write: bool, mid: int, reason: str, timestamp: int):
        self.fault_count = min(0xFFFF, self.fault_count + 1)
        if self.first_fault is None:
            self.first_fault = {
                "addr": addr,
                "len": len_beats,
                "size": size,
                "is_write": is_write,
                "mid": mid,
                "reason": reason,
                "timestamp": timestamp,
                "fault_count": self.fault_count
            }

    def allocate_dynamic_dma_context(self, src: int, dst: int, byte_len: int) -> bool:
        """
        Allocate Region 4 (Read-Only) and Region 5 (Write-Only).
        Rejects misaligned addresses/len, len=0, or 32-bit address overflow.
        """
        if (src & 3 != 0) or (dst & 3 != 0) or (byte_len & 3 != 0) or (byte_len == 0):
            return False
        if (src + byte_len - 1) > 0xFFFF_FFFF or (dst + byte_len - 1) > 0xFFFF_FFFF:
            return False

        # Dynamic Region 4: Source (Read-Only)
        self.regions[4].base = src
        self.regions[4].limit = src + byte_len - 1
        self.regions[4].perm = (
            (1 << 31) | (1 << 3) | (1 << 2) | (1 << 0)
        )
        self.regions[4].mid = 0x00

        # Dynamic Region 5: Destination (Write-Only)
        self.regions[5].base = dst
        self.regions[5].limit = dst + byte_len - 1
        self.regions[5].perm = (
            (1 << 31) | (1 << 3) | (1 << 2) | (1 << 1)
        )
        self.regions[5].mid = 0x00
        return True

    def revoke_dynamic_dma_context(self):
        """Zero-Delay Revocation of Region 4 & 5"""
        self.regions[4].perm &= ~(1 << 31)
        self.regions[5].perm &= ~(1 << 31)
