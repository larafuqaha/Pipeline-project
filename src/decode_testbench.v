
module ID_stage_detailed_tb;

    // =================================================
    // Clock
    // =================================================
    reg clk;
    always #5 clk = ~clk;

    // =================================================
    // Inputs
    // =================================================
    reg  [31:0] Instruction_D;
    reg  [31:0] NPC_D;

    reg         RegWr_WB_final;
    reg  [4:0]  Rd_WB;
    reg  [31:0] BusW_WB;

    reg  [31:0] Fwd_EX, Fwd_MEM, Fwd_WB;

    reg  [4:0]  Rd_EX, Rd_MEM, Rd_WB_pipe;
    reg         RegWrite_EX, RegWrite_MEM, RegWrite_WB;
    reg         MemRead_EX;

    reg         RPzero_EX, RPzero_MEM, RPzero_WB;

    // =================================================
    // Outputs
    // =================================================
    wire [1:0]  PCsrc;
    wire        KILL;
    wire [31:0] PC_offset;
    wire [31:0] PC_regRs;

    wire        Stall;
    wire        disable_PC;
    wire        disable_IR;

    wire        RegWr_final;
    wire        MemWr_final;
    wire        MemRd_final;

    wire        RegWr_IDEX;
    wire        MemWr_IDEX;
    wire        MemRd_IDEX;

    wire        ALUSrc_IDEX;
    wire [2:0]  ALUop_IDEX;
    wire [1:0]  WBdata_IDEX;

    wire [31:0] A_IDEX;
    wire [31:0] B_IDEX;
    wire [31:0] IMM_IDEX;
    wire [31:0] NPC2_IDEX;

    wire [4:0]  Rd2_IDEX;
    wire        RPzero_IDEX;

    // =================================================
    // DUT
    // =================================================
    ID_stage dut (
        .clk(clk),

        .Instruction_D(Instruction_D),
        .NPC_D(NPC_D),

        .RegWr_WB_final(RegWr_WB_final),
        .Rd_WB(Rd_WB),
        .BusW_WB(BusW_WB),

        .Fwd_EX(Fwd_EX),
        .Fwd_MEM(Fwd_MEM),
        .Fwd_WB(Fwd_WB),

        .Rd_EX(Rd_EX),
        .Rd_MEM(Rd_MEM),
        .Rd_WB_pipe(Rd_WB_pipe),

        .RegWrite_EX(RegWrite_EX),
        .RegWrite_MEM(RegWrite_MEM),
        .RegWrite_WB(RegWrite_WB),

        .MemRead_EX(MemRead_EX),

        .RPzero_EX(RPzero_EX),
        .RPzero_MEM(RPzero_MEM),
        .RPzero_WB(RPzero_WB),

        .PCsrc(PCsrc),
        .KILL(KILL),
        .PC_offset(PC_offset),
        .PC_regRs(PC_regRs),

        .Stall(Stall),
        .disable_PC(disable_PC),
        .disable_IR(disable_IR),

        .RegWr_final(RegWr_final),
        .MemWr_final(MemWr_final),
        .MemRd_final(MemRd_final),

        .RegWr_IDEX(RegWr_IDEX),
        .MemWr_IDEX(MemWr_IDEX),
        .MemRd_IDEX(MemRd_IDEX),

        .ALUSrc_IDEX(ALUSrc_IDEX),
        .ALUop_IDEX(ALUop_IDEX),
        .WBdata_IDEX(WBdata_IDEX),

        .A_IDEX(A_IDEX),
        .B_IDEX(B_IDEX),
        .IMM_IDEX(IMM_IDEX),
        .NPC2_IDEX(NPC2_IDEX),

        .Rd2_IDEX(Rd2_IDEX),
        .RPzero_IDEX(RPzero_IDEX)
    );

    // =================================================
    // Instruction helper functions
    // =================================================
    function [31:0] Rtype;
        input [4:0] op, rp, rd, rs, rt;
        begin
            Rtype = {op, rp, rd, rs, rt, 7'b0};
        end
    endfunction

    function [31:0] Itype;
        input [4:0] op, rp, rd, rs;
        input [11:0] imm;
        begin
            Itype = {op, rp, rd, rs, imm};
        end
    endfunction

    function [31:0] Jtype;
        input [4:0] op, rp;
        input [21:0] off;
        begin
            Jtype = {op, rp, off};
        end
    endfunction

    // =================================================
    // Pretty printer
    // =================================================
    task dump;
        input [127:0] label;
        begin
            #1;
            $display("\n==============================");
            $display("%s", label);
            $display("------------------------------");
            $display("PC            = %0d", NPC_D - 1);
            $display("Instruction   = %h", Instruction_D);
            $display("opcode=%0d Rp=%0d Rd=%0d Rs=%0d Rt=%0d",
                Instruction_D[31:27],
                Instruction_D[26:22],
                Instruction_D[21:17],
                Instruction_D[16:12],
                Instruction_D[11:7]);

            $display("Rpzero_IDEX   = %b", RPzero_IDEX);
            $display("A_IDEX        = %h", A_IDEX);
            $display("B_IDEX        = %h", B_IDEX);
            $display("IMM_IDEX      = %h", IMM_IDEX);

            $display("RegWr=%b MemWr=%b MemRd=%b",
                RegWr_IDEX, MemWr_IDEX, MemRd_IDEX);

            $display("Rd2_IDEX      = %0d", Rd2_IDEX);

            $display("PCsrc=%b  KILL=%b", PCsrc, KILL);
            $display("PC_offset     = %h", PC_offset);
            $display("PC_regRs      = %h", PC_regRs);

            $display("Stall=%b disable_PC=%b disable_IR=%b",
                Stall, disable_PC, disable_IR);
        end
    endtask

    // =================================================
    // TEST SEQUENCE
    // =================================================
    initial begin
        clk = 0;
        NPC_D = 32'd100;

        Reg_toggle_defaults();

        // ---------------------------------------------
        // Basic execution & hazards
        // ---------------------------------------------
        Instruction_D = Rtype(5'd0,5'd6,5'd5,5'd1,5'd2);
        dump("T1: Normal ADD");

        Rd_EX = 5'd1; RegWrite_EX = 1;
        dump("T2: EX Forward");

        RegWrite_EX = 0; Rd_EX = 0;
        Rd_MEM = 5'd1; RegWrite_MEM = 1;
        dump("T3: MEM Forward");

        RegWrite_MEM = 0; Rd_MEM = 0;
        Rd_WB_pipe = 5'd1; RegWrite_WB = 1;
        dump("T4: WB Forward");

        RegWrite_WB = 0; Rd_WB_pipe = 0;
        Rd_EX = 5'd1; RegWrite_EX = 1; MemRead_EX = 1;
        dump("T5: Load-use Stall");

        RPzero_EX = 1;
        dump("T6: Killed Load (No Stall)");

        // ---------------------------------------------
        // Predication coverage
        // ---------------------------------------------
        Reg_toggle_defaults();
        Instruction_D = Rtype(5'd0,5'd0,5'd5,5'd1,5'd2);
        dump("T7: Rp = R0 (Unconditional)");

        Instruction_D = Rtype(5'd0,5'd6,5'd5,5'd1,5'd2);
        dump("T8: Rp != 0, Reg[Rp] != 0");

        Instruction_D = Rtype(5'd0,5'd4,5'd5,5'd1,5'd2);
        dump("T9: Rp != 0, Reg[Rp] = 0 (Killed)");

        // ---------------------------------------------
        // Control flow + predication
        // ---------------------------------------------
        Instruction_D = Jtype(5'd11,5'd4,22'd8);
        dump("T10: J predicated false");

        Instruction_D = Jtype(5'd11,5'd6,22'd8);
        dump("T11: J predicated true");

        Instruction_D = Jtype(5'd12,5'd6,22'd8);
        dump("T12: CALL predicated true");

        Instruction_D = Jtype(5'd12,5'd4,22'd8);
        dump("T13: CALL predicated false");

        #10;
        $stop;
    end

    // =================================================
    // Reset helper
    // =================================================
    task Reg_toggle_defaults;
        begin
            RegWr_WB_final = 0;
            Rd_WB = 0;
            BusW_WB = 0;

            Fwd_EX  = 32'hAAAA0001;
            Fwd_MEM = 32'hBBBB0002;
            Fwd_WB  = 32'hCCCC0003;

            Rd_EX = 0; Rd_MEM = 0; Rd_WB_pipe = 0;
            RegWrite_EX = 0; RegWrite_MEM = 0; RegWrite_WB = 0;
            MemRead_EX = 0;

            RPzero_EX = 0; RPzero_MEM = 0; RPzero_WB = 0;
        end
    endtask

endmodule