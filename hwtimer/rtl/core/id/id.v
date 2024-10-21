`include "defines.v"

module id(
  input wire rst_i,

  //from if_id
  input wire[`ADDR_WIDTH-1:0] inst_addr_i, // pc
  input wire[`DATA_WIDTH-1:0] inst_i,

  //from regfile
  input wire[`RDATA_WIDTH-1:0] reg1_rdata_i,
  input wire[`RDATA_WIDTH-1:0] reg2_rdata_i,

// 為了解決 RAW 的 DATA HAZARD ( 相鄰兩個指令和相隔一個指令 )
// 在第二條或第三條指令的 ID 階段需要前面的 EXE ( 相隔一個指令 ) 以及前面 MEM ( 相鄰兩個指令 )
// 直接 input ( 地址 數據 enable ) 進 ID 裡面 

//from exe
  input wire[`RADDR_WIDTH-1:0] exe_reg_waddr_i,
  input wire[`RDATA_WIDTH-1:0] exe_reg_wdata_i,
  input wire exe_reg_we_i,

  //from mem
  input wire[`RADDR_WIDTH-1:0] mem_reg_waddr_i,
  input wire[`RDATA_WIDTH-1:0] mem_reg_wdata_i,
  input wire mem_reg_we_i,

  //from id_exe (load use)
  input wire[`RADDR_WIDTH-1:0] rd_i, 
  input wire inst_is_load_i,

  // to regfile
  output reg[`RADDR_WIDTH-1:0] reg1_raddr_o,
  output reg[`RADDR_WIDTH-1:0] reg2_raddr_o,
  output reg reg1_re_o,
  output reg reg2_re_o,

  //to id_exe
  output reg[`DATA_WIDTH-1:0] inst_o,  //繼續傳指令下去
  output reg[`RDATA_WIDTH-1:0] op1_o,
  output reg[`RDATA_WIDTH-1:0] op2_o,   //兩個讀出來的資料
  output reg[`RADDR_WIDTH-1:0] reg_waddr_o, //暫存器位址
  output reg reg_we_o,         //enable

  //to id_exe (type-jb)
  output reg[`ADDR_WIDTH-1:0] inst_addr_o, // 就是 pc

  //to ctrl
  output reg stallreq_o,

  // for csr
    // to id_exe
  output reg csr_we_o,
  output reg[`CSR_ADDR_WIDTH-1:0] csr_addr_o,

  //for exception
  output reg[`DATA_WIDTH-1:0] exception_o
);

assign exception_o = {29'b0, except_ecall, except_mret};
assign inst_addr_o = inst_addr_i;


// 要接線所以先定義 wire , 再把線接上

reg[`RDATA_WIDTH-1:0] op1_o_final;       
reg[`RDATA_WIDTH-1:0] op2_o_final;       

wire[6:0] opcode = inst_i[6:0];
wire[`RADDR_WIDTH-1:0] i_reg1_raddr_o;
wire[`RADDR_WIDTH-1:0] i_reg2_raddr_o;
wire i_reg1_re_o;
wire i_reg2_re_o;
wire[`RDATA_WIDTH-1:0] i_op1_o;
wire[`RDATA_WIDTH-1:0] i_op2_o;
wire i_reg_we_o;
wire[`RADDR_WIDTH-1:0] i_reg_waddr_o;
wire[4:0] rd = inst_i[11:7];
wire[4:0] rs1 = inst_i[19:15];
wire[4:0] rs2 = inst_i[24:20];
wire[2:0] funct3 = inst_i[14:12];
wire[6:0] funct7 = inst_i[31:25];
reg except_mret;
reg except_ecall;
id_type_i inst_type_i(
    .inst_i(inst_i),
    .reg1_rdata_i(reg1_rdata_i),
    .reg2_rdata_i(reg2_rdata_i),
    .reg1_raddr_o(i_reg1_raddr_o),
    .reg2_raddr_o(i_reg2_raddr_o),
    .reg1_re_o(i_reg1_re_o),
    .reg2_re_o(i_reg2_re_o),
    .op1_o(i_op1_o),
    .op2_o(i_op2_o),
    .reg_we_o(i_reg_we_o),
    .reg_waddr_o(i_reg_waddr_o)
  );

