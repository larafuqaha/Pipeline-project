module IF_ID(
  input  wire        clk,
  input  wire        reset,
  input  wire        disable_IR,
  input  wire        kill,
  input  wire [31:0] Instruction_F,
  input  wire [31:0] NPC_F,
  output reg  [31:0] Instruction_D,
  output reg  [31:0] NPC_D
);

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      Instruction_D <= 32'h00000000; // NOP
      NPC_D         <= 32'b0;
    end else if (!disable_IR) begin
      Instruction_D <= kill ? 32'h00000000 : Instruction_F;
      NPC_D         <= NPC_F;
    end
  end
endmodule

module ID_EX (
    input  wire        clk,
    input  wire        reset,

    // control from ID
    input  wire        RegWr_ID,
    input  wire        MemWr_ID,
    input  wire        MemRd_ID,
    input  wire        ALUSrc_ID,
    input  wire [2:0]  ALUop_ID,
    input  wire [1:0]  WBdata_ID,

    // data from ID
    input  wire [31:0] A_ID,
    input  wire [31:0] B_ID,
    input  wire [31:0] Imm_ID,
    input  wire [31:0] NPC_ID,
    input  wire [4:0]  Rd_ID,

    // flush controls
    input  wire        kill,
    input  wire        stall,

    // outputs to EX
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

    always @(posedge clk or posedge reset) begin
        if (reset || stall) begin
            
            RegWr_EX  <= 1'b0;
            MemWr_EX  <= 1'b0;
            MemRd_EX  <= 1'b0;
            ALUSrc_EX <= 1'b0;
            ALUop_EX  <= 3'b000;
            WBdata_EX <= 2'b00;

            A_EX   <= 32'b0;
            B_EX   <= 32'b0;
            Imm_EX <= 32'b0;
            NPC_EX <= 32'b0;
            Rd_EX  <= 5'b0;
        end else begin
            RegWr_EX  <= RegWr_ID;
            MemWr_EX  <= MemWr_ID;
            MemRd_EX  <= MemRd_ID;
            ALUSrc_EX <= ALUSrc_ID;
            ALUop_EX  <= ALUop_ID;
            WBdata_EX <= WBdata_ID;

            A_EX   <= A_ID;
            B_EX   <= B_ID;
            Imm_EX <= Imm_ID;
            NPC_EX <= NPC_ID;
            Rd_EX  <= Rd_ID;
        end
    end

endmodule


module EX_MEM (
    input  wire        clk,
    input  wire        reset,

    // Control
    input  wire        RegWr_EX,
    input  wire        MemWr_EX,
    input  wire        MemRd_EX,
    input  wire [1:0]  WBdata_EX,

    // Data
    input  wire [31:0] ALUout_EX,
    input  wire [31:0] D_EX,
    input  wire [31:0] NPC_EX,
    input  wire [4:0]  Rd_EX,

    // Outputs
    output reg         RegWr_MEM,
    output reg         MemWr_MEM,
    output reg         MemRd_MEM,
    output reg  [1:0]  WBdata_MEM,

    output reg  [31:0] ALUout_MEM,
    output reg  [31:0] D_MEM,
    output reg  [31:0] NPC_MEM,
    output reg  [4:0]  Rd_MEM
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            RegWr_MEM  <= 1'b0;
            MemWr_MEM  <= 1'b0;
            MemRd_MEM  <= 1'b0;
            WBdata_MEM <= 2'b00;

            ALUout_MEM <= 32'b0;
            D_MEM      <= 32'b0;
            NPC_MEM    <= 32'b0;
            Rd_MEM     <= 5'd0;
        end else begin
            RegWr_MEM  <= RegWr_EX;
            MemWr_MEM  <= MemWr_EX;
            MemRd_MEM  <= MemRd_EX;
            WBdata_MEM <= WBdata_EX;

            ALUout_MEM <= ALUout_EX;
            D_MEM      <= D_EX;
            NPC_MEM    <= NPC_EX;
            Rd_MEM     <= Rd_EX;
        end
    end

endmodule
module MEM_WB (
    input  wire        clk,
    input  wire        reset,

    // -------- Inputs from MEM stage --------
    input  wire        RegWrite_MEM,
    input  wire [4:0]  Rd_MEM,
    input  wire [1:0]  WBdata_MEM,

    input  wire [31:0] ALUout_MEM,
    input  wire [31:0] MemOut_MEM,
    input  wire [31:0] NPC3_MEM,

    // -------- Outputs to WB stage --------
    output reg         RegWr_final,
    output reg  [4:0]  Rd_final,
    output reg  [1:0]  WBdata_final,

    output reg  [31:0] ALUout_final,
    output reg  [31:0] MemOut_final,
    output reg  [31:0] NPC3_final
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            RegWr_final   <= 1'b0;
            Rd_final      <= 5'd0;
            WBdata_final  <= 2'b00;

            ALUout_final  <= 32'b0;
            MemOut_final  <= 32'b0;
            NPC3_final    <= 32'b0;
        end else begin
            RegWr_final   <= RegWrite_MEM;
            Rd_final      <= Rd_MEM;
            WBdata_final  <= WBdata_MEM;

            ALUout_final  <= ALUout_MEM;
            MemOut_final  <= MemOut_MEM;
            NPC3_final    <= NPC3_MEM;
	end	  

    end

endmodule
