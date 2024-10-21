module pipe_ctrl(
    input wire rst_i,
    input wire clk_i,

//from id
    input stallreq_from_id_i,   //load hazard

// from exe
    input wire[`ADDR_WIDTH-1:0] jump_addr_i,
    input wire jump_we_i,
    input stallreq_from_exe_i,  //jump hazard 
    
    input wire[`ADDR_WIDTH-1:0] pc_i, //from mem

    output reg[5:0] stall_o,  //stall request to pc if_id id_exe exe_mem mem_wb
    //stall_o 中的每一個 bit 代表 相對應的 stage 是否需要 stall

    output reg                   flush_jump_o, //flush IF_ID, ID_EXE   因為到exe解出 type j b 所以要把下兩條已經跑得流水線清除
    output reg[`ADDR_WIDTH-1:0]  new_pc_o,     // change pc              讓下一條直接去跑 jump 所指的位址
    output reg                   flush_int_o, //flush IF_ID, ID_EXE, EXE_MEM, MEM_WB

    //for int
    //input from interrupt ctrl
    input wire[`ADDR_WIDTH-1:0]  isr_pc_i,
    input wire                  int_en_i,
    output reg[`ADDR_WIDTH-1:0]  pc_o //to interrupt_ctrl for mepc
);

reg[`ADDR_WIDTH-1:0] current_pc;
assign pc_o = (|pc_i)? pc_i: current_pc;

always @(posedge clk_i) begin
    if (jump_we_i)
        current_pc <= jump_addr_i;
    else
        current_pc <= current_pc;
end

assign flush_jump_o = jump_we_i; 
assign flush_int_o = int_en_i;
assign new_pc_o = jump_addr_i;

// assign new_pc_o = jump_addr_i;
always @ (*) begin
    if (int_en_i) begin
        new_pc_o = isr_pc_i;
    end else if (jump_we_i) begin
        new_pc_o = jump_addr_i;
    end else begin
        new_pc_o = `ZERO;
    end
end

always @(*) begin
    if(rst_i == 1'b1) begin
        stall_o = 6'b000000;
    end else if(stallreq_from_id_i == `STOP) begin  // stall request from id: stop PC,IF_ID, ID_EXE
        stall_o = 6'b000111;
    end else if(stallreq_from_exe_i == `STOP) begin  // stall request from exe: stop the PC,IF_ID, ID_EXE, EXE_MEM
        stall_o = 6'b001111;
    end else begin
        stall_o = 6'b000000;
    end
end


endmodule