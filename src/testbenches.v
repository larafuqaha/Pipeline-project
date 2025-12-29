// test bench for if stage
`timescale 1ns/1ps

module tb_IF_stage;

    reg clk;
    reg reset;

    reg disable_PC;
    reg disable_IR;
    reg KILL;
    reg [1:0] PCsrc;

    reg [31:0] PC_offset;
    reg [31:0] PC_regRs;

    wire [31:0] Instruction_F;
    wire [31:0] NPC_F;
    wire [31:0] PC;

    IF_stage dut (
        .clk(clk),
        .reset(reset),
        .disable_PC(disable_PC),
        .disable_IR(disable_IR),
        .KILL(KILL),
        .PCsrc(PCsrc),
        .PC_offset(PC_offset),
        .PC_regRs(PC_regRs),
        .Instruction_F(Instruction_F),
        .NPC_F(NPC_F),
        .PC(PC)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        disable_PC = 0;
        disable_IR = 0;
        KILL = 0;
        PCsrc = 2'b00;
        PC_offset = 32'd0;
        PC_regRs  = 32'd0;

        // automatic tracing
        $monitor(
            "T=%0t | PC=%0d | Instr=%h | NPC=%0d | dPC=%b dIR=%b KILL=%b PCsrc=%b",
            $time, PC, Instruction_F, NPC_F,
            disable_PC, disable_IR, KILL, PCsrc
        );

        // reset
        #10;
        reset = 0;

        // normal fetch
        repeat (3) @(posedge clk);

        // PC stall
        disable_PC = 1;
        @(posedge clk);
        disable_PC = 0;

        // IR stall
        disable_IR = 1;
        @(posedge clk);
        disable_IR = 0;

        // kill
        KILL = 1;
        @(posedge clk);
        KILL = 0;

        // jump
        PC_offset = PC + 32'd3;
        PCsrc = 2'b01;
        @(posedge clk);
        PCsrc = 2'b00;

        // JR
        PC_regRs = 32'd10;
        PCsrc = 2'b10;
        @(posedge clk);
        PCsrc = 2'b00;

        #10;
        $finish;
    end

endmodule

// test bench for IF_ID buffer
module tb_IF_ID;

    reg clk;
    reg disable_IR;
    reg kill;

    reg [31:0] Instruction_F;
    reg [31:0] NPC_F;

    wire [31:0] Instruction_D;
    wire [31:0] NPC_D;

    // -----------------------------
    // DUT
    // -----------------------------
    IF_ID dut (
        .clk(clk),
        .disable_IR(disable_IR),
        .kill(kill),
        .Instruction_F(Instruction_F),
        .NPC_F(NPC_F),
        .Instruction_D(Instruction_D),
        .NPC_D(NPC_D)
    );

    // -----------------------------
    // Clock
    // -----------------------------
    always #5 clk = ~clk;

    initial begin
        $display("==== IF_ID TEST START ====");

        clk = 0;
        disable_IR = 0;
        kill = 0;

        Instruction_F = 32'hAAAAAAAA;
        NPC_F         = 32'd1;

        // ---------- Cycle 1: normal latch ----------
        @(posedge clk);
        #1;
        $display("Cycle 1:");
        $display(" Instr_D=%h NPC_D=%0d",
                 Instruction_D, NPC_D);

        // ---------- Cycle 2: change inputs ----------
        Instruction_F = 32'hBBBBBBBB;
        NPC_F         = 32'd2;

        @(posedge clk);
        #1;
        $display("Cycle 2:");
        $display(" Instr_D=%h NPC_D=%0d",
                 Instruction_D, NPC_D);

        // ---------- Cycle 3: IR stall ----------
        disable_IR = 1;
        Instruction_F = 32'hCCCCCCCC;
        NPC_F         = 32'd3;

        @(posedge clk);
        #1;
        $display("Cycle 3 (stall):");
        $display(" Instr_D=%h NPC_D=%0d (should NOT change)",
                 Instruction_D, NPC_D);

        disable_IR = 0;

        // ---------- Cycle 4: kill ----------
        kill = 1;
        Instruction_F = 32'hDDDDDDDD;
        NPC_F         = 32'd4;

        @(posedge clk);
        #1;
        $display("Cycle 4 (kill):");
        $display(" Instr_D=%h NPC_D=%0d (Instr should be NOP)",
                 Instruction_D, NPC_D);

        kill = 0;

        // ---------- Cycle 5: back to normal ----------
        Instruction_F = 32'hEEEEEEEE;
        NPC_F         = 32'd5;

        @(posedge clk);
        #1;
        $display("Cycle 5:");
        $display(" Instr_D=%h NPC_D=%0d",
                 Instruction_D, NPC_D);

        $display("==== IF_ID TEST END ====");
        $finish;
    end

endmodule
