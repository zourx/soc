`include "defines.v"

module regfile(

//暫存器
    input wire clk_i,
    input wire rst_i,

//兩個輸入 enable addr 各一 , from id read
    input wire re1_i,
    input wire[`RADDR_WIDTH-1:0] raddr1_i,
    input wire re2_i,
    input wire[`RADDR_WIDTH-1:0] raddr2_i,

//輸出 data ,  to id
    output reg[`RDATA_WIDTH-1:0] rdata1_o,
    output reg[`RDATA_WIDTH-1:0] rdata2_o,

//from WB
    input wire we_i,
    input wire[`RADDR_WIDTH-1:0] waddr_i,
    input wire[`RDATA_WIDTH-1:0] wdata_i
);

// 暫存器組是用振列編號排序 5bit （s0～s31）; csr file 不會是這樣寫,每個暫存器都會有一個位置,有12bit
    reg[`RDATA_WIDTH-1:0] regs[0:`RNUM-1];
    integer i;
    initial begin
        for (i=0;i<`RNUM;i=i+1)
            regs[i] = 0;
    end

    //write
    always @(posedge clk_i) begin
        if (rst_i == 0) begin
                // 先做寫
            if ((we_i == `WRITE_ENABLE) && (waddr_i != `ZERO_REG)) begin
                    regs[waddr_i] <= wdata_i;
                end
        end//if rst_i
    end//always

    //read 1
    always @(*) begin
        if (raddr1_i == `ZERO_REG) begin
            rdata1_o = `ZERO;

            // 如果 讀地址 = 寫地址且write enable，直接返回數據
        end else if (raddr1_i == waddr_i && we_i == `WRITE_ENABLE && re1_i == `READ_ENABLE) begin 
            rdata1_o = wdata_i;
        
        end else if (re1_i == `READ_ENABLE) begin
            rdata1_o = regs[raddr1_i];               //贊存器編號的data位置
        end else begin
            rdata1_o = `ZERO;
        end//if
    end//always

    //read 2
    always @(*) begin
        if (raddr2_i == `ZERO_REG) begin
            rdata2_o = `ZERO;

            // 如果 讀地址 = 寫地址且write enable，直接返回數據
        end else if (raddr2_i == waddr_i && we_i == `WRITE_ENABLE && re2_i == `READ_ENABLE) begin
            rdata2_o = wdata_i;

        end else if (re2_i == `READ_ENABLE) begin
            rdata2_o = regs[raddr2_i];               //贊存器編號的data位置
        end else begin
            rdata2_o = `ZERO;
        end//if
    end//always

// 在測試時可以讀出任意的 register內容
    task readRegister;
        /*verilator public*/
        input integer raddr;
        output integer val;
        begin
            val = regs[raddr[4:0]];
        end
    endtask

endmodule