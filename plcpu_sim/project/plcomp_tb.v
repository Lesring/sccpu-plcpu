`timescale 1ns/1ns 
// ----------------------------
// plcomp 仿真 testbench：加载 IM 初值、产生复位与周期时钟，观察 PLCPU+DM+IM 联仿。
// ----------------------------
module plcomp_tb();
  reg   clk, rstn;
  integer i=0;  //for debug

  // instantiation of plcomp
  plcomp plcomp(clk, rstn);
  
  // 默认 riscv_sidascsorting_sim.dat
  // TEST30 -> Test_30_Instr.dat；TEST37 -> Test_37_Instr.dat
  initial begin
`ifdef TEST37
    $readmemh("Test_37_Instr.dat", plcomp.U_imem.RAM);
`elsif TEST30
    $readmemh("Test_30_Instr.dat", plcomp.U_imem.RAM);
`else
    $readmemh("riscv_sidascsorting_sim.dat", plcomp.U_imem.RAM);
`endif
    clk = 0;
    rstn = 1;
    #50 ;
    rstn = 0;
  end
  
  always begin
    #(5) clk = ~clk;
  end

  always @(posedge clk) begin   //for debug
       i=i+1;
       if (clk) $write("\n cycle=%d, IF_PC=%h, IF_ins=%h, ", i, plcomp.PC, plcomp.instr );
       if (plcomp.U_PLCPU.U_RF.RFWr && plcomp.U_PLCPU.U_RF.A3) $write("x%d = %h  ", plcomp.U_PLCPU.U_RF.A3, plcomp.U_PLCPU.U_RF.WD) ;
  end
      
endmodule
