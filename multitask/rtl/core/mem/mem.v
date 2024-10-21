`include "defines.v"

module mem(
    input wire clk_i,
    input wire rst_i,
//from exe_mem
    input wire[`RADDR_WIDTH-1:0] reg_waddr_i,
    input wire reg_we_i,
    input wire[`RDATA_WIDTH-1:0] reg_wdata_i,

// store from exe_mem
    input wire[`ADDR_WIDTH-1:0] mem_addr_i,
    input wire[`DATA_WIDTH-1:0] mem_data_i,
    input wire[3:0] mem_op_i,        //LB,LH,LW,LBU, LHU, SB, SH, SW, NONE
    input wire mem_we_i,

// store from ram
    input wire[`DATA_WIDTH-1:0] ram_data_i,

// store to ram
    output reg[`ADDR_WIDTH-1:0] ram_addr_o,
    output reg[`DATA_WIDTH-1:0] ram_data_o,
    output reg ram_w_request_o,
    output reg ram_ce_o,

//to mem_wb
    // csr
    input wire                            csr_we_i,
    input wire[`CSR_ADDR_WIDTH-1:0]       csr_waddr_i,
    input wire[`DATA_WIDTH-1:0]           csr_wdata_i,


    output reg                            csr_we_o,
    output reg[`CSR_ADDR_WIDTH-1:0]       csr_waddr_o,
    output reg[`DATA_WIDTH-1:0]           csr_wdata_o,


    output reg[`RADDR_WIDTH-1:0] reg_waddr_o,
    output reg reg_we_o,
    output reg[`RDATA_WIDTH-1:0] reg_wdata_o,

    output reg halt_o,  //for isa test

//to interrupt ctrl
    output reg[`ADDR_WIDTH-1:0]         inst_addr_o,
    input wire[`ADDR_WIDTH-1:0]         inst_addr_i,
//to i_ctrl
    input wire[`DATA_WIDTH-1:0]         exception_i,
    output reg[`DATA_WIDTH-1:0]         exception_o

);

assign exception_o = exception_i;

