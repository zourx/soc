`include "defines.v"

module exe_type_b_j(
    input wire rst_i,

    input wire[`DATA_WIDTH-1:0] op1_i,
    input wire[`DATA_WIDTH-1:0] op2_i,
    input wire[`RDATA_WIDTH-1:0] inst_i,
    input wire[`ADDR_WIDTH-1:0] inst_addr_i,

    output reg reg_we_o,
    output reg[`RDATA_WIDTH-1:0] reg_wdata_o,

    output reg[`ADDR_WIDTH-1:0] jump_addr_o,
    output reg jump_we_o
);

    wire[6:0] opcode = inst_i[6:0];
    wire[2:0] funct3 = inst_i[14:12];

    wire [`DATA_WIDTH-1:0] simm_jal;
    assign simm_jal = {{12{inst_i[31]}},inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};

    wire [`DATA_WIDTH-1:0] simm_jalr;
    assign simm_jalr = {{20{inst_i[31]}},inst_i[31:20]};

    wire [`DATA_WIDTH-1:0] simm_b;
    assign simm_b = {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
    
    always @(*) begin
        if(rst_i == 1) begin
            jump_addr_o = `ZERO;
            jump_we_o = `WRITE_DISABLE;
            reg_we_o = `WRITE_DISABLE;
            reg_wdata_o = `ZERO;
        end else begin
            case(opcode)
            `INST_TYPE_JAL : begin
                jump_addr_o = inst_addr_i + simm_jal;
                jump_we_o = `WRITE_ENABLE;
                reg_we_o = `WRITE_ENABLE;
                reg_wdata_o = inst_addr_i + 4;
            end
            `INST_TYPE_JALR : begin
                jump_addr_o = op1_i + simm_jalr;
                jump_we_o = `WRITE_ENABLE;
                reg_we_o = `WRITE_ENABLE;
                reg_wdata_o = inst_addr_i + 4;
            end
            `INST_TYPE_B : begin
                reg_we_o = `WRITE_DISABLE;
                reg_wdata_o = `ZERO;
                case(funct3)
                `INST_BEQ: begin
                    if($signed(op1_i) == $signed(op2_i)) begin
                    jump_addr_o = inst_addr_i + simm_b;
                    jump_we_o = `WRITE_ENABLE;
                    end else begin
                        jump_addr_o = `ZERO;
                        jump_we_o = `WRITE_DISABLE;
                    end
                    end
                `INST_BNE: begin
                    if($signed(op1_i) != $signed(op2_i)) begin
                    jump_addr_o = inst_addr_i + simm_b;
                    jump_we_o = `WRITE_ENABLE;
                    end else begin
                        jump_addr_o = `ZERO;
                        jump_we_o = `WRITE_DISABLE;
                    end
                    end
                `INST_BLT: begin
                    if($signed(op1_i) < $signed(op2_i)) begin
                    jump_addr_o = inst_addr_i + simm_b;
                    jump_we_o = `WRITE_ENABLE;
                    end else begin
                        jump_addr_o = `ZERO;
                        jump_we_o = `WRITE_DISABLE;
                    end
                    end
                `INST_BGE: begin
                    if($signed(op1_i) >= $signed(op2_i)) begin
                    jump_addr_o = inst_addr_i + simm_b;
                    jump_we_o = `WRITE_ENABLE;
                    end else begin
                        jump_addr_o = `ZERO;
                        jump_we_o = `WRITE_DISABLE;
                    end
                    end
                `INST_BLTU: begin
                    if(op1_i < op2_i) begin
                    jump_addr_o = inst_addr_i + simm_b;
                    jump_we_o = `WRITE_ENABLE;
                    end else begin
                        jump_addr_o = `ZERO;
                        jump_we_o = `WRITE_DISABLE;
                    end
                    end
                `INST_BGEU: begin
                    if(op1_i >= op2_i) begin
                    jump_addr_o = inst_addr_i + simm_b;
                    jump_we_o = `WRITE_ENABLE;
                    end else begin
                        jump_addr_o = `ZERO;
                        jump_we_o = `WRITE_DISABLE;
                    end
                    end
                default:begin
                    jump_addr_o = `ZERO;
                    jump_we_o = `WRITE_DISABLE;
                end
            endcase
            end
            default:begin
                jump_addr_o = `ZERO;
                jump_we_o = `WRITE_DISABLE;
                reg_we_o = `WRITE_DISABLE;
                reg_wdata_o = `ZERO;
            end
            endcase
        end
    end

endmodule