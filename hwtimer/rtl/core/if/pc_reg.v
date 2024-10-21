`include "defines.v"

module pc_reg(
    input wire rst_i,
    input wire clk_i,

    //ctrl
    input wire[5:0] stall_i,
    input wire flush_jump_i,
    input wire[`ADDR_WIDTH-1:0] new_pc_i,

    output reg[`ADDR_WIDTH-1:0] pc_o,
    output reg ce_o,
    
    input wire flush_int_i //for int
);

    always @(posedge clk_i) begin
        if (rst_i == 1'b1) begin
            ce_o <= 1'b0;
        end else begin
            ce_o <= 1'b1;
        end
    end

    wire is_new_pc = (flush_jump_i);
    always @(posedge clk_i) begin
        if(ce_o == 1'b0) begin
            pc_o <= 32'h0;
        end else if(is_new_pc | flush_int_i )begin
            pc_o <= new_pc_i;
        end else if(stall_i[0] == `STOP)begin
            pc_o <= pc_o; //loop
        end else begin
            pc_o <= pc_o + 4;
        end
    end

endmodule