`timescale 1ns/1ps

// Generic educational 8-bit accumulator processor.
// This is NOT a reconstruction of the photographed chip.
//
// Instruction format:
//   00             NOP
//   01 LL HH       LDA  [HHLL]
//   02 LL HH       STA  [HHLL]
//   03 LL HH       ADD  [HHLL]
//   04 LL HH       SUB  [HHLL]
//   05 LL HH       AND  [HHLL]
//   06 LL HH       XOR  [HHLL]
//
// Memory timing contract:
//   * Reads are one setup cycle plus one capture cycle.
//   * data_in must be valid while mem_read is asserted.
//   * A write is committed on a rising edge while mem_write is asserted.
module classic_proc_fixed (
    input  wire        clk,
    input  wire        rst_n,

    input  wire [7:0]  data_in,
    output reg  [7:0]  data_out,
    output reg  [15:0] addr_bus,
    output reg         mem_read,
    output reg         mem_write
);

    localparam [7:0] OP_NOP = 8'h00;
    localparam [7:0] OP_LDA = 8'h01;
    localparam [7:0] OP_STA = 8'h02;
    localparam [7:0] OP_ADD = 8'h03;
    localparam [7:0] OP_SUB = 8'h04;
    localparam [7:0] OP_AND = 8'h05;
    localparam [7:0] OP_XOR = 8'h06;

    localparam [3:0] ST_FETCH_SETUP     = 4'd0;
    localparam [3:0] ST_FETCH_CAPTURE   = 4'd1;
    localparam [3:0] ST_DECODE          = 4'd2;
    localparam [3:0] ST_ADDR_LO_SETUP   = 4'd3;
    localparam [3:0] ST_ADDR_LO_CAPTURE = 4'd4;
    localparam [3:0] ST_ADDR_HI_SETUP   = 4'd5;
    localparam [3:0] ST_ADDR_HI_CAPTURE = 4'd6;
    localparam [3:0] ST_MEM_READ_SETUP  = 4'd7;
    localparam [3:0] ST_MEM_READ_CAPTURE= 4'd8;
    localparam [3:0] ST_MEM_WRITE_SETUP = 4'd9;
    localparam [3:0] ST_MEM_WRITE_HOLD  = 4'd10;

    reg [3:0]  state;
    reg [15:0] pc;
    reg [15:0] operand_addr;
    reg [7:0]  acc;
    reg [7:0]  ir;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= ST_FETCH_SETUP;
            pc           <= 16'h0000;
            operand_addr <= 16'h0000;
            acc          <= 8'h00;
            ir           <= OP_NOP;
            data_out     <= 8'h00;
            addr_bus     <= 16'h0000;
            mem_read     <= 1'b0;
            mem_write    <= 1'b0;
        end else begin
            // Bus strobes are pulses. Individual states assert them as needed.
            mem_read  <= 1'b0;
            mem_write <= 1'b0;

            case (state)
                ST_FETCH_SETUP: begin
                    addr_bus <= pc;
                    mem_read <= 1'b1;
                    state    <= ST_FETCH_CAPTURE;
                end

                ST_FETCH_CAPTURE: begin
                    ir    <= data_in;
                    pc    <= pc + 16'd1;
                    state <= ST_DECODE;
                end

                ST_DECODE: begin
                    case (ir)
                        OP_NOP: state <= ST_FETCH_SETUP;
                        OP_LDA,
                        OP_STA,
                        OP_ADD,
                        OP_SUB,
                        OP_AND,
                        OP_XOR: state <= ST_ADDR_LO_SETUP;
                        default: state <= ST_FETCH_SETUP;
                    endcase
                end

                ST_ADDR_LO_SETUP: begin
                    addr_bus <= pc;
                    mem_read <= 1'b1;
                    state    <= ST_ADDR_LO_CAPTURE;
                end

                ST_ADDR_LO_CAPTURE: begin
                    operand_addr[7:0] <= data_in;
                    pc                <= pc + 16'd1;
                    state             <= ST_ADDR_HI_SETUP;
                end

                ST_ADDR_HI_SETUP: begin
                    addr_bus <= pc;
                    mem_read <= 1'b1;
                    state    <= ST_ADDR_HI_CAPTURE;
                end

                ST_ADDR_HI_CAPTURE: begin
                    operand_addr[15:8] <= data_in;
                    pc                 <= pc + 16'd1;
                    if (ir == OP_STA)
                        state <= ST_MEM_WRITE_SETUP;
                    else
                        state <= ST_MEM_READ_SETUP;
                end

                ST_MEM_READ_SETUP: begin
                    // operand_addr is now complete; do not combine this with
                    // ST_ADDR_HI_CAPTURE because nonblocking assignments update
                    // after the active clock edge.
                    addr_bus <= operand_addr;
                    mem_read <= 1'b1;
                    state    <= ST_MEM_READ_CAPTURE;
                end

                ST_MEM_READ_CAPTURE: begin
                    case (ir)
                        OP_LDA: acc <= data_in;
                        OP_ADD: acc <= acc + data_in;
                        OP_SUB: acc <= acc - data_in;
                        OP_AND: acc <= acc & data_in;
                        OP_XOR: acc <= acc ^ data_in;
                        default: acc <= acc;
                    endcase
                    state <= ST_FETCH_SETUP;
                end

                ST_MEM_WRITE_SETUP: begin
                    addr_bus  <= operand_addr;
                    data_out  <= acc;
                    mem_write <= 1'b1;
                    state     <= ST_MEM_WRITE_HOLD;
                end

                ST_MEM_WRITE_HOLD: begin
                    // The external memory observes mem_write=1 at this edge.
                    state <= ST_FETCH_SETUP;
                end

                default: begin
                    // Recover from an illegal/corrupted state.
                    state <= ST_FETCH_SETUP;
                end
            endcase
        end
    end

endmodule
