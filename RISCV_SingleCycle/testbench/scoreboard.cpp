#ifndef COMMON_H
#include "common.h"
#endif

std::queue<Transaction> rx_fifo;
std::queue<Transaction> ref_fifo;


class Scoreboard {
private:
public:
    int res_count;
    int ref_count;
    int err_total;
    int err_count;

    Scoreboard(): res_count(0), err_total(0) {}

    ~Scoreboard() {
        if (err_total) {
            RETURN_CODE = 1;
            printf("##### RISCV VERIFICATION FAILED with %d errors #####\n", err_total);
        } else {
            printf("***** RISCV VERIFICATION PASSED *****\n");
        }
    }

    void write(Transaction *tx){
        rx_fifo.push(*tx);
    }

    int main() {
        int err = 0;
        if (rx_fifo.empty()) return 0;  // monitor did not send a transaction - skiping
        if (ref_fifo.empty()) {
            printf("ERROR: monitor sent a transaction but reference results are NONE");
            return 1;
        }

        Transaction &expres = ref_fifo.front();
        Transaction &recres = rx_fifo.front();

        if (recres.addr != expres.addr) {
            printf("ERROR Tr(%d): addr %08lx not as expected %08lx\n",
                res_count, recres.addr, expres.addr);
            err++;
        } else if (VERBOSITY) {
            printf("PASS Tr(%d): addr = %08lx\n", res_count, recres.addr);
        }

        if (recres.wr != expres.wr) {
            printf("ERROR Tr(%d): wr %d not as expected %d\n",
                res_count, recres.wr, expres.wr);
            err++;
        } else if (VERBOSITY)  {
            printf("PASS Tr(%d): wr = %d\n", res_count, recres.wr);
        }

        if (expres.wr) {
            if (recres.wr_data != expres.wr_data) {
                printf("ERROR Tr(%d): wr_data %08lx not as expected %08lx\n",
                    res_count, recres.wr_data, expres.wr_data);
                err++;
            } else if (VERBOSITY) {
                printf("PASS Tr(%d): wr_data = %08lx\n", res_count, recres.wr_data);
            }
        }

        // TODO: check rd_data lines by connecting peripherals
        if (!expres.wr) {
            if (recres.rd_data != expres.rd_data) {
                printf("ERROR Tr(%d): rd_data %08lx not as expected %08lx\n",
                    res_count, recres.rd_data, expres.rd_data);
                err++;
            } else if (VERBOSITY) {
                printf("PASS Tr(%d): rd_data = %08lx\n\n", res_count, recres.rd_data);
            }
        }
        ref_fifo.pop();
        rx_fifo.pop();
        res_count++;

        if (err) {
            err_count++;
            printf("WARNING: unsuccessful instructions chain:\n%s\n", expres.str);
        }
        return err;
    }

    void forward_to_set(int set_num) {
        while (!ref_fifo.empty()) {
            if (ref_fifo.front().test_id != set_num) {
                ref_fifo.pop();
                res_count++;
            } else {
                break;
            }
        }
    }

    void pre_test() {
        ref_count = ref_fifo.size();
        err_count = 0;
    }

    void post_test() {
        if (!err_count) {
            if (!ref_count || res_count != ref_count) {
                printf("ERROR: reference count is %d, res_count is %d\n\n", ref_count, res_count);
                err_total++;
            } else {
                printf("PASSED: got all %d results\n\n", ref_count);
            }
            if (!drv_fifo.empty()) {
                printf("ERROR: unsent %ld by driver\n\n", drv_fifo.size());
                err_total++;
            }
        } else {
            printf("ERROR: %d errors occurred during test\n\n", err_count);
            err_total += err_count;
        }
        res_count = 0;
        while (!ref_fifo.empty()) ref_fifo.pop();
        while (!drv_fifo.empty()) drv_fifo.pop();
    }

    char is_finished() {
        return ref_fifo.empty() && rx_fifo.empty();
    }
};
