`include "ctrl_encode_def.v"

// 单周期/教学用：根据 NPCOp 选下一条 PC。本工程流水线 PLCPU 在 EX 内联计算 redirect_pc（见 PLCPU）
// ，模块实例化可有可无；语义与 jalr=(RA+IMM)&~1、分支/J 型类似。
module NPC(PC, RA, NPCOp, IMM, NPC);  // next pc module
   input  [31:0] PC;        // pc
   input  [31:0] RA;        // rs1 value (for jalr)
   input  [4:0]  NPCOp;     // next pc operation
   input  [31:0] IMM;       // immediate
   output reg [31:0] NPC;   // next pc
   
   wire [31:0] PCPLUS4;
   assign PCPLUS4 = PC + 4; // pc + 4
  
   always @(*) begin
        case (NPCOp)
            `NPC_PLUS4:  NPC = PCPLUS4;
            `NPC_BRANCH: NPC = PC+IMM;
            `NPC_JUMP:   NPC = PC+IMM;
            `NPC_JALR:   NPC = (RA + IMM) & 32'hffff_fffe;
  
            default:     NPC = PCPLUS4;
        endcase
    end // end always
   
endmodule
