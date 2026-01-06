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
	     // ADDI
	5'd5: begin
	  RegWr_control = 1'b1;
	  ALUSrc        = 1'b1;
	  ExtOp         = 1'b1;
	  ALUop         = 3'b000;
	  RBSrc         = 1'b1;   
	end
	
	// ORI
	5'd6: begin
	  RegWr_control = 1'b1;
	  ALUSrc        = 1'b1;
	  ExtOp         = 1'b0;
	  ALUop         = 3'b010;
	  RBSrc         = 1'b1;  
	end
	
	// NORI
	5'd7: begin
	  RegWr_control = 1'b1;
	  ALUSrc        = 1'b1;
	  ExtOp         = 1'b0;
	  ALUop         = 3'b011;
	  RBSrc         = 1'b1;  
	end
	
	// ANDI
	5'd8: begin
	  RegWr_control = 1'b1;
	  ALUSrc        = 1'b1;
	  ExtOp         = 1'b0;
	  ALUop         = 3'b100;
	  RBSrc         = 1'b1;   
	end
	
	// LW
	5'd9: begin
	  RegWr_control = 1'b1;
	  MemRd         = 1'b1;
	  ALUSrc        = 1'b1;
	  ExtOp         = 1'b1;
	  ALUop         = 3'b000;
	  WBdata        = 2'b01;
	  RBSrc         = 1'b1;  
	end
	
	// SW (already correct)
	5'd10: begin
	  MemWr_control = 1'b1;
	  ALUSrc        = 1'b1;
	  ExtOp         = 1'b1;
	  ALUop         = 3'b000;
	  RBSrc         = 1'b1;
	end


      // -------------------------
      // CALL
      // -------------------------
      5'd12: begin // CALL
		  RegWr_control = 1'b1;
		  RegDst        = 1'b1;
		  WBdata        = 2'b10;
		  ALUSrc        = 1'b1;  
		  ExtOp         = 1'b1;
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
            5'd11,5'd12: begin
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
    input  wire       Rpzero,     // =1 if Reg[Rp] == 0
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
    input  wire [4:0]  Rp,            // read predicate reg
    input  wire [31:0] BusW,           // write data

    output wire [31:0] BusA,           // read data A 
    output wire [31:0] BusB,           // read data B
    output wire [31:0] BusP            // read data P
);

    reg [31:0] registers [0:31];

    // -------------------------------------------------
    // Initial state
    // -------------------------------------------------
    initial begin
        registers[0]  = 0;
        registers[1]  = 1;
        registers[2]  = 7;
        registers[3]  = 6;
        registers[4]  = 0;
        registers[5]  = 0;
        registers[6]  = 3;
        registers[7]  = 1;
        registers[8]  = 0;
        registers[9]  = 0;
        registers[10] = 0;
        registers[11] = 0;
        registers[12] = 0;
        registers[13] = 0;
        registers[14] = 0;
        registers[15] = 0;
        registers[16] = 1;
        registers[17] = 7;
        registers[18] = 6;
        registers[19] = 0;
        registers[20] = 0;
        registers[21] = 3;
        registers[22] = 1;
        registers[23] = 0;
        registers[24] = 0;
        registers[25] = 0;
        registers[26] = 0;
        registers[27] = 0;
        registers[28] = 0;
        registers[29] = 0;
        registers[30] = 0;   
        registers[31] = 0;
    end

    // -------------------------------------------------
    // Async reads
    // -------------------------------------------------
    assign BusA = (Rs == 5'd0) ? 32'b0 : registers[Rs];
    assign BusB = (Rt == 5'd0) ? 32'b0 : registers[Rt];
    assign BusP = (Rp == 5'd0) ? 32'b0 : registers[Rp];

    // -------------------------------------------------
    // Sync write
    // -------------------------------------------------
    always @(posedge clk) begin
        if (RegWr_final && (Rd != 5'd0) && (Rd != 5'd30))
            registers[Rd] <= BusW;

        registers[0]  <= 32'b0;  // R0 hardwired to zero
        registers[30] <= 32'b0;  // R30 hardwired (PC shadow)
    end

endmodule




module ID_stage (
    input  wire        clk,

    input  wire [31:0] Instruction_D,
    input  wire [31:0] NPC_D,          // NPC = PC in your design

    // WB feedback
    input  wire        RegWr_WB_final,
    input  wire [4:0]  Rd_WB,
    input  wire [31:0] BusW_WB,

    // forwarding data
    input  wire [31:0] Fwd_EX,
    input  wire [31:0] Fwd_MEM,
    input  wire [31:0] Fwd_WB,

    // hazard bookkeeping
    input  wire [4:0]  Rd_EX,
    input  wire [4:0]  Rd_MEM,
    input  wire [4:0]  Rd_WB_pipe,

    input  wire        RegWrite_EX,
    input  wire        RegWrite_MEM,
    input  wire        RegWrite_WB,
    input  wire        MemRead_EX,

    input  wire        RPzero_EX,
    input  wire        RPzero_MEM,
    input  wire        RPzero_WB,

    // ---------------- IF control ----------------
    output wire [1:0]  PCsrc,
    output wire        KILL,
    output wire [31:0] PC_offset,
    output wire [31:0] PC_regRs,

    output wire        Stall,
    output wire        disable_PC,
    output wire        disable_IR,

    // ---------------- final gated controls ----------------
    output wire        RegWr_final,
    output wire        MemWr_final,
    output wire        MemRd_final,

    // ---------------- ID/EX outputs ----------------
    output wire        RegWr_IDEX,
    output wire        MemWr_IDEX,
    output wire        MemRd_IDEX,

    output wire        ALUSrc_IDEX,
    output wire [2:0]  ALUop_IDEX,
    output wire [1:0]  WBdata_IDEX,

    output wire [31:0] A_IDEX,
    output wire [31:0] B_IDEX,
    output wire [31:0] IMM_IDEX,
    output wire [31:0] NPC2_IDEX,
    output wire [4:0]  Rd2_IDEX,
    output wire        RPzero_IDEX
);

    // ---------------- instruction fields ----------------
    wire [4:0] opcode = Instruction_D[31:27];
    wire [4:0] Rp     = Instruction_D[26:22];
    wire [4:0] Rd     = Instruction_D[21:17];
    wire [4:0] Rs     = Instruction_D[16:12];
    wire [4:0] Rt     = Instruction_D[11:7];
    wire [21:0] imm22 = Instruction_D[21:0];

    // ---------------- main control ----------------
    wire RegWr_control, MemWr_control, MemRd_control;
    wire ALUSrc_control, ExtOp_control, RBSrc_control, RegDst_control;
    wire [1:0] WBdata_control;
    wire [2:0] ALUop_control;

    control_unit CU (
        .opcode(opcode),
        .RegWr_control(RegWr_control),
        .MemWr_control(MemWr_control),
        .MemRd(MemRd_control),
        .ALUSrc(ALUSrc_control),
        .ExtOp(ExtOp_control),
        .RBSrc(RBSrc_control),
        .RegDst(RegDst_control),
        .WBdata(WBdata_control),
        .ALUop(ALUop_control)
    );

    // ---------------- register file ----------------
    wire [31:0] BusA_raw, BusB_raw, BusP_raw;

    RegisterFile RF (
        .clk(clk),
        .RegWr_final(RegWr_WB_final),
        .Rd(Rd_WB),
        .Rs(Rs),
        .Rt(Rt),
        .Rp(Rp),
        .BusW(BusW_WB),
        .BusA(BusA_raw),
        .BusB(BusB_raw),
        .BusP(BusP_raw)
    );

    // ---------------- predication ----------------
    wire Rpzero = (Rp != 5'd0) && (BusP_raw == 32'b0);
    assign RPzero_IDEX = Rpzero;

    // ---------------- extender ----------------
    wire [31:0] imm_ext;
    extender EXT (
        .opcode(opcode),
        .imm_in(imm22),
        .ExtOp(ExtOp_control),
        .imm_out(imm_ext)
    );

    // ---------------- PC control ----------------
    pc_control PCC (
        .Op(opcode),
        .Rpzero(Rpzero),
        .PCsrc(PCsrc),
        .KILL(KILL)
    );

    // ---------------- hazard unit ----------------
    wire [1:0] ForwardA, ForwardB;

    Hazard_Unit HU (
        .Rs(Rs),
        .Rt(Rt),
        .Rd_EX(Rd_EX),
        .Rd_MEM(Rd_MEM),
        .Rd_WB(Rd_WB_pipe),
        .RegWrite_EX(RegWrite_EX),
        .RegWrite_MEM(RegWrite_MEM),
        .RegWrite_WB(RegWrite_WB),
        .MemRead_EX(MemRead_EX),
        .RPzero_EX(RPzero_EX),
        .RPzero_MEM(RPzero_MEM),
        .RPzero_WB(RPzero_WB),
        .ForwardA(ForwardA),
        .ForwardB(ForwardB),
        .Stall(Stall)
    );

    assign disable_PC = Stall;
    assign disable_IR = Stall;

    // ---------------- forwarding muxes ----------------
    reg [31:0] A_fwd, B_fwd;

    always @(*) begin
        case (ForwardA)
            2'b00: A_fwd = BusA_raw;
            2'b01: A_fwd = Fwd_EX;
            2'b10: A_fwd = Fwd_MEM;
            2'b11: A_fwd = Fwd_WB;
        endcase
    end

    always @(*) begin
        case (ForwardB)
            2'b00: B_fwd = BusB_raw;
            2'b01: B_fwd = Fwd_EX;
            2'b10: B_fwd = Fwd_MEM;
            2'b11: B_fwd = Fwd_WB;
        endcase
    end

    // JR must use forwarded Rs
    assign PC_regRs = A_fwd;

	// jump target
	assign PC_offset = NPC_D + imm_ext - 32'd1;

	// return address =  NPC_D we pipeline PC +1 
	assign NPC2_IDEX = NPC_D;


    // ---------------- datapath outputs ----------------
    assign A_IDEX   = A_fwd;
    assign B_IDEX   = B_fwd;
    assign IMM_IDEX = imm_ext;
   

    // BusB selection
	wire [4:0] RB_bus = RBSrc_control ? Rd : Rt;

	// Destination selection 
	assign Rd2_IDEX = RegDst_control ? 5'd31 : Rd;

    // ---------------- predication gating ----------------
    wire exec_en = ~Rpzero;

    assign RegWr_final = RegWr_control & exec_en;
    assign MemWr_final = MemWr_control & exec_en;
    assign MemRd_final = MemRd_control & exec_en;

    // ---------------- bubble injection ----------------
    wire bubble = Stall;

    assign RegWr_IDEX  = bubble ? 1'b0 : RegWr_final;
    assign MemWr_IDEX  = bubble ? 1'b0 : MemWr_final;
    assign MemRd_IDEX  = bubble ? 1'b0 : MemRd_final;

    assign ALUSrc_IDEX = bubble ? 1'b0   : ALUSrc_control;
    assign ALUop_IDEX  = bubble ? 3'b000 : ALUop_control;
    assign WBdata_IDEX = bubble ? 2'b00  : WBdata_control;

endmodule
