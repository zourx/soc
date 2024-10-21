`include "defines.v"

module exe_mem(
    input wire clk_i,
    input wire rst_i,
//form exe
    input wire[`RADDR_WIDTH-1:0] reg_waddr_i,
    input wire reg_we_i,
    input wire[`RDATA_WIDTH-1:0] reg_wdata_i,

// store from exe 
    input reg[`ADDR_WIDTH-1:0] mem_addr_i,
    input reg[`DATA_WIDTH-1:0] mem_data_i,
    input reg[3:0] mem_op_i,
    input reg mem_we_i,

// to mem
    output reg[`RADDR_WIDTH-1:0] reg_waddr_o,
    output reg reg_we_o,
    output reg[`RDATA_WIDTH-1:0] reg_wdata_o,

    // csr
    input wire                             csr_we_i,
    input wire[`CSR_ADDR_WIDTH-1:0]        csr_waddr_i,
    input wire[`DATA_WIDTH-1:0]            csr_wdata_i,
    output reg                             csr_we_o,
    output reg[`CSR_ADDR_WIDTH-1:0]        csr_waddr_o,
    output reg[`DATA_WIDTH-1:0]            csr_wdata_o,


// store to mem 
    output reg[`ADDR_WIDTH-1:0] mem_addr_o,
    output reg[`DATA_WIDTH-1:0] mem_data_o,
    output reg[3:0] mem_op_o,
    output reg mem_we_o,

//for interrupt ctrl
    input wire[`ADDR_WIDTH-1:0] inst_addr_i,
    output reg[`ADDR_WIDTH-1:0] inst_addr_o,
    input wire flush_int_i, //for int

    input wire[`DATA_WIDTH-1:0] exception_i,
    output reg[`DATA_WIDTH-1:0] exception_o
);

//for interrupt ctrl
always @(posedge clk_i) begin
    if (rst_i == 1'b1) begin
        inst_addr_o <= `ZERO;
        exception_o <= `ZERO;
    end else if (flush_int_i) begin
        inst_addr_o <= `ZERO;
        exception_o <= `ZERO;
    end else begin
        inst_addr_o <= inst_addr_i;
        exception_o <= exception_i;
    end
end

always @(posedge clk_i) begin
    if(rst_i == 1'b1)begin
        reg_waddr_o <= `ZERO_REG;
        reg_we_o <= `WRITE_ENABLE;
        reg_wdata_o <= `ZERO;
        mem_addr_o <= `ZERO;
        mem_data_o <= `ZERO;
        mem_op_o <= `MEM_NOP;
        mem_we_o <= `WRITE_DISABLE;
        csr_we_o <= `WRITE_DISABLE;
        csr_waddr_o <= 12'b0;
        csr_wdata_o<= `ZERO;
    end else if (flush_int_i) begin
        reg_waddr_o <= `ZERO_REG;
        reg_we_o <= `WRITE_ENABLE;
        reg_wdata_o <= `ZERO;
        mem_addr_o <= `ZERO;
        mem_data_o <= `ZERO;
        mem_op_o <= `MEM_NOP;
        mem_we_o <= `WRITE_DISABLE;
        csr_we_o <= `WRITE_DISABLE;
        csr_waddr_o <= 12'b0;
        csr_wdata_o<= `ZERO;
    end else begin
        reg_waddr_o <= reg_waddr_i;
        reg_we_o <= reg_we_i;
        reg_wdata_o <= reg_wdata_i;
        mem_addr_o <= mem_addr_i;
        mem_data_o <= mem_data_i;
        mem_op_o <= mem_op_i;
        mem_we_o <= mem_we_i;
        csr_we_o <= csr_we_i;
        csr_waddr_o <= csr_waddr_i;
        csr_wdata_o<= csr_wdata_i;
    end
end

endmodule