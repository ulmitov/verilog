#ifndef COMMON_H
#include "common.h"
#endif


class Sequencer {
public:
    std::queue<int> sqr_fifo;
    int split_count = 0;    // as generators are running they will increase this with each zero command
    int cmd_count = 0;      // counter of commands per hex file (test phase)

    void main(const char *mem_file_name = "test.mem");

    void push(unsigned int val);

    void put_bytes(const char *file_path, unsigned long input_val, int word_len = Vriscv_risc_pkg::IALIGN / 8);
};


void Sequencer::main(const char *mem_file_name) {
    int val;
    cmd_count = 0;
    remove(mem_file_name);
    while (!sqr_fifo.empty()) {
        val = sqr_fifo.front();
        sqr_fifo.pop();
        put_bytes(mem_file_name, val);
        if (!val) break;
        cmd_count++;
    }
    // push zero cmd as last command
    if (val) put_bytes(mem_file_name, 0);
}


void Sequencer::push(unsigned int val) {
    sqr_fifo.push(val);
    if (!val) split_count++;
}


void Sequencer::put_bytes(const char *file_path, unsigned long input_val, int word_len) {
    int byte_val;
    FILE *fp;
    if ((fp = fopen(file_path, "a")) == NULL) {
        fprintf(stderr, "Error opening file %s\n", file_path);
        exit(1);
    }
    for (int i = word_len; i > 0; i--) {
        byte_val = (input_val >> (i - 1) * 8) & 0xFF;
        fprintf(fp, "%02x ", byte_val);
    }
    fprintf(fp, "\n");
    fclose(fp);
}
