// Main & ALU Control Unit (ID stage)
module control_unit (
  input  wire [4:0] opcode,

  // control enables (pre-gating)
  output reg        RegWr_control,
  output reg        MemWr_control,
  output reg        MemRd,

  // datapath selects
  output reg        ALUSrc,
  output reg        ExtOp,      // 1: sign-ext, 0: zero-ext
  output reg        RBSrc,      // 0: Rt, 1: Rd
  output reg        RegDst,     // 0: Rd, 1: R31

  output reg [1:0]  WBdata,    // 0: ALU, 1: MEM, 2: PC+1
  output reg [2:0]  ALUop
);

  always @(*) begin
    // -------------------------
    // defaults = NOP
    // -------------------------
    RegWr_control = 1'b0;
    MemWr_control = 1'b0;
    MemRd         = 1'b0;

    ALUSrc        = 1'b0;
    ExtOp         = 1'b0;   // zero-ext default
    RBSrc         = 1'b0;
    RegDst        = 1'b0;

    WBdata        = 2'b00;   // ALU
    ALUop         = 3'b000;   // ADD

    case (opcode)

      // -------------------------
      // R-type ALU instructions
      // -------------------------
      5'd0: begin // ADD
        RegWr_control = 1'b1;
        ALUop         = 3'b000; // ADD 
      end

      5'd1: begin // SUB
        RegWr_control = 1'b1;
        ALUop         = 3'b001; // SUB
      end

      5'd2: begin // OR
        RegWr_control = 1'b1;
        ALUop         = 3'b010; // OR
      end

      5'd3: begin // NOR
        RegWr_control = 1'b1;
        ALUop         = 3'b011; // NOR
      end

      5'd4: begin // AND
        RegWr_control = 1'b1;
        ALUop         = 3'b100; // AND
      end

      // -------------------------
      // I-type ALU instructions
      // -------------------------
      5'd5: begin // ADDI
        RegWr_control = 1'b1;
        ALUSrc        = 1'b1;
        ExtOp         = 1'b1; // sign-ext
        ALUop         = 3'b000; // ADD
      end

      5'd6: begin // ORI
        RegWr_control = 1'b1;
        ALUSrc        = 1'b1;
        ExtOp         = 1'b0; // zero-ext
        ALUop         = 3'b010; // OR
      end

      5'd7: begin // NORI
        RegWr_control = 1'b1;
        ALUSrc        = 1'b1;
        ExtOp         = 1'b0; // zero-ext
        ALUop         = 3'b011; // NOR
      end

      5'd8: begin // ANDI
        RegWr_control = 1'b1;
        ALUSrc        = 1'b1;
        ExtOp         = 1'b0; // zero-ext
        ALUop         = 3'b100; // AND
      end

      // -------------------------
      // Load / Store
      // -------------------------
      5'd9: begin // LW
        RegWr_control = 1'b1;
        MemRd         = 1'b1;
        ALUSrc        = 1'b1;
        ExtOp         = 1'b1; // sign-ext
        ALUop         = 3'b000; // ADD
        WBdata        = 2'b01; // MEM
      end

      5'd10: begin // SW
        MemWr_control = 1'b1;
        ALUSrc        = 1'b1;
        ExtOp         = 1'b1; // sign-ext
        ALUop         = 3'b000; // ADD
        RBSrc         = 1'b1; // use Rd
      end

      // -------------------------
      // CALL
      // -------------------------
      5'd12: begin // CALL
        RegWr_control = 1'b1;
        RegDst        = 1'b1; // R31
        WBdata        = 2'b10; // PC+1
      end

      default: begin
        // NOP
      end

    endcase
  end

endmodule

module extender (
    input  wire [4:0]  opcode,
    input  wire [21:0] imm_in,     // [11:0] for I-type, [21:0] for J-type
    input  wire        ExtOp,      // 1 = sign, 0 = zero (I-type only)
    output reg  [31:0] imm_out
);

    reg extend_bit;

    always @(*) begin
        case (opcode)

            // J, CALL ? 22-bit signed offset (ALWAYS sign-extended)
            5'd11,5'd12, 5'd13: begin
                extend_bit = imm_in[21];
                imm_out = { {10{extend_bit}}, imm_in[21:0] };
            end

            // I-type ? 12-bit immediate
            default: begin
                extend_bit = imm_in[11] & ExtOp;
                imm_out = { {20{extend_bit}}, imm_in[11:0] };
            end

        endcase
    end

endmodule

module pc_control (
    input  wire [4:0] Op,        // opcode
    input  wire       Rpzero,     // 1 if Reg[Rp] == 0
    output reg  [1:0] PCsrc,      // PC source select
    output reg        KILL        // kill next instruction
);

    // opcode parameters
    localparam OP_J    = 5'd11;
    localparam OP_CALL = 5'd12;
    localparam OP_JR   = 5'd13;

    always @(*) begin
        // defaults
        PCsrc = 2'b00; // PC + 1
        KILL  = 1'b0;

        // instruction executes only if predicate is true
        if (!Rpzero) begin
            case (Op)
                OP_J,
                OP_CALL: begin
                    PCsrc = 2'b01; // PC + offset
                    KILL  = 1'b1;  // squash wrong-path instruction
                end

                OP_JR: begin
                    PCsrc = 2'b10; // Reg[Rs]
                    KILL  = 1'b1;
                end

                default: begin
                    PCsrc = 2'b00;
                    KILL  = 1'b0;
                end
            endcase
        end
    end

