module ALU (
    input  wire [2:0]  ALUop,
    input  wire [31:0] A,
    input  wire [31:0] B,
    output reg  [31:0] ALUout
);

    always @(*) begin
        case (ALUop)
            3'b000: ALUout = A + B;        // ADD
            3'b001: ALUout = A - B;        // SUB
            3'b010: ALUout = A | B;        // OR
            3'b011: ALUout = ~(A | B);     // NOR 
            3'b100: ALUout = A & B;        // AND
            default: ALUout = 32'b0;
        endcase
    end

endmodule

module Execute (
    input clk,

    // from ID/EX
    input        RegWr_ID,
    input        MemWr_ID,
    input        MemRd_ID,
    input [1:0]  WBdata_ID,
    input        ALUSrc_ID,
    input [2:0]  ALUop_ID,

    input [31:0] npc2,
    input [31:0] imm,
    input [31:0] A,
    input [31:0] B,
    input [4:0]  rd2,
    input [4:0]  rs2,
    input [4:0]  rt2,
    input        RPzero_ID,

    // EX/MEM (previous instruction)
    input        RegWr_EXM,
    input [4:0]  rd3_EXM,
    input [31:0] ALUout_EXM,

    // MEM/WB
    input        RegWr_WB,
    input [4:0]  Rd_WB,
    input [31:0] BusW_WB,

    // outputs
    output reg        RegWr_EX,
    output reg        MemWr_EX,
    output reg        MemRd_EX,
    output reg [1:0]  WBdata_EX,

    output reg [31:0] ALUout_EX,
    output reg [31:0] D,
    output reg [31:0] npc3,
    output reg [4:0]  rd3,
    output reg        RPzero_EX
);

    // -----------------------------
    // Forwarding (EX/MEM has priority over WB)
    // -----------------------------
    wire [31:0] A_fwd =
        (RegWr_EXM && (rd3_EXM != 5'd0) && (rd3_EXM != 5'd30) && (rd3_EXM == rs2)) ? ALUout_EXM :
        (RegWr_WB  && (Rd_WB   != 5'd0) && (Rd_WB   != 5'd30) && (Rd_WB   == rs2)) ? BusW_WB   :
                                                                                      A;

    wire [31:0] B_fwd =
        (RegWr_EXM && (rd3_EXM != 5'd0) && (rd3_EXM != 5'd30) && (rd3_EXM == rt2)) ? ALUout_EXM :
        (RegWr_WB  && (Rd_WB   != 5'd0) && (Rd_WB   != 5'd30) && (Rd_WB   == rt2)) ? BusW_WB   :
                                                                                      B;

    // ALU input select
    wire [31:0] ALU_B = (ALUSrc_ID) ? imm : B_fwd;

    // store data should also be forwarded
    wire [31:0] store_data = B_fwd;

    // ALU output (combinational)
    wire [31:0] alu_out;

    ALU alu_inst (
        .ALUop (ALUop_ID),
        .A     (A_fwd),
        .B     (ALU_B),
        .ALUout(alu_out)
    );

    // -----------------------------
    // EX/MEM pipeline register
    // -----------------------------
    always @(posedge clk) begin
        ALUout_EX <= alu_out;
        D         <= store_data;  
        npc3      <= npc2;
        rd3       <= rd2;

        RegWr_EX  <= RegWr_ID;
        MemWr_EX  <= MemWr_ID;
        MemRd_EX  <= MemRd_ID;
        WBdata_EX <= WBdata_ID;
        RPzero_EX <= RPzero_ID;
    end

endmodule

