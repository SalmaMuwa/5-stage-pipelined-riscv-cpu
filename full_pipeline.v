// Phase 3: Fully Resolved Pipelined Processor Core

// Dynamic Forwarding Unit
module ForwardingUnit (
    input wire [4:0] ID_EX_rs1,
    input wire [4:0] ID_EX_rs2,
    input wire [4:0] EX_MEM_rd,
    input wire [4:0] MEM_WB_rd,
    input wire EX_MEM_reg_write,
    input wire MEM_WB_reg_write,
    output reg [1:0] forward_a,
    output reg [1:0] forward_b
);
    always @(*) begin
        // Forward A logic
        if (EX_MEM_reg_write && (EX_MEM_rd != 0) && (EX_MEM_rd == ID_EX_rs1))
            forward_a = 2'b10;
        else if (MEM_WB_reg_write && (MEM_WB_rd != 0) && (MEM_WB_rd == ID_EX_rs1))
            forward_a = 2'b01;
        else
            forward_a = 2'b00;

        // Forward B logic
        if (EX_MEM_reg_write && (EX_MEM_rd != 0) && (EX_MEM_rd == ID_EX_rs2))
            forward_b = 2'b10;
        else if (MEM_WB_reg_write && (MEM_WB_rd != 0) && (MEM_WB_rd == ID_EX_rs2))
            forward_b = 2'b01;
        else
            forward_b = 2'b00;
    end
endmodule

// Load-Use Hazard Detection Unit
module HazardDetectionUnit (
    input wire [4:0] IF_ID_rs1,
    input wire [4:0] IF_ID_rs2,
    input wire [4:0] ID_EX_rd,
    input wire ID_EX_mem_read,
    output reg stall
);
    always @(*) begin
        if (ID_EX_mem_read && ((ID_EX_rd == IF_ID_rs1) || (ID_EX_rd == IF_ID_rs2)) && (ID_EX_rd != 0))
            stall = 1'b1;
        else
            stall = 1'b0;
    end
endmodule

// 2-Bit Dynamic Branch Predictor (Branch History Table)
module BranchPredictor (
    input wire clk,
    input wire rst,
    input wire [31:0] pc,
    input wire update_en,
    input wire [31:0] update_pc,
    input wire actual_taken,
    output wire predict_taken
);
    reg [1:0] bht [0:15]; // 16-entry 2-bit saturating counters
    wire [3:0] read_idx = pc[5:2];
    wire [3:0] update_idx = update_pc[5:2];

    assign predict_taken = bht[read_idx][1]; // MSB determines prediction

    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 16; i = i + 1) bht[i] <= 2'b01; // Default Weakly Not Taken
        end else if (update_en) begin
            case (bht[update_idx])
                2'b00: bht[update_idx] <= actual_taken ? 2'b01 : 2'b00;
                2'b01: bht[update_idx] <= actual_taken ? 2'b10 : 2'b00;
                2'b10: bht[update_idx] <= actual_taken ? 2'b11 : 2'b01;
                2'b11: bht[update_idx] <= actual_taken ? 2'b11 : 2'b10;
            endcase
        end
    end
endmodule

