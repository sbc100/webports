#include "machine/endian.h"

/* At the moment NaCl only runs on little-endian machines. */
#ifndef BYTE_ORDER
#define BYTE_ORDER LITTLE_ENDIAN
#endif