//for int  mepc <= pc 
always @(*) begin
    if (rst_i == 1'b1) begin
        inst_addr_o = `ZERO; 
    end else begin
        inst_addr_o = inst_addr_i; 
    end //if
end //always

wire[1:0] ram_addr_offset;
assign ram_addr_offset = mem_addr_i[1:0] & 2'b11; //0,1,2,3   後面 ＆2'b11 可以在這捨去 但如果要 mask 更多時就得考慮例外 , mem_addr_i 是算出來記憶體的哪個位址抓資料用

// for ram write TYPE-S 跟 ram 有關所以保留 ram 的變數

// for reg write TYPE-L 跟暫存器有關所以保留暫存器的變數


    //csr file
    always @(*) begin
        if (rst_i == 1'b1) begin
            csr_we_o = `WRITE_DISABLE;
            csr_waddr_o = {12'b0};
            csr_wdata_o = `ZERO;
        end else begin
            csr_we_o = csr_we_i;
            csr_waddr_o = csr_waddr_i;
            csr_wdata_o = csr_wdata_i;
        end //if
    end //always


    reg[`DATA_WIDTH-1:0] reg_wdata;
    assign reg_wdata_o = reg_wdata;

    //for wb regfile
    always @(*) begin
        if (rst_i == 1'b1) begin
            reg_waddr_o = `ZERO_REG;
            reg_we_o = `WRITE_DISABLE;
            reg_wdata = `ZERO;
        end else begin
            reg_waddr_o = reg_waddr_i;
            reg_we_o = reg_we_i;
            reg_wdata = reg_wdata_i;
        end
    end

    always @(*) begin
        if (rst_i == 1'b1) begin
            reg_waddr_o = `ZERO_REG;
            reg_we_o = `WRITE_DISABLE;
            reg_wdata_o = `ZERO;
            ram_addr_o = `ZERO;
            ram_data_o = `ZERO;
            ram_w_request_o = `WRITE_DISABLE;
            ram_ce_o = `CHIP_DISABLE;   
        end else begin
            reg_waddr_o = reg_waddr_i;
            reg_we_o = reg_we_i;
            ram_w_request_o = mem_we_i;
            ram_addr_o = mem_addr_i;
            ram_data_o = `ZERO;
            reg_wdata_o = reg_wdata_i; 
            case(mem_op_i)   //先不考慮 ram 讀取需要幾個 cycle
                `LB: begin
                    ram_ce_o = `CHIP_ENABLE;
                    case(ram_addr_offset)
                    2'b00:begin
                        reg_wdata_o = {{24{ram_data_i[7]}}, ram_data_i[7:0]};
                    end
                    2'b01:begin
                        reg_wdata_o = {{24{ram_data_i[15]}}, ram_data_i[15:8]};
                    end
                    2'b10:begin
                        reg_wdata_o = {{24{ram_data_i[23]}}, ram_data_i[23:16]};
                    end
                    default:begin
                        reg_wdata_o = {{24{ram_data_i[31]}}, ram_data_i[31:24]};
                    end
                    endcase      
                end
                `LH: begin
                    ram_ce_o = `CHIP_ENABLE;
                    if (ram_addr_offset==2'b00) begin
                        reg_wdata_o = {{16{ram_data_i[15]}}, ram_data_i[15:0]};
                    end else if(ram_addr_offset==2'b10) begin
                        reg_wdata_o = {{16{ram_data_i[31]}}, ram_data_i[31:16]};
                    end else 
                        reg_wdata_o = `ZERO;
                end
                `LW: begin
                    ram_ce_o = `CHIP_ENABLE;
                    reg_wdata_o = ram_data_i;
                end
                `LBU:begin
                    ram_ce_o = `CHIP_ENABLE;
                    case (ram_addr_offset)
                        2'b00: begin
                            reg_wdata_o = {24'h0, ram_data_i[7:0]};
                        end
                        2'b01: begin
                            reg_wdata_o = {24'h0, ram_data_i[15:8]};
                        end
                        2'b10: begin
                            reg_wdata_o = {24'h0, ram_data_i[23:16]};
                        end
                        default: begin
                            reg_wdata_o = {24'h0, ram_data_i[31:24]};
                        end
                    endcase   
                end
                `LHU:begin
                    ram_ce_o = `CHIP_ENABLE;
                    if (ram_addr_offset == 2'b0) begin
                        reg_wdata_o = {16'h0, ram_data_i[15:0]};
                    end else if (ram_addr_offset == 2'b10) begin
                        reg_wdata_o = {16'h0, ram_data_i[31:16]};
                    end else
                        reg_wdata_o = `ZERO;
                end                
                `SB: begin
                    ram_ce_o = `CHIP_ENABLE;
                    case (ram_addr_offset)
                    2'b00: begin
                        ram_data_o = {ram_data_i[31:8],mem_data_i[7:0]};
                    end
                    2'b01: begin
                        ram_data_o = {ram_data_i[31:16],mem_data_i[7:0], ram_data_i[7:0]};
                    end
                    2'b10:begin
                        ram_data_o = {ram_data_i[31:24],mem_data_i[7:0], ram_data_i[15:0]};
                    end
                    default:begin
                        ram_data_o = {mem_data_i[7:0], ram_data_i[23:0]};
                    end
                    endcase
                end
                `SH: begin
                    ram_ce_o = `CHIP_ENABLE;
                    if (ram_addr_offset == 2'b00) begin
                        ram_data_o = {ram_data_i[31:16],mem_data_i[15:0]};
                    end else if(ram_addr_offset == 2'b10) begin
                        ram_data_o = {mem_data_i[15:0], ram_data_i[15:0]};
                    end else
                        ram_data_o = `ZERO;
                end
                `SW: begin
                    ram_ce_o = `CHIP_ENABLE;
                    ram_data_o = mem_data_i;
                end
                default: begin
                    ram_addr_o = `ZERO;
                    ram_data_o = `ZERO;
                    ram_w_request_o = `WRITE_DISABLE;
                    ram_ce_o = `CHIP_DISABLE;
                end
            endcase
        end //if
    end //always

    always @(posedge clk_i) begin
        //for isa test
        if (mem_op_i==`SW && mem_addr_i == `HALT_ADDR)begin
            halt_o <= 1'b1;
        end else begin
            halt_o <= halt_o;
        end   
    end

endmodule
