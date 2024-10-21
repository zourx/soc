`include "defines.v"

module exe_type_r_m(
    input wire rst_i,
    input wire clk_i,
    
    input wire[`DATA_WIDTH-1:0] op1_i,
    input wire[`DATA_WIDTH-1:0] op2_i,
    input wire[`RDATA_WIDTH-1:0] inst_i,

    output wire stall_o,
    output reg reg_we_o,
    output reg[`RDATA_WIDTH-1:0] reg_wdata_o
);

    wire[6:0] opcode = inst_i[6:0];
    wire[2:0] funct3 = inst_i[14:12];
    wire[6:0] funct7 = inst_i[31:25];

    wire isType_r_m;
    assign isType_r_m = (opcode == `INST_TYPE_R_M);

// for slt sltu
    wire op1_ge_op2_signed;
    wire op1_ge_op2_unsigned;
    assign op1_ge_op2_signed = ($signed(op1_i) >= $signed(op2_i));
    assign op1_ge_op2_unsigned = (op1_i >= op2_i);

// for SRL , SRA
    wire[31:0] sr_shift;
    wire[31:0] sr_shift_mask;
    assign sr_shift = op1_i >> op2_i[4:0];
    assign sr_shift_mask = 32'hffffffff >> op2_i[4:0];


reg                  mult_req_o, div_req_o;

//// mul

wire is_b_zero;
assign is_b_zero = ~(|op2_i);

// 做乘除法前有號無號的暫存
reg[`DATA_WIDTH-1:0] a_o, b_o;

// 結果輸出暫存還沒做有號無號的切割
reg[`DATA_WIDTH*2-1:0] mult_result_i;

// 存做有號無號的切割
reg[`DATA_WIDTH-1:0] result;

// 乘除法器做完的訊號源
reg mult_ready_i;

// 如果乘除法器還沒做完,stall等待
assign stall_o = (mult_req_o & ~mult_ready_i)|(div_req_o & ~div_ready_i); ////

// 做負數的二補數
reg[`DATA_WIDTH*2-1:0] invert_result_m;
assign invert_result_m = (mult_req_o)? ~mult_result_i+1 : 64'b0;

//結果輸出
// assign reg_wdata_o = {32{mult_ready_i | div_ready_i}} & result; ////

// 取高位看正負號
wire is_a_neg = op1_i[`DATA_WIDTH-1];   
wire is_b_neg = op2_i[`DATA_WIDTH-1];

// 判斷同號
wire signed_adjust = is_a_neg ^ is_b_neg;

wire isType_m;
assign isType_m = (opcode == `INST_TYPE_R_M & funct7 == 0000001);

mul mul0
(
    .clk_i(clk_i),
    .rst_i(rst_i),
    .req_i(mult_req_o),
    .a_i(a_o),
    .b_i(b_o),
    .ready_o(mult_ready_i),
    .result_o(mult_result_i)
);



//// div

// 乘除法器做完的訊號源
reg div_ready_i;

// 結果輸出暫存還沒做有號無號的切割 (前餘後商)
reg[`DATA_WIDTH*2:0] div_result_i;

reg[`DATA_WIDTH-1:0] quotient;
reg[`DATA_WIDTH-1:0] remainder;

assign quotient = div_result_i[31:0];
assign remainder = div_result_i[64:33];

// 做負數的二補數
// reg[`DATA_WIDTH*2:0] invert_result_d;
// assign invert_result_d = (div_req_o)? ~div_result_i+1 : 65'b0;

// assign quotient = (div_req_o)? ~quotient+1 : quotient;
// assign remainder = (div_req_o)? ~remainder+1 : remainder;

// reg [`DATA_WIDTH-1:0] div_result_i;
reg is_q_o;

div div0(
    .clk_i(clk_i),
    .rst_i(rst_i),
    .req_i(div_req_o),
    .a_i(a_o),
    .b_i(b_o),
    .is_q_i(is_q_o),
    .result_o(div_result_i),
    .ready_o(div_ready_i)
);


