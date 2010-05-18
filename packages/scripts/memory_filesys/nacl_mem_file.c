/*
 * Copyright (c) 2010 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that be
 * found in the LICENSE file.
 */

#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <sys/param.h>
#include <sys/stat.h>
#include <unistd.h>
#include "nacl_escape.h"
#ifdef __native_client__
#  include <nacl/nacl_srpc.h>
#endif

extern int console_get_nonblock(void);
extern int console_get(void);
extern void console_put(const char *str, int str_len);

/* Kinds of file nodes. */
typedef enum {
  FILE_NODE_DIRECTORY,
  FILE_NODE_FILE
} FILE_NODE_KIND;

typedef struct _FILE_NODE {
  struct _FILE_NODE *next;
  char *name;
  int use_count;
  FILE_NODE_KIND kind;
  union {
    struct {
      struct _FILE_NODE *children;
    } directory;
    struct {
      char *data;
      size_t len;
      size_t capacity;
    } file;
  } u;
} FILE_NODE;

typedef struct {
  FILE_NODE *node;
  off_t offset;
  int flags;
  int used;
} FILE_HANDLE;

static pthread_once_t mem_file_has_started = PTHREAD_ONCE_INIT;
#define MAX_FILE_HANDLES 100
static FILE_HANDLE file_handle_table[MAX_FILE_HANDLES];

static FILE_NODE *root = 0;
static char *cwd = 0;

static pthread_mutex_t master_lock;

static void mem_file_init_once(void) {
  /* Blank file handle table. */
  memset(file_handle_table, 0, sizeof(file_handle_table));
  /* Reserve 0(stdin) , 1(stdout), 2(stderr). */
  file_handle_table[0].used = 1;
  file_handle_table[1].used = 1;
  file_handle_table[2].used = 1;
  /* Set working dir to / */
  cwd = strdup("/");
  /* Allocate the root directory. */
  root = (FILE_NODE*)calloc(1, sizeof(FILE_NODE));
  assert(root);
  root->kind = FILE_NODE_DIRECTORY;
  root->name = strdup("/");
  /* Setup file system master lock. */
  if (pthread_mutex_init(&master_lock, NULL)) assert(0);
}

static void file_global_lock(void) {
  if (pthread_once(&mem_file_has_started, mem_file_init_once)) assert(0);
  if (pthread_mutex_lock(&master_lock)) assert(0);
}

static void file_global_unlock(void) {
  if (pthread_mutex_unlock(&master_lock)) assert(0);
}

static FILE_HANDLE *file_handle_get(int fildes) {
  if (fildes < 0 || fildes >= MAX_FILE_HANDLES) return 0;
  if (!file_handle_table[fildes].used) return 0;
  return &file_handle_table[fildes];
}

static char *path_collapse(const char *path) {
  char *ret;
  const char *src;
  char *tmp;
  char *dst;
  char cur;

  /* Setup space for resulting path. */
  ret = malloc(strlen(path) + 1);
  assert(ret);
  /* Canonialize assuming an absolute path. */
  src = path;
  dst = ret;
  cur = 0;
  for(;;) {
    /* Drain a character until done. */
    cur = *src;
    if (!cur) break;
    ++src; 
    /* Handle this character. */
    if (cur == '/') {
      for(;;) {
        if (strcmp(src, "..") == 0 || strncmp(src, "../", 3) == 0) {
          /* Strip off a layer. */ 
          (*dst) = 0;
          tmp = strrchr(ret, '/');
          if (tmp) { dst = tmp; }
          (*dst) = 0;
          src += 2;
          /* Slash in second case gets handled next time round. */
        } else if (strcmp(src, ".") == 0 || (*src) =='/' ||
                   strncmp(src, "./", 2) == 0) {
          ++src;
          /* Slash in last case gets handled next time round. */
        } else {
          break;
        }
      }
      if (*src) {
        (*dst) = '/'; ++dst;
      }
    } else {
      (*dst) = cur; ++dst;
    }
  }
  (*dst) = 0;
  return ret;
}

