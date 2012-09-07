#include <netdb.h>

int __getservbyname_r(const char *name, const char *proto,
                      struct servent *result_buf, char *buf,
                      size_t buflen, struct servent **result)
{
  *result = NULL;
  return 1;
}