always @(*) begin
    if(rst_i == 1'b1 || isType_r_m == 0) begin
        reg_we_o = `WRITE_DISABLE;
        reg_wdata_o = `ZERO;
        mult_req_o = 1'b0;
        div_req_o = 1'b0;
    end else begin
        if(isType_m == 0 & isType_r_m == 1)begin
            mult_req_o = 1'b0;
            div_req_o = 1'b0;
            case(funct3)
            `INST_ADD:begin             //add & sub
                if(funct7 == 7'b0000000)begin
                    reg_wdata_o = op1_i + op2_i;
                    reg_we_o = `WRITE_ENABLE;
                end else begin                     //sub
                reg_wdata_o = op1_i - op2_i;
                reg_we_o = `WRITE_ENABLE;
                end
            end
            `INST_XOR:begin                        //xor
                reg_wdata_o = op1_i ^ op2_i;
                reg_we_o = `WRITE_ENABLE;
            end
            `INST_OR:begin                         //or
                reg_wdata_o = op1_i | op2_i;
                reg_we_o = `WRITE_ENABLE;
            end
            `INST_AND:begin                        //and
                reg_wdata_o = op1_i & op2_i;
                reg_we_o = `WRITE_ENABLE;
            end
            `INST_SLT: begin                        //SLTI
                reg_wdata_o = {32{(~op1_ge_op2_signed)}} & 32'h1;
                reg_we_o = `WRITE_ENABLE;
            end
            `INST_SLTU: begin                       //SLTU
                reg_wdata_o = {32{(~op1_ge_op2_unsigned)}} & 32'h1;
                reg_we_o = `WRITE_ENABLE;
            end
            `INST_SLL:begin                        //sll
                if(funct7 == 7'b0000000) begin
                    reg_wdata_o = op1_i << op2_i[4:0];
                    reg_we_o = `WRITE_ENABLE;
                end else begin
                    reg_wdata_o = `ZERO;
                    reg_we_o = `WRITE_DISABLE;
                end
            end
            `INST_SRL:begin                        //srl sra
                if(funct7 == 7'b0000000) begin
                    reg_wdata_o = op1_i >> op2_i[4:0];
                    reg_we_o = `WRITE_ENABLE;
                end else if(funct7 == 7'b0100000) begin
                    reg_wdata_o = (sr_shift & sr_shift_mask) | ({32{op1_i[31]}} & (~sr_shift_mask)); 
                    reg_we_o = `WRITE_ENABLE;
                end else begin
                    reg_wdata_o = `ZERO;
                    reg_we_o = `WRITE_DISABLE;
                end
            end
            default: begin
                reg_wdata_o = `ZERO;
                reg_we_o = `WRITE_DISABLE;
                a_o = `ZERO;
                b_o = `ZERO;
            end
            endcase
        end else begin
        if(isType_m == 1 & opcode == `INST_TYPE_R_M & funct7 == 7'b0000001)begin
            reg_we_o = `WRITE_ENABLE;
            case(funct3)
            `INST_MUL:begin                      // MUL
                a_o = op1_i;
                b_o = op2_i;
                result = mult_result_i[`DATA_WIDTH-1:0];
                reg_wdata_o = {32{mult_ready_i | div_ready_i}} & result;
                mult_req_o = 1'b1;
                div_req_o = 1'b0;
            end
            `INST_MULH:begin                      // MULH
                a_o = (is_a_neg)? ~op1_i+1 : op1_i;
                b_o = (is_b_neg)? ~op2_i+1 : op2_i;
                mult_req_o = 1'b1;
                div_req_o = 1'b0;
                result = (signed_adjust)? invert_result_m[`DATA_WIDTH*2-1:`DATA_WIDTH] : mult_result_i[`DATA_WIDTH*2-1:`DATA_WIDTH];
                reg_wdata_o = {32{mult_ready_i | div_ready_i}} & result;
            end
            `INST_MULHU:begin                    // MULHU
                a_o = op1_i;
                b_o = op2_i;
                mult_req_o = 1'b1;
                div_req_o = 1'b0;
                result =  mult_result_i[`DATA_WIDTH*2-1:`DATA_WIDTH];
                reg_wdata_o = {32{mult_ready_i | div_ready_i}} & result;
            end
            `INST_MULHSU:begin                     // MULHSU
                a_o = (is_a_neg)? ~op1_i+1 : op1_i;
                b_o = op2_i;
                mult_req_o = 1'b1;
                div_req_o = 1'b0;
                result = (is_a_neg)? invert_result_m[`DATA_WIDTH*2-1:`DATA_WIDTH] : mult_result_i[`DATA_WIDTH*2-1:`DATA_WIDTH];
                reg_wdata_o = {32{mult_ready_i | div_ready_i}} & result;
            end

            `INST_DIV: begin                       // DIV
                a_o = (is_a_neg)? ~op1_i+1 : op1_i;
                b_o = (is_b_neg)? ~op2_i+1 : op2_i;
                mult_req_o = 1'b0;
                div_req_o = 1'b1;
                is_q_o = 1'b1;
                // reg_wdata_o = div_result_i;
                result = (is_b_zero)? quotient: (signed_adjust)? -quotient : quotient;
                // result = (signed_adjust)? invert_result_d[`DATA_WIDTH-1:0] : div_result_i[`DATA_WIDTH-1:0];
                reg_wdata_o = {32{mult_ready_i | div_ready_i}} & result;
            end
            `INST_DIVU: begin                       // DIVU
                a_o = op1_i;
                b_o = op2_i;
                mult_req_o = 1'b0;
                div_req_o = 1'b1;
                is_q_o = 1'b1;
                // reg_wdata_o = div_result_i;
                result = quotient;
                reg_wdata_o = {32{mult_ready_i | div_ready_i}} & result;
            end

            `INST_REM:begin                        // REM
                a_o = (is_a_neg)? ~op1_i+1 : op1_i;
                b_o = (is_b_neg)? ~op2_i+1 : op2_i;
                mult_req_o = 1'b0;
                div_req_o = 1'b1;
                is_q_o = 1'b0;
                // reg_wdata_o = div_result_i;
                result = (is_b_zero)? remainder : (is_a_neg)? -remainder : remainder;
                reg_wdata_o = {32{mult_ready_i | div_ready_i}} & result;
            end
            `INST_REMU:begin                        // REMU
                a_o = op1_i;
                b_o = op2_i;
                mult_req_o = 1'b0;
                div_req_o = 1'b1;
                is_q_o = 1'b0;
                // reg_wdata_o = div_result_i;
                result =  div_result_i[`DATA_WIDTH*2:`DATA_WIDTH+1];
                // result = (is_b_zero)? remainder: remainder;
                reg_wdata_o = {32{mult_ready_i | div_ready_i}} & result;
            end
            default: begin
                reg_wdata_o = `ZERO;
                reg_we_o = `WRITE_DISABLE;
                a_o = `ZERO;
                b_o = `ZERO;
                mult_req_o = 1'b0;
                div_req_o = 1'b0;
                result = `ZERO;
            end
            endcase
        end
        end
    end
end
endmodule


// always @(*) begin
//     if(rst_i == 1'b1 || isType_m == 0) begin
//         reg_we_o = `WRITE_DISABLE;
//         reg_wdata_o = `ZERO;
//         a_o = `ZERO;
//         b_o = `ZERO;
//         result = `ZERO;
//     end else begin
//         if(isType_m == 1 & rst_i == 1'b0)begin
//             reg_we_o = `WRITE_ENABLE;
//             case(funct3)
//             `INST_MUL:begin                      // MUL
//                 a_o = op1_i;
//                 b_o = op2_i;
//                 result = mult_result_i[`DATA_WIDTH-1:0];
//             end
//             `INST_MULH:begin                      // MULH
//                 a_o = (is_a_neg)? ~op1_i+1 : op1_i;
//                 b_o = (is_b_neg)? ~op2_i+1 : op2_i;
//                 result = (signed_adjust)? invert_result_m[`DATA_WIDTH*2-1:`DATA_WIDTH] : mult_result_i[`DATA_WIDTH*2-1:`DATA_WIDTH];
//             end
//             `INST_MULHSU:begin                    // MULHSU
//                 a_o = op1_i;
//                 b_o = op2_i;
//                 result =  mult_result_i[`DATA_WIDTH*2-1:`DATA_WIDTH];
//             end
//             `INST_MULHU:begin                     // MULHU
//                 a_o = (is_a_neg)? ~op1_i+1 : op1_i;
//                 b_o = op2_i;
//                 result = (is_a_neg)? invert_result_m[`DATA_WIDTH*2-1:`DATA_WIDTH] : mult_result_i[`DATA_WIDTH*2-1:`DATA_WIDTH];
//             end

//             `INST_DIV: begin                       // DIV
//                 a_o = (is_a_neg)? ~op1_i+1 : op1_i;
//                 b_o = (is_b_neg)? ~op2_i+1 : op2_i;
//                 result = (signed_adjust)? invert_result_d[`DATA_WIDTH-1:0] : div_result_i[`DATA_WIDTH-1:0];
//             end
//             `INST_DIVU: begin                       // DIVU
//                 a_o = op1_i;
//                 b_o = op2_i;
//                 result = mult_result_i[`DATA_WIDTH-1:0];
//             end

//             `INST_REM:begin                        // REM
//                 a_o = (is_a_neg)? ~op1_i+1 : op1_i;
//                 b_o = (is_b_neg)? ~op2_i+1 : op2_i;
//                 result = (signed_adjust)? invert_result_d[`DATA_WIDTH*2-1:`DATA_WIDTH] : div_result_i[`DATA_WIDTH*2-1:`DATA_WIDTH];
//             end
//             `INST_REMU:begin                        // REMU
//                 a_o = op1_i;
//                 b_o = op2_i;
//                 result =  mult_result_i[`DATA_WIDTH*2-1:`DATA_WIDTH];
//             end
//             default: begin
//                 reg_wdata_o = `ZERO;
//                 reg_we_o = `WRITE_DISABLE;
//                 a_o = `ZERO;
//                 b_o = `ZERO;
//                 result = `ZERO;
//             end
//             endcase
//         end
//     end
// end
