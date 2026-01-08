module Processor (
    input  wire clk,
    input  wire rst_async
);

    // -----------------------------
    // Reset sync (glitch-free reset)
    // -----------------------------
    wire rst_sync;
    reset_sync u_rstsync (
        .clk      (clk),
        .rst_async (rst_async),
        .rst_sync  (rst_sync)
    );

    // -----------------------------
    // IF stage wires
    // -----------------------------
    wire        disable_PC, disable_IR;
    wire [1:0]  PCsrc;
    wire        KILL;
    wire [31:0] PC_offset, PC_regRs;

    wire [31:0] Instruction_F, NPC_F;
    wire [31:0] PC;

    IF_stage u_if (
        .clk          (clk),
        .reset        (rst_sync),
        .disable_PC   (disable_PC),
        .disable_IR   (disable_IR),
        .KILL         (KILL),
        .PCsrc        (PCsrc),
        .PC_offset    (PC_offset),
        .PC_regRs     (PC_regRs),
        .Instruction_F(Instruction_F),
        .NPC_F        (NPC_F),
        .PC           (PC)
    );

    // -----------------------------
    // IF/ID pipeline register
    // -----------------------------
    wire [31:0] Instruction_D, NPC_D;

    IF_ID u_ifid (
        .clk          (clk),
        .reset        (rst_sync),
        .disable_IR   (disable_IR),
        .kill         (KILL),
        .Instruction_F(Instruction_F),
        .NPC_F        (NPC_F),
        .Instruction_D(Instruction_D),
        .NPC_D        (NPC_D)
    );

    // -----------------------------
    // WB stage outputs (from MEM/WB)
    // -----------------------------
    wire [4:0]  Rd_WB_final;
    wire [31:0] BusW_WB_final;	
	wire        RegWr_WB_final_raw;