wire[`RADDR_WIDTH-1:0] r_reg1_raddr_o;
wire[`RADDR_WIDTH-1:0] r_reg2_raddr_o;
wire r_reg1_re_o;
wire r_reg2_re_o;
wire[`RDATA_WIDTH-1:0] r_op1_o;
wire[`RDATA_WIDTH-1:0] r_op2_o;
wire r_reg_we_o;
wire[`RADDR_WIDTH-1:0] r_reg_waddr_o;

id_type_r_m inst_type_r_m(
    .inst_i(inst_i),
    .reg1_rdata_i(reg1_rdata_i),
    .reg2_rdata_i(reg2_rdata_i),
    .reg1_raddr_o(r_reg1_raddr_o),
    .reg2_raddr_o(r_reg2_raddr_o),
    .reg1_re_o(r_reg1_re_o),
    .reg2_re_o(r_reg2_re_o),
    .op1_o(r_op1_o),
    .op2_o(r_op2_o),
    .reg_we_o(r_reg_we_o),
    .reg_waddr_o(r_reg_waddr_o)
  );

// type-u 所需
wire[4:0] rd = inst_i[11:7];

always @(*) begin
    if (rst_i == 1) begin
        inst_o = `NOP;
        reg1_raddr_o = `ZERO_REG;
        reg2_raddr_o = `ZERO_REG;
        reg1_re_o = `READ_DISABLE;
        reg2_re_o = `READ_DISABLE;
        reg_we_o = `WRITE_DISABLE;
        reg_waddr_o = `ZERO_REG;
        op1_o_final = `ZERO;
        op2_o_final = `ZERO;
        inst_addr_o = `ZERO_REG;
        csr_we_o = `WRITE_DISABLE;
        csr_addr_o = {12'b0};
        except_mret = 1'b0;
        except_ecall = 1'b0;
    end else begin
        case (opcode)
            `INST_TYPE_I:begin
              inst_o = inst_i;
              reg1_raddr_o = i_reg1_raddr_o;
              reg2_raddr_o = i_reg2_raddr_o;
              reg1_re_o = i_reg1_re_o;
              reg2_re_o = i_reg2_re_o;
              op1_o_final = i_op1_o;
              op2_o_final = i_op2_o;
              reg_we_o = i_reg_we_o;
              reg_waddr_o = i_reg_waddr_o;
              inst_addr_o = `ZERO_REG;
              csr_we_o = `WRITE_DISABLE;
              csr_addr_o = {12'b0};
              except_mret = 1'b0;
              except_ecall = 1'b0;
            end
            `INST_TYPE_R_M:begin
              inst_o = inst_i;
              reg1_raddr_o = r_reg1_raddr_o;
              reg2_raddr_o = r_reg2_raddr_o;
              reg1_re_o = r_reg1_re_o;
              reg2_re_o = r_reg2_re_o;
              op1_o_final = r_op1_o;
              op2_o_final = r_op2_o;
              reg_we_o = r_reg_we_o;
              reg_waddr_o = r_reg_waddr_o;
              inst_addr_o = `ZERO_REG;
              csr_we_o = `WRITE_DISABLE;
              csr_addr_o = {12'b0};
              except_mret = 1'b0;
              except_ecall = 1'b0;
            end
            `INST_TYPE_LUI:begin
              inst_o = inst_i;
              reg1_raddr_o = `ZERO_REG;
              reg2_raddr_o = `ZERO_REG;
              reg1_re_o = `READ_DISABLE;
              reg2_re_o = `READ_DISABLE;
              op1_o_final = {inst_i[31:12],12'b0};
              op2_o_final = `ZERO;
              reg_we_o = `WRITE_ENABLE;
              reg_waddr_o = rd;
              inst_addr_o = `ZERO_REG;
              csr_we_o = `WRITE_DISABLE;
              csr_addr_o = {12'b0};
              except_mret = 1'b0;
              except_ecall = 1'b0;
            end
            `INST_TYPE_AUIPC:begin
              inst_o = inst_i;
              reg1_raddr_o = `ZERO_REG;
              reg2_raddr_o = `ZERO_REG;
              reg1_re_o = `READ_DISABLE;
              reg2_re_o = `READ_DISABLE;
              op1_o_final = inst_addr_i;
              op2_o_final = {inst_i[31:12],12'b0};
              reg_we_o = `WRITE_ENABLE;
              reg_waddr_o = rd;
              inst_addr_o = `ZERO_REG;
              csr_we_o = `WRITE_DISABLE;
              csr_addr_o = {12'b0};
              except_mret = 1'b0;
              except_ecall = 1'b0;
            end
            `INST_TYPE_S:begin
              reg_we_o = `WRITE_DISABLE;    // type s 不需要寫 rd (目標暫存器)
              reg_waddr_o = `ZERO_REG;
              reg1_raddr_o = rs1;
              reg2_raddr_o = rs2;
              reg1_re_o = `READ_ENABLE;
              reg2_re_o = `READ_ENABLE;
              op1_o_final = reg1_rdata_i;
              op2_o_final = reg2_rdata_i;
              inst_o = inst_i;
              inst_addr_o = `ZERO_REG;
              csr_we_o = `WRITE_DISABLE;
              csr_addr_o = {12'b0};
              except_mret = 1'b0;
              except_ecall = 1'b0;
            end
            `INST_TYPE_L:begin
              reg_we_o = `WRITE_ENABLE;
              reg_waddr_o = rd;
              reg1_raddr_o = rs1;
              reg2_raddr_o = `ZERO_REG;
              reg1_re_o = `READ_ENABLE;
              reg2_re_o = `READ_DISABLE;
              op1_o_final = reg1_rdata_i;
              op2_o_final = `ZERO;
              inst_o = inst_i;
              inst_addr_o = `ZERO_REG;
              csr_we_o = `WRITE_DISABLE;
              csr_addr_o = {12'b0};
              except_mret = 1'b0;
              except_ecall = 1'b0;
            end

            `INST_TYPE_JAL:begin
              reg_we_o = `WRITE_ENABLE;
              reg_waddr_o = rd;
              inst_addr_o = inst_addr_i;
              inst_o = inst_i;
              reg1_raddr_o = `ZERO_REG;
              reg2_raddr_o = `ZERO_REG;
              reg1_re_o = `READ_DISABLE;
              reg2_re_o = `READ_DISABLE;
              op1_o_final = `ZERO;
              op2_o_final = `ZERO;
              csr_we_o = `WRITE_DISABLE;
              csr_addr_o = {12'b0};
              except_mret = 1'b0;
              except_ecall = 1'b0;
            end
            `INST_TYPE_JALR:begin
              reg_we_o = `WRITE_ENABLE;
              reg_waddr_o = rd;
              inst_addr_o = inst_addr_i;
              reg1_raddr_o = rs1;
              reg2_raddr_o = `ZERO_REG;
              reg1_re_o = `READ_ENABLE;
              reg2_re_o = `READ_DISABLE;
              op1_o_final = reg1_rdata_i;
              op2_o_final = `ZERO;
              inst_o = inst_i;
              csr_we_o = `WRITE_DISABLE;
              csr_addr_o = {12'b0};
              except_mret = 1'b0;
              except_ecall = 1'b0;
            end
            `INST_TYPE_B:begin
              reg_we_o = `WRITE_DISABLE;
              reg_waddr_o = `ZERO_REG;
              reg1_raddr_o = rs1;
              reg2_raddr_o = rs2;
              reg1_re_o = `READ_ENABLE;
              reg2_re_o = `READ_ENABLE;
              op1_o_final = reg1_rdata_i;
              op2_o_final = reg2_rdata_i;
              inst_o = inst_i;
              inst_addr_o = inst_addr_i;
              csr_we_o = `WRITE_DISABLE;
              csr_addr_o = {12'b0};
              except_mret = 1'b0;
              except_ecall = 1'b0;
            end
            `INST_TYPE_SYSTEM:begin   ////csr, ecall, ebreak, wfi
              reg2_raddr_o = `ZERO_REG;
              reg2_re_o = `READ_DISABLE;
              op2_o_final = `ZERO;
              inst_o = inst_i;
              inst_addr_o = inst_addr_i;
              case(funct3)
                `INST_CSRRW , `INST_CSRRS , `INST_CSRRC: begin
                  reg1_raddr_o = rs1;
                  op1_o_final = reg1_rdata_i;
                  reg1_re_o = `READ_ENABLE;
                  reg_we_o = `WRITE_ENABLE;
                  reg_waddr_o = rd;
                  csr_we_o = `WRITE_ENABLE;
                  csr_addr_o = inst_i[31:20];
                end
                `INST_CSRRWI,`INST_CSRRSI, `INST_CSRRCI : begin
                  reg1_raddr_o = `ZERO_REG;
                  op1_o_final = {{27{1'b0}},inst_i[19:15]};
                  reg1_re_o = `READ_DISABLE;
                  reg_we_o = `WRITE_ENABLE;
                  reg_waddr_o = rd;
                  csr_we_o = `WRITE_ENABLE;
                  csr_addr_o = inst_i[31:20];
                end
                `INST_CSR_PRIV : begin
                  if( (funct7==7'b0011000) && (rs2 == 5'b00010)) begin  //mret
                      // {00110, 00, rs2(00010), rs1(00000), funct3(000), rd(00000), opcode = 7b'1110011 }
                      // Return from traps in M-mode, and MRET copies MPIE into MIE, then sets MPIE.
                      // mret  :   ExceptionReturn(Machine)
                      except_mret = 1'b1;
                  end
                  if((funct7==7'b0000000) &&  (rs2 == 5'b00000))  begin //ecall
                      // {00000, 00, rs2(00000), rs1(00000), funct3(000), rd(00000), opcode = 7b'1110011 }
                      // Make a request to the supporting execution environment.
                      // When executed in U-mode, S-mode, or M-mode, it generates an
                      // environment-call-from-U-mode exception, environment-call-from-S-mode
                      // exception, or environment-call-from-M-mode exception, respectively, and
                      // performs no other operation.
                      // ecall  :   RaiseException(EnvironmentCall)
                      except_ecall= 1'b1;
                  end
                end
                default:begin
                  inst_o = `NOP;
                  reg1_raddr_o = `ZERO_REG;
                  reg2_raddr_o = `ZERO_REG;
                  reg1_re_o = `READ_DISABLE;
                  reg2_re_o = `READ_DISABLE;
                  reg_we_o = `WRITE_DISABLE;
                  reg_waddr_o = `ZERO_REG;
                  op1_o_final = `ZERO;
                  op2_o_final = `ZERO;
                  inst_addr_o = `ZERO_REG;
                  csr_we_o = `WRITE_DISABLE;
                  csr_addr_o = {12'b0};
                end
            endcase
            end
            default:begin
              inst_o = `NOP;
              reg1_raddr_o = `ZERO_REG;
              reg2_raddr_o = `ZERO_REG;
              reg1_re_o = `READ_DISABLE;
              reg2_re_o = `READ_DISABLE;
              reg_we_o = `WRITE_DISABLE;
              reg_waddr_o = `ZERO_REG;
              op1_o_final = `ZERO;
              op2_o_final = `ZERO;
              inst_addr_o = `ZERO_REG;
              csr_we_o = `WRITE_DISABLE;
              csr_addr_o = {12'b0};
            end//default
        endcase
    end//if
end//always


//determine op1_o
always @(*) begin
  if (rst_i == 1)begin
    op1_o = `ZERO;

// 如果 ID 要讀 reg1 同時 EXE 要寫入 reg1 而且讀的位址和寫的位址相同 那就直接將訊號給 ID  
  end else if(reg1_re_o == `READ_ENABLE && exe_reg_we_i == `WRITE_ENABLE && exe_reg_waddr_i == reg1_raddr_o )begin
    op1_o = exe_reg_wdata_i;
  end else if(reg1_re_o == `READ_ENABLE && mem_reg_we_i == `WRITE_ENABLE && mem_reg_waddr_i == reg1_raddr_o )begin
    op1_o = mem_reg_wdata_i;

  end else begin
    op1_o = op1_o_final;
  end
  end

//determine op2_o
always @(*) begin
  if (rst_i == 1)begin
    op2_o = `ZERO;
// 如果 ID 要讀 reg1 同時 EXE 要寫入 reg1 而且讀的位址和寫的位址相同 那就直接將訊號給 ID  
  end else if(reg2_re_o == `READ_ENABLE && exe_reg_we_i == `WRITE_ENABLE && exe_reg_waddr_i == reg2_raddr_o )begin
    op2_o = exe_reg_wdata_i;
  end else if(reg2_re_o == `READ_ENABLE && mem_reg_we_i == `WRITE_ENABLE && mem_reg_waddr_i == reg2_raddr_o )begin
    op2_o = mem_reg_wdata_i;

  end else begin
    op2_o = op2_o_final;
  end
end

wire is_load_hazard;
assign is_load_hazard = (inst_is_load_i == 1'b1 && (rs1 == rd_i || rs2 == rd_i));

always @(*)begin
  if(is_load_hazard == 1)begin
    stallreq_o = 1'b1;
  end else begin
    stallreq_o = 1'b0;
  end
end

endmodule