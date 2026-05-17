#ifndef COMMON_H
#include "common.h"
#endif


class Logger {
public:
    int uid;
    int prefix = -1;
    int postfix = -1;
    const char *tpl = "vcd/%d_test%03d_phase%03d.txt";
    FILE *fptr = NULL;

    Logger(): uid(time(NULL)) {}

    ~Logger() {
        if (fptr != NULL) fclose(fptr);
    }

    void init_log() {
        // for all generators in running test the prefix remains same
        // push_ref change it on the next test.
        postfix = -1;   // phase id
        prefix++;       // test id
    }

    void start_log(int index) {
        char ch;
        char name[40];
        if (index == postfix) return;
        if (fptr != NULL) fclose(fptr);

        postfix = index;
        sprintf(name, tpl, uid, prefix, index);
        fptr = fopen(name, "a");
        if (fptr == NULL) {
            printf("ERROR: Could not open file %s\n", name);
            exit(1);
        }
    }
    
    void print_log() {
        FILE *rptr;
        char ch;
        char name[40];
        sprintf(name, tpl, uid, prefix, postfix);
        fprintf(fptr, "---------- END OF %s ----------\n", name);
        fflush(fptr);
        rptr = fopen(name, "r");
        if (rptr == NULL) {
            printf("ERROR: Could not open file %s\n", name);
            exit(1);
        }
        while ((ch = fgetc(rptr)) != EOF) putchar(ch);
        fclose(rptr);
    }
};


Logger *logger = new Logger();
