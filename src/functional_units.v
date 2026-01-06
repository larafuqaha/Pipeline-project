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

    // READ 
    always @(*) begin
        if (MemRd)
            Data_out = memory[Address[5:0]];
        else
            Data_out = 32'b0;	  
    end
endmodule



module InstructionMemo (input  wire [31:0] Address, output reg  [31:0] Instruction);

    reg [31:0] memory [0:255];
    integer i;

    initial begin
    integer i;
    for (i = 0; i < 256; i = i + 1)
        memory[i] = 32'h00000000; // NOP
  
    memory[0] = 32'b01001000000010100001000000000111;  // LW R5, 7(R1) 

end

    always @(*) begin
    Instruction = memory[Address[7:0]];
end
endmodule	  
