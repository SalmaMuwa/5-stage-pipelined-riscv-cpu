// Phase 1: Single-Cycle Processor Core

module PC (
    input wire clk,
    input wire rst,
    input wire [31:0] pc_in,
    output reg [31:0] pc_out
);
    always @(posedge clk or posedge rst) begin
        if (rst) pc_out <= 32'h00000000;
        else pc_out <= pc_in;
    end
endmodule

module InstrMem (
    input wire [31:0] addr,
    output wire [31:0] instr
);
    reg [31:0] mem [0:16383]; // 64KB Instruction Memory[cite: 3]
    assign instr = mem[addr[15:2]];
endmodule

module RegFile (
    input wire clk,
    input wire reg_write,
    input wire [4:0] rs1_addr,
    input wire [4:0] rs2_addr,
    input wire [4:0] rd_addr,
    input wire [31:0] write_data,
    output wire [31:0] rs1_data,
    output wire [31:0] rs2_data
);
    reg [31:0] registers [0:31];
    integer i;
    
    initial begin
        for (i = 0; i < 32; i = i + 1) registers[i] = 32'b0;
    end

    assign rs1_data = (rs1_addr == 0) ? 32'b0 : registers[rs1_addr];[cite: 3, 5]
    assign rs2_data = (rs2_addr == 0) ? 32'b0 : registers[rs2_addr];[cite: 3, 5]

    always @(posedge clk) begin
        if (reg_write && rd_addr != 0) begin
            registers[rd_addr] <= write_data;
        end
    end
endmodule

