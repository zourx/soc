`include "defines.v"

module dpram #(
  parameter RAM_SIZE        = 1,
  parameter RAM_ADDR_WIDTH  = 1
  )(
//rom - instrution port

    input wire clk_i,
    input wire ce_i,
    input wire [`ADDR_WIDTH-1:0] pc_i,
    output reg [`ADDR_WIDTH-1:0] inst_o,

//ram - data port
    input wire ram_ce_i,
    // from mem
    input wire[`ADDR_WIDTH-1:0] addr_i,
    input wire[`DATA_WIDTH-1:0] data_i,
    input wire we_i,
    // to mem
    output reg[`DATA_WIDTH-1:0] data_o
);


reg [7:0] mem[0:RAM_SIZE-1];

//rom - instrution port

// 記憶體做 byte 單位 （ 8 bit ）
// 記憶體在讀 32 bit 的時候會,一次抓 4 個讀取
///// assign addr4 = {addr_i[20:2],2'b0};  之所以沒有位寬至 32bit 
///// 因為 bus 要往下到 rom 取位址時 , 前面的 bit 是在 bus 上固定的 , 所以不用全取
///// 後面補兩個 0 , 對於二進制的數值來說左移n位等於原來的數值乘以2的n次方


wire[RAM_ADDR_WIDTH-1:0] rom_addr4;
assign rom_addr4 = {pc_i[RAM_ADDR_WIDTH-1:2],2'b0};


    always @(*)
        if (ce_i == `CHIP_ENABLE) begin
            inst_o = {mem[rom_addr4],mem[rom_addr4+1],mem[rom_addr4+2],mem[rom_addr4+3]};
        end else begin
            inst_o = `ZERO;
        end//if

    task readByte;
        /*verilator public*/
        input integer byte_addr;
        output integer val;
        begin
            val = {24'b0,mem[byte_addr[RAM_ADDR_WIDTH-1:0]]};
        end
    endtask    


    task writeByte;
        /*verilator public*/
        input integer byte_addr;
        input [7:0] val;
        begin
            mem[byte_addr[RAM_ADDR_WIDTH-1:0]] = val;
        end
    endtask    

    /*------------------ data port ----------------------*/

wire [RAM_ADDR_WIDTH-1:0] addr4;
assign addr4 = {addr_i[RAM_ADDR_WIDTH-1:2],2'b0};

        // 將 data_i 寫入 mem 中指定的 addr_i 中
        
	always @ (posedge clk_i) begin
		if( (ram_ce_i == 1'b1) && (we_i == `WRITE_ENABLE) ) begin
            mem[addr4] <= data_i[31:24];
            mem[addr4+1] <= data_i[23:16];
            mem[addr4+2] <= data_i[15:8];
            mem[addr4+3] <= data_i[7:0];
        end
	end
	always @ (*) begin
		if (ram_ce_i==`CHIP_ENABLE) begin
		    data_o =  {mem[addr4],mem[addr4+1],mem[addr4+2],mem[addr4+3]};
		end else begin
			data_o = `ZERO;
		end
	end		

endmodule