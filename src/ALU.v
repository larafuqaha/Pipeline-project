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