// 讓外面進來的 clk rst input 先不做 output

`include "defines.v"

module core_top(
    input wire clk_i,
    input wire rst_i,

// 因為把 dpram 放在 bus 上 , 所以需要從整個 core 核心 作為 master , 然後將 dpram 作為 salve , 中間有 bus 作為橋樑
 
    input wire [`ADDR_WIDTH-1:0]  rom_data_i,
    output reg rom_ce_o,
    output reg [`ADDR_WIDTH-1:0]  rom_addr_o,

    input wire [`DATA_WIDTH-1:0] ram_rdata_i,
    output reg [`DATA_WIDTH-1:0] ram_wdata_o,
    output reg ram_we_o,
    output reg [`ADDR_WIDTH-1:0] ram_addr_o,
    output reg ram_ce_o,

    // // 測 isa 用
    output reg halt_o,

    //for int
    input wire irq_external_i,
    input wire irq_software_i,
    input wire irq_timer_i
);

// // 測 isa 用
assign halt_o = mem_halt_o;

/// 接下來是把所做的模塊連線
/// 模塊有的 input output 都要有
/// 每條線都是接著兩個模塊
/// 如果是 input 就是用著上一個模塊的 output 線 , 如果是 output 就要寫新的線

assign rom_addr_o = pc_wire;



/// if
// inst_fetch 中拆成兩個模組 pc 和 rom , pc 是從外面輸入 rst clk 輸出 pc_o 和 ce_o
// 而從 pc 輸出的 pc 和 ce 接到 rom 的 addr_i 和 ce_i , 最後輸出 一個 inst_o

// pc
wire[`ADDR_WIDTH-1:0] pc_wire;
// wire ce_wire;

pc_reg pc_reg0(
    .rst_i(rst_i),
    .clk_i(clk_i),
    .pc_o(pc_wire), // to if_id
    .ce_o(rom_ce_o), // to rom
    .stall_i(ctrl_stall_o), //from ctrl
    .flush_jump_i(flush_jump_o),
    .new_pc_i(new_pc_o),
    .flush_int_i(pctrl_flush_int_o)    // for int
);

// // rom
// wire[31:0] pc_wire;
// wire[31:0] if_inst_o;
// wire ce_wire;

// rom rom0(
//     .ce_i(ce_wire),
//     .clk_i(clk_i),
//     .addr_i(pc_wire), // pc_wire 串接 addr_i
//     .inst_o(if_inst_o) 
// );

wire[`ADDR_WIDTH-1:0] if_inst_addr_o;    //if to if_id lines
assign if_inst_addr_o = pc_wire;


// IF_ID
//wire[`DATA_WIDTH-1:0] if_inst_o;          //if to if_id lines
wire[`DATA_WIDTH-1:0] if_id_inst_o;       // 連接 if_id 與 id 的線
wire[`ADDR_WIDTH-1:0] if_id_inst_addr_o;  // 連接 if_id 與 id 的線


if_id if_id0(
    .inst_i(rom_data_i),                 // form if
    .inst_addr_i(if_inst_addr_o),       // form if

    .stall_i(ctrl_stall_o),     //from ctrl
    .flush_jump_i(flush_jump_o), //from ctrl

    .inst_o(if_id_inst_o),              // to id
    .inst_addr_o(if_id_inst_addr_o),    // to id

    .flush_int_i(pctrl_flush_int_o),    // for int

    .rst_i(rst_i),
    .clk_i(clk_i)
);

/// id
// id 做指令解碼,會將地址和指令丟去 regfile 且回傳 data , 然後傳給 id_ex


//id & regfile

wire[`RDATA_WIDTH-1:0] reg1_data_o;         //regfile 對外接線
wire[`RDATA_WIDTH-1:0] reg2_data_o;         //regfile 對外接線

wire id_reg1_re_o;                          //id to regfile
wire[`RADDR_WIDTH-1:0] id_reg1_addr_o;      //id to regfile
wire id_reg2_re_o;                          //id to regfile
wire[`RADDR_WIDTH-1:0] id_reg2_addr_o;      //id to regfile

