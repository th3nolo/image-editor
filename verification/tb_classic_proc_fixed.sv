`timescale 1ns/1ps

module tb_classic_proc_fixed;
    reg clk = 1'b0;
    reg rst_n = 1'b0;

    wire [7:0] data_in;
    wire [7:0] data_out;
    wire [15:0] addr_bus;
    wire mem_read;
    wire mem_write;

    reg [7:0] memory [0:65535];
    integer i;
    integer cycles;

    assign data_in = mem_read ? memory[addr_bus] : 8'hxx;

    classic_proc_fixed dut (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .data_out(data_out),
        .addr_bus(addr_bus),
        .mem_read(mem_read),
        .mem_write(mem_write)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (rst_n) begin
            if (mem_read && mem_write)
                $fatal(1, "mem_read and mem_write asserted together");

            if (mem_write)
                memory[addr_bus] <= data_out;
        end
    end

    initial begin
        for (i = 0; i < 65536; i = i + 1)
            memory[i] = 8'h00;

        // Program:
        //   LDA [$0100]   ; A = 5
        //   ADD [$0101]   ; A = 12
        //   STA [$0102]   ; memory[$0102] = 12
        //   SUB [$0103]   ; A = 10
        //   AND [$0104]   ; A = 2
        //   XOR [$0105]   ; A = A7
        //   NOP
        memory[16'h0000] = 8'h01;
        memory[16'h0001] = 8'h00;
        memory[16'h0002] = 8'h01;

        memory[16'h0003] = 8'h03;
        memory[16'h0004] = 8'h01;
        memory[16'h0005] = 8'h01;

        memory[16'h0006] = 8'h02;
        memory[16'h0007] = 8'h02;
        memory[16'h0008] = 8'h01;

        memory[16'h0009] = 8'h04;
        memory[16'h000a] = 8'h03;
        memory[16'h000b] = 8'h01;

        memory[16'h000c] = 8'h05;
        memory[16'h000d] = 8'h04;
        memory[16'h000e] = 8'h01;

        memory[16'h000f] = 8'h06;
        memory[16'h0010] = 8'h05;
        memory[16'h0011] = 8'h01;

        memory[16'h0012] = 8'h00;

        memory[16'h0100] = 8'd5;
        memory[16'h0101] = 8'd7;
        memory[16'h0102] = 8'h00;
        memory[16'h0103] = 8'd2;
        memory[16'h0104] = 8'h0f;
        memory[16'h0105] = 8'ha5;

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        cycles = 0;
        while ((memory[16'h0102] !== 8'd12) && (cycles < 200)) begin
            @(posedge clk);
            cycles = cycles + 1;
        end

        if (memory[16'h0102] !== 8'd12)
            $fatal(1, "STA failed: expected memory[0102]=0c, got %02h", memory[16'h0102]);

        // Allow SUB, AND and XOR to complete.
        while ((dut.pc < 16'h0012) && (cycles < 400)) begin
            @(posedge clk);
            cycles = cycles + 1;
        end
        repeat (4) @(posedge clk);
        #1;

        if (dut.acc !== 8'ha7)
            $fatal(1, "ALU sequence failed: expected acc=a7, got %02h", dut.acc);

        if (dut.pc < 16'h0013)
            $fatal(1, "PC did not advance through NOP: pc=%04h", dut.pc);

        $display("PASS cycles=%0d pc=%04h acc=%02h memory[0102]=%02h", cycles, dut.pc, dut.acc, memory[16'h0102]);
        $finish;
    end
endmodule