module ImmGen (
    input wire [31:0] instr,
    output reg [31:0] imm_ext
);
    wire [6:0] opcode = instr[6:0];
    always @(*) begin
        case (opcode)
            7'b0010011, 7'b0000011, 7'b1100111: // I-type[cite: 4, 11]
                imm_ext = {{20{instr[31]}}, instr[31:20]};
            7'b0100011: // S-type[cite: 4, 11]
                imm_ext = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            7'b1100011: // B-type[cite: 4, 11]
                imm_ext = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
            7'b0110111, 7'b0010111: // U-type[cite: 4, 11]
                imm_ext = {instr[31:12], 12'b0};
            7'b1101111: // J-type[cite: 4, 11]
                imm_ext = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
            default: imm_ext = 32'b0;
        endcase
    end
endmodule

module ALU (
    input wire [31:0] a,
    input wire [31:0] b,
    input wire [3:0] alu_ctrl,
    output reg [31:0] result,
    output wire zero
);
    always @(*) begin
        case (alu_ctrl)
            4'b0000: result = a + b;       // ADD
            4'b0001: result = a - b;       // SUB
            4 meb0010: result = a & b;       // AND
            4'b0011: result = a | b;       // OR
            4'b0100: result = a ^ b;       // XOR
            4'b0101: result = a << b[4:0]; // SLL
            4'b0110: result = a >> b[4:0]; // SRL
            4'b0111: result = $signed(a) >>> b[4:0]; // SRA
            4'b1000: result = (a < b) ? 32'b1 : 32'b0; // SLT
            default: result = 32'b0;
        endcase
    end
    assign zero = (result == 32'b0);
endmodule

module ControlUnit (
    input wire [6:0] opcode,
    output reg reg_write,
    output reg alu_src,
    output reg mem_to_reg,
    output reg mem_read,
    output reg mem_write,
    output reg branch,
    output reg [1:0] alu_op
);
    always @(*) begin
        case (opcode)
            7'b0110011: begin // R-Type
                reg_write = 1; alu_src = 0; mem_to_reg = 0;
                mem_read = 0; mem_write = 0; branch = 0; alu_op = 2'b10;
            end
            7'b0010011: begin // I-Type (ALU)
                reg_write = 1; alu_src = 1; mem_to_reg = 0;
                mem_read = 0; mem_write = 0; branch = 0; alu_op = 2'b10;
            end
            7'b0000011: begin // Load (lw)
                reg_write = 1; alu_src = 1; mem_to_reg = 1;
                mem_read = 1; mem_write = 0; branch = 0; alu_op = 2'b00;
            end
            7'b0100011: begin // Store (sw)
                reg_write = 0; alu_src = 1; mem_to_reg = 0;
                mem_read = 0; mem_write = 1; branch = 0; alu_op = 2'b00;
            end
            7'b1100011: begin // Branch (beq)
                reg_write = 0; alu_src = 0; mem_to_reg = 0;
                mem_read = 0; mem_write = 0; branch = 1; alu_op = 2'b01;
            end
            default: begin
                reg_write = 0; alu_src = 0; mem_to_reg = 0;
                mem_read = 0; mem_write = 0; branch = 0; alu_op = 2'b00;
            end
        endcase
    end
endmodule

module DataMem (
    input wire clk,
    input wire mem_read,
    input wire mem_write,
    input wire [31:0] addr,
    input wire [31:0] write_data,
    output wire [31:0] read_data
);
    reg [31:0] memory [0:2047]; // 8KB Data Memory[cite: 3, 11]
    assign read_data = (mem_read) ? memory[addr[12:2]] : 32'b0;

    always @(posedge clk) begin
        if (mem_write) memory[addr[12:2]] <= write_data;
    end
endmodule

// Top Single-Cycle Processor
module riscv_single_cycle (
    input wire clk,
    input wire rst
);
    wire [31:0] pc, next_pc, instr, rs1_data, rs2_data, imm_ext, alu_b, alu_result, mem_read_data, wb_data;
    wire reg_write, alu_src, mem_to_reg, mem_read, mem_write, branch, zero;
    wire [1:0] alu_op;
    reg [3:0] alu_ctrl;

    PC pc_mod (.clk(clk), .rst(rst), .pc_in(next_pc), .pc_out(pc));
    InstrMem imem (.addr(pc), .instr(instr));
    ControlUnit ctrl (
        .opcode(instr[6:0]), .reg_write(reg_write), .alu_src(alu_src),
        .mem_to_reg(mem_to_reg), .mem_read(mem_read), .mem_write(mem_write),
        .branch(branch), .alu_op(alu_op)
    );
    RegFile rf (
        .clk(clk), .reg_write(reg_write), .rs1_addr(instr[19:15]),
        .rs2_addr(instr[24:20]), .rd_addr(instr[11:7]),
        .write_data(wb_data), .rs1_data(rs1_data), .rs2_data(rs2_data)
    );
    ImmGen imm (.instr(instr), .imm_ext(imm_ext));

    always @(*) begin
        case (alu_op)
            2'b00: alu_ctrl = 4'b0000; // ADD for load/store
            2'b01: alu_ctrl = 4'b0001; // SUB for branch comparison
            2'b10: begin
                case (instr[14:12])
                    3'b000: alu_ctrl = (instr[30] && instr[6:0] == 7'b0110011) ? 4'b0001 : 4'b0000;
                    3'b111: alu_ctrl = 4'b0010;
                    3'b110: alu_ctrl = 4'b0011;
                    3'b100: alu_ctrl = 4'b0100;
                    default: alu_ctrl = 4'b0000;
                endcase
            end
            default: alu_ctrl = 4'b0000;
        endcase
    end

    assign alu_b = (alu_src) ? imm_ext : rs2_data;
    ALU alu (.a(rs1_data), .b(alu_b), .alu_ctrl(alu_ctrl), .result(alu_result), .zero(zero));
    DataMem dmem (
        .clk(clk), .mem_read(mem_read), .mem_write(mem_write),
        .addr(alu_result), .write_data(rs2_data), .read_data(mem_read_data)
    );

    assign wb_data = (mem_to_reg) ? mem_read_data : alu_result;
    assign next_pc = (branch && zero) ? (pc + imm_ext) : (pc + 4);
endmodule
