module DataMemo (
    input        clk,
    input        MemRd,
    input        MemWr_final,
    input [31:0] Address,
    input [31:0] Data_in,
    output reg [31:0] Data_out
);

    reg [31:0] memory [0:63];
    integer i;

    initial begin
        for (i = 0; i < 64; i = i + 1)
            memory[i] = 32'b0;

        memory[1] = 32'h00000005; 
        memory[2] = 32'h0000000A; 
    end

    // WRITE
    always @(posedge clk) begin
        if (MemWr_final)
            memory[Address[5:0]] <= Data_in;   
    end

    // READ 
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
//memory[0] = 32'h01061100; // ADD R3, R1, R2, R4  (executes)
//memory[1] = 32'h000A1100; // ADD R5, R1, R2, R0  (killed)
//memory[2] = 32'h00000000; // NOP
//memory[3] = 32'h00000000; // NOP 
//memory[0] = 32'h30042005; // ORI R2, R1, #5
//memory[1] = 32'h00000000; // NOP	
//memory[0] = 32'h48060004; // LW R3, 4(R0)
//memory[1] = 32'h00000000; // NOP
//memory[2] = 32'h00000000; // NOP


//memory[0] = 32'h04062000; // ADD  R3, R1, R2   -> updates Rp based on result
//memory[1] = 32'h04084000; // ADDp R4, R1, R3  -> predicated, should be squashed
//memory[2] = 32'h040E2000; // ADD  R7, R1, R2  -> normal instruction
//memory[3] = 32'h00000000; // NOP	 

 //load hz
//memory[0] = 32'h280A0005;
//memory[1] = 32'h48022000;
//memory[2] = 32'h00061280;	   
	   
// Predication (Rp) forwarding test
//memory[0] = 32'h28040000; // ADDI R2, R0, 0x000, R0     ; R2 = 0 (base for store)
//memory[1] = 32'h28080001; // ADDI R4, R0, 0x001, R0     ; R4 = 1 (predicate becomes TRUE)
//memory[2] = 32'h00000000; // NOP                        ; lets R4 value reach a forwardable stage
//memory[3] = 32'h290E0123; // ADDI R7, R0, 0x123, R4     ; predicated on R4 (should EXECUTE)
//memory[4] = 32'h500E2000; // SW   R7, 0(R2), R0         ; Mem[0] = 0x123
//memory[5] = 32'h00000000; // NOP	 

memory[0] = 32'h28020005;
memory[1] =32'h00000000;   
memory[2] =32'h00000000;
memory[3] = 32'h00041200  ;









    end

    always @(*) begin
    Instruction = memory[Address[7:0]];
end


endmodule
