// 流水线寄存器（IF/ID、ID/EX …）：复位清零；正常运行时一拍锁存上一级输出。
// 阻塞时上一级把 in 设为 out（自保持），实现“流水线暂停且不丢状态”。
module pl_reg #(parameter WIDTH = 32)(
    input clk, rst, 
    input [WIDTH-1:0] in,
    output reg [WIDTH-1:0] out
    );
    
    always@(posedge clk, posedge rst)
      begin
          if(rst)
              out <= 0;
          else 
              out <= in;
      end
    
endmodule
