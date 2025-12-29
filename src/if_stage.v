module IF_stage (
    input  wire        clk,
    input  wire        reset,

    // Control signals
    input  wire        disable_PC,   // stall PC
    input  wire        disable_IR,   // stall IF/ID
    input  wire        KILL,          // flush instruction
    input  wire [1:0]  PCsrc,         // PC select

    // Resolved PC inputs (from ID stage)
    input  wire [31:0] PC_offset,     // PC + signext(offset)
    input  wire [31:0] PC_regRs,       // Reg[Rs] (JR)

    // Outputs to IF/ID
    output reg  [31:0] Instruction_F,
    output reg  [31:0] NPC_F,

    // Program Counter (R30)
    output reg  [31:0] PC
); 

      // PC + 1
    wire [31:0] PC_plus1;
    assign PC_plus1 = PC + 32'd1;

     //  Next PC selection
    wire [31:0] PC_next;

    mux3 #(32) pc_mux (
        .a(PC_plus1),    // PCsrc = 00
        .b(PC_offset),   // PCsrc = 01
        .c(PC_regRs),    // PCsrc = 10
        .s(PCsrc),
        .y(PC_next)
    );

     // PC Register (R30)
    always @(posedge clk or posedge reset) begin
        if (reset)
            PC <= 32'd0;
        else if (!disable_PC)
            PC <= PC_next;
    end

    // Instruction Memory
    wire [31:0] Instruction;

    InstructionMemo IM (
        .Address(PC),
        .Instruction(Instruction)
    );

    // IF / ID register outputs
    always @(posedge clk) begin
        if (!disable_IR) begin
            if (KILL)
                Instruction_F <= 32'h00000000; // NOP
            else
                Instruction_F <= Instruction;

            NPC_F <= PC_plus1;
        end
    end

endmodule
