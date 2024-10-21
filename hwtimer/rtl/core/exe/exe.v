`include "defines.v"

module exe(
    input wire rst_i,
    input wire clk_i,

// from id_exe
    input wire[`DATA_WIDTH-1:0] op1_i,
    input wire[`DATA_WIDTH-1:0] op2_i,
    input wire reg_we_i,
    input wire[`RADDR_WIDTH-1:0] reg_waddr_i,
    input wire[`DATA_WIDTH-1:0] inst_i,
    input wire[`ADDR_WIDTH-1:0] inst_addr_i,

// to exe_mem
    output reg[`RADDR_WIDTH-1:0] reg_waddr_o,
    output reg reg_we_o,
    output reg[`RDATA_WIDTH-1:0] reg_wdata_o,

    output reg[`ADDR_WIDTH-1:0] mem_addr_o,
    output reg[`DATA_WIDTH-1:0] mem_data_o,
    output reg[3:0] mem_op_o,
    output reg mem_we_o,
    output reg[`ADDR_WIDTH-1:0] inst_addr_o, // 就是 pc

// to ctrl
    output reg[`ADDR_WIDTH-1:0] jump_addr_o,
    output reg jump_we_o,
    output reg stallreq_o,

///csr
    // from id_exe , to exe_mem
    input wire csr_we_i,
    input wire[`CSR_ADDR_WIDTH-1:0] csr_addr_i,
    output reg csr_we_o,
    output reg[`CSR_ADDR_WIDTH-1:0] csr_waddr_o,
    output reg[`DATA_WIDTH-1:0] csr_wdata_o,

    // from or to csrfile
    input wire[`DATA_WIDTH-1:0] csr_rdata_i,
    output reg[`CSR_ADDR_WIDTH-1:0] csr_raddr_o,

    //for csr data read forward
    //from mem
    input wire                          mem_csr_we_i,
    input wire[`CSR_ADDR_WIDTH-1:0]     mem_csr_waddr_i,
    input wire[`DATA_WIDTH-1:0]         mem_csr_wdata_i,

//for exception
    input wire[`DATA_WIDTH-1:0]         exception_i,
    output reg[`DATA_WIDTH-1:0]         exception_o

);
//for interrupt ctrl
assign inst_addr_o = inst_addr_i;
assign exception_o = exception_i;
    
// exe 獲得指令去抓取分割出 funct7 funct3 opcode
// wire[6:0] funct7 = inst_i[31:25];
// wire[2:0] funct3 = inst_i[14:12];
wire[6:0] opcode = inst_i[6:0];

wire i_reg_we_o;
wire[`RDATA_WIDTH-1:0] i_reg_wdata_o;
exe_type_i exe_type_i0(
    .rst_i(rst_i),
    .op1_i(op1_i),
    .op2_i(op2_i),
    .inst_i(inst_i),
    .reg_wdata_o(i_reg_wdata_o),
    .reg_we_o(i_reg_we_o)
);

wire r_reg_we_o;
wire[`RDATA_WIDTH-1:0] r_reg_wdata_o;
wire mult_div_stall;

// assign  stallreq_o = mult_div_stall;  //只有mult, div指令才需要停止流水线

exe_type_r_m exe_type_r_m0(
    .rst_i(rst_i),
    .clk_i(clk_i),
    .op1_i(op1_i),
    .op2_i(op2_i),
    .inst_i(inst_i),
    .reg_wdata_o(r_reg_wdata_o),
    .reg_we_o(r_reg_we_o),
    .stall_o(mult_div_stall)
);

wire s_reg_we_o;
wire [`RDATA_WIDTH-1:0] s_reg_wdata_o;

wire [`ADDR_WIDTH-1:0] s_mem_addr_o;
wire [`DATA_WIDTH-1:0] s_mem_data_o;
wire [3:0] s_mem_op_o;
wire s_mem_we_o;

exe_type_s_l exe_type_s_l0(
    .rst_i(rst_i),
    .op1_i(op1_i),
    .op2_i(op2_i),
    .inst_i(inst_i),
    .reg_wdata_o(s_reg_wdata_o),
    .reg_we_o(s_reg_we_o),

    .mem_addr_o(s_mem_addr_o),
    .mem_data_o(s_mem_data_o),
    .mem_op_o(s_mem_op_o),
    .mem_we_o(s_mem_we_o)
);

