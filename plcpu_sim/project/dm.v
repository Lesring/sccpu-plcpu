// data memory（仿真）
// ----------------------------
// DM：同步写字、组合读；支持 lb/lh/lw/sb/sh/sw 等按字节/半字/字访问。
// ----------------------------
`include "ctrl_encode_def.v"
module dm(clk, DMWr, DMRe, DMCtrl, addr, din, dout);
   input          clk;
   input          DMWr;
   input          DMRe;
   input  [2:0]   DMCtrl;
   input  [31:0]  addr;
   input  [31:0]  din;
   output reg [31:0]  dout;
   
   reg [31:0] dmem[127:0];
   
   always @(posedge clk)
      if (DMWr) begin
         case (DMCtrl)
            `dm_word: dmem[addr[8:2]] <= din;
            `dm_halfword: begin
               if (addr[1] == 1'b0)
                  dmem[addr[8:2]][15:0] <= din[15:0];
               else
                  dmem[addr[8:2]][31:16] <= din[15:0];
            end
            `dm_byte: begin
               case (addr[1:0])
                  2'b00: dmem[addr[8:2]][7:0]   <= din[7:0];
                  2'b01: dmem[addr[8:2]][15:8]  <= din[7:0];
                  2'b10: dmem[addr[8:2]][23:16] <= din[7:0];
                  2'b11: dmem[addr[8:2]][31:24] <= din[7:0];
               endcase
            end
            default: dmem[addr[8:2]] <= din;
         endcase
         $write(" memaddr = %h, memdata = %h \n", addr[31:0], din);
      end
   
   //load
   always @(*) begin
      if (DMRe) begin
         case (DMCtrl)
            `dm_word: dout = dmem[addr[8:2]];
            `dm_halfword: begin
               if (addr[1] == 1'b0)
                  dout = {{16{dmem[addr[8:2]][15]}}, dmem[addr[8:2]][15:0]};
               else
                  dout = {{16{dmem[addr[8:2]][31]}}, dmem[addr[8:2]][31:16]};
            end
            `dm_halfword_unsigned: begin
               if (addr[1] == 1'b0)
                  dout = {16'b0, dmem[addr[8:2]][15:0]};
               else
                  dout = {16'b0, dmem[addr[8:2]][31:16]};
            end
            `dm_byte: begin
               case (addr[1:0])
                  2'b00: dout = {{24{dmem[addr[8:2]][7]}}, dmem[addr[8:2]][7:0]};
                  2'b01: dout = {{24{dmem[addr[8:2]][15]}}, dmem[addr[8:2]][15:8]};
                  2'b10: dout = {{24{dmem[addr[8:2]][23]}}, dmem[addr[8:2]][23:16]};
                  2'b11: dout = {{24{dmem[addr[8:2]][31]}}, dmem[addr[8:2]][31:24]};
               endcase
            end
            `dm_byte_unsigned: begin
               case (addr[1:0])
                  2'b00: dout = {24'b0, dmem[addr[8:2]][7:0]};
                  2'b01: dout = {24'b0, dmem[addr[8:2]][15:8]};
                  2'b10: dout = {24'b0, dmem[addr[8:2]][23:16]};
                  2'b11: dout = {24'b0, dmem[addr[8:2]][31:24]};
               endcase
            end
            default: dout = dmem[addr[8:2]];
         endcase
      end
   end
   
endmodule    