wire[`DATA_WIDTH-1:0] id_inst_o;            // 連接 id 與 id_exe線
wire[`RDATA_WIDTH-1:0] id_op1_o;            // 連接 id 與 id_exe線
wire[`RDATA_WIDTH-1:0] id_op2_o;            // 連接 id 與 id_exe線
wire[`RADDR_WIDTH-1:0] id_reg_waddr_o;      // 連接 id 與 id_exe線
wire id_reg_we_o;                           // 連接 id 與 id_exe線
wire [`ADDR_WIDTH-1:0] id_inst_addr_o;      // 連接 id 與 id_exe線
wire id_stallreq_o;                         //to ctrl

wire                        id_csr_we_o;
wire[`CSR_ADDR_WIDTH-1:0]   id_csr_addr_o;
wire[`DATA_WIDTH-1:0] id_exception_o;

id id0(
    .rst_i(rst_i),

    .inst_addr_i(if_id_inst_addr_o),  //from if_id
    .inst_i(if_id_inst_o),            //from if_id

    .exe_reg_waddr_i(exe_reg_waddr_o), // from exe
    .exe_reg_wdata_i(exe_reg_wdata_o), // from exe
    .exe_reg_we_i(exe_reg_we_o), // from exe

    .mem_reg_waddr_i(mem_reg_waddr_o), // from mem
    .mem_reg_wdata_i(mem_reg_wdata_o), // from mem
    .mem_reg_we_i(mem_reg_we_o), // from mem

    .rd_i(id_exe_rd_o),   //from id_exe
    .inst_is_load_i(id_exe_inst_is_load_o),  //from id_exe

    .reg1_rdata_i(reg1_data_o), //from regfile
    .reg2_rdata_i(reg2_data_o), //from regfile

    .stallreq_o(id_stallreq_o),    //to ctrl

    .reg1_re_o(id_reg1_re_o),           //to regfile
    .reg1_raddr_o(id_reg1_addr_o),   //to regfile
    .reg2_re_o(id_reg2_re_o),           //to regfile
    .reg2_raddr_o(id_reg2_addr_o),   //to regfile

    .inst_o(id_inst_o),              //to id_exe
    .op1_o(id_op1_o),                //to id_exe
    .op2_o(id_op2_o),                //to id_exe
    .reg_waddr_o(id_reg_waddr_o),    //to id_exe
    .reg_we_o(id_reg_we_o),           //to id_exe
    .inst_addr_o(id_inst_addr_o),     //to id_exe

    //for csr
    //to id_exe
    .csr_we_o(id_csr_we_o),
    .csr_addr_o(id_csr_addr_o),

    .exception_o(id_exception_o)
);


//regfile

regfile regfile0(
    .clk_i(clk_i),
    .rst_i(rst_i),

    .we_i(mem_wb_reg_we_o),            // form WB
    .waddr_i(mem_wb_reg_waddr_o),          // form WB
    .wdata_i(mem_wb_reg_wdata_o),          // form WB

    .re1_i(id_reg1_re_o),             // form id
    .re2_i(id_reg2_re_o),             // form id
    .raddr1_i(id_reg1_addr_o),       // form id
    .raddr2_i(id_reg2_addr_o),       // form id

    .rdata1_o(reg1_data_o),          // to id
    .rdata2_o(reg2_data_o)           // to id
);


//ID_EXE
wire[`RDATA_WIDTH-1:0] id_exe_op1_o;             //id_exe to exe
wire[`RDATA_WIDTH-1:0] id_exe_op2_o;             //id_exe to exe
wire[`RADDR_WIDTH-1:0] id_exe_reg_waddr_o;       //id_exe to exe
wire[`DATA_WIDTH-1:0] id_exe_inst_o;             //id_exe to exe
wire id_exe_reg_we_o;                            //id_exe to exe

// id_exe to id
wire [`RADDR_WIDTH-1:0] id_exe_rd_o;
wire id_exe_inst_is_load_o;
wire [`ADDR_WIDTH-1:0] id_exe_inst_addr_o;

wire                        id_exe_csr_we_o;
wire[`CSR_ADDR_WIDTH-1:0]   id_exe_csr_addr_o;
wire[`DATA_WIDTH-1:0] id_exe_exception_o;
id_exe id_exe0(
    .rst_i(rst_i),
    .clk_i(clk_i),

//from ctrl
    .stall_i(ctrl_stall_o), 
    .flush_jump_i(flush_jump_o),


    .flush_int_i(pctrl_flush_int_o), //for int

// to id
    .rd_o(id_exe_rd_o),
    .inst_is_load_o(id_exe_inst_is_load_o),

    .op1_i(id_op1_o),                           //from id
    .op2_i(id_op2_o),                           //from id
    .reg_waddr_i(id_reg_waddr_o),               //from id
    .inst_i(id_inst_o),                         //from id
    .reg_we_i(id_reg_we_o),                     //from id
    .inst_addr_i(id_inst_addr_o),               //from id

    .op1_o(id_exe_op1_o),                            //to exe
    .op2_o(id_exe_op2_o),                            //to exe
    .reg_waddr_o(id_exe_reg_waddr_o),                //to exe
    .inst_o(id_exe_inst_o),                      //to exe
    .reg_we_o(id_exe_reg_we_o),                   //to exe
    .inst_addr_o(id_exe_inst_addr_o),

    //for csr
    //from id
    .csr_we_i(id_csr_we_o),
    .csr_addr_i(id_csr_addr_o),
    //to exe
    .csr_we_o(id_exe_csr_we_o),
    .csr_addr_o(id_exe_csr_addr_o),

    //for exception
    .exception_i(id_exception_o),
    .exception_o(id_exe_exception_o)
);

//EXE
wire[`RADDR_WIDTH-1:0] exe_reg_waddr_o;
wire exe_reg_we_o;
wire[`RDATA_WIDTH-1:0] exe_reg_wdata_o;

wire[`ADDR_WIDTH-1:0] exe_mem_addr_o;
wire[`DATA_WIDTH-1:0] exe_mem_data_o;
wire[3:0] exe_mem_op_o;
wire exe_mem_we_o;
wire[`ADDR_WIDTH-1:0] exe_jump_addr_o;
wire exe_jump_we_o;
wire exe_stallreq_o;
wire [`ADDR_WIDTH-1:0] exe_inst_addr_o;

//for csr 
wire                        exe_csr_we_o;
wire[`CSR_ADDR_WIDTH-1:0]   exe_csr_waddr_o;
wire[`DATA_WIDTH-1:0]       exe_csr_wdata_o;
wire[`CSR_ADDR_WIDTH-1:0]   exe_csr_raddr_o;

