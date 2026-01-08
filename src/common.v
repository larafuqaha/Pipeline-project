// mux 2x1
module mux2 #(parameter W=32) (
  input  wire [W-1:0] a,
  input  wire [W-1:0] b,
  input  wire         s,
  output wire [W-1:0] y
);
  assign y = s ? b : a;
endmodule

// mux 3x1
module mux3 #(parameter W=32) (
  input  wire [W-1:0] a,   // 2'b00
  input  wire [W-1:0] b,   // 2'b01
  input  wire [W-1:0] c,   // 2'b10
  input  wire [1:0]   s,
  output reg  [W-1:0] y
);
  always @(*) begin
    case (s)
      2'b00: y = a;
      2'b01: y = b;
      2'b10: y = c;
      default: y = a;
    endcase
  end
endmodule

// mux 4x1
module mux4 #(parameter W=32) (
    input  wire [W-1:0] d0,
    input  wire [W-1:0] d1,
    input  wire [W-1:0] d2,
    input  wire [W-1:0] d3,
    input  wire [1:0]   sel,  
    output reg  [W-1:0] y
);
    always @(*) begin
        case (sel)
            2'b00: y = d0;
            2'b01: y = d1;
            2'b10: y = d2;
            2'b11: y = d3;
            default: y = d0;
        endcase
    end
endmodule

// synchronizes an external asynchronous reset to the clock
// to ensure clean glitch free reset for pipeline registers.
module reset_sync (
  input  wire clk,
  input  wire rst_async,
  output wire rst_sync
);
  reg r1, r2;
  always @(posedge clk or posedge rst_async) begin
    if (rst_async) begin
      r1 <= 1'b1;
      r2 <= 1'b1;
    end else begin
      r1 <= 1'b0;
      r2 <= r1;
    end
  end
  assign rst_sync = r2;
endmodule


module Hazard_Unit (
    input  [4:0] Rs, Rt,
    input  [4:0] Rd_EX, Rd_MEM, Rd_WB,	
	input UseRs, UseRt,

    input        RegWrite_EX,
    input        RegWrite_MEM,
    input        RegWrite_WB,

    input        MemRead_EX,

    input        RPzero_EX,     // 1 = killed, 0 = executes
    input        RPzero_MEM,
    input        RPzero_WB,

    output reg [1:0] ForwardA,
    output reg [1:0] ForwardB,
    output reg       Stall
);

    // -------------------------------------------------
    // Forwarding logic
    // -------------------------------------------------
    always @(*) begin
        ForwardA = 2'b00;
        ForwardB = 2'b00;

        // ---------- Forward A (Rs) ----------
        if (RegWrite_EX  && !RPzero_EX  &&
            (Rd_EX  != 5'd0) && (Rd_EX  != 5'd30) && (Rd_EX  == Rs))
            ForwardA = 2'b01;
        else if (RegWrite_MEM && !RPzero_MEM &&
                 (Rd_MEM != 5'd0) && (Rd_MEM != 5'd30) && (Rd_MEM == Rs))
            ForwardA = 2'b10;
        else if (RegWrite_WB  && !RPzero_WB  &&
                 (Rd_WB  != 5'd0) && (Rd_WB  != 5'd30) && (Rd_WB  == Rs))
            ForwardA = 2'b11;

        // ---------- Forward B (Rt) ----------
        if (RegWrite_EX  && !RPzero_EX  &&
            (Rd_EX  != 5'd0) && (Rd_EX  != 5'd30) && (Rd_EX  == Rt))
            ForwardB = 2'b01;
        else if (RegWrite_MEM && !RPzero_MEM &&
                 (Rd_MEM != 5'd0) && (Rd_MEM != 5'd30) && (Rd_MEM == Rt))
            ForwardB = 2'b10;
        else if (RegWrite_WB  && !RPzero_WB  &&
                 (Rd_WB  != 5'd0) && (Rd_WB  != 5'd30) && (Rd_WB  == Rt))
            ForwardB = 2'b11;
    end

    // -------------------------------------------------
    // Load-use stall detection
    // -------------------------------------------------
    always @(*) begin
        if (MemRead_EX &&
            !RPzero_EX &&
            (Rd_EX != 5'd0) &&
            (Rd_EX != 5'd30) &&   
            ((UseRs && Rd_EX == Rs) || (UseRt && Rd_EX == Rt)))
            Stall = 1'b1;
        else
            Stall = 1'b0;
    end

endmodule
