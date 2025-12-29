module WriteBack (input [31:0] ALUout,
    input [31:0] MemOut,
    input [31:0] NPC3,
    input [1:0] WBdata,     // 0: ALU_result, 1: MemOut


    output reg [31:0] writeData 
    );

    // MUX to choose between ALU result and memory output
    assign writeData = (WBdata == 2'b00) ?  ALUout:
                  (WBdata == 2'b01) ? NPC3:
                  (WBdata == 2'b10) ?  MemOut:
                 32'b0; // default fallback
endmodule