wire [1:0]  WBdata_WB;
wire [31:0] ALUout_WB, MemOut_WB, NPC3_WB;


    // IMPORTANT: declare this BEFORE using it in u_id
    wire RegWr_WB_final;

    // -----------------------------
    // Forwarding buses back to ID
    // -----------------------------
    wire [31:0] Fwd_EX;
    wire [31:0] Fwd_MEM;
    wire [31:0] Fwd_WB;

    // -----------------------------
    // Hazard bookkeeping into ID_stage
    // -----------------------------
    wire [4:0]  Rd_EX_pipe, Rd_MEM_pipe, Rd_WB_pipe;
    wire        RegWrite_EX_pipe, RegWrite_MEM_pipe, RegWrite_WB_pipe;
    wire        MemRead_EX_pipe;
    wire        RPzero_EX_pipe, RPzero_MEM_pipe, RPzero_WB_pipe;

    // -----------------------------
    // ID outputs into ID/EX
    // -----------------------------
    wire        Stall;

    wire        RegWr_IDEX, MemWr_IDEX, MemRd_IDEX;
    wire        ALUSrc_IDEX;
    wire [2:0]  ALUop_IDEX;
    wire [1:0]  WBdata_IDEX;

    wire [31:0] A_IDEX, B_IDEX, IMM_IDEX, NPC2_IDEX;
    wire [4:0]  Rd2_IDEX;
    wire        RPzero_IDEX;

    // tie-offs (avoid warnings)
    wire RegWr_final_ID_unused, MemWr_final_ID_unused, MemRd_final_ID_unused;

    // -----------------------------
    // ID stage
    // -----------------------------
    ID_stage u_id (
        .clk            (clk),

        .Instruction_D  (Instruction_D),
        .NPC_D          (NPC_D),

        .RegWr_WB_final (RegWr_WB_final),
        .Rd_WB          (Rd_WB_final),
        .BusW_WB        (BusW_WB_final),

        .Fwd_EX         (Fwd_EX),
        .Fwd_MEM        (Fwd_MEM),
        .Fwd_WB         (Fwd_WB),

        .Rd_EX          (Rd_EX_pipe),
        .Rd_MEM         (Rd_MEM_pipe),
        .Rd_WB_pipe     (Rd_WB_pipe),

        .RegWrite_EX    (RegWrite_EX_pipe),
        .RegWrite_MEM   (RegWrite_MEM_pipe),
        .RegWrite_WB    (RegWrite_WB_pipe),

        .MemRead_EX     (MemRead_EX_pipe),

        .RPzero_EX      (RPzero_EX_pipe),
        .RPzero_MEM     (RPzero_MEM_pipe),
        .RPzero_WB      (RPzero_WB_pipe),

        .PCsrc          (PCsrc),
        .KILL           (KILL),
        .PC_offset      (PC_offset),
        .PC_regRs       (PC_regRs),

        .Stall          (Stall),
        .disable_PC     (disable_PC),
        .disable_IR     (disable_IR),

        .RegWr_final    (RegWr_final_ID_unused),
        .MemWr_final    (MemWr_final_ID_unused),
        .MemRd_final    (MemRd_final_ID_unused),

        .RegWr_IDEX     (RegWr_IDEX),
        .MemWr_IDEX     (MemWr_IDEX),
        .MemRd_IDEX     (MemRd_IDEX),

        .ALUSrc_IDEX    (ALUSrc_IDEX),
        .ALUop_IDEX     (ALUop_IDEX),
        .WBdata_IDEX    (WBdata_IDEX),

        .A_IDEX         (A_IDEX),
        .B_IDEX         (B_IDEX),
        .IMM_IDEX       (IMM_IDEX),
        .NPC2_IDEX      (NPC2_IDEX),
        .Rd2_IDEX       (Rd2_IDEX),
        .RPzero_IDEX    (RPzero_IDEX)
    );

    // -----------------------------
    // ID/EX pipeline register
    // -----------------------------
    wire        RegWr_EX, MemWr_EX, MemRd_EX;
    wire        ALUSrc_EX;
    wire [2:0]  ALUop_EX;
    wire [1:0]  WBdata_EX;

    wire [31:0] A_EX, B_EX, Imm_EX, NPC_EX;
    wire [4:0]  Rd_EX;

    ID_EX u_idex (
        .clk       (clk),
        .reset     (rst_sync),	  
   		 .stall     (Stall),    

        .RegWr_ID  (RegWr_IDEX),
        .MemWr_ID  (MemWr_IDEX),
        .MemRd_ID  (MemRd_IDEX),
        .ALUSrc_ID (ALUSrc_IDEX),
        .ALUop_ID  (ALUop_IDEX),
        .WBdata_ID (WBdata_IDEX),

        .A_ID      (A_IDEX),
        .B_ID      (B_IDEX),
        .Imm_ID    (IMM_IDEX),
        .NPC_ID    (NPC2_IDEX),
        .Rd_ID     (Rd2_IDEX),

        .RegWr_EX  (RegWr_EX),
        .MemWr_EX  (MemWr_EX),
        .MemRd_EX  (MemRd_EX),
        .ALUSrc_EX (ALUSrc_EX),
        .ALUop_EX  (ALUop_EX),
        .WBdata_EX (WBdata_EX),

        .A_EX      (A_EX),
        .B_EX      (B_EX),
        .Imm_EX    (Imm_EX),
        .NPC_EX    (NPC_EX),
        .Rd_EX     (Rd_EX)
    );

    // pipeline RPzero into EX
    reg RPzero_EX_reg;
    always @(posedge clk or posedge rst_sync) begin
        if (rst_sync) RPzero_EX_reg <= 1'b0;
        else          RPzero_EX_reg <= RPzero_IDEX;
    end

    // -----------------------------
    // Execute stage
    // -----------------------------
    wire        RegWr_EXM, MemWr_EXM, MemRd_EXM;
    wire [1:0]  WBdata_EXM;
    wire [31:0] ALUout_EXM, D_EXM, NPC3_EXM;
    wire [4:0]  rd3_EXM;
    wire        RPzero_EXM;

    wire [31:0] B_EX_store_safe = (RPzero_EX_reg) ? 32'b0 : B_EX;

    Execute u_ex (
        .clk        (clk),

        .RegWr_ID   (RegWr_EX),
        .MemWr_ID   (MemWr_EX),
        .MemRd_ID   (MemRd_EX),
        .WBdata_ID  (WBdata_EX),

        .ALUSrc_ID  (ALUSrc_EX),
        .ALUop_ID   (ALUop_EX),

        .npc2       (NPC_EX),
        .imm        (Imm_EX),
        .A          (A_EX),
        .B          (B_EX_store_safe),
        .rd2        (Rd_EX),
        .RPzero_ID  (RPzero_EX_reg),

        .RegWr_EX   (RegWr_EXM),
        .MemWr_EX   (MemWr_EXM),
        .MemRd_EX   (MemRd_EXM),
        .WBdata_EX  (WBdata_EXM),

        .ALUout_EX  (ALUout_EXM),
        .D          (D_EXM),
        .npc3       (NPC3_EXM),
        .rd3        (rd3_EXM),
        .RPzero_EX  (RPzero_EXM)
    );

    // -----------------------------
	// MEM stage ? MEM/WB inputs
	// -----------------------------
	wire        RegWrite_MEM;
	wire [4:0]  Rd_MEM;
	wire [1:0]  WBdata_MEM;
	wire [31:0] ALUout_MEM;
	wire [31:0] MemOut_MEM;
	wire [31:0] NPC3_MEM;


    mem_stage u_mem (
    .clk         (clk),
    .reset       (rst_sync),

    .RegWrite_EX (RegWr_EXM),
    .memW        (MemWr_EXM),
    .memR        (MemRd_EXM),
    .WBdata_EX   (WBdata_EXM),

    .D           (D_EXM),
    .ALUout_EX   (ALUout_EXM),
    .NPC3_EX     (NPC3_EXM),
    .rd3_EX      (rd3_EXM),

    .RegWrite_MEM(RegWrite_MEM),
    .Rd_MEM      (Rd_MEM),
    .WBdata_MEM  (WBdata_MEM),
    .ALUout_MEM  (ALUout_MEM),
    .MemOut_MEM  (MemOut_MEM),
    .NPC3_MEM    (NPC3_MEM)
	);


    // pipeline RPzero into MEM
    reg RPzero_MEM_reg;
    always @(posedge clk or posedge rst_sync) begin
        if (rst_sync) RPzero_MEM_reg <= 1'b0;
        else          RPzero_MEM_reg <= RPzero_EXM;
    end

    // -----------------------------
    // MEM/WB pipeline register
    // -----------------------------  

  MEM_WB u_memwb (
  .clk         (clk),
  .reset       (rst_sync),

  .RegWrite_MEM(RegWrite_MEM),
  .Rd_MEM      (Rd_MEM),
  .WBdata_MEM  (WBdata_MEM),
  .ALUout_MEM  (ALUout_MEM),
  .MemOut_MEM  (MemOut_MEM),
  .NPC3_MEM    (NPC3_MEM),

  .RegWr_final (RegWr_WB_final_raw),
  .Rd_final    (Rd_WB_final),
  .WBdata_final(WBdata_WB),
  .ALUout_final(ALUout_WB),
  .MemOut_final(MemOut_WB),
  .NPC3_final  (NPC3_WB)
);

