//======================================================
// EX / MEM Pipeline Register
//======================================================
module EX_MEM (
    input  wire        clk,

    // -------- Control signals from EX --------
    input  wire        RegWr_EX,
    input  wire        MemWr_EX,
    input  wire        MemRd_EX,
    input  wire [1:0]  WBdata_EX,

    // -------- Data signals from EX --------
    input  wire [31:0] ALUout_EX,
    input  wire [31:0] D_EX,        // store data
    input  wire [31:0] NPC_EX,      // PC+1 (for CALL)
    input  wire [4:0]  Rd_EX,        // destination register

    // -------- Outputs to MEM stage --------
    output reg         RegWr_MEM,
    output reg         MemWr_MEM,
    output reg         MemRd_MEM,
    output reg  [1:0]  WBdata_MEM,

    output reg  [31:0] ALUout_MEM,
    output reg  [31:0] D_MEM,
    output reg  [31:0] NPC_MEM,
    output reg  [4:0]  Rd_MEM
);

    always @(posedge clk) begin
        // Control
        RegWr_MEM  <= RegWr_EX;
        MemWr_MEM  <= MemWr_EX;
        MemRd_MEM  <= MemRd_EX;
        WBdata_MEM <= WBdata_EX;

        // Data
        ALUout_MEM <= ALUout_EX;
        D_MEM      <= D_EX;
        NPC_MEM    <= NPC_EX;
        Rd_MEM     <= Rd_EX;
    end

endmodule

// Memory - Write Back Buffer ==> MEMWB
module MEM_WB (
    input clk,
    input RegWrite,             // From MEM stage
    input [4:0] Rd,             // 5-bit destination register
    input [31:0] Data,          // 32-bit data to be written back

    output reg RegWr_final,   // To WB stage
    output reg [4:0] Rd_out,
    output reg [31:0] Data_out
);

    always @(posedge clk) begin
        RegWr_final <= RegWrite;
        Rd_out       <= Rd;
        Data_out     <= Data;	
    end

endmodule

//Fetch - Decode Buffer ==> IF_ID
module IF_ID(
  input clk,disable_IR,kill,
  input [31:0] Instruction_F,NPC_F,
  output reg [31:0] Instruction_D, NPC_D
  );

  always@(posedge clk) begin
    if(~disable_IR) begin
      if(kill) Instruction_D <= 32'h00000000;	// NOP
      else Instruction_D <= Instruction_F;
      NPC_D <= NPC_F;
    end
  end
endmodule

//======================================================
// ID / EX Pipeline Register
//======================================================
module ID_EX (
    input  wire        clk,
    input  wire        stall,

    // -------- Control signals from ID --------
    input  wire        RegWr_ID,
    input  wire        MemWr_ID,
    input  wire        MemRd_ID,
    input  wire        ALUSrc_ID,
    input  wire [2:0]  ALUop_ID,
    input  wire [1:0]  WBdata_ID,

    // -------- Data signals from ID --------
    input  wire [31:0] A_ID,
    input  wire [31:0] B_ID,
    input  wire [31:0] Imm_ID,
    input  wire [31:0] NPC_ID,
    input  wire [4:0]  Rd_ID,

    // -------- Outputs to EX stage --------
    output reg         RegWr_EX,
    output reg         MemWr_EX,
    output reg         MemRd_EX,
    output reg         ALUSrc_EX,
    output reg  [2:0]  ALUop_EX,
    output reg  [1:0]  WBdata_EX,

    output reg  [31:0] A_EX,
    output reg  [31:0] B_EX,
    output reg  [31:0] Imm_EX,
    output reg  [31:0] NPC_EX,
    output reg  [4:0]  Rd_EX
);

    always @(posedge clk) begin
        if (stall) begin
            // Bubble: zero control
            RegWr_EX  <= 1'b0;
            MemWr_EX  <= 1'b0;
            MemRd_EX  <= 1'b0;
            ALUSrc_EX <= 1'b0;
            ALUop_EX  <= 3'b000;
            WBdata_EX <= 2'b00;

            // Data don't-care
            A_EX      <= 32'd0;
            B_EX      <= 32'd0;
            Imm_EX    <= 32'd0;
            NPC_EX    <= 32'd0;
            Rd_EX     <= 5'd0;
        end
        else begin
            // Normal latch
            RegWr_EX  <= RegWr_ID;
            MemWr_EX  <= MemWr_ID;
            MemRd_EX  <= MemRd_ID;
            ALUSrc_EX <= ALUSrc_ID;
            ALUop_EX  <= ALUop_ID;
            WBdata_EX <= WBdata_ID;

            A_EX      <= A_ID;
            B_EX      <= B_ID;
            Imm_EX    <= Imm_ID;
            NPC_EX    <= NPC_ID;
            Rd_EX     <= Rd_ID;
        end
    end

endmodule
