module exe_type_system(
    input wire rst_i,

    input wire[`DATA_WIDTH-1:0] op1_i, 
    input wire[`RDATA_WIDTH-1:0] inst_i,
    output reg[`RDATA_WIDTH-1:0] reg1_data_o,
    input wire[`DATA_WIDTH-1:0] csr_rdata_i,
    output reg[`DATA_WIDTH-1:0] csr_rdata_o
);

wire[6:0] opcode = inst_i[6:0];

wire[2:0] funct3 = inst_i[14:12];

wire isTYPE_system;

assign isTYPE_system = (opcode == `INST_TYPE_SYSTEM);

always@(*) begin
    if(rst_i == 1'b1 || ~isTYPE_system) begin
        reg1_data_o = `ZERO;
        csr_rdata_o = `ZERO;
    end else begin
        case(funct3)
        `INST_CSRRW , `INST_CSRRWI : begin
            reg1_data_o = csr_rdata_i;
            csr_rdata_o = op1_i;
        end
        `INST_CSRRS , `INST_CSRRSI : begin
            reg1_data_o = csr_rdata_i;
            csr_rdata_o = op1_i | csr_rdata_i;
        end
        `INST_CSRRC , `INST_CSRRCI : begin
            reg1_data_o = csr_rdata_i;
            csr_rdata_o = csr_rdata_i & ~op1_i;
        end
        default:begin
            reg1_data_o = `ZERO;
            csr_rdata_o = `ZERO;
        end
    endcase
    end
end


endmodule