wire [`DATA_WIDTH-1:0] exe_exception_o;
exe exe0(
    .rst_i(rst_i),
    .clk_i(clk_i),
    
    .op1_i(id_exe_op1_o),
    .op2_i(id_exe_op2_o),
    .reg_waddr_i(id_exe_reg_waddr_o),
    .inst_i(id_exe_inst_o),
    .reg_we_i(id_exe_reg_we_o),
    .inst_addr_i(id_exe_inst_addr_o),
// to exe_mem
    .reg_waddr_o(exe_reg_waddr_o),
    .reg_wdata_o(exe_reg_wdata_o),
    .reg_we_o(exe_reg_we_o),

    .mem_addr_o(exe_mem_addr_o),
    .mem_data_o(exe_mem_data_o),
    .mem_op_o(exe_mem_op_o),
    .mem_we_o(exe_mem_we_o),
    .inst_addr_o(exe_inst_addr_o),

// to ctrl
    .jump_addr_o(exe_jump_addr_o),
    .jump_we_o(exe_jump_we_o),
    .stallreq_o(exe_stallreq_o),

//for csr
    //from id_exe
    .csr_addr_i(id_exe_csr_addr_o),
    .csr_we_i(id_exe_csr_we_o),
    //to exe_mem
    .csr_we_o(exe_csr_we_o),
    .csr_waddr_o(exe_csr_waddr_o),
    .csr_wdata_o(exe_csr_wdata_o),
    //to/from csr_file
    .csr_rdata_i(csr_file_csr_rdata_o),
    .csr_raddr_o(exe_csr_raddr_o),
    //from mem
    .mem_csr_we_i(mem_csr_we_o),
    .mem_csr_waddr_i(mem_csr_waddr_o),
    .mem_csr_wdata_i(mem_csr_wdata_o),
    //for exception
    .exception_i(id_exe_exception_o),
    .exception_o(exe_exception_o)
);

//EXE_MEM
wire[`RADDR_WIDTH-1:0] exe_mem_reg_waddr_o;
wire exe_mem_reg_we_o;
wire[`RDATA_WIDTH-1:0] exe_mem_reg_wdata_o;

wire[`ADDR_WIDTH-1:0] exe_mem_s_mem_addr_o;
wire[`DATA_WIDTH-1:0] exe_mem_s_mem_data_o;
wire[3:0] exe_mem_s_mem_op_o;
wire exe_mem_s_mem_we_o;
wire [`ADDR_WIDTH-1:0] exe_mem_inst_addr_o;

//for csr to mem 
wire                        exe_mem_csr_we_o;
wire[`CSR_ADDR_WIDTH-1:0]   exe_mem_csr_waddr_o;
wire[`DATA_WIDTH-1:0]       exe_mem_csr_wdata_o;

