# SƠ ĐỒ KHỐI CHI TIẾT & ĐẶC TẢ GIAO DIỆN LIÊN MODULE (DETAILED BLOCK DIAGRAM)
## DMA-Aware Bus Firewall IP & DMA Controller Core
**Tài liệu:** Architecture Specification - Single Source of Truth (SSOT)  
**Phiên bản:** V2.4.1 DMA-Constrained Clarification & Closure Baseline  
**Ngày cập nhật:** 2026-08-23  
**Trạng thái:** Canonical Architecture Baseline V2.4.1 — RTL Integrated / Frontend Verified

---

## 1. SƠ ĐỒ KHỐI KIẾN TRÚC VI MẠCH (MERMAID ARCHITECTURE DIAGRAM)

```mermaid
graph TB
    subgraph SOC_ENVIRONMENT["SoC Infrastructure"]
        CPU["Secure CPU / TrustZone Master"]
        MATRIX["AXI4 Multi-Layer Interconnect Matrix"]
        MEM["System Memory / Peripherals"]
        MATRIX <--> MEM
    end

    subgraph DMA_CORE_IP["DMA Controller Core (dma_controller.v)"]
        APB_SLV["APB Config Slave<br/>(dma_apb_slave.v)"]
        CTX_EMIT["Sideband Context Emitter<br/>(dma_controller.v)"]
        FIFO["Synchronous FIFO Buffer<br/>(32 Words x 32-bit)<br/>(dma_fifo_latch.v)"]
        AXI_RD["AXI4 Read Master FSM<br/>(dma_axi_master.v)"]
        AXI_WR["AXI4 Write Master FSM<br/>(dma_axi_master.v)"]
        ABORT_COORD["Terminal / Abort Coordinator<br/>(planned in dma_axi_master.v)<br/>- Block new AR/AW<br/>- Drain committed bursts<br/>- Flush FIFO and pulse done/error"]
        
        APB_SLV -->|src_addr, dst_addr, len, start| AXI_RD
        APB_SLV -->|src_addr, dst_addr, len, start| AXI_WR
        APB_SLV -->|descriptor context| CTX_EMIT
        AXI_RD -->|read state / error| ABORT_COORD
        AXI_WR -->|write state / error| ABORT_COORD
        ABORT_COORD -->|terminal success/error| CTX_EMIT
        AXI_RD -->|push / wdata| FIFO
        FIFO -->|pop / rdata| AXI_WR
    end

    subgraph FIREWALL_IP["DMA-Aware Bus Firewall IP (RTL INTEGRATED / FRONTEND VERIFIED)"]
        APB_REGS["APB4 MMIO & Sticky Lock<br/>(fw_apb_regs.v)<br/>- FW_LOCK RW1S<br/>- FAULT_COUNT [31:16]<br/>- 8x Region Descriptors"]
        
        CTX_TRK["Dynamic Context Tracker<br/>(fw_context_tracker.v)<br/>- Region 4: Read-Only<br/>- Region 5: Write-Only<br/>- Synchronous Revocation after done"]
        
        STAGE1["Stage 1: Addr Pipeline Slice<br/>(production: ../../../rtl/fw_axi_address_slice.v)<br/>- Extended Address Adder<br/>- INCR / 4KB Boundary Detector"]
        
        STAGE2["Stage 2: Parallel ACL Matcher<br/>(fw_acl_matcher.v)<br/>- 8x 32-bit Full-Address Comparators<br/>- Most-Restrictive AND-Logic<br/>- Whitelist Master ID & Mask"]
        
        CUT_MUX["Combinational Cut-Through Mux<br/>(planned: fw_data_path_mux.v)<br/>- No added register stage"]
        
        DRAIN_FSM["Protocol Drain Engine<br/>(planned: fw_drain_fsm.v)<br/>- Write Sink / Read Dummy Generator<br/>- Completion under AXI progress assumptions<br/>- DECERR / Honeypot OKAY"]
        
        APB_REGS -->|Static Region Config| STAGE2
        CTX_TRK -->|Dynamic Region 4 & 5| STAGE2
        STAGE1 -->|Latched Addr & End Addr| STAGE2
        STAGE2 -->|Pass: Allow Master Request| MATRIX
        STAGE2 -->|Denied request snapshot: ID/LEN/ERR mode| DRAIN_FSM
        STAGE2 -->|Independent read/write fault records| APB_REGS
        CTX_TRK -->|Context fault record| APB_REGS
        CUT_MUX <-->|Clean Traffic Bypass| MATRIX
        DRAIN_FSM <-->|Malicious Traffic Sink| CUT_MUX
    end

    %% External Interface Connections
    CPU -->|APB4 Config & Sticky Lock| APB_REGS
    CPU -->|IF_DMA_APB: dma_apb_paddr, dma_apb_psel, dma_apb_penable, dma_apb_pwrite, dma_apb_pwdata, dma_apb_prdata, dma_apb_pready, dma_apb_pslverr| APB_SLV
    
    %% Sideband Interface (Dedicated Point-to-Point)
    CTX_EMIT -.->|dma_ctx_valid, src_addr, dst_addr, byte_len, done| CTX_TRK
    
    %% AXI Slave Interface (DMA -> Firewall)
    AXI_RD ==>|s_axi_ar* (Read Addr)| STAGE1
    AXI_WR ==>|s_axi_aw* (Write Addr)| STAGE1
    AXI_WR ==>|s_axi_w* (Write Data)| CUT_MUX
    CUT_MUX ==>|s_axi_r* (Read Data)| AXI_RD
    CUT_MUX ==>|s_axi_b* (Write Resp)| AXI_WR

    %% AXI Master Interface (Firewall -> Interconnect Matrix)
    STAGE2 ==>|m_axi_ar* / m_axi_aw*| MATRIX
    CUT_MUX <==>|m_axi_w* / m_axi_r* / m_axi_b*| MATRIX

    %% Interrupts
    APB_REGS -->|sec_irq (Security Alert)| CPU
    APB_SLV -->|IF_DMA_IRQ: dma_irq| CPU
```

