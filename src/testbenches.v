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

module tb_Execute;

    reg clk;

    // -------- inputs --------
    reg        RegWr_ID;
    reg        MemWr_ID;
    reg        MemRd_ID;
    reg [1:0]  WBdata_ID;
    reg        ALUSrc_ID;
    reg [2:0]  ALUop_ID;

    reg [31:0] npc2;
    reg [31:0] imm;
    reg [31:0] A;
    reg [31:0] B;
    reg [3:0]  rd2;
    reg        RPzero_ID;

    // -------- outputs --------
    wire        RegWr_EX;
    wire        MemWr_EX;
    wire        MemRd_EX;
    wire [1:0]  WBdata_EX;

    wire [31:0] ALUout_EX;
    wire [31:0] D;
    wire [31:0] npc3;
    wire [3:0]  rd3;
    wire        RPzero_EX;

    // -------- DUT --------
    Execute dut (
        .clk(clk),

        .RegWr_ID(RegWr_ID),
        .MemWr_ID(MemWr_ID),
        .MemRd_ID(MemRd_ID),
        .WBdata_ID(WBdata_ID),
        .ALUSrc_ID(ALUSrc_ID),
        .ALUop_ID(ALUop_ID),

        .npc2(npc2),
        .imm(imm),
        .A(A),
        .B(B),
        .rd2(rd2),
        .RPzero_ID(RPzero_ID),

        .RegWr_EX(RegWr_EX),
        .MemWr_EX(MemWr_EX),
        .MemRd_EX(MemRd_EX),
        .WBdata_EX(WBdata_EX),

        .ALUout_EX(ALUout_EX),
        .D(D),
        .npc3(npc3),
        .rd3(rd3),
        .RPzero_EX(RPzero_EX)
    );

    // -------- clock --------
    always #5 clk = ~clk;

    // -------- monitor --------
    initial begin
        $monitor(
            "T=%0t | ALUop=%b | A=%0d B=%0d imm=%0d | ALUSrc=%b | ALUout=%0d | D=%0d | Rd=%0d | RPzero=%b",
            $time, ALUop_ID, A, B, imm, ALUSrc_ID,
            ALUout_EX, D, rd3, RPzero_EX
        );
    end

    // -------- test sequence --------
    initial begin
        clk = 0;

        // default inputs
        RegWr_ID   = 0;
        MemWr_ID   = 0;
        MemRd_ID   = 0;
        WBdata_ID  = 2'b00;
        ALUSrc_ID  = 0;
        ALUop_ID   = 3'b000;

        A = 0;
        B = 0;
        imm = 0;
        npc2 = 0;
        rd2 = 0;
        RPzero_ID = 0;

        // ---------- ADD ----------
        @(posedge clk);
        A = 10;
        B = 5;
        ALUop_ID = 3'b000; // ADD
        rd2 = 4'd3;
        RegWr_ID = 1;

        // ---------- SUB ----------
        @(posedge clk);
        A = 10;
        B = 4;
        ALUop_ID = 3'b001; // SUB
        rd2 = 4'd4;

        // ---------- AND ----------
        @(posedge clk);
        A = 8;
        B = 3;
        ALUop_ID = 3'b100; // AND
        rd2 = 4'd5;

        // ---------- OR ----------
        @(posedge clk);
        A = 8;
        B = 1;
        ALUop_ID = 3'b010; // OR
        rd2 = 4'd6;

        // ---------- NOR ----------
        @(posedge clk);
        A = 8;
        B = 1;
        ALUop_ID = 3'b011; // NOR
        rd2 = 4'd7;

        // ---------- ALUSrc = immediate ----------
        @(posedge clk);
        A = 20;
        imm = 7;
        ALUSrc_ID = 1;
        ALUop_ID = 3'b000; // ADD imm
        rd2 = 4'd8;

        // ---------- store data forwarding ----------
        @(posedge clk);
        B = 99;
        MemWr_ID = 1;

        // ---------- predicate propagation ----------
        @(posedge clk);
        RPzero_ID = 1;

        // finish
        #10;
        $finish;
    end

