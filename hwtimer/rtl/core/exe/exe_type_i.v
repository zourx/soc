`include "defines.v"

module exe_type_i(
    input wire rst_i,

    input wire[`DATA_WIDTH-1:0] op1_i,
    input wire[`DATA_WIDTH-1:0] op2_i,
    input wire[`RDATA_WIDTH-1:0] inst_i,

    output reg reg_we_o,
    output reg[`RDATA_WIDTH-1:0] reg_wdata_o

);

    wire[6:0] opcode = inst_i[6:0];
    wire[2:0] funct3 = inst_i[14:12];
    wire[6:0] funct7 = inst_i[31:25];

// for slt sltu
    wire op1_ge_op2_signed;
    wire op1_ge_op2_unsigned;
    assign op1_ge_op2_signed = ($signed(op1_i) >= $signed(op2_i));
    assign op1_ge_op2_unsigned = (op1_i >= op2_i);

// for SRLI , SRAI
    wire[31:0] sr_shift;
    wire[31:0] sr_shift_mask;
    assign sr_shift = op1_i >> op2_i[4:0];
    assign sr_shift_mask = 32'hffffffff >> op2_i[4:0];

    wire isType_i;
    assign isType_i = (opcode == `INST_TYPE_I);

always @(*) begin
    if(rst_i == 1'b1 || isType_i == 0) begin
        reg_we_o = `WRITE_DISABLE;
        reg_wdata_o = `ZERO;
    end else begin
        if(opcode == `INST_TYPE_I)begin
            case (funct3)
                `INST_ADDI:begin                        //addi
                    reg_wdata_o = op1_i + op2_i;
                    reg_we_o = `WRITE_ENABLE;
                end
                `INST_XORI:begin                        //xori
                    reg_wdata_o = op1_i ^ op2_i;
                    reg_we_o = `WRITE_ENABLE;
                end
                `INST_ORI:begin                         //ori
                    reg_wdata_o = op1_i | op2_i;
                    reg_we_o = `WRITE_ENABLE;
                end
                `INST_ANDI:begin                        //andi
                    reg_wdata_o = op1_i & op2_i;
                    reg_we_o = `WRITE_ENABLE;
                end
                `INST_SLTI: begin
                    reg_wdata_o = {32{(~op1_ge_op2_signed)}} & 32'h1;
                    reg_we_o = `WRITE_ENABLE;
                end//SLTI
                `INST_SLTIU: begin
                    reg_wdata_o = {32{(~op1_ge_op2_unsigned)}} & 32'h1;
                    reg_we_o = `WRITE_ENABLE;
                end//SLTIU
                `INST_SLLI:begin                        //slli
                    if(funct7 == 7'b0000000) begin
                        reg_wdata_o = op1_i << op2_i;
                        reg_we_o = `WRITE_ENABLE;
                    end else begin
                        reg_wdata_o = `ZERO;
                        reg_we_o = `WRITE_DISABLE;
                    end
                end
                `INST_SRLI:begin                        //srli srai ???????????
                    if(funct7 == 7'b0000000) begin
                        reg_wdata_o = op1_i >> op2_i;
                        reg_we_o = `WRITE_ENABLE;
                    end else if(funct7 == 7'b0100000) begin
                        reg_wdata_o = (sr_shift & sr_shift_mask) | ({32{op1_i[31]}} & (~sr_shift_mask)); 
                        reg_we_o = `WRITE_ENABLE;
                    end else begin
                        reg_wdata_o = `ZERO;
                        reg_we_o = `WRITE_DISABLE;
                    end
                end
                default: begin
                    reg_wdata_o = `ZERO;
                    reg_we_o = `WRITE_DISABLE;
                end//default
            endcase
        end
    end
end

endmodule