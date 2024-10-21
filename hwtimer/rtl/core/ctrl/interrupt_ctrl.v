// 發生中斷時 , csr 告訴 intrrupt_ctrl , 再去讀 csr 有沒有開啟中斷開關 是哪個中斷
// 也就是說 , 中斷時要做的事情 , 並非指令去做 , 而是在這 ctrl 就會做

`include "defines.v"

module interrupt_ctrl(
    input wire                   clk_i,
    input wire                   rst_i,

    input wire[`DATA_WIDTH-1:0]  exception_i, //from mem (ecall, mret)  ,  每一個 bit 都是一個中斷
    input wire[`DATA_WIDTH-1:0]  pc_i,   // from pipe_ctrl

    // from csr , intrrupt_ctrl 發生中斷要透過 csr 才能得知 中斷發生 該做哪些事 中斷返回

    // mstatus_ie
    // mie_ext, mie_timer, mie_sw
    // mip_ext, mip_timer, mip_sw
    // epc （ mret回來的路 ）, mtvec

    input wire                   mstatus_ie_i,    // global interrupt enabled or not
    input wire                   mie_external_i,  // external interrupt enbled or not
    input wire                   mie_timer_i,     // timer interrupt enabled or not
    input wire                   mie_sw_i,        // sw interrupt enabled or not

    input wire                   mip_external_i,   // external interrupt pending
    input wire                   mip_timer_i,      // timer interrupt pending
    input wire                   mip_sw_i,         // sw interrupt pending

    input wire[`DATA_WIDTH-1:0]  mtvec_i,          // the trap vector
    input wire[`DATA_WIDTH-1:0]  epc_i,            // get the epc for the mret instruction

    //to csr , 確定中斷處理後 , interrupt_ctrl 會去寫入一些 csr 的值

    // epc, epc_we（除了 mret 以外 都要寫回 pc）
    // trap_cause, cause_we, interrupt_type（紀錄是中斷還異常）
    // mstatus_ie_clear（中斷發生後將 enable 關閉）, mstatus_ie_set(reset 中斷前的值)
    
    output reg                   interrupt_type_o,  // 是中斷還是異常
    output reg                   cause_we_o,
    output reg[3:0]              trap_casue_o,      // 中斷異常編號

    output reg                   epc_we_o,
    output reg[`DATA_WIDTH-1:0]  epc_o,             // 中斷處理完要回來的 pc

    output reg                   mstatus_ie_clear_o, //for interrupt
    output reg                   mstatus_ie_set_o, //for mret

    /* ---signals to other stages of the pipeline  ----*/
    // 中斷發生時 , 通知 pip_ctrl 切斷所有水管
    output reg                   interrupt_en_o,   // clear all pipeline
    output reg[`DATA_WIDTH-1:0]  new_pc_o   // pc_reg = new_pc_o（mtvec 中的 new pc）
);

    // state registers  用 4 bit 有 16 種狀態
    reg [3:0] S;        
    reg [3:0] S_nxt;

    // machine states   狀態機編號
    parameter RESET         = 4'b0001;
    parameter OPERATING     = 4'b0010;
    parameter TRAP_TAKEN    = 4'b0100;
    parameter TRAP_RETURN   = 4'b1000;

    // exception_i 從 mem 來 , 有 32 bit 但目前只實做 2 個 exception
    wire   mret, ecall;
    assign {ecall, mret}=exception_i[1:0];

    /* check there is a interrupt on pending*///  ctrl 到 csr 去讀 pending
    wire   eip; 
    wire   tip;
    wire   sip;
    wire   ip;

    assign eip = mie_external_i & mip_external_i;
    assign tip = mie_timer_i &  mip_timer_i;
    assign sip = mie_sw_i & mip_sw_i;
    assign ip = eip | tip | sip;        // 只要有一個發生就是 interrupt

    /* an interrupt need to be processed */ // (mstatus_ie_i & ip) 全局中斷開啟且是 interrupt
    wire   trap_happened;
    assign trap_happened = (mstatus_ie_i & ip) | ecall; //mstatus.MIE & MIP & MIE

    always @(posedge clk_i) begin
        if(rst_i == 1'b1)
            S <= RESET;
        else
            S <= S_nxt;
    end

    always @ (*)   begin
        case(S)
            RESET: begin
                S_nxt = OPERATING;
            end
            OPERATING: begin
                if(trap_happened)
                    S_nxt = TRAP_TAKEN;
                else if(mret)
                    S_nxt = TRAP_RETURN;
                else
                    S_nxt = OPERATING;
            end
            TRAP_TAKEN: begin           // 現在是 taken 因為不能朝狀中斷 , 所以下一個狀態就不會是中斷
                S_nxt = OPERATING;
            end
            TRAP_RETURN: begin           // 現在是 RETURN 因為不能朝狀中斷 , 所以下一個狀態就不會是中斷
                S_nxt = OPERATING;
            end
            default: begin
                S_nxt = OPERATING;
            end
        endcase
    end

    reg [29:0]         mtvec_base; // machine trap base address

    assign mtvec_base = mtvec_i[31:2]; // ISR vector base addr // 最低位 2 bit 是判斷是向量還是非向量模式

    reg[`DATA_WIDTH-1:0] trap_mux_out;
    wire [`DATA_WIDTH-1:0] vec_mux_out;
    wire [`DATA_WIDTH-1:0] base_offset;

    // mtvec = { base[maxlen-1:2], mode[1:0]}
    // The value in the BASE field must always be aligned on a 4-byte boundary, and the MODE setting may impose
    // additional alignment constraints on the value in the BASE field.
    // when mode =2'b00, direct mode, When MODE=Direct, all traps into machine mode cause the pc to be set to the address in the BASE field.
    // when mode =2'b01, Vectored mode, all synchronous exceptions into machine mode cause the pc to be set to the address in the BASE
    // field, whereas interrupts cause the pc to be set to the address in the BASE field plus four times the interrupt cause number.
    assign base_offset = {26'b0, trap_casue_o, 2'b0};  // trap_casue_o * 4
    assign vec_mux_out = mtvec_i[0] ? {mtvec_base, 2'b00} + base_offset : {mtvec_base, 2'b00};   // {mtvec_base, 2'b00} 為了補足 32 bit
    assign trap_mux_out = interrupt_type_o ? vec_mux_out : {mtvec_base, 2'b00};

// 
    reg exception;
    always @(posedge clk_i) 
        exception <= (|exception_i);        // 这表示如果exception_i中的任何一个位為1，则exception寄存器被置为1，表示发生了异常

//

    // output generation
    always @ (*)   begin
        case(S)
            RESET: begin
                interrupt_en_o = 1'b0;
                new_pc_o = `ZERO;
                epc_we_o = 1'b0;
                cause_we_o = 1'b0;
                mstatus_ie_clear_o = 1'b0;
                mstatus_ie_set_o = 1'b0;
            end

            OPERATING: begin
                interrupt_en_o = 1'b0;
                new_pc_o = `ZERO;
                epc_we_o = 1'b0;
                cause_we_o = 1'b0;
                mstatus_ie_clear_o = 1'b0;
                mstatus_ie_set_o = 1'b0;
            end

            TRAP_TAKEN: begin
                interrupt_en_o = 1'b1;          // clear all pipeline
                new_pc_o = trap_mux_out;        // jump to the trap handler 給 pc 中斷處理的位址
                epc_we_o = 1'b1;                // update the epc csr
                cause_we_o = 1'b1;              // update the mcause csr
                mstatus_ie_clear_o = 1'b1;      // disable the mie bit in the mstatus
                mstatus_ie_set_o = 1'b0;
                epc_o = (exception) ? pc_i - 4 : pc_i;
            end

            TRAP_RETURN: begin
                interrupt_en_o = 1'b1;
                new_pc_o =  epc_i;
                epc_we_o = 1'b0;
                cause_we_o = 1'b0;
                mstatus_ie_clear_o = 1'b0;
                mstatus_ie_set_o = 1'b1;      //enable the mie
            end

            default: begin
                interrupt_en_o = 1'b0;
                new_pc_o = `ZERO;
                epc_we_o = 1'b0;
                cause_we_o = 1'b0;
                mstatus_ie_clear_o = 1'b0;
                mstatus_ie_set_o = 1'b0;
            end
        endcase
    end

    always @(posedge clk_i)
    begin
        if(rst_i == 1'b1) begin
            trap_casue_o <= 4'b0;
            interrupt_type_o <= 1'b0;
        end else if(S == OPERATING) begin
            if(mstatus_ie_i & tip) begin
                trap_casue_o <= 4'd7; // M-mode timer interrupt
                interrupt_type_o <= 1'b1; //interrupt
            end else if(mstatus_ie_i & sip) begin
                trap_casue_o <= 4'd3; // M-mode software interrupt
                interrupt_type_o <= 1'b1; //interrupt
            end else if(mstatus_ie_i & eip) begin
                trap_casue_o <= 4'd11; // M-mode external interrupt
                interrupt_type_o <= 1'b1; //interrupt
            end else if(ecall) begin
                trap_casue_o <= 4'd11; // ecall from M-mode, cause = 11, exception
                interrupt_type_o <= 1'b0; //exception    
            end        
        end
    end

endmodule