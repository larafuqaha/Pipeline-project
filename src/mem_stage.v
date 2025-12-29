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

    // Outputs to MEM/WB stage (pipeline-latched)
    output reg         RegWrite_MEM,
    output reg [4:0]   Rd3_MEM,
    output reg [31:0]  WBdata_out
);

    // Output from Data Memory
    wire [31:0] memoOut;

    // Data Memory
    DataMemo memory_inst (
        .clk      (clk),
        .MemRd  (memR),
        .MemWr_final (memW),
		
        .Address  (ALUout[5:0])

        ,
        .Data_in  (D),
        .Data_out (memoOut)
    );

    // MEM/WB pipeline register (everything latched on clk)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            RegWrite_MEM <= 1'b0;
            Rd3_MEM      <= 5'd0;
            WBdata_out   <= 32'd0;
        end else begin
            RegWrite_MEM <= RegWrite_EX;
            Rd3_MEM      <= rd3;

            case (WBdata)
                2'b00: WBdata_out <= ALUout;
                2'b01: WBdata_out <= memoOut;
                2'b10: WBdata_out <= NPC3;
                default: WBdata_out <= 32'd0;
            endcase
        end
    end

endmodule