module fw_mtd_formal (
    input wire        clk,
    input wire        resetn,
    input wire [1:0]  threat_level,
    input wire        orig_valid,
    input wire        orig_is_write,
    input wire [31:0] orig_addr,
    input wire [7:0]  orig_len,
    input wire [3:0]  orig_id
);

    localparam [31:0] HONEY_POT_BASE = 32'h7F00_0000;
    localparam [31:0] HONEY_POT_MASK = 32'hFFFF_F000;
    localparam [15:0] SCRAMBLER_SEED = 16'h1ACE;

    wire [31:0] morph_addr;
    wire        honey_pot_hit;
    wire        jitter_active;
    wire        force_drain_req;
    wire [15:0] active_key;

    fw_mtd_engine #(
        .HONEY_POT_BASE(HONEY_POT_BASE),
        .HONEY_POT_MASK(HONEY_POT_MASK),
        .SCRAMBLER_SEED(SCRAMBLER_SEED)
    ) dut (
        .clk(clk),
        .resetn(resetn),
        .threat_level(threat_level),
        .telemetry_overrun(1'b0),
        .overrun_mid(4'h0),
        .sink_ready(1'b1),
        .orig_valid(orig_valid),
        .orig_is_write(orig_is_write),
        .orig_addr(orig_addr),
        .orig_len(orig_len),
        .orig_id(orig_id),
        .trans_action(),
        .morph_addr(morph_addr),
        .honey_pot_hit(honey_pot_hit),
        .rate_limit_stall(),
        .jitter_active(jitter_active),
        .force_drain_req(force_drain_req),
        .scrambler_state_out(),
        .active_key(active_key)
    );

    wire [31:0] expected_honey_addr =
        (HONEY_POT_BASE & HONEY_POT_MASK) |
        ((orig_addr & ~HONEY_POT_MASK) ^
         ({20'd0, active_key[9:0], 2'b00} & ~HONEY_POT_MASK));

    // Keep the formal trace in a defined reset-to-active shape.
    reg [1:0] reset_counter = 2'd0;
    always @(posedge clk) begin
        if (reset_counter < 2'd2)
            reset_counter <= reset_counter + 1'b1;
    end

    always @(*) begin
        if (reset_counter < 2'd2) begin
            assume(!resetn);
            assume(threat_level == 2'b00);
        end else begin
            assume(resetn);
        end
    end

    // Previous-cycle references for the registered honey-pot pulse.
    reg        prev_valid;
    reg        prev_orig_valid;
    reg [1:0]  prev_threat_level;
    always @(posedge clk) begin
        if (!resetn) begin
            prev_valid       <= 1'b0;
            prev_orig_valid  <= 1'b0;
            prev_threat_level <= 2'b00;
        end else begin
            if (prev_valid)
                assert(honey_pot_hit ==
                       (prev_orig_valid && (prev_threat_level == 2'b10)));
            prev_valid        <= 1'b1;
            prev_orig_valid   <= orig_valid;
            prev_threat_level <= threat_level;
        end
    end

    always @(posedge clk) begin
        // Direct control invariants.
        assert(force_drain_req == (threat_level == 2'b11));
        assert(!jitter_active || (threat_level == 2'b01));

        // Address morphing contract for all four threat levels:
        // 2'b00 (Safe) & 2'b01 (Probe) & 2'b11 (Breach/Drain) -> orig_addr
        // 2'b10 (Attack/Honey-Pot with sink_ready=1) -> expected_honey_addr
        if (threat_level == 2'b10)
            assert(morph_addr == expected_honey_addr);
        else
            assert(morph_addr == orig_addr);

        if (!resetn)
            assert(active_key == SCRAMBLER_SEED);
    end

endmodule
