`timescale 1ns/1ns 
module sccomp_tb();
   reg    clk, rstn;
   reg  [4:0] reg_sel;
   wire [31:0] reg_data;

   // instantiation of sccomp
   sccomp sccomp(.clk(clk), .rstn(rstn), .reg_sel(reg_sel), .reg_data(reg_data));

   // 默认加载排序测试程序。编译时加宏 TEST37 则加载 Test_37_Instr.dat（iverilog: -DTEST37；ModelSim: +define+TEST37）
   initial begin
`ifdef TEST37
      $readmemh("Test_37_Instr.dat", sccomp.U_imem.RAM);
`else
      $readmemh("riscv_sidascsorting_sim.dat", sccomp.U_imem.RAM);
`endif

      clk = 1;
      rstn = 0;
      #10 ;
      rstn = 1;
      reg_sel = 7;
   end
   
   always begin
      #(5) clk = ~clk;
   end
   
endmodule