wire [`DATA_WIDTH-1:0] exe_mem_exception_o;
exe_mem exe_mem0(
    .clk_i(clk_i),
    .rst_i(rst_i),
//form exe
    .reg_waddr_i(exe_reg_waddr_o),
    .reg_wdata_i(exe_reg_wdata_o), 
    .reg_we_i(exe_reg_we_o),

//for interrupt ctrl
    .inst_addr_i(exe_inst_addr_o),
    .inst_addr_o(exe_mem_inst_addr_o),
    .flush_int_i(pctrl_flush_int_o), //for int

// to mem
    .reg_waddr_o(exe_mem_reg_waddr_o),
    .reg_wdata_o(exe_mem_reg_wdata_o),
    .reg_we_o(exe_mem_reg_we_o),
// store from exe
    .mem_addr_i(exe_mem_addr_o),
    .mem_data_i(exe_mem_data_o),
    .mem_op_i(exe_mem_op_o),
    .mem_we_i(exe_mem_we_o),
// store to mem 
    .mem_addr_o(exe_mem_s_mem_addr_o),
    .mem_data_o(exe_mem_s_mem_data_o),
    .mem_op_o(exe_mem_s_mem_op_o),
    .mem_we_o(exe_mem_s_mem_we_o),

    //for csr
    //from exe
    .csr_we_i(exe_csr_we_o),
    .csr_waddr_i(exe_csr_waddr_o),
    .csr_wdata_i(exe_csr_wdata_o),
    //to mem
    .csr_we_o(exe_mem_csr_we_o),
    .csr_waddr_o(exe_mem_csr_waddr_o),
    .csr_wdata_o(exe_mem_csr_wdata_o),

    //for exception
    .exception_i(exe_exception_o),
    .exception_o(exe_mem_exception_o)
);


// //RAM
// wire[`DATA_WIDTH-1:0] ram_data_o;

// localparam int MemSize = 32'h200000;
// localparam int MemAddrWidth = 21;

// ram #(
//     .RAM_SIZE(MemSize), 
//     .RAM_ADDR_WIDTH(MemAddrWidth)
// ) ram0 (
//     .rst_i(rst_i),
//     .clk_i(clk_i),
//     .addr_i(mem_mem_addr_o),
//     .data_i(mem_mem_data_o),
//     .we_i(mem_mem_we_o),
//     .ram_ce_i(mem_ram_ce_o),
//     .data_o(ram_data_o)
// );

//MEM

wire[`RADDR_WIDTH-1:0] mem_reg_waddr_o;
wire mem_reg_we_o;
wire[`RDATA_WIDTH-1:0] mem_reg_wdata_o;
// wire[`ADDR_WIDTH-1:0] mem_mem_addr_o;
// wire mem_mem_we_o;
// wire[`DATA_WIDTH-1:0] mem_mem_data_o;
// wire mem_ram_ce_o;
wire mem_halt_o;

//for csr to mem_wb
wire                        mem_csr_we_o;
wire[`CSR_ADDR_WIDTH-1:0]   mem_csr_waddr_o;
wire[`DATA_WIDTH-1:0]       mem_csr_wdata_o;

//to interrupt ctrl
wire[`ADDR_WIDTH-1:0]       memtoictrl_inst_addr_o;

// to pipe_ctrl
wire[`ADDR_WIDTH-1:0]       mem_inst_addr_o;

mem mem0(
    .rst_i(rst_i),
    .clk_i(clk_i),

    .reg_waddr_i(exe_mem_reg_waddr_o),
    .reg_wdata_i(exe_mem_reg_wdata_o),
    .reg_we_i(exe_mem_reg_we_o),

    .mem_addr_i(exe_mem_s_mem_addr_o),
    .mem_data_i(exe_mem_s_mem_data_o),
    .mem_op_i(exe_mem_s_mem_op_o),
    .mem_we_i(exe_mem_s_mem_we_o),

    .ram_data_i(ram_rdata_i),

    .ram_addr_o(ram_addr_o),
    .ram_data_o(ram_wdata_o),
    .ram_w_request_o(ram_we_o),
    .ram_ce_o(ram_ce_o),

    .reg_waddr_o(mem_reg_waddr_o),
    .reg_wdata_o(mem_reg_wdata_o),
    .reg_we_o(mem_reg_we_o),
    //for test halt signal
    .halt_o(mem_halt_o),

    //for csr
    //from exe_mem
    .csr_we_i(exe_mem_csr_we_o),
    .csr_waddr_i(exe_mem_csr_waddr_o),
    .csr_wdata_i(exe_mem_csr_wdata_o),
    //to mem_wb
    .csr_we_o(mem_csr_we_o),
    .csr_waddr_o(mem_csr_waddr_o),
    .csr_wdata_o(mem_csr_wdata_o),

    //to pipe_ctrl from exe_mem
    .inst_addr_o(mem_inst_addr_o),
    .inst_addr_i(exe_mem_inst_addr_o),
    //to pipe_ctrl from exe_mem
    .exception_i(exe_mem_exception_o),
    .exception_o(memtoictrl_inst_addr_o)
);

