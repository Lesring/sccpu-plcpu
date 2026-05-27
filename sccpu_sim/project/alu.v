`include "ctrl_encode_def.v"

module alu(A, B, ALUOp, C, Zero);
   input  signed [31:0] A, B;
   input         [4:0]  ALUOp;
   output signed [31:0] C;
   output Zero;  //condition flag: set if condition is true for B-type instruction
   
   reg [31:0] C;
   integer    i;
       
   always @( * ) begin
      case ( ALUOp )
      `ALUOp_lui:C=B;
      `ALUOp_add:C=A+B;
      `ALUOp_sub:C=A-B;  //and beq
      `ALUOp_bne:C=(A!=B)?32'b0:32'b1;
      `ALUOp_blt:C=($signed(A)<$signed(B))?32'b0:32'b1;
      `ALUOp_bge:C=($signed(A)>=$signed(B))?32'b0:32'b1;
      `ALUOp_bltu:C=($unsigned(A)<$unsigned(B))?32'b0:32'b1;
      `ALUOp_bgeu:C=($unsigned(A)>=$unsigned(B))?32'b0:32'b1;
      `ALUOp_slt:C=($signed(A)<$signed(B))?32'b1:32'b0;
      `ALUOp_sltu:C=($unsigned(A)<$unsigned(B))?32'b1:32'b0;
      `ALUOp_xor:C=A^B;
      `ALUOp_or:C=A|B;
      `ALUOp_and:C=A&B;
      // RV32 sll/srl：按无符号位图案移位（signed 端口下 >> 为算术右移，误用于 srl）
      `ALUOp_sll:C=$unsigned(A)<<B[4:0];
      `ALUOp_srl:C=$unsigned(A)>>B[4:0];
      `ALUOp_sra:C=$signed(A)>>>B[4:0];
      default: C=A;
      endcase
   end // end always
   
   assign Zero = (C == 32'b0);  

endmodule
    