static char *path_canonical(const char *path) {
  char *tmp;
  char *ret;

  /* Handle absolute paths directly. */
  if ((*path) == '/') {
    return path_collapse(path);
  }
  /* Do collapse on cwd + "/" + path. */
  tmp = malloc(strlen(cwd) + strlen(path) + 2);
  strcpy(tmp, cwd);
  strcat(tmp, "/");
  strcat(tmp, path);
  ret = path_collapse(tmp);
  free(tmp);
  return ret;  
}

static char *path_last(const char *path) {
  const char *pos;

  pos = strrchr(path, '/');
  if (!pos) return strdup(path);
  assert(strlen(pos) != 0);  /* TODO: this may not be fully robust. */
  return strdup(pos + 1);
}

static FILE_NODE *file_node_get(const char *path) {
  FILE_NODE *node;
  FILE_NODE *child;
  char *fpath;
  const char *pos;
  const char *next;
  size_t len;

  /* Get in canonical form. */
  fpath = path_canonical(path);
  if (!fpath) {
    errno = ENOENT;
    return 0;
  }
  /* Walk up from root. */
  node = root;
  pos = fpath;
  for(;;) {
    /* Found it if pos is used up. */
    if ((*pos) == 0) {
      free(fpath);
      return node;
    }
    /* Check that the current node is a directory. */
    if (node->kind != FILE_NODE_DIRECTORY) {
      free(fpath);
      errno = ENOTDIR;
      return 0;
    }
    /* Find the next path component. */
    assert((*pos) == '/');
    next = strchr(pos + 1, '/');
    if (!next) next = pos + strlen(pos);
    len = next - (pos + 1);
    assert(len > 0);
    /* Look for it in this directory. */
    child = node->u.directory.children;
    while(child) {
      if (strlen(child->name) == len &&
          strncmp(child->name, pos + 1, len) == 0) {
        break;
      }
      child = child->next;
    }
    /* Fail if not found. */
    if (!child) {
      free(fpath);
      errno = ENOENT;
      return 0;
    }
    node = child;
    pos = next;
  }
}

static FILE_NODE *file_node_get_parent(const char *path) {
  char *tmp;
  FILE_NODE *node;

  /* Construct path + "/.." */
  tmp = malloc(strlen(path) + 4);
  assert(tmp);
  strcpy(tmp, path);
  strcat(tmp, "/..");
  /* Get its node. */
  node = file_node_get(tmp);
  /* Cleanup. */
  free(tmp);
  return node;
}

int __wrap_creat(const char *path, mode_t mode) {
  return open(path, O_CREAT | O_TRUNC | O_WRONLY, mode);
}

int __wrap_open(const char *path, int oflag, ...) {
  FILE_NODE *node;
  FILE_NODE *parent;
  int fildes;

  file_global_lock();
  /* Find empty file id. */
  for (fildes = 0; fildes < MAX_FILE_HANDLES; ++fildes) {
    if (!file_handle_table[fildes].used) break;
  }
  if (fildes == MAX_FILE_HANDLES) {
    errno = ENFILE;
    file_global_unlock();
    return -1;
  }
  /* Get the directory its in. */
  parent = file_node_get_parent(path);
  if (!parent) return -1; 
  /* It must be a directory. */
  if (parent->kind != FILE_NODE_DIRECTORY) {
    errno = ENOTDIR;
    file_global_unlock();
    return -1;
  }
  /* See if file exists. */
  node = file_node_get(path);
  if (node) {
    /* Check that it is a file if it does. */
    if (node->kind != FILE_NODE_FILE) {
      errno = EISDIR;
      file_global_unlock();
      return -1;
    }
    /* Check that we weren't expecting to create it. */
    if ((oflag & O_CREAT) && (oflag & O_EXCL)) {
      errno = EEXIST;
      file_global_unlock();
      return -1;
    }
  } else {
    /* Check that we can create it. */
    if (!(oflag & O_CREAT)) {
      errno = ENOENT;
      file_global_unlock();
      return -1;
    }
    /* Create it. */
    node = (FILE_NODE*)calloc(1, sizeof(FILE_NODE));
    node->kind = FILE_NODE_FILE;
    node->name = path_last(path);
    /* Add it to parent. */
    node->next = parent->u.directory.children;
    parent->u.directory.children = node;
  }
  /* Truncate the file if relevant. */
  if (oflag & O_TRUNC) {
    node->u.file.len = 0;
  }
  /* Setup file handle. */
  ++node->use_count;
  file_handle_table[fildes].used = 1;
  file_handle_table[fildes].node = node;
  file_handle_table[fildes].flags = oflag;
  if (oflag & O_APPEND) {
    file_handle_table[fildes].offset = node->u.file.len;
  } else {
    file_handle_table[fildes].offset = 0;
  }
  file_global_unlock();
  return fildes;
}