WriteBack u_wb (
  .ALUout    (ALUout_WB),
  .MemOut    (MemOut_WB),
  .NPC3      (NPC3_WB),
  .WBdata    (WBdata_WB),
  .writeData (BusW_WB_final)
);



    // pipeline RPzero into WB
    reg RPzero_WB_reg;
    always @(posedge clk or posedge rst_sync) begin
        if (rst_sync) RPzero_WB_reg <= 1'b0;
        else          RPzero_WB_reg <= RPzero_MEM_reg;
    end

    // -----------------------------
    // WB gating
    // -----------------------------
    assign RegWr_WB_final =
        RegWr_WB_final_raw &&
        !RPzero_WB_reg &&
        (Rd_WB_final != 5'd0) &&
		(Rd_WB_final != 5'd30);

    // -----------------------------
    // Bookkeeping back to ID_stage
    // -----------------------------
    assign Rd_EX_pipe        = rd3_EXM;
    assign Rd_MEM_pipe = Rd_MEM;
    assign Rd_WB_pipe        = Rd_WB_final;

    assign RegWrite_EX_pipe  = RegWr_EXM;
    assign RegWrite_MEM_pipe = RegWrite_MEM;
    assign RegWrite_WB_pipe  = RegWr_WB_final;

    assign MemRead_EX_pipe   = MemRd_EXM;

    assign RPzero_EX_pipe    = RPzero_EXM;
    assign RPzero_MEM_pipe   = RPzero_MEM_reg;
    assign RPzero_WB_pipe    = RPzero_WB_reg;

    // forwarding buses
    assign Fwd_EX  = ALUout_EXM;
    assign Fwd_MEM =
    (WBdata_MEM == 2'b01) ? MemOut_MEM :   // LW
    (WBdata_MEM == 2'b10) ? NPC3_MEM   :   // CALL if it can be forwarded
                            ALUout_MEM;    // ALU ops default
    assign Fwd_WB  = BusW_WB_final;

endmodule
