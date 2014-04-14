/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include <arpa/inet.h>
#include <errno.h>
#include <grp.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <syslog.h>
#include <sys/signal.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <termios.h>
#include <unistd.h>

/*
 * This file contains stubs for functions that are present in glibc
 * by missing in newlib.
 *
 * These stubs are implemented in one of 3 different ways:
 *  1) return a fake answer (e.g. umask()).
 *  2) Report and error and abort (e.g unlink()).
 *  3) return and error and set errno to ENOSYS (e.g. accept()).
 *
 * TODO(sbc): Figure out the rational for why each function is implemented
 * in a given way, and be more consistent.
 */

#define UNIMPLEMENTED_FATAL()                                            \
  fprintf(stderr,                                                        \
          "Function %s is not implemented in glibc-compat, aborting!\n", \
          __FUNCTION__);                                                 \
  abort();

#define UNIMPLEMENTED() \
  fprintf(stderr, "Function %s is not implemented in glibc-compat!\n", \
          __FUNCTION__);

#define UNIMPLEMENTED_NOSYS_RTN(RTN) \
  UNIMPLEMENTED(); \
  errno = ENOSYS; \
  return RTN; \

#define UNIMPLEMENTED_NOSYS() UNIMPLEMENTED_NOSYS_RTN(-1)


#undef htonl
#undef htons
#undef ntohl
#undef ntohs

int accept(int sockfd, struct sockaddr *addr,
           socklen_t *addrlen) __attribute__((weak));
int accept(int sockfd, struct sockaddr *addr, socklen_t *addrlen) {
  UNIMPLEMENTED_NOSYS();
}

int bind(int sockfd, const struct sockaddr *addr,
         socklen_t addrlen) __attribute__((weak));
int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen) {
  UNIMPLEMENTED_NOSYS();
}

int eaccess(const char *pathname, int mode) __attribute__((weak));
int eaccess(const char *pathname, int mode) {
  return access(pathname, mode);
}

#if NACL_SDK_VERSION < 34
speed_t cfgetispeed(const struct termios *termios_p) __attribute__((weak));
speed_t cfgetispeed(const struct termios *termios_p) {
  return termios_p->c_ispeed;
}

speed_t cfgetospeed(const struct termios *termios_p) __attribute__((weak));
speed_t cfgetospeed(const struct termios *termios_p) {
  return termios_p->c_ospeed;
}

int cfsetispeed(struct termios *termios_p, speed_t speed) __attribute__((weak));
int cfsetispeed(struct termios *termios_p, speed_t speed) {
  termios_p->c_ispeed = speed;
  return 0;
}

int cfsetospeed(struct termios *termios_p, speed_t speed) __attribute__((weak));
int cfsetospeed(struct termios *termios_p, speed_t speed) {
  termios_p->c_ospeed = speed;
  return 0;
}

int cfsetspeed(struct termios *termios_p, speed_t speed) __attribute__((weak));
int cfsetspeed(struct termios *termios_p, speed_t speed) {
  termios_p->c_ispeed = speed;
  termios_p->c_ospeed = speed;
  return 0;
}
#endif

void endgrent(void) __attribute__((weak));
void endgrent(void) {
  UNIMPLEMENTED();
}

struct group *getgrent(void) __attribute__((weak));
struct group *getgrent(void) {
  UNIMPLEMENTED_NOSYS_RTN(NULL);
}

struct group *getgrnam(const char *name) __attribute__((weak));
struct group *getgrnam(const char *name) {
  UNIMPLEMENTED_NOSYS_RTN(NULL);
}

struct group *getgrgid(gid_t gid) __attribute__((weak));
struct group *getgrgid(gid_t gid) {
  UNIMPLEMENTED_NOSYS_RTN(NULL);
}

struct hostent *gethostbyaddr(const void *addr,
                              socklen_t len, int type) __attribute__((weak));
struct hostent *gethostbyaddr(const void *addr,
                              socklen_t len, int type) {
  UNIMPLEMENTED_NOSYS_RTN(NULL);
}

struct hostent *gethostbyname(const char *name) __attribute__((weak));
struct hostent *gethostbyname(const char *name) {
  UNIMPLEMENTED_NOSYS_RTN(NULL);
}

int gethostname(char *name, size_t len) __attribute__((weak));
int gethostname(char *name, size_t len) {
  UNIMPLEMENTED_NOSYS();
}

int getpeername(int sockfd, struct sockaddr *addr,
                socklen_t *addrlen) __attribute__((weak));
int getpeername(int sockfd, struct sockaddr *addr, socklen_t *addrlen) {
  UNIMPLEMENTED_NOSYS();
}

struct servent *getservbyport(int port,
                              const char *proto) __attribute__((weak));
struct servent *getservbyport(int port, const char *proto) {
  UNIMPLEMENTED_FATAL();
}

