`include "ctrl_encode_def.v"
// ----------------------------
// 立即数扩展：按 EXTOp 在 I/S/B/U/J/shamt 等形式中选一路，输出符号扩展后的 immout。
// ----------------------------
module EXT( 
    input	[11:0]			iimm, //instr[31:20], 12 bits
	input	[11:0]			simm, //instr[31:25, 11:7], 12 bits
	input	[11:0]			bimm, //instr[31], instr[7], instr[30:25], instr[11:8]
	input	[19:0]			uimm, // U type
	input	[19:0]			jimm, // J type
	input	[5:0]			EXTOp,

	output	reg [31:0] 	    immout
	);

always  @(*)
	 case (EXTOp)
        `EXT_CTRL_ITYPE_SHAMT: immout <= {27'b0, iimm[4:0]};
		`EXT_CTRL_ITYPE:	immout <= {{20{iimm[11]}}, iimm[11:0]};
		`EXT_CTRL_STYPE:	immout <= {{20{simm[11]}}, simm[11:0]};
		`EXT_CTRL_BTYPE:    immout <= {{19{bimm[11]}}, bimm[11:0], 1'b0};
		`EXT_CTRL_UTYPE:	immout <= {uimm[19:0], 12'b0};     //???????????12??0
		`EXT_CTRL_JTYPE:	immout <= {{11{jimm[19]}}, jimm[19:0], 1'b0};
		default:	        immout <= 32'b0;
	 endcase
       
endmodule
