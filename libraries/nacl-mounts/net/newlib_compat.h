/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_BASE_NEWLIB_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_BASE_NEWLIB_H_

#include <assert.h>

typedef uint32_t socklen_t;
struct sockaddr {
  uint16_t sa_family;
  char sa_data[14];
};

typedef uint32_t in_addr_t;
typedef uint16_t in_port_t;

struct in_addr {
  in_addr_t s_addr;
};

struct sockaddr_in {
  uint16_t sin_family;
  uint16_t sin_port;
  struct in_addr sin_addr;
  char sin_zero[8];
};

typedef struct addrinfo {
  int   ai_flags;
  int   ai_family;
  int   ai_socktype;
  int   ai_protocol;
  size_t  ai_addrlen;
  struct  sockaddr *ai_addr;
  char* ai_canonname;   /* canonical name */
  struct  addrinfo *ai_next; /* this struct can form a linked list */
} ADDRINFOA;

struct in6_addr {
  uint8_t  s6_addr[16];  /* IPv6 address */
};

#define AF_INET 1
#define AF_INET6 2
#define AF_UNSPEC 4
#define SOCK_STREAM 1
#define SOCK_DGRAM 2

#define EAI_FAIL 1
#define AI_PASSIVE 1
#define AI_NUMERICHOST 2
#define AI_CANONNAME 3
#define EAI_FAMILY 2

#define NI_MAXHOST 256

#ifndef INET_ADDRSTRLEN
#define INET_ADDRSTRLEN 16
#endif

struct hostent {
  char*   h_name;        /* official name of host */
  char**  h_aliases;    /* alias list */
  int     h_addrtype;     /* host address type */
  int     h_length;       /* length of address */
  char**  h_addr_list;  /* list of addresses */
};

#define h_addr  h_addr_list[0]  /* for backward compatibility */

static uint16_t htons(uint16_t v) {
  assert(0);
}
uint16_t ntohs(uint16_t v) {
  assert(0);
}

const char*
inet_ntop(int af, const void *src, char *dst, socklen_t cnt) {
  assert(0);
}
int inet_pton(int af, const char* src, void* dst) {
  assert(0);
}

struct sockaddr_in6 {
  uint16_t        sin6_family;   /* AF_INET6     */
  in_port_t       sin6_port;     /* Transport layer port #   */
  uint32_t        sin6_flowinfo; /* IPv6 flow information    */
  struct in6_addr sin6_addr;     /* IPv6 address       */
};

#endif  // PACKAGES_LIBRARIES_NACL_MOUNTS_BASE_NEWLIB_H_

