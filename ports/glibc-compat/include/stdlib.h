#include_next <stdlib.h>

extern char* realpath(const char* path, const char* resolved_path);

extern void qsort_r(void *base, size_t nmemb, size_t size,
                    int (*compar)(const void *, const void *, void *),
                    void *arg);
