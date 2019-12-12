#include <sys/param.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <stdio.h>
#include <string.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#define MAX_ADDRS 16

int usage(char *cmd, int status)
{
    FILE *op = status ? stderr : stdout;
    fprintf(status ? stderr : stdout, "Usage: %s [-4|-6] host [service]\n", cmd);
    return status;
}

int main(int argc, char *argv[])
{
    struct addrinfo hints;
    struct addrinfo *result, *rp;
    int family = AF_UNSPEC;
    char *host = NULL, *service = NULL;
    int s, i;
    struct sockaddr_in *ipv4s[MAX_ADDRS] = { NULL };
    struct sockaddr_in6 *ipv6s[MAX_ADDRS] = { NULL };
    char ip_str[MAX(INET6_ADDRSTRLEN, INET_ADDRSTRLEN)];

    for (i = 1; i < argc; i++) {
        char* arg = argv[i];
        if (!strcmp(arg, "-h") ||
            !strcmp(arg, "-?") ||
            !strcmp(arg, "--help")
        ) {
            return usage(argv[0], 0);
        } else if (!strcmp(arg, "-4")) {
            family = AF_INET;
        } else if (!strcmp(arg, "-6")) {
            family = AF_INET6;
        } else if (!host) {
            host = arg;
        } else if (!service) {
            service = arg;
        } else {
            return usage(argv[0], 1);
        }

    }

    /* Obtain address(es) matching host/service */

    memset(&hints, 0, sizeof(struct addrinfo));
    hints.ai_family = family;
    hints.ai_socktype = 0;           /* Any socket type */
    hints.ai_flags = AI_ALL | AI_V4MAPPED;
    hints.ai_protocol = 0;           /* Any protocol */

    s = getaddrinfo(host, service, &hints, &result);
    if (s != 0) {
        fprintf(stderr, "%s: %s\n", argv[0], gai_strerror(s));
        return s;
    }

    /* getaddrinfo() returns a list of address structures.
       Try each address until we successfully connect(2).
       If socket(2) (or connect(2)) fails, we (close the socket
       and) try the next address. */

    for (rp = result; rp != NULL; rp = rp->ai_next) {
        if (rp->ai_family == AF_INET) {
            struct sockaddr_in *ipv4 = (struct sockaddr_in *)rp->ai_addr;
            for (i = 0; i < (sizeof ipv4s); i++) {
                if (ipv4s[i]) {
                    if (    memcmp(&ipv4->sin_addr, &ipv4s[i]->sin_addr, sizeof (struct in_addr)) ||
                            ipv4->sin_port != ipv4s[i]->sin_port) {
                        continue;   /* doesn't match, try next */
                    }
                } else {
                    ipv4s[i] = ipv4;
                }
                break;
            }
        } else if (rp->ai_family == AF_INET6) {
            struct sockaddr_in6 *ipv6 = (struct sockaddr_in6 *)rp->ai_addr;
            struct in6_addr *addr = &(ipv6->sin6_addr);
            for (i = 0; i < (sizeof ipv6s); i++) {
                if (ipv6s[i]) {
                    if (    memcmp(&ipv6->sin6_addr, &ipv6s[i]->sin6_addr, sizeof (struct in6_addr)) ||
                            ipv6->sin6_port != ipv6s[i]->sin6_port) {
                        continue;   /* doesn't match, try next */
                    }
                } else {
                    ipv6s[i] = ipv6;
                }
                break;
            }
        } else {
            fprintf(stderr, "Ignoring unknown address family: %d (not ipv4:%d or ipv6:%d)\n",
                    rp->ai_family, AF_INET, AF_INET6);
        }
    }
    /* TODO: print ports as well */
    for (i = 0; i < (sizeof ipv4s) && ipv4s[i]; i++) {
        inet_ntop(AF_INET, &ipv4s[i]->sin_addr, ip_str, sizeof ip_str);
        if (ipv4s[i]->sin_port) {
            fprintf(stdout, "%s:%d\n", ip_str, ntohs(ipv4s[i]->sin_port));
        } else {
            fprintf(stdout, "%s\n", ip_str);
        }
    }
    for (i = 0; i < (sizeof ipv6s) && ipv6s[i]; i++) {
        inet_ntop(AF_INET6, &ipv6s[i]->sin6_addr, ip_str, sizeof ip_str);
        if (ipv6s[i]->sin6_port) {
            fprintf(stdout, "[%s]:%d\n", ip_str, ntohs(ipv6s[i]->sin6_port));
        } else {
            fprintf(stdout, "%s\n", ip_str);
        }
    }

    freeaddrinfo(result);           /* No longer needed */

    return 0;
}


