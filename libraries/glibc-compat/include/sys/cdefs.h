#ifndef GLIBCEMU_SYS_CDEFS_H
#define GLIBCEMU_SYS_CDEFS_H 1
#include_next <sys/cdefs.h>

#ifdef  __cplusplus
# define __BEGIN_DECLS  extern "C" {
# define __END_DECLS    }
#else
# define __BEGIN_DECLS
# define __END_DECLS
#endif

#endif

