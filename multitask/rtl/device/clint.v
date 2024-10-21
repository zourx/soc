module clint (
    input wire clk_i,
    input wire rst_i,
    
    // connect bus
    input wire req_i,
    input wire we_i,
    input wire [`DATA_WIDTH-1 : 0] addr_i,        //mtime, msip, mtimecmp
    input wire [`DATA_WIDTH-1:0] data_i,
    output reg [`DATA_WIDTH-1:0] data_o,

    // to csr
    output reg    timer_irq_o,
    output reg    software_irq_o
);

// mtime 是硬體設定完 , os 只能讀
// msip, mtimecmp , os 可以寫

// mtime 可以依核心數量有多個時間中斷

localparam MTIMECMP_BASE = 16'h4000;
localparam MSIP_BASE = 16'h0;
localparam TIME_ADDR = 16'hBFF8;        // mtime addr
wire[15:0] raddr = addr_i[15:0];

reg  [`DATA_WIDTH-1 : 0] mtime_mem[0: 1];   // 內部計數器 mtime_mem , 每個 0 和 1 都有 32 bit 加在一起就 64 bit
reg  [`DATA_WIDTH-1 : 0] mtimecmp_mem[0: 1]; // 同理 mtime_mem
reg  [`DATA_WIDTH-1 : 0] msip_mem;          // 軟體中斷只需要 32 bit
wire [`DATA_WIDTH2-1 : 0] mtime = { mtime_mem[1], mtime_mem[0] };   // 將兩個 mtime_mem 合併成 64 bit , 因為會不斷加 1 所以要進位
wire [`DATA_WIDTH2-1 : 0] mtimecmp = { mtimecmp_mem[1], mtimecmp_mem[0] }; // 64 bit 的比較 , 和 mtime 比較
wire [`DATA_WIDTH2-1 : 0] msip = {32'b0, msip_mem}; // 只要寫 1 就是觸發中斷 , 所以 1 bit 就夠了

wire carry = (mtime_mem[0] == 32'hFFFF_FFFF);   //如果全部都是 1 的時候要進位 , 所以做一個判斷

wire is_time_addr0 = (raddr == TIME_ADDR);
wire is_time_addr1 = (raddr == TIME_ADDR+16'h4);    // 8*4 ＝ 32 做高位
wire is_mtimecmp_addr0 = (raddr == MTIMECMP_BASE);
wire is_mtimecmp_addr1 = (raddr == MTIMECMP_BASE+16'h4);
wire is_msip_addr = (raddr == MSIP_BASE);

always @(posedge clk_i)     // 寫操作
begin
    if (rst_i == 1'b1) begin
        mtime_mem [0] <= 32'b0;
        mtime_mem [1] <= 32'b0;
        mtimecmp_mem[0] <= 32'b0;
        mtimecmp_mem[1] <= 32'b0;
        msip_mem <= 32'b0;
    end if (we_i) begin
// mtime 是硬體設定完 , os 只能讀
// msip, mtimecmp , os 可以寫
        if (is_msip_addr)
            msip_mem <= data_i;
        else if (is_mtimecmp_addr0)     // is_mtimecmp_addr0 要判斷 64 bit 前還是後 32 bit
            mtimecmp_mem[0] <= data_i;
        else if (is_mtimecmp_addr1)
            mtimecmp_mem[1] <= data_i;
    end else begin                          // 如果不是寫的操作 , 就是 + 1 
        mtime_mem[0] <= mtime_mem[0] + 32'b1;
        mtime_mem[1] <= mtime_mem[1] + {31'b0,carry};
    end
end


always @(*)     // 讀操作
begin
    if (req_i==`CHIP_ENABLE)
    begin
        if (is_msip_addr) 
            data_o = msip_mem;
        else if (is_mtimecmp_addr0)
            data_o = mtimecmp_mem[0];
        else if (is_mtimecmp_addr1)
            data_o = mtimecmp_mem[1];
        else if(is_time_addr0)
            data_o = mtime_mem[0];
        else if(is_time_addr1)
            data_o = mtime_mem[1];
    end else
    data_o = `ZERO;


end

// ISR 完成後 可重新 reload(set mtimecmp), 也可 關閉 time interrupt (只要 set mie.MTIE=1)

// 使用 software interrupt 在ISR最後也必須要關掉 software interrupt, 只要set msip=0

// time 中斷

// mtime 會不斷的 +1 , 直到大於 mtimecmp 就會發起中斷
// 但目前硬體設定的 mtime 不會歸零 , 所以要透過 os 再追加 mtimecmp 的設定 , 否則會不斷發出時間中斷
wire[63:0]  time_interval = (mtime - mtimecmp);
wire is_timeout = (time_interval[63] == 1'b0);
wire is_mtimecmp_nonzero = (mtimecmp == 64'h0);
assign timer_irq_o = (is_timeout & ~is_mtimecmp_nonzero);

// 軟體中斷
assign software_irq_o = | msip;  // 1 bit

endmodule