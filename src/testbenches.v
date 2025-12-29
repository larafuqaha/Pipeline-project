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
`timescale 1ns/1ps

// ------------------------------------------------------------
// STUB Hazard Unit (replace with your real one if available)
// ------------------------------------------------------------
module Hazard_Unit (
    input  wire [4:0]  Rs,
    input  wire [4:0]  Rt,
    input  wire [4:0]  Rd_EX,
    input  wire [4:0]  Rd_MEM,
    input  wire [4:0]  Rd_WB,
    input  wire        RegWrite_EX,
    input  wire        RegWrite_MEM,
    input  wire        RegWrite_WB,
    input  wire        MemRead_EX,
    input  wire        RPzero_EX,
    input  wire        RPzero_MEM,
    input  wire        RPzero_WB,
    output reg  [1:0]  ForwardA,
    output reg  [1:0]  ForwardB,
    output reg         Stall
);
    always @(*) begin
        // default: no forwarding, no stall
        ForwardA = 2'b00;
        ForwardB = 2'b00;
        Stall    = 1'b0;

        // simple forwarding priority: EX > MEM > WB
        if (RegWrite_EX && !RPzero_EX && (Rd_EX != 0) && (Rd_EX == Rs)) ForwardA = 2'b01;
        else if (RegWrite_MEM && !RPzero_MEM && (Rd_MEM != 0) && (Rd_MEM == Rs)) ForwardA = 2'b10;
        else if (RegWrite_WB && !RPzero_WB && (Rd_WB != 0) && (Rd_WB == Rs)) ForwardA = 2'b11;

        if (RegWrite_EX && !RPzero_EX && (Rd_EX != 0) && (Rd_EX == Rt)) ForwardB = 2'b01;
        else if (RegWrite_MEM && !RPzero_MEM && (Rd_MEM != 0) && (Rd_MEM == Rt)) ForwardB = 2'b10;
        else if (RegWrite_WB && !RPzero_WB && (Rd_WB != 0) && (Rd_WB == Rt)) ForwardB = 2'b11;

        // classic load-use stall (very simplified)
        if (MemRead_EX && (Rd_EX != 0) && ((Rd_EX == Rs) || (Rd_EX == Rt)))
            Stall = 1'b1;
    end
endmodule


module tb_ID_stage;

  // -------------------------
  // DUT inputs
  // -------------------------
  logic        clk;

  logic [31:0] Instruction_D;
  logic [31:0] NPC_D;

  logic        RegWr_WB_final;
  logic [4:0]  Rd_WB;
  logic [31:0] BusW_WB;

  logic [31:0] Fwd_EX, Fwd_MEM, Fwd_WB;

  logic [4:0]  Rd_EX, Rd_MEM, Rd_WB_pipe;
  logic        RegWrite_EX, RegWrite_MEM, RegWrite_WB;
  logic        MemRead_EX;

  logic        RPzero_EX, RPzero_MEM, RPzero_WB;

  // -------------------------
  // DUT outputs
  // -------------------------
  wire [1:0]  PCsrc;
  wire        KILL;
  wire [31:0] PC_offset;
  wire [31:0] PC_regRs;

  wire        Stall;
  wire        disable_PC;
  wire        disable_IR;

  wire        RegWr_final;
  wire        MemWr_final;
  wire        MemRd_final;

  wire        RegWr_IDEX;
  wire        MemWr_IDEX;
  wire        MemRd_IDEX;

  wire        ALUSrc_IDEX;
  wire [2:0]  ALUop_IDEX;
  wire [1:0]  WBdata_IDEX;

  wire [31:0] A_IDEX;
  wire [31:0] B_IDEX;
  wire [31:0] IMM_IDEX;
  wire [31:0] NPC2_IDEX;
  wire [4:0]  Rd2_IDEX;
  wire        RPzero_IDEX;

  // -------------------------
  // Instantiate DUT
  // -------------------------
  ID_stage dut (
    .clk(clk),

    .Instruction_D(Instruction_D),
    .NPC_D(NPC_D),

    .RegWr_WB_final(RegWr_WB_final),
    .Rd_WB(Rd_WB),
    .BusW_WB(BusW_WB),

    .Fwd_EX(Fwd_EX),
    .Fwd_MEM(Fwd_MEM),
    .Fwd_WB(Fwd_WB),

    .Rd_EX(Rd_EX),
    .Rd_MEM(Rd_MEM),
    .Rd_WB_pipe(Rd_WB_pipe),

    .RegWrite_EX(RegWrite_EX),
    .RegWrite_MEM(RegWrite_MEM),
    .RegWrite_WB(RegWrite_WB),

    .MemRead_EX(MemRead_EX),

    .RPzero_EX(RPzero_EX),
    .RPzero_MEM(RPzero_MEM),
    .RPzero_WB(RPzero_WB),

    .PCsrc(PCsrc),
    .KILL(KILL),
    .PC_offset(PC_offset),
    .PC_regRs(PC_regRs),

    .Stall(Stall),
    .disable_PC(disable_PC),
    .disable_IR(disable_IR),

    .RegWr_final(RegWr_final),
    .MemWr_final(MemWr_final),
    .MemRd_final(MemRd_final),

    .RegWr_IDEX(RegWr_IDEX),
    .MemWr_IDEX(MemWr_IDEX),
    .MemRd_IDEX(MemRd_IDEX),

    .ALUSrc_IDEX(ALUSrc_IDEX),
    .ALUop_IDEX(ALUop_IDEX),
    .WBdata_IDEX(WBdata_IDEX),

    .A_IDEX(A_IDEX),
    .B_IDEX(B_IDEX),
    .IMM_IDEX(IMM_IDEX),
    .NPC2_IDEX(NPC2_IDEX),
    .Rd2_IDEX(Rd2_IDEX),
    .RPzero_IDEX(RPzero_IDEX)
  );

  // -------------------------
  // Clock
  // -------------------------
  initial clk = 1'b0;
  always #5 clk = ~clk;

  // -------------------------
  // Helpers
  // -------------------------
  function automatic [31:0] mk_instr(
      input [4:0] op,
      input [4:0] rp,
      input [4:0] rd,
      input [4:0] rs,
      input [4:0] rt,
      input [21:0] imm22
  );
    mk_instr = {op, rp, rd, rs, rt, imm22[6:0]}; // note: imm22 overlaps fields in your design;
                                               // for ALU/LD/ST we care about imm[11:0] in [11:0] anyway
  endfunction

  // Better: build exactly by bit positions used in ID_stage
  function automatic [31:0] enc(
      input [4:0] op,
      input [4:0] rp,
      input [4:0] rd,
      input [4:0] rs,
      input [4:0] rt,
      input [21:0] imm
  );
    enc = 32'b0;
    enc[31:27] = op;
    enc[26:22] = rp;
    enc[21:17] = rd;
    enc[16:12] = rs;
    enc[11:7]  = rt;
    enc[21:0]  = imm; // yes, this overwrites rd/rs/rt bits, matching your current encoding usage
  endfunction

  task automatic apply_and_check_controls(
      input string name,
      input [4:0] op,
      input [4:0] rp,
      input [4:0] rd,
      input [4:0] rs,
      input [4:0] rt,
      input [21:0] imm,
      input bit exp_regwr_final,
      input bit exp_memwr_final,
      input bit exp_memrd_final,
      input bit exp_alusrc_idex,
      input [2:0] exp_aluop_idex,
      input [1:0] exp_wbdata_idex,
      input [4:0] exp_rd2_idex
  );
    begin
      Instruction_D = enc(op,rp,rd,rs,rt,imm);
      #1; // settle comb

      // "final" signals are pre-bubble (predication gated)
      assert(RegWr_final === exp_regwr_final)
        else $fatal("[%s] RegWr_final exp=%0b got=%0b", name, exp_regwr_final, RegWr_final);
      assert(MemWr_final === exp_memwr_final)
        else $fatal("[%s] MemWr_final exp=%0b got=%0b", name, exp_memwr_final, MemWr_final);
      assert(MemRd_final === exp_memrd_final)
        else $fatal("[%s] MemRd_final exp=%0b got=%0b", name, exp_memrd_final, MemRd_final);

      // IDEX controls may bubble if Stall=1
      if (!Stall) begin
        assert(ALUSrc_IDEX === exp_alusrc_idex)
          else $fatal("[%s] ALUSrc_IDEX exp=%0b got=%0b", name, exp_alusrc_idex, ALUSrc_IDEX);
        assert(ALUop_IDEX === exp_aluop_idex)
          else $fatal("[%s] ALUop_IDEX exp=%0b got=%0b", name, exp_aluop_idex, ALUop_IDEX);
        assert(WBdata_IDEX === exp_wbdata_idex)
          else $fatal("[%s] WBdata_IDEX exp=%0b got=%0b", name, exp_wbdata_idex, WBdata_IDEX);
        assert(Rd2_IDEX === exp_rd2_idex)
          else $fatal("[%s] Rd2_IDEX exp=%0d got=%0d", name, exp_rd2_idex, Rd2_IDEX);
      end
      else begin
        assert(RegWr_IDEX==0 && MemWr_IDEX==0 && MemRd_IDEX==0)
          else $fatal("[%s] Bubble expected IDEX writes=0", name);
      end

      $display("PASS: %s", name);
    end
  endtask

  // -------------------------
  // Init / tests
  // -------------------------
  initial begin
    // defaults
    Instruction_D   = 32'd0;
    NPC_D           = 32'h1000;

    RegWr_WB_final  = 1'b0;
    Rd_WB           = 5'd0;
    BusW_WB         = 32'd0;

    Fwd_EX  = 32'hAAAA_AAAA;
    Fwd_MEM = 32'hBBBB_BBBB;
    Fwd_WB  = 32'hCCCC_CCCC;

    Rd_EX = 0; Rd_MEM = 0; Rd_WB_pipe = 0;
    RegWrite_EX = 0; RegWrite_MEM = 0; RegWrite_WB = 0;
    MemRead_EX  = 0;

    RPzero_EX = 0; RPzero_MEM = 0; RPzero_WB = 0;

    // let regfile init happen
    repeat (2) @(posedge clk);

    // ------------------------------------------------------------
    // 1) R-type ADD opcode=0, predicate passes (Rp=0 -> exec_en=1)
    // Rd2 should select Rt (RBSrc=0, RegDst=0)
    // ------------------------------------------------------------
    apply_and_check_controls(
      "R-ADD (op0) pred true",
      5'd0, 5'd0, 5'd9, 5'd1, 5'd2, 22'd0,
      1'b1, 1'b0, 1'b0,
      1'b0, 3'b000, 2'b00,
      5'd2
    );

    // ------------------------------------------------------------
    // 2) I-type ANDI opcode=8, zero-ext, ALUSrc=1
    // ------------------------------------------------------------
    apply_and_check_controls(
      "ANDI (op8) pred true",
      5'd8, 5'd0, 5'd9, 5'd1, 5'd3, 22'h0000F, // imm[11:0]=0x00F
      1'b1, 1'b0, 1'b0,
      1'b1, 3'b100, 2'b00,
      5'd3
    );
    // check zero-extend (ExtOp=0) => IMM has upper 20 bits 0
    #1;
    assert(IMM_IDEX[31:12] == 20'h0) else $fatal("ANDI expected zero-extend, got IMM=%h", IMM_IDEX);

    // ------------------------------------------------------------
    // 3) ADDI opcode=5, sign-ext
    // imm = 0x800 (negative in 12-bit) => sign extends to 0xFFFFF800
    // ------------------------------------------------------------
    apply_and_check_controls(
      "ADDI (op5) pred true signext",
      5'd5, 5'd0, 5'd9, 5'd1, 5'd4, 22'h00800,
      1'b1, 1'b0, 1'b0,
      1'b1, 3'b000, 2'b00,
      5'd4
    );
    #1;
    assert(IMM_IDEX == 32'hFFFFF800) else $fatal("ADDI signext expected FFFFF800 got %h", IMM_IDEX);

    // ------------------------------------------------------------
    // 4) LW opcode=9 => RegWr=1, MemRd=1, WBdata=01, ALUSrc=1 signext
    // ------------------------------------------------------------
    apply_and_check_controls(
      "LW (op9) pred true",
      5'd9, 5'd0, 5'd0, 5'd1, 5'd5, 22'h00010,
      1'b1, 1'b0, 1'b1,
      1'b1, 3'b000, 2'b01,
      5'd5
    );

    // ------------------------------------------------------------
    // 5) SW opcode=10 => MemWr=1, ALUSrc=1 signext, RBSrc=1 so dest = Rd
    // (RegWr=0, MemRd=0)
    // ------------------------------------------------------------
    apply_and_check_controls(
      "SW (op10) pred true, dest=Rd",
      5'd10, 5'd0, 5'd7, 5'd1, 5'd6, 22'h00020,
      1'b0, 1'b1, 1'b0,
      1'b1, 3'b000, 2'b00,
      5'd7
    );

    // ------------------------------------------------------------
    // 6) CALL opcode=12 => RegWr=1, RegDst=R31, WBdata=PC+1 (2'b10)
    // Extender: 22-bit sign-ext always (even though not used in controls)
    // PC control: when predicate passes => PCsrc=01, KILL=1
    // ------------------------------------------------------------
    apply_and_check_controls(
      "CALL (op12) pred true",
      5'd12, 5'd0, 5'd0, 5'd1, 5'd2, 22'h200000, // imm[21]=1 => negative
      1'b1, 1'b0, 1'b0,
      1'b0, 3'b000, 2'b10,
      5'd31
    );
    #1;
    assert(PCsrc == 2'b01 && KILL == 1'b1)
      else $fatal("CALL expected PCsrc=01 KILL=1, got PCsrc=%b KILL=%b", PCsrc, KILL);
    assert(IMM_IDEX[31:22] == 10'h3FF) // sign extended ones
      else $fatal("CALL expected 22-bit signext, got IMM=%h", IMM_IDEX);

    // ------------------------------------------------------------
    // 7) Predication false case:
    // Pick Rp=4. Your RF init sets registers[4]=0, so Rpzero=1.
    // That makes exec_en=0 => RegWr_final/Mem*final forced 0.
    // Also PC_control does NOTHING when Rpzero=1 (predicate fails)
    // ------------------------------------------------------------
    apply_and_check_controls(
      "LW (op9) pred FALSE via Rp=4 => finals 0",
      5'd9, 5'd4, 5'd0, 5'd1, 5'd5, 22'h00010,
      1'b0, 1'b0, 1'b0,
      1'b1, 3'b000, 2'b01,
      5'd5
    );
    #1;
    assert(PCsrc == 2'b00 && KILL == 1'b0)
      else $fatal("Pred-fail expected PCsrc=00 KILL=0, got PCsrc=%b KILL=%b", PCsrc, KILL);

    // ------------------------------------------------------------
    // 8) Stall bubble injection check:
    // Force a load-use hazard in stub HU: MemRead_EX=1, Rd_EX matches Rs
    // Then Stall=1 => disable_PC/IR=1 and IDEX controls forced to 0
    // ------------------------------------------------------------
    MemRead_EX  = 1'b1;
    Rd_EX       = 5'd1;
    RegWrite_EX = 1'b1;
    RPzero_EX   = 1'b0;

    // Use Rs=1 so hazard triggers stall
    Instruction_D = enc(5'd5, 5'd0, 5'd0, 5'd1, 5'd2, 22'h00001); // ADDI, Rs=1
    #1;

    assert(Stall == 1'b1) else $fatal("Expected Stall=1");
    assert(disable_PC == 1'b1 && disable_IR == 1'b1) else $fatal("Expected disable_PC/IR=1");

    // bubble forces IDEX controls low
    assert(RegWr_IDEX==0 && MemWr_IDEX==0 && MemRd_IDEX==0) else $fatal("Bubble expected IDEX writes=0");
    assert(ALUSrc_IDEX==0 && ALUop_IDEX==3'b000 && WBdata_IDEX==2'b00) else $fatal("Bubble expected NOP controls");

    $display("PASS: Stall bubble injection");

    $display("\nALL TESTS PASSED.\n");
    $finish;
  end

endmodule
`timescale 1ns/1ps

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
// Main & ALU Control Unit (ID stage)
module control_unit (
  input  wire [4:0] opcode,

  // control enables (pre-gating)
  output reg        RegWr_control,
  output reg        MemWr_control,
  output reg        MemRd,

  // datapath selects
  output reg        ALUSrc,
  output reg        ExtOp,      // 1: sign-ext, 0: zero-ext
  output reg        RBSrc,      // 0: Rt, 1: Rd
  output reg        RegDst,     // 0: Rd, 1: R31

  output reg [1:0]  WBdata,    // 0: ALU, 1: MEM, 2: PC+1
  output reg [2:0]  ALUop
);

  always @(*) begin
    // -------------------------
    // defaults = NOP
    // -------------------------
    RegWr_control = 1'b0;
    MemWr_control = 1'b0;
    MemRd         = 1'b0;

    ALUSrc        = 1'b0;
    ExtOp         = 1'b0;   // zero-ext default
    RBSrc         = 1'b0;
    RegDst        = 1'b0;

    WBdata        = 2'b00;   // ALU
    ALUop         = 3'b000;   // ADD

    case (opcode)

      // -------------------------
      // R-type ALU instructions
      // -------------------------
      5'd0: begin // ADD
        RegWr_control = 1'b1;
        ALUop         = 3'b000; // ADD 
      end

      5'd1: begin // SUB
        RegWr_control = 1'b1;
        ALUop         = 3'b001; // SUB
      end

      5'd2: begin // OR
        RegWr_control = 1'b1;
        ALUop         = 3'b010; // OR
      end

      5'd3: begin // NOR
        RegWr_control = 1'b1;
        ALUop         = 3'b011; // NOR
      end

      5'd4: begin // AND
        RegWr_control = 1'b1;
        ALUop         = 3'b100; // AND
      end

      // -------------------------
      // I-type ALU instructions
      // -------------------------
      5'd5: begin // ADDI
        RegWr_control = 1'b1;
        ALUSrc        = 1'b1;
        ExtOp         = 1'b1; // sign-ext
        ALUop         = 3'b000; // ADD
      end

      5'd6: begin // ORI
        RegWr_control = 1'b1;
        ALUSrc        = 1'b1;
        ExtOp         = 1'b0; // zero-ext
        ALUop         = 3'b010; // OR
      end

      5'd7: begin // NORI
        RegWr_control = 1'b1;
        ALUSrc        = 1'b1;
        ExtOp         = 1'b0; // zero-ext
        ALUop         = 3'b011; // NOR
      end

      5'd8: begin // ANDI
        RegWr_control = 1'b1;
        ALUSrc        = 1'b1;
        ExtOp         = 1'b0; // zero-ext
        ALUop         = 3'b100; // AND
      end

      // -------------------------
      // Load / Store
      // -------------------------
      5'd9: begin // LW
        RegWr_control = 1'b1;
        MemRd         = 1'b1;
        ALUSrc        = 1'b1;
        ExtOp         = 1'b1; // sign-ext
        ALUop         = 3'b000; // ADD
        WBdata        = 2'b01; // MEM
      end

      5'd10: begin // SW
        MemWr_control = 1'b1;
        ALUSrc        = 1'b1;
        ExtOp         = 1'b1; // sign-ext
        ALUop         = 3'b000; // ADD
        RBSrc         = 1'b1; // use Rd
      end

      // -------------------------
      // CALL
      // -------------------------
      5'd12: begin // CALL
        RegWr_control = 1'b1;
        RegDst        = 1'b1; // R31
        WBdata        = 2'b10; // PC+1
      end

      default: begin
        // NOP
      end

    endcase
  end

