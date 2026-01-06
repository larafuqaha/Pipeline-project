module WriteBack(
  input  [31:0] ALUout,
  input  [31:0] MemOut,
  input  [31:0] NPC3,
  input  [1:0]  WBdata,
  output reg [31:0] writeData
);

always @(*) begin	   

    case (WBdata)
        2'b00: writeData = ALUout;
        2'b01: writeData = MemOut;
        2'b10: writeData = NPC3;
        default: writeData = 32'b0;
    endcase
end

endmodule
