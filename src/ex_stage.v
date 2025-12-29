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

    // -------- inputs from ID/EX --------
    input        RegWr_ID,
    input        MemWr_ID,
    input        MemRd_ID,
    input [1:0]  WBdata_ID,
    input        ALUSrc_ID,
    input [2:0]  ALUop_ID,

    input [31:0] npc2,
    input [31:0] imm12,
    input [31:0] A,
    input [31:0] B,
    input [3:0]  rd2,

    // -------- outputs to MEM stage (EX/MEM) --------
    output reg        RegWr_EX,
    output reg        MemWr_EX,
    output reg        MemRd_EX,
    output reg [1:0]  WBdata_EX,

    output reg [31:0] ALUout,
    output reg [31:0] D,
    output reg [31:0] npc3,
    output reg [3:0]  rd3
);

    // ALU output (combinational)
    wire [31:0] alu_out;

    // ALU instance (directly using inputs)
    ALU alu_inst (
        .ALUop (ALUop_ID),
        .A     (A),
        .B     (ALUSrc_ID ? imm12 : B),
        .ALUout(alu_out)
    );

    // EX/MEM pipeline register
    always @(posedge clk) begin
        ALUout    <= alu_out;
        D         <= B;
        npc3      <= npc2;
        rd3       <= rd2;

        RegWr_EX  <= RegWr_ID;
        MemWr_EX  <= MemWr_ID;
        MemRd_EX  <= MemRd_ID;
        WBdata_EX <= WBdata_ID;
    end

endmodule
