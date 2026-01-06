module mem_stage (
    input  wire        clk,
    input  wire        reset,

    input  wire        RegWrite_EX,
    input  wire        memW,
    input  wire        memR,
    input  wire [1:0]  WBdata_EX,

    input  wire [31:0] D,
    input  wire [31:0] ALUout_EX,
    input  wire [31:0] NPC3_EX,
    input  wire [4:0]  rd3_EX,

    output reg         RegWrite_MEM,
    output reg  [4:0]  Rd_MEM,
    output reg  [1:0]  WBdata_MEM,
    output reg  [31:0] ALUout_MEM,
    output reg  [31:0] MemOut_MEM,
    output reg  [31:0] NPC3_MEM
);

    wire [31:0] MemOut;

    DataMemo DM (
        .clk        (clk),
        .MemRd      (memR),
        .MemWr_final(memW),
        .Address    (ALUout_EX),
        .Data_in    (D),
        .Data_out   (MemOut)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            RegWrite_MEM <= 0;
            Rd_MEM       <= 0;
            WBdata_MEM   <= 0;
            ALUout_MEM   <= 0;
            MemOut_MEM   <= 0;
            NPC3_MEM     <= 0;
        end else begin
            RegWrite_MEM <= RegWrite_EX;
            Rd_MEM       <= rd3_EX;
            WBdata_MEM   <= WBdata_EX;
            ALUout_MEM   <= ALUout_EX;
            MemOut_MEM   <= MemOut;
            NPC3_MEM     <= NPC3_EX;
        end
end		   

endmodule
