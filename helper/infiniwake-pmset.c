/*
 * Узкий privileged helper: только pmset disablesleep / displaysleepnow.
 * Принимает: on | off | display-sleep
 */
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/wait.h>

static int runPmset(char *const argv[]) {
    pid_t pid = fork();
    if (pid < 0) {
        perror("fork");
        return 1;
    }
    if (pid == 0) {
        execv("/usr/bin/pmset", argv);
        _exit(127);
    }
    int status = 0;
    if (waitpid(pid, &status, 0) < 0) {
        perror("waitpid");
        return 1;
    }
    if (WIFEXITED(status)) {
        return WEXITSTATUS(status);
    }
    return 1;
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "usage: infiniwake-pmset on|off|display-sleep\n");
        return 2;
    }

    if (strcmp(argv[1], "on") == 0) {
        char *args[] = {"pmset", "-a", "disablesleep", "1", NULL};
        return runPmset(args);
    }
    if (strcmp(argv[1], "off") == 0) {
        char *args[] = {"pmset", "-a", "disablesleep", "0", NULL};
        return runPmset(args);
    }
    if (strcmp(argv[1], "display-sleep") == 0) {
        char *args[] = {"pmset", "displaysleepnow", NULL};
        return runPmset(args);
    }

    fprintf(stderr, "infiniwake-pmset: unknown command\n");
    return 2;
}
