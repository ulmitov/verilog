#ifndef COMMON_H
#include "common.h"
#endif

// maybe move it later into the class
std::queue<Transaction> rx_fifo;


class Scoreboard {
private:
public:
    int ref_count;  // count of reference transactions
    int res_count;  // count of received transactions
    int err_count;  // count of errors per phase
    int err_total;  // count of errors in all tests
    Transaction expres;

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
        // monitor did not send a transaction - skiping
        if (rx_fifo.empty()) return err;
        // monitor did not send and also not expecting for any
        if ( is_finished() ) return err;

        Transaction &monreq = rx_fifo.front();

        if (!get_ref(&expres)) {
            printf( "ERROR: reference transactions are NONE, "
                    "but monitor sent a new transaction:\n%s\n", monreq.str );
            return 1;
        }
        //expres = ref_fifo.front();

        if (monreq.addr != expres.addr) {
            printf("ERROR Tr#%d: addr %08lx not as expected %08lx\n",
                res_count, monreq.addr, expres.addr);
            err++;
        } else {
            fprintf(logger->fptr, "PASS Tr#%d: addr = %08lx\n", res_count, monreq.addr);
        }

        if (monreq.wr != expres.wr) {
            printf("ERROR Tr#%d: wr %d not as expected %d\n",
                res_count, monreq.wr, expres.wr);
            err++;
        } else {
            fprintf(logger->fptr, "PASS Tr#%d: wr = %d\n", res_count, monreq.wr);
        }

        if (expres.wr) {
            if (monreq.wr_data != expres.wr_data) {
                printf("ERROR Tr#%d: wr_data %08lx not as expected %08lx\n",
                    res_count, monreq.wr_data, expres.wr_data);
                err++;
            } else {
                fprintf(logger->fptr, "PASS Tr#%d: wr_data = %08lx\n", res_count, monreq.wr_data);
            }
        }

        // TODO: check rd_data lines by connecting peripherals
        if (!expres.wr) {
            if (monreq.rd_data != expres.rd_data) {
                printf("ERROR Tr#%d: rd_data %08lx not as expected %08lx\n",
                    res_count, monreq.rd_data, expres.rd_data);
                err++;
            } else {
                fprintf(logger->fptr, "PASS Tr#%d: rd_data = %08lx\n\n", res_count, monreq.rd_data);
            }
        }
        //ref_fifo.pop();
        rx_fifo.pop();
        res_count++;

        if (err) {
            printf("WARNING: unsuccessful instructions chain:\n");
            printf("WARNING: %s\n", expres.str);
            err_count++;
        }
        return err;
    }

    void post_phase(int phase_num) {
        // forward reference transactions to next phase number
        while (!ref_fifo.empty()) {
            if (ref_fifo.front().test_id == phase_num) break;
            ref_fifo.pop();
            res_count++;
        }
    }

    void pre_test() {
        err_count = 0;
        ref_count = ref_fifo.size();
        if (!ref_count) {
            printf("WARNING: Scoreboard has none reference transactions\n\n");
        }
    }

    void post_test() {
        if (err_count) {
            printf("ERROR: %d errors occurred during test\n\n", err_count);
            err_total += err_count;
        } else {
            if (!rx_fifo.empty()) {
                printf("ERROR: scoreboard fifo has %ld unverified transactions\n\n", rx_fifo.size());
                err_total++;
            }
            if (res_count != ref_count || !ref_fifo.empty()) {
                printf("ERROR: reference count is %d, res_count is %d,"
                    "reference fifo has %ld unverified transactions\n\n",
                    ref_count, res_count, ref_fifo.size());
                err_total++;
            } else {
                printf("INFO: PASSED: got all %d results\n\n", ref_count);
            }
        }
        res_count = 0;
        while (!rx_fifo.empty()) rx_fifo.pop();
        while (!ref_fifo.empty()) ref_fifo.pop();
    }

    char is_finished() {
        return ref_fifo.empty() && rx_fifo.empty();
    }
};
