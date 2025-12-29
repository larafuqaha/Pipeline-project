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

