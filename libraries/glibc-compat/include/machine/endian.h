#ifndef GLIBCEMU_MACHINE_ENDIAN_H
#define GLIBCEMU_MACHINE_ENDIAN_H 1
#include_next <machine/endian.h>

#define __byte_swap_16(x) \
  ( (((x) & 0xff) << 8) | ((unsigned short)(x) >> 8) )
#define __byte_swap_32(x) \
        ( ((x) << 24) | \
         (((x) << 8) & 0x00ff0000) | \
         (((x) >> 8) & 0x0000ff00) | \
         ((x) >> 24) )

#define ntohs(x)   __byte_swap_16(x)
#define ntohl(x)   __byte_swap_32(x)
#define htons(x)   __byte_swap_16(x)
#define htonl(x)   __byte_swap_32(x)

#endif