int __wrap_close(int fildes) {
  FILE_HANDLE *handle;

  if (fildes == STDIN_FILENO ||
      fildes == STDOUT_FILENO ||
      fildes == STDERR_FILENO) return 0;

  file_global_lock();
  handle = file_handle_get(fildes);
  if (!handle) {
    errno = EBADF;
    file_global_unlock();
    return -1;
  }
  --handle->node->use_count;
  handle->used = 0;
  file_global_unlock();
  return 0;
}

ssize_t __wrap_read(int fildes, void *buf, size_t nbyte) {
  FILE_HANDLE *handle;
  size_t len;
  char *pos;
  int ch;

  /* Hook in console read. */
  if (fildes == STDIN_FILENO) {
    pos = buf;
    len = nbyte;
    while (len > 0) {
      ch = console_get_nonblock();
      if (ch >= 0) {
        *pos++ = ch;
        --len;
      }
      //*pos++ = console_get();
      //  --len;
//      if (pos[-1] == '\n' || pos[-1] == '\r') break;
      break;
    }
    return nbyte - len;
  }
  if (fildes == STDOUT_FILENO || fildes == STDERR_FILENO) {
    errno = EBADF;
    return -1;
  }

  file_global_lock();
  handle = file_handle_get(fildes);
  if (!handle) {
    errno = EBADF;
    file_global_unlock();
    return -1;
  }
  /* Check that this file handle can be read from. */
  if ((handle->flags & O_ACCMODE) == O_WRONLY) {
    errno = EBADF;
    file_global_unlock();
    return -1;
  }
  /* Limit to the end of the file. */
  len = nbyte;
  if (len > handle->node->u.file.len - handle->offset) {
    len = handle->node->u.file.len - handle->offset; 
  }
  /* Do the read. */
  memcpy(buf, handle->node->u.file.data + handle->offset, len);
  handle->offset += len;
  file_global_unlock();
  return len; 
}


