#include <netdb.h>

int __getprotobyname_r(const char *name,
                       struct protoent *result_buf, char *buf,
                       size_t buflen, struct protoent **result)
{
  *result = NULL;
  return 1;
}