//mem_wb
wire[`RADDR_WIDTH-1:0] mem_wb_reg_waddr_o;
wire mem_wb_reg_we_o;
wire[`RDATA_WIDTH-1:0] mem_wb_reg_wdata_o;

//for csr
wire                        mem_wb_csr_we_o;
wire[`CSR_ADDR_WIDTH-1:0]   mem_wb_csr_waddr_o;
wire[`RDATA_WIDTH-1:0]      mem_wb_csr_wdata_o;

// for csrfile
wire                        wbtocsr_instret_incr_o;

mem_wb mem_wb0(
    .rst_i(rst_i),
    .clk_i(clk_i),

    //from ctrl
    // .stall_i(ctrl_stall_o),

    .reg_waddr_i(mem_reg_waddr_o),
    .reg_wdata_i(mem_reg_wdata_o),
    .reg_we_i(mem_reg_we_o),

    .reg_waddr_o(mem_wb_reg_waddr_o),
    .reg_wdata_o(mem_wb_reg_wdata_o),
    .reg_we_o(mem_wb_reg_we_o),


    //for csr
    //from mem
    .csr_we_i(mem_csr_we_o),
    .csr_waddr_i(mem_csr_waddr_o),
    .csr_wdata_i(mem_csr_wdata_o),
    //to csr_file
    //to csr
    .csr_we_o(mem_wb_csr_we_o),
    .csr_waddr_o(mem_wb_csr_waddr_o),
    .csr_wdata_o(mem_wb_csr_wdata_o),
    .instret_incr_o(wbtocsr_instret_incr_o),

    //from interrupt ctrl
    .flush_int_i(pctrl_flush_int_o)
);


// pipe ctrl
wire flush_jump_o;
wire[`ADDR_WIDTH-1:0] new_pc_o;
wire[5:0] ctrl_stall_o;
wire [`ADDR_WIDTH-1:0]  pctrltoictrl_pc_o;
wire pctrl_flush_int_o;

pipe_ctrl pipe_ctrl0(
    .rst_i(rst_i),
    .clk_i(clk_i),

    // from id
    .stallreq_from_id_i(id_stallreq_o),

    // to pc if_id id_exe exe_mem mem_wb
    .stall_o(ctrl_stall_o),

    // from exe
    .jump_addr_i(exe_jump_addr_o),
    .jump_we_i(exe_jump_we_o),
    .stallreq_from_exe_i(exe_stallreq_o),

    // from mem
    .pc_i(mem_inst_addr_o),

    // flush IF_ID, ID_EXE
    .flush_jump_o(flush_jump_o),
    // flush IF_ID, ID_EXE, EXE_MEM, MEM_WB
    .flush_int_o(pctrl_flush_int_o), 
    // change pc
    .new_pc_o(new_pc_o),

    //input from interrupt ctrl
    .isr_pc_i(ictrltopctrl_new_pc_o),
    .int_en_i(ictrltopctrl_interrupt_en_o),

    // to interrupt_ctrl for mepc
    .pc_o(pctrltoictrl_pc_o)
);


