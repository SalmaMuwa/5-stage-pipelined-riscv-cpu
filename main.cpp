
#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
#include <string>
#include <unordered_map>
#include <iomanip>
#include <algorithm>
#include <cstdint>

using namespace std;

// Register Mapping
unordered_map<string, uint32_t> register_map = {
    {"x0", 0}, {"zero", 0}, {"x1", 1}, {"ra", 1}, {"x2", 2}, {"sp", 2},
    {"x3", 3}, {"gp", 3}, {"x4", 4}, {"tp", 4}, {"x5", 5}, {"t0", 5},
    {"x6", 6}, {"t1", 6}, {"x7", 7}, {"t2", 7}, {"x8", 8}, {"s0", 8}, {"fp", 8},
    {"x9", 9}, {"s1", 9}, {"x10", 10}, {"a0", 10}, {"x11", 11}, {"a1", 11},
    {"x12", 12}, {"a2", 12}, {"x13", 13}, {"a3", 13}, {"x14", 14}, {"a4", 14},
    {"x15", 15}, {"a5", 15}, {"x16", 16}, {"a6", 16}, {"x17", 17}, {"a7", 17},
    {"x18", 18}, {"s2", 18}, {"x19", 19}, {"s3", 19}, {"x20", 20}, {"s4", 20},
    {"x21", 21}, {"s5", 21}, {"x22", 22}, {"s6", 22}, {"x23", 23}, {"s7", 23},
    {"x24", 24}, {"s8", 24}, {"x25", 25}, {"s9", 25}, {"x26", 26}, {"s10", 26},
    {"x27", 27}, {"s11", 27}, {"x28", 28}, {"t3", 28}, {"x29", 29}, {"t4", 29},
    {"x30", 30}, {"t5", 30}, {"x31", 31}, {"t6", 31}
};

string clean_token(string token) {
    token.erase(remove(token.begin(), token.end(), ','), token.end());
    token.erase(remove(token.begin(), token.end(), '('), token.end());
    token.erase(remove(token.begin(), token.end(), ')'), token.end());
    return token;
}

uint32_t parse_reg(string r) {
    r = clean_token(r);
    if (register_map.find(r) != register_map.end()) return register_map[r];
    return 0;
}

int32_t parse_imm(string imm_str) {
    imm_str = clean_token(imm_str);
    if (imm_str.find("0x") == 0 || imm_str.find("0X") == 0) {
        return stoi(imm_str, nullptr, 16);
    }
    return stoi(imm_str);
}

string to_hex_32(uint32_t val) {
    stringstream ss;
    ss << setfill('0') << setw(8) << hex << val;
    return ss.str();
}

