#ifndef COMMON_H
#include "common.h"
#endif


class Sequencer {
private:
    std::queue<int> sqr_fifo;
public:
    int split_num = 0;  // each zero command marks the end of an hex file and rest of commands are split to next hex
    int cmd_count = 0;  // counter of commands per hex file (test phase)

    void main(const char *mem_file_name = "test.mem");

    void post_test();

    void push_seq(unsigned int val);

    void split();

    void reset();

    long size();

    void put_bytes(const char *file_path, unsigned long input_val, int word_len = Vriscv_risc_pkg::IALIGN / 8);
};


void Sequencer::main(const char *mem_file_name) {
    int val;
    cmd_count = 0;
    remove(mem_file_name);
    while (!sqr_fifo.empty()) {
        val = sqr_fifo.front();
        sqr_fifo.pop();
        if (val) {
            put_bytes(mem_file_name, val, val & 0x3 == 3 ? 4 : 2);
            cmd_count++;
        } else if (sqr_fifo.front()) {
            // not breaking if multiple zero cmds injected
            break;
        }
    }
    // push zero cmd as last command
    put_bytes(mem_file_name, 0);
}


void Sequencer::post_test() {
    split_num = 0;
}


void Sequencer::push_seq(unsigned int val) {
    sqr_fifo.push(val);
    if (!val) split_num++;
}


void Sequencer::reset() {
    while (!sqr_fifo.empty()) sqr_fifo.pop();
}


void Sequencer::split() {
    push_seq(0);
}


long Sequencer::size() {
    return sqr_fifo.size();
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