endmodule


module extender ( 
    input  wire [4:0]  opcode,
    input  wire [21:0] imm_in,     // [11:0] for I-type, [21:0] for J-type
    input  wire        ExtOp,      // 1 = sign, 0 = zero (I-type only)
    output reg  [31:0] imm_out
);

    reg extend_bit;

    always @(*) begin
        case (opcode)

            // J, CALL ? 22-bit signed offset (ALWAYS sign-extended)
            5'd11,5'd12: begin
                extend_bit = imm_in[21];
                imm_out = { {10{extend_bit}}, imm_in[21:0] };
            end

            // I-type ? 12-bit immediate
            default: begin
                extend_bit = imm_in[11] & ExtOp;
                imm_out = { {20{extend_bit}}, imm_in[11:0] };
            end

        endcase
    end

endmodule


module pc_control (
    input  wire [4:0] Op,        // opcode
    input  wire       Rpzero,     // =1 if Reg[Rp] == 0
    output reg  [1:0] PCsrc,      // PC source select
    output reg        KILL        // kill next instruction
);

    // opcode parameters
    localparam OP_J    = 5'd11;
    localparam OP_CALL = 5'd12;
    localparam OP_JR   = 5'd13;

    always @(*) begin
        // defaults
        PCsrc = 2'b00; // PC + 1
        KILL  = 1'b0;

        // instruction executes only if predicate is true
        if (!Rpzero) begin
            case (Op)
                OP_J,
                OP_CALL: begin
                    PCsrc = 2'b01; // PC + offset
                    KILL  = 1'b1;  // squash wrong-path instruction
                end

                OP_JR: begin
                    PCsrc = 2'b10; // Reg[Rs]
                    KILL  = 1'b1;
                end

                default: begin
                    PCsrc = 2'b00;
                    KILL  = 1'b0;
                end
            endcase
        end
    end

