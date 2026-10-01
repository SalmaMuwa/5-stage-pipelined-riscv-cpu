// Phase 2: Unhandled 5-Stage Pipelined Core

module riscv_basic_pipeline (
    input wire clk,
    input wire rst
);
    // Pipeline Register Structures
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

    // IF Stage Components
    reg [31:0] pc;
    wire [31:0] instr;
    InstrMem imem (.addr(pc), .instr(instr));

    always @(posedge clk or posedge rst) begin
        if (rst) pc <= 0;
        else pc <= pc + 4;
    end

    // IF/ID Register
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            IF_ID_pc <= 0; IF_ID_instr <= 0;
        end else begin
            IF_ID_pc <= pc; IF_ID_instr <= instr;
        end
    end

    // ID Stage Components
    wire [31:0] rs1_data, rs2_data, imm_ext, wb_data;
    wire reg_write, alu_src, mem_to_reg, mem_read, mem_write, branch;
    wire [1:0] alu_op;

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

    // ID/EX Register
    always @(posedge clk or posedge rst) begin
        if (rst) begin
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

    // EX Stage Components
    wire [31:0] alu_b, alu_result;
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

    assign alu_b = (ID_EX_alu_src) ? ID_EX_imm : ID_EX_rs2_data;
    ALU alu (.a(ID_EX_rs1_data), .b(alu_b), .alu_ctrl(alu_ctrl), .result(alu_result), .zero(zero));

    // EX/MEM Register
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            EX_MEM_alu_result <= 0; EX_MEM_rs2_data <= 0; EX_MEM_rd_addr <= 0;
            EX_MEM_reg_write <= 0; EX_MEM_mem_to_reg <= 0;
            EX_MEM_mem_read <= 0; EX_MEM_mem_write <= 0;
        end else begin
            EX_MEM_alu_result <= alu_result; EX_MEM_rs2_data <= ID_EX_rs2_data;
            EX_MEM_rd_addr <= ID_EX_rd_addr; EX_MEM_reg_write <= ID_EX_reg_write;
            EX_MEM_mem_to_reg <= ID_EX_mem_to_reg; EX_MEM_mem_read <= ID_EX_mem_read;
            EX_MEM_mem_write <= ID_EX_mem_write;
        end
    end

    // MEM Stage Components
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
