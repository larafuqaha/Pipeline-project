module IF_stage (
    input  wire        clk,
    input  wire        reset,

    // Control
    input  wire        disable_PC,
    input  wire        disable_IR,
    input  wire        KILL,
    input  wire [1:0]  PCsrc,

    // PC inputs
    input  wire [31:0] PC_offset,
    input  wire [31:0] PC_regRs,

    // Outputs
    output reg  [31:0] Instruction_F,
    output reg  [31:0] NPC_F,
    output reg  [31:0] PC
);

    // -------------------------------------------------
    // PC + 1 from CURRENT PC (for sequential path)
    // -------------------------------------------------
    wire [31:0] PC_plus1 = PC + 32'd1;

    // -------------------------------------------------
    // Instruction memory 
    // -------------------------------------------------
    wire [31:0] Instruction;
    InstructionMemo IM (
        .Address     (PC),
        .Instruction (Instruction)
    );

    // -------------------------------------------------
    // Next PC selection
    // -------------------------------------------------
    wire [31:0] PC_next;
    mux3 #(32) pc_mux (
        .a (PC_plus1),   // 00: PC + 1
        .b (PC_offset),  // 01: jump/call
        .c (PC_regRs),   // 10: JR
        .s (PCsrc),
        .y (PC_next)
    );

    // -------------------------------------------------
    // PC register
    // -------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset)
            PC <= 32'd0;
        else if (!disable_PC)
            PC <= PC_next;
    end

    // -------------------------------------------------
    // IF / ID latch
    // -------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            Instruction_F <= 32'b0;
            NPC_F         <= 32'b0;
        end
        else if (!disable_IR) begin
            Instruction_F <= KILL ? 32'b0 : Instruction;
            NPC_F         <= PC_plus1;  
        end
    end

endmodule
