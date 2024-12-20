`include "defines.v"

module if_id(
    input wire clk_i,
    input wire rst_i,

    //ctrl
    input wire[5:0] stall_i,
    input wire flush_jump_i,
    input wire flush_int_i, //for int

    input wire[`ADDR_WIDTH-1:0] inst_addr_i,
    input wire[`DATA_WIDTH-1:0] inst_i,


    //inst_addr_i

    output reg[`ADDR_WIDTH-1:0] inst_addr_o,
    output reg[`DATA_WIDTH-1:0] inst_o
);

    always @(posedge clk_i) begin
        if (rst_i == 1) begin
            inst_addr_o <= 0;
            inst_o <= `NOP;
        end else if(flush_jump_i | flush_int_i)begin
            inst_addr_o <= 0;
            inst_o <= `NOP;
        end else if(stall_i[1]==`STOP && stall_i[2]==`STOP)begin //loop
            inst_addr_o <= inst_addr_o;
            inst_o <= inst_o;
        end else if(stall_i[1]==`STOP && stall_i[2]==`NOSTOP) begin //10就清空
            inst_addr_o <= 0;
            inst_o <= `NOP;
        end else begin
            inst_addr_o <= inst_addr_i;
            inst_o <= inst_i;
        end//if
    end//always
endmodule