wire[`ADDR_WIDTH-1:0] b_jump_addr_o;
wire b_jump_we_o;
wire b_reg_we_o;
wire [`RDATA_WIDTH-1:0] b_reg_wdata_o;

exe_type_b_j exe_type_b_j0(
    .rst_i(rst_i),
    .op1_i(op1_i),
    .op2_i(op2_i),
    .inst_i(inst_i),
    .jump_addr_o(b_jump_addr_o),
    .jump_we_o(b_jump_we_o),
    .reg_wdata_o(b_reg_wdata_o),
    .reg_we_o(b_reg_we_o),
    .inst_addr_i(inst_addr_i)
);

assign csr_raddr_o = csr_addr_i; //read csr
assign csr_waddr_o = csr_addr_i; //write csr

wire [`RDATA_WIDTH-1:0] i_reg1_wdata_o;
wire [`DATA_WIDTH-1:0] i_csr_wdata_o;

exe_type_system exe_type_system0(
    .rst_i(rst_i),
    .inst_i(inst_i),
    .op1_i(op1_i),
    .reg1_data_o(i_reg1_wdata_o),
    .csr_rdata_i(csr_rdata_i),
    .csr_rdata_o(i_csr_wdata_o)
);

reg[`DATA_WIDTH-1:0] csr_rdata;
always @(*) begin
    if (csr_addr_i == mem_csr_waddr_i && mem_csr_we_i==`WRITE_ENABLE) begin
        csr_rdata = mem_csr_wdata_i;
    end else begin
        csr_rdata = csr_rdata_i;
    end
end