int main(int argc, char* argv[]) {
    if (argc < 3) {
        cout << "Usage: " << argv[0] << " <input.s> <output.hex>" << endl;
        return 1;
    }

    ifstream infile(argv[1]);
    ofstream outfile(argv[2]);
    if (!infile.is_open() || !outfile.is_open()) {
        cerr << "Error opening input or output file." << endl;
        return 1;
    }

    string line;
    vector<string> lines;
    unordered_map<string, uint32_t> label_locations; [cite:4]
        uint32_t pc = 0;

    // Pass 1: Resolve Labels[cite: 4]
    while (getline(infile, line)) {
        size_t comment_pos = line.find('#');
        if (comment_pos != string::npos) line = line.substr(0, comment_pos);

        stringstream ss(line);
        string token;
        if (!(ss >> token)) continue;

        if (token.back() == ':') {
            string label = token.substr(0, token.size() - 1);
            label_locations[label] = pc;
            if (ss >> token) {
                lines.push_back(line.substr(line.find(token)));
                pc += 4;
            }
        }
        else {
            lines.push_back(line);
            pc += 4;
        }
    }

    // Pass 2: Translate to Machine Hex[cite: 4]
    pc = 0;
    for (const auto& l : lines) {
        stringstream ss(l);
        string op, arg1, arg2, arg3;
        ss >> op;

        uint32_t instr = 0;

        // R-Type Instructions[cite: 4]
        if (op == "add" || op == "sub" || op == "and" || op == "or" || op == "xor" || op == "sll" || op == "srl" || op == "sra" || op == "slt") {
            ss >> arg1 >> arg2 >> arg3;
            uint32_t rd = parse_reg(arg1);
            uint32_t rs1 = parse_reg(arg2);
            uint32_t rs2 = parse_reg(arg3);
            uint32_t opcode = 0x33;
            uint32_t funct3 = 0, funct7 = 0;

            if (op == "add") { funct3 = 0x0; funct7 = 0x00; }
            if (op == "sub") { funct3 = 0x0; funct7 = 0x20; }
            if (op == "sll") { funct3 = 0x1; funct7 = 0x00; }
            if (op == "slt") { funct3 = 0x2; funct7 = 0x00; }
            if (op == "xor") { funct3 = 0x4; funct7 = 0x00; }
            if (op == "srl") { funct3 = 0x5; funct7 = 0x00; }
            if (op == "sra") { funct3 = 0x5; funct7 = 0x20; }
            if (op == "or") { funct3 = 0x6; funct7 = 0x00; }
            if (op == "and") { funct3 = 0x7; funct7 = 0x00; }

            instr = (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode;
        }
        // I-Type Instructions[cite: 4]
        else if (op == "addi" || op == "andi" || op == "ori" || op == "xori" || op == "lw" || op == "jalr") {
            uint32_t opcode = (op == "lw") ? 0x03 : ((op == "jalr") ? 0x67 : 0x13);
            uint32_t funct3 = 0;

            if (op == "lw") {
                ss >> arg1 >> arg2; // lw rd, offset(rs1)
                size_t p1 = arg2.find('(');
                size_t p2 = arg2.find(')');
                int32_t imm = parse_imm(arg2.substr(0, p1));
                uint32_t rs1 = parse_reg(arg2.substr(p1 + 1, p2 - p1 - 1));
                uint32_t rd = parse_reg(arg1);
                instr = ((imm & 0xFFF) << 20) | (rs1 << 15) | (0x2 << 12) | (rd << 7) | opcode;
            }
            else {
                ss >> arg1 >> arg2 >> arg3;
                uint32_t rd = parse_reg(arg1);
                uint32_t rs1 = parse_reg(arg2);
                int32_t imm = parse_imm(arg3);

                if (op == "addi") funct3 = 0x0;
                if (op == "xori") funct3 = 0x4;
                if (op == "ori")  funct3 = 0x6;
                if (op == "andi") funct3 = 0x7;

                instr = ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode;
            }
        }
        // S-Type Instructions[cite: 4]
        else if (op == "sw") {
            ss >> arg1 >> arg2; // sw rs2, offset(rs1)
            size_t p1 = arg2.find('(');
            size_t p2 = arg2.find(')');
            int32_t imm = parse_imm(arg2.substr(0, p1));
            uint32_t rs1 = parse_reg(arg2.substr(p1 + 1, p2 - p1 - 1));
            uint32_t rs2 = parse_reg(arg1);
            uint32_t opcode = 0x23;
            uint32_t funct3 = 0x2;

            uint32_t imm_11_5 = (imm >> 5) & 0x7F;
            uint32_t imm_4_0 = imm & 0x1F;

            instr = (imm_11_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm_4_0 << 7) | opcode;
        }
        // SB-Type Instructions[cite: 4]
        else if (op == "beq" || op == "bne" || op == "blt" || op == "bge") {
            ss >> arg1 >> arg2 >> arg3;
            uint32_t rs1 = parse_reg(arg1);
            uint32_t rs2 = parse_reg(arg2);
            int32_t offset = 0;

            if (label_locations.find(clean_token(arg3)) != label_locations.end()) {
                offset = label_locations[clean_token(arg3)] - pc;
            }
            else {
                offset = parse_imm(arg3);
            }

            uint32_t opcode = 0x63;
            uint32_t funct3 = (op == "beq") ? 0x0 : ((op == "bne") ? 0x1 : ((op == "blt") ? 0x4 : 0x5));

            uint32_t imm_12 = (offset >> 12) & 0x1;
            uint32_t imm_10_5 = (offset >> 5) & 0x3F;
            uint32_t imm_4_1 = (offset >> 1) & 0xF;
            uint32_t imm_11 = (offset >> 11) & 0x1;

            instr = (imm_12 << 31) | (imm_10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm_4_1 << 8) | (imm_11 << 7) | opcode;
        }
        // UJ-Type Instructions[cite: 4]
        else if (op == "jal") {
            ss >> arg1 >> arg2;
            uint32_t rd = parse_reg(arg1);
            int32_t offset = 0;

            if (label_locations.find(clean_token(arg2)) != label_locations.end()) {
                offset = label_locations[clean_token(arg2)] - pc;
            }
            else {
                offset = parse_imm(arg2);
            }

            uint32_t opcode = 0x6F;
            uint32_t imm_20 = (offset >> 20) & 0x1;
            uint32_t imm_10_1 = (offset >> 1) & 0x3FF;
            uint32_t imm_11 = (offset >> 11) & 0x1;
            uint32_t imm_19_12 = (offset >> 12) & 0xFF;

            instr = (imm_20 << 31) | (imm_10_1 << 21) | (imm_11 << 20) | (imm_19_12 << 12) | (rd << 7) | opcode;
        }

        outfile << to_hex_32(instr) << endl;
        pc += 4;
    }

    cout << "Assembly complete. Output written to " << argv[2] << endl;
    return 0;
}