ssize_t __wrap_write(int fildes, const void *buf, size_t nbyte) {
  FILE_HANDLE *handle;
  size_t len;
  size_t next;

  /* Hook in console write. */
  if (fildes == STDOUT_FILENO ||
      fildes == STDERR_FILENO) {
    console_put(buf, nbyte);
    return nbyte;
  }
  if (fildes == STDIN_FILENO) {
    errno = EBADF;
    return -1;
  }

  file_global_lock();
  handle = file_handle_get(fildes);
  if (!handle) {
    errno = EBADF;
    file_global_unlock();
    return -1;
  }
  /* Check that this file handle can be written to. */
  if ((handle->flags & O_ACCMODE) == O_RDONLY) {
    errno = EBADF;
    file_global_unlock();
    return -1;
  }
  /* Grow the file if needed. */
  if (handle->offset + nbyte > handle->node->u.file.capacity) {
    len = handle->offset + nbyte;
    next = (handle->node->u.file.capacity + 1) * 2;
    if (next > len) len = next;
    handle->node->u.file.data =
        (char*)realloc(handle->node->u.file.data, len);
    assert(handle->node->u.file.data);
    /* TODO: Handle memory overflow more gracefully. */
    handle->node->u.file.capacity = len;
  }
  /* Pad any gap with zeros. */
  if (handle->offset > handle->node->u.file.len) {
    memset(handle->node->u.file.data + handle->node->u.file.len,
           0, handle->offset);
  }
  /* Write out the block. */
  memcpy(handle->node->u.file.data + handle->offset, buf, nbyte);
  handle->offset += nbyte;
  if (handle->offset > handle->node->u.file.len) {
    handle->node->u.file.len = handle->offset;
  }
  file_global_unlock();
  return nbyte;
}

off_t __wrap_lseek(int fildes, off_t offset, int whence) {
  FILE_HANDLE *handle;
  off_t next;

  if (fildes == STDIN_FILENO ||
      fildes == STDOUT_FILENO ||
      fildes == STDERR_FILENO) return 0;

  file_global_lock();
  handle = file_handle_get(fildes);
  if (!handle) {
    errno = EBADF;
    file_global_unlock();
    return -1;
  }
  switch(whence) {
    case SEEK_SET:
      next = offset;
      break;
    case SEEK_CUR:
      next = handle->offset + offset;
      /* TODO(bradnelson): handle EOVERFLOW if too big. */
      break;
    case SEEK_END:
      next = handle->node->u.file.len - offset;
      /* TODO(bradnelson): handle EOVERFLOW if too big. */
      break;
    default:
      errno = EINVAL;
      file_global_unlock();
      return -1;
   }
   /* Must not seek beyond the front of the file. */
   if (next < 0) {
     errno = EINVAL;
     file_global_unlock();
     return -1;
   }
   /* Go to the new offset. */
   handle->offset = next;
   file_global_unlock();
   return next;
}


off_t __wrap_tell(int fildes) {
  FILE_HANDLE *handle;
  off_t pos;

  if (fildes == STDIN_FILENO ||
      fildes == STDOUT_FILENO ||
      fildes == STDERR_FILENO) return 0;

  file_global_lock();
  handle = file_handle_get(fildes);
  if (!handle) {
    errno = EBADF;
    file_global_unlock();
    return -1;
  }
  pos = handle->offset;
  file_global_unlock();
  return pos;
}


int __wrap_mkdir(const char *path, mode_t mode) {
  FILE_NODE *node;
  FILE_NODE *nnode;

  file_global_lock();
  /* Make sure it doesn't already exist. */
  node = file_node_get(path);
  if (node) {
    errno = EEXIST;
    file_global_unlock();
    return -1;
  }
  /* Get the parent node. */
  node = file_node_get_parent(path);
  if (!node) {
    errno = ENOENT;
    file_global_unlock();
    return -1;
  }
  /* Check that parent is a directory. */
  if (node->kind != FILE_NODE_DIRECTORY) {
    errno = ENOTDIR;
    file_global_unlock();
    return -1;
  }
  /* Create a new node */
  nnode = (FILE_NODE*)calloc(1, sizeof(FILE_NODE));
  assert(nnode);
  nnode->kind = FILE_NODE_DIRECTORY;
  nnode->name = path_last(path);
  /* Add in the node */
  nnode->next = node->u.directory.children;
  node->u.directory.children = nnode;
  file_global_unlock();
  return 0;
}


