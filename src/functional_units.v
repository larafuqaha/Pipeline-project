// data memory
module DataMemo ( clk,MemRd,MemWr_final,Address,Data_in,Data_out);
    input clk;
    input MemRd;
    input MemWr_final;
    input [5:0] Address;
    input [31:0] Data_in ;
    output reg [31:0] Data_out ;

    // 1024 x 32-bit memory
    reg [31:0] memory [0:63];

    // Write operation
    always @(posedge clk) begin
        if (MemWr_final) begin
            memory[Address] <= Data_in;
        end
    end

    // Read operation 
    always @(*) begin
        if (MemRd) begin
            Data_out = memory[Address];
        end else begin
            Data_out = 32'd0;
        end
    end

endmodule

// instruction memory
module InstructionMemo (
    input wire [31:0] Address,
    output reg [31:0] Instruction
);

    reg [31:0] memory [0:255]; // 256-word ROM
    initial begin
    memory[0]  = 32'h28020005; // ADDI R2, R0, 5
	memory[1]  = 32'h28040003; // ADDI R4, R0, 3
	memory[2]  = 32'h00061100; // ADD  R6, R2, R4
	memory[3]  = 32'h08081100; // SUB  R8, R2, R4
	memory[4]  = 32'h400A300F; // ANDI R10, R6, 15   
	memory[5]  = 32'h300C40F0; // ORI  R12, R8, 240
	memory[6]  = 32'h380E0000; // NORI R14, R0, 0
	memory[7]  = 32'h48060000; // LW   R6, 0(R0)     
	memory[8]  = 32'h50100000; // SW   R16, 0(R0)
	memory[9]  = 32'h10125300; // ADD  R18, R9, R10
	memory[10] = 32'h20145300; // OR   R20, R9, R10
	memory[11] = 32'h18165300; // AND  R22, R9, R10
	memory[12] = 32'h58000003; // J    3           
	memory[13] = 32'h28180001; // ADDI R24, R0, 1
	memory[14] = 32'h28180002; // ADDI R24, R0, 2
	memory[15] = 32'h28180009; // ADDI R24, R0, 9

    end


    always @(*) begin
    if (Address < 256)
        Instruction = memory[Address];
    else
        Instruction = 32'h00000000; // Default to NOP on out-of-bounds
    end


endmodule