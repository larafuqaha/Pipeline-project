module mem_stage (
    input  wire        clk,
    input  wire        reset,

    input  wire        RegWrite_EX,
    input  wire        memW,
    input  wire        memR,
    input  wire [1:0]  WBdata,

    input  wire [31:0] D,
    input  wire [31:0] ALUout,
    input  wire [31:0] NPC3,
    input  wire [4:0]  rd3,

    output reg         RegWrite_MEM,
    output reg  [4:0]  Rd3_MEM,
    output reg  [31:0] WBdata_out
);

    wire [31:0] MemOut;

    // Data memory
    DataMemo DM (
        .clk        (clk),
        .MemRd      (memR),
        .MemWr_final(memW),
        .Address    (ALUout),
        .Data_in    (D),
        .Data_out   (MemOut)
    );

    // Writeback mux
    wire [31:0] WB_mux_out;
    assign WB_mux_out =
        (WBdata == 2'b00) ? ALUout :
        (WBdata == 2'b01) ? MemOut :
        (WBdata == 2'b10) ? NPC3   :
                            32'b0;

    // MEM/WB pipeline register
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            RegWrite_MEM <= 1'b0;
            Rd3_MEM      <= 5'd0;
            WBdata_out   <= 32'b0;
        end else begin
            RegWrite_MEM <= RegWrite_EX;
            Rd3_MEM      <= rd3;
            WBdata_out   <= WB_mux_out;
        end
    end

endmodule
