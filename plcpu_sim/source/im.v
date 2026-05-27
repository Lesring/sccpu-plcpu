// instruction memory（仿真）
// ----------------------------
// IM：组合读 dout=RAM[addr]；顶层用 PC[31:2] 寻址字对齐指令。
// ----------------------------
module im(input  [31:2]  addr, output [31:0] dout );
  reg  [31:0] RAM[255:0];

  assign dout = RAM[addr]; // word aligned
endmodule  