int __wrap_rmdir(const char *path) {
  FILE_NODE *node;
  FILE_NODE *parent;
  FILE_NODE **pos;

  file_global_lock();
  /* Get the node. */
  node = file_node_get(path);
  if (!node) {
    errno = ENOENT;
    file_global_unlock();
    return -1;
  }
  /* Check if it's a directory. */
  if (node->kind != FILE_NODE_DIRECTORY)  {
    errno = ENOTDIR;
    file_global_unlock();
    return -1;
  }
  /* Check if it's empty. */
  if (node->u.directory.children)  {
    errno = ENOTEMPTY;
    file_global_unlock();
    return -1;
  }
  /* Get the node's parent. */
  parent = file_node_get_parent(path);
  assert(parent);
  /* Drop it from parent. */
  pos = &parent->u.directory.children;
  while (*pos) {
    if ((*pos) == node) {
      (*pos) = (*pos)->next;
      break;
    }
    pos = &(*pos)->next;
  }
  /* Free it. */
  free(node->name);
  free(node);
  file_global_unlock();
  return 0;
}


int __wrap_remove(const char *path) {
  FILE_NODE *node;
  FILE_NODE *parent;
  FILE_NODE **pos;

  file_global_lock();
  /* Get the node. */
  node = file_node_get(path);
  if (!node) {
    errno = ENOENT;
    file_global_unlock();
    return -1;
  }
  /* Check that it's a file. */
  if (node->kind != FILE_NODE_FILE) {
    errno = EPERM;  /* TODO: this isn't quite right. */
    file_global_unlock();
    return -1;
  }
  /* Check that it's not busy. */
  if (node->use_count > 0) {
    errno = EBUSY;
    file_global_unlock();
    return -1;
  }
  /* Get the node's parent. */
  parent = file_node_get_parent(path);
  assert(parent);
  /* Drop it from parent. */
  pos = &parent->u.directory.children;
  while (*pos) {
    if ((*pos) == node) {
      (*pos) = (*pos)->next;
      break;
    }
    pos = &(*pos)->next;
  }
  /* Free it. */
  free(node->name);
  free(node->u.file.data);
  free(node);
  file_global_unlock();
  return 0;
}


char *__wrap_getcwd(char *buf, size_t size) {
  if (size == 0) {
    errno = EINVAL;
    return 0;
  }
  file_global_lock();
  if (size < strlen(cwd) + 1) {
    errno = ERANGE;
    file_global_unlock();
    return 0;
  }
  strcpy(buf, cwd);
  file_global_unlock();
  return buf;
}

char *__wrap_getwd(char *buf) {
  return getcwd(buf, MAXPATHLEN);
}

int __wrap_chdir(const char *path) {
  FILE_NODE *node;
  
  file_global_lock();
  /* It must exist. */
  node = file_node_get(path);
  if (!node) {
    file_global_unlock();
    return -1;
  }
  /* It must be a directory. */
  if (node->kind != FILE_NODE_DIRECTORY) {
    errno = ENOTDIR;
    file_global_unlock();
    return -1;
  }
  /* Store it. */
  free(cwd);
  cwd = path_canonical(path);
  file_global_unlock();
  return 0;
}


int __wrap_isatty(int fildes) {
  if (fildes == STDIN_FILENO ||
      fildes == STDOUT_FILENO ||
      fildes == STDERR_FILENO) return 1;
  return 0;
}

static void raw_stat(FILE_NODE *node, struct stat *buf) {
  memset(buf, 0, sizeof(struct stat));
  if (node->kind == FILE_NODE_DIRECTORY) {
    buf->st_mode = S_IFDIR | 0777;
  } else {
    buf->st_mode = S_IFREG | 0777;
    buf->st_size = node->u.file.len;
  }
  buf->st_uid = 1001;
  buf->st_gid = 1002;
  buf->st_blksize = 1024;
}

int __wrap_stat(const char *path, struct stat *buf) {
  FILE_NODE *node;

  file_global_lock();
  node = file_node_get(path);
  if (!node) {
    file_global_unlock();
    return -1;
  }
  raw_stat(node, buf);
  file_global_unlock();
  return 0;
}

