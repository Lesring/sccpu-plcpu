`include "ctrl_encode_def.v"
// ========================================================================
// PLCPU：五级流水线 RV32I（IF → ID → EX → MEM → WB）数据通路内核。
// 对外：inst_in/Data_in 来自 IM/DM；mem_w/mem_r/Pc/Data/Addr 为访存握手与地址。
// 内部含 load-use 阻塞、分支跳转 redirect、MEM/WB → EX/MEM 数据旁路。
// ========================================================================
module PLCPU(
    input      clk,            // clock
    input      reset,          // reset
    input [31:0]  inst_in,     // instruction
    input [31:0]  Data_in,     // data from data memory
    output [31:0] PC_out,     // PC address
    output [31:0] Addr_out,   // ALU output
    output [31:0] Data_out,   // data to data memory
    output    mem_w,          // output: memory write signal
    output    mem_r,          // output: memory read signal
    output [2:0] dm_ctrl      // data memory access type
);
    // --------- ID（译码级）组合输出：控制器 + 本条指令用到的通用信号 ---------
    wire        RegWrite;    // control signal to register write
    wire [5:0]  EXTOp;      // control signal to signed extension
    wire [4:0]  ALUOp;       // ALU opertion
    wire [4:0]  NPCOp;       // next PC operation
    wire [1:0]  WDSel;       // (register) write data selection
    wire [2:0]  DMCtrl;      // data memory access width/sign
   
    wire        ALUSrc;      // ALU source for B
    wire        Zero;        // ALU ouput zero

    wire [31:0] NPC;         // next PC

    wire [4:0]  rs1;          // rs
    wire [4:0]  rs2;          // rt
    wire [4:0]  rd;          // rd
    wire [6:0]  Op;          // opcode
    wire [6:0]  Funct7;       // funct7
    wire [2:0]  Funct3;       // funct3
    wire [11:0] Imm12;       // 12-bit immediate
    wire [31:0] Imm32;       // 32-bit immediate
    wire [19:0] IMM;         // 20-bit immediate (address)
    wire [4:0]  A3;          // register address for write
    reg [31:0] WD;           // register write data
    reg [31:0] memdata_wr;    // memory write data
    wire [31:0] RD1,RD2;         // register data specified by rs
    wire [31:0] A;            //operator for ALU A
    wire [31:0] B;           // operator for ALU B

	wire [4:0] iimm_shamt;
	wire [11:0] iimm,simm,bimm;
	wire [19:0] uimm,jimm;
	wire [31:0] immout;

	// --------- EX（执行段）：由上一条流水线寄存器 ID_EX 锁存后在 EX 使用 ---------
	wire [4:0] EX_rd;
    wire [4:0] EX_rs1;
    wire [4:0] EX_rs2;
    wire [31:0] EX_immout;
    wire [31:0] EX_RD1;
    wire [31:0] EX_RD2;
    wire        EX_RegWrite;//RFWr
    wire        EX_MemWrite;//DMWr
    wire        EX_MemRead;//DMRe
    wire [4:0] EX_ALUOp;
    wire [4:0] EX_NPCOp;
    wire       EX_ALUSrc;
    wire [1:0] EX_WDSel;
    wire [31:0] EX_pc;
    wire [2:0] EX_DMType;

	// --------- MEM（访存段）：由 EX_MEM 锁存：存数地址、写字、lw 读出等 ---------
	wire [4:0] MEM_rd;
	wire [4:0] MEM_rs2;
	wire [31:0] MEM_RD2;
	wire [31:0] MEM_aluout;
    wire [31:0] MEM_pc;
	wire        MEM_RegWrite;
	wire        MEM_MemWrite;
	wire        MEM_MemRead;
	wire [1:0] MEM_WDSel;
    wire [2:0] MEM_DMType;

    assign mem_w = MEM_MemWrite; // DM 写使能（本条在 MEM 段的指令是否为 sw）
    assign mem_r = MEM_MemRead;  // DM 读使能（本条是否为 lw）
    assign dm_ctrl = MEM_DMType;

    // --------- WB（写回段）：由 MEM_WB 锁存；真正写寄存器 RF 在此处生效 ---------
    wire [4:0] WB_rd;
    wire [31:0] WB_aluout;
    wire [31:0] WB_MemData;
    wire        WB_RegWrite;
    wire [1:0]  WB_WDSel;
	wire [31:0] WB_pc;
	
    wire[31:0] aluout;
    assign Addr_out = MEM_aluout;   // lw/sw 字节地址来自 MEM 段的 ALU 结果
	assign Data_out = memdata_wr;   // sw 写入 DM 的字（可由 WB 旁路）

	wire [31:0] instr;              // 当前译码用到的指令码（来自 IF/ID）

	// --------- 拆分指令 raw 字段，供 EXT/I/S/B/U/J 立即数选择与寄存器端口 ---------
	assign iimm_shamt=instr[24:20];
	assign iimm=instr[31:20];
	assign simm={instr[31:25],instr[11:7]};
	assign bimm={instr[31],instr[7],instr[30:25],instr[11:8]};
	assign uimm=instr[31:12];
	assign jimm={instr[31],instr[19:12],instr[20],instr[30:21]};
   
    assign Op = instr[6:0];  // instruction
    assign Funct7 = instr[31:25]; // funct7
    assign Funct3 = instr[14:12]; // funct3
    assign rs1 = instr[19:15];  // rs1
    assign rs2 = instr[24:20];  // rs2
    assign rd = instr[11:7];  // rd
    assign Imm12 = instr[31:20];// 12-bit immediate
    assign IMM = instr[31:12];  // 20-bit immediate
    
      
    wire ID_MemWrite; // DM 写：本条在 ID（严格说锁存后到 EX/MEM）是否访存写
    wire ID_MemRead;  // DM 读：本条是否 lw（影响 load-use 检测）

   // --------- 功能部件例化：控制器、PC、扩展、寄存器堆、EX 段的 ALU ---------
	ctrl U_ctrl(
	    .Op(Op), .Funct7(Funct7), .Funct3(Funct3), .Zero(Zero), 
		.RegWrite(RegWrite), .MemWrite(ID_MemWrite), .MemRead(ID_MemRead),
		.EXTOp(EXTOp), .ALUOp(ALUOp), .NPCOp(NPCOp), 
		.ALUSrc(ALUSrc), .WDSel(WDSel), .DMCtrl(DMCtrl)
 );
    // RF 时钟域与 WB 对齐；PC 时钟与流水寄存器相位取反(~clk)，与讲义 pl_reg 一拍对齐
	PC U_PC(.clk(~clk), .rst(reset), .NPC(NPC), .PC(PC_out) );
	// raw 立即数按 EXTOp 符号扩展 → ID 级使用的 32 位 immout
	EXT U_EXT(
		.iimm(iimm), .simm(simm), .bimm(bimm),
		.uimm(uimm), .jimm(jimm), .EXTOp(EXTOp), .immout(immout)
	);
	RF U_RF(
		.clk(clk), .rst(reset),
		.RFWr(WB_RegWrite), 
		.A1(rs1), .A2(rs2), .A3(WB_rd),
		.WD(WD),
		.RD1(RD1), .RD2(RD2)
	);
    // ALU 只在 EX：A/B 为旁路后操作数；结果供分支 Zero、EXE/MEM aluout、地址等
	alu U_alu(.A(A), .B(B), .ALUOp(EX_ALUOp), .C(aluout), .Zero(Zero));

    // --------- 冒险与数据通路拼装（NEXT PC、WB/MEM MUX、转发、再接流水线寄存器）---------

    // ---------- 流水线冒险处理：阻塞、冲刷、转发 ----------
    // load-use（数据冒险）：EX 级为 lw 且目的寄存器正好是当前 ID 级指令的源寄存器时，
    // lw 的数据尚在 MEM/WB，无法在 EX 用旁路修好，只能阻塞一拍：PC 不写 + IF/ID 保持 + EX 前行气泡。
    //
    // 控制冒险：分支/跳转在 EX 根据 ALU Zero 算出 EX_NPCOp，非顺序取指时 redirect=1：
    // 清空 IF_ID（避免错误指令混入），并向 ID_EX 打气泡冲刷紧跟在错的预测后面的那条。
    //
    // 转发（旁路）：EX 用 ALU 时，alu_in1/2 优先从 MEM/WB 未写回寄存器堆的“正确答案”选一；
    // store 写内存时同理用 wb_wd_forward 对齐 rs2。
    //
    wire load_use_stall;   // load-use：暂停取指一拍
    wire redirect;          // 控制流改变：改写 PC，冲刷流水前段
    wire [31:0] redirect_pc;
    reg  [31:0] alu_in1;    // ALU A：经 EX 级转发后的 rs1 值（可能来自 MEM/WB）
    reg  [31:0] alu_in2;    // ALU B：经 EX 级转发后的 rs2 值（同上）
    reg  [31:0] mem_wd_forward;  // MEM 级即将/已经得到的“寄存器写入数据”（旁路到 EX）
    reg  [31:0] wb_wd_forward;   // WB 级最终写回值（旁路到 EX 与 MEM 的 store 数据）

    assign load_use_stall = EX_MemRead && (EX_rd != 5'b0) &&
                            ((EX_rd == rs1) || (EX_rd == rs2));
    assign redirect = (EX_NPCOp != `NPC_PLUS4);
    // jalr 用已转发的 rs1（alu_in1）+ 立即数并对齐到低地址清零最低位；分支/jal 用 EX_pc + offset
    assign redirect_pc = (EX_NPCOp[2]) ? ((alu_in1 + EX_immout) & 32'hffff_fffe) :
                         (EX_pc + EX_immout);
    // stall 时不更新 PC（NPC=PC）；正常顺序 PC+4；跳转/分支走 redirect_pc
    assign NPC = redirect ? redirect_pc :
                 (load_use_stall ? PC_out : (PC_out + 4));

// WB：根据 WDSel 选写寄存器数据源（算术/lw/jal），输出到 WD 再在 RF 时钟边沿写入

always @(*)
begin
	case(WB_WDSel)
		`WDSel_FromALU: WD = WB_aluout;
		`WDSel_FromMEM: WD = WB_MemData;
		`WDSel_FromPC:  WD = WB_pc+4;  // jal/jalr write return address
        default:        WD = WB_aluout;
	endcase
end

// 按 WDSel 拼出 MEM 级“写寄存器”数据，供 EX 级旁路（离 EX 最近，优先级高于 WB）
always @(*)
begin
	case(MEM_WDSel)
		`WDSel_FromALU: mem_wd_forward = MEM_aluout;
		`WDSel_FromMEM: mem_wd_forward = Data_in;
		`WDSel_FromPC:  mem_wd_forward = MEM_pc+4;
        default:        mem_wd_forward = MEM_aluout;
	endcase
end

// 按 WDSel 拼出 WB 级写回数据，供 EX 第二优先旁路、以及 MEM store 数据旁路
always @(*)
begin
	case(WB_WDSel)
		`WDSel_FromALU: wb_wd_forward = WB_aluout;
		`WDSel_FromMEM: wb_wd_forward = WB_MemData;
		`WDSel_FromPC:  wb_wd_forward = WB_pc+4;
        default:        wb_wd_forward = WB_aluout;
	endcase
end

// EX 级转发 MUX：默认用 ID_EX 锁存的寄存器读；若更后级要写同一寄存器则用旁路
// 优先级 MEM > WB（更近的指令赢，避免用到过期值）
    always @(*) 
    begin
        alu_in1 = EX_RD1; // 无相关时：流水线寄存器中的 rs1
        if (MEM_RegWrite && (MEM_rd != 5'b0) && (MEM_rd == EX_rs1))
            alu_in1 = mem_wd_forward;
        else if (WB_RegWrite && (WB_rd != 5'b0) && (WB_rd == EX_rs1))
            alu_in1 = wb_wd_forward;

        alu_in2 = EX_RD2; // 无相关时：流水线寄存器中的 rs2
        if (MEM_RegWrite && (MEM_rd != 5'b0) && (MEM_rd == EX_rs2))
            alu_in2 = mem_wd_forward;
        else if (WB_RegWrite && (WB_rd != 5'b0) && (WB_rd == EX_rs2))
            alu_in2 = wb_wd_forward;
    end
    
    // Store：sw 的写数据在 MEM 级；若 rs2 刚在 WB 写回，需从 WB 旁路（MEM 无对 rs2 的第二写口）
    always @(*) 
    begin
        memdata_wr = MEM_RD2;
        if (WB_RegWrite && (WB_rd != 5'b0) && (WB_rd == MEM_rs2))
            memdata_wr = wb_wd_forward;
    end
        
    assign A = (EX_ALUOp == `ALUOp_auipc) ? EX_pc : alu_in1;
    assign B = (EX_ALUSrc) ? EX_immout : alu_in2; // I 型等：B 用立即数，不走 rs2 旁路

    // ========================================================================
    // 流水线寄存器：每级一拍锁存上一级；IF_ID 可 stall（保持）或 redirect（清）；ID_EX 可 bubble。
    // ========================================================================

    // IF/ID：[31:0]=取指对应 PC；[63:32]=指令字；供译码与后续流水使用

    wire [63:0] IF_ID_in;
    wire [63:0] IF_ID_out;
    // redirect：IF 已取新址，原 IF_ID 内容作废 -> 置 0（配合 EX 侧 bubble）
    // load_use_stall：保持 IF_ID 不变 -> ID 同一周期重复译码，等价暂停 IF/ID
    assign IF_ID_in = redirect ? 64'b0 :
                      (load_use_stall ? IF_ID_out : {inst_in, PC_out});

    assign instr = IF_ID_out[63:32];
    pl_reg #(.WIDTH(64))
    IF_ID
    (.clk(~clk), .rst(reset), 
    .in(IF_ID_in), .out(IF_ID_out));

    // ID/EX：锁存进入 EX 的 PC、rd/rs、立即数、RD1/2 及全部控制；bubble 时写全 0（nop），避免错误执行。
    wire id_bubble;
    wire [193:0] ID_EX_in;
    assign id_bubble = redirect | load_use_stall;
    assign ID_EX_in[31:0] = id_bubble ? 32'b0 : IF_ID_out[31:0];//PC
    assign ID_EX_in[36:32] = id_bubble ? 5'b0 : rd;
    assign ID_EX_in[41:37] = id_bubble ? 5'b0 : rs1;
    assign ID_EX_in[46:42] = id_bubble ? 5'b0 : rs2;
    assign ID_EX_in[78:47] = id_bubble ? 32'b0 : immout;
    assign ID_EX_in[110:79] = id_bubble ? 32'b0 : RD1;
    assign ID_EX_in[142:111] = id_bubble ? 32'b0 : RD2;
    assign ID_EX_in[143] = id_bubble ? 1'b0 : RegWrite;//RFWr
    assign ID_EX_in[144] = id_bubble ? 1'b0 : ID_MemWrite;//DMWr
    assign ID_EX_in[149:145] = id_bubble ? `ALUOp_nop : ALUOp;
    assign ID_EX_in[154:150] = id_bubble ? `NPC_PLUS4 : NPCOp;
    assign ID_EX_in[155] = id_bubble ? 1'b0 : ALUSrc;
    assign ID_EX_in[158:156] = id_bubble ? 3'b000 : DMCtrl;
    assign ID_EX_in[160:159] = id_bubble ? `WDSel_FromALU : WDSel;
    assign ID_EX_in[161] = id_bubble ? 1'b0 : ID_MemRead;
    assign ID_EX_in[193:162] = id_bubble ? 32'b0 : IF_ID_out[63:32];

    wire [193:0] ID_EX_out;
    //wire [31:0] EX_inst;
    assign EX_rd = ID_EX_out[36:32];
    assign EX_rs1 = ID_EX_out[41:37];
    assign EX_rs2 = ID_EX_out[46:42];
    assign EX_immout = ID_EX_out[78:47];
    assign EX_RD1 = ID_EX_out[110:79];
    assign EX_RD2 = ID_EX_out[142:111];
    assign EX_RegWrite = ID_EX_out[143];//RFWr
    assign EX_MemWrite = ID_EX_out[144];//DMWr
    assign EX_ALUOp = ID_EX_out[149:145];
    // 最后一 bit 与 ALU Zero 组合：条件分支是否成立由具体 ALU 操作（beq/bne/…）与 Zero 共同决定
    assign EX_NPCOp = {ID_EX_out[154:151], ID_EX_out[150] & Zero};
    assign EX_ALUSrc = ID_EX_out[155];
    assign EX_DMType = ID_EX_out[158:156];
    assign EX_WDSel = ID_EX_out[160:159];
    assign EX_MemRead = ID_EX_out[161];
    assign EX_pc = ID_EX_out[31:0];
    //assign EX_inst = ID_EX_out[193:162];
    
    pl_reg #(.WIDTH(194))
    ID_EX
    (.clk(~clk), .rst(reset), 
    .in(ID_EX_in), .out(ID_EX_out));

    
    // EX/MEM：ALU 结果、store 用第二源（已旁路）、写回选择与访存在 MEM 段的寄存器快照。
    wire [145:0] EX_MEM_in;
    assign EX_MEM_in[31:0] = ID_EX_out[31:0];//PC
    assign EX_MEM_in[36:32] = EX_rd;//rd
    assign EX_MEM_in[68:37] = alu_in2; // RD2：已含 EX 级转发后的 rs2，供 store 写入 DM
    assign EX_MEM_in[100:69] = aluout;
    assign EX_MEM_in[101] = EX_RegWrite;
    assign EX_MEM_in[102] = EX_MemWrite;
    assign EX_MEM_in[105:103] = EX_DMType;
    assign EX_MEM_in[107:106] = EX_WDSel;
    assign EX_MEM_in[112:108] = EX_rs2;
    assign EX_MEM_in[113] = EX_MemRead;
    assign EX_MEM_in[145:114] = ID_EX_out[193:162];

    wire [145:0] EX_MEM_out;
    assign MEM_pc = EX_MEM_out[31:0];
    assign MEM_rd = EX_MEM_out[36:32];
    assign MEM_RD2 = EX_MEM_out[68:37];
    assign MEM_aluout = EX_MEM_out[100:69];
    assign MEM_RegWrite = EX_MEM_out[101];
    assign MEM_MemWrite = EX_MEM_out[102];
    assign MEM_DMType = EX_MEM_out[105:103];
    assign MEM_WDSel = EX_MEM_out[107:106];
    assign MEM_rs2 = EX_MEM_out[112:108];
    assign MEM_MemRead = EX_MEM_out[113];  
    //assign MEM_inst = EX_MEM_out[145:114];  
 
    pl_reg #(.WIDTH(146))
    EX_MEM
    (.clk(~clk), .rst(reset), 
    .in(EX_MEM_in), .out(EX_MEM_out));

    // MEM/WB：合并 ALU 结果与 DM 读出（lw）；下一拍 WB 据此写寄存器或供旁路使用。
    wire [135:0] MEM_WB_in;
    wire [31:0] WB_inst;
    assign MEM_WB_in[31:0] = EX_MEM_out[31:0]; //PC
    assign MEM_WB_in[36:32] = MEM_rd;
    assign MEM_WB_in[68:37] = MEM_aluout;
    assign MEM_WB_in[100:69] = Data_in;  //data from dmem
    assign MEM_WB_in[101] = MEM_RegWrite;
    assign MEM_WB_in[103:102] = MEM_WDSel;
    assign MEM_WB_in[135:104] = EX_MEM_out[145:114];
 
    wire [135:0] MEM_WB_out;
    assign WB_pc = MEM_WB_out[31:0];
    assign WB_rd = MEM_WB_out[36:32];
    assign WB_aluout = MEM_WB_out[68:37];
    assign WB_MemData = MEM_WB_out[100:69];
    assign WB_RegWrite = MEM_WB_out[101];
    assign WB_WDSel = MEM_WB_out[103:102];
    assign WB_inst = MEM_WB_out[135:104];

    pl_reg #(.WIDTH(136))
    MEM_WB
    (.clk(~clk), .rst(reset), 
    .in(MEM_WB_in), .out(MEM_WB_out));

endmodule