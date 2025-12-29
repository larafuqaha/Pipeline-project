module WriteBack(
  input  [31:0] ALUout,
  input  [31:0] MemOut,
  input  [31:0] NPC3,
  input  [1:0]  WBdata,
  output [31:0] writeData
);
  assign writeData = (WBdata == 2'b00) ? ALUout :
                     (WBdata == 2'b01) ? MemOut :
                     (WBdata == 2'b10) ? NPC3 :
                     32'b0;
endmodule