always @(*) begin
    if(rst_i == 1) begin
            reg_waddr_o = `ZERO_REG;
            reg_wdata_o = `ZERO;
            reg_we_o = `WRITE_DISABLE;
            mem_we_o = `WRITE_DISABLE;
            mem_addr_o = `ZERO;
            mem_data_o = `ZERO;
            mem_op_o = `MEM_NOP;
            jump_addr_o = `ZERO;
            jump_we_o = `WRITE_DISABLE;
            csr_we_o = `WRITE_DISABLE;
            csr_wdata_o = `ZERO;
            inst_addr_o = `ZERO_REG;
    end else begin
        /// 用 opcode 找出是哪個 tpye , 用 funct3 funct7 去區分哪個指令
        inst_addr_o = inst_addr_i;
        case(opcode)
            `INST_TYPE_I:begin  //0010011 = I type
                reg_waddr_o = reg_waddr_i;
                reg_wdata_o = i_reg_wdata_o;
                reg_we_o = i_reg_we_o;
                mem_we_o = `WRITE_DISABLE;
                mem_addr_o = `ZERO;
                mem_data_o = `ZERO;
                mem_op_o = `MEM_NOP;
                jump_addr_o = `ZERO;
                jump_we_o = `WRITE_DISABLE;
                csr_we_o = `WRITE_DISABLE;
                csr_wdata_o = `ZERO;
            end
            `INST_TYPE_R_M:begin // R type
                reg_waddr_o = reg_waddr_i;
                reg_wdata_o = r_reg_wdata_o;
                reg_we_o = r_reg_we_o;
                mem_we_o = `WRITE_DISABLE;
                mem_addr_o = `ZERO;
                mem_data_o = `ZERO;
                mem_op_o = `MEM_NOP;
                jump_addr_o = `ZERO;
                jump_we_o = `WRITE_DISABLE;
                csr_we_o = `WRITE_DISABLE;
                csr_wdata_o = `ZERO;
            end
            `INST_TYPE_LUI:begin // U type
                reg_waddr_o = reg_waddr_i;
                reg_wdata_o = op1_i+op2_i;
                reg_we_o = reg_we_i;
                mem_we_o = `WRITE_DISABLE;
                mem_addr_o = `ZERO;
                mem_data_o = `ZERO;
                mem_op_o = `MEM_NOP;
                jump_addr_o = `ZERO;
                jump_we_o = `WRITE_DISABLE;
                csr_we_o = `WRITE_DISABLE;
                csr_wdata_o = `ZERO;
            end
            `INST_TYPE_AUIPC:begin // U type
                reg_waddr_o = reg_waddr_i;
                reg_wdata_o = op1_i+op2_i;
                reg_we_o = reg_we_i;
                mem_we_o = `WRITE_DISABLE;
                mem_addr_o = `ZERO;
                mem_data_o = `ZERO;
                mem_op_o = `MEM_NOP;
                jump_addr_o = `ZERO;
                jump_we_o = `WRITE_DISABLE;
                csr_we_o = `WRITE_DISABLE;
                csr_wdata_o = `ZERO;
            end
            `INST_TYPE_S, `INST_TYPE_L:begin //type store, load
                reg_waddr_o = reg_waddr_i;
                reg_wdata_o = s_reg_wdata_o;
                reg_we_o = s_reg_we_o;
                mem_we_o = s_mem_we_o;
                mem_addr_o = s_mem_addr_o;
                mem_data_o = s_mem_data_o;
                mem_op_o = s_mem_op_o;
                jump_addr_o = `ZERO;
                jump_we_o = `WRITE_DISABLE;
                csr_we_o = `WRITE_DISABLE;
                csr_wdata_o = `ZERO;
            end
            `INST_TYPE_JAL:begin //type_J JAL
                reg_waddr_o = reg_waddr_i;
                reg_wdata_o = b_reg_wdata_o;
                reg_we_o = b_reg_we_o;
                mem_we_o = `WRITE_DISABLE;
                mem_addr_o = `ZERO;
                mem_data_o = `ZERO;
                mem_op_o = `MEM_NOP;
                jump_addr_o = b_jump_addr_o;
                jump_we_o = b_jump_we_o;
                csr_we_o = `WRITE_DISABLE;
                csr_wdata_o = `ZERO;
            end
            `INST_TYPE_JALR:begin //type_J JALR
                reg_waddr_o = reg_waddr_i;
                reg_wdata_o = b_reg_wdata_o;
                reg_we_o = b_reg_we_o;
                mem_we_o = `WRITE_DISABLE;
                mem_addr_o = `ZERO;
                mem_data_o = `ZERO;
                mem_op_o = `MEM_NOP;
                jump_addr_o = b_jump_addr_o;
                jump_we_o = b_jump_we_o;
                csr_we_o = `WRITE_DISABLE;
                csr_wdata_o = `ZERO;
            end
            `INST_TYPE_B:begin //type_B
                reg_waddr_o = reg_waddr_i;
                reg_wdata_o = b_reg_wdata_o;
                reg_we_o = b_reg_we_o;
                mem_we_o = `WRITE_DISABLE;
                mem_addr_o = `ZERO;
                mem_data_o = `ZERO;
                mem_op_o = `MEM_NOP;
                jump_addr_o = b_jump_addr_o;
                jump_we_o = b_jump_we_o;
                csr_we_o = `WRITE_DISABLE;
                csr_wdata_o = `ZERO;
            end
            `INST_TYPE_SYSTEM:begin //csr, ecall, ebreak, mret, wfi etc.
                mem_we_o = `WRITE_DISABLE;
                mem_addr_o = `ZERO;
                mem_data_o = `ZERO;
                mem_op_o = `MEM_NOP;
                jump_addr_o = `ZERO;
                jump_we_o = `WRITE_DISABLE;
                reg_waddr_o = reg_waddr_i;
                reg_wdata_o = i_reg1_wdata_o;
                reg_we_o = reg_we_i;
                csr_we_o = csr_we_i;
                csr_wdata_o = i_csr_wdata_o;
            end
            default:begin
                reg_waddr_o = `ZERO_REG;
                reg_wdata_o = `ZERO;
                reg_we_o = `WRITE_DISABLE;
                mem_we_o = `WRITE_DISABLE;
                mem_addr_o = `ZERO;
                mem_data_o = `ZERO;
                mem_op_o = `MEM_NOP;
                jump_addr_o = `ZERO;
                jump_we_o = `WRITE_DISABLE;
                csr_we_o = `WRITE_DISABLE;
                csr_wdata_o = `ZERO;
            end
        endcase
    end
end

wire is_jump_hazard;
assign is_jump_hazard = (jump_we_o == 1'b1);

always @(*)begin
  if(is_jump_hazard == 1 | mult_div_stall == 1)begin
    stallreq_o = 1'b1;
  end else begin
    stallreq_o = 1'b0;
  end
end

endmodule