endmodule


module RegisterFile (
    input  wire        clk,
    input  wire        RegWr_final,   // write enable
    input  wire [4:0]  Rd,            // write register number
    input  wire [4:0]  Rs,            // read reg A number
    input  wire [4:0]  Rt,            // read reg B number 
    input  wire [4:0]  Rp,              // read reg P number
    input  wire [31:0] BusW,          // write data
    output wire [31:0] BusA,          // read data A 
    output wire [31:0] BusP,          // read data P
    output wire [31:0] BusB           // read data B
);

    reg [31:0] registers [0:31]; 
    // Register pre-load
        initial begin
            registers[0] = 0;
            registers[1] = 1; 
            registers[2] = 7;
            registers[3] = 6;
            registers[4] = 0;
            registers[5] = 0;
            registers[6] = 3;
            registers[7] = 1;
            registers[8] = 0;
            registers[9] = 0;
            registers[10] = 0;
            registers[11] = 0;
            registers[12] = 0;
            registers[13] = 0;
            registers[14] = 0;	
		   registers[15] = 0;
            registers[16] = 1; 
            registers[17] = 7;
            registers[18] = 6;
            registers[19] = 0;
            registers[20] = 0;
            registers[21] = 3;
            registers[22] = 1;
            registers[23] = 0;
            registers[24] = 0;
            registers[25] = 0;
            registers[26] = 0;
            registers[27] = 0;
            registers[28] = 0;
            registers[29] = 0;
		   registers[30] = 0;
            registers[31] = 0;
        end

    // async reads
    assign BusA = (Rs == 5'd0) ? 32'b0 : registers[Rs];
    assign BusB = (Rt == 5'd0) ? 32'b0 : registers[Rt];
    assign BusP = (Rp == 5'd0) ? 32'b0 : registers[Rp];

    // sync write
    always @(posedge clk) begin
        if (RegWr_final && (Rd != 5'd0) && (Rd != 5'd30))
            registers[Rd] <= BusW;

        registers[0] <= 32'b0; // keep R0 always zero
    end

endmodule



module ID_stage (
    input  wire        clk,
    //input  wire        reset,

    input  wire [31:0] Instruction_D,
    input  wire [31:0] NPC_D,

    input  wire        RegWr_WB_final,
    input  wire [4:0]  Rd_WB,
    input  wire [31:0] BusW_WB,

    input  wire [31:0] Fwd_EX,
    input  wire [31:0] Fwd_MEM,
    input  wire [31:0] Fwd_WB,

    input  wire [4:0]  Rd_EX,
    input  wire [4:0]  Rd_MEM,
    input  wire [4:0]  Rd_WB_pipe,

    input  wire        RegWrite_EX,
    input  wire        RegWrite_MEM,
    input  wire        RegWrite_WB,

    input  wire        MemRead_EX,

    input  wire        RPzero_EX,
    input  wire        RPzero_MEM,
    input  wire        RPzero_WB,

    // -----------------------------
    // Outputs back to IF stage control
    // -----------------------------
    output wire [1:0]  PCsrc,
    output wire        KILL,
    output wire [31:0] PC_offset,
    output wire [31:0] PC_regRs,

    // Stall controls for IF + IF/ID
    output wire        Stall,
    output wire        disable_PC,
    output wire        disable_IR,

    // -----------------------------
    // *** THESE ARE THE SIGNALS YOU ASKED FOR ***
    // Generated in ID (after predication) and then pipelined forward
    // -----------------------------
    output wire        RegWr_final,   // RegWr_control & ~RPzero
    output wire        MemWr_final,   // MemWr_control & ~RPzero
    output wire        MemRd_final,   // MemRd_control & ~RPzero (recommended)

    // -----------------------------
    // Outputs into ID/EX register
    // -----------------------------
    output wire        RegWr_IDEX,
    output wire        MemWr_IDEX,
    output wire        MemRd_IDEX,

    output wire        ALUSrc_IDEX,
    output wire [2:0]  ALUop_IDEX,
    output wire [1:0]  WBdata_IDEX,

    output wire [31:0] A_IDEX,
    output wire [31:0] B_IDEX,
    output wire [31:0] IMM_IDEX,
    output wire [31:0] NPC2_IDEX,
    output wire [4:0]  Rd2_IDEX,
    output wire        RPzero_IDEX
);

    // -------- fields --------
    wire [4:0] opcode = Instruction_D[31:27];
    wire [4:0] Rp     = Instruction_D[26:22];
    wire [4:0] Rd     = Instruction_D[21:17];
    wire [4:0] Rs     = Instruction_D[16:12];
    wire [4:0] Rt     = Instruction_D[11:7];
    wire [21:0] imm22 = Instruction_D[21:0];

    // -------- main control (pre-gating) --------
    wire        RegWr_control, MemWr_control, MemRd_control;
    wire        ALUSrc_control, ExtOp_control, RBSrc_control, RegDst_control;
    wire [1:0]  WBdata_control;
    wire [2:0]  ALUop_control;

    control_unit CU (
        .opcode(opcode),
        .RegWr_control(RegWr_control),
        .MemWr_control(MemWr_control),
        .MemRd(MemRd_control),
        .ALUSrc(ALUSrc_control),
        .ExtOp(ExtOp_control),
        .RBSrc(RBSrc_control),
        .RegDst(RegDst_control),
        .WBdata(WBdata_control),
        .ALUop(ALUop_control)
    );

    // -------- regfile read + Rp comparator --------
    wire [31:0] BusA_raw, BusB_raw, BusP_raw;

    RegisterFile RF (
        .clk(clk),
        .RegWr_final(RegWr_WB_final),
        .Rd(Rd_WB),
        .Rs(Rs),
        .Rt(Rt),
        .Rp(Rp),
        .BusW(BusW_WB),
        .BusA(BusA_raw),
        .BusP(BusP_raw),
        .BusB(BusB_raw)
    );

    wire Rpzero;
	// Rp == R0  ? unconditional execution ? NOT zero
    // Rp != R0  ? zero only if BusP == 0
	assign Rpzero = (Rp != 5'd0) && (BusP_raw == 32'b0); 
    assign RPzero_IDEX = Rpzero;

    assign PC_regRs = BusA_raw;

    // -------- extender --------
    wire [31:0] imm_ext;
    extender EXT (
        .opcode(opcode),
        .imm_in(imm22),
        .ExtOp(ExtOp_control),
        .imm_out(imm_ext)
    );

    // -------- PC + offset (use NPC-1 as PC base) --------
    wire [31:0] PC_base = NPC_D - 32'd1;
    assign PC_offset    = PC_base + imm_ext;
    assign NPC2_IDEX    = PC_offset;   // your NPC2 path

    // -------- PC control --------
    pc_control PCC (
        .Op(opcode),
        .Rpzero(Rpzero),
        .PCsrc(PCsrc),
        .KILL(KILL)
    );

    // -------- hazard unit --------
    wire [1:0] ForwardA, ForwardB;

    Hazard_Unit HU (
        .Rs(Rs),
        .Rt(Rt),
        .Rd_EX(Rd_EX),
        .Rd_MEM(Rd_MEM),
        .Rd_WB(Rd_WB_pipe),
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

    assign disable_PC = Stall;
    assign disable_IR = Stall;

    // -------- forwarding muxes --------
    reg [31:0] A_fwd, B_fwd;

    always @(*) begin
        case (ForwardA)
            2'b00: A_fwd = BusA_raw;
            2'b01: A_fwd = Fwd_EX;
            2'b10: A_fwd = Fwd_MEM;
            2'b11: A_fwd = Fwd_WB;
        endcase
    end

    always @(*) begin
        case (ForwardB)
            2'b00: B_fwd = BusB_raw;
            2'b01: B_fwd = Fwd_EX;
            2'b10: B_fwd = Fwd_MEM;
            2'b11: B_fwd = Fwd_WB;
        endcase
    end

    assign A_IDEX   = A_fwd;
    assign B_IDEX   = B_fwd;
    assign IMM_IDEX = imm_ext;

    // -------- dest reg selection --------
    wire [4:0] RB_sel  = (RBSrc_control) ? Rd : Rt;
    wire [4:0] Rd2_sel = (RegDst_control) ? 5'd31 : RB_sel;
    assign Rd2_IDEX = Rd2_sel;

    // -------- predication gating (THESE ARE THE "final" signals) --------
    wire exec_en = ~Rpzero;

    assign RegWr_final = RegWr_control & exec_en;
    assign MemWr_final = MemWr_control & exec_en;
    assign MemRd_final = MemRd_control & exec_en;

    // -------- bubble injection on Stall --------
    wire bubble = Stall;

    assign RegWr_IDEX  = bubble ? 1'b0 : RegWr_final;
    assign MemWr_IDEX  = bubble ? 1'b0 : MemWr_final;
    assign MemRd_IDEX  = bubble ? 1'b0 : MemRd_final;

    assign ALUSrc_IDEX = bubble ? 1'b0    : ALUSrc_control;
    assign ALUop_IDEX  = bubble ? 3'b000  : ALUop_control;
    assign WBdata_IDEX = bubble ? 2'b00   : WBdata_control;

endmodule