int getsockname(int sockfd, struct sockaddr *addr,
                socklen_t *addrlen) __attribute__((weak));
int getsockname(int sockfd, struct sockaddr *addr,
                socklen_t *addrlen) {
  UNIMPLEMENTED_FATAL();
}

int getsockopt(int sockfd, int level, int optname,
               void *optval, socklen_t *optlen) __attribute__((weak));
int getsockopt(int sockfd, int level, int optname,
               void *optval, socklen_t *optlen) {
 UNIMPLEMENTED_FATAL();
}

uint32_t htonl(uint32_t hostlong) __attribute__((weak));
uint32_t htonl(uint32_t hostlong) {
  UNIMPLEMENTED_FATAL();
}

uint16_t htons(uint16_t hostshort) __attribute__((weak));
uint16_t htons(uint16_t hostshort) {
  UNIMPLEMENTED_FATAL();
}

const char *inet_ntop(int af, const void *src,
                      char *dst, socklen_t size) __attribute__((weak));
const char *inet_ntop(int af, const void *src,
                      char *dst, socklen_t size) {
  UNIMPLEMENTED_FATAL();
}

char *inet_ntoa(struct in_addr in) __attribute__((weak));
char *inet_ntoa(struct in_addr in) {
  UNIMPLEMENTED_FATAL();
}

int listen(int sockfd, int backlog) __attribute__((weak));
int listen(int sockfd, int backlog) {
  UNIMPLEMENTED_FATAL();
}

dev_t makedev(int maj, int min)  __attribute__((weak));
dev_t makedev(int maj, int min) {
  return ((maj & 0xff) << 8 | (min & 0xff));
}

int major(dev_t dev) __attribute__((weak));
int major(dev_t dev) {
  return (dev >> 8) & 0xff;
}

int minor(dev_t dev) __attribute__((weak));
int minor(dev_t dev) {
  return dev & 0xff;
}

uint32_t ntohl(uint32_t netlong) __attribute__((weak));
uint32_t ntohl(uint32_t netlong) {
  UNIMPLEMENTED_FATAL();
}

uint16_t ntohs(uint16_t netshort) __attribute__((weak));
uint16_t ntohs(uint16_t netshort) {
  UNIMPLEMENTED_FATAL();
}

ssize_t recv(int sockfd, void *buf, size_t len,
             int flags) __attribute__((weak));
ssize_t recv(int sockfd, void *buf, size_t len, int flags) {
  UNIMPLEMENTED_FATAL();
}

ssize_t recvfrom(int sockfd, void *buf, size_t len, int flags,
                 struct sockaddr *src_addr,
                 socklen_t *addrlen) __attribute__((weak));
ssize_t recvfrom(int sockfd, void *buf, size_t len, int flags,
                 struct sockaddr *src_addr,
                 socklen_t *addrlen) {
  UNIMPLEMENTED_FATAL();
}

ssize_t send(int sockfd, const void *buf, size_t len,
             int flags) __attribute__((weak));
ssize_t send(int sockfd, const void *buf, size_t len, int flags) {
  UNIMPLEMENTED_FATAL();
}

ssize_t sendto(int sockfd, const void *buf, size_t len, int flags,
               const struct sockaddr *dest_addr,
               socklen_t addrlen) __attribute__((weak));
ssize_t sendto(int sockfd, const void *buf, size_t len, int flags,
               const struct sockaddr *dest_addr,
               socklen_t addrlen) {
  UNIMPLEMENTED_FATAL();
}

void setgrent(void) __attribute__((weak));
void setgrent(void) {
  UNIMPLEMENTED();
}

int setsockopt(int sockfd, int level, int optname,
               const void *optval, socklen_t optlen) __attribute__((weak));
int setsockopt(int sockfd, int level, int optname,
               const void *optval, socklen_t optlen) {
 UNIMPLEMENTED_FATAL();
}

int shutdown(int sockfd, int how) __attribute__((weak));
int shutdown(int sockfd, int how) {
  UNIMPLEMENTED_FATAL();
}

int sigsuspend(const sigset_t *mask) __attribute__((weak));
int sigsuspend(const sigset_t *mask) {
  UNIMPLEMENTED_NOSYS();
}

int sigaction(int signum, const struct sigaction *act,
                     struct sigaction *oldact) __attribute__((weak));
int sigaction(int signum, const struct sigaction *act,
                     struct sigaction *oldact) {
  UNIMPLEMENTED_NOSYS();
}

int socketpair(int domain, int type, int protocol,
               int sv[2]) __attribute__((weak));
int socketpair(int domain, int type, int protocol,
               int sv[2]) {
  UNIMPLEMENTED_FATAL();
}