int __wrap_fstat(int fildes, struct stat *buf) {
  FILE_HANDLE *handle;

  if (fildes == STDIN_FILENO ||
      fildes == STDOUT_FILENO ||
      fildes == STDERR_FILENO) {
    memset(buf, 0, sizeof(struct stat));
    buf->st_mode = S_IFCHR | 0777;
    return 0;
  }

  file_global_lock();
  handle = file_handle_get(fildes);
  if (!handle) {
    errno = EBADF;
    file_global_unlock();
    return -1;
  }
  raw_stat(handle->node, buf);
  file_global_unlock();

  return 0;
}


/* Everything else is just a do nothing stub. */


int __wrap_access(const char *path, int amode) {
  return 0;
}

uid_t __wrap_getuid(void) {
  return 1001;
}

int __wrap_setuid(uid_t id) {
  return 0;
} 

gid_t __wrap_getgid(void) {
  return 1002;
}

int __wrap_setgid(gid_t id) {
  return 0;
}

char *__wrap_getlogin(void) {
  return "";
}

struct passwd *__wrap_getpwnam(const char *login) {
  /* Not sure this is helpful, as its an error. */
  return 0;
}

struct passwd *__wrap_getpwuid(uid_t uid) {
  /* Not sure this is helpful, as its an error. */
  return 0;
}

mode_t __wrap_umask(mode_t cmask) {
  return 0777;
}

int __wrap_chmod(const char *path, mode_t mode) {
  return 0;
}

int __wrap_ioctl(int fildes, unsigned long request, ...) {
  return 0;
}

int __wrap_link(const char *path1, const char *path2) {
  errno = EMLINK;
  return -1;
}

int __wrap_unlink(const char *path) {
  /* Always pretend to work for now. */
  return 0;
}

int __wrap_kill(pid_t pid, int sig) {
  return 0;
}


#ifdef __native_client__

NaClSrpcError NaClOpen(NaClSrpcChannel *channel,
                       NaClSrpcArg **in_args,
                       NaClSrpcArg **out_args) {
  out_args[0]->u.ival = __wrap_open(in_args[0]->u.sval,
                                    in_args[1]->u.ival);
  return NACL_SRPC_RESULT_OK;
}
NACL_SRPC_METHOD("open:si:i", NaClOpen);

NaClSrpcError NaClClose(NaClSrpcChannel *channel,
                        NaClSrpcArg **in_args,
                        NaClSrpcArg **out_args) {
  out_args[0]->u.ival = __wrap_close(in_args[0]->u.ival);
  return NACL_SRPC_RESULT_OK;
}
NACL_SRPC_METHOD("close:i:i", NaClClose);

NaClSrpcError NaClReadEscaped(NaClSrpcChannel *channel,
                              NaClSrpcArg **in_args,
                              NaClSrpcArg **out_args) {
  char *buf;
  char *escaped;
  int ret;
  int len;

  /* Prepare workspaces */
  buf = malloc(in_args[1]->u.ival);
  assert(buf);
  /* Read it and get its length. */
  ret = __wrap_read(in_args[0]->u.ival, buf, in_args[1]->u.ival);
  len = ret>=0 ? ret : 0;
  /* Escape it. */
  escaped = escape_string(buf, len);
  free(buf);
  /* Return result. */
  out_args[0]->u.ival = ret;
  out_args[1]->u.sval = escaped;
  return NACL_SRPC_RESULT_OK;
}
NACL_SRPC_METHOD("readEscaped:ii:is", NaClReadEscaped);

NaClSrpcError NaClWriteEscaped(NaClSrpcChannel *channel,
                               NaClSrpcArg **in_args,
                               NaClSrpcArg **out_args) {
  char *unescaped;
  int unescaped_len;

  /* Unescape it. */
  unescape_string(in_args[1]->u.sval, &unescaped, &unescaped_len);
  /* Write it. */
  out_args[0]->u.ival = __wrap_write(in_args[0]->u.ival,
                                     unescaped, unescaped_len);
  free(unescaped);
  return NACL_SRPC_RESULT_OK;
}
NACL_SRPC_METHOD("writeEscaped:is:i", NaClWriteEscaped);