// Top Phase 3 Fully Resolved Core
module riscv_full_pipeline (
    input wire clk,
    input wire rst
);
    wire stall, predict_taken, actual_taken, flush;
    wire [1:0] forward_a, forward_b;
    reg [31:0] pc;
    wire [31:0] next_pc, instr;

    // Pipeline Registers
    reg [31:0] IF_ID_pc, IF_ID_instr;
    
    reg [31:0] ID_EX_pc, ID_EX_rs1_data, ID_EX_rs2_data, ID_EX_imm;
    reg [4:0]  ID_EX_rs1_addr, ID_EX_rs2_addr, ID_EX_rd_addr;
    reg [2:0]  ID_EX_funct3;
    reg        ID_EX_funct7_30;
    reg        ID_EX_reg_write, ID_EX_mem_to_reg, ID_EX_mem_read, ID_EX_mem_write, ID_EX_alu_src, ID_EX_branch;
    reg [1:0]  ID_EX_alu_op;

    reg [31:0] EX_MEM_alu_result, EX_MEM_rs2_data;
    reg [4:0]  EX_MEM_rd_addr;
    reg        EX_MEM_reg_write, EX_MEM_mem_to_reg, EX_MEM_mem_read, EX_MEM_mem_write;

    reg [31:0] MEM_WB_read_data, MEM_WB_alu_result;
    reg [4:0]  MEM_WB_rd_addr;
    reg        MEM_WB_reg_write, MEM_WB_mem_to_reg;

    // IF Stage
    InstrMem imem (.addr(pc), .instr(instr));
    BranchPredictor bp (
        .clk(clk), .rst(rst), .pc(pc),
        .update_en(ID_EX_branch), .update_pc(ID_EX_pc),
        .actual_taken(actual_taken), .predict_taken(predict_taken)
    );

    wire [31:0] branch_target = ID_EX_pc + ID_EX_imm;
    assign actual_taken = ID_EX_branch && (ID_EX_rs1_data == ID_EX_rs2_data); // Zero compare
    assign flush = ID_EX_branch && (actual_taken != predict_taken); // Misprediction flush

    assign next_pc = (flush) ? (actual_taken ? branch_target : (ID_EX_pc + 4)) :
                     (predict_taken ? (pc + {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}) : (pc + 4));

    always @(posedge clk or posedge rst) begin
        if (rst) pc <= 0;
        else if (!stall) pc <= next_pc; // Freeze PC on hazard stall
    end

    // IF/ID Register
    always @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            IF_ID_pc <= 0; IF_ID_instr <= 0;
        end else if (!stall) begin
            IF_ID_pc <= pc; IF_ID_instr <= instr;
        end
    end

    // ID Stage
    wire [31:0] rs1_data, rs2_data, imm_ext, wb_data;
    wire reg_write, alu_src, mem_to_reg, mem_read, mem_write, branch;
    wire [1:0] alu_op;

    HazardDetectionUnit hdu (
        .IF_ID_rs1(IF_ID_instr[19:15]), .IF_ID_rs2(IF_ID_instr[24:20]),
        .ID_EX_rd(ID_EX_rd_addr), .ID_EX_mem_read(ID_EX_mem_read), .stall(stall)
    );

    RegFile rf (
        .clk(clk), .reg_write(MEM_WB_reg_write), .rs1_addr(IF_ID_instr[19:15]),
        .rs2_addr(IF_ID_instr[24:20]), .rd_addr(MEM_WB_rd_addr),
        .write_data(wb_data), .rs1_data(rs1_data), .rs2_data(rs2_data)
    );
    ImmGen imm (.instr(IF_ID_instr), .imm_ext(imm_ext));
    ControlUnit ctrl (
        .opcode(IF_ID_instr[6:0]), .reg_write(reg_write), .alu_src(alu_src),
        .mem_to_reg(mem_to_reg), .mem_read(mem_read), .mem_write(mem_write),
        .branch(branch), .alu_op(alu_op)
    );

    // ID/EX Register with Stall Bubble Injection
    always @(posedge clk or posedge rst) begin
        if (rst || stall || flush) begin
            ID_EX_pc <= 0; ID_EX_rs1_data <= 0; ID_EX_rs2_data <= 0; ID_EX_imm <= 0;
            ID_EX_rs1_addr <= 0; ID_EX_rs2_addr <= 0; ID_EX_rd_addr <= 0;
            ID_EX_funct3 <= 0; ID_EX_funct7_30 <= 0;
            ID_EX_reg_write <= 0; ID_EX_mem_to_reg <= 0; ID_EX_mem_read <= 0;
            ID_EX_mem_write <= 0; ID_EX_alu_src <= 0; ID_EX_branch <= 0; ID_EX_alu_op <= 0;
        end else begin
            ID_EX_pc <= IF_ID_pc; ID_EX_rs1_data <= rs1_data; ID_EX_rs2_data <= rs2_data;
            ID_EX_imm <= imm_ext; ID_EX_rs1_addr <= IF_ID_instr[19:15];
            ID_EX_rs2_addr <= IF_ID_instr[24:20]; ID_EX_rd_addr <= IF_ID_instr[11:7];
            ID_EX_funct3 <= IF_ID_instr[14:12]; ID_EX_funct7_30 <= IF_ID_instr[30];
            ID_EX_reg_write <= reg_write; ID_EX_mem_to_reg <= mem_to_reg;
            ID_EX_mem_read <= mem_read; ID_EX_mem_write <= mem_write;
            ID_EX_alu_src <= alu_src; ID_EX_branch <= branch; ID_EX_alu_op <= alu_op;
        end
    end

    // EX Stage & Forwarding Muxes
    ForwardingUnit fwd (
        .ID_EX_rs1(ID_EX_rs1_addr), .ID_EX_rs2(ID_EX_rs2_addr),
        .EX_MEM_rd(EX_MEM_rd_addr), .MEM_WB_rd(MEM_WB_rd_addr),
        .EX_MEM_reg_write(EX_MEM_reg_write), .MEM_WB_reg_write(MEM_WB_reg_write),
        .forward_a(forward_a), .forward_b(forward_b)
    );

    reg [31:0] alu_operand_a, forwarded_rs2;
    always @(*) begin
        case (forward_a)
            2'b00: alu_operand_a = ID_EX_rs1_data;
            2'b10: alu_operand_a = EX_MEM_alu_result;
            2'b01: alu_operand_a = wb_data;
            default: alu_operand_a = ID_EX_rs1_data;
        endcase

        case (forward_b)
            2'b00: forwarded_rs2 = ID_EX_rs2_data;
            2'b10: forwarded_rs2 = EX_MEM_alu_result;
            2'b01: forwarded_rs2 = wb_data;
            default: forwarded_rs2 = ID_EX_rs2_data;
        endcase
    end

    wire [31:0] alu_b = (ID_EX_alu_src) ? ID_EX_imm : forwarded_rs2;
    wire [31:0] alu_result;
    wire zero;
    reg [3:0] alu_ctrl;

    always @(*) begin
        case (ID_EX_alu_op)
            2'b00: alu_ctrl = 4'b0000;
            2'b01: alu_ctrl = 4'b0001;
            2'b10: begin
                case (ID_EX_funct3)
                    3'b000: alu_ctrl = (ID_EX_funct7_30) ? 4'b0001 : 4'b0000;
                    3'b111: alu_ctrl = 4'b0010;
                    3'b110: alu_ctrl = 4'b0011;
                    3'b100: alu_ctrl = 4'b0100;
                    default: alu_ctrl = 4'b0000;
                endcase
            end
            default: alu_ctrl = 4'b0000;
        endcase
    end

    ALU alu (.a(alu_operand_a), .b(alu_b), .alu_ctrl(alu_ctrl), .result(alu_result), .zero(zero));

    // EX/MEM Register
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            EX_MEM_alu_result <= 0; EX_MEM_rs2_data <= 0; EX_MEM_rd_addr <= 0;
            EX_MEM_reg_write <= 0; EX_MEM_mem_to_reg <= 0;
            EX_MEM_mem_read <= 0; EX_MEM_mem_write <= 0;
        end else begin
            EX_MEM_alu_result <= alu_result; EX_MEM_rs2_data <= forwarded_rs2;
            EX_MEM_rd_addr <= ID_EX_rd_addr; EX_MEM_reg_write <= ID_EX_reg_write;
            EX_MEM_mem_to_reg <= ID_EX_mem_to_reg; EX_MEM_mem_read <= ID_EX_mem_read;
            EX_MEM_mem_write <= ID_EX_mem_write;
        end
    end

    // MEM Stage
    wire [31:0] mem_read_data;
    DataMem dmem (
        .clk(clk), .mem_read(EX_MEM_mem_read), .mem_write(EX_MEM_mem_write),
        .addr(EX_MEM_alu_result), .write_data(EX_MEM_rs2_data), .read_data(mem_read_data)
    );

    // MEM/WB Register
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            MEM_WB_read_data <= 0; MEM_WB_alu_result <= 0;
            MEM_WB_rd_addr <= 0; MEM_WB_reg_write <= 0; MEM_WB_mem_to_reg <= 0;
        end else begin
            MEM_WB_read_data <= mem_read_data; MEM_WB_alu_result <= EX_MEM_alu_result;
            MEM_WB_rd_addr <= EX_MEM_rd_addr; MEM_WB_reg_write <= EX_MEM_reg_write;
            MEM_WB_mem_to_reg <= EX_MEM_mem_to_reg;
        end
    end

    // WB Stage
    assign wb_data = (MEM_WB_mem_to_reg) ? MEM_WB_read_data : MEM_WB_alu_result;
endmodule
