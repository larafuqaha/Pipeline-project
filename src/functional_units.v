module DataMemo (
    input        clk,
    input        MemRd,
    input        MemWr_final,
    input [31:0] Address,     
    input [31:0] Data_in,
    output reg [31:0] Data_out
);

    // 64 words = 256 bytes
    reg [31:0] memory [0:63];

    integer i;
    initial begin
        for (i = 0; i < 64; i = i + 1)
            memory[i] = 32'b0;

        memory[8]  = 32'h0000002A;  // 42
    	memory[12] = 32'h0000000D;  // 13
    end

    // WRITE (word-aligned)
    always @(posedge clk) begin
        if (MemWr_final) begin
            memory[Address[5:0]] <= Data_in;
        end
    end

    // READ (combinational)
    always @(*) begin
        if (MemRd)
            Data_out = memory[Address[5:0]];
        else
            Data_out = 32'b0;	  
    end
endmodule


module InstructionMemo (
    input  wire [31:0] Address,
    output reg  [31:0] Instruction
);

    reg [31:0] memory [0:255];
    integer i;

    initial begin
        // Fill entire ROM with NOPs first
        for (i = 0; i < 256; i = i + 1)
            memory[i] = 32'h00000000;



// -------- R-Type Forwarding Test Program --------

// memory[0]: ADD R3, R1, R2
// R3 = R1 + R2
memory[0] = 32'h00018880;

// memory[1]: SUB R4, R3, R1
// R4 = R3 - R1   (EX -> EX forwarding from previous ADD)
memory[1] = 32'h04221880;

// memory[2]: AND R5, R4, R3
// R5 = R4 & R3   (chained forwarding: uses two recent results)
memory[2] = 32'h102520C0;

// memory[3]: OR R6, R5, R4
// R6 = R5 | R4   (MEM/WB -> EX forwarding)
memory[3] = 32'h08062880;






    end

    always @(*) begin
    Instruction = memory[Address[7:0]];
end


endmodule