endmodule

module RegisterFile (
    input  wire        clk,
    input  wire        RegWr_final,   // write enable
    input  wire [4:0]  Rd,            // write register number
    input  wire [4:0]  Rs,            // read reg A number
    input  wire [4:0]  Rt,            // read reg B number 
    input  wire [4:0]  Rp,              // read reg P number
    input  wire [31:0] BusW,          // write data
    output wire [31:0] BusA,          // read data A 
    output wire [31:0] BusP,          // read data P
    output wire [31:0] BusB           // read data B
);

    reg [31:0] registers [0:31]; 
    // Register pre-load
        initial begin
            registers[0] = 0;
            registers[1] = 1; 
            registers[2] = 7;
            registers[3] = 6;
            registers[4] = 0;
            registers[5] = 0;
            registers[6] = 3;
            registers[7] = 1;
            registers[8] = 0;
            registers[9] = 0;
            registers[10] = 0;
            registers[11] = 0;
            registers[12] = 0;
            registers[13] = 0;
            registers[14] = 0;
        end

    // async reads
    assign BusA = (Rs == 5'd0) ? 32'b0 : registers[Rs];
    assign BusB = (Rt == 5'd0) ? 32'b0 : registers[Rt];
    assign BusP = (Rp == 5'd0) ? 32'b0 : registers[Rp];

    // sync write
    always @(posedge clk) begin
        if (RegWr_final && (Rd != 5'd0) && (Rd != 5'd30))
            registers[Rd] <= BusW;

        registers[0] <= 32'b0; // keep R0 always zero
    end

endmodule

module ID_stage (
    input  wire        clk,
    input  wire        reset,

    // IF/ID inputs
    input  wire [31:0] IR,
    input  wire [31:0] NPC,              // pipelined PC+1

    // hazard unit
    input  wire        stall,
    input  wire [1:0]  ForwardA,
    input  wire [1:0]  ForwardB,

    // forwarding sources
    input  wire [31:0] ALUResult_fwd,     // from EX/MEM
    input  wire [31:0] MemResult_fwd,     // from MEM
    input  wire [31:0] EBResult_fwd,      // from WB

    // WB -> regfile
    input  wire        RegWr_WB,
    input  wire [4:0]  Rd_WB,
    input  wire [31:0] BusW_WB,

    // -------------------------
    // outputs to IF stage
    // -------------------------
    output wire        PCWrite,
    output wire        IRWrite,
    output wire [1:0]  PCsrc,
    output wire        KILL,

    output wire [31:0] JumpTarget_ID,
    output wire [31:0] JRTarget_ID,

    // -------------------------
    // ID/EX outputs
    // -------------------------
    output reg  [31:0] A_EX,
    output reg  [31:0] B_EX,
    output reg  [31:0] Imm_EX,
    output reg  [31:0] NPC_EX,

    output reg  [4:0]  Rs_EX,
    output reg  [4:0]  Rt_EX,
    output reg  [4:0]  Rd_EX,

    output reg         RegWr_EX,
    output reg         MemWr_EX,
    output reg         MemRd_EX,
    output reg         ALUSrc_EX,
    output reg  [2:0]  ALUop_EX,
    output reg  [1:0]  WBdata_EX
);

    // --------------------------------------------------
    // Instruction fields
    // --------------------------------------------------
    wire [4:0] opcode = IR[31:27];
    wire [4:0] Rp     = IR[26:22];
    wire [4:0] Rd     = IR[21:17];
    wire [4:0] Rs     = IR[16:12];
    wire [4:0] Rt     = IR[11:7];

    wire [11:0] imm12 = IR[11:0];
    wire [21:0] imm22 = IR[21:0];

    // --------------------------------------------------
    // Control unit (raw control)
    // --------------------------------------------------
    wire        RegWr_c, MemWr_c, MemRd_c;
    wire        ALUSrc_c, ExtOp_c, RBSrc_c, RegDst_c;
    wire [1:0]  WBdata_c;
    wire [2:0]  ALUop_c;

    control_unit CU (
        .opcode(opcode),
        .RegWr_control(RegWr_c),
        .MemWr_control(MemWr_c),
        .MemRd(MemRd_c),
        .ALUSrc(ALUSrc_c),
        .ExtOp(ExtOp_c),
        .RBSrc(RBSrc_c),
        .RegDst(RegDst_c),
        .WBdata(WBdata_c),
        .ALUop(ALUop_c)
    );

    // --------------------------------------------------
    // B source register select (SW uses Rd)
    // --------------------------------------------------
    wire [4:0] Rt_eff = RBSrc_c ? Rd : Rt;

    // --------------------------------------------------
    // Register file
    // --------------------------------------------------
    wire [31:0] BusA, BusB, BusP;

    RegisterFile RF (
        .clk(clk),
        .RegWr_final(RegWr_WB),
        .Rd(Rd_WB),
        .Rs(Rs),
        .Rt(Rt_eff),
        .Rp(Rp),
        .BusW(BusW_WB),
        .BusA(BusA),
        .BusB(BusB),
        .BusP(BusP)
    );

    // --------------------------------------------------
    // Predicate logic
    // Rpzero = 1 => instruction does NOT execute
    // --------------------------------------------------
    wire Rpzero = (Rp == 5'd0) ? 1'b0 : (BusP == 32'd0);
    wire PredTrue = ~Rpzero;

    // --------------------------------------------------
    // PC control unit (authoritative)
    // --------------------------------------------------
    wire [1:0] PCsrc_raw;
    wire       KILL_raw;

    pc_control PCCTRL (
        .Op(opcode),
        .Rpzero(Rpzero),
        .PCsrc(PCsrc_raw),
        .KILL(KILL_raw)
    );

    // --------------------------------------------------
    // Stall handling to IF stage
    // --------------------------------------------------
    assign PCWrite = ~stall;
    assign IRWrite = ~stall;

    assign PCsrc = stall ? 2'd0 : PCsrc_raw;
    assign KILL  = stall ? 1'b0 : KILL_raw;

    // --------------------------------------------------
    // Jump targets
    // --------------------------------------------------
    assign JumpTarget_ID = { NPC[31:22], imm22 };
    assign JRTarget_ID   = BusA;

    // --------------------------------------------------
    // Immediate extension (imm12 only)
    // --------------------------------------------------
    wire [31:0] imm_ext;

    extender EXT (
        .opcode(opcode),
        .imm_in(IR[21:0]),
        .ExtOp(ExtOp_c),
        .imm_out(imm_ext)
    );

    // --------------------------------------------------
    // Decode-stage forwarding muxes
    // ForwardA / ForwardB select what feeds A_EX / B_EX
    // 0: BusA / BusB
    // 1: ALUResult
    // 2: MemResult
    // 3: EBResult
    // --------------------------------------------------
    reg [31:0] A_sel, B_sel;

    always @(*) begin
        case (ForwardA)
            2'd0: A_sel = BusA;
            2'd1: A_sel = ALUResult_fwd;
            2'd2: A_sel = MemResult_fwd;
            2'd3: A_sel = EBResult_fwd;
            default: A_sel = BusA;
        endcase
    end

    always @(*) begin
        case (ForwardB)
            2'd0: B_sel = BusB;
            2'd1: B_sel = ALUResult_fwd;
            2'd2: B_sel = MemResult_fwd;
            2'd3: B_sel = EBResult_fwd;
            default: B_sel = BusB;
        endcase
    end

    // --------------------------------------------------
    // Predicate gating of controls
    // --------------------------------------------------
    wire RegWr_f   = RegWr_c  & PredTrue;
    wire MemWr_f   = MemWr_c  & PredTrue;
    wire MemRd_f   = MemRd_c  & PredTrue;
    wire ALUSrc_f  = ALUSrc_c & PredTrue;
    wire [2:0] ALUop_f  = PredTrue ? ALUop_c  : 3'd0;
    wire [1:0] WBdata_f = PredTrue ? WBdata_c : 2'd0;

    // --------------------------------------------------
    // Destination register
    // --------------------------------------------------
    wire [4:0] DestReg =
        MemWr_c  ? 5'd0 :
        RegDst_c ? 5'd31 :
                   Rd;

    // --------------------------------------------------
    // ID/EX pipeline register
    // --------------------------------------------------
    always @(posedge clk) begin
        if (reset || stall) begin
            A_EX      <= 32'd0;
            B_EX      <= 32'd0;
            Imm_EX    <= 32'd0;
            NPC_EX    <= 32'd0;

            Rs_EX     <= 5'd0;
            Rt_EX     <= 5'd0;
            Rd_EX     <= 5'd0;

            RegWr_EX  <= 1'b0;
            MemWr_EX  <= 1'b0;
            MemRd_EX  <= 1'b0;
            ALUSrc_EX <= 1'b0;
            ALUop_EX  <= 3'd0;
            WBdata_EX <= 2'd0;
        end
        else begin
            A_EX      <= A_sel;
            B_EX      <= B_sel;
            Imm_EX    <= imm_ext;
            NPC_EX    <= NPC;

            Rs_EX     <= Rs;
            Rt_EX     <= Rt_eff;
            Rd_EX     <= DestReg;

            RegWr_EX  <= RegWr_f;
            MemWr_EX  <= MemWr_f;
            MemRd_EX  <= MemRd_f;
            ALUSrc_EX <= ALUSrc_f;
            ALUop_EX  <= ALUop_f;
            WBdata_EX <= WBdata_f;
        end
    end

endmodule