#if NACL_SDK_VERSION < 34
int tcdrain(int fd) __attribute__((weak));
int tcdrain(int fd) {
  UNIMPLEMENTED_NOSYS();
}

int tcflow(int fd, int action) __attribute__((weak));
int tcflow(int fd, int action) {
  UNIMPLEMENTED_NOSYS();
}

int tcflush(int fd, int queue_selector) __attribute__((weak));
int tcflush(int fd, int queue_selector) {
  UNIMPLEMENTED_NOSYS();
}

int tcgetattr(int fd, struct termios *termios_p) __attribute__((weak));
int tcgetattr(int fd, struct termios *termios_p) {
  UNIMPLEMENTED_NOSYS();
}

int tcsendbreak(int fd, int duration) __attribute__((weak));
int tcsendbreak(int fd, int duration) {
  UNIMPLEMENTED_NOSYS();
}

int tcsetattr(int fd, int optional_actions,
              const struct termios *termios_p) __attribute__((weak));
int tcsetattr(int fd, int optional_actions,
              const struct termios *termios_p) {
  UNIMPLEMENTED_NOSYS();
}
#endif

FILE *popen(const char *command, const char *type) __attribute__ ((weak));
FILE *popen(const char *command, const char *type) {
  UNIMPLEMENTED_FATAL();
}

int pclose(FILE *stream) __attribute__ ((weak));
int pclose(FILE *stream) {
  UNIMPLEMENTED_NOSYS();
}

int system(const char *command) __attribute__ ((weak));
int system(const char *command) {
  UNIMPLEMENTED_NOSYS();
}

int execl(const char *path, const char *arg, ...) __attribute__ ((weak));
int execl(const char *path, const char *arg, ...) {
  UNIMPLEMENTED_NOSYS();
}

int execlp(const char *file, const char *arg, ...) __attribute__ ((weak));
int execlp(const char *file, const char *arg, ...) {
  UNIMPLEMENTED_NOSYS();
}

int execv(const char *path, char *const argv[]) __attribute__ ((weak));
int execv(const char *path, char *const argv[]) {
  UNIMPLEMENTED_NOSYS();
}

void openlog(const char *ident, int option, int facility)
    __attribute__ ((weak));
void openlog(const char *ident, int option, int facility) {
  UNIMPLEMENTED_FATAL();
}

void syslog(int priority, const char *format, ...) __attribute__ ((weak));
void syslog(int priority, const char *format, ...) {
  UNIMPLEMENTED_FATAL();
}

void closelog(void) __attribute__ ((weak));
void closelog(void) {
  UNIMPLEMENTED_FATAL();
}

ssize_t readv(int fd, const struct iovec *iov, int iovcnt)
    __attribute__ ((weak));
ssize_t readv(int fd, const struct iovec *iov, int iovcnt) {
  UNIMPLEMENTED_FATAL();
}

int initgroups(const char *user, gid_t group) __attribute__ ((weak));
int initgroups(const char *user, gid_t group) {
  UNIMPLEMENTED_FATAL();
}

int getgroups(int size, gid_t list[]) __attribute__ ((weak));
int getgroups(int size, gid_t list[]) {
  UNIMPLEMENTED_FATAL();
}

int setgroups(size_t size, const gid_t *list) __attribute__ ((weak));
int setgroups(size_t size, const gid_t *list) {
  UNIMPLEMENTED_FATAL();
}

pid_t setsid(void) __attribute__ ((weak));
pid_t setsid(void) {
  UNIMPLEMENTED_FATAL();
}

int socket(int domain, int type, int protocol) __attribute__ ((weak));
int socket(int domain, int type, int protocol) {
  UNIMPLEMENTED_FATAL();
}

int connect(int sockfd, const struct sockaddr *addr,
            socklen_t addrlen) __attribute__ ((weak));
int connect(int sockfd, const struct sockaddr *addr,
                   socklen_t addrlen) {
  UNIMPLEMENTED_FATAL();
}

char* realpath(const char* path, const char* resolved) __attribute__ ((weak));
char* realpath(const char* path, const char* resolved) {
  UNIMPLEMENTED_NOSYS_RTN(NULL);
}

int getaddrinfo(const char *, const char *, const struct addrinfo *,
                struct addrinfo **) __attribute__ ((weak));
int getaddrinfo(const char *node, const char *service,
                const struct addrinfo *hints, struct addrinfo **res) {
  errno = ENOSYS;
  UNIMPLEMENTED_NOSYS_RTN(EAI_SYSTEM);
}

void freeaddrinfo(struct addrinfo *) __attribute__ ((weak));
void freeaddrinfo(struct addrinfo *res) {
  UNIMPLEMENTED();
}

char *gai_strerror(int) __attribute__ ((weak));
char *gai_strerror(int errcode) {
  UNIMPLEMENTED_NOSYS_RTN(NULL);
}
