module Fetch (
    input  wire        clk,
    input  wire        reset,

    // From Hazard Detect / Stall logic (diagram: "Disable PC", "Disable IR")
    // In the datapath these are enables: when low, the reg holds its value.
    input  wire        PCWr,      // enable write to PC (R30)
    input  wire        IRWrite,   // enable write to IR and NPC regs

    // From PC control (diagram: PCSrc selects PC+1 / TargetAddress / Reg[Rs])
    input  wire [1:0]  PCSrc,

    // Bubble/kill (diagram: KILL -> mux inserts NOP)
    input  wire        KILL,

    // Mux inputs (diagram labels)
    input  wire [31:0] TargetAddress, // resolved target (branch/jump target)
    input  wire [31:0] RegRs,         // JR target (Reg[Rs])

    // Outputs / pipeline regs (diagram: PC(R30), NPC, IR)
    output reg  [31:0] PC,   // PC (R30) -> Instruction Memory Address
    output reg  [31:0] NPC,  // latched PC+1
    output reg  [31:0] IR    // latched instruction
);

    // PC + 1 (word-addressed, as in the diagram)
    wire [31:0] PC_plus1 = PC + 32'd1;

    // Next PC from PC mux (PCSrc)
    reg  [31:0] PC_next;
    always @(*) begin
        case (PCSrc)
            2'd0: PC_next = PC_plus1;      // PC+1
            2'd1: PC_next = TargetAddress; // Target Address
            2'd2: PC_next = RegRs;         // Reg[Rs]
            default: PC_next = PC_plus1;
        endcase
    end

    // Instruction memory (combinational read assumed, matches your instantiation style)
    wire [31:0] imem_instr;
    InstructionMemo imem (
        .Address     (PC),
        .Instruction (imem_instr)
    );

    // IR input mux for bubble/kill (insert NOP)
    wire [31:0] IR_in = (KILL) ? 32'h0000_0000 : imem_instr; // NOP encoding per your design

    // Sequential regs: PC(R30), NPC, IR
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            PC  <= 32'd0;
            NPC <= 32'd0;
            IR  <= 32'd0;
        end else begin
            // PC update can be stalled independently
            if (PCWr) begin
                PC <= PC_next;
            end

            // NPC/IR update can be stalled independently
            if (IRWrite) begin
                NPC <= PC_plus1; // latch PC+1 (from current PC)
                IR  <= IR_in;    // latch instruction or NOP if KILL
            end
        end
    end

endmodule