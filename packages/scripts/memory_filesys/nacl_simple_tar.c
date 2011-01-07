/*
 * Copyright (c) 2010 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that be
 * found in the LICENSE file.
 */

#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/param.h>
#include <sys/stat.h>
#include <unistd.h>
#include "nacl_escape.h"
#ifdef __native_client__
#  include <nacl/nacl_srpc.h>
#endif

int simple_tar_extract(const char *path) {
  char *blk;
  const char *src;
  int len;
  int name_len, data_len;
  ssize_t len_out;
  const char *end;
  char *name;
  int fh;
  int count;

  /* Read in the simple tar file. */
/*
  fh = open(path, O_RDONLY);
  if (fh < 0) return -1;
  lseek(fh, 0, SEEK_END);
  len = tell(fh);
  lseek(fh, 0, SEEK_SET);
  blk = malloc(len);
  assert(blk);
  data_len = read(fh, blk, len);
  if (data_len != len) {
    free(blk);
    close(fh);
    return -2;
  }
  close(fh);
*/
  FILE *file;
  file = fopen(path, "rb");
  if (!file) return -1;
  fseek(file, 0, SEEK_END);
  len = ftell(file);
  fseek(file, 0, SEEK_SET);
  blk = malloc(len);
  assert(blk);
  data_len = fread(blk, 1, len, file);
  if (data_len != len) {
    free(blk);
    fclose(file);
    return -2;
  }
  fclose(file);

  /* Extract the directories/files. */
  count = 0;
  src = blk;
  end = blk + len;
  while (src < end) {
    /* Get the first entry. */
    if (sscanf(src, "%d %d", &name_len, &data_len) != 2) {
      assert(0);
    }
    assert(name_len > 0);
    /* Advance past it. */
    src = strchr(src, '\n');
    assert(src);
    ++src;
    /* Pull out name. */
    name = malloc(name_len + 1);
    memcpy(name, src, name_len);
    name[name_len] = 0;
    src += name_len;
    /* Handle directories vs files. */
    if (data_len < 0) {
      mkdir(name, 0777);
    } else {
      /* Write out the data. */
      fh = open(name, O_CREAT | O_WRONLY | O_TRUNC);
      assert(fh >= 0);
      len_out = write(fh, src, data_len);
      assert(len_out == data_len);
      close(fh);
      /* Jump to the next entry. */
      src += data_len;
    }
    free(name);
    ++count;
  }
  free(blk);
  return count;
}


#ifdef __native_client__

void NaClSimpleTarExtract(NaClSrpcRpc *rpc,
                          NaClSrpcArg **in_args,
                          NaClSrpcArg **out_args,
                          NaClSrpcClosure *done) {
  out_args[0]->u.ival = simple_tar_extract(in_args[0]->arrays.str);
  rpc->result = NACL_SRPC_RESULT_OK;
  done->Run(done);
}

#endif