endmodule

module tb_Hazard_Unit;

    // Inputs
    reg  [4:0] Rs, Rt;
    reg  [4:0] Rd_EX, Rd_MEM, Rd_WB;

    reg        RegWrite_EX;
    reg        RegWrite_MEM;
    reg        RegWrite_WB;

    reg        MemRead_EX;

    reg        RPzero_EX;
    reg        RPzero_MEM;
    reg        RPzero_WB;

    // Outputs
    wire [1:0] ForwardA;
    wire [1:0] ForwardB;
    wire       Stall;

    // DUT
    Hazard_Unit dut (
        .Rs(Rs),
        .Rt(Rt),
        .Rd_EX(Rd_EX),
        .Rd_MEM(Rd_MEM),
        .Rd_WB(Rd_WB),
        .RegWrite_EX(RegWrite_EX),
        .RegWrite_MEM(RegWrite_MEM),
        .RegWrite_WB(RegWrite_WB),
        .MemRead_EX(MemRead_EX),
        .RPzero_EX(RPzero_EX),
        .RPzero_MEM(RPzero_MEM),
        .RPzero_WB(RPzero_WB),
        .ForwardA(ForwardA),
        .ForwardB(ForwardB),
        .Stall(Stall)
    );

    // Task for displaying state
    task show;
        begin
            #1;
            $display(
                "Rs=%0d Rt=%0d | Rd_EX=%0d Rd_MEM=%0d Rd_WB=%0d | FA=%b FB=%b Stall=%b",
                Rs, Rt, Rd_EX, Rd_MEM, Rd_WB, ForwardA, ForwardB, Stall
            );
        end
    endtask

    initial begin
        $display("==== Hazard Unit Testbench ====");

        // Default values
        Rs = 0; Rt = 0;
        Rd_EX = 0; Rd_MEM = 0; Rd_WB = 0;
        RegWrite_EX = 0; RegWrite_MEM = 0; RegWrite_WB = 0;
        MemRead_EX = 0;
        RPzero_EX = 0; RPzero_MEM = 0; RPzero_WB = 0;

        show;

        // ------------------------------
        // EX forwarding (Rs)
        // ------------------------------
        Rs = 5; Rt = 3;
        Rd_EX = 5;
        RegWrite_EX = 1;
        show; // ForwardA = 01

        // ------------------------------
        // MEM forwarding (Rs)
        // ------------------------------
        RegWrite_EX = 0;
        Rd_EX = 0;
        Rd_MEM = 5;
        RegWrite_MEM = 1;
        show; // ForwardA = 10

        // ------------------------------
        // WB forwarding (Rs)
        // ------------------------------
        RegWrite_MEM = 0;
        Rd_MEM = 0;
        Rd_WB = 5;
        RegWrite_WB = 1;
        show; // ForwardA = 11

        // ------------------------------
        // Forwarding on Rt
        // ------------------------------
        Rs = 1; Rt = 7;
        Rd_EX = 7;
        RegWrite_EX = 1;
        show; // ForwardB = 01

        // ------------------------------
        // Killed instruction (no forward)
        // ------------------------------
        RPzero_EX = 1;
        show; // No forwarding

        RPzero_EX = 0;
        RegWrite_EX = 0;

        // ------------------------------
        // Load-use hazard (stall)
        // ------------------------------
        Rs = 4; Rt = 6;
        Rd_EX = 4;
        MemRead_EX = 1;
        RegWrite_EX = 1;
        show; // Stall = 1

        // ------------------------------
        // No stall when Rd_EX = 0
        // ------------------------------
        Rd_EX = 0;
        show; // Stall = 0

        // ------------------------------
        // No stall if instruction killed
        // ------------------------------
        Rd_EX = 6;
        RPzero_EX = 1;
        show; // Stall = 0

        // ------------------------------
        // Cleanup
        // ------------------------------
        MemRead_EX = 0;
        RegWrite_EX = 0;
        RPzero_EX = 0;

        $display("==== Test Complete ====");
        $finish;
    end

endmodule