NaClSrpcError NaClSeek(NaClSrpcChannel *channel,
                       NaClSrpcArg **in_args,
                       NaClSrpcArg **out_args) {
  out_args[0]->u.ival = __wrap_lseek(in_args[0]->u.ival,
                                     in_args[1]->u.ival,
                                     in_args[2]->u.ival);
  return NACL_SRPC_RESULT_OK;
}
NACL_SRPC_METHOD("seek:iii:i", NaClSeek);

NaClSrpcError NaClTell(NaClSrpcChannel *channel,
                       NaClSrpcArg **in_args,
                       NaClSrpcArg **out_args) {
  out_args[0]->u.ival = __wrap_tell(in_args[0]->u.ival);
  return NACL_SRPC_RESULT_OK;
}
NACL_SRPC_METHOD("tell:i:i", NaClTell);

NaClSrpcError NaClMkdir(NaClSrpcChannel *channel,
                        NaClSrpcArg **in_args,
                        NaClSrpcArg **out_args) {
  out_args[0]->u.ival = __wrap_mkdir(in_args[0]->u.sval, 0777);
  return NACL_SRPC_RESULT_OK;
}
NACL_SRPC_METHOD("mkdir:s:i", NaClMkdir);

NaClSrpcError NaClRmdir(NaClSrpcChannel *channel,
                        NaClSrpcArg **in_args,
                        NaClSrpcArg **out_args) {
  out_args[0]->u.ival = __wrap_rmdir(in_args[0]->u.sval);
  return NACL_SRPC_RESULT_OK;
}
NACL_SRPC_METHOD("rmdir:s:i", NaClRmdir);

NaClSrpcError NaClRemove(NaClSrpcChannel *channel,
                         NaClSrpcArg **in_args,
                         NaClSrpcArg **out_args) {
  out_args[0]->u.ival = __wrap_remove(in_args[0]->u.sval);
  return NACL_SRPC_RESULT_OK;
}
NACL_SRPC_METHOD("remove:s:i", NaClRemove);

NaClSrpcError NaClGetCWD(NaClSrpcChannel *channel,
                         NaClSrpcArg **in_args,
                         NaClSrpcArg **out_args) {
  char buf[MAXPATHLEN];
  if (!__wrap_getcwd(buf, MAXPATHLEN)) assert(0);
  out_args[0]->u.sval = strdup(buf);
  return NACL_SRPC_RESULT_OK;
}
NACL_SRPC_METHOD("getcwd::s", NaClGetCWD);

NaClSrpcError NaClChdir(NaClSrpcChannel *channel,
                        NaClSrpcArg **in_args,
                        NaClSrpcArg **out_args) {
  out_args[0]->u.ival = chdir(in_args[0]->u.sval);
  return NACL_SRPC_RESULT_OK;
}
NACL_SRPC_METHOD("chdir:s:i", NaClChdir);

NaClSrpcError NaClErrno(NaClSrpcChannel *channel,
                        NaClSrpcArg **in_args,
                        NaClSrpcArg **out_args) {
  out_args[0]->u.ival = errno;
  return NACL_SRPC_RESULT_OK;
}
NACL_SRPC_METHOD("errno::i", NaClErrno);

NaClSrpcError NaClGetEnv(NaClSrpcChannel *channel,
                         NaClSrpcArg **in_args,
                         NaClSrpcArg **out_args) {
  char *val;

  val = getenv(in_args[0]->u.sval);
  if (!val) val = "";
  out_args[0]->u.sval = strdup(val);
  return NACL_SRPC_RESULT_OK;
}
NACL_SRPC_METHOD("getenv:s:s", NaClGetEnv);

#endif