---

## 2. BẢNG KẾT NỐI VÀ GIAO TIẾP LIÊN MODULE (INTER-MODULE INTERFACE SPECIFICATION)

| Tên Interface / Kênh | Module Nguồn (Source) | Module Đích (Dest) | Độ Rộng Addr / Data | Giao Thức / Chuẩn | Độ Trễ (Latency) | Chức Năng Chi Tiết |
| :--- | :--- | :--- | :---: | :---: | :---: | :--- |
| **`IF_CPU_APB_FW`** | Secure CPU | `fw_apb_regs.v` | 32-bit system address / 32-bit data | APB4 protection profile, full-word only | 1 chu kỳ mục tiêu | Cấu hình 8 vùng phân quyền, kích hoạt `FW_LOCK` (RW1S), đọc `FAULT_INFO` & xóa cờ `W1C`; `PPROT` được kiểm tra cục bộ, `PSTRB` không expose và được coi là `4'b1111`. |
| **`IF_CPU_APB_DMA`** | Secure-Privileged CPU aperture | `dma_apb_slave.v` | 32-bit system address / 32-bit data | APB3 profile, full-word only | 1 chu kỳ mục tiêu | Cấu hình địa chỉ nguồn, địa chỉ đích, byte length và phát `START`; không có `PPROT/PSTRB`, nên Secure-Privileged provenance phải do upstream APB bridge enforce và verify. |
| **`IF_DMA_SIDEBAND`** | `dma_controller.v` | `fw_context_tracker.v` | `valid/src/dst/len/done` | Dedicated Sideband | **1 clock synchronous** | 5 tín hiệu chuyên dụng: valid, src_addr, dst_addr, byte_len, done. Truyền descriptor trực tiếp; Region 4/5 bị vô hiệu hóa sau cạnh clock lấy mẫu `dma_ctx_done` và trước giao dịch mới kế tiếp. |
| **`IF_DMA_AXI_AR`** | `dma_axi_master.v` | `fw_axi_address_slice.v` | 32-bit address, ID_WIDTH=4 | AMBA AXI4 Read Addr | 1 chu kỳ | DMA phát fixed `ARID=0`, `ARPROT=001`; Stage 1 chốt đầy đủ AR payload và chỉ assert READY khi secure pipeline còn slot. |
| **`IF_DMA_AXI_AW`** | `dma_axi_master.v` | `fw_axi_address_slice.v` | 32-bit address, ID_WIDTH=4 | AMBA AXI4 Write Addr | 1 chu kỳ | DMA phát fixed `AWID=0`, `AWPROT=001`; W bị chặn đến sau AW acceptance và ACL decision. |
| **`IF_PIPE_S1_S2`** | `fw_axi_address_slice.v` | `fw_acl_matcher.v` | 32-bit address/end, ID=4 | Decoupled valid/ready pipeline | 1 chu kỳ | Chuyển request descriptor, profile flags và ACL snapshot bất biến; Stage 2 ready truyền backpressure về Stage 1. |
| **`IF_ACL_TO_MATRIX`**| `fw_acl_matcher.v` | AXI4 Interconnect Matrix | 32-bit / - | AMBA AXI4 Master | Không thêm tầng register; timing `TBD` | Chuyển tiếp địa chỉ hợp lệ ra bus liên kết hệ thống khi kiểm tra quyền hạn thành công. |
| **`IF_DATA_CUTTHROUGH`**| `dma_axi_master.v` | AXI4 Interconnect Matrix | - / 32-bit | AMBA AXI4 Data Ch | Không thêm tầng register; timing `TBD` | Truyền dữ liệu $WDATA$ và $RDATA$ qua bypass multiplexer khi giao dịch được cho phép. |
| **`IF_SINK_DRAIN`** | `fw_acl_matcher.v` + `fw_data_path_mux.v` | `fw_drain_fsm.v`, response ngược về DMA | ID=4 / data=32 | Internal request + AXI handshake | Tổ hợp + FSM | Matcher cấp fault request đã chốt (`ID/LEN/ERR_MODE`); mux đưa `WVALID/WLAST/BREADY/RREADY` vào drain và đưa `WREADY/BVALID/BID/BRESP/RVALID/RID/RDATA/RRESP/RLAST` ngược về DMA. |
| **`IF_FAULT_EVENTS`** | Matcher + context tracker | `fw_apb_regs.v` | code=4, addr=32, ID=4 | 3 independent event records/cycle | 0–1 chu kỳ | Read/write/context records được nhận đồng thời; status OR tất cả, counter tăng theo số record, first-fault metadata priority `context > write > read`. |
| **`IF_SEC_ALERT`** | `fw_apb_regs.v` | CPU Interrupt Ctrl | 1-bit | Level-Sensitive Active-High | 0 chu kỳ | Ngắt an ninh cấp hệ thống (Level-Sensitive Active-High). sec_irq = FW_CONTROL[1] (IRQ_EN) && FAULT_STATUS[31] (IRQ_PENDING). Chỉ deassert khi CPU ghi 1 xóa cờ IRQ_PENDING qua W1C hoặc khi tắt IRQ_EN = 0. |
| **`IF_DMA_APB`** | Secure-Privileged CPU aperture | `dma_apb_slave.v` | 32-bit address / 32-bit data | APB3 profile | 1 chu kỳ mục tiêu | `dma_apb_paddr, dma_apb_psel, dma_apb_penable, dma_apb_pwrite, dma_apb_pwdata, dma_apb_prdata, dma_apb_pready, dma_apb_pslverr`; không có `PPROT/PSTRB`, trust filter nằm upstream. |
| **`IF_DMA_IRQ`** | `dma_controller.v` | CPU Interrupt Ctrl | 1-bit | - | 0 chu kỳ | DMA Interrupt Interface: `dma_irq`. |
