#include_next <stdlib.h>

extern void qsort_r(void *base, size_t nmemb, size_t size,
                    int (*compar)(const void *, const void *, void *),
                    void *arg);
