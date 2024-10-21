module bus #(
    parameter NrDevices     = 1,    //client 數量默認為 1 , 到 test_top 可以再更改數量
    parameter NrHosts       = 1,    //master 數量默認為 1 , 到 test_top 可以再更改數量
    parameter DataWidth     = 32,
    parameter AddressWidth  = 32
)(

input wire clk_i,

input wire rst_i,

//master(host) -> bus 
    // 傳遞 reqest, addr, we, wdata 給 bus

//bus -> master(host)
    //傳遞 rdata, gnt 給 master

input wire host_req_i [NrHosts],                        //  [NrHosts] 代表任一個 NrHost 傳遞訊號進來

input wire host_we_i [NrHosts],

input wire [AddressWidth-1:0] host_addr_i [NrHosts],

input wire [DataWidth-1:0] host_wdata_i [NrHosts],

output reg [DataWidth-1:0] host_rdata_o [NrHosts],

output reg host_gnt_o [NrHosts],                        // bus 授權,bus授權過才能傳遞資料

//bus -> device(client) 
    //傳遞 reqest, addr, we, wdata 給 device

//device -> bus
    //傳遞 rdata, gnt 給 bus

input wire[DataWidth-1:0] device_rdata_i [NrDevices],       // 數組被用来表示多個 slaves 的输入或输出訊號

output reg device_req_o [NrDevices],

output reg device_we_o [NrDevices],

output reg[AddressWidth-1:0] device_addr_o [NrDevices],

output reg[DataWidth-1:0] device_wdata_o [NrDevices],


//device address map
// 設備地址的最高位視為地址映射的 base , 映射地址的範圍由 mask 決定 , bus 透過這個地址映射可以正確的將 master slaves 做相互傳輸

// 透過 master 地址 (host_addr_i) & device_mask [NrDevices] 若等於 device_base [NrDevices] , 則代表 master 請求是發給 device [NrDevices] 

input wire[AddressWidth-1:0]  cfg_device_addr_base [NrDevices],  // 定義設備的地址映射,將設備地址映射到 bus 特定地址上
input wire[AddressWidth-1:0]  cfg_device_addr_mask [NrDevices]   // 它的作用是屏蔽掉不需要考虑的地址位，只保留需要匹配的地址位 , 其中的1表示需要匹配的地址位，0表示不需要考慮的地址位 通過地址掩碼的設置，可以定義設備地址的範圍

);

  localparam NumBitsHostSel = NrHosts > 1 ? clog2(NrHosts) : 1;         // 目的是計算需要幾個 bit 來表示選擇哪個 masters
  localparam NumBitsDeviceSel = NrDevices > 1 ? clog2(NrDevices) : 1;   // 選擇哪個 slaves

// localparam 是 Verilog 語言中的一個關鍵字，用於定義一個局部參數，其值在編譯時期就已經確定，不會在運行時改變
// 它可以用來定義常量、地址、輸入寬度、信號延遲等

  reg [NumBitsHostSel-1:0] host_sel_req, host_sel_resp;
  reg [NumBitsDeviceSel-1:0] device_sel_req, device_sel_resp;

// master 仲裁優先級
// host_sel_req 記錄主機端選擇的結果
// 先用迴圈遍歷所有的 master , 如果 master 有發出訪問的需求 host_req_i[host]會為 1 
// 如果為 1 , host_sel_req 會設為這個主機端的編號，也就是 host 變數
// 迴圈大到小 , 所以會從越小的越先做(權限高)

always @(*) begin
    host_sel_req = '0;
    for (integer host = NrHosts -1 ; host >= 1 ; host = host -1)
    begin
        if (host_req_i[host]) begin
            host_sel_req = NumBitsHostSel'(host);   //
        end
    end
end


// slave 選擇匹配 master mask 當前要處理的請求
// 使用 host_sel_req 訊號表示當前需要處理請求的主機 , 遍歷所有 slave 起始地址 , 去找相等於 （ 當前 master_addr 做 mask 後的地址結果）
// 也就是說透過權限高的 master 去找尋它所要交握的 slave

always @(*) begin
    device_sel_req = 0;
    for (integer device = 0; device < NrDevices; device = device + 1)
    begin
        if ((host_addr_i[host_sel_req] & cfg_device_addr_mask[device]) == cfg_device_addr_base[device]) begin
            device_sel_req = NumBitsDeviceSel'(device);
        end
    end
end

// 選中 master slave 將他們訊號連起來
// master(host) -> device
// 傳遞 request, we, addr, wdata 給 device

// 用來選擇從主機端來的傳輸請求要發送給哪一個裝置
// 遍歷所有 slave 編號 ,  把編號和 device_sel_req 相同的抓出 , 將 master 傳送至該 slave

always@(*) begin
    for (integer device = 0; device < NrDevices; device = device + 1) begin
        if(NumBitsDeviceSel'(device) == device_sel_req) begin
        device_req_o[device]    =   host_req_i[host_sel_req];
        device_we_o[device]     =   host_we_i[host_sel_req];
        device_addr_o[device]   =   host_addr_i[host_sel_req];
        device_wdata_o[device]  =   host_wdata_i[host_sel_req];
        end else begin
        device_req_o[device]   = 1'b0;
        device_we_o[device]    = 1'b0;
        device_addr_o[device]  = 'b0;
        device_wdata_o[device] = 'b0;
      end
    end
end

// 將選中的 device 的 rdata 連到 host 的 rdata
// 同時授權給 選中的 host，其他 host授權取消

always@(*)begin
    for(integer host = 0; host < NrHosts ; host = host + 1 )
    begin
        host_gnt_o[host] = 1'b0;
        if(NumBitsHostSel'(host) == host_sel_resp) begin
            host_rdata_o[host] = device_rdata_i[device_sel_resp];
        end else begin
            host_rdata_o[host] = 'b0;
        end
    end
    host_gnt_o[host_sel_req] = host_req_i[host_sel_req];
end





  always @(*) begin                     //clk_i
     if (rst_i==1'b1) begin
        host_sel_resp = '0;
        device_sel_resp = '0;
     end else begin
        // Responses are always expected 1 cycle after the request
        device_sel_resp = device_sel_req;
        host_sel_resp = host_sel_req;
     end
  end



  function integer clog2 (input integer n); begin
    n = n - 1;
    for (clog2 = 0; n > 0; clog2 = clog2 + 1)
      n = n >> 1;
  end
  endfunction  
endmodule