// prints a list of all users
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <pwd.h>

static int usage(char* name) {
    return printf(
        "Usage: %s [-h]\n"
        "  Outputs a list of all users on this system.\n"
        "\n"
        "Arguments:\n"
        "  -h, -?, --help\tOutput this help message\n",
        name);
}

int main(int argc, char* argv[]) {
    // Optionally print uage and exit
    if (argc > 1) {
        if (    !strcmp(argv[1], "-h") ||
                !strcmp(argv[1], "-?") ||
                !strcmp(argv[1], "--help")) {
            usage(argv[0]);
            return 0;
        }
        printf("Unknown argument: '%s'\n", argv[1]);
        usage(argv[0]);
        return 1;
    }

    // Keep using getpwent() to output users
    static struct passwd* entry;
    setpwent();
    while ((entry = getpwent())) {
        printf("%s\n", entry->pw_name);
    }
    endpwent();
    return 0;
}