wire [`DATA_WIDTH-1:0] csr_file_csr_rdata_o;

wire csrtoctrl_mip_external_o;
wire csrtoctrl_mip_timer_o;
wire csrtoctrl_mip_software_o;
wire csrtoctrl_mstatus_ie_o;
wire csrtoctrl_mie_external_o;
wire csrtoctrl_mie_timer_o;
wire csrtoctrl_mie_software_o;
wire [`DATA_WIDTH-1:0]  csrtoctrl_mtvec_o;
wire [`DATA_WIDTH-1:0]  csrtoctrl_epc_o;

csrfile csr0(
    .clk_i(clk_i),
    .rst_i(rst_i),
    .raddr_i(exe_csr_raddr_o),
    .rdata_o(csr_file_csr_rdata_o),
    .we_i(mem_wb_csr_we_o),
    .waddr_i(mem_wb_csr_waddr_o),
    .wdata_i(mem_wb_csr_wdata_o),
    .instret_incr_i(wbtocsr_instret_incr_o),
    //interrupt signal from clint or plic
    .irq_timer_i(irq_timer_i),
    .irq_software_i(irq_software_i),  
    .irq_external_i(irq_external_i),  //from plic and not implemet now so always 0

    //to interrupt_ctrl
    .mip_external_o(csrtoctrl_mip_external_o),
    .mip_timer_o(csrtoctrl_mip_timer_o),
    .mip_software_o(csrtoctrl_mip_software_o),

    .mstatus_ie_o(csrtoctrl_mstatus_ie_o),
    .mie_external_o(csrtoctrl_mie_external_o),
    .mie_timer_o(csrtoctrl_mie_timer_o), 
    .mie_software_o(csrtoctrl_mie_software_o),
    
    .mtvec_o(csrtoctrl_mtvec_o),
    .epc_o(csrtoctrl_epc_o),          // 回來的 pc 位址

    //from i_ctrl signal
    .interrupt_type_i(ictrltocsr_interrupt_type_o),
    .cause_we_i(ictrltocsr_cause_we_o),
    .cause_i(ictrltocsr_trap_casue_o),
    .epc_we_i(ictrltocsr_epc_we_o),
    .epc_i(ictrltocsr_epc_o),
    .mstatus_ie_clear_i(ictrltocsr_mstatus_ie_clear_o),
    .mstatus_ie_set_i(ictrltocsr_mstatus_ie_set_o)
);


// dpram
// wire[31:0] if_inst_o;
// wire[`DATA_WIDTH-1:0] ram_data_o;
// localparam int MemSize = 32'h200000;
// localparam int MemAddrWidth = 21;

// dpram #(
//     .RAM_SIZE (MemSize),
//     .RAM_ADDR_WIDTH (MemAddrWidth)
// ) data_ram0(

//     .clk_i(clk_i),
//     .ce_i(ce_wire),
//     .pc_i(pc_wire),
//     .inst_o(if_inst_o),

//     .ram_ce_i(mem_ram_ce_o),
//     .addr_i(mem_mem_addr_o),
//     .data_i(mem_mem_data_o),
//     .we_i(mem_mem_we_o),
//     .data_o(ram_data_o)
// );

wire ictrltopctrl_interrupt_en_o;

wire [`DATA_WIDTH-1:0]  ictrltopctrl_new_pc_o;

wire ictrltocsr_interrupt_type_o;
wire ictrltocsr_cause_we_o;
wire [3:0] ictrltocsr_trap_casue_o;
wire ictrltocsr_epc_we_o;
wire [`DATA_WIDTH-1:0]  ictrltocsr_epc_o;
wire ictrltocsr_mstatus_ie_clear_o;
wire ictrltocsr_mstatus_ie_set_o;

interrupt_ctrl interrupt_ctrl0(
    .clk_i(clk_i),
    .rst_i(rst_i),

    // from mem
    .exception_i(memtoictrl_inst_addr_o),

    // from pipe_ctrl
    .pc_i(pctrltoictrl_pc_o),

    // from csr
    .mstatus_ie_i(csrtoctrl_mstatus_ie_o),
    .mie_external_i(csrtoctrl_mie_external_o),
    .mie_timer_i(csrtoctrl_mie_timer_o),
    .mie_sw_i(csrtoctrl_mie_software_o),

    .mip_external_i(csrtoctrl_mip_external_o),
    .mip_timer_i(csrtoctrl_mip_timer_o),
    .mip_sw_i(csrtoctrl_mip_software_o),

    .mtvec_i(csrtoctrl_mtvec_o),
    .epc_i(csrtoctrl_epc_o),
    
    //to csr 
    .interrupt_type_o(ictrltocsr_interrupt_type_o),
    .cause_we_o(ictrltocsr_cause_we_o),
    .trap_casue_o(ictrltocsr_trap_casue_o),
    
    .epc_we_o(ictrltocsr_epc_we_o),
    .epc_o(ictrltocsr_epc_o),

    .mstatus_ie_clear_o(ictrltocsr_mstatus_ie_clear_o),
    .mstatus_ie_set_o(ictrltocsr_mstatus_ie_set_o),

    // to pipeline_ctrl
    .interrupt_en_o(ictrltopctrl_interrupt_en_o),
    .new_pc_o(ictrltopctrl_new_pc_o)
);


endmodule